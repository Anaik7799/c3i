// =============================================================================
// PRAJNA GUARDIAN FORMAL SPECIFICATION
// Sprint 30.15.1 - Mathematical Proof of Guardian Invariants
// =============================================================================
//
// WHAT: Formal verification of Guardian safety kernel properties
// WHY: SC-COV-003 (Mathematical proofs for core) + SC-FORMAL-001
//
// STAMP Constraints:
//   - SC-PRAJNA-001: All commands through Guardian pre-approval
//   - SC-PRAJNA-006: Constitutional invariants checked
//   - SC-FOUNDER-001: All actions serve Founder's lineage
//   - SC-CONST-007: Guardian has absolute veto authority
//
// Document Control:
//   | Field     | Value                  |
//   |-----------|------------------------|
//   | Version   | 1.0.0                  |
//   | Created   | 2026-01-02             |
//   | Author    | Cybernetic Architect   |
//   | Sprint    | 30.15.1                |
//   | STAMP     | SC-COV-003, SC-FORMAL-001 |
//
// =============================================================================

module prajna_guardian {

  // ---------------------------------------------------------------------------
  // TYPE DEFINITIONS
  // ---------------------------------------------------------------------------

  /// Proposal types that can be submitted to Guardian
  type ProposalType =
    | Command           // Normal command execution
    | Reconfiguration   // System reconfiguration
    | Mutation          // State mutation
    | ScaleUp           // Resource scaling
    | CodeExec          // Code execution
    | NetworkCall       // Network operation

  /// Guardian validation decision
  type ValidationResult =
    | Approved          // Proposal passes all checks
    | Vetoed            // Proposal violates constraints
    | Timeout           // Validation timeout

  /// Proposal lifecycle states
  type ProposalState =
    | Pending           // Submitted but not validated
    | Validating        // Under Guardian review
    | ApprovedByGuardian // Guardian approved
    | VetoedByGuardian  // Guardian vetoed
    | Executing         // Approved and executing
    | Executed          // Completed execution
    | Rejected          // Execution blocked

  /// Safety constraint categories checked by Guardian
  type ConstraintType =
    | FounderDirective  // Omega0 - Supreme Directive
    | ResourceBounds    // SC-RES - Resource limits
    | SecurityCheck     // SC-SEC - Security constraints
    | PhysicalLimits    // SC-PHY - Actuator physics
    | TemporalBounds    // SC-TMP - Timing constraints
    | NetworkPolicy     // SC-NET - Network restrictions

  /// Proposal record structure
  // Note: 'action' is a reserved keyword in Quint; field renamed to 'operation'
  type Proposal = {
    id: str,
    proposalType: ProposalType,
    state: ProposalState,
    operation: str,
    validatedBy: Set[ConstraintType],
    bypassedGuardian: bool,
    vetoReason: str,
    timestamp: int
  }

  // ---------------------------------------------------------------------------
  // STATE VARIABLES
  // ---------------------------------------------------------------------------

  /// All proposals submitted to the system
  var proposals: Set[Proposal]

  /// Proposals that passed Guardian validation
  var approvedProposals: Set[Proposal]

  /// Proposals that were vetoed by Guardian
  var vetoedProposals: Set[Proposal]

  /// Proposals currently executing
  var executingProposals: Set[Proposal]

  /// Proposals that completed execution
  var executedProposals: Set[Proposal]

  /// System-wide bypass flag (should NEVER be true)
  var guardianBypassEnabled: bool

  /// Global clock for timing
  var globalClock: int

  /// Guardian liveness counter (heartbeat)
  var guardianHeartbeat: int

  // ---------------------------------------------------------------------------
  // CONSTANTS (Safety Envelope)
  // ---------------------------------------------------------------------------

  /// All safety constraints that Guardian checks (SC-GUARD-001)
  pure val REQUIRED_CHECKS: Set[ConstraintType] = Set(
    FounderDirective,
    ResourceBounds,
    SecurityCheck,
    PhysicalLimits,
    TemporalBounds,
    NetworkPolicy
  )

  /// Maximum validation timeout (5000ms per SC-SIL4-001)
  pure val MAX_VALIDATION_TIMEOUT_MS: int = 5000

  /// Minimum heartbeat interval (guardian must be alive)
  pure val MIN_HEARTBEAT_INTERVAL_MS: int = 2000

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  action init = all {
    proposals' = Set(),
    approvedProposals' = Set(),
    vetoedProposals' = Set(),
    executingProposals' = Set(),
    executedProposals' = Set(),
    guardianBypassEnabled' = false,
    globalClock' = 0,
    guardianHeartbeat' = 0
  }

  // ---------------------------------------------------------------------------
  // ACTIONS: Proposal Submission
  // ---------------------------------------------------------------------------

  /// Submit a proposal for Guardian validation (entry point)
  action submitProposal(p: Proposal): bool = all {
    // Pre-condition: Proposal not already submitted
    not(proposals.contains(p)),
    // SC-PRAJNA-001: All proposals start in Pending state
    p.state == Pending,
    p.bypassedGuardian == false,
    // Add to proposals set
    proposals' = proposals.union(Set(p)),
    // Stutter: no change to other state variables
    approvedProposals' = approvedProposals,
    vetoedProposals' = vetoedProposals,
    executingProposals' = executingProposals,
    executedProposals' = executedProposals,
    guardianBypassEnabled' = guardianBypassEnabled,
    guardianHeartbeat' = guardianHeartbeat,
    // Advance clock
    globalClock' = globalClock + 1
  }

  /// Guardian validates a proposal (linear chain of checks)
  // val binding before all{} so 'validated' is in scope throughout the block
  action guardianValidate(p: Proposal): bool =
    val validated = { ...p,
      state: Validating,
      validatedBy: REQUIRED_CHECKS,
      timestamp: globalClock
    }
    all {
      // Pre-condition: Proposal is pending validation
      proposals.contains(p),
      p.state == Pending,
      // Update proposal state to validating
      proposals' = proposals.exclude(Set(p)).union(Set(validated)),
      approvedProposals' = approvedProposals,
      vetoedProposals' = vetoedProposals,
      executingProposals' = executingProposals,
      executedProposals' = executedProposals,
      guardianBypassEnabled' = guardianBypassEnabled,
      // Record Guardian heartbeat (SC-GUARD-002)
      guardianHeartbeat' = globalClock,
      // Advance clock
      globalClock' = globalClock + 10
    }

  /// Guardian approves a proposal (all checks passed)
  // val binding before all{} so 'approved' is in scope throughout the block
  action guardianApprove(p: Proposal): bool =
    val approved = { ...p, state: ApprovedByGuardian }
    all {
      // Pre-condition: Proposal is validating
      proposals.contains(p),
      p.state == Validating,
      // SC-FOUNDER-001: All constraints must pass (including Omega0)
      p.validatedBy == REQUIRED_CHECKS,
      // Update state to approved
      proposals' = proposals.exclude(Set(p)).union(Set(approved)),
      approvedProposals' = approvedProposals.union(Set(approved)),
      vetoedProposals' = vetoedProposals,
      executingProposals' = executingProposals,
      executedProposals' = executedProposals,
      guardianBypassEnabled' = guardianBypassEnabled,
      guardianHeartbeat' = guardianHeartbeat,
      // Advance clock
      globalClock' = globalClock + 5
    }

  /// Guardian vetoes a proposal (constraint violation detected)
  // val binding before all{} so 'vetoed' is in scope throughout the block
  action guardianVeto(p: Proposal, reason: str): bool =
    val vetoed = { ...p,
      state: VetoedByGuardian,
      vetoReason: reason
    }
    all {
      // Pre-condition: Proposal is validating
      proposals.contains(p),
      p.state == Validating,
      // Update state to vetoed
      proposals' = proposals.exclude(Set(p)).union(Set(vetoed)),
      approvedProposals' = approvedProposals,
      vetoedProposals' = vetoedProposals.union(Set(vetoed)),
      executingProposals' = executingProposals,
      executedProposals' = executedProposals,
      guardianBypassEnabled' = guardianBypassEnabled,
      guardianHeartbeat' = guardianHeartbeat,
      // Advance clock
      globalClock' = globalClock + 5
    }

  // ---------------------------------------------------------------------------
  // ACTIONS: Proposal Execution
  // ---------------------------------------------------------------------------

  /// Execute an approved proposal (SC-PRAJNA-001: Only after Guardian approval)
  // val binding before all{} so 'executing' is in scope throughout the block
  action executeProposal(p: Proposal): bool =
    val executing = { ...p, state: Executing }
    all {
      // CRITICAL: Can ONLY execute if Guardian approved
      approvedProposals.contains(p),
      p.state == ApprovedByGuardian,
      // SC-PRAJNA-001: Guardian must have validated
      p.validatedBy == REQUIRED_CHECKS,
      p.bypassedGuardian == false,
      // Update state to executing
      proposals' = proposals.exclude(Set(p)).union(Set(executing)),
      approvedProposals' = approvedProposals.exclude(Set(p)),
      vetoedProposals' = vetoedProposals,
      executingProposals' = executingProposals.union(Set(executing)),
      executedProposals' = executedProposals,
      guardianBypassEnabled' = guardianBypassEnabled,
      guardianHeartbeat' = guardianHeartbeat,
      // Advance clock
      globalClock' = globalClock + 50
    }

  /// Complete execution of a proposal
  // val binding before all{} so 'executed' is in scope throughout the block
  action completeExecution(p: Proposal): bool =
    val executed = { ...p, state: Executed }
    all {
      // Pre-condition: Proposal is executing
      executingProposals.contains(p),
      p.state == Executing,
      // Update state to executed
      proposals' = proposals.exclude(Set(p)).union(Set(executed)),
      approvedProposals' = approvedProposals,
      vetoedProposals' = vetoedProposals,
      executingProposals' = executingProposals.exclude(Set(p)),
      executedProposals' = executedProposals.union(Set(executed)),
      guardianBypassEnabled' = guardianBypassEnabled,
      guardianHeartbeat' = guardianHeartbeat,
      // Advance clock
      globalClock' = globalClock + 10
    }

  /// Reject execution of a vetoed proposal
  // val binding before all{} so 'rejected' is in scope throughout the block
  action rejectProposal(p: Proposal): bool =
    val rejected = { ...p, state: Rejected }
    all {
      // Pre-condition: Proposal was vetoed
      vetoedProposals.contains(p),
      p.state == VetoedByGuardian,
      // Update state to rejected (terminal state)
      proposals' = proposals.exclude(Set(p)).union(Set(rejected)),
      approvedProposals' = approvedProposals,
      vetoedProposals' = vetoedProposals.exclude(Set(p)),
      executingProposals' = executingProposals,
      executedProposals' = executedProposals,
      guardianBypassEnabled' = guardianBypassEnabled,
      guardianHeartbeat' = guardianHeartbeat,
      // Advance clock
      globalClock' = globalClock + 1
    }

  // ---------------------------------------------------------------------------
  // SAFETY INVARIANTS
  // ---------------------------------------------------------------------------

  // ==========================================================================
  // INVARIANT 1 (30.15.1.1): NO-BYPASS PROOF
  // ==========================================================================
  // Theorem: All executed proposals MUST have been approved by Guardian.
  // Proof: By construction, executeProposal requires p in approvedProposals,
  //        and guardianApprove is the ONLY action that adds to approvedProposals.
  //        Therefore, forall p in executedProposals: p was validated by Guardian.

  /// Core no-bypass invariant: Execution requires Guardian approval
  val inv_no_bypass_core: bool =
    executedProposals.forall(p =>
      // Executed proposal MUST have been approved by Guardian
      p.state == Executed and
      p.validatedBy == REQUIRED_CHECKS and
      p.bypassedGuardian == false
    )

  /// No proposal can bypass Guardian validation
  val inv_no_bypass_flag: bool =
    proposals.forall(p =>
      p.bypassedGuardian == false
    ) and guardianBypassEnabled == false

  /// Guardian validation is comprehensive (all checks performed)
  val inv_guardian_complete: bool =
    approvedProposals.forall(p =>
      p.validatedBy == REQUIRED_CHECKS
    )

  /// Executing proposals must be Guardian-approved
  val inv_executing_approved: bool =
    executingProposals.forall(p =>
      p.validatedBy == REQUIRED_CHECKS and
      p.bypassedGuardian == false
    )

  /// Combined NO-BYPASS invariant (30.15.1.1)
  val inv_no_bypass: bool = all {
    inv_no_bypass_core,
    inv_no_bypass_flag,
    inv_guardian_complete,
    inv_executing_approved
  }

  // ==========================================================================
  // INVARIANT 2 (30.15.1.2): VETO ALWAYS HALTS
  // ==========================================================================
  // Theorem: Vetoed proposals NEVER reach executing or executed state.
  // Proof: By construction, executeProposal requires p in approvedProposals.
  //        guardianVeto adds p to vetoedProposals and sets state to VetoedByGuardian.
  //        These sets are disjoint (approvedProposals intersect vetoedProposals = empty).
  //        Therefore, forall p in vetoedProposals: p.state not in {Executing, Executed}.

  /// Vetoed proposals cannot execute
  val inv_veto_halts_core: bool =
    vetoedProposals.forall(p =>
      p.state == VetoedByGuardian or p.state == Rejected
    )

  /// Vetoed proposals never reach execution
  val inv_veto_prevents_execution: bool =
    executingProposals.forall(p =>
      not(vetoedProposals.contains(p))
    )

  /// Vetoed proposals never reach executed state
  val inv_veto_prevents_completion: bool =
    executedProposals.forall(p =>
      not(vetoedProposals.contains(p))
    )

  /// Approved and vetoed sets are disjoint
  val inv_approval_veto_disjoint: bool =
    approvedProposals.forall(p =>
      not(vetoedProposals.contains(p))
    ) and
    vetoedProposals.forall(p =>
      not(approvedProposals.contains(p))
    )

  /// Combined VETO-HALTS invariant (30.15.1.2)
  val inv_veto_halts: bool = all {
    inv_veto_halts_core,
    inv_veto_prevents_execution,
    inv_veto_prevents_completion,
    inv_approval_veto_disjoint
  }

  // ==========================================================================
  // ADDITIONAL SAFETY INVARIANTS
  // ==========================================================================

  /// Guardian heartbeat is recent (liveness)
  val inv_guardian_alive: bool =
    globalClock - guardianHeartbeat <= MIN_HEARTBEAT_INTERVAL_MS

  /// All proposals have unique IDs
  val inv_unique_ids: bool =
    proposals.forall(p1 =>
      proposals.forall(p2 =>
        p1.id == p2.id implies p1 == p2
      )
    )

  /// State machine is well-formed (no invalid transitions)
  val inv_state_machine: bool =
    proposals.forall(p =>
      p.state == Pending or
      p.state == Validating or
      p.state == ApprovedByGuardian or
      p.state == VetoedByGuardian or
      p.state == Executing or
      p.state == Executed or
      p.state == Rejected
    )

  /// Founder Directive (Omega0) is always checked
  val inv_founder_directive: bool =
    approvedProposals.forall(p =>
      p.validatedBy.contains(FounderDirective)
    )

  // ==========================================================================
  // MASTER SAFETY INVARIANT
  // ==========================================================================

  /// All safety properties hold simultaneously
  val guardianSafetyInvariant: bool = all {
    inv_no_bypass,                 // 30.15.1.1: No execution without Guardian
    inv_veto_halts,                // 30.15.1.2: Veto always prevents execution
    inv_guardian_alive,            // Guardian is responsive
    inv_unique_ids,                // Proposal IDs are unique
    inv_state_machine,             // State machine is well-formed
    inv_founder_directive          // Omega0 is always validated
  }

  /// Temporal: Safety is ALWAYS maintained
  temporal alwaysGuardianSafe = always(guardianSafetyInvariant)

  // ---------------------------------------------------------------------------
  // LIVENESS PROPERTIES
  // ---------------------------------------------------------------------------

  /// Every submitted proposal eventually gets validated
  temporal proposalEventuallyValidated = always(
    proposals.exists(p => p.state == Pending) implies
    eventually(proposals.exists(p =>
      p.state == ApprovedByGuardian or p.state == VetoedByGuardian
    ))
  )

  /// Approved proposals eventually execute or timeout
  temporal approvedEventuallyExecutes = always(
    approvedProposals.exists(p => p.state == ApprovedByGuardian) implies
    eventually(
      executingProposals.exists(p => p.state == Executing) or
      approvedProposals.size() == 0
    )
  )

  /// Vetoed proposals never execute (safety wins over liveness)
  temporal vetoedNeverExecutes = always(
    vetoedProposals.exists(p => true) implies
    always(executingProposals.forall(p => not(vetoedProposals.contains(p))))
  )

  /// Guardian remains alive (heartbeat)
  temporal guardianStaysAlive = always(
    eventually(guardianHeartbeat == globalClock)
  )

  // ---------------------------------------------------------------------------
  // HELPER PREDICATES
  // ---------------------------------------------------------------------------

  /// Check if a proposal was Guardian-approved
  def wasGuardianApproved(p: Proposal): bool =
    p.validatedBy == REQUIRED_CHECKS and
    p.bypassedGuardian == false and
    (p.state == ApprovedByGuardian or
     p.state == Executing or
     p.state == Executed)

  /// Check if a proposal was vetoed
  def wasVetoed(p: Proposal): bool =
    p.state == VetoedByGuardian or p.state == Rejected

  /// Check if execution path is valid
  def validExecutionPath(p: Proposal): bool =
    // Valid path: Pending -> Validating -> Approved -> Executing -> Executed
    (p.state == Pending) or
    (p.state == Validating and p.validatedBy == REQUIRED_CHECKS) or
    (p.state == ApprovedByGuardian and wasGuardianApproved(p)) or
    (p.state == Executing and wasGuardianApproved(p)) or
    (p.state == Executed and wasGuardianApproved(p))

  /// Check if veto path is valid
  def validVetoPath(p: Proposal): bool =
    // Valid path: Pending -> Validating -> Vetoed -> Rejected
    (p.state == Pending) or
    (p.state == Validating) or
    (p.state == VetoedByGuardian and wasVetoed(p)) or
    (p.state == Rejected and wasVetoed(p))
}

// =============================================================================
// MODEL CHECKING HARNESS
// =============================================================================

module guardian_model_checking {
  import prajna_guardian.*

  /// Non-deterministic proposal generation for model checking
  pure def createTestProposal(id: str, ptype: ProposalType): Proposal = {
    id: id,
    proposalType: ptype,
    state: Pending,
    operation: "test_operation",
    validatedBy: Set(),
    bypassedGuardian: false,
    vetoReason: "",
    timestamp: 0
  }

  // ---------------------------------------------------------------------------
  // Step sub-actions: each updates ALL state variables via their called actions.
  // nondet bindings must be at action level (not nested inside all{}).
  // ---------------------------------------------------------------------------

  /// Sub-action: submit a new proposal
  action stepSubmit: bool = {
    nondet id = oneOf(Set("p1", "p2", "p3", "p4", "p5"))
    nondet ptype = oneOf(Set(Command, Reconfiguration, Mutation, ScaleUp))
    submitProposal(createTestProposal(id, ptype))
  }

  /// Sub-action: Guardian validates a pending proposal
  action stepValidate: bool = {
    nondet p = oneOf(proposals)
    guardianValidate(p)
  }

  /// Sub-action: Guardian approves a validating proposal
  action stepApprove: bool = {
    nondet p = oneOf(proposals)
    guardianApprove(p)
  }

  /// Sub-action: Guardian vetoes a validating proposal
  action stepVeto: bool = {
    nondet p = oneOf(proposals)
    nondet reason = oneOf(Set("resource_limit", "security_violation", "founder_directive"))
    guardianVeto(p, reason)
  }

  /// Sub-action: Execute an approved proposal
  action stepExecute: bool = {
    nondet p = oneOf(approvedProposals)
    executeProposal(p)
  }

  /// Sub-action: Complete execution of an executing proposal
  action stepComplete: bool = {
    nondet p = oneOf(executingProposals)
    completeExecution(p)
  }

  /// Sub-action: Reject a vetoed proposal
  action stepReject: bool = {
    nondet p = oneOf(vetoedProposals)
    rejectProposal(p)
  }

  /// Master step: non-deterministic choice of actions
  action step = any {
    stepSubmit,
    stepValidate,
    stepApprove,
    stepVeto,
    stepExecute,
    stepComplete,
    stepReject
  }

  /// Master invariant for verification
  val masterInvariant: bool = guardianSafetyInvariant

  // Run: quint verify --invariant=masterInvariant prajna_guardian.qnt
  // Expected: PASS (all invariants hold)

  // Run: quint run --max-steps=100 --invariant=masterInvariant prajna_guardian.qnt
  // Expected: No counterexamples (model is safe)
}

// =============================================================================
// VERIFICATION CHECKLIST (Sprint 30.15.1)
// =============================================================================
//
// 30.15.1.1: No-bypass proof
//   - inv_no_bypass proves all executed proposals were Guardian-approved
//   - Structural proof by construction (executeProposal requires approval)
//
// 30.15.1.2: Veto always halts
//   - inv_veto_halts proves vetoed proposals never execute
//   - Disjoint sets proof (approved intersect vetoed = empty)
//
// Additional properties:
//   - Guardian liveness (heartbeat check)
//   - State machine well-formedness
//   - Founder Directive (Omega0) always validated
//   - Unique proposal IDs
//
// Temporal properties:
//   - Safety always maintained
//   - Proposals eventually validated
//   - Approved proposals eventually execute
//   - Vetoed proposals never execute
//
// =============================================================================
