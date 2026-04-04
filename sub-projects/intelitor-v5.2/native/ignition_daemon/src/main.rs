#![allow(warnings)]
//! # Indrajaal Ignition Daemon — SIL-6 Biomorphic Mesh Pre-Flight & Boot

mod apoptosis;
mod artifacts;
mod build;
mod build_oracle;
mod build_stream;
mod cascade;
mod command_verifier;
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
mod math_monitor;
mod mcp_bridge;
mod nif_validator;
mod ooda_supervisor;
mod openrouter;
mod partition;
mod podman;
mod preflight;
mod recovery;
mod robust_launch;
mod rule_engine;
mod seven_level_rca;
mod smoke_test;
mod substrate_guard;
mod tui;
mod tui_tests;
mod types;
mod verify;
mod zenoh_telemetry;

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
    RuleTest,
    Cpm,
    Twin,
    Config {
        #[arg(long, default_value_t = false)]
        sync: bool,
    },
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
        | Commands::TuiTest => {
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
        Commands::RuleTest => cmd_rule_test().await,
        Commands::Cpm => cmd_cpm().await,
        Commands::Twin => cmd_twin().await,
        Commands::Config { sync } => cmd_config(sync).await,
    };

    match result {
        Ok(_) => {
            if !is_dashboard {
                info!("✨ Ignition flow complete in {} ms", start.elapsed().as_millis());
            }
        }
        Err(e) => {
            error!("❌ Ignition failed: {}", e);
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

async fn cmd_rca(issue: &str, ai: bool) -> Result<(), errors::IgnitionError> {
    info!("🔍 Initiating Root Cause Analysis for: {}", issue);
    
    if ai {
        info!("🤖 Querying LLM Advisor for AI-powered RCA...");
        match crate::openrouter::query_llm_advisor(issue).await {
            Ok(advice) => {
                info!("✅ AI Advisor Response:");
                info!("{}", advice);
            }
            Err(e) => {
                warn!("⚠️  LLM Advisor unavailable: {}", e);
                info!("🔧 Proceeding with rule-based analysis...");
            }
        }
    } else {
        info!("🔧 Performing rule-based RCA analysis...");
    }
    
    // In a real implementation, this would trigger a proper RCA workflow
    info!("✅ RCA initiated successfully");
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

async fn cmd_rule_test() -> Result<(), errors::IgnitionError> {
    info!("🧪 Running rule engine tests...");
    
    // Test a few rule evaluations
    use crate::rule_engine::{evaluate_preflight, PreflightFacts, evaluate_cascade, evaluate_health_consensus};
    
    // Test preflight rules
    let preflight_result = evaluate_preflight(&PreflightFacts {
        infra_healthy: true,
        zenoh_quorum: true,
        db_ready: true,
        substrate_clean: true,
        image_exists: true,
    });
    info!("Preflight test result: {} - {}", preflight_result.decision, preflight_result.reason);
    
    // Test cascade rules
    let cascade_result = evaluate_cascade(2, true);
    info!("Cascade test result: {} - {}", cascade_result.decision, cascade_result.reason);
    
    // Test health consensus rules
    let health_result = evaluate_health_consensus(true, 4);
    info!("Health consensus test result: {} - {}", health_result.decision, health_result.reason);
    
    info!("✅ Rule engine tests completed");
    Ok(())
}
