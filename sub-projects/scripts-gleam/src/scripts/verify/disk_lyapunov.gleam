//// scripts/verify/disk_lyapunov — SC-DISK-LYAPUNOV detector.
////
//// Consumes data/logs/disk-trend.log (JSONL produced by disk_trend.gleam
//// per SC-DISK-TREND) and detects sustained growth — a single 88% sample
//// is benign, but 80 → 85 → 90 across 3 samples is a P1 trajectory toward
//// the 95% runtime-hazard threshold.
////
//// Alert rules:
////   - Δ(first→last) >= 5 across last 10 samples → P1 sustained growth
////   - max(last 10) >= 95                         → P0 hazard
////   - max(last 10) >= 90                         → P1 elevated
////   - else                                       → ✓
////
//// ZK lineage: [zk-bd82645aedcb5ef4] Stub-That-Lies — parse, do not assert.

import gleam/erlang/charlist
import gleam/int
import gleam/io
import gleam/list
import gleam/string

const log_path: String = "/home/an/dev/ver/c3i/data/logs/disk-trend.log"

@external(erlang, "scripts_sh_ffi", "run_capture")
fn sh(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
) -> #(charlist.Charlist, Int)

fn cl(s: String) -> charlist.Charlist {
  charlist.from_string(s)
}

pub fn main() -> Nil {
  io.println("══ Disk Lyapunov Detector (SC-DISK-LYAPUNOV) ══")

  let #(out, rc) = sh(cl("tail"), [cl("-10"), cl(log_path)])
  case rc {
    0 -> {
      let rows =
        charlist.to_string(out)
        |> string.trim
        |> string.split("\n")
        |> list.filter(fn(s) { string.length(s) > 0 })
      case list.length(rows) {
        0 -> io.println("⚠ log empty — run disk_trend at least once")
        n -> analyse(rows, n)
      }
    }
    _ ->
      io.println(
        "⚠ log not readable rc="
        <> int.to_string(rc)
        <> " (absence is not a violation; first disk_trend run will create it)",
      )
  }
}

fn analyse(rows: List(String), n: Int) -> Nil {
  let pcts = list.map(rows, extract_pct)
  let max_pct = list.fold(pcts, 0, fn(acc, p) {
    case p > acc {
      True -> p
      False -> acc
    }
  })
  let first_p = case list.first(pcts) {
    Ok(p) -> p
    Error(_) -> 0
  }
  let last_p = case list.last(pcts) {
    Ok(p) -> p
    Error(_) -> 0
  }
  let delta = last_p - first_p

  io.println(
    "samples="
    <> int.to_string(n)
    <> " first="
    <> int.to_string(first_p)
    <> "% last="
    <> int.to_string(last_p)
    <> "% max="
    <> int.to_string(max_pct)
    <> "% Δ="
    <> int.to_string(delta),
  )

  case max_pct, delta {
    m, _ if m >= 95 -> {
      io.println("✗ P0 — runtime hazard")
      io.println(
        "hint: sa-plan add --priority P0 'Disk >= 95% per SC-DISK-LYAPUNOV'",
      )
    }
    m, _ if m >= 90 -> {
      io.println("✗ P1 — elevated")
      io.println(
        "hint: sa-plan add --priority P1 'Disk >= 90% per SC-DISK-LYAPUNOV'",
      )
    }
    _, d if d >= 5 -> {
      io.println("⚠ P1 — sustained growth Δ >= 5%")
      io.println(
        "hint: sa-plan add --priority P1 'Disk growth trajectory per SC-DISK-LYAPUNOV'",
      )
    }
    _, _ -> io.println("✓ λ ≤ 0 — disk usage stable")
  }
}

fn extract_pct(row: String) -> Int {
  case string.split(row, "\"pct\":") {
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
