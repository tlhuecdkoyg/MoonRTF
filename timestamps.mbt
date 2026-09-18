///|
pub(all) struct DocumentTime {
  year : Int
  month : Int
  day : Int
  hour : Int
  minute : Int
  second : Int
} derive(Eq, Debug, ToJson)

///|
fn time_destination(name : String) -> Bool {
  name == "creatim" || name == "revtim" || name == "printim" || name == "buptim"
}

///|
fn month_days(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 =>
      if year % 400 == 0 || (year % 4 == 0 && year % 100 != 0) {
        29
      } else {
        28
      }
    _ => 0
  }
}

///|
pub fn DocumentTime::valid(self : DocumentTime) -> Bool {
  self.year >= 1 &&
  self.year <= 9999 &&
  self.month >= 1 &&
  self.month <= 12 &&
  self.day >= 1 &&
  self.day <= month_days(self.year, self.month) &&
  self.hour >= 0 &&
  self.hour <= 23 &&
  self.minute >= 0 &&
  self.minute <= 59 &&
  self.second >= 0 &&
  self.second <= 59
}

///|
fn decimal_padded(value : Int, width : Int) -> String {
  let value = value.to_string()
  let out = StringBuilder()
  for _ in 0..<(width - value.length()).max(0) {
    out.write_char('0')
  }
  out.write_string(value)
  out.to_string()
}

///|
/// RTF timestamps do not declare a timezone; no UTC suffix is fabricated.
pub fn DocumentTime::to_iso(self : DocumentTime) -> String {
  "\{decimal_padded(self.year, 4)}-\{decimal_padded(self.month, 2)}-\{decimal_padded(self.day, 2)}T\{decimal_padded(self.hour, 2)}:\{decimal_padded(self.minute, 2)}:\{decimal_padded(self.second, 2)}"
}

///|
fn decimal_slice(chars : Array[Char], start : Int, count : Int) -> Int? {
  let mut value = 0
  if start < 0 || start + count > chars.length() {
    return None
  }
  for i in start..<(start + count) {
    let digit = chars[i].to_int() - 48
    if digit < 0 || digit > 9 {
      return None
    }
    value = value * 10 + digit
  }
  Some(value)
}

///|
pub fn DocumentTime::from_iso(text : String) -> DocumentTime? {
  let c = text.to_array()
  if c.length() != 19 ||
    c[4] != '-' ||
    c[7] != '-' ||
    c[10] != 'T' ||
    c[13] != ':' ||
    c[16] != ':' {
    return None
  }
  match
    (
      decimal_slice(c, 0, 4),
      decimal_slice(c, 5, 2),
      decimal_slice(c, 8, 2),
      decimal_slice(c, 11, 2),
      decimal_slice(c, 14, 2),
      decimal_slice(c, 17, 2),
    ) {
    (Some(year), Some(month), Some(day), Some(hour), Some(minute), Some(second)) => {
      let time : DocumentTime = { year, month, day, hour, minute, second, }
      if time.valid() {
        Some(time)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
pub fn Document::created_time(self : Document) -> DocumentTime? {
  match self.metadata_value("creatim") {
    Some(value) => DocumentTime::from_iso(value)
    None => None
  }
}

///|
pub fn Document::revised_time(self : Document) -> DocumentTime? {
  match self.metadata_value("revtim") {
    Some(value) => DocumentTime::from_iso(value)
    None => None
  }
}

///|
fn Parser::time_control(
  self : Parser,
  name : String,
  value : Int?,
  span : Span,
) -> Bool {
  if !time_destination(self.state.destination) {
    return false
  }
  let current = self.state.time
  match name {
    "yr" | "mo" | "dy" | "hr" | "min" | "sec" => {
      if self.parameter(name, value, span) is Some(v) {
        self.state.time = match name {
          "yr" => { ..current, year: v, }
          "mo" => { ..current, month: v, }
          "dy" => { ..current, day: v, }
          "hr" => { ..current, hour: v, }
          "min" => { ..current, minute: v, }
          _ => { ..current, second: v, }
        }
      }
      true
    }
    _ => false
  }
}
