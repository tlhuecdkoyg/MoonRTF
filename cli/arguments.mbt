///|
pub(all) enum Command {
  Text
  Json
  Markdown
  Html
  Inspect
  Validate
  Tokens
  SourceMap
  Csv
  Help
  Version
} derive(Eq, Debug)

///|
pub(all) struct Options {
  command : Command
  input : String
  output : String?
  overwrite : Bool
  recover : Bool
  fail_on_warning : Bool
  pretty : Bool
  json_report : Bool
  text : @rtf.TextOptions
  limits : @rtf.Limits
  max_output : Int
  max_tokens : Int
  table_index : Int
} derive(Eq, Debug)

///|
pub fn defaults() -> Options {
  {
    command: Text,
    input: "-",
    output: None,
    overwrite: false,
    recover: false,
    fail_on_warning: false,
    pretty: false,
    json_report: false,
    text: @rtf.TextOptions::default(),
    limits: @rtf.Limits::default(),
    max_output: 64 * 1024 * 1024,
    max_tokens: 10000,
    table_index: 0,
  }
}

///|
fn positive_number(text : String) -> Int? {
  if text.is_empty() {
    return None
  }
  let mut value = 0
  for c in text.iter() {
    let digit = c.to_int() - 48
    if digit < 0 || digit > 9 {
      return None
    }
    if value > (2147483647 - digit) / 10 {
      return None
    }
    value = value * 10 + digit
  }
  if value > 0 {
    Some(value)
  } else {
    None
  }
}

///|
fn command_name(name : String) -> Command? {
  match name {
    "text" => Some(Text)
    "json" => Some(Json)
    "markdown" => Some(Markdown)
    "html" => Some(Html)
    "inspect" => Some(Inspect)
    "validate" => Some(Validate)
    "tokens" => Some(Tokens)
    "source-map" => Some(SourceMap)
    "csv" => Some(Csv)
    "help" | "--help" | "-h" => Some(Help)
    "version" | "--version" => Some(Version)
    _ => None
  }
}

///|
/// Arguments exclude the executable name.
pub fn parse_args(args : Array[String]) -> Result[Options, String] {
  let mut options = defaults()
  if args.is_empty() {
    return Ok({ ..options, command: Help, })
  }
  match command_name(args[0]) {
    Some(command) => options = { ..options, command, }
    None => return Err("Unknown command: \{args[0]}")
  }
  if options.command == Help || options.command == Version {
    return Ok(options)
  }
  let mut i = 1
  let mut positional = false
  let mut end_options = false
  while i < args.length() {
    let arg = args[i]
    i += 1
    if !end_options && arg == "--" {
      end_options = true
      continue
    }
    if end_options || !arg.has_prefix("-") || arg == "-" {
      if positional {
        return Err("Only one input path is accepted")
      }
      if arg.is_empty() {
        return Err("Input path cannot be empty")
      }
      options = { ..options, input: arg, }
      positional = true
      continue
    }
    match arg {
      "--help" | "-h" => return Ok({ ..options, command: Help, })
      "--force" => options = { ..options, overwrite: true, }
      "--recover" => options = { ..options, recover: true, }
      "--strict" =>
        options = { ..options, recover: false, fail_on_warning: true, }
      "--fail-on-warning" => options = { ..options, fail_on_warning: true, }
      "--pretty" => options = { ..options, pretty: true, }
      "--json" => options = { ..options, json_report: true, }
      "--include-hidden" =>
        options = {
          ..options,
          text: { ..options.text, include_hidden: true, },
        }
      "--include-headers" =>
        options = {
          ..options,
          text: { ..options.text, include_headers: true, },
        }
      "--include-footers" =>
        options = {
          ..options,
          text: { ..options.text, include_footers: true, },
        }
      "--include-notes" =>
        options = { ..options, text: { ..options.text, include_notes: true, }, }
      "--trim-trailing-space" =>
        options = {
          ..options,
          text: { ..options.text, trim_trailing_space: true, },
        }
      "--output" | "-o" => {
        if i >= args.length() {
          return Err("Missing value after \{arg}")
        }
        if args[i].is_empty() {
          return Err("Output path cannot be empty")
        }
        options = { ..options, output: Some(args[i]), }
        i += 1
      }
      "--max-input"
      | "--max-depth"
      | "--max-nodes"
      | "--max-text"
      | "--max-diagnostics"
      | "--max-output"
      | "--max-tokens"
      | "--table" => {
        if i >= args.length() {
          return Err("Missing numeric value after \{arg}")
        }
        let value = match positive_number(args[i]) {
          Some(n) => n
          None => return Err("\{arg} requires a positive integer")
        }
        i += 1
        options = match arg {
          "--max-input" =>
            { ..options, limits: { ..options.limits, input_bytes: value, }, }
          "--max-depth" =>
            { ..options, limits: { ..options.limits, depth: value, }, }
          "--max-nodes" =>
            { ..options, limits: { ..options.limits, nodes: value, }, }
          "--max-text" =>
            { ..options, limits: { ..options.limits, output_units: value, }, }
          "--max-diagnostics" =>
            { ..options, limits: { ..options.limits, diagnostics: value, }, }
          "--max-output" => { ..options, max_output: value, }
          "--max-tokens" => { ..options, max_tokens: value, }
          _ => { ..options, table_index: value - 1, }
        }
      }
      _ => return Err("Unknown option: \{arg}")
    }
  }
  if options.output == Some(options.input) && options.input != "-" {
    return Err("Input and output must be different files")
  }
  if options.command != Json && options.pretty {
    return Err("--pretty requires the json command")
  }
  if options.json_report &&
    !(options.command == Validate ||
    options.command == Inspect ||
    options.command == Tokens) {
    return Err("--json is supported by inspect, validate and tokens")
  }
  Ok(options)
}

///|
pub fn usage() -> String {
  (
    #|MoonRTF 0.1.1 — bounded RTF extraction
    #|
    #|Usage: moonrtf COMMAND [FILE|-] [OPTIONS]
    #|
    #|Commands:
    #|  text        Extract visible body text (tables use tabs)
    #|  json        Export the structured document and diagnostics
    #|  markdown    Export basic Markdown with safe links
    #|  html        Export a semantic HTML fragment with safe links
    #|  inspect     Show metadata and document statistics
    #|  validate    Check syntax, references and supported features
    #|  tokens      Inspect the bounded lexical token stream
    #|  source-map  Export text with byte-source mappings
    #|  csv         Export one simple table (default: first table)
    #|
    #|Options:
    #|  -o, --output FILE       Write a file instead of stdout
    #|  --force                 Allow replacing an existing output file
    #|  --recover               Return recoverable partial content (exit 1)
    #|  --strict                Stop on errors; warnings fail validation
    #|  --fail-on-warning       Return exit 1 for warnings
    #|  --pretty                Indent document JSON
    #|  --json                  JSON report for inspect/validate/tokens
    #|  --include-hidden        Include hidden runs in text exports
    #|  --include-headers       Include header paragraphs
    #|  --include-footers       Include footer paragraphs
    #|  --include-notes         Include footnotes and annotations
    #|  --trim-trailing-space   Remove trailing spaces in text output
    #|  --table N               Select table N (one-based) for CSV
    #|  --max-input N           Maximum input bytes (33554432)
    #|  --max-depth N           Maximum group depth (256)
    #|  --max-nodes N           Maximum document nodes (200000)
    #|  --max-text N            Maximum decoded UTF-16 units (33554432)
    #|  --max-output N          Maximum output UTF-16 units (67108864)
    #|  --max-diagnostics N     Maximum parser diagnostics (1000)
    #|  --max-tokens N          Token inspection limit (10000)
    #|  --                      Treat remaining argument as a path
    #|
    #|Exit status: 0 success, 1 document/limit failure, 2 usage or I/O error.
    #|Traditional encoding support: Windows-1252. Unicode escapes supported.
  )
}
