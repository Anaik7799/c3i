//// scripts/pass8/p8_15_skill_scope_prompts — Idea #15 · composite 33.3.
////
//// Today Pi loads every tool schema (44 tools × ~300 tokens = ~13k tokens)
//// into the system prompt on every turn. Skill-scoping restricts tools to
//// the subset needed for the current intent, typically cutting 4k+ tokens
//// from the prompt prefix.
////
//// This module produces a JSON catalogue of "tool bundles per intent" that
//// the Pi extension can read at session_start and wire into its dynamic
//// toolset.
////
//// ENV:
////   INTENT — planning|coding|reasoning|retrieval|chat|vision (default coding)

import envoy
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import scripts/common/nif

pub fn main() -> Nil {
  io.println("=== pass8/#15 Skill-scoped prompt bundles ===")
  let intent = case envoy.get("INTENT") {
    Ok(v) -> v
    Error(_) -> "coding"
  }
  let bundle = tools_for(intent)
  let bundle_count = list.length(bundle)
  io.println("intent=" <> intent <> " bundle_size=" <> int.to_string(bundle_count))
  io.println("tools:")
  list.each(bundle, fn(t) { io.println("  " <> t) })

  // Estimate savings:
  //   full toolset ~= 44 tools × 300 tokens ≈ 13200 tokens
  //   scoped ~= bundle_count × 300 tokens
  //   saved = (44 - bundle_count) × 300
  let savings = { 44 - bundle_count } * 300
  io.println("estimated tokens saved per turn = " <> int.to_string(savings))

  let payload =
    "{\"intent\":\"" <> intent <> "\",\"tools\":["
    <> { bundle |> list.map(fn(s) { "\"" <> s <> "\"" }) |> string.join(",") }
    <> "],\"tokens_saved_est\":" <> int.to_string(savings)
    <> ",\"by\":\"p8_15_skill_scope_prompts\"}"
  let _ = nif.zenoh_put("indrajaal/l5/cog/skill_scope/bundle", payload)
  Nil
}

/// Hand-tuned tool bundle per intent. Names match the 44 Pi tools in
/// `lib/cepaf_gleam/src/cepaf_gleam/bridge/pi_tools.gleam`.
fn tools_for(intent: String) -> List(String) {
  case intent {
    "planning" -> [
      "plan_status", "plan_list", "plan_search", "plan_add", "plan_update",
      "knowledge_search",
    ]
    "coding" -> [
      "bash", "edit", "read", "write", "grep", "find", "ls",
      "gleam_build", "gleam_test", "gleam_format_check",
      "knowledge_search",
    ]
    "reasoning" -> [
      "knowledge_search", "plan_status", "sil6_checklist",
      "graph_analyze", "muda_check", "pre_commit_audit",
    ]
    "retrieval" -> ["knowledge_search", "knowledge_ingest", "read", "grep", "find"]
    "chat" -> ["knowledge_search", "plan_status", "read"]
    "vision" -> ["render_diagrams", "read", "page_dom_check", "knowledge_search"]
    _ -> [
      "plan_status", "knowledge_search", "system_health",
      "system_dashboard", "bash", "read",
    ]
  }
}
