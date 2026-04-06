//// =============================================================================
//// [C3I-SIL6-MSTS] MATHEMATICAL & SEMANTIC MODULE CONTRACT
//// =============================================================================
//// <c3i-module>
////   <identity>
////     <module>cepaf_gleam/ui/lustre/shell</module>
////     <fsharp-lineage>Cepaf.UI.Shell.fs</fsharp-lineage>
////   </identity>
////   <fractal-topology>
////     <layer>L2_COMPONENT</layer>
////     <mesh-domain>HTML shell layout, nav, reusable UI primitives</mesh-domain>
////   </fractal-topology>
////   <compliance>
////     <criticality>HIGH</criticality>
////     <stamp-controls>SC-GLM-UI-001, SC-GLM-UI-002, SC-GLM-UI-008, SC-MUDA-001</stamp-controls>
////   </compliance>
////   <transformations>
////     <morphism type="isomorphic">
////       Shell layout ≅ Lustre Element tree. Pure, no side effects.
////     </morphism>
////   </transformations>
//// </c3i-module>
//// =============================================================================
////
//// HTML shell: <!doctype html> document wrapper, navigation, reusable
//// component primitives (status_card, container_card, mini_bar, section,
//// kv_row, alert_banner, data_table).
////
//// CSS is intentionally minimal (~70 lines) to avoid Gleam compiler OOM on
//// large string literals (SC-MUDA-001).
////
//// STAMP: SC-GLM-UI-001, SC-GLM-UI-008, SC-MUDA-001

import gleam/float
import gleam/int
import gleam/list
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

// ---------------------------------------------------------------------------
// CSS — intentionally minimal: no animations, no gradients, no sparklines.
// ---------------------------------------------------------------------------

const css: String = "
body{margin:0;font-family:system-ui,sans-serif;background:#0a0e17;color:#e0e6ed;}
a{color:#00d4aa;text-decoration:none;}
a:hover{color:#3dd68c;}
nav{background:#0d1420;border-bottom:1px solid #1e2a3a;padding:0 1rem;display:flex;flex-wrap:wrap;gap:.25rem;align-items:center;}
nav a{padding:.5rem .75rem;border-radius:4px;font-size:.85rem;}
nav a.active{background:#1e2a3a;color:#3dd68c;}
main{padding:1.5rem;max-width:1400px;margin:0 auto;}
h1{font-size:1.4rem;margin:.5rem 0 .25rem;}
h2{font-size:1.1rem;margin:1rem 0 .5rem;color:#7a8fa6;}
p.sub{font-size:.85rem;color:#7a8fa6;margin:0 0 1rem;}
.card-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:1rem;margin:.75rem 0;}
.card-grid-wide{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:1rem;margin:.75rem 0;}
.card{background:#141922;border:1px solid #1e2a3a;border-radius:6px;padding:1rem;}
.card-title{font-size:.8rem;color:#7a8fa6;text-transform:uppercase;margin:0 0 .4rem;}
.card-value{font-size:1.5rem;font-weight:700;margin:0 0 .25rem;}
.card-detail{font-size:.8rem;color:#7a8fa6;}
.status-healthy{color:#3dd68c;}
.status-degraded{color:#f5a623;}
.status-critical{color:#e05252;}
.status-unknown{color:#7a8fa6;}
.badge{display:inline-block;padding:.15rem .5rem;border-radius:3px;font-size:.75rem;font-weight:600;}
.badge-healthy{background:#1a3d2a;color:#3dd68c;}
.badge-degraded{background:#3d2e10;color:#f5a623;}
.badge-critical{background:#3d1515;color:#e05252;}
.section{margin:1.25rem 0;}
.section-title{font-size:.85rem;color:#7a8fa6;text-transform:uppercase;margin:0 0 .5rem;border-bottom:1px solid #1e2a3a;padding-bottom:.35rem;}
.alert{padding:.75rem 1rem;border-radius:4px;margin:.5rem 0;font-size:.9rem;}
.alert-critical{background:#3d1515;border:1px solid #e05252;color:#e05252;}
.alert-warning{background:#3d2e10;border:1px solid #f5a623;color:#f5a623;}
.alert-info{background:#0d2235;border:1px solid #00d4aa;color:#00d4aa;}
table{width:100%;border-collapse:collapse;font-size:.88rem;}
th{text-align:left;padding:.4rem .6rem;background:#0d1420;color:#7a8fa6;font-size:.78rem;text-transform:uppercase;}
td{padding:.4rem .6rem;border-bottom:1px solid #1e2a3a;}
.bar-wrap{background:#1e2a3a;border-radius:2px;height:6px;width:100%;overflow:hidden;}
.bar-fill{height:100%;border-radius:2px;}
.kv-row{display:flex;gap:.75rem;padding:.3rem 0;border-bottom:1px solid #1e2a3a;font-size:.88rem;}
.kv-key{color:#7a8fa6;min-width:140px;}
.ooda-phases{display:flex;align-items:center;gap:.5rem;flex-wrap:wrap;padding:.5rem 0;}
.ooda-arrow{color:#7a8fa6;}
.pill{display:inline-block;padding:.2rem .6rem;border-radius:12px;font-size:.8rem;background:#1e2a3a;color:#7a8fa6;}
.pill-active{background:#1a3d2a;color:#3dd68c;}
.w-full{width:100%;}
@media(max-width:768px){nav{padding:.25rem;}.card-grid,.card-grid-wide{grid-template-columns:1fr;}main{padding:.75rem;}}
"

// ---------------------------------------------------------------------------
// Navigation pages (order matches the cockpit tab bar)
// ---------------------------------------------------------------------------

const nav_pages: List(#(String, String)) = [
  #("/dashboard", "Dashboard"),
  #("/planning", "Planning"),
  #("/immune", "Immune"),
  #("/knowledge", "Knowledge"),
  #("/zenoh", "Zenoh"),
  #("/cockpit", "Cockpit"),
  #("/verification", "Verification"),
  #("/substrate", "Substrate"),
  #("/metabolic", "Metabolic"),
  #("/podman", "Podman"),
  #("/mcp", "MCP"),
  #("/kms", "KMS"),
  #("/telemetry", "Telemetry"),
  #("/federation", "Federation"),
  #("/health-grid", "Health Grid"),
]

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Render a complete <!doctype html> page as a String.
///
/// `title`       — Browser tab / <title> suffix.
/// `active_path` — URL path including leading "/" (e.g. "/dashboard").
///                 Used to highlight the active nav link.
/// `content`     — Lustre element tree for <main>.
///
/// Returns the full HTML document string.
pub fn render_page(
  title: String,
  active_path: String,
  content: Element(msg),
) -> String {
  let doc =
    html.html([], [
      html.head([], [
        html.meta([attribute.attribute("charset", "utf-8")]),
        html.meta([
          attribute.name("viewport"),
          attribute.attribute("content", "width=device-width,initial-scale=1"),
        ]),
        html.title([], "C3I — " <> title),
        html.style([], css),
      ]),
      html.body([], [
        render_nav(active_path),
        html.main([], [content]),
      ]),
    ])
  "<!doctype html>" <> element.to_string(doc)
}

/// Render the horizontal navigation bar.
fn render_nav(active_path: String) -> Element(msg) {
  let links =
    list.map(nav_pages, fn(pair) {
      let #(path, label) = pair
      let cls = case path == active_path {
        True -> "active"
        False -> ""
      }
      html.a([attribute.href(path), attribute.class(cls)], [
        element.text(label),
      ])
    })
  html.nav([], links)
}

/// A card showing a status value with title, value, and detail text.
///
/// `status` should be one of: "Healthy", "Degraded", "Critical", or "Unknown".
pub fn status_card(
  title: String,
  status: String,
  value: String,
  detail: String,
) -> Element(msg) {
  let status_class = case string.lowercase(status) {
    "healthy" -> "status-healthy"
    "degraded" -> "status-degraded"
    "critical" -> "status-critical"
    _ -> "status-unknown"
  }
  html.div([attribute.class("card")], [
    html.p([attribute.class("card-title")], [element.text(title)]),
    html.p([attribute.class("card-value " <> status_class)], [
      element.text(value),
    ]),
    html.p([attribute.class("card-detail")], [element.text(detail)]),
  ])
}

/// A card for a container showing name, status, CPU %, and memory %.
pub fn container_card(
  name: String,
  status: String,
  cpu: Float,
  memory: Float,
) -> Element(msg) {
  let status_class = case string.lowercase(status) {
    "running" -> "status-healthy"
    "stopped" | "exited" -> "status-critical"
    _ -> "status-degraded"
  }
  html.div([attribute.class("card")], [
    html.p([attribute.class("card-title")], [element.text(name)]),
    html.p([attribute.class("card-value " <> status_class)], [
      element.text(status),
    ]),
    html.div([], [
      mini_bar(cpu, 1.0, "#00d4aa"),
      html.p([attribute.class("card-detail")], [
        element.text(
          "CPU "
          <> int.to_string(float.round(cpu *. 100.0))
          <> "% · MEM "
          <> int.to_string(float.round(memory *. 100.0))
          <> "%",
        ),
      ]),
    ]),
  ])
}

/// A thin horizontal progress bar.
///
/// `value` and `max` determine fill percentage. `color` is a CSS color string.
pub fn mini_bar(value: Float, max: Float, color: String) -> Element(msg) {
  let pct = case max >. 0.0 {
    True -> {
      let v = value /. max *. 100.0
      int.to_string(float.round(v))
    }
    False -> "0"
  }
  html.div([attribute.class("bar-wrap")], [
    html.div(
      [
        attribute.class("bar-fill"),
        attribute.attribute(
          "style",
          "width:" <> pct <> "%;background:" <> color,
        ),
      ],
      [],
    ),
  ])
}

/// A titled section wrapping child elements.
pub fn section(title: String, children: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("section")], [
    html.p([attribute.class("section-title")], [element.text(title)]),
    ..children
  ])
}

/// A single key-value row for property tables.
pub fn kv_row(key: String, value: String) -> Element(msg) {
  html.div([attribute.class("kv-row")], [
    html.span([attribute.class("kv-key")], [element.text(key)]),
    html.span([], [element.text(value)]),
  ])
}

/// An alert banner with severity styling.
///
/// `severity` should be one of: "critical", "warning", "info".
pub fn alert_banner(severity: String, message: String) -> Element(msg) {
  let cls = case string.lowercase(severity) {
    "critical" -> "alert alert-critical"
    "warning" -> "alert alert-warning"
    _ -> "alert alert-info"
  }
  html.div([attribute.class(cls)], [element.text(message)])
}

/// A simple HTML table with headers and rows.
pub fn data_table(
  headers: List(String),
  rows: List(List(String)),
) -> Element(msg) {
  let th_cells = list.map(headers, fn(h) { html.th([], [element.text(h)]) })
  let tr_rows =
    list.map(rows, fn(row) {
      let td_cells =
        list.map(row, fn(cell) { html.td([], [element.text(cell)]) })
      html.tr([], td_cells)
    })
  html.table([], [
    html.thead([], [html.tr([], th_cells)]),
    html.tbody([], tr_rows),
  ])
}

/// Action button that performs an API call via JS fetch.
pub fn action_button(
  label: String,
  endpoint: String,
  payload: String,
) -> Element(msg) {
  html.button(
    [
      attribute.class("action-button badge badge-healthy"),
      attribute.attribute(
        "style",
        "cursor: pointer; margin-right: 0.5rem; border: 1px solid #3dd68c;",
      ),
      attribute.attribute(
        "onclick",
        "fetch('"
          <> endpoint
          <> "', {method: 'POST', headers: {'Authorization': 'Bearer ' + (localStorage.getItem('token') || ''), 'Content-Type': 'application/json'}, body: '"
          <> payload
          <> "'}).then(r => r.json()).then(console.log)",
      ),
    ],
    [element.text(label)],
  )
}
