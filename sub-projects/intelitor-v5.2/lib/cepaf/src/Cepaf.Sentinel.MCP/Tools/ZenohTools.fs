namespace Cepaf.Sentinel.MCP.Tools

open System
open System.Text
open System.Text.Json
open Cepaf.Zenoh.Core
open Cepaf.Sentinel.MCP.Protocol

/// MCP tool definitions for Zenoh pub/sub — optimised for token economy.
///
/// Consolidates 10 granular tools into 4 sharp ones (MCP best practice):
///   - zenoh_session: Open/close/stats via action enum
///   - zenoh_pub: Publish a message (single-purpose, no enum needed)
///   - zenoh_sub: Subscribe/poll/unsubscribe via action enum
///   - zenoh_query: Synchronous get + diagnostics via action enum
///
/// STAMP: SC-ZEN-001 (Zenoh unified IPC), SC-ZENOH-FFI-001 to SC-ZENOH-FFI-050
/// AOR: AOR-FFI-001 (validated pointers), AOR-ZTEST-004 (async publishing)
module ZenohTools =

    // ═══════════════════════════════════════════════════════════════════
    // SCHEMA HELPERS
    // ═══════════════════════════════════════════════════════════════════

    let private mkSchema (props: (string * obj) list) (required: string list) : obj =
        {| ``type`` = "object"
           properties = props |> Map.ofList
           required = required |}

    let private stringProp desc : obj =
        {| ``type`` = "string"; description = desc |} :> obj

    let private enumProp desc (values: string list) : obj =
        {| ``type`` = "string"; description = desc; ``enum`` = values |} :> obj

    let private intProp desc defaultVal : obj =
        {| ``type`` = "integer"; description = desc; ``default`` = defaultVal |} :> obj

    // ═══════════════════════════════════════════════════════════════════
    // TOOL DEFINITIONS (4 tools, enum-driven)
    // ═══════════════════════════════════════════════════════════════════

    let toolDefinitions : McpProtocol.ToolDefinition list = [
        { Name = "zenoh_session"
          Description = "Manage native Zenoh session lifecycle. Must open before pub/sub/query."
          InputSchema = mkSchema
            [ "action", enumProp "Session action" [ "open"; "close"; "stats" ]
              "endpoints", stringProp "Comma-separated Zenoh router endpoints (open only, default: tcp/localhost:7447)"
              "mode", enumProp "Session mode (open only)" [ "client"; "peer" ] ]
            [ "action" ] }

        { Name = "zenoh_pub"
          Description = "Publish a UTF-8 message to a Zenoh key expression."
          InputSchema = mkSchema
            [ "key", stringProp "Zenoh key expression (e.g. indrajaal/test/hello)"
              "payload", stringProp "Message payload (UTF-8 string)" ]
            [ "key"; "payload" ] }

        { Name = "zenoh_sub"
          Description = "Manage Zenoh subscriptions: subscribe to topics, poll messages, or unsubscribe."
          InputSchema = mkSchema
            [ "action", enumProp "Subscription action" [ "subscribe"; "poll"; "unsubscribe" ]
              "key", stringProp "Key expression pattern (subscribe only, e.g. indrajaal/**)"
              "id", stringProp "Subscription ID (poll/unsubscribe only, returned by subscribe)"
              "limit", intProp "Max messages to retrieve (poll only, 1-100)" 10 ]
            [ "action" ] }

        { Name = "zenoh_query"
          Description = "Query Zenoh key expressions or run diagnostics (metrics, formal invariant checks)."
          InputSchema = mkSchema
            [ "action", enumProp "Query action" [ "get"; "metrics"; "verify" ]
              "key", stringProp "Key expression (get only)"
              "timeout_ms", intProp "Query timeout in ms (get only)" 5000 ]
            [ "action" ] }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════════

    type SessionState = {
        mutable SessionHandle: nativeint
        mutable Subscriptions: Map<string, nativeint>
        mutable NextSubId: int
    }

    let createState () = {
        SessionHandle = nativeint 0
        Subscriptions = Map.empty
        NextSubId = 1
    }

    // ═══════════════════════════════════════════════════════════════════
    // HELPERS — minimal JSON responses (token economy)
    // ═══════════════════════════════════════════════════════════════════

    let private requireSession (state: SessionState) (id: JsonElement option) (f: unit -> string) : string =
        if state.SessionHandle = nativeint 0 then
            McpProtocol.toolError id "No session. Call zenoh_session with action=open first."
        else
            f ()

    // ═══════════════════════════════════════════════════════════════════
    // ZENOH_SESSION HANDLER
    // ═══════════════════════════════════════════════════════════════════

    let private handleSession (state: SessionState) (args: JsonElement option) (id: JsonElement option) : string =
        let action = McpProtocol.getArgOpt "action" args |> Option.defaultValue ""
        match action with
        | "open" ->
            if state.SessionHandle <> nativeint 0 then
                McpProtocol.toolError id "Session already open. Close first."
            elif not (ZenohFfiBridge.isAvailable()) then
                McpProtocol.toolError id "libzenoh_ffi.so not available. Check LD_LIBRARY_PATH."
            else
                let endpoints =
                    match McpProtocol.getArgOpt "endpoints" args with
                    | Some ep -> ep.Split(',') |> Array.map (fun s -> s.Trim()) |> Array.toList
                    | None -> [ "tcp/localhost:7447" ]
                let mode =
                    match McpProtocol.getArgOpt "mode" args with
                    | Some m -> m | None -> "client"
                let config = { SessionConfig.defaultConfig() with Endpoints = endpoints; Mode = mode }
                match ZenohFfiBridge.openSession config with
                | Ok handle ->
                    state.SessionHandle <- handle
                    let r = {| status = "connected"; endpoints = endpoints; mode = mode |}
                    McpProtocol.toolResult id (JsonSerializer.Serialize(r))
                | Error err ->
                    McpProtocol.toolError id (sprintf "Open failed: %A" err)

        | "close" ->
            if state.SessionHandle = nativeint 0 then
                McpProtocol.toolResult id """{"status":"no_session"}"""
            else
                state.Subscriptions |> Map.iter (fun _ h -> ZenohFfiBridge.unsubscribe h)
                state.Subscriptions <- Map.empty
                state.NextSubId <- 1
                ZenohFfiBridge.closeSession state.SessionHandle
                state.SessionHandle <- nativeint 0
                McpProtocol.toolResult id """{"status":"closed"}"""

        | "stats" ->
            requireSession state id (fun () ->
                match ZenohFfiBridge.sessionStats state.SessionHandle with
                | Ok h ->
                    let r = {|
                        connected = (h.Status = ConnectionStatus.Connected)
                        published = h.MessagesPublished
                        received = h.MessagesReceived
                        latency_ms = h.AveragePublishLatencyMs
                        uptime_s = h.Uptime |> Option.map (fun t -> t.TotalSeconds) |> Option.defaultValue 0.0
                        subs = state.Subscriptions.Count |}
                    McpProtocol.toolResult id (JsonSerializer.Serialize(r))
                | Error err ->
                    McpProtocol.toolError id (sprintf "Stats failed: %A" err))

        | other ->
            McpProtocol.invalidParams id (sprintf "Unknown action: %s (expected open|close|stats)" other)

    // ═══════════════════════════════════════════════════════════════════
    // ZENOH_PUB HANDLER
    // ═══════════════════════════════════════════════════════════════════

    let private handlePub (state: SessionState) (args: JsonElement option) (id: JsonElement option) : string =
        requireSession state id (fun () ->
            match McpProtocol.getArg "key" args, McpProtocol.getArg "payload" args with
            | Ok key, Ok payload ->
                match ZenohFfiBridge.publishString state.SessionHandle key payload with
                | Ok () ->
                    let r = {| ok = true; key = key; len = payload.Length |}
                    McpProtocol.toolResult id (JsonSerializer.Serialize(r))
                | Error err ->
                    McpProtocol.toolError id (sprintf "Publish failed: %A" err)
            | Error e, _ | _, Error e ->
                McpProtocol.invalidParams id e)

    // ═══════════════════════════════════════════════════════════════════
    // ZENOH_SUB HANDLER
    // ═══════════════════════════════════════════════════════════════════

    let private handleSub (state: SessionState) (args: JsonElement option) (id: JsonElement option) : string =
        let action = McpProtocol.getArgOpt "action" args |> Option.defaultValue ""
        match action with
        | "subscribe" ->
            requireSession state id (fun () ->
                match McpProtocol.getArg "key" args with
                | Ok key ->
                    match ZenohFfiBridge.subscribe state.SessionHandle key with
                    | Ok subHandle ->
                        let subId = sprintf "sub_%d" state.NextSubId
                        state.NextSubId <- state.NextSubId + 1
                        state.Subscriptions <- state.Subscriptions |> Map.add subId subHandle
                        let r = {| id = subId; key = key |}
                        McpProtocol.toolResult id (JsonSerializer.Serialize(r))
                    | Error err ->
                        McpProtocol.toolError id (sprintf "Subscribe failed: %A" err)
                | Error e ->
                    McpProtocol.invalidParams id e)

        | "poll" ->
            match McpProtocol.getArg "id" args with
            | Ok subId ->
                match state.Subscriptions |> Map.tryFind subId with
                | Some subHandle ->
                    let limit = McpProtocol.getArgInt "limit" 10 args
                    match ZenohFfiBridge.poll subHandle limit with
                    | Ok samples ->
                        // Minimal response: only key + payload (token economy)
                        let msgs =
                            samples |> List.map (fun s ->
                                {| k = s.KeyExpr; v = Encoding.UTF8.GetString(s.Payload) |})
                        let r = {| id = subId; n = msgs.Length; msgs = msgs |}
                        McpProtocol.toolResult id (JsonSerializer.Serialize(r))
                    | Error err ->
                        McpProtocol.toolError id (sprintf "Poll failed: %A" err)
                | None ->
                    McpProtocol.toolError id (sprintf "Unknown subscription: %s" subId)
            | Error e ->
                McpProtocol.invalidParams id e

        | "unsubscribe" ->
            match McpProtocol.getArg "id" args with
            | Ok subId ->
                match state.Subscriptions |> Map.tryFind subId with
                | Some subHandle ->
                    ZenohFfiBridge.unsubscribe subHandle
                    state.Subscriptions <- state.Subscriptions |> Map.remove subId
                    McpProtocol.toolResult id (sprintf """{"removed":"%s"}""" subId)
                | None ->
                    McpProtocol.toolError id (sprintf "Unknown subscription: %s" subId)
            | Error e ->
                McpProtocol.invalidParams id e

        | other ->
            McpProtocol.invalidParams id (sprintf "Unknown action: %s (expected subscribe|poll|unsubscribe)" other)

    // ═══════════════════════════════════════════════════════════════════
    // ZENOH_QUERY HANDLER
    // ═══════════════════════════════════════════════════════════════════

    let private handleQuery (state: SessionState) (args: JsonElement option) (id: JsonElement option) : string =
        let action = McpProtocol.getArgOpt "action" args |> Option.defaultValue ""
        match action with
        | "get" ->
            requireSession state id (fun () ->
                match McpProtocol.getArg "key" args with
                | Ok key ->
                    let timeoutMs = McpProtocol.getArgInt "timeout_ms" 5000 args
                    match ZenohFfiBridge.get state.SessionHandle key timeoutMs with
                    | Ok samples ->
                        let replies =
                            samples |> List.map (fun s ->
                                {| k = s.KeyExpr; v = Encoding.UTF8.GetString(s.Payload) |})
                        let r = {| key = key; n = replies.Length; replies = replies |}
                        McpProtocol.toolResult id (JsonSerializer.Serialize(r))
                    | Error err ->
                        McpProtocol.toolError id (sprintf "Get failed: %A" err)
                | Error e ->
                    McpProtocol.invalidParams id e)

        | "metrics" ->
            match ZenohFfiBridge.getMetrics() with
            | Ok json -> McpProtocol.toolResult id json
            | Error err -> McpProtocol.toolError id (sprintf "Metrics failed: %A" err)

        | "verify" ->
            match ZenohFfiBridge.verifyDetailed() with
            | Ok json -> McpProtocol.toolResult id json
            | Error err ->
                let basic = ZenohFfiBridge.verify()
                McpProtocol.toolResult id (sprintf """{"passing":%d,"error":"%A"}""" basic err)

        | other ->
            McpProtocol.invalidParams id (sprintf "Unknown action: %s (expected get|metrics|verify)" other)

    // ═══════════════════════════════════════════════════════════════════
    // DISPATCH
    // ═══════════════════════════════════════════════════════════════════

    let dispatch (state: SessionState) (toolName: string) (args: JsonElement option) (id: JsonElement option) : string option =
        match toolName with
        | "zenoh_session" -> Some (handleSession state args id)
        | "zenoh_pub"     -> Some (handlePub state args id)
        | "zenoh_sub"     -> Some (handleSub state args id)
        | "zenoh_query"   -> Some (handleQuery state args id)
        | _ -> None
