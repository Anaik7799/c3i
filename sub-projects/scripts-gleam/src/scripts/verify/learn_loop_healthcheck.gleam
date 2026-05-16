//// scripts/verify/learn_loop_healthcheck — SC-LEARN-LOOP-HEALTHCHECK aggregator.
////
//// One operator command runs all 5 institutional-memory-loop validators
//// shipped in the perf-bench-20260516 closure arc:
////
////   1. cpig_consistency      — L5 governance honesty
////   2. corpus_index          — L3 perf invariant
////   3. stop_hook_lyapunov    — L5 stop-hook observability consumer
////   4. disk_trend            — L4 disk emit + classify
////   5. disk_lyapunov         — L5 disk observability consumer
////
//// Exit 0 iff every validator reports ✓ (no P0/P1).
//// ZK lineage: [zk-bd82645aedcb5ef4] Stub-That-Lies — invoke, do not assert.

import gleam/erlang/charlist
import gleam/int
import gleam/io
import gleam/list
import gleam/string

@external(erlang, "scripts_sh_ffi", "run_capture_in")
fn sh_in(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
  cwd: charlist.Charlist,
) -> #(charlist.Charlist, Int)

fn cl(s: String) -> charlist.Charlist {
  charlist.from_string(s)
}

const repo_root: String = "/home/an/dev/ver/c3i/sub-projects/scripts-gleam"

const validators: List(String) = [
  "scripts/verify/cpig_consistency",
  "scripts/verify/corpus_index",
  "scripts/verify/stop_hook_lyapunov",
  "scripts/verify/disk_trend",
  "scripts/verify/disk_lyapunov",
  // SC-VALIDATORS-META-TEST — proves the Lyapunov detectors above
  // actually trip on synthetic bad input (anti-Stub-That-Lies for the
  // detectors themselves). Last because it briefly swaps log files.
  "scripts/verify/validators_meta_test",
  // SC-AGUI-UI-WIRING-DEPTH — proves agui-chrome.js carries the JS handler
  // signatures backing each HTML-detectable chrome component. Sibling of
  // SC-AGUI-UI-CONFORMANCE (substring → presence) at the wiring layer.
  "scripts/verify/agui_js_depth",
]

pub fn main() -> Nil {
  io.println("══ Learn-Loop Health Check (SC-LEARN-LOOP-HEALTHCHECK) ══")

  let results = list.map(validators, run_one)
  let failures = list.filter(results, fn(r) {
    let #(_, verdict) = r
    verdict != "✓"
  })

  io.println("")
  io.println("── summary ──")
  list.each(results, fn(r) {
    let #(name, verdict) = r
    io.println("  " <> verdict <> "  " <> name)
  })

  case failures {
    [] ->
      io.println(
        "\n✓ all "
        <> int.to_string(list.length(results))
        <> " validators report homeostasis",
      )
    _ ->
      io.println(
        "\n✗ "
        <> int.to_string(list.length(failures))
        <> " validator(s) reported alarm — see logs above",
      )
  }
}

fn run_one(module_path: String) -> #(String, String) {
  io.println("\n── " <> module_path <> " ──")
  let #(out, _rc) =
    sh_in(
      cl("gleam"),
      [cl("run"), cl("-m"), cl(module_path)],
      cl(repo_root),
    )
  let raw = charlist.to_string(out)
  let verdict = extract_verdict(raw)
  // print last 4 lines (validator's own summary)
  let _ = print_tail(raw, 4)
  #(module_path, verdict)
}

fn extract_verdict(raw: String) -> String {
  // Match the classification line shape ("✗ P0 —", "✗ P1 —", "⚠ P2 —"),
  // not the hint string (which always mentions the constraint name).
  // Also handle the meta-test's failure shape ("✗ multiple meta-tests failed").
  case string.contains(raw, "meta-tests failed") {
    True -> "✗META"
    False ->
      case string.contains(raw, "✗ P0") {
        True -> "✗P0"
        False ->
          case string.contains(raw, "✗ P1") {
            True -> "✗P1"
            False ->
              case string.contains(raw, "⚠ P2") || string.contains(raw, "⚠ P1") {
                True -> "⚠P2"
                False -> "✓"
              }
          }
      }
  }
}

fn print_tail(raw: String, n: Int) -> Nil {
  let lines = string.split(raw, "\n")
  let total = list.length(lines)
  let drop_count = case total - n {
    d if d > 0 -> d
    _ -> 0
  }
  let tail = list.drop(lines, drop_count)
  list.each(tail, fn(l) {
    case string.length(string.trim(l)) {
      0 -> Nil
      _ -> io.println("    " <> l)
    }
  })
}
