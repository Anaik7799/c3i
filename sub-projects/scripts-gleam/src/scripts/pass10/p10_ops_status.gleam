//// scripts/pass10/p10_ops_status — writes operations status snapshot for dashboard.
////
//// Captures service + timer health from systemd --user and publishes a compact
//// JSON document at docs/journal/monitor/ops-status.json.

import gleam/erlang/charlist
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import simplifile
import scripts/common/nif

@external(erlang, "scripts_sh_ffi", "run_capture")
fn sh_run_capture(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
) -> #(charlist.Charlist, Int)

const default_out = "/home/an/dev/ver/c3i/docs/journal/monitor/ops-status.json"

pub fn main() -> Nil {
  io.println("=== pass10/ops_status ===")
  let out = default_out

  let services = [
    "c3i-symbiosis-monitor.service",
    "c3i-robustness-gate.service",
    "c3i-rete-autofix.service",
  ]
  let timers = [
    "c3i-history-compactor.timer",
    "c3i-slo-guard.timer",
  ]

  let services_json =
    services
    |> list.map(service_json)
    |> string.join(",")

  let timers_json =
    timers
    |> list.map(timer_json)
    |> string.join(",")

  let body =
    "{\"ts_nanos\":" <> int.to_string(nif.now_nanos())
    <> ",\"services\":[" <> services_json <> "]"
    <> ",\"timers\":[" <> timers_json <> "]"
    <> "}"

  let _ = simplifile.write(to: out, contents: body)
  let _ = nif.zenoh_put("indrajaal/l4/sre/ops_status", body)
  io.println("wrote " <> out)
}

fn service_json(unit: String) -> String {
  let show =
    run(
      "systemctl",
      [
        "--user", "show", unit,
        "-p", "ActiveState",
        "-p", "SubState",
        "-p", "MainPID",
        "-p", "ExecMainStatus",
      ],
    )

  let active = kv(show, "ActiveState")
  let sub = kv(show, "SubState")
  let pid = kv(show, "MainPID")
  let rc = kv(show, "ExecMainStatus")

  "{\"unit\":\"" <> esc(unit) <> "\""
  <> ",\"active\":\"" <> esc(active) <> "\""
  <> ",\"sub\":\"" <> esc(sub) <> "\""
  <> ",\"pid\":\"" <> esc(pid) <> "\""
  <> ",\"rc\":\"" <> esc(rc) <> "\"}"
}

fn timer_json(unit: String) -> String {
  let show =
    run(
      "systemctl",
      [
        "--user", "show", unit,
        "-p", "ActiveState",
        "-p", "LastTriggerUSecRealtime",
        "-p", "NextElapseUSecRealtime",
        "-p", "LastTriggerUSecMonotonic",
        "-p", "NextElapseUSecMonotonic",
      ],
    )

  let active = kv(show, "ActiveState")
  let last = kv(show, "LastTriggerUSecRealtime")
  let next = kv(show, "NextElapseUSecRealtime")
  let last_mono = kv(show, "LastTriggerUSecMonotonic")
  let next_mono = kv(show, "NextElapseUSecMonotonic")

  "{\"unit\":\"" <> esc(unit) <> "\""
  <> ",\"active\":\"" <> esc(active) <> "\""
  <> ",\"last\":\"" <> esc(last) <> "\""
  <> ",\"next\":\"" <> esc(next) <> "\""
  <> ",\"last_mono\":\"" <> esc(last_mono) <> "\""
  <> ",\"next_mono\":\"" <> esc(next_mono) <> "\"}"
}

fn run(cmd: String, args: List(String)) -> String {
  let #(out, _rc) =
    sh_run_capture(
      charlist.from_string(cmd),
      list.map(args, charlist.from_string),
    )
  charlist.to_string(out)
}

fn kv(out: String, key: String) -> String {
  let marker = key <> "="
  case string.split_once(out, marker) {
    Error(_) -> ""
    Ok(#(_, rest)) ->
      case string.split_once(rest, "\n") {
        Ok(#(v, _)) -> string.trim(v)
        Error(_) -> string.trim(rest)
      }
  }
}

fn esc(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", " ")
}
