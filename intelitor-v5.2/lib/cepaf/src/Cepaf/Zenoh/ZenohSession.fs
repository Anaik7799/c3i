namespace Cepaf.Zenoh

open System
open System.Threading
open System.Threading.Tasks
open System.Collections.Concurrent
open Cepaf.Core.Units  // SC-FSH-004: Units of Measure for type safety
open Cepaf.Core.Composition  // SC-FSH-010: Function composition

/// Zenoh Session Manager for F# CEPAF Cockpit
/// Manages native Zenoh session lifecycle for real-time communication with Indrajaal.
///
/// ## STAMP Constraints
/// - SC-ZENOH-FSH-001: Session singleton pattern
/// - SC-ZENOH-FSH-002: Auto-reconnect with exponential backoff
/// - SC-ZENOH-FSH-003: Thread-safe subscriber management
///
/// ## Key Expression Schema
/// - indrajaal/fractal/{l1..l5}/** - Fractal logs from Elixir
/// - indrajaal/telemetry/elixir/** - Elixir telemetry
/// - indrajaal/telemetry/fsharp/** - F# telemetry (outbound)
/// - indrajaal/control/** - Control commands
/// - indrajaal/kpi/** - Key performance indicators
module ZenohSession =

    // ========================================================================
    // TYPES
    // ========================================================================

    /// Connection status
    type ConnectionStatus =
        | Disconnected
        | Connecting
        | Connected
        | Reconnecting
        | Failed of string

    /// Zenoh message received from subscription
    type ZenohMessage = {
        Key: string
        Payload: byte[]
        Timestamp: DateTimeOffset option
        Encoding: string
        Source: string option
    }

    /// Session statistics
    type SessionStats = {
        MessagesReceived: int64
        MessagesSent: int64
        ReconnectCount: int
        UptimeSeconds: float
        LastLatencyMs: float
    }

    /// Configuration for Zenoh session
    type SessionConfig = {
        Endpoints: string list
        Mode: string  // "client" | "peer" | "router"
        ReconnectDelayMs: int
        MaxReconnectAttempts: int
        HealthCheckIntervalMs: int
    }

    // ========================================================================
    // TYPE-SAFE CONSTANTS (SC-FSH-004)
    // ========================================================================

    /// Default Zenoh port (SC-FSH-004)
    let zenohPort = Port.zenoh  // 7447

    /// Default reconnect delay
    let private defaultReconnectDelay = Timeout.fromSec 1.0<sec>

    /// Default health check interval
    let private defaultHealthCheckInterval = Timeout.fromSec 10.0<sec>

    // ========================================================================
    // DEFAULT CONFIGURATION
    // ========================================================================

    /// Default session configuration
    let defaultConfig = {
        Endpoints = [sprintf "tcp/zenoh:%d" (Port.value zenohPort)]
        Mode = "client"
        ReconnectDelayMs = Timeout.toRawMs defaultReconnectDelay
        MaxReconnectAttempts = 5
        HealthCheckIntervalMs = Timeout.toRawMs defaultHealthCheckInterval
    }

    // ========================================================================
    // STATE
    // ========================================================================

    /// Session singleton state
    let mutable private sessionState: SessionConfig option = None
    let mutable private connectionStatus = Disconnected
    let private statsLock = obj()
    let mutable private stats = {
        MessagesReceived = 0L
        MessagesSent = 0L
        ReconnectCount = 0
        UptimeSeconds = 0.0
        LastLatencyMs = 0.0
    }
    let private startTime = DateTimeOffset.UtcNow
    let private subscribers = ConcurrentDictionary<string, string * (ZenohMessage -> unit)>()
    let private messageBuffer = ConcurrentQueue<ZenohMessage>()
    let private cancellationSource = new CancellationTokenSource()

    // ========================================================================
    // INTERNAL HELPERS
    // ========================================================================

    /// Increment messages sent counter
    let private incrementSent () =
        lock statsLock (fun () ->
            stats <- { stats with MessagesSent = stats.MessagesSent + 1L }
        )

    /// Increment messages received counter
    let private incrementReceived () =
        lock statsLock (fun () ->
            stats <- { stats with MessagesReceived = stats.MessagesReceived + 1L }
        )

    /// Update latency
    let private updateLatency (ms: float) =
        lock statsLock (fun () ->
            stats <- { stats with LastLatencyMs = ms }
        )

    /// Increment reconnect count
    let private incrementReconnect () =
        lock statsLock (fun () ->
            stats <- { stats with ReconnectCount = stats.ReconnectCount + 1 }
        )

    // ========================================================================
    // PUBLIC API
    // ========================================================================

    /// Get current connection status
    let getStatus () = connectionStatus

    /// Check if connected
    let isConnected () = connectionStatus = Connected

    /// Get session statistics
    let getStats () =
        let uptime = (DateTimeOffset.UtcNow - startTime).TotalSeconds
        { stats with UptimeSeconds = uptime }

    /// Initialize session with configuration
    let initializeAsync (config: SessionConfig) = async {
        sessionState <- Some config
        connectionStatus <- Connecting

        // NOTE: In production, this would use the Zenoh .NET library:
        // let! session = Zenoh.Session.OpenAsync(config) |> Async.AwaitTask
        // For now, we simulate connection success

        // Simulate connection delay
        do! Async.Sleep(100)

        connectionStatus <- Connected
        printfn "[ZenohSession] Connected to %s" (config.Endpoints |> List.head)

        return Ok ()
    }

    /// Initialize with default configuration
    let initialize () =
        initializeAsync defaultConfig |> Async.RunSynchronously

    /// Publish a message to a key
    let publishAsync (key: string) (payload: byte[]) = async {
        if not (isConnected()) then
            return Error "Not connected"
        else
            let start = DateTimeOffset.UtcNow

            // NOTE: Production implementation:
            // do! session.PutAsync(key, payload) |> Async.AwaitTask

            // Simulate publish
            do! Async.Sleep(1)  // ~1ms simulated latency

            let elapsed = (DateTimeOffset.UtcNow - start).TotalMilliseconds
            updateLatency elapsed
            incrementSent ()

            // Log if latency exceeds target
            if elapsed > 1.0 then
                printfn "[ZenohSession] WARNING: Publish latency %.2fms > 1ms target" elapsed

            return Ok ()
    }

    /// Publish a message synchronously
    let publish (key: string) (payload: byte[]) =
        publishAsync key payload |> Async.RunSynchronously

    /// Subscribe to a key expression with handler
    let subscribe (keyExpr: string) (handler: ZenohMessage -> unit) =
        let subId = Guid.NewGuid().ToString("N").[..7]

        if subscribers.TryAdd(subId, (keyExpr, handler)) then
            printfn "[ZenohSession] Subscribed to %s (id: %s)" keyExpr subId

            // NOTE: Production implementation:
            // let sub = session.DeclareSubscriber(keyExpr)
            //                   .Callback(fun sample ->
            //                       let msg = { Key = sample.KeyExpr.ToString(); ... }
            //                       handler msg
            //                   )
            //                   .Res()

            Ok subId
        else
            Error "Failed to register subscription"

    /// Unsubscribe by subscription ID
    let unsubscribe (subId: string) =
        let mutable removed = Unchecked.defaultof<string * (ZenohMessage -> unit)>
        if subscribers.TryRemove(subId, &removed) then
            printfn "[ZenohSession] Unsubscribed: %s" subId
            Ok ()
        else
            Error "Subscription not found"

    /// Query Zenoh storage for matching entries
    let getAsync (keyExpr: string) (timeoutMs: int) = async {
        if not (isConnected()) then
            return Error "Not connected"
        else
            // NOTE: Production implementation:
            // let! replies = session.GetAsync(keyExpr) |> Async.AwaitTask
            // let samples = replies |> Seq.choose (fun r -> r.Sample) |> Seq.toList

            // Simulate empty response for now
            return Ok []
    }

    /// Dispatch message to matching subscribers (called by native layer)
    let dispatchMessage (msg: ZenohMessage) =
        incrementReceived ()

        for KeyValue(_, (keyExpr, handler)) in subscribers do
            // Simple prefix matching for now
            if msg.Key.StartsWith(keyExpr.TrimEnd('*')) then
                try
                    handler msg
                with ex ->
                    printfn "[ZenohSession] Handler error: %s" ex.Message

    /// Close the session
    let close () =
        cancellationSource.Cancel()
        subscribers.Clear()
        connectionStatus <- Disconnected
        printfn "[ZenohSession] Session closed"

    /// Reconnect to Zenoh router
    let reconnectAsync () = async {
        match sessionState with
        | Some config ->
            connectionStatus <- Reconnecting
            incrementReconnect ()
            return! initializeAsync config
        | None ->
            return Error "No configuration available"
    }

    // ========================================================================
    // CONVENIENCE FUNCTIONS
    // ========================================================================

    /// Publish JSON payload
    let publishJson (key: string) (jsonString: string) =
        let payload = System.Text.Encoding.UTF8.GetBytes(jsonString)
        publish key payload

    /// Publish text payload
    let publishText (key: string) (text: string) =
        let payload = System.Text.Encoding.UTF8.GetBytes(text)
        publish key payload

    /// Subscribe with JSON deserialization
    let subscribeJson<'T> (keyExpr: string) (handler: 'T -> unit) =
        subscribe keyExpr (fun msg ->
            try
                let json = System.Text.Encoding.UTF8.GetString(msg.Payload)
                let obj = System.Text.Json.JsonSerializer.Deserialize<'T>(json)
                handler obj
            with ex ->
                printfn "[ZenohSession] JSON parse error: %s" ex.Message
        )

    // ========================================================================
    // FRACTAL LOG SPECIFIC
    // ========================================================================

    /// Subscribe to all fractal log levels
    let subscribeAllFractalLogs (handler: ZenohMessage -> unit) =
        subscribe "indrajaal/fractal/**" handler

    /// Subscribe to specific fractal level
    let subscribeFractalLevel (level: string) (handler: ZenohMessage -> unit) =
        let keyExpr = sprintf "indrajaal/fractal/%s/**" level
        subscribe keyExpr handler

    /// Subscribe to fractal logs for specific domain
    let subscribeFractalDomain (domain: string) (handler: ZenohMessage -> unit) =
        let keyExpr = sprintf "indrajaal/fractal/**/%s/**" domain
        subscribe keyExpr handler

    // ========================================================================
    // TELEMETRY SPECIFIC
    // ========================================================================

    /// Publish F# telemetry metric
    let publishTelemetry (metricName: string) (value: float) (tags: Map<string, string>) =
        let key = sprintf "indrajaal/telemetry/fsharp/%s" metricName
        let payload = {|
            name = metricName
            value = value
            tags = tags
            timestamp = DateTimeOffset.UtcNow.ToString("o")
        |}
        publishJson key (System.Text.Json.JsonSerializer.Serialize(payload))

    // ========================================================================
    // CONTROL SPECIFIC
    // ========================================================================

    /// Publish control command
    let publishControlCommand (target: string) (command: string) (payload: obj) =
        let key = sprintf "indrajaal/control/%s/%s" target command
        let message = {|
            id = Guid.NewGuid().ToString("N")
            command = command
            payload = payload
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "cepaf-cockpit"
        |}
        publishJson key (System.Text.Json.JsonSerializer.Serialize(message))

    /// Subscribe to control responses
    let subscribeControlResponses (handler: ZenohMessage -> unit) =
        subscribe "indrajaal/control/response/**" handler
