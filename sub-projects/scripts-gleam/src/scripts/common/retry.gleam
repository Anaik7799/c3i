//// scripts/common/retry — exponential backoff with jitter + metrics.
////
//// Addresses scalability dimension #12 (typed errors & recovery). Every
//// retried attempt emits counter + histogram metrics via `scripts/common/metrics`
//// so the registry/observability surface can show retry rates.

import gleam/int
import scripts/common/errors.{type ScriptError}
import scripts/common/metrics
import scripts/common/nif

pub type Policy {
  Policy(
    max_attempts: Int,
    initial_delay_ms: Int,
    max_delay_ms: Int,
    // multiplier is percent * 100 (e.g. 200 == 2.0x) to stay Int-only.
    multiplier_pct: Int,
  )
}

pub fn default_policy() -> Policy {
  Policy(
    max_attempts: 3,
    initial_delay_ms: 500,
    max_delay_ms: 30_000,
    multiplier_pct: 200,
  )
}

@external(erlang, "timer", "sleep")
fn sleep(ms: Int) -> Nil

/// Pseudo-random jitter in [0, scale_ms]. Uses the Erlang rand module via FFI.
@external(erlang, "rand", "uniform")
fn rand_uniform(n: Int) -> Int

fn jitter(scale_ms: Int) -> Int {
  case scale_ms <= 0 {
    True -> 0
    False -> rand_uniform(scale_ms)
  }
}

fn next_delay(current: Int, policy: Policy) -> Int {
  let base = current * policy.multiplier_pct / 100
  let capped = case base > policy.max_delay_ms {
    True -> policy.max_delay_ms
    False -> base
  }
  capped + jitter(capped / 4)
}

/// Run `work` with exponential-backoff retry on retryable `ScriptError`s.
/// Emits metrics `scripts.retry.attempts` (counter) + `scripts.retry.duration_ms`
/// (histogram) labelled by `label`.
pub fn with_policy(
  label: String,
  policy: Policy,
  work: fn() -> Result(a, ScriptError),
) -> Result(a, ScriptError) {
  loop(label, policy, policy.initial_delay_ms, 1, work)
}

fn loop(
  label: String,
  policy: Policy,
  delay: Int,
  attempt: Int,
  work: fn() -> Result(a, ScriptError),
) -> Result(a, ScriptError) {
  let start_ns = nif.now_nanos()
  let result = work()
  let dur_ms = { nif.now_nanos() - start_ns } / 1_000_000
  let _ =
    metrics.histogram_observe(
      "scripts.retry.duration_ms",
      label,
      int.to_float(dur_ms),
    )
  case result {
    Ok(v) -> {
      let _ = metrics.counter_inc("scripts.retry.success", label, 1)
      Ok(v)
    }
    Error(e) -> {
      case errors.is_retryable(e) && attempt < policy.max_attempts {
        True -> {
          let _ =
            metrics.counter_inc(
              "scripts.retry.attempts",
              label <> "." <> errors.tag(e),
              1,
            )
          sleep(delay)
          loop(label, policy, next_delay(delay, policy), attempt + 1, work)
        }
        False -> {
          let _ =
            metrics.counter_inc(
              "scripts.retry.giveup",
              label <> "." <> errors.tag(e),
              1,
            )
          Error(e)
        }
      }
    }
  }
}
