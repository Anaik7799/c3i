namespace Cepaf.Observability

open System
open System.IO
open System.Text
open System.Text.Json
open System.Text.Json.Serialization
open System.Collections.Concurrent
open System.Threading

/// File channel implementation for Quadplex observability.
/// Provides JSON Lines format logging with rotation and retention.
/// STAMP Compliance: SC-OBS-069 (dual logging - file component)
module FileChannel =

    /// JSON serialization options
    let private jsonOptions =
        let options = JsonSerializerOptions()
        options.WriteIndented <- false
        options.DefaultIgnoreCondition <- JsonIgnoreCondition.WhenWritingNull
        options.Converters.Add(JsonStringEnumConverter())
        options

    /// Serialize log level to string
    let private serializeLogLevel (level: LogLevel) =
        match level with
        | LogLevel.Trace -> "TRACE"
        | LogLevel.Debug -> "DEBUG"
        | LogLevel.Info -> "INFO"
        | LogLevel.Warning -> "WARN"
        | LogLevel.Error -> "ERROR"
        | LogLevel.Critical -> "CRITICAL"
        | _ -> "UNKNOWN"

    /// Serialize event category to string
    let private serializeCategory (category: EventCategory) =
        match category with
        | EventCategory.Protocol -> "protocol"
        | EventCategory.Phase -> "phase"
        | EventCategory.Task -> "task"
        | EventCategory.Safety -> "safety"
        | EventCategory.Container -> "container"
        | EventCategory.Performance -> "performance"
        | EventCategory.Security -> "security"
        | EventCategory.Agent -> "agent"
        | EventCategory.OODA -> "ooda"
        | EventCategory.Phics -> "phics"
        | EventCategory.Database -> "database"
        | EventCategory.Network -> "network"
        | EventCategory.Build -> "build"
        | EventCategory.Test -> "test"
        | EventCategory.Verification -> "verification"

    /// Serialize task status
    let private serializeTaskStatus (status: TaskStatus) =
        match status with
        | TaskStatus.Pending -> "pending"
        | TaskStatus.InProgress percent -> sprintf "in_progress:%d" percent
        | TaskStatus.Completed -> "completed"
        | TaskStatus.Failed reason -> sprintf "failed:%s" reason

    /// Serialize payload to JSON object
    let private serializePayload (payload: TelemetryPayload) : obj =
        match payload with
        | TelemetryPayload.ProtocolStart ts ->
            {| ``type`` = "protocol_start"; timestamp = ts.ToString("o") |} :> obj
        | TelemetryPayload.ProtocolComplete (dur, success) ->
            {| ``type`` = "protocol_complete"; duration_ms = dur; success = success |} :> obj
        | TelemetryPayload.PhaseStart (name, ctx) ->
            {| ``type`` = "phase_start"; name = name; context = ctx |} :> obj
        | TelemetryPayload.PhaseComplete (name, dur, success, metrics) ->
            {| ``type`` = "phase_complete"; name = name; duration_ms = dur; success = success; metrics = metrics |} :> obj
        | TelemetryPayload.TaskUpdate task ->
            {| ``type`` = "task_update"; task_id = task.Id; description = task.Description; status = serializeTaskStatus task.Status |} :> obj
        | TelemetryPayload.OodaTransition (phase, decision, confidence) ->
            {| ``type`` = "ooda_transition"; phase = phase; decision = decision; confidence = confidence |} :> obj
        | TelemetryPayload.SafetyAuditStarted ->
            {| ``type`` = "safety_audit_started" |} :> obj
        | TelemetryPayload.SafetyCheckPassed (id, details) ->
            {| ``type`` = "safety_check_passed"; constraint_id = id; details = details |} :> obj
        | TelemetryPayload.SafetyCheckFailed (id, reason, severity) ->
            {| ``type`` = "safety_check_failed"; constraint_id = id; reason = reason; severity = severity |} :> obj
        | TelemetryPayload.SafetyAuditComplete (success, summary) ->
            {| ``type`` = "safety_audit_complete"; success = success; summary = summary |} :> obj
        | TelemetryPayload.MetricLogged (name, value, unit, tags) ->
            {| ``type`` = "metric"; name = name; value = value; unit = unit; tags = tags |} :> obj
        | TelemetryPayload.SpanStarted (name, parentId) ->
            {| ``type`` = "span_started"; name = name; parent_id = parentId |} :> obj
        | TelemetryPayload.SpanEnded (name, dur, status) ->
            {| ``type`` = "span_ended"; name = name; duration_ms = dur; status = status |} :> obj
        | TelemetryPayload.ContainerEvent (id, status, details) ->
            {| ``type`` = "container_event"; container_id = id; status = status; details = details |} :> obj
        | TelemetryPayload.AgentEvent (id, status, efficiency) ->
            {| ``type`` = "agent_event"; agent_id = id; status = status; efficiency = efficiency |} :> obj
        | TelemetryPayload.PhicsReload (path, latency, success) ->
            {| ``type`` = "phics_reload"; file_path = path; latency_ms = latency; success = success |} :> obj
        | TelemetryPayload.BuildStarted (target, config) ->
            {| ``type`` = "build_started"; target = target; configuration = config |} :> obj
        | TelemetryPayload.BuildCompleted (target, dur, success, warnings) ->
            {| ``type`` = "build_completed"; target = target; duration_ms = dur; success = success; warnings = warnings |} :> obj
        | TelemetryPayload.TestSuiteStarted (name, count) ->
            {| ``type`` = "test_suite_started"; suite_name = name; test_count = count |} :> obj
        | TelemetryPayload.TestCompleted (name, passed, dur) ->
            {| ``type`` = "test_completed"; test_name = name; passed = passed; duration_ms = dur |} :> obj
        | TelemetryPayload.TestSuiteCompleted (name, passed, failed, skipped) ->
            {| ``type`` = "test_suite_completed"; suite_name = name; passed = passed; failed = failed; skipped = skipped |} :> obj
        | TelemetryPayload.Custom (eventType, data) ->
            {| ``type`` = "custom"; event_type = eventType; data = data |} :> obj

    /// Convert event to JSON Lines format
    let private eventToJsonLine (event: QuadplexEvent) =
        let traceContext =
            match event.Metadata.TraceContext with
            | Some ctx -> {| trace_id = ctx.TraceId; span_id = ctx.SpanId; parent_span_id = ctx.ParentSpanId |}
            | None -> {| trace_id = ""; span_id = ""; parent_span_id = None |}

        let record = {|
            id = event.Id.ToString()
            timestamp = event.Timestamp.ToString("o")
            level = serializeLogLevel event.Level
            category = serializeCategory event.Category
            message = event.Message
            trace = traceContext
            correlation_id = event.Metadata.CorrelationId
            machine = event.Metadata.MachineName
            process_id = event.Metadata.ProcessId
            thread_id = event.Metadata.ThreadId
            payload = serializePayload event.Payload
            exception_message = event.Exception |> Option.map (fun ex -> ex.Message)
            exception_type = event.Exception |> Option.map (fun ex -> ex.GetType().Name)
        |}

        JsonSerializer.Serialize(record, jsonOptions)

    /// File channel state
    type FileChannelState = {
        mutable FilePath: string
        mutable Writer: StreamWriter option
        mutable CurrentSize: int64
        MinLevel: LogLevel
        RotationSizeBytes: int64
        RetentionDays: int
        Format: FileFormat
        BufferSize: int
        Buffer: ConcurrentQueue<string>
        LockObj: obj
        mutable LastFlush: DateTimeOffset
        FlushIntervalMs: int
    }

    /// Get the directory for log files
    let private getLogDirectory (filePath: string) =
        Path.GetDirectoryName(filePath)

    /// Ensure directory exists
    let private ensureDirectory (filePath: string) =
        let dir = getLogDirectory filePath
        if not (String.IsNullOrEmpty(dir)) && not (Directory.Exists(dir)) then
            Directory.CreateDirectory(dir) |> ignore

    /// Generate rotated file name
    let private getRotatedFileName (basePath: string) =
        let dir = Path.GetDirectoryName(basePath)
        let name = Path.GetFileNameWithoutExtension(basePath)
        let ext = Path.GetExtension(basePath)
        let timestamp = DateTimeOffset.UtcNow.ToString("yyyyMMdd-HHmmss")
        Path.Combine(dir, sprintf "%s-%s%s" name timestamp ext)

    /// Open or create log file
    let private openLogFile (state: FileChannelState) =
        ensureDirectory state.FilePath
        let stream = new FileStream(state.FilePath, FileMode.Append, FileAccess.Write, FileShare.Read)
        state.CurrentSize <- stream.Length
        let writer = new StreamWriter(stream, Encoding.UTF8, state.BufferSize)
        writer.AutoFlush <- false
        state.Writer <- Some writer

    /// Close current log file
    let private closeLogFile (state: FileChannelState) =
        match state.Writer with
        | Some writer ->
            writer.Flush()
            writer.Close()
            writer.Dispose()
            state.Writer <- None
        | None -> ()

    /// Rotate log file if needed
    let private rotateIfNeeded (state: FileChannelState) =
        if state.CurrentSize >= state.RotationSizeBytes then
            closeLogFile state
            let rotatedPath = getRotatedFileName state.FilePath
            if File.Exists(state.FilePath) then
                File.Move(state.FilePath, rotatedPath)
            openLogFile state

    /// Prune old log files based on retention policy
    let pruneOldFiles (state: FileChannelState) =
        try
            let dir = getLogDirectory state.FilePath
            let name = Path.GetFileNameWithoutExtension(state.FilePath)
            let ext = Path.GetExtension(state.FilePath)
            let pattern = sprintf "%s-*%s" name ext
            let cutoff = DateTimeOffset.UtcNow.AddDays(float -state.RetentionDays)

            if Directory.Exists(dir) then
                Directory.GetFiles(dir, pattern)
                |> Array.iter (fun file ->
                    let fileInfo = FileInfo(file)
                    if fileInfo.LastWriteTimeUtc < cutoff.UtcDateTime then
                        try File.Delete(file) with _ -> ()
                )
        with _ -> ()

    /// Create file channel
    let create (config: QuadplexConfig) : FileChannelState =
        let rotationBytes = int64 config.FileRotationSizeMb * 1024L * 1024L

        let state = {
            FilePath = config.FilePath
            Writer = None
            CurrentSize = 0L
            MinLevel = config.FileMinLevel
            RotationSizeBytes = rotationBytes
            RetentionDays = config.FileRetentionDays
            Format = config.FileFormat
            BufferSize = config.FileBufferSize
            Buffer = ConcurrentQueue<string>()
            LockObj = obj()
            LastFlush = DateTimeOffset.UtcNow
            FlushIntervalMs = 1000
        }

        openLogFile state
        state

    /// Check if level is enabled
    let isEnabled (state: FileChannelState) (level: LogLevel) =
        int level >= int state.MinLevel

    /// Write line to file
    let private writeLine (state: FileChannelState) (line: string) =
        match state.Writer with
        | Some writer ->
            writer.WriteLine(line)
            state.CurrentSize <- state.CurrentSize + int64 (Encoding.UTF8.GetByteCount(line)) + 1L
        | None ->
            openLogFile state
            match state.Writer with
            | Some writer ->
                writer.WriteLine(line)
                state.CurrentSize <- state.CurrentSize + int64 (Encoding.UTF8.GetByteCount(line)) + 1L
            | None -> ()

    /// Write event to file
    let write (state: FileChannelState) (event: QuadplexEvent) =
        if isEnabled state event.Level then
            lock state.LockObj (fun () ->
                rotateIfNeeded state
                let line = eventToJsonLine event
                writeLine state line

                // Auto-flush based on level or interval
                let shouldFlush =
                    int event.Level >= int LogLevel.Warning ||
                    (DateTimeOffset.UtcNow - state.LastFlush).TotalMilliseconds > float state.FlushIntervalMs

                if shouldFlush then
                    match state.Writer with
                    | Some writer -> writer.Flush()
                    | None -> ()
                    state.LastFlush <- DateTimeOffset.UtcNow
            )

    /// Flush file buffer
    let flush (state: FileChannelState) =
        lock state.LockObj (fun () ->
            match state.Writer with
            | Some writer ->
                writer.Flush()
                state.LastFlush <- DateTimeOffset.UtcNow
            | None -> ()
        )

    /// Dispose resources
    let dispose (state: FileChannelState) =
        lock state.LockObj (fun () ->
            closeLogFile state
        )

/// File channel as ILogChannel implementation
type FileLogChannel(config: QuadplexConfig) =
    let state = FileChannel.create config

    interface ILogChannel with
        member _.Write(event) = FileChannel.write state event
        member _.Flush() = FileChannel.flush state
        member _.IsEnabled(level) = FileChannel.isEnabled state level

    interface IDisposable with
        member _.Dispose() = FileChannel.dispose state

    /// Prune old files (call periodically)
    member _.PruneOldFiles() = FileChannel.pruneOldFiles state
