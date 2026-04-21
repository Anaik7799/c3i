//// scripts/common/html_doc — reusable HTML analysis-document builder.
////
//// Consistent shape for every feature: prompt / features / implementation /
//// usage / testing / summary sections + KPI band + embedded diagrams.
//// Pair with `scripts/common/journal` (.md) and `scripts/common/html_deck`
//// (slides). All three files land in the canonical artifact tree so the
//// sa-plan task-id page server serves them over HTTP + HTTPS.

import gleam/list
import gleam/string
import scripts/common/artifact
import scripts/common/fsx

pub type Kpi {
  Kpi(value: String, label: String)
}

pub type Diagram {
  Diagram(caption: String, image_filename: String)
}

pub type Meta {
  Meta(
    stamp: String,
    task_id: String,
    feature_slug: String,       // e.g. "scripts-gleam-evolution"
    title: String,
    pair_journal_file: String,  // filename of the paired journal.md
    pair_deck_file: String,     // filename of the paired deck.html
  )
}

pub type Doc {
  Doc(
    prompt_summary: String,           // 1-2 paragraphs
    features: List(String),           // bullet list
    implementation_rows: List(#(String, String)), // [(layer, impl)]
    usage_examples: List(String),     // pre-formatted shell snippets
    testing_rows: List(#(String, String)), // [(test, outcome)]
    summary: String,                  // closing paragraph
    kpis: List(Kpi),
    diagrams: List(Diagram),
  )
}

fn escape(s: String) -> String {
  s
  |> string.replace(each: "&", with: "&amp;")
  |> string.replace(each: "<", with: "&lt;")
  |> string.replace(each: ">", with: "&gt;")
}

fn kpi_html(kpis: List(Kpi)) -> String {
  case kpis {
    [] -> ""
    items ->
      "<div class=\"kpi\">"
      <> string.join(
        list.map(items, fn(k) {
          "<div><b>" <> escape(k.value) <> "</b>" <> escape(k.label) <> "</div>"
        }),
        "",
      )
      <> "</div>"
  }
}

fn diagram_html(meta: Meta, d: Diagram) -> String {
  let url = artifact.link(artifact.Http, meta.task_id, d.image_filename)
  "<h3>" <> escape(d.caption) <> "</h3>\n"
  <> "<img src=\"" <> url <> "\" alt=\"" <> escape(d.caption) <> "\">"
}

fn ul_html(items: List(String)) -> String {
  "<ul>"
  <> string.join(list.map(items, fn(s) { "<li>" <> s <> "</li>" }), "")
  <> "</ul>"
}

fn table_html(rows: List(#(String, String)), h1: String, h2: String) -> String {
  "<table><tr><th>" <> escape(h1) <> "</th><th>" <> escape(h2) <> "</th></tr>"
  <> string.join(
    list.map(rows, fn(r) {
      let #(a, b) = r
      "<tr><td>" <> escape(a) <> "</td><td>" <> b <> "</td></tr>"
    }),
    "",
  )
  <> "</table>"
}

fn code_block(s: String) -> String {
  "<pre><code>" <> escape(s) <> "</code></pre>"
}

/// Render the complete HTML document.
pub fn render(meta: Meta, doc: Doc) -> String {
  let deck_link = artifact.link(artifact.Https, meta.task_id, meta.pair_deck_file)
  let journal_link = artifact.link(artifact.Https, meta.task_id, meta.pair_journal_file)
  "<!DOCTYPE html>\n<html lang=\"en\"><head>\n"
  <> "<meta charset=\"utf-8\">\n"
  <> "<title>" <> escape(meta.title) <> " — " <> meta.task_id <> "</title>\n"
  <> "<style>\nbody{font-family:system-ui,-apple-system,sans-serif;max-width:1100px;margin:2em auto;padding:0 1em;line-height:1.6;color:#111}\n"
  <> "h1{border-bottom:2px solid #111;padding-bottom:.2em}\n"
  <> "h2{border-bottom:1px solid #999;padding-bottom:.15em;margin-top:2em}\n"
  <> "code,pre{background:#f6f8fa;padding:.15em .35em;border-radius:3px;font-family:ui-monospace,Menlo,monospace}\n"
  <> "pre{padding:1em;overflow:auto}\n"
  <> "table{border-collapse:collapse;width:100%;margin:1em 0}\n"
  <> "th,td{border:1px solid #ccc;padding:.4em .7em;vertical-align:top;text-align:left}\n"
  <> "th{background:#eef}\n"
  <> ".banner{background:#044;color:#fff;padding:.8em 1em;border-radius:6px;margin-bottom:1em}\n"
  <> ".banner a{color:#fff}\n"
  <> ".kpi{display:grid;grid-template-columns:repeat(4,1fr);gap:.6em;margin:1em 0}\n"
  <> ".kpi div{background:#eef;padding:.6em;border-radius:4px;text-align:center}\n"
  <> ".kpi b{display:block;font-size:1.4em;color:#044;margin-right:.3em}\n"
  <> "img{max-width:100%;border:1px solid #ddd;border-radius:4px;background:#fff;padding:4px}\n"
  <> "</style></head><body>\n"
  <> "<div class=\"banner\"><a href=\"" <> journal_link <> "\">" <> journal_link <> "</a></div>\n"
  <> "<h1>" <> escape(meta.title) <> "</h1>\n"
  <> "<p><b>Task id:</b> " <> escape(meta.task_id)
  <> " · <b>Generated:</b> " <> escape(meta.stamp)
  <> " UTC · <b>Path invariant:</b> <code>/home/an/dev/ver/c3i/</code></p>\n"
  <> kpi_html(doc.kpis)
  <> "<h2>Prompt</h2>\n<p>" <> doc.prompt_summary <> "</p>\n"
  <> "<h2>Features</h2>\n" <> ul_html(doc.features)
  <> "<h2>Implementation</h2>\n" <> table_html(doc.implementation_rows, "Layer", "Implementation")
  <> "<h2>Architecture diagrams</h2>\n"
  <> string.join(list.map(doc.diagrams, fn(d) { diagram_html(meta, d) }), "\n")
  <> "\n<h2>Usage</h2>\n"
  <> string.join(list.map(doc.usage_examples, code_block), "\n")
  <> "\n<h2>Testing</h2>\n" <> table_html(doc.testing_rows, "Test", "Outcome")
  <> "<h2>Summary</h2>\n<p>" <> doc.summary <> "</p>\n"
  <> "<p><a href=\"" <> deck_link <> "\">Slide deck →</a></p>\n"
  <> "</body></html>\n"
}

/// Write the analysis HTML to the canonical artifact location.
pub fn write(meta: Meta, doc: Doc) -> Result(String, String) {
  let filename =
    artifact.filename(meta.stamp, meta.task_id, artifact.Analysis, meta.feature_slug)
  case fsx.write_file(artifact.journal_dir(), filename, render(meta, doc)) {
    Error(e) -> Error(e)
    Ok(_) -> Ok(filename)
  }
}
