//// scripts/pass8/p8_14_ctx_aware_router — Idea #14 · composite 34.4.
////
//// Given a prompt + estimated response length, picks the cheapest model
//// whose context window fits (prompt + response + 20% safety margin).
////
//// ENV:
////   PROMPT_TOKENS   — estimated prompt size (default 32000)
////   RESPONSE_TOKENS — estimated response size (default 2000)

import envoy
import gleam/int
import gleam/io
import gleam/list
import scripts/common/kms
import scripts/common/kms_coord
import scripts/common/nif

pub fn main() -> Nil {
  io.println("=== pass8/#14 Context-window aware routing ===")
  let prompt_tok = env_int("PROMPT_TOKENS", 32_000)
  let resp_tok = env_int("RESPONSE_TOKENS", 2_000)
  let required = prompt_tok + resp_tok + prompt_tok / 5
  io.println(
    "prompt=" <> int.to_string(prompt_tok)
    <> " response=" <> int.to_string(resp_tok)
    <> " required_ctx=" <> int.to_string(required),
  )

  let assert Ok(coord) = kms_coord.start()
  let sql =
    "SELECT model_id, provider, input_per_million, output_per_million, context_window
       FROM model_pricing
      WHERE context_window >= ? AND supports_cache = 1
      ORDER BY input_per_million, context_window
      LIMIT 5"
  case kms_coord.query(coord, sql, [int.to_string(required)]) {
    Error(e) -> io.println_error("query: " <> kms.error_to_string(e))
    Ok(qr) -> {
      case qr.rows {
        [] -> io.println("no model large enough")
        [first, ..rest] -> {
          io.println("top candidates:")
          list.each([first, ..rest], fn(r) {
            io.println("  " <> col(r, "provider") <> "/" <> col(r, "model_id")
              <> "  ctx=" <> col(r, "context_window")
              <> "  in=$" <> col(r, "input_per_million") <> "/Mt")
          })
          let model = col(first, "model_id")
          let provider = col(first, "provider")
          io.println("DECISION: " <> provider <> "/" <> model)
          let payload =
            "{\"required_ctx\":" <> int.to_string(required)
            <> ",\"model\":\"" <> model <> "\",\"provider\":\"" <> provider
            <> "\",\"by\":\"p8_14_ctx_aware_router\"}"
          let _ = nif.zenoh_put("indrajaal/l5/cog/router/ctx_pick", payload)
          Nil
        }
      }
    }
  }
  io.println(kms_coord.summary_line(kms_coord.introspect(coord)))
}

fn col(row: kms.Row, key: String) -> String {
  case list.find(row, fn(p) { p.0 == key }) {
    Ok(#(_, v)) -> v
    Error(_) -> ""
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
