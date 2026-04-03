// ZenohFractalPublisher.fs
// WHAT: Zenoh-based Fractal Log Publisher for F# CEPAF
// WHY: Routes fractal log entries to Zenoh for real-time streaming to dashboards
// CONSTRAINTS: Aligned with Indrajaal.Observability.ZenohFractalPublisher
// SOPv5.11 Compliance: SC-ZENOH-PUB-001, SC-ZENOH-PUB-002, SC-ZENOH-PUB-003, SC-LOG-001

namespace Cepaf.Observability.Fractal

open System
open System.Collections.Concurrent
open System.Threading
open System.Text.Json
open Cepaf.Zenoh

/// Configuration for ZenohFractalPublisher (SC-ZENOH-PUB-001)
type ZenohFractalPublisherConfig = {
    Enabled: bool
    BatchSize: int
    FlushIntervalMs: int
    KeyPrefix: string
    Levels: FractalLevel list
}

/// Statistics for publisher monitoring
type ZenohFractalPublisherStats = {
    EntriesPublished: int64
    Flushes: int64
    Errors: int64
    TotalLatencyUs: int64
    StartedAt: DateTimeOffset
    LastFlushAt: DateTimeOffset option
    BufferSize: int
}

/// Zenoh Fractal Publisher - Routes fractal logs to Zenoh
/// Aligned with Indrajaal.Observability.ZenohFractalPublisher
module ZenohFractalPublisher =

    // ========================================================================
    // CONFIGURATION
    // ========================================================================

    let private defaultBatchSize = 100
    let private defaultFlushIntervalMs = 100
    let private keyPrefix = "indrajaal/fractal"

    let defaultConfig = {
        Enabled = true
        BatchSize = defaultBatchSize
        FlushIntervalMs = defaultFlushIntervalMs
        KeyPrefix = keyPrefix
        Levels = [FractalLevel.L1; FractalLevel.L2; FractalLevel.L3; FractalLevel.L4; FractalLevel.L5]
    }

    // ========================================================================
    // STATE
    // ========================================================================

    let mutable private config = defaultConfig
    let private buffer = ConcurrentQueue<FractalLogEntry>()
    let mutable private stats = {
        EntriesPublished = 0L
        Flushes = 0L
        Errors = 0L
        TotalLatencyUs = 0L
        StartedAt = DateTimeOffset.UtcNow
        LastFlushAt = None
        BufferSize = 0
    }
    let private statsLock = obj()
    let mutable private flushTimer: Timer option = None
    let private cancellation = new CancellationTokenSource()

    // ========================================================================
    // KEY EXPRESSION BUILDING
    // ========================================================================

    /// Build Zenoh key from fractal log entry
    /// Schema: indrajaal/fractal/{level}/{domain}/{event_type}
    /// Aligned with ZenohFractalPublisher.build_key/2 in Elixir
    let private buildKey (entry: FractalLogEntry) : string =
        let levelStr = FractalLevel.toString entry.FractalLevel |> fun s -> s.ToLowerInvariant()
        let domainStr =
            entry.Module
            |> fun s -> s.ToLowerInvariant().Replace(".", "_").Replace(" ", "_")
        let eventType =
            entry.Function
            |> fun s -> s.ToLowerInvariant().Replace(" ", "_")

        sprintf "%s/%s/%s/%s" config.KeyPrefix levelStr domainStr eventType

    // ========================================================================
    // ENCODING
    // ========================================================================

    /// Extract message from payload
    let private payloadToMessage (payload: FractalPayload) : string =
        match payload with
        | FractalPayload.Empty -> ""
        | FractalPayload.Text s -> s
        | FractalPayload.Json s -> s
        | FractalPayload.Binary b -> Convert.ToBase64String(b)
        | FractalPayload.Structured pairs ->
            pairs
            |> List.map (fun (k, v) -> sprintf "%s=%O" k v)
            |> String.concat "; "

    /// Encode fractal log entry to JSON bytes
    let private encodeEntry (entry: FractalLogEntry) : byte[] =
        let hlcStr =
            sprintf "%d.%d@%s" entry.HLC.Physical entry.HLC.Counter entry.HLC.NodeId

        let payload = {|
            timestamp = entry.Timestamp.ToString("o")
            level = FractalLevel.toString entry.FractalLevel
            module_name = entry.Module
            function_name = entry.Function
            message = payloadToMessage entry.Payload
            hlc = hlcStr
            trace_id = entry.TraceId
            baggage = entry.Baggage
            event_type = EventType.toInt entry.EventType
            priority = Priority.toInt entry.Priority
            source = "cepaf-fsharp"
        |}
        JsonSerializer.SerializeToUtf8Bytes(payload)

    // ========================================================================
    // LEVEL FILTERING
    // ========================================================================

    /// Check if level is enabled
    let private levelEnabled (level: FractalLevel) : bool =
        config.Levels |> List.contains level

    // ========================================================================
    // FLUSHING
    // ========================================================================

    /// Flush buffered entries to Zenoh
    let private doFlush (entries: FractalLogEntry list) =
        if entries.IsEmpty then ()
        else
            let startTime = DateTimeOffset.UtcNow

            // Build messages for batch publish
            let messages =
                entries
                |> List.map (fun entry ->
                    let key = buildKey entry
                    let payload = encodeEntry entry
                    (key, payload)
                )

            // Publish each message
            let mutable errorCount = 0
            for (key, payload) in messages do
                match ZenohSession.publish key payload with
                | Ok () -> ()
                | Error _ -> errorCount <- errorCount + 1

            let elapsedUs =
                int64 ((DateTimeOffset.UtcNow - startTime).TotalMilliseconds * 1000.0)

            // Update stats
            let count = int64 entries.Length
            lock statsLock (fun () ->
                stats <- {
                    stats with
                        EntriesPublished = stats.EntriesPublished + count
                        Flushes = stats.Flushes + 1L
                        Errors = stats.Errors + int64 errorCount
                        TotalLatencyUs = stats.TotalLatencyUs + elapsedUs
                        LastFlushAt = Some DateTimeOffset.UtcNow
                }
            )

            // Log if latency exceeds target (SC-ZENOH-PUB-002: <1ms)
            if elapsedUs > 1000L then
                printfn "[ZenohFractalPublisher] WARNING: Flush latency %dus exceeds 1ms target" elapsedUs

    /// Flush buffer callback
    let private flushBuffer () =
        if buffer.IsEmpty then ()
        else
            let entries = ResizeArray<FractalLogEntry>()
            let mutable entry = Unchecked.defaultof<FractalLogEntry>

            while entries.Count < config.BatchSize && buffer.TryDequeue(&entry) do
                entries.Add(entry)

            if entries.Count > 0 then
                doFlush (entries |> Seq.toList)

    // ========================================================================
    // PUBLIC API
    // ========================================================================

    /// Initialize the publisher with configuration
    let initialize (cfg: ZenohFractalPublisherConfig) =
        config <- cfg

        if cfg.Enabled then
            // Initialize Zenoh session if not already connected
            if not (ZenohSession.isConnected()) then
                ZenohSession.initialize() |> ignore

            // Start flush timer
            let callback = TimerCallback(fun _ -> flushBuffer())
            flushTimer <- Some (new Timer(callback, null, cfg.FlushIntervalMs, cfg.FlushIntervalMs))

            printfn "[ZenohFractalPublisher] Initialized - SC-ZENOH-PUB-001"

    /// Initialize with default configuration
    let initializeDefault () =
        initialize defaultConfig

    /// Publish a single fractal log entry (SC-ZENOH-PUB-001: Non-blocking)
    let publishEntry (entry: FractalLogEntry) =
        if not config.Enabled then ()
        elif not (levelEnabled entry.FractalLevel) then ()
        else
            buffer.Enqueue(entry)

            // Auto-flush if buffer exceeds batch size
            if buffer.Count >= config.BatchSize then
                ThreadPool.QueueUserWorkItem(fun _ -> flushBuffer()) |> ignore

    /// Publish multiple entries at once (SC-ZENOH-PUB-003: Batch support)
    let publishEntries (entries: FractalLogEntry list) =
        if not config.Enabled then ()
        else
            let enabledEntries =
                entries |> List.filter (fun e -> levelEnabled e.FractalLevel)

            for entry in enabledEntries do
                buffer.Enqueue(entry)

            // Auto-flush if buffer exceeds batch size
            if buffer.Count >= config.BatchSize then
                ThreadPool.QueueUserWorkItem(fun _ -> flushBuffer()) |> ignore

    /// Force flush of buffered entries
    let flush () =
        flushBuffer()

    /// Get publisher statistics
    let getStats () : ZenohFractalPublisherStats =
        lock statsLock (fun () ->
            { stats with BufferSize = buffer.Count }
        )

    /// Check if publisher is enabled
    let isEnabled () = config.Enabled

    /// Enable or disable the publisher
    let setEnabled (enabled: bool) =
        if enabled && not config.Enabled then
            // Start flush timer
            let callback = TimerCallback(fun _ -> flushBuffer())
            flushTimer <- Some (new Timer(callback, null, config.FlushIntervalMs, config.FlushIntervalMs))
        elif not enabled && config.Enabled then
            // Stop flush timer
            match flushTimer with
            | Some timer ->
                timer.Change(Timeout.Infinite, Timeout.Infinite) |> ignore
            | None -> ()

        config <- { config with Enabled = enabled }

    /// Close the publisher
    let close () =
        flush()
        match flushTimer with
        | Some timer -> timer.Dispose()
        | None -> ()
        cancellation.Cancel()
        printfn "[ZenohFractalPublisher] Closed"

    // ========================================================================
    // INTEGRATION WITH FRACTAL LOGGING
    // ========================================================================

    /// Create a log handler for FractalControl integration
    /// This can be registered as a content router backend
    let createLogHandler () : FractalLogEntry -> unit =
        fun entry -> publishEntry entry

    /// Subscribe to fractal log level (receives logs from Elixir)
    let subscribeLevel (level: FractalLevel) (handler: FractalLogEntry -> unit) =
        let levelStr = FractalLevel.toString level |> fun s -> s.ToLowerInvariant()
        let keyExpr = sprintf "%s/%s/**" config.KeyPrefix levelStr

        ZenohSession.subscribe keyExpr (fun msg ->
            try
                let json = System.Text.Encoding.UTF8.GetString(msg.Payload)
                let doc = JsonDocument.Parse(json)
                let root = doc.RootElement

                // Parse back to FractalLogEntry
                let levelParsed =
                    root.GetProperty("level").GetString()
                    |> FractalLevel.parse
                    |> Option.defaultValue FractalLevel.L3

                // Try to get optional trace_id
                let mutable traceIdElem = Unchecked.defaultof<JsonElement>
                let traceId =
                    if root.TryGetProperty("trace_id", &traceIdElem) &&
                       traceIdElem.ValueKind <> JsonValueKind.Null then
                        Some (traceIdElem.GetString())
                    else None

                let entry : FractalLogEntry = {
                    Key = msg.Key
                    KeyAlias = None
                    HLC = FractalControl.hlcNow()  // Use current HLC for received msgs
                    FractalLevel = levelParsed
                    Priority = Priority.fromLevel levelParsed
                    EventType = Entry
                    TraceId = traceId
                    SpanId = None
                    ParentSpanId = None
                    Payload = FractalPayload.Text (root.GetProperty("message").GetString())
                    Baggage = Map.empty
                    Tags = []
                    Timestamp = root.GetProperty("timestamp").GetString() |> DateTimeOffset.Parse
                    Duration = None
                    Node = "zenoh"
                    Module = root.GetProperty("module_name").GetString()
                    Function = root.GetProperty("function_name").GetString()
                    Arity = 0
                }
                handler entry
            with ex ->
                printfn "[ZenohFractalPublisher] Parse error: %s" ex.Message
        )

    /// Subscribe to all fractal logs from Elixir
    let subscribeAllLevels (handler: FractalLogEntry -> unit) =
        ZenohSession.subscribeAllFractalLogs (fun msg ->
            try
                let json = System.Text.Encoding.UTF8.GetString(msg.Payload)
                let doc = JsonDocument.Parse(json)
                let root = doc.RootElement

                let levelParsed =
                    root.GetProperty("level").GetString()
                    |> FractalLevel.parse
                    |> Option.defaultValue FractalLevel.L3

                // Try to get optional trace_id
                let mutable traceIdElem = Unchecked.defaultof<JsonElement>
                let traceId =
                    if root.TryGetProperty("trace_id", &traceIdElem) &&
                       traceIdElem.ValueKind <> JsonValueKind.Null then
                        Some (traceIdElem.GetString())
                    else None

                let entry : FractalLogEntry = {
                    Key = msg.Key
                    KeyAlias = None
                    HLC = FractalControl.hlcNow()
                    FractalLevel = levelParsed
                    Priority = Priority.fromLevel levelParsed
                    EventType = Entry
                    TraceId = traceId
                    SpanId = None
                    ParentSpanId = None
                    Payload = FractalPayload.Text (root.GetProperty("message").GetString())
                    Baggage = Map.empty
                    Tags = []
                    Timestamp = root.GetProperty("timestamp").GetString() |> DateTimeOffset.Parse
                    Duration = None
                    Node = "zenoh"
                    Module = root.GetProperty("module_name").GetString()
                    Function = root.GetProperty("function_name").GetString()
                    Arity = 0
                }
                handler entry
            with ex ->
                printfn "[ZenohFractalPublisher] Parse error: %s" ex.Message
        )

/// Zenoh Key Expression utilities for Fractal logging
/// Aligned with Indrajaal.Observability.Fractal.KeyExpression
module ZenohKeyExpressions =

    /// All key expression planes used by Indrajaal/CEPAF
    /// Aligned with ZenohCoordinator.list_key_expressions/0
    let planes = {|
        /// Fractal logging plane (SC-ZENOH-INT-001)
        FractalPlane = [
            "indrajaal/fractal/l1/**"
            "indrajaal/fractal/l2/**"
            "indrajaal/fractal/l3/**"
            "indrajaal/fractal/l4/**"
            "indrajaal/fractal/l5/**"
        ]
        /// Telemetry plane
        TelemetryPlane = [
            "indrajaal/telemetry/elixir/**"
            "indrajaal/telemetry/fsharp/**"
        ]
        /// Data plane (KPIs)
        DataPlane = [
            "indrajaal/kpi/compilation"
            "indrajaal/kpi/tests"
            "indrajaal/kpi/containers"
            "indrajaal/kpi/performance"
            "indrajaal/kpi/progress"
            "indrajaal/kpi/stamp"
            "indrajaal/kpi/todos"
            "indrajaal/kpi/agents"
        ]
        /// Control plane
        ControlPlane = [
            "indrajaal/control/refresh"
            "indrajaal/control/mode"
            "indrajaal/control/agent/**"
            "indrajaal/control/fractal/boost"
            "indrajaal/control/fractal/suppress"
            "indrajaal/control/compile"
            "indrajaal/control/test"
            "indrajaal/control/emergency"
        ]
        /// Coordination plane
        CoordinationPlane = [
            "indrajaal/coord/heartbeat"
            "indrajaal/coord/sync"
            "indrajaal/coord/barrier/**"
        ]
        /// Evolution plane (SC-ZENOH-EVO-001)
        EvolutionPlane = [
            "indrajaal/evolution/shadow/*/execution"
            "indrajaal/evolution/shadow/*/comparison"
            "indrajaal/evolution/shadow/*/promotion"
            "indrajaal/evolution/gym/episode/*"
            "indrajaal/evolution/gym/stats"
            "indrajaal/evolution/guardian/validations"
            "indrajaal/evolution/openrouter/calls"
            "indrajaal/evolution/stats"
        ]
    |}

    /// Build fractal key expression for specific level and domain
    let fractalKey (level: FractalLevel) (domain: string) (eventType: string) =
        let levelStr = FractalLevel.toString level |> fun s -> s.ToLowerInvariant()
        let domainStr = domain.ToLowerInvariant().Replace(" ", "_")
        let eventStr = eventType.ToLowerInvariant().Replace(" ", "_")
        sprintf "indrajaal/fractal/%s/%s/%s" levelStr domainStr eventStr

    /// Build wildcard expression for all events in a domain
    let fractalDomainWildcard (domain: string) =
        let domainStr = domain.ToLowerInvariant().Replace(" ", "_")
        sprintf "indrajaal/fractal/**/%s/**" domainStr

    /// Build telemetry key for F# metrics
    let telemetryKey (metricName: string) =
        sprintf "indrajaal/telemetry/fsharp/%s" metricName

    /// Build control key
    let controlKey (command: string) =
        sprintf "indrajaal/control/%s" command

    /// Build coordination key
    let coordKey (key: string) =
        sprintf "indrajaal/coord/%s" key
