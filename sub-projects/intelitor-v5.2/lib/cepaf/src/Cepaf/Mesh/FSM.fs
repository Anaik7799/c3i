// =============================================================================
// FSM.fs - Finite State Machine for Container Lifecycle
// =============================================================================
// STAMP: SC-BOOT-006 (Containers MUST pass health check), SC-FUNC-003
// AOR: AOR-FUNC-001 (Verify compilation), AOR-FUNC-005 (Rollback on failure)
//
// ## Purpose
// Implements a Deterministic Finite Automaton (DFA) for container lifecycle
// management, ensuring valid state transitions and preventing illegal states.
//
// ## Mathematical Foundation
// DFA M = (Q, Σ, δ, q0, F) where:
//   Q = {NotFound, Created, Starting, Running, Healthy, Unhealthy, Stopping, Stopped, Failed}
//   Σ = {Create, Start, HealthOk, HealthFail, Stop, Remove, Crash, Timeout}
//   δ = transition function (defined below)
//   q0 = NotFound (initial state)
//   F = {Healthy} (accepting states)
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
open System.Collections.Generic

/// Container states (Q) - 9 states
type ContainerState =
    | NotFound      // q0 - initial, container doesn't exist
    | Created       // q1 - container created but not started
    | Starting      // q2 - container starting up
    | Running       // q3 - container process running (not yet healthy)
    | Healthy       // q4 - accepting state, container healthy
    | Unhealthy     // q5 - running but health check failing
    | Stopping      // q6 - graceful shutdown in progress
    | Stopped       // q7 - container stopped normally
    | Failed        // q8 - error state, needs intervention

/// Input signals (Σ) - 8 signals
type ContainerSignal =
    | Create        // Create container
    | Start         // Start container
    | HealthOk      // Health check passed
    | HealthFail    // Health check failed
    | Stop          // Graceful stop requested
    | Remove        // Remove container
    | Crash         // Container crashed unexpectedly
    | Timeout       // Operation timed out

/// State transition with metadata
type StateTransition = {
    FromState: ContainerState
    Signal: ContainerSignal
    ToState: ContainerState
    Timestamp: DateTime
    Details: string option
}

/// Container FSM instance
type ContainerFSM = {
    ContainerId: string
    ContainerName: string
    CurrentState: ContainerState
    History: StateTransition list
    CreatedAt: DateTime
    LastTransitionAt: DateTime
    HealthCheckCount: int
    ConsecutiveHealthFails: int
}

/// FSM operations module
module FSM =

    /// Transition function δ: Q × Σ → Q
    /// Returns the new state given current state and input signal
    let transition (state: ContainerState) (signal: ContainerSignal) : ContainerState =
        match state, signal with
        // From NotFound (q0)
        | NotFound, Create -> Created
        | NotFound, _ -> NotFound  // Ignore other signals

        // From Created (q1)
        | Created, Start -> Starting
        | Created, Remove -> NotFound
        | Created, _ -> Created

        // From Starting (q2)
        | Starting, HealthOk -> Running
        | Starting, HealthFail -> Starting  // Still starting, keep waiting
        | Starting, Timeout -> Failed
        | Starting, Crash -> Failed
        | Starting, Stop -> Stopping
        | Starting, _ -> Starting

        // From Running (q3)
        | Running, HealthOk -> Healthy
        | Running, HealthFail -> Unhealthy
        | Running, Stop -> Stopping
        | Running, Crash -> Failed
        | Running, _ -> Running

        // From Healthy (q4) - accepting state
        | Healthy, HealthOk -> Healthy  // Stay healthy
        | Healthy, HealthFail -> Unhealthy
        | Healthy, Stop -> Stopping
        | Healthy, Crash -> Failed
        | Healthy, _ -> Healthy

        // From Unhealthy (q5)
        | Unhealthy, HealthOk -> Healthy  // Recovered
        | Unhealthy, HealthFail -> Unhealthy
        | Unhealthy, Stop -> Stopping
        | Unhealthy, Crash -> Failed
        | Unhealthy, Timeout -> Failed
        | Unhealthy, _ -> Unhealthy

        // From Stopping (q6)
        | Stopping, HealthFail -> Stopped   // Health fails = shutdown complete
        | Stopping, Timeout -> Failed
        | Stopping, Crash -> Stopped        // Crashed during shutdown = stopped
        | Stopping, Remove -> NotFound      // Remove container goes back to NotFound
        | Stopping, _ -> Stopped            // Any other signal completes stop

        // From Stopped (q7)
        | Stopped, Start -> Starting
        | Stopped, Remove -> NotFound
        | Stopped, _ -> Stopped

        // From Failed (q8) - error state
        | Failed, Start -> Starting  // Allow restart attempt
        | Failed, Remove -> NotFound
        | Failed, _ -> Failed

    /// Check if state is accepting (healthy)
    let isAccepting (state: ContainerState) : bool =
        state = Healthy

    /// Check if state is terminal (no automatic recovery)
    let isTerminal (state: ContainerState) : bool =
        match state with
        | Failed | Stopped | NotFound -> true
        | _ -> false

    /// Check if state indicates the container is running
    let isRunning (state: ContainerState) : bool =
        match state with
        | Starting | Running | Healthy | Unhealthy -> true
        | _ -> false

    /// Create a new FSM for a container
    let create (containerId: string) (containerName: string) : ContainerFSM =
        let now = DateTime.UtcNow
        {
            ContainerId = containerId
            ContainerName = containerName
            CurrentState = NotFound
            History = []
            CreatedAt = now
            LastTransitionAt = now
            HealthCheckCount = 0
            ConsecutiveHealthFails = 0
        }

    /// Apply a signal to the FSM and return updated FSM
    let applySignal (fsm: ContainerFSM) (signal: ContainerSignal) (details: string option) : ContainerFSM =
        let now = DateTime.UtcNow
        let newState = transition fsm.CurrentState signal

        let trans = {
            FromState = fsm.CurrentState
            Signal = signal
            ToState = newState
            Timestamp = now
            Details = details
        }

        let (healthCheckCount, consecutiveFails) =
            match signal with
            | HealthOk -> (fsm.HealthCheckCount + 1, 0)
            | HealthFail -> (fsm.HealthCheckCount + 1, fsm.ConsecutiveHealthFails + 1)
            | _ -> (fsm.HealthCheckCount, fsm.ConsecutiveHealthFails)

        {
            fsm with
                CurrentState = newState
                History = trans :: fsm.History
                LastTransitionAt = now
                HealthCheckCount = healthCheckCount
                ConsecutiveHealthFails = consecutiveFails
        }

    /// Get all valid transitions from current state
    let getValidSignals (state: ContainerState) : ContainerSignal list =
        let allSignals = [Create; Start; HealthOk; HealthFail; Stop; Remove; Crash; Timeout]
        allSignals
        |> List.filter (fun signal ->
            let newState = transition state signal
            newState <> state || signal = HealthOk)  // Include signals that change state or are health checks

    /// Get state color for display
    let stateColor (state: ContainerState) : string =
        match state with
        | NotFound -> "\u001b[90m"      // Gray
        | Created -> "\u001b[36m"       // Cyan
        | Starting -> "\u001b[33m"      // Yellow
        | Running -> "\u001b[34m"       // Blue
        | Healthy -> "\u001b[32m"       // Green
        | Unhealthy -> "\u001b[33m"     // Yellow
        | Stopping -> "\u001b[35m"      // Magenta
        | Stopped -> "\u001b[90m"       // Gray
        | Failed -> "\u001b[31m"        // Red

    /// Get state name as string
    let stateName (state: ContainerState) : string =
        match state with
        | NotFound -> "NOT_FOUND"
        | Created -> "CREATED"
        | Starting -> "STARTING"
        | Running -> "RUNNING"
        | Healthy -> "HEALTHY"
        | Unhealthy -> "UNHEALTHY"
        | Stopping -> "STOPPING"
        | Stopped -> "STOPPED"
        | Failed -> "FAILED"

    /// Get state emoji
    let stateEmoji (state: ContainerState) : string =
        match state with
        | NotFound -> "❓"
        | Created -> "📦"
        | Starting -> "🔄"
        | Running -> "▶️"
        | Healthy -> "✅"
        | Unhealthy -> "⚠️"
        | Stopping -> "⏹️"
        | Stopped -> "⏸️"
        | Failed -> "❌"

    /// Print FSM state
    let printState (fsm: ContainerFSM) : unit =
        let color = stateColor fsm.CurrentState
        let emoji = stateEmoji fsm.CurrentState
        printfn "%s%s %s: %s\u001b[0m (health checks: %d, consecutive fails: %d)"
            color emoji fsm.ContainerName (stateName fsm.CurrentState)
            fsm.HealthCheckCount fsm.ConsecutiveHealthFails

    /// Print FSM transition history
    let printHistory (fsm: ContainerFSM) : unit =
        printfn ""
        printfn "State transition history for %s:" fsm.ContainerName
        printfn "════════════════════════════════════════════════════════"

        for trans in fsm.History |> List.rev do
            let details = trans.Details |> Option.defaultValue "-"
            printfn "  %s → [%A] → %s (%s)"
                (stateName trans.FromState)
                trans.Signal
                (stateName trans.ToState)
                details

        printfn ""

    /// Print FSM state diagram (ASCII art)
    let printStateDiagram () : unit =
        printfn ""
        printfn "╔═══════════════════════════════════════════════════════════════════════════════╗"
        printfn "║                     CONTAINER LIFECYCLE FSM                                    ║"
        printfn "╠═══════════════════════════════════════════════════════════════════════════════╣"
        printfn "║                                                                                ║"
        printfn "║   ┌─────────────┐                                                             ║"
        printfn "║   │  NOT_FOUND  │ ←─────────────────────────────────────────┐                ║"
        printfn "║   │    (q0)     │                                          │ Remove          ║"
        printfn "║   └──────┬──────┘                                          │                 ║"
        printfn "║          │ Create                                          │                 ║"
        printfn "║          ▼                                                 │                 ║"
        printfn "║   ┌─────────────┐                                   ┌──────┴──────┐         ║"
        printfn "║   │   CREATED   │                                   │   STOPPED   │         ║"
        printfn "║   │    (q1)     │                                   │    (q7)     │         ║"
        printfn "║   └──────┬──────┘                                   └──────┬──────┘         ║"
        printfn "║          │ Start                                          ▲                  ║"
        printfn "║          ▼                                                │                  ║"
        printfn "║   ┌─────────────┐    HealthOk     ┌─────────────┐        │                  ║"
        printfn "║   │  STARTING   │ ──────────────▶ │   RUNNING   │        │                  ║"
        printfn "║   │    (q2)     │                 │    (q3)     │        │ Completed        ║"
        printfn "║   └──────┬──────┘                 └──────┬──────┘        │                  ║"
        printfn "║          │ Timeout/Crash                 │               │                  ║"
        printfn "║          │                               │ HealthOk      │                  ║"
        printfn "║          ▼                               ▼               │                  ║"
        printfn "║   ┌─────────────┐    HealthOk     ┌─────────────┐ ┌──────┴──────┐         ║"
        printfn "║   │   FAILED    │ ◀─── Timeout ── │  UNHEALTHY  │ │  STOPPING   │         ║"
        printfn "║   │    (q8)     │                 │    (q5)     │ │    (q6)     │         ║"
        printfn "║   └─────────────┘                 └──────┬──────┘ └─────────────┘         ║"
        printfn "║                                          │                                  ║"
        printfn "║                                          │ HealthOk                         ║"
        printfn "║                                          ▼                                  ║"
        printfn "║                                   ╔═════════════╗                           ║"
        printfn "║                                   ║   HEALTHY   ║ ← Accepting State        ║"
        printfn "║                                   ║    (q4)     ║                           ║"
        printfn "║                                   ╚═════════════╝                           ║"
        printfn "║                                                                                ║"
        printfn "╚═══════════════════════════════════════════════════════════════════════════════╝"
        printfn ""
