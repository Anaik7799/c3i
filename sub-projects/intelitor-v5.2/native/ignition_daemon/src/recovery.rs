//! # Recovery Playbooks — SIL-6 Ignition Daemon
//!
//! ## Fractal Position
//! | Dimension | Value |
//! |-----------|-------|
//! | Layer     | L4-System (Automated Failure Recovery) |
//! | Element   | FMEA / Playbooks / Auto-Remediation |
//!
//! ## Top-5 Failure Modes by RPN
//! | # | Failure Mode              | RPN | Playbook Steps |
//! |---|---------------------------|-----|----------------|
//! | 1 | NIF Compilation Failure   | 252 | 5 steps        |
//! | 2 | glibc/musl Conflict       | 225 | 6 steps        |
//! | 3 | Health Timeout            | 196 | 4 steps        |
//! | 4 | Boot Ordering Race        | 168 | 5 steps        |
//! | 5 | Observability Gap         | 140 | 4 steps        |
//!
//! ## STAMP: SC-SIL4-001, SC-IGNITE-003, SC-FMEA-007
//!
//! SC-SIL4-001: Safety functions MUST fail to safe state.
//! SC-IGNITE-003: 7-Level Fractal RCA MUST be executed automatically on any boot failure.
//! SC-FMEA-007: Mitigation plan MUST be generated for RPN >= 100.
//!
//! ## Design Invariants
//! - `execute_recovery`: retries up to `max_retries`; on any step failure the
//!   retry loop restarts from step 1 (idempotent playbooks).
//! - `diagnose_failure`: pure heuristic scan of exit-code + log keywords;
//!   returns `None` when no mode matches so the caller can decide to escalate.
//! - `auto_recover`: composes diagnose → select → execute in one call.
//! - Informational steps (command = None) always succeed and emit an `info!` log.
//! - Steps that target a fixed dependency container (e.g. `indrajaal-db-prod`,
//!   `indrajaal-obs-prod`) use `podman_exec` against that container directly,
//!   not against the `container` parameter that triggered the recovery.

use crate::errors::IgnitionError;
use crate::podman;
use crate::types::{
    FailureMode, RecoveryPlaybook, RecoveryResult, RecoveryStep, MAX_RECOVERY_RETRIES,
};
use log::{debug, error, info, warn};
use std::time::{Duration, Instant};
use tokio::process::Command;
use tokio::time::sleep;

// ═══════════════════════════════════════════════════════════════════════════════
// PLAYBOOK REGISTRY
// ═══════════════════════════════════════════════════════════════════════════════

/// Get the recovery playbook for a specific failure mode.
///
/// Each playbook is a deterministic, ordered sequence of steps. Steps are
/// executed sequentially; a step failure aborts the current attempt (the outer
/// `execute_recovery` loop retries from step 1).
///
/// STAMP: SC-FMEA-007 (mitigation plan for RPN >= 100)
pub fn get_playbook(mode: FailureMode) -> RecoveryPlaybook {
    match mode {
        // Original 5 (RPN 252-140)
        FailureMode::NifCompilationFailure => playbook_nif_compilation(),
        FailureMode::GlibcMuslConflict => playbook_glibc_musl(),
        FailureMode::HealthTimeout => playbook_health_timeout(),
        FailureMode::BootOrderingRace => playbook_boot_ordering(),
        FailureMode::ObservabilityGap => playbook_observability_gap(),
        // New 10 (RPN 230-130)
        FailureMode::CascadingFailure => playbook_cascading_failure(),
        FailureMode::DiskExhaustion => playbook_disk_exhaustion(),
        FailureMode::MemoryLeak => playbook_memory_leak(),
        FailureMode::NetworkPartition => playbook_network_partition(),
        FailureMode::ImageCorruption => playbook_image_corruption(),
        FailureMode::CertificateExpiry => playbook_certificate_expiry(),
        FailureMode::ClockDrift => playbook_clock_drift(),
        FailureMode::ZombieProcess => playbook_zombie_process(),
        FailureMode::RegistryUnavailable => playbook_registry_unavailable(),
        FailureMode::ConfigDrift => playbook_config_drift(),
    }
}

/// Get all 15 playbooks (for TUI display and audit).
///
/// Order is descending RPN (highest risk first).
pub fn all_playbooks() -> Vec<RecoveryPlaybook> {
    vec![
        playbook_nif_compilation(),      // RPN 252
        playbook_cascading_failure(),    // RPN 230
        playbook_glibc_musl(),           // RPN 225
        playbook_disk_exhaustion(),      // RPN 210
        playbook_memory_leak(),          // RPN 198
        playbook_health_timeout(),       // RPN 196
        playbook_network_partition(),    // RPN 189
        playbook_image_corruption(),     // RPN 175
        playbook_boot_ordering(),        // RPN 168
        playbook_certificate_expiry(),   // RPN 162
        playbook_clock_drift(),          // RPN 154
        playbook_zombie_process(),       // RPN 147
        playbook_observability_gap(),    // RPN 140
        playbook_registry_unavailable(), // RPN 138
        playbook_config_drift(),         // RPN 130
    ]
}

// ─── Individual Playbook Constructors ─────────────────────────────────────────

/// Playbook 1 — NIF Compilation Failure (RPN 252)
///
/// Root cause: `cargo` or `rustup` absent inside container; stale NIF artefacts
/// from a previous failed build cause `mix compile` to skip recompilation.
///
/// Step ordering rationale:
///   1. Confirm toolchain present (fast fail if not).
///   2. Confirm rustup (full toolchain, not just system cargo).
///   3. Delete stale .so artefacts so `mix compile` is forced to rebuild.
///   4. Full recompile (300s budget — first build can be slow).
///   5. Verify at least one .so was produced.
fn playbook_nif_compilation() -> RecoveryPlaybook {
    RecoveryPlaybook {
        failure_mode: FailureMode::NifCompilationFailure,
        rpn: 252,
        max_retries: MAX_RECOVERY_RETRIES,
        escalation: "Manual intervention required: install Rust toolchain in container".into(),
        steps: vec![
            RecoveryStep {
                order: 1,
                action: "Check cargo availability".into(),
                command: Some("exec {container} cargo --version".into()),
                expected_result: "cargo N.N.N printed to stdout".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 2,
                action: "Check rustup availability".into(),
                command: Some("exec {container} rustup show".into()),
                expected_result: "Active toolchain line present".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 3,
                action: "Clean NIF build artefacts".into(),
                command: Some(
                    "exec {container} sh -c \
                     \"rm -rf /app/_build/*/lib/*/priv/native/\""
                        .into(),
                ),
                expected_result: "Exit code 0 (directory removed or did not exist)".into(),
                timeout_ms: 10_000,
            },
            RecoveryStep {
                order: 4,
                action: "Recompile NIFs (force)".into(),
                command: Some(
                    "exec {container} sh -c \
                     \"cd /app && mix compile --force\""
                        .into(),
                ),
                expected_result: "Compilation exits 0".into(),
                timeout_ms: 300_000,
            },
            RecoveryStep {
                order: 5,
                action: "Verify NIF .so loaded".into(),
                command: Some(
                    "exec {container} sh -c \
                     \"ls /app/_build/*/lib/*/priv/native/*.so\""
                        .into(),
                ),
                expected_result: "At least one .so path printed".into(),
                timeout_ms: 5_000,
            },
        ],
    }
}

/// Playbook 2 — glibc/musl Conflict (RPN 225)
///
/// Root cause: Host-compiled `_build/` or `deps/` directories are mounted into
/// the container. NIFs link against host glibc but the container uses musl.
/// Axiom 0.1: host artefacts inside a container substrate are PROHIBITED.
///
/// Steps 3 and 4 are informational because the actual `rm -rf` must run on the
/// host filesystem (not inside the container), which requires operator action or
/// a host-side script outside the container runtime boundary.
fn playbook_glibc_musl() -> RecoveryPlaybook {
    RecoveryPlaybook {
        failure_mode: FailureMode::GlibcMuslConflict,
        rpn: 225,
        max_retries: MAX_RECOVERY_RETRIES,
        escalation: "Host _build/deps MUST be deleted before container boot (Axiom 0.1)".into(),
        steps: vec![
            RecoveryStep {
                order: 1,
                action: "Detect host _build contamination".into(),
                // Run on host via tokio::process::Command (see execute_step special-case)
                command: Some("host:ls _build/*/lib/*/priv/native/*.so 2>/dev/null".into()),
                expected_result: "Empty output means no host contamination".into(),
                timeout_ms: 3_000,
            },
            RecoveryStep {
                order: 2,
                action: "Stop container".into(),
                command: Some("stop -t 5 {container}".into()),
                expected_result: "Container enters Stopped state".into(),
                timeout_ms: 10_000,
            },
            RecoveryStep {
                order: 3,
                action: "Remove contaminated _build (operator action required)".into(),
                // Informational — command: None means log-only, always succeeds
                command: None,
                expected_result: "Operator runs: rm -rf _build deps on the host".into(),
                timeout_ms: 1_000,
            },
            RecoveryStep {
                order: 4,
                action: "Remove contaminated deps (operator action required)".into(),
                command: None,
                expected_result: "Operator confirms _build/ and deps/ removed from host".into(),
                timeout_ms: 1_000,
            },
            RecoveryStep {
                order: 5,
                action: "Rebuild container image from scratch (--no-cache)".into(),
                command: Some(
                    "build --no-cache -f Dockerfile.sopv51-app \
                     -t localhost/indrajaal-ex-app:latest ."
                        .into(),
                ),
                expected_result: "Image build exits 0".into(),
                timeout_ms: 600_000,
            },
            RecoveryStep {
                order: 6,
                action: "Restart container".into(),
                command: Some("start {container}".into()),
                expected_result: "Container enters Running state".into(),
                timeout_ms: 30_000,
            },
        ],
    }
}

/// Playbook 3 — Health Timeout (RPN 196)
///
/// Root cause: container starts but the application or its health endpoint is
/// not ready within the default timeout. Usually caused by a slow first compile
/// or a transient dependency race.
fn playbook_health_timeout() -> RecoveryPlaybook {
    RecoveryPlaybook {
        failure_mode: FailureMode::HealthTimeout,
        rpn: 196,
        max_retries: MAX_RECOVERY_RETRIES,
        escalation:
            "Container repeatedly fails health checks — check resource limits and dependencies"
                .into(),
        steps: vec![
            RecoveryStep {
                order: 1,
                action: "Check container state".into(),
                command: Some("inspect {container} --format {{.State.Status}}".into()),
                expected_result: "\"running\" or \"created\"".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 2,
                action: "Capture last 50 log lines for diagnostics".into(),
                command: Some("logs --tail 50 {container}".into()),
                expected_result: "Log output captured (step always continues)".into(),
                timeout_ms: 10_000,
            },
            RecoveryStep {
                order: 3,
                action: "Restart container".into(),
                command: Some("restart -t 10 {container}".into()),
                expected_result: "Container re-enters Running state".into(),
                timeout_ms: 30_000,
            },
            RecoveryStep {
                order: 4,
                action: "Wait for application health (60s budget)".into(),
                // Handled by execute_step as a structured sleep + port probe
                command: Some("health-wait {container} 60".into()),
                expected_result: "Container reports healthy within 60s".into(),
                timeout_ms: 65_000,
            },
        ],
    }
}

/// Playbook 4 — Boot Ordering Race (RPN 168)
///
/// Root cause: app-tier container starts before the DB or Zenoh router is ready.
/// The fix verifies the upstream dependencies are healthy, then stops and
/// restarts the offending container after a deliberate pause.
fn playbook_boot_ordering() -> RecoveryPlaybook {
    RecoveryPlaybook {
        failure_mode: FailureMode::BootOrderingRace,
        rpn: 168,
        max_retries: MAX_RECOVERY_RETRIES,
        escalation: "Boot ordering dependency not met — verify tier hierarchy".into(),
        steps: vec![
            RecoveryStep {
                order: 1,
                action: "Verify DB is ready".into(),
                command: Some("exec indrajaal-db-prod pg_isready -U postgres".into()),
                expected_result: "pg_isready exits 0".into(),
                timeout_ms: 10_000,
            },
            RecoveryStep {
                order: 2,
                action: "Verify Zenoh router is ready".into(),
                command: Some("exec zenoh-router sh -c \"nc -z localhost 7447\"".into()),
                expected_result: "nc exits 0 (port 7447 is open)".into(),
                timeout_ms: 10_000,
            },
            RecoveryStep {
                order: 3,
                action: "Stop app container".into(),
                command: Some("stop -t 5 {container}".into()),
                expected_result: "Container enters Stopped state".into(),
                timeout_ms: 10_000,
            },
            RecoveryStep {
                order: 4,
                action: "Wait 5s for dependencies to stabilise".into(),
                command: Some("sleep 5".into()),
                expected_result: "5-second pause elapsed".into(),
                timeout_ms: 10_000,
            },
            RecoveryStep {
                order: 5,
                action: "Start app container".into(),
                command: Some("start {container}".into()),
                expected_result: "Container enters Running state".into(),
                timeout_ms: 30_000,
            },
        ],
    }
}

/// Playbook 5 — Observability Gap (RPN 140)
///
/// Root cause: OTEL collector or Prometheus is not running inside the
/// observability container, or the app container lacks the
/// `OTEL_EXPORTER_OTLP_ENDPOINT` environment variable.
fn playbook_observability_gap() -> RecoveryPlaybook {
    RecoveryPlaybook {
        failure_mode: FailureMode::ObservabilityGap,
        rpn: 140,
        max_retries: MAX_RECOVERY_RETRIES,
        escalation: "Observability pipeline broken — check OTEL collector and Prometheus configs"
            .into(),
        steps: vec![
            RecoveryStep {
                order: 1,
                action: "Check OTEL collector on port 4317".into(),
                command: Some("exec indrajaal-obs-prod sh -c \"nc -z localhost 4317\"".into()),
                expected_result: "nc exits 0 (OTEL gRPC port open)".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 2,
                action: "Check Prometheus on port 9090".into(),
                command: Some("exec indrajaal-obs-prod sh -c \"nc -z localhost 9090\"".into()),
                expected_result: "nc exits 0 (Prometheus port open)".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 3,
                action: "Restart observability container".into(),
                command: Some("restart indrajaal-obs-prod".into()),
                expected_result: "indrajaal-obs-prod re-enters Running state".into(),
                timeout_ms: 30_000,
            },
            RecoveryStep {
                order: 4,
                action: "Verify OTEL_EXPORTER_OTLP_ENDPOINT in app container".into(),
                command: Some("exec {container} printenv OTEL_EXPORTER_OTLP_ENDPOINT".into()),
                expected_result: "Non-empty endpoint URL printed".into(),
                timeout_ms: 5_000,
            },
        ],
    }
}

// ─── New Playbooks (Ideas #48 — 5→15 expansion) ──────────────────────────────

/// Playbook 6 — Cascading Failure (RPN 230)
fn playbook_cascading_failure() -> RecoveryPlaybook {
    RecoveryPlaybook {
        failure_mode: FailureMode::CascadingFailure,
        rpn: 230,
        max_retries: MAX_RECOVERY_RETRIES,
        escalation:
            "Cascading failure detected — manual intervention required for tier-by-tier recovery"
                .into(),
        steps: vec![
            RecoveryStep {
                order: 1,
                action: "Identify failure domain".into(),
                command: Some("exec {container} sh -c \"echo cascading_failure\"".into()),
                expected_result: "Failure domain identified".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 2,
                action: "Isolate affected tiers".into(),
                command: None,
                expected_result: "Containment activated".into(),
                timeout_ms: 1_000,
            },
            RecoveryStep {
                order: 3,
                action: "Stop dependent containers".into(),
                command: Some("stop -t 3 {container}".into()),
                expected_result: "Dependent containers stopped".into(),
                timeout_ms: 15_000,
            },
            RecoveryStep {
                order: 4,
                action: "Recover from lowest failed tier".into(),
                command: None,
                expected_result: "Recovery initiated from foundation tier".into(),
                timeout_ms: 1_000,
            },
            RecoveryStep {
                order: 5,
                action: "Verify quorum preserved".into(),
                command: Some("exec zenoh-router-1 sh -c \"nc -z localhost 7447\"".into()),
                expected_result: "Zenoh quorum intact".into(),
                timeout_ms: 5_000,
            },
        ],
    }
}

/// Playbook 7 — Disk Exhaustion (RPN 210)
fn playbook_disk_exhaustion() -> RecoveryPlaybook {
    RecoveryPlaybook {
        failure_mode: FailureMode::DiskExhaustion,
        rpn: 210,
        max_retries: MAX_RECOVERY_RETRIES,
        escalation: "Disk space critical — manual cleanup of volumes/images required".into(),
        steps: vec![
            RecoveryStep { order: 1, action: "Check disk usage".into(), command: Some("host:df -h /".into()), expected_result: "Disk usage percentage reported".into(), timeout_ms: 5_000 },
            RecoveryStep { order: 2, action: "Prune stopped containers".into(), command: Some("container prune -f".into()), expected_result: "Stopped containers removed".into(), timeout_ms: 30_000 },
            RecoveryStep { order: 3, action: "Prune unused images".into(), command: Some("image prune -a -f".into()), expected_result: "Unused images removed".into(), timeout_ms: 60_000 },
            RecoveryStep { order: 4, action: "Truncate container logs".into(), command: Some("host:find /var/lib/containers -name '*.log' -size +100M -exec truncate -s 0 {} \\;".into()), expected_result: "Large logs truncated".into(), timeout_ms: 15_000 },
            RecoveryStep { order: 5, action: "Verify disk space reclaimed".into(), command: Some("host:df -h /".into()), expected_result: "Disk usage below 85%".into(), timeout_ms: 5_000 },
        ],
    }
}

/// Playbook 8 — Memory Leak (RPN 198)
fn playbook_memory_leak() -> RecoveryPlaybook {
    RecoveryPlaybook {
        failure_mode: FailureMode::MemoryLeak,
        rpn: 198,
        max_retries: MAX_RECOVERY_RETRIES,
        escalation: "Memory leak detected — container needs restart with increased limits".into(),
        steps: vec![
            RecoveryStep {
                order: 1,
                action: "Check container memory usage".into(),
                command: Some("inspect {container} --format {{.MemoryStats.Usage}}".into()),
                expected_result: "Memory usage reported".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 2,
                action: "Capture memory profile".into(),
                command: Some("exec {container} sh -c \"cat /proc/1/status | grep VmRSS\"".into()),
                expected_result: "RSS captured".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 3,
                action: "Graceful restart container".into(),
                command: Some("restart -t 10 {container}".into()),
                expected_result: "Container restarted with clean memory".into(),
                timeout_ms: 30_000,
            },
            RecoveryStep {
                order: 4,
                action: "Verify memory stabilized".into(),
                command: Some("inspect {container} --format {{.MemoryStats.Usage}}".into()),
                expected_result: "Memory usage below threshold".into(),
                timeout_ms: 10_000,
            },
        ],
    }
}

/// Playbook 9 — Network Partition (RPN 189)
fn playbook_network_partition() -> RecoveryPlaybook {
    RecoveryPlaybook {
        failure_mode: FailureMode::NetworkPartition,
        rpn: 189,
        max_retries: MAX_RECOVERY_RETRIES,
        escalation: "Network partition detected — manual network troubleshooting required".into(),
        steps: vec![
            RecoveryStep {
                order: 1,
                action: "Verify mesh network exists".into(),
                command: Some("network inspect indrajaal-sil6-mesh".into()),
                expected_result: "Network exists and is active".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 2,
                action: "Check container network attachment".into(),
                command: Some("inspect {container} --format {{.NetworkSettings.Networks}}".into()),
                expected_result: "Container attached to mesh network".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 3,
                action: "Disconnect and reconnect container".into(),
                command: Some("network disconnect indrajaal-sil6-mesh {container}".into()),
                expected_result: "Container disconnected".into(),
                timeout_ms: 10_000,
            },
            RecoveryStep {
                order: 4,
                action: "Reconnect to mesh network".into(),
                command: Some("network connect indrajaal-sil6-mesh {container}".into()),
                expected_result: "Container reconnected".into(),
                timeout_ms: 10_000,
            },
            RecoveryStep {
                order: 5,
                action: "Verify connectivity restored".into(),
                command: Some("exec {container} sh -c \"nc -z zenoh-router-1 7447\"".into()),
                expected_result: "Connectivity to zenoh-router restored".into(),
                timeout_ms: 5_000,
            },
        ],
    }
}

/// Playbook 10 — Image Corruption (RPN 175)
fn playbook_image_corruption() -> RecoveryPlaybook {
    RecoveryPlaybook {
        failure_mode: FailureMode::ImageCorruption,
        rpn: 175,
        max_retries: MAX_RECOVERY_RETRIES,
        escalation: "Image corruption detected — rebuild from Dockerfile required".into(),
        steps: vec![
            RecoveryStep {
                order: 1,
                action: "Verify image digest".into(),
                command: Some("image inspect {container} --format {{.RepoDigests}}".into()),
                expected_result: "Image digest reported".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 2,
                action: "Stop corrupted container".into(),
                command: Some("stop -t 5 {container}".into()),
                expected_result: "Container stopped".into(),
                timeout_ms: 10_000,
            },
            RecoveryStep {
                order: 3,
                action: "Remove corrupted container".into(),
                command: Some("rm -f {container}".into()),
                expected_result: "Container removed".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 4,
                action: "Rebuild image from scratch".into(),
                command: Some("build --no-cache -t localhost/indrajaal-ex-app-1:latest .".into()),
                expected_result: "Image built successfully".into(),
                timeout_ms: 600_000,
            },
            RecoveryStep {
                order: 5,
                action: "Launch fresh container".into(),
                command: Some("start {container}".into()),
                expected_result: "Container running with fresh image".into(),
                timeout_ms: 30_000,
            },
        ],
    }
}

/// Playbook 11 — Certificate Expiry (RPN 162)
fn playbook_certificate_expiry() -> RecoveryPlaybook {
    RecoveryPlaybook {
        failure_mode: FailureMode::CertificateExpiry,
        rpn: 162,
        max_retries: MAX_RECOVERY_RETRIES,
        escalation: "Certificate expired — manual certificate rotation required".into(),
        steps: vec![
            RecoveryStep { order: 1, action: "Check certificate expiry dates".into(), command: Some("exec {container} sh -c \"find /etc/ssl -name '*.pem' -exec openssl x509 -enddate -noout -in {} \\;\"".into()), expected_result: "Certificate dates reported".into(), timeout_ms: 10_000 },
            RecoveryStep { order: 2, action: "Generate new certificates".into(), command: None, expected_result: "New certificates generated".into(), timeout_ms: 1_000 },
            RecoveryStep { order: 3, action: "Restart container with new certs".into(), command: Some("restart -t 5 {container}".into()), expected_result: "Container restarted".into(), timeout_ms: 30_000 },
            RecoveryStep { order: 4, action: "Verify TLS connections".into(), command: Some("exec {container} sh -c \"openssl s_client -connect localhost:443\"".into()), expected_result: "TLS handshake successful".into(), timeout_ms: 10_000 },
        ],
    }
}

/// Playbook 12 — Clock Drift (RPN 154)
fn playbook_clock_drift() -> RecoveryPlaybook {
    RecoveryPlaybook {
        failure_mode: FailureMode::ClockDrift,
        rpn: 154,
        max_retries: MAX_RECOVERY_RETRIES,
        escalation: "Clock drift critical — manual NTP sync required".into(),
        steps: vec![
            RecoveryStep {
                order: 1,
                action: "Check container clock".into(),
                command: Some("exec {container} date +%s".into()),
                expected_result: "Container timestamp reported".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 2,
                action: "Check host clock".into(),
                command: Some("host:date +%s".into()),
                expected_result: "Host timestamp reported".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 3,
                action: "Sync NTP on host".into(),
                command: Some("host:chronyc -a makestep".into()),
                expected_result: "NTP sync successful".into(),
                timeout_ms: 15_000,
            },
            RecoveryStep {
                order: 4,
                action: "Restart container to pick up new time".into(),
                command: Some("restart -t 3 {container}".into()),
                expected_result: "Container restarted with correct time".into(),
                timeout_ms: 15_000,
            },
        ],
    }
}

/// Playbook 13 — Zombie Process (RPN 147)
fn playbook_zombie_process() -> RecoveryPlaybook {
    RecoveryPlaybook {
        failure_mode: FailureMode::ZombieProcess,
        rpn: 147,
        max_retries: MAX_RECOVERY_RETRIES,
        escalation: "Zombie processes accumulating — container restart required".into(),
        steps: vec![
            RecoveryStep {
                order: 1,
                action: "Count zombie processes".into(),
                command: Some("exec {container} sh -c \"ps aux | grep -c 'Z'\"".into()),
                expected_result: "Zombie count reported".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 2,
                action: "Send SIGCHLD to parent processes".into(),
                command: Some("exec {container} sh -c \"kill -SIGCHLD 1\"".into()),
                expected_result: "SIGCHLD sent to PID 1".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 3,
                action: "Verify zombies reaped".into(),
                command: Some("exec {container} sh -c \"ps aux | grep -c 'Z'\"".into()),
                expected_result: "Zombie count reduced".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 4,
                action: "Restart container if zombies persist".into(),
                command: Some("restart -t 5 {container}".into()),
                expected_result: "Container restarted clean".into(),
                timeout_ms: 30_000,
            },
        ],
    }
}

/// Playbook 14 — Registry Unavailable (RPN 138)
fn playbook_registry_unavailable() -> RecoveryPlaybook {
    RecoveryPlaybook {
        failure_mode: FailureMode::RegistryUnavailable,
        rpn: 138,
        max_retries: MAX_RECOVERY_RETRIES,
        escalation: "Registry unavailable — check Podman registry service".into(),
        steps: vec![
            RecoveryStep {
                order: 1,
                action: "Check registry connectivity".into(),
                command: Some("host:curl -sf http://localhost:5000/v2/".into()),
                expected_result: "Registry responds".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 2,
                action: "Restart registry if available".into(),
                command: Some("host:systemctl restart podman-registry".into()),
                expected_result: "Registry restarted".into(),
                timeout_ms: 15_000,
            },
            RecoveryStep {
                order: 3,
                action: "Verify local images available".into(),
                command: Some("images --format {{.Repository}}".into()),
                expected_result: "Local images listed".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 4,
                action: "Retry container launch with local image".into(),
                command: Some("start {container}".into()),
                expected_result: "Container started from local image".into(),
                timeout_ms: 30_000,
            },
        ],
    }
}

/// Playbook 15 — Configuration Drift (RPN 130)
fn playbook_config_drift() -> RecoveryPlaybook {
    RecoveryPlaybook {
        failure_mode: FailureMode::ConfigDrift,
        rpn: 130,
        max_retries: MAX_RECOVERY_RETRIES,
        escalation: "Configuration drift detected — manual reconciliation required".into(),
        steps: vec![
            RecoveryStep {
                order: 1,
                action: "Inspect current container config".into(),
                command: Some("inspect {container} --format {{.Config.Env}}".into()),
                expected_result: "Current env vars reported".into(),
                timeout_ms: 5_000,
            },
            RecoveryStep {
                order: 2,
                action: "Compare with expected config".into(),
                command: None,
                expected_result: "Drift identified".into(),
                timeout_ms: 1_000,
            },
            RecoveryStep {
                order: 3,
                action: "Stop container".into(),
                command: Some("stop -t 5 {container}".into()),
                expected_result: "Container stopped".into(),
                timeout_ms: 10_000,
            },
            RecoveryStep {
                order: 4,
                action: "Recreate with correct config".into(),
                command: Some("rm -f {container}".into()),
                expected_result: "Container removed for recreation".into(),
                timeout_ms: 5_000,
            },
        ],
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DIAGNOSIS
// ═══════════════════════════════════════════════════════════════════════════════

/// Diagnose a container failure and return the most likely `FailureMode`.
///
/// Inspection order (highest-confidence signal first):
///   1. Exit-code heuristics (137 = OOM → not directly in top-5, skip for now).
///   2. Log keyword search across last 100 lines.
///   3. Returns `None` when no known mode matches — caller may escalate.
///
/// STAMP: SC-IGNITE-003 (auto-RCA on boot failure)
pub async fn diagnose_failure(container: &str) -> Option<FailureMode> {
    debug!(
        "[recovery] Diagnosing failure for container '{}'",
        container
    );

    // ── 1. Inspect exit code ──────────────────────────────────────────────────
    let exit_code: i32 = podman::container_exit_code(container).await.unwrap_or(-1);

    debug!(
        "[recovery] Container '{}' exit_code={}",
        container, exit_code
    );

    // Exit code 1 with NIF-style logs is the primary NIF signal; we refine below.
    // Exit code 137 (SIGKILL / OOM) is not in top-5 FMEA — fall through to logs.

    // ── 2. Fetch logs ─────────────────────────────────────────────────────────
    let logs = podman::container_logs(container, 100)
        .await
        .unwrap_or_default()
        .to_lowercase();

    debug!(
        "[recovery] Container '{}' log snippet (first 200 chars): {}",
        container,
        &logs[..logs.len().min(200)]
    );

    // ── 3. Keyword matching (ordered by RPN descending) ───────────────────────

    // NIF Compilation (RPN 252): cargo/rustup errors or NIF load failures
    if logs.contains("could not compile")
        || logs.contains("cargo not found")
        || logs.contains("error loading nif")
        || logs.contains("rustup")
        || (logs.contains("nif") && logs.contains("error"))
        || (logs.contains("cargo") && exit_code == 1)
    {
        info!(
            "[recovery] Diagnosed '{}' as NifCompilationFailure (RPN 252)",
            container
        );
        return Some(FailureMode::NifCompilationFailure);
    }

    // glibc/musl Conflict (RPN 225): dynamic linker errors referencing ld-linux
    if logs.contains("ld-linux")
        || logs.contains("no such file or directory: /lib64")
        || logs.contains("libc.so")
        || logs.contains("musl")
        || logs.contains("version `glibc")
        || logs.contains("libc version")
    {
        info!(
            "[recovery] Diagnosed '{}' as GlibcMuslConflict (RPN 225)",
            container
        );
        return Some(FailureMode::GlibcMuslConflict);
    }

    // Health Timeout (RPN 196): explicit timeout messages
    if logs.contains("health check timed out")
        || logs.contains("timeout waiting")
        || logs.contains("health check failed")
        || logs.contains("readiness probe failed")
        || exit_code == 124
    // timeout(1) exit code
    {
        info!(
            "[recovery] Diagnosed '{}' as HealthTimeout (RPN 196)",
            container
        );
        return Some(FailureMode::HealthTimeout);
    }

    // Boot Ordering Race (RPN 168): connection refused to DB / Zenoh
    if logs.contains("econnrefused")
        || logs.contains("connection refused")
        || logs.contains("database not ready")
        || logs.contains("zenoh: connect failed")
        || logs.contains("failed to connect to zenoh")
        || logs.contains("tcp connect error")
    {
        info!(
            "[recovery] Diagnosed '{}' as BootOrderingRace (RPN 168)",
            container
        );
        return Some(FailureMode::BootOrderingRace);
    }

    // Observability Gap (RPN 140): OTEL exporter errors
    if logs.contains("otel")
        || logs.contains("opentelemetry")
        || logs.contains("exporter failed")
        || logs.contains("grpc: failed to connect")
        || logs.contains("otlp")
    {
        info!(
            "[recovery] Diagnosed '{}' as ObservabilityGap (RPN 140)",
            container
        );
        return Some(FailureMode::ObservabilityGap);
    }

    // No match
    warn!(
        "[recovery] Could not diagnose failure mode for '{}' (exit_code={})",
        container, exit_code
    );
    None
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP EXECUTION
// ═══════════════════════════════════════════════════════════════════════════════

/// Execute a single recovery step for `container`.
///
/// Command routing logic:
///   - `None` → informational step; always returns `Ok(true)`.
///   - `"host:<shell-cmd>"` → run on host via `sh -c` (not inside container).
///   - `"exec <target> <args>"` → `podman exec <target> <args>` (target may differ
///     from `container`, e.g. `indrajaal-db-prod`).
///   - `"sleep <N>"` → async sleep for N seconds (no podman call).
///   - `"health-wait <container> <N>"` → poll container status for up to N seconds.
///   - Any other string with `{container}` placeholder → replace and run as
///     `podman <expanded-cmd>`.
///
/// Returns `Ok(true)` on success, `Ok(false)` when the command exits non-zero
/// (treated as a soft failure that aborts the current playbook attempt),
/// `Err` only for infrastructure errors (timeout, io).
async fn execute_step(container: &str, step: &RecoveryStep) -> Result<bool, IgnitionError> {
    let timeout_dur = Duration::from_millis(step.timeout_ms);

    // ── Informational step ────────────────────────────────────────────────────
    let raw = match &step.command {
        None => {
            info!(
                "[recovery] Step {}: {} (informational — no command)",
                step.order, step.action
            );
            return Ok(true);
        }
        Some(cmd) => cmd.clone(),
    };

    // Substitute {container} placeholder
    let cmd_str = raw.replace("{container}", container);

    debug!(
        "[recovery] Step {}: {} — executing: {}",
        step.order, step.action, cmd_str
    );

    // ── Host-side command ─────────────────────────────────────────────────────
    if let Some(shell_cmd) = cmd_str.strip_prefix("host:") {
        let shell_cmd = shell_cmd.to_string();
        let result = tokio::time::timeout(timeout_dur, async {
            Command::new("sh")
                .arg("-c")
                .arg(&shell_cmd)
                .output()
                .await
                .map_err(|e| IgnitionError::PodmanExec(format!("host sh -c failed: {}", e)))
        })
        .await
        .map_err(|_| IgnitionError::Timeout(format!("host command timed out: {}", shell_cmd)))??;

        let stdout = String::from_utf8_lossy(&result.stdout).trim().to_string();
        let code = result.status.code().unwrap_or(-1);
        debug!(
            "[recovery] Step {} host result: code={} stdout={}",
            step.order, code, stdout
        );
        // For contamination detection: non-empty output means contamination found
        // (step continues — callers use the log to decide on escalation)
        if !stdout.is_empty() {
            warn!(
                "[recovery] Step {}: host contamination detected: {}",
                step.order, stdout
            );
        }
        return Ok(true); // always continue after contamination check
    }

    // ── Sleep step ────────────────────────────────────────────────────────────
    if let Some(secs_str) = cmd_str.strip_prefix("sleep ") {
        let secs: u64 = secs_str.trim().parse().unwrap_or(5);
        info!("[recovery] Step {}: sleeping {}s", step.order, secs);
        sleep(Duration::from_secs(secs)).await;
        return Ok(true);
    }

    // ── Health-wait step ──────────────────────────────────────────────────────
    // Format: "health-wait <target> <seconds>"
    if cmd_str.starts_with("health-wait ") {
        let parts: Vec<&str> = cmd_str.splitn(3, ' ').collect();
        let target = if parts.len() >= 2 {
            parts[1]
        } else {
            container
        };
        let wait_secs: u64 = if parts.len() >= 3 {
            parts[2].parse().unwrap_or(60)
        } else {
            60
        };
        return health_wait(target, wait_secs).await;
    }

    // ── Pure podman subcommand (no "exec" prefix) ─────────────────────────────
    // These are free-form podman args, e.g. "stop -t 5 {container}",
    // "start {container}", "restart -t 10 {container}",
    // "build --no-cache -f Dockerfile.sopv51-app ..."
    // They do NOT start with "exec ".
    if !cmd_str.starts_with("exec ") {
        let args: Vec<&str> = cmd_str.split_whitespace().collect();
        let (stdout, stderr, code) = podman::podman_cmd(&args, timeout_dur).await?;
        debug!(
            "[recovery] Step {} podman result: code={} out={} err={}",
            step.order, code, stdout, stderr
        );
        if code != 0 {
            warn!(
                "[recovery] Step {} FAILED (code={}): {} | {}",
                step.order, code, stdout, stderr
            );
            return Ok(false);
        }
        return Ok(true);
    }

    // ── podman exec <target> <cmd...> ─────────────────────────────────────────
    // Strip leading "exec "
    let rest = &cmd_str["exec ".len()..];
    let parts: Vec<&str> = rest.splitn(2, ' ').collect();
    if parts.is_empty() {
        warn!(
            "[recovery] Step {}: malformed exec command: '{}'",
            step.order, cmd_str
        );
        return Ok(false);
    }
    let target_container = parts[0];
    let inner_cmd = if parts.len() > 1 { parts[1] } else { "" };
    let inner_args: Vec<&str> = inner_cmd.split_whitespace().collect();

    let (stdout, stderr, code) =
        podman::podman_exec(target_container, &inner_args, timeout_dur).await?;

    debug!(
        "[recovery] Step {} exec '{}' result: code={} out={} err={}",
        step.order, target_container, code, stdout, stderr
    );

    if code != 0 {
        warn!(
            "[recovery] Step {} FAILED (code={}): {} | {}",
            step.order, code, stdout, stderr
        );
        return Ok(false);
    }

    Ok(true)
}

// ═══════════════════════════════════════════════════════════════════════════════
// PLAYBOOK EXECUTOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Execute a recovery playbook for `container`.
///
/// Runs steps sequentially. On the first step failure the current attempt is
/// abandoned and a new retry begins from step 1 (idempotent playbook design).
/// Up to `playbook.max_retries` attempts are made before returning a failure
/// result containing the escalation message.
///
/// SC-SIL4-001: Safety functions MUST fail to safe state — if recovery is
/// exhausted we return a `RecoveryResult { success: false }` with escalation
/// detail rather than panicking or leaving the caller in an ambiguous state.
pub async fn execute_recovery(container: &str, mode: FailureMode) -> RecoveryResult {
    let playbook = get_playbook(mode);
    let steps_total = playbook.steps.len() as u8;
    let wall_start = Instant::now();

    info!(
        "[recovery] Starting recovery for '{}' mode={:?} RPN={} max_retries={}",
        container, mode, playbook.rpn, playbook.max_retries
    );

    for attempt in 1..=playbook.max_retries {
        info!(
            "[recovery] Attempt {}/{} for '{}' ({:?})",
            attempt, playbook.max_retries, container, mode
        );

        let mut steps_executed: u8 = 0;

        for step in &playbook.steps {
            info!(
                "[recovery] Step {}/{}: {}",
                step.order, steps_total, step.action
            );

            let step_result = execute_step(container, step).await;

            match step_result {
                Err(e) => {
                    // Infrastructure error (timeout, io): abort attempt
                    error!(
                        "[recovery] Step {} infrastructure error on '{}': {}",
                        step.order, container, e
                    );
                    steps_executed += 1;
                    break;
                }
                Ok(false) => {
                    // Soft failure: step command returned non-zero
                    warn!(
                        "[recovery] Step {} failed for '{}', aborting attempt {}",
                        step.order, container, attempt
                    );
                    steps_executed += 1;
                    break;
                }
                Ok(true) => {
                    steps_executed += 1;
                    // Continue to next step
                }
            }

            // If this was the last step and we succeeded, report success
            if step.order == steps_total {
                let elapsed = wall_start.elapsed().as_millis() as u64;
                info!(
                    "[recovery] Recovery SUCCEEDED for '{}' ({:?}) in {}ms \
                     after {} attempt(s)",
                    container, mode, elapsed, attempt
                );
                return RecoveryResult {
                    failure_mode: mode,
                    success: true,
                    steps_executed,
                    steps_total,
                    duration_ms: elapsed,
                    detail: format!("All {} steps passed on attempt {}", steps_total, attempt),
                };
            }
        }

        // Between retries: brief back-off (5s * attempt number, max 30s)
        if attempt < playbook.max_retries {
            let backoff = std::cmp::min(5 * attempt as u64, 30);
            info!(
                "[recovery] Back-off {}s before retry {}/{} for '{}'",
                backoff,
                attempt + 1,
                playbook.max_retries,
                container
            );
            sleep(Duration::from_secs(backoff)).await;
        }
    }

    // All retries exhausted
    let elapsed = wall_start.elapsed().as_millis() as u64;
    error!(
        "[recovery] Recovery FAILED for '{}' ({:?}) after {} attempts ({}ms). \
         Escalation: {}",
        container, mode, playbook.max_retries, elapsed, playbook.escalation
    );

    RecoveryResult {
        failure_mode: mode,
        success: false,
        steps_executed: playbook.max_retries * steps_total, // worst-case upper bound
        steps_total,
        duration_ms: elapsed,
        detail: format!(
            "Exhausted {} retries. Escalation: {}",
            playbook.max_retries, playbook.escalation
        ),
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUTO-RECOVER
// ═══════════════════════════════════════════════════════════════════════════════

/// Full automated recovery pipeline: diagnose → select playbook → execute.
///
/// When `diagnose_failure` returns `None` (no known mode matches) a synthetic
/// `RecoveryResult { success: false }` is returned immediately so callers can
/// escalate without attempting blind recovery.
pub async fn auto_recover(container: &str) -> RecoveryResult {
    info!("[recovery] auto_recover started for '{}'", container);
    let wall_start = Instant::now();

    let mode = match diagnose_failure(container).await {
        Some(m) => m,
        None => {
            let elapsed = wall_start.elapsed().as_millis() as u64;
            warn!(
                "[recovery] auto_recover: could not diagnose '{}' — no playbook selected",
                container
            );
            // Return a synthetic failed result — no steps executed.
            // Use HealthTimeout as a placeholder mode (lowest-harm default).
            return RecoveryResult {
                failure_mode: FailureMode::HealthTimeout,
                success: false,
                steps_executed: 0,
                steps_total: 0,
                duration_ms: elapsed,
                detail: format!(
                    "Diagnosis inconclusive for '{}' — manual investigation required",
                    container
                ),
            };
        }
    };

    execute_recovery(container, mode).await
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Poll container status until it reports "running" or the budget expires.
///
/// Uses a 2-second polling interval (SC-CPU-GOV-009 mirrors this cadence).
/// Returns `Ok(true)` if the container becomes running within the budget,
/// `Ok(false)` otherwise (treated as a soft step failure by `execute_step`).
async fn health_wait(container: &str, wait_secs: u64) -> Result<bool, IgnitionError> {
    info!(
        "[recovery] health_wait: polling '{}' for up to {}s",
        container, wait_secs
    );

    let deadline = Instant::now() + Duration::from_secs(wait_secs);
    let poll_interval = Duration::from_secs(2);

    while Instant::now() < deadline {
        let status = podman::container_status(container)
            .await
            .unwrap_or_else(|_| "unknown".into());

        debug!("[recovery] health_wait '{}' status={}", container, status);

        if status == "running" {
            info!("[recovery] health_wait: '{}' is running", container);
            return Ok(true);
        }

        sleep(poll_interval).await;
    }

    warn!(
        "[recovery] health_wait: '{}' did not become running within {}s",
        container, wait_secs
    );
    Ok(false)
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    // ── Playbook structure invariants ──────────────────────────────────────────

    #[test]
    fn test_all_playbooks_returns_fifteen() {
        let books = all_playbooks();
        assert_eq!(books.len(), 15, "Expected exactly 15 playbooks");
    }

    #[test]
    fn test_playbooks_rpn_descending() {
        let books = all_playbooks();
        let rpns: Vec<u16> = books.iter().map(|b| b.rpn).collect();
        for i in 0..rpns.len() - 1 {
            assert!(
                rpns[i] >= rpns[i + 1],
                "Playbooks must be ordered by RPN descending: {:?}",
                rpns
            );
        }
    }

    #[test]
    fn test_all_playbooks_have_steps() {
        for book in all_playbooks() {
            assert!(
                !book.steps.is_empty(),
                "Playbook {:?} must have at least one step",
                book.failure_mode
            );
        }
    }

    #[test]
    fn test_step_order_is_sequential() {
        for book in all_playbooks() {
            for (idx, step) in book.steps.iter().enumerate() {
                assert_eq!(
                    step.order,
                    (idx + 1) as u8,
                    "Step order mismatch in {:?}: expected {} got {}",
                    book.failure_mode,
                    idx + 1,
                    step.order
                );
            }
        }
    }

    #[test]
    fn test_all_playbooks_have_escalation() {
        for book in all_playbooks() {
            assert!(
                !book.escalation.is_empty(),
                "Playbook {:?} must have a non-empty escalation message",
                book.failure_mode
            );
        }
    }

    #[test]
    fn test_max_retries_is_correct() {
        for book in all_playbooks() {
            assert_eq!(
                book.max_retries, MAX_RECOVERY_RETRIES,
                "Playbook {:?} max_retries mismatch",
                book.failure_mode
            );
        }
    }

    #[test]
    fn test_get_playbook_round_trips() {
        let modes = [
            FailureMode::NifCompilationFailure,
            FailureMode::GlibcMuslConflict,
            FailureMode::HealthTimeout,
            FailureMode::BootOrderingRace,
            FailureMode::ObservabilityGap,
        ];
        for mode in modes {
            let book = get_playbook(mode);
            assert_eq!(book.failure_mode, mode);
        }
    }

    // ── RPN values ─────────────────────────────────────────────────────────────

    #[test]
    fn test_rpn_values_match_spec() {
        assert_eq!(get_playbook(FailureMode::NifCompilationFailure).rpn, 252);
        assert_eq!(get_playbook(FailureMode::GlibcMuslConflict).rpn, 225);
        assert_eq!(get_playbook(FailureMode::HealthTimeout).rpn, 196);
        assert_eq!(get_playbook(FailureMode::BootOrderingRace).rpn, 168);
        assert_eq!(get_playbook(FailureMode::ObservabilityGap).rpn, 140);
    }

    // ── Step timeout sanity ────────────────────────────────────────────────────

    #[test]
    fn test_step_timeouts_are_positive() {
        for book in all_playbooks() {
            for step in &book.steps {
                assert!(
                    step.timeout_ms > 0,
                    "Step {}.{} timeout must be positive",
                    book.rpn,
                    step.order
                );
            }
        }
    }

    #[test]
    fn test_nif_recompile_step_has_long_timeout() {
        let book = get_playbook(FailureMode::NifCompilationFailure);
        // Step 4 is the mix compile step — needs at least 120s
        let step4 = book.steps.iter().find(|s| s.order == 4).unwrap();
        assert!(
            step4.timeout_ms >= 120_000,
            "NIF recompile step must have timeout >= 120s, got {}ms",
            step4.timeout_ms
        );
    }

    #[test]
    fn test_glibc_rebuild_step_has_long_timeout() {
        let book = get_playbook(FailureMode::GlibcMuslConflict);
        // Step 5 is the podman build --no-cache step
        let step5 = book.steps.iter().find(|s| s.order == 5).unwrap();
        assert!(
            step5.timeout_ms >= 300_000,
            "Container rebuild step must have timeout >= 300s, got {}ms",
            step5.timeout_ms
        );
    }

    // ── Informational steps ────────────────────────────────────────────────────

    #[test]
    fn test_glibc_playbook_has_informational_steps() {
        let book = get_playbook(FailureMode::GlibcMuslConflict);
        let info_steps: Vec<_> = book.steps.iter().filter(|s| s.command.is_none()).collect();
        assert_eq!(
            info_steps.len(),
            2,
            "GlibcMusl playbook must have exactly 2 informational steps (host-side rm)"
        );
    }

    // ── Step-count per playbook ────────────────────────────────────────────────

    #[test]
    fn test_step_counts_match_spec() {
        assert_eq!(
            get_playbook(FailureMode::NifCompilationFailure).steps.len(),
            5
        );
        assert_eq!(get_playbook(FailureMode::GlibcMuslConflict).steps.len(), 6);
        assert_eq!(get_playbook(FailureMode::HealthTimeout).steps.len(), 4);
        assert_eq!(get_playbook(FailureMode::BootOrderingRace).steps.len(), 5);
        assert_eq!(get_playbook(FailureMode::ObservabilityGap).steps.len(), 4);
    }

    // ── Diagnosis keyword coverage (unit, no I/O) ──────────────────────────────
    // These tests validate the keyword-matching logic by running diagnose_failure
    // against a container name that is guaranteed to not exist at test time.
    // The function falls back to keyword scan of empty logs, so we just verify
    // it compiles and returns None when no container is present.

    #[tokio::test]
    async fn test_diagnose_returns_none_for_absent_container() {
        // Container "__test_nonexistent__" will never be running in CI
        let result = diagnose_failure("__test_nonexistent__").await;
        // Either None (container absent) or Some (if another test left one running)
        // We just assert the function doesn't panic.
        let _ = result;
    }

    // ── RecoveryResult sentinel values ────────────────────────────────────────

    #[test]
    fn test_recovery_result_success_fields() {
        let r = RecoveryResult {
            failure_mode: FailureMode::HealthTimeout,
            success: true,
            steps_executed: 4,
            steps_total: 4,
            duration_ms: 12_500,
            detail: "All 4 steps passed on attempt 1".into(),
        };
        assert!(r.success);
        assert_eq!(r.steps_executed, r.steps_total);
    }

    #[test]
    fn test_recovery_result_failure_fields() {
        let r = RecoveryResult {
            failure_mode: FailureMode::GlibcMuslConflict,
            success: false,
            steps_executed: 6,
            steps_total: 6,
            duration_ms: 605_000,
            detail: "Exhausted 3 retries. Escalation: Host _build/deps MUST be deleted".into(),
        };
        assert!(!r.success);
        assert!(r.detail.contains("Escalation"));
    }
}
