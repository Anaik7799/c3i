//// scripts/pass8/p8_19_per_turn_spans — Idea #19 · composite 32.9.
////
//// Installs session_turn_spans table to capture one row per LLM turn
//// (not per session) so we can correlate which exact prompt caused which
//// cost. Used by Pi extension's after_provider_response hook.

import gleam/int
import gleam/io
import gleam/list
import scripts/common/kms
import scripts/common/kms_coord
import scripts/common/nif

pub fn main() -> Nil {
  io.println("=== pass8/#19 Per-turn span table ===")
  let assert Ok(coord) = kms_coord.start()

  let _ = kms_coord.exec_batch(
    coord,
    "CREATE TABLE IF NOT EXISTS session_turn_spans (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       session_id TEXT NOT NULL,
       turn_index INTEGER NOT NULL,
       started_at TEXT NOT NULL,
       ended_at TEXT,
       model TEXT,
       provider TEXT,
       tokens_input INTEGER DEFAULT 0,
       tokens_output INTEGER DEFAULT 0,
       tokens_cache_read INTEGER DEFAULT 0,
       tokens_cache_write INTEGER DEFAULT 0,
       cost_usd REAL DEFAULT 0.0,
       prompt_sha256 TEXT,
       prompt_prefix TEXT,
       response_bytes INTEGER,
       tool_calls INTEGER DEFAULT 0,
       zk_citations INTEGER DEFAULT 0,
       rag_injected INTEGER DEFAULT 0,
       stage_latency_ms INTEGER
    );
    CREATE INDEX IF NOT EXISTS idx_turn_spans_session
      ON session_turn_spans(session_id, turn_index);
    CREATE INDEX IF NOT EXISTS idx_turn_spans_cost
      ON session_turn_spans(cost_usd DESC);
    CREATE VIEW IF NOT EXISTS v_top_cost_turns AS
      SELECT session_id, turn_index, model, provider,
             ROUND(cost_usd,4) AS cost_usd,
             tokens_input + tokens_output AS tokens_total,
             prompt_prefix
        FROM session_turn_spans
        ORDER BY cost_usd DESC
        LIMIT 50;",
  )

  // Seed: insert a demo row per recent pi_session showing the schema in action
  case kms_coord.query(
    coord,
    "SELECT pi_session_id, model, cost_usd, tokens_total FROM pi_sessions
       ORDER BY started_at DESC LIMIT 3",
    [],
  ) {
    Ok(qr) -> {
      io.println("seeding demo turn rows for " <> int.to_string(list.length(qr.rows)) <> " recent sessions")
      list.each(qr.rows, fn(r) {
        let sid = col(r, "pi_session_id")
        let model = col(r, "model")
        let _ = kms_coord.exec(
          coord,
          "INSERT INTO session_turn_spans
             (session_id, turn_index, started_at, model, provider, cost_usd, prompt_prefix)
             VALUES (?, 0, datetime('now'), ?, '', 0, 'demo_seed')",
          [sid, model],
        )
        Nil
      })
    }
    Error(e) -> io.println_error("seed: " <> kms.error_to_string(e))
  }

  // Report
  case kms_coord.query(coord, "SELECT COUNT(*) FROM session_turn_spans", []) {
    Ok(qr) ->
      case qr.rows {
        [[#(_, v), ..], ..] ->
          io.println("session_turn_spans rows=" <> v)
        _ -> Nil
      }
    Error(_) -> Nil
  }

  let payload =
    "{\"schema\":\"session_turn_spans\",\"views\":[\"v_top_cost_turns\"],"
    <> "\"by\":\"p8_19_per_turn_spans\"}"
  let _ = nif.zenoh_put("indrajaal/l4/sre/obs/turn_spans_installed", payload)
  io.println(kms_coord.summary_line(kms_coord.introspect(coord)))
}

fn col(row: kms.Row, key: String) -> String {
  case list.find(row, fn(p) { p.0 == key }) {
    Ok(#(_, v)) -> v
    Error(_) -> ""
  }
}
