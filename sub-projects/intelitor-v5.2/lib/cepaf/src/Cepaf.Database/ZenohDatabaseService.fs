/// Main Zenoh Database Service - Entry point for all database operations
/// SC-CONC-001: MailboxProcessor for message serialization
/// SC-BRIDGE-001: FIFO message ordering
/// SC-DBPROXY-001: All DB access via this service
module Cepaf.Database.ZenohDatabaseService

open System
open System.Collections.Concurrent
open System.Threading
open System.Threading.Tasks
open Cepaf.Database.Types
open Cepaf.Database.ConnectionPool
open Cepaf.Database.TransactionManager
open Cepaf.Database.DuckDBHandler
open Cepaf.Database.SQLiteHandler

/// Service statistics
type ServiceStats = {
    RequestsProcessed: int64
    RequestsFailed: int64
    AvgLatencyMs: float
    ActiveTransactions: int
    DuckDBPoolStats: PoolStats option
    SQLitePoolStats: PoolStats option
    UptimeSeconds: float
}

/// Message types for the agent mailbox
type DatabaseMessage =
    | ProcessRequest of DatabaseRequest * AsyncReplyChannel<DatabaseResponse>
    | GetStats of AsyncReplyChannel<ServiceStats>
    | Shutdown of AsyncReplyChannel<unit>

/// Zenoh Database Service with MailboxProcessor for concurrency
type ZenohDatabaseService(config: DatabaseServiceConfig) =

    // Start time for uptime tracking
    let startTime = DateTime.UtcNow

    // Statistics
    let mutable requestsProcessed = 0L
    let mutable requestsFailed = 0L
    let mutable totalLatencyMs = 0.0

    // Pool manager
    let poolManager = new PoolManager(config.DuckDBPoolConfig, config.SQLitePoolConfig)

    // Transaction manager
    let txnManager = new TransactionManager()

    // Request timeout
    let requestTimeout = TimeSpan.FromSeconds(5.0)

    // DuckDB handler (lazy init)
    let duckdbHandler = lazy (
        let pool = poolManager.GetDuckDBPool()
        DuckDBHandler(pool, config.DuckDBPath)
    )

    // SQLite handler (lazy init)
    let sqliteHandler = lazy (
        let pool = poolManager.GetSQLitePool()
        SQLiteHandler(pool, config.SQLitePath)
    )

    /// Process a database request
    let processRequest (request: DatabaseRequest) : Async<DatabaseResponse> =
        async {
            let startTime = DateTime.UtcNow

            try
                let! result =
                    match request.DbType, request.QueryType with
                    // DuckDB operations
                    | DuckDB, Select ->
                        async {
                            let! r = duckdbHandler.Value.Query(request.Sql, request.Params)
                            return r |> Result.map (fun rows -> rows :> obj)
                        }

                    | DuckDB, Insert ->
                        async {
                            let! r = duckdbHandler.Value.Execute(request.Sql, request.Params)
                            return r |> Result.map (fun affected -> affected :> obj)
                        }

                    | DuckDB, Update ->
                        async {
                            let! r = duckdbHandler.Value.Execute(request.Sql, request.Params)
                            return r |> Result.map (fun affected -> affected :> obj)
                        }

                    | DuckDB, Delete ->
                        async {
                            let! r = duckdbHandler.Value.Execute(request.Sql, request.Params)
                            return r |> Result.map (fun affected -> affected :> obj)
                        }

                    // SQLite operations
                    | SQLite, Select ->
                        async {
                            let! r = sqliteHandler.Value.Query(request.Sql, request.Params)
                            return r |> Result.map (fun rows -> rows :> obj)
                        }

                    | SQLite, Insert ->
                        async {
                            let! r = sqliteHandler.Value.Execute(request.Sql, request.Params)
                            return r |> Result.map (fun affected -> affected :> obj)
                        }

                    | SQLite, Update ->
                        async {
                            let! r = sqliteHandler.Value.Execute(request.Sql, request.Params)
                            return r |> Result.map (fun affected -> affected :> obj)
                        }

                    | SQLite, Delete ->
                        async {
                            let! r = sqliteHandler.Value.Execute(request.Sql, request.Params)
                            return r |> Result.map (fun affected -> affected :> obj)
                        }

                    // Transaction operations
                    | _, BeginTxn ->
                        async {
                            let isolation = Serializable  // Default to strictest
                            let result = txnManager.Begin(isolation, request.DbType, null)
                            return result |> Result.map (fun txnId -> txnId :> obj)
                        }

                    | _, CommitTxn ->
                        async {
                            match request.TransactionId with
                            | Some txnId ->
                                let result = txnManager.Commit(txnId)
                                return result |> Result.map (fun _ -> null :> obj)
                            | None ->
                                return Error "Transaction ID required"
                        }

                    | _, RollbackTxn ->
                        async {
                            match request.TransactionId with
                            | Some txnId ->
                                let result = txnManager.Rollback(txnId)
                                return result |> Result.map (fun _ -> null :> obj)
                            | None ->
                                return Error "Transaction ID required"
                        }

                    | _, Savepoint ->
                        async {
                            match request.TransactionId with
                            | Some txnId ->
                                let name = request.Sql  // Savepoint name in SQL field
                                let result = txnManager.CreateSavepoint(txnId, name)
                                return result |> Result.map (fun _ -> null :> obj)
                            | None ->
                                return Error "Transaction ID required"
                        }

                    | _, ReleaseSavepoint ->
                        async {
                            match request.TransactionId with
                            | Some txnId ->
                                let name = request.Sql
                                let result = txnManager.ReleaseSavepoint(txnId, name)
                                return result |> Result.map (fun _ -> null :> obj)
                            | None ->
                                return Error "Transaction ID required"
                        }

                    // Open/Close for SQLite connections
                    | SQLite, Open ->
                        async {
                            // Connection managed by pool, return success
                            return Ok ("connected" :> obj)
                        }

                    | SQLite, Close ->
                        async {
                            // Connection managed by pool, return success
                            return Ok ("closed" :> obj)
                        }

                    | _ ->
                        async {
                            return Error $"Unsupported operation: {request.DbType} {request.QueryType}"
                        }

                let elapsed = (DateTime.UtcNow - startTime).TotalMilliseconds
                Interlocked.Increment(&requestsProcessed) |> ignore
                totalLatencyMs <- totalLatencyMs + elapsed

                match result with
                | Ok value ->
                    return {
                        RequestId = request.RequestId
                        Success = true
                        Result = Some value
                        Error = None
                        RowsAffected = None
                        Timestamp = DateTime.UtcNow
                    }
                | Error msg ->
                    Interlocked.Increment(&requestsFailed) |> ignore
                    return {
                        RequestId = request.RequestId
                        Success = false
                        Result = None
                        Error = Some msg
                        RowsAffected = None
                        Timestamp = DateTime.UtcNow
                    }

            with ex ->
                Interlocked.Increment(&requestsFailed) |> ignore
                return {
                    RequestId = request.RequestId
                    Success = false
                    Result = None
                    Error = Some $"Exception: {ex.Message}"
                    RowsAffected = None
                    Timestamp = DateTime.UtcNow
                }
        }

    /// Get service statistics
    let getStats () : ServiceStats =
        let avgLatency =
            if requestsProcessed > 0L then
                totalLatencyMs / float requestsProcessed
            else 0.0

        {
            RequestsProcessed = requestsProcessed
            RequestsFailed = requestsFailed
            AvgLatencyMs = avgLatency
            ActiveTransactions = txnManager.ActiveCount
            DuckDBPoolStats = poolManager.Stats.DuckDB
            SQLitePoolStats = poolManager.Stats.SQLite
            UptimeSeconds = (DateTime.UtcNow - startTime).TotalSeconds
        }

    /// The main agent (MailboxProcessor) for serialized request processing
    /// SC-CONC-001: MailboxProcessor ensures FIFO ordering
    let agent = MailboxProcessor<DatabaseMessage>.Start(fun inbox ->
        let rec loop () = async {
            let! msg = inbox.Receive()
            match msg with
            | ProcessRequest (request, replyChannel) ->
                let! response = processRequest request
                replyChannel.Reply(response)
                return! loop()

            | GetStats replyChannel ->
                let stats = getStats()
                replyChannel.Reply(stats)
                return! loop()

            | Shutdown replyChannel ->
                // Cleanup
                txnManager.Dispose()
                poolManager.Dispose()
                replyChannel.Reply(())
                // Don't loop - shut down
        }
        loop()
    )

    /// Process a request (async)
    member _.ProcessRequestAsync(request: DatabaseRequest) : Async<DatabaseResponse> =
        agent.PostAndAsyncReply(fun ch -> ProcessRequest(request, ch))

    /// Process a request from JSON string
    member this.ProcessJsonRequest(json: string) : Async<string> =
        async {
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
                    Timestamp = DateTime.UtcNow
                }
                return ResponseSerializer.serialize errorResponse
        }

    /// Get statistics
    member _.GetStats() : ServiceStats =
        agent.PostAndReply(GetStats)

    /// Shutdown the service
    member _.Shutdown() : unit =
        agent.PostAndReply(Shutdown)

    /// Dispose
    member this.Dispose() =
        this.Shutdown()

    interface IDisposable with
        member this.Dispose() = this.Dispose()

/// Service factory
module ZenohDatabaseServiceFactory =

    /// Create service with default configuration
    let create () =
        new ZenohDatabaseService(ServiceDefaults.config)

    /// Create service with custom configuration
    let createWithConfig (config: DatabaseServiceConfig) =
        new ZenohDatabaseService(config)

/// Zenoh message handler integration
module ZenohMessageHandler =

    /// Handle incoming Zenoh message
    let handleMessage (service: ZenohDatabaseService) (topic: string) (payload: byte[]) : Async<byte[]> =
        async {
            let json = System.Text.Encoding.UTF8.GetString(payload)
            let! responseJson = service.ProcessJsonRequest(json)
            return System.Text.Encoding.UTF8.GetBytes(responseJson)
        }

    /// Extract database type from topic
    let getDbTypeFromTopic (topic: string) : DbType option =
        if topic.Contains("duckdb") then Some DuckDB
        elif topic.Contains("sqlite") then Some SQLite
        else None
