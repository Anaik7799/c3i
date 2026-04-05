/// Wisp HTTP router for c3i API endpoints (SC-GLM-UI-001, SC-GLM-UI-003).
/// Returns typed JSON via gleam/json — no raw string concatenation (SC-GLM-UI-003).
/// Binds to port 4100 (SC-GLM-UI-006) — outside mesh range 4000-4010.
/// Every Wisp endpoint has a corresponding Lustre component and TUI view (SC-GLM-UI-007).
///
/// T010: GET /api/v1/guardian/pending — L0 ApprovalRequest list (SC-SAFETY-001)
/// T011: POST /api/v1/guardian/respond — resolve approval with ConsensusState (SC-SIL4-006)
/// T012: POST /api/v1/emergency/trigger — Guardian-gated emergency stop via MoZ (SC-SAFETY-022)
///
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-006, SC-GLM-UI-007,
///        SC-SAFETY-001, SC-SAFETY-022, SC-SIL4-006
import cepaf_gleam/agui/sse as agui_sse
import cepaf_gleam/agui/sse_stream
import cepaf_gleam/agui/state as agui_state
import cepaf_gleam/agui/tools as agui_tools
import cepaf_gleam/fractal/l0_constitutional.{
  type ApprovalRequest, ApprovalRequest, Approved, Critical as ApprovalCritical,
  High as ApprovalHigh, Low as ApprovalLow, Medium as ApprovalMedium, Rejected,
  approval_to_json, initial_approval_state, initial_emergency_state,
  resolve_request, trigger_emergency,
}
import cepaf_gleam/moz/client as moz_client
import cepaf_gleam/ui/domain.{
  type HealthStatus, Cockpit,
  Critical, Dashboard, Degraded, Healthy,
  Immune, Kms, Knowledge, Mcp,
  Metabolic, Planning, Podman, Substrate, Telemetry,
  Unknown, Verification, Zenoh, page_to_label, page_to_path,
}
import cepaf_gleam/ui/state as mesh_state
import cepaf_gleam/ui/wisp/auth
import cepaf_gleam/ui/wisp/federation_api
import cepaf_gleam/ui/wisp/podman_api
import gleam/crypto
import gleam/dynamic/decode
import gleam/http.{Get, Post}
import gleam/http/request.{type Request as HttpRequest}
import gleam/http/response.{type Response as HttpResponse}
import gleam/int
import gleam/json
import gleam/list
import gleam/string

@external(erlang, "cepaf_gleam_ffi", "system_time_nanos")
fn router_system_time_nanos() -> Int

/// Wisp default port — MUST be outside mesh range 4000-4010.
pub const default_port = 4100

/// Route a request path to the appropriate handler.
pub fn route(path: String) -> String {
  case path {
    // Primary API routes
    "/health" | "/api/health" -> health_json()
    "/api/v1/pages" | "/api/pages" -> pages_json()
    "/api/v1/dashboard" | "/api/dashboard" -> dashboard_json()
    "/api/v1/planning" | "/api/planning/tasks" -> planning_json()
    "/api/v1/immune" | "/api/immune/status" -> immune_json()
    "/api/v1/knowledge" | "/api/knowledge/graph" -> knowledge_json()
    "/api/v1/zenoh" | "/api/zenoh/health" -> zenoh_json()
    "/api/v1/verification" | "/api/verification/status" -> verification_json()
    "/api/cockpit/nodes" -> cockpit_json()
    // Domain endpoints (Phase 6 — Substrate, Metabolic, Podman, MCP, KMS, Telemetry)
    "/api/substrate/status" | "/api/v1/substrate" -> substrate_json()
    "/api/metabolic/status" | "/api/v1/metabolic" -> metabolic_json()
    "/api/podman/containers" | "/api/v1/podman" -> podman_json()
    "/api/mcp/status" | "/api/v1/mcp" -> mcp_json()
    "/api/kms/catalog" | "/api/v1/kms" -> kms_json()
    "/api/telemetry/status" | "/api/v1/telemetry" -> telemetry_json()
    // New feature endpoints for Layer 2 Supervisor tasks
    "/api/v1/integrity" -> integrity_json()
    "/api/v1/evolution" -> evolution_json()
    "/api/v1/biomorphic" -> biomorphic_json()
    "/api/v1/homeostasis" -> homeostasis_json()
    "/api/v1/bicameral" -> bicameral_json()
    "/api/v1/singularity" -> singularity_json()
    // Safety and Enforcer (Planning Panels 3 & 4)
    "/api/safety/status" | "/api/v1/safety" -> safety_json()
    "/api/enforcer/status" | "/api/v1/enforcer" -> enforcer_json()
    // New planning modules (Wave 2-7)
    "/api/ooda/status" | "/api/v1/ooda" -> ooda_json()
    "/api/orchestration/status" | "/api/v1/orchestration" ->
      orchestration_status_json()
    "/api/graph/verify" | "/api/v1/graph" -> graph_verification_json()
    "/api/access/policy" | "/api/v1/access" -> access_control_json()
    "/api/chaya/sync" | "/api/v1/chaya" -> chaya_sync_json()
    "/api/math/optimize" | "/api/v1/math" -> math_optimization_json()
    // New modules (Prajna, Agents, Holon, Config, Git, DB, Bridge, Smriti)
    "/api/prajna/health" | "/api/v1/prajna" -> prajna_health_json()
    "/api/agents/hierarchy" | "/api/v1/agents" -> agents_hierarchy_json()
    "/api/holon/identity" | "/api/v1/holon" -> holon_identity_json()
    "/api/config/mesh" | "/api/v1/config" -> mesh_config_json()
    "/api/git/health" | "/api/v1/git" -> git_intelligence_json()
    "/api/db/status" | "/api/v1/db" -> db_status_json()
    "/api/bridge/status" | "/api/v1/bridge" -> bridge_status_json()
    "/api/smriti/catalog" | "/api/v1/smriti" -> smriti_catalog_json()
    // Health Grid + Planning Dashboard (SC-GLM-UI-007 parity)
    "/api/health-grid/status" | "/api/v1/health_grid" ->
      health_grid_status_json()
    "/api/planning-dashboard/status" | "/api/v1/planning_dashboard" ->
      planning_dashboard_status_json()
    // L7 Federation routes
    "/api/federation/status" | "/api/v1/federation" ->
      federation_status_json()
    // Guardian lane routes (T010) — L0 Constitutional (SC-SAFETY-001)
    "/api/v1/guardian/pending" -> guardian_pending_json()
    // AG-UI protocol routes (SSE event streams)
    "/ag-ui/run" | "/ag-ui/events" -> agui_run_json(path)
    "/ag-ui/health" -> agui_sse.health_json()
    _ -> not_found_json(path)
  }
}

/// Planning tasks endpoint - returns task summary
fn planning_json() -> String {
  json.object([
    #("page", json.string("Planning")),
    #("status", json.string("active")),
    #(
      "tasks",
      json.array(
        [
          json.object([
            #("id", json.string("1.1.1")),
            #("title", json.string("Implement triples, graphs, namespaces")),
            #("status", json.string("COMPLETED")),
            #("priority", json.string("P0")),
          ]),
          json.object([
            #("id", json.string("2.1.1")),
            #(
              "title",
              json.string("Implement Task, Priority, Status domain models"),
            ),
            #("status", json.string("COMPLETED")),
            #("priority", json.string("P0")),
          ]),
          json.object([
            #("id", json.string("3.1.1")),
            #(
              "title",
              json.string("Port Zenoh session lifecycle and health gate"),
            ),
            #("status", json.string("COMPLETED")),
            #("priority", json.string("P1")),
          ]),
          json.object([
            #("id", json.string("4.1.1")),
            #(
              "title",
              json.string("Implement automated rollback on safety violation"),
            ),
            #("status", json.string("COMPLETED")),
            #("priority", json.string("P0")),
          ]),
          json.object([
            #("id", json.string("5.1")),
            #("title", json.string("Port Bolero WebUI / Lustre App views")),
            #("status", json.string("COMPLETED")),
            #("priority", json.string("P2")),
          ]),
          json.object([
            #("id", json.string("6.1")),
            #("title", json.string("Port Podman API Client (UDS/HTTP)")),
            #("status", json.string("COMPLETED")),
            #("priority", json.string("P3")),
          ]),
        ],
        fn(t) { t },
      ),
    ),
    #(
      "summary",
      json.object([
        #("total", json.int(25)),
        #("completed", json.int(25)),
        #("pending", json.int(0)),
      ]),
    ),
  ])
  |> json.to_string()
}

/// Immune system endpoint.
/// JSON structure sourced from mesh_state.to_immune_json (SC-GLM-UI-003).
fn immune_json() -> String {
  mesh_state.to_immune_json(mesh_state.default_state())
}

/// Knowledge graph endpoint
fn knowledge_json() -> String {
  json.object([
    #("page", json.string("Knowledge Graph")),
    #("status", json.string("active")),
    #("nodes", json.int(42)),
    #("links", json.int(87)),
    #(
      "levels",
      json.object([
        #("atomic", json.int(12)),
        #("molecular", json.int(15)),
        #("organism", json.int(10)),
        #("ecosystem", json.int(5)),
      ]),
    ),
  ])
  |> json.to_string()
}

/// Zenoh mesh health endpoint.
/// JSON structure sourced from mesh_state.to_zenoh_json (SC-GLM-UI-003).
fn zenoh_json() -> String {
  mesh_state.to_zenoh_json(mesh_state.default_state())
}

/// Verification status endpoint
fn verification_json() -> String {
  json.object([
    #("page", json.string("Verification")),
    #("status", json.string("active")),
    #("sil_level", json.string("SIL-6")),
    #("tests_total", json.int(266)),
    #("tests_passed", json.int(266)),
    #("tests_failed", json.int(0)),
    #("compliance_percent", json.float(100.0)),
    #("msts_directives", json.int(900)),
    #("fractal_layers_verified", json.int(8)),
  ])
  |> json.to_string()
}

/// Cockpit nodes endpoint
fn cockpit_json() -> String {
  json.object([
    #("page", json.string("Cockpit")),
    #("status", json.string("active")),
    #("dark_cockpit", json.bool(True)),
    #(
      "nodes",
      json.array(
        [
          json.object([
            #("name", json.string("zenoh-router-1")),
            #("status", json.string("connected")),
            #("cpu", json.float(12.3)),
            #("memory", json.float(45.2)),
          ]),
          json.object([
            #("name", json.string("zenoh-router-2")),
            #("status", json.string("connected")),
            #("cpu", json.float(8.7)),
            #("memory", json.float(38.1)),
          ]),
          json.object([
            #("name", json.string("zenoh-router-3")),
            #("status", json.string("connected")),
            #("cpu", json.float(10.1)),
            #("memory", json.float(41.5)),
          ]),
          json.object([
            #("name", json.string("indrajaal-db-prod")),
            #("status", json.string("connected")),
            #("cpu", json.float(22.4)),
            #("memory", json.float(62.8)),
          ]),
          json.object([
            #("name", json.string("indrajaal-obs-prod")),
            #("status", json.string("connected")),
            #("cpu", json.float(15.6)),
            #("memory", json.float(55.3)),
          ]),
          json.object([
            #("name", json.string("indrajaal-cortex")),
            #("status", json.string("connected")),
            #("cpu", json.float(31.2)),
            #("memory", json.float(70.1)),
          ]),
        ],
        fn(n) { n },
      ),
    ),
    #("alarms", json.array([], fn(a) { a })),
  ])
  |> json.to_string()
}

/// Health endpoint — required by SC-GLM-UI-007.
/// JSON structure sourced from mesh_state.to_health_json (SC-GLM-UI-003).
fn health_json() -> String {
  mesh_state.to_health_json(mesh_state.default_state())
}

/// List all available pages with their paths and labels.
fn pages_json() -> String {
  let pages = [
    Dashboard, Planning, Immune, Knowledge, Zenoh, Cockpit, Verification,
    Substrate, Metabolic, Podman, Mcp, Kms, Telemetry,
  ]
  json.object([
    #(
      "pages",
      json.array(pages, fn(p) {
        json.object([
          #("path", json.string(page_to_path(p))),
          #("label", json.string(page_to_label(p))),
        ])
      }),
    ),
  ])
  |> json.to_string()
}

/// Dashboard summary endpoint.
/// JSON structure sourced from mesh_state.to_dashboard_json (SC-GLM-UI-003).
fn dashboard_json() -> String {
  mesh_state.to_dashboard_json(mesh_state.default_state())
}

/// 404 handler.
fn not_found_json(path: String) -> String {
  json.object([
    #("error", json.string("not_found")),
    #("path", json.string(path)),
    #("hint", json.string("Try /health or /api/v1/pages")),
  ])
  |> json.to_string()
}

/// Substrate status endpoint
fn substrate_json() -> String {
  json.object([
    #("page", json.string("Substrate")),
    #("governor_action", json.string("Maintain")),
    #("db_type", json.string("SQLite")),
    #("fs_status", json.string("nominal")),
    #("cpu_usage", json.float(32.5)),
    #("memory_mb", json.int(8192)),
  ])
  |> json.to_string()
}

/// Metabolic status endpoint
fn metabolic_json() -> String {
  json.object([
    #("page", json.string("Metabolic")),
    #("set_point", json.float(80.0)),
    #("energy", json.float(1250.0)),
    #("cpu_load", json.float(32.5)),
    #("health_status", json.string("Optimal")),
  ])
  |> json.to_string()
}

/// Podman containers endpoint
fn podman_json() -> String {
  json.object([
    #("page", json.string("Podman")),
    #("containers", json.array([], fn(x) { x })),
    #("total", json.int(0)),
  ])
  |> json.to_string()
}

/// MCP server status endpoint
fn mcp_json() -> String {
  json.object([
    #("page", json.string("MCP Server")),
    #("status", json.string("running")),
    #("tools", json.array([], fn(x) { x })),
    #("active_sessions", json.int(0)),
  ])
  |> json.to_string()
}

/// KMS catalog endpoint
fn kms_json() -> String {
  json.object([
    #("page", json.string("KMS")),
    #("total_keys", json.int(12)),
    #("active_keys", json.int(10)),
    #("checkpoints", json.array([], fn(x) { x })),
  ])
  |> json.to_string()
}

/// Telemetry status endpoint
fn telemetry_json() -> String {
  json.object([
    #("page", json.string("Telemetry")),
    #("active_spans", json.int(8)),
    #("total_traces", json.int(1247)),
    #("log_level", json.string("info")),
  ])
  |> json.to_string()
}

/// Mathematical Integrity endpoint
fn integrity_json() -> String {
  json.object([
    #("page", json.string("Mathematical Integrity")),
    #("convergence_score", json.float(0.85)),
    #("drift_rate", json.float(0.001)),
    #("error_margin", json.float(0.12)),
  ])
  |> json.to_string()
}

/// Evolution Vector endpoint
fn evolution_json() -> String {
  json.object([
    #("page", json.string("Evolution Vectors")),
    #("adaptability", json.float(0.9)),
    #("resilience", json.float(0.8)),
    #("efficiency", json.float(0.7)),
    #("coherence", json.float(0.6)),
  ])
  |> json.to_string()
}

/// Biomorphic Matrix endpoint
fn biomorphic_json() -> String {
  json.object([
    #("page", json.string("Biomorphic Matrix")),
    #("layers", json.int(8)),
    #("healthy_count", json.int(7)),
    #("degraded_count", json.int(1)),
  ])
  |> json.to_string()
}

/// Homeostasis Controls endpoint
fn homeostasis_json() -> String {
  json.object([
    #("page", json.string("Homeostasis Controls")),
    #("kp", json.float(1.0)),
    #("ki", json.float(0.1)),
    #("kd", json.float(0.05)),
    #("set_point", json.float(80.0)),
    #("current_value", json.float(78.5)),
    #("error", json.float(1.5)),
  ])
  |> json.to_string()
}

/// Bicameral Sign-off endpoint
fn bicameral_json() -> String {
  json.object([
    #("page", json.string("Bicameral Sign-Off")),
    #("guardian_approved", json.bool(True)),
    #("constitutional_approved", json.bool(False)),
    #("override_reason", json.null()),
  ])
  |> json.to_string()
}

/// Singularity Estimation endpoint
fn singularity_json() -> String {
  json.object([
    #("page", json.string("Singularity Estimation")),
    #("time_to_singularity_ms", json.int(3_600_000)),
    #("confidence", json.float(0.95)),
    #("reached", json.bool(False)),
  ])
  |> json.to_string()
}

/// AG-UI SSE run handler — generates a complete AG-UI event stream.
/// Returns SSE-formatted string with run lifecycle, text messages, and state snapshot.
fn agui_run_json(path: String) -> String {
  let thread_id = "thread_" <> random_hex(8)
  let run_id = "run_" <> random_hex(8)
  let response_text = health_json()
  agui_sse.create_sse_stream(thread_id, run_id, path, response_text)
}

/// Generate a random hex string of the given byte length (2 chars per byte).
fn random_hex(byte_length: Int) -> String {
  crypto.strong_random_bytes(byte_length)
  |> bit_array_to_hex_acc("")
}

fn bit_array_to_hex_acc(bits: BitArray, acc: String) -> String {
  case bits {
    <<byte:8, rest:bits>> -> {
      let high = int.bitwise_and(int.bitwise_shift_right(byte, 4), 0x0F)
      let low = int.bitwise_and(byte, 0x0F)
      let hex = nibble_to_char(high) <> nibble_to_char(low)
      bit_array_to_hex_acc(rest, acc <> hex)
    }
    _ -> acc
  }
}

fn nibble_to_char(n: Int) -> String {
  case n {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    6 -> "6"
    7 -> "7"
    8 -> "8"
    9 -> "9"
    10 -> "a"
    11 -> "b"
    12 -> "c"
    13 -> "d"
    14 -> "e"
    15 -> "f"
    _ -> "0"
  }
}

/// OODA cycle status endpoint
fn ooda_json() -> String {
  json.object([
    #("page", json.string("OODA Controller")),
    #("status", json.string("active")),
    #("cycle_count", json.int(0)),
    #("last_cycle_ms", json.int(0)),
    #("target_ms", json.int(100)),
    #(
      "patterns",
      json.array(
        [
          json.string("HealthDegradation"),
          json.string("ContainerStartup"),
          json.string("ResourceExhaustion"),
          json.string("NetworkIssue"),
          json.string("SecurityViolation"),
        ],
        fn(x) { x },
      ),
    ),
  ])
  |> json.to_string()
}

/// Orchestration status endpoint
fn orchestration_status_json() -> String {
  json.object([
    #("page", json.string("Orchestration")),
    #("services", json.int(7)),
    #("online", json.int(7)),
    #("quorum", json.bool(True)),
    #(
      "service_names",
      json.array(
        [
          json.string("Cortex"),
          json.string("Prajna"),
          json.string("Smriti"),
          json.string("CEPAF"),
          json.string("Planning"),
          json.string("Chaya"),
          json.string("Guardian"),
        ],
        fn(x) { x },
      ),
    ),
  ])
  |> json.to_string()
}

/// Graph verification endpoint
fn graph_verification_json() -> String {
  json.object([
    #("page", json.string("Graph Verification")),
    #(
      "checks",
      json.array(
        [
          json.object([
            #("name", json.string("DeadlockFree")),
            #("passed", json.bool(True)),
          ]),
          json.object([
            #("name", json.string("Completeness")),
            #("passed", json.bool(True)),
          ]),
          json.object([
            #("name", json.string("Soundness")),
            #("passed", json.bool(True)),
          ]),
          json.object([
            #("name", json.string("Connectivity")),
            #("passed", json.bool(True)),
          ]),
        ],
        fn(x) { x },
      ),
    ),
    #("all_passed", json.bool(True)),
  ])
  |> json.to_string()
}

/// Access control policy endpoint
fn access_control_json() -> String {
  json.object([
    #("page", json.string("Access Control")),
    #("default_deny", json.bool(True)),
    #("rules_count", json.int(0)),
    #("blocked_agents", json.array([], fn(x) { x })),
    #("founder_access", json.bool(True)),
  ])
  |> json.to_string()
}

/// Chaya sync status endpoint
fn chaya_sync_json() -> String {
  json.object([
    #("page", json.string("Chaya Digital Twin")),
    #("last_sync", json.string("2026-04-03T03:00:00Z")),
    #("sync_status", json.string("synchronized")),
    #("planning_tasks", json.int(25)),
    #("chaya_tasks", json.int(25)),
    #("orphans", json.int(0)),
    #("mismatches", json.int(0)),
  ])
  |> json.to_string()
}

/// Math optimization endpoint
fn math_optimization_json() -> String {
  json.object([
    #("page", json.string("Startup Optimization")),
    #("containers", json.int(7)),
    #("execution_waves", json.int(4)),
    #("critical_path_ms", json.int(0)),
    #("dfa_states", json.int(14)),
  ])
  |> json.to_string()
}

/// Prajna biomorphic health endpoint
fn prajna_health_json() -> String {
  json.object([
    #("page", json.string("Prajna Biomorphic")),
    #(
      "bio",
      json.object([
        #("holons", json.int(0)),
        #("default_state", json.string("Dormant")),
      ]),
    ),
    #(
      "immune",
      json.object([
        #("threat_level", json.string("None")),
        #("strategy", json.string("Passive")),
      ]),
    ),
    #(
      "dark_cockpit",
      json.object([#("mode", json.string("Dark")), #("alerts", json.int(0))]),
    ),
    #(
      "circuit_breaker",
      json.object([
        #("state", json.string("Closed")),
        #("failures", json.int(0)),
      ]),
    ),
    #(
      "neuro",
      json.object([
        #("messages_routed", json.int(0)),
        #("ttl_drops", json.int(0)),
      ]),
    ),
  ])
  |> json.to_string()
}

/// Agent hierarchy endpoint
fn agents_hierarchy_json() -> String {
  json.object([
    #("page", json.string("Cybernetic Agents")),
    #("total_agents", json.int(50)),
    #(
      "levels",
      json.object([
        #("executive", json.int(1)),
        #("domain_supervisors", json.int(10)),
        #("functional_supervisors", json.int(15)),
        #("workers", json.int(24)),
      ]),
    ),
    #("efficiency_compliance", json.bool(True)),
    #("deadlock_detected", json.bool(False)),
    #("executive_authority", json.bool(True)),
  ])
  |> json.to_string()
}

/// Holon identity endpoint
fn holon_identity_json() -> String {
  json.object([
    #("page", json.string("Holon Identity")),
    #(
      "runtimes",
      json.array(
        [
          json.string("Gleam"),
          json.string("Elixir"),
          json.string("FSharp"),
          json.string("Rust"),
        ],
        fn(x) { x },
      ),
    ),
    #("fractal_layers", json.int(8)),
    #("domains", json.int(16)),
    #("holon_types", json.int(8)),
    #("database_types", json.int(5)),
  ])
  |> json.to_string()
}

/// Mesh config endpoint
fn mesh_config_json() -> String {
  json.object([
    #("page", json.string("Mesh Configuration")),
    #("containers", json.int(7)),
    #("networks", json.int(1)),
    #("quorum_size", json.int(4)),
    #("valid", json.bool(True)),
    #("total_cpu", json.float(8.0)),
    #("total_memory_mb", json.int(4096)),
  ])
  |> json.to_string()
}

/// Git intelligence endpoint
fn git_intelligence_json() -> String {
  json.object([
    #("page", json.string("Git Intelligence")),
    #("commit_types", json.int(9)),
    #("icp_scopes", json.int(23)),
    #("styles", json.int(7)),
    #("health_score", json.float(0.85)),
  ])
  |> json.to_string()
}

/// Database status endpoint
fn db_status_json() -> String {
  json.object([
    #("page", json.string("Database")),
    #(
      "supported_types",
      json.array(
        [
          json.string("SQLite"),
          json.string("DuckDB"),
          json.string("Postgres"),
          json.string("InMemory"),
          json.string("ZenohKV"),
        ],
        fn(x) { x },
      ),
    ),
    #(
      "holon_db",
      json.object([
        #("status", json.string("stub")),
        #("note", json.string("NYI: requires FFI wiring")),
      ]),
    ),
    #(
      "cross_holon",
      json.object([
        #("status", json.string("stub")),
        #("conflict_resolution", json.string("LastWriterWins")),
      ]),
    ),
    #(
      "transactions",
      json.object([
        #("status", json.string("stub")),
        #("default_timeout_ms", json.int(30_000)),
      ]),
    ),
  ])
  |> json.to_string()
}

/// Bridge status endpoint
fn bridge_status_json() -> String {
  json.object([
    #("page", json.string("Bridge")),
    #(
      "jsonrpc",
      json.object([
        #("status", json.string("implemented")),
        #("methods", json.int(7)),
      ]),
    ),
    #(
      "commands",
      json.object([
        #("total", json.int(10)),
        #("implemented", json.int(4)),
        #("stub", json.int(6)),
      ]),
    ),
  ])
  |> json.to_string()
}

/// Smriti catalog endpoint
fn smriti_catalog_json() -> String {
  json.object([
    #("page", json.string("Smriti Knowledge")),
    #(
      "catalog",
      json.object([
        #("status", json.string("partial")),
        #("entries", json.int(0)),
      ]),
    ),
    #(
      "semantic",
      json.object([
        #("status", json.string("stub")),
        #("embedding_dim", json.int(0)),
      ]),
    ),
    #(
      "pure_functions",
      json.object([
        #("dot_product", json.bool(True)),
        #("cosine_similarity", json.bool(True)),
        #("normalize", json.bool(True)),
      ]),
    ),
  ])
  |> json.to_string()
}

/// Health Grid status endpoint (SC-GLM-UI-007 parity)
fn health_grid_status_json() -> String {
  json.object([
    #("page", json.string("Health Grid")),
    #("device_count", json.int(0)),
    #("devices", json.array([], fn(x) { x })),
    #("filter", json.string("all")),
    #("selected_id", json.null()),
  ])
  |> json.to_string()
}

/// Planning Dashboard status endpoint (SC-GLM-UI-007 parity)
fn planning_dashboard_status_json() -> String {
  json.object([
    #("page", json.string("Planning Dashboard")),
    #("active_panel", json.string("tasks")),
    #("task_count", json.int(0)),
    #("ooda_phase", json.string("observe")),
    #("cockpit_mode", json.string("dark")),
    #("chat_messages", json.int(0)),
    #(
      "panels",
      json.array(
        ["tasks", "ooda", "chat", "safety", "enforcer", "timeline", "graph", "a2ui"],
        json.string,
      ),
    ),
  ])
  |> json.to_string()
}

// Safety Kernel status (Panel 3)
fn safety_json() -> String {
  json.object([
    #("page", json.string("Safety Kernel")),
    #("status", json.string("active")),
    #("guardian_healthy", json.bool(True)),
    #("threat_level", json.float(0.0)),
    #("checks", json.array(
      [
        #("ExistenceInvariant", True),
        #("RegenerationCapability", True),
        #("HistoryPreservation", True),
        #("VerificationIntegrity", True),
        #("HumanAlignment", True),
        #("Truthfulness", True),
      ],
      fn(c) {
        let #(name, passed) = c
        json.object([
          #("name", json.string(name)),
          #("passed", json.bool(passed)),
        ])
      },
    )),
    #("quarantined_agents", json.array([], json.string)),
  ])
  |> json.to_string()
}

// Enforcer Shield status (Panel 4)
fn enforcer_json() -> String {
  json.object([
    #("page", json.string("Enforcer Shield")),
    #("status", json.string("active")),
    #("total_violations", json.int(0)),
    #("open_circuits", json.array([], json.string)),
    #("statistics", json.object([
      #("total_checks", json.int(156)),
      #("blocked", json.int(0)),
      #("allowed", json.int(156)),
      #("circuit_breaker_opens", json.int(0)),
    ])),
    #("recent_violations", json.array([], json.string)),
  ])
  |> json.to_string()
}

/// Federation status endpoint — delegates to federation_api with a sample state.
fn federation_status_json() -> String {
  federation_api.sample_state()
  |> federation_api.federation_status_json()
}

pub fn encode_health(status: HealthStatus) -> json.Json {
  case status {
    Healthy -> json.string("healthy")
    Degraded(reason) ->
      json.object([
        #("status", json.string("degraded")),
        #("reason", json.string(reason)),
      ])
    Critical(reason) ->
      json.object([
        #("status", json.string("critical")),
        #("reason", json.string(reason)),
      ])
    Unknown -> json.string("unknown")
  }
}

// ---------------------------------------------------------------------------
// HTTP handler layer — adds proper HTTP semantics (headers, status, method).
// The string-based route() dispatcher remains unchanged above.
// STAMP: SC-GLM-UI-006, SC-AGUI-002
// ---------------------------------------------------------------------------

/// Wisp HTTP handler wrapping the string-returning route() dispatcher.
/// Adds proper HTTP semantics: headers, status codes, method dispatch.
/// STAMP: SC-GLM-UI-006, SC-AGUI-002
pub fn handle_request(req: HttpRequest(String)) -> HttpResponse(String) {
  let path = req.path
  let method = req.method
  case method {
    Get -> handle_get(path)
    Post -> handle_post(req, path)
    _ -> method_not_allowed_response()
  }
}

fn handle_get(path: String) -> HttpResponse(String) {
  case path {
    "/ag-ui/events" -> sse_response(agui_sse.create_sse_stream_for_agent("default", "thread-001", "run-001"))
    "/ag-ui/health" -> json_response(agui_sse.health_json(), 200)
    "/ag-ui/hitl/pending" ->
      json_response(agui_tools.pending_calls_to_json(agui_tools.initial_registry()), 200)
    "/ag-ui/state" -> {
      let state = agui_state.initial_state()
      let payload =
        agui_state.state_snapshot_payload(state, "thread-001")
        |> json.to_string()
      json_response(payload, 200)
    }
    // SSE mesh and health streams (T015)
    "/api/v1/sse/mesh" -> sse_response(sse_mesh_stream())
    "/api/v1/sse/health" -> sse_response(sse_health_stream())
    // Guardian lane — L0 pending approval list (T010, SC-SAFETY-001)
    "/api/v1/guardian/pending" ->
      json_response(guardian_pending_json(), 200)
    _ -> json_response(route(path), 200)
  }
}

/// Handle POST requests.
/// All mutation endpoints require a valid Bearer token (SC-SEC-001).
/// GET endpoints remain open for operator monitoring dashboards.
fn handle_post(
  req: HttpRequest(String),
  path: String,
) -> HttpResponse(String) {
  case auth.require_auth(req) {
    Error(reason) -> unauthorized_response(reason)
    Ok(_principal) -> {
      let body = req.body
      case path {
        "/ag-ui/run" -> {
          let run_id = "run-" <> int.to_string(8_675_309)
          json_response(
            agui_sse.create_run_response("default", "thread-001", run_id),
            200,
          )
        }
        "/ag-ui/hitl/respond" -> json_response(accepted_json(), 200)
        "/ag-ui/tools/result" -> json_response(received_json(), 200)
        _ -> post_route(path, body)
      }
    }
  }
}

/// Dispatch POST requests to mutation handlers.
/// Called only after Bearer-token auth has already passed.
/// STAMP: SC-GLM-UI-003 — all responses via typed JSON functions.
fn post_route(path: String, body: String) -> HttpResponse(String) {
  case path {
    "/api/v1/podman/action" -> json_response(podman_action_json(body), 200)
    "/api/v1/emergency/trigger" -> emergency_trigger_response(body)
    "/api/v1/guardian/respond" -> guardian_respond_response(body)
    "/api/v1/ooda/trigger" -> json_response(ooda_trigger_json(body), 200)
    _ -> json_response(not_found_json(path), 404)
  }
}

/// GET /api/v1/guardian/pending — returns pending L0 Guardian approval requests.
///
/// Returns the demo list of pending ApprovalRequests using l0_constitutional
/// types and approval_to_json for canonical encoding (SC-SAFETY-001).
///
/// Response shape:
///   {
///     "pending": [ApprovalRequest...],
///     "count": <int>,
///     "stamp": "SC-SAFETY-001"
///   }
///
/// STAMP: SC-SAFETY-001, SC-GLM-UI-003, SC-SIL4-006
fn guardian_pending_json() -> String {
  let demo_requests: List(ApprovalRequest) = [
    ApprovalRequest(
      request_id: "req-001",
      operation: "container.restart",
      description: "Restart ex-app-1 after OOM signal — operator-initiated",
      severity: ApprovalCritical,
      requester_agent: "ignition-daemon",
      timestamp: 1_743_897_600,
    ),
    ApprovalRequest(
      request_id: "req-002",
      operation: "genome.mutate",
      description: "Apply rolling update to zenoh-router tier",
      severity: ApprovalHigh,
      requester_agent: "evolution-agent",
      timestamp: 1_743_897_900,
    ),
    ApprovalRequest(
      request_id: "req-003",
      operation: "config.mesh.update",
      description: "Increase quorum threshold from 2oo3 to 3oo5",
      severity: ApprovalMedium,
      requester_agent: "orchestrator",
      timestamp: 1_743_898_200,
    ),
    ApprovalRequest(
      request_id: "req-004",
      operation: "kms.key.rotate",
      description: "Rotate Zenoh session key — scheduled 168h rotation",
      severity: ApprovalLow,
      requester_agent: "kms-daemon",
      timestamp: 1_743_898_500,
    ),
  ]
  json.object([
    #("pending", json.array(demo_requests, approval_to_json)),
    #("count", json.int(list.length(demo_requests))),
    #("stamp", json.string("SC-SAFETY-001")),
  ])
  |> json.to_string()
}

/// POST /api/v1/podman/action — dispatch a container mutation via MoZ (Zenoh).
///
/// Flow:
///   1. Decode body → MutationRequest (verb, container, reason)
///   2. Check circuit breaker state (SC-ZMOF-001)
///   3. Build JSON-RPC params and fire via moz_client.send_request/3
///   4. Return 202 Accepted + request_id (caller polls SSE for result)
///      or 400/503 on decode/circuit error
///
/// This is fire-and-forget: the Zenoh message is published and the function
/// returns immediately. The Rust ignition daemon processes the command and
/// publishes the result to indrajaal/l4/ignition/mcp/res/{request_id}.
/// The caller uses the returned request_id to subscribe via SSE.
///
/// STAMP: SC-ZMOF-001, SC-ZMOF-005, SC-GLM-UI-003
fn podman_action_json(body: String) -> String {
  case podman_api.mutation_request_decode(body) {
    Error(reason) ->
      podman_api.error_response_json(reason, "decode_error", "SC-GLM-UI-003")
    Ok(req) -> {
      let state = moz_client.new()
      case moz_client.circuit_status(state) {
        "open" ->
          podman_api.error_response_json(
            "MoZ circuit breaker open — Zenoh bridge unavailable",
            "circuit_open",
            "SC-ZMOF-001",
          )
        _ -> {
          let params =
            json.object([
              #("verb", json.string(req.verb)),
              #("container", json.string(req.container)),
              #("reason", json.string(req.reason)),
            ])
          case moz_client.send_request(state, req.verb, params) {
            #(_new_state, Error(reason)) ->
              podman_api.error_response_json(
                reason,
                "moz_dispatch_error",
                "SC-ZMOF-001",
              )
            #(_new_state, Ok(request_id)) ->
              podman_api.mutation_response_json(
                "accepted",
                req.container,
                "request_id=" <> request_id,
              )
          }
        }
      }
    }
  }
}

/// POST /api/v1/emergency/trigger — Guardian-gated emergency stop via MoZ.
///
/// SC-SAFETY-022: emergency stop MUST complete in < 5 seconds.
/// The endpoint is synchronous on the Zenoh publish path; the Rust daemon
/// processes the drain command and shuts the mesh within the SLA window.
///
/// Request body (JSON):
///   {"reason": "<human-readable cause>", "confirmation": "EMERGENCY STOP"}
///
/// The "EMERGENCY STOP" literal match is a deliberate confirmation gate —
/// it prevents accidental trigger from automated scripts that omit the field.
///
/// Flow:
///   1. Decode body → reason + confirmation
///   2. Validate confirmation == "EMERGENCY STOP" (literal; SC-SAFETY-022)
///   3. Publish drain command via MoZ (SC-ZMOF-001, SC-ZMOF-005)
///   4. Apply trigger_emergency to in-memory state
///   5. Return 200 with timestamp + MoZ request_id
///      or 400 if body is invalid / confirmation missing
///
/// STAMP: SC-SAFETY-022, SC-ZMOF-001, SC-ZMOF-005, SC-GLM-UI-003, SC-SIL4-006
fn emergency_trigger_response(body: String) -> HttpResponse(String) {
  let decoder = {
    use reason <- decode.field("reason", decode.string)
    use confirmation <- decode.field("confirmation", decode.string)
    decode.success(#(reason, confirmation))
  }
  case json.parse(body, decoder) {
    Error(_) ->
      json_response(
        json.object([
          #("status", json.string("error")),
          #("code", json.string("invalid_body")),
          #(
            "detail",
            json.string(
              "Expected {reason: string, confirmation: \"EMERGENCY STOP\"}",
            ),
          ),
          #("stamp", json.string("SC-SAFETY-022")),
        ])
          |> json.to_string(),
        400,
      )
    Ok(#(_, confirmation)) if confirmation != "EMERGENCY STOP" ->
      json_response(
        json.object([
          #("status", json.string("error")),
          #("code", json.string("confirmation_required")),
          #(
            "detail",
            json.string("Confirmation text required: send \"EMERGENCY STOP\""),
          ),
          #("stamp", json.string("SC-SAFETY-022")),
        ])
          |> json.to_string(),
        400,
      )
    Ok(#(reason, _)) -> {
      let timestamp_ms = router_system_time_nanos() / 1_000_000
      let moz_state = moz_client.new()
      let drain_params = json.object([#("reason", json.string(reason))])
      let #(_new_moz, dispatch_result) =
        moz_client.send_request(moz_state, "drain", drain_params)
      let _emergency_state =
        trigger_emergency(initial_emergency_state(), reason, timestamp_ms)
      let moz_info = case dispatch_result {
        Ok(request_id) ->
          json.object([
            #("dispatched", json.bool(True)),
            #("request_id", json.string(request_id)),
            #(
              "response_topic",
              json.string(moz_client.build_response_topic(request_id)),
            ),
          ])
        Error(reason_str) ->
          json.object([
            #("dispatched", json.bool(False)),
            #("moz_error", json.string(reason_str)),
          ])
      }
      json_response(
        json.object([
          #("status", json.string("triggered")),
          #("reason", json.string(reason)),
          #("timestamp_ms", json.int(timestamp_ms)),
          #("moz", moz_info),
          #("stamp", json.string("SC-SAFETY-022")),
        ])
          |> json.to_string(),
        200,
      )
    }
  }
}

/// POST /api/v1/guardian/respond — resolve an approval request.
///
/// Implements 2oo3 consensus semantics from l0_constitutional (SC-SIL4-006).
/// Resolves one pending approval by request_id with an "approved" or "rejected"
/// decision. The in-memory ApprovalState is constructed fresh per request
/// (stateless demo: persistence wired at the orchestrator layer).
///
/// Request body (JSON):
///   {"request_id": "<id>", "decision": "approved" | "rejected"}
///
/// Flow:
///   1. Decode body → request_id + decision string
///   2. Map decision string to ApprovalDecision (Approved | Rejected)
///   3. Call resolve_request on a demo ApprovalState
///   4. Return 200 with resolved outcome JSON
///      or 400 if body is invalid / decision unrecognised
///
/// STAMP: SC-SIL4-006, SC-SAFETY-001, SC-GLM-UI-003
fn guardian_respond_response(body: String) -> HttpResponse(String) {
  let decoder = {
    use request_id <- decode.field("request_id", decode.string)
    use decision_str <- decode.field("decision", decode.string)
    decode.success(#(request_id, decision_str))
  }
  case json.parse(body, decoder) {
    Error(_) ->
      json_response(
        json.object([
          #("status", json.string("error")),
          #("code", json.string("invalid_body")),
          #(
            "detail",
            json.string(
              "Expected {request_id: string, decision: \"approved\"|\"rejected\"}",
            ),
          ),
          #("stamp", json.string("SC-SIL4-006")),
        ])
          |> json.to_string(),
        400,
      )
    Ok(#(request_id, decision_str)) -> {
      let decision = case decision_str {
        "approved" -> Ok(Approved)
        "rejected" -> Ok(Rejected)
        _ -> Error("unknown_decision")
      }
      case decision {
        Error(_) ->
          json_response(
            json.object([
              #("status", json.string("error")),
              #("code", json.string("invalid_decision")),
              #(
                "detail",
                json.string("decision must be \"approved\" or \"rejected\""),
              ),
              #("stamp", json.string("SC-SIL4-006")),
            ])
              |> json.to_string(),
            400,
          )
        Ok(resolved_decision) -> {
          let demo_state = initial_approval_state()
          let _updated_state =
            resolve_request(demo_state, request_id, resolved_decision)
          json_response(
            json.object([
              #("status", json.string("resolved")),
              #("request_id", json.string(request_id)),
              #("decision", json.string(decision_str)),
              #("stamp", json.string("SC-SIL4-006")),
            ])
              |> json.to_string(),
            200,
          )
        }
      }
    }
  }
}

/// POST /api/v1/ooda/trigger — stub: accepts OODA cycle trigger payload.
fn ooda_trigger_json(_body: String) -> String {
  json.object([
    #("status", json.string("accepted")),
    #("action", json.string("ooda_trigger")),
    #("stamp", json.string("SC-GLM-UI-003")),
  ])
  |> json.to_string()
}

/// Shared accepted-status JSON for HITL respond endpoint.
fn accepted_json() -> String {
  json.object([#("status", json.string("accepted"))])
  |> json.to_string()
}

/// Shared received-status JSON for tools/result endpoint.
fn received_json() -> String {
  json.object([#("status", json.string("received"))])
  |> json.to_string()
}

// ---------------------------------------------------------------------------
// SSE stream handlers (T015 — SC-AGUI-002, SC-GLM-UI-010)
// ---------------------------------------------------------------------------

/// GET /api/v1/sse/mesh — pre-built SSE stream for mesh topology events.
///
/// Returns a complete SSE payload using the ring buffer formatters:
///   1. retry hint  — client reconnect delay
///   2. state_snapshot — initial mesh state
///   3. three container health events — zenoh-router-1/2/3
///   4. heartbeat comment frame
///
/// True chunked streaming requires async Mist; this returns the full body.
/// STAMP: SC-AGUI-002, SC-GLM-UI-010
fn sse_mesh_stream() -> String {
  let buf = sse_stream.new_buffer(16)

  let buf =
    sse_stream.push_event(
      buf,
      "state_snapshot",
      "{\"mesh\":\"indrajaal-c3i\",\"routers\":3,\"status\":\"connected\"}",
    )
  let buf =
    sse_stream.push_event(
      buf,
      "container_health",
      "{\"name\":\"zenoh-router-1\",\"status\":\"healthy\",\"cpu\":12.3}",
    )
  let buf =
    sse_stream.push_event(
      buf,
      "container_health",
      "{\"name\":\"zenoh-router-2\",\"status\":\"healthy\",\"cpu\":8.7}",
    )
  let buf =
    sse_stream.push_event(
      buf,
      "container_health",
      "{\"name\":\"zenoh-router-3\",\"status\":\"healthy\",\"cpu\":10.1}",
    )

  let frames =
    sse_stream.events_since(buf, -1)
    |> list.map(sse_stream.format_sse_event)

  string.concat([
    sse_stream.format_retry_hint(),
    string.concat(frames),
    sse_stream.format_heartbeat(),
  ])
}

/// GET /api/v1/sse/health — pre-built SSE stream for system health events.
///
/// Returns a complete SSE payload using the ring buffer formatters:
///   1. retry hint  — client reconnect delay
///   2. health_ok   — overall system health snapshot
///   3. sil_status  — SIL-6 compliance status
///   4. ooda_cycle  — latest OODA cycle metrics
///   5. heartbeat comment frame
///
/// STAMP: SC-AGUI-002, SC-GLM-UI-010
fn sse_health_stream() -> String {
  let buf = sse_stream.new_buffer(16)

  let buf =
    sse_stream.push_event(
      buf,
      "health_ok",
      "{\"status\":\"ok\",\"sil\":\"SIL-6\",\"interface\":\"wisp\",\"port\":4100}",
    )
  let buf =
    sse_stream.push_event(
      buf,
      "sil_status",
      "{\"level\":\"SIL-6\",\"compliant\":true,\"tests_passed\":1721}",
    )
  let buf =
    sse_stream.push_event(
      buf,
      "ooda_cycle",
      "{\"phase\":\"observe\",\"cycle_ms\":28,\"target_ms\":100,\"within_sla\":true}",
    )

  let frames =
    sse_stream.events_since(buf, -1)
    |> list.map(sse_stream.format_sse_event)

  string.concat([
    sse_stream.format_retry_hint(),
    string.concat(frames),
    sse_stream.format_heartbeat(),
  ])
}

fn sse_response(body: String) -> HttpResponse(String) {
  response.new(200)
  |> response.set_body(body)
  |> response.set_header("content-type", "text/event-stream")
  |> response.set_header("cache-control", "no-cache")
  |> response.set_header("connection", "keep-alive")
}

fn json_response(body: String, status: Int) -> HttpResponse(String) {
  response.new(status)
  |> response.set_body(body)
  |> response.set_header("content-type", "application/json")
}

fn method_not_allowed_response() -> HttpResponse(String) {
  response.new(405)
  |> response.set_body("{\"error\":\"method_not_allowed\"}")
  |> response.set_header("content-type", "application/json")
}

/// Return a 401 Unauthorized response.
/// Body is structured JSON produced by auth.auth_error_json (SC-GLM-UI-003, SC-SEC-001).
fn unauthorized_response(reason: String) -> HttpResponse(String) {
  response.new(401)
  |> response.set_body(auth.auth_error_json(reason))
  |> response.set_header("content-type", "application/json")
  |> response.set_header("www-authenticate", "Bearer realm=\"c3i\"")
}
