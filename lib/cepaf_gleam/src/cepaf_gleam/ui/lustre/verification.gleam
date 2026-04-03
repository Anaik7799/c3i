/// Lustre component for Verification plane (SC-GLM-UI-001).
/// Imports from verification/swarm.gleam — no type duplication (SC-GLM-UI-009).
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-002, SC-GLM-UI-009
import cepaf_gleam/verification/swarm.{
  type FractalLayerReport, type OodaMetrics, type SwarmReport,
}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

pub type VerificationModel {
  VerificationModel(
    last_report: Option(SwarmReport),
    running: Bool,
    history: List(VerificationRun),
  )
}

pub type VerificationRun {
  VerificationRun(timestamp: Int, healthy: Int, total: Int, compliant: Bool)
}

pub type VerificationMsg {
  StartVerification
  ReportReceived(SwarmReport)
  RefreshVerification
}

pub fn init() -> VerificationModel {
  VerificationModel(last_report: None, running: False, history: [])
}

pub fn update(
  model: VerificationModel,
  msg: VerificationMsg,
) -> VerificationModel {
  case msg {
    StartVerification -> VerificationModel(..model, running: True)
    ReportReceived(report) -> {
      let run =
        VerificationRun(
          timestamp: 0,
          healthy: report.healthy_containers,
          total: report.total_containers,
          compliant: report.ooda_metrics.compliance,
        )
      VerificationModel(last_report: Some(report), running: False, history: [
        run,
        ..model.history
      ])
    }
    RefreshVerification -> model
  }
}

pub fn compliance_percent(report: SwarmReport) -> Float {
  case report.total_containers {
    0 -> 0.0
    total -> {
      let healthy_float = int_to_float(report.healthy_containers)
      let total_float = int_to_float(total)
      healthy_float /. total_float *. 100.0
    }
  }
}

fn int_to_float(n: Int) -> Float {
  int.to_float(n)
}
