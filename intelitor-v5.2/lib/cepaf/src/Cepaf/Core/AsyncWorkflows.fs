namespace Cepaf.Core

open System
open System.Threading
open System.Threading.Tasks
open System.Diagnostics
open Cepaf.Core.Pipelines

/// Advanced Async Workflows for CEPAF with safety guarantees.
/// Extends Pipelines.fs with specialized async patterns for system operations.
///
/// WHAT: Advanced async workflow patterns with cancellation, supervision, and telemetry
/// WHY: Provides reusable async patterns that comply with SC-FSH-042, SC-FSH-043
/// CONSTRAINTS:
///   - SC-FSH-042: All async operations MUST respect CancellationToken
///   - SC-FSH-043: Never use Async.RunSynchronously in production
///   - SC-PRF-050: Async operations should complete within 50ms
///   - SC-PRF-055: No blocking operations allowed
///
/// TDG Compliance:
///   - TDG-FSH-052: Cancellation tested
///   - TDG-FSH-054: Timeout behavior tested
///
/// AOR Compliance:
///   - AOR-FSH-050: All async compositions use AsyncResult
module AsyncWorkflows =

    // =========================================================================
    // SUPERVISED ASYNC OPERATIONS
    // =========================================================================

    /// Supervision strategy for async operations
    type SupervisionStrategy =
        | OneForOne         // Restart just the failed operation
        | AllForOne         // Restart all operations if one fails
        | RestForOne        // Restart failed and subsequent operations
        | Escalate          // Escalate to parent supervisor

    /// Supervision result
    type SupervisionResult<'T> = {
        Succeeded: bool
        Result: 'T option
        Attempts: int
        TotalTimeMs: int64
        LastError: string option
    }

    /// Execute with supervision and restart policy
    let superviseAsync
        (strategy: SupervisionStrategy)
        (maxRestarts: int)
        (operation: unit -> Async<Result<'T, string>>)
        : Async<SupervisionResult<'T>> =
        async {
            let stopwatch = Stopwatch.StartNew()
            let rec loop attempt lastError =
                async {
                    if attempt > maxRestarts then
                        stopwatch.Stop()
                        return {
                            Succeeded = false
                            Result = None
                            Attempts = attempt
                            TotalTimeMs = stopwatch.ElapsedMilliseconds
                            LastError = lastError
                        }
                    else
                        let! result = operation ()
                        match result with
                        | Ok value ->
                            stopwatch.Stop()
                            return {
                                Succeeded = true
                                Result = Some value
                                Attempts = attempt
                                TotalTimeMs = stopwatch.ElapsedMilliseconds
                                LastError = None
                            }
                        | Error err ->
                            match strategy with
                            | Escalate ->
                                stopwatch.Stop()
                                return {
                                    Succeeded = false
                                    Result = None
                                    Attempts = attempt
                                    TotalTimeMs = stopwatch.ElapsedMilliseconds
                                    LastError = Some err
                                }
                            | _ ->
                                do! Async.Sleep (min 1000 (100 * attempt))
                                return! loop (attempt + 1) (Some err)
                }
            return! loop 1 None
        }

    // =========================================================================
    // CANCELLATION-AWARE WORKFLOWS (SC-FSH-042)
    // =========================================================================

    /// Run operation with explicit cancellation token
    let withCancellation (ct: CancellationToken) (operation: Async<'T>) : Async<Result<'T, string>> =
        async {
            try
                if ct.IsCancellationRequested then
                    return Error "Operation cancelled"
                else
                    let! child = Async.StartChild(operation)
                    let! result = child
                    if ct.IsCancellationRequested then
                        return Error "Operation cancelled"
                    else
                        return Ok result
            with
            | :? OperationCanceledException ->
                return Error "Operation cancelled"
            | ex ->
                return Error ex.Message
        }

    /// Create a cancellable workflow with timeout
    let cancellableWithTimeout (timeoutMs: int) (operation: CancellationToken -> Async<'T>) : Async<Result<'T, string>> =
        async {
            use cts = new CancellationTokenSource(timeoutMs)
            try
                let! result = operation cts.Token
                return Ok result
            with
            | :? OperationCanceledException ->
                return Error (sprintf "Operation timed out after %dms" timeoutMs)
            | ex ->
                return Error ex.Message
        }

    /// Run multiple operations, cancel all on first failure
    let raceWithCancellation (operations: (CancellationToken -> Async<'T>) list) : Async<Result<'T, string list>> =
        async {
            use cts = new CancellationTokenSource()
            let tasks = operations |> List.map (fun op -> op cts.Token)
            try
                let! results = Async.Parallel tasks
                cts.Cancel()
                return Ok (results |> Array.head)
            with ex ->
                cts.Cancel()
                return Error [ex.Message]
        }

    // =========================================================================
    // WORKFLOW COMPOSITION
    // =========================================================================

    /// Pipeline of async operations with early exit on error
    let pipeline (operations: (unit -> Async<Result<unit, string>>) list) : Async<Result<unit, string>> =
        let rec loop remaining =
            async {
                match remaining with
                | [] -> return Ok ()
                | op :: rest ->
                    let! result = op ()
                    match result with
                    | Ok () -> return! loop rest
                    | Error e -> return Error e
            }
        loop operations

    /// Fan-out pattern: run operation on multiple inputs in parallel
    let fanOut (inputs: 'a list) (operation: 'a -> Async<Result<'b, string>>) : Async<Result<'b list, string>> =
        async {
            let! results = inputs |> List.map operation |> Async.Parallel
            let errors = results |> Array.choose (function Error e -> Some e | _ -> None)
            if Array.isEmpty errors then
                let successes = results |> Array.choose (function Ok v -> Some v | _ -> None)
                return Ok (Array.toList successes)
            else
                return Error (String.concat "; " errors)
        }

    /// Fan-in pattern: aggregate results from multiple sources
    let fanIn (sources: Async<Result<'a, string>> list) (aggregator: 'a list -> 'b) : Async<Result<'b, string>> =
        async {
            let! results = sources |> Async.Parallel
            let errors = results |> Array.choose (function Error e -> Some e | _ -> None)
            if Array.isEmpty errors then
                let values = results |> Array.choose (function Ok v -> Some v | _ -> None)
                return Ok (aggregator (Array.toList values))
            else
                return Error (String.concat "; " errors)
        }

    // =========================================================================
    // CIRCUIT BREAKER PATTERN
    // =========================================================================

    /// Circuit breaker state
    type CircuitState =
        | Closed         // Normal operation
        | Open           // Failing, reject requests
        | HalfOpen       // Testing if recovered

    /// Circuit breaker configuration
    type CircuitBreakerConfig = {
        FailureThreshold: int
        ResetTimeoutMs: int
        HalfOpenSuccessThreshold: int
    }

    /// Default circuit breaker config
    let defaultCircuitConfig = {
        FailureThreshold = 5
        ResetTimeoutMs = 30000
        HalfOpenSuccessThreshold = 2
    }

    /// Circuit breaker instance
    type CircuitBreaker = {
        mutable State: CircuitState
        mutable FailureCount: int
        mutable SuccessCount: int
        mutable LastFailureTime: DateTimeOffset option
        Config: CircuitBreakerConfig
        Lock: obj
    }

    /// Create a new circuit breaker
    let createCircuitBreaker (config: CircuitBreakerConfig) : CircuitBreaker =
        {
            State = Closed
            FailureCount = 0
            SuccessCount = 0
            LastFailureTime = None
            Config = config
            Lock = obj()
        }

    /// Execute with circuit breaker protection
    let executeWithCircuitBreaker (cb: CircuitBreaker) (operation: unit -> Async<Result<'T, string>>) : Async<Result<'T, string>> =
        async {
            // Check if circuit should transition from Open to HalfOpen
            lock cb.Lock (fun () ->
                match cb.State, cb.LastFailureTime with
                | Open, Some lastFailure ->
                    let elapsed = (DateTimeOffset.UtcNow - lastFailure).TotalMilliseconds
                    if elapsed > float cb.Config.ResetTimeoutMs then
                        cb.State <- HalfOpen
                        cb.SuccessCount <- 0
                | _ -> ()
            )

            match cb.State with
            | Open ->
                return Error "Circuit breaker is OPEN - rejecting request"
            | Closed | HalfOpen ->
                let! result = operation ()
                lock cb.Lock (fun () ->
                    match result with
                    | Ok _ ->
                        cb.SuccessCount <- cb.SuccessCount + 1
                        if cb.State = HalfOpen && cb.SuccessCount >= cb.Config.HalfOpenSuccessThreshold then
                            cb.State <- Closed
                            cb.FailureCount <- 0
                    | Error _ ->
                        cb.FailureCount <- cb.FailureCount + 1
                        cb.LastFailureTime <- Some DateTimeOffset.UtcNow
                        if cb.FailureCount >= cb.Config.FailureThreshold then
                            cb.State <- Open
                )
                return result
        }

    // =========================================================================
    // BULKHEAD PATTERN (Concurrency Limiting)
    // =========================================================================

    /// Bulkhead for limiting concurrent operations
    type Bulkhead = {
        Semaphore: SemaphoreSlim
        MaxConcurrency: int
        Name: string
    }

    /// Create a bulkhead with max concurrency
    let createBulkhead (name: string) (maxConcurrency: int) : Bulkhead =
        {
            Semaphore = new SemaphoreSlim(maxConcurrency, maxConcurrency)
            MaxConcurrency = maxConcurrency
            Name = name
        }

    /// Execute within bulkhead constraints
    let executeWithBulkhead (bulkhead: Bulkhead) (operation: unit -> Async<'T>) : Async<Result<'T, string>> =
        async {
            try
                do! bulkhead.Semaphore.WaitAsync() |> Async.AwaitTask
                try
                    let! result = operation ()
                    return Ok result
                finally
                    bulkhead.Semaphore.Release() |> ignore
            with ex ->
                return Error (sprintf "Bulkhead %s error: %s" bulkhead.Name ex.Message)
        }

    // =========================================================================
    // TELEMETRY-AWARE ASYNC OPERATIONS
    // =========================================================================

    /// Telemetry data from async operation
    type AsyncTelemetry = {
        OperationName: string
        StartTime: DateTimeOffset
        EndTime: DateTimeOffset
        DurationMs: int64
        Succeeded: bool
        ErrorMessage: string option
    }

    /// Execute with telemetry capture
    let withTelemetry (operationName: string) (operation: unit -> Async<Result<'T, string>>) : Async<'T option * AsyncTelemetry> =
        async {
            let startTime = DateTimeOffset.UtcNow
            let stopwatch = Stopwatch.StartNew()

            let! result = operation ()
            stopwatch.Stop()

            let telemetry = {
                OperationName = operationName
                StartTime = startTime
                EndTime = DateTimeOffset.UtcNow
                DurationMs = stopwatch.ElapsedMilliseconds
                Succeeded = Result.isOk result
                ErrorMessage = match result with Error e -> Some e | _ -> None
            }

            match result with
            | Ok value -> return (Some value, telemetry)
            | Error _ -> return (None, telemetry)
        }

    // =========================================================================
    // WORKFLOW BUILDERS
    // =========================================================================

    /// Builder for constructing complex async workflows
    type WorkflowBuilder() =
        member _.Bind(m, f) = async {
            let! result = m
            match result with
            | Ok v -> return! f v
            | Error e -> return Error e
        }
        member _.Return(x) = async { return Ok x }
        member _.ReturnFrom(m) = m
        member _.Zero() = async { return Ok () }
        member _.Delay(f) = f
        member _.Run(f) = f ()
        member _.Combine(a, b) = async {
            let! result = a
            match result with
            | Ok () -> return! b
            | Error e -> return Error e
        }
        member _.TryWith(m, h) = async {
            try return! m
            with ex -> return! h ex
        }
        member _.TryFinally(m, compensation) = async {
            try return! m
            finally compensation ()
        }

    /// Workflow builder instance
    let workflow = WorkflowBuilder()
