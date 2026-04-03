/// Zenoh Cross-Holon Database Bridge for F# holons.
///
/// WHAT: Handles incoming cross-holon database requests from Elixir holons
///       and routes them to the appropriate F# holon databases.
///
/// WHY: SC-XHOLON-003 requires cross-holon communication only via Zenoh.
///      SC-DBNAME-008 mandates Zenoh for cross-runtime access.
///
/// CONSTRAINTS:
///   - SC-XHOLON-003: Cross-holon access ONLY via Zenoh
///   - SC-XHOLON-025: Request timeout < 5s
///   - SC-XHOLON-026: Retry with exponential backoff
///   - SC-BRIDGE-001: FIFO message ordering
///   - SC-BRIDGE-003: Latency budget 50ms for local, 200ms for remote
///   - SC-BRIDGE-006: Request-response correlation via request_id
///
/// ## Topic Pattern
///
/// Request:  indrajaal/db/{source_runtime}/{source_holon}/request/{target_runtime}/{target_holon}/{db_type}
/// Response: indrajaal/db/{source_runtime}/{source_holon}/response/{request_id}
///
/// ## Message Flow
///
/// 1. Elixir holon publishes request to request topic
/// 2. F# bridge receives request
/// 3. F# bridge routes to appropriate HolonDatabase
/// 4. F# bridge publishes response to response topic
/// 5. Elixir bridge receives response
module Cepaf.Database.ZenohCrossHolonBridge

open System
open System.Collections.Concurrent
open System.Text.Json
open System.Threading
open Cepaf.Database.Types
open Cepaf.Database.HolonDatabase
open Cepaf.Database.HolonConcurrencyHandler

// ============================================================================
// Types
// ============================================================================

/// Incoming database request from remote holon
type CrossHolonRequest = {
    RequestId: string
    Source: string
    Target: string
    DbType: string
    Operation: string
    Sql: string
    Params: JsonElement list
    Version: VersionVector option
    Timestamp: DateTime
}

/// Response to remote holon
type CrossHolonResponse = {
    RequestId: string
    Success: bool
    Result: obj option
    Error: string option
    RowsAffected: int option
    Version: VersionVector option
    Conflict: bool
    Timestamp: DateTime
}

/// Bridge statistics
type BridgeStats = {
    RequestsReceived: int64
    ResponsesSent: int64
    Errors: int64
    AvgLatencyMs: float
    StartedAt: DateTime
}

/// Bridge message for MailboxProcessor
type private BridgeMessage =
    | ProcessRequest of CrossHolonRequest * AsyncReplyChannel<CrossHolonResponse>
    | GetStats of AsyncReplyChannel<BridgeStats>
    | RegisterDatabase of string * HolonDatabase
    | UnregisterDatabase of string
    | Shutdown of AsyncReplyChannel<unit>

// ============================================================================
// Request/Response Serialization
// ============================================================================

module RequestParser =
    let parseDbType (s: string) : HolonDbType option =
        match s.ToLower() with
        | "state" -> Some State
        | "vectors" -> Some Vectors
        | "cache" -> Some Cache
        | "analytics" -> Some Analytics
        | "history" -> Some History
        | "register" -> Some Register
        | _ -> None

    let parseRequest (json: string) : Result<CrossHolonRequest, string> =
        try
            let doc = JsonDocument.Parse(json)
            let root = doc.RootElement

            let requestId = root.GetProperty("request_id").GetString()
            let source = root.GetProperty("source").GetString()
            let target = root.GetProperty("target").GetString()
            let dbType = root.GetProperty("db_type").GetString()
            let operation = root.GetProperty("operation").GetString()
            let sql = root.GetProperty("sql").GetString()

            let mutable paramsEl = Unchecked.defaultof<JsonElement>
            let params =
                if root.TryGetProperty("params", &paramsEl) then
                    let paramsArray = root.GetProperty("params")
                    [ for i in 0 .. paramsArray.GetArrayLength() - 1 do
                        yield paramsArray.[i] ]
                else
                    []

            let mutable versionEl = Unchecked.defaultof<JsonElement>
            let version =
                if root.TryGetProperty("version", &versionEl) then
                    let versionObj = root.GetProperty("version")
                    if versionObj.ValueKind = JsonValueKind.Object then
                        let mutable result = Map.empty
                        for prop in versionObj.EnumerateObject() do
                            result <- Map.add prop.Name (prop.Value.GetInt64()) result
                        Some result
                    else None
                else None

            Ok {
                RequestId = requestId
                Source = source
                Target = target
                DbType = dbType
                Operation = operation
                Sql = sql
                Params = params
                Version = version
                Timestamp = DateTime.UtcNow
            }
        with ex ->
            Error $"Failed to parse request: {ex.Message}"

module ResponseSerializer =
    let serialize (response: CrossHolonResponse) : string =
        let options = JsonSerializerOptions(WriteIndented = false)

        let result =
            match response.Result with
            | Some r -> JsonSerializer.Serialize(r, options)
            | None -> "null"

        let error =
            match response.Error with
            | Some e -> $"\"{e}\""
            | None -> "null"

        let version =
            match response.Version with
            | Some v ->
                let pairs = v |> Map.toList |> List.map (fun (k, v) -> $"\"{k}\":{v}")
                "{" + String.Join(",", pairs) + "}"
            | None -> "null"

        $"""{{
            "request_id": "{response.RequestId}",
            "success": {response.Success.ToString().ToLower()},
            "result": {result},
            "error": {error},
            "rows_affected": {response.RowsAffected |> Option.defaultValue 0},
            "version": {version},
            "conflict": {response.Conflict.ToString().ToLower()},
            "timestamp": "{response.Timestamp:O}"
        }}"""

// ============================================================================
// ZenohCrossHolonBridge Implementation
// ============================================================================

/// Cross-Holon Database Bridge
type ZenohCrossHolonBridge() =

    // Registered holon databases
    let databases = ConcurrentDictionary<string, HolonDatabase>()

    // Statistics
    let mutable requestsReceived = 0L
    let mutable responsesSent = 0L
    let mutable errors = 0L
    let mutable totalLatencyMs = 0.0
    let startTime = DateTime.UtcNow

    /// Process a cross-holon request
    let processRequest (request: CrossHolonRequest) : Async<CrossHolonResponse> = async {
        let startTime = DateTime.UtcNow

        try
            // Find target database
            match databases.TryGetValue(request.Target) with
            | false, _ ->
                return {
                    RequestId = request.RequestId
                    Success = false
                    Result = None
                    Error = Some $"Target holon database not found: {request.Target}"
                    RowsAffected = None
                    Version = None
                    Conflict = false
                    Timestamp = DateTime.UtcNow
                }

            | true, db ->
                // Parse database type
                match RequestParser.parseDbType request.DbType with
                | None ->
                    return {
                        RequestId = request.RequestId
                        Success = false
                        Result = None
                        Error = Some $"Unknown database type: {request.DbType}"
                        RowsAffected = None
                        Version = None
                        Conflict = false
                        Timestamp = DateTime.UtcNow
                    }

                | Some dbType ->
                    // Convert params to obj list
                    let params =
                        request.Params
                        |> List.map (fun p ->
                            match p.ValueKind with
                            | JsonValueKind.String -> p.GetString() :> obj
                            | JsonValueKind.Number -> p.GetDouble() :> obj
                            | JsonValueKind.True -> true :> obj
                            | JsonValueKind.False -> false :> obj
                            | JsonValueKind.Null -> null :> obj
                            | _ -> p.ToString() :> obj
                        )

                    // Execute operation
                    match request.Operation.ToLower() with
                    | "query" ->
                        let! result = db.Query(dbType, request.Sql, params)
                        match result with
                        | Ok rows ->
                            return {
                                RequestId = request.RequestId
                                Success = true
                                Result = Some (rows :> obj)
                                Error = None
                                RowsAffected = None
                                Version = None
                                Conflict = false
                                Timestamp = DateTime.UtcNow
                            }
                        | Error e ->
                            return {
                                RequestId = request.RequestId
                                Success = false
                                Result = None
                                Error = Some e
                                RowsAffected = None
                                Version = None
                                Conflict = false
                                Timestamp = DateTime.UtcNow
                            }

                    | "execute" ->
                        let! result = db.Execute(dbType, request.Sql, params)
                        match result with
                        | Ok execResult ->
                            return {
                                RequestId = request.RequestId
                                Success = true
                                Result = None
                                Error = None
                                RowsAffected = Some execResult.Changes
                                Version = execResult.Version
                                Conflict = false
                                Timestamp = DateTime.UtcNow
                            }
                        | Error e ->
                            return {
                                RequestId = request.RequestId
                                Success = false
                                Result = None
                                Error = Some e
                                RowsAffected = None
                                Version = None
                                Conflict = false
                                Timestamp = DateTime.UtcNow
                            }

                    | "execute_cas" ->
                        match request.Version with
                        | None ->
                            return {
                                RequestId = request.RequestId
                                Success = false
                                Result = None
                                Error = Some "Version vector required for CAS operation"
                                RowsAffected = None
                                Version = None
                                Conflict = false
                                Timestamp = DateTime.UtcNow
                            }
                        | Some expectedVersion ->
                            let! result = db.ExecuteCas(dbType, request.Sql, params, expectedVersion)
                            match result with
                            | Ok execResult ->
                                return {
                                    RequestId = request.RequestId
                                    Success = true
                                    Result = None
                                    Error = None
                                    RowsAffected = Some execResult.Changes
                                    Version = execResult.Version
                                    Conflict = false
                                    Timestamp = DateTime.UtcNow
                                }
                            | Error "conflict" ->
                                let! currentVersion = db.GetVersionVector()
                                return {
                                    RequestId = request.RequestId
                                    Success = false
                                    Result = None
                                    Error = None
                                    RowsAffected = None
                                    Version = Some currentVersion
                                    Conflict = true
                                    Timestamp = DateTime.UtcNow
                                }
                            | Error e ->
                                return {
                                    RequestId = request.RequestId
                                    Success = false
                                    Result = None
                                    Error = Some e
                                    RowsAffected = None
                                    Version = None
                                    Conflict = false
                                    Timestamp = DateTime.UtcNow
                                }

                    | op ->
                        return {
                            RequestId = request.RequestId
                            Success = false
                            Result = None
                            Error = Some $"Unknown operation: {op}"
                            RowsAffected = None
                            Version = None
                            Conflict = false
                            Timestamp = DateTime.UtcNow
                        }

        with ex ->
            Interlocked.Increment(&errors) |> ignore
            return {
                RequestId = request.RequestId
                Success = false
                Result = None
                Error = Some $"Exception: {ex.Message}"
                RowsAffected = None
                Version = None
                Conflict = false
                Timestamp = DateTime.UtcNow
            }
    }

    /// Get statistics
    let getStats () : BridgeStats =
        let avgLatency =
            if requestsReceived > 0L then
                totalLatencyMs / float requestsReceived
            else 0.0

        {
            RequestsReceived = requestsReceived
            ResponsesSent = responsesSent
            Errors = errors
            AvgLatencyMs = avgLatency
            StartedAt = startTime
        }

    /// The main agent (MailboxProcessor)
    let agent = MailboxProcessor<BridgeMessage>.Start(fun inbox ->
        let rec loop () = async {
            let! msg = inbox.Receive()
            match msg with
            | ProcessRequest (request, replyChannel) ->
                Interlocked.Increment(&requestsReceived) |> ignore
                let start = DateTime.UtcNow
                let! response = processRequest request
                let elapsed = (DateTime.UtcNow - start).TotalMilliseconds
                totalLatencyMs <- totalLatencyMs + elapsed
                Interlocked.Increment(&responsesSent) |> ignore
                replyChannel.Reply(response)
                return! loop()

            | GetStats replyChannel ->
                let stats = getStats()
                replyChannel.Reply(stats)
                return! loop()

            | RegisterDatabase (holonId, db) ->
                databases.TryAdd(holonId, db) |> ignore
                printfn "[ZenohCrossHolonBridge] Registered database for holon: %s" holonId
                return! loop()

            | UnregisterDatabase holonId ->
                databases.TryRemove(holonId) |> ignore
                printfn "[ZenohCrossHolonBridge] Unregistered database for holon: %s" holonId
                return! loop()

            | Shutdown replyChannel ->
                printfn "[ZenohCrossHolonBridge] Shutting down..."
                // Shutdown all databases
                for kvp in databases do
                    kvp.Value.Shutdown() |> Async.RunSynchronously
                databases.Clear()
                replyChannel.Reply(())
                // Don't loop - terminate
        }

        loop()
    )

    /// Process request asynchronously
    member _.ProcessRequestAsync(request: CrossHolonRequest) : Async<CrossHolonResponse> =
        agent.PostAndAsyncReply(fun ch -> ProcessRequest(request, ch))

    /// Process request from JSON
    member this.ProcessJsonRequest(json: string) : Async<string> = async {
        match RequestParser.parseRequest json with
        | Ok request ->
            let! response = this.ProcessRequestAsync(request)
            return ResponseSerializer.serialize response
        | Error msg ->
            let errorResponse = {
                RequestId = Guid.NewGuid().ToString("N")
                Success = false
                Result = None
                Error = Some msg
                RowsAffected = None
                Version = None
                Conflict = false
                Timestamp = DateTime.UtcNow
            }
            return ResponseSerializer.serialize errorResponse
    }

    /// Register a holon database
    member _.RegisterDatabase(holonId: string, db: HolonDatabase) : unit =
        agent.Post(RegisterDatabase(holonId, db))

    /// Unregister a holon database
    member _.UnregisterDatabase(holonId: string) : unit =
        agent.Post(UnregisterDatabase holonId)

    /// Get statistics
    member _.GetStats() : BridgeStats =
        agent.PostAndReply(GetStats)

    /// Shutdown
    member _.Shutdown() : unit =
        agent.PostAndReply(Shutdown)

    /// Dispose
    member this.Dispose() =
        this.Shutdown()

    interface IDisposable with
        member this.Dispose() = this.Dispose()

// ============================================================================
// Zenoh Integration
// ============================================================================

module ZenohIntegration =
    /// Handle incoming Zenoh message
    let handleMessage (bridge: ZenohCrossHolonBridge) (topic: string) (payload: byte[]) : Async<byte[]> = async {
        let json = System.Text.Encoding.UTF8.GetString(payload)
        let! responseJson = bridge.ProcessJsonRequest(json)
        return System.Text.Encoding.UTF8.GetBytes(responseJson)
    }

    /// Build response topic from request
    let buildResponseTopic (request: CrossHolonRequest) : string =
        // Parse source UHI
        let parts = request.Source.Split(':')
        if parts.Length >= 5 then
            $"indrajaal/db/{parts.[0]}/{parts.[4]}/response/{request.RequestId}"
        else
            $"indrajaal/db/unknown/{request.Source}/response/{request.RequestId}"

    /// Build subscription pattern for F# holon
    let buildSubscriptionPattern (holonId: string) : string =
        let parts = holonId.Split(':')
        if parts.Length >= 5 then
            $"indrajaal/db/*/*/request/{parts.[0]}/{parts.[4]}/*"
        else
            $"indrajaal/db/*/*/request/fs/{holonId}/*"

// ============================================================================
// Factory
// ============================================================================

module ZenohCrossHolonBridgeFactory =
    /// Create a new bridge instance
    let create () = new ZenohCrossHolonBridge()

    /// Create and configure with databases
    let createWithDatabases (holonDbs: (string * HolonDatabase) list) =
        let bridge = new ZenohCrossHolonBridge()
        for (holonId, db) in holonDbs do
            bridge.RegisterDatabase(holonId, db)
        bridge
