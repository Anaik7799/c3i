//// scripts/pass10/p10_chaos_probe — controlled restart/health verification.
////
//// Executes a safe chaos cycle over user services:
////   stop + start + verify URLs + verify monitor files + emit score
////
//// NOTE: this uses scripts_sh_ffi to invoke systemctl, scoped to user units.
//// No root operations.

import gleam/erlang/charlist
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import scripts/common/httpx
import scripts/common/nif

@external(erlang, "scripts_sh_ffi", "run_capture")
fn sh_run_capture(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
) -> #(charlist.Charlist, Int)

fn run(cmd: String, args: List(String)) -> #(String, Int) {
  let #(out, rc) =
    sh_run_capture(
      charlist.from_string(cmd),
      list.map(args, charlist.from_string),
    )
  #(charlist.to_string(out), rc)
}

pub fn main() -> Nil {
  io.println("=== pass10/chaos_probe ===")
  let units = ["c3i-symbiosis-monitor", "c3i-robustness-gate", "c3i-rete-autofix"]

  // stop all
  list.each(units, fn(u) {
    let #(_o, rc) = run("systemctl", ["--user", "stop", u])
    io.println("stop " <> u <> " rc=" <> int.to_string(rc))
  })

  sleep_ms(1500)

  // start all
  list.each(units, fn(u) {
    let #(_o, rc) = run("systemctl", ["--user", "start", u])
    io.println("start " <> u <> " rc=" <> int.to_string(rc))
  })

  sleep_ms(4000)

  // status check
  let status_ok =
    list.fold(units, True, fn(acc, u) {
      let #(out, rc) = run("systemctl", ["--user", "is-active", u])
      let ok = rc == 0 && string.contains(out, "active")
      io.println("active " <> u <> " => " <> bool(ok))
      acc && ok
    })

  // utility url checks
  let urls = [
    "https://vm-1.tail55d152.ts.net/c3i/task-id/any/monitor/symbiosis.json",
    "https://vm-1.tail55d152.ts.net/c3i/task-id/any/monitor/robustness.json",
    "https://vm-1.tail55d152.ts.net/c3i/task-id/any/monitor/agents.json",
  ]
  let url_ok =
    list.fold(urls, True, fn(acc, u) {
      let r = httpx.head(u, 3000)
      io.println("url " <> u <> " code=" <> int.to_string(r.code))
      acc && r.ok
    })

  // final
  let score =
    100
    |> dec(!status_ok, 50)
    |> dec(!url_ok, 50)

  let payload =
    "{\"ts\":" <> int.to_string(nif.now_nanos())
    <> ",\"status_ok\":" <> bool(status_ok)
    <> ",\"url_ok\":" <> bool(url_ok)
    <> ",\"score\":" <> int.to_string(score)
    <> ",\"by\":\"p10_chaos_probe\"}"
  let _ = nif.zenoh_put("indrajaal/l4/sre/chaos_probe", payload)

  io.println("chaos_probe score=" <> int.to_string(score))
}

fn dec(score: Int, cond: Bool, by: Int) -> Int {
  case cond {
    True -> score - by
    False -> score
  }
}

fn bool(b: Bool) -> String {
  case b {
    True -> "true"
    False -> "false"
  }
}

@external(erlang, "timer", "sleep")
fn sleep_ms(ms: Int) -> Nil
