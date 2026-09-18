///|
fn html_escape(text : String) -> String {
  let out = StringBuilder()
  for c in text.iter() {
    match c {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '"' => out.write_string("&quot;")
      '\'' => out.write_string("&#39;")
      '\n' => out.write_string("<br>\n")
      '\t' => out.write_string("&#9;")
      _ => out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn css_color(color : Color) -> String {
  "rgb(\{color.red.max(0).min(255)},\{color.green.max(0).min(255)},\{color.blue.max(0).min(255)})"
}

///|
fn Document::html_run(self : Document, run : Run) -> String {
  let out = StringBuilder()
  let css = StringBuilder()
  let style = run.style
  if style.foreground > 0 {
    if self.colors.get(style.foreground) is Some(color) && !color.automatic {
      css.write_string("color:\{css_color(color)};")
    }
  }
  if style.background > 0 {
    if self.colors.get(style.background) is Some(color) && !color.automatic {
      css.write_string("background-color:\{css_color(color)};")
    }
  }
  if style.size_half_points > 0 && style.size_half_points <= 32767 {
    let whole = style.size_half_points / 2
    let half = if style.size_half_points % 2 == 0 { "" } else { ".5" }
    css.write_string("font-size:\{whole}\{half}pt;")
  }
  let linked = match run.link {
    Some(target) => safe_link(target)
    None => false
  }
  if linked {
    out.write_string(
      "<a href=\"\{html_escape(run.link.unwrap())}\" rel=\"noreferrer\">",
    )
  }
  if !css.is_empty() {
    out.write_string("<span style=\"\{css.to_string()}\">")
  }
  if style.bold {
    out.write_string("<strong>")
  }
  if style.italic {
    out.write_string("<em>")
  }
  if style.underline {
    out.write_string("<u>")
  }
  if style.strike {
    out.write_string("<s>")
  }
  if style.superscript > 0 {
    out.write_string("<sup>")
  }
  if style.superscript < 0 {
    out.write_string("<sub>")
  }
  out.write_string(html_escape(run.text))
  if style.superscript < 0 {
    out.write_string("</sub>")
  }
  if style.superscript > 0 {
    out.write_string("</sup>")
  }
  if style.strike {
    out.write_string("</s>")
  }
  if style.underline {
    out.write_string("</u>")
  }
  if style.italic {
    out.write_string("</em>")
  }
  if style.bold {
    out.write_string("</strong>")
  }
  if !css.is_empty() {
    out.write_string("</span>")
  }
  if linked {
    out.write_string("</a>")
  }
  out.to_string()
}

///|
fn Document::html_paragraph(
  self : Document,
  paragraph : Paragraph,
  hidden : Bool,
) -> String {
  let out = StringBuilder()
  let align = alignment_name(paragraph.style.alignment)
  out.write_string("<p style=\"text-align:\{align};white-space:pre-wrap\">")
  for run in paragraph.runs {
    if hidden || !run.style.hidden {
      out.write_string(self.html_run(run))
    }
  }
  out.write_string("</p>")
  out.to_string()
}

///|
/// Semantic HTML fragment. No scripts, embedded resources, or raw RTF HTML.
pub fn Document::to_html(
  self : Document,
  options? : TextOptions = TextOptions::default(),
) -> String {
  let out = StringBuilder()
  let mut table = false
  let mut row : Int? = None
  let mut cell : Int? = None
  let mut region : Region? = None
  for paragraph in self.paragraphs {
    if !options.accepts(paragraph.region) {
      continue
    }
    if region != Some(paragraph.region) {
      if table {
        out.write_string("</td></tr></tbody></table>\n")
        table = false
        row = None
        cell = None
      }
      if region is Some(_) {
        out.write_string("</section>\n")
      }
      out.write_string(
        "<section data-region=\"\{region_name(paragraph.region)}\">\n",
      )
      region = Some(paragraph.region)
    }
    if paragraph.table_row is Some(index) {
      if !table {
        out.write_string("<table><tbody><tr><td>")
        table = true
        row = Some(index)
        cell = paragraph.table_cell
      } else if row != Some(index) {
        out.write_string("</td></tr><tr><td>")
        row = Some(index)
        cell = paragraph.table_cell
      } else if cell != paragraph.table_cell {
        out.write_string("</td><td>")
        cell = paragraph.table_cell
      }
    } else if table {
      out.write_string("</td></tr></tbody></table>\n")
      table = false
      row = None
      cell = None
    }
    out.write_string(self.html_paragraph(paragraph, options.include_hidden))
    out.write_char('\n')
  }
  if table {
    out.write_string("</td></tr></tbody></table>\n")
  }
  if region is Some(_) {
    out.write_string("</section>\n")
  }
  out.to_string()
}
