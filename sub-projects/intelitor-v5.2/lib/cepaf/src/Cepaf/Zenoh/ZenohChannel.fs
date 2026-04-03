namespace Cepaf.Zenoh

open System
open System.Threading
open System.Collections.Concurrent
open Cepaf
open Cepaf.Observability

/// Zenoh Channel for QuadplexLogger Integration
/// Routes log entries to Zenoh for cross-language observability.
///
/// ## STAMP Constraints
/// - SC-ZENOH-CHN-001: Non-blocking log dispatch
/// - SC-ZENOH-CHN-002: Batch optimization for efficiency
/// - SC-ZENOH-CHN-003: Graceful degradation on disconnection
///
/// ## Integration
/// This channel integrates with QuadplexLogger to provide a 5th channel
/// for Zenoh pub/sub messaging to Indrajaal and other subscribers.
module ZenohChannel =

    // ========================================================================
    // TYPES
    // ========================================================================

    /// Log entry for Zenoh transmission
    type ZenohLogEntry = {
        Timestamp: DateTimeOffset
        Level: string
        Domain: string
        Message: string
        Metadata: Map<string, obj>
        TraceId: string option
        SpanId: string option
        Source: string
    }

    /// Channel configuration
    type ChannelConfig = {
        Enabled: bool
        KeyPrefix: string
        BatchSize: int
        FlushIntervalMs: int
        Levels: string list
    }

    /// Channel statistics
    type ChannelStats = {
        EntriesPublished: int64
        Flushes: int64
        Errors: int64
        TotalLatencyMs: float
        LastFlushAt: DateTimeOffset option
    }

    // ========================================================================
    // DEFAULTS
    // ========================================================================

    /// Default channel configuration
    let defaultConfig = {
        Enabled = true
        KeyPrefix = "indrajaal/telemetry/fsharp"
        BatchSize = 100
        FlushIntervalMs = 100
        Levels = ["Info"; "Warning"; "Error"; "Critical"; "Debug"]
    }

    // ========================================================================
    // STATE
    // ========================================================================

    let mutable private config = defaultConfig
    let private buffer = ConcurrentQueue<ZenohLogEntry>()
    let mutable private stats = {
        EntriesPublished = 0L
        Flushes = 0L
        Errors = 0L
        TotalLatencyMs = 0.0
        LastFlushAt = None
    }
    let private statsLock = obj()
    let mutable private flushTimer : Timer option = None

    // ========================================================================
    // INTERNAL FUNCTIONS
    // ========================================================================

    /// Build Zenoh key from entry
    let private buildKey (entry: ZenohLogEntry) =
        let level = entry.Level.ToLowerInvariant()
        let domain = entry.Domain.ToLowerInvariant().Replace(" ", "_")
        sprintf "%s/%s/%s" config.KeyPrefix level domain

    /// Encode entry to JSON bytes
    let private encodeEntry (entry: ZenohLogEntry) =
        let json = System.Text.Json.JsonSerializer.Serialize({|
            timestamp = entry.Timestamp.ToString("o")
            level = entry.Level
            domain = entry.Domain
            message = entry.Message
            metadata = entry.Metadata
            traceId = entry.TraceId
            spanId = entry.SpanId
            source = entry.Source
        |})
        System.Text.Encoding.UTF8.GetBytes(json)

    /// Flush the buffer to Zenoh
    let private flushBuffer () =
        if buffer.IsEmpty then ()
        else
            let entries = ResizeArray<ZenohLogEntry>()
            let mutable entry = Unchecked.defaultof<ZenohLogEntry>

            while entries.Count < config.BatchSize && buffer.TryDequeue(&entry) do
                entries.Add(entry)

            if entries.Count > 0 then
                let start = DateTimeOffset.UtcNow

                // Publish each entry
                for e in entries do
                    let key = buildKey e
                    let payload = encodeEntry e

                    match ZenohSession.publish key payload with
                    | Ok () -> ()
                    | Error err ->
                        lock statsLock (fun () ->
                            stats <- { stats with Errors = stats.Errors + 1L }
                        )
                        printfn "[ZenohChannel] Publish error: %s" err

                let elapsed = (DateTimeOffset.UtcNow - start).TotalMilliseconds

                lock statsLock (fun () ->
                    stats <- {
                        stats with
                            EntriesPublished = stats.EntriesPublished + int64 entries.Count
                            Flushes = stats.Flushes + 1L
                            TotalLatencyMs = stats.TotalLatencyMs + elapsed
                            LastFlushAt = Some DateTimeOffset.UtcNow
                    }
                )

                // Log if latency exceeds target
                if elapsed > 10.0 then
                    printfn "[ZenohChannel] WARNING: Flush latency %.2fms for %d entries" elapsed entries.Count

    /// Schedule flush timer
    let private scheduleFlush () =
        match flushTimer with
        | Some timer -> timer.Change(config.FlushIntervalMs, config.FlushIntervalMs) |> ignore
        | None -> ()

    /// Initialize timer (called once during module initialization)
    let private initTimer () =
        if flushTimer.IsNone then
            flushTimer <- Some (new Timer((fun _ -> flushBuffer()), null, Timeout.Infinite, Timeout.Infinite))

    // ========================================================================
    // PUBLIC API
    // ========================================================================

    /// Initialize the channel with configuration
    let initialize (cfg: ChannelConfig) =
        config <- cfg
        initTimer ()
        if cfg.Enabled then
            scheduleFlush ()
            printfn "[ZenohChannel] Initialized with prefix: %s" cfg.KeyPrefix

    /// Initialize with default configuration
    let initializeDefault () =
        initialize defaultConfig

    /// Write a log entry to the channel
    let write (entry: ZenohLogEntry) =
        if not config.Enabled then ()
        elif not (config.Levels |> List.contains entry.Level) then ()
        else
            buffer.Enqueue(entry)

            // Auto-flush if buffer exceeds batch size
            if buffer.Count >= config.BatchSize then
                ThreadPool.QueueUserWorkItem(fun _ -> flushBuffer()) |> ignore

    /// Write from QuadplexLogger QuadplexEvent
    let writeQuadplexEvent (event: QuadplexEvent) =
        let traceId =
            event.Metadata.TraceContext
            |> Option.map (fun tc -> tc.TraceId)
        let spanId =
            event.Metadata.TraceContext
            |> Option.map (fun tc -> tc.SpanId)
        let entry = {
            Timestamp = event.Timestamp
            Level = event.Level.ToString()
            Domain = event.Metadata.Category
            Message = event.Message
            Metadata = event.Metadata.CustomProperties
            TraceId = traceId
            SpanId = spanId
            Source = "cepaf"
        }
        write entry

    /// Force flush all buffered entries
    let flush () =
        flushBuffer ()

    /// Get channel statistics
    let getStats () = stats

    /// Enable or disable the channel
    let setEnabled (enabled: bool) =
        config <- { config with Enabled = enabled }
        if enabled then scheduleFlush ()
        else
            match flushTimer with
            | Some timer -> timer.Change(Timeout.Infinite, Timeout.Infinite) |> ignore
            | None -> ()

    /// Check if channel is enabled
    let isEnabled () = config.Enabled

    /// Close the channel
    let close () =
        flush ()
        match flushTimer with
        | Some timer -> timer.Dispose()
        | None -> ()
        printfn "[ZenohChannel] Channel closed"

    // ========================================================================
    // QUADPLEX INTEGRATION
    // ========================================================================

    /// Create a logger output channel for QuadplexLogger
    /// Returns a function that can be passed to QuadplexLogger configuration
    let createLoggerChannel () : (QuadplexEvent -> unit) =
        fun event -> writeQuadplexEvent event

    // ========================================================================
    // CONVENIENCE FUNCTIONS
    // ========================================================================

    /// Log info message
    let info (domain: string) (message: string) =
        write {
            Timestamp = DateTimeOffset.UtcNow
            Level = "Info"
            Domain = domain
            Message = message
            Metadata = Map.empty
            TraceId = None
            SpanId = None
            Source = "cepaf"
        }

    /// Log warning message
    let warning (domain: string) (message: string) =
        write {
            Timestamp = DateTimeOffset.UtcNow
            Level = "Warning"
            Domain = domain
            Message = message
            Metadata = Map.empty
            TraceId = None
            SpanId = None
            Source = "cepaf"
        }

    /// Log error message
    let error (domain: string) (message: string) =
        write {
            Timestamp = DateTimeOffset.UtcNow
            Level = "Error"
            Domain = domain
            Message = message
            Metadata = Map.empty
            TraceId = None
            SpanId = None
            Source = "cepaf"
        }

    /// Log debug message
    let debug (domain: string) (message: string) =
        write {
            Timestamp = DateTimeOffset.UtcNow
            Level = "Debug"
            Domain = domain
            Message = message
            Metadata = Map.empty
            TraceId = None
            SpanId = None
            Source = "cepaf"
        }

    /// Log with metadata
    let logWithMetadata (level: string) (domain: string) (message: string) (metadata: Map<string, obj>) =
        write {
            Timestamp = DateTimeOffset.UtcNow
            Level = level
            Domain = domain
            Message = message
            Metadata = metadata
            TraceId = None
            SpanId = None
            Source = "cepaf"
        }
