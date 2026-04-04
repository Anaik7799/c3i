//! # Audit Log
//! Immutable audit trail for mesh operations.
//! Source: F# CrmAuditLog.fs (416 lines)
//!
//! ## STAMP: SC-AUDIT-001 to SC-AUDIT-004, SC-SAFETY-003 (complete audit trail to Immutable Register)
//! ## Fractal Position: L4-System (Audit / Compliance)

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditEntry {
    pub id: String,
    pub timestamp: DateTime<Utc>,
    pub actor: String,
    pub action: String,
    pub target: String,
    pub result: AuditResult,
    pub details: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AuditResult {
    Success,
    Failure(String),
    Skipped(String),
}

/// Create a new audit entry with a generated UUID and current timestamp.
pub fn create_entry(
    actor: &str,
    action: &str,
    target: &str,
    result: AuditResult,
    details: &str,
) -> AuditEntry {
    AuditEntry {
        id: uuid::Uuid::new_v4().to_string(),
        timestamp: Utc::now(),
        actor: actor.into(),
        action: action.into(),
        target: target.into(),
        result,
        details: details.into(),
    }
}

/// Format an audit entry as a single human-readable log line.
pub fn format_entry(entry: &AuditEntry) -> String {
    let status = match &entry.result {
        AuditResult::Success => "SUCCESS",
        AuditResult::Failure(_) => "FAILURE",
        AuditResult::Skipped(_) => "SKIPPED",
    };
    format!(
        "[{}] {} {} {} -> {} ({})",
        entry.timestamp.format("%H:%M:%S"),
        entry.actor,
        entry.action,
        entry.target,
        status,
        entry.details
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_entry() {
        let e = create_entry(
            "operator",
            "start",
            "db-prod",
            AuditResult::Success,
            "OK",
        );
        assert_eq!(e.actor, "operator");
        assert_eq!(e.action, "start");
        assert_eq!(e.target, "db-prod");
        assert!(matches!(e.result, AuditResult::Success));
        assert!(!e.id.is_empty(), "UUID must be non-empty");
    }

    #[test]
    fn test_format_entry() {
        let e = create_entry(
            "test",
            "verify",
            "mesh",
            AuditResult::Failure("timeout".into()),
            "10s",
        );
        let s = format_entry(&e);
        assert!(s.contains("FAILURE"), "formatted line must contain FAILURE");
        assert!(s.contains("verify"), "formatted line must contain action");
        assert!(s.contains("mesh"), "formatted line must contain target");
    }
}
