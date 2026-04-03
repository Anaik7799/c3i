// ============================================================================
// PLANNING ORCHESTRATION MODEL (Quint Specification)
// ============================================================================
// MODULE PURPOSE:
// Formal specification for Planning System orchestration including:
// - Zenoh pub/sub messaging
// - OODA loop coordination
// - Service lifecycle management
// - Distributed state synchronization
//
// STAMP CONSTRAINTS:
// - SC-ZENOH-001: Zenoh NIF MUST be loaded on ALL nodes
// - SC-ZENOH-002: Zenoh router MUST be reachable from ALL app nodes
// - SC-BIO-001: OODA cycle < 100ms
// - SC-BRIDGE-001: Message ordering FIFO
// - SC-BRIDGE-002: Latency budget 50ms
// ============================================================================

module planning_orchestration {
  // ==========================================================================
  // TYPE DEFINITIONS
  // ==========================================================================

  type ServiceState =
    | Offline
    | Starting
    | Online
    | Degraded
    | Stopping

  type OODAPhase =
    | Observe
    | Orient
    | Decide
    | Act

  type MessageType =
    | TaskCreated
    | TaskUpdated
    | TaskCompleted
    | HealthPing
    | CoordinationRequest
    | StateSync

  type Message = {
    id: str,
    msgType: MessageType,
    sender: str,
    recipient: str,
    payload: str,
    timestamp: int,
    sequenceNum: int
  }

  type Service = {
    name: str,
    state: ServiceState,
    zenohConnected: bool,
    lastHealthPing: int,
    messagesReceived: int,
    messagesSent: int
  }

  type OrchestrationState = {
    services: str -> Service,
    currentPhase: OODAPhase,
    oodaCycleCount: int,
    oodaStartTime: int,
    messageQueue: List[Message],
    messageHistory: Set[Message],
    nextSequenceNum: int,
    zenohRouterOnline: bool,
    zenohTopics: Set[str],
    quorumRequired: int,
    servicesOnline: int,
    currentTime: int,
    totalCycles: int,
    avgCycleTimeMs: int
  }

  // ==========================================================================
  // STATE VARIABLES
  // ==========================================================================

  var state: OrchestrationState

  // ==========================================================================
  // CONSTANTS
  // ==========================================================================

  pure val OODA_CYCLE_BUDGET_MS = 100
  pure val MESSAGE_LATENCY_BUDGET_MS = 50
  pure val HEALTH_PING_INTERVAL_MS = 10000
  pure val QUORUM_SIZE = 2

  pure val ZENOH_TOPICS = Set(
    "indrajaal/planning/events",
    "indrajaal/planning/health",
    "indrajaal/planning/coordination"
  )

  pure val SERVICE_NAMES = Set(
    "planning-cli",
    "planning-service",
    "smriti-db"
  )

  // ==========================================================================
  // HELPER PREDICATES
  // ==========================================================================

  pure def getServiceState(name: str, services: str -> Service): ServiceState = {
    if (services.keys().contains(name)) services.get(name).state else Offline
  }

  pure def isServiceOnline(name: str, services: str -> Service): bool = {
    getServiceState(name, services) == Online
  }

  pure def countOnlineServices(s: OrchestrationState): int = {
    SERVICE_NAMES.filter(name => isServiceOnline(name, s.services)).size()
  }

  pure def hasQuorum(s: OrchestrationState): bool = {
    s.servicesOnline >= s.quorumRequired
  }

  pure def allServicesConnected(s: OrchestrationState): bool = {
    SERVICE_NAMES.forall(name =>
      if (s.services.keys().contains(name)) s.services.get(name).zenohConnected else false
    )
  }

  // Check FIFO ordering of message queue
  pure def isFIFO(msgs: List[Message]): bool = {
    msgs.indices().forall(i =>
      i == 0 or msgs[i].sequenceNum > msgs[i - 1].sequenceNum
    )
  }

  pure def cycleWithinBudget(s: OrchestrationState): bool = {
    val elapsed = s.currentTime - s.oodaStartTime
    elapsed <= OODA_CYCLE_BUDGET_MS
  }

  pure def isQueueEmpty(s: OrchestrationState): bool = {
    s.messageQueue.length() == 0
  }

  pure def defaultService(name: str): Service = {
    {
      name: name,
      state: Offline,
      zenohConnected: false,
      lastHealthPing: 0,
      messagesReceived: 0,
      messagesSent: 0
    }
  }

  // ==========================================================================
  // STATE TRANSITIONS
  // ==========================================================================

  action init: bool = all {
    state' = {
      services: Map(
        "planning-cli" -> {
          name: "planning-cli",
          state: Offline,
          zenohConnected: false,
          lastHealthPing: 0,
          messagesReceived: 0,
          messagesSent: 0
        },
        "planning-service" -> {
          name: "planning-service",
          state: Offline,
          zenohConnected: false,
          lastHealthPing: 0,
          messagesReceived: 0,
          messagesSent: 0
        },
        "smriti-db" -> {
          name: "smriti-db",
          state: Offline,
          zenohConnected: false,
          lastHealthPing: 0,
          messagesReceived: 0,
          messagesSent: 0
        }
      ),
      currentPhase: Observe,
      oodaCycleCount: 0,
      oodaStartTime: 0,
      messageQueue: List(),
      messageHistory: Set(),
      nextSequenceNum: 1,
      zenohRouterOnline: false,
      zenohTopics: Set(),
      quorumRequired: QUORUM_SIZE,
      servicesOnline: 0,
      currentTime: 0,
      totalCycles: 0,
      avgCycleTimeMs: 0
    }
  }

  // Start Zenoh router (SC-ZENOH-002)
  action startZenohRouter: bool = all {
    not(state.zenohRouterOnline),
    state' = {
      ...state,
      zenohRouterOnline: true,
      zenohTopics: ZENOH_TOPICS
    }
  }

  // Start service (transition Offline -> Starting)
  action startService(serviceName: str): bool = {
    val svc = if (state.services.keys().contains(serviceName))
                state.services.get(serviceName)
              else defaultService(serviceName)
    all {
      getServiceState(serviceName, state.services) == Offline,
      state.zenohRouterOnline,
      state' = {
        ...state,
        services: state.services.put(serviceName, {
          ...svc,
          state: Starting
        })
      }
    }
  }

  // Service transitions to Online (AOR-ZENOH-008)
  action serviceOnline(serviceName: str): bool = {
    val svc = if (state.services.keys().contains(serviceName))
                state.services.get(serviceName)
              else defaultService(serviceName)
    all {
      getServiceState(serviceName, state.services) == Starting,
      state' = {
        ...state,
        services: state.services.put(serviceName, {
          ...svc,
          state: Online,
          zenohConnected: true,
          lastHealthPing: state.currentTime
        }),
        servicesOnline: state.servicesOnline + 1
      }
    }
  }

  // Publish message to Zenoh bus (SC-BRIDGE-001: FIFO)
  action publishMessage(sender: str, msgType: MessageType, payload: str): bool = {
    val svc = if (state.services.keys().contains(sender))
                state.services.get(sender)
              else defaultService(sender)
    val msg = {
      id: "msg",
      msgType: msgType,
      sender: sender,
      recipient: "broadcast",
      payload: payload,
      timestamp: state.currentTime,
      sequenceNum: state.nextSequenceNum
    }
    all {
      isServiceOnline(sender, state.services),
      state' = {
        ...state,
        messageQueue: state.messageQueue.append(msg),
        nextSequenceNum: state.nextSequenceNum + 1,
        services: state.services.put(sender, {
          ...svc,
          messagesSent: svc.messagesSent + 1
        })
      }
    }
  }

  // Consume message from queue
  action consumeMessage(receiver: str): bool = {
    val msg = state.messageQueue.head()
    val svc = if (state.services.keys().contains(receiver))
                state.services.get(receiver)
              else defaultService(receiver)
    all {
      not(isQueueEmpty(state)),
      isServiceOnline(receiver, state.services),
      state' = {
        ...state,
        messageQueue: state.messageQueue.tail(),
        messageHistory: state.messageHistory.union(Set(msg)),
        services: state.services.put(receiver, {
          ...svc,
          messagesReceived: svc.messagesReceived + 1
        })
      }
    }
  }

  // Send health ping (AOR-ZENOH-007) - inline publishMessage to avoid double update
  action healthPing(serviceName: str): bool = {
    val svc = if (state.services.keys().contains(serviceName))
                state.services.get(serviceName)
              else defaultService(serviceName)
    val timeSinceLastPing = state.currentTime - svc.lastHealthPing
    val msg = {
      id: "health-msg",
      msgType: HealthPing,
      sender: serviceName,
      recipient: "broadcast",
      payload: "healthy",
      timestamp: state.currentTime,
      sequenceNum: state.nextSequenceNum
    }
    all {
      isServiceOnline(serviceName, state.services),
      timeSinceLastPing >= HEALTH_PING_INTERVAL_MS,
      state' = {
        ...state,
        messageQueue: state.messageQueue.append(msg),
        nextSequenceNum: state.nextSequenceNum + 1,
        services: state.services.put(serviceName, {
          ...svc,
          lastHealthPing: state.currentTime,
          messagesSent: svc.messagesSent + 1
        })
      }
    }
  }

  // OODA Loop: Observe phase
  action ooda_Observe: bool = all {
    state.currentPhase == Act or state.oodaCycleCount == 0,
    state' = {
      ...state,
      currentPhase: Observe,
      oodaStartTime: state.currentTime
    }
  }

  // OODA Loop: Orient phase
  action ooda_Orient: bool = all {
    state.currentPhase == Observe,
    state' = {
      ...state,
      currentPhase: Orient
    }
  }

  // OODA Loop: Decide phase
  action ooda_Decide: bool = all {
    state.currentPhase == Orient,
    state' = {
      ...state,
      currentPhase: Decide
    }
  }

  // OODA Loop: Act phase
  action ooda_Act: bool = {
    val cycleTime = state.currentTime - state.oodaStartTime
    val newAvg = if (state.totalCycles == 0)
                   cycleTime
                 else (state.avgCycleTimeMs * state.totalCycles + cycleTime) / (state.totalCycles + 1)
    all {
      state.currentPhase == Decide,
      state' = {
        ...state,
        currentPhase: Act,
        oodaCycleCount: state.oodaCycleCount + 1,
        totalCycles: state.totalCycles + 1,
        avgCycleTimeMs: newAvg
      }
    }
  }

  // Advance time
  action tick(ms: int): bool = all {
    state' = {
      ...state,
      currentTime: state.currentTime + ms
    }
  }

  // Combined step
  action step: bool = any {
    startZenohRouter,
    nondet name = oneOf(Set("planning-cli", "planning-service", "smriti-db"))
    startService(name),
    nondet name2 = oneOf(Set("planning-cli", "planning-service", "smriti-db"))
    serviceOnline(name2),
    nondet name3 = oneOf(Set("planning-cli", "planning-service", "smriti-db"))
    publishMessage(name3, TaskCreated, "task-1"),
    nondet name4 = oneOf(Set("planning-cli", "planning-service", "smriti-db"))
    consumeMessage(name4),
    nondet name5 = oneOf(Set("planning-cli", "planning-service", "smriti-db"))
    healthPing(name5),
    ooda_Observe,
    ooda_Orient,
    ooda_Decide,
    ooda_Act,
    tick(10)
  }

  // ==========================================================================
  // TEMPORAL INVARIANTS
  // ==========================================================================

  // SAFETY: Zenoh router MUST be online before services start
  temporal ZenohRouterFirst = always(
    SERVICE_NAMES.forall(name =>
      getServiceState(name, state.services) != Offline implies state.zenohRouterOnline
    )
  )

  // SAFETY: Message queue ALWAYS maintains FIFO order
  temporal MessageQueueFIFO = always(
    isFIFO(state.messageQueue)
  )

  // SAFETY: All online services MUST be Zenoh-connected
  temporal OnlineImpliesConnected = always(
    SERVICE_NAMES.forall(name =>
      isServiceOnline(name, state.services) implies
      (state.services.keys().contains(name) and state.services.get(name).zenohConnected)
    )
  )

  // LIVENESS: Services EVENTUALLY come online
  temporal ServicesEventuallyOnline = always(
    state.zenohRouterOnline implies
    eventually(countOnlineServices(state) >= QUORUM_SIZE)
  )

  // LIVENESS: OODA loop EVENTUALLY completes cycle
  temporal OODAEventuallyCompletes = always(
    state.currentPhase == Observe implies
    eventually(state.currentPhase == Act)
  )

  // SAFETY: OODA cycle MUST complete within budget (SC-BIO-001)
  temporal OODACycleWithinBudget = always(
    (state.currentPhase == Observe and next(state.currentPhase == Act))
    implies cycleWithinBudget(state)
  )

  // LIVENESS: Messages EVENTUALLY get consumed
  temporal MessagesEventuallyConsumed = always(
    (not(isQueueEmpty(state)) and hasQuorum(state))
    implies eventually(isQueueEmpty(state))
  )

  // ==========================================================================
  // RUN DECLARATIONS
  // ==========================================================================

  run serviceLifecycle = {
    init
    .then(startZenohRouter)
    .then(startService("planning-cli"))
    .then(serviceOnline("planning-cli"))
    .expect(isServiceOnline("planning-cli", state.services))
  }

  run messagePubSub = {
    init
    .then(startZenohRouter)
    .then(startService("planning-cli"))
    .then(serviceOnline("planning-cli"))
    .then(publishMessage("planning-cli", TaskCreated, "task-1"))
    .then(consumeMessage("planning-cli"))
    .expect(state.messageHistory.size() == 1)
  }

  run oodaCycle = {
    init
    .then(ooda_Observe)
    .then(ooda_Orient)
    .then(ooda_Decide)
    .then(ooda_Act)
    .expect(state.oodaCycleCount == 1)
  }

  run quorumCoordination = {
    init
    .then(startZenohRouter)
    .then(startService("planning-cli"))
    .then(serviceOnline("planning-cli"))
    .then(startService("smriti-db"))
    .then(serviceOnline("smriti-db"))
    .expect(hasQuorum(state))
  }
}
