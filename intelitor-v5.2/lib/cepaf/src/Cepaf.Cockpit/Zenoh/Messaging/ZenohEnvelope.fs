// =============================================================================
// ZenohEnvelope.fs - Typed Message Envelopes
// =============================================================================
// STAMP: SC-MSG-002, SC-MSG-006, SC-TRACE-001
// AOR: AOR-ZENOH-005
// Criticality: Level 3 (HIGH) - Message Integrity
// =============================================================================
// Provides typed message envelopes with:
// - Distributed tracing integration (W3C Trace Context)
// - Schema versioning for message evolution
// - TTL-based expiry handling
// - Correlation IDs for request/response patterns
// =============================================================================

namespace Cepaf.Zenoh.Messaging

open System
open System.Diagnostics
open Cepaf.Zenoh.Core

/// Envelope metadata for tracing and routing
type EnvelopeMetadata = {
    /// Unique message identifier
    MessageId: Guid
    /// Correlation ID for request/response patterns
    CorrelationId: Guid option
    /// ISO 8601 timestamp (UTC)
    Timestamp: DateTimeOffset
    /// Source holon/node identifier
    Source: string
    /// Target holon/node (None = broadcast)
    Target: string option
    /// Schema version for compatibility checking
    SchemaVersion: string
    /// W3C Trace ID for distributed tracing
    TraceId: string option
    /// W3C Span ID
    SpanId: string option
    /// Parent Span ID
    ParentSpanId: string option
    /// Message type name (for deserialization)
    MessageType: string
    /// Time-to-live in seconds (0 = infinite)
    TtlSeconds: int
    /// Custom headers for extensibility
    Headers: Map<string, string>
}

module EnvelopeMetadata =
    /// Create empty metadata
    let empty = {
        MessageId = Guid.Empty
        CorrelationId = None
        Timestamp = DateTimeOffset.MinValue
        Source = ""
        Target = None
        SchemaVersion = SchemaVersion.CurrentVersion
        TraceId = None
        SpanId = None
        ParentSpanId = None
        MessageType = ""
        TtlSeconds = 300
        Headers = Map.empty
    }

    /// Create metadata with automatic trace context
    let create (source: string) (messageType: string) =
        let activity = Activity.Current
        {
            MessageId = Guid.NewGuid()
            CorrelationId = None
            Timestamp = DateTimeOffset.UtcNow
            Source = source
            Target = None
            SchemaVersion = SchemaVersion.CurrentVersion
            TraceId = activity |> Option.ofObj |> Option.map (fun a -> a.TraceId.ToString())
            SpanId = activity |> Option.ofObj |> Option.map (fun a -> a.SpanId.ToString())
            ParentSpanId = activity |> Option.ofObj |> Option.bind (fun a ->
                if a.ParentSpanId = ActivitySpanId.CreateRandom() then None
                else Some (a.ParentSpanId.ToString()))
            MessageType = messageType
            TtlSeconds = 300  // 5 minute default
            Headers = Map.empty
        }

/// Typed envelope wrapping any payload (SC-MSG-002)
type ZenohEnvelope<'T> = {
    /// Envelope metadata
    Meta: EnvelopeMetadata
    /// Typed payload
    Payload: 'T
}

module ZenohEnvelope =

    /// Create a new envelope with automatic metadata
    let create<'T> (source: string) (payload: 'T) : ZenohEnvelope<'T> =
        {
            Meta = EnvelopeMetadata.create source typeof<'T>.Name
            Payload = payload
        }

    /// Create envelope with correlation ID (for request/response)
    let createCorrelated<'T> (source: string) (correlationId: Guid) (payload: 'T) : ZenohEnvelope<'T> =
        let meta = EnvelopeMetadata.create source typeof<'T>.Name
        { Meta = { meta with CorrelationId = Some correlationId }; Payload = payload }

    /// Create envelope targeting specific node
    let createTargeted<'T> (source: string) (target: string) (payload: 'T) : ZenohEnvelope<'T> =
        let meta = EnvelopeMetadata.create source typeof<'T>.Name
        { Meta = { meta with Target = Some target }; Payload = payload }

    /// Create envelope with custom TTL
    let createWithTtl<'T> (source: string) (ttlSeconds: int) (payload: 'T) : ZenohEnvelope<'T> =
        let meta = EnvelopeMetadata.create source typeof<'T>.Name
        { Meta = { meta with TtlSeconds = ttlSeconds }; Payload = payload }

    /// Create broadcast envelope (no specific target)
    let createBroadcast<'T> (source: string) (payload: 'T) : ZenohEnvelope<'T> =
        create source payload

    /// Serialize envelope to bytes
    let serialize<'T> (envelope: ZenohEnvelope<'T>) : ZenohResult<byte[]> =
        ZenohSerializer.serialize envelope

    /// Deserialize bytes to envelope
    let deserialize<'T> (bytes: byte[]) : ZenohResult<ZenohEnvelope<'T>> =
        ZenohSerializer.deserialize<ZenohEnvelope<'T>> bytes

    /// Check if envelope is expired
    let isExpired (envelope: ZenohEnvelope<'T>) : bool =
        if envelope.Meta.TtlSeconds <= 0 then false
        else
            let expiry = envelope.Meta.Timestamp.AddSeconds(float envelope.Meta.TtlSeconds)
            DateTimeOffset.UtcNow > expiry

    /// Check if envelope is targeted at specific node
    let isTargetedAt (nodeId: string) (envelope: ZenohEnvelope<'T>) : bool =
        match envelope.Meta.Target with
        | None -> true  // Broadcast - accept everywhere
        | Some target -> target = nodeId

    /// Map payload while preserving metadata
    let map<'T, 'U> (f: 'T -> 'U) (envelope: ZenohEnvelope<'T>) : ZenohEnvelope<'U> =
        {
            Meta = { envelope.Meta with MessageType = typeof<'U>.Name }
            Payload = f envelope.Payload
        }

    /// Add custom header
    let withHeader (key: string) (value: string) (envelope: ZenohEnvelope<'T>) : ZenohEnvelope<'T> =
        { envelope with Meta = { envelope.Meta with Headers = Map.add key value envelope.Meta.Headers } }

    /// Get header value
    let getHeader (key: string) (envelope: ZenohEnvelope<'T>) : string option =
        Map.tryFind key envelope.Meta.Headers

    /// Get age of envelope in milliseconds
    let ageMs (envelope: ZenohEnvelope<'T>) : float =
        (DateTimeOffset.UtcNow - envelope.Meta.Timestamp).TotalMilliseconds

    /// Get remaining TTL in seconds
    let remainingTtl (envelope: ZenohEnvelope<'T>) : int =
        if envelope.Meta.TtlSeconds <= 0 then Int32.MaxValue
        else
            let elapsed = (DateTimeOffset.UtcNow - envelope.Meta.Timestamp).TotalSeconds
            max 0 (envelope.Meta.TtlSeconds - int elapsed)

/// Standard topic patterns for Indrajaal
module ZenohTopics =

    /// Base prefix for all topics
    let [<Literal>] Prefix = "indrajaal"

    /// Build a topic path
    let build (parts: string list) =
        Prefix :: parts
        |> List.filter (not << String.IsNullOrEmpty)
        |> String.concat "/"

    /// Health topics (L5: Node level)
    module Health =
        let node (nodeId: string) = build ["health"; nodeId]
        let mesh = build ["health"; "mesh"]
        let pattern = build ["health"; "**"]

        /// Health status payload
        type HealthPayload = {
            NodeId: string
            Status: string
            Uptime: TimeSpan
            MessagesPublished: int64
            MessagesReceived: int64
            ErrorCount: int
        }

    /// Telemetry topics (L5: Node level)
    module Telemetry =
        let metrics (nodeId: string) = build ["telemetry"; nodeId; "metrics"]
        let logs (nodeId: string) = build ["telemetry"; nodeId; "logs"]
        let traces (nodeId: string) = build ["telemetry"; nodeId; "traces"]
        let pattern = build ["telemetry"; "**"]

    /// Cluster coordination topics (L6: Cluster level)
    module Cluster =
        let barrier (barrierId: string) = build ["cluster"; "barrier"; barrierId]
        let quorum (quorumId: string) = build ["cluster"; "quorum"; quorumId]
        let consensus = build ["cluster"; "consensus"]
        let heartbeat = build ["cluster"; "heartbeat"]
        let pattern = build ["cluster"; "**"]

    /// Federation topics (L7: Federation level)
    module Federation =
        let announce = build ["federation"; "announce"]
        let version = build ["federation"; "version"]
        let attestation (holonId: string) = build ["federation"; "attestation"; holonId]
        let pattern = build ["federation"; "**"]

    /// Prajna cockpit topics
    module Prajna =
        let kpi = build ["prajna"; "kpi"]
        let alerts = build ["prajna"; "alerts"]
        let commands = build ["prajna"; "commands"]
        let state = build ["prajna"; "state"]
        let pattern = build ["prajna"; "**"]

    /// Guardian topics (Constitutional layer)
    module Guardian =
        let proposals = build ["guardian"; "proposals"]
        let approvals = build ["guardian"; "approvals"]
        let vetoes = build ["guardian"; "vetoes"]
        let pattern = build ["guardian"; "**"]

    /// Sentinel topics (Immune system)
    module Sentinel =
        let threats = build ["sentinel"; "threats"]
        let health = build ["sentinel"; "health"]
        let patterns = build ["sentinel"; "patterns"]
        let topicPattern = build ["sentinel"; "**"]

    /// KMS/SMRITI topics (Knowledge management)
    module Kms =
        let holons = build ["kms"; "holons"]
        let evolution = build ["kms"; "evolution"]
        let queries = build ["kms"; "queries"]
        let pattern = build ["kms"; "**"]

    /// Container topics (L4: Container level)
    module Container =
        let state (containerName: string) = build ["container"; containerName; "state"]
        let metrics (containerName: string) = build ["container"; containerName; "metrics"]
        let control (containerName: string) = build ["container"; containerName; "control"]
        let pattern = build ["container"; "**"]

/// Envelope builder for fluent API
type EnvelopeBuilder<'T>(source: string, payload: 'T) =
    let mutable envelope = ZenohEnvelope.create source payload

    /// Set correlation ID
    member this.WithCorrelation(correlationId: Guid) =
        envelope <- { envelope with Meta = { envelope.Meta with CorrelationId = Some correlationId } }
        this

    /// Set target node
    member this.WithTarget(target: string) =
        envelope <- { envelope with Meta = { envelope.Meta with Target = Some target } }
        this

    /// Set TTL
    member this.WithTtl(seconds: int) =
        envelope <- { envelope with Meta = { envelope.Meta with TtlSeconds = seconds } }
        this

    /// Add header
    member this.WithHeader(key: string, value: string) =
        envelope <- ZenohEnvelope.withHeader key value envelope
        this

    /// Build the envelope
    member _.Build() = envelope

/// Extension methods for envelope creation
[<AutoOpen>]
module EnvelopeExtensions =

    /// Create envelope builder
    let envelope<'T> (source: string) (payload: 'T) =
        EnvelopeBuilder<'T>(source, payload)
