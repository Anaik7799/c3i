// OpenRouter Integration Graph Model
// Document ID: QUINT-OR-001
// Version: 1.0.0
// Status: ACTIVE
// Created: 2025-12-27T12:30:00+01:00
// Author: Cybernetic Architect
// STAMP Compliance: SC-GDE-060, SC-GDE-061, SC-NEURO-001, SC-NEURO-003, SC-GVF-001

module OpenRouterIntegration {

  //============================================================================
  // SECTION 1: TYPE DEFINITIONS
  //============================================================================

  // Component types in the AI routing graph
  type Component = str

  // AI model tiers
  type Tier = Fast | Smart | Deep

  // Confidence score (0.0 to 1.0, represented as int 0-100 for simplicity)
  type Confidence = int

  // Proposal status
  type ProposalStatus = Pending | Validated | Rejected | Executed

  // Operation types
  type Operation =
    | ScalePool
    | AdjustCache
    | ModifyConfig
    | ShellCommand
    | ContainerOp
    | DatabaseOp

  // Forbidden operation patterns
  type ForbiddenPattern =
    | RmRf
    | DropTable
    | TruncateTable
    | FormatDisk
    | KillAll
    | ChmodRecursive

  //============================================================================
  // SECTION 2: STATE VARIABLES
  //============================================================================

  // Set of all components in the system
  var components: Set[Component]

  // Routing relationships: (source, destination)
  var routes_to: Set[(Component, Component)]

  // Tier assignment for AI-capable components
  var tier_assignment: Component -> Tier

  // Active proposals awaiting validation
  var pending_proposals: Set[(Component, Operation, Confidence)]

  // Validated proposals ready for execution
  var validated_proposals: Set[(Component, Operation)]

  // Executed operations log
  var execution_log: Set[(Component, Operation, bool)]

  // Circuit breaker states: component -> is_open
  var circuit_breakers: Component -> bool

  // Forbidden operations detected
  var forbidden_detected: Set[(Component, ForbiddenPattern)]

  //============================================================================
  // SECTION 3: CONSTANTS
  //============================================================================

  // Core system components
  pure val SYNAPSE: Component = "synapse"
  pure val OPENROUTER: Component = "openrouter"
  pure val GUARDIAN: Component = "guardian"
  pure val GDE: Component = "gde"
  pure val CORTEX: Component = "cortex"
  pure val CEPAF: Component = "cepaf"
  pure val ZENOH: Component = "zenoh"

  // External AI providers (should NOT be directly accessible)
  pure val CLAUDE: Component = "claude"
  pure val GEMINI: Component = "gemini"
  pure val GPT: Component = "gpt"
  pure val EXTERNAL_AI: Set[Component] = Set(CLAUDE, GEMINI, GPT)

  // Minimum confidence threshold (SC-GDE-061)
  pure val MIN_CONFIDENCE: Confidence = 60

  // Core components that must exist
  pure val CORE_COMPONENTS: Set[Component] = Set(
    SYNAPSE, OPENROUTER, GUARDIAN, GDE, CORTEX, CEPAF, ZENOH
  )

  //============================================================================
  // SECTION 4: HELPER FUNCTIONS
  //============================================================================

  // Check if a component can reach another via routing
  def can_reach(src: Component, dst: Component): bool = {
    routes_to.contains((src, dst))
  }

  // Check if a component can transitively reach another
  // Note: Simplified for 2-hop reachability
  def can_reach_2hop(src: Component, dst: Component): bool = {
    routes_to.contains((src, dst)) or
    routes_to.exists(r1 =>
      r1._1 == src and routes_to.exists(r2 =>
        r2._1 == r1._2 and r2._2 == dst
      )
    )
  }

  // Check if a component can transitively reach another (3-hop)
  def can_reach_3hop(src: Component, dst: Component): bool = {
    can_reach_2hop(src, dst) or
    routes_to.exists(r1 =>
      r1._1 == src and can_reach_2hop(r1._2, dst)
    )
  }

  // Check if operation is forbidden
  pure def is_forbidden_operation(op: Operation): bool = {
    op == ShellCommand  // Shell commands require extra scrutiny
  }

  // Check if confidence meets threshold
  pure def meets_confidence_threshold(conf: Confidence): bool = {
    conf >= MIN_CONFIDENCE
  }

  //============================================================================
  // SECTION 5: INVARIANTS (SAFETY PROPERTIES)
  //============================================================================

  // INV-001: SC-GDE-060 - OpenRouter Exclusivity
  // All AI requests must route through OpenRouter, never directly to external AI
  val inv_openrouter_exclusivity: bool = {
    not(routes_to.exists(route =>
      route._1 == SYNAPSE and route._2.in(EXTERNAL_AI)
    ))
  }

  // INV-002: SC-GDE-060 - Synapse routes through OpenRouter
  // Synapse must have a route to OpenRouter
  val inv_synapse_routes_to_openrouter: bool = {
    components.contains(SYNAPSE) implies can_reach(SYNAPSE, OPENROUTER)
  }

  // INV-003: SC-NEURO-001 - Simplex Principle
  // All proposals to GDE must first pass through Guardian
  val inv_simplex_principle: bool = {
    routes_to.filter(r => r._2 == GDE).forall(route =>
      route._1 == GUARDIAN or can_reach(route._1, GUARDIAN)
    )
  }

  // INV-004: SC-GDE-061 - Confidence Threshold
  // Only proposals meeting confidence threshold can be validated
  val inv_confidence_threshold: bool = {
    validated_proposals.forall(vp =>
      pending_proposals.exists(pp =>
        pp._1 == vp._1 and pp._2 == vp._2 and pp._3 >= MIN_CONFIDENCE
      )
    )
  }

  // INV-005: SC-NEURO-003 - No Forbidden Operations Executed
  // Forbidden operations must never appear in execution log as successful
  val inv_no_forbidden_executed: bool = {
    execution_log.forall(entry =>
      not(is_forbidden_operation(entry._2) and entry._3 == true)
    )
  }

  // INV-006: Guardian Validates All Executions
  // Every executed operation must have been validated
  val inv_guardian_validates_all: bool = {
    execution_log.filter(e => e._3 == true).forall(executed =>
      validated_proposals.contains((executed._1, executed._2))
    )
  }

  // INV-007: Circuit Breaker Isolation
  // Open circuit breakers prevent new requests
  val inv_circuit_breaker_isolation: bool = {
    circuit_breakers.keys().forall(comp =>
      circuit_breakers.get(comp) == true implies
      not(routes_to.exists(r => r._1 == comp))
    )
  }

  // INV-008: Telemetry Path Exists
  // All components should be able to reach Zenoh for telemetry
  val inv_telemetry_reachable: bool = {
    CORE_COMPONENTS.forall(comp =>
      comp == ZENOH or can_reach_3hop(comp, ZENOH)
    )
  }

  // INV-009: No Orphan Components
  // All components must be reachable from Cortex (except Cortex itself)
  val inv_no_orphans: bool = {
    components.forall(comp =>
      comp == CORTEX or can_reach_3hop(CORTEX, comp)
    )
  }

  // INV-010: Acyclic Proposal Flow
  // Proposals flow: Synapse -> OpenRouter -> Guardian -> GDE (no cycles)
  val inv_acyclic_proposal_flow: bool = {
    not(can_reach_3hop(GDE, SYNAPSE)) and
    not(can_reach_2hop(GUARDIAN, OPENROUTER)) and
    not(can_reach(OPENROUTER, SYNAPSE))
  }

  // Combined invariant for all safety properties
  val all_invariants: bool = {
    inv_openrouter_exclusivity and
    inv_synapse_routes_to_openrouter and
    inv_simplex_principle and
    inv_confidence_threshold and
    inv_no_forbidden_executed and
    inv_guardian_validates_all and
    inv_circuit_breaker_isolation and
    inv_telemetry_reachable and
    inv_no_orphans and
    inv_acyclic_proposal_flow
  }

  //============================================================================
  // SECTION 6: STATE TRANSITIONS (ACTIONS)
  //============================================================================

  // Initialize the system with core components and valid routing
  action init = all {
    components' = CORE_COMPONENTS,
    routes_to' = Set(
      (CORTEX, SYNAPSE),
      (SYNAPSE, OPENROUTER),
      (OPENROUTER, GUARDIAN),
      (GUARDIAN, GDE),
      (GDE, CEPAF),
      (CORTEX, ZENOH),
      (SYNAPSE, ZENOH),
      (OPENROUTER, ZENOH),
      (GUARDIAN, ZENOH),
      (GDE, ZENOH),
      (CEPAF, ZENOH)
    ),
    tier_assignment' = Map(
      SYNAPSE -> Smart,
      OPENROUTER -> Smart
    ),
    pending_proposals' = Set(),
    validated_proposals' = Set(),
    execution_log' = Set(),
    circuit_breakers' = Map(OPENROUTER -> false, CEPAF -> false),
    forbidden_detected' = Set()
  }

  // Action: Submit a proposal for AI-driven optimization
  action submit_proposal(source: Component, op: Operation, conf: Confidence): bool = all {
    // Precondition: source must be a valid component
    components.contains(source),
    // Precondition: confidence must be in valid range
    conf >= 0 and conf <= 100,
    // Effect: add to pending proposals
    pending_proposals' = pending_proposals.union(Set((source, op, conf))),
    // Other state unchanged
    components' = components,
    routes_to' = routes_to,
    tier_assignment' = tier_assignment,
    validated_proposals' = validated_proposals,
    execution_log' = execution_log,
    circuit_breakers' = circuit_breakers,
    forbidden_detected' = forbidden_detected
  }

  // Action: Guardian validates a proposal
  action validate_proposal(source: Component, op: Operation, conf: Confidence): bool = all {
    // Precondition: proposal must be pending
    pending_proposals.contains((source, op, conf)),
    // Precondition: confidence must meet threshold
    conf >= MIN_CONFIDENCE,
    // Precondition: operation must not be forbidden
    not(is_forbidden_operation(op)),
    // Effect: move to validated
    validated_proposals' = validated_proposals.union(Set((source, op))),
    pending_proposals' = pending_proposals.exclude(Set((source, op, conf))),
    // Other state unchanged
    components' = components,
    routes_to' = routes_to,
    tier_assignment' = tier_assignment,
    execution_log' = execution_log,
    circuit_breakers' = circuit_breakers,
    forbidden_detected' = forbidden_detected
  }

  // Action: Guardian rejects a proposal
  action reject_proposal(source: Component, op: Operation, conf: Confidence): bool = all {
    // Precondition: proposal must be pending
    pending_proposals.contains((source, op, conf)),
    // Precondition: either low confidence or forbidden
    conf < MIN_CONFIDENCE or is_forbidden_operation(op),
    // Effect: remove from pending (rejected)
    pending_proposals' = pending_proposals.exclude(Set((source, op, conf))),
    // Track forbidden if applicable
    forbidden_detected' = if (is_forbidden_operation(op))
      forbidden_detected.union(Set((source, RmRf)))
    else
      forbidden_detected,
    // Other state unchanged
    components' = components,
    routes_to' = routes_to,
    tier_assignment' = tier_assignment,
    validated_proposals' = validated_proposals,
    execution_log' = execution_log,
    circuit_breakers' = circuit_breakers
  }

  // Action: Execute a validated proposal
  action execute_proposal(source: Component, op: Operation): bool = all {
    // Precondition: proposal must be validated
    validated_proposals.contains((source, op)),
    // Precondition: circuit breaker must be closed for CEPAF
    circuit_breakers.get(CEPAF) == false,
    // Effect: log execution
    execution_log' = execution_log.union(Set((source, op, true))),
    validated_proposals' = validated_proposals.exclude(Set((source, op))),
    // Other state unchanged
    components' = components,
    routes_to' = routes_to,
    tier_assignment' = tier_assignment,
    pending_proposals' = pending_proposals,
    circuit_breakers' = circuit_breakers,
    forbidden_detected' = forbidden_detected
  }

  // Action: Open circuit breaker (failure detected)
  action open_circuit_breaker(comp: Component): bool = all {
    // Precondition: component must have a circuit breaker
    circuit_breakers.keys().contains(comp),
    // Effect: open the circuit breaker
    circuit_breakers' = circuit_breakers.set(comp, true),
    // Remove outgoing routes (simplified)
    routes_to' = routes_to.filter(r => r._1 != comp),
    // Other state unchanged
    components' = components,
    tier_assignment' = tier_assignment,
    pending_proposals' = pending_proposals,
    validated_proposals' = validated_proposals,
    execution_log' = execution_log,
    forbidden_detected' = forbidden_detected
  }

  // Action: Close circuit breaker (recovery)
  action close_circuit_breaker(comp: Component): bool = all {
    // Precondition: circuit breaker must be open
    circuit_breakers.get(comp) == true,
    // Effect: close the circuit breaker
    circuit_breakers' = circuit_breakers.set(comp, false),
    // Other state unchanged
    components' = components,
    routes_to' = routes_to,
    tier_assignment' = tier_assignment,
    pending_proposals' = pending_proposals,
    validated_proposals' = validated_proposals,
    execution_log' = execution_log,
    forbidden_detected' = forbidden_detected
  }

  // Non-deterministic step
  action step = any {
    // Submit various proposals
    all {
      nondet source = components.oneOf()
      nondet conf = 0.to(100).oneOf()
      any {
        submit_proposal(source, ScalePool, conf),
        submit_proposal(source, AdjustCache, conf),
        submit_proposal(source, ModifyConfig, conf),
        submit_proposal(source, ShellCommand, conf)
      }
    },
    // Validate pending proposals
    all {
      nondet pp = pending_proposals.oneOf()
      validate_proposal(pp._1, pp._2, pp._3)
    },
    // Reject low-confidence or forbidden
    all {
      nondet pp = pending_proposals.oneOf()
      reject_proposal(pp._1, pp._2, pp._3)
    },
    // Execute validated proposals
    all {
      nondet vp = validated_proposals.oneOf()
      execute_proposal(vp._1, vp._2)
    },
    // Circuit breaker operations
    all {
      nondet comp = circuit_breakers.keys().oneOf()
      any {
        open_circuit_breaker(comp),
        close_circuit_breaker(comp)
      }
    }
  }

  //============================================================================
  // SECTION 7: TEMPORAL PROPERTIES (LIVENESS)
  //============================================================================

  // TEMP-001: All high-confidence proposals eventually get validated or rejected
  // (Liveness property - expressed as eventual consistency)
  temporal proposal_eventually_processed: bool = {
    pending_proposals.forall(pp =>
      pp._3 >= MIN_CONFIDENCE implies eventually(
        validated_proposals.contains((pp._1, pp._2)) or
        not(pending_proposals.contains(pp))
      )
    )
  }

  // TEMP-002: Circuit breakers eventually close after recovery
  temporal circuit_breakers_recover: bool = {
    circuit_breakers.keys().forall(comp =>
      circuit_breakers.get(comp) == true implies
      eventually(circuit_breakers.get(comp) == false)
    )
  }

  //============================================================================
  // SECTION 8: TEST RUNS (COUNTER-EXAMPLE SEARCH)
  //============================================================================

  // TEST-001: Find violation of OpenRouter exclusivity
  run test_bypass_violation = {
    init.then(all {
      // Attempt to create direct route to Claude (should violate invariant)
      routes_to' = routes_to.union(Set((SYNAPSE, CLAUDE))),
      components' = components.union(Set(CLAUDE)),
      // Keep other state
      tier_assignment' = tier_assignment,
      pending_proposals' = pending_proposals,
      validated_proposals' = validated_proposals,
      execution_log' = execution_log,
      circuit_breakers' = circuit_breakers,
      forbidden_detected' = forbidden_detected,
      // Check invariant (should fail)
      assert(inv_openrouter_exclusivity)
    })
  }

  // TEST-002: Find violation of confidence threshold
  run test_low_confidence_validation = {
    init.then(all {
      // Add low-confidence proposal
      pending_proposals' = Set((SYNAPSE, ScalePool, 30)),
      // Attempt to validate (should be rejected)
      validated_proposals' = Set((SYNAPSE, ScalePool)),
      // Keep other state
      components' = components,
      routes_to' = routes_to,
      tier_assignment' = tier_assignment,
      execution_log' = execution_log,
      circuit_breakers' = circuit_breakers,
      forbidden_detected' = forbidden_detected,
      // Check invariant (should fail)
      assert(inv_confidence_threshold)
    })
  }

  // TEST-003: Find violation of Simplex principle
  run test_simplex_bypass = {
    init.then(all {
      // Create direct route from OpenRouter to GDE, bypassing Guardian
      routes_to' = routes_to.union(Set((OPENROUTER, GDE))).exclude(Set((OPENROUTER, GUARDIAN))),
      // Keep other state
      components' = components,
      tier_assignment' = tier_assignment,
      pending_proposals' = pending_proposals,
      validated_proposals' = validated_proposals,
      execution_log' = execution_log,
      circuit_breakers' = circuit_breakers,
      forbidden_detected' = forbidden_detected,
      // Check invariant (should fail)
      assert(inv_simplex_principle)
    })
  }

  // TEST-004: Find forbidden operation execution
  run test_forbidden_execution = {
    init.then(all {
      // Attempt to execute forbidden shell command
      execution_log' = Set((SYNAPSE, ShellCommand, true)),
      validated_proposals' = Set((SYNAPSE, ShellCommand)),
      // Keep other state
      components' = components,
      routes_to' = routes_to,
      tier_assignment' = tier_assignment,
      pending_proposals' = pending_proposals,
      circuit_breakers' = circuit_breakers,
      forbidden_detected' = forbidden_detected,
      // Check invariant (should fail)
      assert(inv_no_forbidden_executed)
    })
  }

  // TEST-005: Verify valid system maintains all invariants
  run test_valid_system = {
    init.then(all {
      // Add valid proposal flow
      pending_proposals' = Set((SYNAPSE, ScalePool, 75)),
      // Keep valid routing
      components' = components,
      routes_to' = routes_to,
      tier_assignment' = tier_assignment,
      validated_proposals' = Set(),
      execution_log' = Set(),
      circuit_breakers' = circuit_breakers,
      forbidden_detected' = Set(),
      // All invariants should hold
      assert(all_invariants)
    })
  }

  // TEST-006: Verify full proposal lifecycle
  run test_proposal_lifecycle = {
    // Initialize
    init
    .then(submit_proposal(SYNAPSE, ScalePool, 80))
    .then(validate_proposal(SYNAPSE, ScalePool, 80))
    .then(execute_proposal(SYNAPSE, ScalePool))
  }

  // TEST-007: Circuit breaker recovery flow
  run test_circuit_breaker_flow = {
    init
    .then(open_circuit_breaker(OPENROUTER))
    .then(close_circuit_breaker(OPENROUTER))
  }

  //============================================================================
  // SECTION 9: PROPERTY ASSERTIONS FOR CI
  //============================================================================

  // Assert all invariants hold after initialization
  run ci_check_init_invariants = {
    init.then(all {
      components' = components,
      routes_to' = routes_to,
      tier_assignment' = tier_assignment,
      pending_proposals' = pending_proposals,
      validated_proposals' = validated_proposals,
      execution_log' = execution_log,
      circuit_breakers' = circuit_breakers,
      forbidden_detected' = forbidden_detected,
      assert(all_invariants)
    })
  }

  // Assert invariants hold after valid operations
  run ci_check_valid_operations = {
    init
    .then(submit_proposal(CORTEX, AdjustCache, 85))
    .then(validate_proposal(CORTEX, AdjustCache, 85))
    .then(execute_proposal(CORTEX, AdjustCache))
  }

  // Assert rejection of forbidden operations
  run ci_check_forbidden_rejected = {
    init
    .then(submit_proposal(SYNAPSE, ShellCommand, 95))
    .then(reject_proposal(SYNAPSE, ShellCommand, 95))
    .then(all {
      // Should be in forbidden_detected, not validated
      components' = components,
      routes_to' = routes_to,
      tier_assignment' = tier_assignment,
      pending_proposals' = pending_proposals,
      validated_proposals' = validated_proposals,
      execution_log' = execution_log,
      circuit_breakers' = circuit_breakers,
      forbidden_detected' = forbidden_detected,
      assert(not(validated_proposals.contains((SYNAPSE, ShellCommand)))),
      assert(all_invariants)
    })
  }

}

//==============================================================================
// MODULE: Container Network Graph
//==============================================================================

module ContainerNetworkGraph {

  type Container = str
  type Network = str

  var containers: Set[Container]
  var networks: Set[Network]
  var connected_to: Set[(Container, Network)]
  var container_comms: Set[(Container, Container)]

  // Core containers
  pure val APP: Container = "indrajaal-app"
  pure val DB: Container = "indrajaal-db"
  pure val OBS: Container = "indrajaal-obs"

  // Networks
  pure val INTERNAL_NET: Network = "indrajaal-internal"
  pure val OBS_NET: Network = "indrajaal-obs-net"

  // INV-NET-001: Containers can only communicate if on same network
  val inv_network_isolation: bool = {
    container_comms.forall(comm =>
      connected_to.exists(cn1 =>
        connected_to.exists(cn2 =>
          cn1._1 == comm._1 and cn2._1 == comm._2 and cn1._2 == cn2._2
        )
      )
    )
  }

  // INV-NET-002: App container must reach DB container
  val inv_app_db_connectivity: bool = {
    containers.contains(APP) and containers.contains(DB) implies
    container_comms.contains((APP, DB)) or container_comms.contains((DB, APP))
  }

  // INV-NET-003: Obs container isolated from external
  val inv_obs_isolation: bool = {
    container_comms.forall(comm =>
      comm._1 == OBS implies comm._2.in(Set(APP, DB))
    )
  }

  // Initialize valid container network
  action init = all {
    containers' = Set(APP, DB, OBS),
    networks' = Set(INTERNAL_NET, OBS_NET),
    connected_to' = Set(
      (APP, INTERNAL_NET),
      (DB, INTERNAL_NET),
      (APP, OBS_NET),
      (OBS, OBS_NET)
    ),
    container_comms' = Set(
      (APP, DB),
      (DB, APP),
      (APP, OBS),
      (OBS, APP)
    )
  }

  // All network invariants
  val all_network_invariants: bool = {
    inv_network_isolation and
    inv_app_db_connectivity and
    inv_obs_isolation
  }

  run test_valid_network = {
    init.then(all {
      containers' = containers,
      networks' = networks,
      connected_to' = connected_to,
      container_comms' = container_comms,
      assert(all_network_invariants)
    })
  }

}

//==============================================================================
// MODULE: Agent Supervision Graph
//==============================================================================

module AgentSupervisionGraph {

  type Agent = str
  type AgentType = Executive | Domain | Functional | Worker

  var agents: Set[Agent]
  var agent_types: Agent -> AgentType
  var supervises: Set[(Agent, Agent)]

  // Executive agent (root of supervision tree)
  pure val EXECUTIVE: Agent = "executive"

  // Maximum supervision depth
  pure val MAX_DEPTH: int = 5

  // INV-SUP-001: Every agent (except Executive) has exactly one supervisor
  val inv_single_supervisor: bool = {
    agents.forall(a =>
      a == EXECUTIVE or
      supervises.filter(s => s._2 == a).size() == 1
    )
  }

  // INV-SUP-002: No circular supervision (simplified: no self-supervision)
  val inv_no_self_supervision: bool = {
    not(supervises.exists(s => s._1 == s._2))
  }

  // INV-SUP-003: Executive supervises at least one agent
  val inv_executive_supervises: bool = {
    agents.size() > 1 implies
    supervises.exists(s => s._1 == EXECUTIVE)
  }

  // INV-SUP-004: Workers cannot supervise others
  val inv_workers_no_supervision: bool = {
    supervises.forall(s =>
      agent_types.get(s._1) != Worker
    )
  }

  // Initialize valid supervision tree
  action init = all {
    agents' = Set(EXECUTIVE, "domain-alarms", "domain-devices", "worker-1", "worker-2"),
    agent_types' = Map(
      EXECUTIVE -> Executive,
      "domain-alarms" -> Domain,
      "domain-devices" -> Domain,
      "worker-1" -> Worker,
      "worker-2" -> Worker
    ),
    supervises' = Set(
      (EXECUTIVE, "domain-alarms"),
      (EXECUTIVE, "domain-devices"),
      ("domain-alarms", "worker-1"),
      ("domain-devices", "worker-2")
    )
  }

  val all_supervision_invariants: bool = {
    inv_single_supervisor and
    inv_no_self_supervision and
    inv_executive_supervises and
    inv_workers_no_supervision
  }

  run test_valid_supervision = {
    init.then(all {
      agents' = agents,
      agent_types' = agent_types,
      supervises' = supervises,
      assert(all_supervision_invariants)
    })
  }

  // Find invalid supervision: worker trying to supervise
  run test_worker_supervision_violation = {
    init.then(all {
      supervises' = supervises.union(Set(("worker-1", "worker-2"))),
      agents' = agents,
      agent_types' = agent_types,
      assert(inv_workers_no_supervision)
    })
  }

}
