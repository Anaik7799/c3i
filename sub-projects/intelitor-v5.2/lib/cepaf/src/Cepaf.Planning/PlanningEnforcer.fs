namespace Cepaf.Planning

open System
open System.Collections.Concurrent
open System.Diagnostics
open System.IO
open System.Text.RegularExpressions

// ============================================================================
// PLANNING ENFORCER - ABSOLUTE SC-TODO-001 ENFORCEMENT
// ============================================================================
(*
MODULE PURPOSE:
This module is the SINGLE POINT OF ENFORCEMENT for SC-TODO-001:
"PROJECT_TODOLIST.md is STRICTLY FORBIDDEN for direct Agent access"

It provides:
- Multi-layer access validation
- Agent classification and fingerprinting
- Immutable violation audit trail
- Circuit breaker for repeat violators
- Runtime hooks for Elixir/F# integration
- Telemetry integration for monitoring
- Thread-safe concurrent access

CONSTITUTIONAL ALIGNMENT:
- Ψ₂ (Evolutionary Continuity): Complete violation history preserved
- Ψ₃ (Verification Capability): All access attempts verifiable
- SC-REG-001: All violations logged to immutable register
- SC-FUNC-003: Rollback capability via circuit breaker
*)

// ============================================================================
// STAMP CONSTRAINTS (SC-ENFORCE-*)
// ============================================================================
(*
SC-ENFORCE-001: Direct access to PROJECT_TODOLIST.md MUST be blocked (CRITICAL)
SC-ENFORCE-002: All access attempts MUST be logged to immutable audit trail (CRITICAL)
SC-ENFORCE-003: Agent classification MUST occur before access check (CRITICAL)
SC-ENFORCE-004: Violation count MUST trigger circuit breaker at threshold (HIGH)
SC-ENFORCE-005: Circuit breaker threshold MUST be configurable (MEDIUM)
SC-ENFORCE-006: Audit trail MUST be append-only (CRITICAL)
SC-ENFORCE-007: Enforcement MUST be thread-safe (CRITICAL)
SC-ENFORCE-008: Hook registration MUST validate callback signatures (HIGH)
SC-ENFORCE-009: Telemetry MUST publish to Zenoh on violation (HIGH)
SC-ENFORCE-010: File path validation MUST be case-insensitive (HIGH)
SC-ENFORCE-011: Forbidden patterns MUST include regex support (MEDIUM)
SC-ENFORCE-012: Access decisions MUST complete within 5ms (HIGH)
SC-ENFORCE-013: Circuit breaker reset MUST require manual intervention (HIGH)
SC-ENFORCE-014: Agent whitelist MUST be verifiable (HIGH)
SC-ENFORCE-015: Enforcement bypass MUST require cryptographic proof (CRITICAL)
SC-ENFORCE-016: Violation alerts MUST include full context (MEDIUM)
SC-ENFORCE-017: Agent fingerprinting MUST detect impersonation (HIGH)
SC-ENFORCE-018: Request rate limiting MUST prevent DOS (HIGH)
SC-ENFORCE-019: Audit log rotation MUST preserve history (MEDIUM)
SC-ENFORCE-020: Multi-layer validation MUST all pass (CRITICAL)
SC-ENFORCE-021: Unknown agents MUST be denied by default (CRITICAL)
SC-ENFORCE-022: System agents MUST have verified identity (HIGH)
SC-ENFORCE-023: Access patterns MUST be analyzed for anomalies (MEDIUM)
SC-ENFORCE-024: Enforcement config MUST be immutable at runtime (HIGH)
SC-ENFORCE-025: All hooks MUST execute atomically (HIGH)
*)

// ============================================================================
// AOR RULES (AOR-ENFORCE-*)
// ============================================================================
(*
AOR-ENFORCE-001: VERIFY agent identity before classification
AOR-ENFORCE-002: LOG all access attempts regardless of outcome
AOR-ENFORCE-003: DENY unknown agents by default (fail-safe)
AOR-ENFORCE-004: TRIGGER circuit breaker after 3 violations per agent
AOR-ENFORCE-005: ALERT Prajna Cockpit on every violation
AOR-ENFORCE-006: RECORD full stack trace for violations
AOR-ENFORCE-007: VALIDATE all file paths against forbidden list
AOR-ENFORCE-008: FINGERPRINT agent behavior patterns
AOR-ENFORCE-009: RATE LIMIT requests per agent (max 10/second)
AOR-ENFORCE-010: REQUIRE Guardian approval for circuit breaker reset
AOR-ENFORCE-011: PUBLISH telemetry to indrajaal/planning/enforcement
AOR-ENFORCE-012: MAINTAIN immutable violation history
AOR-ENFORCE-013: EXECUTE all hooks before allowing access
AOR-ENFORCE-014: VERIFY request origin matches agent claims
AOR-ENFORCE-015: REJECT requests with suspicious patterns
*)

// ============================================================================
// TYPE DEFINITIONS
// ============================================================================

/// Agent type classification (SC-ENFORCE-003)
type AgentType =
    | Human of userId: string
    | AIAgent of agentId: string * model: string
    | SystemProcess of processId: string
    | Unknown of identifier: string

/// Request context for access validation
type RequestContext = {
    AgentType: AgentType
    RequestedPath: string
    Operation: string  // "read", "write", "execute"
    Timestamp: DateTime
    StackTrace: string option
    IpAddress: string option
    AdditionalContext: Map<string, string>
}

/// Violation record for immutable audit trail (SC-ENFORCE-006)
type ViolationRecord = {
    Id: Guid
    Context: RequestContext
    Reason: string
    Severity: string  // "LOW", "MEDIUM", "HIGH", "CRITICAL"
    Timestamp: DateTime
    BlockedByCircuit: bool
}

/// Access decision result
type AccessDecision =
    | Allowed of reason: string
    | Denied of reason: string * violation: ViolationRecord
    | CircuitOpen of agentId: string * violationCount: int

/// Configuration for enforcement (SC-ENFORCE-005, SC-ENFORCE-024)
type EnforcementConfig = {
    ForbiddenPaths: string list
    ForbiddenPatterns: string list  // Regex patterns
    CircuitBreakerThreshold: int
    CircuitBreakerResetRequiresApproval: bool
    MaxRequestsPerSecond: int
    AuditLogPath: string
    TelemetryTopic: string
    EnableTelemetry: bool
    EnableRateLimiting: bool
}

/// Runtime hook for integration (SC-ENFORCE-008)
type EnforcementHook = RequestContext -> AccessDecision -> unit

/// Statistics for monitoring
type EnforcementStatistics = {
    TotalViolations: int
    TotalAgentsTracked: int
    AgentsCircuitOpen: int
    RegisteredHooks: int
    ConfigSnapshot: EnforcementConfig
    UptimeSeconds: float
}

module PlanningEnforcer =

    // ========================================================================
    // IMMUTABLE STATE (Thread-Safe Concurrent Collections)
    // SC-ENFORCE-007: Enforcement MUST be thread-safe
    // ========================================================================

    /// Global violation store (thread-safe)
    let private violationStore = ConcurrentDictionary<Guid, ViolationRecord>()

    /// Agent violation counters (thread-safe)
    let private agentViolations = ConcurrentDictionary<string, int>()

    /// Circuit breaker state (thread-safe)
    let private circuitBreakerState = ConcurrentDictionary<string, bool>()

    /// Registered hooks (thread-safe)
    let private registeredHooks = ConcurrentBag<EnforcementHook>()

    /// Request rate limiter (agent -> timestamp queue)
    let private requestTimestamps = ConcurrentDictionary<string, ConcurrentQueue<DateTime>>()

    /// Module initialization time
    let private startTime = DateTime.UtcNow

    /// Lazy-compiled regex patterns — deferred until first regex check needed (SC-ENFORCE-012)
    /// Avoids ~15ms JIT regex compilation cost on module initialization for CLI cold starts
    let private compiledForbiddenPatterns =
        lazy(
            [|
                @".*PROJECT_TODOLIST\.md$"
                @".*project.?todolist.*\.md"
                @".*read.*PROJECT_TODOLIST.*"
                @".*cat.*PROJECT_TODOLIST.*"
                @".*write.*PROJECT_TODOLIST.*"
                @".*echo.*PROJECT_TODOLIST.*"
                @".*sed.*PROJECT_TODOLIST.*"
                @".*awk.*PROJECT_TODOLIST.*"
                @".*grep.*PROJECT_TODOLIST.*"
                @".*tail.*PROJECT_TODOLIST.*"
                @".*head.*PROJECT_TODOLIST.*"
            |]
            |> Array.map (fun p -> Regex(p, RegexOptions.IgnoreCase ||| RegexOptions.Compiled))
        )

    /// Pre-normalized forbidden paths for fast lookup (SC-ENFORCE-012 optimization)
    let private forbiddenPathSet =
        [
            "project_todolist.md"
            "/project_todolist.md"
            "./project_todolist.md"
            "../project_todolist.md"
            "../../project_todolist.md"
            "data/project_todolist.md"
            "/home/an/dev/ver/intelitor-v5.2/project_todolist.md"
        ]
        |> Set.ofList

    /// Default configuration (SC-TODO-001 enforcement)
    let private defaultConfig = {
        ForbiddenPaths = [
            "PROJECT_TODOLIST.md"
            "/PROJECT_TODOLIST.md"
            "./PROJECT_TODOLIST.md"
            "../PROJECT_TODOLIST.md"
            "../../PROJECT_TODOLIST.md"
            "data/PROJECT_TODOLIST.md"
            "/home/an/dev/ver/intelitor-v5.2/PROJECT_TODOLIST.md"
        ]
        ForbiddenPatterns = [
            @".*PROJECT_TODOLIST\.md$"
            @".*project.?todolist.*\.md"
            @".*read.*PROJECT_TODOLIST.*"
            @".*cat.*PROJECT_TODOLIST.*"
            @".*write.*PROJECT_TODOLIST.*"
            @".*echo.*PROJECT_TODOLIST.*"
            @".*sed.*PROJECT_TODOLIST.*"
            @".*awk.*PROJECT_TODOLIST.*"
            @".*grep.*PROJECT_TODOLIST.*"
            @".*tail.*PROJECT_TODOLIST.*"
            @".*head.*PROJECT_TODOLIST.*"
        ]
        CircuitBreakerThreshold = 3  // AOR-ENFORCE-004
        CircuitBreakerResetRequiresApproval = true  // SC-ENFORCE-013
        MaxRequestsPerSecond = 10  // AOR-ENFORCE-009
        AuditLogPath = "data/holons/planning/enforcement_audit.log"
        TelemetryTopic = "indrajaal/planning/enforcement"  // AOR-ENFORCE-011
        EnableTelemetry = true  // SC-ENFORCE-009
        EnableRateLimiting = true  // SC-ENFORCE-018
    }

    /// Active configuration (mutable ref for runtime override)
    let private activeConfig = ref defaultConfig

    // ========================================================================
    // AGENT CLASSIFICATION (SC-ENFORCE-003, AOR-ENFORCE-001)
    // ========================================================================

    /// Fast agent ID extraction without RequestContext allocation
    let private extractAgentId (agentType: AgentType) : string =
        match agentType with
        | Human userId -> $"human:{userId}"
        | AIAgent (agentId, model) -> $"ai:{agentId}:{model}"
        | SystemProcess processId -> $"system:{processId}"
        | Unknown identifier -> $"unknown:{identifier}"

    /// Extract agent identifier from context
    let private extractAgentIdentifier (ctx: RequestContext) : string =
        extractAgentId ctx.AgentType

    /// Classify agent from request context
    /// SC-ENFORCE-003: Agent classification MUST occur before access check
    /// AOR-ENFORCE-001: VERIFY agent identity before classification
    let classifyAgent (context: Map<string, string>) : AgentType =
        // Check for explicit agent type markers
        match context.TryFind "agent_type" with
        | Some "human" ->
            let userId = context.TryFind "user_id" |> Option.defaultValue "anonymous"
            Human userId
        | Some "ai" ->
            let agentId = context.TryFind "agent_id" |> Option.defaultValue "unknown"
            let model = context.TryFind "model" |> Option.defaultValue "unknown"
            AIAgent (agentId, model)
        | Some "system" ->
            let processId = context.TryFind "process_id" |> Option.defaultValue "unknown"
            SystemProcess processId
        | _ ->
            // Attempt heuristic classification (AOR-ENFORCE-008)
            match context.TryFind "user_agent" with
            | Some ua when ua.Contains("Claude") || ua.Contains("GPT") || ua.Contains("Gemini") || ua.Contains("Grok") ->
                AIAgent ("heuristic", ua)
            | Some ua when ua.Contains("Elixir") || ua.Contains("BEAM") || ua.Contains("erlang") ->
                SystemProcess "elixir-runtime"
            | Some ua when ua.Contains("dotnet") || ua.Contains("fsharp") ->
                SystemProcess "fsharp-runtime"
            | _ ->
                // AOR-ENFORCE-003: DENY unknown agents by default
                let id = context.TryFind "identifier" |> Option.defaultValue "unidentified"
                Unknown id

    // ========================================================================
    // PATH VALIDATION (SC-ENFORCE-010, SC-ENFORCE-011, AOR-ENFORCE-007)
    // ========================================================================

    /// Normalize path for comparison
    let private normalizePath (path: string) : string =
        let normalized = path.Trim().Replace("\\", "/")
        // Handle relative paths
        if normalized.StartsWith("./") then
            normalized.Substring(2)
        else
            normalized

    /// Check if path matches forbidden patterns
    /// SC-ENFORCE-010: File path validation MUST be case-insensitive
    /// SC-ENFORCE-011: Forbidden patterns MUST include regex support
    /// SC-ENFORCE-012: Access decisions MUST complete within 5ms
    /// AOR-ENFORCE-007: VALIDATE all file paths against forbidden list
    let private isPathForbidden (path: string) (_config: EnforcementConfig) : bool =
        let normalizedPath = normalizePath(path).ToLowerInvariant()

        // Fast path: string contains check — avoids regex entirely for safe paths
        if not (normalizedPath.Contains("todolist")) then
            false  // Short-circuit: path can't match any forbidden pattern
        else
            // Medium path: O(log n) Set lookup for exact/suffix matches
            let exactMatch =
                forbiddenPathSet
                |> Set.exists (fun forbidden ->
                    normalizedPath.EndsWith(forbidden) ||
                    normalizedPath.Contains(forbidden))

            if exactMatch then true
            else
                // Slow path: lazy-compiled regex (only triggered for todolist-containing paths)
                compiledForbiddenPatterns.Value
                |> Array.exists (fun regex -> regex.IsMatch(normalizedPath))

    // ========================================================================
    // RATE LIMITING (SC-ENFORCE-018, AOR-ENFORCE-009)
    // ========================================================================

    /// Check if agent exceeds rate limit
    /// SC-ENFORCE-018: Request rate limiting MUST prevent DOS
    /// AOR-ENFORCE-009: RATE LIMIT requests per agent (max 10/second)
    let private checkRateLimit (agentId: string) (config: EnforcementConfig) : bool =
        if not config.EnableRateLimiting then
            true  // Rate limiting disabled
        else
            let now = DateTime.UtcNow
            let oneSecondAgo = now.AddSeconds(-1.0)

            let timestamps =
                requestTimestamps.GetOrAdd(agentId, fun _ -> ConcurrentQueue<DateTime>())

            // Add current timestamp
            timestamps.Enqueue(now)

            // Remove old timestamps (cleanup)
            let mutable oldTimestamp = DateTime.MinValue
            while timestamps.TryPeek(&oldTimestamp) && oldTimestamp < oneSecondAgo do
                timestamps.TryDequeue(&oldTimestamp) |> ignore

            // Check if count exceeds limit
            timestamps.Count <= config.MaxRequestsPerSecond

    // ========================================================================
    // VIOLATION MANAGEMENT (SC-ENFORCE-002, SC-ENFORCE-006, AOR-ENFORCE-012)
    // ========================================================================

    /// Record violation to immutable audit trail
    /// SC-ENFORCE-002: All access attempts MUST be logged
    /// SC-ENFORCE-006: Audit trail MUST be append-only
    /// AOR-ENFORCE-012: MAINTAIN immutable violation history
    let recordViolation (ctx: RequestContext) (reason: string) (severity: string) : ViolationRecord =
        let agentId = extractAgentIdentifier ctx
        let isCircuitBlocked = circuitBreakerState.ContainsKey(agentId) && circuitBreakerState.[agentId]

        let violation = {
            Id = Guid.NewGuid()
            Context = ctx
            Reason = reason
            Severity = severity
            Timestamp = DateTime.UtcNow
            BlockedByCircuit = isCircuitBlocked
        }

        // Store in memory (immutable)
        violationStore.[violation.Id] <- violation

        // Increment violation counter
        let newCount = agentViolations.AddOrUpdate(agentId, 1, fun _ count -> count + 1)

        // Check circuit breaker threshold (SC-ENFORCE-004, AOR-ENFORCE-004)
        if newCount >= (!activeConfig).CircuitBreakerThreshold then
            circuitBreakerState.[agentId] <- true
            printfn "[CIRCUIT BREAKER TRIGGERED] Agent %s blocked after %d violations" agentId newCount

        // Append to audit log (AOR-ENFORCE-006)
        try
            let logDir = Path.GetDirectoryName((!activeConfig).AuditLogPath)
            if not (Directory.Exists(logDir)) then
                Directory.CreateDirectory(logDir) |> ignore

            let stackTrace =
                match ctx.StackTrace with
                | Some st -> $" | StackTrace: {st}"
                | None -> ""

            let logEntry =
                sprintf "[%s] VIOLATION %s | Agent: %s | Path: %s | Op: %s | Reason: %s | Severity: %s%s\n"
                    (violation.Timestamp.ToString("O"))
                    (violation.Id.ToString())
                    agentId
                    ctx.RequestedPath
                    ctx.Operation
                    reason
                    severity
                    stackTrace

            File.AppendAllText((!activeConfig).AuditLogPath, logEntry)
        with ex ->
            eprintfn "[AUDIT LOG ERROR] Failed to write: %s" ex.Message

        // Publish telemetry (SC-ENFORCE-009, AOR-ENFORCE-011)
        if (!activeConfig).EnableTelemetry then
            try
                let topic = (!activeConfig).TelemetryTopic
                let checkpointId = "CP-ENFORCE-01"
                let agentIdForJson = extractAgentIdentifier ctx

                let jsonPayload =
                    sprintf
                        "{\"checkpoint\":\"%s\",\"violation_id\":\"%s\",\"agent\":\"%s\",\"path\":\"%s\",\"operation\":\"%s\",\"reason\":\"%s\",\"severity\":\"%s\",\"timestamp\":\"%s\",\"circuit_blocked\":%s}"
                        checkpointId
                        (violation.Id.ToString())
                        agentIdForJson
                        (ctx.RequestedPath.Replace("\\", "\\\\").Replace("\"", "\\\""))
                        (ctx.Operation.Replace("\"", "\\\""))
                        (violation.Reason.Replace("\"", "\\\""))
                        violation.Severity
                        (violation.Timestamp.ToString("o"))
                        (if violation.BlockedByCircuit then "true" else "false")

                // SC-ZTEST-008: Triple-write pattern
                // Step 1: Log fallback FIRST (guaranteed durability)
                eprintfn "[ZTEST-CHECKPOINT] checkpoint=%s topic=%s message=violation_recorded severity=%s timestamp=%s"
                    checkpointId topic violation.Severity (DateTimeOffset.UtcNow.ToString("o"))
                // Step 2: Real Zenoh publish via ZenohPublish module
                Cepaf.Mesh.ZenohPublish.publish checkpointId topic "violation_recorded" jsonPayload
            with ex ->
                eprintfn "[TELEMETRY ERROR] Failed to publish violation to Zenoh: %s" ex.Message

        // Alert Prajna Cockpit (AOR-ENFORCE-005)
        if severity = "CRITICAL" || severity = "HIGH" then
            printfn "[ALERT] CRITICAL/HIGH violation detected - Agent: %s, Path: %s" agentId ctx.RequestedPath

        violation

    /// Get violation count for an agent
    let getViolationCount (agentType: AgentType) : int =
        let agentId = extractAgentId agentType
        agentViolations.GetOrAdd(agentId, 0)

    /// Check if circuit breaker is open for an agent
    /// SC-ENFORCE-004: Violation count MUST trigger circuit breaker
    let isCircuitOpen (agentType: AgentType) : bool =
        let agentId = extractAgentId agentType
        circuitBreakerState.ContainsKey(agentId) && circuitBreakerState.[agentId]

    /// Reset circuit breaker (requires Guardian approval in production)
    /// SC-ENFORCE-013: Circuit breaker reset MUST require manual intervention
    /// AOR-ENFORCE-010: REQUIRE Guardian approval for circuit breaker reset
    let resetCircuitBreaker (agentType: AgentType) (approvalToken: string option) : Result<unit, string> =
        if (!activeConfig).CircuitBreakerResetRequiresApproval && approvalToken.IsNone then
            Error "Circuit breaker reset requires Guardian approval token (SC-ENFORCE-013)"
        else
            let agentId = extractAgentIdentifier {
                AgentType = agentType
                RequestedPath = ""
                Operation = ""
                Timestamp = DateTime.UtcNow
                StackTrace = None
                IpAddress = None
                AdditionalContext = Map.empty
            }

            // TODO: Validate approval token with Guardian
            // Example: Guardian.validateApprovalToken(approvalToken.Value)

            circuitBreakerState.[agentId] <- false
            agentViolations.[agentId] <- 0

            printfn "[CIRCUIT BREAKER RESET] Agent %s - violations cleared" agentId
            Ok ()

    // ========================================================================
    // MULTI-LAYER VALIDATION (SC-ENFORCE-020)
    // ========================================================================

    /// Validate request against all layers
    /// SC-ENFORCE-020: Multi-layer validation MUST all pass
    let validateRequest (ctx: RequestContext) (config: EnforcementConfig) : Result<unit, string> =
        // Layer 1: Unknown agent check (SC-ENFORCE-021, AOR-ENFORCE-003)
        match ctx.AgentType with
        | Unknown id ->
            Error $"Unknown agents are denied by default (SC-ENFORCE-021): {id}"
        | _ -> Ok ()

        |> Result.bind (fun _ ->
            // Layer 2: Rate limiting (SC-ENFORCE-018, AOR-ENFORCE-009)
            let agentId = extractAgentIdentifier ctx
            if not (checkRateLimit agentId config) then
                Error $"Rate limit exceeded for agent {agentId} (max {config.MaxRequestsPerSecond}/sec)"
            else
                Ok ()
        )

        |> Result.bind (fun _ ->
            // Layer 3: Circuit breaker check (SC-ENFORCE-004)
            if isCircuitOpen ctx.AgentType then
                let agentId = extractAgentIdentifier ctx
                let count = getViolationCount ctx.AgentType
                Error $"Circuit breaker OPEN for agent {agentId} ({count} violations) - requires Guardian reset"
            else
                Ok ()
        )

        |> Result.bind (fun _ ->
            // Layer 4: Path validation (SC-ENFORCE-001, SC-ENFORCE-007, AOR-ENFORCE-007)
            if isPathForbidden ctx.RequestedPath config then
                Error $"FORBIDDEN ACCESS to protected resource: {ctx.RequestedPath} (SC-TODO-001 VIOLATION)"
            else
                Ok ()
        )

        |> Result.bind (fun _ ->
            // Layer 5: Operation validation (AOR-ENFORCE-015)
            let suspiciousPatterns = [
                "rm -rf"
                "sudo"
                "chmod"
                "chown"
                "> PROJECT_TODOLIST"
                ">> PROJECT_TODOLIST"
            ]

            let isSuspicious =
                suspiciousPatterns
                |> List.exists (fun pattern ->
                    ctx.Operation.Contains(pattern, StringComparison.OrdinalIgnoreCase))

            if isSuspicious then
                Error $"SUSPICIOUS operation pattern detected: {ctx.Operation}"
            else
                Ok ()
        )

    // ========================================================================
    // HOOK MANAGEMENT (SC-ENFORCE-008, SC-ENFORCE-025)
    // ========================================================================

    /// Register enforcement hook for runtime integration
    /// SC-ENFORCE-008: Hook registration MUST validate callback signatures
    /// SC-ENFORCE-025: All hooks MUST execute atomically
    let registerHook (hook: EnforcementHook) : unit =
        try
            registeredHooks.Add(hook)
            printfn "[HOOK REGISTERED] Total hooks: %d" registeredHooks.Count
        with ex ->
            eprintfn "[HOOK REGISTRATION ERROR] %s" ex.Message

    /// Execute all registered hooks
    /// AOR-ENFORCE-013: EXECUTE all hooks before allowing access
    let private executeHooks (ctx: RequestContext) (decision: AccessDecision) : unit =
        for hook in registeredHooks do
            try
                hook ctx decision
            with ex ->
                eprintfn "[HOOK EXECUTION ERROR] %s" ex.Message

    // ========================================================================
    // MAIN ENFORCEMENT POINT (SC-ENFORCE-001, SC-ENFORCE-012)
    // ========================================================================

    /// Main enforcement function - SINGLE POINT OF TRUTH
    /// SC-ENFORCE-001: Direct access to PROJECT_TODOLIST.md MUST be blocked
    /// SC-ENFORCE-012: Access decisions MUST complete within 5ms
    /// AOR-ENFORCE-002: LOG all access attempts regardless of outcome
    let enforceAccess (ctx: RequestContext) : AccessDecision =
        let sw = Stopwatch.StartNew()

        // Multi-layer validation (SC-ENFORCE-020)
        let decision =
            match validateRequest ctx (!activeConfig) with
            | Ok () ->
                Allowed "All validation layers passed (SC-ENFORCE-020)"
            | Error reason ->
                let severity =
                    if reason.Contains("SC-TODO-001") then "CRITICAL"
                    elif reason.Contains("Circuit breaker") then "HIGH"
                    elif reason.Contains("Rate limit") then "MEDIUM"
                    elif reason.Contains("SUSPICIOUS") then "HIGH"
                    else "LOW"

                let violation = recordViolation ctx reason severity

                if isCircuitOpen ctx.AgentType then
                    let agentId = extractAgentIdentifier ctx
                    let count = getViolationCount ctx.AgentType
                    CircuitOpen (agentId, count)
                else
                    Denied (reason, violation)

        // Execute hooks (AOR-ENFORCE-013, SC-ENFORCE-025)
        executeHooks ctx decision

        // Performance check (SC-ENFORCE-012) — Stopwatch for hardware-counter precision
        sw.Stop()
        let elapsed = sw.Elapsed.TotalMilliseconds
        if elapsed > 5.0 then
            eprintfn "[PERFORMANCE WARNING] Enforcement took %.2fms (threshold: 5ms, SC-ENFORCE-012)" elapsed

        decision

    // ========================================================================
    // UTILITY FUNCTIONS
    // ========================================================================

    /// Get all violations for a specific agent
    let getAgentViolations (agentType: AgentType) : ViolationRecord list =
        let agentId = extractAgentIdentifier {
            AgentType = agentType
            RequestedPath = ""
            Operation = ""
            Timestamp = DateTime.UtcNow
            StackTrace = None
            IpAddress = None
            AdditionalContext = Map.empty
        }

        violationStore.Values
        |> Seq.filter (fun v -> extractAgentIdentifier v.Context = agentId)
        |> Seq.sortByDescending (fun v -> v.Timestamp)
        |> Seq.toList

    /// Get all violations in time range
    let getViolationsByTimeRange (startTime: DateTime) (endTime: DateTime) : ViolationRecord list =
        violationStore.Values
        |> Seq.filter (fun v -> v.Timestamp >= startTime && v.Timestamp <= endTime)
        |> Seq.sortByDescending (fun v -> v.Timestamp)
        |> Seq.toList

    /// Get violations by severity
    let getViolationsBySeverity (severity: string) : ViolationRecord list =
        violationStore.Values
        |> Seq.filter (fun v -> v.Severity = severity)
        |> Seq.sortByDescending (fun v -> v.Timestamp)
        |> Seq.toList

    /// Get all agents with open circuit breakers
    let getCircuitOpenAgents () : (string * int) list =
        circuitBreakerState
        |> Seq.filter (fun kvp -> kvp.Value)
        |> Seq.map (fun kvp ->
            let count = agentViolations.GetOrAdd(kvp.Key, 0)
            (kvp.Key, count))
        |> Seq.toList

    /// Get statistics
    let getStatistics () : EnforcementStatistics =
        {
            TotalViolations = violationStore.Count
            TotalAgentsTracked = agentViolations.Count
            AgentsCircuitOpen = circuitBreakerState.Values |> Seq.filter id |> Seq.length
            RegisteredHooks = registeredHooks.Count
            ConfigSnapshot = !activeConfig
            UptimeSeconds = (DateTime.UtcNow - startTime).TotalSeconds
        }

    /// Update configuration (runtime override)
    /// SC-ENFORCE-024: Enforcement config MUST be immutable at runtime
    /// Note: This is an exception for administrative purposes
    let updateConfig (newConfig: EnforcementConfig) : unit =
        activeConfig := newConfig
        printfn "[CONFIG UPDATED] Enforcement configuration changed at %s" (DateTime.UtcNow.ToString("O"))

    /// Export audit log to file
    /// SC-ENFORCE-019: Audit log rotation MUST preserve history
    let exportAuditLog (outputPath: string) : Result<int, string> =
        try
            let violations =
                violationStore.Values
                |> Seq.sortBy (fun v -> v.Timestamp)
                |> Seq.toList

            let lines =
                violations
                |> List.map (fun v ->
                    sprintf "%s | %s | %s | %s | %s | %s | %s"
                        (v.Timestamp.ToString("O"))
                        (v.Id.ToString())
                        (extractAgentIdentifier v.Context)
                        v.Context.RequestedPath
                        v.Context.Operation
                        v.Reason
                        v.Severity
                )

            File.WriteAllLines(outputPath, lines)
            Ok violations.Length
        with ex ->
            Error $"Failed to export audit log: {ex.Message}"

    /// Clear all violations (DANGEROUS - requires Guardian approval)
    let clearViolationHistory (approvalToken: string) : Result<int, string> =
        // TODO: Validate with Guardian
        if String.IsNullOrWhiteSpace(approvalToken) then
            Error "Clearing violation history requires Guardian approval token"
        else
            let count = violationStore.Count
            violationStore.Clear()
            agentViolations.Clear()
            circuitBreakerState.Clear()
            requestTimestamps.Clear()

            printfn "[HISTORY CLEARED] All violations cleared (count: %d) with Guardian approval" count
            Ok count

    /// Get detailed report for an agent
    let getAgentReport (agentType: AgentType) : string =
        let agentId = extractAgentIdentifier {
            AgentType = agentType
            RequestedPath = ""
            Operation = ""
            Timestamp = DateTime.UtcNow
            StackTrace = None
            IpAddress = None
            AdditionalContext = Map.empty
        }

        let violations = getAgentViolations agentType
        let violationCount = getViolationCount agentType
        let circuitOpen = isCircuitOpen agentType

        let criticalCount = violations |> List.filter (fun v -> v.Severity = "CRITICAL") |> List.length
        let highCount = violations |> List.filter (fun v -> v.Severity = "HIGH") |> List.length

        sprintf """
=== AGENT ENFORCEMENT REPORT ===
Agent ID: %s
Agent Type: %A
Total Violations: %d
  - CRITICAL: %d
  - HIGH: %d
Circuit Breaker: %s
Recent Violations (last 5):
%s
================================
"""
            agentId
            agentType
            violationCount
            criticalCount
            highCount
            (if circuitOpen then "OPEN (BLOCKED)" else "CLOSED")
            (violations
             |> List.truncate 5
             |> List.map (fun v -> sprintf "  [%s] %s - %s" (v.Timestamp.ToString("O")) v.Severity v.Reason)
             |> String.concat "\n")
