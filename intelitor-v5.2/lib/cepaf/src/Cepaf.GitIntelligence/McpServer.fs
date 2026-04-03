// =============================================================================
// Git Intelligence — MCP stdio JSON-RPC 2.0 Transport
// =============================================================================
// Purpose:  Serve git intelligence tools via MCP protocol over stdin/stdout.
//           Bridges McpTools.dispatch (Map<string,obj>) with JSON-RPC transport.
//           Inline protocol types — standalone, no ProjectReference to Cepaf.
//
// STAMP:    SC-MCP (tool dispatch), SC-FSH-017 (Result type errors)
// =============================================================================

module Cepaf.GitIntelligence.McpServer

open System
open System.IO
open System.Text.Json

// ─────────────────────────────────────────────────────────────────────────────
// I/O Helpers (stdout = protocol, stderr = diagnostics per MCP spec)
// ─────────────────────────────────────────────────────────────────────────────

let private respond (json: string) =
    Console.Out.WriteLine(json)
    Console.Out.Flush()

let private log (msg: string) =
    Console.Error.WriteLine($"[git-intel-mcp] {msg}")
    Console.Error.Flush()

// ─────────────────────────────────────────────────────────────────────────────
// JSON-RPC 2.0 Response Builders (Utf8JsonWriter for correctness)
// ─────────────────────────────────────────────────────────────────────────────

let private successResponse (id: JsonElement option) (resultJson: string) : string =
    use ms = new MemoryStream()
    use w = new Utf8JsonWriter(ms)
    w.WriteStartObject()
    w.WriteString("jsonrpc", "2.0")
    match id with
    | Some el -> w.WritePropertyName("id"); el.WriteTo(w)
    | None -> w.WriteNull("id")
    w.WritePropertyName("result")
    use doc = JsonDocument.Parse(resultJson)
    doc.RootElement.WriteTo(w)
    w.WriteEndObject()
    w.Flush()
    Text.Encoding.UTF8.GetString(ms.ToArray())

let private errorResponse (id: JsonElement option) (code: int) (message: string) : string =
    use ms = new MemoryStream()
    use w = new Utf8JsonWriter(ms)
    w.WriteStartObject()
    w.WriteString("jsonrpc", "2.0")
    match id with
    | Some el -> w.WritePropertyName("id"); el.WriteTo(w)
    | None -> w.WriteNull("id")
    w.WriteStartObject("error")
    w.WriteNumber("code", code)
    w.WriteString("message", message)
    w.WriteEndObject()
    w.WriteEndObject()
    w.Flush()
    Text.Encoding.UTF8.GetString(ms.ToArray())

let private toolResult (id: JsonElement option) (text: string) (isError: bool) : string =
    use ms = new MemoryStream()
    use w = new Utf8JsonWriter(ms)
    w.WriteStartObject()
    w.WriteString("jsonrpc", "2.0")
    match id with
    | Some el -> w.WritePropertyName("id"); el.WriteTo(w)
    | None -> w.WriteNull("id")
    w.WriteStartObject("result")
    w.WriteStartArray("content")
    w.WriteStartObject()
    w.WriteString("type", "text")
    w.WriteString("text", text)
    w.WriteEndObject()
    w.WriteEndArray()
    if isError then w.WriteBoolean("isError", true)
    w.WriteEndObject()
    w.WriteEndObject()
    w.Flush()
    Text.Encoding.UTF8.GetString(ms.ToArray())

// ─────────────────────────────────────────────────────────────────────────────
// JsonElement → Map<string, obj> Adapter
// ─────────────────────────────────────────────────────────────────────────────

/// Convert a JsonElement (from MCP params.arguments) to Map<string, obj>
/// that McpTools.dispatch expects.
let private jsonElementToMap (el: JsonElement option) : Map<string, obj> =
    match el with
    | None -> Map.empty
    | Some e when e.ValueKind <> JsonValueKind.Object -> Map.empty
    | Some e ->
        let mutable m = Map.empty<string, obj>
        for prop in e.EnumerateObject() do
            match prop.Value.ValueKind with
            | JsonValueKind.String -> m <- Map.add prop.Name (prop.Value.GetString() :> obj) m
            | JsonValueKind.Number -> m <- Map.add prop.Name (prop.Value.GetRawText() :> obj) m
            | JsonValueKind.True -> m <- Map.add prop.Name ("true" :> obj) m
            | JsonValueKind.False -> m <- Map.add prop.Name ("false" :> obj) m
            | _ -> m <- Map.add prop.Name (prop.Value.GetRawText() :> obj) m
        m

// ─────────────────────────────────────────────────────────────────────────────
// MCP Method Handlers
// ─────────────────────────────────────────────────────────────────────────────

let private handleInitialize (id: JsonElement option) =
    let result = """{"protocolVersion":"2024-11-05","capabilities":{"tools":{"listChanged":false}},"serverInfo":{"name":"git-intelligence","version":"1.0.0"}}"""
    respond (successResponse id result)

let private handleToolsList (id: JsonElement option) =
    // Build tools array from McpTools.toolDefinitions
    use ms = new MemoryStream()
    use w = new Utf8JsonWriter(ms)
    w.WriteStartObject()
    w.WriteStartArray("tools")
    for tool in McpTools.toolDefinitions do
        w.WriteStartObject()
        w.WriteString("name", tool.Name)
        w.WriteString("description", tool.Description)
        // Serialize InputSchema as raw JSON
        let schemaJson = System.Text.Json.JsonSerializer.Serialize(tool.InputSchema)
        w.WritePropertyName("inputSchema")
        use schemaDoc = JsonDocument.Parse(schemaJson)
        schemaDoc.RootElement.WriteTo(w)
        w.WriteEndObject()
    w.WriteEndArray()
    w.WriteEndObject()
    w.Flush()
    let resultJson = Text.Encoding.UTF8.GetString(ms.ToArray())
    respond (successResponse id resultJson)

let private handleToolsCall (id: JsonElement option) (toolName: string) (arguments: JsonElement option) =
    let args = jsonElementToMap arguments
    match McpTools.dispatch toolName args with
    | Some result ->
        log $"Tool '{toolName}' executed successfully"
        respond (toolResult id result false)
    | None ->
        log $"Unknown tool: {toolName}"
        respond (toolResult id $"Unknown tool: {toolName}" true)

// ─────────────────────────────────────────────────────────────────────────────
// Request Parser
// ─────────────────────────────────────────────────────────────────────────────

type private McpRequest =
    { Id: JsonElement option
      Method: string
      Params: JsonElement option }

let private parseRequest (line: string) : McpRequest option =
    try
        let doc = JsonDocument.Parse(line)
        let root = doc.RootElement
        let id =
            match root.TryGetProperty("id") with
            | true, el -> Some (el.Clone())
            | false, _ -> None
        let meth =
            match root.TryGetProperty("method") with
            | true, el -> el.GetString()
            | false, _ -> ""
        let parms =
            match root.TryGetProperty("params") with
            | true, el -> Some (el.Clone())
            | false, _ -> None
        Some { Id = id; Method = meth; Params = parms }
    with ex ->
        log $"Parse error: {ex.Message}"
        None

/// Extract tool name and arguments from params.
let private extractToolCall (parms: JsonElement option) : (string * JsonElement option) option =
    match parms with
    | None -> None
    | Some p ->
        match p.TryGetProperty("name") with
        | true, nameEl ->
            let name = nameEl.GetString()
            let args =
                match p.TryGetProperty("arguments") with
                | true, a -> Some (a.Clone())
                | false, _ -> None
            Some (name, args)
        | false, _ -> None

// ─────────────────────────────────────────────────────────────────────────────
// Main MCP Server Loop
// ─────────────────────────────────────────────────────────────────────────────

/// Start MCP stdio server. Blocks until stdin EOF.
let serve () : int =
    log "Starting Git Intelligence MCP server (JSON-RPC 2.0 stdio)"

    // Initialize holon state stores
    Store.initDb ()
    History.initDb () |> ignore

    log "Holon state stores initialized"

    let reader = Console.In
    let mutable running = true

    while running do
        let line = reader.ReadLine()
        if isNull line then
            running <- false
            log "EOF received, shutting down"
        else
            let trimmed = line.Trim()
            if trimmed.Length > 0 then
                match parseRequest trimmed with
                | None ->
                    respond (errorResponse None -32700 "Parse error")
                | Some req ->
                    match req.Method with
                    | "initialize" ->
                        log "Received initialize"
                        handleInitialize req.Id

                    | "notifications/initialized" ->
                        log "Client initialized"
                        // No response for notifications

                    | "tools/list" ->
                        log "Listing tools"
                        handleToolsList req.Id

                    | "tools/call" ->
                        match extractToolCall req.Params with
                        | Some (toolName, args) ->
                            log $"Calling tool: {toolName}"
                            handleToolsCall req.Id toolName args
                        | None ->
                            respond (errorResponse req.Id -32602 "Invalid tool call: missing name")

                    | "ping" ->
                        respond (successResponse req.Id """{}""")

                    | meth when meth.StartsWith("notifications/") ->
                        () // Silently ignore other notifications

                    | unknown ->
                        log $"Unknown method: {unknown}"
                        respond (errorResponse req.Id -32601 $"Method not found: {unknown}")

    Notify.closeSession()
    log "Git Intelligence MCP server stopped"
    0
