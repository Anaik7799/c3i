// =============================================================================
// GraphView.fs - Knowledge Graph Tooltip Rendering for SMRITI Graph View
// =============================================================================
// STAMP: SC-SMRITI-131 (FTS5 search), SC-SMRITI-132 (semantic search / embeddings),
//        SC-HMI-010 (Color Rich), SC-GRAPH-001 (graph verification analytics)
// AOR: AOR-CTX-007 (knowledge queries via Smriti), AOR-GRAPH-001
//
// Pure rendering module for the SMRITI knowledge graph visualisation pane.
// Provides tooltip rendering for hovered nodes, grouped node lists, and a
// graph statistics panel.  All functions are PURE — no I/O, no side effects.
// Uses System only — no external dependencies.
//
// ## Constitutional Alignment
// - Ψ₂ (Evolutionary Continuity): Graph captures the full zettelkasten lineage
// - Ψ₃ (Verification): Node statistics are numeric, auditable, and deterministic
//
// ## STAMP Compliance
// - SC-SMRITI-131: Full-text search uses FTS5 — node labels searchable
// - SC-SMRITI-132: Semantic search via vector embeddings — tags & word counts
// - SC-HMI-010: Vibrant chromatic feedback — distinct colour per GraphNodeKind
// - SC-GRAPH-001: Graph operations — topology metrics, edge density reported
//
// Version: 21.3.2 | 2026-03-30
// =============================================================================

namespace Cepaf.Cockpit

open System

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// Classification of a node in the SMRITI knowledge graph.
[<RequireQualifiedAccess>]
type GraphNodeKind =
    /// Atomic zettelkasten note (permanent note, ZTL-xxx)
    | Zettel
    /// Daily/sprint journal entry (JRN-yyyymmdd)
    | Journal
    /// Architecture decision record or design doc (ARCH-xxx)
    | Architecture
    /// Specification or requirements document (SPEC-xxx)
    | Spec
    /// STAMP/AOR constraint definition (SC-xxx or AOR-xxx)
    | Constraint
    /// Node kind could not be determined from the note identifier
    | Unknown

/// A single node in the knowledge graph.
type GraphNode = {
    /// Unique note identifier (e.g. "ZTL-042", "JRN-20260330", "SC-GRAPH-001")
    Id         : string
    /// Human-readable title of the note
    Label      : string
    /// Classification kind
    Kind       : GraphNodeKind
    /// Tags / keywords associated with the note
    Tags       : string list
    /// Number of forward + backward links from this node
    LinkCount  : int
    /// Word count of the note body
    WordCount  : int
    /// ISO-8601 last-modification timestamp string
    UpdatedAt  : string
}

/// A directed link between two graph nodes.
type GraphEdge = {
    /// Identifier of the source node
    Source : string
    /// Identifier of the target node
    Target : string
    /// Human-readable link description (e.g. "references", "implements")
    Label  : string
    /// Link strength or relevance weight (0.0–1.0)
    Weight : float
}

/// The complete SMRITI knowledge graph snapshot.
type KnowledgeGraph = {
    /// All nodes in the graph
    Nodes      : GraphNode list
    /// All directed edges
    Edges      : GraphEdge list
    /// Total note count (may differ from Nodes length if a subset is loaded)
    TotalNotes : int
    /// Total link count across all notes
    TotalLinks : int
}

// ---------------------------------------------------------------------------
// ANSI colour helpers (private, prefix GvAnsi)
// Mirrors the palette convention used across Cepaf.Cockpit modules.
// ---------------------------------------------------------------------------

module private GvAnsi =
    let reset     = "\u001b[0m"
    let bold      = "\u001b[1m"
    let dim       = "\u001b[2m"
    let underline = "\u001b[4m"
    // Standard colours
    let green     = "\u001b[32m"
    let yellow    = "\u001b[33m"
    let cyan      = "\u001b[36m"
    let magenta   = "\u001b[35m"
    let white     = "\u001b[37m"
    let red       = "\u001b[31m"
    let blue      = "\u001b[34m"
    // Bright colours
    let bGreen    = "\u001b[92m"
    let bYellow   = "\u001b[93m"
    let bCyan     = "\u001b[96m"
    let bMagenta  = "\u001b[95m"
    let bWhite    = "\u001b[97m"
    let bBlue     = "\u001b[94m"
    let bRed      = "\u001b[91m"
    // Backgrounds
    let bgGrey    = "\u001b[48;5;236m"
    let bgDark    = "\u001b[48;5;234m"

// ---------------------------------------------------------------------------
// GraphView — pure knowledge graph rendering
// ---------------------------------------------------------------------------

/// Renders SMRITI knowledge graph nodes as ANSI-coloured TUI output.
/// All functions are pure (no I/O).  Callers are responsible for printing
/// the returned strings.
[<RequireQualifiedAccess>]
module GraphView =

    // -----------------------------------------------------------------------
    // Kind mapping helpers (public — used by callers for filtering / styling)
    // -----------------------------------------------------------------------

    /// Maps a GraphNodeKind to an ANSI colour escape code.
    /// Follows SC-HMI-010: each kind has a distinct vibrant colour.
    let kindColour (kind: GraphNodeKind) : string =
        match kind with
        | GraphNodeKind.Zettel       -> GvAnsi.bGreen
        | GraphNodeKind.Journal      -> GvAnsi.bCyan
        | GraphNodeKind.Architecture -> GvAnsi.bMagenta
        | GraphNodeKind.Spec         -> GvAnsi.bYellow
        | GraphNodeKind.Constraint   -> GvAnsi.bRed
        | GraphNodeKind.Unknown      -> GvAnsi.dim

    /// Maps a GraphNodeKind to a short display label for badges and headings.
    let kindLabel (kind: GraphNodeKind) : string =
        match kind with
        | GraphNodeKind.Zettel       -> "ZETTEL"
        | GraphNodeKind.Journal      -> "JOURNAL"
        | GraphNodeKind.Architecture -> "ARCH"
        | GraphNodeKind.Spec         -> "SPEC"
        | GraphNodeKind.Constraint   -> "STAMP"
        | GraphNodeKind.Unknown      -> "???"

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /// Renders a coloured kind badge, e.g. "[ZETTEL]" in bright green.
    let private kindBadge (kind: GraphNodeKind) : string =
        let col = kindColour kind
        let lbl = kindLabel kind
        sprintf "%s[%s]%s" col lbl GvAnsi.reset

    /// Renders a list of tags as "#tag1 #tag2 …" with bright-yellow hashes.
    let private renderTags (tags: string list) : string =
        if tags.IsEmpty then
            sprintf "%s(no tags)%s" GvAnsi.dim GvAnsi.reset
        else
            tags
            |> List.map (fun t -> sprintf "%s#%s%s%s" GvAnsi.bYellow t GvAnsi.dim GvAnsi.reset)
            |> String.concat " "

    /// Clamps an integer to [lo, hi].
    let private clampInt (lo: int) (hi: int) (v: int) : int =
        if v < lo then lo elif v > hi then hi else v

    /// Selects a colour for a link-count value; more links = brighter.
    let private linkCountColour (count: int) : string =
        if   count >= 20 then GvAnsi.bRed
        elif count >= 10 then GvAnsi.bYellow
        elif count >=  5 then GvAnsi.bGreen
        else                  GvAnsi.dim

    /// Rounds a float to 4 decimal places for display.
    let private fmt4 (v: float) : string =
        Math.Round(v, 4).ToString("F4")

    // -----------------------------------------------------------------------
    // Public rendering API
    // -----------------------------------------------------------------------

    /// Renders a compact ANSI tooltip for a single hovered graph node.
    ///
    /// Format (5 lines inside a bordered box):
    ///   ┌──────────────────────────────────────────────┐
    ///   │ ID     ZTL-042                [ZETTEL]       │
    ///   │ TITLE  My Permanent Note On Zenoh            │
    ///   │ TAGS   #zenoh #mesh #sil6                    │
    ///   │ LINKS  12 connections   WORDS  843           │
    ///   │ UPDAT  2026-03-30T14:22:00Z                  │
    ///   └──────────────────────────────────────────────┘
    ///
    /// Returns a multi-line ANSI-coloured string.
    let renderTooltip (node: GraphNode) : string =
        let width = 50
        let bar   = String.replicate width "─"
        let top   = sprintf "%s┌%s┐%s" GvAnsi.cyan bar GvAnsi.reset
        let bot   = sprintf "%s└%s┘%s" GvAnsi.cyan bar GvAnsi.reset

        let stripAnsiLen (s: string) =
            let mutable clean = s
            let mutable idx   = clean.IndexOf('\u001b')
            while idx >= 0 do
                let mEnd = clean.IndexOf('m', idx)
                if mEnd >= 0 then clean <- clean.Remove(idx, mEnd - idx + 1)
                else idx <- -1
                idx <- clean.IndexOf('\u001b')
            clean.Length

        let line (label: string) (value: string) =
            let labelPad = label.PadRight(6)
            let pad = String.replicate (max 0 (width - 10 - label.Length - stripAnsiLen value)) " "
            sprintf "%s│%s %s%s%s  %s %s%s%s%s│%s"
                GvAnsi.cyan GvAnsi.reset
                GvAnsi.dim labelPad GvAnsi.reset
                value
                GvAnsi.dim pad GvAnsi.reset
                GvAnsi.cyan GvAnsi.reset

        // Build each content row
        let idLine =
            let idVal = sprintf "%s%s%s" GvAnsi.bWhite node.Id GvAnsi.reset
            let badge = kindBadge node.Kind
            let pad   = String.replicate 2 " "
            sprintf "%s│%s %s%s%s  %s %s %s%s%s%s│%s"
                GvAnsi.cyan GvAnsi.reset
                GvAnsi.dim "ID    " GvAnsi.reset
                idVal badge
                GvAnsi.dim pad GvAnsi.reset
                GvAnsi.cyan GvAnsi.reset

        let titleVal = sprintf "%s%s%s" GvAnsi.bWhite node.Label GvAnsi.reset
        let tagsVal  = renderTags node.Tags
        let linksVal =
            sprintf "%s%d%s connections   %sWORDS%s  %s%d%s"
                (linkCountColour node.LinkCount) node.LinkCount GvAnsi.reset
                GvAnsi.dim GvAnsi.reset
                GvAnsi.bCyan node.WordCount GvAnsi.reset
        let updVal   = sprintf "%s%s%s" GvAnsi.dim node.UpdatedAt GvAnsi.reset

        [ top
          idLine
          line "TITLE" titleVal
          line "TAGS " tagsVal
          line "LINKS" linksVal
          line "UPDAT" updVal
          bot ]
        |> String.concat "\n"

    /// Renders a numbered list of nodes grouped by GraphNodeKind.
    ///
    /// Each group is introduced by a coloured kind header, followed by
    /// numbered entries showing id, label, link count, and word count.
    ///
    /// Returns a multi-line ANSI-coloured string.
    let renderNodeList (nodes: GraphNode list) : string =
        let kinds =
            [ GraphNodeKind.Zettel
              GraphNodeKind.Journal
              GraphNodeKind.Architecture
              GraphNodeKind.Spec
              GraphNodeKind.Constraint
              GraphNodeKind.Unknown ]

        let sep = sprintf "  %s%s%s" GvAnsi.dim (String.replicate 54 "─") GvAnsi.reset

        let header =
            sprintf "  %s%s SMRITI KNOWLEDGE GRAPH NODES %s(%d total)%s"
                GvAnsi.bold GvAnsi.bMagenta GvAnsi.dim (List.length nodes) GvAnsi.reset

        let groupLines =
            kinds
            |> List.collect (fun kind ->
                let subset = nodes |> List.filter (fun n -> n.Kind = kind)
                if subset.IsEmpty then []
                else
                    let groupHdr =
                        sprintf "\n  %s%s%s  %s%d nodes%s"
                            (kindColour kind) (kindLabel kind) GvAnsi.reset
                            GvAnsi.dim (List.length subset) GvAnsi.reset
                    let rows =
                        subset
                        |> List.mapi (fun i n ->
                            let col = kindColour n.Kind
                            sprintf "    %s%2d.%s %s%-14s%s %-36s  %s%2d lnk%s  %s%4d w%s"
                                GvAnsi.dim (i + 1) GvAnsi.reset
                                col n.Id GvAnsi.reset
                                n.Label
                                (linkCountColour n.LinkCount) n.LinkCount GvAnsi.reset
                                GvAnsi.dim n.WordCount GvAnsi.reset)
                    groupHdr :: rows)

        [ ""; sep; header; sep ]
        @ groupLines
        @ [ ""; sep; "" ]
        |> String.concat "\n"

    /// Renders a statistics pane summarising the knowledge graph topology.
    ///
    /// Shows:
    ///   - Node count total and per-kind breakdown
    ///   - Edge count
    ///   - Graph density  D = E / (N × (N-1))
    ///   - Average link count per node
    ///   - Most-connected node (hub)
    ///
    /// Returns a multi-line ANSI-coloured string.
    let renderGraphStats (graph: KnowledgeGraph) : string =
        let n = List.length graph.Nodes
        let e = List.length graph.Edges

        // Graph density: for a directed graph D = E / N*(N-1), clamp to [0,1]
        let density =
            if n <= 1 then 0.0
            else float e / (float n * float (n - 1))

        // Average links per node
        let avgLinks =
            if n = 0 then 0.0
            else float graph.TotalLinks / float n

        // Hub node: node with highest LinkCount
        let hubLine =
            match graph.Nodes |> List.sortByDescending (fun nd -> nd.LinkCount) |> List.tryHead with
            | None    -> sprintf "%s(empty graph)%s" GvAnsi.dim GvAnsi.reset
            | Some nd ->
                sprintf "%s%s%s  %s%s%s  %s%d links%s"
                    (kindColour nd.Kind) nd.Id GvAnsi.reset
                    GvAnsi.white nd.Label GvAnsi.reset
                    (linkCountColour nd.LinkCount) nd.LinkCount GvAnsi.reset

        // Per-kind counts
        let kindCounts =
            [ GraphNodeKind.Zettel
              GraphNodeKind.Journal
              GraphNodeKind.Architecture
              GraphNodeKind.Spec
              GraphNodeKind.Constraint
              GraphNodeKind.Unknown ]
            |> List.map (fun kind ->
                let count = graph.Nodes |> List.filter (fun nd -> nd.Kind = kind) |> List.length
                let col   = kindColour kind
                let lbl   = kindLabel kind
                sprintf "    %s%-12s%s %s%d%s"
                    col lbl GvAnsi.reset
                    GvAnsi.bWhite count GvAnsi.reset)

        let sep = sprintf "  %s%s%s" GvAnsi.cyan (String.replicate 54 "─") GvAnsi.reset

        let header =
            sprintf "  %s%s SMRITI GRAPH STATISTICS %s%s"
                GvAnsi.bold GvAnsi.bCyan GvAnsi.reset GvAnsi.reset

        let statRows =
            [ sprintf "  %s%-20s%s  %s%d%s  %s(loaded: %d)%s"
                  GvAnsi.dim "Total notes"    GvAnsi.reset
                  GvAnsi.bWhite graph.TotalNotes GvAnsi.reset
                  GvAnsi.dim (List.length graph.Nodes) GvAnsi.reset
              sprintf "  %s%-20s%s  %s%d%s  %s(loaded: %d)%s"
                  GvAnsi.dim "Total links"    GvAnsi.reset
                  GvAnsi.bWhite graph.TotalLinks GvAnsi.reset
                  GvAnsi.dim e GvAnsi.reset
              sprintf "  %s%-20s%s  %s%s%s"
                  GvAnsi.dim "Graph density"  GvAnsi.reset
                  GvAnsi.bYellow (fmt4 density) GvAnsi.reset
              sprintf "  %s%-20s%s  %s%.2f%s"
                  GvAnsi.dim "Avg links/node" GvAnsi.reset
                  GvAnsi.bGreen avgLinks GvAnsi.reset
              ""
              sprintf "  %s%sNode kinds:%s" GvAnsi.bold GvAnsi.white GvAnsi.reset ]

        let hubRows =
            [ ""
              sprintf "  %s%sTop hub:%s" GvAnsi.bold GvAnsi.white GvAnsi.reset
              sprintf "    %s" hubLine ]

        [ ""; sep; header; sep ]
        @ statRows
        @ kindCounts
        @ hubRows
        @ [ ""; sep; "" ]
        |> String.concat "\n"

    // -----------------------------------------------------------------------
    // Sample data
    // -----------------------------------------------------------------------

    /// Returns a sample KnowledgeGraph with 10 nodes and 15 edges for
    /// use in tests, demos, and REPL exploration.
    ///
    /// Node IDs follow the SMRITI convention: ZTL-xxx, JRN-yyyymmdd,
    /// ARCH-xxx, SPEC-xxx, SC-xxx.
    let defaultGraph () : KnowledgeGraph =
        let nodes =
            [ { Id = "ZTL-001"; Label = "Zenoh Unified IPC Architecture";
                Kind = GraphNodeKind.Zettel;
                Tags = [ "zenoh"; "ipc"; "mesh" ];
                LinkCount = 8; WordCount = 920; UpdatedAt = "2026-03-28T10:00:00Z" }
              { Id = "ZTL-002"; Label = "SMRITI Zettelkasten Knowledge Store";
                Kind = GraphNodeKind.Zettel;
                Tags = [ "smriti"; "knowledge"; "sqlite" ];
                LinkCount = 12; WordCount = 1140; UpdatedAt = "2026-03-29T09:15:00Z" }
              { Id = "ZTL-003"; Label = "Biomorphic Fractal Mesh Topology";
                Kind = GraphNodeKind.Zettel;
                Tags = [ "biomorphic"; "mesh"; "sil6" ];
                LinkCount = 6; WordCount = 780; UpdatedAt = "2026-03-27T16:45:00Z" }
              { Id = "JRN-20260328"; Label = "Panoptic Ignition Sprint Journal";
                Kind = GraphNodeKind.Journal;
                Tags = [ "sprint"; "ignition"; "2026-03-28" ];
                LinkCount = 5; WordCount = 2300; UpdatedAt = "2026-03-28T23:59:00Z" }
              { Id = "JRN-20260329"; Label = "Metabolic Pruning Design Journal";
                Kind = GraphNodeKind.Journal;
                Tags = [ "pruning"; "metabolic"; "cepaf" ];
                LinkCount = 3; WordCount = 1850; UpdatedAt = "2026-03-29T22:00:00Z" }
              { Id = "ARCH-001"; Label = "SIL-6 Biomorphic Supervisor Hierarchy";
                Kind = GraphNodeKind.Architecture;
                Tags = [ "sil6"; "supervisor"; "arch" ];
                LinkCount = 9; WordCount = 3200; UpdatedAt = "2026-03-25T11:30:00Z" }
              { Id = "ARCH-002"; Label = "F# Cepaf Mesh Control Plane";
                Kind = GraphNodeKind.Architecture;
                Tags = [ "fsharp"; "cepaf"; "control-plane" ];
                LinkCount = 7; WordCount = 2700; UpdatedAt = "2026-03-26T14:00:00Z" }
              { Id = "SPEC-001"; Label = "Guardian Validation Protocol Spec";
                Kind = GraphNodeKind.Spec;
                Tags = [ "guardian"; "validation"; "spec" ];
                LinkCount = 4; WordCount = 1500; UpdatedAt = "2026-03-20T08:00:00Z" }
              { Id = "SC-GRAPH-001"; Label = "Graph Operations — topology constraint";
                Kind = GraphNodeKind.Constraint;
                Tags = [ "graph"; "stamp"; "topology" ];
                LinkCount = 2; WordCount = 340; UpdatedAt = "2026-03-22T12:00:00Z" }
              { Id = "SC-SMRITI-131"; Label = "Full-text search uses FTS5";
                Kind = GraphNodeKind.Constraint;
                Tags = [ "smriti"; "fts5"; "stamp" ];
                LinkCount = 1; WordCount = 180; UpdatedAt = "2026-03-22T12:00:00Z" } ]

        let edges =
            [ { Source = "ZTL-001"; Target = "ARCH-001";    Label = "implements";  Weight = 0.9 }
              { Source = "ZTL-001"; Target = "ARCH-002";    Label = "references";  Weight = 0.8 }
              { Source = "ZTL-001"; Target = "SC-GRAPH-001"; Label = "satisfies";  Weight = 0.7 }
              { Source = "ZTL-002"; Target = "SC-SMRITI-131"; Label = "satisfies"; Weight = 0.95 }
              { Source = "ZTL-002"; Target = "ZTL-001";     Label = "uses";        Weight = 0.6 }
              { Source = "ZTL-002"; Target = "ARCH-001";    Label = "references";  Weight = 0.5 }
              { Source = "ZTL-003"; Target = "ARCH-001";    Label = "implements";  Weight = 0.85 }
              { Source = "ZTL-003"; Target = "ARCH-002";    Label = "implements";  Weight = 0.75 }
              { Source = "JRN-20260328"; Target = "ZTL-001"; Label = "documents"; Weight = 0.4 }
              { Source = "JRN-20260328"; Target = "ZTL-003"; Label = "documents"; Weight = 0.4 }
              { Source = "JRN-20260329"; Target = "ZTL-002"; Label = "documents"; Weight = 0.4 }
              { Source = "ARCH-001"; Target = "SPEC-001";   Label = "references"; Weight = 0.7 }
              { Source = "ARCH-002"; Target = "ZTL-001";    Label = "references"; Weight = 0.6 }
              { Source = "SPEC-001"; Target = "SC-GRAPH-001"; Label = "extends";  Weight = 0.5 }
              { Source = "SC-SMRITI-131"; Target = "ZTL-002"; Label = "governs"; Weight = 0.9 } ]

        { Nodes      = nodes
          Edges      = edges
          TotalNotes = 10
          TotalLinks = 15 }
