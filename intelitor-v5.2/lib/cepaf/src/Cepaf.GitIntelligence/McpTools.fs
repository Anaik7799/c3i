// =============================================================================
// Git Intelligence — L2 MCP Agentic Interface
// =============================================================================
// Purpose:  Expose git intelligence capabilities as MCP tools for agentic
//           workflows. 5 tools: analyze, validate, health, suggest, history.
//           Inlines minimal MCP protocol types to maintain standalone arch.
//
// STAMP:    SC-MCP (tool dispatch), SC-FSH-017 (Result type errors)
// =============================================================================

module Cepaf.GitIntelligence.McpTools

open System

// ─────────────────────────────────────────────────────────────────────────────
// Inline MCP Protocol Types (standalone — no ProjectReference to Cepaf)
// ─────────────────────────────────────────────────────────────────────────────

/// Minimal MCP tool definition.
type ToolDefinition =
    { Name: string
      Description: string
      InputSchema: obj }

/// Extract an optional string argument from a map.
let private getArgOpt (args: Map<string, obj>) (key: string) : string option =
    match args.TryFind key with
    | Some (:? string as s) when not (String.IsNullOrWhiteSpace s) -> Some s
    | _ -> None

/// Extract a required string argument, or None.
let private getArgReq (args: Map<string, obj>) (key: string) : string option =
    getArgOpt args key

/// Wrap a JSON string as a tool result.
let private toolResult (json: string) : string =
    json

/// Return an invalid-params error.
let private invalidParams (msg: string) : string =
    $"""{{ "error": "invalid_params", "message": "{msg}" }}"""

// ─────────────────────────────────────────────────────────────────────────────
// Tool Definitions
// ─────────────────────────────────────────────────────────────────────────────

let toolDefinitions : ToolDefinition list = [
    { Name = "git_intel_analyze"
      Description = "Analyze git commit history: style distribution, scope compliance, health score, entropy"
      InputSchema =
        {| ``type`` = "object"
           properties = Map.ofList [
               "path", ({| ``type`` = "string"; description = "Git repository path (default: current)" |} :> obj)
               "count", ({| ``type`` = "string"; description = "Number of commits to analyze (default: 100)" |} :> obj)
               "format", ({| ``type`` = "string"; description = "Output format: json or text (default: json)"; ``enum`` = [ "json"; "text" ] |} :> obj) ]
           required = [] :> obj |} :> obj }

    { Name = "git_intel_validate"
      Description = "Validate a commit message against ICP v2.0 convention"
      InputSchema =
        {| ``type`` = "object"
           properties = Map.ofList [
               "message", ({| ``type`` = "string"; description = "Commit message to validate" |} :> obj) ]
           required = [ "message" ] |} :> obj }

    { Name = "git_intel_health"
      Description = "Get current Git Health Score (GHS) and adoption metrics"
      InputSchema =
        {| ``type`` = "object"
           properties = Map.ofList [
               "source", ({| ``type`` = "string"; description = "Data source: live or store (default: store)"; ``enum`` = [ "live"; "store" ] |} :> obj) ]
           required = [] :> obj |} :> obj }

    { Name = "git_intel_suggest"
      Description = "Generate an ICP-compliant commit message for staged changes"
      InputSchema =
        {| ``type`` = "object"
           properties = Map.ofList [
               "path", ({| ``type`` = "string"; description = "Git repository path (default: current)" |} :> obj) ]
           required = [] :> obj |} :> obj }

    { Name = "git_intel_history"
      Description = "Query evolution event history from DuckDB log"
      InputSchema =
        {| ``type`` = "object"
           properties = Map.ofList [
               "action", ({| ``type`` = "string"; description = "History action"; ``enum`` = [ "recent"; "velocity"; "count"; "lineage" ] |} :> obj)
               "event_type", ({| ``type`` = "string"; description = "Filter by event type (for recent)" |} :> obj)
               "limit", ({| ``type`` = "string"; description = "Max events to return (default: 20)" |} :> obj)
               "days", ({| ``type`` = "string"; description = "Window in days (for velocity, default: 7)" |} :> obj) ]
           required = [ "action" ] |} :> obj }
]

// ─────────────────────────────────────────────────────────────────────────────
// Tool Handlers
// ─────────────────────────────────────────────────────────────────────────────

let private handleAnalyze (args: Map<string, obj>) : string =
    let path = getArgOpt args "path" |> Option.defaultValue "."
    let since = getArgOpt args "count" |> Option.defaultValue "6m"
    let format = getArgOpt args "format" |> Option.defaultValue "json"

    match Parser.parseGitLog path since None with
    | Error e ->
        toolResult $"""{{ "error": "parse_error", "message": "{e}" }}"""
    | Ok commits when commits.Length = 0 ->
        toolResult """{ "error": "no_commits", "message": "No commits found in repository" }"""
    | Ok commits ->
        let analysis = Analysis.analyze commits
        match format with
        | "text" ->
            let lines = System.Text.StringBuilder()
            lines.AppendLine("Git Intelligence Analysis") |> ignore
            lines.AppendLine($"  Commits: {analysis.TotalCommits}") |> ignore
            let ghs = analysis.HealthScore.Score
            let entropy = analysis.HealthScore.TypeEntropy
            let adoption = analysis.HealthScore.IcpAdoption
            lines.AppendLine($"  GHS: {ghs:F4}") |> ignore
            lines.AppendLine($"  Entropy: {entropy:F4}") |> ignore
            lines.AppendLine($"  ICP Adoption: {adoption:F1}%%") |> ignore
            let output = lines.ToString().Replace("\"", "\\\"").Replace("\n", "\\n")
            toolResult $"""{{ "format": "text", "output": "{output}" }}"""
        | _ ->
            toolResult (Analysis.analysisToJson analysis)

let private handleValidate (args: Map<string, obj>) : string =
    match getArgReq args "message" with
    | None -> invalidParams "Missing required parameter: message"
    | Some msg ->
        let result = Parser.validate msg
        let escapeJson (s: string) = s.Replace("\"", "\\\"")
        let errorsJson =
            result.Issues
            |> List.map (fun issue ->
                let desc = $"{issue}"
                let escaped = escapeJson desc
                $"\"{escaped}\"")
            |> String.concat ", "
        let escapedMsg = escapeJson msg
        let validStr = if result.IsValid then "true" else "false"
        toolResult $"""{{ "valid": {validStr}, "message": "{escapedMsg}", "errors": [{errorsJson}] }}"""

let private handleHealth (args: Map<string, obj>) : string =
    let source = getArgOpt args "source" |> Option.defaultValue "store"
    match source with
    | "store" ->
        match Store.getLatestHealth () with
        | Some (ghs, adoption, compliance, totalCommits) ->
            toolResult $"""{{ "source": "store", "ghs": {ghs:F4}, "adoption": {adoption:F1}, "compliance": {compliance:F4}, "totalCommits": {totalCommits} }}"""
        | None ->
            toolResult """{ "source": "store", "error": "no_data", "message": "No health snapshots in store. Run analyze first." }"""
    | "live" | _ ->
        match Parser.parseGitLog "." "6m" None with
        | Error e ->
            toolResult $"""{{ "source": "live", "error": "parse_error", "message": "{e}" }}"""
        | Ok commits when commits.Length = 0 ->
            toolResult """{ "source": "live", "error": "no_commits", "message": "No commits found" }"""
        | Ok commits ->
            let analysis = Analysis.analyze commits
            let ghs = analysis.HealthScore.Score
            let entropy = analysis.HealthScore.TypeEntropy
            let adoption = analysis.HealthScore.IcpAdoption
            toolResult $"""{{ "source": "live", "ghs": {ghs:F4}, "entropy": {entropy:F4}, "icpAdoption": {adoption:F1}, "totalCommits": {analysis.TotalCommits} }}"""

let private handleSuggest (args: Map<string, obj>) : string =
    let path = getArgOpt args "path" |> Option.defaultValue "."
    let diff = Parser.stagedShortstat path
    if String.IsNullOrWhiteSpace diff then
        toolResult """{ "error": "no_staged", "message": "No staged changes found. Stage files with git add first." }"""
    else
        // Construct a minimal CommitInput from staged diff info
        let input : CommitInput =
            { Type = CommitType.Chore
              Scopes = []
              Action = "update staged files"
              Context = Some diff
              Why = None
              What = None
              FilesCreated = 0
              FilesModified = 0
              Layers = []
              StampRefs = []
              TaskRef = None }
        let msg = Parser.generateMessage input
        let escapedMsg = msg.Replace("\"", "\\\"")
        let escapedDiff = diff.Replace("\"", "\\\"").Replace("\n", "\\n")
        toolResult $"""{{ "suggested_message": "{escapedMsg}", "staged_diff": "{escapedDiff}" }}"""

let private handleHistory (args: Map<string, obj>) : string =
    match getArgReq args "action" with
    | None -> invalidParams "Missing required parameter: action"
    | Some action ->
        match action with
        | "recent" ->
            let eventType = getArgOpt args "event_type" |> Option.defaultValue "commit"
            let limit =
                getArgOpt args "limit"
                |> Option.bind (fun s -> match Int32.TryParse s with true, n -> Some n | _ -> None)
                |> Option.defaultValue 20
            let events = History.queryByType eventType limit
            let eventsJson =
                events
                |> List.map (fun e ->
                    let ghsBefore = match e.GhsBefore with Some v -> $"{v:F4}" | None -> "null"
                    let ghsAfter = match e.GhsAfter with Some v -> $"{v:F4}" | None -> "null"
                    let delta = match e.Delta with Some v -> $"{v:F4}" | None -> "null"
                    $"""{{ "id": "{e.EventId}", "type": "{e.EventType}", "ghsBefore": {ghsBefore}, "ghsAfter": {ghsAfter}, "delta": {delta}, "timestamp": "{e.Timestamp:O}" }}""")
                |> String.concat ", "
            toolResult $"""{{ "action": "recent", "eventType": "{eventType}", "count": {events.Length}, "events": [{eventsJson}] }}"""

        | "velocity" ->
            let days =
                getArgOpt args "days"
                |> Option.bind (fun s -> match Int32.TryParse s with true, n -> Some n | _ -> None)
                |> Option.defaultValue 7
            let velocity = History.computeVelocity days
            toolResult $"""{{ "action": "velocity", "windowDays": {days}, "velocity": {velocity:F6} }}"""

        | "count" ->
            let count = History.getEventCount ()
            toolResult $"""{{ "action": "count", "totalEvents": {count} }}"""

        | "lineage" ->
            let events = History.exportLineage ()
            let limit =
                getArgOpt args "limit"
                |> Option.bind (fun s -> match Int32.TryParse s with true, n -> Some n | _ -> None)
                |> Option.defaultValue 100
            let truncated = events |> List.truncate limit
            let eventsJson =
                truncated
                |> List.map (fun e ->
                    $"""{{ "id": "{e.EventId}", "type": "{e.EventType}", "timestamp": "{e.Timestamp:O}" }}""")
                |> String.concat ", "
            toolResult $"""{{ "action": "lineage", "totalEvents": {events.Length}, "returned": {truncated.Length}, "events": [{eventsJson}] }}"""

        | unknown ->
            invalidParams $"Unknown history action: {unknown}. Use: recent, velocity, count, lineage"

// ─────────────────────────────────────────────────────────────────────────────
// Dispatch (mirrors SentinelTools.fs pattern)
// ─────────────────────────────────────────────────────────────────────────────

/// Dispatch a tool call. Returns Some(result) if tool matched, None otherwise.
let dispatch (toolName: string) (args: Map<string, obj>) : string option =
    match toolName with
    | "git_intel_analyze"  -> Some (handleAnalyze args)
    | "git_intel_validate" -> Some (handleValidate args)
    | "git_intel_health"   -> Some (handleHealth args)
    | "git_intel_suggest"  -> Some (handleSuggest args)
    | "git_intel_history"  -> Some (handleHistory args)
    | _ -> None

/// List all available tool names.
let listTools () : string list =
    toolDefinitions |> List.map (fun t -> t.Name)

/// Get tool definitions as JSON string.
let toolsToJson () : string =
    let toolsJson =
        toolDefinitions
        |> List.map (fun t ->
            $"""{{ "name": "{t.Name}", "description": "{t.Description.Replace("\"", "\\\"")}" }}""")
        |> String.concat ", "
    $"""{{ "tools": [{toolsJson}] }}"""
