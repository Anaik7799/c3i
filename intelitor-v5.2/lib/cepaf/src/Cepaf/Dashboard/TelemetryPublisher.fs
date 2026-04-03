namespace Cepaf.Dashboard

open System
open System.Threading
open System.Collections.Concurrent
open Cepaf.Zenoh

/// F# Telemetry Publisher for Bidirectional Observability
///
/// ## Features
/// - Publishes F# application metrics to Zenoh
/// - Automatic metric aggregation
/// - Histogram and counter support
/// - System resource monitoring
///
/// ## STAMP Constraints
/// - SC-TEL-FSH-001: Metric publishing interval configurable
/// - SC-TEL-FSH-002: Non-blocking metric collection
/// - SC-TEL-FSH-003: Automatic reconnection
module TelemetryPublisher =

    // ========================================================================
    // TYPES
    // ========================================================================

    /// Metric type
    type MetricType =
        | Counter
        | Gauge
        | Histogram
        | Summary

    /// Metric value
    type MetricValue =
        | Int of int64
        | Float of float
        | Duration of TimeSpan

    /// Metric entry
    type Metric = {
        Name: string
        Type: MetricType
        Value: MetricValue
        Tags: Map<string, string>
        Timestamp: DateTimeOffset
        Unit: string option
    }

    /// Publisher configuration
    type PublisherConfig = {
        Enabled: bool
        KeyPrefix: string
        PublishIntervalMs: int
        BatchSize: int
        IncludeSystemMetrics: bool
    }

    /// Publisher statistics
    type PublisherStats = {
        MetricsPublished: int64
        PublishCycles: int64
        Errors: int64
        LastPublishAt: DateTimeOffset option
        AverageLatencyMs: float
    }

    // ========================================================================
    // DEFAULTS
    // ========================================================================

    let defaultConfig = {
        Enabled = true
        KeyPrefix = "indrajaal/telemetry/fsharp"
        PublishIntervalMs = 5000
        BatchSize = 100
        IncludeSystemMetrics = true
    }

    // ========================================================================
    // STATE
    // ========================================================================

    let mutable private config = defaultConfig
    let private metricBuffer = ConcurrentQueue<Metric>()
    let private counters = ConcurrentDictionary<string, int64 ref>()
    let private gauges = ConcurrentDictionary<string, float ref>()
    let private histograms = ConcurrentDictionary<string, ResizeArray<float>>()

    let mutable private stats = {
        MetricsPublished = 0L
        PublishCycles = 0L
        Errors = 0L
        LastPublishAt = None
        AverageLatencyMs = 0.0
    }
    let private statsLock = obj()
    let mutable private publishTimer : Timer option = None
    let private startTime = DateTimeOffset.UtcNow

    // ========================================================================
    // INTERNAL FUNCTIONS
    // ========================================================================

    /// Collect system metrics
    let private collectSystemMetrics () : Metric seq =
        seq {
            // Uptime
            yield {
                Name = "cepaf.uptime.seconds"
                Type = Gauge
                Value = Float (DateTimeOffset.UtcNow - startTime).TotalSeconds
                Tags = Map.empty
                Timestamp = DateTimeOffset.UtcNow
                Unit = Some "seconds"
            }

            // GC metrics
            yield {
                Name = "cepaf.gc.total_memory"
                Type = Gauge
                Value = Int (GC.GetTotalMemory(false))
                Tags = Map.empty
                Timestamp = DateTimeOffset.UtcNow
                Unit = Some "bytes"
            }

            for gen in 0..2 do
                yield {
                    Name = sprintf "cepaf.gc.collections.gen%d" gen
                    Type = Counter
                    Value = Int (int64 (GC.CollectionCount(gen)))
                    Tags = Map.ofList [("generation", string gen)]
                    Timestamp = DateTimeOffset.UtcNow
                    Unit = None
                }

            // Thread pool metrics
            let workerThreads, completionThreads = ref 0, ref 0
            ThreadPool.GetAvailableThreads(workerThreads, completionThreads)
            let maxWorker, maxCompletion = ref 0, ref 0
            ThreadPool.GetMaxThreads(maxWorker, maxCompletion)

            yield {
                Name = "cepaf.threadpool.available_workers"
                Type = Gauge
                Value = Int (int64 !workerThreads)
                Tags = Map.empty
                Timestamp = DateTimeOffset.UtcNow
                Unit = None
            }

            yield {
                Name = "cepaf.threadpool.busy_workers"
                Type = Gauge
                Value = Int (int64 (!maxWorker - !workerThreads))
                Tags = Map.empty
                Timestamp = DateTimeOffset.UtcNow
                Unit = None
            }
        }

    /// Publish buffered metrics to Zenoh
    let private publishMetrics () =
        if not config.Enabled then ()
        else
            let start = DateTimeOffset.UtcNow

            // Collect all metrics
            let metrics = ResizeArray<Metric>()

            // Drain buffer
            let mutable m = Unchecked.defaultof<Metric>
            while metrics.Count < config.BatchSize && metricBuffer.TryDequeue(&m) do
                metrics.Add(m)

            // Add counter values
            for KeyValue(name, value) in counters do
                metrics.Add({
                    Name = name
                    Type = Counter
                    Value = Int !value
                    Tags = Map.empty
                    Timestamp = DateTimeOffset.UtcNow
                    Unit = None
                })

            // Add gauge values
            for KeyValue(name, value) in gauges do
                metrics.Add({
                    Name = name
                    Type = Gauge
                    Value = Float !value
                    Tags = Map.empty
                    Timestamp = DateTimeOffset.UtcNow
                    Unit = None
                })

            // Add histogram summaries
            for KeyValue(name, values) in histograms do
                if values.Count > 0 then
                    let sorted = values |> Seq.sort |> Seq.toArray
                    let p50 = sorted.[sorted.Length / 2]
                    let p99 = sorted.[int (float sorted.Length * 0.99)]
                    let avg = sorted |> Seq.average

                    metrics.Add({
                        Name = sprintf "%s.p50" name
                        Type = Histogram
                        Value = Float p50
                        Tags = Map.ofList [("quantile", "0.5")]
                        Timestamp = DateTimeOffset.UtcNow
                        Unit = None
                    })
                    metrics.Add({
                        Name = sprintf "%s.p99" name
                        Type = Histogram
                        Value = Float p99
                        Tags = Map.ofList [("quantile", "0.99")]
                        Timestamp = DateTimeOffset.UtcNow
                        Unit = None
                    })
                    metrics.Add({
                        Name = sprintf "%s.avg" name
                        Type = Histogram
                        Value = Float avg
                        Tags = Map.ofList [("type", "average")]
                        Timestamp = DateTimeOffset.UtcNow
                        Unit = None
                    })
                    values.Clear()

            // Add system metrics if enabled
            if config.IncludeSystemMetrics then
                metrics.AddRange(collectSystemMetrics())

            // Publish to Zenoh
            if metrics.Count > 0 then
                let payload = {|
                    timestamp = DateTimeOffset.UtcNow.ToString("o")
                    source = "cepaf"
                    metrics =
                        metrics
                        |> Seq.map (fun m -> {|
                            name = m.Name
                            ``type`` = m.Type.ToString()
                            value =
                                match m.Value with
                                | Int i -> box i
                                | Float f -> box f
                                | Duration d -> box d.TotalMilliseconds
                            tags = m.Tags
                            unit = m.Unit
                        |})
                        |> Seq.toArray
                |}

                let key = sprintf "%s/batch" config.KeyPrefix
                match ZenohSession.publishJson key (System.Text.Json.JsonSerializer.Serialize(payload)) with
                | Ok () ->
                    let elapsed = (DateTimeOffset.UtcNow - start).TotalMilliseconds
                    lock statsLock (fun () ->
                        stats <- {
                            stats with
                                MetricsPublished = stats.MetricsPublished + int64 metrics.Count
                                PublishCycles = stats.PublishCycles + 1L
                                LastPublishAt = Some DateTimeOffset.UtcNow
                                AverageLatencyMs =
                                    (stats.AverageLatencyMs * float stats.PublishCycles + elapsed) /
                                    float (stats.PublishCycles + 1L)
                        }
                    )
                | Error err ->
                    lock statsLock (fun () ->
                        stats <- { stats with Errors = stats.Errors + 1L }
                    )
                    printfn "[TelemetryPublisher] Publish error: %s" err

    /// Initialize timer (called once during initialization)
    let private initTimer () =
        if publishTimer.IsNone then
            publishTimer <- Some (new Timer((fun _ -> publishMetrics()), null, Timeout.Infinite, Timeout.Infinite))

    // ========================================================================
    // PUBLIC API
    // ========================================================================

    /// Initialize the publisher
    let initialize (cfg: PublisherConfig) =
        config <- cfg
        initTimer ()
        if cfg.Enabled then
            match publishTimer with
            | Some timer -> timer.Change(cfg.PublishIntervalMs, cfg.PublishIntervalMs) |> ignore
            | None -> ()
            printfn "[TelemetryPublisher] Started with interval %dms" cfg.PublishIntervalMs

    /// Initialize with default configuration
    let initializeDefault () =
        initialize defaultConfig

    /// Record a counter increment
    let incrementCounter (name: string) (delta: int64) (tags: Map<string, string>) =
        let counter = counters.GetOrAdd(name, fun _ -> ref 0L)
        Interlocked.Add(counter, delta) |> ignore

    /// Record a gauge value
    let setGauge (name: string) (value: float) (tags: Map<string, string>) =
        let gauge = gauges.GetOrAdd(name, fun _ -> ref 0.0)
        gauge := value

    /// Record a histogram observation
    let observeHistogram (name: string) (value: float) (tags: Map<string, string>) =
        let hist = histograms.GetOrAdd(name, fun _ -> ResizeArray<float>())
        lock hist (fun () -> hist.Add(value))

    /// Record a duration
    let recordDuration (name: string) (duration: TimeSpan) (tags: Map<string, string>) =
        observeHistogram (sprintf "%s.duration_ms" name) duration.TotalMilliseconds tags

    /// Measure execution time
    let measureTime (name: string) (tags: Map<string, string>) (f: unit -> 'T) =
        let start = DateTimeOffset.UtcNow
        try
            let result = f()
            let elapsed = DateTimeOffset.UtcNow - start
            recordDuration name elapsed tags
            incrementCounter (sprintf "%s.success" name) 1L tags
            result
        with ex ->
            let elapsed = DateTimeOffset.UtcNow - start
            recordDuration name elapsed tags
            incrementCounter (sprintf "%s.error" name) 1L tags
            reraise()

    /// Enqueue a custom metric
    let recordMetric (metric: Metric) =
        metricBuffer.Enqueue(metric)

    /// Get publisher statistics
    let getStats () = stats

    /// Force publish now
    let publishNow () =
        publishMetrics()

    /// Close the publisher
    let close () =
        match publishTimer with
        | Some timer -> timer.Dispose()
        | None -> ()
        printfn "[TelemetryPublisher] Closed"
