/// Wisp API for Verification plane (SC-GLM-UI-001, SC-GLM-UI-003).
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-007
import cepaf_gleam/verification/swarm.{
  type FractalLayerReport, type OodaMetrics, type SwarmReport,
}
import gleam/json
import gleam/list

pub fn swarm_report_json(report: SwarmReport) -> String {
  json.object([
    #("plane", json.string("verification")),
    #("healthy_containers", json.int(report.healthy_containers)),
    #("total_containers", json.int(report.total_containers)),
    #("ooda", encode_ooda(report.ooda_metrics)),
    #("fractal_layers", json.array(report.fractal_layers, encode_layer)),
  ])
  |> json.to_string()
}

pub fn verification_status_json(
  healthy: Int,
  total: Int,
  compliant: Bool,
) -> String {
  json.object([
    #("plane", json.string("verification")),
    #("healthy", json.int(healthy)),
    #("total", json.int(total)),
    #("compliant", json.bool(compliant)),
    #(
      "compliance_percent",
      json.float(case total {
        0 -> 0.0
        _ -> {
          let h = case healthy {
            n -> n
          }
          let t = case total {
            n -> n
          }
          // Simple integer percentage
          json.int(h * 100 / t)
          0.0
        }
      }),
    ),
  ])
  |> json.to_string()
}

fn encode_ooda(m: OodaMetrics) -> json.Json {
  json.object([
    #("agent_latency_ms", json.int(m.agent_latency_ms)),
    #("intelligence_latency_ms", json.int(m.intelligence_latency_ms)),
    #("compliance", json.bool(m.compliance)),
  ])
}

fn encode_layer(l: FractalLayerReport) -> json.Json {
  json.object([
    #("layer", json.int(l.layer)),
    #("status", json.string(l.status)),
    #("evidence", json.string(l.evidence)),
  ])
}
