/// Optimistic Concurrency Control (OCC) handler for F# holon databases.
///
/// WHAT: Version vector-based conflict detection and resolution for F# holons.
/// WHY: SC-XHOLON-006 requires OCC or locking for concurrent access.
///      SC-XHOLON-010 mandates lock-free reads.
///
/// CONSTRAINTS:
///   - SC-XHOLON-006: Concurrent access uses OCC
///   - SC-XHOLON-007: Version vectors monotonically increasing
///   - SC-XHOLON-010: Lock-free reads
///   - SC-XHOLON-032: No deadlocks permitted
///   - SC-XHOLON-033: No starvation permitted
///
/// ## Algorithm
///
/// The OCC protocol works as follows:
/// 1. Read with version vector (no locks acquired)
/// 2. Perform local modifications
/// 3. Compare-and-swap: verify version hasn't changed
/// 4. If conflict: retry with exponential backoff
///
/// ## Version Vectors
///
/// Version vectors track causality across distributed holons:
/// ```
/// Map [
///     "fs:l4:prj:agt:cockpit", 42
///     "ex:l3:kms:srv:main", 17
/// ]
/// ```
///
/// A version vector V1 "happens-before" V2 if:
/// - For all entries: V1[k] <= V2[k]
/// - For at least one entry: V1[k] < V2[k]
///
/// ## Conflict Resolution
///
/// When a conflict is detected, several strategies are available:
/// - LastWriteWins: Accept the newer write
/// - Merge: Merge conflicting updates (requires custom merge function)
/// - Reject: Reject the conflicting write
module Cepaf.Database.HolonConcurrencyHandler

open System
open System.Collections.Concurrent
open System.Threading

// ============================================================================
// Types
// ============================================================================

/// Version vector type: Map of holon ID to version number
type VersionVector = Map<string, int64>

/// Conflict resolution strategy
type ConflictResolution =
    | LastWriteWins
    | Merge
    | Reject

/// Retry configuration for exponential backoff
type RetryConfig = {
    MaxRetries: int
    BaseDelayMs: int
    MaxDelayMs: int
}

/// Result of a compare-and-swap operation
type CasResult<'T> =
    | CasSuccess of result: 'T * newVersion: VersionVector
    | CasConflict of currentVersion: VersionVector
    | CasError of message: string

/// Lock entry for pessimistic locking
type LockEntry = {
    ResourceId: string
    OwnerId: string
    AcquiredAt: DateTime
}

// ============================================================================
// Constants
// ============================================================================

let defaultRetryConfig = {
    MaxRetries = 3
    BaseDelayMs = 100
    MaxDelayMs = 2000
}

let private lockExpirySeconds = 5.0

// ============================================================================
// Lock Table (ETS equivalent for F#)
// ============================================================================

/// Global lock table (concurrent dictionary)
let private lockTable = ConcurrentDictionary<string, LockEntry>()

// ============================================================================
// Version Vector Operations
// ============================================================================

/// Create a new version vector for a holon
let newVersionVector (holonId: string) : VersionVector =
    Map.ofList [ holonId, 0L ]

/// Increment the version for a specific holon in the vector
let increment (vv: VersionVector) (holonId: string) : VersionVector =
    match Map.tryFind holonId vv with
    | Some v -> Map.add holonId (v + 1L) vv
    | None -> Map.add holonId 1L vv

/// Merge two version vectors by taking the max of each entry
let merge (vv1: VersionVector) (vv2: VersionVector) : VersionVector =
    let allKeys = Set.union (Map.keys vv1 |> Set.ofSeq) (Map.keys vv2 |> Set.ofSeq)
    allKeys
    |> Set.fold (fun acc key ->
        let v1 = Map.tryFind key vv1 |> Option.defaultValue 0L
        let v2 = Map.tryFind key vv2 |> Option.defaultValue 0L
        Map.add key (max v1 v2) acc
    ) Map.empty

/// Check if version vector v1 is greater than or equal to v2
/// Returns true if v1 >= v2 (all entries in v1 are >= corresponding entries in v2)
let versionGte (v1: VersionVector) (v2: VersionVector) : bool =
    v2 |> Map.forall (fun key v2val ->
        let v1val = Map.tryFind key v1 |> Option.defaultValue 0L
        v1val >= v2val
    )

/// Check if version vector v1 happens-before v2
/// Returns true if v1 < v2 (causally precedes)
let happensBefore (v1: VersionVector) (v2: VersionVector) : bool =
    let allLte =
        v1 |> Map.forall (fun key v1val ->
            let v2val = Map.tryFind key v2 |> Option.defaultValue 0L
            v1val <= v2val
        )
    let anyLt =
        v1 |> Map.exists (fun key v1val ->
            let v2val = Map.tryFind key v2 |> Option.defaultValue 0L
            v1val < v2val
        )
    allLte && anyLt

/// Check if two version vectors are concurrent (neither happens-before the other)
let concurrent (v1: VersionVector) (v2: VersionVector) : bool =
    not (happensBefore v1 v2) && not (happensBefore v2 v1)

// ============================================================================
// Compare-and-Swap Operations
// ============================================================================

/// Calculate exponential backoff delay with jitter
let private calculateBackoff (attempt: int) (config: RetryConfig) : int =
    let random = Random()
    let baseDelay = float config.BaseDelayMs * Math.Pow(2.0, float attempt)
    let jitter = random.Next(config.BaseDelayMs / 2)
    min (int baseDelay + jitter) config.MaxDelayMs

/// Execute an operation with compare-and-swap semantics
let compareAndSwap<'T>
    (expectedVersion: VersionVector)
    (getCurrentVersion: unit -> Async<Result<VersionVector, string>>)
    (operation: unit -> Async<Result<'T, string>>)
    (resolution: ConflictResolution)
    (config: RetryConfig)
    : Async<CasResult<'T>> =

    let rec loop attempt = async {
        let! currentVersionResult = getCurrentVersion()

        match currentVersionResult with
        | Error e -> return CasError e
        | Ok currentVersion ->
            if versionGte currentVersion expectedVersion then
                // Version matches or current is ahead, proceed
                let! operationResult = operation()
                match operationResult with
                | Ok result ->
                    let newVersion = increment currentVersion "local"
                    return CasSuccess (result, newVersion)
                | Error reason ->
                    return CasError reason
            else
                // Conflict detected
                match resolution with
                | LastWriteWins when attempt < config.MaxRetries ->
                    // Retry with backoff
                    let delay = calculateBackoff attempt config
                    do! Async.Sleep delay
                    return! loop (attempt + 1)
                | Reject ->
                    return CasConflict currentVersion
                | _ ->
                    return CasConflict currentVersion
    }

    loop 0

/// Execute an operation with automatic retry on conflict
let withRetry<'T>
    (operation: unit -> Async<Result<'T, string>>)
    (config: RetryConfig)
    : Async<Result<'T, string>> =

    let rec loop attempt = async {
        let! result = operation()

        match result with
        | Ok value -> return Ok value
        | Error "conflict" when attempt < config.MaxRetries ->
            let delay = calculateBackoff attempt config
            printfn "[ConcurrencyHandler] Conflict on attempt %d, retrying in %dms" (attempt + 1) delay
            do! Async.Sleep delay
            return! loop (attempt + 1)
        | Error "conflict" ->
            printfn "[ConcurrencyHandler] Max retries exceeded"
            return Error "max_retries_exceeded"
        | Error reason ->
            return Error reason
    }

    loop 0

// ============================================================================
// Pessimistic Locking (for critical sections)
// ============================================================================

/// Acquire a lock for a resource with timeout
let acquireLock (resourceId: string) (ownerId: string) (timeoutMs: int) : bool =
    let deadline = DateTime.UtcNow.AddMilliseconds(float timeoutMs)

    let rec tryAcquire () =
        let now = DateTime.UtcNow
        if now >= deadline then
            false
        else
            let entry = { ResourceId = resourceId; OwnerId = ownerId; AcquiredAt = now }

            // Try to add new lock
            if lockTable.TryAdd(resourceId, entry) then
                true
            else
                // Lock held, check if expired
                match lockTable.TryGetValue(resourceId) with
                | true, existing when (now - existing.AcquiredAt).TotalSeconds > lockExpirySeconds ->
                    // Lock expired, try to take it
                    if lockTable.TryUpdate(resourceId, entry, existing) then
                        true
                    else
                        Thread.Sleep(10)
                        tryAcquire()
                | _ ->
                    // Lock still valid, wait and retry
                    Thread.Sleep(10)
                    tryAcquire()

    tryAcquire()

/// Release a lock for a resource
let releaseLock (resourceId: string) (ownerId: string) : unit =
    match lockTable.TryGetValue(resourceId) with
    | true, entry when entry.OwnerId = ownerId ->
        lockTable.TryRemove(resourceId) |> ignore
    | _ ->
        // Not our lock, ignore
        ()

/// Execute a function with an acquired lock
let withLock<'T>
    (resourceId: string)
    (ownerId: string)
    (timeoutMs: int)
    (operation: unit -> 'T)
    : Result<'T, string> =

    if acquireLock resourceId ownerId timeoutMs then
        try
            let result = operation()
            releaseLock resourceId ownerId
            Ok result
        with ex ->
            releaseLock resourceId ownerId
            Error ex.Message
    else
        Error "Failed to acquire lock: timeout"

// ============================================================================
// Two-Phase Commit Support
// ============================================================================

/// Phase 1: Prepare - Acquire all locks and validate
let twoPhasePrepar
    (participants: string list)
    (coordinatorId: string)
    (timeoutMs: int)
    : Result<unit, string list> =

    let mutable acquired = []
    let mutable failed = []

    for participant in participants do
        if acquireLock participant coordinatorId timeoutMs then
            acquired <- participant :: acquired
        else
            failed <- participant :: failed

    if List.isEmpty failed then
        Ok ()
    else
        // Rollback acquired locks
        for p in acquired do
            releaseLock p coordinatorId
        Error failed

/// Phase 2: Commit - Release all locks
let twoPhaseCommit (participants: string list) (coordinatorId: string) : unit =
    for participant in participants do
        releaseLock participant coordinatorId

/// Phase 2: Rollback - Release all locks (same as commit for pessimistic locking)
let twoPhaseRollback (participants: string list) (coordinatorId: string) : unit =
    twoPhaseCommit participants coordinatorId

// ============================================================================
// Telemetry
// ============================================================================

/// Record conflict event
let private recordConflict (vv: VersionVector) =
    printfn "[ConcurrencyHandler] Conflict detected, version: %A" vv

/// Record retry event
let private recordRetry (attempt: int) (delayMs: int) =
    printfn "[ConcurrencyHandler] Retry attempt %d, delay %dms" attempt delayMs

// ============================================================================
// Utility Functions
// ============================================================================

/// Convert version vector to string for logging/serialization
let versionVectorToString (vv: VersionVector) : string =
    vv
    |> Map.toList
    |> List.map (fun (k, v) -> sprintf "%s=%d" k v)
    |> String.concat ","
    |> sprintf "[%s]"

/// Parse version vector from string
let parseVersionVector (s: string) : Result<VersionVector, string> =
    try
        let trimmed = s.Trim('[', ']')
        if String.IsNullOrEmpty trimmed then
            Ok Map.empty
        else
            let pairs =
                trimmed.Split(',')
                |> Array.map (fun pair ->
                    let parts = pair.Split('=')
                    if parts.Length = 2 then
                        Ok (parts.[0].Trim(), Int64.Parse(parts.[1].Trim()))
                    else
                        Error "Invalid pair format"
                )

            let errors = pairs |> Array.choose (function Error e -> Some e | _ -> None)
            if errors.Length > 0 then
                Error (String.Join(", ", errors))
            else
                pairs
                |> Array.choose (function Ok p -> Some p | _ -> None)
                |> Map.ofArray
                |> Ok
    with ex ->
        Error ex.Message
