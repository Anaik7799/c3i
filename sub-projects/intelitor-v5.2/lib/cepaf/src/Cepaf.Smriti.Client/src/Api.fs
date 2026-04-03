/// Z-KMS Client API - HTTP Client for API Communication
///
/// Fetches data from the Z-KMS Giraffe API server.
///
/// STAMP Constraints:
/// - SC-KMS-001: Read-only access
module Cepaf.Smriti.Client.Api

open System
open Fable.Core
open Fable.SimpleJson
open Fetch
open Cepaf.Smriti.Client.Model

/// API base URL (configurable)
let mutable baseUrl = "http://localhost:5000"

/// Configure the API base URL
let configure (url: string) =
    baseUrl <- url

/// JSON parsing helpers
module Json =
    let inline parse<'T> (json: string) : 'T =
        Json.parseAs<'T> json

/// Fetch with error handling (inline for Fable type resolution)
let inline private fetchJson<'T> (url: string) : JS.Promise<Result<'T, string>> =
    promise {
        try
            let! response = fetch url []
            if response.Ok then
                let! text = response.text()
                let result : 'T = Json.parseAs<'T> text
                return Ok result
            else
                return Error $"HTTP {response.Status}: {response.StatusText}"
        with
        | ex -> return Error ex.Message
    }

/// Fetch with query parameters (inline for Fable type resolution)
let inline private fetchJsonWithParams<'T> (url: string) (queryParams: (string * string) list) : JS.Promise<Result<'T, string>> =
    let queryString =
        queryParams
        |> List.map (fun (k, v) -> $"{k}={JS.encodeURIComponent v}")
        |> String.concat "&"
    let fullUrl = if List.isEmpty queryParams then url else $"{url}?{queryString}"
    fetchJson<'T> fullUrl

// ============================================================================
// API Response Types (match server JSON)
// ============================================================================

type ApiZettel = {|
    id: string
    title: string
    content: string
    tags: string array
    entropy: float
    level: string
    cluster: string option
    backlinkCount: int
    createdAt: string
    modifiedAt: string
|}

type ApiGraphNode = {|
    id: string
    label: string
    entropy: float
    cluster: string option
    level: string
    backlinkCount: int
|}

type ApiGraphLink = {|
    source: string
    target: string
    linkType: string
    weight: float
|}

type ApiGraphData = {|
    nodes: ApiGraphNode array
    edges: ApiGraphLink array
|}

type ApiSearchResult = {|
    zettel: ApiZettel
    score: float
    highlights: string array
|}

type ApiClusterInfo = {|
    name: string
    zettelCount: int
    averageEntropy: float
    topTags: string array
|}

// ============================================================================
// Type Converters
// ============================================================================

let private parseGuid (s: string) : Guid =
    match Guid.TryParse(s) with
    | true, g -> g
    | false, _ -> Guid.Empty

let private parseDateTime (s: string) : DateTime =
    match DateTime.TryParse(s) with
    | true, d -> d
    | false, _ -> DateTime.MinValue

let private toZettel (api: ApiZettel) : Zettel = {
    Id = parseGuid api.id
    Title = api.title
    Content = api.content
    Tags = api.tags |> Array.toList
    Entropy = api.entropy
    Level = api.level
    Cluster = api.cluster
    BacklinkCount = api.backlinkCount
    CreatedAt = parseDateTime api.createdAt
    ModifiedAt = parseDateTime api.modifiedAt
}

let private toGraphNode (api: ApiGraphNode) : GraphNode = {
    Id = parseGuid api.id
    Label = api.label
    Entropy = api.entropy
    Cluster = api.cluster
    Level = api.level
    BacklinkCount = api.backlinkCount
}

let private toGraphLink (api: ApiGraphLink) : GraphLink = {
    Source = parseGuid api.source
    Target = parseGuid api.target
    LinkType = api.linkType
    Weight = api.weight
}

let private toGraphData (api: ApiGraphData) : GraphData = {
    Nodes = api.nodes |> Array.map toGraphNode |> Array.toList
    Edges = api.edges |> Array.map toGraphLink |> Array.toList
}

let private toSearchResult (api: ApiSearchResult) : SearchResult = {
    Zettel = toZettel api.zettel
    Score = api.score
    Highlights = api.highlights |> Array.toList
}

let private toClusterInfo (api: ApiClusterInfo) : ClusterInfo = {
    Name = api.name
    ZettelCount = api.zettelCount
    AverageEntropy = api.averageEntropy
    TopTags = api.topTags |> Array.toList
}

// ============================================================================
// Public API Functions
// ============================================================================

/// Get all zettels (paginated)
let getZettels (page: int) (pageSize: int) : JS.Promise<Result<Zettel list, string>> =
    let url = $"{baseUrl}/api/zettels"
    let queryParams = [ "page", string page; "pageSize", string pageSize ]
    promise {
        let! result = fetchJsonWithParams<ApiZettel array> url queryParams
        return result |> Result.map (Array.map toZettel >> Array.toList)
    }

/// Get a single zettel by ID
let getZettel (id: Guid) : JS.Promise<Result<Zettel, string>> =
    promise {
        let! result = fetchJson<ApiZettel> $"{baseUrl}/api/zettels/{id}"
        return result |> Result.map toZettel
    }

/// Get graph data for visualization
let getGraphData () : JS.Promise<Result<GraphData, string>> =
    promise {
        let! result = fetchJson<ApiGraphData> $"{baseUrl}/api/graph"
        return result |> Result.map toGraphData
    }

/// Get graph data for a specific cluster
let getClusterGraph (clusterName: string) : JS.Promise<Result<GraphData, string>> =
    promise {
        let! result = fetchJson<ApiGraphData> $"{baseUrl}/api/graph/cluster/{clusterName}"
        return result |> Result.map toGraphData
    }

/// Search zettels
let search (query: string) (limit: int) : JS.Promise<Result<SearchResult list, string>> =
    let url = $"{baseUrl}/api/search"
    let queryParams = [ "q", query; "limit", string limit ]
    promise {
        let! result = fetchJsonWithParams<ApiSearchResult array> url queryParams
        return result |> Result.map (Array.map toSearchResult >> Array.toList)
    }

/// Get all clusters
let getClusters () : JS.Promise<Result<ClusterInfo list, string>> =
    promise {
        let! result = fetchJson<ApiClusterInfo array> $"{baseUrl}/api/clusters"
        return result |> Result.map (Array.map toClusterInfo >> Array.toList)
    }

/// Get backlinks for a zettel
let getBacklinks (id: Guid) : JS.Promise<Result<Zettel list, string>> =
    promise {
        let! result = fetchJson<ApiZettel array> $"{baseUrl}/api/zettels/{id}/backlinks"
        return result |> Result.map (Array.map toZettel >> Array.toList)
    }

/// Get top rotting zettels (high entropy)
let getEntropyMetrics () : JS.Promise<Result<Zettel list, string>> =
    promise {
        let! result = fetchJson<ApiZettel array> $"{baseUrl}/api/metrics/entropy"
        return result |> Result.map (Array.map toZettel >> Array.toList)
    }
