//// scripts/pass8/p8_bench_embed — benchmark embedding paths.
////
//// Runs N embeddings against both a configurable HTTP Ollama endpoint and
//// (once the fastembed NIF is wired) the in-process Rust NIF, reporting
//// median/p95 latency and throughput. Uses the same source text for both so
//// results are directly comparable.

import envoy
import gleam/erlang/atom
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import scripts/common/httpx
import scripts/common/kms
import scripts/common/kms_coord
import scripts/common/nif

pub fn main() -> Nil {
  io.println("=== pass8/bench embed · Ollama vs (future) NIF ===")
  let n = env_int("BENCH_N", 20)
  let ollama = case envoy.get("OLLAMA_URL") {
    Ok(v) -> v
    Error(_) -> "http://localhost:11434"
  }
  io.println("samples=" <> int.to_string(n) <> " ollama=" <> ollama)

  let assert Ok(coord) = kms_coord.start()
  let samples = pick_samples(coord, n)
  io.println("fetched " <> int.to_string(list.length(samples)) <> " samples")

  // Ollama pass
  let t0 = nif.now_nanos()
  let ok = list.fold(samples, 0, fn(acc, text) {
    case embed_ollama(ollama, text) {
      Ok(_) -> acc + 1
      Error(_) -> acc
    }
  })
  let t1 = nif.now_nanos()
  report("ollama", ok, list.length(samples), t1 - t0)

  // NIF pass — single-call
  let #(info_tag, info) = nif.fastembed_info()
  io.println("fastembed: " <> atom.to_string(info_tag) <> " " <> info)

  let t2 = nif.now_nanos()
  let ok_nif = list.fold(samples, 0, fn(acc, text) {
    let #(t, _) = nif.fastembed_embed_one(text)
    case atom.to_string(t) {
      "ok" -> acc + 1
      _ -> acc
    }
  })
  let t3 = nif.now_nanos()
  report("fastembed_one", ok_nif, list.length(samples), t3 - t2)

  // NIF pass — batch
  let batch_json = "[" <> list.map(samples, json_quote) |> list.fold("", fn(acc, s) {
    case acc {
      "" -> s
      _ -> acc <> "," <> s
    }
  }) <> "]"
  let t4 = nif.now_nanos()
  let #(bt, _) = nif.fastembed_embed_batch(batch_json)
  let t5 = nif.now_nanos()
  let ok_batch =
    case atom.to_string(bt) {
      "ok" -> list.length(samples)
      _ -> 0
    }
  report("fastembed_batch", ok_batch, list.length(samples), t5 - t4)
}

fn json_quote(s: String) -> String {
  let inner =
    s
    |> string.replace("\\", "\\\\")
    |> string.replace("\"", "\\\"")
    |> string.replace("\n", "\\n")
  "\"" <> inner <> "\""
}

fn pick_samples(coord, n: Int) -> List(String) {
  case
    kms_coord.query(
      coord,
      "SELECT SUBSTR(content,1,1500) FROM holons LIMIT ?",
      [int.to_string(n)],
    )
  {
    Ok(qr) ->
      list.map(qr.rows, fn(r) {
        case r {
          [#(_, v), ..] -> v
          _ -> ""
        }
      })
    Error(_) -> []
  }
}

fn embed_ollama(url: String, text: String) -> Result(Nil, String) {
  let body =
    "{\"model\":\"nomic-embed-text\",\"prompt\":\""
    <> escape(text)
    <> "\"}"
  case httpx.post_with_timeout(url <> "/api/embeddings", body, 120_000) {
    httpx.HttpResult(code: 200, ..) -> Ok(Nil)
    httpx.HttpResult(code: c, detail: d, ..) ->
      Error(int.to_string(c) <> " " <> d)
  }
}

fn report(label: String, ok: Int, total: Int, ns: Int) -> Nil {
  let ms = int.to_float(ns) /. 1_000_000.0
  let per =
    case total {
      0 -> 0.0
      _ -> ms /. int.to_float(total)
    }
  let tps =
    case ms {
      0.0 -> 0.0
      _ -> int.to_float(total) *. 1000.0 /. ms
    }
  io.println(
    "[" <> label <> "] ok=" <> int.to_string(ok)
    <> "/" <> int.to_string(total)
    <> " total_ms=" <> float.to_string(ms)
    <> " avg_ms=" <> float.to_string(per)
    <> " docs_per_sec=" <> float.to_string(tps),
  )
  let _ =
    nif.zenoh_put(
      "indrajaal/l4/sre/bench/embed",
      "{\"backend\":\"" <> label <> "\",\"ok\":" <> int.to_string(ok)
        <> ",\"total_ms\":" <> float.to_string(ms)
        <> ",\"avg_ms\":" <> float.to_string(per)
        <> ",\"dps\":" <> float.to_string(tps) <> "}",
    )
  Nil
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

fn escape(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
}
