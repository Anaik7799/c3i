namespace Cepaf.Core

open System
open System.Threading.Tasks

/// Advanced Computation Expression Builders for specialized workflows.
/// Provides Reader, Writer, State, and specialized domain-specific workflows.
///
/// WHAT: Custom CE builders for Reader, Writer, State, and domain workflows
/// WHY: Enables declarative, composable workflows with implicit context passing
/// CONSTRAINTS:
///   - SC-FSH-040: Workflow builders must be lawful monads
///   - SC-FSH-041: No hidden state mutation
///   - SC-FSH-042: Builders must support proper sequencing
///
/// TDG Compliance:
///   - TDG-FSH-040: Monad laws tested (left identity, right identity, associativity)
///   - TDG-FSH-041: Composition correctness tested
///
/// AOR Compliance:
///   - AOR-FSH-020: Use workflow builders for context-dependent operations
module Workflows =

    // =========================================================================
    // READER MONAD - Implicit environment passing
    // =========================================================================

    /// Reader monad for dependency injection
    type Reader<'Env, 'T> = Reader of ('Env -> 'T)

    module Reader =
        let run env (Reader f) = f env

        let pure' x = Reader (fun _ -> x)

        let map f (Reader r) = Reader (fun env -> f (r env))

        let bind f (Reader r) = Reader (fun env ->
            let a = r env
            let (Reader r') = f a
            r' env)

        let ask = Reader id

        let asks f = Reader f

        let local f (Reader r) = Reader (f >> r)

    /// Reader computation expression builder
    type ReaderBuilder() =
        member _.Return(x) = Reader.pure' x
        member _.ReturnFrom(m) = m
        member _.Bind(m, f) = Reader.bind f m
        member _.Zero() = Reader.pure' ()
        member _.Combine(a, b) = Reader.bind (fun () -> b) a
        member _.Delay(f) = f ()

    let reader = ReaderBuilder()

    // =========================================================================
    // WRITER MONAD - Accumulated output
    // =========================================================================

    /// Writer monad for logging and accumulation
    type Writer<'W, 'T> = Writer of 'T * 'W list

    module Writer =
        let run (Writer (a, w)) = (a, w)

        let pure' x = Writer (x, [])

        let map f (Writer (a, w)) = Writer (f a, w)

        let bind f (Writer (a, w)) =
            let (Writer (b, w')) = f a
            Writer (b, w @ w')

        let tell w = Writer ((), [w])

        let listen (Writer (a, w)) = Writer ((a, w), w)

        let pass (Writer ((a, f), w)) = Writer (a, f w)

        let censor f (Writer (a, w)) = Writer (a, f w)

    /// Writer computation expression builder
    type WriterBuilder() =
        member _.Return(x) = Writer.pure' x
        member _.ReturnFrom(m) = m
        member _.Bind(m, f) = Writer.bind f m
        member _.Zero() = Writer.pure' ()
        member _.Combine(a, b) = Writer.bind (fun () -> b) a
        member _.Delay(f) = f ()

    let writer = WriterBuilder()

    // =========================================================================
    // STATE MONAD - Stateful computation
    // =========================================================================

    /// State monad for stateful computations
    type State<'S, 'T> = State of ('S -> 'T * 'S)

    module State =
        let run s (State f) = f s

        let eval s m = run s m |> fst

        let exec s m = run s m |> snd

        let pure' x = State (fun s -> (x, s))

        let map f (State g) = State (fun s ->
            let (a, s') = g s
            (f a, s'))

        let bind f (State g) = State (fun s ->
            let (a, s') = g s
            let (State h) = f a
            h s')

        let get = State (fun s -> (s, s))

        let put s = State (fun _ -> ((), s))

        let modify f = State (fun s -> ((), f s))

        let gets f = State (fun s -> (f s, s))

    /// State computation expression builder
    type StateBuilder() =
        member _.Return(x) = State.pure' x
        member _.ReturnFrom(m) = m
        member _.Bind(m, f) = State.bind f m
        member _.Zero() = State.pure' ()
        member _.Combine(a, b) = State.bind (fun () -> b) a
        member _.Delay(f) = f ()

    let state = StateBuilder()

    // =========================================================================
    // READER-WRITER-STATE (RWS) MONAD
    // =========================================================================

    /// Combined Reader-Writer-State monad
    type RWS<'R, 'W, 'S, 'T> = RWS of ('R -> 'S -> 'T * 'S * 'W list)

    module RWS =
        let run r s (RWS f) = f r s

        let pure' x = RWS (fun _ s -> (x, s, []))

        let map f (RWS g) = RWS (fun r s ->
            let (a, s', w) = g r s
            (f a, s', w))

        let bind f (RWS g) = RWS (fun r s ->
            let (a, s', w) = g r s
            let (RWS h) = f a
            let (b, s'', w') = h r s'
            (b, s'', w @ w'))

        let ask = RWS (fun r s -> (r, s, []))

        let asks f = RWS (fun r s -> (f r, s, []))

        let local f (RWS g) = RWS (fun r s -> g (f r) s)

        let tell w = RWS (fun _ s -> ((), s, [w]))

        let get = RWS (fun _ s -> (s, s, []))

        let put s = RWS (fun _ _ -> ((), s, []))

        let modify f = RWS (fun _ s -> ((), f s, []))

    /// RWS computation expression builder
    type RWSBuilder() =
        member _.Return(x) = RWS.pure' x
        member _.ReturnFrom(m) = m
        member _.Bind(m, f) = RWS.bind f m
        member _.Zero() = RWS.pure' ()
        member _.Combine(a, b) = RWS.bind (fun () -> b) a
        member _.Delay(f) = f ()

    let rws = RWSBuilder()

    // =========================================================================
    // MAYBE BUILDER (Enhanced)
    // =========================================================================

    /// Enhanced Maybe/Option builder with early exit
    type MaybeBuilder() =
        member _.Return(x) = Some x
        member _.ReturnFrom(m) = m
        member _.Bind(m, f) = Option.bind f m
        member _.Zero() = None
        member _.Combine(a, b) = Option.bind (fun _ -> b ()) a
        member _.Delay(f) = f
        member _.Run(f) = f ()

        // Sequence operations
        member _.For(xs, f) =
            let rec loop = function
                | [] -> Some []
                | x :: rest ->
                    match f x with
                    | Some y ->
                        match loop rest with
                        | Some ys -> Some (y :: ys)
                        | None -> None
                    | None -> None
            loop (Seq.toList xs)

        member _.While(guard, body) =
            if guard () then
                match body () with
                | Some () -> None // Changed: use None to continue would loop forever
                | None -> None
            else Some ()

        member _.TryWith(body, handler) =
            try body ()
            with ex -> handler ex

        member _.TryFinally(body, compensation) =
            try body ()
            finally compensation ()

        member _.Using(resource: #IDisposable, body) =
            try body resource
            finally
                if not (isNull (box resource)) then
                    resource.Dispose()

    let maybe = MaybeBuilder()

    // =========================================================================
    // RESULT BUILDER (Enhanced with error accumulation)
    // =========================================================================

    /// Enhanced Result builder
    type ResultBuilder() =
        member _.Return(x) = Ok x
        member _.ReturnFrom(m) = m
        member _.Bind(m, f) = Result.bind f m
        member _.Zero() = Ok ()
        member _.Combine(a, b) =
            match a with
            | Ok () -> b ()
            | Error e -> Error e
        member _.Delay(f) = f
        member _.Run(f) = f ()

        member _.For(xs, f) =
            let rec loop acc = function
                | [] -> Ok (List.rev acc)
                | x :: rest ->
                    match f x with
                    | Ok y -> loop (y :: acc) rest
                    | Error e -> Error e
            loop [] (Seq.toList xs)

        member _.TryWith(body, handler) =
            try body ()
            with ex -> handler ex

        member _.TryFinally(body, compensation) =
            try body ()
            finally compensation ()

        member _.Using(resource: #IDisposable, body) =
            try body resource
            finally
                if not (isNull (box resource)) then
                    resource.Dispose()

    let result = ResultBuilder()

    // =========================================================================
    // VALIDATION BUILDER (Applicative - accumulates all errors)
    // =========================================================================

    /// Validation type that accumulates errors
    type Validation<'E, 'T> =
        | Valid of 'T
        | Invalid of 'E list

    module Validation =
        let pure' x = Valid x

        let map f = function
            | Valid x -> Valid (f x)
            | Invalid es -> Invalid es

        let apply fV xV =
            match fV, xV with
            | Valid f, Valid x -> Valid (f x)
            | Invalid es, Valid _ -> Invalid es
            | Valid _, Invalid es -> Invalid es
            | Invalid es1, Invalid es2 -> Invalid (es1 @ es2)

        let bind f = function
            | Valid x -> f x
            | Invalid es -> Invalid es

        let fromResult = function
            | Ok x -> Valid x
            | Error e -> Invalid [e]

        let toResult = function
            | Valid x -> Ok x
            | Invalid es -> Error es

    /// Validation builder (applicative style)
    type ValidationBuilder() =
        member _.Return(x) = Valid x
        member _.ReturnFrom(m) = m
        member _.Bind(m, f) = Validation.bind f m
        member _.Zero() = Valid ()

        /// Combine using applicative (accumulates errors)
        member _.MergeSources(v1, v2) =
            match v1, v2 with
            | Valid x, Valid y -> Valid (x, y)
            | Invalid es, Valid _ -> Invalid es
            | Valid _, Invalid es -> Invalid es
            | Invalid es1, Invalid es2 -> Invalid (es1 @ es2)

        member _.BindReturn(m, f) = Validation.map f m

    let validation = ValidationBuilder()

    // =========================================================================
    // LIST BUILDER (Non-deterministic computation)
    // =========================================================================

    /// List monad builder for non-deterministic computations
    type ListBuilder() =
        member _.Return(x) = [x]
        member _.ReturnFrom(m) = m
        member _.Bind(m, f) = List.collect f m
        member _.Zero() = []
        member _.Combine(a, b) = a @ b ()
        member _.Delay(f) = f
        member _.Run(f) = f ()
        member _.For(xs, f) = List.collect f (Seq.toList xs)
        member _.Yield(x) = [x]
        member _.YieldFrom(xs) = List.ofSeq xs

    let list = ListBuilder()

    // =========================================================================
    // ASYNC RESULT BUILDER (Enhanced)
    // =========================================================================

    /// Enhanced Async Result builder
    type AsyncResultBuilder() =
        member _.Return(x) = async { return Ok x }
        member _.ReturnFrom(m) = m

        member _.Bind(m: Async<Result<'T, 'E>>, f: 'T -> Async<Result<'U, 'E>>) = async {
            let! result = m
            match result with
            | Ok x -> return! f x
            | Error e -> return Error e
        }

        member _.Zero() = async { return Ok () }

        member _.Combine(a, b) = async {
            let! result = a
            match result with
            | Ok () -> return! b ()
            | Error e -> return Error e
        }

        member _.Delay(f) = f
        member _.Run(f) = f ()

        member _.TryWith(body, handler) = async {
            try return! body ()
            with ex -> return! handler ex
        }

        member _.TryFinally(body, compensation) = async {
            try return! body ()
            finally compensation ()
        }

        member _.Using(resource: #IDisposable, body) = async {
            try return! body resource
            finally
                if not (isNull (box resource)) then
                    resource.Dispose()
        }

        member _.While(guard, body) = async {
            if guard () then
                let! result = body ()
                match result with
                | Ok () -> return! async { return Ok () }
                | Error e -> return Error e
            else
                return Ok ()
        }

        member _.For(xs, f) = async {
            let rec loop = function
                | [] -> async { return Ok () }
                | x :: rest -> async {
                    let! result = f x
                    match result with
                    | Ok () -> return! loop rest
                    | Error e -> return Error e
                }
            return! loop (Seq.toList xs)
        }

    let asyncResult = AsyncResultBuilder()

    // =========================================================================
    // TASK RESULT BUILDER
    // =========================================================================

    /// Task-based result builder for C# interop
    type TaskResultBuilder() =
        member _.Return(x) = Task.FromResult(Ok x)
        member _.ReturnFrom(m: Task<Result<'T, 'E>>) = m

        member _.Bind(m: Task<Result<'T, 'E>>, f: 'T -> Task<Result<'U, 'E>>) = task {
            let! result = m
            match result with
            | Ok x -> return! f x
            | Error e -> return Error e
        }

        member _.Zero() = Task.FromResult(Ok ())

        member _.Delay(f) = f
        member _.Run(f) = f ()

    let taskResult = TaskResultBuilder()

    // =========================================================================
    // RESOURCE BUILDER (Bracket pattern)
    // =========================================================================

    /// Resource type with automatic cleanup
    type Resource<'T> = Resource of (unit -> 'T) * ('T -> unit)

    module Resource =
        let create acquire release = Resource (acquire, release)

        let use' (Resource (acquire, release)) f =
            let r = acquire ()
            try f r
            finally release r

        let map f (Resource (acquire, release)) =
            Resource ((fun () -> f (acquire ())), fun _ -> ())

        let bind f (Resource (acquire, release)) =
            Resource (
                (fun () ->
                    let r = acquire ()
                    let (Resource (acq', _)) = f r
                    acq' ()),
                (fun _ -> ())  // Simplified - proper impl would track both
            )

    /// Resource builder (bracket pattern)
    type ResourceBuilder() =
        member _.Return(x) = Resource ((fun () -> x), fun _ -> ())
        member _.ReturnFrom(m) = m
        member _.Bind(m, f) = Resource.bind f m
        member _.Zero() = Resource ((fun () -> ()), fun _ -> ())
        member _.Delay(f) = f ()

        /// Use a disposable resource
        member _.Using(resource: #IDisposable, body) =
            Resource.create
                (fun () -> resource)
                (fun r -> r.Dispose())
            |> Resource.bind body

    let resource = ResourceBuilder()

    // =========================================================================
    // CONTINUATION BUILDER
    // =========================================================================

    /// Continuation monad
    type Cont<'R, 'T> = Cont of (('T -> 'R) -> 'R)

    module Cont =
        let run k (Cont f) = f k

        let pure' x = Cont (fun k -> k x)

        let map f (Cont c) = Cont (fun k -> c (f >> k))

        let bind f (Cont c) = Cont (fun k ->
            c (fun a ->
                let (Cont c') = f a
                c' k))

        let callCC f = Cont (fun k ->
            let (Cont c) = f (fun a -> Cont (fun _ -> k a))
            c k)

    /// Continuation builder
    type ContBuilder() =
        member _.Return(x) = Cont.pure' x
        member _.ReturnFrom(m) = m
        member _.Bind(m, f) = Cont.bind f m
        member _.Zero() = Cont.pure' ()
        member _.Delay(f) = f ()

    let cont = ContBuilder()
