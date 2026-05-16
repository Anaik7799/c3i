//// scripts/verify/agui_chrome_presence — SC-AGUI-UI-CHROME-PRESENCE.
////
//// Per-page structural verification: for each of the 32 pages, probe live
//// HTML for the 5 wired chrome elements introduced in passes 28-32:
////
////   1. fractal-chip × 9 (all L0-L7 + All)             — UI-002
////   2. ai-search-input (input element)                — UI-003
////   3. agui-detail-body (drill-down container id)     — UI-004
////   4. chat-panel-form (gemma chat form element)      — UI-005
////   5. change-log-feed (event feed container)         — UI-007
////
//// Strengthens SC-AGUI-UI-CONFORMANCE which checks class-name substrings.
//// This validator checks structural IDs and the count of fractal-chip
//// elements (must be ≥ 9 to satisfy L0-L7 + All).
////
//// Per [zk-bd82645aedcb5ef4] anti-Stub-That-Lies: counts elements via
//// substring grep on live curl output. A page with the class names but
//// without the IDs would fail here, even if agui_conformance passes.

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

const required_ids: List(#(String, String)) = [
  #("UI-003 ai-search input", "ai-search-input"),
  #("UI-004 drill-down body", "agui-detail-body"),
  #("UI-005 chat form", "chat-panel-form"),
  #("UI-005 chat input", "agui-chat-input"),
  #("UI-007 change-log feed", "change-log-feed"),
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
  io.println("══ SC-AGUI-UI-CHROME-PRESENCE — Per-page structural probe ══")

  let results = list.map(pages, fn(path) {
    let url = base <> path
    let #(out, _rc) =
      sh(cl("curl"), [cl("-s"), cl("--max-time"), cl("5"), cl(url)])
    let html = charlist.to_string(out)

    let id_misses = list.filter(required_ids, fn(rid) {
      let #(_, needle) = rid
      !string.contains(html, needle)
    })
    let chip_count = count_substr(html, "fractal-chip ")
    let chips_ok = chip_count >= 9

    let ok = list.length(id_misses) == 0 && chips_ok
    #(path, ok, list.length(id_misses), chip_count)
  })

  let failed = list.filter(results, fn(r) { !r.1 })
  io.println("")
  case failed {
    [] -> {
      io.println(
        "✓ all "
        <> int.to_string(list.length(pages))
        <> " pages carry the 5 structural chrome IDs + ≥9 fractal chips",
      )
    }
    _ -> {
      io.println(
        "✗ "
        <> int.to_string(list.length(failed))
        <> " pages with structural chrome gaps:",
      )
      list.each(failed, fn(r) {
        let #(path, _, miss_n, chip_n) = r
        io.println(
          "  • "
          <> path
          <> "  missing_ids="
          <> int.to_string(miss_n)
          <> "  chips="
          <> int.to_string(chip_n),
        )
      })
      io.println(
        "hint: sa-plan add --priority P0 'Restore AGUI chrome structural IDs per SC-AGUI-UI-CHROME-PRESENCE'",
      )
    }
  }
}

fn count_substr(haystack: String, needle: String) -> Int {
  case string.split(haystack, needle) {
    parts -> list.length(parts) - 1
  }
}
