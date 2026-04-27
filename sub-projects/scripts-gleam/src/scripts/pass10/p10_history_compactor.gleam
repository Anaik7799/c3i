//// scripts/pass10/p10_history_compactor — bounded history retention.
////
//// Prevents unbounded growth of monitor/history.ndjson while preserving
//// recent operational visibility.
////
//// Policy:
////   keep newest KEEP_LINES lines (default 20_000)
////
//// Inputs (env):
////   HISTORY_PATH   default docs/journal/monitor/history.ndjson
////   KEEP_LINES     default 20000
////   OUT_SUMMARY    default docs/journal/monitor/history-compactor.json
////
//// Emits:
////   indrajaal/l4/sre/history_compactor

import envoy
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import simplifile
import scripts/common/nif

const default_history = "/home/an/dev/ver/c3i/docs/journal/monitor/history.ndjson"
const default_keep = 20_000
const default_summary = "/home/an/dev/ver/c3i/docs/journal/monitor/history-compactor.json"

pub fn main() -> Nil {
  let path = env_str("HISTORY_PATH", default_history)
  let keep = env_int("KEEP_LINES", default_keep)
  let out = env_str("OUT_SUMMARY", default_summary)

  io.println("=== pass10/history_compactor ===")
  io.println("path=" <> path <> " keep=" <> int.to_string(keep))

  case simplifile.read(from: path) {
    Error(_) -> io.println_error("read failed: " <> path)
    Ok(body) -> {
      let lines = split_lines(body)
      let total = list.length(lines)
      case total <= keep {
        True -> {
          let msg = "no-op total=" <> int.to_string(total)
          io.println(msg)
          write_summary(out, total, total, 0)
          publish(total, total, 0)
        }
        False -> {
          let kept = list.drop(lines, total - keep)
          let trimmed = total - keep
          let rebuilt = string.join(kept, "\n") <> "\n"
          case simplifile.write(to: path, contents: rebuilt) {
            Ok(_) -> {
              io.println(
                "compacted total=" <> int.to_string(total)
                <> " kept=" <> int.to_string(keep)
                <> " trimmed=" <> int.to_string(trimmed),
              )
              write_summary(out, total, keep, trimmed)
              publish(total, keep, trimmed)
            }
            Error(_) -> io.println_error("write failed: " <> path)
          }
        }
      }
    }
  }
}

fn split_lines(s: String) -> List(String) {
  s
  |> string.split("\n")
  |> list.filter(fn(x) { x != "" })
}

fn write_summary(path: String, total: Int, kept: Int, trimmed: Int) -> Nil {
  let payload =
    "{\"ts\":" <> int.to_string(nif.now_nanos())
    <> ",\"total\":" <> int.to_string(total)
    <> ",\"kept\":" <> int.to_string(kept)
    <> ",\"trimmed\":" <> int.to_string(trimmed)
    <> "}"
  let _ = simplifile.write(to: path, contents: payload)
  Nil
}

fn publish(total: Int, kept: Int, trimmed: Int) -> Nil {
  let payload =
    "{\"ts\":" <> int.to_string(nif.now_nanos())
    <> ",\"total\":" <> int.to_string(total)
    <> ",\"kept\":" <> int.to_string(kept)
    <> ",\"trimmed\":" <> int.to_string(trimmed)
    <> ",\"by\":\"p10_history_compactor\"}"
  let _ = nif.zenoh_put("indrajaal/l4/sre/history_compactor", payload)
  Nil
}

fn env_int(name: String, d: Int) -> Int {
  case envoy.get(name) {
    Ok(v) ->
      case int.parse(v) {
        Ok(n) -> n
        Error(_) -> d
      }
    Error(_) -> d
  }
}

fn env_str(name: String, d: String) -> String {
  case envoy.get(name) {
    Ok(v) -> v
    Error(_) -> d
  }
}
