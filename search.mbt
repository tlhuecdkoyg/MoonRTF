///|
pub(all) struct TextMatch {
  output : Span
  sources : Array[Span]
  paragraphs : Array[Int]
} derive(Eq, Debug, ToJson)

///|
fn ascii_fold(value : Int, insensitive : Bool) -> Int {
  if insensitive && value >= 65 && value <= 90 {
    value + 32
  } else {
    value
  }
}

///|
fn prefix_table(pattern : Array[Int]) -> Array[Int] {
  let table = Array::make(pattern.length(), 0)
  let mut matched = 0
  for i in 1..<pattern.length() {
    while matched > 0 && pattern[i] != pattern[matched] {
      matched = table[matched - 1]
    }
    if pattern[i] == pattern[matched] {
      matched += 1
    }
    table[i] = matched
  }
  table
}

///|
fn MappedText::match_range(
  self : MappedText,
  start : Int,
  end : Int,
) -> TextMatch {
  let sources : Array[Span] = []
  let paragraphs : Array[Int] = []
  let mut low = 0
  let mut high = self.mappings.length()
  while low < high {
    let mid = low + (high - low) / 2
    if self.mappings[mid].output_end <= start {
      low = mid + 1
    } else {
      high = mid
    }
  }
  let mut index = low
  while index < self.mappings.length() {
    let mapping = self.mappings[index]
    if mapping.output_start >= end {
      break
    }
    if mapping.output_end > start {
      sources.push(mapping.source)
      if paragraphs.is_empty() ||
        paragraphs[paragraphs.length() - 1] != mapping.paragraph {
        paragraphs.push(mapping.paragraph)
      }
    }
    index += 1
  }
  { output: { start, end, }, sources, paragraphs, }
}

///|
/// Linear-time exact search across style runs. Ranges use UTF-16 units.
/// ASCII-insensitive mode deliberately avoids length-changing Unicode folding.
pub fn MappedText::find_all(
  self : MappedText,
  needle : String,
  ascii_insensitive? : Bool = false,
  max_matches? : Int = 1000,
  overlapping? : Bool = false,
) -> Array[TextMatch] {
  let result : Array[TextMatch] = []
  if needle.is_empty() || max_matches <= 0 {
    return result
  }
  let pattern : Array[Int] = []
  let offsets : Array[Int] = []
  let mut pattern_units = 0
  for c in needle.iter() {
    pattern.push(ascii_fold(c.to_int(), ascii_insensitive))
    pattern_units += if c.to_int() > 65535 { 2 } else { 1 }
  }
  let prefix = prefix_table(pattern)
  let mut matched = 0
  let mut offset = 0
  for c in self.text.iter() {
    let scalar = ascii_fold(c.to_int(), ascii_insensitive)
    let width = if c.to_int() > 65535 { 2 } else { 1 }
    offset += width
    while matched > 0 && scalar != pattern[matched] {
      matched = prefix[matched - 1]
    }
    if scalar == pattern[matched] {
      matched += 1
    }
    if matched == pattern.length() {
      offsets.push(offset - pattern_units)
      if offsets.length() >= max_matches {
        break
      }
      matched = if overlapping { prefix[matched - 1] } else { 0 }
    }
  }
  for start in offsets {
    result.push(self.match_range(start, start + pattern_units))
  }
  result
}

///|
pub fn Document::find_text(
  self : Document,
  needle : String,
  include_hidden? : Bool = false,
  region? : Region = Body,
  max_matches? : Int = 1000,
) -> Array[TextMatch] {
  self.mapped_text(include_hidden~, region~).find_all(needle, max_matches~)
}

///|
/// Show an escaped source excerpt with a bounded byte radius.
pub fn source_excerpt(input : Bytes, span : Span, radius? : Int = 32) -> String {
  let radius = radius.max(0).min(1024)
  let start = (span.start.max(0).min(input.length()) - radius).max(0)
  let stop = span.end.max(start).min(input.length()).min(start + 128)
  let end = stop + radius.min(input.length() - stop)
  let out = StringBuilder()
  if start > 0 {
    out.write_string("...")
  }
  for i in start..<end {
    let value = input[i].to_int()
    match value {
      10 => out.write_string("\\n")
      13 => out.write_string("\\r")
      9 => out.write_string("\\t")
      92 => out.write_string("\\\\")
      _ =>
        if value >= 32 && value < 127 {
          out.write_char(value.unsafe_to_char())
        } else {
          let hex = "0123456789abcdef".to_array()
          out.write_string("\\x")
          out.write_char(hex[value / 16])
          out.write_char(hex[value % 16])
        }
    }
  }
  if end < input.length() {
    out.write_string("...")
  }
  out.to_string()
}
