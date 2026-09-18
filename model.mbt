///|
pub(all) enum Region {
  Body
  Header
  Footer
  Footnote
  Annotation
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Style {
  bold : Bool
  italic : Bool
  underline : Bool
  strike : Bool
  hidden : Bool
  superscript : Int
  font : Int
  size_half_points : Int
  foreground : Int
  background : Int
} derive(Eq, Debug, ToJson)

///|
pub fn Style::default() -> Style {
  {
    bold: false,
    italic: false,
    underline: false,
    strike: false,
    hidden: false,
    superscript: 0,
    font: 0,
    size_half_points: 24,
    foreground: 0,
    background: 0,
  }
}

///|
pub(all) enum Alignment {
  Left
  Right
  Center
  Justify
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ParagraphStyle {
  alignment : Alignment
  left_indent : Int
  right_indent : Int
  first_indent : Int
  space_before : Int
  space_after : Int
  line_spacing : Int
  keep_together : Bool
  keep_next : Bool
} derive(Eq, Debug, ToJson)

///|
pub fn ParagraphStyle::default() -> ParagraphStyle {
  {
    alignment: Left,
    left_indent: 0,
    right_indent: 0,
    first_indent: 0,
    space_before: 0,
    space_after: 0,
    line_spacing: 0,
    keep_together: false,
    keep_next: false,
  }
}

///|
pub(all) struct Run {
  text : String
  style : Style
  span : Span
  link : String?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Paragraph {
  runs : Array[Run]
  style : ParagraphStyle
  region : Region
  table_row : Int?
  table_cell : Int?
  span : Span
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Font {
  id : Int
  name : String
  charset : Int
  codepage : Int?
  family : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Color {
  red : Int
  green : Int
  blue : Int
  automatic : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Metadata {
  key : String
  value : String
  span : Span
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Attachment {
  kind : String
  span : Span
  declared_width : Int?
  declared_height : Int?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Document {
  paragraphs : Array[Paragraph]
  fonts : Array[Font]
  colors : Array[Color]
  metadata : Array[Metadata]
  attachments : Array[Attachment]
  input_bytes : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ParseResult {
  document : Document
  diagnostics : Array[Diagnostic]
  complete : Bool
} derive(Eq, Debug, ToJson)

///|
pub fn ParseResult::has_errors(self : ParseResult) -> Bool {
  self.diagnostics.any(d => d.is_error())
}

///|
pub fn ParseResult::has_warnings(self : ParseResult) -> Bool {
  self.diagnostics.any(d => d.severity == Warning)
}

///|
pub fn ParseResult::acceptable(
  self : ParseResult,
  fail_on_warning? : Bool = false,
) -> Bool {
  self.complete &&
  !self.has_errors() &&
  (!fail_on_warning || !self.has_warnings())
}

///|
pub fn Document::font(self : Document, id : Int) -> Font? {
  for f in self.fonts {
    if f.id == id {
      return Some(f)
    }
  }
  None
}

///|
pub fn Document::metadata_value(self : Document, key : String) -> String? {
  for m in self.metadata {
    if m.key == key {
      return Some(m.value)
    }
  }
  None
}

///|
pub fn Document::character_count(self : Document) -> Int {
  let mut count = 0
  for paragraph in self.paragraphs {
    for run in paragraph.runs {
      for _ in run.text.iter() {
        count += 1
      }
    }
  }
  count
}

///|
pub fn Document::body_paragraphs(self : Document) -> Array[Paragraph] {
  self.paragraphs.filter(p => p.region == Body)
}

///|
pub fn Document::links(self : Document) -> Array[String] {
  let links : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  for paragraph in self.paragraphs {
    for run in paragraph.runs {
      if run.link is Some(link) && !seen.contains(link) {
        seen[link] = true
        links.push(link)
      }
    }
  }
  links
}

///|
pub fn Paragraph::text(
  self : Paragraph,
  include_hidden? : Bool = false,
) -> String {
  let out = StringBuilder()
  for run in self.runs {
    if include_hidden || !run.style.hidden {
      out.write_string(run.text)
    }
  }
  out.to_string()
}
