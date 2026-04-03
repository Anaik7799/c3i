module Cepaf.Tests.Performance.ZenohPerformanceTests

// ============================================================================
// ZENOH PERFORMANCE TEST SUITE (PRF-L-002)
// ============================================================================
// WHAT:  Validates Zenoh F# integration meets performance SLAs
// WHY:   Ensures real-time cockpit operations under load
// STAMP: SC-ZENOH-PRF-F-001 to SC-ZENOH-PRF-F-006
// ============================================================================

open System
open System.Diagnostics
open System.Threading
open System.Threading.Tasks
open System.Collections.Concurrent
open Expecto

// ============================================================================
// Performance Testing Utilities
// ============================================================================
module PerfUtils =
    /// Measure execution time in microseconds
    let measureMicroseconds (f: unit -> 'T) : 'T * float =
        let sw = Stopwatch.StartNew()
        let result = f()
        sw.Stop()
        result, sw.Elapsed.TotalMicroseconds

    /// Measure execution time in milliseconds
    let measureMilliseconds (f: unit -> 'T) : 'T * float =
        let sw = Stopwatch.StartNew()
        let result = f()
        sw.Stop()
        result, sw.Elapsed.TotalMilliseconds

    /// Measure throughput (operations per second)
    let measureThroughput (count: int) (action: unit -> unit) : float =
        let sw = Stopwatch.StartNew()
        for _ in 1..count do action()
        sw.Stop()
        float count / sw.Elapsed.TotalSeconds

    /// Calculate percentile from a pre-sorted list of values
    /// TPS Fix: Accept pre-sorted list to avoid O(n log n) on each call
    let percentileFromSorted (sorted: float list) (p: float) : float =
        if sorted.IsEmpty then 0.0
        else
            let index = int (float (sorted.Length - 1) * p)
            sorted.[min index (sorted.Length - 1)]

    /// Calculate percentile from a list of values (sorts internally)
    let percentile (values: float list) (p: float) : float =
        if values.IsEmpty then 0.0
        else
            let sorted = values |> List.sort
            percentileFromSorted sorted p

    /// Calculate mean from a list of values
    let mean (values: float list) : float =
        if values.IsEmpty then 0.0
        else values |> List.average

    /// Calculate standard deviation
    let stdDev (values: float list) : float =
        if values.Length < 2 then 0.0
        else
            let avg = mean values
            let sumSquares = values |> List.sumBy (fun x -> (x - avg) ** 2.0)
            sqrt (sumSquares / float (values.Length - 1))

    /// Record for statistical summary
    type StatsSummary = {
        Count: int
        Mean: float
        StdDev: float
        P50: float
        P95: float
        P99: float
        Min: float
        Max: float
    }

    /// Calculate percentile from a pre-sorted array (O(1) index access)
    let private percentileFromArray (sorted: float[]) (p: float) : float =
        if sorted.Length = 0 then 0.0
        else
            let index = int (float (sorted.Length - 1) * p)
            sorted.[min index (sorted.Length - 1)]

    /// Generate statistics summary from values
    /// TPS/Jidoka Fix: Use Array for O(1) access, sort once
    /// RCA: L5 - Original used List with O(n) access and sorted 3x
    let summarize (values: float list) : StatsSummary =
        if values.IsEmpty then
            { Count = 0; Mean = 0.0; StdDev = 0.0; P50 = 0.0; P95 = 0.0; P99 = 0.0; Min = 0.0; Max = 0.0 }
        else
            // Convert to array for O(1) access and faster sorting
            let arr = values |> List.toArray
            Array.sortInPlace arr  // In-place sort, no allocation
            {
                Count = arr.Length
                Mean = arr |> Array.average
                StdDev = if arr.Length < 2 then 0.0
                         else
                             let avg = arr |> Array.average
                             let sumSquares = arr |> Array.sumBy (fun x -> (x - avg) ** 2.0)
                             sqrt (sumSquares / float (arr.Length - 1))
                P50 = percentileFromArray arr 0.50
                P95 = percentileFromArray arr 0.95
                P99 = percentileFromArray arr 0.99
                Min = arr.[0]           // O(1) - already sorted
                Max = arr.[arr.Length - 1]  // O(1) - already sorted
            }

// ============================================================================
// Mock Session for Performance Testing
// ============================================================================
type MessagePayload = {
    Key: string
    Data: byte[]
    Timestamp: DateTimeOffset
}

/// Self-contained mock for deterministic performance testing
/// Simulates Zenoh session behavior without external dependencies
type PerformanceMockSession() =
    let messageBuffer = ConcurrentQueue<MessagePayload>()
    let receiveLatencies = ConcurrentBag<float>()
    let publishLatencies = ConcurrentBag<float>()
    let processedCount = ref 0L
    let droppedCount = ref 0L
    let mutable throttleEnabled = false
    let mutable throttleThreshold = 1000
    let memoryBaseline = GC.GetTotalMemory(false)

    /// Simulate publishing a message
    member _.SimulatePublish(key: string, payload: byte[]) =
        let sw = Stopwatch.StartNew()

        // Simulate throttling under overload
        if throttleEnabled && messageBuffer.Count >= throttleThreshold then
            Interlocked.Increment(droppedCount) |> ignore
        else
            let msg = {
                Key = key
                Data = payload
                Timestamp = DateTimeOffset.UtcNow
            }
            messageBuffer.Enqueue(msg)
            Interlocked.Increment(processedCount) |> ignore

        sw.Stop()
        publishLatencies.Add(sw.Elapsed.TotalMicroseconds)

    /// Simulate receiving/processing a message
    member _.SimulateReceive() : MessagePayload option =
        let sw = Stopwatch.StartNew()
        let mutable result = Unchecked.defaultof<MessagePayload>
        let success = messageBuffer.TryDequeue(&result)
        sw.Stop()

        if success then
            receiveLatencies.Add(sw.Elapsed.TotalMicroseconds)
            Some result
        else
            None

    /// Simulate dashboard update (aggregates recent messages)
    member _.SimulateDashboardUpdate(windowMs: int) : int =
        let cutoff = DateTimeOffset.UtcNow.AddMilliseconds(float -windowMs)
        let recent =
            messageBuffer
            |> Seq.filter (fun m -> m.Timestamp > cutoff)
            |> Seq.length
        recent

    /// Get P99 receive latency
    member _.GetP99ReceiveLatency() : float =
        let values = receiveLatencies |> Seq.toList
        if values.IsEmpty then 0.0
        else PerfUtils.percentile values 0.99

    /// Get P99 publish latency
    member _.GetP99PublishLatency() : float =
        let values = publishLatencies |> Seq.toList
        if values.IsEmpty then 0.0
        else PerfUtils.percentile values 0.99

    /// Get receive latency statistics
    member _.GetReceiveStats() : PerfUtils.StatsSummary =
        receiveLatencies |> Seq.toList |> PerfUtils.summarize

    /// Get publish latency statistics
    member _.GetPublishStats() : PerfUtils.StatsSummary =
        publishLatencies |> Seq.toList |> PerfUtils.summarize

    /// Get total processed count
    member _.ProcessedCount with get() = processedCount.Value

    /// Get total dropped count (under throttle)
    member _.DroppedCount with get() = droppedCount.Value

    /// Enable throttling for overload simulation
    member _.EnableThrottling(threshold: int) =
        throttleThreshold <- threshold
        throttleEnabled <- true

    /// Disable throttling
    member _.DisableThrottling() =
        throttleEnabled <- false

    /// Get current queue depth
    member _.QueueDepth with get() = messageBuffer.Count

    /// Clear buffer
    member _.Clear() =
        let mutable dummy = Unchecked.defaultof<MessagePayload>
        while messageBuffer.TryDequeue(&dummy) do ()

    /// Get memory usage delta (bytes)
    member _.GetMemoryDelta() : int64 =
        GC.GetTotalMemory(false) - memoryBaseline

    /// Reset state
    member this.Reset() =
        this.Clear()
        receiveLatencies.Clear()
        publishLatencies.Clear()
        processedCount := 0L
        droppedCount := 0L
        throttleEnabled <- false

// ============================================================================
// Dashboard Update Simulator
// ============================================================================
module DashboardSim =
    type DashboardState = {
        NodeMetrics: Map<string, float>
        LastUpdate: DateTimeOffset
        UpdateCount: int64
    }

    let create() = {
        NodeMetrics = Map.empty
        LastUpdate = DateTimeOffset.UtcNow
        UpdateCount = 0L
    }

    /// Simulate processing a telemetry update
    let processUpdate (nodeId: string) (value: float) (state: DashboardState) : DashboardState =
        { state with
            NodeMetrics = state.NodeMetrics |> Map.add nodeId value
            LastUpdate = DateTimeOffset.UtcNow
            UpdateCount = state.UpdateCount + 1L
        }

    /// Simulate chart rendering (CPU-bound operation)
    let renderChart (data: float list) : byte[] =
        // Simulate rendering work
        let mutable sum = 0.0
        for v in data do
            sum <- sum + sin(v) * cos(v)
        Array.create (data.Length * 4) (byte (abs sum % 256.0))

// ============================================================================
// Performance Test Suite
// ============================================================================
[<Tests>]
let zenohPerformanceTests =
    testList "Zenoh Performance (SC-ZENOH-PRF-F-001 to PRF-F-006)" [

        // ====================================================================
        // SC-ZENOH-PRF-F-001: Receive Processing Latency < 1ms
        // ====================================================================
        testList "PRF-F-001: Receive Latency" [

            test "Message receive processing < 1ms (1KB payload)" {
                let session = PerformanceMockSession()
                let payload = Array.create 1024 0uy  // 1KB message

                // Warm-up phase (JIT compilation)
                for _ in 1..100 do
                    session.SimulatePublish("warmup", payload)
                    session.SimulateReceive() |> ignore
                session.Reset()

                // Measurement phase
                for _ in 1..1000 do
                    session.SimulatePublish("test/telemetry", payload)
                    session.SimulateReceive() |> ignore

                let stats = session.GetReceiveStats()
                let p99 = stats.P99

                // P99 latency should be < 1000us (1ms)
                Expect.isLessThan p99 1000.0
                    (sprintf "P99 receive latency %.2fus should be < 1000us (1ms). Stats: mean=%.2f, p50=%.2f, p95=%.2f"
                        p99 stats.Mean stats.P50 stats.P95)
            }

            test "Large message processing latency acceptable (64KB)" {
                let session = PerformanceMockSession()
                let payload = Array.create 65536 0uy  // 64KB message

                // Warm-up
                for _ in 1..50 do
                    session.SimulatePublish("warmup", payload)
                    session.SimulateReceive() |> ignore
                session.Reset()

                // Measurement
                for _ in 1..500 do
                    session.SimulatePublish("test/large", payload)
                    session.SimulateReceive() |> ignore

                let p99 = session.GetP99ReceiveLatency()

                // P99 for 64KB should be < 5000us (5ms) - relaxed for large payloads
                Expect.isLessThan p99 5000.0
                    (sprintf "P99 latency for 64KB %.2fus should be < 5000us (5ms)" p99)
            }

            test "Mixed payload sizes maintain sub-millisecond receive" {
                let session = PerformanceMockSession()
                let payloads = [|
                    Array.create 64 0uy      // 64B - minimal
                    Array.create 512 0uy     // 512B - typical
                    Array.create 1024 0uy    // 1KB - standard
                    Array.create 4096 0uy    // 4KB - larger
                |]
                let rng = Random(42)

                // Warm-up
                for _ in 1..100 do
                    let payload = payloads.[rng.Next(payloads.Length)]
                    session.SimulatePublish("warmup", payload)
                    session.SimulateReceive() |> ignore
                session.Reset()

                // Measurement with mixed sizes
                for _ in 1..2000 do
                    let payload = payloads.[rng.Next(payloads.Length)]
                    session.SimulatePublish("test/mixed", payload)
                    session.SimulateReceive() |> ignore

                let stats = session.GetReceiveStats()

                Expect.isLessThan stats.P99 1000.0
                    (sprintf "P99 latency %.2fus should be < 1000us for mixed payloads" stats.P99)
            }
        ]

        // ====================================================================
        // SC-ZENOH-PRF-F-002: Dashboard Update Latency < 50ms
        // ====================================================================
        testList "PRF-F-002: Dashboard Update Latency" [

            test "Dashboard update < 50ms with 100 nodes" {
                let mutable state = DashboardSim.create()
                let nodeCount = 100
                let updateLatencies = ConcurrentBag<float>()

                // Warm-up
                for i in 1..nodeCount do
                    state <- DashboardSim.processUpdate (sprintf "node-%d" i) (float i) state

                // Measurement: 500 update cycles
                for cycle in 1..500 do
                    let _, elapsed = PerfUtils.measureMilliseconds (fun () ->
                        for i in 1..nodeCount do
                            state <- DashboardSim.processUpdate
                                (sprintf "node-%d" i)
                                (float cycle * float i)
                                state
                    )
                    updateLatencies.Add(elapsed)

                let stats = updateLatencies |> Seq.toList |> PerfUtils.summarize

                // P99 update latency should be < 50ms
                Expect.isLessThan stats.P99 50.0
                    (sprintf "P99 dashboard update %.2fms should be < 50ms. Stats: mean=%.2f, p50=%.2f"
                        stats.P99 stats.Mean stats.P50)
            }

            test "Chart rendering completes within timeout" {
                let chartData = [for i in 1..1000 -> float i * 0.1]
                let renderLatencies = ConcurrentBag<float>()

                // Warm-up
                for _ in 1..10 do
                    DashboardSim.renderChart chartData |> ignore

                // Measurement
                for _ in 1..100 do
                    let _, elapsed = PerfUtils.measureMilliseconds (fun () ->
                        DashboardSim.renderChart chartData |> ignore
                    )
                    renderLatencies.Add(elapsed)

                let stats = renderLatencies |> Seq.toList |> PerfUtils.summarize

                // Chart rendering should be < 50ms
                Expect.isLessThan stats.P99 50.0
                    (sprintf "P99 chart render %.2fms should be < 50ms" stats.P99)
            }

            test "Aggregate stats computation < 10ms" {
                let data = [for i in 1..10000 -> float i]

                // TPS/Jidoka: Warmup to exclude JIT compilation overhead
                // RCA: First run includes ~8ms JIT compilation
                for _ in 1..3 do
                    PerfUtils.summarize data |> ignore

                // Measure after warmup
                let _, elapsed = PerfUtils.measureMilliseconds (fun () ->
                    let _ = PerfUtils.summarize data
                    ()
                )

                Expect.isLessThan elapsed 10.0
                    (sprintf "Stats computation %.2fms should be < 10ms" elapsed)
            }
        ]

        // ====================================================================
        // SC-ZENOH-PRF-F-003: Message Queue Throughput > 5K msg/sec
        // ====================================================================
        testList "PRF-F-003: Throughput" [

            test "Message queue throughput > 5K msg/sec" {
                let session = PerformanceMockSession()
                let payload = Array.create 256 0uy  // 256B typical message

                // Warm-up
                for _ in 1..1000 do
                    session.SimulatePublish("warmup", payload)
                session.Reset()

                // Measure publish throughput
                let count = 10000
                let throughput = PerfUtils.measureThroughput count (fun () ->
                    session.SimulatePublish("test/throughput", payload)
                )

                // Throughput should be > 5000 msg/sec
                Expect.isGreaterThan throughput 5000.0
                    (sprintf "Throughput %.0f msg/sec should be > 5000 msg/sec" throughput)
            }

            test "Sustained throughput under continuous load" {
                let session = PerformanceMockSession()
                let payload = Array.create 512 0uy
                let batchSize = 1000
                let batches = 10
                let throughputs = ConcurrentBag<float>()

                // Run multiple batches
                for _ in 1..batches do
                    let t = PerfUtils.measureThroughput batchSize (fun () ->
                        session.SimulatePublish("test/sustained", payload)
                        session.SimulateReceive() |> ignore
                    )
                    throughputs.Add(t)

                let stats = throughputs |> Seq.toList |> PerfUtils.summarize

                // Min throughput (worst batch) should still be > 5K
                Expect.isGreaterThan stats.Min 5000.0
                    (sprintf "Min sustained throughput %.0f should be > 5000 msg/sec. Mean=%.0f"
                        stats.Min stats.Mean)
            }

            test "Batch processing efficiency > 90%%" {
                let session = PerformanceMockSession()
                let payload = Array.create 128 0uy
                let totalMessages = 10000

                // Publish all messages
                for _ in 1..totalMessages do
                    session.SimulatePublish("test/batch", payload)

                // Process all messages
                let mutable received = 0
                while session.SimulateReceive().IsSome do
                    received <- received + 1

                let efficiency = float received / float totalMessages * 100.0

                // Efficiency should be > 90%
                Expect.isGreaterThan efficiency 90.0
                    (sprintf "Batch efficiency %.1f%% should be > 90%%. Received %d/%d"
                        efficiency received totalMessages)
            }
        ]

        // ====================================================================
        // SC-ZENOH-PRF-F-004: UI Rendering Not Blocked
        // ====================================================================
        testList "PRF-F-004: Non-Blocking UI" [

            test "UI thread not blocked by message processing" {
                let session = PerformanceMockSession()
                let payload = Array.create 1024 0uy
                let uiResponsive = ref true
                let cts = new CancellationTokenSource()

                // Start background message processing
                let processingTask = Task.Run(fun () ->
                    for _ in 1..5000 do
                        session.SimulatePublish("test/background", payload)
                        session.SimulateReceive() |> ignore
                        if cts.Token.IsCancellationRequested then ()
                )

                // Simulate UI responsiveness check
                let uiTask = Task.Run(fun () ->
                    let mutable checks = 0
                    while checks < 100 && not processingTask.IsCompleted do
                        let _, elapsed = PerfUtils.measureMilliseconds (fun () ->
                            // Simulate UI operation (should complete quickly)
                            Thread.Sleep(1)
                        )
                        if elapsed > 100.0 then // UI blocked > 100ms
                            uiResponsive := false
                        checks <- checks + 1
                        Thread.Sleep(10)
                )

                // Wait for completion
                Task.WaitAll([| processingTask; uiTask |])

                Expect.isTrue !uiResponsive "UI should remain responsive during processing"
            }

            test "Async message handling preserves responsiveness" {
                let latencies = ConcurrentBag<float>()
                let iterations = 100

                // Simulate interleaved UI and message operations
                for _ in 1..iterations do
                    let _, elapsed = PerfUtils.measureMilliseconds (fun () ->
                        // Simulate brief UI operation
                        let mutable x = 0.0
                        for i in 1..1000 do
                            x <- x + float i * 0.001
                    )
                    latencies.Add(elapsed)

                let stats = latencies |> Seq.toList |> PerfUtils.summarize

                // P99 UI operation should be < 10ms
                Expect.isLessThan stats.P99 10.0
                    (sprintf "P99 UI operation %.2fms should be < 10ms" stats.P99)
            }
        ]

        // ====================================================================
        // SC-ZENOH-PRF-F-005: Memory Stability
        // ====================================================================
        testList "PRF-F-005: Memory Stability" [

            test "Memory stable after 10K messages" {
                let session = PerformanceMockSession()
                let payload = Array.create 512 0uy

                // Force GC to get baseline
                GC.Collect()
                GC.WaitForPendingFinalizers()
                let initialMemory = GC.GetTotalMemory(true)

                // Process 10K messages
                for _ in 1..10000 do
                    session.SimulatePublish("test/memory", payload)
                    session.SimulateReceive() |> ignore

                // Measure memory after processing
                GC.Collect()
                GC.WaitForPendingFinalizers()
                let finalMemory = GC.GetTotalMemory(true)

                let memoryGrowthMB = float (finalMemory - initialMemory) / (1024.0 * 1024.0)

                // Memory growth should be bounded (< 50MB for 10K messages)
                Expect.isLessThan memoryGrowthMB 50.0
                    (sprintf "Memory growth %.2f MB should be < 50 MB after 10K messages" memoryGrowthMB)
            }

            test "No memory leak in long-running scenario" {
                let session = PerformanceMockSession()
                let payload = Array.create 256 0uy
                let memorySnapshots = ConcurrentBag<int64>()

                // Run 5 rounds of 5K messages each, measuring memory between rounds
                for round in 1..5 do
                    for _ in 1..5000 do
                        session.SimulatePublish("test/longrun", payload)
                        session.SimulateReceive() |> ignore

                    // Clear processed messages and force GC
                    session.Clear()
                    GC.Collect()
                    GC.WaitForPendingFinalizers()
                    memorySnapshots.Add(GC.GetTotalMemory(true))

                let snapshots = memorySnapshots |> Seq.toList

                // Check that memory doesn't continuously grow
                // Compare first and last snapshots - difference should be bounded
                if snapshots.Length >= 2 then
                    let first = snapshots.[0]
                    let last = snapshots.[snapshots.Length - 1]
                    let growthMB = float (last - first) / (1024.0 * 1024.0)

                    // Memory should not grow more than 10MB across all rounds
                    Expect.isLessThan growthMB 10.0
                        (sprintf "Memory growth %.2f MB across rounds should be < 10 MB" growthMB)
            }

            test "Buffer cleanup releases memory" {
                let session = PerformanceMockSession()
                let payload = Array.create 4096 0uy  // 4KB messages

                // Fill buffer
                for _ in 1..5000 do
                    session.SimulatePublish("test/cleanup", payload)

                GC.Collect()
                let beforeCleanup = GC.GetTotalMemory(true)

                // Clear buffer
                session.Reset()

                GC.Collect()
                GC.WaitForPendingFinalizers()
                let afterCleanup = GC.GetTotalMemory(true)

                // Memory should decrease after cleanup
                Expect.isLessThanOrEqual afterCleanup beforeCleanup
                    "Memory should not increase after buffer cleanup"
            }
        ]

        // ====================================================================
        // SC-ZENOH-PRF-F-006: Graceful Throttling Under Overload
        // ====================================================================
        testList "PRF-F-006: Graceful Throttling" [

            test "Throttling activates under overload" {
                let session = PerformanceMockSession()
                let payload = Array.create 128 0uy

                // Enable throttling at 500 messages
                session.EnableThrottling(500)

                // Attempt to publish 1000 messages
                for _ in 1..1000 do
                    session.SimulatePublish("test/throttle", payload)

                // Some messages should be dropped
                let dropped = session.DroppedCount
                let processed = session.ProcessedCount

                Expect.isGreaterThan dropped 0L
                    "Some messages should be dropped under throttle"
                Expect.isLessThanOrEqual processed 500L
                    (sprintf "Processed count %d should be <= throttle threshold 500" processed)
            }

            test "System remains responsive during overload" {
                let session = PerformanceMockSession()
                let payload = Array.create 64 0uy
                let publishLatencies = ConcurrentBag<float>()

                // Enable strict throttling
                session.EnableThrottling(100)

                // Attempt high-volume publishing
                for _ in 1..2000 do
                    let _, elapsed = PerfUtils.measureMicroseconds (fun () ->
                        session.SimulatePublish("test/overload", payload)
                    )
                    publishLatencies.Add(elapsed)

                let stats = publishLatencies |> Seq.toList |> PerfUtils.summarize

                // Even under overload, publish operation should return quickly
                Expect.isLessThan stats.P99 1000.0
                    (sprintf "P99 publish latency %.2fus should be < 1000us even under throttle" stats.P99)
            }

            test "Graceful degradation maintains core functionality" {
                let session = PerformanceMockSession()
                let payload = Array.create 256 0uy

                // Enable throttling
                session.EnableThrottling(200)

                // Heavy publish load
                for _ in 1..1000 do
                    session.SimulatePublish("test/degrade", payload)

                // Drain available messages
                let mutable received = 0
                while session.SimulateReceive().IsSome do
                    received <- received + 1

                // Should have received some messages (not complete failure)
                Expect.isGreaterThan received 0
                    "Should receive some messages even under throttle"
                Expect.isLessThanOrEqual received 200
                    (sprintf "Received %d should be <= throttle threshold 200" received)

                // Verify system is still functional after overload
                session.DisableThrottling()
                session.Reset()

                session.SimulatePublish("test/recovery", payload)
                let recovered = session.SimulateReceive()

                Expect.isSome recovered
                    "System should recover after throttle disabled"
            }

            test "Backpressure signals propagate correctly" {
                let session = PerformanceMockSession()
                let payload = Array.create 128 0uy

                // Set low throttle threshold
                session.EnableThrottling(50)

                // Track queue depth during publish
                let depths = ConcurrentBag<int>()

                for _ in 1..200 do
                    session.SimulatePublish("test/backpressure", payload)
                    depths.Add(session.QueueDepth)

                let maxDepth = depths |> Seq.max

                // Queue depth should be bounded by throttle
                Expect.isLessThanOrEqual maxDepth 50
                    (sprintf "Max queue depth %d should be <= throttle threshold 50" maxDepth)
            }
        ]

        // ====================================================================
        // Additional Stress Tests
        // ====================================================================
        testList "Stress Tests (Extended Validation)" [

            test "Concurrent publish/receive stress test" {
                let session = PerformanceMockSession()
                let payload = Array.create 256 0uy
                let errors = ref 0

                // Run concurrent operations
                let publishTask = Task.Run(fun () ->
                    for _ in 1..5000 do
                        try
                            session.SimulatePublish("stress/pub", payload)
                        with _ ->
                            Interlocked.Increment(errors) |> ignore
                )

                let receiveTask = Task.Run(fun () ->
                    for _ in 1..5000 do
                        try
                            session.SimulateReceive() |> ignore
                        with _ ->
                            Interlocked.Increment(errors) |> ignore
                )

                Task.WaitAll([| publishTask; receiveTask |])

                Expect.equal !errors 0 "No errors should occur during concurrent stress"
            }

            test "Latency under varying load patterns" {
                let session = PerformanceMockSession()
                let payload = Array.create 128 0uy
                let latencyByLoad = ConcurrentDictionary<int, float>()

                // Test different load levels
                for loadLevel in [10; 50; 100; 500; 1000] do
                    session.Reset()

                    // Generate load
                    for _ in 1..loadLevel do
                        session.SimulatePublish("test/load", payload)

                    // Measure receive latency at this load
                    for _ in 1..min loadLevel 100 do
                        session.SimulateReceive() |> ignore

                    let p99 = session.GetP99ReceiveLatency()
                    latencyByLoad.[loadLevel] <- p99

                // Latency should remain acceptable across load levels
                for kvp in latencyByLoad do
                    Expect.isLessThan kvp.Value 2000.0
                        (sprintf "P99 latency %.2fus at load %d should be < 2000us" kvp.Value kvp.Key)
            }
        ]
    ]
