///|
priv enum TokenKind {
  Open
  Close
  Word(String, Int?)
  Symbol(Int)
  Hex(Int)
  Text
  Binary
  Bad(String)
  End
} derive(Eq, Debug)

///|
priv struct Token {
  kind : TokenKind
  span : Span
}

///|
priv struct Lexer {
  input : Bytes
  mut pos : Int
  mut binary_remaining : Int
}

///|
fn Lexer::new(input : Bytes) -> Lexer {
  { input, pos: 0, binary_remaining: 0, }
}

///|
fn ascii_letter(n : Int) -> Bool {
  (n >= 65 && n <= 90) || (n >= 97 && n <= 122)
}

///|
fn ascii_digit(n : Int) -> Bool {
  n >= 48 && n <= 57
}

///|
fn hex_digit(n : Int) -> Int? {
  if n >= 48 && n <= 57 {
    Some(n - 48)
  } else if n >= 65 && n <= 70 {
    Some(n - 55)
  } else if n >= 97 && n <= 102 {
    Some(n - 87)
  } else {
    None
  }
}

///|
fn byte_string(input : Bytes, start : Int, end : Int) -> String {
  let out = StringBuilder()
  for i in start..<end {
    out.write_char(input[i].to_int().unsafe_to_char())
  }
  out.to_string()
}

///|
fn Lexer::token(self : Lexer, start : Int, kind : TokenKind) -> Token {
  { kind, span: { start, end: self.pos, }, }
}

///|
fn Lexer::next(self : Lexer) -> Token {
  let n = self.input.length()
  let start = self.pos
  if self.binary_remaining > 0 {
    let count = self.binary_remaining
    self.binary_remaining = 0
    if count > n - self.pos {
      self.pos = n
      return self.token(start, Bad("truncated_binary"))
    }
    self.pos += count
    return self.token(start, Binary)
  }
  if self.pos >= n {
    return self.token(start, End)
  }
  let b = self.input[self.pos].to_int()
  self.pos += 1
  if b == 123 {
    return self.token(start, Open)
  }
  if b == 125 {
    return self.token(start, Close)
  }
  if b != 92 {
    while self.pos < n {
      let c = self.input[self.pos].to_int()
      if c == 123 || c == 125 || c == 92 {
        break
      }
      self.pos += 1
    }
    return self.token(start, Text)
  }
  if self.pos >= n {
    return self.token(start, Bad("truncated_escape"))
  }
  let c = self.input[self.pos].to_int()
  self.pos += 1
  if c == 39 {
    if n - self.pos < 2 {
      self.pos = n
      return self.token(start, Bad("truncated_hex"))
    }
    let hi = hex_digit(self.input[self.pos].to_int())
    let lo = hex_digit(self.input[self.pos + 1].to_int())
    // Do not swallow syntax after a malformed hex escape.
    match (hi, lo) {
      (Some(a), Some(b)) => {
        self.pos += 2
        return self.token(start, Hex(a * 16 + b))
      }
      _ => return self.token(start, Bad("invalid_hex"))
    }
  }
  if !ascii_letter(c) {
    return self.token(start, Symbol(c))
  }
  let name_start = self.pos - 1
  while self.pos < n && ascii_letter(self.input[self.pos].to_int()) {
    self.pos += 1
  }
  let name_end = self.pos
  if name_end - name_start > 32 {
    return self.token(start, Bad("control_word_too_long"))
  }
  let name = byte_string(self.input, name_start, name_end)
  let mut negative = false
  if self.pos + 1 < n &&
    self.input[self.pos].to_int() == 45 &&
    ascii_digit(self.input[self.pos + 1].to_int()) {
    negative = true
    self.pos += 1
  }
  let number_start = self.pos
  let mut value : Int64 = 0
  let mut overflow = false
  while self.pos < n && ascii_digit(self.input[self.pos].to_int()) {
    let digit = self.input[self.pos].to_int() - 48
    if value > 214748364L {
      overflow = true
    } else {
      value = value * 10 + digit.to_int64()
    }
    self.pos += 1
  }
  let has_number = self.pos > number_start
  if negative {
    value = -value
  }
  if value < -2147483648L || value > 2147483647L {
    overflow = true
  }
  if self.pos < n && self.input[self.pos].to_int() == 32 {
    self.pos += 1
  }
  if overflow {
    return self.token(start, Bad("parameter_overflow"))
  }
  let param = if has_number { Some(value.to_int()) } else { None }
  if name == "bin" {
    match param {
      Some(size) if size >= 0 => self.binary_remaining = size
      _ => return self.token(start, Bad("invalid_binary_length"))
    }
  }
  self.token(start, Word(name, param))
}
