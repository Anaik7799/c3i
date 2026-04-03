/// TUI view for Verification plane (SC-GLM-UI-001, SC-GLM-UI-004, SC-GLM-UI-007).
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-004, SC-GLM-UI-007
import cepaf_gleam/cockpit/visuals
import cepaf_gleam/ui/lustre/verification.{type VerificationModel}
import cepaf_gleam/verification/swarm.{type FractalLayerReport, type SwarmReport}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string

pub fn render(model: VerificationModel) -> String {
  let header = visuals.with_color("  VERIFICATION", "cyan")
  let status = render_run_status(model)
  let report = case model.last_report {
    Some(r) -> render_report(r)
    None -> "  No verification run yet."
  }
  string.join([header, status, "", report], "\n")
}

fn render_run_status(model: VerificationModel) -> String {
  case model.running {
    True -> "  " <> visuals.with_color("RUNNING...", "yellow")
    False ->
      "  "
      <> visuals.with_color("IDLE", "blue")
      <> "  History: "
      <> int.to_string(list.length(model.history))
      <> " runs"
  }
}

fn render_report(report: SwarmReport) -> String {
  let pct = case report.total_containers {
    0 -> 0
    t -> report.healthy_containers * 100 / t
  }
  let pct_float = case pct {
    n -> n
  }
  let bar = visuals.render_progress_bar(int_to_float(pct) /. 100.0, 30)
  let containers =
    "  Containers: "
    <> int.to_string(report.healthy_containers)
    <> "/"
    <> int.to_string(report.total_containers)
    <> " healthy"
  let compliance =
    "  OODA: "
    <> case report.ooda_metrics.compliance {
      True -> visuals.with_color("COMPLIANT", "green")
      False -> visuals.with_color("NON-COMPLIANT", "red")
    }
    <> "  Agent: "
    <> int.to_string(report.ooda_metrics.agent_latency_ms)
    <> "ms"
    <> "  Intel: "
    <> int.to_string(report.ooda_metrics.intelligence_latency_ms)
    <> "ms"
  let layers = render_layers(report.fractal_layers)
  string.join([bar, containers, compliance, "", layers], "\n")
}

fn render_layers(layers: List(FractalLayerReport)) -> String {
  layers
  |> list.map(fn(l) {
    let color = case l.status {
      "Stable" -> "green"
      "Healthy" -> "green"
      "Degraded" -> "yellow"
      _ -> "red"
    }
    "  L"
    <> int.to_string(l.layer)
    <> " "
    <> visuals.with_color(l.status, color)
    <> " — "
    <> l.evidence
  })
  |> string.join("\n")
}

fn int_to_float(n: Int) -> Float {
  int.to_float(n)
}
