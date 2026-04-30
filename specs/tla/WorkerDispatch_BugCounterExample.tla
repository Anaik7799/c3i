------------------ MODULE WorkerDispatch_BugCounterExample ------------------
(***************************************************************************)
(* Sister spec to WorkerDispatch.tla that REMOVES the Pass-10 fix from     *)
(* Init, modelling the pre-Pass-10 broken state in which `gleam_run` was   *)
(* registered at the legacy scheduler.rs site but NOT at the authoritative *)
(* workers.rs site (and NOT in knownWorkers).                              *)
(*                                                                         *)
(* Running TLC on this spec with the same invariants as WorkerDispatch.cfg *)
(* MUST produce a counter-example: the very first state already violates  *)
(* DispatcherRegistryConsistency, because                                  *)
(*   "gleam_run" \in matchArms["scheduler_rs"]                              *)
(*   "gleam_run" \notin matchArms["workers_rs"]                             *)
(*   "gleam_run" \notin knownWorkers                                        *)
(*                                                                         *)
(* Additionally, the action  Enqueue("gleam_run", "workers_rs")            *)
(* yields outcomes[i] = "unknown" — the exact symptom of the 5 production  *)
(* job failures fixed in commit 106862017d.                                *)
(*                                                                         *)
(* Re-uses every operator from WorkerDispatch.tla EXCEPT Init, which is    *)
(* re-defined here. The original spec is INSTANCEd to bring the action     *)
(* operators (Enqueue, RegisterWorker, AddMatchArm), invariants, and       *)
(* TypeOK into scope without duplication.                                  *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS Workers, DispatchSites, MaxJobs

VARIABLES knownWorkers, matchArms, enqueued, outcomes

vars == <<knownWorkers, matchArms, enqueued, outcomes>>

\* Bring in operators from the canonical spec.
Original == INSTANCE WorkerDispatch
            WITH Workers       <- Workers,
                 DispatchSites <- DispatchSites,
                 MaxJobs       <- MaxJobs,
                 knownWorkers  <- knownWorkers,
                 matchArms     <- matchArms,
                 enqueued      <- enqueued,
                 outcomes      <- outcomes

TypeOK                         == Original!TypeOK
Enqueue(w, s)                  == Original!Enqueue(w, s)
RegisterWorker(w)              == Original!RegisterWorker(w)
AddMatchArm(w, s)              == Original!AddMatchArm(w, s)
DispatcherRegistryConsistency  == Original!DispatcherRegistryConsistency
DispatcherSingularity          == Original!DispatcherSingularity
NoUnknownWorkerSucceeds        == Original!NoUnknownWorkerSucceeds

----------------------------------------------------------------------------
\* PRE-PASS-10 BROKEN INITIAL STATE.
\*
\*   knownWorkers does NOT contain "gleam_run".
\*   matchArms["workers_rs"] does NOT contain "gleam_run".
\*   matchArms["scheduler_rs"] DOES contain "gleam_run" (legacy workflow).
\*
\* This is exactly the configuration in workers.rs prior to commit
\* 106862017d (Pass 10 fix).
Init ==
    /\ knownWorkers = Workers \ {"gleam_run"}
    /\ matchArms    = [s \in DispatchSites |->
                          IF s = "scheduler_rs" THEN Workers
                          ELSE Workers \ {"gleam_run"}]
    /\ enqueued     = << >>
    /\ outcomes     = << >>

Next ==
    \/ \E w \in Workers, s \in DispatchSites : Enqueue(w, s)
    \/ \E w \in Workers : RegisterWorker(w)
    \/ \E w \in Workers, s \in DispatchSites : AddMatchArm(w, s)

Spec == Init /\ [][Next]_vars

----------------------------------------------------------------------------
\* EXPECTED COUNTER-EXAMPLE TRACE (TLC will produce one of these):
\*
\*   State 0 (Init):
\*     knownWorkers = {"a","b","c"}                    \* gleam_run missing
\*     matchArms["workers_rs"]   = {"a","b","c"}        \* gleam_run missing
\*     matchArms["scheduler_rs"] = {"a","b","c","gleam_run"}
\*     enqueued = << >>, outcomes = << >>
\*
\*   Invariant DispatcherRegistryConsistency violated immediately:
\*     "gleam_run" \in matchArms["scheduler_rs"]  but NOT a "workers_rs" arm
\*     and NOT in knownWorkers — yet a job posted with worker="gleam_run"
\*     to oban.rs:794 routes through workers_rs and falls through to the
\*     "unknown worker" arm.
\*
\*   If TLC is asked to ignore the static violation and run forward:
\*     State 1 (after Enqueue("gleam_run", "workers_rs")):
\*       enqueued = << <<"gleam_run","workers_rs">> >>
\*       outcomes = << "unknown" >>
\*     Invariant NoUnknownWorkerSucceeds is technically NOT violated
\*     (outcome is "unknown", not "completed"), but the OPERATIONAL
\*     pre-condition "every queued job has a chance to complete" is
\*     broken — exactly the production symptom.
============================================================================
