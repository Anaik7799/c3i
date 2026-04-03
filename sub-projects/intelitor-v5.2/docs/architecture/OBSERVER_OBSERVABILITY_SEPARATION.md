# Observer-Observability Separation Architecture

**Version**: 21.3.0-SIL6 | **Date**: 2026-01-11 | **Status**: ACTIVE
**Principle**: OODA-Aligned Cybernetic Control

---

## Executive Summary

This document defines the **Observer-Observability Separation** principle that governs all monitoring, telemetry, and meta-cognitive operations across the Indrajaal fractal architecture. This separation is critical for:

1. **Avoiding Infinite Recursion**: Preventing observers from observing themselves indefinitely
2. **Maintaining Clean Boundaries**: Clear delineation between active monitoring and passive metrics
3. **Enabling Meta-Cognition**: Allowing the system to observe its own observation processes
4. **Supporting OODA Loops**: Separating Observe phase from the system being observed

---

## 1.0 Core Principle

### 1.1 Definition

```
┌─────────────────────────────────────────────────────────────────┐
│                    THE FUNDAMENTAL SEPARATION                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                      OBSERVER                            │    │
│  │                                                           │    │
│  │  • ACTIVE component                                       │    │
│  │  • Polls, queries, analyzes                              │    │
│  │  • Makes decisions based on observations                 │    │
│  │  • Has agency (can take action)                          │    │
│  │  • Consumes resources                                    │    │
│  │                                                           │    │
│  └──────────────────────┬──────────────────────────────────┘    │
│                         │                                        │
│                         │ OBSERVES                               │
│                         ▼                                        │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    OBSERVABILITY                         │    │
│  │                                                           │    │
│  │  • PASSIVE property                                       │    │
│  │  • Emits metrics, traces, logs                           │    │
│  │  • Does not make decisions                               │    │
│  │  • Has no agency (only provides data)                    │    │
│  │  • Minimal overhead                                       │    │
│  │                                                           │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  KEY RULE: Observer ∩ Observed = ∅ (disjoint sets)              │
│            No component can be both observer AND observed        │
│            at the SAME level for the SAME property               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Mathematical Formulation

Let $O$ be the set of all observers and $B$ be the set of all observable components.

**Separation Axiom**:
$$\forall o \in O, b \in B : \text{level}(o) \neq \text{level}(b) \lor \text{property}(o) \neq \text{property}(b)$$

**Meta-Observation Rule**:
$$\text{Observer}_n \text{ observes } \text{Observable}_{n-1}$$
$$\text{Observer}_{n+1} \text{ observes } \text{Observer}_n$$

**Termination Condition**:
$$\exists \text{Constitutional Observer} : \text{not observable}$$

---

## 2.0 OODA Loop Integration

### 2.1 OODA Phases and Separation

```
┌─────────────────────────────────────────────────────────────────┐
│                    OODA LOOP SEPARATION                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  OBSERVE ─────────────────────────────────────────────────────  │
│     │                                                            │
│     │  Observer: Sensor/Collector                               │
│     │  Observability: Metrics, Traces, Logs                     │
│     │  Separation: Sensor process ≠ Metric emission            │
│     │                                                            │
│     ▼                                                            │
│  ORIENT ──────────────────────────────────────────────────────  │
│     │                                                            │
│     │  Observer: Analyzer/Pattern Detector                      │
│     │  Observability: Observation data from OBSERVE             │
│     │  Separation: Analysis process ≠ Raw data                 │
│     │                                                            │
│     ▼                                                            │
│  DECIDE ──────────────────────────────────────────────────────  │
│     │                                                            │
│     │  Observer: Decision Engine                                │
│     │  Observability: Analysis output from ORIENT               │
│     │  Separation: Decision process ≠ Analysis data            │
│     │                                                            │
│     ▼                                                            │
│  ACT ─────────────────────────────────────────────────────────  │
│     │                                                            │
│     │  Observer: Executor                                       │
│     │  Observability: Decision output from DECIDE               │
│     │  Separation: Execution ≠ Decision record                 │
│     │                                                            │
│     └──────────────────────────────────────────────────────────  │
│                                                                  │
│  Each phase has its own Observer-Observability pair             │
│  Phase N+1 observes the output of Phase N                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 OODA at Each Fractal Level

| Level | OBSERVE | ORIENT | DECIDE | ACT |
|-------|---------|--------|--------|-----|
| L0 | Compile errors | Error classification | Fix strategy | Code change |
| L1 | Process state | Pattern matching | Restart decision | Process action |
| L2 | Cluster events | Membership analysis | Partition handling | Topology update |
| L3 | Request metrics | Anomaly detection | Rate limiting | Traffic control |
| L4 | System KPIs | Trend analysis | Resource allocation | Scaling action |
| L5 | Mesh topology | Health assessment | Routing decision | Mesh update |
| L6 | Model metrics | Evolution analysis | Proposal selection | Code deployment |
| L7 | Invariant status | Violation analysis | Corrective action | Constitutional enforcement |

---

## 3.0 Per-Level Separation Architecture

### 3.1 L0 Quantum Level

```
┌─────────────────────────────────────────────────────────────────┐
│                    L0 QUANTUM SEPARATION                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  OBSERVER: Dialyzer / Type Checker                              │
│  ─────────────────────────────────────────                      │
│  • Runs at compile time                                         │
│  • Analyzes type annotations                                    │
│  • Produces warnings/errors                                     │
│  • Process: elixir compiler + dialyzer                         │
│                                                                  │
│  OBSERVABILITY: @spec, @type annotations                        │
│  ─────────────────────────────────────────                      │
│  • Static metadata in source code                               │
│  • Zero runtime overhead                                        │
│  • Immutable once compiled                                      │
│                                                                  │
│  SEPARATION MECHANISM:                                          │
│  • Time: Compile-time (observer) vs Static (observability)     │
│  • Process: Compiler (observer) vs Source AST (observability)  │
│                                                                  │
│  METRICS EMITTED:                                               │
│    compile_time_seconds, type_errors_count,                     │
│    warning_count, spec_coverage_percent                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 L1 Cellular Level

```
┌─────────────────────────────────────────────────────────────────┐
│                    L1 CELLULAR SEPARATION                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  OBSERVER: Process Supervisor / Sentinel                        │
│  ─────────────────────────────────────────                      │
│  • Runs as separate BEAM process                                │
│  • Monitors linked processes                                    │
│  • Receives EXIT signals                                        │
│  • Makes restart decisions                                      │
│                                                                  │
│  OBSERVABILITY: Process State / Mailbox                         │
│  ─────────────────────────────────────────                      │
│  • GenServer state                                              │
│  • Message queue depth                                          │
│  • Heap size                                                    │
│  • Reductions count                                             │
│                                                                  │
│  SEPARATION MECHANISM:                                          │
│  • Process isolation (different PIDs)                           │
│  • Supervisor tree structure                                    │
│  • OTP behaviors (GenServer, Supervisor)                        │
│                                                                  │
│  METRICS EMITTED:                                               │
│    process_memory_bytes, mailbox_length,                        │
│    reductions_total, gc_count, restart_count                    │
│                                                                  │
│  ┌─────────────┐              ┌─────────────┐                   │
│  │ Supervisor  │◀───monitors──│   Holon     │                   │
│  │ (Observer)  │              │ (Observed)  │                   │
│  └─────────────┘              └─────────────┘                   │
│        │                             │                           │
│        │                             │                           │
│        └─────────────────────────────┘                           │
│         Different processes, linked via OTP                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.3 L2 Tissue Level

```
┌─────────────────────────────────────────────────────────────────┐
│                    L2 TISSUE SEPARATION                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  OBSERVER: Cluster Monitor / Horde Supervisor                   │
│  ─────────────────────────────────────────                      │
│  • Runs on dedicated monitor node                               │
│  • Subscribes to cluster events                                 │
│  • Tracks node membership                                       │
│  • Detects partitions                                           │
│                                                                  │
│  OBSERVABILITY: Node State / CRDT State                         │
│  ─────────────────────────────────────────                      │
│  • Node membership list                                         │
│  • CRDT convergence state                                       │
│  • Network connectivity                                         │
│  • Partition status                                             │
│                                                                  │
│  SEPARATION MECHANISM:                                          │
│  • Node isolation (different Erlang nodes)                      │
│  • Out-of-band health channel                                   │
│  • Gossip protocol vs. direct observation                       │
│                                                                  │
│  METRICS EMITTED:                                               │
│    cluster_size, partition_count, gossip_rounds,                │
│    crdt_merge_count, node_connectivity_percent                  │
│                                                                  │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐           │
│  │  Monitor    │   │   Node A    │   │   Node B    │           │
│  │   Node      │◀──│   (CRDT)    │◀──│   (CRDT)    │           │
│  │ (Observer)  │   │ (Observed)  │   │ (Observed)  │           │
│  └─────────────┘   └─────────────┘   └─────────────┘           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.4 L3 Organ Level

```
┌─────────────────────────────────────────────────────────────────┐
│                    L3 ORGAN SEPARATION                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  OBSERVER: Telemetry Middleware / Domain Supervisor             │
│  ─────────────────────────────────────────                      │
│  • Plug pipeline middleware                                     │
│  • Ash action callbacks                                         │
│  • Domain supervisor                                            │
│  • Request tracer                                               │
│                                                                  │
│  OBSERVABILITY: Request Metrics / Service State                 │
│  ─────────────────────────────────────────                      │
│  • Request latency                                              │
│  • Error counts                                                 │
│  • Throughput                                                   │
│  • Active connections                                           │
│                                                                  │
│  SEPARATION MECHANISM:                                          │
│  • Middleware chain (observer before/after observed)            │
│  • Telemetry event system                                       │
│  • Separate metric storage                                      │
│                                                                  │
│  METRICS EMITTED:                                               │
│    request_duration_ms, request_count,                          │
│    error_rate, active_connections, queue_depth                  │
│                                                                  │
│  Request Flow:                                                  │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐     │
│  │Telemetry │──▶│ Service  │──▶│ Response │──▶│Telemetry │     │
│  │  START   │   │ Handler  │   │          │   │   END    │     │
│  │(Observer)│   │(Observed)│   │          │   │(Observer)│     │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.5 L4 Organism Level

```
┌─────────────────────────────────────────────────────────────────┐
│                    L4 ORGANISM SEPARATION                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  OBSERVER: Prajna Controller / SmartMetrics                     │
│  ─────────────────────────────────────────                      │
│  • Dedicated control plane process                              │
│  • Health score calculator                                      │
│  • Threat assessor                                              │
│  • Active inference engine                                      │
│                                                                  │
│  OBSERVABILITY: System KPIs / Component Health                  │
│  ─────────────────────────────────────────                      │
│  • Overall health score (0-100)                                 │
│  • Threat level                                                 │
│  • Agent status                                                 │
│  • Resource utilization                                         │
│                                                                  │
│  SEPARATION MECHANISM:                                          │
│  • Control plane isolation                                      │
│  • Phoenix PubSub topics                                        │
│  • Zenoh control topics                                         │
│                                                                  │
│  METRICS EMITTED:                                               │
│    health_score, threat_level, agent_count,                     │
│    cpu_percent, memory_percent, ooda_cycle_ms                   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    PRAJNA COCKPIT                        │    │
│  │  ┌─────────────┐                  ┌─────────────────┐   │    │
│  │  │  Controller │◀───observes─────│   L1-L3 Layers  │   │    │
│  │  │  (Observer) │                  │   (Observed)    │   │    │
│  │  └─────────────┘                  └─────────────────┘   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.6 L5 Ecosystem Level

```
┌─────────────────────────────────────────────────────────────────┐
│                    L5 ECOSYSTEM SEPARATION                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  OBSERVER: Mesh Coordinator / Federation Monitor                │
│  ─────────────────────────────────────────                      │
│  • Zenoh subscriber                                             │
│  • Topology manager                                             │
│  • Quorum checker                                               │
│  • Federation protocol handler                                  │
│                                                                  │
│  OBSERVABILITY: Zenoh Topics / Mesh State                       │
│  ─────────────────────────────────────────                      │
│  • Topic streams                                                │
│  • Node connectivity                                            │
│  • Replication lag                                              │
│  • Federation peer status                                       │
│                                                                  │
│  SEPARATION MECHANISM:                                          │
│  • Zenoh topic namespaces                                       │
│  • Control plane (indrajaal/mesh/control)                       │
│  • Data plane (indrajaal/mesh/data)                             │
│                                                                  │
│  TOPIC SEPARATION:                                              │
│    Control: indrajaal/mesh/control/**                           │
│    Data:    indrajaal/mesh/data/**                              │
│    Meta:    indrajaal/mesh/meta/** (observer of observers)      │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    ZENOH ROUTER                            │  │
│  │                                                             │  │
│  │   Control Plane        │        Data Plane                 │  │
│  │   (Observer topics)    │        (Observed data)            │  │
│  │                        │                                    │  │
│  │   /mesh/control        │        /mesh/data                 │  │
│  │   /mesh/meta           │        /metrics/**                │  │
│  │                        │        /logs/**                   │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.7 L6 Biosphere Level

```
┌─────────────────────────────────────────────────────────────────┐
│                    L6 BIOSPHERE SEPARATION                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  OBSERVER: AI Orchestrator / GDE Controller                     │
│  ─────────────────────────────────────────                      │
│  • Model performance tracker                                    │
│  • Evolution fitness calculator                                 │
│  • Consensus engine                                             │
│  • Training gym coordinator                                     │
│                                                                  │
│  OBSERVABILITY: Model Metrics / Evolution State                 │
│  ─────────────────────────────────────────                      │
│  • API latency                                                  │
│  • Token usage                                                  │
│  • Accuracy scores                                              │
│  • Proposal success rate                                        │
│                                                                  │
│  SEPARATION MECHANISM:                                          │
│  • Separate metrics store (DuckDB)                              │
│  • Async observation                                            │
│  • Background workers                                           │
│                                                                  │
│  METRICS EMITTED:                                               │
│    api_latency_ms, tokens_used, accuracy_score,                 │
│    proposal_success_rate, evolution_fitness                     │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    AI/ML LAYER                           │    │
│  │                                                           │    │
│  │   ┌──────────────┐         ┌──────────────┐             │    │
│  │   │  Orchestrator│◀────────│  AI Models   │             │    │
│  │   │  (Observer)  │         │  (Observed)  │             │    │
│  │   │              │         │              │             │    │
│  │   │  - Tracks    │         │  - Claude    │             │    │
│  │   │  - Analyzes  │         │  - Gemini    │             │    │
│  │   │  - Decides   │         │  - Grok      │             │    │
│  │   └──────────────┘         └──────────────┘             │    │
│  │         │                                                │    │
│  │         ▼                                                │    │
│  │   ┌──────────────┐                                       │    │
│  │   │   DuckDB     │ (Separate metrics storage)           │    │
│  │   │   History    │                                       │    │
│  │   └──────────────┘                                       │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.8 L7 Constitutional Level

```
┌─────────────────────────────────────────────────────────────────┐
│                    L7 CONSTITUTIONAL SEPARATION                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  OBSERVER: Guardian Verifier / Constitutional Checker           │
│  ─────────────────────────────────────────                      │
│  • Invariant verification                                       │
│  • Founder Directive alignment                                  │
│  • Proof token validation                                       │
│  • Veto authority                                               │
│                                                                  │
│  OBSERVABILITY: Audit Log / Immutable Register                  │
│  ─────────────────────────────────────────                      │
│  • All state mutations                                          │
│  • Constitutional decisions                                     │
│  • Veto events                                                  │
│  • Amendment proposals                                          │
│                                                                  │
│  SEPARATION MECHANISM:                                          │
│  • Immutable Register (append-only)                             │
│  • Ed25519 signatures                                           │
│  • SHA3-256 hash chain                                          │
│                                                                  │
│  SPECIAL PROPERTY: L7 Observer CANNOT be observed               │
│  ─────────────────────────────────────────                      │
│  • Terminal node in observation hierarchy                       │
│  • Self-verifying via hash chain                                │
│  • No meta-observer exists                                      │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    CONSTITUTIONAL CORE                   │    │
│  │                                                           │    │
│  │   ┌──────────────┐         ┌──────────────┐             │    │
│  │   │   Guardian   │◀────────│  L0-L6       │             │    │
│  │   │   Verifier   │         │  Observers   │             │    │
│  │   │  (Terminal)  │         │  (Observed)  │             │    │
│  │   │              │         │              │             │    │
│  │   │  CANNOT BE   │         │              │             │    │
│  │   │  OBSERVED    │         │              │             │    │
│  │   └──────────────┘         └──────────────┘             │    │
│  │         │                                                │    │
│  │         ▼                                                │    │
│  │   ┌──────────────┐                                       │    │
│  │   │  Immutable   │ (Self-verifying via hash chain)      │    │
│  │   │  Register    │                                       │    │
│  │   └──────────────┘                                       │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4.0 Meta-Observation Hierarchy

### 4.1 The Three-Level Meta-Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                    META-OBSERVATION STACK                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  META-2: Constitutional Observer (L7)                           │
│     │    ├── Observes: All layer observers (L0-L6)             │
│     │    ├── Cannot be observed (terminal)                      │
│     │    └── Self-verifies via hash chain                       │
│     │                                                            │
│     └──▶ META-1: System Observer (L4 Prajna)                    │
│           │    ├── Observes: Domain observers (L1-L3)           │
│           │    ├── Observed by: Constitutional (L7)             │
│           │    └── Reports to Prajna Cockpit                    │
│           │                                                      │
│           └──▶ META-0: Domain Observers (L1-L3)                 │
│                 │    ├── Observes: Raw components               │
│                 │    ├── Observed by: System (L4)               │
│                 │    └── Emits telemetry                        │
│                 │                                                │
│                 └──▶ LEVEL-0: Raw Components                    │
│                           ├── Holons, Services, State           │
│                           ├── Observed by: Domain observers     │
│                           └── No observation capability         │
│                                                                  │
│  RULES:                                                          │
│    1. Meta-N observes Meta-(N-1)                                │
│    2. Meta-N+1 observes Meta-N                                  │
│    3. Meta-2 (L7) is terminal                                   │
│    4. No component observes itself                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Observation Scope Rules

| Observer Level | Can Observe | Cannot Observe |
|----------------|-------------|----------------|
| L7 Constitutional | L0-L6 all | Self (terminal) |
| L6 Biosphere | L0-L5 all | L6 AI (own models) |
| L5 Ecosystem | L0-L4 all | L5 Mesh (own coordination) |
| L4 Organism | L1-L3 | L0, L4-L7 |
| L3 Organ | L1-L2 services | L0, L3-L7 |
| L2 Tissue | L1 clusters | L0, L2-L7 |
| L1 Cellular | L1 processes | L0, L2-L7 |

---

## 5.0 Implementation Patterns

### 5.1 Elixir Pattern: Supervisor/Worker

```elixir
defmodule Indrajaal.ObservableWorker do
  @moduledoc """
  OBSERVABILITY: Emits metrics, does not observe.

  Metrics emitted:
    - process_memory_bytes
    - mailbox_length
    - request_count
  """
  use GenServer

  # Only emit, never observe
  def handle_info(:work, state) do
    :telemetry.execute([:worker, :work], %{duration: 100}, %{})
    {:noreply, state}
  end
end

defmodule Indrajaal.ProcessObserver do
  @moduledoc """
  OBSERVER: Monitors processes, makes decisions.

  Observes:
    - Process state via :erlang.process_info
    - Telemetry events from workers
  """
  use GenServer

  # Observe and decide
  def handle_info({:telemetry_event, event}, state) do
    if should_restart?(event) do
      restart_worker()
    end
    {:noreply, state}
  end

  # Observer MUST NOT emit metrics about itself (separation)
end
```

### 5.2 F# Pattern: Reader/Writer Separation

```fsharp
// OBSERVABILITY: State that can be observed
module ObservableState =
    type SystemState = {
        Health: float
        Threats: int
        Uptime: TimeSpan
    }

    // Only provide data, no logic
    let emit (state: SystemState) : Metrics =
        { health = state.Health
          threats = state.Threats
          uptime = state.Uptime.TotalSeconds }

// OBSERVER: Component that watches and decides
module StateObserver =
    open ObservableState

    // Observe and analyze
    let observe (state: SystemState) : Decision =
        if state.Health < 50.0 then
            ScaleUp
        elif state.Threats > 10 then
            Alert
        else
            NoAction

    // Observer MUST NOT modify state directly
```

### 5.3 Zenoh Pattern: Topic Namespace Separation

```yaml
# Observability topics (data plane)
indrajaal/data/:
  health/{node}:     # Health metrics
  metrics/{node}/**:  # Performance data
  logs/{node}/**:     # Log streams

# Observer topics (control plane)
indrajaal/control/:
  commands/**:       # Control commands
  decisions/**:      # Decision outputs
  alerts/**:         # Alert notifications

# Meta topics (observation of observers)
indrajaal/meta/:
  observer_health:   # Observer status
  observation_lag:   # Observation latency
```

---

## 6.0 Anti-Patterns to Avoid

### 6.1 Self-Observation Loop

```
WRONG:
┌───────────┐
│  Process  │◀───observes───┐
│           │               │
│           │───────────────┘
│           │
└───────────┘
Infinite recursion!

RIGHT:
┌───────────┐         ┌───────────┐
│ Observer  │◀────────│ Observed  │
│           │         │           │
└───────────┘         └───────────┘
Clean separation
```

### 6.2 Observer Overhead Domination

```
WRONG:
Observation cost >> Actual work cost
Observer consuming more resources than observed

RIGHT:
Observation cost << 5% of actual work
Observer is lightweight, non-blocking
```

### 6.3 Circular Observation

```
WRONG:
A observes B observes C observes A
Circular dependency!

RIGHT:
A observes B observes C
Constitutional observes A, B, C
Clear hierarchy
```

---

## 7.0 STAMP Constraints (Observer-Observability)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-OBS-001 | Observer MUST NOT block observed | CRITICAL |
| SC-OBS-002 | Observer overhead < 5% of observed | HIGH |
| SC-OBS-003 | Each level has exactly one observer type | HIGH |
| SC-OBS-004 | No circular observation dependencies | CRITICAL |
| SC-OBS-005 | L7 Constitutional is terminal observer | CRITICAL |
| SC-OBS-006 | Meta-observation limited to 3 levels | HIGH |
| SC-OBS-007 | Observer failure MUST NOT cascade | CRITICAL |
| SC-OBS-008 | Observability MUST be passive | HIGH |

---

## 8.0 AOR Rules (Observer-Observability)

| ID | Rule |
|----|------|
| AOR-OBS-001 | Design observer and observed as separate modules |
| AOR-OBS-002 | Use telemetry events for observability, not direct calls |
| AOR-OBS-003 | Observer MUST NOT modify observed state |
| AOR-OBS-004 | Observability MUST emit structured data only |
| AOR-OBS-005 | Meta-observers MUST be registered with L7 |
| AOR-OBS-006 | Test observer failure isolation |
| AOR-OBS-007 | Document observer-observability pairs explicitly |
| AOR-OBS-008 | Use Zenoh topic separation for distributed observation |

---

## 9.0 Related Documents

| Document | Location |
|----------|----------|
| EIGHT_LEVEL_FRACTAL_ANALYSIS.md | docs/architecture/ |
| EIGHT_LEVEL_INTERACTION_MATRICES.md | docs/architecture/ |
| CLAUDE.md | / |

---

**Document Control**

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Created | 2026-01-11 |
| Author | Claude Opus 4.5 |
| STAMP | SC-OBS-001 to SC-OBS-008 |
| AOR | AOR-OBS-001 to AOR-OBS-008 |

---

*This document is part of the Indrajaal SIL-6 Biomorphic Fractal Mesh specification.*
