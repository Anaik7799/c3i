//// scripts/pass10/p10_slo_guard — enforce robustness SLO and page/escalate.
////
//// Reads robustness.json and emits alert when score < threshold for N
//// consecutive evaluations.

import envoy
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import simplifile
import scripts/common/nif

const default_path = "/home/an/dev/ver/c3i/docs/journal/monitor/robustness.json"
const default_state = "/home/an/dev/ver/c3i/docs/journal/monitor/slo-state.json"
const default_threshold = 75
const default_consecutive = 3

pub fn main() -> Nil {
  io.println("=== pass10/slo_guard ===")
  let path = env_str("ROBUSTNESS_JSON", default_path)
  let state_path = env_str("SLO_STATE", default_state)
  let threshold = env_int("SLO_THRESHOLD", default_threshold)
  let consecutive = env_int("SLO_CONSECUTIVE", default_consecutive)

  let score = read_score(path)
  let prev = read_fail_count(state_path)

  let fail = score < threshold
  let now_fail_count = case fail {
    True -> prev + 1
    False -> 0
  }

  write_state(state_path, score, now_fail_count)

  let breach = now_fail_count >= consecutive
  let payload =
    "{\"ts\":" <> int.to_string(nif.now_nanos())
    <> ",\"score\":" <> int.to_string(score)
    <> ",\"threshold\":" <> int.to_string(threshold)
    <> ",\"fail_count\":" <> int.to_string(now_fail_count)
    <> ",\"consecutive\":" <> int.to_string(consecutive)
    <> ",\"breach\":" <> bool_str(breach)
    <> ",\"by\":\"p10_slo_guard\"}"

  let _ = nif.zenoh_put("indrajaal/l4/sre/slo_guard", payload)

  case breach {
    True -> {
      let _ = nif.zenoh_put("indrajaal/l4/sre/pager", payload)
      io.println("SLO BREACH: score=" <> int.to_string(score))
    }
    False -> io.println("SLO ok score=" <> int.to_string(score) <> " fail_count=" <> int.to_string(now_fail_count))
  }
}

fn read_score(path: String) -> Int {
  case simplifile.read(from: path) {
    Error(_) -> 0
    Ok(s) ->
      case extract_int(s, "\"score\":") {
        Ok(n) -> n
        Error(_) -> 0
      }
  }
}

fn read_fail_count(path: String) -> Int {
  case simplifile.read(from: path) {
    Error(_) -> 0
    Ok(s) ->
      case extract_int(s, "\"fail_count\":") {
        Ok(n) -> n
        Error(_) -> 0
      }
  }
}

fn write_state(path: String, score: Int, fail_count: Int) -> Nil {
  let body =
    "{\"ts\":" <> int.to_string(nif.now_nanos())
    <> ",\"score\":" <> int.to_string(score)
    <> ",\"fail_count\":" <> int.to_string(fail_count)
    <> "}"
  let _ = simplifile.write(to: path, contents: body)
  Nil
}

fn extract_int(s: String, marker: String) -> Result(Int, Nil) {
  case string.split_once(s, marker) {
    Error(_) -> Error(Nil)
    Ok(#(_, rest)) -> {
      let digits =
        rest
        |> string.to_graphemes
        |> list.take_while(fn(ch) {
          ch == " " || ch == "-" || is_digit(ch)
        })
        |> string.join("")
        |> string.trim
      case int.parse(digits) {
        Ok(n) -> Ok(n)
        Error(_) -> Error(Nil)
      }
    }
  }
}

fn is_digit(ch: String) -> Bool {
  ch == "0" || ch == "1" || ch == "2" || ch == "3" || ch == "4" || ch == "5" || ch == "6" || ch == "7" || ch == "8" || ch == "9"
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

fn bool_str(b: Bool) -> String {
  case b {
    True -> "true"
    False -> "false"
  }
}
