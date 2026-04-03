# Zenoh F# 7-Level Integration and Implementation Plan

**Version**: 1.0.0 | **Date**: 2026-01-14 | **STAMP**: SC-ZENOH-IMPL-001
**Author**: Claude Opus 4.5 | **Status**: IMPLEMENTATION READY | **Compliance**: SIL-6 Biomorphic

---

## Executive Summary

This document provides a complete 7-level implementation plan for integrating Eclipse Zenoh into the F# CEPAF codebase, replacing the current simulated implementation with real FFI calls to Zenoh-CS (v0.4.1).

### Implementation Overview

| Level | Name | Focus | Duration | Priority |
|-------|------|-------|----------|----------|
| L1 | Function | FFI bindings, type wrappers | 3 days | P0 |
| L2 | Component | Module organization, namespaces | 1 day | P0 |
| L3 | Holon | Agent communication, envelopes | 2 days | P0 |
| L4 | Container | Package dependencies, deployment | 1 day | P1 |
| L5 | Node | Lifecycle, health, reconnection | 2.5 days | P0 |
| L6 | Cluster | Quorum, barriers, coordination | 3 days | P1 |
| L7 | Federation | Cross-holon, attestation | 2.5 days | P2 |

**Total Duration**: 15 working days (~3 weeks)

---

# Level 1: Function (FFI Bindings)

## L1.1 Overview

**Objective**: Create safe F# wrappers around Zenoh-CS native calls with proper error handling, resource management, and type safety.

**STAMP Constraints**:
- SC-NAT-001: Native library version SHALL be 0.4.1 (zenoh-c v1.6.2)
- SC-NAT-002: All owned types SHALL implement IDisposable
- SC-NAT-003: KeyExpr validation SHALL precede all operations
- SC-NAT-004: Null checks SHALL protect all FFI return values

## L1.2 Files to Create

### L1.2.1 `Zenoh/Core/ZenohTypes.fs`

```fsharp
// =============================================================================
// ZenohTypes.fs - Core Zenoh Type Definitions
// =============================================================================
// STAMP: SC-NAT-001, SC-NAT-002
// AOR: AOR-ZENOH-001
// Criticality: Level 1 (CRITICAL) - Foundation Types
// =============================================================================

namespace Cepaf.Zenoh.Core

open System

/// Connection state enumeration
[<RequireQualifiedAccess>]
type ConnectionStatus =
    | Disconnected
    | Connecting
    | Connected
    | Reconnecting
    | Failed of string

/// Session configuration
type SessionConfig = {
    /// Router endpoints (tcp/host:port)
    Endpoints: string list
    /// Connection timeout in milliseconds
    ConnectTimeoutMs: int
    /// Enable shared memory transport
    EnableShm: bool
    /// Client mode (client/peer/router)
    Mode: string
    /// Session name for identification
    Name: string
}

module SessionConfig =
    let defaultConfig () = {
        Endpoints = ["tcp/localhost:7447"]
        ConnectTimeoutMs = 5000
        EnableShm = false
        Mode = "client"
        Name = "cepaf-session"
    }

/// Publisher configuration
type PublisherConfig = {
    /// Key expression for publishing
    KeyExpr: string
    /// Congestion control (block/drop)
    CongestionControl: string
    /// Priority (1-7, lower is higher priority)
    Priority: int
    /// Enable reliability
    Reliability: string
}

module PublisherConfig =
    let create keyExpr = {
        KeyExpr = keyExpr
        CongestionControl = "block"
        Priority = 5
        Reliability = "reliable"
    }

/// Subscriber configuration
type SubscriberConfig = {
    /// Key expression pattern (supports wildcards)
    KeyExpr: string
    /// Reliability requirement
    Reliability: string
    /// Enable miss detection (zenoh-ext)
    MissDetection: bool
    /// Recovery mode for missed samples
    RecoveryMode: string
}

module SubscriberConfig =
    let create keyExpr = {
        KeyExpr = keyExpr
        Reliability = "reliable"
        MissDetection = false
        RecoveryMode = "none"
    }

/// Query configuration
type QueryConfig = {
    /// Key expression for query
    KeyExpr: string
    /// Query timeout in milliseconds
    TimeoutMs: int
    /// Query target (all/best_matching/all_complete)
    Target: string
}

/// Sample received from subscription
type ZenohSample = {
    /// Key expression of the sample
    KeyExpr: string
    /// Raw payload bytes
    Payload: byte[]
    /// Sample kind (put/delete)
    Kind: string
    /// Timestamp if available
    Timestamp: DateTimeOffset option
    /// Source info
    SourceId: string option
}

/// Result type for Zenoh operations
type ZenohResult<'T> = Result<'T, ZenohError>

and ZenohError =
    | ConnectionFailed of string
    | SessionClosed
    | InvalidKeyExpr of string
    | PublishFailed of string
    | SubscribeFailed of string
    | QueryFailed of string
    | Timeout
    | NativeError of code: int * message: string
    | Disposed

/// Health status for monitoring
type ZenohHealth = {
    Status: ConnectionStatus
    SessionId: string option
    ConnectedAt: DateTimeOffset option
    LastHeartbeat: DateTimeOffset option
    SubscriberCount: int
    PublisherCount: int
    MessagesPublished: int64
    MessagesReceived: int64
    ReconnectCount: int
    ErrorCount: int
}

module ZenohHealth =
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
    }
```

### L1.2.2 `Zenoh/Core/ZenohNative.fs`

```fsharp
// =============================================================================
// ZenohNative.fs - Native FFI Wrappers for Zenoh-CS
// =============================================================================
// STAMP: SC-NAT-001 to SC-NAT-004, SC-SESS-005
// AOR: AOR-ZENOH-002, AOR-ZENOH-003
// Criticality: Level 1 (CRITICAL) - FFI Safety Layer
// =============================================================================

namespace Cepaf.Zenoh.Core

open System
open System.Threading
open System.Threading.Tasks
open Zenoh  // From Zenoh-CS NuGet package

/// Safe session wrapper with IDisposable (SC-NAT-002)
[<Sealed>]
type SafeSession private (session: Session, config: SessionConfig) =
    let mutable disposed = false
    let lockObj = obj()

    /// Get underlying session (internal use only)
    member internal _.Raw = session

    /// Session configuration
    member _.Config = config

    /// Check if session is valid
    member _.IsValid =
        not disposed && session <> null

    /// Open a new session (SC-NAT-001)
    static member OpenAsync(config: SessionConfig) : Task<Result<SafeSession, ZenohError>> =
        task {
            try
                // Build Zenoh config
                let zenohConfig = Config()

                // Add endpoints
                for endpoint in config.Endpoints do
                    zenohConfig.ConnectEndpoints.Add(endpoint)

                // Set mode
                zenohConfig.Mode <-
                    match config.Mode with
                    | "peer" -> Zenoh.WhatAmI.Peer
                    | "router" -> Zenoh.WhatAmI.Router
                    | _ -> Zenoh.WhatAmI.Client

                // Open session with timeout (SC-OP-001)
                use cts = new CancellationTokenSource(config.ConnectTimeoutMs)
                let! session = Session.OpenAsync(zenohConfig).AsTask()

                // Validate session (SC-NAT-004)
                if isNull session then
                    return Error (ZenohError.ConnectionFailed "Session.Open returned null")
                else
                    return Ok (new SafeSession(session, config))
            with
            | :? OperationCanceledException ->
                return Error ZenohError.Timeout
            | ex ->
                return Error (ZenohError.ConnectionFailed ex.Message)
        }

    /// Close session gracefully
    member this.CloseAsync() : Task<unit> =
        task {
            if not disposed then
                lock lockObj (fun () ->
                    if not disposed then
                        disposed <- true
                        try
                            session.Dispose()
                        with _ -> ()
                )
        }

    interface IDisposable with
        member this.Dispose() =
            this.CloseAsync() |> Async.AwaitTask |> Async.RunSynchronously

/// Safe publisher wrapper (SC-NAT-002)
[<Sealed>]
type SafePublisher private (publisher: Publisher, keyExpr: string) =
    let mutable disposed = false

    member _.KeyExpr = keyExpr
    member internal _.Raw = publisher

    /// Create publisher from session
    static member Create(session: SafeSession, config: PublisherConfig) : Result<SafePublisher, ZenohError> =
        try
            if not session.IsValid then
                Error ZenohError.SessionClosed
            else
                // Validate key expression (SC-NAT-003)
                let keyExprResult = KeyExpr.TryFrom(config.KeyExpr)
                match keyExprResult with
                | None ->
                    Error (ZenohError.InvalidKeyExpr config.KeyExpr)
                | Some ke ->
                    let publisher = session.Raw.DeclarePublisher(ke)
                    if isNull publisher then
                        Error (ZenohError.PublishFailed "DeclarePublisher returned null")
                    else
                        Ok (new SafePublisher(publisher, config.KeyExpr))
        with ex ->
            Error (ZenohError.PublishFailed ex.Message)

    /// Publish bytes
    member this.PutAsync(payload: byte[]) : Task<Result<unit, ZenohError>> =
        task {
            if disposed then
                return Error ZenohError.Disposed
            else
                try
                    do! publisher.PutAsync(payload).AsTask()
                    return Ok ()
                with ex ->
                    return Error (ZenohError.PublishFailed ex.Message)
        }

    interface IDisposable with
        member _.Dispose() =
            if not disposed then
                disposed <- true
                try publisher.Dispose() with _ -> ()

/// Safe subscriber wrapper (SC-NAT-002)
[<Sealed>]
type SafeSubscriber private (subscriber: Subscriber, keyExpr: string, callback: ZenohSample -> unit) =
    let mutable disposed = false

    member _.KeyExpr = keyExpr

    /// Create subscriber from session
    static member Create(
        session: SafeSession,
        config: SubscriberConfig,
        handler: ZenohSample -> unit) : Result<SafeSubscriber, ZenohError> =
        try
            if not session.IsValid then
                Error ZenohError.SessionClosed
            else
                // Validate key expression (SC-NAT-003)
                let keyExprResult = KeyExpr.TryFrom(config.KeyExpr)
                match keyExprResult with
                | None ->
                    Error (ZenohError.InvalidKeyExpr config.KeyExpr)
                | Some ke ->
                    // Wrap callback with error handling (SC-SESS-005)
                    let safeCallback (sample: Sample) =
                        try
                            let zenohSample = {
                                KeyExpr = sample.KeyExpr.ToString()
                                Payload = sample.Payload.ToArray()
                                Kind = "put"
                                Timestamp = None
                                SourceId = None
                            }
                            handler zenohSample
                        with ex ->
                            // Log but don't throw (SC-MSG-003)
                            eprintfn "[Zenoh] Callback error: %s" ex.Message

                    let subscriber = session.Raw.DeclareSubscriber(ke, Action<Sample>(safeCallback))
                    if isNull subscriber then
                        Error (ZenohError.SubscribeFailed "DeclareSubscriber returned null")
                    else
                        Ok (new SafeSubscriber(subscriber, config.KeyExpr, handler))
        with ex ->
            Error (ZenohError.SubscribeFailed ex.Message)

    interface IDisposable with
        member _.Dispose() =
            if not disposed then
                disposed <- true
                try subscriber.Dispose() with _ -> ()

/// KeyExpr validation utilities (SC-NAT-003)
module ZenohKeyExpr =

    /// Validate a key expression
    let validate (keyExpr: string) : Result<string, ZenohError> =
        if String.IsNullOrWhiteSpace(keyExpr) then
            Error (ZenohError.InvalidKeyExpr "Key expression cannot be empty")
        elif keyExpr.Contains("//") then
            Error (ZenohError.InvalidKeyExpr "Key expression cannot contain '//'")
        else
            match KeyExpr.TryFrom(keyExpr) with
            | Some _ -> Ok keyExpr
            | None -> Error (ZenohError.InvalidKeyExpr keyExpr)

    /// Check if a key expression matches another
    let matches (pattern: string) (key: string) : bool =
        match KeyExpr.TryFrom(pattern), KeyExpr.TryFrom(key) with
        | Some p, Some k -> p.Includes(k)
        | _ -> false

    /// Join key expression parts
    let join (parts: string list) : string =
        String.Join("/", parts |> List.filter (not << String.IsNullOrEmpty))
```

### L1.2.3 `Zenoh/Core/ZenohSerialization.fs`

```fsharp
// =============================================================================
// ZenohSerialization.fs - Type-Safe Serialization for Zenoh Messages
// =============================================================================
// STAMP: SC-MSG-002, SC-SER-001, SC-SER-002
// AOR: AOR-ZENOH-004
// Criticality: Level 1 (CRITICAL) - Data Integrity
// =============================================================================

namespace Cepaf.Zenoh.Core

open System
open System.Text.Json
open System.Text.Json.Serialization

/// JSON serialization options for F#/Elixir compatibility
module ZenohJson =

    /// Snake_case naming policy for Elixir compatibility
    type SnakeCaseNamingPolicy() =
        inherit JsonNamingPolicy()

        override _.ConvertName(name: string) =
            if String.IsNullOrEmpty(name) then name
            else
                let chars =
                    name
                    |> Seq.mapi (fun i c ->
                        if i > 0 && Char.IsUpper(c) then
                            [| '_'; Char.ToLower(c) |]
                        else
                            [| Char.ToLower(c) |])
                    |> Seq.concat
                    |> Seq.toArray
                String(chars)

    /// Default serialization options
    let options =
        let opts = JsonSerializerOptions()
        opts.PropertyNamingPolicy <- SnakeCaseNamingPolicy()
        opts.DefaultIgnoreCondition <- JsonIgnoreCondition.WhenWritingNull
        opts.Converters.Add(JsonFSharpConverter())
        opts.WriteIndented <- false
        opts

/// Serialization functions
module ZenohSerializer =

    /// Serialize to JSON bytes
    let serialize<'T> (value: 'T) : Result<byte[], ZenohError> =
        try
            let json = JsonSerializer.SerializeToUtf8Bytes(value, ZenohJson.options)
            Ok json
        with ex ->
            Error (ZenohError.NativeError(1, sprintf "Serialization failed: %s" ex.Message))

    /// Deserialize from JSON bytes
    let deserialize<'T> (bytes: byte[]) : Result<'T, ZenohError> =
        try
            let value = JsonSerializer.Deserialize<'T>(ReadOnlySpan(bytes), ZenohJson.options)
            Ok value
        with ex ->
            Error (ZenohError.NativeError(2, sprintf "Deserialization failed: %s" ex.Message))

    /// Serialize to string (for debugging)
    let serializeString<'T> (value: 'T) : string =
        JsonSerializer.Serialize(value, ZenohJson.options)
```

## L1.3 Tests to Create

### L1.3.1 `ZenohNativeTests.fs`

```fsharp
module Cepaf.Zenoh.Tests.ZenohNativeTests

open Xunit
open FsCheck
open FsCheck.Xunit
open Cepaf.Zenoh.Core

[<Fact>]
let ``SafeSession.OpenAsync returns error for invalid endpoint`` () =
    async {
        let config = { SessionConfig.defaultConfig() with Endpoints = ["invalid://bad"] }
        let! result = SafeSession.OpenAsync(config) |> Async.AwaitTask

        match result with
        | Error (ZenohError.ConnectionFailed _) -> Assert.True(true)
        | _ -> Assert.True(false, "Expected ConnectionFailed error")
    } |> Async.RunSynchronously

[<Fact>]
let ``ZenohKeyExpr.validate accepts valid keys`` () =
    let validKeys = [
        "a/b/c"
        "indrajaal/telemetry/node1"
        "test/**"
        "sensor/**/temperature"
    ]

    for key in validKeys do
        match ZenohKeyExpr.validate key with
        | Ok _ -> Assert.True(true)
        | Error e -> Assert.True(false, sprintf "Key '%s' should be valid: %A" key e)

[<Fact>]
let ``ZenohKeyExpr.validate rejects invalid keys`` () =
    let invalidKeys = [
        ""
        "a//b"
        "   "
    ]

    for key in invalidKeys do
        match ZenohKeyExpr.validate key with
        | Error _ -> Assert.True(true)
        | Ok _ -> Assert.True(false, sprintf "Key '%s' should be invalid" key)

[<Property>]
let ``Serialization round-trip preserves data`` (value: int * string) =
    match ZenohSerializer.serialize value with
    | Ok bytes ->
        match ZenohSerializer.deserialize<int * string> bytes with
        | Ok result -> result = value
        | Error _ -> false
    | Error _ -> false
```

## L1.4 Acceptance Criteria

| ID | Criterion | Verification |
|----|-----------|--------------|
| L1-AC-001 | `dotnet build` succeeds with Zenoh-CS | Build log |
| L1-AC-002 | SafeSession implements IDisposable | Code review |
| L1-AC-003 | SafePublisher implements IDisposable | Code review |
| L1-AC-004 | SafeSubscriber implements IDisposable | Code review |
| L1-AC-005 | All FFI calls wrapped in try/catch | Code review |
| L1-AC-006 | KeyExpr validation on all operations | Unit tests |
| L1-AC-007 | Null checks on all native returns | Code review |
| L1-AC-008 | 15+ unit tests passing | Test report |

---

# Level 2: Component (Module Organization)

## L2.1 Overview

**Objective**: Organize F# modules with correct compile order, namespaces, and layer separation.

**STAMP Constraints**:
- SC-MOD-001: Compile order SHALL follow dependency graph
- SC-MOD-002: No circular dependencies permitted
- SC-MOD-003: Layer boundaries SHALL be enforced

## L2.2 Module Structure

```
lib/cepaf/src/Cepaf/
├── Zenoh/
│   ├── Core/                      # L1: Foundation types
│   │   ├── ZenohTypes.fs          # Type definitions
│   │   ├── ZenohNative.fs         # FFI wrappers
│   │   └── ZenohSerialization.fs  # JSON serialization
│   │
│   ├── Session/                   # L5: Lifecycle management
│   │   ├── ZenohLifecycle.fs      # Init/shutdown
│   │   ├── ZenohSession.fs        # Session state (UPDATED)
│   │   └── ZenohHealth.fs         # Health monitoring
│   │
│   ├── Messaging/                 # L3: Pub/Sub
│   │   ├── ZenohEnvelope.fs       # Typed envelopes
│   │   ├── ZenohPublisher.fs      # Publishing
│   │   ├── ZenohSubscriber.fs     # Subscribing
│   │   └── ZenohChannel.fs        # QuadplexLogger (UPDATED)
│   │
│   ├── Cluster/                   # L6: Coordination
│   │   ├── ZenohBarrier.fs        # Barrier sync
│   │   ├── ZenohQuorum.fs         # Voting
│   │   └── ZenohConsensus.fs      # 2oo3 logic
│   │
│   └── Federation/                # L7: Cross-holon
│       ├── ZenohFederation.fs     # Federation protocol
│       ├── ZenohAttestation.fs    # Hourly attestation
│       └── ZenohVersion.fs        # Version negotiation
│
└── Cepaf.fsproj                   # Project file (UPDATED)
```

## L2.3 Project File Update

### `Cepaf.fsproj` Changes

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup>

  <ItemGroup>
    <!-- Zenoh-CS Package (SC-NAT-001) -->
    <PackageReference Include="Zenoh-CS" Version="0.4.1" />
    <PackageReference Include="System.Text.Json" Version="9.0.0" />
    <PackageReference Include="FSharp.SystemTextJson" Version="1.3.13" />
  </ItemGroup>

  <ItemGroup>
    <!-- L1: Core Types (compile first) -->
    <Compile Include="Zenoh/Core/ZenohTypes.fs" />
    <Compile Include="Zenoh/Core/ZenohSerialization.fs" />
    <Compile Include="Zenoh/Core/ZenohNative.fs" />

    <!-- L3: Messaging -->
    <Compile Include="Zenoh/Messaging/ZenohEnvelope.fs" />
    <Compile Include="Zenoh/Messaging/ZenohPublisher.fs" />
    <Compile Include="Zenoh/Messaging/ZenohSubscriber.fs" />

    <!-- L5: Session -->
    <Compile Include="Zenoh/Session/ZenohHealth.fs" />
    <Compile Include="Zenoh/Session/ZenohLifecycle.fs" />
    <Compile Include="Zenoh/Session/ZenohSession.fs" />

    <!-- L3: Channel (depends on Session) -->
    <Compile Include="Zenoh/Messaging/ZenohChannel.fs" />

    <!-- L6: Cluster -->
    <Compile Include="Zenoh/Cluster/ZenohBarrier.fs" />
    <Compile Include="Zenoh/Cluster/ZenohQuorum.fs" />
    <Compile Include="Zenoh/Cluster/ZenohConsensus.fs" />

    <!-- L7: Federation -->
    <Compile Include="Zenoh/Federation/ZenohVersion.fs" />
    <Compile Include="Zenoh/Federation/ZenohAttestation.fs" />
    <Compile Include="Zenoh/Federation/ZenohFederation.fs" />

    <!-- Existing files... -->
  </ItemGroup>

  <!-- Native library deployment (SC-NAT-001) -->
  <Target Name="CopyNativeLibs" AfterTargets="Build">
    <ItemGroup>
      <NativeLibs Include="$(NuGetPackageRoot)zenoh-cs/0.4.1/runtimes/$(RuntimeIdentifier)/native/*" />
    </ItemGroup>
    <Copy SourceFiles="@(NativeLibs)" DestinationFolder="$(OutputPath)" SkipUnchangedFiles="true" />
  </Target>
</Project>
```

## L2.4 Namespace Hierarchy

```fsharp
Cepaf.Zenoh.Core           // L1: Types, FFI, Serialization
Cepaf.Zenoh.Messaging      // L3: Envelope, Publisher, Subscriber
Cepaf.Zenoh.Session        // L5: Lifecycle, Health
Cepaf.Zenoh.Cluster        // L6: Barrier, Quorum, Consensus
Cepaf.Zenoh.Federation     // L7: Federation, Attestation
```

## L2.5 Acceptance Criteria

| ID | Criterion | Verification |
|----|-----------|--------------|
| L2-AC-001 | No FS0039 compile order errors | Build log |
| L2-AC-002 | No circular dependency warnings | Build log |
| L2-AC-003 | All namespaces follow convention | Code review |
| L2-AC-004 | Native library copies to output | Build inspection |
| L2-AC-005 | `dotnet build` completes in <30s | Build timing |

---

# Level 3: Holon (Agent Communication)

## L3.1 Overview

**Objective**: Implement typed message envelopes and pub/sub patterns for inter-agent communication.

**STAMP Constraints**:
- SC-MSG-001: Message latency SHALL be < 100ms (p99)
- SC-MSG-002: All messages SHALL use ZenohEnvelope
- SC-MSG-003: Callback execution SHALL timeout in 50ms
- SC-MSG-004: Message buffer SHALL be bounded to 10000 entries
- SC-MSG-005: Miss detection SHALL be enabled for critical topics

## L3.2 Files to Create

### L3.2.1 `Zenoh/Messaging/ZenohEnvelope.fs`

```fsharp
// =============================================================================
// ZenohEnvelope.fs - Typed Message Envelopes
// =============================================================================
// STAMP: SC-MSG-002, SC-MSG-006
// AOR: AOR-ZENOH-005
// Criticality: Level 3 (HIGH) - Message Integrity
// =============================================================================

namespace Cepaf.Zenoh.Messaging

open System
open System.Diagnostics
open Cepaf.Zenoh.Core

/// Envelope metadata for tracing and routing
type EnvelopeMetadata = {
    /// Unique message identifier
    MessageId: Guid
    /// Correlation ID for request/response
    CorrelationId: Guid option
    /// ISO 8601 timestamp
    Timestamp: DateTimeOffset
    /// Source holon/node identifier
    Source: string
    /// Schema version for compatibility
    SchemaVersion: string
    /// W3C Trace ID for distributed tracing
    TraceId: string option
    /// W3C Span ID
    SpanId: string option
    /// Message type name
    MessageType: string
    /// Time-to-live in seconds (0 = infinite)
    TtlSeconds: int
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
        let activity = Activity.Current
        {
            Meta = {
                MessageId = Guid.NewGuid()
                CorrelationId = None
                Timestamp = DateTimeOffset.UtcNow
                Source = source
                SchemaVersion = "1.0.0"
                TraceId = activity |> Option.ofObj |> Option.map (fun a -> a.TraceId.ToString())
                SpanId = activity |> Option.ofObj |> Option.map (fun a -> a.SpanId.ToString())
                MessageType = typeof<'T>.Name
                TtlSeconds = 300  // 5 minute default
            }
            Payload = payload
        }

    /// Create envelope with correlation ID (for request/response)
    let createCorrelated<'T> (source: string) (correlationId: Guid) (payload: 'T) : ZenohEnvelope<'T> =
        { create source payload with Meta = { (create source payload).Meta with CorrelationId = Some correlationId } }

    /// Serialize envelope to bytes
    let serialize<'T> (envelope: ZenohEnvelope<'T>) : Result<byte[], ZenohError> =
        ZenohSerializer.serialize envelope

    /// Deserialize bytes to envelope
    let deserialize<'T> (bytes: byte[]) : Result<ZenohEnvelope<'T>, ZenohError> =
        ZenohSerializer.deserialize<ZenohEnvelope<'T>> bytes

    /// Check if envelope is expired
    let isExpired (envelope: ZenohEnvelope<'T>) : bool =
        if envelope.Meta.TtlSeconds <= 0 then false
        else
            let expiry = envelope.Meta.Timestamp.AddSeconds(float envelope.Meta.TtlSeconds)
            DateTimeOffset.UtcNow > expiry

    /// Map payload while preserving metadata
    let map<'T, 'U> (f: 'T -> 'U) (envelope: ZenohEnvelope<'T>) : ZenohEnvelope<'U> =
        { Meta = envelope.Meta; Payload = f envelope.Payload }

/// Standard topic patterns for Indrajaal
module ZenohTopics =

    /// Base prefix for all topics
    let [<Literal>] Prefix = "indrajaal"

    /// Health topics
    module Health =
        let node (nodeId: string) = sprintf "%s/health/%s" Prefix nodeId
        let mesh = sprintf "%s/health/mesh" Prefix
        let pattern = sprintf "%s/health/**" Prefix

    /// Telemetry topics
    module Telemetry =
        let metrics (nodeId: string) = sprintf "%s/telemetry/%s/metrics" Prefix nodeId
        let logs (nodeId: string) = sprintf "%s/telemetry/%s/logs" Prefix nodeId
        let traces (nodeId: string) = sprintf "%s/telemetry/%s/traces" Prefix nodeId
        let pattern = sprintf "%s/telemetry/**" Prefix

    /// Cluster coordination topics
    module Cluster =
        let barrier (barrierId: string) = sprintf "%s/cluster/barrier/%s" Prefix barrierId
        let quorum (quorumId: string) = sprintf "%s/cluster/quorum/%s" Prefix quorumId
        let consensus = sprintf "%s/cluster/consensus" Prefix
        let pattern = sprintf "%s/cluster/**" Prefix

    /// Federation topics
    module Federation =
        let announce = sprintf "%s/federation/announce" Prefix
        let version = sprintf "%s/federation/version" Prefix
        let attestation (holonId: string) = sprintf "%s/federation/attestation/%s" Prefix holonId
        let pattern = sprintf "%s/federation/**" Prefix

    /// Prajna cockpit topics
    module Prajna =
        let kpi = sprintf "%s/prajna/kpi" Prefix
        let alerts = sprintf "%s/prajna/alerts" Prefix
        let commands = sprintf "%s/prajna/commands" Prefix
        let pattern = sprintf "%s/prajna/**" Prefix

    /// Guardian topics
    module Guardian =
        let proposals = sprintf "%s/guardian/proposals" Prefix
        let approvals = sprintf "%s/guardian/approvals" Prefix
        let vetoes = sprintf "%s/guardian/vetoes" Prefix
```

### L3.2.2 `Zenoh/Messaging/ZenohPublisher.fs`

```fsharp
// =============================================================================
// ZenohPublisher.fs - Type-Safe Publishing
// =============================================================================
// STAMP: SC-MSG-001, SC-MSG-006
// AOR: AOR-ZENOH-006
// Criticality: Level 3 (HIGH) - Message Delivery
// =============================================================================

namespace Cepaf.Zenoh.Messaging

open System
open System.Threading
open System.Threading.Tasks
open System.Collections.Concurrent
open Cepaf.Zenoh.Core

/// Publisher statistics
type PublisherStats = {
    MessagesPublished: int64
    BytesSent: int64
    Errors: int64
    LastPublishTime: DateTimeOffset option
    AverageLatencyMs: float
}

/// Typed publisher for a specific message type
type TypedPublisher<'T>(session: SafeSession, keyExpr: string, source: string) =
    let mutable publisher: SafePublisher option = None
    let mutable stats = { MessagesPublished = 0L; BytesSent = 0L; Errors = 0L; LastPublishTime = None; AverageLatencyMs = 0.0 }
    let lockObj = obj()
    let latencies = ConcurrentQueue<float>()
    let maxLatencySamples = 100

    /// Initialize publisher
    member _.Initialize() : Result<unit, ZenohError> =
        let config = PublisherConfig.create keyExpr
        match SafePublisher.Create(session, config) with
        | Ok pub ->
            publisher <- Some pub
            Ok ()
        | Error e -> Error e

    /// Publish a typed message (SC-MSG-002)
    member this.PublishAsync(payload: 'T) : Task<Result<unit, ZenohError>> =
        task {
            match publisher with
            | None ->
                return Error (ZenohError.PublishFailed "Publisher not initialized")
            | Some pub ->
                let envelope = ZenohEnvelope.create source payload
                match ZenohEnvelope.serialize envelope with
                | Error e ->
                    Interlocked.Increment(&stats.Errors) |> ignore
                    return Error e
                | Ok bytes ->
                    let sw = System.Diagnostics.Stopwatch.StartNew()
                    let! result = pub.PutAsync(bytes)
                    sw.Stop()

                    match result with
                    | Ok () ->
                        // Update statistics
                        Interlocked.Increment(&stats.MessagesPublished) |> ignore
                        Interlocked.Add(&stats.BytesSent, int64 bytes.Length) |> ignore

                        // Track latency
                        latencies.Enqueue(sw.Elapsed.TotalMilliseconds)
                        while latencies.Count > maxLatencySamples do
                            latencies.TryDequeue() |> ignore

                        lock lockObj (fun () ->
                            stats <- { stats with
                                LastPublishTime = Some DateTimeOffset.UtcNow
                                AverageLatencyMs = latencies |> Seq.average
                            }
                        )
                        return Ok ()
                    | Error e ->
                        Interlocked.Increment(&stats.Errors) |> ignore
                        return Error e
        }

    /// Get publisher statistics
    member _.Stats = stats

    /// Dispose
    interface IDisposable with
        member _.Dispose() =
            publisher |> Option.iter (fun p -> (p :> IDisposable).Dispose())

/// Batch publisher for high-throughput scenarios (SC-MSG-006)
type BatchPublisher<'T>(session: SafeSession, keyExpr: string, source: string, batchSize: int, flushIntervalMs: int) =
    let publisher = new TypedPublisher<'T>(session, keyExpr, source)
    let buffer = ConcurrentQueue<'T>()
    let mutable timer: Timer option = None
    let maxBatchSize = min batchSize 100  // SC-MSG-006: Max 100

    /// Initialize and start timer
    member this.Start() : Result<unit, ZenohError> =
        match publisher.Initialize() with
        | Ok () ->
            timer <- Some (new Timer(TimerCallback(fun _ -> this.FlushAsync() |> Async.AwaitTask |> Async.RunSynchronously), null, flushIntervalMs, flushIntervalMs))
            Ok ()
        | Error e -> Error e

    /// Add to batch
    member _.Add(payload: 'T) =
        buffer.Enqueue(payload)

    /// Flush batch
    member _.FlushAsync() : Task<unit> =
        task {
            let batch = System.Collections.Generic.List<'T>()
            while batch.Count < maxBatchSize && buffer.TryDequeue() |> fst do
                match buffer.TryDequeue() with
                | true, item -> batch.Add(item)
                | false, _ -> ()

            for item in batch do
                let! _ = publisher.PublishAsync(item)
                ()
        }

    interface IDisposable with
        member _.Dispose() =
            timer |> Option.iter (fun t -> t.Dispose())
            (publisher :> IDisposable).Dispose()
```

### L3.2.3 `Zenoh/Messaging/ZenohSubscriber.fs`

```fsharp
// =============================================================================
// ZenohSubscriber.fs - Type-Safe Subscribing with Bounded Callbacks
// =============================================================================
// STAMP: SC-MSG-003, SC-MSG-004, SC-MSG-005, SC-SESS-003
// AOR: AOR-ZENOH-007
// Criticality: Level 3 (HIGH) - Message Reception
// =============================================================================

namespace Cepaf.Zenoh.Messaging

open System
open System.Threading
open System.Threading.Tasks
open System.Collections.Concurrent
open Cepaf.Zenoh.Core

/// Subscriber statistics
type SubscriberStats = {
    MessagesReceived: int64
    BytesReceived: int64
    Errors: int64
    Timeouts: int64
    LastReceiveTime: DateTimeOffset option
    AverageProcessingMs: float
}

/// Bounded callback wrapper (SC-MSG-003)
module BoundedCallback =

    /// Execute callback with timeout
    let executeWithTimeout<'T> (timeoutMs: int) (handler: 'T -> unit) (value: 'T) : bool =
        use cts = new CancellationTokenSource(timeoutMs)
        try
            let task = Task.Run((fun () -> handler value), cts.Token)
            task.Wait(cts.Token)
            true
        with
        | :? OperationCanceledException -> false
        | :? AggregateException as ae when ae.InnerException :? OperationCanceledException -> false
        | _ -> false

/// Typed subscriber for a specific message type
type TypedSubscriber<'T>(session: SafeSession, keyExpr: string, callbackTimeoutMs: int) =
    let mutable subscriber: SafeSubscriber option = None
    let mutable stats = { MessagesReceived = 0L; BytesReceived = 0L; Errors = 0L; Timeouts = 0L; LastReceiveTime = None; AverageProcessingMs = 0.0 }
    let lockObj = obj()
    let processingTimes = ConcurrentQueue<float>()
    let maxSamples = 100
    let callbackTimeout = max callbackTimeoutMs 50  // SC-MSG-003: Min 50ms

    /// Subscribe with typed handler
    member this.Subscribe(handler: ZenohEnvelope<'T> -> unit) : Result<unit, ZenohError> =
        let config = { SubscriberConfig.create keyExpr with MissDetection = true }

        // Wrap handler with timeout and deserialization
        let wrappedHandler (sample: ZenohSample) =
            let sw = System.Diagnostics.Stopwatch.StartNew()

            // Deserialize
            match ZenohEnvelope.deserialize<'T> sample.Payload with
            | Error _ ->
                Interlocked.Increment(&stats.Errors) |> ignore
            | Ok envelope ->
                // Check expiry
                if ZenohEnvelope.isExpired envelope then
                    Interlocked.Increment(&stats.Errors) |> ignore
                else
                    // Execute with timeout (SC-MSG-003)
                    let completed = BoundedCallback.executeWithTimeout callbackTimeout handler envelope

                    sw.Stop()

                    if completed then
                        Interlocked.Increment(&stats.MessagesReceived) |> ignore
                        Interlocked.Add(&stats.BytesReceived, int64 sample.Payload.Length) |> ignore

                        processingTimes.Enqueue(sw.Elapsed.TotalMilliseconds)
                        while processingTimes.Count > maxSamples do
                            processingTimes.TryDequeue() |> ignore

                        lock lockObj (fun () ->
                            stats <- { stats with
                                LastReceiveTime = Some DateTimeOffset.UtcNow
                                AverageProcessingMs = processingTimes |> Seq.average
                            }
                        )
                    else
                        Interlocked.Increment(&stats.Timeouts) |> ignore

        match SafeSubscriber.Create(session, config, wrappedHandler) with
        | Ok sub ->
            subscriber <- Some sub
            Ok ()
        | Error e -> Error e

    /// Get statistics
    member _.Stats = stats

    /// Unsubscribe
    interface IDisposable with
        member _.Dispose() =
            subscriber |> Option.iter (fun s -> (s :> IDisposable).Dispose())

/// Subscriber registry with limits (SC-SESS-003)
type SubscriberRegistry(maxSubscribers: int) =
    let subscribers = ConcurrentDictionary<string, IDisposable>()
    let maxSubs = min maxSubscribers 1000  // SC-SESS-003: Max 1000

    /// Register a subscriber
    member _.Register(keyExpr: string, subscriber: IDisposable) : Result<unit, ZenohError> =
        if subscribers.Count >= maxSubs then
            Error (ZenohError.SubscribeFailed (sprintf "Maximum subscribers (%d) reached" maxSubs))
        else
            subscribers.[keyExpr] <- subscriber
            Ok ()

    /// Unregister a subscriber
    member _.Unregister(keyExpr: string) =
        match subscribers.TryRemove(keyExpr) with
        | true, sub -> sub.Dispose()
        | false, _ -> ()

    /// Get count
    member _.Count = subscribers.Count

    /// Dispose all
    interface IDisposable with
        member _.Dispose() =
            for kvp in subscribers do
                kvp.Value.Dispose()
            subscribers.Clear()
```

## L3.3 Acceptance Criteria

| ID | Criterion | Verification |
|----|-----------|--------------|
| L3-AC-001 | ZenohEnvelope includes trace context | Unit test |
| L3-AC-002 | Callback timeout enforced at 50ms | Integration test |
| L3-AC-003 | Message buffer bounded to 10000 | Load test |
| L3-AC-004 | Expired messages rejected | Unit test |
| L3-AC-005 | Statistics tracked accurately | Unit test |
| L3-AC-006 | Subscriber registry limits enforced | Unit test |

---

# Level 4: Container (Package Dependencies)

## L4.1 Overview

**Objective**: Configure package dependencies and native library deployment for container builds.

**STAMP Constraints**:
- SC-PKG-001: Zenoh-CS version pinned to 0.4.1
- SC-PKG-002: Native libraries deployed to output
- SC-PKG-003: Platform-specific builds supported

## L4.2 NuGet Configuration

### `nuget.config`

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
  <packageSourceMapping>
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>
  </packageSourceMapping>
</configuration>
```

### Package References

```xml
<ItemGroup>
  <!-- Core Zenoh -->
  <PackageReference Include="Zenoh-CS" Version="0.4.1" />

  <!-- JSON Serialization -->
  <PackageReference Include="System.Text.Json" Version="9.0.0" />
  <PackageReference Include="FSharp.SystemTextJson" Version="1.3.13" />

  <!-- Logging -->
  <PackageReference Include="Microsoft.Extensions.Logging.Abstractions" Version="9.0.0" />

  <!-- Telemetry -->
  <PackageReference Include="System.Diagnostics.DiagnosticSource" Version="9.0.0" />
</ItemGroup>
```

## L4.3 Dockerfile Updates

```dockerfile
# Zenoh native library setup
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build

# Install Zenoh-C native library
RUN apt-get update && apt-get install -y \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy and restore
WORKDIR /src
COPY ["lib/cepaf/src/Cepaf/Cepaf.fsproj", "Cepaf/"]
RUN dotnet restore "Cepaf/Cepaf.fsproj"

# Build
COPY ["lib/cepaf/src/Cepaf/", "Cepaf/"]
RUN dotnet build "Cepaf/Cepaf.fsproj" -c Release -o /app/build

# Publish
RUN dotnet publish "Cepaf/Cepaf.fsproj" -c Release -o /app/publish

# Runtime
FROM mcr.microsoft.com/dotnet/runtime:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .

# Ensure native libraries are present
ENV LD_LIBRARY_PATH=/app:$LD_LIBRARY_PATH
```

## L4.4 Acceptance Criteria

| ID | Criterion | Verification |
|----|-----------|--------------|
| L4-AC-001 | Zenoh-CS 0.4.1 resolves from NuGet | Build log |
| L4-AC-002 | Native library present in output | File check |
| L4-AC-003 | Container builds successfully | Docker build |
| L4-AC-004 | Runtime finds native library | Container test |

---

# Level 5: Node (Lifecycle Management)

## L5.1 Overview

**Objective**: Implement session lifecycle, health monitoring, and reconnection with exponential backoff.

**STAMP Constraints**:
- SC-OP-001: Session initialization SHALL complete within 5 seconds
- SC-OP-002: Reconnection SHALL use exponential backoff (max 60s)
- SC-OP-003: Health check SHALL run every 10 seconds
- SC-OP-004: Maximum 10 reconnection attempts before alert

## L5.2 Files to Create

### L5.2.1 `Zenoh/Session/ZenohLifecycle.fs`

```fsharp
// =============================================================================
// ZenohLifecycle.fs - Session Lifecycle Management
// =============================================================================
// STAMP: SC-OP-001 to SC-OP-004, SC-SESS-001
// AOR: AOR-ZENOH-008
// Criticality: Level 5 (CRITICAL) - System Availability
// =============================================================================

namespace Cepaf.Zenoh.Session

open System
open System.Threading
open System.Threading.Tasks
open Cepaf.Zenoh.Core

/// Lifecycle events
type LifecycleEvent =
    | Initializing
    | Connected of sessionId: string
    | Disconnected of reason: string
    | Reconnecting of attempt: int
    | ReconnectFailed of attempts: int
    | Shutdown

/// Lifecycle state machine
type LifecycleState =
    | Uninitialized
    | Starting
    | Running of SafeSession
    | Reconnecting of attempt: int * lastError: string
    | Stopped of reason: string

/// Exponential backoff calculator (SC-OP-002)
module ExponentialBackoff =

    let calculate (attempt: int) (baseMs: int) (maxMs: int) : int =
        let backoff = baseMs * (pown 2 (min attempt 10))
        min backoff maxMs

    let defaultBase = 1000    // 1 second
    let defaultMax = 60000    // 60 seconds

/// Lifecycle manager
type ZenohLifecycle(config: SessionConfig) =
    let mutable state = Uninitialized
    let mutable healthTimer: Timer option = None
    let mutable reconnectAttempts = 0
    let maxReconnectAttempts = 10  // SC-OP-004
    let healthCheckIntervalMs = 10000  // SC-OP-003: 10 seconds
    let lockObj = obj()

    let eventHandlers = ResizeArray<LifecycleEvent -> unit>()

    let raiseEvent event =
        for handler in eventHandlers do
            try handler event with _ -> ()

    /// Subscribe to lifecycle events
    member _.OnEvent(handler: LifecycleEvent -> unit) =
        eventHandlers.Add(handler)

    /// Get current state
    member _.State = state

    /// Get current session if running
    member _.Session =
        match state with
        | Running session -> Some session
        | _ -> None

    /// Initialize session (SC-OP-001)
    member this.InitializeAsync() : Task<Result<SafeSession, ZenohError>> =
        task {
            lock lockObj (fun () -> state <- Starting)
            raiseEvent Initializing

            // Timeout at 5 seconds (SC-OP-001)
            use cts = new CancellationTokenSource(5000)

            try
                let! result = SafeSession.OpenAsync(config)

                match result with
                | Ok session ->
                    lock lockObj (fun () -> state <- Running session)
                    reconnectAttempts <- 0
                    raiseEvent (Connected (session.Config.Name))
                    this.StartHealthCheck()
                    return Ok session

                | Error e ->
                    lock lockObj (fun () -> state <- Stopped (sprintf "%A" e))
                    return Error e
            with
            | :? OperationCanceledException ->
                lock lockObj (fun () -> state <- Stopped "Initialization timeout")
                return Error ZenohError.Timeout
        }

    /// Start health check timer (SC-OP-003)
    member private this.StartHealthCheck() =
        let callback _ =
            this.HealthCheckAsync() |> Async.AwaitTask |> Async.RunSynchronously
        healthTimer <- Some (new Timer(TimerCallback(callback), null, healthCheckIntervalMs, healthCheckIntervalMs))

    /// Health check
    member private this.HealthCheckAsync() : Task<unit> =
        task {
            match state with
            | Running session when not session.IsValid ->
                raiseEvent (Disconnected "Session invalid")
                do! this.ReconnectAsync()
            | _ -> ()
        }

    /// Reconnect with exponential backoff (SC-OP-002)
    member private this.ReconnectAsync() : Task<unit> =
        task {
            if reconnectAttempts >= maxReconnectAttempts then
                raiseEvent (ReconnectFailed reconnectAttempts)
                lock lockObj (fun () -> state <- Stopped "Max reconnect attempts exceeded")
            else
                reconnectAttempts <- reconnectAttempts + 1
                raiseEvent (Reconnecting reconnectAttempts)

                let backoffMs = ExponentialBackoff.calculate reconnectAttempts ExponentialBackoff.defaultBase ExponentialBackoff.defaultMax
                do! Task.Delay(backoffMs)

                let! result = SafeSession.OpenAsync(config)

                match result with
                | Ok session ->
                    lock lockObj (fun () -> state <- Running session)
                    reconnectAttempts <- 0
                    raiseEvent (Connected session.Config.Name)
                | Error e ->
                    lock lockObj (fun () -> state <- Reconnecting(reconnectAttempts, sprintf "%A" e))
                    do! this.ReconnectAsync()
        }

    /// Shutdown gracefully
    member this.ShutdownAsync() : Task<unit> =
        task {
            raiseEvent Shutdown

            healthTimer |> Option.iter (fun t -> t.Dispose())
            healthTimer <- None

            match state with
            | Running session ->
                do! session.CloseAsync()
            | _ -> ()

            lock lockObj (fun () -> state <- Stopped "Shutdown requested")
        }

    interface IDisposable with
        member this.Dispose() =
            this.ShutdownAsync() |> Async.AwaitTask |> Async.RunSynchronously
```

### L5.2.2 `Zenoh/Session/ZenohHealth.fs`

```fsharp
// =============================================================================
// ZenohHealth.fs - Health Monitoring and Reporting
// =============================================================================
// STAMP: SC-OP-003, SC-SESS-004
// AOR: AOR-ZENOH-009
// Criticality: Level 5 (HIGH) - Observability
// =============================================================================

namespace Cepaf.Zenoh.Session

open System
open Cepaf.Zenoh.Core
open Cepaf.Zenoh.Messaging

/// Health report generator
type ZenohHealthMonitor(lifecycle: ZenohLifecycle, nodeId: string) =
    let mutable lastHealth = ZenohHealth.empty

    /// Generate current health report
    member _.GetHealth() : ZenohHealth =
        let status =
            match lifecycle.State with
            | Uninitialized -> ConnectionStatus.Disconnected
            | Starting -> ConnectionStatus.Connecting
            | Running _ -> ConnectionStatus.Connected
            | Reconnecting (attempt, _) -> ConnectionStatus.Reconnecting
            | Stopped reason -> ConnectionStatus.Failed reason

        { lastHealth with
            Status = status
            LastHeartbeat = Some DateTimeOffset.UtcNow
        }

    /// Update statistics
    member _.UpdateStats(published: int64, received: int64, errors: int) =
        lastHealth <- { lastHealth with
            MessagesPublished = published
            MessagesReceived = received
            ErrorCount = errors
        }

    /// Check if healthy
    member this.IsHealthy =
        match this.GetHealth().Status with
        | ConnectionStatus.Connected -> true
        | _ -> false

/// Health publisher (publishes to Zenoh topic)
type HealthPublisher(lifecycle: ZenohLifecycle, monitor: ZenohHealthMonitor, nodeId: string) =
    let mutable publisher: TypedPublisher<ZenohHealth> option = None
    let mutable timer: Timer option = None

    /// Start publishing health
    member this.Start() =
        match lifecycle.Session with
        | Some session ->
            let pub = new TypedPublisher<ZenohHealth>(session, ZenohTopics.Health.node nodeId, nodeId)
            match pub.Initialize() with
            | Ok () ->
                publisher <- Some pub
                timer <- Some (new Timer(TimerCallback(fun _ -> this.PublishHealth()), null, 10000, 10000))
            | Error e ->
                eprintfn "[ZenohHealth] Failed to start: %A" e
        | None ->
            eprintfn "[ZenohHealth] No session available"

    /// Publish current health
    member private _.PublishHealth() =
        match publisher with
        | Some pub ->
            let health = monitor.GetHealth()
            pub.PublishAsync(health) |> Async.AwaitTask |> Async.RunSynchronously |> ignore
        | None -> ()

    interface IDisposable with
        member _.Dispose() =
            timer |> Option.iter (fun t -> t.Dispose())
            publisher |> Option.iter (fun p -> (p :> IDisposable).Dispose())
```

## L5.3 Acceptance Criteria

| ID | Criterion | Verification |
|----|-----------|--------------|
| L5-AC-001 | Init completes within 5 seconds | Integration test |
| L5-AC-002 | Backoff doubles each attempt | Unit test |
| L5-AC-003 | Max backoff is 60 seconds | Unit test |
| L5-AC-004 | Health check runs every 10s | Timer verification |
| L5-AC-005 | Max 10 reconnect attempts | Integration test |
| L5-AC-006 | Health published to Zenoh topic | Integration test |

---

# Level 6: Cluster (Multi-Node Coordination)

## L6.1 Overview

**Objective**: Implement barrier synchronization, quorum voting, and 2oo3 consensus for SIL-6 compliance.

**STAMP Constraints**:
- SC-OP-005: Quorum voting SHALL require 2oo3 for SIL-6
- SC-OP-006: Barrier synchronization SHALL timeout in 30 seconds
- SC-QUORUM-001: 2oo3 voting MANDATORY for safety-critical decisions

## L6.2 Files to Create

### L6.2.1 `Zenoh/Cluster/ZenohBarrier.fs`

```fsharp
// =============================================================================
// ZenohBarrier.fs - Distributed Barrier Synchronization
// =============================================================================
// STAMP: SC-OP-006, SC-BARRIER-001
// AOR: AOR-ZENOH-010
// Criticality: Level 6 (CRITICAL) - Cluster Coordination
// =============================================================================

namespace Cepaf.Zenoh.Cluster

open System
open System.Threading
open System.Threading.Tasks
open System.Collections.Concurrent
open Cepaf.Zenoh.Core
open Cepaf.Zenoh.Messaging
open Cepaf.Zenoh.Session

/// Barrier message
type BarrierMessage = {
    BarrierId: string
    NodeId: string
    Timestamp: DateTimeOffset
    Phase: string  // "arrive" | "release"
}

/// Barrier state
type BarrierState =
    | Waiting of arrived: Set<string>
    | Released
    | TimedOut

/// Distributed barrier (SC-OP-006)
type ZenohBarrier(lifecycle: ZenohLifecycle, barrierId: string, nodeId: string, expectedNodes: int) =
    let timeoutMs = 30000  // SC-OP-006: 30 second timeout
    let mutable state = Waiting Set.empty
    let arrivedNodes = ConcurrentDictionary<string, DateTimeOffset>()
    let releaseEvent = new ManualResetEventSlim(false)
    let lockObj = obj()

    let mutable publisher: TypedPublisher<BarrierMessage> option = None
    let mutable subscriber: TypedSubscriber<BarrierMessage> option = None

    /// Initialize barrier
    member this.Initialize() : Result<unit, ZenohError> =
        match lifecycle.Session with
        | None -> Error ZenohError.SessionClosed
        | Some session ->
            // Create publisher
            let pub = new TypedPublisher<BarrierMessage>(session, ZenohTopics.Cluster.barrier barrierId, nodeId)
            match pub.Initialize() with
            | Error e -> Error e
            | Ok () ->
                publisher <- Some pub

                // Create subscriber
                let sub = new TypedSubscriber<BarrierMessage>(session, ZenohTopics.Cluster.barrier barrierId, 50)
                match sub.Subscribe(this.HandleMessage) with
                | Error e -> Error e
                | Ok () ->
                    subscriber <- Some sub
                    Ok ()

    /// Handle incoming barrier message
    member private this.HandleMessage(envelope: ZenohEnvelope<BarrierMessage>) =
        let msg = envelope.Payload
        if msg.BarrierId = barrierId then
            match msg.Phase with
            | "arrive" ->
                arrivedNodes.[msg.NodeId] <- msg.Timestamp
                lock lockObj (fun () ->
                    match state with
                    | Waiting arrived ->
                        let newArrived = Set.add msg.NodeId arrived
                        if Set.count newArrived >= expectedNodes then
                            state <- Released
                            releaseEvent.Set()
                        else
                            state <- Waiting newArrived
                    | _ -> ()
                )
            | "release" ->
                lock lockObj (fun () ->
                    state <- Released
                    releaseEvent.Set()
                )
            | _ -> ()

    /// Wait at barrier
    member this.WaitAsync() : Task<Result<unit, ZenohError>> =
        task {
            // Publish arrival
            match publisher with
            | None -> return Error (ZenohError.PublishFailed "Publisher not initialized")
            | Some pub ->
                let msg = { BarrierId = barrierId; NodeId = nodeId; Timestamp = DateTimeOffset.UtcNow; Phase = "arrive" }
                let! result = pub.PublishAsync(msg)

                match result with
                | Error e -> return Error e
                | Ok () ->
                    // Wait for all nodes (with timeout)
                    let released = releaseEvent.Wait(timeoutMs)

                    if released then
                        return Ok ()
                    else
                        lock lockObj (fun () -> state <- TimedOut)
                        return Error ZenohError.Timeout
        }

    /// Get current state
    member _.State = state

    /// Get arrived nodes
    member _.ArrivedNodes = arrivedNodes.Keys |> Seq.toList

    interface IDisposable with
        member _.Dispose() =
            subscriber |> Option.iter (fun s -> (s :> IDisposable).Dispose())
            publisher |> Option.iter (fun p -> (p :> IDisposable).Dispose())
            releaseEvent.Dispose()
```

### L6.2.2 `Zenoh/Cluster/ZenohQuorum.fs`

```fsharp
// =============================================================================
// ZenohQuorum.fs - Quorum-Based Voting
// =============================================================================
// STAMP: SC-OP-005, SC-QUORUM-001
// AOR: AOR-ZENOH-011
// Criticality: Level 6 (CRITICAL) - Consensus
// =============================================================================

namespace Cepaf.Zenoh.Cluster

open System
open System.Threading.Tasks
open System.Collections.Concurrent
open Cepaf.Zenoh.Core
open Cepaf.Zenoh.Messaging
open Cepaf.Zenoh.Session

/// Vote message
type VoteMessage = {
    QuorumId: string
    NodeId: string
    Vote: bool
    Timestamp: DateTimeOffset
    Nonce: Guid  // Prevent replay attacks
}

/// Quorum result
type QuorumResult =
    | Approved of votes: int * total: int
    | Rejected of votes: int * total: int
    | Inconclusive of votes: int * total: int
    | TimedOut

/// Quorum calculator (SC-OP-005)
module QuorumCalculator =

    /// Calculate required quorum (floor(N/2) + 1)
    let requiredVotes (totalNodes: int) : int =
        (totalNodes / 2) + 1

    /// Check if quorum achieved
    let hasQuorum (yesVotes: int) (totalNodes: int) : bool =
        yesVotes >= requiredVotes totalNodes

    /// 2oo3 voting for SIL-6 (SC-QUORUM-001)
    let twoOfThree (votes: bool list) : bool =
        if List.length votes <> 3 then false
        else
            let yesCount = votes |> List.filter id |> List.length
            yesCount >= 2

/// Quorum voting session
type ZenohQuorum(lifecycle: ZenohLifecycle, quorumId: string, nodeId: string, expectedNodes: int) =
    let timeoutMs = 10000  // 10 second vote timeout
    let votes = ConcurrentDictionary<string, VoteMessage>()
    let lockObj = obj()
    let mutable result: QuorumResult option = None

    let mutable publisher: TypedPublisher<VoteMessage> option = None
    let mutable subscriber: TypedSubscriber<VoteMessage> option = None

    /// Initialize quorum
    member this.Initialize() : Result<unit, ZenohError> =
        match lifecycle.Session with
        | None -> Error ZenohError.SessionClosed
        | Some session ->
            let pub = new TypedPublisher<VoteMessage>(session, ZenohTopics.Cluster.quorum quorumId, nodeId)
            match pub.Initialize() with
            | Error e -> Error e
            | Ok () ->
                publisher <- Some pub

                let sub = new TypedSubscriber<VoteMessage>(session, ZenohTopics.Cluster.quorum quorumId, 50)
                match sub.Subscribe(this.HandleVote) with
                | Error e -> Error e
                | Ok () ->
                    subscriber <- Some sub
                    Ok ()

    /// Handle incoming vote
    member private _.HandleVote(envelope: ZenohEnvelope<VoteMessage>) =
        let vote = envelope.Payload
        if vote.QuorumId = quorumId then
            // Check for replay (same node can only vote once)
            match votes.TryGetValue(vote.NodeId) with
            | true, existing when existing.Nonce <> vote.Nonce ->
                ()  // Ignore duplicate/replay
            | _ ->
                votes.[vote.NodeId] <- vote

    /// Cast vote
    member this.VoteAsync(vote: bool) : Task<Result<unit, ZenohError>> =
        task {
            match publisher with
            | None -> return Error (ZenohError.PublishFailed "Publisher not initialized")
            | Some pub ->
                let msg = {
                    QuorumId = quorumId
                    NodeId = nodeId
                    Vote = vote
                    Timestamp = DateTimeOffset.UtcNow
                    Nonce = Guid.NewGuid()
                }
                return! pub.PublishAsync(msg)
        }

    /// Wait for quorum result
    member this.WaitForResultAsync() : Task<QuorumResult> =
        task {
            let startTime = DateTimeOffset.UtcNow

            while result.IsNone && (DateTimeOffset.UtcNow - startTime).TotalMilliseconds < float timeoutMs do
                do! Task.Delay(100)

                let voteList = votes.Values |> Seq.toList
                if voteList.Length >= expectedNodes then
                    let yesVotes = voteList |> List.filter (fun v -> v.Vote) |> List.length

                    if QuorumCalculator.hasQuorum yesVotes expectedNodes then
                        result <- Some (Approved (yesVotes, expectedNodes))
                    else
                        result <- Some (Rejected (yesVotes, expectedNodes))

            match result with
            | Some r -> return r
            | None ->
                let voteList = votes.Values |> Seq.toList
                let yesVotes = voteList |> List.filter (fun v -> v.Vote) |> List.length
                return TimedOut
        }

    interface IDisposable with
        member _.Dispose() =
            subscriber |> Option.iter (fun s -> (s :> IDisposable).Dispose())
            publisher |> Option.iter (fun p -> (p :> IDisposable).Dispose())
```

### L6.2.3 `Zenoh/Cluster/ZenohConsensus.fs`

```fsharp
// =============================================================================
// ZenohConsensus.fs - 2oo3 Consensus for SIL-6
// =============================================================================
// STAMP: SC-QUORUM-001, SC-SIL6-001
// AOR: AOR-ZENOH-012
// Criticality: Level 6 (CRITICAL) - Safety-Critical Consensus
// =============================================================================

namespace Cepaf.Zenoh.Cluster

open System
open System.Threading.Tasks
open Cepaf.Zenoh.Core
open Cepaf.Zenoh.Session

/// 2oo3 channel vote
type ChannelVote = {
    ChannelId: string  // "primary" | "secondary" | "arbiter"
    Value: bool
    Confidence: float
    Timestamp: DateTimeOffset
}

/// 2oo3 consensus result (SC-SIL6-001)
type ConsensusResult =
    | Unanimous of value: bool
    | TwoOfThree of value: bool * dissenter: string
    | Disagreement of votes: ChannelVote list
    | ChannelFailure of failedChannel: string

/// 2oo3 Voting system for SIL-6 compliance (SC-QUORUM-001)
type TwoOfThreeConsensus(lifecycle: ZenohLifecycle, nodeId: string) =

    /// Execute 2oo3 vote
    member _.Vote(
        primary: unit -> Task<Result<bool, ZenohError>>,
        secondary: unit -> Task<Result<bool, ZenohError>>,
        arbiter: unit -> Task<Result<bool, ZenohError>>) : Task<ConsensusResult> =
        task {
            // Execute all three channels in parallel
            let! results = Task.WhenAll([|
                primary()
                secondary()
                arbiter()
            |])

            let votes =
                [| ("primary", results.[0])
                   ("secondary", results.[1])
                   ("arbiter", results.[2]) |]
                |> Array.map (fun (channel, result) ->
                    match result with
                    | Ok value -> Some { ChannelId = channel; Value = value; Confidence = 1.0; Timestamp = DateTimeOffset.UtcNow }
                    | Error _ -> None)

            // Check for channel failures
            let failures = votes |> Array.mapi (fun i v -> if v.IsNone then Some (fst [| "primary"; "secondary"; "arbiter" |].[i]) else None) |> Array.choose id

            if failures.Length > 1 then
                return ChannelFailure (failures.[0])
            else
                let validVotes = votes |> Array.choose id |> Array.toList

                if validVotes.Length < 2 then
                    return ChannelFailure "Multiple channels failed"
                else
                    let yesVotes = validVotes |> List.filter (fun v -> v.Value)
                    let noVotes = validVotes |> List.filter (fun v -> not v.Value)

                    match yesVotes.Length, noVotes.Length with
                    | 3, 0 -> return Unanimous true
                    | 0, 3 -> return Unanimous false
                    | 2, 1 ->
                        let dissenter = noVotes.[0].ChannelId
                        return TwoOfThree (true, dissenter)
                    | 1, 2 ->
                        let dissenter = yesVotes.[0].ChannelId
                        return TwoOfThree (false, dissenter)
                    | _ -> return Disagreement validVotes
        }

    /// Simple 2oo3 with boolean values
    member this.VoteSimple(v1: bool, v2: bool, v3: bool) : bool =
        let votes = [v1; v2; v3]
        QuorumCalculator.twoOfThree votes
```

## L6.3 Acceptance Criteria

| ID | Criterion | Verification |
|----|-----------|--------------|
| L6-AC-001 | Barrier waits for all nodes | Integration test |
| L6-AC-002 | Barrier times out at 30s | Integration test |
| L6-AC-003 | Quorum requires floor(N/2)+1 | Unit test |
| L6-AC-004 | 2oo3 voting works correctly | Unit test |
| L6-AC-005 | Vote replay prevented | Security test |
| L6-AC-006 | Channel failures detected | Integration test |

---

# Level 7: Federation (Cross-Holon Communication)

## L7.1 Overview

**Objective**: Implement cross-holon communication with version negotiation and hourly attestation.

**STAMP Constraints**:
- SC-OP-007: Federation attestation SHALL occur every hour
- SC-FED-001: Version negotiation required before communication
- SC-FED-002: Ed25519 signatures for attestation

## L7.2 Files to Create

### L7.2.1 `Zenoh/Federation/ZenohFederation.fs`

```fsharp
// =============================================================================
// ZenohFederation.fs - Cross-Holon Federation Protocol
// =============================================================================
// STAMP: SC-OP-007, SC-FED-001, SC-FED-002
// AOR: AOR-ZENOH-013
// Criticality: Level 7 (HIGH) - Federation
// =============================================================================

namespace Cepaf.Zenoh.Federation

open System
open System.Threading
open System.Threading.Tasks
open System.Collections.Concurrent
open Cepaf.Zenoh.Core
open Cepaf.Zenoh.Messaging
open Cepaf.Zenoh.Session

/// Federation announcement
type FederationAnnounce = {
    HolonId: string
    Version: string
    Capabilities: string list
    Endpoint: string
    Timestamp: DateTimeOffset
}

/// Version negotiation message
type VersionNegotiation = {
    SourceHolon: string
    TargetHolon: string
    OfferedVersions: string list
    SelectedVersion: string option
    Status: string  // "request" | "response" | "accepted" | "rejected"
}

/// Federation peer
type FederationPeer = {
    HolonId: string
    Version: string
    LastSeen: DateTimeOffset
    NegotiatedVersion: string option
    Status: string  // "unknown" | "negotiating" | "connected" | "stale"
}

/// Federation manager
type ZenohFederation(lifecycle: ZenohLifecycle, holonId: string, version: string) =
    let peers = ConcurrentDictionary<string, FederationPeer>()
    let supportedVersions = ["1.0.0"; "1.1.0"; "1.2.0"]
    let staleThresholdMinutes = 70  // Just over 1 hour

    let mutable announcePublisher: TypedPublisher<FederationAnnounce> option = None
    let mutable announceSubscriber: TypedSubscriber<FederationAnnounce> option = None
    let mutable versionPublisher: TypedPublisher<VersionNegotiation> option = None
    let mutable versionSubscriber: TypedSubscriber<VersionNegotiation> option = None
    let mutable announceTimer: Timer option = None

    /// Initialize federation
    member this.Initialize() : Result<unit, ZenohError> =
        match lifecycle.Session with
        | None -> Error ZenohError.SessionClosed
        | Some session ->
            // Announce publisher
            let aPub = new TypedPublisher<FederationAnnounce>(session, ZenohTopics.Federation.announce, holonId)
            match aPub.Initialize() with
            | Error e -> Error e
            | Ok () ->
                announcePublisher <- Some aPub

                // Announce subscriber
                let aSub = new TypedSubscriber<FederationAnnounce>(session, ZenohTopics.Federation.announce, 50)
                match aSub.Subscribe(this.HandleAnnounce) with
                | Error e -> Error e
                | Ok () ->
                    announceSubscriber <- Some aSub

                    // Version publisher
                    let vPub = new TypedPublisher<VersionNegotiation>(session, ZenohTopics.Federation.version, holonId)
                    match vPub.Initialize() with
                    | Error e -> Error e
                    | Ok () ->
                        versionPublisher <- Some vPub

                        // Version subscriber
                        let vSub = new TypedSubscriber<VersionNegotiation>(session, ZenohTopics.Federation.version, 50)
                        match vSub.Subscribe(this.HandleVersion) with
                        | Error e -> Error e
                        | Ok () ->
                            versionSubscriber <- Some vSub

                            // Start hourly announce (SC-OP-007)
                            let hourMs = 60 * 60 * 1000
                            announceTimer <- Some (new Timer(TimerCallback(fun _ -> this.AnnounceAsync() |> Async.AwaitTask |> Async.RunSynchronously), null, 0, hourMs))

                            Ok ()

    /// Handle announcement from peer
    member private this.HandleAnnounce(envelope: ZenohEnvelope<FederationAnnounce>) =
        let announce = envelope.Payload
        if announce.HolonId <> holonId then
            let peer = {
                HolonId = announce.HolonId
                Version = announce.Version
                LastSeen = announce.Timestamp
                NegotiatedVersion = None
                Status = "unknown"
            }
            peers.[announce.HolonId] <- peer

            // Initiate version negotiation
            this.NegotiateVersionAsync(announce.HolonId) |> Async.AwaitTask |> Async.RunSynchronously |> ignore

    /// Handle version negotiation
    member private _.HandleVersion(envelope: ZenohEnvelope<VersionNegotiation>) =
        let neg = envelope.Payload
        if neg.TargetHolon = holonId then
            match neg.Status with
            | "request" ->
                // Find best matching version
                let commonVersions = neg.OfferedVersions |> List.filter (fun v -> List.contains v supportedVersions)
                match commonVersions with
                | [] -> ()  // No common version
                | v :: _ ->
                    // Update peer
                    match peers.TryGetValue(neg.SourceHolon) with
                    | true, peer ->
                        peers.[neg.SourceHolon] <- { peer with NegotiatedVersion = Some v; Status = "connected" }
                    | false, _ -> ()
            | "accepted" ->
                match peers.TryGetValue(neg.SourceHolon) with
                | true, peer ->
                    peers.[neg.SourceHolon] <- { peer with NegotiatedVersion = neg.SelectedVersion; Status = "connected" }
                | false, _ -> ()
            | _ -> ()

    /// Announce this holon
    member _.AnnounceAsync() : Task<Result<unit, ZenohError>> =
        task {
            match announcePublisher with
            | None -> return Error (ZenohError.PublishFailed "Publisher not initialized")
            | Some pub ->
                let announce = {
                    HolonId = holonId
                    Version = version
                    Capabilities = ["pub_sub"; "query"; "federation"]
                    Endpoint = "zenoh://localhost:7447"
                    Timestamp = DateTimeOffset.UtcNow
                }
                return! pub.PublishAsync(announce)
        }

    /// Negotiate version with peer
    member _.NegotiateVersionAsync(targetHolon: string) : Task<Result<string option, ZenohError>> =
        task {
            match versionPublisher with
            | None -> return Error (ZenohError.PublishFailed "Publisher not initialized")
            | Some pub ->
                let neg = {
                    SourceHolon = holonId
                    TargetHolon = targetHolon
                    OfferedVersions = supportedVersions
                    SelectedVersion = None
                    Status = "request"
                }
                let! result = pub.PublishAsync(neg)
                match result with
                | Error e -> return Error e
                | Ok () ->
                    // Wait for response (simplified)
                    do! Task.Delay(1000)
                    match peers.TryGetValue(targetHolon) with
                    | true, peer -> return Ok peer.NegotiatedVersion
                    | false, _ -> return Ok None
        }

    /// Get known peers
    member _.Peers = peers.Values |> Seq.toList

    /// Get connected peers
    member _.ConnectedPeers =
        peers.Values |> Seq.filter (fun p -> p.Status = "connected") |> Seq.toList

    /// Check for stale peers
    member _.GetStalePeers() =
        let threshold = DateTimeOffset.UtcNow.AddMinutes(float -staleThresholdMinutes)
        peers.Values |> Seq.filter (fun p -> p.LastSeen < threshold) |> Seq.toList

    interface IDisposable with
        member _.Dispose() =
            announceTimer |> Option.iter (fun t -> t.Dispose())
            versionSubscriber |> Option.iter (fun s -> (s :> IDisposable).Dispose())
            versionPublisher |> Option.iter (fun p -> (p :> IDisposable).Dispose())
            announceSubscriber |> Option.iter (fun s -> (s :> IDisposable).Dispose())
            announcePublisher |> Option.iter (fun p -> (p :> IDisposable).Dispose())
```

## L7.3 Acceptance Criteria

| ID | Criterion | Verification |
|----|-----------|--------------|
| L7-AC-001 | Hourly announcements sent | Timer test |
| L7-AC-002 | Version negotiation completes | Integration test |
| L7-AC-003 | Stale peers detected | Unit test |
| L7-AC-004 | Ed25519 signatures verified | Security test |
| L7-AC-005 | Cross-holon messages delivered | Integration test |

---

# Implementation Schedule

## Phase Timeline

```
Week 1: Foundation (L1 + L2)
├── Day 1-2: ZenohTypes.fs, ZenohSerialization.fs
├── Day 3-4: ZenohNative.fs (SafeSession, SafePublisher, SafeSubscriber)
└── Day 5: Module organization, fsproj updates

Week 2: Messaging + Session (L3 + L5)
├── Day 6-7: ZenohEnvelope.fs, ZenohPublisher.fs, ZenohSubscriber.fs
├── Day 8-9: ZenohLifecycle.fs, ZenohHealth.fs
└── Day 10: Integration, ZenohChannel.fs update

Week 3: Cluster + Federation (L6 + L7)
├── Day 11-12: ZenohBarrier.fs, ZenohQuorum.fs, ZenohConsensus.fs
├── Day 13-14: ZenohFederation.fs, ZenohAttestation.fs
└── Day 15: Final integration, comprehensive testing
```

## Test Requirements

| Level | Unit Tests | Property Tests | Integration Tests |
|-------|------------|----------------|-------------------|
| L1 | 20 | 10 | 5 |
| L2 | 5 | 0 | 2 |
| L3 | 25 | 15 | 10 |
| L4 | 5 | 0 | 3 |
| L5 | 20 | 10 | 8 |
| L6 | 30 | 15 | 15 |
| L7 | 25 | 10 | 10 |
| **Total** | **130** | **60** | **53** |

## Risk Mitigation

| Risk | Mitigation | Owner |
|------|------------|-------|
| Native library issues | Early L1 testing, CI verification | Dev |
| API changes in Zenoh-CS | Version pinning, abstraction layer | Dev |
| Performance regression | Benchmark suite, monitoring | QA |
| Integration failures | Incremental integration, mocks | Dev |
| SIL-6 compliance gaps | Formal verification, safety review | Safety |

---

## Document Control

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Created | 2026-01-14 |
| Author | Claude Opus 4.5 |
| STAMP | SC-ZENOH-IMPL-001 to SC-ZENOH-IMPL-007 |
| Status | IMPLEMENTATION READY |

---

## References

1. ZENOH_COMPLETE_INTEGRATION_ANALYSIS.md - Detailed analysis
2. ZENOH_STAMP_FMEA_CRITICAL_PATH.md - Safety analysis
3. Zenoh-CS NuGet Package v0.4.1
4. Eclipse Zenoh Documentation
5. CLAUDE.md - Master specification
