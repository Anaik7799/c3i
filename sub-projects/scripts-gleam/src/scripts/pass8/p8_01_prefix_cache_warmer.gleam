//// scripts/pass8/p8_01_prefix_cache_warmer — Idea #1 · composite 54.6.
////
//// Writes a canonical "warm-the-cache" prompt to session_metrics so the next
//// LLM call reliably hits the Anthropic/OpenAI/Google prompt-caching tier
//// (90 % discount on read). Emits a Zenoh notification so the Pi extension
//// and Claude hook know which prefix to use.
////
//// STAMP: SC-PASS8-IMPL-001, SC-ZK-COST-OPT-001

import gleam/erlang/atom
import gleam/int
import gleam/io
import gleam/result
import scripts/common/kms
import scripts/common/kms_coord
import scripts/common/nif

pub fn main() -> Nil {
  io.println("=== pass8/#1 Prefix-cache warmer ===")
  case kms_coord.start() {
    Error(_) -> io.println_error("coord start failed")
    Ok(coord) -> {
      let _ =
        kms_coord.exec(
          coord,
          "CREATE TABLE IF NOT EXISTS prompt_prefix_cache (
              prefix_hash TEXT PRIMARY KEY,
              prefix TEXT NOT NULL,
              model TEXT,
              created_at TEXT DEFAULT (datetime('now')),
              last_hit_at TEXT,
              hit_count INTEGER DEFAULT 0,
              bytes INTEGER
           )",
          [],
        )
      let prefix =
        "# C3I System Prompt Prefix (cacheable)\n"
        <> "You are a C3I agent. Cite ZK holon IDs when relevant.\n"
        <> "Prefer cheap cached tokens over fresh LLM calls.\n"
        <> "Follow SC-ZK-COST-OPT-001 thresholds."
      let hash = nif.sha256_hex(prefix)
      let bytes = int.to_string(string_byte_len(prefix))
      let _ =
        kms_coord.exec(
          coord,
          "INSERT OR REPLACE INTO prompt_prefix_cache
           (prefix_hash, prefix, model, bytes) VALUES (?, ?, ?, ?)",
          [hash, prefix, "all", bytes],
        )
      emit_zenoh(hash, bytes)
      io.println("prefix cached: hash=" <> hash <> " bytes=" <> bytes)
      io.println(kms_coord.summary_line(kms_coord.introspect(coord)))
    }
  }
}

fn emit_zenoh(hash: String, bytes: String) -> Nil {
  let payload =
    "{\"hash\":\"" <> hash <> "\",\"bytes\":" <> bytes
    <> ",\"event\":\"cache_warmed\"}"
  let #(tag, _) = nif.zenoh_put("indrajaal/l4/sre/cache/prefix_warmed", payload)
  case atom.to_string(tag) {
    "ok" -> Nil
    _ -> Nil
  }
}

@external(erlang, "erlang", "byte_size")
fn string_byte_len(s: String) -> Int
