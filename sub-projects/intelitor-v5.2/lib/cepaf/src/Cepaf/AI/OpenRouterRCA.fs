// =============================================================================
// OpenRouterRCA.fs - AI-Assisted 7-Level RCA via OpenRouter API
// =============================================================================
// STAMP: SC-BOOT-012, SC-AI-001, SC-AI-004
// AOR: AOR-OPENROUTER-001 to AOR-OPENROUTER-005, AOR-RCA-001
//
// ## OpenRouter Integration
// - Uses free models by default (AOR-OPENROUTER-001)
// - Implements exponential backoff on 429 (AOR-OPENROUTER-002)
// - Caches successful generations (AOR-OPENROUTER-003)
// - Logs all API calls for audit (AOR-OPENROUTER-004)
// - Falls back to mock for offline development (AOR-OPENROUTER-005)
//
// ## Model Selection Strategy
// | Complexity | Model | Use Case |
// |------------|-------|----------|
// | Simple (1-3) | claude-3-haiku | Quick pattern matching |
// | Medium (4-6) | claude-3-sonnet | Detailed analysis |
// | Complex (7+) | claude-3-opus | Deep architectural RCA |
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-17 |
// | Author | Claude Opus 4.5 |
// =============================================================================

namespace Cepaf.AI

open System
open System.Net.Http
open System.Text
open System.Text.Json
open System.Threading.Tasks
open Cepaf.Mesh

/// OpenRouter API configuration
type OpenRouterConfig = {
    /// API endpoint
    Endpoint: string
    /// API key (from environment)
    ApiKey: string option
    /// Default model
    DefaultModel: string
    /// Request timeout in milliseconds
    TimeoutMs: int
    /// Max retries on failure
    MaxRetries: int
    /// Enable offline mock mode
    MockMode: bool
}

/// OpenRouter API request
type OpenRouterRequest = {
    Model: string
    Messages: OpenRouterMessage list
    MaxTokens: int
    Temperature: float
}

and OpenRouterMessage = {
    Role: string
    Content: string
}

/// OpenRouter API response
type OpenRouterResponse = {
    Id: string
    Model: string
    Choices: OpenRouterChoice list
    Usage: OpenRouterUsage option
}

and OpenRouterChoice = {
    Message: OpenRouterMessage
    FinishReason: string
}

and OpenRouterUsage = {
    PromptTokens: int
    CompletionTokens: int
    TotalTokens: int
}

/// RCA analysis request
type RCARequest = {
    /// Error log or description
    ErrorLog: string
    /// Additional context
    Context: Map<string, string>
    /// Complexity hint (1-10)
    ComplexityHint: int option
    /// Force specific model
    ForceModel: string option
}

/// Cached RCA result
type CachedRCAResult = {
    /// Cache key (hash of error log)
    Key: string
    /// RCA report
    Report: RCAReport
    /// Cache timestamp
    CachedAt: DateTime
    /// Model used
    Model: string
    /// Token usage
    TokensUsed: int
}

/// API call audit entry
type APIAuditEntry = {
    /// Timestamp
    Timestamp: DateTime
    /// Model used
    Model: string
    /// Request summary
    RequestSummary: string
    /// Response status
    Status: string
    /// Tokens used
    TokensUsed: int
    /// Latency in milliseconds
    LatencyMs: int64
    /// Error if any
    Error: string option
}

module OpenRouterRCA =

    /// Default configuration
    let defaultConfig : OpenRouterConfig = {
        Endpoint = "https://openrouter.ai/api/v1/chat/completions"
        ApiKey = Environment.GetEnvironmentVariable("OPENROUTER_API_KEY") |> Option.ofObj
        DefaultModel = "anthropic/claude-3-haiku:free"
        TimeoutMs = 30000
        MaxRetries = 3
        MockMode = false
    }

    /// Available free models
    let freeModels = [
        "anthropic/claude-3-haiku:free"
        "google/gemma-7b-it:free"
        "mistralai/mistral-7b-instruct:free"
        "meta-llama/llama-3-8b-instruct:free"
    ]

    /// Select model based on error complexity
    let selectModel (complexity: int) (forceModel: string option) : string =
        match forceModel with
        | Some m -> m
        | None ->
            match complexity with
            | x when x >= 7 -> "anthropic/claude-3-opus"
            | x when x >= 4 -> "anthropic/claude-3-sonnet"
            | _ -> "anthropic/claude-3-haiku:free"

    /// Calculate error complexity from log
    let calculateComplexity (errorLog: string) : int =
        let factors = [
            if errorLog.Contains("Architecture") || errorLog.Contains("specification") then 3 else 0
            if errorLog.Contains("systemic") || errorLog.Contains("cross-module") then 2 else 0
            if errorLog.Contains("design") || errorLog.Contains("pattern") then 2 else 0
            if errorLog.Length > 1000 then 1 else 0
            if errorLog.Contains("cascade") || errorLog.Contains("propagate") then 2 else 0
        ]
        min 10 (List.sum factors + 1)

    /// Build RCA prompt for AI
    let buildRCAPrompt (errorLog: string) (context: Map<string, string>) : string =
        let contextStr =
            context
            |> Map.toList
            |> List.map (fun (k, v) -> sprintf "- %s: %s" k v)
            |> String.concat "\n"

        sprintf """You are analyzing a startup failure in a SIL-6 biomorphic mesh system.

## Error Log
```
%s
```

## Context
%s

## Task
Perform a 7-Level Root Cause Analysis following the TPS 5-Why methodology:

| Level | Name | Question |
|-------|------|----------|
| L1 | Symptom | What failed? What is the observable error? |
| L2 | Local | Why here? What is the immediate context? |
| L3 | Logic | Why this code? What logic path led here? |
| L4 | Module | Why this module? What module design issue? |
| L5 | System | Why systemic? What cross-module integration issue? |
| L6 | Design | Why this design? What design pattern issue? |
| L7 | Architecture | Why architecture? What specification gap? |

## Output Format
Provide your analysis as JSON:
```json
{
  "findings": [
    {"level": "L1", "finding": "..."},
    {"level": "L2", "finding": "..."},
    {"level": "L3", "finding": "..."},
    {"level": "L4", "finding": "..."},
    {"level": "L5", "finding": "..."},
    {"level": "L6", "finding": "..."},
    {"level": "L7", "finding": "..."}
  ],
  "rootCauseLevel": "L1-L7",
  "rootCauseSummary": "...",
  "recommendedFix": "...",
  "preventionStrategy": "..."
}
```

Be specific and actionable. Reference STAMP constraints (SC-BOOT-*) where applicable."""
            errorLog
            (if String.IsNullOrEmpty(contextStr) then "None provided" else contextStr)

    /// Parse AI response to RCA findings
    let parseRCAResponse (response: string) (issueId: string) : RCAReport option =
        try
            // Extract JSON from response (may be wrapped in markdown code blocks)
            let jsonStart = response.IndexOf("{")
            let jsonEnd = response.LastIndexOf("}") + 1
            if jsonStart >= 0 && jsonEnd > jsonStart then
                let jsonStr = response.Substring(jsonStart, jsonEnd - jsonStart)
                let doc = JsonDocument.Parse(jsonStr)
                let root = doc.RootElement

                let findings =
                    root.GetProperty("findings").EnumerateArray()
                    |> Seq.map (fun f ->
                        let levelStr = f.GetProperty("level").GetString()
                        let level =
                            match levelStr with
                            | "L1" -> L1_Symptom
                            | "L2" -> L2_Local
                            | "L3" -> L3_Logic
                            | "L4" -> L4_Module
                            | "L5" -> L5_System
                            | "L6" -> L6_Design
                            | _ -> L7_Architecture
                        SevenLevelRCA.createFinding level (f.GetProperty("finding").GetString()) [] None
                    )
                    |> Seq.toList

                let rootLevelStr = root.GetProperty("rootCauseLevel").GetString()
                let rootLevel =
                    match rootLevelStr with
                    | "L1" -> L1_Symptom
                    | "L2" -> L2_Local
                    | "L3" -> L3_Logic
                    | "L4" -> L4_Module
                    | "L5" -> L5_System
                    | "L6" -> L6_Design
                    | _ -> L7_Architecture

                Some {
                    IssueId = issueId
                    Issue = "AI-Analyzed Startup Failure"
                    Findings = findings
                    RootCauseLevel = rootLevel
                    RootCauseSummary = root.GetProperty("rootCauseSummary").GetString()
                    RecommendedFix = root.GetProperty("recommendedFix").GetString()
                    PreventionStrategy = root.GetProperty("preventionStrategy").GetString()
                    ReportTimestamp = DateTime.UtcNow
                    AnalysisDurationMs = 0L  // Will be set by caller
                }
            else
                None
        with _ ->
            None

    /// Mock RCA response for offline mode
    let mockRCAResponse (errorLog: string) : RCAReport =
        let issueId = sprintf "MOCK-RCA-%s" (DateTime.UtcNow.ToString("yyyyMMdd-HHmmss"))
        // Delegate to local pattern matching
        SevenLevelRCA.analyze "Mock Analysis" errorLog Map.empty

    /// Cache for RCA results
    let mutable private rcaCache : Map<string, CachedRCAResult> = Map.empty

    /// Audit log for API calls
    let mutable private auditLog : APIAuditEntry list = []

    /// Get cache key from error log
    let getCacheKey (errorLog: string) : string =
        use sha = System.Security.Cryptography.SHA256.Create()
        let bytes = Encoding.UTF8.GetBytes(errorLog)
        let hash = sha.ComputeHash(bytes)
        BitConverter.ToString(hash).Replace("-", "").Substring(0, 16)

    /// Check cache for existing result
    let checkCache (errorLog: string) : CachedRCAResult option =
        let key = getCacheKey errorLog
        rcaCache.TryFind key
        |> Option.filter (fun c -> (DateTime.UtcNow - c.CachedAt).TotalHours < 24.0)

    /// Add result to cache
    let addToCache (errorLog: string) (report: RCAReport) (model: string) (tokens: int) : unit =
        let key = getCacheKey errorLog
        let cached = {
            Key = key
            Report = report
            CachedAt = DateTime.UtcNow
            Model = model
            TokensUsed = tokens
        }
        rcaCache <- rcaCache.Add(key, cached)

    /// Add audit entry
    let addAuditEntry (entry: APIAuditEntry) : unit =
        auditLog <- entry :: auditLog
        // Keep only last 1000 entries
        if auditLog.Length > 1000 then
            auditLog <- auditLog |> List.take 1000

    /// Get audit log
    let getAuditLog () : APIAuditEntry list = auditLog

    /// Clear audit log
    let clearAuditLog () : unit = auditLog <- []

    /// Analyze startup failure with OpenRouter AI
    let analyzeWithAI (config: OpenRouterConfig) (request: RCARequest) : Async<Result<RCAReport, string>> =
        async {
            let sw = System.Diagnostics.Stopwatch.StartNew()
            let issueId = sprintf "AI-RCA-%s" (DateTime.UtcNow.ToString("yyyyMMdd-HHmmss"))

            // Check cache first (AOR-OPENROUTER-003)
            match checkCache request.ErrorLog with
            | Some cached ->
                printfn "[OpenRouterRCA] Cache hit for key %s" cached.Key
                return Ok { cached.Report with AnalysisDurationMs = sw.ElapsedMilliseconds }
            | None ->

            // Check for offline/mock mode (AOR-OPENROUTER-005)
            if config.MockMode || config.ApiKey.IsNone then
                printfn "[OpenRouterRCA] Using mock mode (no API key or mock enabled)"
                let report = mockRCAResponse request.ErrorLog
                return Ok { report with AnalysisDurationMs = sw.ElapsedMilliseconds }

            else
                // Calculate complexity and select model
                let complexity = request.ComplexityHint |> Option.defaultWith (fun () -> calculateComplexity request.ErrorLog)
                let model = selectModel complexity request.ForceModel

                // Build prompt
                let prompt = buildRCAPrompt request.ErrorLog request.Context

                // Build request body
                let requestBody = {
                    Model = model
                    Messages = [{ Role = "user"; Content = prompt }]
                    MaxTokens = 2000
                    Temperature = 0.3
                }

                let jsonOptions = JsonSerializerOptions(PropertyNamingPolicy = JsonNamingPolicy.CamelCase)
                let jsonBody = JsonSerializer.Serialize(requestBody, jsonOptions)

                // Make API call with retries (AOR-OPENROUTER-002)
                let mutable lastError = ""
                let mutable result : RCAReport option = None
                let mutable tokensUsed = 0

                for retry in 1..config.MaxRetries do
                    if result.IsNone then
                        try
                            use client = new HttpClient()
                            client.Timeout <- TimeSpan.FromMilliseconds(float config.TimeoutMs)
                            client.DefaultRequestHeaders.Add("Authorization", sprintf "Bearer %s" config.ApiKey.Value)
                            client.DefaultRequestHeaders.Add("HTTP-Referer", "https://indrajaal.io")
                            client.DefaultRequestHeaders.Add("X-Title", "Indrajaal SIL-6 RCA")

                            use content = new StringContent(jsonBody, Encoding.UTF8, "application/json")
                            let! response = client.PostAsync(config.Endpoint, content) |> Async.AwaitTask

                            if response.IsSuccessStatusCode then
                                let! responseBody = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                                let responseDoc = JsonDocument.Parse(responseBody)

                                // Extract token usage
                                if responseDoc.RootElement.TryGetProperty("usage", ref Unchecked.defaultof<JsonElement>) then
                                    let usage = responseDoc.RootElement.GetProperty("usage")
                                    tokensUsed <- usage.GetProperty("total_tokens").GetInt32()

                                // Extract completion
                                let choices = responseDoc.RootElement.GetProperty("choices")
                                if choices.GetArrayLength() > 0 then
                                    let messageContent = choices.[0].GetProperty("message").GetProperty("content").GetString()
                                    match parseRCAResponse messageContent issueId with
                                    | Some report ->
                                        result <- Some { report with AnalysisDurationMs = sw.ElapsedMilliseconds }
                                        // Cache result (AOR-OPENROUTER-003)
                                        addToCache request.ErrorLog report model tokensUsed
                                    | None ->
                                        lastError <- "Failed to parse AI response"
                            elif int response.StatusCode = 429 then
                                // Rate limited - exponential backoff (AOR-OPENROUTER-002)
                                let backoffMs = 1000 * (pown 2 retry)
                                printfn "[OpenRouterRCA] Rate limited, backing off %dms" backoffMs
                                do! Async.Sleep backoffMs
                                lastError <- "Rate limited"
                            else
                                lastError <- sprintf "API error: %d %s" (int response.StatusCode) response.ReasonPhrase

                        with ex ->
                            lastError <- sprintf "Exception: %s" ex.Message
                            // Exponential backoff on error
                            let backoffMs = 1000 * (pown 2 retry)
                            do! Async.Sleep backoffMs

                sw.Stop()

                // Log API call (AOR-OPENROUTER-004)
                let auditEntry = {
                    Timestamp = DateTime.UtcNow
                    Model = model
                    RequestSummary = request.ErrorLog.Substring(0, min 100 request.ErrorLog.Length)
                    Status = if result.IsSome then "Success" else "Failed"
                    TokensUsed = tokensUsed
                    LatencyMs = sw.ElapsedMilliseconds
                    Error = if result.IsSome then None else Some lastError
                }
                addAuditEntry auditEntry

                match result with
                | Some r -> return Ok r
                | None ->
                    // Fallback to local analysis
                    printfn "[OpenRouterRCA] API failed, falling back to local analysis"
                    let localReport = SevenLevelRCA.analyze "Startup Failure (Local Fallback)" request.ErrorLog Map.empty
                    return Ok { localReport with AnalysisDurationMs = sw.ElapsedMilliseconds }
        }

    /// Quick analyze with default config
    let quickAnalyzeWithAI (errorLog: string) : Async<Result<RCAReport, string>> =
        let request = {
            ErrorLog = errorLog
            Context = Map.empty
            ComplexityHint = None
            ForceModel = None
        }
        analyzeWithAI defaultConfig request

    /// Print API audit summary
    let printAuditSummary () : unit =
        let reset = "\u001b[0m"
        let bold = "\u001b[1m"
        let cyan = "\u001b[36m"

        let entries = getAuditLog ()
        let successCount = entries |> List.filter (fun e -> e.Status = "Success") |> List.length
        let failedCount = entries |> List.filter (fun e -> e.Status = "Failed") |> List.length
        let totalTokens = entries |> List.sumBy (fun e -> e.TokensUsed)
        let avgLatency =
            if entries.IsEmpty then 0.0
            else entries |> List.averageBy (fun e -> float e.LatencyMs)

        printfn ""
        printfn "%s%sOpenRouter API Audit Summary%s" cyan bold reset
        printfn "  Total Calls: %d (Success: %d, Failed: %d)" entries.Length successCount failedCount
        printfn "  Total Tokens: %d" totalTokens
        printfn "  Avg Latency: %.1fms" avgLatency
        printfn "  Cache Size: %d entries" rcaCache.Count
        printfn ""

