//// scripts/pass10/p10_rete_autofix — RETE-lite auto-remediation loop.
////
//// Goal: continuously close two dominant risks raised by robustness gate:
////   1) EMBED_LOW      -> run bounded embedding backfill batches
////   2) COST_HIGH      -> hold backfill, publish advisory only
////
//// Safety model:
////   - bounded rows (BATCH_MAX)
////   - bounded wall-clock (MAX_SECONDS)
////   - cooldown between batches (COOLDOWN_SEC)
////   - optional guardian gate (REQUIRE_GUARDIAN / ALLOW_SOFT_BYPASS)
////
//// Emits:
////   Zenoh  indrajaal/l5/ooda/autofix
////   Run telemetry indrajaal/l4/sched/run/<id>/*
////   KMS prefs p10_autofix.last_backfill_ns

import envoy
import gleam/erlang/atom
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import scripts/common/guardian
import scripts/common/kms
import scripts/common/metrics
import scripts/common/nif
import scripts/common/run

const default_interval_ms = 120_000
const default_target_cov = 0.90
const default_cost_guard = 5.0
const default_batch_max = 20
const default_max_seconds = 45
const default_heartbeat_every = 5
const default_cooldown_sec = 600
const default_task_id = "116455937980437851"
const default_autofix_enabled = False

pub fn main() -> Nil {
  let interval_ms = env_int("INTERVAL_MS", default_interval_ms)
  let once = has_env("ONCE")
  io.println("=== pass10/rete_autofix ===")
  io.println(
    "interval=" <> int.to_string(interval_ms)
    <> "ms target_cov=" <> float.to_string(env_float("TARGET_COV", default_target_cov))
    <> " cost_guard=" <> float.to_string(env_float("COST_GUARD", default_cost_guard)),
  )
  case once {
    True -> tick()
    False -> loop(interval_ms)
  }
}

fn loop(interval_ms: Int) -> Nil {
  tick()
  sleep_ms(interval_ms)
  loop(interval_ms)
}

pub type Snapshot {
  Snapshot(
    holons: Int,
    embeddings: Int,
    coverage: Float,
    sessions: Int,
    cost_total: Float,
    cost_per_session: Float,
    turns: Int,
    pi_sessions: Int,
    last_backfill_ns: Int,
  )
}

pub type Decision {
  DoBackfill(reason: String)
  Hold(reason: String)
  Noop(reason: String)
}

fn tick() -> Nil {
  let now = nif.now_nanos()
  let ctx =
    run.new(
      "pass10",
      env_str("TASK_ID", default_task_id),
      "scripts-gleam",
      "p10_rete_autofix",
    )
  run.started(ctx)

  let snap = observe()
  let decision = decide(snap, now)
  let enabled = env_bool("AUTOFIX_ENABLED", default_autofix_enabled)

  io.println(
    "snapshot cov=" <> float.to_string(snap.coverage)
    <> " cost/session=" <> float.to_string(snap.cost_per_session)
    <> " last_backfill_ns=" <> int.to_string(snap.last_backfill_ns)
    <> " autofix_enabled=" <> bool_str(enabled),
  )

  case decision {
    DoBackfill(reason) -> {
      io.println("decision=DoBackfill reason=" <> reason)
      run.progress(ctx, 5, "decision", reason)
      case enabled {
        False -> {
          let msg = "autofix disabled; advisory only"
          publish("hold", msg)
          run.completed(ctx, msg)
        }
        True -> {
          let allow = guardian_allow(reason)
          case allow {
            True -> {
              let max_rows = env_int("BATCH_MAX", default_batch_max)
              let max_seconds = env_int("MAX_SECONDS", default_max_seconds)
              let hb = env_int("HEARTBEAT_EVERY", default_heartbeat_every)
              let #(ok, err, processed, stopped) = backfill_batch(ctx, max_rows, max_seconds, hb)
              let _ = metrics.counter_inc("scripts.autofix.backfill", "ok", ok)
              let _ = metrics.counter_inc("scripts.autofix.backfill", "err", err)
              let _ = metrics.counter_inc("scripts.autofix.backfill", "processed", processed)
              set_last_backfill_ns(now)
              let msg =
                "backfill processed=" <> int.to_string(processed)
                <> " ok=" <> int.to_string(ok)
                <> " err=" <> int.to_string(err)
                <> " stopped=" <> bool_str(stopped)
              publish("executed", msg)
              run.completed(ctx, msg)
            }
            False -> {
              let msg = "guardian denied; skipped backfill"
              publish("denied", msg)
              run.failed(ctx, msg)
            }
          }
        }
      }
    }
    Hold(reason) -> {
      io.println("decision=Hold reason=" <> reason)
      let _ = metrics.counter_inc("scripts.autofix.hold", "count", 1)
      publish("hold", reason)
      run.completed(ctx, "hold: " <> reason)
    }
    Noop(reason) -> {
      io.println("decision=Noop reason=" <> reason)
      let _ = metrics.counter_inc("scripts.autofix.noop", "count", 1)
      publish("noop", reason)
      run.completed(ctx, "noop: " <> reason)
    }
  }
}

fn observe() -> Snapshot {
  let holons = count_of("holons")
  let emb = count_of("holon_embeddings")
  let cov = case holons {
    0 -> 0.0
    _ -> int.to_float(emb) /. int.to_float(holons)
  }
  let sessions = count_of("session_metrics")
  let cost_total = float_scalar("SELECT COALESCE(SUM(cost_usd),0.0) FROM session_metrics")
  let cps = case sessions {
    0 -> 0.0
    _ -> cost_total /. int.to_float(sessions)
  }
  let turns = count_of("session_turn_spans")
  let pi_sessions = count_of("pi_sessions")
  let last = last_backfill_ns()
  Snapshot(holons, emb, cov, sessions, cost_total, cps, turns, pi_sessions, last)
}

fn decide(s: Snapshot, now_ns: Int) -> Decision {
  let target = env_float("TARGET_COV", default_target_cov)
  let cost_guard = env_float("COST_GUARD", default_cost_guard)
  let cooldown_sec = env_int("COOLDOWN_SEC", default_cooldown_sec)

  let need_embed = s.coverage <. target
  let expensive = s.cost_per_session >. cost_guard
  let elapsed = case s.last_backfill_ns {
    0 -> 999_999_999
    n -> { now_ns - n } / 1_000_000_000
  }
  let cooldown = elapsed < cooldown_sec

  case need_embed {
    False -> Noop("coverage healthy")
    True ->
      case expensive {
        True -> Hold("cost guard active ($/session too high)")
        False ->
          case cooldown {
            True -> Hold("cooldown active")
            False -> DoBackfill("embed coverage below target")
          }
      }
  }
}

fn guardian_allow(reason: String) -> Bool {
  let require_guardian = env_bool("REQUIRE_GUARDIAN", True)
  let soft_bypass = env_bool("ALLOW_SOFT_BYPASS", False)
  case guardian.approve("l4.embed_backfill", reason, 1500) {
    Ok(guardian.Approved(_)) -> True
    Ok(guardian.Rejected(msg)) -> {
      io.println("guardian rejected: " <> msg)
      case require_guardian {
        True -> False
        False -> soft_bypass
      }
    }
    Error(e) -> {
      io.println("guardian error: " <> errors.render(e))
      case require_guardian {
        True -> False
        False -> soft_bypass
      }
    }
  }
}

fn backfill_batch(
  ctx: run.RunCtx,
  max_rows: Int,
  max_seconds: Int,
  heartbeat_every: Int,
) -> #(Int, Int, Int, Bool) {
  let db = kms.kms_path()
  let sql =
    "SELECT h.holon_uuid, SUBSTR(h.content, 1, 1500)
       FROM holons h LEFT JOIN holon_embeddings e ON h.holon_uuid = e.holon_id
      WHERE e.holon_id IS NULL
         OR typeof(e.embedding) = 'text'
      LIMIT " <> int.to_string(max_rows)

  case kms.query(sql, []) {
    Error(e) -> {
      run.failed(ctx, "query failed: " <> kms.error_to_string(e))
      #(0, 1, 0, True)
    }
    Ok(qr) -> {
      let rows = list.take(qr.rows, max_rows)
      let total = list.length(rows)
      run.progress(ctx, 10, "backfill", "rows=" <> int.to_string(total))
      let started = nif.now_nanos()
      process_rows(
        ctx,
        rows,
        db,
        0,
        0,
        0,
        total,
        started,
        int.to_float(max_seconds) *. 1_000_000_000.0,
        heartbeat_every,
      )
    }
  }
}

fn process_rows(
  ctx: run.RunCtx,
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
        True -> #(ok, err, processed, True)
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
            True -> {
              let pct = case total {
                0 -> 100
                _ -> processed2 * 100 / total
              }
              run.progress(
                ctx,
                pct,
                "backfill",
                "processed=" <> int.to_string(processed2)
                <> " ok=" <> int.to_string(ok2)
                <> " err=" <> int.to_string(err2),
              )
            }
            False -> Nil
          }

          process_rows(
            ctx,
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

fn col_at(row: kms.Row, idx: Int) -> String {
  case list.drop(row, idx) {
    [#(_, v), ..] -> v
    _ -> ""
  }
}

fn publish(state: String, detail: String) -> Nil {
  let payload =
    "{\"state\":\"" <> esc(state) <> "\""
    <> ",\"detail\":\"" <> esc(detail) <> "\""
    <> ",\"ts\":" <> int.to_string(nif.now_nanos())
    <> ",\"by\":\"p10_rete_autofix\"}"
  let _ = nif.zenoh_put("indrajaal/l5/ooda/autofix", payload)
  Nil
}

fn count_of(table: String) -> Int {
  int_scalar("SELECT COUNT(*) FROM " <> table)
}

fn int_scalar(sql: String) -> Int {
  case kms.scalar(sql, []) {
    Ok(v) -> case int.parse(v) {
      Ok(n) -> n
      Error(_) -> 0
    }
    Error(_) -> 0
  }
}

fn float_scalar(sql: String) -> Float {
  case kms.scalar(sql, []) {
    Ok(v) -> case float.parse(v) {
      Ok(n) -> n
      Error(_) -> 0.0
    }
    Error(_) -> 0.0
  }
}

fn last_backfill_ns() -> Int {
  let db = kms.kms_path()
  let #(tag, val) = nif.smriti_get_pref(db, "p10_autofix.last_backfill_ns")
  case atom.to_string(tag) {
    "ok" ->
      case int.parse(val) {
        Ok(n) -> n
        Error(_) -> 0
      }
    _ -> 0
  }
}

fn set_last_backfill_ns(ns: Int) -> Nil {
  let db = kms.kms_path()
  let _ =
    nif.smriti_set_pref(
      db,
      "p10_autofix",
      "last_backfill_ns",
      int.to_string(ns),
    )
  Nil
}

fn env_int(name: String, default: Int) -> Int {
  case envoy.get(name) {
    Ok(v) ->
      case int.parse(v) {
        Ok(n) -> n
        Error(_) -> default
      }
    Error(_) -> default
  }
}

fn env_float(name: String, default: Float) -> Float {
  case envoy.get(name) {
    Ok(v) ->
      case float.parse(v) {
        Ok(n) -> n
        Error(_) -> default
      }
    Error(_) -> default
  }
}

fn env_bool(name: String, default: Bool) -> Bool {
  case envoy.get(name) {
    Ok(v) -> {
      let s = string.lowercase(v)
      s == "1" || s == "true" || s == "yes" || s == "on"
    }
    Error(_) -> default
  }
}

fn env_str(name: String, default: String) -> String {
  case envoy.get(name) {
    Ok(v) -> v
    Error(_) -> default
  }
}

fn has_env(name: String) -> Bool {
  case envoy.get(name) {
    Ok(_) -> True
    Error(_) -> False
  }
}

fn bool_str(b: Bool) -> String {
  case b {
    True -> "true"
    False -> "false"
  }
}

fn esc(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", " ")
}

@external(erlang, "timer", "sleep")
fn sleep_ms(ms: Int) -> Nil

import scripts/common/errors
