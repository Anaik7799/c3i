//// scripts/pi/operator_view — Pi operator live-view (SC-SCHED-TELE-PI-001).
////
//// Uses the streaming port-spawn FFI (SC-SCHED-TELE-PI-STREAM-FFI-001) to
//// tail `sa-plan sched-observe --json` and pretty-print events with colour +
//// URN + worker for Pi operators. Stays fully gleam-only.
////
//// Usage:
////   gleam run -m scripts/pi/operator_view -- \
////     [--pattern 'indrajaal/l4/sched/**'] \
////     [--max-lines 50] \
////     [--timeout-ms 30000] \
////     [--iterations 1]
////
//// STAMP: SC-SCHED-TELE-PI-001, SC-SCHED-TELE-PI-STREAM-FFI-001, SC-SCRIPT-GLEAM-001

import argv
import gleam/erlang/charlist
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import scripts/common/args as cargs
import scripts/common/fractal
import scripts/common/logx
import scripts/common/manifest as mfst

/// Streaming FFI: collects up to MaxLines or for TimeoutMs, returning early.
@external(erlang, "scripts_sh_ffi", "run_stream_bounded")
fn sh_stream_raw(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
  cwd: charlist.Charlist,
  max_lines: Int,
  timeout_ms: Int,
) -> #(List(charlist.Charlist), StreamStatus)

pub type StreamStatus {
  Ongoing
  Timeout
  Exited(Int)
  Err(String)
}

fn sh_stream(
  cmd: String,
  args: List(String),
  cwd: String,
  max_lines: Int,
  timeout_ms: Int,
) -> #(List(String), StreamStatus) {
  let #(lines_cl, status) =
    sh_stream_raw(
      charlist.from_string(cmd),
      list.map(args, charlist.from_string),
      charlist.from_string(cwd),
      max_lines,
      timeout_ms,
    )
  let lines = list.map(lines_cl, charlist.to_string)
  #(lines, status)
}

pub fn manifest() -> mfst.Manifest {
  mfst.Manifest(
    name: "pi/operator_view",
    category: mfst.Probe,
    fractal_layer: fractal.L6,
    summary: "Pi operator live view: tails sa-plan sched-observe --json via streaming FFI.",
    inputs: [
      mfst.FlagSpec("pattern", "Zenoh key pattern", "indrajaal/l4/sched/**", False),
      mfst.FlagSpec("max-lines", "Stop after N events per iteration", "50", False),
      mfst.FlagSpec("timeout-ms", "Capture window in milliseconds", "30000", False),
      mfst.FlagSpec("iterations", "Repeat the capture N times (0 = loop forever, bounded by Ctrl+C)", "1", False),
    ],
    outputs_schema: "tty",
    retention_days: 1,
    auth_level: mfst.L2Normal,
    sc_id: "SC-SCHED-TELE-PI-001",
  )
}

pub fn main() -> Nil {
  let a = cargs.parse(argv.load().arguments)
  let pattern = cargs.flag(a, "pattern", "indrajaal/l4/sched/**")
  let max_lines = int_or(cargs.flag(a, "max-lines", "50"), 50)
  let timeout_ms = int_or(cargs.flag(a, "timeout-ms", "30000"), 30_000)
  let iterations = int_or(cargs.flag(a, "iterations", "1"), 1)
  let sa_plan = "/home/an/dev/ver/c3i/sub-projects/c3i/sa-plan"

  logx.info("pi/operator_view",
    "pattern=" <> pattern
    <> " max_lines=" <> int.to_string(max_lines)
    <> " timeout_ms=" <> int.to_string(timeout_ms)
    <> " iterations=" <> int.to_string(iterations))

  render_header(pattern, max_lines, timeout_ms)
  loop(sa_plan, pattern, max_lines, timeout_ms, iterations, 0)
}

fn int_or(s: String, default: Int) -> Int {
  case int.parse(s) {
    Ok(n) -> n
    Error(_) -> default
  }
}

fn loop(
  bin: String,
  pattern: String,
  max_lines: Int,
  timeout_ms: Int,
  iterations: Int,
  done: Int,
) -> Nil {
  case iterations > 0 && done >= iterations {
    True -> Nil
    False -> {
      let #(lines, status) =
        sh_stream(
          bin,
          ["sched-observe", "--json", "--pattern", pattern],
          "/",
          max_lines,
          timeout_ms,
        )
      let rendered = render_lines(lines, 0)
      io.println("  iteration " <> int.to_string(done + 1) <> ": rendered=" <> int.to_string(rendered) <> " status=" <> status_to_string(status))
      case iterations == 0 {
        True -> loop(bin, pattern, max_lines, timeout_ms, iterations, done + 1)
        False -> loop(bin, pattern, max_lines, timeout_ms, iterations, done + 1)
      }
    }
  }
}

fn status_to_string(s: StreamStatus) -> String {
  case s {
    Ongoing -> "ongoing"
    Timeout -> "timeout"
    Exited(rc) -> "exited(" <> int.to_string(rc) <> ")"
    Err(e) -> "err(" <> e <> ")"
  }
}

fn render_header(pattern: String, max_lines: Int, timeout_ms: Int) -> Nil {
  io.println("═══════════════════════════════════════════════════════════════════════════════════")
  io.println("  Pi Operator View — /jobs/live (SC-SCHED-TELE-PI-001)")
  io.println("  pattern=" <> pattern
    <> "  max_lines=" <> int.to_string(max_lines)
    <> "  window=" <> int.to_string(timeout_ms) <> "ms")
  io.println("───────────────────────────────────────────────────────────────────────────────────")
  io.println("  EVENT         URN                                            AT")
  io.println("───────────────────────────────────────────────────────────────────────────────────")
}

fn render_lines(lines: List(String), acc: Int) -> Int {
  case lines {
    [] -> acc
    [line, ..rest] ->
      case starts_with_brace(string.trim(line)) {
        False -> render_lines(rest, acc)
        True -> {
          render_one(line)
          render_lines(rest, acc + 1)
        }
      }
  }
}

fn starts_with_brace(s: String) -> Bool {
  case s {
    "data: " <> rest -> string.starts_with(rest, "{")
    other -> string.starts_with(other, "{")
  }
}

fn render_one(raw: String) -> Nil {
  // Strip SSE "data: " prefix if present.
  let line = case string.starts_with(raw, "data: ") {
    True -> string.drop_start(raw, 6)
    False -> raw
  }
  let event = field(line, "event")
  let urn = field(line, "urn")
  let at = field(line, "at")
  io.println(
    "  "
    <> pad(colorize(event), 22)
    <> pad(urn, 50)
    <> " "
    <> at,
  )
}

fn field(line: String, key: String) -> String {
  let pat = "\"" <> key <> "\":\""
  case string.split_once(line, pat) {
    Error(_) -> ""
    Ok(#(_, rest)) ->
      case string.split_once(rest, "\"") {
        Error(_) -> ""
        Ok(#(v, _)) -> v
      }
  }
}

fn colorize(event: String) -> String {
  case event {
    "completed" -> "\u{001b}[32mcompleted\u{001b}[0m"
    "failed" -> "\u{001b}[31mfailed\u{001b}[0m"
    "timeout" -> "\u{001b}[35mtimeout\u{001b}[0m"
    "cancelled" -> "\u{001b}[33mcancelled\u{001b}[0m"
    "started" -> "\u{001b}[36mstarted\u{001b}[0m"
    "heartbeat" -> "\u{001b}[90mheartbeat\u{001b}[0m"
    "enqueued" -> "\u{001b}[34menqueued\u{001b}[0m"
    "retryable" -> "\u{001b}[33mretryable\u{001b}[0m"
    "discarded" -> "\u{001b}[31mdiscarded\u{001b}[0m"
    "created" -> "\u{001b}[36mcreated\u{001b}[0m"
    other -> other
  }
}

fn pad(s: String, width: Int) -> String {
  let n = string.length(strip_ansi(s))
  case n >= width {
    True -> s
    False -> s <> string.repeat(" ", width - n)
  }
}

fn strip_ansi(s: String) -> String {
  s
  |> string.replace("\u{001b}[32m", "")
  |> string.replace("\u{001b}[31m", "")
  |> string.replace("\u{001b}[35m", "")
  |> string.replace("\u{001b}[33m", "")
  |> string.replace("\u{001b}[36m", "")
  |> string.replace("\u{001b}[90m", "")
  |> string.replace("\u{001b}[34m", "")
  |> string.replace("\u{001b}[0m", "")
}
