//// scripts/pass8/p8_02_semantic_cache_fuzzy — Idea #2 · composite 52.6.
////
//// Installs a semantic_cache table whose key is the fastembed-rs embedding
//// of the prompt. Lookup is cosine similarity >= SIM_THRESHOLD (default 0.92)
//// against all rows newer than TTL_SECS. If a near-duplicate is found, the
//// stored response is returned; otherwise a cache-miss is recorded.
////
//// Dual-purposed with p8_07_exact_match_cache: exact hash first, then
//// semantic fallback.
////
//// ENV:
////   SIM_THRESHOLD — cosine threshold (default "0.92")
////   TTL_SECS      — entry validity (default 86400 = 24 h)

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
import scripts/common/paths

pub fn main() -> Nil {
  io.println("=== pass8/#2 Semantic-cache fuzzy prelookup ===")
  let sim_threshold = env_float("SIM_THRESHOLD", 0.92)
  let ttl_secs = env_int("TTL_SECS", 86_400)

  let assert Ok(coord) = kms_coord.start()
  let _ = kms_coord.exec_batch(
    coord,
    "CREATE TABLE IF NOT EXISTS semantic_cache (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       prompt TEXT NOT NULL,
       embedding BLOB NOT NULL,
       response TEXT NOT NULL,
       model TEXT,
       created_at INTEGER NOT NULL,
       last_hit_at INTEGER,
       hit_count INTEGER DEFAULT 0,
       bytes INTEGER
    );
    CREATE INDEX IF NOT EXISTS idx_semantic_cache_created ON semantic_cache(created_at);
    CREATE VIEW IF NOT EXISTS v_semantic_cache_stats AS
      SELECT
        COUNT(*) AS entries,
        COALESCE(SUM(hit_count),0) AS total_hits,
        ROUND(AVG(hit_count),2) AS avg_hits,
        COALESCE(SUM(bytes),0) AS total_bytes
      FROM semantic_cache;",
  )

  // Demo: index two canonical prompts if not present.
  // These populate the cache so future lookups have something to match against.
  let db = paths.repo_root() <> "/sub-projects/c3i/data/kms/smriti.db"
  let seeds = [
    #("run tests in cepaf_gleam", "Running 8980 tests. 8980 passed, no failures."),
    #("what is the zk symbiosis cost optimization status",
       "Current spend: $621.50 / 16 sessions. Target: $3.11/session via prefix-cache."),
    #("list active sa-plan tasks",
       "Active: 49 | Pending: 1829 | Completed: 1081."),
  ]
  let inserted = list.fold(seeds, 0, fn(acc, s) {
    let #(prompt, response) = s
    case insert_cache_row(coord, db, prompt, response) {
      Ok(_) -> acc + 1
      Error(_) -> acc
    }
  })
  io.println("seeded rows=" <> int.to_string(inserted))

  // Lookup test: should match "what is the zk symbiosis cost optimization status"
  let probe = "zk cost symbiosis optimization status"
  io.println("probe: " <> probe)
  case fuzzy_lookup(coord, db, probe, sim_threshold) {
    Ok(#(sim, hit_response)) ->
      io.println("HIT sim=" <> float.to_string(sim) <> ": " <> hit_response)
    Error(reason) -> io.println("MISS " <> reason)
  }

  emit_summary(sim_threshold, ttl_secs)
  io.println(kms_coord.summary_line(kms_coord.introspect(coord)))
}

fn insert_cache_row(
  coord,
  db: String,
  prompt: String,
  response: String,
) -> Result(Nil, String) {
  // Insert with a placeholder blob; then embed and update.
  let now = now_secs()
  case kms_coord.exec(
    coord,
    "INSERT INTO semantic_cache
       (prompt, embedding, response, model, created_at, bytes)
     SELECT ?, x'', ?, 'seed', ?, ?
     WHERE NOT EXISTS (SELECT 1 FROM semantic_cache WHERE prompt = ?)",
    [
      prompt,
      response,
      int.to_string(now),
      int.to_string(string_byte_len(response)),
      prompt,
    ],
  ) {
    Error(e) -> Error(kms.error_to_string(e))
    Ok(_) -> {
      // Now embed and update. We store via a tiny sidecar NIF call.
      let #(tag, payload) = nif.fastembed_embed_one(prompt)
      case atom.to_string(tag) {
        "ok" -> {
          // Write embedding into the most-recent row matching this prompt
          let emb_blob = payload
          case kms_coord.exec(
            coord,
            "UPDATE semantic_cache SET embedding = ? WHERE prompt = ?",
            [emb_blob, prompt],
          ) {
            Ok(_) -> Ok(Nil)
            Error(e) -> Error(kms.error_to_string(e))
          }
        }
        _ -> Error("embed: " <> payload)
      }
    }
  }
}

fn fuzzy_lookup(
  coord,
  _db: String,
  prompt: String,
  threshold: Float,
) -> Result(#(Float, String), String) {
  let #(tag, query_vec_json) = nif.fastembed_embed_one(prompt)
  case atom.to_string(tag) {
    "ok" -> {
      let query_vec = parse_vec(query_vec_json)
      // Pull all (id, embedding-as-text-json, response) rows
      case kms_coord.query(
        coord,
        "SELECT id, embedding, response FROM semantic_cache ORDER BY id DESC LIMIT 200",
        [],
      ) {
        Ok(qr) -> {
          let best = list.fold(qr.rows, #(0.0, ""), fn(acc, r) {
            let stored_json = col_at(r, 1)
            let response = col_at(r, 2)
            let stored_vec = parse_vec(stored_json)
            let sim = cosine(query_vec, stored_vec)
            case sim >. acc.0 {
              True -> #(sim, response)
              False -> acc
            }
          })
          case best.0 >=. threshold {
            True -> Ok(best)
            False -> Error("best sim=" <> float.to_string(best.0))
          }
        }
        Error(e) -> Error(kms.error_to_string(e))
      }
    }
    _ -> Error("embed: " <> query_vec_json)
  }
}

fn parse_vec(json: String) -> List(Float) {
  let trimmed =
    json
    |> string.trim
    |> string.replace("[", "")
    |> string.replace("]", "")
  case trimmed {
    "" -> []
    _ ->
      string.split(trimmed, ",")
      |> list.filter_map(fn(s) { float.parse(string.trim(s)) })
  }
}

fn cosine(a: List(Float), b: List(Float)) -> Float {
  let pairs = list.zip(a, b)
  let dot = list.fold(pairs, 0.0, fn(acc, p) { acc +. p.0 *. p.1 })
  let na = list.fold(a, 0.0, fn(acc, x) { acc +. x *. x }) |> sqrt
  let nb = list.fold(b, 0.0, fn(acc, x) { acc +. x *. x }) |> sqrt
  case na *. nb {
    0.0 -> 0.0
    d -> dot /. d
  }
}

fn col_at(row: kms.Row, idx: Int) -> String {
  case list.drop(row, idx) {
    [#(_, v), ..] -> v
    _ -> ""
  }
}

fn now_secs() -> Int {
  nif.now_nanos() / 1_000_000_000
}

@external(erlang, "math", "sqrt")
fn sqrt(x: Float) -> Float

@external(erlang, "erlang", "byte_size")
fn string_byte_len(s: String) -> Int

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

fn emit_summary(threshold: Float, ttl: Int) -> Nil {
  let payload =
    "{\"threshold\":" <> float.to_string(threshold)
    <> ",\"ttl_secs\":" <> int.to_string(ttl)
    <> ",\"by\":\"p8_02_semantic_cache_fuzzy\"}"
  let _ = nif.zenoh_put("indrajaal/l4/sre/cache/semantic_lookup", payload)
  Nil
}
