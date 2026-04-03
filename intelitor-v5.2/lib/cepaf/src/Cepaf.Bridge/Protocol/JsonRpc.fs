namespace Cepaf.Bridge.Protocol

open System
open System.Text.Json
open System.Text.Json.Serialization

/// JSON-RPC 2.0 Protocol Implementation
/// Reference: https://www.jsonrpc.org/specification
module JsonRpc =

    // ========================================================================
    // Error Codes (JSON-RPC 2.0 + Custom Application Codes)
    // ========================================================================

    /// Standard JSON-RPC 2.0 error codes
    [<RequireQualifiedAccess>]
    module ErrorCode =
        // Standard JSON-RPC errors (-32700 to -32600)
        let ParseError = -32700
        let InvalidRequest = -32600
        let MethodNotFound = -32601
        let InvalidParams = -32602
        let InternalError = -32603

        // Application-specific errors (-32099 to -32000)
        let SocketNotFound = -32001
        let ConnectionRefused = -32002
        let ConnectionTimeout = -32003
        let ContainerNotFound = -32004
        let ContainerAlreadyExists = -32005
        let ImageNotFound = -32006
        let HealthCheckFailed = -32007
        let SafetyViolation = -32008
        let NetworkNotFound = -32009
        let VolumeNotFound = -32010

    // ========================================================================
    // Request/Response Types
    // ========================================================================

    /// JSON-RPC Request
    type Request = {
        Jsonrpc: string
        Id: string option
        Method: string
        Params: JsonElement option
    }

    /// JSON-RPC Error
    type Error = {
        Code: int
        Message: string
        Data: JsonElement option
    }

    /// JSON-RPC Response
    type Response = {
        Jsonrpc: string
        Id: string option
        Result: JsonElement option
        Error: Error option
    }

    // ========================================================================
    // Parsing
    // ========================================================================

    let private jsonOptions =
        let opts = JsonSerializerOptions()
        opts.PropertyNamingPolicy <- JsonNamingPolicy.CamelCase
        opts.DefaultIgnoreCondition <- JsonIgnoreCondition.WhenWritingNull
        opts

    /// Parse a JSON-RPC request from string
    let parseRequest (json: string) : Result<Request, string> =
        try
            let doc = JsonDocument.Parse(json)
            let root = doc.RootElement

            let jsonrpc =
                match root.TryGetProperty("jsonrpc") with
                | true, prop -> prop.GetString()
                | false, _ -> ""

            if jsonrpc <> "2.0" then
                Error "Invalid JSON-RPC version (expected 2.0)"
            else
                let id =
                    match root.TryGetProperty("id") with
                    | true, prop when prop.ValueKind = JsonValueKind.String -> Some (prop.GetString())
                    | true, prop when prop.ValueKind = JsonValueKind.Number -> Some (prop.GetInt32().ToString())
                    | _ -> None

                let method' =
                    match root.TryGetProperty("method") with
                    | true, prop -> prop.GetString()
                    | false, _ -> ""

                if String.IsNullOrEmpty(method') then
                    Error "Missing method field"
                else
                    let params' =
                        match root.TryGetProperty("params") with
                        | true, prop -> Some (prop.Clone())
                        | false, _ -> None

                    Ok {
                        Jsonrpc = "2.0"
                        Id = id
                        Method = method'
                        Params = params'
                    }
        with ex ->
            Error (sprintf "JSON parse error: %s" ex.Message)

    // ========================================================================
    // Response Building
    // ========================================================================

    /// Build a success response
    let successResponse (id: string option) (result: 'T) : string =
        let resultJson = JsonSerializer.SerializeToElement(result, jsonOptions)
        let response = {|
            jsonrpc = "2.0"
            id = id
            result = resultJson
        |}
        JsonSerializer.Serialize(response, jsonOptions)

    /// Build an error response
    let errorResponse (id: string option) (code: int) (message: string) (data: obj option) : string =
        let errorObj =
            match data with
            | Some d ->
                {| code = code; message = message; data = d |}
            | None ->
                {| code = code; message = message; data = null |}

        let response = {|
            jsonrpc = "2.0"
            id = id
            error = errorObj
        |}
        JsonSerializer.Serialize(response, jsonOptions)

    /// Build a parse error response (no id available)
    let parseErrorResponse (message: string) : string =
        errorResponse None ErrorCode.ParseError message None

    /// Build a method not found response
    let methodNotFoundResponse (id: string option) (method': string) : string =
        errorResponse id ErrorCode.MethodNotFound (sprintf "Method not found: %s" method') None

    /// Build an invalid params response
    let invalidParamsResponse (id: string option) (reason: string) : string =
        errorResponse id ErrorCode.InvalidParams (sprintf "Invalid params: %s" reason) None

    /// Build an internal error response
    let internalErrorResponse (id: string option) (message: string) : string =
        errorResponse id ErrorCode.InternalError message None

    // ========================================================================
    // Parameter Extraction Helpers
    // ========================================================================

    /// Get string parameter from params object
    let getString (key: string) (params': JsonElement option) : Result<string, string> =
        match params' with
        | None -> Error (sprintf "Missing params.%s" key)
        | Some p ->
            match p.TryGetProperty(key) with
            | true, prop when prop.ValueKind = JsonValueKind.String ->
                Ok (prop.GetString())
            | _ ->
                Error (sprintf "Missing or invalid params.%s" key)

    /// Get optional string parameter
    let getStringOption (key: string) (params': JsonElement option) : string option =
        match params' with
        | None -> None
        | Some p ->
            match p.TryGetProperty(key) with
            | true, prop when prop.ValueKind = JsonValueKind.String ->
                Some (prop.GetString())
            | _ -> None

    /// Get integer parameter
    let getInt (key: string) (params': JsonElement option) : Result<int, string> =
        match params' with
        | None -> Error (sprintf "Missing params.%s" key)
        | Some p ->
            match p.TryGetProperty(key) with
            | true, prop when prop.ValueKind = JsonValueKind.Number ->
                Ok (prop.GetInt32())
            | _ ->
                Error (sprintf "Missing or invalid params.%s" key)

    /// Get optional integer parameter
    let getIntOption (key: string) (params': JsonElement option) : int option =
        match params' with
        | None -> None
        | Some p ->
            match p.TryGetProperty(key) with
            | true, prop when prop.ValueKind = JsonValueKind.Number ->
                Some (prop.GetInt32())
            | _ -> None

    /// Get boolean parameter with default
    let getBool (key: string) (defaultValue: bool) (params': JsonElement option) : bool =
        match params' with
        | None -> defaultValue
        | Some p ->
            match p.TryGetProperty(key) with
            | true, prop when prop.ValueKind = JsonValueKind.True -> true
            | true, prop when prop.ValueKind = JsonValueKind.False -> false
            | _ -> defaultValue
