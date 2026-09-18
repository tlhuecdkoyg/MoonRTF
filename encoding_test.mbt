///|
test "explicit UTF8 handles raw bytes and hex escape sequences" {
  let raw = @MoonRTF.parse(b"{\\rtf1\\ansicpg65001 \xe4\xb8\xad\xe6\x96\x87}")
  assert_true(raw.acceptable())
  assert_eq(raw.document.to_text(), "中文")
  assert_eq(
    @MoonRTF.extract_text(b"{\\rtf1\\ansicpg65001 \\'f0\\'9f\\'98\\'80}"),
    "😀",
  )
}

///|
test "invalid UTF8 sequences are diagnosed" {
  let inputs = [
    b"{\\rtf1\\ansicpg65001 \xc0\xaf}", b"{\\rtf1\\ansicpg65001 \xed\xa0\x80}", b"{\\rtf1\\ansicpg65001 \xf4\x90\x80\x80}",
    b"{\\rtf1\\ansicpg65001 \xe4}", b"{\\rtf1\\ansicpg65001 \xe4\\b x}",
  ]
  for input in inputs {
    let parsed = @MoonRTF.parse(input, recover=true)
    assert_true(parsed.has_errors())
    assert_true(!parsed.complete)
  }
}

///|
test "unsupported legacy encoding is not silently decoded as CP1252" {
  let r = @MoonRTF.parse(b"{\\rtf1\\ansicpg936 \\'d6\\'d0}", recover=true)
  assert_true(!r.complete)
  assert_true(r.diagnostics.any(d => d.code == "unsupported_codepage_936"))
}

///|
test "document times preserve local time without inventing timezone" {
  let r = @MoonRTF.parse(
    b"{\\rtf1{\\info{\\creatim\\yr2024\\mo2\\dy29\\hr12\\min30}{\\revtim\\yr2026\\mo9\\dy19}}body}",
  )
  assert_true(r.acceptable())
  assert_eq(r.document.created_time().unwrap().to_iso(), "2024-02-29T12:30:00")
  assert_eq(r.document.revised_time().unwrap().to_iso(), "2026-09-19T00:00:00")
}

///|
test "invalid dates are omitted with a useful diagnostic" {
  let r = @MoonRTF.parse(b"{\\rtf1{\\info{\\creatim\\yr2023\\mo2\\dy29}}x}")
  assert_eq(r.document.created_time(), None)
  assert_true(r.diagnostics.any(d => d.code == "invalid_timestamp"))
  assert_true(
    @MoonRTF.explain_diagnostics(b"x", r.diagnostics).contains("hint:"),
  )
  assert_eq(@MoonRTF.DocumentTime::from_iso("2024-13-01T00:00:00"), None)
}
