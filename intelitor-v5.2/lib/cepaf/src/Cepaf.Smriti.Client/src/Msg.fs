/// Z-KMS Client Messages - MVU Message Types
///
/// All messages that drive state updates in the application.
///
/// STAMP Constraints:
/// - SC-KMS-007: Type-safe routing
module Cepaf.Smriti.Client.Msg

open System
open Cepaf.Smriti.Client.Model

/// Application messages
type Msg =
    // Navigation
    | NavigateTo of Route
    | UrlChanged of Route

    // Graph operations
    | LoadGraph
    | GraphLoaded of GraphData
    | GraphLoadFailed of string
    | ChangeLayout of string
    | SetZoom of float
    | HighlightNode of Guid
    | ClearHighlights

    // Zettel operations
    | SelectZettel of Guid
    | ZettelLoaded of Zettel
    | ZettelLoadFailed of string
    | ClearSelectedZettel

    // Search operations
    | UpdateSearchQuery of string
    | PerformSearch of string
    | SearchCompleted of SearchResult list
    | SearchFailed of string
    | ClearSearch

    // Cluster operations
    | LoadClusters
    | ClustersLoaded of ClusterInfo list
    | ClustersLoadFailed of string
    | SelectCluster of string option

    // Batch operations
    | LoadZettels of Guid list
    | ZettelsLoaded of Zettel list

    // Error handling
    | DismissError
    | SetError of string

    // No-op (for subscriptions that don't need to update)
    | NoOp
