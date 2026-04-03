namespace Cepaf.AI

open System
open System.Net.Http
open System.Net.Http.Json
open System.Text.Json
open System.Text.Json.Serialization
open System.Threading.Tasks

/// Configuration for OpenRouter
type OpenRouterConfig = {
    ApiKey: string
    Model: string
    BaseUrl: string
}

module Config =
    let load () = 
        let apiKey = Environment.GetEnvironmentVariable("OPENROUTER_API_KEY")
        let model = 
            match Environment.GetEnvironmentVariable("OPENROUTER_MODEL") with
            | null | "" -> "anthropic/claude-3-sonnet"
            | m -> m
        
        { 
            ApiKey = if String.IsNullOrEmpty(apiKey) then "" else apiKey
            Model = model
            BaseUrl = "https://openrouter.ai/api/v1" 
        }

/// Request/Response Types
type Message = {
    [<JsonPropertyName("role")>] Role: string
    [<JsonPropertyName("content")>] Content: string
}

type CompletionRequest = {
    [<JsonPropertyName("model")>] Model: string
    [<JsonPropertyName("messages")>] Messages: Message list
}

type Choice = {
    [<JsonPropertyName("message")>] Message: Message
}

type CompletionResponse = {
    [<JsonPropertyName("choices")>] Choices: Choice list
}

/// The F# OpenRouter Client - Unified with Elixir implementation
/// AOR-API-002: Exponential backoff on 429/503. AOR-API-006: Circuit breaker.
type OpenRouterClient(config: OpenRouterConfig) =
    let client = new HttpClient()
    let mutable consecutiveErrors = 0
    let mutable circuitBreakerUntil = DateTimeOffset.MinValue
    let maxRetries = 3

    do
        if not (String.IsNullOrEmpty(config.ApiKey)) then
            client.DefaultRequestHeaders.Add("Authorization", sprintf "Bearer %s" config.ApiKey)

        client.DefaultRequestHeaders.Add("HTTP-Referer", "https://indrajaal.ai")
        client.DefaultRequestHeaders.Add("X-Title", "Indrajaal PRAJNA")
        client.Timeout <- TimeSpan.FromSeconds(30.0)

    /// Mock fallback matching Elixir logic (AOR-OPENROUTER-005)
    member private this.MockChatAsync() =
        task {
            do! Task.Delay(500)
            return Ok "MOCK CORTEX (F#): Recommended action is to restart the affected node."
        }

    /// Exponential backoff delay (AOR-API-002)
    member private _.BackoffDelay(attempt: int) =
        let delayMs = min (1000.0 * Math.Pow(2.0, float attempt)) 30000.0
        Task.Delay(int delayMs)

    /// Send a prompt to the Cortex with retry and circuit breaker
    /// Matches Elixir: chat(prompt, context)
    /// AOR-API-002: Exponential backoff. AOR-API-006: Circuit breaker after 3 consecutive errors.
    member this.ChatAsync(prompt: string, context: string) : Task<Result<string, string>> =
        task {
            if String.IsNullOrEmpty(config.ApiKey) then
                return! this.MockChatAsync()
            // AOR-API-006: Circuit breaker check
            elif DateTimeOffset.UtcNow < circuitBreakerUntil then
                return! this.MockChatAsync()
            else
                let systemMessage = sprintf "You are PRAJNA, the Cybernetic Cortex of the Indrajaal System. Context: %s. Response must be a concise, actionable plan." context

                let reqBody = {
                    Model = config.Model
                    Messages = [
                        { Role = "system"; Content = systemMessage }
                        { Role = "user"; Content = prompt }
                    ]
                }

                let mutable lastError = ""
                let mutable attempt = 0
                let mutable result : Result<string, string> option = None

                while attempt < maxRetries && result.IsNone do
                    try
                        if attempt > 0 then
                            do! this.BackoffDelay(attempt)

                        let! response = client.PostAsJsonAsync(config.BaseUrl + "/chat/completions", reqBody)

                        if response.IsSuccessStatusCode then
                            let! body = response.Content.ReadFromJsonAsync<CompletionResponse>()
                            consecutiveErrors <- 0
                            match body.Choices with
                            | head :: _ -> result <- Some (Ok head.Message.Content)
                            | [] -> result <- Some (Error "No choices returned from OpenRouter")
                        else
                            let statusCode = int response.StatusCode
                            let! errorBody = response.Content.ReadAsStringAsync()
                            lastError <- sprintf "API Error %d: %s" statusCode errorBody

                            // AOR-API-002: Retry on 429 (rate limit) and 503 (service unavailable)
                            if statusCode = 429 || statusCode = 503 then
                                consecutiveErrors <- consecutiveErrors + 1
                                attempt <- attempt + 1
                                // AOR-API-006: Trip circuit breaker after 3 consecutive rate limit errors
                                if consecutiveErrors >= 3 then
                                    circuitBreakerUntil <- DateTimeOffset.UtcNow.AddSeconds(30.0)
                                    result <- Some (Error (sprintf "Circuit breaker tripped (30s cooldown). %s" lastError))
                            else
                                result <- Some (Error lastError)
                    with
                    | ex ->
                        lastError <- sprintf "Network Error: %s" ex.Message
                        attempt <- attempt + 1

                return result |> Option.defaultValue (Error (sprintf "Max retries exceeded. %s" lastError))
        }