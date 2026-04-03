namespace Cepaf.Observability.Fractal

open System
open System.Collections
open System.Collections.Concurrent
open System.Security.Cryptography
open System.Text

/// Write Filter using Bloom Filter for publisher-side emission control.
/// Prevents redundant log emissions for identical events.
/// STAMP Compliance: SC-LOG-008 (<1% false negative rate)
module WriteFilter =

    // ============================================================
    // TYPES
    // ============================================================

    /// Bloom filter configuration
    type BloomConfig = {
        /// Expected number of elements
        ExpectedSize: int

        /// Target false positive rate (0.01 = 1%)
        FalsePositiveRate: float

        /// Calculated optimal bit count
        BitCount: int

        /// Calculated optimal hash count
        HashCount: int
    }

    /// Bloom filter state
    type BloomFilter = {
        /// Configuration
        Config: BloomConfig

        /// Bit array for the filter
        Bits: BitArray

        /// Current element count (approximate)
        mutable Count: int

        /// Creation timestamp
        CreatedAt: DateTimeOffset

        /// Lock for thread safety
        Lock: obj
    }

    /// Write filter with time-based partitioning
    type WriteFilterState = {
        /// Current active filter
        mutable Current: BloomFilter

        /// Previous filter (for lookback)
        mutable Previous: BloomFilter option

        /// Configuration
        Config: BloomConfig

        /// Rotation interval in milliseconds
        RotationIntervalMs: int64

        /// Last rotation timestamp
        mutable LastRotation: DateTimeOffset

        /// Filter statistics
        mutable InsertCount: int64
        mutable HitCount: int64
        mutable MissCount: int64

        /// Lock for rotation
        RotationLock: obj
    }

    // ============================================================
    // BLOOM FILTER CALCULATIONS
    // ============================================================

    /// Calculate optimal bit count for desired false positive rate
    /// Formula: m = -n * ln(p) / (ln(2)^2)
    let private calculateBitCount (expectedSize: int) (fpr: float) : int =
        let n = float expectedSize
        let p = fpr
        let m = -n * log p / (log 2.0 ** 2.0)
        int (ceil m)

    /// Calculate optimal hash count
    /// Formula: k = (m/n) * ln(2)
    let private calculateHashCount (bitCount: int) (expectedSize: int) : int =
        let m = float bitCount
        let n = float expectedSize
        let k = (m / n) * log 2.0
        max 1 (int (round k))

    /// Create configuration with optimal parameters
    let createConfig (expectedSize: int) (fpr: float) : BloomConfig =
        let bitCount = calculateBitCount expectedSize fpr
        let hashCount = calculateHashCount bitCount expectedSize
        {
            ExpectedSize = expectedSize
            FalsePositiveRate = fpr
            BitCount = bitCount
            HashCount = hashCount
        }

    // ============================================================
    // HASH FUNCTIONS
    // ============================================================

    /// Generate multiple hash values using double hashing technique
    /// h_i(x) = h1(x) + i * h2(x)
    let private getHashValues (data: byte[]) (hashCount: int) (bitCount: int) : int[] =
        use sha256 = SHA256.Create()
        let hash = sha256.ComputeHash(data)

        // Extract two 64-bit hashes from SHA256
        let h1 = BitConverter.ToInt64(hash, 0)
        let h2 = BitConverter.ToInt64(hash, 8)

        Array.init hashCount (fun i ->
            let combined = h1 + (int64 i) * h2
            int (abs combined % int64 bitCount)
        )

    /// Convert string to bytes for hashing
    let private toBytes (s: string) : byte[] =
        Encoding.UTF8.GetBytes(s)

    // ============================================================
    // BLOOM FILTER OPERATIONS
    // ============================================================

    /// Create a new Bloom filter
    let createFilter (config: BloomConfig) : BloomFilter =
        {
            Config = config
            Bits = BitArray(config.BitCount, false)
            Count = 0
            CreatedAt = DateTimeOffset.UtcNow
            Lock = obj()
        }

    /// Add an element to the Bloom filter
    let add (filter: BloomFilter) (element: string) : unit =
        let bytes = toBytes element
        let indices = getHashValues bytes filter.Config.HashCount filter.Config.BitCount

        lock filter.Lock (fun () ->
            for idx in indices do
                filter.Bits.[idx] <- true
            filter.Count <- filter.Count + 1
        )

    /// Check if an element might be in the filter
    /// Returns: true = might exist (or definitely exists), false = definitely doesn't exist
    let mightContain (filter: BloomFilter) (element: string) : bool =
        let bytes = toBytes element
        let indices = getHashValues bytes filter.Config.HashCount filter.Config.BitCount

        lock filter.Lock (fun () ->
            indices |> Array.forall (fun idx -> filter.Bits.[idx])
        )

    /// Add and check in one operation (returns true if was already present)
    let addAndCheck (filter: BloomFilter) (element: string) : bool =
        let bytes = toBytes element
        let indices = getHashValues bytes filter.Config.HashCount filter.Config.BitCount

        lock filter.Lock (fun () ->
            let wasPresent = indices |> Array.forall (fun idx -> filter.Bits.[idx])

            for idx in indices do
                filter.Bits.[idx] <- true
            filter.Count <- filter.Count + 1

            wasPresent
        )

    /// Get current fill rate (approximate)
    let fillRate (filter: BloomFilter) : float =
        let setBits =
            lock filter.Lock (fun () ->
                let mutable count = 0
                for i in 0 .. filter.Config.BitCount - 1 do
                    if filter.Bits.[i] then count <- count + 1
                count
            )
        float setBits / float filter.Config.BitCount

    /// Estimate actual false positive rate based on fill
    let estimatedFpr (filter: BloomFilter) : float =
        let fill = fillRate filter
        fill ** float filter.Config.HashCount

    // ============================================================
    // WRITE FILTER STATE MANAGEMENT
    // ============================================================

    /// Global write filter state
    let mutable private globalState: WriteFilterState option = None
    let private initLock = obj()

    /// Initialize the write filter
    let initialize (expectedSize: int) (fpr: float) (rotationIntervalMs: int64) : unit =
        lock initLock (fun () ->
            let config = createConfig expectedSize fpr
            globalState <- Some {
                Current = createFilter config
                Previous = None
                Config = config
                RotationIntervalMs = rotationIntervalMs
                LastRotation = DateTimeOffset.UtcNow
                InsertCount = 0L
                HitCount = 0L
                MissCount = 0L
                RotationLock = obj()
            }
        )

    /// Get or initialize state with defaults
    let private getState () : WriteFilterState =
        match globalState with
        | Some s -> s
        | None ->
            // Default: 10000 elements, 1% FPR, 5 minute rotation
            initialize 10000 0.01 300000L
            globalState.Value

    /// Check if rotation is needed and perform it
    let private maybeRotate (state: WriteFilterState) : unit =
        let now = DateTimeOffset.UtcNow
        let elapsed = (now - state.LastRotation).TotalMilliseconds

        if elapsed >= float state.RotationIntervalMs then
            lock state.RotationLock (fun () ->
                // Double-check after acquiring lock
                let elapsed2 = (DateTimeOffset.UtcNow - state.LastRotation).TotalMilliseconds
                if elapsed2 >= float state.RotationIntervalMs then
                    // Rotate: current becomes previous, new filter becomes current
                    state.Previous <- Some state.Current
                    state.Current <- createFilter state.Config
                    state.LastRotation <- DateTimeOffset.UtcNow
            )

    // ============================================================
    // PUBLIC API
    // ============================================================

    /// Build a filter key from log entry components
    let buildKey (moduleKey: string) (eventType: string) (contentHash: string) : string =
        $"{moduleKey}|{eventType}|{contentHash}"

    /// Build a filter key with HLC timestamp for time-sensitive filtering
    let buildKeyWithTime (moduleKey: string) (eventType: string) (hlcPhysical: int64) : string =
        // Round to 50ms buckets for temporal deduplication
        // 50ms = 50000 microseconds (HLC uses microsecond precision)
        let bucket = hlcPhysical / 50000L
        $"{moduleKey}|{eventType}|{bucket}"

    /// Check if a log entry should be emitted (SC-LOG-008)
    /// Returns: true = emit (not seen before), false = suppress (duplicate)
    let shouldEmit (filterKey: string) : bool =
        let state = getState()
        maybeRotate state

        // Check current filter
        if mightContain state.Current filterKey then
            // Found in current, definitely a duplicate
            System.Threading.Interlocked.Increment(&state.HitCount) |> ignore
            false
        else
            // Check previous filter if exists
            match state.Previous with
            | Some prev when mightContain prev filterKey ->
                // Found in previous, likely a duplicate but add to current
                add state.Current filterKey
                System.Threading.Interlocked.Increment(&state.HitCount) |> ignore
                System.Threading.Interlocked.Increment(&state.InsertCount) |> ignore
                false
            | _ ->
                // Not found anywhere, emit and add to current
                add state.Current filterKey
                System.Threading.Interlocked.Increment(&state.MissCount) |> ignore
                System.Threading.Interlocked.Increment(&state.InsertCount) |> ignore
                true

    /// Check and emit in one operation, returns whether to emit
    let checkAndRecord (moduleKey: string) (eventType: string) (contentHash: string) : bool =
        let key = buildKey moduleKey eventType contentHash
        shouldEmit key

    /// Force add a key (for pre-registration)
    let preRegister (filterKey: string) : unit =
        let state = getState()
        add state.Current filterKey
        System.Threading.Interlocked.Increment(&state.InsertCount) |> ignore

    /// Clear all filters (for testing)
    let clear () : unit =
        let state = getState()
        lock state.RotationLock (fun () ->
            state.Current <- createFilter state.Config
            state.Previous <- None
            state.InsertCount <- 0L
            state.HitCount <- 0L
            state.MissCount <- 0L
            state.LastRotation <- DateTimeOffset.UtcNow
        )

    /// Reset to uninitialized state
    let reset () : unit =
        lock initLock (fun () ->
            globalState <- None
        )

    // ============================================================
    // STATISTICS & DIAGNOSTICS
    // ============================================================

    /// Get current filter statistics
    let getStats () =
        let state = getState()
        let currentFill = fillRate state.Current
        let previousFill =
            match state.Previous with
            | Some p -> Some (fillRate p)
            | None -> None

        {|
            InsertCount = state.InsertCount
            HitCount = state.HitCount
            MissCount = state.MissCount
            HitRate = if state.HitCount + state.MissCount > 0L
                      then float state.HitCount / float (state.HitCount + state.MissCount)
                      else 0.0
            CurrentFilterFill = currentFill
            PreviousFilterFill = previousFill
            CurrentEstimatedFpr = estimatedFpr state.Current
            BitCount = state.Config.BitCount
            HashCount = state.Config.HashCount
            ExpectedSize = state.Config.ExpectedSize
            TargetFpr = state.Config.FalsePositiveRate
            RotationIntervalMs = state.RotationIntervalMs
            LastRotation = state.LastRotation
            TimeSinceRotationMs = (DateTimeOffset.UtcNow - state.LastRotation).TotalMilliseconds
        |}

    /// Check if the filter is healthy (SC-LOG-008 compliance)
    let isHealthy () : bool =
        let state = getState()
        let stats = getStats()

        // Filter is healthy if:
        // 1. Fill rate is below 80%
        // 2. Estimated FPR is below 2x target
        stats.CurrentFilterFill < 0.8 &&
        stats.CurrentEstimatedFpr < (state.Config.FalsePositiveRate * 2.0)

    // ============================================================
    // CONTENT HASHING HELPERS
    // ============================================================

    /// Quick hash for content deduplication
    let hashContent (content: string) : string =
        use sha256 = SHA256.Create()
        let bytes = Encoding.UTF8.GetBytes(content)
        let hash = sha256.ComputeHash(bytes)
        Convert.ToBase64String(hash, 0, 8)  // First 8 bytes = 64 bits

    /// Hash structured data for deduplication
    let hashPayload (fields: (string * obj) list) : string =
        let sb = StringBuilder()
        for (key, value) in fields |> List.sortBy fst do
            sb.Append(key).Append(':').Append(value.ToString()).Append(';') |> ignore
        hashContent (sb.ToString())

