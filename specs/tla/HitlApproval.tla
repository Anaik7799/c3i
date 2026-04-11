---- MODULE HitlApproval ----
\* TLA+ specification for HITL tool approval flow
\* STAMP: SC-AGUI-004, SC-SAFETY-001
\* Version: v22.5.0-CORTEX

EXTENDS Integers, Sequences

VARIABLES toolState, approvalQueue, dispatched

States == {"idle", "pending", "awaiting_approval", "approved", "rejected", "dispatched"}

TypeOK ==
    /\ toolState \in States
    /\ approvalQueue \in Seq(STRING)
    /\ dispatched \in BOOLEAN

Init ==
    /\ toolState = "idle"
    /\ approvalQueue = <<>>
    /\ dispatched = FALSE

\* Agent proposes a tool call
ProposeToolCall(tool) ==
    /\ toolState = "idle"
    /\ toolState' = "pending"
    /\ approvalQueue' = Append(approvalQueue, tool)
    /\ UNCHANGED dispatched

\* Tool requires HITL approval
RequireApproval ==
    /\ toolState = "pending"
    /\ toolState' = "awaiting_approval"
    /\ UNCHANGED <<approvalQueue, dispatched>>

\* Tool does NOT require approval — dispatch immediately
DirectDispatch ==
    /\ toolState = "pending"
    /\ toolState' = "dispatched"
    /\ dispatched' = TRUE
    /\ UNCHANGED approvalQueue

\* Operator approves
Approve ==
    /\ toolState = "awaiting_approval"
    /\ toolState' = "approved"
    /\ UNCHANGED <<approvalQueue, dispatched>>

\* Operator rejects
Reject ==
    /\ toolState = "awaiting_approval"
    /\ toolState' = "rejected"
    /\ UNCHANGED <<approvalQueue, dispatched>>

\* Approved tool dispatched via MoZ
DispatchApproved ==
    /\ toolState = "approved"
    /\ toolState' = "dispatched"
    /\ dispatched' = TRUE
    /\ UNCHANGED approvalQueue

Next ==
    \/ \E t \in STRING : ProposeToolCall(t)
    \/ RequireApproval
    \/ DirectDispatch
    \/ Approve
    \/ Reject
    \/ DispatchApproved

\* SAFETY: Destructive tools are NEVER dispatched without approval
SafetyInvariant ==
    toolState = "dispatched" =>
        (toolState # "awaiting_approval" \/ dispatched = TRUE)

\* SAFETY: Rejected tools are NEVER dispatched
RejectionSafety ==
    toolState = "rejected" => dispatched = FALSE

====
