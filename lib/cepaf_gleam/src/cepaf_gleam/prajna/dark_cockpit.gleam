//// [C3I-SIL6-MSTS] <c3i-module><identity><module>cepaf_gleam/prajna/dark_cockpit</module>
////   <fsharp-lineage>Cepaf.Prajna.DarkCockpit</fsharp-lineage></identity>
////   <fractal-topology><layer>L5_COGNITIVE</layer></fractal-topology></c3i-module>

import gleam/list

pub type CockpitMode {
  Dark
  Dim
  NormalMode
  Bright
  EmergencyMode
}

pub type AlertSeverity {
  WarningSeverity
  ErrorSeverity
  CriticalSeverity
}

pub type Alert {
  Alert(
    id: String,
    severity: AlertSeverity,
    message: String,
    source: String,
    timestamp: String,
    acknowledged: Bool,
  )
}

pub type CockpitState {
  CockpitState(mode: CockpitMode, alerts: List(Alert), last_update: String)
}

pub fn initial_state() -> CockpitState {
  CockpitState(mode: Dark, alerts: [], last_update: "")
}

pub fn determine_mode(alerts: List(Alert)) -> CockpitMode {
  let unacked = list.filter(alerts, fn(a) { !a.acknowledged })
  let critical_count =
    list.length(list.filter(unacked, fn(a) { a.severity == CriticalSeverity }))
  let error_count =
    list.length(list.filter(unacked, fn(a) { a.severity == ErrorSeverity }))
  let warning_count =
    list.length(list.filter(unacked, fn(a) { a.severity == WarningSeverity }))
  case critical_count, error_count, warning_count {
    c, _, _ if c > 0 -> EmergencyMode
    _, e, _ if e > 2 -> Bright
    _, e, _ if e > 0 -> NormalMode
    _, _, w if w > 0 -> Dim
    _, _, _ -> Dark
  }
}

pub fn add_alert(state: CockpitState, alert: Alert) -> CockpitState {
  let new_alerts = [alert, ..state.alerts]
  let new_mode = determine_mode(new_alerts)
  CockpitState(..state, alerts: new_alerts, mode: new_mode)
}

pub fn acknowledge_alert(state: CockpitState, alert_id: String) -> CockpitState {
  let new_alerts =
    list.map(state.alerts, fn(a) {
      case a.id == alert_id {
        True -> Alert(..a, acknowledged: True)
        False -> a
      }
    })
  let new_mode = determine_mode(new_alerts)
  CockpitState(..state, alerts: new_alerts, mode: new_mode)
}

pub fn get_unacknowledged_by_severity(
  state: CockpitState,
  severity: AlertSeverity,
) -> List(Alert) {
  list.filter(state.alerts, fn(a) { !a.acknowledged && a.severity == severity })
}

pub fn update(state: CockpitState, timestamp: String) -> CockpitState {
  let new_mode = determine_mode(state.alerts)
  CockpitState(..state, mode: new_mode, last_update: timestamp)
}
