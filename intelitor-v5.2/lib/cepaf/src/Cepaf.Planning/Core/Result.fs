// =============================================================================
// Result.fs - Railway-Oriented Programming for Planning System
// =============================================================================
// STAMP: SC-PLAN-003
// AOR: AOR-PLAN-003
// Criticality: Level 1 (CRITICAL) - Foundation
// =============================================================================

namespace Cepaf.Planning.Core

open System

/// Railway-oriented programming primitives
[<RequireQualifiedAccess>]
module Result =

    /// Bind (flatMap) - chain operations that might fail
    let bind (f: 'a -> Result<'b, 'e>) (result: Result<'a, 'e>) : Result<'b, 'e> =
        match result with
        | Ok x -> f x
        | Error e -> Error e

    /// Map - transform success value
    let map (f: 'a -> 'b) (result: Result<'a, 'e>) : Result<'b, 'e> =
        match result with
        | Ok x -> Ok (f x)
        | Error e -> Error e

    /// Map error - transform error value
    let mapError (f: 'e1 -> 'e2) (result: Result<'a, 'e1>) : Result<'a, 'e2> =
        match result with
        | Ok x -> Ok x
        | Error e -> Error (f e)

    /// Apply - for applicative functor style
    let apply (fResult: Result<'a -> 'b, 'e>) (xResult: Result<'a, 'e>) : Result<'b, 'e> =
        match fResult, xResult with
        | Ok f, Ok x -> Ok (f x)
        | Error e, _ -> Error e
        | _, Error e -> Error e

    /// Lift a function to work with Results
    let lift2 (f: 'a -> 'b -> 'c) (a: Result<'a, 'e>) (b: Result<'b, 'e>) : Result<'c, 'e> =
        match a, b with
        | Ok va, Ok vb -> Ok (f va vb)
        | Error e, _ -> Error e
        | _, Error e -> Error e

    /// Lift a function with 3 arguments
    let lift3 (f: 'a -> 'b -> 'c -> 'd) (a: Result<'a, 'e>) (b: Result<'b, 'e>) (c: Result<'c, 'e>) : Result<'d, 'e> =
        match a, b, c with
        | Ok va, Ok vb, Ok vc -> Ok (f va vb vc)
        | Error e, _, _ -> Error e
        | _, Error e, _ -> Error e
        | _, _, Error e -> Error e

    /// Combine multiple results into one (sequence)
    let sequence (results: Result<'a, 'e> list) : Result<'a list, 'e> =
        let folder state result =
            match state, result with
            | Ok acc, Ok x -> Ok (x :: acc)
            | Error e, _ -> Error e
            | _, Error e -> Error e
        results |> List.fold folder (Ok []) |> map List.rev

    /// Traverse - map and sequence in one pass
    let traverse (f: 'a -> Result<'b, 'e>) (items: 'a list) : Result<'b list, 'e> =
        items |> List.map f |> sequence

    /// Partition results into successes and failures
    let partition (results: Result<'a, 'e> list) : 'a list * 'e list =
        let rec loop oks errs = function
            | [] -> (List.rev oks, List.rev errs)
            | Ok x :: rest -> loop (x :: oks) errs rest
            | Error e :: rest -> loop oks (e :: errs) rest
        loop [] [] results

    /// Try-catch wrapper
    let tryWith (f: unit -> 'a) : Result<'a, string> =
        try Ok (f ())
        with ex -> Error ex.Message

    /// Try-catch with custom error mapping
    let tryWithMap (mapError: exn -> 'e) (f: unit -> 'a) : Result<'a, 'e> =
        try Ok (f ())
        with ex -> Error (mapError ex)

    /// Get value or default
    let defaultValue (defaultVal: 'a) (result: Result<'a, 'e>) : 'a =
        match result with
        | Ok x -> x
        | Error _ -> defaultVal

    /// Get value or compute default
    let defaultWith (f: 'e -> 'a) (result: Result<'a, 'e>) : 'a =
        match result with
        | Ok x -> x
        | Error e -> f e

    /// Convert Option to Result
    let ofOption (error: 'e) (opt: 'a option) : Result<'a, 'e> =
        match opt with
        | Some x -> Ok x
        | None -> Error error

    /// Convert Result to Option (discarding error)
    let toOption (result: Result<'a, 'e>) : 'a option =
        match result with
        | Ok x -> Some x
        | Error _ -> None

    /// Check if result is Ok
    let isOk (result: Result<'a, 'e>) : bool =
        match result with
        | Ok _ -> true
        | Error _ -> false

    /// Check if result is Error
    let isError (result: Result<'a, 'e>) : bool =
        match result with
        | Ok _ -> false
        | Error _ -> true

    /// Side effect on success
    let iter (f: 'a -> unit) (result: Result<'a, 'e>) : unit =
        match result with
        | Ok x -> f x
        | Error _ -> ()

    /// Side effect on error
    let iterError (f: 'e -> unit) (result: Result<'a, 'e>) : unit =
        match result with
        | Ok _ -> ()
        | Error e -> f e

    /// Tap - execute side effect but return original result
    let tap (f: 'a -> unit) (result: Result<'a, 'e>) : Result<'a, 'e> =
        iter f result
        result

    /// Require - convert bool to Result
    let require (error: 'e) (condition: bool) : Result<unit, 'e> =
        if condition then Ok ()
        else Error error

    /// Ignore Ok value, keep error
    let ignoreOk (result: Result<'a, 'e>) : Result<unit, 'e> =
        map ignore result

/// Computation expression for Result (railway-oriented programming)
type ResultBuilder() =
    member _.Bind(m, f) = Result.bind f m
    member _.Return(x) = Ok x
    member _.ReturnFrom(m) = m
    member _.Zero() = Ok ()
    member _.Combine(a, b) = Result.bind (fun () -> b) a
    member _.Delay(f) = f
    member _.Run(f) = f ()

    member _.TryWith(body, handler) =
        try body ()
        with ex -> handler ex

    member _.TryFinally(body, compensation) =
        try body ()
        finally compensation ()

    member _.Using(disposable: #IDisposable, body) =
        let body' = fun () -> body disposable
        ResultBuilder().TryFinally(body', fun () ->
            match disposable with
            | null -> ()
            | disp -> disp.Dispose())

    member _.While(guard, body) =
        if guard () then
            let result = body ()
            match result with
            | Ok () -> ResultBuilder().While(guard, body)
            | Error e -> Error e
        else
            Ok ()

    member _.For(sequence: seq<'a>, body: 'a -> Result<unit, 'e>) =
        let enumerator = sequence.GetEnumerator()
        ResultBuilder().TryFinally(
            (fun () ->
                ResultBuilder().While(
                    (fun () -> enumerator.MoveNext()),
                    (fun () -> body enumerator.Current))),
            (fun () -> enumerator.Dispose()))

/// Module containing the global result builder instance
[<AutoOpen>]
module ResultBuilderInstance =
    /// Global result builder instance
    let result = ResultBuilder()

/// Async Result computation expression
type AsyncResultBuilder() =
    member _.Bind(m: Async<Result<'a, 'e>>, f: 'a -> Async<Result<'b, 'e>>) : Async<Result<'b, 'e>> =
        async {
            let! result = m
            match result with
            | Ok x -> return! f x
            | Error e -> return Error e
        }

    member _.Return(x) = async { return Ok x }
    member _.ReturnFrom(m) = m
    member _.Zero() = async { return Ok () }

    member _.Delay(f) = f
    member _.Run(f) = f ()

    member _.Combine(a: Async<Result<unit, 'e>>, b: Async<Result<'b, 'e>>) : Async<Result<'b, 'e>> =
        async {
            let! resultA = a
            match resultA with
            | Ok () -> return! b
            | Error e -> return Error e
        }

/// Module containing the global async result builder instance
[<AutoOpen>]
module AsyncResultBuilderInstance =
    /// Global async result builder instance
    let asyncResult = AsyncResultBuilder()
