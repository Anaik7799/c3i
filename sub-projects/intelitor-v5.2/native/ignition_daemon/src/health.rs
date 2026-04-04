//! # Health Check Module — SIL-6 Ignition Daemon
//!
//! ## Fractal Position
//! | Dimension | Value |
//! |-----------|-------|
//! | Layer     | L4-System (Container Health Probes) |
//! | Element   | Health / Liveness / Readiness |
//!
//! ## Source Mapping
//! - PanopticIgnition.fs:245-357 (waitForPort, waitForContainerHealth, pgIsReady)
//! - HealthCoordinator.fs:255-286 (FPPS 5-point consensus)
//! - capture-ignition.sh:177-237 (validate_container dispatch)
//!
//! ## STAMP
//! - SC-BOOT-006: All containers MUST pass health check before boot completes
//! - SC-IGNITE-005: BuildHistory MUST persist build timing with EMA estimation
//! - SC-IGNITE-003: 7-Level Fractal RCA MUST be executed automatically on boot failure
//! - SC-OPT-002: Health check exponential backoff (100ms → 3200ms)
//! - SC-SIL4-001: Safety functions MUST fail to safe state
//! - SC-SIL4-006: 2oo3 voting MANDATORY for production actuations
//! - SC-VAL-003: FPPS consensus required for health validation

#[allow(unused_imports)]
use crate::build_oracle;
use crate::errors::IgnitionError;
#[allow(unused_imports)]
use crate::health_orchestra;
use crate::podman;
use crate::types::*;
use log::{debug, info, warn};
use std::time::{Duration, Instant};

/// TCP port probe inside a container.
/// Source: PanopticIgnition.fs:245-256, capture-ignition.sh:204
/// SC-BOOT-006: Container health check
pub async fn check_port(
    container: &str,
    port: u16,
    timeout: Duration,
) -> Result<bool, IgnitionError> {
    let cmd_str = format!("nc -z localhost {} 2>/dev/null", port);
    match podman::podman_exec(container, &["sh", "-c", &cmd_str], timeout).await {
        Ok((_, _, code)) => Ok(code == 0),
        Err(_) => Ok(false),
    }
}

/// PostgreSQL readiness check.
/// Source: PanopticIgnition.fs:289, capture-ignition.sh:211
/// SC-SIL4-001: Safety functions fail to safe state
pub async fn check_postgres(
    container: &str,
    timeout: Duration,
) -> Result<bool, IgnitionError> {
    match podman::podman_exec(container, &["pg_isready", "-U", "postgres"], timeout).await {
        Ok((_, _, code)) => Ok(code == 0),
        Err(_) => Ok(false),
    }
}

/// Container running state check.
/// Source: capture-ignition.sh:218
pub async fn check_running(container: &str) -> Result<bool, IgnitionError> {
    match podman::container_status(container).await {
        Ok(status) => Ok(status == "running"),
        Err(_) => Ok(false),
    }
}

/// HTTP health endpoint check.
/// Source: StartupVerification.fs:249-265
pub async fn check_http(url: &str, timeout: Duration) -> Result<bool, IgnitionError> {
    match podman::podman_cmd(
        &["run", "--rm", "--network", "host", "docker.io/curlimages/curl:latest", "-sf", url],
        timeout,
    )
    .await
    {
        Ok((_, _, code)) => Ok(code == 0),
        Err(_) => {
            // Fallback: use curl directly on host
            let result = tokio::process::Command::new("curl")
                .args(["-sf", "--max-time", "5", url])
                .output()
                .await;
            match result {
                Ok(output) => Ok(output.status.success()),
                Err(_) => Ok(false),
            }
        }
    }
}

/// Redis embedded check (with LC_ALL=C locale fix).
/// Source: F11 fix — Redis 8.2.3 locale crash on NixOS
/// FMEA FM-13: RPN 336 (silent child exit on daemonize)
pub async fn check_redis(container: &str) -> Result<bool, IgnitionError> {
    match podman::podman_exec(
        container,
        &["sh", "-c", "LC_ALL=C redis-cli -h 127.0.0.1 ping"],
        Duration::from_secs(3),
    )
    .await
    {
        Ok((stdout, _, _)) => Ok(stdout.contains("PONG")),
        Err(_) => Ok(false),
    }
}

/// 2oo3 quorum check.
/// Source: HealthCoordinator.fs:218-220, PanopticIgnition.fs:844-850
/// Math: Q(N) = floor(N/2) + 1; for N=3, Q=2
/// SC-SIL4-006: 2oo3 voting MANDATORY
pub fn check_quorum(healthy: u32, total: u32) -> bool {
    healthy >= quorum_threshold(total)
}

/// FPPS 5-point consensus.
/// Source: HealthCoordinator.fs:255-286
/// ALL 5 must pass for consensus. SC-VAL-003.
///
/// Checks:
///   1. status != Unreachable
///   2. health_score >= 0.3 (FPPS_UNHEALTHY_THRESHOLD)
///   3. consecutive_failures < 3 (FPPS_FAILURE_THRESHOLD)
///   4. last_heartbeat < 30s ago (FPPS_HEARTBEAT_TIMEOUT_SECS)
///   5. response_time < 5000ms (FPPS_LATENCY_THRESHOLD_MS)
pub fn fpps_consensus(node: &HealthNode) -> bool {
    let now = chrono::Utc::now();

    let reachable = node.status != HealthStatus::Unreachable;
    let score_ok = node.health_score >= FPPS_UNHEALTHY_THRESHOLD;
    let failures_ok = node.consecutive_failures < FPPS_FAILURE_THRESHOLD;
    let heartbeat_ok = node
        .last_heartbeat
        .map(|hb| {
            (now - hb).num_seconds() < FPPS_HEARTBEAT_TIMEOUT_SECS as i64
        })
        .unwrap_or(false);
    let latency_ok = node
        .response_time_ms
        .map(|rt| rt < FPPS_LATENCY_THRESHOLD_MS)
        .unwrap_or(true);

    reachable && score_ok && failures_ok && heartbeat_ok && latency_ok
}

/// Detect actual DB internal port at runtime.
/// Source: journal Addendum 3 §12.0 — compose says 5433 but actual may be 5432
/// SC-PORT-001: DATABASE_URL port MUST match actual internal port
pub async fn detect_db_port(container: &str) -> Result<u16, IgnitionError> {
    let (stdout, _, code) = podman::podman_exec(
        container,
        &["psql", "-U", "postgres", "-tAc", "SHOW port"],
        Duration::from_secs(5),
    )
    .await?;

    if code != 0 {
        return Err(IgnitionError::DatabaseError("Cannot detect DB port".into()));
    }

    stdout
        .trim()
        .parse::<u16>()
        .map_err(|e| IgnitionError::ParseError(format!("DB port parse: {}", e)))
}

/// Validate a container against its health check type with polling.
/// Source: capture-ignition.sh:177-237
/// Polls every 2s until timeout.
pub async fn validate_container(
    name: &str,
    check: &HealthCheckType,
    timeout: Duration,
) -> Result<bool, IgnitionError> {
    let start = Instant::now();
    let poll_interval = Duration::from_secs(2);

    loop {
        let result = match check {
            HealthCheckType::TcpPort(port) => check_port(name, *port, Duration::from_secs(3)).await,
            HealthCheckType::PgIsReady => check_postgres(name, Duration::from_secs(3)).await,
            HealthCheckType::Running => check_running(name).await,
            HealthCheckType::Http(url) => check_http(url, Duration::from_secs(5)).await,
        };

        match result {
            Ok(true) => {
                debug!("[Health] {} passed {:?} check", name, check);
                return Ok(true);
            }
            _ => {
                if start.elapsed() >= timeout {
                    warn!(
                        "[Health] {} failed {:?} check after {:?}",
                        name, check, timeout
                    );
                    return Ok(false);
                }
                tokio::time::sleep(poll_interval).await;
            }
        }
    }
}

/// Count pattern occurrences in a string (for log-based verification).
pub fn count_pattern(text: &str, pattern: &str) -> u32 {
    text.matches(pattern).count() as u32
}

// ═══════════════════════════════════════════════════════════════════════════════
// ADAPTIVE TIMEOUT INTEGRATION (W2)
// Source: build_oracle.rs (F# BuildHistory EMA bridge)
// SC-IGNITE-005, SC-OPT-002, SC-BOOT-006
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute the adaptive poll interval based on the expected total duration.
///
/// Short-lived containers don't need aggressive polling; very long builds
/// would generate excessive log noise with a 1 s interval.
///
/// | Expected duration | Poll interval |
/// |-------------------|---------------|
/// | < 30 s            | 1 s           |
/// | 30 s – 120 s      | 2 s           |
/// | > 120 s           | 5 s           |
///
/// ## STAMP: SC-OPT-002 (exponential backoff), SC-IGNITE-005 (EMA estimation)
#[allow(dead_code)]
pub fn adaptive_poll_interval(expected_ms: u64) -> Duration {
    match expected_ms {
        0..=29_999 => Duration::from_secs(1),
        30_000..=119_999 => Duration::from_secs(2),
        _ => Duration::from_secs(5),
    }
}

/// Validate a container using an EMA-derived adaptive timeout from BuildHistory.db.
///
/// The function calls `build_oracle::load_timeouts()` to obtain per-container
/// adaptive timeouts computed from the F# `build_ema` SQLite table.  When no
/// EMA record exists for the container (first boot, or the oracle DB is absent),
/// `base_timeout` is used unchanged, ensuring graceful degradation.
///
/// The resolved timeout is then forwarded to the existing [`validate_container`]
/// implementation so all probing logic stays in one place.
///
/// ## STAMP: SC-IGNITE-005, SC-BOOT-006
///
/// ## Arguments
/// - `name`: Container name (e.g. `"indrajaal-ex-app-1"`)
/// - `check`: Health check type to execute
/// - `base_timeout`: Fallback duration when no EMA data is available
///
/// ## Returns
/// `Ok(true)` when the check passes within the resolved timeout.
#[allow(dead_code)]
pub async fn validate_container_adaptive(
    name: &str,
    check: &HealthCheckType,
    base_timeout: Duration,
) -> Result<bool, IgnitionError> {
    // Load all adaptive timeouts from BuildHistory EMA (never fails — returns
    // empty map when DB is absent or unreadable).
    let timeouts = build_oracle::load_timeouts();

    let (resolved, source) = if let Some(at) = timeouts.get(name) {
        let ms = at.ema_timeout_ms;
        info!(
            "[Health] {} — using adaptive timeout {}ms (EMA source, base {}ms)",
            name,
            ms,
            base_timeout.as_millis()
        );
        (Duration::from_millis(ms), at.source)
    } else {
        info!(
            "[Health] {} — no EMA data, using fixed timeout {}ms",
            name,
            base_timeout.as_millis()
        );
        (base_timeout, TimeoutSource::Default)
    };

    debug!(
        "[Health] {} — timeout source: {:?}, resolved: {:?}",
        name, source, resolved
    );

    validate_container(name, check, resolved).await
}

/// Validate a container using exponential back-off polling.
///
/// Instead of polling at a fixed 2 s interval, this function walks through the
/// `BACKOFF_INTERVALS` constant (100 ms → 200 ms → … → 3200 ms → 5000 ms) and
/// then holds at the final interval until the outer timeout expires.
///
/// This matches the `SC-OPT-002` mandate:
/// > "Health check exponential backoff (100ms → 3200ms)"
///
/// ## STAMP: SC-OPT-002, SC-BOOT-006, SC-IGNITE-003
///
/// ## Arguments
/// - `name`: Container name
/// - `check`: Health check type
/// - `timeout`: Maximum total duration before giving up
///
/// ## Returns
/// `Ok(true)` when the check passes within the timeout.
#[allow(dead_code)]
pub async fn validate_with_backoff(
    name: &str,
    check: &HealthCheckType,
    timeout: Duration,
) -> Result<bool, IgnitionError> {
    let start = Instant::now();
    let mut backoff_idx = 0usize;

    loop {
        let result = match check {
            HealthCheckType::TcpPort(port) => {
                check_port(name, *port, Duration::from_secs(3)).await
            }
            HealthCheckType::PgIsReady => check_postgres(name, Duration::from_secs(3)).await,
            HealthCheckType::Running => check_running(name).await,
            HealthCheckType::Http(url) => check_http(url, Duration::from_secs(5)).await,
        };

        match result {
            Ok(true) => {
                debug!(
                    "[Health] {} passed {:?} check after {:?} (backoff)",
                    name,
                    check,
                    start.elapsed()
                );
                return Ok(true);
            }
            _ => {
                if start.elapsed() >= timeout {
                    warn!(
                        "[Health] {} failed {:?} check after {:?} (backoff exhausted)",
                        name, check, timeout
                    );
                    return Ok(false);
                }

                // Pick the current back-off interval, hold at the last entry
                // once the schedule is exhausted.
                let interval_ms = BACKOFF_INTERVALS
                    .get(backoff_idx)
                    .copied()
                    .unwrap_or(*BACKOFF_INTERVALS.last().unwrap_or(&5000));

                debug!(
                    "[Health] {} back-off sleep {}ms (step {})",
                    name, interval_ms, backoff_idx
                );

                tokio::time::sleep(Duration::from_millis(interval_ms)).await;

                // Advance through the schedule until the last entry.
                if backoff_idx + 1 < BACKOFF_INTERVALS.len() {
                    backoff_idx += 1;
                }
            }
        }
    }
}

/// Run the FPPS 5-method health orchestra for a container and return the
/// full [`HealthConsensus`] result.
///
/// This is a thin bridge that converts the `(container, port)` pair into
/// the richer `HealthCheckType`-parameterised call expected by
/// [`health_orchestra::check_consensus`].
///
/// The port is used for the `PortOpen` (TCP) method only; the
/// `ServiceEndpoint` method defaults to a `TcpPort` probe on the same port
/// so that containers that do not expose HTTP still participate in all 5
/// methods.
///
/// ## STAMP
/// - SC-SIL4-006: 2oo3 voting MANDATORY for safety-critical decisions
/// - SC-VAL-003: FPPS consensus required for health validation
/// - Omega-5: Validation Consensus — 5-Method FPPS MUST agree
///
/// ## Arguments
/// - `container`: Container name
/// - `port`: Primary service port (used for `PortOpen` and `ServiceEndpoint`)
///
/// ## Returns
/// `Ok(HealthConsensus)` always — the orchestra itself never hard-fails.
#[allow(dead_code)]
pub async fn check_health_orchestra(
    container: &str,
    port: u16,
) -> Result<HealthConsensus, IgnitionError> {
    info!(
        "[Health] Starting FPPS health orchestra for {} on port {}",
        container, port
    );

    let service_check = HealthCheckType::TcpPort(port);
    let consensus = health_orchestra::check_consensus(container, port, &service_check).await;

    info!(
        "[Health] Orchestra result for {}: {}/{} methods agreed, consensus_reached={}",
        container, consensus.agreed, consensus.total, consensus.consensus_reached
    );

    Ok(consensus)
}

// ═══════════════════════════════════════════════════════════════════════════════
// UNIT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    // ── adaptive_poll_interval ─────────────────────────────────────────────────

    #[test]
    fn test_poll_interval_short() {
        // < 30 s → 1 s
        assert_eq!(adaptive_poll_interval(0), Duration::from_secs(1));
        assert_eq!(adaptive_poll_interval(15_000), Duration::from_secs(1));
        assert_eq!(adaptive_poll_interval(29_999), Duration::from_secs(1));
    }

    #[test]
    fn test_poll_interval_medium() {
        // 30 s – 119 s → 2 s
        assert_eq!(adaptive_poll_interval(30_000), Duration::from_secs(2));
        assert_eq!(adaptive_poll_interval(60_000), Duration::from_secs(2));
        assert_eq!(adaptive_poll_interval(119_999), Duration::from_secs(2));
    }

    #[test]
    fn test_poll_interval_long() {
        // ≥ 120 s → 5 s
        assert_eq!(adaptive_poll_interval(120_000), Duration::from_secs(5));
        assert_eq!(adaptive_poll_interval(300_000), Duration::from_secs(5));
        assert_eq!(adaptive_poll_interval(u64::MAX), Duration::from_secs(5));
    }

    // ── count_pattern (existing, regression guard) ────────────────────────────

    #[test]
    fn test_count_pattern_basic() {
        assert_eq!(count_pattern("hello world hello", "hello"), 2);
        assert_eq!(count_pattern("no match", "xyz"), 0);
        assert_eq!(count_pattern("", "pat"), 0);
    }

    #[test]
    fn test_count_pattern_overlapping() {
        // `str::matches` does not count overlapping patterns — confirm expected
        // behaviour is non-overlapping.
        assert_eq!(count_pattern("aaa", "aa"), 1);
    }

    // ── validate_with_backoff (unit-level, no I/O) ────────────────────────────
    // These tests verify the backoff schedule constant shape without spawning
    // podman processes.

    #[test]
    fn test_backoff_intervals_non_empty() {
        assert!(!BACKOFF_INTERVALS.is_empty(), "BACKOFF_INTERVALS must have at least one entry");
    }

    #[test]
    fn test_backoff_intervals_monotone() {
        // The schedule MUST be non-decreasing (each step is ≥ the previous).
        for window in BACKOFF_INTERVALS.windows(2) {
            assert!(
                window[1] >= window[0],
                "BACKOFF_INTERVALS[{}] < BACKOFF_INTERVALS[{}]: {} < {}",
                1,
                0,
                window[1],
                window[0]
            );
        }
    }

    #[test]
    fn test_backoff_first_interval_fast() {
        // First back-off interval must be ≤ 200 ms (SC-OPT-002 intent).
        assert!(
            BACKOFF_INTERVALS[0] <= 200,
            "First backoff interval should be ≤ 200ms, got {}",
            BACKOFF_INTERVALS[0]
        );
    }

    #[test]
    fn test_backoff_last_interval_bounded() {
        // The largest backoff step must not exceed 10 s (avoidance of livelock).
        let max = *BACKOFF_INTERVALS.last().unwrap();
        assert!(
            max <= 10_000,
            "Last backoff interval must be ≤ 10 000ms, got {}",
            max
        );
    }

    // ── check_quorum regression ────────────────────────────────────────────────

    #[test]
    fn test_quorum_2oo3() {
        // 2-out-of-3 (floor(3/2)+1 = 2)
        assert!(check_quorum(2, 3));
        assert!(check_quorum(3, 3));
        assert!(!check_quorum(1, 3));
    }

    #[test]
    fn test_quorum_3oo5() {
        // floor(5/2)+1 = 3
        assert!(check_quorum(3, 5));
        assert!(check_quorum(5, 5));
        assert!(!check_quorum(2, 5));
    }

    #[test]
    fn test_quorum_zero_total() {
        // Edge case: 0 nodes → threshold=1 → never pass with 0 healthy
        assert!(!check_quorum(0, 0));
    }
}
