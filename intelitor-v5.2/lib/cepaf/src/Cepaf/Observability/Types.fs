namespace Cepaf.Observability

open System

/// Log severity levels aligned with Serilog/OpenTelemetry standards
[<RequireQualifiedAccess>]
type LogLevel =
    | Trace = 0
    | Debug = 1
    | Info = 2
    | Warning = 3
    | Error = 4
    | Critical = 5

/// Trace context for distributed tracing correlation (W3C Trace Context compatible)
type TraceContext = {
    /// 32-character hex string (128-bit trace identifier)
    TraceId: string
    /// 16-character hex string (64-bit span identifier)
    SpanId: string
    /// Parent span ID for hierarchical tracing
    ParentSpanId: string option
    /// Trace flags (bit 0 = sampled)
    TraceFlags: byte
    /// Vendor-specific trace state
    TraceState: string
}

/// Domain-specific event categories for structured observability
[<RequireQualifiedAccess>]
type EventCategory =
    | Protocol       // Orchestrator lifecycle events
    | Phase          // Phase start/complete events
    | Task           // Task progress/completion
    | Safety         // STAMP constraint events
    | Container      // Podman/Docker container events
    | Performance    // Metrics and timing data
    | Security       // Security-related events
    | Agent          // Cybernetic agent events
    | OODA           // OODA loop transitions
    | Phics          // Hot-reload events
    | Database       // Database verification events
    | Network        // Network/connectivity events
    | Build          // Build phase events
    | Test           // Test execution events
    | Verification   // Formal verification events

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

/// Task status for protocol task tracking
type TaskStatus =
    | Pending
    | InProgress of percent: int
    | Completed
    | Failed of reason: string

/// Protocol task definition with lifecycle tracking
type ProtocolTask = {
    Id: string
    Description: string
    EntryCriteria: string
    ExitCriteria: string
    StartState: string
    EndState: string
    Status: TaskStatus
    EstimatedDurationMs: int64
    ActualDurationMs: int64 option
}

/// Event payload variants for structured telemetry
type TelemetryPayload =
    // Protocol lifecycle
    | ProtocolStart of timestamp: DateTimeOffset
    | ProtocolComplete of durationMs: int64 * success: bool

    // Phase lifecycle
    | PhaseStart of name: string * context: Map<string, string>
    | PhaseComplete of name: string * durationMs: int64 * success: bool * metrics: Map<string, float>

    // Task tracking
    | TaskUpdate of task: ProtocolTask

    // OODA loop
    | OodaTransition of phase: string * decision: string * confidence: float

    // Safety auditing
    | SafetyAuditStarted
    | SafetyCheckPassed of constraintId: string * details: string
    | SafetyCheckFailed of constraintId: string * reason: string * severity: string
    | SafetyAuditComplete of success: bool * summary: Map<string, int>

    // Metrics
    | MetricLogged of name: string * value: float * unit: string * tags: Map<string, string>

    // Distributed tracing
    | SpanStarted of spanName: string * parentId: string option
    | SpanEnded of spanName: string * durationMs: int64 * status: string

    // Container events
    | ContainerEvent of containerId: string * status: string * details: string

    // Agent events
    | AgentEvent of agentId: string * status: string * efficiency: float

    // PHICS hot-reload
    | PhicsReload of filePath: string * latencyMs: int64 * success: bool

    // Build events
    | BuildStarted of target: string * configuration: string
    | BuildCompleted of target: string * durationMs: int64 * success: bool * warnings: int

    // Test events
    | TestSuiteStarted of suiteName: string * testCount: int
    | TestCompleted of testName: string * passed: bool * durationMs: int64
    | TestSuiteCompleted of suiteName: string * passed: int * failed: int * skipped: int

    // Custom events
    | Custom of eventType: string * data: Map<string, obj>

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

/// File log format options
type FileFormat =
    | JsonLines
    | StructuredText
    | CompactJson

/// OTLP transport protocol options
type OtlpProtocol =
    | Grpc
    | HttpProtobuf
    | HttpJson

/// Quadplex configuration for all 4 channels
type QuadplexConfig = {
    // Channel 1: Terminal/Console
    ConsoleEnabled: bool
    ConsoleMinLevel: LogLevel
    ConsoleColorEnabled: bool
    ConsoleProgressBars: bool

    // Channel 2: File
    FileEnabled: bool
    FileMinLevel: LogLevel
    FilePath: string
    FileRotationSizeMb: int
    FileRetentionDays: int
    FileFormat: FileFormat
    FileBufferSize: int

    // Channel 3: Telemetry/OTLP
    TelemetryEnabled: bool
    OtlpEndpoint: string
    OtlpProtocol: OtlpProtocol
    ServiceName: string
    ServiceVersion: string
    ServiceNamespace: string
    Environment: string
    BatchSize: int
    FlushIntervalMs: int
    ExportTimeoutMs: int
    RetryCount: int

    // Channel 4: State Tracker
    StateTrackerEnabled: bool
    DatabasePath: string
    PruneAfterDays: int
    MaxEventsInMemory: int

    // Global settings
    TraceContextPropagation: bool
    SamplingRate: float
    EnrichmentEnabled: bool
    IncludeExceptionDetails: bool
}

/// Log channel interface for all 4 output channels
type ILogChannel =
    /// Write an event to this channel
    abstract Write: QuadplexEvent -> unit
    /// Flush any buffered data
    abstract Flush: unit -> unit
    /// Check if this channel accepts events at the given level
    abstract IsEnabled: LogLevel -> bool

/// Telemetry exporter interface for OTLP
type ITelemetryExporter =
    abstract ExportLogs: QuadplexEvent[] -> Async<Result<unit, string>>
    abstract ExportMetrics: (string * float * Map<string, string>)[] -> Async<Result<unit, string>>
    abstract ExportSpans: QuadplexEvent[] -> Async<Result<unit, string>>

/// State store interface for persistence
type IStateStore =
    abstract UpdateState: key: string * value: string -> unit
    abstract GetState: key: string -> string option
    abstract LogTask: ProtocolTask -> unit
    abstract QueryEvents: category: EventCategory option * level: LogLevel option * limit: int -> obj list
    abstract Prune: olderThanDays: int -> int

/// Metrics collector interface
type IMetricsCollector =
    abstract RecordCounter: name: string * value: int64 * tags: Map<string, string> -> unit
    abstract RecordGauge: name: string * value: float * tags: Map<string, string> -> unit
    abstract RecordHistogram: name: string * value: float * tags: Map<string, string> -> unit
    abstract StartTimer: name: string * tags: Map<string, string> -> IDisposable

/// STAMP safety constraint definition
type SafetyConstraint = {
    Id: string
    Category: string
    Description: string
    Mandatory: bool
    Validation: unit -> Result<unit, string>
}

/// Default Quadplex configuration
module QuadplexDefaults =

    /// Default configuration for development environment
    let developmentConfig = {
        // Console
        ConsoleEnabled = true
        ConsoleMinLevel = LogLevel.Info
        ConsoleColorEnabled = true
        ConsoleProgressBars = true

        // File
        FileEnabled = true
        FileMinLevel = LogLevel.Debug
        FilePath = "lib/cepaf/artifacts/logs/cepa-session.log"
        FileRotationSizeMb = 50
        FileRetentionDays = 30
        FileFormat = JsonLines
        FileBufferSize = 4096

        // Telemetry
        TelemetryEnabled = true
        OtlpEndpoint = "http://localhost:4317"
        OtlpProtocol = Grpc
        ServiceName = "cepaf"
        ServiceVersion = "20.0.0"
        ServiceNamespace = "indrajaal"
        Environment = "development"
        BatchSize = 512
        FlushIntervalMs = 5000
        ExportTimeoutMs = 30000
        RetryCount = 3

        // State Tracker
        StateTrackerEnabled = true
        DatabasePath = "lib/cepaf/artifacts/cepa-state.db"
        PruneAfterDays = 90
        MaxEventsInMemory = 10000

        // Global
        TraceContextPropagation = true
        SamplingRate = 1.0
        EnrichmentEnabled = true
        IncludeExceptionDetails = true
    }

    /// Production configuration with reduced verbosity
    let productionConfig = {
        developmentConfig with
            ConsoleMinLevel = LogLevel.Warning
            FileMinLevel = LogLevel.Info
            SamplingRate = 0.1
            IncludeExceptionDetails = false
    }

    /// Test configuration with full verbosity
    let testConfig = {
        developmentConfig with
            ConsoleEnabled = false  // Suppress during tests
            TelemetryEnabled = false  // No external deps in tests
            SamplingRate = 1.0
    }

/// Helper functions for trace context
module TraceContextHelpers =

    /// Generate a new trace ID (32 hex characters)
    let newTraceId () =
        Guid.NewGuid().ToString("N")

    /// Generate a new span ID (16 hex characters)
    let newSpanId () =
        Guid.NewGuid().ToString("N").Substring(0, 16)

    /// Create a new root trace context
    let newRootContext () =
        {
            TraceId = newTraceId()
            SpanId = newSpanId()
            ParentSpanId = None
            TraceFlags = 1uy  // Sampled
            TraceState = ""
        }

    /// Create a child span context
    let childContext (parent: TraceContext) =
        {
            TraceId = parent.TraceId
            SpanId = newSpanId()
            ParentSpanId = Some parent.SpanId
            TraceFlags = parent.TraceFlags
            TraceState = parent.TraceState
        }

    /// Format trace context for W3C traceparent header
    let toTraceparent (ctx: TraceContext) =
        sprintf "00-%s-%s-%02x" ctx.TraceId ctx.SpanId ctx.TraceFlags

    /// Parse W3C traceparent header
    let parseTraceparent (header: string) =
        try
            let parts = header.Split('-')
            if parts.Length >= 4 then
                Some {
                    TraceId = parts.[1]
                    SpanId = parts.[2]
                    ParentSpanId = None
                    TraceFlags = Convert.ToByte(parts.[3], 16)
                    TraceState = ""
                }
            else None
        with _ -> None

/// Helper functions for log metadata creation
module LogMetadataHelpers =
    open System.Threading

    /// Create default metadata
    let create (level: LogLevel) (category: string) (correlationId: string) (traceCtx: TraceContext option) =
        {
            Timestamp = DateTimeOffset.UtcNow
            Level = level
            Category = category
            TraceContext = traceCtx
            TenantId = None
            UserId = None
            SessionId = None
            CorrelationId = correlationId
            MachineName = Environment.MachineName
            ProcessId = Environment.ProcessId
            ThreadId = Thread.CurrentThread.ManagedThreadId
            CustomProperties = Map.empty
        }

    /// Add custom property to metadata
    let withProperty (key: string) (value: obj) (md: LogMetadata) =
        { md with CustomProperties = md.CustomProperties |> Map.add key value }

    /// Add tenant context
    let withTenant (tenantId: string) (md: LogMetadata) =
        { md with TenantId = Some tenantId }

    /// Add user context
    let withUser (userId: string) (md: LogMetadata) =
        { md with UserId = Some userId }

/// Helper functions for event creation
module QuadplexEventHelpers =

    /// Create a new event
    let create (category: EventCategory) (level: LogLevel) (message: string) (payload: TelemetryPayload) (metadata: LogMetadata) =
        {
            Id = Guid.NewGuid()
            Timestamp = DateTimeOffset.UtcNow
            Category = category
            Level = level
            Message = message
            Metadata = metadata
            Payload = payload
            Exception = None
        }

    /// Add exception to event
    let withException (ex: exn) (event: QuadplexEvent) =
        { event with Exception = Some ex }

    /// Extract message and level from payload
    let payloadToMessageAndLevel (payload: TelemetryPayload) =
        match payload with
        | ProtocolStart ts -> (sprintf "Protocol started at %O" ts, LogLevel.Info)
        | ProtocolComplete(dur, success) -> (sprintf "Protocol completed in %dms (success=%b)" dur success, LogLevel.Info)
        | PhaseStart(name, _) -> (sprintf "Phase started: %s" name, LogLevel.Info)
        | PhaseComplete(name, dur, success, _) -> (sprintf "Phase completed: %s (%dms, success=%b)" name dur success, LogLevel.Info)
        | TaskUpdate task -> (sprintf "Task %s: %s" task.Id task.Description, LogLevel.Debug)
        | SafetyAuditStarted -> ("Safety audit started", LogLevel.Info)
        | SafetyCheckPassed(id, _) -> (sprintf "STAMP SAFETY PASSED: %s" id, LogLevel.Info)
        | SafetyCheckFailed(id, reason, _) -> (sprintf "STAMP SAFETY FAILED: %s - %s" id reason, LogLevel.Error)
        | SafetyAuditComplete(success, _) -> (sprintf "Safety audit completed (success=%b)" success, LogLevel.Info)
        | MetricLogged(name, value, unit, _) -> (sprintf "Metric: %s = %.4f %s" name value unit, LogLevel.Debug)
        | ContainerEvent(id, status, _) -> (sprintf "Container %s: %s" id status, LogLevel.Info)
        | AgentEvent(id, status, eff) -> (sprintf "Agent %s: %s (efficiency=%.1f%%)" id status eff, LogLevel.Debug)
        | OodaTransition(phase, decision, _) -> (sprintf "OODA %s: %s" phase decision, LogLevel.Debug)
        | PhicsReload(path, latency, success) -> (sprintf "PHICS reload: %s (%dms, success=%b)" path latency success, LogLevel.Info)
        | SpanStarted(name, _) -> (sprintf "Span started: %s" name, LogLevel.Trace)
        | SpanEnded(name, dur, status) -> (sprintf "Span ended: %s (%dms, %s)" name dur status, LogLevel.Trace)
        | BuildStarted(target, config) -> (sprintf "Build started: %s (%s)" target config, LogLevel.Info)
        | BuildCompleted(target, dur, success, warnings) -> (sprintf "Build completed: %s (%dms, success=%b, warnings=%d)" target dur success warnings, LogLevel.Info)
        | TestSuiteStarted(name, count) -> (sprintf "Test suite started: %s (%d tests)" name count, LogLevel.Info)
        | TestCompleted(name, passed, dur) -> (sprintf "Test %s: %s (%dms)" name (if passed then "PASSED" else "FAILED") dur, LogLevel.Debug)
        | TestSuiteCompleted(name, passed, failed, skipped) -> (sprintf "Test suite completed: %s (%d passed, %d failed, %d skipped)" name passed failed skipped, LogLevel.Info)
        | Custom(eventType, _) -> (sprintf "Custom event: %s" eventType, LogLevel.Debug)
