//// scripts/pass8/p8_22_auto_lifeline — Idea #22 · composite 31.6.
////
//// Detects stuck oban_jobs (state='executing' for longer than STUCK_SECS, default
//// 600) in Smriti.db and resets them to 'available' so the scheduler picks them
//// up. Publishes rescue counts on Zenoh.

import envoy
import gleam/erlang/atom
import gleam/int
import gleam/io
import gleam/string
import scripts/common/nif
import scripts/common/paths

pub fn main() -> Nil {
  io.println("=== pass8/#22 Auto-lifeline ===")
  let stuck_secs = case envoy.get("STUCK_SECS") {
    Ok(v) ->
      case int.parse(v) {
        Ok(n) -> n
        Error(_) -> 600
      }
    Error(_) -> 600
  }
  io.println("stuck_threshold_secs=" <> int.to_string(stuck_secs))

  let smriti =
    paths.repo_root() <> "/sub-projects/c3i/data/smriti/Smriti.db"

  let query_sql =
    "SELECT id FROM oban_jobs WHERE state='executing'
       AND (strftime('%s','now') - strftime('%s',attempted_at)) > "
    <> int.to_string(stuck_secs)

  let #(q_tag, payload) = nif.smriti_query(smriti, query_sql, [])
  case atom.to_string(q_tag) {
    "ok" -> {
      let stuck_count = count_row_entries(payload)
      io.println("stuck_jobs=" <> int.to_string(stuck_count))
      case stuck_count > 0 {
        True -> {
          let reset_sql =
            "UPDATE oban_jobs SET state='available',
               attempt=COALESCE(attempt,0)+1
             WHERE state='executing'
               AND (strftime('%s','now') - strftime('%s',attempted_at)) > "
            <> int.to_string(stuck_secs)
          let #(r_tag, r_payload) = nif.smriti_exec(smriti, reset_sql, [])
          io.println(
            "reset: " <> atom.to_string(r_tag) <> " rows=" <> r_payload,
          )
          emit_rescue(stuck_count)
        }
        False -> io.println("no stuck jobs — lifeline quiescent")
      }
    }
    other -> io.println_error("query " <> other <> ": " <> payload)
  }
}

/// Rough row count from the NIF's JSON payload without a full decoder.
fn count_row_entries(body: String) -> Int {
  case string.contains(body, "\"rows\":[]") {
    True -> 0
    False -> {
      // Each row looks like [...,...], commas between entries.
      // Simple split on "],[" approximates the count for non-nested rows.
      let parts = string.split(body, "],[")
      case parts {
        [] -> 0
        _ -> list_length(parts)
      }
    }
  }
}

@external(erlang, "erlang", "length")
fn list_length(l: List(a)) -> Int

fn emit_rescue(n: Int) -> Nil {
  let _ =
    nif.zenoh_put(
      "indrajaal/l4/sre/lifeline/rescued",
      "{\"count\":" <> int.to_string(n) <> ",\"by\":\"pass8_auto_lifeline\"}",
    )
  Nil
}
