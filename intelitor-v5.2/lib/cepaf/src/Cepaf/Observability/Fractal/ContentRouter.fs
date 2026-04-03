namespace Cepaf.Observability.Fractal

open System
open System.Collections.Concurrent

/// Content Router for intelligent log backend selection.
/// Routes logs to appropriate storage based on fractal level, content type, and retention.
/// STAMP Compliance: SC-LOG-010 (L1/L2 ephemeral, L4/L5 persistent)
module ContentRouter =

    // ============================================================
    // TYPES
    // ============================================================

    /// Backend storage types
    [<RequireQualifiedAccess>]
    type Backend =
        /// In-memory ring buffer (L1 ephemeral)
        | Memory

        /// Local WAL for durability (L2-L3)
        | WAL

        /// TimescaleDB for time-series (L3-L4)
        | TimescaleDB

        /// PostgreSQL for structured data (L4)
        | PostgreSQL

        /// S3-compatible object storage (L5 archival)
        | ObjectStore

        /// OpenTelemetry Collector (all levels)
        | OTLP

        /// Console output (debug)
        | Console

        /// Custom backend handler
        | Custom of string

    /// Retention policy
    type RetentionPolicy = {
        /// Minimum retention duration
        MinRetention: TimeSpan

        /// Maximum retention duration
        MaxRetention: TimeSpan

        /// Whether to archive before deletion
        ArchiveOnExpiry: bool

        /// Compression level for storage
        CompressionLevel: int
    }

    /// Routing rule
    type RoutingRule = {
        /// Rule identifier
        Id: string

        /// Key expression pattern to match
        KeyExpr: string

        /// Compiled pattern
        CompiledExpr: KeyExpression.CompiledExpr option

        /// Minimum fractal level
        MinLevel: FractalLevel

        /// Maximum fractal level
        MaxLevel: FractalLevel

        /// Target backends
        Backends: Backend list

        /// Retention policy
        Retention: RetentionPolicy

        /// Priority (higher = evaluated first)
        Priority: int

        /// Whether rule is enabled
        Enabled: bool
    }

    /// Routing decision
    type RoutingDecision = {
        /// Selected backends
        Backends: Backend list

        /// Applicable retention policy
        Retention: RetentionPolicy

        /// Rule that matched
        MatchedRule: string option

        /// Whether to emit (based on filtering)
        ShouldEmit: bool
    }

    /// Router state
    type RouterState = {
        /// Routing rules
        Rules: ConcurrentDictionary<string, RoutingRule>

        /// Default backends by level
        DefaultBackends: ConcurrentDictionary<FractalLevel, Backend list>

        /// Default retention by level
        DefaultRetention: ConcurrentDictionary<FractalLevel, RetentionPolicy>

        /// Backend availability
        BackendHealth: ConcurrentDictionary<Backend, bool>

        /// Statistics
        mutable RouteCount: int64
        mutable FallbackCount: int64
    }

    // ============================================================
    // DEFAULT CONFIGURATIONS
    // ============================================================

    /// Default retention policies by level
    let private defaultRetentionByLevel =
        [
            (FractalLevel.L1, { MinRetention = TimeSpan.FromMinutes(5.0); MaxRetention = TimeSpan.FromHours(1.0); ArchiveOnExpiry = false; CompressionLevel = 0 })
            (FractalLevel.L2, { MinRetention = TimeSpan.FromHours(1.0); MaxRetention = TimeSpan.FromDays(1.0); ArchiveOnExpiry = false; CompressionLevel = 1 })
            (FractalLevel.L3, { MinRetention = TimeSpan.FromDays(7.0); MaxRetention = TimeSpan.FromDays(30.0); ArchiveOnExpiry = true; CompressionLevel = 6 })
            (FractalLevel.L4, { MinRetention = TimeSpan.FromDays(30.0); MaxRetention = TimeSpan.FromDays(365.0); ArchiveOnExpiry = true; CompressionLevel = 9 })
            (FractalLevel.L5, { MinRetention = TimeSpan.FromDays(365.0); MaxRetention = TimeSpan.FromDays(3650.0); ArchiveOnExpiry = true; CompressionLevel = 9 })
        ]
        |> Map.ofList

    /// Default backends by level
    let private defaultBackendsByLevel =
        [
            (FractalLevel.L1, [Backend.Memory; Backend.OTLP])
            (FractalLevel.L2, [Backend.WAL; Backend.OTLP])
            (FractalLevel.L3, [Backend.TimescaleDB; Backend.OTLP])
            (FractalLevel.L4, [Backend.PostgreSQL; Backend.TimescaleDB; Backend.OTLP])
            (FractalLevel.L5, [Backend.PostgreSQL; Backend.ObjectStore; Backend.OTLP])
        ]
        |> Map.ofList

    // ============================================================
    // STATE MANAGEMENT
    // ============================================================

    let mutable private state: RouterState option = None
    let private initLock = obj()

    /// Initialize the router
    let initialize () =
        lock initLock (fun () ->
            let defaultBackends = ConcurrentDictionary<FractalLevel, Backend list>()
            let defaultRetention = ConcurrentDictionary<FractalLevel, RetentionPolicy>()
            let backendHealth = ConcurrentDictionary<Backend, bool>()

            // Set defaults
            for (level, backends) in defaultBackendsByLevel |> Map.toSeq do
                defaultBackends.[level] <- backends

            for (level, retention) in defaultRetentionByLevel |> Map.toSeq do
                defaultRetention.[level] <- retention

            // All backends healthy by default
            [Backend.Memory; Backend.WAL; Backend.TimescaleDB; Backend.PostgreSQL; Backend.ObjectStore; Backend.OTLP; Backend.Console]
            |> List.iter (fun b -> backendHealth.[b] <- true)

            state <- Some {
                Rules = ConcurrentDictionary<string, RoutingRule>()
                DefaultBackends = defaultBackends
                DefaultRetention = defaultRetention
                BackendHealth = backendHealth
                RouteCount = 0L
                FallbackCount = 0L
            }
        )

    /// Get or initialize state
    let private getState () =
        match state with
        | Some s -> s
        | None ->
            initialize()
            state.Value

    // ============================================================
    // RULE MANAGEMENT
    // ============================================================

    /// Add a routing rule
    let addRule (rule: RoutingRule) : Result<unit, string> =
        let s = getState()

        // Compile key expression
        let compiled =
            match KeyExpression.compile rule.KeyExpr with
            | Ok c -> Some c
            | Error _ -> None

        let ruleWithCompiled = { rule with CompiledExpr = compiled }
        s.Rules.[rule.Id] <- ruleWithCompiled
        Ok ()

    /// Remove a routing rule
    let removeRule (ruleId: string) : bool =
        let s = getState()
        let mutable removed = Unchecked.defaultof<RoutingRule>
        s.Rules.TryRemove(ruleId, &removed)

    /// Enable/disable a rule
    let setRuleEnabled (ruleId: string) (enabled: bool) : bool =
        let s = getState()
        match s.Rules.TryGetValue(ruleId) with
        | true, rule ->
            s.Rules.[ruleId] <- { rule with Enabled = enabled }
            true
        | false, _ -> false

    /// Get all rules
    let getRules () : RoutingRule list =
        let s = getState()
        s.Rules.Values |> Seq.toList

    // ============================================================
    // BACKEND HEALTH
    // ============================================================

    /// Set backend health status
    let setBackendHealth (backend: Backend) (healthy: bool) =
        let s = getState()
        s.BackendHealth.[backend] <- healthy

    /// Check if backend is healthy
    let isBackendHealthy (backend: Backend) : bool =
        let s = getState()
        match s.BackendHealth.TryGetValue(backend) with
        | true, health -> health
        | false, _ -> false

    /// Get all healthy backends
    let getHealthyBackends () : Backend list =
        let s = getState()
        s.BackendHealth
        |> Seq.filter (fun kvp -> kvp.Value)
        |> Seq.map (fun kvp -> kvp.Key)
        |> Seq.toList

    // ============================================================
    // ROUTING LOGIC
    // ============================================================

    /// Find matching rule for an entry
    let private findMatchingRule (s: RouterState) (entry: FractalLogEntry) : RoutingRule option =
        s.Rules.Values
        |> Seq.filter (fun r -> r.Enabled)
        |> Seq.filter (fun r ->
            // Level check
            FractalLevel.toInt entry.FractalLevel >= FractalLevel.toInt r.MinLevel &&
            FractalLevel.toInt entry.FractalLevel <= FractalLevel.toInt r.MaxLevel
        )
        |> Seq.filter (fun r ->
            // Key expression check
            match r.CompiledExpr with
            | Some compiled -> KeyExpression.matches compiled entry.Key
            | None -> entry.Key.StartsWith(r.KeyExpr) || r.KeyExpr = "**"
        )
        |> Seq.sortByDescending (fun r -> r.Priority)
        |> Seq.tryHead

    /// Filter backends by health
    let private filterHealthyBackends (s: RouterState) (backends: Backend list) : Backend list =
        backends
        |> List.filter (fun b ->
            match s.BackendHealth.TryGetValue(b) with
            | true, health -> health
            | false, _ -> true  // Assume healthy if unknown
        )

    /// Route a log entry to appropriate backends
    let route (entry: FractalLogEntry) : RoutingDecision =
        let s = getState()
        System.Threading.Interlocked.Increment(&s.RouteCount) |> ignore

        // Find matching rule
        match findMatchingRule s entry with
        | Some rule ->
            let healthyBackends = filterHealthyBackends s rule.Backends

            // Fallback if no healthy backends
            let finalBackends =
                if healthyBackends.IsEmpty then
                    System.Threading.Interlocked.Increment(&s.FallbackCount) |> ignore
                    [Backend.Console]  // Always available
                else
                    healthyBackends

            {
                Backends = finalBackends
                Retention = rule.Retention
                MatchedRule = Some rule.Id
                ShouldEmit = true
            }

        | None ->
            // Use defaults based on level
            let defaultBackends =
                match s.DefaultBackends.TryGetValue(entry.FractalLevel) with
                | true, backends -> backends
                | false, _ -> [Backend.OTLP]

            let healthyBackends = filterHealthyBackends s defaultBackends

            let retention =
                match s.DefaultRetention.TryGetValue(entry.FractalLevel) with
                | true, ret -> ret
                | false, _ -> defaultRetentionByLevel.[FractalLevel.L3]

            {
                Backends = if healthyBackends.IsEmpty then [Backend.Console] else healthyBackends
                Retention = retention
                MatchedRule = None
                ShouldEmit = true
            }

    /// Batch route multiple entries
    let routeBatch (entries: FractalLogEntry list) : (FractalLogEntry * RoutingDecision) list =
        entries |> List.map (fun e -> (e, route e))

    // ============================================================
    // BACKEND ADAPTERS
    // ============================================================

    /// Backend adapter interface
    type IBackendAdapter =
        abstract member Write: FractalLogEntry -> Async<Result<unit, string>>
        abstract member WriteBatch: FractalLogEntry list -> Async<Result<int, string>>
        abstract member IsHealthy: unit -> bool
        abstract member Name: string

    /// Registry for backend adapters
    let private adapters = ConcurrentDictionary<Backend, IBackendAdapter>()

    /// Register a backend adapter
    let registerAdapter (backend: Backend) (adapter: IBackendAdapter) =
        adapters.[backend] <- adapter

    /// Get adapter for backend
    let getAdapter (backend: Backend) : IBackendAdapter option =
        match adapters.TryGetValue(backend) with
        | true, adapter -> Some adapter
        | false, _ -> None

    /// Write entry to all routed backends
    let writeToBackends (entry: FractalLogEntry) : Async<Result<unit, string>> =
        async {
            let decision = route entry

            if not decision.ShouldEmit then
                return Ok ()
            else

            let! results =
                decision.Backends
                |> List.choose (fun b -> getAdapter b |> Option.map (fun a -> (b, a)))
                |> List.map (fun (_, adapter) ->
                    async {
                        try
                            return! adapter.Write entry
                        with ex ->
                            return Error ex.Message
                    }
                )
                |> Async.Parallel

            let errors = results |> Array.choose (function Error e -> Some e | Ok _ -> None)

            if errors.Length = 0 then
                return Ok ()
            elif errors.Length < results.Length then
                // Partial success
                return Ok ()
            else
                return Error (String.Join("; ", errors))
        }

    // ============================================================
    // PREDEFINED RULES
    // ============================================================

    /// Create rule for security audit logs
    let securityAuditRule () : RoutingRule =
        {
            Id = "security-audit"
            KeyExpr = "Indrajaal/Security/**"
            CompiledExpr = None
            MinLevel = FractalLevel.L3
            MaxLevel = FractalLevel.L5
            Backends = [Backend.PostgreSQL; Backend.ObjectStore; Backend.OTLP]
            Retention = {
                MinRetention = TimeSpan.FromDays(365.0)
                MaxRetention = TimeSpan.FromDays(3650.0)  // 10 years
                ArchiveOnExpiry = true
                CompressionLevel = 9
            }
            Priority = 100
            Enabled = true
        }

    /// Create rule for cognitive/AI logs
    let cognitiveRule () : RoutingRule =
        {
            Id = "cognitive"
            KeyExpr = "Indrajaal/Cortex/**"
            CompiledExpr = None
            MinLevel = FractalLevel.L4
            MaxLevel = FractalLevel.L5
            Backends = [Backend.PostgreSQL; Backend.TimescaleDB; Backend.ObjectStore]
            Retention = {
                MinRetention = TimeSpan.FromDays(90.0)
                MaxRetention = TimeSpan.FromDays(730.0)  // 2 years
                ArchiveOnExpiry = true
                CompressionLevel = 9
            }
            Priority = 90
            Enabled = true
        }

    /// Create rule for alarm processing
    let alarmRule () : RoutingRule =
        {
            Id = "alarms"
            KeyExpr = "Indrajaal/Alarms/**"
            CompiledExpr = None
            MinLevel = FractalLevel.L3
            MaxLevel = FractalLevel.L5
            Backends = [Backend.TimescaleDB; Backend.PostgreSQL; Backend.OTLP]
            Retention = {
                MinRetention = TimeSpan.FromDays(30.0)
                MaxRetention = TimeSpan.FromDays(365.0)
                ArchiveOnExpiry = true
                CompressionLevel = 6
            }
            Priority = 80
            Enabled = true
        }

    /// Create rule for debug/ephemeral logs
    let debugRule () : RoutingRule =
        {
            Id = "debug"
            KeyExpr = "**"
            CompiledExpr = None
            MinLevel = FractalLevel.L1
            MaxLevel = FractalLevel.L2
            Backends = [Backend.Memory; Backend.Console]
            Retention = {
                MinRetention = TimeSpan.FromMinutes(5.0)
                MaxRetention = TimeSpan.FromHours(1.0)
                ArchiveOnExpiry = false
                CompressionLevel = 0
            }
            Priority = 1  // Lowest priority, catch-all
            Enabled = true
        }

    /// Initialize with default rules
    let initializeWithDefaults () =
        initialize()
        addRule (securityAuditRule()) |> ignore
        addRule (cognitiveRule()) |> ignore
        addRule (alarmRule()) |> ignore
        addRule (debugRule()) |> ignore

    // ============================================================
    // STATISTICS & DIAGNOSTICS
    // ============================================================

    /// Get router statistics
    let getStats () =
        let s = getState()
        {|
            RouteCount = s.RouteCount
            FallbackCount = s.FallbackCount
            RuleCount = s.Rules.Count
            EnabledRules = s.Rules.Values |> Seq.filter (fun r -> r.Enabled) |> Seq.length
            HealthyBackends = getHealthyBackends() |> List.length
            TotalBackends = s.BackendHealth.Count
        |}

    /// Reset statistics
    let resetStats () =
        let s = getState()
        s.RouteCount <- 0L
        s.FallbackCount <- 0L

    /// Reset to uninitialized state
    let reset () =
        lock initLock (fun () ->
            state <- None
        )

