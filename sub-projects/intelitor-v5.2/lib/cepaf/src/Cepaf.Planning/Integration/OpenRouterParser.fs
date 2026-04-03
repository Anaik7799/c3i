namespace Cepaf.Planning.Integration

open System
open System.Net.Http
open System.Net.Http.Json
open System.Text.Json
open System.Text.Json.Serialization
open Cepaf.Planning

/// OpenRouter AI-assisted task parser
/// Uses LLM to intelligently extract tasks from PROJECT_TODOLIST.md
/// SC-PLAN-070: AI-augmented parsing for complex markdown formats
module OpenRouterParser =

    // ═══════════════════════════════════════════════════════════════════════════
    // CONFIGURATION
    // ═══════════════════════════════════════════════════════════════════════════

    type OpenRouterConfig = {
        ApiKey: string
        Model: string
        BaseUrl: string
    }

    let loadConfig () =
        let apiKey = Environment.GetEnvironmentVariable("OPENROUTER_API_KEY")
        let model =
            match Environment.GetEnvironmentVariable("OPENROUTER_MODEL") with
            | null | "" -> "google/gemini-flash-1.5"  // Fast and cheap for parsing
            | m -> m
        {
            ApiKey = if String.IsNullOrEmpty(apiKey) then "" else apiKey
            Model = model
            BaseUrl = "https://openrouter.ai/api/v1"
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // API TYPES
    // ═══════════════════════════════════════════════════════════════════════════

    type Message = {
        [<JsonPropertyName("role")>] Role: string
        [<JsonPropertyName("content")>] Content: string
    }

    type CompletionRequest = {
        [<JsonPropertyName("model")>] Model: string
        [<JsonPropertyName("messages")>] Messages: Message list
        [<JsonPropertyName("temperature")>] Temperature: float
        [<JsonPropertyName("max_tokens")>] MaxTokens: int
    }

    type Choice = {
        [<JsonPropertyName("message")>] Message: Message
    }

    type CompletionResponse = {
        [<JsonPropertyName("choices")>] Choices: Choice list
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PARSED TASK JSON TYPE
    // ═══════════════════════════════════════════════════════════════════════════

    type ParsedTaskJson = {
        [<JsonPropertyName("id")>] Id: string
        [<JsonPropertyName("title")>] Title: string
        [<JsonPropertyName("status")>] Status: string
        [<JsonPropertyName("priority")>] Priority: string
        [<JsonPropertyName("parent_id")>] ParentId: string option
    }

    type ParsedTasksResponse = {
        [<JsonPropertyName("tasks")>] Tasks: ParsedTaskJson list
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // AI PARSING
    // ═══════════════════════════════════════════════════════════════════════════

    let private systemPrompt = """You are a task parser for the Indrajaal project management system.
Extract ALL tasks from the provided PROJECT_TODOLIST.md content.

TASK FORMAT RULES:
1. Tasks have IDs like "45.1.0.0.0" or "45.1.1.0.0" (hierarchical numbering)
2. Tasks marked with "- [x]" are COMPLETED
3. Tasks marked with "- [ ]" are PENDING
4. Sprint headers with "**Status**: completed" indicate all children are complete
5. Priority is extracted from context (P0=Critical, P1=High, P2=Medium, P3=Low, P4=Minimal)
6. Parent ID is the ID with one less level (e.g., 45.1.1.0.0's parent is 45.1.0.0.0)

OUTPUT FORMAT (JSON only, no markdown):
{
  "tasks": [
    {
      "id": "45.1.0.0.0",
      "title": "Scaffolding & Core Logic",
      "status": "completed",
      "priority": "P0",
      "parent_id": null
    },
    {
      "id": "45.1.1.0.0",
      "title": "Create Cepaf.Planning F# Project",
      "status": "completed",
      "priority": "P1",
      "parent_id": "45.1.0.0.0"
    }
  ]
}

Extract ALL tasks including subtasks. Be thorough."""

    let private parseWithOpenRouter (config: OpenRouterConfig) (content: string) : Async<Result<TaskItem list, string>> =
        async {
            if String.IsNullOrEmpty(config.ApiKey) then
                return Error "OPENROUTER_API_KEY not set"
            else
                try
                    use client = new HttpClient()
                    client.DefaultRequestHeaders.Add("Authorization", sprintf "Bearer %s" config.ApiKey)
                    client.DefaultRequestHeaders.Add("HTTP-Referer", "https://indrajaal.ai")
                    client.DefaultRequestHeaders.Add("X-Title", "Indrajaal Planning Parser")

                    let truncatedContent =
                        if content.Length > 15000 then content.Substring(0, 15000) + "\n...[truncated]"
                        else content

                    let request = {
                        Model = config.Model
                        Messages = [
                            { Role = "system"; Content = systemPrompt }
                            { Role = "user"; Content = sprintf "Parse this PROJECT_TODOLIST.md:\n\n%s" truncatedContent }
                        ]
                        Temperature = 0.1
                        MaxTokens = 4000
                    }

                    let! response = client.PostAsJsonAsync(config.BaseUrl + "/chat/completions", request) |> Async.AwaitTask

                    if response.IsSuccessStatusCode then
                        let! result = response.Content.ReadFromJsonAsync<CompletionResponse>() |> Async.AwaitTask
                        match result.Choices with
                        | head :: _ ->
                            let jsonContent = head.Message.Content.Trim()
                            // Clean up potential markdown code blocks
                            let cleanJson =
                                jsonContent
                                    .Replace("```json", "")
                                    .Replace("```", "")
                                    .Trim()

                            try
                                let options = JsonSerializerOptions()
                                options.PropertyNameCaseInsensitive <- true

                                let parsed = JsonSerializer.Deserialize<ParsedTasksResponse>(cleanJson, options)

                                let tasks =
                                    parsed.Tasks
                                    |> List.map (fun t ->
                                        {
                                            Id = t.Id
                                            Title = t.Title
                                            Status = DomainHelpers.parseStatus t.Status
                                            Priority = DomainHelpers.parsePriority t.Priority
                                            ParentId = t.ParentId
                                            Owner = None
                                            Created = DateTime.UtcNow
                                            RawLines = []
                                        }
                                    )

                                return Ok tasks
                            with
                            | ex -> return Error (sprintf "JSON parse error: %s\nResponse: %s" ex.Message cleanJson)
                        | [] -> return Error "No response from OpenRouter"
                    else
                        let! errorBody = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                        return Error (sprintf "API Error %d: %s" (int response.StatusCode) errorBody)
                with
                | ex -> return Error (sprintf "Network error: %s" ex.Message)
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // FALLBACK REGEX PARSER (Enhanced)
    // ═══════════════════════════════════════════════════════════════════════════

    open System.Text.RegularExpressions

    let private checkboxTaskRegex = Regex(@"^-\s+\[([ xX])\]\s+([\d\.]+)\s+-\s+(.+)$", RegexOptions.Compiled)
    let private headerTaskRegex = Regex(@"^#+\s+([\d\.]+)\s+-\s+(.+)", RegexOptions.Compiled)
    let private sprintStatusRegex = Regex(@"\*\*Status\*\*:\s*(\w+)", RegexOptions.Compiled ||| RegexOptions.IgnoreCase)
    let private priorityRegex = Regex(@"\*\*Priority\*\*:\s*(P\d)", RegexOptions.Compiled ||| RegexOptions.IgnoreCase)

    let private parseWithRegex (content: string) : TaskItem list =
        let lines = content.Split([|'\n'|])
        let mutable tasks = []
        let mutable currentSprintStatus = "pending"
        let mutable currentPriority = "P2"

        for line in lines do
            // Check for sprint status
            let sprintMatch = sprintStatusRegex.Match(line)
            if sprintMatch.Success then
                currentSprintStatus <- sprintMatch.Groups.[1].Value.ToLower()

            // Check for priority
            let priMatch = priorityRegex.Match(line)
            if priMatch.Success then
                currentPriority <- priMatch.Groups.[1].Value.ToUpper()

            // Check for checkbox tasks: - [x] 45.1.1.0.0 - Title
            let checkboxMatch = checkboxTaskRegex.Match(line)
            if checkboxMatch.Success then
                let isCompleted = checkboxMatch.Groups.[1].Value.ToUpper() = "X"
                let id = checkboxMatch.Groups.[2].Value.Trim()
                let title = checkboxMatch.Groups.[3].Value.Trim()
                let parentId =
                    let parts = id.Split('.')
                    if parts.Length > 2 then
                        let parentParts = parts |> Array.take (parts.Length - 1)
                        Some (String.Join(".", parentParts) + ".0")
                    else None

                let task = {
                    Id = id
                    Title = title
                    Status = if isCompleted then Completed else Pending
                    Priority = DomainHelpers.parsePriority currentPriority
                    ParentId = parentId
                    Owner = None
                    Created = DateTime.UtcNow
                    RawLines = [line]
                }
                tasks <- task :: tasks

            // Check for header tasks: ### 45.1.0.0.0 - Title
            let headerMatch = headerTaskRegex.Match(line)
            if headerMatch.Success && not checkboxMatch.Success then
                let id = headerMatch.Groups.[1].Value.Trim()
                let title = headerMatch.Groups.[2].Value.Trim()
                let status =
                    if currentSprintStatus = "completed" then Completed
                    else Pending

                let task = {
                    Id = id
                    Title = title
                    Status = status
                    Priority = DomainHelpers.parsePriority currentPriority
                    ParentId = None
                    Owner = None
                    Created = DateTime.UtcNow
                    RawLines = [line]
                }
                tasks <- task :: tasks

        tasks |> List.rev

    // ═══════════════════════════════════════════════════════════════════════════
    // PUBLIC API
    // ═══════════════════════════════════════════════════════════════════════════

    /// Parse tasks using AI (OpenRouter) with regex fallback
    let parseAsync (content: string) : Async<TaskItem list> =
        async {
            let config = loadConfig()

            if String.IsNullOrEmpty(config.ApiKey) then
                // Fallback to enhanced regex parser
                printfn "[Parser] No OPENROUTER_API_KEY, using regex fallback"
                return parseWithRegex content
            else
                printfn "[Parser] Using OpenRouter AI (%s)" config.Model
                let! result = parseWithOpenRouter config content
                match result with
                | Ok tasks ->
                    printfn "[Parser] AI extracted %d tasks" tasks.Length
                    return tasks
                | Error err ->
                    printfn "[Parser] AI error: %s, falling back to regex" err
                    return parseWithRegex content
        }

    /// Parse tasks synchronously (for CLI)
    let parse (content: string) : TaskItem list =
        parseAsync content |> Async.RunSynchronously

    /// Parse from file path
    let parseFile (filePath: string) : TaskItem list =
        if System.IO.File.Exists(filePath) then
            let content = System.IO.File.ReadAllText(filePath)
            parse content
        else
            printfn "[Parser] File not found: %s" filePath
            []
