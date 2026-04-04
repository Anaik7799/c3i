//// [C3I-SIL6-MSTS] MODULE CONTRACT
//// <c3i-module>
////   <identity><module>cepaf_gleam/fractal/l0_constitutional</module></identity>
////   <fractal-topology><layer>L0_CONSTITUTIONAL</layer></fractal-topology>
////   <compliance><stamp-controls>SC-AGUI-004, SC-SAFETY-001, SC-GUARD-001</stamp-controls></compliance>
//// </c3i-module>
////
//// L0 Constitutional fractal widgets: Guardian approval, emergency stop,
//// constitutional monitoring (Psi-0..5, Omega-0).
//// HITL approval is MANDATORY at this layer (SC-AGUI-004).

import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}

/// Guardian approval request for HITL.
pub type ApprovalRequest {
  ApprovalRequest(
    request_id: String,
    operation: String,
    description: String,
    severity: ApprovalSeverity,
    requester_agent: String,
    timestamp: Int,
  )
}

pub type ApprovalSeverity {
  Critical
  High
  Medium
  Low
}

pub type ApprovalDecision {
  Approved
  Rejected
  Escalated
  Pending
}

pub type ApprovalState {
  ApprovalState(
    pending_requests: List(ApprovalRequest),
    history: List(#(String, ApprovalDecision)),
  )
}

/// Constitutional check result (Psi invariants).
pub type PsiCheck {
  PsiCheck(invariant: PsiInvariant, status: CheckStatus, evidence: String)
}

pub type PsiInvariant {
  Psi0Existence
  Psi1Regeneration
  Psi2History
  Psi3Verification
  Psi4HumanAlignment
  Psi5Truthfulness
}

pub type CheckStatus {
  Pass
  Fail
  Warning
  NotChecked
}

/// Emergency stop state.
pub type EmergencyState {
  EmergencyState(
    armed: Bool,
    triggered: Bool,
    trigger_reason: Option(String),
    last_triggered: Option(Int),
  )
}

pub fn initial_approval_state() -> ApprovalState {
  ApprovalState(pending_requests: [], history: [])
}

pub fn add_request(
  state: ApprovalState,
  req: ApprovalRequest,
) -> ApprovalState {
  ApprovalState(..state, pending_requests: [req, ..state.pending_requests])
}

pub fn resolve_request(
  state: ApprovalState,
  request_id: String,
  decision: ApprovalDecision,
) -> ApprovalState {
  let remaining =
    list.filter(state.pending_requests, fn(r) { r.request_id != request_id })
  ApprovalState(
    pending_requests: remaining,
    history: [#(request_id, decision), ..state.history],
  )
}

pub fn pending_count(state: ApprovalState) -> Int {
  list.length(state.pending_requests)
}

pub fn initial_emergency_state() -> EmergencyState {
  EmergencyState(
    armed: False,
    triggered: False,
    trigger_reason: None,
    last_triggered: None,
  )
}

pub fn arm_emergency(state: EmergencyState) -> EmergencyState {
  EmergencyState(..state, armed: True)
}

pub fn trigger_emergency(
  state: EmergencyState,
  reason: String,
  timestamp: Int,
) -> EmergencyState {
  EmergencyState(
    ..state,
    armed: False,
    triggered: True,
    trigger_reason: Some(reason),
    last_triggered: Some(timestamp),
  )
}

pub fn reset_emergency(state: EmergencyState) -> EmergencyState {
  EmergencyState(
    ..state,
    armed: False,
    triggered: False,
    trigger_reason: None,
  )
}

pub fn all_psi_pass(checks: List(PsiCheck)) -> Bool {
  list.all(checks, fn(c) { c.status == Pass })
}

pub fn psi_invariant_to_string(inv: PsiInvariant) -> String {
  case inv {
    Psi0Existence -> "Psi-0 Existence"
    Psi1Regeneration -> "Psi-1 Regeneration"
    Psi2History -> "Psi-2 History"
    Psi3Verification -> "Psi-3 Verification"
    Psi4HumanAlignment -> "Psi-4 Human Alignment"
    Psi5Truthfulness -> "Psi-5 Truthfulness"
  }
}

pub fn approval_severity_to_string(severity: ApprovalSeverity) -> String {
  case severity {
    Critical -> "critical"
    High -> "high"
    Medium -> "medium"
    Low -> "low"
  }
}

pub fn approval_to_json(req: ApprovalRequest) -> json.Json {
  json.object([
    #("request_id", json.string(req.request_id)),
    #("operation", json.string(req.operation)),
    #("description", json.string(req.description)),
    #("severity", json.string(approval_severity_to_string(req.severity))),
    #("requester_agent", json.string(req.requester_agent)),
    #("timestamp", json.int(req.timestamp)),
  ])
}
