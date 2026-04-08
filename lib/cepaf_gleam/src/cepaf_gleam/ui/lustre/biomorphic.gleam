//// [C3I-SIL6-MSTS] MODULE CONTRACT
//// <c3i-module>
////   <identity><module>cepaf_gleam/ui/lustre/biomorphic</module></identity>
////   <fractal-topology><layer>L5_COGNITIVE</layer></fractal-topology>
////   <compliance><stamp-controls>SC-GLM-UI-001, SC-GLM-UI-002</stamp-controls></compliance>
//// </c3i-module>
////
//// Lustre MVU component for the Biomorphic page.
//// Displays bio/neuro/immune subsystem health as a unified dashboard.

import gleam/option.{type Option, None, Some}

pub type SubsystemHealth {
  SubsystemHealth(name: String, status: String, score: Float, detail: String)
}

pub type BiomorphicModel {
  BiomorphicModel(
    bio: SubsystemHealth,
    neuro: SubsystemHealth,
    immune: SubsystemHealth,
    overall_score: Float,
    mode: String,
    loading: Bool,
    error: Option(String),
  )
}

pub type BiomorphicMsg {
  HealthLoaded(bio: SubsystemHealth, neuro: SubsystemHealth, immune: SubsystemHealth, overall: Float, mode: String)
  SubsystemUpdated(name: String, status: String, score: Float)
  RefreshBiomorphic
  ErrorReceived(String)
}

pub fn init() -> BiomorphicModel {
  BiomorphicModel(
    bio: SubsystemHealth(name: "Bio", status: "healthy", score: 1.0, detail: "Metabolic homeostasis nominal"),
    neuro: SubsystemHealth(name: "Neuro", status: "healthy", score: 1.0, detail: "Cortex OODA cycle <30ms"),
    immune: SubsystemHealth(name: "Immune", status: "healthy", score: 1.0, detail: "Sentinel active, 0 threats"),
    overall_score: 1.0,
    mode: "normal",
    loading: True,
    error: None,
  )
}

pub fn update(model: BiomorphicModel, msg: BiomorphicMsg) -> BiomorphicModel {
  case msg {
    HealthLoaded(b, n, i, o, m) ->
      BiomorphicModel(bio: b, neuro: n, immune: i, overall_score: o, mode: m, loading: False, error: None)
    SubsystemUpdated(name, status, score) ->
      case name {
        "bio" -> BiomorphicModel(..model, bio: SubsystemHealth(..model.bio, status: status, score: score))
        "neuro" -> BiomorphicModel(..model, neuro: SubsystemHealth(..model.neuro, status: status, score: score))
        "immune" -> BiomorphicModel(..model, immune: SubsystemHealth(..model.immune, status: status, score: score))
        _ -> model
      }
    RefreshBiomorphic -> BiomorphicModel(..model, loading: True)
    ErrorReceived(e) -> BiomorphicModel(..model, error: Some(e), loading: False)
  }
}

pub fn all_healthy(model: BiomorphicModel) -> Bool {
  model.bio.status == "healthy" && model.neuro.status == "healthy" && model.immune.status == "healthy"
}
