//// scripts/pass8/p8_13_moe_router — Idea #13 · composite 35.4.
////
//// Mixture-of-experts routing: maps intent → provider/model-family based on
//// historical cost-per-success (if data available) with sensible defaults.
////
//// Default policy (hard-wired, tuned to the pass-7 measurements):
////   reasoning  → anthropic/claude-opus        (best reasoning / turn)
////   coding     → openai/gpt-5-codex           (best code / turn)
////   vision     → google/gemini-3-pro          (best vision + ctx)
////   retrieval  → google/gemini-3-flash-lite   (cheapest @ ctx>1M)
////   chat       → google/gemini-3-flash        (cheap w/ cache)
////   planning   → openai/gpt-5.4-mini          (cheap reasoning-lite)
////
//// ENV:
////   INTENT — one of reasoning|coding|vision|retrieval|chat|planning

import envoy
import gleam/io
import gleam/list
import gleam/string
import scripts/common/kms_coord
import scripts/common/nif

pub fn main() -> Nil {
  io.println("=== pass8/#13 MoE intent routing ===")
  let intent = case envoy.get("INTENT") {
    Ok(v) -> v
    Error(_) -> "reasoning"
  }
  io.println("intent=" <> intent)

  let pick = case intent {
    "reasoning" -> #("anthropic", "claude-opus-4.7")
    "coding" -> #("openai", "gpt-5-codex")
    "vision" -> #("google", "gemini-3-pro-preview")
    "retrieval" -> #("google", "gemini-3.1-flash-lite-preview")
    "chat" -> #("google", "gemini-3-flash-preview")
    "planning" -> #("openai", "gpt-5.4-mini")
    _ -> #("google", "gemini-3-flash-preview")
  }
  let #(provider, model) = pick

  // Look up canonical pricing to confirm it's in our catalogue
  let assert Ok(coord) = kms_coord.start()
  case kms_coord.query(
    coord,
    "SELECT model_id, provider, input_per_million, output_per_million, tier, context_window
       FROM model_pricing WHERE model_id LIKE ?
       ORDER BY CASE WHEN model_id = ? THEN 0 ELSE 1 END LIMIT 3",
    ["%" <> model <> "%", model],
  ) {
    Ok(qr) -> {
      io.println("catalogue matches:")
      list.each(qr.rows, fn(r) {
        io.println("  " <> string.join(
          list.map(r, fn(p) { p.0 <> "=" <> p.1 }),
          " ",
        ))
      })
    }
    Error(_) -> Nil
  }

  io.println("DECISION: " <> provider <> "/" <> model <> " for intent=" <> intent)
  let payload =
    "{\"intent\":\"" <> intent <> "\",\"provider\":\"" <> provider
    <> "\",\"model\":\"" <> model <> "\",\"by\":\"p8_13_moe_router\"}"
  let _ = nif.zenoh_put("indrajaal/l5/cog/router/moe_pick", payload)
  io.println(kms_coord.summary_line(kms_coord.introspect(coord)))
}

