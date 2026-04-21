//// scripts/common/saplan — uniform wrapper around the `sa-plan` binary, the
//// single system-integration surface for gleam scripts.
////
//// SC-SCRIPT-GLEAM-001 — thin binary invocation is explicitly allowed.
//// SC-SCHED-WORK-001 — workers::dispatch in the Rust daemon is the only
//// runtime executor; we integrate with it by calling `./sa-plan ...`.
////
//// This helper hides the correct CWD + binary path so every script uses the
//// system's real, running authority.

import gleam/erlang/charlist
import gleam/list
import gleam/string
import envoy

/// Path to the sa-plan binary. Prefers env `SAPLAN_BIN`, then the known
/// release layout inside the c3i sub-project.
pub fn binary() -> String {
  case envoy.get("SAPLAN_BIN") {
    Ok(v) -> v
    Error(_) -> {
      let root = case envoy.get("C3I_REPO_ROOT") {
        Ok(v) -> v
        Error(_) -> "/home/an/dev/ver/c3i"
      }
      root <> "/sub-projects/c3i/sa-plan"
    }
  }
}

pub type Run {
  Run(rc: Int, stdout: String, stderr: String)
}

/// Erlang OS-port bridge (run in default erlang CWD).
@external(erlang, "scripts_sh_ffi", "run_capture")
fn sh_run_capture(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
) -> #(charlist.Charlist, Int)

/// Erlang OS-port bridge with explicit CWD (needed for sa-plan which opens
/// `data/smriti/Smriti.db` relative to the c3i sub-project).
@external(erlang, "scripts_sh_ffi", "run_capture_in")
fn sh_run_capture_in(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
  cwd: charlist.Charlist,
) -> #(charlist.Charlist, Int)

fn to_cl(s: String) -> charlist.Charlist {
  charlist.from_string(s)
}

/// Directory sa-plan expects as its CWD (authoritative path).
fn saplan_cwd() -> String {
  let root = case envoy.get("C3I_REPO_ROOT") {
    Ok(v) -> v
    Error(_) -> "/home/an/dev/ver/c3i"
  }
  root <> "/sub-projects/c3i"
}

/// Invoke `sa-plan <args>` with the correct CWD set. Stdout+stderr are
/// merged into the `stdout` field.
pub fn invoke(args: List(String)) -> Run {
  let #(out, rc) =
    sh_run_capture_in(
      to_cl(binary()),
      list.map(args, to_cl),
      to_cl(saplan_cwd()),
    )
  Run(rc, charlist.to_string(out), "")
}

/// Typed helper: add a task. Returns the run object; callers parse the id
/// from stdout or rely on state snapshots from other calls.
pub fn add_task(title: String, priority: String) -> Run {
  invoke(["add", title, priority])
}

/// Mark an existing task as completed (or any status string the CLI accepts).
pub fn update_task(id: String, status: String) -> Run {
  invoke(["update", id, status])
}

/// Set a Smriti preference under a category.
pub fn set_pref(category: String, key: String, value: String) -> Run {
  invoke([
    "set-pref", "--category", category,
    "--key", key, "--value", value,
  ])
}

/// Enqueue an Oban-style job through `sa-plan job-enqueue`.
pub fn enqueue(
  queue: String,
  worker: String,
  args_json: String,
  unique_key: String,
) -> Run {
  invoke([
    "job-enqueue",
    "--queue", queue,
    "--worker", worker,
    "--args", args_json,
    "--priority", "0",
    "--max-attempts", "2",
    "--unique-key", unique_key,
  ])
}

/// Request a queue state snapshot (JSON on stdout).
pub fn queue_list() -> Run {
  invoke(["queue-list", "--json"])
}

/// Thin wrapper for sending email with attachments (absolute paths required).
pub fn send_email(
  to: String,
  subject: String,
  body: String,
  attachments: List(String),
) -> Run {
  let base = [
    "send-email", "--to", to, "--subject", subject, "--body", body,
  ]
  let attach_args =
    list.flat_map(attachments, fn(a) { ["--attach", a] })
  invoke(list.append(base, attach_args))
}

/// Smoke: true if `sa-plan --help` exits 0.
pub fn available() -> Bool {
  let Run(rc, _, _) = invoke(["--help"])
  rc == 0
}

/// Debug-render of a Run's first 200 chars (for logs).
pub fn render(r: Run) -> String {
  "rc=" <> case r.rc {
    0 -> "0"
    _ -> "nonzero"
  }
  <> " out=" <> string.slice(r.stdout, 0, 200)
}
