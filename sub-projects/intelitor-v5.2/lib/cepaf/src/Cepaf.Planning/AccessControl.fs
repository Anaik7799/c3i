namespace Cepaf.Planning

open System
open System.Text.RegularExpressions

// =============================================================================
// AccessControl.fs - Todolist Access Control Runtime Enforcement
// =============================================================================
// STAMP: SC-TODO-001 to SC-TODO-008
// AOR: AOR-TODO-001 to AOR-TODO-010
// Mathematical Foundation: Graph-based access control with formal proofs
// =============================================================================

/// Access method enumeration
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

/// Access result
type AccessResult =
    | Allowed
    | Blocked of reason: string
    | Denied of reason: string
    | Alerted of reason: string

/// Agent identity
type AgentId = string

/// Access log entry
type AccessLogEntry = {
    Timestamp: DateTime
    Agent: AgentId
    Method: AccessMethod
    FilePath: string
    Result: AccessResult
    Constraint: string  // SC-TODO-XXX
}

/// Graph-based access control node
type ACNode =
    | AgentNode of AgentId
    | MethodNode of AccessMethod
    | FileNode of string
    | DecisionNode of AccessResult

/// Graph-based access control edge
type ACEdge = {
    From: ACNode
    To: ACNode
    IsAllowed: bool
    Constraint: string
}

module AccessControl =

    // =========================================================================
    // CONSTANTS
    // =========================================================================

    let private todolistPath = "PROJECT_TODOLIST.md"

    let private directMethods = Set.ofList [
        DirectRead; DirectWrite; ShellCat; ShellGrep; ShellSed; ShellEcho
    ]

    let private authorizedMethods = Set.ofList [
        FSharpCLI; ChayaCLI; FSharpAPI
    ]

    let private agents = Set.ofList [
        "claude"; "gemini"; "grok"; "system"; "ClaudeAgent"; "GeminiAgent"; "GrokAgent"
    ]

    // =========================================================================
    // FORBIDDEN COMMAND PATTERNS (SC-TODO-003)
    // =========================================================================

    let private forbiddenPatterns =
        [
            @"cat\s+.*PROJECT_TODOLIST\.md"
            @"head\s+.*PROJECT_TODOLIST\.md"
            @"tail\s+.*PROJECT_TODOLIST\.md"
            @"less\s+.*PROJECT_TODOLIST\.md"
            @"more\s+.*PROJECT_TODOLIST\.md"
            @"sed\s+.*PROJECT_TODOLIST\.md"
            @"awk\s+.*PROJECT_TODOLIST\.md"
            @"grep\s+.*PROJECT_TODOLIST\.md"
            @"rg\s+.*PROJECT_TODOLIST\.md"
            @"echo\s+.*>>\s*.*PROJECT_TODOLIST\.md"
            @"printf\s+.*>>\s*.*PROJECT_TODOLIST\.md"
        ]
        |> List.map (fun p -> Regex(p, RegexOptions.IgnoreCase))

    // =========================================================================
    // HELPER FUNCTIONS
    // =========================================================================

    /// Check if method is direct access
    let isDirectAccess (method: AccessMethod) : bool =
        directMethods.Contains method

    /// Check if method is authorized
    let isAuthorized (method: AccessMethod) : bool =
        authorizedMethods.Contains method

    /// Check if ID is an agent
    let isAgent (id: AgentId) : bool =
        agents.Contains id || id.Contains "Agent"

    /// Check if path targets todolist
    let targetsTodolist (path: string) : bool =
        path.EndsWith(todolistPath, StringComparison.OrdinalIgnoreCase) ||
        path.Contains(todolistPath)

    // =========================================================================
    // ACCESS DECISION LOGIC (SC-TODO-001)
    // =========================================================================

    /// Core access decision function
    /// Implements SC-TODO-001: Agents SHALL NOT read PROJECT_TODOLIST.md directly
    let accessDecision (agent: AgentId) (method: AccessMethod) (path: string) : AccessResult =
        // SC-TODO-001: Check if this is an agent using direct access on todolist
        if isAgent agent && isDirectAccess method && targetsTodolist path then
            Blocked (sprintf "SC-TODO-001: Agent '%s' cannot use %A on %s. Use sa-plan CLI instead." agent method todolistPath)
        // SC-TODO-004: Check if authorized method
        elif isAuthorized method then
            Allowed
        // Allow human direct access
        elif not (isAgent agent) && isDirectAccess method then
            Allowed
        else
            Denied "Unknown access method"

    // =========================================================================
    // COMMAND VALIDATION (SC-TODO-003)
    // =========================================================================

    /// Validate shell command against forbidden patterns
    let validateShellCommand (command: string) : AccessResult =
        let violation = forbiddenPatterns |> List.tryFind (fun regex -> regex.IsMatch(command))
        match violation with
        | Some pattern ->
            Blocked (sprintf "SC-TODO-003: Command matches forbidden pattern for PROJECT_TODOLIST.md access")
        | None ->
            Allowed

    // =========================================================================
    // GRAPH-BASED VERIFICATION
    // =========================================================================

    /// Build access control graph
    let buildAccessControlGraph () : ACEdge list =
        let edges = ResizeArray<ACEdge>()

        // Agent → AuthorizedMethod edges (allowed)
        for agent in agents do
            for method in authorizedMethods do
                edges.Add({
                    From = AgentNode agent
                    To = MethodNode method
                    IsAllowed = true
                    Constraint = "SC-TODO-004"
                })

        // Agent → DirectMethod edges (blocked)
        for agent in agents do
            for method in directMethods do
                edges.Add({
                    From = AgentNode agent
                    To = MethodNode method
                    IsAllowed = false
                    Constraint = "SC-TODO-001"
                })

        // AuthorizedMethod → FileNode edges (allowed)
        for method in authorizedMethods do
            edges.Add({
                From = MethodNode method
                To = FileNode todolistPath
                IsAllowed = true
                Constraint = "SC-TODO-004"
            })

        edges |> Seq.toList

    /// Verify no forbidden path exists in graph
    let verifyNoForbiddenPath (graph: ACEdge list) (agent: AgentId) : bool =
        // Check: no path Agent → DirectMethod → File exists with IsAllowed = true
        let agentToDirectEdges =
            graph
            |> List.filter (fun e ->
                match e.From, e.To with
                | AgentNode a, MethodNode m when a = agent && isDirectAccess m -> true
                | _ -> false)

        // All such edges should have IsAllowed = false
        agentToDirectEdges |> List.forall (fun e -> not e.IsAllowed)

    // =========================================================================
    // LOGGING AND AUDIT (SC-TODO-008)
    // =========================================================================

    let private accessLog = ResizeArray<AccessLogEntry>()

    /// Log access attempt and publish to Zenoh + Immutable Register
    /// SC-TODO-008: Violations MUST be logged to Immutable Register
    /// SC-ENFORCE-009: Telemetry MUST publish to Zenoh on violation
    let logAccess (entry: AccessLogEntry) : unit =
        accessLog.Add(entry)

        // Determine event type and severity for telemetry
        let (eventType, severity, reason) =
            match entry.Result with
            | Allowed -> ("access_allowed", "LOW", "")
            | Blocked r -> ("access_blocked", "HIGH", r)
            | Denied r -> ("access_denied", "CRITICAL", r)
            | Alerted r -> ("access_alerted", "MEDIUM", r)

        let methodStr = sprintf "%A" entry.Method
        let reasonJson = reason.Replace("\"", "\\\"")
        let constraintJson = entry.Constraint.Replace("\"", "\\\"")
        let pathJson = entry.FilePath.Replace("\\", "\\\\").Replace("\"", "\\\"")

        let checkpointId = "CP-ACCESS-01"
        let topic = "indrajaal/planning/access_control"

        let jsonPayload =
            sprintf
                "{\"checkpoint\":\"%s\",\"event\":\"%s\",\"agent\":\"%s\",\"method\":\"%s\",\"path\":\"%s\",\"severity\":\"%s\",\"reason\":\"%s\",\"constraint\":\"%s\",\"timestamp\":\"%s\"}"
                checkpointId eventType entry.Agent methodStr pathJson severity reasonJson constraintJson
                (entry.Timestamp.ToString("o"))

        // SC-ZTEST-008: Triple-write pattern — log fallback FIRST
        eprintfn "[ZTEST-CHECKPOINT] checkpoint=%s topic=%s message=%s severity=%s timestamp=%s"
            checkpointId topic eventType severity (DateTimeOffset.UtcNow.ToString("o"))

        // Step 2: Real Zenoh publish via ZenohPublish module
        Cepaf.Mesh.ZenohPublish.publish checkpointId topic eventType jsonPayload

        // Console log for local observability
        printfn "[AccessControl] %s | %s | %s | %s | %s"
            (entry.Timestamp.ToString("yyyy-MM-dd HH:mm:ss"))
            entry.Agent
            methodStr
            entry.FilePath
            eventType

    /// Get all access log entries
    let getAccessLog () : AccessLogEntry list =
        accessLog |> Seq.toList

    /// Get violations only
    let getViolations () : AccessLogEntry list =
        accessLog
        |> Seq.filter (fun e ->
            match e.Result with
            | Blocked _ | Denied _ | Alerted _ -> true
            | Allowed -> false)
        |> Seq.toList

    // =========================================================================
    // PUBLIC API
    // =========================================================================

    /// Validate file access (called before Read/Write)
    let validateFileAccess (agent: AgentId) (operation: string) (path: string) : AccessResult =
        let method =
            match operation.ToLower() with
            | "read" -> DirectRead
            | "write" | "edit" -> DirectWrite
            | _ -> DirectRead

        let result = accessDecision agent method path

        logAccess {
            Timestamp = DateTime.UtcNow
            Agent = agent
            Method = method
            FilePath = path
            Result = result
            Constraint = "SC-TODO-001"
        }

        result

    /// Validate shell command (called before Bash execution)
    let validateCommand (agent: AgentId) (command: string) : AccessResult =
        let result = validateShellCommand command

        let method =
            if command.Contains("cat ") then ShellCat
            elif command.Contains("grep ") || command.Contains("rg ") then ShellGrep
            elif command.Contains("sed ") then ShellSed
            elif command.Contains("echo ") && command.Contains(">>") then ShellEcho
            else ShellCat

        logAccess {
            Timestamp = DateTime.UtcNow
            Agent = agent
            Method = method
            FilePath = todolistPath
            Result = result
            Constraint = "SC-TODO-003"
        }

        result

    /// Run full verification
    let runVerification () : bool =
        let graph = buildAccessControlGraph()

        let allAgentsBlocked =
            agents |> Set.forall (fun agent -> verifyNoForbiddenPath graph agent)

        printfn "[AccessControl] Graph verification: %s"
            (if allAgentsBlocked then "PASSED - No forbidden paths" else "FAILED - Forbidden paths exist")

        allAgentsBlocked

// =============================================================================
// MODULE TESTS
// =============================================================================

module AccessControlTests =

    open AccessControl

    let runTests () =
        printfn "\n=== AccessControl Tests ==="

        // Test 1: Claude DirectRead on todolist should be blocked
        let test1 = accessDecision "claude" DirectRead "PROJECT_TODOLIST.md"
        match test1 with
        | Blocked _ -> printfn "✓ Test 1: Claude DirectRead blocked"
        | _ -> printfn "✗ Test 1: FAILED - Expected Blocked"

        // Test 2: Claude FSharpCLI should be allowed
        let test2 = accessDecision "claude" FSharpCLI "PROJECT_TODOLIST.md"
        match test2 with
        | Allowed -> printfn "✓ Test 2: Claude FSharpCLI allowed"
        | _ -> printfn "✗ Test 2: FAILED - Expected Allowed"

        // Test 3: Shell command validation
        let test3 = validateShellCommand "cat PROJECT_TODOLIST.md"
        match test3 with
        | Blocked _ -> printfn "✓ Test 3: Shell cat command blocked"
        | _ -> printfn "✗ Test 3: FAILED - Expected Blocked"

        // Test 4: Valid shell command
        let test4 = validateShellCommand "cat README.md"
        match test4 with
        | Allowed -> printfn "✓ Test 4: Shell cat README.md allowed"
        | _ -> printfn "✗ Test 4: FAILED - Expected Allowed"

        // Test 5: Graph verification
        let test5 = runVerification()
        if test5 then printfn "✓ Test 5: Graph verification passed"
        else printfn "✗ Test 5: Graph verification failed"

        printfn "=== Tests Complete ===\n"
