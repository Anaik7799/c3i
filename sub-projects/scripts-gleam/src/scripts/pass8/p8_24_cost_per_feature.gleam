//// scripts/pass8/p8_24_cost_per_feature — Idea #24 · composite 30.6.
////
//// Rolls up session cost by feature-tag. Adds task_session_link table so
//// pi sessions can be attributed to sa-plan tasks → rollup by task →
//// rollup by parent task / feature area.

import gleam/int
import gleam/io
import gleam/list
import gleam/string
import scripts/common/kms
import scripts/common/kms_coord
import scripts/common/nif

pub fn main() -> Nil {
  io.println("=== pass8/#24 Cost-per-feature attribution ===")
  let assert Ok(coord) = kms_coord.start()

  let _ = kms_coord.exec(
    coord,
    "CREATE TABLE IF NOT EXISTS task_session_link (
       task_id TEXT NOT NULL,
       session_id TEXT NOT NULL,
       linked_at TEXT DEFAULT (datetime('now')),
       PRIMARY KEY (task_id, session_id)
    )",
    [],
  )
  let _ = kms_coord.exec(
    coord,
    "CREATE INDEX IF NOT EXISTS idx_tsl_task ON task_session_link(task_id)",
    [],
  )
  let _ = kms_coord.exec(
    coord,
    "CREATE INDEX IF NOT EXISTS idx_tsl_session ON task_session_link(session_id)",
    [],
  )
  let _ = kms_coord.exec(
    coord,
    "CREATE VIEW IF NOT EXISTS v_cost_by_task AS
      SELECT tsl.task_id,
             COUNT(DISTINCT sm.session_id) AS sessions,
             ROUND(SUM(sm.cost_usd), 4) AS cost_usd,
             SUM(sm.tokens_total) AS tokens,
             ROUND(AVG(sm.cache_hit_ratio), 3) AS avg_cache_hit
        FROM task_session_link tsl
        JOIN session_metrics sm ON sm.session_id = tsl.session_id
       GROUP BY tsl.task_id
       ORDER BY cost_usd DESC",
    [],
  )
  let _ = kms_coord.exec(
    coord,
    "CREATE VIEW IF NOT EXISTS v_unattributed_sessions AS
      SELECT sm.session_id, sm.model, sm.provider, sm.cost_usd
        FROM session_metrics sm
        LEFT JOIN task_session_link tsl ON sm.session_id = tsl.session_id
       WHERE tsl.task_id IS NULL AND sm.cost_usd > 0.0
       ORDER BY sm.cost_usd DESC",
    [],
  )

  // Stats
  let att = count_or_zero(coord, "task_session_link")
  let unatt = count_or_zero(coord, "v_unattributed_sessions")
  io.println("attributed=" <> int.to_string(att)
    <> " unattributed_sessions=" <> int.to_string(unatt))

  // Report unattributed cost
  case kms_coord.query(
    coord,
    "SELECT SUM(cost_usd) FROM v_unattributed_sessions",
    [],
  ) {
    Ok(qr) ->
      case qr.rows {
        [[#(_, v), ..], ..] ->
          io.println("unattributed cost = $" <> v)
        _ -> Nil
      }
    Error(_) -> Nil
  }

  let payload =
    "{\"attributed\":" <> int.to_string(att)
    <> ",\"unattributed_sessions\":" <> int.to_string(unatt)
    <> ",\"views\":[\"v_cost_by_task\",\"v_unattributed_sessions\"],"
    <> "\"by\":\"p8_24_cost_per_feature\"}"
  let _ = nif.zenoh_put("indrajaal/l4/sre/obs/cost_attribution", payload)
  io.println(kms_coord.summary_line(kms_coord.introspect(coord)))
}

fn count_or_zero(coord, name: String) -> Int {
  case kms_coord.query(coord, "SELECT COUNT(*) FROM " <> name, []) {
    Ok(qr) ->
      case qr.rows {
        [[#(_, v), ..], ..] ->
          case int.parse(v) {
            Ok(n) -> n
            Error(_) -> 0
          }
        _ -> 0
      }
    Error(_) -> 0
  }
}
