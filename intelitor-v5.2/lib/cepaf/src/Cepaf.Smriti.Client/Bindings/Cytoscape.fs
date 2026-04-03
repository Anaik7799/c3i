/// Cytoscape.js Bindings for F#/Fable
///
/// Provides type-safe interop with Cytoscape.js graph visualization library
/// for rendering the Zettelkasten knowledge graph.
module Cepaf.Smriti.Client.Bindings.Cytoscape

open Fable.Core
open Fable.Core.JsInterop
open Browser.Types

/// Cytoscape element data
type ElementData = {|
    id: string
    label: string option
    source: string option
    target: string option
    entropy: float option
    cluster: string option
    level: string option
    backlinkCount: int option
    linkType: string option
    weight: float option
    color: string option
|}

/// Cytoscape element (node or edge)
type Element = {|
    data: ElementData
    group: string option
    classes: string option
|}

/// Cytoscape style selector
type StyleSelector = {|
    selector: string
    style: obj
|}

/// Cytoscape layout options
type LayoutOptions = {|
    name: string
    animate: bool option
    animationDuration: int option
    fit: bool option
    padding: int option
    nodeDimensionsIncludeLabels: bool option
    randomize: bool option
    idealEdgeLength: int option
    nodeRepulsion: int option
    gravity: float option
|}

/// Cytoscape instance options
type CytoscapeOptions = {|
    container: HTMLElement
    elements: Element array
    style: StyleSelector array
    layout: LayoutOptions
    minZoom: float option
    maxZoom: float option
    wheelSensitivity: float option
|}

/// Cytoscape event object
[<AllowNullLiteral>]
type CyEvent =
    abstract target: CyNode

/// Cytoscape node
and [<AllowNullLiteral>] CyNode =
    abstract id: unit -> string
    abstract data: string -> obj
    abstract position: unit -> {| x: float; y: float |}
    abstract addClass: string -> CyNode
    abstract removeClass: string -> CyNode
    abstract select: unit -> CyNode
    abstract unselect: unit -> CyNode

/// Cytoscape layout runner
and [<AllowNullLiteral>] CyLayout =
    abstract run: unit -> unit
    abstract stop: unit -> unit

/// Cytoscape core instance
and [<AllowNullLiteral>] CyCore =
    abstract add: Element -> CyNode
    abstract add: Element array -> CyNode array
    abstract remove: string -> unit
    abstract nodes: unit -> CyNode array
    abstract edges: unit -> CyNode array
    abstract elements: unit -> CyNode array
    abstract getElementById: string -> CyNode
    abstract layout: LayoutOptions -> CyLayout
    abstract on: string * (CyEvent -> unit) -> CyCore
    abstract on: string * string * (CyEvent -> unit) -> CyCore
    abstract one: string * (CyEvent -> unit) -> CyCore
    abstract off: string -> CyCore
    abstract fit: unit -> CyCore
    abstract fit: int -> CyCore
    abstract zoom: unit -> float
    abstract zoom: float -> CyCore
    abstract pan: unit -> {| x: float; y: float |}
    abstract pan: {| x: float; y: float |} -> CyCore
    abstract center: unit -> CyCore
    abstract resize: unit -> CyCore
    abstract destroy: unit -> unit
    abstract json: unit -> obj
    abstract batch: (unit -> unit) -> CyCore

/// Import Cytoscape from npm
[<Import("default", "cytoscape")>]
let cytoscape: CytoscapeOptions -> CyCore = jsNative

/// Default node style
let nodeStyle: StyleSelector = {|
    selector = "node"
    style = createObj [
        "background-color" ==> "data(color)"
        "label" ==> "data(label)"
        "width" ==> "mapData(backlinkCount, 0, 10, 30, 80)"
        "height" ==> "mapData(backlinkCount, 0, 10, 30, 80)"
        "font-size" ==> "12px"
        "text-valign" ==> "center"
        "text-halign" ==> "center"
        "color" ==> "#fff"
        "text-outline-width" ==> 2
        "text-outline-color" ==> "#333"
        "border-width" ==> 2
        "border-color" ==> "#333"
    ]
|}

/// Selected node style
let selectedNodeStyle: StyleSelector = {|
    selector = "node:selected"
    style = createObj [
        "border-width" ==> 4
        "border-color" ==> "#0ea5e9"
    ]
|}

/// Edge style
let edgeStyle: StyleSelector = {|
    selector = "edge"
    style = createObj [
        "width" ==> "mapData(weight, 0, 1, 1, 5)"
        "line-color" ==> "#94a3b8"
        "target-arrow-color" ==> "#94a3b8"
        "target-arrow-shape" ==> "triangle"
        "curve-style" ==> "bezier"
        "opacity" ==> 0.6
    ]
|}

/// Highlighted edge style
let highlightedEdgeStyle: StyleSelector = {|
    selector = "edge.highlighted"
    style = createObj [
        "line-color" ==> "#0ea5e9"
        "target-arrow-color" ==> "#0ea5e9"
        "opacity" ==> 1
        "width" ==> 3
    ]
|}

/// Default styles array
let defaultStyles: StyleSelector array = [|
    nodeStyle
    selectedNodeStyle
    edgeStyle
    highlightedEdgeStyle
|]

/// COSE (Compound Spring Embedder) layout
let coseLayout: LayoutOptions = {|
    name = "cose"
    animate = Some true
    animationDuration = Some 500
    fit = Some true
    padding = Some 50
    nodeDimensionsIncludeLabels = Some true
    randomize = Some false
    idealEdgeLength = Some 100
    nodeRepulsion = Some 4000
    gravity = Some 0.25
|}

/// Concentric layout (by entropy)
let concentricLayout: LayoutOptions = {|
    name = "concentric"
    animate = Some true
    animationDuration = Some 500
    fit = Some true
    padding = Some 50
    nodeDimensionsIncludeLabels = Some true
    randomize = None
    idealEdgeLength = None
    nodeRepulsion = None
    gravity = None
|}

/// Circle layout
let circleLayout: LayoutOptions = {|
    name = "circle"
    animate = Some true
    animationDuration = Some 500
    fit = Some true
    padding = Some 50
    nodeDimensionsIncludeLabels = Some true
    randomize = None
    idealEdgeLength = None
    nodeRepulsion = None
    gravity = None
|}

/// Grid layout
let gridLayout: LayoutOptions = {|
    name = "grid"
    animate = Some true
    animationDuration = Some 500
    fit = Some true
    padding = Some 50
    nodeDimensionsIncludeLabels = Some true
    randomize = None
    idealEdgeLength = None
    nodeRepulsion = None
    gravity = None
|}

/// Create node element from data
let createNode (id: string) (label: string) (entropy: float) (cluster: string option) (level: string) (backlinkCount: int) (color: string) : Element =
    {|
        data = {|
            id = id
            label = Some label
            source = None
            target = None
            entropy = Some entropy
            cluster = cluster
            level = Some level
            backlinkCount = Some backlinkCount
            linkType = None
            weight = None
            color = Some color
        |}
        group = Some "nodes"
        classes = None
    |}

/// Create edge element from data
let createEdge (source: string) (target: string) (linkType: string) (weight: float) : Element =
    {|
        data = {|
            id = $"{source}-{target}"
            label = None
            source = Some source
            target = Some target
            entropy = None
            cluster = None
            level = None
            backlinkCount = None
            linkType = Some linkType
            weight = Some weight
            color = None
        |}
        group = Some "edges"
        classes = None
    |}
