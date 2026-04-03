/// Zettel HTTP Handlers - CRUD operations for Zettels
module Cepaf.Smriti.Api.Handlers.ZettelHandler

open System
open Microsoft.AspNetCore.Http
open Giraffe
open Cepaf.Smriti.Shared
open Cepaf.Smriti.Api.Data.KmsRepository

/// Get single Zettel by ID
let getZettel (repo: IKmsRepository) (id: Guid) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let! zettel = repo.GetZettel(id) |> Async.StartAsTask
            match zettel with
            | Some z -> return! json z next ctx
            | None -> return! RequestErrors.NOT_FOUND "Zettel not found" next ctx
        }

/// Get paginated list of all Zettels
let getAllZettels (repo: IKmsRepository) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let page =
                ctx.TryGetQueryStringValue "page"
                |> Option.bind (fun s -> Int32.TryParse s |> function true, n -> Some n | _ -> None)
                |> Option.defaultValue 1

            let pageSize =
                ctx.TryGetQueryStringValue "pageSize"
                |> Option.bind (fun s -> Int32.TryParse s |> function true, n -> Some n | _ -> None)
                |> Option.defaultValue 20
                |> min 100  // Max 100 per page

            let! (zettels, total) = repo.GetAllZettels(page, pageSize) |> Async.StartAsTask

            let result: PagedResult<Zettel> = {
                Items = zettels
                Total = total
                Page = page
                PageSize = pageSize
                HasMore = page * pageSize < total
            }

            return! json result next ctx
        }

/// Get backlinks for a Zettel
let getBacklinks (repo: IKmsRepository) (id: Guid) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let! backlinks = repo.GetBacklinks(id) |> Async.StartAsTask
            return! json backlinks next ctx
        }

/// Get Zettel with full context (content, backlinks, related)
let getZettelContext (repo: IKmsRepository) (id: Guid) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let! zettelOpt = repo.GetZettel(id) |> Async.StartAsTask
            match zettelOpt with
            | None -> return! RequestErrors.NOT_FOUND "Zettel not found" next ctx
            | Some zettel ->
                let! backlinks = repo.GetBacklinks(id) |> Async.StartAsTask

                let context = {|
                    zettel = zettel
                    backlinks = backlinks
                    entropyColor = Entropy.toColor zettel.Entropy
                    entropyLabel = Entropy.toLabel zettel.Entropy
                |}

                return! json context next ctx
        }
