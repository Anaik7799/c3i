# Fractal Logging System - 5-Level Criticality Implementation Plan

**Version**: 1.0.0 | **Date**: 2025-12-25 | **Status**: MASTER IMPLEMENTATION
**Context**: SOPv5.11 + STAMP + CEPAF Standalone + Zenoh-Unified Architecture

---

## 1.0 Implementation Architecture Overview

```
CRITICALITY PYRAMID
                                    P0-CRITICAL
                                   (Foundation)
                                   /          \
                              P1-HIGH      P1-HIGH
                            (KeyExpr)    (WriteFilter)
                           /                        \
                      P2-MEDIUM                  P2-MEDIUM
                      (HLC)                     (BatchEncoder)
                     /                                      \
                P3-LOW                                   P3-LOW
            (ContentRouter)                          (AdminSpace)
```

---

## 2.0 LEVEL 1: Atomic Implementation Details

### 2.1 P0-CRITICAL: Core Type System

| Component | File | Priority | Dependencies | LOC |
|:----------|:-----|:--------:|:-------------|:---:|
| FractalLevel | Types.fs | P0 | None | 150 |
| Priority | Types.fs | P0 | FractalLevel | 50 |
| Lens | Types.fs | P0 | FractalLevel | 80 |
| Boost | Types.fs | P0 | FractalLevel, Lens | 120 |
| HLCTimestamp | Types.fs | P0 | None | 60 |
| FractalLogEntry | Types.fs | P0 | All above | 200 |
| SafetyConstraints | Types.fs | P0 | None | 100 |

**F# Type Definitions** (Already created in `/lib/cepaf/src/Cepaf/Observability/Fractal/Types.fs`)

### 2.2 P0-CRITICAL: FractalControl State Machine

```fsharp
// FractalControl State Machine
type FractalControlState = {
    // Core configuration
    DefaultPolicy: FractalLevel          // L4 default
    Policies: Map<string, FractalLevel>  // Module -> Level

    // Active boosts with TTL
    Boosts: Boost list                   // SC-LOG-005: TTL mandatory

    // Subscription registry (Zenoh-style)
    Subscribers: Map<string, SubscriberInfo list>
    Publishers: Map<string, PublisherInfo list>

    // Write filter (Bloom)
    BloomFilter: BloomFilter option      // SC-LOG-008: <1% false negative

    // Key alias registry
    KeyAliases: Map<string, uint16>      // SC-LOG-009: Pre-registered
    AliasLookup: Map<uint16, string>

    // HLC state
    HLC: HLCState                        // SC-LOG-006: L3+ timestamps

    // Load shedding
    Shedding: bool                       // SC-LOG-002: CPU > 90%
    CurrentLoad: float

    // Metrics
    EmitCount: int64
    DropCount: Map<FractalLevel, int64>
    LastUpdate: DateTimeOffset
}
```

### 2.3 P1-HIGH: Key Expression Engine

```fsharp
// Zenoh Key Expression Syntax
// *   = Match single segment (Indrajaal/*/create)
// **  = Match any path (Indrajaal/**/error)
// $*  = Match within segment (Indrajaal/Alarms/$*Handler)

module KeyExpression =
    type CompiledExpr = {
        Original: string
        Regex: Regex
        Segments: string list
        HasWildcard: bool
        HasDoubleWildcard: bool
        HasInfixWildcard: bool
    }

    let compile (expr: string) : Result<CompiledExpr, string>
    let matches (compiled: CompiledExpr) (key: string) : bool
    let intersects (a: CompiledExpr) (b: CompiledExpr) : bool
```

### 2.4 P2-MEDIUM: Hybrid Logical Clock

```fsharp
// HLC for causal ordering without NTP synchronization
module HLC =
    type Timestamp = {
        Physical: int64    // Unix microseconds
        Counter: int       // Logical counter (0-65535)
        NodeId: string     // 48-bit node UUID
    }

    let now () : Timestamp
    let update (received: Timestamp) : unit
    let compare (a: Timestamp) (b: Timestamp) : int
    let add (ts: Timestamp) (ms: int64) : Timestamp
```

---

## 3.0 LEVEL 2: Component Module Design

### 3.1 Module Dependency Graph

```
                    ┌─────────────────┐
                    │   Types.fs      │ (P0)
                    │  FractalLevel   │
                    │  Priority       │
                    │  Lens, Boost    │
                    └────────┬────────┘
                             │
           ┌─────────────────┼─────────────────┐
           │                 │                 │
           ▼                 ▼                 ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │ KeyExpr.fs   │  │   HLC.fs     │  │ WriteFilter  │
    │    (P1)      │  │    (P2)      │  │    (P1)      │
    └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
           │                 │                 │
           └─────────────────┼─────────────────┘
                             │
                    ┌────────▼────────┐
                    │ FractalControl  │ (P0)
                    │   GenServer     │
                    └────────┬────────┘
                             │
           ┌─────────────────┼─────────────────┐
           │                 │                 │
           ▼                 ▼                 ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │ BatchEncoder │  │ContentRouter │  │ AdminSpace   │
    │    (P2)      │  │    (P3)      │  │    (P3)      │
    └──────────────┘  └──────────────┘  └──────────────┘
```

### 3.2 F# Module Files

| Module | File Path | Purpose | STAMP Constraints |
|:-------|:----------|:--------|:------------------|
| Types | `Fractal/Types.fs` | Core type definitions | SC-LOG-005,006 |
| FractalControl | `Fractal/FractalControl.fs` | State management | SC-LOG-001,002 |
| KeyExpression | `Fractal/KeyExpression.fs` | Zenoh wildcards | SC-LOG-009 |
| WriteFilter | `Fractal/WriteFilter.fs` | Bloom filter | SC-LOG-008 |
| HLC | `Fractal/HLC.fs` | Causal ordering | SC-LOG-006 |
| BatchEncoder | `Fractal/BatchEncoder.fs` | Wire optimization | SC-LOG-007 |
| ContentRouter | `Fractal/ContentRouter.fs` | Backend routing | - |
| AdminSpace | `Fractal/AdminSpace.fs` | Runtime control | SC-LOG-010 |
| Integration | `Fractal/Integration.fs` | QuadplexLogger bridge | SC-OBS-069 |

---

## 4.0 LEVEL 3: Transactional Business Use Cases

### 4.1 Use Case Matrix

| Use Case | Level | Trigger | Data Captured | Retention |
|:---------|:-----:|:--------|:--------------|:----------|
| Production Monitoring | L4 | Always on | CPU, memory, network | 90 days |
| User Journey Tracing | L3 | TraceID present | Business events, latency | 30 days |
| Debug Session | L1 | Operator boost | Function args, returns | 1 hour |
| AI Decision Audit | L5 | Cortex OODA | Intent, confidence | Forever |
| Performance Profiling | L2 | Module override | State transitions | 7 days |
| Security Audit | L5 | Security events | Auth, access | Forever |
| Error Investigation | L1 | Exception trigger | Stack, args | 24 hours |

### 4.2 Container Deployment Scenarios

```yaml
# Scenario 1: Development (Full Verbosity)
FRACTAL_DEFAULT_LEVEL: L2
FRACTAL_SAMPLING_RATE: 1.0
FRACTAL_BATCH_SIZE: 10

# Scenario 2: Production (Optimized)
FRACTAL_DEFAULT_LEVEL: L4
FRACTAL_SAMPLING_RATE: 0.1
FRACTAL_BATCH_SIZE: 100

# Scenario 3: Debugging (Targeted)
FRACTAL_DEFAULT_LEVEL: L4
FRACTAL_BOOST_ENABLED: true
FRACTAL_BOOST_TTL_MS: 300000
```

### 4.3 CLI Commands

```bash
# Focus on specific module
mix fractal.focus --expr "Indrajaal/**/create" --depth L1 --ttl 300000

# Boost for specific user
mix fractal.boost --user_id 123 --depth L1 --ttl 60000

# Query historical logs
mix fractal.query "Indrajaal/Accounts/**?last=10&level=L1&since=-5m"

# Check system status
mix fractal.status --zenoh

# Admin operations
mix fractal.admin get "@/fractal/metrics/throughput"
mix fractal.admin put "@/fractal/emergency/shed_load" --reason "maintenance"
```

---

## 5.0 LEVEL 4: Systemic Operational Concerns

### 5.1 Performance Targets

| Component | Metric | Target | Measurement |
|:----------|:-------|:-------|:------------|
| ETS Lookup | `should_log?/3` | < 1µs | Benchee |
| WriteFilter | `should_emit?/2` | < 500ns | Benchee |
| HLC | `now/0` | < 100ns | Atomic ops |
| Batch Flush | Interval | < 10ms | SC-LOG-007 |
| Wire Savings | Compression | > 65% | Batch vs single |
| Bloom Filter | False negative | < 1% | SC-LOG-008 |

### 5.2 Container Resource Limits

```yaml
services:
  fractal-control:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
        reservations:
          memory: 256M
          cpus: '0.25'
    environment:
      - FRACTAL_ETS_MAX_SIZE=100000
      - FRACTAL_BLOOM_SIZE=10000
      - FRACTAL_BATCH_BUFFER_SIZE=1000
```

### 5.3 Load Shedding Thresholds

| Condition | Detection | Action | Recovery |
|:----------|:----------|:-------|:---------|
| CPU > 90% | ResourceMonitor | Drop to L4 only | CPU < 80% for 30s |
| Memory > 85% | erlang.memory | Drop L1/L2, sample L3 | Memory < 75% |
| Queue > 50K | GenStage demand | Increase sampling | Queue < 10K |
| Export fail x3 | OTLP retry | Buffer locally | Successful export |

### 5.4 Backpressure Queue Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PRIORITY QUEUES                           │
├──────────────┬──────────────┬──────────────┬────────────────┤
│   P0 (L4/L5) │   P1 (L3)    │   P2 (L2)    │    P3 (L1)     │
│   [Block]    │  [10% Drop]  │  [Ring 10K]  │   [Ring 1K]    │
│   ∞ size     │   100K max   │   10K max    │    1K max      │
└──────────────┴──────────────┴──────────────┴────────────────┘
```

---

## 6.0 LEVEL 5: Cognitive AI Integration

### 6.1 OODA Loop Integration

```
OODA CYCLE → FRACTAL LOGGING
┌────────────────────────────────────────────────────────────┐
│                                                            │
│  OBSERVE ──→ L5.CognitiveMessage { observation: {...} }   │
│     │                                                      │
│     ▼                                                      │
│  ORIENT ──→ L5.CognitiveMessage { orientation: {...} }    │
│     │                                                      │
│     ▼                                                      │
│  DECIDE ──→ L5.CognitiveMessage { decision: {...} }       │
│     │                                                      │
│     ▼                                                      │
│   ACT ────→ L5.CognitiveMessage { action: {...} }         │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### 6.2 Cortex Self-Throttling

```fsharp
// Cortex subscribes to fractal load events
FractalControl.subscribe "@/fractal/system/load/**" (fun event ->
    match event with
    | LoadShed reason ->
        // Reduce OODA cycle frequency
        Cortex.setThrottleMode ThrottleMode.Conservative

    | LoadResume ->
        // Resume normal operations
        Cortex.setThrottleMode ThrottleMode.Normal
)
```

### 6.3 Decision Audit Trail (Blockchain-Ready)

```fsharp
// L5 messages with WAL persistence for compliance
type L5AuditEntry = {
    DecisionId: Guid
    OodaCycleId: Guid
    Timestamp: HLCTimestamp           // Causal ordering
    Decision: CognitiveMessage
    MerkleRoot: byte[]                // Tamper-evident
    PreviousHash: byte[]              // Chain link
    Signature: byte[] option          // Optional signing
}
```

---

## 7.0 CEPAF Container Implementation

### 7.1 podman-compose-fractal-standalone.yml

```yaml
version: "3.8"
name: indrajaal-fractal-standalone

services:
  # ========================================
  # FRACTAL CONTROL CONTAINER
  # ========================================
  indrajaal-app:
    image: localhost/indrajaal-app:latest
    container_name: indrajaal-fractal-app
    hostname: fractal-app
    environment:
      # Fractal Configuration
      - FRACTAL_ENABLED=true
      - FRACTAL_DEFAULT_LEVEL=L4
      - FRACTAL_HLC_ENABLED=true
      - FRACTAL_BATCH_SIZE=100
      - FRACTAL_BATCH_FLUSH_MS=10
      - FRACTAL_BLOOM_SIZE=10000
      - FRACTAL_BLOOM_FPR=0.01

      # Key Expression
      - FRACTAL_KEL_CACHE_SIZE=1000
      - FRACTAL_ALIAS_PRELOAD=true

      # Safety Constraints
      - FRACTAL_SHEDDING_CPU_THRESHOLD=90
      - FRACTAL_SHEDDING_MEMORY_THRESHOLD=85
      - FRACTAL_BOOST_MAX_TTL_MS=3600000

      # OTLP Export
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://indrajaal-obs:4317
      - OTEL_EXPORTER_OTLP_PROTOCOL=grpc
      - OTEL_SERVICE_NAME=indrajaal-fractal

      # Database
      - DATABASE_URL=ecto://postgres:postgres@indrajaal-db:5432/indrajaal_dev

    ports:
      - "4000:4000"
    volumes:
      - fractal-logs:/app/data/logs
      - fractal-wal:/app/data/wal
    depends_on:
      indrajaal-db:
        condition: service_healthy
      indrajaal-obs:
        condition: service_started
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '2'
        reservations:
          memory: 512M
          cpus: '1'

  # ========================================
  # DATABASE CONTAINER
  # ========================================
  indrajaal-db:
    image: localhost/indrajaal-db:latest
    container_name: indrajaal-fractal-db
    hostname: fractal-db
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=indrajaal_dev
    ports:
      - "5433:5432"
    volumes:
      - fractal-pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  # ========================================
  # OBSERVABILITY CONTAINER
  # ========================================
  indrajaal-obs:
    image: docker.io/signoz/signoz-otel-collector:0.88.11
    container_name: indrajaal-fractal-obs
    hostname: fractal-obs
    command:
      - "--config=/etc/otel-collector-config.yaml"
    ports:
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP
      - "8888:8888"   # Metrics
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml:ro
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'

  # ========================================
  # CEPAF BRIDGE CONTAINER
  # ========================================
  cepaf-bridge:
    image: localhost/cepaf-bridge:latest
    container_name: indrajaal-fractal-bridge
    hostname: fractal-bridge
    environment:
      - FRACTAL_LEVEL=L3
      - CEPAF_TRACE_PROPAGATION=true
      - CEPAF_OTLP_ENDPOINT=http://indrajaal-obs:4317
    ports:
      - "9876:9876"
    depends_on:
      - indrajaal-app
    volumes:
      - cepaf-state:/app/data/state
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: '0.25'

volumes:
  fractal-logs:
  fractal-wal:
  fractal-pgdata:
  cepaf-state:

networks:
  default:
    name: fractal-network
    driver: bridge
```

### 7.2 OTEL Collector Configuration

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s
    send_batch_size: 100
    send_batch_max_size: 1000

  # Fractal-aware processor
  attributes:
    actions:
      - key: fractal.level
        action: upsert
        from_attribute: fractal_level
      - key: fractal.priority
        action: upsert
        from_attribute: fractal_priority

exporters:
  logging:
    verbosity: detailed

  # SigNoz backend
  otlp/signoz:
    endpoint: signoz-otel-collector:4317
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, attributes]
      exporters: [logging, otlp/signoz]

    logs:
      receivers: [otlp]
      processors: [batch, attributes]
      exporters: [logging, otlp/signoz]

    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging, otlp/signoz]
```

---

## 8.0 Safety Constraints Verification

| Constraint | Description | Verification Method | Status |
|:-----------|:------------|:--------------------|:-------|
| SC-LOG-001 | Async dispatch (never block) | Unit test with blocking check | PENDING |
| SC-LOG-002 | Auto-throttle at CPU > 90% | Integration test with load | PENDING |
| SC-LOG-003 | PII masking at decorator | Property test | PENDING |
| SC-LOG-004 | L1/L2 must link to L3 TraceID | Trace correlation test | PENDING |
| SC-LOG-005 | Boosts require TTL | Boost expiration test | PENDING |
| SC-LOG-006 | L3+ logs MUST use HLC | HLC ordering test | PENDING |
| SC-LOG-007 | Batch flush within 10ms | Performance benchmark | PENDING |
| SC-LOG-008 | Write filter <1% false negative | Bloom accuracy test | PENDING |
| SC-LOG-009 | Key aliases pre-registered | Startup validation | PENDING |
| SC-LOG-010 | Admin space authenticated | Security audit | PENDING |

---

## 9.0 Implementation Order & Timeline

### Phase 1: Foundation (P0-CRITICAL)
```
[x] Types.fs - FractalLevel, Priority, Lens, Boost, HLC
[ ] FractalControl.fs - State machine, ETS-like storage
[ ] SafetyConstraints.fs - SC-LOG validation
```

### Phase 2: Core Features (P1-HIGH)
```
[ ] KeyExpression.fs - Zenoh wildcards (*, **, $*)
[ ] WriteFilter.fs - Bloom filter for emission control
[ ] Integration.fs - Bridge to QuadplexLogger
```

### Phase 3: Performance (P2-MEDIUM)
```
[ ] HLC.fs - Hybrid Logical Clock
[ ] BatchEncoder.fs - Wire optimization (70% savings)
[ ] ZenohWire.fs - 8-byte header protocol
```

### Phase 4: Advanced (P3-LOW)
```
[ ] ContentRouter.fs - Backend routing rules
[ ] AdminSpace.fs - @/fractal/* keyspace
[ ] Queryable.fs - On-demand log retrieval
```

### Phase 5: Container Deployment
```
[ ] podman-compose-fractal-standalone.yml
[ ] otel-collector-config.yaml
[ ] Container health checks
[ ] Volume persistence
```

---

**Document End - Reference: FRACTAL_LOGGING_SYSTEM_MASTER_GEMINI_v3.md**
