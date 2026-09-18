///|
test "text rendering uses table cell separators" {
  let r = @MoonRTF.parse(b"{\\rtf1\\trowd A\\cell B\\cell\\row\\pard End}")
  assert_eq(r.document.to_text(), "A\tB\nEnd")
  assert_eq(r.document.tables().length(), 1)
  assert_eq(r.document.tables()[0].to_csv(), "A,B\r\n")
}

///|
test "markdown escapes source and omits unsafe links" {
  let r = @MoonRTF.parse(b"{\\rtf1 <script> {\\b bold} *x*}")
  assert_eq(r.document.to_markdown(), "&lt;script&gt; **bold** \\*x\\*")
  let unsafe_link = @MoonRTF.parse(
    b"{\\rtf1{\\field{\\*\\fldinst HYPERLINK \"javascript:alert(1)\"}{\\fldrslt click}}}",
  )
  assert_eq(unsafe_link.document.to_markdown(), "click")
  assert_true(unsafe_link.document.validate().any(d => d.code == "unsafe_link"))
}

///|
test "JSON schema uses scalar strings and null optional fields" {
  let text = @MoonRTF.parse(b"{\\rtf1 hello}").to_json_text()
  assert_true(text.contains("moonrtf.document.v1"))
  assert_true(text.contains("\"region\":\"body\""))
  assert_true(text.contains("\"link\":null"))
}

///|
test "source mapping distinguishes inserted separators" {
  let mapped = @MoonRTF.parse(b"{\\rtf1 a\\par b}").document.mapped_text()
  assert_eq(mapped.text, "a\nb")
  assert_true(mapped.source_at(0) is Some(_))
  assert_eq(mapped.source_at(1), None)
  assert_true(mapped.source_at(2) is Some(_))
  assert_eq(mapped.source_at(3), None)
}

///|
test "scan stops at token limit and preserves binary span" {
  let r = @MoonRTF.scan(b"{\\rtf1 x}", max_tokens=2)
  assert_true(r.truncated)
  assert_eq(r.tokens.length(), 2)
  assert_eq(@MoonRTF.scan(b"{\\rtf1 x}").maximum_depth, 1)
}

///|
test "validation warns about undeclared colors" {
  let report = @MoonRTF.validate(b"{\\rtf1\\cf9 x}", fail_on_warning=true)
  assert_true(!report.valid)
  assert_true(report.diagnostics.any(d => d.code == "undefined_color"))
}

///|
test "statistics count scalars and words across runs" {
  let s = @MoonRTF.parse(b"{\\rtf1 he{\\b llo} world\\u-10179?\\u-8704?}").document.statistics()
  assert_eq(s.words, 2)
  assert_eq(s.characters, 12)
}
