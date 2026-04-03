# Zenoh Runtime Coverage Analysis Plan

**Version**: 21.3.0-SIL6
**Status**: ACTIVE
**Last Updated**: 2026-01-14
**Compliance**: IEC 61508 SIL-6, SC-ZENOH-001 to SC-ZENOH-008

---

## Executive Summary

This document defines the runtime coverage analysis plan for Zenoh integration across all 7 fractal layers (L1-L7), ensuring 95% overall coverage and 99% coverage for safety-critical paths per SC-COV-002 and SC-SIL6-001.

### Coverage Targets

| Layer | Component | Target Coverage | Safety-Critical | Status |
|-------|-----------|----------------|-----------------|--------|
| L1 | FFI/NIF | 95% | 99% | PLANNED |
| L2 | Core API | 95% | 99% | PLANNED |
| L3 | Envelope | 95% | 99% | PLANNED |
| L5 | Lifecycle | 95% | 99% | PLANNED |
| L6 | Cluster | 95% | 99% | PLANNED |
| L7 | Federation | 95% | 99% | PLANNED |

---

## 1.0 L1 FFI Runtime Tests

### 1.1 Native Handle Management

#### Test: Handle Creation Under Load
```fsharp
[<Test>]
let ``Handle creation maintains safety under concurrent load`` () =
    let iterations = 10_000
    let parallelism = 16

    let createHandles () =
        seq { 1..iterations }
        |> Seq.map (fun _ ->
            let handle = ZenohFFI.create_session()
            ZenohFFI.dispose_session(handle)
        )
        |> Seq.toList

    let tasks =
        [ 1..parallelism ]
        |> List.map (fun _ -> Task.Run(Action createHandles))

    Task.WaitAll(tasks |> List.toArray)
    // Verify: No leaked handles, no segfaults
```

**STAMP**: SC-ZENOH-001, SC-PRF-050
**FMEA RPN**: 72 (Severity: 8, Occurrence: 3, Detection: 3)

#### Test: Concurrent Dispose Operations
```fsharp
[<Property>]
let ``Concurrent dispose operations are thread-safe`` () =
    forAll (Gen.listOfLength 100 (Gen.constant ())) (fun _ ->
        let handles =
            [1..100] |> List.map (fun _ -> ZenohFFI.create_session())

        handles
        |> List.map (fun h -> Task.Run(fun () -> ZenohFFI.dispose_session h))
        |> List.toArray
        |> Task.WaitAll

        // Verify: No double-free, no use-after-free
        true
    )
```

**STAMP**: SC-ZENOH-001
**FMEA RPN**: 81 (Severity: 9, Occurrence: 3, Detection: 3)

### 1.2 Memory Pressure Testing

#### Test: Memory Leak Detection
```fsharp
[<Test>]
let ``No memory leaks after 100K session cycles`` () =
    let startMemory = GC.GetTotalMemory(true)

    for i in 1..100_000 do
        let session = ZenohFFI.create_session()
        ZenohFFI.dispose_session(session)

    GC.Collect()
    GC.WaitForPendingFinalizers()
    GC.Collect()

    let endMemory = GC.GetTotalMemory(true)
    let leakMB = (endMemory - startMemory) / 1_048_576L

    Assert.Less(leakMB, 10L, "Memory leak detected")
```

**STAMP**: SC-ZENOH-001, SC-PRF-055
**FMEA RPN**: 64 (Severity: 8, Occurrence: 2, Detection: 4)

### 1.3 Error Injection Testing

#### Test: Invalid Handle Recovery
```fsharp
[<Property>]
let ``Invalid handles return error codes instead of crashing`` () =
    forAll Arb.generate<int64> (fun invalidHandle ->
        let result = ZenohFFI.publish(invalidHandle, "topic", [||])
        result = ZenohError.InvalidHandle
    )
```

**STAMP**: SC-ZENOH-001, SC-IMMUNE-001
**FMEA RPN**: 56 (Severity: 7, Occurrence: 2, Detection: 4)

---

## 2.0 L2 Core Runtime Tests

### 2.1 Session Lifecycle

#### Test: Session Creation/Destruction Cycles
```fsharp
[<Test>]
let ``Session lifecycle is deterministic over 10K cycles`` () =
    let mutable successCount = 0

    for i in 1..10_000 do
        use session = ZenohCore.createSession "tcp/127.0.0.1:7447"
        match session with
        | Ok s ->
            successCount <- successCount + 1
            s.Dispose()
        | Error e -> ()

    Assert.GreaterOrEqual(successCount, 9900, "Session creation reliability")
```

**STAMP**: SC-ZENOH-002, SC-ZENOH-005
**FMEA RPN**: 48 (Severity: 6, Occurrence: 2, Detection: 4)

### 2.2 Publisher Throughput Testing

#### Test: Sustained High-Frequency Publishing
```fsharp
[<Test>]
let ``Publisher sustains 10K msgs/sec with p99 latency < 10ms`` () =
    use session = ZenohCore.createSession "tcp/127.0.0.1:7447" |> Result.get
    use publisher = session.CreatePublisher "indrajaal/test/throughput"

    let messageCount = 100_000
    let stopwatch = Stopwatch.StartNew()
    let latencies = ResizeArray<float>()

    for i in 1..messageCount do
        let msgStart = stopwatch.Elapsed.TotalMilliseconds
        publisher.Publish([| byte i |])
        let msgEnd = stopwatch.Elapsed.TotalMilliseconds
        latencies.Add(msgEnd - msgStart)

    stopwatch.Stop()

    let throughput = float messageCount / stopwatch.Elapsed.TotalSeconds
    let p99 = latencies |> Seq.sort |> Seq.item (latencies.Count * 99 / 100)

    Assert.GreaterOrEqual(throughput, 10_000.0, "Throughput requirement")
    Assert.Less(p99, 10.0, "p99 latency requirement")
```

**STAMP**: SC-PRF-050, SC-ZENOH-004
**FMEA RPN**: 40 (Severity: 5, Occurrence: 2, Detection: 4)

### 2.3 Subscriber Latency Testing

#### Test: End-to-End Message Latency
```fsharp
[<Test>]
let ``Subscriber callback latency p99 < 50ms`` () =
    use session = ZenohCore.createSession "tcp/127.0.0.1:7447" |> Result.get
    use publisher = session.CreatePublisher "indrajaal/test/latency"

    let latencies = ResizeArray<float>()
    let mutable receivedCount = 0

    use subscriber =
        session.CreateSubscriber("indrajaal/test/latency", fun timestamp payload ->
            let now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
            let latency = float (now - timestamp)
            latencies.Add(latency)
            Interlocked.Increment(&receivedCount) |> ignore
        )

    Thread.Sleep(100) // Allow subscription to establish

    for i in 1..1000 do
        let timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
        publisher.Publish(BitConverter.GetBytes(timestamp))
        Thread.Sleep(10)

    Thread.Sleep(1000) // Wait for all messages

    let p99 = latencies |> Seq.sort |> Seq.item (latencies.Count * 99 / 100)

    Assert.GreaterOrEqual(receivedCount, 950, "Message delivery reliability")
    Assert.Less(p99, 50.0, "p99 latency requirement")
```

**STAMP**: SC-MSG-003, SC-ZENOH-004
**FMEA RPN**: 48 (Severity: 6, Occurrence: 2, Decision: 4)

### 2.4 Query Timeout Testing

#### Test: Query Timeout Behavior
```fsharp
[<Property>]
let ``Queries timeout correctly under no response`` () =
    forAll (Gen.choose(100, 5000)) (fun timeoutMs ->
        use session = ZenohCore.createSession "tcp/127.0.0.1:7447" |> Result.get

        let stopwatch = Stopwatch.StartNew()
        let result = session.Query("nonexistent/topic", timeoutMs)
        stopwatch.Stop()

        match result with
        | Error ZenohError.Timeout ->
            let actualTimeout = stopwatch.ElapsedMilliseconds
            abs (actualTimeout - int64 timeoutMs) < 100L // 100ms tolerance
        | _ -> false
    )
```

**STAMP**: SC-ZENOH-004, SC-PRF-050
**FMEA RPN**: 32 (Severity: 4, Occurrence: 2, Detection: 4)

---

## 3.0 L3 Envelope Runtime Tests

### 3.1 Large Payload Serialization

#### Test: 10MB Payload Handling
```fsharp
[<Test>]
let ``Envelope handles 10MB payloads without corruption`` () =
    let largePayload = Array.create (10 * 1024 * 1024) 0xFFuy
    Random().NextBytes(largePayload)

    let envelope = {
        MessageId = Guid.NewGuid().ToString()
        Timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
        Payload = largePayload
        Schema = "binary/large"
    }

    let serialized = ZenohEnvelope.serialize envelope
    let deserialized = ZenohEnvelope.deserialize serialized

    Assert.AreEqual(envelope.MessageId, deserialized.MessageId)
    Assert.AreEqual(largePayload, deserialized.Payload)
```

**STAMP**: SC-MSG-001, SC-PRF-055
**FMEA RPN**: 56 (Severity: 7, Occurrence: 2, Detection: 4)

### 3.2 Malformed Data Handling

#### Test: Malformed Envelope Recovery
```fsharp
[<Property>]
let ``Malformed envelopes return error instead of throwing`` () =
    forAll (Arb.generate<byte[]>) (fun malformedBytes ->
        let result = ZenohEnvelope.deserialize malformedBytes
        match result with
        | Error ZenohError.DeserializationFailed -> true
        | Error _ -> true
        | Ok _ -> Array.length malformedBytes > 0 // Valid by chance
    )
```

**STAMP**: SC-IMMUNE-001, SC-SEC-047
**FMEA RPN**: 64 (Severity: 8, Occurrence: 2, Detection: 4)

### 3.3 Version Migration Testing

#### Test: V1 to V2 Envelope Migration
```fsharp
[<Test>]
let ``V1 envelopes migrate to V2 without data loss`` () =
    let v1Envelope =
        """{"message_id":"abc123","timestamp":1234567890,"payload":"SGVsbG8="}"""

    let migrated = ZenohEnvelope.migrateV1toV2 v1Envelope

    match migrated with
    | Ok v2 ->
        Assert.AreEqual("abc123", v2.MessageId)
        Assert.AreEqual(1234567890L, v2.Timestamp)
        Assert.AreEqual("Hello", System.Text.Encoding.UTF8.GetString(v2.Payload))
    | Error e -> Assert.Fail($"Migration failed: {e}")
```

**STAMP**: SC-MSG-002, SC-FRAC-006
**FMEA RPN**: 40 (Severity: 5, Occurrence: 2, Detection: 4)

---

## 4.0 L5 Lifecycle Runtime Tests

### 4.1 Connection Establishment Timing

#### Test: Connection Within SLA
```fsharp
[<Test>]
let ``Connection establishment < 500ms p99`` () =
    let latencies = ResizeArray<float>()

    for i in 1..100 do
        let stopwatch = Stopwatch.StartNew()
        use session = ZenohCore.createSession "tcp/127.0.0.1:7447" |> Result.get
        stopwatch.Stop()
        latencies.Add(stopwatch.Elapsed.TotalMilliseconds)

    let p99 = latencies |> Seq.sort |> Seq.item 99
    Assert.Less(p99, 500.0, "Connection p99 latency")
```

**STAMP**: SC-ZENOH-002, SC-PRF-050
**FMEA RPN**: 48 (Severity: 6, Occurrence: 2, Detection: 4)

### 4.2 Reconnection Under Network Partition

#### Test: Automatic Reconnection
```fsharp
[<Test>]
let ``Session reconnects after network partition`` () =
    use session = ZenohCore.createSession "tcp/127.0.0.1:7447" |> Result.get
    use publisher = session.CreatePublisher "indrajaal/test/reconnect"

    // Simulate network partition
    BlockRouter()
    Thread.Sleep(5000)

    let disconnected = not session.IsConnected
    Assert.True(disconnected, "Session should detect disconnection")

    // Restore network
    UnblockRouter()
    Thread.Sleep(10000) // Wait for reconnect with backoff

    Assert.True(session.IsConnected, "Session should reconnect")

    // Verify publishing works
    let result = publisher.Publish([| 1uy; 2uy; 3uy |])
    Assert.True(result, "Publishing should work after reconnect")
```

**STAMP**: SC-ZENOH-005, SC-ZENOH-006
**FMEA RPN**: 72 (Severity: 9, Occurrence: 2, Detection: 4)

### 4.3 State Machine Stress Testing

#### Test: Rapid State Transitions
```fsharp
[<Test>]
let ``State machine handles rapid transitions without corruption`` () =
    use session = ZenohCore.createSession "tcp/127.0.0.1:7447" |> Result.get

    let tasks = [
        Task.Run(fun () -> for i in 1..1000 do session.Pause())
        Task.Run(fun () -> for i in 1..1000 do session.Resume())
        Task.Run(fun () -> for i in 1..1000 do session.GetState() |> ignore)
    ]

    Task.WaitAll(tasks |> List.toArray)

    // Verify final state is consistent
    let finalState = session.GetState()
    Assert.True(finalState = Connected || finalState = Paused)
```

**STAMP**: SC-ZENOH-003, SC-IMMUNE-001
**FMEA RPN**: 56 (Severity: 7, Occurrence: 2, Detection: 4)

### 4.4 Concurrent Session Management

#### Test: 100 Concurrent Sessions
```fsharp
[<Test>]
let ``System supports 100 concurrent sessions`` () =
    let sessions =
        [1..100]
        |> List.map (fun i ->
            ZenohCore.createSession $"tcp/127.0.0.1:7447?session_id={i}"
        )
        |> List.choose Result.toOption

    Assert.GreaterOrEqual(sessions.Length, 95, "Session creation success rate")

    // Verify all can publish
    let publishers =
        sessions
        |> List.map (fun s -> s.CreatePublisher $"indrajaal/test/concurrent/{s.Id}")

    publishers |> List.iter (fun p -> p.Publish([| 1uy |]) |> ignore)

    // Cleanup
    sessions |> List.iter (fun s -> s.Dispose())
```

**STAMP**: SC-ZENOH-001, SC-PRF-055
**FMEA RPN**: 48 (Severity: 6, Occurrence: 2, Detection: 4)

---

## 5.0 L6 Cluster Runtime Tests

### 5.1 Quorum Formation Timing

#### Test: Quorum Establishment < 500ms
```fsharp
[<Test>]
let ``Quorum forms within 500ms for 3-node cluster`` () =
    let nodes = [
        "tcp/zenoh-router-1:7447"
        "tcp/zenoh-router-2:7448"
        "tcp/zenoh-router-3:7449"
    ]

    let stopwatch = Stopwatch.StartNew()
    let cluster = ZenohCluster.createCluster nodes
    cluster.WaitForQuorum(TimeSpan.FromSeconds(10.0))
    stopwatch.Stop()

    Assert.True(cluster.HasQuorum, "Quorum should be achieved")
    Assert.Less(stopwatch.ElapsedMilliseconds, 500L, "Quorum formation time")
```

**STAMP**: SC-SIL6-011, SC-PRF-050
**FMEA RPN**: 64 (Severity: 8, Occurrence: 2, Detection: 4)

### 5.2 2oo3 Voting Under Failure

#### Test: 2oo3 Consensus With Node Failure
```fsharp
[<Test>]
let ``2oo3 voting succeeds with 1 node failure`` () =
    let nodes = createThreeNodeCluster()

    // Propose a decision
    let proposal = { Action = "upgrade"; Version = "v2.0" }
    let voteTask = nodes.ProposeDecision(proposal)

    // Simulate node-3 failure
    Thread.Sleep(100)
    nodes.[2].Crash()

    let result = voteTask.Result

    match result with
    | Approved votes ->
        Assert.GreaterOrEqual(votes, 2, "2oo3 requires 2 votes")
    | Rejected ->
        Assert.Fail("Should approve with 2/3 nodes")
```

**STAMP**: SC-SIL6-006, SC-SIL6-011
**FMEA RPN**: 81 (Severity: 9, Occurrence: 3, Detection: 3)

### 5.3 Vote Replay Attack Simulation

#### Test: Replay Attack Detection
```fsharp
[<Test>]
let ``Cluster rejects replayed votes`` () =
    let cluster = createThreeNodeCluster()

    let proposal = { Action = "restart"; Component = "db" }
    let vote1 = cluster.Nodes.[0].Vote(proposal)

    // Approve first time
    cluster.ProposeDecision(proposal) |> ignore

    // Attempt replay
    let replayAttempt = cluster.Nodes.[0].ReplayVote(vote1)

    Assert.False(replayAttempt.Accepted, "Replayed vote should be rejected")
```

**STAMP**: SC-SEC-047, SC-SIL6-006
**FMEA RPN**: 72 (Severity: 9, Occurrence: 2, Detection: 4)

### 5.4 Leader Election Contention

#### Test: Leader Election Under Contention
```fsharp
[<Test>]
let ``Leader election resolves within 1 second under contention`` () =
    let cluster = createThreeNodeCluster()
    cluster.Nodes |> List.iter (fun n -> n.BecomeCandidate())

    let stopwatch = Stopwatch.StartNew()
    cluster.RunElection()
    stopwatch.Stop()

    let leaders = cluster.Nodes |> List.filter (fun n -> n.IsLeader)

    Assert.AreEqual(1, leaders.Length, "Exactly one leader")
    Assert.Less(stopwatch.ElapsedMilliseconds, 1000L, "Election time")
```

**STAMP**: SC-SIL6-011, SC-FRAC-001
**FMEA RPN**: 56 (Severity: 7, Occurrence: 2, Detection: 4)

### 5.5 Split-Brain Prevention

#### Test: Split-Brain Detection and Recovery
```fsharp
[<Test>]
let ``Cluster detects and prevents split-brain`` () =
    let cluster = createThreeNodeCluster()

    // Simulate network partition: [1,2] vs [3]
    PartitionNetwork([0; 1], [2])
    Thread.Sleep(5000)

    // Minority partition should step down
    Assert.False(cluster.Nodes.[2].HasQuorum, "Minority should lose quorum")
    Assert.False(cluster.Nodes.[2].IsLeader, "Minority should not be leader")

    // Heal partition
    HealNetwork()
    Thread.Sleep(5000)

    // Should converge to single leader
    let leaders = cluster.Nodes |> List.filter (fun n -> n.IsLeader)
    Assert.AreEqual(1, leaders.Length, "Single leader after heal")
```

**STAMP**: SC-SIL6-011, SC-FRAC-001
**FMEA RPN**: 90 (Severity: 10, Occurrence: 3, Detection: 3)

---

## 6.0 L7 Federation Runtime Tests

### 6.1 Cross-Holon Latency

#### Test: Cross-Holon Message Latency < 100ms
```fsharp
[<Test>]
let ``Cross-holon messages deliver within 100ms p99`` () =
    let holon1 = createHolon "holon-1" "tcp/router-1:7447"
    let holon2 = createHolon "holon-2" "tcp/router-2:7448"

    let latencies = ResizeArray<float>()

    holon2.Subscribe("federation/test", fun timestamp _ ->
        let now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
        latencies.Add(float (now - timestamp))
    )

    Thread.Sleep(1000) // Allow federation to establish

    for i in 1..1000 do
        let timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
        holon1.Publish("federation/test", BitConverter.GetBytes(timestamp))
        Thread.Sleep(10)

    Thread.Sleep(2000)

    let p99 = latencies |> Seq.sort |> Seq.item (latencies.Count * 99 / 100)
    Assert.Less(p99, 100.0, "Cross-holon p99 latency")
```

**STAMP**: SC-FRAC-007, SC-PRF-050
**FMEA RPN**: 56 (Severity: 7, Occurrence: 2, Detection: 4)

### 6.2 Attestation Expiry Handling

#### Test: Expired Attestation Rejection
```fsharp
[<Test>]
let ``Federation rejects expired attestations`` () =
    let holon1 = createHolon "holon-1" "tcp/router-1:7447"
    let holon2 = createHolon "holon-2" "tcp/router-2:7448"

    // Create attestation with 1-second TTL
    let attestation = holon1.CreateAttestation(holon2.Id, TimeSpan.FromSeconds(1.0))

    Thread.Sleep(2000) // Wait for expiry

    let verifyResult = holon2.VerifyAttestation(attestation)

    match verifyResult with
    | Error AttestationError.Expired -> Assert.Pass()
    | _ -> Assert.Fail("Should reject expired attestation")
```

**STAMP**: SC-FRAC-004, SC-SEC-047
**FMEA RPN**: 64 (Severity: 8, Occurrence: 2, Detection: 4)

### 6.3 Version Negotiation Failures

#### Test: Version Mismatch Handling
```fsharp
[<Property>]
let ``Federation negotiates compatible versions or fails gracefully`` () =
    forAll (Gen.two (Gen.choose(1, 10))) (fun (v1, v2) ->
        let holon1 = createHolonWithVersion "holon-1" v1
        let holon2 = createHolonWithVersion "holon-2" v2

        let federationResult = holon1.FederateWith(holon2)

        match federationResult with
        | Ok _ -> abs (v1 - v2) <= 1 // Compatible within 1 major version
        | Error FederationError.IncompatibleVersion -> abs (v1 - v2) > 1
        | _ -> false
    )
```

**STAMP**: SC-FRAC-006, SC-REG-010
**FMEA RPN**: 48 (Severity: 6, Occurrence: 2, Detection: 4)

### 6.4 Routing Under Partition

#### Test: Routing Around Network Partition
```fsharp
[<Test>]
let ``Federation routes around partitioned nodes`` () =
    let holons = [
        createHolon "holon-1" "tcp/router-1:7447"
        createHolon "holon-2" "tcp/router-2:7448"
        createHolon "holon-3" "tcp/router-3:7449"
    ]

    // Establish full federation
    federateAll holons
    Thread.Sleep(2000)

    // Partition holon-2
    PartitionNode(1)
    Thread.Sleep(5000)

    // holon-1 should still reach holon-3
    let mutable received = false
    holons.[2].Subscribe("test/routing", fun _ _ -> received <- true)

    holons.[0].Publish("test/routing", [| 1uy |])
    Thread.Sleep(2000)

    Assert.True(received, "Message should route around partition")
```

**STAMP**: SC-FRAC-007, SC-ZENOH-005
**FMEA RPN**: 72 (Severity: 9, Occurrence: 2, Detection: 4)

---

## 7.0 Performance Benchmarks

### 7.1 Latency Benchmarks

| Test | Target | SIL-6 Requirement | Current | Status |
|------|--------|-------------------|---------|--------|
| Publish latency (p99) | <10ms | SC-PRF-050 | TBD | PLANNED |
| Subscribe callback (p99) | <50ms | SC-MSG-003 | TBD | PLANNED |
| Query response (p99) | <100ms | SC-PRF-050 | TBD | PLANNED |
| Reconnect time (p99) | <5s | SC-ZENOH-005 | TBD | PLANNED |
| Quorum formation | <500ms | SC-SIL6-011 | TBD | PLANNED |
| 2oo3 vote | <50ms | SC-SIL6-004 | TBD | PLANNED |
| Leader election | <1s | SC-FRAC-001 | TBD | PLANNED |
| Cross-holon latency (p99) | <100ms | SC-FRAC-007 | TBD | PLANNED |

### 7.2 Throughput Benchmarks

| Test | Target | SIL-6 Requirement | Current | Status |
|------|--------|-------------------|---------|--------|
| Publisher throughput | 10K msgs/sec | - | TBD | PLANNED |
| Subscriber throughput | 10K msgs/sec | - | TBD | PLANNED |
| Concurrent publishers | 100 | SC-PRF-055 | TBD | PLANNED |
| Concurrent subscribers | 1000 | SC-PRF-055 | TBD | PLANNED |
| Concurrent sessions | 100 | SC-ZENOH-001 | TBD | PLANNED |

### 7.3 Resource Benchmarks

| Test | Target | SIL-6 Requirement | Current | Status |
|------|--------|-------------------|---------|--------|
| Memory per session | <10MB | - | TBD | PLANNED |
| CPU per 1K msgs/sec | <5% | - | TBD | PLANNED |
| Network bandwidth | <100Mbps | - | TBD | PLANNED |
| File descriptors | <1K | - | TBD | PLANNED |

---

## 8.0 Chaos Engineering Tests

### 8.1 Random Node Failure

```fsharp
[<Test>]
let ``System maintains availability with random node failures`` () =
    let cluster = createFiveNodeCluster()
    let mutable totalMessages = 0
    let mutable deliveredMessages = 0

    // Start continuous publishing
    let publishTask = Task.Run(fun () ->
        for i in 1..10_000 do
            Interlocked.Increment(&totalMessages) |> ignore
            cluster.Publish("chaos/test", BitConverter.GetBytes(i))
            Thread.Sleep(10)
    )

    // Subscribe on all nodes
    cluster.Nodes |> List.iter (fun node ->
        node.Subscribe("chaos/test", fun _ _ ->
            Interlocked.Increment(&deliveredMessages) |> ignore
        )
    )

    // Random failures
    let chaosTask = Task.Run(fun () ->
        let rng = Random()
        for i in 1..10 do
            Thread.Sleep(rng.Next(500, 2000))
            let nodeIndex = rng.Next(cluster.Nodes.Length)
            cluster.Nodes.[nodeIndex].Crash()
            Thread.Sleep(rng.Next(1000, 3000))
            cluster.Nodes.[nodeIndex].Restart()
    )

    Task.WaitAll([| publishTask; chaosTask |])
    Thread.Sleep(5000) // Allow convergence

    let deliveryRate = float deliveredMessages / float totalMessages
    Assert.GreaterOrEqual(deliveryRate, 0.95, "95% message delivery under chaos")
```

**STAMP**: SC-IMMUNE-001, SC-ZENOH-005
**FMEA RPN**: 81 (Severity: 9, Occurrence: 3, Detection: 3)

### 8.2 Network Partition

```fsharp
[<Test>]
let ``System recovers from network partition within 30 seconds`` () =
    let cluster = createThreeNodeCluster()

    // Partition into [1] vs [2,3]
    let stopwatch = Stopwatch.StartNew()
    PartitionNetwork([0], [1; 2])
    Thread.Sleep(10_000)

    // Heal partition
    HealNetwork()

    // Wait for convergence
    while not cluster.HasQuorum && stopwatch.Elapsed.TotalSeconds < 30.0 do
        Thread.Sleep(100)

    Assert.True(cluster.HasQuorum, "Should regain quorum")
    Assert.Less(stopwatch.ElapsedMilliseconds, 30_000L, "Recovery time")
```

**STAMP**: SC-FRAC-001, SC-ZENOH-006
**FMEA RPN**: 90 (Severity: 10, Occurrence: 3, Detection: 3)

### 8.3 Clock Skew

```fsharp
[<Test>]
let ``System tolerates 5-second clock skew`` () =
    let cluster = createThreeNodeCluster()

    // Skew node-2 clock by +5 seconds
    cluster.Nodes.[1].SetClockSkew(TimeSpan.FromSeconds(5.0))

    // Publish with timestamp
    let timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
    cluster.Nodes.[0].Publish("clock/test", BitConverter.GetBytes(timestamp))

    Thread.Sleep(1000)

    // Verify all nodes received and processed
    cluster.Nodes |> List.iter (fun node ->
        Assert.True(node.LastMessageTimestamp > 0L, "Node should process message")
    )
```

**STAMP**: SC-FRAC-004, SC-REG-010
**FMEA RPN**: 48 (Severity: 6, Occurrence: 2, Detection: 4)

### 8.4 Resource Exhaustion

```fsharp
[<Test>]
let ``System degrades gracefully under resource exhaustion`` () =
    let session = ZenohCore.createSession "tcp/127.0.0.1:7447" |> Result.get

    // Exhaust file descriptors
    let publishers =
        [1..1000]
        |> List.map (fun i -> session.CreatePublisher $"exhaust/{i}")
        |> List.takeWhile (fun p -> p <> null)

    // System should still function with remaining resources
    let testPublisher = session.CreatePublisher "exhaust/test"
    let canPublish = testPublisher.Publish([| 1uy |])

    // Either publish succeeds OR graceful error is returned
    Assert.True(canPublish || session.LastError = ZenohError.ResourceExhausted)
```

**STAMP**: SC-IMMUNE-002, SC-PRF-055
**FMEA RPN**: 64 (Severity: 8, Occurrence: 2, Detection: 4)

---

## 9.0 Load Testing

### 9.1 10K Messages/Sec Sustained

```fsharp
[<Test>]
let ``System sustains 10K msgs/sec for 10 minutes`` () =
    use session = ZenohCore.createSession "tcp/127.0.0.1:7447" |> Result.get
    use publisher = session.CreatePublisher "load/test/10k"

    let testDuration = TimeSpan.FromMinutes(10.0)
    let targetRate = 10_000 // msgs/sec
    let messageInterval = 1000.0 / float targetRate // ms

    let mutable sentCount = 0L
    let stopwatch = Stopwatch.StartNew()

    while stopwatch.Elapsed < testDuration do
        let startTime = stopwatch.Elapsed.TotalMilliseconds
        publisher.Publish(BitConverter.GetBytes(sentCount))
        Interlocked.Increment(&sentCount) |> ignore

        let elapsed = stopwatch.Elapsed.TotalMilliseconds - startTime
        let sleepTime = max 0.0 (messageInterval - elapsed)
        if sleepTime > 0.0 then
            Thread.Sleep(int sleepTime)

    stopwatch.Stop()

    let actualRate = float sentCount / stopwatch.Elapsed.TotalSeconds
    let rateDeviation = abs (actualRate - float targetRate) / float targetRate

    Assert.Less(rateDeviation, 0.05, "Rate should be within 5% of target")
```

**STAMP**: SC-PRF-050, SC-ZENOH-004
**FMEA RPN**: 56 (Severity: 7, Occurrence: 2, Detection: 4)

### 9.2 1000 Concurrent Subscribers

```fsharp
[<Test>]
let ``System supports 1000 concurrent subscribers`` () =
    use session = ZenohCore.createSession "tcp/127.0.0.1:7447" |> Result.get

    let receivedCounts = ConcurrentDictionary<int, int>()

    let subscribers =
        [1..1000]
        |> List.map (fun i ->
            receivedCounts.[i] <- 0
            session.CreateSubscriber($"load/test/subscribers", fun _ _ ->
                receivedCounts.[i] <- receivedCounts.[i] + 1
            )
        )

    Thread.Sleep(2000) // Allow subscriptions to establish

    use publisher = session.CreatePublisher "load/test/subscribers"

    // Publish 100 messages
    for i in 1..100 do
        publisher.Publish(BitConverter.GetBytes(i))
        Thread.Sleep(10)

    Thread.Sleep(5000) // Wait for delivery

    // At least 95% of subscribers should receive > 95 messages
    let successfulSubscribers =
        receivedCounts.Values
        |> Seq.filter (fun count -> count >= 95)
        |> Seq.length

    Assert.GreaterOrEqual(successfulSubscribers, 950, "95% subscriber success rate")
```

**STAMP**: SC-ZENOH-003, SC-PRF-055
**FMEA RPN**: 48 (Severity: 6, Occurrence: 2, Detection: 4)

### 9.3 100 Concurrent Publishers

```fsharp
[<Test>]
let ``System supports 100 concurrent publishers`` () =
    use session = ZenohCore.createSession "tcp/127.0.0.1:7447" |> Result.get

    let mutable receivedCount = 0L
    use subscriber =
        session.CreateSubscriber("load/test/publishers", fun _ _ ->
            Interlocked.Increment(&receivedCount) |> ignore
        )

    Thread.Sleep(1000)

    let publishers =
        [1..100]
        |> List.map (fun i ->
            session.CreatePublisher $"load/test/publishers"
        )

    // Each publisher sends 100 messages
    let publishTasks =
        publishers
        |> List.mapi (fun i pub ->
            Task.Run(fun () ->
                for j in 1..100 do
                    pub.Publish(BitConverter.GetBytes(i * 1000 + j))
                    Thread.Sleep(10)
            )
        )

    Task.WaitAll(publishTasks |> List.toArray)
    Thread.Sleep(5000)

    // Should receive at least 9500 out of 10000 messages (95%)
    Assert.GreaterOrEqual(receivedCount, 9500L, "95% message delivery")
```

**STAMP**: SC-ZENOH-001, SC-PRF-050
**FMEA RPN**: 48 (Severity: 6, Occurrence: 2, Detection: 4)

---

## 10.0 Coverage Instrumentation

### 10.1 F# Code Coverage with Coverlet

#### Configuration (coverlet.runsettings)
```xml
<?xml version="1.0" encoding="utf-8" ?>
<RunSettings>
  <DataCollectionRunSettings>
    <DataCollectors>
      <DataCollector friendlyName="XPlat Code Coverage">
        <Configuration>
          <Format>cobertura,opencover</Format>
          <Exclude>[*]Cepaf.Testing.*</Exclude>
          <Include>[Cepaf.Zenoh*]*</Include>
          <ExcludeByFile>**/Generated/**/*.fs</ExcludeByFile>
          <SingleHit>false</SingleHit>
          <UseSourceLink>true</UseSourceLink>
          <IncludeTestAssembly>false</IncludeTestAssembly>
          <SkipAutoProps>true</SkipAutoProps>
          <DeterministicReport>true</DeterministicReport>
          <ExcludeAssembliesWithoutSources>MissingAll</ExcludeAssembliesWithoutSources>
        </Configuration>
      </DataCollector>
    </DataCollectors>
  </DataCollectionRunSettings>
</RunSettings>
```

#### Execution
```bash
# Run tests with coverage
dotnet test \
  --collect:"XPlat Code Coverage" \
  --settings coverlet.runsettings \
  --results-directory ./coverage

# Generate HTML report
reportgenerator \
  -reports:./coverage/**/coverage.cobertura.xml \
  -targetdir:./coverage/report \
  -reporttypes:"Html;Badges;JsonSummary"

# Check coverage thresholds
dotnet test \
  /p:CollectCoverage=true \
  /p:Threshold=95 \
  /p:ThresholdType=line \
  /p:ThresholdStat=total
```

### 10.2 Branch Coverage Reporting

```fsharp
// Ensure all branches are covered
[<Test>]
let ``All ZenohError branches are tested`` () =
    let errorTypes = [
        ZenohError.InvalidHandle
        ZenohError.Timeout
        ZenohError.ConnectionFailed
        ZenohError.DeserializationFailed
        ZenohError.ResourceExhausted
        ZenohError.PermissionDenied
    ]

    errorTypes |> List.iter (fun error ->
        let handled =
            match error with
            | ZenohError.InvalidHandle -> true
            | ZenohError.Timeout -> true
            | ZenohError.ConnectionFailed -> true
            | ZenohError.DeserializationFailed -> true
            | ZenohError.ResourceExhausted -> true
            | ZenohError.PermissionDenied -> true
            | _ -> false

        Assert.True(handled, $"Error {error} should be handled")
    )
```

### 10.3 Line Coverage Reporting

Coverage targets:
- **Overall**: 95% line coverage
- **Safety-Critical Paths** (L6 cluster, L7 federation): 99% line coverage
- **FFI Layer**: 99% line coverage (memory safety)

### 10.4 Integration with CI/CD

#### GitHub Actions Workflow
```yaml
name: Zenoh Runtime Coverage

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.0.x'

      - name: Start Zenoh Router
        run: |
          docker run -d --name zenoh-router \
            -p 7447:7447 \
            eclipse/zenoh:latest

      - name: Run Tests with Coverage
        run: |
          dotnet test \
            --collect:"XPlat Code Coverage" \
            --settings coverlet.runsettings \
            --results-directory ./coverage

      - name: Generate Coverage Report
        run: |
          dotnet tool install -g dotnet-reportgenerator-globaltool
          reportgenerator \
            -reports:./coverage/**/coverage.cobertura.xml \
            -targetdir:./coverage/report \
            -reporttypes:"Html;Badges;JsonSummary;Cobertura"

      - name: Check Coverage Thresholds
        run: |
          dotnet test \
            /p:CollectCoverage=true \
            /p:Threshold=95 \
            /p:ThresholdType=line \
            /p:ThresholdStat=total

      - name: Upload Coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage/report/Cobertura.xml
          flags: zenoh
          fail_ci_if_error: true

      - name: Publish Coverage Report
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: ./coverage/report
```

### 10.5 Coverage Metrics Dashboard

| Metric | Formula | Target | SIL-6 |
|--------|---------|--------|-------|
| Line Coverage | Lines Executed / Total Lines | 95% | 99% for critical |
| Branch Coverage | Branches Taken / Total Branches | 90% | 99% for critical |
| Method Coverage | Methods Called / Total Methods | 95% | 100% for critical |
| Cyclomatic Complexity | Weighted by coverage | <10 avg | <5 for critical |

---

## 11.0 Test Execution Plan

### 11.1 Local Development

```bash
# Run all Zenoh tests
dotnet test lib/cepaf/tests/Cepaf.Zenoh.Tests/

# Run specific layer
dotnet test --filter "Category=L1_FFI"
dotnet test --filter "Category=L6_Cluster"

# Run with coverage
dotnet test --collect:"XPlat Code Coverage"

# Run performance benchmarks
dotnet test --filter "Category=Benchmark" --logger "console;verbosity=detailed"
```

### 11.2 CI/CD Pipeline

```yaml
stages:
  - unit_tests          # L1-L5 unit tests (fast)
  - integration_tests   # L6-L7 integration tests (medium)
  - performance_tests   # Benchmarks (slow)
  - chaos_tests         # Chaos engineering (very slow)
  - coverage_report     # Aggregate coverage
  - quality_gate        # Enforce thresholds
```

### 11.3 Nightly Regression Suite

```bash
# Full test suite with extended timeouts
dotnet test \
  --filter "Category!=Slow" \
  --settings nightly.runsettings \
  --logger "trx;LogFileName=nightly-results.trx"

# Chaos tests (1 hour duration each)
dotnet test \
  --filter "Category=Chaos" \
  --settings chaos.runsettings
```

---

## 12.0 STAMP Constraints (Coverage)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-COV-001 | Overall line coverage >= 95% | CRITICAL | Coverlet |
| SC-COV-002 | Safety-critical path coverage >= 99% | CRITICAL | Manual review |
| SC-COV-003 | Branch coverage >= 90% | HIGH | Coverlet |
| SC-COV-004 | Method coverage >= 95% | HIGH | Coverlet |
| SC-COV-005 | Cyclomatic complexity < 10 avg | MEDIUM | SonarQube |
| SC-COV-006 | All error paths tested | CRITICAL | Code review |
| SC-COV-007 | Performance benchmarks on every PR | HIGH | CI/CD |
| SC-COV-008 | Chaos tests weekly | MEDIUM | Cron |

---

## 13.0 AOR Rules (Coverage)

| ID | Rule |
|----|------|
| AOR-COV-001 | RUN full test suite before merge |
| AOR-COV-002 | FAIL build if coverage < 95% |
| AOR-COV-003 | REVIEW manually if safety-critical coverage < 99% |
| AOR-COV-004 | BENCHMARK performance on every release |
| AOR-COV-005 | RUN chaos tests before production deploy |
| AOR-COV-006 | LOG all test failures to telemetry |
| AOR-COV-007 | ALERT on performance regression > 10% |
| AOR-COV-008 | UPDATE this plan quarterly |

---

## 14.0 Related Documents

- `CLAUDE.md` - Master system specification
- `.claude/rules/zenoh-telemetry-mandatory.md` - Zenoh requirements
- `.claude/rules/fsharp-sil6-mesh.md` - Mesh orchestration rules
- `docs/architecture/ZENOH_ARCHITECTURE.md` - Architecture overview
- `lib/cepaf/tests/Cepaf.Zenoh.Tests/` - Test implementation

---

## 15.0 Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-01-14 | Claude Opus 4.5 | Initial comprehensive plan |

---

**STAMP Compliance**: SC-COV-001 to SC-COV-008, SC-ZENOH-001 to SC-ZENOH-008
**AOR Compliance**: AOR-COV-001 to AOR-COV-008, AOR-ZENOH-001 to AOR-ZENOH-008
**SIL-6 Target**: 99% coverage for safety-critical paths
**Overall Target**: 95% coverage across all layers
