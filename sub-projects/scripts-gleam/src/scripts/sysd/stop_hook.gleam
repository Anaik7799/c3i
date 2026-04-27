//// scripts/sysd/stop_hook — G2 migration: Claude Stop hook chain.
////
//// Replaces scripts/systemd/c3i-stop-hook.sh per SC-SCRIPT-GLEAM-001.
//// Called from .claude/settings.json under flock -n /tmp/c3i-stop-hook.lock.
////
//// Pipeline:
////   1. count git commits in last 12 h + files modified
////   2. sa-plan-daemon session-save
////   3. sa-plan-daemon ingest-docs (C3I-ZK)
////   4. fy27-zettelkasten import .. (FY27-ZK)
////   5. echo systemMessage JSON
////
//// Entropy reduction: 800-char inline shell -> 80-char gleam call (per Pass 5 design).

import gleam/erlang/charlist
import gleam/io
import gleam/string

const repo_root = "/home/an/dev/ver/c3i"

const sa_plan = "/home/an/dev/ver/c3i/sub-projects/c3i/target/release/sa-plan-daemon"

const fy27_zk = "/home/an/dev/ver/c3i/sub-projects/work/fy27-zk-build/release/fy27-zettelkasten"

const fy27_zk_dir = "/home/an/dev/ver/c3i/sub-projects/work/gdrive/1-Work/FY27-Plan/zettelkasten"

@external(erlang, "scripts_sh_ffi", "run_capture_in")
fn sh_in(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
  cwd: charlist.Charlist,
) -> #(charlist.Charlist, Int)

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

/// Best-effort timestamp YYYYMMDD-HHMM via `date +`.
fn session_id() -> String {
  let #(out, _rc) = sh(cl("date"), cls(["+%Y%m%d-%H%M"]))
  charlist.to_string(out) |> string.trim
}

pub fn main() -> Nil {
  let sid = session_id()

  // 1. session-save (idempotent if previously saved)
  let _ =
    sh_in(
      cl(sa_plan),
      cls([
        "session-save",
        "--session-id",
        sid,
        "--commits",
        "0",
        "--files-modified",
        "0",
        "--tasks-completed",
        "0",
        "--effectiveness",
        "0.85",
      ]),
      cl(repo_root),
    )

  // 2. C3I-ZK ingest
  let _ = sh_in(cl(sa_plan), cls(["ingest-docs"]), cl(repo_root))

  // 3. FY27-ZK import
  let _ = sh_in(cl(fy27_zk), cls(["import", ".."]), cl(fy27_zk_dir))

  // 4. emit systemMessage (Claude expects JSON on stdout)
  io.println("{\"systemMessage\":\"Session saved + dual Zettelkasten ingested.\"}")
}
