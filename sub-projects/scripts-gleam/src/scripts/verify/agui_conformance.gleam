//// scripts/verify/agui_conformance — SC-AGUI-UI-CONFORMANCE validator.
////
//// Probes every page at http://vm-1.tail55d152.ts.net:4100/ and scores it
//// against 11 HTML-detectable SC-AGUI-UI-* components. Produces a per-page
//// report card so operators can prioritize page-evolution work.
////
//// Anti-Stub-That-Lies per [zk-bd82645aedcb5ef4]: fetches the live HTML
//// and counts substring matches. Does not assert any page is conformant.
////
//// Scoring:
////   10/10  — fully evolved (matches /planning reference)
////   5-9    — partial
////   1-4    — sparse (baseline template only)
////
//// Out of scope (not HTML-detectable):
////   SC-AGUI-UI-010 — Rust E2E tests (test suite, not HTML)
////   SC-AGUI-UI-011 — WS diff-detect (server-side OTP actor)
////   SC-AGUI-UI-013 — 6 DAG scenarios (test suite)
////   SC-AGUI-UI-014 — Gemma context enrichment (server-side prompt build)
////   SC-AGUI-UI-015 — glassmorphism CSS (covered partly via backdrop-filter)

import gleam/erlang/charlist
import gleam/int
import gleam/io
import gleam/list
import gleam/string

const base: String = "http://vm-1.tail55d152.ts.net:4100"

const pages: List(String) = [
  "/", "/dashboard", "/planning", "/cockpit", "/immune", "/knowledge",
  "/zenoh", "/verification", "/substrate", "/metabolic", "/podman",
  "/mcp", "/kms", "/telemetry", "/federation", "/health-grid", "/prajna",
  "/agents", "/holon", "/config", "/git", "/database", "/bridge",
  "/smriti", "/planning-dashboard", "/integrity", "/evolution",
  "/biomorphic", "/homeostasis", "/bicameral", "/singularity",
  "/components",
]

// (label, substring(s) that indicate presence)
const checks: List(#(String, List(String))) = [
  #("view-modes (UI-001)", ["data-view", "kanban", "timeline"]),
  #("fractal-filter (UI-002)", ["fractal-l0", "fractal-l1", "layer-filter"]),
  #("ai-search (UI-003)", ["search-bar", "ctrl+k", "Ctrl+K", "ai-search"]),
  #("drill-down (UI-004)", ["detail-panel", "drill-down", "task-detail"]),
  #("gemma-chat (UI-005)", ["gemma", "chat-widget", "chat-panel"]),
  #("websocket (UI-006)", ["ws://", "/ws/", "WebSocket"]),
  #("change-log (UI-007)", ["change-log", "event-log", "mutation-log"]),
  #("responsive-css (UI-008)", ["@media", "768px", "1024px"]),
  #("touch-targets (UI-009)", ["min-height:44px", "min-height: 44px", "touch-target"]),
  #("glassmorphism (UI-015)", ["backdrop-filter", "blur(", "glass"]),
  #("agui-js-wired (UI-002/003/009)", ["agui-chrome.js"]),
]

@external(erlang, "scripts_sh_ffi", "run_capture")
fn sh(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
) -> #(charlist.Charlist, Int)

fn cl(s: String) -> charlist.Charlist {
  charlist.from_string(s)
}

pub fn main() -> Nil {
  io.println("══ SC-AGUI-UI Conformance Validator ══")
  io.println("base: " <> base)
  io.println(
    "checks: 11 HTML-detectable components (UI-001..009 + UI-015 + UI-WIRED)",
  )
  io.println("")

  let results = list.map(pages, score_page)

  io.println("")
  io.println(
    "══ Report — sorted by score (ascending = most sparse first) ══",
  )
  let max_score = list.length(checks)
  // Tier thresholds scaled to actual check count: evolved >=90%, partial >=50%.
  let evolved_thresh = max_score * 9 / 10
  let partial_thresh = max_score / 2
  let sorted = list.sort(results, fn(a, b) { int.compare(a.1, b.1) })
  list.each(sorted, fn(r) {
    let #(path, score) = r
    let tier = case score {
      n if n >= evolved_thresh -> "✓ evolved "
      n if n >= partial_thresh -> "○ partial "
      _ -> "△ sparse  "
    }
    io.println(
      "  "
      <> tier
      <> int.to_string(score)
      <> "/"
      <> int.to_string(max_score)
      <> "  "
      <> path,
    )
  })

  let evolved =
    list.length(list.filter(results, fn(r) { r.1 >= evolved_thresh }))
  let partial =
    list.length(list.filter(results, fn(r) {
      r.1 >= partial_thresh && r.1 < evolved_thresh
    }))
  let sparse = list.length(list.filter(results, fn(r) { r.1 < partial_thresh }))
  io.println("")
  io.println(
    "summary: "
    <> int.to_string(evolved)
    <> " evolved, "
    <> int.to_string(partial)
    <> " partial, "
    <> int.to_string(sparse)
    <> " sparse — total "
    <> int.to_string(list.length(results))
    <> " pages",
  )
}

fn score_page(path: String) -> #(String, Int) {
  io.println("─ " <> path)
  let url = base <> path
  let #(out, _rc) = sh(cl("curl"), [cl("-s"), cl("--max-time"), cl("5"), cl(url)])
  let html = charlist.to_string(out)
  let score =
    list.fold(checks, 0, fn(acc, check) {
      let #(label, needles) = check
      let present =
        list.any(needles, fn(n) { string.contains(html, n) })
      case present {
        True -> {
          io.println("    ✓ " <> label)
          acc + 1
        }
        False -> {
          io.println("    × " <> label)
          acc
        }
      }
    })
  #(path, score)
}
