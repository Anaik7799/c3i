//// scripts/pass8/p8_04_embed_backfill — Idea #4 · composite 45.5.
////
//// Fills holon_embeddings for every holon missing a row. Writes BLOB-encoded
//// f32 (little-endian, 768×4=3072 bytes) via the `fastembed_embed_and_store`
//// NIF — schema-compatible with existing rows. 50× faster than the prior
//// Ollama HTTP path, zero external dependencies.
////
//// ENV:
////   MAX — max rows to backfill per invocation (default 500)

import envoy
import gleam/erlang/atom
import gleam/int
import gleam/float
import gleam/io
import gleam/list
import scripts/common/kms
import scripts/common/kms_coord
import scripts/common/nif
import scripts/common/paths

pub fn main() -> Nil {
  io.println("=== pass8/#4 Embedding backfill (fastembed NIF · BLOB f32) ===")
  let max = env_int("MAX", 500)
  let max_seconds = env_int("MAX_SECONDS", 120)
  let heartbeat_every = env_int("HEARTBEAT_EVERY", 10)
  io.println(
    "max=" <> int.to_string(max)
    <> " max_seconds=" <> int.to_string(max_seconds)
    <> " heartbeat_every=" <> int.to_string(heartbeat_every),
  )

  let #(info_tag, info) = nif.fastembed_info()
  io.println("engine: " <> atom.to_string(info_tag) <> " " <> info)

  let assert Ok(coord) = kms_coord.start()
  let db_path = paths.repo_root() <> "/sub-projects/c3i/data/kms/smriti.db"

  // Prefer text-stored rows first to re-encode them as BLOB, then missing rows.
  // This single pass handles both cases.
  let sql =
    "SELECT h.holon_uuid, SUBSTR(h.content, 1, 1500)
       FROM holons h LEFT JOIN holon_embeddings e ON h.holon_uuid = e.holon_id
      WHERE e.holon_id IS NULL
         OR typeof(e.embedding) = 'text'
      LIMIT " <> int.to_string(max)

  case kms_coord.query(coord, sql, []) {
    Error(e) -> io.println_error("query: " <> kms.error_to_string(e))
    Ok(qr) -> {
      let n = list.length(qr.rows)
      io.println("pending=" <> int.to_string(n))
      let started = nif.now_nanos()
      let max_ns = int.to_float(max_seconds) *. 1_000_000_000.0
      // Ensure deterministic, bounded work: at most `max` rows and bounded
      // wall-clock by MAX_SECONDS. This avoids operator perception of "hang".
      let rows = list.take(qr.rows, max)
      let #(ok, err, processed, stopped) =
        process_rows(
          rows,
          db_path,
          0,
          0,
          0,
          list.length(rows),
          started,
          max_ns,
          heartbeat_every,
        )
      io.println(
        "embedded=" <> int.to_string(ok)
        <> " failed=" <> int.to_string(err)
        <> " processed=" <> int.to_string(processed)
        <> " stopped=" <> bool_to_string(stopped),
      )
      emit_summary(ok, err, processed, stopped)
      io.println(kms_coord.summary_line(kms_coord.introspect(coord)))
    }
  }
}

fn col_at(row: kms.Row, idx: Int) -> String {
  case list.drop(row, idx) {
    [#(_, v), ..] -> v
    _ -> ""
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

fn emit_summary(ok: Int, err: Int, processed: Int, stopped: Bool) -> Nil {
  let payload =
    "{\"ok\":" <> int.to_string(ok)
    <> ",\"err\":" <> int.to_string(err)
    <> ",\"processed\":" <> int.to_string(processed)
    <> ",\"stopped\":" <> bool_to_string(stopped)
    <> ",\"engine\":\"fastembed-rs\",\"format\":\"blob-f32-le\","
    <> "\"by\":\"p8_04_embed_backfill\"}"
  let _ = nif.zenoh_put("indrajaal/l4/sre/kms/embed_backfilled", payload)
  Nil
}

fn process_rows(
  rows: List(kms.Row),
  db_path: String,
  ok: Int,
  err: Int,
  processed: Int,
  total: Int,
  started_ns: Int,
  max_ns: Float,
  heartbeat_every: Int,
) -> #(Int, Int, Int, Bool) {
  case rows {
    [] -> #(ok, err, processed, False)
    [row, ..rest] -> {
      let elapsed_ns = int.to_float(nif.now_nanos() - started_ns)
      case elapsed_ns >. max_ns {
        True -> {
          io.println("jidoka-stop: time budget exceeded")
          #(ok, err, processed, True)
        }
        False -> {
          let uuid = col_at(row, 0)
          let text = col_at(row, 1)
          let #(ok2, err2, processed2) =
            case uuid {
              "" -> #(ok, err, processed)
              _ -> {
                let #(tag, _) = nif.fastembed_embed_and_store(db_path, uuid, text)
                case atom.to_string(tag) {
                  "ok" -> #(ok + 1, err, processed + 1)
                  _ -> #(ok, err + 1, processed + 1)
                }
              }
            }

          let should_hb =
            heartbeat_every > 0
            && processed2 > 0
            && case int.modulo(processed2, heartbeat_every) {
              Ok(0) -> True
              _ -> False
            }
          case should_hb {
            True -> print_progress(processed2, total, ok2, err2, started_ns)
            False -> Nil
          }

          process_rows(
            rest,
            db_path,
            ok2,
            err2,
            processed2,
            total,
            started_ns,
            max_ns,
            heartbeat_every,
          )
        }
      }
    }
  }
}

fn print_progress(processed: Int, total: Int, ok: Int, err: Int, started_ns: Int) -> Nil {
  let elapsed_ms = { nif.now_nanos() - started_ns } / 1_000_000
  let rate_per_sec = case elapsed_ms {
    0 -> 0.0
    _ -> {
      let elapsed_s = int.to_float(elapsed_ms) /. 1000.0
      int.to_float(processed) /. elapsed_s
    }
  }
  let remain = case total - processed {
    n if n > 0 -> n
    _ -> 0
  }
  let eta_s = case rate_per_sec >. 0.0 {
    True -> int.to_float(remain) /. rate_per_sec
    False -> 0.0
  }
  io.println(
    "progress " <> int.to_string(processed) <> "/" <> int.to_string(total)
    <> " ok=" <> int.to_string(ok)
    <> " err=" <> int.to_string(err)
    <> " rate=" <> float.to_string(rate_per_sec)
    <> "/s eta=" <> float.to_string(eta_s) <> "s",
  )
}

fn bool_to_string(b: Bool) -> String {
  case b {
    True -> "true"
    False -> "false"
  }
}
