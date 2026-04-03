/// CEPAF Arrows Module
/// Provides Arrow abstractions for composable computation with multiple inputs.
///
/// WHAT: Arrows, Kleisli arrows, ArrowChoice, ArrowApply, ArrowLoop
/// WHY: Model computations with static/dynamic wiring, dataflow, circuits
/// CONSTRAINTS:
///   - SC-FSH-140: Arrow laws must hold (identity, composition, first)
///   - SC-FSH-141: ArrowChoice must handle both branches
///   - SC-FSH-142: ArrowLoop must not create infinite loops in finite time
///
/// STAMP Compliance: SC-FSH-140 to SC-FSH-145
/// Version: 1.0.0
namespace Cepaf.Core

open System

// ============================================================================
// ARROW TYPE CLASS (as module pattern)
// ============================================================================

/// Arrow - generalized function abstraction
/// Arrows are computations that take an input and produce an output,
/// with the ability to compose and work with pairs.
type Arrow<'A, 'B> = Arrow of ('A -> 'B)

module Arrow =
    // ========================================================================
    // CORE ARROW OPERATIONS
    // ========================================================================

    /// Lift a function into an arrow
    let arr (f: 'A -> 'B) : Arrow<'A, 'B> = Arrow f

    /// Run an arrow
    let run (Arrow f) x = f x

    /// Identity arrow
    let id<'A> : Arrow<'A, 'A> = arr id

    /// Compose arrows (left to right)
    let compose (Arrow f: Arrow<'A, 'B>) (Arrow g: Arrow<'B, 'C>) : Arrow<'A, 'C> =
        Arrow (f >> g)

    /// Compose operator (>>>)
    let (>>>) = compose

    /// Reverse compose (<<<)
    let (<<<) g f = compose f g

    /// First - apply arrow to first element of pair
    let first (Arrow f: Arrow<'A, 'B>) : Arrow<'A * 'C, 'B * 'C> =
        Arrow (fun (a, c) -> (f a, c))

    /// Second - apply arrow to second element of pair
    let second (Arrow f: Arrow<'A, 'B>) : Arrow<'C * 'A, 'C * 'B> =
        Arrow (fun (c, a) -> (c, f a))

    /// Split - apply two arrows in parallel
    let split (Arrow f: Arrow<'A, 'B>) (Arrow g: Arrow<'C, 'D>) : Arrow<'A * 'C, 'B * 'D> =
        Arrow (fun (a, c) -> (f a, g c))

    /// Split operator (***)
    let ( *** ) = split

    /// Fan-out - apply both arrows to same input
    let fanout (Arrow f: Arrow<'A, 'B>) (Arrow g: Arrow<'A, 'C>) : Arrow<'A, 'B * 'C> =
        Arrow (fun a -> (f a, g a))

    /// Fan-out operator (&&&)
    let ( &&& ) = fanout

    /// Constant arrow
    let constant (b: 'B) : Arrow<'A, 'B> = arr (fun _ -> b)

    /// Swap elements of a pair
    let swap<'A, 'B> : Arrow<'A * 'B, 'B * 'A> =
        arr (fun (a, b) -> (b, a))

    /// Associate left
    let assocL<'A, 'B, 'C> : Arrow<'A * ('B * 'C), ('A * 'B) * 'C> =
        arr (fun (a, (b, c)) -> ((a, b), c))

    /// Associate right
    let assocR<'A, 'B, 'C> : Arrow<('A * 'B) * 'C, 'A * ('B * 'C)> =
        arr (fun ((a, b), c) -> (a, (b, c)))

// ============================================================================
// ARROW CHOICE
// ============================================================================

/// ArrowChoice - arrows that can handle Either/Choice types
module ArrowChoice =
    open Arrow

    /// Left - apply arrow to Left, pass Right through
    let left (Arrow f: Arrow<'A, 'B>) : Arrow<Choice<'A, 'C>, Choice<'B, 'C>> =
        Arrow (function
            | Choice1Of2 a -> Choice1Of2 (f a)
            | Choice2Of2 c -> Choice2Of2 c
        )

    /// Right - apply arrow to Right, pass Left through
    let right (Arrow f: Arrow<'A, 'B>) : Arrow<Choice<'C, 'A>, Choice<'C, 'B>> =
        Arrow (function
            | Choice1Of2 c -> Choice1Of2 c
            | Choice2Of2 a -> Choice2Of2 (f a)
        )

    /// Choice - apply different arrows to different branches
    let choice (Arrow f: Arrow<'A, 'C>) (Arrow g: Arrow<'B, 'C>) : Arrow<Choice<'A, 'B>, 'C> =
        Arrow (function
            | Choice1Of2 a -> f a
            | Choice2Of2 b -> g b
        )

    /// Choice operator (+++)
    let ( +++ ) (Arrow f: Arrow<'A, 'B>) (Arrow g: Arrow<'C, 'D>) : Arrow<Choice<'A, 'C>, Choice<'B, 'D>> =
        Arrow (function
            | Choice1Of2 a -> Choice1Of2 (f a)
            | Choice2Of2 c -> Choice2Of2 (g c)
        )

    /// Fan-in operator (|||)
    let ( ||| ) = choice

    /// Test and branch
    let test (pred: 'A -> bool) : Arrow<'A, Choice<'A, 'A>> =
        arr (fun a -> if pred a then Choice1Of2 a else Choice2Of2 a)

    /// If-then-else arrow
    let ifThenElse (pred: 'A -> bool) (thenArrow: Arrow<'A, 'B>) (elseArrow: Arrow<'A, 'B>) : Arrow<'A, 'B> =
        test pred >>> choice thenArrow elseArrow

// ============================================================================
// ARROW APPLY (Higher-order arrows)
// ============================================================================

/// ArrowApply - arrows that can apply other arrows
module ArrowApply =
    open Arrow

    /// Apply - run an arrow passed as input
    let app<'A, 'B> : Arrow<Arrow<'A, 'B> * 'A, 'B> =
        Arrow (fun (Arrow f, a) -> f a)

    /// Curry an arrow that takes a pair
    let curry (Arrow f: Arrow<'A * 'B, 'C>) : Arrow<'A, Arrow<'B, 'C>> =
        Arrow (fun a -> Arrow (fun b -> f (a, b)))

    /// Uncurry an arrow
    let uncurry (Arrow f: Arrow<'A, Arrow<'B, 'C>>) : Arrow<'A * 'B, 'C> =
        Arrow (fun (a, b) ->
            let (Arrow g) = f a
            g b
        )

// ============================================================================
// ARROW LOOP (Feedback)
// ============================================================================

/// ArrowLoop - arrows with feedback
module ArrowLoop =
    open Arrow

    /// Loop - create feedback loop using trace with default initial value
    /// CAUTION: Can cause infinite loops if not carefully designed
    let loop (Arrow f: Arrow<'A * 'D, 'B * 'D>) : Arrow<'A, 'B> =
        Arrow (fun a ->
            // Simple loop implementation using iteration
            let mutable d = Unchecked.defaultof<'D>
            let mutable b = Unchecked.defaultof<'B>
            for _ in 1..10 do  // Bounded iterations
                let (b', d') = f (a, d)
                b <- b'
                d <- d'
            b
        )

    /// Trace - fixed point with initial value
    let trace (initial: 'D) (Arrow f: Arrow<'A * 'D, 'B * 'D>) : Arrow<'A, 'B> =
        Arrow (fun a ->
            let mutable d = initial
            let mutable result = Unchecked.defaultof<'B>
            for _ in 1..100 do  // Iterate to find fixed point (bounded)
                let (b, d') = f (a, d)
                result <- b
                d <- d'
            result
        )

// ============================================================================
// KLEISLI ARROWS (Monadic arrows)
// ============================================================================

/// Kleisli arrow for Option monad
type KleisliOption<'A, 'B> = KleisliOption of ('A -> 'B option)

module KleisliOption =
    let arr (f: 'A -> 'B) : KleisliOption<'A, 'B> =
        KleisliOption (f >> Some)

    let run (KleisliOption f) x = f x

    let id<'A> : KleisliOption<'A, 'A> = arr id

    let compose (KleisliOption f: KleisliOption<'A, 'B>) (KleisliOption g: KleisliOption<'B, 'C>) : KleisliOption<'A, 'C> =
        KleisliOption (fun a ->
            match f a with
            | None -> None
            | Some b -> g b
        )

    let (>=>) = compose

    let first (KleisliOption f: KleisliOption<'A, 'B>) : KleisliOption<'A * 'C, 'B * 'C> =
        KleisliOption (fun (a, c) ->
            match f a with
            | None -> None
            | Some b -> Some (b, c)
        )

    let second (KleisliOption f: KleisliOption<'A, 'B>) : KleisliOption<'C * 'A, 'C * 'B> =
        KleisliOption (fun (c, a) ->
            match f a with
            | None -> None
            | Some b -> Some (c, b)
        )

/// Kleisli arrow for Result monad
type KleisliResult<'A, 'B, 'E> = KleisliResult of ('A -> Result<'B, 'E>)

module KleisliResult =
    let arr (f: 'A -> 'B) : KleisliResult<'A, 'B, 'E> =
        KleisliResult (f >> Ok)

    let run (KleisliResult f) x = f x

    let id<'A, 'E> : KleisliResult<'A, 'A, 'E> = arr id

    let compose (KleisliResult f: KleisliResult<'A, 'B, 'E>) (KleisliResult g: KleisliResult<'B, 'C, 'E>) : KleisliResult<'A, 'C, 'E> =
        KleisliResult (fun a ->
            match f a with
            | Error e -> Error e
            | Ok b -> g b
        )

    let (>=>) = compose

    let first (KleisliResult f: KleisliResult<'A, 'B, 'E>) : KleisliResult<'A * 'C, 'B * 'C, 'E> =
        KleisliResult (fun (a, c) ->
            match f a with
            | Error e -> Error e
            | Ok b -> Ok (b, c)
        )

/// Kleisli arrow for Async
type KleisliAsync<'A, 'B> = KleisliAsync of ('A -> Async<'B>)

module KleisliAsync =
    let arr (f: 'A -> 'B) : KleisliAsync<'A, 'B> =
        KleisliAsync (fun a -> async { return f a })

    let run (KleisliAsync f) x = f x

    let id<'A> : KleisliAsync<'A, 'A> = arr id

    let compose (KleisliAsync f: KleisliAsync<'A, 'B>) (KleisliAsync g: KleisliAsync<'B, 'C>) : KleisliAsync<'A, 'C> =
        KleisliAsync (fun a -> async {
            let! b = f a
            return! g b
        })

    let (>=>) = compose

    let first (KleisliAsync f: KleisliAsync<'A, 'B>) : KleisliAsync<'A * 'C, 'B * 'C> =
        KleisliAsync (fun (a, c) -> async {
            let! b = f a
            return (b, c)
        })

    let parallel' (KleisliAsync f: KleisliAsync<'A, 'B>) (KleisliAsync g: KleisliAsync<'C, 'D>) : KleisliAsync<'A * 'C, 'B * 'D> =
        KleisliAsync (fun (a, c) -> async {
            let! results = Async.Parallel [|
                async { let! b = f a in return box b }
                async { let! d = g c in return box d }
            |]
            return (unbox<'B> results.[0], unbox<'D> results.[1])
        })

// ============================================================================
// CIRCUIT ARROWS (Stateful arrows for signal processing)
// ============================================================================

/// Circuit arrow - arrow with internal state
type Circuit<'S, 'A, 'B> = Circuit of ('S -> 'A -> 'B * 'S)

module Circuit =
    /// Create stateless circuit
    let arr (f: 'A -> 'B) : Circuit<unit, 'A, 'B> =
        Circuit (fun () a -> (f a, ()))

    /// Create stateful circuit
    let arrState (f: 'S -> 'A -> 'B * 'S) : Circuit<'S, 'A, 'B> =
        Circuit f

    /// Run circuit with initial state
    let run (initial: 'S) (Circuit f: Circuit<'S, 'A, 'B>) (inputs: 'A list) : 'B list =
        let rec go state = function
            | [] -> []
            | x :: xs ->
                let (y, state') = f state x
                y :: go state' xs
        go initial inputs

    /// Identity circuit
    let id<'A> : Circuit<unit, 'A, 'A> = arr id

    /// Compose circuits (need to combine states)
    let compose (Circuit f: Circuit<'S1, 'A, 'B>) (Circuit g: Circuit<'S2, 'B, 'C>) : Circuit<'S1 * 'S2, 'A, 'C> =
        Circuit (fun (s1, s2) a ->
            let (b, s1') = f s1 a
            let (c, s2') = g s2 b
            (c, (s1', s2'))
        )

    let (>>>) = compose

    /// First on circuits
    let first (Circuit f: Circuit<'S, 'A, 'B>) : Circuit<'S, 'A * 'C, 'B * 'C> =
        Circuit (fun s (a, c) ->
            let (b, s') = f s a
            ((b, c), s')
        )

    /// Delay - output previous input
    let delay (initial: 'A) : Circuit<'A, 'A, 'A> =
        Circuit (fun prev current -> (prev, current))

    /// Accumulator - running fold
    let accum (initial: 'S) (f: 'S -> 'A -> 'S) : Circuit<'S, 'A, 'S> =
        Circuit (fun s a ->
            let s' = f s a
            (s', s')
        )

    /// Counter
    let counter : Circuit<int, unit, int> =
        accum 0 (fun n () -> n + 1)

    /// Running sum
    let runningSum : Circuit<float, float, float> =
        accum 0.0 (+)

    /// Running average
    let runningAverage : Circuit<float * int, float, float> =
        Circuit (fun (sum, count) x ->
            let sum' = sum + x
            let count' = count + 1
            (sum' / float count', (sum', count'))
        )

    /// Moving average with window
    let movingAverage (windowSize: int) : Circuit<float list, float, float> =
        Circuit (fun window x ->
            let window' =
                if List.length window >= windowSize then
                    x :: (List.take (windowSize - 1) window)
                else
                    x :: window
            let avg = List.average window'
            (avg, window')
        )

    /// Edge detector - detect rising edge
    let edge : Circuit<bool, bool, bool> =
        Circuit (fun prev current ->
            (current && not prev, current)
        )

    /// Debounce - filter rapid changes (requires equality constraint)
    let debounce<'A when 'A : equality> (threshold: int) : Circuit<'A option * int, 'A, 'A option> =
        Circuit (fun (lastValue, count) current ->
            match lastValue with
            | None -> (Some current, (Some current, 0))
            | Some last when last = current ->
                if count >= threshold then
                    (Some current, (Some current, count))
                else
                    (None, (Some current, count + 1))
            | Some _ -> (None, (Some current, 0))
        )

// ============================================================================
// DATAFLOW ARROWS
// ============================================================================

/// Internal stream type for DataflowArrow (module-internal)
type DfStreamNode<'T> = DfNil | DfCons of 'T * DfStream<'T>
    and DfStream<'T> = unit -> Async<DfStreamNode<'T>>

/// Dataflow arrow for stream processing
type DataflowArrow<'A, 'B> = DataflowArrow of (DfStream<'A> -> DfStream<'B>)

module DataflowArrow =
    open Arrow

    let arr (f: 'A -> 'B) : DataflowArrow<'A, 'B> =
        DataflowArrow (fun input ->
            let rec go (getNext: DfStream<'A>) : DfStream<'B> =
                fun () -> async {
                    let! node = getNext ()
                    match node with
                    | DfNil -> return DfNil
                    | DfCons (a, tail) -> return DfCons (f a, go tail)
                }
            go input
        )

    let run (DataflowArrow f) input = f input

    let identity<'A> : DataflowArrow<'A, 'A> = arr (fun x -> x)

    let compose (DataflowArrow f: DataflowArrow<'A, 'B>) (DataflowArrow g: DataflowArrow<'B, 'C>) : DataflowArrow<'A, 'C> =
        DataflowArrow (f >> g)

    let (>>>) = compose

    /// Filter in dataflow
    let filter (pred: 'A -> bool) : DataflowArrow<'A, 'A> =
        DataflowArrow (fun input ->
            let rec go getNext : DfStream<'A> =
                fun () -> async {
                    let! node = getNext ()
                    match node with
                    | DfNil -> return DfNil
                    | DfCons (a, tail) ->
                        if pred a then return DfCons (a, go tail)
                        else return! go tail ()
                }
            go input
        )

    /// Batch in dataflow
    let batch (size: int) : DataflowArrow<'A, 'A list> =
        DataflowArrow (fun input ->
            let rec go buffer getNext : DfStream<'A list> =
                fun () -> async {
                    if List.length buffer >= size then
                        return DfCons (List.rev buffer, go [] getNext)
                    else
                        let! node = getNext ()
                        match node with
                        | DfNil ->
                            if List.isEmpty buffer then return DfNil
                            else return DfCons (List.rev buffer, fun () -> async { return DfNil })
                        | DfCons (a, tail) ->
                            return! go (a :: buffer) tail ()
                }
            go [] input
        )

// ============================================================================
// ARROW SYNTAX HELPERS
// ============================================================================

/// Arrow computation expression builder
type ArrowBuilder() =
    member _.Return(x) = Arrow.constant x
    member _.ReturnFrom(arr) = arr
    member _.Bind(arr, f) =
        Arrow.compose arr (Arrow.arr f)

[<AutoOpen>]
module ArrowBuilders =
    let arrow = ArrowBuilder()

