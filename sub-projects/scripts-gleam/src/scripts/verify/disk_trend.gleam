//// scripts/verify/disk_trend — SC-DISK-TREND monitor.
////
//// Reads `df -P /` once, appends a JSONL row to data/logs/disk-trend.log,
//// and classifies free-space pressure into 4 tiers:
////
////   used >= 95%  → P0 (runtime hazard imminent — Smriti.db growth blocked)
////   used >= 90%  → P1 (sustained — plan a cleanup pass)
////   used >= 80%  → P2 (watch — perf-bench-20260516 flagged 88%)
////   else         → ✓
////
//// Closes the perf-bench-20260516 §10 disk-usage gap.
//// ZK lineage: [zk-bd82645aedcb5ef4] Stub-That-Lies — measure with df.

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
  io.println("══ Disk Trend Monitor (SC-DISK-TREND) ══")

  let #(out, _rc) = sh(cl("df"), [cl("-P"), cl("/")])
  let raw = charlist.to_string(out)

  case extract_pct(raw) {
    Error(e) -> io.println("⚠ parse error: " <> e)
    Ok(#(pct, used_kb, avail_kb)) -> {
      let now = stamp_now()
      append_row(now, pct, used_kb, avail_kb)
      classify(pct)
    }
  }
}

fn stamp_now() -> String {
  let #(out, _rc) = sh(cl("date"), [cl("+%Y%m%d-%H%M")])
  charlist.to_string(out) |> string.trim
}

fn append_row(at: String, pct: Int, used_kb: Int, avail_kb: Int) -> Nil {
  let line =
    "{\"at\":\""
    <> at
    <> "\",\"pct\":"
    <> int.to_string(pct)
    <> ",\"used_kb\":"
    <> int.to_string(used_kb)
    <> ",\"avail_kb\":"
    <> int.to_string(avail_kb)
    <> "}"
  let _ =
    sh(cl("sh"), [cl("-c"), cl("printf '%s\n' '" <> line <> "' >> " <> log_path)])
  Nil
}

fn classify(pct: Int) -> Nil {
  io.println("used: " <> int.to_string(pct) <> "%")
  case pct {
    p if p >= 95 -> {
      io.println("✗ P0 — runtime hazard imminent")
      io.println(
        "hint: sa-plan add --priority P0 'Disk >= 95% — Smriti.db growth at risk per SC-DISK-TREND'",
      )
    }
    p if p >= 90 -> {
      io.println("⚠ P1 — plan a cleanup pass")
      io.println(
        "hint: sa-plan add --priority P1 'Disk >= 90% sustained per SC-DISK-TREND'",
      )
    }
    p if p >= 80 -> io.println("⚠ P2 — watch (perf-bench-20260516 baseline)")
    _ -> io.println("✓ disk under 80% — nominal")
  }
}

/// Parse `df -P /` output. Line 2 schema:
///   Filesystem 1024-blocks Used Available Capacity Mounted-on
fn extract_pct(raw: String) -> Result(#(Int, Int, Int), String) {
  let lines = string.split(string.trim(raw), "\n")
  case lines {
    [_header, data, ..] -> parse_data_line(data)
    _ -> Error("df output has fewer than 2 lines")
  }
}

fn parse_data_line(line: String) -> Result(#(Int, Int, Int), String) {
  let fields =
    string.split(line, " ")
    |> list.filter(fn(s) { string.length(s) > 0 })
  case fields {
    [_fs, _blocks, used, avail, cap, .._] -> {
      let pct_str = string.replace(cap, "%", "")
      case int.parse(pct_str), int.parse(used), int.parse(avail) {
        Ok(p), Ok(u), Ok(a) -> Ok(#(p, u, a))
        _, _, _ -> Error("non-integer field in df row")
      }
    }
    _ -> Error("df data line has unexpected shape")
  }
}
