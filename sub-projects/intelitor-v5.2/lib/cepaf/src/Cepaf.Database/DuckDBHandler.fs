/// DuckDB handler for analytical queries
/// SC-HOLON-002: All holon history in DuckDB
/// SC-STORE-001: Append-only for history
module Cepaf.Database.DuckDBHandler

open System
open System.Collections.Generic
open System.Data
open Cepaf.Database.Types
open Cepaf.Database.ConnectionPool

/// DuckDB query result
type DuckDBResult =
    | Rows of IReadOnlyList<IReadOnlyDictionary<string, obj>>
    | RowsAffected of int
    | Empty

/// DuckDB handler with connection pooling
type DuckDBHandler(pool: ConnectionPool<IDbConnection>, dbPath: string) =

    /// Execute a SELECT query
    member _.Query(sql: string, parameters: obj list, ?timeout: TimeSpan) : Async<DbResult<DuckDBResult>> =
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
                        let p = cmd.CreateParameter()
                        p.ParameterName <- $"@p{i}"
                        p.Value <- param
                        cmd.Parameters.Add(p) |> ignore

                    let affected = cmd.ExecuteNonQuery()
                    pool.Release(pooled)
                    return Ok affected
                with ex ->
                    pool.Release(pooled)
                    return Error $"Execute failed: {ex.Message}"
            | None ->
                return Error "Failed to acquire connection from pool"
        }

    /// Insert into a table (SC-STORE-001: Append-only)
    member this.Insert(table: string, record: IDictionary<string, obj>, ?timeout: TimeSpan) : Async<DbResult<int>> =
        let columns = String.Join(", ", record.Keys)
        let placeholders = String.Join(", ", record.Keys |> Seq.mapi (fun i _ -> $"@p{i}"))
        let sql = $"INSERT INTO {table} ({columns}) VALUES ({placeholders})"
        let parameters = record.Values |> Seq.toList

        async {
            return! this.Execute(sql, parameters, ?timeout = timeout)
        }

    /// Append to holon history (SC-HOLON-002)
    member this.AppendHistory(holonId: string, eventType: string, data: string, ?timestamp: DateTime) : Async<DbResult<int>> =
        let ts = defaultArg timestamp DateTime.UtcNow
        let sql = """
            INSERT INTO holon_history (holon_id, event_type, data, timestamp)
            VALUES (@p0, @p1, @p2, @p3)
        """
        async {
            return! this.Execute(sql, [holonId :> obj; eventType; data; ts])
        }

    /// Query holon history
    member this.GetHistory(holonId: string, ?limit: int, ?since: DateTime) : Async<DbResult<DuckDBResult>> =
        let limitClause = limit |> Option.map (fun l -> $"LIMIT {l}") |> Option.defaultValue ""
        let sinceClause =
            since
            |> Option.map (fun s -> $"AND timestamp >= @p1")
            |> Option.defaultValue ""

        let sql = $"""
            SELECT * FROM holon_history
            WHERE holon_id = @p0 {sinceClause}
            ORDER BY timestamp DESC
            {limitClause}
        """

        let parameters =
            match since with
            | Some s -> [holonId :> obj; s]
            | None -> [holonId :> obj]

        async {
            return! this.Query(sql, parameters)
        }

    /// Get all vectors for semantic search
    member this.GetVectors(?limit: int) : Async<DbResult<DuckDBResult>> =
        let limitClause = limit |> Option.map (fun l -> $"LIMIT {l}") |> Option.defaultValue ""
        let sql = $"SELECT uuid, embedding FROM vectors {limitClause}"

        async {
            return! this.Query(sql, [])
        }

    /// Get database statistics
    member this.GetStats() : Async<DbResult<DuckDBResult>> =
        let sql = """
            SELECT
                (SELECT COUNT(*) FROM holons) as holon_count,
                (SELECT COUNT(*) FROM holon_history) as history_count,
                (SELECT COUNT(*) FROM vectors) as vector_count,
                (SELECT COUNT(*) FROM relations) as relation_count
        """
        async {
            return! this.Query(sql, [])
        }

    /// Vacuum database (maintenance)
    member this.Vacuum() : Async<DbResult<int>> =
        async {
            return! this.Execute("VACUUM", [])
        }
