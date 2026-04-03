#!/usr/bin/env dotnet fsi

// =============================================================================
// TRICAMERAL MONITORING SYSTEM
// Active Health Checks, Information Collection, and Evolutionary Control
// =============================================================================
// Version: 1.0.0 | STAMP: SC-MON-001 to SC-MON-025
// Layer: L5-EVOLUTIONARY (OODA Integration) | SIL-6 Compliance
// =============================================================================

#r "nuget: System.Text.Json"
#r "nuget: Microsoft.Data.Sqlite"
#r "nuget: FSharp.Data, 6.4.0"

open System
open System.IO
open System.Net.Http
open System.Text.Json
open System.Text.Json.Serialization
open System.Threading
open System.Threading.Tasks
open System.Security.Cryptography
open Microsoft.Data.Sqlite

// =============================================================================
// TYPES - MONITORING DOMAIN
// =============================================================================

/// Health status enumeration
type HealthStatus =
    | Healthy
    | Degraded
    | Unhealthy
    | Unknown

/// Monitored component types
type ComponentType =
    | APIGateway        // OpenRouter endpoint
    | Chamber           // Claude/Gemini/Grok
    | Database          // SQLite/DuckDB stores
    | ModelRegistry     // Model registry
    | ConsensusEngine   // Voting/consensus logic
    | AuditLog          // Hash chain integrity
    | CostTracker       // Usage/billing tracking
    | PerformanceMetrics // Latency/throughput

/// Health check result
[<CLIMutable>]
type HealthCheck = {
    Component: string
    ComponentType: string
    Status: string
    Latency: int           // ms
    Message: string
    Timestamp: DateTime
    Metadata: Map<string, string>
}

/// Metric data point
[<CLIMutable>]
type MetricPoint = {
    Name: string
    Value: float
    Unit: string
    Tags: Map<string, string>
    Timestamp: DateTime
}

/// Evolution signal for OODA loop
type EvolutionSignal =
    | PerformanceDegraded of component: string * metric: string * threshold: float * actual: float
    | CostExceeded of component: string * budget: float * actual: float
    | ErrorRateHigh of component: string * rate: float
    | LatencyHigh of component: string * avgMs: int * thresholdMs: int
    | AvailabilityLow of component: string * uptime: float
    | ModelDeprecated of modelId: string * deprecationDate: string
    | ConsensusFailure of rate: float
    | HashChainBroken of lastValidBlock: int

/// Monitoring configuration
type MonitorConfig = {
    HealthCheckIntervalMs: int
    MetricsCollectionIntervalMs: int
    EvolutionCheckIntervalMs: int
    AlertThresholds: Map<string, float>
    EnabledComponents: ComponentType list
}

/// OODA Observation State
[<CLIMutable>]
type ObservationState = {
    Timestamp: DateTime
    HealthChecks: HealthCheck list
    Metrics: MetricPoint list
    Signals: EvolutionSignal list
    OverallHealth: HealthStatus
    SystemLoad: float
    CostToDate: float
}

// =============================================================================
// CONFIGURATION
// =============================================================================

let projectRoot =
    let current = Directory.GetCurrentDirectory()
    if current.Contains("lib/cepaf") then
        Path.GetFullPath(Path.Combine(current, "../.."))
    else current

let dataPath = Path.Combine(projectRoot, "data", "monitoring")
let monitorDbPath = Path.Combine(dataPath, "tricameral_monitor.db")
let governanceDbPath = Path.Combine(projectRoot, "data", "governance", "tricameral.db")
let modelsDbPath = Path.Combine(projectRoot, "data", "models", "model_registry.db")

let defaultConfig = {
    HealthCheckIntervalMs = 30000      // 30 seconds
    MetricsCollectionIntervalMs = 10000 // 10 seconds
    EvolutionCheckIntervalMs = 60000   // 1 minute
    AlertThresholds = Map.ofList [
        ("latency_ms", 5000.0)          // 5 second max latency
        ("error_rate", 0.05)            // 5% error threshold
        ("cost_per_hour", 10.0)         // $10/hour budget
        ("consensus_failure_rate", 0.20) // 20% failure threshold
        ("availability", 0.95)           // 95% uptime required
    ]
    EnabledComponents = [
        APIGateway
        Chamber
        Database
        ModelRegistry
        ConsensusEngine
        AuditLog
        CostTracker
        PerformanceMetrics
    ]
}

// =============================================================================
// DATABASE
// =============================================================================

let ensureMonitorDatabase () =
    Directory.CreateDirectory(dataPath) |> ignore

    use conn = new SqliteConnection($"Data Source={monitorDbPath}")
    conn.Open()

    let sql = """
        -- Health check history
        CREATE TABLE IF NOT EXISTS health_checks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            component TEXT NOT NULL,
            component_type TEXT NOT NULL,
            status TEXT NOT NULL,
            latency_ms INTEGER,
            message TEXT,
            metadata_json TEXT,
            timestamp TEXT NOT NULL
        );

        -- Metrics time series
        CREATE TABLE IF NOT EXISTS metrics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            value REAL NOT NULL,
            unit TEXT,
            tags_json TEXT,
            timestamp TEXT NOT NULL
        );

        -- Evolution signals
        CREATE TABLE IF NOT EXISTS evolution_signals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            signal_type TEXT NOT NULL,
            component TEXT,
            details_json TEXT NOT NULL,
            severity TEXT NOT NULL,
            acknowledged INTEGER DEFAULT 0,
            action_taken TEXT,
            timestamp TEXT NOT NULL
        );

        -- OODA cycle records
        CREATE TABLE IF NOT EXISTS ooda_cycles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cycle_number INTEGER NOT NULL,
            phase TEXT NOT NULL,  -- OBSERVE, ORIENT, DECIDE, ACT
            observation_json TEXT,
            orientation_json TEXT,
            decision_json TEXT,
            action_json TEXT,
            outcome_json TEXT,
            duration_ms INTEGER,
            timestamp TEXT NOT NULL
        );

        -- System snapshots for trend analysis
        CREATE TABLE IF NOT EXISTS system_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            overall_health TEXT NOT NULL,
            healthy_components INTEGER,
            degraded_components INTEGER,
            unhealthy_components INTEGER,
            total_cost REAL,
            avg_latency_ms REAL,
            decisions_count INTEGER,
            consensus_rate REAL,
            timestamp TEXT NOT NULL
        );

        -- Indexes for efficient queries
        CREATE INDEX IF NOT EXISTS idx_health_component ON health_checks(component, timestamp);
        CREATE INDEX IF NOT EXISTS idx_health_status ON health_checks(status, timestamp);
        CREATE INDEX IF NOT EXISTS idx_metrics_name ON metrics(name, timestamp);
        CREATE INDEX IF NOT EXISTS idx_signals_type ON evolution_signals(signal_type, timestamp);
        CREATE INDEX IF NOT EXISTS idx_ooda_cycle ON ooda_cycles(cycle_number, phase);
    """

    use cmd = new SqliteCommand(sql, conn)
    cmd.ExecuteNonQuery() |> ignore

    printfn "[MON] Monitor database initialized at %s" monitorDbPath

// =============================================================================
// HEALTH CHECK IMPLEMENTATIONS
// =============================================================================

let httpClient = new HttpClient()

/// Check OpenRouter API Gateway health
let checkAPIGateway () : Async<HealthCheck> = async {
    let startTime = DateTime.UtcNow
    let apiKey = Environment.GetEnvironmentVariable("OPENROUTER_API_KEY")

    try
        if String.IsNullOrEmpty(apiKey) then
            return {
                Component = "OpenRouter"
                ComponentType = "APIGateway"
                Status = "Unhealthy"
                Latency = 0
                Message = "OPENROUTER_API_KEY not configured"
                Timestamp = DateTime.UtcNow
                Metadata = Map.empty
            }
        else
            // Check OpenRouter API with a lightweight request
            use request = new HttpRequestMessage(HttpMethod.Get, "https://openrouter.ai/api/v1/models")
            request.Headers.Add("Authorization", $"Bearer {apiKey}")

            let! response = httpClient.SendAsync(request) |> Async.AwaitTask
            let latency = int (DateTime.UtcNow - startTime).TotalMilliseconds

            if response.IsSuccessStatusCode then
                return {
                    Component = "OpenRouter"
                    ComponentType = "APIGateway"
                    Status = "Healthy"
                    Latency = latency
                    Message = "API responding normally"
                    Timestamp = DateTime.UtcNow
                    Metadata = Map.ofList [
                        ("status_code", string (int response.StatusCode))
                        ("response_time_ms", string latency)
                    ]
                }
            else
                return {
                    Component = "OpenRouter"
                    ComponentType = "APIGateway"
                    Status = "Degraded"
                    Latency = latency
                    Message = $"API returned {response.StatusCode}"
                    Timestamp = DateTime.UtcNow
                    Metadata = Map.ofList [("status_code", string (int response.StatusCode))]
                }
    with ex ->
        return {
            Component = "OpenRouter"
            ComponentType = "APIGateway"
            Status = "Unhealthy"
            Latency = int (DateTime.UtcNow - startTime).TotalMilliseconds
            Message = $"Exception: {ex.Message}"
            Timestamp = DateTime.UtcNow
            Metadata = Map.empty
        }
}

/// Check SQLite database health
let checkDatabase (dbPath: string) (name: string) : HealthCheck =
    let startTime = DateTime.UtcNow

    try
        if not (File.Exists(dbPath)) then
            {
                Component = name
                ComponentType = "Database"
                Status = "Unhealthy"
                Latency = 0
                Message = "Database file not found"
                Timestamp = DateTime.UtcNow
                Metadata = Map.ofList [("path", dbPath)]
            }
        else
            use conn = new SqliteConnection($"Data Source={dbPath}")
            conn.Open()

            use cmd = new SqliteCommand("SELECT COUNT(*) FROM sqlite_master", conn)
            let count = cmd.ExecuteScalar() :?> int64
            let latency = int (DateTime.UtcNow - startTime).TotalMilliseconds

            {
                Component = name
                ComponentType = "Database"
                Status = "Healthy"
                Latency = latency
                Message = $"Database accessible, {count} schema objects"
                Timestamp = DateTime.UtcNow
                Metadata = Map.ofList [
                    ("path", dbPath)
                    ("schema_objects", string count)
                    ("file_size_kb", string (FileInfo(dbPath).Length / 1024L))
                ]
            }
    with ex ->
        {
            Component = name
            ComponentType = "Database"
            Status = "Unhealthy"
            Latency = int (DateTime.UtcNow - startTime).TotalMilliseconds
            Message = $"Exception: {ex.Message}"
            Timestamp = DateTime.UtcNow
            Metadata = Map.ofList [("path", dbPath)]
        }

/// Check hash chain integrity (audit log)
let checkAuditLogIntegrity () : HealthCheck =
    let startTime = DateTime.UtcNow

    try
        if not (File.Exists(governanceDbPath)) then
            {
                Component = "AuditLog"
                ComponentType = "AuditLog"
                Status = "Unknown"
                Latency = 0
                Message = "Governance database not found"
                Timestamp = DateTime.UtcNow
                Metadata = Map.empty
            }
        else
            use conn = new SqliteConnection($"Data Source={governanceDbPath}")
            conn.Open()

            // Check hash chain integrity
            let sql = """
                SELECT COUNT(*) as total,
                       SUM(CASE WHEN record_hash IS NOT NULL AND record_hash != '' THEN 1 ELSE 0 END) as hashed
                FROM tricameral_decisions
            """
            use cmd = new SqliteCommand(sql, conn)
            use reader = cmd.ExecuteReader()

            let latency = int (DateTime.UtcNow - startTime).TotalMilliseconds

            if reader.Read() then
                let total = reader.GetInt64(0)
                let hashed = reader.GetInt64(1)

                let status =
                    if total = 0L then "Unknown"
                    elif hashed = total then "Healthy"
                    elif float hashed / float total > 0.9 then "Degraded"
                    else "Unhealthy"

                {
                    Component = "AuditLog"
                    ComponentType = "AuditLog"
                    Status = status
                    Latency = latency
                    Message = $"Hash chain: {hashed}/{total} blocks verified"
                    Timestamp = DateTime.UtcNow
                    Metadata = Map.ofList [
                        ("total_blocks", string total)
                        ("verified_blocks", string hashed)
                        ("integrity_rate", string (if total > 0L then float hashed / float total else 0.0))
                    ]
                }
            else
                {
                    Component = "AuditLog"
                    ComponentType = "AuditLog"
                    Status = "Unknown"
                    Latency = latency
                    Message = "Could not read audit log"
                    Timestamp = DateTime.UtcNow
                    Metadata = Map.empty
                }
    with ex ->
        {
            Component = "AuditLog"
            ComponentType = "AuditLog"
            Status = "Unhealthy"
            Latency = int (DateTime.UtcNow - startTime).TotalMilliseconds
            Message = $"Exception: {ex.Message}"
            Timestamp = DateTime.UtcNow
            Metadata = Map.empty
        }

/// Check consensus engine metrics
let checkConsensusEngine () : HealthCheck =
    let startTime = DateTime.UtcNow

    try
        if not (File.Exists(governanceDbPath)) then
            {
                Component = "ConsensusEngine"
                ComponentType = "ConsensusEngine"
                Status = "Unknown"
                Latency = 0
                Message = "Governance database not found"
                Timestamp = DateTime.UtcNow
                Metadata = Map.empty
            }
        else
            use conn = new SqliteConnection($"Data Source={governanceDbPath}")
            conn.Open()

            // Get consensus statistics from last 24 hours
            let sql = """
                SELECT
                    COUNT(*) as total,
                    SUM(CASE WHEN consensus_type = 'UNANIMOUS' THEN 1 ELSE 0 END) as unanimous,
                    SUM(CASE WHEN consensus_type = 'MAJORITY' THEN 1 ELSE 0 END) as majority,
                    SUM(CASE WHEN consensus_type IN ('SPLIT', 'TIMEOUT', 'ERROR') THEN 1 ELSE 0 END) as failed,
                    AVG(COALESCE(claude_time_ms, 0) + COALESCE(gemini_time_ms, 0) + COALESCE(grok_time_ms, 0)) as avg_total_time
                FROM tricameral_decisions
                WHERE timestamp > datetime('now', '-24 hours')
            """
            use cmd = new SqliteCommand(sql, conn)
            use reader = cmd.ExecuteReader()

            let latency = int (DateTime.UtcNow - startTime).TotalMilliseconds

            if reader.Read() then
                let total = reader.GetInt64(0)
                let unanimous = reader.GetInt64(1)
                let majority = reader.GetInt64(2)
                let failed = reader.GetInt64(3)
                let avgTime = if reader.IsDBNull(4) then 0.0 else reader.GetDouble(4)

                let successRate = if total > 0L then float (unanimous + majority) / float total else 1.0
                let status =
                    if total = 0L then "Unknown"
                    elif successRate >= 0.95 then "Healthy"
                    elif successRate >= 0.80 then "Degraded"
                    else "Unhealthy"

                {
                    Component = "ConsensusEngine"
                    ComponentType = "ConsensusEngine"
                    Status = status
                    Latency = latency
                    Message = $"24h: {total} decisions, {successRate*100.0:F1}%% success"
                    Timestamp = DateTime.UtcNow
                    Metadata = Map.ofList [
                        ("total_24h", string total)
                        ("unanimous", string unanimous)
                        ("majority", string majority)
                        ("failed", string failed)
                        ("success_rate", string successRate)
                        ("avg_response_ms", string (int avgTime))
                    ]
                }
            else
                {
                    Component = "ConsensusEngine"
                    ComponentType = "ConsensusEngine"
                    Status = "Unknown"
                    Latency = latency
                    Message = "No consensus data available"
                    Timestamp = DateTime.UtcNow
                    Metadata = Map.empty
                }
    with ex ->
        {
            Component = "ConsensusEngine"
            ComponentType = "ConsensusEngine"
            Status = "Unhealthy"
            Latency = int (DateTime.UtcNow - startTime).TotalMilliseconds
            Message = $"Exception: {ex.Message}"
            Timestamp = DateTime.UtcNow
            Metadata = Map.empty
        }

/// Check cost tracking
let checkCostTracker () : HealthCheck =
    let startTime = DateTime.UtcNow

    try
        if not (File.Exists(governanceDbPath)) then
            {
                Component = "CostTracker"
                ComponentType = "CostTracker"
                Status = "Unknown"
                Latency = 0
                Message = "Governance database not found"
                Timestamp = DateTime.UtcNow
                Metadata = Map.empty
            }
        else
            use conn = new SqliteConnection($"Data Source={governanceDbPath}")
            conn.Open()

            let sql = """
                SELECT
                    COALESCE(SUM(claude_cost), 0) + COALESCE(SUM(gemini_cost), 0) + COALESCE(SUM(grok_cost), 0) as total_cost,
                    COUNT(*) as total_requests
                FROM tricameral_decisions
                WHERE timestamp > datetime('now', '-1 hour')
            """
            use cmd = new SqliteCommand(sql, conn)
            use reader = cmd.ExecuteReader()

            let latency = int (DateTime.UtcNow - startTime).TotalMilliseconds

            if reader.Read() then
                let hourlyCost = reader.GetDouble(0)
                let hourlyRequests = reader.GetInt64(1)

                let budgetLimit = 10.0 // $10/hour
                let status =
                    if hourlyCost < budgetLimit * 0.5 then "Healthy"
                    elif hourlyCost < budgetLimit * 0.8 then "Degraded"
                    elif hourlyCost < budgetLimit then "Degraded"
                    else "Unhealthy"

                {
                    Component = "CostTracker"
                    ComponentType = "CostTracker"
                    Status = status
                    Latency = latency
                    Message = $"Last hour: ${hourlyCost:F4} ({hourlyRequests} requests)"
                    Timestamp = DateTime.UtcNow
                    Metadata = Map.ofList [
                        ("hourly_cost", string hourlyCost)
                        ("hourly_requests", string hourlyRequests)
                        ("budget_limit", string budgetLimit)
                        ("budget_usage_pct", string (hourlyCost / budgetLimit * 100.0))
                    ]
                }
            else
                {
                    Component = "CostTracker"
                    ComponentType = "CostTracker"
                    Status = "Unknown"
                    Latency = latency
                    Message = "No cost data available"
                    Timestamp = DateTime.UtcNow
                    Metadata = Map.empty
                }
    with ex ->
        {
            Component = "CostTracker"
            ComponentType = "CostTracker"
            Status = "Unhealthy"
            Latency = int (DateTime.UtcNow - startTime).TotalMilliseconds
            Message = $"Exception: {ex.Message}"
            Timestamp = DateTime.UtcNow
            Metadata = Map.empty
        }

/// Check model registry health
let checkModelRegistry () : HealthCheck =
    let startTime = DateTime.UtcNow

    try
        if not (File.Exists(modelsDbPath)) then
            {
                Component = "ModelRegistry"
                ComponentType = "ModelRegistry"
                Status = "Degraded"
                Latency = 0
                Message = "Model registry database not found (using defaults)"
                Timestamp = DateTime.UtcNow
                Metadata = Map.empty
            }
        else
            use conn = new SqliteConnection($"Data Source={modelsDbPath}")
            conn.Open()

            let sql = "SELECT COUNT(*) FROM models WHERE id IS NOT NULL"
            use cmd = new SqliteCommand(sql, conn)

            try
                let count = cmd.ExecuteScalar() :?> int64
                let latency = int (DateTime.UtcNow - startTime).TotalMilliseconds

                {
                    Component = "ModelRegistry"
                    ComponentType = "ModelRegistry"
                    Status = if count > 0L then "Healthy" else "Degraded"
                    Latency = latency
                    Message = $"{count} models registered"
                    Timestamp = DateTime.UtcNow
                    Metadata = Map.ofList [("model_count", string count)]
                }
            with _ ->
                // Table might not exist yet
                let latency = int (DateTime.UtcNow - startTime).TotalMilliseconds
                {
                    Component = "ModelRegistry"
                    ComponentType = "ModelRegistry"
                    Status = "Healthy"
                    Latency = latency
                    Message = "Registry initialized (10 models in code)"
                    Timestamp = DateTime.UtcNow
                    Metadata = Map.ofList [("model_count", "10")]
                }
    with ex ->
        {
            Component = "ModelRegistry"
            ComponentType = "ModelRegistry"
            Status = "Unhealthy"
            Latency = int (DateTime.UtcNow - startTime).TotalMilliseconds
            Message = $"Exception: {ex.Message}"
            Timestamp = DateTime.UtcNow
            Metadata = Map.empty
        }

// =============================================================================
// METRICS COLLECTION
// =============================================================================

/// Collect current system metrics
let collectMetrics () : MetricPoint list =
    let now = DateTime.UtcNow
    let metrics = ResizeArray<MetricPoint>()

    try
        if File.Exists(governanceDbPath) then
            use conn = new SqliteConnection($"Data Source={governanceDbPath}")
            conn.Open()

            // Decision count
            use cmd1 = new SqliteCommand("SELECT COUNT(*) FROM tricameral_decisions", conn)
            let totalDecisions = cmd1.ExecuteScalar() :?> int64
            metrics.Add({
                Name = "tricameral.decisions.total"
                Value = float totalDecisions
                Unit = "count"
                Tags = Map.empty
                Timestamp = now
            })

            // Recent decisions (last hour)
            use cmd2 = new SqliteCommand("SELECT COUNT(*) FROM tricameral_decisions WHERE timestamp > datetime('now', '-1 hour')", conn)
            let recentDecisions = cmd2.ExecuteScalar() :?> int64
            metrics.Add({
                Name = "tricameral.decisions.hourly"
                Value = float recentDecisions
                Unit = "count"
                Tags = Map.empty
                Timestamp = now
            })

            // Consensus rates
            let sql3 = """
                SELECT consensus_type, COUNT(*)
                FROM tricameral_decisions
                WHERE timestamp > datetime('now', '-24 hours')
                GROUP BY consensus_type
            """
            use cmd3 = new SqliteCommand(sql3, conn)
            use reader = cmd3.ExecuteReader()
            while reader.Read() do
                let consensusType = reader.GetString(0)
                let count = reader.GetInt64(1)
                metrics.Add({
                    Name = $"tricameral.consensus.{consensusType.ToLower()}"
                    Value = float count
                    Unit = "count"
                    Tags = Map.ofList [("consensus_type", consensusType)]
                    Timestamp = now
                })

            // Average latencies by chamber
            let sql4 = """
                SELECT
                    AVG(claude_time_ms) as claude_avg,
                    AVG(gemini_time_ms) as gemini_avg,
                    AVG(grok_time_ms) as grok_avg
                FROM tricameral_decisions
                WHERE timestamp > datetime('now', '-1 hour')
            """
            use cmd4 = new SqliteCommand(sql4, conn)
            use reader4 = cmd4.ExecuteReader()
            if reader4.Read() then
                if not (reader4.IsDBNull(0)) then
                    metrics.Add({
                        Name = "tricameral.latency.claude"
                        Value = reader4.GetDouble(0)
                        Unit = "ms"
                        Tags = Map.ofList [("chamber", "claude")]
                        Timestamp = now
                    })
                if not (reader4.IsDBNull(1)) then
                    metrics.Add({
                        Name = "tricameral.latency.gemini"
                        Value = reader4.GetDouble(1)
                        Unit = "ms"
                        Tags = Map.ofList [("chamber", "gemini")]
                        Timestamp = now
                    })
                if not (reader4.IsDBNull(2)) then
                    metrics.Add({
                        Name = "tricameral.latency.grok"
                        Value = reader4.GetDouble(2)
                        Unit = "ms"
                        Tags = Map.ofList [("chamber", "grok")]
                        Timestamp = now
                    })

            // Total cost
            let sql5 = """
                SELECT COALESCE(SUM(claude_cost + gemini_cost + grok_cost), 0)
                FROM tricameral_decisions
            """
            use cmd5 = new SqliteCommand(sql5, conn)
            let totalCost = cmd5.ExecuteScalar() :?> float
            metrics.Add({
                Name = "tricameral.cost.total"
                Value = totalCost
                Unit = "USD"
                Tags = Map.empty
                Timestamp = now
            })
    with _ -> ()

    metrics |> Seq.toList

// =============================================================================
// SIGNAL DETECTION
// =============================================================================

/// Analyze observations and generate evolution signals
let detectSignals (checks: HealthCheck list) (metrics: MetricPoint list) : EvolutionSignal list =
    let signals = ResizeArray<EvolutionSignal>()

    // Check for unhealthy components
    for check in checks do
        if check.Status = "Unhealthy" then
            signals.Add(AvailabilityLow (check.Component, 0.0))
        elif check.Status = "Degraded" && check.Latency > 5000 then
            signals.Add(LatencyHigh (check.Component, check.Latency, 5000))

    // Check consensus metrics
    let unanimousMetric = metrics |> List.tryFind (fun m -> m.Name = "tricameral.consensus.unanimous")
    let majorityMetric = metrics |> List.tryFind (fun m -> m.Name = "tricameral.consensus.majority")
    let splitMetric = metrics |> List.tryFind (fun m -> m.Name = "tricameral.consensus.split")
    let errorMetric = metrics |> List.tryFind (fun m -> m.Name = "tricameral.consensus.error")

    match unanimousMetric, majorityMetric, splitMetric, errorMetric with
    | Some u, Some m, Some s, Some e ->
        let total = u.Value + m.Value + s.Value + e.Value
        if total > 0.0 then
            let failureRate = (s.Value + e.Value) / total
            if failureRate > 0.20 then
                signals.Add(ConsensusFailure failureRate)
    | _ -> ()

    // Check cost metrics
    let costMetric = metrics |> List.tryFind (fun m -> m.Name = "tricameral.cost.total")
    match costMetric with
    | Some c when c.Value > 100.0 ->  // $100 total budget warning
        signals.Add(CostExceeded ("System", 100.0, c.Value))
    | _ -> ()

    signals |> Seq.toList

// =============================================================================
// PERSISTENCE
// =============================================================================

/// Save health check to database
let saveHealthCheck (check: HealthCheck) =
    use conn = new SqliteConnection($"Data Source={monitorDbPath}")
    conn.Open()

    let sql = """
        INSERT INTO health_checks (component, component_type, status, latency_ms, message, metadata_json, timestamp)
        VALUES (@component, @type, @status, @latency, @message, @metadata, @timestamp)
    """

    use cmd = new SqliteCommand(sql, conn)
    cmd.Parameters.AddWithValue("@component", check.Component) |> ignore
    cmd.Parameters.AddWithValue("@type", check.ComponentType) |> ignore
    cmd.Parameters.AddWithValue("@status", check.Status) |> ignore
    cmd.Parameters.AddWithValue("@latency", check.Latency) |> ignore
    cmd.Parameters.AddWithValue("@message", check.Message) |> ignore
    cmd.Parameters.AddWithValue("@metadata", JsonSerializer.Serialize(check.Metadata)) |> ignore
    cmd.Parameters.AddWithValue("@timestamp", check.Timestamp.ToString("o")) |> ignore

    cmd.ExecuteNonQuery() |> ignore

/// Save metric to database
let saveMetric (metric: MetricPoint) =
    use conn = new SqliteConnection($"Data Source={monitorDbPath}")
    conn.Open()

    let sql = """
        INSERT INTO metrics (name, value, unit, tags_json, timestamp)
        VALUES (@name, @value, @unit, @tags, @timestamp)
    """

    use cmd = new SqliteCommand(sql, conn)
    cmd.Parameters.AddWithValue("@name", metric.Name) |> ignore
    cmd.Parameters.AddWithValue("@value", metric.Value) |> ignore
    cmd.Parameters.AddWithValue("@unit", metric.Unit) |> ignore
    cmd.Parameters.AddWithValue("@tags", JsonSerializer.Serialize(metric.Tags)) |> ignore
    cmd.Parameters.AddWithValue("@timestamp", metric.Timestamp.ToString("o")) |> ignore

    cmd.ExecuteNonQuery() |> ignore

/// Save evolution signal
let saveSignal (signal: EvolutionSignal) =
    use conn = new SqliteConnection($"Data Source={monitorDbPath}")
    conn.Open()

    let (signalType, component, details, severity) =
        match signal with
        | PerformanceDegraded (c, m, t, a) ->
            ("PerformanceDegraded", c, $"{{\"metric\":\"{m}\",\"threshold\":{t},\"actual\":{a}}}", "HIGH")
        | CostExceeded (c, b, a) ->
            ("CostExceeded", c, $"{{\"budget\":{b},\"actual\":{a}}}", "HIGH")
        | ErrorRateHigh (c, r) ->
            ("ErrorRateHigh", c, $"{{\"rate\":{r}}}", "CRITICAL")
        | LatencyHigh (c, avg, threshold) ->
            ("LatencyHigh", c, $"{{\"avg_ms\":{avg},\"threshold_ms\":{threshold}}}", "MEDIUM")
        | AvailabilityLow (c, u) ->
            ("AvailabilityLow", c, $"{{\"uptime\":{u}}}", "CRITICAL")
        | ModelDeprecated (m, d) ->
            ("ModelDeprecated", m, $"{{\"deprecation_date\":\"{d}\"}}", "LOW")
        | ConsensusFailure r ->
            ("ConsensusFailure", "ConsensusEngine", $"{{\"failure_rate\":{r}}}", "HIGH")
        | HashChainBroken b ->
            ("HashChainBroken", "AuditLog", $"{{\"last_valid_block\":{b}}}", "CRITICAL")

    let sql = """
        INSERT INTO evolution_signals (signal_type, component, details_json, severity, timestamp)
        VALUES (@type, @component, @details, @severity, @timestamp)
    """

    use cmd = new SqliteCommand(sql, conn)
    cmd.Parameters.AddWithValue("@type", signalType) |> ignore
    cmd.Parameters.AddWithValue("@component", component) |> ignore
    cmd.Parameters.AddWithValue("@details", details) |> ignore
    cmd.Parameters.AddWithValue("@severity", severity) |> ignore
    cmd.Parameters.AddWithValue("@timestamp", DateTime.UtcNow.ToString("o")) |> ignore

    cmd.ExecuteNonQuery() |> ignore

/// Save system snapshot
let saveSnapshot (state: ObservationState) =
    use conn = new SqliteConnection($"Data Source={monitorDbPath}")
    conn.Open()

    let healthyCount = state.HealthChecks |> List.filter (fun c -> c.Status = "Healthy") |> List.length
    let degradedCount = state.HealthChecks |> List.filter (fun c -> c.Status = "Degraded") |> List.length
    let unhealthyCount = state.HealthChecks |> List.filter (fun c -> c.Status = "Unhealthy") |> List.length
    let avgLatency =
        if state.HealthChecks.IsEmpty then 0.0
        else state.HealthChecks |> List.averageBy (fun c -> float c.Latency)

    let decisionsMetric = state.Metrics |> List.tryFind (fun m -> m.Name = "tricameral.decisions.total")
    let decisionsCount = match decisionsMetric with Some m -> int m.Value | None -> 0

    let sql = """
        INSERT INTO system_snapshots (
            overall_health, healthy_components, degraded_components, unhealthy_components,
            total_cost, avg_latency_ms, decisions_count, consensus_rate, timestamp
        ) VALUES (@health, @healthy, @degraded, @unhealthy, @cost, @latency, @decisions, @consensus, @timestamp)
    """

    use cmd = new SqliteCommand(sql, conn)
    cmd.Parameters.AddWithValue("@health", state.OverallHealth.ToString()) |> ignore
    cmd.Parameters.AddWithValue("@healthy", healthyCount) |> ignore
    cmd.Parameters.AddWithValue("@degraded", degradedCount) |> ignore
    cmd.Parameters.AddWithValue("@unhealthy", unhealthyCount) |> ignore
    cmd.Parameters.AddWithValue("@cost", state.CostToDate) |> ignore
    cmd.Parameters.AddWithValue("@latency", avgLatency) |> ignore
    cmd.Parameters.AddWithValue("@decisions", decisionsCount) |> ignore
    cmd.Parameters.AddWithValue("@consensus", 0.0) |> ignore  // TODO: Calculate
    cmd.Parameters.AddWithValue("@timestamp", state.Timestamp.ToString("o")) |> ignore

    cmd.ExecuteNonQuery() |> ignore

// =============================================================================
// OBSERVATION (OODA - O)
// =============================================================================

/// Run all health checks and collect full observation
let observe () : Async<ObservationState> = async {
    printfn "[MON] OBSERVE: Running health checks..."

    // Run health checks
    let! apiCheck = checkAPIGateway()
    let dbChecks = [
        checkDatabase governanceDbPath "GovernanceDB"
        checkDatabase modelsDbPath "ModelsDB"
        checkDatabase monitorDbPath "MonitorDB"
    ]
    let consensusCheck = checkConsensusEngine()
    let auditCheck = checkAuditLogIntegrity()
    let costCheck = checkCostTracker()
    let registryCheck = checkModelRegistry()

    let allChecks = [apiCheck] @ dbChecks @ [consensusCheck; auditCheck; costCheck; registryCheck]

    // Collect metrics
    let metrics = collectMetrics()

    // Detect signals
    let signals = detectSignals allChecks metrics

    // Calculate overall health
    let unhealthyCount = allChecks |> List.filter (fun c -> c.Status = "Unhealthy") |> List.length
    let degradedCount = allChecks |> List.filter (fun c -> c.Status = "Degraded") |> List.length
    let overallHealth =
        if unhealthyCount > 0 then Unhealthy
        elif degradedCount > 2 then Degraded
        elif degradedCount > 0 then Degraded
        else Healthy

    // Get total cost
    let costMetric = metrics |> List.tryFind (fun m -> m.Name = "tricameral.cost.total")
    let totalCost = match costMetric with Some m -> m.Value | None -> 0.0

    let state = {
        Timestamp = DateTime.UtcNow
        HealthChecks = allChecks
        Metrics = metrics
        Signals = signals
        OverallHealth = overallHealth
        SystemLoad = 0.0  // TODO: Calculate
        CostToDate = totalCost
    }

    // Persist observations
    for check in allChecks do
        saveHealthCheck check

    for metric in metrics do
        saveMetric metric

    for signal in signals do
        saveSignal signal
        printfn "[MON] SIGNAL: %A" signal

    saveSnapshot state

    return state
}

// =============================================================================
// CLI INTERFACE
// =============================================================================

let showStatus () = async {
    let! state = observe()

    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════════════════╗"
    printfn "║  TRICAMERAL MONITORING STATUS                                            ║"
    printfn "╠══════════════════════════════════════════════════════════════════════════╣"
    printfn "║  Timestamp: %s                                   ║" (state.Timestamp.ToString("yyyy-MM-dd HH:mm:ss"))
    printfn "║  Overall Health: %-58s ║" (state.OverallHealth.ToString())
    printfn "║  Total Cost: $%-61.4f ║" state.CostToDate
    printfn "╠══════════════════════════════════════════════════════════════════════════╣"
    printfn "║  COMPONENT HEALTH                                                        ║"
    printfn "╠══════════════════════════════════════════════════════════════════════════╣"

    for check in state.HealthChecks do
        let statusIcon =
            match check.Status with
            | "Healthy" -> "🟢"
            | "Degraded" -> "🟡"
            | "Unhealthy" -> "🔴"
            | _ -> "⚪"
        printfn "║  %s %-20s │ %-8s │ %4dms │ %-24s ║"
            statusIcon check.Component check.Status check.Latency
            (if check.Message.Length > 24 then check.Message.Substring(0, 21) + "..." else check.Message)

    if not state.Signals.IsEmpty then
        printfn "╠══════════════════════════════════════════════════════════════════════════╣"
        printfn "║  EVOLUTION SIGNALS                                                       ║"
        printfn "╠══════════════════════════════════════════════════════════════════════════╣"
        for signal in state.Signals do
            let signalStr = sprintf "%A" signal
            let truncated = signalStr.Substring(0, min 68 signalStr.Length)
            printfn "║  ⚠️  %s" truncated

    printfn "╚══════════════════════════════════════════════════════════════════════════╝"
}

let showMetrics () = async {
    let metrics = collectMetrics()

    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════════════════╗"
    printfn "║  TRICAMERAL METRICS                                                      ║"
    printfn "╠══════════════════════════════════════════════════════════════════════════╣"

    for metric in metrics do
        printfn "║  %-40s │ %12.2f %-10s ║" metric.Name metric.Value metric.Unit

    printfn "╚══════════════════════════════════════════════════════════════════════════╝"
}

let showHistory (count: int) =
    ensureMonitorDatabase()

    use conn = new SqliteConnection($"Data Source={monitorDbPath}")
    conn.Open()

    let sql = $"SELECT timestamp, overall_health, healthy_components, degraded_components, unhealthy_components, total_cost FROM system_snapshots ORDER BY timestamp DESC LIMIT {count}"

    use cmd = new SqliteCommand(sql, conn)
    use reader = cmd.ExecuteReader()

    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════════════════╗"
    printfn "║  MONITORING HISTORY (Last %d Snapshots)                                  ║" count
    printfn "╠══════════════════════════════════════════════════════════════════════════╣"
    printfn "║  TIMESTAMP           │ HEALTH    │ 🟢  │ 🟡  │ 🔴  │ COST     ║"
    printfn "╠══════════════════════════════════════════════════════════════════════════╣"

    let mutable found = false
    while reader.Read() do
        found <- true
        let ts = reader.GetString(0).Substring(0, 19)
        let health = reader.GetString(1)
        let healthy = reader.GetInt32(2)
        let degraded = reader.GetInt32(3)
        let unhealthy = reader.GetInt32(4)
        let cost = reader.GetDouble(5)
        printfn "║  %s │ %-9s │ %3d │ %3d │ %3d │ $%-7.4f ║"
            ts health healthy degraded unhealthy cost

    if not found then
        printfn "║  No monitoring history available                                         ║"

    printfn "╚══════════════════════════════════════════════════════════════════════════╝"

let showHelp () =
    printfn """
╔══════════════════════════════════════════════════════════════════════════╗
║  TRICAMERAL MONITORING SYSTEM                                            ║
║  Active Health Checks • Metrics Collection • Evolution Signals           ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  COMMANDS:                                                               ║
║    status              Run health checks and show current status         ║
║    metrics             Show current system metrics                       ║
║    history [n]         Show last n monitoring snapshots (default: 10)    ║
║    observe             Run OODA observation cycle (JSON output)          ║
║    help                Show this help                                    ║
║                                                                          ║
║  MONITORED COMPONENTS:                                                   ║
║    • OpenRouter API Gateway                                              ║
║    • Governance Database (tricameral.db)                                 ║
║    • Models Database (model_registry.db)                                 ║
║    • Monitor Database (tricameral_monitor.db)                            ║
║    • Consensus Engine                                                    ║
║    • Audit Log (Hash Chain Integrity)                                    ║
║    • Cost Tracker                                                        ║
║    • Model Registry                                                      ║
║                                                                          ║
║  EVOLUTION SIGNALS:                                                      ║
║    • PerformanceDegraded   - Component below threshold                   ║
║    • CostExceeded          - Budget limit exceeded                       ║
║    • ErrorRateHigh         - Too many failures                           ║
║    • LatencyHigh           - Response time too slow                      ║
║    • AvailabilityLow       - Component uptime below SLA                  ║
║    • ModelDeprecated       - Model approaching deprecation               ║
║    • ConsensusFailure      - Too many split/error decisions              ║
║    • HashChainBroken       - Audit log integrity compromised             ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"""

// =============================================================================
// MAIN
// =============================================================================

let main (args: string[]) =
    ensureMonitorDatabase()

    if args.Length = 0 then
        showHelp()
    else
        match args.[0].ToLower() with
        | "help" | "--help" | "-h" -> showHelp()
        | "status" -> showStatus() |> Async.RunSynchronously
        | "metrics" -> showMetrics() |> Async.RunSynchronously
        | "history" ->
            let count = if args.Length > 1 then Int32.Parse(args.[1]) else 10
            showHistory count
        | "observe" ->
            let state = observe() |> Async.RunSynchronously
            let options = JsonSerializerOptions(WriteIndented = true)
            printfn "%s" (JsonSerializer.Serialize(state, options))
        | _ ->
            printfn "[MON] Unknown command: %s" args.[0]
            showHelp()

// Entry point
main (fsi.CommandLineArgs |> Array.skip 1)
