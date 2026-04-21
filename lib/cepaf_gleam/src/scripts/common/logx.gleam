//// scripts/common/logx — structured logging + timestamp for gleam-run scripts.
////
//// SC-SCRIPT-GLEAM-001. Minimal, dependency-light.

import gleam/erlang/atom
import gleam/int
import gleam/io
import gleam/string

@external(erlang, "calendar", "universal_time")
fn erl_utc_now() -> #(#(Int, Int, Int), #(Int, Int, Int))

fn pad2(n: Int) -> String {
  let s = int.to_string(n)
  case string.length(s) {
    1 -> "0" <> s
    _ -> s
  }
}

/// Filesystem-safe timestamp: `YYYYMMDD-HHMMSS` in UTC.
pub fn stamp() -> String {
  let #(#(y, mo, d), #(h, mi, s)) = erl_utc_now()
  int.to_string(y)
  <> pad2(mo)
  <> pad2(d)
  <> "-"
  <> pad2(h)
  <> pad2(mi)
  <> pad2(s)
}

/// ISO-ish UTC time for headers: `YYYY-MM-DDTHH:MM:SSZ`.
pub fn iso_now() -> String {
  let #(#(y, mo, d), #(h, mi, s)) = erl_utc_now()
  int.to_string(y)
  <> "-" <> pad2(mo)
  <> "-" <> pad2(d)
  <> "T" <> pad2(h)
  <> ":" <> pad2(mi)
  <> ":" <> pad2(s)
  <> "Z"
}

pub type Level {
  Info
  Warn
  Error
  Debug
}

fn level_str(l: Level) -> String {
  case l {
    Info -> "INFO"
    Warn -> "WARN"
    Error -> "ERROR"
    Debug -> "DEBUG"
  }
}

/// Emit a single structured log line to stdout.
///
/// Example:
///   logx.log(logx.Info, "public_interface", "probe complete pass=10/10")
pub fn log(level: Level, scope: String, msg: String) -> Nil {
  let line =
    "[" <> iso_now() <> "] "
    <> level_str(level) <> " "
    <> scope <> " "
    <> msg
  io.println(line)
  // reserved for future Zenoh OTel publish via atom tag:
  let _ = atom.create("scripts." <> scope)
  Nil
}

pub fn info(scope: String, msg: String) -> Nil {
  log(Info, scope, msg)
}

pub fn warn(scope: String, msg: String) -> Nil {
  log(Warn, scope, msg)
}

pub fn error(scope: String, msg: String) -> Nil {
  log(Error, scope, msg)
}
