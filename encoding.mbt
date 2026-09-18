///|
fn decode_1252(n : Int) -> Int? {
  if n < 128 || n >= 160 {
    return Some(n)
  }
  match n {
    128 => Some(0x20AC)
    130 => Some(0x201A)
    131 => Some(0x0192)
    132 => Some(0x201E)
    133 => Some(0x2026)
    134 => Some(0x2020)
    135 => Some(0x2021)
    136 => Some(0x02C6)
    137 => Some(0x2030)
    138 => Some(0x0160)
    139 => Some(0x2039)
    140 => Some(0x0152)
    142 => Some(0x017D)
    145 => Some(0x2018)
    146 => Some(0x2019)
    147 => Some(0x201C)
    148 => Some(0x201D)
    149 => Some(0x2022)
    150 => Some(0x2013)
    151 => Some(0x2014)
    152 => Some(0x02DC)
    153 => Some(0x2122)
    154 => Some(0x0161)
    155 => Some(0x203A)
    156 => Some(0x0153)
    158 => Some(0x017E)
    159 => Some(0x0178)
    _ => None
  }
}

///|
fn charset_codepage(charset : Int) -> Int? {
  match charset {
    0 => Some(1252)
    128 => Some(932)
    129 => Some(949)
    134 => Some(936)
    136 => Some(950)
    161 => Some(1253)
    162 => Some(1254)
    163 => Some(1258)
    177 => Some(1255)
    178 => Some(1256)
    186 => Some(1257)
    204 => Some(1251)
    222 => Some(874)
    238 => Some(1250)
    255 => Some(437)
    _ => None
  }
}

///|
fn unicode_unit(value : Int) -> Int? {
  if value < -32768 || value > 65535 {
    None
  } else if value < 0 {
    Some(value + 65536)
  } else {
    Some(value)
  }
}

///|
fn high_surrogate(value : Int) -> Bool {
  value >= 0xD800 && value <= 0xDBFF
}

///|
fn low_surrogate(value : Int) -> Bool {
  value >= 0xDC00 && value <= 0xDFFF
}

///|
fn combine_surrogates(high : Int, low : Int) -> Int {
  0x10000 + (high - 0xD800) * 1024 + low - 0xDC00
}
