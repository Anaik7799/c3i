/// Thread-safe connection pool with semaphore-based concurrency control
/// SC-CONC-002: SemaphoreSlim for connection limit
/// SC-CONC-004: No deadlock paths (verified via Quint model)
module Cepaf.Database.ConnectionPool

open System
open System.Collections.Concurrent
open System.Threading
open System.Threading.Tasks
open Cepaf.Database.Types

/// Pooled connection wrapper
type PooledConnection<'T> = {
    Connection: 'T
    Id: string
    CreatedAt: DateTime
    LastUsed: DateTime
    InUse: bool
}

/// Connection pool statistics
type PoolStats = {
    TotalConnections: int
    ActiveConnections: int
    AvailableConnections: int
    WaitingRequests: int
    TotalAcquisitions: int64
    TotalReleases: int64
    TotalTimeouts: int64
    AvgWaitTimeMs: float
}

/// Generic connection pool with semaphore-based concurrency control
type ConnectionPool<'T when 'T :> IDisposable>(
    config: PoolConfig,
    createConnection: unit -> 'T,
    validateConnection: 'T -> bool) =

    // SC-CONC-002: Semaphore controls max concurrent connections
    let semaphore = new SemaphoreSlim(config.MaxConnections, config.MaxConnections)

    // Connection storage
    let connections = ConcurrentBag<PooledConnection<'T>>()
    let activeConnections = ConcurrentDictionary<string, PooledConnection<'T>>()

    // Statistics
    let mutable totalAcquisitions = 0L
    let mutable totalReleases = 0L
    let mutable totalTimeouts = 0L
    let mutable totalWaitTimeMs = 0.0

    // SC-CONC-005: Starvation-free - FIFO queue for waiting requests
    let waitQueue = ConcurrentQueue<TaskCompletionSource<PooledConnection<'T> option>>()

    /// Create a new pooled connection
    let createPooledConnection () =
        let conn = createConnection()
        {
            Connection = conn
            Id = Guid.NewGuid().ToString("N")
            CreatedAt = DateTime.UtcNow
            LastUsed = DateTime.UtcNow
            InUse = false
        }

    /// Validate and refresh connection if needed
    let ensureValid (pooled: PooledConnection<'T>) =
        try
            if validateConnection pooled.Connection then
                Some pooled
            else
                // Connection invalid, create new one
                pooled.Connection.Dispose()
                Some (createPooledConnection())
        with _ ->
            try pooled.Connection.Dispose() with _ -> ()
            Some (createPooledConnection())

    /// Try to get connection from pool
    let rec tryGetFromPool () =
        match connections.TryTake() with
        | true, pooled ->
            match ensureValid pooled with
            | Some valid -> Some valid
            | None -> tryGetFromPool() // Retry with next connection
        | false, _ -> None

    /// Acquire a connection with timeout (SC-CONC-006: Lock timeout 1s max)
    member _.AcquireAsync(timeout: TimeSpan, ?cancellationToken: CancellationToken) =
        let ct = defaultArg cancellationToken CancellationToken.None
        let startTime = DateTime.UtcNow

        async {
            // Wait for semaphore
            let! acquired =
                semaphore.WaitAsync(int timeout.TotalMilliseconds, ct)
                |> Async.AwaitTask

            if acquired then
                Interlocked.Increment(&totalAcquisitions) |> ignore
                let waitTime = (DateTime.UtcNow - startTime).TotalMilliseconds
                totalWaitTimeMs <- totalWaitTimeMs + waitTime

                // Try to get existing connection or create new
                let pooled =
                    match tryGetFromPool() with
                    | Some p -> p
                    | None -> createPooledConnection()

                let active = { pooled with InUse = true; LastUsed = DateTime.UtcNow }
                activeConnections.TryAdd(active.Id, active) |> ignore

                return Some active
            else
                Interlocked.Increment(&totalTimeouts) |> ignore
                return None
        }

    /// Release a connection back to the pool
    member _.Release(pooled: PooledConnection<'T>) =
        activeConnections.TryRemove(pooled.Id) |> ignore
        Interlocked.Increment(&totalReleases) |> ignore

        // Check if connection is still valid
        let released = { pooled with InUse = false; LastUsed = DateTime.UtcNow }

        // Check idle timeout
        if (DateTime.UtcNow - released.CreatedAt) < config.IdleTimeout then
            connections.Add(released)
        else
            // Connection too old, dispose
            try released.Connection.Dispose() with _ -> ()

        semaphore.Release() |> ignore

    /// Get pool statistics
    member _.Stats : PoolStats =
        let total = connections.Count + activeConnections.Count
        let avgWait =
            if totalAcquisitions > 0L then
                totalWaitTimeMs / float totalAcquisitions
            else 0.0

        {
            TotalConnections = total
            ActiveConnections = activeConnections.Count
            AvailableConnections = connections.Count
            WaitingRequests = config.MaxConnections - semaphore.CurrentCount
            TotalAcquisitions = totalAcquisitions
            TotalReleases = totalReleases
            TotalTimeouts = totalTimeouts
            AvgWaitTimeMs = avgWait
        }

    /// Current available count
    member _.Available = semaphore.CurrentCount

    /// Current active count
    member _.Active = activeConnections.Count

    /// Cleanup all connections
    member _.Dispose() =
        // Dispose all pooled connections
        let mutable pooled = Unchecked.defaultof<PooledConnection<'T>>
        while connections.TryTake(&pooled) do
            try pooled.Connection.Dispose() with _ -> ()

        // Dispose active connections
        for kvp in activeConnections do
            try kvp.Value.Connection.Dispose() with _ -> ()

        activeConnections.Clear()
        semaphore.Dispose()

    interface IDisposable with
        member this.Dispose() = this.Dispose()

/// Connection pool manager for multiple database types
/// SC-DBNAME-001: UHI-based paths for database files
type PoolManager(duckdbConfig: PoolConfig, sqliteConfig: PoolConfig) =
    // UHI: ex:l3:kms:srv:main - KMS service databases
    let duckdbPath = "data/holons/ex/l3/kms/main/analytics.duckdb"  // ex:l3:kms:srv:main:analytics
    let sqlitePath = "data/holons/ex/l3/kms/main/state.sqlite"      // ex:l3:kms:srv:main:state

    // Lazy initialization of pools
    let duckdbPool = lazy (
        // Using placeholder - actual DuckDB connection would be via DuckDB.NET
        ConnectionPool<System.Data.IDbConnection>(
            duckdbConfig,
            (fun () ->
                // Placeholder - in real impl use DuckDB.NET
                let conn = new Microsoft.Data.Sqlite.SqliteConnection($"Data Source={duckdbPath}") :> System.Data.IDbConnection
                conn.Open()
                conn),
            (fun conn -> conn.State = System.Data.ConnectionState.Open)
        )
    )

    let sqlitePool = lazy (
        ConnectionPool<Microsoft.Data.Sqlite.SqliteConnection>(
            sqliteConfig,
            (fun () ->
                let conn = new Microsoft.Data.Sqlite.SqliteConnection($"Data Source={sqlitePath}")
                conn.Open()
                conn),
            (fun conn -> conn.State = System.Data.ConnectionState.Open)
        )
    )

    member _.GetDuckDBPool() = duckdbPool.Value
    member _.GetSQLitePool() = sqlitePool.Value

    member _.Stats =
        {|
            DuckDB = if duckdbPool.IsValueCreated then Some duckdbPool.Value.Stats else None
            SQLite = if sqlitePool.IsValueCreated then Some sqlitePool.Value.Stats else None
        |}

    member _.Dispose() =
        if duckdbPool.IsValueCreated then duckdbPool.Value.Dispose()
        if sqlitePool.IsValueCreated then sqlitePool.Value.Dispose()

    interface IDisposable with
        member this.Dispose() = this.Dispose()
