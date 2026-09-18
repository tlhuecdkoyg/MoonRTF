///|
pub(all) enum OutputFormat {
  PlainText
  Markdown
  Html
  StructuredJson
} derive(Eq, Debug)

///|
pub(all) struct Conversion {
  content : String
  diagnostics : Array[Diagnostic]
  exceeded_limit : Bool
} derive(Eq, Debug, ToJson)

///|
/// Identify representation losses before selecting an output format.
pub fn Document::conversion_diagnostics(
  self : Document,
  format : OutputFormat,
  include_hidden? : Bool = false,
) -> Array[Diagnostic] {
  let diagnostics : Array[Diagnostic] = []
  let seen : Map[String, Bool] = Map([])
  for paragraph in self.paragraphs {
    if paragraph.region != Body {
      continue
    }
    if format == Markdown &&
      paragraph.style.alignment != Left &&
      !seen.contains("markdown_alignment") {
      seen["markdown_alignment"] = true
      diagnostics.push(
        validation_issue(
          "markdown_alignment",
          "Markdown does not preserve paragraph alignment",
          paragraph.span,
        ),
      )
    }
    for run in paragraph.runs {
      if !include_hidden && run.style.hidden {
        continue
      }
      if format == Markdown {
        if run.style.underline && !seen.contains("markdown_underline") {
          seen["markdown_underline"] = true
          diagnostics.push(
            validation_issue(
              "markdown_underline",
              "Underline is flattened in Markdown output",
              run.span,
            ),
          )
        }
        if run.style.superscript != 0 && !seen.contains("markdown_script") {
          seen["markdown_script"] = true
          diagnostics.push(
            validation_issue(
              "markdown_script",
              "Superscript and subscript are flattened in Markdown output",
              run.span,
            ),
          )
        }
        if (run.style.foreground > 0 || run.style.background > 0) &&
          !seen.contains("markdown_color") {
          seen["markdown_color"] = true
          diagnostics.push(
            validation_issue(
              "markdown_color",
              "Font colors are not preserved in Markdown output",
              run.span,
            ),
          )
        }
      }
      if (format == Markdown || format == Html) &&
        run.link is Some(link) &&
        !safe_link(link) &&
        !seen.contains("inactive_link") {
        seen["inactive_link"] = true
        diagnostics.push(
          validation_issue(
            "inactive_link",
            "A link with an unsupported scheme is rendered as text",
            run.span,
          ),
        )
      }
    }
  }
  if format == Markdown {
    for table in self.tables() {
      if !table.is_rectangular() && !seen.contains("ragged_markdown_table") {
        seen["ragged_markdown_table"] = true
        diagnostics.push(
          validation_issue(
            "ragged_markdown_table",
            "Unequal table row widths may render differently between Markdown readers",
            { start: 0, end: 0, },
          ),
        )
      }
    }
  }
  diagnostics
}

///|
/// Convert a parsed document with an explicit output limit and loss report.
/// Structured JSON keeps parse diagnostics in the interchange representation.
pub fn ParseResult::convert(
  self : ParseResult,
  format : OutputFormat,
  options? : TextOptions = TextOptions::default(),
  max_output_units? : Int = 64 * 1024 * 1024,
) -> Conversion {
  let diagnostics = self.diagnostics.copy()
  if max_output_units <= 0 {
    diagnostics.push({
      code: "invalid_output_limit",
      severity: Error,
      message: "Output limit must be positive",
      span: { start: 0, end: 0, },
    })
    return { content: "", diagnostics, exceeded_limit: true, }
  }
  for
    issue in self.document.conversion_diagnostics(
      format,
      include_hidden=options.include_hidden,
    ) {
    diagnostics.push(issue)
  }
  let content = match format {
    PlainText => self.document.to_text(options~)
    Markdown => self.document.to_markdown(options~)
    Html => self.document.to_html(options~)
    StructuredJson => self.to_json_text()
  }
  if content.length() > max_output_units {
    diagnostics.push({
      code: "encoded_output_limit",
      severity: Error,
      message: "Converted output exceeds its UTF-16 unit limit",
      span: { start: 0, end: 0, },
    })
    { content: "", diagnostics, exceeded_limit: true, }
  } else {
    { content, diagnostics, exceeded_limit: false, }
  }
}
