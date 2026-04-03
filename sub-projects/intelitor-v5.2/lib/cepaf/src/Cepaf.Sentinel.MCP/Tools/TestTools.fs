namespace Cepaf.Sentinel.MCP.Tools

open System
open System.Text.Json
open Cepaf.Sentinel.MCP.Protocol
open Cepaf.Testing

/// MCP tool definitions for F# test execution via TestAgent.
///
/// 5 tools following MCP best practice (enum-driven where applicable):
///   - test_fsharp_start: Start a regression test run (levels, timeout)
///   - test_fsharp_stop: Stop a running test (by run_id)
///   - test_fsharp_status: Query current test agent status
///   - test_fsharp_results: Get recent test results
///   - test_fsharp_logs: Get recent failure stack traces (Phase 4)
///
/// STAMP: SC-MCP-TEST-001 to SC-MCP-TEST-004, SC-ZTEST-008, SC-ZTEST-003
/// AOR: AOR-FAG-002 (MailboxProcessor), AOR-ZTEST-004 (async publishing)
module TestTools =

    // ═══════════════════════════════════════════════════════════════════
    // SCHEMA HELPERS (same pattern as ZenohTools)
    // ═══════════════════════════════════════════════════════════════════

    let private mkSchema (props: (string * obj) list) (required: string list) : obj =
        {| ``type`` = "object"
           properties = props |> Map.ofList
           required = required |}

    let private stringProp desc : obj =
        {| ``type`` = "string"; description = desc |} :> obj

    let private intProp desc defaultVal : obj =
        {| ``type`` = "integer"; description = desc; ``default`` = defaultVal |} :> obj

    let private boolProp desc defaultVal : obj =
        {| ``type`` = "boolean"; description = desc; ``default`` = defaultVal |} :> obj

    let private arrayProp desc itemType : obj =
        {| ``type`` = "array"; description = desc; items = {| ``type`` = itemType |} |} :> obj

    // ═══════════════════════════════════════════════════════════════════
    // TOOL DEFINITIONS
    // ═══════════════════════════════════════════════════════════════════

    let toolDefinitions : McpProtocol.ToolDefinition list = [
        { Name = "test_fsharp_start"
          Description = "Start F# regression test run. Levels: 1=Compile, 2=FullTests, 3=SIL6, 4=Quality, 5=Health."
          InputSchema = mkSchema
            [ "levels", arrayProp "Regression levels to run (1-5). Default: all." "integer"
              "timeout_s", intProp "Timeout in seconds (default 900 = 15min)" 900
              "verbose", boolProp "Verbose output" false ]
            [] }

        { Name = "test_fsharp_stop"
          Description = "Stop a running F# test. Propagates cancellation within 1s."
          InputSchema = mkSchema
            [ "run_id", stringProp "Run ID to stop (empty = stop current run)" ]
            [] }

        { Name = "test_fsharp_status"
          Description = "Query current F# test agent status (idle/running/completed/failed)."
          InputSchema = mkSchema [] [] }

        { Name = "test_fsharp_results"
          Description = "Get recent F# test run results."
          InputSchema = mkSchema
            [ "count", intProp "Number of recent results to return (default 5)" 5 ]
            [] }

        { Name = "test_fsharp_logs"
          Description = "Get recent F# test failure stack traces and error logs. Returns last N failure entries for debugging."
          InputSchema = mkSchema
            [ "count", intProp "Number of recent log entries to return (default 10)" 10 ]
            [] }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════════

    /// A buffered log entry from test execution (failures, errors)
    type LogEntry = {
        Timestamp: DateTime
        RunId: string
        Level: int
        Category: string
        Message: string
    }

    type TestToolsState = {
        Agent: MailboxProcessor<Cepaf.Testing.TestMessage>
        /// Bounded buffer of recent log entries (max 100). Phase 4: SC-ZTEST-003.
        LogBuffer: ResizeArray<LogEntry>
    }

    let private maxLogEntries = 100

    let createState () : TestToolsState = {
        Agent = TestAgent.create(None)
        LogBuffer = ResizeArray<LogEntry>(maxLogEntries)
    }

    /// Add a log entry to the bounded buffer, evicting oldest if at capacity
    let addLogEntry (state: TestToolsState) (entry: LogEntry) =
        if state.LogBuffer.Count >= maxLogEntries then
            state.LogBuffer.RemoveAt(0)
        state.LogBuffer.Add(entry)

    /// Extract failure log entries from a RunResult and add to buffer.
    /// Uses lr.Details (subprocess output) instead of DU status string (SC-MCP-TEST-005).
    let bufferFailures (state: TestToolsState) (result: Cepaf.Testing.RunResult) =
        result.LevelResults
        |> Map.iter (fun levelNum lr ->
            match lr.Status with
            | Cepaf.Testing.Fail _statusStr ->
                addLogEntry state {
                    Timestamp = result.EndTime
                    RunId = result.RunId
                    Level = levelNum
                    Category = "FAIL"
                    Message = if lr.Details.Length > 0 then lr.Details else "FAIL (no output captured)"
                }
            | _ -> ())

    // ═══════════════════════════════════════════════════════════════════
    // HELPERS
    // ═══════════════════════════════════════════════════════════════════

    /// Parse levels array from JSON args. Default: [1,2,3,4,5]
    let private parseLevels (args: JsonElement option) : int list =
        match args with
        | None -> [1; 2; 3; 4; 5]
        | Some argsEl ->
            match argsEl.TryGetProperty("levels") with
            | true, levelsEl when levelsEl.ValueKind = JsonValueKind.Array ->
                [ for item in levelsEl.EnumerateArray() do
                    if item.ValueKind = JsonValueKind.Number then
                        yield item.GetInt32() ]
                |> function
                   | [] -> [1; 2; 3; 4; 5]
                   | levels -> levels |> List.filter (fun l -> l >= 1 && l <= 5)
            | _ -> [1; 2; 3; 4; 5]

    // ═══════════════════════════════════════════════════════════════════
    // HANDLERS
    // ═══════════════════════════════════════════════════════════════════

    let private handleStart (state: TestToolsState) (args: JsonElement option) (id: JsonElement option) : string =
        let levels = parseLevels args
        let timeoutS = McpProtocol.getArgInt "timeout_s" 900 args
        let verbose =
            match args with
            | Some argsEl ->
                match argsEl.TryGetProperty("verbose") with
                | true, v when v.ValueKind = JsonValueKind.True -> true
                | _ -> false
            | None -> false

        let config : Cepaf.Testing.TestConfig = {
            Levels = levels
            TimeoutSeconds = timeoutS
            Verbose = verbose
        }

        match TestAgent.start state.Agent config with
        | Ok runId ->
            let r = {| ok = true; run_id = runId; levels = levels; timeout_s = timeoutS |}
            McpProtocol.toolResult id (JsonSerializer.Serialize(r))
        | Error err ->
            McpProtocol.toolError id err

    let private handleStop (state: TestToolsState) (args: JsonElement option) (id: JsonElement option) : string =
        let runId = McpProtocol.getArgOpt "run_id" args |> Option.defaultValue ""
        match TestAgent.stop state.Agent runId with
        | Ok () ->
            McpProtocol.toolResult id """{"ok":true,"stopped":true}"""
        | Error err ->
            McpProtocol.toolError id err

    let private handleStatus (state: TestToolsState) (_args: JsonElement option) (id: JsonElement option) : string =
        let s = TestAgent.status state.Agent
        McpProtocol.toolResult id (TestAgent.statusToJson s)

    let private handleResults (state: TestToolsState) (args: JsonElement option) (id: JsonElement option) : string =
        let count = McpProtocol.getArgInt "count" 5 args
        let runs = TestAgent.results state.Agent count
        // Buffer failures from any new results
        runs |> List.iter (bufferFailures state)
        let json =
            runs
            |> List.map TestAgent.resultToJson
            |> String.concat ","
            |> sprintf """{"count":%d,"results":[%s]}""" runs.Length
        McpProtocol.toolResult id json

    let private handleLogs (state: TestToolsState) (args: JsonElement option) (id: JsonElement option) : string =
        let count = McpProtocol.getArgInt "count" 10 args
        // Also refresh from latest results to catch any new failures
        let runs = TestAgent.results state.Agent 5
        runs |> List.iter (bufferFailures state)
        let entries =
            state.LogBuffer
            |> Seq.toList
            |> List.rev  // Most recent first
            |> List.truncate count
        let logsJson =
            entries
            |> List.map (fun e ->
                sprintf """{"timestamp":"%s","run_id":"%s","level":%d,"category":"%s","message":"%s"}"""
                    (e.Timestamp.ToString("o"))
                    e.RunId
                    e.Level
                    e.Category
                    (let raw = if e.Message.Length > 4000 then e.Message.Substring(e.Message.Length - 4000) else e.Message
                     raw.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\n", "\\n").Replace("\r", "")))
            |> String.concat ","
        McpProtocol.toolResult id (sprintf """{"count":%d,"total_buffered":%d,"logs":[%s]}""" entries.Length state.LogBuffer.Count logsJson)

    // ═══════════════════════════════════════════════════════════════════
    // DISPATCH
    // ═══════════════════════════════════════════════════════════════════

    let dispatch (state: TestToolsState) (toolName: string) (args: JsonElement option) (id: JsonElement option) : string option =
        match toolName with
        | "test_fsharp_start"   -> Some (handleStart state args id)
        | "test_fsharp_stop"    -> Some (handleStop state args id)
        | "test_fsharp_status"  -> Some (handleStatus state args id)
        | "test_fsharp_results" -> Some (handleResults state args id)
        | "test_fsharp_logs"    -> Some (handleLogs state args id)
        | _ -> None
