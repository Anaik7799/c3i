// =============================================================================
// Hysteresis.fs - Health Check Stability via Hysteresis Control
// =============================================================================
// STAMP: SC-BOOT-006 (Containers MUST pass health check), SC-OPT-002
// AOR: AOR-BOOT-003 (Prevent health check flapping)
//
// ## Purpose
// Implements hysteresis control to prevent health check flapping.
// A service must remain in a state for N consecutive checks before
// transitioning to a new state.
//
// ## Mathematical Foundation
// Hysteresis: State change requires N consecutive confirmations
// H(n) = NewState if last N checks agree, else CurrentState
//
// This prevents:
// - Flapping: rapid oscillation between healthy/unhealthy
// - False positives: single check failure causing state change
// - Premature transitions: transient issues causing restarts
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-18 |
// | Author | Claude Opus 4.5 |
// | Reference | 20260118-1615-sil6-biomorphic-startup-master-specification.md |
// =============================================================================

namespace Cepaf.Mesh

open System

/// Health state for hysteresis tracking
type HealthState =
    | Healthy
    | Unhealthy
    | Unknown
    | Degraded

/// Configuration for hysteresis behavior
type HysteresisConfig = {
    /// Number of consecutive checks required for state transition
    RequiredConsecutive: int
    /// Minimum interval between health checks (ms)
    CheckIntervalMs: int
    /// Ignore state changes within this window (ms) - debounce
    DebounceMs: int
    /// Maximum history to retain
    MaxHistory: int
    /// Threshold for degraded state (consecutive failures before unhealthy)
    DegradedThreshold: int
}

/// State of the hysteresis controller
type HysteresisState = {
    /// Current stable state
    CurrentState: HealthState
    /// Number of consecutive checks in potential new state
    ConsecutiveCount: int
    /// Potential new state being tested
    PendingState: HealthState option
    /// Timestamp of last state change
    LastStateChange: DateTime
    /// Timestamp of last health check
    LastCheckTime: DateTime
    /// History of recent health checks
    History: (DateTime * HealthState) list
    /// Total healthy checks
    TotalHealthyChecks: int
    /// Total unhealthy checks
    TotalUnhealthyChecks: int
}

/// Result of applying a health check
type HysteresisResult =
    | StateUnchanged of current: HealthState * consecutiveInNew: int
    | StateTransitioned of from: HealthState * to': HealthState
    | Debounced of reason: string

/// Hysteresis controller operations
module Hysteresis =

    /// Default configuration
    let defaultConfig : HysteresisConfig = {
        RequiredConsecutive = 3     // 3 consecutive checks to change state
        CheckIntervalMs = 1000      // 1 second between checks
        DebounceMs = 500            // 500ms debounce window
        MaxHistory = 100            // Keep last 100 checks
        DegradedThreshold = 2       // 2 failures = degraded, 3 = unhealthy
    }

    /// Aggressive config for faster transitions (development)
    let aggressiveConfig : HysteresisConfig = {
        RequiredConsecutive = 2
        CheckIntervalMs = 500
        DebounceMs = 200
        MaxHistory = 50
        DegradedThreshold = 1
    }

    /// Conservative config for stable production
    let conservativeConfig : HysteresisConfig = {
        RequiredConsecutive = 5
        CheckIntervalMs = 2000
        DebounceMs = 1000
        MaxHistory = 200
        DegradedThreshold = 3
    }

    /// Create initial hysteresis state
    let create () : HysteresisState = {
        CurrentState = Unknown
        ConsecutiveCount = 0
        PendingState = None
        LastStateChange = DateTime.MinValue  // No debounce on first check
        LastCheckTime = DateTime.MinValue
        History = []
        TotalHealthyChecks = 0
        TotalUnhealthyChecks = 0
    }

    /// Apply a health check result with hysteresis
    let applyCheck (config: HysteresisConfig) (state: HysteresisState) (newCheck: HealthState) : HysteresisState * HysteresisResult =
        let now = DateTime.UtcNow

        // Update statistics
        let (healthyCount, unhealthyCount) =
            match newCheck with
            | Healthy -> (state.TotalHealthyChecks + 1, state.TotalUnhealthyChecks)
            | Unhealthy -> (state.TotalHealthyChecks, state.TotalUnhealthyChecks + 1)
            | _ -> (state.TotalHealthyChecks, state.TotalUnhealthyChecks)

        // Add to history (truncate if needed)
        let newHistory =
            (now, newCheck) :: state.History
            |> List.truncate config.MaxHistory

        // Check debounce window
        let timeSinceLastChange = (now - state.LastStateChange).TotalMilliseconds
        if timeSinceLastChange < float config.DebounceMs then
            let newState = {
                state with
                    LastCheckTime = now
                    History = newHistory
                    TotalHealthyChecks = healthyCount
                    TotalUnhealthyChecks = unhealthyCount
            }
            (newState, Debounced "Within debounce window")

        // Same as current state - reset consecutive counter
        elif newCheck = state.CurrentState then
            let newState = {
                state with
                    ConsecutiveCount = 0
                    PendingState = None
                    LastCheckTime = now
                    History = newHistory
                    TotalHealthyChecks = healthyCount
                    TotalUnhealthyChecks = unhealthyCount
            }
            (newState, StateUnchanged (state.CurrentState, 0))

        // Different state - track consecutive checks
        else
            let (pendingState, consecutiveCount) =
                match state.PendingState with
                | Some pending when pending = newCheck ->
                    // Same as pending - increment
                    (Some newCheck, state.ConsecutiveCount + 1)
                | _ ->
                    // New pending state - start counting
                    (Some newCheck, 1)

            // Check if threshold reached
            if consecutiveCount >= config.RequiredConsecutive then
                // Transition to new state
                let newState = {
                    state with
                        CurrentState = newCheck
                        ConsecutiveCount = 0
                        PendingState = None
                        LastStateChange = now
                        LastCheckTime = now
                        History = newHistory
                        TotalHealthyChecks = healthyCount
                        TotalUnhealthyChecks = unhealthyCount
                }
                (newState, StateTransitioned (state.CurrentState, newCheck))
            else
                // Still accumulating
                let newState = {
                    state with
                        ConsecutiveCount = consecutiveCount
                        PendingState = pendingState
                        LastCheckTime = now
                        History = newHistory
                        TotalHealthyChecks = healthyCount
                        TotalUnhealthyChecks = unhealthyCount
                }
                (newState, StateUnchanged (state.CurrentState, consecutiveCount))

    /// Get health percentage from history
    let getHealthPercentage (state: HysteresisState) : float =
        let total = state.TotalHealthyChecks + state.TotalUnhealthyChecks
        if total = 0 then 0.0
        else float state.TotalHealthyChecks / float total * 100.0

    /// Get recent health trend (last N checks)
    let getRecentTrend (n: int) (state: HysteresisState) : (int * int) =
        let recent = state.History |> List.truncate n
        let healthy = recent |> List.filter (fun (_, s) -> s = Healthy) |> List.length
        let unhealthy = recent |> List.filter (fun (_, s) -> s = Unhealthy) |> List.length
        (healthy, unhealthy)

    /// Check if currently in stable healthy state
    let isStableHealthy (state: HysteresisState) : bool =
        state.CurrentState = Healthy && state.ConsecutiveCount = 0

    /// Check if health is trending down
    let isTrendingDown (state: HysteresisState) : bool =
        match state.PendingState with
        | Some Unhealthy -> true
        | _ ->
            let (healthy, unhealthy) = getRecentTrend 5 state
            unhealthy > healthy

    /// Get time since last healthy state
    let timeSinceHealthy (state: HysteresisState) : TimeSpan option =
        if state.CurrentState = Healthy then Some TimeSpan.Zero
        else
            state.History
            |> List.tryFind (fun (_, s) -> s = Healthy)
            |> Option.map (fun (t, _) -> DateTime.UtcNow - t)

    /// Get state color for display
    let stateColor (state: HealthState) : string =
        match state with
        | Healthy -> "\u001b[32m"   // Green
        | Unhealthy -> "\u001b[31m" // Red
        | Degraded -> "\u001b[33m"  // Yellow
        | Unknown -> "\u001b[90m"   // Gray

    /// Print hysteresis state summary
    let printState (name: string) (state: HysteresisState) : unit =
        let color = stateColor state.CurrentState
        let pending =
            match state.PendingState with
            | Some p -> sprintf " → %s (%d/%s)" (stateColor p + (sprintf "%A" p) + "\u001b[0m") state.ConsecutiveCount "?"
            | None -> ""
        let trend = if isTrendingDown state then "📉" else "📈"

        printfn "%s%s: %A\u001b[0m%s %s (%.1f%% healthy, %d checks)"
            color name state.CurrentState pending trend
            (getHealthPercentage state)
            (state.TotalHealthyChecks + state.TotalUnhealthyChecks)

    /// Print recent health history
    let printHistory (state: HysteresisState) : unit =
        printfn ""
        printfn "Recent health history (last 10 checks):"
        for (time, health) in state.History |> List.truncate 10 do
            let color = stateColor health
            printfn "  %s - %s%A\u001b[0m" (time.ToString("HH:mm:ss.fff")) color health
        printfn ""
