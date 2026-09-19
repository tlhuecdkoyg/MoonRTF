///|
test "selected ranges preserve multiple source runs and paragraph identities" {
  let mapped = @MoonRTF.parse(b"{\\rtf1 ab{\\b cd}\\par ef}").document.mapped_text()
  assert_eq(mapped.text, "abcd\nef")
  let selection = mapped.source_range(1, 6).unwrap()
  assert_eq(selection.output.start, 1)
  assert_eq(selection.output.end, 6)
  assert_eq(selection.sources.length(), 3)
  assert_eq(selection.paragraphs, [0, 1])
  assert_eq(Some(selection.sources[0]), mapped.source_at(1))
  assert_eq(Some(selection.sources[1]), mapped.source_at(2))
  assert_eq(Some(selection.sources[2]), mapped.source_at(5))
  assert_eq(mapped.source_range(4, 5).unwrap().sources, [])
  assert_eq(mapped.source_range(4, 5).unwrap().paragraphs, [])
}

///|
test "source selections reject invalid bounds without clamping" {
  let mapped = @MoonRTF.parse(b"{\\rtf1 abc}").document.mapped_text()
  for (start, end) in [(-1, 1), (0, 0), (2, 1), (0, 4), (3, 4), (0, 2147483647)] {
    assert_eq(mapped.source_range(start, end), None)
  }
  assert_true(mapped.source_range(0, 3) is Some(_))
  let empty = @MoonRTF.parse(b"{\\rtf1}").document.mapped_text()
  assert_eq(empty.source_range(0, 1), None)
}

///|
test "source selections use UTF16 units and respect hidden text filtering" {
  let document = @MoonRTF.parse(b"{\\rtf1\\u-10179?\\u-8704?{\\v secret}x}").document
  let mapped = document.mapped_text()
  assert_eq(mapped.text, "😀x")
  assert_eq(
    mapped.source_range(0, 1).unwrap().sources,
    mapped.source_range(1, 2).unwrap().sources,
  )
  assert_eq(mapped.source_range(0, 3).unwrap().sources.length(), 2)
  let hidden = document.mapped_text(include_hidden=true)
  assert_eq(hidden.text, "😀secretx")
  assert_eq(hidden.source_range(2, 8).unwrap().sources.length(), 1)
}
