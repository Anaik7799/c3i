//// scripts/pass8/p8_10_shared_cache — Idea #10 · composite 37.7.
////
//// Shared cache across agents (Claude ↔ Pi ↔ Gemini). Both prompt_cache
//// (exact) and semantic_cache (fuzzy) already live in smriti.db which is
//// reachable from all agents via this NIF. This module installs a
//// cross-agent view and a published "cache catalogue" so any agent can
//// discover what's available without per-agent state.

import gleam/int
import gleam/io
import gleam/list
import scripts/common/kms
import scripts/common/kms_coord
import scripts/common/nif

pub fn main() -> Nil {
  io.println("=== pass8/#10 Shared cross-agent cache ===")

  let assert Ok(coord) = kms_coord.start()

  let _ = kms_coord.exec_batch(
    coord,
    "CREATE VIEW IF NOT EXISTS v_shared_cache_catalogue AS
       SELECT 'exact' AS kind, prompt_hash AS key, model, created_at,
              hit_count, bytes
         FROM prompt_cache
       UNION ALL
       SELECT 'semantic' AS kind, CAST(id AS TEXT) AS key, model, created_at,
              hit_count, bytes
         FROM semantic_cache;
    CREATE VIEW IF NOT EXISTS v_shared_cache_savings AS
      SELECT
        (SELECT COALESCE(SUM(hit_count), 0) FROM prompt_cache) AS exact_hits,
        (SELECT COALESCE(SUM(hit_count), 0) FROM semantic_cache) AS semantic_hits,
        (SELECT COALESCE(SUM(hit_count), 0) FROM prompt_cache)
          + (SELECT COALESCE(SUM(hit_count), 0) FROM semantic_cache) AS total_hits;",
  )

  // Dump catalogue head
  case kms_coord.query(
    coord,
    "SELECT kind, key, model, hit_count, bytes FROM v_shared_cache_catalogue ORDER BY created_at DESC LIMIT 10",
    [],
  ) {
    Ok(qr) -> {
      io.println("catalogue rows=" <> int.to_string(list.length(qr.rows)))
      list.each(qr.rows, fn(r) {
        io.println("  " <> r_to_s(r))
      })
    }
    Error(e) -> io.println_error("query: " <> kms.error_to_string(e))
  }

  // Savings snapshot
  case kms_coord.query(coord, "SELECT * FROM v_shared_cache_savings", []) {
    Ok(qr) -> {
      io.println("savings: " <> case qr.rows {
        [row, ..] -> r_to_s(row)
        _ -> "(empty)"
      })
    }
    Error(_) -> Nil
  }

  // Publish catalogue to Zenoh so every agent can subscribe
  let _ =
    nif.zenoh_put(
      "indrajaal/l4/sre/cache/shared_catalogue",
      "{\"announced_at\":" <> int.to_string(nif.now_nanos())
        <> ",\"views\":[\"v_shared_cache_catalogue\",\"v_shared_cache_savings\"],"
        <> "\"by\":\"p8_10_shared_cache\"}",
    )
  io.println(kms_coord.summary_line(kms_coord.introspect(coord)))
}

fn r_to_s(row: kms.Row) -> String {
  row
  |> list.map(fn(pair) { pair.0 <> "=" <> pair.1 })
  |> join(", ")
}

fn join(parts: List(String), sep: String) -> String {
  case parts {
    [] -> ""
    [x] -> x
    [x, ..rest] -> x <> sep <> join(rest, sep)
  }
}
