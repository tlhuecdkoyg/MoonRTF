///|
pub(all) struct TextOptions {
  include_hidden : Bool
  include_headers : Bool
  include_footers : Bool
  include_notes : Bool
  paragraph_separator : String
  cell_separator : String
  trim_trailing_space : Bool
} derive(Eq, Debug)

///|
pub fn TextOptions::default() -> TextOptions {
  {
    include_hidden: false,
    include_headers: false,
    include_footers: false,
    include_notes: false,
    paragraph_separator: "\n",
    cell_separator: "\t",
    trim_trailing_space: false,
  }
}

///|
fn TextOptions::accepts(self : TextOptions, region : Region) -> Bool {
  match region {
    Body => true
    Header => self.include_headers
    Footer => self.include_footers
    Footnote | Annotation => self.include_notes
  }
}

///|
fn trim_line_ends(text : String) -> String {
  let out = StringBuilder()
  let pending = StringBuilder()
  for c in text.iter() {
    match c {
      ' ' | '\t' => pending.write_char(c)
      '\n' => {
        pending.reset()
        out.write_char(c)
      }
      _ => {
        out.write_string(pending.to_string())
        pending.reset()
        out.write_char(c)
      }
    }
  }
  out.to_string()
}

///|
pub fn Document::to_text(
  self : Document,
  options? : TextOptions = TextOptions::default(),
) -> String {
  let out = StringBuilder()
  let mut previous : Paragraph? = None
  for paragraph in self.paragraphs {
    if !options.accepts(paragraph.region) {
      continue
    }
    if previous is Some(before) {
      if paragraph.table_row is Some(row) &&
        before.table_row == Some(row) &&
        paragraph.region == before.region &&
        paragraph.table_cell != before.table_cell {
        out.write_string(options.cell_separator)
      } else {
        out.write_string(options.paragraph_separator)
      }
    }
    let text = paragraph.text(include_hidden=options.include_hidden)
    if options.trim_trailing_space {
      out.write_string(trim_line_ends(text))
    } else {
      out.write_string(text)
    }
    previous = Some(paragraph)
  }
  out.to_string()
}

///|
pub fn region_name(region : Region) -> String {
  match region {
    Body => "body"
    Header => "header"
    Footer => "footer"
    Footnote => "footnote"
    Annotation => "annotation"
  }
}

///|
pub fn alignment_name(alignment : Alignment) -> String {
  match alignment {
    Left => "left"
    Right => "right"
    Center => "center"
    Justify => "justify"
  }
}

///|
fn safe_link(target : String) -> Bool {
  let lower = target.to_lower()
  if !(lower.has_prefix("https://") ||
    lower.has_prefix("http://") ||
    lower.has_prefix("mailto:") ||
    lower.has_prefix("#")) {
    return false
  }
  for c in target.iter() {
    if c.to_int() < 32 || c == '<' || c == '>' || c == '"' {
      return false
    }
  }
  true
}

///|
fn markdown_escape(text : String, table : Bool) -> String {
  let out = StringBuilder()
  for c in text.iter() {
    match c {
      '\\'
      | '`'
      | '*'
      | '_'
      | '{'
      | '}'
      | '['
      | ']'
      | '('
      | ')'
      | '#'
      | '+'
      | '-'
      | '.'
      | '!'
      | '|'
      | '~' => {
        out.write_char('\\')
        out.write_char(c)
      }
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '&' => out.write_string("&amp;")
      '\n' => out.write_string(if table { "<br>" } else { "  \n" })
      _ => out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn markdown_link(target : String) -> String {
  let out = StringBuilder()
  for c in target.iter() {
    match c {
      ' ' => out.write_string("%20")
      '(' => out.write_string("%28")
      ')' => out.write_string("%29")
      '\\' => out.write_string("%5C")
      _ => out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn markdown_run(run : Run, table : Bool) -> String {
  let escaped = markdown_escape(run.text, table)
  if escaped.is_empty() {
    return ""
  }
  let out = StringBuilder()
  // Leave boundary whitespace outside emphasis delimiters.
  let chars = escaped.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end &&
        (chars[start] == ' ' || chars[start] == '\t' || chars[start] == '\n') {
    start += 1
  }
  while end > start &&
        (
          chars[end - 1] == ' ' ||
          chars[end - 1] == '\t' ||
          chars[end - 1] == '\n'
        ) {
    end -= 1
  }
  out.write_string(String::from_array(chars[:start]))
  if start < end {
    let linked = match run.link {
      Some(link) => safe_link(link)
      None => false
    }
    if linked {
      out.write_char('[')
    }
    if run.style.bold {
      out.write_string("**")
    }
    if run.style.italic {
      out.write_char('*')
    }
    if run.style.strike {
      out.write_string("~~")
    }
    out.write_string(String::from_array(chars[start:end]))
    if run.style.strike {
      out.write_string("~~")
    }
    if run.style.italic {
      out.write_char('*')
    }
    if run.style.bold {
      out.write_string("**")
    }
    if linked {
      out.write_string("](\{markdown_link(run.link.unwrap())})")
    }
  }
  out.write_string(String::from_array(chars[end:]))
  out.to_string()
}

///|
fn markdown_paragraph(
  paragraph : Paragraph,
  include_hidden : Bool,
  table : Bool,
) -> String {
  let out = StringBuilder()
  for run in paragraph.runs {
    if include_hidden || !run.style.hidden {
      out.write_string(markdown_run(run, table))
    }
  }
  out.to_string()
}

///|
pub fn Document::to_markdown(
  self : Document,
  options? : TextOptions = TextOptions::default(),
) -> String {
  let out = StringBuilder()
  let mut in_table = false
  let mut row : Int? = None
  let mut cell : Int? = None
  let mut columns = 0
  let mut first_row = true
  let mut first_block = true
  for paragraph in self.paragraphs {
    if !options.accepts(paragraph.region) {
      continue
    }
    if paragraph.table_row is Some(current_row) {
      if !in_table {
        if !first_block {
          out.write_string("\n\n")
        }
        first_block = false
        in_table = true
        first_row = true
        columns = 0
        row = Some(current_row)
        cell = None
        out.write_char('|')
      } else if row != Some(current_row) {
        out.write_string(" |\n")
        if first_row {
          out.write_char('|')
          for _ in 0..<columns {
            out.write_string(" --- |")
          }
          out.write_char('\n')
          first_row = false
        }
        out.write_char('|')
        row = Some(current_row)
        cell = None
      }
      if cell != paragraph.table_cell {
        if cell is Some(_) {
          out.write_string(" |")
        }
        if first_row {
          columns += 1
        }
        out.write_char(' ')
      } else {
        out.write_string("<br>")
      }
      cell = paragraph.table_cell
      out.write_string(
        markdown_paragraph(paragraph, options.include_hidden, true),
      )
    } else {
      if in_table {
        out.write_string(" |")
        if first_row {
          out.write_string("\n|")
          for _ in 0..<columns {
            out.write_string(" --- |")
          }
        }
        in_table = false
        row = None
        cell = None
      }
      if !first_block {
        out.write_string("\n\n")
      }
      first_block = false
      out.write_string(
        markdown_paragraph(paragraph, options.include_hidden, false),
      )
    }
  }
  if in_table {
    out.write_string(" |")
    if first_row {
      out.write_string("\n|")
      for _ in 0..<columns {
        out.write_string(" --- |")
      }
    }
  }
  out.to_string()
}
