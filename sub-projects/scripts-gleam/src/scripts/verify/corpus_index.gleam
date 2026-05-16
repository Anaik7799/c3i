//// scripts/verify/corpus_index — SC-CORPUS-INDEX validator.
////
//// Verifies that Smriti.db carries the required performance indexes
//// installed by Phase A of the perf-bench-20260516 pass. Without these
//// the stop-hook regresses from 9ms warm to 25s cold (2777× slowdown).
////
//// Exit 0 = all required indexes present. Exit 1 = at least one missing.
//// ZK lineage: [zk-bd82645aedcb5ef4] Stub-That-Lies — verify mechanically.

import argv
import gleam/erlang/charlist
import gleam/int
import gleam/io
import gleam/list
import gleam/string

const default_db_path: String =
  "/home/an/dev/ver/c3i/sub-projects/c3i/data/kms/smriti.db"

const required_indexes: List(String) = [
  "idx_holons_content_hash",
  "idx_holons_cluster",
  "idx_holons_level",
  "idx_holons_entropy",
  "idx_holons_updated",
  "idx_ingest_state_mtime",
]

@external(erlang, "scripts_sh_ffi", "run_capture_in")
fn sh_in(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
  cwd: charlist.Charlist,
) -> #(charlist.Charlist, Int)

fn cl(s: String) -> charlist.Charlist {
  charlist.from_string(s)
}

pub fn main() -> Nil {
  io.println("══ Corpus Index Validator (SC-CORPUS-INDEX) ══")
  // SC-VALIDATORS-META-TEST-001 — accept optional argv[1] db path override
  // so the validator can be exercised against synthetic empty-index dbs.
  // Default = production Smriti.db.
  let db = case argv.load().arguments {
    [path, ..] -> path
    [] -> default_db_path
  }
  io.println("db: " <> db)

  let missing = list.filter(required_indexes, fn(idx) { !present(db, idx) })

  case missing {
    [] -> {
      io.println(
        "✓ all "
        <> int.to_string(list.length(required_indexes))
        <> " required indexes present",
      )
      Nil
    }
    _ -> {
      io.println(
        "✗ "
        <> int.to_string(list.length(missing))
        <> " SC-CORPUS-INDEX violations:",
      )
      list.each(missing, fn(i) { io.println("  • missing: " <> i) })
      io.println(
        "hint: sa-plan add --priority P0 'Restore Smriti.db perf indexes per SC-CORPUS-INDEX'",
      )
    }
  }
}

fn present(db: String, idx_name: String) -> Bool {
  let query =
    "SELECT 1 FROM sqlite_master WHERE type='index' AND name='"
    <> idx_name
    <> "' LIMIT 1;"
  let #(out, _rc) =
    sh_in(cl("sqlite3"), [cl(db), cl(query)], cl("/home/an/dev/ver/c3i"))
  string.contains(charlist.to_string(out), "1")
}
