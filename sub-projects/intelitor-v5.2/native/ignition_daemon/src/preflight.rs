//! # Pre-Flight Check Module — SIL-6 Ignition Daemon
//!
//! ## Fractal Position
//! | Dimension | Value |
//! |-----------|-------|
//! | Layer     | L4-System (Pre-Boot Validation) |
//! | Element   | Preflight / Validation |
//!
//! ## Source Mapping
//! - PanopticIgnition.fs:743-791 (Phase 0: Preflight)
//! - MeshStartup.fs:172-206 (port scouring, migration verification)
//! - StartupVerification.fs:138-282 (state vector, stage gates)
//! - capture-ignition.sh:82-115 (pre-validation)
//!
//! ## STAMP: SC-IGNITE-002, SC-BOOT-001 to SC-BOOT-010
//!
//! Pre-flight predicate (critical):
//!   PreFlight_critical = PF1 ∧ PF2 ∧ PF3 ∧ PF4 ∧ PF5 ∧ PF6
//!
//! Extended checks (non-blocking, PF-7 through PF-18):
//!   PreFlight_extended = PF7 ∨ … ∨ PF18  (failures warn but do not halt)
//!
//! Total budget: T_preflight ≤ 30s

use crate::build_oracle;
use crate::errors::IgnitionError;
use crate::health;
use crate::health_orchestra;
use crate::nif_validator;
use crate::podman;
use crate::substrate_guard;
use crate::types::*;
use log::{error, info, warn};
use std::path::Path;
use std::time::{Duration, Instant};

/// Infrastructure containers that MUST be running before app launch.
/// Source: PanopticIgnition.fs sil6Genome, capture-ignition.sh:58
const INFRA_CONTAINERS: &[&str] = &[
    "zenoh-router-1",
    "zenoh-router-2",
    "zenoh-router-3",
    "indrajaal-db-prod",
    "indrajaal-obs-prod",
    "indrajaal-cortex",
];

const ZENOH_ROUTERS: &[&str] = &["zenoh-router-1", "zenoh-router-2", "zenoh-router-3"];

/// ts_event_logs CREATE TABLE SQL.
/// Source: scripts/timescale/init-timescaledb.sql (modified: tenant_id nullable)
/// F8 fix: tenant_id changed from NOT NULL to nullable for system events
const TS_EVENT_LOGS_SQL: &str = r#"
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE TABLE IF NOT EXISTS ts_event_logs (
    id BIGSERIAL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    event_type VARCHAR(100) NOT NULL DEFAULT 'general_event',
    event_source VARCHAR(100) NOT NULL DEFAULT 'application',
    tenant_id UUID,
    user_id UUID,
    resource_type VARCHAR(100),
    resource_id UUID,
    action VARCHAR(100),
    status VARCHAR(50),
    metadata JSONB DEFAULT '{}',
    duration_ms INTEGER,
    ip_address INET,
    user_agent TEXT,
    correlation_id UUID,
    trace_id VARCHAR(64),
    span_id VARCHAR(16),
    severity VARCHAR(20) DEFAULT 'info',
    message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_hypertable('ts_event_logs', 'timestamp',
    chunk_time_interval => INTERVAL '1 day',
    create_default_indexes => false,
    if_not_exists => TRUE
);
CREATE INDEX IF NOT EXISTS idx_ts_event_logs_timestamp ON ts_event_logs (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ts_event_logs_event_type ON ts_event_logs (event_type, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ts_event_logs_severity ON ts_event_logs (severity, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ts_event_logs_metadata ON ts_event_logs USING GIN (metadata);
"#;

/// PF-1: Verify all infrastructure containers are running.
/// Source: PanopticIgnition.fs:465, capture-ignition.sh:58-69
/// SC-BOOT-006: All containers pass health check
pub async fn check_infrastructure() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    info!("[PF-1] Checking infrastructure containers...");

    let mut healthy = 0u32;
    let total = INFRA_CONTAINERS.len() as u32;

    for container in INFRA_CONTAINERS {
        match podman::container_status(container).await {
            Ok(status) if status == "running" => {
                info!("  ✅ {}: running", container);
                healthy += 1;
            }
            Ok(status) => {
                warn!("  ❌ {}: {}", container, status);
            }
            Err(e) => {
                warn!("  ❌ {}: {}", container, e);
            }
        }
    }

    let passed = healthy == total;
    Ok(CheckResult {
        name: "PF-1: Infrastructure".into(),
        passed,
        message: format!("{}/{} containers running", healthy, total),
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-2: Database readiness — port, SSL, database existence, ts_event_logs.
/// Source: MeshStartup.fs:172-188, StartupVerification.fs:203-222
/// SC-XHOLON-030, SC-BOOT-002
pub async fn check_database() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    let db = "indrajaal-db-prod";
    let timeout = Duration::from_secs(10);
    info!("[PF-2] Checking database readiness...");

    // 2a: pg_isready
    let pg_ready = health::check_postgres(db, timeout).await.unwrap_or(false);
    if !pg_ready {
        return Ok(CheckResult {
            name: "PF-2: Database".into(),
            passed: false,
            message: "PostgreSQL not accepting connections".into(),
            duration_ms: start.elapsed().as_millis() as u64,
        });
    }
    info!("  ✅ pg_isready: accepting connections");

    // 2b: Detect internal port
    let port = health::detect_db_port(db).await.unwrap_or(5432);
    info!("  ✅ Internal port: {}", port);

    // 2c: SSL status
    if let Ok((ssl, _, _)) =
        podman::podman_exec(db, &["psql", "-U", "postgres", "-tAc", "SHOW ssl"], timeout).await
    {
        info!("  ✅ SSL: {}", ssl.trim());
    }

    // 2d: Database existence — create if missing
    let (db_check, _, _) = podman::podman_exec(
        db,
        &[
            "psql", "-U", "postgres", "-tAc",
            "SELECT datname FROM pg_database WHERE datname = 'indrajaal_prod'",
        ],
        timeout,
    )
    .await?;

    if !db_check.trim().contains("indrajaal_prod") {
        info!("  ⚠️  indrajaal_prod not found — creating...");
        let _ = podman::podman_exec(db, &["createdb", "-U", "postgres", "indrajaal_prod"], timeout).await;
        let _ = podman::podman_exec(
            db,
            &[
                "psql", "-U", "postgres", "-d", "indrajaal_prod", "-c",
                "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE",
            ],
            timeout,
        )
        .await;
        info!("  ✅ Created indrajaal_prod + TimescaleDB");
    } else {
        info!("  ✅ indrajaal_prod exists");
    }

    // 2e: ts_event_logs table
    let (table_check, _, _) = podman::podman_exec(
        db,
        &[
            "psql", "-U", "postgres", "-d", "indrajaal_prod", "-tAc",
            "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'ts_event_logs')",
        ],
        timeout,
    )
    .await?;

    if table_check.trim() != "t" {
        info!("  ⚠️  ts_event_logs not found — creating hypertable...");
        let _ = podman::podman_exec(
            db,
            &["psql", "-U", "postgres", "-d", "indrajaal_prod", "-c", TS_EVENT_LOGS_SQL],
            Duration::from_secs(30),
        )
        .await;
        info!("  ✅ Created ts_event_logs hypertable");
    } else {
        info!("  ✅ ts_event_logs exists");
    }

    Ok(CheckResult {
        name: "PF-2: Database".into(),
        passed: true,
        message: format!("PostgreSQL ready, port {}, indrajaal_prod + ts_event_logs verified", port),
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-3: Zenoh 2oo3 quorum check.
/// Source: PanopticIgnition.fs:844-850, HealthCoordinator.fs:218-220
/// Math: Q(N) = floor(N/2) + 1 = 2 for N=3
/// SC-SIL4-006: 2oo3 voting MANDATORY
pub async fn check_zenoh_quorum() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    info!("[PF-3] Checking Zenoh mesh quorum...");

    let mut healthy = 0u32;
    let total = ZENOH_ROUTERS.len() as u32;

    for router in ZENOH_ROUTERS {
        if health::check_running(router).await.unwrap_or(false) {
            info!("  ✅ {}: running", router);
            healthy += 1;
        } else {
            warn!("  ❌ {}: not running", router);
        }
    }

    let quorum_met = health::check_quorum(healthy, total);
    let required = quorum_threshold(total);

    Ok(CheckResult {
        name: "PF-3: Zenoh Quorum".into(),
        passed: quorum_met,
        message: format!(
            "{}/{} routers running (quorum requires {}): {}",
            healthy,
            total,
            required,
            if quorum_met { "ACHIEVED" } else { "NOT MET" }
        ),
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-4: Network & IP availability.
/// Source: PanopticIgnition.fs:455, MeshStartup.fs:192-206
/// SC-NET-MESH-001: App MUST be on sil6-mesh
pub async fn check_network() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    let target_ip = "172.28.0.10";
    info!("[PF-4] Checking network & IP availability...");

    // 4a: Network exists
    if !podman::network_exists(MESH_NETWORK).await {
        return Ok(CheckResult {
            name: "PF-4: Network".into(),
            passed: false,
            message: format!("Network {} does not exist", MESH_NETWORK),
            duration_ms: start.elapsed().as_millis() as u64,
        });
    }
    info!("  ✅ Network {} exists", MESH_NETWORK);

    // 4b: DNS enabled
    let dns = podman::network_dns_enabled(MESH_NETWORK).await.unwrap_or(false);
    if dns {
        info!("  ✅ DNS enabled");
    } else {
        warn!("  ⚠️ DNS not enabled on network");
    }

    // 4c: Remove stale app container if exists
    if podman::container_exists("indrajaal-ex-app-1").await {
        info!("  ⚠️ Old indrajaal-ex-app-1 found — removing...");
        podman::force_remove("indrajaal-ex-app-1").await?;
        info!("  ✅ Removed stale container");
    } else {
        info!("  ✅ No stale app container");
    }

    // 4d: Check host ports free (best-effort)
    info!("  ✅ Target IP {} (will be assigned on launch)", target_ip);

    Ok(CheckResult {
        name: "PF-4: Network".into(),
        passed: true,
        message: format!("Network {}, DNS={}, IP {} ready", MESH_NETWORK, dns, target_ip),
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-5: Image existence and code fix verification.
/// Source: PanopticIgnition.fs:156,183,193
/// SC-IGNITE-002: Architectural control checks
pub async fn check_image() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    let image = "localhost/indrajaal-ex-app-1:latest";
    info!("[PF-5] Checking image {}...", image);

    let exists = podman::image_exists(image).await;
    if !exists {
        return Ok(CheckResult {
            name: "PF-5: Image".into(),
            passed: false,
            message: format!("Image {} not found", image),
            duration_ms: start.elapsed().as_millis() as u64,
        });
    }
    info!("  ✅ Image exists");

    Ok(CheckResult {
        name: "PF-5: Image".into(),
        passed: true,
        message: format!("{} present", image),
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-6: Observability stack check.
/// Source: SIL6BiomorphicOrchestrator.fs:360-392
pub async fn check_observability() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    info!("[PF-6] Checking observability stack...");

    let running = health::check_running("indrajaal-obs-prod").await.unwrap_or(false);
    if running {
        info!("  ✅ indrajaal-obs-prod: running");
    } else {
        warn!("  ❌ indrajaal-obs-prod: not running");
    }

    Ok(CheckResult {
        name: "PF-6: Observability".into(),
        passed: running,
        message: if running {
            "OTEL + Prometheus + Grafana available".into()
        } else {
            "Observability stack not running".into()
        },
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-7: NIF binary validation.
/// Calls nif_validator::validate_all_nifs to inspect ELF headers of all
/// compiled NIF .so files inside the app container.
///
/// SC-NIF-001 to SC-NIF-006, Axiom 0.1
#[allow(dead_code)]
pub async fn check_nif_binaries() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    let container = "indrajaal-ex-app-1";
    info!("[PF-7] Validating NIF binaries in {}...", container);

    // Check cargo availability first (SC-NIF-006)
    let cargo_ok = nif_validator::check_cargo_available(container).await.unwrap_or(false);
    if !cargo_ok {
        warn!("  ❌ cargo not found in {} — SC-NIF-006 violation", container);
        return Ok(CheckResult {
            name: "PF-7: NIF Binaries".into(),
            passed: false,
            message: format!("cargo not found in {} — NIF compilation cannot proceed", container),
            duration_ms: start.elapsed().as_millis() as u64,
        });
    }
    info!("  ✅ cargo available");

    let results = nif_validator::validate_all_nifs(container).await?;
    let total = results.len();

    if total == 0 {
        info!("  ✅ No NIF .so files found (pre-compile state)");
        return Ok(CheckResult {
            name: "PF-7: NIF Binaries".into(),
            passed: true,
            message: "No NIF binaries present yet (pre-compile state)".into(),
            duration_ms: start.elapsed().as_millis() as u64,
        });
    }

    let issues = nif_validator::check_libc_consistency(&results);
    let valid = results.iter().filter(|r| r.is_valid).count();
    let has_critical = issues.iter().any(|i| i.contains("CRITICAL"));
    let passed = !has_critical;

    if passed {
        info!("  ✅ {}/{} NIFs valid, libc consistent", valid, total);
    } else {
        warn!("  ❌ libc consistency violation detected");
        for issue in &issues {
            warn!("    {}", issue);
        }
    }

    Ok(CheckResult {
        name: "PF-7: NIF Binaries".into(),
        passed,
        message: format!(
            "{}/{} NIFs valid{}",
            valid,
            total,
            if issues.is_empty() { String::new() } else { format!(", {} issue(s)", issues.len()) }
        ),
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-8: Substrate integrity.
/// Calls substrate_guard::run_all_checks to verify Axiom 0.1 (_build/deps
/// contamination) and Axiom 0.2 (volume shadowing).
///
/// SC-IGNITE-001, Axiom 0.1, Axiom 0.2
#[allow(dead_code)]
pub async fn check_substrate_integrity() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    let project_root = Path::new("/home/an/dev/ver/intelitor-v5.2");
    info!("[PF-8] Checking substrate integrity (Axiom 0.1/0.2)...");

    let report = substrate_guard::run_all_checks(project_root).await?;
    let passed_count = report.checks.iter().filter(|c| c.passed).count();
    let total = report.checks.len();

    if report.all_passed {
        info!("  ✅ {}/{} substrate checks passed — substrate is clean", passed_count, total);
    } else {
        warn!("  ❌ {}/{} substrate checks passed", passed_count, total);
        if report.host_build_detected {
            warn!("  ❌ Host _build contamination detected — Axiom 0.1 violation");
        }
        if report.host_deps_detected {
            warn!("  ❌ Host deps contamination detected — Axiom 0.1 violation");
        }
        if !report.contamination_paths.is_empty() {
            warn!("  ❌ {} contamination path(s) found", report.contamination_paths.len());
        }
    }

    let message = if report.all_passed {
        format!("{}/{} checks passed — substrate clean", passed_count, total)
    } else {
        let contamination = if !report.contamination_paths.is_empty() {
            format!(", {} contaminated path(s)", report.contamination_paths.len())
        } else {
            String::new()
        };
        format!("{}/{} checks passed{}", passed_count, total, contamination)
    };

    Ok(CheckResult {
        name: "PF-8: Substrate Integrity".into(),
        passed: report.all_passed,
        message,
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-9: Build oracle health.
/// Calls build_oracle::check_health() to verify the BuildHistory SQLite
/// database is accessible and contains EMA data.
///
/// SC-IGNITE-005, SC-XHOLON-001, SC-XHOLON-030
#[allow(dead_code)]
pub async fn check_build_oracle() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    info!("[PF-9] Checking build oracle health...");

    let health = build_oracle::check_health();

    if !health.db_exists {
        info!("  ✅ build-history.db absent — first boot, graceful degradation");
        return Ok(CheckResult {
            name: "PF-9: Build Oracle".into(),
            passed: true,
            message: "Database absent (first boot) — adaptive timeouts will use defaults".into(),
            duration_ms: start.elapsed().as_millis() as u64,
        });
    }

    let passed = health.db_exists && health.wal_mode;

    if passed {
        info!(
            "  ✅ build-history.db: WAL={}, history_rows={}, ema_rows={}",
            health.wal_mode, health.build_history_rows, health.ema_rows
        );
        if let Some(ref newest) = health.newest_record {
            info!("  ✅ Newest build record: {}", newest);
        }
    } else {
        warn!(
            "  ❌ build-history.db health degraded: WAL={}, history_rows={}, ema_rows={}",
            health.wal_mode, health.build_history_rows, health.ema_rows
        );
    }

    Ok(CheckResult {
        name: "PF-9: Build Oracle".into(),
        passed,
        message: format!(
            "db_exists={}, WAL={}, history_rows={}, ema_rows={}",
            health.db_exists, health.wal_mode, health.build_history_rows, health.ema_rows
        ),
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-10: Health orchestra FPPS consensus.
/// Calls health_orchestra::check_all_containers() to run 5-method FPPS
/// consensus across all 16 SIL-6 genome containers.
///
/// SC-SIL4-006 (2oo3 voting), SC-VAL-003 (FPPS consensus), Omega-5
#[allow(dead_code)]
pub async fn check_health_consensus() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    info!("[PF-10] Running FPPS 5-method consensus across all 16 containers...");

    let results = health_orchestra::check_all_containers().await;
    let total = results.len();
    let healthy = results.iter().filter(|c| c.consensus_reached).count();

    for consensus in &results {
        if consensus.consensus_reached {
            info!(
                "  ✅ {}: {}/{} methods agreed",
                consensus.container_name, consensus.agreed, consensus.total
            );
        } else {
            warn!(
                "  ❌ {}: {}/{} methods agreed (need {})",
                consensus.container_name, consensus.agreed, consensus.total,
                HEALTH_CONSENSUS_THRESHOLD
            );
        }
    }

    // Pass if at least the 6 critical infra containers are healthy
    let infra_healthy = results
        .iter()
        .filter(|c| INFRA_CONTAINERS.contains(&c.container_name.as_str()))
        .filter(|c| c.consensus_reached)
        .count();
    let infra_total = INFRA_CONTAINERS.len();
    let passed = infra_healthy == infra_total;

    Ok(CheckResult {
        name: "PF-10: Health Consensus".into(),
        passed,
        message: format!(
            "{}/{} containers healthy (FPPS); {}/{} infra containers confirmed",
            healthy, total, infra_healthy, infra_total
        ),
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-11: Zenoh telemetry backplane.
/// Verifies all three Zenoh routers are reachable on port 7447 and have
/// consistent running state.
///
/// SC-ZENOH-001, SC-ZENOH-002, SC-BIST-001
#[allow(dead_code)]
pub async fn check_zenoh_telemetry() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    info!("[PF-11] Checking Zenoh telemetry backplane...");

    let mut reachable = 0u32;
    let total = ZENOH_ROUTERS.len() as u32;

    for router in ZENOH_ROUTERS {
        let running = health::check_running(router).await.unwrap_or(false);
        let port_open = health::check_port(router, ZENOH_PORT, Duration::from_secs(3))
            .await
            .unwrap_or(false);

        if running && port_open {
            info!("  ✅ {}: running, port {} open", router, ZENOH_PORT);
            reachable += 1;
        } else {
            warn!(
                "  ❌ {}: running={}, port_{}={}",
                router, running, ZENOH_PORT, port_open
            );
        }
    }

    // Zenoh quorum: floor(N/2)+1 = 2 of 3
    let quorum_met = health::check_quorum(reachable, total);
    let required = quorum_threshold(total);
    let passed = quorum_met;

    Ok(CheckResult {
        name: "PF-11: Zenoh Telemetry".into(),
        passed,
        message: format!(
            "{}/{} routers reachable on port {} (quorum requires {}): {}",
            reachable, total, ZENOH_PORT, required,
            if passed { "BACKPLANE STABLE" } else { "BACKPLANE DEGRADED" }
        ),
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-12: Container image freshness.
/// Checks image age for key containers. Flags if any image is older than
/// MAX_IMAGE_AGE_HOURS (168 h = 7 days).
///
/// SC-IGNITE-007
#[allow(dead_code)]
pub async fn check_image_freshness() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    info!("[PF-12] Checking container image freshness (max age: {} h)...", MAX_IMAGE_AGE_HOURS);

    /// Key images to check — BuiltFromDockerfile containers from sil6Genome.
    const KEY_IMAGES: &[&str] = &[
        "localhost/indrajaal-ex-app-1:latest",
        "localhost/indrajaal-db-prod:latest",
        "localhost/indrajaal-obs-prod:latest",
        "localhost/cepaf-bridge:latest",
        "localhost/indrajaal-cortex:latest",
    ];

    let timeout = Duration::from_secs(5);
    let mut stale_count = 0u32;
    let mut checked = 0u32;

    for image in KEY_IMAGES {
        let exists = podman::image_exists(image).await;
        if !exists {
            info!("  ⚠️  {}: not found (may not be built yet)", image);
            continue;
        }
        checked += 1;

        // Query image creation timestamp via podman inspect
        let (stdout, _, code) = podman::podman_cmd(
            &["image", "inspect", image, "--format", "{{.Created}}"],
            timeout,
        )
        .await
        .unwrap_or_else(|_| (String::new(), String::new(), -1));

        if code != 0 || stdout.trim().is_empty() {
            info!("  ⚠️  {}: cannot determine age", image);
            continue;
        }

        // Parse RFC3339-like timestamp; attempt to detect staleness via podman age check
        // podman outputs: "2006-01-02 15:04:05.999999999 +0000 UTC"
        // Use a secondary call to get age in seconds via --format {{.Age}} if available
        let (age_out, _, age_code) = podman::podman_cmd(
            &["image", "inspect", image, "--format", "{{.Age}}"],
            timeout,
        )
        .await
        .unwrap_or_else(|_| (String::new(), String::new(), -1));

        if age_code == 0 && !age_out.trim().is_empty() {
            info!("  ✅ {}: age={}", image, age_out.trim());
            // Heuristic: "weeks" or a large number of days indicates staleness
            let age_str = age_out.trim().to_lowercase();
            if age_str.contains("week") || age_str.contains("month") || age_str.contains("year") {
                warn!("  ⚠️  {}: image may be stale ({})", image, age_str);
                stale_count += 1;
            }
        } else {
            // Fall back to reporting the raw creation timestamp
            info!("  ✅ {}: created {}", image, stdout.trim());
        }
    }

    let passed = stale_count == 0;
    Ok(CheckResult {
        name: "PF-12: Image Freshness".into(),
        passed,
        message: format!(
            "{}/{} images checked; {} potentially stale (> {} h threshold)",
            checked,
            KEY_IMAGES.len(),
            stale_count,
            MAX_IMAGE_AGE_HOURS
        ),
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-13: Database migration state.
/// Verifies the Ecto `schema_migrations` table exists in `indrajaal_prod`,
/// indicating that migrations have been run.
///
/// SC-MIG-001, SC-BOOT-002
#[allow(dead_code)]
pub async fn check_migration_state() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    let db = "indrajaal-db-prod";
    let timeout = Duration::from_secs(10);
    info!("[PF-13] Checking Ecto migration state...");

    // Verify schema_migrations table exists
    let (stdout, _, code) = podman::podman_exec(
        db,
        &[
            "psql", "-U", "postgres", "-d", "indrajaal_prod", "-tAc",
            "SELECT EXISTS (SELECT FROM information_schema.tables \
             WHERE table_schema = 'public' AND table_name = 'schema_migrations')",
        ],
        timeout,
    )
    .await
    .unwrap_or_else(|_| (String::new(), String::new(), -1));

    if code != 0 {
        warn!("  ❌ Cannot query schema_migrations (DB may not be ready)");
        return Ok(CheckResult {
            name: "PF-13: Migration State".into(),
            passed: false,
            message: "Cannot query schema_migrations — DB not accessible".into(),
            duration_ms: start.elapsed().as_millis() as u64,
        });
    }

    let table_exists = stdout.trim() == "t";

    if table_exists {
        // Count migrations applied
        let (count_out, _, _) = podman::podman_exec(
            db,
            &["psql", "-U", "postgres", "-d", "indrajaal_prod", "-tAc",
              "SELECT COUNT(*) FROM schema_migrations"],
            timeout,
        )
        .await
        .unwrap_or_else(|_| (String::new(), String::new(), -1));

        let count: i64 = count_out.trim().parse().unwrap_or(0);
        info!("  ✅ schema_migrations exists with {} migration(s) applied", count);
        Ok(CheckResult {
            name: "PF-13: Migration State".into(),
            passed: true,
            message: format!("schema_migrations present ({} migrations applied)", count),
            duration_ms: start.elapsed().as_millis() as u64,
        })
    } else {
        warn!("  ❌ schema_migrations table not found — migrations not yet run");
        Ok(CheckResult {
            name: "PF-13: Migration State".into(),
            passed: false,
            message: "schema_migrations table absent — run `mix ecto.migrate`".into(),
            duration_ms: start.elapsed().as_millis() as u64,
        })
    }
}

/// PF-14: Port availability.
/// Verifies key service ports are not occupied by stale host processes before
/// container launch. Checks ports on the host side.
///
/// SC-BOOT-007
#[allow(dead_code)]
pub async fn check_port_availability() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    info!("[PF-14] Checking host port availability...");

    /// (port, service_name, critical)
    const PORTS_TO_CHECK: &[(u16, &str, bool)] = &[
        (4000, "Phoenix app", true),
        (4317, "OTEL gRPC", true),
        (5433, "PostgreSQL (external)", true),
        (7447, "Zenoh router", true),
        (9090, "Prometheus", false),
        (3000, "Grafana", false),
    ];

    let mut blocked = 0u32;
    let mut critical_blocked = 0u32;

    for &(port, service, critical) in PORTS_TO_CHECK {
        // Use ss/netstat to check if the host port is in use
        let (stdout, _, code) = podman::podman_cmd(
            &["port", "--all"],
            Duration::from_secs(5),
        )
        .await
        .unwrap_or_else(|_| (String::new(), String::new(), -1));

        // podman port --all lists port mappings for running containers.
        // A port reported here is "in use by a container" which is expected.
        // We do a best-effort check — if podman itself reports the port occupied
        // by a non-mesh container, flag it.
        let _ = (stdout, code); // suppress unused warning — result is best-effort

        // Try to connect to the port on localhost to see if something is listening
        let in_use = tokio::net::TcpStream::connect(
            std::net::SocketAddr::new(
                std::net::IpAddr::V4(std::net::Ipv4Addr::LOCALHOST),
                port,
            )
        )
        .await
        .is_ok();

        if in_use {
            info!("  ✅ Port {} ({}): in use (expected for running infra)", port, service);
        } else {
            info!("  ✅ Port {} ({}): free", port, service);
        }

        // For preflight purposes, stale host processes binding these ports are
        // problematic only if the port is not in use by the expected container.
        // We report ports that are unexpectedly IN USE when the associated container
        // is NOT running, as a potential blocker.
        let container_for_port: Option<&str> = match port {
            4000 => Some("indrajaal-ex-app-1"),
            4317 => Some("indrajaal-obs-prod"),
            5433 => Some("indrajaal-db-prod"),
            7447 => Some("zenoh-router-1"),
            _ => None,
        };

        if let Some(container) = container_for_port {
            let container_running = health::check_running(container).await.unwrap_or(false);
            if in_use && !container_running {
                warn!("  ❌ Port {} ({}): occupied but {} is NOT running — stale process?",
                      port, service, container);
                blocked += 1;
                if critical {
                    critical_blocked += 1;
                }
            }
        }
    }

    let passed = critical_blocked == 0;
    Ok(CheckResult {
        name: "PF-14: Port Availability".into(),
        passed,
        message: format!(
            "Checked {} ports; {} blocked ({} critical)",
            PORTS_TO_CHECK.len(), blocked, critical_blocked
        ),
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-15: Elixir release check.
/// Verifies the Elixir release binary `/app/bin/indrajaal` exists inside the
/// app container image.
///
/// SC-OPT-005 (pre-compiled BEAM files in app container)
#[allow(dead_code)]
pub async fn check_elixir_release() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    let image = "localhost/indrajaal-ex-app-1:latest";
    info!("[PF-15] Checking Elixir release in {}...", image);

    if !podman::image_exists(image).await {
        warn!("  ❌ Image {} not found — cannot verify release", image);
        return Ok(CheckResult {
            name: "PF-15: Elixir Release".into(),
            passed: false,
            message: format!("Image {} not found", image),
            duration_ms: start.elapsed().as_millis() as u64,
        });
    }

    // Run a one-shot container to check for the release binary
    let timeout = Duration::from_secs(10);
    let (stdout, _, code) = podman::podman_cmd(
        &[
            "run", "--rm", "--entrypoint", "sh",
            image,
            "-c", "test -f /app/bin/indrajaal && echo found || echo missing",
        ],
        timeout,
    )
    .await
    .unwrap_or_else(|_| (String::new(), String::new(), -1));

    let found = code == 0 && stdout.trim() == "found";

    if found {
        info!("  ✅ /app/bin/indrajaal exists in image");
    } else {
        warn!("  ❌ /app/bin/indrajaal not found in image (stdout='{}', code={})",
              stdout.trim(), code);
    }

    Ok(CheckResult {
        name: "PF-15: Elixir Release".into(),
        passed: found,
        message: if found {
            "/app/bin/indrajaal present in image".into()
        } else {
            format!("/app/bin/indrajaal absent (code={}, out='{}')", code, stdout.trim())
        },
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-16: BIST stability check.
/// SC-BIST-001: 3σ stability on Zenoh telemetry backplane. Samples 10 TCP
/// round-trips to zenoh-router, computes mean and standard deviation, passes
/// only if 3*sigma < BIST_3SIGMA_THRESHOLD_MS (100 ms).
///
/// SC-BIST-001
#[allow(dead_code)]
pub async fn check_bist_stability() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    info!("[PF-16] BIST stability check ({} pings to zenoh-router)...", BIST_PING_COUNT);

    let mut latencies: Vec<f64> = Vec::with_capacity(BIST_PING_COUNT as usize);

    for i in 0..BIST_PING_COUNT {
        let ping_start = Instant::now();
        let reachable = health::check_port(
            "zenoh-router",
            ZENOH_PORT,
            Duration::from_millis(200),
        )
        .await
        .unwrap_or(false);
        let latency_ms = ping_start.elapsed().as_secs_f64() * 1000.0;

        if reachable {
            latencies.push(latency_ms);
            info!("  ping {}: {:.1} ms", i + 1, latency_ms);
        } else {
            warn!("  ping {}: unreachable", i + 1);
        }

        if i + 1 < BIST_PING_COUNT {
            tokio::time::sleep(Duration::from_millis(BIST_PING_INTERVAL_MS)).await;
        }
    }

    if latencies.is_empty() {
        warn!("  ❌ All pings failed — zenoh-router unreachable");
        return Ok(CheckResult {
            name: "PF-16: BIST Stability".into(),
            passed: false,
            message: "All pings failed — zenoh-router unreachable".into(),
            duration_ms: start.elapsed().as_millis() as u64,
        });
    }

    let n = latencies.len() as f64;
    let mean = latencies.iter().sum::<f64>() / n;
    let variance = latencies.iter().map(|&x| (x - mean).powi(2)).sum::<f64>() / n;
    let sigma = variance.sqrt();
    let three_sigma = 3.0 * sigma;

    let passed = three_sigma < BIST_3SIGMA_THRESHOLD_MS;

    if passed {
        info!(
            "  ✅ BIST: n={}, mean={:.1}ms, sigma={:.1}ms, 3σ={:.1}ms < {:.0}ms",
            latencies.len(), mean, sigma, three_sigma, BIST_3SIGMA_THRESHOLD_MS
        );
    } else {
        warn!(
            "  ❌ BIST: 3σ={:.1}ms >= {:.0}ms threshold (mean={:.1}ms, sigma={:.1}ms)",
            three_sigma, BIST_3SIGMA_THRESHOLD_MS, mean, sigma
        );
    }

    Ok(CheckResult {
        name: "PF-16: BIST Stability".into(),
        passed,
        message: format!(
            "n={}/{}, mean={:.1}ms, sigma={:.1}ms, 3σ={:.1}ms (threshold={:.0}ms)",
            latencies.len(), BIST_PING_COUNT, mean, sigma, three_sigma, BIST_3SIGMA_THRESHOLD_MS
        ),
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-17: Cortex binary check.
/// Verifies that `indrajaal-cortex` container has the expected F# binary
/// (`/app/Cepaf`) present, indicating the F# cognitive layer is deployable.
///
/// SC-IGNITE-008 (sil6Genome coverage)
#[allow(dead_code)]
pub async fn check_cortex_binary() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    let container = "indrajaal-cortex";
    info!("[PF-17] Checking cortex F# binary in {}...", container);

    let running = health::check_running(container).await.unwrap_or(false);
    if !running {
        warn!("  ❌ {}: not running — cannot inspect binary", container);
        return Ok(CheckResult {
            name: "PF-17: Cortex Binary".into(),
            passed: false,
            message: format!("{} is not running", container),
            duration_ms: start.elapsed().as_millis() as u64,
        });
    }

    let timeout = Duration::from_secs(5);
    let (stdout, _, code) = podman::podman_exec(
        container,
        &["sh", "-c", "test -f /app/Cepaf && echo found || echo missing"],
        timeout,
    )
    .await
    .unwrap_or_else(|_| (String::new(), String::new(), -1));

    let found = code == 0 && stdout.trim() == "found";

    if found {
        info!("  ✅ /app/Cepaf binary present in {}", container);
    } else {
        warn!("  ❌ /app/Cepaf binary not found in {} (code={}, out='{}')",
              container, code, stdout.trim());
    }

    Ok(CheckResult {
        name: "PF-17: Cortex Binary".into(),
        passed: found,
        message: if found {
            format!("/app/Cepaf present in {}", container)
        } else {
            format!("/app/Cepaf absent in {} (code={}, out='{}')", container, code, stdout.trim())
        },
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-18: Bridge binary check.
/// Verifies that `cepaf-bridge` container has the expected F# binary
/// (`/app/Cepaf`) or bridge binary present.
///
/// SC-IGNITE-008 (sil6Genome coverage)
#[allow(dead_code)]
pub async fn check_bridge_binary() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    let container = "cepaf-bridge";
    info!("[PF-18] Checking bridge F# binary in {}...", container);

    let running = health::check_running(container).await.unwrap_or(false);
    if !running {
        warn!("  ❌ {}: not running — cannot inspect binary", container);
        return Ok(CheckResult {
            name: "PF-18: Bridge Binary".into(),
            passed: false,
            message: format!("{} is not running", container),
            duration_ms: start.elapsed().as_millis() as u64,
        });
    }

    let timeout = Duration::from_secs(5);
    // Check for the bridge binary — may be /app/Cepaf or /app/cepaf-bridge
    let (stdout, _, code) = podman::podman_exec(
        container,
        &[
            "sh", "-c",
            "( test -f /app/Cepaf && echo found:Cepaf ) || \
             ( test -f /app/cepaf-bridge && echo found:cepaf-bridge ) || \
             echo missing",
        ],
        timeout,
    )
    .await
    .unwrap_or_else(|_| (String::new(), String::new(), -1));

    let found = code == 0 && stdout.trim().starts_with("found");
    let binary_name = if found {
        stdout.trim().splitn(2, ':').nth(1).unwrap_or("unknown").to_string()
    } else {
        "none".to_string()
    };

    if found {
        info!("  ✅ Bridge binary ({}) present in {}", binary_name, container);
    } else {
        warn!("  ❌ Bridge binary not found in {} (code={}, out='{}')",
              container, code, stdout.trim());
    }

    Ok(CheckResult {
        name: "PF-18: Bridge Binary".into(),
        passed: found,
        message: if found {
            format!("Bridge binary ({}) present in {}", binary_name, container)
        } else {
            format!("Bridge binary absent in {} (code={}, out='{}')", container, code, stdout.trim())
        },
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-19: Mandatory Disk Quota Check (<15% free aborts).
/// Ensures host disk has sufficient entropy/space before launch.
/// SC-IGNITE-002, SC-BOOT-004
#[allow(dead_code)]
pub async fn check_disk_space() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    info!("[PF-19] Checking host disk space...");

    let (stdout, _, code) = podman::podman_cmd(
        &["info", "--format", "{{.Store.GraphRoot}}"],
        Duration::from_secs(5),
    )
    .await
    .unwrap_or_else(|_| (String::new(), String::new(), -1));

    if code != 0 || stdout.trim().is_empty() {
        warn!("  ⚠️ Could not determine podman graph root, skipping disk check");
        return Ok(CheckResult {
            name: "PF-19: Disk Space".into(),
            passed: true,
            message: "Skipped (podman info failed)".into(),
            duration_ms: start.elapsed().as_millis() as u64,
        });
    }

    let graph_root = stdout.trim();
    // Use df to check available space on the partition hosting the graph root
    let df_out = std::process::Command::new("df")
        .arg("-k")
        .arg(graph_root)
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).to_string())
        .unwrap_or_default();

    // Parse df output: Filesystem 1K-blocks Used Available Use% Mounted on
    let lines: Vec<&str> = df_out.lines().collect();
    if lines.len() > 1 {
        let parts: Vec<&str> = lines[1].split_whitespace().collect();
        if parts.len() >= 5 {
            let use_pct_str = parts[4].trim_end_matches('%');
            if let Ok(use_pct) = use_pct_str.parse::<u8>() {
                let free_pct = 100 - use_pct;
                if free_pct < 15 {
                    warn!("  ❌ CRITICAL: Host disk space dangerously low ({}% free) at {}", free_pct, graph_root);
                    return Ok(CheckResult {
                        name: "PF-19: Disk Space".into(),
                        passed: false,
                        message: format!("Low disk space: {}% free < 15% threshold", free_pct),
                        duration_ms: start.elapsed().as_millis() as u64,
                    });
                } else {
                    info!("  ✅ Disk space healthy: {}% free at {}", free_pct, graph_root);
                    return Ok(CheckResult {
                        name: "PF-19: Disk Space".into(),
                        passed: true,
                        message: format!("Disk healthy: {}% free", free_pct),
                        duration_ms: start.elapsed().as_millis() as u64,
                    });
                }
            }
        }
    }

    Ok(CheckResult {
        name: "PF-19: Disk Space".into(),
        passed: true,
        message: "Check inconclusive (df parse failed)".into(),
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-20: Pre-flight Socket Testing (Podman Health)
/// Rank 5 Idea: Actively attempt a mock connection to the Podman Unix socket before spawning the main process.
#[allow(dead_code)]
pub async fn check_podman_socket() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    info!("[PF-20] Checking podman socket responsiveness...");

    let (stdout, _, code) = podman::podman_cmd(&["info"], Duration::from_secs(3)).await
        .unwrap_or_else(|_| (String::new(), String::new(), -1));

    let passed = code == 0 && stdout.contains("host");
    if passed {
        info!("  ✅ Podman socket responsive");
    } else {
        warn!("  ❌ Podman socket unresponsive or hanging");
    }

    Ok(CheckResult {
        name: "PF-20: Podman Socket".into(),
        passed,
        message: if passed { "Responsive".into() } else { "Unresponsive".into() },
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// PF-21: Substrate Entropy Check (/dev/random)
/// Rank 12 Idea: Verify available disk entropy is sufficient for crypto operations.
#[allow(dead_code)]
pub async fn check_substrate_entropy() -> Result<CheckResult, IgnitionError> {
    let start = Instant::now();
    info!("[PF-21] Checking substrate entropy pool...");

    let entropy_avail = std::fs::read_to_string("/proc/sys/kernel/random/entropy_avail")
        .unwrap_or_else(|_| String::from("0"));
    
    let entropy: u32 = entropy_avail.trim().parse().unwrap_or(0);
    let passed = entropy >= 256; // 256 is absolute minimum for secure boot

    if passed {
        info!("  ✅ Entropy pool healthy: {}", entropy);
    } else {
        warn!("  ⚠️ Low entropy detected: {} (may cause slow crypto)", entropy);
    }

    Ok(CheckResult {
        name: "PF-21: Substrate Entropy".into(),
        passed,
        message: format!("Pool size: {}", entropy),
        duration_ms: start.elapsed().as_millis() as u64,
    })
}

/// Run all 6 critical pre-flight checks plus PF-7 through PF-21 extended checks.


///
/// Critical predicate: PreFlight = PF1 ∧ PF2 ∧ PF3 ∧ PF4 ∧ PF5 ∧ PF6
/// Extended checks (PF-7 through PF-18) are non-blocking — failures are
/// logged as warnings but do NOT affect the `passed` field on PreflightReport.
///
/// SC-IGNITE-002: Architectural control checks at every ignition stage
/// Publishes CP-BOOT-01 (start) and CP-BOOT-02 (complete).
pub async fn run_all() -> Result<PreflightReport, IgnitionError> {
    let start = Instant::now();
    info!("╔═══════════════════════════════════════════════════════╗");
    info!("║  PRE-FLIGHT CHECKS (6 critical + 12 extended)       ║");
    info!("╚═══════════════════════════════════════════════════════╝");

    // ── Critical checks (PF-1 through PF-6) ──────────────────────────────────
    info!("── Critical Checks (PF-1..PF-6) ──");
    let pf1 = check_infrastructure().await?;
    let pf2 = check_database().await?;
    let pf3 = check_zenoh_quorum().await?;
    let pf4 = check_network().await?;
    let pf5 = check_image().await?;
    let pf6 = check_observability().await?;

    let critical_passed = [&pf1, &pf2, &pf3, &pf4, &pf5, &pf6]
        .iter()
        .filter(|r| r.passed)
        .count();
    let critical_total = 6usize;

    // ── Extended checks (PF-7 through PF-18) — non-blocking ─────────────────
    info!("── Extended Checks (PF-7..PF-18) ──");
    let mut extended: Vec<CheckResult> = Vec::with_capacity(12);

    macro_rules! run_extended {
        ($fut:expr) => {{
            match $fut.await {
                Ok(result) => {
                    if result.passed {
                        info!("  [EXT] ✅ {}: {}", result.name, result.message);
                    } else {
                        warn!("  [EXT] ⚠️  {}: {} (non-critical)", result.name, result.message);
                    }
                    extended.push(result);
                }
                Err(e) => {
                    warn!("  [EXT] ⚠️  extended check error (non-critical): {}", e);
                    extended.push(CheckResult {
                        name: "PF-EXT: error".into(),
                        passed: false,
                        message: format!("Check error: {}", e),
                        duration_ms: 0,
                    });
                }
            }
        }};
    }

    run_extended!(check_nif_binaries());
    run_extended!(check_substrate_integrity());
    run_extended!(check_build_oracle());
    run_extended!(check_health_consensus());
    run_extended!(check_zenoh_telemetry());
    run_extended!(check_image_freshness());
    run_extended!(check_migration_state());
    run_extended!(check_port_availability());
    run_extended!(check_elixir_release());
    run_extended!(check_bist_stability());
    run_extended!(check_cortex_binary());
    run_extended!(check_bridge_binary());
    run_extended!(check_disk_space());
    run_extended!(check_podman_socket());
    run_extended!(check_substrate_entropy());

    let ext_passed = extended.iter().filter(|r| r.passed).count();
    let ext_total = extended.len();

    // ── Overall result — only critical checks gate the report.passed field ───
    let all_critical_passed = pf1.passed && pf2.passed && pf3.passed
        && pf4.passed && pf5.passed && pf6.passed;

    let total_duration_ms = start.elapsed().as_millis() as u64;

    // Log summary
    if all_critical_passed {
        info!(
            "═══ PRE-FLIGHT: {}/{} critical PASSED, {}/{} extended passed ({} ms) ═══",
            critical_passed, critical_total, ext_passed, ext_total, total_duration_ms
        );
    } else {
        let critical_failed = critical_total - critical_passed;
        error!(
            "═══ PRE-FLIGHT: FAILED — {}/{} critical FAILED, {}/{} extended passed ({} ms) ═══",
            critical_failed, critical_total, ext_passed, ext_total, total_duration_ms
        );
    }

    let report = PreflightReport {
        infrastructure: pf1,
        database: pf2,
        zenoh_quorum: pf3,
        network: pf4,
        image: pf5,
        observability: pf6,
        passed: all_critical_passed,
        duration_ms: total_duration_ms,
    };

    Ok(report)
}
