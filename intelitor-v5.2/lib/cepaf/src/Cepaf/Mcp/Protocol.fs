namespace Cepaf.Mcp

open System
open System.Text.Json
open System.Text.Json.Serialization

// --- MCP PROTOCOL TYPES ---

[<CLIMutable>]
type JsonRpcRequest = {
    [<JsonPropertyName("jsonrpc")>] JsonRpc: string
    [<JsonPropertyName("id")>] Id: JsonElement
    [<JsonPropertyName("method")>] Method: string
    [<JsonPropertyName("params")>] Params: JsonElement
}

[<CLIMutable>]
type JsonRpcResponse<'T> = {
    [<JsonPropertyName("jsonrpc")>] JsonRpc: string
    [<JsonPropertyName("id")>] Id: JsonElement
    [<JsonPropertyName("result")>] Result: 'T
}

[<CLIMutable>]
type JsonRpcErrorResponse = {
    [<JsonPropertyName("jsonrpc")>] JsonRpc: string
    [<JsonPropertyName("id")>] Id: JsonElement
    [<JsonPropertyName("error")>] Error: ErrorObject
}

and ErrorObject = {
    [<JsonPropertyName("code")>] Code: int
    [<JsonPropertyName("message")>] Message: string
}

// --- DOMAIN TYPES ---

[<CLIMutable>]
type Tool = {
    [<JsonPropertyName("name")>] Name: string
    [<JsonPropertyName("description")>] Description: string
    [<JsonPropertyName("inputSchema")>] InputSchema: obj
}

[<CLIMutable>]
type ToolListResult = {
    [<JsonPropertyName("tools")>] Tools: Tool list
}

[<CLIMutable>]
type TextContent = {
    [<JsonPropertyName("type")>] Type: string
    [<JsonPropertyName("text")>] Text: string
}

[<CLIMutable>]
type ToolCallResult = {
    [<JsonPropertyName("content")>] Content: TextContent list
    [<JsonPropertyName("isError")>] IsError: bool
}
