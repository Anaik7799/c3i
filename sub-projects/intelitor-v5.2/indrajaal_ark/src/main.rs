use clap::{Parser, Subcommand};
use anyhow::Result;
use std::path::PathBuf;

mod crypto;
mod coding;
mod polyglot;

#[derive(Parser)]
#[command(author, version, about)]
#[command(propagate_version = true)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Seal a directory into an Ark (BIOSYNTHESIS)
    Seal {
        /// Input directory to seal
        #[arg(short, long)]
        input: PathBuf,

        /// Output Ark file
        #[arg(short, long)]
        output: PathBuf,

        /// Force overwrite
        #[arg(short, long)]
        force: bool,
    },

    /// Extract an Ark to the filesystem (LYSIS)
    Unseal {
        /// Ark file to extract
        #[arg(short, long)]
        input: PathBuf,

        /// Destination directory
        #[arg(short, long)]
        destination: PathBuf,
    },

    /// Verify integrity without extracting (DIAGNOSIS)
    Verify {
        /// Ark file to check
        #[arg(short, long)]
        input: PathBuf,
    },

    /// Embed this binary into a shell script header (MORPHOGENESIS)
    Biomorph {
        /// The raw binary
        #[arg(short, long)]
        input: PathBuf,

        /// The polyglot output
        #[arg(short, long)]
        output: PathBuf,
    }
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match &cli.command {
        Commands::Seal { input, output, force: _ } => {
            println!(">>> [ARK] Initiating BIOSYNTHESIS...");
            // TODO: Implement Zstd -> RS -> Write
            println!("    Target: {:?}", input);
            println!("    Artifact: {:?}", output);
            Ok(())
        }
        Commands::Unseal { input, destination: _ } => {
            println!(">>> [ARK] Initiating LYSIS...");
            println!("    Source: {:?}", input);
            // TODO: Verify -> Heal -> Decompress
            Ok(())
        }
        Commands::Verify { input: _ } => {
            println!(">>> [ARK] Running DIAGNOSIS...");
            // TODO: BLAKE3 Verification
            Ok(())
        }
        Commands::Biomorph { input, output } => {
            println!(">>> [ARK] Executing MORPHOGENESIS...");
            polyglot::stitch(input, output)?;
            Ok(())
        }
    }
}
