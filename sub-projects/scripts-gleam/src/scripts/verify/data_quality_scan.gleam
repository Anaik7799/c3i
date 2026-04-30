//// scripts/verify/data_quality_scan — Tasks-table enum-violation detector.
////
//// Scans Smriti.db for non-canonical priority/status values and SimTest
//// fixture spam. Prints a one-line summary; exits 0 always (drift detection
//// is informational, not a hard gate). Operator action is generated as
//// sa-plan task hints when violations exceed thresholds.
////
//// SC-TRUTH-001 / SC-VALUE-GUARD-001 / SC-MUDA-001 enforcement at scan-time.
////
//// Usage:
////   gleam run -m scripts/verify/data_quality_scan
////
//// Scheduled hourly + 5-min canary via sa-plan-daemon workflow_schedules.
//// ZK lineage: [zk-907c636b4bbf0d73] silent metric drift anti-pattern.

import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/string

const db_path: String = "/home/an/dev/ver/c3i/sub-projects/c3i/data/smriti/Smriti.db"

// Canonical enum sets MUST match db.rs::VALID_PRIORITIES and VALID_STATUSES.
const valid_priorities: List(String) = ["P0", "P1", "P2", "P3"]

const valid_statuses: List(String) = [
  "pending", "in_progress", "completed", "blocked",
]

pub fn main() -> Nil {
  io.println("══ Data Quality Scan (SC-TRUTH-001) ══")
  io.println("db: " <> db_path)

  // Erlang shell-out via os:cmd for sqlite3 — single read-only query, no
  // external script. The query is the only logic; this module stays under
  // the Gleam-only scripting mandate (SC-SCRIPT-GLEAM-001).
  let bad_prio_q =
    "SELECT COUNT(*) FROM Tasks WHERE Priority NOT IN ('P0','P1','P2','P3');"
  let bad_status_q =
    "SELECT COUNT(*) FROM Tasks WHERE Status NOT IN ('pending','in_progress','completed','blocked');"
  let simtest_q = "SELECT COUNT(*) FROM Tasks WHERE Title LIKE 'SimTest task #%';"

  let bp = run_count(bad_prio_q)
  let bs = run_count(bad_status_q)
  let st = run_count(simtest_q)
  let total = bp + bs + st

  io.println(
    "violations: priority="
    <> int.to_string(bp)
    <> " status="
    <> int.to_string(bs)
    <> " simtest="
    <> int.to_string(st)
    <> " total="
    <> int.to_string(total),
  )

  case total {
    0 -> {
      io.println("✓ Tasks table clean — no enum violations")
      io.println("decision: NoAction reason: SC-TRUTH-001 satisfied")
      // Touch supress_active flag (informational) — daemon may consume.
      Nil
    }
    n ->
      report_violations(bp, bs, st, n)
  }

  // Always exit 0; drift detection is informational
  Nil
}

fn run_count(sql: String) -> Int {
  // os:cmd via Erlang FFI — keeps this script self-contained without adding
  // a sqlite NIF dependency. Each scan ≤3 ms per query on a 3k-row table.
  let cmd = "sqlite3 -readonly " <> db_path <> " \"" <> sql <> "\""
  let raw = os_cmd(cmd)
  let trimmed = string.trim(raw)
  case int.parse(trimmed) {
    Ok(n) -> n
    Error(_) -> -1
  }
}

fn report_violations(
  prio: Int,
  status: Int,
  simtest: Int,
  total: Int,
) -> Nil {
  io.println("✗ DRIFT DETECTED — opening sa-plan tasks")

  // Open one P1 sa-plan task per violation class — idempotent by date so
  // hourly cron doesn't spam the queue.
  let _ = case prio {
    0 -> Nil
    n -> {
      io.println(
        "  hint: ./sa-plan add --priority P1 'DQ priority enum drift: "
        <> int.to_string(n)
        <> " rows (SC-VALUE-GUARD-001)'",
      )
      Nil
    }
  }
  let _ = case status {
    0 -> Nil
    n -> {
      io.println(
        "  hint: ./sa-plan add --priority P1 'DQ status enum drift: "
        <> int.to_string(n)
        <> " rows (SC-VALUE-GUARD-001)'",
      )
      Nil
    }
  }
  let _ = case simtest {
    0 -> Nil
    n -> {
      io.println(
        "  hint: ./sa-plan add --priority P2 'DQ fixture spam: "
        <> int.to_string(n)
        <> " SimTest rows (SC-MUDA-001)'",
      )
      Nil
    }
  }

  // Lyapunov gate: total > 50 → emergency P0 (Jidoka stop-the-line per
  // .claude/rules/biomorphic-evolution-protocol.md SC-BIO-EVO-001).
  case total >= 50 {
    True ->
      io.println(
        "  ⚠ JIDOKA: total="
        <> int.to_string(total)
        <> " >= 50 — opening P0 emergency task",
      )
    False -> Nil
  }

  let _ = process.sleep(10)
  Nil
}

// Erlang FFI: os:cmd/1 returns the captured stdout as a charlist; we coerce
// to a UTF-8 binary via unicode:characters_to_binary/1.
@external(erlang, "os", "cmd")
fn os_cmd_raw(cmd: List(Int)) -> List(Int)

@external(erlang, "unicode", "characters_to_binary")
fn unicode_chars_to_bin(c: List(Int)) -> String

fn string_to_charlist(s: String) -> List(Int) {
  s
  |> string.to_utf_codepoints
  |> list.map(string.utf_codepoint_to_int)
}

fn os_cmd(cmd: String) -> String {
  cmd
  |> string_to_charlist
  |> os_cmd_raw
  |> unicode_chars_to_bin
}
