/// Graph HTTP Handlers - Graph data for Cytoscape.js visualization
module Cepaf.Smriti.Api.Handlers.GraphHandler

open System
open Microsoft.AspNetCore.Http
open Giraffe
open Cepaf.Smriti.Shared
open Cepaf.Smriti.Api.Data.KmsRepository
open Cepaf.Smriti.Api.Data.AnalyticsQuery

/// Convert GraphData to Cytoscape.js format
let toCytoscapeFormat (data: GraphData) =
    let nodes =
        data.Nodes
        |> List.map (fun n ->
            {| data = {|
                id = n.Id.ToString()
                label = n.Label
                entropy = n.Entropy
                cluster = n.Cluster
                level = n.Level.ToString()
                backlinkCount = n.BacklinkCount
                color = Entropy.toColor n.Entropy
            |} |}
        )

    let edges =
        data.Edges
        |> List.map (fun e ->
            {| data = {|
                id = $"{e.Source}-{e.Target}"
                source = e.Source.ToString()
                target = e.Target.ToString()
                linkType = e.LinkType.ToString()
                weight = e.Weight
            |} |}
        )

    {| nodes = nodes; edges = edges; generatedAt = data.GeneratedAt |}

/// Get full graph data for visualization
let getGraph (repo: IKmsRepository) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let! graphData = repo.GetGraphData() |> Async.StartAsTask
            let cytoscapeData = toCytoscapeFormat graphData
            return! json cytoscapeData next ctx
        }

/// Get graph data for a specific cluster
let getClusterGraph (repo: IKmsRepository) (clusterName: string) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let! graphData = repo.GetClusterGraph(clusterName) |> Async.StartAsTask
            let cytoscapeData = toCytoscapeFormat graphData
            return! json cytoscapeData next ctx
        }

/// Get list of all clusters
let getClusters (repo: IKmsRepository) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let! clusters = repo.GetClusters() |> Async.StartAsTask
            return! json clusters next ctx
        }

/// Get entropy metrics for dashboard
let getEntropyMetrics (repo: IKmsRepository) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let topN =
                ctx.TryGetQueryStringValue "top"
                |> Option.bind (fun s -> Int32.TryParse s |> function true, n -> Some n | _ -> None)
                |> Option.defaultValue 10

            let! metrics = repo.GetEntropyMetrics(topN) |> Async.StartAsTask
            return! json metrics next ctx
        }

/// Get mind map data for visualization
let getMindMap (analytics: IAnalyticsRepository) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let centralConcept = ctx.TryGetQueryStringValue "center"
            let! mindMap = analytics.GetMindMap(centralConcept) |> Async.StartAsTask
            return! json mindMap next ctx
        }

/// Get evolution timeline for a specific Zettel
let getEvolutionTimeline (analytics: IAnalyticsRepository) (id: Guid) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let days =
                ctx.TryGetQueryStringValue "days"
                |> Option.bind (fun s -> Int32.TryParse s |> function true, n -> Some n | _ -> None)
                |> Option.defaultValue 30

            let! timeline = analytics.GetEntropyTimeline(id, days) |> Async.StartAsTask
            let result =
                timeline
                |> List.map (fun (date, entropy) ->
                    {| date = date.ToString("yyyy-MM-dd"); entropy = entropy; color = Entropy.toColor entropy |}
                )
            return! json result next ctx
        }

/// Get recent evolution events
let getRecentEvolution (analytics: IAnalyticsRepository) : HttpHandler =
    fun (next: HttpFunc) (ctx: HttpContext) ->
        task {
            let limit =
                ctx.TryGetQueryStringValue "limit"
                |> Option.bind (fun s -> Int32.TryParse s |> function true, n -> Some n | _ -> None)
                |> Option.defaultValue 50

            let! events = analytics.GetRecentEvolution(limit) |> Async.StartAsTask
            return! json events next ctx
        }
