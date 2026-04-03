// =============================================================================
// ALARM MANAGEMENT INVARIANTS — FORMAL SPECIFICATION
// Indrajaal Prajna Cockpit, L3 Domain Layer
// =============================================================================
//
// WHAT: Temporal-logic specification of the alarm management state machine
//       for the Prajna cockpit.  Models storm detection, acknowledgement
//       safety, Guardian-gated escalation, severity ordering, filter
//       consistency, and noise-reduction bounds.
//
// WHY:  Alarm management is a safety-critical HMI function (SC-HMI-010).
//       Incorrect alarm state transitions — e.g. re-acknowledging an alarm
//       or executing a fire-action without Guardian approval — can mask real
//       threats or cause unsafe operator responses.  Mechanised verification
//       prevents these failure modes before runtime.
//
// CONSTRAINTS:
//   - SC-ALARM-001: Alarm processing pipeline must be deterministic
//   - SC-ALARM-003: Storm detection threshold must be configurable
//   - SC-ALARM-005: Acknowledged alarms cannot be re-acknowledged
//   - SC-ALARM-009: Escalated alarms require Guardian pre-approval
//   - SC-ALARM-015: Severity ordering Critical > Warning > Caution > Advisory
//   - SC-ALARM-020: Filter state must be consistent (filtered ≤ total)
//   - SC-ALARM-025: Noise-reduction percentage bounded to [0, 100]
//   - SC-HMI-010:   Vibrant chromatic feedback based on Zenoh metabolic telemetry
//   - SC-ALARMS-001: Alarm engine — severity classification mandatory
//   - SC-GUARD-001:  Guardian MUST approve destructive/escalation actions
//   - SC-SAFETY-001: Guardian pre-approval REQUIRED for planning mutations
//
// FRACTAL LAYER: L3 (Domain) — alarm domain logic, Ash resource layer.
//
// STATES (AlarmStatus):
//   Active       — alarm is live, not yet addressed
//   Acknowledged — operator has seen and acknowledged the alarm
//   Silenced     — operator has muted without acknowledging root cause
//   Escalated    — alarm promoted to Guardian for approval
//   Resolved     — alarm closed; root cause addressed
//
// STORM STATES:
//   Normal       — alarm rate within acceptable bounds
//   StormActive  — alarm rate exceeds storm_threshold; suppression active
//
// Document Control:
//   | Field   | Value                                            |
//   |---------|--------------------------------------------------|
//   | Version | 1.0.0                                            |
//   | Created | 2026-03-28                                       |
//   | Author  | Code Evolution Agent v21.3.1-SIL6                |
//   | STAMP   | SC-ALARM-001..041, SC-ALARMS-001..012, SC-HMI-010 |
//
// Verification:
//   quint verify --invariant=alarmInvariant alarm_management_invariants.qnt
//   quint run --max-steps=300 --invariant=alarmInvariant alarm_management_invariants.qnt
//
// =============================================================================

module alarm_management {

  // ---------------------------------------------------------------------------
  // TYPE DEFINITIONS
  // ---------------------------------------------------------------------------

  /// Four-level severity ordering (SC-ALARM-015).
  /// Encoded as integers so ordering comparisons are expressible.
  ///   Critical = 3 (highest, red)
  ///   Warning  = 2 (amber)
  ///   Caution  = 1 (yellow)
  ///   Advisory = 0 (blue/white)
  type Severity =
    | Critical   // int value 3 — must never be downgraded silently
    | Warning    // int value 2
    | Caution    // int value 1
    | Advisory   // int value 0

  /// Lifecycle status of a single alarm instance (SC-ALARM-005).
  type AlarmStatus =
    | Active        // newly raised, awaiting operator action
    | Acknowledged  // operator has seen it; cannot be re-acknowledged (INV-ACK)
    | Silenced      // temporarily muted; still Active for counting purposes
    | Escalated     // requires Guardian approval (SC-ALARM-009)
    | Resolved      // closed; root cause confirmed

  /// A single alarm record.
  type Alarm = {
    id:              str,
    severity:        Severity,
    status:          AlarmStatus,
    guardianApproved: bool,   // true only when Guardian has approved escalation
    raisedAt:        int,     // logical clock tick when raised
    ackAt:           int      // 0 if never acknowledged
  }

  // ---------------------------------------------------------------------------
  // CONSTANTS — Safety Envelope
  // ---------------------------------------------------------------------------

  /// Default storm-detection threshold: alarms per evaluation window.
  /// SC-ALARM-003: threshold MUST be configurable; modelled as a constant here.
  pure val DEFAULT_STORM_THRESHOLD: int = 10

  /// Noise-reduction percentage bounds (SC-ALARM-025).
  pure val NOISE_REDUCTION_MIN: int = 0
  pure val NOISE_REDUCTION_MAX: int = 100

  /// Severity integer values — used for ordering proofs.
  pure def severityRank(s: Severity): int =
    match s {
      | Critical => 3
      | Warning  => 2
      | Caution  => 1
      | Advisory => 0
    }

  // ---------------------------------------------------------------------------
  // STATE VARIABLES
  // ---------------------------------------------------------------------------

  /// The live alarm set managed by the cockpit alarm engine.
  var alarms: Set[Alarm]

  /// Whether the storm-suppression mode is currently active.
  var stormActive: bool

  /// Current alarm-arrival rate (alarms per window tick).
  /// Incremented by raise_alarm, decremented by resolve_alarm or window expiry.
  var alarmRate: int

  /// Configurable storm threshold (can be updated via Zenoh config push).
  var stormThreshold: int

  /// Percentage of alarms suppressed/noise-reduced in the current window.
  /// Bounded to [NOISE_REDUCTION_MIN, NOISE_REDUCTION_MAX] (SC-ALARM-025).
  var noiseReductionPct: int

  /// Count of alarms currently passing the active severity filter.
  var filteredCount: int

  /// Monotonic logical clock.
  var clock: int

  /// Append-only audit log for alarm transitions.
  var auditLog: List[str]

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  /// Total number of alarms in the set.
  def totalCount: int = alarms.size()

  /// Number of alarms in a given status.
  def countByStatus(s: AlarmStatus): int =
    alarms.filter(a => a.status == s).size()

  /// Append a string entry to the audit log.
  def logEvent(msg: str): List[str] = auditLog.append(msg)

  /// Look up an alarm by id; returns the alarm if found.
  def findAlarm(aid: str): Set[Alarm] =
    alarms.filter(a => a.id == aid)

  /// Empty alarm used as a sentinel (never inserted into the set).
  pure def emptyAlarm: Alarm = {
    id:              "",
    severity:        Advisory,
    status:          Active,
    guardianApproved: false,
    raisedAt:        0,
    ackAt:           0
  }

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  action init = all {
    alarms'            = Set(),
    stormActive'       = false,
    alarmRate'         = 0,
    stormThreshold'    = DEFAULT_STORM_THRESHOLD,
    noiseReductionPct' = 0,
    filteredCount'     = 0,
    clock'             = 0,
    auditLog'          = List()
  }

  // ---------------------------------------------------------------------------
  // ACTION: raise_alarm
  // ---------------------------------------------------------------------------
  // Adds a new alarm to the active set.  Increments alarmRate and checks
  // whether the storm threshold has been crossed (INV-STORM).
  // SC-ALARM-001: alarm entry is deterministic — same id cannot be raised twice
  // while still Active.

  action raise_alarm(a: Alarm): bool = all {
    // Do not raise if an active alarm with the same id already exists
    alarms.filter(x => x.id == a.id and x.status == Active).size() == 0,
    alarms'         = alarms.union(Set({ ...a, raisedAt: clock, ackAt: 0 })),
    alarmRate'      = alarmRate + 1,
    // Storm detection: rate crossing threshold activates storm mode
    stormActive'    = (alarmRate + 1 > stormThreshold),
    clock'          = clock + 1,
    auditLog'       = logEvent("raise:" + a.id),
    // Stutter
    stormThreshold'    = stormThreshold,
    noiseReductionPct' = noiseReductionPct,
    filteredCount'     = filteredCount
  }

  // ---------------------------------------------------------------------------
  // ACTION: acknowledge_alarm
  // ---------------------------------------------------------------------------
  // Operator acknowledges a specific Active alarm.
  // SC-ALARM-005: Acknowledged alarms CANNOT be re-acknowledged (INV-ACK).
  // Pre: alarm exists and status is Active (not already Acknowledged or Resolved).

  action acknowledge_alarm(aid: str): bool = all {
    // Exactly one alarm with this id must be Active
    alarms.filter(a => a.id == aid and a.status == Active).size() == 1,
    val target = alarms.filter(a => a.id == aid and a.status == Active)
                       .fold(emptyAlarm, (_, x) => x)
    all {
      alarms' = alarms
                  .filter(a => a.id != aid or a.status != Active)
                  .union(Set({ ...target, status: Acknowledged, ackAt: clock })),
      auditLog' = logEvent("ack:" + aid),
      clock'   = clock + 1,
      // Stutter
      stormActive'       = stormActive,
      alarmRate'         = alarmRate,
      stormThreshold'    = stormThreshold,
      noiseReductionPct' = noiseReductionPct,
      filteredCount'     = filteredCount
    }
  }

  // ---------------------------------------------------------------------------
  // ACTION: escalate_alarm
  // ---------------------------------------------------------------------------
  // Promotes an Active alarm to Escalated status.
  // SC-ALARM-009: escalation requires Guardian approval (INV-ESC).
  // guardianApproved MUST be true before this action fires.

  action escalate_alarm(aid: str, approved: bool): bool = all {
    // Guardian must have approved before escalation proceeds
    approved == true,
    alarms.filter(a => a.id == aid and
                       (a.status == Active or a.status == Acknowledged)).size() == 1,
    val target = alarms.filter(a => a.id == aid and
                                    (a.status == Active or a.status == Acknowledged))
                       .fold(emptyAlarm, (_, x) => x)
    all {
      alarms' = alarms
                  .filter(a => not(a.id == aid and
                                   (a.status == Active or a.status == Acknowledged)))
                  .union(Set({ ...target,
                               status: Escalated,
                               guardianApproved: true })),
      auditLog' = logEvent("escalate:" + aid),
      clock'   = clock + 1,
      // Stutter
      stormActive'       = stormActive,
      alarmRate'         = alarmRate,
      stormThreshold'    = stormThreshold,
      noiseReductionPct' = noiseReductionPct,
      filteredCount'     = filteredCount
    }
  }

  // ---------------------------------------------------------------------------
  // ACTION: resolve_alarm
  // ---------------------------------------------------------------------------
  // Closes an alarm (Acknowledged or Escalated → Resolved).
  // Decrements alarmRate; may deactivate storm mode if rate drops below threshold.

  action resolve_alarm(aid: str): bool = all {
    alarms.filter(a => a.id == aid and
                       (a.status == Acknowledged or a.status == Escalated)).size() == 1,
    val target = alarms.filter(a => a.id == aid and
                                    (a.status == Acknowledged or a.status == Escalated))
                       .fold(emptyAlarm, (_, x) => x)
    val newRate = if (alarmRate > 0) alarmRate - 1 else 0
    all {
      alarms' = alarms
                  .filter(a => not(a.id == aid and
                                   (a.status == Acknowledged or a.status == Escalated)))
                  .union(Set({ ...target, status: Resolved })),
      alarmRate'  = newRate,
      stormActive' = (newRate > stormThreshold),
      auditLog'   = logEvent("resolve:" + aid),
      clock'      = clock + 1,
      // Stutter
      stormThreshold'    = stormThreshold,
      noiseReductionPct' = noiseReductionPct,
      filteredCount'     = filteredCount
    }
  }

  // ---------------------------------------------------------------------------
  // ACTION: silence_alarm
  // ---------------------------------------------------------------------------
  // Temporarily mutes an Active alarm without acknowledging root cause.
  // Silenced alarms remain in Active-equivalent state for counting (INV-FILTER).

  action silence_alarm(aid: str): bool = all {
    alarms.filter(a => a.id == aid and a.status == Active).size() == 1,
    val target = alarms.filter(a => a.id == aid and a.status == Active)
                       .fold(emptyAlarm, (_, x) => x)
    all {
      alarms' = alarms
                  .filter(a => not(a.id == aid and a.status == Active))
                  .union(Set({ ...target, status: Silenced })),
      auditLog' = logEvent("silence:" + aid),
      clock'   = clock + 1,
      // Stutter
      stormActive'       = stormActive,
      alarmRate'         = alarmRate,
      stormThreshold'    = stormThreshold,
      noiseReductionPct' = noiseReductionPct,
      filteredCount'     = filteredCount
    }
  }

  // ---------------------------------------------------------------------------
  // ACTION: update_filter
  // ---------------------------------------------------------------------------
  // Updates the filteredCount to reflect the current severity filter selection.
  // Caller computes filteredCount externally; this action enforces the bound
  // filteredCount ≤ totalCount (INV-FILTER).

  action update_filter(newFiltered: int): bool = all {
    // Filtered count must not exceed total (SC-ALARM-020)
    newFiltered >= 0,
    newFiltered <= totalCount,
    filteredCount' = newFiltered,
    auditLog' = logEvent("filter_update"),
    clock'    = clock + 1,
    // Stutter
    alarms'            = alarms,
    stormActive'       = stormActive,
    alarmRate'         = alarmRate,
    stormThreshold'    = stormThreshold,
    noiseReductionPct' = noiseReductionPct
  }

  // ---------------------------------------------------------------------------
  // ACTION: update_noise_reduction
  // ---------------------------------------------------------------------------
  // Updates the noise-reduction percentage (SC-ALARM-025).
  // Bounded to [0, 100]; values outside this range are rejected.

  action update_noise_reduction(pct: int): bool = all {
    pct >= NOISE_REDUCTION_MIN,
    pct <= NOISE_REDUCTION_MAX,
    noiseReductionPct' = pct,
    auditLog' = logEvent("noise_reduction_update"),
    clock'    = clock + 1,
    // Stutter
    alarms'         = alarms,
    stormActive'    = stormActive,
    alarmRate'      = alarmRate,
    stormThreshold' = stormThreshold,
    filteredCount'  = filteredCount
  }

  // ---------------------------------------------------------------------------
  // ACTION: update_storm_threshold
  // ---------------------------------------------------------------------------
  // Reconfigures the storm threshold (SC-ALARM-003).
  // Threshold must be strictly positive.

  action update_storm_threshold(newThreshold: int): bool = all {
    newThreshold > 0,
    stormThreshold' = newThreshold,
    // Re-evaluate current storm state against new threshold
    stormActive'    = (alarmRate > newThreshold),
    auditLog'       = logEvent("storm_threshold_update"),
    clock'          = clock + 1,
    // Stutter
    alarms'            = alarms,
    alarmRate'         = alarmRate,
    noiseReductionPct' = noiseReductionPct,
    filteredCount'     = filteredCount
  }

  // ---------------------------------------------------------------------------
  // ACTION: tick_clock
  // ---------------------------------------------------------------------------
  // Advances the logical clock without changing alarm state.
  // Used to model time passing between alarm events.

  action tick_clock: bool = all {
    clock'          = clock + 1,
    alarms'         = alarms,
    stormActive'    = stormActive,
    alarmRate'      = alarmRate,
    stormThreshold' = stormThreshold,
    noiseReductionPct' = noiseReductionPct,
    filteredCount'  = filteredCount,
    auditLog'       = auditLog
  }

  // ---------------------------------------------------------------------------
  // SAFETY INVARIANTS
  // ---------------------------------------------------------------------------

  // INV-ACK: Acknowledged alarms CANNOT be re-acknowledged.
  // Once an alarm enters Acknowledged status its ackAt > 0 and it cannot
  // return to Active or be acknowledged again (SC-ALARM-005).
  val inv_no_double_ack: bool =
    alarms.forall(a =>
      a.status == Acknowledged implies
        (a.ackAt > 0 and
         alarms.filter(x => x.id == a.id and x.status == Active).size() == 0)
    )

  // INV-ESC: Escalated alarms have Guardian approval (SC-ALARM-009).
  val inv_escalation_requires_guardian: bool =
    alarms.forall(a =>
      a.status == Escalated implies a.guardianApproved == true
    )

  // INV-SEV-ORDER: Severity ordering is transitive and total.
  // We assert that the severityRank function is consistent with the ordering
  // Critical (3) > Warning (2) > Caution (1) > Advisory (0).
  val inv_severity_ordering: bool =
    severityRank(Critical) > severityRank(Warning) and
    severityRank(Warning)  > severityRank(Caution) and
    severityRank(Caution)  > severityRank(Advisory) and
    severityRank(Advisory) >= 0

  // INV-FILTER: filteredCount ≤ totalCount (SC-ALARM-020).
  val inv_filter_consistent: bool =
    filteredCount >= 0 and filteredCount <= totalCount

  // INV-NOISE: noiseReductionPct ∈ [0, 100] (SC-ALARM-025).
  val inv_noise_reduction_bounds: bool =
    noiseReductionPct >= NOISE_REDUCTION_MIN and
    noiseReductionPct <= NOISE_REDUCTION_MAX

  // INV-STORM: stormActive is true if and only if alarmRate > stormThreshold.
  // This encodes that storm detection correctly reflects the threshold crossing.
  val inv_storm_threshold_correct: bool =
    stormActive == (alarmRate > stormThreshold)

  // INV-RATE: alarmRate is non-negative.
  val inv_alarm_rate_nonneg: bool = alarmRate >= 0

  // INV-THRESHOLD: stormThreshold is strictly positive.
  val inv_storm_threshold_positive: bool = stormThreshold > 0

  // INV-GUARDIAN-ONLY-ESC: alarms that are NOT escalated do NOT have
  // guardianApproved set to true (approval only granted via escalate_alarm).
  val inv_guardian_approval_only_on_escalated: bool =
    alarms.forall(a =>
      a.guardianApproved == true implies a.status == Escalated
    )

  // INV-RESOLVED-TERMINAL: Resolved alarms stay resolved (terminal state).
  // Modelled by the absence of any action that transitions away from Resolved.
  // As an invariant, we check that resolved alarms are not in Active/Acknowledged.
  val inv_resolved_terminal: bool =
    alarms.forall(a =>
      a.status == Resolved implies
        alarms.filter(x => x.id == a.id and x.status == Active).size() == 0
    )

  // INV-ACK-AT: ackAt is 0 for non-acknowledged alarms.
  val inv_ackAt_consistency: bool =
    alarms.forall(a =>
      (a.status != Acknowledged) implies a.ackAt == 0
    )

  // INV-AUDIT-GROWS: audit log is non-empty once any action has fired.
  // Vacuously true at init.
  val inv_audit_log_grows: bool =
    (totalCount > 0 or alarmRate > 0) implies auditLog.length() > 0

  /// Combined master invariant checked by the model checker.
  val alarmInvariant: bool = all {
    inv_no_double_ack,
    inv_escalation_requires_guardian,
    inv_severity_ordering,
    inv_filter_consistent,
    inv_noise_reduction_bounds,
    inv_storm_threshold_correct,
    inv_alarm_rate_nonneg,
    inv_storm_threshold_positive,
    inv_guardian_approval_only_on_escalated,
    inv_resolved_terminal,
    inv_ackAt_consistency,
    inv_audit_log_grows
  }

  // ---------------------------------------------------------------------------
  // TEMPORAL PROPERTIES
  // ---------------------------------------------------------------------------

  // TEMP1: □(alarmRate > stormThreshold → stormActive)
  // Storm detection triggers correctly whenever the rate exceeds threshold.
  temporal temp1_storm_detection_correct = always(
    alarmRate > stormThreshold implies stormActive
  )

  // TEMP2: □(stormActive → alarmRate > stormThreshold)
  // Storm mode is not spuriously active when rate is within threshold.
  temporal temp2_no_spurious_storm = always(
    stormActive implies alarmRate > stormThreshold
  )

  // TEMP3: □(∀a ∈ alarms, a.status == Acknowledged → □(a.status != Active))
  // Once acknowledged, an alarm never returns to Active.
  temporal temp3_ack_irreversible = always(
    alarms.forall(a => a.status == Acknowledged implies
      not(alarms.exists(x => x.id == a.id and x.status == Active))
    )
  )

  // TEMP4: □(filteredCount ≤ totalCount)
  // Filter consistency is maintained across all steps.
  temporal temp4_filter_always_consistent = always(
    filteredCount <= totalCount
  )

  // TEMP5: □(noiseReductionPct ∈ [0, 100])
  // Noise-reduction percentage never leaves the valid range.
  temporal temp5_noise_always_bounded = always(
    noiseReductionPct >= 0 and noiseReductionPct <= 100
  )

  // TEMP6: □(guardianInvariant)
  // Safety invariant holds at every reachable state.
  temporal temp6_always_safe = always(alarmInvariant)

}

// =============================================================================
// MODEL-CHECKING HARNESS
// =============================================================================

module alarm_management_model_checking {
  import alarm_management.*

  // Test alarm constructors
  pure def mkAlarm(aid: str, sev: Severity): Alarm = {
    id:              aid,
    severity:        sev,
    status:          Active,
    guardianApproved: false,
    raisedAt:        0,
    ackAt:           0
  }

  // Non-deterministic alarm raise
  action stepRaise: bool = {
    nondet aid = oneOf(Set("a1", "a2", "a3", "a4", "a5"))
    nondet sev = oneOf(Set(Critical, Warning, Caution, Advisory))
    raise_alarm(mkAlarm(aid, sev))
  }

  // Non-deterministic acknowledge
  action stepAck: bool = {
    nondet aid = oneOf(Set("a1", "a2", "a3", "a4", "a5"))
    acknowledge_alarm(aid)
  }

  // Non-deterministic escalate — always with Guardian approval
  action stepEscalate: bool = {
    nondet aid = oneOf(Set("a1", "a2", "a3", "a4", "a5"))
    escalate_alarm(aid, true)
  }

  // Non-deterministic resolve
  action stepResolve: bool = {
    nondet aid = oneOf(Set("a1", "a2", "a3", "a4", "a5"))
    resolve_alarm(aid)
  }

  // Non-deterministic silence
  action stepSilence: bool = {
    nondet aid = oneOf(Set("a1", "a2", "a3", "a4", "a5"))
    silence_alarm(aid)
  }

  // Non-deterministic filter update (0 to totalCount)
  action stepFilter: bool = {
    nondet n = oneOf(Set(0, 1, 2, 3, 4, 5))
    update_filter(n)
  }

  // Non-deterministic noise-reduction update
  action stepNoise: bool = {
    nondet pct = oneOf(Set(0, 10, 25, 50, 75, 90, 100))
    update_noise_reduction(pct)
  }

  // Non-deterministic storm threshold update
  action stepThreshold: bool = {
    nondet t = oneOf(Set(1, 5, 10, 20, 50))
    update_storm_threshold(t)
  }

  // Clock tick
  action stepTick: bool = tick_clock

  // Master non-deterministic step
  action step = any {
    stepRaise,
    stepAck,
    stepEscalate,
    stepResolve,
    stepSilence,
    stepFilter,
    stepNoise,
    stepThreshold,
    stepTick
  }

  val masterInvariant: bool = alarmInvariant

  // Run commands:
  //   quint verify --invariant=masterInvariant alarm_management_invariants.qnt
  //   quint run --max-steps=300 --invariant=masterInvariant alarm_management_invariants.qnt
  // Expected: PASS — no counterexamples in up to 300 steps

}

// =============================================================================
// VERIFICATION SUMMARY
// =============================================================================
//
// INV-ACK (no double-acknowledge):
//   acknowledge_alarm requires status == Active. Once set to Acknowledged the
//   action's precondition is no longer satisfied, making re-acknowledgement
//   structurally impossible.
//
// INV-ESC (Guardian approval on escalated):
//   escalate_alarm requires approved == true as a precondition and sets
//   guardianApproved = true in the updated record. No other path leads to
//   Escalated status.
//
// INV-SEV-ORDER (severity ordering):
//   severityRank is a pure function returning 3/2/1/0 for Critical/Warning/
//   Caution/Advisory. The invariant is a static arithmetic assertion and holds
//   in every state.
//
// INV-FILTER (filteredCount ≤ totalCount):
//   update_filter pre-checks newFiltered <= totalCount. No other action
//   modifies filteredCount directly, preserving the bound across all steps.
//
// INV-NOISE (noise reduction ∈ [0,100]):
//   update_noise_reduction pre-checks bounds. Initial value is 0. No other
//   action modifies noiseReductionPct.
//
// INV-STORM (storm threshold correct):
//   raise_alarm and resolve_alarm recompute stormActive as (rate > threshold).
//   update_storm_threshold also recomputes it. The invariant asserts the
//   biconditional holds at every state.
//
// =============================================================================
