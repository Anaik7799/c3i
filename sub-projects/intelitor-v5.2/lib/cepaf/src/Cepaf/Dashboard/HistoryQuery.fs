namespace Cepaf.Dashboard

open System
open System.Threading.Tasks
open Microsoft.Data.Sqlite

/// Historical Log Query Interface for CEPAF Cockpit
///
/// ## Features
/// - Time-range based queries
/// - Level and domain filtering
/// - Pagination support
/// - Aggregation queries
/// - Export to various formats
///
/// ## STAMP Constraints
/// - SC-GUI-HIS-001: Query timeout <30s
/// - SC-GUI-HIS-002: Max 100,000 results per query
/// - SC-GUI-HIS-003: Connection pooling
///
/// ## Note
/// In production, this connects to TimescaleDB via PostgreSQL.
/// For standalone mode, uses SQLite for local history.
module HistoryQuery =

    // ========================================================================
    // TYPES
    // ========================================================================

    /// Query result entry
    type HistoricalLogEntry = {
        Id: string
        Timestamp: DateTimeOffset
        HlcTimestamp: int64 option
        Level: string
        Domain: string
        Module: string option
        Function: string option
        Message: string
        Metadata: Map<string, string>
        TraceId: string option
        SpanId: string option
        Node: string option
    }

    /// Query parameters
    type QueryParams = {
        StartTime: DateTimeOffset option
        EndTime: DateTimeOffset option
        Levels: string list option
        Domains: string list option
        SearchPattern: string option
        TraceId: string option
        Limit: int
        Offset: int
        OrderBy: string
        OrderDesc: bool
    }

    /// Query result
    type QueryResult = {
        Entries: HistoricalLogEntry list
        TotalCount: int
        HasMore: bool
        QueryTimeMs: float
        FromCache: bool
    }

    /// Aggregation result
    type AggregationResult = {
        Period: string
        Count: int64
        ByLevel: Map<string, int64>
        ByDomain: Map<string, int64>
    }

    /// Connection configuration
    type ConnectionConfig = {
        ConnectionString: string
        MaxRetries: int
        TimeoutSeconds: int
        UsePooling: bool
    }

    // ========================================================================
    // DEFAULTS
    // ========================================================================

    /// Default query parameters
    let defaultParams = {
        StartTime = Some (DateTimeOffset.UtcNow.AddHours(-1.0))
        EndTime = Some DateTimeOffset.UtcNow
        Levels = None
        Domains = None
        SearchPattern = None
        TraceId = None
        Limit = 100
        Offset = 0
        OrderBy = "timestamp"
        OrderDesc = true
    }

    /// Default connection config (SQLite for standalone)
    let defaultConfig = {
        ConnectionString = "Data Source=data/fractal_logs.db"
        MaxRetries = 3
        TimeoutSeconds = 30
        UsePooling = true
    }

    // ========================================================================
    // STATE
    // ========================================================================

    let mutable private config = defaultConfig
    let mutable private isInitialized = false

    // ========================================================================
    // INITIALIZATION
    // ========================================================================

    /// Initialize the query interface
    let initialize (cfg: ConnectionConfig) =
        config <- cfg
        isInitialized <- true

        // Create SQLite database if not exists
        if config.ConnectionString.Contains("sqlite") || config.ConnectionString.Contains("Data Source") then
            use conn = new SqliteConnection(config.ConnectionString)
            conn.Open()

            let createTableSql = """
                CREATE TABLE IF NOT EXISTS fractal_logs (
                    id TEXT PRIMARY KEY,
                    timestamp TEXT NOT NULL,
                    hlc_timestamp INTEGER,
                    level TEXT NOT NULL,
                    domain TEXT,
                    module TEXT,
                    function TEXT,
                    message TEXT,
                    metadata TEXT,
                    trace_id TEXT,
                    span_id TEXT,
                    node TEXT
                );
                CREATE INDEX IF NOT EXISTS idx_timestamp ON fractal_logs(timestamp);
                CREATE INDEX IF NOT EXISTS idx_level ON fractal_logs(level);
                CREATE INDEX IF NOT EXISTS idx_domain ON fractal_logs(domain);
                CREATE INDEX IF NOT EXISTS idx_trace_id ON fractal_logs(trace_id);
            """

            use cmd = new SqliteCommand(createTableSql, conn)
            cmd.ExecuteNonQuery() |> ignore

        printfn "[HistoryQuery] Initialized with %s" config.ConnectionString

    /// Initialize with default configuration
    let initializeDefault () =
        initialize defaultConfig

    // ========================================================================
    // QUERY FUNCTIONS
    // ========================================================================

    /// Execute a query with parameters
    let queryAsync (queryParams: QueryParams) = async {
        let start = DateTimeOffset.UtcNow

        use conn = new SqliteConnection(config.ConnectionString)
        do! conn.OpenAsync() |> Async.AwaitTask

        // Build WHERE clause
        let conditions = ResizeArray<string>()
        let parameters = ResizeArray<SqliteParameter>()

        match queryParams.StartTime with
        | Some t ->
            conditions.Add("timestamp >= @startTime")
            parameters.Add(SqliteParameter("@startTime", t.ToString("o")))
        | None -> ()

        match queryParams.EndTime with
        | Some t ->
            conditions.Add("timestamp <= @endTime")
            parameters.Add(SqliteParameter("@endTime", t.ToString("o")))
        | None -> ()

        match queryParams.Levels with
        | Some levels when not (List.isEmpty levels) ->
            let placeholders = levels |> List.mapi (fun i _ -> sprintf "@level%d" i)
            conditions.Add(sprintf "level IN (%s)" (String.Join(",", placeholders)))
            levels |> List.iteri (fun i l ->
                parameters.Add(SqliteParameter(sprintf "@level%d" i, l))
            )
        | _ -> ()

        match queryParams.Domains with
        | Some domains when not (List.isEmpty domains) ->
            let placeholders = domains |> List.mapi (fun i _ -> sprintf "@domain%d" i)
            conditions.Add(sprintf "domain IN (%s)" (String.Join(",", placeholders)))
            domains |> List.iteri (fun i d ->
                parameters.Add(SqliteParameter(sprintf "@domain%d" i, d))
            )
        | _ -> ()

        match queryParams.SearchPattern with
        | Some pattern when not (String.IsNullOrWhiteSpace(pattern)) ->
            conditions.Add("message LIKE @search")
            parameters.Add(SqliteParameter("@search", sprintf "%%%s%%" pattern))
        | _ -> ()

        match queryParams.TraceId with
        | Some tid when not (String.IsNullOrWhiteSpace(tid)) ->
            conditions.Add("trace_id = @traceId")
            parameters.Add(SqliteParameter("@traceId", tid))
        | _ -> ()

        let whereClause =
            if conditions.Count > 0 then
                sprintf "WHERE %s" (String.Join(" AND ", conditions))
            else
                ""

        let orderClause =
            sprintf "ORDER BY %s %s"
                queryParams.OrderBy
                (if queryParams.OrderDesc then "DESC" else "ASC")

        // Get total count
        let countSql = sprintf "SELECT COUNT(*) FROM fractal_logs %s" whereClause
        use countCmd = new SqliteCommand(countSql, conn)
        parameters |> Seq.iter (fun p -> countCmd.Parameters.Add(SqliteParameter(p.ParameterName, p.Value)) |> ignore)
        let! countResult = countCmd.ExecuteScalarAsync() |> Async.AwaitTask
        let totalCount = Convert.ToInt32(countResult)

        // Get entries
        let querySql =
            sprintf "SELECT id, timestamp, hlc_timestamp, level, domain, module, function, message, metadata, trace_id, span_id, node FROM fractal_logs %s %s LIMIT @limit OFFSET @offset" whereClause orderClause

        use queryCmd = new SqliteCommand(querySql, conn)
        parameters |> Seq.iter (fun p -> queryCmd.Parameters.Add(SqliteParameter(p.ParameterName, p.Value)) |> ignore)
        queryCmd.Parameters.AddWithValue("@limit", queryParams.Limit) |> ignore
        queryCmd.Parameters.AddWithValue("@offset", queryParams.Offset) |> ignore

        let entries = ResizeArray<HistoricalLogEntry>()
        use! reader = queryCmd.ExecuteReaderAsync() |> Async.AwaitTask

        while reader.Read() do
            entries.Add({
                Id = reader.GetString(0)
                Timestamp = DateTimeOffset.Parse(reader.GetString(1))
                HlcTimestamp = if reader.IsDBNull(2) then None else Some (reader.GetInt64(2))
                Level = reader.GetString(3)
                Domain = if reader.IsDBNull(4) then "" else reader.GetString(4)
                Module = if reader.IsDBNull(5) then None else Some (reader.GetString(5))
                Function = if reader.IsDBNull(6) then None else Some (reader.GetString(6))
                Message = if reader.IsDBNull(7) then "" else reader.GetString(7)
                Metadata = Map.empty
                TraceId = if reader.IsDBNull(9) then None else Some (reader.GetString(9))
                SpanId = if reader.IsDBNull(10) then None else Some (reader.GetString(10))
                Node = if reader.IsDBNull(11) then None else Some (reader.GetString(11))
            })

        let elapsed = (DateTimeOffset.UtcNow - start).TotalMilliseconds

        return {
            Entries = entries |> Seq.toList
            TotalCount = totalCount
            HasMore = queryParams.Offset + entries.Count < totalCount
            QueryTimeMs = elapsed
            FromCache = false
        }
    }

    /// Query with default parameters
    let query () =
        queryAsync defaultParams |> Async.RunSynchronously

    /// Query by time range
    let queryByTimeRange (startTime: DateTimeOffset) (endTime: DateTimeOffset) (limit: int) =
        let params' = { defaultParams with StartTime = Some startTime; EndTime = Some endTime; Limit = limit }
        queryAsync params' |> Async.RunSynchronously

    /// Query by trace ID
    let queryByTraceId (traceId: string) =
        let params' = { defaultParams with TraceId = Some traceId; Limit = 1000 }
        queryAsync params' |> Async.RunSynchronously

    /// Get aggregation by level
    let getAggregationByLevel (startTime: DateTimeOffset) (endTime: DateTimeOffset) = async {
        use conn = new SqliteConnection(config.ConnectionString)
        do! conn.OpenAsync() |> Async.AwaitTask

        let sql = """
            SELECT level, COUNT(*) as count
            FROM fractal_logs
            WHERE timestamp >= @startTime AND timestamp <= @endTime
            GROUP BY level
            ORDER BY count DESC
        """

        use cmd = new SqliteCommand(sql, conn)
        cmd.Parameters.AddWithValue("@startTime", startTime.ToString("o")) |> ignore
        cmd.Parameters.AddWithValue("@endTime", endTime.ToString("o")) |> ignore

        let result = ResizeArray<string * int64>()
        use! reader = cmd.ExecuteReaderAsync() |> Async.AwaitTask

        while reader.Read() do
            result.Add((reader.GetString(0), reader.GetInt64(1)))

        return result |> Seq.toList |> Map.ofList
    }

    /// Get aggregation by domain
    let getAggregationByDomain (startTime: DateTimeOffset) (endTime: DateTimeOffset) = async {
        use conn = new SqliteConnection(config.ConnectionString)
        do! conn.OpenAsync() |> Async.AwaitTask

        let sql = """
            SELECT domain, COUNT(*) as count
            FROM fractal_logs
            WHERE timestamp >= @startTime AND timestamp <= @endTime
            GROUP BY domain
            ORDER BY count DESC
            LIMIT 50
        """

        use cmd = new SqliteCommand(sql, conn)
        cmd.Parameters.AddWithValue("@startTime", startTime.ToString("o")) |> ignore
        cmd.Parameters.AddWithValue("@endTime", endTime.ToString("o")) |> ignore

        let result = ResizeArray<string * int64>()
        use! reader = cmd.ExecuteReaderAsync() |> Async.AwaitTask

        while reader.Read() do
            let domain = if reader.IsDBNull(0) then "unknown" else reader.GetString(0)
            result.Add((domain, reader.GetInt64(1)))

        return result |> Seq.toList |> Map.ofList
    }

    // ========================================================================
    // WRITE FUNCTIONS (for local storage)
    // ========================================================================

    /// Insert a log entry
    let insertAsync (entry: HistoricalLogEntry) = async {
        use conn = new SqliteConnection(config.ConnectionString)
        do! conn.OpenAsync() |> Async.AwaitTask

        let sql = """
            INSERT OR REPLACE INTO fractal_logs
            (id, timestamp, hlc_timestamp, level, domain, module, function, message, metadata, trace_id, span_id, node)
            VALUES (@id, @timestamp, @hlc, @level, @domain, @module, @function, @message, @metadata, @traceId, @spanId, @node)
        """

        use cmd = new SqliteCommand(sql, conn)
        cmd.Parameters.AddWithValue("@id", entry.Id) |> ignore
        cmd.Parameters.AddWithValue("@timestamp", entry.Timestamp.ToString("o")) |> ignore
        cmd.Parameters.AddWithValue("@hlc", entry.HlcTimestamp |> Option.map box |> Option.defaultValue (box DBNull.Value)) |> ignore
        cmd.Parameters.AddWithValue("@level", entry.Level) |> ignore
        cmd.Parameters.AddWithValue("@domain", entry.Domain) |> ignore
        cmd.Parameters.AddWithValue("@module", entry.Module |> Option.map box |> Option.defaultValue (box DBNull.Value)) |> ignore
        cmd.Parameters.AddWithValue("@function", entry.Function |> Option.map box |> Option.defaultValue (box DBNull.Value)) |> ignore
        cmd.Parameters.AddWithValue("@message", entry.Message) |> ignore
        cmd.Parameters.AddWithValue("@metadata", System.Text.Json.JsonSerializer.Serialize(entry.Metadata)) |> ignore
        cmd.Parameters.AddWithValue("@traceId", entry.TraceId |> Option.map box |> Option.defaultValue (box DBNull.Value)) |> ignore
        cmd.Parameters.AddWithValue("@spanId", entry.SpanId |> Option.map box |> Option.defaultValue (box DBNull.Value)) |> ignore
        cmd.Parameters.AddWithValue("@node", entry.Node |> Option.map box |> Option.defaultValue (box DBNull.Value)) |> ignore

        let! _ = cmd.ExecuteNonQueryAsync() |> Async.AwaitTask
        return ()
    }

    /// Insert multiple entries
    let insertBatchAsync (entries: HistoricalLogEntry list) = async {
        for entry in entries do
            do! insertAsync entry
    }

    // ========================================================================
    // CONVENIENCE FUNCTIONS
    // ========================================================================

    /// Get recent logs (last hour)
    let getRecentLogs (limit: int) =
        queryByTimeRange (DateTimeOffset.UtcNow.AddHours(-1.0)) DateTimeOffset.UtcNow limit

    /// Get logs for today
    let getTodaysLogs (limit: int) =
        let today = DateTimeOffset.UtcNow.Date
        queryByTimeRange (DateTimeOffset(today, TimeSpan.Zero)) DateTimeOffset.UtcNow limit

    /// Search logs
    let searchLogs (pattern: string) (limit: int) =
        let params' = { defaultParams with SearchPattern = Some pattern; Limit = limit }
        queryAsync params' |> Async.RunSynchronously
