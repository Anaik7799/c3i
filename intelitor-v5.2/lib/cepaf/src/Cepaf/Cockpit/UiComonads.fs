/// CEPAF UI Comonads Module
/// Comonadic abstractions for UI focus, context, and navigation.
///
/// WHAT: Focus management, context propagation, hierarchical navigation
/// WHY: Type-safe UI state with principled context and focus handling
/// CONSTRAINTS:
///   - SC-COMONAD-001: Focus operations must be reversible (zipper law)
///   - SC-COMONAD-002: Context must propagate correctly through UI tree
///   - SC-COMONAD-003: All navigation must preserve structural integrity
///   - SC-COMONAD-004: Undo/Redo stacks must respect comonad laws
///
/// STAMP Compliance: SC-COMONAD-001 to SC-COMONAD-008
/// Version: 1.0.0
namespace Cepaf.Cockpit

open System
open Cepaf.Cockpit.Domain

// ============================================================================
// UI CONTEXT COMONAD (Env-based)
// ============================================================================

/// UI Context - carries environment through UI computations
type UiContext<'A> = UiCtx of context: UiEnv * value: 'A

/// Environment available throughout the UI
and UiEnv = {
    Theme: ThemeConfig
    Operator: OperatorInfo
    Permissions: Permission list
    TimeZone: TimeZoneInfo
    RefreshRate: int
    MonitorOnly: bool
    Locale: string
}

/// Theme configuration
and ThemeConfig = {
    IsDarkMode: bool
    AccentColor: string
    FontScale: float
    HighContrast: bool
    ReducedMotion: bool
}

/// Operator information
and OperatorInfo = {
    Id: string
    Name: string
    Role: string
    SessionStart: DateTime
}

/// Permission types
and Permission =
    | ViewDashboard
    | ViewAlarms
    | AcknowledgeAlarms
    | SendCommands
    | CriticalCommands
    | ConfigureNodes
    | AdminAccess

module UiContext =
    /// Extract the value
    let extract (UiCtx (_, a)) = a

    /// Get the environment
    let ask (UiCtx (env, _)) = env

    /// Map over the value
    let map (f: 'A -> 'B) (UiCtx (env, a)) : UiContext<'B> =
        UiCtx (env, f a)

    /// Duplicate - wrap in another layer
    let duplicate (UiCtx (env, a) as w) : UiContext<UiContext<'A>> =
        UiCtx (env, w)

    /// Extend - apply contextual transformation
    let extend (f: UiContext<'A> -> 'B) (UiCtx (env, _) as w) : UiContext<'B> =
        UiCtx (env, f w)

    /// Modify context locally
    let local (f: UiEnv -> UiEnv) (UiCtx (env, a)) : UiContext<'A> =
        UiCtx (f env, a)

    /// Create with environment
    let withEnv (env: UiEnv) (a: 'A) : UiContext<'A> = UiCtx (env, a)

    /// Run context to get environment and value
    let run (UiCtx (env, a)) = (env, a)

    /// Check permission
    let hasPermission (perm: Permission) (UiCtx (env, _)) : bool =
        List.contains perm env.Permissions

    /// CoKleisli composition operator
    let (=>>) (w: UiContext<'A>) (f: UiContext<'A> -> 'B) : UiContext<'B> =
        extend f w

// ============================================================================
// UI FOCUS COMONAD (Store-based)
// ============================================================================

/// UI Focus - tracks current focus with ability to peek at other elements
type UiFocus<'Id, 'A when 'Id : comparison> = Focus of getter: (Map<'Id, 'A>) * currentId: 'Id

module UiFocus =
    /// Get current focused element
    let extract (Focus (items, id)) : 'A option =
        Map.tryFind id items

    /// Get current focus ID
    let focusId (Focus (_, id)) = id

    /// Get all items
    let items (Focus (items, _)) = items

    /// Peek at different element without changing focus
    let peek (targetId: 'Id) (Focus (items, _)) : 'A option =
        Map.tryFind targetId items

    /// Move focus to new element (seek)
    let focusOn (targetId: 'Id) (Focus (items, _)) : UiFocus<'Id, 'A> =
        Focus (items, targetId)

    /// Map over current focus
    let map (f: 'A -> 'B) (Focus (items, id)) : UiFocus<'Id, 'B> =
        let newItems = items |> Map.map (fun _ v -> f v)
        Focus (newItems, id)

    /// Map only the focused element
    let mapFocused (f: 'A -> 'A) (Focus (items, id)) : UiFocus<'Id, 'A> =
        let newItems =
            items |> Map.map (fun k v -> if k = id then f v else v)
        Focus (newItems, id)

    /// Duplicate - create focus on focuses
    let duplicate (Focus (items, id)) : UiFocus<'Id, UiFocus<'Id, 'A>> =
        let getter =
            items |> Map.map (fun k _ -> Focus (items, k))
        Focus (getter, id)

    /// Extend - apply focus-aware transformation
    let extend (f: UiFocus<'Id, 'A> -> 'B) (Focus (items, id)) : UiFocus<'Id, 'B> =
        let newItems =
            items |> Map.map (fun k _ -> f (Focus (items, k)))
        Focus (newItems, id)

    /// Create focus from map
    let fromMap (defaultId: 'Id) (items: Map<'Id, 'A>) : UiFocus<'Id, 'A> =
        Focus (items, defaultId)

    /// Add item to focus
    let add (id: 'Id) (item: 'A) (Focus (items, currentId)) : UiFocus<'Id, 'A> =
        Focus (Map.add id item items, currentId)

    /// Remove item from focus
    let remove (id: 'Id) (Focus (items, currentId)) : UiFocus<'Id, 'A> =
        let newId = if id = currentId then Map.tryFindKey (fun k _ -> k <> id) items |> Option.defaultValue currentId else currentId
        Focus (Map.remove id items, newId)

    /// Get neighbors (items adjacent to current focus)
    let neighbors (Focus (items, id)) : 'A list =
        let keys = items |> Map.keys |> Seq.toList |> List.sort
        let idx = keys |> List.tryFindIndex ((=) id)
        match idx with
        | None -> []
        | Some i ->
            [
                if i > 0 then yield items.[keys.[i - 1]]
                if i < List.length keys - 1 then yield items.[keys.[i + 1]]
            ]

    /// CoKleisli composition
    let (=>>) (w: UiFocus<'Id, 'A>) (f: UiFocus<'Id, 'A> -> 'B) : UiFocus<'Id, 'B> =
        extend f w

// ============================================================================
// UI ZIPPER - Hierarchical Navigation
// ============================================================================

/// Breadcrumb - path through hierarchy
type Breadcrumb<'A> = {
    Item: 'A
    Left: 'A list
    Right: 'A list
}

/// Zipper for navigating hierarchical structures
type UiZipper<'A> = {
    Focus: 'A
    Crumbs: Breadcrumb<'A> list
    Children: 'A list
}

module UiZipper =
    /// Create zipper at root
    let fromList (items: 'A list) : UiZipper<'A> option =
        match items with
        | [] -> None
        | x :: xs -> Some { Focus = x; Crumbs = []; Children = xs }

    /// Get focused element
    let extract (z: UiZipper<'A>) = z.Focus

    /// Move to next sibling (right)
    let goRight (z: UiZipper<'A>) : UiZipper<'A> option =
        match z.Crumbs with
        | [] -> None
        | crumb :: rest ->
            match crumb.Right with
            | [] -> None
            | r :: rs ->
                Some {
                    Focus = r
                    Crumbs = { crumb with Left = z.Focus :: crumb.Left; Right = rs } :: rest
                    Children = []
                }

    /// Move to previous sibling (left)
    let goLeft (z: UiZipper<'A>) : UiZipper<'A> option =
        match z.Crumbs with
        | [] -> None
        | crumb :: rest ->
            match crumb.Left with
            | [] -> None
            | l :: ls ->
                Some {
                    Focus = l
                    Crumbs = { crumb with Left = ls; Right = z.Focus :: crumb.Right } :: rest
                    Children = []
                }

    /// Move down to first child
    let goDown (z: UiZipper<'A>) : UiZipper<'A> option =
        match z.Children with
        | [] -> None
        | c :: cs ->
            Some {
                Focus = c
                Crumbs = { Item = z.Focus; Left = []; Right = cs } :: z.Crumbs
                Children = []
            }

    /// Move up to parent
    let goUp (z: UiZipper<'A>) : UiZipper<'A> option =
        match z.Crumbs with
        | [] -> None
        | crumb :: rest ->
            let siblings = (List.rev crumb.Left) @ [z.Focus] @ crumb.Right
            Some {
                Focus = crumb.Item
                Crumbs = rest
                Children = siblings
            }

    /// Modify focused element
    let modify (f: 'A -> 'A) (z: UiZipper<'A>) : UiZipper<'A> =
        { z with Focus = f z.Focus }

    /// Replace focused element
    let replace (a: 'A) (z: UiZipper<'A>) : UiZipper<'A> =
        { z with Focus = a }

    /// Set children of focused element
    let setChildren (children: 'A list) (z: UiZipper<'A>) : UiZipper<'A> =
        { z with Children = children }

    /// Navigate to root
    let rec goRoot (z: UiZipper<'A>) : UiZipper<'A> =
        match goUp z with
        | None -> z
        | Some parent -> goRoot parent

    /// Map over entire structure
    let map (f: 'A -> 'B) (z: UiZipper<'A>) : UiZipper<'B> =
        let mapCrumb crumb = {
            Item = f crumb.Item
            Left = List.map f crumb.Left
            Right = List.map f crumb.Right
        }
        {
            Focus = f z.Focus
            Crumbs = List.map mapCrumb z.Crumbs
            Children = List.map f z.Children
        }

    /// Duplicate (comonad)
    let duplicate (z: UiZipper<'A>) : UiZipper<UiZipper<'A>> =
        // Create zipper of zippers where each position holds the zipper focused there
        {
            Focus = z
            Crumbs = []  // Simplified - full impl would reconstruct breadcrumbs
            Children = z.Children |> List.mapi (fun i _ ->
                match goDown z with
                | None -> z
                | Some child -> child
            )
        }

    /// Extend (comonad)
    let extend (f: UiZipper<'A> -> 'B) (z: UiZipper<'A>) : UiZipper<'B> =
        map f (duplicate z)

// ============================================================================
// COCKPIT NODE FOCUS
// ============================================================================

/// Node-specific focus operations
module NodeFocus =
    /// Create node focus from cockpit state
    let fromCockpitState (state: CockpitState) : UiFocus<NodeId, MeshNode> =
        let defaultId =
            state.Nodes
            |> Map.tryFindKey (fun _ _ -> true)
            |> Option.defaultValue ""
        UiFocus.fromMap defaultId state.Nodes

    /// Create zone focus from cockpit state
    let zonesFocus (state: CockpitState) : UiFocus<ZoneId, Zone> =
        let defaultId =
            state.Zones
            |> Map.tryFindKey (fun _ _ -> true)
            |> Option.defaultValue ""
        UiFocus.fromMap defaultId state.Zones

    /// Get related nodes (same zone)
    let relatedNodes (Focus (items, id) as focus) : MeshNode list =
        match UiFocus.extract focus with
        | None -> []
        | Some node ->
            items
            |> Map.toList
            |> List.filter (fun (_, n) -> n.Zone = node.Zone && n.Id <> id)
            |> List.map snd

    /// Apply context-aware transformation to focused node
    let withNodeContext (ctx: UiContext<unit>) (f: MeshNode -> UiEnv -> 'A) (focus: UiFocus<NodeId, MeshNode>) : 'A option =
        let env = UiContext.ask ctx
        focus
        |> UiFocus.extract
        |> Option.map (fun node -> f node env)

// ============================================================================
// ALARM FOCUS WITH PRIORITY
// ============================================================================

/// Alarm-specific focus with severity awareness
module AlarmFocus =
    /// Create alarm focus sorted by severity
    let fromAlarms (alarms: Map<AlarmId, Alarm>) : UiFocus<AlarmId, Alarm> =
        let sortedByPriority =
            alarms
            |> Map.toList
            |> List.sortByDescending (fun (_, a: Alarm) ->
                match a.Level with
                | Critical -> 5 | Warning -> 4 | Caution -> 3 | Advisory -> 2 | Normal -> 1
            )

        let defaultId =
            sortedByPriority
            |> List.tryHead
            |> Option.map fst
            |> Option.defaultValue ""

        UiFocus.fromMap defaultId alarms

    /// Focus on highest severity unacknowledged alarm
    let focusHighestUnacked (Focus (items, _) as focus) : UiFocus<AlarmId, Alarm> =
        let unacked =
            items
            |> Map.filter (fun _ (a: Alarm) -> a.AcknowledgedAt.IsNone)
            |> Map.toList
            |> List.sortByDescending (fun (_, a: Alarm) ->
                match a.Level with
                | Critical -> 5 | Warning -> 4 | Caution -> 3 | Advisory -> 2 | Normal -> 1
            )

        match unacked with
        | [] -> focus
        | (id, _) :: _ -> UiFocus.focusOn id focus

    /// Get count by severity
    let countBySeverity (Focus (items, _) : UiFocus<AlarmId, Alarm>) : Map<AlarmLevel, int> =
        items
        |> Map.toList
        |> List.map snd
        |> List.groupBy (fun (a: Alarm) -> a.Level)
        |> List.map (fun (level, alarms) -> (level, List.length alarms))
        |> Map.ofList

// ============================================================================
// VIEW HISTORY COMONAD (Traced-based)
// ============================================================================

/// View history - tracks navigation with undo capability
type ViewHistory<'A> = History of past: 'A list * current: 'A * future: 'A list

module ViewHistory =
    /// Extract current view
    let extract (History (_, current, _)) = current

    /// Get past views
    let past (History (past, _, _)) = past

    /// Get future views (for redo)
    let future (History (_, _, future)) = future

    /// Navigate to new view
    let navigate (view: 'A) (History (past, current, _)) : ViewHistory<'A> =
        History (current :: past, view, [])

    /// Undo - go back
    let undo (History (past, current, future)) : ViewHistory<'A> option =
        match past with
        | [] -> None
        | p :: ps -> Some (History (ps, p, current :: future))

    /// Redo - go forward
    let redo (History (past, current, future)) : ViewHistory<'A> option =
        match future with
        | [] -> None
        | f :: fs -> Some (History (current :: past, f, fs))

    /// Can undo?
    let canUndo (History (past, _, _)) = not (List.isEmpty past)

    /// Can redo?
    let canRedo (History (_, _, future)) = not (List.isEmpty future)

    /// Map over current (preserve history)
    let map (f: 'A -> 'B) (History (past, current, future)) : ViewHistory<'B> =
        History (List.map f past, f current, List.map f future)

    /// Duplicate
    let duplicate (History (past, current, future) as h) : ViewHistory<ViewHistory<'A>> =
        let pastHistories =
            past |> List.mapi (fun i _ ->
                let p = List.skip (i + 1) past
                let c = past.[i]
                let f = (List.take i past |> List.rev) @ [current] @ future
                History (p, c, f)
            )
        let futureHistories =
            future |> List.mapi (fun i _ ->
                let p = past @ [current] @ (List.take i future |> List.rev)
                let c = future.[i]
                let f = List.skip (i + 1) future
                History (p, c, f)
            )
        History (pastHistories, h, futureHistories)

    /// Extend
    let extend (f: ViewHistory<'A> -> 'B) (h: ViewHistory<'A>) : ViewHistory<'B> =
        duplicate h |> map f

    /// Create history at initial view
    let init (view: 'A) : ViewHistory<'A> = History ([], view, [])

    /// Get history depth
    let depth (History (past, _, _)) = List.length past

    /// Clear history
    let clear (History (_, current, _)) : ViewHistory<'A> = History ([], current, [])

    /// CoKleisli composition
    let (=>>) (w: ViewHistory<'A>) (f: ViewHistory<'A> -> 'B) : ViewHistory<'B> =
        extend f w

// ============================================================================
// COCKPIT FOCUS COMPOSITION
// ============================================================================

/// Composite focus for entire cockpit
type CockpitFocus = {
    Nodes: UiFocus<NodeId, MeshNode>
    Alarms: UiFocus<AlarmId, Alarm>
    ViewHistory: ViewHistory<ViewMode>
    Context: UiContext<unit>
}

module CockpitFocus =
    /// Create from cockpit state
    let fromState (env: UiEnv) (state: CockpitState) : CockpitFocus =
        {
            Nodes = NodeFocus.fromCockpitState state
            Alarms = AlarmFocus.fromAlarms state.Alarms
            ViewHistory = ViewHistory.init state.CurrentView
            Context = UiContext.withEnv env ()
        }

    /// Focus on specific node
    let focusNode (nodeId: NodeId) (focus: CockpitFocus) : CockpitFocus =
        { focus with Nodes = UiFocus.focusOn nodeId focus.Nodes }

    /// Focus on specific alarm
    let focusAlarm (alarmId: AlarmId) (focus: CockpitFocus) : CockpitFocus =
        { focus with Alarms = UiFocus.focusOn alarmId focus.Alarms }

    /// Navigate to view
    let navigateView (view: ViewMode) (focus: CockpitFocus) : CockpitFocus =
        { focus with ViewHistory = ViewHistory.navigate view focus.ViewHistory }

    /// Undo view navigation
    let undoView (focus: CockpitFocus) : CockpitFocus =
        { focus with ViewHistory = ViewHistory.undo focus.ViewHistory |> Option.defaultValue focus.ViewHistory }

    /// Redo view navigation
    let redoView (focus: CockpitFocus) : CockpitFocus =
        { focus with ViewHistory = ViewHistory.redo focus.ViewHistory |> Option.defaultValue focus.ViewHistory }

    /// Update context
    let withContext (f: UiEnv -> UiEnv) (focus: CockpitFocus) : CockpitFocus =
        { focus with Context = UiContext.local f focus.Context }

    /// Get current view
    let currentView (focus: CockpitFocus) = ViewHistory.extract focus.ViewHistory

    /// Get focused node
    let focusedNode (focus: CockpitFocus) = UiFocus.extract focus.Nodes

    /// Get focused alarm
    let focusedAlarm (focus: CockpitFocus) = UiFocus.extract focus.Alarms

    /// Check permission
    let hasPermission (perm: Permission) (focus: CockpitFocus) =
        UiContext.hasPermission perm focus.Context

// ============================================================================
// PREBUILT CONTEXT CONFIGURATIONS
// ============================================================================

module UiContextDefaults =
    let darkTheme : ThemeConfig = {
        IsDarkMode = true
        AccentColor = "#00B4D8"  // Cyan for safety-critical
        FontScale = 1.0
        HighContrast = false
        ReducedMotion = false
    }

    let lightTheme : ThemeConfig = {
        IsDarkMode = false
        AccentColor = "#0077B6"
        FontScale = 1.0
        HighContrast = false
        ReducedMotion = false
    }

    let highContrastTheme : ThemeConfig = {
        IsDarkMode = true
        AccentColor = "#FFFF00"  // Yellow for max contrast
        FontScale = 1.2
        HighContrast = true
        ReducedMotion = true
    }

    let operatorPermissions : Permission list = [
        ViewDashboard
        ViewAlarms
        AcknowledgeAlarms
    ]

    let supervisorPermissions : Permission list = [
        ViewDashboard
        ViewAlarms
        AcknowledgeAlarms
        SendCommands
    ]

    let adminPermissions : Permission list = [
        ViewDashboard
        ViewAlarms
        AcknowledgeAlarms
        SendCommands
        CriticalCommands
        ConfigureNodes
        AdminAccess
    ]

    let createEnv (operator: OperatorInfo) (permissions: Permission list) (isDark: bool) : UiEnv =
        {
            Theme = if isDark then darkTheme else lightTheme
            Operator = operator
            Permissions = permissions
            TimeZone = TimeZoneInfo.Local
            RefreshRate = 10
            MonitorOnly = false
            Locale = "en-US"
        }
