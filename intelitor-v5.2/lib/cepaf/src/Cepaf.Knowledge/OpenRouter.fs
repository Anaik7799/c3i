module Cepaf.Knowledge.OpenRouter

open System
open System.Net.Http
open System.Text
open System.Text.Json
open System.Text.Json.Serialization
open System.Threading.Tasks

// Configuration
type OpenRouterConfig = {
    ApiKey: string
    BaseUrl: string
    DefaultModel: string
}

// Request/Response Models
type Message = {
    [<JsonPropertyName("role")>]
    Role: string
    [<JsonPropertyName("content")>]
    Content: string
}

type ProviderPreferences = {
    [<JsonPropertyName("data_collection")>]
    DataCollection: string
}

type CompletionRequest = {
    [<JsonPropertyName("model")>]
    Model: string
    [<JsonPropertyName("messages")>]
    Messages: Message list
    [<JsonPropertyName("temperature")>]
    Temperature: float
    [<JsonPropertyName("provider")>]
    Provider: ProviderPreferences
}

type Choice = {
    [<JsonPropertyName("message")>]
    Message: Message
}

type CompletionResponse = {
    [<JsonPropertyName("choices")>]
    Choices: Choice list
}

type OpenRouterClient(config: OpenRouterConfig) = 
    
    let client = new HttpClient()
    
    do
        client.BaseAddress <- Uri(config.BaseUrl)
        // Check for empty key to avoid runtime errors if not set
        if not (String.IsNullOrEmpty(config.ApiKey)) then
            client.DefaultRequestHeaders.Add("Authorization", sprintf "Bearer %s" config.ApiKey)
        
        client.DefaultRequestHeaders.Add("HTTP-Referer", "https://intelitor.ai")
        client.DefaultRequestHeaders.Add("X-Title", "Indrajaal Knowledge Engine")

    member this.CompleteAsync(prompt: string, ?model: string, ?systemPrompt: string) = 
        task {
            // User mandate: Use configured model or fallback, do not hardcode
            let selectedModel = defaultArg model (if String.IsNullOrEmpty(config.DefaultModel) then "google/gemini-2.0-flash-lite-preview-02-05:free" else config.DefaultModel)
            
            let messages = 
                match systemPrompt with
                | Some sys -> [ { Role = "system"; Content = sys }; { Role = "user"; Content = prompt } ]
                | None -> [ { Role = "user"; Content = prompt } ]

            let requestBody = {
                Model = selectedModel
                Messages = messages
                Temperature = 0.2
                Provider = { DataCollection = "deny" } // SC-PRIV-001: ZDR enabled by default
            }

            let json = JsonSerializer.Serialize(requestBody)
            let content = new StringContent(json, Encoding.UTF8, "application/json")

            let! response = client.PostAsync("chat/completions", content)
            let! responseString = response.Content.ReadAsStringAsync()
            
            if not response.IsSuccessStatusCode then
                failwithf "OpenRouter API Error: %s" responseString

            let result = JsonSerializer.Deserialize<CompletionResponse>(responseString)
            return result.Choices[0].Message.Content
        }

    // Specialized Method: Auto-Classify
    member this.AutoClassifyAsync(text: string) = 
        let systemPrompt = 
            "You are the Indrajaal Knowledge Engine (IKE) Classifier.\n" +
            "Analyze the input text and return a JSON object with the following fields:\n" +
            "- holon_level: 'atomic', 'molecular', 'organism', or 'ecosystem'\n" +
            "- rhetorical_function: 'axiom', 'hypothesis', 'evidence', 'synthesis', or 'description'\n" +
            "- keywords: list of 5 key terms\n" +
            "- summary: 1 sentence summary\n" +
            "Return ONLY the JSON. No markdown formatting."
            
        // Use default model from config
        this.CompleteAsync(text, systemPrompt = systemPrompt)

    // Specialized Method: Oracle
    member this.OracleConsultAsync(query: string, context: string) = 
        let systemPrompt = 
            sprintf "You are the Indrajaal System Oracle.\nYou have access to the following context from the Knowledge Graph:\n%s\n\nAnswer the user's query based strictly on the context and STAMP safety constraints.\nIf the query reveals a violation, flag it as CRITICAL." context
            
        // Use default model from config
        this.CompleteAsync(query, systemPrompt = systemPrompt)

    // Specialized Method: Document Generator (Artifact Creator)
    member this.GenerateArtifactAsync(topic: string, context: string, template: string) = 
        let systemPrompt = 
            sprintf """You are the Indrajaal Documentation Generator.
            Your goal is to create a high-quality Markdown artifact based on the User's Topic.
            
            CONTEXT from Knowledge Base:
            %s
            
            REQUIRED FORMAT (Follow this template structure):
            %s
            
            Output ONLY the valid Markdown content. Include valid YAML Frontmatter at the top based on the Indrajaal Holonic Schema.
            """ context template
            
        // Use default model from config
        this.CompleteAsync(topic, systemPrompt = systemPrompt)