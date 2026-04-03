use anyhow::Result;
use clap::{Parser, Subcommand};
use indrajaal_ark::ArkManager;
use std::path::PathBuf;

/// Indrajaal.Ark: Deep Native Archive & Biomorphic Seed
#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Create a new Ark archive from a directory
    Create {
        /// Source directory
        source: PathBuf,
        /// Output Ark file
        output: PathBuf,
        /// Erasure coding: data shards (default: 10)
        #[arg(short, long, default_value_t = 10)]
        data: usize,
        /// Erasure coding: parity shards (default: 4)
        #[arg(short, long, default_value_t = 4)]
        parity: usize,
    },
    /// Restore a directory from an Ark archive
    Restore {
        /// Input Ark file
        input: PathBuf,
        /// Output directory
        output: PathBuf,
    },
    /// Verify the integrity of an Ark archive
    Verify {
        /// Ark file to verify
        input: PathBuf,
    },
}

fn main() -> Result<()> {
    env_logger::init();
    let cli = Cli::parse();

    match cli.command {
        Commands::Create { source, output, data, parity } => {
            println!("⚓ Creating Ark: {:?} -> {:?}", source, output);
            ArkManager::create(&source, &output, data, parity)?;
            println!("✅ Ark created successfully.");
        }
        Commands::Restore { input, output } => {
            println!("⚓ Restoring Ark: {:?} -> {:?}", input, output);
            ArkManager::restore(&input, &output)?;
            println!("✅ Ark restored successfully.");
        }
        Commands::Verify { input } => {
            println!("⚓ Verifying Ark: {:?}", input);
            let valid = ArkManager::verify(&input)?;
            if valid {
                println!("✅ Ark integrity verified.");
            } else {
                println!("❌ Ark corrupted.");
            }
        }
    }

    Ok(())
}
