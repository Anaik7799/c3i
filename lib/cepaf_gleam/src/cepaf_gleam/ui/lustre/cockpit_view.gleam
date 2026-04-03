/// Lustre component for Cockpit plane (SC-GLM-UI-001).
/// Dark Cockpit pattern — anomalies surface, normal is minimal (SC-GLM-UI-008).
/// Imports from cockpit/domain.gleam — no type duplication (SC-GLM-UI-009).
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-002, SC-GLM-UI-008, SC-GLM-UI-009
import cepaf_gleam/cockpit/domain.{
  type Alarm, type AlarmLevel, type MeshNode, type ViewMode, Advisory, Caution,
  Connected, Critical, Normal, Warning,
}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{Eq, Gt, Lt}

pub type CockpitModel {
  CockpitModel(
    nodes: List(MeshNode),
    alarms: List(Alarm),
    view_mode: ViewMode,
    dark_cockpit: Bool,
    selected_node: Option(String),
  )
}

pub type CockpitMsg {
  NodesUpdated(List(MeshNode))
  AlarmsUpdated(List(Alarm))
  SetViewMode(ViewMode)
  SelectNode(String)
  AcknowledgeAlarm(String)
  ToggleDarkCockpit
  RefreshCockpit
}

pub fn init() -> CockpitModel {
  CockpitModel(
    nodes: [],
    alarms: [],
    view_mode: domain.Overview,
    dark_cockpit: True,
    selected_node: None,
  )
}

pub fn update(model: CockpitModel, msg: CockpitMsg) -> CockpitModel {
  case msg {
    NodesUpdated(nodes) -> CockpitModel(..model, nodes: nodes)
    AlarmsUpdated(alarms) -> CockpitModel(..model, alarms: alarms)
    SetViewMode(mode) -> CockpitModel(..model, view_mode: mode)
    SelectNode(id) -> CockpitModel(..model, selected_node: Some(id))
    AcknowledgeAlarm(_id) -> model
    ToggleDarkCockpit ->
      CockpitModel(..model, dark_cockpit: !model.dark_cockpit)
    RefreshCockpit -> model
  }
}

/// Dark Cockpit: only show nodes with non-normal status (SC-GLM-UI-008).
pub fn visible_nodes(model: CockpitModel) -> List(MeshNode) {
  case model.dark_cockpit {
    True -> list.filter(model.nodes, fn(n) { n.status != Connected })
    False -> model.nodes
  }
}

/// Active alarms sorted by severity (Critical first).
pub fn active_alarms(model: CockpitModel) -> List(Alarm) {
  list.filter(model.alarms, fn(a) { a.level != Normal })
  |> list.sort(fn(a, b) {
    let sa = alarm_severity_rank(a.level)
    let sb = alarm_severity_rank(b.level)
    case sa > sb {
      True -> Lt
      False ->
        case sa == sb {
          True -> Eq
          False -> Gt
        }
    }
  })
}

fn alarm_severity_rank(level: AlarmLevel) -> Int {
  case level {
    Critical -> 5
    Warning -> 4
    Caution -> 3
    Advisory -> 2
    Normal -> 1
  }
}
