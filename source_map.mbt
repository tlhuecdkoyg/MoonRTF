///|
pub(all) struct TextMapping {
  paragraph : Int
  run : Int
  output_start : Int
  output_end : Int
  source : Span
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MappedText {
  text : String
  mappings : Array[TextMapping]
} derive(Eq, Debug, ToJson)

///|
/// UTF-16 output ranges map to encompassing byte ranges, not one-to-one bytes.
pub fn Document::mapped_text(
  self : Document,
  include_hidden? : Bool = false,
  region? : Region = Body,
) -> MappedText {
  let out = StringBuilder()
  let mappings : Array[TextMapping] = []
  let mut offset = 0
  let mut first = true
  for p in 0..<self.paragraphs.length() {
    let paragraph = self.paragraphs[p]
    if paragraph.region != region {
      continue
    }
    if !first {
      out.write_char('\n')
      offset += 1
    }
    first = false
    for r in 0..<paragraph.runs.length() {
      let run = paragraph.runs[r]
      if !include_hidden && run.style.hidden {
        continue
      }
      let start = offset
      out.write_string(run.text)
      offset += run.text.length()
      mappings.push({
        paragraph: p,
        run: r,
        output_start: start,
        output_end: offset,
        source: run.span,
      })
    }
  }
  { text: out.to_string(), mappings, }
}

///|
pub fn MappedText::source_at(self : MappedText, output_offset : Int) -> Span? {
  if output_offset < 0 || output_offset >= self.text.length() {
    return None
  }
  let mut low = 0
  let mut high = self.mappings.length()
  while low < high {
    let mid = low + (high - low) / 2
    let mapping = self.mappings[mid]
    if output_offset < mapping.output_start {
      high = mid
    } else if output_offset >= mapping.output_end {
      low = mid + 1
    } else {
      return Some(mapping.source)
    }
  }
  None
}

///|
pub fn Document::runs_at_source(
  self : Document,
  byte_offset : Int,
) -> Array[Run] {
  let result : Array[Run] = []
  if byte_offset < 0 || byte_offset >= self.input_bytes {
    return result
  }
  for paragraph in self.paragraphs {
    for run in paragraph.runs {
      if run.span.contains(byte_offset) {
        result.push(run)
      }
    }
  }
  result
}

///|
pub fn MappedText::to_json_text(self : MappedText) -> String {
  Json::object({
    "schema": Json::string("moonrtf.source-map.v1"),
    "offset_unit": Json::string("utf16"),
    "text": Json::string(self.text),
    "mappings": Json::array(
      self.mappings.map(m => {
        Json::object({
          "paragraph": m.paragraph.to_json(),
          "run": m.run.to_json(),
          "output_start": m.output_start.to_json(),
          "output_end": m.output_end.to_json(),
          "source": span_json(m.source),
        })
      }),
    ),
  }).stringify()
}
