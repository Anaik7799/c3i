namespace Cepaf.Cockpit

open System
open System.Threading
open Cepaf.Rop

/// ===============================================================================
/// CEPAF-PRAJNA SENTINEL BRIDGE (30s Health Sync)
/// ===============================================================================
///
/// WHAT: GenServer-style F# agent that synchronizes Sentinel health data between
///       F# CEPAF Cockpit and Elixir Prajna backend every 30 seconds.
///
/// WHY: SC-PRAJNA-004 requires Sentinel health integration. SC-SYNC-004 mandates
///      30-second sync interval. AOR-SYNC-007 requires continuous Sentinel health sync.
///
/// STAMP Compliance:
///   - SC-PRAJNA-004: Sentinel health integration required
///   - SC-SYNC-004: Health sync interval = 30s
///   - SC-BIO-001: OODA cycle < 100ms (individual checks)
///   - SC-OBS-069: Dual logging to terminal and telemetry
///
/// AOR Compliance:
///   - AOR-SYNC-007: Sentinel Health - Sync Sentinel health every 30s
///   - AOR-BIO-004: Dashboard Refresh - Display dashboard with 30s refresh
///   - AOR-PRAJNA-004: Sentinel Sync - SmartMetrics MUST sync with Sentinel every 30 seconds
///
/// ===============================================================================
module SentinelBridge =

    open ElixirBridge

    // ═══════════════════════════════════════════════════════════════════════════
    // TYPES
    // ═══════════════════════════════════════════════════════════════════════════

    /// Threat advisory from Sentinel
    type ThreatAdvisory = {
        Id: string
        Severity: string
        Description: string
        AffectedModule: string
        RecommendedAction: string
        DetectedAt: DateTime
        ExpireAt: DateTime option
    }

    /// Smart metrics for Prajna display
    type SmartMetrics = {
        HealthScore: float
        Status: string
        SystemLoad: float
        MemoryUsage: float
        CpuUsage: float
        ActiveConnections: int
        ErrorRate: float
        ThroughputRps: float
    }

    /// Bridge configuration
    type SentinelConfig = {
        /// Sync interval (SC-SYNC-004: 30s)
        SyncInterval: TimeSpan
        /// Maximum consecutive failures before alerting
        MaxConsecutiveFailures: int
        /// Enable threat monitoring
        ThreatMonitoringEnabled: bool
        /// Pattern taxonomy for threat classification
        PatternTaxonomyEnabled: bool
    }

    /// Default configuration
    let defaultConfig = {
        SyncInterval = TimeSpan.FromSeconds(30.0)  // SC-SYNC-004
        MaxConsecutiveFailures = 3
        ThreatMonitoringEnabled = true
        PatternTaxonomyEnabled = true
    }

    /// Sync state
    type SyncState = {
        Config: SentinelConfig
        Bridge: BridgeState
        LastHealth: SentinelHealth option
        LastMetrics: SmartMetrics option
        ActiveThreats: ThreatAdvisory list
        ConsecutiveFailures: int
        TotalSyncs: int64
        TotalFailures: int64
        LastSyncAt: DateTime option
        NextSyncAt: DateTime
        IsRunning: bool
    }

    /// Messages for the Sentinel bridge agent
    type SentinelMsg =
        | SyncNow
        | UpdateMetrics of SmartMetrics
        | AddThreat of ThreatAdvisory
        | RemoveThreat of string
        | GetState of AsyncReplyChannel<SyncState>
        | Stop

    // ═══════════════════════════════════════════════════════════════════════════
    // STATE MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create initial sync state
    let createState (config: SentinelConfig) (bridgeConfig: BridgeConfig) : SyncState = {
        Config = config
        Bridge = createBridge bridgeConfig
        LastHealth = None
        LastMetrics = None
        ActiveThreats = []
        ConsecutiveFailures = 0
        TotalSyncs = 0L
        TotalFailures = 0L
        LastSyncAt = None
        NextSyncAt = DateTime.UtcNow.Add(config.SyncInterval)
        IsRunning = true
    }

    /// Convert Sentinel health to Smart metrics
    let toSmartMetrics (health: SentinelHealth) : SmartMetrics = {
        HealthScore = health.HealthScore
        Status = health.Status
        SystemLoad = health.SystemLoad
        MemoryUsage = health.MemoryUsage
        CpuUsage = health.CpuUsage
        ActiveConnections = 0  // Would come from actual metrics
        ErrorRate = 0.0
        ThroughputRps = 0.0
    }

    /// Convert threats from string list to ThreatAdvisory
    let toThreatAdvisories (threats: string list) : ThreatAdvisory list =
        threats
        |> List.mapi (fun i desc -> {
            Id = sprintf "threat_%d_%d" (DateTime.UtcNow.Ticks) i
            Severity = "medium"
            Description = desc
            AffectedModule = "unknown"
            RecommendedAction = "investigate"
            DetectedAt = DateTime.UtcNow
            ExpireAt = None
        })

    // ═══════════════════════════════════════════════════════════════════════════
    // SYNC OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Perform health sync (SC-PRAJNA-004, SC-SYNC-004, AOR-SYNC-007)
    let private performSync (state: SyncState) : Async<SyncState> =
        async {
            try
                match! checkHealth state.Bridge with
                | Ok (newBridge, health) ->
                    let metrics = toSmartMetrics health
                    let threats = toThreatAdvisories health.ActiveThreats

                    return {
                        state with
                            Bridge = newBridge
                            LastHealth = Some health
                            LastMetrics = Some metrics
                            ActiveThreats = threats
                            ConsecutiveFailures = 0
                            TotalSyncs = state.TotalSyncs + 1L
                            LastSyncAt = Some DateTime.UtcNow
                            NextSyncAt = DateTime.UtcNow.Add(state.Config.SyncInterval)
                    }

                | Error msg ->
                    printfn "[SentinelBridge] Sync failed: %s" msg
                    return {
                        state with
                            ConsecutiveFailures = state.ConsecutiveFailures + 1
                            TotalFailures = state.TotalFailures + 1L
                            NextSyncAt = DateTime.UtcNow.Add(state.Config.SyncInterval)
                    }
            with ex ->
                printfn "[SentinelBridge] Sync exception: %s" ex.Message
                return {
                    state with
                        ConsecutiveFailures = state.ConsecutiveFailures + 1
                        TotalFailures = state.TotalFailures + 1L
                        NextSyncAt = DateTime.UtcNow.Add(state.Config.SyncInterval)
                }
        }

    /// Push SmartMetrics to Elixir Sentinel (bidirectional sync)
    let private pushMetrics (state: SyncState) (metrics: SmartMetrics) : Async<SyncState> =
        async {
            // Publish metrics via Zenoh
            let message: ZenohMessage = {
                Topic = "prajna/metrics/smart"
                Payload = Map.ofList [
                    "health_score", box metrics.HealthScore
                    "status", box metrics.Status
                    "system_load", box metrics.SystemLoad
                    "memory_usage", box metrics.MemoryUsage
                    "cpu_usage", box metrics.CpuUsage
                    "timestamp", box (DateTime.UtcNow.ToString("o"))
                ]
            }

            match! publishZenoh state.Bridge message with
            | Ok newBridge ->
                return { state with Bridge = newBridge; LastMetrics = Some metrics }
            | Error msg ->
                printfn "[SentinelBridge] Failed to push metrics: %s" msg
                return state
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // SENTINEL BRIDGE AGENT
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create the Sentinel bridge agent (GenServer-style)
    let createAgent (config: SentinelConfig) (bridgeConfig: BridgeConfig) (onHealthUpdate: SmartMetrics -> unit) =
        MailboxProcessor.Start(fun inbox ->
            let rec loop (state: SyncState) = async {
                let! msg = inbox.TryReceive(1000)  // 1 second timeout for timer checks

                match msg with
                | Some SyncNow ->
                    let! newState = performSync state
                    match newState.LastMetrics with
                    | Some metrics -> onHealthUpdate metrics
                    | None -> ()
                    return! loop newState

                | Some (UpdateMetrics metrics) ->
                    let! newState = pushMetrics state metrics
                    return! loop newState

                | Some (AddThreat threat) ->
                    let newThreats = threat :: state.ActiveThreats
                    return! loop { state with ActiveThreats = newThreats }

                | Some (RemoveThreat threatId) ->
                    let newThreats = state.ActiveThreats |> List.filter (fun t -> t.Id <> threatId)
                    return! loop { state with ActiveThreats = newThreats }

                | Some (GetState channel) ->
                    channel.Reply state
                    return! loop state

                | Some Stop ->
                    printfn "[SentinelBridge] Stopping..."
                    return ()

                | None ->
                    // Timer tick - check if sync is due
                    if state.IsRunning && DateTime.UtcNow >= state.NextSyncAt then
                        inbox.Post SyncNow
                    return! loop state
            }

            let initialState = createState config bridgeConfig
            printfn "[SentinelBridge] Started with %ds sync interval" (int config.SyncInterval.TotalSeconds)
            loop initialState
        )

    // ═══════════════════════════════════════════════════════════════════════════
    // PUBLIC API
    // ═══════════════════════════════════════════════════════════════════════════

    /// Start the Sentinel bridge with default configuration
    let start (bridgeConfig: BridgeConfig) (onHealthUpdate: SmartMetrics -> unit) =
        createAgent defaultConfig bridgeConfig onHealthUpdate

    /// Start with custom configuration
    let startWithConfig (config: SentinelConfig) (bridgeConfig: BridgeConfig) (onHealthUpdate: SmartMetrics -> unit) =
        createAgent config bridgeConfig onHealthUpdate

    /// Force immediate sync
    let syncNow (agent: MailboxProcessor<SentinelMsg>) =
        agent.Post SyncNow

    /// Get current state
    let getState (agent: MailboxProcessor<SentinelMsg>) : SyncState =
        agent.PostAndReply(fun channel -> GetState channel)

    /// Stop the bridge
    let stop (agent: MailboxProcessor<SentinelMsg>) =
        agent.Post Stop

    /// Update metrics from local sources
    let updateMetrics (agent: MailboxProcessor<SentinelMsg>) (metrics: SmartMetrics) =
        agent.Post (UpdateMetrics metrics)

    /// Add threat advisory
    let addThreat (agent: MailboxProcessor<SentinelMsg>) (threat: ThreatAdvisory) =
        agent.Post (AddThreat threat)

    /// Remove threat advisory
    let removeThreat (agent: MailboxProcessor<SentinelMsg>) (threatId: string) =
        agent.Post (RemoveThreat threatId)

    // ═══════════════════════════════════════════════════════════════════════════
    // DASHBOARD INTEGRATION (AOR-BIO-004)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Format health for dashboard display
    let formatHealthForDashboard (state: SyncState) : string list =
        let status =
            match state.LastHealth with
            | Some h -> sprintf "Health: %.1f%% (%s)" h.HealthScore h.Status
            | None -> "Health: Unknown"

        let syncInfo =
            match state.LastSyncAt with
            | Some dt -> sprintf "Last Sync: %s" (dt.ToString("HH:mm:ss"))
            | None -> "Last Sync: Never"

        let nextSync = sprintf "Next Sync: %s" (state.NextSyncAt.ToString("HH:mm:ss"))

        let threats =
            if state.ActiveThreats.IsEmpty then
                "Threats: None"
            else
                sprintf "Threats: %d active" state.ActiveThreats.Length

        let stats = sprintf "Syncs: %d | Failures: %d" state.TotalSyncs state.TotalFailures

        [ status; syncInfo; nextSync; threats; stats ]

    /// Get statistics for API dashboard
    let getStatistics (state: SyncState) : Map<string, obj> =
        Map.ofList [
            "total_syncs", box state.TotalSyncs
            "total_failures", box state.TotalFailures
            "consecutive_failures", box state.ConsecutiveFailures
            "active_threats", box state.ActiveThreats.Length
            "is_running", box state.IsRunning
            "last_sync", box (state.LastSyncAt |> Option.map (fun d -> d.ToString("o")))
            "next_sync", box (state.NextSyncAt.ToString("o"))
            "health_score", box (state.LastHealth |> Option.map (fun h -> h.HealthScore) |> Option.defaultValue 0.0)
        ]
