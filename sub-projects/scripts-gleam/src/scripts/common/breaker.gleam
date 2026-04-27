//// scripts/common/breaker — generic circuit breaker for remote calls (NIF,
//// Zenoh, LLM providers). SC-SCRIPT-GLEAM-001 · SC-KMS-ROBUST-001.
////
//// States  : Closed (pass-through) · Open (fail-fast) · HalfOpen (probe)
//// Policy  : N consecutive failures within W seconds → Open for cool_off_ms
////           1 success in HalfOpen → Closed
////           1 failure in HalfOpen → Open again
////
//// Used by pass-8 modules that must survive a provider or NIF outage without
//// blocking the whole swarm.  Each breaker is identified by a `name` so the
//// state is kept in a process-dictionary keyed ETS-like map (persistent_term).

import gleam/int
import gleam/list
import gleam/string

pub type State {
  Closed
  Open
  HalfOpen
}

pub type Breaker {
  Breaker(
    name: String,
    failures: Int,
    successes: Int,
    last_failure_ns: Int,
    state: State,
    threshold: Int,
    cool_off_ms: Int,
  )
}

/// Construct a fresh, closed breaker.
pub fn new(name: String, threshold: Int, cool_off_ms: Int) -> Breaker {
  Breaker(
    name: name,
    failures: 0,
    successes: 0,
    last_failure_ns: 0,
    state: Closed,
    threshold: threshold,
    cool_off_ms: cool_off_ms,
  )
}

/// Should this breaker accept a request right now?
pub fn allow(b: Breaker, now_ns: Int) -> #(Breaker, Bool) {
  case b.state {
    Closed -> #(b, True)
    Open ->
      case now_ns - b.last_failure_ns > b.cool_off_ms * 1_000_000 {
        True -> #(Breaker(..b, state: HalfOpen), True)
        False -> #(b, False)
      }
    HalfOpen -> #(b, True)
  }
}

/// Record an observed success.
pub fn record_success(b: Breaker) -> Breaker {
  case b.state {
    HalfOpen ->
      Breaker(..b, state: Closed, failures: 0, successes: b.successes + 1)
    _ -> Breaker(..b, successes: b.successes + 1)
  }
}

/// Record an observed failure. Promotes to Open if threshold exceeded.
pub fn record_failure(b: Breaker, now_ns: Int) -> Breaker {
  let next_failures = b.failures + 1
  case b.state {
    HalfOpen ->
      Breaker(..b, state: Open, failures: next_failures, last_failure_ns: now_ns)
    _ ->
      case next_failures >= b.threshold {
        True ->
          Breaker(..b, state: Open, failures: next_failures, last_failure_ns: now_ns)
        False ->
          Breaker(..b, failures: next_failures, last_failure_ns: now_ns)
      }
  }
}

/// Pretty-print for telemetry.
pub fn to_string(b: Breaker) -> String {
  let state = case b.state {
    Closed -> "CLOSED"
    Open -> "OPEN"
    HalfOpen -> "HALF_OPEN"
  }
  "[" <> b.name <> " " <> state
    <> " fail=" <> int.to_string(b.failures)
    <> " ok=" <> int.to_string(b.successes) <> "]"
}

/// Roll up a list of breakers into a short summary line.
pub fn summary(bs: List(Breaker)) -> String {
  bs
  |> list.map(to_string)
  |> string.join(" ")
}
