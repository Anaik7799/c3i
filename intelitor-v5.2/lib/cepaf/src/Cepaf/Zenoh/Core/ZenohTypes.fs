// =============================================================================
// ZenohTypes.fs - Core Zenoh Type Definitions
// =============================================================================
// STAMP: SC-NAT-001, SC-NAT-002, SC-ZENOH-001
// AOR: AOR-ZENOH-001, AOR-ZENOH-002
// Criticality: Level 1 (CRITICAL) - Foundation Types
// =============================================================================
// Provides core type definitions for Zenoh F# integration:
// - Connection state management
// - Session and publisher configuration
// - Error types with rich context
// - Health monitoring types
// =============================================================================

namespace Cepaf.Zenoh.Core

open System

/// Connection state enumeration for lifecycle tracking
[<RequireQualifiedAccess>]
type ConnectionStatus =
    | Disconnected
    | Connecting
    | Connected
    | Reconnecting
    | Failed of reason: string

    member this.IsInConnectedState =
        match this with
        | Connected -> true
        | _ -> false

    member this.IsHealthy =
        match this with
        | Connected | Connecting | Reconnecting -> true
        | Disconnected | Failed _ -> false

    override this.ToString() =
        match this with
        | Disconnected -> "disconnected"
        | Connecting -> "connecting"
        | Connected -> "connected"
        | Reconnecting -> "reconnecting"
        | Failed reason -> sprintf "failed: %s" reason

/// Session configuration for Zenoh connection
type SessionConfig = {
    /// Router endpoints (tcp/host:port format)
    Endpoints: string list
    /// Connection timeout in milliseconds (SC-OP-001: max 5000ms)
    ConnectTimeoutMs: int
    /// Enable shared memory transport for zero-copy
    EnableShm: bool
    /// Client mode: "client" | "peer" | "router"
    Mode: string
    /// Session name for identification and logging
    Name: string
    /// Maximum reconnection attempts (SC-OP-004)
    MaxReconnectAttempts: int
    /// Base delay for exponential backoff in ms
    ReconnectBaseDelayMs: int
    /// Maximum delay for exponential backoff in ms (SC-OP-002: max 60000ms)
    ReconnectMaxDelayMs: int
}

module SessionConfig =
    /// Default session configuration with SIL-6 compliant values
    let defaultConfig () = {
        Endpoints = ["tcp/localhost:7447"]
        ConnectTimeoutMs = 5000           // SC-OP-001
        EnableShm = false
        Mode = "client"
        Name = "cepaf-session"
        MaxReconnectAttempts = 10         // SC-OP-004
        ReconnectBaseDelayMs = 1000
        ReconnectMaxDelayMs = 60000       // SC-OP-002
    }

    /// Create config for specific router endpoint
    let forEndpoint (endpoint: string) =
        { defaultConfig() with Endpoints = [endpoint] }

    /// Create config for multiple endpoints (failover)
    let forEndpoints (endpoints: string list) =
        { defaultConfig() with Endpoints = endpoints }

    /// Create config with custom name
    let withName (name: string) (config: SessionConfig) =
        { config with Name = name }

    /// Enable shared memory transport
    let withShm (config: SessionConfig) =
        { config with EnableShm = true }

/// Publisher configuration
type PublisherConfig = {
    /// Key expression for publishing
    KeyExpr: string
    /// Congestion control: "block" | "drop"
    CongestionControl: string
    /// Priority (1-7, lower is higher priority)
    Priority: int
    /// Reliability: "reliable" | "best_effort"
    Reliability: string
    /// Enable express mode (reduced latency)
    Express: bool
}

module PublisherConfig =
    /// Create publisher config for a key expression
    let create (keyExpr: string) = {
        KeyExpr = keyExpr
        CongestionControl = "block"
        Priority = 5
        Reliability = "reliable"
        Express = false
    }

    /// Create high-priority publisher
    let highPriority (keyExpr: string) =
        { create keyExpr with Priority = 1 }

    /// Create express (low-latency) publisher
    let express (keyExpr: string) =
        { create keyExpr with Express = true }

    /// Create best-effort publisher (for non-critical data)
    let bestEffort (keyExpr: string) =
        { create keyExpr with Reliability = "best_effort"; CongestionControl = "drop" }

/// Subscriber configuration
type SubscriberConfig = {
    /// Key expression pattern (supports wildcards: * and **)
    KeyExpr: string
    /// Reliability requirement: "reliable" | "best_effort"
    Reliability: string
    /// Enable miss detection (zenoh-ext feature)
    MissDetection: bool
    /// Recovery mode for missed samples: "none" | "periodic" | "heartbeat"
    RecoveryMode: string
    /// Callback timeout in milliseconds (SC-MSG-003: max 50ms)
    CallbackTimeoutMs: int
}

module SubscriberConfig =
    /// Create subscriber config for a key expression
    let create (keyExpr: string) = {
        KeyExpr = keyExpr
        Reliability = "reliable"
        MissDetection = false
        RecoveryMode = "none"
        CallbackTimeoutMs = 50  // SC-MSG-003
    }

    /// Enable miss detection for critical subscriptions
    let withMissDetection (config: SubscriberConfig) =
        { config with MissDetection = true; RecoveryMode = "heartbeat" }

    /// Create subscriber for wildcard pattern
    let forPattern (pattern: string) =
        create pattern

/// Query configuration for get/reply operations
type QueryConfig = {
    /// Key expression for query
    KeyExpr: string
    /// Query timeout in milliseconds
    TimeoutMs: int
    /// Query target: "all" | "best_matching" | "all_complete"
    Target: string
    /// Consolidation mode: "none" | "monotonic" | "latest"
    Consolidation: string
}

module QueryConfig =
    let create (keyExpr: string) = {
        KeyExpr = keyExpr
        TimeoutMs = 10000
        Target = "all"
        Consolidation = "none"
    }

/// Sample received from subscription
type ZenohSample = {
    /// Key expression of the sample
    KeyExpr: string
    /// Raw payload bytes
    Payload: byte[]
    /// Sample kind: "put" | "delete"
    Kind: string
    /// Timestamp if available (hybrid logical clock)
    Timestamp: DateTimeOffset option
    /// Source info (session ID)
    SourceId: string option
    /// Encoding type
    Encoding: string option
    /// Attachment data
    Attachment: byte[] option
}

module ZenohSample =
    /// Create empty sample
    let empty = {
        KeyExpr = ""
        Payload = [||]
        Kind = "put"
        Timestamp = None
        SourceId = None
        Encoding = None
        Attachment = None
    }

    /// Get payload as UTF-8 string
    let payloadString (sample: ZenohSample) =
        System.Text.Encoding.UTF8.GetString(sample.Payload)

    /// Check if sample is a delete operation
    let isDelete (sample: ZenohSample) =
        sample.Kind = "delete"

/// Error types for Zenoh operations with rich context
[<RequireQualifiedAccess>]
type ZenohError =
    | ConnectionFailed of message: string
    | SessionClosed
    | InvalidKeyExpr of keyExpr: string * reason: string
    | PublishFailed of keyExpr: string * message: string
    | SubscribeFailed of keyExpr: string * message: string
    | QueryFailed of keyExpr: string * message: string
    | Timeout of operation: string * timeoutMs: int
    | NativeError of code: int * message: string
    | Disposed of resource: string
    | SerializationError of typeName: string * message: string
    | DeserializationError of typeName: string * message: string
    | ConfigurationError of message: string
    | QuorumFailed of required: int * received: int
    | BarrierTimeout of barrierId: string * waitedMs: int
    | SplitBrainDetected of visibleNodes: int * totalNodes: int
    | WitnessUnreachable of endpoint: string * attempts: int
    | ArbitrationFailed of reason: string
    | OperationsFrozen of reason: string

    /// Get error message
    member this.Message =
        match this with
        | ConnectionFailed msg -> sprintf "Connection failed: %s" msg
        | SessionClosed -> "Session is closed"
        | InvalidKeyExpr (ke, reason) -> sprintf "Invalid key expression '%s': %s" ke reason
        | PublishFailed (ke, msg) -> sprintf "Publish to '%s' failed: %s" ke msg
        | SubscribeFailed (ke, msg) -> sprintf "Subscribe to '%s' failed: %s" ke msg
        | QueryFailed (ke, msg) -> sprintf "Query '%s' failed: %s" ke msg
        | Timeout (op, ms) -> sprintf "Operation '%s' timed out after %dms" op ms
        | NativeError (code, msg) -> sprintf "Native error %d: %s" code msg
        | Disposed resource -> sprintf "Resource '%s' has been disposed" resource
        | SerializationError (t, msg) -> sprintf "Failed to serialize %s: %s" t msg
        | DeserializationError (t, msg) -> sprintf "Failed to deserialize %s: %s" t msg
        | ConfigurationError msg -> sprintf "Configuration error: %s" msg
        | QuorumFailed (req, recv) -> sprintf "Quorum failed: required %d, received %d" req recv
        | BarrierTimeout (id, ms) -> sprintf "Barrier '%s' timed out after %dms" id ms
        | SplitBrainDetected (visible, total) -> sprintf "Split-brain detected: visible %d of %d nodes" visible total
        | WitnessUnreachable (endpoint, attempts) -> sprintf "Witness '%s' unreachable after %d attempts" endpoint attempts
        | ArbitrationFailed reason -> sprintf "Arbitration failed: %s" reason
        | OperationsFrozen reason -> sprintf "Operations frozen: %s" reason

    override this.ToString() = this.Message

/// Result type alias for Zenoh operations
type ZenohResult<'T> = Result<'T, ZenohError>

/// Health status for monitoring (SC-OP-003)
type ZenohHealth = {
    /// Current connection status
    Status: ConnectionStatus
    /// Session identifier (if connected)
    SessionId: string option
    /// When connection was established
    ConnectedAt: DateTimeOffset option
    /// Last successful heartbeat
    LastHeartbeat: DateTimeOffset option
    /// Active subscriber count
    SubscriberCount: int
    /// Active publisher count
    PublisherCount: int
    /// Total messages published
    MessagesPublished: int64
    /// Total messages received
    MessagesReceived: int64
    /// Number of reconnection attempts
    ReconnectCount: int
    /// Total error count
    ErrorCount: int
    /// Average publish latency in milliseconds
    AveragePublishLatencyMs: float
    /// Average receive processing time in milliseconds
    AverageReceiveLatencyMs: float
    /// Uptime since last connection
    Uptime: TimeSpan option
}

module ZenohHealth =
    /// Empty/initial health state
    let empty = {
        Status = ConnectionStatus.Disconnected
        SessionId = None
        ConnectedAt = None
        LastHeartbeat = None
        SubscriberCount = 0
        PublisherCount = 0
        MessagesPublished = 0L
        MessagesReceived = 0L
        ReconnectCount = 0
        ErrorCount = 0
        AveragePublishLatencyMs = 0.0
        AverageReceiveLatencyMs = 0.0
        Uptime = None
    }

    /// Check if healthy
    let isHealthy (health: ZenohHealth) =
        health.Status.IsConnected

    /// Update uptime
    let updateUptime (health: ZenohHealth) =
        match health.ConnectedAt with
        | Some connectedAt ->
            { health with Uptime = Some (DateTimeOffset.UtcNow - connectedAt) }
        | None -> health

    /// Record heartbeat
    let recordHeartbeat (health: ZenohHealth) =
        { health with LastHeartbeat = Some DateTimeOffset.UtcNow }

    /// Increment publish count
    let recordPublish (health: ZenohHealth) =
        { health with MessagesPublished = health.MessagesPublished + 1L }

    /// Increment receive count
    let recordReceive (health: ZenohHealth) =
        { health with MessagesReceived = health.MessagesReceived + 1L }

    /// Increment error count
    let recordError (health: ZenohHealth) =
        { health with ErrorCount = health.ErrorCount + 1 }

/// Lifecycle events for observability
[<RequireQualifiedAccess>]
type LifecycleEvent =
    | Initializing of config: SessionConfig
    | Connected of sessionId: string
    | Disconnected of reason: string
    | Reconnecting of attempt: int * maxAttempts: int
    | ReconnectFailed of attempts: int * lastError: string
    | HealthCheck of health: ZenohHealth
    | Shutdown of graceful: bool

    override this.ToString() =
        match this with
        | Initializing _ -> "Initializing"
        | Connected sid -> sprintf "Connected (session: %s)" sid
        | Disconnected reason -> sprintf "Disconnected: %s" reason
        | Reconnecting (attempt, max) -> sprintf "Reconnecting (%d/%d)" attempt max
        | ReconnectFailed (attempts, err) -> sprintf "Reconnect failed after %d attempts: %s" attempts err
        | HealthCheck _ -> "Health check"
        | Shutdown graceful -> sprintf "Shutdown (graceful: %b)" graceful
