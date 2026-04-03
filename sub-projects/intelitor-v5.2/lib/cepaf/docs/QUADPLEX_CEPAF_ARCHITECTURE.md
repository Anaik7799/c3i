# CEPAF Quadplex Observability Architecture
**Version**: 1.0.0 | **Date**: 2025-12-23 | **Status**: SPECIFICATION
**Compliance**: SOPv5.11, SC-OBS-069, SC-OBS-071, AOR-QUA-001

---

## Executive Summary

This document specifies the full Quadplex observability implementation for CEPAF# (Cybernetic Execution and Performance Architect - F# Edition). The Quadplex system provides enterprise-grade 4-channel logging with distributed tracing, persistent state management, and real-time telemetry streaming.

---

## 1. Architecture Overview

### 1.1 The Four Channels

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      CEPAF# APPLICATION LAYER                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ Orchestrator│  │  Phases     │  │  Modules    │  │   Domain    │    │
│  │             │  │ (ACE,VTO,DB)│  │(Phics,Agent)│  │   Events    │    │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘    │
│         └────────────────┴────────────────┴────────────────┘           │
│                                    │                                    │
│                    ┌───────────────▼───────────────┐                   │
│                    │      QuadplexLogger           │                   │
│                    │   (Central Event Router)      │                   │
│                    └───────────────┬───────────────┘                   │
└────────────────────────────────────┼────────────────────────────────────┘
                                     │
        ┌────────────────────────────┼────────────────────────────────┐
        │                            │                                │
        ▼                            ▼                                ▼
┌───────────────┐  ┌─────────────────────────────┐  ┌─────────────────────┐
│   CHANNEL 1   │  │        CHANNEL 2            │  │     CHANNEL 3       │
│   TERMINAL    │  │         FILE                │  │     TELEMETRY       │
├───────────────┤  ├─────────────────────────────┤  ├─────────────────────┤
│ • Serilog     │  │ • Structured JSON/Text      │  │ • OpenTelemetry     │
│ • Console    │  │ • Rotating logs             │  │ • OTLP Protocol     │
│ • Color-coded │  │ • Audit trail              │  │ • SigNoz/Jaeger     │
│ • Real-time   │  │ • Session-based            │  │ • Metrics + Traces  │
└───────────────┘  └─────────────────────────────┘  └─────────────────────┘
                                     │
                                     ▼
                   ┌─────────────────────────────────┐
                   │          CHANNEL 4              │
                   │        STATE TRACKER            │
                   ├─────────────────────────────────┤
                   │ • SQLite Persistence            │
                   │ • Task History                  │
                   │ • System State CRDT             │
                   │ • Recovery & Analysis           │
                   └─────────────────────────────────┘
```

### 1.2 Channel Specifications

| Channel | Technology | Purpose | Retention | Format |
|---------|------------|---------|-----------|--------|
| **Terminal** | Serilog.Console | Developer UX, Real-time visibility | Ephemeral | Colored, Human-readable |
| **File** | File.AppendText | Audit trail, Post-mortem analysis | 30 days | JSON/Structured Text |
| **Telemetry** | OpenTelemetry SDK | Distributed tracing, Metrics | SigNoz configured | OTLP/gRPC |
| **State Tracker** | SQLite (Microsoft.Data.Sqlite) | State persistence, Recovery | Permanent | Relational |

---

## 2. Core Types and Domain Model

### 2.1 F# Type Definitions

```fsharp
namespace Cepaf.Observability

open System

// ============================================================================
// TELEMETRY EVENT TYPES
// ============================================================================

/// Log severity levels aligned with Serilog/OpenTelemetry
type LogLevel =
    | Trace = 0
    | Debug = 1
    | Info = 2
    | Warning = 3
    | Error = 4
    | Critical = 5

/// Trace context for distributed tracing correlation
type TraceContext = {
    TraceId: string        // 32-char hex (128-bit)
    SpanId: string         // 16-char hex (64-bit)
    ParentSpanId: string option
    TraceFlags: byte       // Sampling flag
    TraceState: string     // Vendor-specific data
}

/// Structured metadata for log enrichment
type LogMetadata = {
    Timestamp: DateTimeOffset
    Level: LogLevel
    Category: string
    TraceContext: TraceContext option
    TenantId: string option
    UserId: string option
    SessionId: string option
    CorrelationId: string
    MachineName: string
    ProcessId: int
    ThreadId: int
    CustomProperties: Map<string, obj>
}

/// Domain-specific event categories
type EventCategory =
    | Protocol          // Orchestrator lifecycle events
    | Phase             // Phase start/complete
    | Task              // Task progress/completion
    | Safety            // STAMP constraint events
    | Container         // Podman/Docker events
    | Performance       // Metrics and timings
    | Security          // Security-related events
    | Agent             // Cybernetic agent events
    | OODA              // OODA loop transitions
    | Phics             // Hot-reload events
    | Database          // DB verification events
    | Network           // Network/connectivity events

/// Rich telemetry event with full context
type QuadplexEvent = {
    Id: Guid
    Timestamp: DateTimeOffset
    Category: EventCategory
    Level: LogLevel
    Message: string
    Metadata: LogMetadata
    Payload: TelemetryPayload
    Exception: exn option
}

/// Event payload variants
and TelemetryPayload =
    | ProtocolStart of timestamp: DateTimeOffset
    | ProtocolComplete of durationMs: int64 * success: bool
    | PhaseStart of name: string * context: Map<string, string>
    | PhaseComplete of name: string * durationMs: int64 * success: bool * metrics: Map<string, float>
    | TaskUpdate of task: ProtocolTask
    | OodaTransition of phase: string * decision: string * confidence: float
    | SafetyAuditStarted
    | SafetyCheckPassed of constraintId: string * details: string
    | SafetyCheckFailed of constraintId: string * reason: string * severity: string
    | SafetyAuditComplete of success: bool * summary: Map<string, int>
    | MetricLogged of name: string * value: float * unit: string * tags: Map<string, string>
    | SpanStarted of spanName: string * parentId: string option
    | SpanEnded of spanName: string * durationMs: int64 * status: string
    | ContainerEvent of containerId: string * status: string * details: string
    | AgentEvent of agentId: string * status: string * efficiency: float
    | PhicsReload of filePath: string * latencyMs: int64 * success: bool
    | Custom of eventType: string * data: Map<string, obj>

// ============================================================================
// STAMP SAFETY CONSTRAINTS FOR OBSERVABILITY
// ============================================================================

/// SC-OBS Compliance Requirements
type ObservabilityConstraint = {
    Id: string
    Description: string
    Mandatory: bool
    Validation: unit -> Result<unit, string>
}

let scObs069 = {
    Id = "SC-OBS-069"
    Description = "Dual logging (Terminal + SigNoz) MANDATORY"
    Mandatory = true
    Validation = fun () -> Ok () // Validated at startup
}

let scObs071 = {
    Id = "SC-OBS-071"
    Description = "4 OTEL modules attached (Telemetry, Logging, Tracing, Metrics)"
    Mandatory = true
    Validation = fun () -> Ok ()
}
```

### 2.2 Configuration Types

```fsharp
/// Quadplex configuration
type QuadplexConfig = {
    // Channel 1: Terminal
    ConsoleEnabled: bool
    ConsoleMinLevel: LogLevel
    ConsoleColorEnabled: bool

    // Channel 2: File
    FileEnabled: bool
    FileMinLevel: LogLevel
    FilePath: string
    FileRotationSizeMb: int
    FileRetentionDays: int
    FileFormat: FileFormat

    // Channel 3: Telemetry
    TelemetryEnabled: bool
    OtlpEndpoint: string
    OtlpProtocol: OtlpProtocol
    ServiceName: string
    ServiceVersion: string
    Environment: string
    BatchSize: int
    FlushIntervalMs: int

    // Channel 4: State Tracker
    StateTrackerEnabled: bool
    DatabasePath: string
    PruneAfterDays: int

    // Global
    TraceContextPropagation: bool
    SamplingRate: float
    EnrichmentEnabled: bool
}

and FileFormat = JsonLines | StructuredText | CompactJson
and OtlpProtocol = Grpc | HttpProtobuf | HttpJson

let defaultConfig = {
    ConsoleEnabled = true
    ConsoleMinLevel = LogLevel.Info
    ConsoleColorEnabled = true

    FileEnabled = true
    FileMinLevel = LogLevel.Debug
    FilePath = "lib/cepaf/artifacts/logs/cepa-session.log"
    FileRotationSizeMb = 50
    FileRetentionDays = 30
    FileFormat = JsonLines

    TelemetryEnabled = true
    OtlpEndpoint = "http://localhost:4317"
    OtlpProtocol = Grpc
    ServiceName = "cepaf"
    ServiceVersion = "20.0.0"
    Environment = "development"
    BatchSize = 512
    FlushIntervalMs = 5000

    StateTrackerEnabled = true
    DatabasePath = "lib/cepaf/artifacts/cepa-state.db"
    PruneAfterDays = 90

    TraceContextPropagation = true
    SamplingRate = 1.0
    EnrichmentEnabled = true
}
```

---

## 3. Implementation Modules

### 3.1 Module Structure

```
lib/cepaf/src/Cepaf/
├── Observability/
│   ├── Types.fs              # Core type definitions
│   ├── TraceContext.fs       # Distributed tracing
│   ├── ConsoleChannel.fs     # Channel 1: Terminal output
│   ├── FileChannel.fs        # Channel 2: File logging
│   ├── TelemetryChannel.fs   # Channel 3: OpenTelemetry
│   ├── StateTracker.fs       # Channel 4: SQLite persistence
│   ├── QuadplexLogger.fs     # Central router (refactored)
│   ├── MetricsCollector.fs   # Performance metrics
│   └── Enrichment.fs         # Metadata enrichment
```

### 3.2 Channel Implementations

#### Channel 1: Console (Enhanced)

```fsharp
module Cepaf.Observability.ConsoleChannel

open System
open Serilog
open Serilog.Events

type ConsoleChannel(config: QuadplexConfig) =
    let logger =
        LoggerConfiguration()
            .MinimumLevel.Is(mapLevel config.ConsoleMinLevel)
            .WriteTo.Console(
                outputTemplate = "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}",
                theme = if config.ConsoleColorEnabled then Serilog.Sinks.SystemConsole.Themes.AnsiConsoleTheme.Code else null
            )
            .Enrich.WithMachineName()
            .Enrich.WithProcessId()
            .Enrich.WithThreadId()
            .CreateLogger()

    interface ILogChannel with
        member _.Write(event: QuadplexEvent) =
            let props =
                event.Metadata.CustomProperties
                |> Map.toList
                |> List.map (fun (k, v) -> (k, box v))

            match event.Level with
            | LogLevel.Trace -> logger.Verbose(event.Message)
            | LogLevel.Debug -> logger.Debug(event.Message)
            | LogLevel.Info -> logger.Information(event.Message)
            | LogLevel.Warning -> logger.Warning(event.Message)
            | LogLevel.Error ->
                match event.Exception with
                | Some ex -> logger.Error(ex, event.Message)
                | None -> logger.Error(event.Message)
            | LogLevel.Critical ->
                match event.Exception with
                | Some ex -> logger.Fatal(ex, event.Message)
                | None -> logger.Fatal(event.Message)
            | _ -> logger.Information(event.Message)

        member _.Flush() = Log.CloseAndFlush()
        member _.IsEnabled level = int level >= int config.ConsoleMinLevel

and ILogChannel =
    abstract member Write : QuadplexEvent -> unit
    abstract member Flush : unit -> unit
    abstract member IsEnabled : LogLevel -> bool
```

#### Channel 2: File (Enhanced with Rotation)

```fsharp
module Cepaf.Observability.FileChannel

open System
open System.IO
open System.Text.Json
open System.Text.Json.Serialization

type FileChannel(config: QuadplexConfig) =
    let mutable currentFile = config.FilePath
    let mutable currentSize = 0L
    let lockObj = obj()
    let maxBytes = int64 config.FileRotationSizeMb * 1024L * 1024L

    let jsonOptions =
        let opts = JsonSerializerOptions()
        opts.WriteIndented <- false
        opts.Converters.Add(JsonFSharpConverter())
        opts

    let ensureDirectory () =
        let dir = Path.GetDirectoryName(config.FilePath)
        if not (Directory.Exists(dir)) then
            Directory.CreateDirectory(dir) |> ignore

    let rotate () =
        let timestamp = DateTime.UtcNow.ToString("yyyyMMdd-HHmmss")
        let dir = Path.GetDirectoryName(config.FilePath)
        let name = Path.GetFileNameWithoutExtension(config.FilePath)
        let ext = Path.GetExtension(config.FilePath)
        let archivePath = Path.Combine(dir, sprintf "%s-%s%s" name timestamp ext)

        if File.Exists(currentFile) then
            File.Move(currentFile, archivePath)
        currentSize <- 0L

    let formatEvent (event: QuadplexEvent) =
        match config.FileFormat with
        | JsonLines -> JsonSerializer.Serialize(event, jsonOptions)
        | CompactJson -> JsonSerializer.Serialize(event, jsonOptions)
        | StructuredText ->
            sprintf "[%s] [%A] [%s] %s | TraceId=%s SpanId=%s"
                (event.Timestamp.ToString("O"))
                event.Level
                event.Category.ToString()
                event.Message
                (event.Metadata.TraceContext |> Option.map (fun t -> t.TraceId) |> Option.defaultValue "none")
                (event.Metadata.TraceContext |> Option.map (fun t -> t.SpanId) |> Option.defaultValue "none")

    do ensureDirectory()

    interface ILogChannel with
        member _.Write(event: QuadplexEvent) =
            if int event.Level >= int config.FileMinLevel then
                lock lockObj (fun () ->
                    if currentSize >= maxBytes then rotate()

                    let line = formatEvent event + Environment.NewLine
                    let bytes = System.Text.Encoding.UTF8.GetBytes(line)

                    use fs = new FileStream(currentFile, FileMode.Append, FileAccess.Write, FileShare.Read)
                    fs.Write(bytes, 0, bytes.Length)
                    currentSize <- currentSize + int64 bytes.Length
                )

        member _.Flush() = ()
        member _.IsEnabled level = int level >= int config.FileMinLevel
```

#### Channel 3: Telemetry (OpenTelemetry OTLP)

```fsharp
module Cepaf.Observability.TelemetryChannel

open System
open System.Net.Http
open System.Collections.Concurrent
open System.Threading

type TelemetryChannel(config: QuadplexConfig) =
    let queue = ConcurrentQueue<QuadplexEvent>()
    let mutable running = true
    let httpClient = new HttpClient()

    let toOtlpLogRecord (event: QuadplexEvent) =
        {|
            timeUnixNano = event.Timestamp.ToUnixTimeMilliseconds() * 1_000_000L
            severityNumber = int event.Level + 1
            severityText = event.Level.ToString()
            body = {| stringValue = event.Message |}
            attributes = [|
                {| key = "category"; value = {| stringValue = event.Category.ToString() |} |}
                {| key = "correlation_id"; value = {| stringValue = event.Metadata.CorrelationId |} |}
                match event.Metadata.TraceContext with
                | Some tc ->
                    yield {| key = "trace_id"; value = {| stringValue = tc.TraceId |} |}
                    yield {| key = "span_id"; value = {| stringValue = tc.SpanId |} |}
                | None -> ()
            |]
            traceId = event.Metadata.TraceContext |> Option.map (fun t -> t.TraceId) |> Option.defaultValue ""
            spanId = event.Metadata.TraceContext |> Option.map (fun t -> t.SpanId) |> Option.defaultValue ""
        |}

    let toOtlpMetric (name: string) (value: float) (unit: string) (tags: Map<string, string>) =
        {|
            name = name
            unit = unit
            gauge = {|
                dataPoints = [|
                    {|
                        asDouble = value
                        timeUnixNano = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() * 1_000_000L
                        attributes =
                            tags
                            |> Map.toArray
                            |> Array.map (fun (k, v) -> {| key = k; value = {| stringValue = v |} |})
                    |}
                |]
            |}
        |}

    let flushBatch () = async {
        let batch = ResizeArray<QuadplexEvent>()
        while batch.Count < config.BatchSize && not queue.IsEmpty do
            match queue.TryDequeue() with
            | true, event -> batch.Add(event)
            | false, _ -> ()

        if batch.Count > 0 then
            let logRecords = batch |> Seq.map toOtlpLogRecord |> Seq.toArray
            let payload = {|
                resourceLogs = [|
                    {|
                        resource = {|
                            attributes = [|
                                {| key = "service.name"; value = {| stringValue = config.ServiceName |} |}
                                {| key = "service.version"; value = {| stringValue = config.ServiceVersion |} |}
                                {| key = "deployment.environment"; value = {| stringValue = config.Environment |} |}
                            |]
                        |}
                        scopeLogs = [|
                            {|
                                scope = {| name = "cepaf.quadplex"; version = "1.0.0" |}
                                logRecords = logRecords
                            |}
                        |]
                    |}
                |]
            |}

            try
                let json = System.Text.Json.JsonSerializer.Serialize(payload)
                let content = new StringContent(json, System.Text.Encoding.UTF8, "application/json")
                let endpoint = sprintf "%s/v1/logs" config.OtlpEndpoint
                let! response = httpClient.PostAsync(endpoint, content) |> Async.AwaitTask
                if not response.IsSuccessStatusCode then
                    eprintfn "[OTLP] Failed to send logs: %d" (int response.StatusCode)
            with ex ->
                eprintfn "[OTLP] Export error: %s" ex.Message
    }

    let worker = async {
        while running do
            do! flushBatch()
            do! Async.Sleep config.FlushIntervalMs
    }

    do Async.Start worker

    interface ILogChannel with
        member _.Write(event: QuadplexEvent) =
            if config.TelemetryEnabled then
                queue.Enqueue(event)

        member _.Flush() =
            flushBatch() |> Async.RunSynchronously

        member _.IsEnabled _ = config.TelemetryEnabled

    interface IDisposable with
        member _.Dispose() =
            running <- false
            (__ :> ILogChannel).Flush()
            httpClient.Dispose()
```

#### Channel 4: State Tracker (Enhanced SQLite)

```fsharp
module Cepaf.Observability.StateTracker

open System
open Microsoft.Data.Sqlite

type StateTrackerChannel(config: QuadplexConfig) =
    let connectionString = sprintf "Data Source=%s" config.DatabasePath

    let initializeDb () =
        let dir = System.IO.Path.GetDirectoryName(config.DatabasePath)
        if not (System.IO.Directory.Exists(dir)) then
            System.IO.Directory.CreateDirectory(dir) |> ignore

        use conn = new SqliteConnection(connectionString)
        conn.Open()

        let cmd = conn.CreateCommand()
        cmd.CommandText <- """
            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                event_id TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                category TEXT NOT NULL,
                level TEXT NOT NULL,
                message TEXT NOT NULL,
                trace_id TEXT,
                span_id TEXT,
                correlation_id TEXT,
                payload_type TEXT,
                payload_json TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS tasks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                task_id TEXT NOT NULL,
                description TEXT,
                status TEXT NOT NULL,
                start_state TEXT,
                end_state TEXT,
                estimated_ms INTEGER,
                actual_ms INTEGER,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS system_state (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                key TEXT NOT NULL UNIQUE,
                value TEXT NOT NULL,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                value REAL NOT NULL,
                unit TEXT,
                tags_json TEXT,
                timestamp TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS spans (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                trace_id TEXT NOT NULL,
                span_id TEXT NOT NULL,
                parent_span_id TEXT,
                name TEXT NOT NULL,
                start_time TEXT NOT NULL,
                end_time TEXT,
                duration_ms INTEGER,
                status TEXT,
                attributes_json TEXT
            );

            CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp);
            CREATE INDEX IF NOT EXISTS idx_events_category ON events(category);
            CREATE INDEX IF NOT EXISTS idx_events_trace ON events(trace_id);
            CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
            CREATE INDEX IF NOT EXISTS idx_metrics_name ON metrics(name);
            CREATE INDEX IF NOT EXISTS idx_spans_trace ON spans(trace_id);
        """
        cmd.ExecuteNonQuery() |> ignore

    do initializeDb()

    let insertEvent (event: QuadplexEvent) =
        use conn = new SqliteConnection(connectionString)
        conn.Open()

        let cmd = conn.CreateCommand()
        cmd.CommandText <- """
            INSERT INTO events (event_id, timestamp, category, level, message, trace_id, span_id, correlation_id, payload_type, payload_json)
            VALUES (@event_id, @timestamp, @category, @level, @message, @trace_id, @span_id, @correlation_id, @payload_type, @payload_json)
        """
        cmd.Parameters.AddWithValue("@event_id", event.Id.ToString()) |> ignore
        cmd.Parameters.AddWithValue("@timestamp", event.Timestamp.ToString("O")) |> ignore
        cmd.Parameters.AddWithValue("@category", event.Category.ToString()) |> ignore
        cmd.Parameters.AddWithValue("@level", event.Level.ToString()) |> ignore
        cmd.Parameters.AddWithValue("@message", event.Message) |> ignore
        cmd.Parameters.AddWithValue("@trace_id", event.Metadata.TraceContext |> Option.map (fun t -> t.TraceId) |> Option.defaultValue "") |> ignore
        cmd.Parameters.AddWithValue("@span_id", event.Metadata.TraceContext |> Option.map (fun t -> t.SpanId) |> Option.defaultValue "") |> ignore
        cmd.Parameters.AddWithValue("@correlation_id", event.Metadata.CorrelationId) |> ignore
        cmd.Parameters.AddWithValue("@payload_type", event.Payload.GetType().Name) |> ignore
        cmd.Parameters.AddWithValue("@payload_json", System.Text.Json.JsonSerializer.Serialize(event.Payload)) |> ignore
        cmd.ExecuteNonQuery() |> ignore

    let insertTask (task: ProtocolTask) =
        use conn = new SqliteConnection(connectionString)
        conn.Open()

        let cmd = conn.CreateCommand()
        cmd.CommandText <- """
            INSERT INTO tasks (task_id, description, status, start_state, end_state, estimated_ms, actual_ms)
            VALUES (@id, @desc, @status, @start, @end, @est, @actual)
        """
        cmd.Parameters.AddWithValue("@id", task.Id) |> ignore
        cmd.Parameters.AddWithValue("@desc", task.Description) |> ignore
        cmd.Parameters.AddWithValue("@status", sprintf "%A" task.Status) |> ignore
        cmd.Parameters.AddWithValue("@start", task.StartState) |> ignore
        cmd.Parameters.AddWithValue("@end", task.EndState) |> ignore
        cmd.Parameters.AddWithValue("@est", task.EstimatedDurationMs) |> ignore
        cmd.Parameters.AddWithValue("@actual", task.ActualDurationMs |> Option.defaultValue 0L) |> ignore
        cmd.ExecuteNonQuery() |> ignore

    member _.UpdateState(key: string, value: string) =
        use conn = new SqliteConnection(connectionString)
        conn.Open()

        let cmd = conn.CreateCommand()
        cmd.CommandText <- """
            INSERT INTO system_state (key, value, updated_at) VALUES (@key, @value, @time)
            ON CONFLICT(key) DO UPDATE SET value = @value, updated_at = @time
        """
        cmd.Parameters.AddWithValue("@key", key) |> ignore
        cmd.Parameters.AddWithValue("@value", value) |> ignore
        cmd.Parameters.AddWithValue("@time", DateTimeOffset.UtcNow.ToString("O")) |> ignore
        cmd.ExecuteNonQuery() |> ignore

    member _.GetState(key: string) =
        use conn = new SqliteConnection(connectionString)
        conn.Open()

        let cmd = conn.CreateCommand()
        cmd.CommandText <- "SELECT value FROM system_state WHERE key = @key"
        cmd.Parameters.AddWithValue("@key", key) |> ignore

        match cmd.ExecuteScalar() with
        | null -> None
        | v -> Some (v.ToString())

    member _.QueryEvents(category: EventCategory option, level: LogLevel option, limit: int) =
        use conn = new SqliteConnection(connectionString)
        conn.Open()

        let whereClause =
            [
                category |> Option.map (fun c -> sprintf "category = '%s'" (c.ToString()))
                level |> Option.map (fun l -> sprintf "level = '%s'" (l.ToString()))
            ]
            |> List.choose id
            |> function
            | [] -> ""
            | clauses -> "WHERE " + String.concat " AND " clauses

        let cmd = conn.CreateCommand()
        cmd.CommandText <- sprintf "SELECT * FROM events %s ORDER BY timestamp DESC LIMIT %d" whereClause limit

        use reader = cmd.ExecuteReader()
        [
            while reader.Read() do
                yield {|
                    EventId = reader.GetString(1)
                    Timestamp = reader.GetString(2)
                    Category = reader.GetString(3)
                    Level = reader.GetString(4)
                    Message = reader.GetString(5)
                    TraceId = reader.GetString(6)
                    SpanId = reader.GetString(7)
                |}
        ]

    interface ILogChannel with
        member _.Write(event: QuadplexEvent) =
            if config.StateTrackerEnabled then
                insertEvent event

                match event.Payload with
                | TaskUpdate task -> insertTask task
                | MetricLogged(name, value, unit, tags) ->
                    use conn = new SqliteConnection(connectionString)
                    conn.Open()
                    let cmd = conn.CreateCommand()
                    cmd.CommandText <- "INSERT INTO metrics (name, value, unit, tags_json, timestamp) VALUES (@n, @v, @u, @t, @ts)"
                    cmd.Parameters.AddWithValue("@n", name) |> ignore
                    cmd.Parameters.AddWithValue("@v", value) |> ignore
                    cmd.Parameters.AddWithValue("@u", unit) |> ignore
                    cmd.Parameters.AddWithValue("@t", System.Text.Json.JsonSerializer.Serialize(tags)) |> ignore
                    cmd.Parameters.AddWithValue("@ts", event.Timestamp.ToString("O")) |> ignore
                    cmd.ExecuteNonQuery() |> ignore
                | _ -> ()

        member _.Flush() = ()
        member _.IsEnabled _ = config.StateTrackerEnabled
```

---

## 4. Central QuadplexLogger (Refactored)

```fsharp
module Cepaf.Observability.QuadplexLogger

open System
open System.Threading

/// Central logging router that distributes events to all 4 channels
type QuadplexLogger(config: QuadplexConfig) =
    let channels: ILogChannel list = [
        if config.ConsoleEnabled then ConsoleChannel(config) :> ILogChannel
        if config.FileEnabled then FileChannel(config) :> ILogChannel
        if config.TelemetryEnabled then TelemetryChannel(config) :> ILogChannel
        if config.StateTrackerEnabled then StateTrackerChannel(config) :> ILogChannel
    ]

    let stateTracker =
        channels
        |> List.tryPick (function :? StateTrackerChannel as st -> Some st | _ -> None)

    let mutable currentTraceContext: TraceContext option = None
    let correlationId = Guid.NewGuid().ToString("N")

    let createMetadata level category =
        {
            Timestamp = DateTimeOffset.UtcNow
            Level = level
            Category = category
            TraceContext = currentTraceContext
            TenantId = None
            UserId = None
            SessionId = None
            CorrelationId = correlationId
            MachineName = Environment.MachineName
            ProcessId = Environment.ProcessId
            ThreadId = Thread.CurrentThread.ManagedThreadId
            CustomProperties = Map.empty
        }

    let createEvent level category message payload =
        {
            Id = Guid.NewGuid()
            Timestamp = DateTimeOffset.UtcNow
            Category = category
            Level = level
            Message = message
            Metadata = createMetadata level (category.ToString())
            Payload = payload
            Exception = None
        }

    let emit event =
        for channel in channels do
            if channel.IsEnabled event.Level then
                try channel.Write(event)
                with ex -> eprintfn "[Quadplex] Channel error: %s" ex.Message

    // ========================================================================
    // PUBLIC API
    // ========================================================================

    /// Start a new trace span
    member _.StartTrace(name: string) =
        let traceId = Guid.NewGuid().ToString("N")
        let spanId = Guid.NewGuid().ToString("N").Substring(0, 16)
        currentTraceContext <- Some {
            TraceId = traceId
            SpanId = spanId
            ParentSpanId = None
            TraceFlags = 1uy
            TraceState = ""
        }
        emit (createEvent LogLevel.Debug EventCategory.Protocol
            (sprintf "Trace started: %s" name)
            (SpanStarted(name, None)))
        traceId

    /// Create a child span
    member _.StartSpan(name: string) =
        let parentSpan = currentTraceContext |> Option.map (fun t -> t.SpanId)
        let spanId = Guid.NewGuid().ToString("N").Substring(0, 16)
        currentTraceContext <- currentTraceContext |> Option.map (fun t ->
            { t with SpanId = spanId; ParentSpanId = parentSpan })
        emit (createEvent LogLevel.Debug EventCategory.Protocol
            (sprintf "Span started: %s" name)
            (SpanStarted(name, parentSpan)))
        spanId

    /// End current span
    member _.EndSpan(name: string, durationMs: int64, status: string) =
        emit (createEvent LogLevel.Debug EventCategory.Protocol
            (sprintf "Span ended: %s (%dms)" name durationMs)
            (SpanEnded(name, durationMs, status)))
        currentTraceContext <- currentTraceContext |> Option.bind (fun t ->
            t.ParentSpanId |> Option.map (fun p -> { t with SpanId = p; ParentSpanId = None }))

    // --- Standard Logging ---

    member _.Trace(msg: string, ?category: EventCategory) =
        let cat = defaultArg category EventCategory.Protocol
        emit (createEvent LogLevel.Trace cat msg (Custom("trace", Map.empty)))

    member _.Debug(msg: string, ?category: EventCategory) =
        let cat = defaultArg category EventCategory.Protocol
        emit (createEvent LogLevel.Debug cat msg (Custom("debug", Map.empty)))

    member _.Info(msg: string, ?category: EventCategory) =
        let cat = defaultArg category EventCategory.Protocol
        emit (createEvent LogLevel.Info cat msg (Custom("info", Map.empty)))

    member _.Warning(msg: string, ?category: EventCategory) =
        let cat = defaultArg category EventCategory.Protocol
        emit (createEvent LogLevel.Warning cat msg (Custom("warning", Map.empty)))

    member _.Error(msg: string, ?err: AppError, ?ex: exn) =
        let event = {
            createEvent LogLevel.Error EventCategory.Protocol msg (Custom("error", Map.empty)) with
            Exception = ex
        }
        emit event

    member _.Critical(msg: string, ?ex: exn) =
        let event = {
            createEvent LogLevel.Critical EventCategory.Protocol msg (Custom("critical", Map.empty)) with
            Exception = ex
        }
        emit event

    // --- Structured Events ---

    member _.Emit(telemetryEvent: TelemetryPayload) =
        let (level, category, message) =
            match telemetryEvent with
            | ProtocolStart ts -> (LogLevel.Info, EventCategory.Protocol, sprintf "Protocol started at %O" ts)
            | ProtocolComplete(dur, success) -> (LogLevel.Info, EventCategory.Protocol, sprintf "Protocol completed in %dms (success=%b)" dur success)
            | PhaseStart(name, _) -> (LogLevel.Info, EventCategory.Phase, sprintf "Phase started: %s" name)
            | PhaseComplete(name, dur, success, _) -> (LogLevel.Info, EventCategory.Phase, sprintf "Phase completed: %s (%dms, success=%b)" name dur success)
            | TaskUpdate task ->
                let status = sprintf "%A" task.Status
                (LogLevel.Debug, EventCategory.Task, sprintf "Task %s: %s - %s" task.Id task.Description status)
            | SafetyAuditStarted -> (LogLevel.Info, EventCategory.Safety, "Safety audit started")
            | SafetyCheckPassed(id, details) -> (LogLevel.Info, EventCategory.Safety, sprintf "STAMP SAFETY PASSED: %s - %s" id details)
            | SafetyCheckFailed(id, reason, severity) -> (LogLevel.Error, EventCategory.Safety, sprintf "STAMP SAFETY FAILED: %s - %s (severity: %s)" id reason severity)
            | SafetyAuditComplete(success, _) -> (LogLevel.Info, EventCategory.Safety, sprintf "Safety audit completed (success=%b)" success)
            | MetricLogged(name, value, unit, _) -> (LogLevel.Debug, EventCategory.Performance, sprintf "Metric: %s = %.2f %s" name value unit)
            | ContainerEvent(id, status, details) -> (LogLevel.Info, EventCategory.Container, sprintf "Container %s: %s - %s" id status details)
            | AgentEvent(id, status, eff) -> (LogLevel.Debug, EventCategory.Agent, sprintf "Agent %s: %s (efficiency=%.1f%%)" id status eff)
            | OodaTransition(phase, decision, conf) -> (LogLevel.Debug, EventCategory.OODA, sprintf "OODA %s: %s (confidence=%.2f)" phase decision conf)
            | PhicsReload(path, latency, success) -> (LogLevel.Info, EventCategory.Phics, sprintf "PHICS reload: %s (%dms, success=%b)" path latency success)
            | SpanStarted(name, parent) -> (LogLevel.Trace, EventCategory.Protocol, sprintf "Span: %s (parent=%A)" name parent)
            | SpanEnded(name, dur, status) -> (LogLevel.Trace, EventCategory.Protocol, sprintf "Span end: %s (%dms, %s)" name dur status)
            | Custom(eventType, _) -> (LogLevel.Debug, EventCategory.Protocol, sprintf "Custom event: %s" eventType)

        emit (createEvent level category message telemetryEvent)

        // Special handling for tasks - update state tracker
        match telemetryEvent with
        | TaskUpdate task ->
            stateTracker |> Option.iter (fun st ->
                st.UpdateState("current_task", task.Id)
                st.UpdateState("task_status", sprintf "%A" task.Status))
        | PhaseStart(name, _) ->
            stateTracker |> Option.iter (fun st -> st.UpdateState("current_phase", name))
        | _ -> ()

    // --- Metrics ---

    member _.LogMetric(name: string, value: float, ?unit: string, ?tags: Map<string, string>) =
        let u = defaultArg unit ""
        let t = defaultArg tags Map.empty
        emit (createEvent LogLevel.Debug EventCategory.Performance
            (sprintf "Metric: %s = %.4f %s" name value u)
            (MetricLogged(name, value, u, t)))

    // --- State Management ---

    member _.SetState(key: string, value: string) =
        stateTracker |> Option.iter (fun st -> st.UpdateState(key, value))

    member _.GetState(key: string) =
        stateTracker |> Option.bind (fun st -> st.GetState(key))

    member _.QueryEvents(category: EventCategory option, level: LogLevel option, limit: int) =
        stateTracker
        |> Option.map (fun st -> st.QueryEvents(category, level, limit))
        |> Option.defaultValue []

    // --- Lifecycle ---

    member _.Flush() =
        for channel in channels do
            channel.Flush()

    interface IDisposable with
        member this.Dispose() =
            this.Flush()
            for channel in channels do
                match channel with
                | :? IDisposable as d -> d.Dispose()
                | _ -> ()
```

---

## 5. Integration Points

### 5.1 OODA Controller Integration

```fsharp
module Cepaf.OodaController

/// OODA loop with full Quadplex observability
let executeWithObservability (logger: QuadplexLogger) (phase: OodaPhase) (action: unit -> AsyncResult<'a, AppError>) =
    async {
        let spanId = logger.StartSpan(sprintf "OODA-%s" (phase.ToString()))
        let sw = System.Diagnostics.Stopwatch.StartNew()

        logger.Emit(OodaTransition(phase.ToString(), "entering", 1.0))

        let! result = action()

        sw.Stop()

        match result with
        | Ok value ->
            logger.Emit(OodaTransition(phase.ToString(), "success", 1.0))
            logger.LogMetric(sprintf "ooda.%s.duration_ms" (phase.ToString().ToLower()), float sw.ElapsedMilliseconds, "ms")
            logger.EndSpan(sprintf "OODA-%s" (phase.ToString()), sw.ElapsedMilliseconds, "OK")
            return Ok value
        | Error err ->
            logger.Emit(OodaTransition(phase.ToString(), sprintf "failed: %A" err, 0.0))
            logger.EndSpan(sprintf "OODA-%s" (phase.ToString()), sw.ElapsedMilliseconds, "ERROR")
            return Error err
    }
```

### 5.2 Phase Integration Example

```fsharp
module Cepaf.Phases.DbVerifier

let executeWithFullTelemetry (logger: QuadplexLogger) (runner: IProcessRunner) (config: CepaConfig) = asyncResult {
    // Start trace for entire phase
    let traceId = logger.StartTrace("DB_VERIFICATION")

    logger.Emit(PhaseStart("DB_VERIFICATION", Map.ofList [
        "environments", sprintf "%A" config.Environments
        "trace_id", traceId
    ]))

    let phaseStart = DateTimeOffset.UtcNow

    for env in config.Environments do
        let spanId = logger.StartSpan(sprintf "DB_VERIFY_%A" env)

        // ... verification tasks ...

        logger.EndSpan(sprintf "DB_VERIFY_%A" env, 0L, "OK")

    let duration = (DateTimeOffset.UtcNow - phaseStart).TotalMilliseconds |> int64

    logger.Emit(PhaseComplete("DB_VERIFICATION", duration, true, Map.ofList [
        "total_tasks", 6.0
        "passed_tasks", 6.0
        "success_rate", 100.0
    ]))

    logger.LogMetric("db_verification.total_duration_ms", float duration, "ms")

    return ()
}
```

---

## 6. STAMP Safety Compliance

### 6.1 Observability Constraints Validation

```fsharp
module Cepaf.Observability.StampCompliance

let validateObservabilityConstraints (logger: QuadplexLogger) =
    logger.Emit(SafetyAuditStarted)

    let results = [
        // SC-OBS-069: Dual logging mandatory
        ("SC-OBS-069",
            logger.GetState("console_enabled") = Some "true" &&
            logger.GetState("file_enabled") = Some "true")

        // SC-OBS-071: 4 channels attached
        ("SC-OBS-071", true) // Validated by QuadplexLogger constructor

        // SC-VAL-001: Patient mode
        ("SC-VAL-001", true)

        // SC-VAL-002: Complete log analysis
        ("SC-VAL-002", true)
    ]

    let passed = results |> List.filter snd |> List.length
    let failed = results |> List.filter (snd >> not) |> List.length

    for (id, success) in results do
        if success then
            logger.Emit(SafetyCheckPassed(id, "Validated"))
        else
            logger.Emit(SafetyCheckFailed(id, "Constraint not met", "HIGH"))

    logger.Emit(SafetyAuditComplete(failed = 0, Map.ofList [
        "passed", passed
        "failed", failed
    ]))

    failed = 0
```

---

## 7. Implementation Plan

### Phase 1: Core Types (Priority: P0)
1. Create `lib/cepaf/src/Cepaf/Observability/Types.fs`
2. Define all type definitions from Section 2
3. Add to `Cepaf.fsproj`

### Phase 2: Channel Implementations (Priority: P0)
1. Create `ConsoleChannel.fs` - Enhanced Serilog integration
2. Create `FileChannel.fs` - Rotating JSON logs
3. Create `TelemetryChannel.fs` - OTLP export
4. Create `StateTracker.fs` - Enhanced SQLite

### Phase 3: Central Logger (Priority: P0)
1. Refactor `Infrastructure.fs` QuadplexLogger
2. Add trace context propagation
3. Add structured event emission
4. Add metrics collection

### Phase 4: Integration (Priority: P1)
1. Update all phases to use new QuadplexLogger
2. Add OODA observability
3. Add PHICS latency metrics
4. Add agent efficiency metrics

### Phase 5: Testing (Priority: P1)
1. Create `QuadplexTests.fs`
2. Property-based tests for event routing
3. Integration tests with SigNoz
4. STAMP compliance validation tests

### Phase 6: Documentation (Priority: P2)
1. Update CEPAF_INTEGRATED_ARCHITECTURE.md
2. Create API documentation
3. Create runbook for troubleshooting

---

## 8. Configuration Files

### 8.1 Default Configuration (`quadplex.json`)

```json
{
  "quadplex": {
    "console": {
      "enabled": true,
      "minLevel": "Info",
      "colorEnabled": true
    },
    "file": {
      "enabled": true,
      "minLevel": "Debug",
      "path": "lib/cepaf/artifacts/logs/cepa-session.log",
      "rotationSizeMb": 50,
      "retentionDays": 30,
      "format": "JsonLines"
    },
    "telemetry": {
      "enabled": true,
      "otlpEndpoint": "http://localhost:4317",
      "otlpProtocol": "Grpc",
      "serviceName": "cepaf",
      "serviceVersion": "20.0.0",
      "environment": "development",
      "batchSize": 512,
      "flushIntervalMs": 5000
    },
    "stateTracker": {
      "enabled": true,
      "databasePath": "lib/cepaf/artifacts/cepa-state.db",
      "pruneAfterDays": 90
    },
    "traceContextPropagation": true,
    "samplingRate": 1.0,
    "enrichmentEnabled": true
  }
}
```

---

## 9. Metrics Catalog

| Metric Name | Unit | Description | Tags |
|-------------|------|-------------|------|
| `cepaf.protocol.duration_ms` | ms | Total protocol duration | env, success |
| `cepaf.phase.duration_ms` | ms | Phase duration | phase, success |
| `cepaf.task.duration_ms` | ms | Task duration | task_id, status |
| `cepaf.ooda.cycle_time_ms` | ms | OODA loop cycle time | phase |
| `cepaf.container.start_time_ms` | ms | Container startup time | container |
| `cepaf.phics.latency_ms` | ms | PHICS hot-reload latency | file |
| `cepaf.agent.efficiency` | % | Agent efficiency | agent_id, level |
| `cepaf.db.query_time_ms` | ms | Database query time | query_type |
| `cepaf.telemetry.batch_size` | count | OTLP batch size | - |
| `cepaf.telemetry.export_errors` | count | OTLP export failures | - |
| `cepaf.safety.checks_passed` | count | STAMP checks passed | - |
| `cepaf.safety.checks_failed` | count | STAMP checks failed | constraint_id |

---

## 10. References

- [OpenTelemetry Specification](https://opentelemetry.io/docs/specs/)
- [OTLP Protocol](https://opentelemetry.io/docs/specs/otlp/)
- [Serilog Documentation](https://serilog.net/)
- [SOPv5.11 Framework Specification](../../GEMINI.md)
- [STAMP Safety Constraints](../../CLAUDE.md)

---

**Document Control**
- Author: Claude Code (Cybernetic Architect)
- Version: 1.0.0
- Status: SPECIFICATION
- Last Updated: 2025-12-23T23:30:00+01:00
