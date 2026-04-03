namespace Cepaf.Observability

open System
open System.Collections.Concurrent
open System.Threading
open Cepaf.Core.Units  // SC-FSH-004: Units of Measure
open Cepaf.Core.Composition  // SC-FSH-010: Function composition

/// Central Quadplex Logger coordinating all 4 observability channels.
/// Provides unified logging, tracing, metrics, and state management.
/// STAMP Compliance: SC-OBS-069 (dual logging), SC-OBS-071 (4 OTEL modules)
module QuadplexLogger =

    /// Active span information for tracing
    type ActiveSpan = {
        Name: string
        StartTime: DateTimeOffset
        Context: TraceContext
    }

    /// Logger state holding all channels and context
    type LoggerState = {
        Config: QuadplexConfig
        ConsoleChannel: ILogChannel
        FileChannel: ILogChannel
        TelemetryChannel: ILogChannel
        StateTrackerChannel: ILogChannel
        StateStore: IStateStore
        mutable CurrentTrace: TraceContext option
        ActiveSpans: ConcurrentDictionary<string, ActiveSpan>
        CorrelationId: string
        LockObj: obj
    }

    /// Create a new logger with all 4 channels
    let create (config: QuadplexConfig) : LoggerState =
        let consoleChannel = new ConsoleLogChannel(config) :> ILogChannel
        let fileChannel = new FileLogChannel(config) :> ILogChannel
        let telemetryChannel = new TelemetryLogChannel(config) :> ILogChannel
        let stateTrackerChannel = new StateTrackerLogChannel(config) :> ILogChannel
        let stateStore = new SqliteStateStore(config) :> IStateStore

        {
            Config = config
            ConsoleChannel = consoleChannel
            FileChannel = fileChannel
            TelemetryChannel = telemetryChannel
            StateTrackerChannel = stateTrackerChannel
            StateStore = stateStore
            CurrentTrace = None
            ActiveSpans = ConcurrentDictionary<string, ActiveSpan>()
            CorrelationId = Guid.NewGuid().ToString("N")
            LockObj = obj()
        }

    /// Get all active channels as array
    let private getChannels (state: LoggerState) =
        [| state.ConsoleChannel; state.FileChannel; state.TelemetryChannel; state.StateTrackerChannel |]

    /// Get number of active channels
    let getChannelCount (state: LoggerState) =
        let channels = getChannels state
        channels |> Array.filter (fun ch -> ch.IsEnabled(LogLevel.Info)) |> Array.length

    /// Create metadata for an event
    let private createMetadata (state: LoggerState) (level: LogLevel) (category: string) =
        LogMetadataHelpers.create level category state.CorrelationId state.CurrentTrace

    /// Emit event to all enabled channels
    let private emit (state: LoggerState) (event: QuadplexEvent) =
        let channels = getChannels state
        for channel in channels do
            if channel.IsEnabled(event.Level) then
                try
                    channel.Write(event)
                with _ -> ()  // Graceful degradation

    /// Create and emit an event
    let private emitEvent (state: LoggerState) (category: EventCategory) (level: LogLevel) (message: string) (payload: TelemetryPayload) (ex: exn option) =
        let metadata = createMetadata state level (category.ToString())
        let event = {
            Id = Guid.NewGuid()
            Timestamp = DateTimeOffset.UtcNow
            Category = category
            Level = level
            Message = message
            Metadata = metadata
            Payload = payload
            Exception = ex
        }
        emit state event

    // ========== Trace Management ==========

    /// Start a new trace (root span)
    let startTrace (state: LoggerState) (name: string) =
        let ctx = TraceContextHelpers.newRootContext()
        state.CurrentTrace <- Some ctx

        let span = { Name = name; StartTime = DateTimeOffset.UtcNow; Context = ctx }
        state.ActiveSpans.TryAdd(name, span) |> ignore

        emitEvent state EventCategory.Protocol LogLevel.Info
            (sprintf "Trace started: %s" name)
            (TelemetryPayload.SpanStarted(name, None))
            None

        ctx.TraceId

    /// Start a child span
    let startSpan (state: LoggerState) (name: string) =
        let ctx =
            match state.CurrentTrace with
            | Some parent -> TraceContextHelpers.childContext parent
            | None -> TraceContextHelpers.newRootContext()

        state.CurrentTrace <- Some ctx

        let span = { Name = name; StartTime = DateTimeOffset.UtcNow; Context = ctx }
        state.ActiveSpans.TryAdd(name, span) |> ignore

        let parentId = ctx.ParentSpanId
        emitEvent state EventCategory.Phase LogLevel.Debug
            (sprintf "Span started: %s" name)
            (TelemetryPayload.SpanStarted(name, parentId))
            None

        ctx.SpanId

    /// End a span
    let endSpan (state: LoggerState) (name: string) (status: string) =
        match state.ActiveSpans.TryRemove(name) with
        | true, span ->
            let duration = int64 (DateTimeOffset.UtcNow - span.StartTime).TotalMilliseconds

            // Restore parent context if available
            match span.Context.ParentSpanId with
            | Some parentId ->
                state.CurrentTrace <- Some { span.Context with SpanId = parentId; ParentSpanId = None }
            | None ->
                state.CurrentTrace <- None

            emitEvent state EventCategory.Phase LogLevel.Debug
                (sprintf "Span ended: %s (%dms, %s)" name duration status)
                (TelemetryPayload.SpanEnded(name, duration, status))
                None

            duration
        | false, _ ->
            0L

    /// Get current trace ID
    let getCurrentTraceId (state: LoggerState) =
        state.CurrentTrace |> Option.map (fun ctx -> ctx.TraceId)

    // ========== Standard Logging Methods ==========

    /// Log at Trace level
    let trace (state: LoggerState) (message: string) (category: EventCategory) =
        emitEvent state category LogLevel.Trace message
            (TelemetryPayload.Custom("trace", Map.empty))
            None

    /// Log at Debug level
    let debug (state: LoggerState) (message: string) (category: EventCategory) =
        emitEvent state category LogLevel.Debug message
            (TelemetryPayload.Custom("debug", Map.empty))
            None

    /// Log at Info level
    let info (state: LoggerState) (message: string) (category: EventCategory) =
        emitEvent state category LogLevel.Info message
            (TelemetryPayload.Custom("info", Map.empty))
            None

    /// Log at Warning level
    let warning (state: LoggerState) (message: string) (category: EventCategory) =
        emitEvent state category LogLevel.Warning message
            (TelemetryPayload.Custom("warning", Map.empty))
            None

    /// Log at Error level
    let error (state: LoggerState) (message: string) (ex: exn option) =
        emitEvent state EventCategory.Protocol LogLevel.Error message
            (TelemetryPayload.Custom("error", Map.empty))
            ex

    /// Log at Critical level
    let critical (state: LoggerState) (message: string) (ex: exn option) =
        emitEvent state EventCategory.Safety LogLevel.Critical message
            (TelemetryPayload.Custom("critical", Map.empty))
            ex

    // ========== Structured Event Emission ==========

    /// Emit a structured telemetry payload
    let emitPayload (state: LoggerState) (payload: TelemetryPayload) =
        let (message, level) = QuadplexEventHelpers.payloadToMessageAndLevel payload

        let category =
            match payload with
            | TelemetryPayload.ProtocolStart _ | TelemetryPayload.ProtocolComplete _ -> EventCategory.Protocol
            | TelemetryPayload.PhaseStart _ | TelemetryPayload.PhaseComplete _ -> EventCategory.Phase
            | TelemetryPayload.TaskUpdate _ -> EventCategory.Task
            | TelemetryPayload.SafetyAuditStarted | TelemetryPayload.SafetyCheckPassed _
            | TelemetryPayload.SafetyCheckFailed _ | TelemetryPayload.SafetyAuditComplete _ -> EventCategory.Safety
            | TelemetryPayload.ContainerEvent _ -> EventCategory.Container
            | TelemetryPayload.MetricLogged _ -> EventCategory.Performance
            | TelemetryPayload.AgentEvent _ -> EventCategory.Agent
            | TelemetryPayload.OodaTransition _ -> EventCategory.OODA
            | TelemetryPayload.PhicsReload _ -> EventCategory.Phics
            | TelemetryPayload.SpanStarted _ | TelemetryPayload.SpanEnded _ -> EventCategory.Protocol
            | TelemetryPayload.BuildStarted _ | TelemetryPayload.BuildCompleted _ -> EventCategory.Build
            | TelemetryPayload.TestSuiteStarted _ | TelemetryPayload.TestCompleted _
            | TelemetryPayload.TestSuiteCompleted _ -> EventCategory.Test
            | TelemetryPayload.Custom _ -> EventCategory.Protocol

        emitEvent state category level message payload None

    // ========== Metrics ==========

    /// Log a metric
    let logMetric (state: LoggerState) (name: string) (value: float) (unit: string) (tags: Map<string, string>) =
        emitEvent state EventCategory.Performance LogLevel.Debug
            (sprintf "Metric: %s = %.4f %s" name value unit)
            (TelemetryPayload.MetricLogged(name, value, unit, tags))
            None

    // ========== State Management ==========

    /// Set state value
    let setState (state: LoggerState) (key: string) (value: string) =
        state.StateStore.UpdateState(key, value)

    /// Get state value
    let getState (state: LoggerState) (key: string) =
        state.StateStore.GetState(key)

    /// Log a task
    let logTask (state: LoggerState) (task: ProtocolTask) =
        state.StateStore.LogTask(task)
        emitEvent state EventCategory.Task LogLevel.Info
            (sprintf "Task: %s - %s" task.Id task.Description)
            (TelemetryPayload.TaskUpdate task)
            None

    /// Query events
    let queryEvents (state: LoggerState) (category: EventCategory option) (level: LogLevel option) (limit: int) =
        state.StateStore.QueryEvents(category, level, limit)

    // ========== Lifecycle ==========

    /// Flush all channels
    let flush (state: LoggerState) =
        let channels = getChannels state
        for channel in channels do
            try
                channel.Flush()
            with _ -> ()

    /// Dispose all resources
    let dispose (state: LoggerState) =
        flush state

        let disposables = [|
            state.ConsoleChannel :> obj
            state.FileChannel :> obj
            state.TelemetryChannel :> obj
            state.StateTrackerChannel :> obj
            state.StateStore :> obj
        |]

        for d in disposables do
            match d with
            | :? IDisposable as disp ->
                try disp.Dispose() with _ -> ()
            | _ -> ()

/// Quadplex Logger class wrapper for OOP usage
type QuadplexLoggerInstance(config: QuadplexConfig) =
    let state = QuadplexLogger.create config

    // Trace Management
    member _.StartTrace(name) = QuadplexLogger.startTrace state name
    member _.StartSpan(name) = QuadplexLogger.startSpan state name
    member _.EndSpan(name, status) = QuadplexLogger.endSpan state name status
    member _.GetCurrentTraceId() = QuadplexLogger.getCurrentTraceId state

    // Standard Logging
    member _.Trace(msg, ?category) = QuadplexLogger.trace state msg (defaultArg category EventCategory.Protocol)
    member _.Debug(msg, ?category) = QuadplexLogger.debug state msg (defaultArg category EventCategory.Protocol)
    member _.Info(msg, ?category) = QuadplexLogger.info state msg (defaultArg category EventCategory.Protocol)
    member _.Warning(msg, ?category) = QuadplexLogger.warning state msg (defaultArg category EventCategory.Protocol)
    member _.Error(msg, ?ex) = QuadplexLogger.error state msg ex
    member _.Critical(msg, ?ex) = QuadplexLogger.critical state msg ex

    // Structured Events
    member _.Emit(payload) = QuadplexLogger.emitPayload state payload

    // Metrics
    member _.LogMetric(name, value, ?unit, ?tags) =
        QuadplexLogger.logMetric state name value (defaultArg unit "") (defaultArg tags Map.empty)

    // State Management
    member _.SetState(key, value) = QuadplexLogger.setState state key value
    member _.GetState(key) = QuadplexLogger.getState state key
    member _.LogTask(task) = QuadplexLogger.logTask state task
    member _.QueryEvents(category, level, limit) = QuadplexLogger.queryEvents state category level limit

    // Lifecycle
    member _.Flush() = QuadplexLogger.flush state
    member _.ChannelCount = QuadplexLogger.getChannelCount state

    interface IDisposable with
        member _.Dispose() = QuadplexLogger.dispose state

/// Global logger instance for convenience
module GlobalLogger =
    let mutable private instance: QuadplexLoggerInstance option = None
    let private lockObj = obj()

    /// Initialize global logger with config
    let initialize (config: QuadplexConfig) =
        lock lockObj (fun () ->
            match instance with
            | Some existing -> (existing :> IDisposable).Dispose()
            | None -> ()
            instance <- Some (new QuadplexLoggerInstance(config))
        )

    /// Initialize with default development config
    let initializeDefault () =
        initialize QuadplexDefaults.developmentConfig

    /// Get the global logger instance
    let get () =
        match instance with
        | Some logger -> logger
        | None ->
            initializeDefault()
            instance.Value

    /// Dispose global logger
    let dispose () =
        lock lockObj (fun () ->
            match instance with
            | Some logger ->
                (logger :> IDisposable).Dispose()
                instance <- None
            | None -> ()
        )

    // Convenience methods
    let trace msg = get().Trace(msg)
    let debug msg = get().Debug(msg)
    let info msg = get().Info(msg)
    let warning msg = get().Warning(msg)
    let error msg ex = get().Error(msg, ?ex = ex)
    let critical msg ex = get().Critical(msg, ?ex = ex)
    let emit payload = get().Emit(payload)
    let logMetric name value = get().LogMetric(name, value)
    let flush () = get().Flush()
