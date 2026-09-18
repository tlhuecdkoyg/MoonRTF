///|
pub(all) struct ValidationReport {
  valid : Bool
  complete : Bool
  errors : Int
  warnings : Int
  diagnostics : Array[Diagnostic]
} derive(Eq, Debug, ToJson)

///|
fn check_span(span : Span, length : Int) -> Bool {
  span.start >= 0 && span.end >= span.start && span.end <= length
}

///|
fn validation_issue(code : String, message : String, span : Span) -> Diagnostic {
  { code, severity: Warning, message, span, }
}

///|
/// Check references and structural invariants in the extracted document.
pub fn Document::validate(
  self : Document,
  max_diagnostics? : Int = 1000,
) -> Array[Diagnostic] {
  let out : Array[Diagnostic] = []
  if max_diagnostics <= 0 {
    return out
  }
  let font_ids : Map[Int, Bool] = Map([])
  let missing_fonts : Map[Int, Bool] = Map([])
  let missing_colors : Map[Int, Bool] = Map([])
  for font in self.fonts {
    if out.length() >= max_diagnostics {
      return out
    }
    if font_ids.contains(font.id) {
      out.push(
        validation_issue(
          "duplicate_font_id",
          "Font identifier appears more than once",
          { start: 0, end: 0, },
        ),
      )
    }
    font_ids[font.id] = true
  }
  let mut last_row : Int? = None
  let mut last_cell : Int? = None
  for paragraph in self.paragraphs {
    if out.length() >= max_diagnostics {
      break
    }
    if !check_span(paragraph.span, self.input_bytes) {
      out.push(
        validation_issue(
          "invalid_paragraph_span",
          "Paragraph source range is outside the input",
          { start: 0, end: 0, },
        ),
      )
    }
    if (paragraph.table_row is Some(_)) != (paragraph.table_cell is Some(_)) {
      out.push(
        validation_issue(
          "incomplete_table_address",
          "Table row and cell must both be present",
          paragraph.span,
        ),
      )
    }
    if paragraph.table_row is Some(row) {
      if last_row == Some(row) {
        if paragraph.table_cell is Some(cell) &&
          last_cell is Some(previous) &&
          cell < previous {
          out.push(
            validation_issue(
              "table_cell_order",
              "Cell indices decrease within a row",
              paragraph.span,
            ),
          )
        }
      }
      last_row = Some(row)
      last_cell = paragraph.table_cell
    } else {
      last_row = None
      last_cell = None
    }
    for run in paragraph.runs {
      if out.length() >= max_diagnostics {
        break
      }
      if !check_span(run.span, self.input_bytes) {
        out.push(
          validation_issue(
            "invalid_run_span",
            "Text source range is outside the input",
            { start: 0, end: 0, },
          ),
        )
      }
      let font = run.style.font
      if !self.fonts.is_empty() &&
        !font_ids.contains(font) &&
        !missing_fonts.contains(font) {
        missing_fonts[font] = true
        out.push(
          validation_issue(
            "undefined_font",
            "Font \{font} is not declared",
            run.span,
          ),
        )
      }
      for color in [run.style.foreground, run.style.background] {
        if color > 0 &&
          color >= self.colors.length() &&
          !missing_colors.contains(color) {
          missing_colors[color] = true
          out.push(
            validation_issue(
              "undefined_color",
              "Color \{color} is not declared",
              run.span,
            ),
          )
        }
      }
      if run.link is Some(link) && !safe_link(link) {
        out.push(
          validation_issue(
            "unsafe_link",
            "Link is retained as metadata but not activated by Markdown export",
            run.span,
          ),
        )
      }
    }
  }
  // The inner checks can add a few messages together; the public cap is exact.
  if out.length() > max_diagnostics {
    out[:max_diagnostics].to_owned()
  } else {
    out
  }
}

///|
pub fn validate(
  input : Bytes,
  fail_on_warning? : Bool = false,
  limits? : Limits = Limits::default(),
) -> ValidationReport {
  let parsed = parse(input, limits~, recover=true)
  let diagnostics = parsed.diagnostics.copy()
  let remaining = (limits.diagnostics - diagnostics.length()).max(0)
  for issue in parsed.document.validate(max_diagnostics=remaining) {
    diagnostics.push(issue)
  }
  let mut errors = 0
  let mut warnings = 0
  for d in diagnostics {
    if d.is_error() {
      errors += 1
    } else {
      warnings += 1
    }
  }
  {
    valid: parsed.complete && errors == 0 && (!fail_on_warning || warnings == 0),
    complete: parsed.complete,
    errors,
    warnings,
    diagnostics,
  }
}

///|
pub fn ValidationReport::to_json_text(self : ValidationReport) -> String {
  Json::object({
    "schema": Json::string("moonrtf.validation.v1"),
    "valid": Json::boolean(self.valid),
    "complete": Json::boolean(self.complete),
    "errors": self.errors.to_json(),
    "warnings": self.warnings.to_json(),
    "diagnostics": Json::array(self.diagnostics.map(diagnostic_json)),
  }).stringify()
}

///|
pub fn ValidationReport::to_text(
  self : ValidationReport,
  input : Bytes,
) -> String {
  let out = StringBuilder()
  out.write_string(if self.valid { "VALID" } else { "INVALID" })
  out.write_string(" errors=\{self.errors} warnings=\{self.warnings}\n")
  for d in self.diagnostics {
    out.write_string(format_diagnostic(input, d))
    out.write_char('\n')
  }
  out.to_string()
}
