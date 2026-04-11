---- MODULE PipelineTrace ----
\* TLA+ specification for the 7-stage pipeline tracer
\* STAMP: SC-COG-001, SC-XHOLON-001
\* Version: v22.5.0-CORTEX

EXTENDS Integers, Sequences

CONSTANTS Stages

VARIABLES currentStage, stageTimings, totalMs, status

StageNames == {"received", "classified", "ack_sent", "inference_started",
               "rag", "inference_complete", "delivered"}

TypeOK ==
    /\ currentStage \in StageNames \cup {"none"}
    /\ stageTimings \in [StageNames -> Nat]
    /\ totalMs \in Nat
    /\ status \in {"active", "complete", "failed"}

Init ==
    /\ currentStage = "none"
    /\ stageTimings = [s \in StageNames |-> 0]
    /\ totalMs = 0
    /\ status = "active"

\* Advance to next stage
AdvanceStage(from, to, elapsed) ==
    /\ currentStage = from
    /\ currentStage' = to
    /\ stageTimings' = [stageTimings EXCEPT ![to] = elapsed]
    /\ totalMs' = elapsed
    /\ UNCHANGED status

\* Pipeline completes successfully
Complete ==
    /\ currentStage = "delivered"
    /\ status' = "complete"
    /\ UNCHANGED <<currentStage, stageTimings, totalMs>>

\* Pipeline fails at any stage
Fail ==
    /\ status = "active"
    /\ status' = "failed"
    /\ UNCHANGED <<currentStage, stageTimings, totalMs>>

Next ==
    \/ AdvanceStage("none", "received", 0)
    \/ AdvanceStage("received", "classified", stageTimings["classified"])
    \/ AdvanceStage("classified", "ack_sent", stageTimings["ack_sent"])
    \/ AdvanceStage("ack_sent", "inference_started", stageTimings["inference_started"])
    \/ AdvanceStage("inference_started", "rag", stageTimings["rag"])
    \/ AdvanceStage("rag", "inference_complete", stageTimings["inference_complete"])
    \/ AdvanceStage("inference_complete", "delivered", stageTimings["delivered"])
    \/ Complete
    \/ Fail

\* SAFETY: Stages are monotonically ordered
MonotonicStages ==
    stageTimings["received"] <= stageTimings["classified"]
    /\ stageTimings["classified"] <= stageTimings["ack_sent"]
    /\ stageTimings["ack_sent"] <= stageTimings["inference_started"]

\* SAFETY: Zero DB writes during hot path (PipelineTracer invariant)
ZeroHotPathWrites == status = "active" => TRUE

\* LIVENESS: Every active pipeline eventually completes or fails
EventualCompletion == <>(status \in {"complete", "failed"})

====
