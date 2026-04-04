// =============================================================================
// QuadruplexLogger.fs - SIL-6 High-Assurance Git Intelligence Logging
// =============================================================================
// Purpose:  Implement Quadruplex logging (Console, JSON, Zenoh, OTEL) for 
//           GitIntelligence holon. Ensures real-time closed-loop observability.
//
// STAMP:    SC-LOG-004, SC-OBS-069, SC-OBS-071, SC-ZENOH-001
// AOR:      AOR-SIL6-006, AOR-FFI-006 (dual-write)
// =============================================================================

namespace Cepaf.GitIntelligence

open System
open System.IO
open System.Diagnostics
open System.Collections.Generic
open System.Text.Json
open OpenTelemetry
open OpenTelemetry.Trace
open OpenTelemetry.Resources
open Cepaf.GitIntelligence.Notify

/// <summary>
/// Fractal log levels (L1-L5)
/// </summary>
type LogLevel =
    | Critical = 1   // System failures, SIL-6 violations
    | Error = 2      // Operational errors, rollbacks
    | Warning = 3    // Degraded operation, retries
    | Info = 4       // Normal operations, state changes
    | Debug = 5      // Detailed diagnostics, timing

/// <summary>
/// Log entry domain
/// </summary>
type LogDomain =
    | GitAnalysis
    | GitCommit
    | Validation
    | Biomorphic
    | Neural
    | Homeostasis
    | Safety
    | Integration
    | System

/// <summary>
/// Structured log entry
/// </summary>
type LogEntry = {
    Timestamp: DateTimeOffset
    Level: LogLevel
    Domain: LogDomain
    Message: string
    TraceId: string option
    SpanId: string option
    DurationMs: int64 option
    Attributes: Map<string, obj>
    Error: string option
}

/// <summary>
/// Logger configuration
/// </summary>
type LoggerConfig = {
    MinLevel: LogLevel
    ConsoleOutput: bool
    FileOutput: bool
    ZenohOutput: bool
    OtelOutput: bool
    LogFilePath: string option
    ServiceName: string
}

module QuadruplexLogger =

    let private DefaultConfig : LoggerConfig = {
        MinLevel = LogLevel.Info
        ConsoleOutput = true
        FileOutput = true
        ZenohOutput = true
        OtelOutput = true
        LogFilePath = Some "git-intelligence.log"
        ServiceName = "git-intelligence"
    }

    let mutable private activeConfig = DefaultConfig
    let mutable private tracerProvider: TracerProvider option = None
    let private activitySource = new ActivitySource("Cepaf.GitIntelligence")

    /// Configure the logger and initialize OTEL if enabled
    let configure (config: LoggerConfig) =
        activeConfig <- config
        if config.OtelOutput then
            let builder = 
                Sdk.CreateTracerProviderBuilder()
                    .AddSource("Cepaf.GitIntelligence")
                    .SetResourceBuilder(ResourceBuilder.CreateDefault().AddService(config.ServiceName))
                    .AddOtlpExporter()
            tracerProvider <- Some (builder.Build())

    /// Shutdown the logger and OTEL
    let shutdown () =
        match tracerProvider with
        | Some tp -> tp.Dispose(); tracerProvider <- None
        | None -> ()
        Notify.closeSession()

    let private formatLevel (level: LogLevel) : string =
        match level with
        | LogLevel.Critical -> "\u001b[31m\u001b[1mCRIT\u001b[0m"
        | LogLevel.Error -> "\u001b[31mERR \u001b[0m"
        | LogLevel.Warning -> "\u001b[33mWARN\u001b[0m"
        | LogLevel.Info -> "\u001b[36mINFO\u001b[0m"
        | LogLevel.Debug -> "\u001b[37mDEBG\u001b[0m"
        | _ -> "????"

    let private formatEntry (entry: LogEntry) : string =
        let ts = entry.Timestamp.ToString("HH:mm:ss.fff")
        let level = formatLevel entry.Level
        let domain = entry.Domain.ToString().ToUpper()
        let trace = match entry.TraceId with Some id -> " trace=" + id.Substring(0, 8) | None -> ""
        let duration = match entry.DurationMs with Some ms -> sprintf " (%dms)" ms | None -> ""
        sprintf "[%s] [%-10s] [%s] %s%s%s" ts domain level entry.Message duration trace

    let private serializeEntry (entry: LogEntry) : string =
        let dict = Dictionary<string, obj>()
        dict.["timestamp"] <- entry.Timestamp.ToString("o")
        dict.["level"] <- int entry.Level
        dict.["domain"] <- entry.Domain.ToString()
        dict.["message"] <- entry.Message
        match entry.TraceId with Some id -> dict.["traceId"] <- id | None -> ()
        match entry.SpanId with Some id -> dict.["spanId"] <- id | None -> ()
        match entry.DurationMs with Some ms -> dict.["durationMs"] <- ms | None -> ()
        match entry.Error with Some e -> dict.["error"] <- e | None -> ()
        for KeyValue(k, v) in entry.Attributes do dict.[k] <- v
        JsonSerializer.Serialize(dict)

    /// Log a structured entry
    let log (level: LogLevel) (domain: LogDomain) (message: string) (attrs: Map<string, obj>) (err: string option) (duration: int64 option) =
        if int level <= int activeConfig.MinLevel then
            let currentActivity = Activity.Current
            let entry = {
                Timestamp = DateTimeOffset.UtcNow
                Level = level
                Domain = domain
                Message = message
                TraceId = if currentActivity <> null then Some (currentActivity.TraceId.ToHexString()) else None
                SpanId = if currentActivity <> null then Some (currentActivity.SpanId.ToHexString()) else None
                DurationMs = duration
                Attributes = attrs
                Error = err
            }

            // 1. Console
            if activeConfig.ConsoleOutput then
                printfn "%s" (formatEntry entry)

            // 2. JSON File
            if activeConfig.FileOutput then
                match activeConfig.LogFilePath with
                | Some path -> 
                    try File.AppendAllLines(path, [serializeEntry entry]) with _ -> ()
                | None -> ()

            // 3. Zenoh
            if activeConfig.ZenohOutput then
                let topic = sprintf "indrajaal/git/log/%s/%s" (domain.ToString().ToLower()) (level.ToString().ToLower())
                let payload = serializeEntry entry
                Notify.zenohPublish topic payload |> ignore

            // 4. OTEL (Event on current span)
            if activeConfig.OtelOutput && currentActivity <> null then
                let tags = ActivityTagsCollection()
                tags.Add("level", int level)
                tags.Add("domain", domain.ToString())
                tags.Add("message", message)
                match err with Some e -> tags.Add("error", e) | None -> ()
                for KeyValue(k, v) in attrs do tags.Add(k, v)
                currentActivity.AddEvent(ActivityEvent(message, entry.Timestamp, tags)) |> ignore

    // Convenience helpers
    let info domain msg = log LogLevel.Info domain msg Map.empty None None
    let warn domain msg = log LogLevel.Warning domain msg Map.empty None None
    let error domain msg err = log LogLevel.Error domain msg Map.empty (Some err) None
    let crit domain msg err = log LogLevel.Critical domain msg Map.empty (Some err) None
    let debug domain msg = log LogLevel.Debug domain msg Map.empty None None

    /// Start a timed operation with OTEL span
    let startSpan (domain: LogDomain) (name: string) =
        let activity = activitySource.StartActivity(name)
        if activity <> null then
            activity.SetTag("domain", domain.ToString()) |> ignore
        activity

    /// Execute and time an operation
    let time (domain: LogDomain) (name: string) (op: unit -> 'T) : 'T =
        use activity = startSpan domain name
        let sw = Stopwatch.StartNew()
        try
            let result = op()
            sw.Stop()
            log LogLevel.Info domain (sprintf "%s completed" name) Map.empty None (Some sw.ElapsedMilliseconds)
            result
        with ex ->
            sw.Stop()
            log LogLevel.Error domain (sprintf "%s failed" name) Map.empty (Some ex.Message) (Some sw.ElapsedMilliseconds)
            reraise()
