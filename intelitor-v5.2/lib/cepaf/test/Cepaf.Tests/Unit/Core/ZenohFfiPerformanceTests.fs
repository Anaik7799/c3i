// =============================================================================
// ZenohFfiPerformanceTests.fs - Performance benchmarks for Zenoh FFI operations
// =============================================================================
// STAMP: SC-ZTEST-003 (publish latency < 10ms), SC-ZENOH-FFI-001 to SC-ZENOH-FFI-025
// Tests: L4 (Performance) — FFI call overhead, publish latency, throughput, memory
// Mathematical: $L_{publish} < 10ms$ (p99), $T_{ops} > 1000$ ops/sec
// FMEA: RPN 72 (high latency from FFI overhead), mitigation = async publish
// =============================================================================

namespace Cepaf.Tests.Unit.Core

open System
open System.Diagnostics
open System.Threading
open Expecto
open Cepaf.Zenoh.Core
open Cepaf.Mesh

module ZenohFfiPerformanceTests =

    // =========================================================================
    // Performance Utilities
    // =========================================================================

    /// Measure execution time in microseconds
    let private measureUs (f: unit -> 'T) : 'T * float =
        let sw = Stopwatch.StartNew()
        let result = f()
        sw.Stop()
        result, sw.Elapsed.TotalMicroseconds

    /// Measure execution time in milliseconds
    let private measureMs (f: unit -> 'T) : 'T * float =
        let sw = Stopwatch.StartNew()
        let result = f()
        sw.Stop()
        result, sw.Elapsed.TotalMilliseconds

    /// Collect N samples of a measurement
    let private collectSamples (n: int) (f: unit -> unit) : float[] =
        // Warmup: 5 iterations
        for _ in 1..5 do f()
        // Collect
        let results = Array.zeroCreate n
        for i in 0..n-1 do
            let sw = Stopwatch.StartNew()
            f()
            sw.Stop()
            results.[i] <- sw.Elapsed.TotalMicroseconds
        results

    /// Calculate percentile from sorted array
    let private percentile (sorted: float[]) (p: float) : float =
        if sorted.Length = 0 then 0.0
        else
            let idx = int (float (sorted.Length - 1) * p)
            sorted.[min idx (sorted.Length - 1)]

    /// Format stats summary
    let private summarize (label: string) (samples: float[]) =
        let sorted = samples |> Array.sort
        let p50 = percentile sorted 0.50
        let p95 = percentile sorted 0.95
        let p99 = percentile sorted 0.99
        let avg = samples |> Array.average
        let min' = sorted.[0]
        let max' = sorted.[sorted.Length - 1]
        sprintf "%s: avg=%.1fus p50=%.1fus p95=%.1fus p99=%.1fus min=%.1fus max=%.1fus (n=%d)"
            label avg p50 p95 p99 min' max' samples.Length

    // =========================================================================
    // L4: FFI Availability Check Latency
    // =========================================================================

    [<Tests>]
    let ffiAvailabilityPerf =
        testList "FFI.Perf.Availability" [

            test "isAvailable latency < 1ms (SC-ZENOH-FFI-001)" {
                let samples = collectSamples 100 (fun () ->
                    try ZenohFfiBridge.isAvailable() |> ignore
                    with _ -> ())
                let sorted = samples |> Array.sort
                let p99 = percentile sorted 0.99
                let avgMs = (samples |> Array.average) / 1000.0
                // isAvailable should be very fast — just a DllImport probe
                Expect.isLessThan avgMs 1.0
                    (sprintf "isAvailable avg should be <1ms, got %.3fms. %s"
                        avgMs (summarize "isAvailable" samples))
            }

            test "isAvailable is consistent (no flapping)" {
                let results = Array.init 50 (fun _ ->
                    try ZenohFfiBridge.isAvailable() with _ -> false)
                let allSame = results |> Array.forall (fun r -> r = results.[0])
                Expect.isTrue allSame "isAvailable should return consistent result"
            }
        ]

    // =========================================================================
    // L4: Key Expression Validation Latency
    // =========================================================================

    [<Tests>]
    let keyExprValidationPerf =
        testList "FFI.Perf.KeyExprValidation" [

            test "ZenohKeyExpr.validate latency < 100us for simple keys" {
                let samples = collectSamples 1000 (fun () ->
                    ZenohKeyExpr.validate "indrajaal/test/hello" |> ignore)
                let sorted = samples |> Array.sort
                let p99 = percentile sorted 0.99
                Expect.isLessThan p99 100.0
                    (sprintf "Validation p99 should be <100us, got %.1fus. %s"
                        p99 (summarize "validate" samples))
            }

            test "ZenohKeyExpr.matches latency < 50us for wildcard patterns" {
                let samples = collectSamples 1000 (fun () ->
                    ZenohKeyExpr.matches "indrajaal/**/health" "indrajaal/a/b/c/health" |> ignore)
                let sorted = samples |> Array.sort
                let p99 = percentile sorted 0.99
                Expect.isLessThan p99 50.0
                    (sprintf "Matching p99 should be <50us, got %.1fus. %s"
                        p99 (summarize "matches" samples))
            }

            test "Validation throughput > 100K ops/sec" {
                let sw = Stopwatch.StartNew()
                let count = 10000
                for _ in 1..count do
                    ZenohKeyExpr.validate "indrajaal/test/perf" |> ignore
                sw.Stop()
                let opsPerSec = float count / sw.Elapsed.TotalSeconds
                Expect.isGreaterThan opsPerSec 100000.0
                    (sprintf "Validation throughput should be >100K ops/sec, got %.0f" opsPerSec)
            }
        ]

    // =========================================================================
    // L4: Null Handle Safety Check Latency
    // =========================================================================

    [<Tests>]
    let nullHandlePerf =
        testList "FFI.Perf.NullHandleSafety" [

            test "Null handle publish rejection < 50us" {
                let samples = collectSamples 500 (fun () ->
                    ZenohFfiBridge.publish (nativeint 0) "test" [||] |> ignore)
                let sorted = samples |> Array.sort
                let p99 = percentile sorted 0.99
                Expect.isLessThan p99 50.0
                    (sprintf "Null handle rejection p99 should be <50us. %s"
                        (summarize "null-publish" samples))
            }

            test "Null handle subscribe rejection < 50us" {
                let samples = collectSamples 500 (fun () ->
                    ZenohFfiBridge.subscribe (nativeint 0) "test" |> ignore)
                let sorted = samples |> Array.sort
                let p99 = percentile sorted 0.99
                Expect.isLessThan p99 50.0
                    (sprintf "Null subscribe rejection p99 should be <50us. %s"
                        (summarize "null-subscribe" samples))
            }

            test "Null handle isConnected < 10us" {
                let samples = collectSamples 500 (fun () ->
                    ZenohFfiBridge.isConnected (nativeint 0) |> ignore)
                let sorted = samples |> Array.sort
                let p99 = percentile sorted 0.99
                Expect.isLessThan p99 10.0
                    (sprintf "Null isConnected p99 should be <10us. %s"
                        (summarize "null-isConnected" samples))
            }
        ]

    // =========================================================================
    // L4: Simulated Session Publish Latency (SC-ZTEST-003 proxy)
    // =========================================================================

    [<Tests>]
    let simulatedPublishPerf =
        testList "FFI.Perf.SimulatedPublish" [

            testAsync "Simulated publish p99 < 5ms" {
                let config = SessionConfig.defaultConfig()
                let! r = SafeSession.OpenAsync(config) |> Async.AwaitTask
                match r with
                | Ok session ->
                    let pc = { PublisherConfig.KeyExpr = "indrajaal/perf/test"
                               CongestionControl = "drop"; Priority = 5
                               Reliability = "best_effort"; Express = true }
                    match SafePublisher.Create(session, pc) with
                    | Ok pub' ->
                        let payload = System.Text.Encoding.UTF8.GetBytes("""{"perf":"test"}""")
                        // Warmup
                        for _ in 1..10 do
                            pub'.PutAsync(payload).Wait()
                        // Measure
                        let samples = Array.zeroCreate 200
                        for i in 0..199 do
                            let sw = Stopwatch.StartNew()
                            pub'.PutAsync(payload).Wait()
                            sw.Stop()
                            samples.[i] <- sw.Elapsed.TotalMilliseconds
                        let sorted = samples |> Array.sort
                        let p99 = percentile sorted 0.99
                        Expect.isLessThan p99 5.0
                            (sprintf "Simulated publish p99=%.2fms should be <5ms" p99)
                        (pub' :> IDisposable).Dispose()
                    | Error e -> failwithf "Publisher create failed: %s" e.Message
                    do! session.CloseAsync() |> Async.AwaitTask
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            testAsync "Simulated publish throughput > 500 ops/sec" {
                let config = SessionConfig.defaultConfig()
                let! r = SafeSession.OpenAsync(config) |> Async.AwaitTask
                match r with
                | Ok session ->
                    match SafePublisher.Create(session, PublisherConfig.create "indrajaal/perf/throughput") with
                    | Ok pub' ->
                        let payload = [| 0uy..255uy |]
                        let sw = Stopwatch.StartNew()
                        let count = 500
                        for _ in 1..count do
                            pub'.PutAsync(payload).Wait()
                        sw.Stop()
                        let opsPerSec = float count / sw.Elapsed.TotalSeconds
                        Expect.isGreaterThan opsPerSec 500.0
                            (sprintf "Throughput should be >500 ops/sec, got %.0f" opsPerSec)
                        (pub' :> IDisposable).Dispose()
                    | Error e -> failwithf "Create failed: %s" e.Message
                    do! session.CloseAsync() |> Async.AwaitTask
                | Error e -> failwithf "Session open failed: %s" e.Message
            }
        ]

    // =========================================================================
    // L4: ZenohPublish Triple-Write Latency (SC-ZTEST-008)
    // =========================================================================

    [<Tests>]
    let tripleWritePerf =
        testList "FFI.Perf.TripleWrite" [

            test "Triple-write latency p99 < 5ms (no native session)" {
                ZenohPublish.clearNativeSession()
                let samples = collectSamples 200 (fun () ->
                    ZenohPublish.tryPublish
                        "CP-PERF-01"
                        "indrajaal/perf/triple"
                        "perf test"
                        """{"perf":"test"}"""
                    |> ignore)
                let sorted = samples |> Array.sort
                let p99Ms = (percentile sorted 0.99) / 1000.0
                Expect.isLessThan p99Ms 5.0
                    (sprintf "Triple-write p99=%.2fms should be <5ms. %s"
                        p99Ms (summarize "triple-write" samples))
            }

            test "Triple-write with state vector p99 < 5ms" {
                ZenohPublish.clearNativeSession()
                let samples = collectSamples 200 (fun () ->
                    ZenohPublish.tryPublishWithStateVector
                        "CP-PERF-02"
                        "indrajaal/perf/boot"
                        "boot test"
                        "[1,1,1,0,0,0]"
                        """{"state_vector":"[1,1,1,0,0,0]"}"""
                    |> ignore)
                let sorted = samples |> Array.sort
                let p99Ms = (percentile sorted 0.99) / 1000.0
                Expect.isLessThan p99Ms 5.0
                    (sprintf "Triple-write+SV p99=%.2fms should be <5ms. %s"
                        p99Ms (summarize "triple-write-sv" samples))
            }

            test "Triple-write throughput > 1000 ops/sec" {
                ZenohPublish.clearNativeSession()
                let sw = Stopwatch.StartNew()
                let count = 1000
                for i in 1..count do
                    ZenohPublish.publish
                        (sprintf "CP-PERF-%03d" (i % 100))
                        "indrajaal/perf/throughput"
                        "throughput test"
                        (sprintf """{"i":%d}""" i)
                sw.Stop()
                let opsPerSec = float count / sw.Elapsed.TotalSeconds
                Expect.isGreaterThan opsPerSec 1000.0
                    (sprintf "Triple-write throughput should be >1000 ops/sec, got %.0f" opsPerSec)
            }
        ]

    // =========================================================================
    // L4: ExponentialBackoff Computation Latency
    // =========================================================================

    [<Tests>]
    let backoffPerf =
        testList "FFI.Perf.Backoff" [

            test "Backoff calculation < 1us per call" {
                let samples = collectSamples 1000 (fun () ->
                    for attempt in 0..20 do
                        ExponentialBackoff.calculate attempt 1000 60000 |> ignore)
                let sorted = samples |> Array.sort
                let avgPerCallUs = (samples |> Array.average) / 21.0
                Expect.isLessThan avgPerCallUs 1.0
                    (sprintf "Backoff calc should be <1us/call, got %.3fus" avgPerCallUs)
            }

            test "Backoff sequence generation is lazy (O(1) per element)" {
                // Warmup to avoid JIT overhead
                let _ = ExponentialBackoff.sequence 1000 60000 |> Seq.take 5 |> Seq.toArray
                let sw = Stopwatch.StartNew()
                let first10 = ExponentialBackoff.sequence 1000 60000 |> Seq.take 10 |> Seq.toArray
                sw.Stop()
                Expect.equal first10.Length 10 "Should produce 10 elements"
                Expect.isLessThan sw.Elapsed.TotalMilliseconds 10.0
                    "Lazy sequence should be <10ms for 10 elements (includes Seq.toArray materialization)"
            }
        ]

    // =========================================================================
    // L4: Session Open/Close Latency
    // =========================================================================

    [<Tests>]
    let sessionOpenClosePerf =
        testList "FFI.Perf.SessionLifecycle" [

            testAsync "Simulated session open < 200ms" {
                let sw = Stopwatch.StartNew()
                let config = SessionConfig.defaultConfig()
                let! r = SafeSession.OpenAsync(config) |> Async.AwaitTask
                sw.Stop()
                Expect.isOk r "Should succeed"
                // Simulated has 50ms built-in delay
                Expect.isLessThan sw.Elapsed.TotalMilliseconds 200.0
                    (sprintf "Open should be <200ms, got %.0fms" sw.Elapsed.TotalMilliseconds)
                match r with
                | Ok s -> do! s.CloseAsync() |> Async.AwaitTask
                | _ -> ()
            }

            testAsync "Session close < 10ms" {
                let config = SessionConfig.defaultConfig()
                let! r = SafeSession.OpenAsync(config) |> Async.AwaitTask
                match r with
                | Ok session ->
                    let sw = Stopwatch.StartNew()
                    do! session.CloseAsync() |> Async.AwaitTask
                    sw.Stop()
                    Expect.isLessThan sw.Elapsed.TotalMilliseconds 10.0
                        (sprintf "Close should be <10ms, got %.0fms" sw.Elapsed.TotalMilliseconds)
                | Error e -> failwithf "Open failed: %s" e.Message
            }
        ]

    // =========================================================================
    // L4: Memory Allocation Proxy Test
    // =========================================================================

    [<Tests>]
    let memoryTests =
        testList "FFI.Perf.Memory" [

            test "Key expression validation does not allocate excessively" {
                // Warm up
                for _ in 1..100 do
                    ZenohKeyExpr.validate "indrajaal/test/memory" |> ignore
                // Measure
                let before = GC.GetTotalMemory(true)
                let iterations = 10000
                for _ in 1..iterations do
                    ZenohKeyExpr.validate "indrajaal/test/memory" |> ignore
                let after = GC.GetTotalMemory(false)
                let bytesPerOp = float (after - before) / float iterations
                // Should be minimal — mostly string splits
                Expect.isLessThan bytesPerOp 500.0
                    (sprintf "Validation should alloc <500 bytes/op, got %.0f" bytesPerOp)
            }

            test "ZenohPublish triple-write memory bounded" {
                ZenohPublish.clearNativeSession()
                // Warm up
                for _ in 1..50 do
                    ZenohPublish.publish "CP-MEM-01" "indrajaal/mem/test" "test" """{"m":1}"""
                // Measure
                let before = GC.GetTotalMemory(true)
                let iterations = 1000
                for _ in 1..iterations do
                    ZenohPublish.publish "CP-MEM-02" "indrajaal/mem/test" "test" """{"m":2}"""
                let after = GC.GetTotalMemory(false)
                let bytesPerOp = float (after - before) / float iterations
                // Triple-write creates strings for stderr fallback + optional FFI + optional stdout
                // 8KB budget accounts for stderr formatting, DateTimeOffset.ToString("o"), and sprintf
                Expect.isLessThan bytesPerOp 8000.0
                    (sprintf "Triple-write should alloc <8KB/op, got %.0f bytes" bytesPerOp)
            }
        ]
