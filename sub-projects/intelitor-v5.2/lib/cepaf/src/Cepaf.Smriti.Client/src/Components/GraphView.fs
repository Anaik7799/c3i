/// Graph View Component - Cytoscape.js integration for knowledge graph
///
/// Renders the Zettelkasten as an interactive graph visualization.
///
/// STAMP Constraints:
/// - SC-KMS-005: Cytoscape.js graph visualization
module Cepaf.Smriti.Client.Components.GraphView

open System
open Fable.Core
open Fable.Core.JsInterop
open Feliz
open Browser.Types
open Cepaf.Smriti.Client.Model
open Cepaf.Smriti.Client.Msg
open Cepaf.Smriti.Client.Bindings.Cytoscape

/// Convert model graph data to Cytoscape elements
let graphDataToElements (graphData: GraphData) : Element array =
    let nodeElements =
        graphData.Nodes
        |> List.map (fun node ->
            createNode
                (string node.Id)
                node.Label
                node.Entropy
                node.Cluster
                node.Level
                node.BacklinkCount
                (entropyToColor node.Entropy)
        )
        |> List.toArray

    let edgeElements =
        graphData.Edges
        |> List.map (fun edge ->
            createEdge
                (string edge.Source)
                (string edge.Target)
                edge.LinkType
                edge.Weight
        )
        |> List.toArray

    Array.append nodeElements edgeElements

/// Get layout options by name
let getLayout (name: string) : LayoutOptions =
    match name with
    | "concentric" -> concentricLayout
    | "circle" -> circleLayout
    | "grid" -> gridLayout
    | _ -> coseLayout

/// Layout button component
[<ReactComponent>]
let LayoutButton (name: string) (label: string) (currentLayout: string) (onClick: unit -> unit) =
    Html.button [
        prop.style [
            style.padding (length.rem 0.5, length.rem 0.75)
            style.border (1, borderStyle.solid, if currentLayout = name then "#3b82f6" else "#d1d5db")
            style.borderRadius (length.rem 0.25)
            style.backgroundColor (if currentLayout = name then "#eff6ff" else "white")
            style.color (if currentLayout = name then "#3b82f6" else "#374151")
            style.cursor.pointer
            style.fontSize (length.rem 0.875)
        ]
        prop.onClick (fun _ -> onClick())
        prop.text label
    ]

/// Legend component
[<ReactComponent>]
let Legend () =
    Html.div [
        prop.style [
            style.position.absolute
            style.bottom (length.rem 1)
            style.right (length.rem 1)
            style.padding (length.rem 0.75)
            style.backgroundColor "rgba(255, 255, 255, 0.95)"
            style.borderRadius (length.rem 0.25)
            style.border (1, borderStyle.solid, "#e5e7eb")
            style.fontSize (length.rem 0.75)
        ]
        prop.children [
            Html.div [
                prop.style [ style.fontWeight 600; style.marginBottom (length.rem 0.5) ]
                prop.text "Entropy"
            ]
            for (color, label) in [
                ("#22c55e", "Fresh (0-20%)")
                ("#84cc16", "Recent (20-40%)")
                ("#eab308", "Aging (40-60%)")
                ("#f97316", "Stale (60-80%)")
                ("#ef4444", "Rotting (80-100%)")
            ] do
                Html.div [
                    prop.style [
                        style.display.flex
                        style.alignItems.center
                        style.gap (length.rem 0.5)
                        style.marginBottom (length.rem 0.25)
                    ]
                    prop.children [
                        Html.span [
                            prop.style [
                                style.width (length.rem 0.75)
                                style.height (length.rem 0.75)
                                style.borderRadius (length.percent 50)
                                style.backgroundColor color
                            ]
                        ]
                        Html.span [ prop.text label ]
                    ]
                ]
        ]
    ]

/// Main graph view component
[<ReactComponent>]
let GraphView (graphData: GraphData) (layout: string) (dispatch: Msg -> unit) =
    let containerRef = React.useRef<HTMLElement option> None
    let cyRef = React.useRef<CyCore option> None

    // Initialize Cytoscape on mount
    React.useEffect(
        (fun () ->
            match containerRef.current with
            | Some container ->
                let elements = graphDataToElements graphData
                let cy = cytoscape {|
                    container = container
                    elements = elements
                    style = defaultStyles
                    layout = getLayout layout
                    minZoom = Some 0.1
                    maxZoom = Some 3.0
                    wheelSensitivity = Some 0.3
                |}

                cyRef.current <- Some cy

                cy.on("tap", "node", fun (evt: CyEvent) ->
                    let nodeId = evt.target.id()
                    match Guid.TryParse(nodeId) with
                    | true, guid -> dispatch (SelectZettel guid)
                    | false, _ -> ()
                ) |> ignore

                { new IDisposable with
                    member _.Dispose() =
                        match cyRef.current with
                        | Some cy ->
                            cy.destroy()
                            cyRef.current <- None
                        | None -> ()
                }
            | None ->
                { new IDisposable with member _.Dispose() = () }
        ),
        [| box graphData |]
    )

    // Update layout when it changes
    React.useEffect(
        (fun () ->
            match cyRef.current with
            | Some cy ->
                let layoutRunner = cy.layout(getLayout layout)
                layoutRunner.run()
            | None -> ()
        ),
        [| box layout |]
    )

    Html.div [
        prop.style [
            style.position.relative
            style.width (length.percent 100)
        ]
        prop.children [
            // Toolbar
            Html.div [
                prop.style [
                    style.display.flex
                    style.alignItems.center
                    style.gap (length.rem 0.5)
                    style.padding (length.rem 0.75)
                    style.backgroundColor "white"
                    style.borderBottom (1, borderStyle.solid, "#e5e7eb")
                ]
                prop.children [
                    Html.span [
                        prop.style [ style.fontWeight 500; style.marginRight (length.rem 0.5) ]
                        prop.text "Layout:"
                    ]
                    LayoutButton "cose" "Force" layout (fun () -> dispatch (ChangeLayout "cose"))
                    LayoutButton "concentric" "Concentric" layout (fun () -> dispatch (ChangeLayout "concentric"))
                    LayoutButton "circle" "Circle" layout (fun () -> dispatch (ChangeLayout "circle"))
                    LayoutButton "grid" "Grid" layout (fun () -> dispatch (ChangeLayout "grid"))

                    Html.div [ prop.style [ style.flexGrow 1 ] ]

                    Html.button [
                        prop.style [
                            style.padding (length.rem 0.5, length.rem 0.75)
                            style.border (1, borderStyle.solid, "#d1d5db")
                            style.borderRadius (length.rem 0.25)
                            style.backgroundColor "white"
                            style.cursor.pointer
                        ]
                        prop.onClick (fun _ ->
                            match cyRef.current with
                            | Some cy -> cy.fit() |> ignore
                            | None -> ()
                        )
                        prop.text "Fit"
                    ]
                ]
            ]

            // Graph container
            Html.div [
                prop.ref (fun el -> containerRef.current <- Option.ofObj (el :?> HTMLElement))
                prop.style [
                    style.width (length.percent 100)
                    style.height (length.vh 70)
                    style.backgroundColor "#f9fafb"
                    style.borderRadius (length.rem 0.5)
                    style.border (1, borderStyle.solid, "#e5e7eb")
                    style.overflow.hidden
                ]
            ]

            Legend()
        ]
    ]

/// Loading state for graph
[<ReactComponent>]
let GraphViewWithState (graphState: LoadingState<GraphData>) (layout: string) (dispatch: Msg -> unit) =
    match graphState with
    | NotStarted ->
        Html.div [
            prop.style [
                style.display.flex
                style.alignItems.center
                style.justifyContent.center
                style.height (length.vh 50)
                style.color "#6b7280"
            ]
            prop.children [
                Html.button [
                    prop.style [
                        style.padding (length.rem 0.75, length.rem 1.5)
                        style.backgroundColor "#3b82f6"
                        style.color "white"
                        style.custom ("border", "none")
                        style.borderRadius (length.rem 0.375)
                        style.cursor.pointer
                        style.fontSize (length.rem 1)
                    ]
                    prop.onClick (fun _ -> dispatch LoadGraph)
                    prop.text "Load Graph"
                ]
            ]
        ]
    | Loading ->
        Html.div [
            prop.style [
                style.display.flex
                style.alignItems.center
                style.justifyContent.center
                style.height (length.vh 50)
                style.color "#6b7280"
            ]
            prop.text "Loading graph..."
        ]
    | Loaded graphData ->
        GraphView graphData layout dispatch
    | Failed error ->
        Html.div [
            prop.style [
                style.display.flex
                style.alignItems.center
                style.justifyContent.center
                style.height (length.vh 50)
                style.color "#ef4444"
            ]
            prop.children [
                Html.div [
                    prop.style [ style.textAlign.center ]
                    prop.children [
                        Html.p [
                            prop.style [ style.fontSize (length.rem 1.125); style.fontWeight 500 ]
                            prop.text "Failed to load graph"
                        ]
                        Html.p [
                            prop.style [ style.fontSize (length.rem 0.875); style.marginTop (length.rem 0.5) ]
                            prop.text error
                        ]
                        Html.button [
                            prop.style [
                                style.marginTop (length.rem 1)
                                style.padding (length.rem 0.5, length.rem 1)
                                style.backgroundColor "#3b82f6"
                                style.color "white"
                                style.custom ("border", "none")
                                style.borderRadius (length.rem 0.375)
                                style.cursor.pointer
                            ]
                            prop.onClick (fun _ -> dispatch LoadGraph)
                            prop.text "Retry"
                        ]
                    ]
                ]
            ]
        ]
