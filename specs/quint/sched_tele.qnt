// sched_tele.qnt — Quint mirror of specs/tla/SchedTele.tla (SC-SCHED-TELE-001..005)
//
// Typecheck: quint typecheck specs/quint/sched_tele.qnt
// Run:       quint run --max-steps 200 --invariant inv_all specs/quint/sched_tele.qnt
// Verify:    quint verify --invariant inv_all specs/quint/sched_tele.qnt
//
// Note: `inv_all` is the safety-only invariant. `doc_process_bounded` is a
// liveness property that requires weak-fairness and is verified in TLA+.

module sched_tele {
  pure val MaxJobs: int = 2
  pure val MaxAttempts: int = 2
  pure val TelemetryBufCap: int = 4
  pure val TimeoutTicks: int = 4

  type JobState =
      Available | Executing | Retryable
    | Completed | Discarded | Cancelled

  type ProcState = Idle | Running | TimingOut | Killed | ExitedOk | ExitedErr

  var job_state: int -> JobState
  var attempt: int -> int
  var run_id: int -> int
  var proc_state: int -> ProcState
  var proc_started_at: int -> int
  var tele_len: int
  var tele_dropped: int
  var zenoh_up: bool
  var clock: int

  pure def jobs: Set[int] = 1.to(MaxJobs)

  action init = all {
    job_state'       = jobs.mapBy(_ => Available),
    attempt'         = jobs.mapBy(_ => 0),
    run_id'          = jobs.mapBy(_ => 0),
    proc_state'      = jobs.mapBy(_ => Idle),
    proc_started_at' = jobs.mapBy(_ => 0),
    tele_len'        = 0,
    tele_dropped'    = 0,
    zenoh_up'        = true,
    clock'           = 0,
  }

  action publish_claim(j: int): bool = all {
    job_state.get(j) == Available,
    attempt.get(j) < MaxAttempts,
    job_state'       = job_state.set(j, Executing),
    attempt'         = attempt.set(j, attempt.get(j) + 1),
    run_id'          = run_id.set(j, j),
    proc_state'      = proc_state.set(j, Running),
    proc_started_at' = proc_started_at.set(j, clock),
    tele_len'        = if (tele_len < TelemetryBufCap) tele_len + 1 else tele_len,
    tele_dropped'    = if (tele_len < TelemetryBufCap) tele_dropped else tele_dropped + 1,
    zenoh_up'        = zenoh_up,
    clock'           = clock,
  }

  action exit_ok(j: int): bool = all {
    proc_state.get(j) == Running,
    job_state.get(j) == Executing,
    proc_state'      = proc_state.set(j, ExitedOk),
    job_state'       = job_state.set(j, Completed),
    attempt'         = attempt,
    run_id'          = run_id,
    proc_started_at' = proc_started_at,
    tele_len'        = if (tele_len < TelemetryBufCap) tele_len + 1 else tele_len,
    tele_dropped'    = if (tele_len < TelemetryBufCap) tele_dropped else tele_dropped + 1,
    zenoh_up'        = zenoh_up,
    clock'           = clock,
  }

  action exit_err(j: int): bool = all {
    proc_state.get(j) == Running,
    job_state.get(j) == Executing,
    proc_state'      = proc_state.set(j, ExitedErr),
    job_state'       = if (attempt.get(j) < MaxAttempts)
                         job_state.set(j, Retryable)
                       else
                         job_state.set(j, Discarded),
    attempt'         = attempt,
    run_id'          = run_id,
    proc_started_at' = proc_started_at,
    tele_len'        = if (tele_len < TelemetryBufCap) tele_len + 1 else tele_len,
    tele_dropped'    = if (tele_len < TelemetryBufCap) tele_dropped else tele_dropped + 1,
    zenoh_up'        = zenoh_up,
    clock'           = clock,
  }

  action timeout_finalize(j: int): bool = all {
    proc_state.get(j) == Running,
    clock - proc_started_at.get(j) >= TimeoutTicks,
    proc_state'      = proc_state.set(j, Killed),
    job_state'       = if (attempt.get(j) < MaxAttempts)
                         job_state.set(j, Retryable)
                       else
                         job_state.set(j, Discarded),
    attempt'         = attempt,
    run_id'          = run_id,
    proc_started_at' = proc_started_at,
    tele_len'        = if (tele_len < TelemetryBufCap) tele_len + 1 else tele_len,
    tele_dropped'    = if (tele_len < TelemetryBufCap) tele_dropped else tele_dropped + 1,
    zenoh_up'        = zenoh_up,
    clock'           = clock,
  }

  action retry_promote(j: int): bool = all {
    job_state.get(j) == Retryable,
    job_state'       = job_state.set(j, Available),
    proc_state'      = proc_state.set(j, Idle),
    run_id'          = run_id.set(j, 0),
    attempt'         = attempt,
    proc_started_at' = proc_started_at,
    tele_len'        = tele_len,
    tele_dropped'    = tele_dropped,
    zenoh_up'        = zenoh_up,
    clock'           = clock,
  }

  action cancel(j: int): bool = all {
    job_state.get(j).in(Set(Available, Executing, Retryable)),
    job_state'       = job_state.set(j, Cancelled),
    proc_state'      = if (proc_state.get(j) == Running)
                         proc_state.set(j, Killed)
                       else
                         proc_state,
    attempt'         = attempt,
    run_id'          = run_id,
    proc_started_at' = proc_started_at,
    tele_len'        = if (tele_len < TelemetryBufCap) tele_len + 1 else tele_len,
    tele_dropped'    = if (tele_len < TelemetryBufCap) tele_dropped else tele_dropped + 1,
    zenoh_up'        = zenoh_up,
    clock'           = clock,
  }

  action drain_one: bool = all {
    tele_len > 0,
    zenoh_up,
    tele_len'        = tele_len - 1,
    tele_dropped'    = tele_dropped,
    job_state'       = job_state,
    attempt'         = attempt,
    run_id'          = run_id,
    proc_state'      = proc_state,
    proc_started_at' = proc_started_at,
    zenoh_up'        = zenoh_up,
    clock'           = clock,
  }

  action tick: bool = all {
    clock'           = clock + 1,
    job_state'       = job_state,
    attempt'         = attempt,
    run_id'          = run_id,
    proc_state'      = proc_state,
    proc_started_at' = proc_started_at,
    tele_len'        = tele_len,
    tele_dropped'    = tele_dropped,
    zenoh_up'        = zenoh_up,
  }

  action step = any {
    nondet j = jobs.oneOf()
    any {
      publish_claim(j),
      exit_ok(j),
      exit_err(j),
      timeout_finalize(j),
      retry_promote(j),
      cancel(j),
    },
    drain_one,
    tick,
  }

  // ── Safety invariants (true in every reachable state) ───────────────────
  val inv_attempt_bounded: bool =
    jobs.forall(j => attempt.get(j) <= MaxAttempts)

  val inv_telemetry_bounded: bool =
    tele_len <= TelemetryBufCap

  val inv_no_dual_terminal: bool =
    jobs.forall(j =>
      not (Set(Completed, Discarded, Cancelled).contains(job_state.get(j))
           and proc_state.get(j) == Running))

  val inv_state_coherent: bool =
    jobs.forall(j => {
      val s = job_state.get(j)
      val p = proc_state.get(j)
      val r = run_id.get(j)
      and {
        s == Executing implies (Set(Running, TimingOut).contains(p) and r > 0),
        Set(Completed, Discarded, Cancelled).contains(s) implies p != Running,
        s == Retryable implies Set(Idle, ExitedErr, Killed).contains(p),
        (s == Available and p == Idle) implies r == 0,
      }
    })

  val inv_all: bool =
    inv_attempt_bounded
      and inv_telemetry_bounded
      and inv_no_dual_terminal
      and inv_state_coherent

  // ── Liveness properties (documented; checked in TLA+ under WF_vars) ─────
  //   * proc Running => eventually finalized (weak fairness on timeout/exit)
  //   * every job eventually terminal
  //   * tele_len eventually zero when zenoh_up
  val doc_process_bounded: bool =
    jobs.forall(j =>
      proc_state.get(j) != Running
      or (clock - proc_started_at.get(j)) <= (TimeoutTicks + 5))
}
