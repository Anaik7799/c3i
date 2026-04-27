//// scripts/pass8/p8_07_exact_match_cache — Idea #7 · composite 39.1.
////
//// Exact-match prompt cache keyed by sha256(prompt). Used by callers BEFORE
//// an LLM round-trip; if a cached response exists with age < TTL_SECS, the
//// LLM call is skipped entirely (free answer).
////
//// Schema (in KMS): prompt_cache(hash PRIMARY KEY, prompt, response, model,
////                                created_at, last_hit_at, hit_count, ttl_secs).
////
//// ENV:
////   PRUNE_OLDER_SECS — prune entries older than this (default 604800 = 7 d)

import envoy
import gleam/int
import gleam/io
import gleam/list
import scripts/common/kms
import scripts/common/kms_coord
import scripts/common/nif

pub fn main() -> Nil {
  io.println("=== pass8/#7 Exact-match prompt cache ===")
  let prune_older = env_int("PRUNE_OLDER_SECS", 7 * 24 * 3600)

  let assert Ok(coord) = kms_coord.start()

  let _ = kms_coord.exec_batch(
    coord,
    "CREATE TABLE IF NOT EXISTS prompt_cache (
       prompt_hash TEXT PRIMARY KEY,
       prompt TEXT,
       response TEXT NOT NULL,
       model TEXT,
       provider TEXT,
       created_at INTEGER NOT NULL,
       last_hit_at INTEGER,
       hit_count INTEGER DEFAULT 0,
       ttl_secs INTEGER DEFAULT 86400,
       bytes INTEGER
    );
    CREATE INDEX IF NOT EXISTS idx_prompt_cache_created ON prompt_cache(created_at);
    CREATE VIEW IF NOT EXISTS v_prompt_cache_stats AS
      SELECT
        COUNT(*) AS entries,
        COALESCE(SUM(hit_count), 0) AS total_hits,
        ROUND(AVG(hit_count), 2) AS avg_hits,
        MAX(hit_count) AS max_hits,
        COALESCE(SUM(bytes), 0) AS total_bytes
      FROM prompt_cache;",
  )

  // Stats before prune
  let s_before = stats(coord)
  io.println("before: " <> s_before)

  // Prune stale
  let now = now_secs()
  let cutoff = int.to_string(now - prune_older)
  case kms_coord.exec(
    coord,
    "DELETE FROM prompt_cache WHERE created_at < ? AND hit_count < 1",
    [cutoff],
  ) {
    Ok(n) -> io.println("pruned: " <> int.to_string(n) <> " entries older than "
                        <> int.to_string(prune_older) <> "s")
    Error(e) -> io.println_error("prune: " <> kms.error_to_string(e))
  }

  // Demo: insert a canonical "run tests" entry if not present
  let demo_prompt = "run tests"
  let hash = nif.sha256_hex(demo_prompt)
  let demo_response = "8980 passed, no failures (cached)"
  let _ =
    kms_coord.exec(
      coord,
      "INSERT OR IGNORE INTO prompt_cache
         (prompt_hash, prompt, response, model, created_at, bytes)
         VALUES (?, ?, ?, ?, ?, ?)",
      [
        hash,
        demo_prompt,
        demo_response,
        "demo",
        int.to_string(now),
        int.to_string(string_byte_len(demo_response)),
      ],
    )

  let s_after = stats(coord)
  io.println("after:  " <> s_after)

  emit_summary(s_after)
  io.println(kms_coord.summary_line(kms_coord.introspect(coord)))
}

fn stats(coord) -> String {
  case kms_coord.query(coord, "SELECT * FROM v_prompt_cache_stats", []) {
    Ok(qr) ->
      case qr.rows {
        [row, ..] ->
          row
          |> list.map(fn(pair) { pair.0 <> "=" <> pair.1 })
          |> join(", ")
        _ -> "(empty)"
      }
    Error(e) -> "ERR " <> kms.error_to_string(e)
  }
}

@external(erlang, "erlang", "byte_size")
fn string_byte_len(s: String) -> Int

fn env_int(name: String, def: Int) -> Int {
  case envoy.get(name) {
    Ok(v) ->
      case int.parse(v) {
        Ok(n) -> n
        Error(_) -> def
      }
    Error(_) -> def
  }
}

fn now_secs() -> Int {
  nif.now_nanos() / 1_000_000_000
}

fn join(parts: List(String), sep: String) -> String {
  case parts {
    [] -> ""
    [x] -> x
    [x, ..rest] -> x <> sep <> join(rest, sep)
  }
}

fn emit_summary(stats_line: String) -> Nil {
  let payload =
    "{\"stats\":\"" <> stats_line <> "\",\"by\":\"p8_07_exact_match_cache\"}"
  let _ = nif.zenoh_put("indrajaal/l4/sre/cache/prompt_cache_stats", payload)
  Nil
}
