//// scripts/common/journal — 13-section journal template (SC-JOURNAL).
////
//// Every feature-evolution journal follows the canonical 13-section
//// structure required by `.claude/rules/journal-protocol.md`.
//// Build a `Sections` record, pass to `render` / `write` and you get a
//// compliant `.md` file with the tailscale HTTPS link on the first line.

import gleam/list
import gleam/string
import scripts/common/artifact
import scripts/common/fsx

pub type Meta {
  Meta(
    stamp: String,
    task_id: String,
    feature_slug: String,   // e.g. "scripts-gleam-evolution"
    title: String,          // Human title
    sc_ids: List(String),
    pair_analysis_file: String, // filename of the paired analysis.html
  )
}

pub type Sections {
  Sections(
    scope_trigger: String,
    pre_state: String,
    execution: String,
    rca: String,
    fix_taxonomy: String,
    patterns: String,
    verification: String,
    files_modified: String,
    architectural_observations: String,
    remaining_gaps: String,
    metrics_summary: String,
    stamp_alignment: String,
    conclusion: String,
  )
}

fn h2(n: Int, title: String, body: String) -> String {
  "## " <> int_to_string(n) <> ". " <> title <> "\n\n" <> body <> "\n\n"
}

@external(erlang, "erlang", "integer_to_binary")
fn int_to_string(n: Int) -> String

/// Render the 13-section journal as a string.
pub fn render(meta: Meta, sections: Sections) -> String {
  let top_link = artifact.top_https_line(meta.task_id, meta.pair_analysis_file)
  let sc_line = case meta.sc_ids {
    [] -> ""
    ids -> "\n**SC-IDs:** " <> string.join(ids, ", ") <> "\n"
  }
  top_link <> "\n\n"
  <> "# " <> meta.title <> " — journal (task " <> meta.task_id <> ")\n\n"
  <> "**UTC:** " <> meta.stamp <> "  \n"
  <> "**Task:** " <> meta.task_id <> "  \n"
  <> "**Feature slug:** " <> meta.feature_slug
  <> sc_line
  <> "\n"
  <> h2(1,  "Scope & Trigger",              sections.scope_trigger)
  <> h2(2,  "Pre-State Assessment",         sections.pre_state)
  <> h2(3,  "Execution Detail",             sections.execution)
  <> h2(4,  "Root Cause Analysis",          sections.rca)
  <> h2(5,  "Fix Taxonomy",                 sections.fix_taxonomy)
  <> h2(6,  "Patterns & Anti-Patterns",     sections.patterns)
  <> h2(7,  "Verification Matrix",          sections.verification)
  <> h2(8,  "Files Modified",               sections.files_modified)
  <> h2(9,  "Architectural Observations",   sections.architectural_observations)
  <> h2(10, "Remaining Gaps",               sections.remaining_gaps)
  <> h2(11, "Metrics Summary",              sections.metrics_summary)
  <> h2(12, "STAMP & Constitutional Alignment", sections.stamp_alignment)
  <> h2(13, "Conclusion",                   sections.conclusion)
}

/// Write the journal using the canonical artifact path, return the leaf filename.
pub fn write(meta: Meta, sections: Sections) -> Result(String, String) {
  let filename = artifact.filename(meta.stamp, meta.task_id, artifact.Journal, meta.feature_slug)
  let body = render(meta, sections)
  case fsx.write_file(artifact.journal_dir(), filename, body) {
    Error(e) -> Error(e)
    Ok(_) -> Ok(filename)
  }
}

/// Quick helper — render a simple bullet list into a single markdown string.
pub fn bullets(items: List(String)) -> String {
  items
  |> list.map(fn(s) { "- " <> s })
  |> string.join("\n")
}

/// Render a simple markdown table (header row + data rows).
pub fn table(headers: List(String), rows: List(List(String))) -> String {
  let header = "| " <> string.join(headers, " | ") <> " |"
  let sep =
    "|"
    <> string.join(list.map(headers, fn(_) { "---" }), "|")
    <> "|"
  let body =
    rows
    |> list.map(fn(row) { "| " <> string.join(row, " | ") <> " |" })
    |> string.join("\n")
  header <> "\n" <> sep <> "\n" <> body
}
