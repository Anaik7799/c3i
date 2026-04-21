//// scripts/common/zenoh — typed Zenoh API for gleam-run scripts.
////
//// SC-SCRIPT-GLEAM-001, SC-ZENOH-001. Backed by the `scripts_nif` Rust NIF
//// which holds the process-wide Zenoh session.
////
//// All system-to-system communication from scripts MUST go through this
//// module (or one of the higher-level modules that use it).

import gleam/list
import gleam/string
import scripts/common/nif

pub type ZenohError {
  ZenohError(detail: String)
}

pub type Reply {
  Reply(key_expr: String, payload: String)
}

/// Ensure the process-wide Zenoh session is open. Safe to call repeatedly.
pub fn open() -> Result(String, ZenohError) {
  let #(_atom, msg) = nif.zenoh_open_session()
  Ok(msg)
  |> wrap_ok
}

fn wrap_ok(r: Result(a, Nil)) -> Result(a, ZenohError) {
  case r {
    Ok(v) -> Ok(v)
    Error(_) -> Error(ZenohError("nil"))
  }
}

/// Publish a payload to a Zenoh key-expression (default: Data priority, Block).
pub fn put(key: String, payload: String) -> Result(String, ZenohError) {
  let #(_atom, msg) = nif.zenoh_put(key, payload)
  case string.starts_with(msg, "put ok") {
    True -> Ok(msg)
    False -> Error(ZenohError(msg))
  }
}

pub type Priority {
  RealTime
  InteractiveHigh
  InteractiveLow
  DataHigh
  Data
  DataLow
  Background
}

fn priority_code(p: Priority) -> Int {
  case p {
    RealTime -> 0
    InteractiveHigh -> 1
    InteractiveLow -> 2
    DataHigh -> 3
    Data -> 4
    DataLow -> 5
    Background -> 6
  }
}

pub type Congestion {
  Block
  Drop
}

fn congestion_code(c: Congestion) -> String {
  case c {
    Block -> "block"
    Drop -> "drop"
  }
}

/// Publish with explicit priority + congestion control.
pub fn put_with(
  key: String,
  payload: String,
  priority: Priority,
  congestion: Congestion,
) -> Result(String, ZenohError) {
  let #(_, msg) =
    nif.zenoh_put_prio(
      key,
      payload,
      priority_code(priority),
      congestion_code(congestion),
    )
  case string.starts_with(msg, "put_prio ok") {
    True -> Ok(msg)
    False -> Error(ZenohError(msg))
  }
}

/// Query a Zenoh selector (key/pattern) and return replies within the
/// timeout window. Each reply has the shape `"<key_expr>|<payload>"` from
/// the NIF; this helper splits them into typed `Reply`.
pub fn get(selector: String, timeout_ms: Int) -> List(Reply) {
  let #(_atom, raw) = nif.zenoh_get(selector, timeout_ms)
  list.filter_map(raw, parse_reply)
}

fn parse_reply(raw: String) -> Result(Reply, Nil) {
  case string.split_once(raw, on: "|") {
    Ok(#(k, p)) -> Ok(Reply(key_expr: k, payload: p))
    Error(_) -> Error(Nil)
  }
}

/// JSON session-state snapshot from the NIF (handy for health checks).
pub fn session_info() -> String {
  let #(_, s) = nif.zenoh_session_info()
  s
}
