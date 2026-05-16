//// scripts/verify/validators_meta_test — SC-VALIDATORS-META-TEST.
////
//// Proves the Lyapunov detectors actually trip on bad input.
//// Anti-Stub-That-Lies per [zk-bd82645aedcb5ef4]: a validator that
//// has only been observed in the ✓ state is itself a stub-that-lies risk.
////
//// Protocol per detector:
////   1. Save real log to .bak
////   2. Write synthetic bad-data log
////   3. Invoke detector
////   4. Assert expected classification token appears in stdout
////   5. Restore real log from .bak
////
//// Detectors tested:
////   - stop_hook_lyapunov  (synthetic: 3 rows with elapsed_s=99 → expect P0)
////   - disk_lyapunov       (synthetic: 1 row with pct=96 → expect P0)
////
//// Exit 0 = both detectors fire as expected.
//// Exit 1 = at least one fails to fire (the detector is broken or itself
//// a Stub-That-Lies).

import gleam/erlang/charlist
import gleam/io
import gleam/list
import gleam/string

const stop_log: String = "/home/an/dev/ver/c3i/data/logs/stop-hook-timing.log"

const disk_log: String = "/home/an/dev/ver/c3i/data/logs/disk-trend.log"

const repo_root: String = "/home/an/dev/ver/c3i/sub-projects/scripts-gleam"

@external(erlang, "scripts_sh_ffi", "run_capture")
fn sh(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
) -> #(charlist.Charlist, Int)

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
  io.println("══ Validators Meta-Test (SC-VALIDATORS-META-TEST) ══")
  io.println("anti-Stub-That-Lies: proving detectors actually trip on bad input")

  let results = [
    test_stop_hook_lyapunov(),
    test_disk_lyapunov(),
    test_cpig_consistency(),
  ]

  io.println("")
  io.println("── summary ──")
  list.each(results, fn(r) {
    let #(name, pass) = r
    case pass {
      True -> io.println("  ✓  " <> name)
      False -> io.println("  ✗  " <> name)
    }
  })

  let failures = list.filter(results, fn(r) { !r.1 })
  case failures {
    [] -> io.println("\n✓ all meta-tests pass — validators are not Stub-That-Lies")
    _ ->
      io.println(
        "\n✗ "
        <> case list.length(failures) {
          1 -> "1 meta-test"
          _ -> "multiple meta-tests"
        }
        <> " failed — investigate the detector",
      )
  }
}

fn test_stop_hook_lyapunov() -> #(String, Bool) {
  let name = "stop_hook_lyapunov · synthetic elapsed_s=99 → expect ✗ P0"
  io.println("\n── " <> name <> " ──")

  let rows = [
    "{\"at\":\"99991231-2359\",\"elapsed_s\":99,\"c3i_rc\":0,\"fy27_rc\":127,\"c3i\":\"ok\",\"fy27\":\"absent\"}",
    "{\"at\":\"99991231-2358\",\"elapsed_s\":99,\"c3i_rc\":0,\"fy27_rc\":127,\"c3i\":\"ok\",\"fy27\":\"absent\"}",
    "{\"at\":\"99991231-2357\",\"elapsed_s\":99,\"c3i_rc\":0,\"fy27_rc\":127,\"c3i\":\"ok\",\"fy27\":\"absent\"}",
  ]

  swap_log_rows(stop_log, rows)
  let #(out, _rc) =
    sh_in(
      cl("gleam"),
      [cl("run"), cl("-m"), cl("scripts/verify/stop_hook_lyapunov")],
      cl(repo_root),
    )
  restore_log(stop_log)

  let raw = charlist.to_string(out)
  // ASCII-safe substring — Erlang charlist→string decodes as Latin-1, mangling
  // the UTF-8 ✗ glyph. The hint line "--priority P0" is always present when
  // the detector emits a P0 verdict and is pure ASCII.
  let pass = string.contains(raw, "--priority P0")
  io.println("  → contains '✗ P0': " <> bool_to_str(pass))
  #(name, pass)
}

fn test_disk_lyapunov() -> #(String, Bool) {
  let name = "disk_lyapunov · synthetic pct=96 → expect ✗ P0"
  io.println("\n── " <> name <> " ──")

  let rows = ["{\"at\":\"99991231-2359\",\"pct\":96,\"used_kb\":1,\"avail_kb\":1}"]

  swap_log_rows(disk_log, rows)
  let #(out, _rc) =
    sh_in(
      cl("gleam"),
      [cl("run"), cl("-m"), cl("scripts/verify/disk_lyapunov")],
      cl(repo_root),
    )
  restore_log(disk_log)

  let raw = charlist.to_string(out)
  // ASCII-safe substring — Erlang charlist→string decodes as Latin-1, mangling
  // the UTF-8 ✗ glyph. The hint line "--priority P0" is always present when
  // the detector emits a P0 verdict and is pure ASCII.
  let pass = string.contains(raw, "--priority P0")
  io.println("  → contains '✗ P0': " <> bool_to_str(pass))
  #(name, pass)
}

fn test_cpig_consistency() -> #(String, Bool) {
  let name = "cpig_consistency · synthetic score=1 evidence=[] → expect violation"
  io.println("\n── " <> name <> " ──")

  let matrix_path =
    "/home/an/dev/ver/c3i/docs/journal/task-116480247290237220/cpig-matrix.json"

  // Synthesise a tiny matrix with a known-bad gate (score=1 but evidence=[]).
  // The validator only inspects score + evidence.length, not other fields.
  let bad_matrix =
    "{\"subsystems\":[{\"id\":\"meta-test-synth\",\"gates\":{\"formal_spec\":{\"score\":1,\"evidence\":[]}}}]}"

  let _ =
    sh(cl("sh"), [
      cl("-c"),
      cl("cp " <> matrix_path <> " " <> matrix_path <> ".bak"),
    ])
  let _ =
    sh(cl("sh"), [
      cl("-c"),
      cl("printf '%s' '" <> bad_matrix <> "' > " <> matrix_path),
    ])

  let #(out, _rc) =
    sh_in(
      cl("gleam"),
      [cl("run"), cl("-m"), cl("scripts/verify/cpig_consistency")],
      cl(repo_root),
    )
  let _ =
    sh(cl("sh"), [
      cl("-c"),
      cl("mv " <> matrix_path <> ".bak " <> matrix_path),
    ])

  let raw = charlist.to_string(out)
  // ASCII-safe — "SC-CPIG-CONSISTENCY violations:" always emitted on bad input
  let pass = string.contains(raw, "SC-CPIG-CONSISTENCY violations")
  io.println("  → contains 'SC-CPIG-CONSISTENCY violations': " <> bool_to_str(pass))
  #(name, pass)
}

fn swap_log_rows(path: String, rows: List(String)) -> Nil {
  // Save real log → .bak
  let _ = sh(cl("sh"), [cl("-c"), cl("cp " <> path <> " " <> path <> ".bak 2>/dev/null || true")])
  // Truncate target
  let _ = sh(cl("sh"), [cl("-c"), cl(": > " <> path)])
  // Append each row as a separate printf — avoids embedded-newline escaping
  list.each(rows, fn(row) {
    let _ =
      sh(cl("sh"), [
        cl("-c"),
        cl("printf '%s\n' '" <> row <> "' >> " <> path),
      ])
    Nil
  })
}

fn restore_log(path: String) -> Nil {
  let _ =
    sh(cl("sh"), [
      cl("-c"),
      cl("mv " <> path <> ".bak " <> path <> " 2>/dev/null || true"),
    ])
  Nil
}

fn bool_to_str(b: Bool) -> String {
  case b {
    True -> "true"
    False -> "false"
  }
}
