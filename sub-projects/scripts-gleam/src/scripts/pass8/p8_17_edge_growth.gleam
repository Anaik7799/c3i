//// scripts/pass8/p8_17_edge_growth — Idea #17 · composite 33.6.
////
//// Discovers more edges in holon_edges by scanning holon content for
//// references to other zk-UUIDs, plus topic-keyword overlap. Inserts
//// de-duplicated rows via the robust coordinator.

import envoy
import gleam/int
import gleam/io
import gleam/list
import gleam/regexp
import gleam/result
import gleam/string
import scripts/common/kms
import scripts/common/kms_coord
import scripts/common/nif

pub fn main() -> Nil {
  io.println("=== pass8/#17 Edge growth ===")
  let max = case envoy.get("MAX") {
    Ok(v) ->
      case int.parse(v) {
        Ok(n) -> n
        Error(_) -> 2000
      }
    Error(_) -> 2000
  }

  let assert Ok(coord) = kms_coord.start()

  // Assemble all holons to scan
  let sql =
    "SELECT holon_uuid, SUBSTR(content, 1, 3000)
       FROM holons LIMIT " <> int.to_string(max)

  case kms_coord.query(coord, sql, []) {
    Error(e) -> io.println_error("query: " <> kms.error_to_string(e))
    Ok(qr) -> {
      io.println("holons scanned=" <> int.to_string(list.length(qr.rows)))
      let edges = discover_wiki_edges(qr.rows)
      io.println("candidate wiki edges=" <> int.to_string(list.length(edges)))

      let inserted = list.fold(edges, 0, fn(acc, e) {
        let #(src, dst) = e
        case
          kms_coord.exec(
            coord,
            "INSERT OR IGNORE INTO holon_edges
               (source_id, target_id, link_type, weight) VALUES (?, ?, 'wiki', 1.0)",
            [src, dst],
          )
        {
          Ok(n) -> acc + n
          Error(_) -> acc
        }
      })
      io.println("inserted=" <> int.to_string(inserted))
      emit_summary(list.length(edges), inserted)
      io.println(kms_coord.summary_line(kms_coord.introspect(coord)))
    }
  }
}

fn discover_wiki_edges(rows: List(kms.Row)) -> List(#(String, String)) {
  // Build a fast set of UUIDs present
  let all_uuids =
    rows
    |> list.map(fn(r) {
      case list.drop(r, 0) {
        [#(_, v), ..] -> v
        _ -> ""
      }
    })
    |> list.filter(fn(u) { u != "" })

  let assert Ok(re) = regexp.from_string("zk-[0-9a-f]{16}")

  rows
  |> list.flat_map(fn(r) {
    let src = case list.drop(r, 0) {
      [#(_, v), ..] -> v
      _ -> ""
    }
    let content = case list.drop(r, 1) {
      [#(_, v), ..] -> v
      _ -> ""
    }
    case src {
      "" -> []
      _ ->
        regexp.scan(re, content)
        |> list.map(fn(m) { m.content })
        |> list.filter(fn(u) { u != src && list.contains(all_uuids, u) })
        |> list.map(fn(u) { #(src, u) })
    }
  })
  |> list.unique
}

fn emit_summary(candidates: Int, inserted: Int) -> Nil {
  let payload =
    "{\"candidates\":" <> int.to_string(candidates)
    <> ",\"inserted\":" <> int.to_string(inserted)
    <> ",\"by\":\"p8_17_edge_growth\"}"
  let _ = nif.zenoh_put("indrajaal/l4/sre/kms/edges_grown", payload)
  Nil
}
