///|
test "invalid options do not silently become paths" {
  assert_true(@cli.parse_args(["text", "--typo"]) is Err(_))
  assert_true(@cli.parse_args(["text", "--max-input", "-1"]) is Err(_))
  assert_true(
    @cli.parse_args(["text", "--max-input", "99999999999999"]) is Err(_),
  )
  assert_true(@cli.parse_args(["text", "a", "b"]) is Err(_))
  assert_true(@cli.parse_args(["text", "a", "-o", "a"]) is Err(_))
  assert_true(@cli.parse_args(["text", "--pretty"]) is Err(_))
}

///|
test "end of options and numeric limits" {
  let options = @cli.parse_args([
    "json", "--pretty", "--max-depth", "12", "--", "-file.rtf",
  ]).unwrap()
  assert_eq(options.input, "-file.rtf")
  assert_eq(options.limits.depth, 12)
  assert_true(options.pretty)
}

///|
test "pure command reports failures with no silent success" {
  let options = @cli.parse_args(["text"]).unwrap()
  assert_eq(@cli.execute(b"{\\rtf1 abc}", options).text, "abc")
  assert_eq(@cli.execute(b"bad", options).exit_code, 1)
  assert_eq(@cli.execute(b"bad", options).text, "")
  let options = @cli.parse_args(["text", "--max-output", "2"]).unwrap()
  assert_eq(@cli.execute(b"{\\rtf1 abc}", options).exit_code, 1)
}
