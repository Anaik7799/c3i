/// Lustre component for Prajna Operator plane (SC-GLM-UI-001).
/// Manages holon count, threat level, cockpit mode, and circuit state.
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-002, SC-GLM-UI-009
pub type PrajnaModel {
  PrajnaModel(
    holon_count: Int,
    threat_level: String,
    cockpit_mode: String,
    circuit_state: String,
    messages_routed: Int,
  )
}

pub type PrajnaMsg {
  HolonCreated
  ThreatChanged(String)
  ModeChanged(String)
  CircuitChanged(String)
  RefreshPrajna
}

pub fn init() -> PrajnaModel {
  PrajnaModel(
    holon_count: 0,
    threat_level: "nominal",
    cockpit_mode: "dark",
    circuit_state: "closed",
    messages_routed: 0,
  )
}

pub fn update(model: PrajnaModel, msg: PrajnaMsg) -> PrajnaModel {
  case msg {
    HolonCreated -> PrajnaModel(..model, holon_count: model.holon_count + 1)
    ThreatChanged(level) -> PrajnaModel(..model, threat_level: level)
    ModeChanged(mode) -> PrajnaModel(..model, cockpit_mode: mode)
    CircuitChanged(state) -> PrajnaModel(..model, circuit_state: state)
    RefreshPrajna -> model
  }
}

pub fn is_emergency(model: PrajnaModel) -> Bool {
  model.threat_level == "critical" || model.circuit_state == "open"
}

pub fn active_holons(model: PrajnaModel) -> Int {
  model.holon_count
}
