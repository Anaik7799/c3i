namespace Cepaf.Podman.Client

open System
open System.IO
open System.Net.Http
open System.Net.Sockets
open System.Threading
open System.Threading.Tasks
open Cepaf.Podman.Domain

/// Unix Domain Socket connection handler
module UnixSocket =

    /// Check if socket file exists
    let exists (path: string) : bool =
        File.Exists(path)

    /// Verify socket is accessible
    let verify (path: string) : PodmanResult<unit> =
        if not (exists path) then
            Error (PodmanError.SocketNotFound path)
        else
            try
                use socket = new Socket(AddressFamily.Unix, SocketType.Stream, ProtocolType.Unspecified)
                let endpoint = UnixDomainSocketEndPoint(path)
                socket.Connect(endpoint)
                socket.Close()
                Ok ()
            with
            | :? SocketException as ex ->
                Error (PodmanError.ConnectionRefused (sprintf "%s: %s" path ex.Message))
            | ex ->
                Error (PodmanError.InternalError ex.Message)

    /// Create socket connection callback for HttpClient
    let createConnectCallback (socketPath: string) =
        fun (context: SocketsHttpConnectionContext) (cancellationToken: CancellationToken) ->
            let socket = new Socket(AddressFamily.Unix, SocketType.Stream, ProtocolType.Unspecified)
            try
                let endpoint = UnixDomainSocketEndPoint(socketPath)
                socket.Connect(endpoint)
                ValueTask<Stream>(new NetworkStream(socket, ownsSocket = true) :> Stream)
            with ex ->
                socket.Dispose()
                raise ex

    /// Create HTTP client configured for Unix socket
    let createHttpClient (socketPath: string) (timeout: TimeSpan) : HttpClient =
        let handler = new SocketsHttpHandler(
            ConnectCallback = Func<SocketsHttpConnectionContext, CancellationToken, ValueTask<Stream>>(createConnectCallback socketPath),
            PooledConnectionLifetime = TimeSpan.FromMinutes(5.0),
            PooledConnectionIdleTimeout = TimeSpan.FromMinutes(2.0),
            MaxConnectionsPerServer = 10
        )

        let client = new HttpClient(handler)
        client.BaseAddress <- Uri("http://d/")
        client.Timeout <- timeout
        client

    /// Get default socket path for current environment
    let getDefaultPath () : string =
        let uid = Environment.GetEnvironmentVariable("UID")
        if String.IsNullOrEmpty(uid) || uid = "0" then
            "/run/podman/podman.sock"
        else
            sprintf "/run/user/%s/podman/podman.sock" uid

    /// Get socket path from config or auto-detect
    let getPath (socket: PodmanSocket) : string =
        PodmanSocket.getPath socket

    /// Auto-detect and verify socket
    let autoDetect () : PodmanResult<PodmanSocket> =
        let socket = PodmanSocket.detect ()
        let path = getPath socket
        match verify path with
        | Ok () -> Ok socket
        | Error e -> Error e

/// Unix socket-based HTTP message handler
type UnixSocketHandler(socketPath: string) =
    inherit HttpMessageHandler()

    let socket = new Socket(AddressFamily.Unix, SocketType.Stream, ProtocolType.Unspecified)
    let mutable isConnected = false

    let ensureConnected () =
        if not isConnected then
            let endpoint = UnixDomainSocketEndPoint(socketPath)
            socket.Connect(endpoint)
            isConnected <- true

    override this.SendAsync(request: HttpRequestMessage, cancellationToken: CancellationToken) =
        task {
            ensureConnected()

            // Build request
            let path = request.RequestUri.PathAndQuery
            let method = request.Method.Method

            let requestLine = sprintf "%s %s HTTP/1.1\r\n" method path
            let host = "Host: d\r\n"

            let! bodyBytes =
                if request.Content <> null then
                    request.Content.ReadAsByteArrayAsync()
                else
                    Task.FromResult(Array.empty<byte>)

            let contentLength =
                if bodyBytes.Length > 0 then
                    sprintf "Content-Length: %d\r\n" bodyBytes.Length
                else
                    ""

            let contentType =
                if request.Content <> null && request.Content.Headers.ContentType <> null then
                    sprintf "Content-Type: %s\r\n" (request.Content.Headers.ContentType.ToString())
                else
                    ""

            let headers = requestLine + host + contentLength + contentType + "\r\n"
            let headerBytes = System.Text.Encoding.ASCII.GetBytes(headers)

            // Send request
            let! _ = socket.SendAsync(ReadOnlyMemory(headerBytes), SocketFlags.None, cancellationToken)
            if bodyBytes.Length > 0 then
                let! _ = socket.SendAsync(ReadOnlyMemory(bodyBytes), SocketFlags.None, cancellationToken)
                ()

            // Read response
            let buffer = Array.zeroCreate<byte> 65536
            let! bytesRead = socket.ReceiveAsync(Memory(buffer), SocketFlags.None, cancellationToken)

            let responseText = System.Text.Encoding.UTF8.GetString(buffer, 0, bytesRead)

            // Parse response (simplified)
            let lines = responseText.Split([| "\r\n" |], StringSplitOptions.None)
            let statusLine = lines.[0]
            let statusParts = statusLine.Split(' ')
            let statusCode = int statusParts.[1]

            // Find body (after empty line)
            let bodyStart = responseText.IndexOf("\r\n\r\n")
            let body =
                if bodyStart >= 0 then
                    responseText.Substring(bodyStart + 4)
                else
                    ""

            let response = new HttpResponseMessage(enum<Net.HttpStatusCode> statusCode)
            response.Content <- new StringContent(body)
            return response
        }

    override this.Dispose(disposing: bool) =
        if disposing then
            socket.Dispose()
        base.Dispose(disposing)
