/// CEPAF Units of Measure Module
/// Provides compile-time type safety for physical quantities.
///
/// WHAT: F# units of measure for time, data, and network quantities
/// WHY: Prevents unit confusion bugs at compile time (e.g., mixing ms with seconds)
/// CONSTRAINTS: SC-FSH-004 (Units of Measure for Physical Quantities)
///
/// STAMP Compliance: SC-FSH-004, SC-FSH-005
/// Version: 1.0.0
[<AutoOpen>]
module Cepaf.Core.Units

open System

// ============================================================================
// TIME UNITS
// ============================================================================

/// Milliseconds
[<Measure>] type ms

/// Seconds
[<Measure>] type sec

/// Minutes (named 'minute' to avoid conflict with F# built-in min function)
[<Measure>] type minute

/// Hours
[<Measure>] type hr

// ============================================================================
// DATA SIZE UNITS
// ============================================================================

/// Bytes
[<Measure>] type bytes

/// Kilobytes
[<Measure>] type KB

/// Megabytes
[<Measure>] type MB

/// Gigabytes
[<Measure>] type GB

// ============================================================================
// NETWORK UNITS
// ============================================================================

/// Port number
[<Measure>] type port

/// Requests per second
[<Measure>] type rps

/// Messages per second
[<Measure>] type mps

// ============================================================================
// PERCENTAGE/RATIO UNITS
// ============================================================================

/// Percentage (0-100)
[<Measure>] type percent

/// Ratio (0.0-1.0)
[<Measure>] type ratio

// ============================================================================
// TIME CONVERSIONS
// ============================================================================

/// Time conversion utilities
[<RequireQualifiedAccess>]
module Time =

    /// Convert milliseconds to seconds
    let msToSec (x: float<ms>) : float<sec> = x / 1000.0<ms/sec>

    /// Convert seconds to milliseconds
    let secToMs (x: float<sec>) : float<ms> = x * 1000.0<ms/sec>

    /// Convert minutes to seconds
    let minToSec (x: float<minute>) : float<sec> = x * 60.0<sec/minute>

    /// Convert seconds to minutes
    let secToMin (x: float<sec>) : float<minute> = x / 60.0<sec/minute>

    /// Convert hours to minutes
    let hrToMin (x: float<hr>) : float<minute> = x * 60.0<minute/hr>

    /// Convert minutes to hours
    let minToHr (x: float<minute>) : float<hr> = x / 60.0<minute/hr>

    /// Convert milliseconds to TimeSpan
    let msToTimeSpan (x: float<ms>) : TimeSpan =
        TimeSpan.FromMilliseconds(float x)

    /// Convert seconds to TimeSpan
    let secToTimeSpan (x: float<sec>) : TimeSpan =
        TimeSpan.FromSeconds(float x)

    /// Convert TimeSpan to milliseconds
    let timeSpanToMs (ts: TimeSpan) : float<ms> =
        ts.TotalMilliseconds * 1.0<ms>

    /// Convert TimeSpan to seconds
    let timeSpanToSec (ts: TimeSpan) : float<sec> =
        ts.TotalSeconds * 1.0<sec>

// ============================================================================
// DATA SIZE CONVERSIONS
// ============================================================================

/// Data size conversion utilities
[<RequireQualifiedAccess>]
module DataSize =

    /// Convert bytes to kilobytes
    let bytesToKB (x: float<bytes>) : float<KB> = x / 1024.0<bytes/KB>

    /// Convert kilobytes to bytes
    let kbToBytes (x: float<KB>) : float<bytes> = x * 1024.0<bytes/KB>

    /// Convert kilobytes to megabytes
    let kbToMB (x: float<KB>) : float<MB> = x / 1024.0<KB/MB>

    /// Convert megabytes to kilobytes
    let mbToKB (x: float<MB>) : float<KB> = x * 1024.0<KB/MB>

    /// Convert megabytes to gigabytes
    let mbToGB (x: float<MB>) : float<GB> = x / 1024.0<MB/GB>

    /// Convert gigabytes to megabytes
    let gbToMB (x: float<GB>) : float<MB> = x * 1024.0<MB/GB>

    /// Convert bytes directly to megabytes
    let bytesToMB (x: float<bytes>) : float<MB> = x |> bytesToKB |> kbToMB

    /// Convert bytes directly to gigabytes
    let bytesToGB (x: float<bytes>) : float<GB> = x |> bytesToKB |> kbToMB |> mbToGB

    /// Format data size for display
    let format (bytes: float<bytes>) : string =
        let absBytes = abs (float bytes)
        if absBytes >= 1024.0 * 1024.0 * 1024.0 then
            sprintf "%.2f GB" (float (bytesToGB bytes))
        elif absBytes >= 1024.0 * 1024.0 then
            sprintf "%.2f MB" (float (bytesToMB bytes))
        elif absBytes >= 1024.0 then
            sprintf "%.2f KB" (float (bytesToKB bytes))
        else
            sprintf "%.0f B" (float bytes)

// ============================================================================
// PERCENTAGE CONVERSIONS
// ============================================================================

/// Percentage/ratio utilities
[<RequireQualifiedAccess>]
module Percentage =

    /// Convert ratio (0.0-1.0) to percentage (0-100)
    let ratioToPercent (x: float<ratio>) : float<percent> =
        x * 100.0<percent/ratio>

    /// Convert percentage (0-100) to ratio (0.0-1.0)
    let percentToRatio (x: float<percent>) : float<ratio> =
        x / 100.0<percent/ratio>

    /// Clamp percentage to valid range
    let clamp (x: float<percent>) : float<percent> =
        max 0.0<percent> (min 100.0<percent> x)

    /// Format percentage for display
    let format (x: float<percent>) : string =
        sprintf "%.1f%%" (float x)

// ============================================================================
// SAFE WRAPPER TYPES
// ============================================================================

/// Type-safe timeout with units
type Timeout = private Timeout of float<ms>

/// Timeout operations
[<RequireQualifiedAccess>]
module Timeout =

    /// Create timeout from milliseconds
    let fromMs (ms: float<ms>) : Timeout = Timeout ms

    /// Create timeout from seconds
    let fromSec (s: float<sec>) : Timeout = Timeout (Time.secToMs s)

    /// Create timeout from minutes
    let fromMin (m: float<minute>) : Timeout = Timeout (Time.secToMs (Time.minToSec m))

    /// Create timeout from raw milliseconds (for interop)
    let fromRawMs (ms: int) : Timeout = Timeout (float ms * 1.0<ms>)

    /// Create timeout from raw seconds (for interop)
    let fromRawSec (s: float) : Timeout = Timeout (s * 1000.0<ms>)

    /// Get timeout value in milliseconds
    let toMs (Timeout ms) : float<ms> = ms

    /// Get timeout value in seconds
    let toSec (Timeout ms) : float<sec> = Time.msToSec ms

    /// Convert to TimeSpan
    let toTimeSpan (Timeout ms) : TimeSpan = Time.msToTimeSpan ms

    /// Convert to raw int milliseconds (for interop)
    let toRawMs (Timeout ms) : int = int (float ms)

    /// Default timeouts
    let fast = fromRawMs 1000
    let normal = fromRawMs 5000
    let slow = fromRawMs 30000
    let veryLong = fromRawMs 120000

    /// Check if timeout has expired since start time
    let hasExpired (startTime: DateTimeOffset) (Timeout ms) : bool =
        let elapsed = DateTimeOffset.UtcNow - startTime
        elapsed.TotalMilliseconds >= float ms


/// Type-safe port number
type Port = private Port of int<port>

/// Port operations
[<RequireQualifiedAccess>]
module Port =

    /// Valid port range
    let private minPort = 1
    let private maxPort = 65535

    /// Create port with validation
    let create (p: int) : Port option =
        if p >= minPort && p <= maxPort then
            Some (Port (p * 1<port>))
        else
            None

    /// Create port without validation (use with caution)
    let createUnsafe (p: int) : Port = Port (p * 1<port>)

    /// Get port value
    let value (Port p) : int = int p

    /// Well-known ports
    let http = createUnsafe 80
    let https = createUnsafe 443
    let ssh = createUnsafe 22
    let postgres = createUnsafe 5432
    let redis = createUnsafe 6379
    let phoenix = createUnsafe 4000
    let podman = createUnsafe 8000
    let zenoh = createUnsafe 7447

    /// Check if port is privileged (< 1024)
    let isPrivileged (Port p) : bool = int p < 1024

    /// Check if port is in ephemeral range (49152-65535)
    let isEphemeral (Port p) : bool =
        let portVal = int p
        portVal >= 49152 && portVal <= 65535


/// Type-safe memory size
type MemorySize = private MemorySize of float<bytes>

/// Memory size operations
[<RequireQualifiedAccess>]
module MemorySize =

    /// Create from bytes
    let fromBytes (b: float<bytes>) : MemorySize = MemorySize b

    /// Create from kilobytes
    let fromKB (kb: float<KB>) : MemorySize = MemorySize (DataSize.kbToBytes kb)

    /// Create from megabytes
    let fromMB (mb: float<MB>) : MemorySize = MemorySize (DataSize.kbToBytes (DataSize.mbToKB mb))

    /// Create from gigabytes
    let fromGB (gb: float<GB>) : MemorySize = MemorySize (DataSize.kbToBytes (DataSize.mbToKB (DataSize.gbToMB gb)))

    /// Create from raw int64 bytes (for interop)
    let fromRawBytes (b: int64) : MemorySize = MemorySize (float b * 1.0<bytes>)

    /// Get value in bytes
    let toBytes (MemorySize b) : float<bytes> = b

    /// Get value in kilobytes
    let toKB (MemorySize b) : float<KB> = DataSize.bytesToKB b

    /// Get value in megabytes
    let toMB (MemorySize b) : float<MB> = DataSize.bytesToMB b

    /// Get value in gigabytes
    let toGB (MemorySize b) : float<GB> = DataSize.bytesToGB b

    /// Get raw int64 bytes (for interop)
    let toRawBytes (MemorySize b) : int64 = int64 (float b)

    /// Format for display
    let format (MemorySize b) : string = DataSize.format b


// ============================================================================
// RATE/THROUGHPUT TYPES
// ============================================================================

/// Type-safe rate measurement
type Rate<[<Measure>] 'u> = Rate of float<'u>

/// Rate operations
[<RequireQualifiedAccess>]
module Rate =

    /// Create rate
    let create<[<Measure>] 'u> (value: float<'u>) : Rate<'u> = Rate value

    /// Get rate value
    let value<[<Measure>] 'u> (Rate v: Rate<'u>) : float<'u> = v

    /// Check if rate exceeds threshold
    let exceeds<[<Measure>] 'u> (threshold: float<'u>) (Rate v: Rate<'u>) : bool =
        v > threshold


// ============================================================================
// DURATION HELPERS
// ============================================================================

/// Create durations with units for readable code
[<RequireQualifiedAccess>]
module Duration =

    /// Milliseconds literal
    let ms (value: float) : float<ms> = value * 1.0<ms>

    /// Seconds literal
    let sec (value: float) : float<sec> = value * 1.0<sec>

    /// Minutes literal
    let mins (value: float) : float<minute> = value * 1.0<minute>

    /// Hours literal
    let hr (value: float) : float<hr> = value * 1.0<hr>


// ============================================================================
// SIZE HELPERS
// ============================================================================

/// Create sizes with units for readable code
[<RequireQualifiedAccess>]
module Size =

    /// Bytes literal
    let bytes (value: float) : float<bytes> = value * 1.0<bytes>

    /// Kilobytes literal
    let kb (value: float) : float<KB> = value * 1.0<KB>

    /// Megabytes literal
    let mb (value: float) : float<MB> = value * 1.0<MB>

    /// Gigabytes literal
    let gb (value: float) : float<GB> = value * 1.0<GB>
