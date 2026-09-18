///|
test "binary braces are not group tokens" {
  let lex = Lexer::new(b"{\\rtf1\\bin3 {}\\}")
  assert_eq(lex.next().kind, Open)
  assert_eq(lex.next().kind, Word("rtf", Some(1)))
  assert_eq(lex.next().kind, Word("bin", Some(3)))
  let binary = lex.next()
  assert_eq(binary.kind, Binary)
  assert_eq(binary.span.length(), 3)
  assert_eq(lex.next().kind, Close)
}

///|
test "overflow and truncation are bounded diagnostics" {
  assert_eq(
    Lexer::new(b"\\u999999999999999999999").next().kind,
    Bad("parameter_overflow"),
  )
  assert_eq(Lexer::new(b"\\").next().kind, Bad("truncated_escape"))
  assert_eq(Lexer::new(b"\\'f").next().kind, Bad("truncated_hex"))
  let lex = Lexer::new(b"\\bin8 a")
  let _ = lex.next()
  assert_eq(lex.next().kind, Bad("truncated_binary"))
}

///|
test "control parameters and single delimiter space" {
  let lex = Lexer::new(b"\\u-32768  x")
  assert_eq(lex.next().kind, Word("u", Some(-32768)))
  let t = lex.next()
  assert_eq(byte_string(lex.input, t.span.start, t.span.end), " x")
}

///|
test "byte locations treat CRLF as one line break" {
  let p = locate(b"a\r\nb\rc\nd", 8)
  assert_eq(p.line, 4)
  assert_eq(p.column, 2)
}
