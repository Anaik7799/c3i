// =============================================================================
// QUINT MODULE: FLAME Distributed Execution Verification
// Purpose: Model check FLAME scaling and fault tolerance
// Context: Stream Beta (Task 30.1.2)
// =============================================================================

module FLAMEExecution {

  // ---------------------------------------------------------------------------
  // Types
  // ---------------------------------------------------------------------------

  type FLAMEState = Idle | Spawning | Running | Scaling | Draining | Terminated

  type ScaleDirection = ScaleUp | ScaleDown | NoScale

  // ---------------------------------------------------------------------------
  // State Variables
  // ---------------------------------------------------------------------------

  var flameState: FLAMEState
  var activeNodes: int
  var targetNodes: int
  var workloadPending: int
  var drainingNodes: Set[int]
  var globalClock: int

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  pure val MIN_NODES = 1
  pure val MAX_NODES = 100
  pure val SPAWN_LATENCY = 500
  pure val DRAIN_LATENCY = 10000

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  action init = all {
    flameState' = Idle,
    activeNodes' = MIN_NODES,
    targetNodes' = MIN_NODES,
    workloadPending' = 0,
    drainingNodes' = Set(),
    globalClock' = 0
  }

  // ---------------------------------------------------------------------------
  // State Transitions
  // ---------------------------------------------------------------------------

  action receiveWorkload(work: int): bool = all {
    flameState == Idle,
    work > 0,
    flameState' = Spawning,
    workloadPending' = work,
    targetNodes' = if (activeNodes + (work / 100) < MAX_NODES) activeNodes + (work / 100) else MAX_NODES,
    activeNodes' = activeNodes,
    drainingNodes' = drainingNodes,
    globalClock' = globalClock + 10
  }

  action completeSpawn: bool = all {
    flameState == Spawning,
    activeNodes' = targetNodes,
    flameState' = Running,
    targetNodes' = targetNodes,
    workloadPending' = workloadPending,
    drainingNodes' = drainingNodes,
    globalClock' = globalClock + SPAWN_LATENCY
  }

  action scaleUp(additionalNodes: int): bool = all {
    flameState == Running,
    additionalNodes > 0,
    activeNodes + additionalNodes <= MAX_NODES,
    flameState' = Scaling,
    targetNodes' = activeNodes + additionalNodes,
    activeNodes' = activeNodes,
    workloadPending' = workloadPending,
    drainingNodes' = drainingNodes,
    globalClock' = globalClock + 100
  }

  action scaleDown(removeNodes: int): bool = all {
    flameState == Running,
    removeNodes > 0,
    activeNodes - removeNodes >= MIN_NODES,
    flameState' = Draining,
    drainingNodes' = Set(activeNodes - removeNodes + 1).union(
      Set(activeNodes - removeNodes + 2)
    ),
    activeNodes' = activeNodes,
    targetNodes' = targetNodes,
    workloadPending' = workloadPending,
    globalClock' = globalClock + 100
  }

  action completeDrain: bool = all {
    flameState == Draining,
    activeNodes' = activeNodes - size(drainingNodes),
    drainingNodes' = Set(),
    flameState' = Running,
    targetNodes' = targetNodes,
    workloadPending' = workloadPending,
    globalClock' = globalClock + DRAIN_LATENCY
  }

  action shutdown: bool = all {
    flameState == Running or flameState == Draining,
    flameState' = Terminated,
    activeNodes' = activeNodes,
    targetNodes' = targetNodes,
    workloadPending' = workloadPending,
    drainingNodes' = drainingNodes,
    globalClock' = globalClock
  }

  // ---------------------------------------------------------------------------
  // Safety Invariants (SC-FLAME-001 to SC-FLAME-006)
  // ---------------------------------------------------------------------------

  // SC-FLAME-002: Maintain quorum during scaling
  val quorumMaintained: bool =
    flameState == Scaling implies activeNodes >= MIN_NODES

  // SC-FLAME-003: No spawn without resource check
  val resourceCheckBeforeSpawn: bool =
    flameState == Spawning implies targetNodes <= MAX_NODES

  // SC-FLAME-004: Graceful draining before shutdown
  val gracefulDrain: bool =
    flameState == Terminated implies size(drainingNodes) == 0

  val flameInvariant: bool = and {
    quorumMaintained,
    resourceCheckBeforeSpawn,
    gracefulDrain,
    activeNodes >= MIN_NODES,
    activeNodes <= MAX_NODES
  }

  temporal alwaysFLAMESafe = always(flameInvariant)

  // ---------------------------------------------------------------------------
  // Liveness Properties
  // ---------------------------------------------------------------------------

  // Scaling eventually completes
  temporal scalingCompletes = always(
    flameState == Scaling implies eventually(flameState == Running)
  )

  // Draining eventually completes
  temporal drainingCompletes = always(
    flameState == Draining implies eventually(
      flameState == Running or flameState == Terminated
    )
  )
}
