/// CEPAF Telemetry Streams Module
/// Async streaming abstractions for real-time telemetry processing.
///
/// WHAT: Telemetry streams, windowing, aggregation, pub/sub integration
/// WHY: Handle 1000+ msg/sec with backpressure and memory efficiency
/// CONSTRAINTS:
///   - SC-STREAM-001: Streams must support backpressure signaling
///   - SC-STREAM-002: Windows must be time-bounded (max 60 seconds)
///   - SC-STREAM-003: Aggregations must be incremental (no full recompute)
///   - SC-STREAM-004: Subscriptions must be cancellable
///
/// STAMP Compliance: SC-STREAM-001 to SC-STREAM-010
/// Version: 1.0.0
namespace Cepaf.Cockpit

open System
open System.Threading
open Cepaf.Cockpit.Domain

// ============================================================================
// ASYNC HELPERS (DEFINED FIRST)
// ============================================================================

module private AsyncHelpers =
    let map f a = async {
        let! x = a
        return f x
    }

// ============================================================================
// TELEMETRY TYPES (DEFINED FIRST)
// ============================================================================

/// Telemetry message types
type TelemetryMsg =
    | NodeMetrics of NodeId * MeshNodeMetrics
    | AlarmEvent of Alarm
    | CommandAck of CommandId * bool
    | ConnectionStatus of NodeId * ConnStatus
    | AiInsightMsg of AiInsight

and MeshNodeMetrics = {
    Cpu: float
    Memory: float
    NetworkLatency: float
    Battery: float option
    Timestamp: DateTime
}

/// Processed telemetry result
type ProcessedTelemetry = {
    NodeId: NodeId
    Metrics: MeshNodeMetrics
    CpuTrend: Trend
    MemoryTrend: Trend
    HealthScore: float
    IsAnomaly: bool
    Timestamp: DateTime
}

/// Subscription handle for cancellable streams
type TelemetrySubscription = {
    Id: string
    Cancel: unit -> unit
    IsActive: unit -> bool
}

// ============================================================================
// TELEMETRY STREAM - Core Streaming Type
// ============================================================================

/// Telemetry stream - lazy, pull-based async stream
type TelStream<'T> = TelStream of (CancellationToken -> Async<TelNode<'T>>)

and TelNode<'T> =
    | TelEnd                                // Stream completed
    | TelError of exn                       // Stream errored
    | TelNext of value: 'T * next: TelStream<'T>  // Value with continuation

module TelStream =

    // ========================================================================
    // CONSTRUCTION
    // ========================================================================

    /// Create empty stream
    let empty<'T> : TelStream<'T> =
        TelStream (fun _ -> async { return TelEnd })

    /// Create stream with error
    let error (ex: exn) : TelStream<'T> =
        TelStream (fun _ -> async { return TelError ex })

    /// Create singleton stream
    let singleton (x: 'T) : TelStream<'T> =
        TelStream (fun _ -> async { return TelNext (x, empty) })

    /// Create from value with continuation
    let cons (x: 'T) (xs: TelStream<'T>) : TelStream<'T> =
        TelStream (fun _ -> async { return TelNext (x, xs) })

    /// Unfold - create stream from generator
    let unfold (gen: 'State -> Async<('T * 'State) option>) (init: 'State) : TelStream<'T> =
        let rec go state =
            TelStream (fun ct -> async {
                if ct.IsCancellationRequested then return TelEnd
                else
                    let! result = gen state
                    match result with
                    | None -> return TelEnd
                    | Some (v, s') -> return TelNext (v, go s')
            })
        go init

    /// Create from list
    let ofList (xs: 'T list) : TelStream<'T> =
        let rec go = function
            | [] -> empty
            | h :: t -> cons h (go t)
        go xs

    /// Create from seq
    let ofSeq (xs: seq<'T>) : TelStream<'T> =
        xs |> Seq.toList |> ofList

    /// Create infinite stream that repeats value
    let repeat (x: 'T) : TelStream<'T> =
        let rec go () = cons x (go ())
        go ()

    /// Create stream from async generator with intervals
    let interval (ms: int) : TelStream<DateTime> =
        unfold (fun _ -> async {
            do! Async.Sleep ms
            return Some (DateTime.UtcNow, ())
        }) ()

    // ========================================================================
    // CONSUMPTION
    // ========================================================================

    /// Pull next value from stream
    let pull (ct: CancellationToken) (TelStream f) : Async<TelNode<'T>> = f ct

    /// Iterate over stream
    let iter (action: 'T -> unit) (ct: CancellationToken) (stream: TelStream<'T>) : Async<unit> =
        let rec go (TelStream f) = async {
            if ct.IsCancellationRequested then return ()
            else
                let! node = f ct
                match node with
                | TelEnd -> return ()
                | TelError _ -> return ()
                | TelNext (v, next) ->
                    action v
                    return! go next
        }
        go stream

    /// Iterate with async action
    let iterAsync (action: 'T -> Async<unit>) (ct: CancellationToken) (stream: TelStream<'T>) : Async<unit> =
        let rec go (TelStream f) = async {
            if ct.IsCancellationRequested then return ()
            else
                let! node = f ct
                match node with
                | TelEnd -> return ()
                | TelError _ -> return ()
                | TelNext (v, next) ->
                    do! action v
                    return! go next
        }
        go stream

    /// Fold stream to single value
    let fold (folder: 'State -> 'T -> 'State) (init: 'State) (ct: CancellationToken) (stream: TelStream<'T>) : Async<'State> =
        let rec go acc (TelStream f) = async {
            if ct.IsCancellationRequested then return acc
            else
                let! node = f ct
                match node with
                | TelEnd -> return acc
                | TelError _ -> return acc
                | TelNext (v, next) -> return! go (folder acc v) next
        }
        go init stream

    /// Collect stream to list
    let toList (ct: CancellationToken) (stream: TelStream<'T>) : Async<'T list> =
        fold (fun acc x -> x :: acc) [] ct stream
        |> AsyncHelpers.map List.rev

    // ========================================================================
    // TRANSFORMATION
    // ========================================================================

    /// Map over stream
    let map (f: 'T -> 'U) (stream: TelStream<'T>) : TelStream<'U> =
        let rec go (TelStream getNext) =
            TelStream (fun ct -> async {
                let! node = getNext ct
                match node with
                | TelEnd -> return TelEnd
                | TelError ex -> return TelError ex
                | TelNext (v, next) -> return TelNext (f v, go next)
            })
        go stream

    /// Async map
    let mapAsync (f: 'T -> Async<'U>) (stream: TelStream<'T>) : TelStream<'U> =
        let rec go (TelStream getNext) =
            TelStream (fun ct -> async {
                let! node = getNext ct
                match node with
                | TelEnd -> return TelEnd
                | TelError ex -> return TelError ex
                | TelNext (v, next) ->
                    let! mapped = f v
                    return TelNext (mapped, go next)
            })
        go stream

    /// Filter stream
    let filter (pred: 'T -> bool) (stream: TelStream<'T>) : TelStream<'T> =
        let rec go (TelStream getNext) =
            TelStream (fun ct -> async {
                let! node = getNext ct
                match node with
                | TelEnd -> return TelEnd
                | TelError ex -> return TelError ex
                | TelNext (v, next) ->
                    if pred v then return TelNext (v, go next)
                    else
                        let (TelStream f) = go next
                        return! f ct
            })
        go stream

    /// FlatMap (bind)
    let flatMap (f: 'T -> TelStream<'U>) (stream: TelStream<'T>) : TelStream<'U> =
        let rec outer (TelStream getNext) =
            TelStream (fun ct -> async {
                let! node = getNext ct
                match node with
                | TelEnd -> return TelEnd
                | TelError ex -> return TelError ex
                | TelNext (v, nextOuter) ->
                    let inner = f v
                    return! concat inner (outer nextOuter) ct
            })
        and concat (TelStream f1) rest ct = async {
            let! node = f1 ct
            match node with
            | TelEnd ->
                let (TelStream f) = rest
                return! f ct
            | TelError ex -> return TelError ex
            | TelNext (v, next) -> return TelNext (v, TelStream (fun c -> concat next rest c))
        }
        outer stream

    /// Scan - fold with intermediate values
    let scan (folder: 'State -> 'T -> 'State) (init: 'State) (stream: TelStream<'T>) : TelStream<'State> =
        let rec go state (TelStream getNext) =
            TelStream (fun ct -> async {
                let! node = getNext ct
                match node with
                | TelEnd -> return TelEnd
                | TelError ex -> return TelError ex
                | TelNext (v, next) ->
                    let newState = folder state v
                    return TelNext (newState, go newState next)
            })
        cons init (go init stream)

    /// Take first n elements
    let take (n: int) (stream: TelStream<'T>) : TelStream<'T> =
        let rec go count (TelStream getNext) =
            if count <= 0 then empty
            else TelStream (fun ct -> async {
                let! node = getNext ct
                match node with
                | TelEnd -> return TelEnd
                | TelError ex -> return TelError ex
                | TelNext (v, next) -> return TelNext (v, go (count - 1) next)
            })
        go n stream

    /// Skip first n elements
    let skip (n: int) (stream: TelStream<'T>) : TelStream<'T> =
        let rec go count (TelStream getNext) =
            TelStream (fun ct -> async {
                let! node = getNext ct
                match node with
                | TelEnd -> return TelEnd
                | TelError ex -> return TelError ex
                | TelNext (v, next) ->
                    if count > 0 then
                        let (TelStream f) = go (count - 1) next
                        return! f ct
                    else return TelNext (v, go 0 next)
            })
        go n stream

    /// Distinct consecutive elements
    let distinctBy (f: 'T -> 'Key) (stream: TelStream<'T>) : TelStream<'T> =
        let rec go lastKey (TelStream getNext) =
            TelStream (fun ct -> async {
                let! node = getNext ct
                match node with
                | TelEnd -> return TelEnd
                | TelError ex -> return TelError ex
                | TelNext (v, next) ->
                    let key = f v
                    match lastKey with
                    | Some k when k = key ->
                        let (TelStream f) = go lastKey next
                        return! f ct
                    | _ -> return TelNext (v, go (Some key) next)
            })
        go None stream

    // ========================================================================
    // WINDOWING (SC-STREAM-002)
    // ========================================================================

    /// Tumbling window - non-overlapping fixed-size windows
    let tumblingWindow (size: int) (stream: TelStream<'T>) : TelStream<'T list> =
        let rec go buffer (TelStream getNext) =
            TelStream (fun ct -> async {
                let! node = getNext ct
                match node with
                | TelEnd ->
                    if List.isEmpty buffer then return TelEnd
                    else return TelNext (List.rev buffer, empty)
                | TelError ex -> return TelError ex
                | TelNext (v, next) ->
                    let newBuffer = v :: buffer
                    if List.length newBuffer >= size then
                        return TelNext (List.rev newBuffer, go [] next)
                    else
                        let (TelStream f) = go newBuffer next
                        return! f ct
            })
        go [] stream

    /// Sliding window - overlapping windows
    let slidingWindow (size: int) (stream: TelStream<'T>) : TelStream<'T list> =
        let rec go buffer (TelStream getNext) =
            TelStream (fun ct -> async {
                let! node = getNext ct
                match node with
                | TelEnd ->
                    if List.length buffer >= size then return TelNext (buffer |> List.truncate size, empty)
                    else return TelEnd
                | TelError ex -> return TelError ex
                | TelNext (v, next) ->
                    let newBuffer = buffer @ [v] |> List.rev |> List.truncate size |> List.rev
                    if List.length newBuffer >= size then
                        return TelNext (newBuffer, go newBuffer next)
                    else
                        let (TelStream f) = go newBuffer next
                        return! f ct
            })
        go [] stream

    /// Time-based window (SC-STREAM-002: max 60s)
    let timeWindow (durationMs: int) (stream: TelStream<'T>) : TelStream<'T list * DateTime> =
        let maxDuration = min durationMs 60000  // Enforce max 60s
        let rec go buffer (startTime: DateTime) (TelStream getNext) =
            TelStream (fun ct -> async {
                let elapsed = (DateTime.UtcNow - startTime).TotalMilliseconds
                if elapsed >= float maxDuration then
                    return TelNext ((List.rev buffer, startTime), go [] DateTime.UtcNow (TelStream getNext))
                else
                    let! node = getNext ct
                    match node with
                    | TelEnd ->
                        if List.isEmpty buffer then return TelEnd
                        else return TelNext ((List.rev buffer, startTime), empty)
                    | TelError ex -> return TelError ex
                    | TelNext (v, next) ->
                        let (TelStream f) = go (v :: buffer) startTime next
                        return! f ct
            })
        go [] DateTime.UtcNow stream

    // ========================================================================
    // AGGREGATION (SC-STREAM-003: Incremental)
    // ========================================================================

    /// Running sum (incremental)
    let runningSum (stream: TelStream<float>) : TelStream<float> =
        scan (+) 0.0 stream

    /// Running average (incremental using Welford's algorithm)
    let runningAverage (stream: TelStream<float>) : TelStream<float> =
        scan (fun (count, mean) x ->
            let n = count + 1.0
            let delta = x - mean
            let newMean = mean + delta / n
            (n, newMean)
        ) (0.0, 0.0) stream
        |> map snd

    /// Running min
    let runningMin (stream: TelStream<float>) : TelStream<float> =
        scan (fun acc x -> min acc x) System.Double.MaxValue stream

    /// Running max
    let runningMax (stream: TelStream<float>) : TelStream<float> =
        scan (fun acc x -> max acc x) System.Double.MinValue stream

    /// Running variance (Welford's online algorithm)
    let runningVariance (stream: TelStream<float>) : TelStream<float> =
        scan (fun (count, mean, m2) x ->
            let n = count + 1.0
            let delta = x - mean
            let newMean = mean + delta / n
            let delta2 = x - newMean
            let newM2 = m2 + delta * delta2
            (n, newMean, newM2)
        ) (0.0, 0.0, 0.0) stream
        |> map (fun (n, _, m2) -> if n < 2.0 then 0.0 else m2 / (n - 1.0))

    // ========================================================================
    // COMBINATION
    // ========================================================================

    /// Merge two streams
    let merge (s1: TelStream<'T>) (s2: TelStream<'T>) : TelStream<'T> =
        // Simple interleaving - real impl would use actual concurrency
        let rec go (TelStream f1) (TelStream f2) =
            TelStream (fun ct -> async {
                let! node1 = f1 ct
                match node1 with
                | TelEnd ->
                    let! node2 = f2 ct
                    return node2
                | TelError ex -> return TelError ex
                | TelNext (v, next1) ->
                    return TelNext (v, go (TelStream f2) next1)
            })
        go s1 s2

    /// Zip two streams
    let zip (s1: TelStream<'A>) (s2: TelStream<'B>) : TelStream<'A * 'B> =
        let rec go (TelStream f1) (TelStream f2) =
            TelStream (fun ct -> async {
                let! node1 = f1 ct
                match node1 with
                | TelEnd -> return TelEnd
                | TelError ex -> return TelError ex
                | TelNext (v1, next1) ->
                    let! node2 = f2 ct
                    match node2 with
                    | TelEnd -> return TelEnd
                    | TelError ex -> return TelError ex
                    | TelNext (v2, next2) ->
                        return TelNext ((v1, v2), go next1 next2)
            })
        go s1 s2

    // ========================================================================
    // RATE CONTROL (SC-STREAM-001: Backpressure)
    // ========================================================================

    /// Throttle to max rate (items per second)
    let throttle (itemsPerSecond: int) (stream: TelStream<'T>) : TelStream<'T> =
        let delayMs = 1000 / max 1 itemsPerSecond
        let rec go (TelStream getNext) =
            TelStream (fun ct -> async {
                let! node = getNext ct
                match node with
                | TelEnd -> return TelEnd
                | TelError ex -> return TelError ex
                | TelNext (v, next) ->
                    do! Async.Sleep delayMs
                    return TelNext (v, go next)
            })
        go stream

    /// Debounce - emit only after quiet period
    let debounce (quietMs: int) (stream: TelStream<'T>) : TelStream<'T> =
        let rec go lastValue (lastTime: DateTime) (TelStream getNext) =
            TelStream (fun ct -> async {
                let! node = getNext ct
                match node with
                | TelEnd ->
                    match lastValue with
                    | None -> return TelEnd
                    | Some v -> return TelNext (v, empty)
                | TelError ex -> return TelError ex
                | TelNext (v, next) ->
                    let now = DateTime.UtcNow
                    let elapsed = (now - lastTime).TotalMilliseconds
                    if elapsed >= float quietMs then
                        return TelNext (v, go None now next)
                    else
                        let (TelStream f) = go (Some v) now next
                        return! f ct
            })
        go None DateTime.UtcNow stream

    /// Sample at intervals
    let sample (intervalMs: int) (stream: TelStream<'T>) : TelStream<'T> =
        let rec go (lastEmit: DateTime) lastValue (TelStream getNext) =
            TelStream (fun ct -> async {
                let! node = getNext ct
                match node with
                | TelEnd ->
                    match lastValue with
                    | None -> return TelEnd
                    | Some v -> return TelNext (v, empty)
                | TelError ex -> return TelError ex
                | TelNext (v, next) ->
                    let now = DateTime.UtcNow
                    let elapsed = (now - lastEmit).TotalMilliseconds
                    if elapsed >= float intervalMs then
                        return TelNext (v, go now None next)
                    else
                        let (TelStream f) = go lastEmit (Some v) next
                        return! f ct
            })
        go DateTime.UtcNow None stream

// ============================================================================
// TELEMETRY-SPECIFIC STREAMS
// ============================================================================

module TelemetryPipeline =
    open TelStream

    /// Create telemetry stream from message source
    let fromSource (source: unit -> Async<TelemetryMsg option>) : TelStream<TelemetryMsg> =
        unfold (fun () -> async {
            let! msg = source ()
            return msg |> Option.map (fun m -> (m, ()))
        }) ()

    /// Filter to node metrics only
    let nodeMetricsOnly : TelStream<TelemetryMsg> -> TelStream<NodeId * MeshNodeMetrics> =
        filter (function NodeMetrics _ -> true | _ -> false)
        >> map (function NodeMetrics (id, m) -> (id, m) | _ -> failwith "impossible")

    /// Filter to alarms only
    let alarmsOnly : TelStream<TelemetryMsg> -> TelStream<Alarm> =
        filter (function AlarmEvent _ -> true | _ -> false)
        >> map (function AlarmEvent a -> a | _ -> failwith "impossible")

    /// Extract metrics for specific node
    let metricsForNode (nodeId: NodeId) : TelStream<TelemetryMsg> -> TelStream<MeshNodeMetrics> =
        nodeMetricsOnly
        >> filter (fun (id, _) -> id = nodeId)
        >> map snd

    /// Compute health score stream from metrics
    let healthScoreStream : TelStream<MeshNodeMetrics> -> TelStream<float> =
        map (fun m ->
            let cpuHealth = 100.0 - m.Cpu
            let memHealth = 100.0 - m.Memory
            let latencyHealth =
                if m.NetworkLatency < 10.0 then 100.0
                elif m.NetworkLatency < 50.0 then 80.0
                elif m.NetworkLatency < 100.0 then 60.0
                else 40.0
            (cpuHealth * 0.35 + memHealth * 0.35 + latencyHealth * 0.30)
        )

    /// Anomaly detection stream
    let anomalyStream (threshold: float) : TelStream<MeshNodeMetrics> -> TelStream<MeshNodeMetrics * bool> =
        slidingWindow 10
        >> map (fun window ->
            let latest = List.head window
            let cpuValues = window |> List.map (fun m -> m.Cpu)
            let mean = List.average cpuValues
            let variance = cpuValues |> List.map (fun x -> (x - mean) ** 2.0) |> List.average
            let stdDev = sqrt variance
            let isAnomaly = abs (latest.Cpu - mean) > threshold * stdDev
            (latest, isAnomaly)
        )

    /// Trend analysis stream
    let trendStream : TelStream<MeshNodeMetrics> -> TelStream<MeshNodeMetrics * Trend> =
        slidingWindow 5
        >> map (fun window ->
            let latest = List.head window
            let values = window |> List.map (fun m -> m.Cpu)
            let n = List.length values |> float
            if n < 2.0 then (latest, Stable)
            else
                let xs = [0.0 .. n - 1.0]
                let meanX = (n - 1.0) / 2.0
                let meanY = List.average values
                let slope =
                    let num = List.zip xs values |> List.sumBy (fun (x, y) -> (x - meanX) * (y - meanY))
                    let den = xs |> List.sumBy (fun x -> (x - meanX) ** 2.0)
                    if abs den < 1e-10 then 0.0 else num / den
                let trend =
                    if slope > 5.0 then RisingFast
                    elif slope > 1.0 then Rising
                    elif slope < -5.0 then FallingFast
                    elif slope < -1.0 then Falling
                    else Stable
                (latest, trend)
        )

    /// Complete telemetry processing pipeline
    let processingPipeline (nodeId: NodeId) (ct: CancellationToken) (source: TelStream<TelemetryMsg>) : TelStream<ProcessedTelemetry> =
        source
        |> metricsForNode nodeId
        |> slidingWindow 10
        |> map (fun window ->
            let latest = List.head window
            let cpuValues = window |> List.map (fun m -> m.Cpu)
            let memValues = window |> List.map (fun m -> m.Memory)

            // Calculate trend
            let slope values =
                let n = List.length values |> float
                if n < 2.0 then 0.0
                else
                    let xs = [0.0 .. n - 1.0]
                    let meanX = (n - 1.0) / 2.0
                    let meanY = List.average values
                    let num = List.zip xs values |> List.sumBy (fun (x, y) -> (x - meanX) * (y - meanY))
                    let den = xs |> List.sumBy (fun x -> (x - meanX) ** 2.0)
                    if abs den < 1e-10 then 0.0 else num / den

            let cpuSlope = slope cpuValues
            let cpuTrend =
                if cpuSlope > 5.0 then RisingFast
                elif cpuSlope > 1.0 then Rising
                elif cpuSlope < -5.0 then FallingFast
                elif cpuSlope < -1.0 then Falling
                else Stable

            // Calculate health
            let health = 100.0 - (latest.Cpu * 0.4 + latest.Memory * 0.4 + latest.NetworkLatency * 0.002 * 20.0)

            // Anomaly detection (z-score)
            let mean = List.average cpuValues
            let variance = cpuValues |> List.map (fun x -> (x - mean) ** 2.0) |> List.average
            let stdDev = sqrt variance
            let isAnomaly = stdDev > 0.1 && abs (latest.Cpu - mean) > 2.5 * stdDev

            {
                NodeId = nodeId
                Metrics = latest
                CpuTrend = cpuTrend
                MemoryTrend = Stable  // Simplified
                HealthScore = max 0.0 (min 100.0 health)
                IsAnomaly = isAnomaly
                Timestamp = latest.Timestamp
            }
        )

// ============================================================================
// SUBSCRIPTION MANAGER (SC-STREAM-004: Cancellable)
// ============================================================================

module SubscriptionManager =
    /// Create a cancellable subscription
    let subscribe
        (stream: TelStream<'T>)
        (handler: 'T -> unit)
        : TelemetrySubscription =

        let cts = new CancellationTokenSource()
        let id = Guid.NewGuid().ToString("N").[..7]

        // Start processing in background
        Async.Start(
            TelStream.iter handler cts.Token stream,
            cts.Token
        )

        {
            Id = id
            Cancel = fun () -> cts.Cancel()
            IsActive = fun () -> not cts.IsCancellationRequested
        }

    /// Subscribe with async handler
    let subscribeAsync
        (stream: TelStream<'T>)
        (handler: 'T -> Async<unit>)
        : TelemetrySubscription =

        let cts = new CancellationTokenSource()
        let id = Guid.NewGuid().ToString("N").[..7]

        Async.Start(
            TelStream.iterAsync handler cts.Token stream,
            cts.Token
        )

        {
            Id = id
            Cancel = fun () -> cts.Cancel()
            IsActive = fun () -> not cts.IsCancellationRequested
        }
