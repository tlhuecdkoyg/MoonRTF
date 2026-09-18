///|
fn Parser::parameter(
  self : Parser,
  name : String,
  value : Int?,
  span : Span,
) -> Int? {
  if value is None {
    self.report(
      "missing_parameter",
      Error,
      "Control \\\{name} requires a numeric parameter",
      span,
    )
  }
  value
}

///|
fn Parser::control(
  self : Parser,
  name : String,
  value : Int?,
  span : Span,
) -> Unit {
  if self.state.destination == "skip" {
    self.state.starred = false
    return
  }
  if self.destination(name, span) {
    self.state.starred = false
    return
  }
  if self.state.starred {
    self.state.starred = false
    self.state.destination = "skip"
    self.warn_once(
      "unknown_destination", "Unknown starred destination was omitted", span,
    )
    return
  }
  if name == "u" {
    if self.parameter(name, value, span) is Some(v) {
      self.emit_unicode(v, span)
    }
    return
  }
  if name == "uc" {
    if self.parameter(name, value, span) is Some(v) {
      if v >= 0 && v <= 32767 {
        self.state.uc = v
      } else {
        self.report(
          "fallback_range",
          Error,
          "Unicode fallback count must be between 0 and 32767",
          span,
        )
      }
    }
    return
  }
  self.flush_surrogate()
  self.flush_run()
  let on = value.unwrap_or(1) != 0
  let style = self.state.style
  let paragraph = self.state.paragraph
  match name {
    "rtf" => {
      if self.seen_version || self.stack.length() != 1 || value != Some(1) {
        self.report(
          "invalid_version",
          Error,
          "Expected one root-level \\rtf1 header",
          span,
        )
      }
      self.seen_version = true
    }
    "ansi" => self.state.codepage = 1252
    "mac" => self.state.codepage = 10000
    "pc" => self.state.codepage = 437
    "pca" => self.state.codepage = 850
    "ansicpg" =>
      if self.parameter(name, value, span) is Some(v) {
        if v > 0 {
          self.state.codepage = v
        } else {
          self.report(
            "invalid_codepage",
            Error,
            "Code page must be positive",
            span,
          )
        }
      }
    "deff" =>
      if self.parameter(name, value, span) is Some(v) {
        self.default_font = v
        self.state.style = { ..style, font: v, }
      }
    "f" =>
      if self.parameter(name, value, span) is Some(v) {
        if self.state.destination == "fonttbl" {
          self.state.font_id = v
          self.state.capture = StringBuilder()
          self.state.charset = 0
          self.state.font_codepage = None
        } else {
          self.state.style = { ..style, font: v, }
        }
      }
    "fcharset" =>
      if self.parameter(name, value, span) is Some(v) {
        self.state.charset = v
      }
    "cpg" => self.state.font_codepage = self.parameter(name, value, span)
    "fnil" => self.state.family = "nil"
    "froman" => self.state.family = "roman"
    "fswiss" => self.state.family = "swiss"
    "fmodern" => self.state.family = "modern"
    "fscript" => self.state.family = "script"
    "fdecor" => self.state.family = "decor"
    "ftech" => self.state.family = "technical"
    "fbidi" => self.state.family = "bidi"
    "red" | "green" | "blue" =>
      if self.parameter(name, value, span) is Some(v) {
        if v < 0 || v > 255 {
          self.report(
            "color_range",
            Error,
            "Color channel must be between 0 and 255",
            span,
          )
        } else {
          self.state.color_set = true
          match name {
            "red" => self.state.red = v
            "green" => self.state.green = v
            _ => self.state.blue = v
          }
        }
      }
    "b" => self.state.style = { ..style, bold: on, }
    "i" => self.state.style = { ..style, italic: on, }
    "ul" => self.state.style = { ..style, underline: on, }
    "ulnone" => self.state.style = { ..style, underline: false, }
    "strike" | "striked" => self.state.style = { ..style, strike: on, }
    "v" => self.state.style = { ..style, hidden: on, }
    "super" => self.state.style = { ..style, superscript: 1, }
    "sub" => self.state.style = { ..style, superscript: -1, }
    "nosupersub" => self.state.style = { ..style, superscript: 0, }
    "plain" =>
      self.state.style = { ..Style::default(), font: self.default_font, }
    "fs" =>
      if self.parameter(name, value, span) is Some(v) {
        if v > 0 && v <= 32767 {
          self.state.style = { ..style, size_half_points: v, }
        } else {
          self.report(
            "font_size_range",
            Error,
            "Font size must be a positive half-point value",
            span,
          )
        }
      }
    "cf" | "highlight" | "cb" =>
      if self.parameter(name, value, span) is Some(v) {
        if v < 0 {
          self.report(
            "color_index_range",
            Error,
            "Color index cannot be negative",
            span,
          )
        } else if name == "cf" {
          self.state.style = { ..style, foreground: v, }
        } else {
          self.state.style = { ..style, background: v, }
        }
      }
    "pard" => {
      self.state.paragraph = ParagraphStyle::default()
      self.state.in_table = false
    }
    "ql" => self.state.paragraph = { ..paragraph, alignment: Left, }
    "qr" => self.state.paragraph = { ..paragraph, alignment: Right, }
    "qc" => self.state.paragraph = { ..paragraph, alignment: Center, }
    "qj" => self.state.paragraph = { ..paragraph, alignment: Justify, }
    "keep" => self.state.paragraph = { ..paragraph, keep_together: on, }
    "keepn" => self.state.paragraph = { ..paragraph, keep_next: on, }
    "li" | "ri" | "fi" | "sb" | "sa" | "sl" =>
      if self.parameter(name, value, span) is Some(v) {
        self.state.paragraph = match name {
          "li" => { ..paragraph, left_indent: v, }
          "ri" => { ..paragraph, right_indent: v, }
          "fi" => { ..paragraph, first_indent: v, }
          "sb" => { ..paragraph, space_before: v, }
          "sa" => { ..paragraph, space_after: v, }
          _ => { ..paragraph, line_spacing: v, }
        }
      }
    "par" => self.finish_paragraph(span.end, true)
    "line" => self.append_scalar(10, span)
    "tab" => self.append_scalar(9, span)
    "page" | "sect" => {
      self.finish_paragraph(span.end, true)
      self.warn_once(
        "page_layout", "Page and section layout is represented as paragraph boundaries",
        span,
      )
    }
    "emdash" => self.append_scalar(0x2014, span)
    "endash" => self.append_scalar(0x2013, span)
    "emspace" => self.append_scalar(0x2003, span)
    "enspace" => self.append_scalar(0x2002, span)
    "qmspace" => self.append_scalar(0x2005, span)
    "bullet" => self.append_scalar(0x2022, span)
    "lquote" => self.append_scalar(0x2018, span)
    "rquote" => self.append_scalar(0x2019, span)
    "ldblquote" => self.append_scalar(0x201C, span)
    "rdblquote" => self.append_scalar(0x201D, span)
    "zwj" => self.append_scalar(0x200D, span)
    "zwnj" => self.append_scalar(0x200C, span)
    "trowd" => {
      self.finish_paragraph(span.start, false)
      self.state.in_table = true
      self.cell = 0
    }
    "intbl" => self.state.in_table = on
    "cell" => {
      self.state.in_table = true
      self.finish_paragraph(span.end, true)
      self.cell += 1
    }
    "row" => {
      self.finish_paragraph(span.end, false)
      self.row += 1
      self.cell = 0
      self.state.in_table = false
    }
    "nestcell" | "nestrow" | "clmgf" | "clmrg" | "clvmgf" | "clvmrg" =>
      self.warn_once(
        "complex_table", "Nested or merged table structure is not reconstructed",
        span,
      )
    "itap" =>
      if value.unwrap_or(1) > 1 {
        self.warn_once(
          "complex_table", "Nested table structure is not reconstructed", span,
        )
      }
    "picw" => self.state.width = self.parameter(name, value, span)
    "pich" => self.state.height = self.parameter(name, value, span)
    "bin" => ()
    "cellx"
    | "trgaph"
    | "trleft"
    | "trrh"
    | "trql"
    | "trqr"
    | "trqc"
    | "lang"
    | "langfe"
    | "deflang"
    | "deflangfe"
    | "viewkind"
    | "viewscale"
    | "fet"
    | "widowctrl"
    | "deftab"
    | "paperw"
    | "paperh"
    | "margl"
    | "margr"
    | "margt"
    | "margb"
    | "landscape"
    | "cocoartf"
    | "cocoatextscaling"
    | "cocoaplatform"
    | "pngblip"
    | "jpegblip"
    | "wmetafile"
    | "emfblip"
    | "picscalex"
    | "picscaley"
    | "picwgoal"
    | "pichgoal"
    | "objemb"
    | "objlink"
    | "objw"
    | "objh" => ()
    _ =>
      self.warn_once(
        "unknown_control_\{name}",
        "Unrecognized control \\\{name}; surrounding text is retained",
        span,
      )
  }
}
