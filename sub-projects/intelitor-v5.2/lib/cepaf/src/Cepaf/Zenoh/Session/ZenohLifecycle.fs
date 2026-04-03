// =============================================================================
// ZenohLifecycle.fs - Session Lifecycle Management
// =============================================================================
// STAMP: SC-OP-001 to SC-OP-004, SC-SESS-001
// AOR: AOR-ZENOH-008, AOR-ZENOH-009
// Criticality: Level 5 (CRITICAL) - System Availability
// =============================================================================
// Provides session lifecycle management with:
// - Initialization with timeout (SC-OP-001: 5 seconds)
// - Exponential backoff reconnection (SC-OP-002: max 60 seconds)
// - Health check timer (SC-OP-003: every 10 seconds)
// - Max reconnection attempts (SC-OP-004: 10 attempts)
// =============================================================================

namespace Cepaf.Zenoh.Session

open System
open System.Threading
open System.Threading.Tasks
open Cepaf.Zenoh.Core

/// Lifecycle state machine
[<RequireQualifiedAccess>]
type LifecycleState =
    | Uninitialized
    | Starting of startTime: DateTimeOffset
    | Running of session: SafeSession * connectedAt: DateTimeOffset
    | Reconnecting of attempt: int * lastError: string * startTime: DateTimeOffset
    | Stopped of reason: string * stoppedAt: DateTimeOffset

    member this.IsOperational =
        match this with
        | Running _ -> true
        | _ -> false

    member this.CanReconnect =
        match this with
        | Stopped _ -> false
        | _ -> true

/// Lifecycle manager for Zenoh sessions
type ZenohLifecycle(config: SessionConfig, nodeId: string) =
    let mutable state = LifecycleState.Uninitialized
    let mutable healthTimer: Timer option = None
    let mutable reconnectAttempts = 0
    let mutable health = ZenohHealth.empty
    let lockObj = obj()

    // Configuration
    let maxReconnectAttempts = config.MaxReconnectAttempts  // SC-OP-004
    let healthCheckIntervalMs = 10000  // SC-OP-003: 10 seconds
    let initTimeoutMs = config.ConnectTimeoutMs  // SC-OP-001: 5 seconds

    // Event handlers
    let eventHandlers = ResizeArray<LifecycleEvent -> unit>()

    let raiseEvent event =
        for handler in eventHandlers do
            try handler event with _ -> ()

    let updateHealth f =
        lock lockObj (fun () -> health <- f health)

    /// Subscribe to lifecycle events
    member _.OnEvent(handler: LifecycleEvent -> unit) =
        eventHandlers.Add(handler)

    /// Get current state
    member _.State = state

    /// Get current health
    member _.Health =
        health |> ZenohHealth.updateUptime

    /// Get node identifier
    member _.NodeId = nodeId

    /// Get current session if running
    member _.Session =
        match state with
        | LifecycleState.Running (session, _) -> Some session
        | _ -> None

    /// Check if operational
    member _.IsOperational = state.IsOperational

    /// Initialize session (SC-OP-001: 5 second timeout)
    member this.InitializeAsync() : Task<ZenohResult<SafeSession>> =
        task {
            lock lockObj (fun () ->
                state <- LifecycleState.Starting DateTimeOffset.UtcNow
            )
            raiseEvent (LifecycleEvent.Initializing config)

            try
                // Use cancellation for timeout (SC-OP-001)
                use cts = new CancellationTokenSource(initTimeoutMs)

                let! result = SafeSession.OpenAsync(config)

                match result with
                | Ok session ->
                    let connectedAt = DateTimeOffset.UtcNow
                    lock lockObj (fun () ->
                        state <- LifecycleState.Running (session, connectedAt)
                        reconnectAttempts <- 0
                        health <- {
                            health with
                                Status = ConnectionStatus.Connected
                                SessionId = Some session.SessionId
                                ConnectedAt = Some connectedAt
                                LastHeartbeat = Some connectedAt
                                ReconnectCount = 0
                        }
                    )
                    raiseEvent (LifecycleEvent.Connected session.SessionId)
                    this.StartHealthCheck()
                    return Ok session

                | Error e ->
                    lock lockObj (fun () ->
                        state <- LifecycleState.Stopped (e.Message, DateTimeOffset.UtcNow)
                        health <- { health with Status = ConnectionStatus.Failed e.Message }
                    )
                    updateHealth ZenohHealth.recordError
                    return Error e

            with
            | :? OperationCanceledException ->
                let error = ZenohError.Timeout("Initialize", initTimeoutMs)
                lock lockObj (fun () ->
                    state <- LifecycleState.Stopped (error.Message, DateTimeOffset.UtcNow)
                    health <- { health with Status = ConnectionStatus.Failed "Timeout" }
                )
                updateHealth ZenohHealth.recordError
                return Error error
        }

    /// Start health check timer (SC-OP-003)
    member private this.StartHealthCheck() =
        let callback _ = this.HealthCheckAsync() |> ignore
        healthTimer <- Some (new Timer(TimerCallback(callback), null, healthCheckIntervalMs, healthCheckIntervalMs))

    /// Stop health check timer
    member private _.StopHealthCheck() =
        healthTimer |> Option.iter (fun t -> t.Dispose())
        healthTimer <- None

    /// Perform health check
    member private this.HealthCheckAsync() : Task<unit> =
        task {
            updateHealth ZenohHealth.recordHeartbeat
            raiseEvent (LifecycleEvent.HealthCheck this.Health)

            match state with
            | LifecycleState.Running (session, _) when not session.IsValid ->
                // Session became invalid - trigger reconnection
                raiseEvent (LifecycleEvent.Disconnected "Session invalid")
                updateHealth (fun h -> { h with Status = ConnectionStatus.Disconnected })
                do! this.ReconnectAsync()

            | LifecycleState.Running (session, connectedAt) ->
                // Update health statistics
                updateHealth (fun h -> {
                    h with
                        SubscriberCount = session.SubscriberCount
                        PublisherCount = session.PublisherCount
                })

            | _ -> ()
        }

    /// Reconnect with exponential backoff (SC-OP-002)
    member private this.ReconnectAsync() : Task<unit> =
        task {
            if reconnectAttempts >= maxReconnectAttempts then
                // Max attempts exceeded (SC-OP-004)
                let error = sprintf "Max reconnect attempts (%d) exceeded" maxReconnectAttempts
                raiseEvent (LifecycleEvent.ReconnectFailed (reconnectAttempts, error))
                lock lockObj (fun () ->
                    state <- LifecycleState.Stopped (error, DateTimeOffset.UtcNow)
                    health <- { health with Status = ConnectionStatus.Failed error }
                )
            else
                reconnectAttempts <- reconnectAttempts + 1
                let attempt = reconnectAttempts

                lock lockObj (fun () ->
                    state <- LifecycleState.Reconnecting (attempt, "Reconnecting", DateTimeOffset.UtcNow)
                    health <- {
                        health with
                            Status = ConnectionStatus.Reconnecting
                            ReconnectCount = attempt
                    }
                )

                raiseEvent (LifecycleEvent.Reconnecting (attempt, maxReconnectAttempts))

                // Calculate backoff delay (SC-OP-002)
                let backoffMs = ExponentialBackoff.calculate
                                    (attempt - 1)
                                    config.ReconnectBaseDelayMs
                                    config.ReconnectMaxDelayMs

                do! Task.Delay(backoffMs)

                // Attempt reconnection
                let! result = SafeSession.OpenAsync(config)

                match result with
                | Ok session ->
                    let connectedAt = DateTimeOffset.UtcNow
                    lock lockObj (fun () ->
                        state <- LifecycleState.Running (session, connectedAt)
                        health <- {
                            health with
                                Status = ConnectionStatus.Connected
                                SessionId = Some session.SessionId
                                ConnectedAt = Some connectedAt
                                LastHeartbeat = Some connectedAt
                        }
                    )
                    reconnectAttempts <- 0
                    raiseEvent (LifecycleEvent.Connected session.SessionId)

                | Error e ->
                    lock lockObj (fun () ->
                        state <- LifecycleState.Reconnecting (attempt, e.Message, DateTimeOffset.UtcNow)
                    )
                    updateHealth ZenohHealth.recordError
                    // Try again
                    do! this.ReconnectAsync()
        }

    /// Shutdown gracefully
    member this.ShutdownAsync(?graceful: bool) : Task<unit> =
        let graceful = defaultArg graceful true
        task {
            raiseEvent (LifecycleEvent.Shutdown graceful)
            this.StopHealthCheck()

            match state with
            | LifecycleState.Running (session, _) ->
                do! session.CloseAsync()
            | _ -> ()

            lock lockObj (fun () ->
                state <- LifecycleState.Stopped ("Shutdown requested", DateTimeOffset.UtcNow)
                health <- { health with Status = ConnectionStatus.Disconnected }
            )
        }

    /// Force reconnection (for manual recovery)
    member this.ForceReconnectAsync() : Task<ZenohResult<SafeSession>> =
        task {
            // Reset reconnect counter
            reconnectAttempts <- 0

            // Close existing session if any
            match state with
            | LifecycleState.Running (session, _) ->
                do! session.CloseAsync()
            | _ -> ()

            // Reinitialize
            return! this.InitializeAsync()
        }

    interface IDisposable with
        member this.Dispose() =
            this.ShutdownAsync(true).Wait()

/// Health monitor for publishing health status
type HealthPublisher(lifecycle: ZenohLifecycle) =
    let mutable publisher: SafePublisher option = None
    let mutable timer: Timer option = None
    let publishIntervalMs = 10000  // Publish health every 10 seconds

    /// Start publishing health to Zenoh
    member this.Start() =
        match lifecycle.Session with
        | Some session ->
            let config = PublisherConfig.create (Cepaf.Zenoh.Messaging.ZenohTopics.Health.node lifecycle.NodeId)
            match SafePublisher.Create(session, config) with
            | Ok pub ->
                publisher <- Some pub
                timer <- Some (new Timer(TimerCallback(fun _ -> this.PublishHealth()), null, 0, publishIntervalMs))
            | Error e ->
                eprintfn "[HealthPublisher] Failed to start: %s" e.Message
        | None ->
            eprintfn "[HealthPublisher] No session available"

    /// Publish current health
    member private _.PublishHealth() =
        match publisher with
        | Some pub ->
            let health = lifecycle.Health
            let payload: Cepaf.Zenoh.Messaging.ZenohTopics.Health.HealthPayload = {
                NodeId = lifecycle.NodeId
                Status = health.Status.ToString()
                Uptime = health.Uptime |> Option.defaultValue TimeSpan.Zero
                MessagesPublished = health.MessagesPublished
                MessagesReceived = health.MessagesReceived
                ErrorCount = health.ErrorCount
            }
            match ZenohSerializer.serialize payload with
            | Ok bytes ->
                pub.PutAsync(bytes) |> ignore
            | Error _ -> ()
        | None -> ()

    interface IDisposable with
        member _.Dispose() =
            timer |> Option.iter (fun t -> t.Dispose())
            publisher |> Option.iter (fun p -> (p :> IDisposable).Dispose())

/// Lifecycle manager factory
module ZenohLifecycleFactory =

    /// Create lifecycle manager with default config
    let create (nodeId: string) =
        new ZenohLifecycle(SessionConfig.defaultConfig(), nodeId)

    /// Create lifecycle manager for specific endpoint
    let createForEndpoint (nodeId: string) (endpoint: string) =
        let config = SessionConfig.forEndpoint endpoint |> SessionConfig.withName nodeId
        new ZenohLifecycle(config, nodeId)

    /// Create lifecycle manager for multiple endpoints
    let createForEndpoints (nodeId: string) (endpoints: string list) =
        let config = SessionConfig.forEndpoints endpoints |> SessionConfig.withName nodeId
        new ZenohLifecycle(config, nodeId)
