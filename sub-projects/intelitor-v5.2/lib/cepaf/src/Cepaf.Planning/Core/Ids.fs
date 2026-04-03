// =============================================================================
// Ids.fs - ULID-based ID Generation for Planning System
// =============================================================================
// STAMP: SC-PLAN-002
// AOR: AOR-PLAN-002
// Criticality: Level 1 (CRITICAL) - Foundation
// =============================================================================

namespace Cepaf.Planning.Core

open System
open System.Security.Cryptography

/// ULID-based identifiers for lexicographic sorting and uniqueness
module Ids =

    // Crockford Base32 alphabet (excludes I, L, O, U to avoid confusion)
    let private alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

    /// Generate cryptographically random bytes
    let private randomBytes (count: int) =
        let bytes = Array.zeroCreate<byte> count
        RandomNumberGenerator.Fill(bytes)
        bytes

    /// Encode timestamp (48 bits = 6 bytes) to Base32 (10 chars)
    let private encodeTimestamp (timestamp: int64) =
        let chars = Array.zeroCreate<char> 10
        let mutable ts = timestamp
        for i in 9 .. -1 .. 0 do
            chars.[i] <- alphabet.[int (ts % 32L)]
            ts <- ts / 32L
        String(chars)

    /// Encode randomness (80 bits = 10 bytes) to Base32 (16 chars)
    let private encodeRandomness (bytes: byte[]) =
        let chars = Array.zeroCreate<char> 16
        let mutable bitBuffer = 0UL
        let mutable bitsInBuffer = 0
        let mutable charIndex = 0
        let mutable byteIndex = 0

        while charIndex < 16 do
            if bitsInBuffer < 5 && byteIndex < bytes.Length then
                bitBuffer <- (bitBuffer <<< 8) ||| uint64 bytes.[byteIndex]
                bitsInBuffer <- bitsInBuffer + 8
                byteIndex <- byteIndex + 1

            let shift = bitsInBuffer - 5
            let index = int ((bitBuffer >>> shift) &&& 0x1FUL)
            chars.[charIndex] <- alphabet.[index]
            bitsInBuffer <- shift
            bitBuffer <- bitBuffer &&& ((1UL <<< shift) - 1UL)
            charIndex <- charIndex + 1

        String(chars)

    /// Generate a new ULID (26 characters)
    let generateUlid () : string =
        let timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
        let randomness = randomBytes 10
        encodeTimestamp timestamp + encodeRandomness randomness

    /// Generate a shorter ID (16 characters) for internal use
    let generateShortId () : string =
        let timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
        let randomness = randomBytes 4
        let ts = encodeTimestamp timestamp
        let rnd = encodeRandomness (Array.append randomness (Array.zeroCreate 6))
        ts.Substring(4) + rnd.Substring(0, 10)  // 6 + 10 = 16 chars

    // === Strongly-typed IDs ===

    /// Task identifier
    type TaskId = TaskId of string
        with
        member this.Value = match this with TaskId id -> id
        override this.ToString() = this.Value

    /// Project identifier
    type ProjectId = ProjectId of string
        with
        member this.Value = match this with ProjectId id -> id
        override this.ToString() = this.Value

    /// Sprint identifier
    type SprintId = SprintId of string
        with
        member this.Value = match this with SprintId id -> id
        override this.ToString() = this.Value

    /// User/Actor identifier
    type UserId = UserId of string
        with
        member this.Value = match this with UserId id -> id
        override this.ToString() = this.Value

    /// Holon identifier (compatible with DigitalTwin)
    type HolonId = HolonId of string
        with
        member this.Value = match this with HolonId id -> id
        override this.ToString() = this.Value

    /// OODA Cycle identifier
    type OODACycleId = OODACycleId of string
        with
        member this.Value = match this with OODACycleId id -> id
        override this.ToString() = this.Value

    /// Event identifier
    type EventId = EventId of Guid
        with
        member this.Value = match this with EventId id -> id
        override this.ToString() = this.Value.ToString("N")

    /// Correlation identifier (for distributed tracing)
    type CorrelationId = CorrelationId of Guid
        with
        member this.Value = match this with CorrelationId id -> id
        override this.ToString() = this.Value.ToString("N")

    // === ID Generators ===

    let newTaskId () = TaskId (generateUlid ())
    let newProjectId () = ProjectId (generateUlid ())
    let newSprintId () = SprintId (generateUlid ())
    let newUserId () = UserId (generateUlid ())
    let newHolonId () = HolonId (generateUlid ())
    let newOODACycleId () = OODACycleId (generateUlid ())
    let newEventId () = EventId (Guid.NewGuid ())
    let newCorrelationId () = CorrelationId (Guid.NewGuid ())

    // === ID Parsers ===

    let parseTaskId (s: string) =
        if String.IsNullOrWhiteSpace(s) then Error "TaskId cannot be empty"
        else Ok (TaskId s)

    let parseProjectId (s: string) =
        if String.IsNullOrWhiteSpace(s) then Error "ProjectId cannot be empty"
        else Ok (ProjectId s)

    let parseSprintId (s: string) =
        if String.IsNullOrWhiteSpace(s) then Error "SprintId cannot be empty"
        else Ok (SprintId s)

    let parseUserId (s: string) =
        if String.IsNullOrWhiteSpace(s) then Error "UserId cannot be empty"
        else Ok (UserId s)

    let parseHolonId (s: string) =
        if String.IsNullOrWhiteSpace(s) then Error "HolonId cannot be empty"
        else Ok (HolonId s)

    // === Value extractors ===

    let taskIdValue (TaskId id) = id
    let projectIdValue (ProjectId id) = id
    let sprintIdValue (SprintId id) = id
    let userIdValue (UserId id) = id
    let holonIdValue (HolonId id) = id
    let oodaCycleIdValue (OODACycleId id) = id
    let eventIdValue (EventId id) = id
    let correlationIdValue (CorrelationId id) = id
