///|
fn metadata_key(name : String) -> Bool {
  match name {
    "title"
    | "subject"
    | "author"
    | "manager"
    | "company"
    | "operator"
    | "category"
    | "keywords"
    | "comment"
    | "doccomm"
    | "hlinkbase"
    | "generator" => true
    _ => false
  }
}

///|
fn ignored_destination(name : String) -> Bool {
  match name {
    "stylesheet"
    | "filetbl"
    | "revtbl"
    | "rsidtbl"
    | "listtable"
    | "listoverridetable"
    | "latentstyles"
    | "xmlnstbl"
    | "datastore"
    | "themedata"
    | "colorschememapping"
    | "fontemb"
    | "fontfile"
    | "datafield"
    | "objdata"
    | "objclass"
    | "objname"
    | "shp"
    | "shpinst"
    | "nonshppict"
    | "pntext"
    | "listtext"
    | "pn"
    | "bkmkstart"
    | "bkmkend"
    | "xe"
    | "tc"
    | "private"
    | "mmath"
    | "mmathPr"
    | "password"
    | "formfield" => true
    _ => false
  }
}

///|
fn Parser::destination(self : Parser, name : String, span : Span) -> Bool {
  if self.state.destination == "skip" {
    return true
  }
  if metadata_key(name) {
    self.flush_surrogate()
    self.flush_run()
    self.state.destination = name
    self.state.capture = StringBuilder()
    self.state.owned = true
    return true
  }
  if ignored_destination(name) {
    self.flush_surrogate()
    self.flush_run()
    self.state.destination = "skip"
    if name == "listtable" || name == "listoverridetable" {
      self.warn_once(
        "list_numbering", "Automatic list numbering is not reconstructed", span,
      )
    }
    if name == "mmath" || name == "shp" {
      self.warn_once(
        "unsupported_drawing", "Drawing or equation content was omitted", span,
      )
    }
    return true
  }
  match name {
    "fonttbl" | "colortbl" | "info" => {
      self.flush_surrogate()
      self.flush_run()
      self.state.destination = name
      self.state.capture = StringBuilder()
      self.state.owned = true
      true
    }
    "pict" | "object" => {
      self.flush_surrogate()
      self.flush_run()
      self.state.destination = name
      self.state.owned = true
      self.warn_once(
        "embedded_content", "Embedded pictures and objects are recorded but not rendered",
        span,
      )
      true
    }
    "header"
    | "headerl"
    | "headerr"
    | "headerf"
    | "footer"
    | "footerl"
    | "footerr"
    | "footerf"
    | "footnote"
    | "annotation" => {
      self.flush_surrogate()
      self.finish_paragraph(span.start, false)
      self.state.region = match name {
        "footnote" => Footnote
        "annotation" => Annotation
        "header" | "headerl" | "headerr" | "headerf" => Header
        _ => Footer
      }
      self.state.destination = "body"
      self.state.owned = true
      true
    }
    "field" => {
      self.flush_surrogate()
      self.flush_run()
      self.state.field = Some({ instruction: "", link: None, })
      self.state.destination = "field"
      true
    }
    "fldinst" => {
      self.state.destination = "fldinst"
      self.state.capture = StringBuilder()
      self.state.owned = true
      true
    }
    "fldrslt" => {
      self.state.destination = "fldrslt"
      true
    }
    "upr" => {
      self.state.destination = "upr"
      true
    }
    "ud" => {
      self.state.destination = "body"
      true
    }
    _ => false
  }
}

///|
fn Parser::finish_font(self : Parser, span : Span) -> Unit {
  let name = self.state.capture.to_string().trim().to_owned()
  self.state.capture.reset()
  if self.state.font_id < 0 || name.is_empty() {
    return
  }
  if !self.take_node(span) {
    return
  }
  let font : Font = {
    id: self.state.font_id,
    name,
    charset: self.state.charset,
    codepage: self.state.font_codepage,
    family: self.state.family,
  }
  if self.font_indices.get(font.id) is Some(i) {
    self.report(
      "duplicate_font",
      Warning,
      "Duplicate font identifier; last declaration wins",
      span,
    )
    self.fonts[i] = font
    return
  }
  self.font_indices[font.id] = self.fonts.length()
  self.fonts.push(font)
}

///|
fn Parser::finish_color(self : Parser, span : Span) -> Unit {
  if self.take_node(span) {
    self.colors.push({
      red: self.state.red,
      green: self.state.green,
      blue: self.state.blue,
      automatic: !self.state.color_set,
    })
  }
  self.state.red = 0
  self.state.green = 0
  self.state.blue = 0
  self.state.color_set = false
}

///|
fn Parser::close_destination(self : Parser, span : Span) -> Unit {
  if !self.state.owned {
    return
  }
  let name = self.state.destination
  if metadata_key(name) {
    if self.take_node(span) {
      self.metadata.push({
        key: name,
        value: self.state.capture.to_string(),
        span: { start: self.state.start, end: span.end, },
      })
    }
  } else if name == "fldinst" {
    if self.state.field is Some(field) {
      field.instruction = self.state.capture.to_string().trim().to_owned()
      field.link = hyperlink_target(field.instruction)
    }
  } else if name == "pict" || name == "object" {
    if self.take_node(span) {
      self.attachments.push({
        kind: name,
        span: { start: self.state.start, end: span.end, },
        declared_width: self.state.width,
        declared_height: self.state.height,
      })
    }
  } else if name == "body" && self.state.region != Body {
    self.finish_paragraph(span.end, false)
  }
}

///|
fn hyperlink_target(instruction : String) -> String? {
  let chars = instruction.to_array()
  let mut pos = 0
  while pos < chars.length() && chars[pos] != ' ' && chars[pos] != '\t' {
    pos += 1
  }
  let head = String::from_array(chars[:pos]).to_upper()
  if head != "HYPERLINK" {
    return None
  }
  while pos < chars.length() && (chars[pos] == ' ' || chars[pos] == '\t') {
    pos += 1
  }
  if pos >= chars.length() {
    return None
  }
  let out = StringBuilder()
  let quoted = chars[pos] == '"'
  if quoted {
    pos += 1
  }
  while pos < chars.length() {
    let c = chars[pos]
    if (quoted && c == '"') || (!quoted && (c == ' ' || c == '\t')) {
      break
    }
    out.write_char(c)
    pos += 1
  }
  let value = out.to_string()
  if value.is_empty() || value.has_prefix("\\") {
    None
  } else {
    Some(value)
  }
}
