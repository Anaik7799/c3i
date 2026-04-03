// =============================================================================
// GraphViewTests.fs - Tests for Cepaf.Cockpit.GraphView
// =============================================================================
// STAMP: SC-HMI-010 (Color Rich), SC-GRAPH-001 (graph analytics),
//        SC-SMRITI-131 (FTS5), SC-SMRITI-132 (semantic search)
// AOR:   AOR-GRAPH-001, AOR-CTX-007
//
// Covers:
//   GV-KIND   kindColour and kindLabel for every GraphNodeKind
//   GV-TT     renderTooltip structure and content
//   GV-NODES  renderNodeList grouping, counts, ANSI output
//   GV-STATS  renderGraphStats density, hub, per-kind counts
//   GV-DEF    defaultGraph shape invariants
//
// Version: 21.3.2 | 2026-03-30
// =============================================================================

module Cepaf.Tests.Unit.Cockpit.GraphViewTests

open Expecto
open Cepaf.Cockpit

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Strip all ANSI escape sequences so we can assert on plain text content.
let stripAnsi (s: string) : string =
    let mutable t = s
    let mutable i = t.IndexOf('\u001b')
    while i >= 0 do
        let m = t.IndexOf('m', i)
        if m >= 0 then t <- t.Remove(i, m - i + 1)
        else i <- -1
        i <- t.IndexOf('\u001b')
    t

/// All six GraphNodeKind cases.
let allKinds =
    [ GraphNodeKind.Zettel
      GraphNodeKind.Journal
      GraphNodeKind.Architecture
      GraphNodeKind.Spec
      GraphNodeKind.Constraint
      GraphNodeKind.Unknown ]

/// Build a minimal GraphNode for test use.
let makeNode id label kind tags linkCount wordCount updatedAt : GraphNode =
    { Id        = id
      Label     = label
      Kind      = kind
      Tags      = tags
      LinkCount = linkCount
      WordCount = wordCount
      UpdatedAt = updatedAt }

/// Build a minimal GraphEdge for test use.
let makeEdge src tgt label weight : GraphEdge =
    { Source = src; Target = tgt; Label = label; Weight = weight }

// ---------------------------------------------------------------------------
// GV-KIND: kindColour and kindLabel
// ---------------------------------------------------------------------------

[<Tests>]
let kindColourTests =
    testList "GV-KIND: kindColour" [

        test "GV-KIND-001: kindColour returns non-empty string for every kind" {
            for k in allKinds do
                let col = GraphView.kindColour k
                Expect.isTrue (col.Length > 0)
                    (sprintf "kindColour must return non-empty string for %A" k)
        }

        test "GV-KIND-002: kindColour contains ANSI escape code (SC-HMI-010)" {
            for k in allKinds do
                let col = GraphView.kindColour k
                Expect.stringContains col "\u001b["
                    (sprintf "kindColour must contain ANSI code for %A" k)
        }

        test "GV-KIND-003: kindColour produces distinct colours for distinct kinds" {
            let colours = allKinds |> List.map GraphView.kindColour
            let unique  = colours |> List.distinct
            Expect.equal (List.length unique) (List.length allKinds)
                "Every GraphNodeKind must have a distinct ANSI colour (SC-HMI-010)"
        }

        test "GV-KIND-004: kindColour for Constraint returns bright-red code" {
            // SC-HMI-010: Constraint nodes use bRed (\u001b[91m)
            let col = GraphView.kindColour GraphNodeKind.Constraint
            Expect.stringContains col "\u001b[91m"
                "Constraint kind must use bright-red colour"
        }

        test "GV-KIND-005: kindColour for Unknown returns dim code" {
            // Unknown nodes use dim (\u001b[2m)
            let col = GraphView.kindColour GraphNodeKind.Unknown
            Expect.stringContains col "\u001b[2m"
                "Unknown kind must use dim colour"
        }
    ]

[<Tests>]
let kindLabelTests =
    testList "GV-KIND: kindLabel" [

        test "GV-KIND-006: kindLabel returns non-empty string for every kind" {
            for k in allKinds do
                Expect.isTrue (GraphView.kindLabel(k).Length > 0)
                    (sprintf "kindLabel must return non-empty string for %A" k)
        }

        test "GV-KIND-007: kindLabel for Zettel is ZETTEL" {
            Expect.equal (GraphView.kindLabel GraphNodeKind.Zettel) "ZETTEL"
                "Zettel kind label must be ZETTEL"
        }

        test "GV-KIND-008: kindLabel for Journal is JOURNAL" {
            Expect.equal (GraphView.kindLabel GraphNodeKind.Journal) "JOURNAL"
                "Journal kind label must be JOURNAL"
        }

        test "GV-KIND-009: kindLabel for Architecture is ARCH" {
            Expect.equal (GraphView.kindLabel GraphNodeKind.Architecture) "ARCH"
                "Architecture kind label must be ARCH"
        }

        test "GV-KIND-010: kindLabel for Spec is SPEC" {
            Expect.equal (GraphView.kindLabel GraphNodeKind.Spec) "SPEC"
                "Spec kind label must be SPEC"
        }

        test "GV-KIND-011: kindLabel for Constraint is STAMP" {
            Expect.equal (GraphView.kindLabel GraphNodeKind.Constraint) "STAMP"
                "Constraint kind label must be STAMP"
        }

        test "GV-KIND-012: kindLabel for Unknown is ???" {
            Expect.equal (GraphView.kindLabel GraphNodeKind.Unknown) "???"
                "Unknown kind label must be ???"
        }
    ]

// ---------------------------------------------------------------------------
// GV-TT: renderTooltip
// ---------------------------------------------------------------------------

[<Tests>]
let renderTooltipTests =
    testList "GV-TT: renderTooltip" [

        test "GV-TT-001: renderTooltip returns non-empty string" {
            let node = makeNode "ZTL-001" "My Zettel Note" GraphNodeKind.Zettel
                                ["zenoh"; "mesh"] 5 400 "2026-03-30T10:00:00Z"
            let result = GraphView.renderTooltip node
            Expect.isTrue (result.Length > 0) "renderTooltip must return non-empty content"
        }

        test "GV-TT-002: renderTooltip contains node Id in plain text" {
            let node = makeNode "ZTL-042" "Permanent Note" GraphNodeKind.Zettel [] 3 200 "2026-03-30T00:00:00Z"
            let plain = stripAnsi (GraphView.renderTooltip node)
            Expect.stringContains plain "ZTL-042"
                "renderTooltip must include the node Id"
        }

        test "GV-TT-003: renderTooltip contains node Label in plain text" {
            let node = makeNode "ARCH-001" "SIL-6 Hierarchy Design" GraphNodeKind.Architecture
                                ["sil6"] 9 3200 "2026-03-25T11:30:00Z"
            let plain = stripAnsi (GraphView.renderTooltip node)
            Expect.stringContains plain "SIL-6 Hierarchy Design"
                "renderTooltip must include the node Label"
        }

        test "GV-TT-004: renderTooltip contains kind badge label in plain text" {
            let node = makeNode "JRN-20260328" "Sprint Journal" GraphNodeKind.Journal
                                ["sprint"] 5 2300 "2026-03-28T23:59:00Z"
            let plain = stripAnsi (GraphView.renderTooltip node)
            Expect.stringContains plain "JOURNAL"
                "renderTooltip must include the kind badge label"
        }

        test "GV-TT-005: renderTooltip contains ANSI colour codes (SC-HMI-010)" {
            let node = makeNode "SC-GRAPH-001" "Topology Constraint" GraphNodeKind.Constraint
                                ["graph"] 2 340 "2026-03-22T12:00:00Z"
            let result = GraphView.renderTooltip node
            Expect.stringContains result "\u001b["
                "renderTooltip must contain ANSI escape codes (SC-HMI-010)"
        }

        test "GV-TT-006: renderTooltip for Zettel contains ZETTEL badge in plain text" {
            let node = makeNode "ZTL-001" "Zenoh IPC" GraphNodeKind.Zettel
                                ["zenoh"] 8 920 "2026-03-28T10:00:00Z"
            let plain = stripAnsi (GraphView.renderTooltip node)
            Expect.stringContains plain "ZETTEL"
                "Zettel tooltip must contain [ZETTEL] badge"
        }

        test "GV-TT-007: renderTooltip for Constraint contains STAMP badge in plain text" {
            let node = makeNode "SC-SMRITI-131" "FTS5 constraint" GraphNodeKind.Constraint
                                ["stamp"] 1 180 "2026-03-22T12:00:00Z"
            let plain = stripAnsi (GraphView.renderTooltip node)
            Expect.stringContains plain "STAMP"
                "Constraint tooltip must contain [STAMP] badge"
        }

        test "GV-TT-008: renderTooltip contains word count in plain text" {
            let node = makeNode "SPEC-001" "Guardian Spec" GraphNodeKind.Spec
                                ["guardian"] 4 1500 "2026-03-20T08:00:00Z"
            let plain = stripAnsi (GraphView.renderTooltip node)
            Expect.stringContains plain "1500"
                "renderTooltip must include the word count"
        }

        test "GV-TT-009: renderTooltip contains UpdatedAt in plain text" {
            let node = makeNode "ARCH-002" "F# Control Plane" GraphNodeKind.Architecture
                                ["fsharp"] 7 2700 "2026-03-26T14:00:00Z"
            let plain = stripAnsi (GraphView.renderTooltip node)
            Expect.stringContains plain "2026-03-26T14:00:00Z"
                "renderTooltip must include the UpdatedAt timestamp"
        }

        test "GV-TT-010: renderTooltip for node with no tags contains (no tags) in plain text" {
            let node = makeNode "ZTL-099" "Untagged Note" GraphNodeKind.Zettel
                                [] 0 50 "2026-01-01T00:00:00Z"
            let plain = stripAnsi (GraphView.renderTooltip node)
            Expect.stringContains plain "(no tags)"
                "renderTooltip must display (no tags) when Tags list is empty"
        }

        test "GV-TT-011: renderTooltip for node with tags contains hash-prefixed tags in plain text" {
            let node = makeNode "ZTL-001" "Tagged Note" GraphNodeKind.Zettel
                                ["zenoh"; "mesh"; "sil6"] 5 400 "2026-03-30T00:00:00Z"
            let plain = stripAnsi (GraphView.renderTooltip node)
            Expect.stringContains plain "#zenoh"
                "renderTooltip must show tags with # prefix"
        }

        test "GV-TT-012: renderTooltip contains box-drawing characters" {
            let node = makeNode "ZTL-001" "Box Test" GraphNodeKind.Zettel [] 1 100 "2026-03-30T00:00:00Z"
            let result = GraphView.renderTooltip node
            // The top border uses ┌ and the bottom uses └
            Expect.stringContains result "┌"
                "renderTooltip must use box-drawing top-left corner"
            Expect.stringContains result "└"
                "renderTooltip must use box-drawing bottom-left corner"
        }

        test "GV-TT-013: renderTooltip output spans multiple lines" {
            let node = makeNode "ZTL-001" "Multi-line Test" GraphNodeKind.Zettel [] 2 200 "2026-03-30T00:00:00Z"
            let result = GraphView.renderTooltip node
            let lineCount = result.Split('\n').Length
            Expect.isGreaterThan lineCount 3
                "renderTooltip must produce at least 4 lines"
        }
    ]

// ---------------------------------------------------------------------------
// GV-NODES: renderNodeList
// ---------------------------------------------------------------------------

[<Tests>]
let renderNodeListTests =
    testList "GV-NODES: renderNodeList" [

        test "GV-NODES-001: renderNodeList of empty list returns non-empty header string" {
            let result = GraphView.renderNodeList []
            Expect.isTrue (result.Length > 0)
                "renderNodeList of empty list must still return a non-empty header"
        }

        test "GV-NODES-002: renderNodeList contains ANSI codes (SC-HMI-010)" {
            let nodes = [ makeNode "ZTL-001" "Test" GraphNodeKind.Zettel [] 1 100 "2026-03-30T00:00:00Z" ]
            let result = GraphView.renderNodeList nodes
            Expect.stringContains result "\u001b["
                "renderNodeList must contain ANSI colour codes (SC-HMI-010)"
        }

        test "GV-NODES-003: renderNodeList total count appears in plain text" {
            let nodes =
                [ makeNode "ZTL-001" "A" GraphNodeKind.Zettel [] 1 100 "2026-03-30T00:00:00Z"
                  makeNode "ZTL-002" "B" GraphNodeKind.Zettel [] 2 200 "2026-03-30T00:00:00Z"
                  makeNode "JRN-001" "C" GraphNodeKind.Journal [] 3 300 "2026-03-30T00:00:00Z" ]
            let plain = stripAnsi (GraphView.renderNodeList nodes)
            Expect.stringContains plain "3"
                "renderNodeList must include total node count in header"
        }

        test "GV-NODES-004: renderNodeList groups Zettel nodes under ZETTEL heading" {
            let nodes =
                [ makeNode "ZTL-001" "Note A" GraphNodeKind.Zettel ["x"] 1 100 "2026-03-30T00:00:00Z"
                  makeNode "ZTL-002" "Note B" GraphNodeKind.Zettel ["y"] 2 200 "2026-03-30T00:00:00Z" ]
            let plain = stripAnsi (GraphView.renderNodeList nodes)
            Expect.stringContains plain "ZETTEL"
                "renderNodeList must include ZETTEL group heading"
        }

        test "GV-NODES-005: renderNodeList groups Constraint nodes under STAMP heading" {
            let nodes =
                [ makeNode "SC-001" "Constraint A" GraphNodeKind.Constraint ["stamp"] 0 50 "2026-03-30T00:00:00Z" ]
            let plain = stripAnsi (GraphView.renderNodeList nodes)
            Expect.stringContains plain "STAMP"
                "renderNodeList must include STAMP group heading for Constraint kind"
        }

        test "GV-NODES-006: renderNodeList includes node IDs in plain text" {
            let nodes =
                [ makeNode "ARCH-001" "Architecture Doc" GraphNodeKind.Architecture [] 9 3200 "2026-03-25T11:30:00Z" ]
            let plain = stripAnsi (GraphView.renderNodeList nodes)
            Expect.stringContains plain "ARCH-001"
                "renderNodeList must include node ID"
        }

        test "GV-NODES-007: renderNodeList omits kind groups with no members" {
            // Only one Spec node — Journal group must not appear at all
            let nodes =
                [ makeNode "SPEC-001" "Spec Doc" GraphNodeKind.Spec ["spec"] 2 500 "2026-03-30T00:00:00Z" ]
            let plain = stripAnsi (GraphView.renderNodeList nodes)
            Expect.isFalse (plain.Contains("JOURNAL"))
                "renderNodeList must not render a group heading when that kind has no nodes"
        }

        test "GV-NODES-008: renderNodeList with mixed kinds includes all populated kind headings" {
            let nodes =
                [ makeNode "ZTL-001" "Zettel"      GraphNodeKind.Zettel       [] 1 100 "2026-03-30T00:00:00Z"
                  makeNode "JRN-001" "Journal"     GraphNodeKind.Journal      [] 2 200 "2026-03-30T00:00:00Z"
                  makeNode "SC-001"  "Constraint"  GraphNodeKind.Constraint   [] 0 50  "2026-03-30T00:00:00Z" ]
            let plain = stripAnsi (GraphView.renderNodeList nodes)
            Expect.stringContains plain "ZETTEL"   "ZETTEL heading must appear"
            Expect.stringContains plain "JOURNAL"  "JOURNAL heading must appear"
            Expect.stringContains plain "STAMP"    "STAMP heading must appear"
        }
    ]

// ---------------------------------------------------------------------------
// GV-STATS: renderGraphStats
// ---------------------------------------------------------------------------

[<Tests>]
let renderGraphStatsTests =
    testList "GV-STATS: renderGraphStats" [

        test "GV-STATS-001: renderGraphStats returns non-empty string" {
            let graph = GraphView.defaultGraph ()
            let result = GraphView.renderGraphStats graph
            Expect.isTrue (result.Length > 0)
                "renderGraphStats must return non-empty content"
        }

        test "GV-STATS-002: renderGraphStats contains ANSI codes (SC-HMI-010)" {
            let graph = GraphView.defaultGraph ()
            let result = GraphView.renderGraphStats graph
            Expect.stringContains result "\u001b["
                "renderGraphStats must contain ANSI codes (SC-HMI-010)"
        }

        test "GV-STATS-003: renderGraphStats contains TotalNotes value in plain text" {
            let graph = GraphView.defaultGraph ()
            let plain = stripAnsi (GraphView.renderGraphStats graph)
            // defaultGraph has TotalNotes = 10
            Expect.stringContains plain (string graph.TotalNotes)
                "renderGraphStats must display TotalNotes"
        }

        test "GV-STATS-004: renderGraphStats contains TotalLinks value in plain text" {
            let graph = GraphView.defaultGraph ()
            let plain = stripAnsi (GraphView.renderGraphStats graph)
            // defaultGraph has TotalLinks = 15
            Expect.stringContains plain (string graph.TotalLinks)
                "renderGraphStats must display TotalLinks"
        }

        test "GV-STATS-005: renderGraphStats reports graph density in plain text" {
            let graph = GraphView.defaultGraph ()
            let plain = stripAnsi (GraphView.renderGraphStats graph)
            // Density field header must appear
            Expect.stringContains plain "density"
                "renderGraphStats must include graph density row"
        }

        test "GV-STATS-006: renderGraphStats reports avg links per node in plain text" {
            let graph = GraphView.defaultGraph ()
            let plain = stripAnsi (GraphView.renderGraphStats graph)
            Expect.stringContains plain "Avg links"
                "renderGraphStats must include avg links/node row"
        }

        test "GV-STATS-007: renderGraphStats includes Top hub section in plain text" {
            let graph = GraphView.defaultGraph ()
            let plain = stripAnsi (GraphView.renderGraphStats graph)
            Expect.stringContains plain "Top hub"
                "renderGraphStats must include a Top hub section"
        }

        test "GV-STATS-008: renderGraphStats hub is the node with highest LinkCount" {
            let graph = GraphView.defaultGraph ()
            // ZTL-002 has LinkCount = 12, the highest in defaultGraph
            let plain = stripAnsi (GraphView.renderGraphStats graph)
            Expect.stringContains plain "ZTL-002"
                "renderGraphStats hub must be ZTL-002 (LinkCount=12, the max)"
        }

        test "GV-STATS-009: renderGraphStats for empty graph shows empty-graph message" {
            let emptyGraph = { Nodes = []; Edges = []; TotalNotes = 0; TotalLinks = 0 }
            let plain = stripAnsi (GraphView.renderGraphStats emptyGraph)
            Expect.stringContains plain "(empty graph)"
                "renderGraphStats must display (empty graph) when there are no nodes"
        }

        test "GV-STATS-010: renderGraphStats per-kind section contains ZETTEL label" {
            let graph = GraphView.defaultGraph ()
            let plain = stripAnsi (GraphView.renderGraphStats graph)
            Expect.stringContains plain "ZETTEL"
                "renderGraphStats must include per-kind count for ZETTEL"
        }

        test "GV-STATS-011: renderGraphStats per-kind section contains STAMP label" {
            let graph = GraphView.defaultGraph ()
            let plain = stripAnsi (GraphView.renderGraphStats graph)
            Expect.stringContains plain "STAMP"
                "renderGraphStats must include per-kind count for STAMP (Constraint)"
        }

        test "GV-STATS-012: renderGraphStats density for single-node graph is 0.0000" {
            let singleNode =
                { Nodes      = [ makeNode "ZTL-001" "Solo" GraphNodeKind.Zettel [] 0 100 "2026-03-30T00:00:00Z" ]
                  Edges      = []
                  TotalNotes = 1
                  TotalLinks = 0 }
            let plain = stripAnsi (GraphView.renderGraphStats singleNode)
            // D = E / (N*(N-1)) = 0/(1*0) → 0; clamped to 0.0000
            Expect.stringContains plain "0.0000"
                "Single-node graph must have density 0.0000"
        }
    ]

// ---------------------------------------------------------------------------
// GV-DEF: defaultGraph
// ---------------------------------------------------------------------------

[<Tests>]
let defaultGraphTests =
    testList "GV-DEF: defaultGraph" [

        test "GV-DEF-001: defaultGraph returns exactly 10 nodes" {
            let g = GraphView.defaultGraph ()
            Expect.equal (List.length g.Nodes) 10
                "defaultGraph must contain exactly 10 nodes"
        }

        test "GV-DEF-002: defaultGraph returns exactly 15 edges" {
            let g = GraphView.defaultGraph ()
            Expect.equal (List.length g.Edges) 15
                "defaultGraph must contain exactly 15 edges"
        }

        test "GV-DEF-003: defaultGraph TotalNotes is 10" {
            let g = GraphView.defaultGraph ()
            Expect.equal g.TotalNotes 10
                "defaultGraph TotalNotes must be 10"
        }

        test "GV-DEF-004: defaultGraph TotalLinks is 15" {
            let g = GraphView.defaultGraph ()
            Expect.equal g.TotalLinks 15
                "defaultGraph TotalLinks must be 15"
        }

        test "GV-DEF-005: all node IDs are non-empty" {
            let g = GraphView.defaultGraph ()
            Expect.isTrue (g.Nodes |> List.forall (fun n -> n.Id.Length > 0))
                "All node IDs must be non-empty strings"
        }

        test "GV-DEF-006: all node Labels are non-empty" {
            let g = GraphView.defaultGraph ()
            Expect.isTrue (g.Nodes |> List.forall (fun n -> n.Label.Length > 0))
                "All node Labels must be non-empty strings"
        }

        test "GV-DEF-007: all edge Source and Target IDs reference valid node IDs" {
            let g       = GraphView.defaultGraph ()
            let nodeIds = g.Nodes |> List.map (fun n -> n.Id) |> Set.ofList
            Expect.isTrue
                (g.Edges |> List.forall (fun e ->
                    Set.contains e.Source nodeIds && Set.contains e.Target nodeIds))
                "All edge endpoints must reference valid node IDs"
        }

        test "GV-DEF-008: defaultGraph contains a ZTL-001 node of kind Zettel" {
            let g    = GraphView.defaultGraph ()
            let node = g.Nodes |> List.find (fun n -> n.Id = "ZTL-001")
            Expect.equal node.Kind GraphNodeKind.Zettel
                "ZTL-001 must have kind Zettel"
        }

        test "GV-DEF-009: defaultGraph contains a SC-GRAPH-001 node of kind Constraint" {
            let g    = GraphView.defaultGraph ()
            let node = g.Nodes |> List.find (fun n -> n.Id = "SC-GRAPH-001")
            Expect.equal node.Kind GraphNodeKind.Constraint
                "SC-GRAPH-001 must have kind Constraint"
        }

        test "GV-DEF-010: all edge weights are in range [0.0, 1.0]" {
            let g = GraphView.defaultGraph ()
            Expect.isTrue
                (g.Edges |> List.forall (fun e -> e.Weight >= 0.0 && e.Weight <= 1.0))
                "All edge weights must be in the range [0.0, 1.0]"
        }

        test "GV-DEF-011: defaultGraph contains at least one Journal node" {
            let g = GraphView.defaultGraph ()
            Expect.isTrue
                (g.Nodes |> List.exists (fun n -> n.Kind = GraphNodeKind.Journal))
                "defaultGraph must contain at least one Journal node"
        }

        test "GV-DEF-012: defaultGraph contains at least one Architecture node" {
            let g = GraphView.defaultGraph ()
            Expect.isTrue
                (g.Nodes |> List.exists (fun n -> n.Kind = GraphNodeKind.Architecture))
                "defaultGraph must contain at least one Architecture node"
        }
    ]

// ---------------------------------------------------------------------------
// Aggregate
// ---------------------------------------------------------------------------

[<Tests>]
let allGraphViewTests =
    testList "GraphView" [
        kindColourTests
        kindLabelTests
        renderTooltipTests
        renderNodeListTests
        renderGraphStatsTests
        defaultGraphTests
    ]
