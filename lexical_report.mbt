///|
pub(all) struct TokenInfo {
  kind : String
  span : Span
  control : String?
  parameter : Int?
  depth : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ScanReport {
  tokens : Array[TokenInfo]
  diagnostics : Array[Diagnostic]
  truncated : Bool
  consumed_bytes : Int
  maximum_depth : Int
} derive(Eq, Debug, ToJson)

///|
/// Bounded syntax inspection for editor integrations and troubleshooting.
pub fn scan(
  input : Bytes,
  max_tokens? : Int = 10000,
  max_input? : Int = 32 * 1024 * 1024,
) -> ScanReport {
  let tokens : Array[TokenInfo] = []
  let diagnostics : Array[Diagnostic] = []
  if max_tokens <= 0 || max_input <= 0 || input.length() > max_input {
    return {
      tokens,
      diagnostics: [
        {
          code: "scan_limit",
          severity: Error,
          message: "Invalid scan limit or input exceeds scan byte limit",
          span: { start: 0, end: 0, },
        },
      ],
      truncated: true,
      consumed_bytes: 0,
      maximum_depth: 0,
    }
  }
  let lexer = Lexer::new(input)
  let mut depth = 0
  let mut maximum_depth = 0
  let mut truncated = false
  while lexer.pos < input.length() {
    if tokens.length() >= max_tokens {
      truncated = true
      break
    }
    let token = lexer.next()
    let mut control : String? = None
    let mut parameter : Int? = None
    let kind = match token.kind {
      Open => {
        depth += 1
        maximum_depth = maximum_depth.max(depth)
        "open"
      }
      Close => {
        if depth == 0 {
          diagnostics.push({
            code: "unexpected_close",
            severity: Error,
            message: "Unmatched closing brace",
            span: token.span,
          })
        } else {
          depth -= 1
        }
        "close"
      }
      Word(name, value) => {
        control = Some(name)
        parameter = value
        "control"
      }
      Symbol(value) => {
        parameter = Some(value)
        "symbol"
      }
      Hex(value) => {
        parameter = Some(value)
        "hex"
      }
      Text => "text"
      Binary => "binary"
      Bad(code) => {
        diagnostics.push({
          code,
          severity: Error,
          message: "Malformed lexical token: \{Repr(token.kind)}",
          span: token.span,
        })
        "error"
      }
      End => "end"
    }
    tokens.push({ kind, span: token.span, control, parameter, depth, })
  }
  if !truncated && depth > 0 {
    diagnostics.push({
      code: "unclosed_group",
      severity: Error,
      message: "Unclosed groups at end of scan",
      span: { start: lexer.pos, end: lexer.pos, },
    })
  }
  { tokens, diagnostics, truncated, consumed_bytes: lexer.pos, maximum_depth, }
}

///|
pub fn ScanReport::to_json_text(self : ScanReport) -> String {
  let tokens = self.tokens.map(token => {
    Json::object({
      "kind": Json::string(token.kind),
      "source": span_json(token.span),
      "control": optional_string_json(token.control),
      "parameter": optional_int_json(token.parameter),
      "depth": token.depth.to_json(),
    })
  })
  Json::object({
    "schema": Json::string("moonrtf.tokens.v1"),
    "tokens": Json::array(tokens),
    "diagnostics": Json::array(self.diagnostics.map(diagnostic_json)),
    "truncated": Json::boolean(self.truncated),
    "consumed_bytes": self.consumed_bytes.to_json(),
    "maximum_depth": self.maximum_depth.to_json(),
  }).stringify()
}

///|
pub fn ScanReport::to_text(self : ScanReport) -> String {
  let out = StringBuilder()
  for token in self.tokens {
    out.write_string(
      "\{token.span.start}..\{token.span.end} depth=\{token.depth} \{token.kind}",
    )
    if token.control is Some(name) {
      out.write_string(" \\\{name}")
    }
    if token.parameter is Some(value) {
      out.write_string(" \{value}")
    }
    out.write_char('\n')
  }
  if self.truncated {
    out.write_string("Scan truncated by token limit\n")
  }
  out.to_string()
}
