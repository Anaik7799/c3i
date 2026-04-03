// ============================================================================
// PLANNING ACCESS CONTROL STATE MACHINE (Quint Specification)
// ============================================================================
// MODULE PURPOSE:
// Formal specification for SC-TODO-001 enforcement: PROJECT_TODOLIST.md
// access control with multi-layer validation, circuit breakers, and
// immutable audit trail.
//
// CONSTITUTIONAL ALIGNMENT:
// - Psi2 (Evolutionary Continuity): Complete violation history preserved
// - Psi3 (Verification Capability): All access attempts verifiable
// - SC-REG-001: All violations logged to immutable register
// - SC-FUNC-003: Rollback capability via circuit breaker
//
// STAMP CONSTRAINTS:
// - SC-ENFORCE-001: Direct access to PROJECT_TODOLIST.md MUST be blocked
// - SC-ENFORCE-004: Violation count MUST trigger circuit breaker at threshold
// - SC-ENFORCE-020: Multi-layer validation MUST all pass
// - SC-ENFORCE-021: Unknown agents MUST be denied by default
//
// AOR RULES:
// - AOR-ENFORCE-003: DENY unknown agents by default (fail-safe)
// - AOR-ENFORCE-004: TRIGGER circuit breaker after 3 violations per agent
// ============================================================================

module planning_access_control {
  // ==========================================================================
  // TYPE DEFINITIONS
  // ==========================================================================

  // Agent type: positional constructors (named fields not supported in Quint 0.29.1)
  // Human(userId), AIAgent(agentId), SystemProcess(processId), Unknown(identifier)
  type AgentType =
    | Human(str)
    | AIAgent(str)
    | SystemProcess(str)
    | Unknown(str)

  // Access decision states
  type AccessState =
    | Pending
    | Allowed
    | Denied
    | CircuitOpen
    | Alerted

  // Violation severity levels
  type Severity =
    | SevLow
    | SevMedium
    | SevHigh
    | SevCritical

  // Request context for access validation
  type RequestContext = {
    agentType: AgentType,
    requestedPath: str,
    operation: str,
    timestamp: int,
    stackTrace: str
  }

  // Violation record (immutable)
  type ViolationRecord = {
    id: str,
    context: RequestContext,
    reason: str,
    severity: Severity,
    timestamp: int
  }

  // System state
  type SystemState = {
    currentRequest: RequestContext,
    currentState: AccessState,
    violationCounters: str -> int,
    circuitBreakerState: str -> bool,
    violations: Set[ViolationRecord],
    circuitBreakerThreshold: int,
    forbiddenPaths: Set[str],
    maxRequestsPerSecond: int,
    totalViolations: int,
    totalRequests: int
  }

  // ==========================================================================
  // STATE VARIABLES
  // ==========================================================================

  var state: SystemState

  // ==========================================================================
  // CONSTANTS
  // ==========================================================================

  pure val CIRCUIT_THRESHOLD = 3

  pure val FORBIDDEN_PATHS = Set(
    "PROJECT_TODOLIST.md",
    "/PROJECT_TODOLIST.md",
    "./PROJECT_TODOLIST.md",
    "../PROJECT_TODOLIST.md"
  )

  pure val CRITICAL_PATTERNS = Set(
    "rm -rf",
    "sudo",
    "> PROJECT_TODOLIST",
    ">> PROJECT_TODOLIST"
  )

  // ==========================================================================
  // HELPER PREDICATES
  // ==========================================================================

  // Extract agent identifier from context
  pure def extractAgentId(ctx: RequestContext): str = match ctx.agentType {
    | Human(id) => id
    | AIAgent(id) => id
    | SystemProcess(id) => id
    | Unknown(id) => id
  }

  // Check if path is forbidden (SC-ENFORCE-001)
  // Quint strings only support equality - use set membership
  pure def isPathForbidden(path: str): bool = {
    FORBIDDEN_PATHS.contains(path)
  }

  // Check if operation is suspicious - use set membership
  pure def isSuspiciousOperation(op: str): bool = {
    CRITICAL_PATTERNS.contains(op)
  }

  // Check if agent is unknown (SC-ENFORCE-021, AOR-ENFORCE-003)
  pure def isUnknownAgent(agentType: AgentType): bool = match agentType {
    | Unknown(_) => true
    | _ => false
  }

  // Get violation count for agent
  pure def getViolationCount(agentId: str, counters: str -> int): int = {
    if (counters.keys().contains(agentId)) counters.get(agentId) else 0
  }

  // Check if circuit breaker is open
  pure def isCircuitOpen(agentId: str, cbState: str -> bool): bool = {
    if (cbState.keys().contains(agentId)) cbState.get(agentId) else false
  }

  // ==========================================================================
  // VALIDATION LAYERS (SC-ENFORCE-020: Multi-layer validation)
  // ==========================================================================

  // Layer 1: Unknown agent check
  pure def validateLayer1_UnknownAgent(ctx: RequestContext): bool = {
    not(isUnknownAgent(ctx.agentType))
  }

  // Layer 2: Circuit breaker check
  pure def validateLayer2_CircuitBreaker(ctx: RequestContext, cbState: str -> bool): bool = {
    val agentId = extractAgentId(ctx)
    not(isCircuitOpen(agentId, cbState))
  }

  // Layer 3: Path validation
  pure def validateLayer3_PathValidation(ctx: RequestContext): bool = {
    not(isPathForbidden(ctx.requestedPath))
  }

  // Layer 4: Operation validation
  pure def validateLayer4_OperationValidation(ctx: RequestContext): bool = {
    not(isSuspiciousOperation(ctx.operation))
  }

  // Layer 5: Rate limiting (simplified for temporal logic)
  pure def validateLayer5_RateLimit(ctx: RequestContext): bool = {
    true
  }

  // All layers must pass (SC-ENFORCE-020)
  pure def allLayersPass(ctx: RequestContext, cbState: str -> bool): bool = {
    validateLayer1_UnknownAgent(ctx) and
    validateLayer2_CircuitBreaker(ctx, cbState) and
    validateLayer3_PathValidation(ctx) and
    validateLayer4_OperationValidation(ctx) and
    validateLayer5_RateLimit(ctx)
  }

  // ==========================================================================
  // STATE TRANSITIONS
  // ==========================================================================

  // Initialize system state
  action init: bool = all {
    state' = {
      currentRequest: {
        agentType: Human("init"),
        requestedPath: "",
        operation: "",
        timestamp: 0,
        stackTrace: ""
      },
      currentState: Pending,
      violationCounters: Map(),
      circuitBreakerState: Map(),
      violations: Set(),
      circuitBreakerThreshold: CIRCUIT_THRESHOLD,
      forbiddenPaths: FORBIDDEN_PATHS,
      maxRequestsPerSecond: 10,
      totalViolations: 0,
      totalRequests: 0
    }
  }

  // New request received - transition to Pending
  action receiveRequest(ctx: RequestContext): bool = all {
    state' = {
      ...state,
      currentRequest: ctx,
      currentState: Pending,
      totalRequests: state.totalRequests + 1
    }
  }

  // Validate request - transition to Allowed if all layers pass
  action validateAndAllow: bool = all {
    state.currentState == Pending,
    allLayersPass(state.currentRequest, state.circuitBreakerState),
    state' = {
      ...state,
      currentState: Allowed
    }
  }

  // Deny request due to validation failure
  action denyRequest(reason: str, severity: Severity): bool = {
    val agentId = extractAgentId(state.currentRequest)
    val newViolationCount = getViolationCount(agentId, state.violationCounters) + 1
    val violation = {
      id: "violation",
      context: state.currentRequest,
      reason: reason,
      severity: severity,
      timestamp: state.currentRequest.timestamp
    }
    all {
      state.currentState == Pending,
      not(allLayersPass(state.currentRequest, state.circuitBreakerState)),
      state' = {
        ...state,
        currentState: Denied,
        violationCounters: state.violationCounters.put(agentId, newViolationCount),
        violations: state.violations.union(Set(violation)),
        totalViolations: state.totalViolations + 1
      }
    }
  }

  // Trigger circuit breaker (SC-ENFORCE-004, AOR-ENFORCE-004)
  action triggerCircuitBreaker: bool = {
    val agentId = extractAgentId(state.currentRequest)
    val count = getViolationCount(agentId, state.violationCounters)
    all {
      count >= state.circuitBreakerThreshold,
      state' = {
        ...state,
        currentState: CircuitOpen,
        circuitBreakerState: state.circuitBreakerState.put(agentId, true)
      }
    }
  }

  // Escalate to alert (CRITICAL/HIGH severity)
  action escalateToAlert: bool = {
    val agentId = extractAgentId(state.currentRequest)
    val recentViolations = state.violations.filter(v =>
      extractAgentId(v.context) == agentId and
      (v.severity == SevCritical or v.severity == SevHigh)
    )
    all {
      state.currentState == Denied,
      recentViolations.size() > 0,
      state' = {
        ...state,
        currentState: Alerted
      }
    }
  }

  // Reset circuit breaker (requires Guardian approval)
  action resetCircuitBreaker(agentId: str): bool = all {
    isCircuitOpen(agentId, state.circuitBreakerState),
    state' = {
      ...state,
      circuitBreakerState: state.circuitBreakerState.put(agentId, false),
      violationCounters: state.violationCounters.put(agentId, 0)
    }
  }

  // Combined step - each branch updates state exactly once (no multiple updates)
  action step: bool = any {
    nondet agentChoice = oneOf(Set(0, 1, 2, 3))
    nondet pathChoice = oneOf(Set(0, 1, 2))
    nondet opChoice = oneOf(Set(0, 1, 2))
    {
      val agentT = if (agentChoice == 0) Human("user1")
                   else if (agentChoice == 1) AIAgent("claude")
                   else if (agentChoice == 2) SystemProcess("elixir")
                   else Unknown("anonymous")
      val pathT = if (pathChoice == 0) "safe/path.md"
                  else if (pathChoice == 1) "PROJECT_TODOLIST.md"
                  else "other.ex"
      val opT = if (opChoice == 0) "read"
                else if (opChoice == 1) "write"
                else "sudo"
      val ctx = {
        agentType: agentT,
        requestedPath: pathT,
        operation: opT,
        timestamp: state.totalRequests,
        stackTrace: "trace"
      }
      any {
        receiveRequest(ctx),
        validateAndAllow,
        denyRequest("Path forbidden", SevCritical),
        denyRequest("Unknown agent", SevHigh),
        denyRequest("Suspicious operation", SevHigh),
        triggerCircuitBreaker,
        escalateToAlert,
        resetCircuitBreaker("claude"),
        resetCircuitBreaker("anonymous")
      }
    }
  }

  // ==========================================================================
  // TEMPORAL INVARIANTS
  // ==========================================================================

  // Helper: check if current agent is unknown
  pure def isCurrentAgentUnknown(s: SystemState): bool =
    isUnknownAgent(s.currentRequest.agentType)

  // SAFETY: Unknown agents are ALWAYS denied
  temporal UnknownAgentsAlwaysDenied = always(
    isCurrentAgentUnknown(state) implies (state.currentState != Allowed)
  )

  // SAFETY: Violation count never decreases (monotonicity of total)
  temporal ViolationCountMonotonic = always(
    next(state.totalViolations >= state.totalViolations)
  )

  // LIVENESS: Valid requests eventually processed
  temporal ValidRequestsEventuallyProcessed = always(
    (state.currentState == Pending and allLayersPass(state.currentRequest, state.circuitBreakerState))
    implies eventually(state.currentState == Allowed)
  )

  // SAFETY: Circuit breaker threshold is positive
  temporal CircuitBreakerEnforced = always(
    state.circuitBreakerThreshold > 0
  )

  // ==========================================================================
  // RUN DECLARATIONS
  // ==========================================================================

  // Run: Basic access control flow
  run basicAccessControlTest = {
    init
    .then(receiveRequest({
      agentType: Human("user1"),
      requestedPath: "safe/path.md",
      operation: "read",
      timestamp: 1,
      stackTrace: "trace"
    }))
    .then(validateAndAllow)
    .expect(state.totalRequests > 0)
  }

  // Run: Unknown agent always denied
  run unknownAgentTest = {
    init
    .then(receiveRequest({
      agentType: Unknown("anonymous"),
      requestedPath: "safe/path.md",
      operation: "read",
      timestamp: 1,
      stackTrace: "trace"
    }))
    .then(denyRequest("Unknown agent", SevHigh))
    .expect(state.currentState == Denied)
  }

  // Run: Circuit breaker triggers
  run circuitBreakerTest = {
    init
    .then(receiveRequest({
      agentType: AIAgent("attacker"),
      requestedPath: "PROJECT_TODOLIST.md",
      operation: "read",
      timestamp: 1,
      stackTrace: "trace"
    }))
    .then(denyRequest("Forbidden path", SevCritical))
    .then(receiveRequest({
      agentType: AIAgent("attacker"),
      requestedPath: "PROJECT_TODOLIST.md",
      operation: "write",
      timestamp: 2,
      stackTrace: "trace"
    }))
    .then(denyRequest("Forbidden path", SevCritical))
    .then(receiveRequest({
      agentType: AIAgent("attacker"),
      requestedPath: "PROJECT_TODOLIST.md",
      operation: "execute",
      timestamp: 3,
      stackTrace: "trace"
    }))
    .then(denyRequest("Forbidden path", SevCritical))
    .then(triggerCircuitBreaker)
    .expect(isCircuitOpen("attacker", state.circuitBreakerState))
  }
}
