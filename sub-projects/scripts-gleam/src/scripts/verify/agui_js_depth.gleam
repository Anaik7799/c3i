//// scripts/verify/agui_js_depth — SC-AGUI-UI-WIRING-DEPTH validator.
////
//// Fetches /static/agui-chrome.js once and asserts that 5 specific wiring
//// signatures are present. Each signature corresponds to functional JS code
//// that backs an HTML-detectable component check in agui_conformance.
////
//// Anti-Stub-That-Lies per [zk-bd82645aedcb5ef4]: catches the failure class
//// where someone adds `class="gemma chat-widget"` without an actual handler.
//// agui_conformance.gleam alone can't detect that — this validator can.
////
//// Signatures (component → JS evidence required):
////   UI-002 fractal-filter   → `applyFractalFilter` function name
////   UI-003 ai-search        → `ai-search-input` selector binding
////   UI-004 drill-down       → `agui-detail-body` DOM id reference
////   UI-005 gemma-chat       → `/api/v1/ai/chat` fetch URL + `agui-chat-input`
////   meta                    → `data-agui-wired` body marker
////
//// Exit 0 if all signatures present, 1 if any missing.

import argv
import gleam/erlang/charlist
import gleam/io
import gleam/list
import gleam/string

const default_url: String = "http://vm-1.tail55d152.ts.net:4100/static/agui-chrome.js"

const signatures: List(#(String, String)) = [
  #("UI-002 fractal-filter handler", "applyFractalFilter"),
  #("UI-002 fractal-layer auto-classifier", "classifyLayer"),
  #("UI-003 ai-search binding", "ai-search-input"),
  #("UI-004 drill-down DOM target", "agui-detail-body"),
  #("UI-005 gemma chat fetch URL", "/api/v1/ai/chat"),
  #("UI-005 gemma chat input id", "agui-chat-input"),
  #("UI-007 change-log feed populator", "appendFeed"),
  #("meta wired-body marker", "data-agui-wired"),
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
  let url = case argv.load().arguments {
    [u, ..] -> u
    [] -> default_url
  }
  io.println("══ SC-AGUI-UI-WIRING-DEPTH (JS signatures) ══")
  io.println("source: " <> url)
  let #(out, _rc) =
    sh(cl("curl"), [cl("-s"), cl("--max-time"), cl("5"), cl(url)])
  let body = charlist.to_string(out)
  let results =
    list.map(signatures, fn(sig) {
      let #(label, needle) = sig
      #(label, needle, string.contains(body, needle))
    })
  list.each(results, fn(r) {
    let #(label, needle, ok) = r
    let mark = case ok {
      True -> "✓"
      False -> "✗"
    }
    io.println("  " <> mark <> " " <> label <> "  (" <> needle <> ")")
  })
  let missing = list.filter(results, fn(r) { !r.2 })
  case list.length(missing) {
    0 -> io.println("\n✓ all JS wiring signatures present — UI is not Stub-That-Lies")
    n -> {
      io.println(
        "\n✗ P0 — "
        <> "missing "
        <> case n {
          1 -> "1 signature"
          _ -> "multiple signatures"
        }
        <> " (hint: --priority P0 sa-plan task)",
      )
      panic as "SC-AGUI-UI-WIRING-DEPTH: missing signatures"
    }
  }
}
