///|
fn main {
  let result = @rtf.parse(b"{\\rtf1 Hello {\\b MoonRTF}! \\u20013?\\u25991?}")
  println(result.document.to_text())
  println(result.document.to_markdown())
  println(result.document.statistics().to_text())
}
