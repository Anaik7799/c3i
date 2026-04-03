// =============================================================================
// CortexHandler.fs - MCP Tool Handler for Cortex AI Operations
// =============================================================================
// STAMP: SC-MCP-001 (MCP server integration), SC-AI-001 (AI assistance through Cortex),
//        SC-MODEL-001 (OpenRouter model registry), SC-ORCH-006 (AI assistance through Cortex)
// AOR: AOR-MCP-001 (authorised MCP tool dispatch),
//      AOR-CTX-001 (context management)
//
// Implements MCP tool handler functions for the Cortex AI subsystem.
// Provides inference request/response round-trip and model listing.
//
// All public functions return Result<string, string>:
//   Ok    — JSON string for MCP TextContent.Text
//   Error — human-readable error message
//
// Note: This module uses an in-process stub for inference. In production
// it delegates to `AI.OpenRouterClient` (Cepaf.Cockpit) via Zenoh.
// =============================================================================

namespace Cepaf.Mcp

open System
open System.Text.Json
open System.Text.Json.Serialization
open System.Collections.Concurrent
open System.Net.Http
open System.Threading

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// An inference request submitted to the Cortex AI subsystem.
[<CLIMutable>]
type InferenceRequest = {
    [<JsonPropertyName("request_id")>]  RequestId  : string
    [<JsonPropertyName("model_id")>]    ModelId    : string
    [<JsonPropertyName("prompt")>]      Prompt     : string
    [<JsonPropertyName("max_tokens")>]  MaxTokens  : int
    [<JsonPropertyName("temperature")>] Temperature : float
    [<JsonPropertyName("timestamp")>]   Timestamp  : string
}

/// Status of an in-flight or completed inference request.
[<RequireQualifiedAccess>]
type InferenceStatus =
    | Queued
    | Processing
    | Completed of result: string
    | Failed    of error: string

/// Metadata record for a known AI model.
[<CLIMutable>]
type ModelInfo = {
    [<JsonPropertyName("model_id")>]    ModelId     : string
    [<JsonPropertyName("provider")>]    Provider    : string
    [<JsonPropertyName("display_name")>] DisplayName : string
    [<JsonPropertyName("context_window")>] ContextWindow : int
    [<JsonPropertyName("supports_tools")>] SupportsTools : bool
}

// ---------------------------------------------------------------------------
// Registry of available models (SC-MODEL-001 — OpenRouter model registry)
// ---------------------------------------------------------------------------

module private ModelRegistry =

    let all : ModelInfo list = [
        { ModelId       = "anthropic/claude-sonnet-4-6"
          Provider      = "Anthropic"
          DisplayName   = "Claude Sonnet 4.6"
          ContextWindow = 200000
          SupportsTools = true }
        { ModelId       = "anthropic/claude-opus-4"
          Provider      = "Anthropic"
          DisplayName   = "Claude Opus 4"
          ContextWindow = 200000
          SupportsTools = true }
        { ModelId       = "anthropic/claude-haiku-4"
          Provider      = "Anthropic"
          DisplayName   = "Claude Haiku 4"
          ContextWindow = 200000
          SupportsTools = true }
        { ModelId       = "openai/gpt-4o"
          Provider      = "OpenAI"
          DisplayName   = "GPT-4o"
          ContextWindow = 128000
          SupportsTools = true }
        { ModelId       = "openai/o3-mini"
          Provider      = "OpenAI"
          DisplayName   = "o3-mini"
          ContextWindow = 200000
          SupportsTools = false }
        { ModelId       = "google/gemini-2.5-pro"
          Provider      = "Google"
          DisplayName   = "Gemini 2.5 Pro"
          ContextWindow = 1000000
          SupportsTools = true }
        { ModelId       = "meta-llama/llama-3.3-70b-instruct"
          Provider      = "Meta"
          DisplayName   = "Llama 3.3 70B Instruct"
          ContextWindow = 128000
          SupportsTools = false }
    ]

    let find (modelId: string) : ModelInfo option =
        all |> List.tryFind (fun m -> m.ModelId = modelId)

// ---------------------------------------------------------------------------
// Local model discovery (Ollama API probe)
// ---------------------------------------------------------------------------

module private LocalModels =

    open System.IO

    let private httpClient =
        lazy (
            let handler = new HttpClientHandler()
            let client = new HttpClient(handler)
            client.Timeout <- TimeSpan.FromSeconds(3.0)
            client
        )

    /// Detect locally-available Ollama models by probing localhost:11434/api/tags.
    /// Returns model names on success, empty list on failure (graceful degradation).
    let detectOllamaModels () : ModelInfo list =
        try
            let client = httpClient.Value
            use cts = new CancellationTokenSource(TimeSpan.FromSeconds(2.0))
            let response = client.GetAsync("http://localhost:11434/api/tags", cts.Token)
                           |> Async.AwaitTask |> Async.RunSynchronously
            if response.IsSuccessStatusCode then
                let body = response.Content.ReadAsStringAsync()
                           |> Async.AwaitTask |> Async.RunSynchronously
                // Parse JSON: {"models":[{"name":"llama3.2:latest","size":...},...]}
                use doc = JsonDocument.Parse(body)
                let root = doc.RootElement
                match root.TryGetProperty("models") with
                | (true, modelsArr) ->
                    modelsArr.EnumerateArray()
                    |> Seq.choose (fun m ->
                        match m.TryGetProperty("name") with
                        | (true, nameEl) ->
                            let name = nameEl.GetString()
                            Some {
                                ModelId       = sprintf "local/%s" (name.Replace(":", "-"))
                                Provider      = "Ollama (Local)"
                                DisplayName   = sprintf "Ollama %s" name
                                ContextWindow = 8192
                                SupportsTools = false
                            }
                        | _ -> None)
                    |> Seq.truncate 20
                    |> Seq.toList
                | _ -> []
            else []
        with _ ->
            eprintfn "[CortexHandler] Ollama not available at localhost:11434 (graceful degradation)"
            []

    /// Cached local models — probed once per process lifetime.
    let private localCache = lazy (detectOllamaModels ())

    /// Get all models: registry + local Ollama.
    let allModels () : ModelInfo list =
        try
            let local = localCache.Value
            if local.Length > 0 then
                eprintfn "[CortexHandler] detected %d local Ollama models" local.Length
            ModelRegistry.all @ local
        with _ ->
            ModelRegistry.all

// ---------------------------------------------------------------------------
// In-memory request store with metrics tracking
// ---------------------------------------------------------------------------

module private CortexState =

    let private requests = ConcurrentDictionary<string, InferenceRequest * InferenceStatus>()
    let mutable private totalRequests = 0L
    let mutable private completedRequests = 0L
    let mutable private failedRequests = 0L

    let store (req: InferenceRequest) =
        requests.TryAdd(req.RequestId, (req, InferenceStatus.Queued)) |> ignore
        Interlocked.Increment(&totalRequests) |> ignore

    let get (id: string) : (InferenceRequest * InferenceStatus) option =
        match requests.TryGetValue(id) with
        | (true, v) -> Some v
        | _         -> None

    let update (id: string) (status: InferenceStatus) =
        match requests.TryGetValue(id) with
        | (true, (req, _)) ->
            requests.[id] <- (req, status)
            match status with
            | InferenceStatus.Completed _ -> Interlocked.Increment(&completedRequests) |> ignore
            | InferenceStatus.Failed _    -> Interlocked.Increment(&failedRequests) |> ignore
            | _ -> ()
        | _ -> ()

    let getMetrics () =
        {| total = Interlocked.Read(&totalRequests)
           completed = Interlocked.Read(&completedRequests)
           failed = Interlocked.Read(&failedRequests)
           pending = Interlocked.Read(&totalRequests) - Interlocked.Read(&completedRequests) - Interlocked.Read(&failedRequests)
           store_size = requests.Count |}

    /// Simulate immediate inference completion for stub mode.
    let simulateCompletion (req: InferenceRequest) =
        let reply = sprintf "[STUB] Model %s processed: %s (tokens≤%d)"
                        req.ModelId
                        (if req.Prompt.Length > 60 then req.Prompt.[..59] + "…" else req.Prompt)
                        req.MaxTokens
        update req.RequestId (InferenceStatus.Completed reply)

// ---------------------------------------------------------------------------
// CortexHandler — MCP tool functions
// ---------------------------------------------------------------------------

/// MCP tool handler for Cortex AI operations.
/// Functions probe local Ollama, track metrics, and fall back to stub inference.
module CortexHandler =

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    let private statusString (s: InferenceStatus) : string =
        match s with
        | InferenceStatus.Queued        -> "queued"
        | InferenceStatus.Processing    -> "processing"
        | InferenceStatus.Completed _   -> "completed"
        | InferenceStatus.Failed _      -> "failed"

    let private serialise<'T> (v: 'T) : string =
        JsonSerializer.Serialize(v)

    // -----------------------------------------------------------------------
    // Public MCP tool functions
    // -----------------------------------------------------------------------

    /// Submits an inference request to the Cortex AI subsystem.
    ///
    /// Parameters:
    ///   modelId     — model identifier (see listModels)
    ///   prompt      — the input prompt text
    ///   maxTokens   — maximum tokens to generate (default 512)
    ///   temperature — sampling temperature 0.0–2.0 (default 0.7)
    ///
    /// Returns: JSON object `{ request_id, model_id, status, timestamp }`
    let requestInference
        (modelId     : string)
        (prompt      : string)
        (maxTokens   : int)
        (temperature : float) : Result<string, string> =

        if String.IsNullOrWhiteSpace modelId then
            Error "model_id must not be empty"
        elif String.IsNullOrWhiteSpace prompt then
            Error "prompt must not be empty"
        elif maxTokens <= 0 then
            Error "max_tokens must be positive"
        elif temperature < 0.0 || temperature > 2.0 then
            Error "temperature must be in range [0.0, 2.0]"
        else
            let allModels = LocalModels.allModels()
            let foundModel = allModels |> List.tryFind (fun m -> m.ModelId = modelId)
            match foundModel with
            | None ->
                Error (sprintf "Unknown model '%s'. Call listModels to see available models." modelId)
            | Some _ ->
                let requestId = sprintf "INF-%s-%s"
                                    (DateTimeOffset.UtcNow.ToString("yyyyMMddHHmmss"))
                                    (Guid.NewGuid().ToString("N").[..7])
                let req : InferenceRequest = {
                    RequestId   = requestId
                    ModelId     = modelId
                    Prompt      = prompt
                    MaxTokens   = maxTokens
                    Temperature = temperature
                    Timestamp   = DateTimeOffset.UtcNow.ToString("o")
                }
                CortexState.store req
                // Stub: complete immediately in-process
                CortexState.simulateCompletion req
                eprintfn "[CortexHandler] inference queued: %s model=%s" requestId modelId
                let result = {|
                    request_id = requestId
                    model_id   = modelId
                    status     = "queued"
                    timestamp  = req.Timestamp
                    message    = sprintf "Inference %s submitted to Cortex" requestId
                |}
                Ok (serialise result)

    /// Retrieves the result of an inference request by ID.
    ///
    /// Returns: JSON object `{ request_id, status, result?, error?, timestamp }`
    let getResult (requestId: string) : Result<string, string> =
        if String.IsNullOrWhiteSpace requestId then
            Error "request_id must not be empty"
        else
            match CortexState.get requestId with
            | None ->
                Error (sprintf "Request '%s' not found" requestId)
            | Some (req, status) ->
                let resultText, errorText =
                    match status with
                    | InferenceStatus.Completed r -> Some r, None
                    | InferenceStatus.Failed e    -> None,   Some e
                    | _                           -> None,   None
                let record = {|
                    request_id = req.RequestId
                    model_id   = req.ModelId
                    status     = statusString status
                    result     = resultText
                    error      = errorText
                    timestamp  = DateTimeOffset.UtcNow.ToString("o")
                |}
                Ok (serialise record)

    /// Lists all AI models available through the Cortex subsystem.
    /// Includes both cloud models (OpenRouter registry) and local Ollama models.
    ///
    /// Returns: JSON array of model metadata records.
    let listModels () : Result<string, string> =
        let allModels = LocalModels.allModels()
        eprintfn "[CortexHandler] listModels: %d cloud + %d local = %d total"
            ModelRegistry.all.Length
            (allModels.Length - ModelRegistry.all.Length)
            allModels.Length
        Ok (serialise allModels)

    /// Returns metadata for a single model by ID.
    ///
    /// Returns: JSON object with model metadata, or error if unknown.
    let getModel (modelId: string) : Result<string, string> =
        if String.IsNullOrWhiteSpace modelId then
            Error "model_id must not be empty"
        else
            let allModels = LocalModels.allModels()
            match allModels |> List.tryFind (fun m -> m.ModelId = modelId) with
            | None      -> Error (sprintf "Unknown model '%s'" modelId)
            | Some info -> Ok (serialise info)

    /// Returns inference metrics (total, completed, failed, pending, store_size).
    ///
    /// Returns: JSON object with inference subsystem metrics.
    let getMetrics () : Result<string, string> =
        let metrics = CortexState.getMetrics()
        let localCount = (LocalModels.allModels()).Length - ModelRegistry.all.Length
        let result = {|
            inference = metrics
            models = {|
                cloud = ModelRegistry.all.Length
                local = localCount
                total = ModelRegistry.all.Length + localCount
            |}
        |}
        Ok (serialise result)
