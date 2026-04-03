// =============================================================================
// OpenRouterClient.fs - AI Client Implementation
// =============================================================================
// Phase 3: Cognitive Expansion
// STAMP: SC-NEURO-001 (Simplex Architecture)
// Criticality: Level 3 (HIGH) - AI Communication
// =============================================================================

namespace Cepaf.Cockpit.AI

open System
open System.Net.Http
open System.Net.Http.Headers
open System.Text
open System.Text.Json
open System.Threading.Tasks

/// Client for OpenRouter API
type OpenRouterClient(apiKey: string, siteUrl: string, appName: string) =
    let httpClient = new HttpClient()
    let baseUrl = "https://openrouter.ai/api/v1/"
    let jsonOptions = 
        let opts = JsonSerializerOptions()
        opts.PropertyNamingPolicy <- JsonNamingPolicy.SnakeCaseLower
        opts.PropertyNameCaseInsensitive <- true
        opts

    do
        httpClient.BaseAddress <- Uri(baseUrl)
        httpClient.DefaultRequestHeaders.Authorization <- AuthenticationHeaderValue("Bearer", apiKey)
        httpClient.DefaultRequestHeaders.Add("HTTP-Referer", siteUrl)
        httpClient.DefaultRequestHeaders.Add("X-Title", appName)

    /// Send chat completion request
    member this.ChatCompletionAsync(request: ChatCompletionRequest) : Task<Result<ChatCompletionResponse, string>> =
        task {
            try
                let json = JsonSerializer.Serialize(request, jsonOptions)
                let content = new StringContent(json, Encoding.UTF8, "application/json")
                
                let! response = httpClient.PostAsync("chat/completions", content)
                let! responseBody = response.Content.ReadAsStringAsync()

                if response.IsSuccessStatusCode then
                    try
                        let result = JsonSerializer.Deserialize<ChatCompletionResponse>(responseBody, jsonOptions)
                        return Ok result
                    with ex ->
                        return Error (sprintf "Deserialization failed: %s. Body: %s" ex.Message responseBody)
                else
                    return Error (sprintf "API Error %d: %s" (int response.StatusCode) responseBody)
            with ex ->
                return Error (sprintf "Request failed: %s" ex.Message)
        }

    interface IDisposable with
        member _.Dispose() = httpClient.Dispose()
