///|
pub fn Diagnostic::hint(self : Diagnostic) -> String {
  match self.code {
    "missing_header" | "invalid_version" | "header_order" =>
      "Use an RTF file whose root group begins with \\rtf1; DOC and DOCX are different formats."
    "text_outside_root" | "extra_root" | "control_outside_root" =>
      "Remove concatenated documents or bytes outside the single root group."
    "unexpected_close" =>
      "Balance group braces. Literal braces in text must be escaped."
    "unclosed_group" =>
      "Check whether the file was truncated during transfer; recovery can expose partial text."
    "truncated_escape" | "truncated_hex" | "invalid_hex" =>
      "Check the backslash escape and ensure hexadecimal escapes contain exactly two hex digits."
    "parameter_overflow" | "missing_parameter" =>
      "Check the numeric argument attached to the control word."
    "control_word_too_long" =>
      "RTF control word names may contain at most 32 ASCII letters."
    "invalid_binary_length" | "truncated_binary" =>
      "The binary length must match the bytes following the control, including any braces."
    "unicode_range" | "unpaired_surrogate" =>
      "Check Unicode values and surrogate pairs; ensure fallback characters are counted correctly."
    "fallback_range" =>
      "Use a nonnegative \\uc count and check its group scope."
    "truncated_utf8" | "invalid_utf8" =>
      "Check UTF-8 bytes under code page 65001; a multibyte sequence cannot cross a formatting boundary."
    "undefined_codepoint" =>
      "This byte is undefined in Windows-1252; verify the declared code page."
    "invalid_codepage" =>
      "Use a positive code-page identifier; Unicode escapes avoid legacy encoding ambiguity."
    "input_limit" | "scan_limit" =>
      "Use a smaller input or explicitly raise the input limit for trusted data."
    "depth_limit" =>
      "Inspect deeply nested groups before increasing the nesting limit."
    "node_limit" =>
      "Reduce fragmentation or increase the node limit after checking the file size."
    "output_limit" =>
      "Increase the decoded-text limit only if the expected document size is known."
    "invalid_limits" => "All parser limits must be positive integers."
    "duplicate_font" | "duplicate_font_id" =>
      "Ensure each font identifier has one consistent declaration."
    "undefined_font" =>
      "Add the missing font declaration or select an existing font identifier."
    "color_range" | "color_index_range" | "undefined_color" =>
      "Check color-table indices and RGB channel values from 0 through 255."
    "font_size_range" =>
      "RTF font sizes use positive half-points; 24 represents 12 pt."
    "invalid_timestamp" =>
      "Provide a valid year, month and day; omitted time components default to zero."
    "complex_table" | "table_cell_order" | "incomplete_table_address" =>
      "Export a simple single-level table or inspect the structured output for lost layout."
    "unsafe_link" =>
      "Only http, https, mailto and fragment links are activated by HTML and Markdown export."
    "embedded_content" =>
      "Images and objects remain metadata; use an external renderer for their visual content."
    "list_numbering" =>
      "Automatic list labels are not reconstructed; use explicit text labels if required."
    "page_layout" =>
      "Page and section layout is intentionally reduced to logical paragraph boundaries."
    "unknown_destination" =>
      "Inspect the original file if the omitted destination contains important custom data."
    "unsupported_drawing" =>
      "The file contains drawing or equation content outside the supported extraction subset."
    "nul_text" =>
      "An embedded NUL was discarded; check the producer's text encoding."
    "invalid_paragraph_span" | "invalid_run_span" =>
      "Source ranges refer to the original bytes; do not reuse them after editing the input."
    _ =>
      if self.code.has_prefix("unsupported_codepage_") {
        "Convert this document to Unicode RTF or a supported code page before extracting it."
      } else if self.code.has_prefix("unknown_control_") {
        "The control was ignored; check the support matrix if formatting or text is missing."
      } else if self.code.has_prefix("unknown_symbol_") {
        "Check whether this symbol is a typo or a producer-specific extension."
      } else {
        "Inspect the source range and the project's support matrix."
      }
  }
}

///|
pub(all) struct DiagnosticSummary {
  errors : Int
  warnings : Int
  distinct_codes : Int
  first_error : Int?
} derive(Eq, Debug, ToJson)

///|
pub fn summarize_diagnostics(
  diagnostics : Array[Diagnostic],
) -> DiagnosticSummary {
  let codes : Map[String, Bool] = Map([])
  let mut errors = 0
  let mut warnings = 0
  let mut first_error : Int? = None
  for diagnostic in diagnostics {
    codes[diagnostic.code] = true
    if diagnostic.is_error() {
      errors += 1
      if first_error is None {
        first_error = Some(diagnostic.span.start)
      }
    } else {
      warnings += 1
    }
  }
  { errors, warnings, distinct_codes: codes.length(), first_error, }
}

///|
/// Terminal-safe context; input control bytes are escaped before display.
pub fn explain_diagnostic(
  input : Bytes,
  diagnostic : Diagnostic,
  context_bytes? : Int = 24,
) -> String {
  let out = StringBuilder()
  out.write_string(format_diagnostic(input, diagnostic))
  out.write_char('\n')
  out.write_string("  source: ")
  out.write_string(source_excerpt(input, diagnostic.span, radius=context_bytes))
  out.write_char('\n')
  out.write_string("  hint: ")
  out.write_string(diagnostic.hint())
  out.to_string()
}

///|
pub fn explain_diagnostics(
  input : Bytes,
  diagnostics : Array[Diagnostic],
  max_messages? : Int = 20,
) -> String {
  let out = StringBuilder()
  let count = max_messages.max(0).min(diagnostics.length())
  for i in 0..<count {
    if i > 0 {
      out.write_string("\n\n")
    }
    out.write_string(explain_diagnostic(input, diagnostics[i]))
  }
  if diagnostics.length() > count {
    out.write_string(
      "\n\{diagnostics.length() - count} additional diagnostics omitted",
    )
  }
  out.to_string()
}
