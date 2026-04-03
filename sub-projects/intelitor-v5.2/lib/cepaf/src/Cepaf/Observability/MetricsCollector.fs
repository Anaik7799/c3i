namespace Cepaf.Observability

open System
open System.Collections.Concurrent
open System.Threading
open System.Diagnostics

/// Metrics collector for Quadplex observability.
/// Provides counter, gauge, histogram, and timer support with aggregation.
/// STAMP Compliance: SC-OBS-071 (4 OTEL modules - metrics component)
module MetricsCollector =

    /// Metric type enumeration
    type MetricType =
        | Counter
        | Gauge
        | Histogram

    /// Single metric data point
    type MetricPoint = {
        Name: string
        Value: float
        Tags: Map<string, string>
        Timestamp: DateTimeOffset
        MetricType: MetricType
    }

    /// Histogram bucket for distribution tracking
    type HistogramBucket = {
        UpperBound: float
        mutable Count: int64
    }

    /// Histogram state for tracking distributions
    type HistogramState = {
        Name: string
        Tags: Map<string, string>
        Buckets: HistogramBucket[]
        mutable Sum: float
        mutable Count: int64
        mutable Min: float
        mutable Max: float
    }

    /// Metric callback for external logging
    type MetricCallback = string -> float -> string -> Map<string, string> -> unit

    /// Collector state
    type MetricsCollectorState = {
        Counters: ConcurrentDictionary<string, int64>
        Gauges: ConcurrentDictionary<string, float>
        Histograms: ConcurrentDictionary<string, HistogramState>
        Buffer: ConcurrentQueue<MetricPoint>
        mutable MetricCallback: MetricCallback option
        Config: QuadplexConfig
        DefaultBuckets: float[]
        mutable LastFlush: DateTimeOffset
        FlushIntervalMs: int
        LockObj: obj
    }

    /// Default histogram buckets (latency-focused)
    let defaultBuckets = [| 1.0; 5.0; 10.0; 25.0; 50.0; 100.0; 250.0; 500.0; 1000.0; 2500.0; 5000.0; 10000.0 |]

    /// Create metrics collector
    let create (config: QuadplexConfig) : MetricsCollectorState =
        {
            Counters = ConcurrentDictionary<string, int64>()
            Gauges = ConcurrentDictionary<string, float>()
            Histograms = ConcurrentDictionary<string, HistogramState>()
            Buffer = ConcurrentQueue<MetricPoint>()
            MetricCallback = None
            Config = config
            DefaultBuckets = defaultBuckets
            LastFlush = DateTimeOffset.UtcNow
            FlushIntervalMs = config.FlushIntervalMs
            LockObj = obj()
        }

    /// Set metric callback for logging
    let setMetricCallback (state: MetricsCollectorState) (callback: MetricCallback) =
        state.MetricCallback <- Some callback

    /// Build metric key from name and tags
    let private buildKey (name: string) (tags: Map<string, string>) =
        let tagStr = tags |> Map.toSeq |> Seq.map (fun (k, v) -> sprintf "%s=%s" k v) |> String.concat ","
        if String.IsNullOrEmpty(tagStr) then name else sprintf "%s:%s" name tagStr

    /// Record histogram value (internal implementation)
    let private recordHistogramInternal (state: MetricsCollectorState) (name: string) (value: float) (tags: Map<string, string>) =
        let key = sprintf "%s:%s" name (tags |> Map.toSeq |> Seq.map (fun (k, v) -> sprintf "%s=%s" k v) |> String.concat ",")

        let histogram =
            state.Histograms.GetOrAdd(key, fun _ ->
                {
                    Name = name
                    Tags = tags
                    Buckets = state.DefaultBuckets |> Array.map (fun ub -> { UpperBound = ub; Count = 0L })
                    Sum = 0.0
                    Count = 0L
                    Min = Double.MaxValue
                    Max = Double.MinValue
                }
            )

        lock state.LockObj (fun () ->
            histogram.Sum <- histogram.Sum + value
            histogram.Count <- histogram.Count + 1L
            histogram.Min <- min histogram.Min value
            histogram.Max <- max histogram.Max value

            for bucket in histogram.Buckets do
                if value <= bucket.UpperBound then
                    Interlocked.Increment(&bucket.Count) |> ignore
        )

        let point = {
            Name = name
            Value = value
            Tags = tags
            Timestamp = DateTimeOffset.UtcNow
            MetricType = Histogram
        }
        state.Buffer.Enqueue(point)

    // ========== Counter Operations ==========

    /// Increment counter by value
    let incrementCounter (state: MetricsCollectorState) (name: string) (value: int64) (tags: Map<string, string>) =
        let key = buildKey name tags
        state.Counters.AddOrUpdate(key, value, fun _ existing -> existing + value) |> ignore

        let point = {
            Name = name
            Value = float value
            Tags = tags
            Timestamp = DateTimeOffset.UtcNow
            MetricType = Counter
        }
        state.Buffer.Enqueue(point)

        // Emit via callback if set
        match state.MetricCallback with
        | Some callback -> callback name (float value) "count" tags
        | None -> ()

    /// Increment counter by 1
    let incrementCounterByOne (state: MetricsCollectorState) (name: string) (tags: Map<string, string>) =
        incrementCounter state name 1L tags

    /// Get counter value
    let getCounter (state: MetricsCollectorState) (name: string) (tags: Map<string, string>) =
        let key = buildKey name tags
        match state.Counters.TryGetValue(key) with
        | true, value -> value
        | false, _ -> 0L

    // ========== Gauge Operations ==========

    /// Set gauge value
    let setGauge (state: MetricsCollectorState) (name: string) (value: float) (tags: Map<string, string>) =
        let key = buildKey name tags
        state.Gauges.AddOrUpdate(key, value, fun _ _ -> value) |> ignore

        let point = {
            Name = name
            Value = value
            Tags = tags
            Timestamp = DateTimeOffset.UtcNow
            MetricType = Gauge
        }
        state.Buffer.Enqueue(point)

        match state.MetricCallback with
        | Some callback -> callback name value "" tags
        | None -> ()

    /// Get gauge value
    let getGauge (state: MetricsCollectorState) (name: string) (tags: Map<string, string>) =
        let key = buildKey name tags
        match state.Gauges.TryGetValue(key) with
        | true, value -> value
        | false, _ -> 0.0

    // ========== Histogram Operations ==========

    /// Record histogram value
    let recordHistogram (state: MetricsCollectorState) (name: string) (value: float) (tags: Map<string, string>) =
        recordHistogramInternal state name value tags

        match state.MetricCallback with
        | Some callback -> callback name value "ms" tags
        | None -> ()

    /// Get histogram statistics
    let getHistogramStats (state: MetricsCollectorState) (name: string) (tags: Map<string, string>) =
        let key = buildKey name tags
        match state.Histograms.TryGetValue(key) with
        | true, hist ->
            Some {|
                Count = hist.Count
                Sum = hist.Sum
                Min = if hist.Count > 0L then hist.Min else 0.0
                Max = if hist.Count > 0L then hist.Max else 0.0
                Avg = if hist.Count > 0L then hist.Sum / float hist.Count else 0.0
                Buckets = hist.Buckets |> Array.map (fun b -> (b.UpperBound, b.Count))
            |}
        | false, _ -> None

    /// Calculate percentile from histogram
    let getPercentile (state: MetricsCollectorState) (name: string) (tags: Map<string, string>) (percentile: float) =
        let key = buildKey name tags
        match state.Histograms.TryGetValue(key) with
        | true, hist when hist.Count > 0L ->
            let targetCount = int64 (float hist.Count * percentile / 100.0)
            let mutable cumulative = 0L
            let mutable result = hist.Max

            for bucket in hist.Buckets do
                cumulative <- cumulative + bucket.Count
                if cumulative >= targetCount && result = hist.Max then
                    result <- bucket.UpperBound

            result
        | _ -> 0.0

    // ========== Timer Operations ==========

    /// Timer handle for automatic duration recording
    type TimerHandle(state: MetricsCollectorState, name: string, tags: Map<string, string>) =
        let stopwatch = Stopwatch.StartNew()

        interface IDisposable with
            member _.Dispose() =
                stopwatch.Stop()
                let durationMs = float stopwatch.ElapsedMilliseconds
                recordHistogramInternal state name durationMs tags

    /// Start a timer that records duration on dispose
    let startTimer (state: MetricsCollectorState) (name: string) (tags: Map<string, string>) : IDisposable =
        new TimerHandle(state, name, tags)

    /// Time a function and return its result
    let time (state: MetricsCollectorState) (name: string) (tags: Map<string, string>) (f: unit -> 'a) : 'a =
        let sw = Stopwatch.StartNew()
        try
            f()
        finally
            sw.Stop()
            recordHistogram state name (float sw.ElapsedMilliseconds) tags

    /// Time an async computation
    let timeAsync (state: MetricsCollectorState) (name: string) (tags: Map<string, string>) (computation: Async<'a>) : Async<'a> = async {
        let sw = Stopwatch.StartNew()
        try
            return! computation
        finally
            sw.Stop()
            recordHistogram state name (float sw.ElapsedMilliseconds) tags
    }

    // ========== Aggregation & Export ==========

    /// Get all metrics as array
    let getAllMetrics (state: MetricsCollectorState) =
        let counters =
            state.Counters
            |> Seq.map (fun kvp ->
                let parts = kvp.Key.Split(':')
                let name = parts.[0]
                let tags =
                    if parts.Length > 1 then
                        parts.[1].Split(',')
                        |> Array.choose (fun s ->
                            let kv = s.Split('=')
                            if kv.Length = 2 then Some (kv.[0], kv.[1]) else None)
                        |> Map.ofArray
                    else Map.empty
                (name, float kvp.Value, tags, Counter)
            )

        let gauges =
            state.Gauges
            |> Seq.map (fun kvp ->
                let parts = kvp.Key.Split(':')
                let name = parts.[0]
                let tags =
                    if parts.Length > 1 then
                        parts.[1].Split(',')
                        |> Array.choose (fun s ->
                            let kv = s.Split('=')
                            if kv.Length = 2 then Some (kv.[0], kv.[1]) else None)
                        |> Map.ofArray
                    else Map.empty
                (name, kvp.Value, tags, Gauge)
            )

        let histogramAverages =
            state.Histograms
            |> Seq.map (fun kvp ->
                let hist = kvp.Value
                let avg = if hist.Count > 0L then hist.Sum / float hist.Count else 0.0
                (hist.Name, avg, hist.Tags, Histogram)
            )

        Seq.concat [counters; gauges; histogramAverages] |> Seq.toArray

    /// Drain buffer and get all buffered points
    let drainBuffer (state: MetricsCollectorState) =
        let points = ResizeArray<MetricPoint>()
        let mutable item = Unchecked.defaultof<MetricPoint>
        while state.Buffer.TryDequeue(&item) do
            points.Add(item)
        points.ToArray()

    /// Reset all metrics
    let reset (state: MetricsCollectorState) =
        state.Counters.Clear()
        state.Gauges.Clear()
        state.Histograms.Clear()
        while state.Buffer.TryDequeue(ref Unchecked.defaultof<MetricPoint>) do ()

/// Metrics collector class wrapper
type MetricsCollectorInstance(config: QuadplexConfig) =
    let state = MetricsCollector.create config

    member _.SetMetricCallback(callback) = MetricsCollector.setMetricCallback state callback

    // Counters
    member _.IncrementCounter(name, ?value, ?tags) =
        MetricsCollector.incrementCounter state name (defaultArg value 1L) (defaultArg tags Map.empty)
    member _.GetCounter(name, ?tags) =
        MetricsCollector.getCounter state name (defaultArg tags Map.empty)

    // Gauges
    member _.SetGauge(name, value, ?tags) =
        MetricsCollector.setGauge state name value (defaultArg tags Map.empty)
    member _.GetGauge(name, ?tags) =
        MetricsCollector.getGauge state name (defaultArg tags Map.empty)

    // Histograms
    member _.RecordHistogram(name, value, ?tags) =
        MetricsCollector.recordHistogram state name value (defaultArg tags Map.empty)
    member _.GetHistogramStats(name, ?tags) =
        MetricsCollector.getHistogramStats state name (defaultArg tags Map.empty)
    member _.GetPercentile(name, percentile, ?tags) =
        MetricsCollector.getPercentile state name (defaultArg tags Map.empty) percentile

    // Timers
    member _.StartTimer(name, ?tags) =
        MetricsCollector.startTimer state name (defaultArg tags Map.empty)
    member _.Time(name, f, ?tags) =
        MetricsCollector.time state name (defaultArg tags Map.empty) f
    member _.TimeAsync(name, computation, ?tags) =
        MetricsCollector.timeAsync state name (defaultArg tags Map.empty) computation

    // Aggregation
    member _.GetAllMetrics() = MetricsCollector.getAllMetrics state
    member _.DrainBuffer() = MetricsCollector.drainBuffer state
    member _.Reset() = MetricsCollector.reset state

    interface IMetricsCollector with
        member this.RecordCounter(name, value, tags) = this.IncrementCounter(name, value, tags)
        member this.RecordGauge(name, value, tags) = this.SetGauge(name, value, tags)
        member this.RecordHistogram(name, value, tags) = this.RecordHistogram(name, value, tags)
        member this.StartTimer(name, tags) = this.StartTimer(name, tags)
