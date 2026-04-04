#![deny(warnings, unused_imports, dead_code)]

//! C3I AG-UI Idea Catalog Generator
//!
//! Generates 200 AG-UI/A2A feature ideas across 10 categories with
//! multi-dimensional scoring (Criticality, Usability, Info Utility, UX/CX).
//! Outputs Markdown or JSON. Optionally publishes rankings to ZMOF via Zenoh.

mod ideas;

use clap::Parser;
use serde::Serialize;
use std::fs::File;
use std::io::Write;
use std::path::PathBuf;

use ideas::{ideas, Idea, CATEGORIES};

// =============================================================================
// CLI
// =============================================================================

#[derive(Parser)]
#[command(name = "c3i_agui_ideas")]
#[command(about = "Generate AG-UI/A2A feature idea catalog with scoring")]
struct Cli {
    /// Output file path
    #[arg(short, long, default_value = "docs/AGUI_200_IDEAS.md")]
    output: PathBuf,

    /// Output format
    #[arg(short, long, default_value = "md", value_parser = ["md", "json"])]
    format: String,

    /// Number of top ideas in summary table
    #[arg(long, default_value = "50")]
    top_n: usize,

    /// Publish rankings to Zenoh ZMOF backplane
    #[arg(long)]
    publish_zenoh: bool,

    /// Verbose output
    #[arg(short, long)]
    verbose: bool,
}

// =============================================================================
// Structured Output
// =============================================================================

#[derive(Clone, Debug, Serialize)]
pub struct ScoredIdea {
    pub id: usize,
    pub title: String,
    pub source: String,
    pub description: String,
    pub zenoh_topic: String,
    pub criticality: u8,
    pub usability: u8,
    pub info_utility: u8,
    pub ux: u8,
    pub total_score: u8,
    pub category_index: usize,
    pub category_name: String,
}

#[derive(Clone, Debug, Serialize)]
pub struct IdeaCatalog {
    pub ideas: Vec<ScoredIdea>,
    pub categories: Vec<CategorySummary>,
    pub top_ideas: Vec<ScoredIdea>,
}

#[derive(Clone, Debug, Serialize)]
pub struct CategorySummary {
    pub index: usize,
    pub name: String,
    pub idea_count: usize,
    pub avg_score: f64,
}

fn build_catalog(top_n: usize) -> IdeaCatalog {
    let raw_ideas = ideas();

    let scored: Vec<ScoredIdea> = raw_ideas
        .iter()
        .map(|i| {
            let cat_idx = category_for_id(i.id);
            let cat_name = CATEGORIES
                .get(cat_idx)
                .map(|c| c.2)
                .unwrap_or("Unknown");
            ScoredIdea {
                id: i.id,
                title: i.title.to_string(),
                source: i.source.to_string(),
                description: i.desc.to_string(),
                zenoh_topic: i.zenoh.to_string(),
                criticality: i.crit,
                usability: i.usab,
                info_utility: i.info,
                ux: i.ux,
                total_score: i.crit + i.usab + i.info + i.ux,
                category_index: cat_idx,
                category_name: cat_name.to_string(),
            }
        })
        .collect();

    let categories: Vec<CategorySummary> = CATEGORIES
        .iter()
        .enumerate()
        .map(|(idx, (start, end, name))| {
            let cat_ideas: Vec<&ScoredIdea> = scored
                .iter()
                .filter(|i| i.id >= *start && i.id <= *end)
                .collect();
            let avg = if cat_ideas.is_empty() {
                0.0
            } else {
                cat_ideas.iter().map(|i| i.total_score as f64).sum::<f64>() / cat_ideas.len() as f64
            };
            CategorySummary {
                index: idx,
                name: name.to_string(),
                idea_count: cat_ideas.len(),
                avg_score: avg,
            }
        })
        .collect();

    let mut sorted = scored.clone();
    sorted.sort_by(|a, b| b.total_score.cmp(&a.total_score).then(a.id.cmp(&b.id)));
    let top_ideas: Vec<ScoredIdea> = sorted.into_iter().take(top_n).collect();

    IdeaCatalog {
        ideas: scored,
        categories,
        top_ideas,
    }
}

fn category_for_id(id: usize) -> usize {
    CATEGORIES
        .iter()
        .position(|(start, end, _)| id >= *start && id <= *end)
        .unwrap_or(0)
}

// =============================================================================
// Markdown Renderer
// =============================================================================

fn render_markdown(catalog: &IdeaCatalog, top_n: usize) -> String {
    let mut out = String::new();
    out.push_str("# C3I AG-UI Integration: 200 Ranked Ideas\n\n");
    out.push_str("## Scoring (1-5 each, max 20): Criticality, Usability, Information Utility, UX/CX\n\n");

    for cat in &catalog.categories {
        out.push_str(&format!("\n---\n\n## {}\n\n", cat.name));
        for idea in catalog.ideas.iter().filter(|i| i.category_index == cat.index) {
            out.push_str(&format!(
                "### {}.  {} (Score: {}/20)\n\
                 - **Source:** {}\n\
                 - **Description:** {}\n\
                 - **Zenoh Topic:** `{}`\n\
                 - **Scores:** Criticality={}, Usability={}, Info Utility={}, UX/CX={}\n\n",
                idea.id,
                idea.title,
                idea.total_score,
                idea.source,
                idea.description,
                idea.zenoh_topic,
                idea.criticality,
                idea.usability,
                idea.info_utility,
                idea.ux
            ));
        }
    }

    out.push_str(&format!(
        "\n---\n\n## Summary: Top {} Ideas by Score\n\n",
        top_n
    ));
    out.push_str("| Rank | # | Idea | Score | Crit | Usab | Info | UX |\n");
    out.push_str("|:----:|:-:|------|:-----:|:----:|:----:|:----:|:--:|\n");

    for (rank, idea) in catalog.top_ideas.iter().enumerate() {
        out.push_str(&format!(
            "| {} | {} | {} | {} | {} | {} | {} | {} |\n",
            rank + 1,
            idea.id,
            idea.title,
            idea.total_score,
            idea.criticality,
            idea.usability,
            idea.info_utility,
            idea.ux
        ));
    }

    out
}

// =============================================================================
// Main
// =============================================================================

fn main() {
    let cli = Cli::parse();
    c3i_common::telemetry::init_tracing(cli.verbose);

    let catalog = build_catalog(cli.top_n);

    let content = match cli.format.as_str() {
        "json" => serde_json::to_string_pretty(&catalog).expect("JSON serialization failed"),
        _ => render_markdown(&catalog, cli.top_n),
    };

    let mut f = File::create(&cli.output).expect("Failed to create output file");
    f.write_all(content.as_bytes())
        .expect("Failed to write output");

    eprintln!(
        "[c3i_agui_ideas] Generated {} ideas to {}",
        catalog.ideas.len(),
        cli.output.display()
    );

    if cli.publish_zenoh {
        eprintln!("[c3i_agui_ideas] --publish-zenoh: ZMOF publishing (Phase 4 — not yet wired)");
    }
}

// =============================================================================
// Tests
// =============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ideas_count_200() {
        assert_eq!(ideas().len(), 200);
    }

    #[test]
    fn test_ids_unique() {
        let all = ideas();
        let mut ids: Vec<usize> = all.iter().map(|i| i.id).collect();
        ids.sort();
        ids.dedup();
        assert_eq!(ids.len(), 200);
    }

    #[test]
    fn test_ids_contiguous_1_to_200() {
        let all = ideas();
        let mut ids: Vec<usize> = all.iter().map(|i| i.id).collect();
        ids.sort();
        assert_eq!(ids.first(), Some(&1));
        assert_eq!(ids.last(), Some(&200));
    }

    #[test]
    fn test_scores_in_range() {
        for idea in ideas() {
            assert!(idea.crit >= 1 && idea.crit <= 5, "id={} crit={}", idea.id, idea.crit);
            assert!(idea.usab >= 1 && idea.usab <= 5, "id={} usab={}", idea.id, idea.usab);
            assert!(idea.info >= 1 && idea.info <= 5, "id={} info={}", idea.id, idea.info);
            assert!(idea.ux >= 1 && idea.ux <= 5, "id={} ux={}", idea.id, idea.ux);
        }
    }

    #[test]
    fn test_all_categories_populated() {
        let catalog = build_catalog(10);
        for cat in &catalog.categories {
            assert!(cat.idea_count > 0, "Category '{}' is empty", cat.name);
            assert_eq!(cat.idea_count, 20, "Category '{}' has {} ideas (expected 20)", cat.name, cat.idea_count);
        }
    }

    #[test]
    fn test_top_ideas_sorted_by_score() {
        let catalog = build_catalog(50);
        for window in catalog.top_ideas.windows(2) {
            assert!(
                window[0].total_score >= window[1].total_score,
                "Top ideas not sorted: {} ({}) before {} ({})",
                window[0].id,
                window[0].total_score,
                window[1].id,
                window[1].total_score
            );
        }
    }

    #[test]
    fn test_json_roundtrip() {
        let catalog = build_catalog(5);
        let json = serde_json::to_string(&catalog).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed["ideas"].as_array().unwrap().len(), 200);
        assert_eq!(parsed["top_ideas"].as_array().unwrap().len(), 5);
    }

    #[test]
    fn test_markdown_contains_all_categories() {
        let catalog = build_catalog(10);
        let md = render_markdown(&catalog, 10);
        for cat in &CATEGORIES {
            assert!(md.contains(cat.2), "Markdown missing category: {}", cat.2);
        }
    }
}
