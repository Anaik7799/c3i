/// Lustre component for Verification plane (SC-GLM-UI-001).
/// Imports from verification/swarm.gleam — no type duplication (SC-GLM-UI-009).
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-002, SC-GLM-UI-009, SC-PROM-001..007, SC-GVF-001..008
import cepaf_gleam/verification/graph_verification.{type GraphCheck}
import cepaf_gleam/verification/prometheus.{
  type ProofToken, type VerificationResult, Inconclusive, Rejected, Verified,
}
import cepaf_gleam/verification/swarm.{type SwarmReport}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

pub type VerificationModel {
  VerificationModel(
    last_report: Option(SwarmReport),
    running: Bool,
    history: List(VerificationRun),
    latest_proof: Option(ProofToken),
    graph_checks: List(GraphCheck),
    dag_node_count: Int,
    dag_edge_count: Int,
    proof_history: List(ProofToken),
  )
}

pub type VerificationRun {
  VerificationRun(timestamp: Int, healthy: Int, total: Int, compliant: Bool)
}

pub type VerificationMsg {
  StartVerification
  ReportReceived(SwarmReport)
  RefreshVerification
  ProofGenerated(ProofToken)
  GraphChecksCompleted(List(GraphCheck))
  DagUpdated(node_count: Int, edge_count: Int)
}

pub fn init() -> VerificationModel {
  VerificationModel(
    last_report: None,
    running: False,
    history: [],
    latest_proof: None,
    graph_checks: [],
    dag_node_count: 0,
    dag_edge_count: 0,
    proof_history: [],
  )
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
      VerificationModel(
        ..model,
        last_report: Some(report),
        running: False,
        history: [run, ..model.history],
      )
    }
    RefreshVerification -> model
    ProofGenerated(proof) ->
      VerificationModel(
        ..model,
        latest_proof: Some(proof),
        proof_history: [proof, ..model.proof_history],
      )
    GraphChecksCompleted(checks) ->
      VerificationModel(..model, graph_checks: checks)
    DagUpdated(nc, ec) ->
      VerificationModel(..model, dag_node_count: nc, dag_edge_count: ec)
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

/// Returns True if all graph checks have passed (SC-GRAPH-001).
pub fn all_checks_passed(model: VerificationModel) -> Bool {
  list.all(model.graph_checks, fn(c) { c.passed })
}

/// Returns True if the latest proof token carries a Verified result (SC-PROM-001).
pub fn latest_proof_verified(model: VerificationModel) -> Bool {
  case model.latest_proof {
    None -> False
    Some(p) ->
      case p.result {
        Verified -> True
        Rejected(_) -> False
        Inconclusive -> False
      }
  }
}

/// Converts a VerificationResult to a display string.
pub fn proof_result_string(result: VerificationResult) -> String {
  case result {
    Verified -> "Verified"
    Rejected(_) -> "Rejected"
    Inconclusive -> "Inconclusive"
  }
}

fn int_to_float(n: Int) -> Float {
  int.to_float(n)
}
