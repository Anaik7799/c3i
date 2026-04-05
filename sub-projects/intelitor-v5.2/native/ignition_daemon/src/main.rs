#![allow(warnings)]
//! # Indrajaal Ignition Daemon — SIL-6 Biomorphic Mesh Pre-Flight & Boot

mod apoptosis;
mod artifacts;
mod build;
mod build_oracle;
mod build_stream;
mod cascade;
mod config_bridge;
mod connectivity;
mod cpm;
mod dag;
mod digital_twin;
mod errors;
mod governor;
mod health;
mod health_orchestra;
mod hysteresis;
mod launch;
mod mcp_bridge;
mod mutation_gate;
mod nif_validator;
mod ooda_cache;
mod ooda_supervisor;
mod openrouter;
mod partition;
mod podman;
mod preflight;
mod recovery;
mod robust_launch;
mod rule_engine;
mod security;
mod seven_level_rca;
mod substrate_guard;
mod tui;
mod tui_tests;
mod types;
mod verify;
mod zenoh_telemetry;

// New Operational Modules (Migrated from F#)
mod down;
mod scour;
mod listen;
mod logs;
mod genotype;
mod mesh;
mod mojo;
mod stabilize;
mod multiverse;

use clap::{Parser, Subcommand};
use log::{error, info, warn};
use std::path::Path;
use std::time::Instant;

use types::{HealthCheckType, LaunchMode};

const VERSION: &str = env!("CARGO_PKG_VERSION");

#[derive(Parser)]
#[command(name = "ignition", version)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    Preflight,
    Launch {
        #[arg(long, value_enum, default_value_t = LaunchMode::Prod)]
        env: LaunchMode,
        #[arg(long, default_value = "")]
        test_args: String,
    },
    Verify {
        #[arg(long, value_enum, default_value_t = LaunchMode::Prod)]
        env: LaunchMode,
    },
    Full {
        #[arg(long, value_enum, default_value_t = LaunchMode::Prod)]
        env: LaunchMode,
        #[arg(long, default_value = "")]
        test_args: String,
    },
    Status,
    TuiTest,
    Dashboard {
        #[arg(long, default_value_t = false)]
        auto_boot: bool,
        #[arg(long, default_value_t = false)]
        test_ui: bool,
    },
    SplitTest,
    OpsTest,
    Observer,
    Build {
        #[arg(long)]
        container: Option<String>,
        #[arg(long, default_value_t = false)]
        force: bool,
    },
    Ooda {
        #[arg(long, default_value_t = 100)]
        interval: u64,
        #[arg(long, default_value_t = 100)]
        cycles: u32,
    },
    Rca {
        issue_description: String,
        #[arg(long, default_value_t = false)]
        ai: bool,
    },
    Cpm,
    Twin,
    Config {
        #[arg(long, default_value_t = false)]
        sync: bool,
    },
    
    // --- Migrated Lifecycle Commands ---
    /// Gracefully shutdown the 16-container mesh
    Down,
    /// Nuclear clean: remove containers and prune volumes
    Scour,
    /// Raw Zenoh payload listener for debugging
    Listen {
        /// Optional Zenoh key expression (default: indrajaal/**)
        #[arg(short, long)]
        pattern: Option<String>,
    },
    /// Stream logs from all 16 containers simultaneously
    Logs {
        /// Follow log output
        #[arg(short, long, default_value_t = false)]
        follow: bool,
        /// Number of lines to show from the end
        #[arg(short, long, default_value_t = 50)]
        tail: u32,
    },
    /// Immediate Apoptosis trigger (Emergency Stop)
    Emergency,
    /// Synthesize SIL-6 Genotype (DNA)
    Genotype,
    /// Display Ecosystem Topology
    Mesh,
    /// State Stabilization (Halt mutations)
    Stabilize,
    /// Multiverse Federation Sync
    Multiverse,
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();
    let start = Instant::now();

    let mut is_dashboard = false;
    match cli.command {
        Commands::Dashboard { .. }
        | Commands::SplitTest
        | Commands::OpsTest
        | Commands::Observer
        | Commands::TuiTest
        | Commands::Listen { .. }
        | Commands::Logs { .. } => {
            is_dashboard = true;
        }
        _ => {}
    }

    if is_dashboard {
        tui_logger::init_logger(log::LevelFilter::Info).unwrap();
        tui_logger::set_default_level(log::LevelFilter::Info);
    } else {
        env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
            .format_timestamp_millis()
            .init();
    }

    if !is_dashboard {
        info!("╔═══════════════════════════════════════════════════════╗");
        info!("║  INDRAJAAL IGNITION DAEMON v{}                  ║", VERSION);
        info!("║  SIL-6 Biomorphic Mesh — Pre-Flight & Boot          ║");
        info!("╚═══════════════════════════════════════════════════════╝");
    }

    let result = match cli.command {
        Commands::Preflight => cmd_preflight().await,
        Commands::Launch { env, test_args } => {
            let _telemetry = zenoh_telemetry::ZenohTelemetry::new().await;
            cmd_launch(env, &test_args).await
        }
        Commands::Verify { env } => {
            let _telemetry = zenoh_telemetry::ZenohTelemetry::new().await;
            cmd_verify(env).await
        }
        Commands::Full { env, test_args } => {
            let _telemetry = zenoh_telemetry::ZenohTelemetry::new().await;
            cmd_full(env, &test_args).await
        }
        Commands::Status => cmd_status().await,
        Commands::TuiTest => tui_tests::run_tui_harness().await,
        Commands::Dashboard { auto_boot, test_ui } => {
            let _telemetry = zenoh_telemetry::ZenohTelemetry::new().await;
            if auto_boot {
                tokio::spawn(async move {
                    if let Err(e) = cmd_full(LaunchMode::Prod, "").await {
                        error!("❌ Ignition failed: {}", e);
                    }
                });
            }
            cmd_dashboard(test_ui).await
        }
        Commands::SplitTest => cmd_split_test().await,
        Commands::OpsTest => cmd_ops_test().await,
        Commands::Observer => cmd_observer().await,
        Commands::Build { container, force } => cmd_build(container, force).await,
        Commands::Ooda { interval, cycles } => cmd_ooda(interval, cycles).await,
        Commands::Rca { issue_description, ai } => cmd_rca(&issue_description, ai).await,
        Commands::Cpm => cmd_cpm().await,
        Commands::Twin => cmd_twin().await,
        Commands::Config { sync } => cmd_config(sync).await,
        
        // Handlers for migrated commands
        Commands::Down => down::run_down().await,
        Commands::Scour => scour::run_scour().await,
        Commands::Listen { pattern } => listen::run_listen(pattern).await,
        Commands::Logs { follow, tail } => logs::run_logs(follow, tail).await,
        Commands::Emergency => apoptosis::emergency_stop().await,
        Commands::Genotype => genotype::run_genotype().await,
        Commands::Mesh => mesh::run_mesh().await,
        Commands::Stabilize => stabilize::run_stabilize().await,
        Commands::Multiverse => multiverse::run_multiverse().await,
    };

    match result {
        Ok(_) => {
            if !is_dashboard {
                info!("✨ Operation complete in {} ms", start.elapsed().as_millis());
            }
        }
        Err(e) => {
            error!("❌ Operation failed: {}", e);
            std::process::exit(1);
        }
    }
}

async fn cmd_preflight() -> Result<(), errors::IgnitionError> {
    preflight::run_all().await.map(|_| ())
}

async fn cmd_launch(mode: LaunchMode, test_args: &str) -> Result<(), errors::IgnitionError> {
    match mode {
        LaunchMode::Prod => launch::launch_mesh().await,
        LaunchMode::Test => launch::launch_test_app(test_args).await.map(|_| ()),
    }
}

async fn cmd_verify(mode: LaunchMode) -> Result<(), errors::IgnitionError> {
    verify::run_all().await.map(|_| ())
}

async fn cmd_full(mode: LaunchMode, test_args: &str) -> Result<(), errors::IgnitionError> {
    cmd_preflight().await?;
    cmd_launch(mode, test_args).await?;
    cmd_verify(mode).await
}

async fn cmd_status() -> Result<(), errors::IgnitionError> {
    info!("═══ CPU GOVERNOR ═══");
    info!("{}", governor::status().await);
    Ok(())
}

async fn cmd_dashboard(test_ui: bool) -> Result<(), errors::IgnitionError> {
    tui::run_dashboard(test_ui).await
}

async fn cmd_split_test() -> Result<(), errors::IgnitionError> {
    info!("Split-test not fully implemented");
    Ok(())
}

async fn cmd_ops_test() -> Result<(), errors::IgnitionError> {
    info!("Ops-test not fully implemented");
    Ok(())
}

async fn cmd_observer() -> Result<(), errors::IgnitionError> {
    zenoh_telemetry::run_observer().await
}

async fn cmd_build(_container: Option<String>, _force: bool) -> Result<(), errors::IgnitionError> {
    info!("Build not fully implemented in CLI");
    Ok(())
}

async fn cmd_ooda(interval: u64, _cycles: u32) -> Result<(), errors::IgnitionError> {
    let mut config = ooda_supervisor::SupervisorConfig::default();
    config.cycle_interval_ms = interval;
    let mut supervisor = ooda_supervisor::OodaSupervisor::new(config);
    supervisor.start_loop().await
}

async fn cmd_rca(_issue: &str, _ai: bool) -> Result<(), errors::IgnitionError> {
    info!("RCA not fully implemented in CLI");
    Ok(())
}

async fn cmd_cpm() -> Result<(), errors::IgnitionError> {
    info!("CPM not fully implemented");
    Ok(())
}

async fn cmd_twin() -> Result<(), errors::IgnitionError> {
    info!("Twin check not fully implemented");
    Ok(())
}

async fn cmd_config(_sync: bool) -> Result<(), errors::IgnitionError> {
    info!("Config bridge not fully implemented");
    Ok(())
}
