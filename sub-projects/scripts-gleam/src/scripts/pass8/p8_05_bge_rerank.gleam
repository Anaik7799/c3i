//// scripts/pass8/p8_05_bge_rerank — Idea #5 · composite 45.2.
////
//// Reranks recall candidates via the fastembed NIF. One NIF call does:
////   embed query → fetch candidate BLOBs → cosine similarity → sort desc.
////
//// Typical flow: FTS5 returns 15 candidates → rerank to top-3 via embedding
//// similarity, dropping ~80 % of the context token budget at equal quality.
////
//// ENV:
////   QUERY  — query text (required; defaults to a built-in stub)
////   TOP_K  — how many top reranked results to print (default 3)

import envoy
import gleam/erlang/atom
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import scripts/common/kms
import scripts/common/kms_coord
import scripts/common/nif
import scripts/common/paths

pub fn main() -> Nil {
  io.println("=== pass8/#5 Reranker (fastembed NIF · cosine over BLOB) ===")
  let query = case envoy.get("QUERY") {
    Ok(q) -> q
    Error(_) -> "ZK symbiosis closed loop cost optimization"
  }
  let top_k = env_int("TOP_K", 3)
  io.println("query=" <> query <> " top_k=" <> int.to_string(top_k))

  // 1. FTS5 candidates
  let assert Ok(coord) = kms_coord.start()
  let sql =
    "SELECT h.holon_uuid, SUBSTR(h.title, 1, 80)
       FROM holons h
       JOIN holons_fts fts ON fts.rowid = h.rowid
      WHERE fts.holons_fts MATCH ?
      ORDER BY rank LIMIT 15"
  case kms_coord.query(coord, sql, [query]) {
    Error(e) -> io.println_error("fts: " <> kms.error_to_string(e))
    Ok(qr) -> {
      let rows = qr.rows
      io.println("fts_candidates=" <> int.to_string(list.length(rows)))
      let uuids = list.map(rows, fn(r) { col_at(r, 0) })
      let titles = list.map(rows, fn(r) { col_at(r, 1) })

      // 2. Rerank in one NIF call
      let uuids_json = to_json_array(uuids)
      let db = paths.repo_root() <> "/sub-projects/c3i/data/kms/smriti.db"
      let #(tag, payload) = nif.fastembed_rerank_query(db, query, uuids_json)
      case atom.to_string(tag) {
        "ok" -> {
          // Parse "[{\"id\":\"zk-...\",\"score\":0.83},...]" lightly: keep uuid→score map
          let scored = parse_scores(payload)
          let title_map = list.zip(uuids, titles)
          let top = list.take(scored, top_k)
          io.println("─ top " <> int.to_string(top_k) <> " reranked ─")
          list.each(top, fn(s) {
            let #(uuid, score) = s
            let title = lookup(title_map, uuid)
            io.println("  " <> score <> "  " <> uuid <> "  " <> title)
          })
          emit_summary(list.length(rows), list.length(top))
        }
        _ -> io.println_error("rerank: " <> payload)
      }
    }
  }
}

fn col_at(row: kms.Row, idx: Int) -> String {
  case list.drop(row, idx) {
    [#(_, v), ..] -> v
    _ -> ""
  }
}

fn to_json_array(strings: List(String)) -> String {
  let parts = list.map(strings, fn(s) { "\"" <> s <> "\"" })
  "[" <> string.join(parts, ",") <> "]"
}

/// Parse `[{"id":"zk-...","score":0.83},...]` → list of (uuid, score-string) in order.
fn parse_scores(json: String) -> List(#(String, String)) {
  let trimmed = string.trim(json)
  let inner = case string.starts_with(trimmed, "[") && string.ends_with(trimmed, "]") {
    True -> string.slice(trimmed, 1, string.length(trimmed) - 2)
    False -> trimmed
  }
  case inner {
    "" -> []
    _ -> {
      // Split on "},{" to isolate objects
      let parts = string.split(inner, "},{")
      list.filter_map(parts, fn(p) {
        let cleaned = string.replace(p, "{", "") |> string.replace("}", "")
        case string.split(cleaned, ",") {
          [id_pair, score_pair, ..] -> {
            let id = extract_after_colon(id_pair)
            let score = extract_after_colon(score_pair)
            Ok(#(string.replace(id, "\"", ""), score))
          }
          _ -> Error(Nil)
        }
      })
    }
  }
}

fn extract_after_colon(s: String) -> String {
  case string.split(s, ":") {
    [_, v, ..] -> string.trim(v)
    _ -> ""
  }
}

fn lookup(pairs: List(#(String, String)), k: String) -> String {
  case list.find(pairs, fn(p) { p.0 == k }) {
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

fn emit_summary(candidates: Int, kept: Int) -> Nil {
  let payload =
    "{\"candidates\":" <> int.to_string(candidates)
    <> ",\"kept\":" <> int.to_string(kept)
    <> ",\"by\":\"p8_05_bge_rerank\"}"
  let _ = nif.zenoh_put("indrajaal/l4/sre/rag/reranked", payload)
  Nil
}
