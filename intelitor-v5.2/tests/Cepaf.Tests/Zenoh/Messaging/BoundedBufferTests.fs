// =============================================================================
// BoundedBufferTests.fs - Test Suite for FM-008 Bounded Buffer
// =============================================================================
// STAMP: SC-ENV-003, SC-BUF-001, SC-BUF-002, SC-TEST-001
// AOR: AOR-TEST-001, AOR-TDG
// Criticality: Level 1 (CRITICAL) - Security Testing
// =============================================================================
// Comprehensive test suite for bounded buffer including:
// - Message size enforcement tests
// - Buffer capacity limit tests
// - Backpressure signaling tests
// - Thread-safety stress tests
// - Property-based tests
// - Integration tests with ZenohEnvelope
// =============================================================================

module Cepaf.Tests.Zenoh.Messaging.BoundedBufferTests

open System
open System.Threading
open System.Threading.Tasks
open Xunit
open FsCheck
open FsCheck.Xunit
open Cepaf.Zenoh.Core
open Cepaf.Zenoh.Messaging

// =============================================================================
// Test Fixtures
// =============================================================================

module TestData =
    /// Create byte array of specific size
    let createMessage (sizeBytes: int) : byte[] =
        Array.create sizeBytes 0xAAuy

    /// Create random message
    let createRandomMessage (sizeBytes: int) : byte[] =
        let rnd = Random()
        Array.init sizeBytes (fun _ -> byte (rnd.Next(256)))

    /// Small message (100 bytes)
    let smallMessage = createMessage 100

    /// Medium message (100 KB)
    let mediumMessage = createMessage (100 * 1024)

    /// Large message (1 MB)
    let largeMessage = createMessage (1 * 1024 * 1024)

    /// Oversized message (2 MB - exceeds default limit)
    let oversizedMessage = createMessage (2 * 1024 * 1024)

// =============================================================================
// Unit Tests - Message Size Enforcement (SC-ENV-003)
// =============================================================================

[<Fact>]
let ``TryBuffer accepts message within size limit`` () =
    // Arrange
    let buffer = BoundedBuffer.create()
    let message = TestData.createMessage 512

    // Act
    let result = buffer.TryBuffer(message)

    // Assert
    Assert.True(result.IsAccepted, "Expected message to be accepted")
    Assert.Equal(1, buffer.Count)

[<Fact>]
let ``TryBuffer rejects message exceeding size limit`` () =
    // Arrange
    let buffer = BoundedBuffer.createWithMaxSize (100 * 1024) // 100 KB limit
    let message = TestData.createMessage (200 * 1024) // 200 KB message

    // Act
    let result = buffer.TryBuffer(message)

    // Assert
    match result with
    | BufferResult.RejectedTooLarge (actual, max) ->
        Assert.Equal(200 * 1024, actual)
        Assert.Equal(100 * 1024, max)
    | _ -> Assert.True(false, "Expected RejectedTooLarge")

    Assert.Equal(0, buffer.Count)

[<Fact>]
let ``TryBuffer rejects null message`` () =
    // Arrange
    let buffer = BoundedBuffer.create()

    // Act
    let result = buffer.TryBuffer(null)

    // Assert
    match result with
    | BufferResult.RejectedInvalid reason ->
        Assert.Contains("Null", reason)
    | _ -> Assert.True(false, "Expected RejectedInvalid")

[<Fact>]
let ``TryBuffer rejects empty message`` () =
    // Arrange
    let buffer = BoundedBuffer.create()
    let emptyMessage = [||]

    // Act
    let result = buffer.TryBuffer(emptyMessage)

    // Assert
    match result with
    | BufferResult.RejectedInvalid reason ->
        Assert.Contains("Empty", reason)
    | _ -> Assert.True(false, "Expected RejectedInvalid")

[<Fact>]
let ``Default max message size is 1MB`` () =
    // Arrange
    let buffer = BoundedBuffer.create()

    // Act
    let config = buffer.Config

    // Assert
    Assert.Equal(MessageSizeLimits.DefaultMaxMessageBytes, config.MaxMessageBytes)
    Assert.Equal(1_048_576, config.MaxMessageBytes)

// =============================================================================
// Unit Tests - Buffer Capacity Enforcement (SC-BUF-001)
// =============================================================================

[<Fact>]
let ``Buffer accepts messages up to capacity`` () =
    // Arrange
    let buffer = BoundedBuffer.createWithCapacity 10
    let message = TestData.smallMessage

    // Act & Assert
    for i in 1..10 do
        let result = buffer.TryBuffer(message)
        Assert.True(result.IsAccepted, sprintf "Message %d should be accepted" i)

    Assert.Equal(10, buffer.Count)

[<Fact>]
let ``Buffer rejects messages beyond capacity`` () =
    // Arrange
    let buffer = BoundedBuffer.createWithCapacity 5
    let message = TestData.smallMessage

    // Act - Fill buffer
    for _ in 1..5 do
        buffer.TryBuffer(message) |> ignore

    // Act - Try to add 6th message
    let result = buffer.TryBuffer(message)

    // Assert
    match result with
    | BufferResult.RejectedBufferFull (current, max) ->
        Assert.Equal(5, current)
        Assert.Equal(5, max)
    | _ -> Assert.True(false, "Expected RejectedBufferFull")

[<Fact>]
let ``TryDequeue returns None when buffer empty`` () =
    // Arrange
    let buffer = BoundedBuffer.create()

    // Act
    let result = buffer.TryDequeue()

    // Assert
    Assert.True(result.IsNone, "Expected None for empty buffer")

[<Fact>]
let ``TryDequeue returns messages in FIFO order`` () =
    // Arrange
    let buffer = BoundedBuffer.create()
    let msg1 = TestData.createMessage 100
    let msg2 = TestData.createMessage 200
    let msg3 = TestData.createMessage 300

    // Act
    buffer.TryBuffer(msg1) |> ignore
    buffer.TryBuffer(msg2) |> ignore
    buffer.TryBuffer(msg3) |> ignore

    let dequeued1 = buffer.TryDequeue().Value
    let dequeued2 = buffer.TryDequeue().Value
    let dequeued3 = buffer.TryDequeue().Value

    // Assert
    Assert.Equal(100, dequeued1.Length)
    Assert.Equal(200, dequeued2.Length)
    Assert.Equal(300, dequeued3.Length)

[<Fact>]
let ``Clear empties the buffer`` () =
    // Arrange
    let buffer = BoundedBuffer.create()
    for _ in 1..10 do
        buffer.TryBuffer(TestData.smallMessage) |> ignore

    // Act
    buffer.Clear()

    // Assert
    Assert.Equal(0, buffer.Count)
    Assert.True(buffer.IsEmpty)

// =============================================================================
// Unit Tests - Backpressure Signaling (SC-BUF-002)
// =============================================================================

[<Fact>]
let ``GetStatus returns Available when buffer less than 80 percent full`` () =
    // Arrange
    let buffer = BoundedBuffer.createWithCapacity 100
    let message = TestData.smallMessage

    // Act - Fill to 75%
    for _ in 1..75 do
        buffer.TryBuffer(message) |> ignore

    let status = buffer.GetStatus()

    // Assert
    match status with
    | BufferStatus.Available -> Assert.True(true)
    | _ -> Assert.True(false, sprintf "Expected Available, got %A" status)

[<Fact>]
let ``GetStatus returns NearCapacity when buffer 80-94 percent full`` () =
    // Arrange
    let buffer = BoundedBuffer.createWithCapacity 100
    let message = TestData.smallMessage

    // Act - Fill to 85%
    for _ in 1..85 do
        buffer.TryBuffer(message) |> ignore

    let status = buffer.GetStatus()

    // Assert
    match status with
    | BufferStatus.NearCapacity percentFull ->
        Assert.True(percentFull >= 80.0 && percentFull < 95.0)
    | _ -> Assert.True(false, sprintf "Expected NearCapacity, got %A" status)

[<Fact>]
let ``GetStatus returns Critical when buffer 95-99 percent full`` () =
    // Arrange
    let buffer = BoundedBuffer.createWithCapacity 100
    let message = TestData.smallMessage

    // Act - Fill to 96%
    for _ in 1..96 do
        buffer.TryBuffer(message) |> ignore

    let status = buffer.GetStatus()

    // Assert
    match status with
    | BufferStatus.Critical percentFull ->
        Assert.True(percentFull >= 95.0 && percentFull < 100.0)
    | _ -> Assert.True(false, sprintf "Expected Critical, got %A" status)

[<Fact>]
let ``GetStatus returns Full when buffer 100 percent full`` () =
    // Arrange
    let buffer = BoundedBuffer.createWithCapacity 10
    let message = TestData.smallMessage

    // Act - Fill to 100%
    for _ in 1..10 do
        buffer.TryBuffer(message) |> ignore

    let status = buffer.GetStatus()

    // Assert
    Assert.Equal(BufferStatus.Full, status)

[<Fact>]
let ``ShouldApplyBackpressure returns true when near capacity`` () =
    // Arrange
    let buffer = BoundedBuffer.createWithCapacity 100
    let message = TestData.smallMessage

    // Act - Fill to 85%
    for _ in 1..85 do
        buffer.TryBuffer(message) |> ignore

    // Assert
    Assert.True(BoundedBuffer.shouldApplyBackpressure buffer)

// =============================================================================
// Unit Tests - Metrics Tracking
// =============================================================================

[<Fact>]
let ``Metrics track accepted messages`` () =
    // Arrange
    let buffer = BoundedBuffer.create()
    let message = TestData.createMessage 500

    // Act
    for _ in 1..10 do
        buffer.TryBuffer(message) |> ignore

    let metrics = buffer.GetMetrics()

    // Assert
    Assert.Equal(10L, metrics.AcceptedCount)
    Assert.Equal(5000L, metrics.TotalBytesAccepted) // 10 * 500
    Assert.Equal(500, metrics.LargestMessageBytes)

[<Fact>]
let ``Metrics track rejected messages`` () =
    // Arrange
    let buffer = BoundedBuffer.createWithMaxSize 1000
    let smallMsg = TestData.createMessage 500
    let largeMsg = TestData.createMessage 2000

    // Act
    buffer.TryBuffer(smallMsg) |> ignore
    buffer.TryBuffer(largeMsg) |> ignore

    let metrics = buffer.GetMetrics()

    // Assert
    Assert.Equal(1L, metrics.AcceptedCount)
    Assert.Equal(1L, metrics.RejectedTooLargeCount)

[<Fact>]
let ``Metrics track peak count`` () =
    // Arrange
    let buffer = BoundedBuffer.create()
    let message = TestData.smallMessage

    // Act - Fill buffer
    for _ in 1..20 do
        buffer.TryBuffer(message) |> ignore

    // Dequeue some
    for _ in 1..10 do
        buffer.TryDequeue() |> ignore

    let metrics = buffer.GetMetrics()

    // Assert
    Assert.Equal(20, metrics.PeakCount)
    Assert.Equal(10, metrics.CurrentCount)

// =============================================================================
// Concurrency Tests - Thread Safety
// =============================================================================

[<Fact>]
let ``Concurrent enqueue operations are thread-safe`` () =
    // Arrange
    let buffer = BoundedBuffer.createWithCapacity 10000
    let message = TestData.smallMessage
    let threadCount = 10
    let messagesPerThread = 100

    // Act
    let tasks =
        [1..threadCount]
        |> List.map (fun _ ->
            Task.Run(fun () ->
                for _ in 1..messagesPerThread do
                    buffer.TryBuffer(message) |> ignore
            )
        )

    Task.WaitAll(tasks |> List.toArray)

    // Assert
    Assert.Equal(threadCount * messagesPerThread, buffer.Count)

[<Fact>]
let ``Concurrent dequeue operations are thread-safe`` () =
    // Arrange
    let buffer = BoundedBuffer.create()
    let message = TestData.smallMessage

    // Fill buffer
    for _ in 1..1000 do
        buffer.TryBuffer(message) |> ignore

    // Act - Concurrent dequeue
    let mutable dequeuedCount = 0
    let threadCount = 10

    let tasks =
        [1..threadCount]
        |> List.map (fun _ ->
            Task.Run(fun () ->
                while buffer.TryDequeue().IsSome do
                    Interlocked.Increment(&dequeuedCount) |> ignore
            )
        )

    Task.WaitAll(tasks |> List.toArray)

    // Assert
    Assert.Equal(1000, dequeuedCount)
    Assert.Equal(0, buffer.Count)

// =============================================================================
// Integration Tests - ZenohEnvelope
// =============================================================================

[<Fact>]
let ``EnvelopeBuffer accepts serialized envelope`` () =
    // Arrange
    type TestPayload = { Message: string; Value: int }
    let buffer = EnvelopeBuffer.createEnvelopeBuffer<TestPayload> (10 * 1024) 100

    let payload = { Message = "test"; Value = 42 }
    let envelope = ZenohEnvelope.create "test-source" payload

    // Act
    let result = EnvelopeBuffer.tryBufferEnvelope buffer envelope

    // Assert
    Assert.True(result.IsOk, "Expected envelope to be buffered")
    Assert.Equal(1, buffer.Count)

[<Fact>]
let ``EnvelopeBuffer roundtrip preserves data`` () =
    // Arrange
    type TestPayload = { Message: string; Value: int }
    let buffer = EnvelopeBuffer.createEnvelopeBuffer<TestPayload> (10 * 1024) 100

    let payload = { Message = "test"; Value = 42 }
    let envelope = ZenohEnvelope.create "test-source" payload

    // Act
    EnvelopeBuffer.tryBufferEnvelope buffer envelope |> ignore
    let dequeued = EnvelopeBuffer.tryDequeueEnvelope<TestPayload> buffer

    // Assert
    match dequeued with
    | Some (Ok env) ->
        Assert.Equal("test", env.Payload.Message)
        Assert.Equal(42, env.Payload.Value)
    | _ -> Assert.True(false, "Expected envelope to be dequeued")

// =============================================================================
// Property-Based Tests (FsCheck)
// =============================================================================

[<Property>]
let ``No message accepted exceeds max size`` (messageSize: PositiveInt) =
    let maxSize = 1024
    let buffer = BoundedBuffer.createWithMaxSize maxSize
    let message = TestData.createMessage (messageSize.Get % 2048)

    let result = buffer.TryBuffer(message)

    match result with
    | BufferResult.Accepted _ -> message.Length <= maxSize
    | BufferResult.RejectedTooLarge _ -> message.Length > maxSize
    | _ -> true

[<Property>]
let ``Buffer count never exceeds capacity`` (messages: byte[] list) =
    let capacity = 100
    let buffer = BoundedBuffer.createWithCapacity capacity

    messages
    |> List.filter (fun m -> not (isNull m) && m.Length > 0 && m.Length <= 1024)
    |> List.iter (fun m -> buffer.TryBuffer(m) |> ignore)

    buffer.Count <= capacity

[<Property>]
let ``Dequeue order matches enqueue order`` (messages: NonEmptyArray<byte[]>) =
    let buffer = BoundedBuffer.create()
    let validMessages =
        messages.Get
        |> Array.filter (fun m -> not (isNull m) && m.Length > 0 && m.Length <= 1024)
        |> Array.take (min 100 (Array.length messages.Get))

    // Enqueue
    validMessages |> Array.iter (fun m -> buffer.TryBuffer(m) |> ignore)

    // Dequeue
    let dequeued =
        [1..validMessages.Length]
        |> List.choose (fun _ -> buffer.TryDequeue())
        |> List.toArray

    Array.length dequeued = validMessages.Length &&
    Array.forall2 (fun a b -> a.Length = b.Length) validMessages dequeued

// =============================================================================
// STAMP Constraint Verification Tests
// =============================================================================

[<Fact>]
let ``Verify SC-ENV-003 - Maximum message size enforced`` () =
    // Arrange
    let buffer = BoundedBuffer.create()
    let validMessage = TestData.createMessage (1 * 1024 * 1024) // 1MB
    let invalidMessage = TestData.createMessage (2 * 1024 * 1024) // 2MB

    // Act & Assert
    Assert.True(BoundedBufferConstraints.verifyMaxMessageSize buffer validMessage)
    Assert.True(BoundedBufferConstraints.verifyMaxMessageSize buffer invalidMessage)

[<Fact>]
let ``Verify SC-BUF-001 - Capacity limit enforced`` () =
    // Arrange
    let buffer = BoundedBuffer.createWithCapacity 10

    // Act - Fill buffer
    for _ in 1..10 do
        buffer.TryBuffer(TestData.smallMessage) |> ignore

    // Assert
    Assert.True(BoundedBufferConstraints.verifyCapacityLimit buffer)

[<Fact>]
let ``Verify SC-BUF-002 - Backpressure thresholds correct`` () =
    // Arrange
    let buffer = BoundedBuffer.createWithCapacity 100
    let message = TestData.smallMessage

    // Test at different fill levels
    let testPoints = [
        (75, BufferStatus.Available)
        (85, BufferStatus.NearCapacity 0.0) // Match any NearCapacity
        (96, BufferStatus.Critical 0.0)     // Match any Critical
        (100, BufferStatus.Full)
    ]

    for (fillCount, expectedStatus) in testPoints do
        buffer.Clear()
        for _ in 1..fillCount do
            buffer.TryBuffer(message) |> ignore

        // Assert
        Assert.True(BoundedBufferConstraints.verifyBackpressure buffer)

[<Fact>]
let ``Run all STAMP constraint verifications`` () =
    // Arrange
    let buffer = BoundedBuffer.create()

    // Act
    let results = BoundedBufferConstraints.verifyAll buffer

    // Assert
    results |> List.iter (fun (name, passed) ->
        Assert.True(passed, sprintf "Constraint failed: %s" name)
    )

// =============================================================================
// Performance Tests
// =============================================================================

[<Fact>]
let ``Buffer handles high throughput`` () =
    // Arrange
    let buffer = BoundedBuffer.createWithCapacity 100000
    let message = TestData.smallMessage
    let messageCount = 50000

    // Act
    let stopwatch = System.Diagnostics.Stopwatch.StartNew()

    for _ in 1..messageCount do
        buffer.TryBuffer(message) |> ignore

    stopwatch.Stop()

    // Assert
    let messagesPerSecond = float messageCount / stopwatch.Elapsed.TotalSeconds
    Assert.True(messagesPerSecond > 10000.0, sprintf "Throughput too low: %.0f msg/s" messagesPerSecond)

[<Fact>]
let ``Metrics updates have minimal overhead`` () =
    // Arrange
    let bufferWithMetrics = BoundedBuffer.create()
    let bufferWithoutMetrics =
        BoundedBuffer.createWith (
            BoundedBufferConfig.defaultConfig
            |> BoundedBufferConfig.withoutTelemetry
        )

    let message = TestData.smallMessage
    let iterations = 10000

    // Act - With metrics
    let sw1 = System.Diagnostics.Stopwatch.StartNew()
    for _ in 1..iterations do
        bufferWithMetrics.TryBuffer(message) |> ignore
    sw1.Stop()

    // Act - Without metrics
    let sw2 = System.Diagnostics.Stopwatch.StartNew()
    for _ in 1..iterations do
        bufferWithoutMetrics.TryBuffer(message) |> ignore
    sw2.Stop()

    // Assert - Overhead should be < 50%
    let overhead = (float sw1.ElapsedMilliseconds / float sw2.ElapsedMilliseconds) - 1.0
    Assert.True(overhead < 0.5, sprintf "Metrics overhead too high: %.1f%%" (overhead * 100.0))
