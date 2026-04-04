/// Allium rule evaluation stubs for C3I Rust tools.
///
/// These implement local GRL rule patterns matching the 13 domains
/// in the RETE-UL rule engine (rule_engine.rs). Phase 1 evaluates
/// locally; Phase 2 will call via MoZ (MCP-over-Zenoh).
use serde::Serialize;

/// Result of an Allium rule evaluation.
#[derive(Debug, Clone, Serialize)]
pub struct RuleResult {
    pub decision: String,
    pub reason: String,
    pub domain: String,
    pub confidence: f64,
}

/// Evaluate preflight gate rules before an operation.
///
/// Maps to the Preflight Gate domain (4 rules):
/// - Block when target is unhealthy
/// - Warn when Zenoh is disconnected
/// - Pass when all checks green
pub fn evaluate_preflight(url_healthy: bool, zenoh_connected: bool) -> RuleResult {
    if !url_healthy {
        return RuleResult {
            decision: "Block".into(),
            reason: "Target URL is not healthy — cannot run tests".into(),
            domain: "PreflightGate".into(),
            confidence: 1.0,
        };
    }

    if !zenoh_connected {
        return RuleResult {
            decision: "Warn".into(),
            reason: "Zenoh not connected — results will not be published to ZMOF".into(),
            domain: "PreflightGate".into(),
            confidence: 0.8,
        };
    }

    RuleResult {
        decision: "Pass".into(),
        reason: "All preflight checks passed".into(),
        domain: "PreflightGate".into(),
        confidence: 1.0,
    }
}

/// Evaluate verification compliance after a test/generation run.
///
/// Maps to the Verify Compliance domain (3 rules):
/// - Compliant: all categories covered, failure rate < 10%
/// - Degraded: some categories missing or failure rate 10-30%
/// - NonCompliant: failure rate > 30%
pub fn evaluate_verify(passed: usize, failed: usize, categories_covered: usize, categories_total: usize) -> RuleResult {
    let total = passed + failed;
    let failure_rate = if total > 0 {
        failed as f64 / total as f64
    } else {
        1.0
    };

    let coverage_ratio = if categories_total > 0 {
        categories_covered as f64 / categories_total as f64
    } else {
        0.0
    };

    if failure_rate <= 0.1 && coverage_ratio >= 0.9 {
        RuleResult {
            decision: "Compliant".into(),
            reason: format!(
                "Failure rate {:.1}%, coverage {:.0}% — within SIL-6 bounds",
                failure_rate * 100.0,
                coverage_ratio * 100.0
            ),
            domain: "VerifyCompliance".into(),
            confidence: 1.0 - failure_rate,
        }
    } else if failure_rate <= 0.3 {
        RuleResult {
            decision: "Degraded".into(),
            reason: format!(
                "Failure rate {:.1}%, coverage {:.0}% — degraded but operational",
                failure_rate * 100.0,
                coverage_ratio * 100.0
            ),
            domain: "VerifyCompliance".into(),
            confidence: 0.7 - failure_rate,
        }
    } else {
        RuleResult {
            decision: "NonCompliant".into(),
            reason: format!(
                "Failure rate {:.1}%, coverage {:.0}% — exceeds tolerance",
                failure_rate * 100.0,
                coverage_ratio * 100.0
            ),
            domain: "VerifyCompliance".into(),
            confidence: 0.3,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_preflight_blocks_on_unhealthy() {
        let result = evaluate_preflight(false, true);
        assert_eq!(result.decision, "Block");
    }

    #[test]
    fn test_preflight_warns_on_no_zenoh() {
        let result = evaluate_preflight(true, false);
        assert_eq!(result.decision, "Warn");
    }

    #[test]
    fn test_preflight_passes_when_healthy() {
        let result = evaluate_preflight(true, true);
        assert_eq!(result.decision, "Pass");
    }

    #[test]
    fn test_verify_compliant() {
        let result = evaluate_verify(95, 5, 10, 10);
        assert_eq!(result.decision, "Compliant");
    }

    #[test]
    fn test_verify_degraded() {
        let result = evaluate_verify(75, 25, 8, 10);
        assert_eq!(result.decision, "Degraded");
    }

    #[test]
    fn test_verify_noncompliant() {
        let result = evaluate_verify(50, 50, 5, 10);
        assert_eq!(result.decision, "NonCompliant");
    }

    #[test]
    fn test_verify_zero_tests() {
        let result = evaluate_verify(0, 0, 0, 10);
        assert_eq!(result.decision, "NonCompliant");
    }
}
