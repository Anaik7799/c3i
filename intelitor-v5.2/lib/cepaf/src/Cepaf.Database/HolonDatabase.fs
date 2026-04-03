/// Unified Database Access for F# Holons.
///
/// WHAT: Single entry point for all F# holon database operations with direct
///       high-performance access to SQLite and DuckDB using MailboxProcessor.
///
/// WHY: SC-XHOLON-001 requires isolated database access per holon.
///      SC-XHOLON-002 mandates native high-performance libraries.
///
/// CONSTRAINTS:
///   - SC-XHOLON-001: Each holon has isolated database files
///   - SC-XHOLON-002: Direct access via Microsoft.Data.Sqlite/DuckDB.NET
///   - SC-XHOLON-010: Lock-free reads via OCC
///   - SC-XHOLON-020: SQLite read latency < 1ms
///   - SC-XHOLON-021: DuckDB query latency < 10ms
///   - SC-DBNAME-001: UHI-based database paths
///
/// ## Architecture
///
/// ```
/// HolonDatabase (MailboxProcessor)
///      │
///      ├── SQLitePool (ConnectionPool + Microsoft.Data.Sqlite)
///      │   └── state.sqlite, vectors.sqlite
///      │
///      └── DuckDBPool (ConnectionPool + DuckDB.NET)
///          └── analytics.duckdb, history.duckdb, register.duckdb
/// ```
///
/// ## Usage
///
/// ```fsharp
/// // Start database for a holon
/// let db = HolonDatabase.create "fs:l4:prj:agt:cockpit"
///
/// // Query SQLite
/// let! rows = db.Query(State, "SELECT * FROM config WHERE key = ?", ["setting"])
///
/// // Execute with version control
/// let! result = db.ExecuteCas(State, "INSERT INTO config VALUES (?, ?)", ["k"; "v"], expectedVersion)
/// ```
module Cepaf.Database.HolonDatabase

open System
open System.Collections.Generic
open System.Data
open System.IO
open Microsoft.Data.Sqlite
open Cepaf.Database.Types
open Cepaf.Database.ConnectionPool
open Cepaf.Database.HolonConcurrencyHandler
module DP = Cepaf.Holon.DatabasePath

// ============================================================================
// Types
// ============================================================================

/// Database type for holon access
type HolonDbType =
    | State     // state.sqlite (SQLite)
    | Vectors   // vectors.sqlite (SQLite)
    | Cache     // cache.sqlite (SQLite)
    | Analytics // analytics.duckdb (DuckDB)
    | History   // history.duckdb (DuckDB)
    | Register  // register.duckdb (DuckDB)

/// Query result as list of dictionaries
type QueryResult = IReadOnlyList<IReadOnlyDictionary<string, obj>>

/// Execute result
type ExecuteResult = {
    Changes: int
    LastInsertId: int64 option
    Version: VersionVector option
}

/// Database message for MailboxProcessor
type private HolonDbMessage =
    | Query of HolonDbType * string * obj list * AsyncReplyChannel<Result<QueryResult, string>>
    | Execute of HolonDbType * string * obj list * AsyncReplyChannel<Result<ExecuteResult, string>>
    | ExecuteCas of HolonDbType * string * obj list * VersionVector * AsyncReplyChannel<Result<ExecuteResult, string>>
    | Transaction of HolonDbType * (IDbConnection -> Result<obj, string>) * AsyncReplyChannel<Result<obj, string>>
    | GetVersionVector of AsyncReplyChannel<VersionVector>
    | GetStats of AsyncReplyChannel<HolonDbStats>
    | Shutdown of AsyncReplyChannel<unit>

/// Database statistics
and HolonDbStats = {
    Queries: int64
    Executes: int64
    Transactions: int64
    Conflicts: int64
    Errors: int64
    StartedAt: DateTime
    HolonId: string
}

// ============================================================================
// Configuration
// ============================================================================

/// Configuration for holon database
type HolonDbConfig = {
    HolonId: string
    PoolSize: int
    AcquireTimeout: TimeSpan
}

let defaultConfig holonId = {
    HolonId = holonId
    PoolSize = 5
    AcquireTimeout = TimeSpan.FromSeconds(5.0)
}

// ============================================================================
// SQLite Database Types
// ============================================================================

let private sqliteDbs = [State; Vectors; Cache]
let private duckdbDbs = [Analytics; History; Register]

let private dbTypeToFileType = function
    | State -> DP.DatabaseType.State
    | Vectors -> DP.DatabaseType.Vectors
    | Cache -> DP.DatabaseType.State  // Use state type for cache
    | Analytics -> DP.DatabaseType.Analytics
    | History -> DP.DatabaseType.History
    | Register -> DP.DatabaseType.Register

// ============================================================================
// Connection Helpers
// ============================================================================

/// Create SQLite connection factory
let private createSqliteConnection (path: string) () =
    Directory.CreateDirectory(Path.GetDirectoryName(path)) |> ignore
    let conn = new SqliteConnection($"Data Source={path};Mode=ReadWriteCreate")
    conn.Open()
    // Enable WAL mode for concurrent access
    use cmd = conn.CreateCommand()
    cmd.CommandText <- "PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000; PRAGMA foreign_keys=ON; PRAGMA synchronous=NORMAL"
    cmd.ExecuteNonQuery() |> ignore
    conn

/// Validate SQLite connection
let private validateSqliteConnection (conn: SqliteConnection) =
    try conn.State = ConnectionState.Open with _ -> false

/// Create DuckDB connection factory (placeholder - uses IDbConnection interface)
let private createDuckDbConnection (path: string) () =
    Directory.CreateDirectory(Path.GetDirectoryName(path)) |> ignore
    // Note: In production, use DuckDB.NET.Data.DuckDBConnection
    // For now, using placeholder that can be swapped
    let conn = new SqliteConnection($"Data Source={path}") :> IDbConnection
    conn.Open()
    conn

/// Validate DuckDB connection
let private validateDuckDbConnection (conn: IDbConnection) =
    try conn.State = ConnectionState.Open with _ -> false

// ============================================================================
// HolonDatabase Implementation
// ============================================================================

/// Holon database instance
type HolonDatabase private (config: HolonDbConfig, agent: MailboxProcessor<HolonDbMessage>) =

    /// Query the database
    member _.Query(dbType: HolonDbType, sql: string, ?parameters: obj list) : Async<Result<QueryResult, string>> =
        let params = defaultArg parameters []
        agent.PostAndAsyncReply(fun reply -> Query(dbType, sql, params, reply))

    /// Execute a write statement
    member _.Execute(dbType: HolonDbType, sql: string, ?parameters: obj list) : Async<Result<ExecuteResult, string>> =
        let params = defaultArg parameters []
        agent.PostAndAsyncReply(fun reply -> Execute(dbType, sql, params, reply))

    /// Execute with compare-and-swap (optimistic concurrency)
    member _.ExecuteCas(dbType: HolonDbType, sql: string, parameters: obj list, expectedVersion: VersionVector) : Async<Result<ExecuteResult, string>> =
        agent.PostAndAsyncReply(fun reply -> ExecuteCas(dbType, sql, parameters, expectedVersion, reply))

    /// Execute within a transaction
    member _.Transaction<'T>(dbType: HolonDbType, operation: IDbConnection -> Result<'T, string>) : Async<Result<'T, string>> = async {
        let boxedOp = fun conn ->
            match operation conn with
            | Ok result -> Ok (box result)
            | Error e -> Error e
        let! result = agent.PostAndAsyncReply(fun reply -> Transaction(dbType, boxedOp, reply))
        return
            match result with
            | Ok boxed -> Ok (unbox<'T> boxed)
            | Error e -> Error e
    }

    /// Get current version vector
    member _.GetVersionVector() : Async<VersionVector> =
        agent.PostAndAsyncReply(fun reply -> GetVersionVector reply)

    /// Get database statistics
    member _.GetStats() : Async<HolonDbStats> =
        agent.PostAndAsyncReply(fun reply -> GetStats reply)

    /// Shutdown the database
    member _.Shutdown() : Async<unit> =
        agent.PostAndAsyncReply(fun reply -> Shutdown reply)

    /// Holon ID
    member _.HolonId = config.HolonId

    /// Create a new HolonDatabase instance
    static member Create(holonId: string, ?poolSize: int, ?acquireTimeout: TimeSpan) : HolonDatabase =
        let config = {
            HolonId = holonId
            PoolSize = defaultArg poolSize 5
            AcquireTimeout = defaultArg acquireTimeout (TimeSpan.FromSeconds(5.0))
        }

        // Parse UHI
        let uhi =
            match DP.parseUHI holonId with
            | DP.Success u -> u
            | DP.Error e -> failwith $"Invalid holon ID: {e}"

        // Create pool configuration
        let poolConfig = {
            MaxConnections = config.PoolSize
            MinConnections = 1
            AcquireTimeout = config.AcquireTimeout
            IdleTimeout = TimeSpan.FromMinutes(5.0)
            ValidationQuery = Some "SELECT 1"
        }

        // Create SQLite pools
        let sqlitePools =
            sqliteDbs
            |> List.map (fun dbType ->
                let fqdn = DP.createFQDN uhi (dbTypeToFileType dbType)
                let path = DP.resolve fqdn
                let pool = new ConnectionPool<SqliteConnection>(
                    poolConfig,
                    createSqliteConnection path,
                    validateSqliteConnection
                )
                dbType, pool
            )
            |> dict

        // Create DuckDB pools (placeholder)
        let duckdbPools =
            duckdbDbs
            |> List.map (fun dbType ->
                let fqdn = DP.createFQDN uhi (dbTypeToFileType dbType)
                let path = DP.resolve fqdn
                let pool = new ConnectionPool<IDbConnection>(
                    poolConfig,
                    createDuckDbConnection path,
                    validateDuckDbConnection
                )
                dbType, pool
            )
            |> dict

        // Initialize state
        let mutable versionVectors = Map.ofList [
            "local", 0L
            holonId, 0L
        ]
        let mutable stats = {
            Queries = 0L
            Executes = 0L
            Transactions = 0L
            Conflicts = 0L
            Errors = 0L
            StartedAt = DateTime.UtcNow
            HolonId = holonId
        }

        // Helper to get pool
        let getPool dbType =
            if List.contains dbType sqliteDbs then
                match sqlitePools.TryGetValue(dbType) with
                | true, pool -> Some (Choice1Of2 pool)
                | false, _ -> None
            elif List.contains dbType duckdbDbs then
                match duckdbPools.TryGetValue(dbType) with
                | true, pool -> Some (Choice2Of2 pool)
                | false, _ -> None
            else
                None

        // Execute query helper
        let executeQuery dbType sql (parameters: obj list) = async {
            match getPool dbType with
            | None -> return Error $"Unknown database type: {dbType}"
            | Some poolChoice ->
                match poolChoice with
                | Choice1Of2 sqlitePool ->
                    let! maybeConn = sqlitePool.AcquireAsync(config.AcquireTimeout)
                    match maybeConn with
                    | None -> return Error "Failed to acquire SQLite connection"
                    | Some pooled ->
                        try
                            use cmd = pooled.Connection.CreateCommand()
                            cmd.CommandText <- sql

                            // Add parameters
                            for i, param in parameters |> List.indexed do
                                cmd.Parameters.AddWithValue($"@p{i}", param) |> ignore

                            use reader = cmd.ExecuteReader()
                            let results = List<IReadOnlyDictionary<string, obj>>()

                            while reader.Read() do
                                let row = Dictionary<string, obj>()
                                for i in 0 .. reader.FieldCount - 1 do
                                    let name = reader.GetName(i)
                                    let value = reader.GetValue(i)
                                    row.[name] <- if value :? DBNull then null else value
                                results.Add(row :> IReadOnlyDictionary<string, obj>)

                            sqlitePool.Release(pooled)
                            stats <- { stats with Queries = stats.Queries + 1L }
                            return Ok (results :> QueryResult)
                        with ex ->
                            sqlitePool.Release(pooled)
                            stats <- { stats with Errors = stats.Errors + 1L }
                            return Error $"Query failed: {ex.Message}"

                | Choice2Of2 duckdbPool ->
                    let! maybeConn = duckdbPool.AcquireAsync(config.AcquireTimeout)
                    match maybeConn with
                    | None -> return Error "Failed to acquire DuckDB connection"
                    | Some pooled ->
                        try
                            use cmd = pooled.Connection.CreateCommand()
                            cmd.CommandText <- sql

                            // Add parameters
                            for i, param in parameters |> List.indexed do
                                let p = cmd.CreateParameter()
                                p.ParameterName <- $"@p{i}"
                                p.Value <- param
                                cmd.Parameters.Add(p) |> ignore

                            use reader = cmd.ExecuteReader()
                            let results = List<IReadOnlyDictionary<string, obj>>()

                            while reader.Read() do
                                let row = Dictionary<string, obj>()
                                for i in 0 .. reader.FieldCount - 1 do
                                    let name = reader.GetName(i)
                                    let value = reader.GetValue(i)
                                    row.[name] <- if value :? DBNull then null else value
                                results.Add(row :> IReadOnlyDictionary<string, obj>)

                            duckdbPool.Release(pooled)
                            stats <- { stats with Queries = stats.Queries + 1L }
                            return Ok (results :> QueryResult)
                        with ex ->
                            duckdbPool.Release(pooled)
                            stats <- { stats with Errors = stats.Errors + 1L }
                            return Error $"Query failed: {ex.Message}"
        }

        // Execute write helper
        let executeWrite dbType sql (parameters: obj list) = async {
            match getPool dbType with
            | None -> return Error $"Unknown database type: {dbType}"
            | Some poolChoice ->
                match poolChoice with
                | Choice1Of2 sqlitePool ->
                    let! maybeConn = sqlitePool.AcquireAsync(config.AcquireTimeout)
                    match maybeConn with
                    | None -> return Error "Failed to acquire SQLite connection"
                    | Some pooled ->
                        try
                            use cmd = pooled.Connection.CreateCommand()
                            cmd.CommandText <- sql

                            // Add parameters
                            for i, param in parameters |> List.indexed do
                                cmd.Parameters.AddWithValue($"@p{i}", param) |> ignore

                            let changes = cmd.ExecuteNonQuery()

                            // Get last insert ID if applicable
                            use idCmd = pooled.Connection.CreateCommand()
                            idCmd.CommandText <- "SELECT last_insert_rowid()"
                            let lastId = idCmd.ExecuteScalar() |> Convert.ToInt64

                            // Update version
                            versionVectors <- increment versionVectors holonId

                            sqlitePool.Release(pooled)
                            stats <- { stats with Executes = stats.Executes + 1L }
                            return Ok {
                                Changes = changes
                                LastInsertId = Some lastId
                                Version = Some versionVectors
                            }
                        with ex ->
                            sqlitePool.Release(pooled)
                            stats <- { stats with Errors = stats.Errors + 1L }
                            return Error $"Execute failed: {ex.Message}"

                | Choice2Of2 duckdbPool ->
                    let! maybeConn = duckdbPool.AcquireAsync(config.AcquireTimeout)
                    match maybeConn with
                    | None -> return Error "Failed to acquire DuckDB connection"
                    | Some pooled ->
                        try
                            use cmd = pooled.Connection.CreateCommand()
                            cmd.CommandText <- sql

                            // Add parameters
                            for i, param in parameters |> List.indexed do
                                let p = cmd.CreateParameter()
                                p.ParameterName <- $"@p{i}"
                                p.Value <- param
                                cmd.Parameters.Add(p) |> ignore

                            let changes = cmd.ExecuteNonQuery()

                            // Update version
                            versionVectors <- increment versionVectors holonId

                            duckdbPool.Release(pooled)
                            stats <- { stats with Executes = stats.Executes + 1L }
                            return Ok {
                                Changes = changes
                                LastInsertId = None
                                Version = Some versionVectors
                            }
                        with ex ->
                            duckdbPool.Release(pooled)
                            stats <- { stats with Errors = stats.Errors + 1L }
                            return Error $"Execute failed: {ex.Message}"
        }

        // Create the MailboxProcessor agent
        let agent = MailboxProcessor.Start(fun inbox ->
            let rec loop () = async {
                let! msg = inbox.Receive()

                match msg with
                | Query (dbType, sql, parameters, reply) ->
                    let! result = executeQuery dbType sql parameters
                    reply.Reply(result)
                    return! loop()

                | Execute (dbType, sql, parameters, reply) ->
                    let! result = executeWrite dbType sql parameters
                    reply.Reply(result)
                    return! loop()

                | ExecuteCas (dbType, sql, parameters, expectedVersion, reply) ->
                    // Check version before executing
                    if versionGte versionVectors expectedVersion then
                        let! result = executeWrite dbType sql parameters
                        reply.Reply(result)
                    else
                        stats <- { stats with Conflicts = stats.Conflicts + 1L }
                        reply.Reply(Error "conflict")
                    return! loop()

                | Transaction (dbType, operation, reply) ->
                    match getPool dbType with
                    | None ->
                        reply.Reply(Error $"Unknown database type: {dbType}")
                        return! loop()
                    | Some poolChoice ->
                        match poolChoice with
                        | Choice1Of2 sqlitePool ->
                            let! maybeConn = sqlitePool.AcquireAsync(config.AcquireTimeout)
                            match maybeConn with
                            | None ->
                                reply.Reply(Error "Failed to acquire connection")
                                return! loop()
                            | Some pooled ->
                                try
                                    try
                                        use txn = pooled.Connection.BeginTransaction()
                                        let conn = pooled.Connection :> IDbConnection
                                        match operation conn with
                                        | Ok result ->
                                            txn.Commit()
                                            versionVectors <- increment versionVectors holonId
                                            stats <- { stats with Transactions = stats.Transactions + 1L }
                                            reply.Reply(Ok result)
                                        | Error e ->
                                            txn.Rollback()
                                            stats <- { stats with Errors = stats.Errors + 1L }
                                            reply.Reply(Error e)
                                    with ex ->
                                        stats <- { stats with Errors = stats.Errors + 1L }
                                        reply.Reply(Error $"Transaction failed: {ex.Message}")
                                finally
                                    sqlitePool.Release(pooled)
                                return! loop()

                        | Choice2Of2 duckdbPool ->
                            let! maybeConn = duckdbPool.AcquireAsync(config.AcquireTimeout)
                            match maybeConn with
                            | None ->
                                reply.Reply(Error "Failed to acquire connection")
                                return! loop()
                            | Some pooled ->
                                try
                                    try
                                        // DuckDB has limited transaction support
                                        let conn = pooled.Connection
                                        match operation conn with
                                        | Ok result ->
                                            versionVectors <- increment versionVectors holonId
                                            stats <- { stats with Transactions = stats.Transactions + 1L }
                                            reply.Reply(Ok result)
                                        | Error e ->
                                            stats <- { stats with Errors = stats.Errors + 1L }
                                            reply.Reply(Error e)
                                    with ex ->
                                        stats <- { stats with Errors = stats.Errors + 1L }
                                        reply.Reply(Error $"Transaction failed: {ex.Message}")
                                finally
                                    duckdbPool.Release(pooled)
                                return! loop()

                | GetVersionVector reply ->
                    reply.Reply(versionVectors)
                    return! loop()

                | GetStats reply ->
                    reply.Reply(stats)
                    return! loop()

                | Shutdown reply ->
                    // Dispose all pools
                    for kvp in sqlitePools do
                        (kvp.Value :> IDisposable).Dispose()
                    for kvp in duckdbPools do
                        (kvp.Value :> IDisposable).Dispose()
                    reply.Reply(())
                    // Don't loop, terminate
            }

            loop()
        )

        printfn "[HolonDatabase] Initialized database for holon: %s" holonId
        HolonDatabase(config, agent)

// ============================================================================
// Convenience Functions
// ============================================================================

/// Create a new holon database with default settings
let create holonId = HolonDatabase.Create(holonId)

/// Create a new holon database with custom settings
let createWithConfig holonId poolSize acquireTimeout =
    HolonDatabase.Create(holonId, poolSize, acquireTimeout)

// ============================================================================
// Telemetry
// ============================================================================

/// Emit telemetry event (placeholder for Zenoh integration)
let private emitTelemetry (operation: string) (holonId: string) (dbType: HolonDbType) (durationUs: int64) (success: bool) =
    printfn "[HolonDatabase] %s %s %A %dμs %s"
        operation
        holonId
        dbType
        durationUs
        (if success then "OK" else "ERROR")
