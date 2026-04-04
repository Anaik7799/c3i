#![allow(warnings)]
//! # Indrajaal Planning Daemon — SIL-6 Biomorphic Mesh Task Authority
//!
//! ## Fractal Position
//! | Dimension | Value |
//! |-----------|-------|
//! | Layer     | L5-Cognitive (Task & Intent Authority) |
//! | Element   | sa-plan |
//! | VSM       | S4-Intelligence |
//!
//! ## STAMP: SC-TODO-001, SC-ZMOF-001
//!
//! ## Architecture
//! Single-binary Rust daemon replacing F# Cepaf.Planning.CLI.
//! It manages the SQLite `planning.db` and generates `PROJECT_TODOLIST.md`.

mod errors;
mod tui;
mod types;
mod zenoh_telemetry;
mod cli;
mod db;
mod markdown;

use clap::{Parser, Subcommand};
use log::{error, info, warn};
use std::time::Instant;

const VERSION: &str = env!("CARGO_PKG_VERSION");

#[derive(Parser)]
#[command(
    name = "sa-plan",
    version,
    about = "Indrajaal SIL-6 Biomorphic Mesh Planning Daemon",
    long_about = "Authoritative Task Management for the SIL-6 mesh.\n\n\
                  Source: Cepaf.Planning.CLI\n\
                  STAMP: SC-TODO-001"
)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// List all active and pending tasks
    Status,
    /// Add a new task to the database
    Add {
        title: String,
        priority: String,
    },
    /// Update an existing task's status
    Update {
        id: String,
        status: String,
    },
    /// Interactive TUI Dashboard for Task Management
    Dashboard,
    /// Synchronize the PROJECT_TODOLIST.md artifact with the database
    Sync,
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();
    let start = Instant::now();

    let mut is_dashboard = false;
    if let Commands::Dashboard = cli.command {
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

    if !is_dashboard {
        info!("╔═══════════════════════════════════════════════════════╗");
        info!("║  INDRAJAAL PLANNING DAEMON v{}                  ║", VERSION);
        info!("║  SIL-6 Task & Intent Authority                      ║");
        info!("╚═══════════════════════════════════════════════════════╝");
    }

    let result = match cli.command {
        Commands::Status => cli::cmd_status().await,
        Commands::Add { title, priority } => cli::cmd_add(&title, &priority).await,
        Commands::Update { id, status } => cli::cmd_update(&id, &status).await,
        Commands::Dashboard => cli::cmd_dashboard().await,
        Commands::Sync => cli::cmd_sync().await,
    };

    match result {
        Ok(_) => {
            if !is_dashboard {
                info!("✨ Planning operation complete in {} ms", start.elapsed().as_millis());
            }
        }
        Err(e) => {
            error!("❌ Planning operation failed: {}", e);
            std::process::exit(1);
        }
    }
}
