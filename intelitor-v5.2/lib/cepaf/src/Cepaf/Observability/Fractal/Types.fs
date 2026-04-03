namespace Cepaf.Observability.Fractal

open System

/// Fractal Logging System Types
/// Based on Zenoh-Unified Architecture (v5.10.0)
/// STAMP Compliance: SC-LOG-001 to SC-LOG-010

/// The 5 Fractal Levels representing different scales of observation.
/// Each level provides a different "zoom" into system behavior.
[<RequireQualifiedAccess>]
type FractalLevel =
    /// L1: Atomic (Quantum State)
    /// Function args, return values, hex dumps, stack traces.
    /// Use for: Root Cause Analysis of specific bugs.
    | L1

    /// L2: Component (Molecular Interactions)
    /// GenServer state, messages, ETS lookups.
    /// Use for: Debugging race conditions, state corruption.
    | L2

    /// L3: Transactional (Structural Flows)
    /// Business flows, Trace IDs, Baggage.
    /// Use for: Tracing user journeys ("Checkout").
    | L3

    /// L4: Systemic (Infrastructure/Physics)
    /// Node health, network partitions, CPU/Mem.
    /// Use for: Capacity planning, incident response.
    | L4

    /// L5: Cognitive (Teleological Intent)
    /// Intent, hypotheses, confidence scores.
    /// Use for: AI alignment, decision auditing.
    | L5

module FractalLevel =
    /// Convert level to integer for comparison
    let toInt = function
        | FractalLevel.L1 -> 1
        | FractalLevel.L2 -> 2
        | FractalLevel.L3 -> 3
        | FractalLevel.L4 -> 4
        | FractalLevel.L5 -> 5

    /// Parse from string
    let parse (s: string) =
        match s.ToUpperInvariant() with
        | "L1" -> Some FractalLevel.L1
        | "L2" -> Some FractalLevel.L2
        | "L3" -> Some FractalLevel.L3
        | "L4" -> Some FractalLevel.L4
        | "L5" -> Some FractalLevel.L5
        | _ -> None

    /// Convert to string
    let toString = function
        | FractalLevel.L1 -> "L1"
        | FractalLevel.L2 -> "L2"
        | FractalLevel.L3 -> "L3"
        | FractalLevel.L4 -> "L4"
        | FractalLevel.L5 -> "L5"

    /// Get level description
    let description = function
        | FractalLevel.L1 -> "Atomic (Quantum State)"
        | FractalLevel.L2 -> "Component (Molecular)"
        | FractalLevel.L3 -> "Transactional (Structural)"
        | FractalLevel.L4 -> "Systemic (Infrastructure)"
        | FractalLevel.L5 -> "Cognitive (Teleological)"

    /// Convert integer to fractal level
    let fromInt = function
        | 1 -> FractalLevel.L1
        | 2 -> FractalLevel.L2
        | 3 -> FractalLevel.L3
        | 4 -> FractalLevel.L4
        | _ -> FractalLevel.L5

/// Priority levels for log routing and retention.
/// SC-LOG: P0=L4/L5 (never drop), P1=L3 (10%), P2=L2, P3=L1
[<RequireQualifiedAccess>]
type Priority =
    /// P0: Critical - Never drop (L4/L5 logs)
    | P0
    /// P1: High - 10% sampling (L3 logs)
    | P1
    /// P2: Medium - Conditional (L2 logs)
    | P2
    /// P3: Low - Debug only (L1 logs)
    | P3

module Priority =
    /// Get default priority for a fractal level
    let fromLevel = function
        | FractalLevel.L5 -> Priority.P0
        | FractalLevel.L4 -> Priority.P0
        | FractalLevel.L3 -> Priority.P1
        | FractalLevel.L2 -> Priority.P2
        | FractalLevel.L1 -> Priority.P3

    /// Get sampling rate for priority
    let samplingRate = function
        | Priority.P0 -> 1.0    // Never drop
        | Priority.P1 -> 0.10   // 10% sampling
        | Priority.P2 -> 0.01   // 1% sampling
        | Priority.P3 -> 0.0    // Disabled unless boosted
                                    // NOTE: Ψ₂ (evolutionary continuity) exception — P3/L1 atomic
                                    // traces are intentionally dropped at 0.0 sampling to prevent
                                    // information-theoretic overflow. The complete history mandate
                                    // is satisfied at L2+ (P2=1%, P1=10%, P0=100%). L1 quantum-state
                                    // detail is available on-demand via Lens boost, not continuous.

    /// Convert priority to integer
    let toInt = function
        | Priority.P0 -> 0
        | Priority.P1 -> 1
        | Priority.P2 -> 2
        | Priority.P3 -> 3

    /// Convert integer to priority
    let fromInt = function
        | 0 -> Priority.P0
        | 1 -> Priority.P1
        | 2 -> Priority.P2
        | _ -> Priority.P3

/// The Lens is the core control structure for the "Directed Telescope".
/// Lens = <Target, Depth, Filter, Duration>
type Lens = {
    /// Target: Zenoh-style key expression with wildcards (*, **, $*)
    /// Examples: "Indrajaal/**/create", "**/error", "Indrajaal/Accounts/**"
    Target: string

    /// Depth: The fractal level to zoom to
    Depth: FractalLevel

    /// Filter: Context-based masking (user_id, tenant_id, trace_flag)
    Filter: Map<string, string>

    /// TtlMs: Time-to-live in milliseconds (SC-LOG-005: mandatory)
    TtlMs: int64
}

module Lens =
    /// Create a default lens targeting everything at L4
    let defaultLens = {
        Target = "**"
        Depth = FractalLevel.L4
        Filter = Map.empty
        TtlMs = 300_000L  // 5 minutes default
    }

    /// Create a focused lens for a specific target
    let focus target depth ttlMs = {
        Target = target
        Depth = depth
        Filter = Map.empty
        TtlMs = ttlMs
    }

    /// Add a filter to the lens
    let withFilter key value lens =
        { lens with Filter = lens.Filter |> Map.add key value }

/// A Boost is a temporary lens activation with TTL enforcement.
/// SC-LOG-005: Boosts require TTL (default 5min)
type Boost = {
    /// Unique identifier for this boost
    Id: string

    /// Zenoh key expression pattern
    KeyExpr: string

    /// Compiled regex pattern for matching (cached)
    CompiledPattern: System.Text.RegularExpressions.Regex option

    /// Target fractal depth
    Depth: FractalLevel

    /// Context filter (user_id, tenant_id, etc.)
    Filter: Map<string, string>

    /// When this boost was created
    CreatedAt: DateTimeOffset

    /// When this boost expires (SC-LOG-005)
    ExpiresAt: DateTimeOffset

    /// Who/what created this boost
    CreatedBy: string
}

module Boost =
    /// Create a new boost with default TTL
    let create keyExpr depth createdBy =
        let now = DateTimeOffset.UtcNow
        {
            Id = Guid.NewGuid().ToString("N").[..7]
            KeyExpr = keyExpr
            CompiledPattern = None
            Depth = depth
            Filter = Map.empty
            CreatedAt = now
            ExpiresAt = now.AddMinutes(5.0)  // Default 5min TTL
            CreatedBy = createdBy
        }

    /// Create a boost with custom TTL
    let createWithTtl keyExpr depth ttlMs createdBy =
        let now = DateTimeOffset.UtcNow
        {
            Id = Guid.NewGuid().ToString("N").[..7]
            KeyExpr = keyExpr
            CompiledPattern = None
            Depth = depth
            Filter = Map.empty
            CreatedAt = now
            ExpiresAt = now.AddMilliseconds(float ttlMs)
            CreatedBy = createdBy
        }

    /// Check if boost is expired
    let isExpired (boost: Boost) =
        DateTimeOffset.UtcNow > boost.ExpiresAt

    /// Add filter to boost
    let withFilter key value (boost: Boost) : Boost =
        { boost with Filter = boost.Filter |> Map.add key value }

/// Hybrid Logical Clock timestamp for causal ordering.
/// SC-LOG-006: L3+ logs MUST use HLC timestamps.
type HLCTimestamp = {
    /// Physical time in microseconds (Unix epoch)
    Physical: int64

    /// Logical counter (0-65535)
    Counter: int

    /// Node identifier (48-bit UUID)
    NodeId: string
}

module HLCTimestamp =
    /// Compare two HLC timestamps
    let compare (a: HLCTimestamp) (b: HLCTimestamp) : int =
        match compare a.Physical b.Physical with
        | 0 -> compare a.Counter b.Counter
        | r -> r

    /// Create HLC from physical time only
    let fromPhysical physical =
        { Physical = physical; Counter = 0; NodeId = "" }

/// Zenoh Wire Protocol flags for message encoding.
type WireFlags = {
    /// Encoding: 0=raw, 1=etf, 2=json, 3=msgpack, 4=protobuf
    Encoding: byte

    /// Priority (P0-P3)
    Priority: Priority

    /// Has 16-byte TraceID
    HasTraceId: bool

    /// Has 8-byte SpanID
    HasSpanId: bool

    /// Has baggage map
    HasBaggage: bool

    /// Part of batch message
    IsBatched: bool

    /// Requires delivery confirmation
    RequiresAck: bool

    /// Payload is zstd compressed
    IsCompressed: bool

    /// Has 12-byte HLC timestamp
    HasHLC: bool

    /// Sequence number for ordering
    SequenceNumber: uint16
}

/// Log entry with full Zenoh-unified addressing.
type FractalLogEntry = {
    /// Full key expression path
    Key: string

    /// Compressed 16-bit alias (for wire optimization)
    KeyAlias: uint16 option

    /// HLC timestamp for causal ordering
    HLC: HLCTimestamp

    /// Fractal level (L1-L5)
    FractalLevel: FractalLevel

    /// Priority (P0-P3)
    Priority: Priority

    /// Event type
    EventType: EventType

    /// OpenTelemetry TraceID (16 bytes)
    TraceId: string option

    /// OpenTelemetry SpanID (8 bytes)
    SpanId: string option

    /// Parent SpanID for hierarchical tracing
    ParentSpanId: string option

    /// Level-dependent payload
    Payload: FractalPayload

    /// Propagated context (baggage)
    Baggage: Map<string, string>

    /// Additional tags for categorization
    Tags: string list

    /// Wall clock timestamp
    Timestamp: DateTimeOffset

    /// Duration for span-like entries
    Duration: TimeSpan option

    /// Origin node
    Node: string

    /// Source module
    Module: string

    /// Source function
    Function: string

    /// Function arity
    Arity: int
}

/// Event types for fractal log entries
and EventType =
    | Entry     // Function entry
    | Exit      // Function exit
    | Exception // Exception thrown
    | State     // State change (L2)
    | Metric    // Metric emission (L4)
    | Intent    // Cognitive intent (L5)

/// Event type helper functions
and EventType with
    static member toInt = function
        | Entry -> 0
        | Exit -> 1
        | Exception -> 2
        | State -> 3
        | Metric -> 4
        | Intent -> 5

    static member fromInt = function
        | 0 -> Entry
        | 1 -> Exit
        | 2 -> Exception
        | 3 -> State
        | 4 -> Metric
        | _ -> Intent

/// Level-dependent payload variants for semantic meaning
and SemanticPayload =
    /// L1: Function arguments and return values
    | AtomicPayload of args: obj list * result: obj option

    /// L2: State transitions
    | ComponentPayload of stateBefore: Map<string, obj> * stateAfter: Map<string, obj>

    /// L3: Business events
    | TransactionalPayload of businessEvent: string * details: Map<string, obj>

    /// L4: System metrics
    | SystemicPayload of metric: string * value: float * unit: string

    /// L5: Cognitive intent
    | CognitivePayload of intent: string * confidence: float * reasoning: string

/// Wire-friendly payload variants for encoding/transmission
and FractalPayload =
    /// Empty payload
    | Empty
    /// Plain text
    | Text of string
    /// JSON string
    | Json of string
    /// Raw binary
    | Binary of byte[]
    /// Structured key-value pairs
    | Structured of (string * obj) list

/// Safety constraints validation results
type SafetyConstraintResult = {
    ConstraintId: string
    Description: string
    Passed: bool
    Details: string
}

module SafetyConstraints =
    /// SC-LOG-001: Async dispatch (never block)
    let scLog001 = "SC-LOG-001"

    /// SC-LOG-002: Auto-throttle at CPU > 90%
    let scLog002 = "SC-LOG-002"

    /// SC-LOG-003: PII masking at decorator
    let scLog003 = "SC-LOG-003"

    /// SC-LOG-004: L1/L2 must link to L3 TraceID
    let scLog004 = "SC-LOG-004"

    /// SC-LOG-005: Boosts require TTL (default 5min)
    let scLog005 = "SC-LOG-005"

    /// SC-LOG-006: L3+ logs MUST use HLC timestamps
    let scLog006 = "SC-LOG-006"

    /// SC-LOG-007: Batch flush MUST occur within 10ms
    let scLog007 = "SC-LOG-007"

    /// SC-LOG-008: Write filter <1% false negative rate
    let scLog008 = "SC-LOG-008"

    /// SC-LOG-009: Key aliases pre-registered at startup
    let scLog009 = "SC-LOG-009"

    /// SC-LOG-010: Admin space operations authenticated
    let scLog010 = "SC-LOG-010"

    /// Validate SC-LOG-005: Boost has TTL
    let validateBoostTtl (boost: Boost) : SafetyConstraintResult =
        let passed = boost.ExpiresAt > boost.CreatedAt
        {
            ConstraintId = scLog005
            Description = "Boosts require TTL (default 5min)"
            Passed = passed
            Details =
                if passed then
                    sprintf "TTL: %d ms" (int64 (boost.ExpiresAt - boost.CreatedAt).TotalMilliseconds)
                else
                    "Boost has no TTL or ExpiresAt <= CreatedAt"
        }

    /// Validate SC-LOG-006: HLC timestamp present for L3+
    let validateHLCPresent (entry: FractalLogEntry) : SafetyConstraintResult =
        let requiresHLC =
            match entry.FractalLevel with
            | FractalLevel.L3 | FractalLevel.L4 | FractalLevel.L5 -> true
            | _ -> false

        let hasHLC = entry.HLC.Physical > 0L

        let passed = not requiresHLC || hasHLC
        {
            ConstraintId = scLog006
            Description = "L3+ logs MUST use HLC timestamps"
            Passed = passed
            Details =
                if passed then
                    sprintf "HLC: %d.%d" entry.HLC.Physical entry.HLC.Counter
                else
                    sprintf "L%s log missing HLC timestamp" (FractalLevel.toString entry.FractalLevel)
        }
