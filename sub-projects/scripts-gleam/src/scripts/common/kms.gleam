//// scripts/common/kms — battle-hardened KMS (smriti.db) access layer.
////
//// STAMP: SC-SCRIPT-GLEAM-001 · SC-PASS8-IMPL-001 · SC-KMS-ROBUST-001
////
//// Three layers of robustness:
////   L1  Rust NIF            pooled rusqlite + WAL + NORMAL sync + retry-on-BUSY
////   L2  gleam wrapper       typed errors, positional params, JSON row decoder
////   L3  observability       OTel span emit, metrics counter, zenoh publish
////
//// Callers should NEVER shell to `sqlite3` binary from pass-8 modules; always
//// use this module so the retry/pool/observe machinery applies uniformly.

import envoy
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import scripts/common/fractal
import scripts/common/metrics
import scripts/common/nif
import scripts/common/paths

// ─── Error taxonomy ──────────────────────────────────────────────────────────

pub type KmsError {
  /// DB file unavailable, wrong path, permission denied, or schema missing.
  OpenFailed(detail: String)
  /// SQL syntax / constraint / type error.
  SqlError(detail: String)
  /// SQLITE_BUSY / SQLITE_LOCKED beyond NIF's 5-retry envelope.
  Busy(detail: String)
  /// JSON decode failure from the NIF → gleam boundary.
  DecodeError(detail: String)
  /// Network-adjacent (e.g. cross-holon NIF not loaded).
  NifUnavailable(detail: String)
}

pub fn error_to_string(e: KmsError) -> String {
  case e {
    OpenFailed(d) -> "kms open: " <> d
    SqlError(d) -> "kms sql: " <> d
    Busy(d) -> "kms busy: " <> d
    DecodeError(d) -> "kms decode: " <> d
    NifUnavailable(d) -> "kms nif: " <> d
  }
}

// ─── Path + health ───────────────────────────────────────────────────────────

pub fn kms_path() -> String {
  case envoy.get("KMS_DB") {
    Ok(p) -> p
    Error(_) -> paths.repo_root() <> "/sub-projects/c3i/data/kms/smriti.db"
  }
}

/// JSON health snapshot of the pooled connection.
pub fn health() -> Result(String, KmsError) {
  let #(tag, msg) = nif.smriti_health(kms_path())
  case atom.to_string(tag) {
    "ok" -> Ok(msg)
    _ -> Error(OpenFailed(msg))
  }
}

// ─── Row model ───────────────────────────────────────────────────────────────

/// A single SELECT result as column-name → string-value tuples.
/// Strings are used throughout so downstream parsing is uniform.
pub type Row =
  List(#(String, String))

pub type QueryResult {
  QueryResult(columns: List(String), rows: List(Row))
}

// ─── Query API ───────────────────────────────────────────────────────────────

/// Run a SELECT/PRAGMA. Parameters are positional; all serialised as strings.
pub fn query(sql: String, params: List(String)) -> Result(QueryResult, KmsError) {
  let path = kms_path()
  emit_span("query", sql)
  let _ = metrics.counter_inc("kms_query", "total", 1)
  let #(tag, payload) = nif.smriti_query(path, sql, params)
  case atom.to_string(tag) {
    "ok" -> decode_query_result(payload)
    _ -> {
      let _ = metrics.counter_inc("kms_query", "error", 1)
      case string.contains(payload, "busy") {
        True -> Error(Busy(payload))
        False -> Error(SqlError(payload))
      }
    }
  }
}

/// Run an INSERT/UPDATE/DELETE/DDL. Returns rows-affected.
pub fn exec(sql: String, params: List(String)) -> Result(Int, KmsError) {
  let path = kms_path()
  emit_span("exec", sql)
  let _ = metrics.counter_inc("kms_exec", "total", 1)
  let #(tag, payload) = nif.smriti_exec(path, sql, params)
  case atom.to_string(tag) {
    "ok" ->
      case int.parse(payload) {
        Ok(n) -> Ok(n)
        Error(_) -> Error(DecodeError("rows-affected not int: " <> payload))
      }
    _ -> {
      let _ = metrics.counter_inc("kms_exec", "error", 1)
      case string.contains(payload, "busy") {
        True -> Error(Busy(payload))
        False -> Error(SqlError(payload))
      }
    }
  }
}

/// Run a transaction-wrapped batch of statements.
pub fn exec_batch(sql_batch: String) -> Result(Nil, KmsError) {
  let path = kms_path()
  emit_span("exec_batch", "batch")
  let _ = metrics.counter_inc("kms_batch", "total", 1)
  let #(tag, payload) = nif.smriti_exec_batch(path, sql_batch)
  case atom.to_string(tag) {
    "ok" -> Ok(Nil)
    _ -> {
      let _ = metrics.counter_inc("kms_batch", "error", 1)
      Error(SqlError(payload))
    }
  }
}

/// Convenience: single-column / single-row scalar queries.
pub fn scalar(sql: String, params: List(String)) -> Result(String, KmsError) {
  use qr <- result.try(query(sql, params))
  case qr.rows {
    [row, ..] ->
      case row {
        [#(_, v), ..] -> Ok(v)
        _ -> Error(DecodeError("scalar: empty row"))
      }
    _ -> Error(DecodeError("scalar: no rows"))
  }
}

/// Convenience: count-rows query (`SELECT COUNT(*) FROM …`).
pub fn count(table: String, where_clause: String) -> Result(Int, KmsError) {
  let sql =
    "SELECT COUNT(*) AS n FROM "
    <> table
    <> case where_clause {
      "" -> ""
      _ -> " WHERE " <> where_clause
    }
  use v <- result.try(scalar(sql, []))
  case int.parse(v) {
    Ok(n) -> Ok(n)
    Error(_) -> Error(DecodeError("count not int: " <> v))
  }
}

// ─── Observability ───────────────────────────────────────────────────────────

/// Publish a small JSON snapshot to Zenoh for SRE dashboards.
pub fn publish_metric(topic: String, body_json: String) -> Result(Nil, KmsError) {
  let #(tag, msg) = nif.zenoh_put(topic, body_json)
  case atom.to_string(tag) {
    "ok" -> Ok(Nil)
    _ -> Error(NifUnavailable(msg))
  }
}

fn emit_span(op: String, sql: String) -> Nil {
  let snippet = case string.length(sql) > 80 {
    True -> string.slice(sql, 0, 80) <> "…"
    False -> sql
  }
  let now = nif.now_nanos()
  let attrs =
    "{\"op\":\"" <> op <> "\",\"sql\":\"" <> escape_for_json(snippet) <> "\"}"
  let _ =
    nif.fractal_span_emit(
      fractal.layer_tag(fractal.L3),
      "kms." <> op,
      now,
      now,
      "ok",
      attrs,
    )
  Nil
}

fn escape_for_json(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
  |> string.replace("\r", "\\r")
  |> string.replace("\t", "\\t")
}

// ─── JSON → Row decoder ──────────────────────────────────────────────────────

fn decode_query_result(body: String) -> Result(QueryResult, KmsError) {
  let cols_decoder = {
    use columns <- decode.field(
      "columns",
      decode.list(decode.string),
    )
    use raw_rows <- decode.field(
      "rows",
      decode.list(decode.list(decode.dynamic)),
    )
    decode.success(#(columns, raw_rows))
  }
  case json.parse(body, cols_decoder) {
    Ok(#(columns, raw_rows)) -> {
      let rows = list.map(raw_rows, fn(r) { zip_row(columns, r) })
      Ok(QueryResult(columns: columns, rows: rows))
    }
    Error(_) -> Error(DecodeError("body: " <> body))
  }
}

/// Pair column names with row values as strings.
/// Uses `string.inspect` so ints/floats/nulls are representable.
fn zip_row(columns: List(String), values: List(decode.Dynamic)) -> Row {
  list.zip(columns, values)
  |> list.map(fn(pair) {
    let #(col, dyn) = pair
    #(col, dynamic_to_string(dyn))
  })
}

fn dynamic_to_string(d: decode.Dynamic) -> String {
  case decode.run(d, decode.string) {
    Ok(s) -> s
    Error(_) ->
      case decode.run(d, decode.int) {
        Ok(n) -> int.to_string(n)
        Error(_) ->
          case decode.run(d, decode.float) {
            Ok(f) -> float_to_string(f)
            Error(_) -> string.inspect(d)
          }
      }
  }
}

@external(erlang, "erlang", "float_to_binary")
fn do_float_to_binary(f: Float, opts: List(atom.Atom)) -> String

fn float_to_string(f: Float) -> String {
  let compact = atom.create("compact")
  let decimals = atom.create("short")
  do_float_to_binary(f, [compact, decimals])
}
