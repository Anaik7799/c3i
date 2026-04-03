// =============================================================================
// BuildHistory.fs - Persistent Build Timing & Intelligence Database
// =============================================================================
// STAMP: SC-IGNITE-001, SC-IGNITE-004, SC-HOLON-009, SC-XHOLON-001
// AOR: AOR-IGNITE-001, AOR-HOLON-009
//
// ## Purpose
// SQLite-backed persistent store for container build/boot timing data.
// Enables ETA estimation, build-skip intelligence, and historical baselines.
// Follows Omega-7 (Holon State Sovereignty) — SQLite is authoritative.
//
// ## Document Control
// | Version | 1.0.0 |
// | Created | 2026-03-31 |
// | Author  | Cybernetic Architect |
// =============================================================================

namespace Cepaf.Mesh

open System
open System.IO
open Microsoft.Data.Sqlite

module BuildHistory =

    // =========================================================================
    // Types
    // =========================================================================

    /// A single build timing record
    type BuildRecord = {
        ContainerName: string
        Action: string           // "build", "pull", "skip", "boot"
        Success: bool
        DurationMs: int64
        ImageSizeBytes: int64
        CacheHits: int
        CacheMisses: int
        StepCount: int
        Timestamp: DateTime
        Error: string option
    }

    /// Aggregated build statistics for a container
    type BuildStats = {
        ContainerName: string
        TotalBuilds: int
        SuccessRate: float
        AvgDurationMs: float
        MinDurationMs: int64
        MaxDurationMs: int64
        LastBuildTime: DateTime
        LastDurationMs: int64
        EmaMs: float             // Exponential moving average (alpha=0.3)
    }

    // =========================================================================
    // Database Path & Initialization
    // =========================================================================

    let private dbPath =
        let dir = "lib/cepaf/artifacts"
        if not (Directory.Exists(dir)) then
            Directory.CreateDirectory(dir) |> ignore
        Path.Combine(dir, "build-history.db")

    let private connectionString () =
        sprintf "Data Source=%s;Mode=ReadWriteCreate" dbPath

    /// Ensure the database schema exists. Idempotent.
    let ensureSchema () =
        use conn = new SqliteConnection(connectionString())
        conn.Open()
        use cmd = conn.CreateCommand()
        cmd.CommandText <- """
            CREATE TABLE IF NOT EXISTS build_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                container_name TEXT NOT NULL,
                action TEXT NOT NULL DEFAULT 'build',
                success INTEGER NOT NULL DEFAULT 1,
                duration_ms INTEGER NOT NULL,
                image_size_bytes INTEGER NOT NULL DEFAULT 0,
                cache_hits INTEGER NOT NULL DEFAULT 0,
                cache_misses INTEGER NOT NULL DEFAULT 0,
                step_count INTEGER NOT NULL DEFAULT 0,
                timestamp TEXT NOT NULL DEFAULT (datetime('now')),
                error TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_build_history_container
                ON build_history(container_name, timestamp DESC);
            CREATE INDEX IF NOT EXISTS idx_build_history_action
                ON build_history(action, timestamp DESC);

            -- Aggregated EMA table (updated on each insert)
            CREATE TABLE IF NOT EXISTS build_ema (
                container_name TEXT PRIMARY KEY,
                ema_duration_ms REAL NOT NULL DEFAULT 0.0,
                total_builds INTEGER NOT NULL DEFAULT 0,
                last_updated TEXT NOT NULL DEFAULT (datetime('now'))
            );

            -- Pragma for WAL mode (concurrent reads, SC-XHOLON-001)
            PRAGMA journal_mode=WAL;
            PRAGMA busy_timeout=5000;
        """
        cmd.ExecuteNonQuery() |> ignore

    // =========================================================================
    // Write Operations
    // =========================================================================

    /// Record a build event. Updates EMA automatically.
    let record (entry: BuildRecord) =
        ensureSchema()
        use conn = new SqliteConnection(connectionString())
        conn.Open()

        // Insert the raw record
        use insertCmd = conn.CreateCommand()
        insertCmd.CommandText <- """
            INSERT INTO build_history
                (container_name, action, success, duration_ms, image_size_bytes,
                 cache_hits, cache_misses, step_count, timestamp, error)
            VALUES
                (@name, @action, @success, @duration, @size,
                 @hits, @misses, @steps, @ts, @error)
        """
        insertCmd.Parameters.AddWithValue("@name", entry.ContainerName) |> ignore
        insertCmd.Parameters.AddWithValue("@action", entry.Action) |> ignore
        insertCmd.Parameters.AddWithValue("@success", if entry.Success then 1 else 0) |> ignore
        insertCmd.Parameters.AddWithValue("@duration", entry.DurationMs) |> ignore
        insertCmd.Parameters.AddWithValue("@size", entry.ImageSizeBytes) |> ignore
        insertCmd.Parameters.AddWithValue("@hits", entry.CacheHits) |> ignore
        insertCmd.Parameters.AddWithValue("@misses", entry.CacheMisses) |> ignore
        insertCmd.Parameters.AddWithValue("@steps", entry.StepCount) |> ignore
        insertCmd.Parameters.AddWithValue("@ts", entry.Timestamp.ToString("o")) |> ignore
        insertCmd.Parameters.AddWithValue("@error",
            match entry.Error with Some e -> box e | None -> box DBNull.Value) |> ignore
        insertCmd.ExecuteNonQuery() |> ignore

        // Update EMA (alpha = 0.3) — only for successful builds
        if entry.Success then
            use emaCmd = conn.CreateCommand()
            emaCmd.CommandText <- """
                INSERT INTO build_ema (container_name, ema_duration_ms, total_builds, last_updated)
                VALUES (@name, @duration, 1, datetime('now'))
                ON CONFLICT(container_name) DO UPDATE SET
                    ema_duration_ms = 0.3 * @duration + 0.7 * ema_duration_ms,
                    total_builds = total_builds + 1,
                    last_updated = datetime('now')
            """
            emaCmd.Parameters.AddWithValue("@name", entry.ContainerName) |> ignore
            emaCmd.Parameters.AddWithValue("@duration", float entry.DurationMs) |> ignore
            emaCmd.ExecuteNonQuery() |> ignore

    // =========================================================================
    // Read Operations
    // =========================================================================

    /// Get the EMA-based estimated duration for a container build.
    /// Returns None if no history exists.
    let getEstimatedDuration (containerName: string) : float option =
        ensureSchema()
        use conn = new SqliteConnection(connectionString())
        conn.Open()
        use cmd = conn.CreateCommand()
        cmd.CommandText <- "SELECT ema_duration_ms FROM build_ema WHERE container_name = @name"
        cmd.Parameters.AddWithValue("@name", containerName) |> ignore
        let result = cmd.ExecuteScalar()
        if result <> null && result <> box DBNull.Value then
            Some (Convert.ToDouble(result))
        else
            None

    /// Get full build statistics for a container.
    let getStats (containerName: string) : BuildStats option =
        ensureSchema()
        use conn = new SqliteConnection(connectionString())
        conn.Open()

        use cmd = conn.CreateCommand()
        cmd.CommandText <- """
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN success = 1 THEN 1.0 ELSE 0.0 END) / MAX(COUNT(*), 1) as rate,
                AVG(duration_ms) as avg_ms,
                MIN(duration_ms) as min_ms,
                MAX(duration_ms) as max_ms,
                MAX(timestamp) as last_ts
            FROM build_history
            WHERE container_name = @name AND action = 'build'
        """
        cmd.Parameters.AddWithValue("@name", containerName) |> ignore
        use reader = cmd.ExecuteReader()
        if reader.Read() && reader.GetInt32(0) > 0 then
            let total = reader.GetInt32(0)
            let rate = reader.GetDouble(1)
            let avgMs = reader.GetDouble(2)
            let minMs = reader.GetInt64(3)
            let maxMs = reader.GetInt64(4)
            let lastTs = DateTime.Parse(reader.GetString(5))

            // Get last build duration
            use lastCmd = conn.CreateCommand()
            lastCmd.CommandText <- """
                SELECT duration_ms FROM build_history
                WHERE container_name = @name AND action = 'build'
                ORDER BY timestamp DESC LIMIT 1
            """
            lastCmd.Parameters.AddWithValue("@name", containerName) |> ignore
            let lastDur = Convert.ToInt64(lastCmd.ExecuteScalar())

            // Get EMA
            let ema = getEstimatedDuration containerName |> Option.defaultValue avgMs

            Some {
                ContainerName = containerName
                TotalBuilds = total
                SuccessRate = rate
                AvgDurationMs = avgMs
                MinDurationMs = minMs
                MaxDurationMs = maxMs
                LastBuildTime = lastTs
                LastDurationMs = lastDur
                EmaMs = ema
            }
        else
            None

    /// Get the last N build records for a container.
    let getHistory (containerName: string) (limit: int) : BuildRecord list =
        ensureSchema()
        use conn = new SqliteConnection(connectionString())
        conn.Open()
        use cmd = conn.CreateCommand()
        cmd.CommandText <- """
            SELECT container_name, action, success, duration_ms, image_size_bytes,
                   cache_hits, cache_misses, step_count, timestamp, error
            FROM build_history
            WHERE container_name = @name
            ORDER BY timestamp DESC
            LIMIT @limit
        """
        cmd.Parameters.AddWithValue("@name", containerName) |> ignore
        cmd.Parameters.AddWithValue("@limit", limit) |> ignore

        use reader = cmd.ExecuteReader()
        let mutable records = []
        while reader.Read() do
            records <- {
                ContainerName = reader.GetString(0)
                Action = reader.GetString(1)
                Success = reader.GetInt32(2) = 1
                DurationMs = reader.GetInt64(3)
                ImageSizeBytes = reader.GetInt64(4)
                CacheHits = reader.GetInt32(5)
                CacheMisses = reader.GetInt32(6)
                StepCount = reader.GetInt32(7)
                Timestamp = DateTime.Parse(reader.GetString(8))
                Error = if reader.IsDBNull(9) then None else Some (reader.GetString(9))
            } :: records
        records |> List.rev

    /// Get EMA estimates for all known containers (for dashboard display).
    let getAllEstimates () : Map<string, float> =
        ensureSchema()
        use conn = new SqliteConnection(connectionString())
        conn.Open()
        use cmd = conn.CreateCommand()
        cmd.CommandText <- "SELECT container_name, ema_duration_ms FROM build_ema"

        use reader = cmd.ExecuteReader()
        let mutable result = Map.empty
        while reader.Read() do
            result <- Map.add (reader.GetString(0)) (reader.GetDouble(1)) result
        result

    /// Get the timestamp of the last successful build for a container.
    let getLastSuccessfulBuild (containerName: string) : DateTime option =
        ensureSchema()
        use conn = new SqliteConnection(connectionString())
        conn.Open()
        use cmd = conn.CreateCommand()
        cmd.CommandText <- """
            SELECT timestamp FROM build_history
            WHERE container_name = @name AND success = 1 AND action = 'build'
            ORDER BY timestamp DESC LIMIT 1
        """
        cmd.Parameters.AddWithValue("@name", containerName) |> ignore
        let result = cmd.ExecuteScalar()
        if result <> null && result <> box DBNull.Value then
            Some (DateTime.Parse(string result))
        else
            None

    // =========================================================================
    // Utility
    // =========================================================================

    /// Print a summary of all build history to console (for dashboards).
    let printSummary () =
        let estimates = getAllEstimates()
        if estimates.IsEmpty then
            printfn "\u001b[33m[BUILD-HISTORY]\u001b[0m No build history recorded yet."
        else
            printfn "\u001b[35m\u001b[1m╔════════════════════════════════════════════════════════╗\u001b[0m"
            printfn "\u001b[35m\u001b[1m║          BUILD HISTORY — EMA BASELINES                ║\u001b[0m"
            printfn "\u001b[35m\u001b[1m╠════════════════════════════════════════════════════════╣\u001b[0m"
            for kvp in estimates do
                let name = kvp.Key
                let ema = kvp.Value
                let etaStr =
                    if ema < 1000.0 then sprintf "%.0fms" ema
                    elif ema < 60000.0 then sprintf "%.1fs" (ema / 1000.0)
                    else sprintf "%.1fm" (ema / 60000.0)
                printfn "\u001b[35m\u001b[1m║\u001b[0m  %-30s  EMA: %8s       \u001b[35m\u001b[1m║\u001b[0m" name etaStr
            printfn "\u001b[35m\u001b[1m╚════════════════════════════════════════════════════════╝\u001b[0m"
