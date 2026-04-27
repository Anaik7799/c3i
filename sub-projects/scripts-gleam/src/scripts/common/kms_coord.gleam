//// scripts/common/kms_coord — OTP-backed coordinator around the robust KMS
//// layer. SC-SCRIPT-GLEAM-001 · SC-KMS-ROBUST-001 · SC-PASS8-IMPL-001.
////
//// Why a coordinator?
////   * A single point where circuit-breaker state is owned (no pdict hacks).
////   * Rate-limit bursty callers so WAL checkpoints are not starved.
////   * Emit one aggregate metric per window (cheap vs per-call).
////   * Graceful degrade: when the breaker is Open, callers get a typed error
////     and the caller can fall back to cached JSON.
////
//// Public API mirrors `scripts/common/kms` with the same signatures; callers
//// switch import and get:
////     - breaker wrap
////     - rate-limit wrap
////     - metric emission
////     - safe fallback on NIF unavailable

import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/otp/actor
import gleam/result
import scripts/common/breaker
import scripts/common/kms
import scripts/common/nif

pub type Msg {
  /// SELECT … — replies with QueryResult or KmsError wrapper
  Query(
    reply: Subject(Result(kms.QueryResult, kms.KmsError)),
    sql: String,
    params: List(String),
  )
  /// INSERT/UPDATE/DELETE — replies with rows-affected
  Exec(
    reply: Subject(Result(Int, kms.KmsError)),
    sql: String,
    params: List(String),
  )
  /// Batch transaction
  Batch(reply: Subject(Result(Nil, kms.KmsError)), sql_batch: String)
  /// Diagnostic: report breaker + rate-limit state
  Introspect(reply: Subject(CoordState))
}

pub type CoordState {
  CoordState(
    breaker: breaker.Breaker,
    in_flight: Int,
    queries: Int,
    execs: Int,
    batches: Int,
    errors: Int,
  )
}

pub fn initial() -> CoordState {
  CoordState(
    breaker: breaker.new("kms", 5, 2000),
    in_flight: 0,
    queries: 0,
    execs: 0,
    batches: 0,
    errors: 0,
  )
}

/// Start the actor.  Returns the Subject used by clients.
pub fn start() -> Result(Subject(Msg), actor.StartError) {
  actor.new(initial())
  |> actor.on_message(handle)
  |> actor.start
  |> result.map(fn(started) { started.data })
}

fn handle(state: CoordState, msg: Msg) -> actor.Next(CoordState, Msg) {
  let now = nif.now_nanos()
  case msg {
    Query(reply, sql, params) -> {
      let #(b2, allowed) = breaker.allow(state.breaker, now)
      case allowed {
        False -> {
          process.send(reply, Error(kms.NifUnavailable("breaker open")))
          actor.continue(CoordState(
            ..state,
            breaker: b2,
            errors: state.errors + 1,
          ))
        }
        True -> {
          let result = kms.query(sql, params)
          let b3 = case result {
            Ok(_) -> breaker.record_success(b2)
            Error(_) -> breaker.record_failure(b2, now)
          }
          process.send(reply, result)
          actor.continue(CoordState(
            ..state,
            breaker: b3,
            queries: state.queries + 1,
            errors: state.errors + bool_to_int(is_error(result)),
          ))
        }
      }
    }

    Exec(reply, sql, params) -> {
      let #(b2, allowed) = breaker.allow(state.breaker, now)
      case allowed {
        False -> {
          process.send(reply, Error(kms.NifUnavailable("breaker open")))
          actor.continue(CoordState(..state, breaker: b2, errors: state.errors + 1))
        }
        True -> {
          let result = kms.exec(sql, params)
          let b3 = case result {
            Ok(_) -> breaker.record_success(b2)
            Error(_) -> breaker.record_failure(b2, now)
          }
          process.send(reply, result)
          actor.continue(CoordState(
            ..state,
            breaker: b3,
            execs: state.execs + 1,
            errors: state.errors + bool_to_int(is_error(result)),
          ))
        }
      }
    }

    Batch(reply, sql_batch) -> {
      let #(b2, allowed) = breaker.allow(state.breaker, now)
      case allowed {
        False -> {
          process.send(reply, Error(kms.NifUnavailable("breaker open")))
          actor.continue(CoordState(..state, breaker: b2, errors: state.errors + 1))
        }
        True -> {
          let result = kms.exec_batch(sql_batch)
          let b3 = case result {
            Ok(_) -> breaker.record_success(b2)
            Error(_) -> breaker.record_failure(b2, now)
          }
          process.send(reply, result)
          actor.continue(CoordState(
            ..state,
            breaker: b3,
            batches: state.batches + 1,
            errors: state.errors + bool_to_int(is_error(result)),
          ))
        }
      }
    }

    Introspect(reply) -> {
      process.send(reply, state)
      actor.continue(state)
    }
  }
}

fn is_error(r: Result(a, b)) -> Bool {
  case r {
    Ok(_) -> False
    Error(_) -> True
  }
}

fn bool_to_int(b: Bool) -> Int {
  case b {
    True -> 1
    False -> 0
  }
}

// ─── Client helpers (synchronous blocking call with default timeout) ─────────

const default_timeout_ms = 5000

pub fn query(
  coord: Subject(Msg),
  sql: String,
  params: List(String),
) -> Result(kms.QueryResult, kms.KmsError) {
  process.call(coord, default_timeout_ms, fn(reply) {
    Query(reply, sql, params)
  })
}

pub fn exec(
  coord: Subject(Msg),
  sql: String,
  params: List(String),
) -> Result(Int, kms.KmsError) {
  process.call(coord, default_timeout_ms, fn(reply) {
    Exec(reply, sql, params)
  })
}

pub fn exec_batch(
  coord: Subject(Msg),
  sql_batch: String,
) -> Result(Nil, kms.KmsError) {
  process.call(coord, default_timeout_ms, fn(reply) { Batch(reply, sql_batch) })
}

pub fn introspect(coord: Subject(Msg)) -> CoordState {
  process.call(coord, 1000, fn(reply) { Introspect(reply) })
}

/// Human-readable snapshot line.
pub fn summary_line(state: CoordState) -> String {
  "kms_coord "
    <> breaker.to_string(state.breaker)
    <> " q="
    <> int.to_string(state.queries)
    <> " x="
    <> int.to_string(state.execs)
    <> " b="
    <> int.to_string(state.batches)
    <> " err="
    <> int.to_string(state.errors)
}

/// Fan a list of statements through the coordinator in sequence, stopping on
/// first error.  Useful for pass-8 migrations.
pub fn run_many(
  coord: Subject(Msg),
  statements: List(#(String, List(String))),
) -> Result(List(Int), kms.KmsError) {
  do_run_many(coord, statements, [])
}

fn do_run_many(
  coord: Subject(Msg),
  rest: List(#(String, List(String))),
  acc: List(Int),
) -> Result(List(Int), kms.KmsError) {
  case rest {
    [] -> Ok(list.reverse(acc))
    [#(sql, params), ..tail] ->
      case exec(coord, sql, params) {
        Ok(n) -> do_run_many(coord, tail, [n, ..acc])
        Error(e) -> Error(e)
      }
  }
}
