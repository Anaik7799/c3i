/// CEPAF Function Composition Module
/// Provides advanced functional composition utilities.
///
/// WHAT: Function composition operators and combinators
/// WHY: Enables declarative, point-free style for data transformations
/// CONSTRAINTS: SC-FSH-010, SC-FSH-011, SC-FSH-012
///
/// STAMP Compliance: SC-FSH-010 (Function Composition), SC-FSH-011 (Partial Application)
/// Version: 1.0.0
[<AutoOpen>]
module Cepaf.Core.Composition

open System

// ============================================================================
// STANDARD COMBINATORS (SKI + Extensions)
// ============================================================================

/// Identity function - returns input unchanged
let inline id x = x

/// Constant function - ignores second argument
let inline konst x _ = x

/// Flip - swaps the first two arguments of a function
let inline flip f x y = f y x

/// Apply - applies a function to an argument
let inline apply f x = f x

/// Apply 2 - applies a curried function to two arguments
let inline apply2 f x y = f x y

// ============================================================================
// COMPOSITION OPERATORS
// ============================================================================

// Note: >> and << are built-in F# operators
// These aliases make composition more explicit in some contexts

/// Forward composition (same as >>)
/// f >-> g = fun x -> g (f x)
let inline (>->) f g = f >> g

/// Backward composition (same as <<)
/// f <-< g = fun x -> f (g x)
let inline (<-<) f g = f << g

/// Compose async functions
let inline (>>>) (f: 'a -> Async<'b>) (g: 'b -> Async<'c>) : 'a -> Async<'c> =
    fun x -> async {
        let! intermediate = f x
        return! g intermediate
    }

/// Kleisli composition for Result
let inline (>=>) (f: 'a -> Result<'b, 'e>) (g: 'b -> Result<'c, 'e>) : 'a -> Result<'c, 'e> =
    fun x ->
        match f x with
        | Ok b -> g b
        | Error e -> Error e

/// Kleisli composition for Option
let inline (>>=>) (f: 'a -> 'b option) (g: 'b -> 'c option) : 'a -> 'c option =
    fun x ->
        match f x with
        | Some b -> g b
        | None -> None

// ============================================================================
// TAP / SIDE EFFECTS
// ============================================================================

/// Tap - execute side effect and return value unchanged
/// Useful for logging/debugging in pipelines
let inline tap f x =
    f x
    x

/// Tap async - execute async side effect and return value unchanged
let inline tapAsync f x = async {
    do! f x
    return x
}

/// Tap option - execute side effect only if Some
let inline tapSome f opt =
    match opt with
    | Some x -> f x; opt
    | None -> None

/// Tap result - execute side effect only if Ok
let inline tapOk f result =
    match result with
    | Ok x -> f x; result
    | Error _ -> result

/// Tap result error - execute side effect only if Error
let inline tapError f result =
    match result with
    | Ok _ -> result
    | Error e -> f e; result

// ============================================================================
// CONDITIONAL APPLICATION
// ============================================================================

/// Apply function only if condition is true
let inline applyIf condition f x =
    if condition then f x else x

/// Apply function only if predicate matches value
let inline applyWhen predicate f x =
    if predicate x then f x else x

/// Apply function or alternative based on condition
let inline applyIfElse condition f g x =
    if condition then f x else g x

/// Apply function n times
let rec applyN n f x =
    if n <= 0 then x
    else applyN (n - 1) f (f x)

/// Apply until predicate is satisfied or max iterations reached
let rec applyUntil maxIterations predicate f x =
    if maxIterations <= 0 || predicate x then x
    else applyUntil (maxIterations - 1) predicate f (f x)

// ============================================================================
// MEMOIZATION
// ============================================================================

/// Memoize a single-argument function
/// WARNING: Use only for pure functions with finite domain
let memoize f =
    let cache = System.Collections.Concurrent.ConcurrentDictionary<_, _>()
    fun x -> cache.GetOrAdd(x, lazy f x).Value

/// Memoize with custom equality comparer
let memoizeWith (comparer: System.Collections.Generic.IEqualityComparer<'a>) f =
    let cache = System.Collections.Concurrent.ConcurrentDictionary<_, _>(comparer)
    fun x -> cache.GetOrAdd(x, lazy f x).Value

/// Memoize with bounded cache size (LRU-like behavior)
let memoizeBounded maxSize f =
    let cache = System.Collections.Concurrent.ConcurrentDictionary<_, _>()
    fun x ->
        if cache.Count >= maxSize then
            // Simple eviction: clear half the cache
            let toRemove = cache.Keys |> Seq.take (maxSize / 2) |> Seq.toList
            for key in toRemove do
                cache.TryRemove(key) |> ignore
        cache.GetOrAdd(x, lazy f x).Value

// ============================================================================
// TUPLE UTILITIES
// ============================================================================

/// Apply function to first element of tuple
let inline mapFst f (x, y) = (f x, y)

/// Apply function to second element of tuple
let inline mapSnd f (x, y) = (x, f y)

/// Apply two functions to tuple elements
let inline mapBoth f g (x, y) = (f x, g y)

/// Swap tuple elements
let inline swap (x, y) = (y, x)

/// Duplicate value into tuple
let inline dup x = (x, x)

/// Apply function to duplicated value
let inline dupApply f x = (x, f x)

/// Uncurry a function
let inline uncurry f (x, y) = f x y

/// Curry a function
let inline curry f x y = f (x, y)

// ============================================================================
// LIST/SEQUENCE UTILITIES
// ============================================================================

/// Interleave two lists
let rec interleave xs ys =
    match xs, ys with
    | [], ys -> ys
    | xs, [] -> xs
    | x::xs', y::ys' -> x :: y :: interleave xs' ys'

/// Split list at predicate
let splitWhen predicate list =
    let rec loop acc = function
        | [] -> (List.rev acc, [])
        | x::xs when predicate x -> (List.rev acc, x::xs)
        | x::xs -> loop (x::acc) xs
    loop [] list

/// Group consecutive elements by predicate
let groupConsecutiveBy keyFn list =
    match list with
    | [] -> []
    | x::xs ->
        let rec loop currentKey currentGroup acc = function
            | [] -> List.rev ((currentKey, List.rev currentGroup) :: acc)
            | x::xs ->
                let key = keyFn x
                if key = currentKey then
                    loop currentKey (x::currentGroup) acc xs
                else
                    loop key [x] ((currentKey, List.rev currentGroup)::acc) xs
        loop (keyFn x) [x] [] xs

// ============================================================================
// OPTION UTILITIES
// ============================================================================

/// Sequence two options
let optionZip opt1 opt2 =
    match opt1, opt2 with
    | Some x, Some y -> Some (x, y)
    | _ -> None

/// Get value or compute default
let optionGetOrElse f opt =
    match opt with
    | Some x -> x
    | None -> f ()

/// Filter option by predicate
let optionFilter predicate opt =
    match opt with
    | Some x when predicate x -> Some x
    | _ -> None

/// Flatten nested option
let optionFlatten opt =
    match opt with
    | Some (Some x) -> Some x
    | _ -> None

// ============================================================================
// RESULT UTILITIES
// ============================================================================

/// Sequence two results
let resultZip result1 result2 =
    match result1, result2 with
    | Ok x, Ok y -> Ok (x, y)
    | Error e, _ -> Error e
    | _, Error e -> Error e

/// Get value or compute from error
let resultGetOrElse f result =
    match result with
    | Ok x -> x
    | Error e -> f e

/// Filter result by predicate
let resultFilter errorFn predicate result =
    match result with
    | Ok x when predicate x -> Ok x
    | Ok x -> Error (errorFn x)
    | Error e -> Error e

/// Flatten nested result
let resultFlatten result =
    match result with
    | Ok (Ok x) -> Ok x
    | Ok (Error e) -> Error e
    | Error e -> Error e

/// Convert option to result
let optionToResult error opt =
    match opt with
    | Some x -> Ok x
    | None -> Error error

/// Convert result to option
let resultToOption result =
    match result with
    | Ok x -> Some x
    | Error _ -> None

// ============================================================================
// ASYNC UTILITIES
// ============================================================================

/// Map over async
let asyncMap f asyncVal = async {
    let! x = asyncVal
    return f x
}

/// Bind over async
let asyncBind f asyncVal = async {
    let! x = asyncVal
    return! f x
}

/// Apply async function to async value
let asyncApply asyncF asyncX = async {
    let! f = asyncF
    let! x = asyncX
    return f x
}

/// Sequence list of async values
let asyncSequence asyncs = async {
    let! results = Async.Parallel asyncs
    return Array.toList results
}

/// Traverse list with async function
let asyncTraverse f xs = async {
    let! results = xs |> List.map f |> Async.Parallel
    return Array.toList results
}

/// Add timeout to async operation
let asyncWithTimeout (timeout: TimeSpan) asyncOp =
    async {
        let! child = Async.StartChild(asyncOp, int timeout.TotalMilliseconds)
        return! child
    }

/// Retry async operation with delays
let asyncRetry maxAttempts delay asyncOp =
    let rec loop attempt =
        async {
            try
                return! asyncOp
            with _ when attempt < maxAttempts ->
                do! Async.Sleep(int delay)
                return! loop (attempt + 1)
        }
    loop 1

// ============================================================================
// VALIDATION COMBINATORS
// ============================================================================

/// Validate value with multiple validators
let validate validators value =
    validators
    |> List.map (fun v -> v value)
    |> List.choose (function Error e -> Some e | Ok _ -> None)
    |> function
        | [] -> Ok value
        | errors -> Error errors

/// Combine validators
let (<&>) v1 v2 value =
    match v1 value, v2 value with
    | Ok _, Ok _ -> Ok value
    | Error e1, Error e2 -> Error (e1 @ e2)
    | Error e, _ | _, Error e -> Error e

// ============================================================================
// STRING UTILITIES
// ============================================================================

/// Join strings with separator (flipped String.concat)
let inline joinWith separator strings =
    String.concat separator strings

/// Split string by separator
let inline splitOn (separator: string) (str: string) =
    str.Split([|separator|], StringSplitOptions.None) |> Array.toList

/// Trim and filter empty strings
let inline cleanLines (str: string) =
    str.Split([|'\n'; '\r'|], StringSplitOptions.RemoveEmptyEntries)
    |> Array.map (fun s -> s.Trim())
    |> Array.filter (String.IsNullOrWhiteSpace >> not)
    |> Array.toList
