///|
test "conversion loss report explains flattened formatting" {
  let parsed = @MoonRTF.parse(b"{\\rtf1\\ul underlined}")
  let conversion = parsed.convert(Markdown)
  assert_eq(conversion.content, "underlined")
  assert_true(conversion.diagnostics.any(d => d.code == "markdown_underline"))
  assert_true(
    !parsed.convert(Html).diagnostics.any(d => d.code == "markdown_underline"),
  )
}

///|
test "conversion output limit never returns partial JSON" {
  let conversion = @MoonRTF.parse(b"{\\rtf1 a}").convert(
    StructuredJson,
    max_output_units=1,
  )
  assert_true(conversion.exceeded_limit)
  assert_eq(conversion.content, "")
}

///|
test "binary declaration at end is detected by the scanner" {
  let scan = @MoonRTF.scan(b"{\\rtf1\\bin3")
  assert_true(scan.diagnostics.any(d => d.code == "truncated_binary"))
}
