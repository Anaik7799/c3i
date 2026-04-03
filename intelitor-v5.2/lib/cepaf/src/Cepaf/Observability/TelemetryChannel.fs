namespace Cepaf.Observability

open System
open System.Net.Http
open System.Text
open System.Text.Json
open System.Text.Json.Serialization
open System.Collections.Concurrent
open System.Threading
open System.Threading.Tasks

/// Telemetry channel implementation for Quadplex observability.
/// Provides OTLP export with batching, retry, and graceful degradation.
/// STAMP Compliance: SC-OBS-071 (4 OTEL modules - telemetry component)
module TelemetryChannel =

    /// JSON options for OTLP serialization
    let private jsonOptions =
        let options = JsonSerializerOptions()
        options.WriteIndented <- false
        options.DefaultIgnoreCondition <- JsonIgnoreCondition.WhenWritingNull
        options.PropertyNamingPolicy <- JsonNamingPolicy.CamelCase
        options.Converters.Add(JsonStringEnumConverter())
        options

    /// OTLP severity number mapping
    let private getSeverityNumber (level: LogLevel) =
        match level with
        | LogLevel.Trace -> 1
        | LogLevel.Debug -> 5
        | LogLevel.Info -> 9
        | LogLevel.Warning -> 13
        | LogLevel.Error -> 17
        | LogLevel.Critical -> 21
        | _ -> 9

    /// OTLP severity text
    let private getSeverityText (level: LogLevel) =
        match level with
        | LogLevel.Trace -> "TRACE"
        | LogLevel.Debug -> "DEBUG"
        | LogLevel.Info -> "INFO"
        | LogLevel.Warning -> "WARN"
        | LogLevel.Error -> "ERROR"
        | LogLevel.Critical -> "FATAL"
        | _ -> "INFO"

    /// Convert timestamp to Unix nanoseconds
    let private toUnixNanos (ts: DateTimeOffset) =
        ts.ToUnixTimeMilliseconds() * 1_000_000L

    /// OTLP attribute value (always use stringValue for simplicity)
    type OtlpAttributeValue = { stringValue: string }

    /// OTLP key-value pair
    type OtlpKeyValue = { key: string; value: OtlpAttributeValue }

    /// Create OTLP KeyValue (all values serialized as strings for compatibility)
    let private createKeyValue (key: string) (value: obj) : OtlpKeyValue =
        let strValue =
            match value with
            | :? string as s -> s
            | :? int as i -> string i
            | :? int64 as l -> string l
            | :? float as f -> sprintf "%.6f" f
            | :? bool as b -> if b then "true" else "false"
            | null -> ""
            | _ -> value.ToString()
        { key = key; value = { stringValue = strValue } }

    /// Create OTLP resource attributes
    let private createResourceAttributes (config: QuadplexConfig) : OtlpKeyValue[] =
        [|
            createKeyValue "service.name" (config.ServiceName :> obj)
            createKeyValue "service.version" (config.ServiceVersion :> obj)
            createKeyValue "service.namespace" (config.ServiceNamespace :> obj)
            createKeyValue "deployment.environment" (config.Environment :> obj)
            createKeyValue "host.name" (Environment.MachineName :> obj)
        |]

    /// Convert QuadplexEvent to OTLP LogRecord
    let private toOtlpLogRecord (event: QuadplexEvent) =
        let traceId, spanId =
            match event.Metadata.TraceContext with
            | Some ctx -> ctx.TraceId, ctx.SpanId
            | None -> "", ""

        let attributes = [|
            createKeyValue "category" (event.Category.ToString() :> obj)
            createKeyValue "correlation_id" (event.Metadata.CorrelationId :> obj)
            createKeyValue "process.pid" (event.Metadata.ProcessId :> obj)
            createKeyValue "thread.id" (event.Metadata.ThreadId :> obj)
        |]

        {|
            timeUnixNano = string (toUnixNanos event.Timestamp)
            severityNumber = getSeverityNumber event.Level
            severityText = getSeverityText event.Level
            body = {| stringValue = event.Message |}
            attributes = attributes
            traceId = traceId
            spanId = spanId
        |}

    /// Create OTLP logs export request
    let private createLogsRequest (config: QuadplexConfig) (events: QuadplexEvent[]) =
        let logRecords = events |> Array.map toOtlpLogRecord
        let resourceAttributes = createResourceAttributes config

        {|
            resourceLogs = [|
                {|
                    resource = {| attributes = resourceAttributes |}
                    scopeLogs = [|
                        {|
                            scope = {| name = "cepaf.quadplex"; version = config.ServiceVersion |}
                            logRecords = logRecords
                        |}
                    |]
                |}
            |]
        |}

    /// Circuit breaker state
    type CircuitState =
        | Closed
        | Open of reopenAt: DateTimeOffset
        | HalfOpen

    /// Telemetry channel state
    type TelemetryChannelState = {
        Config: QuadplexConfig
        HttpClient: HttpClient
        Buffer: ConcurrentQueue<QuadplexEvent>
        mutable CircuitState: CircuitState
        mutable ConsecutiveFailures: int
        mutable LastExportTime: DateTimeOffset
        mutable IsExporting: int  // 0 = not exporting, 1 = exporting
        mutable TotalExported: int64
        mutable TotalFailed: int64
        LockObj: obj
        CancellationSource: CancellationTokenSource
    }

    /// Create telemetry channel
    let create (config: QuadplexConfig) : TelemetryChannelState =
        let client = new HttpClient()
        client.Timeout <- TimeSpan.FromMilliseconds(float config.ExportTimeoutMs)

        {
            Config = config
            HttpClient = client
            Buffer = ConcurrentQueue<QuadplexEvent>()
            CircuitState = Closed
            ConsecutiveFailures = 0
            LastExportTime = DateTimeOffset.UtcNow
            IsExporting = 0
            TotalExported = 0L
            TotalFailed = 0L
            LockObj = obj()
            CancellationSource = new CancellationTokenSource()
        }

    /// Check if circuit breaker allows requests
    let private isCircuitAllowing (state: TelemetryChannelState) =
        match state.CircuitState with
        | Closed -> true
        | HalfOpen -> true
        | Open reopenAt ->
            if DateTimeOffset.UtcNow >= reopenAt then
                state.CircuitState <- HalfOpen
                true
            else
                false

    /// Record success for circuit breaker
    let private recordSuccess (state: TelemetryChannelState) =
        state.ConsecutiveFailures <- 0
        state.CircuitState <- Closed

    /// Record failure for circuit breaker
    let private recordFailure (state: TelemetryChannelState) =
        state.ConsecutiveFailures <- state.ConsecutiveFailures + 1
        if state.ConsecutiveFailures >= state.Config.RetryCount then
            // Open circuit for 30 seconds
            state.CircuitState <- Open (DateTimeOffset.UtcNow.AddSeconds(30.0))

    /// Export batch of events to OTLP endpoint (internal, accessible within module)
    let exportBatch (state: TelemetryChannelState) (events: QuadplexEvent[]) = async {
        if events.Length = 0 then
            return Ok ()
        elif not (isCircuitAllowing state) then
            return Error "Circuit breaker open"
        else
            try
                let request = createLogsRequest state.Config events
                let json = JsonSerializer.Serialize(request, jsonOptions)
                let content = new StringContent(json, Encoding.UTF8, "application/json")

                let endpoint =
                    match state.Config.OtlpProtocol with
                    | OtlpProtocol.HttpJson | OtlpProtocol.HttpProtobuf ->
                        sprintf "%s/v1/logs" state.Config.OtlpEndpoint
                    | OtlpProtocol.Grpc ->
                        // For gRPC, use HTTP endpoint as fallback
                        sprintf "%s/v1/logs" (state.Config.OtlpEndpoint.Replace(":4317", ":4318"))

                let! response = state.HttpClient.PostAsync(endpoint, content) |> Async.AwaitTask

                if response.IsSuccessStatusCode then
                    recordSuccess state
                    Interlocked.Add(&state.TotalExported, int64 events.Length) |> ignore
                    return Ok ()
                else
                    recordFailure state
                    Interlocked.Add(&state.TotalFailed, int64 events.Length) |> ignore
                    return Error (sprintf "HTTP %d: %s" (int response.StatusCode) response.ReasonPhrase)
            with ex ->
                recordFailure state
                Interlocked.Add(&state.TotalFailed, int64 events.Length) |> ignore
                return Error ex.Message
    }

    /// Drain buffer and export
    let private drainAndExport (state: TelemetryChannelState) = async {
        if Interlocked.CompareExchange(&state.IsExporting, 1, 0) = 0 then
            try
                let events = ResizeArray<QuadplexEvent>()
                let mutable item = Unchecked.defaultof<QuadplexEvent>
                while events.Count < state.Config.BatchSize && state.Buffer.TryDequeue(&item) do
                    events.Add(item)

                if events.Count > 0 then
                    let! _ = exportBatch state (events.ToArray())
                    state.LastExportTime <- DateTimeOffset.UtcNow
            finally
                Interlocked.Exchange(&state.IsExporting, 0) |> ignore
    }

    /// Check if flush is needed
    let private shouldFlush (state: TelemetryChannelState) =
        state.Buffer.Count >= state.Config.BatchSize ||
        (DateTimeOffset.UtcNow - state.LastExportTime).TotalMilliseconds >= float state.Config.FlushIntervalMs

    /// Check if level is enabled (telemetry accepts all levels when enabled)
    let isEnabled (state: TelemetryChannelState) (_level: LogLevel) =
        state.Config.TelemetryEnabled

    /// Write event to telemetry channel
    let write (state: TelemetryChannelState) (event: QuadplexEvent) =
        if state.Config.TelemetryEnabled then
            // Apply sampling
            let shouldSample =
                state.Config.SamplingRate >= 1.0 ||
                Random.Shared.NextDouble() < state.Config.SamplingRate

            if shouldSample then
                state.Buffer.Enqueue(event)

                // Trigger export if batch size reached
                if shouldFlush state then
                    drainAndExport state |> Async.Start

    /// Flush all buffered events
    let flush (state: TelemetryChannelState) =
        drainAndExport state |> Async.RunSynchronously

    /// Get export statistics
    let getStats (state: TelemetryChannelState) =
        {|
            BufferCount = state.Buffer.Count
            TotalExported = state.TotalExported
            TotalFailed = state.TotalFailed
            CircuitState = state.CircuitState.ToString()
            ConsecutiveFailures = state.ConsecutiveFailures
        |}

    /// Dispose resources
    let dispose (state: TelemetryChannelState) =
        state.CancellationSource.Cancel()
        flush state
        state.HttpClient.Dispose()
        state.CancellationSource.Dispose()

/// Telemetry channel as ILogChannel implementation
type TelemetryLogChannel(config: QuadplexConfig) =
    let state = TelemetryChannel.create config

    interface ILogChannel with
        member _.Write(event) = TelemetryChannel.write state event
        member _.Flush() = TelemetryChannel.flush state
        member _.IsEnabled(level) = TelemetryChannel.isEnabled state level

    interface IDisposable with
        member _.Dispose() = TelemetryChannel.dispose state

    /// Get export statistics
    member _.GetStats() = TelemetryChannel.getStats state

/// Telemetry exporter implementation
type OtlpTelemetryExporter(config: QuadplexConfig) =
    let state = TelemetryChannel.create config

    interface ITelemetryExporter with
        member _.ExportLogs(events) = async {
            let! result = TelemetryChannel.exportBatch state events
            return result
        }

        member _.ExportMetrics(metrics) = async {
            // Convert metrics to log events for now
            // Full metrics export would require OTLP metrics protocol
            for (name, value, tags) in metrics do
                let event = {
                    Id = Guid.NewGuid()
                    Timestamp = DateTimeOffset.UtcNow
                    Category = EventCategory.Performance
                    Level = LogLevel.Debug
                    Message = sprintf "Metric: %s = %.4f" name value
                    Metadata = LogMetadataHelpers.create LogLevel.Debug "metrics" (Guid.NewGuid().ToString("N")) None
                    Payload = TelemetryPayload.MetricLogged(name, value, "", tags)
                    Exception = None
                }
                state.Buffer.Enqueue(event)

            TelemetryChannel.flush state
            return Ok ()
        }

        member _.ExportSpans(events) = async {
            // Filter for span events and export
            let spanEvents = events |> Array.filter (fun e ->
                match e.Payload with
                | TelemetryPayload.SpanStarted _ | TelemetryPayload.SpanEnded _ -> true
                | _ -> false)

            let! result = TelemetryChannel.exportBatch state spanEvents
            return result
        }

    interface IDisposable with
        member _.Dispose() = TelemetryChannel.dispose state
