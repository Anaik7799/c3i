/// Cepaf.IndrajaalTest.HttpClient
/// HTTP client utilities for REST API testing
///
/// STAMP Constraints:
/// - SC-HTTP-001: All requests must include proper headers
/// - SC-HTTP-002: Timeout must be enforced on all requests
/// - SC-HTTP-003: Response must be validated before parsing
module Cepaf.IndrajaalTest.HttpClient

open System
open System.Net.Http
open System.Net.Http.Headers
open System.Text
open System.Text.Json
open System.Threading
open Cepaf.IndrajaalTest.Types

// =============================================================================
// HTTP Client Configuration
// =============================================================================

/// JSON serializer options
let jsonOptions =
    let options = JsonSerializerOptions()
    options.PropertyNamingPolicy <- JsonNamingPolicy.SnakeCaseLower
    options.PropertyNameCaseInsensitive <- true
    options.WriteIndented <- true
    options

/// Create HTTP client with default configuration
let createClient (config: ServerConfig) : HttpClient =
    let handler = new HttpClientHandler()
    if not config.UseSsl then
        handler.ServerCertificateCustomValidationCallback <-
            fun _ _ _ _ -> true

    let client = new HttpClient(handler)
    client.BaseAddress <- Uri(config.BaseUrl)
    client.Timeout <- config.Timeout
    client.DefaultRequestHeaders.Accept.Add(
        MediaTypeWithQualityHeaderValue("application/json"))
    client.DefaultRequestHeaders.Add("User-Agent", "Cepaf.IndrajaalTest/1.0")
    client

/// Add authorization header
let withAuth (token: string) (client: HttpClient) =
    client.DefaultRequestHeaders.Authorization <-
        AuthenticationHeaderValue("Bearer", token)
    client

/// Add tenant header
let withTenant (tenantId: string) (client: HttpClient) =
    if not (client.DefaultRequestHeaders.Contains("X-Tenant-ID")) then
        client.DefaultRequestHeaders.Add("X-Tenant-ID", tenantId)
    client

/// Add device header
let withDevice (deviceId: string) (client: HttpClient) =
    if not (client.DefaultRequestHeaders.Contains("X-Device-ID")) then
        client.DefaultRequestHeaders.Add("X-Device-ID", deviceId)
    client

// =============================================================================
// Request Building
// =============================================================================

/// Create JSON content
let jsonContent (data: 'T) : HttpContent =
    let json = JsonSerializer.Serialize(data, jsonOptions)
    new StringContent(json, Encoding.UTF8, "application/json")

/// Build query string from parameters
let buildQueryString (parameters: (string * string) list) : string =
    if List.isEmpty parameters then ""
    else
        parameters
        |> List.map (fun (k, v) -> sprintf "%s=%s" (Uri.EscapeDataString(k)) (Uri.EscapeDataString(v)))
        |> String.concat "&"
        |> sprintf "?%s"

// =============================================================================
// Response Handling
// =============================================================================

/// Extract headers from response
let extractHeaders (response: HttpResponseMessage) : Map<string, string> =
    response.Headers
    |> Seq.append response.Content.Headers
    |> Seq.map (fun h -> h.Key, String.Join(", ", h.Value))
    |> Map.ofSeq

/// Parse JSON response
let parseJson<'T> (content: string) : Result<'T, TestError> =
    try
        let result = JsonSerializer.Deserialize<'T>(content, jsonOptions)
        Ok result
    with
    | ex -> Error (ParseError (sprintf "Failed to parse JSON: %s" ex.Message))

/// Create API response from HTTP response
let toApiResponse<'T> (startTime: DateTime) (response: HttpResponseMessage) : Async<ApiResponse<'T>> =
    async {
        let! content = response.Content.ReadAsStringAsync() |> Async.AwaitTask
        let duration = DateTime.UtcNow - startTime
        let headers = extractHeaders response

        let data, error =
            if response.IsSuccessStatusCode then
                match parseJson<'T> content with
                | Ok data -> Some data, None
                | Error (ParseError msg) -> None, Some msg
                | _ -> None, Some "Unknown parse error"
            else
                None, Some content

        return {
            Success = response.IsSuccessStatusCode
            Data = data
            Error = error
            StatusCode = int response.StatusCode
            Headers = headers
            Duration = duration
        }
    }

// =============================================================================
// HTTP Methods
// =============================================================================

/// GET request
let get<'T> (client: HttpClient) (path: string) : Async<ApiResponse<'T>> =
    async {
        let startTime = DateTime.UtcNow
        try
            let! response = client.GetAsync(path) |> Async.AwaitTask
            return! toApiResponse<'T> startTime response
        with
        | :? TaskCanceledException ->
            return {
                Success = false
                Data = None
                Error = Some "Request timed out"
                StatusCode = 0
                Headers = Map.empty
                Duration = DateTime.UtcNow - startTime
            }
        | ex ->
            return {
                Success = false
                Data = None
                Error = Some ex.Message
                StatusCode = 0
                Headers = Map.empty
                Duration = DateTime.UtcNow - startTime
            }
    }

/// GET request with query parameters
let getWithQuery<'T> (client: HttpClient) (path: string) (queryParams: (string * string) list) : Async<ApiResponse<'T>> =
    let fullPath = path + buildQueryString queryParams
    get<'T> client fullPath

/// POST request
let post<'TReq, 'TRes> (client: HttpClient) (path: string) (data: 'TReq) : Async<ApiResponse<'TRes>> =
    async {
        let startTime = DateTime.UtcNow
        try
            use content = jsonContent data
            let! response = client.PostAsync(path, content) |> Async.AwaitTask
            return! toApiResponse<'TRes> startTime response
        with
        | :? TaskCanceledException ->
            return {
                Success = false
                Data = None
                Error = Some "Request timed out"
                StatusCode = 0
                Headers = Map.empty
                Duration = DateTime.UtcNow - startTime
            }
        | ex ->
            return {
                Success = false
                Data = None
                Error = Some ex.Message
                StatusCode = 0
                Headers = Map.empty
                Duration = DateTime.UtcNow - startTime
            }
    }

/// POST request without body
let postEmpty<'T> (client: HttpClient) (path: string) : Async<ApiResponse<'T>> =
    async {
        let startTime = DateTime.UtcNow
        try
            use content = new StringContent("", Encoding.UTF8, "application/json")
            let! response = client.PostAsync(path, content) |> Async.AwaitTask
            return! toApiResponse<'T> startTime response
        with
        | :? TaskCanceledException ->
            return {
                Success = false
                Data = None
                Error = Some "Request timed out"
                StatusCode = 0
                Headers = Map.empty
                Duration = DateTime.UtcNow - startTime
            }
        | ex ->
            return {
                Success = false
                Data = None
                Error = Some ex.Message
                StatusCode = 0
                Headers = Map.empty
                Duration = DateTime.UtcNow - startTime
            }
    }

/// PUT request
let put<'TReq, 'TRes> (client: HttpClient) (path: string) (data: 'TReq) : Async<ApiResponse<'TRes>> =
    async {
        let startTime = DateTime.UtcNow
        try
            use content = jsonContent data
            let! response = client.PutAsync(path, content) |> Async.AwaitTask
            return! toApiResponse<'TRes> startTime response
        with
        | :? TaskCanceledException ->
            return {
                Success = false
                Data = None
                Error = Some "Request timed out"
                StatusCode = 0
                Headers = Map.empty
                Duration = DateTime.UtcNow - startTime
            }
        | ex ->
            return {
                Success = false
                Data = None
                Error = Some ex.Message
                StatusCode = 0
                Headers = Map.empty
                Duration = DateTime.UtcNow - startTime
            }
    }

/// DELETE request
let delete<'T> (client: HttpClient) (path: string) : Async<ApiResponse<'T>> =
    async {
        let startTime = DateTime.UtcNow
        try
            let! response = client.DeleteAsync(path) |> Async.AwaitTask
            return! toApiResponse<'T> startTime response
        with
        | :? TaskCanceledException ->
            return {
                Success = false
                Data = None
                Error = Some "Request timed out"
                StatusCode = 0
                Headers = Map.empty
                Duration = DateTime.UtcNow - startTime
            }
        | ex ->
            return {
                Success = false
                Data = None
                Error = Some ex.Message
                StatusCode = 0
                Headers = Map.empty
                Duration = DateTime.UtcNow - startTime
            }
    }

// =============================================================================
// Health Check Helpers
// =============================================================================

/// Health check response type
type HealthCheckResponse = {
    status: string
    timestamp: string option
    checks: Map<string, obj> option
}

/// Check health endpoint
let checkHealth (client: HttpClient) (path: string) : Async<Result<HealthResponse, TestError>> =
    async {
        let! response = get<HealthCheckResponse> client path

        if response.Success then
            match response.Data with
            | Some data ->
                let status =
                    match data.status.ToLowerInvariant() with
                    | "healthy" | "ok" -> Healthy
                    | "ready" | "started" -> Healthy
                    | "unhealthy" | "error" -> Unhealthy
                    | "degraded" | "warning" -> Degraded
                    | _ -> Unknown

                return Ok {
                    Status = status
                    Timestamp =
                        data.timestamp
                        |> Option.map (fun s -> DateTime.Parse(s))
                        |> Option.defaultValue DateTime.UtcNow
                    Checks = []
                    Version = None
                }
            | None ->
                return Error (ParseError "Empty response body")
        else
            return Error (ServerError (response.StatusCode, response.Error |> Option.defaultValue "Unknown error"))
    }
