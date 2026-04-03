/// TUI view for Prajna Operator plane (SC-GLM-UI-001, SC-GLM-UI-004, SC-GLM-UI-007).
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-004, SC-GLM-UI-007
import cepaf_gleam/cockpit/visuals
import cepaf_gleam/ui/lustre/prajna.{type PrajnaModel}
import gleam/int
import gleam/string

pub fn render(model: PrajnaModel) -> String {
  let header = visuals.with_color("  PRAJNA OPERATOR", "cyan")
  let holons = render_holons(model)
  let threat = render_threat(model)
  let cockpit = render_cockpit(model)
  let circuit = render_circuit(model)
  let routed = render_routed(model)
  string.join([header, holons, threat, cockpit, circuit, routed], "\n")
}

fn render_holons(model: PrajnaModel) -> String {
  "  Holons: " <> visuals.with_color(int.to_string(model.holon_count), "blue")
}

fn render_threat(model: PrajnaModel) -> String {
  let color = case model.threat_level {
    "nominal" -> "green"
    "elevated" -> "yellow"
    "critical" -> "red"
    _ -> "red"
  }
  "  Threat: " <> visuals.with_color(model.threat_level, color)
}

fn render_cockpit(model: PrajnaModel) -> String {
  let color = case model.cockpit_mode {
    "dark" -> "green"
    "alert" -> "yellow"
    _ -> "magenta"
  }
  "  Cockpit: " <> visuals.with_color(model.cockpit_mode, color)
}

fn render_circuit(model: PrajnaModel) -> String {
  let color = case model.circuit_state {
    "closed" -> "green"
    "half-open" -> "yellow"
    "open" -> "red"
    _ -> "yellow"
  }
  "  Circuit: " <> visuals.with_color(model.circuit_state, color)
}

fn render_routed(model: PrajnaModel) -> String {
  "  Messages Routed: " <> int.to_string(model.messages_routed)
}
