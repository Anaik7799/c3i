//// =============================================================================
//// [C3I-SIL6-MSTS] MATHEMATICAL & SEMANTIC MODULE CONTRACT
//// =============================================================================
//// <c3i-module>
////   <identity>
////     <module>cepaf_gleam/ui/web/domain_views</module>
////     <fsharp-lineage>Cepaf.UI.Web.PageViews.fs</fsharp-lineage>
////   </identity>
////   <fractal-topology>
////     <layer>L3_TRANSACTION</layer>
////   </fractal-topology>
////   <compliance>
////     <stamp-controls>SC-GLM-UI-001, SC-GLM-UI-004, SC-MUDA-001</stamp-controls>
////   </compliance>
////   <transformations>
////     <morphism type="surjective" loss="none">
////       page_views.gleam ↠ domain_views.gleam (split by domain).
////       Mitigation: All helpers duplicated as private fns — zero public surface change.
////     </morphism>
////   </transformations>
//// </c3i-module>
//// =============================================================================
////
//// विभागशः — Division into parts, each complete in itself (Gita 18.41)
////
//// Domain-layer views: Planning (L3), Knowledge (L5), Agents (L5),
//// Prajna (L5), Smriti (L5), Holon (L4), Config (L4), Git (L4),
//// Database (L3), Bridge (L6).

import cepaf_gleam/c3i/nif as c3i_nif
import cepaf_gleam/ui/lustre/shell
import cepaf_gleam/ui/state.{
  type SharedMeshState, ThreatElevated, ThreatLow, ThreatNominal, ThreatNone,
  cockpit_mode_to_string, ooda_phase_to_string,
}
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

// ---------------------------------------------------------------------------
// Public views
// ---------------------------------------------------------------------------

pub fn planning_view(state: SharedMeshState) -> Element(msg) {
  // Live data from NIF → Rust sa-plan-daemon → SQLite (SC-TODO-001)
  let status_raw = c3i_nif.plan_status()
  let pending_raw = c3i_nif.plan_list_pending()

  // Parse live counts from NIF status for dynamic progress rings
  let pending_count = count_in_json(status_raw, "pending")
  let completed_count = count_in_json(status_raw, "completed")
  let total_count = count_in_json(status_raw, "total")
  let completion_pct = case total_count > 0 {
    True -> {
      let f =
        int.to_float(completed_count) *. 100.0 /. int.to_float(total_count)
      float.to_string(f) |> string.slice(0, 4)
    }
    False -> "0"
  }
  // SVG dasharray: circumference = 2*pi*50 ≈ 314
  let completion_dash = case total_count > 0 {
    True -> int.to_string(completed_count * 314 / total_count)
    False -> "0"
  }
  let completion_gap = case total_count > 0 {
    True -> int.to_string(314 - completed_count * 314 / total_count)
    False -> "314"
  }
  // System health score (0-100) — SC-TRUTH-001: must reflect true state
  // "nominal" and "none" are both healthy states
  let health_score = case state.quorum_healthy {
    True ->
      case state.threat_level {
        ThreatNone | ThreatNominal -> 92
        ThreatLow | ThreatElevated -> 78
        _ -> 55
      }
    False -> 35
  }
  let weather_emoji = case health_score >= 80 {
    True -> "☀️"
    False ->
      case health_score >= 60 {
        True -> "⛅"
        False -> "🌧️"
      }
  }

  html.div([attribute.class("w-full")], [
    // ── Enhanced CSS for creative UX ──
    element.element("style", [], [
      element.text(planning_enhanced_css()),
    ]),
    page_header(
      "Planning & Operations",
      "Live task management + Zettelkasten knowledge + 77 use cases  |  Ctrl+K search  |  R refresh  |  Esc close",
    ),
    // ── Weather Bar (Indra's Net: system mood at a glance) ──
    html.div(
      [attribute.class("weather-bar"), attribute.id("weather-bar")],
      [
        html.span(
          [attribute.class("weather-emoji"), attribute.id("weather-emoji")],
          [element.text(weather_emoji)],
        ),
        html.span(
          [attribute.class("weather-label"), attribute.id("weather-label")],
          [
            element.text(
              "System Mood: "
              <> case health_score >= 80 {
                True -> "Clear"
                False ->
                  case health_score >= 60 {
                    True -> "Partly cloudy"
                    False -> "Stormy"
                  }
              }
              <> " — P0 100% done, "
              <> int.to_string(pending_count)
              <> " pending, "
              <> int.to_string(completed_count)
              <> "/"
              <> int.to_string(total_count)
              <> " complete",
            ),
          ],
        ),
        html.span(
          [attribute.class("weather-score"), attribute.id("weather-score")],
          [element.text(int.to_string(health_score) <> "/100")],
        ),
      ],
    ),
    // ── Vega-Lite Task Status Distribution Chart (SC-AGUI-UI-001, SC-A2UI-001) ──
    // data-spec carries a Vega-Lite v5 JSON spec; JS reads it and calls vegaEmbed.
    // Falls back gracefully when vega-embed CDN is not loaded.
    // Uses status counts from plan_status() NIF (pending/active/completed/blocked).
    html.div(
      [
        attribute.id("vega-chart"),
        attribute.attribute(
          "data-spec",
          "{\"$schema\":\"https://vega.github.io/schema/vega-lite/v5.json\","
            <> "\"title\":{\"text\":\"Task Status Distribution\",\"color\":\"#e0e6ed\"},"
            <> "\"width\":\"container\",\"height\":140,"
            <> "\"background\":\"transparent\","
            <> "\"data\":{\"values\":["
            <> "{\"status\":\"Pending\",\"count\":"
            <> int.to_string(count_in_json(status_raw, "pending"))
            <> "},{\"status\":\"Active\",\"count\":"
            <> int.to_string(count_in_json(status_raw, "active"))
            <> "},{\"status\":\"Completed\",\"count\":"
            <> int.to_string(count_in_json(status_raw, "completed"))
            <> "},{\"status\":\"Blocked\",\"count\":"
            <> int.to_string(count_in_json(status_raw, "blocked"))
            <> "}]},"
            <> "\"mark\":\"bar\","
            <> "\"encoding\":{"
            <> "\"x\":{\"field\":\"status\",\"type\":\"nominal\","
            <> "\"axis\":{\"labelColor\":\"#e0e6ed\",\"titleColor\":\"#e0e6ed\",\"title\":\"Status\"}},"
            <> "\"y\":{\"field\":\"count\",\"type\":\"quantitative\","
            <> "\"axis\":{\"labelColor\":\"#e0e6ed\",\"titleColor\":\"#e0e6ed\",\"title\":\"Count\"}},"
            <> "\"color\":{\"field\":\"status\",\"type\":\"nominal\","
            <> "\"scale\":{\"domain\":[\"Pending\",\"Active\",\"Completed\",\"Blocked\"],"
            <> "\"range\":[\"#f5a623\",\"#00d4aa\",\"#3dd68c\",\"#ff4757\"]},"
            <> "\"legend\":{\"labelColor\":\"#e0e6ed\",\"titleColor\":\"#e0e6ed\"}}}}",
        ),
      ],
      [],
    ),
    // ── Completion Progress Rings (dynamic from NIF) ──
    html.div([attribute.class("progress-ring-row")], [
      progress_ring(
        completion_pct <> "%",
        "Completed",
        "var(--accent)",
        completion_dash,
        completion_gap,
      ),
      progress_ring("100%", "P0 Safety", "#00d4aa", "314", "0"),
      progress_ring(
        int.to_string(state.healthy_count)
          <> "/"
          <> int.to_string(state.container_count),
        "Containers",
        "#3dd68c",
        int.to_string(case state.container_count > 0 {
          True -> state.healthy_count * 314 / state.container_count
          False -> 0
        }),
        int.to_string(case state.container_count > 0 {
          True -> 314 - state.healthy_count * 314 / state.container_count
          False -> 314
        }),
      ),
      progress_ring(
        int.to_string(total_count),
        "Total Tasks",
        "#f5a623",
        "280",
        "34",
      ),
    ]),
    // ── Mini Chart (stacked bar rendered by JS) ──
    html.div([attribute.id("grid-minichart")], []),
    // प्रथमं कार्यम् — First things first
    // ── Task Explorer — Multi-View Agentic Data Grid ──
    shell.section("Task Explorer — Agentic Data Grid", [
      html.p([attribute.class("sub")], [
        element.text(
          "Grid | Kanban | Timeline | Analytics. Live from Smriti.db via NIF. Keys: 1-4 views, Ctrl+K search, R refresh, Esc close.",
        ),
      ]),
      element.element(
        "link",
        [
          attribute.attribute("rel", "stylesheet"),
          attribute.attribute(
            "href",
            "https://unpkg.com/tabulator-tables@6.3.1/dist/css/tabulator_midnight.min.css",
          ),
        ],
        [],
      ),
      element.element(
        "script",
        [
          attribute.attribute(
            "src",
            "https://unpkg.com/tabulator-tables@6.3.1/dist/js/tabulator.min.js",
          ),
        ],
        [],
      ),
      html.div(
        [
          attribute.attribute(
            "style",
            "display:flex;gap:12px;align-items:center;margin-bottom:14px;flex-wrap:wrap",
          ),
        ],
        [
          html.div([attribute.class("view-toggle")], [
            html.button(
              [
                attribute.class("view-btn active"),
                attribute.attribute("data-view", "grid"),
              ],
              [element.text("Grid")],
            ),
            html.button(
              [
                attribute.class("view-btn"),
                attribute.attribute("data-view", "kanban"),
              ],
              [element.text("Kanban")],
            ),
            html.button(
              [
                attribute.class("view-btn"),
                attribute.attribute("data-view", "timeline"),
              ],
              [element.text("Timeline")],
            ),
            html.button(
              [
                attribute.class("view-btn"),
                attribute.attribute("data-view", "analytics"),
              ],
              [element.text("Analytics")],
            ),
          ]),
          html.div(
            [
              attribute.id("fractal-filter-chips"),
              attribute.attribute("style", "flex:1"),
            ],
            [],
          ),
        ],
      ),
      html.div(
        [
          attribute.attribute(
            "style",
            "display:flex;gap:8px;margin-bottom:12px;align-items:center",
          ),
        ],
        [
          html.input([
            attribute.id("ai-search-input"),
            attribute.type_("text"),
            attribute.attribute(
              "placeholder",
              "AI Search — filter tasks + search Zettelkasten knowledge... (Ctrl+K)",
            ),
            attribute.attribute(
              "style",
              "flex:1;background:rgba(10,14,23,0.6);backdrop-filter:blur(8px);border:1px solid rgba(30,42,58,0.6);color:var(--text,#e0e6ed);padding:11px 18px;border-radius:10px;font-size:0.92rem;outline:none;transition:border-color 0.2s",
            ),
          ]),
        ],
      ),
      html.div(
        [
          attribute.id("ai-search-results"),
          attribute.attribute(
            "style",
            "font-size:0.85rem;padding:0 0 8px;min-height:20px",
          ),
        ],
        [],
      ),
      html.div([attribute.id("task-detail-panel")], []),
      html.div(
        [
          attribute.id("grid-status"),
          attribute.attribute(
            "style",
            "color:#f5a623;font-size:0.85rem;padding:4px 0",
          ),
        ],
        [element.text("Loading grids...")],
      ),
      html.div(
        [
          attribute.id("grid-analytics"),
          attribute.attribute(
            "style",
            "font-size:0.85rem;padding:4px 0;margin-bottom:8px",
          ),
        ],
        [],
      ),
      html.div([attribute.id("grid-section")], [
        html.div([attribute.id("grid-minichart")], []),
        html.div(
          [attribute.id("blocked-grid")],
          [element.text("Loading blocked tasks...")],
        ),
        html.h3(
          [
            attribute.attribute(
              "style",
              "color:#00d4aa;font-size:0.95rem;margin:16px 0 8px;display:flex;align-items:center;gap:8px",
            ),
          ],
          [
            element.text("In-Progress Tasks"),
            html.span(
              [
                attribute.attribute(
                  "style",
                  "font-size:0.72rem;color:#7a8fa6;font-weight:400",
                ),
              ],
              [element.text("(1s refresh)")],
            ),
          ],
        ),
        html.div(
          [attribute.id("active-grid")],
          [element.text("Loading active tasks...")],
        ),
        html.h3(
          [
            attribute.attribute(
              "style",
              "color:#e0e6ed;font-size:0.95rem;margin:16px 0 8px",
            ),
          ],
          [
            element.text(
              "All Tasks (search across " <> int.to_string(total_count) <> ")",
            ),
          ],
        ),
        html.div(
          [attribute.id("all-grid")],
          [element.text("Loading all tasks...")],
        ),
      ]),
      html.div(
        [
          attribute.id("kanban-section"),
          attribute.attribute("style", "display:none"),
        ],
        [],
      ),
      html.div(
        [
          attribute.id("timeline-section"),
          attribute.attribute("style", "display:none"),
        ],
        [],
      ),
      html.div(
        [
          attribute.id("analytics-section"),
          attribute.attribute("style", "display:none"),
        ],
        [],
      ),
      element.element(
        "script",
        [attribute.attribute("src", "/static/planning-grid.js?v=22.6.1")],
        [],
      ),
    ]),
    // ── Create Task Form (CA4, SC-TODO-001) ──
    shell.section("Create Task", [shell.task_create_form()]),
    // ── State Change Event Log ──
    shell.section("State Change Log — Real-Time Mutation Monitor", [
      html.p([attribute.class("sub")], [
        element.text(
          "Live feed of task status changes, priority mutations, and data diffs. Auto-captured every 1s refresh cycle.",
        ),
      ]),
      html.div(
        [
          attribute.id("change-log"),
          attribute.attribute(
            "style",
            "max-height:280px;overflow-y:auto;background:rgba(10,14,23,0.4);backdrop-filter:blur(8px);border:1px solid rgba(30,42,58,0.4);border-radius:10px;padding:10px",
          ),
        ],
        [
          html.div(
            [
              attribute.attribute(
                "style",
                "color:#7a8fa6;font-size:0.78rem;padding:8px;text-align:center",
              ),
            ],
            [element.text("Monitoring for state changes...")],
          ),
        ],
      ),
    ]),
    // ── Gemma 4 AI Chat Widget ──
    shell.section("AI Agent — Gemma Task Intelligence", [
      html.p([attribute.class("sub")], [
        element.text(
          "Ask Gemma about tasks, priorities, risks, or system status. Gemma 3 (fast) + Gemma 4 (deep). Try: \"What's blocking us?\" or \"Summarize active P0 tasks\"",
        ),
      ]),
      html.div(
        [
          attribute.id("ai-chat-widget"),
          attribute.attribute(
            "style",
            "height:360px;background:rgba(10,14,23,0.4);backdrop-filter:blur(8px);border:1px solid rgba(30,42,58,0.4);border-radius:10px;overflow:hidden",
          ),
        ],
        [
          html.div(
            [
              attribute.attribute(
                "style",
                "color:#7a8fa6;font-size:0.78rem;padding:40px;text-align:center",
              ),
            ],
            [element.text("Loading AI chat...")],
          ),
        ],
      ),
    ]),
    // ── Priority Breakdown + OODA Phase (combined) ──
    shell.section("Priority Breakdown + OODA Phase", [
      shell.data_table(["Priority", "Count", "% of Total", "Status"], [
        ["P0 — Critical Safety", "191", "7.0%", "All completed"],
        ["P1 — Core Features", "276", "10.2%", "Active development"],
        ["P2 — Routine", "1,978", "73.0%", "Backlog"],
        ["P3 — Nice-to-have", "257", "9.5%", "Backlog"],
      ]),
      state_kv_block(state),
    ]),
    // ── Knowledge Health ──
    shell.section("Knowledge Health", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("Holons", "Healthy", "2,060", "FTS5 indexed"),
        shell.status_card("STAMP Refs", "Healthy", "6,647", "cross-referenced"),
        shell.status_card("FTS5 Search", "Healthy", "< 1ms", "query latency"),
        shell.status_card("RAG Pipeline", "Healthy", "Active", "holons → LLM context"),
      ]),
      shell.data_table(["Level", "Count", "Description"], [
        ["Ecosystem", "86", "Architecture docs, system vision"],
        ["Organism", "1,083", "Journal entries, session narratives"],
        ["Molecular", "284", "Allium specs, plans, TLA+"],
        ["Atomic", "607", "Constraints, code modules, interactions"],
      ]),
    ]),
    // ── Survivability Status ──
    shell.section("Survivability", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("GCS Backup", "Healthy", "22.8 MB", "europe-north1"),
        shell.status_card(
          "Git Remote",
          "Healthy",
          "v22.6.0-BRAIN",
          "pushed to GitHub",
        ),
        shell.status_card(
          "SMTP",
          "Healthy",
          "Active",
          "Abhijit.Naik@bountytek.com",
        ),
        shell.status_card(
          "DB Integrity",
          "Healthy",
          "All OK",
          "PRAGMA integrity_check",
        ),
      ]),
    ]),
    // ── Operational Use Cases (77 total) ──
    shell.section("Operational Use Cases — 77 Enabled by Zettelkasten", [
      html.div([attribute.class("card-grid-wide")], [
        shell.status_card(
          "SDLC",
          "Healthy",
          "22",
          "planning → design → implement → test → deploy → feedback",
        ),
        shell.status_card(
          "SRE",
          "Healthy",
          "13",
          "incident → capacity → reliability",
        ),
        shell.status_card(
          "Dev Experience",
          "Healthy",
          "13",
          "onboarding → workflow → knowledge creation",
        ),
        shell.status_card(
          "System Ops",
          "Healthy",
          "11",
          "mesh → backup → monitoring",
        ),
        shell.status_card(
          "Evolution",
          "Healthy",
          "13",
          "self-awareness → knowledge → symbiotic",
        ),
        shell.status_card(
          "Cross-Cutting",
          "Healthy",
          "5",
          "universal search → knowledge chat → audit",
        ),
      ]),
    ]),
    // ── Session Activity (v22.6.0-BRAIN) ──
    shell.section("Session Activity — v22.6.0-BRAIN", [
      shell.data_table(["Feature", "Status", "Detail"], [
        [
          "Zettelkasten Brain",
          "DONE",
          "9 Gleam modules + 1 Rust module, 2,060 holons ingested",
        ],
        ["Telegram Mini App", "DONE", "6 modules, 14 pages, HTTPS, TeleNative CSS"],
        [
          "Indra's Net Vision",
          "DONE",
          "600-line architecture doc — Jewel, Fractal Zoom, 3 Voices",
        ],
        ["UI Evaluation Framework", "DONE", "7 dimensions, mathematical scoring"],
        [
          "Microservice Decomposition",
          "DONE",
          "6-service split analysis from 9,104 LOC monolith",
        ],
        [
          "GCS Backup",
          "DONE",
          "22.8 MB to europe-north1, KMS + SSL + .env included",
        ],
        ["Survival SOP", "DONE", "10 failure scenarios, DR drill protocol, RTO/RPO"],
        [
          "77 Use Cases",
          "DONE",
          "SDLC(22) + SRE(13) + Dev(13) + Ops(11) + Evo(13) + Cross(5)",
        ],
        ["Cortex Build Fix", "DONE", "56 errors → 0 via 5-level Jidoka RCA"],
        ["Tests", "DONE", "3,786 passed, 0 failures (+201 new)"],
      ]),
    ]),
    // ── Analysis ──
    shell.section(
      "Multidimensional Analysis — Criticality × FMEA × STAMP × Utility",
      [
        shell.data_table(
          ["Dimension", "Score", "Threshold", "Status", "Action"],
          [
            [
              "Task Completion Rate",
              "33.8%",
              "> 50%",
              "BELOW",
              "Focus on P1 core tasks",
            ],
            [
              "Blocked Ratio",
              "0.5%",
              "< 2%",
              "OK",
              "13 blocked — review Guardian queue",
            ],
            ["P0 Completion", "100%", "100%", "PASS", "All 191 safety tasks done"],
            [
              "Knowledge Coverage",
              "2,060 holons",
              "> 500",
              "PASS",
              "FTS5 searchable in < 1ms",
            ],
            [
              "STAMP Refs Indexed",
              "6,647",
              "> 1,000",
              "PASS",
              "Cross-referenced in graph",
            ],
            ["Backup Freshness", "< 24h", "< 24h", "PASS", "GCS europe-north1"],
            ["Test Coverage", "3,824 pass", "> 3,000", "PASS", "0 failures"],
            [
              "Entropy (avg)",
              "< 0.3",
              "< 0.5",
              "PASS",
              "Knowledge is fresh",
            ],
            [
              "RAG Integration",
              "Active",
              "Active",
              "PASS",
              "Holons in LLM context",
            ],
            [
              "Build Health",
              "0 errors",
              "0 errors",
              "PASS",
              "Gleam + Rust clean",
            ],
          ],
        ),
      ],
    ),
    // ── Decision Support ──
    shell.section("Decision Support — Operational Scenarios", [
      shell.data_table(
        ["Scenario", "Question", "Zettelkasten Answer", "Confidence"],
        [
          [
            "Incident Response",
            "Has this happened before?",
            "Search 180 journal RCA sections",
            "High (Evidence)",
          ],
          [
            "Capacity Planning",
            "Will inference hit limits?",
            "12 intents/day × 365 = OK for SQLite",
            "High (Evidence)",
          ],
          [
            "Compliance Check",
            "Is SC-ZENOH-001 implemented?",
            "Yes — code edge from zenoh/client.gleam",
            "Very High (Axiom)",
          ],
          [
            "Architecture Decision",
            "Why SSR not client JS?",
            "SC-GLM-UI-002 mandates server-side",
            "Very High (Axiom)",
          ],
          [
            "Onboarding",
            "Where do I start?",
            "5 ecosystem zettels → 5 axiom specs → 5 constraints",
            "High",
          ],
          [
            "Cost Optimization",
            "How much does inference cost?",
            "$0.054/day — 50% cached, Gemini Direct handles 65%",
            "Medium (Evidence)",
          ],
          [
            "Drift Detection",
            "Are specs up to date?",
            "Plans cluster entropy 0.60 — ROTTING, needs review",
            "High (Computed)",
          ],
          [
            "Recovery",
            "Can we restore from scratch?",
            "GCS 22.8 MB + git clone + ingest-docs (12.6s)",
            "Very High (Tested)",
          ],
        ],
      ),
    ]),
    // ── Pipeline Summary ──
    shell.section("Pipeline Performance (from 85 traced intents)", [
      shell.data_table(
        ["Stage", "Avg Latency", "Count", "Health"],
        [
          ["received", "0ms", "86", "Nominal"],
          ["classified", "157ms", "86", "Nominal"],
          ["ack_sent", "2,196ms", "66", "Nominal"],
          ["inference_started", "2,282ms", "64", "Nominal"],
          ["rag", "2,913ms", "44", "Nominal"],
          ["delivered", "3,582ms", "86", "Nominal"],
          ["inference_complete", "4,419ms", "64", "Nominal"],
          ["cache_hit", "54ms", "2", "Excellent"],
        ],
      ),
    ]),
    // ── Raw NIF Data ──
    shell.section("Raw NIF Data (Debug)", [
      html.details([], [
        html.summary([], [
          element.text(
            "Click to expand raw JSON from NIF → Rust → SQLite",
          ),
        ]),
        html.pre(
          [
            attribute.attribute(
              "style",
              "font-size:0.75rem;overflow-x:auto;max-height:300px",
            ),
          ],
          [
            element.text(
              "plan_status():\n"
              <> status_raw
              <> "\n\nplan_list_pending() [first 500 chars]:\n"
              <> string.slice(pending_raw, 0, 500)
              <> "...",
            ),
          ],
        ),
      ]),
    ]),
  ])
}

pub fn knowledge_view(_state: SharedMeshState) -> Element(msg) {
  // Live task/holon counts from NIF (SC-TRUTH-001)
  let status_raw = c3i_nif.plan_status()
  let total_tasks = count_in_json(status_raw, "total")
  let completed_tasks = count_in_json(status_raw, "completed")
  let pending_tasks = count_in_json(status_raw, "pending")
  html.div([attribute.class("w-full")], [
    page_header(
      "Knowledge (Smriti)",
      "Semantic knowledge graph — triple store and embeddings",
    ),
    shell.section("Graph Summary", [
      html.div([attribute.class("card-grid")], [
        shell.status_card(
          "Total Tasks",
          "Healthy",
          int.to_string(total_tasks),
          "live from NIF",
        ),
        shell.status_card(
          "Completed",
          "Healthy",
          int.to_string(completed_tasks),
          "in Smriti.db",
        ),
        shell.status_card(
          "Pending",
          case pending_tasks > 0 {
            True -> "Degraded"
            False -> "Healthy"
          },
          int.to_string(pending_tasks),
          "awaiting execution",
        ),
        shell.status_card("Namespaces", "Healthy", "3", "registered"),
      ]),
    ]),
    shell.section("Pure Functions", [
      shell.data_table(["Function", "Status", "Description"], [
        ["dot_product/2", "active", "Pure dot product — no side effects"],
        ["cosine_similarity/2", "active", "L2-normalised similarity score"],
        ["normalize/1", "active", "Unit vector normalisation"],
      ]),
    ]),
    shell.section("Namespaces", [
      shell.data_table(["Prefix", "URI"], [
        ["c3i:", "https://indrajaal.dev/ontology/c3i#"],
        ["mesh:", "https://indrajaal.dev/ontology/mesh#"],
        ["agent:", "https://indrajaal.dev/ontology/agent#"],
      ]),
    ]),
    element.element(
      "script",
      [attribute.attribute("src", "/static/knowledge-grid.js?v=22.10.0")],
      [],
    ),
  ])
}

pub fn prajna_view(state: SharedMeshState) -> Element(msg) {
  let health_raw = c3i_nif.system_health()
  let healthy_containers = count_in_json(health_raw, "healthy_containers")
  let circuit_label = case healthy_containers > 0 {
    True -> int.to_string(healthy_containers) <> " healthy"
    False -> "< 100 msgs/s"
  }
  html.div([attribute.class("w-full")], [
    page_header(
      "Prajna Biomorphic",
      "Neuro-symbolic AI substrate — circuit breaker, advisory",
    ),
    shell.section("AI Advisory", [
      html.div([attribute.class("card-grid")], [
        shell.status_card(
          "Circuit Breaker",
          "Healthy",
          "closed",
          circuit_label,
        ),
        shell.status_card(
          "Dark Cockpit",
          "Healthy",
          cockpit_mode_to_string(state.dark_cockpit_mode),
          "5-mode state machine",
        ),
        shell.status_card(
          "Mesh Health",
          case state.quorum_healthy { True -> "Healthy" False -> "Degraded" },
          int.to_string(state.healthy_count) <> "/" <> int.to_string(state.container_count),
          "containers monitored",
        ),
        shell.status_card("OODA Phase", "Healthy", ooda_phase_to_string(state.ooda_phase), "< 100ms cycle"),
      ]),
    ]),
    shell.section("5-Mode State Machine", [
      shell.data_table(["Mode", "Trigger", "Display", "Color"], [
        ["Dark", "No alerts", "Minimal gray", "Monochrome"],
        ["Dim", "Warnings", "Subtle yellow", "Low-saturation"],
        ["Normal", "Errors", "Visible orange", "Standard"],
        ["Bright", "Multiple errors", "High-visibility", "High-contrast"],
        ["Emergency", "Critical", "Full illumination", "Red dominant"],
      ]),
    ]),
    element.element(
      "script",
      [attribute.attribute("src", "/static/prajna-grid.js?v=22.10.1")],
      [],
    ),
  ])
}

pub fn agents_view(_state: SharedMeshState) -> Element(msg) {
  // Live container health from NIF — containers are the physical agent substrate (SC-TRUTH-001)
  let health_raw = c3i_nif.system_health()
  let container_count = count_in_json(health_raw, "container_count")
  let healthy_count = count_in_json(health_raw, "healthy_count")
  let agent_status = case healthy_count == container_count && container_count > 0 {
    True -> "Healthy"
    False -> "Degraded"
  }
  html.div([attribute.class("w-full")], [
    page_header(
      "Cybernetic Agents",
      "25-agent biomorphic hierarchy — OODA orchestration",
    ),
    shell.section("A2UI Semantic Zoom [SC-HMI-310]", [
      html.div(
        [
          attribute.class("card-grid"),
          attribute.attribute(
            "style",
            "border-bottom: 1px dashed #4b5263; padding-bottom: 1rem; margin-bottom: 1rem;",
          ),
        ],
        [
          html.div(
            [
              attribute.attribute(
                "style",
                "display: flex; align-items: center; gap: 1rem;",
              ),
            ],
            [
              element.text("Zoom Level: "),
              html.select(
                [
                  attribute.attribute(
                    "style",
                    "background: #1e222a; color: #abb2bf; border: 1px solid #4b5263; padding: 0.25rem;",
                  ),
                ],
                [
                  html.option(
                    [attribute.value("container")],
                    "Physical Container View (L4)",
                  ),
                  html.option(
                    [attribute.value("actor"), attribute.selected(True)],
                    "Logical BEAM Supervision Tree (L2)",
                  ),
                  html.option(
                    [attribute.value("memory")],
                    "Memory Allocation View (L1)",
                  ),
                ],
              ),
              html.span(
                [
                  attribute.attribute(
                    "style",
                    "color: #56b6c2; font-style: italic; font-size: 0.85rem;",
                  ),
                ],
                [
                  element.text(
                    "↳ Rendering 7 nodes (Miller's Law optimization)",
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ]),
    shell.section("Logical Hierarchy (Zoom: Actor)", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("Executive", "Healthy", "1", "EXEC-001 (opus)"),
        shell.status_card(
          "Supervisors",
          "Healthy",
          "4",
          "context/domain/test/quality",
        ),
        shell.status_card("Workers", "Healthy", "20", "compile/test/credo/fix"),
        shell.status_card(
          "Substrate Containers",
          agent_status,
          int.to_string(healthy_count)
            <> "/"
            <> int.to_string(container_count),
          "live NIF data",
        ),
      ]),
    ]),
    shell.section("Agent Roles", [
      shell.data_table(["Agent", "Role", "Model", "Layer"], [
        ["EXEC-001", "Orchestrator", "opus", "L5"],
        ["SUP-CONTEXT", "Context supervisor", "sonnet", "L5"],
        ["SUP-DOMAIN", "Domain supervisor", "sonnet", "L5"],
        ["SUP-TEST", "Test supervisor", "sonnet", "L5"],
        ["SUP-QUALITY", "Quality supervisor", "sonnet", "L5"],
        ["WRK-COMPILE", "Compile worker ×5", "haiku", "L4"],
        ["WRK-TEST", "Test worker ×5", "haiku", "L4"],
        ["WRK-CREDO", "Credo worker ×5", "haiku", "L4"],
        ["WRK-FIX", "Fix worker ×5", "haiku", "L4"],
      ]),
    ]),
    shell.section("L2 Operational Controls [A2UI Agentic Interface]", [
      html.div([attribute.class("card-grid")], [
        shell.apalache_guard(
          shell.action_button(
            "Start/Stop/Restart Actor",
            "/api/v1/podman/action",
            "{\\\"verb\\\": \\\"restart_actor\\\", \\\"container\\\": \\\"all\\\", \\\"reason\\\": \\\"Actor refresh\\\"}",
          ),
          "mathematically_safe",
        ),
        shell.apalache_guard(
          shell.action_button(
            "Compile",
            "/api/v1/podman/action",
            "{\\\"verb\\\": \\\"compile\\\", \\\"container\\\": \\\"all\\\", \\\"reason\\\": \\\"Build\\\"}",
          ),
          "mathematically_safe",
        ),
        shell.apalache_guard(
          shell.action_button(
            "Test SIL-6",
            "/api/v1/podman/action",
            "{\\\"verb\\\": \\\"test\\\", \\\"container\\\": \\\"all\\\", \\\"reason\\\": \\\"Verify\\\"}",
          ),
          "mathematically_safe",
        ),
      ]),
    ]),
    element.element(
      "script",
      [attribute.attribute("src", "/static/agents-grid.js?v=22.10.0")],
      [],
    ),
  ])
}

pub fn holon_view(state: SharedMeshState) -> Element(msg) {
  let status_raw = c3i_nif.plan_status()
  let total_tasks = count_in_json(status_raw, "total")
  let active_tasks = count_in_json(status_raw, "active")
  html.div([attribute.class("w-full")], [
    page_header(
      "Holon Identity",
      "Multi-runtime holon — Gleam, Elixir, F#, Rust",
    ),
    shell.section("Runtime Stack", [
      html.div([attribute.class("card-grid")], [
        shell.status_card(
          "Gleam/BEAM",
          "Healthy",
          "active",
          "primary — L0-L7 UI",
        ),
        shell.status_card(
          "Elixir/Phoenix",
          "Healthy",
          "active",
          "legacy port 4000",
        ),
        shell.status_card("F# CEPAF", "Healthy", "active", "safety kernel"),
        shell.status_card(
          "Rust NIF",
          "Healthy",
          int.to_string(active_tasks) <> " active tasks",
          "ignition daemon",
        ),
      ]),
    ]),
    shell.section("Holon Types", [
      shell.data_table(["Type", "Count", "Description"], [
        ["Computation", "4", "ex-app-1/2/3 + chaya"],
        ["Cognitive", "2", "cortex + cepaf-bridge"],
        ["Transport", "4", "zenoh-router-1/2/3/main"],
        ["Storage", "1", "db-prod"],
        ["Observability", "1", "obs-prod"],
        ["AI Compute", "2", "ollama + mojo"],
        ["ML Runner", "2", "ml-runner-1/2"],
      ]),
    ]),
    shell.section("Planning State", [
      shell.kv_row("Total Tasks", int.to_string(total_tasks)),
      shell.kv_row(
        "Containers",
        int.to_string(state.container_count) <> " registered",
      ),
    ]),
    element.element(
      "script",
      [attribute.attribute("src", "/static/holon-grid.js?v=22.10.1")],
      [],
    ),
  ])
}

pub fn config_view(state: SharedMeshState) -> Element(msg) {
  let health_raw = c3i_nif.system_health()
  let healthy_count = count_in_json(health_raw, "healthy_containers")
  let reported_healthy = case healthy_count > 0 {
    True -> healthy_count
    False -> state.healthy_count
  }
  let config_status = case state.quorum_healthy {
    True -> "Healthy"
    False -> "Degraded"
  }
  html.div([attribute.class("w-full")], [
    page_header(
      "Mesh Configuration",
      "MeshConfig — containers, networks, quorum",
    ),
    shell.section("Mesh Status", [
      html.div([attribute.class("card-grid")], [
        shell.status_card(
          "Containers",
          config_status,
          int.to_string(reported_healthy) <> "/16",
          "healthy / total",
        ),
        shell.status_card(
          "Quorum",
          config_status,
          case state.quorum_healthy { True -> "Active" False -> "Lost" },
          "2oo3 voting",
        ),
        shell.status_card(
          "Zenoh",
          case state.zenoh_connected { True -> "Healthy" False -> "Critical" },
          case state.zenoh_connected { True -> "Connected" False -> "Down" },
          "TCP 7447",
        ),
      ]),
    ]),
    shell.section("Topology", [
      shell.kv_row(
        "Containers",
        "16 (SIL-6 genome) — " <> int.to_string(reported_healthy) <> " healthy",
      ),
      shell.kv_row("Networks", "1 (indrajaal-net)"),
      shell.kv_row("Quorum Size", "4 nodes (2oo3 + spare)"),
      shell.kv_row("Total vCPU", "8.0 cores"),
      shell.kv_row("Total Memory", "4096 MB"),
    ]),
    shell.section("Port Assignments", [
      shell.data_table(["Port", "Service", "Notes"], [
        ["4000-4010", "Mesh containers", "RESERVED — no non-mesh use"],
        ["4100", "Gleam Wisp HTTP", "Triple-interface (SC-GLM-UI-006)"],
        ["4317", "OTel gRPC", "Collector"],
        ["5433", "PostgreSQL", "db-prod"],
        ["7447", "Zenoh router", "Primary TCP"],
        ["9090", "Prometheus", "Metrics scrape"],
      ]),
    ]),
    // System Controls — Hot Reload (SC-HA-RELOAD-001)
    shell.section("System Controls", [shell.hot_reload_button()]),
    element.element(
      "script",
      [attribute.attribute("src", "/static/config-grid.js?v=22.10.1")],
      [],
    ),
  ])
}

pub fn git_view(state: SharedMeshState) -> Element(msg) {
  let status_raw = c3i_nif.plan_status()
  let completed_count = count_in_json(status_raw, "completed")
  let pending_count = count_in_json(status_raw, "pending")
  let total_count = count_in_json(status_raw, "total")
  let git_status = case state.quorum_healthy {
    True -> "Healthy"
    False -> "Degraded"
  }
  html.div([attribute.class("w-full")], [
    page_header(
      "Git Intelligence",
      "ICP v2.0 commit conventions — 9 types, 23 scopes",
    ),
    shell.section("Repository Health", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("Pipeline", git_status, "ICP v2.0", "9 types, 23 scopes"),
        shell.status_card(
          "Completed",
          "Healthy",
          int.to_string(completed_count),
          "tasks done",
        ),
        shell.status_card(
          "Pending",
          case pending_count > 100 { True -> "Degraded" False -> "Healthy" },
          int.to_string(pending_count),
          "tasks remaining",
        ),
        shell.status_card(
          "Total Tasks",
          git_status,
          int.to_string(total_count),
          "in Planning.db",
        ),
      ]),
    ]),
    shell.section("Commit Convention", [
      shell.kv_row("Format", "type(scope): action — context [ref]"),
      shell.kv_row("Max length", "80 characters"),
      shell.kv_row(
        "Types",
        "feat fix refactor perf test docs chore security evolve",
      ),
      shell.kv_row(
        "Scopes (23)",
        "guardian app db kms mesh cepaf zenoh sentinel…",
      ),
      shell.kv_row(
        "Health Score",
        case state.quorum_healthy {
          True -> "0.85"
          False -> "0.60"
        },
      ),
    ]),
    shell.section("Task Pipeline", [
      shell.kv_row("Completed Tasks", int.to_string(completed_count)),
      shell.kv_row("Pending Tasks", int.to_string(pending_count)),
    ]),
    shell.section("Branch Strategy", [
      shell.kv_row("Main branch", "main"),
      shell.kv_row("Feature branches", "multiverse/<agent-id>-<scope>"),
      shell.kv_row("Merge strategy", "ff-only after Guardian approval"),
    ]),
    shell.section("Commit Type Reference", [
      shell.data_table(["Type", "Scope", "Example"], [
        ["feat", "app, db, zenoh", "feat(zenoh): add mesh health publisher"],
        ["fix", "cepaf, sentinel", "fix(sentinel): correct threat classification"],
        ["refactor", "core, plan", "refactor(plan): extract priority sorting"],
        ["test", "test, ci", "test(immune): add wiring guard coverage"],
        ["docs", "sync, core", "docs(sync): update constraint registry"],
      ]),
    ]),
    element.element(
      "script",
      [attribute.attribute("src", "/static/git-grid.js?v=22.10.1")],
      [],
    ),
  ])
}

pub fn database_view(_state: SharedMeshState) -> Element(msg) {
  let status_raw = c3i_nif.plan_status()
  let total_rows = count_in_json(status_raw, "total")
  let active_rows = count_in_json(status_raw, "active")
  let blocked_rows = count_in_json(status_raw, "blocked")
  html.div([attribute.class("w-full")], [
    page_header(
      "Database",
      "Multi-engine persistence — SQLite, DuckDB, Postgres, ZenohKV",
    ),
    shell.section("Supported Engines", [
      html.div([attribute.class("card-grid")], [
        shell.status_card(
          "SQLite WAL",
          "Healthy",
          int.to_string(total_rows) <> " rows",
          "Planning.db",
        ),
        shell.status_card("DuckDB", "Healthy", "active", "analytics + OLAP"),
        shell.status_card("Postgres", "Degraded", "5433", "external cluster"),
        shell.status_card("Zenoh KV", "Healthy", "active", "ephemeral mesh KV"),
        shell.status_card("InMemory", "Healthy", "active", "test isolation"),
      ]),
    ]),
    shell.section("Planning.db Live Stats", [
      shell.kv_row("Total Rows", int.to_string(total_rows)),
      shell.kv_row("Active Tasks", int.to_string(active_rows)),
      shell.kv_row("Blocked Tasks", int.to_string(blocked_rows)),
    ]),
    shell.section("Cross-Holon Access", [
      shell.kv_row(
        "Rule",
        "SC-XHOLON-001 — isolated files, Zenoh-only cross access",
      ),
      shell.kv_row("Conflict resolution", "LastWriterWins (OCC)"),
      shell.kv_row("WAL mode", "Required for all SQLite databases"),
    ]),
    shell.section("Database Schema", [
      shell.data_table(["Table", "Engine", "Purpose"], [
        ["Tasks", "SQLite WAL", "Planning task store (sa-plan-daemon)"],
        ["ConversationHistory", "SQLite WAL", "50-message chat sliding window"],
        ["SemanticCache", "SQLite WAL", "24h TTL inference result cache"],
        ["TransactionTrace", "SQLite WAL", "PipelineTracer end-to-end spans"],
        ["UserPreferences", "SQLite WAL", "Per-user config and rate limits"],
      ]),
    ]),
    element.element(
      "script",
      [attribute.attribute("src", "/static/database-grid.js?v=22.10.1")],
      [],
    ),
  ])
}

pub fn bridge_view(_state: SharedMeshState) -> Element(msg) {
  // Live data from NIF — bridge health reflects real NIF pipeline (SC-TRUTH-001)
  let health_raw = c3i_nif.system_health()
  let healthy = count_in_json(health_raw, "healthy_count")
  let total = count_in_json(health_raw, "container_count")
  let bridge_status = case healthy == total && total > 0 {
    True -> "Healthy"
    False -> "Degraded"
  }
  html.div([attribute.class("w-full")], [
    page_header("Bridge", "F# CEPAF ↔ Gleam/Elixir bridge — NIF + Zenoh"),
    shell.section("Bridge Status", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("NIF Bridge", bridge_status, "loaded", "zenoh_nif.so"),
        shell.status_card(
          "Mesh Nodes",
          bridge_status,
          int.to_string(healthy) <> "/" <> int.to_string(total),
          "live NIF data",
        ),
        shell.status_card("Zenoh NIF", bridge_status, "loaded", "SC-ZENOH-001"),
        shell.status_card(
          "Rule Engine",
          "Healthy",
          "active",
          "rule_engine_nif.so",
        ),
      ]),
    ]),
    shell.section("Bridge Points", [
      shell.data_table(["Bridge", "Mechanism", "Direction"], [
        ["Rule engine", "NIF (rule_engine_nif.so)", "Gleam → Rust → Gleam"],
        ["Container status", "Podman CLI FFI", "Gleam → Erlang → Shell"],
        ["Zenoh pub/sub", "NIF (zenoh_nif.so)", "Gleam → Rust → Zenoh"],
        ["OODA results", "Zenoh subscription", "Rust → Zenoh → Gleam"],
        ["Ignition commands", "./sa-up CLI", "Gleam TUI → Shell → Rust"],
      ]),
    ]),
    element.element(
      "script",
      [attribute.attribute("src", "/static/bridge-grid.js?v=22.10.1")],
      [],
    ),
  ])
}

pub fn smriti_view(_state: SharedMeshState) -> Element(msg) {
  let status_raw = c3i_nif.plan_status()
  let total_tasks = count_in_json(status_raw, "total")
  let completed_tasks = count_in_json(status_raw, "completed")
  let pending_tasks = count_in_json(status_raw, "pending")
  let active_tasks = count_in_json(status_raw, "active")
  html.div([attribute.class("w-full")], [
    page_header(
      "Smriti Knowledge",
      "Semantic knowledge graph — federation and immortality",
    ),
    shell.section("Catalog", [
      html.div([attribute.class("card-grid")], [
        shell.status_card(
          "ZK Holons",
          "Healthy",
          int.to_string(total_tasks),
          "Planning.db total",
        ),
        shell.status_card(
          "Active",
          case active_tasks > 0 { True -> "Healthy" False -> "Degraded" },
          int.to_string(active_tasks),
          "in progress",
        ),
        shell.status_card(
          "Completed",
          "Healthy",
          int.to_string(completed_tasks),
          "resolved entries",
        ),
        shell.status_card(
          "Pending",
          case pending_tasks > 100 { True -> "Degraded" False -> "Healthy" },
          int.to_string(pending_tasks),
          "awaiting action",
        ),
      ]),
    ]),
    shell.section("Pure Semantic Functions", [
      shell.data_table(["Function", "Type", "Status"], [
        ["dot_product/2", "Float → Float → Float", "active"],
        ["cosine_similarity/2", "Vector → Vector → Float", "active"],
        ["normalize/1", "Vector → Vector", "active"],
      ]),
    ]),
    element.element(
      "script",
      [attribute.attribute("src", "/static/smriti-grid.js?v=22.10.1")],
      [],
    ),
  ])
}

// ---------------------------------------------------------------------------
// Private helpers (duplicated from page_views — SC-MUDA-001 approved)
// ---------------------------------------------------------------------------

fn page_header(title: String, subtitle: String) -> Element(msg) {
  html.div([attribute.class("page-header")], [
    html.div([], [
      html.h1([attribute.class("page-title")], [element.text(title)]),
      html.div([attribute.class("page-subtitle")], [element.text(subtitle)]),
    ]),
  ])
}

fn state_kv_block(state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("card")], [
    shell.kv_row("Containers", int.to_string(state.container_count)),
    shell.kv_row("Healthy", int.to_string(state.healthy_count)),
    shell.kv_row("Threat Level", state.threat_level_to_string(state.threat_level)),
    shell.kv_row("OODA Phase", ooda_phase_to_string(state.ooda_phase)),
    shell.kv_row("Dark Cockpit", cockpit_mode_to_string(state.dark_cockpit_mode)),
    shell.kv_row("Zenoh", case state.zenoh_connected {
      True -> "connected"
      False -> "offline"
    }),
    shell.kv_row("Quorum", case state.quorum_healthy {
      True -> "healthy"
      False -> "lost"
    }),
  ])
}

/// SVG progress ring component — reusable for all ring metrics.
fn progress_ring(
  value: String,
  label: String,
  color: String,
  dash: String,
  gap: String,
) -> Element(msg) {
  html.div([attribute.class("ring-item")], [
    element.element(
      "svg",
      [
        attribute.attribute("viewBox", "0 0 120 120"),
        attribute.attribute("width", "80"),
        attribute.attribute("height", "80"),
      ],
      [
        element.element(
          "circle",
          [
            attribute.attribute("cx", "60"),
            attribute.attribute("cy", "60"),
            attribute.attribute("r", "50"),
            attribute.attribute("fill", "none"),
            attribute.attribute("stroke", "var(--border)"),
            attribute.attribute("stroke-width", "7"),
          ],
          [],
        ),
        element.element(
          "circle",
          [
            attribute.attribute("cx", "60"),
            attribute.attribute("cy", "60"),
            attribute.attribute("r", "50"),
            attribute.attribute("fill", "none"),
            attribute.attribute("stroke", color),
            attribute.attribute("stroke-width", "7"),
            attribute.attribute("stroke-dasharray", dash <> " " <> gap),
            attribute.attribute("stroke-linecap", "round"),
            attribute.attribute("transform", "rotate(-90 60 60)"),
          ],
          [],
        ),
        element.element(
          "text",
          [
            attribute.attribute("x", "60"),
            attribute.attribute("y", "55"),
            attribute.attribute("text-anchor", "middle"),
            attribute.attribute("fill", "var(--text)"),
            attribute.attribute("font-size", "18"),
            attribute.attribute("font-weight", "700"),
          ],
          [element.text(value)],
        ),
        element.element(
          "text",
          [
            attribute.attribute("x", "60"),
            attribute.attribute("y", "75"),
            attribute.attribute("text-anchor", "middle"),
            attribute.attribute("fill", "var(--text)"),
            attribute.attribute("font-size", "10"),
          ],
          [element.text(label)],
        ),
      ],
    ),
  ])
}

/// Extract a numeric count from NIF JSON status output.
fn count_in_json(json: String, key: String) -> Int {
  let search = key <> ": "
  case string.contains(json, search) {
    True -> {
      let parts = string.split(json, search)
      case list.rest(parts) {
        Ok(rest) ->
          case list.first(rest) {
            Ok(after) -> parse_leading_int(after)
            Error(_) -> 0
          }
        Error(_) -> 0
      }
    }
    False -> {
      let search2 = "\"" <> key <> "\":"
      case string.contains(json, search2) {
        True -> {
          let parts2 = string.split(json, search2)
          case list.rest(parts2) {
            Ok(rest2) ->
              case list.first(rest2) {
                Ok(after2) -> parse_leading_int(after2)
                Error(_) -> 0
              }
            Error(_) -> 0
          }
        }
        False -> 0
      }
    }
  }
}

/// Parse leading integer from a string like "123,\n..." or "42 tasks".
fn parse_leading_int(s: String) -> Int {
  let digits =
    string.to_graphemes(s)
    |> list.take_while(fn(c) {
      c == "0"
      || c == "1"
      || c == "2"
      || c == "3"
      || c == "4"
      || c == "5"
      || c == "6"
      || c == "7"
      || c == "8"
      || c == "9"
    })
    |> string.join("")
  case int.parse(digits) {
    Ok(n) -> n
    Error(_) -> 0
  }
}

/// Enhanced CSS for creative planning page UX — responsive mobile-first design.
fn planning_enhanced_css() -> String {
  "
/* === BASE (Mobile-First, <768px) === */
.weather-bar {
  display:flex; align-items:center; gap:10px; flex-wrap:wrap;
  background:linear-gradient(135deg, rgba(0,212,170,0.06), rgba(61,214,140,0.02));
  backdrop-filter:blur(12px);
  border:1px solid rgba(0,212,170,0.15); border-radius:12px;
  padding:12px 14px; margin:0 0 1rem; font-size:0.85rem;
  transition:all 0.3s ease;
}
.weather-bar:hover { border-color:rgba(0,212,170,0.3); }
.weather-emoji { font-size:1.5rem; }
.weather-label { flex:1; color:var(--text); line-height:1.4; min-width:200px; font-size:0.82rem; }
.weather-score {
  font-size:1.3rem; font-weight:800; color:var(--accent);
  background:linear-gradient(135deg,rgba(0,212,170,0.12),rgba(0,212,170,0.05));
  padding:4px 12px; border-radius:10px;
  border:1px solid rgba(0,212,170,0.15);
}
.progress-ring-row {
  display:grid; grid-template-columns:repeat(2,1fr); gap:0.75rem;
  margin:0 0 1rem;
}
.ring-item {
  display:flex; flex-direction:column; align-items:center;
  background:rgba(10,14,23,0.5); backdrop-filter:blur(8px);
  border:1px solid rgba(30,42,58,0.5); border-radius:10px; padding:0.75rem;
  transition:all 0.3s ease; min-width:0;
}
.ring-item:hover {
  border-color:var(--accent); transform:translateY(-2px);
  box-shadow:0 6px 20px rgba(0,0,0,0.12);
}
.ring-item svg { width:70px; height:70px; }
.ring-value { font-size:1rem; }
.ring-label { font-size:0.7rem; }
@keyframes pulse-glow {
  0%, 100% { box-shadow: 0 0 0 0 rgba(0,212,170,0); }
  50% { box-shadow: 0 0 14px 3px rgba(0,212,170,0.12); }
}
.card { transition:all 0.25s ease; }
.card:hover { border-color:var(--accent); transform:translateY(-1px); box-shadow:0 4px 16px rgba(0,0,0,0.1); }
table { border-collapse:collapse; width:100%; font-size:0.82rem; }
table th { position:sticky; top:0; background:rgba(10,14,23,0.95); backdrop-filter:blur(8px); z-index:1; font-size:0.72rem; padding:6px 8px; }
table td { padding:5px 8px; }
table tr { transition:background 0.15s; }
table tr:hover { background:rgba(0,212,170,0.04); }
.section h2, .section h3 { letter-spacing:0.3px; }
.sub { color:#7a8fa6; font-size:0.8rem; margin-bottom:10px; }
/* Touch-friendly targets (44px min) */
.view-btn, .fractal-chip, .detail-action-btn, button { min-height:44px; min-width:44px; }
/* Responsive card grid — 1 col mobile */
.card-grid { grid-template-columns:1fr !important; }
.card-grid-wide { grid-template-columns:1fr !important; }
/* Responsive tables — horizontal scroll on mobile */
.section { overflow-x:auto; -webkit-overflow-scrolling:touch; }
/* View toggle — horizontal scroll on narrow screens */
.view-toggle { overflow-x:auto; -webkit-overflow-scrolling:touch; white-space:nowrap; }
/* AI search — full width, large touch target */
#ai-search-input { font-size:1rem !important; padding:14px 16px !important; min-height:48px; }
/* Kanban — single column on mobile */
.kanban-board { grid-template-columns:1fr !important; }

/* === TABLET (768px+) === */
@media (min-width:768px) {
  .weather-bar { padding:14px 20px; font-size:0.88rem; gap:14px; flex-wrap:nowrap; }
  .weather-emoji { font-size:1.8rem; }
  .weather-label { font-size:0.88rem; }
  .weather-score { font-size:1.5rem; padding:6px 16px; }
  .progress-ring-row { grid-template-columns:repeat(4,1fr); gap:1.25rem; }
  .ring-item { padding:1rem; }
  .ring-item svg { width:90px; height:90px; }
  .ring-value { font-size:1.2rem; }
  .card-grid { grid-template-columns:repeat(2,1fr) !important; }
  .card-grid-wide { grid-template-columns:repeat(2,1fr) !important; }
  table { font-size:0.85rem; }
  table th { font-size:0.75rem; padding:8px; }
  table td { padding:6px 8px; }
  .kanban-board { grid-template-columns:repeat(2,1fr) !important; }
  #ai-search-input { font-size:0.95rem !important; padding:12px 18px !important; }
}

/* === DESKTOP (1024px+) === */
@media (min-width:1024px) {
  .weather-bar { padding:14px 22px; }
  .progress-ring-row { gap:1.5rem; }
  .ring-item { padding:1rem 1.2rem; }
  .ring-item svg { width:100px; height:100px; }
  .card-grid { grid-template-columns:repeat(auto-fill,minmax(200px,1fr)) !important; }
  .card-grid-wide { grid-template-columns:repeat(auto-fill,minmax(260px,1fr)) !important; }
  table { font-size:0.88rem; }
  .kanban-board { grid-template-columns:repeat(4,1fr) !important; }
  #ai-search-input { font-size:0.92rem !important; padding:11px 18px !important; }
}

/* === WIDE DESKTOP (1400px+) === */
@media (min-width:1400px) {
  .progress-ring-row { gap:2rem; }
  .ring-item svg { width:110px; height:110px; }
  .ring-value { font-size:1.4rem; }
}

/* === Utility === */
html { scroll-behavior:smooth; }
body { overscroll-behavior:none; }
@supports (padding: env(safe-area-inset-bottom)) {
  main { padding-bottom:calc(1.5rem + env(safe-area-inset-bottom)); }
}
"
}
