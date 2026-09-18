///|
suberror InputLimit {
  InputLimit(String)
}

///|
async fn read_bounded(reader : &@io.Reader, limit : Int) -> Bytes {
  let chunks : Array[Bytes] = []
  let mut total = 0
  while true {
    let size = if total == limit { 1 } else { (limit - total).min(65536) }
    match reader.read_some(max_len=size) {
      None => break
      Some(bytes) => {
        if bytes.length() > limit - total {
          raise InputLimit("Input exceeds --max-input")
        }
        total += bytes.length()
        chunks.push(bytes)
      }
    }
  }
  let result = FixedArray::make(total, b'\x00')
  let mut offset = 0
  for chunk in chunks {
    for b in chunk {
      result[offset] = b
      offset += 1
    }
  }
  Bytes::from_iter(result.iter())
}

///|
async fn load_input(options : @cli.Options) -> Bytes {
  if options.input == "-" {
    read_bounded(@stdio.stdin, options.limits.input_bytes)
  } else {
    let file = @fs.open(options.input, mode=ReadOnly)
    defer file.close()
    if file.size() > options.limits.input_bytes.to_int64() {
      raise InputLimit("Input file exceeds --max-input")
    }
    read_bounded(file, options.limits.input_bytes)
  }
}

///|
async fn write_output(options : @cli.Options, text : String) -> Unit {
  match options.output {
    None | Some("-") => @stdio.stdout.write(text)
    Some(path) => {
      if options.input != "-" && @fs.exists(path) {
        if @fs.realpath(path) == @fs.realpath(options.input) {
          fail("Refusing to overwrite the input file")
        }
      }
      @fs.write_file(
        path,
        text,
        create_mode=if options.overwrite { CreateOrTruncate } else { CreateNew },
      )
    }
  }
}

///|
async fn run() -> Int {
  let args = @env.args()
  let options = match @cli.parse_args(args[1:].to_owned()) {
    Ok(options) => options
    Err(message) => {
      @stdio.stderr.write("MoonRTF: \{message}\nUse --help for usage.\n")
      return 2
    }
  }
  if options.command == Help || options.command == Version {
    let output = @cli.execute(b"", options)
    @stdio.stdout.write(output.text + "\n")
    return 0
  }
  let input = load_input(options)
  let output = @cli.execute(input, options)
  for diagnostic in output.diagnostics {
    @stdio.stderr.write(diagnostic + "\n")
  }
  if !output.text.is_empty() || output.exit_code == 0 {
    write_output(options, output.text)
  }
  output.exit_code
}

///|
async fn main {
  let code = run() catch {
    InputLimit(message) => {
      @stdio.stderr.write("MoonRTF: \{message}\n")
      1
    }
    error => {
      @stdio.stderr.write("MoonRTF I/O error: \{error}\n")
      2
    }
  }
  @sys.exit(code)
}
