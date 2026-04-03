namespace Cepaf.Cockpit

open System
open System.Net.Http
open System.Text
open System.Text.Json
open System.Threading
open Cepaf.Rop

/// ===============================================================================
/// CEPAF-PRAJNA ELIXIR BRIDGE (HTTP Transport Layer)
/// ===============================================================================
///
/// WHAT: HTTP transport layer connecting F# CEPAF Cockpit to Elixir Phoenix backend.
///       Provides type-safe async communication for all Prajna API operations.
///
/// WHY: Enables bidirectional sync between F# TUI and Elixir backend with proper
///      error handling, circuit breaker, and retry logic per SC-SYNC constraints.
///
/// STAMP Compliance:
///   - SC-SYNC-001: Bridge timeout < 5s
///   - SC-SYNC-002: Retry with exponential backoff
///   - SC-SYNC-003: Circuit breaker after 3 failures
///   - SC-SYNC-004: Health sync interval = 30s
///   - SC-SYNC-005: All commands through Guardian
///   - SC-SYNC-006: All state via Immutable Register
///   - SC-SYNC-007: Proof token required for mutations
///   - SC-SYNC-008: Constitutional check before reconfig
///   - SC-SYNC-009: Zenoh for real-time telemetry
///   - SC-SYNC-010: DuckDB for shared history
///
/// AOR Compliance:
///   - AOR-SYNC-001: Backend Verify - Verify Elixir backend reachable before any operation
///   - AOR-SYNC-002: Log All Sync - Log all sync operations to Immutable Register
///   - AOR-SYNC-005: Proof Token - Request proof token for all mutations
///   - AOR-SYNC-006: Guardian Approve - Use Guardian for all command approval
///
/// ===============================================================================
module ElixirBridge =

    // ═══════════════════════════════════════════════════════════════════════════
    // CONFIGURATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Bridge configuration (SC-SYNC-001, SC-SYNC-002, SC-SYNC-003)
    [<Struct>]
    type BridgeConfig = {
        /// Base URL for Elixir Phoenix API
        BaseUrl: string
        /// Request timeout (SC-SYNC-001: < 5s)
        Timeout: TimeSpan
        /// Maximum retry attempts (SC-SYNC-002)
        MaxRetries: int
        /// Base delay for exponential backoff
        RetryBaseDelay: TimeSpan
        /// Circuit breaker failure threshold (SC-SYNC-003)
        CircuitBreakerThreshold: int
        /// Circuit breaker reset timeout
        CircuitBreakerResetTimeout: TimeSpan
        /// API authentication token
        AuthToken: string option
    }

    /// Default configuration with STAMP-compliant values
    let defaultConfig = {
        BaseUrl = "http://localhost:4000/api/v1/prajna"
        Timeout = TimeSpan.FromSeconds(5.0)  // SC-SYNC-001
        MaxRetries = 3
        RetryBaseDelay = TimeSpan.FromMilliseconds(500.0)
        CircuitBreakerThreshold = 3  // SC-SYNC-003
        CircuitBreakerResetTimeout = TimeSpan.FromSeconds(30.0)
        AuthToken = None
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TYPES
    // ═══════════════════════════════════════════════════════════════════════════

    /// Circuit breaker state (SC-SYNC-003)
    type CircuitState =
        | Closed
        | Open of openedAt: DateTime
        | HalfOpen

    /// Bridge state for tracking connection health
    type BridgeState = {
        Config: BridgeConfig
        CircuitState: CircuitState
        ConsecutiveFailures: int
        LastSuccessAt: DateTime option
        LastFailureAt: DateTime option
        TotalRequests: int64
        TotalFailures: int64
    }

    /// Guardian proposal result (SC-PRAJNA-001)
    type GuardianResult =
        | Approved of proposalId: string
        | Vetoed of reason: string * fallbackAction: string option
        | Pending of proposalId: string

    /// Sentinel health response (SC-PRAJNA-004)
    type SentinelHealth = {
        HealthScore: float
        Status: string
        ActiveThreats: string list
        LastCheck: DateTime
        SystemLoad: float
        MemoryUsage: float
        CpuUsage: float
    }

    /// Founder directive validation result (SC-PRAJNA-002)
    type FounderValidation = {
        IsValid: bool
        AlignmentScore: float
        Goal1Alignment: float  // Symbiotic Survival
        Goal2Alignment: float  // Sentience Pursuit
        Goal3Alignment: float  // Power Accumulation
        Violations: string list
        Warnings: string list
    }

    /// Proof token for mutations (SC-SYNC-007)
    type ProofToken = {
        Token: string
        ExpiresAt: DateTime
        Scope: string list
        IssuedAt: DateTime
    }

    /// Register entry response (SC-SYNC-006)
    type RegisterEntry = {
        BlockNumber: int64
        Hash: string
        PreviousHash: string
        Signature: string
        Timestamp: DateTime
        Operation: string
    }

    /// API response wrapper
    type ApiResponse<'T> = {
        Success: bool
        Data: 'T option
        Error: string option
        RequestId: string
        Timestamp: DateTime
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HTTP CLIENT
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create HTTP client with configuration
    let private createClient (config: BridgeConfig) =
        let handler = new HttpClientHandler()
        let client = new HttpClient(handler)
        client.Timeout <- config.Timeout
        client.DefaultRequestHeaders.Add("Accept", "application/json")
        client.DefaultRequestHeaders.Add("X-Client", "CEPAF-Cockpit")
        client.DefaultRequestHeaders.Add("X-STAMP-Version", "SC-SYNC-001")
        match config.AuthToken with
        | Some token -> client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}")
        | None -> ()
        client

    /// Serialize payload to JSON
    let private toJson (obj: obj) =
        JsonSerializer.Serialize(obj, JsonSerializerOptions(PropertyNamingPolicy = JsonNamingPolicy.CamelCase))

    /// Deserialize JSON response
    let private fromJson<'T> (json: string) =
        try
            Some (JsonSerializer.Deserialize<'T>(json, JsonSerializerOptions(PropertyNamingPolicy = JsonNamingPolicy.CamelCase)))
        with _ -> None

    // ═══════════════════════════════════════════════════════════════════════════
    // CIRCUIT BREAKER (SC-SYNC-003)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Check if circuit allows requests
    let private isCircuitAllowed (state: BridgeState) =
        match state.CircuitState with
        | Closed -> true
        | HalfOpen -> true
        | Open openedAt ->
            let elapsed = DateTime.UtcNow - openedAt
            elapsed > state.Config.CircuitBreakerResetTimeout

    /// Update circuit state after request
    let private updateCircuit (state: BridgeState) (success: bool) =
        if success then
            { state with
                CircuitState = Closed
                ConsecutiveFailures = 0
                LastSuccessAt = Some DateTime.UtcNow
                TotalRequests = state.TotalRequests + 1L }
        else
            let failures = state.ConsecutiveFailures + 1
            let newCircuit =
                if failures >= state.Config.CircuitBreakerThreshold then
                    Open DateTime.UtcNow
                else
                    state.CircuitState
            { state with
                CircuitState = newCircuit
                ConsecutiveFailures = failures
                LastFailureAt = Some DateTime.UtcNow
                TotalRequests = state.TotalRequests + 1L
                TotalFailures = state.TotalFailures + 1L }

    // ═══════════════════════════════════════════════════════════════════════════
    // RETRY WITH EXPONENTIAL BACKOFF (SC-SYNC-002)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Execute with retry logic
    let private withRetry (config: BridgeConfig) (operation: unit -> Async<Result<'T, string>>) : Async<Result<'T, string>> =
        let rec loop attempt =
            async {
                match! operation() with
                | Ok result -> return Ok result
                | Error msg when attempt < config.MaxRetries ->
                    let delay = config.RetryBaseDelay.TotalMilliseconds * (pown 2.0 attempt)
                    do! Async.Sleep (int delay)
                    return! loop (attempt + 1)
                | Error msg -> return Error msg
            }
        loop 0

    // ═══════════════════════════════════════════════════════════════════════════
    // CORE HTTP OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Make GET request
    let private getAsync<'T> (client: HttpClient) (url: string) : Async<Result<'T, string>> =
        async {
            try
                let! response = client.GetAsync(url) |> Async.AwaitTask
                let! content = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                if response.IsSuccessStatusCode then
                    match fromJson<'T> content with
                    | Some data -> return Ok data
                    | None -> return Error "Failed to parse response"
                else
                    return Error $"HTTP {int response.StatusCode}: {content}"
            with ex ->
                return Error $"Request failed: {ex.Message}"
        }

    /// Make POST request
    let private postAsync<'TReq, 'TRes> (client: HttpClient) (url: string) (body: 'TReq) : Async<Result<'TRes, string>> =
        async {
            try
                let json = toJson body
                let content = new StringContent(json, Encoding.UTF8, "application/json")
                let! response = client.PostAsync(url, content) |> Async.AwaitTask
                let! responseContent = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                if response.IsSuccessStatusCode then
                    match fromJson<'TRes> responseContent with
                    | Some data -> return Ok data
                    | None -> return Error "Failed to parse response"
                else
                    return Error $"HTTP {int response.StatusCode}: {responseContent}"
            with ex ->
                return Error $"Request failed: {ex.Message}"
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // BRIDGE STATE MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create initial bridge state
    let createBridge (config: BridgeConfig) : BridgeState = {
        Config = config
        CircuitState = Closed
        ConsecutiveFailures = 0
        LastSuccessAt = None
        LastFailureAt = None
        TotalRequests = 0L
        TotalFailures = 0L
    }

    /// Check backend health (AOR-SYNC-001)
    let checkHealth (state: BridgeState) : Async<Result<BridgeState * SentinelHealth, string>> =
        async {
            if not (isCircuitAllowed state) then
                return Error "Circuit breaker is open"
            else
                use client = createClient state.Config
                let url = $"{state.Config.BaseUrl}/sentinel/health"
                let! result = withRetry state.Config (fun () -> getAsync<SentinelHealth> client url)
                match result with
                | Ok health ->
                    let newState = updateCircuit state true
                    return Ok (newState, health)
                | Error msg ->
                    let newState = updateCircuit state false
                    return Error msg
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // GUARDIAN INTEGRATION (SC-PRAJNA-001, SC-SYNC-005, AOR-SYNC-006)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Submit command proposal to Guardian
    type GuardianProposal = {
        CommandType: string
        TargetModule: string
        Payload: Map<string, obj>
        Justification: string
        Urgency: string
    }

    /// Submit proposal to Guardian (SC-PRAJNA-001)
    let submitGuardianProposal (state: BridgeState) (proposal: GuardianProposal) : Async<Result<BridgeState * GuardianResult, string>> =
        async {
            if not (isCircuitAllowed state) then
                return Error "Circuit breaker is open"
            else
                use client = createClient state.Config
                let url = $"{state.Config.BaseUrl}/guardian/submit"
                let! result = withRetry state.Config (fun () -> postAsync<GuardianProposal, ApiResponse<GuardianResult>> client url proposal)
                match result with
                | Ok response when response.Success && response.Data.IsSome ->
                    let newState = updateCircuit state true
                    return Ok (newState, response.Data.Value)
                | Ok response ->
                    let newState = updateCircuit state false
                    return Error (response.Error |> Option.defaultValue "Unknown error")
                | Error msg ->
                    let newState = updateCircuit state false
                    return Error msg
        }

    /// Execute with Guardian approval wrapper
    let executeWithGuardian
        (state: BridgeState)
        (commandType: string)
        (target: string)
        (payload: Map<string, obj>)
        (justification: string)
        (onApproved: unit -> Async<Result<'T, string>>)
        (onVetoed: string -> Result<'T, string>) : Async<Result<BridgeState * 'T, string>> =
        async {
            let proposal = {
                CommandType = commandType
                TargetModule = target
                Payload = payload
                Justification = justification
                Urgency = "normal"
            }
            match! submitGuardianProposal state proposal with
            | Ok (newState, Approved _) ->
                match! onApproved() with
                | Ok result -> return Ok (newState, result)
                | Error msg -> return Error msg
            | Ok (newState, Vetoed (reason, _)) ->
                match onVetoed reason with
                | Ok result -> return Ok (newState, result)
                | Error msg -> return Error msg
            | Ok (newState, Pending proposalId) ->
                return Error $"Proposal {proposalId} is pending approval"
            | Error msg -> return Error msg
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // FOUNDER DIRECTIVE VALIDATION (SC-PRAJNA-002, AOR-SYNC-003)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Recommendation to validate against Founder's Directive
    type FounderRecommendation = {
        Action: string
        ResourceImpact: float
        FounderBenefit: string
        Description: string
    }

    /// Validate against Founder's Directive (SC-PRAJNA-002)
    let validateFounderDirective (state: BridgeState) (recommendation: FounderRecommendation) : Async<Result<BridgeState * FounderValidation, string>> =
        async {
            if not (isCircuitAllowed state) then
                return Error "Circuit breaker is open"
            else
                use client = createClient state.Config
                let url = $"{state.Config.BaseUrl}/founder/validate"
                let! result = withRetry state.Config (fun () -> postAsync<FounderRecommendation, ApiResponse<FounderValidation>> client url recommendation)
                match result with
                | Ok response when response.Success && response.Data.IsSome ->
                    let newState = updateCircuit state true
                    return Ok (newState, response.Data.Value)
                | Ok response ->
                    let newState = updateCircuit state false
                    return Error (response.Error |> Option.defaultValue "Validation failed")
                | Error msg ->
                    let newState = updateCircuit state false
                    return Error msg
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // IMMUTABLE REGISTER (SC-PRAJNA-003, SC-SYNC-006, AOR-SYNC-002)
    // ═══════════════════════════════════════════════════════════════════════════

    /// State change to record
    type StateChange = {
        Module: string
        Operation: string
        OldValue: string option
        NewValue: string
        Reason: string
    }

    /// Record state change to immutable register (SC-PRAJNA-003)
    let recordStateChange (state: BridgeState) (change: StateChange) : Async<Result<BridgeState * RegisterEntry, string>> =
        async {
            if not (isCircuitAllowed state) then
                return Error "Circuit breaker is open"
            else
                use client = createClient state.Config
                let url = $"{state.Config.BaseUrl}/register/record"
                let! result = withRetry state.Config (fun () -> postAsync<StateChange, ApiResponse<RegisterEntry>> client url change)
                match result with
                | Ok response when response.Success && response.Data.IsSome ->
                    let newState = updateCircuit state true
                    return Ok (newState, response.Data.Value)
                | Ok response ->
                    let newState = updateCircuit state false
                    return Error (response.Error |> Option.defaultValue "Failed to record state")
                | Error msg ->
                    let newState = updateCircuit state false
                    return Error msg
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // PROOF TOKEN (SC-SYNC-007, AOR-SYNC-005)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Proof token request
    type ProofTokenRequest = {
        Scope: string list
        Reason: string
        ExpirationMinutes: int
    }

    /// Request PROMETHEUS proof token (SC-SYNC-007)
    let requestProofToken (state: BridgeState) (request: ProofTokenRequest) : Async<Result<BridgeState * ProofToken, string>> =
        async {
            if not (isCircuitAllowed state) then
                return Error "Circuit breaker is open"
            else
                use client = createClient state.Config
                let url = $"{state.Config.BaseUrl}/prometheus/token"
                let! result = withRetry state.Config (fun () -> postAsync<ProofTokenRequest, ApiResponse<ProofToken>> client url request)
                match result with
                | Ok response when response.Success && response.Data.IsSome ->
                    let newState = updateCircuit state true
                    return Ok (newState, response.Data.Value)
                | Ok response ->
                    let newState = updateCircuit state false
                    return Error (response.Error |> Option.defaultValue "Failed to get proof token")
                | Error msg ->
                    let newState = updateCircuit state false
                    return Error msg
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTITUTIONAL CHECK (SC-SYNC-008)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Constitutional invariant check result
    type ConstitutionalCheck = {
        Psi0Existence: bool         // Existence preservation
        Psi1Regeneration: bool      // Regenerative completeness
        Psi2Evolution: bool         // Evolutionary continuity
        Psi3Verification: bool      // Verification capability
        Psi4HumanAlignment: bool    // Human alignment
        Psi5Truthfulness: bool      // Truthfulness
        AllPassed: bool
        Violations: string list
    }

    /// Reconfiguration request
    type ReconfigRequest = {
        TargetLayer: string         // L1-L7
        ChangeDescription: string
        SurvivalPressure: string option
        ExpectedBenefits: string list
    }

    /// Check constitutional invariants before reconfiguration (SC-SYNC-008)
    let checkConstitutional (state: BridgeState) (request: ReconfigRequest) : Async<Result<BridgeState * ConstitutionalCheck, string>> =
        async {
            if not (isCircuitAllowed state) then
                return Error "Circuit breaker is open"
            else
                use client = createClient state.Config
                let url = $"{state.Config.BaseUrl}/constitutional/check"
                let! result = withRetry state.Config (fun () -> postAsync<ReconfigRequest, ApiResponse<ConstitutionalCheck>> client url request)
                match result with
                | Ok response when response.Success && response.Data.IsSome ->
                    let newState = updateCircuit state true
                    return Ok (newState, response.Data.Value)
                | Ok response ->
                    let newState = updateCircuit state false
                    return Error (response.Error |> Option.defaultValue "Constitutional check failed")
                | Error msg ->
                    let newState = updateCircuit state false
                    return Error msg
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // ZENOH INTEGRATION (SC-SYNC-009, AOR-SYNC-008)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Zenoh subscription request
    type ZenohSubscription = {
        Topic: string
        CallbackUrl: string option
    }

    /// Subscribe to Zenoh telemetry topic (SC-SYNC-009)
    let subscribeZenoh (state: BridgeState) (subscription: ZenohSubscription) : Async<Result<BridgeState * string, string>> =
        async {
            if not (isCircuitAllowed state) then
                return Error "Circuit breaker is open"
            else
                use client = createClient state.Config
                let url = $"{state.Config.BaseUrl}/zenoh/subscribe"
                let! result = withRetry state.Config (fun () -> postAsync<ZenohSubscription, ApiResponse<{| SubscriptionId: string |}>> client url subscription)
                match result with
                | Ok response when response.Success && response.Data.IsSome ->
                    let newState = updateCircuit state true
                    return Ok (newState, response.Data.Value.SubscriptionId)
                | Ok response ->
                    let newState = updateCircuit state false
                    return Error (response.Error |> Option.defaultValue "Subscription failed")
                | Error msg ->
                    let newState = updateCircuit state false
                    return Error msg
        }

    /// Publish telemetry to Zenoh (AOR-SYNC-008)
    type ZenohMessage = {
        Topic: string
        Payload: Map<string, obj>
    }

    let publishZenoh (state: BridgeState) (message: ZenohMessage) : Async<Result<BridgeState, string>> =
        async {
            if not (isCircuitAllowed state) then
                return Error "Circuit breaker is open"
            else
                use client = createClient state.Config
                let url = $"{state.Config.BaseUrl}/zenoh/publish"
                let! result = withRetry state.Config (fun () -> postAsync<ZenohMessage, ApiResponse<unit>> client url message)
                match result with
                | Ok response when response.Success ->
                    return Ok (updateCircuit state true)
                | Ok response ->
                    return Error (response.Error |> Option.defaultValue "Publish failed")
                | Error msg ->
                    return Error msg
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // BRIDGE STATISTICS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get bridge statistics for dashboard display
    let getStatistics (state: BridgeState) : Map<string, obj> =
        let circuitStatus =
            match state.CircuitState with
            | Closed -> "CLOSED"
            | Open _ -> "OPEN"
            | HalfOpen -> "HALF_OPEN"
        Map.ofList [
            "total_requests", box state.TotalRequests
            "total_failures", box state.TotalFailures
            "consecutive_failures", box state.ConsecutiveFailures
            "circuit_state", box circuitStatus
            "last_success", box (state.LastSuccessAt |> Option.map (fun d -> d.ToString("o")))
            "last_failure", box (state.LastFailureAt |> Option.map (fun d -> d.ToString("o")))
            "success_rate", box (if state.TotalRequests > 0L then float (state.TotalRequests - state.TotalFailures) / float state.TotalRequests * 100.0 else 100.0)
        ]
