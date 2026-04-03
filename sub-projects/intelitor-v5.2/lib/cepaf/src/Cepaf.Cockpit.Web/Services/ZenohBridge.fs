namespace Cepaf.Cockpit.Web.Services

open System
open System.Net.WebSockets
open System.Text
open System.Text.Json
open System.Threading
open System.Threading.Tasks
open Cepaf.Cockpit.Domain

/// <summary>
/// ZenohBridge - WebSocket bridge to Zenoh router for real-time telemetry
///
/// STAMP Constraints:
/// - SC-ZENOH-001: Zenoh NIF MUST be loaded on ALL nodes (CRITICAL)
/// - SC-ZENOH-002: Zenoh router MUST be reachable from ALL app nodes (CRITICAL)
/// - SC-ZENOH-004: Telemetry publishing latency < 100ms (HIGH)
/// - SC-BRIDGE-001: Message Ordering - ZenohLiveViewBridge MUST preserve FIFO ordering
/// - SC-BRIDGE-002: Latency Budget - Bridge operations MUST complete within 50ms
///
/// AOR Rules:
/// - AOR-ZENOH-003: ALWAYS include zenoh-router in compose dependencies
/// - AOR-ZENOH-005: ALERT on Zenoh disconnection > 30 seconds
/// - AOR-ZENOH-006: RETRY Zenoh connection with exponential backoff
///
/// Architecture Notes:
/// - Browser cannot directly use Zenoh NIF (native code)
/// - WebSocket bridge via cepaf-bridge service (port 9876)
/// - Async-compatible for Bolero Elmish update loop
/// </summary>
module ZenohBridge =

    /// Zenoh topic subscription
    type ZenohTopic =
        | Health of nodeId: string
        | Metrics of nodeId: string
        | Logs of nodeId: string
        | PrajnaKpi
        | SentinelThreats
        | ClusterEvents
        | Custom of topic: string

    /// Bridge connection state
    type ConnectionState =
        | Disconnected
        | Connecting
        | Connected of sessionId: string
        | Failed of error: string

    /// Telemetry message from Zenoh
    type TelemetryMessage = {
        Topic: string
        Payload: string
        Timestamp: DateTime
        NodeId: string option
    }

    /// WebSocket bridge client
    type ZenohBridgeClient(bridgeUrl: string) =
        let mutable ws: ClientWebSocket option = None
        let mutable connectionState = Disconnected
        let mutable subscriptions: Set<string> = Set.empty
        let mutable messageHandlers: Map<string, TelemetryMessage -> unit> = Map.empty
        let mutable reconnectAttempts = 0

        /// Convert topic to key expression
        let topicToKeyExpr = function
            | Health nodeId -> $"indrajaal/health/{nodeId}"
            | Metrics nodeId -> $"indrajaal/metrics/{nodeId}/**"
            | Logs nodeId -> $"indrajaal/logs/{nodeId}/**"
            | PrajnaKpi -> "indrajaal/prajna/kpi"
            | SentinelThreats -> "indrajaal/sentinel/threats"
            | ClusterEvents -> "indrajaal/cluster/events"
            | Custom topic -> topic

        /// Exponential backoff delay
        let getReconnectDelay attempts =
            let baseDelay = 1000.0 // 1 second
            let maxDelay = 30000.0 // 30 seconds
            Math.Min(baseDelay * Math.Pow(2.0, float attempts), maxDelay)
            |> int

        /// Connect to WebSocket bridge
        member this.ConnectAsync(ct: CancellationToken) = task {
            try
                connectionState <- Connecting
                let client = new ClientWebSocket()
                do! client.ConnectAsync(Uri(bridgeUrl), ct)
                ws <- Some client
                connectionState <- Connected $"session-{Guid.NewGuid()}"
                reconnectAttempts <- 0

                // Start message receive loop
                this.StartReceiveLoop(client, ct) |> ignore

                return Ok connectionState
            with ex ->
                connectionState <- Failed ex.Message
                return Error ex.Message
        }

        /// Reconnect with exponential backoff (AOR-ZENOH-006)
        member this.ReconnectAsync(ct: CancellationToken) = task {
            reconnectAttempts <- reconnectAttempts + 1
            let delay = getReconnectDelay reconnectAttempts

            printfn $"[ZenohBridge] Reconnect attempt {reconnectAttempts} after {delay}ms delay"
            do! Task.Delay(delay, ct)

            return! this.ConnectAsync(ct)
        }

        /// Subscribe to Zenoh topic
        member this.SubscribeAsync(topic: ZenohTopic, handler: TelemetryMessage -> unit, ct: CancellationToken) = task {
            let keyExpr = topicToKeyExpr topic
            subscriptions <- subscriptions.Add(keyExpr)
            messageHandlers <- messageHandlers.Add(keyExpr, handler)

            match ws with
            | Some client when client.State = WebSocketState.Open ->
                let subscribeMsg = JsonSerializer.Serialize({| action = "subscribe"; topic = keyExpr |})
                let bytes = Encoding.UTF8.GetBytes(subscribeMsg)
                do! client.SendAsync(ArraySegment(bytes), WebSocketMessageType.Text, true, ct)
                return Ok keyExpr
            | _ ->
                return Error "WebSocket not connected"
        }

        /// Unsubscribe from topic
        member this.UnsubscribeAsync(topic: ZenohTopic, ct: CancellationToken) = task {
            let keyExpr = topicToKeyExpr topic
            subscriptions <- subscriptions.Remove(keyExpr)
            messageHandlers <- messageHandlers.Remove(keyExpr)

            match ws with
            | Some client when client.State = WebSocketState.Open ->
                let unsubMsg = JsonSerializer.Serialize({| action = "unsubscribe"; topic = keyExpr |})
                let bytes = Encoding.UTF8.GetBytes(unsubMsg)
                do! client.SendAsync(ArraySegment(bytes), WebSocketMessageType.Text, true, ct)
                return Ok ()
            | _ ->
                return Error "WebSocket not connected"
        }

        /// Publish to Zenoh topic
        member this.PublishAsync(topic: ZenohTopic, payload: string, ct: CancellationToken) = task {
            let keyExpr = topicToKeyExpr topic

            match ws with
            | Some client when client.State = WebSocketState.Open ->
                let pubMsg = JsonSerializer.Serialize({|
                    action = "publish"
                    topic = keyExpr
                    payload = payload
                    timestamp = DateTime.UtcNow
                |})
                let bytes = Encoding.UTF8.GetBytes(pubMsg)

                // SC-BRIDGE-002: Latency Budget - operations < 50ms
                let startTime = DateTime.UtcNow
                do! client.SendAsync(ArraySegment(bytes), WebSocketMessageType.Text, true, ct)
                let latency = (DateTime.UtcNow - startTime).TotalMilliseconds

                if latency > 50.0 then
                    printfn $"[ZenohBridge] WARNING: Publish latency {latency:F2}ms exceeds 50ms budget (SC-BRIDGE-002)"

                return Ok latency
            | _ ->
                return Error "WebSocket not connected"
        }

        /// Receive loop for WebSocket messages (SC-BRIDGE-001: FIFO ordering)
        member private this.StartReceiveLoop(client: ClientWebSocket, ct: CancellationToken) = task {
            let buffer = Array.zeroCreate<byte> (64 * 1024) // 64KB buffer
            let mutable receiving = true

            while receiving && not ct.IsCancellationRequested do
                try
                    let! result = client.ReceiveAsync(ArraySegment(buffer), ct)

                    if result.MessageType = WebSocketMessageType.Close then
                        receiving <- false
                        connectionState <- Disconnected
                        printfn "[ZenohBridge] WebSocket closed by server"

                        // AOR-ZENOH-005: Alert on disconnection > 30s
                        // (Handled by UI layer timeout monitoring)

                    elif result.MessageType = WebSocketMessageType.Text then
                        let json = Encoding.UTF8.GetString(buffer, 0, result.Count)
                        let msg = JsonSerializer.Deserialize<TelemetryMessage>(json)

                        // Dispatch to registered handlers (FIFO order preserved)
                        messageHandlers
                        |> Map.tryFind msg.Topic
                        |> Option.iter (fun handler -> handler msg)

                with ex ->
                    printfn $"[ZenohBridge] Receive error: {ex.Message}"
                    receiving <- false
                    connectionState <- Failed ex.Message

                    // Trigger reconnect
                    this.ReconnectAsync(ct) |> ignore
        }

        /// Get current connection state
        member this.State = connectionState

        /// Check if connected
        member this.IsConnected =
            match connectionState with
            | Connected _ -> true
            | _ -> false

        /// Disconnect and cleanup
        member this.DisconnectAsync(ct: CancellationToken) = task {
            match ws with
            | Some client ->
                if client.State = WebSocketState.Open then
                    do! client.CloseAsync(WebSocketCloseStatus.NormalClosure, "Client disconnect", ct)
                client.Dispose()
                ws <- None
            | None -> ()

            connectionState <- Disconnected
            subscriptions <- Set.empty
            messageHandlers <- Map.empty
        }

        interface IDisposable with
            member this.Dispose() =
                match ws with
                | Some client ->
                    client.Dispose()
                    ws <- None
                | None -> ()

    /// Factory for creating bridge client with default URL
    let createClient () =
        // Default to cepaf-bridge service on port 9876
        let bridgeUrl =
            match Environment.GetEnvironmentVariable("ZENOH_BRIDGE_URL") with
            | null | "" -> "ws://localhost:9876/zenoh"
            | url -> url

        new ZenohBridgeClient(bridgeUrl)

    /// Health check for Zenoh connectivity (SC-ZENOH-002)
    let checkConnectivity (client: ZenohBridgeClient) =
        match client.State with
        | Connected sessionId -> Ok $"Connected ({sessionId})"
        | Connecting -> Error "Connection in progress"
        | Disconnected -> Error "Not connected"
        | Failed err -> Error $"Connection failed: {err}"
