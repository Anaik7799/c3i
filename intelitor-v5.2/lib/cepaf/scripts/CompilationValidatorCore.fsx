namespace Indrajaal.Validation

#r "nuget: System.Text.Json"
#r "nuget: FSharp.Control.AsyncSeq"

open System
open System.IO
open System.Text.Json
open System.Text.Json.Serialization
open System.Text.RegularExpressions
open System.Net.Http
open System.Text
open System.Threading
open System.Collections.Concurrent

// 1. Domain Types
type Severity = Critical | High | Medium | Low

type ErrorType = 
    | CompilationError
    | UndefinedFunction
    | TypeMismatch
    | DependencyError
    | SyntaxError
    | UnusedVariable
    | Deprecation
    | Unknown of string

type LogIssue = {
    Type: ErrorType
    Severity: Severity
    Message: string
    LineNumber: int
    RawLine: string
    FilePath: string option
    Context: string list 
    Count: int 
}

type ValidationStats = {
    TotalLines: int
    ProcessedLines: int
    ErrorCount: int
    WarningCount: int
    NullByteCount: int
    ErrorDensity: float
    StartTime: DateTime
    EndTime: DateTime option
}

// 2. Active Patterns
module Patterns = 
    let mkRegex p = Regex(p, RegexOptions.Compiled)
    let rError = mkRegex @"error:|^^ ** \("
    let rWarning = mkRegex @"warning:|Warning"
    let rUndefined = mkRegex @"undefined function|undefined variable"
    let rSyntax = mkRegex @"syntax error|unexpected token"
    
    let (|IsError|_|) (line: string) = if rError.IsMatch(line) then Some CompilationError else None
    let (|IsWarning|_|) (line: string) = if rWarning.IsMatch(line) then Some UnusedVariable else None 
    let (|IsCritical|_|) (line: string) = if line.Contains("== Compilation error") || line.Contains("** (CompileError)") then Some line else None

// 4. Zenoh Mesh Integration (REST Bridge) - Moved to TOP
module Zenoh = 
    let endpoint = "http://localhost:8000"
    let client = new HttpClient()

    let publish (key: string) (value: obj) = async {
        try 
            let options = JsonSerializerOptions(WriteIndented = false)
            options.Converters.Add(System.Text.Json.Serialization.JsonStringEnumConverter())
            let json = JsonSerializer.Serialize(value, options)
            let content = new StringContent(json, Encoding.UTF8, "application/json")
            let! _ = client.PutAsync(sprintf "%s/%s" endpoint key, content) |> Async.AwaitTask
            ()
        with _ -> ()
    }

    let publishStats (stats: ValidationStats) = publish "indrajaal/telemetry/validation/stats" stats
    let sanitizePath (path: string option) = match path with Some p -> p.Replace("/home/an/dev/ver/", "$REPO_ROOT/") | None -> "unknown"
    let publishIssue (issue: LogIssue) = 
        let safeIssue = { issue with FilePath = Some (sanitizePath issue.FilePath); RawLine = "" } 
        publish "indrajaal/events/validation/issue" safeIssue
    let publishSystemState (state: string) = publish "indrajaal/control/validation/state" {| status = state; timestamp = DateTime.UtcNow |}
    let publishCost (model: string) (tokens: int) (estimatedCost: float) = 
        publish "indrajaal/telemetry/ai/cost" {| model = model; tokens = tokens; cost = estimatedCost; timestamp = DateTime.UtcNow |}

module FileUtils = 
    let getContext (filePath: string) (lineNum: int) (window: int) = 
        try 
            if File.Exists(filePath) then 
                File.ReadLines(filePath) |> Seq.skip (max 0 (lineNum - window - 1)) |> Seq.truncate (window * 2 + 1) |> Seq.toList
            else []
        with _ -> []

    let extractFilePath (line: string) = 
        let m = Regex.Match(line, @"(?:^|\s)([\w\-\./]+\.(?:ex|exs|fs|fsx|rs)):(\d+)")
        if m.Success then Some (m.Groups.[1].Value, int m.Groups.[2].Value) else None

// 2.5 Resilience
module Resilience = 
    type CircuitState = Closed | Open | HalfOpen
    type CircuitBreaker(failureThreshold: int, resetTimeout: TimeSpan) = 
        let mutable state = Closed
        let mutable failures = 0
        let mutable lastFailureTime = DateTime.MinValue
        let lockObj = obj()

        member this.ExecuteAsync<'T>(action: unit -> Async<'T>) : Async<Result<'T, string>> = async {
            let currentState = lock lockObj (fun () -> if state = Open && (DateTime.UtcNow - lastFailureTime) > resetTimeout then state <- HalfOpen; state)
            match currentState with
            | Open -> return Error "Circuit Breaker is OPEN. Request skipped."
            | _ ->
                try
                    let! result = action()
                    lock lockObj (fun () -> if state = HalfOpen then state <- Closed; failures <- 0)
                    return Ok result
                with ex ->
                    lock lockObj (fun () -> failures <- failures + 1; if failures >= failureThreshold then state <- Open; lastFailureTime <- DateTime.UtcNow; printfn "🔥 Circuit Breaker TRIPPED! Pausing AI calls for %A" resetTimeout)
                    return Error ex.Message
        }

// 2.9 OpenRouter Client
module OpenRouterClient = 
    let endpoint = "https://openrouter.ai/api/v1/chat/completions"
    let client = new HttpClient()

    type ProviderSettings = { [<JsonPropertyName("zdr")>] Zdr: bool }
    type ChatMessage = { [<JsonPropertyName("role")>] Role: string; [<JsonPropertyName("content")>] Content: string }
    type Prediction = { [<JsonPropertyName("type")>] Type: string; [<JsonPropertyName("content")>] Content: string }
    
    type CompletionRequest = {
        [<JsonPropertyName("model")>] Model: string option
        [<JsonPropertyName("models")>] Models: string list option
        [<JsonPropertyName("messages")>] Messages: ChatMessage list
        [<JsonPropertyName("provider")>] Provider: ProviderSettings
        [<JsonPropertyName("route")>] Route: string option
        [<JsonPropertyName("prediction")>] Prediction: Prediction option
    }
    type Usage = {
        [<JsonPropertyName("prompt_tokens")>] PromptTokens: int
        [<JsonPropertyName("completion_tokens")>] CompletionTokens: int
        [<JsonPropertyName("total_tokens")>] TotalTokens: int
        [<JsonPropertyName("total_cost")>] TotalCost: decimal
    }
    type Choice = { [<JsonPropertyName("message")>] Message: ChatMessage }
    type CompletionResponse = { [<JsonPropertyName("choices")>] Choices: Choice list; [<JsonPropertyName("usage")>] Usage: Usage option }

    let private parseResponse (json: string) =
        try
            let result = JsonSerializer.Deserialize<CompletionResponse>(json)
            match result.Choices with
            | head :: _ -> Ok (head.Message.Content, result.Usage)
            | [] -> Error "No choices returned from OpenRouter"
        with ex ->
            Error (sprintf "Failed to parse OpenRouter response: %s" ex.Message)

    let call (model: string) (prompt: string) (fallbacks: string list) (prefill: string option) = async {
        let apiKey = Environment.GetEnvironmentVariable("OPENROUTER_API_KEY")
        if String.IsNullOrEmpty(apiKey) then 
            failwith "Missing OPENROUTER_API_KEY"

        let messages = 
            match prefill with
            | Some content -> [ { Role = "user"; Content = prompt }; { Role = "assistant"; Content = content } ]
            | None -> [ { Role = "user"; Content = prompt } ]

        let request = 
            if fallbacks.Length > 0 then
                {
                    Model = None
                    Models = Some (model :: fallbacks)
                    Messages = messages
                    Provider = { Zdr = true }
                    Route = Some "fallback"
                    Prediction = None
                }
            else
                {
                    Model = Some model
                    Models = None
                    Messages = messages
                    Provider = { Zdr = true }
                    Route = None
                    Prediction = None
                }

        let json = JsonSerializer.Serialize(request)
        let content = new StringContent(json, Encoding.UTF8, "application/json")
        
        let msg = new HttpRequestMessage(HttpMethod.Post, endpoint)
        msg.Headers.Add("Authorization", sprintf "Bearer %s" apiKey)
        msg.Headers.Add("HTTP-Referer", "https://indrajaal.ai") 
        msg.Headers.Add("X-Title", "Indrajaal Validation Cortex")
        msg.Content <- content

        let! internalResult = async {
            try
                let! r = client.SendAsync(msg) |> Async.AwaitTask
                let! b = r.Content.ReadAsStringAsync() |> Async.AwaitTask
                return Ok (r, b)
            with ex ->
                return Error ex
            finally
                msg.Dispose()
        }

        match internalResult with
        | Ok (response, responseBody) ->
            if not response.IsSuccessStatusCode then
                 let errMsg = sprintf "OpenRouter API Error: %d %s" (int response.StatusCode) responseBody
                 return failwith errMsg
            else
                 match parseResponse responseBody with
                 | Ok res -> return res
                 | Error err -> return failwith err
        | Error ex ->
            return failwithf "HTTP Request Failed: %s" ex.Message
    }

// 3. Cortex (AI Intelligence)
module Cortex = 
    type ModelTier = TierFree | TierLow | TierMedium | TierHigh
    type ModelConfig = { Id: string; Provider: string; Tier: ModelTier }
    type AiResponse = { Analysis: string; Fix: string; Confidence: float }

    let fallbackChain = [
        { Id = "mistralai/devstral-2512:free"; Provider = "OpenRouter"; Tier = TierFree }
        { Id = "google/gemini-2.0-flash-lite-preview-02-05:free"; Provider = "OpenRouter"; Tier = TierFree }
        { Id = "anthropic/claude-3.5-sonnet"; Provider = "OpenRouter"; Tier = TierHigh }
        { Id = "local-heuristic"; Provider = "Local"; Tier = TierFree }
    ]

    type RateLimiter(tokensPerMinute: int) = 
        let semaphore = new SemaphoreSlim(tokensPerMinute, tokensPerMinute)
        let _ = new Timer((fun _ -> 
            try let current = semaphore.CurrentCount; if current < tokensPerMinute then semaphore.Release(tokensPerMinute - current) |> ignore
            with _ -> ()), null, 60000, 60000)
        member _.WaitAsync() = semaphore.WaitAsync()

    let rateLimiter = RateLimiter(15)
    let circuitBreaker = Resilience.CircuitBreaker(3, TimeSpan.FromSeconds(30.0))
    let estimateTokens (text: string) = let words = text.Split([|' '; '\n'; '\t'|], StringSplitOptions.RemoveEmptyEntries) in float words.Length * 1.3 |> int
    let getModelForSeverity (severity: Severity) = 
        match severity with Critical -> "google/gemini-2.0-pro-exp-02-05:free" | High -> "google/gemini-2.0-flash-lite-preview-02-05:free" | _ -> "google/gemini-2.0-flash-lite-preview-02-05:free"

    let private executeRealApi (model: ModelConfig) (prompt: string) (prefill: string option) = async {
        let fallbacks = fallbackChain |> List.filter (fun m -> m.Id <> model.Id && m.Provider = "OpenRouter") |> List.map (fun m -> m.Id)
        let! (content, usage) = OpenRouterClient.call model.Id prompt fallbacks prefill
        match usage with Some u -> do! Zenoh.publishCost model.Id u.TotalTokens (float u.TotalCost) | None -> ()
        return content
    }

    let private simulateApiCall (model: ModelConfig) (prompt: string) = async {
        let failMistral = Environment.GetEnvironmentVariable("SIM_FAIL_MISTRAL") = "true"
        let failGemini = Environment.GetEnvironmentVariable("SIM_FAIL_GEMINI") = "true"
        let latency = match model.Tier with TierFree -> 200 | TierHigh -> 800 | _ -> 400
        do! Async.Sleep(latency)
        if model.Id.Contains("mistral") && failMistral then failwith "503 Service Unavailable"
        if model.Id.Contains("gemini") && failGemini then failwith "429 Too Many Requests"
        if model.Provider = "Local" then return sprintf "{\"Analysis\": \"Heuristic detection.\", \"Fix\": \"Check syntax.\", \"Confidence\": 0.5}"
        else return sprintf "{\"Analysis\": \"AI Analysis by %s\", \"Fix\": \"Fix suggestion\", \"Confidence\": 0.95}" model.Id
    }

    let rec executeWithFallback (chain: ModelConfig list) (issue: LogIssue) (errors: string list) (prefill: string option) = async {
        match chain with 
        | [] -> return (sprintf "All models failed. Errors: %A" errors, None)
        | model :: rest ->
            try 
                if model.Provider = "Local" then return (sprintf "[%s] Analysis: Fallback. Check: %s" model.Id issue.Message, None)
                else 
                    do! rateLimiter.WaitAsync() |> Async.AwaitTask
                    let useRealApi = Environment.GetEnvironmentVariable("OPENROUTER_REAL_MODE") = "true"
                    let! (jsonResult, usage) = if useRealApi then executeRealApi model issue.RawLine prefill else async { let! res = simulateApiCall model issue.RawLine in return (res, None) }
                    try 
                        let parsed = JsonSerializer.Deserialize<AiResponse>(jsonResult)
                        return (sprintf "[%s] Analysis: %s (Fix: %s)" model.Id parsed.Analysis parsed.Fix, usage)
                    with _ -> return (sprintf "[%s] Raw Analysis: %s" model.Id jsonResult, usage)
            with ex -> 
                let errorMsg = sprintf "%s failed: %s" model.Id ex.Message
                return! executeWithFallback rest issue (errors @ [errorMsg]) prefill
    }

    let generateFix (issue: LogIssue) = async {
        let contextStr = String.Join("\n", issue.Context)
        let prompt = sprintf "Error: %s\nFile: %s:%d\nContext:\n%s\n\nGenerate a fix." issue.Message (defaultArg issue.FilePath "unknown") issue.LineNumber contextStr
        let prefill = Some "```fsharp"
        let action = fun () -> async {
             do! rateLimiter.WaitAsync() |> Async.AwaitTask
             let apiKey = Environment.GetEnvironmentVariable("OPENROUTER_API_KEY")
             if String.IsNullOrEmpty(apiKey) then return ("AI Fix Skipped (No Key)", None)
             else return! executeWithFallback fallbackChain issue [] prefill
        }
        let! result = circuitBreaker.ExecuteAsync(action)
        match result with Ok (s, usage) -> return (s, usage) | Error e -> return (sprintf "Fix Gen Failed: %s" e, None)
    }

    let analyzeError (issue: LogIssue) = async { return! generateFix issue }

// 5. Persistence
module Persistence = 
    let persistencePath = "validation_state.db.json"
    type PersistentState = { LastRun: DateTime; TotalErrorsDetected: int; TotalCost: float; KnownIssuesHash: string }
    let loadState () = async {
        try if File.Exists(persistencePath) then let json = File.ReadAllText(persistencePath) in JsonSerializer.Deserialize<PersistentState>(json)
            else { LastRun = DateTime.MinValue; TotalErrorsDetected = 0; TotalCost = 0.0; KnownIssuesHash = "" }
        with _ -> { LastRun = DateTime.MinValue; TotalErrorsDetected = 0; TotalCost = 0.0; KnownIssuesHash = "" }
    }
    let saveState (stats: ValidationStats) (cost: float) = async {
        try let! current = loadState()
            let newState = { current with LastRun = DateTime.UtcNow; TotalErrorsDetected = current.TotalErrorsDetected + stats.ErrorCount; TotalCost = current.TotalCost + cost }
            let json = JsonSerializer.Serialize(newState)
            File.WriteAllText(persistencePath, json)
            printfn "[Persistence] State saved to %s" persistencePath
        with ex -> printfn "[Persistence] Failed to save state: %s" ex.Message
    }

// 5.1 Smriti
module Smriti = 
    let queryKnownErrors (signature: string) = async {
        do! Async.Sleep(50)
        match signature with s when s.Contains("UndefinedFunction") -> return Some "Known Issue: EP-022." | _ -> return None
    }
    let recordFix (issue: LogIssue) (fix: string) = async { () }

// 6. Supervisors
type BatchMessage = ProcessLine of int * string | Flush | GetReport of AsyncReplyChannel<ValidationStats * LogIssue list * bool * float>

type BatchSupervisor(batchId: int) = 
    let agent = MailboxProcessor.Start(fun inbox ->
        let rec loop (stats: ValidationStats) (issues: Map<string, LogIssue>) (sessionCost: float) = async {
            try
                let! msg = inbox.Receive()
                match msg with
                | ProcessLine (lineNum, line) ->
                    let hasCorruption = line.Contains("\u0000") || line.Contains("\uFFFD")
                    let newNulls = if hasCorruption then stats.NullByteCount + 1 else stats.NullByteCount
                    let newStats = { stats with ProcessedLines = stats.ProcessedLines + 1; TotalLines = stats.TotalLines + 1; NullByteCount = newNulls }
                    let fileInfo = FileUtils.extractFilePath line
                    let (filePath, fileLine) = match fileInfo with Some (path, ln) -> (Some path, ln) | None -> (None, lineNum)
                    let context = match filePath with Some path -> FileUtils.getContext path fileLine 3 | None -> []
                    match line with
                    | Patterns.IsCritical _ ->
                        let key = line.Substring(0, min 50 line.Length)
                        let issue = { Type = CompilationError; Severity = Critical; Message = line; LineNumber = fileLine; RawLine = line; FilePath = filePath; Context = context; Count = 1 }
                        return! loop { newStats with ErrorCount = newStats.ErrorCount + 1 } (issues.Add(key, issue)) sessionCost
                    | Patterns.IsError _ ->
                        let key = line.Substring(0, min 50 line.Length)
                        let issue = { Type = CompilationError; Severity = High; Message = line; LineNumber = fileLine; RawLine = line; FilePath = filePath; Context = context; Count = 1 }
                        return! loop { newStats with ErrorCount = newStats.ErrorCount + 1 } (issues.Add(key, issue)) sessionCost
                    | Patterns.IsWarning _ -> return! loop { newStats with WarningCount = newStats.WarningCount + 1 } issues sessionCost
                    | _ -> return! loop newStats issues sessionCost
                | Flush ->
                    let density = float stats.ErrorCount / float (max 1 stats.TotalLines)
                    if density > 0.10 then printfn "⚠️ [Batch %d] High Error Density: %.2f%%" batchId (density * 100.0)
                    do! Zenoh.publishStats stats
                    let topIssues = issues.Values |> Seq.filter (fun i -> i.Severity = Critical || i.Severity = High) |> Seq.truncate 3 |> Seq.toList
                    let mutable updatedCost = sessionCost
                    for issue in topIssues do
                        do! Zenoh.publishIssue issue
                        Async.Start (async {
                            try
                                let! knownFix = Smriti.queryKnownErrors issue.Message
                                match knownFix with 
                                | Some fix -> printfn "[Smriti] Recall: %s" fix
                                | None ->
                                    let! (fixProposal, usage) = Cortex.generateFix issue
                                    printfn "[Cortex] Auto-Fix Proposal: %s" fixProposal
                                    match usage with Some u -> do! Zenoh.publishCost issue.Message u.TotalTokens (float u.TotalCost) | None -> ()
                            with ex -> printfn "🔥 [Async Analysis Failed] %s" ex.Message
                        })
                    return! loop stats issues updatedCost
                | GetReport reply ->
                    let isClean = stats.ErrorCount = 0 && stats.WarningCount = 0 && stats.NullByteCount = 0
                    let consensus = isClean 
                    reply.Reply(stats, issues.Values |> Seq.toList, isClean, sessionCost)
                    return! loop stats issues sessionCost
            with ex ->
                printfn "🔥 [BatchSupervisor Crash Recovery] %s" ex.Message
                return! loop stats issues sessionCost
        }
        loop { TotalLines = 0; ProcessedLines = 0; ErrorCount = 0; WarningCount = 0; NullByteCount = 0; ErrorDensity = 0.0; StartTime = DateTime.UtcNow; EndTime = None } Map.empty 0.0
    )
    member this.Process(lineNum, line) = agent.Post(ProcessLine(lineNum, line))
    member this.Flush() = agent.Post(Flush)
    member this.GetReport() = agent.PostAndReply(GetReport)

type SystemSupervisor() = 
    let batchSupervisors = ConcurrentDictionary<int, BatchSupervisor>()
    let cts = new CancellationTokenSource()
    do AppDomain.CurrentDomain.ProcessExit.Add(fun _ -> printfn "\n🛑 SystemSupervisor: Graceful Shutdown Initiated..."; cts.Cancel(); printfn "👋 SystemSupervisor: Goodbye.")
    member this.GetOrCreateBatch(id: int) = batchSupervisors.GetOrAdd(id, fun k -> BatchSupervisor(k))
    member this.ExecuteFullAudit(path: string) = async {
        do! Zenoh.publishSystemState "AUDIT_STARTED"
        let totalLines = File.ReadLines(path) |> Seq.length
        let batchSize = 1000
        let supervisor = this.GetOrCreateBatch(1)
        let mutable count = 0
        try 
            try 
                for line in File.ReadLines(path) do
                    if cts.Token.IsCancellationRequested then raise (OperationCanceledException())
                    count <- count + 1
                    supervisor.Process(count, line)
                    if count % batchSize = 0 then supervisor.Flush()
            finally supervisor.Flush()
            let (stats, issues, consensus, sessionCost) = supervisor.GetReport()
            do! Persistence.saveState stats sessionCost 
            if not consensus then do! Zenoh.publishSystemState "HOMEOSTASIS_BREACHED"
            else do! Zenoh.publishSystemState "HOMEOSTASIS_MAINTAINED"
            return (stats, issues, consensus)
        with 
        | :? OperationCanceledException -> do! Zenoh.publishSystemState "AUDIT_CANCELLED"; return ({TotalLines=0; ProcessedLines=0; ErrorCount=0; WarningCount=0; NullByteCount=0; ErrorDensity=0.0; StartTime=DateTime.UtcNow; EndTime=None}, [], false)
        | ex -> printfn "🔥 SystemSupervisor Crash: %s" ex.Message; do! Zenoh.publishSystemState "SYSTEM_CRASH"; return ({TotalLines=0; ProcessedLines=0; ErrorCount=0; WarningCount=0; NullByteCount=0; ErrorDensity=0.0; StartTime=DateTime.UtcNow; EndTime=None}, [], false)
    }