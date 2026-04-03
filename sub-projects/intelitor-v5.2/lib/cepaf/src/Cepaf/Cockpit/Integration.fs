namespace Cepaf.Cockpit

open System
open Cepaf.Rop

/// ===============================================================================
/// CEPAF-PRAJNA FULL INTEGRATION CONTROLLER
/// ===============================================================================
///
/// WHAT: Unified integration controller that orchestrates all sync operations
///       between F# CEPAF Cockpit and Elixir Prajna backend.
///
/// WHY: Provides a single entry point for all CEPAF ↔ Cockpit ↔ Prajna
///      synchronization with STAMP/AOR compliance.
///
/// STAMP Compliance:
///   - SC-SYNC-001 to SC-SYNC-010: All synchronization constraints
///   - SC-PRAJNA-001 to SC-PRAJNA-007: All Prajna constraints
///   - SC-BIO-001 to SC-BIO-007: Biomorphic execution constraints
///   - SC-FOUNDER-001: ALL actions serve Founder's lineage
///
/// AOR Compliance:
///   - AOR-SYNC-001 to AOR-SYNC-008: All synchronization rules
///   - AOR-PRAJNA-001 to AOR-PRAJNA-005: All Prajna operational rules
///   - AOR-BIO-001 to AOR-BIO-007: Biomorphic agent rules
///
/// ===============================================================================
module Integration =

    // Import ElixirBridge for HTTP transport and core types
    open ElixirBridge
    // Import SentinelBridge for health sync
    open SentinelBridge
    // NOTE: ImmutableState, GuardianIntegration, AiCopilotFounder are NOT opened
    // to avoid type name conflicts. Use fully qualified names instead.

    // ═══════════════════════════════════════════════════════════════════════════
    // INTEGRATION STATE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Full integration state combining all subsystems
    type IntegrationState = {
        /// HTTP bridge state (ElixirBridge)
        Bridge: BridgeState
        /// Sentinel sync state (SentinelBridge)
        SentinelState: SyncState option
        /// Sentinel agent reference
        SentinelAgent: MailboxProcessor<SentinelMsg> option
        /// Immutable register state (local)
        RegisterState: Map<string, obj>
        /// Connection status
        IsConnected: bool
        /// Last successful sync
        LastSyncAt: DateTime option
        /// Total sync operations
        TotalSyncs: int64
        /// Error log (last 10)
        SyncErrors: string list
        /// Configuration
        Config: IntegrationConfig
    }

    /// Integration configuration
    and IntegrationConfig = {
        /// Bridge configuration
        BridgeConfig: BridgeConfig
        /// Sentinel configuration
        SentinelConfig: SentinelConfig
        /// Auto-connect on creation
        AutoConnect: bool
        /// Enable Zenoh subscriptions
        EnableZenoh: bool
        /// Dashboard callback
        OnHealthUpdate: SmartMetrics -> unit
    }

    /// Default integration config
    let defaultIntegrationConfig = {
        BridgeConfig = ElixirBridge.defaultConfig
        SentinelConfig = SentinelBridge.defaultConfig
        AutoConnect = true
        EnableZenoh = true
        OnHealthUpdate = fun _ -> ()
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STATE INITIALIZATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create initial integration state
    let create (config: IntegrationConfig) : IntegrationState = {
        Bridge = createBridge config.BridgeConfig
        SentinelState = None
        SentinelAgent = None
        RegisterState = Map.empty
        IsConnected = false
        LastSyncAt = None
        TotalSyncs = 0L
        SyncErrors = []
        Config = config
    }

    /// Create with default configuration
    let createDefault () = create defaultIntegrationConfig

    // ═══════════════════════════════════════════════════════════════════════════
    // CONNECTION MANAGEMENT (AOR-SYNC-001)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Connect to Elixir backend (AOR-SYNC-001: Verify backend reachable)
    let connect (state: IntegrationState) : Async<Result<IntegrationState, string>> =
        async {
            printfn "[Integration] Connecting to Elixir backend..."

            // Step 1: Verify Elixir backend is reachable
            match! checkHealth state.Bridge with
            | Error msg ->
                printfn "[Integration] Backend unreachable: %s" msg
                return Error $"Backend unreachable: {msg}"

            | Ok (newBridge, health) ->
                printfn "[Integration] Backend connected. Health: %.1f%%" health.HealthScore

                // Step 2: Start Sentinel health sync
                let sentinelAgent =
                    SentinelBridge.startWithConfig
                        state.Config.SentinelConfig
                        state.Config.BridgeConfig
                        state.Config.OnHealthUpdate

                let sentinelState = SentinelBridge.getState sentinelAgent

                // Step 3: Setup Zenoh subscriptions if enabled
                if state.Config.EnableZenoh then
                    let! zenohResult = subscribeZenoh newBridge { Topic = "prajna/**"; CallbackUrl = None }
                    match zenohResult with
                    | Ok _ -> printfn "[Integration] Zenoh subscriptions active"
                    | Error msg -> printfn "[Integration] Zenoh subscription failed: %s" msg

                let newState = {
                    state with
                        Bridge = newBridge
                        SentinelState = Some sentinelState
                        SentinelAgent = Some sentinelAgent
                        IsConnected = true
                        LastSyncAt = Some DateTime.UtcNow
                        TotalSyncs = state.TotalSyncs + 1L
                }

                printfn "[Integration] Connected successfully"
                return Ok newState
        }

    /// Disconnect from backend
    let disconnect (state: IntegrationState) : IntegrationState =
        match state.SentinelAgent with
        | Some agent ->
            SentinelBridge.stop agent
            printfn "[Integration] Disconnected"
        | None -> ()

        { state with
            IsConnected = false
            SentinelAgent = None
            SentinelState = None
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // COMMAND EXECUTION (SC-PRAJNA-001, SC-SYNC-005, AOR-SYNC-006)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Execute command through Guardian with full STAMP compliance
    let executeCommand
        (state: IntegrationState)
        (commandType: string)
        (target: string)
        (payload: Map<string, obj>)
        (justification: string) : Async<Result<IntegrationState * obj, string>> =
        async {
            if not state.IsConnected then
                return Error "Not connected to backend"
            else
                printfn "[Integration] Executing command: %s on %s" commandType target

                // Step 1: Validate against Founder's Directive (SC-PRAJNA-002)
                let recommendation: FounderRecommendation = {
                    Action = commandType
                    ResourceImpact = 1.0
                    FounderBenefit = justification
                    Description = $"{commandType} on {target}"
                }

                match! validateFounderDirective state.Bridge recommendation with
                | Error msg ->
                    return Error $"Founder validation failed: {msg}"

                | Ok (bridge1, validation) when not validation.IsValid ->
                    let violations = String.concat ", " validation.Violations
                    return Error $"Violates Founder's Directive: {violations}"

                | Ok (bridge1, validation) ->
                    printfn "[Integration] Founder validation passed. Alignment: %.2f" validation.AlignmentScore

                    // Step 2: Get PROMETHEUS proof token (SC-SYNC-007)
                    let tokenRequest: ProofTokenRequest = {
                        Scope = [ $"{commandType}:execute" ]
                        Reason = justification
                        ExpirationMinutes = 15
                    }

                    match! requestProofToken bridge1 tokenRequest with
                    | Error msg ->
                        return Error $"Failed to get proof token: {msg}"

                    | Ok (bridge2, token) ->
                        printfn "[Integration] Proof token acquired: %s" (token.Token.Substring(0, 16))

                        // Step 3: Submit to Guardian (SC-PRAJNA-001, SC-SYNC-005)
                        let proposal: GuardianProposal = {
                            CommandType = commandType
                            TargetModule = target
                            Payload = payload
                            Justification = justification
                            Urgency = "normal"
                        }

                        match! submitGuardianProposal bridge2 proposal with
                        | Error msg ->
                            return Error $"Guardian submission failed: {msg}"

                        | Ok (bridge3, Vetoed (reason, _)) ->
                            printfn "[Integration] Command vetoed: %s" reason
                            return Error $"Guardian vetoed: {reason}"

                        | Ok (bridge3, Pending proposalId) ->
                            return Error $"Proposal {proposalId} pending approval"

                        | Ok (bridge3, Approved proposalId) ->
                            printfn "[Integration] Command approved: %s" proposalId

                            // Step 4: Record to immutable register (SC-PRAJNA-003, SC-SYNC-006)
                            let stateChange: StateChange = {
                                Module = target
                                Operation = commandType
                                OldValue = None
                                NewValue = $"Executed with approval {proposalId}"
                                Reason = justification
                            }

                            match! recordStateChange bridge3 stateChange with
                            | Error msg ->
                                printfn "[Integration] Warning: Failed to record state: %s" msg

                            | Ok (bridge4, entry) ->
                                printfn "[Integration] State recorded at block %d" entry.BlockNumber

                            let newState = {
                                state with
                                    Bridge = bridge3
                                    TotalSyncs = state.TotalSyncs + 1L
                                    LastSyncAt = Some DateTime.UtcNow
                            }

                            return Ok (newState, box proposalId)
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTITUTIONAL CHECK (SC-SYNC-008, AOR-SYNC-004)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Check constitutional invariants before reconfiguration
    let checkConstitutionalInvariants
        (state: IntegrationState)
        (targetLayer: string)
        (changeDescription: string)
        (survivalPressure: string option) : Async<Result<IntegrationState * ConstitutionalCheck, string>> =
        async {
            if not state.IsConnected then
                return Error "Not connected to backend"
            else
                let request: ReconfigRequest = {
                    TargetLayer = targetLayer
                    ChangeDescription = changeDescription
                    SurvivalPressure = survivalPressure
                    ExpectedBenefits = []
                }

                match! checkConstitutional state.Bridge request with
                | Ok (newBridge, check) ->
                    if check.AllPassed then
                        printfn "[Integration] Constitutional check PASSED"
                    else
                        printfn "[Integration] Constitutional check FAILED: %s" (String.concat ", " check.Violations)

                    return Ok ({ state with Bridge = newBridge }, check)

                | Error msg ->
                    return Error $"Constitutional check failed: {msg}"
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // HEALTH MONITORING (SC-PRAJNA-004, AOR-SYNC-007)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get current health status
    let getHealth (state: IntegrationState) : SmartMetrics option =
        state.SentinelAgent
        |> Option.map SentinelBridge.getState
        |> Option.bind (fun s -> s.LastMetrics)

    /// Force immediate health sync
    let syncHealthNow (state: IntegrationState) =
        state.SentinelAgent |> Option.iter SentinelBridge.syncNow

    /// Get active threats
    let getActiveThreats (state: IntegrationState) : ThreatAdvisory list =
        state.SentinelAgent
        |> Option.map SentinelBridge.getState
        |> Option.map (fun s -> s.ActiveThreats)
        |> Option.defaultValue []

    // ═══════════════════════════════════════════════════════════════════════════
    // DASHBOARD INTEGRATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get comprehensive dashboard statistics
    let getDashboardStats (state: IntegrationState) : Map<string, obj> =
        let bridgeStats = ElixirBridge.getStatistics state.Bridge

        let sentinelStats =
            state.SentinelAgent
            |> Option.map SentinelBridge.getState
            |> Option.map SentinelBridge.getStatistics
            |> Option.defaultValue Map.empty

        // Merge all statistics
        Map.ofList [
            "is_connected", box state.IsConnected
            "total_syncs", box state.TotalSyncs
            "last_sync", box (state.LastSyncAt |> Option.map (fun d -> d.ToString("o")))
            "sync_errors", box state.SyncErrors.Length
            "bridge", box bridgeStats
            "sentinel", box sentinelStats
        ]

    /// Format status for terminal display
    let formatStatus (state: IntegrationState) : string list =
        let connectionStatus =
            if state.IsConnected then "CONNECTED" else "DISCONNECTED"

        let bridgeCircuit =
            match state.Bridge.CircuitState with
            | Closed -> "CLOSED"
            | Open _ -> "OPEN"
            | HalfOpen -> "HALF_OPEN"

        let healthScore =
            getHealth state
            |> Option.map (fun h -> sprintf "%.1f%%" h.HealthScore)
            |> Option.defaultValue "N/A"

        let threatCount = getActiveThreats state |> List.length

        [
            sprintf "=== CEPAF-PRAJNA INTEGRATION v21.1.0 ==="
            sprintf "Status: %s | Circuit: %s" connectionStatus bridgeCircuit
            sprintf "Health: %s | Threats: %d" healthScore threatCount
            sprintf "Total Syncs: %d | Errors: %d" state.TotalSyncs state.SyncErrors.Length
            match state.LastSyncAt with
            | Some dt -> sprintf "Last Sync: %s" (dt.ToString("HH:mm:ss"))
            | None -> "Last Sync: Never"
        ]

    // ═══════════════════════════════════════════════════════════════════════════
    // ZENOH OPERATIONS (SC-SYNC-009, AOR-SYNC-008)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Publish telemetry via Zenoh
    let publishTelemetry
        (state: IntegrationState)
        (topic: string)
        (payload: Map<string, obj>) : Async<Result<IntegrationState, string>> =
        async {
            if not state.IsConnected then
                return Error "Not connected"
            else
                let message: ZenohMessage = { Topic = topic; Payload = payload }
                match! publishZenoh state.Bridge message with
                | Ok newBridge ->
                    return Ok { state with Bridge = newBridge }
                | Error msg ->
                    return Error msg
        }

    /// Subscribe to Zenoh topic
    let subscribeTopic
        (state: IntegrationState)
        (topic: string) : Async<Result<IntegrationState * string, string>> =
        async {
            if not state.IsConnected then
                return Error "Not connected"
            else
                let subscription: ZenohSubscription = { Topic = topic; CallbackUrl = None }
                match! subscribeZenoh state.Bridge subscription with
                | Ok (newBridge, subId) ->
                    return Ok ({ state with Bridge = newBridge }, subId)
                | Error msg ->
                    return Error msg
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // LIFECYCLE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Initialize and optionally connect
    let initialize (config: IntegrationConfig) : Async<IntegrationState> =
        async {
            let state = create config

            if config.AutoConnect then
                match! connect state with
                | Ok connectedState -> return connectedState
                | Error msg ->
                    printfn "[Integration] Auto-connect failed: %s" msg
                    return { state with SyncErrors = msg :: state.SyncErrors }
            else
                return state
        }

    /// Graceful shutdown
    let shutdown (state: IntegrationState) : IntegrationState =
        printfn "[Integration] Shutting down..."
        disconnect state
