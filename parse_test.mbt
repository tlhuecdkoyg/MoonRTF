///|
test "header precedes text escapes and nested groups in both modes" {
  let invalid = [
    b"{text\\rtf1 body}", b"{\\'41\\rtf1 body}", b"{\\~\\rtf1 body}", b"{{}\\rtf1 body}",
    b"{{\\rtf1 body}}",
  ]
  for input in invalid {
    for recover in [false, true] {
      let result = @MoonRTF.parse(input, recover~)
      assert_true(result.has_errors())
      assert_true(!result.complete)
    }
  }
  assert_eq(@MoonRTF.extract_text(b"{\r\n\\rtf1 body}"), "body")
  assert_eq(@MoonRTF.extract_text(b"{text\\rtf1 body}", recover=true), "body")
}

///|
test "escapes outside the root and late headers are rejected" {
  assert_true(@MoonRTF.parse(b"{\\rtf1 x}\\'41").has_errors())
  assert_true(@MoonRTF.parse(b"{\\rtf1 x}\\{").has_errors())
  assert_true(@MoonRTF.parse(b"{\\b\\rtf1 x}").has_errors())
}

///|
test "plain paragraphs and styles preserve text" {
  let r = @MoonRTF.parse(b"{\\rtf1 Hello {\\b bold} world.\\par Next}")
  assert_true(r.acceptable())
  assert_eq(r.document.paragraphs.length(), 2)
  assert_eq(r.document.paragraphs[0].text(), "Hello bold world.")
  assert_true(r.document.paragraphs[0].runs.any(r => r.style.bold))
  assert_eq(@MoonRTF.extract_text(b"{\\rtf1 a\\par b}"), "a\nb")
}

///|
test "Unicode Chinese emoji and fallback counts" {
  assert_eq(@MoonRTF.extract_text(b"{\\rtf1\\uc1\\u20013?\\u25991?}"), "中文")
  assert_eq(@MoonRTF.extract_text(b"{\\rtf1\\u-10179?\\u-8704?}"), "😀")
  assert_eq(@MoonRTF.extract_text(b"{\\rtf1{\\uc0\\u945}\\u946?}"), "αβ")
  assert_eq(@MoonRTF.extract_text(b"{\\rtf1\\uc2\\u945\\'61\\'62x}"), "αx")
}

///|
test "skipped destinations do not leak and binary braces stay opaque" {
  let r = @MoonRTF.parse(b"{\\rtf1 a{\\*\\unknown hidden{nested}\\bin3 {}\\}b}")
  assert_eq(r.document.paragraphs[0].text(), "ab")
  assert_true(!r.has_errors())
}

///|
test "font and color tables are metadata not body" {
  let r = @MoonRTF.parse(
    b"{\\rtf1{\\fonttbl{\\f0\\fswiss Arial;}}{\\colortbl;\\red255\\green0\\blue0;}\\f0\\cf1 Hi}",
  )
  assert_true(r.acceptable())
  assert_eq(r.document.font(0).unwrap().name, "Arial")
  assert_eq(r.document.colors.length(), 2)
  assert_eq(r.document.paragraphs[0].text(), "Hi")
}

///|
test "fields preserve display text and hyperlink target" {
  let r = @MoonRTF.parse(
    b"{\\rtf1{\\field{\\*\\fldinst HYPERLINK \"https://example.com\"}{\\fldrslt Example}}}",
  )
  assert_true(r.acceptable())
  assert_eq(r.document.paragraphs[0].text(), "Example")
  assert_eq(r.document.links(), ["https://example.com"])
}

///|
test "simple tables have row and cell identities" {
  let r = @MoonRTF.parse(
    b"{\\rtf1\\trowd\\intbl A\\cell B\\cell\\row\\pard End}",
  )
  assert_eq(r.document.paragraphs[0].table_cell, Some(0))
  assert_eq(r.document.paragraphs[1].table_cell, Some(1))
  assert_eq(r.document.paragraphs[2].table_row, None)
}

///|
test "metadata and page regions stay separate" {
  let r = @MoonRTF.parse(
    b"{\\rtf1{\\info{\\title Title}{\\author Alice}}{\\header Header}Body}",
  )
  assert_eq(r.document.metadata_value("title"), Some("Title"))
  assert_eq(r.document.body_paragraphs().length(), 1)
  assert_eq(r.document.body_paragraphs()[0].text(), "Body")
}

///|
test "CP1252 escapes and hidden text" {
  assert_eq(@MoonRTF.extract_text(b"{\\rtf1 \\'80{\\v secret}text}"), "€text")
  assert_eq(
    @MoonRTF.extract_text(b"{\\rtf1{\\v secret}}", include_hidden=true),
    "secret",
  )
}

///|
test "malformed input and configured limits never report success" {
  assert_true(@MoonRTF.parse(b"{\\rtf1 x").has_errors())
  assert_true(@MoonRTF.parse(b"not rtf").has_errors())
  assert_true(@MoonRTF.parse(b"{\\rtf2 x}").has_errors())
  let limits = { ..@MoonRTF.Limits::default(), depth: 2, }
  assert_true(
    @MoonRTF.parse(b"{\\rtf1{{x}}}", limits~, recover=true).has_errors(),
  )
  let bad = @MoonRTF.parse(b"{\\rtf1\\u-10240?x}", recover=true)
  assert_true(!bad.complete)
  assert_eq(bad.document.paragraphs[0].text(), "�x")
}

///|
test "random bytes terminate within resource limits" {
  for seed in 0..<128 {
    let bytes = Bytes::makei(64, i => ((i * 37 + seed * 13) % 256).to_byte())
    let r = @MoonRTF.parse(bytes, recover=true)
    for d in r.diagnostics {
      assert_true(d.span.start >= 0 && d.span.end <= bytes.length())
    }
  }
}
