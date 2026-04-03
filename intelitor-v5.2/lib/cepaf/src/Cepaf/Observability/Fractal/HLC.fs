namespace Cepaf.Observability.Fractal

open System
open System.Threading

/// Hybrid Logical Clock for causal ordering without NTP synchronization.
/// Based on Zenoh protocol principles.
/// STAMP Compliance: SC-LOG-006 (L3+ logs MUST use HLC timestamps)
module HLC =

    // ============================================================
    // TYPES
    // ============================================================

    /// HLC Timestamp with physical time, logical counter, and node ID
    [<Struct>]
    type Timestamp = {
        /// Physical time in microseconds (Unix epoch)
        Physical: int64

        /// Logical counter for events at same physical time (0-65535)
        Counter: int

        /// Node identifier (machine name or UUID)
        NodeId: string
    }

    /// HLC state for a node
    type State = {
        mutable Physical: int64
        mutable Counter: int
        NodeId: string
        Lock: obj
    }

    // ============================================================
    // GLOBAL STATE
    // ============================================================

    let private state: State = {
        Physical = 0L
        Counter = 0
        NodeId = Environment.MachineName
        Lock = obj()
    }

    // ============================================================
    // CORE OPERATIONS
    // ============================================================

    /// Get current physical time in microseconds
    let private getPhysicalTime () : int64 =
        DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() * 1000L

    /// Generate a new HLC timestamp for a local event
    let now () : Timestamp =
        lock state.Lock (fun () ->
            let physical = getPhysicalTime()

            if physical > state.Physical then
                // Physical time has advanced
                state.Physical <- physical
                state.Counter <- 0
            else
                // Same or earlier physical time, increment counter
                state.Counter <- state.Counter + 1

            {
                Physical = state.Physical
                Counter = state.Counter
                NodeId = state.NodeId
            }
        )

    /// Update HLC from a received timestamp (message receive)
    let update (received: Timestamp) : Timestamp =
        lock state.Lock (fun () ->
            let physical = getPhysicalTime()

            if physical > state.Physical && physical > received.Physical then
                // Local physical time is most recent
                state.Physical <- physical
                state.Counter <- 0
            elif received.Physical > state.Physical then
                // Received physical time is most recent
                state.Physical <- received.Physical
                state.Counter <- received.Counter + 1
            elif received.Physical = state.Physical then
                // Same physical time, take max counter + 1
                state.Counter <- max state.Counter received.Counter + 1
            else
                // Local is ahead, increment counter
                state.Counter <- state.Counter + 1

            {
                Physical = state.Physical
                Counter = state.Counter
                NodeId = state.NodeId
            }
        )

    /// Merge two timestamps (for causality tracking)
    let merge (a: Timestamp) (b: Timestamp) : Timestamp =
        if a.Physical > b.Physical then
            { a with Counter = a.Counter + 1 }
        elif b.Physical > a.Physical then
            { b with Counter = b.Counter + 1 }
        else
            {
                Physical = a.Physical
                Counter = max a.Counter b.Counter + 1
                NodeId = state.NodeId
            }

    // ============================================================
    // COMPARISON
    // ============================================================

    /// Compare two HLC timestamps
    /// Returns: -1 if a < b, 0 if a = b, 1 if a > b
    let compare (a: Timestamp) (b: Timestamp) : int =
        match compare a.Physical b.Physical with
        | 0 ->
            // Same physical time, compare counters
            match compare a.Counter b.Counter with
            | 0 ->
                // Same counter, compare node IDs (tie-breaker)
                // Normalize String.Compare result to -1/0/1
                let cmp = String.Compare(a.NodeId, b.NodeId, StringComparison.Ordinal)
                if cmp < 0 then -1 elif cmp > 0 then 1 else 0
            | c -> c
        | c -> c

    /// Check if a happened before b
    let happenedBefore (a: Timestamp) (b: Timestamp) : bool =
        compare a b < 0

    /// Check if a happened after b
    let happenedAfter (a: Timestamp) (b: Timestamp) : bool =
        compare a b > 0

    /// Check if timestamps are concurrent (neither happened before the other)
    let areConcurrent (a: Timestamp) (b: Timestamp) : bool =
        // Concurrent if same physical time but different nodes
        a.Physical = b.Physical && a.NodeId <> b.NodeId

    // ============================================================
    // ARITHMETIC
    // ============================================================

    /// Add milliseconds to a timestamp
    let addMs (ts: Timestamp) (ms: int64) : Timestamp =
        { ts with Physical = ts.Physical + (ms * 1000L); Counter = 0 }

    /// Subtract two timestamps to get duration in microseconds
    let diffMicros (a: Timestamp) (b: Timestamp) : int64 =
        a.Physical - b.Physical

    /// Subtract two timestamps to get duration in milliseconds
    let diffMs (a: Timestamp) (b: Timestamp) : int64 =
        (a.Physical - b.Physical) / 1000L

    // ============================================================
    // SERIALIZATION
    // ============================================================

    /// Serialize to compact binary format (12 bytes)
    /// Format: Physical (8 bytes) + Counter (2 bytes) + NodeHash (2 bytes)
    let toBytes (ts: Timestamp) : byte[] =
        let bytes = Array.zeroCreate<byte> 12
        BitConverter.GetBytes(ts.Physical) |> Array.iteri (fun i b -> bytes.[i] <- b)
        BitConverter.GetBytes(uint16 ts.Counter) |> Array.iteri (fun i b -> bytes.[8 + i] <- b)
        let nodeHash = uint16 (abs (ts.NodeId.GetHashCode()) % 65536)
        BitConverter.GetBytes(nodeHash) |> Array.iteri (fun i b -> bytes.[10 + i] <- b)
        bytes

    /// Deserialize from compact binary format
    let fromBytes (bytes: byte[]) (nodeId: string option) : Result<Timestamp, string> =
        if bytes.Length < 12 then
            Error "Invalid HLC bytes: expected 12 bytes"
        else
            try
                let physical = BitConverter.ToInt64(bytes, 0)
                let counter = int (BitConverter.ToUInt16(bytes, 8))
                Ok {
                    Physical = physical
                    Counter = counter
                    NodeId = defaultArg nodeId "unknown"
                }
            with ex ->
                Error $"Failed to parse HLC bytes: {ex.Message}"

    /// Convert to ISO 8601 string with counter
    let toIso8601 (ts: Timestamp) : string =
        let dt = DateTimeOffset.FromUnixTimeMilliseconds(ts.Physical / 1000L)
        $"{dt:o}.{ts.Counter:D4}"

    /// Convert to human-readable string
    let toString (ts: Timestamp) : string =
        $"{ts.Physical}.{ts.Counter}@{ts.NodeId}"

    /// Parse from string representation
    let parse (s: string) : Result<Timestamp, string> =
        try
            let parts = s.Split('@')
            let timeParts = parts.[0].Split('.')

            Ok {
                Physical = Int64.Parse(timeParts.[0])
                Counter = if timeParts.Length > 1 then Int32.Parse(timeParts.[1]) else 0
                NodeId = if parts.Length > 1 then parts.[1] else state.NodeId
            }
        with ex ->
            Error $"Failed to parse HLC string '{s}': {ex.Message}"

    // ============================================================
    // DIAGNOSTICS
    // ============================================================

    /// Get current HLC state for diagnostics
    let getState () =
        {|
            Physical = state.Physical
            Counter = state.Counter
            NodeId = state.NodeId
            CurrentTime = getPhysicalTime()
            Drift = getPhysicalTime() - state.Physical
        |}

    /// Reset HLC state (for testing only)
    let reset () =
        lock state.Lock (fun () ->
            state.Physical <- 0L
            state.Counter <- 0
        )

    // ============================================================
    // VALIDATION (SC-LOG-006)
    // ============================================================

    /// Validate that a timestamp is valid for a fractal level
    let validateForLevel (level: FractalLevel) (ts: Timestamp option) : Result<unit, string> =
        match level with
        | FractalLevel.L3 | FractalLevel.L4 | FractalLevel.L5 ->
            match ts with
            | Some t when t.Physical > 0L -> Ok ()
            | Some _ -> Error "HLC timestamp has invalid physical time"
            | None -> Error $"SC-LOG-006: {FractalLevel.toString level} logs MUST have HLC timestamp"
        | _ -> Ok ()  // L1/L2 don't require HLC

    /// Check if timestamp is within acceptable drift
    let isWithinDrift (ts: Timestamp) (maxDriftMs: int64) : bool =
        let now = getPhysicalTime()
        let drift = abs (now - ts.Physical)
        drift <= (maxDriftMs * 1000L)
