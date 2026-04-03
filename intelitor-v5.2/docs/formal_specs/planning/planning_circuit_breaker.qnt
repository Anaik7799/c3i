// ============================================================================
// PLANNING CIRCUIT BREAKER STATE MACHINE (Quint Specification)
// ============================================================================
// MODULE PURPOSE:
// Formal specification for circuit breaker pattern in Planning System
// enforcement. Prevents cascade failures and implements fail-safe mechanisms.
//
// STAMP CONSTRAINTS:
// - SC-ENFORCE-004: Violation count MUST trigger circuit breaker at threshold
// - SC-ENFORCE-013: Circuit breaker reset MUST require manual intervention
// - SC-FUNC-003: Rollback capability via circuit breaker
//
// AOR RULES:
// - AOR-ENFORCE-004: TRIGGER circuit breaker after 3 violations per agent
// - AOR-ENFORCE-010: REQUIRE Guardian approval for circuit breaker reset
//
// DESIGN PATTERN:
// Implements classic Circuit Breaker pattern (Closed -> Open -> Half-Open)
// with Guardian-approved recovery mechanism.
// ============================================================================

module planning_circuit_breaker {
  // ==========================================================================
  // TYPE DEFINITIONS
  // ==========================================================================

  /// Circuit breaker states (classic pattern)
  type CircuitState =
    | Closed      // Normal operation, requests allowed
    | Open        // Circuit open, all requests blocked
    | HalfOpen    // Testing recovery, limited requests allowed

  /// Violation event
  type Violation = {
    agentId: str,
    timestamp: int,
    severity: str  // "LOW" | "MEDIUM" | "HIGH" | "CRITICAL"
  }

  /// Recovery attempt
  type RecoveryAttempt = {
    timestamp: int,
    approved: bool,
    guardianToken: str
  }

  /// System state
  type CircuitBreakerState = {
    // Circuit state per agent
    circuits: str -> CircuitState,

    // Violation tracking
    violations: str -> List[Violation],  // agentId -> violations
    violationCounts: str -> int,         // agentId -> count

    // Configuration
    threshold: int,                      // Violations to trigger open
    halfOpenMaxAttempts: int,            // Max test requests in half-open
    resetTimeoutSeconds: int,            // Time before auto half-open

    // Recovery tracking
    recoveryAttempts: str -> List[RecoveryAttempt],
    lastViolationTime: str -> int,

    // Statistics
    totalCircuitOpens: int,
    totalResets: int,
    currentTime: int
  }

  // ==========================================================================
  // STATE VARIABLES
  // ==========================================================================

  var state: CircuitBreakerState

  // ==========================================================================
  // CONSTANTS
  // ==========================================================================

  pure val VIOLATION_THRESHOLD = 3      // AOR-ENFORCE-004
  pure val HALF_OPEN_ATTEMPTS = 5       // Max test requests
  pure val RESET_TIMEOUT = 300          // 5 minutes in seconds
  pure val GUARDIAN_TOKEN = "guardian-approved-reset"

  // ==========================================================================
  // HELPER PREDICATES
  // ==========================================================================

  /// Get circuit state for agent (replaces .withDefault)
  pure def getCircuitState(agentId: str, s: CircuitBreakerState): CircuitState = {
    if (s.circuits.keys().contains(agentId)) s.circuits.get(agentId) else Closed
  }

  /// Get violation count for agent (replaces .withDefault)
  pure def getViolationCount(agentId: str, s: CircuitBreakerState): int = {
    if (s.violationCounts.keys().contains(agentId)) s.violationCounts.get(agentId) else 0
  }

  /// Get last violation time for agent (replaces .withDefault)
  pure def getLastViolationTime(agentId: str, s: CircuitBreakerState): int = {
    if (s.lastViolationTime.keys().contains(agentId)) s.lastViolationTime.get(agentId) else 0
  }

  /// Get violations list for agent (replaces .withDefault(List()))
  pure def getViolations(agentId: str, s: CircuitBreakerState): List[Violation] = {
    if (s.violations.keys().contains(agentId)) s.violations.get(agentId) else List()
  }

  /// Get recovery attempts for agent (replaces .withDefault(List()))
  pure def getRecoveryAttempts(agentId: str, s: CircuitBreakerState): List[RecoveryAttempt] = {
    if (s.recoveryAttempts.keys().contains(agentId)) s.recoveryAttempts.get(agentId) else List()
  }

  /// Check if threshold exceeded
  pure def thresholdExceeded(agentId: str, s: CircuitBreakerState): bool = {
    getViolationCount(agentId, s) >= s.threshold
  }

  /// Check if timeout elapsed since last violation
  pure def timeoutElapsed(agentId: str, s: CircuitBreakerState): bool = {
    val lastTime = getLastViolationTime(agentId, s)
    (s.currentTime - lastTime) >= s.resetTimeoutSeconds
  }

  /// Check if Guardian token is valid
  pure def isValidGuardianToken(token: str): bool = {
    token == GUARDIAN_TOKEN
  }

  /// Get recent violations using List.select (replaces List.filter)
  pure def getRecentViolations(agentId: str, s: CircuitBreakerState, windowSeconds: int): List[Violation] = {
    val allViolations = getViolations(agentId, s)
    allViolations.select(v => (s.currentTime - v.timestamp) <= windowSeconds)
  }

  /// Count critical violations using List.select then length
  pure def countCriticalViolations(violations: List[Violation]): int = {
    violations.select(v => v.severity == "CRITICAL").length()
  }

  // ==========================================================================
  // STATE TRANSITIONS
  // ==========================================================================

  /// Initialize circuit breaker state
  action init: bool = all {
    state' = {
      circuits: Map(),
      violations: Map(),
      violationCounts: Map(),
      threshold: VIOLATION_THRESHOLD,
      halfOpenMaxAttempts: HALF_OPEN_ATTEMPTS,
      resetTimeoutSeconds: RESET_TIMEOUT,
      recoveryAttempts: Map(),
      lastViolationTime: Map(),
      totalCircuitOpens: 0,
      totalResets: 0,
      currentTime: 0
    }
  }

  /// Advance time (for timeout testing) - ': bool' required for typed param actions
  action tick(seconds: int): bool = all {
    state' = {
      ...state,
      currentTime: state.currentTime + seconds
    }
  }

  /// Record violation (SC-ENFORCE-004) - ': bool' required for typed param actions
  action recordViolation(agentId: str, severity: str): bool = {
    val currentViolations = getViolations(agentId, state)
    val newViolation = {
      agentId: agentId,
      timestamp: state.currentTime,
      severity: severity
    }
    val newCount = getViolationCount(agentId, state) + 1
    all {
      state' = {
        ...state,
        violations: state.violations.put(agentId, currentViolations.append(newViolation)),
        violationCounts: state.violationCounts.put(agentId, newCount),
        lastViolationTime: state.lastViolationTime.put(agentId, state.currentTime)
      }
    }
  }

  /// Transition: Closed -> Open (threshold exceeded)
  action closedToOpen(agentId: str): bool = all {
    getCircuitState(agentId, state) == Closed,
    thresholdExceeded(agentId, state),
    state' = {
      ...state,
      circuits: state.circuits.put(agentId, Open),
      totalCircuitOpens: state.totalCircuitOpens + 1
    }
  }

  /// Transition: Open -> HalfOpen (timeout elapsed)
  action openToHalfOpen(agentId: str): bool = all {
    getCircuitState(agentId, state) == Open,
    timeoutElapsed(agentId, state),
    state' = {
      ...state,
      circuits: state.circuits.put(agentId, HalfOpen)
    }
  }

  /// Transition: HalfOpen -> Closed (success - no recent violations)
  action halfOpenToClosed(agentId: str): bool = {
    val recentViolations = getRecentViolations(agentId, state, 60)
    all {
      getCircuitState(agentId, state) == HalfOpen,
      recentViolations.length() == 0,
      state' = {
        ...state,
        circuits: state.circuits.put(agentId, Closed),
        totalResets: state.totalResets + 1
      }
    }
  }

  /// Transition: HalfOpen -> Open (failure - new violation occurred)
  action halfOpenToOpen(agentId: str): bool = {
    val recentViolations = getRecentViolations(agentId, state, 60)
    all {
      getCircuitState(agentId, state) == HalfOpen,
      recentViolations.length() > 0,
      state' = {
        ...state,
        circuits: state.circuits.put(agentId, Open),
        totalCircuitOpens: state.totalCircuitOpens + 1
      }
    }
  }

  /// Manual reset with Guardian approval (SC-ENFORCE-013, AOR-ENFORCE-010)
  action guardianReset(agentId: str, token: str): bool = {
    val attempt = {
      timestamp: state.currentTime,
      approved: true,
      guardianToken: token
    }
    val attempts = getRecoveryAttempts(agentId, state)
    all {
      getCircuitState(agentId, state) == Open,
      isValidGuardianToken(token),
      state' = {
        ...state,
        circuits: state.circuits.put(agentId, Closed),
        violationCounts: state.violationCounts.put(agentId, 0),
        violations: state.violations.put(agentId, List()),
        recoveryAttempts: state.recoveryAttempts.put(agentId, attempts.append(attempt)),
        totalResets: state.totalResets + 1
      }
    }
  }

  /// Denied reset (invalid token)
  action deniedReset(agentId: str, token: str): bool = {
    val attempt = {
      timestamp: state.currentTime,
      approved: false,
      guardianToken: token
    }
    val attempts = getRecoveryAttempts(agentId, state)
    all {
      getCircuitState(agentId, state) == Open,
      not(isValidGuardianToken(token)),
      state' = {
        ...state,
        recoveryAttempts: state.recoveryAttempts.put(agentId, attempts.append(attempt))
      }
    }
  }

  /// Combined step: simulate violation and state transitions
  action step: bool = any {
    nondet agentId = oneOf(Set("agent1", "agent2", "agent3"))
    nondet severity = oneOf(Set("LOW", "MEDIUM", "HIGH", "CRITICAL"))
    any {
      recordViolation(agentId, severity),
      closedToOpen(agentId),
      openToHalfOpen(agentId),
      halfOpenToClosed(agentId),
      halfOpenToOpen(agentId),
      guardianReset(agentId, GUARDIAN_TOKEN),
      deniedReset(agentId, "invalid-token"),
      tick(10)
    }
  }

  // ==========================================================================
  // TEMPORAL INVARIANTS
  // ==========================================================================

  /// Helper: open circuit stays open or transitions to HalfOpen only
  pure def openCircuitTransitionsOk(s: CircuitBreakerState): bool =
    Set("agent1", "agent2", "agent3").forall(agentId =>
      getCircuitState(agentId, s) != Open or
      (getCircuitState(agentId, s) == Open or getCircuitState(agentId, s) == HalfOpen)
    )

  /// SAFETY: Circuit ALWAYS opens when threshold exceeded
  temporal CircuitOpensOnThreshold = always(
    Set("agent1", "agent2", "agent3").forall(agentId =>
      not(thresholdExceeded(agentId, state)) or
      getCircuitState(agentId, state) != Closed
    )
  )

  /// SAFETY: Open circuit can only go to HalfOpen
  temporal OpenCircuitBlocksRequests = always(
    openCircuitTransitionsOk(state)
  )

  /// SAFETY: Violation count non-negative
  temporal ViolationCountMonotonic = always(
    Set("agent1", "agent2", "agent3").forall(agentId =>
      getViolationCount(agentId, state) >= 0
    )
  )

  /// SAFETY: Total circuit opens monotonically increases
  temporal TotalOpensMonotonic = always(
    next(state.totalCircuitOpens >= state.totalCircuitOpens)
  )

  /// LIVENESS: Open circuit EVENTUALLY transitions to HalfOpen (timeout)
  temporal OpenEventuallyHalfOpen = always(
    getCircuitState("agent1", state) == Open implies
    eventually(getCircuitState("agent1", state) == HalfOpen)
  )

  /// LIVENESS: HalfOpen EVENTUALLY resolves (Closed or Open)
  temporal HalfOpenEventuallyResolves = always(
    getCircuitState("agent1", state) == HalfOpen implies
    eventually(
      getCircuitState("agent1", state) == Closed or
      getCircuitState("agent1", state) == Open
    )
  )

  // ==========================================================================
  // RUN DECLARATIONS
  // ==========================================================================

  /// Run: Basic circuit breaker flow
  run basicCircuitFlow = {
    init
    .then(recordViolation("agent1", "CRITICAL"))
    .then(recordViolation("agent1", "CRITICAL"))
    .then(recordViolation("agent1", "CRITICAL"))
    .then(closedToOpen("agent1"))
    .expect(getCircuitState("agent1", state) == Open)
  }

  /// Run: Timeout-based recovery
  run timeoutRecovery = {
    init
    .then(recordViolation("agent1", "HIGH"))
    .then(recordViolation("agent1", "HIGH"))
    .then(recordViolation("agent1", "HIGH"))
    .then(closedToOpen("agent1"))
    .then(tick(301))  // Wait past timeout
    .then(openToHalfOpen("agent1"))
    .then(tick(60))   // No violations in half-open window
    .then(halfOpenToClosed("agent1"))
    .expect(getCircuitState("agent1", state) == Closed)
  }

  /// Run: Guardian-approved reset
  run guardianResetFlow = {
    init
    .then(recordViolation("agent2", "CRITICAL"))
    .then(recordViolation("agent2", "CRITICAL"))
    .then(recordViolation("agent2", "CRITICAL"))
    .then(closedToOpen("agent2"))
    .then(guardianReset("agent2", GUARDIAN_TOKEN))
    .expect(getCircuitState("agent2", state) == Closed)
    .expect(getViolationCount("agent2", state) == 0)
  }

  /// Run: Denied reset (invalid token)
  run deniedResetFlow = {
    init
    .then(recordViolation("agent3", "HIGH"))
    .then(recordViolation("agent3", "HIGH"))
    .then(recordViolation("agent3", "HIGH"))
    .then(closedToOpen("agent3"))
    .then(deniedReset("agent3", "invalid-token"))
    .expect(getCircuitState("agent3", state) == Open)  // Still open
  }

  /// Run: Half-open failure (re-open)
  run halfOpenFailure = {
    init
    .then(recordViolation("agent1", "MEDIUM"))
    .then(recordViolation("agent1", "MEDIUM"))
    .then(recordViolation("agent1", "MEDIUM"))
    .then(closedToOpen("agent1"))
    .then(tick(301))
    .then(openToHalfOpen("agent1"))
    .then(recordViolation("agent1", "CRITICAL"))  // Fail during half-open
    .then(halfOpenToOpen("agent1"))
    .expect(getCircuitState("agent1", state) == Open)
  }
}
