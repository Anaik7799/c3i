// =============================================================================
// ZenohNativeLifecycleTests.fs - Lifecycle tests for SafeSession/Publisher/Subscriber
// =============================================================================
// STAMP: SC-NAT-001 to SC-NAT-004, SC-SESS-005, SC-ZENOH-FFI-002
// Tests: L1 (Unit) — SafeSession, SafePublisher, SafeSubscriber, SimulatedMessageBus
// Coverage: Session open/close, publisher create/dispose, subscriber message delivery,
//           concurrent access, simulated pub/sub roundtrip, state transitions
// =============================================================================

namespace Cepaf.Tests.Unit.Core

open System
open System.Threading
open System.Threading.Tasks
open Expecto
open Cepaf.Zenoh.Core

module ZenohNativeLifecycleTests =

    // =========================================================================
    // Helpers
    // =========================================================================

    let private openSimulatedSession () =
        let config = SessionConfig.defaultConfig()
        SafeSession.OpenAsync(config).Result

    let private pubConfig key =
        { PublisherConfig.KeyExpr = key
          CongestionControl = "drop"
          Priority = 5
          Reliability = "reliable"
          Express = false }

    let private subConfig key =
        SubscriberConfig.create key

    // =========================================================================
    // L1: SafeSession Lifecycle (SC-NAT-002)
    // =========================================================================

    [<Tests>]
    let sessionLifecycleTests =
        testList "SafeSession.Lifecycle" [

            testAsync "OpenAsync creates valid session (native or simulated)" {
                let config = SessionConfig.defaultConfig()
                let! result = SafeSession.OpenAsync(config) |> Async.AwaitTask
                Expect.isOk result "OpenAsync should succeed"
                match result with
                | Ok session ->
                    Expect.isTrue session.IsValid "Session should be valid after open"
                    // In native-only mode with FFI available, session is native (not simulated)
                    let isNative = ZenohFfiBridge.isAvailable()
                    if isNative then
                        Expect.isFalse session.IsSimulated "Should be native when FFI available"
                    else
                        Expect.isTrue session.IsSimulated "Should be simulated without FFI"
                        Expect.stringStarts session.SessionId "sim-" "Simulated session ID should have sim- prefix"
                    do! session.CloseAsync() |> Async.AwaitTask
                | Error _ -> ()
            }

            testAsync "CloseAsync invalidates session" {
                match openSimulatedSession() with
                | Ok session ->
                    Expect.isTrue session.IsValid "Should be valid before close"
                    do! session.CloseAsync() |> Async.AwaitTask
                    Expect.isFalse session.IsValid "Should be invalid after close"
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            testAsync "CloseAsync is idempotent" {
                match openSimulatedSession() with
                | Ok session ->
                    do! session.CloseAsync() |> Async.AwaitTask
                    // Second close should not throw
                    do! session.CloseAsync() |> Async.AwaitTask
                    Expect.isFalse session.IsValid "Should remain invalid"
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            testAsync "IDisposable Dispose closes session" {
                let session =
                    match openSimulatedSession() with
                    | Ok s -> s
                    | Error e -> failwithf "Session open failed: %s" e.Message
                (session :> IDisposable).Dispose()
                Expect.isFalse session.IsValid "Session should be invalid after Dispose"
            }

            testAsync "Session has zero publishers and subscribers initially" {
                match openSimulatedSession() with
                | Ok session ->
                    Expect.equal session.PublisherCount 0 "Should have 0 publishers"
                    Expect.equal session.SubscriberCount 0 "Should have 0 subscribers"
                    do! session.CloseAsync() |> Async.AwaitTask
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            testAsync "Multiple sessions can coexist" {
                let config = SessionConfig.defaultConfig()
                let! r1 = SafeSession.OpenAsync(config) |> Async.AwaitTask
                let! r2 = SafeSession.OpenAsync(config) |> Async.AwaitTask
                Expect.isOk r1 "First session should open"
                Expect.isOk r2 "Second session should open"
                match r1, r2 with
                | Ok s1, Ok s2 ->
                    Expect.notEqual s1.SessionId s2.SessionId "Session IDs should be unique"
                    Expect.isTrue s1.IsValid "First should be valid"
                    Expect.isTrue s2.IsValid "Second should be valid"
                    do! s1.CloseAsync() |> Async.AwaitTask
                    do! s2.CloseAsync() |> Async.AwaitTask
                | _ -> ()
            }

            test "SessionConfig.defaultConfig has expected values" {
                let config = SessionConfig.defaultConfig()
                Expect.equal config.Endpoints ["tcp/localhost:7447"] "Default endpoint"
                Expect.equal config.Mode "client" "Default mode"
                Expect.equal config.ConnectTimeoutMs 5000 "Default timeout 5s per SC-OP-001"
                Expect.equal config.MaxReconnectAttempts 10 "Default max reconnect per SC-OP-004"
                Expect.equal config.ReconnectMaxDelayMs 60000 "Default max backoff 60s per SC-OP-002"
                Expect.isFalse config.EnableShm "SHM disabled by default"
            }

            test "SessionConfig.forEndpoint creates custom endpoint" {
                let config = SessionConfig.forEndpoint "tcp/zenoh-router:7447"
                Expect.equal config.Endpoints ["tcp/zenoh-router:7447"] "Custom endpoint"
            }

            test "SessionConfig.forEndpoints creates multiple endpoints" {
                let endpoints = ["tcp/z1:7447"; "tcp/z2:7448"; "tcp/z3:7449"]
                let config = SessionConfig.forEndpoints endpoints
                Expect.equal config.Endpoints endpoints "Multiple endpoints"
            }
        ]

    // =========================================================================
    // L1: SafePublisher Lifecycle (SC-NAT-002, SC-NAT-003)
    // =========================================================================

    [<Tests>]
    let publisherLifecycleTests =
        testList "SafePublisher.Lifecycle" [

            testAsync "Create publisher on valid session succeeds" {
                match openSimulatedSession() with
                | Ok session ->
                    match SafePublisher.Create(session, pubConfig "indrajaal/test/pub") with
                    | Ok pub' ->
                        Expect.equal session.PublisherCount 1 "Should have 1 publisher"
                        Expect.equal pub'.KeyExpr "indrajaal/test/pub" "KeyExpr should match"
                        Expect.equal pub'.MessageCount 0L "No messages yet"
                        (pub' :> IDisposable).Dispose()
                    | Error e -> failwithf "Publisher create failed: %s" e.Message
                    do! session.CloseAsync() |> Async.AwaitTask
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            testAsync "Create publisher with invalid key expression fails" {
                match openSimulatedSession() with
                | Ok session ->
                    let result = SafePublisher.Create(session, pubConfig "")
                    Expect.isError result "Empty key should fail"
                    let result2 = SafePublisher.Create(session, pubConfig "indrajaal//bad")
                    Expect.isError result2 "Double slash should fail"
                    Expect.equal session.PublisherCount 0 "No publishers registered on error"
                    do! session.CloseAsync() |> Async.AwaitTask
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            testAsync "Create publisher on closed session fails" {
                match openSimulatedSession() with
                | Ok session ->
                    do! session.CloseAsync() |> Async.AwaitTask
                    let result = SafePublisher.Create(session, pubConfig "indrajaal/test")
                    Expect.isError result "Should fail on closed session"
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            testAsync "Dispose unregisters publisher from session" {
                match openSimulatedSession() with
                | Ok session ->
                    match SafePublisher.Create(session, pubConfig "indrajaal/test/pub") with
                    | Ok pub' ->
                        Expect.equal session.PublisherCount 1 "Before dispose"
                        (pub' :> IDisposable).Dispose()
                        Expect.equal session.PublisherCount 0 "After dispose"
                    | Error e -> failwithf "Create failed: %s" e.Message
                    do! session.CloseAsync() |> Async.AwaitTask
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            testAsync "PutAsync increments message count" {
                match openSimulatedSession() with
                | Ok session ->
                    match SafePublisher.Create(session, pubConfig "indrajaal/test/pub") with
                    | Ok pub' ->
                        let! r1 = pub'.PutStringAsync("msg1") |> Async.AwaitTask
                        Expect.isOk r1 "First publish should succeed"
                        Expect.equal pub'.MessageCount 1L "Count after 1 publish"
                        let! r2 = pub'.PutStringAsync("msg2") |> Async.AwaitTask
                        Expect.isOk r2 "Second publish should succeed"
                        Expect.equal pub'.MessageCount 2L "Count after 2 publishes"
                        (pub' :> IDisposable).Dispose()
                    | Error e -> failwithf "Create failed: %s" e.Message
                    do! session.CloseAsync() |> Async.AwaitTask
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            testAsync "PutAsync on disposed publisher returns error" {
                match openSimulatedSession() with
                | Ok session ->
                    match SafePublisher.Create(session, pubConfig "indrajaal/test") with
                    | Ok pub' ->
                        (pub' :> IDisposable).Dispose()
                        let! result = pub'.PutStringAsync("should fail") |> Async.AwaitTask
                        Expect.isError result "Should fail on disposed publisher"
                    | Error e -> failwithf "Create failed: %s" e.Message
                    do! session.CloseAsync() |> Async.AwaitTask
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            testAsync "Multiple publishers on same session" {
                match openSimulatedSession() with
                | Ok session ->
                    let p1 = SafePublisher.Create(session, pubConfig "indrajaal/test/a")
                    let p2 = SafePublisher.Create(session, pubConfig "indrajaal/test/b")
                    let p3 = SafePublisher.Create(session, pubConfig "indrajaal/test/c")
                    Expect.isOk p1 "p1 should succeed"
                    Expect.isOk p2 "p2 should succeed"
                    Expect.isOk p3 "p3 should succeed"
                    Expect.equal session.PublisherCount 3 "Should have 3 publishers"
                    match p1 with Ok p -> (p :> IDisposable).Dispose() | _ -> ()
                    Expect.equal session.PublisherCount 2 "After disposing one"
                    do! session.CloseAsync() |> Async.AwaitTask
                    // Session close should clean up remaining publishers
                    Expect.equal session.PublisherCount 0 "After session close"
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            test "PublisherConfig.create sets reasonable defaults" {
                let cfg = PublisherConfig.create "indrajaal/test"
                Expect.equal cfg.KeyExpr "indrajaal/test" "KeyExpr"
                Expect.equal cfg.CongestionControl "block" "Default congestion control"
                Expect.equal cfg.Priority 5 "Default priority"
                Expect.equal cfg.Reliability "reliable" "Default reliability"
                Expect.isFalse cfg.Express "Express disabled by default"
            }

            test "PublisherConfig.highPriority sets priority 1" {
                let cfg = PublisherConfig.highPriority "indrajaal/critical"
                Expect.equal cfg.Priority 1 "High priority = 1"
            }

            test "PublisherConfig.bestEffort uses drop congestion" {
                let cfg = PublisherConfig.bestEffort "indrajaal/metrics"
                Expect.equal cfg.CongestionControl "drop" "Best effort drops"
                Expect.equal cfg.Reliability "best_effort" "Best effort reliability"
            }
        ]

    // =========================================================================
    // L1: SafeSubscriber Lifecycle (SC-NAT-002)
    // =========================================================================

    [<Tests>]
    let subscriberLifecycleTests =
        testList "SafeSubscriber.Lifecycle" [

            testAsync "Create subscriber on valid session succeeds" {
                match openSimulatedSession() with
                | Ok session ->
                    let received = ref 0
                    let handler (_: ZenohSample) = Interlocked.Increment(received) |> ignore
                    match SafeSubscriber.Create(session, subConfig "indrajaal/test/**", handler) with
                    | Ok sub ->
                        Expect.equal session.SubscriberCount 1 "Should have 1 subscriber"
                        Expect.equal sub.KeyExpr "indrajaal/test/**" "KeyExpr match"
                        Expect.equal sub.MessageCount 0L "No messages yet"
                        (sub :> IDisposable).Dispose()
                    | Error e -> failwithf "Subscriber create failed: %s" e.Message
                    do! session.CloseAsync() |> Async.AwaitTask
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            testAsync "Subscriber receives delivered samples" {
                match openSimulatedSession() with
                | Ok session ->
                    let received = System.Collections.Concurrent.ConcurrentBag<string>()
                    let handler (sample: ZenohSample) =
                        received.Add(ZenohSample.payloadString sample)
                    match SafeSubscriber.Create(session, subConfig "indrajaal/test", handler) with
                    | Ok sub ->
                        let sample = { ZenohSample.empty with
                                          KeyExpr = "indrajaal/test"
                                          Payload = System.Text.Encoding.UTF8.GetBytes("hello") }
                        sub.DeliverSample(sample)
                        sub.DeliverSample({ sample with Payload = System.Text.Encoding.UTF8.GetBytes("world") })
                        Expect.equal sub.MessageCount 2L "Should have 2 messages"
                        Expect.equal received.Count 2 "Handler called twice"
                        Expect.contains (received |> Seq.toList) "hello" "Should contain hello"
                        Expect.contains (received |> Seq.toList) "world" "Should contain world"
                        (sub :> IDisposable).Dispose()
                    | Error e -> failwithf "Create failed: %s" e.Message
                    do! session.CloseAsync() |> Async.AwaitTask
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            testAsync "Subscriber handler errors are caught (SC-MSG-003)" {
                match openSimulatedSession() with
                | Ok session ->
                    let handler (_: ZenohSample) = failwith "intentional handler error"
                    match SafeSubscriber.Create(session, subConfig "indrajaal/test", handler) with
                    | Ok sub ->
                        let sample = { ZenohSample.empty with KeyExpr = "indrajaal/test" }
                        // Should not throw despite handler failure
                        sub.DeliverSample(sample)
                        Expect.equal sub.MessageCount 1L "Count still increments"
                        (sub :> IDisposable).Dispose()
                    | Error e -> failwithf "Create failed: %s" e.Message
                    do! session.CloseAsync() |> Async.AwaitTask
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            testAsync "Create subscriber with invalid key expression fails" {
                match openSimulatedSession() with
                | Ok session ->
                    let handler (_: ZenohSample) = ()
                    let result = SafeSubscriber.Create(session, subConfig "", handler)
                    Expect.isError result "Empty key should fail"
                    Expect.equal session.SubscriberCount 0 "No subscribers on error"
                    do! session.CloseAsync() |> Async.AwaitTask
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            testAsync "Dispose unregisters subscriber" {
                match openSimulatedSession() with
                | Ok session ->
                    let handler (_: ZenohSample) = ()
                    match SafeSubscriber.Create(session, subConfig "indrajaal/test", handler) with
                    | Ok sub ->
                        Expect.equal session.SubscriberCount 1 "Before dispose"
                        (sub :> IDisposable).Dispose()
                        Expect.equal session.SubscriberCount 0 "After dispose"
                    | Error e -> failwithf "Create failed: %s" e.Message
                    do! session.CloseAsync() |> Async.AwaitTask
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            test "SubscriberConfig.create sets defaults per SC-MSG-003" {
                let cfg = SubscriberConfig.create "indrajaal/test"
                Expect.equal cfg.KeyExpr "indrajaal/test" "KeyExpr"
                Expect.equal cfg.Reliability "reliable" "Default reliable"
                Expect.isFalse cfg.MissDetection "Miss detection off by default"
                Expect.equal cfg.CallbackTimeoutMs 50 "50ms per SC-MSG-003"
            }
        ]

    // =========================================================================
    // L1: SimulatedMessageBus Pub/Sub Roundtrip
    // =========================================================================

    [<Tests>]
    let simulatedPubSubTests =
        testList "SimulatedMessageBus.PubSub" [

            testAsync "Publish delivers to matching subscriber" {
                match openSimulatedSession() with
                | Ok session ->
                    SimulatedMessageBus.clear()
                    let received = ref ""
                    let handler (sample: ZenohSample) =
                        received.Value <- ZenohSample.payloadString sample
                    match SafeSubscriber.Create(session, subConfig "indrajaal/test", handler) with
                    | Ok sub ->
                        SimulatedMessageBus.subscribe "indrajaal/test" sub
                        SimulatedMessageBus.publish "indrajaal/test" (System.Text.Encoding.UTF8.GetBytes("hello"))
                        Expect.equal received.Value "hello" "Should receive the message"
                        SimulatedMessageBus.unsubscribe "indrajaal/test" sub
                        (sub :> IDisposable).Dispose()
                    | Error e -> failwithf "Create failed: %s" e.Message
                    do! session.CloseAsync() |> Async.AwaitTask
                    SimulatedMessageBus.clear()
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            testAsync "Wildcard subscriber receives matching messages" {
                match openSimulatedSession() with
                | Ok session ->
                    SimulatedMessageBus.clear()
                    let messages = System.Collections.Concurrent.ConcurrentBag<string>()
                    let handler (sample: ZenohSample) =
                        messages.Add(sample.KeyExpr)
                    match SafeSubscriber.Create(session, subConfig "indrajaal/**", handler) with
                    | Ok sub ->
                        SimulatedMessageBus.subscribe "indrajaal/**" sub
                        SimulatedMessageBus.publish "indrajaal/test/a" [||]
                        SimulatedMessageBus.publish "indrajaal/test/b" [||]
                        SimulatedMessageBus.publish "indrajaal/deep/nested/topic" [||]
                        Expect.equal messages.Count 3 "Should receive all 3 messages"
                        SimulatedMessageBus.unsubscribe "indrajaal/**" sub
                        (sub :> IDisposable).Dispose()
                    | Error e -> failwithf "Create failed: %s" e.Message
                    do! session.CloseAsync() |> Async.AwaitTask
                    SimulatedMessageBus.clear()
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            test "Non-matching messages are not delivered" {
                SimulatedMessageBus.clear()
                let config = SessionConfig.defaultConfig()
                match SafeSession.OpenAsync(config).Result with
                | Ok session ->
                    let received = ref false
                    let handler (_: ZenohSample) = received.Value <- true
                    match SafeSubscriber.Create(session, subConfig "indrajaal/specific", handler) with
                    | Ok sub ->
                        SimulatedMessageBus.subscribe "indrajaal/specific" sub
                        SimulatedMessageBus.publish "indrajaal/other" [||]
                        Expect.isFalse received.Value "Should not receive non-matching message"
                        SimulatedMessageBus.unsubscribe "indrajaal/specific" sub
                        (sub :> IDisposable).Dispose()
                    | Error e -> failwithf "Create failed: %s" e.Message
                    session.CloseAsync().Wait()
                    SimulatedMessageBus.clear()
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            test "Multiple subscribers receive same message" {
                SimulatedMessageBus.clear()
                match openSimulatedSession() with
                | Ok session ->
                    let count1 = ref 0
                    let count2 = ref 0
                    let h1 (_: ZenohSample) = Interlocked.Increment(count1) |> ignore
                    let h2 (_: ZenohSample) = Interlocked.Increment(count2) |> ignore
                    match SafeSubscriber.Create(session, subConfig "indrajaal/test", h1),
                          SafeSubscriber.Create(session, subConfig "indrajaal/test", h2) with
                    | Ok s1, Ok s2 ->
                        SimulatedMessageBus.subscribe "indrajaal/test" s1
                        SimulatedMessageBus.subscribe "indrajaal/test" s2
                        SimulatedMessageBus.publish "indrajaal/test" [||]
                        Expect.equal count1.Value 1 "Sub1 received"
                        Expect.equal count2.Value 1 "Sub2 received"
                        SimulatedMessageBus.clear()
                        (s1 :> IDisposable).Dispose()
                        (s2 :> IDisposable).Dispose()
                    | _ -> failwith "Create failed"
                    session.CloseAsync().Wait()
                | Error e -> failwithf "Session open failed: %s" e.Message
            }
        ]

    // =========================================================================
    // L1: ZenohSample / ZenohHealth utility tests
    // =========================================================================

    [<Tests>]
    let typeUtilityTests =
        testList "ZenohTypes.Utilities" [

            test "ZenohSample.empty has expected defaults" {
                let s = ZenohSample.empty
                Expect.equal s.KeyExpr "" "Empty key"
                Expect.equal s.Payload [||] "Empty payload"
                Expect.equal s.Kind "put" "Default kind"
                Expect.isNone s.Timestamp "No timestamp"
                Expect.isNone s.SourceId "No source"
            }

            test "ZenohSample.payloadString decodes UTF-8" {
                let s = { ZenohSample.empty with Payload = System.Text.Encoding.UTF8.GetBytes("test 123") }
                Expect.equal (ZenohSample.payloadString s) "test 123" "UTF-8 decode"
            }

            test "ZenohSample.isDelete checks kind" {
                let put = { ZenohSample.empty with Kind = "put" }
                let del = { ZenohSample.empty with Kind = "delete" }
                Expect.isFalse (ZenohSample.isDelete put) "put is not delete"
                Expect.isTrue (ZenohSample.isDelete del) "delete is delete"
            }

            test "ZenohHealth.empty is disconnected" {
                let h = ZenohHealth.empty
                Expect.equal h.Status ConnectionStatus.Disconnected "Initial status"
                Expect.equal h.MessagesPublished 0L "No publishes"
                Expect.equal h.ErrorCount 0 "No errors"
                Expect.isFalse (ZenohHealth.isHealthy h) "Empty is not healthy"
            }

            test "ZenohHealth.recordPublish increments count" {
                let h = ZenohHealth.empty |> ZenohHealth.recordPublish |> ZenohHealth.recordPublish
                Expect.equal h.MessagesPublished 2L "Two publishes"
            }

            test "ZenohHealth.recordError increments error count" {
                let h = ZenohHealth.empty |> ZenohHealth.recordError
                Expect.equal h.ErrorCount 1 "One error"
            }

            test "ConnectionStatus properties" {
                Expect.isTrue ConnectionStatus.Connected.IsInConnectedState "Connected is connected"
                Expect.isFalse ConnectionStatus.Disconnected.IsInConnectedState "Disconnected is not connected"
                Expect.isTrue ConnectionStatus.Reconnecting.IsHealthy "Reconnecting is healthy"
                Expect.isFalse (ConnectionStatus.Failed "reason").IsHealthy "Failed is not healthy"
            }

            test "ZenohError messages are descriptive" {
                let errs = [
                    ZenohError.ConnectionFailed "timeout"
                    ZenohError.SessionClosed
                    ZenohError.InvalidKeyExpr("bad//key", "double slash")
                    ZenohError.PublishFailed("key", "dropped")
                    ZenohError.NativeError(-1, "segfault")
                    ZenohError.Disposed "Publisher"
                    ZenohError.QuorumFailed(2, 1)
                ]
                for e in errs do
                    Expect.isNotEmpty e.Message (sprintf "%A should have non-empty message" e)
            }
        ]

    // =========================================================================
    // L1: Concurrent Access Safety
    // =========================================================================

    [<Tests>]
    let concurrencyTests =
        testList "SafeSession.Concurrency" [

            testAsync "Concurrent publishes do not lose messages" {
                match openSimulatedSession() with
                | Ok session ->
                    match SafePublisher.Create(session, pubConfig "indrajaal/concurrent") with
                    | Ok pub' ->
                        let tasks =
                            [| for i in 1..100 ->
                                pub'.PutStringAsync(sprintf "msg-%d" i) |]
                        let! results =
                            tasks
                            |> Array.map Async.AwaitTask
                            |> Async.Parallel
                        let okCount = results |> Array.filter Result.isOk |> Array.length
                        Expect.equal okCount 100 "All 100 publishes should succeed"
                        Expect.equal pub'.MessageCount 100L "All 100 counted"
                        (pub' :> IDisposable).Dispose()
                    | Error e -> failwithf "Create failed: %s" e.Message
                    do! session.CloseAsync() |> Async.AwaitTask
                | Error e -> failwithf "Session open failed: %s" e.Message
            }

            test "Concurrent subscriber delivery" {
                SimulatedMessageBus.clear()
                match openSimulatedSession() with
                | Ok session ->
                    let count = ref 0
                    let handler (_: ZenohSample) = Interlocked.Increment(count) |> ignore
                    match SafeSubscriber.Create(session, subConfig "indrajaal/concurrent", handler) with
                    | Ok sub ->
                        SimulatedMessageBus.subscribe "indrajaal/concurrent" sub
                        // Publish 50 messages
                        for _ in 1..50 do
                            SimulatedMessageBus.publish "indrajaal/concurrent" [||]
                        Expect.equal count.Value 50 "All 50 delivered"
                        SimulatedMessageBus.clear()
                        (sub :> IDisposable).Dispose()
                    | Error e -> failwithf "Create failed: %s" e.Message
                    session.CloseAsync().Wait()
                | Error e -> failwithf "Session open failed: %s" e.Message
            }
        ]
