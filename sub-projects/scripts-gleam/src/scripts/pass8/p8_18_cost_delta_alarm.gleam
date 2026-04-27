//// scripts/pass8/p8_18_cost_delta_alarm — Idea #18 · composite 32.6.
////
//// Scans session_turn_spans for any single turn costing more than
//// THRESHOLD_USD (default $1.00) and publishes a high-priority alarm on
//// Zenoh so the Guardian layer can halt the session and prompt the operator.

import envoy
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import scripts/common/kms
import scripts/common/kms_coord
import scripts/common/nif

pub fn main() -> Nil {
  io.println("=== pass8/#18 Single-turn cost-delta alarm ===")
  let threshold = env_float("THRESHOLD_USD", 1.0)
  io.println("threshold=$" <> float.to_string(threshold))

  let assert Ok(coord) = kms_coord.start()

  case kms_coord.query(
    coord,
    "SELECT session_id, turn_index, model, provider, cost_usd, tokens_input + tokens_output AS tokens
       FROM session_turn_spans
      WHERE cost_usd > ?
      ORDER BY cost_usd DESC",
    [float.to_string(threshold)],
  ) {
    Ok(qr) -> {
      let breaches = list.length(qr.rows)
      io.println("breaches=" <> int.to_string(breaches))
      list.each(qr.rows, fn(r) {
        io.println("  ALARM: " <> row_summary(r))
        publish_alarm(r)
      })
    }
    Error(e) -> io.println_error("query: " <> kms.error_to_string(e))
  }
  io.println(kms_coord.summary_line(kms_coord.introspect(coord)))
}

fn row_summary(r: kms.Row) -> String {
  "sess=" <> col(r, "session_id")
    <> " turn=" <> col(r, "turn_index")
    <> " model=" <> col(r, "model")
    <> " cost=$" <> col(r, "cost_usd")
}

fn col(row: kms.Row, key: String) -> String {
  case list.find(row, fn(p) { p.0 == key }) {
    Ok(#(_, v)) -> v
    Error(_) -> ""
  }
}

fn publish_alarm(r: kms.Row) -> Nil {
  let payload =
    "{\"session_id\":\"" <> col(r, "session_id")
    <> "\",\"turn\":" <> col(r, "turn_index")
    <> ",\"model\":\"" <> col(r, "model")
    <> "\",\"provider\":\"" <> col(r, "provider")
    <> "\",\"cost_usd\":" <> col(r, "cost_usd")
    <> ",\"tokens\":" <> col(r, "tokens")
    <> ",\"rule\":\"SingleTurnCostBreach\",\"action\":\"HaltSession\","
    <> "\"by\":\"p8_18_cost_delta_alarm\"}"
  let _ = nif.zenoh_put("indrajaal/l4/sre/alarm/cost_delta", payload)
  Nil
}

fn env_float(name: String, def: Float) -> Float {
  case envoy.get(name) {
    Ok(v) ->
      case float.parse(v) {
        Ok(f) -> f
        Error(_) -> def
      }
    Error(_) -> def
  }
}
