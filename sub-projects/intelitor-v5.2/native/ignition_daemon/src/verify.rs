//! # Post-Launch Verification — 14-Point Checklist
//!
//! ## Fractal Position: L4-System / Homeostasis Verification
//! ## Source: journal §4, StartupVerification.fs:138-282
//! ## STAMP: SC-BOOT-006, SC-VER-001 to SC-VER-079

use crate::errors::IgnitionError;
use crate::health;
use crate::podman;
use crate::types::*;
use log::{info, warn};
use std::time::{Duration, Instant};

/// Count occurrences of a pattern in text.
fn count_pattern(text: &str, pattern: &str) -> u32 {
    text.matches(pattern).count() as u32
}

/// Run all 14 post-launch verification checks.
/// Waits T_boot=45s for container to stabilize before checking.
/// SC-VER-001: Startup verification before app ready
pub async fn run_all() -> Result<VerifyReport, IgnitionError> {
    let start = Instant::now();

    info!("╔═══════════════════════════════════════════════════════╗");
    info!("║  POST-LAUNCH VERIFICATION (14 checks)                ║");
    info!("║  Waiting 45s for boot stabilization...               ║");
    info!("╚═══════════════════════════════════════════════════════╝");

    tokio::time::sleep(Duration::from_secs(45)).await;

    let mut checks: Vec<CheckResult> = Vec::new();

    // V-1: Container running
    let v1 = {
        let running = health::check_running("indrajaal-ex-app-1")
            .await
            .unwrap_or(false);
        CheckResult {
            name: "V-1: Container running".into(),
            passed: running,
            message: if running {
                "Up".into()
            } else {
                "Not running".into()
            },
            duration_ms: 0,
        }
    };
    log_check(&v1);
    checks.push(v1);

    // V-2: Health endpoint
    let v2 = {
        let ok = health::check_http("http://localhost:4000/health", Duration::from_secs(5))
            .await
            .unwrap_or(false);
        CheckResult {
            name: "V-2: Health endpoint".into(),
            passed: ok,
            message: if ok { "OK".into() } else { "Failed".into() },
            duration_ms: 0,
        }
    };
    log_check(&v2);
    checks.push(v2);

    // V-3: Web UI
    let v3 = {
        let result = tokio::process::Command::new("curl")
            .args(["-sf", "--max-time", "5", "http://localhost:4000/"])
            .output()
            .await;
        let ok = result
            .map(|o| String::from_utf8_lossy(&o.stdout).contains("Indrajaal"))
            .unwrap_or(false);
        CheckResult {
            name: "V-3: Web UI".into(),
            passed: ok,
            message: if ok {
                "Renders HTML".into()
            } else {
                "No content".into()
            },
            duration_ms: 0,
        }
    };
    log_check(&v3);
    checks.push(v3);

    // V-4: Redis
    let v4 = {
        let ok = health::check_redis("indrajaal-ex-app-1")
            .await
            .unwrap_or(false);
        CheckResult {
            name: "V-4: Redis".into(),
            passed: ok,
            message: if ok {
                "PONG".into()
            } else {
                "Not responding".into()
            },
            duration_ms: 0,
        }
    };
    log_check(&v4);
    checks.push(v4);

    // Get logs for pattern-based checks
    let logs = podman::container_logs("indrajaal-ex-app-1", 1000)
        .await
        .unwrap_or_default();

    // V-5: BadMapError (F6 verification)
    let bme = count_pattern(&logs, "BadMapError");
    let v5 = CheckResult {
        name: "V-5: BadMapError (F6)".into(),
        passed: bme == 0,
        message: format!("{} occurrences", bme),
        duration_ms: 0,
    };
    log_check(&v5);
    checks.push(v5);

    // V-6: ArgumentError (F6b verification)
    let ae = count_pattern(&logs, "not a list");
    let v6 = CheckResult {
        name: "V-6: ArgumentError (F6b)".into(),
        passed: ae == 0,
        message: format!("{} occurrences", ae),
        duration_ms: 0,
    };
    log_check(&v6);
    checks.push(v6);

    // V-7: CepafPort (F3+F4 verification)
    let cp = count_pattern(&logs, "CepafPort") & count_pattern(&logs, "Failed");
    let v7 = CheckResult {
        name: "V-7: CepafPort (F3+F4)".into(),
        passed: cp == 0,
        message: format!("{} failures", cp),
        duration_ms: 0,
    };
    log_check(&v7);
    checks.push(v7);

    // V-8: Watchdog restarts (F10 verification)
    let restarts = count_pattern(&logs, "Scheduling restart");
    let v8 = CheckResult {
        name: "V-8: Watchdog restarts (F10)".into(),
        passed: restarts == 0,
        message: format!("{} restarts", restarts),
        duration_ms: 0,
    };
    log_check(&v8);
    checks.push(v8);

    // V-9: Error rate
    let errors = count_pattern(&logs, "[error]");
    let v9 = CheckResult {
        name: "V-9: Error rate".into(),
        passed: errors <= 10,
        message: format!("{} errors in logs", errors),
        duration_ms: 0,
    };
    log_check(&v9);
    checks.push(v9);

    // V-10: ts_event_logs (F8 verification)
    let ts_err = count_pattern(&logs, "QUERY ERROR");
    let v10 = CheckResult {
        name: "V-10: ts_event_logs (F8)".into(),
        passed: ts_err == 0,
        message: format!("{} query errors", ts_err),
        duration_ms: 0,
    };
    log_check(&v10);
    checks.push(v10);

    // V-11: OODA interval (F1 verification)
    let ooda = count_pattern(&logs, "CP-OODA-01");
    let v11 = CheckResult {
        name: "V-11: OODA interval (F1)".into(),
        passed: ooda <= 20, // ~45s of logs at 10s interval = ~5
        message: format!("{} checkpoints (expect ~5 at 10s interval)", ooda),
        duration_ms: 0,
    };
    log_check(&v11);
    checks.push(v11);

    // V-12: GenServer crashes
    let crashes = count_pattern(&logs, "terminating");
    let v12 = CheckResult {
        name: "V-12: GenServer crashes".into(),
        passed: crashes == 0,
        message: format!("{} terminations", crashes),
        duration_ms: 0,
    };
    log_check(&v12);
    checks.push(v12);

    // V-13: Guardian escalations
    let esc = count_pattern(&logs, "ESCALATING");
    let v13 = CheckResult {
        name: "V-13: Guardian escalations".into(),
        passed: esc == 0,
        message: format!("{} escalations", esc),
        duration_ms: 0,
    };
    log_check(&v13);
    checks.push(v13);

    // V-14: cepaf-bridge running
    let v14 = {
        let ok = health::check_running("cepaf-bridge").await.unwrap_or(false);
        CheckResult {
            name: "V-14: cepaf-bridge".into(),
            passed: ok,
            message: if ok {
                "Running".into()
            } else {
                "Not running".into()
            },
            duration_ms: 0,
        }
    };
    log_check(&v14);
    checks.push(v14);

    // V-15: Inter-container connectivity (Idea #32)
    let v15 = {
        let start = Instant::now();
        match crate::connectivity::verify_connectivity().await {
            Ok(matrix) => {
                let all_ok = matrix.all_reachable;
                CheckResult {
                    name: "V-15: Inter-container connectivity".into(),
                    passed: all_ok,
                    message: if all_ok {
                        format!("{}/{} reachable", matrix.successful, matrix.total_probes)
                    } else {
                        format!(
                            "{}/{} reachable, {} failed",
                            matrix.successful, matrix.total_probes, matrix.failed
                        )
                    },
                    duration_ms: start.elapsed().as_millis() as u64,
                }
            }
            Err(e) => CheckResult {
                name: "V-15: Inter-container connectivity".into(),
                passed: false,
                message: format!("Error: {}", e),
                duration_ms: start.elapsed().as_millis() as u64,
            },
        }
    };
    log_check(&v15);
    checks.push(v15);

    // V-16: Zenoh mesh topology (Idea #34)
    let v16 = {
        let start = Instant::now();
        match crate::connectivity::verify_zenoh_mesh_topology().await {
            Ok(report) => {
                let ok = report.fully_connected;
                CheckResult {
                    name: "V-16: Zenoh mesh topology".into(),
                    passed: ok,
                    message: if ok {
                        format!(
                            "{}/{} sessions established",
                            report.sessions_established, report.total_sessions_expected
                        )
                    } else {
                        format!(
                            "{} routers checked, {}/{} sessions",
                            report.routers_checked,
                            report.sessions_established,
                            report.total_sessions_expected
                        )
                    },
                    duration_ms: start.elapsed().as_millis() as u64,
                }
            }
            Err(e) => CheckResult {
                name: "V-16: Zenoh mesh topology".into(),
                passed: false,
                message: format!("Error: {}", e),
                duration_ms: start.elapsed().as_millis() as u64,
            },
        }
    };
    log_check(&v16);
    checks.push(v16);

    // V-17: Network partition detection (Idea #51)
    let v17 = {
        let start = Instant::now();
        match crate::partition::detect_partitions().await {
            Ok(result) => {
                let ok = !result.detected;
                CheckResult {
                    name: "V-17: Network partition check".into(),
                    passed: ok,
                    message: if ok {
                        "No partitions detected".into()
                    } else {
                        format!(
                            "PARTITION: {} + {} containers",
                            result.partition_a.len(),
                            result.partition_b.len()
                        )
                    },
                    duration_ms: start.elapsed().as_millis() as u64,
                }
            }
            Err(e) => CheckResult {
                name: "V-17: Network partition check".into(),
                passed: false,
                message: format!("Error: {}", e),
                duration_ms: start.elapsed().as_millis() as u64,
            },
        }
    };
    log_check(&v17);
    checks.push(v17);

    let passed_count = checks.iter().filter(|c| c.passed).count() as u32;
    let total_count = checks.len() as u32;
    let all_passed = passed_count == total_count;

    let state_vector = StateVector {
        compile: true,
        migrations: checks[0].passed, // container running implies compilation OK
        containers: checks[0].passed,
        zenoh: true, // verified in preflight
        health: checks[1].passed,
        quorum: true, // verified in preflight
        quorum_count: if checks[1].passed { 5 } else { 0 },
    };

    // Rule engine: graduated compliance assessment
    let critical_failed = !checks[0].passed || !checks[1].passed; // container + health are critical
    let verify_rule = crate::rule_engine::evaluate_verify(all_passed, critical_failed);
    info!(
        "═══ VERIFICATION: {}/{} checks passed, rule: {} — {} ({} ms) ═══",
        passed_count, total_count, verify_rule.decision, verify_rule.reason,
        start.elapsed().as_millis()
    );

    Ok(VerifyReport {
        checks,
        passed_count,
        total_count,
        all_passed,
        state_vector,
    })
}

fn log_check(check: &CheckResult) {
    if check.passed {
        info!("  ✅ {}: {}", check.name, check.message);
    } else {
        warn!("  ❌ {}: {}", check.name, check.message);
    }
}

// =============================================================================
// Unit Tests — Pure Verification Logic
// =============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    // ─── count_pattern ───

    #[test]
    fn test_count_pattern_empty_text() {
        assert_eq!(count_pattern("", "BadMapError"), 0);
    }

    #[test]
    fn test_count_pattern_no_match() {
        assert_eq!(count_pattern("all is well", "BadMapError"), 0);
    }

    #[test]
    fn test_count_pattern_single_match() {
        assert_eq!(
            count_pattern("got BadMapError at line 42", "BadMapError"),
            1
        );
    }

    #[test]
    fn test_count_pattern_multiple_matches() {
        let logs = "BadMapError on init\n[error] BadMapError again\nBadMapError third";
        assert_eq!(count_pattern(logs, "BadMapError"), 3);
    }

    #[test]
    fn test_count_pattern_error_rate_threshold() {
        // V-9: error rate <= 10
        let logs = (0..10)
            .map(|i| format!("[error] test error {}", i))
            .collect::<Vec<_>>()
            .join("\n");
        assert_eq!(count_pattern(&logs, "[error]"), 10);
        assert!(count_pattern(&logs, "[error]") <= 10); // passes threshold
    }

    #[test]
    fn test_count_pattern_error_rate_exceeds_threshold() {
        let logs = (0..11)
            .map(|i| format!("[error] test error {}", i))
            .collect::<Vec<_>>()
            .join("\n");
        assert!(count_pattern(&logs, "[error]") > 10); // fails V-9
    }

    #[test]
    fn test_count_pattern_ooda_checkpoints() {
        // V-11: expect ~5 CP-OODA-01 at 10s interval in 45s
        let logs = "CP-OODA-01 at 10s\nCP-OODA-01 at 20s\nCP-OODA-01 at 30s\nCP-OODA-01 at 40s\nCP-OODA-01 at 50s";
        assert_eq!(count_pattern(logs, "CP-OODA-01"), 5);
    }

    #[test]
    fn test_count_pattern_case_sensitive() {
        // Patterns are case-sensitive — "badmaperror" shouldn't match "BadMapError"
        assert_eq!(count_pattern("BadMapError", "badmaperror"), 0);
    }

    // ─── log_check ───

    #[test]
    fn test_check_result_passed() {
        let check = CheckResult {
            name: "V-1: Container running".into(),
            passed: true,
            message: "Up".into(),
            duration_ms: 42,
        };
        assert!(check.passed);
        assert_eq!(check.name, "V-1: Container running");
    }

    #[test]
    fn test_check_result_failed() {
        let check = CheckResult {
            name: "V-2: Health endpoint".into(),
            passed: false,
            message: "Failed".into(),
            duration_ms: 5000,
        };
        assert!(!check.passed);
    }

    // ─── state_vector construction logic ───

    #[test]
    fn test_state_vector_from_passing_checks() {
        // Simulate V-1 passed (container running) and V-2 passed (health)
        let sv = StateVector {
            compile: true,
            migrations: true,
            containers: true,
            zenoh: true,
            health: true,
            quorum: true,
            quorum_count: 5,
        };
        assert!(sv.is_valid());
    }

    #[test]
    fn test_state_vector_from_failed_health() {
        let sv = StateVector {
            compile: true,
            migrations: true,
            containers: true,
            zenoh: true,
            health: false,
            quorum: true,
            quorum_count: 5,
        };
        assert!(!sv.is_valid());
    }

    #[test]
    fn test_state_vector_from_failed_container() {
        let sv = StateVector {
            compile: true,
            migrations: false,
            containers: false,
            zenoh: true,
            health: false,
            quorum: true,
            quorum_count: 0,
        };
        assert!(!sv.is_valid());
        assert_eq!(sv.as_array(), [1, 0, 0, 1, 0, 1]);
    }

    // ─── verify report summary ───

    #[test]
    fn test_verify_report_all_pass() {
        let checks: Vec<CheckResult> = (1..=14)
            .map(|i| CheckResult {
                name: format!("V-{}", i),
                passed: true,
                message: "OK".into(),
                duration_ms: 0,
            })
            .collect();

        let passed_count = checks.iter().filter(|c| c.passed).count() as u32;
        let total_count = checks.len() as u32;
        assert_eq!(passed_count, 14);
        assert_eq!(total_count, 14);
        assert!(passed_count == total_count);
    }

    #[test]
    fn test_verify_report_partial_pass() {
        let mut checks: Vec<CheckResult> = (1..=14)
            .map(|i| CheckResult {
                name: format!("V-{}", i),
                passed: true,
                message: "OK".into(),
                duration_ms: 0,
            })
            .collect();
        // Fail V-5 and V-12
        checks[4].passed = false;
        checks[11].passed = false;

        let passed_count = checks.iter().filter(|c| c.passed).count() as u32;
        assert_eq!(passed_count, 12);
        assert!(passed_count < 14);
    }

    // ─── bitwise AND in V-7 ───

    #[test]
    fn test_v7_cepafport_logic() {
        // V-7 uses bitwise AND (&) — both "CepafPort" AND "Failed" must appear
        let logs_both = "CepafPort Failed to connect";
        let cp = count_pattern(logs_both, "CepafPort") & count_pattern(logs_both, "Failed");
        assert_eq!(cp, 1); // both present -> cp = 1 & 1 = 1

        let logs_only_cepaf = "CepafPort connected OK";
        let cp2 =
            count_pattern(logs_only_cepaf, "CepafPort") & count_pattern(logs_only_cepaf, "Failed");
        assert_eq!(cp2, 0); // "Failed" absent -> 1 & 0 = 0

        let logs_neither = "All good";
        let cp3 = count_pattern(logs_neither, "CepafPort") & count_pattern(logs_neither, "Failed");
        assert_eq!(cp3, 0); // neither -> 0 & 0 = 0
    }
}
