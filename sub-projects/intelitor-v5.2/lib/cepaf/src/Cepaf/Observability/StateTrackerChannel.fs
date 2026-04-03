namespace Cepaf.Observability

open System
open System.IO
open System.Text.Json
open System.Text.Json.Serialization
open Microsoft.Data.Sqlite

/// State tracker channel implementation for Quadplex observability.
/// Provides SQLite persistence for events, tasks, state, and metrics.
/// STAMP Compliance: SC-OBS-071 (4 OTEL modules - state tracker component)
module StateTrackerChannel =

    /// JSON options for serialization
    let private jsonOptions =
        let options = JsonSerializerOptions()
        options.WriteIndented <- false
        options.DefaultIgnoreCondition <- JsonIgnoreCondition.WhenWritingNull
        options.Converters.Add(JsonStringEnumConverter())
        options

    /// SQL schema for state tracker database
    let private createSchema = """
        -- Events table for log history
        CREATE TABLE IF NOT EXISTS events (
            id TEXT PRIMARY KEY,
            timestamp TEXT NOT NULL,
            level INTEGER NOT NULL,
            category TEXT NOT NULL,
            message TEXT NOT NULL,
            trace_id TEXT,
            span_id TEXT,
            correlation_id TEXT,
            payload_json TEXT,
            exception_message TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );

        -- Tasks table for protocol task tracking
        CREATE TABLE IF NOT EXISTS tasks (
            id TEXT PRIMARY KEY,
            description TEXT NOT NULL,
            entry_criteria TEXT,
            exit_criteria TEXT,
            start_state TEXT,
            end_state TEXT,
            status TEXT NOT NULL,
            status_percent INTEGER,
            status_reason TEXT,
            estimated_duration_ms INTEGER,
            actual_duration_ms INTEGER,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        );

        -- State table for key-value storage
        CREATE TABLE IF NOT EXISTS state (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        );

        -- Metrics table for metric history
        CREATE TABLE IF NOT EXISTS metrics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            name TEXT NOT NULL,
            value REAL NOT NULL,
            unit TEXT,
            tags_json TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );

        -- Spans table for distributed tracing
        CREATE TABLE IF NOT EXISTS spans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            trace_id TEXT NOT NULL,
            span_id TEXT NOT NULL,
            parent_span_id TEXT,
            name TEXT NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT,
            duration_ms INTEGER,
            status TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );

        -- Indexes for common queries
        CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp);
        CREATE INDEX IF NOT EXISTS idx_events_level ON events(level);
        CREATE INDEX IF NOT EXISTS idx_events_category ON events(category);
        CREATE INDEX IF NOT EXISTS idx_events_trace_id ON events(trace_id);
        CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
        CREATE INDEX IF NOT EXISTS idx_metrics_name ON metrics(name);
        CREATE INDEX IF NOT EXISTS idx_metrics_timestamp ON metrics(timestamp);
        CREATE INDEX IF NOT EXISTS idx_spans_trace_id ON spans(trace_id);
    """

    /// State tracker channel state
    type StateTrackerState = {
        Connection: SqliteConnection
        DatabasePath: string
        PruneAfterDays: int
        MaxEventsInMemory: int
        LockObj: obj
    }

    /// Ensure database directory exists
    let private ensureDirectory (dbPath: string) =
        let dir = Path.GetDirectoryName(dbPath)
        if not (String.IsNullOrEmpty(dir)) && not (Directory.Exists(dir)) then
            Directory.CreateDirectory(dir) |> ignore

    /// Initialize database with schema
    let private initializeDatabase (connection: SqliteConnection) =
        use cmd = connection.CreateCommand()
        cmd.CommandText <- createSchema
        cmd.ExecuteNonQuery() |> ignore

        // Enable WAL mode for better concurrency
        cmd.CommandText <- "PRAGMA journal_mode=WAL;"
        cmd.ExecuteNonQuery() |> ignore

        cmd.CommandText <- "PRAGMA synchronous=NORMAL;"
        cmd.ExecuteNonQuery() |> ignore

    /// Create state tracker channel
    let create (config: QuadplexConfig) : StateTrackerState =
        ensureDirectory config.DatabasePath

        let connectionString = sprintf "Data Source=%s" config.DatabasePath
        let connection = new SqliteConnection(connectionString)
        connection.Open()
        initializeDatabase connection

        {
            Connection = connection
            DatabasePath = config.DatabasePath
            PruneAfterDays = config.PruneAfterDays
            MaxEventsInMemory = config.MaxEventsInMemory
            LockObj = obj()
        }

    /// Serialize payload to JSON
    let private serializePayload (payload: TelemetryPayload) =
        try
            // Create a simple representation for storage
            let payloadObj =
                match payload with
                | TelemetryPayload.ProtocolStart ts ->
                    {| ``type`` = "protocol_start"; timestamp = ts.ToString("o") |} :> obj
                | TelemetryPayload.ProtocolComplete (dur, success) ->
                    {| ``type`` = "protocol_complete"; duration_ms = dur; success = success |} :> obj
                | TelemetryPayload.PhaseStart (name, _) ->
                    {| ``type`` = "phase_start"; name = name |} :> obj
                | TelemetryPayload.PhaseComplete (name, dur, success, _) ->
                    {| ``type`` = "phase_complete"; name = name; duration_ms = dur; success = success |} :> obj
                | TelemetryPayload.TaskUpdate task ->
                    {| ``type`` = "task_update"; task_id = task.Id |} :> obj
                | TelemetryPayload.SafetyCheckPassed (id, _) ->
                    {| ``type`` = "safety_passed"; id = id |} :> obj
                | TelemetryPayload.SafetyCheckFailed (id, reason, _) ->
                    {| ``type`` = "safety_failed"; id = id; reason = reason |} :> obj
                | TelemetryPayload.ContainerEvent (id, status, _) ->
                    {| ``type`` = "container"; id = id; status = status |} :> obj
                | TelemetryPayload.MetricLogged (name, value, unit, _) ->
                    {| ``type`` = "metric"; name = name; value = value; unit = unit |} :> obj
                | _ ->
                    {| ``type`` = "other" |} :> obj

            JsonSerializer.Serialize(payloadObj, jsonOptions)
        with _ -> "{}"

    /// Insert event into database
    let private insertEvent (state: StateTrackerState) (event: QuadplexEvent) =
        let sql = """
            INSERT INTO events (id, timestamp, level, category, message, trace_id, span_id, correlation_id, payload_json, exception_message)
            VALUES (@id, @timestamp, @level, @category, @message, @trace_id, @span_id, @correlation_id, @payload_json, @exception_message)
        """

        use cmd = state.Connection.CreateCommand()
        cmd.CommandText <- sql

        cmd.Parameters.AddWithValue("@id", event.Id.ToString()) |> ignore
        cmd.Parameters.AddWithValue("@timestamp", event.Timestamp.ToString("o")) |> ignore
        cmd.Parameters.AddWithValue("@level", int event.Level) |> ignore
        cmd.Parameters.AddWithValue("@category", event.Category.ToString()) |> ignore
        cmd.Parameters.AddWithValue("@message", event.Message) |> ignore

        let traceId, spanId =
            match event.Metadata.TraceContext with
            | Some ctx -> ctx.TraceId, ctx.SpanId
            | None -> "", ""

        cmd.Parameters.AddWithValue("@trace_id", traceId) |> ignore
        cmd.Parameters.AddWithValue("@span_id", spanId) |> ignore
        cmd.Parameters.AddWithValue("@correlation_id", event.Metadata.CorrelationId) |> ignore
        cmd.Parameters.AddWithValue("@payload_json", serializePayload event.Payload) |> ignore

        let exMsg = event.Exception |> Option.map (fun ex -> ex.Message) |> Option.defaultValue ""
        cmd.Parameters.AddWithValue("@exception_message", exMsg) |> ignore

        cmd.ExecuteNonQuery() |> ignore

    /// Insert or update task
    let logTask (state: StateTrackerState) (task: ProtocolTask) =
        let statusStr, percent, reason =
            match task.Status with
            | TaskStatus.Pending -> "pending", 0, ""
            | TaskStatus.InProgress p -> "in_progress", p, ""
            | TaskStatus.Completed -> "completed", 100, ""
            | TaskStatus.Failed r -> "failed", 0, r

        let sql = """
            INSERT INTO tasks (id, description, entry_criteria, exit_criteria, start_state, end_state, status, status_percent, status_reason, estimated_duration_ms, actual_duration_ms)
            VALUES (@id, @description, @entry_criteria, @exit_criteria, @start_state, @end_state, @status, @status_percent, @status_reason, @estimated_duration_ms, @actual_duration_ms)
            ON CONFLICT(id) DO UPDATE SET
                status = @status,
                status_percent = @status_percent,
                status_reason = @status_reason,
                actual_duration_ms = @actual_duration_ms,
                updated_at = CURRENT_TIMESTAMP
        """

        lock state.LockObj (fun () ->
            use cmd = state.Connection.CreateCommand()
            cmd.CommandText <- sql

            cmd.Parameters.AddWithValue("@id", task.Id) |> ignore
            cmd.Parameters.AddWithValue("@description", task.Description) |> ignore
            cmd.Parameters.AddWithValue("@entry_criteria", task.EntryCriteria) |> ignore
            cmd.Parameters.AddWithValue("@exit_criteria", task.ExitCriteria) |> ignore
            cmd.Parameters.AddWithValue("@start_state", task.StartState) |> ignore
            cmd.Parameters.AddWithValue("@end_state", task.EndState) |> ignore
            cmd.Parameters.AddWithValue("@status", statusStr) |> ignore
            cmd.Parameters.AddWithValue("@status_percent", percent) |> ignore
            cmd.Parameters.AddWithValue("@status_reason", reason) |> ignore
            cmd.Parameters.AddWithValue("@estimated_duration_ms", task.EstimatedDurationMs) |> ignore
            cmd.Parameters.AddWithValue("@actual_duration_ms", task.ActualDurationMs |> Option.defaultValue 0L) |> ignore

            cmd.ExecuteNonQuery() |> ignore
        )

    /// Update state key-value pair
    let updateState (state: StateTrackerState) (key: string) (value: string) =
        let sql = """
            INSERT INTO state (key, value)
            VALUES (@key, @value)
            ON CONFLICT(key) DO UPDATE SET
                value = @value,
                updated_at = CURRENT_TIMESTAMP
        """

        lock state.LockObj (fun () ->
            use cmd = state.Connection.CreateCommand()
            cmd.CommandText <- sql
            cmd.Parameters.AddWithValue("@key", key) |> ignore
            cmd.Parameters.AddWithValue("@value", value) |> ignore
            cmd.ExecuteNonQuery() |> ignore
        )

    /// Get state value
    let getState (state: StateTrackerState) (key: string) : string option =
        let sql = "SELECT value FROM state WHERE key = @key"

        lock state.LockObj (fun () ->
            use cmd = state.Connection.CreateCommand()
            cmd.CommandText <- sql
            cmd.Parameters.AddWithValue("@key", key) |> ignore

            use reader = cmd.ExecuteReader()
            if reader.Read() then
                Some (reader.GetString(0))
            else
                None
        )

    /// Log metric
    let logMetric (state: StateTrackerState) (name: string) (value: float) (unit: string) (tags: Map<string, string>) =
        let sql = """
            INSERT INTO metrics (timestamp, name, value, unit, tags_json)
            VALUES (@timestamp, @name, @value, @unit, @tags_json)
        """

        lock state.LockObj (fun () ->
            use cmd = state.Connection.CreateCommand()
            cmd.CommandText <- sql
            cmd.Parameters.AddWithValue("@timestamp", DateTimeOffset.UtcNow.ToString("o")) |> ignore
            cmd.Parameters.AddWithValue("@name", name) |> ignore
            cmd.Parameters.AddWithValue("@value", value) |> ignore
            cmd.Parameters.AddWithValue("@unit", unit) |> ignore
            cmd.Parameters.AddWithValue("@tags_json", JsonSerializer.Serialize(tags, jsonOptions)) |> ignore
            cmd.ExecuteNonQuery() |> ignore
        )

    /// Query events
    let queryEvents (state: StateTrackerState) (category: EventCategory option) (level: LogLevel option) (limit: int) : obj list =
        let mutable sql = "SELECT id, timestamp, level, category, message, payload_json FROM events WHERE 1=1"

        match category with
        | Some cat -> sql <- sql + sprintf " AND category = '%s'" (cat.ToString())
        | None -> ()

        match level with
        | Some lvl -> sql <- sql + sprintf " AND level >= %d" (int lvl)
        | None -> ()

        sql <- sql + sprintf " ORDER BY timestamp DESC LIMIT %d" limit

        lock state.LockObj (fun () ->
            use cmd = state.Connection.CreateCommand()
            cmd.CommandText <- sql

            use reader = cmd.ExecuteReader()
            let results = ResizeArray<obj>()
            while reader.Read() do
                let record = {|
                    id = reader.GetString(0)
                    timestamp = reader.GetString(1)
                    level = reader.GetInt32(2)
                    category = reader.GetString(3)
                    message = reader.GetString(4)
                    payload = reader.GetString(5)
                |}
                results.Add(record :> obj)
            results |> Seq.toList
        )

    /// Prune old data
    let prune (state: StateTrackerState) (olderThanDays: int) : int =
        let cutoff = DateTimeOffset.UtcNow.AddDays(float -olderThanDays).ToString("o")

        lock state.LockObj (fun () ->
            let mutable totalDeleted = 0

            // Prune events
            use cmd = state.Connection.CreateCommand()
            cmd.CommandText <- sprintf "DELETE FROM events WHERE timestamp < '%s'" cutoff
            totalDeleted <- totalDeleted + cmd.ExecuteNonQuery()

            // Prune metrics
            cmd.CommandText <- sprintf "DELETE FROM metrics WHERE timestamp < '%s'" cutoff
            totalDeleted <- totalDeleted + cmd.ExecuteNonQuery()

            // Prune completed tasks older than threshold
            cmd.CommandText <- sprintf "DELETE FROM tasks WHERE status = 'completed' AND updated_at < '%s'" cutoff
            totalDeleted <- totalDeleted + cmd.ExecuteNonQuery()

            // Vacuum to reclaim space
            cmd.CommandText <- "VACUUM"
            cmd.ExecuteNonQuery() |> ignore

            totalDeleted
        )

    /// Check if level is enabled (state tracker accepts all levels)
    let isEnabled (_state: StateTrackerState) (_level: LogLevel) =
        true

    /// Write event to state tracker
    let write (state: StateTrackerState) (event: QuadplexEvent) =
        lock state.LockObj (fun () ->
            insertEvent state event

            // Also handle task updates
            match event.Payload with
            | TelemetryPayload.TaskUpdate task ->
                logTask state task
            | TelemetryPayload.MetricLogged (name, value, unit, tags) ->
                logMetric state name value unit tags
            | _ -> ()
        )

    /// Flush (no-op for SQLite with WAL mode)
    let flush (_state: StateTrackerState) =
        ()

    /// Dispose resources
    let dispose (state: StateTrackerState) =
        state.Connection.Close()
        state.Connection.Dispose()

/// State tracker channel as ILogChannel implementation
type StateTrackerLogChannel(config: QuadplexConfig) =
    let state = StateTrackerChannel.create config

    interface ILogChannel with
        member _.Write(event) = StateTrackerChannel.write state event
        member _.Flush() = StateTrackerChannel.flush state
        member _.IsEnabled(level) = StateTrackerChannel.isEnabled state level

    interface IDisposable with
        member _.Dispose() = StateTrackerChannel.dispose state

    /// Log task
    member _.LogTask(task) = StateTrackerChannel.logTask state task

    /// Update state
    member _.UpdateState(key, value) = StateTrackerChannel.updateState state key value

    /// Get state
    member _.GetState(key) = StateTrackerChannel.getState state key

    /// Query events
    member _.QueryEvents(category, level, limit) = StateTrackerChannel.queryEvents state category level limit

    /// Prune old data
    member _.Prune(olderThanDays) = StateTrackerChannel.prune state olderThanDays

/// State store implementation
type SqliteStateStore(config: QuadplexConfig) =
    let state = StateTrackerChannel.create config

    interface IStateStore with
        member _.UpdateState(key, value) = StateTrackerChannel.updateState state key value
        member _.GetState(key) = StateTrackerChannel.getState state key
        member _.LogTask(task) = StateTrackerChannel.logTask state task
        member _.QueryEvents(category, level, limit) = StateTrackerChannel.queryEvents state category level limit
        member _.Prune(olderThanDays) = StateTrackerChannel.prune state olderThanDays

    interface IDisposable with
        member _.Dispose() = StateTrackerChannel.dispose state
