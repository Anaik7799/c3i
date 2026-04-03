/// Z-KMS Client Router - URL Routing
///
/// Type-safe URL parsing and generation for the SPA.
///
/// STAMP Constraints:
/// - SC-KMS-007: Type-safe routing (Elmish.Land)
module Cepaf.Smriti.Client.Router

open System
open Feliz.Router
open Cepaf.Smriti.Client.Model

/// Parse URL segments into a Route
let parseUrl (segments: string list) : Route =
    match segments with
    | [] -> Home
    | [ "" ] -> Home
    | [ "graph" ] -> GraphExplorer
    | [ "z"; id ] ->
        match Guid.TryParse(id) with
        | true, guid -> ZettelView guid
        | false, _ -> Home
    | [ "cluster"; name ] -> ClusterView name
    | [ "search" ] -> SearchResults ""
    | [ "search"; query ] -> SearchResults query
    | [ "mindmap" ] -> MindMap None
    | [ "mindmap"; concept ] -> MindMap (Some concept)
    | _ -> Home

/// Generate URL segments from a Route
let toUrl (route: Route) : string list =
    match route with
    | Home -> []
    | GraphExplorer -> [ "graph" ]
    | ZettelView id -> [ "z"; string id ]
    | ClusterView name -> [ "cluster"; name ]
    | SearchResults query ->
        if String.IsNullOrEmpty(query) then [ "search" ]
        else [ "search"; query ]
    | MindMap conceptOpt ->
        match conceptOpt with
        | None -> [ "mindmap" ]
        | Some concept -> [ "mindmap"; concept ]

/// Generate a clickable URL path string
let toPath (route: Route) : string =
    let segments = toUrl route
    if List.isEmpty segments then "/"
    else "/" + String.concat "/" segments

/// Navigate to a route (for use with Router.navigate)
let navigateTo (route: Route) =
    Router.navigate (toUrl route |> List.toArray)

/// Current route from browser URL
let currentRoute () : Route =
    Router.currentUrl() |> parseUrl

/// Route title for browser tab
let routeTitle (route: Route) : string =
    match route with
    | Home -> "Z-KMS - Knowledge Graph"
    | GraphExplorer -> "Graph Explorer - Z-KMS"
    | ZettelView _ -> "Zettel View - Z-KMS"
    | ClusterView name -> $"Cluster: {name} - Z-KMS"
    | SearchResults query ->
        if String.IsNullOrEmpty(query) then "Search - Z-KMS"
        else $"Search: {query} - Z-KMS"
    | MindMap conceptOpt ->
        match conceptOpt with
        | None -> "Mind Map - Z-KMS"
        | Some concept -> $"Mind Map: {concept} - Z-KMS"

/// Route breadcrumbs for navigation
let breadcrumbs (route: Route) : (string * Route option) list =
    let home = ("Home", Some Home)
    match route with
    | Home -> [ home ]
    | GraphExplorer -> [ home; ("Graph Explorer", None) ]
    | ZettelView _ -> [ home; ("Zettel", None) ]
    | ClusterView name -> [ home; ("Clusters", Some Home); (name, None) ]
    | SearchResults _ -> [ home; ("Search", None) ]
    | MindMap _ -> [ home; ("Mind Map", None) ]
