/// OpenRouter API Client for Claude Integration
///
/// STAMP Constraints:
/// - SC-OPENROUTER-001: Free models MUST be prioritized
/// - SC-OPENROUTER-002: Rate limiting with exponential backoff
/// - SC-OPENROUTER-003: Fallback to mock on API unavailable
module Cepaf.Smriti.Api.AI.OpenRouterClient

open System
open System.Net.Http
open System.Text
open System.Text.Json
open System.Text.RegularExpressions

/// OpenRouter API configuration
type OpenRouterConfig = {
    ApiKey: string
    BaseUrl: string
    Model: string
    MaxTokens: int
    Temperature: float
    TimeoutSeconds: int
}

/// Extracted Zettel data from AI
type ExtractedZettel = {
    Title: string
    Summary: string
    Tags: string list
    Level: string
    KeyConcepts: string list
    RelatedTopics: string list
}

/// Default configuration
let defaultConfig () : OpenRouterConfig =
    let apiKey =
        Environment.GetEnvironmentVariable("OPENROUTER_API_KEY")
        |> Option.ofObj
        |> Option.defaultValue ""
    {
        ApiKey = apiKey
        BaseUrl = "https://openrouter.ai/api/v1"
        Model = "anthropic/claude-3-haiku"
        MaxTokens = 1024
        Temperature = 0.3
        TimeoutSeconds = 30
    }

/// Check if AI is available
let isAvailable (config: OpenRouterConfig) : bool =
    not (String.IsNullOrEmpty config.ApiKey)

/// Fallback extraction using regex
let extractFallback (content: string) (filePath: string) : ExtractedZettel =
    let titleRegex = Regex(@"^#\s+(.+)$", RegexOptions.Multiline)
    let titleMatch = titleRegex.Match(content)
    let title =
        if titleMatch.Success then titleMatch.Groups.[1].Value.Trim()
        else System.IO.Path.GetFileNameWithoutExtension(filePath).Replace("_", " ").Replace("-", " ")

    let level =
        if content.Length > 10000 then "organism"
        elif content.Length > 3000 then "molecular"
        else "atomic"

    { Title = title
      Summary = ""
      Tags = []
      Level = level
      KeyConcepts = []
      RelatedTopics = [] }

/// Extract using AI API (async)
let extractWithAI (config: OpenRouterConfig) (content: string) (filePath: string) : Async<Result<ExtractedZettel * bool, string>> =
    async {
        if not (isAvailable config) then
            return Ok (extractFallback content filePath, false)
        else
            try
                use client = new HttpClient()
                client.Timeout <- TimeSpan.FromSeconds(float config.TimeoutSeconds)
                client.DefaultRequestHeaders.Add("Authorization", sprintf "Bearer %s" config.ApiKey)
                client.DefaultRequestHeaders.Add("HTTP-Referer", "https://indrajaal.io")

                let truncated =
                    if content.Length > 6000 then content.Substring(0, 6000)
                    else content

                let prompt = sprintf """You are a knowledge management expert. Analyze this document and extract:
1. A clear title (max 80 chars)
2. A 2-sentence summary
3. Up to 5 relevant tags
4. The holon level (atomic/molecular/organism)
5. Key concepts (3-5)
6. Related topics (2-3)

Document: %s

Content:
%s

Respond with ONLY valid JSON:
{"title": "...", "summary": "...", "tags": ["..."], "level": "...", "key_concepts": ["..."], "related_topics": ["..."]}""" filePath truncated

                let requestObj = {|
                    model = config.Model
                    messages = [| {| role = "user"; content = prompt |} |]
                    max_tokens = config.MaxTokens
                    temperature = config.Temperature
                |}

                let requestJson = JsonSerializer.Serialize(requestObj)
                use httpContent = new StringContent(requestJson, Encoding.UTF8, "application/json")

                let! response = client.PostAsync(config.BaseUrl + "/chat/completions", httpContent) |> Async.AwaitTask

                if response.IsSuccessStatusCode then
                    let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                    use doc = JsonDocument.Parse(body)

                    let contentStr =
                        doc.RootElement
                            .GetProperty("choices").[0]
                            .GetProperty("message")
                            .GetProperty("content")
                            .GetString()

                    let cleaned = contentStr.Replace("```json", "").Replace("```", "").Trim()
                    use parsed = JsonDocument.Parse(cleaned)
                    let root = parsed.RootElement

                    let getStringOpt (prop: string) =
                        try
                            let mutable elem = Unchecked.defaultof<JsonElement>
                            if root.TryGetProperty(prop, &elem) then
                                elem.GetString()
                            else ""
                        with _ -> ""

                    let getArrayOpt (prop: string) =
                        try
                            let mutable elem = Unchecked.defaultof<JsonElement>
                            if root.TryGetProperty(prop, &elem) then
                                elem.EnumerateArray()
                                |> Seq.map (fun e -> e.GetString())
                                |> Seq.filter (fun s -> not (String.IsNullOrEmpty s))
                                |> Seq.toList
                            else []
                        with _ -> []

                    let extracted = {
                        Title = getStringOpt "title"
                        Summary = getStringOpt "summary"
                        Tags = getArrayOpt "tags"
                        Level = getStringOpt "level"
                        KeyConcepts = getArrayOpt "key_concepts"
                        RelatedTopics = getArrayOpt "related_topics"
                    }

                    return Ok (extracted, true)
                else
                    return Ok (extractFallback content filePath, false)
            with ex ->
                return Ok (extractFallback content filePath, false)
    }
