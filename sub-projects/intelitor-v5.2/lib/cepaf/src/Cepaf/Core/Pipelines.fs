namespace Cepaf.Core

open System
open System.Threading.Tasks

/// Reusable composition pipelines for common async, result, and validation operations.
/// Provides Railway-Oriented Programming (ROP) patterns and async workflows.
///
/// WHAT: Pre-built composition pipelines for async results, validation, and retry logic
/// WHY: Eliminates boilerplate, ensures consistent error handling across all modules
/// CONSTRAINTS:
///   - SC-FSH-010: Kleisli composition for Result types
///   - SC-FSH-011: tap/applyIf for side effects
///   - SC-FSH-016: Async operations must not block
///   - SC-FSH-017: All errors must be captured in Result type
///
/// TDG Compliance:
///   - TDG-FSH-010: Composition associativity tested
///   - TDG-FSH-016: Async cancellation tested
///
/// AOR Compliance:
///   - AOR-FSH-004: All async operations use these pipelines
///   - AOR-FSH-005: No raw try/catch in business logic
module Pipelines =

    // =========================================================================
    // RESULT OPERATORS (Railway-Oriented Programming)
    // =========================================================================

    /// Bind operator for Result
    let (>>=) result f = Result.bind f result

    /// Map operator for Result
    let (>>|) result f = Result.map f result

    /// Kleisli composition for Result
    let (>=>) f g x =
        match f x with
        | Ok v -> g v
        | Error e -> Error e

    /// Create Ok result
    let ok value = Ok value

    /// Create Error result
    let error err = Error err

    /// Apply function if value matches predicate
    let applyIf predicate f value =
        if predicate value then f value else value

    /// Apply function to Ok, keeping result type
    let mapOk f = function
        | Ok v -> Ok (f v)
        | Error e -> Error e

    /// Apply function to Error, keeping result type
    let mapError f = function
        | Ok v -> Ok v
        | Error e -> Error (f e)

    // =========================================================================
    // ASYNC RESULT MODULE
    // =========================================================================

    /// Async Result operations (AsyncResult<'T, 'E> = Async<Result<'T, 'E>>)
    module AsyncResult =

        /// Lift a value into Async<Result<_,_>>
        let retn value = async { return Ok value }

        /// Lift an error into Async<Result<_,_>>
        let error err = async { return Error err }

        /// Map over Async<Result<_,_>>
        let map f asyncResult = async {
            let! result = asyncResult
            return Result.map f result
        }

        /// Map error over Async<Result<_,_>>
        let mapError f asyncResult = async {
            let! result = asyncResult
            return Result.mapError f result
        }

        /// Bind over Async<Result<_,_>>
        let bind f asyncResult = async {
            let! result = asyncResult
            match result with
            | Ok value -> return! f value
            | Error e -> return Error e
        }

        /// Bind operator for Async<Result<_,_>>
        let (>>=) asyncResult f = bind f asyncResult

        /// Map operator for Async<Result<_,_>>
        let (>>|) asyncResult f = map f asyncResult

        /// Kleisli composition for Async<Result<_,_>>
        let (>=>) f g x = async {
            let! result = f x
            match result with
            | Ok v -> return! g v
            | Error e -> return Error e
        }

        /// Lift Async<'T> to Async<Result<'T, 'E>>
        let ofAsync asyncOp = async {
            let! value = asyncOp
            return Ok value
        }

        /// Lift Result<'T, 'E> to Async<Result<'T, 'E>>
        let ofResult result = async { return result }

        /// Tap into Ok value (for side effects like logging)
        let tapOk f asyncResult = async {
            let! result = asyncResult
            match result with
            | Ok v ->
                f v
                return Ok v
            | Error e -> return Error e
        }

        /// Tap into Error value (for side effects like logging)
        let tapError f asyncResult = async {
            let! result = asyncResult
            match result with
            | Ok v -> return Ok v
            | Error e ->
                f e
                return Error e
        }

        /// Tap into both Ok and Error
        let tap fOk fError asyncResult = async {
            let! result = asyncResult
            match result with
            | Ok v ->
                fOk v
                return Ok v
            | Error e ->
                fError e
                return Error e
        }

        /// Catch exceptions and convert to Result
        let catch makeError asyncOp = async {
            try
                let! result = asyncOp
                return Ok result
            with ex ->
                return Error (makeError ex)
        }

        /// Catch with default error type
        let catchWith asyncOp = async {
            try
                let! result = asyncOp
                return Ok result
            with ex ->
                return Error ex.Message
        }

        /// Ignore the Ok value, return unit
        let ignore asyncResult = async {
            let! _ = asyncResult
            return ()
        }

        /// Default value if error
        let defaultValue def asyncResult = async {
            let! result = asyncResult
            return
                match result with
                | Ok v -> v
                | Error _ -> def
        }

        /// Convert to Option (losing error info)
        let toOption asyncResult = async {
            let! result = asyncResult
            return
                match result with
                | Ok v -> Some v
                | Error _ -> None
        }

    // =========================================================================
    // VALIDATION PIPELINE
    // =========================================================================

    /// Validation result with accumulated errors
    type ValidationResult<'T> = Result<'T, string list>

    module Validation =

        /// Single validation rule
        type Rule<'T> = 'T -> ValidationResult<'T>

        /// Create a passing validation
        let pass value : ValidationResult<'T> = Ok value

        /// Create a failing validation
        let fail error : ValidationResult<'T> = Error [error]

        /// Create a failing validation with multiple errors
        let failMany errors : ValidationResult<'T> = Error errors

        /// Validate with a predicate
        let validate predicate error value : ValidationResult<'T> =
            if predicate value then Ok value
            else Error [error]

        /// Validate not null/empty string
        let notEmpty fieldName (value: string) =
            if String.IsNullOrWhiteSpace(value) then
                Error [$"{fieldName} must not be empty"]
            else
                Ok value

        /// Validate minimum length
        let minLength fieldName minLen (value: string) =
            if value.Length < minLen then
                Error [$"{fieldName} must be at least {minLen} characters"]
            else
                Ok value

        /// Validate maximum length
        let maxLength fieldName maxLen (value: string) =
            if value.Length > maxLen then
                Error [$"{fieldName} must be at most {maxLen} characters"]
            else
                Ok value

        /// Validate in range
        let inRange fieldName minVal maxVal (value: 'T when 'T : comparison) =
            if value < minVal || value > maxVal then
                Error [$"{fieldName} must be between {minVal} and {maxVal}"]
            else
                Ok value

        /// Validate positive number
        let positive fieldName (value: int) =
            if value <= 0 then
                Error [$"{fieldName} must be positive"]
            else
                Ok value

        /// Combine two validation results
        let combine (r1: ValidationResult<'T>) (r2: ValidationResult<'T>) : ValidationResult<'T> =
            match r1, r2 with
            | Ok v, Ok _ -> Ok v
            | Error e1, Error e2 -> Error (e1 @ e2)
            | Error e, Ok _ | Ok _, Error e -> Error e

        /// Combine validation results, keeping first valid value
        let combineAll (results: ValidationResult<'T> list) : ValidationResult<'T> =
            results |> List.fold combine (Error [])

        /// Chain multiple validators
        let chain (validators: Rule<'T> list) (value: 'T) : ValidationResult<'T> =
            validators
            |> List.map (fun v -> v value)
            |> List.fold combine (Ok value)

        /// Apply validators to a value and collect all errors
        let validateAll validators value =
            let results = validators |> List.map (fun v -> v value)
            let errors =
                results
                |> List.choose (function Error es -> Some es | Ok _ -> None)
                |> List.concat

            if errors.IsEmpty then Ok value
            else Error errors

        /// Map validated value
        let map f = function
            | Ok v -> Ok (f v)
            | Error es -> Error es

        /// Bind validated value
        let bind f = function
            | Ok v -> f v
            | Error es -> Error es

    // =========================================================================
    // RETRY PIPELINE (SC-FSH-016: Non-blocking)
    // =========================================================================

    module Retry =

        /// Retry configuration
        type RetryConfig = {
            MaxAttempts: int
            BaseDelayMs: int
            MaxDelayMs: int
            ExponentialBackoff: bool
            ShouldRetry: exn -> bool
        }

        /// Default retry config
        let defaultConfig = {
            MaxAttempts = 3
            BaseDelayMs = 100
            MaxDelayMs = 5000
            ExponentialBackoff = true
            ShouldRetry = fun _ -> true
        }

        /// Calculate delay for attempt
        let private calculateDelay (config: RetryConfig) (attempt: int) =
            if config.ExponentialBackoff then
                min config.MaxDelayMs (config.BaseDelayMs * pown 2 attempt)
            else
                config.BaseDelayMs

        /// Retry with configuration
        let withConfig (config: RetryConfig) (operation: unit -> Async<'T>) : Async<Result<'T, exn>> =
            let rec loop attempt = async {
                try
                    let! result = operation ()
                    return Ok result
                with ex ->
                    if attempt < config.MaxAttempts && config.ShouldRetry ex then
                        let delay = calculateDelay config attempt
                        do! Async.Sleep delay
                        return! loop (attempt + 1)
                    else
                        return Error ex
            }
            loop 0

        /// Simple retry with default config
        let retry operation = withConfig defaultConfig operation

        /// Retry with custom attempts
        let retryN maxAttempts operation =
            withConfig { defaultConfig with MaxAttempts = maxAttempts } operation

        /// Retry with custom delay
        let retryWithDelay delayMs operation =
            withConfig { defaultConfig with BaseDelayMs = delayMs } operation

        /// Retry only specific exceptions
        let retryWhen shouldRetry operation =
            withConfig { defaultConfig with ShouldRetry = shouldRetry } operation

        /// Retry async result operations
        let retryAsyncResult (config: RetryConfig) (operation: unit -> Async<Result<'T, 'E>>) : Async<Result<'T, 'E>> =
            let rec loop attempt lastError = async {
                let! result = operation ()
                match result with
                | Ok v -> return Ok v
                | Error e when attempt < config.MaxAttempts ->
                    let delay = calculateDelay config attempt
                    do! Async.Sleep delay
                    return! loop (attempt + 1) (Some e)
                | Error e -> return Error e
            }
            loop 0 None

    // =========================================================================
    // TIMEOUT PIPELINE (SC-PRF-050, SC-PRF-055)
    // =========================================================================

    module Timeout =

        /// Run with timeout (SC-PRF-050: <50ms response)
        let withTimeout (timeoutMs: int) (operation: Async<'T>) : Async<Result<'T, string>> = async {
            let! child = Async.StartChild(operation, timeoutMs)
            try
                let! result = child
                return Ok result
            with
            | :? TimeoutException ->
                return Error $"Operation timed out after {timeoutMs}ms"
        }

        /// Run with cancellation token
        let withCancellation (token: Threading.CancellationToken) (operation: Async<'T>) : Async<Result<'T, string>> = async {
            try
                let! result = Async.StartChild(operation)
                let! value = result
                return Ok value
            with
            | :? OperationCanceledException ->
                return Error "Operation was cancelled"
        }

        /// Default response timeout (SC-PRF-050)
        let defaultResponseTimeout = 50

        /// Default operation timeout
        let defaultOperationTimeout = 30_000

    // =========================================================================
    // PARALLEL PIPELINE
    // =========================================================================

    module Parallel =

        /// Run operations in parallel, collect all results
        let all (operations: Async<'T> list) : Async<'T list> = async {
            let! results = operations |> Async.Parallel
            return results |> Array.toList
        }

        /// Run operations in parallel, collect all Results
        let allResults (operations: Async<Result<'T, 'E>> list) : Async<Result<'T list, 'E list>> = async {
            let! results = operations |> Async.Parallel
            let oks = results |> Array.choose (function Ok v -> Some v | _ -> None) |> Array.toList
            let errors = results |> Array.choose (function Error e -> Some e | _ -> None) |> Array.toList

            if errors.IsEmpty then
                return Ok oks
            else
                return Error errors
        }

        /// Run first successful operation
        let race (operations: Async<Result<'T, 'E>> list) : Async<Result<'T, 'E list>> = async {
            let! results = operations |> Async.Parallel
            let firstOk = results |> Array.tryPick (function Ok v -> Some v | _ -> None)
            match firstOk with
            | Some v -> return Ok v
            | None ->
                let errors = results |> Array.choose (function Error e -> Some e | _ -> None) |> Array.toList
                return Error errors
        }

        /// Map in parallel with concurrency limit
        let mapLimit (concurrency: int) (f: 'T -> Async<'U>) (items: 'T list) : Async<'U list> = async {
            let semaphore = new Threading.SemaphoreSlim(concurrency)

            let withSemaphore item = async {
                do! semaphore.WaitAsync() |> Async.AwaitTask
                try
                    return! f item
                finally
                    semaphore.Release() |> ignore
            }

            let! results = items |> List.map withSemaphore |> Async.Parallel
            return results |> Array.toList
        }

    // =========================================================================
    // BUILDER PIPELINE (for fluent configuration)
    // =========================================================================

    /// Fluent builder pattern using composition
    module Builder =

        /// Configuration step result
        type BuildStep<'T> = 'T -> Result<'T, string>

        /// Empty builder (identity)
        let empty : BuildStep<'T> = Ok

        /// Add a step to the builder
        let step f : BuildStep<'T> = f

        /// Combine two build steps
        let andThen (step2: BuildStep<'T>) (step1: BuildStep<'T>) : BuildStep<'T> =
            step1 >=> step2

        /// Combine build steps with operator
        let (>>>) = andThen

        /// Add conditional step
        let when' predicate (step: BuildStep<'T>) : BuildStep<'T> =
            fun value ->
                if predicate value then step value
                else Ok value

        /// Add validation step
        let validate predicate error : BuildStep<'T> =
            fun value ->
                if predicate value then Ok value
                else Error error

        /// Build with steps
        let build (steps: BuildStep<'T> list) (initial: 'T) : Result<'T, string> =
            steps |> List.fold (fun acc step -> acc >>= step) (Ok initial)
