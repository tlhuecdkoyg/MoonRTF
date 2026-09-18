///|
priv struct FieldContext {
  mut instruction : String
  mut link : String?
}

///|
priv struct State {
  mut style : Style
  mut paragraph : ParagraphStyle
  mut destination : String
  mut region : Region
  mut uc : Int
  mut codepage : Int
  mut starred : Bool
  mut owned : Bool
  mut capture : StringBuilder
  mut font_id : Int
  mut charset : Int
  mut font_codepage : Int?
  mut family : String
  mut red : Int
  mut green : Int
  mut blue : Int
  mut color_set : Bool
  mut field : FieldContext?
  mut in_table : Bool
  mut width : Int?
  mut height : Int?
  start : Int
}

///|
fn State::new(start : Int) -> State {
  {
    style: Style::default(),
    paragraph: ParagraphStyle::default(),
    destination: "body",
    region: Body,
    uc: 1,
    codepage: 1252,
    starred: false,
    owned: false,
    capture: StringBuilder(),
    font_id: -1,
    charset: 0,
    font_codepage: None,
    family: "nil",
    red: 0,
    green: 0,
    blue: 0,
    color_set: false,
    field: None,
    in_table: false,
    width: None,
    height: None,
    start,
  }
}

///|
fn State::child(self : State, start : Int) -> State {
  {
    style: self.style,
    paragraph: self.paragraph,
    destination: self.destination,
    region: self.region,
    uc: self.uc,
    codepage: self.codepage,
    starred: false,
    owned: false,
    capture: self.capture,
    font_id: self.font_id,
    charset: self.charset,
    font_codepage: self.font_codepage,
    family: self.family,
    red: self.red,
    green: self.green,
    blue: self.blue,
    color_set: self.color_set,
    field: self.field,
    in_table: self.in_table,
    width: self.width,
    height: self.height,
    start,
  }
}

///|
priv struct Parser {
  input : Bytes
  lexer : Lexer
  limits : Limits
  recover : Bool
  stack : Array[State]
  mut state : State
  paragraphs : Array[Paragraph]
  fonts : Array[Font]
  colors : Array[Color]
  metadata : Array[Metadata]
  attachments : Array[Attachment]
  diagnostics : Array[Diagnostic]
  runs : Array[Run]
  buffer : StringBuilder
  mut buffer_start : Int
  mut buffer_end : Int
  mut paragraph_start : Int
  mut fallback : Int
  mut pending_high : Int?
  mut high_span : Span
  mut units : Int
  mut nodes : Int
  mut row : Int
  mut cell : Int
  mut default_font : Int
  mut complete : Bool
  mut stopped : Bool
  mut closed_root : Bool
  mut seen_version : Bool
  warned : Map[String, Bool]
}

///|
fn Parser::new(input : Bytes, limits : Limits, recover : Bool) -> Parser {
  {
    input,
    lexer: Lexer::new(input),
    limits,
    recover,
    stack: [],
    state: State::new(0),
    paragraphs: [],
    fonts: [],
    colors: [],
    metadata: [],
    attachments: [],
    diagnostics: [],
    runs: [],
    buffer: StringBuilder(),
    buffer_start: 0,
    buffer_end: 0,
    paragraph_start: 0,
    fallback: 0,
    pending_high: None,
    high_span: { start: 0, end: 0, },
    units: 0,
    nodes: 0,
    row: 0,
    cell: 0,
    default_font: 0,
    complete: true,
    stopped: false,
    closed_root: false,
    seen_version: false,
    warned: {},
  }
}

///|
fn Parser::report(
  self : Parser,
  code : String,
  severity : Severity,
  message : String,
  span : Span,
) -> Unit {
  if self.diagnostics.length() >= self.limits.diagnostics {
    self.complete = false
    self.stopped = true
    return
  }
  self.diagnostics.push({ code, severity, message, span, })
  if severity == Error {
    self.complete = false
    if !self.recover {
      self.stopped = true
    }
  }
}

///|
fn Parser::warn_once(
  self : Parser,
  code : String,
  message : String,
  span : Span,
) -> Unit {
  if !self.warned.contains(code) {
    self.warned[code] = true
    self.report(code, Warning, message, span)
  }
}

///|
fn Parser::take_node(self : Parser, span : Span) -> Bool {
  if self.nodes >= self.limits.nodes {
    self.report("node_limit", Error, "Document node limit exceeded", span)
    self.stopped = true
    return false
  }
  self.nodes += 1
  true
}

///|
fn Parser::flush_run(self : Parser) -> Unit {
  if self.buffer.is_empty() {
    return
  }
  let text = self.buffer.to_string()
  self.buffer.reset()
  let span : Span = { start: self.buffer_start, end: self.buffer_end, }
  if !self.take_node(span) {
    return
  }
  let link = match self.state.field {
    Some(field) => field.link
    None => None
  }
  self.runs.push({ text, style: self.state.style, span, link, })
}

///|
fn Parser::finish_paragraph(self : Parser, end : Int, force : Bool) -> Unit {
  self.flush_run()
  if self.runs.is_empty() && !force {
    self.paragraph_start = end
    return
  }
  let span : Span = { start: self.paragraph_start, end, }
  if !self.take_node(span) {
    self.runs.clear()
    return
  }
  self.paragraphs.push({
    runs: self.runs.copy(),
    style: self.state.paragraph,
    region: self.state.region,
    table_row: if self.state.in_table {
      Some(self.row)
    } else {
      None
    },
    table_cell: if self.state.in_table {
      Some(self.cell)
    } else {
      None
    },
    span,
  })
  self.runs.clear()
  self.paragraph_start = end
}

///|
fn Parser::append_scalar(self : Parser, scalar : Int, span : Span) -> Unit {
  if self.stopped {
    return
  }
  let cost = if scalar > 0xFFFF { 2 } else { 1 }
  if cost > self.limits.output_units - self.units {
    self.report("output_limit", Error, "Decoded text limit exceeded", span)
    self.stopped = true
    return
  }
  self.units += cost
  let c = scalar.unsafe_to_char()
  match self.state.destination {
    "skip" | "info" | "field" | "upr" | "pict" | "object" => ()
    "fonttbl" =>
      if scalar == 59 {
        self.finish_font(span)
      } else {
        self.state.capture.write_char(c)
      }
    "colortbl" => if scalar == 59 { self.finish_color(span) }
    "body" | "fldrslt" => {
      if self.buffer.is_empty() {
        self.buffer_start = span.start
      }
      self.buffer_end = span.end
      self.buffer.write_char(c)
    }
    _ => self.state.capture.write_char(c)
  }
}

///|
fn Parser::flush_surrogate(self : Parser) -> Unit {
  if self.pending_high is Some(_) {
    self.pending_high = None
    self.report(
      "unpaired_surrogate",
      Error,
      "High surrogate has no matching low surrogate",
      self.high_span,
    )
    self.append_scalar(0xFFFD, self.high_span)
  }
}

///|
fn Parser::emit_unicode(self : Parser, value : Int, span : Span) -> Unit {
  match unicode_unit(value) {
    None => {
      self.report(
        "unicode_range",
        Error,
        "Unicode control value is out of range",
        span,
      )
      self.append_scalar(0xFFFD, span)
    }
    Some(unit) =>
      if high_surrogate(unit) {
        self.flush_surrogate()
        self.pending_high = Some(unit)
        self.high_span = span
      } else if low_surrogate(unit) {
        match self.pending_high {
          Some(high) => {
            self.pending_high = None
            self.append_scalar(combine_surrogates(high, unit), {
              start: self.high_span.start,
              end: span.end,
            })
          }
          None => {
            self.report(
              "unpaired_surrogate",
              Error,
              "Low surrogate has no preceding high surrogate",
              span,
            )
            self.append_scalar(0xFFFD, span)
          }
        }
      } else {
        self.flush_surrogate()
        self.append_scalar(unit, span)
      }
  }
  self.fallback = self.state.uc
}

///|
fn Parser::effective_codepage(self : Parser) -> Int {
  for font in self.fonts {
    if font.id == self.state.style.font {
      if font.codepage is Some(cp) {
        return cp
      }
      if font.charset != 0 && font.charset != 1 {
        return charset_codepage(font.charset).unwrap_or(-1)
      }
    }
  }
  self.state.codepage
}

///|
fn Parser::emit_byte(self : Parser, b : Int, span : Span) -> Unit {
  if b == 10 || b == 13 {
    return
  }
  if self.fallback > 0 {
    self.fallback -= 1
    return
  }
  if self.state.destination == "skip" {
    return
  }
  self.flush_surrogate()
  let cp = self.effective_codepage()
  if b < 128 {
    if b == 0 {
      self.report("nul_text", Warning, "NUL in text was omitted", span)
    } else {
      self.append_scalar(b, span)
    }
  } else if cp == 1252 {
    match decode_1252(b) {
      Some(scalar) => self.append_scalar(scalar, span)
      None => {
        self.report(
          "undefined_codepoint",
          Error,
          "Undefined Windows-1252 byte",
          span,
        )
        self.append_scalar(0xFFFD, span)
      }
    }
  } else {
    self.warn_once(
      "unsupported_codepage_\{cp}",
      "Code page \{cp} is not supported; affected bytes become replacement characters",
      span,
    )
    self.complete = false
    self.append_scalar(0xFFFD, span)
  }
}
