/// Z-KMS Client Model - Global Application State
///
/// MVU architecture state model for the Zettelkasten Knowledge Management System.
///
/// STAMP Constraints:
/// - SC-KMS-007: Type-safe routing (Elmish.Land)
module Cepaf.Smriti.Client.Model

open System
open Fable.Core

/// Route definition for the application
type Route =
    | Home
    | ZettelView of Guid
    | ClusterView of string
    | SearchResults of string
    | GraphExplorer
    | MindMap of string option

/// Zettel domain model (client-side)
type Zettel = {
    Id: Guid
    Title: string
    Content: string
    Tags: string list
    Entropy: float
    Level: string
    Cluster: string option
    BacklinkCount: int
    CreatedAt: DateTime
    ModifiedAt: DateTime
}

/// Graph node for visualization
type GraphNode = {
    Id: Guid
    Label: string
    Entropy: float
    Cluster: string option
    Level: string
    BacklinkCount: int
}

/// Graph edge (link between zettels)
type GraphLink = {
    Source: Guid
    Target: Guid
    LinkType: string
    Weight: float
}

/// Graph data for Cytoscape
type GraphData = {
    Nodes: GraphNode list
    Edges: GraphLink list
}

/// Search result
type SearchResult = {
    Zettel: Zettel
    Score: float
    Highlights: string list
}

/// Cluster information
type ClusterInfo = {
    Name: string
    ZettelCount: int
    AverageEntropy: float
    TopTags: string list
}

/// API loading state
type LoadingState<'T> =
    | NotStarted
    | Loading
    | Loaded of 'T
    | Failed of string

/// Application model (global state)
type Model = {
    // Routing
    CurrentRoute: Route

    // Data
    Zettels: Map<Guid, Zettel>
    GraphData: LoadingState<GraphData>
    SearchResults: LoadingState<SearchResult list>
    Clusters: LoadingState<ClusterInfo list>

    // UI State
    SelectedZettel: Zettel option
    SearchQuery: string
    SelectedCluster: string option

    // Graph view state
    GraphLayout: string  // "cose", "concentric", "circle", "grid"
    GraphZoom: float
    HighlightedNodes: Set<Guid>

    // Error handling
    LastError: string option
}

/// Initial model state
let init () : Model = {
    CurrentRoute = Home
    Zettels = Map.empty
    GraphData = NotStarted
    SearchResults = NotStarted
    Clusters = NotStarted
    SelectedZettel = None
    SearchQuery = ""
    SelectedCluster = None
    GraphLayout = "cose"
    GraphZoom = 1.0
    HighlightedNodes = Set.empty
    LastError = None
}

/// Entropy level classification
type EntropyLevel =
    | Fresh      // 0.0 - 0.2
    | Recent     // 0.2 - 0.4
    | Aging      // 0.4 - 0.6
    | Stale      // 0.6 - 0.8
    | Rotting    // 0.8 - 1.0

/// Get entropy level from value
let getEntropyLevel (entropy: float) : EntropyLevel =
    match entropy with
    | e when e < 0.2 -> Fresh
    | e when e < 0.4 -> Recent
    | e when e < 0.6 -> Aging
    | e when e < 0.8 -> Stale
    | _ -> Rotting

/// Get color for entropy level
let entropyToColor (entropy: float) : string =
    match getEntropyLevel entropy with
    | Fresh -> "#22c55e"    // Green
    | Recent -> "#84cc16"   // Lime
    | Aging -> "#eab308"    // Yellow
    | Stale -> "#f97316"    // Orange
    | Rotting -> "#ef4444"  // Red

/// Get label for entropy level
let entropyToLabel (entropy: float) : string =
    match getEntropyLevel entropy with
    | Fresh -> "Fresh"
    | Recent -> "Recent"
    | Aging -> "Aging"
    | Stale -> "Stale"
    | Rotting -> "Rotting"
