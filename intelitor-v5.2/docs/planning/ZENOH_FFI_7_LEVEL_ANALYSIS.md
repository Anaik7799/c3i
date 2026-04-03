# 7-Level Fractal Analysis: Zenoh.Net FFI Integration into F# Codebase

**Version**: 1.0.0 | **Date**: 2026-01-14 | **STAMP**: SC-ZENOH-FFI-001
**Author**: Claude Opus 4.5 | **Status**: PLANNING

---

## Executive Summary

**Current State**: The F# codebase has well-designed Zenoh abstraction layers (ZenohSession, ZenohChannel, ZenohAdapter) but they are entirely simulated/mocked. Only `Indrajaal.Cortex.fsproj` has the `Zenoh-CS Version="0.4.1"` NuGet package, but even its `ZenohAdapter.fs` is a stub.

**Target State**: Full FFI integration with actual Zenoh-CS library calls while maintaining STAMP constraints (SC-ZENOH-001 through SC-ZENOH-015) and AOR rules.

---

## L1 - Function Level: FFI Bindings and Type Mappings

### 1.1 Current State Analysis

The current `ZenohSession.fs` defines these function signatures that are simulated:

```fsharp
// Current: Simulated (lib/cepaf/src/Cepaf/Zenoh/ZenohSession.fs:155-170)
let initializeAsync (config: SessionConfig) = async {
    // NOTE: In production, this would use the Zenoh .NET library:
    // let! session = Zenoh.Session.OpenAsync(config) |> Async.AwaitTask
    // For now, we simulate connection success
    do! Async.Sleep(100)
    connectionStatus <- Connected
    return Ok ()
}

// Current publish (line 177-198) - simulated with Sleep(1)
let publishAsync (key: string) (payload: byte[]) = async {
    // NOTE: Production implementation:
    // do! session.PutAsync(key, payload) |> Async.AwaitTask
    do! Async.Sleep(1)
    return Ok ()
}
```

### 1.2 Target State Design

Based on Zenoh-CS 0.4.1 API:

```fsharp
// Target: Real Zenoh-CS FFI calls
open Zenoh

// Session type wrapper for F# safety
type ZenohNativeSession = {
    Session: Session
    mutable IsOpen: bool
}

// Configuration mapping F# -> Zenoh-CS
let mapConfig (cfg: SessionConfig) : Config =
    let config = new Config()
    for endpoint in cfg.Endpoints do
        config.Connect(endpoint)
    config.SetMode(cfg.Mode)
    config

// Real session initialization
let initializeAsync (config: SessionConfig) = async {
    let zenohConfig = mapConfig config
    let! session = Session.OpenAsync(zenohConfig) |> Async.AwaitTask
    nativeSession <- Some { Session = session; IsOpen = true }
    connectionStatus <- Connected
    return Ok ()
}

// Real publish with KeyExpr
let publishAsync (key: string) (payload: byte[]) = async {
    match nativeSession with
    | Some ns when ns.IsOpen ->
        let keyExpr = KeyExpr.Parse(key)
        do! ns.Session.PutAsync(keyExpr, payload) |> Async.AwaitTask
        return Ok ()
    | _ -> return Error "Not connected"
}

// Real subscribe with callback
let subscribe (keyExpr: string) (handler: ZenohMessage -> unit) =
    match nativeSession with
    | Some ns when ns.IsOpen ->
        let ke = KeyExpr.Parse(keyExpr)
        let subscriber = ns.Session.DeclareSubscriber(ke)
            .Callback(fun sample ->
                let msg = {
                    Key = sample.KeyExpr.ToString()
                    Payload = sample.Payload.ToArray()
                    Timestamp = Some (DateTimeOffset.FromUnixTimeMilliseconds(sample.Timestamp))
                    Encoding = sample.Encoding.ToString()
                    Source = sample.SampleKind.ToString() |> Some
                }
                handler msg
            )
            .Res()
        Ok (subscriber.Id.ToString())
    | _ -> Error "Not connected"
```

### 1.3 STAMP Constraints (L1)

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-ZENOH-FSH-001 | Session singleton pattern | Mutable `nativeSession` option |
| SC-ZENOH-FSH-002 | Auto-reconnect with exponential backoff | Wrap in retry loop |
| SC-ZENOH-FSH-003 | Thread-safe subscriber management | ConcurrentDictionary |

### 1.4 AOR Rules (L1)

| ID | Rule |
|----|------|
| AOR-FFI-001 | All Zenoh-CS calls MUST be wrapped in try/catch |
| AOR-FFI-002 | Null checks for all returned Zenoh objects |
| AOR-FFI-003 | Dispose pattern for Session and Subscriber |
| AOR-FFI-004 | KeyExpr.Parse failures MUST return Result.Error |

### 1.5 Implementation Steps (L1)

1. Add type aliases for Zenoh-CS types in `ZenohTypes.fs`
2. Create `ZenohNativeWrapper.fs` with safe FFI wrappers
3. Update `ZenohSession.fs` to use real FFI calls
4. Add `ZenohAdapter.fs` in Planning to use `Cepaf.Zenoh` module

### 1.6 Risk Analysis (FMEA - L1)

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| KeyExpr parse failure | 6 | 3 | 8 | 144 | Validate key format before parse |
| Null session reference | 8 | 2 | 9 | 144 | Option type pattern matching |
| Memory leak in subscribers | 7 | 4 | 6 | 168 | Dispose pattern + finalization |
| Type mismatch payload | 5 | 3 | 7 | 105 | Strong typing with byte[] |

### 1.7 Test Requirements (L1)

- Unit tests for each FFI wrapper function
- Property tests for key expression parsing (PropCheck)
- Error case coverage for null/exception scenarios
- Memory leak detection tests

---

## L2 - Component Level: Module Organization

### 2.1 Current State Analysis

Current module structure:

```
lib/cepaf/src/Cepaf/Zenoh/
├── ZenohSession.fs      # Simulated session management
├── ZenohChannel.fs      # Log channel using ZenohSession
├── KmsSubscriber.fs     # KMS state subscription

lib/cepaf/src/Cepaf.Planning/
├── ZenohAdapter.fs      # Console-only placeholder
```

### 2.2 Target State Design

Proposed restructured architecture:

```
lib/cepaf/src/Cepaf/Zenoh/
├── Core/
│   ├── ZenohTypes.fs          # NEW: Type aliases and wrappers
│   ├── ZenohNativeWrapper.fs  # NEW: Safe FFI layer
│   └── ZenohConfig.fs         # NEW: Configuration management
├── Session/
│   ├── ZenohSession.fs        # MODIFIED: Use real FFI
│   └── ZenohReconnect.fs      # NEW: Reconnection logic
├── PubSub/
│   ├── ZenohPublisher.fs      # NEW: Publisher abstraction
│   ├── ZenohSubscriber.fs     # NEW: Subscriber abstraction
│   └── ZenohChannel.fs        # MODIFIED: Use real session
├── Integration/
│   ├── KmsSubscriber.fs       # MODIFIED: Real subscriptions
│   └── FractalPublisher.fs    # MOVED: From Observability

lib/cepaf/src/Cepaf.Planning/
├── ZenohAdapter.fs            # MODIFIED: Use Cepaf.Zenoh
```

### 2.3 STAMP Constraints (L2)

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-ZENOH-CHN-001 | Non-blocking log dispatch | Async publish with buffering |
| SC-ZENOH-CHN-002 | Batch optimization | ConcurrentQueue + timer flush |
| SC-ZENOH-CHN-003 | Graceful degradation | Fallback to console on disconnect |

### 2.4 AOR Rules (L2)

| ID | Rule |
|----|------|
| AOR-MOD-001 | Core module has no external dependencies except Zenoh-CS |
| AOR-MOD-002 | Session module uses Core, no direct Zenoh-CS calls |
| AOR-MOD-003 | PubSub module uses Session, provides typed abstractions |
| AOR-MOD-004 | Integration module uses PubSub, domain-specific logic |

### 2.5 Implementation Steps (L2)

1. Create `Core/` subdirectory with foundation types
2. Move existing session logic to `Session/` with new wrapper
3. Extract publisher/subscriber patterns to `PubSub/`
4. Update `Cepaf.fsproj` compile order (critical for F#)
5. Update `Cepaf.Planning.fsproj` to add `Zenoh-CS` reference

### 2.6 Risk Analysis (FMEA - L2)

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| Compile order wrong | 9 | 5 | 2 | 90 | Explicit fsproj ordering |
| Circular dependency | 8 | 3 | 4 | 96 | Layered architecture |
| Missing module export | 6 | 4 | 5 | 120 | Namespace consistency |

### 2.7 Test Requirements (L2)

- Integration tests for module composition
- Dependency graph verification
- Build order validation tests

---

## L3 - Holon Level: Agent Communication Patterns

### 3.1 Current State Analysis

Current topic schema (from `ZenohFractalPublisher.fs`):

```fsharp
let planes = {|
    FractalPlane = ["indrajaal/fractal/l1/**"; ...; "indrajaal/fractal/l5/**"]
    TelemetryPlane = ["indrajaal/telemetry/elixir/**"; "indrajaal/telemetry/fsharp/**"]
    DataPlane = ["indrajaal/kpi/compilation"; ...; "indrajaal/kpi/agents"]
    ControlPlane = ["indrajaal/control/refresh"; ...; "indrajaal/control/emergency"]
    CoordinationPlane = ["indrajaal/coord/heartbeat"; "indrajaal/coord/sync"; ...]
    EvolutionPlane = ["indrajaal/evolution/shadow/*/execution"; ...]
|}
```

### 3.2 Target State Design

Enhanced message patterns with real Zenoh integration:

```fsharp
// Message envelope with tracing
type ZenohEnvelope<'T> = {
    Payload: 'T
    Timestamp: DateTimeOffset
    TraceId: string option
    SpanId: string option
    Source: string
    Version: string
}

// Serialization strategy
module ZenohSerialization =
    let serialize<'T> (msg: 'T) : byte[] =
        JsonSerializer.SerializeToUtf8Bytes(msg)

    let deserialize<'T> (payload: byte[]) : Result<'T, string> =
        try
            Ok (JsonSerializer.Deserialize<'T>(payload))
        with ex -> Error ex.Message

// Typed publisher for domain events
type PlanningEventPublisher(session: ZenohSession) =
    let topic = "indrajaal/planning/events"

    member this.PublishTaskCreated(task: TaskItem) =
        let envelope = {
            Payload = TaskCreated task
            Timestamp = DateTimeOffset.UtcNow
            TraceId = Some (Guid.NewGuid().ToString("N"))
            SpanId = None
            Source = "cepaf-planning"
            Version = "1.0.0"
        }
        session.publish topic (ZenohSerialization.serialize envelope)
```

### 3.3 STAMP Constraints (L3)

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-ZENOH-INT-001 | Universal Zenoh access | Single session shared across modules |
| SC-ZENOH-PUB-001 | Non-blocking publish | Async with Task.Run fallback |
| SC-ZENOH-PUB-002 | Latency < 1ms | Buffer + batch flush |
| SC-ZENOH-PUB-003 | Batch support | ConcurrentQueue with size trigger |

### 3.4 AOR Rules (L3)

| ID | Rule |
|----|------|
| AOR-MSG-001 | All messages MUST have envelope with tracing |
| AOR-MSG-002 | JSON serialization with snake_case naming |
| AOR-MSG-003 | Version field for schema evolution |
| AOR-MSG-004 | TraceId propagation for distributed tracing |

### 3.5 Implementation Steps (L3)

1. Define `ZenohEnvelope<'T>` generic wrapper
2. Create typed publishers for each domain (Planning, KMS, Mesh)
3. Create typed subscribers with deserialization
4. Add tracing context propagation

### 3.6 Risk Analysis (FMEA - L3)

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| Schema mismatch | 7 | 5 | 4 | 140 | Version negotiation |
| Lost messages | 8 | 3 | 5 | 120 | Acknowledgment pattern |
| Deserialization fail | 6 | 4 | 6 | 144 | Result type with error handling |
| Topic typo | 5 | 4 | 3 | 60 | Constant definitions |

### 3.7 Test Requirements (L3)

- Round-trip serialization tests
- Cross-language compatibility tests (F# <-> Elixir JSON)
- Message ordering tests
- Tracing propagation tests

---

## L4 - Container Level: Package Dependencies and Build Configuration

### 4.1 Current State Analysis

**Cepaf.fsproj**:
```xml
<ItemGroup>
    <PackageReference Include="Argu" Version="6.2.5" />
    <PackageReference Include="CliWrap" Version="3.10.0" />
    <PackageReference Include="Microsoft.Data.Sqlite" Version="9.0.1" />
    <!-- NO Zenoh-CS reference -->
</ItemGroup>
```

**Cepaf.Planning.fsproj**:
```xml
<ItemGroup>
    <PackageReference Include="FParsec" Version="1.1.1" />
    <PackageReference Include="Microsoft.Data.Sqlite" Version="9.0.1" />
    <!-- NO Zenoh-CS reference -->
</ItemGroup>
```

**Indrajaal.Cortex.fsproj** - HAS Zenoh-CS:
```xml
<ItemGroup>
    <PackageReference Include="Zenoh-CS" Version="0.4.1" />
</ItemGroup>
```

### 4.2 Target State Design

**Updated Cepaf.fsproj**:
```xml
<ItemGroup>
    <!-- Existing packages -->
    <PackageReference Include="Argu" Version="6.2.5" />
    <PackageReference Include="CliWrap" Version="3.10.0" />
    <PackageReference Include="Microsoft.Data.Sqlite" Version="9.0.1" />

    <!-- NEW: Zenoh-CS for native pub/sub (SC-ZENOH-001) -->
    <PackageReference Include="Zenoh-CS" Version="0.4.1" />
</ItemGroup>
```

**Updated Cepaf.Planning.fsproj**:
```xml
<ItemGroup>
    <PackageReference Include="FParsec" Version="1.1.1" />
    <PackageReference Include="Microsoft.Data.Sqlite" Version="9.0.1" />
    <!-- Uses Cepaf.Zenoh via ProjectReference, no direct Zenoh-CS needed -->
</ItemGroup>

<ItemGroup>
    <ProjectReference Include="..\Cepaf\Cepaf.fsproj" />
</ItemGroup>
```

### 4.3 STAMP Constraints (L4)

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-NET-001 | Target net10.0 | Already compliant |
| SC-ZENOH-PKG-001 | Zenoh-CS version pinned | Explicit Version="0.4.1" |
| SC-BUILD-001 | Deterministic builds | Lock file for NuGet |

### 4.4 AOR Rules (L4)

| ID | Rule |
|----|------|
| AOR-PKG-001 | Zenoh-CS only in Cepaf, not Planning (use via ProjectReference) |
| AOR-PKG-002 | Version must match Cortex for consistency |
| AOR-PKG-003 | No transitive dependency conflicts |
| AOR-PKG-004 | Native library deployment verified |

### 4.5 Implementation Steps (L4)

1. Add `Zenoh-CS Version="0.4.1"` to `Cepaf.fsproj`
2. Verify `Cepaf.Planning.fsproj` already has `ProjectReference` to Cepaf
3. Update `global.json` if needed for native library compatibility
4. Verify native Zenoh library deployment (zenohc.dll/libzenohc.so)

### 4.6 Risk Analysis (FMEA - L4)

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| Native lib missing | 9 | 4 | 7 | 252 | NuGet postbuild copy |
| Version conflict | 7 | 3 | 5 | 105 | Explicit version pins |
| Platform incompatibility | 8 | 2 | 8 | 128 | CI multi-platform tests |
| Build order issue | 6 | 4 | 3 | 72 | Explicit compile order |

### 4.7 Test Requirements (L4)

- NuGet restore verification
- Native library presence check
- Cross-platform build tests (Linux, Windows)
- Container deployment tests

---

## L5 - Node Level: Runtime Initialization and Health Monitoring

### 5.1 Current State Analysis

Current initialization (ZenohSession.fs):
```fsharp
let initializeAsync (config: SessionConfig) = async {
    sessionState <- Some config
    connectionStatus <- Connecting
    // Simulated - no actual Zenoh calls
    do! Async.Sleep(100)
    connectionStatus <- Connected
    return Ok ()
}
```

Health is simulated via `getStats()` returning mock data.

### 5.2 Target State Design

```fsharp
// Real lifecycle management
module ZenohLifecycle =
    let mutable private session: Session option = None
    let mutable private healthCheckTimer: Timer option = None

    let initializeAsync (config: SessionConfig) = async {
        try
            let zenohConfig = new Config()
            for endpoint in config.Endpoints do
                zenohConfig.Connect(endpoint)

            let! sess = Session.OpenAsync(zenohConfig) |> Async.AwaitTask
            session <- Some sess
            connectionStatus <- Connected

            // Start health check timer (SC-ZENOH-007)
            let callback = TimerCallback(fun _ -> healthCheck())
            healthCheckTimer <- Some (new Timer(callback, null, 10000, 10000))

            return Ok ()
        with ex ->
            connectionStatus <- Failed ex.Message
            return Error ex.Message
    }

    let private healthCheck () =
        match session with
        | Some s ->
            try
                // Zenoh-CS health ping
                let info = s.Info()
                let stats = {
                    MessagesReceived = info.Statistics.ReceivedMessages
                    MessagesSent = info.Statistics.SentMessages
                    ReconnectCount = 0
                    UptimeSeconds = info.Uptime.TotalSeconds
                    LastLatencyMs = 0.0
                }
                updateStats stats
            with ex ->
                connectionStatus <- Reconnecting
                reconnectAsync() |> Async.Start
        | None -> ()

    let closeAsync () = async {
        match healthCheckTimer with
        | Some timer -> timer.Dispose()
        | None -> ()

        match session with
        | Some s ->
            s.Close()
            session <- None
            connectionStatus <- Disconnected
        | None -> ()
    }
```

### 5.3 STAMP Constraints (L5)

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-ZENOH-001 | Zenoh NIF loaded on ALL nodes | Runtime check on init |
| SC-ZENOH-002 | Router reachable from ALL nodes | Health check endpoint |
| SC-ZENOH-003 | TelemetrySubscriber connected | Verify on startup |
| SC-ZENOH-005 | Reconnect on failure | Exponential backoff |
| SC-ZENOH-007 | Health in /health endpoint | JSON status |

### 5.4 AOR Rules (L5)

| ID | Rule |
|----|------|
| AOR-ZENOH-002 | Verify router running before startup |
| AOR-ZENOH-004 | Log all connection state changes |
| AOR-ZENOH-005 | Alert on disconnect > 30 seconds |
| AOR-ZENOH-006 | Retry with exponential backoff |
| AOR-ZENOH-007 | Publish node health every 10 seconds |

### 5.5 Implementation Steps (L5)

1. Create `ZenohLifecycle.fs` with init/close/health
2. Implement exponential backoff reconnection
3. Add health check timer with 10s interval
4. Expose health endpoint integration
5. Add startup validation (router reachable)

### 5.6 Risk Analysis (FMEA - L5)

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| Router unreachable | 9 | 5 | 8 | 360 | Startup gate, depends_on |
| Session leak | 7 | 3 | 5 | 105 | Dispose pattern |
| Health check blocked | 6 | 4 | 6 | 144 | Timeout with async |
| Reconnect storm | 8 | 3 | 4 | 96 | Circuit breaker |

### 5.7 Test Requirements (L5)

- Startup with/without router tests
- Reconnection behavior tests
- Health check accuracy tests
- Resource cleanup tests (no leaks)

---

## L6 - Cluster Level: Multi-Node Coordination

### 6.1 Current State Analysis

Barrier synchronization is implemented but uses local state only - NOT distributed.

### 6.2 Target State Design

```fsharp
// Distributed barrier using Zenoh
module ZenohDistributedCoordination =
    let private barrierTopic name = sprintf "indrajaal/coord/barrier/%s" name

    let barrierAsync (name: string) (count: int) (nodeId: string) (timeoutMs: int) = async {
        // Publish join message
        let joinMsg = {|
            event = "join"
            barrier = name
            node = nodeId
            timestamp = DateTimeOffset.UtcNow.ToString("o")
        |}
        do! ZenohSession.publishJson (barrierTopic name) (serialize joinMsg)

        // Subscribe to barrier updates
        let mutable participants = Set.empty<string>
        let subscription =
            ZenohSession.subscribe (barrierTopic name) (fun msg ->
                let evt = deserialize<{| event: string; node: string |}> msg.Payload
                if evt.event = "join" then
                    participants <- participants.Add(evt.node)
            )

        // Wait for all participants
        let deadline = DateTimeOffset.UtcNow.AddMilliseconds(float timeoutMs)
        while Set.count participants < count && DateTimeOffset.UtcNow < deadline do
            do! Async.Sleep(100)

        // Cleanup subscription
        ZenohSession.unsubscribe subscription |> ignore

        if Set.count participants >= count then
            return Ok ()
        else
            return Error "Barrier timeout"
    }

    // Quorum voting using Zenoh (SC-SIL6-006)
    let quorumVoteAsync (topic: string) (vote: bool) (quorumSize: int) = async {
        // Publish vote
        do! ZenohSession.publishJson topic {| vote = vote; node = nodeId |}

        // Collect votes
        let mutable votes = Map.empty<string, bool>
        let sub = ZenohSession.subscribe topic (fun msg ->
            let v = deserialize<{| vote: bool; node: string |}> msg.Payload
            votes <- votes.Add(v.node, v.vote)
        )

        // Wait for quorum
        do! Async.Sleep(1000)
        ZenohSession.unsubscribe sub |> ignore

        let yesVotes = votes |> Map.filter (fun _ v -> v) |> Map.count
        return yesVotes >= quorumSize
    }
```

### 6.3 STAMP Constraints (L6)

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-SIL6-006 | 2oo3 voting mandatory | Quorum functions |
| SC-SIL6-011 | Quorum = floor(N/2)+1 | Dynamic calculation |
| SC-MESH-001 | Mesh boot 5 stages | Barrier per stage |
| SC-FRAC-001 | Cluster AI quorum | Vote aggregation |

### 6.4 AOR Rules (L6)

| ID | Rule |
|----|------|
| AOR-MESH-003 | Verify 2oo3 consensus in production |
| AOR-MESH-004 | FPPS 5-method validation for health |
| AOR-MESH-006 | Negotiate protocol version |

### 6.5 Implementation Steps (L6)

1. Implement `ZenohDistributedCoordination.fs`
2. Replace local barriers with Zenoh-backed
3. Add quorum voting functions
4. Integrate with mesh boot sequence

### 6.6 Risk Analysis (FMEA - L6)

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| Split brain | 9 | 2 | 5 | 90 | Quorum requirements |
| Vote lost | 7 | 4 | 6 | 168 | Retransmission |
| Barrier deadlock | 8 | 3 | 4 | 96 | Timeout with cleanup |
| Network partition | 9 | 2 | 7 | 126 | Graceful degradation |

### 6.7 Test Requirements (L6)

- Multi-node barrier synchronization tests
- Quorum voting with node failure tests
- Network partition simulation tests
- Consensus convergence tests

---

## L7 - Federation Level: Cross-Holon Communication

### 7.1 Current State Analysis

Federation protocol exists but uses simulated Zenoh. Version negotiation not implemented over real Zenoh.

### 7.2 Target State Design

```fsharp
// Federation protocol over real Zenoh
module ZenohFederation =
    let private federationTopic holonId =
        sprintf "indrajaal/federation/%s" holonId

    type FederationMessage =
        | Announce of version: string * capabilities: string list
        | VersionNegotiate of minVersion: string * maxVersion: string
        | StateSync of holonId: string * stateHash: string
        | Attestation of holonId: string * attestation: byte[]

    // Cross-holon announcement (SC-REG-012)
    let announceAsync (holonId: string) (version: string) (caps: string list) = async {
        let msg = Announce(version, caps)
        let topic = sprintf "indrajaal/federation/announce"
        do! ZenohSession.publishJson topic (serialize msg)
    }

    // Version negotiation (SC-FRAC-006)
    let negotiateVersionAsync (targetHolon: string) (minVer: string) (maxVer: string) = async {
        let responseTopic = sprintf "indrajaal/federation/%s/negotiate/response" (Guid.NewGuid().ToString("N"))

        // Subscribe to response
        let mutable result = None
        let sub = ZenohSession.subscribe responseTopic (fun msg ->
            result <- Some (deserialize<string> msg.Payload)
        )

        // Send negotiation request
        let req = {|
            minVersion = minVer
            maxVersion = maxVer
            responseTopic = responseTopic
        |}
        do! ZenohSession.publishJson (federationTopic targetHolon + "/negotiate") (serialize req)

        // Wait for response
        do! Async.Sleep(5000)
        ZenohSession.unsubscribe sub |> ignore

        return result
    }

    // State attestation (SC-REG-012: every hour)
    let attestStateAsync (holonId: string) (stateHash: byte[]) = async {
        let attestation = Attestation(holonId, stateHash)
        do! ZenohSession.publishJson "indrajaal/federation/attestation" (serialize attestation)
    }
```

### 7.3 STAMP Constraints (L7)

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-REG-010 | Protocol version negotiation | negotiateVersionAsync |
| SC-REG-012 | Federation attestation hourly | attestStateAsync with timer |
| SC-FRAC-004 | Cross-holon attestation | State hash verification |
| SC-FRAC-005 | Global AI learning propagation | Pub/sub broadcast |
| SC-FRAC-006 | Federation version negotiation | Request/response pattern |

### 7.4 AOR Rules (L7)

| ID | Rule |
|----|------|
| AOR-RECONFIG-004 | Notify federation peers of reconfigurations |
| AOR-REG-010 | Negotiate protocol version before communication |
| AOR-REG-012 | Attest peer holon integrity every hour |

### 7.5 Implementation Steps (L7)

1. Create `ZenohFederation.fs` with protocol implementation
2. Implement version negotiation handshake
3. Add hourly attestation timer
4. Integrate with existing FederationProtocol

### 7.6 Risk Analysis (FMEA - L7)

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| Version mismatch | 7 | 4 | 5 | 140 | Negotiation fallback |
| Attestation forgery | 9 | 1 | 8 | 72 | Cryptographic signatures |
| Cross-holon timeout | 6 | 5 | 6 | 180 | Reasonable timeouts |
| Protocol incompatibility | 8 | 2 | 4 | 64 | Version ranges |

### 7.7 Test Requirements (L7)

- Cross-holon communication tests
- Version negotiation with multiple scenarios
- Attestation verification tests
- Protocol compatibility matrix tests

---

## Summary: Implementation Priority and Dependencies

### Dependency Graph

```
L1 (Function FFI) ← L2 (Module Org) ← L3 (Message Patterns)
        ↑                  ↑                   ↑
        └──────────────────┴───────────────────┘
                           ↓
L4 (Package Deps) ← L5 (Runtime Init) ← L6 (Cluster Coord) ← L7 (Federation)
```

### Implementation Phases

| Phase | Levels | Effort | Dependencies |
|-------|--------|--------|--------------|
| 1 | L1 + L4 | 2-3 days | None |
| 2 | L2 + L5 | 2-3 days | Phase 1 |
| 3 | L3 | 1-2 days | Phase 2 |
| 4 | L6 + L7 | 3-4 days | Phase 3 |

### Total Risk Profile

| Level | Total RPN | Critical Risks |
|-------|-----------|----------------|
| L1 | 561 | Memory leak (168), Type mismatch (144) |
| L2 | 306 | Missing exports (120), Compile order (90) |
| L3 | 464 | Schema mismatch (140), Deserialization (144) |
| L4 | 557 | Native lib missing (252), Platform (128) |
| L5 | 705 | Router unreachable (360), Reconnect storm (96) |
| L6 | 480 | Vote lost (168), Network partition (126) |
| L7 | 456 | Cross-holon timeout (180), Version mismatch (140) |

---

## Critical Files for Implementation

1. **`lib/cepaf/src/Cepaf/Zenoh/ZenohSession.fs`** - Core session management requiring FFI replacement

2. **`lib/cepaf/src/Cepaf/Cepaf.fsproj`** - Must add `Zenoh-CS Version="0.4.1"` package reference

3. **`lib/cepaf/src/Cepaf.Planning/ZenohAdapter.fs`** - Placeholder that needs real Cepaf.Zenoh integration

4. **`lib/cortex/src/Indrajaal.Cortex/Indrajaal.Cortex.fsproj`** - Reference for Zenoh-CS pattern

5. **`lib/cepaf/src/Cepaf/Observability/Fractal/ZenohFractalPublisher.fs`** - Consumer that will benefit from real FFI

---

## New Files to Create

| File | Level | Purpose |
|------|-------|---------|
| `Zenoh/Core/ZenohTypes.fs` | L1 | Type aliases and wrappers |
| `Zenoh/Core/ZenohNativeWrapper.fs` | L1 | Safe FFI layer |
| `Zenoh/Session/ZenohReconnect.fs` | L5 | Reconnection logic |
| `Zenoh/Session/ZenohLifecycle.fs` | L5 | Init/close/health management |
| `Zenoh/PubSub/ZenohPublisher.fs` | L3 | Publisher abstraction |
| `Zenoh/PubSub/ZenohSubscriber.fs` | L3 | Subscriber abstraction |
| `Zenoh/Coordination/ZenohDistributedCoordination.fs` | L6 | Barriers and quorum |
| `Zenoh/Federation/ZenohFederation.fs` | L7 | Cross-holon protocol |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-01-14 | Claude Opus 4.5 | Initial 7-level analysis |
