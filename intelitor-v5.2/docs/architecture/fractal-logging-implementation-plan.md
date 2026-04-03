# Fractal Logging System - Criticality-Based Implementation Plan

**Version**: 1.0.0
**Date**: 2025-12-25
**Status**: IMPLEMENTATION PLAN
**Context**: SOPv5.11 + STAMP + CEPAF Standalone

---

## 1.0 Executive Summary

This document provides a **5-level depth implementation plan** for the Fractal Logging System, organized by **criticality** (P0-P3). The implementation targets both:

1. **Elixir/Phoenix** (Indrajaal main application)
2. **F#/CEPAF** (Standalone orchestration environment)

### 1.1 Criticality Matrix

| Priority | Category | Components | Timeline | Risk |
|:--------:|:---------|:-----------|:---------|:-----|
| **P0** | Critical Infrastructure | FractalControl, 5-Level Types, Safety Constraints | Immediate | Low |
| **P1** | Core Features | KeyExpression, WriteFilter, Bloom Filter | Phase 1 | Medium |
| **P2** | Performance | HLC, BatchEncoder, ZenohWire | Phase 2 | Medium |
| **P3** | Advanced | ContentRouter, AdminSpace, Distributed | Phase 3 | Low |

---

## 2.0 P0-CRITICAL: Foundation Infrastructure

### Level 1: Atomic (Implementation Details)

#### 2.1.1 Elixir Modules

```
lib/indrajaal/observability/fractal/
├── fractal_control.ex       # GenServer managing lens state
├── types.ex                  # FractalLevel, Lens, Boost types
├── safety_constraints.ex     # SC-LOG-001 to SC-LOG-010
├── ets_manager.ex            # ETS table initialization
└── config.ex                 # Configuration parsing
```

**FractalLevel Type Definition**:
```elixir
defmodule Indrajaal.Observability.Fractal.Types do
  @type fractal_level :: :L1 | :L2 | :L3 | :L4 | :L5
  @type priority :: :P0 | :P1 | :P2 | :P3

  @type lens :: %{
    target: String.t(),           # Key expression
    depth: fractal_level(),       # Zoom level
    filter: map(),                # Context filters
    ttl_ms: non_neg_integer()     # Time-to-live
  }

  @type boost :: %{
    id: String.t(),
    key_expr: String.t(),
    depth: fractal_level(),
    filter: map(),
    created_at: DateTime.t(),
    expires_at: DateTime.t(),
    created_by: String.t()
  }
end
```

#### 2.1.2 F#/CEPAF Modules

```
lib/cepaf/src/Cepaf/Observability/Fractal/
├── Types.fs                  # FractalLevel, Lens, Boost types
├── FractalControl.fs         # Central state manager
├── SafetyConstraints.fs      # SC-LOG validation
└── Configuration.fs          # Config binding
```

**FractalLevel Type Definition (F#)**:
```fsharp
namespace Cepaf.Observability.Fractal

[<RequireQualifiedAccess>]
type FractalLevel =
    | L1  // Atomic: Function args, return values
    | L2  // Component: GenServer state, messages
    | L3  // Transactional: Business flows, TraceID
    | L4  // Systemic: Node health, network
    | L5  // Cognitive: Intent, hypotheses, confidence

[<RequireQualifiedAccess>]
type Priority =
    | P0  // Never drop (L4/L5)
    | P1  // 10% sampling (L3)
    | P2  // Conditional (L2)
    | P3  // Debug only (L1)

type Lens = {
    Target: string              // Zenoh key expression
    Depth: FractalLevel
    Filter: Map<string, string> // Context filters
    TtlMs: int64                // Time-to-live
}

type Boost = {
    Id: string
    KeyExpr: string
    Depth: FractalLevel
    Filter: Map<string, string>
    CreatedAt: DateTimeOffset
    ExpiresAt: DateTimeOffset
    CreatedBy: string
}
```

### Level 2: Component (Module Design)

#### 2.2.1 FractalControl GenServer (Elixir)

**State Structure**:
```elixir
defmodule Indrajaal.Observability.FractalControl.State do
  defstruct [
    default_policy: :L4,
    policies: %{},              # module => level
    boosts: [],                 # active boosts
    ets_table: :fractal_config,
    subscribers: %{},           # pid => key_expr
    shedding: false             # load shedding active?
  ]
end
```

**Key Operations**:
- `depth_enabled?/3` - O(1) ETS lookup for logging decision
- `apply_boost/1` - Activate temporary depth increase
- `expire_boosts/0` - Remove expired boosts
- `activate_shedding/0` - Emergency load reduction

#### 2.2.2 FractalControl Agent (F#)

**State Structure**:
```fsharp
type FractalControlState = {
    DefaultPolicy: FractalLevel
    Policies: Map<string, FractalLevel>
    Boosts: Boost list
    Shedding: bool
    LastUpdate: DateTimeOffset
}

module FractalControl =
    let mutable private state = {
        DefaultPolicy = FractalLevel.L4
        Policies = Map.empty
        Boosts = []
        Shedding = false
        LastUpdate = DateTimeOffset.UtcNow
    }

    let depthEnabled (key: string) (level: FractalLevel) : bool =
        // Fast path: check if level >= default policy
        // Slow path: check module-specific policies
        // Boost path: check active boosts
```

### Level 3: Transactional (Business Use Cases)

| Use Case | FractalLevel | Trigger | Data Captured |
|:---------|:-------------|:--------|:--------------|
| Production Monitoring | L4 | Always on | CPU, memory, network |
| User Journey Tracing | L3 | TraceID present | Business events, latency |
| Debug Session | L1 | Operator boost | Function args, return values |
| AI Decision Audit | L5 | Cortex activity | Intent, confidence, reasoning |
| Performance Profiling | L2 | Module override | State transitions, ETS ops |

### Level 4: Systemic (Operational Concerns)

**ETS Table Configuration**:
```elixir
:ets.new(:fractal_config, [
  :ordered_set,
  :public,
  :named_table,
  {:read_concurrency, true},
  {:write_concurrency, false}
])
```

**Performance Targets**:
| Metric | Target | Measurement |
|:-------|:-------|:------------|
| ETS Lookup | < 1µs | `should_log?/3` |
| Boost Apply | < 100µs | GenServer call |
| Memory Overhead | < 10MB | ETS table size |

### Level 5: Cognitive (AI Integration)

**Cortex Integration Points**:
- L5 logs capture OODA loop decisions
- Auto-boost on anomaly detection
- Self-throttling during high load
- Decision replay for audit

---

## 3.0 P1-HIGH: Key Expression Engine

### Level 1: Atomic (Implementation Details)

#### 3.1.1 Key Expression Syntax

```
┌─────────────────────────────────────────────────────────────────┐
│                    ZENOH KEY EXPRESSION LANGUAGE                 │
├─────────────────────────────────────────────────────────────────┤
│  *   = Match single path segment (e.g., Indrajaal/*/create)     │
│  **  = Match any path (e.g., Indrajaal/**/error)                │
│  $*  = Match within segment (e.g., Indrajaal/Alarms/$*Handler)  │
└─────────────────────────────────────────────────────────────────┘
```

#### 3.1.2 Elixir Implementation

```elixir
defmodule Indrajaal.Observability.Fractal.KeyExpression do
  @doc "Compile key expression to optimized regex"
  def compile(expr) do
    pattern = expr
      |> String.replace(".", "/")
      |> String.replace("$*", "([^/]*)")
      |> String.replace("**", "(.*)")
      |> String.replace("*", "([^/]+)")

    {:ok, Regex.compile!("^#{pattern}$")}
  end

  @doc "O(1) match against compiled pattern"
  def matches?(compiled, key), do: Regex.match?(compiled, key)
end
```

#### 3.1.3 F# Implementation

```fsharp
module Cepaf.Observability.Fractal.KeyExpression

open System.Text.RegularExpressions

type CompiledExpr = Regex

let compile (expr: string) : Result<CompiledExpr, string> =
    try
        let pattern =
            expr
                .Replace(".", "/")
                .Replace("$*", "([^/]*)")
                .Replace("**", "(.*)")
                .Replace("*", "([^/]+)")
        Ok(Regex($"^{pattern}$", RegexOptions.Compiled))
    with ex ->
        Error ex.Message

let matches (compiled: CompiledExpr) (key: string) : bool =
    compiled.IsMatch(key)
```

### Level 2: Component (Module Design)

**WriteFilter with Bloom Filter**:
```elixir
defmodule Indrajaal.Observability.Fractal.WriteFilter do
  @moduledoc """
  Publisher-side emission filtering using Bloom filter.
  SC-LOG-008: < 1% false negative rate
  """

  def should_emit?(key, level) do
    case BloomFilter.maybe_member?(:write_filter, {key, level}) do
      false -> :skip  # Definitely no subscribers
      true -> if has_subscribers?(key, level), do: :emit, else: :skip
    end
  end
end
```

### Level 3: Transactional (Business Use Cases)

| Pattern | Example | Use Case |
|:--------|:--------|:---------|
| `Indrajaal/**/create` | Any create function | Audit trail |
| `**/error` | Any error event | Error tracking |
| `Indrajaal/Accounts/**` | All Accounts domain | Domain debugging |
| `Indrajaal/Cortex/$*Sensor` | Any Cortex sensor | AI monitoring |

### Level 4: Systemic (Operational Concerns)

**Key Alias Registry** (for wire optimization):
```elixir
# Registration (startup)
KeyRegistry.register("Indrajaal.Accounts.User.create")  # => 0x1A2B

# Wire format uses 16-bit alias
<<0x1A, 0x2B>>  # 2 bytes vs 40 bytes
```

### Level 5: Cognitive (AI Integration)

- Pattern evolution detection (new error patterns)
- Semantic grouping of similar key expressions
- Auto-suggestion for boost targeting

---

## 4.0 P2-MEDIUM: Performance Optimization

### Level 1: Atomic (Implementation Details)

#### 4.1.1 Hybrid Logical Clock (HLC)

```elixir
defmodule Indrajaal.Observability.Fractal.HLC do
  @moduledoc """
  Hybrid Logical Clock for causal ordering.
  SC-LOG-006: L3+ logs MUST use HLC timestamps.
  """

  defstruct [:physical, :counter, :node_id]

  def now do
    ref = :persistent_term.get(__MODULE__)
    physical = System.os_time(:microsecond)
    counter = :atomics.add_get(ref, 1, 1)
    {physical, counter, Node.self()}
  end

  def compare(%{physical: p1, counter: c1}, %{physical: p2, counter: c2}) do
    cond do
      p1 != p2 -> if p1 < p2, do: :lt, else: :gt
      c1 != c2 -> if c1 < c2, do: :lt, else: :gt
      true -> :eq
    end
  end
end
```

#### 4.1.2 F# HLC Implementation

```fsharp
module Cepaf.Observability.Fractal.HLC

open System
open System.Threading

type HLCTimestamp = {
    Physical: int64
    Counter: int
    NodeId: string
}

let mutable private counter = 0

let now () : HLCTimestamp =
    let physical = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() * 1000L
    let cnt = Interlocked.Increment(&counter)
    { Physical = physical; Counter = cnt; NodeId = Environment.MachineName }

let compare (a: HLCTimestamp) (b: HLCTimestamp) : int =
    match compare a.Physical b.Physical with
    | 0 -> compare a.Counter b.Counter
    | r -> r
```

### Level 2: Component (Module Design)

**BatchEncoder** (70% wire savings):
```elixir
defmodule Indrajaal.Observability.Fractal.BatchEncoder do
  @max_batch_size 100
  @max_batch_age_ms 10

  def encode_batch(messages, trace_id, batch_start) do
    <<
      0xFB, 0x01,               # Magic bytes
      length(messages)::16,     # Count
      trace_id::binary,         # Shared trace ID
      encode_deltas(messages, batch_start)::binary
    >>
  end
end
```

### Level 3: Transactional (Business Use Cases)

| Metric | Without Batching | With Batching | Savings |
|:-------|:-----------------|:--------------|:--------|
| 100 L1 logs | 4,000 bytes | 1,220 bytes | 70% |
| Network overhead | 100 packets | 1 packet | 99% |

### Level 4: Systemic (Operational Concerns)

**Performance Targets**:
| Component | Target | Measurement |
|:----------|:-------|:------------|
| HLC.now/0 | < 100ns | Atomic increment |
| Batch flush | < 10ms | SC-LOG-007 |
| Wire encoding | < 1ms | 100 messages |

### Level 5: Cognitive (AI Integration)

- Predictive batching based on load patterns
- Adaptive batch size during traffic spikes
- HLC drift detection and correction

---

## 5.0 P3-LOW: Advanced Features

### Level 1: Atomic (Implementation Details)

**ContentRouter**:
```elixir
defmodule Indrajaal.Observability.Fractal.ContentRouter do
  @routes [
    {"Indrajaal/**", [:L4, :L5], [SigNoz]},
    {"Indrajaal/Security/**", [:L1, :L2, :L3, :L4, :L5], [SecuritySIEM]},
    {"Indrajaal/Cortex/**", [:L5], [AuditLog, BlockchainLedger]},
    {"**/error", [:L1, :L2, :L3, :L4, :L5], [ErrorTracker]}
  ]
end
```

**AdminSpace**:
```elixir
defmodule Indrajaal.Observability.Fractal.AdminSpace do
  @admin_keys %{
    "config/global" => :get_set_global_depth,
    "config/module/*" => :get_set_module_depth,
    "boosts/active" => :list_boosts,
    "emergency/shed_load" => :trigger_shed
  }
end
```

### Level 2-5: (See main spec document)

---

## 6.0 CEPAF Standalone Container Integration

### 6.1 Container Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    FRACTAL LOGGING CONTAINERS                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │ indrajaal-app│  │ indrajaal-db │  │ indrajaal-obs│           │
│  │ (Phoenix)    │  │ (PostgreSQL) │  │ (SigNoz)     │           │
│  │ Port: 4000   │  │ Port: 5433   │  │ Port: 8123   │           │
│  └──────┬───────┘  └──────────────┘  └──────┬───────┘           │
│         │                                    │                   │
│         │     ┌──────────────────────┐       │                   │
│         │     │   FRACTAL CONTROL    │       │                   │
│         └────►│   (ETS + HLC + KEL)  │◄──────┘                   │
│               │   L1-L5 Routing      │                           │
│               └──────────────────────┘                           │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │ cepaf-bridge │  │ FLAME Runner │  │ Test Runner  │           │
│  │ (F#/.NET)    │  │ (Ephemeral)  │  │ (PropCheck)  │           │
│  │ Port: 9876   │  │ Dynamic      │  │ MIX_ENV=test │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 podman-compose-fractal-standalone.yml

```yaml
version: "3.8"
name: indrajaal-fractal

services:
  fractal-control:
    image: localhost/indrajaal-app:latest
    container_name: fractal-control
    environment:
      - FRACTAL_DEFAULT_LEVEL=L4
      - FRACTAL_HLC_ENABLED=true
      - FRACTAL_BATCH_SIZE=100
      - FRACTAL_BATCH_FLUSH_MS=10
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://indrajaal-obs:4317
    ports:
      - "4000:4000"
    depends_on:
      - indrajaal-db
      - indrajaal-obs

  indrajaal-db:
    image: localhost/indrajaal-db:latest
    container_name: indrajaal-db
    environment:
      - POSTGRES_USER=indrajaal
      - POSTGRES_PASSWORD=indrajaal_dev
    ports:
      - "5433:5432"

  indrajaal-obs:
    image: docker.io/signoz/signoz-otel-collector:latest
    container_name: indrajaal-obs
    ports:
      - "4317:4317"  # OTLP gRPC
      - "4318:4318"  # OTLP HTTP
      - "8123:8123"  # ClickHouse (for queries)

  cepaf-bridge:
    image: localhost/cepaf-bridge:latest
    container_name: cepaf-bridge
    environment:
      - FRACTAL_LEVEL=L3
      - CEPAF_TRACE_PROPAGATION=true
    ports:
      - "9876:9876"
    depends_on:
      - fractal-control
```

---

## 7.0 Safety Constraints (SC-LOG)

| ID | Constraint | Verification |
|:---|:-----------|:-------------|
| SC-LOG-001 | Async dispatch (never block) | Unit test with blocking check |
| SC-LOG-002 | Auto-throttle at CPU > 90% | Integration test with load |
| SC-LOG-003 | PII masking at decorator | Property test with sensitive data |
| SC-LOG-004 | L1/L2 must link to L3 TraceID | Trace correlation test |
| SC-LOG-005 | Boosts require TTL (default 5min) | Boost expiration test |
| SC-LOG-006 | L3+ logs MUST use HLC timestamps | HLC ordering test |
| SC-LOG-007 | Batch flush MUST occur within 10ms | Performance benchmark |
| SC-LOG-008 | Write filter <1% false negative | Bloom filter accuracy test |
| SC-LOG-009 | Key aliases pre-registered at startup | Startup validation |
| SC-LOG-010 | Admin space operations authenticated | Security audit |

---

## 8.0 Implementation Order

### Phase 1: Foundation (P0)
1. Create `Types.fs` / `types.ex` with FractalLevel definitions
2. Implement `FractalControl` GenServer/Agent
3. Setup ETS tables with proper configuration
4. Add safety constraints validation

### Phase 2: Core Features (P1)
1. Implement `KeyExpression` module with wildcards
2. Add `WriteFilter` with Bloom filter
3. Create key alias registry
4. Integrate with existing QuadplexLogger

### Phase 3: Performance (P2)
1. Implement `HLC` module
2. Add `BatchEncoder` for wire optimization
3. Create `ZenohWire` protocol encoder
4. Performance benchmarking

### Phase 4: Advanced (P3)
1. Implement `ContentRouter`
2. Add `AdminSpace` with `@/fractal/*` keyspace
3. Distributed storage integration
4. CLI commands (`mix fractal.*`)

---

## 9.0 Verification Commands

```bash
# P0: Foundation
mix compile --warnings-as-errors
mix test test/indrajaal/observability/fractal/types_test.exs

# P1: Key Expression
mix fractal.test.kel

# P2: Performance
mix fractal.bench.hlc
mix fractal.bench.batch

# P3: Integration
mix fractal.status --zenoh
mix fractal.focus --expr "Indrajaal/**/create" --depth L1 --ttl 300000
```

---

**Document End**
