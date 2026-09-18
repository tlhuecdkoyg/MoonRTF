///|
pub(all) struct TableCell {
  index : Int
  paragraphs : Array[Paragraph]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct TableRow {
  index : Int
  cells : Array[TableCell]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Table {
  region : Region
  rows : Array[TableRow]
} derive(Eq, Debug, ToJson)

///|
pub fn TableCell::text(
  self : TableCell,
  include_hidden? : Bool = false,
) -> String {
  self.paragraphs.map(p => p.text(include_hidden~)).join("\n")
}

///|
pub fn Table::column_count(self : Table) -> Int {
  let mut maximum = 0
  for row in self.rows {
    maximum = maximum.max(row.cells.length())
  }
  maximum
}

///|
pub fn Table::is_rectangular(self : Table) -> Bool {
  if self.rows.is_empty() {
    return true
  }
  let count = self.rows[0].cells.length()
  self.rows.all(row => row.cells.length() == count)
}

///|
/// Group contiguous table paragraphs. No inference of merged cells is made.
pub fn Document::tables(self : Document) -> Array[Table] {
  let tables : Array[Table] = []
  let rows : Array[TableRow] = []
  let cells : Array[TableCell] = []
  let paragraphs : Array[Paragraph] = []
  let mut region = Body
  let mut row_id : Int? = None
  let mut cell_id : Int? = None
  for paragraph in self.paragraphs {
    let boundary = paragraph.table_row is None || paragraph.region != region
    if boundary || paragraph.table_row != row_id {
      if cell_id is Some(id) {
        cells.push({ index: id, paragraphs: paragraphs.copy(), })
        paragraphs.clear()
        cell_id = None
      }
      if row_id is Some(id) {
        rows.push({ index: id, cells: cells.copy(), })
        cells.clear()
        row_id = None
      }
    }
    if boundary && !rows.is_empty() {
      tables.push({ region, rows: rows.copy(), })
      rows.clear()
    }
    if paragraph.table_row is Some(row) && paragraph.table_cell is Some(cell) {
      region = paragraph.region
      row_id = Some(row)
      if cell_id != Some(cell) {
        if cell_id is Some(id) {
          cells.push({ index: id, paragraphs: paragraphs.copy(), })
          paragraphs.clear()
        }
        cell_id = Some(cell)
      }
      paragraphs.push(paragraph)
    }
  }
  if cell_id is Some(id) {
    cells.push({ index: id, paragraphs: paragraphs.copy(), })
  }
  if row_id is Some(id) {
    rows.push({ index: id, cells: cells.copy(), })
  }
  if !rows.is_empty() {
    tables.push({ region, rows: rows.copy(), })
  }
  tables
}

///|
fn csv_field(value : String, delimiter : Char) -> String {
  let mut quote = false
  for c in value.iter() {
    if c == delimiter || c == '"' || c == '\n' || c == '\r' {
      quote = true
    }
  }
  if !quote {
    return value
  }
  let out = StringBuilder()
  out.write_char('"')
  for c in value.iter() {
    if c == '"' {
      out.write_char('"')
    }
    out.write_char(c)
  }
  out.write_char('"')
  out.to_string()
}

///|
pub fn Table::to_csv(
  self : Table,
  delimiter? : Char = ',',
  include_hidden? : Bool = false,
) -> String {
  let out = StringBuilder()
  for row in self.rows {
    for i in 0..<row.cells.length() {
      if i > 0 {
        out.write_char(delimiter)
      }
      out.write_string(csv_field(row.cells[i].text(include_hidden~), delimiter))
    }
    out.write_string("\r\n")
  }
  out.to_string()
}

///|
pub fn Table::cell(self : Table, row : Int, column : Int) -> TableCell? {
  if row < 0 || row >= self.rows.length() {
    return None
  }
  self.rows[row].cells.get(column)
}
