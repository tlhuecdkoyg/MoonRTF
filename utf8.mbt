///|
fn Parser::flush_utf8(self : Parser) -> Unit {
  if self.utf8_remaining == 0 {
    return
  }
  self.utf8_remaining = 0
  self.report(
    "truncated_utf8",
    Error,
    "Incomplete UTF-8 sequence before a syntax boundary",
    self.utf8_span,
  )
  self.append_scalar(0xFFFD, self.utf8_span)
}

///|
fn Parser::emit_utf8(self : Parser, byte : Int, span : Span) -> Unit {
  if self.utf8_remaining > 0 {
    if byte < 128 || byte > 191 {
      self.flush_utf8()
      if !self.stopped {
        self.emit_utf8(byte, span)
      }
      return
    }
    self.utf8_value = self.utf8_value * 64 + byte - 128
    self.utf8_span = { start: self.utf8_span.start, end: span.end, }
    self.utf8_remaining -= 1
    if self.utf8_remaining == 0 {
      let value = self.utf8_value
      if value < self.utf8_minimum ||
        value > 0x10FFFF ||
        (value >= 0xD800 && value <= 0xDFFF) {
        self.report(
          "invalid_utf8",
          Error,
          "UTF-8 sequence encodes an invalid scalar",
          self.utf8_span,
        )
        self.append_scalar(0xFFFD, self.utf8_span)
      } else {
        self.append_scalar(value, self.utf8_span)
      }
    }
    return
  }
  if byte < 128 {
    if byte != 0 {
      self.append_scalar(byte, span)
    } else {
      self.report("nul_text", Warning, "NUL in text was omitted", span)
    }
  } else if byte >= 194 && byte <= 223 {
    self.utf8_remaining = 1
    self.utf8_value = byte - 192
    self.utf8_minimum = 128
    self.utf8_span = span
  } else if byte >= 224 && byte <= 239 {
    self.utf8_remaining = 2
    self.utf8_value = byte - 224
    self.utf8_minimum = 2048
    self.utf8_span = span
  } else if byte >= 240 && byte <= 244 {
    self.utf8_remaining = 3
    self.utf8_value = byte - 240
    self.utf8_minimum = 65536
    self.utf8_span = span
  } else {
    self.report("invalid_utf8", Error, "Invalid UTF-8 leading byte", span)
    self.append_scalar(0xFFFD, span)
  }
}
