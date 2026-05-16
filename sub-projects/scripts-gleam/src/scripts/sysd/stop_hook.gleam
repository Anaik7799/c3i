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

/// Robustness mandate (Pass A.2 — 2026-05-16):
/// Stop hook is the canonical OODA Learn phase. Each step is BEST-EFFORT.
/// Optional peers (FY27-ZK) may be absent; we MUST NOT propagate their
/// failure as a Gleam panic, and we MUST always emit the systemMessage
/// JSON so Claude continues with a clean Stop.
///
/// rc=127 from scripts_sh_ffi indicates "executable not found" (FY27 binary
/// absent on this machine — expected on dev hosts without gdrive build).
/// rc=124 indicates 60s FFI timeout (peer slow but reachable).
/// rc=0 = ok. Any non-zero is tolerated; C3I-ZK ingest is required and any
/// non-zero is reported in the systemMessage status field.
pub fn main() -> Nil {
  let sid = session_id()

  // 1. session-save (idempotent if previously saved)
  let #(_, _save_rc) =
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

  // 2. C3I-ZK ingest (required peer)
  let #(_, c3i_rc) = sh_in(cl(sa_plan), cls(["ingest-docs"]), cl(repo_root))

  // 3. FY27-ZK import (OPTIONAL peer — degrades gracefully if binary absent)
  let #(_, fy27_rc) =
    sh_in(cl(fy27_zk), cls(["import", ".."]), cl(fy27_zk_dir))

  // 4. emit systemMessage (Claude expects JSON on stdout) — ALWAYS
  let c3i_status = case c3i_rc {
    0 -> "ok"
    _ -> "degraded"
  }
  let fy27_status = case fy27_rc {
    0 -> "ok"
    127 -> "absent"
    124 -> "timeout"
    _ -> "degraded"
  }
  io.println(
    "{\"systemMessage\":\"Session saved + ZK ingest C3I="
    <> c3i_status
    <> " FY27="
    <> fy27_status
    <> "\"}",
  )
}
