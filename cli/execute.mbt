///|
pub(all) struct Output {
  text : String
  diagnostics : Array[String]
  exit_code : Int
} derive(Eq, Debug)

///|
fn bounded_output(
  text : String,
  diagnostics : Array[String],
  code : Int,
  limit : Int,
) -> Output {
  if text.length() > limit {
    {
      text: "",
      diagnostics: diagnostics + ["Output exceeds --max-output"],
      exit_code: 1,
    }
  } else {
    { text, diagnostics, exit_code: code, }
  }
}

///|
/// Pure command implementation; native I/O is a separate adapter.
pub fn execute(input : Bytes, options : Options) -> Output {
  match options.command {
    Help => return { text: usage(), diagnostics: [], exit_code: 0, }
    Version => return { text: "MoonRTF 0.1.1", diagnostics: [], exit_code: 0, }
    Tokens => {
      let scan = @rtf.scan(
        input,
        max_tokens=options.max_tokens,
        max_input=options.limits.input_bytes,
      )
      let text = if options.json_report {
        scan.to_json_text()
      } else {
        scan.to_text()
      }
      let code = if scan.truncated || !scan.diagnostics.is_empty() {
        1
      } else {
        0
      }
      return bounded_output(
        text,
        scan.diagnostics.map(d => @rtf.format_diagnostic(input, d)),
        code,
        options.max_output,
      )
    }
    Validate => {
      let report = @rtf.validate(
        input,
        limits=options.limits,
        fail_on_warning=options.fail_on_warning,
      )
      let text = if options.json_report {
        report.to_json_text()
      } else {
        report.to_text(input)
      }
      return bounded_output(
        text,
        [],
        if report.valid {
          0
        } else {
          1
        },
        options.max_output,
      )
    }
    _ => ()
  }
  let parsed = @rtf.parse(input, recover=options.recover, limits=options.limits)
  let diagnostics = parsed.diagnostics.map(d => @rtf.format_diagnostic(input, d))
  let code = if parsed.acceptable(fail_on_warning=options.fail_on_warning) {
    0
  } else {
    1
  }
  let report_command = options.command == Json || options.command == Inspect
  if parsed.has_errors() && !options.recover && !report_command {
    return { text: "", diagnostics, exit_code: 1, }
  }
  let text = match options.command {
    Text => parsed.document.to_text(options=options.text)
    Json => parsed.to_json_text(pretty=options.pretty)
    Markdown => parsed.document.to_markdown(options=options.text)
    Html => parsed.document.to_html(options=options.text)
    Inspect =>
      if options.json_report {
        parsed.document.statistics().to_json().stringify()
      } else {
        parsed.inspect()
      }
    SourceMap =>
      parsed.document
      .mapped_text(include_hidden=options.text.include_hidden)
      .to_json_text()
    Csv => {
      let tables = parsed.document.tables()
      if tables.get(options.table_index) is Some(table) {
        table.to_csv(include_hidden=options.text.include_hidden)
      } else {
        return {
          text: "",
          diagnostics: diagnostics + ["Requested table does not exist"],
          exit_code: 1,
        }
      }
    }
    _ => ""
  }
  bounded_output(text, diagnostics, code, options.max_output)
}
