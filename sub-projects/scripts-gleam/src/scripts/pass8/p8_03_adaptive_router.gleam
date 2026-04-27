//// scripts/pass8/p8_03_adaptive_router — Idea #3 · composite 49.6.
////
//// Picks the cheapest capable model given:
////   * task tier (planning | reasoning | coding | retrieval | chat)
////   * minimum context window required
////   * whether vision is needed
////   * whether the session's avg cache-hit ratio warrants a cache-supporting model
////
//// The decision is published to Zenoh as
//// indrajaal/l5/cog/router/pick so Pi/Claude hooks can read it and switch
//// provider mid-session.

import envoy
import gleam/erlang/atom
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import scripts/common/kms
import scripts/common/kms_coord
import scripts/common/nif

pub fn main() -> Nil {
  io.println("=== pass8/#3 Adaptive model router ===")
  let tier = case envoy.get("TIER") {
    Ok(t) -> t
    Error(_) -> "standard"
  }
  let ctx_min = env_int("CTX_MIN", 128_000)
  let vision = env_int("VISION", 0)
  let cache_required = env_int("CACHE_REQUIRED", 1)
  io.println("tier=" <> tier <> " ctx_min=" <> int.to_string(ctx_min)
    <> " vision=" <> int.to_string(vision)
    <> " cache_required=" <> int.to_string(cache_required))

  let assert Ok(coord) = kms_coord.start()

  let sql =
    "SELECT model_id, provider, input_per_million, output_per_million,
            context_window, supports_cache, supports_vision, tier
       FROM model_pricing
      WHERE tier = ?
        AND context_window >= ?
        AND supports_vision >= ?
        AND supports_cache >= ?
      ORDER BY input_per_million, output_per_million
      LIMIT 5"
  case
    kms_coord.query(coord, sql, [
      tier,
      int.to_string(ctx_min),
      int.to_string(vision),
      int.to_string(cache_required),
    ])
  {
    Error(e) -> io.println_error("query: " <> kms.error_to_string(e))
    Ok(qr) -> {
      case qr.rows {
        [] -> io.println("no matching models")
        [first, ..rest] -> {
          io.println("top-5 candidates:")
          list.each([first, ..rest], fn(r) { io.println("  " <> r_to_s(r)) })

          // Decision = cheapest (first row)
          let model_id = col(first, "model_id")
          let provider = col(first, "provider")
          let input_p = col(first, "input_per_million")
          let output_p = col(first, "output_per_million")
          io.println(
            "DECISION: " <> provider <> "/" <> model_id
            <> " (in=$" <> input_p <> "/Mt  out=$" <> output_p <> "/Mt)",
          )
          publish_decision(tier, provider, model_id, input_p, output_p)
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

fn r_to_s(row: kms.Row) -> String {
  row
  |> list.map(fn(p) { p.0 <> "=" <> p.1 })
  |> string.join(" ")
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

fn publish_decision(
  tier: String,
  provider: String,
  model: String,
  in_p: String,
  out_p: String,
) -> Nil {
  let payload =
    "{\"tier\":\"" <> tier <> "\",\"provider\":\"" <> provider
    <> "\",\"model\":\"" <> model
    <> "\",\"input_per_million\":" <> in_p
    <> ",\"output_per_million\":" <> out_p
    <> ",\"by\":\"p8_03_adaptive_router\"}"
  let _ = nif.zenoh_put("indrajaal/l5/cog/router/pick", payload)
  Nil
}
