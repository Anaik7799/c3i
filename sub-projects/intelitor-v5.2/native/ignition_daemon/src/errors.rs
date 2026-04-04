//! # Error Types — SIL-6 Ignition Daemon
//!
//! STAMP: SC-SIL4-001 (Safety functions MUST fail to safe state)
//! All errors are recoverable — the daemon logs and continues or retries.

use thiserror::Error;

#[derive(Error, Debug)]
pub enum IgnitionError {
    #[error("Podman execution failed: {0}")]
    PodmanExec(String),

    #[error("Container not found: {0}")]
    ContainerNotFound(String),

    #[error("Network not found: {0}")]
    NetworkNotFound(String),

    #[error("Operation timed out: {0}")]
    Timeout(String),

    #[error("Health check failed: {0}")]
    HealthCheckFailed(String),

    #[error("Pre-flight check failed: {0}")]
    PreflightFailed(String),

    #[error("Launch failed: {0}")]
    LaunchFailed(String),

    #[error("Build failed: {0}")]
    BuildFailed(String),

    #[error("Database error: {0}")]
    DatabaseError(String),

    #[error("Parse error: {0}")]
    ParseError(String),

    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),

    #[error("Quorum not achieved: {healthy}/{total} (need {required})")]
    QuorumNotAchieved {
        healthy: u32,
        total: u32,
        required: u32,
    },

    #[error("BIST-001 stability check failed: 3σ={three_sigma_ms:.1}ms > {threshold_ms:.1}ms")]
    BistFailed {
        three_sigma_ms: f64,
        threshold_ms: f64,
    },

    #[error("Socket not found: {0}")]
    SocketNotFound(String),

    #[error("FMEA recovery needed: exit_code={exit_code}, container={container}")]
    FmeaRecovery { container: String, exit_code: i32 },

    // ─── W1: NIF Validator + Substrate Guard ───
    #[error("NIF validation failed: {0}")]
    NifValidationFailed(String),

    #[error("Substrate contaminated: {0}")]
    SubstrateContaminated(String),

    #[error("ELF binary mismatch: expected {expected}, found {found} in {path}")]
    ElfMismatch {
        expected: String,
        found: String,
        path: String,
    },

    // ─── W2: Build Oracle ───
    #[error("Build oracle error: {0}")]
    BuildOracleError(String),

    #[error("SQLite error: {0}")]
    SqliteError(String),

    // ─── W3: Health Orchestra ───
    #[error("Health orchestra consensus failed: {agreed}/{total} methods agree (need {required})")]
    ConsensusNotReached {
        agreed: u32,
        total: u32,
        required: u32,
    },

    // ─── W5: Recovery ───
    #[error("Recovery failed for {container}: {reason}")]
    RecoveryFailed { container: String, reason: String },
}
