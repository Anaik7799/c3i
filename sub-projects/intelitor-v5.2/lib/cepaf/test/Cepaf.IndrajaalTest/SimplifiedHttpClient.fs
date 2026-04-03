/// Cepaf.IndrajaalTest.HttpClient
/// Simplified HTTP client for API testing
///
/// STAMP Constraints:
/// - SC-HTTP-001: All requests must include proper headers
/// - SC-HTTP-002: Timeouts must be enforced
module Cepaf.IndrajaalTest.HttpClient

open System
open System.Diagnostics
open System.Net.Http
open System.Text
open System.Text.Json
open Cepaf.IndrajaalTest.Types

// =============================================================================
// HTTP Client Creation
// =============================================================================

/// Create a new HTTP client for the given server config
let createClient (config: ServerConfig) : HttpClient =
    let handler = new HttpClientHandler()
    handler.ServerCertificateCustomValidationCallback <- fun _ _ _ _ -> true
    let client = new HttpClient(handler)
    client.BaseAddress <- Uri(config.BaseUrl)
    client.Timeout <- config.Timeout
    client.DefaultRequestHeaders.Add("Accept", "application/json")
    client.DefaultRequestHeaders.Add("User-Agent", "Cepaf.IndrajaalTest/1.0")
    client

/// Add authentication token to client
let withAuth (token: string) (client: HttpClient) : HttpClient =
    client.DefaultRequestHeaders.Remove("Authorization") |> ignore
    client.DefaultRequestHeaders.Add("Authorization", sprintf "Bearer %s" token)
    client

// =============================================================================
// JSON Serialization
// =============================================================================

let private jsonOptions =
    let opts = JsonSerializerOptions()
    opts.PropertyNamingPolicy <- JsonNamingPolicy.SnakeCaseLower
    opts.PropertyNameCaseInsensitive <- true
    opts

let private serialize<'T> (value: 'T) : string =
    JsonSerializer.Serialize(value, jsonOptions)

let private deserialize<'T> (json: string) : 'T option =
    try
        Some (JsonSerializer.Deserialize<'T>(json, jsonOptions))
    with
    | _ -> None

// =============================================================================
// HTTP Request Methods
// =============================================================================

/// Execute HTTP request and measure timing
let private executeRequest<'TResponse> (client: HttpClient) (request: HttpRequestMessage) : Async<ApiResponse<'TResponse>> =
    async {
        let stopwatch = Stopwatch.StartNew()
        try
            let! response = client.SendAsync(request) |> Async.AwaitTask
            stopwatch.Stop()

            let! content = response.Content.ReadAsStringAsync() |> Async.AwaitTask

            let headers =
                response.Headers
                |> Seq.map (fun kvp -> kvp.Key, String.Join(",", kvp.Value))
                |> Map.ofSeq

            let data =
                if response.IsSuccessStatusCode && not (String.IsNullOrEmpty(content)) then
                    deserialize<'TResponse> content
                else
                    None

            return {
                Success = response.IsSuccessStatusCode
                StatusCode = int response.StatusCode
                Data = data
                Error = if response.IsSuccessStatusCode then None else Some content
                Headers = headers
                ElapsedMs = stopwatch.ElapsedMilliseconds
            }
        with
        | :? AggregateException as ex ->
            stopwatch.Stop()
            return {
                Success = false
                StatusCode = 0
                Data = None
                Error = Some (sprintf "Connection error: %s" ex.InnerException.Message)
                Headers = Map.empty
                ElapsedMs = stopwatch.ElapsedMilliseconds
            }
        | :? HttpRequestException as ex ->
            stopwatch.Stop()
            return {
                Success = false
                StatusCode = 0
                Data = None
                Error = Some (sprintf "HTTP error: %s" ex.Message)
                Headers = Map.empty
                ElapsedMs = stopwatch.ElapsedMilliseconds
            }
        | :? OperationCanceledException ->
            stopwatch.Stop()
            return {
                Success = false
                StatusCode = 0
                Data = None
                Error = Some "Request timed out"
                Headers = Map.empty
                ElapsedMs = stopwatch.ElapsedMilliseconds
            }
        | ex ->
            stopwatch.Stop()
            return {
                Success = false
                StatusCode = 0
                Data = None
                Error = Some (sprintf "Unexpected error: %s" ex.Message)
                Headers = Map.empty
                ElapsedMs = stopwatch.ElapsedMilliseconds
            }
    }

/// GET request
let get<'TResponse> (client: HttpClient) (path: string) : Async<ApiResponse<'TResponse>> =
    async {
        use request = new HttpRequestMessage(HttpMethod.Get, path)
        return! executeRequest<'TResponse> client request
    }

/// GET request with query parameters
let getWithQuery<'TResponse> (client: HttpClient) (path: string) (queryParams: (string * string) list) : Async<ApiResponse<'TResponse>> =
    async {
        let query = queryParams |> List.map (fun (k, v) -> sprintf "%s=%s" k v) |> String.concat "&"
        let fullPath = if String.IsNullOrEmpty(query) then path else sprintf "%s?%s" path query
        use request = new HttpRequestMessage(HttpMethod.Get, fullPath)
        return! executeRequest<'TResponse> client request
    }

/// POST request with JSON body
let post<'TRequest, 'TResponse> (client: HttpClient) (path: string) (body: 'TRequest) : Async<ApiResponse<'TResponse>> =
    async {
        use request = new HttpRequestMessage(HttpMethod.Post, path)
        let json = serialize body
        request.Content <- new StringContent(json, Encoding.UTF8, "application/json")
        return! executeRequest<'TResponse> client request
    }

/// POST request without body
let postEmpty<'TResponse> (client: HttpClient) (path: string) : Async<ApiResponse<'TResponse>> =
    async {
        use request = new HttpRequestMessage(HttpMethod.Post, path)
        return! executeRequest<'TResponse> client request
    }

/// PUT request with JSON body
let put<'TRequest, 'TResponse> (client: HttpClient) (path: string) (body: 'TRequest) : Async<ApiResponse<'TResponse>> =
    async {
        use request = new HttpRequestMessage(HttpMethod.Put, path)
        let json = serialize body
        request.Content <- new StringContent(json, Encoding.UTF8, "application/json")
        return! executeRequest<'TResponse> client request
    }

/// DELETE request
let delete<'TResponse> (client: HttpClient) (path: string) : Async<ApiResponse<'TResponse>> =
    async {
        use request = new HttpRequestMessage(HttpMethod.Delete, path)
        return! executeRequest<'TResponse> client request
    }

/// PATCH request with JSON body
let patch<'TRequest, 'TResponse> (client: HttpClient) (path: string) (body: 'TRequest) : Async<ApiResponse<'TResponse>> =
    async {
        use request = new HttpRequestMessage(HttpMethod.Patch, path)
        let json = serialize body
        request.Content <- new StringContent(json, Encoding.UTF8, "application/json")
        return! executeRequest<'TResponse> client request
    }

// =============================================================================
// Convenience Methods
// =============================================================================

/// Check if endpoint is reachable
let ping (client: HttpClient) (path: string) : Async<bool> =
    async {
        let! response = get<obj> client path
        return response.StatusCode > 0 && response.StatusCode < 500
    }

/// Check response time
let measureLatency (client: HttpClient) (path: string) : Async<int64> =
    async {
        let! response = get<obj> client path
        return response.ElapsedMs
    }
