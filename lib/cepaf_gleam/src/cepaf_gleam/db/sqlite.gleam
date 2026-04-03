import gleam/dynamic.{type Dynamic}

@external(erlang, "cepaf_gleam_ffi", "sqlite_open")
pub fn open(path: String) -> Result(Dynamic, String)

@external(erlang, "cepaf_gleam_ffi", "sqlite_exec")
pub fn execute_raw(conn: Dynamic, sql: String) -> Result(Int, String)

@external(erlang, "cepaf_gleam_ffi", "sqlite_q")
pub fn query_raw(
  conn: Dynamic,
  sql: String,
  params: List(Dynamic),
) -> Result(List(List(Dynamic)), String)

@external(erlang, "cepaf_gleam_ffi", "sqlite_close")
pub fn close(conn: Dynamic) -> Nil

pub fn ensure_schema(conn: Dynamic, schema_sql: String) -> Result(Nil, String) {
  case execute_raw(conn, schema_sql) {
    Ok(_) -> Ok(Nil)
    Error(e) -> Error(e)
  }
}
