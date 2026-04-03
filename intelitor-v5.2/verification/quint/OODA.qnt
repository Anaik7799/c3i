// =============================================================================
// OODA.qnt - Panopticon Temporal Safety Model
// WHAT: Models the 10s SLA, 2oo3 Voting, and High-Density Load
// =============================================================================

module OodaPanopticon {
  // --- TYPES ---
  type NodeState = Healthy | Failed
  type VotingResult = Actuate | Halt | Jidoka

  // --- CONSTANTS ---
  val SLA_THRESHOLD_MS = 10000
  val MAX_PANELS = 5000

  // --- STATE ---
  var time_ms: int
  var nodes: str -> NodeState
  var judge_decision: VotingResult
  var load_count: int

  // --- ACTIONS ---
  action init = all {
    time_ms' = 0,
    nodes' = Map("live" -> Healthy, "shadow" -> Healthy, "model" -> Healthy),
    judge_decision' = Halt,
    load_count' = 0
  }

  action process_load = all {
    load_count < MAX_PANELS,
    load_count' = load_count + 100, // Batch processing
    time_ms' = time_ms + 50,
    nodes' = nodes,
    judge_decision' = judge_decision
  }

  action failure_injection = {
    nondet victim = oneOf(Set("live", "shadow", "model"));
    all {
      nodes' = nodes.set(victim, Failed),
      time_ms' = time_ms + 10,
      judge_decision' = judge_decision,
      load_count' = load_count
    }
  }

  action judge_vote = {
    val healthy_count = nodes.keys().filter(n => nodes.get(n) == Healthy).size();
    all {
      judge_decision' = if (healthy_count >= 2) Actuate else Jidoka,
      time_ms' = time_ms + 2,
      nodes' = nodes,
      load_count' = load_count
    }
  }

  // --- INVARIANTS ---
  // SC-PAN-002: Safety Invariant (Quorum required for Actuation)
  val safety_invariant = (judge_decision == Actuate) implies (
    nodes.keys().filter(n => nodes.get(n) == Healthy).size() >= 2
  )

  // SC-FRACTAL-001: SLA Invariant (Startup/Converge within 10s)
  val sla_invariant = (load_count == MAX_PANELS) implies (time_ms <= SLA_THRESHOLD_MS)
}
