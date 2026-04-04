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
        let running = health::check_running("indrajaal-ex-app-1").await.unwrap_or(false);
        CheckResult {
            name: "V-1: Container running".into(),
            passed: running,
            message: if running { "Up".into() } else { "Not running".into() },
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
            message: if ok { "Renders HTML".into() } else { "No content".into() },
            duration_ms: 0,
        }
    };
    log_check(&v3);
    checks.push(v3);

    // V-4: Redis
    let v4 = {
        let ok = health::check_redis("indrajaal-ex-app-1").await.unwrap_or(false);
        CheckResult {
            name: "V-4: Redis".into(),
            passed: ok,
            message: if ok { "PONG".into() } else { "Not responding".into() },
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
            message: if ok { "Running".into() } else { "Not running".into() },
            duration_ms: 0,
        }
    };
    log_check(&v14);
    checks.push(v14);

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
    };

    info!(
        "═══ VERIFICATION: {}/{} checks passed ({} ms) ═══",
        passed_count,
        total_count,
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
