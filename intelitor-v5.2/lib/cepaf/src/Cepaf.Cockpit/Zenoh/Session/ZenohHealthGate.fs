// =============================================================================
// ZenohHealthGate.fs - Zenoh Health Check and Startup Gate
// =============================================================================
// STAMP: SC-ZENOH-007, SC-ZENOH-008, SC-CNT-015
// AOR: AOR-ZENOH-002, AOR-ZENOH-003, AOR-ZENOH-007
// Criticality: Level 5 (CRITICAL) - Container Startup Safety
// =============================================================================
// Provides health gate functionality for safe container startup:
// - Health check verifies Zenoh session connectivity (SC-ZENOH-007)
// - Startup gate blocks until Zenoh available (SC-ZENOH-008)
// - HTTP endpoint integration for /health (SC-CNT-015)
// - Timeout handling (max 30s for startup)
// =============================================================================
// FM-007: Add Zenoh health check to /health endpoint and startup gate
// Context: Containers can start without Zenoh connectivity, creating zombies
// Solution: Block container startup until Zenoh connectivity verified
// =============================================================================

namespace Cepaf.Zenoh.Session

open System
open System.Threading
open System.Threading.Tasks
open Cepaf.Zenoh.Core

/// Zenoh health status for HTTP response
type ZenohHealthStatus = {
    /// Connection status (connected, disconnected, etc.)
    Connected: bool
    /// Connection status string
    Status: string
    /// Session identifier if connected
    SessionId: string option
    /// Last heartbeat timestamp
    LastHeartbeat: DateTimeOffset option
    /// Average latency in milliseconds
    Latency: TimeSpan option
    /// Number of active subscriptions
    TopicCount: int
    /// Uptime duration
    Uptime: TimeSpan option
    /// Messages published count
    MessagesPublished: int64
    /// Messages received count
    MessagesReceived: int64
    /// Reconnection attempts
    ReconnectCount: int
    /// Error count
    ErrorCount: int
}

module ZenohHealthStatus =
    /// Create empty/initial health status
    let empty = {
        Connected = false
        Status = "disconnected"
        SessionId = None
        LastHeartbeat = None
        Latency = None
        TopicCount = 0
        Uptime = None
        MessagesPublished = 0L
        MessagesReceived = 0L
        ReconnectCount = 0
        ErrorCount = 0
    }

    /// Create from ZenohHealth
    let fromZenohHealth (health: ZenohHealth) (topicCount: int) = {
        Connected = health.Status.IsInConnectedState
        Status = health.Status.ToString()
        SessionId = health.SessionId
        LastHeartbeat = health.LastHeartbeat
        Latency =
            if health.AveragePublishLatencyMs > 0.0 then
                Some (TimeSpan.FromMilliseconds(health.AveragePublishLatencyMs))
            else
                None
        TopicCount = topicCount
        Uptime = health.Uptime
        MessagesPublished = health.MessagesPublished
        MessagesReceived = health.MessagesReceived
        ReconnectCount = health.ReconnectCount
        ErrorCount = health.ErrorCount
    }

/// Health check result
[<RequireQualifiedAccess>]
type HealthCheckResult =
    | Healthy of status: ZenohHealthStatus
    | Unhealthy of reason: string * status: ZenohHealthStatus
    | Timeout of waitedMs: int

    member this.IsOperational =
        match this with
        | Healthy _ -> true
        | _ -> false

    member this.GetStatus =
        match this with
        | Healthy s | Unhealthy (_, s) -> Some s
        | Timeout _ -> None

/// Startup gate result
[<RequireQualifiedAccess>]
type StartupGateResult =
    | Ready of status: ZenohHealthStatus
    | Failed of reason: string
    | Timeout of waitedMs: int

    member this.IsSuccessful =
        match this with
        | Ready _ -> true
        | _ -> false

/// Zenoh Health Gate - ensures Zenoh connectivity before container operations
type ZenohHealthGate(lifecycle: ZenohLifecycle) =

    // Configuration
    let startupTimeoutMs = 30000  // SC-ZENOH-008: 30 second max wait
    let healthCheckIntervalMs = 500  // Poll every 500ms
    let latencyTargetMs = 100.0  // SC-ZENOH-004: <100ms latency

    /// Check Zenoh session health (SC-ZENOH-007)
    /// Returns detailed health status for /health endpoint
    member _.CheckHealth() : HealthCheckResult =
        try
            let health = lifecycle.Health
            let topicCount =
                match lifecycle.Session with
                | Some session -> session.SubscriberCount
                | None -> 0

            let status = ZenohHealthStatus.fromZenohHealth health topicCount

            // Determine if healthy based on connection state
            match health.Status with
            | ConnectionStatus.Connected ->
                // Additional validation: check latency
                if health.AveragePublishLatencyMs > latencyTargetMs then
                    let reason = sprintf "Latency %.2fms exceeds target %.0fms"
                                    health.AveragePublishLatencyMs latencyTargetMs
                    HealthCheckResult.Unhealthy (reason, status)
                else
                    HealthCheckResult.Healthy status

            | ConnectionStatus.Connecting
            | ConnectionStatus.Reconnecting ->
                HealthCheckResult.Unhealthy ("Not yet connected", status)

            | ConnectionStatus.Disconnected ->
                HealthCheckResult.Unhealthy ("Disconnected", status)

            | ConnectionStatus.Failed reason ->
                HealthCheckResult.Unhealthy (sprintf "Failed: %s" reason, status)

        with ex ->
            let status = { ZenohHealthStatus.empty with
                            Status = sprintf "error: %s" ex.Message }
            HealthCheckResult.Unhealthy (ex.Message, status)

    /// Check health asynchronously
    member this.CheckHealthAsync() : Task<HealthCheckResult> =
        Task.FromResult(this.CheckHealth())

    /// Wait for Zenoh to be ready (SC-ZENOH-008)
    /// Blocks until Zenoh is connected or timeout
    /// Returns: Ready(status) | Failed(reason) | Timeout(ms)
    member this.WaitForZenohAsync(?timeoutMs: int) : Task<StartupGateResult> =
        let timeout = defaultArg timeoutMs startupTimeoutMs

        task {
            use cts = new CancellationTokenSource(timeout)
            let startTime = DateTimeOffset.UtcNow
            let mutable continueLoop = true
            let mutable result = StartupGateResult.Timeout timeout

            try
                // Poll until connected or timeout
                while continueLoop && not cts.Token.IsCancellationRequested do
                    let healthResult = this.CheckHealth()

                    match healthResult with
                    | HealthCheckResult.Healthy status ->
                        // Successfully connected
                        result <- StartupGateResult.Ready status
                        continueLoop <- false

                    | HealthCheckResult.Unhealthy (reason, status) ->
                        // Not healthy yet - check if we should keep waiting
                        match status.Status with
                        | "connecting" | "reconnecting" ->
                            // Still trying to connect - keep waiting
                            do! Task.Delay(healthCheckIntervalMs, cts.Token)
                        | _ ->
                            // Failed state - don't wait
                            result <- StartupGateResult.Failed reason
                            continueLoop <- false

                    | HealthCheckResult.Timeout _ ->
                        // Health check itself timed out
                        result <- StartupGateResult.Failed "Health check timeout"
                        continueLoop <- false

                // If we reach here, cancellation token was triggered (timeout)
                if cts.Token.IsCancellationRequested then
                    let elapsed = (DateTimeOffset.UtcNow - startTime).TotalMilliseconds |> int
                    result <- StartupGateResult.Timeout elapsed

                return result

            with
            | :? OperationCanceledException ->
                // Timeout reached
                let elapsed = (DateTimeOffset.UtcNow - startTime).TotalMilliseconds |> int
                return StartupGateResult.Timeout elapsed
            | ex ->
                // Unexpected error
                return StartupGateResult.Failed (sprintf "Startup gate error: %s" ex.Message)
        }

    /// Wait for Zenoh synchronously (blocks current thread)
    member this.WaitForZenoh(?timeoutMs: int) : StartupGateResult =
        let timeout = defaultArg timeoutMs startupTimeoutMs
        this.WaitForZenohAsync(timeout)
            .GetAwaiter()
            .GetResult()

    /// Format health status as JSON for HTTP endpoint (SC-CNT-015)
    member _.FormatHealthJson(status: ZenohHealthStatus) : string =
        // Manual JSON construction for compatibility
        // (avoids dependency on System.Text.Json in this module)
        let sb = System.Text.StringBuilder()
        sb.Append("{") |> ignore

        // Connected (boolean)
        sb.AppendFormat("\"connected\":{0}", if status.Connected then "true" else "false") |> ignore
        sb.Append(",") |> ignore

        // Status (string)
        sb.AppendFormat("\"status\":\"{0}\"", status.Status) |> ignore
        sb.Append(",") |> ignore

        // SessionId (optional string)
        match status.SessionId with
        | Some sid ->
            sb.AppendFormat("\"session_id\":\"{0}\"", sid) |> ignore
        | None ->
            sb.Append("\"session_id\":null") |> ignore
        sb.Append(",") |> ignore

        // LastHeartbeat (optional ISO8601 string)
        match status.LastHeartbeat with
        | Some hb ->
            sb.AppendFormat("\"last_heartbeat\":\"{0}\"", hb.ToString("o")) |> ignore
        | None ->
            sb.Append("\"last_heartbeat\":null") |> ignore
        sb.Append(",") |> ignore

        // Latency (optional milliseconds)
        match status.Latency with
        | Some lat ->
            sb.AppendFormat("\"latency_ms\":{0:F2}", lat.TotalMilliseconds) |> ignore
        | None ->
            sb.Append("\"latency_ms\":null") |> ignore
        sb.Append(",") |> ignore

        // TopicCount (integer)
        sb.AppendFormat("\"topic_count\":{0}", status.TopicCount) |> ignore
        sb.Append(",") |> ignore

        // Uptime (optional seconds)
        match status.Uptime with
        | Some up ->
            sb.AppendFormat("\"uptime_seconds\":{0:F1}", up.TotalSeconds) |> ignore
        | None ->
            sb.Append("\"uptime_seconds\":null") |> ignore
        sb.Append(",") |> ignore

        // Messages (integers)
        sb.AppendFormat("\"messages_published\":{0}", status.MessagesPublished) |> ignore
        sb.Append(",") |> ignore
        sb.AppendFormat("\"messages_received\":{0}", status.MessagesReceived) |> ignore
        sb.Append(",") |> ignore

        // Reconnect count
        sb.AppendFormat("\"reconnect_count\":{0}", status.ReconnectCount) |> ignore
        sb.Append(",") |> ignore

        // Error count
        sb.AppendFormat("\"error_count\":{0}", status.ErrorCount) |> ignore

        sb.Append("}") |> ignore
        sb.ToString()

    /// Format health check result as JSON
    member this.FormatHealthCheckJson(result: HealthCheckResult) : string =
        let isHealthy = result.IsOperational
        match result with
        | HealthCheckResult.Healthy status ->
            sprintf "{\"healthy\":true,\"zenoh\":%s}" (this.FormatHealthJson status)
        | HealthCheckResult.Unhealthy (reason, status) ->
            sprintf "{\"healthy\":false,\"reason\":\"%s\",\"zenoh\":%s}"
                reason (this.FormatHealthJson status)
        | HealthCheckResult.Timeout waitedMs ->
            sprintf "{\"healthy\":false,\"reason\":\"Health check timeout\",\"waited_ms\":%d}"
                waitedMs

    /// Format startup gate result as JSON
    member this.FormatStartupGateJson(result: StartupGateResult) : string =
        match result with
        | StartupGateResult.Ready status ->
            sprintf "{\"ready\":true,\"zenoh\":%s}" (this.FormatHealthJson status)
        | StartupGateResult.Failed reason ->
            sprintf "{\"ready\":false,\"reason\":\"%s\"}" reason
        | StartupGateResult.Timeout waitedMs ->
            sprintf "{\"ready\":false,\"reason\":\"Startup timeout\",\"waited_ms\":%d}"
                waitedMs

/// Factory for creating health gates
module ZenohHealthGate =

    /// Create health gate for a lifecycle manager
    let create (lifecycle: ZenohLifecycle) =
        new ZenohHealthGate(lifecycle)

    /// Perform health check on lifecycle
    let checkHealth (lifecycle: ZenohLifecycle) =
        let gate = create lifecycle
        gate.CheckHealth()

    /// Wait for Zenoh to be ready
    let waitForZenoh (lifecycle: ZenohLifecycle) (timeoutMs: int) =
        let gate = create lifecycle
        gate.WaitForZenoh(timeoutMs)

    /// Wait for Zenoh asynchronously
    let waitForZenohAsync (lifecycle: ZenohLifecycle) (timeoutMs: int) =
        let gate = create lifecycle
        gate.WaitForZenohAsync(timeoutMs)

    /// Get health status as JSON
    let healthJson (lifecycle: ZenohLifecycle) =
        let gate = create lifecycle
        let result = gate.CheckHealth()
        gate.FormatHealthCheckJson(result)

// =============================================================================
// USAGE EXAMPLES (for Elixir bridge integration)
// =============================================================================
//
// 1. Container startup gate:
//    let lifecycle = ZenohLifecycle(config, "node-1")
//    let! initResult = lifecycle.InitializeAsync()
//    match initResult with
//    | Ok _ ->
//        let gate = ZenohHealthGate.create lifecycle
//        let! startupResult = gate.WaitForZenohAsync(30000)
//        match startupResult with
//        | StartupGateResult.Ready status ->
//            printfn "Container ready: Zenoh connected"
//            // Proceed with application startup
//        | StartupGateResult.Failed reason ->
//            eprintfn "Container startup BLOCKED: %s" reason
//            exit 1
//        | StartupGateResult.Timeout ms ->
//            eprintfn "Container startup TIMEOUT after %dms" ms
//            exit 1
//    | Error e ->
//        eprintfn "Zenoh initialization failed: %s" e.Message
//        exit 1
//
// 2. HTTP /health endpoint:
//    let healthCheckHandler (lifecycle: ZenohLifecycle) =
//        let gate = ZenohHealthGate.create lifecycle
//        let result = gate.CheckHealth()
//        let json = gate.FormatHealthCheckJson(result)
//        // Return JSON response with appropriate HTTP status:
//        // - 200 OK if Healthy
//        // - 503 Service Unavailable if Unhealthy or Timeout
//        (if result.IsHealthy then 200 else 503, json)
//
// 3. Periodic health monitoring:
//    let monitorHealth (lifecycle: ZenohLifecycle) = async {
//        let gate = ZenohHealthGate.create lifecycle
//        while true do
//            let! result = gate.CheckHealthAsync()
//            match result with
//            | HealthCheckResult.Healthy status ->
//                printfn "[Health] OK - Latency: %A" status.Latency
//            | HealthCheckResult.Unhealthy (reason, _) ->
//                eprintfn "[Health] DEGRADED - %s" reason
//            | HealthCheckResult.Timeout ms ->
//                eprintfn "[Health] TIMEOUT after %dms" ms
//            do! Async.Sleep 10000  // Check every 10 seconds
//    }
//
// =============================================================================
// STAMP CONSTRAINTS VERIFICATION
// =============================================================================
//
// SC-ZENOH-007: Zenoh health included in /health endpoint
//   ✓ FormatHealthCheckJson() provides JSON for HTTP response
//   ✓ CheckHealth() verifies connection status, latency, uptime
//   ✓ Includes all metrics: connected, session_id, latency, topics, messages
//
// SC-ZENOH-008: Container MUST NOT start if Zenoh unavailable
//   ✓ WaitForZenohAsync() blocks until connected or timeout
//   ✓ Returns StartupGateResult.Failed if connection fails
//   ✓ Returns StartupGateResult.Timeout after 30 seconds
//   ✓ Container can use result to decide whether to proceed or exit
//
// SC-CNT-015: Container startup gate integration
//   ✓ Provides both async and sync wait functions
//   ✓ JSON formatting for Elixir bridge compatibility
//   ✓ Timeout handling with configurable duration
//
// =============================================================================
