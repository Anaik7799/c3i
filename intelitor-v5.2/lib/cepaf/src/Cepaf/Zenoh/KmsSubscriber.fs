namespace Cepaf.Zenoh

open System
open System.Collections.Concurrent
open System.Text.Json
open System.Text.Json.Serialization

/// Zenoh KMS Subscriber for real-time Knowledge Management System state from Elixir.
/// Enables F# Cockpit to display holon tree, health status, and system metrics.
///
/// ## STAMP Constraints
/// - SC-KMS-005: Cross-runtime state sync via Zenoh
/// - SC-ZENOH-INT-001: Universal Zenoh access
/// - SC-OODA-001: <100ms state update latency
///
/// ## Key Expression Schema
/// - indrajaal/kms/holons/created - New holon created
/// - indrajaal/kms/holons/updated - Holon updated
/// - indrajaal/kms/holons/deleted - Holon deleted
/// - indrajaal/kms/state/health - Health report (vital signs aggregate)
/// - indrajaal/kms/state/entropy - Entropy report (stale holons)
/// - indrajaal/kms/state/stats - Event statistics
module KmsSubscriber =

    // ========================================================================
    // TYPES
    // ========================================================================

    /// Holon type enumeration
    type HolonType =
        | Knowledge
        | Process
        | Agent
        | Artifact
        | Index

    /// Vital signs for holon health
    type VitalSigns = {
        Health: float
        Stress: float
        Energy: float
        Coherence: float
    }

    /// Holon data structure (matches Elixir schema)
    type Holon = {
        Id: string
        Fqun: string option
        Type: string
        Name: string
        ParentId: string option
        VitalSigns: VitalSigns option
        HlcPhysical: int64 option
        HlcLogical: int option
    }

    /// Holon event from Zenoh
    type HolonEvent = {
        Event: string
        Holon: Holon
        Timestamp: string
        Source: string
        Sequence: int
        Version: string
    }

    /// Health state report
    type HealthState = {
        Type: string
        Data: JsonElement
        Timestamp: string
        Source: string
        Sequence: int
        Version: string
    }

    /// Entropy state report
    type EntropyState = {
        Type: string
        Data: JsonElement
        Threshold: float
        Timestamp: string
        Source: string
        Sequence: int
        Version: string
    }

    /// Stats state report
    type StatsState = {
        Type: string
        Data: JsonElement
        Timestamp: string
        Source: string
        Sequence: int
        Version: string
    }

    /// Local KMS state cache
    type KmsState = {
        Holons: ConcurrentDictionary<string, Holon>
        Health: HealthState option
        Entropy: EntropyState option
        Stats: StatsState option
        LastUpdate: DateTimeOffset
        EventCount: int64
    }

    /// Event callbacks
    type KmsEventHandlers = {
        OnHolonCreated: Holon -> unit
        OnHolonUpdated: Holon -> unit
        OnHolonDeleted: string -> unit
        OnHealthUpdate: HealthState -> unit
        OnEntropyUpdate: EntropyState -> unit
        OnStatsUpdate: StatsState -> unit
    }

    // ========================================================================
    // STATE
    // ========================================================================

    let private kmsPrefix = "indrajaal/kms"

    let mutable private state = {
        Holons = ConcurrentDictionary<string, Holon>()
        Health = None
        Entropy = None
        Stats = None
        LastUpdate = DateTimeOffset.MinValue
        EventCount = 0L
    }

    let mutable private handlers: KmsEventHandlers option = None
    let private subscriptionIds = ResizeArray<string>()

    // ========================================================================
    // JSON OPTIONS
    // ========================================================================

    let private jsonOptions =
        let opts = JsonSerializerOptions()
        opts.PropertyNameCaseInsensitive <- true
        opts.PropertyNamingPolicy <- JsonNamingPolicy.SnakeCaseLower
        opts

    // ========================================================================
    // HANDLERS
    // ========================================================================

    let private handleHolonEvent (msg: ZenohSession.ZenohMessage) =
        try
            let json = System.Text.Encoding.UTF8.GetString(msg.Payload)
            let evt = JsonSerializer.Deserialize<HolonEvent>(json, jsonOptions)

            match evt.Event with
            | "created" ->
                state.Holons.[evt.Holon.Id] <- evt.Holon
                handlers |> Option.iter (fun h -> h.OnHolonCreated evt.Holon)

            | "updated" ->
                state.Holons.[evt.Holon.Id] <- evt.Holon
                handlers |> Option.iter (fun h -> h.OnHolonUpdated evt.Holon)

            | "deleted" ->
                let mutable removed = Unchecked.defaultof<Holon>
                state.Holons.TryRemove(evt.Holon.Id, &removed) |> ignore
                handlers |> Option.iter (fun h -> h.OnHolonDeleted evt.Holon.Id)

            | other ->
                printfn "[KmsSubscriber] Unknown holon event: %s" other

            state <- { state with LastUpdate = DateTimeOffset.UtcNow; EventCount = state.EventCount + 1L }
        with ex ->
            printfn "[KmsSubscriber] Holon event error: %s" ex.Message

    let private handleHealthState (msg: ZenohSession.ZenohMessage) =
        try
            let json = System.Text.Encoding.UTF8.GetString(msg.Payload)
            let health = JsonSerializer.Deserialize<HealthState>(json, jsonOptions)
            state <- { state with Health = Some health; LastUpdate = DateTimeOffset.UtcNow; EventCount = state.EventCount + 1L }
            handlers |> Option.iter (fun h -> h.OnHealthUpdate health)
        with ex ->
            printfn "[KmsSubscriber] Health state error: %s" ex.Message

    let private handleEntropyState (msg: ZenohSession.ZenohMessage) =
        try
            let json = System.Text.Encoding.UTF8.GetString(msg.Payload)
            let entropy = JsonSerializer.Deserialize<EntropyState>(json, jsonOptions)
            state <- { state with Entropy = Some entropy; LastUpdate = DateTimeOffset.UtcNow; EventCount = state.EventCount + 1L }
            handlers |> Option.iter (fun h -> h.OnEntropyUpdate entropy)
        with ex ->
            printfn "[KmsSubscriber] Entropy state error: %s" ex.Message

    let private handleStatsState (msg: ZenohSession.ZenohMessage) =
        try
            let json = System.Text.Encoding.UTF8.GetString(msg.Payload)
            let stats = JsonSerializer.Deserialize<StatsState>(json, jsonOptions)
            state <- { state with Stats = Some stats; LastUpdate = DateTimeOffset.UtcNow; EventCount = state.EventCount + 1L }
            handlers |> Option.iter (fun h -> h.OnStatsUpdate stats)
        with ex ->
            printfn "[KmsSubscriber] Stats state error: %s" ex.Message

    // ========================================================================
    // PUBLIC API
    // ========================================================================

    /// Initialize KMS subscriber with event handlers
    let initialize (eventHandlers: KmsEventHandlers) =
        handlers <- Some eventHandlers

        // Subscribe to holon events
        match ZenohSession.subscribe (sprintf "%s/holons/+" kmsPrefix) handleHolonEvent with
        | Ok subId -> subscriptionIds.Add(subId)
        | Error err -> printfn "[KmsSubscriber] Holon subscription error: %s" err

        // Subscribe to health state
        match ZenohSession.subscribe (sprintf "%s/state/health" kmsPrefix) handleHealthState with
        | Ok subId -> subscriptionIds.Add(subId)
        | Error err -> printfn "[KmsSubscriber] Health subscription error: %s" err

        // Subscribe to entropy state
        match ZenohSession.subscribe (sprintf "%s/state/entropy" kmsPrefix) handleEntropyState with
        | Ok subId -> subscriptionIds.Add(subId)
        | Error err -> printfn "[KmsSubscriber] Entropy subscription error: %s" err

        // Subscribe to stats state
        match ZenohSession.subscribe (sprintf "%s/state/stats" kmsPrefix) handleStatsState with
        | Ok subId -> subscriptionIds.Add(subId)
        | Error err -> printfn "[KmsSubscriber] Stats subscription error: %s" err

        printfn "[KmsSubscriber] Initialized with %d subscriptions" subscriptionIds.Count

    /// Initialize with default (no-op) handlers
    let initializeDefault () =
        initialize {
            OnHolonCreated = ignore
            OnHolonUpdated = ignore
            OnHolonDeleted = ignore
            OnHealthUpdate = ignore
            OnEntropyUpdate = ignore
            OnStatsUpdate = ignore
        }

    /// Get current KMS state snapshot
    let getState () = state

    /// Get all holons
    let getHolons () =
        state.Holons.Values |> Seq.toList

    /// Get holon by ID
    let getHolon (id: string) =
        match state.Holons.TryGetValue(id) with
        | true, holon -> Some holon
        | false, _ -> None

    /// Get children of a holon
    let getChildren (parentId: string) =
        state.Holons.Values
        |> Seq.filter (fun h -> h.ParentId = Some parentId)
        |> Seq.toList

    /// Get root holons (no parent)
    let getRoots () =
        state.Holons.Values
        |> Seq.filter (fun h -> h.ParentId.IsNone)
        |> Seq.toList

    /// Get holons by type
    let getByType (holonType: string) =
        state.Holons.Values
        |> Seq.filter (fun h -> h.Type = holonType)
        |> Seq.toList

    /// Get current health state
    let getHealth () = state.Health

    /// Get current entropy state
    let getEntropy () = state.Entropy

    /// Get current stats state
    let getStats () = state.Stats

    /// Get last update timestamp
    let getLastUpdate () = state.LastUpdate

    /// Get total event count
    let getEventCount () = state.EventCount

    /// Close all subscriptions
    let close () =
        for subId in subscriptionIds do
            ZenohSession.unsubscribe subId |> ignore
        subscriptionIds.Clear()
        printfn "[KmsSubscriber] Closed all subscriptions"

    // ========================================================================
    // TREE BUILDING HELPERS
    // ========================================================================

    /// Build a tree structure from flat holon list
    type HolonTreeNode = {
        Holon: Holon
        Children: HolonTreeNode list
    }

    /// Build holon tree starting from roots
    let buildTree () =
        let rec buildNode (holon: Holon) =
            let children = getChildren holon.Id
            {
                Holon = holon
                Children = children |> List.map buildNode
            }
        getRoots() |> List.map buildNode

    /// Flatten tree to list with depth
    let flattenTree () =
        let rec flatten depth (node: HolonTreeNode) =
            seq {
                yield (depth, node.Holon)
                for child in node.Children do
                    yield! flatten (depth + 1) child
            }
        buildTree() |> Seq.collect (flatten 0) |> Seq.toList

    // ========================================================================
    // DASHBOARD INTEGRATION
    // ========================================================================

    /// Get summary for dashboard display
    type KmsSummary = {
        TotalHolons: int
        ByType: Map<string, int>
        RootCount: int
        HealthScore: float option
        EntropyThreshold: float option
        StaleCount: int option
        LastUpdate: string
        EventCount: int64
    }

    let getSummary () : KmsSummary =
        let holons = getHolons()
        let byType =
            holons
            |> List.groupBy (fun h -> h.Type)
            |> List.map (fun (t, hs) -> (t, List.length hs))
            |> Map.ofList

        {
            TotalHolons = List.length holons
            ByType = byType
            RootCount = getRoots() |> List.length
            HealthScore =
                state.Health
                |> Option.bind (fun h ->
                    try
                        Some (h.Data.GetProperty("overall_health").GetDouble())
                    with _ -> None
                )
            EntropyThreshold =
                state.Entropy
                |> Option.map (fun e -> e.Threshold)
            StaleCount =
                state.Entropy
                |> Option.bind (fun e ->
                    try
                        Some (e.Data.GetArrayLength())
                    with _ -> None
                )
            LastUpdate = state.LastUpdate.ToString("o")
            EventCount = state.EventCount
        }
