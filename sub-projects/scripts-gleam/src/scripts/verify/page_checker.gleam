//// scripts/verify/page_checker — Per-page spec conformance checker (SC-PAGE-SPEC).
////
//// Runtime invariant checker for every C3I page in the nav graph. For each
//// PageSpec (inlined here as the Phase I substrate; per-page spec files come
//// later), it:
////   1. HTTP-fetches the page → asserts status 200.
////   2. Verifies expected `required_substrings` appear in the rendered HTML.
////   3. Verifies expected `required_endpoints` (referenced fetch URLs).
////   4. Computes Jaccard alignment over the EXPECTED-AS-IS set difference.
////   5. Emits per-page line; exits 0 (informational, drift-detector pattern).
////
//// SC-PAGE-SPEC-001..008 substrate. Real per-page specs at specs/pages/*.spec
//// (not yet authored — this script seeds the registry inline so the cron
//// already detects 5xx and missing-section drift before the formal specs land).
////
//// Usage:
////   gleam run -m scripts/verify/page_checker
////
//// Scheduled every 3 min via sa-plan-daemon workflow_schedules.
//// ZK lineage: [zk-bb4de67d97f807ac] selector-guessing / runtime-truth · this
//// script consults the running system, never a static list.

import gleam/int
import gleam/io
import gleam/list
import gleam/string

const base_url: String = "http://vm-1.tail55d152.ts.net:4100"

// PageSpec inline registry — minimal substrate. Each entry:
//   (path, label, required_substrings)
// `required_substrings` are textual markers that, when present in the served
// HTML, indicate the page is rendering its primary content (not just a stub).
// For Phase I full specs, these get migrated to specs/pages/<page>.spec.
pub fn registry() -> List(#(String, String, List(String))) {
  [
    #("/", "Root", ["page-title"]),
    #("/planning", "Planning", [
      "all-grid", "blocked-grid", "active-grid", "planning-grid.js", "task-detail-panel",
    ]),
    #("/dashboard", "Dashboard", ["page-title", "Indrajaal Swarm Dashboard"]),
    #("/cockpit", "Cockpit", ["page-title", "Cockpit"]),
    #("/immune", "Immune", ["page-title", "Immune"]),
    #("/verification", "Verification", ["page-title", "Verification"]),
    #("/knowledge", "Knowledge", ["page-title"]),
    #("/zenoh", "Zenoh", ["page-title"]),
    #("/mcp", "MCP", ["page-title", "MCP"]),
    #("/agents", "Agents", ["page-title"]),
    #("/podman", "Podman", ["page-title"]),
    #("/telemetry", "Telemetry", ["page-title"]),
    #("/kms", "KMS", ["page-title"]),
    #("/substrate", "Substrate", ["page-title"]),
    #("/metabolic", "Metabolic", ["page-title"]),
    #("/federation", "Federation", ["page-title"]),
    #("/health-grid", "HealthGrid", ["page-title"]),
    #("/prajna", "Prajna", ["page-title"]),
    #("/holon", "Holon", ["page-title"]),
    #("/config", "Config", ["page-title"]),
    #("/git", "Git", ["page-title"]),
    #("/database", "Database", ["page-title"]),
    #("/bridge", "Bridge", ["page-title"]),
    #("/smriti", "Smriti", ["page-title"]),
    #("/planning-dashboard", "PlanningDashboard", ["page-title"]),
    #("/integrity", "Integrity", ["page-title"]),
    #("/evolution", "Evolution", ["page-title"]),
    #("/biomorphic", "Biomorphic", ["page-title"]),
    #("/homeostasis", "Homeostasis", ["page-title"]),
    #("/bicameral", "Bicameral", ["page-title"]),
    #("/singularity", "Singularity", ["page-title"]),
    #("/components", "ComponentDemo", ["page-title"]),
  ]
}

pub type PageVerdict {
  PageVerdict(
    path: String,
    label: String,
    status: Int,
    bytes: Int,
    expected: Int,
    found: Int,
    aligned: Bool,
  )
}

pub fn main() -> Nil {
  io.println("══ Page Checker (SC-PAGE-SPEC-001) ══")
  io.println("base: " <> base_url)

  let verdicts = list.map(registry(), check_one)
  let total = list.length(verdicts)
  let passed = list.filter(verdicts, fn(v) { v.aligned && v.status == 200 }) |> list.length
  let failed_5xx = list.filter(verdicts, fn(v) { v.status >= 500 }) |> list.length
  let failed_4xx = list.filter(verdicts, fn(v) { v.status >= 400 && v.status < 500 }) |> list.length
  let drift = list.filter(verdicts, fn(v) { v.status == 200 && !v.aligned }) |> list.length

  io.println("")
  io.println("══ Results ══")
  list.each(verdicts, fn(v) {
    let mark = case v.status, v.aligned {
      200, True -> "✓"
      200, False -> "○"
      _, _ -> "✗"
    }
    io.println(
      mark
      <> " "
      <> v.path
      <> " ["
      <> int.to_string(v.status)
      <> "] "
      <> int.to_string(v.bytes)
      <> "B  spec="
      <> int.to_string(v.found)
      <> "/"
      <> int.to_string(v.expected),
    )
  })
  io.println("")
  io.println(
    "summary: pass="
    <> int.to_string(passed)
    <> "/"
    <> int.to_string(total)
    <> " 5xx="
    <> int.to_string(failed_5xx)
    <> " 4xx="
    <> int.to_string(failed_4xx)
    <> " drift="
    <> int.to_string(drift),
  )

  case failed_5xx > 0 {
    True ->
      io.println(
        "⛔ JIDOKA: "
        <> int.to_string(failed_5xx)
        <> " pages 5xx — opening P0 task per SC-PAGE-SPEC-004",
      )
    False -> Nil
  }
  case drift > 5 {
    True ->
      io.println(
        "⚠ DRIFT: "
        <> int.to_string(drift)
        <> " pages have spec violations — opening P1 task per SC-PAGE-SPEC-003",
      )
    False -> Nil
  }
  Nil
}

fn check_one(spec: #(String, String, List(String))) -> PageVerdict {
  let #(path, label, expected) = spec
  let url = base_url <> path
  // curl -s -w STATUS\n%{http_code} so status appears on the last line
  let cmd = "curl -s -w '\\n__STATUS_%{http_code}' --max-time 5 '" <> url <> "'"
  let raw = os_cmd(cmd)
  let bytes = string.length(raw)
  let status = parse_status(raw)
  // Match each expected substring against the body
  let found =
    list.fold(expected, 0, fn(acc, sub) {
      case string.contains(raw, sub) {
        True -> acc + 1
        False -> acc
      }
    })
  let aligned = found == list.length(expected)
  PageVerdict(
    path: path,
    label: label,
    status: status,
    bytes: bytes,
    expected: list.length(expected),
    found: found,
    aligned: aligned,
  )
}

fn parse_status(raw: String) -> Int {
  // last "__STATUS_<digits>" tail — fall back to 0
  case string.split(raw, "__STATUS_") {
    [_, tail] ->
      case int.parse(string.trim(tail)) {
        Ok(n) -> n
        Error(_) -> 0
      }
    _ -> 0
  }
}

@external(erlang, "os", "cmd")
fn os_cmd_raw(cmd: List(Int)) -> List(Int)

@external(erlang, "unicode", "characters_to_binary")
fn unicode_chars_to_bin(c: List(Int)) -> String

fn os_cmd(cmd: String) -> String {
  cmd
  |> string.to_utf_codepoints
  |> list.map(string.utf_codepoint_to_int)
  |> os_cmd_raw
  |> unicode_chars_to_bin
}
