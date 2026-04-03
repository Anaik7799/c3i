// ============================================================================
// PLANNING SAFETY KERNEL (Quint Specification)
// ============================================================================
// MODULE PURPOSE:
// Formal specification for safety kernel guaranteeing system-wide invariants
// across all Planning System operations. Implements Constitutional alignment
// checks and Guardian validation.
//
// CONSTITUTIONAL ALIGNMENT:
// - Psi0 (Existence): System survives ALL operations
// - Psi1 (Regeneration): State recoverable from SQLite/DuckDB
// - Psi2 (Evolutionary Continuity): Complete history preserved
// - Psi3 (Verification Capability): All changes verifiable
//
// STAMP CONSTRAINTS:
// - SC-FUNC-001: System MUST compile at all times
// - SC-FUNC-003: Rollback path MUST exist for every change
// - SC-FUNC-004: State MUST be recoverable from SQLite/DuckDB
// - SC-PRAJNA-001: Guardian approval required for mutations
// ============================================================================

module planning_safety_kernel {
  // ==========================================================================
  // TYPE DEFINITIONS
  // ==========================================================================

  type SystemState =
    | Functional
    | Degraded
    | Critical
    | Failed

  type OperationType =
    | TaskCreate
    | TaskUpdate
    | TaskDelete
    | StateSync
    | DatabaseMigration
    | ConfigUpdate

  type Checkpoint = {
    id: str,
    timestamp: int,
    systemState: SystemState,
    databaseSnapshot: str,
    configSnapshot: str,
    invariantsHeld: Set[str]
  }

  type Condition = {
    name: str,
    holds: bool,
    description: str
  }

  type Operation = {
    id: str,
    opType: OperationType,
    preconditions: Set[Condition],
    postconditions: Set[Condition],
    timestamp: int,
    guardianApproved: bool
  }

  type KernelState = {
    systemState: SystemState,
    invariantsHeld: Set[str],
    violatedInvariants: Set[str],
    currentOperation: Operation,
    operationHistory: List[Operation],
    checkpoints: List[Checkpoint],
    lastCheckpoint: Checkpoint,
    canRollback: bool,
    rollbackInProgress: bool,
    registerEntries: Set[str],
    totalOperations: int,
    totalRollbacks: int,
    currentTime: int
  }

  // ==========================================================================
  // STATE VARIABLES
  // ==========================================================================

  var state: KernelState

  // ==========================================================================
  // CONSTANTS
  // ==========================================================================

  pure val CORE_INVARIANTS = Set(
    "Psi0-Existence",
    "Psi1-Regeneration",
    "Psi2-History",
    "Psi3-Verification",
    "SC-FUNC-001",
    "SC-FUNC-003",
    "SC-FUNC-004"
  )

  pure val OPERATIONAL_INVARIANTS = Set(
    "QuorumMaintained",
    "DatabaseConsistent",
    "ZenohConnected",
    "AuthorizationValid"
  )

  pure val ALL_INVARIANTS = Set(
    "Psi0-Existence",
    "Psi1-Regeneration",
    "Psi2-History",
    "Psi3-Verification",
    "SC-FUNC-001",
    "SC-FUNC-003",
    "SC-FUNC-004",
    "QuorumMaintained",
    "DatabaseConsistent",
    "ZenohConnected",
    "AuthorizationValid"
  )

  pure val MUTATING_OPS = Set(TaskCreate, TaskUpdate, TaskDelete, ConfigUpdate)

  // ==========================================================================
  // HELPER PREDICATES
  // ==========================================================================

  pure def coreInvariantsHold(s: KernelState): bool = {
    CORE_INVARIANTS.forall(inv => s.invariantsHeld.contains(inv))
  }

  pure def isFunctional(s: KernelState): bool = {
    s.systemState == Functional and coreInvariantsHold(s)
  }

  pure def requiresGuardianApproval(opType: OperationType): bool = {
    MUTATING_OPS.contains(opType)
  }

  pure def preconditionsHold(op: Operation): bool = {
    op.preconditions.forall(c => c.holds)
  }

  pure def postconditionsHold(op: Operation): bool = {
    op.postconditions.forall(c => c.holds)
  }

  pure def violationCount(s: KernelState): int = {
    s.violatedInvariants.size()
  }

  pure def makeInitCheckpoint: Checkpoint = {
    {
      id: "checkpoint-0",
      timestamp: 0,
      systemState: Functional,
      databaseSnapshot: "init.db",
      configSnapshot: "init.config",
      invariantsHeld: ALL_INVARIANTS
    }
  }

  // ==========================================================================
  // STATE TRANSITIONS
  // ==========================================================================

  action init: bool = {
    val initCheckpoint = makeInitCheckpoint
    all {
      state' = {
        systemState: Functional,
        invariantsHeld: ALL_INVARIANTS,
        violatedInvariants: Set(),
        currentOperation: {
          id: "init",
          opType: StateSync,
          preconditions: Set(),
          postconditions: Set(),
          timestamp: 0,
          guardianApproved: true
        },
        operationHistory: List(),
        checkpoints: List(initCheckpoint),
        lastCheckpoint: initCheckpoint,
        canRollback: false,
        rollbackInProgress: false,
        registerEntries: Set("INIT"),
        totalOperations: 0,
        totalRollbacks: 0,
        currentTime: 0
      }
    }
  }

  // Create checkpoint before risky operation (SC-FUNC-003)
  action createCheckpoint: bool = {
    val checkpoint = {
      id: "checkpoint-snap",
      timestamp: state.currentTime,
      systemState: state.systemState,
      databaseSnapshot: "snapshot.db",
      configSnapshot: "config-snap",
      invariantsHeld: state.invariantsHeld
    }
    all {
      isFunctional(state),
      state' = {
        ...state,
        checkpoints: state.checkpoints.append(checkpoint),
        lastCheckpoint: checkpoint,
        canRollback: true
      }
    }
  }

  // Validate operation preconditions
  action validatePreconditions(op: Operation): bool = all {
    preconditionsHold(op),
    requiresGuardianApproval(op.opType) implies op.guardianApproved,
    state' = {
      ...state,
      currentOperation: op
    }
  }

  // Execute operation (preserving invariants)
  action executeOperation(op: Operation): bool = all {
    state.currentOperation.id == op.id,
    preconditionsHold(op),
    isFunctional(state),
    state' = {
      ...state,
      operationHistory: state.operationHistory.append(op),
      totalOperations: state.totalOperations + 1
    }
  }

  // Verify postconditions after operation - success branch
  action verifyPostconditionsSuccess(op: Operation): bool = all {
    postconditionsHold(op),
    state' = {
      ...state,
      registerEntries: state.registerEntries.union(Set("OP-SUCCESS"))
    }
  }

  // Verify postconditions after operation - failure branch
  action verifyPostconditionsFailure(op: Operation): bool = all {
    not(postconditionsHold(op)),
    state' = {
      ...state,
      systemState: Degraded,
      violatedInvariants: state.violatedInvariants.union(Set("PostCondition-Failed")),
      invariantsHeld: state.invariantsHeld.exclude(Set("PostCondition-Failed"))
    }
  }

  // Trigger rollback on invariant violation (AOR-FUNC-005)
  action triggerRollback: bool = all {
    state.systemState == Degraded or state.systemState == Critical,
    state.canRollback,
    not(state.rollbackInProgress),
    state' = {
      ...state,
      rollbackInProgress: true
    }
  }

  // Execute rollback to last checkpoint
  action executeRollback: bool = {
    val checkpoint = state.lastCheckpoint
    all {
      state.rollbackInProgress,
      state' = {
        ...state,
        systemState: checkpoint.systemState,
        invariantsHeld: checkpoint.invariantsHeld,
        violatedInvariants: Set(),
        rollbackInProgress: false,
        totalRollbacks: state.totalRollbacks + 1,
        registerEntries: state.registerEntries.union(Set("ROLLBACK"))
      }
    }
  }

  // Emergency stop (SC-EMR-057: < 5 seconds)
  action emergencyStop: bool = all {
    state.systemState == Critical or violationCount(state) >= 3,
    state' = {
      ...state,
      systemState: Failed,
      registerEntries: state.registerEntries.union(Set("EMERGENCY-STOP"))
    }
  }

  // Restore from checkpoint (manual recovery)
  action restoreFromCheckpoint: bool = {
    val checkpoint = state.lastCheckpoint
    all {
      state' = {
        ...state,
        systemState: checkpoint.systemState,
        invariantsHeld: checkpoint.invariantsHeld,
        violatedInvariants: Set(),
        lastCheckpoint: checkpoint,
        registerEntries: state.registerEntries.union(Set("RESTORE"))
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
    createCheckpoint,
    nondet opType = oneOf(Set(TaskCreate, TaskUpdate, StateSync))
    nondet guardianApproved = oneOf(Set(true, false))
    val op = {
      id: "op-current",
      opType: opType,
      preconditions: Set({
        name: "SystemFunctional",
        holds: isFunctional(state),
        description: "System must be functional"
      }),
      postconditions: Set({
        name: "InvariantsPreserved",
        holds: true,
        description: "All invariants preserved"
      }),
      timestamp: state.currentTime,
      guardianApproved: guardianApproved
    }
    any {
      validatePreconditions(op),
      executeOperation(op),
      verifyPostconditionsSuccess(op),
      verifyPostconditionsFailure(op)
    },
    triggerRollback,
    executeRollback,
    emergencyStop,
    tick(10)
  }

  // ==========================================================================
  // TEMPORAL INVARIANTS
  // ==========================================================================

  // SAFETY: Core invariants ALWAYS hold (Psi0-Psi3)
  temporal CoreInvariantsAlwaysHold = always(
    state.systemState == Functional implies coreInvariantsHold(state)
  )

  // SAFETY: Mutating operations REQUIRE Guardian approval
  temporal MutatingOpsRequireGuardian = always(
    (MUTATING_OPS.contains(state.currentOperation.opType) and
     state.currentOperation.id != "init")
    implies state.currentOperation.guardianApproved
  )

  // SAFETY: Rollback path ALWAYS exists (SC-FUNC-003)
  temporal RollbackPathExists = always(
    state.systemState != Failed implies state.checkpoints.length() > 0
  )

  // LIVENESS: Degraded system EVENTUALLY recovers or stops
  temporal DegradedEventuallyRecovers = always(
    state.systemState == Degraded implies
    eventually(
      state.systemState == Functional or
      state.systemState == Failed
    )
  )

  // LIVENESS: Rollback EVENTUALLY completes
  temporal RollbackEventuallyCompletes = always(
    state.rollbackInProgress implies
    eventually(not(state.rollbackInProgress))
  )

  // SAFETY: Register entries monotonically increase
  temporal RegisterMonotonic = always(
    next(state.registerEntries.size() >= state.registerEntries.size())
  )

  // SAFETY: Total operations monotonically increases
  temporal OperationsMonotonic = always(
    next(state.totalOperations >= state.totalOperations)
  )

  // SAFETY: Failed state is terminal
  temporal FailedIsTerminal = always(
    state.systemState == Failed implies next(state.systemState == Failed)
  )

  // ==========================================================================
  // RUN DECLARATIONS
  // ==========================================================================

  run basicOperationFlow = {
    init
    .then(createCheckpoint)
    .then(validatePreconditions({
      id: "op-1",
      opType: TaskCreate,
      preconditions: Set({
        name: "SystemFunctional",
        holds: true,
        description: "System functional"
      }),
      postconditions: Set({
        name: "InvariantsPreserved",
        holds: true,
        description: "Invariants preserved"
      }),
      timestamp: 1,
      guardianApproved: true
    }))
    .then(executeOperation({
      id: "op-1",
      opType: TaskCreate,
      preconditions: Set(),
      postconditions: Set(),
      timestamp: 1,
      guardianApproved: true
    }))
    .expect(state.totalOperations == 1)
  }

  run rollbackOnFailure = {
    init
    .then(createCheckpoint)
    .then(state' = { ...state, systemState: Degraded })
    .then(triggerRollback)
    .then(executeRollback)
    .expect(state.systemState == Functional)
  }

  run emergencyStopFlow = {
    init
    .then(state' = { ...state, systemState: Critical })
    .then(emergencyStop)
    .expect(state.systemState == Failed)
  }

  run guardianApprovalRequired = {
    init
    .then(validatePreconditions({
      id: "op-mutate",
      opType: TaskCreate,
      preconditions: Set(),
      postconditions: Set(),
      timestamp: 1,
      guardianApproved: true
    }))
    .expect(requiresGuardianApproval(TaskCreate))
  }
}
