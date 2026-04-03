namespace Cepaf.Smriti.Client.Components

/// <summary>
/// Graph visualization component using Cytoscape.js.
///
/// ## WHAT
/// Interactive knowledge graph with force-directed layout and entropy colors.
///
/// ## WHY
/// Visual exploration of zettel connections reveals hidden patterns.
///
/// ## CONSTRAINTS
/// - SC-KMS-005: Cytoscape.js graph visualization required
/// - SC-PRF-050: Graph rendering < 50ms for < 1000 nodes
/// </summary>
module GraphView

open System
open Feliz
open Browser.Types
open Cepaf.Smriti.Shared
open Cepaf.Smriti.Client
open Cepaf.Smriti.Client.Bindings

/// <summary>
/// Convert GraphData to Cytoscape elements format.
/// </summary>
let private graphDataToElements (graphData: GraphData) : obj =
    let nodes =
        graphData.Nodes
        |> List.map (fun node ->
            {|
                data = {|
                    id = node.Id.ToString()
                    label = node.Label
                    entropy = node.Entropy
                    cluster = node.Cluster |> Option.defaultValue ""
                |}
            |}
        )

    let edges =
        graphData.Edges
        |> List.map (fun edge ->
            {|
                data = {|
                    id = sprintf "%s-%s" (edge.Source.ToString()) (edge.Target.ToString())
                    source = edge.Source.ToString()
                    target = edge.Target.ToString()
                    weight = edge.Weight
                    linkType = edge.LinkType.ToString()
                |}
            |}
        )

    [|
        yield! nodes |> List.toArray
        yield! edges |> List.toArray
    |]

/// <summary>
/// Cytoscape style configuration.
/// </summary>
let private graphStyle : obj =
    [|
        // Node style
        {|
            selector = "node"
            style = {|
                label = "data(label)"
                width = 40
                height = 40
                backgroundColor =
                    "mapData(entropy, 0, 1, #22c55e, #ef4444)"
                color = "#ffffff"
                fontSize = 12
                textValign = "center"
                textHalign = "center"
                borderWidth = 2
                borderColor = "#ffffff"
            |}
        |}

        // Edge style
        {|
            selector = "edge"
            style = {|
                width = "mapData(weight, 0, 1, 1, 5)"
                lineColor = "#d1d5db"
                targetArrowColor = "#d1d5db"
                targetArrowShape = "triangle"
                curveStyle = "bezier"
            |}
        |}

        // Selected node
        {|
            selector = "node:selected"
            style = {|
                borderColor = "#3b82f6"
                borderWidth = 4
            |}
        |}
    |]

/// <summary>
/// Initialize Cytoscape instance.
/// </summary>
let private initCytoscape
    (container: HTMLElement)
    (graphData: GraphData)
    (dispatch: Msg.Msg -> unit) : Cytoscape.Cytoscape =

    let elements = graphDataToElements graphData
    let cy = Cytoscape.create container elements graphStyle Cytoscape.Layouts.cose

    // Register click handler
    cy.on(Cytoscape.Events.Tap, fun evt ->
        if evt.target.isNode() then
            let nodeId = evt.target.id()
            match Guid.TryParse(nodeId) with
            | true, guid -> dispatch (Msg.SelectZettel guid)
            | false, _ -> ()
    )

    // Register hover handler for tooltips
    cy.on(Cytoscape.Events.MouseOver, fun evt ->
        if evt.target.isNode() then
            let entropy = evt.target.data("entropy") |> unbox<float>
            let label = evt.target.data("label") |> unbox<string>
            // TODO: Show tooltip with zettel info
            ()
    )

    cy

/// <summary>
/// Render graph view component.
/// </summary>
let render (graphData: GraphData option) (dispatch: Msg.Msg -> unit) =
    let cyRef = React.useRef<Cytoscape.Cytoscape option>(None)

    Html.div [
        prop.className "graph-view"
        prop.style [
            style.width (length.percent 100)
            style.height (length.vh 80)
            style.border (1, borderStyle.solid, "#e5e7eb")
            style.borderRadius 8
            style.position.relative
        ]
        prop.children [
            // Graph container
            Html.div [
                prop.id "cy-container"
                prop.style [
                    style.width (length.percent 100)
                    style.height (length.percent 100)
                ]
                prop.ref (fun (element: HTMLElement) ->
                    if not (isNull element) && graphData.IsSome then
                        // Initialize Cytoscape if not already done
                        match cyRef.current with
                        | Some _ -> () // Already initialized
                        | None ->
                            let cy = initCytoscape element graphData.Value dispatch
                            cyRef.current <- Some cy
                )
            ]

            // Controls overlay
            Html.div [
                prop.className "graph-controls"
                prop.style [
                    style.position.absolute
                    style.top 16
                    style.right 16
                    style.display.flex
                    style.gap 8
                ]
                prop.children [
                    // Fit to viewport button
                    Html.button [
                        prop.className "btn-fit"
                        prop.style [
                            style.padding (8, 16)
                            style.backgroundColor "#3b82f6"
                            style.color "#ffffff"
                            style.border.none
                            style.borderRadius 4
                            style.cursor.pointer
                        ]
                        prop.onClick (fun _ ->
                            match cyRef.current with
                            | Some cy -> cy.fit()
                            | None -> ()
                        )
                        prop.text "Fit"
                    ]

                    // Layout selector
                    Html.select [
                        prop.className "layout-selector"
                        prop.style [
                            style.padding (8, 16)
                            style.border (1, borderStyle.solid, "#d1d5db")
                            style.borderRadius 4
                        ]
                        prop.onChange (fun (value: string) ->
                            match cyRef.current with
                            | Some cy ->
                                let layout =
                                    match value with
                                    | "circle" -> Cytoscape.Layouts.circle
                                    | "grid" -> Cytoscape.Layouts.grid
                                    | "concentric" -> Cytoscape.Layouts.concentric
                                    | _ -> Cytoscape.Layouts.cose
                                let layoutInstance = cy.layout(layout)
                                layoutInstance.run()
                            | None -> ()
                        )
                        prop.children [
                            Html.option [ prop.value "cose"; prop.text "Force-Directed" ]
                            Html.option [ prop.value "circle"; prop.text "Circle" ]
                            Html.option [ prop.value "grid"; prop.text "Grid" ]
                            Html.option [ prop.value "concentric"; prop.text "Concentric (Entropy)" ]
                        ]
                    ]
                ]
            ]

            // Legend
            Html.div [
                prop.className "graph-legend"
                prop.style [
                    style.position.absolute
                    style.bottom 16
                    style.left 16
                    style.backgroundColor "#ffffff"
                    style.padding 12
                    style.borderRadius 8
                    style.border (1, borderStyle.solid, "#e5e7eb")
                ]
                prop.children [
                    Html.div [
                        prop.style [ style.fontWeight 600; style.marginBottom 8 ]
                        prop.text "Entropy"
                    ]
                    Html.div [
                        prop.style [ style.display.flex; style.alignItems.center; style.gap 4; style.marginBottom 4 ]
                        prop.children [
                            Html.div [ prop.style [ style.width 16; style.height 16; style.backgroundColor "#22c55e"; style.borderRadius 2 ] ]
                            Html.span [ prop.text "Fresh" ]
                        ]
                    ]
                    Html.div [
                        prop.style [ style.display.flex; style.alignItems.center; style.gap 4; style.marginBottom 4 ]
                        prop.children [
                            Html.div [ prop.style [ style.width 16; style.height 16; style.backgroundColor "#eab308"; style.borderRadius 2 ] ]
                            Html.span [ prop.text "Aging" ]
                        ]
                    ]
                    Html.div [
                        prop.style [ style.display.flex; style.alignItems.center; style.gap 4 ]
                        prop.children [
                            Html.div [ prop.style [ style.width 16; style.height 16; style.backgroundColor "#ef4444"; style.borderRadius 2 ] ]
                            Html.span [ prop.text "Rotting" ]
                        ]
                    ]
                ]
            ]
        ]
    ]

/// <summary>
/// Render loading state.
/// </summary>
let renderLoading () =
    Html.div [
        prop.className "graph-loading"
        prop.style [
            style.display.flex
            style.justifyContent.center
            style.alignItems.center
            style.height (length.vh 80)
            style.border (1, borderStyle.solid, "#e5e7eb")
            style.borderRadius 8
        ]
        prop.children [
            Html.div [
                prop.text "Loading graph..."
                prop.style [ style.fontSize 18; style.color "#6b7280" ]
            ]
        ]
    ]
