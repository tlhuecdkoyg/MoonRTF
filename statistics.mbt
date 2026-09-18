///|
pub(all) struct Statistics {
  input_bytes : Int
  paragraphs : Int
  runs : Int
  characters : Int
  hidden_characters : Int
  words : Int
  tables : Int
  rows : Int
  cells : Int
  links : Int
  fonts : Int
  colors : Int
  attachments : Int
  body_paragraphs : Int
  header_paragraphs : Int
  footer_paragraphs : Int
  note_paragraphs : Int
} derive(Eq, Debug, ToJson)

///|
fn word_space(c : Char) -> Bool {
  match c.to_int() {
    9
    | 10
    | 11
    | 12
    | 13
    | 32
    | 0x85
    | 0xA0
    | 0x1680
    | 0x2000
    | 0x2001
    | 0x2002
    | 0x2003
    | 0x2004
    | 0x2005
    | 0x2006
    | 0x2007
    | 0x2008
    | 0x2009
    | 0x200A
    | 0x2028
    | 0x2029
    | 0x202F
    | 0x205F
    | 0x3000 => true
    _ => false
  }
}

///|
/// Words are whitespace-delimited segments, not language-specific segmentation.
pub fn Document::statistics(self : Document) -> Statistics {
  let mut runs = 0
  let mut characters = 0
  let mut hidden_characters = 0
  let mut words = 0
  let mut body = 0
  let mut headers = 0
  let mut footers = 0
  let mut notes = 0
  for paragraph in self.paragraphs {
    match paragraph.region {
      Body => body += 1
      Header => headers += 1
      Footer => footers += 1
      Footnote | Annotation => notes += 1
    }
    let mut in_word = false
    runs += paragraph.runs.length()
    for run in paragraph.runs {
      for c in run.text.iter() {
        characters += 1
        if run.style.hidden {
          hidden_characters += 1
        } else if word_space(c) {
          in_word = false
        } else if !in_word {
          words += 1
          in_word = true
        }
      }
    }
  }
  let tables = self.tables()
  let mut rows = 0
  let mut cells = 0
  for table in tables {
    rows += table.rows.length()
    for row in table.rows {
      cells += row.cells.length()
    }
  }
  {
    input_bytes: self.input_bytes,
    paragraphs: self.paragraphs.length(),
    runs,
    characters,
    hidden_characters,
    words,
    tables: tables.length(),
    rows,
    cells,
    links: self.links().length(),
    fonts: self.fonts.length(),
    colors: self.colors.length(),
    attachments: self.attachments.length(),
    body_paragraphs: body,
    header_paragraphs: headers,
    footer_paragraphs: footers,
    note_paragraphs: notes,
  }
}

///|
pub fn Statistics::to_text(self : Statistics) -> String {
  let out = StringBuilder()
  out.write_string("Input bytes: \{self.input_bytes}\n")
  out.write_string("Paragraphs: \{self.paragraphs}\n")
  out.write_string("Runs: \{self.runs}\n")
  out.write_string("Unicode scalars: \{self.characters}\n")
  out.write_string("Hidden scalars: \{self.hidden_characters}\n")
  out.write_string("Whitespace-delimited words: \{self.words}\n")
  out.write_string("Tables: \{self.tables}\n")
  out.write_string("Rows: \{self.rows}\n")
  out.write_string("Cells: \{self.cells}\n")
  out.write_string("Unique links: \{self.links}\n")
  out.write_string("Fonts: \{self.fonts}\n")
  out.write_string("Colors: \{self.colors}\n")
  out.write_string("Attachments: \{self.attachments}\n")
  out.write_string(
    "Regions: body=\{self.body_paragraphs}, headers=\{self.header_paragraphs}, footers=\{self.footer_paragraphs}, notes=\{self.note_paragraphs}\n",
  )
  out.to_string()
}

///|
pub fn ParseResult::inspect(self : ParseResult) -> String {
  let out = StringBuilder()
  out.write_string("MoonRTF document inspection\n")
  out.write_string("Complete: \{self.complete}\n")
  out.write_string(self.document.statistics().to_text())
  for item in self.document.metadata {
    out.write_string("Metadata \{item.key}: \{item.value}\n")
  }
  for font in self.document.fonts {
    out.write_string(
      "Font \{font.id}: \{font.name} (charset \{font.charset})\n",
    )
  }
  for attachment in self.document.attachments {
    out.write_string(
      "Embedded \{attachment.kind}: bytes \{attachment.span.start}..\{attachment.span.end}\n",
    )
  }
  for d in self.diagnostics {
    out.write_string("\{d.code} at byte \{d.span.start}: \{d.message}\n")
  }
  out.to_string()
}
