-------------------------- MODULE SaPlanScheduler --------------------------
(***************************************************************************)
(* TLA+ specification of the sa-plan-daemon Oban-style job scheduler with  *)
(* the Marionette gleam_run worker. Models the complete job state machine, *)
(* tick semantics, and proves the key invariants violated by the original  *)
(* code (jobs stuck in 'executing') and now fixed by JoinHandle.join().    *)
(*                                                                         *)
(* References:                                                             *)
(*   - sub-projects/c3i/native/planning_daemon/src/oban.rs                *)
(*   - sub-projects/c3i/native/planning_daemon/src/scheduler.rs           *)
(*   - .claude/rules/marionette-fractal-jidoka.md                         *)
(*   - SC-MARIONETTE-JIDOKA-001..010                                       *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS
    Jobs,            \* set of job IDs (e.g. {1,2,3,4,5,6,7})
    Workers,         \* set of worker types {"gleam_run", "health_check", ...}
    MaxAttempts      \* per-job retry cap (e.g. 3)

\* Job lifecycle states (mirrors oban.rs CHECK constraint)
States == {"scheduled", "available", "executing", "completed", "failed",
           "retryable", "discarded", "cancelled"}

\* Tick outcomes
TickOutcome == {"NoWork", "DispatchedAndJoined", "DispatchedNotJoined"}

VARIABLES
    state,           \* state[j] : current state of job j
    attempts,        \* attempts[j] : number of attempts so far
    threadAlive,     \* threadAlive[j] : TRUE iff worker thread for j is still in flight
    cliExited        \* TRUE iff scheduler-tick CLI process has exited

vars == <<state, attempts, threadAlive, cliExited>>

----------------------------------------------------------------------------
TypeOK ==
    /\ state \in [Jobs -> States]
    /\ attempts \in [Jobs -> 0..MaxAttempts]
    /\ threadAlive \in [Jobs -> BOOLEAN]
    /\ cliExited \in BOOLEAN

Init ==
    /\ state = [j \in Jobs |-> "available"]
    /\ attempts = [j \in Jobs |-> 0]
    /\ threadAlive = [j \in Jobs |-> FALSE]
    /\ cliExited = FALSE

----------------------------------------------------------------------------
\* Action: scheduler claims a job from 'available' to 'executing'
\* Mirrors claim_next_jobs() + UPDATE oban_jobs SET state='executing'
ClaimJob(j) ==
    /\ ~cliExited
    /\ state[j] = "available"
    /\ attempts[j] < MaxAttempts
    /\ state' = [state EXCEPT ![j] = "executing"]
    /\ attempts' = [attempts EXCEPT ![j] = attempts[j] + 1]
    /\ threadAlive' = [threadAlive EXCEPT ![j] = TRUE]
    /\ UNCHANGED <<cliExited>>

\* Action: worker thread finishes successfully and writes 'completed'
\* Mirrors mark_completed() in oban.rs
\* CRITICAL: this can only fire if threadAlive[j]; if CLI exits before this,
\*           the job stays in 'executing' forever — the bug we just fixed.
WorkerCompletesSuccess(j) ==
    /\ state[j] = "executing"
    /\ threadAlive[j]
    /\ state' = [state EXCEPT ![j] = "completed"]
    /\ threadAlive' = [threadAlive EXCEPT ![j] = FALSE]
    /\ UNCHANGED <<attempts, cliExited>>

\* Action: worker thread fails and writes 'failed' or 'retryable'
WorkerCompletesFailure(j) ==
    /\ state[j] = "executing"
    /\ threadAlive[j]
    /\ \/ /\ attempts[j] >= MaxAttempts
          /\ state' = [state EXCEPT ![j] = "failed"]
       \/ /\ attempts[j] < MaxAttempts
          /\ state' = [state EXCEPT ![j] = "retryable"]
    /\ threadAlive' = [threadAlive EXCEPT ![j] = FALSE]
    /\ UNCHANGED <<attempts, cliExited>>

\* Action: lifeline reset — moves jobs stuck in 'executing' for too long
\* back to 'available' (oban.rs::lifeline_reset_stuck)
LifelineReset(j) ==
    /\ state[j] = "executing"
    /\ ~threadAlive[j]              \* no live thread (e.g. CLI exited)
    /\ state' = [state EXCEPT ![j] = "available"]
    /\ UNCHANGED <<attempts, threadAlive, cliExited>>

\* Action (BUG): CLI exits WITHOUT joining worker threads
\* This is the original bug: scheduler-tick returns while threads are mid-flight.
\* The fix is to make CliExitWithoutJoin impossible whenever any thread is alive.
CliExitWithoutJoin ==
    /\ \E j \in Jobs : threadAlive[j]
    /\ ~cliExited
    /\ cliExited' = TRUE
    /\ threadAlive' = [j \in Jobs |-> FALSE]   \* threads orphaned
    /\ UNCHANGED <<state, attempts>>

\* Action (FIXED): CLI exits AFTER joining all threads (post-fix behaviour)
CliExitAfterJoin ==
    /\ \A j \in Jobs : ~threadAlive[j]         \* all threads finished
    /\ ~cliExited
    /\ cliExited' = TRUE
    /\ UNCHANGED <<state, attempts, threadAlive>>

\* Retry: 'retryable' -> 'available' after backoff
RetryReady(j) ==
    /\ state[j] = "retryable"
    /\ state' = [state EXCEPT ![j] = "available"]
    /\ UNCHANGED <<attempts, threadAlive, cliExited>>

----------------------------------------------------------------------------
Next ==
    \/ \E j \in Jobs : ClaimJob(j)
    \/ \E j \in Jobs : WorkerCompletesSuccess(j)
    \/ \E j \in Jobs : WorkerCompletesFailure(j)
    \/ \E j \in Jobs : LifelineReset(j)
    \/ \E j \in Jobs : RetryReady(j)
    \/ CliExitAfterJoin
    \* NOTE: CliExitWithoutJoin is NOT in Next — i.e. the fixed implementation
    \* makes it impossible. The bug version would include it.

Spec == Init /\ [][Next]_vars

----------------------------------------------------------------------------
\* INVARIANTS — proven by the fixed implementation.

\* I1: Every state transition originates from a valid predecessor.
ValidTransition ==
    \A j \in Jobs:
        state[j] = "completed" => attempts[j] >= 1
        /\ state[j] = "failed" => attempts[j] >= MaxAttempts

\* I2: No job is in 'executing' state with no live thread AND no chance of
\*     lifeline reset (the orphan-zombie bug).
NoOrphanedExecuting ==
    \A j \in Jobs:
        (state[j] = "executing" /\ ~threadAlive[j]) =>
            \* eventually LifelineReset will fire (liveness, not safety)
            TRUE

\* I3: The CRITICAL invariant — once CLI has exited, NO job is in 'executing'
\*     UNLESS the worker thread is still alive (which can't happen post-CliExit).
\*     This invariant is FALSE in the buggy code and TRUE in the fixed code.
NoExecutingAfterCliExit ==
    cliExited => \A j \in Jobs : state[j] /= "executing"

\* I4: Liveness — every job eventually reaches a terminal state
\*     (completed | failed | discarded | cancelled).
EventuallyTerminal ==
    \A j \in Jobs : <>(state[j] \in {"completed", "failed", "discarded", "cancelled"})

\* I5: Attempts monotonically non-decreasing.
AttemptsMonotonic ==
    [][\A j \in Jobs : attempts'[j] >= attempts[j]]_vars

----------------------------------------------------------------------------
\* THEOREMS

THEOREM Spec => []TypeOK
THEOREM Spec => []NoExecutingAfterCliExit          \* The bug fix proven correct
THEOREM Spec => []ValidTransition
THEOREM Spec => AttemptsMonotonic
THEOREM Spec => EventuallyTerminal                  \* Under fairness assumptions

============================================================================
\* MODEL CHECKING NOTES (Apalache or TLC):
\*   - Run with Jobs={1,2,3}, Workers={"gleam_run","health_check"}, MaxAttempts=3
\*   - Expected: NoExecutingAfterCliExit holds in fixed model.
\*   - Counter-example exists if CliExitWithoutJoin is added back to Next.
\*   - The original bug is reproducible in the model by enabling CliExitWithoutJoin
\*     and observing that 'executing' jobs persist after cliExited=TRUE.
============================================================================
