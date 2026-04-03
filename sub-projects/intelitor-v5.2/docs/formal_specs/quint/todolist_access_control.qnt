// =============================================================================
// todolist_access_control.qnt
// Formal Model for PROJECT_TODOLIST.md Access Control
// =============================================================================
// STAMP: SC-TODO-001 to SC-TODO-008
// AOR: AOR-TODO-001 to AOR-TODO-010
// =============================================================================

module TodolistAccessControl {

  // =========================================================================
  // TYPE DEFINITIONS
  // =========================================================================

  type AgentId = str
  type MethodId = str
  type FilePath = str

  type AccessMethod =
    | DirectRead
    | DirectWrite
    | ShellCat
    | ShellGrep
    | ShellSed
    | ShellEcho
    | FSharpCLI
    | ChayaCLI
    | FSharpAPI

  type AccessResult =
    | Allowed
    | Blocked
    | Denied
    | Alerted

  type AccessState =
    | Idle
    | Requested
    | Validating
    | Executing
    | Logging
    | Completed

  // =========================================================================
  // STATE VARIABLES
  // =========================================================================

  var accessState: AccessState
  var currentAgent: AgentId
  var currentMethod: AccessMethod
  var accessLog: List[(AgentId, AccessMethod, AccessResult)]
  var violationCount: int
  var lastResult: AccessResult

  // =========================================================================
  // CONSTANTS
  // =========================================================================

  val TODOLIST_PATH: FilePath = "PROJECT_TODOLIST.md"

  val AGENTS: Set[AgentId] = Set("claude", "gemini", "grok", "system")

  val DIRECT_METHODS: Set[AccessMethod] = Set(
    DirectRead, DirectWrite, ShellCat, ShellGrep, ShellSed, ShellEcho
  )

  val AUTHORIZED_METHODS: Set[AccessMethod] = Set(
    FSharpCLI, ChayaCLI, FSharpAPI
  )

  // =========================================================================
  // HELPER FUNCTIONS
  // =========================================================================

  pure def isAgent(id: AgentId): bool = AGENTS.contains(id)

  pure def isDirectAccess(method: AccessMethod): bool =
    DIRECT_METHODS.contains(method)

  pure def isAuthorized(method: AccessMethod): bool =
    AUTHORIZED_METHODS.contains(method)

  // SC-TODO-001: Access decision logic
  pure def accessDecision(agent: AgentId, method: AccessMethod): AccessResult =
    if (isAgent(agent) and isDirectAccess(method)) {
      Blocked  // VIOLATION: Agent direct access blocked
    } else if (isAuthorized(method)) {
      Allowed  // Authorized method OK
    } else if (not(isAgent(agent)) and isDirectAccess(method)) {
      Allowed  // Human direct access allowed
    } else {
      Denied   // Unknown method denied
    }

  // =========================================================================
  // INITIAL STATE
  // =========================================================================

  action init = all {
    accessState' = Idle,
    currentAgent' = "",
    currentMethod' = FSharpCLI,
    accessLog' = [],
    violationCount' = 0,
    lastResult' = Allowed
  }

  // =========================================================================
  // STATE TRANSITIONS
  // =========================================================================

  // Request access (any agent, any method)
  action requestAccess(agent: AgentId, method: AccessMethod): bool = all {
    accessState == Idle,
    accessState' = Requested,
    currentAgent' = agent,
    currentMethod' = method,
    accessLog' = accessLog,
    violationCount' = violationCount,
    lastResult' = lastResult
  }

  // Validate access request
  action validateAccess = all {
    accessState == Requested,
    val decision = accessDecision(currentAgent, currentMethod);
    all {
      accessState' = Validating,
      lastResult' = decision,
      violationCount' = if (decision == Blocked) violationCount + 1 else violationCount,
      currentAgent' = currentAgent,
      currentMethod' = currentMethod,
      accessLog' = accessLog
    }
  }

  // Execute if allowed
  action executeIfAllowed = all {
    accessState == Validating,
    lastResult == Allowed,
    accessState' = Executing,
    currentAgent' = currentAgent,
    currentMethod' = currentMethod,
    accessLog' = accessLog,
    violationCount' = violationCount,
    lastResult' = lastResult
  }

  // Block if denied
  action blockIfDenied = all {
    accessState == Validating,
    lastResult == Blocked or lastResult == Denied,
    accessState' = Logging,
    currentAgent' = currentAgent,
    currentMethod' = currentMethod,
    accessLog' = accessLog,
    violationCount' = violationCount,
    lastResult' = lastResult
  }

  // Log and complete
  action logAndComplete = all {
    accessState == Executing or accessState == Logging,
    accessState' = Completed,
    accessLog' = accessLog.append((currentAgent, currentMethod, lastResult)),
    currentAgent' = currentAgent,
    currentMethod' = currentMethod,
    violationCount' = violationCount,
    lastResult' = lastResult
  }

  // Return to idle
  action returnToIdle = all {
    accessState == Completed,
    accessState' = Idle,
    currentAgent' = "",
    currentMethod' = FSharpCLI,
    accessLog' = accessLog,
    violationCount' = violationCount,
    lastResult' = lastResult
  }

  // =========================================================================
  // COMBINED STEP
  // =========================================================================

  action step = any {
    nondet agent = AGENTS.oneOf();
    nondet method = (DIRECT_METHODS.union(AUTHORIZED_METHODS)).oneOf();
    requestAccess(agent, method),
    validateAccess,
    executeIfAllowed,
    blockIfDenied,
    logAndComplete,
    returnToIdle
  }

  // =========================================================================
  // INVARIANTS (Must always hold)
  // =========================================================================

  // SC-TODO-001: Agents cannot directly access todolist
  val directAccessInvariant: bool =
    (accessState == Executing) implies (not(isDirectAccess(currentMethod)) or not(isAgent(currentAgent)))

  // SC-TODO-004: Only authorized methods execute
  val authorizedMethodInvariant: bool =
    (accessState == Executing) implies (isAuthorized(currentMethod) or not(isAgent(currentAgent)))

  // Safety: No direct agent access ever succeeds
  // (Lists don't have forall — use select to find violations, check none exist)
  val safetyInvariant: bool =
    accessLog.select(entry =>
      isAgent(entry._1) and isDirectAccess(entry._2) and entry._3 == Allowed
    ).length() == 0

  // =========================================================================
  // TEMPORAL PROPERTIES
  // =========================================================================

  // Liveness: Every request eventually completes
  temporal requestEventuallyCompletes: bool =
    always(accessState == Requested implies eventually(accessState == Completed))

  // Liveness: Blocked requests are logged
  temporal blockedRequestsLogged: bool =
    always((lastResult == Blocked) implies eventually(accessLog.length() > 0))

  // Safety: Direct access never succeeds (temporal)
  temporal directAccessNeverSucceeds: bool =
    always(not(accessState == Executing and isAgent(currentAgent) and isDirectAccess(currentMethod)))

  // =========================================================================
  // TESTS
  // =========================================================================

  // Identity action for test assertions (keeps all state unchanged)
  action stutter = all {
    accessState' = accessState,
    currentAgent' = currentAgent,
    currentMethod' = currentMethod,
    accessLog' = accessLog,
    violationCount' = violationCount,
    lastResult' = lastResult
  }

  // Test: Claude using DirectRead should be blocked
  run testClaudeDirectReadBlocked = {
    init
    .then(requestAccess("claude", DirectRead))
    .then(validateAccess)
    .then(all { lastResult == Blocked, accessState == Validating, stutter })
  }

  // Test: Claude using FSharpCLI should be allowed
  run testClaudeFSharpAllowed = {
    init
    .then(requestAccess("claude", FSharpCLI))
    .then(validateAccess)
    .then(all { lastResult == Allowed, accessState == Validating, stutter })
    .then(executeIfAllowed)
    .then(all { accessState == Executing, stutter })
  }

  // Test: Gemini using ShellCat should be blocked
  run testGeminiShellCatBlocked = {
    init
    .then(requestAccess("gemini", ShellCat))
    .then(validateAccess)
    .then(all { lastResult == Blocked, stutter })
  }

  // Test: All agents blocked from DirectWrite
  run testAllAgentsBlockedDirectWrite = {
    init
    .then(requestAccess("claude", DirectWrite))
    .then(validateAccess)
    .then(blockIfDenied)
    .then(all { accessState == Logging, stutter })
  }

}
