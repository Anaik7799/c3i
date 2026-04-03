/// Wisp API for Telemetry plane (SC-GLM-UI-001, SC-GLM-UI-003).
/// Typed JSON via gleam/json — no raw strings (SC-GLM-UI-003).
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-007
import gleam/json

/// Full telemetry status JSON with OTel spans, active traces, metrics, and log level.
pub fn status_json(
  active_traces: Int,
  total_spans: Int,
  cpu_percent: Float,
  memory_mb: Int,
  network_bytes_sec: Int,
  log_level: String,
) -> String {
  json.object([
    #("plane", json.string("telemetry")),
    #("active_traces", json.int(active_traces)),
    #("total_spans", json.int(total_spans)),
    #(
      "metrics",
      json.object([
        #("cpu_percent", json.float(cpu_percent)),
        #("memory_mb", json.int(memory_mb)),
        #("network_bytes_sec", json.int(network_bytes_sec)),
      ]),
    ),
    #("log_level", json.string(log_level)),
  ])
  |> json.to_string()
}

/// Compact metrics-only JSON for telemetry plane.
pub fn metrics_json(
  cpu_percent: Float,
  memory_mb: Int,
  network_bytes_sec: Int,
) -> String {
  json.object([
    #("plane", json.string("telemetry")),
    #("cpu_percent", json.float(cpu_percent)),
    #("memory_mb", json.int(memory_mb)),
    #("network_bytes_sec", json.int(network_bytes_sec)),
  ])
  |> json.to_string()
}
