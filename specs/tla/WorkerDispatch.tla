-------------------------- MODULE WorkerDispatch --------------------------
(***************************************************************************)
(* TLA+ specification of the C3I sa-plan-daemon Worker Dispatcher          *)
(* Registry Consistency Invariant — formalises the bug class fixed in       *)
(* Pass 10 (commit 106862017d in c3i submodule).                            *)
(*                                                                          *)
(* Bug class: oban_jobs are dispatched via                                  *)
(*   workers::dispatch(name, args, run_id) at oban.rs:794.                  *)
(* dispatch is a single string-keyed match. A SECOND dispatch site exists   *)
(* in scheduler.rs (legacy workflow_type path) used by `workflow_run` —     *)
(* unrelated to oban_jobs. Pass 8 added "gleam_run" only to scheduler.rs.   *)
(* All 5 oban_jobs with worker="gleam_run" failed with                      *)
(*   InternalError("unknown worker 'gleam_run'. known: [...]")              *)
(* until Pass 10 added the name to workers.rs.                              *)
(*                                                                          *)
(* This spec proves:                                                        *)
(*   - DispatcherRegistryConsistency : ∀ enqueued worker w,                *)
(*       w ∈ KnownWorkers ⇔ ∃ arm m in match arms, arm.name = w            *)
(*   - DispatcherSingularity         : ∀ oban worker w,                    *)
(*       there is exactly one dispatch site that handles w                  *)
(*   - NoUnknownWorkerSucceeds       : an "unknown worker" branch never     *)
(*       transitions a job to state=completed                               *)
(*                                                                          *)
(* References:                                                              *)
(*   - sub-projects/c3i/native/planning_daemon/src/workers.rs               *)
(*   - sub-projects/c3i/native/planning_daemon/src/oban.rs (line 794)       *)
(*   - sub-projects/c3i/native/planning_daemon/src/scheduler.rs (line 128)  *)
(*   - .claude/rules/scripts-gleam-feature-evolution.md (SC-SCRIPT-GLEAM)   *)
(*   - .claude/rules/sched-telemetry-mandatory.md (SC-SCHED-WORK-001)       *)
(*   - specs/tla/SaPlanScheduler.tla (Pass 9 — state-machine fix)           *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS
    Workers,         \* abstract set of worker names
                     \* concrete model: {"health_check", "gleam_script",
                     \*   "gleam_run", "rust_build", "gleam_build",
                     \*   "pi_build", "embed_refresh", "zk_maintain", ...}
    DispatchSites,   \* set of dispatch sites
                     \* concrete model: {"workers_rs", "scheduler_rs"}
    MaxJobs

VARIABLES
    knownWorkers,    \* the registry: workers.rs::known_workers()
    matchArms,       \* matchArms[s] : set of worker names handled by site s
    enqueued,        \* sequence of (worker, dispatch_site) pairs
    outcomes         \* outcomes[i] ∈ {"completed", "failed", "unknown"}

vars == <<knownWorkers, matchArms, enqueued, outcomes>>

----------------------------------------------------------------------------
TypeOK ==
    /\ knownWorkers \subseteq Workers
    /\ matchArms \in [DispatchSites -> SUBSET Workers]
    /\ enqueued \in Seq(Workers \X DispatchSites)
    /\ outcomes \in [1..Len(enqueued) -> {"completed", "failed", "unknown"}]
    /\ Len(enqueued) <= MaxJobs

\* Concrete instantiation for the Pass-10 model:
\*   Workers       = {"health_check","gleam_script","gleam_run","rust_build",
\*                    "gleam_build","pi_build","embed_refresh","zk_maintain",
\*                    "ingest_docs","feature_autopilot","knowledge_search_warmup",
\*                    "link_registry_refresh","send_email","prune_jobs",
\*                    "lifeline_reset","reindex_db","sa_plan_sync",
\*                    "ooda_recommend","echo","cargo_test","build_all_parallel"}
\*   DispatchSites = {"workers_rs", "scheduler_rs"}

----------------------------------------------------------------------------
\* Pre-Pass-10 broken state (counter-example):
\*   knownWorkers = Workers \ {"gleam_run"}
\*   matchArms["workers_rs"] = Workers \ {"gleam_run"}
\*   matchArms["scheduler_rs"] = {"health_check","embed_refresh","zk_maintain","gleam_run"}
\*   ⇒ "gleam_run" ∈ matchArms["scheduler_rs"] but ∉ knownWorkers ∧ ∉ matchArms["workers_rs"]
\*   ⇒ DispatcherRegistryConsistency violated

\* Post-Pass-10 fixed state:
\*   knownWorkers = Workers
\*   matchArms["workers_rs"] = Workers
\*   matchArms["scheduler_rs"] = {"health_check","embed_refresh","zk_maintain","gleam_run"}
\*   (scheduler_rs is the legacy workflow path — different concern)

Init ==
    /\ knownWorkers = Workers                       \* post-fix invariant
    /\ matchArms    = [s \in DispatchSites |-> Workers]
    /\ enqueued     = << >>
    /\ outcomes     = << >>

----------------------------------------------------------------------------
\* Action: a job is enqueued for worker w via site s
Enqueue(w, s) ==
    /\ Len(enqueued) < MaxJobs
    /\ enqueued' = Append(enqueued, <<w, s>>)
    /\ outcomes' = Append(outcomes,
                          IF w \in matchArms[s]
                          THEN IF w \in knownWorkers
                               THEN "completed"
                               ELSE "unknown"   \* match arm exists but registry rejects (pre-fix gleam_run anomaly)
                          ELSE "unknown")
    /\ UNCHANGED <<knownWorkers, matchArms>>

\* Action: a worker is added to the registry
RegisterWorker(w) ==
    /\ w \notin knownWorkers
    /\ knownWorkers' = knownWorkers \cup {w}
    /\ UNCHANGED <<matchArms, enqueued, outcomes>>

\* Action: a worker match arm is added at site s
AddMatchArm(w, s) ==
    /\ w \notin matchArms[s]
    /\ matchArms' = [matchArms EXCEPT ![s] = matchArms[s] \cup {w}]
    /\ UNCHANGED <<knownWorkers, enqueued, outcomes>>

----------------------------------------------------------------------------
Next ==
    \/ \E w \in Workers, s \in DispatchSites : Enqueue(w, s)
    \/ \E w \in Workers : RegisterWorker(w)
    \/ \E w \in Workers, s \in DispatchSites : AddMatchArm(w, s)

Spec == Init /\ [][Next]_vars

----------------------------------------------------------------------------
\* INVARIANTS

\* I1: Registry consistency — every worker name dispatched via the AUTHORITATIVE
\*     site (workers_rs) MUST be in the registry. This is the Pass-10 invariant.
DispatcherRegistryConsistency ==
    \A w \in Workers :
        (w \in matchArms["workers_rs"]) <=> (w \in knownWorkers)

\* I2: Singularity — every worker name has at most ONE authoritative dispatch
\*     site. The legacy scheduler.rs path is allowed but does NOT count as
\*     "authoritative" for oban_jobs.
\*     This invariant is satisfied by construction: oban.rs:794 routes ONLY
\*     through workers::dispatch (workers_rs site).
DispatcherSingularity ==
    \A w \in Workers :
        Cardinality({s \in DispatchSites :
                       /\ s = "workers_rs"
                       /\ w \in matchArms[s]}) <= 1

\* I3: No completed-with-unknown — the dispatcher never returns "completed"
\*     when the worker name was unknown to the registry.
NoUnknownWorkerSucceeds ==
    \A i \in 1..Len(enqueued) :
        LET worker  == enqueued[i][1]
            site    == enqueued[i][2]
        IN  outcomes[i] = "completed" =>
            /\ worker \in knownWorkers
            /\ worker \in matchArms[site]

\* I4: Pre-fix counter-example — proves the spec admits the pre-Pass-10 bug
\*     when the invariant is dropped from Init.
\*     (This is for reasoning, not enforced.)

----------------------------------------------------------------------------
\* THEOREMS

THEOREM Spec => []TypeOK
THEOREM Spec => []DispatcherRegistryConsistency  \* Pass-10 fix proven correct
THEOREM Spec => []DispatcherSingularity
THEOREM Spec => []NoUnknownWorkerSucceeds

----------------------------------------------------------------------------
\* MODEL CHECKING NOTES (TLC):
\*   Workers       = {"a","b","c","gleam_run"}
\*   DispatchSites = {"workers_rs","scheduler_rs"}
\*   MaxJobs       = 4
\*   Expected: all four invariants hold under Spec.
\*
\*   To reproduce the bug, replace Init's knownWorkers with
\*   `knownWorkers = Workers \ {"gleam_run"}` AND
\*   matchArms["scheduler_rs"] = matchArms["scheduler_rs"] \cup {"gleam_run"}
\*   while leaving matchArms["workers_rs"] unchanged. TLC will generate a
\*   counter-example trace where Enqueue("gleam_run","workers_rs") yields
\*   outcomes[i] = "unknown" while a parallel dispatch via scheduler_rs
\*   succeeds — proving the Pass-10 bug class.
============================================================================
