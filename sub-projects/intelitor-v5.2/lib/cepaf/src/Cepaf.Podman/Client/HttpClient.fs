namespace Cepaf.Podman.Client

open System
open System.Collections.Generic
open System.IO
open System.Net.Http
open System.Text
open System.Threading
open System.Threading.Tasks
open Cepaf.Podman.Domain

/// Podman HTTP client wrapper
type PodmanClient = {
    HttpClient: HttpClient
    Config: PodmanClientConfig
    BasePath: string
}

/// HTTP client operations
module HttpClient =

    // ========================================================================
    // Client Creation
    // ========================================================================

    /// Create Podman client from config
    let create (config: PodmanClientConfig) : PodmanResult<PodmanClient> =
        let socketPath = PodmanSocket.getPath config.Socket
        match UnixSocket.verify socketPath with
        | Error e -> Error e
        | Ok () ->
            let httpClient = UnixSocket.createHttpClient socketPath config.Timeout
            Ok {
                HttpClient = httpClient
                Config = config
                BasePath = sprintf "/v%s/libpod" config.ApiVersion
            }

    /// Create client with default config
    let createDefault () : PodmanResult<PodmanClient> =
        create PodmanClientConfig.defaultConfig

    /// Create client with custom socket path
    let createWithSocket (socketPath: string) : PodmanResult<PodmanClient> =
        let socket =
            if socketPath.Contains("/run/user/") then
                PodmanSocket.Rootless ("", socketPath)
            else
                PodmanSocket.Rootful socketPath
        let config = PodmanClientConfig.defaultConfig |> PodmanClientConfig.withSocket socket
        create config

    /// Dispose client
    let dispose (client: PodmanClient) : unit =
        client.HttpClient.Dispose()

    // ========================================================================
    // URL Building
    // ========================================================================

    /// Build full URL for endpoint
    let buildUrl (client: PodmanClient) (endpoint: string) : string =
        client.BasePath + endpoint

    /// URL encode a value
    let urlEncode (value: string) : string =
        Uri.EscapeDataString(value)

    /// Build query string from parameters
    let buildQueryString (params': (string * string) list) : string =
        if params'.IsEmpty then
            ""
        else
            "?" + String.concat "&" [
                for (key, value) in params' ->
                    sprintf "%s=%s" key (urlEncode value)
            ]

    // ========================================================================
    // HTTP Operations
    // ========================================================================

    /// GET request returning raw response body
    let getRaw (client: PodmanClient) (endpoint: string) : AsyncPodmanResult<string> = async {
        try
            let url = buildUrl client endpoint
            let! response = client.HttpClient.GetAsync(url) |> Async.AwaitTask
            let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask

            match int response.StatusCode with
            | code when code >= 200 && code < 300 ->
                return Ok body
            | 304 ->
                return Ok "{}"  // Not modified
            | 404 ->
                return Error (PodmanError.NotFound ("resource", endpoint))
            | 409 ->
                return Error (PodmanError.Conflict ("resource", body))
            | code ->
                return Error (PodmanError.ApiError (code, body))
        with
        | :? TaskCanceledException ->
            return Error (PodmanError.ConnectionTimeout ("GET " + endpoint, int64 client.Config.Timeout.TotalMilliseconds))
        | :? HttpRequestException as ex ->
            return Error (PodmanError.ConnectionRefused ex.Message)
        | ex ->
            return Error (PodmanError.InternalError ex.Message)
    }

    /// GET request with JSON parsing
    let get<'T> (client: PodmanClient) (endpoint: string) (parser: string -> PodmanResult<'T>) : AsyncPodmanResult<'T> = async {
        let! result = getRaw client endpoint
        return result |> Result.bind parser
    }

    /// POST request with optional body
    let post (client: PodmanClient) (endpoint: string) (body: string option) : AsyncPodmanResult<string> = async {
        try
            let url = buildUrl client endpoint
            let content =
                match body with
                | Some json -> new StringContent(json, Encoding.UTF8, "application/json") :> HttpContent
                | None -> null

            let! response = client.HttpClient.PostAsync(url, content) |> Async.AwaitTask
            let! responseBody = response.Content.ReadAsStringAsync() |> Async.AwaitTask

            match int response.StatusCode with
            | code when code >= 200 && code < 300 ->
                return Ok responseBody
            | 304 ->
                return Ok "{}"  // Already in desired state
            | 404 ->
                return Error (PodmanError.NotFound ("resource", endpoint))
            | 409 ->
                return Error (PodmanError.Conflict ("resource", responseBody))
            | code ->
                return Error (PodmanError.ApiError (code, responseBody))
        with
        | :? TaskCanceledException ->
            return Error (PodmanError.ConnectionTimeout ("POST " + endpoint, int64 client.Config.Timeout.TotalMilliseconds))
        | :? HttpRequestException as ex ->
            return Error (PodmanError.ConnectionRefused ex.Message)
        | ex ->
            return Error (PodmanError.InternalError ex.Message)
    }

    /// POST request without body
    let postEmpty (client: PodmanClient) (endpoint: string) : AsyncPodmanResult<string> =
        post client endpoint None

    /// POST request with JSON body
    let postJson (client: PodmanClient) (endpoint: string) (json: string) : AsyncPodmanResult<string> =
        post client endpoint (Some json)

    /// DELETE request
    let delete (client: PodmanClient) (endpoint: string) : AsyncPodmanResult<unit> = async {
        try
            let url = buildUrl client endpoint
            let! response = client.HttpClient.DeleteAsync(url) |> Async.AwaitTask

            match int response.StatusCode with
            | code when code >= 200 && code < 300 ->
                return Ok ()
            | 304 ->
                return Ok ()  // Already gone
            | 404 ->
                return Ok ()  // Already gone - treat as success
            | 409 ->
                let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                return Error (PodmanError.Conflict ("resource", body))
            | code ->
                let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                return Error (PodmanError.ApiError (code, body))
        with
        | :? TaskCanceledException ->
            return Error (PodmanError.ConnectionTimeout ("DELETE " + endpoint, int64 client.Config.Timeout.TotalMilliseconds))
        | :? HttpRequestException as ex ->
            return Error (PodmanError.ConnectionRefused ex.Message)
        | ex ->
            return Error (PodmanError.InternalError ex.Message)
    }

    /// PUT request with JSON body
    let put (client: PodmanClient) (endpoint: string) (json: string) : AsyncPodmanResult<string> = async {
        try
            let url = buildUrl client endpoint
            let content = new StringContent(json, Encoding.UTF8, "application/json")
            let! response = client.HttpClient.PutAsync(url, content) |> Async.AwaitTask
            let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask

            match int response.StatusCode with
            | code when code >= 200 && code < 300 ->
                return Ok body
            | 304 ->
                return Ok "{}"
            | 404 ->
                return Error (PodmanError.NotFound ("resource", endpoint))
            | 409 ->
                return Error (PodmanError.Conflict ("resource", body))
            | code ->
                return Error (PodmanError.ApiError (code, body))
        with
        | :? TaskCanceledException ->
            return Error (PodmanError.ConnectionTimeout ("PUT " + endpoint, int64 client.Config.Timeout.TotalMilliseconds))
        | :? HttpRequestException as ex ->
            return Error (PodmanError.ConnectionRefused ex.Message)
        | ex ->
            return Error (PodmanError.InternalError ex.Message)
    }

    // ========================================================================
    // Streaming Operations
    // ========================================================================

    /// GET request that streams response line by line
    let getStream (client: PodmanClient) (endpoint: string) (cancellationToken: CancellationToken) : IAsyncEnumerable<PodmanResult<string>> =
        { new IAsyncEnumerable<PodmanResult<string>> with
            member _.GetAsyncEnumerator(ct) =
                let combinedCt = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, ct).Token
                let url = buildUrl client endpoint

                let mutable reader: StreamReader option = None
                let mutable response: HttpResponseMessage option = None
                let mutable current: PodmanResult<string> = Error PodmanError.OperationCancelled

                { new IAsyncEnumerator<PodmanResult<string>> with
                    member _.Current = current

                    member self.MoveNextAsync() =
                        ValueTask<bool>(task {
                            try
                                // Initialize stream on first call
                                if reader.IsNone then
                                    let! resp = client.HttpClient.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, combinedCt)
                                    response <- Some resp
                                    let! stream = resp.Content.ReadAsStreamAsync(combinedCt)
                                    reader <- Some (new StreamReader(stream))

                                match reader with
                                | Some r when not r.EndOfStream ->
                                    let! line = r.ReadLineAsync(combinedCt).AsTask()
                                    if not (String.IsNullOrEmpty(line)) then
                                        current <- Ok line
                                        return true
                                    else
                                        return! self.MoveNextAsync().AsTask()
                                | _ ->
                                    return false
                            with
                            | :? OperationCanceledException ->
                                current <- Error PodmanError.OperationCancelled
                                return false
                            | ex ->
                                current <- Error (PodmanError.InternalError ex.Message)
                                return false
                        })

                    member _.DisposeAsync() =
                        ValueTask(task {
                            match reader with
                            | Some r -> r.Dispose()
                            | None -> ()
                            match response with
                            | Some r -> r.Dispose()
                            | None -> ()
                        })
                }
        }

    // ========================================================================
    // Utility Operations
    // ========================================================================

    /// Ping the API to check connectivity
    let ping (client: PodmanClient) : AsyncPodmanResult<bool> = async {
        try
            let! response = client.HttpClient.GetAsync("/_ping") |> Async.AwaitTask
            return Ok response.IsSuccessStatusCode
        with ex ->
            return Error (PodmanError.ConnectionRefused ex.Message)
    }

    /// Get API version info
    let version (client: PodmanClient) : AsyncPodmanResult<VersionInfo> = async {
        let! result = getRaw client "/version"
        return result |> Result.bind (fun json ->
            try
                let doc = System.Text.Json.JsonDocument.Parse(json)
                let root = doc.RootElement
                Ok {
                    Version = Serialization.getString "Version" "" root
                    ApiVersion = Serialization.getString "APIVersion" "" root
                    GoVersion = Serialization.getString "GoVersion" "" root
                    GitCommit = Serialization.getString "GitCommit" "" root
                    Built = Serialization.tryGetString "Built" root |> Option.bind Serialization.parseDateTimeOffset
                    OsArch = Serialization.getString "OsArch" "" root
                }
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    // ========================================================================
    // Retry Logic
    // ========================================================================

    /// Execute operation with retry
    let withRetry (client: PodmanClient) (operation: unit -> AsyncPodmanResult<'T>) : AsyncPodmanResult<'T> =
        let rec loop attempt = async {
            let! result = operation ()
            match result with
            | Ok value -> return Ok value
            | Error e when PodmanError.isRetryable e && attempt < client.Config.RetryCount ->
                do! Async.Sleep (int client.Config.RetryDelay.TotalMilliseconds)
                return! loop (attempt + 1)
            | Error e -> return Error e
        }
        loop 0
