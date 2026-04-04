use anyhow::Result;
use clap::{Parser, ValueEnum};
use colored::*;
use std::fs;
use std::path::PathBuf;
use std::process;
use walkdir::WalkDir;

mod checker;
mod config;
mod fixer;
mod report;

use checker::{CheckMode, CheckResult, FileChecker};
use config::CheckerConfig;
use fixer::ConfigFixer;
use report::Report;

#[derive(Parser, Debug)]
#[command(
    name = "indrajaal-env-checker",
    about = "Indrajaal ELIXIR_ERL_OPTIONS Configuration Validator",
    long_about = r#"
Indrajaal SIL-6 Compliant ELIXIR_ERL_OPTIONS Configuration Checker

Validates that all ELIXIR_ERL_OPTIONS configurations include the +fnu flag
for UTF-8 filename encoding compliance. This is MANDATORY per:
- SC-ENV-COMPILE-004: All mix compile MUST have +fnu
- SC-UTF8-001: All ELIXIR_ERL_OPTIONS MUST include +fnu

Exit codes:
  0 - All checks passed (100% compliance)
  1 - Violations found (non-zero violations)
  2 - Error during execution
    "#
)]
struct Args {
    #[arg(short, long, default_value = ".")]
    path: PathBuf,

    #[arg(
        short,
        long,
        default_value = "*.exs,*.ex,*.sh,*.fs,*.fsx,*.nix,Dockerfile*,*.yml,*.yaml"
    )]
    patterns: String,

    #[arg(short, long, default_value = "_build,deps,.git,target,priv")]
    exclude: String,

    #[arg(short, long, default_value = "strict")]
    mode: CheckMode,

    #[arg(short, long, default_value = "false")]
    fix: bool,

    #[arg(short, long, default_value = "text")]
    format: OutputFormat,

    #[arg(short, long, default_value = "false")]
    violations_only: bool,

    #[arg(short, long, default_value = "false")]
    quiet: bool,

    #[arg(long, default_value = "true")]
    fail_on_violation: bool,

    #[arg(long)]
    export: Option<PathBuf>,
}

#[derive(Debug, Clone, ValueEnum)]
enum OutputFormat {
    Text,
    Json,
    Compact,
    Github,
}

fn main() -> Result<()> {
    let args = Args::parse();

    let config = CheckerConfig::load().unwrap_or_default();
    let checker = FileChecker::new(&config);
    let fixer = ConfigFixer::new();

    let pb = if !args.quiet {
        Some(indicatif::ProgressBar::new_spinner())
    } else {
        None
    };

    if let Some(ref p) = pb {
        p.set_style(
            indicatif::ProgressStyle::default_spinner()
                .template("{spinner:.cyan} {msg}")
                .unwrap(),
        );
        p.set_message("Scanning files...");
    }

    let patterns: Vec<&str> = args.patterns.split(',').collect();
    let exclude: Vec<&str> = args.exclude.split(',').collect();

    let mut violations: Vec<CheckResult> = Vec::new();
    let mut checked_files: usize = 0;
    let mut total_files_with_env: usize = 0;

    for entry in WalkDir::new(&args.path)
        .follow_links(false)
        .into_iter()
        .filter_entry(|e| {
            let path = e.path();
            !exclude
                .iter()
                .any(|ex| path.to_string_lossy().contains(&format!("/{}/", ex)))
        })
        .filter_map(|e| e.ok())
    {
        let path = entry.path();

        if !path.is_file() {
            continue;
        }

        let filename = path.file_name().and_then(|n| n.to_str()).unwrap_or("");

        let matches_pattern = patterns.iter().any(|p| {
            if p.starts_with('*') {
                filename.ends_with(&p[1..])
            } else {
                filename == *p
            }
        });

        if !matches_pattern {
            continue;
        }

        checked_files += 1;

        if let Ok(content) = fs::read_to_string(path) {
            if content.contains("ELIXIR_ERL_OPTIONS") {
                total_files_with_env += 1;
                let file_buf = path.to_path_buf();
                let results = checker.check_content(&content, &file_buf, &args.mode);
                violations.extend(results);
            }
        }
    }

    if let Some(p) = pb {
        p.finish_with_message("Scan complete".green().to_string());
    }

    if args.fix && !violations.is_empty() {
        if !args.quiet {
            println!(
                "\n{} Fixing {} violations...",
                "🔧".cyan(),
                violations.len()
            );
        }

        for violation in &violations {
            if let Err(e) = fixer.fix_file(violation) {
                eprintln!("{} Error fixing {:?}: {}", "❌".red(), violation.file, e);
            }
        }

        violations.clear();
        for entry in WalkDir::new(&args.path)
            .follow_links(false)
            .into_iter()
            .filter_map(|e| e.ok())
        {
            let path = entry.path();
            if !path.is_file() {
                continue;
            }

            if let Ok(content) = fs::read_to_string(path) {
                if content.contains("ELIXIR_ERL_OPTIONS") {
                    let file_buf = path.to_path_buf();
                    let results = checker.check_content(&content, &file_buf, &args.mode);
                    violations.extend(results);
                }
            }
        }

        if !args.quiet {
            println!("{} Fixes applied. Re-scanning...", "✅".green());
        }
    }

    let report = Report::new(violations.clone(), checked_files, total_files_with_env);

    match args.format {
        OutputFormat::Json => {
            println!("{}", report.to_json());
        }
        OutputFormat::Compact => {
            println!("{}", report.to_compact());
        }
        OutputFormat::Github => {
            println!("{}", report.to_github_actions());
        }
        OutputFormat::Text => {
            if !args.quiet {
                println!("\n{}", report.to_text());
            } else if !violations.is_empty() {
                println!("{}", report.to_compact());
            }
        }
    }

    if let Some(path) = &args.export {
        if let Err(e) = fs::write(path, report.to_json()) {
            eprintln!("{} Error exporting to {:?}: {}", "❌".red(), path, e);
        } else if !args.quiet {
            println!("\n{} Exported to {:?}", "📄".cyan(), path);
        }
    }

    let exit_code = if violations.is_empty() {
        if !args.quiet {
            println!(
                "\n{} All {} files with ELIXIR_ERL_OPTIONS are compliant (100% +fnu coverage)",
                "✅".green(),
                total_files_with_env
            );
        }
        0
    } else {
        if !args.quiet {
            eprintln!(
                "\n{} Found {} violations in {} files",
                "❌".red(),
                violations.len(),
                violations
                    .iter()
                    .map(|v| &v.file)
                    .collect::<std::collections::HashSet<_>>()
                    .len()
            );
        }
        if args.fail_on_violation {
            1
        } else {
            0
        }
    };

    process::exit(exit_code);
}
