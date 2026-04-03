#!/usr/bin/env dotnet fsi

// =============================================================================
// API USAGE TRACKER - Comprehensive External Model Activity Monitoring
// =============================================================================
// STAMP: SC-METRICS-001 to SC-METRICS-020
// Tracks ALL external AI model API calls with full granularity
// Version: 1.0.0 | Created: 2026-01-11
// =============================================================================

#r "nuget: Microsoft.Data.Sqlite"
#r "nuget: System.Text.Json"

open System
open System.IO
open System.Text.Json
open System.Text.Json.Serialization
open Microsoft.Data.Sqlite

// =============================================================================
// TYPES - Full Granularity Tracking
// =============================================================================

/// API call record with complete metrics
[<CLIMutable>]
type ApiCallRecord = {
    [<JsonPropertyName("id")>]
    Id: string
    [<JsonPropertyName("timestamp")>]
    Timestamp: DateTime
    [<JsonPropertyName("session_id")>]
    SessionId: string

    // Model Information
    [<JsonPropertyName("provider")>]
    Provider: string              // anthropic, google, x-ai
    [<JsonPropertyName("model_id")>]
    ModelId: string               // Full OpenRouter model ID
    [<JsonPropertyName("model_name")>]
    ModelName: string             // Human readable name
    [<JsonPropertyName("model_tier")>]
    ModelTier: string             // Frontier, Performance, Efficient, Economy

    // Token Metrics
    [<JsonPropertyName("input_tokens")>]
    InputTokens: int
    [<JsonPropertyName("output_tokens")>]
    OutputTokens: int
    [<JsonPropertyName("total_tokens")>]
    TotalTokens: int
    [<JsonPropertyName("cached_tokens")>]
    CachedTokens: int             // Prompt caching tokens

    // Cost Metrics (USD)
    [<JsonPropertyName("input_cost")>]
    InputCost: float
    [<JsonPropertyName("output_cost")>]
    OutputCost: float
    [<JsonPropertyName("total_cost")>]
    TotalCost: float
    [<JsonPropertyName("cached_savings")>]
    CachedSavings: float          // Savings from prompt caching

    // Performance Metrics
    [<JsonPropertyName("latency_ms")>]
    LatencyMs: int
    [<JsonPropertyName("tokens_per_second")>]
    TokensPerSecond: float
    [<JsonPropertyName("time_to_first_token_ms")>]
    TimeToFirstTokenMs: int

    // Request Context
    [<JsonPropertyName("request_type")>]
    RequestType: string           // chat, completion, embedding
    [<JsonPropertyName("chamber")>]
    Chamber: string               // Constitutional, Technical, Pragmatic
    [<JsonPropertyName("decision_category")>]
    DecisionCategory: string      // Existential, Architectural, Operational, etc.
    [<JsonPropertyName("task_id")>]
    TaskId: string

    // Response Metrics
    [<JsonPropertyName("success")>]
    Success: bool
    [<JsonPropertyName("error_code")>]
    ErrorCode: string option
    [<JsonPropertyName("error_message")>]
    ErrorMessage: string option
    [<JsonPropertyName("finish_reason")>]
    FinishReason: string          // stop, length, tool_calls, error

    // Quality Metrics
    [<JsonPropertyName("confidence_score")>]
    ConfidenceScore: float option
    [<JsonPropertyName("consensus_vote")>]
    ConsensusVote: string option  // approve, reject, abstain
}

/// Session aggregate metrics
[<CLIMutable>]
type SessionMetrics = {
    SessionId: string
    StartTime: DateTime
    EndTime: DateTime option
    TotalCalls: int
    TotalInputTokens: int
    TotalOutputTokens: int
    TotalCost: float
    TotalSavings: float
    AvgLatencyMs: float
    SuccessRate: float
    CallsByProvider: Map<string, int>
    CallsByTier: Map<string, int>
    CostByProvider: Map<string, float>
}

/// Model pricing configuration
[<CLIMutable>]
type ModelPricing = {
    ModelId: string
    InputPerMillion: float
    OutputPerMillion: float
    CachedInputPerMillion: float option
}

// =============================================================================
// DATABASE SETUP
// =============================================================================

let projectRoot =
    let current = Directory.GetCurrentDirectory()
    if current.Contains("lib/cepaf") then
        Path.GetFullPath(Path.Combine(current, "../.."))
    else current

let dataPath = Path.Combine(projectRoot, "data", "metrics")
let dbPath = Path.Combine(dataPath, "api_usage.db")

/// Initialize the metrics database with full schema
let initializeDatabase () =
    Directory.CreateDirectory(dataPath) |> ignore

    use conn = new SqliteConnection($"Data Source={dbPath}")
    conn.Open()

    let schema = """
        -- API Call Records (granular)
        CREATE TABLE IF NOT EXISTS api_calls (
            id TEXT PRIMARY KEY,
            timestamp TEXT NOT NULL,
            session_id TEXT NOT NULL,

            -- Model Info
            provider TEXT NOT NULL,
            model_id TEXT NOT NULL,
            model_name TEXT,
            model_tier TEXT,

            -- Token Metrics
            input_tokens INTEGER NOT NULL DEFAULT 0,
            output_tokens INTEGER NOT NULL DEFAULT 0,
            total_tokens INTEGER NOT NULL DEFAULT 0,
            cached_tokens INTEGER DEFAULT 0,

            -- Cost Metrics (stored as cents for precision)
            input_cost_cents INTEGER NOT NULL DEFAULT 0,
            output_cost_cents INTEGER NOT NULL DEFAULT 0,
            total_cost_cents INTEGER NOT NULL DEFAULT 0,
            cached_savings_cents INTEGER DEFAULT 0,

            -- Performance
            latency_ms INTEGER,
            tokens_per_second REAL,
            time_to_first_token_ms INTEGER,

            -- Context
            request_type TEXT,
            chamber TEXT,
            decision_category TEXT,
            task_id TEXT,

            -- Response
            success INTEGER NOT NULL DEFAULT 1,
            error_code TEXT,
            error_message TEXT,
            finish_reason TEXT,

            -- Quality
            confidence_score REAL,
            consensus_vote TEXT
        );

        -- Session Aggregates
        CREATE TABLE IF NOT EXISTS sessions (
            session_id TEXT PRIMARY KEY,
            start_time TEXT NOT NULL,
            end_time TEXT,
            total_calls INTEGER DEFAULT 0,
            total_input_tokens INTEGER DEFAULT 0,
            total_output_tokens INTEGER DEFAULT 0,
            total_cost_cents INTEGER DEFAULT 0,
            total_savings_cents INTEGER DEFAULT 0,
            avg_latency_ms REAL,
            success_rate REAL,
            metadata_json TEXT
        );

        -- Model Pricing Reference
        CREATE TABLE IF NOT EXISTS model_pricing (
            model_id TEXT PRIMARY KEY,
            provider TEXT NOT NULL,
            model_name TEXT,
            input_per_million REAL NOT NULL,
            output_per_million REAL NOT NULL,
            cached_input_per_million REAL,
            updated_at TEXT NOT NULL
        );

        -- Hourly Aggregates (for dashboards)
        CREATE TABLE IF NOT EXISTS hourly_metrics (
            hour TEXT PRIMARY KEY,  -- ISO format: 2026-01-11T09:00:00
            total_calls INTEGER DEFAULT 0,
            total_tokens INTEGER DEFAULT 0,
            total_cost_cents INTEGER DEFAULT 0,
            calls_by_provider_json TEXT,
            calls_by_tier_json TEXT,
            avg_latency_ms REAL,
            error_count INTEGER DEFAULT 0
        );

        -- Daily Aggregates
        CREATE TABLE IF NOT EXISTS daily_metrics (
            date TEXT PRIMARY KEY,  -- ISO format: 2026-01-11
            total_calls INTEGER DEFAULT 0,
            total_tokens INTEGER DEFAULT 0,
            total_cost_cents INTEGER DEFAULT 0,
            unique_sessions INTEGER DEFAULT 0,
            calls_by_provider_json TEXT,
            cost_by_provider_json TEXT,
            peak_hour TEXT,
            avg_latency_ms REAL
        );

        -- Indexes for fast queries
        CREATE INDEX IF NOT EXISTS idx_calls_timestamp ON api_calls(timestamp);
        CREATE INDEX IF NOT EXISTS idx_calls_session ON api_calls(session_id);
        CREATE INDEX IF NOT EXISTS idx_calls_provider ON api_calls(provider);
        CREATE INDEX IF NOT EXISTS idx_calls_model ON api_calls(model_id);
        CREATE INDEX IF NOT EXISTS idx_calls_chamber ON api_calls(chamber);
        CREATE INDEX IF NOT EXISTS idx_hourly_hour ON hourly_metrics(hour);
    """

    use cmd = new SqliteCommand(schema, conn)
    cmd.ExecuteNonQuery() |> ignore

    printfn "[METRICS] Database initialized at %s" dbPath

/// Load model pricing from registry
let loadModelPricing () =
    let pricingData = [
        // Anthropic
        ("anthropic/claude-3-opus", "Anthropic", "Claude 3 Opus", 15.0, 75.0, Some 3.75)
        ("anthropic/claude-3.5-sonnet", "Anthropic", "Claude 3.5 Sonnet", 3.0, 15.0, Some 0.75)
        ("anthropic/claude-3.5-haiku", "Anthropic", "Claude 3.5 Haiku", 0.80, 4.0, Some 0.20)
        // Google
        ("google/gemini-2.0-flash-thinking-exp:free", "Google", "Gemini 2.0 Flash Thinking", 0.0, 0.0, None)
        ("google/gemini-2.0-flash-exp:free", "Google", "Gemini 2.0 Flash", 0.0, 0.0, None)
        ("google/gemini-pro-1.5", "Google", "Gemini 1.5 Pro", 2.50, 10.0, Some 0.625)
        ("google/gemini-flash-1.5", "Google", "Gemini 1.5 Flash", 0.30, 1.0, Some 0.075)
        // xAI
        ("x-ai/grok-2-1212", "xAI", "Grok 2", 2.0, 10.0, None)
        ("x-ai/grok-beta", "xAI", "Grok Beta", 5.0, 15.0, None)
        ("x-ai/grok-2-vision-1212", "xAI", "Grok 2 Vision", 2.0, 10.0, None)
    ]

    use conn = new SqliteConnection($"Data Source={dbPath}")
    conn.Open()

    for (modelId, provider, name, inputPrice, outputPrice, cachedPrice) in pricingData do
        let sql = """
            INSERT OR REPLACE INTO model_pricing
            (model_id, provider, model_name, input_per_million, output_per_million, cached_input_per_million, updated_at)
            VALUES (@id, @provider, @name, @input, @output, @cached, @updated)
        """
        use cmd = new SqliteCommand(sql, conn)
        cmd.Parameters.AddWithValue("@id", modelId) |> ignore
        cmd.Parameters.AddWithValue("@provider", provider) |> ignore
        cmd.Parameters.AddWithValue("@name", name) |> ignore
        cmd.Parameters.AddWithValue("@input", inputPrice) |> ignore
        cmd.Parameters.AddWithValue("@output", outputPrice) |> ignore
        cmd.Parameters.AddWithValue("@cached", cachedPrice |> Option.defaultValue 0.0) |> ignore
        cmd.Parameters.AddWithValue("@updated", DateTime.UtcNow.ToString("o")) |> ignore
        cmd.ExecuteNonQuery() |> ignore

    printfn "[METRICS] Loaded pricing for %d models" (List.length pricingData)

// =============================================================================
// TRACKING FUNCTIONS
// =============================================================================

/// Get pricing for a model
let getModelPricing (modelId: string) =
    use conn = new SqliteConnection($"Data Source={dbPath}")
    conn.Open()

    let sql = "SELECT input_per_million, output_per_million, cached_input_per_million FROM model_pricing WHERE model_id = @id"
    use cmd = new SqliteCommand(sql, conn)
    cmd.Parameters.AddWithValue("@id", modelId) |> ignore

    use reader = cmd.ExecuteReader()
    if reader.Read() then
        Some {
            ModelId = modelId
            InputPerMillion = reader.GetDouble(0)
            OutputPerMillion = reader.GetDouble(1)
            CachedInputPerMillion = if reader.IsDBNull(2) then None else Some (reader.GetDouble(2))
        }
    else
        // Default pricing if not found
        Some {
            ModelId = modelId
            InputPerMillion = 1.0
            OutputPerMillion = 5.0
            CachedInputPerMillion = None
        }

/// Calculate cost for tokens
let calculateCost (pricing: ModelPricing) (inputTokens: int) (outputTokens: int) (cachedTokens: int) =
    let inputCost = float inputTokens * pricing.InputPerMillion / 1_000_000.0
    let outputCost = float outputTokens * pricing.OutputPerMillion / 1_000_000.0
    let cachedSavings =
        match pricing.CachedInputPerMillion with
        | Some cachedRate ->
            let normalCost = float cachedTokens * pricing.InputPerMillion / 1_000_000.0
            let cachedCost = float cachedTokens * cachedRate / 1_000_000.0
            normalCost - cachedCost
        | None -> 0.0

    (inputCost, outputCost, inputCost + outputCost, cachedSavings)

/// Update hourly aggregate metrics (must be defined before recordApiCall)
let updateHourlyMetrics (record: ApiCallRecord) (conn: SqliteConnection) =
    let hour = record.Timestamp.ToString("yyyy-MM-ddTHH:00:00")

    let sql = """
        INSERT INTO hourly_metrics (hour, total_calls, total_tokens, total_cost_cents, avg_latency_ms, error_count)
        VALUES (@hour, 1, @tokens, @cost, @latency, @error)
        ON CONFLICT(hour) DO UPDATE SET
            total_calls = total_calls + 1,
            total_tokens = total_tokens + @tokens,
            total_cost_cents = total_cost_cents + @cost,
            avg_latency_ms = (avg_latency_ms * total_calls + @latency) / (total_calls + 1),
            error_count = error_count + @error
    """

    use cmd = new SqliteCommand(sql, conn)
    cmd.Parameters.AddWithValue("@hour", hour) |> ignore
    cmd.Parameters.AddWithValue("@tokens", record.TotalTokens) |> ignore
    cmd.Parameters.AddWithValue("@cost", int (record.TotalCost * 100.0)) |> ignore
    cmd.Parameters.AddWithValue("@latency", record.LatencyMs) |> ignore
    cmd.Parameters.AddWithValue("@error", if record.Success then 0 else 1) |> ignore
    cmd.ExecuteNonQuery() |> ignore

/// Record an API call with full metrics
let recordApiCall (record: ApiCallRecord) =
    use conn = new SqliteConnection($"Data Source={dbPath}")
    conn.Open()

    let sql = """
        INSERT INTO api_calls (
            id, timestamp, session_id,
            provider, model_id, model_name, model_tier,
            input_tokens, output_tokens, total_tokens, cached_tokens,
            input_cost_cents, output_cost_cents, total_cost_cents, cached_savings_cents,
            latency_ms, tokens_per_second, time_to_first_token_ms,
            request_type, chamber, decision_category, task_id,
            success, error_code, error_message, finish_reason,
            confidence_score, consensus_vote
        ) VALUES (
            @id, @ts, @session,
            @provider, @model_id, @model_name, @tier,
            @input_tok, @output_tok, @total_tok, @cached_tok,
            @input_cost, @output_cost, @total_cost, @savings,
            @latency, @tps, @ttft,
            @req_type, @chamber, @category, @task,
            @success, @error_code, @error_msg, @finish,
            @confidence, @vote
        )
    """

    use cmd = new SqliteCommand(sql, conn)
    cmd.Parameters.AddWithValue("@id", record.Id) |> ignore
    cmd.Parameters.AddWithValue("@ts", record.Timestamp.ToString("o")) |> ignore
    cmd.Parameters.AddWithValue("@session", record.SessionId) |> ignore
    cmd.Parameters.AddWithValue("@provider", record.Provider) |> ignore
    cmd.Parameters.AddWithValue("@model_id", record.ModelId) |> ignore
    cmd.Parameters.AddWithValue("@model_name", record.ModelName) |> ignore
    cmd.Parameters.AddWithValue("@tier", record.ModelTier) |> ignore
    cmd.Parameters.AddWithValue("@input_tok", record.InputTokens) |> ignore
    cmd.Parameters.AddWithValue("@output_tok", record.OutputTokens) |> ignore
    cmd.Parameters.AddWithValue("@total_tok", record.TotalTokens) |> ignore
    cmd.Parameters.AddWithValue("@cached_tok", record.CachedTokens) |> ignore
    cmd.Parameters.AddWithValue("@input_cost", int (record.InputCost * 100.0)) |> ignore
    cmd.Parameters.AddWithValue("@output_cost", int (record.OutputCost * 100.0)) |> ignore
    cmd.Parameters.AddWithValue("@total_cost", int (record.TotalCost * 100.0)) |> ignore
    cmd.Parameters.AddWithValue("@savings", int (record.CachedSavings * 100.0)) |> ignore
    cmd.Parameters.AddWithValue("@latency", record.LatencyMs) |> ignore
    cmd.Parameters.AddWithValue("@tps", record.TokensPerSecond) |> ignore
    cmd.Parameters.AddWithValue("@ttft", record.TimeToFirstTokenMs) |> ignore
    cmd.Parameters.AddWithValue("@req_type", record.RequestType) |> ignore
    cmd.Parameters.AddWithValue("@chamber", record.Chamber) |> ignore
    cmd.Parameters.AddWithValue("@category", record.DecisionCategory) |> ignore
    cmd.Parameters.AddWithValue("@task", record.TaskId) |> ignore
    cmd.Parameters.AddWithValue("@success", if record.Success then 1 else 0) |> ignore
    cmd.Parameters.AddWithValue("@error_code", record.ErrorCode |> Option.defaultValue "") |> ignore
    cmd.Parameters.AddWithValue("@error_msg", record.ErrorMessage |> Option.defaultValue "") |> ignore
    cmd.Parameters.AddWithValue("@finish", record.FinishReason) |> ignore
    cmd.Parameters.AddWithValue("@confidence", record.ConfidenceScore |> Option.defaultValue 0.0) |> ignore
    cmd.Parameters.AddWithValue("@vote", record.ConsensusVote |> Option.defaultValue "") |> ignore

    cmd.ExecuteNonQuery() |> ignore

    // Update hourly aggregate
    updateHourlyMetrics record conn

/// Create a tracking record from API response
let createTrackingRecord
    (sessionId: string)
    (modelId: string)
    (chamber: string)
    (category: string)
    (taskId: string)
    (inputTokens: int)
    (outputTokens: int)
    (cachedTokens: int)
    (latencyMs: int)
    (success: bool)
    (finishReason: string)
    (confidenceScore: float option)
    (vote: string option)
    (errorCode: string option)
    (errorMessage: string option) =

    let pricing = getModelPricing modelId |> Option.get
    let (inputCost, outputCost, totalCost, savings) = calculateCost pricing inputTokens outputTokens cachedTokens

    let provider =
        if modelId.StartsWith("anthropic/") then "Anthropic"
        elif modelId.StartsWith("google/") then "Google"
        elif modelId.StartsWith("x-ai/") then "xAI"
        else "Unknown"

    let tier =
        if modelId.Contains("opus") || modelId.Contains("pro") then "Frontier"
        elif modelId.Contains("sonnet") || modelId.Contains("grok-2") then "Performance"
        elif modelId.Contains("haiku") || modelId.Contains("flash") then "Efficient"
        else "Standard"

    let tps = if latencyMs > 0 then float outputTokens / (float latencyMs / 1000.0) else 0.0

    {
        Id = Guid.NewGuid().ToString()
        Timestamp = DateTime.UtcNow
        SessionId = sessionId
        Provider = provider
        ModelId = modelId
        ModelName = modelId.Split('/').[1]
        ModelTier = tier
        InputTokens = inputTokens
        OutputTokens = outputTokens
        TotalTokens = inputTokens + outputTokens
        CachedTokens = cachedTokens
        InputCost = inputCost
        OutputCost = outputCost
        TotalCost = totalCost
        CachedSavings = savings
        LatencyMs = latencyMs
        TokensPerSecond = tps
        TimeToFirstTokenMs = latencyMs / 4  // Estimate
        RequestType = "chat"
        Chamber = chamber
        DecisionCategory = category
        TaskId = taskId
        Success = success
        ErrorCode = errorCode
        ErrorMessage = errorMessage
        FinishReason = finishReason
        ConfidenceScore = confidenceScore
        ConsensusVote = vote
    }

// =============================================================================
// QUERY FUNCTIONS
// =============================================================================

/// Get session summary
let getSessionSummary (sessionId: string) =
    use conn = new SqliteConnection($"Data Source={dbPath}")
    conn.Open()

    let sql = """
        SELECT
            COUNT(*) as total_calls,
            SUM(input_tokens) as total_input,
            SUM(output_tokens) as total_output,
            SUM(total_cost_cents) / 100.0 as total_cost,
            SUM(cached_savings_cents) / 100.0 as total_savings,
            AVG(latency_ms) as avg_latency,
            AVG(CASE WHEN success = 1 THEN 100.0 ELSE 0.0 END) as success_rate,
            MIN(timestamp) as start_time,
            MAX(timestamp) as end_time
        FROM api_calls
        WHERE session_id = @session
    """

    use cmd = new SqliteCommand(sql, conn)
    cmd.Parameters.AddWithValue("@session", sessionId) |> ignore

    use reader = cmd.ExecuteReader()
    if reader.Read() then
        Some {|
            TotalCalls = reader.GetInt32(0)
            TotalInputTokens = if reader.IsDBNull(1) then 0 else reader.GetInt32(1)
            TotalOutputTokens = if reader.IsDBNull(2) then 0 else reader.GetInt32(2)
            TotalCost = if reader.IsDBNull(3) then 0.0 else reader.GetDouble(3)
            TotalSavings = if reader.IsDBNull(4) then 0.0 else reader.GetDouble(4)
            AvgLatencyMs = if reader.IsDBNull(5) then 0.0 else reader.GetDouble(5)
            SuccessRate = if reader.IsDBNull(6) then 0.0 else reader.GetDouble(6)
            StartTime = if reader.IsDBNull(7) then "" else reader.GetString(7)
            EndTime = if reader.IsDBNull(8) then "" else reader.GetString(8)
        |}
    else None

/// Get provider breakdown
let getProviderBreakdown (hours: int) =
    use conn = new SqliteConnection($"Data Source={dbPath}")
    conn.Open()

    let cutoff = DateTime.UtcNow.AddHours(float -hours).ToString("o")

    let sql = """
        SELECT
            provider,
            COUNT(*) as calls,
            SUM(total_tokens) as tokens,
            SUM(total_cost_cents) / 100.0 as cost,
            AVG(latency_ms) as avg_latency
        FROM api_calls
        WHERE timestamp > @cutoff
        GROUP BY provider
        ORDER BY cost DESC
    """

    use cmd = new SqliteCommand(sql, conn)
    cmd.Parameters.AddWithValue("@cutoff", cutoff) |> ignore

    use reader = cmd.ExecuteReader()
    let results = ResizeArray<_>()
    while reader.Read() do
        results.Add({|
            Provider = reader.GetString(0)
            Calls = reader.GetInt32(1)
            Tokens = reader.GetInt32(2)
            Cost = reader.GetDouble(3)
            AvgLatency = reader.GetDouble(4)
        |})
    results |> Seq.toList

/// Get recent calls
let getRecentCalls (limit: int) =
    use conn = new SqliteConnection($"Data Source={dbPath}")
    conn.Open()

    let sql = $"SELECT id, timestamp, model_id, chamber, input_tokens, output_tokens, total_cost_cents / 100.0, latency_ms, success FROM api_calls ORDER BY timestamp DESC LIMIT {limit}"

    use cmd = new SqliteCommand(sql, conn)
    use reader = cmd.ExecuteReader()

    let results = ResizeArray<_>()
    while reader.Read() do
        results.Add({|
            Id = reader.GetString(0)
            Timestamp = reader.GetString(1)
            ModelId = reader.GetString(2)
            Chamber = reader.GetString(3)
            InputTokens = reader.GetInt32(4)
            OutputTokens = reader.GetInt32(5)
            Cost = reader.GetDouble(6)
            LatencyMs = reader.GetInt32(7)
            Success = reader.GetInt32(8) = 1
        |})
    results |> Seq.toList

/// Get total stats
let getTotalStats () =
    use conn = new SqliteConnection($"Data Source={dbPath}")
    conn.Open()

    let sql = """
        SELECT
            COUNT(*) as total_calls,
            SUM(input_tokens) as total_input,
            SUM(output_tokens) as total_output,
            SUM(total_cost_cents) / 100.0 as total_cost,
            SUM(cached_savings_cents) / 100.0 as total_savings,
            COUNT(DISTINCT session_id) as sessions,
            COUNT(DISTINCT DATE(timestamp)) as days
        FROM api_calls
    """

    use cmd = new SqliteCommand(sql, conn)
    use reader = cmd.ExecuteReader()

    if reader.Read() then
        {|
            TotalCalls = reader.GetInt32(0)
            TotalInputTokens = if reader.IsDBNull(1) then 0 else reader.GetInt32(1)
            TotalOutputTokens = if reader.IsDBNull(2) then 0 else reader.GetInt32(2)
            TotalCost = if reader.IsDBNull(3) then 0.0 else reader.GetDouble(3)
            TotalSavings = if reader.IsDBNull(4) then 0.0 else reader.GetDouble(4)
            UniqueSessions = reader.GetInt32(5)
            ActiveDays = reader.GetInt32(6)
        |}
    else
        {|
            TotalCalls = 0
            TotalInputTokens = 0
            TotalOutputTokens = 0
            TotalCost = 0.0
            TotalSavings = 0.0
            UniqueSessions = 0
            ActiveDays = 0
        |}

// =============================================================================
// DASHBOARD DISPLAY
// =============================================================================

let showDashboard () =
    let stats = getTotalStats()
    let providers = getProviderBreakdown 24
    let recent = getRecentCalls 10

    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════════════════════════╗"
    printfn "║  API USAGE TRACKER - Real-Time Metrics Dashboard                                 ║"
    printfn "║  %s                                              ║" (DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss UTC"))
    printfn "╠══════════════════════════════════════════════════════════════════════════════════╣"
    printfn "║  LIFETIME TOTALS                                                                 ║"
    printfn "╠══════════════════════════════════════════════════════════════════════════════════╣"
    printfn "║  Total API Calls:     %-10d │ Unique Sessions: %-10d               ║" stats.TotalCalls stats.UniqueSessions
    printfn "║  Input Tokens:        %-10d │ Output Tokens:   %-10d               ║" stats.TotalInputTokens stats.TotalOutputTokens
    printfn "║  Total Cost:          $%-9.4f │ Cache Savings:   $%-9.4f               ║" stats.TotalCost stats.TotalSavings
    printfn "║  Active Days:         %-10d │ Avg Cost/Call:   $%-9.4f               ║" stats.ActiveDays (if stats.TotalCalls > 0 then stats.TotalCost / float stats.TotalCalls else 0.0)
    printfn "╠══════════════════════════════════════════════════════════════════════════════════╣"
    printfn "║  PROVIDER BREAKDOWN (Last 24 Hours)                                              ║"
    printfn "╠══════════════════════════════════════════════════════════════════════════════════╣"

    if List.isEmpty providers then
        printfn "║  No API calls in the last 24 hours                                               ║"
    else
        printfn "║  %-12s │ %8s │ %10s │ %10s │ %10s                ║" "PROVIDER" "CALLS" "TOKENS" "COST" "AVG LAT"
        for p in providers do
            printfn "║  %-12s │ %8d │ %10d │ $%9.4f │ %8.0fms                ║" p.Provider p.Calls p.Tokens p.Cost p.AvgLatency

    printfn "╠══════════════════════════════════════════════════════════════════════════════════╣"
    printfn "║  RECENT CALLS                                                                    ║"
    printfn "╠══════════════════════════════════════════════════════════════════════════════════╣"

    if List.isEmpty recent then
        printfn "║  No API calls recorded yet                                                       ║"
    else
        printfn "║  %-8s │ %-25s │ %-12s │ %6s │ %8s │ %-4s       ║" "TIME" "MODEL" "CHAMBER" "TOKENS" "COST" "OK"
        for r in recent do
            let time = DateTime.Parse(r.Timestamp).ToString("HH:mm:ss")
            let model = if r.ModelId.Length > 25 then r.ModelId.Substring(0, 22) + "..." else r.ModelId
            let status = if r.Success then "OK" else "ERR"
            printfn "║  %-8s │ %-25s │ %-12s │ %6d │ $%7.4f │ %-4s       ║" time model r.Chamber (r.InputTokens + r.OutputTokens) r.Cost status

    printfn "╚══════════════════════════════════════════════════════════════════════════════════╝"

let showHelp () =
    printfn """
╔══════════════════════════════════════════════════════════════════════════╗
║  API USAGE TRACKER                                                       ║
║  Comprehensive External Model Activity Monitoring                        ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  COMMANDS:                                                               ║
║    init          Initialize database and load pricing                    ║
║    dashboard     Show real-time metrics dashboard                        ║
║    session <id>  Show session summary                                    ║
║    providers     Show provider breakdown                                 ║
║    recent [n]    Show n most recent calls (default: 10)                  ║
║    export        Export metrics to JSON                                  ║
║    help          Show this help                                          ║
║                                                                          ║
║  INTEGRATION:                                                            ║
║    Use recordApiCall() after each OpenRouter API call                    ║
║    Use createTrackingRecord() to build the record from response          ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"""

// =============================================================================
// MAIN
// =============================================================================

let main (args: string[]) =
    if args.Length = 0 then
        showHelp()
    else
        match args.[0].ToLower() with
        | "init" ->
            initializeDatabase()
            loadModelPricing()
            printfn "[METRICS] Initialization complete"
        | "dashboard" | "status" ->
            showDashboard()
        | "session" when args.Length > 1 ->
            match getSessionSummary args.[1] with
            | Some s ->
                printfn "Session: %s" args.[1]
                printfn "  Calls: %d | Tokens: %d in / %d out" s.TotalCalls s.TotalInputTokens s.TotalOutputTokens
                printfn "  Cost: $%.4f | Savings: $%.4f" s.TotalCost s.TotalSavings
                printfn "  Avg Latency: %.0fms | Success Rate: %.1f%%" s.AvgLatencyMs s.SuccessRate
            | None ->
                printfn "Session not found: %s" args.[1]
        | "providers" ->
            let providers = getProviderBreakdown 24
            for p in providers do
                printfn "%s: %d calls, %d tokens, $%.4f, %.0fms avg" p.Provider p.Calls p.Tokens p.Cost p.AvgLatency
        | "recent" ->
            let limit = if args.Length > 1 then Int32.Parse args.[1] else 10
            let recent = getRecentCalls limit
            for r in recent do
                printfn "%s | %s | %s | %d tok | $%.4f" r.Timestamp r.ModelId r.Chamber (r.InputTokens + r.OutputTokens) r.Cost
        | "export" ->
            let stats = getTotalStats()
            let json = JsonSerializer.Serialize(stats, JsonSerializerOptions(WriteIndented = true))
            let exportPath = Path.Combine(dataPath, $"export_{DateTime.UtcNow:yyyyMMdd_HHmmss}.json")
            File.WriteAllText(exportPath, json)
            printfn "[METRICS] Exported to %s" exportPath
        | "help" | "--help" | "-h" ->
            showHelp()
        | _ ->
            printfn "Unknown command: %s" args.[0]
            showHelp()

// Entry point
main (fsi.CommandLineArgs |> Array.skip 1)
