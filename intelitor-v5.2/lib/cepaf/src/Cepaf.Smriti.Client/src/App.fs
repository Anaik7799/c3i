/// Z-KMS Client App - Root Application Component
///
/// Main MVU update loop and view rendering.
///
/// STAMP Constraints:
/// - SC-KMS-007: Type-safe routing (Elmish.Land)
module Cepaf.Smriti.Client.App

open System
open Elmish
open Feliz
open Feliz.Router
open Cepaf.Smriti.Client.Model
open Cepaf.Smriti.Client.Msg
open Cepaf.Smriti.Client.Router
open Cepaf.Smriti.Client.Api
open Cepaf.Smriti.Client.Components

/// Command to fetch graph data
let loadGraphCmd : Cmd<Msg> =
    Cmd.OfPromise.either
        getGraphData
        ()
        (function
            | Ok data -> GraphLoaded data
            | Error err -> GraphLoadFailed err)
        (fun ex -> GraphLoadFailed ex.Message)

/// Command to fetch a zettel by ID
let loadZettelCmd (id: Guid) : Cmd<Msg> =
    Cmd.OfPromise.either
        getZettel
        id
        (function
            | Ok zettel -> ZettelLoaded zettel
            | Error err -> ZettelLoadFailed err)
        (fun ex -> ZettelLoadFailed ex.Message)

/// Command to search
let searchCmd (query: string) : Cmd<Msg> =
    Cmd.OfPromise.either
        (fun q -> search q 10)
        query
        (function
            | Ok results -> SearchCompleted results
            | Error err -> SearchFailed err)
        (fun ex -> SearchFailed ex.Message)

/// Command to load clusters
let loadClustersCmd : Cmd<Msg> =
    Cmd.OfPromise.either
        getClusters
        ()
        (function
            | Ok clusters -> ClustersLoaded clusters
            | Error err -> ClustersLoadFailed err)
        (fun ex -> ClustersLoadFailed ex.Message)

/// Initialize the application
let init () : Model * Cmd<Msg> =
    let initialRoute = currentRoute()
    let model = { Model.init() with CurrentRoute = initialRoute }

    let cmd =
        match initialRoute with
        | GraphExplorer -> loadGraphCmd
        | ZettelView id -> loadZettelCmd id
        | _ -> Cmd.none

    model, cmd

/// Update function (MVU core)
let update (msg: Msg) (model: Model) : Model * Cmd<Msg> =
    match msg with
    // Navigation
    | NavigateTo route ->
        navigateTo route
        model, Cmd.none

    | UrlChanged route ->
        let cmd =
            match route with
            | GraphExplorer when model.GraphData = NotStarted -> loadGraphCmd
            | ZettelView id -> loadZettelCmd id
            | _ -> Cmd.none
        { model with CurrentRoute = route }, cmd

    // Graph operations
    | LoadGraph ->
        { model with GraphData = Loading }, loadGraphCmd

    | GraphLoaded data ->
        { model with GraphData = Loaded data }, Cmd.none

    | GraphLoadFailed error ->
        { model with GraphData = Failed error; LastError = Some error }, Cmd.none

    | ChangeLayout layout ->
        { model with GraphLayout = layout }, Cmd.none

    | SetZoom zoom ->
        { model with GraphZoom = zoom }, Cmd.none

    | HighlightNode id ->
        { model with HighlightedNodes = Set.add id model.HighlightedNodes }, Cmd.none

    | ClearHighlights ->
        { model with HighlightedNodes = Set.empty }, Cmd.none

    // Zettel operations
    | SelectZettel id ->
        navigateTo (ZettelView id)
        model, loadZettelCmd id

    | ZettelLoaded zettel ->
        let zettels = Map.add zettel.Id zettel model.Zettels
        { model with
            Zettels = zettels
            SelectedZettel = Some zettel }, Cmd.none

    | ZettelLoadFailed error ->
        { model with LastError = Some error }, Cmd.none

    | ClearSelectedZettel ->
        { model with SelectedZettel = None }, Cmd.none

    // Search operations
    | UpdateSearchQuery query ->
        { model with SearchQuery = query }, Cmd.none

    | PerformSearch query ->
        if String.IsNullOrWhiteSpace(query) then
            { model with SearchResults = NotStarted }, Cmd.none
        else
            { model with SearchResults = Loading }, searchCmd query

    | SearchCompleted results ->
        { model with SearchResults = Loaded results }, Cmd.none

    | SearchFailed error ->
        { model with SearchResults = Failed error; LastError = Some error }, Cmd.none

    | ClearSearch ->
        { model with SearchQuery = ""; SearchResults = NotStarted }, Cmd.none

    // Cluster operations
    | LoadClusters ->
        { model with Clusters = Loading }, loadClustersCmd

    | ClustersLoaded clusters ->
        { model with Clusters = Loaded clusters }, Cmd.none

    | ClustersLoadFailed error ->
        { model with Clusters = Failed error; LastError = Some error }, Cmd.none

    | SelectCluster cluster ->
        { model with SelectedCluster = cluster }, Cmd.none

    // Batch operations
    | LoadZettels ids ->
        // Would batch load multiple zettels
        model, Cmd.none

    | ZettelsLoaded zettels ->
        let newZettels =
            zettels
            |> List.fold (fun acc z -> Map.add z.Id z acc) model.Zettels
        { model with Zettels = newZettels }, Cmd.none

    // Error handling
    | DismissError ->
        { model with LastError = None }, Cmd.none

    | SetError error ->
        { model with LastError = Some error }, Cmd.none

    | NoOp ->
        model, Cmd.none

/// Styles for the app
module Styles =
    let app = [
        style.minHeight (length.vh 100)
        style.backgroundColor "#f3f4f6"
        style.fontFamily "system-ui, -apple-system, sans-serif"
    ]

    let header = [
        style.backgroundColor "white"
        style.borderBottom (1, borderStyle.solid, "#e5e7eb")
        style.padding (length.rem 1, length.rem 1.5)
    ]

    let headerContent = [
        style.display.flex
        style.alignItems.center
        style.justifyContent.spaceBetween
        style.maxWidth (length.rem 80)
        style.margin (length.rem 0, length.auto)
    ]

    let logo = [
        style.display.flex
        style.alignItems.center
        style.gap (length.rem 0.5)
        style.fontWeight.bold
        style.fontSize (length.rem 1.25)
        style.color "#1f2937"
        style.textDecoration.none
    ]

    let nav = [
        style.display.flex
        style.alignItems.center
        style.gap (length.rem 1)
    ]

    let navLink (active: bool) = [
        style.padding (length.rem 0.5, length.rem 0.75)
        style.borderRadius (length.rem 0.375)
        style.color (if active then "#3b82f6" else "#4b5563")
        style.backgroundColor (if active then "#eff6ff" else "transparent")
        style.textDecoration.none
        style.fontSize (length.rem 0.875)
        style.fontWeight 500
        style.cursor.pointer
        style.custom ("transition", "all 0.15s")
    ]

    let main = [
        style.maxWidth (length.rem 80)
        style.margin (length.rem 0, length.auto)
        style.padding (length.rem 1.5)
    ]

    let errorToast = [
        style.position.fixedRelativeToWindow
        style.bottom (length.rem 1)
        style.right (length.rem 1)
        style.padding (length.rem 1)
        style.backgroundColor "#fef2f2"
        style.border (1, borderStyle.solid, "#fecaca")
        style.borderRadius (length.rem 0.375)
        style.color "#b91c1c"
        style.display.flex
        style.alignItems.center
        style.gap (length.rem 0.75)
        style.maxWidth (length.rem 24)
        style.custom ("boxShadow", "0 10px 15px -3px rgba(0, 0, 0, 0.1)")
    ]

/// Navigation link component
[<ReactComponent>]
let NavLink (route: Route) (label: string) (currentRoute: Route) (dispatch: Msg -> unit) =
    let isActive =
        match route, currentRoute with
        | Home, Home -> true
        | GraphExplorer, GraphExplorer -> true
        | SearchResults _, SearchResults _ -> true
        | _ -> false

    Html.a [
        prop.style (Styles.navLink isActive)
        prop.href (toPath route)
        prop.onClick (fun e ->
            e.preventDefault()
            dispatch (NavigateTo route)
        )
        prop.text label
    ]

/// Error toast component
[<ReactComponent>]
let ErrorToast (error: string) (dispatch: Msg -> unit) =
    Html.div [
        prop.style Styles.errorToast
        prop.children [
            Html.span [ prop.text "⚠️" ]
            Html.span [ prop.text error ]
            Html.button [
                prop.style [
                    style.custom ("border", "none")
                    style.backgroundColor.transparent
                    style.cursor.pointer
                    style.padding 0
                    style.color "#b91c1c"
                ]
                prop.onClick (fun _ -> dispatch DismissError)
                prop.text "✕"
            ]
        ]
    ]

/// Header component
[<ReactComponent>]
let Header (model: Model) (dispatch: Msg -> unit) =
    Html.header [
        prop.style Styles.header
        prop.children [
            Html.div [
                prop.style Styles.headerContent
                prop.children [
                    // Logo
                    Html.a [
                        prop.style Styles.logo
                        prop.href "/"
                        prop.onClick (fun e ->
                            e.preventDefault()
                            dispatch (NavigateTo Home)
                        )
                        prop.children [
                            Html.span [ prop.text "🧠" ]
                            Html.span [ prop.text "Z-KMS" ]
                        ]
                    ]

                    // Search bar
                    Html.div [
                        prop.style [ style.flexGrow 1; style.maxWidth (length.rem 24); style.margin (length.rem 0, length.rem 2) ]
                        prop.children [
                            SearchBar.SearchBar model.SearchQuery model.SearchResults dispatch
                        ]
                    ]

                    // Navigation
                    Html.nav [
                        prop.style Styles.nav
                        prop.children [
                            NavLink Home "Home" model.CurrentRoute dispatch
                            NavLink GraphExplorer "Graph" model.CurrentRoute dispatch
                            NavLink (SearchResults "") "Search" model.CurrentRoute dispatch
                        ]
                    ]
                ]
            ]
        ]
    ]

/// Page content based on route
[<ReactComponent>]
let PageContent (model: Model) (dispatch: Msg -> unit) =
    match model.CurrentRoute with
    | Home ->
        Html.div [
            Html.h1 [
                prop.style [
                    style.fontSize (length.rem 2)
                    style.fontWeight.bold
                    style.color "#1f2937"
                    style.marginBottom (length.rem 1.5)
                ]
                prop.text "Welcome to Z-KMS"
            ]
            Html.p [
                prop.style [
                    style.color "#4b5563"
                    style.marginBottom (length.rem 2)
                    style.fontSize (length.rem 1.125)
                ]
                prop.text "Your Zettelkasten Knowledge Management System"
            ]

            // Quick actions
            Html.div [
                prop.style [
                    style.display.grid
                    style.custom ("gridTemplateColumns", "repeat(auto-fit, minmax(250px, 1fr))")
                    style.gap (length.rem 1)
                ]
                prop.children [
                    Html.div [
                        prop.style [
                            style.padding (length.rem 1.5)
                            style.backgroundColor "white"
                            style.borderRadius (length.rem 0.5)
                            style.border (1, borderStyle.solid, "#e5e7eb")
                            style.cursor.pointer
                        ]
                        prop.onClick (fun _ -> dispatch (NavigateTo GraphExplorer))
                        prop.children [
                            Html.div [
                                prop.style [ style.fontSize (length.rem 2); style.marginBottom (length.rem 0.5) ]
                                prop.text "🔗"
                            ]
                            Html.h2 [
                                prop.style [ style.fontWeight 600; style.marginBottom (length.rem 0.25) ]
                                prop.text "Explore Graph"
                            ]
                            Html.p [
                                prop.style [ style.fontSize (length.rem 0.875); style.color "#6b7280" ]
                                prop.text "Visualize the knowledge graph"
                            ]
                        ]
                    ]
                    Html.div [
                        prop.style [
                            style.padding (length.rem 1.5)
                            style.backgroundColor "white"
                            style.borderRadius (length.rem 0.5)
                            style.border (1, borderStyle.solid, "#e5e7eb")
                            style.cursor.pointer
                        ]
                        prop.onClick (fun _ -> dispatch (NavigateTo (SearchResults "")))
                        prop.children [
                            Html.div [
                                prop.style [ style.fontSize (length.rem 2); style.marginBottom (length.rem 0.5) ]
                                prop.text "🔍"
                            ]
                            Html.h2 [
                                prop.style [ style.fontWeight 600; style.marginBottom (length.rem 0.25) ]
                                prop.text "Search"
                            ]
                            Html.p [
                                prop.style [ style.fontSize (length.rem 0.875); style.color "#6b7280" ]
                                prop.text "Find zettels by content"
                            ]
                        ]
                    ]
                ]
            ]
        ]

    | GraphExplorer ->
        Html.div [
            Html.h1 [
                prop.style [
                    style.fontSize (length.rem 1.5)
                    style.fontWeight.bold
                    style.color "#1f2937"
                    style.marginBottom (length.rem 1)
                ]
                prop.text "Knowledge Graph"
            ]
            GraphView.GraphViewWithState model.GraphData model.GraphLayout dispatch
        ]

    | ZettelView id ->
        match model.SelectedZettel with
        | Some zettel ->
            ZettelView.Detail zettel [] dispatch
        | None ->
            Html.div [
                prop.style [ style.textAlign.center; style.padding (length.rem 4) ]
                prop.children [
                    Html.p [ prop.text "Loading zettel..." ]
                ]
            ]

    | ClusterView name ->
        Html.div [
            Html.h1 [
                prop.style [
                    style.fontSize (length.rem 1.5)
                    style.fontWeight.bold
                    style.marginBottom (length.rem 1)
                ]
                prop.text $"Cluster: {name}"
            ]
            Html.p [
                prop.style [ style.color "#6b7280" ]
                prop.text "Cluster view coming soon..."
            ]
        ]

    | SearchResults query ->
        Html.div [
            Html.h1 [
                prop.style [
                    style.fontSize (length.rem 1.5)
                    style.fontWeight.bold
                    style.marginBottom (length.rem 1)
                ]
                prop.text (if String.IsNullOrEmpty query then "Search" else $"Results for \"{query}\"")
            ]
            match model.SearchResults with
            | NotStarted ->
                Html.p [
                    prop.style [ style.color "#6b7280" ]
                    prop.text "Enter a search query to find zettels"
                ]
            | Loading ->
                Html.p [ prop.text "Searching..." ]
            | Loaded results ->
                if List.isEmpty results then
                    Html.p [
                        prop.style [ style.color "#6b7280" ]
                        prop.text "No results found"
                    ]
                else
                    Html.div [
                        prop.style [
                            style.display.grid
                            style.gap (length.rem 1)
                        ]
                        prop.children [
                            for result in results do
                                ZettelView.Card result.Zettel (fun () -> dispatch (SelectZettel result.Zettel.Id))
                        ]
                    ]
            | Failed error ->
                Html.p [
                    prop.style [ style.color "#ef4444" ]
                    prop.text $"Error: {error}"
                ]
        ]

    | MindMap conceptOpt ->
        Html.div [
            Html.h1 [
                prop.style [
                    style.fontSize (length.rem 1.5)
                    style.fontWeight.bold
                    style.marginBottom (length.rem 1)
                ]
                prop.text (
                    match conceptOpt with
                    | None -> "Mind Map"
                    | Some c -> $"Mind Map: {c}"
                )
            ]
            Html.p [
                prop.style [ style.color "#6b7280" ]
                prop.text "Mind map view coming soon..."
            ]
        ]

/// Main view function
let view (model: Model) (dispatch: Msg -> unit) =
    React.router [
        router.onUrlChanged (parseUrl >> UrlChanged >> dispatch)
        router.children [
            Html.div [
                prop.style Styles.app
                prop.children [
                    Header model dispatch
                    Html.main [
                        prop.style Styles.main
                        prop.children [
                            PageContent model dispatch
                        ]
                    ]

                    // Error toast
                    match model.LastError with
                    | Some error -> ErrorToast error dispatch
                    | None -> Html.none
                ]
            ]
        ]
    ]
