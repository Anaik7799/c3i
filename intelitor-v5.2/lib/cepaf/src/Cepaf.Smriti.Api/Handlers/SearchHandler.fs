/// Search HTTP Handlers - Full-text and vector search
module Cepaf.Smriti.Api.Handlers.SearchHandler

open System
open Microsoft.AspNetCore.Http
open Giraffe
open Cepaf.Smriti.Shared
open Cepaf.Smriti.Api.Data.KmsRepository

/// Full-text search handler
let search (repo: IKmsRepository) : HttpHandler =
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
                    |> Option.defaultValue 20
                    |> min 100

                let! results = repo.FullTextSearch(query, limit) |> Async.StartAsTask
                return! json results next ctx
        }

/// Vector similarity search handler
let vectorSearch (repo: IKmsRepository) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let! request = ctx.BindJsonAsync<VectorSearchRequest>()

            if String.IsNullOrWhiteSpace(request.Query) then
                return! RequestErrors.BAD_REQUEST "Query is required" next ctx
            else
                // For now, fall back to FTS - vector search requires embedding service
                let! results = repo.FullTextSearch(request.Query, request.Limit) |> Async.StartAsTask

                // Filter by threshold (simulating vector similarity)
                let filtered =
                    results
                    |> List.filter (fun r -> r.Score >= request.Threshold)

                // Filter by tags if provided
                let tagFiltered =
                    match request.Tags with
                    | None -> filtered
                    | Some tags ->
                        filtered
                        |> List.filter (fun r ->
                            tags |> List.exists (fun t -> r.Zettel.Tags |> List.contains t)
                        )

                return! json tagFiltered next ctx
        }

/// Search suggestions (autocomplete)
let suggestions (repo: IKmsRepository) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let prefix =
                ctx.TryGetQueryStringValue "prefix"
                |> Option.defaultValue ""

            if String.IsNullOrWhiteSpace(prefix) || prefix.Length < 2 then
                return! json [] next ctx
            else
                // Use FTS with prefix query
                let! results = repo.FullTextSearch($"{prefix}*", 10) |> Async.StartAsTask

                let suggestions =
                    results
                    |> List.map (fun r -> {| id = r.Zettel.Id; title = r.Zettel.Title; tags = r.Zettel.Tags |})

                return! json suggestions next ctx
        }

/// Get all unique tags for filtering
let getTags (repo: IKmsRepository) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let! (zettels, _) = repo.GetAllZettels(1, 1000) |> Async.StartAsTask

            let tags =
                zettels
                |> List.collect (fun z -> z.Tags)
                |> List.distinct
                |> List.sort

            return! json tags next ctx
        }
