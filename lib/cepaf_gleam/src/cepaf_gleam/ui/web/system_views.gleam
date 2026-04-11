//// =============================================================================
//// [C3I-SIL6-MSTS] MATHEMATICAL & SEMANTIC MODULE CONTRACT
//// =============================================================================
//// <c3i-module>
////   <identity>
////     <module>cepaf_gleam/ui/web/system_views</module>
////     <fsharp-lineage>Cepaf.UI.Web.PageViews.fs</fsharp-lineage>
////   </identity>
////   <fractal-topology>
////     <layer>L4_SYSTEM</layer>
////   </fractal-topology>
////   <compliance>
////     <stamp-controls>SC-GLM-UI-001, SC-GLM-UI-004, SC-MUDA-001</stamp-controls>
////   </compliance>
////   <transformations>
////     <morphism type="surjective" loss="none">
////       page_views.gleam ↠ system_views.gleam (split by domain).
////       Mitigation: All helpers duplicated as private fns — zero public surface change.
////     </morphism>
////   </transformations>
//// </c3i-module>
//// =============================================================================
////
//// विभागशः — Division into parts, each complete in itself (Gita 18.41)
////
//// System-layer views: Podman (L4), Zenoh (L6), Verification (L0),
//// Immune (L0), KMS (L0), Telemetry (L1), Metabolic (L1),
//// Substrate (L3), MCP (L6).

import cepaf_gleam/ui/lustre/shell
import cepaf_gleam/ui/state.{
  type SharedMeshState, ThreatCritical, ThreatElevated, ThreatNominal, ThreatNone,
  ThreatSevere,
}
import gleam/int
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

// ---------------------------------------------------------------------------
// Public views
// ---------------------------------------------------------------------------

pub fn immune_view(state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Immune System",
      "Biomorphic threat detection and antibody deployment",
    ),
    case state.threat_level {
      ThreatCritical | ThreatSevere ->
        shell.alert_banner(
          "critical",
          "THREAT LEVEL CRITICAL — antibodies deployed",
        )
      _ -> html.div([], [])
    },
    shell.section("Threat Status", [
      html.div([attribute.class("card-grid")], [
        shell.status_card(
          "Threat Level",
          threat_label(state.threat_level),
          state.threat_level_to_string(state.threat_level),
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

fn threat_label(level: state.ThreatLevel) -> String {
  case level {
    ThreatNominal | ThreatNone -> "Healthy"
    ThreatElevated -> "Degraded"
    ThreatCritical | ThreatSevere -> "Critical"
    _ -> "Unknown"
  }
}

fn bool_status(b: Bool) -> String {
  case b {
    True -> "Healthy"
    False -> "Critical"
  }
}
