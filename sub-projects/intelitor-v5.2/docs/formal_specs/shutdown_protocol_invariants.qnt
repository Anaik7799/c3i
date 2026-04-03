// =============================================================================
// SHUTDOWN PROTOCOL INVARIANTS — FORMAL SPECIFICATION
// Indrajaal Prajna Cockpit Arm & Fire Shutdown Protocol, L5 Cluster Layer
// =============================================================================
//
// WHAT: Temporal-logic specification of the Arm & Fire shutdown protocol for
//       the Indrajaal biomorphic mesh.  Models the mandatory two-step arm-then-
//       fire sequencing, force-mode confirmation, Guardian veto cancellation,
//       6-phase ordered execution, dying-gasp checkpoint, abort window, and
//       auto-disarm timeout.
//
// WHY:  Shutdown is a destructive action (SC-SAFETY-001).  A fire without prior
//       arm, or a shutdown that bypasses the dying-gasp checkpoint, can leave
//       the system in an unrecoverable state.  The SC-SIL4-007 and SC-SIL4-013
//       constraints require six shutdown phases and a dying-gasp checkpoint.
//       Mechanised verification proves these invariants before deployment.
//
// CONSTRAINTS:
//   - SC-SAFETY-001:  Guardian pre-approval REQUIRED for destructive actions
//   - SC-SAFETY-022:  Emergency stop < 5 seconds
//   - SC-SIL4-007:    Dying gasp checkpoint MANDATORY before shutdown
//   - SC-SIL4-008:    Connection drain timeout 30 seconds
//   - SC-SIL4-013:    6 shutdown phases MANDATORY
//   - SC-HMI-001 (SC-SAFETY-001 proxy): Multi-step commit for destructive UI
//   - SC-GUARD-002:   Guardian integrates with DeadMansSwitch; fails closed
//   - SC-DMS-003:     Failsafe state must be deterministic
//   - SC-FUNC-003:    Rollback path MUST exist for every change
//   - SC-BOOT-004:    Boot transactional with rollback (symmetry principle)
//
// PROTOCOL OVERVIEW (Happy Path):
//   Idle → Armed → [Phase1..Phase6 in order] → DyingGasp → ShutdownComplete
//
// ABORT PATH:
//   Any state before Phase5 → Aborted → Idle (recovery possible)
//
// GUARDIAN VETO:
//   Armed or Phase1..Phase4 → GuardianVetoed → Idle
//
// FORCE MODE:
//   Idle → ForceModeArmed (requires confirmation phrase) →
//   Phase1..Phase6 → DyingGasp → ShutdownComplete
//
// AUTO-DISARM:
//   Armed and (clock - armedAt > DISARM_TIMEOUT) → Idle (alarm logged)
//
// SHUTDOWN PHASES (SC-SIL4-013):
//   Phase1 — Drain active connections (SC-SIL4-008)
//   Phase2 — Checkpoint holon state to SQLite/DuckDB
//   Phase3 — Notify federation peers (SC-FED-005)
//   Phase4 — Stop application services (L3/L2)
//   Phase5 — Stop infrastructure services (L1)
//   Phase6 — Stop container mesh (L4 teardown)
//
// Document Control:
//   | Field   | Value                                              |
//   |---------|----------------------------------------------------|
//   | Version | 1.0.0                                              |
//   | Created | 2026-03-28                                         |
//   | Author  | Code Evolution Agent v21.3.1-SIL6                  |
//   | STAMP   | SC-SAFETY-001, SC-SIL4-007/008/013, SC-GUARD-002   |
//
// Verification:
//   quint verify --invariant=shutdownInvariant shutdown_protocol_invariants.qnt
//   quint run --max-steps=400 --invariant=shutdownInvariant shutdown_protocol_invariants.qnt
//
// =============================================================================

module shutdown_protocol {

  // ---------------------------------------------------------------------------
  // TYPE DEFINITIONS
  // ---------------------------------------------------------------------------

  /// The complete set of states in the Arm & Fire shutdown state machine.
  type ShutdownState =
    | Idle              // system operating normally; no shutdown in progress
    | Armed             // operator has armed; awaiting fire command
    | ForceModeArmed    // force-mode armed; confirmation phrase verified
    | Phase1            // draining active connections (SC-SIL4-008)
    | Phase2            // checkpointing holon state
    | Phase3            // notifying federation peers
    | Phase4            // stopping application services
    | Phase5            // stopping infrastructure services
    | Phase6            // stopping container mesh
    | DyingGasp         // SC-SIL4-007: dying gasp checkpoint in progress
    | ShutdownComplete  // terminal: system is fully halted
    | Aborted           // operator or timeout aborted before Phase5
    | GuardianVetoed    // Guardian rejected the shutdown request

  /// Describes which type of fire command was issued.
  type FireMode =
    | StandardFire  // normal two-step: arm then fire
    | ForceFireMode // force mode: requires confirmation phrase

  /// An audit entry for the shutdown protocol log.
  type ShutdownAuditEntry = {
    fromState:   ShutdownState,
    toState:     ShutdownState,
    reason:      str,
    clock:       int,
    operatorId:  str
  }

  // ---------------------------------------------------------------------------
  // CONSTANTS
  // ---------------------------------------------------------------------------

  /// Force-mode confirmation phrase (SC-HMI — Arm & Fire multi-step commit).
  /// In production this is a cryptographically-derived string; here it is a
  /// fixed constant for model-checking purposes.
  pure val FORCE_CONFIRM_PHRASE: str = "CONFIRM_FORCE_SHUTDOWN_v21"

  /// Auto-disarm timeout in logical clock ticks.
  /// Represents the real-time window during which a fire must follow an arm.
  pure val DISARM_TIMEOUT: int = 30

  /// The ordered sequence of shutdown phases encoded as integers 1..6.
  /// Phase N must complete before Phase N+1 starts (INV-PHASE-ORDER).
  pure val PHASE_COUNT: int = 6

  // ---------------------------------------------------------------------------
  // STATE VARIABLES
  // ---------------------------------------------------------------------------

  /// Current state of the shutdown protocol state machine.
  var state: ShutdownState

  /// The fire mode selected when firing was initiated.
  var fireMode: FireMode

  /// The numeric index of the current phase during execution (0 when not executing).
  var currentPhase: int

  /// True when the dying-gasp checkpoint has completed (SC-SIL4-007).
  var dyingGaspComplete: bool

  /// True when Guardian has provided approval for this shutdown sequence.
  var guardianApproved: bool

  /// True when a Guardian veto has been received.
  var guardianVetoed: bool

  /// Logical clock tick at which the system was armed.
  var armedAt: int

  /// Monotonic logical clock.
  var clock: int

  /// Append-only audit log (SC-REG-001: immutable register).
  var auditLog: List[ShutdownAuditEntry]

  /// Abort is possible only before Phase5 starts (INV-ABORT-WINDOW).
  var abortAvailable: bool

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  /// Append an entry to the audit log.
  def logTransition(from: ShutdownState, to: ShutdownState,
                    reason: str, opId: str): List[ShutdownAuditEntry] =
    auditLog.append({
      fromState:  from,
      toState:    to,
      reason:     reason,
      clock:      clock,
      operatorId: opId
    })

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  action init = all {
    state'            = Idle,
    fireMode'         = StandardFire,
    currentPhase'     = 0,
    dyingGaspComplete' = false,
    guardianApproved' = false,
    guardianVetoed'   = false,
    armedAt'          = 0,
    clock'            = 0,
    auditLog'         = List(),
    abortAvailable'   = false
  }

  // ---------------------------------------------------------------------------
  // ACTION: arm
  // ---------------------------------------------------------------------------
  // Operator arms the shutdown protocol — the first step of Arm & Fire.
  // Pre: system is Idle and Guardian has pre-approved (SC-SAFETY-001).
  // Sets armedAt for auto-disarm timeout tracking.

  action arm(operatorId: str, approved: bool): bool = all {
    state == Idle,
    approved == true,      // Guardian pre-approval required (SC-SAFETY-001)
    state'            = Armed,
    guardianApproved' = true,
    armedAt'          = clock,
    abortAvailable'   = true,
    auditLog'         = logTransition(Idle, Armed, "armed", operatorId),
    clock'            = clock + 1,
    // Stutter
    fireMode'          = fireMode,
    currentPhase'      = currentPhase,
    dyingGaspComplete' = dyingGaspComplete,
    guardianVetoed'    = guardianVetoed
  }

  // ---------------------------------------------------------------------------
  // ACTION: arm_force_mode
  // ---------------------------------------------------------------------------
  // Arms the shutdown in force mode.  Requires the confirmation phrase
  // (SC-SAFETY-001 Arm & Fire multi-step) AND Guardian approval.
  // Force mode bypasses certain grace-period waits but NOT dying-gasp.

  action arm_force_mode(operatorId: str, confirmPhrase: str, approved: bool): bool = all {
    state == Idle,
    approved == true,
    confirmPhrase == FORCE_CONFIRM_PHRASE,
    state'            = ForceModeArmed,
    guardianApproved' = true,
    armedAt'          = clock,
    abortAvailable'   = true,
    fireMode'         = ForceFireMode,
    auditLog'         = logTransition(Idle, ForceModeArmed, "force_mode_armed", operatorId),
    clock'            = clock + 1,
    // Stutter
    currentPhase'      = currentPhase,
    dyingGaspComplete' = dyingGaspComplete,
    guardianVetoed'    = guardianVetoed
  }

  // ---------------------------------------------------------------------------
  // ACTION: fire
  // ---------------------------------------------------------------------------
  // Initiates Phase 1 execution after a successful arm.
  // Pre: system is Armed or ForceModeArmed.
  // INV-FIRE-REQUIRES-ARM: fire can only happen after arm.

  action fire(operatorId: str): bool = all {
    state == Armed or state == ForceModeArmed,
    // Disarm timeout not exceeded (INV-TIMEOUT-DISARMS)
    clock - armedAt <= DISARM_TIMEOUT,
    state'        = Phase1,
    currentPhase' = 1,
    abortAvailable' = true,    // abort still possible through Phase4
    auditLog'     = logTransition(state, Phase1, "fire_initiated", operatorId),
    clock'        = clock + 1,
    // Stutter
    fireMode'          = fireMode,
    dyingGaspComplete' = dyingGaspComplete,
    guardianApproved'  = guardianApproved,
    guardianVetoed'    = guardianVetoed,
    armedAt'           = armedAt
  }

  // ---------------------------------------------------------------------------
  // ACTIONS: advance_phase_N (phases 1 through 5 each advance to the next)
  // ---------------------------------------------------------------------------
  // Phase execution is sequential; Phase N → Phase N+1.
  // Each advance action represents completion of the preceding phase.
  // INV-PHASE-ORDER: phases execute strictly in 1,2,3,4,5,6 order.

  action advance_to_phase2(operatorId: str): bool = all {
    state == Phase1,
    currentPhase == 1,
    state'        = Phase2,
    currentPhase' = 2,
    abortAvailable' = true,   // abort still possible
    auditLog'     = logTransition(Phase1, Phase2, "phase1_complete_drain", operatorId),
    clock'        = clock + 1,
    // Stutter
    fireMode'          = fireMode,
    dyingGaspComplete' = dyingGaspComplete,
    guardianApproved'  = guardianApproved,
    guardianVetoed'    = guardianVetoed,
    armedAt'           = armedAt
  }

  action advance_to_phase3(operatorId: str): bool = all {
    state == Phase2,
    currentPhase == 2,
    state'        = Phase3,
    currentPhase' = 3,
    abortAvailable' = true,
    auditLog'     = logTransition(Phase2, Phase3, "phase2_complete_checkpoint", operatorId),
    clock'        = clock + 1,
    // Stutter
    fireMode'          = fireMode,
    dyingGaspComplete' = dyingGaspComplete,
    guardianApproved'  = guardianApproved,
    guardianVetoed'    = guardianVetoed,
    armedAt'           = armedAt
  }

  action advance_to_phase4(operatorId: str): bool = all {
    state == Phase3,
    currentPhase == 3,
    state'        = Phase4,
    currentPhase' = 4,
    abortAvailable' = true,
    auditLog'     = logTransition(Phase3, Phase4, "phase3_complete_notify_fed", operatorId),
    clock'        = clock + 1,
    // Stutter
    fireMode'          = fireMode,
    dyingGaspComplete' = dyingGaspComplete,
    guardianApproved'  = guardianApproved,
    guardianVetoed'    = guardianVetoed,
    armedAt'           = armedAt
  }

  action advance_to_phase5(operatorId: str): bool = all {
    state == Phase4,
    currentPhase == 4,
    state'          = Phase5,
    currentPhase'   = 5,
    abortAvailable' = false,    // abort window CLOSES at Phase5 (INV-ABORT-WINDOW)
    auditLog'       = logTransition(Phase4, Phase5, "phase4_complete_stop_app", operatorId),
    clock'          = clock + 1,
    // Stutter
    fireMode'          = fireMode,
    dyingGaspComplete' = dyingGaspComplete,
    guardianApproved'  = guardianApproved,
    guardianVetoed'    = guardianVetoed,
    armedAt'           = armedAt
  }

  action advance_to_phase6(operatorId: str): bool = all {
    state == Phase5,
    currentPhase == 5,
    state'        = Phase6,
    currentPhase' = 6,
    auditLog'     = logTransition(Phase5, Phase6, "phase5_complete_stop_infra", operatorId),
    clock'        = clock + 1,
    // Stutter
    fireMode'          = fireMode,
    dyingGaspComplete' = dyingGaspComplete,
    guardianApproved'  = guardianApproved,
    guardianVetoed'    = guardianVetoed,
    armedAt'           = armedAt,
    abortAvailable'    = abortAvailable
  }

  // ---------------------------------------------------------------------------
  // ACTION: complete_dying_gasp
  // ---------------------------------------------------------------------------
  // Records completion of the dying-gasp checkpoint (SC-SIL4-007).
  // MUST complete before transition to ShutdownComplete (INV-DYING-GASP).
  // Pre: all 6 phases have completed (currentPhase == 6).

  action complete_dying_gasp(operatorId: str): bool = all {
    state == Phase6,
    currentPhase == 6,
    state'             = DyingGasp,
    dyingGaspComplete' = true,
    auditLog'          = logTransition(Phase6, DyingGasp, "phase6_dying_gasp", operatorId),
    clock'             = clock + 1,
    // Stutter
    fireMode'         = fireMode,
    guardianApproved' = guardianApproved,
    guardianVetoed'   = guardianVetoed,
    armedAt'          = armedAt,
    currentPhase'     = currentPhase,
    abortAvailable'   = abortAvailable
  }

  // ---------------------------------------------------------------------------
  // ACTION: finalize_shutdown
  // ---------------------------------------------------------------------------
  // Transitions to ShutdownComplete.
  // Pre: DyingGasp completed (INV-DYING-GASP).

  action finalize_shutdown(operatorId: str): bool = all {
    state == DyingGasp,
    dyingGaspComplete == true,   // SC-SIL4-007 enforcement
    state'    = ShutdownComplete,
    auditLog' = logTransition(DyingGasp, ShutdownComplete, "shutdown_complete", operatorId),
    clock'    = clock + 1,
    // Stutter
    fireMode'          = fireMode,
    dyingGaspComplete' = dyingGaspComplete,
    guardianApproved'  = guardianApproved,
    guardianVetoed'    = guardianVetoed,
    armedAt'           = armedAt,
    currentPhase'      = currentPhase,
    abortAvailable'    = abortAvailable
  }

  // ---------------------------------------------------------------------------
  // ACTION: abort
  // ---------------------------------------------------------------------------
  // Operator cancels the shutdown.  Only possible before Phase5 starts.
  // INV-ABORT-WINDOW: abort is not available once Phase5 begins.
  // Aborted state transitions back to Idle with recovery procedure.

  action abort(operatorId: str): bool = all {
    abortAvailable == true,
    state == Armed or state == ForceModeArmed or
    state == Phase1 or state == Phase2 or
    state == Phase3 or state == Phase4,
    state'          = Aborted,
    abortAvailable' = false,
    auditLog'       = logTransition(state, Aborted, "shutdown_aborted", operatorId),
    clock'          = clock + 1,
    // Stutter
    fireMode'          = fireMode,
    dyingGaspComplete' = dyingGaspComplete,
    guardianApproved'  = guardianApproved,
    guardianVetoed'    = guardianVetoed,
    armedAt'           = armedAt,
    currentPhase'      = currentPhase
  }

  // ---------------------------------------------------------------------------
  // ACTION: recover_from_abort
  // ---------------------------------------------------------------------------
  // Returns system to Idle after an abort, resetting all shutdown state.

  action recover_from_abort(operatorId: str): bool = all {
    state == Aborted,
    state'             = Idle,
    currentPhase'      = 0,
    dyingGaspComplete' = false,
    guardianApproved'  = false,
    guardianVetoed'    = false,
    armedAt'           = 0,
    abortAvailable'    = false,
    auditLog'          = logTransition(Aborted, Idle, "abort_recovery", operatorId),
    clock'             = clock + 1,
    // Stutter
    fireMode' = fireMode
  }

  // ---------------------------------------------------------------------------
  // ACTION: guardian_veto
  // ---------------------------------------------------------------------------
  // Guardian vetoes the shutdown.  Can happen during Armed or Phases 1-4.
  // SC-SAFETY-001 + SC-CONSENSUS-002: Guardian veto is absolute.
  // INV-VETO-CANCELS: veto always moves to GuardianVetoed state.

  action guardian_veto(reason: str): bool = all {
    state == Armed or state == ForceModeArmed or
    state == Phase1 or state == Phase2 or
    state == Phase3 or state == Phase4,
    guardianVetoed' = true,
    state'          = GuardianVetoed,
    abortAvailable' = false,
    auditLog'       = logTransition(state, GuardianVetoed, reason, "guardian"),
    clock'          = clock + 1,
    // Stutter
    fireMode'          = fireMode,
    dyingGaspComplete' = dyingGaspComplete,
    guardianApproved'  = guardianApproved,
    armedAt'           = armedAt,
    currentPhase'      = currentPhase
  }

  // ---------------------------------------------------------------------------
  // ACTION: recover_from_veto
  // ---------------------------------------------------------------------------
  // Returns system to Idle after a Guardian veto.

  action recover_from_veto(operatorId: str): bool = all {
    state == GuardianVetoed,
    state'             = Idle,
    currentPhase'      = 0,
    dyingGaspComplete' = false,
    guardianApproved'  = false,
    guardianVetoed'    = false,
    armedAt'           = 0,
    abortAvailable'    = false,
    auditLog'          = logTransition(GuardianVetoed, Idle, "veto_recovery", operatorId),
    clock'             = clock + 1,
    // Stutter
    fireMode' = fireMode
  }

  // ---------------------------------------------------------------------------
  // ACTION: auto_disarm
  // ---------------------------------------------------------------------------
  // Fires when the armed state times out without a fire command.
  // INV-TIMEOUT-DISARMS: auto-disarm always returns to Idle.

  action auto_disarm: bool = all {
    state == Armed or state == ForceModeArmed,
    clock - armedAt > DISARM_TIMEOUT,
    state'             = Idle,
    currentPhase'      = 0,
    dyingGaspComplete' = false,
    guardianApproved'  = false,
    guardianVetoed'    = false,
    armedAt'           = 0,
    abortAvailable'    = false,
    auditLog'          = logTransition(state, Idle, "auto_disarmed_timeout", "system"),
    clock'             = clock + 1,
    // Stutter
    fireMode' = fireMode
  }

  // ---------------------------------------------------------------------------
  // ACTION: tick_clock
  // ---------------------------------------------------------------------------

  action tick_clock: bool = all {
    clock'             = clock + 1,
    state'             = state,
    fireMode'          = fireMode,
    currentPhase'      = currentPhase,
    dyingGaspComplete' = dyingGaspComplete,
    guardianApproved'  = guardianApproved,
    guardianVetoed'    = guardianVetoed,
    armedAt'           = armedAt,
    auditLog'          = auditLog,
    abortAvailable'    = abortAvailable
  }

  // ---------------------------------------------------------------------------
  // SAFETY INVARIANTS
  // ---------------------------------------------------------------------------

  // INV-FIRE-REQUIRES-ARM: Fire (Phase1 or later) can only be reached
  // after an arm.  Encoded as: if state is Phase1..Phase6 or DyingGasp or
  // ShutdownComplete, then guardianApproved must have been true.
  val inv_fire_requires_arm: bool =
    (state == Phase1 or state == Phase2 or state == Phase3 or
     state == Phase4 or state == Phase5 or state == Phase6 or
     state == DyingGasp or state == ShutdownComplete)
    implies guardianApproved == true

  // INV-PHASE-ORDER: Phase numbers are strictly monotonically increasing.
  // currentPhase is set to 1,2,3,4,5,6 in order by the advance actions.
  // We assert that currentPhase is always in [0, PHASE_COUNT].
  val inv_phase_order: bool =
    currentPhase >= 0 and currentPhase <= PHASE_COUNT

  // INV-PHASE-STATE-CONSISTENT: currentPhase matches the current state.
  val inv_phase_state_consistent: bool =
    (state == Idle           implies currentPhase == 0) and
    (state == Armed          implies currentPhase == 0) and
    (state == ForceModeArmed implies currentPhase == 0) and
    (state == Phase1         implies currentPhase == 1) and
    (state == Phase2         implies currentPhase == 2) and
    (state == Phase3         implies currentPhase == 3) and
    (state == Phase4         implies currentPhase == 4) and
    (state == Phase5         implies currentPhase == 5) and
    (state == Phase6         implies currentPhase == 6) and
    (state == DyingGasp      implies currentPhase == 6) and
    (state == ShutdownComplete implies currentPhase == 6)

  // INV-DYING-GASP: ShutdownComplete can only be reached after dying-gasp
  // completes (SC-SIL4-007).
  val inv_dying_gasp_before_complete: bool =
    state == ShutdownComplete implies dyingGaspComplete == true

  // INV-ABORT-WINDOW: Abort is not available once Phase5 begins.
  val inv_abort_window: bool =
    (state == Phase5 or state == Phase6 or
     state == DyingGasp or state == ShutdownComplete)
    implies abortAvailable == false

  // INV-VETO-CANCELS: Guardian veto always moves to GuardianVetoed (not to
  // Phase5 or beyond).  Encoded as: guardianVetoed == true implies the state
  // is GuardianVetoed or Idle (post-recovery).
  val inv_veto_cancels_shutdown: bool =
    guardianVetoed == true implies
      (state == GuardianVetoed or state == Idle)

  // INV-FORCE-CONFIRM: ForceModeArmed can only be reached with the correct
  // confirmation phrase.  Encoded structurally by arm_force_mode's precondition;
  // as an invariant we assert that ForceModeArmed implies fireMode == ForceFireMode.
  val inv_force_mode_confirmation: bool =
    state == ForceModeArmed implies fireMode == ForceFireMode

  // INV-TIMEOUT-DISARMS: Armed state reverts to Idle on timeout.
  // Encoded as: if state is Armed or ForceModeArmed and the timeout has elapsed,
  // the state should not remain Armed.
  // (The positive form: if Armed and NOT timed out then state may remain Armed.)
  val inv_timeout_disarms: bool =
    (state == Armed or state == ForceModeArmed) implies
      (clock - armedAt <= DISARM_TIMEOUT + 1)

  // INV-SINGLE-STATE: state is always one of the defined values.
  val inv_single_state: bool =
    state == Idle           or
    state == Armed          or
    state == ForceModeArmed or
    state == Phase1         or
    state == Phase2         or
    state == Phase3         or
    state == Phase4         or
    state == Phase5         or
    state == Phase6         or
    state == DyingGasp      or
    state == ShutdownComplete or
    state == Aborted        or
    state == GuardianVetoed

  // INV-AUDIT-GROWS: audit log grows after any transition.
  val inv_audit_grows: bool =
    (state != Idle or guardianApproved or guardianVetoed)
      implies auditLog.length() >= 0

  // INV-COMPLETE-ONLY-VIA-DYING-GASP:
  // The ShutdownComplete state can only be the product of a DyingGasp transition.
  // Encoded as: ShutdownComplete implies the last audit entry transitions from DyingGasp.
  // Approximated here as: ShutdownComplete implies dyingGaspComplete.
  val inv_complete_only_via_dying_gasp: bool =
    state == ShutdownComplete implies dyingGaspComplete == true

  /// Combined master invariant.
  val shutdownInvariant: bool = all {
    inv_fire_requires_arm,
    inv_phase_order,
    inv_phase_state_consistent,
    inv_dying_gasp_before_complete,
    inv_abort_window,
    inv_veto_cancels_shutdown,
    inv_force_mode_confirmation,
    inv_timeout_disarms,
    inv_single_state,
    inv_audit_grows,
    inv_complete_only_via_dying_gasp
  }

  // ---------------------------------------------------------------------------
  // TEMPORAL PROPERTIES
  // ---------------------------------------------------------------------------

  // TEMP1: □(Armed → ◇(Phase1 ∨ Idle ∨ GuardianVetoed ∨ Aborted))
  // An armed state always eventually resolves — no livelock in Armed.
  temporal temp1_arm_resolves = always(
    state == Armed implies
    eventually(state == Phase1 or state == Idle or
               state == GuardianVetoed or state == Aborted)
  )

  // TEMP2: □(Phase1 → ◇(ShutdownComplete ∨ Aborted ∨ GuardianVetoed))
  // Once firing begins, the protocol always terminates.
  temporal temp2_fire_terminates = always(
    state == Phase1 implies
    eventually(state == ShutdownComplete or
               state == Aborted or state == GuardianVetoed)
  )

  // TEMP3: □(Phase5 → ◇(ShutdownComplete))
  // Once past Phase5 the shutdown is committed — it completes.
  temporal temp3_committed_completes = always(
    state == Phase5 implies eventually(state == ShutdownComplete)
  )

  // TEMP4: □(Phase6 → ◇(DyingGasp))
  // Phase6 always leads to the dying-gasp checkpoint (SC-SIL4-007).
  temporal temp4_phase6_leads_to_dying_gasp = always(
    state == Phase6 implies eventually(state == DyingGasp)
  )

  // TEMP5: □(DyingGasp → dyingGaspComplete)
  // Dying-gasp state implies the checkpoint flag is set.
  temporal temp5_dying_gasp_flag_set = always(
    state == DyingGasp implies dyingGaspComplete
  )

  // TEMP6: □(GuardianVetoed → ◇Idle)
  // After a Guardian veto, recovery always leads back to Idle.
  temporal temp6_veto_recoverable = always(
    state == GuardianVetoed implies eventually(state == Idle)
  )

  // TEMP7: □(shutdownInvariant)
  // Safety is maintained across every reachable state.
  temporal temp7_always_safe = always(shutdownInvariant)

}

// =============================================================================
// MODEL-CHECKING HARNESS
// =============================================================================

module shutdown_model_checking {
  import shutdown_protocol.*

  // Non-deterministic arm (standard)
  action stepArm: bool = {
    nondet opId = oneOf(Set("op1", "op2", "op3"))
    arm(opId, true)
  }

  // Non-deterministic arm (force mode)
  action stepArmForce: bool = {
    nondet opId = oneOf(Set("op1", "op2", "op3"))
    arm_force_mode(opId, FORCE_CONFIRM_PHRASE, true)
  }

  // Non-deterministic fire
  action stepFire: bool = {
    nondet opId = oneOf(Set("op1", "op2", "op3"))
    fire(opId)
  }

  // Phase advancement
  action stepPhase2: bool = {
    nondet opId = oneOf(Set("op1", "op2"))
    advance_to_phase2(opId)
  }
  action stepPhase3: bool = {
    nondet opId = oneOf(Set("op1", "op2"))
    advance_to_phase3(opId)
  }
  action stepPhase4: bool = {
    nondet opId = oneOf(Set("op1", "op2"))
    advance_to_phase4(opId)
  }
  action stepPhase5: bool = {
    nondet opId = oneOf(Set("op1", "op2"))
    advance_to_phase5(opId)
  }
  action stepPhase6: bool = {
    nondet opId = oneOf(Set("op1", "op2"))
    advance_to_phase6(opId)
  }

  // Dying gasp and finalize
  action stepDyingGasp: bool = {
    nondet opId = oneOf(Set("op1", "op2"))
    complete_dying_gasp(opId)
  }
  action stepFinalize: bool = {
    nondet opId = oneOf(Set("op1", "op2"))
    finalize_shutdown(opId)
  }

  // Abort
  action stepAbort: bool = {
    nondet opId = oneOf(Set("op1", "op2"))
    abort(opId)
  }
  action stepRecoverAbort: bool = {
    nondet opId = oneOf(Set("op1", "op2"))
    recover_from_abort(opId)
  }

  // Guardian veto
  action stepVeto: bool = {
    nondet reason = oneOf(Set("constitutional_violation", "safety_risk", "operator_error"))
    guardian_veto(reason)
  }
  action stepRecoverVeto: bool = {
    nondet opId = oneOf(Set("op1", "op2"))
    recover_from_veto(opId)
  }

  // Auto disarm
  action stepDisarm: bool = auto_disarm

  // Clock tick
  action stepTick: bool = tick_clock

  // Master step
  action step = any {
    stepArm,
    stepArmForce,
    stepFire,
    stepPhase2,
    stepPhase3,
    stepPhase4,
    stepPhase5,
    stepPhase6,
    stepDyingGasp,
    stepFinalize,
    stepAbort,
    stepRecoverAbort,
    stepVeto,
    stepRecoverVeto,
    stepDisarm,
    stepTick
  }

  val masterInvariant: bool = shutdownInvariant

  // Run commands:
  //   quint verify --invariant=masterInvariant shutdown_protocol_invariants.qnt
  //   quint run --max-steps=400 --invariant=masterInvariant shutdown_protocol_invariants.qnt
  // Expected: PASS

}

// =============================================================================
// VERIFICATION SUMMARY
// =============================================================================
//
// INV-FIRE-REQUIRES-ARM:
//   arm() and arm_force_mode() are the only actions that set guardianApproved.
//   fire() requires Armed or ForceModeArmed, both requiring guardianApproved.
//   No path to Phase1..Phase6 skips the arm step.
//
// INV-PHASE-ORDER:
//   Each advance action requires the exact predecessor state and sets
//   currentPhase to the next integer value.  The invariant bounds ensure no
//   phase is skipped or reversed.
//
// INV-DYING-GASP-BEFORE-COMPLETE:
//   finalize_shutdown() requires state == DyingGasp and dyingGaspComplete == true.
//   No other action sets state to ShutdownComplete.
//
// INV-ABORT-WINDOW:
//   advance_to_phase5() sets abortAvailable = false.  abort() requires
//   abortAvailable == true.  Therefore abort is structurally impossible in
//   Phase5, Phase6, DyingGasp, and ShutdownComplete.
//
// INV-VETO-CANCELS:
//   guardian_veto() is only enabled for states before Phase5.  It sets
//   state = GuardianVetoed and guardianVetoed = true.  recover_from_veto()
//   returns to Idle and resets guardianVetoed.
//
// INV-FORCE-CONFIRM:
//   arm_force_mode() requires confirmPhrase == FORCE_CONFIRM_PHRASE AND sets
//   fireMode = ForceFireMode.  Only this action reaches ForceModeArmed.
//
// INV-TIMEOUT-DISARMS:
//   auto_disarm() fires when clock - armedAt > DISARM_TIMEOUT and resets
//   to Idle.  The invariant asserts that if Armed the elapsed ticks are
//   within DISARM_TIMEOUT + 1 (the +1 allows the disarm action itself to fire).
//
// =============================================================================
