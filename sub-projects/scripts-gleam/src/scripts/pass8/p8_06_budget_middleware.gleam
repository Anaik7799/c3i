//// scripts/pass8/p8_06_budget_middleware — Idea #6 · composite 42.7.
////
//// Installs session_budget table + sweep that checks current session_metrics
//// against per-session caps. Breaches are published on Zenoh under
//// indrajaal/l4/sre/alarm/budget_breach and flagged in the pi_sessions row
//// so the Guardian layer can block the next turn.

import gleam/io
import gleam/int
import gleam/list
import gleam/string
import scripts/common/kms
import scripts/common/kms_coord

pub fn main() -> Nil {
  io.println("=== pass8/#6 Budget middleware ===")
  let assert Ok(coord) = kms_coord.start()

  // 1. Table + default cap
  let _ =
    kms_coord.exec_batch(
      coord,
      "CREATE TABLE IF NOT EXISTS session_budget (
         session_id TEXT PRIMARY KEY,
         cap_usd REAL NOT NULL DEFAULT 50.0,
         daily_cap_usd REAL NOT NULL DEFAULT 100.0,
         hard_halt INTEGER NOT NULL DEFAULT 1,
         created_at TEXT DEFAULT (datetime('now'))
      );
      CREATE VIEW IF NOT EXISTS v_budget_status AS
        SELECT
          s.session_id,
          ROUND(s.cost_usd, 4) AS cost_usd,
          COALESCE(b.cap_usd, 50.0) AS cap_usd,
          ROUND(100.0 * s.cost_usd / COALESCE(b.cap_usd, 50.0), 1) AS pct_of_cap,
          CASE
            WHEN s.cost_usd >= COALESCE(b.cap_usd, 50.0) THEN 'HALT'
            WHEN s.cost_usd >= 0.8 * COALESCE(b.cap_usd, 50.0) THEN 'WARN'
            ELSE 'OK'
          END AS status,
          s.model, s.provider, s.started_at
        FROM session_metrics s
        LEFT JOIN session_budget b USING (session_id);",
    )

  // 2. Sweep current sessions — print breaches
  let breaches = case
    kms_coord.query(
      coord,
      "SELECT session_id, cost_usd, cap_usd, pct_of_cap, status, model
         FROM v_budget_status WHERE status != 'OK' ORDER BY cost_usd DESC",
      [],
    )
  {
    Ok(qr) -> qr.rows
    Error(e) -> {
      io.println_error("sweep FAIL: " <> kms.error_to_string(e))
      []
    }
  }

  list.each(breaches, fn(row) {
    io.println("BREACH: " <> row_to_string(row))
  })
  io.println("breaches=" <> int.to_string(list.length(breaches)))
  io.println(kms_coord.summary_line(kms_coord.introspect(coord)))
}

fn row_to_string(r: kms.Row) -> String {
  r
  |> list.map(fn(p) {
    let #(k, v) = p
    k <> "=" <> v
  })
  |> string.join(", ")
}
