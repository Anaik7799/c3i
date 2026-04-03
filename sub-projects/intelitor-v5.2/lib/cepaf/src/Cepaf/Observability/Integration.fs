namespace Cepaf.Observability

open System
open System.IO
open System.Diagnostics

/// Integration module bridging old Domain types to new Quadplex Observability system.
/// Provides backward-compatible interface for existing CEPAF modules.
/// STAMP Compliance: SC-OBS-069 (dual logging), SC-OBS-071 (4 OTEL modules)
module Integration =

    /// Map Domain.ProtocolTask to Observability.ProtocolTask
    let mapProtocolTask (task: Cepaf.ProtocolTask) : ProtocolTask =
        {
            Id = task.Id
            Description = task.Description
            EntryCriteria = task.EntryCriteria
            ExitCriteria = task.ExitCriteria
            StartState = task.StartState
            EndState = task.EndState
            Status =
                match task.Status with
                | Cepaf.TaskStatus.Pending -> TaskStatus.Pending
                | Cepaf.TaskStatus.InProgress p -> TaskStatus.InProgress p
                | Cepaf.TaskStatus.Completed -> TaskStatus.Completed
                | Cepaf.TaskStatus.Failed r -> TaskStatus.Failed r
            EstimatedDurationMs = task.EstimatedDurationMs
            ActualDurationMs = task.ActualDurationMs
        }

    /// Map Domain.TelemetryEvent to Observability.TelemetryPayload
    let mapTelemetryEvent (event: Cepaf.TelemetryEvent) : TelemetryPayload =
        match event with
        | Cepaf.TelemetryEvent.ProtocolStart ts ->
            TelemetryPayload.ProtocolStart ts
        | Cepaf.TelemetryEvent.ProtocolComplete (dur, success) ->
            TelemetryPayload.ProtocolComplete(dur, success)
        | Cepaf.TelemetryEvent.PhaseStart name ->
            TelemetryPayload.PhaseStart(name, Map.empty)
        | Cepaf.TelemetryEvent.PhaseComplete (name, dur, success) ->
            TelemetryPayload.PhaseComplete(name, dur, success, Map.empty)
        | Cepaf.TelemetryEvent.TaskUpdate task ->
            TelemetryPayload.TaskUpdate (mapProtocolTask task)
        | Cepaf.TelemetryEvent.SafetyAuditStarted ->
            TelemetryPayload.SafetyAuditStarted
        | Cepaf.TelemetryEvent.SafetyCheckPassed id ->
            TelemetryPayload.SafetyCheckPassed(id, "")
        | Cepaf.TelemetryEvent.SafetyAuditComplete success ->
            TelemetryPayload.SafetyAuditComplete(success, Map.empty)
        | Cepaf.TelemetryEvent.MetricLogged (name, value) ->
            TelemetryPayload.MetricLogged(name, value, "", Map.empty)
        | Cepaf.TelemetryEvent.OodaTransition (phase, decision) ->
            TelemetryPayload.OodaTransition(phase, decision, 1.0)
        | Cepaf.TelemetryEvent.AnomalyDetected (desc, severity) ->
            TelemetryPayload.Custom("anomaly", Map.ofList [("description", desc :> obj); ("severity", severity :> obj)])
        | Cepaf.TelemetryEvent.PodmanEventObserved (id, status, ts) ->
            TelemetryPayload.ContainerEvent(id, status, ts)
        // CORTEX MASTER PLAN EVENTS
        | Cepaf.TelemetryEvent.TrainingGymEpisode (episodeType, reward) ->
            TelemetryPayload.Custom("training_gym", Map.ofList [("episode_type", episodeType :> obj); ("reward", reward :> obj)])
        | Cepaf.TelemetryEvent.ShadowModeExecution (modelId, agreed) ->
            TelemetryPayload.Custom("shadow_mode", Map.ofList [("model_id", modelId :> obj); ("agreed", agreed :> obj)])
        | Cepaf.TelemetryEvent.GuardianValidation (action, approved) ->
            TelemetryPayload.Custom("guardian", Map.ofList [("action", action :> obj); ("approved", approved :> obj)])
        | Cepaf.TelemetryEvent.OpenRouterCall (model, tokenCount) ->
            TelemetryPayload.Custom("openrouter", Map.ofList [("model", model :> obj); ("token_count", tokenCount :> obj)])
        // GDE PIPELINE EVENTS
        | Cepaf.TelemetryEvent.GDEProposalGenerated (proposalType, confidence) ->
            TelemetryPayload.Custom("gde_proposal", Map.ofList [("proposal_type", proposalType :> obj); ("confidence", confidence :> obj)])
        | Cepaf.TelemetryEvent.GDEProposalValidated (proposalId, passed, reason) ->
            TelemetryPayload.Custom("gde_validated", Map.ofList [("proposal_id", proposalId :> obj); ("passed", passed :> obj); ("reason", reason :> obj)])
        | Cepaf.TelemetryEvent.GDECycleComplete (proposalCount, validatedCount, successRate) ->
            TelemetryPayload.Custom("gde_cycle", Map.ofList [("proposal_count", proposalCount :> obj); ("validated_count", validatedCount :> obj); ("success_rate", successRate :> obj)])
        | Cepaf.TelemetryEvent.FractalLogEvent (level, channel, message) ->
            TelemetryPayload.Custom("fractal_log", Map.ofList [("level", level :> obj); ("channel", channel :> obj); ("message", message :> obj)])
        | Cepaf.TelemetryEvent.ZenohEvolutionEvent (keyExpr, eventType, payload) ->
            TelemetryPayload.Custom("zenoh_evolution", Map.ofList [("key_expr", keyExpr :> obj); ("event_type", eventType :> obj); ("payload", payload :> obj)])

    /// Map AppError to string for logging
    let formatAppError (err: Cepaf.AppError) : string =
        match err with
        | Cepaf.AppError.ProcessError (cmd, code, stderr) ->
            sprintf "ProcessError: %s (exit %d): %s" cmd code stderr
        | Cepaf.AppError.InfrastructureError (op, msg) ->
            sprintf "InfrastructureError: %s - %s" op msg
        | Cepaf.AppError.ValidationFailed (check, reason) ->
            sprintf "ValidationFailed: %s - %s" check reason
        | Cepaf.AppError.SafetyViolation (id, msg) ->
            sprintf "SafetyViolation [%s]: %s" id msg
        | Cepaf.AppError.BootMandateViolation (actual, threshold) ->
            sprintf "BootMandateViolation: %dms > %dms threshold" actual threshold
        | Cepaf.AppError.AorViolation (rule, msg) ->
            sprintf "AorViolation [%s]: %s" rule msg
        | Cepaf.AppError.CircuitBreakerOpen cmd ->
            sprintf "CircuitBreakerOpen: %s" cmd
        | Cepaf.AppError.HealthCheckTimedOut (svc, probe) ->
            sprintf "HealthCheckTimedOut: %s probe %s" svc probe
        | Cepaf.AppError.ConfigurationError reason ->
            sprintf "ConfigurationError: %s" reason
        | Cepaf.AppError.DependencyCycleDetected nodes ->
            sprintf "DependencyCycleDetected: %s" (String.concat " -> " nodes)
        | Cepaf.AppError.FileIOError (path, msg) ->
            sprintf "FileIOError: %s - %s" path msg
        | Cepaf.AppError.FormalVerificationError (gate, err) ->
            sprintf "FormalVerificationError [%s]: %s" gate err
        | Cepaf.AppError.PodmanApiError (endpoint, code, body) ->
            sprintf "PodmanApiError: %s (HTTP %d): %s" endpoint code body
        | Cepaf.AppError.SignalInterrupt ->
            "SignalInterrupt: Process interrupted"
        | Cepaf.AppError.PhicsLatencyViolation (actual, target) ->
            sprintf "PhicsLatencyViolation: %dms > %dms target" actual target

/// Unified logger that wraps QuadplexLoggerInstance for backward compatibility.
/// Maintains old API while using new 4-channel observability internally.
type UnifiedLogger(config: QuadplexConfig) =
    let logger = new QuadplexLoggerInstance(config)
    let metrics = new MetricsCollectorInstance(config)
    let mutable currentPhase: string option = None

    // Wire metrics to logger
    do metrics.SetMetricCallback(fun name value unit tags ->
        logger.LogMetric(name, value, unit, tags))

    /// Start a new protocol trace
    member _.StartProtocol(name: string) =
        logger.StartTrace(name) |> ignore
        logger.Emit(TelemetryPayload.ProtocolStart DateTimeOffset.UtcNow)

    /// End the protocol trace
    member _.EndProtocol(durationMs: int64, success: bool) =
        logger.Emit(TelemetryPayload.ProtocolComplete(durationMs, success))
        logger.EndSpan("protocol", if success then "success" else "failed") |> ignore

    /// Start a phase span
    member this.StartPhase(name: string) =
        currentPhase <- Some name
        logger.StartSpan(name) |> ignore
        logger.Emit(TelemetryPayload.PhaseStart(name, Map.empty))

    /// End a phase span
    member this.EndPhase(name: string, durationMs: int64, success: bool) =
        logger.Emit(TelemetryPayload.PhaseComplete(name, durationMs, success, Map.empty))
        logger.EndSpan(name, if success then "success" else "failed") |> ignore
        currentPhase <- None

    // ========== Legacy API Compatibility ==========

    /// Log info message (legacy API)
    member _.Info(msg: string) =
        logger.Info(msg, EventCategory.Protocol)

    /// Log error message with optional AppError (legacy API)
    member _.Error(msg: string, ?err: Cepaf.AppError) =
        let fullMsg =
            match err with
            | Some e -> sprintf "%s - %s" msg (Integration.formatAppError e)
            | None -> msg
        logger.Error(fullMsg)

    /// Emit telemetry event (legacy API)
    member this.Emit(event: Cepaf.TelemetryEvent) =
        let payload = Integration.mapTelemetryEvent event
        logger.Emit(payload)

        // Handle task progress bars for compatibility
        match event with
        | Cepaf.TelemetryEvent.TaskUpdate t ->
            match t.Status with
            | Cepaf.TaskStatus.InProgress p ->
                let bar = String.replicate (p / 5) "█" + String.replicate (20 - p / 5) "░"
                printf "\r[%s] %3d%% %s: %s" bar p t.Id t.Description
            | Cepaf.TaskStatus.Completed ->
                printfn "\r[████████████████████] 100%% %s: %s -> %dms"
                    t.Id t.Description (defaultArg t.ActualDurationMs 0L)
            | Cepaf.TaskStatus.Failed reason ->
                printfn "\r[XXXXXXXXXXXXXXXXXXXX] FAILED %s: %s - %s" t.Id t.Description reason
            | _ -> ()
        | _ -> ()

    // ========== New Quadplex API ==========

    /// Log with category
    member _.LogWithCategory(msg: string, category: EventCategory, level: LogLevel) =
        match level with
        | LogLevel.Trace -> logger.Trace(msg, category)
        | LogLevel.Debug -> logger.Debug(msg, category)
        | LogLevel.Info -> logger.Info(msg, category)
        | LogLevel.Warning -> logger.Warning(msg, category)
        | LogLevel.Error -> logger.Error(msg)
        | LogLevel.Critical -> logger.Critical(msg)
        | _ -> logger.Info(msg, category)

    /// Record a metric
    member _.RecordMetric(name: string, value: float, ?unit: string, ?tags: Map<string, string>) =
        let u = defaultArg unit ""
        let t = defaultArg tags Map.empty
        logger.LogMetric(name, value, u, t)

    /// Increment a counter
    member _.IncrementCounter(name: string, ?value: int64, ?tags: Map<string, string>) =
        metrics.IncrementCounter(name, ?value = value, ?tags = tags)

    /// Set a gauge value
    member _.SetGauge(name: string, value: float, ?tags: Map<string, string>) =
        metrics.SetGauge(name, value, ?tags = tags)

    /// Record histogram value
    member _.RecordHistogram(name: string, value: float, ?tags: Map<string, string>) =
        metrics.RecordHistogram(name, value, ?tags = tags)

    /// Start a timer that auto-records on dispose
    member _.StartTimer(name: string, ?tags: Map<string, string>) =
        metrics.StartTimer(name, ?tags = tags)

    /// Time a function
    member _.Time(name: string, f: unit -> 'a, ?tags: Map<string, string>) =
        metrics.Time(name, f, ?tags = tags)

    /// Get histogram statistics
    member _.GetHistogramStats(name: string, ?tags: Map<string, string>) =
        metrics.GetHistogramStats(name, ?tags = tags)

    /// Flush all channels
    member _.Flush() =
        logger.Flush()

    /// Get channel count
    member _.ChannelCount = logger.ChannelCount

    /// Get underlying logger for advanced use
    member _.UnderlyingLogger = logger

    /// Get underlying metrics collector
    member _.UnderlyingMetrics = metrics

    interface IDisposable with
        member this.Dispose() =
            this.Flush()
            (logger :> IDisposable).Dispose()

/// Factory for creating infrastructure with Quadplex observability
module InfrastructureFactory =

    /// Create Quadplex config from system registry
    let createConfig (registry: Cepaf.SystemRegistry) : QuadplexConfig =
        let logDir = Path.GetDirectoryName(registry.LogPath)
        let logFile = Path.Combine(logDir, "cepa-session.log")

        {
            // Console
            ConsoleEnabled = true
            ConsoleMinLevel = LogLevel.Info
            ConsoleColorEnabled = true
            ConsoleProgressBars = true

            // File
            FileEnabled = true
            FileMinLevel = LogLevel.Debug
            FilePath = logFile
            FileRotationSizeMb = 50
            FileRetentionDays = 30
            FileFormat = JsonLines
            FileBufferSize = 4096

            // Telemetry
            TelemetryEnabled = false  // Enable when OTEL collector available
            OtlpEndpoint = "http://localhost:4318"
            OtlpProtocol = OtlpProtocol.HttpJson
            ServiceName = "cepaf"
            ServiceVersion = "20.0.0"
            ServiceNamespace = "indrajaal"
            Environment = "development"
            BatchSize = 100
            FlushIntervalMs = 5000
            ExportTimeoutMs = 10000
            RetryCount = 3

            // State Tracker
            StateTrackerEnabled = true
            DatabasePath = registry.DatabasePath
            PruneAfterDays = 7
            MaxEventsInMemory = 10000

            // Global
            TraceContextPropagation = true
            SamplingRate = 1.0
            EnrichmentEnabled = true
            IncludeExceptionDetails = true
        }

    /// Create unified infrastructure components
    let create (registry: Cepaf.SystemRegistry) : UnifiedLogger =
        let config = createConfig registry
        new UnifiedLogger(config)

/// Global unified logger access
module GlobalUnifiedLogger =
    let mutable private instance: UnifiedLogger option = None
    let private lockObj = obj()

    /// Initialize with registry
    let initialize (registry: Cepaf.SystemRegistry) =
        lock lockObj (fun () ->
            match instance with
            | Some existing -> (existing :> IDisposable).Dispose()
            | None -> ()
            instance <- Some (InfrastructureFactory.create registry)
        )

    /// Get the global instance
    let get () =
        match instance with
        | Some logger -> logger
        | None -> failwith "GlobalUnifiedLogger not initialized"

    /// Dispose global logger
    let dispose () =
        lock lockObj (fun () ->
            match instance with
            | Some logger ->
                (logger :> IDisposable).Dispose()
                instance <- None
            | None -> ()
        )
