///|
pub(all) enum Severity {
  Warning
  Error
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Span {
  start : Int
  end : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Diagnostic {
  code : String
  severity : Severity
  message : String
  span : Span
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Limits {
  input_bytes : Int
  depth : Int
  nodes : Int
  output_units : Int
  diagnostics : Int
} derive(Eq, Debug, ToJson)

///|
pub fn Limits::default() -> Limits {
  {
    input_bytes: 32 * 1024 * 1024,
    depth: 256,
    nodes: 200000,
    output_units: 32 * 1024 * 1024,
    diagnostics: 1000,
  }
}

///|
pub fn Limits::valid(self : Limits) -> Bool {
  self.input_bytes > 0 && self.depth > 0 && self.nodes > 0 &&
  self.output_units > 0 && self.diagnostics > 0
}

///|
pub fn Span::length(self : Span) -> Int {
  self.end - self.start
}

///|
pub fn Span::contains(self : Span, offset : Int) -> Bool {
  offset >= self.start && offset < self.end
}

///|
pub fn Diagnostic::is_error(self : Diagnostic) -> Bool {
  self.severity == Error
}

///|
pub(all) struct Location {
  line : Int
  column : Int
  offset : Int
} derive(Eq, Debug, ToJson)

///|
/// Byte columns, not Unicode display columns. CRLF counts as one newline.
pub fn locate(input : Bytes, offset : Int) -> Location {
  let end = offset.max(0).min(input.length())
  let mut line = 1
  let mut column = 1
  let mut previous_cr = false
  for i in 0..<end {
    let b = input[i].to_int()
    if b == 13 {
      line += 1
      column = 1
      previous_cr = true
    } else if b == 10 {
      if !previous_cr {
        line += 1
      }
      column = 1
      previous_cr = false
    } else {
      column += 1
      previous_cr = false
    }
  }
  { line, column, offset: end }
}

///|
pub fn format_diagnostic(input : Bytes, d : Diagnostic) -> String {
  let pos = locate(input, d.span.start)
  let level = if d.is_error() { "error" } else { "warning" }
  "\{pos.line}:\{pos.column}: \{level}[\{d.code}]: \{d.message}"
}
