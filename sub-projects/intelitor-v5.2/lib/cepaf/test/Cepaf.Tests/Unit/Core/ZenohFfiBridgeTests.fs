// =============================================================================
// ZenohFfiBridgeTests.fs - Unit tests for Zenoh FFI Bridge
// =============================================================================
// STAMP: SC-ZENOH-FFI-001 to SC-ZENOH-FFI-025
// Tests: L1 (Unit) + L2 (Integration when ZENOH_USE_NATIVE=true)
// =============================================================================

namespace Cepaf.Tests.Unit.Core

open System
open Expecto
open Cepaf.Zenoh.Core

module ZenohFfiBridgeTests =

    // =========================================================================
    // L1: FFI Availability & Library Loading
    // =========================================================================

    [<Tests>]
    let availabilityTests =
        testList "ZenohFfiBridge.Availability" [
            test "isAvailable returns bool without crashing" {
                // SC-ZENOH-FFI-001: No panics across FFI
                // This should not throw even if libzenoh_ffi.so is not on LD_LIBRARY_PATH
                let result =
                    try
                        ZenohFfiBridge.isAvailable() |> ignore
                        true
                    with
                    | :? DllNotFoundException -> true  // Expected when .so not found
                    | :? EntryPointNotFoundException -> true  // Expected when wrong .so
                    | ex ->
                        // Any other exception is unexpected
                        false
                Expect.isTrue result "isAvailable should not throw unexpected exceptions"
            }

            test "isAvailable returns consistent results on repeated calls" {
                let r1 =
                    try ZenohFfiBridge.isAvailable()
                    with _ -> false
                let r2 =
                    try ZenohFfiBridge.isAvailable()
                    with _ -> false
                Expect.equal r1 r2 "isAvailable should be deterministic"
            }
        ]

    // =========================================================================
    // L1: Key Expression Validation
    // =========================================================================

    [<Tests>]
    let keyExprTests =
        testList "ZenohKeyExpr.Validation" [
            test "valid key expression passes" {
                let result = ZenohKeyExpr.validate "indrajaal/test/hello"
                Expect.isOk result "Simple key expression should be valid"
            }

            test "empty key expression fails" {
                let result = ZenohKeyExpr.validate ""
                Expect.isError result "Empty key should be invalid"
            }

            test "key with double slash fails" {
                let result = ZenohKeyExpr.validate "indrajaal//test"
                Expect.isError result "Double slash should be invalid"
            }

            test "key starting with slash fails" {
                let result = ZenohKeyExpr.validate "/indrajaal/test"
                Expect.isError result "Leading slash should be invalid"
            }

            test "key ending with slash fails" {
                let result = ZenohKeyExpr.validate "indrajaal/test/"
                Expect.isError result "Trailing slash should be invalid"
            }

            test "wildcard single segment is valid" {
                let result = ZenohKeyExpr.validate "indrajaal/*/test"
                Expect.isOk result "Single wildcard should be valid"
            }

            test "wildcard multi segment is valid" {
                let result = ZenohKeyExpr.validate "indrajaal/**"
                Expect.isOk result "Multi wildcard should be valid"
            }

            test "key with dots is valid" {
                let result = ZenohKeyExpr.validate "indrajaal/boot/state.vector"
                Expect.isOk result "Dots in segments should be valid"
            }

            test "key with hyphens is valid" {
                let result = ZenohKeyExpr.validate "indrajaal/ex-app-1/health"
                Expect.isOk result "Hyphens in segments should be valid"
            }

            test "key with underscores is valid" {
                let result = ZenohKeyExpr.validate "indrajaal/test_topic/sub_topic"
                Expect.isOk result "Underscores in segments should be valid"
            }

            test "topic depth <= 6 per SC-ZTEST-017" {
                // SC-ZTEST-017: Topic depth <= 6 levels
                let validTopic = "a/b/c/d/e/f"
                let result = ZenohKeyExpr.validate validTopic
                Expect.isOk result "6-level topic should be valid"

                let parts = validTopic.Split('/')
                Expect.isLessThanOrEqual parts.Length 6 "Should have <= 6 levels"
            }
        ]

    // =========================================================================
    // L1: Key Expression Matching
    // =========================================================================

    [<Tests>]
    let keyExprMatchTests =
        testList "ZenohKeyExpr.Matching" [
            test "exact match" {
                Expect.isTrue
                    (ZenohKeyExpr.matches "indrajaal/test" "indrajaal/test")
                    "Exact key should match exact pattern"
            }

            test "single wildcard matches one segment" {
                Expect.isTrue
                    (ZenohKeyExpr.matches "indrajaal/*/health" "indrajaal/app1/health")
                    "Single wildcard should match one segment"
            }

            test "single wildcard does not match multiple segments" {
                Expect.isFalse
                    (ZenohKeyExpr.matches "indrajaal/*/health" "indrajaal/a/b/health")
                    "Single wildcard should not match multiple segments"
            }

            test "double wildcard matches zero segments" {
                Expect.isTrue
                    (ZenohKeyExpr.matches "indrajaal/**" "indrajaal")
                    "Double wildcard at end matches zero additional segments"
            }

            test "double wildcard matches multiple segments" {
                Expect.isTrue
                    (ZenohKeyExpr.matches "indrajaal/**" "indrajaal/a/b/c/d")
                    "Double wildcard should match multiple segments"
            }

            test "no match on different prefix" {
                Expect.isFalse
                    (ZenohKeyExpr.matches "indrajaal/test" "other/test")
                    "Different prefix should not match"
            }

            test "join produces valid key" {
                let key = ZenohKeyExpr.join ["indrajaal"; "boot"; "preflight"]
                Expect.equal key "indrajaal/boot/preflight" "Join should concatenate with /"
            }

            test "parts splits correctly" {
                let parts = ZenohKeyExpr.parts "indrajaal/boot/preflight"
                Expect.equal parts ["indrajaal"; "boot"; "preflight"] "Parts should split on /"
            }
        ]

    // =========================================================================
    // L1: Null Handle Safety (SC-ZENOH-FFI-004)
    // =========================================================================

    [<Tests>]
    let nullSafetyTests =
        testList "ZenohFfiBridge.NullSafety" [
            test "closeSession with zero handle does not crash" {
                // SC-ZENOH-FFI-002: Safe to call multiple times
                ZenohFfiBridge.closeSession (nativeint 0)
                Expect.isTrue true "closeSession(0) should be a no-op"
            }

            test "isConnected with zero handle returns false" {
                let result = ZenohFfiBridge.isConnected (nativeint 0)
                Expect.isFalse result "isConnected(0) should return false"
            }

            test "publish with zero handle returns error" {
                let result = ZenohFfiBridge.publish (nativeint 0) "test" [||]
                Expect.isError result "publish(0) should return Error"
            }

            test "subscribe with zero handle returns error" {
                let result = ZenohFfiBridge.subscribe (nativeint 0) "test"
                Expect.isError result "subscribe(0) should return Error"
            }

            test "poll with zero handle returns error" {
                let result = ZenohFfiBridge.poll (nativeint 0) 10
                Expect.isError result "poll(0) should return Error"
            }

            test "get with zero handle returns error" {
                let result = ZenohFfiBridge.get (nativeint 0) "test" 1000
                Expect.isError result "get(0) should return Error"
            }

            test "sessionStats with zero handle returns error" {
                let result = ZenohFfiBridge.sessionStats (nativeint 0)
                Expect.isError result "sessionStats(0) should return Error"
            }

            test "unsubscribe with zero handle does not crash" {
                ZenohFfiBridge.unsubscribe (nativeint 0)
                Expect.isTrue true "unsubscribe(0) should be a no-op"
            }
        ]

    // =========================================================================
    // L1: NativeSession/NativeSubscription IDisposable
    // =========================================================================

    [<Tests>]
    let disposableTests =
        testList "NativeSession.Disposable" [
            test "NativeSession.Open with unreachable router returns error" {
                // This tests the happy path error case — no router available
                let config = {
                    SessionConfig.defaultConfig() with
                        Endpoints = ["tcp/localhost:19999"] // Non-existent port
                }
                // This will fail because ZENOH_USE_NATIVE is not set (or .so not on path)
                // Either way, it should return an error, not crash
                let result =
                    try
                        NativeSession.Open(config)
                    with
                    | :? DllNotFoundException -> Error (ZenohError.ConnectionFailed "DLL not found")
                    | ex -> Error (ZenohError.ConnectionFailed ex.Message)
                Expect.isError result "Open with unreachable router should fail gracefully"
            }
        ]

    // =========================================================================
    // L1: ExponentialBackoff (SC-OP-002)
    // =========================================================================

    [<Tests>]
    let backoffTests =
        testList "ExponentialBackoff" [
            test "attempt 0 returns base delay" {
                let delay = ExponentialBackoff.calculate 0 1000 60000
                Expect.equal delay 1000 "Attempt 0 should return base delay"
            }

            test "attempt 1 doubles delay" {
                let delay = ExponentialBackoff.calculate 1 1000 60000
                Expect.equal delay 2000 "Attempt 1 should double"
            }

            test "delay is capped at max" {
                let delay = ExponentialBackoff.calculate 20 1000 60000
                Expect.equal delay 60000 "Should be capped at max"
            }

            test "default backoff uses 1s base 60s max" {
                let d0 = ExponentialBackoff.defaultBackoff 0
                let d1 = ExponentialBackoff.defaultBackoff 1
                Expect.equal d0 1000 "Default base = 1s"
                Expect.equal d1 2000 "Default second attempt = 2s"
            }

            test "backoff sequence is monotonically non-decreasing" {
                let delays = ExponentialBackoff.sequence 1000 60000 |> Seq.take 15 |> Seq.toList
                let pairs = List.pairwise delays
                for (a, b) in pairs do
                    Expect.isLessThanOrEqual a b "Backoff should be non-decreasing"
            }
        ]

    // =========================================================================
    // L1: SimulatedMessageBus
    // =========================================================================

    [<Tests>]
    let simulatedBusTests =
        testList "SimulatedMessageBus" [
            test "clear does not crash" {
                SimulatedMessageBus.clear()
                Expect.isTrue true "Clear should succeed"
            }

            test "publish without subscribers does not crash" {
                SimulatedMessageBus.clear()
                SimulatedMessageBus.publish "indrajaal/test" [||]
                Expect.isTrue true "Publish without subscribers should be a no-op"
            }
        ]

    // =========================================================================
    // L1: ZenohPublish Triple-Write Pattern (SC-ZTEST-008)
    // =========================================================================

    [<Tests>]
    let tripleWriteTests =
        testList "ZenohPublish.TripleWrite" [
            test "tryPublish returns Ok with no native session" {
                // SC-ZTEST-008: Log fallback should always work
                Cepaf.Mesh.ZenohPublish.clearNativeSession()
                let result = Cepaf.Mesh.ZenohPublish.tryPublish
                                "CP-TEST-01"
                                "indrajaal/test/unit"
                                "Unit test message"
                                """{"test":true}"""
                Expect.isOk result "tryPublish should succeed with log fallback only"
            }

            test "tryPublishWithStateVector returns Ok" {
                Cepaf.Mesh.ZenohPublish.clearNativeSession()
                let result = Cepaf.Mesh.ZenohPublish.tryPublishWithStateVector
                                "CP-BOOT-01"
                                "indrajaal/boot/preflight/start"
                                "Boot started"
                                "[0,0,0,0,0,0]"
                                """{"phase":"preflight","state_vector":"[0,0,0,0,0,0]"}"""
                Expect.isOk result "tryPublishWithStateVector should succeed"
            }

            test "publish fire-and-forget does not throw" {
                Cepaf.Mesh.ZenohPublish.clearNativeSession()
                // Should not throw
                Cepaf.Mesh.ZenohPublish.publish
                    "CP-SMOKE-01"
                    "indrajaal/smoke/batch/start"
                    "Smoke test started"
                    """{"batch":"test"}"""
                Expect.isTrue true "Fire-and-forget publish should not throw"
            }
        ]

    // =========================================================================
    // L1: SafeSession / SafePublisher (Simulated Mode)
    // =========================================================================

    [<Tests>]
    let safeSessionTests =
        testList "SafeSession.Simulated" [
            testAsync "OpenAsync returns Ok (native or simulated)" {
                let config = SessionConfig.defaultConfig()
                let! result = SafeSession.OpenAsync(config) |> Async.AwaitTask
                Expect.isOk result "OpenAsync should succeed"
                match result with
                | Ok session ->
                    Expect.isTrue session.IsValid "Session should be valid"
                    // In native-only mode with FFI available, IsSimulated is false
                    // In environments without libzenoh_ffi.so, IsSimulated is true
                    let isNative = ZenohFfiBridge.isAvailable()
                    if isNative then
                        Expect.isFalse session.IsSimulated "Should be native when FFI available"
                    else
                        Expect.isTrue session.IsSimulated "Should be simulated without FFI"
                    Expect.equal session.PublisherCount 0 "No publishers initially"
                    Expect.equal session.SubscriberCount 0 "No subscribers initially"
                    do! session.CloseAsync() |> Async.AwaitTask
                    Expect.isFalse session.IsValid "Session should be invalid after close"
                | Error _ -> ()
            }

            testAsync "SafePublisher publishes in simulated mode" {
                let config = SessionConfig.defaultConfig()
                let! result = SafeSession.OpenAsync(config) |> Async.AwaitTask
                match result with
                | Ok session ->
                    let pubConfig = { PublisherConfig.KeyExpr = "indrajaal/test/pub"; CongestionControl = "drop"; Priority = 5; Reliability = "reliable"; Express = false }
                    match SafePublisher.Create(session, pubConfig) with
                    | Ok pub' ->
                        Expect.equal session.PublisherCount 1 "Should have 1 publisher"
                        let! putResult = pub'.PutStringAsync("hello") |> Async.AwaitTask
                        Expect.isOk putResult "PutStringAsync should succeed"
                        Expect.equal pub'.MessageCount 1L "Should have 1 message"
                        (pub' :> System.IDisposable).Dispose()
                        Expect.equal session.PublisherCount 0 "Publisher should be unregistered"
                    | Error e -> failwithf "Publisher create failed: %A" e
                    do! session.CloseAsync() |> Async.AwaitTask
                | Error e -> failwithf "Session open failed: %A" e
            }
        ]

    // =========================================================================
    // L1: FfiMetrics Observability (SC-ZENOH-FFI-040)
    // =========================================================================

    [<Tests>]
    let metricsTests =
        testList "ZenohFfiBridge.Metrics" [
            test "getMetrics returns valid JSON" {
                // SC-ZENOH-FFI-040: Metrics must be observable via FFI
                match ZenohFfiBridge.getMetrics() with
                | Ok json ->
                    Expect.isNotEmpty json "Metrics JSON should not be empty"
                    let doc = System.Text.Json.JsonDocument.Parse(json)
                    Expect.isNotNull doc "Should parse as valid JSON"
                    doc.Dispose()
                | Error e -> failwithf "getMetrics failed: %A" e
            }

            test "getMetrics includes session counters" {
                match ZenohFfiBridge.getMetrics() with
                | Ok json ->
                    Expect.stringContains json "sessions_opened" "Should have sessions_opened"
                    Expect.stringContains json "sessions_closed" "Should have sessions_closed"
                    Expect.stringContains json "active_sessions" "Should have active_sessions"
                    Expect.stringContains json "session_open_errors" "Should have session_open_errors"
                    Expect.stringContains json "session_open_timeouts" "Should have session_open_timeouts"
                | Error e -> failwithf "getMetrics failed: %A" e
            }

            test "getMetrics includes publish counters" {
                match ZenohFfiBridge.getMetrics() with
                | Ok json ->
                    Expect.stringContains json "publish_total" "Should have publish_total"
                    Expect.stringContains json "publish_ok" "Should have publish_ok"
                    Expect.stringContains json "publish_errors" "Should have publish_errors"
                    Expect.stringContains json "publish_latency_max_us" "Should have latency max"
                    Expect.stringContains json "publish_latency_last_us" "Should have latency last"
                | Error e -> failwithf "getMetrics failed: %A" e
            }

            test "getMetrics includes subscribe/poll/get counters" {
                match ZenohFfiBridge.getMetrics() with
                | Ok json ->
                    Expect.stringContains json "subscribe_total" "Should have subscribe_total"
                    Expect.stringContains json "poll_total" "Should have poll_total"
                    Expect.stringContains json "poll_messages" "Should have poll_messages"
                    Expect.stringContains json "get_total" "Should have get_total"
                | Error e -> failwithf "getMetrics failed: %A" e
            }

            test "getMetrics includes safety counters" {
                match ZenohFfiBridge.getMetrics() with
                | Ok json ->
                    Expect.stringContains json "panic_count" "Should have panic_count"
                    Expect.stringContains json "null_rejected" "Should have null_rejected"
                    Expect.stringContains json "ffi_calls_total" "Should have ffi_calls_total"
                | Error e -> failwithf "getMetrics failed: %A" e
            }

            test "getMetrics includes latency histogram" {
                match ZenohFfiBridge.getMetrics() with
                | Ok json ->
                    Expect.stringContains json "latency_histogram" "Should have latency_histogram"
                    Expect.stringContains json "under_1ms" "Should have under_1ms bucket"
                    Expect.stringContains json "1ms_to_10ms" "Should have 1ms_to_10ms bucket"
                    Expect.stringContains json "10ms_to_100ms" "Should have 10ms_to_100ms bucket"
                    Expect.stringContains json "over_100ms" "Should have over_100ms bucket"
                | Error e -> failwithf "getMetrics failed: %A" e
            }

            test "getMetrics includes invariant verification (12 total)" {
                match ZenohFfiBridge.getMetrics() with
                | Ok json ->
                    Expect.stringContains json "invariants_passing" "Should include invariant results"
                    Expect.stringContains json "invariants_total" "Should include invariant total"
                    Expect.stringContains json "semaphore_capacity" "Should include semaphore capacity"
                | Error e -> failwithf "getMetrics failed: %A" e
            }

            test "getMetrics tracks null handle rejections (INV-9)" {
                // Call with null handle to trigger null_rejected counter
                let _ = ZenohFfiBridge.isConnected (nativeint 0)
                match ZenohFfiBridge.getMetrics() with
                | Ok json ->
                    Expect.stringContains json "null_rejected" "Should track null rejections"
                | Error e -> failwithf "getMetrics failed: %A" e
            }

            test "getMetrics ffi_calls_total increments on each call" {
                // Get metrics twice — ffi_calls_total should increase
                match ZenohFfiBridge.getMetrics(), ZenohFfiBridge.getMetrics() with
                | Ok json1, Ok json2 ->
                    let doc1 = System.Text.Json.JsonDocument.Parse(json1)
                    let doc2 = System.Text.Json.JsonDocument.Parse(json2)
                    let calls1 = doc1.RootElement.GetProperty("ffi_calls_total").GetInt64()
                    let calls2 = doc2.RootElement.GetProperty("ffi_calls_total").GetInt64()
                    Expect.isGreaterThan calls2 calls1 "ffi_calls_total should increment"
                    doc1.Dispose()
                    doc2.Dispose()
                | _ -> failwith "getMetrics failed"
            }
        ]

    // =========================================================================
    // L1: Formal Invariant Verification (SC-ZENOH-FFI-050, INV-1 to INV-12)
    // =========================================================================

    [<Tests>]
    let verifyTests =
        testList "ZenohFfiBridge.Verify" [
            test "verify returns all 12 invariants passing" {
                // SC-ZENOH-FFI-050: Runtime invariant checking
                let passing = ZenohFfiBridge.verify()
                Expect.isGreaterThanOrEqual passing 0 "Verify should return >= 0"
                Expect.equal passing 12 "All 12 invariants should pass"
            }

            test "verify is idempotent" {
                let r1 = ZenohFfiBridge.verify()
                let r2 = ZenohFfiBridge.verify()
                Expect.equal r1 r2 "Verify should be deterministic"
            }

            test "verifyDetailed returns valid JSON with all 12 invariants" {
                match ZenohFfiBridge.verifyDetailed() with
                | Ok json ->
                    let doc = System.Text.Json.JsonDocument.Parse(json)
                    let root = doc.RootElement
                    let passing = root.GetProperty("passing").GetInt32()
                    let total = root.GetProperty("total").GetInt32()
                    let allPass = root.GetProperty("all_pass").GetBoolean()
                    Expect.equal total 12 "Should check 12 invariants"
                    Expect.equal passing 12 "All 12 should pass"
                    Expect.isTrue allPass "all_pass should be true"
                    // Verify each invariant key exists
                    let inv = root.GetProperty("invariants")
                    for i in 1..12 do
                        let key = sprintf "INV-%d" i
                        let found = inv.EnumerateObject() |> Seq.exists (fun p -> p.Name.StartsWith(key))
                        Expect.isTrue found (sprintf "%s should be present in details" key)
                    doc.Dispose()
                | Error e -> failwithf "verifyDetailed failed: %A" e
            }

            test "verifyDetailed includes diagnostic values" {
                match ZenohFfiBridge.verifyDetailed() with
                | Ok json ->
                    // Verify INV-2 includes concurrency limit
                    Expect.stringContains json "limit" "INV-2 should include semaphore limit"
                    // Verify INV-5 includes conservation values
                    Expect.stringContains json "opened" "INV-5 should include opened count"
                    Expect.stringContains json "closed" "INV-5 should include closed count"
                    // Verify INV-8 includes latency readings
                    Expect.stringContains json "max1_us" "INV-8 should include first max read"
                    Expect.stringContains json "max2_us" "INV-8 should include second max read"
                | Error e -> failwithf "verifyDetailed failed: %A" e
            }

            test "INV-2 bounded concurrency holds (active <= semaphore capacity)" {
                // INV-2: active_sessions <= SEMAPHORE_CAPACITY
                match ZenohFfiBridge.verifyDetailed() with
                | Ok json ->
                    let doc = System.Text.Json.JsonDocument.Parse(json)
                    let inv = doc.RootElement.GetProperty("invariants")
                    let inv2 = inv.GetProperty("INV-2_bounded_concurrency")
                    Expect.isTrue (inv2.GetProperty("pass").GetBoolean()) "INV-2 should pass"
                    let limit = inv2.GetProperty("limit").GetInt32()
                    Expect.equal limit 2 "Semaphore capacity should be 2"
                    doc.Dispose()
                | Error e -> failwithf "verifyDetailed failed: %A" e
            }

            test "INV-5 conservation holds after session open/close cycle" {
                let config = SessionConfig.defaultConfig()
                match ZenohFfiBridge.openSession config with
                | Ok handle ->
                    ZenohFfiBridge.closeSession handle
                    let passing = ZenohFfiBridge.verify()
                    Expect.equal passing 12 "All 12 invariants should hold after open/close"
                | Error _ ->
                    // Session open may fail (no router), invariants still hold
                    let passing = ZenohFfiBridge.verify()
                    Expect.equal passing 12 "All 12 invariants should hold on open failure"
            }

            test "INV-6 panic safety — panics bounded by calls" {
                match ZenohFfiBridge.verifyDetailed() with
                | Ok json ->
                    let doc = System.Text.Json.JsonDocument.Parse(json)
                    let inv = doc.RootElement.GetProperty("invariants")
                    let inv6 = inv.GetProperty("INV-6_panic_safety")
                    Expect.isTrue (inv6.GetProperty("pass").GetBoolean()) "INV-6 should pass"
                    let panics = inv6.GetProperty("panics").GetInt64()
                    let totalCalls = inv6.GetProperty("total_calls").GetInt64()
                    Expect.isLessThanOrEqual panics totalCalls "Panics should be <= total calls"
                    Expect.equal panics 0L "No panics should have occurred"
                    doc.Dispose()
                | Error e -> failwithf "verifyDetailed failed: %A" e
            }

            test "INV-7 publish accounting holds after null-handle publishes" {
                // Publish with null handle — errors should be tracked
                let _ = ZenohFfiBridge.publish (nativeint 0) "test/inv7" [||]
                let _ = ZenohFfiBridge.publish (nativeint 0) "test/inv7" [||]
                match ZenohFfiBridge.verifyDetailed() with
                | Ok json ->
                    let doc = System.Text.Json.JsonDocument.Parse(json)
                    let inv = doc.RootElement.GetProperty("invariants")
                    let inv7 = inv.GetProperty("INV-7_publish_accounting")
                    Expect.isTrue (inv7.GetProperty("pass").GetBoolean()) "INV-7 should pass"
                    let total = inv7.GetProperty("total").GetInt64()
                    let ok = inv7.GetProperty("ok").GetInt64()
                    let errors = inv7.GetProperty("errors").GetInt64()
                    Expect.equal total (ok + errors) "total = ok + errors"
                    doc.Dispose()
                | Error e -> failwithf "verifyDetailed failed: %A" e
            }

            test "INV-8 monotone max latency (no decrement)" {
                match ZenohFfiBridge.verifyDetailed() with
                | Ok json ->
                    let doc = System.Text.Json.JsonDocument.Parse(json)
                    let inv = doc.RootElement.GetProperty("invariants")
                    let inv8 = inv.GetProperty("INV-8_monotone_max_latency")
                    Expect.isTrue (inv8.GetProperty("pass").GetBoolean()) "INV-8 should pass"
                    let max1 = inv8.GetProperty("max1_us").GetInt64()
                    let max2 = inv8.GetProperty("max2_us").GetInt64()
                    Expect.isGreaterThanOrEqual max2 max1 "Second read >= first read"
                    doc.Dispose()
                | Error e -> failwithf "verifyDetailed failed: %A" e
            }

            test "INV-9 null safety — rejections bounded by calls" {
                // Trigger some null rejections
                let _ = ZenohFfiBridge.isConnected (nativeint 0)
                let _ = ZenohFfiBridge.publish (nativeint 0) "test" [||]
                match ZenohFfiBridge.verifyDetailed() with
                | Ok json ->
                    let doc = System.Text.Json.JsonDocument.Parse(json)
                    let inv = doc.RootElement.GetProperty("invariants")
                    let inv9 = inv.GetProperty("INV-9_null_safety")
                    Expect.isTrue (inv9.GetProperty("pass").GetBoolean()) "INV-9 should pass"
                    let nulls = inv9.GetProperty("null_rejected").GetInt64()
                    let calls = inv9.GetProperty("total_calls").GetInt64()
                    Expect.isLessThanOrEqual nulls calls "Null rejections <= total calls"
                    Expect.isGreaterThan nulls 0L "Should have recorded null rejections"
                    doc.Dispose()
                | Error e -> failwithf "verifyDetailed failed: %A" e
            }

            test "INV-10/11/12 accounting for subscribe/poll/get" {
                // These all start at 0=0+0 so should trivially pass
                match ZenohFfiBridge.verifyDetailed() with
                | Ok json ->
                    let doc = System.Text.Json.JsonDocument.Parse(json)
                    let inv = doc.RootElement.GetProperty("invariants")
                    let inv10 = inv.GetProperty("INV-10_subscribe_accounting")
                    let inv11 = inv.GetProperty("INV-11_poll_accounting")
                    let inv12 = inv.GetProperty("INV-12_get_accounting")
                    Expect.isTrue (inv10.GetProperty("pass").GetBoolean()) "INV-10 should pass"
                    Expect.isTrue (inv11.GetProperty("pass").GetBoolean()) "INV-11 should pass"
                    Expect.isTrue (inv12.GetProperty("pass").GetBoolean()) "INV-12 should pass"
                    doc.Dispose()
                | Error e -> failwithf "verifyDetailed failed: %A" e
            }

            test "all 12 invariants verified after mixed operations" {
                // Do a mix of operations, then verify everything holds
                let _ = ZenohFfiBridge.isConnected (nativeint 0) // null rejection
                let _ = ZenohFfiBridge.publish (nativeint 0) "test" [||] // null publish
                let _ = ZenohFfiBridge.subscribe (nativeint 0) "test" // null subscribe
                let _ = ZenohFfiBridge.poll (nativeint 0) 10 // null poll
                let _ = ZenohFfiBridge.get (nativeint 0) "test" 100 // null get
                ZenohFfiBridge.closeSession (nativeint 0) // null close (no-op)
                ZenohFfiBridge.unsubscribe (nativeint 0) // null unsub (no-op)

                let passing = ZenohFfiBridge.verify()
                Expect.equal passing 12 "All 12 invariants should hold after mixed null ops"
            }
        ]
