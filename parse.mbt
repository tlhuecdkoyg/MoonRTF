///|
/// Parse a bounded RTF byte buffer. Recovery never bypasses resource limits.
pub fn parse(
  input : Bytes,
  recover? : Bool = false,
  limits? : Limits = Limits::default(),
) -> ParseResult {
  let parser = Parser::new(input, limits, recover)
  if !limits.valid() {
    parser.report(
      "invalid_limits",
      Error,
      "All resource limits must be positive",
      { start: 0, end: 0, },
    )
    parser.stopped = true
  } else if input.length() > limits.input_bytes {
    parser.report("input_limit", Error, "Input byte limit exceeded", {
      start: 0,
      end: 0,
    })
    parser.stopped = true
  }
  while !parser.stopped {
    let token = parser.lexer.next()
    if token.kind == End {
      break
    }
    parser.consume(token)
  }
  parser.flush_utf8()
  parser.flush_surrogate()
  parser.finish_paragraph(parser.lexer.pos, false)
  let end : Span = { start: parser.lexer.pos, end: parser.lexer.pos, }
  if !parser.stopped {
    if !parser.stack.is_empty() {
      parser.report(
        "unclosed_group",
        Error,
        "Input ended before all groups were closed",
        end,
      )
    }
    if !parser.seen_version {
      parser.report(
        "missing_header",
        Error,
        "Input does not contain an RTF version header",
        end,
      )
    }
  }
  {
    document: {
      paragraphs: parser.paragraphs,
      fonts: parser.fonts,
      colors: parser.colors,
      metadata: parser.metadata,
      attachments: parser.attachments,
      input_bytes: input.length(),
    },
    diagnostics: parser.diagnostics,
    complete: parser.complete,
  }
}

///|
fn Parser::consume(self : Parser, token : Token) -> Unit {
  let span = token.span
  if self.stack.is_empty() {
    match token.kind {
      Open | Close | Text | End => ()
      _ => {
        self.report(
          "control_outside_root",
          Error,
          "Escapes and controls must occur inside the root group",
          span,
        )
        return
      }
    }
  }
  if !self.seen_version {
    match token.kind {
      Word(name, _) if name != "rtf" => {
        self.report(
          "header_order",
          Error,
          "The first control word must be the RTF version header",
          span,
        )
        if self.stopped {
          return
        }
      }
      Hex(_) | Symbol(_) | Binary => {
        self.report(
          "header_order",
          Error,
          "Escapes must follow the RTF header",
          span,
        )
        return
      }
      Open if !self.stack.is_empty() => {
        self.report(
          "header_order",
          Error,
          "Nested groups must follow the RTF header",
          span,
        )
        if self.stopped {
          return
        }
      }
      _ => ()
    }
  }
  match token.kind {
    Open => {
      self.flush_utf8()
      self.fallback = 0
      self.flush_surrogate()
      self.flush_run()
      if self.closed_root {
        self.report(
          "extra_root",
          Error,
          "Only one root group is permitted",
          span,
        )
        self.stopped = true
        return
      }
      if self.stack.length() >= self.limits.depth {
        self.report("depth_limit", Error, "Group nesting limit exceeded", span)
        self.stopped = true
        return
      }
      self.stack.push(self.state)
      self.state = self.state.child(span.start)
    }
    Close => {
      self.flush_utf8()
      self.fallback = 0
      self.flush_surrogate()
      self.flush_run()
      if self.stack.pop() is Some(parent) {
        self.close_destination(span)
        if self.stack.is_empty() {
          self.finish_paragraph(span.end, false)
          self.closed_root = true
        }
        self.state = parent
      } else {
        self.report(
          "unexpected_close",
          Error,
          "Closing brace has no matching open group",
          span,
        )
      }
    }
    Bad(code) => self.report(code, Error, "Malformed RTF token: \{code}", span)
    Text =>
      for i in span.start..<span.end {
        if self.stopped {
          break
        }
        let b = self.input[i].to_int()
        if self.stack.is_empty() {
          if b != 10 && b != 13 && b != 32 && b != 9 {
            self.report(
              "text_outside_root",
              Error,
              "Non-whitespace text outside the root group",
              { start: i, end: i + 1, },
            )
          }
        } else if !self.seen_version {
          if b != 10 && b != 13 && b != 32 && b != 9 {
            self.report(
              "header_order",
              Error,
              "Text must follow the RTF header",
              { start: i, end: i + 1, },
            )
          }
        } else {
          self.emit_byte(b, { start: i, end: i + 1, })
        }
      }
    Hex(b) => self.emit_byte(b, span)
    Word(name, value) =>
      if self.stack.is_empty() {
        self.report(
          "control_outside_root",
          Error,
          "Control word outside the root group",
          span,
        )
      } else if self.fallback > 0 {
        self.fallback -= 1
      } else {
        self.control(name, value, span)
      }
    Symbol(symbol) =>
      if self.fallback > 0 {
        self.fallback -= 1
      } else {
        self.symbol(symbol, span)
      }
    Binary => ()
    End => ()
  }
}

///|
fn Parser::symbol(self : Parser, symbol : Int, span : Span) -> Unit {
  self.flush_utf8()
  if self.state.destination == "skip" {
    return
  }
  if symbol == 42 {
    self.state.starred = true
    return
  }
  self.flush_surrogate()
  match symbol {
    92 | 123 | 125 => self.append_scalar(symbol, span)
    126 => self.append_scalar(0xA0, span)
    95 => self.append_scalar(0x2011, span)
    45 => self.append_scalar(0xAD, span)
    10 | 13 => self.finish_paragraph(span.end, true)
    _ =>
      self.warn_once(
        "unknown_symbol_\{symbol}",
        "Unrecognized control symbol was omitted",
        span,
      )
  }
}

///|
pub fn extract_text(
  input : Bytes,
  recover? : Bool = false,
  include_hidden? : Bool = false,
) -> String {
  let parsed = parse(input, recover~)
  let out = StringBuilder()
  let mut first = true
  for paragraph in parsed.document.paragraphs {
    if paragraph.region != Body {
      continue
    }
    if !first {
      out.write_char('\n')
    }
    first = false
    out.write_string(paragraph.text(include_hidden~))
  }
  out.to_string()
}
