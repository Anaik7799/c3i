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

    #[error("Internal error: {0}")]
    InternalError(String),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_display_podman_exec() {
        let err = IgnitionError::PodmanExec("connection refused".into());
        assert_eq!(
            err.to_string(),
            "Podman execution failed: connection refused"
        );
    }

    #[test]
    fn test_display_container_not_found() {
        let err = IgnitionError::ContainerNotFound("indrajaal-db-prod".into());
        assert_eq!(err.to_string(), "Container not found: indrajaal-db-prod");
    }

    #[test]
    fn test_display_timeout() {
        let err = IgnitionError::Timeout("podman inspect timed out after 5s".into());
        assert!(err.to_string().contains("timed out"));
    }

    #[test]
    fn test_display_quorum_not_achieved() {
        let err = IgnitionError::QuorumNotAchieved {
            healthy: 1,
            total: 3,
            required: 2,
        };
        assert_eq!(err.to_string(), "Quorum not achieved: 1/3 (need 2)");
    }

    #[test]
    fn test_display_bist_failed() {
        let err = IgnitionError::BistFailed {
            three_sigma_ms: 150.5,
            threshold_ms: 100.0,
        };
        let s = err.to_string();
        assert!(s.contains("150.5"));
        assert!(s.contains("100.0"));
    }

    #[test]
    fn test_display_elf_mismatch() {
        let err = IgnitionError::ElfMismatch {
            expected: "musl".into(),
            found: "glibc".into(),
            path: "/app/_build/zenoh_nif.so".into(),
        };
        let s = err.to_string();
        assert!(s.contains("musl"));
        assert!(s.contains("glibc"));
        assert!(s.contains("zenoh_nif.so"));
    }

    #[test]
    fn test_display_consensus_not_reached() {
        let err = IgnitionError::ConsensusNotReached {
            agreed: 2,
            total: 5,
            required: 3,
        };
        assert_eq!(
            err.to_string(),
            "Health orchestra consensus failed: 2/5 methods agree (need 3)"
        );
    }

    #[test]
    fn test_display_recovery_failed() {
        let err = IgnitionError::RecoveryFailed {
            container: "cepaf-bridge".into(),
            reason: "NIF compilation error".into(),
        };
        assert_eq!(
            err.to_string(),
            "Recovery failed for cepaf-bridge: NIF compilation error"
        );
    }

    #[test]
    fn test_io_error_conversion() {
        let io_err = std::io::Error::new(std::io::ErrorKind::NotFound, "file missing");
        let err: IgnitionError = io_err.into();
        assert!(err.to_string().contains("file missing"));
    }

    #[test]
    fn test_all_variants_are_debug_printable() {
        // Verify Debug impl works for all variants (thiserror generates this)
        let variants: Vec<IgnitionError> = vec![
            IgnitionError::PodmanExec("test".into()),
            IgnitionError::ContainerNotFound("test".into()),
            IgnitionError::NetworkNotFound("test".into()),
            IgnitionError::Timeout("test".into()),
            IgnitionError::HealthCheckFailed("test".into()),
            IgnitionError::PreflightFailed("test".into()),
            IgnitionError::LaunchFailed("test".into()),
            IgnitionError::BuildFailed("test".into()),
            IgnitionError::DatabaseError("test".into()),
            IgnitionError::ParseError("test".into()),
            IgnitionError::SocketNotFound("test".into()),
            IgnitionError::NifValidationFailed("test".into()),
            IgnitionError::SubstrateContaminated("test".into()),
            IgnitionError::BuildOracleError("test".into()),
            IgnitionError::SqliteError("test".into()),
            IgnitionError::InternalError("test".into()),
        ];
        for v in &variants {
            let debug = format!("{:?}", v);
            assert!(!debug.is_empty());
            let display = format!("{}", v);
            assert!(!display.is_empty());
        }
    }
}
