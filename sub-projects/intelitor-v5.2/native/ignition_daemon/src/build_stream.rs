/// Build stream parser for podman/docker JSON log lines.
///
/// Parses the newline-delimited JSON that `podman build --progress=plain` emits
/// and extracts structured `BuildStep` information for the TUI progress bar and
/// EMA-based ETA calculations.
///
/// # Pattern reference (no `regex` crate — uses manual parsing for zero-dep)
///
/// STEP lines:   `STEP N/M: <instruction>`  or  `STEP N/M | <instruction>`
/// Cache lines:  contain "Using cache" or "CACHED"
/// Error lines:  start with "error"/"ERROR", or contain "COPY failed"/"RUN.*returned"
use serde::{Deserialize, Serialize};

// ─── Raw stream event types (kept from original scaffold) ────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum BuildStreamEvent {
    Stream {
        stream: String,
    },
    Error {
        error: String,
        error_detail: Option<ErrorDetail>,
    },
    Status {
        status: String,
        progress: Option<String>,
        id: Option<String>,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorDetail {
    pub message: String,
}

/// Deserialise a raw JSON log line into a `BuildStreamEvent`.
/// Returns `None` for non-JSON or unrecognised lines.
pub fn parse_build_stream_line(line: &str) -> Option<BuildStreamEvent> {
    serde_json::from_str(line).ok()
}

// ─── Structured build step ───────────────────────────────────────────────────

/// A parsed Dockerfile build step extracted from a `STEP N/M` log line.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BuildStep {
    /// 1-based step number (N in STEP N/M)
    pub step_number: usize,
    /// Total steps in this build (M in STEP N/M)
    pub total_steps: usize,
    /// The Dockerfile instruction text after the colon/pipe separator
    pub instruction: String,
    /// Whether this step was served from the build cache
    pub cache_hit: bool,
}

// ─── Step parser (manual, no regex) ─────────────────────────────────────────

/// Attempt to parse a STEP line from podman build `--progress=plain` output.
///
/// Accepts both separator variants:
///   `STEP 3/10: RUN apt-get install ...`
///   `STEP 3/10 | RUN apt-get install ...`
///
/// Returns `None` for any line that does not start with `STEP `.
pub fn parse_build_line(line: &str) -> Option<BuildStep> {
    let trimmed = line.trim();

    // Must start with "STEP " (case-sensitive — podman uses uppercase)
    if !trimmed.starts_with("STEP ") {
        return None;
    }

    // Slice past "STEP "
    let rest = &trimmed["STEP ".len()..];

    // Find the slash that separates N from M
    let slash_pos = rest.find('/')?;
    let n_str = &rest[..slash_pos];
    let step_number: usize = n_str.trim().parse().ok()?;

    // After the slash, find the first non-digit to locate M
    let after_slash = &rest[slash_pos + 1..];
    let sep_pos = after_slash
        .find(|c: char| !c.is_ascii_digit())
        .unwrap_or(after_slash.len());
    let m_str = &after_slash[..sep_pos];
    let total_steps: usize = m_str.trim().parse().ok()?;

    // The rest after M contains the separator (colon, pipe, whitespace) then the instruction
    let after_m = &after_slash[sep_pos..];

    // Strip leading whitespace, then one optional separator char (`:` or `|`), then whitespace
    let instruction = after_m
        .trim_start()
        .trim_start_matches(':')
        .trim_start_matches('|')
        .trim()
        .to_string();

    Some(BuildStep {
        step_number,
        total_steps,
        instruction,
        cache_hit: false,
    })
}

// ─── Cache / error helpers ───────────────────────────────────────────────────

/// Returns `true` when a build log line signals that the layer was served from cache.
///
/// Detects both podman plain-output variants:
///   `Using cache <hash>`
///   `--> Cached`  / `CACHED`
pub fn is_cache_hit(line: &str) -> bool {
    line.contains("Using cache") || line.contains("CACHED")
}

/// Returns `true` when a build log line signals a build error.
///
/// Covers:
///   Lines beginning with `error` or `ERROR`
///   `COPY failed: …`
///   `RUN … returned a non-zero code`
pub fn is_build_error(line: &str) -> bool {
    let t = line.trim();
    t.starts_with("error")
        || t.starts_with("ERROR")
        || t.contains("COPY failed")
        || (t.contains("RUN") && t.contains("returned"))
}

// ─── ETA calculation ─────────────────────────────────────────────────────────

/// Estimate remaining build time in milliseconds using the Exponential Moving Average.
///
/// Formula: `remaining_steps * ema_ms_per_step`
///
/// # Arguments
/// * `current_step`  – The step that just completed (1-based).
/// * `total_steps`   – Total number of steps in the build.
/// * `ema_ms`        – EMA of milliseconds per step (from `BuildHistory`).
///
/// # Returns
/// Estimated remaining milliseconds. Returns `0.0` when all steps are done.
pub fn calculate_eta(current_step: usize, total_steps: usize, ema_ms: f64) -> f64 {
    if current_step >= total_steps {
        return 0.0;
    }
    let remaining = total_steps.saturating_sub(current_step);
    (remaining as f64) * ema_ms
}

// ─── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_step_line_colon_separator() {
        let line = "STEP 3/10: RUN apt-get update";
        let step = parse_build_line(line).expect("should parse STEP line");
        assert_eq!(step.step_number, 3);
        assert_eq!(step.total_steps, 10);
        assert_eq!(step.instruction, "RUN apt-get update");
        assert!(!step.cache_hit);
    }

    #[test]
    fn parse_step_line_pipe_separator() {
        // Some podman versions emit a pipe instead of a colon
        let line = "STEP 1/5 | FROM ubuntu:22.04";
        let step = parse_build_line(line).expect("should parse STEP line with pipe");
        assert_eq!(step.step_number, 1);
        assert_eq!(step.total_steps, 5);
        assert_eq!(step.instruction, "FROM ubuntu:22.04");
    }

    #[test]
    fn parse_non_step_line_returns_none() {
        // Regular log lines must not be misidentified as steps
        assert!(parse_build_line("Successfully built abc123").is_none());
        assert!(parse_build_line("Using cache").is_none());
        assert!(parse_build_line("").is_none());
        assert!(parse_build_line("   ").is_none());
    }

    #[test]
    fn cache_hit_detection() {
        assert!(is_cache_hit("Using cache abc123def456"));
        assert!(is_cache_hit("--> CACHED"));
        assert!(is_cache_hit("STEP 2/8: CACHED"));
        assert!(!is_cache_hit("STEP 3/8: RUN echo hello"));
        assert!(!is_cache_hit("Successfully tagged localhost/myimage:latest"));
    }

    #[test]
    fn error_detection() {
        assert!(is_build_error("error: failed to compute env vars"));
        assert!(is_build_error("ERROR: dockerfile parse error"));
        assert!(is_build_error("COPY failed: file not found"));
        assert!(is_build_error("RUN pip install returned a non-zero code: 1"));
        assert!(!is_build_error("STEP 4/10: COPY . /app"));
        assert!(!is_build_error("Successfully built abc123"));
    }

    #[test]
    fn eta_calculation() {
        // 7 steps remaining at 500ms each → 3500ms
        let eta = calculate_eta(3, 10, 500.0);
        assert!((eta - 3500.0).abs() < f64::EPSILON, "expected 3500.0, got {}", eta);

        // Already at the last step → 0ms remaining
        assert_eq!(calculate_eta(10, 10, 500.0), 0.0);

        // current_step > total_steps (guard against over-run) → 0ms
        assert_eq!(calculate_eta(12, 10, 500.0), 0.0);

        // Zero EMA (no history yet) → 0ms regardless of steps
        assert_eq!(calculate_eta(0, 10, 0.0), 0.0);
    }
}
