// =============================================================================
// GraphView.fs - Knowledge Graph Tooltip & Visualization
// =============================================================================
// STAMP: SC-SMRITI-131 (full-text search/graph uses FTS5/vector embeddings),
//        SC-GRAPH-001 (graph operations — verification, analytics),
//        SC-HMI-010 (vibrant chromatic feedback), SC-VDP-001 (visual data plane)
// AOR: AOR-CTX-007 (knowledge queries via Smriti), AOR-GRAPH-001 (graph verification)
//
// Renders a SMRITI knowledge graph as ANSI-coloured terminal output.
// Provides node tooltip construction, ASCII adjacency rendering,
// DOT/JSON export, and ANSI node-list display for the Prajna TUI cockpit.
//
// Note kinds supported: zettel, journal, architecture, spec
// Edge relation types: references, extends, contradicts, implements
//
// All public functions are pure — no I/O, no mutable state.
// Version: 21.3.2 | 2026-03-30
// =============================================================================

namespace Cepaf.Cockpit

open System

// ---------------------------------------------------------------------------
// ANSI palette (re-declared locally — SC-CONSOL-003)
// ---------------------------------------------------------------------------

module private GraphAnsi =
    let reset    = "\x1b[0m"
    let bold     = "\x1b[1m"
    let dim      = "\x1b[2m"
    let cyan     = "\x1b[36m"
    let yellow   = "\x1b[33m"
    let green    = "\x1b[32m"
    let blue     = "\x1b[34m"
    let magenta  = "\x1b[35m"
    let white    = "\x1b[97m"
    let grey     = "\x1b[90m"
    let red      = "\x1b[31m"
    let orange   = "\x1b[38;5;208m"

    let paint (colour: string) (text: string) : string =
        sprintf "%s%s%s" colour text reset

    let boldPaint (colour: string) (text: string) : string =
        sprintf "%s%s%s%s" bold colour text reset

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// A node in the knowledge graph — corresponds to one SMRITI zettel.
type GraphNode = {
    Id        : string
    Label     : string
    Kind      : string          // zettel | journal | architecture | spec
    Tags      : string list
    WordCount : int
    UpdatedAt : string
}

/// A directed edge between two knowledge graph nodes.
type GraphEdge = {
    Source   : string
    Target   : string
    Relation : string           // references | extends | contradicts | implements
    Weight   : float
}

/// The complete knowledge graph snapshot.
type KnowledgeGraph = {
    Nodes     : GraphNode list
    Edges     : GraphEdge list
    Timestamp : string
}

/// Rich tooltip for a single graph node — shown on hover / inspection.
type NodeTooltip = {
    NodeId      : string
    Title       : string
    Kind        : string
    Summary     : string
    Tags        : string list
    LinkCount   : int
    LastUpdated : string
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

module private GraphHelpers =

    /// Colour for a node kind badge.
    let kindColour (kind: string) : string =
        match kind.ToLowerInvariant() with
        | "zettel"       -> GraphAnsi.cyan
        | "journal"      -> GraphAnsi.blue
        | "architecture" -> GraphAnsi.orange
        | "spec"         -> GraphAnsi.magenta
        | _              -> GraphAnsi.grey

    /// Colour for a relation type.
    let relationColour (relation: string) : string =
        match relation.ToLowerInvariant() with
        | "extends"     -> GraphAnsi.green
        | "implements"  -> GraphAnsi.cyan
        | "references"  -> GraphAnsi.blue
        | "contradicts" -> GraphAnsi.red
        | _             -> GraphAnsi.grey

    /// Degree (total links) for a node.
    let degree (graph: KnowledgeGraph) (nodeId: string) : int =
        graph.Edges
        |> List.filter (fun e -> e.Source = nodeId || e.Target = nodeId)
        |> List.length

    /// Neighbours (outgoing targets) for a node.
    let outgoing (graph: KnowledgeGraph) (nodeId: string) : string list =
        graph.Edges
        |> List.filter (fun e -> e.Source = nodeId)
        |> List.map (fun e -> e.Target)

    /// Incoming sources for a node.
    let incoming (graph: KnowledgeGraph) (nodeId: string) : string list =
        graph.Edges
        |> List.filter (fun e -> e.Target = nodeId)
        |> List.map (fun e -> e.Source)

    /// Render a tag badge in ANSI magenta.
    let tagBadge (tag: string) : string =
        GraphAnsi.paint GraphAnsi.magenta (sprintf "[%s]" tag)

    /// Render all tag badges space-separated.
    let tagBadges (tags: string list) : string =
        if tags.IsEmpty then GraphAnsi.paint GraphAnsi.grey "(no tags)"
        else tags |> List.map tagBadge |> String.concat " "

    /// Look up a node by id, returning None when absent.
    let findNode (graph: KnowledgeGraph) (nodeId: string) : GraphNode option =
        graph.Nodes |> List.tryFind (fun n -> n.Id = nodeId)

    /// Brief auto-generated summary from node metadata.
    let autosummary (node: GraphNode) (linkCount: int) : string =
        sprintf "%s note · %d words · %d link%s · updated %s"
            node.Kind node.WordCount linkCount
            (if linkCount = 1 then "" else "s")
            node.UpdatedAt

    /// Escape a string for inclusion in a DOT label attribute.
    let dotEscape (s: string) : string =
        s.Replace("\"", "\\\"").Replace("\n", "\\n")

    /// Escape a string for inclusion in a JSON string value.
    let jsonEscape (s: string) : string =
        s.Replace("\\", "\\\\")
         .Replace("\"", "\\\"")
         .Replace("\n", "\\n")
         .Replace("\r", "\\r")
         .Replace("\t", "\\t")

    /// Render a float with 2 decimal places without trailing zero noise.
    let fmtFloat (f: float) : string = sprintf "%.2f" f

// ---------------------------------------------------------------------------
// Stub zettel data (8 nodes, representative knowledge base)
// ---------------------------------------------------------------------------

module private StubData =

    let nodes : GraphNode list = [
        { Id = "z-001"; Label = "SIL-6 Biomorphic Mesh Architecture";
          Kind = "architecture"; Tags = ["sil6"; "mesh"; "safety"];
          WordCount = 1240; UpdatedAt = "2026-03-28" }

        { Id = "z-002"; Label = "Zenoh Unified IPC Design";
          Kind = "spec"; Tags = ["zenoh"; "ipc"; "protocol"];
          WordCount = 872; UpdatedAt = "2026-03-27" }

        { Id = "z-003"; Label = "OODA Cycle < 100ms Invariant";
          Kind = "zettel"; Tags = ["ooda"; "latency"; "invariant"];
          WordCount = 310; UpdatedAt = "2026-03-25" }

        { Id = "z-004"; Label = "Founder's Covenant — Omega-0";
          Kind = "zettel"; Tags = ["constitutional"; "omega"; "founder"];
          WordCount = 195; UpdatedAt = "2026-03-20" }

        { Id = "z-005"; Label = "2026-03-28 Sprint 87 Journal";
          Kind = "journal"; Tags = ["sprint87"; "morphogenesis"; "retrospective"];
          WordCount = 2350; UpdatedAt = "2026-03-28" }

        { Id = "z-006"; Label = "Constitutional Reconfiguration Protocol";
          Kind = "spec"; Tags = ["constitution"; "reconfiguration"; "guardian"];
          WordCount = 680; UpdatedAt = "2026-03-22" }

        { Id = "z-007"; Label = "Fractal Coverage Gold Standard";
          Kind = "zettel"; Tags = ["coverage"; "wallaby"; "tdg"];
          WordCount = 420; UpdatedAt = "2026-03-26" }

        { Id = "z-008"; Label = "MathematicalSystemMonitor Design Notes";
          Kind = "architecture"; Tags = ["math"; "monitor"; "fmea"; "disciplines"];
          WordCount = 960; UpdatedAt = "2026-03-19" }
    ]

    let edges : GraphEdge list = [
        { Source = "z-001"; Target = "z-002"; Relation = "references"; Weight = 0.9 }
        { Source = "z-001"; Target = "z-003"; Relation = "extends";    Weight = 0.7 }
        { Source = "z-002"; Target = "z-003"; Relation = "implements"; Weight = 0.8 }
        { Source = "z-003"; Target = "z-004"; Relation = "references"; Weight = 0.5 }
        { Source = "z-004"; Target = "z-006"; Relation = "extends";    Weight = 0.6 }
        { Source = "z-005"; Target = "z-001"; Relation = "references"; Weight = 0.4 }
        { Source = "z-005"; Target = "z-008"; Relation = "references"; Weight = 0.4 }
        { Source = "z-006"; Target = "z-001"; Relation = "implements"; Weight = 0.85 }
        { Source = "z-007"; Target = "z-003"; Relation = "extends";    Weight = 0.65 }
        { Source = "z-008"; Target = "z-001"; Relation = "implements"; Weight = 0.75 }
        { Source = "z-007"; Target = "z-006"; Relation = "contradicts"; Weight = 0.3 }
    ]

// ---------------------------------------------------------------------------
// GraphView — public API
// ---------------------------------------------------------------------------

/// ANSI knowledge graph renderer and tooltip provider for the Prajna TUI cockpit.
/// STAMP: SC-SMRITI-131, SC-GRAPH-001, SC-HMI-010
module GraphView =

    // -----------------------------------------------------------------------
    // Graph construction
    // -----------------------------------------------------------------------

    /// Build a KnowledgeGraph from stub zettel data (5-10 nodes).
    ///
    /// In production this would query the SMRITI SQLite store
    /// (SC-SMRITI-131: FTS5 full-text search, SC-GRAPH-001).
    ///
    /// Returns: KnowledgeGraph ready for rendering.
    let buildGraph () : KnowledgeGraph =
        { Nodes     = StubData.nodes
          Edges     = StubData.edges
          Timestamp = DateTimeOffset.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ") }

    // -----------------------------------------------------------------------
    // Tooltip
    // -----------------------------------------------------------------------

    /// Get a rich tooltip for the given node id.
    ///
    /// Parameters:
    ///   graph  — the KnowledgeGraph to query
    ///   nodeId — the id of the node to inspect
    ///
    /// Returns:
    ///   Ok(tooltip_string)   — ANSI-formatted tooltip ready for display
    ///   Error(reason)        — node not found or graph empty
    let getTooltip (graph: KnowledgeGraph) (nodeId: string) : Result<string, string> =
        if String.IsNullOrWhiteSpace nodeId then
            Error "nodeId must not be empty"
        else
            match GraphHelpers.findNode graph nodeId with
            | None ->
                Error (sprintf "node '%s' not found in graph (%d nodes)" nodeId graph.Nodes.Length)
            | Some node ->
                let linkCount = GraphHelpers.degree graph nodeId
                let tooltip : NodeTooltip = {
                    NodeId      = node.Id
                    Title       = node.Label
                    Kind        = node.Kind
                    Summary     = GraphHelpers.autosummary node linkCount
                    Tags        = node.Tags
                    LinkCount   = linkCount
                    LastUpdated = node.UpdatedAt
                }
                let kindColour = GraphHelpers.kindColour tooltip.Kind
                let sep = GraphAnsi.paint GraphAnsi.grey (String.replicate 54 "─")
                let lines = [
                    sep
                    sprintf "%s %s"
                        (GraphAnsi.paint GraphAnsi.grey "Node:")
                        (GraphAnsi.boldPaint GraphAnsi.white tooltip.NodeId)
                    sprintf "%s %s"
                        (GraphAnsi.paint GraphAnsi.grey "Title:")
                        (GraphAnsi.boldPaint kindColour tooltip.Title)
                    sprintf "%s %s"
                        (GraphAnsi.paint GraphAnsi.grey "Kind:")
                        (GraphAnsi.paint kindColour tooltip.Kind)
                    sprintf "%s %s"
                        (GraphAnsi.paint GraphAnsi.grey "Tags:")
                        (GraphHelpers.tagBadges tooltip.Tags)
                    sprintf "%s %s"
                        (GraphAnsi.paint GraphAnsi.grey "Summary:")
                        (GraphAnsi.paint GraphAnsi.white tooltip.Summary)
                    sprintf "%s %s"
                        (GraphAnsi.paint GraphAnsi.grey "Links:")
                        (GraphAnsi.boldPaint GraphAnsi.yellow (string tooltip.LinkCount))
                    sprintf "%s %s"
                        (GraphAnsi.paint GraphAnsi.grey "Updated:")
                        (GraphAnsi.paint GraphAnsi.blue tooltip.LastUpdated)
                    sep
                ]
                Ok (lines |> String.concat "\n")

    // -----------------------------------------------------------------------
    // ASCII adjacency rendering
    // -----------------------------------------------------------------------

    /// Render a simple ASCII adjacency list of the knowledge graph.
    ///
    /// Parameters:
    ///   graph — the KnowledgeGraph to render
    ///
    /// Returns: multi-line ASCII string showing node → neighbours.
    let renderAsciiGraph (graph: KnowledgeGraph) : string =
        let header = sprintf "Knowledge Graph  (%d nodes, %d edges)" graph.Nodes.Length graph.Edges.Length
        let divider = String.replicate (header.Length) "─"
        let rows =
            graph.Nodes
            |> List.map (fun node ->
                let outs =
                    GraphHelpers.outgoing graph node.Id
                    |> List.map (fun tid ->
                        match GraphHelpers.findNode graph tid with
                        | Some t -> sprintf "%s (%s)" t.Id t.Label
                        | None   -> tid)
                let arrows =
                    if outs.IsEmpty then "  (no outgoing links)"
                    else outs |> List.mapi (fun i s -> sprintf "  %s─► %s" (if i = 0 then "├" else "└") s) |> String.concat "\n"
                sprintf "[ %s ] %s\n%s" node.Id node.Label arrows)
        (header :: divider :: rows) |> String.concat "\n"

    // -----------------------------------------------------------------------
    // ANSI node list
    // -----------------------------------------------------------------------

    /// Render an ANSI-coloured list of all graph nodes with kind badges.
    ///
    /// Parameters:
    ///   graph — the KnowledgeGraph to render
    ///
    /// Returns: ANSI-formatted multi-line string ready for TUI display.
    let renderNodeList (graph: KnowledgeGraph) : string =
        let header =
            GraphAnsi.boldPaint GraphAnsi.cyan
                (sprintf "Knowledge Graph — %d nodes" graph.Nodes.Length)
        let divider = GraphAnsi.paint GraphAnsi.grey (String.replicate 60 "─")
        let rows =
            graph.Nodes
            |> List.mapi (fun i node ->
                let kindColour = GraphHelpers.kindColour node.Kind
                let badge = GraphAnsi.paint kindColour (sprintf "%-12s" node.Kind)
                let links = GraphHelpers.degree graph node.Id
                let tagStr =
                    node.Tags
                    |> List.truncate 3
                    |> List.map (fun t -> GraphAnsi.paint GraphAnsi.grey (sprintf "#%s" t))
                    |> String.concat " "
                let wc = GraphAnsi.paint GraphAnsi.dim (sprintf "%4dw" node.WordCount)
                let lnk =
                    GraphAnsi.paint GraphAnsi.yellow (sprintf "%d lnk" links)
                sprintf "%2d │ %s %s  %s  %s  %s"
                    (i + 1) badge (GraphAnsi.boldPaint kindColour node.Label)
                    wc lnk tagStr)
        (header :: divider :: rows) |> String.concat "\n"

    // -----------------------------------------------------------------------
    // JSON serialisation
    // -----------------------------------------------------------------------

    /// Serialise the KnowledgeGraph to a compact JSON string.
    ///
    /// Parameters:
    ///   graph — the KnowledgeGraph to serialise
    ///
    /// Returns: JSON string (no indentation — compact form).
    let toJson (graph: KnowledgeGraph) : string =
        let nodeJson (n: GraphNode) =
            let tagsJson =
                n.Tags
                |> List.map (fun t -> sprintf "\"%s\"" (GraphHelpers.jsonEscape t))
                |> String.concat ","
            sprintf "{\"id\":\"%s\",\"label\":\"%s\",\"kind\":\"%s\",\"tags\":[%s],\"wordCount\":%d,\"updatedAt\":\"%s\"}"
                (GraphHelpers.jsonEscape n.Id)
                (GraphHelpers.jsonEscape n.Label)
                (GraphHelpers.jsonEscape n.Kind)
                tagsJson
                n.WordCount
                (GraphHelpers.jsonEscape n.UpdatedAt)

        let edgeJson (e: GraphEdge) =
            sprintf "{\"source\":\"%s\",\"target\":\"%s\",\"relation\":\"%s\",\"weight\":%s}"
                (GraphHelpers.jsonEscape e.Source)
                (GraphHelpers.jsonEscape e.Target)
                (GraphHelpers.jsonEscape e.Relation)
                (GraphHelpers.fmtFloat e.Weight)

        let nodesArr  = graph.Nodes |> List.map nodeJson  |> String.concat ","
        let edgesArr  = graph.Edges |> List.map edgeJson  |> String.concat ","
        sprintf "{\"timestamp\":\"%s\",\"nodes\":[%s],\"edges\":[%s]}"
            (GraphHelpers.jsonEscape graph.Timestamp)
            nodesArr edgesArr

    // -----------------------------------------------------------------------
    // DOT / GraphViz export
    // -----------------------------------------------------------------------

    /// Export the KnowledgeGraph in GraphViz DOT format.
    ///
    /// Parameters:
    ///   graph — the KnowledgeGraph to export
    ///
    /// Returns: DOT source string suitable for `dot -Tsvg` rendering.
    let toDot (graph: KnowledgeGraph) : string =
        let nodeShape (kind: string) =
            match kind.ToLowerInvariant() with
            | "architecture" -> "diamond"
            | "spec"         -> "box"
            | "journal"      -> "note"
            | _              -> "ellipse"  // zettel default

        let nodeColour (kind: string) =
            match kind.ToLowerInvariant() with
            | "architecture" -> "#FF9800"
            | "spec"         -> "#9C27B0"
            | "journal"      -> "#2196F3"
            | _              -> "#00BCD4"  // zettel default

        let edgeStyle (relation: string) =
            match relation.ToLowerInvariant() with
            | "extends"     -> "solid"
            | "implements"  -> "dashed"
            | "contradicts" -> "dotted"
            | _             -> "solid"   // references default

        let edgeColour (relation: string) =
            match relation.ToLowerInvariant() with
            | "extends"     -> "#4CAF50"
            | "implements"  -> "#00BCD4"
            | "contradicts" -> "#F44336"
            | _             -> "#607D8B"  // references default

        let nodeLines =
            graph.Nodes
            |> List.map (fun n ->
                let lbl = GraphHelpers.dotEscape (sprintf "%s\\n(%s)\\n%dw" n.Id n.Kind n.WordCount)
                let shape = nodeShape n.Kind
                let colour = nodeColour n.Kind
                sprintf "  \"%s\" [label=\"%s\", shape=%s, style=filled, fillcolor=\"%s\", fontcolor=\"white\"];"
                    (GraphHelpers.dotEscape n.Id) lbl shape colour)

        let edgeLines =
            graph.Edges
            |> List.map (fun e ->
                let style  = edgeStyle e.Relation
                let colour = edgeColour e.Relation
                let lbl    = GraphHelpers.dotEscape (sprintf "%s (%.1f)" e.Relation e.Weight)
                sprintf "  \"%s\" -> \"%s\" [label=\"%s\", style=%s, color=\"%s\"];"
                    (GraphHelpers.dotEscape e.Source)
                    (GraphHelpers.dotEscape e.Target)
                    lbl style colour)

        let lines = [
            sprintf "// Generated by Cepaf.Cockpit.GraphView — %s" graph.Timestamp
            "// STAMP: SC-SMRITI-131, SC-GRAPH-001"
            "digraph KnowledgeGraph {"
            "  graph [rankdir=LR, bgcolor=\"#1a1a2e\", fontname=\"monospace\"];"
            "  node  [fontname=\"monospace\", fontsize=10];"
            "  edge  [fontname=\"monospace\", fontsize=9];"
            yield! nodeLines
            ""
            yield! edgeLines
            "}"
        ]
        lines |> String.concat "\n"
