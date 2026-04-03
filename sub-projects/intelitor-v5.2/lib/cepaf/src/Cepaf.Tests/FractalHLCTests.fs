namespace Cepaf.Tests.Observability.Fractal

open Xunit
open Cepaf.Observability.Fractal
open System
open System.Threading

/// TDG Test Suite for Fractal HLC (Hybrid Logical Clock)
/// STAMP Compliance: SC-LOG-006 (L3+ logs MUST use HLC timestamps)
/// Total: 48 tests covering clock operations, comparison, serialization, and validation
module FractalHLCTests =

    // Helper to create HLC.Timestamp with explicit type
    let private mkTs (physical: int64) (counter: int) (nodeId: string) : HLC.Timestamp =
        { Physical = physical; Counter = counter; NodeId = nodeId }

    // ============================================================
    // TIMESTAMP GENERATION (12 tests)
    // ============================================================

    [<Fact>]
    let ``HLC.now returns valid timestamp`` () =
        HLC.reset()
        let ts = HLC.now()
        Assert.True(ts.Physical > 0L, "Physical time should be positive")
        Assert.True(ts.Counter >= 0, "Counter should be non-negative")
        Assert.False(String.IsNullOrEmpty(ts.NodeId), "NodeId should not be empty")

    [<Fact>]
    let ``HLC.now is monotonically increasing`` () =
        HLC.reset()
        let ts1 = HLC.now()
        let ts2 = HLC.now()
        let ts3 = HLC.now()
        Assert.True(HLC.happenedBefore ts1 ts2 || ts1 = ts2, "ts1 should <= ts2")
        Assert.True(HLC.happenedBefore ts2 ts3 || ts2 = ts3, "ts2 should <= ts3")

    [<Fact>]
    let ``HLC.now increments counter for same physical time`` () =
        HLC.reset()
        // Generate many timestamps quickly to hit same physical time
        let timestamps = [for _ in 1..100 -> HLC.now()]
        let counters = timestamps |> List.map (fun ts -> ts.Counter)
        // At least some should have incremented counters
        Assert.True(counters |> List.max > 0, "Counter should increment for rapid calls")

    [<Fact>]
    let ``HLC.now resets counter when physical time advances`` () =
        HLC.reset()
        let ts1 = HLC.now()
        Thread.Sleep(2) // Wait for physical time to advance
        let ts2 = HLC.now()
        if ts2.Physical > ts1.Physical then
            Assert.Equal(0, ts2.Counter)

    [<Fact>]
    let ``HLC.now preserves NodeId across calls`` () =
        HLC.reset()
        let ts1 = HLC.now()
        let ts2 = HLC.now()
        Assert.Equal(ts1.NodeId, ts2.NodeId)

    [<Fact>]
    let ``HLC.now generates unique timestamps`` () =
        HLC.reset()
        let timestamps = [for _ in 1..1000 -> HLC.now()]
        let unique = timestamps |> List.distinctBy (fun ts -> (ts.Physical, ts.Counter))
        Assert.Equal(timestamps.Length, unique.Length)

    [<Fact>]
    let ``HLC state reflects physical time`` () =
        HLC.reset()
        let _ = HLC.now()
        let state = HLC.getState()
        Assert.True(state.Physical > 0L, "State physical should be set")
        Assert.False(String.IsNullOrEmpty(state.NodeId), "State NodeId should be set")

    [<Fact>]
    let ``HLC.reset clears state`` () =
        let _ = HLC.now()
        HLC.reset()
        let state = HLC.getState()
        Assert.Equal(0L, state.Physical)
        Assert.Equal(0, state.Counter)

    [<Fact>]
    let ``HLC handles concurrent timestamp generation`` () =
        HLC.reset()
        let results = System.Collections.Concurrent.ConcurrentBag<HLC.Timestamp>()
        let threads =
            [for _ in 1..10 ->
                System.Threading.Tasks.Task.Run(fun () ->
                    for _ in 1..100 do
                        results.Add(HLC.now())
                )]
        System.Threading.Tasks.Task.WaitAll(threads |> Array.ofList)
        let timestamps = results |> Seq.toList
        Assert.Equal(1000, timestamps.Length)
        // All should be unique
        let unique = timestamps |> List.distinctBy (fun ts -> (ts.Physical, ts.Counter))
        Assert.Equal(1000, unique.Length)

    [<Fact>]
    let ``HLC timestamp physical time is in microseconds`` () =
        HLC.reset()
        let ts = HLC.now()
        // Physical time should be in microseconds (around 10^15 for current epoch)
        Assert.True(ts.Physical > 1_000_000_000_000_000L, "Physical time should be in microseconds")

    [<Fact>]
    let ``HLC counter caps at max value`` () =
        // This test verifies counter behavior at edge case
        HLC.reset()
        // Generate many timestamps to push counter high
        for _ in 1..65535 do
            HLC.now() |> ignore
        let ts = HLC.now()
        Assert.True(ts.Counter <= 65535, "Counter should not exceed max")

    [<Fact>]
    let ``HLC NodeId contains machine name`` () =
        HLC.reset()
        let ts = HLC.now()
        Assert.Contains(Environment.MachineName, ts.NodeId)

    // ============================================================
    // UPDATE / MERGE (10 tests)
    // ============================================================

    [<Fact>]
    let ``HLC.update advances from received timestamp`` () =
        HLC.reset()
        let received = mkTs (DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() * 1000L) 5 "other-node"
        let updated = HLC.update received
        Assert.True(updated.Physical >= received.Physical, "Should advance from received")

    [<Fact>]
    let ``HLC.update increments counter when physical times match`` () =
        HLC.reset()
        let local = HLC.now()
        let received: HLC.Timestamp = { local with Counter = local.Counter + 10 }
        let updated = HLC.update received
        Assert.True(updated.Counter > received.Counter, "Counter should increment")

    [<Fact>]
    let ``HLC.update uses local time when ahead`` () =
        HLC.reset()
        let _ = HLC.now() // Establish local time
        let oldReceived = mkTs 1000L 0 "old-node"
        let updated = HLC.update oldReceived
        Assert.True(updated.Physical > oldReceived.Physical, "Should use local time")

    [<Fact>]
    let ``HLC.merge combines timestamps correctly`` () =
        let ts1 = mkTs 1000000L 5 "node-1"
        let ts2 = mkTs 1000000L 3 "node-2"
        let merged = HLC.merge ts1 ts2
        Assert.Equal(1000000L, merged.Physical)
        Assert.True(merged.Counter > 5, "Merged counter should exceed max")

    [<Fact>]
    let ``HLC.merge takes higher physical time`` () =
        let ts1 = mkTs 1000000L 5 "node-1"
        let ts2 = mkTs 2000000L 3 "node-2"
        let merged = HLC.merge ts1 ts2
        Assert.Equal(2000000L, merged.Physical)

    [<Fact>]
    let ``HLC.merge preserves causality`` () =
        let ts1 = mkTs 1000000L 5 "node-1"
        let ts2 = mkTs 1000000L 5 "node-2"
        let merged = HLC.merge ts1 ts2
        Assert.True(HLC.happenedAfter merged ts1, "Merged should happen after ts1")
        Assert.True(HLC.happenedAfter merged ts2, "Merged should happen after ts2")

    [<Fact>]
    let ``HLC.update maintains monotonicity`` () =
        HLC.reset()
        let ts1 = HLC.now()
        let received = mkTs (ts1.Physical - 1000000L) 0 "past-node"
        let ts2 = HLC.update received
        Assert.True(HLC.happenedAfter ts2 ts1 || ts2 = ts1, "Should not go backwards")

    [<Fact>]
    let ``HLC.update with future timestamp`` () =
        HLC.reset()
        let futurePhysical = (DateTimeOffset.UtcNow.AddMinutes(5.0)).ToUnixTimeMilliseconds() * 1000L
        let received = mkTs futurePhysical 0 "future-node"
        let updated = HLC.update received
        Assert.True(updated.Physical >= futurePhysical, "Should accept future time")

    [<Fact>]
    let ``HLC merge is commutative in result ordering`` () =
        let ts1 = mkTs 1000000L 5 "node-1"
        let ts2 = mkTs 2000000L 3 "node-2"
        let merged1 = HLC.merge ts1 ts2
        let merged2 = HLC.merge ts2 ts1
        Assert.Equal(merged1.Physical, merged2.Physical)

    [<Fact>]
    let ``HLC update preserves local NodeId`` () =
        HLC.reset()
        let _ = HLC.now()
        let state = HLC.getState()
        let received = mkTs 1000L 0 "remote-node"
        let updated = HLC.update received
        Assert.Equal(state.NodeId, updated.NodeId)

    // ============================================================
    // COMPARISON (10 tests)
    // ============================================================

    [<Fact>]
    let ``HLC.compare returns -1 for earlier timestamp`` () =
        let ts1 = mkTs 1000L 0 "node"
        let ts2 = mkTs 2000L 0 "node"
        Assert.Equal(-1, HLC.compare ts1 ts2)

    [<Fact>]
    let ``HLC.compare returns 1 for later timestamp`` () =
        let ts1 = mkTs 2000L 0 "node"
        let ts2 = mkTs 1000L 0 "node"
        Assert.Equal(1, HLC.compare ts1 ts2)

    [<Fact>]
    let ``HLC.compare returns 0 for equal timestamps`` () =
        let ts1 = mkTs 1000L 5 "node"
        let ts2 = mkTs 1000L 5 "node"
        Assert.Equal(0, HLC.compare ts1 ts2)

    [<Fact>]
    let ``HLC.compare uses counter when physical times equal`` () =
        let ts1 = mkTs 1000L 5 "node"
        let ts2 = mkTs 1000L 10 "node"
        Assert.Equal(-1, HLC.compare ts1 ts2)

    [<Fact>]
    let ``HLC.compare uses NodeId as tiebreaker`` () =
        let ts1 = mkTs 1000L 5 "aaa"
        let ts2 = mkTs 1000L 5 "zzz"
        Assert.Equal(-1, HLC.compare ts1 ts2)

    [<Fact>]
    let ``HLC.happenedBefore correctly identifies ordering`` () =
        let ts1 = mkTs 1000L 0 "node"
        let ts2 = mkTs 2000L 0 "node"
        Assert.True(HLC.happenedBefore ts1 ts2)
        Assert.False(HLC.happenedBefore ts2 ts1)

    [<Fact>]
    let ``HLC.happenedAfter correctly identifies ordering`` () =
        let ts1 = mkTs 2000L 0 "node"
        let ts2 = mkTs 1000L 0 "node"
        Assert.True(HLC.happenedAfter ts1 ts2)
        Assert.False(HLC.happenedAfter ts2 ts1)

    [<Fact>]
    let ``HLC.areConcurrent detects concurrent events`` () =
        let ts1 = mkTs 1000L 0 "node-1"
        let ts2 = mkTs 1000L 0 "node-2"
        Assert.True(HLC.areConcurrent ts1 ts2)

    [<Fact>]
    let ``HLC.areConcurrent returns false for sequential events`` () =
        let ts1 = mkTs 1000L 0 "node"
        let ts2 = mkTs 2000L 0 "node"
        Assert.False(HLC.areConcurrent ts1 ts2)

    [<Fact>]
    let ``HLC.areConcurrent returns false for same node`` () =
        let ts1 = mkTs 1000L 0 "same-node"
        let ts2 = mkTs 1000L 5 "same-node"
        Assert.False(HLC.areConcurrent ts1 ts2)

    // ============================================================
    // ARITHMETIC (6 tests)
    // ============================================================

    [<Fact>]
    let ``HLC.addMs adds milliseconds correctly`` () =
        let ts = mkTs 1000000L 5 "node"
        let result = HLC.addMs ts 100L
        Assert.Equal(1100000L, result.Physical)
        Assert.Equal(0, result.Counter)

    [<Fact>]
    let ``HLC.diffMicros calculates difference`` () =
        let ts1 = mkTs 2000000L 0 "node"
        let ts2 = mkTs 1000000L 0 "node"
        Assert.Equal(1000000L, HLC.diffMicros ts1 ts2)

    [<Fact>]
    let ``HLC.diffMs calculates milliseconds difference`` () =
        let ts1 = mkTs 2000000L 0 "node"
        let ts2 = mkTs 1000000L 0 "node"
        Assert.Equal(1000L, HLC.diffMs ts1 ts2)

    [<Fact>]
    let ``HLC.addMs with zero has no effect on physical`` () =
        let ts = mkTs 1000000L 5 "node"
        let result = HLC.addMs ts 0L
        Assert.Equal(1000000L, result.Physical)

    [<Fact>]
    let ``HLC.diffMicros can be negative`` () =
        let ts1 = mkTs 1000000L 0 "node"
        let ts2 = mkTs 2000000L 0 "node"
        Assert.Equal(-1000000L, HLC.diffMicros ts1 ts2)

    [<Fact>]
    let ``HLC.addMs resets counter`` () =
        let ts = mkTs 1000000L 100 "node"
        let result = HLC.addMs ts 1L
        Assert.Equal(0, result.Counter)

    // ============================================================
    // SERIALIZATION (7 tests)
    // ============================================================

    [<Fact>]
    let ``HLC.toBytes produces 12 bytes`` () =
        let ts = mkTs 1000000L 5 "test-node"
        let bytes = HLC.toBytes ts
        Assert.Equal(12, bytes.Length)

    [<Fact>]
    let ``HLC.fromBytes roundtrips correctly`` () =
        let ts = mkTs 1234567890123456L 42 "test-node"
        let bytes = HLC.toBytes ts
        match HLC.fromBytes bytes (Some "test-node") with
        | Ok decoded ->
            Assert.Equal(ts.Physical, decoded.Physical)
            Assert.Equal(ts.Counter, decoded.Counter)
            Assert.Equal("test-node", decoded.NodeId)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``HLC.fromBytes fails on short input`` () =
        let bytes = [| 0uy; 1uy; 2uy |]
        match HLC.fromBytes bytes None with
        | Error _ -> Assert.True(true)
        | Ok _ -> Assert.Fail("Should fail on short input")

    [<Fact>]
    let ``HLC.toIso8601 produces valid format`` () =
        let ts = mkTs 1735123456789000L 42 "node"
        let iso = HLC.toIso8601 ts
        Assert.Contains(".", iso)
        Assert.EndsWith("0042", iso)

    [<Fact>]
    let ``HLC.toString produces readable format`` () =
        let ts = mkTs 1000000L 5 "node"
        let str = HLC.toString ts
        Assert.Equal("1000000.5@node", str)

    [<Fact>]
    let ``HLC.parse roundtrips with toString`` () =
        let ts = mkTs 1000000L 5 "test-node"
        let str = HLC.toString ts
        match HLC.parse str with
        | Ok parsed ->
            Assert.Equal(ts.Physical, parsed.Physical)
            Assert.Equal(ts.Counter, parsed.Counter)
            Assert.Equal(ts.NodeId, parsed.NodeId)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``HLC.parse handles minimal format`` () =
        match HLC.parse "1000000" with
        | Ok parsed ->
            Assert.Equal(1000000L, parsed.Physical)
            Assert.Equal(0, parsed.Counter)
        | Error e -> Assert.Fail(e)

    // ============================================================
    // VALIDATION / SC-LOG-006 (3 tests)
    // ============================================================

    [<Fact>]
    let ``HLC.validateForLevel passes for L3+ with valid HLC`` () =
        let ts = mkTs 1000000L 0 "node"
        Assert.Equal(Ok (), HLC.validateForLevel FractalLevel.L3 (Some ts))
        Assert.Equal(Ok (), HLC.validateForLevel FractalLevel.L4 (Some ts))
        Assert.Equal(Ok (), HLC.validateForLevel FractalLevel.L5 (Some ts))

    [<Fact>]
    let ``HLC.validateForLevel fails for L3+ without HLC`` () =
        match HLC.validateForLevel FractalLevel.L3 None with
        | Error msg -> Assert.Contains("SC-LOG-006", msg)
        | Ok _ -> Assert.Fail("Should fail without HLC")

    [<Fact>]
    let ``HLC.validateForLevel passes for L1/L2 without HLC`` () =
        Assert.Equal(Ok (), HLC.validateForLevel FractalLevel.L1 None)
        Assert.Equal(Ok (), HLC.validateForLevel FractalLevel.L2 None)
