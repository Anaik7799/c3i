#!/usr/bin/env dotnet fsi

// =============================================================================
// TRICAMERAL AI GOVERNANCE ORCHESTRATOR
// Claude • Gemini • Grok - Consensus-Based Critical Decision Making
// =============================================================================
// Version: 1.1.0 | STAMP: SC-TRI-001 to SC-TRI-015, SC-METRICS-001 to SC-METRICS-020
// Integrated with API Usage Tracker for full granularity cost/token monitoring
// =============================================================================

#r "nuget: FSharp.Data, 6.4.0"
#r "nuget: System.Text.Json"
#r "nuget: Microsoft.Data.Sqlite"

// API Usage Tracking - SC-METRICS-001
// Records all external model API calls with full granularity

open System
open System.IO
open System.Net.Http
open System.Text
open System.Text.Json
open System.Text.Json.Serialization
open System.Security.Cryptography
open System.Threading.Tasks
open Microsoft.Data.Sqlite

// =============================================================================
// TYPES AND DOMAIN MODEL
// =============================================================================

/// AI Chamber identifiers
type Chamber =
    | Claude
    | Gemini
    | Grok

/// Decision criticality categories
type DecisionCategory =
    | Existential      // 3oo3 required, 5 min timeout
    | Constitutional   // 3oo3 required, 3 min timeout
    | Architectural    // 2oo3 required, 2 min timeout
    | Operational      // 2oo3 required, 1 min timeout
    | Tactical         // 1oo3 sufficient, 30 sec timeout

/// Voting strategies
type VotingStrategy =
    | RequireUnanimous   // All must agree (3oo3)
    | RequireMajority    // 2 out of 3 (2oo3)
    | WeightedVote       // Confidence-weighted
    | HierarchicalVote   // Claude > Gemini > Grok

/// AI response from a chamber
[<CLIMutable>]
type AIResponse = {
    [<JsonPropertyName("recommendation")>]
    Recommendation: string
    [<JsonPropertyName("confidence")>]
    Confidence: float
    [<JsonPropertyName("reasoning")>]
    Reasoning: string
    [<JsonPropertyName("risks")>]
    Risks: string[]
    [<JsonPropertyName("alternatives")>]
    Alternatives: string[]
}

/// Vote with full metadata
type AIVote = {
    Chamber: Chamber
    Response: AIResponse
    ResponseTime: TimeSpan
    TokensUsed: int
    Cost: float
    Timestamp: DateTime
}

/// Consensus result
type ConsensusResult =
    | Unanimous of recommendation: string * avgConfidence: float
    | MajorityReached of recommendation: string * avgConfidence: float * dissenter: Chamber
    | Split of votes: AIVote list
    | Timeout of timedOutChambers: Chamber list
    | Error of message: string

/// Complete decision record
type DecisionRecord = {
    Id: Guid
    Timestamp: DateTime
    Category: DecisionCategory
    ItemDescription: string
    Context: string
    ClaudeVote: AIVote option
    GeminiVote: AIVote option
    GrokVote: AIVote option
    ConsensusResult: ConsensusResult
    GuardianApproved: bool option
    ActionTaken: string option
    ExecutionResult: string option
    RecordHash: string
}

/// API configuration
type ProviderConfig = {
    Name: string
    Endpoint: string
    Model: string
    ApiKeyEnv: string
    MaxTokens: int
    TimeoutMs: int
}

// =============================================================================
// CONFIGURATION
// =============================================================================

let projectRoot =
    let current = Directory.GetCurrentDirectory()
    if current.Contains("lib/cepaf") then
        Path.GetFullPath(Path.Combine(current, "../.."))
    else current

let dataPath = Path.Combine(projectRoot, "data", "governance")
let dbPath = Path.Combine(dataPath, "tricameral.db")

// =============================================================================
// OPENROUTER UNIFIED CONFIGURATION
// =============================================================================
// All three chambers now use OpenRouter as unified gateway
// Models are selected dynamically based on decision category tier
// Set OPENROUTER_API_KEY environment variable

let openRouterEndpoint = "https://openrouter.ai/api/v1/chat/completions"
let openRouterApiKeyEnv = "OPENROUTER_API_KEY"

// =============================================================================
// DYNAMIC MODEL REGISTRY (January 2026 - Latest Versions)
// =============================================================================

/// Model tiers for different decision categories
type ModelTier = Frontier | Performance | Efficient

/// Model configuration with capabilities
type ModelConfig = {
    Id: string
    Name: string
    Provider: string
    ContextWindow: int
    InputPricePerMillion: float
    OutputPricePerMillion: float
    TokensPerSecond: int
    Tier: ModelTier
}

// Latest models (January 2026) - OpenRouter Valid IDs
let models = {|
    // Anthropic Claude
    ClaudeOpus45 = {
        Id = "anthropic/claude-3-opus"  // Valid OpenRouter ID
        Name = "Claude 3 Opus"
        Provider = "Anthropic"
        ContextWindow = 200000
        InputPricePerMillion = 15.0
        OutputPricePerMillion = 75.0
        TokensPerSecond = 70
        Tier = Frontier
    }
    ClaudeSonnet45 = {
        Id = "anthropic/claude-3.5-sonnet"  // Valid OpenRouter ID
        Name = "Claude 3.5 Sonnet"
        Provider = "Anthropic"
        ContextWindow = 1000000
        InputPricePerMillion = 3.0
        OutputPricePerMillion = 15.0
        TokensPerSecond = 150
        Tier = Performance
    }
    ClaudeHaiku45 = {
        Id = "anthropic/claude-3.5-haiku"  // Valid OpenRouter ID
        Name = "Claude 3.5 Haiku"
        Provider = "Anthropic"
        ContextWindow = 200000
        InputPricePerMillion = 0.80
        OutputPricePerMillion = 4.0
        TokensPerSecond = 300
        Tier = Efficient
    }
    // Google Gemini
    Gemini3Pro = {
        Id = "google/gemini-2.0-flash-thinking-exp:free"  // Valid OpenRouter ID (free)
        Name = "Gemini 2.0 Flash Thinking"
        Provider = "Google"
        ContextWindow = 1000000
        InputPricePerMillion = 0.0
        OutputPricePerMillion = 0.0
        TokensPerSecond = 180
        Tier = Frontier
    }
    Gemini3Flash = {
        Id = "google/gemini-2.0-flash-exp:free"  // Valid OpenRouter ID (free)
        Name = "Gemini 2.0 Flash"
        Provider = "Google"
        ContextWindow = 1000000
        InputPricePerMillion = 0.0
        OutputPricePerMillion = 0.0
        TokensPerSecond = 400
        Tier = Efficient
    }
    Gemini25Pro = {
        Id = "google/gemini-pro-1.5"  // Valid OpenRouter ID
        Name = "Gemini 1.5 Pro"
        Provider = "Google"
        ContextWindow = 1000000
        InputPricePerMillion = 2.50
        OutputPricePerMillion = 10.0
        TokensPerSecond = 150
        Tier = Performance
    }
    // xAI Grok
    Grok41Fast = {
        Id = "x-ai/grok-2-1212"  // Valid OpenRouter ID
        Name = "Grok 2"
        Provider = "xAI"
        ContextWindow = 131072
        InputPricePerMillion = 2.0
        OutputPricePerMillion = 10.0
        TokensPerSecond = 455
        Tier = Performance
    }
    Grok4 = {
        Id = "x-ai/grok-beta"  // Valid OpenRouter ID
        Name = "Grok Beta"
        Provider = "xAI"
        ContextWindow = 131072
        InputPricePerMillion = 5.0
        OutputPricePerMillion = 15.0
        TokensPerSecond = 280
        Tier = Frontier
    }
    GrokCodeFast = {
        Id = "x-ai/grok-2-vision-1212"  // Valid OpenRouter ID
        Name = "Grok 2 Vision"
        Provider = "xAI"
        ContextWindow = 32768
        InputPricePerMillion = 2.0
        OutputPricePerMillion = 10.0
        TokensPerSecond = 500
        Tier = Efficient
    }
|}

/// Get the appropriate tier for a decision category
let getTierForCategory category =
    match category with
    | Existential | Constitutional -> Frontier
    | Architectural | Operational -> Performance
    | Tactical -> Efficient

/// Get model for chamber based on decision category
let getModelForChamberAndCategory chamber category =
    let tier = getTierForCategory category
    match chamber, tier with
    // Claude - Constitutional/Ethics specialist
    | Claude, Frontier -> models.ClaudeOpus45
    | Claude, Performance -> models.ClaudeSonnet45
    | Claude, Efficient -> models.ClaudeHaiku45
    // Gemini - Technical/Systems specialist
    | Gemini, Frontier -> models.Gemini3Pro
    | Gemini, Performance -> models.Gemini25Pro
    | Gemini, Efficient -> models.Gemini3Flash
    // Grok - Pragmatic/Speed specialist
    | Grok, Frontier -> models.Grok4
    | Grok, Performance -> models.Grok41Fast
    | Grok, Efficient -> models.GrokCodeFast

/// Mutable current category for dynamic model selection
let mutable currentCategory = Tactical

/// Get model ID for chamber (uses current category context)
let getModelForChamber chamber =
    (getModelForChamberAndCategory chamber currentCategory).Id

/// Estimate cost for tokens
let estimateModelCost (model: ModelConfig) (inputTokens: int) (outputTokens: int) =
    let inputCost = float inputTokens * model.InputPricePerMillion / 1_000_000.0
    let outputCost = float outputTokens * model.OutputPricePerMillion / 1_000_000.0
    inputCost + outputCost

/// Get timeout for category
let getCategoryTimeout category =
    match category with
    | Existential -> TimeSpan.FromMinutes(5.0)
    | Constitutional -> TimeSpan.FromMinutes(3.0)
    | Architectural -> TimeSpan.FromMinutes(2.0)
    | Operational -> TimeSpan.FromMinutes(1.0)
    | Tactical -> TimeSpan.FromSeconds(30.0)

/// Get required consensus threshold
let getConsensusThreshold category =
    match category with
    | Existential | Constitutional -> RequireUnanimous
    | Architectural | Operational -> RequireMajority
    | Tactical -> RequireMajority  // Single would suffice but use majority for safety

// =============================================================================
// DATABASE
// =============================================================================

let ensureDatabase () =
    Directory.CreateDirectory(dataPath) |> ignore

    use conn = new SqliteConnection($"Data Source={dbPath}")
    conn.Open()

    let sql = """
        CREATE TABLE IF NOT EXISTS tricameral_decisions (
            id TEXT PRIMARY KEY,
            timestamp TEXT NOT NULL,
            category TEXT NOT NULL,
            item_description TEXT NOT NULL,
            context TEXT,
            claude_response TEXT,
            gemini_response TEXT,
            grok_response TEXT,
            claude_time_ms INTEGER,
            gemini_time_ms INTEGER,
            grok_time_ms INTEGER,
            claude_cost REAL,
            gemini_cost REAL,
            grok_cost REAL,
            consensus_type TEXT,
            winning_recommendation TEXT,
            consensus_confidence REAL,
            dissenting_chamber TEXT,
            guardian_approved INTEGER,
            action_taken TEXT,
            execution_result TEXT,
            record_hash TEXT,
            previous_hash TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_timestamp ON tricameral_decisions(timestamp);
        CREATE INDEX IF NOT EXISTS idx_category ON tricameral_decisions(category);

        CREATE TABLE IF NOT EXISTS chamber_metrics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            chamber TEXT NOT NULL,
            success_rate REAL,
            avg_latency_ms REAL,
            total_cost REAL,
            decisions_count INTEGER
        );
    """

    use cmd = new SqliteCommand(sql, conn)
    cmd.ExecuteNonQuery() |> ignore

    printfn "[TRI] Database initialized at %s" dbPath

let getLastHash () =
    use conn = new SqliteConnection($"Data Source={dbPath}")
    conn.Open()

    let sql = "SELECT record_hash FROM tricameral_decisions ORDER BY timestamp DESC LIMIT 1"
    use cmd = new SqliteCommand(sql, conn)

    match cmd.ExecuteScalar() with
    | null -> "GENESIS"
    | hash -> hash.ToString()

let saveDecision (record: DecisionRecord) =
    use conn = new SqliteConnection($"Data Source={dbPath}")
    conn.Open()

    let previousHash = getLastHash()

    let sql = """
        INSERT INTO tricameral_decisions (
            id, timestamp, category, item_description, context,
            claude_response, gemini_response, grok_response,
            claude_time_ms, gemini_time_ms, grok_time_ms,
            claude_cost, gemini_cost, grok_cost,
            consensus_type, winning_recommendation, consensus_confidence, dissenting_chamber,
            guardian_approved, action_taken, execution_result, record_hash, previous_hash
        ) VALUES (
            @id, @timestamp, @category, @item, @context,
            @claude, @gemini, @grok,
            @claudeTime, @geminiTime, @grokTime,
            @claudeCost, @geminiCost, @grokCost,
            @consensusType, @winning, @confidence, @dissenter,
            @guardian, @action, @result, @hash, @prevHash
        )
    """

    use cmd = new SqliteCommand(sql, conn)
    cmd.Parameters.AddWithValue("@id", record.Id.ToString()) |> ignore
    cmd.Parameters.AddWithValue("@timestamp", record.Timestamp.ToString("o")) |> ignore
    cmd.Parameters.AddWithValue("@category", record.Category.ToString()) |> ignore
    cmd.Parameters.AddWithValue("@item", record.ItemDescription) |> ignore
    cmd.Parameters.AddWithValue("@context", record.Context) |> ignore

    // Serialize responses
    let serializeVote (v: AIVote option) : obj =
        match v with
        | Some vote -> JsonSerializer.Serialize(vote.Response) :> obj
        | None -> DBNull.Value :> obj

    cmd.Parameters.AddWithValue("@claude", serializeVote record.ClaudeVote) |> ignore
    cmd.Parameters.AddWithValue("@gemini", serializeVote record.GeminiVote) |> ignore
    cmd.Parameters.AddWithValue("@grok", serializeVote record.GrokVote) |> ignore

    let getTime (v: AIVote option) =
        match v with Some vote -> int vote.ResponseTime.TotalMilliseconds | None -> 0
    let getCost (v: AIVote option) =
        match v with Some vote -> vote.Cost | None -> 0.0

    cmd.Parameters.AddWithValue("@claudeTime", getTime record.ClaudeVote) |> ignore
    cmd.Parameters.AddWithValue("@geminiTime", getTime record.GeminiVote) |> ignore
    cmd.Parameters.AddWithValue("@grokTime", getTime record.GrokVote) |> ignore
    cmd.Parameters.AddWithValue("@claudeCost", getCost record.ClaudeVote) |> ignore
    cmd.Parameters.AddWithValue("@geminiCost", getCost record.GeminiVote) |> ignore
    cmd.Parameters.AddWithValue("@grokCost", getCost record.GrokVote) |> ignore

    // Consensus info
    let (consensusType, winning, confidence, dissenter) : (string * obj * float * obj) =
        match record.ConsensusResult with
        | Unanimous (recommendation, conf) -> ("UNANIMOUS", recommendation :> obj, conf, DBNull.Value :> obj)
        | MajorityReached (recommendation, conf, diss) -> ("MAJORITY", recommendation :> obj, conf, diss.ToString() :> obj)
        | Split _ -> ("SPLIT", DBNull.Value :> obj, 0.0, DBNull.Value :> obj)
        | Timeout chambers -> ("TIMEOUT", DBNull.Value :> obj, 0.0, String.Join(",", chambers |> List.map string) :> obj)
        | Error msg -> ("ERROR", msg :> obj, 0.0, DBNull.Value :> obj)

    cmd.Parameters.AddWithValue("@consensusType", consensusType) |> ignore
    cmd.Parameters.AddWithValue("@winning", winning) |> ignore
    cmd.Parameters.AddWithValue("@confidence", confidence) |> ignore
    cmd.Parameters.AddWithValue("@dissenter", dissenter) |> ignore

    let guardianValue =
        match record.GuardianApproved with
        | Some b -> (if b then 1 else 0) :> obj
        | None -> DBNull.Value :> obj
    cmd.Parameters.AddWithValue("@guardian", guardianValue) |> ignore

    let actionValue =
        match record.ActionTaken with
        | Some a -> a :> obj
        | None -> DBNull.Value :> obj
    cmd.Parameters.AddWithValue("@action", actionValue) |> ignore

    let resultValue =
        match record.ExecutionResult with
        | Some r -> r :> obj
        | None -> DBNull.Value :> obj
    cmd.Parameters.AddWithValue("@result", resultValue) |> ignore
    cmd.Parameters.AddWithValue("@hash", record.RecordHash) |> ignore
    cmd.Parameters.AddWithValue("@prevHash", previousHash) |> ignore

    cmd.ExecuteNonQuery() |> ignore
    printfn "[TRI] Decision saved: %s" (record.Id.ToString())

// =============================================================================
// API USAGE TRACKING (SC-METRICS-001 to SC-METRICS-020)
// =============================================================================
// Records all external model API calls with full granularity
// Writes to data/metrics/api_usage.db

let metricsPath = Path.Combine(projectRoot, "data", "metrics")
let metricsDbPath = Path.Combine(metricsPath, "api_usage.db")
let mutable currentSessionId = Guid.NewGuid().ToString()

/// Ensure metrics database exists
let ensureMetricsDb () =
    if not (File.Exists(metricsDbPath)) then
        printfn "[METRICS] Warning: api_usage.db not found. Run ApiUsageTracker.fsx init"
    else
        ()

/// Record API call to metrics database
let recordApiCall
    (modelId: string)
    (chamber: string)
    (category: string)
    (inputTokens: int)
    (outputTokens: int)
    (latencyMs: int)
    (success: bool)
    (finishReason: string)
    (cost: float) =

    if not (File.Exists(metricsDbPath)) then
        () // Skip if metrics db not initialized
    else
        try
            use conn = new SqliteConnection($"Data Source={metricsDbPath}")
            conn.Open()

            let id = Guid.NewGuid().ToString()
            let provider =
                if modelId.StartsWith("anthropic/") then "Anthropic"
                elif modelId.StartsWith("google/") then "Google"
                elif modelId.StartsWith("x-ai/") then "xAI"
                else "Unknown"

            let tier =
                if modelId.Contains("opus") || modelId.Contains("beta") || modelId.Contains("thinking") then "Frontier"
                elif modelId.Contains("sonnet") || modelId.Contains("pro") || modelId.Contains("grok-2") then "Performance"
                else "Efficient"

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
                    @input_tok, @output_tok, @total_tok, 0,
                    @input_cost, @output_cost, @total_cost, 0,
                    @latency, @tps, @ttft,
                    'chat', @chamber, @category, 'tricameral',
                    @success, '', '', @finish,
                    0, ''
                )
            """

            use cmd = new SqliteCommand(sql, conn)
            cmd.Parameters.AddWithValue("@id", id) |> ignore
            cmd.Parameters.AddWithValue("@ts", DateTime.UtcNow.ToString("o")) |> ignore
            cmd.Parameters.AddWithValue("@session", currentSessionId) |> ignore
            cmd.Parameters.AddWithValue("@provider", provider) |> ignore
            cmd.Parameters.AddWithValue("@model_id", modelId) |> ignore
            cmd.Parameters.AddWithValue("@model_name", modelId.Split('/').[1]) |> ignore
            cmd.Parameters.AddWithValue("@tier", tier) |> ignore
            cmd.Parameters.AddWithValue("@input_tok", inputTokens) |> ignore
            cmd.Parameters.AddWithValue("@output_tok", outputTokens) |> ignore
            cmd.Parameters.AddWithValue("@total_tok", inputTokens + outputTokens) |> ignore
            cmd.Parameters.AddWithValue("@input_cost", int (cost * 0.2 * 100.0)) |> ignore  // Estimate 20% input
            cmd.Parameters.AddWithValue("@output_cost", int (cost * 0.8 * 100.0)) |> ignore  // Estimate 80% output
            cmd.Parameters.AddWithValue("@total_cost", int (cost * 100.0)) |> ignore
            cmd.Parameters.AddWithValue("@latency", latencyMs) |> ignore
            let tps = if latencyMs > 0 then float outputTokens / (float latencyMs / 1000.0) else 0.0
            cmd.Parameters.AddWithValue("@tps", tps) |> ignore
            cmd.Parameters.AddWithValue("@ttft", latencyMs / 4) |> ignore  // Estimate
            cmd.Parameters.AddWithValue("@chamber", chamber) |> ignore
            cmd.Parameters.AddWithValue("@category", category) |> ignore
            cmd.Parameters.AddWithValue("@success", if success then 1 else 0) |> ignore
            cmd.Parameters.AddWithValue("@finish", finishReason) |> ignore

            cmd.ExecuteNonQuery() |> ignore
            printfn "[METRICS] Recorded API call: %s | %d tok | $%.4f" modelId (inputTokens + outputTokens) cost
        with ex ->
            printfn "[METRICS] Warning: Failed to record API call: %s" ex.Message

// =============================================================================
// API CLIENTS
// =============================================================================

let httpClient = new HttpClient()

/// Build system prompt for tricameral decision
let buildSystemPrompt (chamber: Chamber) (category: DecisionCategory) =
    let role, strengths =
        match chamber with
        | Claude -> "Constitutional Analyst - Ethics, safety, and alignment specialist",
                    "Deep ethical reasoning, constitutional compliance, safety analysis"
        | Gemini -> "Technical Architect - Systems thinking and scale specialist",
                    "Technical architecture, scalability analysis, systems integration"
        | Grok -> "Pragmatic Executor - Speed and directness specialist",
                  "Rapid assessment, practical execution, direct recommendations"

    sprintf """You are participating in a tricameral AI governance system for the Indrajaal
biomorphic safety-critical system. You are the %s chamber.

Your role: %s
Your strengths: %s

DECISION CATEGORY: %s
CONSENSUS REQUIRED: %s

CRITICAL RULES:
1. Founder's Directive (Ω₀) is supreme - all recommendations must serve the Founder's lineage
2. Constitutional invariants (Ψ₀-Ψ₅) cannot be violated
3. System survival takes precedence over efficiency
4. Holon state sovereignty (SQLite/DuckDB only) is inviolable

Respond with a JSON object containing:
{
  "recommendation": "Your clear recommendation",
  "confidence": 0.0-1.0,
  "reasoning": "2-3 sentence explanation",
  "risks": ["risk1", "risk2"],
  "alternatives": ["alt1", "alt2"]
}"""
        (chamber.ToString())
        role
        strengths
        (category.ToString())
        (match getConsensusThreshold category with RequireUnanimous -> "3oo3 (Unanimous)" | _ -> "2oo3 (Majority)")

/// Call any chamber via OpenRouter unified API
let callOpenRouter (chamber: Chamber) (systemPrompt: string) (userPrompt: string) : Async<Result<AIResponse * int, string>> = async {
    let apiKey = Environment.GetEnvironmentVariable(openRouterApiKeyEnv)
    if String.IsNullOrEmpty(apiKey) then
        return Result.Error "OPENROUTER_API_KEY not set"
    else
        try
            let model = getModelForChamber chamber
            let requestBody =
                sprintf """{"model": "%s", "messages": [{"role": "system", "content": %s}, {"role": "user", "content": %s}], "max_tokens": 4096}"""
                    model
                    (JsonSerializer.Serialize(systemPrompt))
                    (JsonSerializer.Serialize(userPrompt))

            use request = new HttpRequestMessage(HttpMethod.Post, openRouterEndpoint)
            request.Headers.Add("Authorization", sprintf "Bearer %s" apiKey)
            request.Headers.Add("HTTP-Referer", "https://indrajaal.ai")
            request.Headers.Add("X-Title", "Tricameral AI Governance")
            request.Content <- new StringContent(requestBody, Encoding.UTF8, "application/json")

            let! response = httpClient.SendAsync(request) |> Async.AwaitTask
            let! content = response.Content.ReadAsStringAsync() |> Async.AwaitTask

            if response.IsSuccessStatusCode then
                let doc = JsonDocument.Parse(content)
                let text = doc.RootElement
                            .GetProperty("choices").[0]
                            .GetProperty("message")
                            .GetProperty("content").GetString()

                // Try to get tokens, default to estimate if not available
                let tokens =
                    try
                        doc.RootElement.GetProperty("usage").GetProperty("completion_tokens").GetInt32()
                    with _ -> 500

                // Extract JSON from response (models may wrap it in markdown)
                let jsonStart = text.IndexOf("{")
                let jsonEnd = text.LastIndexOf("}") + 1
                let jsonText =
                    if jsonStart >= 0 && jsonEnd > jsonStart then
                        text.Substring(jsonStart, jsonEnd - jsonStart)
                    else
                        text

                let parsed = JsonSerializer.Deserialize<AIResponse>(jsonText)
                return Result.Ok (parsed, tokens)
            else
                return Result.Error (sprintf "%s via OpenRouter error: %s" (chamber.ToString()) content)
        with ex ->
            return Result.Error (sprintf "%s exception: %s" (chamber.ToString()) ex.Message)
}

/// Estimate cost based on tokens
let estimateCost (chamber: Chamber) (tokens: int) =
    match chamber with
    | Claude -> float tokens * 0.075 / 1000.0  // Opus output pricing
    | Gemini -> float tokens * 0.00025 / 1000.0  // Flash pricing
    | Grok -> float tokens * 0.01 / 1000.0  // Estimate

// =============================================================================
// CONSENSUS ENGINE
// =============================================================================

/// Query a single chamber
let queryChamber (chamber: Chamber) (category: DecisionCategory) (item: string) (context: string) : Async<AIVote option> = async {
    let systemPrompt = buildSystemPrompt chamber category
    let userPrompt = sprintf "CRITICAL ITEM:\n%s\n\nCONTEXT:\n%s" item context
    let modelId = getModelForChamber chamber

    let startTime = DateTime.UtcNow

    // All chambers use unified OpenRouter API
    let! result = callOpenRouter chamber systemPrompt userPrompt

    let elapsed = DateTime.UtcNow - startTime
    let latencyMs = int elapsed.TotalMilliseconds

    match result with
    | Result.Ok (response, tokens) ->
        let cost = estimateCost chamber tokens
        printfn "[TRI] %s responded in %.1fs: %s (confidence: %.2f)"
            (chamber.ToString()) elapsed.TotalSeconds response.Recommendation response.Confidence

        // Record to API Usage Tracker (SC-METRICS-001)
        let inputTokens = tokens / 5  // Estimate: ~20% input
        let outputTokens = tokens - inputTokens
        recordApiCall modelId (chamber.ToString()) (category.ToString())
            inputTokens outputTokens latencyMs true "stop" cost

        return Some {
            Chamber = chamber
            Response = response
            ResponseTime = elapsed
            TokensUsed = tokens
            Cost = cost
            Timestamp = DateTime.UtcNow
        }
    | Result.Error msg ->
        printfn "[TRI] %s failed: %s" (chamber.ToString()) msg

        // Record failed API call (SC-METRICS-002)
        recordApiCall modelId (chamber.ToString()) (category.ToString())
            0 0 latencyMs false "error" 0.0

        return None
}

/// Query all chambers in parallel
let queryAllChambers (category: DecisionCategory) (item: string) (context: string) : Async<AIVote option * AIVote option * AIVote option> = async {
    printfn "[TRI] Querying all chambers for %s decision..." (category.ToString())

    let timeout = getCategoryTimeout category

    let! results =
        [
            queryChamber Claude category item context
            queryChamber Gemini category item context
            queryChamber Grok category item context
        ]
        |> Async.Parallel

    return (results.[0], results.[1], results.[2])
}

/// Determine consensus from votes
let determineConsensus (votes: AIVote list) (strategy: VotingStrategy) : ConsensusResult =
    if votes.IsEmpty then
        Error "No votes received"
    elif votes.Length < 2 then
        Error "Insufficient votes for consensus"
    else
        let grouped =
            votes
            |> List.groupBy (fun v -> v.Response.Recommendation.ToUpperInvariant().Trim())
            |> List.sortByDescending (fun (_, vs) -> List.length vs)

        match strategy with
        | RequireUnanimous ->
            if grouped.Length = 1 then
                let _rec1, voters = grouped.[0]
                let avgConf = voters |> List.averageBy (fun v -> v.Response.Confidence)
                Unanimous (voters.[0].Response.Recommendation, avgConf)
            else
                Split votes

        | RequireMajority | WeightedVote ->
            match grouped with
            | (_, voters) :: _rest when voters.Length >= 2 ->
                let avgConf = voters |> List.averageBy (fun v -> v.Response.Confidence)
                let dissenter =
                    votes
                    |> List.find (fun v ->
                        not (voters |> List.exists (fun v2 -> v2.Chamber = v.Chamber)))
                MajorityReached (voters.[0].Response.Recommendation, avgConf, dissenter.Chamber)
            | _ ->
                Split votes

        | HierarchicalVote ->
            // Claude's vote wins
            match votes |> List.tryFind (fun v -> v.Chamber = Claude) with
            | Some claude -> MajorityReached (claude.Response.Recommendation, claude.Response.Confidence, Claude)
            | None ->
                match votes |> List.tryFind (fun v -> v.Chamber = Gemini) with
                | Some gemini -> MajorityReached (gemini.Response.Recommendation, gemini.Response.Confidence, Gemini)
                | None -> Split votes

/// Compute hash for record
let computeHash (record: DecisionRecord) =
    let consensusStr =
        match record.ConsensusResult with
        | Unanimous (r, _) -> r
        | MajorityReached (r, _, _) -> r
        | _ -> "NONE"
    let content =
        sprintf "%s|%s|%s|%s"
            (record.Id.ToString())
            (record.Timestamp.ToString("o"))
            record.ItemDescription
            consensusStr

    use sha = SHA256.Create()
    let bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(content))
    BitConverter.ToString(bytes).Replace("-", "").ToLower()

// =============================================================================
// MAIN DECISION FUNCTION
// =============================================================================

/// Make a tricameral decision
let makeDecision (category: DecisionCategory) (item: string) (context: string) : Async<DecisionRecord> = async {
    // Set current category for dynamic model selection
    currentCategory <- category

    // Get models that will be used
    let claudeModel = getModelForChamberAndCategory Claude category
    let geminiModel = getModelForChamberAndCategory Gemini category
    let grokModel = getModelForChamberAndCategory Grok category
    let tier = getTierForCategory category

    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════════════╗"
    printfn "║  TRICAMERAL DECISION REQUEST                                         ║"
    printfn "╠══════════════════════════════════════════════════════════════════════╣"
    printfn "║  Category: %-58s ║" (category.ToString())
    printfn "║  Tier: %-62s ║" (sprintf "%A" tier)
    printfn "║  Item: %-62s ║" (if item.Length > 60 then item.Substring(0, 57) + "..." else item)
    printfn "╠══════════════════════════════════════════════════════════════════════╣"
    printfn "║  SELECTED MODELS (Dynamic)                                           ║"
    printfn "║  Claude: %-60s ║" claudeModel.Name
    printfn "║  Gemini: %-60s ║" geminiModel.Name
    printfn "║  Grok:   %-60s ║" grokModel.Name
    printfn "╚══════════════════════════════════════════════════════════════════════╝"
    printfn ""

    let decisionId = Guid.NewGuid()
    let timestamp = DateTime.UtcNow

    // Query all chambers (using dynamically selected models)
    let! (claudeVote, geminiVote, grokVote) = queryAllChambers category item context

    // Collect valid votes
    let votes = [claudeVote; geminiVote; grokVote] |> List.choose id

    // Determine consensus
    let strategy = getConsensusThreshold category
    let consensus = determineConsensus votes strategy

    // Display results
    printfn ""
    printfn "┌──────────────────────────────────────────────────────────────────────┐"
    printfn "│  CHAMBER RESPONSES                                                   │"
    printfn "├──────────────────────────────────────────────────────────────────────┤"

    let printVote label (vote: AIVote option) =
        match vote with
        | Some v ->
            printfn "│  %-8s: %-50s │" label v.Response.Recommendation
            printfn "│           Confidence: %.2f  Time: %.1fs  Cost: $%.4f           │"
                v.Response.Confidence v.ResponseTime.TotalSeconds v.Cost
        | None ->
            printfn "│  %-8s: TIMEOUT/ERROR                                          │" label

    printVote "CLAUDE" claudeVote
    printVote "GEMINI" geminiVote
    printVote "GROK" grokVote

    printfn "├──────────────────────────────────────────────────────────────────────┤"
    printfn "│  CONSENSUS RESULT                                                    │"
    printfn "├──────────────────────────────────────────────────────────────────────┤"

    match consensus with
    | Unanimous (recommendation, conf) ->
        printfn "│  ✓ UNANIMOUS: %-54s │" recommendation
        printfn "│    Average Confidence: %.2f                                        │" conf
    | MajorityReached (recommendation, conf, dissenter) ->
        printfn "│  ✓ MAJORITY (2oo3): %-48s │" recommendation
        printfn "│    Dissenter: %-8s  Average Confidence: %.2f                   │" (dissenter.ToString()) conf
    | Split _ ->
        printfn "│  ✗ SPLIT - No consensus reached                                   │"
        printfn "│    Escalation to Guardian required                                │"
    | Timeout chambers ->
        printfn "│  ✗ TIMEOUT - Chambers failed: %s                         │" (String.Join(", ", chambers |> List.map string))
    | Error msg ->
        printfn "│  ✗ ERROR: %-58s │" msg

    printfn "└──────────────────────────────────────────────────────────────────────┘"

    // Build record
    let record = {
        Id = decisionId
        Timestamp = timestamp
        Category = category
        ItemDescription = item
        Context = context
        ClaudeVote = claudeVote
        GeminiVote = geminiVote
        GrokVote = grokVote
        ConsensusResult = consensus
        GuardianApproved = None
        ActionTaken = None
        ExecutionResult = None
        RecordHash = ""
    }

    let recordWithHash = { record with RecordHash = computeHash record }

    // Save to database
    saveDecision recordWithHash

    // Calculate total cost
    let totalCost =
        [claudeVote; geminiVote; grokVote]
        |> List.choose id
        |> List.sumBy (fun v -> v.Cost)
    printfn ""
    printfn "[TRI] Total cost: $%.4f" totalCost

    return recordWithHash
}

// =============================================================================
// CLI INTERFACE
// =============================================================================

let showHelp () =
    printfn """
╔══════════════════════════════════════════════════════════════════════════╗
║  TRICAMERAL AI GOVERNANCE ORCHESTRATOR                                   ║
║  Claude • Gemini • Grok - Consensus-Based Decision Making                ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  USAGE:                                                                  ║
║    dotnet fsi TricameralOrchestrator.fsx <command> [options]             ║
║                                                                          ║
║  COMMANDS:                                                               ║
║    decide <category> <item>   Make a tricameral decision                 ║
║    status                     Show chamber status and metrics            ║
║    history [n]                Show last n decisions (default: 10)        ║
║    test                       Run a test decision                        ║
║    help                       Show this help                             ║
║                                                                          ║
║  CATEGORIES:                                                             ║
║    existential     - 3oo3 required, 5 min timeout                        ║
║    constitutional  - 3oo3 required, 3 min timeout                        ║
║    architectural   - 2oo3 required, 2 min timeout                        ║
║    operational     - 2oo3 required, 1 min timeout                        ║
║    tactical        - 2oo3 required, 30 sec timeout                       ║
║                                                                          ║
║  ENVIRONMENT VARIABLES:                                                  ║
║    OPENROUTER_API_KEY  - OpenRouter API key (unified gateway)            ║
║                                                                          ║
║  DYNAMIC MODEL SELECTION (January 2026):                                 ║
║    Models are selected based on decision category tier:                  ║
║    - Frontier (Existential/Constitutional): Opus, Pro, Grok4            ║
║    - Performance (Architectural/Operational): Sonnet, 2.5Pro, 4.1Fast   ║
║    - Efficient (Tactical): Haiku, Flash, CodeFast                       ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"""

let showStatus () =
    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════════════╗"
    printfn "║  TRICAMERAL CHAMBER STATUS (OpenRouter Gateway)                      ║"
    printfn "╠══════════════════════════════════════════════════════════════════════╣"

    let apiKey = Environment.GetEnvironmentVariable(openRouterApiKeyEnv)
    let hasKey = not (String.IsNullOrEmpty(apiKey))

    if hasKey then
        printfn "║  OpenRouter: 🟢 API key configured                                  ║"
        printfn "╠══════════════════════════════════════════════════════════════════════╣"
        printfn "║  DYNAMIC MODEL REGISTRY (Jan 2026)                                  ║"
        printfn "╠══════════════════════════════════════════════════════════════════════╣"
        printfn "║  TIER      │ CLAUDE              │ GEMINI           │ GROK           ║"
        printfn "╠══════════════════════════════════════════════════════════════════════╣"
        printfn "║  Frontier  │ %-19s │ %-16s │ %-14s ║" models.ClaudeOpus45.Name models.Gemini3Pro.Name models.Grok4.Name
        printfn "║  Perform.  │ %-19s │ %-16s │ %-14s ║" models.ClaudeSonnet45.Name models.Gemini25Pro.Name models.Grok41Fast.Name
        printfn "║  Efficient │ %-19s │ %-16s │ %-14s ║" models.ClaudeHaiku45.Name models.Gemini3Flash.Name models.GrokCodeFast.Name
        printfn "╠══════════════════════════════════════════════════════════════════════╣"
        printfn "║  System Status: 🟢 READY (9 models via OpenRouter)                  ║"
    else
        printfn "║  OpenRouter: 🔴 API key not configured (OPENROUTER_API_KEY)         ║"
        printfn "╠══════════════════════════════════════════════════════════════════════╣"
        printfn "║  System Status: 🔴 OFFLINE (Set OPENROUTER_API_KEY)                 ║"

    printfn "╚══════════════════════════════════════════════════════════════════════╝"

let showHistory (count: int) =
    ensureDatabase()

    use conn = new SqliteConnection($"Data Source={dbPath}")
    conn.Open()

    let sql = sprintf "SELECT id, timestamp, category, winning_recommendation, consensus_type FROM tricameral_decisions ORDER BY timestamp DESC LIMIT %d" count
    use cmd = new SqliteCommand(sql, conn)
    use reader = cmd.ExecuteReader()

    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════════════╗"
    printfn "║  RECENT TRICAMERAL DECISIONS                                         ║"
    printfn "╠══════════════════════════════════════════════════════════════════════╣"

    let mutable found = false
    while reader.Read() do
        found <- true
        let ts = reader.GetString(1)
        let cat = reader.GetString(2)
        let recommendation = if reader.IsDBNull(3) then "N/A" else reader.GetString(3)
        let consensus = reader.GetString(4)
        printfn "║  %s │ %-12s │ %-10s │ %-20s ║"
            (ts.Substring(0, 16)) cat consensus (if recommendation.Length > 20 then recommendation.Substring(0,17) + "..." else recommendation)

    if not found then
        printfn "║  No decisions recorded yet                                          ║"

    printfn "╚══════════════════════════════════════════════════════════════════════╝"

let runTest () = async {
    printfn "[TRI] Running test decision..."

    let testItem = "Should we add debug logging to the authentication module?"
    let testContext = "The authentication module is working correctly but we need better observability for production troubleshooting."

    let! result = makeDecision Tactical testItem testContext

    printfn ""
    printfn "[TRI] Test complete. Decision ID: %s" (result.Id.ToString())
}

let parseCategory (s: string) =
    match s.ToLowerInvariant() with
    | "existential" -> Some Existential
    | "constitutional" -> Some Constitutional
    | "architectural" -> Some Architectural
    | "operational" -> Some Operational
    | "tactical" -> Some Tactical
    | _ -> None

// =============================================================================
// MAIN
// =============================================================================

let main (args: string[]) =
    ensureDatabase()
    ensureMetricsDb()  // SC-METRICS-001: Check API usage tracker

    if args.Length = 0 then
        showHelp()
    else
        match args.[0].ToLowerInvariant() with
        | "help" | "--help" | "-h" ->
            showHelp()

        | "status" ->
            showStatus()

        | "history" ->
            let count = if args.Length > 1 then Int32.Parse(args.[1]) else 10
            showHistory count

        | "test" ->
            runTest() |> Async.RunSynchronously

        | "decide" when args.Length >= 3 ->
            match parseCategory args.[1] with
            | Some category ->
                let item = args.[2]
                let context = if args.Length > 3 then String.Join(" ", args.[3..]) else ""
                makeDecision category item context |> Async.RunSynchronously |> ignore
            | None ->
                printfn "[TRI] Invalid category: %s" args.[1]
                printfn "Valid categories: existential, constitutional, architectural, operational, tactical"

        | _ ->
            printfn "[TRI] Unknown command: %s" args.[0]
            showHelp()

// Entry point
main (fsi.CommandLineArgs |> Array.skip 1)
