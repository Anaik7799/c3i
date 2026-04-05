//// =============================================================================
//// [C3I-SIL6-MSTS] MATHEMATICAL & SEMANTIC MODULE CONTRACT
//// =============================================================================
//// <c3i-module>
////   <identity>
////     <module>cepaf_gleam/ui/state</module>
////     <fsharp-lineage>Cepaf.Mesh.MeshState.fs</fsharp-lineage>
////   </identity>
////   <fractal-topology>
////     <layer>L3_TRANSACTION</layer>
////   </fractal-topology>
////   <compliance>
////     <stamp-controls>SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-009, SC-MUDA-001</stamp-controls>
////   </compliance>
////   <transformations>
////     <morphism type="injective">
////       F# mutable record state ↪ Gleam immutable SharedMeshState value type.
////       Mitigation: All mutations return a new state value — no in-place update.
////     </morphism>
////   </transformations>
//// </c3i-module>
//// =============================================================================
////
//// SharedMeshState — canonical typed mesh state for the triple-interface mandate.
////
//// This module is the SOLE source of state defaults for the Wisp API layer.
//// All JSON serialisation flows through the typed functions here, never via
//// raw string concatenation (SC-GLM-UI-003).
////
//// STAMP: SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-009, SC-MUDA-001

import gleam/int
import gleam/json

/// Snapshot of live mesh state, shared across all three interfaces.
///
/// Fields are intentionally flat and primitive so they can be sourced
/// from any future Zenoh subscription without an impedance mismatch.
pub type SharedMeshState {
  SharedMeshState(
    /// Total number of containers in the genome.
    container_count: Int,
    /// Containers that have passed health consensus.
    healthy_count: Int,
    /// Immune threat level: "nominal" | "elevated" | "critical"
    threat_level: String,
    /// Current OODA phase: "observe" | "orient" | "decide" | "act"
    ooda_phase: String,
    /// Dark-cockpit illumination mode: "dark" | "dim" | "normal" | "bright" | "emergency"
    dark_cockpit_mode: String,
    /// Whether the Zenoh router is reachable from this node.
    zenoh_connected: Bool,
    /// Whether the 2-of-3 quorum is satisfied across the cluster.
    quorum_healthy: Bool,
    /// Unix epoch milliseconds of the last state observation.
    last_updated_ms: Int,
  )
}

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------

/// Return a safe, structurally valid default state.
///
/// Represents a single-node deployment with Zenoh available and quorum met —
/// the minimal viable operational posture before any live subscription data
/// arrives from a real Zenoh source.
pub fn default_state() -> SharedMeshState {
  SharedMeshState(
    container_count: 16,
    healthy_count: 16,
    threat_level: "nominal",
    ooda_phase: "observe",
    dark_cockpit_mode: "dark",
    zenoh_connected: True,
    quorum_healthy: True,
    last_updated_ms: 0,
  )
}

// ---------------------------------------------------------------------------
// JSON serialisers (SC-GLM-UI-003 — typed gleam/json, no string concat)
// ---------------------------------------------------------------------------

/// Serialise overall system health for the /health and /api/health endpoints.
///
/// Derives the status string from the fraction of healthy containers and the
/// quorum flag so that the derivation lives co-located with the state type.
pub fn to_health_json(state: SharedMeshState) -> String {
  let derived_status = case
    state.quorum_healthy && state.healthy_count == state.container_count
  {
    True -> "ok"
    False ->
      case state.healthy_count > state.container_count / 2 {
        True -> "degraded"
        False -> "critical"
      }
  }
  json.object([
    #("status", json.string(derived_status)),
    #("interface", json.string("wisp")),
    #("port", json.int(4100)),
    #("version", json.string("1.0.0")),
    #("container_count", json.int(state.container_count)),
    #("healthy_count", json.int(state.healthy_count)),
    #("zenoh_connected", json.bool(state.zenoh_connected)),
    #("quorum_healthy", json.bool(state.quorum_healthy)),
    #("last_updated_ms", json.int(state.last_updated_ms)),
  ])
  |> json.to_string()
}

/// Serialise immune-system status for the /api/v1/immune endpoint.
///
/// Derives the antibody count and blocked-attack count from threat level to
/// keep the response semantically consistent with the underlying state.
pub fn to_immune_json(state: SharedMeshState) -> String {
  let antibodies = case state.threat_level {
    "nominal" -> 0
    "elevated" -> 3
    _ -> 12
  }
  let attacks_blocked = case state.threat_level {
    "nominal" -> 0
    "elevated" -> 1
    _ -> 5
  }
  json.object([
    #("page", json.string("Immune System")),
    #("status", json.string("active")),
    #("threat_level", json.string(state.threat_level)),
    #("antibodies_deployed", json.int(antibodies)),
    #("chaos_attacks_blocked", json.int(attacks_blocked)),
    #("last_scan", json.string("2026-04-02T22:00:00Z")),
  ])
  |> json.to_string()
}

/// Serialise Zenoh mesh connectivity for the /api/v1/zenoh endpoint.
pub fn to_zenoh_json(state: SharedMeshState) -> String {
  let router_count = case state.zenoh_connected {
    True -> 3
    False -> 0
  }
  let topics = case state.zenoh_connected {
    True -> 12
    False -> 0
  }
  json.object([
    #("page", json.string("Zenoh Mesh")),
    #("status", json.string("active")),
    #("routers", json.int(router_count)),
    #("connected", json.bool(state.zenoh_connected)),
    #("topics_active", json.int(topics)),
    #("messages_per_sec", json.int(0)),
    #(
      "router_endpoints",
      json.array(
        [
          json.string("tcp/localhost:7447"),
          json.string("tcp/localhost:7448"),
          json.string("tcp/localhost:7449"),
        ],
        fn(s) { s },
      ),
    ),
  ])
  |> json.to_string()
}

/// Serialise a top-level dashboard summary for the /api/v1/dashboard endpoint.
///
/// Includes "path" field for backwards-compatibility with existing test suite
/// (wisp_tui_content_test.dashboard_has_path_test).
pub fn to_dashboard_json(state: SharedMeshState) -> String {
  let health_pct = case state.container_count > 0 {
    True ->
      int.to_float(state.healthy_count)
      /. int.to_float(state.container_count)
      *. 100.0
    False -> 0.0
  }
  json.object([
    #("page", json.string("Dashboard")),
    #("path", json.string("/dashboard")),
    #("status", json.string("active")),
    #("container_count", json.int(state.container_count)),
    #("healthy_count", json.int(state.healthy_count)),
    #("health_pct", json.float(health_pct)),
    #("threat_level", json.string(state.threat_level)),
    #("ooda_phase", json.string(state.ooda_phase)),
    #("dark_cockpit_mode", json.string(state.dark_cockpit_mode)),
    #("zenoh_connected", json.bool(state.zenoh_connected)),
    #("quorum_healthy", json.bool(state.quorum_healthy)),
    #("last_updated_ms", json.int(state.last_updated_ms)),
  ])
  |> json.to_string()
}
