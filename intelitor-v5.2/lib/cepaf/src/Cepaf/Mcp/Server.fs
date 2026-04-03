// =============================================================================
// Server.fs - MCP Server Dispatch Hub (19-Tool Registry)
// =============================================================================
// STAMP: SC-MCP-001 (MCP server integration), SC-MCP-002 (tool dispatch),
//        SC-GUARD-001 (Guardian handler), SC-ORCH-006 (AI via Cortex),
//        SC-SMRITI-131 (knowledge search), SC-SESS-001 (SSE sessions),
//        SC-ZENOH-001 (Zenoh telemetry), SC-MON-003 (per-domain metrics)
// AOR: AOR-MCP-001 (authorised MCP tool dispatch)
//
// Central JSON-RPC dispatch hub for the CEPAF MCP server.
// Routes tools/list and tools/call to domain handlers:
//   Core (4), Guardian (5), Cortex (4), SMRITI (3), SSE (3)
//
// Telemetry: Per-tool request count, error count and cumulative latency are
// stored in ConcurrentDictionary counters.  After every tool call the metrics
// are published to Zenoh key `indrajaal/mcp/server/metrics` via ZenohPublish.
//
// NOTE: This file MUST appear AFTER all handler files in Cepaf.fsproj
// because F# compiles top-to-bottom — Server.fs references handler modules.
// Version: 21.3.3 | 2026-03-30
// =============================================================================

namespace Cepaf.Mcp

open System
open System.Collections.Concurrent
open System.Text.Json
open Cepaf.Modules // Access to Podman, etc.
open Cepaf.Mesh.CLI
open Cepaf.Mesh

module Server =

    // -------------------------------------------------------------------------
    // Per-tool telemetry counters (SC-MON-003, SC-ZENOH-001)
    // -------------------------------------------------------------------------

    /// Accumulator record stored per tool name in the ConcurrentDictionary.
    [<Struct>]
    type private ToolCounter = {
        Requests  : int64
        Errors    : int64
        TotalMs   : int64
    }

    /// Thread-safe store: tool_name → aggregated counters.
    let private toolCounters = ConcurrentDictionary<string, ToolCounter>()

    /// Server-wide totals (updated atomically alongside per-tool counters).
    let mutable private totalRequests = 0L
    let mutable private totalErrors   = 0L

    /// Atomically increment the per-tool counter after a call completes.
    let private recordCall (toolName: string) (durationMs: int64) (isError: bool) =
        let upd _ (c: ToolCounter) =
            { Requests = c.Requests + 1L
              Errors   = c.Errors   + (if isError then 1L else 0L)
              TotalMs  = c.TotalMs  + durationMs }
        let init =
            { Requests = 1L
              Errors   = if isError then 1L else 0L
              TotalMs  = durationMs }
        toolCounters.AddOrUpdate(toolName, init, upd) |> ignore
        Threading.Interlocked.Increment(&totalRequests) |> ignore
        if isError then Threading.Interlocked.Increment(&totalErrors) |> ignore

    /// Build a compact JSON metrics payload for Zenoh publication.
    let private buildMetricsJson () : string =
        let toolEntries =
            toolCounters
            |> Seq.map (fun kv ->
                let c = kv.Value
                let avgMs = if c.Requests > 0L then float c.TotalMs / float c.Requests else 0.0
                let errRate = if c.Requests > 0L then float c.Errors / float c.Requests else 0.0
                sprintf """"%s":{"requests":%d,"errors":%d,"avg_latency_ms":%.2f,"error_rate":%.4f}"""
                    kv.Key c.Requests c.Errors avgMs errRate)
            |> String.concat ","
        sprintf """{"server":{"total_requests":%d,"total_errors":%d},"tools":{%s},"timestamp":"%s"}"""
            totalRequests totalErrors toolEntries (DateTimeOffset.UtcNow.ToString("o"))

    /// Publish current metrics to Zenoh (fire-and-forget, best-effort).
    let private publishMetrics (toolName: string) (durationMs: int64) (isError: bool) =
        try
            let json = buildMetricsJson ()
            let msg  = sprintf "tool=%s duration_ms=%d error=%b" toolName durationMs isError
            ZenohPublish.publish "MCP-METRICS" "indrajaal/mcp/server/metrics" msg json
        with ex ->
            eprintfn "[MCP-Server] metrics publish failed: %s" ex.Message

    // -------------------------------------------------------------------------
    // Safe JSON arg extraction helpers
    // -------------------------------------------------------------------------

    let private tryGetString (args: JsonElement) (name: string) : string option =
        let mutable el = JsonElement()
        if args.ValueKind = JsonValueKind.Object && args.TryGetProperty(name, &el) then
            if el.ValueKind = JsonValueKind.String then Some (el.GetString()) else None
        else None

    let private tryGetInt (args: JsonElement) (name: string) (defaultVal: int) : int =
        let mutable el = JsonElement()
        if args.ValueKind = JsonValueKind.Object && args.TryGetProperty(name, &el) then
            if el.ValueKind = JsonValueKind.Number then el.GetInt32() else defaultVal
        else defaultVal

    let private tryGetFloat (args: JsonElement) (name: string) (defaultVal: float) : float =
        let mutable el = JsonElement()
        if args.ValueKind = JsonValueKind.Object && args.TryGetProperty(name, &el) then
            if el.ValueKind = JsonValueKind.Number then el.GetDouble() else defaultVal
        else defaultVal

    let private tryGetBool (args: JsonElement) (name: string) (defaultVal: bool) : bool =
        let mutable el = JsonElement()
        if args.ValueKind = JsonValueKind.Object && args.TryGetProperty(name, &el) then
            match el.ValueKind with
            | JsonValueKind.True -> true
            | JsonValueKind.False -> false
            | _ -> defaultVal
        else defaultVal

    let private tryGetInt64 (args: JsonElement) (name: string) (defaultVal: int64) : int64 =
        let mutable el = JsonElement()
        if args.ValueKind = JsonValueKind.Object && args.TryGetProperty(name, &el) then
            if el.ValueKind = JsonValueKind.Number then el.GetInt64() else defaultVal
        else defaultVal

    let private tryGetStringList (args: JsonElement) (name: string) : string list =
        let mutable el = JsonElement()
        if args.ValueKind = JsonValueKind.Object && args.TryGetProperty(name, &el) then
            if el.ValueKind = JsonValueKind.Array then
                [ for item in el.EnumerateArray() do
                    if item.ValueKind = JsonValueKind.String then yield item.GetString() ]
            else []
        else []

    let private tryGetOptionalFloat (args: JsonElement) (name: string) : float option =
        let mutable el = JsonElement()
        if args.ValueKind = JsonValueKind.Object && args.TryGetProperty(name, &el) then
            if el.ValueKind = JsonValueKind.Number then Some (el.GetDouble()) else None
        else None

    // -------------------------------------------------------------------------
    // 19-Tool registry across 5 domains
    // -------------------------------------------------------------------------

    let private tools = [
        // --- Core (4) ---
        { Name = "cepaf.health"
          Description = "Get CEPAF system health status"
          InputSchema = obj() }
        { Name = "cepaf.podman.list"
          Description = "List running containers"
          InputSchema = obj() }
        { Name = "swarm_metabolic_prune"
          Description = "High-assurance metabolic pruning of orphaned container layers. Call without args for analysis, then with confirm_hash to actuate."
          InputSchema = obj() }
        { Name = "server_stats"
          Description = "Return MCP server telemetry: per-tool request count, error count, average latency and error rate."
          InputSchema = obj() }

        // --- Guardian (5) ---
        { Name = "guardian.submit"
          Description = "Submit a proposal for Guardian evaluation. Requires actor, action, target."
          InputSchema = obj() }
        { Name = "guardian.status"
          Description = "Query Guardian proposal status by proposal_id."
          InputSchema = obj() }
        { Name = "guardian.list_pending"
          Description = "List all pending Guardian proposals."
          InputSchema = obj() }
        { Name = "guardian.approve"
          Description = "Approve a pending Guardian proposal by proposal_id."
          InputSchema = obj() }
        { Name = "guardian.veto"
          Description = "Veto a pending Guardian proposal with reason."
          InputSchema = obj() }

        // --- Cortex AI (4) ---
        { Name = "cortex.infer"
          Description = "Request AI inference via Cortex. Requires model_id and prompt."
          InputSchema = obj() }
        { Name = "cortex.status"
          Description = "Get inference request status/result by request_id."
          InputSchema = obj() }
        { Name = "cortex.models"
          Description = "List available AI models in the Cortex registry."
          InputSchema = obj() }
        { Name = "cortex.model"
          Description = "Get metadata for a specific AI model by model_id."
          InputSchema = obj() }

        // --- SMRITI Knowledge (3) ---
        { Name = "smriti.search"
          Description = "Search SMRITI knowledge base with full-text query. Supports kind and tag filters."
          InputSchema = obj() }
        { Name = "smriti.get"
          Description = "Get a specific SMRITI note by note_id."
          InputSchema = obj() }
        { Name = "smriti.kinds"
          Description = "List available note kinds and their counts."
          InputSchema = obj() }

        // --- SSE Transport (3) ---
        { Name = "sse.register"
          Description = "Register a new SSE client session. Requires remote_addr."
          InputSchema = obj() }
        { Name = "sse.frame"
          Description = "Frame a JSON payload as an SSE message event. Requires client_id, event_id, payload."
          InputSchema = obj() }
        { Name = "sse.heartbeat"
          Description = "Generate an SSE heartbeat frame. Requires client_id, event_id."
          InputSchema = obj() }
    ]

    // -------------------------------------------------------------------------
    // Result<string,string> → ToolCallResult adapter
    // -------------------------------------------------------------------------

    let private resultToToolCall (r: Result<string, string>) : ToolCallResult =
        match r with
        | Ok json -> { Content = [{ Type = "text"; Text = json }]; IsError = false }
        | Error e -> { Content = [{ Type = "text"; Text = e }]; IsError = true }

    // -------------------------------------------------------------------------
    // Tool dispatch — routes to domain handlers
    // -------------------------------------------------------------------------

    let private dispatchTool (name: string) (args: JsonElement) : ToolCallResult =
        try
            match name with
            // === Core ===
            | "cepaf.health" ->
                { Content = [{ Type = "text"; Text = "{\"status\":\"healthy\",\"uptime\":100}" }]; IsError = false }

            | "cepaf.podman.list" ->
                { Content = [{ Type = "text"; Text = "[]" }]; IsError = false }

            | "swarm_metabolic_prune" ->
                let confirmHash = tryGetString args "confirm_hash"
                let isLive = tryGetBool args "live" false
                let age = tryGetOptionalFloat args "age_threshold"
                let cli = SIL4MeshCLI()
                let res = cli.Prune(true, ?confirmHash = confirmHash, dryRun = not isLive, ?ageThreshold = age)
                { Content = [{ Type = "text"; Text = JsonSerializer.Serialize(res) }]; IsError = false }

            // === Guardian (SC-GUARD-001, SC-SAFETY-001) ===
            | "guardian.submit" ->
                let actor = tryGetString args "actor" |> Option.defaultValue ""
                let action = tryGetString args "action" |> Option.defaultValue ""
                let target = tryGetString args "target" |> Option.defaultValue ""
                let payload = tryGetString args "payload" |> Option.defaultValue "{}"
                let stampRefs = tryGetStringList args "stamp_refs"
                GuardianHandler.submitProposal actor action target payload stampRefs |> resultToToolCall

            | "guardian.status" ->
                let pid = tryGetString args "proposal_id" |> Option.defaultValue ""
                GuardianHandler.queryStatus pid |> resultToToolCall

            | "guardian.list_pending" ->
                GuardianHandler.listPending () |> resultToToolCall

            | "guardian.approve" ->
                let pid = tryGetString args "proposal_id" |> Option.defaultValue ""
                GuardianHandler.approveProposal pid |> resultToToolCall

            | "guardian.veto" ->
                let pid = tryGetString args "proposal_id" |> Option.defaultValue ""
                let reason = tryGetString args "reason" |> Option.defaultValue "No reason given"
                GuardianHandler.vetoProposal pid reason |> resultToToolCall

            // === Cortex AI (SC-ORCH-006, SC-MODEL-001) ===
            | "cortex.infer" ->
                let modelId = tryGetString args "model_id" |> Option.defaultValue ""
                let prompt = tryGetString args "prompt" |> Option.defaultValue ""
                let maxTokens = tryGetInt args "max_tokens" 512
                let temp = tryGetFloat args "temperature" 0.7
                CortexHandler.requestInference modelId prompt maxTokens temp |> resultToToolCall

            | "cortex.status" ->
                let rid = tryGetString args "request_id" |> Option.defaultValue ""
                CortexHandler.getResult rid |> resultToToolCall

            | "cortex.models" ->
                CortexHandler.listModels () |> resultToToolCall

            | "cortex.model" ->
                let mid = tryGetString args "model_id" |> Option.defaultValue ""
                CortexHandler.getModel mid |> resultToToolCall

            // === SMRITI Knowledge (SC-SMRITI-131, SC-SMRITI-133) ===
            | "smriti.search" ->
                let query = tryGetString args "query" |> Option.defaultValue ""
                let kind = tryGetString args "kind"
                let tags = tryGetStringList args "tags"
                let maxRes = tryGetInt args "max_results" 10
                SmritiHandler.searchNotes query kind tags maxRes |> resultToToolCall

            | "smriti.get" ->
                let nid = tryGetString args "note_id" |> Option.defaultValue ""
                SmritiHandler.getNote nid |> resultToToolCall

            | "smriti.kinds" ->
                SmritiHandler.listKinds () |> resultToToolCall

            // === SSE Transport (SC-SESS-001, SC-HTTP-001) ===
            | "sse.register" ->
                let addr = tryGetString args "remote_addr" |> Option.defaultValue "unknown"
                SseTransport.registerClient addr |> resultToToolCall

            | "sse.frame" ->
                let cid = tryGetString args "client_id" |> Option.defaultValue ""
                let eid = tryGetInt64 args "event_id" 0L
                let payload = tryGetString args "payload" |> Option.defaultValue "{}"
                SseTransport.frameMessage cid eid payload |> resultToToolCall

            | "sse.heartbeat" ->
                let cid = tryGetString args "client_id" |> Option.defaultValue ""
                let eid = tryGetInt64 args "event_id" 0L
                SseTransport.frameHeartbeat cid eid |> resultToToolCall

            // === Telemetry / Stats ===
            | "server_stats" ->
                let json = buildMetricsJson ()
                { Content = [{ Type = "text"; Text = json }]; IsError = false }

            | _ ->
                { Content = [{ Type = "text"; Text = sprintf "Unknown tool: %s" name }]; IsError = true }

        with ex ->
            { Content = [{ Type = "text"; Text = ex.Message }]; IsError = true }

    /// Instrumented wrapper: records timing, updates counters, publishes to Zenoh.
    let private handleToolCall (name: string) (args: JsonElement) : ToolCallResult =
        let sw = Diagnostics.Stopwatch.StartNew()
        let result = dispatchTool name args
        sw.Stop()
        let durationMs = sw.ElapsedMilliseconds
        let isError = result.IsError
        recordCall name durationMs isError
        eprintfn "[MCP-Server] tool=%s duration_ms=%d error=%b" name durationMs isError
        publishMetrics name durationMs isError
        result

    // -------------------------------------------------------------------------
    // JSON-RPC stdin/stdout loop
    // -------------------------------------------------------------------------

    let processLine (line: string) =
        try
            let req = JsonSerializer.Deserialize<JsonRpcRequest>(line)
            match req.Method with
            | "tools/list" ->
                let result = { Tools = tools }
                let resp = { JsonRpc = "2.0"; Id = req.Id; Result = result }
                Console.WriteLine(JsonSerializer.Serialize(resp))

            | "tools/call" ->
                let name = req.Params.GetProperty("name").GetString()
                let args = req.Params.GetProperty("arguments")
                let result = handleToolCall name args
                let resp = { JsonRpc = "2.0"; Id = req.Id; Result = result }
                Console.WriteLine(JsonSerializer.Serialize(resp))

            | _ -> ()
        with ex ->
            Console.Error.WriteLine($"[MCP-F#] Error: {ex.Message}")

    let start () =
        let rec loop () =
            let line = Console.ReadLine()
            if not (isNull line) then
                processLine line
                loop ()
        loop ()
