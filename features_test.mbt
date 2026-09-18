///|
test "search finds matches across style boundaries" {
  let document = @MoonRTF.parse(b"{\\rtf1 he{\\b llo} hello}").document
  let matches = document.find_text("hello")
  assert_eq(matches.length(), 2)
  assert_eq(matches[0].output, { start: 0, end: 5, })
  assert_eq(matches[0].sources.length(), 2)
  assert_eq(
    document.mapped_text().find_all("HELLO", ascii_insensitive=true).length(),
    2,
  )
}

///|
test "search handles overlap and UTF16 offsets" {
  let mapped = @MoonRTF.parse(b"{\\rtf1\\u-10179?\\u-8704?ababa}").document.mapped_text()
  assert_eq(mapped.find_all("aba").length(), 1)
  assert_eq(mapped.find_all("aba", overlapping=true).length(), 2)
  assert_eq(mapped.find_all("aba")[0].output.start, 2)
  assert_eq(mapped.find_all("", max_matches=10).length(), 0)
  assert_eq(mapped.find_all("a", max_matches=1).length(), 1)
}

///|
test "semantic HTML escapes content and balances table tags" {
  let document = @MoonRTF.parse(b"{\\rtf1\\trowd <a>\\cell {\\b B}\\cell\\row}").document
  let html = document.to_html()
  assert_true(html.contains("&lt;a&gt;"))
  assert_true(html.contains("<strong>B</strong>"))
  assert_true(html.contains("</td></tr></tbody></table>"))
  assert_true(!html.contains("<a>"))
}

///|
test "source excerpts escape nonprintable bytes and stay bounded" {
  let bytes = Bytes::make(10000, b'\x01')
  let text = @MoonRTF.source_excerpt(bytes, { start: 0, end: 10000, })
  assert_true(text.length() < 1000)
  assert_true(text.contains("\\x01"))
}

///|
test "every truncation of an RTF document remains bounded" {
  let input = b"{\\rtf1{\\fonttbl{\\f0 Arial;}}\\u20013?{\\b x}\\bin3 {}\\}"
  for length in 0..<=input.length() {
    let bytes = Bytes::makei(length, i => input[i])
    let result = @MoonRTF.parse(bytes, recover=true)
    assert_true(result.diagnostics.length() <= 1000)
    for diagnostic in result.diagnostics {
      assert_true(diagnostic.span.start >= 0)
      assert_true(diagnostic.span.end <= length)
    }
  }
}

///|
test "all limit families refuse work rather than silently succeeding" {
  let base = @MoonRTF.Limits::default()
  let cases = [
    { ..base, input_bytes: 1, },
    { ..base, nodes: 1, },
    { ..base, output_units: 1, },
    { ..base, depth: 1, },
    { ..base, diagnostics: 0, },
  ]
  for limits in cases {
    assert_true(
      !@MoonRTF.parse(b"{\\rtf1{ab}\\par cd}", limits~, recover=true).complete,
    )
  }
}
