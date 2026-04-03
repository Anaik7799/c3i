# Zenoh Complete Integration Analysis: 7-Level + 10x10 Matrix + SIL-6

**Version**: 2.0.0 | **Date**: 2026-01-14 | **STAMP**: SC-ZENOH-COMPLETE-001
**Author**: Claude Opus 4.5 | **Status**: PLANNING | **Compliance**: SIL-6 Biomorphic

---

## Executive Summary

This document provides a comprehensive analysis for integrating the Eclipse Zenoh pub/sub messaging system with the F# CEPAF codebase at SIL-6 safety level, including:
- **7-Level Fractal Analysis** (L1-L7: Function → Federation)
- **10x10 Component Matrix** (100 integration points)
- **SIL-6 Safety Requirements** (PFH < 10⁻¹², 2oo3 voting, deterministic behavior)

---

## Part I: Zenoh Architecture Deep Dive

### 1.1 Core Architecture Components

Based on [eclipse-zenoh/zenoh](https://github.com/eclipse-zenoh/zenoh):

```
┌─────────────────────────────────────────────────────────────────────┐
│                        ZENOH ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │
│  │   zenoh     │  │  zenoh-ext  │  │   zenohd    │                 │
│  │   (core)    │  │ (extensions)│  │  (router)   │                 │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                 │
│         │                │                │                         │
│         └────────────────┼────────────────┘                         │
│                          │                                          │
│  ┌───────────────────────┴───────────────────────┐                 │
│  │              zenoh-c (C bindings)             │                 │
│  │    Memory: owned/loaned/moved/view types      │                 │
│  │    Thread-safe: Arc<Session>                  │                 │
│  └───────────────────────┬───────────────────────┘                 │
│                          │                                          │
│  ┌───────────────────────┴───────────────────────┐                 │
│  │           Zenoh-CS (NuGet 0.4.1)              │                 │
│  │    Target: .NET Standard 2.0                  │                 │
│  │    Requires: zenoh-c v1.6.2 native lib        │                 │
│  └───────────────────────────────────────────────┘                 │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Zenoh Core Concepts

| Concept | Description | F# Mapping |
|---------|-------------|------------|
| **Session** | Connection to Zenoh network | `ZenohSession` module |
| **KeyExpr** | Hierarchical key expression (e.g., `a/b/**`) | `string` with validation |
| **Publisher** | Named data producer | `ZenohPublisher` type |
| **Subscriber** | Named data consumer with callback | `ZenohSubscriber` type |
| **Sample** | Published data with metadata | `ZenohMessage` record |
| **Queryable** | Request-response handler | `ZenohQueryable` type |
| **Get** | Ad-hoc query operation | `getAsync` function |

### 1.3 zenoh-ext Advanced Features

From [zenoh-ext](https://github.com/eclipse-zenoh/zenoh/tree/main/zenoh-ext):

| Feature | Purpose | SIL-6 Relevance |
|---------|---------|-----------------|
| **AdvancedPublisher** | Caching, miss detection, heartbeat | Reliability guarantees |
| **AdvancedSubscriber** | History retrieval, recovery | Data integrity |
| **Sample Miss Detection** | Heartbeat-based gap detection | Loss detection |
| **Serialization** | Compact binary format | Cross-language safety |

### 1.4 Memory Management Patterns (zenoh-c)

From [zenoh-c docs](https://zenoh-c.readthedocs.io/):

```c
// Ownership semantics (critical for FFI safety)
z_owned_session_t    // Full ownership - must z_drop()
z_loaned_session_t   // Borrowed reference - no drop
z_moved_session_t    // Transfer ownership - consumed
z_view_keyexpr_t     // Non-owning read-only view
```

**F# Safety Mapping**:
```fsharp
// F# safe wrappers
type OwnedSession = private { Handle: nativeint; mutable Disposed: bool }
type LoanedSession = private { Handle: nativeint }  // No IDisposable

// Safe disposal pattern
interface IDisposable with
    member this.Dispose() =
        if not this.Disposed then
            z_drop(this.Handle)
            this.Disposed <- true
```

---

## Part II: 7-Level Fractal Integration Analysis

### Level 1: Function (FFI Bindings)

#### 1.1 Current State
- `ZenohSession.fs`: Simulated with `Async.Sleep`
- No actual Zenoh-CS calls
- Console logging placeholders

#### 1.2 Target State

```fsharp
// Core FFI wrapper module
module ZenohNative =
    open Zenoh  // From Zenoh-CS NuGet

    /// Safe session wrapper with IDisposable
    type SafeSession = {
        Session: Session
        mutable IsDisposed: bool
    }
    interface IDisposable with
        member this.Dispose() =
            if not this.IsDisposed then
                this.Session.Close()
                this.IsDisposed <- true

    /// Open session with config
    let openSession (config: Config) : Result<SafeSession, string> =
        try
            let session = Session.Open(config)
            Ok { Session = session; IsDisposed = false }
        with ex ->
            Error (sprintf "Session open failed: %s" ex.Message)

    /// Declare publisher
    let declarePublisher (session: SafeSession) (keyExpr: string) : Result<Publisher, string> =
        try
            let ke = KeyExpr.TryFrom(keyExpr)
            match ke with
            | Some k -> Ok (session.Session.DeclarePublisher(k).Res())
            | None -> Error (sprintf "Invalid key expression: %s" keyExpr)
        with ex ->
            Error ex.Message

    /// Declare subscriber with callback
    let declareSubscriber (session: SafeSession) (keyExpr: string) (callback: Sample -> unit) =
        try
            let ke = KeyExpr.TryFrom(keyExpr) |> Option.get
            let sub = session.Session.DeclareSubscriber(ke)
                        .Callback(Action<Sample>(callback))
                        .Res()
            Ok sub
        with ex ->
            Error ex.Message
```

#### 1.3 STAMP Constraints (L1)

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-L1-FFI-001 | All FFI calls wrapped in try/catch | Result<'T, string> return |
| SC-L1-FFI-002 | Null checks for all Zenoh objects | Option type wrapping |
| SC-L1-FFI-003 | IDisposable for owned resources | SafeSession pattern |
| SC-L1-FFI-004 | KeyExpr validation before use | TryFrom with error handling |
| SC-L1-FFI-005 | Thread-safe session access | lock pattern or Actor |

#### 1.4 Risk Analysis (FMEA - L1)

| Failure Mode | S | O | D | RPN | Mitigation |
|--------------|---|---|---|-----|------------|
| Native lib missing | 9 | 4 | 7 | 252 | NuGet postbuild copy |
| Session leak | 8 | 3 | 5 | 120 | IDisposable + finalizer |
| KeyExpr parse fail | 6 | 5 | 3 | 90 | Pre-validation |
| Callback exception | 7 | 4 | 4 | 112 | try/catch in callback |
| Thread race | 8 | 3 | 6 | 144 | MailboxProcessor |

---

### Level 2: Component (Module Organization)

#### 2.1 Current Structure
```
lib/cepaf/src/Cepaf/Zenoh/
├── ZenohSession.fs      # Simulated
├── ZenohChannel.fs      # Uses simulated session
└── KmsSubscriber.fs     # Placeholder
```

#### 2.2 Target Structure
```
lib/cepaf/src/Cepaf/Zenoh/
├── Core/
│   ├── ZenohNative.fs       # FFI wrappers (SafeSession, etc.)
│   ├── ZenohTypes.fs        # F# domain types
│   └── ZenohConfig.fs       # Configuration management
├── Session/
│   ├── ZenohSession.fs      # High-level session API
│   ├── ZenohReconnect.fs    # Exponential backoff reconnection
│   └── ZenohHealth.fs       # Health monitoring
├── PubSub/
│   ├── ZenohPublisher.fs    # Typed publisher abstraction
│   ├── ZenohSubscriber.fs   # Typed subscriber abstraction
│   └── ZenohChannel.fs      # QuadplexLogger integration
├── Query/
│   ├── ZenohQueryable.fs    # Request handler
│   └── ZenohGet.fs          # Query operations
├── Advanced/
│   ├── ZenohAdvancedPub.fs  # zenoh-ext AdvancedPublisher
│   └── ZenohMissDetect.fs   # Sample miss detection
└── Integration/
    ├── KmsSubscriber.fs     # KMS state subscription
    ├── FractalPublisher.fs  # Fractal telemetry
    └── ControlBus.fs        # Control plane messaging
```

#### 2.3 STAMP Constraints (L2)

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-L2-MOD-001 | Core has no external deps except Zenoh-CS | Package isolation |
| SC-L2-MOD-002 | Layered architecture (Core→Session→PubSub→Integration) | fsproj compile order |
| SC-L2-MOD-003 | No circular dependencies | Module dependency graph |
| SC-L2-MOD-004 | Public API surface minimized | Internal modules |

---

### Level 3: Holon (Agent Communication)

#### 3.1 Message Envelope Design

```fsharp
/// Universal message envelope for all Zenoh communication
/// SC-L3-MSG-001: All messages MUST use this envelope
type ZenohEnvelope<'T> = {
    /// Message payload
    Payload: 'T
    /// ISO 8601 timestamp
    Timestamp: DateTimeOffset
    /// W3C trace context - trace ID
    TraceId: string option
    /// W3C trace context - span ID
    SpanId: string option
    /// Source identifier (e.g., "cepaf-planning")
    Source: string
    /// Schema version for evolution
    Version: string
    /// Message type discriminator
    MessageType: string
    /// Correlation ID for request-response
    CorrelationId: string option
}

/// Create envelope with tracing
let createEnvelope<'T> (payload: 'T) (msgType: string) : ZenohEnvelope<'T> =
    {
        Payload = payload
        Timestamp = DateTimeOffset.UtcNow
        TraceId = Activity.Current |> Option.ofObj |> Option.map (fun a -> a.TraceId.ToString())
        SpanId = Activity.Current |> Option.ofObj |> Option.map (fun a -> a.SpanId.ToString())
        Source = Environment.MachineName
        Version = "1.0.0"
        MessageType = msgType
        CorrelationId = None
    }
```

#### 3.2 Topic Schema (Key Expressions)

```fsharp
/// Centralized topic definitions
/// SC-L3-KEY-001: All topics MUST be defined here
module ZenohTopics =
    // Fractal telemetry plane
    let fractalL1 = "indrajaal/fractal/l1/**"
    let fractalL2 = "indrajaal/fractal/l2/**"
    let fractalL3 = "indrajaal/fractal/l3/**"
    let fractalL4 = "indrajaal/fractal/l4/**"
    let fractalL5 = "indrajaal/fractal/l5/**"
    let fractalAll = "indrajaal/fractal/**"

    // Telemetry plane
    let telemetryElixir = "indrajaal/telemetry/elixir/**"
    let telemetryFsharp = "indrajaal/telemetry/fsharp/**"

    // Control plane
    let controlRefresh = "indrajaal/control/refresh"
    let controlEmergency = "indrajaal/control/emergency"
    let controlResponse = "indrajaal/control/response/**"

    // Coordination plane (cluster)
    let coordHeartbeat = "indrajaal/coord/heartbeat"
    let coordSync = "indrajaal/coord/sync"
    let coordBarrier name = sprintf "indrajaal/coord/barrier/%s" name
    let coordQuorum topic = sprintf "indrajaal/coord/quorum/%s" topic

    // Federation plane
    let fedAnnounce = "indrajaal/federation/announce"
    let fedNegotiate holonId = sprintf "indrajaal/federation/%s/negotiate" holonId
    let fedAttestation = "indrajaal/federation/attestation"

    // Planning domain
    let planningEvents = "indrajaal/planning/events"
    let planningTasks = "indrajaal/planning/tasks/**"
    let planningOoda = "indrajaal/planning/ooda"

    // KMS state
    let kmsState = "indrajaal/kms/state"
    let kmsCheckpoint = "indrajaal/kms/checkpoint"

    // Container agents
    let containerHealth name = sprintf "indrajaal/container/%s/health" name
    let containerMetrics name = sprintf "indrajaal/container/%s/metrics" name
    let containerControl name = sprintf "indrajaal/container/%s/control" name
```

#### 3.3 STAMP Constraints (L3)

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-L3-MSG-001 | All messages use ZenohEnvelope | Type system enforcement |
| SC-L3-MSG-002 | JSON serialization with snake_case | JsonNamingPolicy.SnakeCaseLower |
| SC-L3-MSG-003 | Version field mandatory | Record structure |
| SC-L3-MSG-004 | TraceId propagation for distributed tracing | Activity.Current |
| SC-L3-KEY-001 | Topics defined in ZenohTopics module | Centralized constants |
| SC-L3-KEY-002 | No ad-hoc key strings | Compile-time enforcement |

---

### Level 4: Container (Package Dependencies)

#### 4.1 Required Package Changes

**Cepaf.fsproj** - ADD:
```xml
<PackageReference Include="Zenoh-CS" Version="0.4.1" />
```

**Native Library Deployment**:
```xml
<!-- Ensure zenoh-c native library is deployed -->
<ItemGroup>
  <None Include="$(NuGetPackageRoot)zenoh-cs/0.4.1/runtimes/linux-x64/native/*.so"
        CopyToOutputDirectory="PreserveNewest"
        Condition="'$(RuntimeIdentifier)' == 'linux-x64'" />
  <None Include="$(NuGetPackageRoot)zenoh-cs/0.4.1/runtimes/win-x64/native/*.dll"
        CopyToOutputDirectory="PreserveNewest"
        Condition="'$(RuntimeIdentifier)' == 'win-x64'" />
</ItemGroup>
```

#### 4.2 STAMP Constraints (L4)

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-L4-PKG-001 | Zenoh-CS version = 0.4.1 (match Cortex) | Explicit version pin |
| SC-L4-PKG-002 | Native lib deployment verified | Postbuild check |
| SC-L4-PKG-003 | .NET 10.0 target framework | fsproj TargetFramework |
| SC-L4-PKG-004 | No transitive conflicts | NuGet audit |

---

### Level 5: Node (Runtime Initialization)

#### 5.1 Lifecycle Management

```fsharp
/// Zenoh lifecycle manager with SIL-6 health monitoring
module ZenohLifecycle =
    open System.Timers

    let private mutable session: SafeSession option = None
    let private mutable healthTimer: Timer option = None
    let private mutable reconnectAttempts = 0
    let private maxReconnectAttempts = 10
    let private baseReconnectDelayMs = 1000

    /// Initialize with exponential backoff reconnection
    let initializeAsync (config: SessionConfig) = async {
        try
            // SC-L5-INIT-001: Validate router reachable before connect
            let! routerReachable = checkRouterReachable config.Endpoints
            if not routerReachable then
                return Error "Zenoh router not reachable"
            else
                let zenohConfig = Config.Default()
                for endpoint in config.Endpoints do
                    zenohConfig.Connect(endpoint) |> ignore

                match ZenohNative.openSession zenohConfig with
                | Ok s ->
                    session <- Some s
                    reconnectAttempts <- 0

                    // Start health check timer (SC-L5-HEALTH-001)
                    let timer = new Timer(10000.0)  // 10 second interval
                    timer.Elapsed.Add(fun _ -> healthCheck())
                    timer.Start()
                    healthTimer <- Some timer

                    return Ok ()
                | Error e ->
                    return Error e
        with ex ->
            return Error ex.Message
    }

    /// Health check with automatic reconnection
    let private healthCheck () =
        match session with
        | Some s when not s.IsDisposed ->
            try
                // Publish heartbeat to detect connectivity
                let heartbeat = {| timestamp = DateTimeOffset.UtcNow.ToString("o"); node = Environment.MachineName |}
                ZenohSession.publishJson ZenohTopics.coordHeartbeat (serialize heartbeat) |> ignore
            with _ ->
                // Connection lost - trigger reconnect
                reconnectAsync() |> Async.Start
        | _ -> ()

    /// Exponential backoff reconnection
    let private reconnectAsync () = async {
        if reconnectAttempts >= maxReconnectAttempts then
            // SC-L5-FAIL-001: Alert on max reconnects
            publishAlert "zenoh_reconnect_exhausted" |> ignore
        else
            reconnectAttempts <- reconnectAttempts + 1
            let delay = baseReconnectDelayMs * (pown 2 reconnectAttempts)
            do! Async.Sleep(min delay 60000)  // Max 60 seconds

            match sessionState with
            | Some config ->
                let! result = initializeAsync config
                match result with
                | Ok () -> reconnectAttempts <- 0
                | Error _ -> () // Will retry on next health check
            | None -> ()
    }

    /// Graceful shutdown
    let shutdown () =
        healthTimer |> Option.iter (fun t -> t.Stop(); t.Dispose())
        session |> Option.iter (fun s -> (s :> IDisposable).Dispose())
        session <- None
```

#### 5.2 STAMP Constraints (L5)

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-L5-INIT-001 | Router reachability check before connect | Pre-connect validation |
| SC-L5-INIT-002 | Session singleton pattern | Module-level mutable |
| SC-L5-HEALTH-001 | Health check every 10 seconds | Timer-based heartbeat |
| SC-L5-HEALTH-002 | Health in /health endpoint | JSON status exposure |
| SC-L5-RECON-001 | Exponential backoff (1s, 2s, 4s, ..., 60s max) | Capped exponential |
| SC-L5-RECON-002 | Max 10 reconnect attempts before alert | Counter + alert |
| SC-L5-FAIL-001 | Alert on reconnect exhaustion | Telemetry publish |

---

### Level 6: Cluster (Multi-Node Coordination)

#### 6.1 Distributed Barrier Implementation

```fsharp
/// Distributed barrier using Zenoh pub/sub
/// SC-L6-BARRIER-001: Zenoh-backed distributed synchronization
module ZenohDistributedBarrier =

    type BarrierState = {
        Name: string
        RequiredCount: int
        Participants: Set<string>
        StartTime: DateTimeOffset
    }

    let private barriers = ConcurrentDictionary<string, BarrierState>()

    /// Wait at barrier until required participants join
    let barrierAsync (name: string) (count: int) (nodeId: string) (timeoutMs: int) = async {
        let topic = ZenohTopics.coordBarrier name

        // Initialize barrier state
        let state = barriers.GetOrAdd(name, fun _ -> {
            Name = name
            RequiredCount = count
            Participants = Set.empty
            StartTime = DateTimeOffset.UtcNow
        })

        // Subscribe to barrier topic
        let mutable participants = state.Participants
        let subResult = ZenohSession.subscribe topic (fun msg ->
            let evt = deserialize<{| event: string; node: string |}> msg.Payload
            if evt.event = "join" then
                participants <- participants.Add(evt.node)
        )

        match subResult with
        | Error e -> return Error e
        | Ok subId ->
            // Publish join message
            let joinMsg = {| event = "join"; node = nodeId; barrier = name |}
            ZenohSession.publishJson topic (serialize joinMsg) |> ignore

            // Wait for all participants
            let deadline = DateTimeOffset.UtcNow.AddMilliseconds(float timeoutMs)
            while Set.count participants < count && DateTimeOffset.UtcNow < deadline do
                do! Async.Sleep(100)

            // Cleanup
            ZenohSession.unsubscribe subId |> ignore
            barriers.TryRemove(name) |> ignore

            if Set.count participants >= count then
                return Ok participants
            else
                return Error (sprintf "Barrier timeout: %d/%d participants" (Set.count participants) count)
    }
```

#### 6.2 Quorum Voting (2oo3 for SIL-6)

```fsharp
/// Quorum voting using Zenoh for SIL-6 2oo3 compliance
/// SC-SIL6-006: 2oo3 voting MANDATORY
module ZenohQuorumVoting =

    type Vote = {
        NodeId: string
        Value: bool
        Timestamp: DateTimeOffset
        Signature: byte[] option  // Ed25519 for SIL-6
    }

    type QuorumResult = {
        Achieved: bool
        YesVotes: int
        NoVotes: int
        TotalVotes: int
        QuorumSize: int
    }

    /// Calculate quorum size: floor(N/2) + 1
    let calculateQuorumSize (totalNodes: int) =
        (totalNodes / 2) + 1

    /// Conduct quorum vote
    let voteAsync (topic: string) (vote: bool) (nodeId: string) (totalNodes: int) (timeoutMs: int) = async {
        let quorumTopic = ZenohTopics.coordQuorum topic
        let quorumSize = calculateQuorumSize totalNodes

        // Collect votes
        let mutable votes = Map.empty<string, Vote>

        let subResult = ZenohSession.subscribe quorumTopic (fun msg ->
            let v = deserialize<Vote> msg.Payload
            votes <- votes.Add(v.NodeId, v)
        )

        match subResult with
        | Error e -> return Error e
        | Ok subId ->
            // Publish our vote
            let myVote = {
                NodeId = nodeId
                Value = vote
                Timestamp = DateTimeOffset.UtcNow
                Signature = None  // TODO: Ed25519 signing
            }
            ZenohSession.publishJson quorumTopic (serialize myVote) |> ignore

            // Wait for votes
            do! Async.Sleep(timeoutMs)
            ZenohSession.unsubscribe subId |> ignore

            let yesVotes = votes |> Map.filter (fun _ v -> v.Value) |> Map.count
            let noVotes = votes |> Map.filter (fun _ v -> not v.Value) |> Map.count

            return Ok {
                Achieved = yesVotes >= quorumSize
                YesVotes = yesVotes
                NoVotes = noVotes
                TotalVotes = Map.count votes
                QuorumSize = quorumSize
            }
    }

    /// 2oo3 voting for critical decisions (SIL-6)
    let twoOutOfThreeVote (topic: string) (vote: bool) (nodeId: string) = async {
        return! voteAsync topic vote nodeId 3 5000
    }
```

#### 6.3 STAMP Constraints (L6)

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-L6-BARRIER-001 | Distributed barriers via Zenoh | Pub/sub coordination |
| SC-L6-BARRIER-002 | Timeout on barrier wait | Deadline-based loop |
| SC-L6-QUORUM-001 | Quorum = floor(N/2)+1 | calculateQuorumSize |
| SC-L6-QUORUM-002 | 2oo3 voting for SIL-6 | twoOutOfThreeVote |
| SC-L6-VOTE-001 | Vote messages signed (Ed25519) | Signature field |

---

### Level 7: Federation (Cross-Holon Communication)

#### 7.1 Federation Protocol

```fsharp
/// Federation protocol for cross-holon communication
/// SC-L7-FED-001: Version negotiation required
module ZenohFederation =

    type HolonCapability =
        | PubSub
        | Query
        | Storage
        | Compute
        | AI

    type FederationAnnouncement = {
        HolonId: string
        Version: string
        Capabilities: HolonCapability list
        Endpoints: string list
        Timestamp: DateTimeOffset
    }

    type VersionNegotiationRequest = {
        SourceHolon: string
        TargetHolon: string
        MinVersion: string
        MaxVersion: string
        ResponseTopic: string
    }

    type StateAttestation = {
        HolonId: string
        StateHash: string  // SHA3-256
        BlockHeight: int64
        Timestamp: DateTimeOffset
        Signature: byte[]  // Ed25519
    }

    /// Announce holon to federation
    let announceAsync (holonId: string) (version: string) (caps: HolonCapability list) = async {
        let announcement = {
            HolonId = holonId
            Version = version
            Capabilities = caps
            Endpoints = ZenohSession.getEndpoints()
            Timestamp = DateTimeOffset.UtcNow
        }
        return ZenohSession.publishJson ZenohTopics.fedAnnounce (serialize announcement)
    }

    /// Negotiate protocol version with peer holon
    let negotiateVersionAsync (targetHolon: string) (minVer: string) (maxVer: string) = async {
        let responseId = Guid.NewGuid().ToString("N")
        let responseTopic = sprintf "indrajaal/federation/%s/negotiate/response/%s" targetHolon responseId

        let mutable result: string option = None

        // Subscribe to response
        let subResult = ZenohSession.subscribe responseTopic (fun msg ->
            result <- Some (Text.Encoding.UTF8.GetString(msg.Payload))
        )

        match subResult with
        | Error e -> return Error e
        | Ok subId ->
            // Send negotiation request
            let request = {
                SourceHolon = Environment.MachineName
                TargetHolon = targetHolon
                MinVersion = minVer
                MaxVersion = maxVer
                ResponseTopic = responseTopic
            }
            ZenohSession.publishJson (ZenohTopics.fedNegotiate targetHolon) (serialize request) |> ignore

            // Wait for response
            do! Async.Sleep(5000)
            ZenohSession.unsubscribe subId |> ignore

            match result with
            | Some v -> return Ok v
            | None -> return Error "Version negotiation timeout"
    }

    /// Attest holon state to federation (SC-REG-012: hourly)
    let attestStateAsync (holonId: string) (stateHash: string) (blockHeight: int64) = async {
        let attestation = {
            HolonId = holonId
            StateHash = stateHash
            BlockHeight = blockHeight
            Timestamp = DateTimeOffset.UtcNow
            Signature = [||]  // TODO: Ed25519 sign
        }
        return ZenohSession.publishJson ZenohTopics.fedAttestation (serialize attestation)
    }
```

#### 7.2 STAMP Constraints (L7)

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-L7-FED-001 | Version negotiation before communication | negotiateVersionAsync |
| SC-L7-FED-002 | Hourly state attestation | Timer-based attestStateAsync |
| SC-L7-FED-003 | Ed25519 signatures for attestations | Signature field |
| SC-L7-FED-004 | SHA3-256 for state hashes | stateHash format |

---

## Part III: 10x10 Detailed Analysis Matrix

### 3.1 Matrix Definition

The 10x10 matrix covers integration points between:

**Rows (Zenoh Components)**:
1. Session
2. Publisher
3. Subscriber
4. KeyExpr
5. Sample
6. Query/Get
7. Queryable
8. Config
9. AdvancedPub (zenoh-ext)
10. AdvancedSub (zenoh-ext)

**Columns (F# Integration Aspects)**:
1. Type Safety
2. Memory Management
3. Error Handling
4. Async/Concurrency
5. Serialization
6. Telemetry
7. Health Monitoring
8. SIL-6 Compliance
9. Testing
10. Documentation

### 3.2 Complete 10x10 Matrix

| | Type Safety | Memory Mgmt | Error Handling | Async | Serialization | Telemetry | Health | SIL-6 | Testing | Docs |
|---|---|---|---|---|---|---|---|---|---|---|
| **Session** | SafeSession record | IDisposable | Result<_,string> | Async.AwaitTask | N/A | Connection state | Heartbeat | Singleton | Unit+Integration | API docs |
| **Publisher** | TypedPublisher<'T> | Owned lifetime | Result monad | Task.Run fallback | JSON+Binary | Publish count | Latency | Deterministic | Property tests | Examples |
| **Subscriber** | TypedSubscriber<'T> | Callback ref | Exception handler | MailboxProcessor | Auto-deserialize | Receive count | Miss detect | Callback timeout | Mock handler | Topic guide |
| **KeyExpr** | Validated string | View type safe | TryFrom pattern | N/A | ToString | Key hit/miss | N/A | Static keys | Validation tests | Schema docs |
| **Sample** | ZenohMessage record | Payload copy | Null checks | Async handler | Payload decode | Sample metrics | N/A | Timestamp valid | Round-trip | Format spec |
| **Query/Get** | Reply<'T> type | Response cleanup | Timeout handling | Async timeout | Response decode | Query latency | N/A | Bounded wait | Query tests | Usage guide |
| **Queryable** | Handler<'Q,'R> | Handler lifetime | Reply errors | Concurrent handlers | Request decode | Handler metrics | Handler health | Deterministic reply | Handler tests | Request spec |
| **Config** | SessionConfig record | Immutable | Validation | N/A | JSON5 parse | Config changes | Config valid | Frozen config | Config tests | Config ref |
| **AdvancedPub** | CachedPublisher<'T> | Cache cleanup | Cache overflow | Batch async | Cached serialize | Cache hits | Heartbeat | Cache bounded | Cache tests | Cache guide |
| **AdvancedSub** | RecoverableSub<'T> | History buffer | Recovery errors | Recovery async | History decode | Recovery count | Miss listener | Recovery SLA | Recovery tests | Recovery docs |

### 3.3 Detailed Cell Analysis (Selected Critical Cells)

#### Cell [Session, SIL-6]: Safety-Critical Session Management

```fsharp
/// SIL-6 compliant session with deterministic behavior
/// SC-SIL6-SESSION-001: Bounded initialization time
/// SC-SIL6-SESSION-002: Deterministic cleanup
module SIL6Session =
    let private initTimeoutMs = 5000  // Bounded init
    let private cleanupTimeoutMs = 1000  // Bounded cleanup

    let initializeSIL6 (config: SessionConfig) = async {
        use cts = new CancellationTokenSource(initTimeoutMs)
        try
            let! result = Async.StartAsTask(initializeAsync config, cancellationToken = cts.Token) |> Async.AwaitTask
            return result
        with
        | :? OperationCanceledException ->
            return Error "Session init timeout (SIL-6 bounded)"
    }

    let shutdownSIL6 () =
        use cts = new CancellationTokenSource(cleanupTimeoutMs)
        try
            Task.Run((fun () -> shutdown()), cts.Token).Wait()
        with _ ->
            // Force cleanup on timeout
            forceCleanup()
```

#### Cell [Subscriber, Callback timeout]: Bounded Callback Execution

```fsharp
/// SIL-6 bounded callback execution
/// SC-SIL6-CALLBACK-001: Callback timeout enforcement
let subscribeSIL6<'T> (keyExpr: string) (handler: 'T -> unit) (timeoutMs: int) =
    let boundedHandler (msg: ZenohMessage) =
        use cts = new CancellationTokenSource(timeoutMs)
        try
            let task = Task.Run((fun () ->
                let payload = deserialize<'T> msg.Payload
                handler payload
            ), cts.Token)
            task.Wait()
        with
        | :? OperationCanceledException ->
            // Log timeout violation
            publishTelemetry "callback_timeout" {| key = keyExpr; timeout_ms = timeoutMs |}
        | ex ->
            // Log handler error
            publishTelemetry "callback_error" {| key = keyExpr; error = ex.Message |}

    ZenohSession.subscribe keyExpr boundedHandler
```

#### Cell [AdvancedPub, Cache bounded]: Bounded Cache for SIL-6

```fsharp
/// Bounded cache publisher for SIL-6 memory safety
/// SC-SIL6-CACHE-001: Cache size bounded
/// SC-SIL6-CACHE-002: Cache eviction deterministic
module BoundedCachePublisher =
    let private maxCacheSize = 1000  // Hard limit

    type CacheConfig = {
        MaxSize: int
        EvictionPolicy: string  // "LRU" | "FIFO"
        TTLSeconds: int option
    }

    let defaultConfig = {
        MaxSize = maxCacheSize
        EvictionPolicy = "LRU"
        TTLSeconds = Some 300
    }

    let createBoundedCache<'T> (config: CacheConfig) =
        if config.MaxSize > maxCacheSize then
            Error (sprintf "Cache size %d exceeds SIL-6 limit %d" config.MaxSize maxCacheSize)
        else
            Ok (ConcurrentDictionary<string, 'T * DateTimeOffset>(config.MaxSize))
```

---

## Part IV: SIL-6 Safety Integration Requirements

### 4.1 SIL-6 Probability Targets

| Metric | SIL-6 Biomorphic Requirement | SIL-6 Target |
|--------|-------------------|--------------|
| PFH (Probability of Failure/Hour) | < 10⁻⁸ | < 10⁻¹² |
| Diagnostic Coverage | ≥ 99% | ≥ 99.99% |
| Safe Failure Fraction | ≥ 99% | ≥ 99.99% |
| Hardware Fault Tolerance | 1 | 2 |

### 4.2 SIL-6 STAMP Constraints for Zenoh Integration

| ID | Constraint | Severity | Implementation |
|----|------------|----------|----------------|
| SC-SIL6-ZENOH-001 | Bounded message latency (< 100ms p99) | CRITICAL | Timeout enforcement |
| SC-SIL6-ZENOH-002 | Deterministic memory usage | CRITICAL | Bounded buffers |
| SC-SIL6-ZENOH-003 | 2oo3 voting for critical operations | CRITICAL | QuorumVoting module |
| SC-SIL6-ZENOH-004 | Cryptographic message integrity | CRITICAL | Ed25519 signatures |
| SC-SIL6-ZENOH-005 | Heartbeat-based liveness detection | HIGH | 10-second heartbeats |
| SC-SIL6-ZENOH-006 | Sample miss detection enabled | HIGH | AdvancedSubscriber |
| SC-SIL6-ZENOH-007 | Exponential backoff reconnection | HIGH | Capped at 60 seconds |
| SC-SIL6-ZENOH-008 | Session singleton pattern | HIGH | Module-level state |
| SC-SIL6-ZENOH-009 | Immutable message envelopes | MEDIUM | Record types |
| SC-SIL6-ZENOH-010 | Comprehensive telemetry | MEDIUM | All operations logged |

### 4.3 SIL-6 Verification Requirements

| Verification Type | Requirement | Implementation |
|-------------------|-------------|----------------|
| **Static Analysis** | Type safety verification | F# compiler + FSharpLint |
| **Dynamic Analysis** | Runtime bounds checking | Timeout wrappers |
| **Formal Verification** | Critical path proofs | Quint models |
| **Property Testing** | Invariant verification | FsCheck properties |
| **Penetration Testing** | Security boundary tests | Message injection tests |
| **Chaos Engineering** | Failure mode coverage | Network partition tests |

### 4.4 SIL-6 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     SIL-6 ZENOH INTEGRATION ARCHITECTURE                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                    CONSTITUTIONAL LAYER (Ψ₀-Ψ₅)                  │  │
│   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │  │
│   │  │  Guardian   │  │  Sentinel   │  │ Immutable   │              │  │
│   │  │   Veto      │  │   Health    │  │  Register   │              │  │
│   │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘              │  │
│   └─────────┼────────────────┼────────────────┼──────────────────────┘  │
│             │                │                │                          │
│   ┌─────────┴────────────────┴────────────────┴──────────────────────┐  │
│   │                    SAFETY ENVELOPE (SC-SIL6-*)                   │  │
│   │                                                                   │  │
│   │   ┌─────────────────────────────────────────────────────────┐   │  │
│   │   │              ZENOH INTEGRATION LAYER                     │   │  │
│   │   │                                                          │   │  │
│   │   │   ┌─────────┐    ┌─────────┐    ┌─────────┐            │   │  │
│   │   │   │ Session │◄──►│ PubSub  │◄──►│  Query  │            │   │  │
│   │   │   │(SIL-6)  │    │(SIL-6)  │    │(SIL-6)  │            │   │  │
│   │   │   └────┬────┘    └────┬────┘    └────┬────┘            │   │  │
│   │   │        │              │              │                   │   │  │
│   │   │   ┌────┴──────────────┴──────────────┴────┐            │   │  │
│   │   │   │         BOUNDED EXECUTION              │            │   │  │
│   │   │   │   • Timeout wrappers (100ms max)      │            │   │  │
│   │   │   │   • Memory limits (1000 cache max)    │            │   │  │
│   │   │   │   • Retry limits (10 max)             │            │   │  │
│   │   │   └───────────────────────────────────────┘            │   │  │
│   │   │                                                          │   │  │
│   │   │   ┌─────────────────────────────────────────────────┐   │   │  │
│   │   │   │              2oo3 VOTING PLANE                   │   │   │  │
│   │   │   │   Node 1 ──┐                                     │   │   │  │
│   │   │   │   Node 2 ──┼──► Quorum Decision ──► Action       │   │   │  │
│   │   │   │   Node 3 ──┘                                     │   │   │  │
│   │   │   └─────────────────────────────────────────────────┘   │   │  │
│   │   │                                                          │   │  │
│   │   └──────────────────────────────────────────────────────────┘   │  │
│   │                                                                   │  │
│   │   ┌─────────────────────────────────────────────────────────┐   │  │
│   │   │              TELEMETRY & MONITORING                      │   │  │
│   │   │   • Connection state changes                             │   │  │
│   │   │   • Message publish/receive counts                       │   │  │
│   │   │   • Latency histograms                                   │   │  │
│   │   │   • Error rates                                          │   │  │
│   │   │   • Health check results                                 │   │  │
│   │   └─────────────────────────────────────────────────────────┘   │  │
│   │                                                                   │  │
│   └───────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                    ZENOH-CS NATIVE LAYER                         │  │
│   │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │  │
│   │   │  Session    │  │  Publisher  │  │ Subscriber  │              │  │
│   │   │  (FFI)      │  │   (FFI)     │  │   (FFI)     │              │  │
│   │   └──────┬──────┘  └──────┬──────┘  └──────┬──────┘              │  │
│   │          └─────────────────┼─────────────────┘                    │  │
│   │                            │                                      │  │
│   │   ┌────────────────────────┴───────────────────────────┐         │  │
│   │   │              zenoh-c v1.6.2 (Native)               │         │  │
│   │   │              libzenohc.so / zenohc.dll             │         │  │
│   │   └────────────────────────────────────────────────────┘         │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Part V: Implementation Roadmap

### 5.1 Phase Summary

| Phase | Focus | Duration | Deliverables |
|-------|-------|----------|--------------|
| **1** | L1-L2: FFI + Modules | 3-4 days | ZenohNative.fs, module structure |
| **2** | L3-L4: Messages + Packages | 2-3 days | Envelope types, NuGet integration |
| **3** | L5: Runtime | 2-3 days | Lifecycle, health, reconnection |
| **4** | L6: Cluster | 3-4 days | Barriers, quorum voting |
| **5** | L7: Federation | 2-3 days | Protocol, attestation |
| **6** | SIL-6 Hardening | 3-4 days | Bounded execution, 2oo3 |

### 5.2 Files to Create/Modify

| File | Action | Phase |
|------|--------|-------|
| `Zenoh/Core/ZenohNative.fs` | CREATE | 1 |
| `Zenoh/Core/ZenohTypes.fs` | CREATE | 1 |
| `Zenoh/Session/ZenohSession.fs` | MODIFY | 2 |
| `Zenoh/Session/ZenohLifecycle.fs` | CREATE | 3 |
| `Zenoh/PubSub/ZenohPublisher.fs` | CREATE | 2 |
| `Zenoh/PubSub/ZenohSubscriber.fs` | CREATE | 2 |
| `Zenoh/Cluster/ZenohBarrier.fs` | CREATE | 4 |
| `Zenoh/Cluster/ZenohQuorum.fs` | CREATE | 4 |
| `Zenoh/Federation/ZenohFederation.fs` | CREATE | 5 |
| `Zenoh/SIL6/BoundedExecution.fs` | CREATE | 6 |
| `Cepaf.fsproj` | MODIFY | 1 |

---

## Part VI: Test Requirements Summary

### 6.1 Test Matrix (By Level)

| Level | Unit Tests | Property Tests | Integration | SIL-6 | Total |
|-------|------------|----------------|-------------|-------|-------|
| L1 | 20 | 10 | 5 | 5 | 40 |
| L2 | 15 | 5 | 5 | 0 | 25 |
| L3 | 25 | 15 | 10 | 5 | 55 |
| L4 | 10 | 0 | 5 | 0 | 15 |
| L5 | 20 | 10 | 10 | 10 | 50 |
| L6 | 25 | 15 | 15 | 15 | 70 |
| L7 | 20 | 10 | 10 | 5 | 45 |
| **Total** | **135** | **65** | **60** | **40** | **300** |

### 6.2 SIL-6 Specific Tests

| Test Category | Count | Description |
|---------------|-------|-------------|
| Timeout bounds | 10 | Verify all operations complete within bounds |
| Memory bounds | 10 | Verify cache/buffer limits enforced |
| 2oo3 voting | 10 | Verify quorum logic correct |
| Reconnection | 5 | Verify exponential backoff behavior |
| Heartbeat | 5 | Verify liveness detection |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-01-14 | Claude Opus 4.5 | Initial 7-level analysis |
| 2.0.0 | 2026-01-14 | Claude Opus 4.5 | Added 10x10 matrix, SIL-6 requirements |

---

## References

- [Eclipse Zenoh](https://github.com/eclipse-zenoh/zenoh)
- [zenoh-ext](https://github.com/eclipse-zenoh/zenoh/tree/main/zenoh-ext)
- [zenoh-c documentation](https://zenoh-c.readthedocs.io/)
- [Zenoh-CS NuGet](https://www.nuget.org/packages/Zenoh-CS)
- [Zenoh Getting Started](https://zenoh.io/docs/getting-started/first-app/)
