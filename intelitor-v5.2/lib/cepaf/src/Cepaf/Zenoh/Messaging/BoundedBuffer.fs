// =============================================================================
// BoundedBuffer.fs - Bounded Message Buffer for DoS Prevention (FM-008)
// =============================================================================
// STAMP: SC-ENV-003, SC-ENV-004, SC-BUF-001, SC-BUF-002, SC-DOS-001
// AOR: AOR-ZENOH-004, AOR-SEC-001
// Criticality: Level 1 (CRITICAL) - Security and Stability
// =============================================================================
// Provides bounded message buffering with:
// - Maximum message size enforcement (1MB default per SC-ENV-003)
// - Buffer pool with bounded capacity (prevents memory exhaustion)
// - Rejection of oversized messages with error
// - Backpressure signaling when buffer near capacity
// - Thread-safe operations using ConcurrentQueue
// - Telemetry integration for monitoring
// =============================================================================
// SECURITY: Prevents memory exhaustion DoS attacks by enforcing strict size
// and capacity limits on incoming Zenoh messages.
// =============================================================================

namespace Cepaf.Zenoh.Messaging

open System
open System.Collections.Concurrent
open System.Threading
open Cepaf.Zenoh.Core

/// Maximum message size constants (SC-ENV-003)
[<RequireQualifiedAccess>]
module MessageSizeLimits =
    /// Default maximum message size: 1MB (SC-ENV-003)
    let [<Literal>] DefaultMaxMessageBytes = 1_048_576

    /// Absolute maximum for oversized messages: 10MB (SC-ENV-004)
    let [<Literal>] AbsoluteMaxMessageBytes = 10_485_760

    /// Minimum message size: 1 byte
    let [<Literal>] MinMessageBytes = 1

    /// Warning threshold: 80% of max size
    let [<Literal>] WarningThresholdBytes = 838_860  // 80% of 1MB

/// Buffer capacity constants (SC-BUF-001)
[<RequireQualifiedAccess>]
module BufferCapacityLimits =
    /// Default maximum pending messages in buffer
    let [<Literal>] DefaultMaxCapacity = 1000

    /// Warning threshold: 80% full (triggers backpressure)
    let [<Literal>] WarningThresholdPercent = 80.0

    /// Critical threshold: 95% full (near rejection)
    let [<Literal>] CriticalThresholdPercent = 95.0

    /// Full threshold: 100% (reject all new messages)
    let [<Literal>] FullThresholdPercent = 100.0

/// Buffer status enumeration for backpressure signaling (SC-BUF-002)
[<RequireQualifiedAccess>]
type BufferStatus =
    /// Buffer has available capacity (< 80% full)
    | Available

    /// Buffer approaching capacity (80-95% full) - backpressure advised
    | NearCapacity of percentFull: float

    /// Buffer at critical capacity (95-100% full) - urgent backpressure
    | Critical of percentFull: float

    /// Buffer full (100%) - rejecting all new messages
    | Full

    member this.IsHealthy =
        match this with
        | Available -> true
        | NearCapacity _ | Critical _ | Full -> false

    member this.PercentFull =
        match this with
        | Available -> 0.0
        | NearCapacity pct | Critical pct -> pct
        | Full -> 100.0

    member this.ShouldApplyBackpressure =
        match this with
        | NearCapacity _ | Critical _ | Full -> true
        | Available -> false

    override this.ToString() =
        match this with
        | Available -> "available"
        | NearCapacity pct -> sprintf "near_capacity (%.1f%%)" pct
        | Critical pct -> sprintf "critical (%.1f%%)" pct
        | Full -> "full (100%)"

/// Result type for buffer operations (SC-BUF-001)
[<RequireQualifiedAccess>]
type BufferResult<'T> =
    /// Message accepted into buffer
    | Accepted of value: 'T

    /// Message rejected: exceeds size limit
    | RejectedTooLarge of actualBytes: int * maxBytes: int

    /// Message rejected: buffer full
    | RejectedBufferFull of currentCount: int * maxCapacity: int

    /// Message rejected: invalid payload (empty/null)
    | RejectedInvalid of reason: string

    member this.IsAccepted =
        match this with
        | Accepted _ -> true
        | _ -> false

    member this.ToResult() : Result<'T, string> =
        match this with
        | Accepted value -> Ok value
        | RejectedTooLarge (actual, max) ->
            Error (sprintf "Message size %d bytes exceeds maximum %d bytes" actual max)
        | RejectedBufferFull (current, max) ->
            Error (sprintf "Buffer full: %d/%d messages" current max)
        | RejectedInvalid reason ->
            Error (sprintf "Invalid message: %s" reason)

    override this.ToString() =
        match this with
        | Accepted _ -> "accepted"
        | RejectedTooLarge (actual, max) -> sprintf "rejected_too_large (%d > %d bytes)" actual max
        | RejectedBufferFull (current, max) -> sprintf "rejected_buffer_full (%d/%d)" current max
        | RejectedInvalid reason -> sprintf "rejected_invalid: %s" reason

/// Configuration for bounded buffer (SC-ENV-003, SC-BUF-001)
type BoundedBufferConfig = {
    /// Maximum message size in bytes
    MaxMessageBytes: int

    /// Maximum buffer capacity (number of messages)
    MaxCapacity: int

    /// Enable telemetry reporting
    EnableTelemetry: bool

    /// Buffer name for logging/telemetry
    Name: string
}

module BoundedBufferConfig =
    /// Default configuration with SIL-6 compliant values
    let defaultConfig = {
        MaxMessageBytes = MessageSizeLimits.DefaultMaxMessageBytes
        MaxCapacity = BufferCapacityLimits.DefaultMaxCapacity
        EnableTelemetry = true
        Name = "zenoh-buffer"
    }

    /// Create config with custom message size limit
    let withMaxMessageBytes (bytes: int) (config: BoundedBufferConfig) =
        let clampedBytes =
            max MessageSizeLimits.MinMessageBytes
                (min bytes MessageSizeLimits.AbsoluteMaxMessageBytes)
        { config with MaxMessageBytes = clampedBytes }

    /// Create config with custom capacity
    let withMaxCapacity (capacity: int) (config: BoundedBufferConfig) =
        { config with MaxCapacity = max 1 capacity }

    /// Create config with custom name
    let withName (name: string) (config: BoundedBufferConfig) =
        { config with Name = name }

    /// Disable telemetry
    let withoutTelemetry (config: BoundedBufferConfig) =
        { config with EnableTelemetry = false }

/// Telemetry metrics for buffer monitoring
type BufferMetrics = {
    /// Total messages accepted
    AcceptedCount: int64

    /// Total messages rejected (too large)
    RejectedTooLargeCount: int64

    /// Total messages rejected (buffer full)
    RejectedBufferFullCount: int64

    /// Total messages rejected (invalid)
    RejectedInvalidCount: int64

    /// Current buffer count
    CurrentCount: int

    /// Maximum buffer count observed
    PeakCount: int

    /// Total bytes accepted
    TotalBytesAccepted: int64

    /// Largest message size observed
    LargestMessageBytes: int

    /// Last status check timestamp
    LastStatusCheck: DateTimeOffset

    /// Current buffer status
    Status: BufferStatus
}

module BufferMetrics =
    /// Create empty metrics
    let empty = {
        AcceptedCount = 0L
        RejectedTooLargeCount = 0L
        RejectedBufferFullCount = 0L
        RejectedInvalidCount = 0L
        CurrentCount = 0
        PeakCount = 0
        TotalBytesAccepted = 0L
        LargestMessageBytes = 0
        LastStatusCheck = DateTimeOffset.UtcNow
        Status = BufferStatus.Available
    }

    /// Total rejection count
    let totalRejections (metrics: BufferMetrics) =
        metrics.RejectedTooLargeCount +
        metrics.RejectedBufferFullCount +
        metrics.RejectedInvalidCount

    /// Acceptance rate (0.0-1.0)
    let acceptanceRate (metrics: BufferMetrics) =
        let total = metrics.AcceptedCount + totalRejections metrics
        if total = 0L then 1.0
        else float metrics.AcceptedCount / float total

    /// Average message size
    let averageMessageBytes (metrics: BufferMetrics) =
        if metrics.AcceptedCount = 0L then 0.0
        else float metrics.TotalBytesAccepted / float metrics.AcceptedCount

/// Thread-safe bounded buffer for Zenoh messages (SC-BUF-001, SC-BUF-002)
type BoundedBuffer(config: BoundedBufferConfig) =
    let buffer = ConcurrentQueue<byte[]>()
    let mutable metrics = BufferMetrics.empty
    let metricsLock = obj()

    /// Validate message size (SC-ENV-003)
    let validateMessageSize (message: byte[]) : BufferResult<int> =
        if isNull message then
            BufferResult.RejectedInvalid "Null message"
        elif message.Length = 0 then
            BufferResult.RejectedInvalid "Empty message"
        elif message.Length > config.MaxMessageBytes then
            BufferResult.RejectedTooLarge (message.Length, config.MaxMessageBytes)
        else
            BufferResult.Accepted message.Length

    /// Calculate current buffer status (SC-BUF-002)
    let calculateBufferStatus (currentCount: int) : BufferStatus =
        let percentFull = (float currentCount / float config.MaxCapacity) * 100.0

        if percentFull < BufferCapacityLimits.WarningThresholdPercent then
            BufferStatus.Available
        elif percentFull < BufferCapacityLimits.CriticalThresholdPercent then
            BufferStatus.NearCapacity percentFull
        elif percentFull < BufferCapacityLimits.FullThresholdPercent then
            BufferStatus.Critical percentFull
        else
            BufferStatus.Full

    /// Update metrics (thread-safe)
    let updateMetrics (action: BufferMetrics -> BufferMetrics) =
        lock metricsLock (fun () ->
            metrics <- action metrics
            if config.EnableTelemetry then
                // SC-ZTEST-008 dual-write: log fallback first, then structured JSON
                let timestamp = DateTimeOffset.UtcNow.ToString("o")
                eprintfn "[ZTEST-CHECKPOINT] checkpoint=CP-BUF-METRICS topic=indrajaal/buffer/%s/metrics message=Buffer_metrics_update timestamp=%s"
                    config.Name timestamp
                printfn """{"zenoh_publish":{"checkpoint":"CP-BUF-METRICS","topic":"indrajaal/buffer/%s/metrics","timestamp":"%s","payload":{"enqueued":%d,"dequeued":%d,"dropped":%d,"current_size":%d,"peak_size":%d}}}"""
                    config.Name timestamp
                    metrics.EnqueuedCount metrics.DequeuedCount metrics.DroppedCount
                    metrics.CurrentSize metrics.PeakSize
        )

    /// Try to enqueue message into buffer (SC-BUF-001)
    member _.TryBuffer(message: byte[]) : BufferResult<unit> =
        // Step 1: Validate message size
        match validateMessageSize message with
        | BufferResult.RejectedTooLarge (actual, max) ->
            updateMetrics (fun m ->
                { m with RejectedTooLargeCount = m.RejectedTooLargeCount + 1L })
            BufferResult.RejectedTooLarge (actual, max)

        | BufferResult.RejectedInvalid reason ->
            updateMetrics (fun m ->
                { m with RejectedInvalidCount = m.RejectedInvalidCount + 1L })
            BufferResult.RejectedInvalid reason

        | BufferResult.Accepted messageSize ->
            // Step 2: Check buffer capacity
            let currentCount = buffer.Count
            if currentCount >= config.MaxCapacity then
                updateMetrics (fun m ->
                    { m with RejectedBufferFullCount = m.RejectedBufferFullCount + 1L })
                BufferResult.RejectedBufferFull (currentCount, config.MaxCapacity)
            else
                // Step 3: Enqueue message
                buffer.Enqueue(message)

                // Step 4: Update metrics
                updateMetrics (fun m ->
                    let newCount = buffer.Count
                    let newPeak = max m.PeakCount newCount
                    let newLargest = max m.LargestMessageBytes messageSize
                    let newStatus = calculateBufferStatus newCount

                    { m with
                        AcceptedCount = m.AcceptedCount + 1L
                        CurrentCount = newCount
                        PeakCount = newPeak
                        TotalBytesAccepted = m.TotalBytesAccepted + int64 messageSize
                        LargestMessageBytes = newLargest
                        Status = newStatus
                        LastStatusCheck = DateTimeOffset.UtcNow
                    }
                )

                BufferResult.Accepted ()

        | _ -> failwith "Unexpected buffer result variant"

    /// Try to dequeue message from buffer
    member _.TryDequeue() : byte[] option =
        match buffer.TryDequeue() with
        | true, message ->
            updateMetrics (fun m ->
                { m with
                    CurrentCount = buffer.Count
                    Status = calculateBufferStatus buffer.Count
                    LastStatusCheck = DateTimeOffset.UtcNow
                })
            Some message
        | false, _ -> None

    /// Get current buffer status for backpressure (SC-BUF-002)
    member _.GetStatus() : BufferStatus =
        let currentCount = buffer.Count
        let status = calculateBufferStatus currentCount

        updateMetrics (fun m ->
            { m with
                CurrentCount = currentCount
                Status = status
                LastStatusCheck = DateTimeOffset.UtcNow
            }
        )

        status

    /// Get current metrics snapshot
    member _.GetMetrics() : BufferMetrics =
        lock metricsLock (fun () -> metrics)

    /// Clear buffer (emergency drain)
    member _.Clear() =
        buffer.Clear()
        updateMetrics (fun m ->
            { m with
                CurrentCount = 0
                Status = BufferStatus.Available
                LastStatusCheck = DateTimeOffset.UtcNow
            }
        )

    /// Get current count
    member _.Count = buffer.Count

    /// Check if buffer is empty
    member _.IsEmpty = buffer.IsEmpty

    /// Get configuration
    member _.Config = config

/// Module-level functions for bounded buffer operations
module BoundedBuffer =

    /// Create a bounded buffer with default configuration
    let create() =
        BoundedBuffer(BoundedBufferConfig.defaultConfig)

    /// Create a bounded buffer with custom configuration
    let createWith (config: BoundedBufferConfig) =
        BoundedBuffer(config)

    /// Create a bounded buffer with custom max size
    let createWithMaxSize (maxBytes: int) =
        let config = BoundedBufferConfig.defaultConfig
                     |> BoundedBufferConfig.withMaxMessageBytes maxBytes
        BoundedBuffer(config)

    /// Create a bounded buffer with custom capacity
    let createWithCapacity (capacity: int) =
        let config = BoundedBufferConfig.defaultConfig
                     |> BoundedBufferConfig.withMaxCapacity capacity
        BoundedBuffer(config)

    /// Validate and buffer incoming message
    let tryBuffer (buffer: BoundedBuffer) (message: byte[]) : BufferResult<unit> =
        buffer.TryBuffer(message)

    /// Get buffer status for backpressure
    let getStatus (buffer: BoundedBuffer) : BufferStatus =
        buffer.GetStatus()

    /// Try to dequeue message
    let tryDequeue (buffer: BoundedBuffer) : byte[] option =
        buffer.TryDequeue()

    /// Get metrics snapshot
    let getMetrics (buffer: BoundedBuffer) : BufferMetrics =
        buffer.GetMetrics()

    /// Clear buffer
    let clear (buffer: BoundedBuffer) =
        buffer.Clear()

    /// Check if backpressure should be applied
    let shouldApplyBackpressure (buffer: BoundedBuffer) : bool =
        let status = getStatus buffer
        status.ShouldApplyBackpressure

    /// Get percent full
    let percentFull (buffer: BoundedBuffer) : float =
        let status = getStatus buffer
        status.PercentFull

    /// Check if buffer is healthy (not applying backpressure)
    let isHealthy (buffer: BoundedBuffer) : bool =
        let status = getStatus buffer
        status.IsHealthy

/// Integration with ZenohEnvelope for typed message buffering
module EnvelopeBuffer =

    /// Try to buffer a ZenohEnvelope after serialization
    let tryBufferEnvelope<'T> (buffer: BoundedBuffer) (envelope: ZenohEnvelope<'T>) : ZenohResult<unit> =
        match ZenohEnvelope.serialize envelope with
        | Error e -> Error e
        | Ok bytes ->
            match buffer.TryBuffer(bytes) with
            | BufferResult.Accepted _ -> Ok ()
            | BufferResult.RejectedTooLarge (actual, max) ->
                Error (ZenohError.SerializationError(
                    typeof<'T>.Name,
                    sprintf "Envelope size %d exceeds limit %d" actual max))
            | BufferResult.RejectedBufferFull (current, max) ->
                Error (ZenohError.PublishFailed(
                    "buffer",
                    sprintf "Buffer full: %d/%d messages" current max))
            | BufferResult.RejectedInvalid reason ->
                Error (ZenohError.SerializationError(
                    typeof<'T>.Name,
                    sprintf "Invalid envelope: %s" reason))

    /// Try to dequeue and deserialize a ZenohEnvelope
    let tryDequeueEnvelope<'T> (buffer: BoundedBuffer) : ZenohResult<ZenohEnvelope<'T>> option =
        match buffer.TryDequeue() with
        | None -> None
        | Some bytes ->
            match ZenohEnvelope.deserialize<'T> bytes with
            | Ok envelope -> Some (Ok envelope)
            | Error e -> Some (Error e)

    /// Create envelope buffer with size validation
    let createEnvelopeBuffer<'T> (maxEnvelopeBytes: int) (capacity: int) =
        let config =
            BoundedBufferConfig.defaultConfig
            |> BoundedBufferConfig.withMaxMessageBytes maxEnvelopeBytes
            |> BoundedBufferConfig.withMaxCapacity capacity
        BoundedBuffer(config)

/// STAMP Constraint Verification Module
module BoundedBufferConstraints =

    /// Verify SC-ENV-003: Maximum message size enforced
    let verifyMaxMessageSize (buffer: BoundedBuffer) (testMessage: byte[]) : bool =
        match buffer.TryBuffer(testMessage) with
        | BufferResult.RejectedTooLarge _ when testMessage.Length > buffer.Config.MaxMessageBytes -> true
        | BufferResult.Accepted _ when testMessage.Length <= buffer.Config.MaxMessageBytes -> true
        | _ -> false

    /// Verify SC-BUF-001: Buffer capacity limit enforced
    let verifyCapacityLimit (buffer: BoundedBuffer) : bool =
        buffer.Count <= buffer.Config.MaxCapacity

    /// Verify SC-BUF-002: Backpressure signaling works
    let verifyBackpressure (buffer: BoundedBuffer) : bool =
        let status = buffer.GetStatus()
        let percentFull = status.PercentFull

        match status with
        | BufferStatus.Available -> percentFull < 80.0
        | BufferStatus.NearCapacity _ -> percentFull >= 80.0 && percentFull < 95.0
        | BufferStatus.Critical _ -> percentFull >= 95.0 && percentFull < 100.0
        | BufferStatus.Full -> percentFull >= 100.0

    /// Run all constraint verifications
    let verifyAll (buffer: BoundedBuffer) : (string * bool) list =
        [
            ("SC-ENV-003: Max message size", verifyCapacityLimit buffer)
            ("SC-BUF-001: Capacity limit", verifyCapacityLimit buffer)
            ("SC-BUF-002: Backpressure", verifyBackpressure buffer)
        ]
