// =============================================================================
// FractalLogger.fs - SIL-4 Compliant Fractal Logging with Zenoh Telemetry
// =============================================================================
// STAMP: SC-SIL4-009, SC-OBS-069, SC-OBS-071, SC-BRIDGE-005, SC-PRF-050
// AOR: AOR-SIL4-006, AOR-BRIDGE-001, AOR-BRIDGE-002
//
// ## Techniques Implemented
// | Technique | Source | Purpose |
// |-----------|--------|---------|
// | Structured Metadata Injection | Google Dapper | Trace context propagation |
// | Head-Based Sampling | Jaeger | Adaptive telemetry reduction |
// | Fractal Log Levels | 5-Level System | L1-L5 granularity |
// | Zenoh Pub/Sub | Eclipse Zenoh | Real-time telemetry |
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-04 |
// | Author | Cybernetic Architect |
// =============================================================================

namespace Cepaf.Mesh

open System
open System.Diagnostics
open System.Collections.Generic
open System.Text.Json

/// <summary>
/// Fractal log levels (L1-L5)
/// </summary>
type FractalLevel =
    | L1_Critical = 1   // System failures, SIL-4 violations
    | L2_Error = 2      // Operational errors, rollbacks
    | L3_Warning = 3    // Degraded operation, retries
    | L4_Info = 4       // Normal operations, state changes
    | L5_Debug = 5      // Detailed diagnostics, timing

/// <summary>
/// Log entry domain (container operations)
/// </summary>
type LogDomain =
    | Boot
    | Shutdown
    | Health
    | Topology
    | Drain
    | Checkpoint
    | Dashboard
    | Zenoh
    | LifecycleOp

/// <summary>
/// Trace context for distributed tracing (Dapper-style)
/// </summary>
type TraceContext = {
    /// Unique trace ID (spans entire operation)
    TraceId: string
    /// Span ID (current operation)
    SpanId: string
    /// Parent span ID (if nested)
    ParentSpanId: string option
    /// Sampling decision (head-based)
    Sampled: bool
    /// Baggage items (propagated context)
    Baggage: Map<string, string>
}

/// <summary>
/// Structured log entry
/// </summary>
type LogEntry = {
    /// Timestamp (UTC)
    Timestamp: DateTimeOffset
    /// Fractal level
    Level: FractalLevel
    /// Log domain
    Domain: LogDomain
    /// Message
    Message: string
    /// Holon/container ID
    HolonId: string option
    /// Trace context
    Trace: TraceContext option
    /// Duration in microseconds
    DurationUs: int64 option
    /// Structured attributes
    Attributes: Map<string, obj>
    /// Error if any
    Error: string option
}

/// <summary>
/// Sampling configuration (head-based)
/// </summary>
type SamplingConfig = {
    /// Sample rate for L5_Debug (0.0 - 1.0)
    DebugRate: float
    /// Sample rate for L4_Info (0.0 - 1.0)
    InfoRate: float
    /// Always sample L1-L3 (critical, error, warning)
    AlwaysSampleCritical: bool
    /// Adaptive sampling based on load
    AdaptiveSampling: bool
    /// Target events per second
    TargetEventsPerSecond: int
}

/// <summary>
/// Zenoh topic configuration
/// </summary>
type ZenohTopicConfig = {
    /// Base topic prefix
    Prefix: string
    /// Boot events topic
    BootTopic: string
    /// Shutdown events topic
    ShutdownTopic: string
    /// Health events topic
    HealthTopic: string
    /// KPI metrics topic
    KpiTopic: string
    /// Alerts topic
    AlertsTopic: string
}

/// <summary>
/// Logger configuration
/// </summary>
type LoggerConfig = {
    /// Minimum level to log
    MinLevel: FractalLevel
    /// Enable console output
    ConsoleOutput: bool
    /// Enable Zenoh publishing
    ZenohOutput: bool
    /// Zenoh topic config
    ZenohTopics: ZenohTopicConfig
    /// Sampling config
    Sampling: SamplingConfig
    /// Enable structured JSON
    JsonFormat: bool
    /// Include trace context
    IncludeTrace: bool
}

/// <summary>
/// Fractal logger operations module
/// </summary>
module FractalLogger =

    /// Default Zenoh topics
    let defaultZenohTopics : ZenohTopicConfig = {
        Prefix = "indrajaal/mesh"
        BootTopic = "indrajaal/mesh/boot"
        ShutdownTopic = "indrajaal/mesh/shutdown"
        HealthTopic = "indrajaal/mesh/health"
        KpiTopic = "indrajaal/mesh/kpi"
        AlertsTopic = "indrajaal/mesh/alerts"
    }

    /// Default sampling configuration
    let defaultSampling : SamplingConfig = {
        DebugRate = 0.1              // 10% of debug logs
        InfoRate = 0.5               // 50% of info logs
        AlwaysSampleCritical = true  // 100% of L1-L3
        AdaptiveSampling = true
        TargetEventsPerSecond = 100
    }

    /// Default logger configuration
    let defaultConfig : LoggerConfig = {
        MinLevel = FractalLevel.L4_Info
        ConsoleOutput = true
        ZenohOutput = true
        ZenohTopics = defaultZenohTopics
        Sampling = defaultSampling
        JsonFormat = true
        IncludeTrace = true
    }

    /// Random for sampling
    let private random = Random()

    /// Current events per second counter
    let mutable private eventsThisSecond = 0
    let mutable private lastSecond = DateTime.UtcNow.Second

    /// Generate trace ID
    let generateTraceId () : string =
        Guid.NewGuid().ToString("N")

    /// Generate span ID
    let generateSpanId () : string =
        Guid.NewGuid().ToString("N").Substring(0, 16)

    /// Create new trace context
    let createTraceContext () : TraceContext = {
        TraceId = generateTraceId ()
        SpanId = generateSpanId ()
        ParentSpanId = None
        Sampled = true
        Baggage = Map.empty
    }

    /// Create child span
    let createChildSpan (parent: TraceContext) : TraceContext = {
        TraceId = parent.TraceId
        SpanId = generateSpanId ()
        ParentSpanId = Some parent.SpanId
        Sampled = parent.Sampled
        Baggage = parent.Baggage
    }

    /// Add baggage to trace context
    let addBaggage (key: string) (value: string) (ctx: TraceContext) : TraceContext =
        { ctx with Baggage = Map.add key value ctx.Baggage }

    /// Head-based sampling decision
    let shouldSample (level: FractalLevel) (config: SamplingConfig) : bool =
        // Always sample critical logs
        if config.AlwaysSampleCritical && int level <= int FractalLevel.L3_Warning then
            true
        else
            // Adaptive sampling - reduce if over target
            let adaptiveMultiplier =
                if config.AdaptiveSampling then
                    let currentSecond = DateTime.UtcNow.Second
                    if currentSecond <> lastSecond then
                        eventsThisSecond <- 0
                        lastSecond <- currentSecond

                    if eventsThisSecond > config.TargetEventsPerSecond then
                        0.1  // Reduce to 10% when over limit
                    else
                        1.0
                else
                    1.0

            let rate =
                match level with
                | FractalLevel.L5_Debug -> config.DebugRate * adaptiveMultiplier
                | FractalLevel.L4_Info -> config.InfoRate * adaptiveMultiplier
                | _ -> 1.0

            random.NextDouble() < rate

    /// Format level for console
    let formatLevel (level: FractalLevel) : string =
        match level with
        | FractalLevel.L1_Critical -> sprintf "\u001b[31m\u001b[1mCRIT\u001b[0m"
        | FractalLevel.L2_Error -> sprintf "\u001b[31mERROR\u001b[0m"
        | FractalLevel.L3_Warning -> sprintf "\u001b[33mWARN\u001b[0m"
        | FractalLevel.L4_Info -> sprintf "\u001b[36mINFO\u001b[0m"
        | FractalLevel.L5_Debug -> sprintf "\u001b[37mDEBUG\u001b[0m"
        | _ -> "???"

    /// Format domain for console
    let formatDomain (domain: LogDomain) : string =
        match domain with
        | Boot -> "BOOT"
        | Shutdown -> "SHUTDOWN"
        | Health -> "HEALTH"
        | Topology -> "TOPOLOGY"
        | Drain -> "DRAIN"
        | Checkpoint -> "CHECKPOINT"
        | Dashboard -> "DASHBOARD"
        | Zenoh -> "ZENOH"
        | LifecycleOp -> "LIFECYCLE"

    /// Format entry for console output
    let formatConsole (entry: LogEntry) : string =
        let ts = entry.Timestamp.ToString("HH:mm:ss.fff")
        let level = formatLevel entry.Level
        let domain = formatDomain entry.Domain

        let holonPart =
            match entry.HolonId with
            | Some id -> sprintf " [%s]" id
            | None -> ""

        let durationPart =
            match entry.DurationUs with
            | Some us when us >= 1000L -> sprintf " (%dms)" (us / 1000L)
            | Some us -> sprintf " (%dμs)" us
            | None -> ""

        let tracePart =
            match entry.Trace with
            | Some t -> sprintf " trace=%s" (t.TraceId.Substring(0, 8))
            | None -> ""

        sprintf "[%s] [%-8s] [%-7s]%s %s%s%s"
            ts domain level holonPart entry.Message durationPart tracePart

    /// Format entry for JSON output
    let formatJson (entry: LogEntry) : string =
        let dict = Dictionary<string, obj>()
        dict.["timestamp"] <- entry.Timestamp.ToString("o")
        dict.["level"] <- int entry.Level
        dict.["levelName"] <- formatDomain entry.Domain
        dict.["domain"] <- entry.Domain.ToString()
        dict.["message"] <- entry.Message

        match entry.HolonId with
        | Some id -> dict.["holonId"] <- id
        | None -> ()

        match entry.Trace with
        | Some t ->
            dict.["traceId"] <- t.TraceId
            dict.["spanId"] <- t.SpanId
            match t.ParentSpanId with
            | Some p -> dict.["parentSpanId"] <- p
            | None -> ()
            dict.["sampled"] <- t.Sampled
            if not t.Baggage.IsEmpty then
                let baggageDict = Dictionary<string, obj>()
                for KeyValue(k, v) in t.Baggage do
                    baggageDict.[k] <- v :> obj
                dict.["baggage"] <- box baggageDict
        | None -> ()

        match entry.DurationUs with
        | Some us -> dict.["durationUs"] <- us
        | None -> ()

        for KeyValue(k, v) in entry.Attributes do
            dict.["attr_" + k] <- v

        match entry.Error with
        | Some e -> dict.["error"] <- e
        | None -> ()

        let options = JsonSerializerOptions(WriteIndented = false)
        JsonSerializer.Serialize(dict, options)

    /// Get Zenoh topic for entry
    let getZenohTopic (entry: LogEntry) (config: ZenohTopicConfig) : string =
        match entry.Domain with
        | Boot -> config.BootTopic
        | Shutdown -> config.ShutdownTopic
        | Health -> config.HealthTopic
        | Dashboard -> config.KpiTopic
        | _ ->
            if int entry.Level <= int FractalLevel.L2_Error then
                config.AlertsTopic
            else
                config.Prefix

    /// Simulated Zenoh publish (real implementation would use Zenoh client)
    let publishToZenoh (topic: string) (payload: string) : unit =
        // In real implementation: zenoh_session.put(topic, payload)
        // For now, just log that we would publish
        if defaultConfig.ConsoleOutput then
            printfn "[ZENOH] → %s (size=%d)" topic payload.Length

    /// Log entry with configuration
    let logWithConfig (config: LoggerConfig) (entry: LogEntry) : unit =
        // Check minimum level
        if int entry.Level > int config.MinLevel then
            ()
        else
            // Apply sampling
            let sampled =
                match entry.Trace with
                | Some t -> t.Sampled
                | None -> shouldSample entry.Level config.Sampling

            if not sampled then
                ()
            else
                // Update events counter for adaptive sampling
                eventsThisSecond <- eventsThisSecond + 1

                // Console output
                if config.ConsoleOutput then
                    if config.JsonFormat then
                        printfn "%s" (formatJson entry)
                    else
                        printfn "%s" (formatConsole entry)

                // Zenoh output
                if config.ZenohOutput then
                    let topic = getZenohTopic entry config.ZenohTopics
                    let payload = formatJson entry
                    publishToZenoh topic payload

    /// Global logger with default config
    let private globalConfig = ref defaultConfig

    /// Set global logger configuration
    let configure (config: LoggerConfig) : unit =
        globalConfig := config

    /// Log with global configuration
    let log (entry: LogEntry) : unit =
        logWithConfig !globalConfig entry

    /// Create log entry helper
    let createEntry
        (level: FractalLevel)
        (domain: LogDomain)
        (message: string)
        (holonId: string option)
        (trace: TraceContext option)
        (durationUs: int64 option)
        (attributes: Map<string, obj>)
        (error: string option)
        : LogEntry =
        {
            Timestamp = DateTimeOffset.UtcNow
            Level = level
            Domain = domain
            Message = message
            HolonId = holonId
            Trace = trace
            DurationUs = durationUs
            Attributes = attributes
            Error = error
        }

    // Convenience logging functions

    /// Log critical (L1)
    let critical (domain: LogDomain) (message: string) : unit =
        log (createEntry FractalLevel.L1_Critical domain message None None None Map.empty None)

    /// Log error (L2)
    let error (domain: LogDomain) (message: string) (err: string option) : unit =
        log (createEntry FractalLevel.L2_Error domain message None None None Map.empty err)

    /// Log warning (L3)
    let warn (domain: LogDomain) (message: string) : unit =
        log (createEntry FractalLevel.L3_Warning domain message None None None Map.empty None)

    /// Log info (L4)
    let info (domain: LogDomain) (message: string) : unit =
        log (createEntry FractalLevel.L4_Info domain message None None None Map.empty None)

    /// Log debug (L5)
    let debug (domain: LogDomain) (message: string) : unit =
        log (createEntry FractalLevel.L5_Debug domain message None None None Map.empty None)

    /// Log with holon context
    let logHolon (level: FractalLevel) (domain: LogDomain) (holonId: string) (message: string) : unit =
        log (createEntry level domain message (Some holonId) None None Map.empty None)

    /// Log with trace context
    let logTrace (level: FractalLevel) (domain: LogDomain) (trace: TraceContext) (message: string) : unit =
        log (createEntry level domain message None (Some trace) None Map.empty None)

    /// Log with timing
    let logTimed (level: FractalLevel) (domain: LogDomain) (durationUs: int64) (message: string) : unit =
        log (createEntry level domain message None None (Some durationUs) Map.empty None)

    /// Time an operation and log result
    let timeOperation<'T> (level: FractalLevel) (domain: LogDomain) (message: string) (operation: unit -> 'T) : 'T =
        let sw = Stopwatch.StartNew()
        try
            let result = operation ()
            sw.Stop()
            log (createEntry level domain (sprintf "%s completed" message) None None (Some (sw.ElapsedTicks * 1000000L / Stopwatch.Frequency)) Map.empty None)
            result
        with ex ->
            sw.Stop()
            log (createEntry FractalLevel.L2_Error domain (sprintf "%s failed" message) None None (Some (sw.ElapsedTicks * 1000000L / Stopwatch.Frequency)) Map.empty (Some ex.Message))
            reraise ()

    /// Log boot event
    let logBoot (holonId: string) (phase: string) (durationMs: int64) : unit =
        log (createEntry FractalLevel.L4_Info Boot (sprintf "%s: %s" holonId phase) (Some holonId) None (Some (durationMs * 1000L)) Map.empty None)

    /// Log shutdown event
    let logShutdown (holonId: string) (phase: string) (durationMs: int64) : unit =
        log (createEntry FractalLevel.L4_Info Shutdown (sprintf "%s: %s" holonId phase) (Some holonId) None (Some (durationMs * 1000L)) Map.empty None)

    /// Log health check
    let logHealth (holonId: string) (status: string) (score: float) : unit =
        let attrs = Map.ofList [("healthScore", box score)]
        log (createEntry FractalLevel.L4_Info Health (sprintf "%s: %s (score=%.2f)" holonId status score) (Some holonId) None None attrs None)

    /// Log KPI update
    let logKpi (kpiName: string) (value: float) (unit: string) : unit =
        let attrs = Map.ofList [("kpiName", box kpiName); ("value", box value); ("unit", box unit)]
        log (createEntry FractalLevel.L4_Info Dashboard (sprintf "KPI: %s = %.2f %s" kpiName value unit) None None None attrs None)

    /// Log SLA violation
    let logSlaViolation (slaName: string) (expected: float) (actual: float) : unit =
        let attrs = Map.ofList [("slaName", box slaName); ("expected", box expected); ("actual", box actual)]
        log (createEntry FractalLevel.L3_Warning Dashboard (sprintf "SLA VIOLATION: %s expected=%.2f actual=%.2f" slaName expected actual) None None None attrs None)

    /// Log a lifecycle phase transition
    let logPhase (domain: string) (holonId: string) (phase: string) (message: string) : unit =
        let attrs = Map.ofList [("domain", box domain); ("phase", box phase)]
        log (createEntry FractalLevel.L4_Info LifecycleOp (sprintf "[%s] %s: %s - %s" domain holonId phase message) (Some holonId) None None attrs None)

