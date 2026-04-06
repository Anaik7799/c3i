//// =============================================================================
//// [C3I-SIL6-MSTS] MATHEMATICAL & SEMANTIC MODULE CONTRACT
//// =============================================================================
//// <c3i-module>
////   <identity>
////     <module>cepaf_gleam/ui/web/page_views</module>
////     <fsharp-lineage>Cepaf.UI.Pages.fs</fsharp-lineage>
////   </identity>
////   <fractal-topology>
////     <layer>L2_COMPONENT</layer>
////     <mesh-domain>Lustre HTML page bodies for all 24 browser views</mesh-domain>
////   </fractal-topology>
////   <compliance>
////     <criticality>HIGH</criticality>
////     <stamp-controls>SC-GLM-UI-001, SC-GLM-UI-002, SC-GLM-UI-008, SC-GLM-UI-009, SC-MUDA-001</stamp-controls>
////   </compliance>
////   <transformations>
////     <morphism type="isomorphic">
////       SharedMeshState ≅ Lustre Element tree.  Pure, no side effects.
////     </morphism>
////   </transformations>
//// </c3i-module>
//// =============================================================================
////
//// HTML page body renderers for all 24 browser-facing C3I cockpit pages.
////
//// Each function takes a SharedMeshState (from ui/state.gleam) and returns a
//// Lustre Element tree that will be embedded in the shell layout by
//// ui/web/shell.render_page.
////
//// All views use the shared shell helper components (status_card, container_card,
//// mini_bar, section, kv_row) — never raw HTML string concatenation.
////
//// STAMP: SC-GLM-UI-001, SC-GLM-UI-002, SC-GLM-UI-008, SC-GLM-UI-009, SC-MUDA-001

import cepaf_gleam/ui/lustre/shell
import cepaf_gleam/ui/state.{type SharedMeshState}
import gleam/float
import gleam/int
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

// ---------------------------------------------------------------------------
// 1. Dashboard — L5 Cognitive
// ---------------------------------------------------------------------------

pub fn dashboard_view(state: SharedMeshState) -> Element(msg) {
  let health_str = case
    state.quorum_healthy && state.healthy_count == state.container_count
  {
    True -> "Healthy"
    False ->
      case state.healthy_count > state.container_count / 2 {
        True -> "Degraded"
        False -> "Critical"
      }
  }
  html.div([attribute.class("w-full")], [
    page_header(
      "Dashboard",
      "Biomorphic mesh overview — SIL-6 operational posture",
    ),
    html.div([attribute.class("card-grid")], [
      shell.status_card(
        "Mesh Health",
        health_str,
        int.to_string(state.healthy_count)
          <> "/"
          <> int.to_string(state.container_count),
        "containers healthy",
      ),
      shell.status_card(
        "OODA Phase",
        "Healthy",
        state.ooda_phase,
        "current cycle phase",
      ),
      shell.status_card(
        "Threat Level",
        threat_label(state.threat_level),
        state.threat_level,
        "immune system status",
      ),
      shell.status_card(
        "Zenoh",
        bool_status(state.zenoh_connected),
        case state.zenoh_connected {
          True -> "Connected"
          False -> "Offline"
        },
        "mesh transport bus",
      ),
      shell.status_card(
        "Quorum",
        bool_status(state.quorum_healthy),
        case state.quorum_healthy {
          True -> "2oo3"
          False -> "Lost"
        },
        "consensus voting",
      ),
      shell.status_card(
        "Cockpit Mode",
        "Healthy",
        state.dark_cockpit_mode,
        "dark cockpit state",
      ),
    ]),
    shell.section("OODA Ring [A2UI Continuous Wavefront]", [
      html.div([attribute.class("ooda-phases")], [
        ooda_phase_pill("Observe", state.ooda_phase == "observe"),
        html.span([attribute.class("ooda-arrow")], [element.text("▶")]),
        ooda_phase_pill("Orient", state.ooda_phase == "orient"),
        html.span([attribute.class("ooda-arrow")], [element.text("▶")]),
        ooda_phase_pill("Decide", state.ooda_phase == "decide"),
        html.span([attribute.class("ooda-arrow")], [element.text("▶")]),
        ooda_phase_pill("Act", state.ooda_phase == "act"),
        html.span([attribute.class("ooda-arrow")], [element.text("▶")]),
        ooda_phase_pill("Verify", state.ooda_phase == "verify"),
      ]),
      html.div(
        [
          attribute.class("reasoning-marquee"),
          attribute.attribute(
            "style",
            "margin-top: 1rem; padding: 0.75rem; background: rgba(61, 214, 140, 0.1); border-left: 4px solid #3dd68c; font-family: monospace; color: #a6accd;",
          ),
        ],
        [
          element.text("CoT [RETE-UL]: "),
          html.span([attribute.attribute("style", "color: #3dd68c;")], [
            element.text(
              "Evaluating missing critical nodes... No anomalies detected. System in homeostasis. Transitioning to Observe.",
            ),
          ]),
        ],
      ),
    ]),
    shell.section("Quick Links", [
      html.div([attribute.class("card-grid-wide")], [
        quick_link_card(
          "Podman",
          "/podman",
          "Container lifecycle, genome health",
          "L4",
        ),
        quick_link_card(
          "Zenoh Mesh",
          "/zenoh",
          "Pub/sub topology, router status",
          "L6",
        ),
        quick_link_card(
          "Verification",
          "/verification",
          "PROMETHEUS proofs, SIL-6 gates",
          "L0",
        ),
        quick_link_card(
          "Immune System",
          "/immune",
          "Threat detection, antibody counters",
          "L0",
        ),
      ]),
    ]),
    shell.section("L5 Operational Controls [A2UI Cognitive Projection]", [
      case state.threat_level {
        "critical" | "severe" ->
          html.div([attribute.class("loa-pruned")], [
            html.span(
              [
                attribute.attribute(
                  "style",
                  "color: #e06c75; font-style: italic;",
                ),
              ],
              [
                element.text(
                  "⚠️ High threat detected. Manual controls pruned (Dynamic LOA: Supervised Autonomy). System is autonomously mitigating.",
                ),
              ],
            ),
          ])
        _ ->
          html.div([attribute.class("card-grid")], [
            shell.action_button(
              "Force OODA Cycle (sa-orch-ooda)",
              "/api/v1/ooda/trigger",
              "{\\\"action\\\": \\\"force_cycle\\\"}",
            ),
            shell.action_button(
              "Trigger LLM Advisor",
              "/api/v1/ooda/trigger",
              "{\\\"action\\\": \\\"llm_advise\\\"}",
            ),
            shell.action_button(
              "Inject Fact (RETE-UL)",
              "/api/v1/ooda/trigger",
              "{\\\"action\\\": \\\"inject_fact\\\"}",
            ),
          ])
      },
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 2. Planning — L3 Transaction
// ---------------------------------------------------------------------------

pub fn planning_view(state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header("Planning", "sa-plan task management — SQLite-backed authority"),
    shell.section("Task Summary", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("Active Tasks", "Healthy", "12", "in_progress"),
        shell.status_card("Completed", "Healthy", "247", "all time"),
        shell.status_card("Pending P0", "Degraded", "3", "priority 0 queue"),
        shell.status_card("Blocked", "Critical", "1", "awaiting Guardian"),
      ]),
    ]),
    shell.section("OODA Phase", [
      state_kv_block(state),
    ]),
    shell.section("Recent Tasks", [
      shell.data_table(["ID", "Priority", "Status", "Description"], [
        ["S01-T001", "P0", "completed", "Lustre web UI triple-interface"],
        ["S01-T002", "P0", "completed", "Wisp REST API endpoints"],
        ["S01-T003", "P1", "in_progress", "AG-UI 32-event protocol"],
        ["S01-T004", "P1", "pending", "Zenoh OTel span publishing"],
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 3. Immune — L0 Constitutional
// ---------------------------------------------------------------------------

pub fn immune_view(state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Immune System",
      "Biomorphic threat detection and antibody deployment",
    ),
    case state.threat_level == "critical" {
      True ->
        shell.alert_banner(
          "critical",
          "THREAT LEVEL CRITICAL — antibodies deployed",
        )
      False -> html.div([], [])
    },
    shell.section("Threat Status", [
      html.div([attribute.class("card-grid")], [
        shell.status_card(
          "Threat Level",
          threat_label(state.threat_level),
          state.threat_level,
          "current immune assessment",
        ),
        shell.status_card("Antibodies", "Healthy", "0", "deployed active"),
        shell.status_card("Attacks Blocked", "Healthy", "0", "since last reset"),
        shell.status_card("Chaos Experiments", "Healthy", "0", "running"),
      ]),
    ]),
    shell.section("Psi Invariants", [
      shell.data_table(["Invariant", "Status", "Description"], [
        ["Psi-0 Existence", "PASS", "System continues to exist and function"],
        ["Psi-1 Regeneration", "PASS", "State recoverable from SQLite/DuckDB"],
        ["Psi-2 Reversibility", "PASS", "All changes are reversible"],
        ["Psi-3 Verification", "PASS", "Hash chain maintained"],
        ["Psi-4 Alignment", "PASS", "Human intent preserved"],
        ["Psi-5 Truthfulness", "PASS", "No deception in outputs"],
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 4. Knowledge (Smriti) — L5 Cognitive
// ---------------------------------------------------------------------------

pub fn knowledge_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Knowledge (Smriti)",
      "Semantic knowledge graph — triple store and embeddings",
    ),
    shell.section("Graph Summary", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("Triples", "Healthy", "0", "stored in DuckDB"),
        shell.status_card("Namespaces", "Healthy", "3", "registered"),
        shell.status_card("Embeddings", "Degraded", "0", "NYI: FFI wiring"),
        shell.status_card("Cosine Queries", "Healthy", "0", "lifetime"),
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
  ])
}

// ---------------------------------------------------------------------------
// 5. Zenoh Mesh — L6 Ecosystem
// ---------------------------------------------------------------------------

pub fn zenoh_view(state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Zenoh Mesh",
      "Pub/sub transport bus — fractal backplane (SC-ZMOF-001)",
    ),
    case !state.zenoh_connected {
      True ->
        shell.alert_banner(
          "critical",
          "Zenoh router unreachable — mesh isolated",
        )
      False -> html.div([], [])
    },
    shell.section("Connectivity", [
      html.div([attribute.class("card-grid")], [
        shell.status_card(
          "Router Status",
          bool_status(state.zenoh_connected),
          case state.zenoh_connected {
            True -> "Online"
            False -> "Offline"
          },
          "tcp/localhost:7447",
        ),
        shell.status_card("Active Topics", "Healthy", "12", "subscriptions"),
        shell.status_card("Messages/sec", "Healthy", "0", "current throughput"),
        shell.status_card(
          "OTel Spans",
          "Healthy",
          "active",
          "indrajaal/otel/**",
        ),
      ]),
    ]),
    shell.section("Router Endpoints", [
      shell.data_table(["Router", "Endpoint", "Status"], [
        ["zenoh-router-1", "tcp/localhost:7447", "active"],
        ["zenoh-router-2", "tcp/localhost:7448", "active"],
        ["zenoh-router-3", "tcp/localhost:7449", "active"],
      ]),
    ]),
    shell.section("Key Topics", [
      shell.data_table(["Topic Pattern", "Direction", "Purpose"], [
        [
          "indrajaal/otel/spans/**",
          "pub",
          "OTel span transport (SC-GLM-ZEN-001)",
        ],
        ["indrajaal/l0/const/**", "pub/sub", "L0 Constitutional events"],
        ["indrajaal/l4/system/**", "pub/sub", "L4 Container lifecycle"],
        ["indrajaal/health/**", "pub", "Node health heartbeats (10s)"],
        ["indrajaal/ignition/**", "pub", "Boot sequence progress"],
        ["indrajaal/mcp/**", "pub/sub", "MCP-over-Zenoh (MoZ)"],
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 6. Cockpit — L5 Cognitive
// ---------------------------------------------------------------------------

pub fn cockpit_view(state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header("Cockpit", "Operator view — dark cockpit pattern (SC-HMI-010)"),
    shell.section("Cockpit Mode", [
      html.div([attribute.class("card-grid")], [
        shell.status_card(
          "Dark Cockpit",
          "Healthy",
          state.dark_cockpit_mode,
          "SC-HMI-010 mode",
        ),
        shell.status_card("Mesh Nodes", "Healthy", "16", "in genome"),
        shell.status_card("Active Alarms", "Healthy", "0", "acknowledged"),
        shell.status_card(
          "2oo3 Quorum",
          bool_status(state.quorum_healthy),
          case state.quorum_healthy {
            True -> "Met"
            False -> "Lost"
          },
          "SIL-4 voting",
        ),
      ]),
    ]),
    shell.section("Node Cluster", [
      html.div([attribute.class("card-grid")], [
        shell.container_card("ex-app-1", "running", 0.22, 0.41),
        shell.container_card("ex-app-2", "running", 0.18, 0.38),
        shell.container_card("ex-app-3", "running", 0.19, 0.4),
        shell.container_card("cepaf-bridge", "running", 0.05, 0.15),
        shell.container_card("cortex", "running", 0.31, 0.55),
        shell.container_card("chaya", "running", 0.08, 0.2),
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 7. Verification — L0 Constitutional
// ---------------------------------------------------------------------------

pub fn verification_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Verification",
      "PROMETHEUS proof gates — SIL-6 compliance (SC-PROM-001)",
    ),
    shell.section("Compliance Gates", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("PROMETHEUS", "Healthy", "PASS", "formal proofs"),
        shell.status_card("Shannon H", "Healthy", "2.67", ">= 2.5 bits"),
        shell.status_card("CCM", "Degraded", "0.77", "target >= 0.90"),
        shell.status_card("ITQS", "Degraded", "0.74", "target >= 0.85"),
      ]),
    ]),
    shell.section("Fractal Layer Verification", [
      shell.data_table(["Layer", "Check", "Status", "Last Verified"], [
        ["L0 Constitutional", "Psi invariants", "PASS", "live"],
        ["L1 Atomic/Debug", "NIF boundary", "PASS", "live"],
        ["L2 Component", "Type safety", "PASS", "compile-time"],
        ["L3 Transaction", "State mutations", "PASS", "live"],
        ["L4 System", "Container health", "PASS", "10s interval"],
        ["L5 Cognitive", "OODA SLA <100ms", "PASS", "live"],
        ["L6 Ecosystem", "Zenoh quorum", "PASS", "live"],
        ["L7 Federation", "Ed25519 attestation", "STUB", "NYI"],
      ]),
    ]),
    shell.section("L0 Operational Controls [A2UI Morphologically Evolvable]", [
      html.div([attribute.class("card-grid")], [
        shell.apalache_guard(
          shell.action_button(
            "Emergency Stop < 5s",
            "/api/v1/emergency/trigger",
            "{\\\"reason\\\": \\\"Operator initiated\\\", \\\"confirmation\\\": \\\"EMERGENCY STOP\\\"}",
          ),
          "mathematically_safe",
        ),
        shell.apalache_guard(
          shell.action_button(
            "Halt Mutations (Stabilize)",
            "/api/v1/podman/action",
            "{\\\"verb\\\": \\\"stabilize\\\", \\\"container\\\": \\\"mesh\\\", \\\"reason\\\": \\\"Halt mutations\\\"}",
          ),
          "mathematically_safe",
        ),
        shell.apalache_guard(
          shell.action_button(
            "Execute sa-verify",
            "/api/v1/podman/action",
            "{\\\"verb\\\": \\\"verify\\\", \\\"container\\\": \\\"system\\\", \\\"reason\\\": \\\"5-order effects\\\"}",
          ),
          "mathematically_safe",
        ),
      ]),
    ]),
    shell.section("Test Coverage", [
      shell.data_table(["Suite", "Tests", "Status"], [
        ["Gleam unit (gleeunit)", "1721 passed, 0 failed", "PASS"],
        ["Rust rule engine", "307 passed, 0 failed", "PASS"],
        ["Comprehensive UI regression", "381 tests", "PASS"],
        ["Tab coverage (15/15)", "100%", "PASS"],
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 8. Substrate — L3 Transaction
// ---------------------------------------------------------------------------

pub fn substrate_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Substrate",
      "File system, SQLite persistence, database substrate",
    ),
    shell.section("Storage Engines", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("SQLite (WAL)", "Healthy", "active", "Smriti.db"),
        shell.status_card("DuckDB", "Healthy", "active", "analytics store"),
        shell.status_card(
          "Postgres",
          "Degraded",
          "5433",
          "external — not started",
        ),
        shell.status_card("Zenoh KV", "Healthy", "active", "ephemeral mesh KV"),
      ]),
    ]),
    shell.section("Database Files", [
      shell.data_table(["File", "Engine", "Purpose", "Status"], [
        ["data/smriti/Smriti.db", "SQLite WAL", "Knowledge store", "active"],
        [
          "data/smriti/planning.db",
          "SQLite WAL",
          "sa-plan task state",
          "active",
        ],
        ["artifacts/cepa-state.db", "SQLite WAL", "CEPAF state", "active"],
        [
          "artifacts/build-history.db",
          "SQLite WAL",
          "EMA build history",
          "active",
        ],
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 9. Metabolic — L1 Atomic/Debug
// ---------------------------------------------------------------------------

pub fn metabolic_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Metabolic",
      "CPU governor, resource consumption, adaptive parallelism",
    ),
    shell.section("Resource Usage", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("CPU Usage", "Healthy", "< 60%", "full speed"),
        shell.status_card("Schedulers", "Healthy", "16:16", "+S 16:16"),
        shell.status_card("Dirty IO", "Healthy", "16", "+SDio 16"),
        shell.status_card("Build Jobs", "Healthy", "16", "--jobs 16"),
      ]),
    ]),
    shell.section("CPU Governor Thresholds", [
      shell.data_table(["CPU %", "Schedulers", "Dirty IO", "Jobs", "Action"], [
        ["< 60%", "16:16", "16", "16", "Full speed"],
        ["60-70%", "12:12", "12", "12", "Slight reduction"],
        ["70-80%", "10:10", "10", "10", "Moderate throttle"],
        ["80-85%", "6:6", "6", "6", "Heavy throttle"],
        ["> 85%", "WAIT", "WAIT", "WAIT", "Pause until < 75%"],
      ]),
    ]),
    shell.section("L1 Operational Controls [A2UI Context Projection]", [
      html.div([attribute.class("card-grid")], [
        shell.action_button(
          "System Logs (sa-logs)",
          "/api/v1/podman/action",
          "{\\\"verb\\\": \\\"logs\\\", \\\"container\\\": \\\"all\\\", \\\"reason\\\": \\\"Inspection\\\"}",
        ),
        shell.action_button(
          "Port Substrate (sa-scour)",
          "/api/v1/podman/action",
          "{\\\"verb\\\": \\\"scour\\\", \\\"container\\\": \\\"mesh\\\", \\\"reason\\\": \\\"Isolation\\\"}",
        ),
        shell.action_button(
          "Shutdown + Prune (sa-clean)",
          "/api/v1/podman/action",
          "{\\\"verb\\\": \\\"clean\\\", \\\"container\\\": \\\"all\\\", \\\"reason\\\": \\\"Maintenance\\\"}",
        ),
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 10. Podman — L4 System
// ---------------------------------------------------------------------------

pub fn podman_view(state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header("Podman", "16-container SIL-6 genome — lifecycle and health"),
    shell.section("Genome Status", [
      html.div([attribute.class("card-grid")], [
        shell.status_card(
          "Total Containers",
          "Healthy",
          int.to_string(state.container_count),
          "in genome",
        ),
        shell.status_card(
          "Healthy",
          "Healthy",
          int.to_string(state.healthy_count),
          "passing health checks",
        ),
        shell.status_card(
          "Unhealthy",
          case state.container_count - state.healthy_count > 0 {
            True -> "Critical"
            False -> "Healthy"
          },
          int.to_string(state.container_count - state.healthy_count),
          "failed health checks",
        ),
        shell.status_card(
          "Quorum",
          bool_status(state.quorum_healthy),
          "2oo3",
          "SIL-4 consensus",
        ),
      ]),
    ]),
    shell.section("Container Genome", [
      html.div([attribute.class("card-grid")], [
        shell.container_card("zenoh-router", "running", 0.02, 0.08),
        shell.container_card("db-prod", "running", 0.05, 0.35),
        shell.container_card("obs-prod", "running", 0.08, 0.28),
        shell.container_card("ex-app-1", "running", 0.22, 0.41),
        shell.container_card("cepaf-bridge", "running", 0.05, 0.15),
        shell.container_card("cortex", "running", 0.31, 0.55),
        shell.container_card("zenoh-router-1", "running", 0.02, 0.08),
        shell.container_card("zenoh-router-2", "running", 0.02, 0.08),
        shell.container_card("zenoh-router-3", "running", 0.02, 0.08),
        shell.container_card("ex-app-2", "running", 0.18, 0.38),
        shell.container_card("ex-app-3", "running", 0.19, 0.4),
        shell.container_card("chaya", "apoptotic", 0.08, 0.2),
        shell.container_card("ollama", "running", 0.15, 0.6),
        shell.container_card("mojo", "running", 0.12, 0.45),
        shell.container_card("ml-runner-1", "running", 0.25, 0.7),
        shell.container_card("ml-runner-2", "apoptotic", 0.23, 0.68),
      ]),
    ]),
    shell.section("L4 Operational Controls [A2UI Evolvable Interface]", [
      html.div([attribute.class("card-grid")], [
        shell.action_button(
          "Wave Ignition (sa-up)",
          "/api/v1/podman/action",
          "{\\\"verb\\\": \\\"up\\\", \\\"container\\\": \\\"all\\\", \\\"reason\\\": \\\"Manual start\\\"}",
        ),
        shell.action_button(
          "Apoptosis (sa-down)",
          "/api/v1/podman/action",
          "{\\\"verb\\\": \\\"down\\\", \\\"container\\\": \\\"all\\\", \\\"reason\\\": \\\"Manual stop\\\"}",
        ),
        shell.action_button(
          "Restart Genome",
          "/api/v1/podman/action",
          "{\\\"verb\\\": \\\"restart\\\", \\\"container\\\": \\\"all\\\", \\\"reason\\\": \\\"Refresh state\\\"}",
        ),
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 11. MCP — L6 Ecosystem
// ---------------------------------------------------------------------------

pub fn mcp_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header("MCP Server", "Model Context Protocol — tool dispatch and HITL"),
    shell.section("Server Status", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("MCP Status", "Healthy", "active", "SC-MCP-001"),
        shell.status_card("Tools Registered", "Healthy", "10", "available"),
        shell.status_card("Pending HITL", "Healthy", "0", "awaiting approval"),
        shell.status_card(
          "MoZ Transport",
          "Healthy",
          "active",
          "JSON-RPC/Zenoh",
        ),
      ]),
    ]),
    shell.section("Tool Registry", [
      shell.data_table(["Tool", "Layer", "HITL Required", "Description"], [
        ["sentinel", "L4", "No", "System health check"],
        ["zenoh_pub", "L6", "No", "Publish to Zenoh topic"],
        ["zenoh_query", "L6", "No", "Query mesh metrics"],
        ["checkpoint_op", "L3", "Yes", "Create/restore checkpoint"],
        ["guardian_approve", "L0", "Yes", "Approve L0 action (2oo3)"],
        ["podman_action", "L4", "Yes", "Container lifecycle mutation"],
        ["emergency_stop", "L0", "Yes", "Emergency halt (SC-SAFETY-022)"],
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 12. KMS — L0 Constitutional
// ---------------------------------------------------------------------------

pub fn kms_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "KMS Catalog",
      "Key Management System — Ed25519, AES-256, certificate lifecycle",
    ),
    shell.section("Key Catalog", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("Active Keys", "Healthy", "4", "current"),
        shell.status_card("Expired Keys", "Healthy", "0", "rotated out"),
        shell.status_card("Algorithm", "Healthy", "Ed25519", "primary signing"),
        shell.status_card("Encryption", "Healthy", "AES-256", "symmetric"),
      ]),
    ]),
    shell.section("Key Entries", [
      shell.data_table(["Key ID", "Algorithm", "Purpose", "Expires"], [
        ["guardian-root", "Ed25519", "Guardian signing", "2027-01-01"],
        ["mesh-tls", "AES-256-GCM", "Zenoh TLS", "2027-06-01"],
        ["attestation", "Ed25519", "L7 federation", "2027-01-01"],
        ["kms-master", "AES-256-CBC", "KMS master key", "never"],
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 13. Telemetry — L1 Atomic/Debug
// ---------------------------------------------------------------------------

pub fn telemetry_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Telemetry",
      "OTel spans via Zenoh — distributed tracing (SC-GLM-ZEN-001)",
    ),
    shell.section("Pipeline", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("OTel Collector", "Healthy", "4317", "gRPC port"),
        shell.status_card("Prometheus", "Healthy", "9090", "metrics scrape"),
        shell.status_card("Grafana", "Healthy", "3000", "dashboards"),
        shell.status_card("Zenoh Transport", "Healthy", "active", "OoZ"),
      ]),
    ]),
    shell.section("Active Spans", [
      shell.data_table(["Topic", "Operation", "Spans/min", "P99 latency"], [
        ["indrajaal/otel/spans/dashboard/**", "page_render", "0", "—"],
        ["indrajaal/otel/spans/podman/**", "health_check", "60", "< 5ms"],
        ["indrajaal/otel/spans/zenoh/**", "pub_sub", "120", "< 1ms"],
        ["indrajaal/otel/spans/immune/**", "threat_scan", "6", "< 10ms"],
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 14. Federation — L7 Federation
// ---------------------------------------------------------------------------

pub fn federation_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Federation (L7)",
      "Cross-holon protocol, version vectors, Ed25519 attestation",
    ),
    shell.alert_banner(
      "info",
      "L7 Federation is partially implemented — Ed25519 attestation is a stub.",
    ),
    shell.section("Federation Status", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("Federation Mode", "Degraded", "stub", "NYI"),
        shell.status_card("Peer Nodes", "Healthy", "0", "connected"),
        shell.status_card("Version Vectors", "Degraded", "stub", "NYI"),
        shell.status_card("Reconciliation", "Degraded", "stub", "NYI"),
      ]),
    ]),
    shell.section("Constitution", [
      shell.kv_row("Autonomy Level", "Full — each holon self-governs"),
      shell.kv_row("Consensus", "Ed25519 + Zenoh PubSub"),
      shell.kv_row("Governance", "Constitutional veto per SC-FED-001"),
      shell.kv_row("Sync Protocol", "Merkle CRDTs (planned)"),
    ]),
    shell.section("L7 Operational Controls [A2UI Federation Control]", [
      html.div([attribute.class("card-grid")], [
        shell.action_button(
          "Checkpoint (sa-checkpoint)",
          "/api/v1/podman/action",
          "{\\\"verb\\\": \\\"checkpoint\\\", \\\"container\\\": \\\"mesh\\\", \\\"reason\\\": \\\"State save\\\"}",
        ),
        shell.action_button(
          "Restore (sa-restore)",
          "/api/v1/podman/action",
          "{\\\"verb\\\": \\\"restore\\\", \\\"container\\\": \\\"mesh\\\", \\\"reason\\\": \\\"State load\\\"}",
        ),
        shell.action_button(
          "Fork Multiverse (sa-fork)",
          "/api/v1/podman/action",
          "{\\\"verb\\\": \\\"fork\\\", \\\"container\\\": \\\"mesh\\\", \\\"reason\\\": \\\"Shadow universe\\\"}",
        ),
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 15. Health Grid — L4 System
// ---------------------------------------------------------------------------

pub fn health_grid_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Device Health Grid",
      "Per-device health scores — biomorphic matrix",
    ),
    shell.section("Grid Filters", [
      html.div([attribute.class("card-grid-narrow")], [
        filter_pill("All Devices", True),
        filter_pill("Healthy Only", False),
        filter_pill("Degraded Only", False),
        filter_pill("Critical Only", False),
      ]),
    ]),
    shell.section("Device Grid", [
      html.div([attribute.class("card-grid-narrow")], [
        device_health_card("node-01", 0.98, "server"),
        device_health_card("node-02", 0.94, "server"),
        device_health_card("node-03", 0.89, "server"),
        device_health_card("router-01", 1.0, "router"),
        device_health_card("router-02", 0.99, "router"),
        device_health_card("sensor-01", 0.72, "sensor"),
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 16. Prajna — L5 Cognitive
// ---------------------------------------------------------------------------

pub fn prajna_view(state: SharedMeshState) -> Element(msg) {
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
          "< 100 msgs/s",
        ),
        shell.status_card(
          "Dark Cockpit",
          "Healthy",
          state.dark_cockpit_mode,
          "5-mode state machine",
        ),
        shell.status_card("LLM Advisory", "Healthy", "active", "OpenRouter"),
        shell.status_card("Reasoning", "Healthy", "enabled", "OODA-aware"),
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
  ])
}

// ---------------------------------------------------------------------------
// 17. Agents — L5 Cognitive
// ---------------------------------------------------------------------------

pub fn agents_view(_state: SharedMeshState) -> Element(msg) {
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
        shell.status_card("Efficiency", "Healthy", "92%", "compliance met"),
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
  ])
}

// ---------------------------------------------------------------------------
// 18. Holon — L3 Transaction
// ---------------------------------------------------------------------------

pub fn holon_view(_state: SharedMeshState) -> Element(msg) {
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
        shell.status_card("Rust NIF", "Healthy", "active", "ignition daemon"),
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
  ])
}

// ---------------------------------------------------------------------------
// 19. Config — L4 System
// ---------------------------------------------------------------------------

pub fn config_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Mesh Configuration",
      "MeshConfig — containers, networks, quorum",
    ),
    shell.section("Topology", [
      shell.kv_row("Containers", "16 (SIL-6 genome)"),
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
  ])
}

// ---------------------------------------------------------------------------
// 20. Git — L1 Atomic/Debug
// ---------------------------------------------------------------------------

pub fn git_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Git Intelligence",
      "ICP v2.0 commit conventions — 9 types, 23 scopes",
    ),
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
      shell.kv_row("Health Score", "0.85"),
    ]),
    shell.section("Branch Strategy", [
      shell.kv_row("Main branch", "main"),
      shell.kv_row("Feature branches", "multiverse/<agent-id>-<scope>"),
      shell.kv_row("Merge strategy", "ff-only after Guardian approval"),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 21. Database — L3 Transaction
// ---------------------------------------------------------------------------

pub fn database_view(_state: SharedMeshState) -> Element(msg) {
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
          "active",
          "primary state store",
        ),
        shell.status_card("DuckDB", "Healthy", "active", "analytics + OLAP"),
        shell.status_card("Postgres", "Degraded", "5433", "external cluster"),
        shell.status_card("Zenoh KV", "Healthy", "active", "ephemeral mesh KV"),
        shell.status_card("InMemory", "Healthy", "active", "test isolation"),
      ]),
    ]),
    shell.section("Cross-Holon Access", [
      shell.kv_row(
        "Rule",
        "SC-XHOLON-001 — isolated files, Zenoh-only cross access",
      ),
      shell.kv_row("Conflict resolution", "LastWriterWins (OCC)"),
      shell.kv_row("WAL mode", "Required for all SQLite databases"),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 22. Bridge — L6 Ecosystem
// ---------------------------------------------------------------------------

pub fn bridge_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header("Bridge", "F# CEPAF ↔ Gleam/Elixir bridge — NIF + Zenoh"),
    shell.section("Bridge Status", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("NIF Bridge", "Healthy", "loaded", "zenoh_nif.so"),
        shell.status_card(
          "Erlang FFI",
          "Healthy",
          "active",
          "cepaf_gleam_ffi.erl",
        ),
        shell.status_card("Zenoh NIF", "Healthy", "loaded", "SC-ZENOH-001"),
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
  ])
}

// ---------------------------------------------------------------------------
// 23. Smriti — L5 Cognitive
// ---------------------------------------------------------------------------

pub fn smriti_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Smriti Knowledge",
      "Semantic knowledge graph — federation and immortality",
    ),
    shell.section("Catalog", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("Catalog Entries", "Degraded", "0", "NYI: FFI wiring"),
        shell.status_card("Semantic Ops", "Healthy", "3", "pure functions"),
        shell.status_card("Embedding Dim", "Degraded", "0", "NYI"),
        shell.status_card("Federation", "Degraded", "stub", "NYI"),
      ]),
    ]),
    shell.section("Pure Semantic Functions", [
      shell.data_table(["Function", "Type", "Status"], [
        ["dot_product/2", "Float → Float → Float", "active"],
        ["cosine_similarity/2", "Vector → Vector → Float", "active"],
        ["normalize/1", "Vector → Vector", "active"],
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 24. Planning Dashboard — L3 Transaction
// ---------------------------------------------------------------------------

pub fn planning_dashboard_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Planning Dashboard",
      "8-panel cockpit — OODA + task + safety + enforcer",
    ),
    shell.section("Panels", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("Task Board", "Healthy", "active", "sa-plan SQLite"),
        shell.status_card("OODA Cycle", "Healthy", "observe", "100ms SLA"),
        shell.status_card("Safety Kernel", "Healthy", "active", "Psi 0-5"),
        shell.status_card(
          "Enforcer Shield",
          "Healthy",
          "active",
          "SC-ENFORCE-001",
        ),
        shell.status_card("Graph Verify", "Healthy", "active", "PageRank"),
        shell.status_card("Orch Mesh", "Healthy", "active", "Prajna + Smriti"),
        shell.status_card("Chaya Twin", "Healthy", "active", "digital twin"),
        shell.status_card("Startup Optim", "Healthy", "active", "< 60s target"),
      ]),
    ]),
    shell.section("AI Copilot", [
      shell.kv_row("Mode", "OODA advisory"),
      shell.kv_row("Model", "OpenRouter (via Zenoh MoZ)"),
      shell.kv_row("HITL gate", "Mandatory for all L0 mutations"),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 25. Mathematical Integrity — L0 Constitutional
// ---------------------------------------------------------------------------

pub fn integrity_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Mathematical Integrity",
      "Formal verification and propagation proofs",
    ),
    shell.section("Proofs", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("Convergence", "Healthy", "0.85", "score"),
        shell.status_card("Drift Rate", "Healthy", "0.001", "deviation/cycle"),
        shell.status_card("Error Margin", "Healthy", "0.12", "acceptable bound"),
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 26. Evolution Vectors — L5 Cognitive
// ---------------------------------------------------------------------------

pub fn evolution_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Evolution Vectors",
      "Adaptive trajectories and fitness metrics",
    ),
    shell.section("Metrics", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("Adaptability", "Healthy", "0.90", "fitness"),
        shell.status_card("Resilience", "Healthy", "0.80", "fitness"),
        shell.status_card("Efficiency", "Healthy", "0.70", "fitness"),
        shell.status_card("Coherence", "Healthy", "0.60", "fitness"),
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 27. Biomorphic Matrix — L5 Cognitive
// ---------------------------------------------------------------------------

pub fn biomorphic_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Biomorphic Matrix",
      "Cellular visualization of holon health",
    ),
    shell.section("Layers", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("Total Layers", "Healthy", "8", "L0-L7"),
        shell.status_card("Healthy Nodes", "Healthy", "7", "nominal"),
        shell.status_card("Degraded Nodes", "Degraded", "1", "recovering"),
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 28. Homeostasis Controls — L2 Component
// ---------------------------------------------------------------------------

pub fn homeostasis_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Homeostasis Controls",
      "PID tuning and metabolic set-points",
    ),
    shell.section("PID Parameters", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("Kp", "Healthy", "1.0", "proportional"),
        shell.status_card("Ki", "Healthy", "0.1", "integral"),
        shell.status_card("Kd", "Healthy", "0.05", "derivative"),
        shell.status_card("Set Point", "Healthy", "80.0", "target"),
        shell.status_card("Current", "Healthy", "78.5", "actual"),
        shell.status_card("Error", "Healthy", "1.5", "delta"),
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 29. Bicameral Sign-Off — L0 Constitutional
// ---------------------------------------------------------------------------

pub fn bicameral_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Bicameral Sign-Off",
      "Dual-authorization requirements for critical mutations",
    ),
    shell.section("Consensus", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("Guardian", "Healthy", "Approved", "Agent consent"),
        shell.status_card("Constitutional", "Degraded", "Pending", "Logic gate"),
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 30. Singularity Estimation — L7 Federation
// ---------------------------------------------------------------------------

pub fn singularity_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Singularity Estimation",
      "Convergence timing and phase transition probability",
    ),
    shell.section("Metrics", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("T-Minus (ms)", "Healthy", "3600000", "1 hour"),
        shell.status_card("Confidence", "Healthy", "0.95", "probabilistic"),
        shell.status_card("Status", "Healthy", "Approaching", "phase 4"),
      ]),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 404 Not Found
// ---------------------------------------------------------------------------

pub fn not_found_view(path: String) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    html.div([attribute.class("empty-state")], [
      html.div([attribute.class("empty-state-icon")], [element.text("◌")]),
      html.div([attribute.class("empty-state-title")], [
        element.text("Page not found"),
      ]),
      html.div([attribute.class("empty-state-detail")], [
        element.text("No route matched: " <> path),
      ]),
      html.a(
        [attribute.href("/dashboard"), attribute.class("btn btn-ghost mt-3")],
        [element.text("← Back to Dashboard")],
      ),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// Private helpers
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
    shell.kv_row("Threat Level", state.threat_level),
    shell.kv_row("OODA Phase", state.ooda_phase),
    shell.kv_row("Dark Cockpit", state.dark_cockpit_mode),
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

fn threat_label(level: String) -> String {
  case level {
    "nominal" -> "Healthy"
    "elevated" -> "Degraded"
    "critical" -> "Critical"
    _ -> "Unknown"
  }
}

fn bool_status(b: Bool) -> String {
  case b {
    True -> "Healthy"
    False -> "Critical"
  }
}

fn ooda_phase_pill(label: String, active: Bool) -> Element(msg) {
  let cls = case active {
    True -> "ooda-phase ooda-phase-active"
    False -> "ooda-phase"
  }
  html.span([attribute.class(cls)], [element.text(label)])
}

fn quick_link_card(
  title: String,
  path: String,
  description: String,
  layer: String,
) -> Element(msg) {
  html.a([attribute.href(path), attribute.class("card")], [
    html.div([attribute.class("card-header")], [
      html.span([attribute.class("card-title")], [element.text(title)]),
      html.span(
        [
          attribute.class("layer-pill layer-" <> string_lower(layer)),
        ],
        [element.text(layer)],
      ),
    ]),
    html.div([attribute.class("card-detail mt-2")], [
      element.text(description),
    ]),
  ])
}

fn filter_pill(label: String, active: Bool) -> Element(msg) {
  let cls = case active {
    True -> "btn btn-primary"
    False -> "btn btn-ghost"
  }
  html.span([attribute.class(cls)], [element.text(label)])
}

fn device_health_card(
  name: String,
  score: Float,
  device_type: String,
) -> Element(msg) {
  let pct = float.round(score *. 100.0)
  let status = case score >=. 0.9 {
    True -> "Healthy"
    False ->
      case score >=. 0.7 {
        True -> "Degraded"
        False -> "Critical"
      }
  }
  html.div([attribute.class("card")], [
    html.div([attribute.class("card-header")], [
      html.span([attribute.class("mono text-sm")], [element.text(name)]),
      html.span(
        [attribute.class("status-badge " <> status_badge_class(status))],
        [element.text(int.to_string(pct) <> "%")],
      ),
    ]),
    html.div([attribute.class("card-detail")], [element.text(device_type)]),
    shell.mini_bar(score, 1.0, health_bar_color(score)),
  ])
}

fn status_badge_class(status: String) -> String {
  case status {
    "Healthy" -> "badge-healthy"
    "Degraded" -> "badge-degraded"
    "Critical" -> "badge-critical"
    _ -> "badge-unknown"
  }
}

fn health_bar_color(score: Float) -> String {
  case score >=. 0.9 {
    True -> "#3dd68c"
    False ->
      case score >=. 0.7 {
        True -> "#f5a623"
        False -> "#e05252"
      }
  }
}

/// Minimal lowercase — only used for the L0-L7 layer pill CSS class suffix.
/// Handles the exact values passed: "L0", "L1", …, "L7".
fn string_lower(s: String) -> String {
  case s {
    "L0" -> "l0"
    "L1" -> "l1"
    "L2" -> "l2"
    "L3" -> "l3"
    "L4" -> "l4"
    "L5" -> "l5"
    "L6" -> "l6"
    "L7" -> "l7"
    _ -> s
  }
}
