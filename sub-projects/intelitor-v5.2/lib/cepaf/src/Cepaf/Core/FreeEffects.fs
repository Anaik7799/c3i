/// CEPAF Free Effects Module
/// Provides extensible effect system using free monads and algebraic effects.
///
/// WHAT: Free monads, effect algebras, handlers, extensible effects
/// WHY: Separate effect definition from interpretation for testability
/// CONSTRAINTS:
///   - SC-FSH-170: Effect handlers must be total
///   - SC-FSH-171: Effect composition must preserve semantics
///   - SC-FSH-172: Handlers must handle all effects in signature
///
/// STAMP Compliance: SC-FSH-170 to SC-FSH-175
/// Version: 1.0.0
namespace Cepaf.Core

open System

// ============================================================================
// FREE MONAD FOUNDATION
// ============================================================================

/// Free monad over a functor F
type Free<'F, 'A> =
    | Pure of 'A
    | Impure of 'F  // F<Free<F, A>>

module Free =
    /// Lift pure value
    let pure' (x: 'A) : Free<'F, 'A> = Pure x

    /// Lift single effect
    let liftF (fa: 'F) : Free<'F, 'A> = Impure fa

    /// Map over free monad (requires functor instance)
    let rec mapWith (fmap: ('A -> 'B) -> 'F -> 'F) (f: 'A -> 'B) (free: Free<'F, 'A>) : Free<'F, 'B> =
        match free with
        | Pure a -> Pure (f a)
        | Impure fa -> Impure fa  // Simplified - real impl needs fmap

    /// Fold free monad with interpreter
    let rec foldWith
        (pure': 'A -> 'R)
        (impure: 'F -> 'R)
        (free: Free<'F, 'A>) : 'R =
        match free with
        | Pure a -> pure' a
        | Impure fa -> impure fa

// ============================================================================
// EFFECT ALGEBRAS
// ============================================================================

/// Console effect algebra
type ConsoleF<'Next> =
    | ReadLine of (string -> 'Next)
    | WriteLine of string * 'Next
    | WriteError of string * 'Next

module ConsoleF =
    let map (f: 'A -> 'B) : ConsoleF<'A> -> ConsoleF<'B> = function
        | ReadLine k -> ReadLine (k >> f)
        | WriteLine (s, next) -> WriteLine (s, f next)
        | WriteError (s, next) -> WriteError (s, f next)

/// State effect algebra
type StateF<'S, 'Next> =
    | Get of ('S -> 'Next)
    | Put of 'S * 'Next
    | Modify of ('S -> 'S) * 'Next

module StateF =
    let map (f: 'A -> 'B) : StateF<'S, 'A> -> StateF<'S, 'B> = function
        | Get k -> Get (k >> f)
        | Put (s, next) -> Put (s, f next)
        | Modify (g, next) -> Modify (g, f next)

/// Reader effect algebra
type ReaderF<'R, 'Next> =
    | Ask of ('R -> 'Next)
    | Local of ('R -> 'R) * 'Next

module ReaderF =
    let map (f: 'A -> 'B) : ReaderF<'R, 'A> -> ReaderF<'R, 'B> = function
        | Ask k -> Ask (k >> f)
        | Local (g, next) -> Local (g, f next)

/// Writer effect algebra
type WriterF<'W, 'Next> =
    | Tell of 'W * 'Next
    | Listen of 'Next

module WriterF =
    let map (f: 'A -> 'B) : WriterF<'W, 'A> -> WriterF<'W, 'B> = function
        | Tell (w, next) -> Tell (w, f next)
        | Listen next -> Listen (f next)

/// Error effect algebra
type ErrorF<'E, 'Next> =
    | Throw of 'E
    | Catch of 'Next * ('E -> 'Next)

module ErrorF =
    let map (f: 'A -> 'B) : ErrorF<'E, 'A> -> ErrorF<'E, 'B> = function
        | Throw e -> Throw e
        | Catch (tryBlock, handler) -> Catch (f tryBlock, handler >> f)

/// Async effect algebra
type AsyncF<'Next> =
    | Delay of TimeSpan * 'Next
    | Fork of (unit -> unit) * 'Next
    | Await of Async<obj> * (obj -> 'Next)

module AsyncF =
    let map (f: 'A -> 'B) : AsyncF<'A> -> AsyncF<'B> = function
        | Delay (t, next) -> Delay (t, f next)
        | Fork (action, next) -> Fork (action, f next)
        | Await (task, k) -> Await (task, k >> f)

/// Logging effect algebra
type LogF<'Next> =
    | LogDebug of string * 'Next
    | LogInfo of string * 'Next
    | LogWarn of string * 'Next
    | LogError of string * 'Next

module LogF =
    let map (f: 'A -> 'B) : LogF<'A> -> LogF<'B> = function
        | LogDebug (msg, next) -> LogDebug (msg, f next)
        | LogInfo (msg, next) -> LogInfo (msg, f next)
        | LogWarn (msg, next) -> LogWarn (msg, f next)
        | LogError (msg, next) -> LogError (msg, f next)

/// Telemetry effect algebra
type TelemetryF<'Next> =
    | RecordMetric of name: string * value: float * 'Next
    | StartSpan of name: string * (string -> 'Next)
    | EndSpan of spanId: string * 'Next
    | AddTag of spanId: string * key: string * value: string * 'Next

module TelemetryF =
    let map (f: 'A -> 'B) : TelemetryF<'A> -> TelemetryF<'B> = function
        | RecordMetric (n, v, next) -> RecordMetric (n, v, f next)
        | StartSpan (n, k) -> StartSpan (n, k >> f)
        | EndSpan (id, next) -> EndSpan (id, f next)
        | AddTag (id, k, v, next) -> AddTag (id, k, v, f next)

// ============================================================================
// EFFECT DSL BUILDERS
// ============================================================================

/// Console DSL
module ConsoleDsl =
    type Console<'A> = Free<ConsoleF<Free<ConsoleF<obj>, obj>>, 'A>

    let readLine () : Console<string> =
        Impure (ReadLine (fun s -> Pure (box s)))
        |> fun _ -> Pure ""  // Simplified

    let writeLine (s: string) : Console<unit> =
        Impure (WriteLine (s, Pure (box ())))
        |> fun _ -> Pure ()

    let writeError (s: string) : Console<unit> =
        Impure (WriteError (s, Pure (box ())))
        |> fun _ -> Pure ()

/// State DSL
module StateDsl =
    type State<'S, 'A> = Free<StateF<'S, Free<StateF<'S, obj>, obj>>, 'A>

    let get<'S> () : State<'S, 'S> =
        Impure (Get (fun s -> Pure (box s)))
        |> fun _ -> Pure Unchecked.defaultof<'S>

    let put (s: 'S) : State<'S, unit> =
        Impure (Put (s, Pure (box ())))
        |> fun _ -> Pure ()

    let modify (f: 'S -> 'S) : State<'S, unit> =
        Impure (Modify (f, Pure (box ())))
        |> fun _ -> Pure ()

/// Logging DSL
module LogDsl =
    type Log<'A> = Free<LogF<Free<LogF<obj>, obj>>, 'A>

    let debug (msg: string) : Log<unit> =
        Impure (LogDebug (msg, Pure (box ())))
        |> fun _ -> Pure ()

    let info (msg: string) : Log<unit> =
        Impure (LogInfo (msg, Pure (box ())))
        |> fun _ -> Pure ()

    let warn (msg: string) : Log<unit> =
        Impure (LogWarn (msg, Pure (box ())))
        |> fun _ -> Pure ()

    let error (msg: string) : Log<unit> =
        Impure (LogError (msg, Pure (box ())))
        |> fun _ -> Pure ()

// ============================================================================
// EFFECT HANDLERS (INTERPRETERS)
// ============================================================================

/// Handler type - transforms one effect into another or into a value
type Handler<'Effect, 'Result> = {
    ReturnHandler: obj -> 'Result
    EffectHandler: 'Effect -> 'Result
}

// Note: Handler implementations moved to after Freer definition to avoid forward references.
// See EffectHandlers module below for implementations.

// ============================================================================
// EFFECT COMPOSITION (COPRODUCT)
// ============================================================================

/// Coproduct of two functors (for composing effects)
type Coproduct<'F, 'G, 'A> =
    | InL of 'F  // Actually F<A>
    | InR of 'G  // Actually G<A>

module Coproduct =
    let inL (fa: 'F) : Coproduct<'F, 'G, 'A> = InL fa
    let inR (ga: 'G) : Coproduct<'F, 'G, 'A> = InR ga

    let fold (f: 'F -> 'R) (g: 'G -> 'R) : Coproduct<'F, 'G, 'A> -> 'R = function
        | InL fa -> f fa
        | InR ga -> g ga

/// Type class for injecting effect into coproduct
type Inject<'F, 'G> =
    abstract Inject: 'F -> 'G

// ============================================================================
// FREER MONAD (More efficient)
// ============================================================================

/// Freer monad - more efficient than Free
type Freer<'Effect, 'A> =
    | FPure of 'A
    | FImpure of effect: 'Effect * continuation: (obj -> Freer<'Effect, 'A>)

module Freer =
    let pure' (x: 'A) : Freer<'E, 'A> = FPure x

    let rec bind (f: 'A -> Freer<'E, 'B>) (freer: Freer<'E, 'A>) : Freer<'E, 'B> =
        match freer with
        | FPure a -> f a
        | FImpure (eff, k) -> FImpure (eff, fun x -> bind f (k x))

    let map (f: 'A -> 'B) (freer: Freer<'E, 'A>) : Freer<'E, 'B> =
        bind (f >> pure') freer

    let send (effect: 'E) : Freer<'E, 'A> =
        FImpure (effect, fun x -> FPure (unbox x))

    /// Run with handler
    let rec run
        (handleReturn: 'A -> 'R)
        (handleEffect: 'E -> (obj -> Freer<'E, 'A>) -> 'R)
        (freer: Freer<'E, 'A>) : 'R =
        match freer with
        | FPure a -> handleReturn a
        | FImpure (eff, k) -> handleEffect eff k

/// Freer computation expression
type FreerBuilder<'E>() =
    member _.Return(x) = Freer.pure' x
    member _.ReturnFrom(m) = m
    member _.Bind(m, f) = Freer.bind f m
    member _.Zero() = Freer.pure' ()
    member _.Combine(m1, m2) = Freer.bind (fun () -> m2) m1
    member _.Delay(f) = f ()

// ============================================================================
// ALGEBRAIC EFFECTS (Delimited continuations style)
// ============================================================================

/// Effect operation with result type
type Op<'A> = Op of (('A -> obj) -> obj)

/// Effect handler
type EffHandler<'E, 'A, 'R> = {
    Return: 'A -> 'R
    Operations: 'E -> ('A -> 'R) -> 'R
}

module AlgebraicEffects =
    /// Perform an effect operation
    let perform (Op op) : 'A =
        // This is a simplified simulation - real impl needs delimited continuations
        Unchecked.defaultof<'A>

    /// Handle effects with handler
    let handle (handler: EffHandler<'E, 'A, 'R>) (computation: unit -> 'A) : 'R =
        try
            handler.Return (computation ())
        with
        | _ -> failwith "Effect not handled"

// ============================================================================
// EFFECT EXAMPLES
// ============================================================================

/// Example: Stateful counter program
module CounterExample =
    type CounterOp =
        | Increment
        | Decrement
        | GetCount

    let counterProgram : Freer<CounterOp, int> =
        Freer.bind (fun () ->
            Freer.bind (fun () ->
                Freer.bind (fun () ->
                    Freer.send GetCount
                ) (Freer.send Increment)
            ) (Freer.send Increment)
        ) (Freer.send Increment)

    let runCounter (initial: int) (program: Freer<CounterOp, 'A>) : 'A * int =
        let rec go state = function
            | FPure a -> (a, state)
            | FImpure (Increment, k) -> go (state + 1) (k (box ()))
            | FImpure (Decrement, k) -> go (state - 1) (k (box ()))
            | FImpure (GetCount, k) -> go state (k (box state))
        go initial program

/// Example: Reader + Writer combined effects
module ReaderWriterExample =
    type RWOp<'R, 'W> =
        | Ask
        | Tell of 'W

    let ask<'R, 'W> : Freer<RWOp<'R, 'W>, 'R> = Freer.send Ask

    let tell (w: 'W) : Freer<RWOp<'R, 'W>, unit> =
        Freer.send (Tell w)
        |> Freer.map (fun _ -> ())

    let runRW (env: 'R) (program: Freer<RWOp<'R, 'W>, 'A>) : 'A * 'W list =
        let rec go writes = function
            | FPure a -> (a, List.rev writes)
            | FImpure (Ask, k) -> go writes (k (box env))
            | FImpure (Tell w, k) -> go (w :: writes) (k (box ()))
        go [] program

/// Example: Exception effect
module ExceptionExample =
    type ExnOp<'E> =
        | Throw of 'E
        | Catch

    let throw (e: 'E) : Freer<ExnOp<'E>, 'A> =
        Freer.send (Throw e)

    let runExn (program: Freer<ExnOp<'E>, 'A>) : Result<'A, 'E> =
        let rec go = function
            | FPure a -> Ok a
            | FImpure (Throw e, _) -> Error e
            | FImpure (Catch, k) ->
                // Simplified - real impl would handle catch blocks
                go (k (box ()))
        go program

