namespace Cepaf.Cockpit

open System
open Cepaf.Zenoh.KmsSubscriber
open Cepaf.Cockpit.DarkCockpitUI

/// ═══════════════════════════════════════════════════════════════════════════════
/// KMS PANEL - Knowledge Management System Dashboard
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// WHAT: Terminal-based panel for displaying KMS holon tree, health status,
///       and knowledge metrics from the Elixir KMS backend.
///
/// WHY: Provides operators with real-time visibility into organizational
///      knowledge state, enabling:
///      - Holon hierarchy visualization
///      - Health monitoring (vital signs)
///      - Entropy tracking (stale knowledge)
///      - Quick navigation to knowledge artifacts
///
/// INTEGRATION:
///   - Uses KmsSubscriber for real-time Zenoh data
///   - Follows Dark Cockpit UI principles
///   - NASA-STD-3000 compliant layout
///
/// STAMP Compliance:
///   - SC-KMS-005: Cross-runtime state sync via Zenoh
///   - SC-HMI-001: Dark Cockpit defaults
///   - SC-OODA-001: <100ms update latency
///
/// ═══════════════════════════════════════════════════════════════════════════════
module KmsPanel =

    // ═══════════════════════════════════════════════════════════════════════════
    // PANEL STATE
    // ═══════════════════════════════════════════════════════════════════════════

    type KmsPanelState = {
        SelectedHolonId: string option
        ExpandedNodes: Set<string>
        ViewMode: KmsViewMode
        FilterType: string option
        SearchQuery: string
        LastRefresh: DateTimeOffset
    }

    and KmsViewMode =
        | TreeView
        | ListView
        | HealthView
        | EntropyView

    let mutable private panelState = {
        SelectedHolonId = None
        ExpandedNodes = Set.empty
        ViewMode = TreeView
        FilterType = None
        SearchQuery = ""
        LastRefresh = DateTimeOffset.MinValue
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ICONS & SYMBOLS
    // ═══════════════════════════════════════════════════════════════════════════

    let private typeIcon (holonType: string) =
        match holonType.ToLower() with
        | "knowledge" -> "📚"
        | "process" -> "⚙"
        | "agent" -> "🤖"
        | "artifact" -> "📦"
        | "index" -> "📁"
        | "decision" -> "📋"
        | "architecture" -> "🏗"
        | "debt" -> "⚠"
        | "radar" -> "📡"
        | "capability" -> "👥"
        | _ -> "●"

    let private healthIcon (health: float) =
        if health >= 0.9 then "🟢"
        elif health >= 0.7 then "🟡"
        elif health >= 0.5 then "🟠"
        else "🔴"

    let private treePrefix (depth: int) (isLast: bool) =
        if depth = 0 then ""
        else
            let indent = String.replicate (depth - 1) "│   "
            if isLast then indent + "└── "
            else indent + "├── "

    // ═══════════════════════════════════════════════════════════════════════════
    // RENDERING - TREE VIEW
    // ═══════════════════════════════════════════════════════════════════════════

    let private renderTreeNode (depth: int) (isLast: bool) (node: HolonTreeNode) =
        let prefix = treePrefix depth isLast
        let icon = typeIcon node.Holon.Type
        let name = node.Holon.Name
        let healthStr =
            match node.Holon.VitalSigns with
            | Some vs -> sprintf " %s %.0f%%" (healthIcon vs.Health) (vs.Health * 100.0)
            | None -> ""

        let expanded = Set.contains node.Holon.Id panelState.ExpandedNodes
        let expandIcon = if List.isEmpty node.Children then " " elif expanded then "▼" else "▶"

        let color =
            if Some node.Holon.Id = panelState.SelectedHolonId then Ansi.advisory
            else Ansi.normal

        sprintf "%s%s%s %s %s%s%s" color prefix expandIcon icon name healthStr Ansi.reset

    let rec private renderTree (depth: int) (nodes: HolonTreeNode list) : string list =
        nodes
        |> List.mapi (fun i node ->
            let isLast = i = List.length nodes - 1
            let line = renderTreeNode depth isLast node
            if Set.contains node.Holon.Id panelState.ExpandedNodes && not (List.isEmpty node.Children) then
                line :: renderTree (depth + 1) node.Children
            else
                [line]
        )
        |> List.concat

    let renderTreeView () : string list =
        let tree = buildTree()
        if List.isEmpty tree then
            ["  (No holons loaded - waiting for Zenoh data...)"]
        else
            [
                sprintf "%s📊 HOLON TREE%s" Ansi.bold Ansi.reset
                sprintf "%s──────────────────────────────────────────%s" Ansi.dim Ansi.reset
            ] @ renderTree 0 tree

    // ═══════════════════════════════════════════════════════════════════════════
    // RENDERING - LIST VIEW
    // ═══════════════════════════════════════════════════════════════════════════

    let renderListView () : string list =
        let holons = getHolons()
        let filtered =
            match panelState.FilterType with
            | Some t -> holons |> List.filter (fun h -> h.Type = t)
            | None -> holons

        let sorted = filtered |> List.sortBy (fun h -> h.Name)

        [
            sprintf "%s📋 HOLON LIST (%d items)%s" Ansi.bold (List.length sorted) Ansi.reset
            sprintf "%s──────────────────────────────────────────%s" Ansi.dim Ansi.reset
            sprintf "%s%-6s %-20s %-12s %s%s" Ansi.dim "Icon" "Name" "Type" "Health" Ansi.reset
        ] @
        (sorted |> List.map (fun h ->
            let icon = typeIcon h.Type
            let name = if String.length h.Name > 20 then h.Name.Substring(0, 17) + "..." else h.Name
            let healthStr =
                match h.VitalSigns with
                | Some vs -> sprintf "%.0f%%" (vs.Health * 100.0)
                | None -> "-"
            let color = if Some h.Id = panelState.SelectedHolonId then Ansi.advisory else Ansi.normal
            sprintf "%s  %s   %-20s %-12s %s%s" color icon name h.Type healthStr Ansi.reset
        ))

    // ═══════════════════════════════════════════════════════════════════════════
    // RENDERING - HEALTH VIEW
    // ═══════════════════════════════════════════════════════════════════════════

    let private renderHealthBar (label: string) (value: float) (maxWidth: int) =
        let filled = int (value * float maxWidth)
        let empty = maxWidth - filled
        let color =
            if value >= 0.9 then Ansi.connected
            elif value >= 0.7 then Ansi.caution
            else Ansi.warning
        let filledBar = String.replicate filled "█"
        let emptyBar = String.replicate empty "░"
        sprintf "  %s%-15s%s [%s%s%s%s%s] %.1f%%" Ansi.dim label Ansi.reset color filledBar Ansi.dim emptyBar Ansi.reset (value * 100.0)

    let renderHealthView () : string list =
        let summary = getSummary()
        let health = getHealth()

        [
            sprintf "%s🏥 SYSTEM HEALTH%s" Ansi.bold Ansi.reset
            sprintf "%s──────────────────────────────────────────%s" Ansi.dim Ansi.reset
            ""
            sprintf "  Total Holons:    %s%d%s" Ansi.advisory summary.TotalHolons Ansi.reset
            sprintf "  Root Holons:     %s%d%s" Ansi.normal summary.RootCount Ansi.reset
            sprintf "  Event Count:     %s%d%s" Ansi.normal summary.EventCount Ansi.reset
            sprintf "  Last Update:     %s%s%s" Ansi.dim summary.LastUpdate Ansi.reset
            ""
        ] @
        (match summary.HealthScore with
         | Some score -> [renderHealthBar "Overall Health" score 30]
         | None -> [sprintf "  %sHealth data not available%s" Ansi.dim Ansi.reset]) @
        [
            ""
            sprintf "  %sHolons by Type:%s" Ansi.dim Ansi.reset
        ] @
        (summary.ByType |> Map.toList |> List.map (fun (t, count) ->
            sprintf "    %s %-15s %d" (typeIcon t) t count
        ))

    // ═══════════════════════════════════════════════════════════════════════════
    // RENDERING - ENTROPY VIEW
    // ═══════════════════════════════════════════════════════════════════════════

    let renderEntropyView () : string list =
        let summary = getSummary()
        let entropy = getEntropy()

        [
            sprintf "%s🔥 ENTROPY / STALE KNOWLEDGE%s" Ansi.bold Ansi.reset
            sprintf "%s──────────────────────────────────────────%s" Ansi.dim Ansi.reset
            ""
        ] @
        (match entropy with
         | Some e ->
             [
                 sprintf "  Threshold:       %s%.0f days%s" Ansi.caution e.Threshold Ansi.reset
                 sprintf "  Stale Count:     %s%s%s"
                     (if summary.StaleCount.IsSome && summary.StaleCount.Value > 0 then Ansi.warning else Ansi.connected)
                     (match summary.StaleCount with Some c -> string c | None -> "0")
                     Ansi.reset
                 ""
                 sprintf "  %sStale holons require attention:%s" Ansi.dim Ansi.reset
             ]
         | None ->
             [sprintf "  %sEntropy data not available%s" Ansi.dim Ansi.reset])

    // ═══════════════════════════════════════════════════════════════════════════
    // RENDERING - HOLON DETAIL PANEL
    // ═══════════════════════════════════════════════════════════════════════════

    let renderHolonDetail (holonId: string) : string list =
        match getHolon holonId with
        | Some holon ->
            let children = getChildren holonId
            [
                sprintf "%s📖 HOLON DETAIL%s" Ansi.bold Ansi.reset
                sprintf "%s──────────────────────────────────────────%s" Ansi.dim Ansi.reset
                ""
                sprintf "  %sID:%s       %s" Ansi.dim Ansi.reset holon.Id
                sprintf "  %sName:%s     %s%s%s" Ansi.dim Ansi.reset Ansi.advisory holon.Name Ansi.reset
                sprintf "  %sType:%s     %s %s" Ansi.dim Ansi.reset (typeIcon holon.Type) holon.Type
                sprintf "  %sFQUN:%s     %s" Ansi.dim Ansi.reset (holon.Fqun |> Option.defaultValue "-")
                sprintf "  %sParent:%s   %s" Ansi.dim Ansi.reset (holon.ParentId |> Option.defaultValue "(root)")
                sprintf "  %sChildren:%s %d" Ansi.dim Ansi.reset (List.length children)
                ""
            ] @
            (match holon.VitalSigns with
             | Some vs ->
                 [
                     sprintf "  %sVital Signs:%s" Ansi.dim Ansi.reset
                     renderHealthBar "Health" vs.Health 20
                     renderHealthBar "Stress" vs.Stress 20
                     renderHealthBar "Energy" vs.Energy 20
                     renderHealthBar "Coherence" vs.Coherence 20
                 ]
             | None -> [])
        | None ->
            [sprintf "  %sHolon not found%s" Ansi.warning Ansi.reset]

    // ═══════════════════════════════════════════════════════════════════════════
    // MAIN RENDER
    // ═══════════════════════════════════════════════════════════════════════════

    let render (width: int) (height: int) : string list =
        let header = [
            sprintf "%s%s ═══════════════════════════════════════════════════════ %s" Ansi.bgBlue Ansi.brightWhite Ansi.reset
            sprintf "%s%s  📚 KNOWLEDGE MANAGEMENT SYSTEM                        %s" Ansi.bgBlue Ansi.brightWhite Ansi.reset
            sprintf "%s%s ═══════════════════════════════════════════════════════ %s" Ansi.bgBlue Ansi.brightWhite Ansi.reset
            ""
        ]

        let tabs = sprintf "  [%s1:Tree%s] [%s2:List%s] [%s3:Health%s] [%s4:Entropy%s]"
                       (if panelState.ViewMode = TreeView then Ansi.advisory else Ansi.dim) Ansi.reset
                       (if panelState.ViewMode = ListView then Ansi.advisory else Ansi.dim) Ansi.reset
                       (if panelState.ViewMode = HealthView then Ansi.advisory else Ansi.dim) Ansi.reset
                       (if panelState.ViewMode = EntropyView then Ansi.advisory else Ansi.dim) Ansi.reset

        let mainContent =
            match panelState.ViewMode with
            | TreeView -> renderTreeView()
            | ListView -> renderListView()
            | HealthView -> renderHealthView()
            | EntropyView -> renderEntropyView()

        let detailPanel =
            match panelState.SelectedHolonId with
            | Some id -> renderHolonDetail id
            | None -> []

        let footer = [
            ""
            sprintf "%s──────────────────────────────────────────%s" Ansi.dim Ansi.reset
            sprintf "%s  ↑↓:Navigate  Enter:Select  1-4:View  q:Back  r:Refresh%s" Ansi.dim Ansi.reset
        ]

        header @ [tabs; ""] @ mainContent @ detailPanel @ footer
        |> List.take (min height (List.length (header @ [tabs; ""] @ mainContent @ detailPanel @ footer)))

    // ═══════════════════════════════════════════════════════════════════════════
    // PANEL ACTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    let selectHolon (holonId: string option) =
        panelState <- { panelState with SelectedHolonId = holonId }

    let toggleExpand (holonId: string) =
        let expanded =
            if Set.contains holonId panelState.ExpandedNodes then
                Set.remove holonId panelState.ExpandedNodes
            else
                Set.add holonId panelState.ExpandedNodes
        panelState <- { panelState with ExpandedNodes = expanded }

    let setViewMode (mode: KmsViewMode) =
        panelState <- { panelState with ViewMode = mode }

    let setFilter (filterType: string option) =
        panelState <- { panelState with FilterType = filterType }

    let search (query: string) =
        panelState <- { panelState with SearchQuery = query }

    let refresh () =
        panelState <- { panelState with LastRefresh = DateTimeOffset.UtcNow }

    let expandAll () =
        let allIds = getHolons() |> List.map (fun h -> h.Id) |> Set.ofList
        panelState <- { panelState with ExpandedNodes = allIds }

    let collapseAll () =
        panelState <- { panelState with ExpandedNodes = Set.empty }

    // ═══════════════════════════════════════════════════════════════════════════
    // KEYBOARD HANDLING
    // ═══════════════════════════════════════════════════════════════════════════

    type KeyAction =
        | NavigateUp
        | NavigateDown
        | Select
        | Back
        | ViewTree
        | ViewList
        | ViewHealth
        | ViewEntropy
        | Refresh
        | ExpandToggle
        | Unknown

    let handleKey (key: ConsoleKeyInfo) : KeyAction =
        match key.Key with
        | ConsoleKey.UpArrow -> NavigateUp
        | ConsoleKey.DownArrow -> NavigateDown
        | ConsoleKey.Enter -> Select
        | ConsoleKey.Escape | ConsoleKey.Q -> Back
        | ConsoleKey.R -> Refresh
        | ConsoleKey.Spacebar -> ExpandToggle
        | ConsoleKey.D1 -> ViewTree
        | ConsoleKey.D2 -> ViewList
        | ConsoleKey.D3 -> ViewHealth
        | ConsoleKey.D4 -> ViewEntropy
        | _ -> Unknown

    // ═══════════════════════════════════════════════════════════════════════════
    // INITIALIZATION
    // ═══════════════════════════════════════════════════════════════════════════

    let initialize () =
        // Initialize KmsSubscriber with default handlers
        initializeDefault()
        panelState <- {
            SelectedHolonId = None
            ExpandedNodes = Set.empty
            ViewMode = TreeView
            FilterType = None
            SearchQuery = ""
            LastRefresh = DateTimeOffset.UtcNow
        }
        printfn "[KmsPanel] Initialized"

    let shutdown () =
        close()
        printfn "[KmsPanel] Shutdown"
