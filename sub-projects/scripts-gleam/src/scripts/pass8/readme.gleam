//// scripts/pass8/readme — manifest + index for the 18 pass-8 improvements.
////
//// STAMP: SC-PASS8-IMPL-001
//// Parent task: 116452825849720856
////
//// Every module under `scripts/pass8/` implements ONE of the 18 top-scored
//// ideas from the pass-7 44-idea matrix. Each module ships as a runnable:
////
////     cd sub-projects/scripts-gleam
////     gleam run -m scripts/pass8/<name>
////
//// Topology (per SPRINT):
////   Sprint 1 — Prefix cache + Budget + SRE
////     p8_01_prefix_cache_warmer     — #1  composite 54.6
////     p8_06_budget_middleware       — #6  composite 42.7
////     p8_22_auto_lifeline           — #22 composite 31.6
////
////   Sprint 2 — RAG substrate
////     p8_04_embed_backfill          — #4  composite 45.5
////     p8_05_bge_rerank              — #5  composite 45.2
////     p8_17_edge_growth             — #17 composite 33.6
////
////   Sprint 3 — Cache layers
////     p8_02_semantic_cache_fuzzy    — #2  composite 52.6
////     p8_07_exact_match_cache       — #7  composite 39.1
////     p8_10_shared_cache            — #10 composite 37.7
////
////   Sprint 4 — Routing
////     p8_03_adaptive_router         — #3  composite 49.6
////     p8_14_ctx_aware_router        — #14 composite 34.4
////     p8_13_moe_router              — #13 composite 35.4
////
////   Sprint 5 — Compression
////     p8_11_llmlingua_compress      — #11 composite 36.4
////     p8_16_old_msg_summarise       — #16 composite 33.3
////     p8_15_skill_scope_prompts     — #15 composite 33.3
////
////   Sprint 6 — Observability closure
////     p8_19_per_turn_spans          — #19 composite 32.9
////     p8_18_cost_delta_alarm        — #18 composite 32.6
////     p8_24_cost_per_feature        — #24 composite 30.6

import gleam/io

pub fn main() -> Nil {
  io.println(
    "pass8 — 18 improvements from the 44-idea ultrathink matrix.\n"
    <> "Run each via `gleam run -m scripts/pass8/<name>`.\n"
    <> "Composite rank order: 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,22,24.",
  )
}
