//! # Indrajaal Ignition Daemon — SIL-6 Biomorphic Mesh Pre-Flight & Boot
//!
//! ## Fractal Position
//! | Dimension | Value |
//! |-----------|-------|
//! | Layer     | L4-System (Container Orchestration) |
//! | Element   | Ignition / Boot / Verification |
//! | VSM       | S1-Operations |
//!
//! ## STAMP: SC-IGNITE-001 to SC-IGNITE-010, SC-BOOT-001 to SC-BOOT-010
//!
//! ## Architecture
//! Single-binary Rust daemon replacing F# PanopticIgnition.fs and
//! shell scripts (capture-ignition.sh, cpu-governor.sh).
//!
//! ## Modules
//! - types: Constants (33), enums, structs from F# Core.fs + journal spec
//! - errors: Error types with thiserror
//! - podman: Podman CLI wrapper with timeouts
//! - health: TCP, pg_isready, HTTP, Redis, FPPS, quorum checks
//! - preflight: 18 pre-flight checks (PF-1 to PF-18)
//! - launch: App container + cepaf-bridge creation
//! - verify: 14-point post-launch verification
//! - governor: CPU measurement + adaptive parallelism
//! - substrate_guard: Axiom 0.1 enforcement — _build/deps contamination detection
//! - nif_validator: ELF binary inspection, glibc/musl mismatch detection
//! - build_oracle: F# BuildHistory.db reader, EMA-based adaptive timeouts
//! - health_orchestra: FPPS 5-method consensus (Running+Port+Service+Quorum+Twin)
//! - recovery: Automated recovery playbooks for top-5 failure modes
//!
//! ## Usage
//! ```
//! ignition preflight                          # Run 18 pre-flight checks + substrate guard + NIF validation
//! ignition launch                             # Pre-flight + launch app + bridge (production)
//! ignition launch --env test                  # Pre-flight + launch test container (isolated)
//! ignition launch --env test --test-args "--only wallaby"  # Test container with filter
//! ignition verify                             # 14-point verification + FPPS consensus
//! ignition verify --env test                  # Verify test container health
//! ignition full                               # Pre-flight + launch + verify (production)
//! ignition full --env test                    # Full test ignition sequence
//! ignition status                             # CPU governor + swarm + build oracle + recovery playbooks
//! ```
//!
//! v21.3.2-SIL6

mod errors;
mod governor;
mod health;
mod launch;
mod podman;
mod preflight;
mod tui;
mod types;
mod verify;

// ─── W1-W5: Stabilization modules (SC-IGNITE-001 to SC-IGNITE-010) ───
mod nif_validator;      // W1: ELF binary inspection, glibc/musl detection, cargo check
mod substrate_guard;    // W1: Axiom 0.1 enforcement, _build/deps contamination
mod build_oracle;       // W2: F# BuildHistory.db reader, EMA-based adaptive timeouts
mod health_orchestra;   // W3: FPPS 5-method consensus replacing single-probe health
mod recovery;           // W5: Automated recovery playbooks for top-5 failure modes

// ─── W6-W8: Robustness modules (Ideas #16, #21, #29, #30, #32, #34, #46) ───
mod cascade;            // W6: Cascading failure containment, checkpointing, rollback
mod connectivity;       // W7: Inter-container connectivity matrix, Zenoh mesh topology
mod robust_launch;      // W8: Atomic tier commit, idempotent launch, emergency drain
mod partition;          // W9: Network partition detection, split-brain prevention, fencing
use clap::{Parser, Subcommand};
use log::{error, info, warn};
use std::path::Path;
use std::time::Instant;

use types::{HealthCheckType, LaunchMode};

const VERSION: &str = env!("CARGO_PKG_VERSION");

#[derive(Parser)]
#[command(
    name = "ignition",
    version,
    about = "Indrajaal SIL-6 Biomorphic Mesh Ignition Daemon",
    long_about = "Pre-flight checks, container launch, and post-launch verification \
                  for the 16-container SIL-6 biomorphic mesh.\n\n\
                  Source: PanopticIgnition.fs, capture-ignition.sh, cpu-governor.sh\n\
                  STAMP: SC-IGNITE-001 to SC-IGNITE-010"
)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Run 6 pre-flight checks (PF-1 to PF-6)
    Preflight,
    /// Pre-flight + launch app container + cepaf-bridge
    Launch {
        /// Launch mode: prod (default) or test
        #[arg(long, value_enum, default_value_t = LaunchMode::Prod)]
        env: LaunchMode,

        /// Arguments passed to `mix test` (only used in test mode, e.g. "--only wallaby")
        #[arg(long, default_value = "")]
        test_args: String,
    },
    /// Run 14 post-launch verification checks
    Verify {
        /// Verify mode: prod (default) or test — selects correct ports/container
        #[arg(long, value_enum, default_value_t = LaunchMode::Prod)]
        env: LaunchMode,
    },
    /// Full ignition sequence: preflight → launch → verify
    Full {
        /// Launch mode: prod (default) or test
        #[arg(long, value_enum, default_value_t = LaunchMode::Prod)]
        env: LaunchMode,

        /// Arguments passed to `mix test` (only used in test mode)
        #[arg(long, default_value = "")]
        test_args: String,
    },
    /// Show CPU governor status and swarm state
    Status,
    /// Interactive TUI dashboard (SC-HMI-010 Color Rich)
    Dashboard {
        /// Automatically start the full ignition sequence in the background
        #[arg(long, default_value_t = false)]
        auto_boot: bool,
        /// Run 50 cycles of UI testing and exit
        #[arg(long, default_value_t = false)]
        test_ui: bool,
    },
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();
    let start = Instant::now();

    // Do not print directly to stdout here if we are starting the dashboard
    let mut is_dashboard = false;
    if let Commands::Dashboard { .. } = cli.command {
        is_dashboard = true;
    }

    if is_dashboard {
        tui_logger::init_logger(log::LevelFilter::Info).unwrap();
        tui_logger::set_default_level(log::LevelFilter::Info);
    } else {
        env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
            .format_timestamp_millis()
            .init();
    }

    let mut show_start_banner = !is_dashboard;

    if show_start_banner {
        info!("╔═══════════════════════════════════════════════════════╗");
        info!("║  INDRAJAAL IGNITION DAEMON v{}                  ║", VERSION);
        info!("║  SIL-6 Biomorphic Mesh — Pre-Flight & Boot          ║");
        info!("╚═══════════════════════════════════════════════════════╝");
    }

    let result = match cli.command {
        Commands::Preflight => cmd_preflight().await,
        Commands::Launch { env, test_args } => cmd_launch(env, &test_args).await,
        Commands::Verify { env } => cmd_verify(env).await,
        Commands::Full { env, test_args } => cmd_full(env, &test_args).await,
        Commands::Status => cmd_status().await,
        Commands::Dashboard { auto_boot, test_ui } => {
            if auto_boot {
                // Spawn full ignition in background
                tokio::spawn(async move {
                    info!("╔═══════════════════════════════════════════════════════╗");
                    info!("║  INDRAJAAL IGNITION DAEMON v{}                  ║", VERSION);
                    info!("║  SIL-6 Biomorphic Mesh — Pre-Flight & Boot          ║");
                    info!("╚═══════════════════════════════════════════════════════╝");
                    if let Err(e) = cmd_full(LaunchMode::Prod, "").await {
                        error!("❌ Ignition failed: {}", e);
                    }
                });
            }
            cmd_dashboard(test_ui).await
        },
    };

    match result {
        Ok(()) => {
            info!(
                "✅ Ignition complete ({:.1}s)",
                start.elapsed().as_secs_f64()
            );
        }
        Err(e) => {
            error!("❌ Ignition failed: {}", e);
            std::process::exit(1);
        }
    }
}

async fn cmd_preflight() -> Result<(), errors::IgnitionError> {
    // ─── W1: Substrate Guard (Axiom 0.1 — host _build/deps contamination) ───
    info!("── Substrate Guard (SC-IGNITE-002, Axiom 0.1) ──");
    let project_root = Path::new(".");
    let substrate = substrate_guard::run_all_checks(project_root).await?;
    if !substrate.all_passed {
        for check in &substrate.checks {
            if !check.passed {
                error!("  [FAIL] {}: {}", check.name, check.detail);
            }
        }
        let cmds = substrate_guard::remediation_commands(&substrate);
        if !cmds.is_empty() {
            warn!("  Remediation commands:");
            for cmd in &cmds {
                warn!("    $ {}", cmd);
            }
        }
        return Err(errors::IgnitionError::PreflightFailed(
            "Substrate contamination detected — host _build/deps must be removed".into(),
        ));
    }
    info!("  ✓ Substrate clean — no host _build/deps contamination");

    // ─── Standard pre-flight checks (PF-1 through PF-18) ───
    info!("── Pre-Flight Checks ──");
    let report = preflight::run_all().await?;
    if !report.passed {
        return Err(errors::IgnitionError::PreflightFailed(
            "One or more pre-flight checks failed".into(),
        ));
    }

    // ─── W1: NIF Validator (ELF binary inspection, glibc/musl detection) ───
    info!("── NIF Validation (SC-NIF-006, SC-IGNITE-002) ──");
    let nif_containers = ["indrajaal-ex-app-1", "cepaf-bridge"];
    for container in &nif_containers {
        match nif_validator::validate_all_nifs(container).await {
            Ok(results) => {
                let valid = results.iter().filter(|r| r.is_valid).count();
                let total = results.len();
                if valid == total {
                    info!("  ✓ {} — {}/{} NIFs valid", container, valid, total);
                } else {
                    warn!("  ⚠ {} — {}/{} NIFs valid", container, valid, total);
                    for r in results.iter().filter(|r| !r.is_valid) {
                        warn!("    {} — {} errors: {:?}", r.path.display(), r.nif_name, r.errors);
                    }
                }
                // Check glibc/musl consistency
                let issues = nif_validator::check_libc_consistency(&results);
                for issue in &issues {
                    warn!("  ⚠ {}: {}", container, issue);
                }
            }
            Err(e) => {
                // NIF validation failure is a warning, not a hard stop (container may not exist yet)
                warn!("  ⚠ {} — NIF validation skipped: {}", container, e);
            }
        }
    }

    Ok(())
}

async fn cmd_launch(mode: LaunchMode, test_args: &str) -> Result<(), errors::IgnitionError> {
    info!("Launch mode: {}", mode);

    // Pre-flight first (includes substrate guard + NIF validation)
    cmd_preflight().await?;

    // CPU governor check
    info!("[Governor] {}", governor::status().await);

    // ─── W2: Build Oracle — display adaptive timeout predictions ───
    info!("── Build Oracle (SC-IGNITE-005) ──");
    let timeouts = build_oracle::load_timeouts();
    if timeouts.is_empty() {
        info!("  No EMA data yet — using default timeouts (first build)");
    } else {
        for (name, at) in &timeouts {
            info!(
                "  {} — EMA timeout {}ms (source: {:?})",
                name, at.ema_timeout_ms, at.source
            );
        }
    }

    match mode {
        LaunchMode::Prod => {
            // Use the new authoritative DAG-based mesh ignition
            launch::launch_mesh().await?;
        }
        LaunchMode::Test => {
            // Launch test container (isolated, separate ports/IP/name)
            info!("── Test Container Launch (SC-ENV-COMPILE-005 to SC-ENV-COMPILE-007) ──");
            let test_id = launch::launch_test_app(test_args).await?;
            info!("Test container: {}", test_id);
            // No bridge needed for test mode — tests run inside the container
        }
    }

    Ok(())
}

async fn cmd_verify(mode: LaunchMode) -> Result<(), errors::IgnitionError> {
    info!("Verify mode: {}", mode);

    // ─── Standard 14-point verification ───
    info!("── Standard Verification ──");
    let report = verify::run_all().await?;

    info!(
        "Verification: {}/{} passed",
        report.passed_count, report.total_count
    );
    info!("State vector: {:?}", report.state_vector.as_array());

    if !report.all_passed {
        let failed: Vec<_> = report
            .checks
            .iter()
            .filter(|c| !c.passed)
            .map(|c| c.name.clone())
            .collect();
        error!("Failed checks: {:?}", failed);
    }

    // ─── W3: FPPS 5-Method Consensus (SC-SIL4-006, Omega-5) ───
    info!("── FPPS 5-Method Consensus (SC-SIL4-006) ──");
    let consensus_targets: Vec<(&str, u16, HealthCheckType)> = match mode {
        LaunchMode::Prod => vec![
            ("indrajaal-ex-app-1", 4000, HealthCheckType::Http("http://localhost:4000/health".into())),
            ("indrajaal-db-prod", 5433, HealthCheckType::PgIsReady),
            ("indrajaal-obs-prod", 4317, HealthCheckType::TcpPort(4317)),
            ("zenoh-router", 7447, HealthCheckType::TcpPort(7447)),
            ("cepaf-bridge", 4010, HealthCheckType::TcpPort(4010)),
            ("indrajaal-cortex", 4005, HealthCheckType::TcpPort(4005)),
        ],
        LaunchMode::Test => vec![
            (types::TEST_CONTAINER_NAME, types::TEST_PHOENIX_PORT, HealthCheckType::Http(
                format!("http://localhost:{}/health", types::TEST_HEALTH_PORT)
            )),
            ("indrajaal-db-prod", 5433, HealthCheckType::PgIsReady),
            ("zenoh-router", 7447, HealthCheckType::TcpPort(7447)),
        ],
    };

    let mut any_failed = false;
    for (container, port, check_type) in &consensus_targets {
        let hc = health_orchestra::check_consensus(container, *port, check_type).await;
        if hc.consensus_reached {
            info!(
                "  ✓ {} — {}/{} methods agree (consensus)",
                container, hc.agreed, hc.total
            );
        } else {
            warn!(
                "  ⚠ {} — {}/{} methods agree (NO consensus)",
                container, hc.agreed, hc.total
            );
            for m in &hc.methods {
                if !m.passed {
                    warn!("    [FAIL] {:?} — {} ({}ms)", m.method, m.detail, m.latency_ms);
                }
            }

            // ─── W5: Auto-recover containers that fail consensus ───
            any_failed = true;
            info!("  → Attempting auto-recovery for {} ...", container);
            let rr = recovery::auto_recover(container).await;
            if rr.success {
                info!("    ✓ Recovery succeeded: {}", rr.detail);
            } else {
                warn!("    ⚠ Recovery failed: {}", rr.detail);
            }
        }
    }

    if any_failed {
        warn!("Some containers failed FPPS consensus — check warnings above");
    }

    Ok(())
}

async fn cmd_full(mode: LaunchMode, test_args: &str) -> Result<(), errors::IgnitionError> {
    info!("Full ignition mode: {}", mode);

    info!("═══ PHASE 1: PRE-FLIGHT (substrate + NIF + 18 checks) ═══");
    cmd_preflight().await?;

    info!("═══ PHASE 2: LAUNCH (adaptive timeouts) ═══");
    // CPU governor
    info!("[Governor] {}", governor::status().await);

    // Build oracle adaptive timeouts
    let timeouts = build_oracle::load_timeouts();
    if !timeouts.is_empty() {
        info!("── Build Oracle EMA timeouts ──");
        for (name, at) in &timeouts {
            info!("  {} — {}ms (source: {:?})", name, at.ema_timeout_ms, at.source);
        }
    }

    match mode {
        LaunchMode::Prod => {
            // Use the new authoritative DAG-based mesh ignition
            launch::launch_mesh().await?;
        }
        LaunchMode::Test => {
            // Launch test container (isolated)
            info!("── Test Container Launch ──");
            let _test_id = launch::launch_test_app(test_args).await?;
        }
    }

    info!("═══ PHASE 3: VERIFY (14-point + FPPS consensus) ═══");
    cmd_verify(mode).await?;

    // ─── W2: Build Oracle health summary ───
    let health = build_oracle::check_health();
    info!(
        "Build Oracle: db_exists={}, history_rows={}, ema_rows={}",
        health.db_exists, health.build_history_rows, health.ema_rows
    );

    let phase_label = match mode {
        LaunchMode::Prod => "FULL IGNITION SEQUENCE COMPLETE",
        LaunchMode::Test => "TEST IGNITION SEQUENCE COMPLETE",
    };
    info!("╔═══════════════════════════════════════════════════════╗");
    info!("║  ✅ {:<42} ║", phase_label);
    info!("╚═══════════════════════════════════════════════════════╝");

    Ok(())
}

async fn cmd_status() -> Result<(), errors::IgnitionError> {
    info!("═══ CPU GOVERNOR ═══");
    info!("{}", governor::status().await);

    info!("═══ SWARM STATUS ═══");
    let containers = [
        "zenoh-router", "zenoh-router-1", "zenoh-router-2", "zenoh-router-3",
        "indrajaal-db-prod", "indrajaal-obs-prod", "indrajaal-cortex",
        "cepaf-bridge", "indrajaal-ex-app-1", "indrajaal-ex-app-2",
        "indrajaal-ex-app-3", "indrajaal-chaya",
        "indrajaal-ollama", "indrajaal-mojo",
        "indrajaal-ml-runner-1", "indrajaal-ml-runner-2",
    ];

    for name in &containers {
        let status = podman::container_status(name)
            .await
            .unwrap_or_else(|_| "not found".into());
        let ip = podman::container_ip(name).await.unwrap_or_default();
        info!("  {:<25} {} {}", name, status, ip);
    }

    // ─── W2: Build Oracle Status ───
    info!("═══ BUILD ORACLE (SC-IGNITE-005) ═══");
    let health = build_oracle::check_health();
    info!(
        "  DB: exists={}, wal={}, history_rows={}, ema_rows={}",
        health.db_exists, health.wal_mode, health.build_history_rows, health.ema_rows
    );
    if let Some(newest) = &health.newest_record {
        info!("  Latest build: {}", newest);
    }

    if let Some(conn) = build_oracle::open_db()? {
        match build_oracle::read_all_ema(&conn) {
            Ok(emas) => {
                if emas.is_empty() {
                    info!("  No EMA data yet (no builds recorded)");
                } else {
                    info!("  ┌─────────────────────────┬─────────────┬────────┐");
                    info!("  │ Container               │ EMA (ms)    │ Builds │");
                    info!("  ├─────────────────────────┼─────────────┼────────┤");
                    for ema in &emas {
                        info!(
                            "  │ {:<23} │ {:>11.0} │ {:>6} │",
                            ema.container_name, ema.ema_duration_ms, ema.total_builds
                        );
                    }
                    info!("  └─────────────────────────┴─────────────┴────────┘");
                }
            }
            Err(e) => warn!("  EMA read failed: {}", e),
        }
    }

    // ─── W5: Recovery Playbooks Summary ───
    info!("═══ RECOVERY PLAYBOOKS ═══");
    let playbooks = recovery::all_playbooks();
    for pb in &playbooks {
        info!(
            "  {:?} (RPN {}) — {} steps, max {} retries, escalation: {}",
            pb.failure_mode,
            pb.rpn,
            pb.steps.len(),
            pb.max_retries,
            pb.escalation
        );
    }

    Ok(())
}

async fn cmd_dashboard(test_ui: bool) -> Result<(), errors::IgnitionError> {
    tui::run_dashboard(test_ui).await
}
