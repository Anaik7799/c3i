/// Lustre component for Config Management plane (SC-GLM-UI-001).
/// Manages container config, network topology, and resource validation.
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-002, SC-GLM-UI-009
import gleam/int
import gleam/list

pub type ConfigModel {
  ConfigModel(
    containers: List(String),
    networks: List(String),
    quorum_size: Int,
    is_valid: Bool,
    total_cpu: Int,
    total_memory: Int,
  )
}

pub type ConfigMsg {
  ConfigLoaded
  ValidationRan(Bool)
  ContainerAdded(String)
  RefreshConfig
}

pub fn init() -> ConfigModel {
  ConfigModel(
    containers: [],
    networks: [],
    quorum_size: 3,
    is_valid: False,
    total_cpu: 0,
    total_memory: 0,
  )
}

pub fn update(model: ConfigModel, msg: ConfigMsg) -> ConfigModel {
  case msg {
    ConfigLoaded -> model
    ValidationRan(valid) -> ConfigModel(..model, is_valid: valid)
    ContainerAdded(name) ->
      ConfigModel(..model, containers: [name, ..model.containers])
    RefreshConfig -> model
  }
}

pub fn quorum_met(model: ConfigModel) -> Bool {
  list.length(model.containers) >= model.quorum_size
}

pub fn resource_summary(model: ConfigModel) -> String {
  "CPU:"
  <> int.to_string(model.total_cpu)
  <> " MEM:"
  <> int.to_string(model.total_memory)
  <> "MB"
}
