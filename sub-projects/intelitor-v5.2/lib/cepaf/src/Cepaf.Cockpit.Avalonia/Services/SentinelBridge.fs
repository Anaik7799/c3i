// =============================================================================
// Prajna C3I Cockpit - Sentinel Bridge
// =============================================================================
// STAMP: SC-PRAJNA-004, SC-IMMUNE-001 to SC-IMMUNE-008, SC-SYNC-004
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-03 |
// | Author | Cybernetic Architect |
// | Reference | SC-IMMUNE-*, AOR-IMMUNE-* |
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Services

open System
open System.Threading
open System.Threading.Tasks
open Cepaf.Cockpit.Avalonia.Domain.Types
open Cepaf.Cockpit.Avalonia.Domain.Messages

/// <summary>
/// Bridge to Sentinel for digital immune system integration
/// Syncs health metrics and threat detection (SC-PRAJNA-004)
/// </summary>
module SentinelBridge =

    // =========================================================================
    // Configuration
    // =========================================================================

    type SentinelConfig = {
        SyncIntervalMs: int          // SC-SYNC-004: 30s default
        HealthCheckIntervalMs: int
        ThreatAlertThreshold: float  // RPN threshold for alerts
        ResponseTimeMs: Map<ThreatSeverity, int>  // SC-IMMUNE-007
    }

    let defaultConfig = {
        SyncIntervalMs = 30000       // 30 seconds
        HealthCheckIntervalMs = 5000  // 5 seconds
        ThreatAlertThreshold = 50.0
        ResponseTimeMs = Map.ofList [
            (Extinction, 100)   // 100ms for extinction-level threats
            (ThreatSeverity.Critical, 500)
            (ThreatSeverity.High, 2000)
            (ThreatSeverity.Medium, 5000)
            (ThreatSeverity.Low, 10000)
        ]
    }

    // =========================================================================
    // SmartMetrics for Sentinel (SC-PRAJNA-004)
    // =========================================================================

    type SmartMetrics = {
        Timestamp: DateTime
        CpuUsage: float
        MemoryUsage: float
        DiskUsage: float
        NetworkLatency: int
        ErrorRate: float
        ActiveConnections: int
        RequestsPerSecond: float
        AverageResponseTimeMs: float
        OodaCycleTimeMs: float
        FitnessCoverage: float
        FitnessPassRate: float
    }

    let collectMetrics (systemHealth: SystemHealth) (ooda: OodaState) (fitness: FitnessMetrics) : SmartMetrics = {
        Timestamp = DateTime.UtcNow
        CpuUsage = systemHealth.CpuUsage
        MemoryUsage = systemHealth.MemoryUsage
        DiskUsage = systemHealth.DiskUsage
        NetworkLatency = systemHealth.NetworkLatency
        ErrorRate = systemHealth.ErrorRate
        ActiveConnections = systemHealth.ActiveConnections
        RequestsPerSecond = 0.0  // Calculated from telemetry
        AverageResponseTimeMs = 0.0
        OodaCycleTimeMs = ooda.LastCycleDuration.TotalMilliseconds
        FitnessCoverage = fitness.Coverage
        FitnessPassRate = fitness.PassRate
    }

    // =========================================================================
    // Threat Classification (SC-IMMUNE-008)
    // =========================================================================

    type ThreatCategory =
        | Lineage       // Threats to Founder's lineage (highest priority)
        | Existential   // Threats to system existence
        | Financial     // Financial/resource threats
        | Reputational  // Trust/reputation threats
        | Operational   // Operational capability threats

    let classifyThreat (threat: Threat) : ThreatCategory =
        match threat.Pattern with
        | p when p.Contains("lineage") || p.Contains("founder") -> Lineage
        | p when p.Contains("shutdown") || p.Contains("terminate") || p.Contains("destroy") -> Existential
        | p when p.Contains("financial") || p.Contains("resource") || p.Contains("budget") -> Financial
        | p when p.Contains("trust") || p.Contains("reputation") || p.Contains("compliance") -> Reputational
        | _ -> Operational

    // =========================================================================
    // Bridge State
    // =========================================================================

    type BridgeState = {
        Config: SentinelConfig
        ElixirClient: ElixirClient.ClientState
        mutable HealthScore: float
        mutable ActiveThreats: Threat list
        mutable ThreatTaxonomy: Map<string, int>
        mutable QuarantinedCount: int
        mutable LastAssessment: DateTime
        mutable LastSync: DateTime
        mutable CancellationSource: CancellationTokenSource option
        mutable DispatchCallback: (Msg -> unit) option
    }

    let create (config: SentinelConfig) (elixirClient: ElixirClient.ClientState) : BridgeState = {
        Config = config
        ElixirClient = elixirClient
        HealthScore = 1.0
        ActiveThreats = []
        ThreatTaxonomy = Map.empty
        QuarantinedCount = 0
        LastAssessment = DateTime.MinValue
        LastSync = DateTime.MinValue
        CancellationSource = None
        DispatchCallback = None
    }

    // =========================================================================
    // Sentinel API Calls
    // =========================================================================

    let private fetchSentinelState (state: BridgeState) : Task<Result<SentinelState, string>> =
        ElixirClient.getSentinelState state.ElixirClient

    let private pushMetrics (state: BridgeState) (metrics: SmartMetrics) : Task<Result<unit, string>> =
        task {
            let! result = ElixirClient.post<SmartMetrics, {| success: bool |}>
                state.ElixirClient
                ElixirClient.SentinelState
                metrics

            return result |> Result.map (fun _ -> ())
        }

    let private triggerAssessment (state: BridgeState) : Task<Result<float, string>> =
        ElixirClient.triggerAssessment state.ElixirClient

    // =========================================================================
    // Sync Loop (SC-SYNC-004: Health sync interval = 30s)
    // =========================================================================

    let private syncLoop (state: BridgeState) (token: CancellationToken) : Task =
        task {
            while not token.IsCancellationRequested do
                try
                    // Fetch Sentinel state
                    let! result = fetchSentinelState state

                    match result with
                    | Ok sentinelState ->
                        // Update local state
                        state.HealthScore <- sentinelState.HealthScore
                        state.ActiveThreats <- sentinelState.ActiveThreats
                        state.ThreatTaxonomy <- sentinelState.ThreatTaxonomy
                        state.QuarantinedCount <- sentinelState.QuarantinedProcesses
                        state.LastSync <- DateTime.UtcNow

                        // Dispatch update to MVU
                        match state.DispatchCallback with
                        | Some dispatch ->
                            dispatch (Sent (SentinelStateLoaded sentinelState))
                        | None -> ()

                        // Check for high-priority threats
                        for threat in sentinelState.ActiveThreats do
                            if threat.RpnScore >= int state.Config.ThreatAlertThreshold then
                                match state.DispatchCallback with
                                | Some dispatch ->
                                    dispatch (Sent (ThreatDetected threat))
                                | None -> ()

                    | Error _ ->
                        // Log error, continue sync loop
                        ()

                with _ ->
                    // Ignore exceptions, continue sync loop
                    ()

                do! Task.Delay(state.Config.SyncIntervalMs, token)
        }

    // =========================================================================
    // Connection Management
    // =========================================================================

    let startSync (state: BridgeState) (dispatch: Msg -> unit) : Task<bool> =
        task {
            state.DispatchCallback <- Some dispatch
            state.CancellationSource <- Some (new CancellationTokenSource())

            let token = state.CancellationSource.Value.Token

            // Start sync loop in background
            Task.Run(fun () -> syncLoop state token) |> ignore

            // Trigger initial assessment
            let! result = triggerAssessment state
            match result with
            | Ok score ->
                state.HealthScore <- score
                state.LastAssessment <- DateTime.UtcNow
                return true
            | Error _ ->
                return false
        }

    let stopSync (state: BridgeState) =
        match state.CancellationSource with
        | Some cts ->
            cts.Cancel()
            cts.Dispose()
            state.CancellationSource <- None
        | None -> ()

        state.DispatchCallback <- None

    let dispose (state: BridgeState) =
        stopSync state

    // =========================================================================
    // Health Assessment (AOR-IMMUNE-001)
    // =========================================================================

    let assessNow (state: BridgeState) : Task<Result<float, string>> =
        task {
            let! result = triggerAssessment state

            match result with
            | Ok score ->
                state.HealthScore <- score
                state.LastAssessment <- DateTime.UtcNow
                return Ok score
            | Error err ->
                return Error err
        }

    let getHealthScore (state: BridgeState) : float =
        state.HealthScore

    let getActiveThreats (state: BridgeState) : Threat list =
        state.ActiveThreats

    // =========================================================================
    // Threat Response (SC-IMMUNE-007)
    // =========================================================================

    let getResponseTime (state: BridgeState) (severity: ThreatSeverity) : int =
        state.Config.ResponseTimeMs
        |> Map.tryFind severity
        |> Option.defaultValue 10000

    let shouldQuarantine (threat: Threat) : bool =
        threat.RpnScore >= 100 || threat.Severity = Extinction

    // =========================================================================
    // Pattern Detection (SC-IMMUNE-004, SC-IMMUNE-005)
    // =========================================================================

    type PatternAnalysis = {
        Pattern: string
        Occurrences: int
        Trend: string  // "increasing", "stable", "decreasing"
        RiskLevel: ThreatSeverity
    }

    let analyzePatterns (state: BridgeState) : PatternAnalysis list =
        state.ThreatTaxonomy
        |> Map.toList
        |> List.map (fun (pattern, count) ->
            let severity =
                if count > 100 then ThreatSeverity.Critical
                elif count > 50 then ThreatSeverity.High
                elif count > 10 then ThreatSeverity.Medium
                else ThreatSeverity.Low

            {
                Pattern = pattern
                Occurrences = count
                Trend = if count > 50 then "increasing" else "stable"
                RiskLevel = severity
            })

    // =========================================================================
    // Status Query
    // =========================================================================

    let getSentinelState (state: BridgeState) : SentinelState = {
        HealthScore = state.HealthScore
        ActiveThreats = state.ActiveThreats
        ThreatTaxonomy = state.ThreatTaxonomy
        QuarantinedProcesses = state.QuarantinedCount
        LastAssessment = state.LastAssessment
    }

    let isHealthy (state: BridgeState) : bool =
        state.HealthScore >= 0.7 &&
        not (state.ActiveThreats |> List.exists (fun t -> t.Severity = Extinction))
