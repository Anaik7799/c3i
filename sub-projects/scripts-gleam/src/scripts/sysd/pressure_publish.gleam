//// scripts/sysd/pressure_publish — G2 migration: c3i-pressure-publish.sh.
////
//// Lyapunov hysteresis controller for cgroup memory.pressure (Pass 5 design).
////
//// V(t) = avg10_full from /sys/fs/cgroup/.../c3i.slice/memory.pressure
//// theta_low  = 0.5  → Nominal      → RETE D14 fires FullSpeed
//// theta_high = 5.0  → HighPressure  → RETE D14 fires HeavyThrottle
//// theta_crit = 20.0 → Critical     → emergency action (restart highest OOM)
////
//// Publishes to: indrajaal/l4/system/{pressure, pressure_level}
////
//// Per SC-OBS-PRESSURE, SC-CPU-GOV.

import gleam/erlang/charlist
import gleam/io
import gleam/list
import gleam/string
import simplifile

const psi_path = "/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/c3i.slice/memory.pressure"

const hysteresis_state = "/tmp/c3i-pressure-state"

const zenoh_rest = "http://127.0.0.1:8000"

const pressure_topic = "indrajaal/l4/system/pressure"

const level_topic = "indrajaal/l4/system/pressure_level"

@external(erlang, "scripts_sh_ffi", "run_capture")
fn sh(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
) -> #(charlist.Charlist, Int)

fn cl(s: String) -> charlist.Charlist {
  charlist.from_string(s)
}

fn cls(xs: List(String)) -> List(charlist.Charlist) {
  case xs {
    [] -> []
    [x, ..rest] -> [cl(x), ..cls(rest)]
  }
}

/// Parse "full avg10=N.NN avg60=... avg300=... total=..." line.
/// Extract avg10 only (we use it as Lyapunov V).
fn parse_full_avg10(content: String) -> Float {
  let lines = string.split(content, "\n")
  let full_line = case
    list.find(lines, fn(line) { string.starts_with(line, "full") })
  {
    Ok(l) -> l
    Error(_) -> ""
  }
  let tokens = string.split(full_line, " ")
  case
    list.find(tokens, fn(t) { string.starts_with(t, "avg10=") })
  {
    Ok(t) -> {
      let v = string.replace(t, "avg10=", "")
      case parse_float(v) {
        Ok(f) -> f
        Error(_) -> 0.0
      }
    }
    Error(_) -> 0.0
  }
}

@external(erlang, "erlang", "binary_to_float")
fn binary_to_float(s: String) -> Float

fn parse_float(s: String) -> Result(Float, Nil) {
  // Accept "0", "0.0", "11.30", etc. Erlang's binary_to_float rejects "0".
  case string.contains(s, ".") {
    True -> Ok(binary_to_float(s))
    False ->
      case s {
        "" -> Error(Nil)
        _ -> Ok(binary_to_float(s <> ".0"))
      }
  }
}

/// Lyapunov hysteresis: state machine on V with theta_low/high/crit and a
/// memory of the previous level (prevents oscillation around theta_high).
fn classify(v: Float, prev: String) -> String {
  case v >. 20.0 {
    True -> "Critical"
    False ->
      case v >. 5.0 {
        True -> "HighPressure"
        False ->
          case prev {
            "HighPressure" -> {
              case v >. 0.5 {
                True -> "HighPressure"
                False -> "Nominal"
              }
            }
            "Critical" -> {
              case v >. 5.0 {
                True -> "HighPressure"
                False -> "Nominal"
              }
            }
            _ -> "Nominal"
          }
      }
  }
}

fn iso_now() -> String {
  let #(out, _rc) = sh(cl("date"), cls(["-u", "+%Y-%m-%dT%H:%M:%SZ"]))
  charlist.to_string(out) |> string.trim
}

fn float_to_string(f: Float) -> String {
  // simple representation; sufficient for telemetry
  case f >. 0.0 {
    True -> string.inspect(f)
    False -> "0.0"
  }
}

fn put_zenoh(topic: String, body: String) -> Nil {
  let _ =
    sh(cl("curl"), cls([
      "-fsS",
      "--max-time",
      "1",
      "-X",
      "PUT",
      "--data-binary",
      body,
      zenoh_rest <> "/" <> topic,
    ]))
  Nil
}

pub fn main() -> Nil {
  case simplifile.read(from: psi_path) {
    Error(_) -> {
      io.println("[pressure] PSI file unreadable: " <> psi_path)
      Nil
    }
    Ok(content) -> {
      let v = parse_full_avg10(content)
      let prev = case simplifile.read(from: hysteresis_state) {
        Ok(s) -> string.trim(s)
        Error(_) -> "Nominal"
      }
      let level = classify(v, prev)
      let payload =
        "{\"level\":\""
        <> level
        <> "\",\"avg10\":"
        <> float_to_string(v)
        <> ",\"ts\":\""
        <> iso_now()
        <> "\"}"
      put_zenoh(pressure_topic, payload)
      put_zenoh(level_topic, level)
      let _ = simplifile.write(to: hysteresis_state, contents: level)
      io.println(level <> " avg10=" <> float_to_string(v) <> " (prev=" <> prev <> ")")
    }
  }
}
