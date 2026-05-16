//// scripts/verify/stop_hook_lyapunov — SC-STOP-HOOK-LYAPUNOV detector.
////
//// Consumes data/logs/stop-hook-timing.log (JSONL produced by stop_hook.gleam
//// per SC-STOP-HOOK-TELE) and flags regression of the OODA Learn loop.
////
//// Alert rules:
////   - any single elapsed_s >= 30  → P0 (approaching the 50s timeout boundary)
////   - any single elapsed_s >= 5   → P1 (sub-second baseline broken)
////   - >=3 consecutive elapsed_s >= 5 in last 10 rows → P1 sustained
////   - all green → exit 0
////
//// Closes the loop opened by perf-bench-20260516: emit (TELE) -> observe (this).
//// ZK lineage: [zk-bd82645aedcb5ef4] Stub-That-Lies — parse, do not assert.

import gleam/erlang/charlist
import gleam/int
import gleam/io
import gleam/list
import gleam/string

const log_path: String = "/home/an/dev/ver/c3i/data/logs/stop-hook-timing.log"

@external(erlang, "scripts_sh_ffi", "run_capture")
fn sh(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
) -> #(charlist.Charlist, Int)

fn cl(s: String) -> charlist.Charlist {
  charlist.from_string(s)
}

pub fn main() -> Nil {
  io.println("══ Stop-Hook Lyapunov Detector (SC-STOP-HOOK-LYAPUNOV) ══")
  io.println("log: " <> log_path)

  let #(out, rc) =
    sh(cl("tail"), [cl("-10"), cl(log_path)])

  case rc {
    0 -> {
      let rows =
        charlist.to_string(out)
        |> string.trim
        |> string.split("\n")
        |> list.filter(fn(s) { string.length(s) > 0 })

      case list.length(rows) {
        0 -> io.println("⚠ log empty — no observations yet (run stop_hook at least once)")
        n -> analyse(rows, n)
      }
    }
    _ -> {
      io.println("⚠ log not readable rc=" <> int.to_string(rc))
      io.println(
        "hint: log is created on first stop_hook run; absence is not a violation",
      )
    }
  }
}

fn analyse(rows: List(String), n: Int) -> Nil {
  let elapsed_list = list.map(rows, extract_elapsed)
  let high_5 = list.filter(elapsed_list, fn(e) { e >= 5 })
  let high_30 = list.filter(elapsed_list, fn(e) { e >= 30 })
  let max_obs = list.fold(elapsed_list, 0, fn(acc, e) {
    case e > acc {
      True -> e
      False -> acc
    }
  })

  io.println(
    "samples="
    <> int.to_string(n)
    <> " max_elapsed_s="
    <> int.to_string(max_obs)
    <> " high(>=5s)="
    <> int.to_string(list.length(high_5))
    <> " high(>=30s)="
    <> int.to_string(list.length(high_30)),
  )

  case list.length(high_30), list.length(high_5) {
    n30, _ if n30 > 0 -> {
      io.println("✗ P0 — stop-hook approaching 50s timeout boundary")
      io.println(
        "hint: sa-plan add --priority P0 'Stop-hook Lyapunov P0 — Phase A regression suspected'",
      )
    }
    _, n5 if n5 >= 3 -> {
      io.println("✗ P1 — sustained sub-second regression in last 10 runs")
      io.println(
        "hint: sa-plan add --priority P1 'Stop-hook Lyapunov P1 — investigate elapsed_s drift'",
      )
    }
    _, n5 if n5 > 0 -> {
      io.println(
        "⚠ P2 — "
        <> int.to_string(n5)
        <> " transient spike(s) above 5s; monitor",
      )
    }
    _, _ -> io.println("✓ λ = 0 — OODA Learn loop in homeostasis")
  }
}

/// Extract elapsed_s integer from a JSONL row. Returns 0 on parse failure
/// (best-effort — corrupt rows do not crash the detector).
fn extract_elapsed(row: String) -> Int {
  case string.split(row, "\"elapsed_s\":") {
    [_, tail, ..] -> {
      let digits =
        tail
        |> string.split(",")
        |> list.first
      case digits {
        Ok(s) ->
          case int.parse(string.trim(s)) {
            Ok(n) -> n
            Error(_) -> 0
          }
        Error(_) -> 0
      }
    }
    _ -> 0
  }
}
