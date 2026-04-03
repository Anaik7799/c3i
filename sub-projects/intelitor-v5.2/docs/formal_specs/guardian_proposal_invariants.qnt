// =============================================================================
// GUARDIAN PROPOSAL INVARIANTS — FORMAL SPECIFICATION
// Indrajaal Guardian Safety Kernel, L5 Cluster Layer
// =============================================================================
//
// WHAT: Temporal-logic specification of the Guardian proposal lifecycle.
//       Models the full submit → review → approve/reject pipeline, the
//       Constitutional veto (absolute block), 2oo3 tricameral voting, and the
//       Founder Directive preservation invariant.
//
// WHY:  The existing guardian_state_machine.qnt models the 5-state DMS-backed
//       machine.  This companion spec zooms in on the PROPOSAL LIFECYCLE: what
//       happens from the moment a proposal is submitted until it is either
//       executed or permanently blocked.  The critical safety property is that
//       NO proposal violating the Founder Directive (Ω₀) or a Constitutional
//       constraint (Ψ₀–Ψ₅) ever reaches the Executed state.
//
// CONSTRAINTS:
//   - SC-GUARD-001: Guardian MUST use Envelope for all constraint values
//   - SC-GUARD-002: Guardian integrates with DeadMansSwitch; fails closed
//   - SC-GUARD-003: Guardian integrates with FounderDirective (Ω₀)
//   - SC-SAFETY-001: Guardian pre-approval REQUIRED for planning mutations
//   - SC-SAFETY-005: Access control enforced — quarantined agents blocked
//   - SC-CONSENSUS-001: 2oo3 voting for P0 decisions
//   - SC-CONSENSUS-002: Each chamber has Constitutional veto (absolute)
//   - SC-CONSENSUS-003: Timeout < 30s per chamber
//   - SC-TRI-001 to SC-TRI-005: Tricameral orchestrator constraints
//   - SC-GDE-001: Guardian validation required
//   - SC-GDE-002: Shadow testing mandatory
//   - SC-GDE-003: Rollback capability
//   - SC-GDE-004: Proposal threshold >= 0.85
//   - SC-RECONFIG-009: Guardian approval REQUIRED
//
// FRACTAL LAYER: L5 (Cluster) — Guardian coordinates across all fractal layers.
//
// PROPOSAL LIFECYCLE STATES:
//   Submitted    — proposal received by the Guardian queue
//   InReview     — at least one chamber is evaluating the proposal
//   VotePending  — all three chambers have voted; awaiting tally
//   Approved     — 2oo3 quorum satisfied, no Constitutional veto
//   Rejected     — 2oo3 quorum not satisfied (< 2 approvals)
//   Vetoed       — at least one chamber issued a Constitutional veto
//   Executed     — approved proposal has been applied and logged
//   RolledBack   — executed proposal was reversed (SC-GDE-003)
//
// TRICAMERAL CHAMBERS (SC-CONSENSUS-001):
//   Chamber A: Safety Kernel (hard safety constraints)
//   Chamber B: Constitutional Checker (Ψ₀-Ψ₅, Ω₀)
//   Chamber C: Resource Envelope (SC-RES, SC-SIL4 timing)
//
// VOTING OUTCOMES PER CHAMBER:
//   Approve         — constraint check passes
//   Reject          — constraint check fails (not a veto)
//   ConstitVeto     — Constitutional violation (absolute block)
//
// Document Control:
//   | Field   | Value                                              |
//   |---------|----------------------------------------------------|
//   | Version | 1.0.0                                              |
//   | Created | 2026-03-28                                         |
//   | Author  | Code Evolution Agent v21.3.1-SIL6                  |
//   | STAMP   | SC-GUARD-001..003, SC-CONSENSUS-001..003, SC-GDE-001..004 |
//
// Verification:
//   quint verify --invariant=proposalInvariant guardian_proposal_invariants.qnt
//   quint run --max-steps=400 --invariant=proposalInvariant guardian_proposal_invariants.qnt
//
// =============================================================================

module guardian_proposals {

  // ---------------------------------------------------------------------------
  // TYPE DEFINITIONS
  // ---------------------------------------------------------------------------

  /// The lifecycle states of a single proposal (SC-GUARD-001).
  type ProposalStatus =
    | Submitted    // received; not yet under review
    | InReview     // at least one chamber has started evaluation
    | VotePending  // all votes cast; awaiting tally
    | Approved     // 2oo3 passed; no Constitutional veto
    | Rejected     // fewer than 2 approvals; not a Constitutional veto
    | Vetoed       // absolute Constitutional veto — PERMANENT block
    | Executed     // approved and applied; logged to Immutable Register
    | RolledBack   // was Executed; reversal completed (SC-GDE-003)

  /// The three chambers of the tricameral consensus (SC-TRI-001).
  type Chamber =
    | SafetyKernel        // hard safety constraints
    | ConstitutionalCheck // Ψ₀-Ψ₅, Ω₀ (Founder Directive)
    | ResourceEnvelope    // SC-RES, SC-SIL4 timing

  /// A vote cast by one chamber.
  type ChamberVote =
    | Approve      // constraint check passes
    | Reject       // constraint check fails (non-veto)
    | ConstitVeto  // Constitutional violation — absolute veto

  /// Priority classification of a proposal (SC-GUARD-004: threshold >= 0.85).
  type ProposalPriority =
    | P0  // Safety-critical: always requires 3/3 unanimous
    | P1  // Core system: 2oo3 minimum
    | P2  // Domain logic: 2oo3 minimum
    | P3  // Style: 1oo3 sufficient

  /// A proposal record.
  type Proposal = {
    id:              str,
    operation:       str,
    priority:        ProposalPriority,
    status:          ProposalStatus,
    // Votes indexed by chamber (stored as separate fields to avoid maps)
    voteA:           ChamberVote,   // SafetyKernel
    voteB:           ChamberVote,   // ConstitutionalCheck
    voteC:           ChamberVote,   // ResourceEnvelope
    votesComplete:   bool,
    founderApproved: bool,  // true only when Ω₀ check passes (SC-GUARD-003)
    shadowTested:    bool,  // SC-GDE-002: shadow test must pass
    submittedAt:     int,
    resolvedAt:      int    // 0 when not yet resolved
  }

  /// Audit entry for the proposal log.
  type ProposalAuditEntry = {
    proposalId: str,
    fromStatus: ProposalStatus,
    toStatus:   ProposalStatus,
    reason:     str,
    clock:      int
  }

  // ---------------------------------------------------------------------------
  // CONSTANTS
  // ---------------------------------------------------------------------------

  /// Minimum fitness threshold for proposal activation (SC-GDE-004).
  /// Encoded as integer percentage (85 = 0.85 × 100).
  pure val PROPOSAL_FITNESS_THRESHOLD: int = 85

  /// Maximum ticks allowed for a chamber to vote (SC-CONSENSUS-003: < 30s).
  pure val CHAMBER_VOTE_TIMEOUT: int = 30

  /// Confirmation phrase required to execute a P0 proposal.
  pure val P0_EXEC_CONFIRM: str = "FOUNDER_APPROVED_P0_EXEC_v21"

  // ---------------------------------------------------------------------------
  // STATE VARIABLES
  // ---------------------------------------------------------------------------

  /// The set of proposals currently tracked by the Guardian.
  var proposals: Set[Proposal]

  /// Set of proposal IDs with permanent Constitutional veto (SC-CONSENSUS-002).
  var permanentVetoIds: Set[str]

  /// Set of proposal IDs that have been successfully executed.
  var executedIds: Set[str]

  /// Monotonic logical clock.
  var clock: int

  /// Append-only proposal lifecycle audit log (SC-REG-001).
  var auditLog: List[ProposalAuditEntry]

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  /// Count how many Approve votes a proposal has.
  def approveCount(p: Proposal): int =
    (if (p.voteA == Approve) 1 else 0) +
    (if (p.voteB == Approve) 1 else 0) +
    (if (p.voteC == Approve) 1 else 0)

  /// True when any chamber voted ConstitVeto.
  def hasConstitVeto(p: Proposal): bool =
    p.voteA == ConstitVeto or p.voteB == ConstitVeto or p.voteC == ConstitVeto

  /// Required approve count for a given priority (SC-CONSENSUS-001).
  def quorumRequired(priority: ProposalPriority): int =
    match priority {
      | P0 => 3   // unanimous for safety-critical
      | P1 => 2   // 2oo3
      | P2 => 2   // 2oo3
      | P3 => 1   // 1oo3 sufficient
    }

  /// True when the proposal meets the minimum quorum for its priority.
  def meetsQuorum(p: Proposal): bool =
    approveCount(p) >= quorumRequired(p.priority)

  /// Append an entry to the audit log.
  def logEvent(pid: str, from: ProposalStatus, to: ProposalStatus,
               reason: str): List[ProposalAuditEntry] =
    auditLog.append({
      proposalId: pid,
      fromStatus: from,
      toStatus:   to,
      reason:     reason,
      clock:      clock
    })

  /// Sentinel proposal used as a default in fold operations.
  pure def emptyProposal: Proposal = {
    id:              "",
    operation:       "",
    priority:        P2,
    status:          Submitted,
    voteA:           Reject,
    voteB:           Reject,
    voteC:           Reject,
    votesComplete:   false,
    founderApproved: false,
    shadowTested:    false,
    submittedAt:     0,
    resolvedAt:      0
  }

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  action init = all {
    proposals'       = Set(),
    permanentVetoIds' = Set(),
    executedIds'     = Set(),
    clock'           = 0,
    auditLog'        = List()
  }

  // ---------------------------------------------------------------------------
  // ACTION: submit_proposal
  // ---------------------------------------------------------------------------
  // A new proposal enters the Guardian queue.
  // SC-GUARD-001: must carry an Envelope with constraint values.
  // SC-GDE-002: shadow test result is required before admission.
  // Pre: proposal ID is unique and not in permanentVetoIds.

  action submit_proposal(p: Proposal): bool = all {
    // New ID, not already known, not permanently vetoed
    proposals.filter(x => x.id == p.id).size() == 0,
    not(permanentVetoIds.contains(p.id)),
    // SC-GDE-002: shadow test must have been performed before submission
    p.shadowTested == true,
    val admitted: Proposal = {
      ...p,
      status:      Submitted,
      submittedAt: clock,
      resolvedAt:  0
    }
    all {
      proposals' = proposals.union(Set(admitted)),
      auditLog'  = logEvent(p.id, Submitted, Submitted, "proposal_submitted"),
      clock'     = clock + 1,
      // Stutter
      permanentVetoIds' = permanentVetoIds,
      executedIds'      = executedIds
    }
  }

  // ---------------------------------------------------------------------------
  // ACTION: begin_review
  // ---------------------------------------------------------------------------
  // Transitions a Submitted proposal to InReview.
  // All three chambers begin evaluation concurrently (modelled as a single step).

  action begin_review(pid: str): bool = all {
    proposals.filter(p => p.id == pid and p.status == Submitted).size() == 1,
    val target = proposals.filter(p => p.id == pid and p.status == Submitted)
                          .fold(emptyProposal, (_, x) => x)
    val updated: Proposal = { ...target, status: InReview }
    all {
      proposals' = proposals
                     .filter(p => p.id != pid)
                     .union(Set(updated)),
      auditLog'  = logEvent(pid, Submitted, InReview, "review_started"),
      clock'     = clock + 1,
      // Stutter
      permanentVetoIds' = permanentVetoIds,
      executedIds'      = executedIds
    }
  }

  // ---------------------------------------------------------------------------
  // ACTION: cast_votes
  // ---------------------------------------------------------------------------
  // All three chambers submit their votes simultaneously.
  // ConstitutionalCheck chamber (B) also evaluates the Founder Directive (SC-GUARD-003).
  // Moves proposal to VotePending.

  action cast_votes(pid: str, vA: ChamberVote, vB: ChamberVote,
                    vC: ChamberVote, founderOk: bool): bool = all {
    proposals.filter(p => p.id == pid and p.status == InReview).size() == 1,
    val target = proposals.filter(p => p.id == pid and p.status == InReview)
                          .fold(emptyProposal, (_, x) => x)
    val updated: Proposal = {
      ...target,
      voteA:           vA,
      voteB:           vB,
      voteC:           vC,
      votesComplete:   true,
      founderApproved: founderOk,
      status:          VotePending
    }
    all {
      proposals' = proposals
                     .filter(p => p.id != pid)
                     .union(Set(updated)),
      auditLog'  = logEvent(pid, InReview, VotePending, "votes_cast"),
      clock'     = clock + 1,
      // Stutter
      permanentVetoIds' = permanentVetoIds,
      executedIds'      = executedIds
    }
  }

  // ---------------------------------------------------------------------------
  // ACTION: tally_votes
  // ---------------------------------------------------------------------------
  // Tallies votes and determines the outcome.
  // Outcome rules:
  //   1. Any ConstitVeto → Vetoed (SC-CONSENSUS-002: absolute veto)
  //   2. Founder Directive failed → Vetoed (SC-GUARD-003)
  //   3. meetsQuorum → Approved
  //   4. Otherwise → Rejected

  action tally_votes(pid: str): bool = all {
    proposals.filter(p => p.id == pid and p.status == VotePending).size() == 1,
    val target = proposals.filter(p => p.id == pid and p.status == VotePending)
                          .fold(emptyProposal, (_, x) => x)
    // Determine outcome
    val outcome: ProposalStatus =
      if (hasConstitVeto(target) or not(target.founderApproved)) Vetoed
      else if (meetsQuorum(target)) Approved
      else Rejected
    val updated: Proposal = {
      ...target,
      status:     outcome,
      resolvedAt: clock
    }
    // If vetoed, add to permanent veto set
    val newVetoIds =
      if (outcome == Vetoed) permanentVetoIds.union(Set(pid))
      else permanentVetoIds
    all {
      proposals'        = proposals
                            .filter(p => p.id != pid)
                            .union(Set(updated)),
      permanentVetoIds' = newVetoIds,
      auditLog'         = logEvent(pid, VotePending, outcome, "tally_complete"),
      clock'            = clock + 1,
      // Stutter
      executedIds' = executedIds
    }
  }

  // ---------------------------------------------------------------------------
  // ACTION: execute_proposal
  // ---------------------------------------------------------------------------
  // An Approved proposal is applied.
  // P0 proposals require the FOUNDER confirmation phrase.
  // SC-GDE-003: executed proposals must have a rollback available.
  // Pre: proposal is Approved, not in permanentVetoIds.

  action execute_proposal(pid: str, confirmPhrase: str): bool = all {
    proposals.filter(p => p.id == pid and p.status == Approved).size() == 1,
    not(permanentVetoIds.contains(pid)),
    val target = proposals.filter(p => p.id == pid and p.status == Approved)
                          .fold(emptyProposal, (_, x) => x)
    // P0 proposals require explicit Founder confirmation
    (target.priority != P0 or confirmPhrase == P0_EXEC_CONFIRM),
    // Founder Directive must have been confirmed during vote (SC-GUARD-003)
    target.founderApproved == true,
    val updated: Proposal = { ...target, status: Executed, resolvedAt: clock }
    all {
      proposals'   = proposals
                       .filter(p => p.id != pid)
                       .union(Set(updated)),
      executedIds' = executedIds.union(Set(pid)),
      auditLog'    = logEvent(pid, Approved, Executed, "proposal_executed"),
      clock'       = clock + 1,
      // Stutter
      permanentVetoIds' = permanentVetoIds
    }
  }

  // ---------------------------------------------------------------------------
  // ACTION: rollback_proposal
  // ---------------------------------------------------------------------------
  // An Executed proposal is reversed (SC-GDE-003).
  // Removes proposal id from executedIds and records the rollback.

  action rollback_proposal(pid: str): bool = all {
    proposals.filter(p => p.id == pid and p.status == Executed).size() == 1,
    executedIds.contains(pid),
    val target = proposals.filter(p => p.id == pid and p.status == Executed)
                          .fold(emptyProposal, (_, x) => x)
    val updated: Proposal = { ...target, status: RolledBack, resolvedAt: clock }
    all {
      proposals'   = proposals
                       .filter(p => p.id != pid)
                       .union(Set(updated)),
      executedIds' = executedIds.filter(eid => eid != pid),
      auditLog'    = logEvent(pid, Executed, RolledBack, "rollback_executed"),
      clock'       = clock + 1,
      // Stutter
      permanentVetoIds' = permanentVetoIds
    }
  }

  // ---------------------------------------------------------------------------
  // ACTION: tick_clock
  // ---------------------------------------------------------------------------

  action tick_clock: bool = all {
    clock'            = clock + 1,
    proposals'        = proposals,
    permanentVetoIds' = permanentVetoIds,
    executedIds'      = executedIds,
    auditLog'         = auditLog
  }

  // ---------------------------------------------------------------------------
  // SAFETY INVARIANTS
  // ---------------------------------------------------------------------------

  // INV-VETO-PREVENTS-EXEC: A vetoed proposal NEVER reaches Executed.
  // (SC-CONSENSUS-002: Constitutional veto is absolute.)
  val inv_veto_prevents_execution: bool =
    permanentVetoIds.forall(vid => not(executedIds.contains(vid))) and
    proposals.forall(p =>
      p.status == Vetoed implies not(executedIds.contains(p.id))
    )

  // INV-FOUNDER-DIRECTIVE: Every Executed proposal had founderApproved == true.
  // (SC-GUARD-003: Founder Directive is the supreme override.)
  val inv_founder_directive_preserved: bool =
    proposals.forall(p =>
      p.status == Executed implies p.founderApproved == true
    )

  // INV-SHADOW-TESTED: Every proposal that reached InReview was shadow-tested.
  // (SC-GDE-002: shadow testing mandatory.)
  val inv_shadow_tested_before_review: bool =
    proposals.forall(p =>
      (p.status == InReview    or
       p.status == VotePending or
       p.status == Approved    or
       p.status == Executed    or
       p.status == RolledBack)
      implies p.shadowTested == true
    )

  // INV-VETO-IMMUTABLE: permanentVetoIds only grows; vetoed proposals are
  // never removed from the set.  Approximated by: if a proposal has Vetoed
  // status, its id is in permanentVetoIds.
  val inv_veto_set_consistent: bool =
    proposals.forall(p =>
      p.status == Vetoed implies permanentVetoIds.contains(p.id)
    )

  // INV-CONST-VETO-ABSOLUTE: If any chamber cast ConstitVeto, the proposal
  // must be in Vetoed status or awaiting tally (VotePending).
  val inv_const_veto_leads_to_vetoed: bool =
    proposals.forall(p =>
      hasConstitVeto(p) implies
        (p.status == Vetoed or p.status == VotePending)
    )

  // INV-2OO3-QUORUM: An Approved proposal must have met the required quorum
  // for its priority level (SC-CONSENSUS-001).
  val inv_approved_meets_quorum: bool =
    proposals.forall(p =>
      p.status == Approved implies meetsQuorum(p)
    )

  // INV-ROLLBACK-REQUIRES-EXECUTION: Only Executed proposals can be rolled back.
  val inv_rollback_only_from_executed: bool =
    proposals.forall(p =>
      p.status == RolledBack implies executedIds.filter(eid => eid == p.id).size() == 0
    )

  // INV-AUDIT-GROWS: audit log is non-empty once any proposal has been submitted.
  val inv_audit_grows: bool =
    proposals.size() > 0 implies auditLog.length() > 0

  // INV-VOTES-COMPLETE-BEFORE-PENDING: A VotePending proposal always has
  // votesComplete == true.
  val inv_votes_complete_when_pending: bool =
    proposals.forall(p =>
      p.status == VotePending implies p.votesComplete == true
    )

  // INV-RESOLVED-AT-SET: Resolved proposals (Approved/Rejected/Vetoed/Executed)
  // have resolvedAt > 0.
  val inv_resolved_at_set: bool =
    proposals.forall(p =>
      (p.status == Approved or p.status == Rejected or
       p.status == Vetoed   or p.status == Executed) implies p.resolvedAt > 0
    )

  /// Combined master invariant.
  val proposalInvariant: bool = all {
    inv_veto_prevents_execution,
    inv_founder_directive_preserved,
    inv_shadow_tested_before_review,
    inv_veto_set_consistent,
    inv_const_veto_leads_to_vetoed,
    inv_approved_meets_quorum,
    inv_rollback_only_from_executed,
    inv_audit_grows,
    inv_votes_complete_when_pending,
    inv_resolved_at_set
  }

  // ---------------------------------------------------------------------------
  // TEMPORAL PROPERTIES
  // ---------------------------------------------------------------------------

  // TEMP1: proposals_eventually_resolved —
  //   □(Submitted → ◇(Approved ∨ Rejected ∨ Vetoed))
  // Every submitted proposal eventually reaches a terminal decision state.
  temporal temp1_proposals_eventually_resolved = always(
    proposals.forall(p =>
      p.status == Submitted implies
      eventually(
        proposals.exists(q =>
          q.id == p.id and
          (q.status == Approved or q.status == Rejected or q.status == Vetoed)
        )
      )
    )
  )

  // TEMP2: veto_halts_execution — □(Vetoed → □¬Executed)
  // A vetoed proposal NEVER becomes Executed, in any future state.
  temporal temp2_veto_halts_execution = always(
    proposals.forall(p =>
      p.status == Vetoed implies
      always(
        proposals.forall(q => q.id == p.id implies q.status != Executed)
      )
    )
  )

  // TEMP3: founder_directive_preserved — □(Executed → founderApproved)
  // The Founder Directive check is preserved in every reachable state.
  temporal temp3_founder_directive_preserved = always(
    proposals.forall(p =>
      p.status == Executed implies p.founderApproved == true
    )
  )

  // TEMP4: □(Approved → ◇(Executed ∨ RolledBack))
  // An approved proposal is always eventually executed or rolled back —
  // it does not linger in Approved indefinitely.
  temporal temp4_approved_eventually_resolved = always(
    proposals.forall(p =>
      p.status == Approved implies
      eventually(
        proposals.exists(q =>
          q.id == p.id and
          (q.status == Executed or q.status == RolledBack)
        )
      )
    )
  )

  // TEMP5: □(proposalInvariant)
  // Safety invariants hold in every reachable state.
  temporal temp5_always_safe = always(proposalInvariant)

}

// =============================================================================
// MODEL-CHECKING HARNESS
// =============================================================================

module guardian_proposal_model_checking {
  import guardian_proposals.*

  /// Helper: build a test proposal.
  pure def mkProposal(pid: str, prio: ProposalPriority, shadow: bool): Proposal = {
    id:              pid,
    operation:       pid,
    priority:        prio,
    status:          Submitted,
    voteA:           Reject,
    voteB:           Reject,
    voteC:           Reject,
    votesComplete:   false,
    founderApproved: false,
    shadowTested:    shadow,
    submittedAt:     0,
    resolvedAt:      0
  }

  // Non-deterministic submit
  action stepSubmit: bool = {
    nondet pid  = oneOf(Set("p1", "p2", "p3", "p4", "p5"))
    nondet prio = oneOf(Set(P0, P1, P2, P3))
    submit_proposal(mkProposal(pid, prio, true))
  }

  // Non-deterministic begin review
  action stepBeginReview: bool = {
    nondet pid = oneOf(Set("p1", "p2", "p3", "p4", "p5"))
    begin_review(pid)
  }

  // Non-deterministic vote (covers veto / approve / reject combinations)
  action stepVote: bool = {
    nondet pid      = oneOf(Set("p1", "p2", "p3", "p4", "p5"))
    nondet va       = oneOf(Set(Approve, Reject, ConstitVeto))
    nondet vb       = oneOf(Set(Approve, Reject, ConstitVeto))
    nondet vc       = oneOf(Set(Approve, Reject, ConstitVeto))
    nondet founderOk = oneOf(Set(true, false))
    cast_votes(pid, va, vb, vc, founderOk)
  }

  // Non-deterministic tally
  action stepTally: bool = {
    nondet pid = oneOf(Set("p1", "p2", "p3", "p4", "p5"))
    tally_votes(pid)
  }

  // Non-deterministic execute (standard priority — no P0 confirm needed)
  action stepExecute: bool = {
    nondet pid = oneOf(Set("p1", "p2", "p3", "p4", "p5"))
    execute_proposal(pid, "")
  }

  // P0 execute with correct confirmation
  action stepExecuteP0: bool = {
    nondet pid = oneOf(Set("p1", "p2", "p3", "p4", "p5"))
    execute_proposal(pid, P0_EXEC_CONFIRM)
  }

  // Non-deterministic rollback
  action stepRollback: bool = {
    nondet pid = oneOf(Set("p1", "p2", "p3", "p4", "p5"))
    rollback_proposal(pid)
  }

  // Clock tick
  action stepTick: bool = tick_clock

  // Master non-deterministic step
  action step = any {
    stepSubmit,
    stepBeginReview,
    stepVote,
    stepTally,
    stepExecute,
    stepExecuteP0,
    stepRollback,
    stepTick
  }

  val masterInvariant: bool = proposalInvariant

  // Run commands:
  //   quint verify --invariant=masterInvariant guardian_proposal_invariants.qnt
  //   quint run --max-steps=400 --invariant=masterInvariant guardian_proposal_invariants.qnt
  // Expected: PASS — no counterexamples in up to 400 steps

}

// =============================================================================
// VERIFICATION SUMMARY
// =============================================================================
//
// INV-VETO-PREVENTS-EXEC (SC-CONSENSUS-002):
//   tally_votes inserts the proposal id into permanentVetoIds when hasConstitVeto
//   is true or founderApproved is false.  execute_proposal pre-checks
//   not(permanentVetoIds.contains(pid)).  Therefore a vetoed proposal can never
//   be executed — structurally impossible.
//
// INV-FOUNDER-DIRECTIVE (SC-GUARD-003):
//   cast_votes records founderApproved per chamber B's evaluation.  tally_votes
//   moves to Vetoed when founderApproved == false.  execute_proposal pre-checks
//   founderApproved == true.  Invariant holds by structural enforcement.
//
// INV-SHADOW-TESTED (SC-GDE-002):
//   submit_proposal pre-checks p.shadowTested == true.  No proposal can enter
//   InReview without this check passing.
//
// INV-2OO3-QUORUM (SC-CONSENSUS-001):
//   tally_votes computes Approved only when meetsQuorum is true.  The invariant
//   asserts the condition on every Approved proposal.
//
// INV-CONST-VETO-ABSOLUTE:
//   tally_votes checks hasConstitVeto first (before quorum), ensuring any
//   ConstitVeto vote leads to Vetoed, never Approved.
//
// TEMP2 (veto_halts_execution):
//   Vetoed proposals are added to permanentVetoIds which is never reduced.
//   execute_proposal guards against permanentVetoIds membership.  Under any
//   future step, the veto set only grows, so the property holds globally.
//
// =============================================================================
