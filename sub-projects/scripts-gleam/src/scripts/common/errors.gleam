//// scripts/common/errors — unified error type + classifier.
////
//// Every scripts-gleam module returns `Result(_, ScriptError)` so scheduler,
//// retry, guardrail, and metrics code can reason uniformly about failures.

import gleam/string

pub type ScriptError {
  /// I/O or filesystem failure.
  IoError(detail: String)
  /// Misconfiguration (missing env, bad CLI flags).
  ConfigError(detail: String)
  /// Transient failure — worth retrying.
  Transient(detail: String)
  /// Permanent failure — do not retry.
  Permanent(detail: String)
  /// Timeout while waiting for a remote operation.
  Timeout(detail: String)
  /// Authorization denied (Guardian L0 gate, API 401/403).
  Denied(detail: String)
  /// Upstream service error (Gemini HTTP error, sa-plan non-zero rc, Pi unreachable).
  Upstream(detail: String)
}

/// Short tag used in metrics/log labels.
pub fn tag(e: ScriptError) -> String {
  case e {
    IoError(_) -> "io"
    ConfigError(_) -> "config"
    Transient(_) -> "transient"
    Permanent(_) -> "permanent"
    Timeout(_) -> "timeout"
    Denied(_) -> "denied"
    Upstream(_) -> "upstream"
  }
}

/// Classify whether an error is safe to retry.
pub fn is_retryable(e: ScriptError) -> Bool {
  case e {
    Transient(_) -> True
    Timeout(_) -> True
    Upstream(_) -> True
    _ -> False
  }
}

pub fn detail(e: ScriptError) -> String {
  case e {
    IoError(d) -> d
    ConfigError(d) -> d
    Transient(d) -> d
    Permanent(d) -> d
    Timeout(d) -> d
    Denied(d) -> d
    Upstream(d) -> d
  }
}

/// Human-readable single-line rendering.
pub fn render(e: ScriptError) -> String {
  tag(e) <> ": " <> string.slice(detail(e), 0, 200)
}

/// Lift a `Result(a, String)` into a `Result(a, ScriptError)` with the given tag.
pub fn lift_upstream(r: Result(a, String)) -> Result(a, ScriptError) {
  case r {
    Ok(v) -> Ok(v)
    Error(d) -> Error(Upstream(d))
  }
}

pub fn lift_io(r: Result(a, String)) -> Result(a, ScriptError) {
  case r {
    Ok(v) -> Ok(v)
    Error(d) -> Error(IoError(d))
  }
}
