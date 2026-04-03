/// Cepaf.IndrajaalTest.WebSocketClient
/// WebSocket and Phoenix Channel client for real-time interface testing
///
/// STAMP Constraints:
/// - SC-WS-001: WebSocket connections must authenticate
/// - SC-WS-002: Channel subscriptions must respect tenant boundaries
/// - SC-WS-003: Heartbeat must be maintained
module Cepaf.IndrajaalTest.WebSocketClient

open System
open System.Net.WebSockets
open System.Text
open System.Text.Json
open System.Threading
open Cepaf.IndrajaalTest.Types

// =============================================================================
// Phoenix Protocol Types
// =============================================================================

/// Phoenix message structure
type PhoenixMessage = {
    topic: string
    event: string
    payload: Map<string, obj>
    ref: string option
    join_ref: string option
}

/// Phoenix reply structure
type PhoenixReply = {
    response: Map<string, obj>
    status: string
}

// =============================================================================
// WebSocket Client
// =============================================================================

/// WebSocket connection state
type WebSocketState =
    | Disconnected
    | Connecting
    | Connected
    | Reconnecting
    | Closed

/// Phoenix channel client
type PhoenixClient = {
    Socket: ClientWebSocket
    Url: string
    Token: string option
    State: WebSocketState
    JoinedChannels: Map<string, string> // topic -> join_ref
    MessageRef: int ref
    CancellationToken: CancellationTokenSource
}

/// Create a new Phoenix client
let createClient (wsUrl: string) (token: string option) : PhoenixClient = {
    Socket = new ClientWebSocket()
    Url = wsUrl
    Token = token
    State = Disconnected
    JoinedChannels = Map.empty
    MessageRef = ref 0
    CancellationToken = new CancellationTokenSource()
}

/// Generate next message ref
let nextRef (client: PhoenixClient) : string =
    let current = Interlocked.Increment(client.MessageRef)
    string current

/// Build WebSocket URL with token
let buildWsUrl (baseUrl: string) (token: string option) : string =
    match token with
    | Some t -> sprintf "%s?token=%s&vsn=2.0.0" baseUrl t
    | None -> sprintf "%s?vsn=2.0.0" baseUrl

/// Serialize Phoenix message to JSON
let serializeMessage (msg: PhoenixMessage) : string =
    // Phoenix expects array format: [join_ref, ref, topic, event, payload]
    let joinRef = msg.join_ref |> Option.map box |> Option.defaultValue (box null)
    let ref = msg.ref |> Option.map box |> Option.defaultValue (box null)
    let arr = [| joinRef; ref; box msg.topic; box msg.event; box msg.payload |]
    JsonSerializer.Serialize(arr)

/// Parse Phoenix message from JSON
let parseMessage (json: string) : Result<PhoenixMessage, string> =
    try
        let arr = JsonSerializer.Deserialize<obj[]>(json)
        if arr.Length >= 5 then
            let joinRef =
                match arr.[0] with
                | null -> None
                | :? string as s -> Some s
                | v -> Some (string v)
            let ref =
                match arr.[1] with
                | null -> None
                | :? string as s -> Some s
                | v -> Some (string v)
            let topic = string arr.[2]
            let event = string arr.[3]
            let payload =
                match arr.[4] with
                | :? JsonElement as elem ->
                    elem.EnumerateObject()
                    |> Seq.map (fun p -> p.Name, p.Value :> obj)
                    |> Map.ofSeq
                | _ -> Map.empty

            Ok {
                topic = topic
                event = event
                payload = payload
                ref = ref
                join_ref = joinRef
            }
        else
            Error "Invalid message format"
    with ex ->
        Error (sprintf "Parse error: %s" ex.Message)

// =============================================================================
// Connection Management
// =============================================================================

/// Connect to Phoenix socket
let connect (client: PhoenixClient) : Async<Result<PhoenixClient, TestError>> =
    async {
        try
            let url = buildWsUrl client.Url client.Token
            let uri = Uri(url)
            do! client.Socket.ConnectAsync(uri, client.CancellationToken.Token) |> Async.AwaitTask
            return Ok { client with State = Connected }
        with ex ->
            return Error (ConnectionError (sprintf "WebSocket connection failed: %s" ex.Message))
    }

/// Send message over WebSocket
let sendMessage (client: PhoenixClient) (msg: PhoenixMessage) : Async<Result<unit, TestError>> =
    async {
        try
            if client.Socket.State = WebSocketState.Open then
                let json = serializeMessage msg
                let bytes = Encoding.UTF8.GetBytes(json)
                let segment = ArraySegment<byte>(bytes)
                do! client.Socket.SendAsync(segment, WebSocketMessageType.Text, true, client.CancellationToken.Token)
                    |> Async.AwaitTask
                return Ok ()
            else
                return Error (ConnectionError "WebSocket is not open")
        with ex ->
            return Error (ConnectionError (sprintf "Send failed: %s" ex.Message))
    }

/// Receive message from WebSocket
let receiveMessage (client: PhoenixClient) (timeout: TimeSpan) : Async<Result<PhoenixMessage, TestError>> =
    async {
        try
            let buffer = Array.zeroCreate<byte> 8192
            let segment = ArraySegment<byte>(buffer)

            use cts = new CancellationTokenSource(timeout)
            use linkedCts = CancellationTokenSource.CreateLinkedTokenSource(cts.Token, client.CancellationToken.Token)

            let! result = client.Socket.ReceiveAsync(segment, linkedCts.Token) |> Async.AwaitTask

            if result.MessageType = WebSocketMessageType.Close then
                return Error (ConnectionError "WebSocket closed by server")
            else
                let json = Encoding.UTF8.GetString(buffer, 0, result.Count)
                match parseMessage json with
                | Ok msg -> return Ok msg
                | Error err -> return Error (ParseError err)
        with
        | :? OperationCanceledException ->
            return Error (TimeoutError ("Receive message", timeout))
        | ex ->
            return Error (ConnectionError (sprintf "Receive failed: %s" ex.Message))
    }

/// Close WebSocket connection
let disconnect (client: PhoenixClient) : Async<unit> =
    async {
        try
            if client.Socket.State = WebSocketState.Open then
                do! client.Socket.CloseAsync(
                    WebSocketCloseStatus.NormalClosure,
                    "Test complete",
                    CancellationToken.None) |> Async.AwaitTask
            client.CancellationToken.Cancel()
        with _ -> ()
    }

// =============================================================================
// Channel Operations
// =============================================================================

/// Join a Phoenix channel
let joinChannel (client: PhoenixClient) (topic: string) (payload: Map<string, obj>) : Async<Result<ChannelJoinResult, TestError>> =
    async {
        let ref = nextRef client
        let joinRef = ref

        let msg: PhoenixMessage = {
            topic = topic
            event = "phx_join"
            payload = payload
            ref = Some ref
            join_ref = Some joinRef
        }

        match! sendMessage client msg with
        | Error err -> return Error err
        | Ok () ->
            // Wait for join reply
            match! receiveMessage client (TimeSpan.FromSeconds(10.0)) with
            | Error err -> return Error err
            | Ok reply ->
                if reply.event = "phx_reply" then
                    let status =
                        reply.payload
                        |> Map.tryFind "status"
                        |> Option.map string
                        |> Option.defaultValue ""

                    if status = "ok" then
                        let response =
                            reply.payload
                            |> Map.tryFind "response"
                            |> Option.map (fun r ->
                                match r with
                                | :? JsonElement as elem ->
                                    elem.EnumerateObject()
                                    |> Seq.map (fun p -> p.Name, p.Value :> obj)
                                    |> Map.ofSeq
                                | _ -> Map.empty)
                            |> Option.defaultValue Map.empty
                        return Ok (Joined response)
                    else
                        let reason =
                            reply.payload
                            |> Map.tryFind "response"
                            |> Option.map string
                            |> Option.defaultValue "Unknown reason"
                        return Ok (Denied reason)
                else
                    return Ok Timeout
    }

/// Leave a Phoenix channel
let leaveChannel (client: PhoenixClient) (topic: string) : Async<Result<unit, TestError>> =
    async {
        let ref = nextRef client
        let joinRef =
            client.JoinedChannels
            |> Map.tryFind topic

        let msg: PhoenixMessage = {
            topic = topic
            event = "phx_leave"
            payload = Map.empty
            ref = Some ref
            join_ref = joinRef
        }

        return! sendMessage client msg
    }

/// Send event to channel
let sendEvent (client: PhoenixClient) (topic: string) (event: string) (payload: Map<string, obj>) : Async<Result<unit, TestError>> =
    async {
        let ref = nextRef client
        let joinRef =
            client.JoinedChannels
            |> Map.tryFind topic

        let msg: PhoenixMessage = {
            topic = topic
            event = event
            payload = payload
            ref = Some ref
            join_ref = joinRef
        }

        return! sendMessage client msg
    }

/// Send heartbeat
let heartbeat (client: PhoenixClient) : Async<Result<unit, TestError>> =
    async {
        let ref = nextRef client

        let msg: PhoenixMessage = {
            topic = "phoenix"
            event = "heartbeat"
            payload = Map.empty
            ref = Some ref
            join_ref = None
        }

        return! sendMessage client msg
    }

// =============================================================================
// Test Helpers
// =============================================================================

/// Wait for specific event
let waitForEvent (client: PhoenixClient) (expectedEvent: string) (timeout: TimeSpan) : Async<Result<PhoenixMessage, TestError>> =
    let rec loop (remaining: TimeSpan) =
        async {
            if remaining <= TimeSpan.Zero then
                return Error (TimeoutError (sprintf "Waiting for event '%s'" expectedEvent, timeout))
            else
                let startTime = DateTime.UtcNow
                match! receiveMessage client (min remaining (TimeSpan.FromSeconds(1.0))) with
                | Ok msg when msg.event = expectedEvent ->
                    return Ok msg
                | Ok _ ->
                    // Wrong event, keep waiting
                    let elapsed = DateTime.UtcNow - startTime
                    return! loop (remaining - elapsed)
                | Error (TimeoutError _) ->
                    // Timeout on this attempt, keep waiting
                    let elapsed = DateTime.UtcNow - startTime
                    return! loop (remaining - elapsed)
                | Error err ->
                    return Error err
        }

    loop timeout

/// Collect events for duration
let collectEvents (client: PhoenixClient) (duration: TimeSpan) : Async<PhoenixMessage list> =
    let rec loop (remaining: TimeSpan) (acc: PhoenixMessage list) =
        async {
            if remaining <= TimeSpan.Zero then
                return List.rev acc
            else
                let startTime = DateTime.UtcNow
                match! receiveMessage client (min remaining (TimeSpan.FromMilliseconds(100.0))) with
                | Ok msg ->
                    let elapsed = DateTime.UtcNow - startTime
                    return! loop (remaining - elapsed) (msg :: acc)
                | Error _ ->
                    let elapsed = DateTime.UtcNow - startTime
                    return! loop (remaining - elapsed) acc
        }

    loop duration []
