namespace Cepaf.Sentinel.MCP.Protocol

open System
open System.Text.Json
open System.Text.Json.Serialization

/// MCP (Model Context Protocol) JSON-RPC 2.0 implementation for Claude Code.
///
/// Implements the MCP server protocol over stdio:
///   - initialize / notifications/initialized handshake
///   - tools/list (tool discovery)
///   - tools/call (tool execution)
///
/// STAMP: SC-ZEN-001 (Zenoh unified IPC), SC-PRAJNA-004 (Sentinel integration)
/// AOR: AOR-SYNC-007 (Sentinel health sync)
module McpProtocol =

    let private jsonOptions =
        let opts = JsonSerializerOptions()
        opts.PropertyNamingPolicy <- JsonNamingPolicy.CamelCase
        opts.DefaultIgnoreCondition <- JsonIgnoreCondition.WhenWritingNull
        opts.WriteIndented <- false
        opts

    // ═══════════════════════════════════════════════════════════════════
    // TYPES
    // ═══════════════════════════════════════════════════════════════════

    /// Parsed MCP/JSON-RPC request
    type McpRequest = {
        Id: JsonElement option
        Method: string
        Params: JsonElement option
    }

    /// Tool input schema property
    type SchemaProperty = {
        Type: string
        Description: string
        Enum: string list option
        Default: string option
    }

    /// Tool definition for tools/list
    type ToolDefinition = {
        Name: string
        Description: string
        InputSchema: obj
    }

    // ═══════════════════════════════════════════════════════════════════
    // PARSING
    // ═══════════════════════════════════════════════════════════════════

    /// Parse a JSON-RPC 2.0 request from a line
    let parseRequest (line: string) : Result<McpRequest, string> =
        try
            let doc = JsonDocument.Parse(line)
            let root = doc.RootElement

            let jsonrpc =
                match root.TryGetProperty("jsonrpc") with
                | true, p -> p.GetString()
                | _ -> ""

            if jsonrpc <> "2.0" then
                Error "Invalid JSON-RPC version"
            else
                let id =
                    match root.TryGetProperty("id") with
                    | true, p when p.ValueKind <> JsonValueKind.Null -> Some (p.Clone())
                    | _ -> None

                let method' =
                    match root.TryGetProperty("method") with
                    | true, p -> p.GetString()
                    | _ -> ""

                let params' =
                    match root.TryGetProperty("params") with
                    | true, p -> Some (p.Clone())
                    | _ -> None

                Ok { Id = id; Method = method'; Params = params' }
        with ex ->
            Error (sprintf "Parse error: %s" ex.Message)

    // ═══════════════════════════════════════════════════════════════════
    // RESPONSE BUILDERS
    // ═══════════════════════════════════════════════════════════════════

    /// Build a JSON-RPC 2.0 success response
    let successResponse (id: JsonElement option) (result: obj) : string =
        use stream = new IO.MemoryStream()
        use writer = new Utf8JsonWriter(stream)
        writer.WriteStartObject()
        writer.WriteString("jsonrpc", "2.0")

        // Write id
        match id with
        | Some idElem ->
            writer.WritePropertyName("id")
            idElem.WriteTo(writer)
        | None ->
            writer.WriteNull("id")

        // Write result
        writer.WritePropertyName("result")
        let resultJson = JsonSerializer.SerializeToElement(result, jsonOptions)
        resultJson.WriteTo(writer)

        writer.WriteEndObject()
        writer.Flush()
        Text.Encoding.UTF8.GetString(stream.ToArray())

    /// Build a JSON-RPC 2.0 error response
    let errorResponse (id: JsonElement option) (code: int) (message: string) : string =
        use stream = new IO.MemoryStream()
        use writer = new Utf8JsonWriter(stream)
        writer.WriteStartObject()
        writer.WriteString("jsonrpc", "2.0")

        match id with
        | Some idElem ->
            writer.WritePropertyName("id")
            idElem.WriteTo(writer)
        | None ->
            writer.WriteNull("id")

        writer.WriteStartObject("error")
        writer.WriteNumber("code", code)
        writer.WriteString("message", message)
        writer.WriteEndObject()

        writer.WriteEndObject()
        writer.Flush()
        Text.Encoding.UTF8.GetString(stream.ToArray())

    let methodNotFound (id: JsonElement option) (method': string) =
        errorResponse id -32601 (sprintf "Method not found: %s" method')

    let invalidParams (id: JsonElement option) (reason: string) =
        errorResponse id -32602 (sprintf "Invalid params: %s" reason)

    let internalError (id: JsonElement option) (message: string) =
        errorResponse id -32603 message

    // ═══════════════════════════════════════════════════════════════════
    // INITIALIZE RESPONSE
    // ═══════════════════════════════════════════════════════════════════

    /// Build the MCP initialize response with server capabilities
    let initializeResponse (id: JsonElement option) : string =
        let result = {|
            protocolVersion = "2025-03-26"
            capabilities = {|
                tools = {| listChanged = false |}
            |}
            serverInfo = {|
                name = "indrajaal-sentinel-zenoh"
                version = "21.2.1"
            |}
        |}
        successResponse id result

    // ═══════════════════════════════════════════════════════════════════
    // TOOL CONTENT BUILDERS
    // ═══════════════════════════════════════════════════════════════════

    /// Build a tools/call text content response
    let toolResult (id: JsonElement option) (text: string) : string =
        let result = {|
            content = [| {| ``type`` = "text"; text = text |} |]
        |}
        successResponse id result

    /// Build a tools/call error content response (isError = true)
    let toolError (id: JsonElement option) (text: string) : string =
        let result = {|
            content = [| {| ``type`` = "text"; text = text |} |]
            isError = true
        |}
        successResponse id result

    // ═══════════════════════════════════════════════════════════════════
    // PARAM EXTRACTION
    // ═══════════════════════════════════════════════════════════════════

    /// Extract tool name and arguments from tools/call params
    let extractToolCall (params': JsonElement option) : Result<string * JsonElement option, string> =
        match params' with
        | None -> Error "Missing params"
        | Some p ->
            match p.TryGetProperty("name") with
            | true, name when name.ValueKind = JsonValueKind.String ->
                let args =
                    match p.TryGetProperty("arguments") with
                    | true, a -> Some (a.Clone())
                    | _ -> None
                Ok (name.GetString(), args)
            | _ -> Error "Missing params.name"

    /// Get a string from tool arguments
    let getArg (key: string) (args: JsonElement option) : Result<string, string> =
        match args with
        | None -> Error (sprintf "Missing argument: %s" key)
        | Some a ->
            match a.TryGetProperty(key) with
            | true, p when p.ValueKind = JsonValueKind.String -> Ok (p.GetString())
            | _ -> Error (sprintf "Missing or invalid argument: %s" key)

    /// Get an optional string from tool arguments
    let getArgOpt (key: string) (args: JsonElement option) : string option =
        match args with
        | None -> None
        | Some a ->
            match a.TryGetProperty(key) with
            | true, p when p.ValueKind = JsonValueKind.String -> Some (p.GetString())
            | _ -> None

    /// Get an integer from tool arguments with default
    let getArgInt (key: string) (defaultVal: int) (args: JsonElement option) : int =
        match args with
        | None -> defaultVal
        | Some a ->
            match a.TryGetProperty(key) with
            | true, p when p.ValueKind = JsonValueKind.Number ->
                try p.GetInt32() with _ -> defaultVal
            | _ -> defaultVal
