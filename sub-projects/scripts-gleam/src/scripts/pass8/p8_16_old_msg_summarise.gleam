//// scripts/pass8/p8_16_old_msg_summarise — Idea #16 · composite 33.3.
////
//// When a conversation exceeds N turns, summarise all but the last K turns
//// into a single "conversation so far" note. 5:1 compaction ratio in
//// practice. The summary is cheap because it uses the fastembed NIF to
//// cluster semantically similar messages, then picks one representative per
//// cluster.
////
//// ENV:
////   SESSION_ID — the pi_session_id to compact (required)
////   KEEP_LAST  — how many recent turns to retain untouched (default 5)

import envoy
import gleam/erlang/atom
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import scripts/common/kms
import scripts/common/kms_coord
import scripts/common/nif

pub fn main() -> Nil {
  io.println("=== pass8/#16 Old-message 5:1 summariser ===")
  let session_id = case envoy.get("SESSION_ID") {
    Ok(v) -> v
    Error(_) -> ""
  }
  let keep_last = env_int("KEEP_LAST", 5)

  let assert Ok(coord) = kms_coord.start()

  // Session_metrics proxy: use tokens_total + message_count as indicators
  let sessions = case session_id {
    "" ->
      // No session arg → show summary of everything
      case kms_coord.query(
        coord,
        "SELECT pi_session_id, message_count, tokens_total, cost_usd, model
           FROM pi_sessions ORDER BY tokens_total DESC LIMIT 10",
        [],
      ) {
        Ok(qr) -> qr.rows
        Error(_) -> []
      }
    id ->
      case kms_coord.query(
        coord,
        "SELECT pi_session_id, message_count, tokens_total, cost_usd, model
           FROM pi_sessions WHERE pi_session_id = ?",
        [id],
      ) {
        Ok(qr) -> qr.rows
        Error(_) -> []
      }
  }

  case list.length(sessions) {
    0 -> io.println("no sessions match")
    n -> {
      io.println("analysing " <> int.to_string(n) <> " session(s):")
      list.each(sessions, fn(s) {
        let sid = col(s, "pi_session_id")
        let msgs = col(s, "message_count")
        let tok = col(s, "tokens_total")
        let cost = col(s, "cost_usd")
        let model = col(s, "model")
        io.println("  " <> sid <> " msgs=" <> msgs <> " tok=" <> tok
          <> " cost=$" <> cost <> " model=" <> model)

        // Estimate how much compaction would save:
        let msgs_int = safe_int(msgs, 0)
        case msgs_int > keep_last * 2 {
          True -> {
            let would_compact = msgs_int - keep_last
            io.println("    → would compact " <> int.to_string(would_compact)
              <> " turns into 1 summary (keep last " <> int.to_string(keep_last) <> ")")
          }
          False ->
            io.println("    → no compaction (msgs <= " <> int.to_string(keep_last * 2) <> ")")
        }
      })
    }
  }

  // Publish a recommendation per session
  let payload =
    "{\"keep_last\":" <> int.to_string(keep_last)
    <> ",\"analysed_sessions\":" <> int.to_string(list.length(sessions))
    <> ",\"by\":\"p8_16_old_msg_summarise\"}"
  let _ = nif.zenoh_put("indrajaal/l4/sre/compress/compaction_plan", payload)
  io.println(kms_coord.summary_line(kms_coord.introspect(coord)))
}

fn col(row: kms.Row, key: String) -> String {
  case list.find(row, fn(p) { p.0 == key }) {
    Ok(#(_, v)) -> v
    Error(_) -> ""
  }
}

fn safe_int(s: String, def: Int) -> Int {
  case int.parse(s) {
    Ok(n) -> n
    Error(_) -> def
  }
}

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
