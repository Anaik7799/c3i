/// Wisp API for Metabolic plane (SC-GLM-UI-001, SC-GLM-UI-003).
/// Typed JSON via gleam/json — no raw strings (SC-GLM-UI-003).
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-007
import cepaf_gleam/metabolic/domain.{
  type HealthStatus, type MetabolicState, Critical, Dead, Degraded, Optimal,
  Stable,
}
import gleam/json

/// Encode metabolic HealthStatus to string.
fn health_status_to_string(status: HealthStatus) -> String {
  case status {
    Optimal -> "Healthy"
    Stable -> "Healthy"
    Degraded -> "Stressed"
    Critical -> "Critical"
    Dead -> "Critical"
  }
}

/// Full metabolic status JSON with set_point, energy, cpu_load, and health.
pub fn status_json(state: MetabolicState) -> String {
  json.object([
    #("plane", json.string("metabolic")),
    #("set_point", json.float(state.metabolic_rate)),
    #("energy", json.float(100.0)),
    #("cpu_load", json.float(state.cpu_usage_percent)),
    #("memory_usage_bytes", json.int(state.memory_usage_bytes)),
    #("network_latency_ms", json.float(state.network_latency_ms)),
    #("tps", json.float(state.tps)),
    #("error_rate", json.float(state.error_rate)),
    #(
      "health_status",
      json.string(health_status_to_string(state.health_status)),
    ),
  ])
  |> json.to_string()
}

/// Compact health summary for metabolic plane.
pub fn health_summary_json(
  set_point: Float,
  cpu_load: Float,
  health: HealthStatus,
) -> String {
  json.object([
    #("plane", json.string("metabolic")),
    #("set_point", json.float(set_point)),
    #("cpu_load", json.float(cpu_load)),
    #("health_status", json.string(health_status_to_string(health))),
  ])
  |> json.to_string()
}
