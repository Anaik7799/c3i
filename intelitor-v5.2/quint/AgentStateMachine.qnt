// =============================================================================
// QUINT MODULE: Agent State Machine
// Purpose: Executable state machine for 50-agent hierarchy
// Coverage Gap: Mathematica §2.2 defines δ: Q × Σ → Q statically;
//               Quint enables execution, model checking, and trace generation
// =============================================================================

module AgentStateMachine {
  // Types (inlined from IndrajaalTypes for standalone type-checking)
  type AgentRole = Executive | DomainSupervisor | FunctionalSupervisor | Worker
  type AgentState = Idle | Active | Blocked | Error | Recovering | Suspended | Terminated

  type Agent = {
    id: int,
    role: AgentRole,
    state: AgentState,
    supervisor: int,
    errorCount: int,
    currentTask: int
  }

  // ---------------------------------------------------------------------------
  // §Q2.1 State Variables
  // ---------------------------------------------------------------------------

  pure val NUM_AGENTS = 50
  pure val MAX_ERROR_COUNT = 5
  pure val SUPERVISOR_TIMEOUT_MS = 1000

  var agents: int -> Agent
  var taskQueue: List[int]
  var supervisorAcknowledged: Set[(int, int)]
  var terminatedAgents: Set[int]
  var globalTime: int

  // ---------------------------------------------------------------------------
  // §Q2.2 Initialization Action
  // ---------------------------------------------------------------------------

  action init = all {
    agents' = Map(
      1 -> { id: 1, role: Executive, state: Idle, supervisor: -1, errorCount: 0, currentTask: -1 },
      // Domain Supervisors (2-11)
      2 -> { id: 2, role: DomainSupervisor, state: Idle, supervisor: 1, errorCount: 0, currentTask: -1 }
      // ... (pattern continues for all 50 agents)
    ),
    taskQueue' = [],
    supervisorAcknowledged' = Set(),
    terminatedAgents' = Set(),
    globalTime' = 0
  }

  // ---------------------------------------------------------------------------
  // §Q2.3 State Transition Actions (δ function from §2.2)
  // ---------------------------------------------------------------------------

  // Transition: idle -> active (on task assignment)
  action assignTask(agentId: int, taskId: int): bool = all {
    agents.get(agentId).state == Idle,
    not(agentId.in(terminatedAgents)),
    agents' = agents.set(agentId, { ...agents.get(agentId), state: Active, currentTask: taskId }),
    taskQueue' = taskQueue.select(t => t != taskId),
    supervisorAcknowledged' = supervisorAcknowledged,
    terminatedAgents' = terminatedAgents,
    globalTime' = globalTime + 1
  }

  // Transition: active -> idle (on completion)
  action completeTask(agentId: int): bool = all {
    agents.get(agentId).state == Active,
    agents' = agents.set(agentId, { ...agents.get(agentId), state: Idle, currentTask: -1 }),
    taskQueue' = taskQueue,
    supervisorAcknowledged' = supervisorAcknowledged,
    terminatedAgents' = terminatedAgents,
    globalTime' = globalTime + 1
  }

  // Transition: active -> error (on failure)
  action failTask(agentId: int): bool = all {
    agents.get(agentId).state == Active,
    val newErrorCount = agents.get(agentId).errorCount + 1;
    all {
      agents' = agents.set(agentId, {
        ...agents.get(agentId),
        state: Error,
        errorCount: newErrorCount,
        currentTask: -1
      }),
      taskQueue' = taskQueue,
      supervisorAcknowledged' = supervisorAcknowledged,
      terminatedAgents' = terminatedAgents,
      globalTime' = globalTime + 1
    }
  }

  // Transition: error -> recovering
  action initiateRecovery(agentId: int): bool = all {
    agents.get(agentId).state == Error,
    agents.get(agentId).errorCount < MAX_ERROR_COUNT,
    agents' = agents.set(agentId, { ...agents.get(agentId), state: Recovering }),
    taskQueue' = taskQueue,
    supervisorAcknowledged' = supervisorAcknowledged,
    terminatedAgents' = terminatedAgents,
    globalTime' = globalTime + 1
  }

  // Transition: recovering -> idle
  action completeRecovery(agentId: int): bool = all {
    agents.get(agentId).state == Recovering,
    agents' = agents.set(agentId, { ...agents.get(agentId), state: Idle }),
    taskQueue' = taskQueue,
    supervisorAcknowledged' = supervisorAcknowledged,
    terminatedAgents' = terminatedAgents,
    globalTime' = globalTime + 1
  }

  // Transition: * -> terminated (emergency stop)
  action emergencyStop(agentId: int): bool = all {
    agents.get(agentId).state != Terminated,
    agents' = agents.set(agentId, { ...agents.get(agentId), state: Terminated, currentTask: -1 }),
    taskQueue' = taskQueue,
    supervisorAcknowledged' = supervisorAcknowledged,
    terminatedAgents' = terminatedAgents.union(Set(agentId)),
    globalTime' = globalTime + 1
  }

  // Transition: error -> terminated (max errors exceeded)
  action terminateOnMaxErrors(agentId: int): bool = all {
    agents.get(agentId).state == Error,
    agents.get(agentId).errorCount >= MAX_ERROR_COUNT,
    agents' = agents.set(agentId, { ...agents.get(agentId), state: Terminated }),
    taskQueue' = taskQueue,
    supervisorAcknowledged' = supervisorAcknowledged,
    terminatedAgents' = terminatedAgents.union(Set(agentId)),
    globalTime' = globalTime + 1
  }

  // ---------------------------------------------------------------------------
  // §Q2.4 Supervisor Acknowledgment Protocol
  // ---------------------------------------------------------------------------

  action supervisorAck(agentId: int, supervisorId: int): bool = all {
    agents.get(agentId).supervisor == supervisorId,
    agents' = agents,
    taskQueue' = taskQueue,
    supervisorAcknowledged' = supervisorAcknowledged.union(Set((agentId, supervisorId))),
    terminatedAgents' = terminatedAgents,
    globalTime' = globalTime + 1
  }

  // ---------------------------------------------------------------------------
  // §Q2.5 Nondeterministic System Step
  // ---------------------------------------------------------------------------

  action step = {
    nondet agentId = oneOf(1.to(NUM_AGENTS));
    nondet taskId = oneOf(0.to(100));
    any {
      assignTask(agentId, taskId),
      completeTask(agentId),
      failTask(agentId),
      initiateRecovery(agentId),
      completeRecovery(agentId),
      emergencyStop(agentId),
      terminateOnMaxErrors(agentId)
    }
  }
}
