namespace Cepaf.Observability.Fractal

open System
open System.Collections.Concurrent
open System.Threading

/// FractalControl: Central state manager for the Fractal Logging System.
/// Implements Zenoh-style pub/sub with ETS-like concurrent access patterns.
/// STAMP Compliance: SC-LOG-001 (async), SC-LOG-002 (throttle), SC-LOG-005 (TTL)
module FractalControl =

    // ============================================================
    // STATE DEFINITIONS
    // ============================================================

    /// Subscriber information for Zenoh-style pub/sub
    type SubscriberInfo = {
        Id: string
        KeyExpr: string
        CompiledExpr: System.Text.RegularExpressions.Regex option
        Level: FractalLevel
        Callback: FractalLogEntry -> unit
        CreatedAt: DateTimeOffset
    }

    /// Publisher registration for write filtering
    type PublisherInfo = {
        Id: string
        KeyExpr: string
        Level: FractalLevel
        RegisteredAt: DateTimeOffset
    }

    /// Load shedding state
    type SheddingState = {
        Active: bool
        Reason: string option
        ActivatedAt: DateTimeOffset option
        CpuThreshold: float
        MemoryThreshold: float
    }

    /// Metrics for observability
    type FractalMetrics = {
        mutable EmitCount: int64
        DropCount: ConcurrentDictionary<FractalLevel, int64>
        mutable BoostCount: int
        mutable SubscriberCount: int
        mutable LastEmitTime: DateTimeOffset option
    }

    /// Central FractalControl state
    type State = {
        // Core configuration
        DefaultPolicy: FractalLevel
        Policies: ConcurrentDictionary<string, FractalLevel>

        // Active boosts with TTL (SC-LOG-005)
        Boosts: ConcurrentDictionary<string, Boost>

        // Zenoh-style subscriptions
        Subscribers: ConcurrentDictionary<string, SubscriberInfo>
        Publishers: ConcurrentDictionary<string, PublisherInfo>

        // Key alias registry (SC-LOG-009)
        KeyAliases: ConcurrentDictionary<string, uint16>
        AliasLookup: ConcurrentDictionary<uint16, string>
        mutable NextAlias: uint16

        // Load shedding (SC-LOG-002)
        mutable Shedding: SheddingState

        // HLC state
        mutable HLCPhysical: int64
        mutable HLCCounter: int
        NodeId: string

        // Metrics
        Metrics: FractalMetrics

        // Lock for state modifications
        Lock: obj
    }

    // ============================================================
    // GLOBAL STATE (Thread-Safe)
    // ============================================================

    let private defaultShedding = {
        Active = false
        Reason = None
        ActivatedAt = None
        CpuThreshold = 90.0
        MemoryThreshold = 85.0
    }

    // ============================================================
    // FRACTAL LEVEL HELPERS (SC-FSH-060)
    // ============================================================

    /// Compare levels by integer value
    let levelGreaterOrEqual (a: FractalLevel) (b: FractalLevel) : bool =
        FractalLevel.toInt a >= FractalLevel.toInt b

    /// Get sampling rate for a level during shedding (SC-FSH-060)
    /// Returns a value between 0.0 and 1.0 representing the sampling rate
    let getSamplingRateForShedding (level: FractalLevel) (shedding: bool) : float =
        if shedding then
            // During shedding, only sample L4/L5
            match level with
            | FractalLevel.L4 | FractalLevel.L5 -> 1.0
            | _ -> 0.0
        else
            // Normal mode: full sampling for all levels
            1.0

    /// Check if we should sample this log based on rate
    let shouldSampleWithRate (rate: float) : bool =
        if rate >= 1.0 then true
        elif rate <= 0.0 then false
        else System.Random().NextDouble() < rate

    let private defaultMetrics = {
        EmitCount = 0L
        DropCount = ConcurrentDictionary<FractalLevel, int64>()
        BoostCount = 0
        SubscriberCount = 0
        LastEmitTime = None
    }

    let mutable private state: State option = None
    let private initLock = obj()

    /// Initialize FractalControl with default configuration
    let initialize () =
        lock initLock (fun () ->
            match state with
            | Some _ -> ()  // Already initialized
            | None ->
                state <- Some {
                    DefaultPolicy = FractalLevel.L4
                    Policies = ConcurrentDictionary<string, FractalLevel>()
                    Boosts = ConcurrentDictionary<string, Boost>()
                    Subscribers = ConcurrentDictionary<string, SubscriberInfo>()
                    Publishers = ConcurrentDictionary<string, PublisherInfo>()
                    KeyAliases = ConcurrentDictionary<string, uint16>()
                    AliasLookup = ConcurrentDictionary<uint16, string>()
                    NextAlias = 1us
                    Shedding = defaultShedding
                    HLCPhysical = 0L
                    HLCCounter = 0
                    NodeId = Environment.MachineName
                    Metrics = defaultMetrics
                    Lock = obj()
                }
        )

    /// Get current state (initializes if needed)
    let private getState () =
        match state with
        | Some s -> s
        | None ->
            initialize()
            state.Value

    // ============================================================
    // POLICY MANAGEMENT
    // ============================================================

    /// Set default policy for all modules
    let setDefaultPolicy (level: FractalLevel) =
        let s = getState()
        lock s.Lock (fun () ->
            { s with DefaultPolicy = level } |> ignore
        )

    /// Set policy for specific module/key expression
    let setPolicy (keyExpr: string) (level: FractalLevel) =
        let s = getState()
        s.Policies.[keyExpr] <- level

    /// Get effective policy for a key
    let getPolicy (key: string) : FractalLevel =
        let s = getState()

        // Check specific policies first (longest match wins)
        let matchingPolicies =
            s.Policies
            |> Seq.filter (fun kvp -> key.StartsWith(kvp.Key) || kvp.Key = "*" || kvp.Key = "**")
            |> Seq.sortByDescending (fun kvp -> kvp.Key.Length)
            |> Seq.tryHead

        match matchingPolicies with
        | Some kvp -> kvp.Value
        | None -> s.DefaultPolicy

    // ============================================================
    // DEPTH CHECKING (O(1) via ConcurrentDictionary)
    // ============================================================

    /// Check if logging is enabled for a key at a specific level
    /// This is the HOT PATH - must be < 1µs
    /// SC-FSH-060: Uses type-safe level comparison and sampling
    let depthEnabled (key: string) (level: FractalLevel) : bool =
        let s = getState()

        // SC-FSH-060: Get sampling rate based on shedding state
        let samplingRate = getSamplingRateForShedding level s.Shedding.Active

        // Fast path: Check if sampling rate allows this log
        if not (shouldSampleWithRate samplingRate) then
            false
        else
            // Normal path: Check policy with level comparison
            let policy = getPolicy key
            levelGreaterOrEqual level policy

    /// Check if any boost matches the key and context
    let boostMatches (key: string) (baggage: Map<string, string>) : bool =
        let s = getState()
        let now = DateTimeOffset.UtcNow

        s.Boosts.Values
        |> Seq.exists (fun boost ->
            // Check expiration first (fast fail)
            if boost.ExpiresAt < now then
                false
            else
                // Check key expression match
                let keyMatches =
                    match boost.CompiledPattern with
                    | Some regex -> regex.IsMatch(key)
                    | None -> key.StartsWith(boost.KeyExpr) || boost.KeyExpr = "**"

                // Check filter match
                let filterMatches =
                    boost.Filter
                    |> Map.forall (fun k v ->
                        match baggage |> Map.tryFind k with
                        | Some bagVal -> bagVal = v
                        | None -> false
                    )

                keyMatches && filterMatches
        )

    /// Combined check: depth enabled OR boost matches
    let shouldLog (key: string) (level: FractalLevel) (baggage: Map<string, string>) : bool =
        depthEnabled key level || boostMatches key baggage

    // ============================================================
    // BOOST MANAGEMENT (SC-LOG-005: TTL Mandatory)
    // ============================================================

    /// Apply a new boost
    let applyBoost (boost: Boost) : Result<string, string> =
        let s = getState()

        // Validate TTL (SC-LOG-005)
        let validation = SafetyConstraints.validateBoostTtl boost
        if not validation.Passed then
            Error validation.Details
        else
            s.Boosts.[boost.Id] <- boost
            Ok boost.Id

    /// Create and apply a boost for a key expression
    let focus (keyExpr: string) (depth: FractalLevel) (ttlMs: int64) (createdBy: string) : Result<string, string> =
        let boost = Boost.createWithTtl keyExpr depth (int ttlMs) createdBy
        applyBoost boost

    /// Remove a boost by ID
    let removeBoost (boostId: string) : bool =
        let s = getState()
        let mutable removed = Unchecked.defaultof<Boost>
        s.Boosts.TryRemove(boostId, &removed)

    /// Expire all stale boosts
    let expireBoosts () : int =
        let s = getState()
        let now = DateTimeOffset.UtcNow

        let expired =
            s.Boosts.Values
            |> Seq.filter (fun b -> b.ExpiresAt < now)
            |> Seq.map (fun b -> b.Id)
            |> Seq.toList

        expired |> List.iter (fun id -> removeBoost id |> ignore)
        expired.Length

    /// Get all active boosts
    let getActiveBoosts () : Boost list =
        let s = getState()
        let now = DateTimeOffset.UtcNow

        s.Boosts.Values
        |> Seq.filter (fun b -> b.ExpiresAt > now)
        |> Seq.toList

    // ============================================================
    // KEY ALIAS REGISTRY (SC-LOG-009)
    // ============================================================

    /// Register a key and get its alias
    let registerKey (key: string) : uint16 =
        let s = getState()

        match s.KeyAliases.TryGetValue(key) with
        | true, alias -> alias
        | false, _ ->
            lock s.Lock (fun () ->
                // Double-check after lock
                match s.KeyAliases.TryGetValue(key) with
                | true, alias -> alias
                | false, _ ->
                    let alias = s.NextAlias
                    s.NextAlias <- s.NextAlias + 1us
                    s.KeyAliases.[key] <- alias
                    s.AliasLookup.[alias] <- key
                    alias
            )

    /// Lookup key from alias
    let lookupAlias (alias: uint16) : string option =
        let s = getState()
        match s.AliasLookup.TryGetValue(alias) with
        | true, key -> Some key
        | false, _ -> None

    /// Lookup alias from key
    let getAlias (key: string) : uint16 option =
        let s = getState()
        match s.KeyAliases.TryGetValue(key) with
        | true, alias -> Some alias
        | false, _ -> None

    // ============================================================
    // SUBSCRIPTION MANAGEMENT (Zenoh-style)
    // ============================================================

    /// Subscribe to log events matching a key expression
    let subscribe (keyExpr: string) (level: FractalLevel) (callback: FractalLogEntry -> unit) : string =
        let s = getState()
        let id = Guid.NewGuid().ToString("N").[..7]

        let compiled =
            try
                let pattern =
                    keyExpr
                        .Replace(".", "/")
                        .Replace("$*", "([^/]*)")
                        .Replace("**", "(.*)")
                        .Replace("*", "([^/]+)")
                Some(System.Text.RegularExpressions.Regex($"^{pattern}$"))
            with _ -> None

        let sub = {
            Id = id
            KeyExpr = keyExpr
            CompiledExpr = compiled
            Level = level
            Callback = callback
            CreatedAt = DateTimeOffset.UtcNow
        }

        s.Subscribers.[id] <- sub
        id

    /// Unsubscribe by ID
    let unsubscribe (subscriptionId: string) : bool =
        let s = getState()
        let mutable removed = Unchecked.defaultof<SubscriberInfo>
        s.Subscribers.TryRemove(subscriptionId, &removed)

    /// Register as a publisher
    let declarePublisher (keyExpr: string) (level: FractalLevel) : string =
        let s = getState()
        let id = Guid.NewGuid().ToString("N").[..7]

        let pub = {
            Id = id
            KeyExpr = keyExpr
            Level = level
            RegisteredAt = DateTimeOffset.UtcNow
        }

        s.Publishers.[id] <- pub
        id

    // ============================================================
    // LOAD SHEDDING (SC-LOG-002)
    // ============================================================

    /// Activate load shedding
    let activateShedding (reason: string) =
        let s = getState()
        s.Shedding <- {
            s.Shedding with
                Active = true
                Reason = Some reason
                ActivatedAt = Some DateTimeOffset.UtcNow
        }

    /// Deactivate load shedding
    let deactivateShedding () =
        let s = getState()
        s.Shedding <- {
            s.Shedding with
                Active = false
                Reason = None
                ActivatedAt = None
        }

    /// Check if shedding is active
    let isShedding () : bool =
        let s = getState()
        s.Shedding.Active

    /// Update resource metrics and auto-shed if needed
    let updateResourceMetrics (cpuPercent: float) (memoryPercent: float) =
        let s = getState()

        if cpuPercent > s.Shedding.CpuThreshold then
            if not s.Shedding.Active then
                activateShedding (sprintf "CPU > %.0f%%" s.Shedding.CpuThreshold)

        elif memoryPercent > s.Shedding.MemoryThreshold then
            if not s.Shedding.Active then
                activateShedding (sprintf "Memory > %.0f%%" s.Shedding.MemoryThreshold)

        elif s.Shedding.Active && cpuPercent < (s.Shedding.CpuThreshold - 10.0) &&
             memoryPercent < (s.Shedding.MemoryThreshold - 10.0) then
            deactivateShedding()

    // ============================================================
    // HLC TIMESTAMPS (SC-LOG-006)
    // ============================================================

    /// Get current HLC timestamp
    let hlcNow () : HLCTimestamp =
        let s = getState()
        let physical = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() * 1000L

        lock s.Lock (fun () ->
            if physical > s.HLCPhysical then
                s.HLCPhysical <- physical
                s.HLCCounter <- 0
            else
                s.HLCCounter <- s.HLCCounter + 1

            { Physical = s.HLCPhysical; Counter = s.HLCCounter; NodeId = s.NodeId }
        )

    /// Update HLC from received timestamp
    let hlcUpdate (received: HLCTimestamp) =
        let s = getState()
        let physical = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() * 1000L

        lock s.Lock (fun () ->
            if physical > s.HLCPhysical && physical > received.Physical then
                s.HLCPhysical <- physical
                s.HLCCounter <- 0
            elif received.Physical > s.HLCPhysical then
                s.HLCPhysical <- received.Physical
                s.HLCCounter <- received.Counter + 1
            else
                s.HLCCounter <- max s.HLCCounter received.Counter + 1
        )

    // ============================================================
    // EMISSION & NOTIFICATION
    // ============================================================

    /// Notify all matching subscribers of a log entry
    let notify (entry: FractalLogEntry) =
        let s = getState()

        // Increment emit count
        Interlocked.Increment(&s.Metrics.EmitCount) |> ignore

        // Find matching subscribers
        s.Subscribers.Values
        |> Seq.filter (fun sub ->
            // Level check
            FractalLevel.toInt entry.FractalLevel >= FractalLevel.toInt sub.Level &&
            // Key expression check
            (match sub.CompiledExpr with
             | Some regex -> regex.IsMatch(entry.Key)
             | None -> entry.Key.StartsWith(sub.KeyExpr) || sub.KeyExpr = "**")
        )
        |> Seq.iter (fun sub ->
            // SC-LOG-001: Async dispatch
            ThreadPool.QueueUserWorkItem(fun _ ->
                try sub.Callback entry
                with _ -> ()  // Graceful degradation
            ) |> ignore
        )

    /// Record a dropped log
    let recordDrop (level: FractalLevel) =
        let s = getState()
        s.Metrics.DropCount.AddOrUpdate(level, 1L, fun _ c -> c + 1L) |> ignore

    // ============================================================
    // STATUS & DIAGNOSTICS
    // ============================================================

    /// Get current FractalControl status
    let getStatus () =
        let s = getState()
        {|
            DefaultPolicy = s.DefaultPolicy
            PolicyCount = s.Policies.Count
            ActiveBoosts = s.Boosts.Count
            Subscribers = s.Subscribers.Count
            Publishers = s.Publishers.Count
            KeyAliases = s.KeyAliases.Count
            Shedding = s.Shedding.Active
            SheddingReason = s.Shedding.Reason
            EmitCount = s.Metrics.EmitCount
            DropCount = s.Metrics.DropCount |> Seq.map (fun kvp -> kvp.Key, kvp.Value) |> Map.ofSeq
            HLC = hlcNow()
        |}

    /// Reset state (for testing)
    let reset () =
        lock initLock (fun () ->
            state <- None
        )

    // ============================================================
    // FRACTAL HANDLERS (Integration with Elixir FractalControl)
    // ============================================================

    /// Fractal_SetLevel: Set the logging level for a key expression
    /// Maps to FractalControl.set_policy/2 in Elixir
    let setLevel (keyExpr: string) (level: FractalLevel) : Result<unit, string> =
        if String.IsNullOrWhiteSpace(keyExpr) then
            Error "Key expression cannot be empty"
        else
            setPolicy keyExpr level
            Ok ()

    /// Fractal_SetDefaultLevel: Set the default logging level
    /// Maps to FractalControl.set_default_policy/1 in Elixir
    let setDefaultLevel (level: FractalLevel) : Result<unit, string> =
        let s = getState()
        lock s.Lock (fun () ->
            { s with DefaultPolicy = level } |> ignore
        )
        Ok ()

    /// Fractal_GetLevel: Get the effective logging level for a key
    let getLevel (key: string) : FractalLevel =
        getPolicy key

    /// Fractal_Focus: Apply a focus boost to enable verbose logging
    /// Maps to FractalControl.focus/4 in Elixir
    /// SC-LOG-005: Boosts require TTL (default 5min, max 1hr)
    let applyFocus (keyExpr: string) (depth: FractalLevel) (ttlMs: int64) (createdBy: string)
                   : Result<string, string> =
        // Validate TTL (max 1 hour)
        let maxTtlMs = 3_600_000L
        if ttlMs > maxTtlMs then
            Error (sprintf "TTL exceeds maximum of %d ms" maxTtlMs)
        elif ttlMs <= 0L then
            Error "TTL must be positive"
        else
            focus keyExpr depth ttlMs createdBy

    /// Fractal_ClearBoosts: Clear all active boosts
    let clearBoosts () : int =
        let s = getState()
        let count = s.Boosts.Count
        s.Boosts.Clear()
        count

    /// Fractal_GetStats: Get comprehensive fractal logging statistics
    /// Maps to FractalControl.get_status/0 and get_metrics/0 in Elixir
    let getStats () =
        let s = getState()
        let status = getStatus()

        {|
            // Core status
            Healthy = not s.Shedding.Active
            DefaultPolicy = FractalLevel.toString s.DefaultPolicy
            PolicyCount = s.Policies.Count

            // Boost information
            ActiveBoosts = s.Boosts.Count
            BoostList =
                s.Boosts.Values
                |> Seq.filter (fun b -> b.ExpiresAt > DateTimeOffset.UtcNow)
                |> Seq.map (fun b -> {|
                    Id = b.Id
                    KeyExpr = b.KeyExpr
                    Depth = FractalLevel.toString b.Depth
                    ExpiresAt = b.ExpiresAt
                    CreatedBy = b.CreatedBy
                    RemainingMs = int64 (b.ExpiresAt - DateTimeOffset.UtcNow).TotalMilliseconds
                |})
                |> Seq.toList

            // Subscription information
            Subscribers = s.Subscribers.Count
            Publishers = s.Publishers.Count

            // Key alias information (SC-LOG-009)
            KeyAliases = s.KeyAliases.Count

            // Load shedding status (SC-LOG-002)
            Shedding = s.Shedding.Active
            SheddingReason = s.Shedding.Reason |> Option.defaultValue ""
            SheddingActivatedAt = s.Shedding.ActivatedAt

            // Metrics
            EmitCount = s.Metrics.EmitCount
            DropCount =
                s.Metrics.DropCount
                |> Seq.map (fun kvp -> FractalLevel.toString kvp.Key, kvp.Value)
                |> Map.ofSeq

            // Throughput calculation (messages per second)
            Throughput =
                let emitCount = s.Metrics.EmitCount
                // Simple throughput estimate based on 60 second window
                float emitCount / 60.0

            // Error rate calculation
            ErrorRate =
                let totalDrops = s.Metrics.DropCount |> Seq.sumBy (fun kvp -> kvp.Value)
                let total = s.Metrics.EmitCount + totalDrops
                if total > 0L then float totalDrops / float total else 0.0

            // HLC timestamp
            HLC = {|
                Physical = (hlcNow()).Physical
                Counter = (hlcNow()).Counter
                NodeId = s.NodeId
            |}

            // Node information
            NodeId = s.NodeId
        |}

    /// Fractal_GetMetrics: Get just the metrics portion
    /// Maps to FractalControl.get_metrics/0 in Elixir
    let getMetrics () =
        let s = getState()
        let totalDrops = s.Metrics.DropCount |> Seq.sumBy (fun kvp -> kvp.Value)
        let total = s.Metrics.EmitCount + totalDrops

        {|
            Throughput = float s.Metrics.EmitCount / 60.0
            ErrorRate = if total > 0L then float totalDrops / float total else 0.0
            EmitCount = s.Metrics.EmitCount
            DropCount =
                s.Metrics.DropCount
                |> Seq.map (fun kvp -> FractalLevel.toString kvp.Key, kvp.Value)
                |> Map.ofSeq
            BoostCount = s.Boosts.Count
            SubscriberCount = s.Subscribers.Count
        |}

    /// Fractal_ActivateShedding: Activate load shedding mode
    /// SC-LOG-002: Auto-throttle at CPU > 90%
    let activateSheddingWithReason (reason: string) : Result<unit, string> =
        if String.IsNullOrWhiteSpace(reason) then
            Error "Reason cannot be empty"
        else
            activateShedding reason
            Ok ()

    /// Fractal_DeactivateShedding: Deactivate load shedding mode
    let deactivateSheddingMode () : Result<unit, string> =
        deactivateShedding ()
        Ok ()

    /// Fractal_CheckShouldLog: Check if a log entry should be emitted
    /// This is the main entry point for log emission decisions
    let checkShouldLog (key: string) (level: FractalLevel) (baggage: Map<string, string>)
                       : bool =
        shouldLog key level baggage

    /// Fractal_WarmupETS: Warmup ETS tables (no-op in F# but included for API parity)
    let warmupETS () : Result<unit, string> =
        // In F# we use ConcurrentDictionary which doesn't need warmup
        // This is included for API parity with Elixir
        let _ = getState()
        Ok ()
