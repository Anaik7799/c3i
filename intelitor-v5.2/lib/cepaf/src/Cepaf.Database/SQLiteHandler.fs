/// SQLite handler for OLTP operations
/// SC-HOLON-001: All holon state in SQLite (WAL mode)
/// AOR-HOLON-001: SQLite for real-time state
module Cepaf.Database.SQLiteHandler

open System
open System.Collections.Generic
open Microsoft.Data.Sqlite
open Cepaf.Database.Types
open Cepaf.Database.ConnectionPool

/// SQLite query result
type SQLiteResult =
    | Rows of IReadOnlyList<IReadOnlyDictionary<string, obj>>
    | RowsAffected of int
    | LastInsertRowId of int64
    | Empty

/// SQLite handler with connection pooling and WAL mode
type SQLiteHandler(pool: ConnectionPool<SqliteConnection>, dbPath: string) =

    /// Ensure WAL mode is enabled
    let ensureWalMode (conn: SqliteConnection) =
        use cmd = conn.CreateCommand()
        cmd.CommandText <- "PRAGMA journal_mode=WAL"
        cmd.ExecuteNonQuery() |> ignore

    /// Execute a SELECT query
    member _.Query(sql: string, parameters: obj list, ?timeout: TimeSpan) : Async<DbResult<SQLiteResult>> =
        let timeout = defaultArg timeout (TimeSpan.FromSeconds(5.0))

        async {
            let! maybeConn = pool.AcquireAsync(timeout)

            match maybeConn with
            | Some pooled ->
                try
                    use cmd = pooled.Connection.CreateCommand()
                    cmd.CommandText <- sql
                    cmd.CommandTimeout <- int timeout.TotalSeconds

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

                    pool.Release(pooled)
                    return Ok (Rows (results :> IReadOnlyList<_>))
                with ex ->
                    pool.Release(pooled)
                    return Error $"Query failed: {ex.Message}"
            | None ->
                return Error "Failed to acquire connection from pool"
        }

    /// Execute an INSERT/UPDATE/DELETE command
    member _.Execute(sql: string, parameters: obj list, ?timeout: TimeSpan) : Async<DbResult<int>> =
        let timeout = defaultArg timeout (TimeSpan.FromSeconds(5.0))

        async {
            let! maybeConn = pool.AcquireAsync(timeout)

            match maybeConn with
            | Some pooled ->
                try
                    use cmd = pooled.Connection.CreateCommand()
                    cmd.CommandText <- sql
                    cmd.CommandTimeout <- int timeout.TotalSeconds

                    // Add parameters
                    for i, param in parameters |> List.indexed do
                        cmd.Parameters.AddWithValue($"@p{i}", param) |> ignore

                    let affected = cmd.ExecuteNonQuery()
                    pool.Release(pooled)
                    return Ok affected
                with ex ->
                    pool.Release(pooled)
                    return Error $"Execute failed: {ex.Message}"
            | None ->
                return Error "Failed to acquire connection from pool"
        }

    /// Insert and return last row ID
    member _.InsertReturningId(sql: string, parameters: obj list, ?timeout: TimeSpan) : Async<DbResult<int64>> =
        let timeout = defaultArg timeout (TimeSpan.FromSeconds(5.0))

        async {
            let! maybeConn = pool.AcquireAsync(timeout)

            match maybeConn with
            | Some pooled ->
                try
                    use cmd = pooled.Connection.CreateCommand()
                    cmd.CommandText <- sql + "; SELECT last_insert_rowid()"
                    cmd.CommandTimeout <- int timeout.TotalSeconds

                    // Add parameters
                    for i, param in parameters |> List.indexed do
                        cmd.Parameters.AddWithValue($"@p{i}", param) |> ignore

                    let result = cmd.ExecuteScalar()
                    pool.Release(pooled)
                    return Ok (Convert.ToInt64(result))
                with ex ->
                    pool.Release(pooled)
                    return Error $"Insert failed: {ex.Message}"
            | None ->
                return Error "Failed to acquire connection from pool"
        }

    /// Begin a transaction
    member _.BeginTransaction(isolationLevel: IsolationLevel, ?timeout: TimeSpan) : Async<DbResult<string * SqliteTransaction>> =
        let timeout = defaultArg timeout (TimeSpan.FromSeconds(5.0))

        async {
            let! maybeConn = pool.AcquireAsync(timeout)

            match maybeConn with
            | Some pooled ->
                try
                    let sqliteIsoLevel =
                        match isolationLevel with
                        | ReadUncommitted -> System.Data.IsolationLevel.ReadUncommitted
                        | ReadCommitted -> System.Data.IsolationLevel.ReadCommitted
                        | RepeatableRead -> System.Data.IsolationLevel.RepeatableRead
                        | Serializable -> System.Data.IsolationLevel.Serializable

                    let txn = pooled.Connection.BeginTransaction(sqliteIsoLevel)
                    let txnId = Guid.NewGuid().ToString("N")
                    return Ok (txnId, txn)
                with ex ->
                    pool.Release(pooled)
                    return Error $"BeginTransaction failed: {ex.Message}"
            | None ->
                return Error "Failed to acquire connection from pool"
        }

    /// KMS-specific: Get all keys
    member this.GetKMSKeys(?active: bool) : Async<DbResult<SQLiteResult>> =
        let whereClause =
            active
            |> Option.map (fun a -> if a then "WHERE active = 1" else "WHERE active = 0")
            |> Option.defaultValue ""

        let sql = $"SELECT * FROM kms_keys {whereClause}"
        async {
            return! this.Query(sql, [])
        }

    /// KMS-specific: Store a key
    member this.StoreKMSKey(keyId: string, algorithm: string, encryptedKey: byte[], ?metadata: string) : Async<DbResult<int>> =
        let meta = defaultArg metadata "{}"
        let sql = """
            INSERT INTO kms_keys (key_id, algorithm, encrypted_key, metadata, created_at, active)
            VALUES (@p0, @p1, @p2, @p3, @p4, 1)
        """
        async {
            return! this.Execute(sql, [keyId :> obj; algorithm; encryptedKey; meta; DateTime.UtcNow])
        }

    /// KMS-specific: Revoke a key
    member this.RevokeKMSKey(keyId: string) : Async<DbResult<int>> =
        let sql = "UPDATE kms_keys SET active = 0, revoked_at = @p1 WHERE key_id = @p0"
        async {
            return! this.Execute(sql, [keyId :> obj; DateTime.UtcNow])
        }

    /// Holon state: Get current state
    member this.GetHolonState(holonId: string) : Async<DbResult<SQLiteResult>> =
        let sql = "SELECT * FROM holon_state WHERE holon_id = @p0"
        async {
            return! this.Query(sql, [holonId :> obj])
        }

    /// Holon state: Update state
    member this.UpdateHolonState(holonId: string, state: string) : Async<DbResult<int>> =
        let sql = """
            INSERT OR REPLACE INTO holon_state (holon_id, state, updated_at)
            VALUES (@p0, @p1, @p2)
        """
        async {
            return! this.Execute(sql, [holonId :> obj; state; DateTime.UtcNow])
        }

    /// Get database statistics
    member this.GetStats() : Async<DbResult<SQLiteResult>> =
        let sql = """
            SELECT
                (SELECT COUNT(*) FROM kms_keys) as key_count,
                (SELECT COUNT(*) FROM kms_keys WHERE active = 1) as active_key_count,
                (SELECT COUNT(*) FROM holon_state) as holon_state_count
        """
        async {
            return! this.Query(sql, [])
        }

    /// Vacuum database (maintenance)
    member this.Vacuum() : Async<DbResult<int>> =
        async {
            return! this.Execute("VACUUM", [])
        }

    /// Checkpoint WAL (maintenance)
    member this.Checkpoint() : Async<DbResult<SQLiteResult>> =
        async {
            return! this.Query("PRAGMA wal_checkpoint(TRUNCATE)", [])
        }
