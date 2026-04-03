// ============================================================================
// PLANNING INTEGRATED SYSTEM MODEL (Quint Specification)
// ============================================================================
// MODULE PURPOSE:
// Comprehensive formal specification integrating all Planning System modules:
// - Access Control (SC-TODO-001 enforcement)
// - Circuit Breaker (threshold-based failure isolation)
// - Orchestration (Zenoh pub/sub, OODA loop)
// - Safety Kernel (Constitutional invariants, rollback)
//
// This model proves system-wide safety and liveness properties across all
// layers of the Planning System architecture.
//
// CONSTITUTIONAL ALIGNMENT:
// - Psi0 (Existence): System survives ALL operations
// - Psi1 (Regeneration): State recoverable from SQLite/DuckDB
// - Psi2 (Evolutionary Continuity): Complete history preserved
// - Psi3 (Verification Capability): All changes verifiable
// - Omega0 (Founder's Directive): Resource acquisition for survival
//
// CRITICAL STAMP CONSTRAINTS:
// - SC-TODO-001: PROJECT_TODOLIST.md access STRICTLY FORBIDDEN for AI agents
// - SC-FUNC-001: System MUST compile at all times
// - SC-FUNC-003: Rollback path MUST exist for every change
// - SC-ZENOH-001: Zenoh NIF MUST be loaded on ALL nodes
// - SC-BIO-001: OODA cycle < 100ms
// - SC-PRAJNA-001: Guardian approval for all mutations
//
// VERIFICATION GOALS:
// 1. Deadlock freedom
// 2. Liveness (all valid requests eventually processed)
// 3. Safety (invariants never violated)
// 4. Availability (quorum maintained)
// 5. Security (unauthorized access always blocked)
// ============================================================================

module planning_integrated {
  // ==========================================================================
  // COMPOSITE TYPE DEFINITIONS
  // ==========================================================================

  /// Agent classification - positional constructors only (Quint 0.29.1)
  // AIAgent(str) encodes agentId; model info encoded in id string if needed
  type AgentType =
    | Human(str)
    | AIAgent(str)
    | SystemProcess(str)
    | Unknown(str)

  /// Access states
  type AccessState =
    | Pending
    | Allowed
    | Denied
    | CircuitOpen
    | Alerted

  /// Circuit states
  type CircuitState =
    | Closed
    | Open
    | HalfOpen

  /// Service states
  type ServiceState =
    | Offline
    | Starting
    | Online
    | Degraded
    | Stopping

  /// System health
  type SystemHealth =
    | Functional
    | DegradedHealth
    | Critical
    | Failed

  /// OODA phases
  type OODAPhase =
    | Observe
    | Orient
    | Decide
    | Act

  /// Message types
  type MessageType =
    | TaskCreated
    | TaskUpdated
    | TaskCompleted
    | AccessViolation
    | CircuitTriggered
    | HealthPing
    | SystemAlert

  /// Request context
  type Request = {
    id: str,
    agentType: AgentType,
    path: str,
    operation: str,
    timestamp: int,
    guardianApproved: bool
  }

  /// Violation record
  type Violation = {
    id: str,
    request: Request,
    reason: str,
    severity: str,
    timestamp: int
  }

  /// Message
  type Message = {
    id: str,
    msgType: MessageType,
    sender: str,
    payload: str,
    timestamp: int,
    sequenceNum: int
  }

  /// Service
  type Service = {
    name: str,
    svcState: ServiceState,
    zenohConnected: bool,
    lastHealthPing: int
  }

  /// Checkpoint
  type Checkpoint = {
    id: str,
    timestamp: int,
    systemHealth: SystemHealth,
    invariantsHeld: Set[str]
  }

  /// Integrated system state
  type IntegratedState = {
    // Access Control Layer
    accessState: AccessState,
    currentRequest: Request,
    violations: Set[Violation],
    violationCounters: str -> int,

    // Circuit Breaker Layer
    circuits: str -> CircuitState,
    circuitThreshold: int,

    // Orchestration Layer
    services: str -> Service,
    messageQueue: List[Message],
    nextSeqNum: int,
    zenohOnline: bool,

    // OODA Loop
    oodaPhase: OODAPhase,
    oodaCycleCount: int,
    oodaStartTime: int,

    // Safety Kernel Layer
    systemHealth: SystemHealth,
    invariantsHeld: Set[str],
    checkpoints: List[Checkpoint],
    canRollback: bool,

    // Immutable Register
    registerEntries: Set[str],

    // Statistics
    totalRequests: int,
    totalViolations: int,
    totalCircuitOpens: int,
    totalRollbacks: int,
    currentTime: int
  }

  // ==========================================================================
  // STATE VARIABLES
  // ==========================================================================

  var state: IntegratedState

  // ==========================================================================
  // CONSTANTS
  // ==========================================================================

  pure val CIRCUIT_THRESHOLD = 3
  pure val OODA_BUDGET_MS = 100
  pure val QUORUM_SIZE = 2

  pure val FORBIDDEN_PATHS = Set(
    "PROJECT_TODOLIST.md",
    "/PROJECT_TODOLIST.md"
  )

  pure val SERVICE_NAMES = Set(
    "planning-cli",
    "planning-service",
    "smriti-db"
  )

  pure val CORE_INVARIANTS = Set(
    "Psi0-Existence",
    "Psi1-Regeneration",
    "Psi2-History",
    "Psi3-Verification",
    "SC-TODO-001",
    "SC-FUNC-001"
  )

  // ==========================================================================
  // HELPER PREDICATES
  // ==========================================================================

  /// Extract agent ID from AgentType
  pure def extractAgentId(agent: AgentType): str = match agent {
    | Human(id) => id
    | AIAgent(id) => id
    | SystemProcess(id) => id
    | Unknown(id) => id
  }

  /// Check if path is forbidden
  pure def isPathForbidden(path: str): bool = {
    FORBIDDEN_PATHS.contains(path)
  }

  /// Check if agent is unknown
  pure def isUnknownAgent(agent: AgentType): bool = match agent {
    | Unknown(_) => true
    | _ => false
  }

  /// Check if agent is an AI agent
  pure def isAIAgent(agent: AgentType): bool = match agent {
    | AIAgent(_) => true
    | _ => false
  }

  /// Get violation count (replaces .withDefault)
  pure def getViolationCount(agentId: str, s: IntegratedState): int = {
    if (s.violationCounters.keys().contains(agentId)) s.violationCounters.get(agentId) else 0
  }

  /// Get circuit state (replaces .withDefault)
  pure def getCircuitState(agentId: str, s: IntegratedState): CircuitState = {
    if (s.circuits.keys().contains(agentId)) s.circuits.get(agentId) else Closed
  }

  /// Check if circuit is open
  pure def isCircuitOpen(agentId: str, s: IntegratedState): bool = {
    getCircuitState(agentId, s) == Open
  }

  /// Check if service is online (replaces .map().withDefault())
  pure def isServiceOnline(name: str, s: IntegratedState): bool = {
    if (s.services.keys().contains(name)) s.services.get(name).svcState == Online else false
  }

  /// Count online services
  pure def countOnlineServices(s: IntegratedState): int = {
    SERVICE_NAMES.filter(name => isServiceOnline(name, s)).size()
  }

  /// Check quorum
  pure def hasQuorum(s: IntegratedState): bool = {
    countOnlineServices(s) >= QUORUM_SIZE
  }

  /// Check if all core invariants hold
  pure def coreInvariantsHold(s: IntegratedState): bool = {
    CORE_INVARIANTS.forall(inv => s.invariantsHeld.contains(inv))
  }

  /// Check if system is functional
  pure def isFunctional(s: IntegratedState): bool = {
    s.systemHealth == Functional and coreInvariantsHold(s)
  }

  /// Check OODA cycle within budget
  pure def oodaWithinBudget(s: IntegratedState): bool = {
    (s.currentTime - s.oodaStartTime) <= OODA_BUDGET_MS
  }

  /// Multi-layer access validation
  pure def accessAllowed(req: Request, s: IntegratedState): bool = {
    val agentId = extractAgentId(req.agentType)

    // Layer 1: Unknown agent check
    not(isUnknownAgent(req.agentType)) and

    // Layer 2: Circuit breaker check
    not(isCircuitOpen(agentId, s)) and

    // Layer 3: Path validation (SC-TODO-001)
    not(isPathForbidden(req.path)) and

    // Layer 4: Guardian approval for mutations
    (req.operation == "read" or req.guardianApproved) and

    // Layer 5: System health
    isFunctional(s)
  }

  // ==========================================================================
  // STATE TRANSITIONS
  // ==========================================================================

  /// Initialize integrated system
  action init: bool = {
    val initCheckpoint = {
      id: "checkpoint-0",
      timestamp: 0,
      systemHealth: Functional,
      invariantsHeld: CORE_INVARIANTS
    }
    all {
      state' = {
        // Access Control
        accessState: Pending,
        currentRequest: {
          id: "init",
          agentType: SystemProcess("init"),
          path: "",
          operation: "",
          timestamp: 0,
          guardianApproved: true
        },
        violations: Set(),
        violationCounters: Map(),

        // Circuit Breaker
        circuits: Map(),
        circuitThreshold: CIRCUIT_THRESHOLD,

        // Orchestration
        services: Map(
          "planning-cli" -> {
            name: "planning-cli",
            svcState: Offline,
            zenohConnected: false,
            lastHealthPing: 0
          },
          "planning-service" -> {
            name: "planning-service",
            svcState: Offline,
            zenohConnected: false,
            lastHealthPing: 0
          },
          "smriti-db" -> {
            name: "smriti-db",
            svcState: Offline,
            zenohConnected: false,
            lastHealthPing: 0
          }
        ),
        messageQueue: List(),
        nextSeqNum: 1,
        zenohOnline: false,

        // OODA
        oodaPhase: Observe,
        oodaCycleCount: 0,
        oodaStartTime: 0,

        // Safety Kernel
        systemHealth: Functional,
        invariantsHeld: CORE_INVARIANTS,
        checkpoints: List(initCheckpoint),
        canRollback: false,

        // Register
        registerEntries: Set("INIT"),

        // Statistics
        totalRequests: 0,
        totalViolations: 0,
        totalCircuitOpens: 0,
        totalRollbacks: 0,
        currentTime: 0
      }
    }
  }

  /// Start Zenoh router
  action startZenoh: bool = all {
    not(state.zenohOnline),
    state' = {
      ...state,
      zenohOnline: true,
      registerEntries: state.registerEntries.union(Set("ZENOH-STARTED"))
    }
  }

  /// Start service - replaces .map().withDefault() with if-then-else
  action startService(name: str): bool = {
    val svcExists = state.services.keys().contains(name)
    val svcOffline = if (svcExists) state.services.get(name).svcState == Offline else false
    val svc = if (svcExists) state.services.get(name)
              else { name: name, svcState: Offline, zenohConnected: false, lastHealthPing: 0 }
    all {
      state.zenohOnline,
      svcOffline,
      state' = {
        ...state,
        services: state.services.put(name, {
          ...svc,
          svcState: Online,
          zenohConnected: true,
          lastHealthPing: state.currentTime
        })
      }
    }
  }

  /// Receive access request
  action receiveRequest(req: Request): bool = all {
    isFunctional(state),
    state' = {
      ...state,
      accessState: Pending,
      currentRequest: req,
      totalRequests: state.totalRequests + 1
    }
  }

  /// Process request - ALLOW
  action allowRequest: bool = all {
    state.accessState == Pending,
    accessAllowed(state.currentRequest, state),
    state' = {
      ...state,
      accessState: Allowed,
      registerEntries: state.registerEntries.union(Set("ACCESS-ALLOWED"))
    }
  }

  /// Process request - DENY (constant id, no toString)
  action denyRequest(reason: str, severity: str): bool = {
    val agentId = extractAgentId(state.currentRequest.agentType)
    val newCount = getViolationCount(agentId, state) + 1
    val violation = {
      id: "violation",
      request: state.currentRequest,
      reason: reason,
      severity: severity,
      timestamp: state.currentTime
    }
    all {
      state.accessState == Pending,
      not(accessAllowed(state.currentRequest, state)),
      state' = {
        ...state,
        accessState: Denied,
        violations: state.violations.union(Set(violation)),
        violationCounters: state.violationCounters.put(agentId, newCount),
        totalViolations: state.totalViolations + 1,
        registerEntries: state.registerEntries.union(Set("ACCESS-DENIED"))
      }
    }
  }

  /// Trigger circuit breaker
  action triggerCircuit: bool = {
    val agentId = extractAgentId(state.currentRequest.agentType)
    all {
      getViolationCount(agentId, state) >= state.circuitThreshold,
      getCircuitState(agentId, state) == Closed,
      state' = {
        ...state,
        accessState: CircuitOpen,
        circuits: state.circuits.put(agentId, Open),
        totalCircuitOpens: state.totalCircuitOpens + 1,
        registerEntries: state.registerEntries.union(Set("CIRCUIT-OPEN"))
      }
    }
  }

  /// Publish message (constant id, no toString)
  action publishMessage(msgType: MessageType, sender: str, payload: str): bool = {
    val msg = {
      id: "msg",
      msgType: msgType,
      sender: sender,
      payload: payload,
      timestamp: state.currentTime,
      sequenceNum: state.nextSeqNum
    }
    all {
      isServiceOnline(sender, state),
      state' = {
        ...state,
        messageQueue: state.messageQueue.append(msg),
        nextSeqNum: state.nextSeqNum + 1
      }
    }
  }

  /// OODA: Observe
  action ooda_Observe: bool = all {
    state.oodaPhase == Act or state.oodaCycleCount == 0,
    state' = {
      ...state,
      oodaPhase: Observe,
      oodaStartTime: state.currentTime
    }
  }

  /// OODA: Orient
  action ooda_Orient: bool = all {
    state.oodaPhase == Observe,
    state' = {
      ...state,
      oodaPhase: Orient
    }
  }

  /// OODA: Decide
  action ooda_Decide: bool = all {
    state.oodaPhase == Orient,
    state' = {
      ...state,
      oodaPhase: Decide
    }
  }

  /// OODA: Act
  action ooda_Act: bool = all {
    state.oodaPhase == Decide,
    oodaWithinBudget(state),
    state' = {
      ...state,
      oodaPhase: Act,
      oodaCycleCount: state.oodaCycleCount + 1
    }
  }

  /// Create checkpoint
  action createCheckpoint: bool = {
    val checkpoint = {
      id: "checkpoint",
      timestamp: state.currentTime,
      systemHealth: state.systemHealth,
      invariantsHeld: state.invariantsHeld
    }
    all {
      isFunctional(state),
      state' = {
        ...state,
        checkpoints: state.checkpoints.append(checkpoint),
        canRollback: true
      }
    }
  }

  /// Trigger rollback - use head() of checkpoints for initial known-good state
  action triggerRollback: bool = {
    val lastCheckpoint = state.checkpoints.head()
    all {
      state.systemHealth == DegradedHealth or state.systemHealth == Critical,
      state.canRollback,
      state.checkpoints.length() > 0,
      state' = {
        ...state,
        systemHealth: lastCheckpoint.systemHealth,
        invariantsHeld: lastCheckpoint.invariantsHeld,
        totalRollbacks: state.totalRollbacks + 1,
        registerEntries: state.registerEntries.union(Set("ROLLBACK"))
      }
    }
  }

  /// Advance time
  action tick(ms: int): bool = all {
    state' = {
      ...state,
      currentTime: state.currentTime + ms
    }
  }

  /// Combined step - each branch selects exactly one action (no multiple updates)
  action step: bool = any {
    startZenoh,
    nondet name = oneOf(Set("planning-cli", "planning-service", "smriti-db"))
    startService(name),
    nondet agentChoice = oneOf(Set(0, 1, 2))
    nondet pathChoice = oneOf(Set(0, 1))
    nondet opChoice = oneOf(Set(0, 1))
    nondet approved = oneOf(Set(true, false))
    {
      val agentT = if (agentChoice == 0) Human("user1")
                   else if (agentChoice == 1) AIAgent("claude")
                   else SystemProcess("elixir")
      val pathT = if (pathChoice == 0) "safe.md" else "PROJECT_TODOLIST.md"
      val opT = if (opChoice == 0) "read" else "write"
      val req = {
        id: "req",
        agentType: agentT,
        path: pathT,
        operation: opT,
        timestamp: state.currentTime,
        guardianApproved: approved
      }
      any {
        receiveRequest(req),
        allowRequest,
        denyRequest("Forbidden", "CRITICAL"),
        triggerCircuit
      }
    },
    nondet msgType = oneOf(Set(TaskCreated, HealthPing))
    publishMessage(msgType, "planning-cli", "payload"),
    ooda_Observe,
    ooda_Orient,
    ooda_Decide,
    ooda_Act,
    createCheckpoint,
    triggerRollback,
    tick(10)
  }

  // ==========================================================================
  // TEMPORAL INVARIANTS (SYSTEM-WIDE)
  // ==========================================================================

  /// Helper: AI agent accessing forbidden path implies denied
  pure def aiAgentPathCheck(s: IntegratedState): bool =
    isAIAgent(s.currentRequest.agentType) implies
    (isPathForbidden(s.currentRequest.path) implies s.accessState != Allowed)

  /// SAFETY: AI agents NEVER directly access PROJECT_TODOLIST.md
  temporal SC_TODO_001_Enforced = always(
    aiAgentPathCheck(state)
  )

  /// SAFETY: Unknown agents ALWAYS denied
  temporal UnknownAgentsDenied = always(
    isUnknownAgent(state.currentRequest.agentType) implies (state.accessState != Allowed)
  )

  /// SAFETY: Core invariants ALWAYS hold when functional
  temporal CoreInvariantsAlwaysHold = always(
    isFunctional(state) implies coreInvariantsHold(state)
  )

  /// SAFETY: Services start only after Zenoh online
  temporal ZenohBeforeServices = always(
    countOnlineServices(state) > 0 implies state.zenohOnline
  )

  /// SAFETY: OODA cycle within budget (SC-BIO-001)
  temporal OODAWithinBudget = always(
    state.oodaPhase == Act implies oodaWithinBudget(state)
  )

  /// SAFETY: Rollback path always exists when functional
  temporal RollbackPathExists = always(
    isFunctional(state) implies state.checkpoints.length() > 0
  )

  /// LIVENESS: Valid requests eventually processed
  temporal ValidRequestsProcessed = always(
    (state.accessState == Pending and accessAllowed(state.currentRequest, state))
    implies eventually(state.accessState == Allowed)
  )

  /// LIVENESS: Services eventually come online
  temporal ServicesEventuallyOnline = always(
    state.zenohOnline implies eventually(hasQuorum(state))
  )

  /// LIVENESS: OODA loop eventually completes
  temporal OODAEventuallyCompletes = always(
    state.oodaPhase == Observe implies eventually(state.oodaPhase == Act)
  )

  // ==========================================================================
  // RUN DECLARATIONS
  // ==========================================================================

  /// Run: Full system initialization
  run fullSystemInit = {
    init
    .then(startZenoh)
    .then(startService("planning-cli"))
    .then(startService("smriti-db"))
    .expect(hasQuorum(state))
  }

  /// Run: Access control enforcement
  run accessControlEnforcement = {
    init
    .then(receiveRequest({
      id: "req-1",
      agentType: AIAgent("claude"),
      path: "PROJECT_TODOLIST.md",
      operation: "read",
      timestamp: 1,
      guardianApproved: false
    }))
    .then(denyRequest("SC-TODO-001 violation", "CRITICAL"))
    .expect(state.accessState == Denied)
  }

  /// Run: Circuit breaker integration
  run circuitBreakerIntegration = {
    init
    .then(receiveRequest({
      id: "req-1",
      agentType: AIAgent("attacker"),
      path: "PROJECT_TODOLIST.md",
      operation: "read",
      timestamp: 1,
      guardianApproved: false
    }))
    .then(denyRequest("Forbidden", "CRITICAL"))
    .then(receiveRequest({
      id: "req-2",
      agentType: AIAgent("attacker"),
      path: "PROJECT_TODOLIST.md",
      operation: "write",
      timestamp: 2,
      guardianApproved: false
    }))
    .then(denyRequest("Forbidden", "CRITICAL"))
    .then(receiveRequest({
      id: "req-3",
      agentType: AIAgent("attacker"),
      path: "PROJECT_TODOLIST.md",
      operation: "execute",
      timestamp: 3,
      guardianApproved: false
    }))
    .then(denyRequest("Forbidden", "CRITICAL"))
    .then(triggerCircuit)
    .expect(isCircuitOpen("attacker", state))
  }

  /// Run: OODA loop coordination
  run oodaLoopCoordination = {
    init
    .then(ooda_Observe)
    .then(ooda_Orient)
    .then(ooda_Decide)
    .then(ooda_Act)
    .expect(state.oodaCycleCount == 1)
    .expect(oodaWithinBudget(state))
  }

  /// Run: Checkpoint and rollback
  run checkpointRollback = {
    init
    .then(createCheckpoint)
    .then(all { state' = { ...state, systemHealth: DegradedHealth } })
    .then(triggerRollback)
    .expect(state.systemHealth == Functional)
  }

  /// Run: End-to-end workflow
  run endToEndWorkflow = {
    init
    .then(startZenoh)
    .then(startService("planning-cli"))
    .then(startService("smriti-db"))
    .then(createCheckpoint)
    .then(ooda_Observe)
    .then(receiveRequest({
      id: "req-valid",
      agentType: Human("admin"),
      path: "tasks.md",
      operation: "write",
      timestamp: 10,
      guardianApproved: true
    }))
    .then(allowRequest)
    .then(publishMessage(TaskCreated, "planning-cli", "task-1"))
    .then(ooda_Orient)
    .then(ooda_Decide)
    .then(ooda_Act)
    .expect(hasQuorum(state))
    .expect(isFunctional(state))
    .expect(state.accessState == Allowed)
  }
}
