namespace Cepaf

open System
open System.IO
open System.Collections.Generic
open System.Diagnostics
open CliWrap
open CliWrap.Buffered
open Rop
open Cepaf.Observability

/// CEPAF Infrastructure with Quadplex Observability Integration.
/// Provides unified logging, metrics, and process execution.
/// STAMP Compliance: SC-OBS-069 (dual logging), SC-OBS-071 (4 OTEL modules)
module Infrastructure =

    // ========================================================================
    // Legacy Types for Backward Compatibility
    // ========================================================================

    /// Legacy telemetry sink interface (deprecated - use UnifiedLogger directly)
    type ITelemetrySink =
        abstract member Emit : TelemetryEvent -> unit

    /// Legacy QuadplexLogger type alias for backward compatibility
    type QuadplexLogger = UnifiedLogger

    // ========================================================================
    // Process Runner with Circuit Breaker
    // ========================================================================

    type IProcessRunner =
        abstract member Run : cmd: string * args: string list * ?patientMode: bool -> AsyncResult<BufferedCommandResult, AppError>

    type CliProcessRunner(logger: UnifiedLogger) =
        let mutable failureCount = 0
        let threshold = 5

        interface IProcessRunner with
            member _.Run(cmd, args, ?patientMode) = async {
                if failureCount >= threshold then
                    logger.IncrementCounter("circuit_breaker.open", tags = Map.ofList ["command", cmd])
                    return Error (CircuitBreakerOpen cmd)
                else
                    let isPatient = defaultArg patientMode false

                    let mutable command =
                        Cli.Wrap(cmd)
                            .WithArguments(args)
                            .WithValidation(CommandResultValidation.None)

                    if isPatient then
                        let env = Dictionary<string, string>()
                        env.Add("NO_TIMEOUT", "true")
                        env.Add("PATIENT_MODE", "enabled")
                        env.Add("INFINITE_PATIENCE", "true")
                        env.Add("ELIXIR_ERL_OPTIONS", "+S 16")
                        command <- command.WithEnvironmentVariables(env)

                    logger.Info(sprintf "CMD EXEC: %s %s" cmd (String.concat " " args))

                    // Start timing
                    let startTime = DateTime.UtcNow
                    use timer = logger.StartTimer("process.duration", Map.ofList ["command", cmd])

                    try
                        let stdOutBuffer = new System.Text.StringBuilder()
                        let stdErrBuffer = new System.Text.StringBuilder()

                        let handleOutput (line: string) =
                            if not (String.IsNullOrWhiteSpace(line)) then
                                stdOutBuffer.AppendLine(line) |> ignore
                                let elapsed = DateTime.UtcNow - startTime
                                // High-fidelity streaming output to console with time tracking
                                printfn "\u001b[90m[%02d:%02d] >> %s\u001b[0m" elapsed.Minutes elapsed.Seconds line
                                logger.Info(sprintf "  >> %s" line)

                        let handleError (line: string) =
                            if not (String.IsNullOrWhiteSpace(line)) then
                                stdErrBuffer.AppendLine(line) |> ignore
                                let elapsed = DateTime.UtcNow - startTime
                                printfn "\u001b[31m[%02d:%02d] >> %s\u001b[0m" elapsed.Minutes elapsed.Seconds line
                                logger.Error(sprintf "  >> [ERR] %s" line)

                        let! result = 
                            command
                                .WithStandardOutputPipe(PipeTarget.ToDelegate(Action<string>(handleOutput)))
                                .WithStandardErrorPipe(PipeTarget.ToDelegate(Action<string>(handleError)))
                                .ExecuteAsync().Task |> Async.AwaitTask


                        let bufferedResult = BufferedCommandResult(result.ExitCode, result.StartTime, result.ExitTime, stdOutBuffer.ToString(), stdErrBuffer.ToString())

                        if result.ExitCode = 0 then
                            failureCount <- 0
                            logger.IncrementCounter("process.success", tags = Map.ofList ["command", cmd])
                            return Ok bufferedResult
                        else
                            failureCount <- failureCount + 1
                            logger.IncrementCounter("process.failure", tags = Map.ofList ["command", cmd; "exit_code", string result.ExitCode])
                            logger.Error(sprintf "PROCESS FAIL: %s (exit %d)" cmd result.ExitCode, ProcessError(cmd, result.ExitCode, bufferedResult.StandardError))
                            return Error (ProcessError(cmd, result.ExitCode, bufferedResult.StandardError))
                    with ex ->
                        failureCount <- failureCount + 1
                        logger.IncrementCounter("process.exception", tags = Map.ofList ["command", cmd])
                        return Error (InfrastructureError(cmd, ex.Message))
            }

    // ========================================================================
    // Task Execution with Observability
    // ========================================================================

    /// Create a protocol task (using Domain types)
    let createTask id desc entry exit start endState est : Cepaf.ProtocolTask = {
        Id = id
        Description = desc
        EntryCriteria = entry
        ExitCriteria = exit
        StartState = start
        EndState = endState
        Status = Cepaf.TaskStatus.Pending
        EstimatedDurationMs = est
        ActualDurationMs = None
    }

    /// Run a task with progress tracking and observability
    let runTask (logger: UnifiedLogger) (task: Cepaf.ProtocolTask) action = asyncResult {
        let updatedTask : Cepaf.ProtocolTask = { task with Status = Cepaf.TaskStatus.InProgress 0 }
        logger.Emit(Cepaf.TelemetryEvent.TaskUpdate updatedTask)

        // Start span for this task
        logger.UnderlyingLogger.StartSpan(task.Id) |> ignore

        let sw = Stopwatch.StartNew()

        let steps = 5
        let stepMs = int (task.EstimatedDurationMs / int64 steps)
        let actionTask = action ()

        let progressLoop = async {
            for i in [1..steps-1] do
                do! Async.Sleep stepMs
                let progressTask : Cepaf.ProtocolTask = { updatedTask with Status = Cepaf.TaskStatus.InProgress (i * 100 / steps) }
                logger.Emit(Cepaf.TelemetryEvent.TaskUpdate progressTask)
        }
        Async.Start progressLoop

        let! res = actionTask
        sw.Stop()

        // Record task duration metric
        logger.RecordHistogram("task.duration_ms", float sw.ElapsedMilliseconds,
            Map.ofList ["task_id", task.Id])

        let finalTask : Cepaf.ProtocolTask = { updatedTask with Status = Cepaf.TaskStatus.Completed; ActualDurationMs = Some sw.ElapsedMilliseconds }
        logger.Emit(Cepaf.TelemetryEvent.TaskUpdate finalTask)

        // End span
        logger.UnderlyingLogger.EndSpan(task.Id, "success") |> ignore

        return res
    }

    /// Run a task that may fail
    let runTaskWithFailure (logger: UnifiedLogger) (task: Cepaf.ProtocolTask) action = asyncResult {
        let updatedTask : Cepaf.ProtocolTask = { task with Status = Cepaf.TaskStatus.InProgress 0 }
        logger.Emit(Cepaf.TelemetryEvent.TaskUpdate updatedTask)

        logger.UnderlyingLogger.StartSpan(task.Id) |> ignore
        let sw = Stopwatch.StartNew()

        try
            let! res = action ()
            sw.Stop()

            logger.RecordHistogram("task.duration_ms", float sw.ElapsedMilliseconds,
                Map.ofList ["task_id", task.Id; "status", "success"])

            let finalTask : Cepaf.ProtocolTask = { updatedTask with Status = Cepaf.TaskStatus.Completed; ActualDurationMs = Some sw.ElapsedMilliseconds }
            logger.Emit(Cepaf.TelemetryEvent.TaskUpdate finalTask)
            logger.UnderlyingLogger.EndSpan(task.Id, "success") |> ignore

            return res
        with ex ->
            sw.Stop()

            logger.RecordHistogram("task.duration_ms", float sw.ElapsedMilliseconds,
                Map.ofList ["task_id", task.Id; "status", "failed"])

            let failedTask : Cepaf.ProtocolTask = { updatedTask with Status = Cepaf.TaskStatus.Failed ex.Message; ActualDurationMs = Some sw.ElapsedMilliseconds }
            logger.Emit(Cepaf.TelemetryEvent.TaskUpdate failedTask)
            logger.UnderlyingLogger.EndSpan(task.Id, "failed") |> ignore

            return! fromResult (Error (InfrastructureError(task.Id, ex.Message)))
    }

    // ========================================================================
    // Infrastructure Factory
    // ========================================================================

    /// Create infrastructure components with Quadplex observability
    let createInfrastructure (registry: SystemRegistry) : (UnifiedLogger * IProcessRunner) =
        // Create unified logger using new Quadplex system
        let logger = InfrastructureFactory.create registry

        // Initialize global logger for convenience
        GlobalUnifiedLogger.initialize registry

        // Create process runner with observability
        let runner = CliProcessRunner(logger)

        // Log infrastructure initialization
        logger.Info("============================================================================")
        logger.Info("CEPAF Infrastructure Initialized with Quadplex Observability")
        logger.Info(sprintf "  Channels: %d active" logger.ChannelCount)
        logger.Info(sprintf "  Log Directory: %s" (Path.GetDirectoryName(registry.LogPath)))
        logger.Info(sprintf "  State Database: %s" registry.DatabasePath)
        logger.Info("============================================================================")

        (logger, runner :> IProcessRunner)

    /// Dispose infrastructure
    let disposeInfrastructure () =
        GlobalUnifiedLogger.dispose ()
