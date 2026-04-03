/// MCP HTTP Handlers - Model Context Protocol endpoints for AI agents
///
/// STAMP Constraints:
/// - SC-KMS-004: MCP endpoints for Claude/Gemini agent access
module Cepaf.Smriti.Api.Handlers.McpHandler

open System
open Microsoft.AspNetCore.Http
open Giraffe
open Cepaf.Smriti.Shared
open Cepaf.Smriti.Api.Data.KmsRepository
open Cepaf.Smriti.Api.Data.AnalyticsQuery

/// Truncate content for previews
let private truncate (maxLength: int) (s: string) =
    if s.Length <= maxLength then s
    else s.Substring(0, maxLength) + "..."

/// MCP: read_zettel - Get full Zettel context for AI reasoning
let readZettel (repo: IKmsRepository) (id: Guid) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let! zettelOpt = repo.GetZettel(id) |> Async.StartAsTask
            match zettelOpt with
            | None -> return! RequestErrors.NOT_FOUND "Zettel not found" next ctx
            | Some zettel ->
                let! backlinks = repo.GetBacklinks(id) |> Async.StartAsTask

                let response: McpZettelContext = {
                    Content = zettel.Content
                    Metadata = {
                        Id = zettel.Id
                        Title = zettel.Title
                        Tags = zettel.Tags
                        Entropy = zettel.Entropy
                        ModifiedAt = zettel.ModifiedAt
                    }
                    RelatedContext = backlinks |> List.map (fun (z: Zettel) -> z.Title)
                }

                return! json response next ctx
        }

/// MCP: search - Search Zettels for context retrieval
let mcpSearch (repo: IKmsRepository) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let query =
                ctx.TryGetQueryStringValue "q"
                |> Option.defaultValue ""

            if String.IsNullOrWhiteSpace(query) then
                return! RequestErrors.BAD_REQUEST "Query parameter 'q' is required" next ctx
            else
                let limit =
                    ctx.TryGetQueryStringValue "limit"
                    |> Option.bind (fun s -> Int32.TryParse s |> function true, n -> Some n | _ -> None)
                    |> Option.defaultValue 10
                    |> min 25  // Limit context size for agents

                let! results = repo.FullTextSearch(query, limit) |> Async.StartAsTask

                let response: McpSearchResult list =
                    results
                    |> List.map (fun (r: SearchResult) -> {
                        Title = r.Zettel.Title
                        ContentPreview = truncate 500 r.Zettel.Content
                        Score = r.Score
                        Id = r.Zettel.Id
                    })

                return! json response next ctx
        }

/// MCP: get_context - Get context for a topic (clusters related Zettels)
let getContext (repo: IKmsRepository) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let topic =
                ctx.TryGetQueryStringValue "topic"
                |> Option.defaultValue ""

            if String.IsNullOrWhiteSpace(topic) then
                return! RequestErrors.BAD_REQUEST "Topic parameter is required" next ctx
            else
                // Search for the topic
                let! searchResults = repo.FullTextSearch(topic, 5) |> Async.StartAsTask

                // Get related Zettels through backlinks
                let! relatedZettels =
                    searchResults
                    |> List.take (min 3 searchResults.Length)
                    |> List.map (fun (r: SearchResult) -> repo.GetBacklinks(r.Zettel.Id))
                    |> Async.Parallel
                    |> Async.StartAsTask

                let allRelated =
                    relatedZettels
                    |> Array.toList
                    |> List.concat
                    |> List.distinctBy (fun (z: Zettel) -> z.Id)
                    |> List.truncate 10

                let context = {|
                    topic = topic
                    primaryResults = searchResults |> List.map (fun (r: SearchResult) -> {
                        Title = r.Zettel.Title
                        ContentPreview = truncate 300 r.Zettel.Content
                        Score = r.Score
                        Id = r.Zettel.Id
                    })
                    relatedContext = allRelated |> List.map (fun (z: Zettel) -> {|
                        title = z.Title
                        preview = truncate 200 z.Content
                        entropy = z.Entropy
                        tags = z.Tags
                    |})
                |}

                return! json context next ctx
        }

/// MCP: get_source - Get source code for a holon
let getSource (analytics: IAnalyticsRepository) (id: Guid) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let! sourceOpt = analytics.GetSourceCodeInfo(id) |> Async.StartAsTask
            match sourceOpt with
            | None -> return! RequestErrors.NOT_FOUND "Source code not found" next ctx
            | Some source ->
                let response = {|
                    filePath = source.FilePath
                    language = source.Language
                    content = source.Content
                    lineRange =
                        match source.StartLine, source.EndLine with
                        | Some s, Some e -> Some {| start = s; ``end`` = e |}
                        | _ -> None
                    functions = source.Functions
                |}
                return! json response next ctx
        }

/// MCP: get_evolution - Get evolution history for understanding changes
let getEvolution (analytics: IAnalyticsRepository) (id: Guid) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let limit =
                ctx.TryGetQueryStringValue "limit"
                |> Option.bind (fun s -> Int32.TryParse s |> function true, n -> Some n | _ -> None)
                |> Option.defaultValue 20

            let! events = analytics.GetFeatureEvolution(id, limit) |> Async.StartAsTask

            let response =
                events
                |> List.map (fun (e: EvolutionEvent) -> {|
                    eventType = e.EventType
                    timestamp = e.Timestamp
                    entropyChange =
                        match e.OldEntropy, e.NewEntropy with
                        | Some o, Some n -> Some {| from = o; ``to`` = n |}
                        | _ -> None
                    details = e.Details
                |})

            return! json response next ctx
        }

/// MCP tool definition type
type McpToolDefinition = {
    name: string
    description: string
    parameters: obj
}

/// MCP: list_tools - List available MCP tools
let listTools : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        let tools = [
            {
                name = "read_zettel"
                description = "Read full Zettel content and metadata by ID"
                parameters = {| id = "Zettel UUID (required)" |} :> obj
            }
            {
                name = "search"
                description = "Search Zettels by query string"
                parameters = {| q = "Search query (required)"; limit = "Max results (optional, default 10)" |} :> obj
            }
            {
                name = "get_context"
                description = "Get related context for a topic"
                parameters = {| topic = "Topic to find context for (required)" |} :> obj
            }
            {
                name = "get_source"
                description = "Get source code associated with a holon"
                parameters = {| id = "Holon UUID (required)" |} :> obj
            }
            {
                name = "get_evolution"
                description = "Get evolution history for a holon"
                parameters = {| id = "Holon UUID (required)"; limit = "Max events (optional, default 20)" |} :> obj
            }
        ]

        json tools next ctx
