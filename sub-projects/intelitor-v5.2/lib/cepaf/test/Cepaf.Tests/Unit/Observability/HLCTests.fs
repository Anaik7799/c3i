module Cepaf.Tests.Unit.Observability.HLCTests

open System
open Expecto
open Cepaf.Observability.Fractal.HLC

/// SC-TEST-HLC-001: Hybrid Logical Clock Unit Tests
/// Coverage: 100% of HLC module functions
[<Tests>]
let hlcTests =
    testList "HLC (Hybrid Logical Clock)" [

        testList "now" [
            test "returns valid timestamp with positive physical" {
                let ts = now ()
                Expect.isGreaterThan ts.Physical 0L "Physical should be positive"
            }

            test "returns non-negative counter" {
                let ts = now ()
                Expect.isGreaterThanOrEqual ts.Counter 0 "Counter should be >= 0"
            }

            test "returns valid node ID" {
                let ts = now ()
                Expect.isNotEmpty ts.NodeId "NodeId should not be empty"
            }

            test "successive calls have increasing timestamps" {
                let ts1 = now ()
                System.Threading.Thread.Sleep(1)
                let ts2 = now ()
                Expect.isGreaterThanOrEqual ts2.Physical ts1.Physical "Later HLC should have >= physical"
            }
        ]

        testList "update" [
            test "updates from received timestamp" {
                let received = { Physical = 100000L; Counter = 5; NodeId = "remote" }
                let updated = update received
                Expect.isGreaterThanOrEqual updated.Physical received.Physical "Should be at least received time"
            }

            test "increments counter for same physical time" {
                let received = { Physical = now().Physical; Counter = 10; NodeId = "remote" }
                let updated = update received
                Expect.isGreaterThan updated.Counter received.Counter "Counter should increase"
            }
        ]

        testList "compare" [
            test "equal timestamps return 0" {
                let ts1 = { Physical = 100L; Counter = 5; NodeId = "node1" }
                let ts2 = { Physical = 100L; Counter = 5; NodeId = "node1" }
                Expect.equal (compare ts1 ts2) 0 "Equal HLCs should compare as 0"
            }

            test "earlier physical is less" {
                let ts1 = { Physical = 99L; Counter = 5; NodeId = "node1" }
                let ts2 = { Physical = 100L; Counter = 5; NodeId = "node1" }
                Expect.isLessThan (compare ts1 ts2) 0 "Earlier physical should be less"
            }

            test "later physical is greater" {
                let ts1 = { Physical = 101L; Counter = 5; NodeId = "node1" }
                let ts2 = { Physical = 100L; Counter = 5; NodeId = "node1" }
                Expect.isGreaterThan (compare ts1 ts2) 0 "Later physical should be greater"
            }

            test "same physical, earlier counter is less" {
                let ts1 = { Physical = 100L; Counter = 4; NodeId = "node1" }
                let ts2 = { Physical = 100L; Counter = 5; NodeId = "node1" }
                Expect.isLessThan (compare ts1 ts2) 0 "Earlier counter should be less"
            }

            test "same physical and counter, compares by node ID" {
                let ts1 = { Physical = 100L; Counter = 5; NodeId = "aaa" }
                let ts2 = { Physical = 100L; Counter = 5; NodeId = "bbb" }
                Expect.isLessThan (compare ts1 ts2) 0 "Lower nodeId should be less"
            }
        ]

        testList "happenedBefore and happenedAfter" [
            test "happenedBefore returns true when first is earlier" {
                let ts1 = { Physical = 100L; Counter = 0; NodeId = "a" }
                let ts2 = { Physical = 200L; Counter = 0; NodeId = "a" }
                Expect.isTrue (happenedBefore ts1 ts2) "ts1 happened before ts2"
            }

            test "happenedAfter returns true when first is later" {
                let ts1 = { Physical = 200L; Counter = 0; NodeId = "a" }
                let ts2 = { Physical = 100L; Counter = 0; NodeId = "a" }
                Expect.isTrue (happenedAfter ts1 ts2) "ts1 happened after ts2"
            }
        ]

        testList "areConcurrent" [
            test "same physical, different nodes are concurrent" {
                let ts1 = { Physical = 100L; Counter = 0; NodeId = "node1" }
                let ts2 = { Physical = 100L; Counter = 0; NodeId = "node2" }
                Expect.isTrue (areConcurrent ts1 ts2) "Same time, different nodes = concurrent"
            }

            test "different physical times are not concurrent" {
                let ts1 = { Physical = 100L; Counter = 0; NodeId = "node1" }
                let ts2 = { Physical = 200L; Counter = 0; NodeId = "node2" }
                Expect.isFalse (areConcurrent ts1 ts2) "Different times = not concurrent"
            }
        ]

        testList "toBytes/fromBytes" [
            test "roundtrip preserves values" {
                let original = { Physical = 1234567890123L; Counter = 42; NodeId = "testnode" }
                let encoded = toBytes original
                match fromBytes encoded (Some original.NodeId) with
                | Ok decoded ->
                    Expect.equal decoded.Physical original.Physical "Physical should match"
                    Expect.equal decoded.Counter original.Counter "Counter should match"
                | Error err -> failtest $"Decode failed: {err}"
            }

            test "toBytes produces 12 bytes" {
                let ts = now ()
                let encoded = toBytes ts
                Expect.equal encoded.Length 12 "Encoded should be 12 bytes"
            }

            test "fromBytes handles zeros" {
                let zeros = Array.zeroCreate<byte> 12
                match fromBytes zeros None with
                | Ok decoded ->
                    Expect.equal decoded.Physical 0L "Zero bytes should decode to 0 physical"
                    Expect.equal decoded.Counter 0 "Zero bytes should decode to 0 counter"
                | Error err -> failtest $"Decode failed: {err}"
            }

            test "fromBytes rejects invalid length" {
                let short = Array.zeroCreate<byte> 5
                match fromBytes short None with
                | Error _ -> () // Expected
                | Ok _ -> failtest "Should reject short input"
            }
        ]

        testList "merge" [
            test "takes max physical" {
                let ts1 = { Physical = 100L; Counter = 5; NodeId = "a" }
                let ts2 = { Physical = 200L; Counter = 3; NodeId = "b" }
                let merged = merge ts1 ts2
                Expect.isGreaterThanOrEqual merged.Physical 200L "Merged should have max physical"
            }

            test "increments counter" {
                let ts1 = { Physical = 100L; Counter = 5; NodeId = "a" }
                let ts2 = { Physical = 100L; Counter = 3; NodeId = "b" }
                let merged = merge ts1 ts2
                Expect.isGreaterThan merged.Counter 5 "Merged should increment max counter"
            }
        ]

        testList "addMs and diffMs" [
            test "addMs adds milliseconds" {
                let ts = { Physical = 1000000L; Counter = 5; NodeId = "a" }
                let result = addMs ts 100L
                Expect.equal result.Physical (ts.Physical + 100000L) "Should add 100ms = 100000us"
                Expect.equal result.Counter 0 "Counter should reset"
            }

            test "diffMs calculates difference" {
                let ts1 = { Physical = 200000L; Counter = 0; NodeId = "a" }
                let ts2 = { Physical = 100000L; Counter = 0; NodeId = "a" }
                let diff = diffMs ts1 ts2
                Expect.equal diff 100L "Should be 100ms difference"
            }
        ]

        testList "toString and parse" [
            test "toString produces readable format" {
                let ts = { Physical = 100L; Counter = 5; NodeId = "node1" }
                let str = toString ts
                Expect.stringContains str "100" "Should contain physical"
                Expect.stringContains str "5" "Should contain counter"
                Expect.stringContains str "node1" "Should contain node ID"
            }

            test "parse roundtrips toString" {
                let original = { Physical = 12345L; Counter = 42; NodeId = "mynode" }
                let str = toString original
                match parse str with
                | Ok parsed ->
                    Expect.equal parsed.Physical original.Physical "Physical should match"
                    Expect.equal parsed.Counter original.Counter "Counter should match"
                | Error err -> failtest $"Parse failed: {err}"
            }
        ]

        testList "toIso8601" [
            test "produces ISO format" {
                let ts = now ()
                let iso = toIso8601 ts
                Expect.stringContains iso "T" "Should contain T separator"
                Expect.stringContains iso "." "Should contain decimal"
            }
        ]

        // Use testSequenced to prevent race conditions with shared mutable state
        testSequenced <| testList "state management" [
            test "getState returns current state" {
                // Call now() to update state, then verify
                let ts = now ()
                let state = getState ()
                // State.Physical should match what now() returned
                Expect.equal state.Physical ts.Physical "State should match now() result"
                Expect.isGreaterThan state.Physical 0L "Should have non-zero physical"
            }

            test "reset clears state" {
                reset ()
                let state = getState ()
                Expect.equal state.Physical 0L "Physical should be 0 after reset"
                Expect.equal state.Counter 0 "Counter should be 0 after reset"
                // Re-initialize state for other tests
                let _ = now ()
                ()
            }
        ]

        testList "validation" [
            test "L3 requires HLC timestamp" {
                match validateForLevel Cepaf.Observability.Fractal.FractalLevel.L3 None with
                | Error _ -> () // Expected
                | Ok _ -> failtest "L3 should require timestamp"
            }

            test "L3 accepts valid timestamp" {
                let ts = Some (now ())
                match validateForLevel Cepaf.Observability.Fractal.FractalLevel.L3 ts with
                | Ok _ -> ()
                | Error err -> failtest $"Should accept valid timestamp: {err}"
            }

            test "L1 doesn't require timestamp" {
                match validateForLevel Cepaf.Observability.Fractal.FractalLevel.L1 None with
                | Ok _ -> ()
                | Error err -> failtest $"L1 should not require timestamp: {err}"
            }
        ]

        testList "isWithinDrift" [
            test "current timestamp is within drift" {
                let ts = now ()
                Expect.isTrue (isWithinDrift ts 1000L) "Current timestamp should be within 1s drift"
            }

            test "old timestamp exceeds drift" {
                let old = { Physical = 1000L; Counter = 0; NodeId = "a" }
                Expect.isFalse (isWithinDrift old 1L) "Very old timestamp should exceed 1ms drift"
            }
        ]
    ]
