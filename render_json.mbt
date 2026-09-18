///|
fn span_json(span : Span) -> Json {
  Json::object({ "start": span.start.to_json(), "end": span.end.to_json() })
}

///|
fn optional_int_json(value : Int?) -> Json {
  match value {
    Some(n) => n.to_json()
    None => Json::null()
  }
}

///|
fn optional_string_json(value : String?) -> Json {
  match value {
    Some(s) => Json::string(s)
    None => Json::null()
  }
}

///|
fn style_json(style : Style) -> Json {
  Json::object({
    "bold": Json::boolean(style.bold),
    "italic": Json::boolean(style.italic),
    "underline": Json::boolean(style.underline),
    "strike": Json::boolean(style.strike),
    "hidden": Json::boolean(style.hidden),
    "superscript": style.superscript.to_json(),
    "font": style.font.to_json(),
    "size_half_points": style.size_half_points.to_json(),
    "foreground": style.foreground.to_json(),
    "background": style.background.to_json(),
  })
}

///|
fn paragraph_style_json(style : ParagraphStyle) -> Json {
  Json::object({
    "alignment": Json::string(alignment_name(style.alignment)),
    "left_indent": style.left_indent.to_json(),
    "right_indent": style.right_indent.to_json(),
    "first_indent": style.first_indent.to_json(),
    "space_before": style.space_before.to_json(),
    "space_after": style.space_after.to_json(),
    "line_spacing": style.line_spacing.to_json(),
    "keep_together": Json::boolean(style.keep_together),
    "keep_next": Json::boolean(style.keep_next),
  })
}

///|
fn run_json(run : Run) -> Json {
  Json::object({
    "text": Json::string(run.text),
    "style": style_json(run.style),
    "source": span_json(run.span),
    "link": optional_string_json(run.link),
  })
}

///|
fn paragraph_json(paragraph : Paragraph) -> Json {
  Json::object({
    "runs": Json::array(paragraph.runs.map(run_json)),
    "style": paragraph_style_json(paragraph.style),
    "region": Json::string(region_name(paragraph.region)),
    "table_row": optional_int_json(paragraph.table_row),
    "table_cell": optional_int_json(paragraph.table_cell),
    "source": span_json(paragraph.span),
  })
}

///|
fn font_json(font : Font) -> Json {
  Json::object({
    "id": font.id.to_json(),
    "name": Json::string(font.name),
    "charset": font.charset.to_json(),
    "codepage": optional_int_json(font.codepage),
    "family": Json::string(font.family),
  })
}

///|
fn color_json(color : Color) -> Json {
  Json::object({
    "red": color.red.to_json(),
    "green": color.green.to_json(),
    "blue": color.blue.to_json(),
    "automatic": Json::boolean(color.automatic),
  })
}

///|
fn metadata_json(metadata : Metadata) -> Json {
  Json::object({
    "key": Json::string(metadata.key),
    "value": Json::string(metadata.value),
    "source": span_json(metadata.span),
  })
}

///|
fn attachment_json(attachment : Attachment) -> Json {
  Json::object({
    "kind": Json::string(attachment.kind),
    "source": span_json(attachment.span),
    "width": optional_int_json(attachment.declared_width),
    "height": optional_int_json(attachment.declared_height),
  })
}

///|
fn diagnostic_json(d : Diagnostic) -> Json {
  Json::object({
    "code": Json::string(d.code),
    "severity": Json::string(if d.is_error() { "error" } else { "warning" }),
    "message": Json::string(d.message),
    "source": span_json(d.span),
  })
}

///|
/// Stable interchange schema; independent of MoonBit enum serialization.
pub fn ParseResult::to_interchange(self : ParseResult) -> Json {
  Json::object({
    "schema": Json::string("moonrtf.document.v1"),
    "complete": Json::boolean(self.complete),
    "input_bytes": self.document.input_bytes.to_json(),
    "paragraphs": Json::array(self.document.paragraphs.map(paragraph_json)),
    "fonts": Json::array(self.document.fonts.map(font_json)),
    "colors": Json::array(self.document.colors.map(color_json)),
    "metadata": Json::array(self.document.metadata.map(metadata_json)),
    "attachments": Json::array(self.document.attachments.map(attachment_json)),
    "diagnostics": Json::array(self.diagnostics.map(diagnostic_json)),
  })
}

///|
pub fn ParseResult::to_json_text(
  self : ParseResult,
  pretty? : Bool = false,
) -> String {
  if pretty {
    self.to_interchange().stringify(indent=2)
  } else {
    self.to_interchange().stringify()
  }
}
