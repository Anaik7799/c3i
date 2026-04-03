/// CEPAF Streaming Module
/// Provides streaming abstractions for processing unbounded data.
///
/// WHAT: AsyncSeq, Push/Pull streams, Transducers, Sinks, Sources
/// WHY: Memory-efficient processing of infinite/large observability data
/// CONSTRAINTS:
///   - SC-FSH-130: Streams must support backpressure
///   - SC-FSH-131: Transducers must compose without intermediate allocation
///   - SC-FSH-132: Async operations must be cancellable
///
/// STAMP Compliance: SC-FSH-130 to SC-FSH-135
/// Version: 1.0.0
namespace Cepaf.Core

open System
open System.Threading
open System.Threading.Tasks

// ============================================================================
// ASYNC SEQUENCE (PULL-BASED STREAMING)
// ============================================================================

/// Async sequence - lazy, pull-based stream
type AsyncSeq<'T> = AsyncSeq of (unit -> Async<AsyncSeqNode<'T>>)

and AsyncSeqNode<'T> =
    | AsyncSeqNil
    | AsyncSeqCons of head: 'T * tail: AsyncSeq<'T>

module AsyncSeq =
    /// Create empty sequence
    let empty<'T> : AsyncSeq<'T> =
        AsyncSeq (fun () -> async { return AsyncSeqNil })

    /// Create singleton sequence
    let singleton (x: 'T) : AsyncSeq<'T> =
        AsyncSeq (fun () -> async { return AsyncSeqCons (x, empty) })

    /// Get next element
    let uncons (AsyncSeq f) : Async<AsyncSeqNode<'T>> = f ()

    /// Prepend element
    let cons (x: 'T) (xs: AsyncSeq<'T>) : AsyncSeq<'T> =
        AsyncSeq (fun () -> async { return AsyncSeqCons (x, xs) })

    /// Create from list
    let ofList (xs: 'T list) : AsyncSeq<'T> =
        let rec go = function
            | [] -> empty
            | h :: t -> cons h (go t)
        go xs

    /// Create from array
    let ofArray (xs: 'T[]) : AsyncSeq<'T> =
        let rec go i =
            if i >= xs.Length then empty
            else cons xs.[i] (go (i + 1))
        go 0

    /// Create from seq
    let ofSeq (xs: seq<'T>) : AsyncSeq<'T> =
        ofList (Seq.toList xs)

    /// Create infinite sequence from generator
    let unfold (generator: 'State -> Async<('T * 'State) option>) (initial: 'State) : AsyncSeq<'T> =
        let rec go state =
            AsyncSeq (fun () -> async {
                let! result = generator state
                match result with
                | None -> return AsyncSeqNil
                | Some (value, nextState) -> return AsyncSeqCons (value, go nextState)
            })
        go initial

    /// Create infinite sequence from unfold (sync version)
    let unfoldSync (generator: 'State -> ('T * 'State) option) (initial: 'State) : AsyncSeq<'T> =
        unfold (fun s -> async { return generator s }) initial

    /// Map over async sequence
    let map (f: 'T -> 'U) (xs: AsyncSeq<'T>) : AsyncSeq<'U> =
        let rec go (AsyncSeq getNext) =
            AsyncSeq (fun () -> async {
                let! node = getNext ()
                match node with
                | AsyncSeqNil -> return AsyncSeqNil
                | AsyncSeqCons (h, t) -> return AsyncSeqCons (f h, go t)
            })
        go xs

    /// Async map
    let mapAsync (f: 'T -> Async<'U>) (xs: AsyncSeq<'T>) : AsyncSeq<'U> =
        let rec go (AsyncSeq getNext) =
            AsyncSeq (fun () -> async {
                let! node = getNext ()
                match node with
                | AsyncSeqNil -> return AsyncSeqNil
                | AsyncSeqCons (h, t) ->
                    let! mapped = f h
                    return AsyncSeqCons (mapped, go t)
            })
        go xs

    /// Filter async sequence
    let filter (pred: 'T -> bool) (xs: AsyncSeq<'T>) : AsyncSeq<'T> =
        let rec go (AsyncSeq getNext) =
            AsyncSeq (fun () -> async {
                let! node = getNext ()
                match node with
                | AsyncSeqNil -> return AsyncSeqNil
                | AsyncSeqCons (h, t) ->
                    if pred h then return AsyncSeqCons (h, go t)
                    else return! uncons (go t)
            })
        go xs

    /// Async filter
    let filterAsync (pred: 'T -> Async<bool>) (xs: AsyncSeq<'T>) : AsyncSeq<'T> =
        let rec go (AsyncSeq getNext) =
            AsyncSeq (fun () -> async {
                let! node = getNext ()
                match node with
                | AsyncSeqNil -> return AsyncSeqNil
                | AsyncSeqCons (h, t) ->
                    let! keep = pred h
                    if keep then return AsyncSeqCons (h, go t)
                    else return! uncons (go t)
            })
        go xs

    /// Take first n elements
    let take (n: int) (xs: AsyncSeq<'T>) : AsyncSeq<'T> =
        let rec go count (AsyncSeq getNext) =
            if count <= 0 then empty
            else AsyncSeq (fun () -> async {
                let! node = getNext ()
                match node with
                | AsyncSeqNil -> return AsyncSeqNil
                | AsyncSeqCons (h, t) -> return AsyncSeqCons (h, go (count - 1) t)
            })
        go n xs

    /// Take while predicate holds
    let takeWhile (pred: 'T -> bool) (xs: AsyncSeq<'T>) : AsyncSeq<'T> =
        let rec go (AsyncSeq getNext) =
            AsyncSeq (fun () -> async {
                let! node = getNext ()
                match node with
                | AsyncSeqNil -> return AsyncSeqNil
                | AsyncSeqCons (h, t) ->
                    if pred h then return AsyncSeqCons (h, go t)
                    else return AsyncSeqNil
            })
        go xs

    /// Skip first n elements
    let skip (n: int) (xs: AsyncSeq<'T>) : AsyncSeq<'T> =
        let rec go count (AsyncSeq getNext) =
            if count <= 0 then AsyncSeq getNext
            else AsyncSeq (fun () -> async {
                let! node = getNext ()
                match node with
                | AsyncSeqNil -> return AsyncSeqNil
                | AsyncSeqCons (_, t) -> return! uncons (go (count - 1) t)
            })
        go n xs

    /// Concatenate two sequences
    let append (xs: AsyncSeq<'T>) (ys: AsyncSeq<'T>) : AsyncSeq<'T> =
        let rec go (AsyncSeq getNext) =
            AsyncSeq (fun () -> async {
                let! node = getNext ()
                match node with
                | AsyncSeqNil -> return! uncons ys
                | AsyncSeqCons (h, t) -> return AsyncSeqCons (h, go t)
            })
        go xs

    /// Flatten nested sequences
    let concat (xss: AsyncSeq<AsyncSeq<'T>>) : AsyncSeq<'T> =
        let rec outer (AsyncSeq getOuter) =
            AsyncSeq (fun () -> async {
                let! node = getOuter ()
                match node with
                | AsyncSeqNil -> return AsyncSeqNil
                | AsyncSeqCons (inner, rest) -> return! uncons (append inner (outer rest))
            })
        outer xss

    /// FlatMap / bind
    let collect (f: 'T -> AsyncSeq<'U>) (xs: AsyncSeq<'T>) : AsyncSeq<'U> =
        xs |> map f |> concat

    /// Fold to single value
    let fold (folder: 'State -> 'T -> 'State) (initial: 'State) (xs: AsyncSeq<'T>) : Async<'State> =
        let rec go acc (AsyncSeq getNext) = async {
            let! node = getNext ()
            match node with
            | AsyncSeqNil -> return acc
            | AsyncSeqCons (h, t) -> return! go (folder acc h) t
        }
        go initial xs

    /// Async fold
    let foldAsync (folder: 'State -> 'T -> Async<'State>) (initial: 'State) (xs: AsyncSeq<'T>) : Async<'State> =
        let rec go acc (AsyncSeq getNext) = async {
            let! node = getNext ()
            match node with
            | AsyncSeqNil -> return acc
            | AsyncSeqCons (h, t) ->
                let! newAcc = folder acc h
                return! go newAcc t
        }
        go initial xs

    /// Map async result
    let private asyncMap f a = async { let! x = a in return f x }

    /// Convert to list
    let toList (xs: AsyncSeq<'T>) : Async<'T list> =
        fold (fun acc x -> x :: acc) [] xs
        |> asyncMap List.rev

    /// Convert to array
    let toArray (xs: AsyncSeq<'T>) : Async<'T[]> =
        toList xs |> asyncMap Array.ofList

    /// Iterate with side effects
    let iter (action: 'T -> unit) (xs: AsyncSeq<'T>) : Async<unit> =
        fold (fun () x -> action x) () xs

    /// Async iterate
    let iterAsync (action: 'T -> Async<unit>) (xs: AsyncSeq<'T>) : Async<unit> =
        foldAsync (fun () x -> action x) () xs

    /// Zip two sequences
    let zip (xs: AsyncSeq<'T>) (ys: AsyncSeq<'U>) : AsyncSeq<'T * 'U> =
        let rec go (AsyncSeq getX) (AsyncSeq getY) =
            AsyncSeq (fun () -> async {
                let! nodeX = getX ()
                let! nodeY = getY ()
                match nodeX, nodeY with
                | AsyncSeqCons (x, tx), AsyncSeqCons (y, ty) ->
                    return AsyncSeqCons ((x, y), go tx ty)
                | _ -> return AsyncSeqNil
            })
        go xs ys

    /// Zip with function
    let zipWith (f: 'T -> 'U -> 'V) (xs: AsyncSeq<'T>) (ys: AsyncSeq<'U>) : AsyncSeq<'V> =
        zip xs ys |> map (fun (x, y) -> f x y)

    /// Chunk into batches
    let chunkBySize (size: int) (xs: AsyncSeq<'T>) : AsyncSeq<'T list> =
        let rec go acc count (AsyncSeq getNext) =
            AsyncSeq (fun () -> async {
                if count >= size then
                    return AsyncSeqCons (List.rev acc, go [] 0 (AsyncSeq getNext))
                else
                    let! node = getNext ()
                    match node with
                    | AsyncSeqNil ->
                        if List.isEmpty acc then return AsyncSeqNil
                        else return AsyncSeqCons (List.rev acc, empty)
                    | AsyncSeqCons (h, t) ->
                        return! uncons (go (h :: acc) (count + 1) t)
            })
        go [] 0 xs

    /// Buffer with timeout
    let bufferByTime (interval: TimeSpan) (xs: AsyncSeq<'T>) : AsyncSeq<'T list> =
        // Simplified - real implementation would use timers
        chunkBySize 100 xs

    /// Sample every nth element
    let sample (n: int) (xs: AsyncSeq<'T>) : AsyncSeq<'T> =
        let rec go count (AsyncSeq getNext) =
            AsyncSeq (fun () -> async {
                let! node = getNext ()
                match node with
                | AsyncSeqNil -> return AsyncSeqNil
                | AsyncSeqCons (h, t) ->
                    if count % n = 0 then return AsyncSeqCons (h, go (count + 1) t)
                    else return! uncons (go (count + 1) t)
            })
        go 0 xs

    /// Distinct consecutive elements
    let distinctUntilChanged (xs: AsyncSeq<'T>) : AsyncSeq<'T> when 'T : equality =
        let rec go prev (AsyncSeq getNext) =
            AsyncSeq (fun () -> async {
                let! node = getNext ()
                match node with
                | AsyncSeqNil -> return AsyncSeqNil
                | AsyncSeqCons (h, t) ->
                    match prev with
                    | Some p when p = h -> return! uncons (go prev t)
                    | _ -> return AsyncSeqCons (h, go (Some h) t)
            })
        go None xs

// ============================================================================
// TRANSDUCERS (COMPOSABLE STREAM TRANSFORMERS)
// ============================================================================

/// Reducer - consumes values and produces result
type Reducer<'Result, 'Input> = {
    Init: unit -> 'Result
    Step: 'Result -> 'Input -> 'Result
    Complete: 'Result -> 'Result
}

/// Transducer - transforms one reducer into another (with explicit result type)
type Transducer<'R, 'A, 'B> = Transducer of (Reducer<'R, 'B> -> Reducer<'R, 'A>)

module Transducer =
    /// Apply transducer to reducer
    let apply (Transducer xf: Transducer<'R, 'A, 'B>) (reducer: Reducer<'R, 'B>) : Reducer<'R, 'A> = xf reducer

    /// Identity transducer
    let identity<'R, 'A> : Transducer<'R, 'A, 'A> =
        Transducer (fun r -> r)

    /// Map transducer
    let map<'R, 'A, 'B> (f: 'A -> 'B) : Transducer<'R, 'A, 'B> =
        Transducer (fun reducer -> {
            Init = reducer.Init
            Step = fun r a -> reducer.Step r (f a)
            Complete = reducer.Complete
        })

    /// Filter transducer
    let filter<'R, 'A> (pred: 'A -> bool) : Transducer<'R, 'A, 'A> =
        Transducer (fun reducer -> {
            Init = reducer.Init
            Step = fun r a -> if pred a then reducer.Step r a else r
            Complete = reducer.Complete
        })

    /// Take transducer
    let take<'R, 'A> (n: int) : Transducer<'R, 'A, 'A> =
        Transducer (fun reducer ->
            let mutable count = 0
            {
                Init = reducer.Init
                Step = fun r a ->
                    if count < n then
                        count <- count + 1
                        reducer.Step r a
                    else r
                Complete = reducer.Complete
            }
        )

    /// Drop transducer
    let drop<'R, 'A> (n: int) : Transducer<'R, 'A, 'A> =
        Transducer (fun reducer ->
            let mutable count = 0
            {
                Init = reducer.Init
                Step = fun r a ->
                    count <- count + 1
                    if count > n then reducer.Step r a else r
                Complete = reducer.Complete
            }
        )

    /// FlatMap transducer
    let flatMap<'R, 'A, 'B> (f: 'A -> 'B seq) : Transducer<'R, 'A, 'B> =
        Transducer (fun reducer -> {
            Init = reducer.Init
            Step = fun r a ->
                f a |> Seq.fold reducer.Step r
            Complete = reducer.Complete
        })

    /// Distinct transducer
    let distinct<'R, 'A when 'A : equality> : Transducer<'R, 'A, 'A> =
        Transducer (fun reducer ->
            let seen = System.Collections.Generic.HashSet<'A>()
            {
                Init = reducer.Init
                Step = fun r a ->
                    if seen.Add(a) then reducer.Step r a else r
                Complete = reducer.Complete
            }
        )

    /// Partition transducer - split into chunks
    let partition<'R, 'A> (size: int) : Transducer<'R, 'A, 'A list> =
        Transducer (fun reducer ->
            let buffer = ResizeArray<'A>()
            {
                Init = reducer.Init
                Step = fun r a ->
                    buffer.Add(a)
                    if buffer.Count >= size then
                        let chunk = buffer |> Seq.toList
                        buffer.Clear()
                        reducer.Step r chunk
                    else r
                Complete = fun r ->
                    if buffer.Count > 0 then
                        let chunk = buffer |> Seq.toList
                        buffer.Clear()
                        reducer.Complete (reducer.Step r chunk)
                    else reducer.Complete r
            }
        )

    /// Compose transducers (left to right)
    let compose (Transducer xf1: Transducer<'R, 'A, 'B>) (Transducer xf2: Transducer<'R, 'B, 'C>) : Transducer<'R, 'A, 'C> =
        Transducer (fun reducer -> xf1 (xf2 reducer))

    /// Compose operator
    let (>>>) = compose

    /// Transduce a sequence
    let transduce (xf: Transducer<'R, 'A, 'B>) (reducer: Reducer<'R, 'B>) (source: 'A seq) : 'R =
        let xfReducer = apply xf reducer
        let initial = xfReducer.Init ()
        let result = source |> Seq.fold xfReducer.Step initial
        xfReducer.Complete result

    /// Standard reducers
    module Reducers =
        let toList<'A> : Reducer<'A list, 'A> = {
            Init = fun () -> []
            Step = fun acc x -> x :: acc
            Complete = List.rev
        }

        let toArray<'A> : Reducer<ResizeArray<'A>, 'A> = {
            Init = fun () -> ResizeArray()
            Step = fun acc x -> acc.Add(x); acc
            Complete = id
        }

        let sum : Reducer<int, int> = {
            Init = fun () -> 0
            Step = (+)
            Complete = id
        }

        let count<'A> : Reducer<int, 'A> = {
            Init = fun () -> 0
            Step = fun acc _ -> acc + 1
            Complete = id
        }

// ============================================================================
// PUSH-BASED STREAMS (REACTIVE)
// ============================================================================

/// Observer for push-based streams
type IStreamObserver<'T> =
    abstract OnNext: 'T -> unit
    abstract OnError: exn -> unit
    abstract OnCompleted: unit -> unit

/// Subscription handle
type ISubscription =
    abstract Dispose: unit -> unit

/// Push-based stream (Observable-like)
type PushStream<'T> = PushStream of (IStreamObserver<'T> -> ISubscription)

module PushStream =
    /// Subscribe to stream
    let subscribe (observer: IStreamObserver<'T>) (PushStream subscribe') : ISubscription =
        subscribe' observer

    /// Create from values
    let ofSeq (values: 'T seq) : PushStream<'T> =
        PushStream (fun observer ->
            try
                for v in values do observer.OnNext v
                observer.OnCompleted()
            with ex -> observer.OnError ex
            { new ISubscription with member _.Dispose() = () }
        )

    /// Create singleton
    let singleton (value: 'T) : PushStream<'T> =
        ofSeq [value]

    /// Empty stream
    let empty<'T> : PushStream<'T> =
        PushStream (fun observer ->
            observer.OnCompleted()
            { new ISubscription with member _.Dispose() = () }
        )

    /// Map over stream
    let map (f: 'T -> 'U) (PushStream subscribe') : PushStream<'U> =
        PushStream (fun observer ->
            subscribe' { new IStreamObserver<'T> with
                member _.OnNext x = observer.OnNext (f x)
                member _.OnError e = observer.OnError e
                member _.OnCompleted() = observer.OnCompleted()
            }
        )

    /// Filter stream
    let filter (pred: 'T -> bool) (PushStream subscribe') : PushStream<'T> =
        PushStream (fun observer ->
            subscribe' { new IStreamObserver<'T> with
                member _.OnNext x = if pred x then observer.OnNext x
                member _.OnError e = observer.OnError e
                member _.OnCompleted() = observer.OnCompleted()
            }
        )

    /// Merge two streams
    let merge (PushStream s1) (PushStream s2) : PushStream<'T> =
        PushStream (fun observer ->
            let completed = ref 0
            let checkComplete () =
                if Interlocked.Increment completed = 2 then
                    observer.OnCompleted()
            let createObs () = { new IStreamObserver<'T> with
                member _.OnNext x = observer.OnNext x
                member _.OnError e = observer.OnError e
                member _.OnCompleted() = checkComplete()
            }
            let sub1 = s1 (createObs())
            let sub2 = s2 (createObs())
            { new ISubscription with
                member _.Dispose() = sub1.Dispose(); sub2.Dispose()
            }
        )

    /// Scan / running fold
    let scan (folder: 'State -> 'T -> 'State) (initial: 'State) (PushStream subscribe') : PushStream<'State> =
        PushStream (fun observer ->
            let state = ref initial
            observer.OnNext initial
            subscribe' { new IStreamObserver<'T> with
                member _.OnNext x =
                    state.Value <- folder state.Value x
                    observer.OnNext state.Value
                member _.OnError e = observer.OnError e
                member _.OnCompleted() = observer.OnCompleted()
            }
        )

    /// Buffer by count
    let buffer (size: int) (PushStream subscribe') : PushStream<'T list> =
        PushStream (fun observer ->
            let buffer = ResizeArray<'T>()
            subscribe' { new IStreamObserver<'T> with
                member _.OnNext x =
                    buffer.Add(x)
                    if buffer.Count >= size then
                        observer.OnNext (buffer |> Seq.toList)
                        buffer.Clear()
                member _.OnError e = observer.OnError e
                member _.OnCompleted() =
                    if buffer.Count > 0 then
                        observer.OnNext (buffer |> Seq.toList)
                    observer.OnCompleted()
            }
        )

    /// Throttle - emit at most one per interval
    let throttle (interval: TimeSpan) (PushStream subscribe') : PushStream<'T> =
        PushStream (fun observer ->
            let lastEmit = ref DateTime.MinValue
            subscribe' { new IStreamObserver<'T> with
                member _.OnNext x =
                    let now = DateTime.UtcNow
                    if now - lastEmit.Value >= interval then
                        lastEmit.Value <- now
                        observer.OnNext x
                member _.OnError e = observer.OnError e
                member _.OnCompleted() = observer.OnCompleted()
            }
        )

// ============================================================================
// SINKS AND SOURCES
// ============================================================================

/// Source - produces values
type Source<'T> = {
    Pull: unit -> Async<'T option>
    Close: unit -> unit
}

/// Sink - consumes values
type Sink<'T, 'R> = {
    Push: 'T -> Async<unit>
    Complete: unit -> Async<'R>
}

module Source =
    /// Create from async seq
    let ofAsyncSeq (xs: AsyncSeq<'T>) : Source<'T> =
        let current = ref xs
        {
            Pull = fun () -> async {
                let! node = AsyncSeq.uncons current.Value
                match node with
                | AsyncSeqNil -> return None
                | AsyncSeqCons (h, t) ->
                    current.Value <- t
                    return Some h
            }
            Close = fun () -> ()
        }

    /// Create from sequence
    let ofSeq (xs: 'T seq) : Source<'T> =
        ofAsyncSeq (AsyncSeq.ofSeq xs)

    /// Infinite source from generator
    let generate (f: unit -> 'T) : Source<'T> =
        {
            Pull = fun () -> async { return Some (f ()) }
            Close = fun () -> ()
        }

    /// Map over source
    let map (f: 'T -> 'U) (source: Source<'T>) : Source<'U> =
        {
            Pull = fun () -> async {
                let! item = source.Pull()
                return item |> Option.map f
            }
            Close = source.Close
        }

module Sink =
    /// Collect to list
    let toList<'T> () : Sink<'T, 'T list> =
        let items = ResizeArray<'T>()
        {
            Push = fun x -> async { items.Add(x) }
            Complete = fun () -> async { return items |> Seq.toList }
        }

    /// Fold sink
    let fold (folder: 'State -> 'T -> 'State) (initial: 'State) : Sink<'T, 'State> =
        let state = ref initial
        {
            Push = fun x -> async { state.Value <- folder state.Value x }
            Complete = fun () -> async { return state.Value }
        }

    /// Count sink
    let count<'T> () : Sink<'T, int> =
        fold (fun acc _ -> acc + 1) 0

    /// Ignore sink
    let ignore<'T> () : Sink<'T, unit> =
        {
            Push = fun _ -> async { () }
            Complete = fun () -> async { () }
        }

    /// Contramap over sink
    let contramap (f: 'U -> 'T) (sink: Sink<'T, 'R>) : Sink<'U, 'R> =
        {
            Push = fun x -> sink.Push (f x)
            Complete = sink.Complete
        }

    /// Connect source to sink
    let pipe (source: Source<'T>) (sink: Sink<'T, 'R>) : Async<'R> =
        async {
            let rec loop () = async {
                let! item = source.Pull()
                match item with
                | None ->
                    source.Close()
                    return! sink.Complete()
                | Some x ->
                    do! sink.Push x
                    return! loop ()
            }
            return! loop ()
        }

// ============================================================================
// WINDOWING
// ============================================================================

/// Sliding window over async sequence
module Windowing =
    /// Sliding window of fixed size
    let sliding (size: int) (xs: AsyncSeq<'T>) : AsyncSeq<'T list> =
        let rec go window (AsyncSeq getNext) =
            AsyncSeq (fun () -> async {
                let! node = getNext ()
                match node with
                | AsyncSeqNil ->
                    if List.isEmpty window then return AsyncSeqNil
                    else return AsyncSeqCons (window, AsyncSeq.empty)
                | AsyncSeqCons (h, t) ->
                    let newWindow =
                        if List.length window < size then window @ [h]
                        else (List.tail window) @ [h]
                    if List.length newWindow = size then
                        return AsyncSeqCons (newWindow, go newWindow t)
                    else
                        return! AsyncSeq.uncons (go newWindow t)
            })
        go [] xs

    /// Tumbling window (non-overlapping)
    let tumbling (size: int) (xs: AsyncSeq<'T>) : AsyncSeq<'T list> =
        AsyncSeq.chunkBySize size xs

    /// Session window - group by gaps in time
    let session (gap: TimeSpan) (xs: AsyncSeq<DateTimeOffset * 'T>) : AsyncSeq<(DateTimeOffset * 'T) list> =
        let rec go window lastTime (AsyncSeq getNext) =
            AsyncSeq (fun () -> async {
                let! node = getNext ()
                match node with
                | AsyncSeqNil ->
                    if List.isEmpty window then return AsyncSeqNil
                    else return AsyncSeqCons (List.rev window, AsyncSeq.empty)
                | AsyncSeqCons ((time, value) as item, t) ->
                    match lastTime with
                    | None ->
                        return! AsyncSeq.uncons (go [item] (Some time) t)
                    | Some last when time - last > gap ->
                        // Gap detected - emit window and start new one
                        return AsyncSeqCons (List.rev window, go [item] (Some time) t)
                    | Some _ ->
                        return! AsyncSeq.uncons (go (item :: window) (Some time) t)
            })
        go [] None xs

