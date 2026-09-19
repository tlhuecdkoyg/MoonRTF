///|
test "HTML command escapes source text and filters hidden content" {
  let input = b"{\\rtf1 <script>{\\b bold}{\\v secret}{\\header Heading}}"
  let options = @cli.parse_args(["html"]).unwrap()
  let result = @cli.execute(input, options)
  assert_eq(result.exit_code, 0)
  assert_true(result.text.contains("&lt;script&gt;"))
  assert_true(result.text.contains("<strong>bold</strong>"))
  assert_true(!result.text.contains("secret"))
  assert_true(!result.text.contains("Heading"))
  let options = @cli.parse_args([
    "html", "--include-hidden", "--include-headers",
  ]).unwrap()
  let result = @cli.execute(input, options)
  assert_true(result.text.contains("secret"))
  assert_true(result.text.contains("Heading"))
}

///|
test "HTML command preserves diagnostics limits and recovery status" {
  let options = @cli.parse_args(["html"]).unwrap()
  let result = @cli.execute(b"{\\rtf1 truncated", options)
  assert_eq(result.exit_code, 1)
  assert_eq(result.text, "")
  let options = @cli.parse_args(["html", "--recover"]).unwrap()
  let result = @cli.execute(b"{\\rtf1 truncated", options)
  assert_eq(result.exit_code, 1)
  assert_true(result.text.contains("truncated"))
  let options = @cli.parse_args(["html", "--max-output", "1"]).unwrap()
  let result = @cli.execute(b"{\\rtf1 x}", options)
  assert_eq(result.exit_code, 1)
  assert_eq(result.text, "")
  assert_true(@cli.parse_args(["html", "--pretty"]) is Err(_))
}

///|
test "HTML command renders safe hyperlinks and suppresses active schemes" {
  let options = @cli.parse_args(["html"]).unwrap()
  let safe = @cli.execute(
    b"{\\rtf1{\\field{\\*\\fldinst HYPERLINK \"https://example.com/?a=1&b=2\"}{\\fldrslt visit}}}",
    options,
  )
  assert_true(safe.text.contains("href=\"https://example.com/?a=1&amp;b=2\""))
  let blocked = @cli.execute(
    b"{\\rtf1{\\field{\\*\\fldinst HYPERLINK \"javascript:alert(1)\"}{\\fldrslt visit}}}",
    options,
  )
  assert_true(blocked.text.contains("visit"))
  assert_true(!blocked.text.contains("href="))
}
