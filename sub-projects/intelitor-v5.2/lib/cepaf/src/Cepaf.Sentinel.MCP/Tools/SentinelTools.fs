namespace Cepaf.Sentinel.MCP.Tools

open System
open System.Text
open System.Text.Json
open Cepaf.Zenoh.Core
open Cepaf.Sentinel.MCP.Protocol

/// Single MCP tool for Sentinel health monitoring — action-enum driven.
///
/// Self-contained: reads Sentinel health data from Zenoh topics
/// (no Cepaf.Cockpit / Avalonia dependency).
///
/// Actions: health | threats | status
///   health  — Health score, CPU, memory, error rate, throughput
///   threats — Active threat advisories
///   status  — Bridge connection + subscription metadata
///
/// STAMP: SC-PRAJNA-004 (Sentinel integration), SC-SYNC-004 (30s sync)
/// AOR: AOR-SYNC-007 (Sentinel health sync)
module SentinelTools =

    // ═══════════════════════════════════════════════════════════════════
    // TOOL DEFINITION (1 tool, 3 actions)
    // ═══════════════════════════════════════════════════════════════════

    let toolDefinitions : McpProtocol.ToolDefinition list = [
        { Name = "sentinel"
          Description = "Sentinel health monitoring: get health metrics, active threats, or bridge status."
          InputSchema =
            {| ``type`` = "object"
               properties = Map.ofList [
                   "action", ({| ``type`` = "string"
                                 description = "Sentinel action"
                                 ``enum`` = [ "health"; "threats"; "status" ] |} :> obj) ]
               required = [ "action" ] |} :> obj }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════════

    type HealthCache = {
        mutable HealthScore: float
        mutable Status: string
        mutable SystemLoad: float
        mutable MemoryUsage: float
        mutable CpuUsage: float
        mutable ErrorRate: float
        mutable ThroughputRps: float
        mutable ActiveThreats: string list
        mutable LastUpdated: DateTime option
        mutable PollCount: int64
    }

    type SentinelState = {
        Cache: HealthCache
        mutable HealthSubHandle: nativeint
        mutable ThreatSubHandle: nativeint
    }

    let createState () : SentinelState = {
        Cache = {
            HealthScore = 0.0; Status = "unknown"
            SystemLoad = 0.0; MemoryUsage = 0.0; CpuUsage = 0.0
            ErrorRate = 0.0; ThroughputRps = 0.0
            ActiveThreats = []; LastUpdated = None; PollCount = 0L
        }
        HealthSubHandle = nativeint 0
        ThreatSubHandle = nativeint 0
    }

    // ═══════════════════════════════════════════════════════════════════
    // ZENOH POLLING (lazy subscribe + poll)
    // ═══════════════════════════════════════════════════════════════════

    let private ensureSubscribed (state: SentinelState) (sessionHandle: nativeint) : unit =
        if sessionHandle <> nativeint 0 then
            if state.HealthSubHandle = nativeint 0 then
                match ZenohFfiBridge.subscribe sessionHandle "indrajaal/sentinel/**" with
                | Ok h -> state.HealthSubHandle <- h | Error _ -> ()
            if state.ThreatSubHandle = nativeint 0 then
                match ZenohFfiBridge.subscribe sessionHandle "prajna/alerts/**" with
                | Ok h -> state.ThreatSubHandle <- h | Error _ -> ()

    let private pollHealth (state: SentinelState) : unit =
        if state.HealthSubHandle <> nativeint 0 then
            match ZenohFfiBridge.poll state.HealthSubHandle 50 with
            | Ok samples when not samples.IsEmpty ->
                let latest = samples |> List.last
                let payload = Encoding.UTF8.GetString(latest.Payload)
                try
                    use doc = JsonDocument.Parse(payload)
                    let root = doc.RootElement
                    let f (name: string) = match root.TryGetProperty(name) with | (true, p) -> (try p.GetDouble() with _ -> 0.0) | _ -> 0.0
                    let s (name: string) = match root.TryGetProperty(name) with | (true, p) -> (try p.GetString() with _ -> "") | _ -> ""
                    state.Cache.HealthScore <- f "health_score"
                    state.Cache.Status <- (let v = s "status" in if String.IsNullOrEmpty v then "unknown" else v)
                    state.Cache.SystemLoad <- f "system_load"
                    state.Cache.MemoryUsage <- f "memory_usage"
                    state.Cache.CpuUsage <- f "cpu_usage"
                    state.Cache.ErrorRate <- f "error_rate"
                    state.Cache.ThroughputRps <- f "throughput_rps"
                    state.Cache.LastUpdated <- Some DateTime.UtcNow
                    state.Cache.PollCount <- state.Cache.PollCount + 1L
                with _ -> ()
            | _ -> ()

        if state.ThreatSubHandle <> nativeint 0 then
            match ZenohFfiBridge.poll state.ThreatSubHandle 50 with
            | Ok samples when not samples.IsEmpty ->
                state.Cache.ActiveThreats <- samples |> List.map (fun s -> Encoding.UTF8.GetString(s.Payload))
            | _ -> ()

    // ═══════════════════════════════════════════════════════════════════
    // HANDLER (single dispatch with action enum)
    // ═══════════════════════════════════════════════════════════════════

    let private handleSentinel (state: SentinelState) (sessionHandle: nativeint) (args: JsonElement option) (id: JsonElement option) : string =
        let action = McpProtocol.getArgOpt "action" args |> Option.defaultValue ""
        match action with
        | "health" ->
            ensureSubscribed state sessionHandle
            pollHealth state
            let c = state.Cache
            let r = {|
                score = c.HealthScore
                status = c.Status
                cpu = c.CpuUsage
                mem = c.MemoryUsage
                load = c.SystemLoad
                err_rate = c.ErrorRate
                rps = c.ThroughputRps
                threats = c.ActiveThreats.Length
                updated = (c.LastUpdated |> Option.map (fun d -> d.ToString("o")) |> Option.defaultValue "never") |}
            McpProtocol.toolResult id (JsonSerializer.Serialize(r))

        | "threats" ->
            ensureSubscribed state sessionHandle
            pollHealth state
            let r = {| n = state.Cache.ActiveThreats.Length; threats = state.Cache.ActiveThreats |}
            McpProtocol.toolResult id (JsonSerializer.Serialize(r))

        | "status" ->
            let r = {|
                health_sub = (state.HealthSubHandle <> nativeint 0)
                threat_sub = (state.ThreatSubHandle <> nativeint 0)
                session = (sessionHandle <> nativeint 0)
                updated = (state.Cache.LastUpdated |> Option.map (fun d -> d.ToString("o")) |> Option.defaultValue "never")
                polls = state.Cache.PollCount |}
            McpProtocol.toolResult id (JsonSerializer.Serialize(r))

        | other ->
            McpProtocol.invalidParams id (sprintf "Unknown action: %s (expected health|threats|status)" other)

    // ═══════════════════════════════════════════════════════════════════
    // DISPATCH
    // ═══════════════════════════════════════════════════════════════════

    let dispatch (state: SentinelState) (sessionHandle: nativeint) (toolName: string) (args: JsonElement option) (id: JsonElement option) : string option =
        match toolName with
        | "sentinel" -> Some (handleSentinel state sessionHandle args id)
        | _ -> None

    let shutdown (state: SentinelState) : unit =
        if state.HealthSubHandle <> nativeint 0 then
            ZenohFfiBridge.unsubscribe state.HealthSubHandle
            state.HealthSubHandle <- nativeint 0
        if state.ThreatSubHandle <> nativeint 0 then
            ZenohFfiBridge.unsubscribe state.ThreatSubHandle
            state.ThreatSubHandle <- nativeint 0
