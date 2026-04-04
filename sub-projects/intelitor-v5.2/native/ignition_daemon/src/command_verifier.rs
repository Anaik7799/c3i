//! # Command Verifier
//! Wave 3 — Verifies command execution results.
//! Source: F# CommandVerifier.fs (461 lines)

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommandResult {
    pub command: String,
    pub exit_code: i32,
    pub stdout: String,
    pub stderr: String,
    pub duration_ms: u64,
    pub verified: bool,
}

pub fn verify_exit_code(result: &CommandResult) -> bool {
    result.exit_code == 0
}

pub fn verify_no_stderr(result: &CommandResult) -> bool {
    result.stderr.is_empty()
}

pub fn verify_contains(result: &CommandResult, expected: &str) -> bool {
    result.stdout.contains(expected)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_verify_success() {
        let r = CommandResult {
            command: "ls".into(),
            exit_code: 0,
            stdout: "file.txt".into(),
            stderr: "".into(),
            duration_ms: 10,
            verified: false,
        };
        assert!(verify_exit_code(&r));
        assert!(verify_no_stderr(&r));
        assert!(verify_contains(&r, "file"));
    }

    #[test]
    fn test_verify_failure() {
        let r = CommandResult {
            command: "ls".into(),
            exit_code: 1,
            stdout: "".into(),
            stderr: "not found".into(),
            duration_ms: 10,
            verified: false,
        };
        assert!(!verify_exit_code(&r));
        assert!(!verify_no_stderr(&r));
    }
}
