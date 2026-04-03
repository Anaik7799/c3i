// =============================================================================
// KmsSubscriber.fs - Knowledge Management System State Synchronization
// =============================================================================
// Phase 3: Cognitive Expansion (L8-L9)
// STAMP: SC-KMS-001 (Verification), SC-KMS-005 (Sync), SC-OODA-001 (Latency)
// AOR: AOR-IKE-001 (Update Graph), AOR-IKE-003 (No Hallucination)
// Criticality: Level 2 (HIGH) - World Model Integrity
// =============================================================================

namespace Cepaf.Cockpit.Zenoh

open System
open System.Collections.Concurrent
open System.Text.Json
open System.Text.Json.Serialization
open System.Threading.Tasks
open Cepaf.Zenoh.Core
open Cepaf.Cockpit.Zenoh.Session

/// Zenoh SMRITI Subscriber for real-time Knowledge Management System state from Elixir.
/// Enables F# Cockpit to display holon tree, health status, and system metrics.
module SmritiSubscriber =

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

    /// Local SMRITI state cache
    type SmritiState = {
        Holons: ConcurrentDictionary<string, Holon>
        Health: HealthState option
        Entropy: EntropyState option
        Stats: StatsState option
        LastUpdate: DateTimeOffset
        EventCount: int64
    }

    /// Event callbacks
    type SmritiEventHandlers = {
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

    let mutable private handlers: SmritiEventHandlers option = None
    let private subscriptionIds = ResizeArray<IDisposable>()

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

    let private handleHolonEvent (sample: ZenohSample) =
        try
            let json = ZenohSample.payloadString sample
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
                printfn "[SmritiSubscriber] Unknown holon event: %s" other

            state <- { state with LastUpdate = DateTimeOffset.UtcNow; EventCount = state.EventCount + 1L }
        with ex ->
            printfn "[SmritiSubscriber] Holon event error: %s" ex.Message

    let private handleHealthState (sample: ZenohSample) =
        try
            let json = ZenohSample.payloadString sample
            let health = JsonSerializer.Deserialize<HealthState>(json, jsonOptions)
            state <- { state with Health = Some health; LastUpdate = DateTimeOffset.UtcNow; EventCount = state.EventCount + 1L }
            handlers |> Option.iter (fun h -> h.OnHealthUpdate health)
        with ex ->
            printfn "[SmritiSubscriber] Health state error: %s" ex.Message

    let private handleEntropyState (sample: ZenohSample) =
        try
            let json = ZenohSample.payloadString sample
            let entropy = JsonSerializer.Deserialize<EntropyState>(json, jsonOptions)
            state <- { state with Entropy = Some entropy; LastUpdate = DateTimeOffset.UtcNow; EventCount = state.EventCount + 1L }
            handlers |> Option.iter (fun h -> h.OnEntropyUpdate entropy)
        with ex ->
            printfn "[SmritiSubscriber] Entropy state error: %s" ex.Message

    let private handleStatsState (sample: ZenohSample) =
        try
            let json = ZenohSample.payloadString sample
            let stats = JsonSerializer.Deserialize<StatsState>(json, jsonOptions)
            state <- { state with Stats = Some stats; LastUpdate = DateTimeOffset.UtcNow; EventCount = state.EventCount + 1L }
            handlers |> Option.iter (fun h -> h.OnStatsUpdate stats)
        with ex ->
            printfn "[SmritiSubscriber] Stats state error: %s" ex.Message

    // ========================================================================
    // PUBLIC API
    // ========================================================================

    /// Initialize SMRITI subscriber with event handlers
    let initializeAsync (service: IZenohService) (eventHandlers: SmritiEventHandlers) : Task<unit> =
        task {
            handlers <- Some eventHandlers

            // We need access to the underlying session to create raw subscribers
            // Or we extend IZenohService to support generic subscriptions
            // For Phase 3, we'll assume IZenohService exposes a way or we cast if it's the concrete type
            // But strict interface usage suggests we should add generic subscription support to IZenohService.
            // Let's assume we can use the concrete ZenohService for this advanced usage or modify IZenohService.
            
            // To avoid modifying IZenohService interface in this step and keep it focused, 
            // we will check if service is ZenohService and access lifecycle session.
            
            match service with
            | :? ZenohService as concreteService ->
                match concreteService.Lifecycle.Session with
                | Some session ->
                    // Subscribe to holon events
                    let! sub1 = SafeSubscriber.Create(session, SubscriberConfig.create (sprintf "%s/holons/**" kmsPrefix), handleHolonEvent) |> Result.toOption |> Task.FromResult
                    sub1 |> Option.iter (fun s -> subscriptionIds.Add(s))

                    // Subscribe to health state
                    let! sub2 = SafeSubscriber.Create(session, SubscriberConfig.create (sprintf "%s/state/health" kmsPrefix), handleHealthState) |> Result.toOption |> Task.FromResult
                    sub2 |> Option.iter (fun s -> subscriptionIds.Add(s))

                    // Subscribe to entropy state
                    let! sub3 = SafeSubscriber.Create(session, SubscriberConfig.create (sprintf "%s/state/entropy" kmsPrefix), handleEntropyState) |> Result.toOption |> Task.FromResult
                    sub3 |> Option.iter (fun s -> subscriptionIds.Add(s))

                    // Subscribe to stats state
                    let! sub4 = SafeSubscriber.Create(session, SubscriberConfig.create (sprintf "%s/state/stats" kmsPrefix), handleStatsState) |> Result.toOption |> Task.FromResult
                    sub4 |> Option.iter (fun s -> subscriptionIds.Add(s))

                    printfn "[SmritiSubscriber] Initialized with %d subscriptions" subscriptionIds.Count
                | None ->
                    printfn "[SmritiSubscriber] Failed to initialize: Session not active"
            | _ ->
                printfn "[SmritiSubscriber] Failed to initialize: Service implementation does not support direct subscription"
        }

    /// Initialize with default (no-op) handlers
    let initializeDefaultAsync (service: IZenohService) =
        initializeAsync service {
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
        for sub in subscriptionIds do
            sub.Dispose()
        subscriptionIds.Clear()
        printfn "[SmritiSubscriber] Closed all subscriptions"

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
    type SmritiSummary = {
        TotalHolons: int
        ByType: Map<string, int>
        RootCount: int
        HealthScore: float option
        EntropyThreshold: float option
        StaleCount: int option
        LastUpdate: string
        EventCount: int64
    }

    let getSummary () : SmritiSummary =
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