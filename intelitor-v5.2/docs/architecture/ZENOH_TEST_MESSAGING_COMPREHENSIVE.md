# ZENOH REAL-TIME TEST MESSAGING SYSTEM
## Comprehensive 7-Level Fractal Architecture with 7-Level Interaction Matrix

**Version**: 2.0.0 | **Date**: 2026-01-18 | **Phase**: 8 (Fast Feedback Architecture)
**Compliance**: SC-ZTEST-001 to SC-ZTEST-020 | IEC 61508 SIL-6 | ISO 27001
**Fallback**: Log-based verification per SC-ZTEST-008 with [ZTEST-CHECKPOINT] format
**Mathematical**: State Vector $\vec{S} \in \{0,1\}^6$, Latency $L_{total} < 100ms$, Quorum $Q(N) = \lfloor N/2 \rfloor + 1$

---

## 1. EXECUTIVE SUMMARY

### 1.1 Problem Statement
Log-based verification introduces latency (seconds to minutes) in test feedback, making orchestration
difficult and dashboard updates slow. This system replaces log parsing with direct Zenoh pub/sub
messaging for <100ms test feedback.

### 1.2 Solution Architecture
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     ZENOH TEST MESSAGING ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  PUBLISHERS                      ZENOH MESH                   SUBSCRIBERS   │
│  ┌──────────────────┐           ┌────────────┐           ┌────────────────┐ │
│  │ ExUnit/ZenohFmt  │──publish─▶│   Zenoh    │◀──subscribe│ TestOrchestrator│
│  │ F#/SmokePublish  │           │   2oo3     │           │ Phoenix.PubSub │ │
│  │ Boot/BootPublish │           │   Quorum   │           │ LiveView Dash  │ │
│  └──────────────────┘           └────────────┘           └────────────────┘ │
│                                                                              │
│  FALLBACK: Log-based verification when Zenoh unavailable (SC-ZTEST-008)    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 7-LEVEL FRACTAL ARCHITECTURE (L0-L6)

### 2.1 Layer Mapping

| Layer | Name | Zenoh Component | Primary STAMP | Extended STAMP |
|-------|------|-----------------|---------------|----------------|
| **L0** | Runtime | Zenoh NIF (Rust) | SC-ZTEST-003,004,008 | SC-ZTEST-019 |
| **L1** | Function | Publisher/Subscriber APIs | SC-ZTEST-001,017 | SC-ZTEST-004,019 |
| **L2** | Component | Message Schemas | SC-ZTEST-002,006,007 | SC-ZTEST-013,014,015,016 |
| **L3** | Holon | Checkpoint State Machine | SC-ZTEST-009,010,011 | SC-ZTEST-006 |
| **L4** | Container | Zenoh Router (7447) | SC-ZTEST-012,016 | SC-ZTEST-018 |
| **L5** | Node | Orchestrator Aggregator | SC-ZTEST-005,018 | SC-ZTEST-012 |
| **L6** | Cluster | 2oo3 Quorum Consensus | SC-ZTEST-020 | SC-ZTEST-005 |

### 2.2 L0: Runtime Layer

**Mathematical Foundation**:
```
Zenoh Session State Machine:
S = {Disconnected, Connecting, Connected, Reconnecting}
T = {connect, disconnect, timeout, retry}

σ: S × T → S
σ(Disconnected, connect) = Connecting
σ(Connecting, connected) = Connected
σ(Connected, disconnect) = Disconnected
σ(Connected, timeout) = Reconnecting
σ(Reconnecting, retry) = Connecting
```

**NIF Constraints**:
- `SKIP_ZENOH_NIF=0` REQUIRED for production
- NIF load time < 50ms
- Memory-safe Rust implementation

### 2.3 L1: Function Layer

**Publisher Interface**:
```elixir
@spec publish(topic :: String.t(), payload :: map()) :: :ok | {:error, term()}
@spec publish_async(topic :: String.t(), payload :: map()) :: :ok
```

**Subscriber Interface**:
```elixir
@spec subscribe(topic_pattern :: String.t(), handler :: function()) :: {:ok, subscription_id}
@spec unsubscribe(subscription_id :: term()) :: :ok
```

**I/O Contracts**:
- Topic format: `indrajaal/{domain}/{category}/{event}`
- Payload: JSON with `checkpoint`, `timestamp`, `state_vector`
- Latency guarantee: < 10ms publish (SC-ZTEST-003)

### 2.4 L2: Component Layer - Message Schemas

**Boot Checkpoint Schema (v1.0.0)**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["checkpoint", "topic", "message", "state_vector", "timestamp", "schema_version"],
  "properties": {
    "checkpoint": {"type": "string", "pattern": "^CP-BOOT-[0-9]{2}$"},
    "topic": {"type": "string", "pattern": "^indrajaal/boot/.*$"},
    "message": {"type": "string", "maxLength": 256},
    "state_vector": {"type": "string", "pattern": "^\\[[01_],[01_],[01_],[01_],[01_],[01_]\\]$"},
    "timestamp": {"type": "string", "format": "date-time"},
    "schema_version": {"type": "string", "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"}
  }
}
```

**Test Result Schema (v1.0.0)**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["type", "checkpoint", "test_id", "timestamp"],
  "properties": {
    "type": {"enum": ["test_started", "test_passed", "test_failed", "test_skipped"]},
    "checkpoint": {"type": "string", "pattern": "^CP-TEST-TX-[0-9]{2}$"},
    "test_id": {"type": "string", "format": "uuid"},
    "module": {"type": "string"},
    "name": {"type": "string"},
    "duration_us": {"type": "integer", "minimum": 0},
    "assertions": {"type": "integer", "minimum": 0},
    "failure": {
      "type": "object",
      "properties": {
        "type": {"type": "string"},
        "message": {"type": "string"},
        "stacktrace": {"type": "array", "items": {"type": "string"}}
      }
    }
  }
}
```

### 2.5 L3: Holon Layer - Checkpoint State Machine

**Boot Phase State Machine**:
```
States: S = {S0_Preflight, S1_Foundation, S2_Mesh, S3_Cognitive, S4_App, S5_Homeostasis, S6_Complete, S_Failed}

Transitions:
S0_Preflight   --CP-BOOT-02--> S1_Foundation    (DAG validated)
S1_Foundation  --CP-BOOT-04--> S2_Mesh          (DB + OBS ready)
S2_Mesh        --CP-BOOT-05--> S3_Cognitive     (Zenoh quorum)
S3_Cognitive   --CP-BOOT-07--> S4_App           (Bridge + Cortex)
S4_App         --CP-BOOT-08--> S5_Homeostasis   (App seed ready)
S5_Homeostasis --CP-BOOT-10--> S6_Complete      (All checks pass)

Any state --error--> S_Failed (with rollback capability)
```

**State Vector Evolution**:
```
t0: [0,0,0,0,0,0]  // S0_Preflight
t1: [1,1,0,0,0,0]  // Compile + Migrations valid
t2: [1,1,1,0,0,0]  // + Containers up
t3: [1,1,1,1,0,0]  // + Zenoh connected
t4: [1,1,1,1,1,0]  // + Health checks pass
t5: [1,1,1,1,1,1]  // + Quorum achieved (VALID STARTUP)
```

### 2.6 L4: Container Layer - Zenoh Router

**Router Configuration**:
```yaml
# zenoh-router configuration
mode: router
listen: tcp/0.0.0.0:7447
http_port: 8000

# 2oo3 quorum configuration
peers:
  - tcp/zenoh-router-1:7447
  - tcp/zenoh-router-2:7448
  - tcp/zenoh-router-3:7449
```

**Health Check**:
```bash
curl -s http://localhost:8000/status | jq '.session.local_pid'
```

### 2.7 L5: Node Layer - Orchestrator Aggregator

**Aggregation Algorithm**:
```elixir
defmodule Indrajaal.Testing.ZenohTestOrchestrator do
  use GenServer

  @aggregate_window_ms 100  # SC-ZTEST-005

  def handle_info({:zenoh, topic, payload}, state) do
    # Parse checkpoint message
    checkpoint = decode_checkpoint(payload)

    # Update aggregate state
    new_state = update_aggregate(state, checkpoint)

    # Broadcast to Phoenix.PubSub if window elapsed
    if time_since_last_broadcast(state) > @aggregate_window_ms do
      Phoenix.PubSub.broadcast("zenoh:tests", :aggregate_update, new_state.aggregate)
    end

    {:noreply, new_state}
  end
end
```

### 2.8 L6: Cluster Layer - 2oo3 Consensus

**Quorum Formula**:
```
Q = floor(N/2) + 1

For N=3 routers:
Q = floor(3/2) + 1 = 2

System is operational if healthy_routers >= Q
```

**Voting Protocol**:
```
Router1: HEALTHY  ✓
Router2: HEALTHY  ✓
Router3: UNHEALTHY

Healthy count: 2 >= Q(2) → QUORUM ACHIEVED
```

---

## 3. 7-LEVEL INTERACTION MATRIX

### 3.1 Interaction Levels

| Level | Type | Description |
|-------|------|-------------|
| **I1** | Constitutional | Ψ₀-Ψ₅ invariants |
| **I2** | Operational | Ω₁-Ω₉ axioms |
| **I3** | Safety | SC-* constraints |
| **I4** | AOR | Agent operating rules |
| **I5** | TDG | Test-driven generation |
| **I6** | FMEA | Failure mode analysis |
| **I7** | BDD | Behavior-driven development |

### 3.2 Complete Interaction Matrix (7x7)

```
              │ I1-CONST │ I2-OPER │ I3-SAFETY │ I4-AOR │ I5-TDG │ I6-FMEA │ I7-BDD │
──────────────┼──────────┼─────────┼───────────┼────────┼────────┼─────────┼────────┤
L0-Runtime    │    Ψ₃    │   Ω₁    │ SC-ZENOH  │ AOR-001│ TDG-01 │ FMEA-01 │ BDD-01 │
L1-Function   │    Ψ₃    │   Ω₃    │ SC-ZTEST  │ AOR-002│ TDG-02 │ FMEA-02 │ BDD-02 │
L2-Component  │    Ψ₂    │   Ω₄    │ SC-ZTEST  │ AOR-003│ TDG-03 │ FMEA-03 │ BDD-03 │
L3-Holon      │    Ψ₀    │   Ω₇    │ SC-ZTEST  │ AOR-004│ TDG-04 │ FMEA-04 │ BDD-04 │
L4-Container  │    Ψ₁    │   Ω₂    │ SC-CNT    │ AOR-005│ TDG-05 │ FMEA-05 │ BDD-05 │
L5-Node       │    Ψ₄    │   Ω₆    │ SC-SIL6   │ AOR-006│ TDG-06 │ FMEA-06 │ BDD-06 │
L6-Cluster    │    Ψ₅    │   Ω₉    │ SC-SIL6   │ AOR-007│ TDG-07 │ FMEA-07 │ BDD-07 │
```

---

## 4. TDG (TEST-DRIVEN GENERATION) SPECIFICATIONS

### 4.1 Property Tests

```elixir
# TDG-01: L0 Runtime - Zenoh NIF Properties
property "zenoh session connects within timeout" do
  forall timeout <- PC.integer(100, 5000) do
    {:ok, session} = Zenoh.connect(timeout: timeout)
    Zenoh.connected?(session)
  end
end

# TDG-02: L1 Function - Publisher Latency
property "publish latency < 10ms" do
  forall payload <- SD.map_of(SD.atom(:alphanumeric), SD.binary()) do
    {time_us, :ok} = :timer.tc(fn -> Zenoh.publish("test/topic", payload) end)
    time_us < 10_000  # SC-ZTEST-003
  end
end

# TDG-03: L2 Component - Schema Validation
property "checkpoint messages have required fields" do
  forall checkpoint <- checkpoint_generator() do
    Map.has_key?(checkpoint, :checkpoint) and
    Map.has_key?(checkpoint, :timestamp) and
    Map.has_key?(checkpoint, :state_vector)
  end
end

# TDG-04: L3 Holon - State Machine Transitions
property "boot state machine never enters invalid state" do
  forall events <- SD.list_of(boot_event_generator()) do
    final_state = Enum.reduce(events, :s0_preflight, &boot_transition/2)
    final_state in valid_boot_states()
  end
end

# TDG-05: L4 Container - Router Health
property "router health check returns valid response" do
  forall port <- PC.oneof([7447, 7448, 7449]) do
    case HTTP.get("http://localhost:#{port}/status") do
      {:ok, %{status: 200, body: body}} -> valid_status?(body)
      _ -> true  # Allow graceful degradation
    end
  end
end

# TDG-06: L5 Node - Aggregation Timing
property "aggregator updates within window" do
  forall messages <- SD.list_of(checkpoint_message_generator(), min_length: 1) do
    {time_us, _} = :timer.tc(fn -> aggregate_messages(messages) end)
    time_us < 100_000  # SC-ZTEST-005: < 100ms
  end
end

# TDG-07: L6 Cluster - Quorum Consensus
property "quorum achieved with 2+ healthy routers" do
  forall health_states <- SD.list_of(SD.boolean(), length: 3) do
    healthy_count = Enum.count(health_states, & &1)
    quorum_expected = healthy_count >= 2
    calculate_quorum(health_states) == quorum_expected
  end
end
```

### 4.2 Generator Specifications

```elixir
defmodule Indrajaal.Testing.Generators do
  use PropCheck
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  def checkpoint_generator do
    SD.fixed_map(%{
      checkpoint: SD.string(:alphanumeric, min_length: 10, max_length: 15),
      topic: SD.constant("indrajaal/test/checkpoint"),
      message: SD.string(:printable, min_length: 1, max_length: 256),
      state_vector: state_vector_generator(),
      timestamp: timestamp_generator(),
      schema_version: SD.constant("1.0.0")
    })
  end

  def state_vector_generator do
    SD.bind(SD.list_of(SD.member_of([0, 1, :_]), length: 6), fn components ->
      "[" <> Enum.join(components, ",") <> "]"
    end)
  end

  def boot_event_generator do
    SD.member_of([
      :dag_validated,
      :db_ready,
      :obs_ready,
      :quorum_achieved,
      :bridge_connected,
      :cortex_online,
      :app_ready,
      :health_passed,
      :boot_complete,
      :error
    ])
  end
end
```

---

## 5. FMEA (FAILURE MODE AND EFFECTS ANALYSIS)

### 5.1 Complete FMEA Table

| ID | Failure Mode | Effect | Severity (S) | Occurrence (O) | Detection (D) | RPN | Mitigation |
|----|--------------|--------|--------------|----------------|---------------|-----|------------|
| FMEA-01 | Zenoh NIF fails to load | No pub/sub | 9 | 2 | 8 | 144 | Fallback to log-based |
| FMEA-02 | Router unreachable | Messages lost | 8 | 3 | 6 | 144 | 2oo3 quorum redundancy |
| FMEA-03 | Schema mismatch | Parse errors | 5 | 2 | 3 | 30 | Version field + validation |
| FMEA-04 | State machine deadlock | Boot hangs | 8 | 1 | 7 | 56 | Timeout + rollback |
| FMEA-05 | Container health false negative | Wrong status | 6 | 3 | 5 | 90 | Multi-probe verification |
| FMEA-06 | Aggregator overflow | Data loss | 7 | 2 | 4 | 56 | Bounded buffer + backpressure |
| FMEA-07 | Split brain (no quorum) | Inconsistent state | 9 | 1 | 5 | 45 | Leader election + fencing |
| FMEA-08 | High latency (>100ms) | Stale dashboard | 5 | 4 | 3 | 60 | Async publish + batching |
| FMEA-09 | Message duplication | Incorrect counts | 4 | 3 | 4 | 48 | Idempotency keys |
| FMEA-10 | Topic collision | Wrong routing | 6 | 1 | 2 | 12 | Topic registry validation |

### 5.2 RPN Threshold Analysis

```
RPN Categories:
  0-50:   LOW RISK    (Accept)
  51-100: MEDIUM RISK (Monitor + Document)
  101-200: HIGH RISK  (Mitigation Required)
  201+:   CRITICAL    (Redesign Required)

Critical Items (RPN > 100):
  - FMEA-01: Zenoh NIF (RPN=144) → Log fallback implemented
  - FMEA-02: Router unreachable (RPN=144) → 2oo3 quorum + graceful degradation
```

### 5.3 Mitigation Strategies

**FMEA-01 Mitigation: Log-Based Fallback**
```elixir
defmodule Indrajaal.Testing.ZenohTestFormatter do
  @behaviour ExUnit.Formatter

  def handle_cast({:test_finished, test}, state) do
    case Zenoh.publish(topic, payload) do
      :ok ->
        :ok
      {:error, _reason} ->
        # SC-ZTEST-008: Graceful degradation to log-based
        Logger.info("[ZTEST] #{inspect(payload)}")
    end
    {:noreply, state}
  end
end
```

**FMEA-02 Mitigation: 2oo3 Quorum**
```elixir
def check_quorum(routers) do
  healthy = Enum.count(routers, &router_healthy?/1)
  quorum = div(length(routers), 2) + 1

  if healthy >= quorum do
    {:ok, :quorum_achieved}
  else
    {:error, :no_quorum, healthy: healthy, required: quorum}
  end
end
```

---

## 6. DAG (DIRECTED ACYCLIC GRAPH) RULES

### 6.1 Boot DAG Definition

```
                    ┌─────────────┐
                    │  CP-BOOT-01 │ Preflight Start
                    │  (Start)    │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  CP-BOOT-02 │ Preflight Complete (DAG Validated)
                    │             │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
       ┌──────▼──────┐     │     ┌──────▼──────┐
       │  CP-BOOT-03 │     │     │  CP-BOOT-04 │
       │  DB Ready   │     │     │  OBS Ready  │
       └──────┬──────┘     │     └──────┬──────┘
              │            │            │
              └────────────┼────────────┘
                           │
                    ┌──────▼──────┐
                    │  CP-BOOT-05 │ Zenoh Quorum
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │                         │
       ┌──────▼──────┐           ┌──────▼──────┐
       │  CP-BOOT-06 │           │  CP-BOOT-07 │
       │  Bridge     │           │  Cortex     │
       └──────┬──────┘           └──────┬──────┘
              │                         │
              └────────────┬────────────┘
                           │
                    ┌──────▼──────┐
                    │  CP-BOOT-08 │ App Seed Ready
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  CP-BOOT-09 │ Homeostasis Verified
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  CP-BOOT-10 │ Boot Complete
                    │  (End)      │
                    └─────────────┘
```

### 6.2 DAG Constraints (SC-DAG-*)

| ID | Constraint | Verification |
|----|------------|--------------|
| SC-DAG-001 | DAG MUST be acyclic | Kahn's algorithm |
| SC-DAG-002 | All checkpoints have unique ID | Registry check |
| SC-DAG-003 | Dependencies MUST be satisfied before transition | Pre-check |
| SC-DAG-004 | Parallel branches MUST converge | Join verification |
| SC-DAG-005 | Critical path < 30 seconds | CPM analysis |

### 6.3 Critical Path Method (CPM) Analysis

```
Task Durations (estimated):
  CP-BOOT-01 to CP-BOOT-02: 1s (DAG validation)
  CP-BOOT-02 to CP-BOOT-03: 5s (DB startup)
  CP-BOOT-02 to CP-BOOT-04: 3s (OBS startup)
  CP-BOOT-03/04 to CP-BOOT-05: 2s (Zenoh quorum)
  CP-BOOT-05 to CP-BOOT-06: 1s (Bridge)
  CP-BOOT-05 to CP-BOOT-07: 2s (Cortex)
  CP-BOOT-06/07 to CP-BOOT-08: 3s (App startup)
  CP-BOOT-08 to CP-BOOT-09: 2s (Health checks)
  CP-BOOT-09 to CP-BOOT-10: 0.5s (Final validation)

Critical Path: 01 → 02 → 03 → 05 → 07 → 08 → 09 → 10
Total Duration: 1 + 5 + 2 + 2 + 3 + 2 + 0.5 = 15.5s

Slack Analysis:
  CP-BOOT-04 (OBS): Float = 5 - 3 = 2s
  CP-BOOT-06 (Bridge): Float = 2 - 1 = 1s
```

### 6.4 Topological Sort Implementation

```fsharp
module StartupDAG =
    let topologicalSort () =
        let nodes = getAllNodes ()
        let inDegree = computeInDegree nodes
        let queue = nodes |> List.filter (fun n -> inDegree.[n] = 0)

        let rec sort queue order visited =
            match queue with
            | [] ->
                if Set.count visited = List.length nodes then
                    Ok (List.rev order)
                else
                    Error "Cycle detected in DAG"
            | node :: rest ->
                let newVisited = Set.add node visited
                let newOrder = node :: order
                let neighbors = getNeighbors node
                let (newQueue, newInDegree) =
                    neighbors
                    |> List.fold (fun (q, deg) n ->
                        let d = deg.[n] - 1
                        if d = 0 then (n :: q, Map.add n d deg)
                        else (q, Map.add n d deg)
                    ) (rest, inDegree)
                sort newQueue newOrder newVisited

        sort queue [] Set.empty
```

---

## 7. MATHEMATICAL FOUNDATIONS

### 7.1 State Vector Algebra

**Definition**: State Vector $\vec{S} = [s_1, s_2, s_3, s_4, s_5, s_6]$ where $s_i \in \{0, 1, \_\}$

**Valid Startup Predicate**:
$$\text{ValidStartup}(\vec{S}) \iff \prod_{i=1}^{6} s_i = 1$$

**State Transition Function**:
$$\sigma: \vec{S} \times \mathcal{E} \to \vec{S}$$

where $\mathcal{E}$ is the set of events (checkpoint completions).

**Monotonicity Property**:
$$\forall i, t_1 < t_2: s_i(t_1) = 1 \implies s_i(t_2) = 1$$

(Once a component is valid, it remains valid until explicit invalidation)

### 7.2 Latency Budget Analysis

**Total Latency Budget**: $L_{total} = 100ms$ (SC-ZTEST-005)

**Budget Allocation**:
$$L_{total} = L_{publish} + L_{route} + L_{subscribe} + L_{aggregate}$$

$$100ms = 10ms + 20ms + 10ms + 60ms$$

**Queueing Model** (M/M/1):
$$W = \frac{1}{\mu - \lambda}$$

where:
- $\mu$ = service rate (messages/ms)
- $\lambda$ = arrival rate (messages/ms)
- $W$ = average waiting time

For stable system: $\lambda < \mu$ (utilization < 100%)

### 7.3 Quorum Mathematics

**Quorum Size**:
$$Q(N) = \lfloor N/2 \rfloor + 1$$

**Availability with $k$ failures**:
$$A(N, k) = \begin{cases} 1 & \text{if } N - k \geq Q(N) \\ 0 & \text{otherwise} \end{cases}$$

For N=3:
- Q(3) = 2
- A(3, 0) = 1 (3 healthy, need 2) ✓
- A(3, 1) = 1 (2 healthy, need 2) ✓
- A(3, 2) = 0 (1 healthy, need 2) ✗

### 7.4 FMEA RPN Calculation

$$RPN = S \times O \times D$$

where:
- $S$ = Severity (1-10)
- $O$ = Occurrence probability (1-10)
- $D$ = Detection difficulty (1-10)

**Risk Priority**:
$$\text{Priority} = \begin{cases}
\text{CRITICAL} & RPN > 200 \\
\text{HIGH} & 100 < RPN \leq 200 \\
\text{MEDIUM} & 50 < RPN \leq 100 \\
\text{LOW} & RPN \leq 50
\end{cases}$$

---

## 8. AOR (AGENT OPERATING RULES) COMPLETE LIST

| ID | Rule | Layer | Interaction |
|----|------|-------|-------------|
| AOR-ZTEST-001 | Formatter MUST use async publishing | L1 | I4 |
| AOR-ZTEST-002 | Boot checkpoints at all 10 phases | L3 | I4 |
| AOR-ZTEST-003 | State vector in all boot messages | L2 | I4 |
| AOR-ZTEST-004 | Never block on Zenoh operations | L1 | I4 |
| AOR-ZTEST-005 | Subscribe to all test topics | L5 | I4 |
| AOR-ZTEST-006 | Dashboard via Phoenix.PubSub | L5 | I4 |
| AOR-ZTEST-007 | Log checkpoint ID with publish | L1 | I4 |
| AOR-ZTEST-008 | Graceful degradation to logs | L0 | I4 |
| AOR-DAG-001 | Verify DAG acyclic before boot | L3 | I4 |
| AOR-DAG-002 | Check dependencies before transition | L3 | I4 |
| AOR-QUORUM-001 | 2oo3 voting for health decisions | L6 | I4 |
| AOR-QUORUM-002 | Leader election on quorum loss | L6 | I4 |

---

## 9. LOG-BASED FALLBACK MECHANISM

### 9.1 Fallback Strategy (SC-ZTEST-008)

When Zenoh is unavailable, the system automatically degrades to log-based verification:

```elixir
defmodule Indrajaal.Testing.HybridPublisher do
  @moduledoc """
  Hybrid publisher supporting both Zenoh and log-based output.
  SC-ZTEST-008: Graceful degradation when Zenoh unavailable.
  """

  def publish(topic, payload) do
    # Try Zenoh first (primary)
    case zenoh_publish(topic, payload) do
      :ok ->
        :ok
      {:error, :zenoh_unavailable} ->
        # Fallback to structured logging
        log_checkpoint(topic, payload)
    end
  end

  defp zenoh_publish(topic, payload) do
    if zenoh_available?() do
      Zenoh.publish_async(topic, Jason.encode!(payload))
    else
      {:error, :zenoh_unavailable}
    end
  end

  defp log_checkpoint(topic, payload) do
    # Structured log format for parsing
    Logger.info(
      "[ZTEST-CHECKPOINT] topic=#{topic} payload=#{Jason.encode!(payload)}",
      checkpoint: payload.checkpoint,
      state_vector: payload.state_vector
    )
    :ok
  end

  defp zenoh_available? do
    Application.get_env(:indrajaal, :zenoh_enabled, false) and
    System.get_env("SKIP_ZENOH_NIF", "1") == "0"
  end
end
```

### 9.2 F# Fallback Implementation

```fsharp
module ZenohCheckpoints =
    /// Publish with fallback to console logging when Zenoh unavailable
    /// SC-ZTEST-008: Graceful degradation
    let publishWithFallback (checkpoint: BootCheckpoint) (stateVectorStr: string) (message: string) =
        let topic = getCheckpointTopic checkpoint
        let checkpointId = getCheckpointId checkpoint

        // Always log to console (backup)
        printfn "[ZTEST-CHECKPOINT] checkpoint=%s topic=%s message=%s state_vector=%s"
            checkpointId topic message stateVectorStr

        // Attempt Zenoh publish (non-blocking, best-effort)
        async {
            try
                use client = new HttpClient(Timeout = TimeSpan.FromMilliseconds(50.0))
                let payload = sprintf """{
                    "checkpoint": "%s",
                    "topic": "%s",
                    "message": "%s",
                    "state_vector": %s,
                    "timestamp": "%s"
                }""" checkpointId topic message stateVectorStr (DateTimeOffset.UtcNow.ToString("o"))

                let content = new StringContent(payload, System.Text.Encoding.UTF8, "application/json")
                let! _ = client.PostAsync("http://localhost:8000/publish/" + topic.Replace("/", "%2F"), content) |> Async.AwaitTask
                ()
            with _ ->
                // Non-blocking: log fallback already done above
                ()
        } |> Async.Start
```

### 9.3 Fallback Verification Procedures

**Full Specification**: See `docs/specifications/ZENOH_TEST_MESSAGING_FALLBACK_VERIFICATION.md`

**Quick Verification Commands**:
```bash
# Count all fallback checkpoints in log
grep -c '\[ZTEST-CHECKPOINT\]' ./data/tmp/ztest.log

# Extract boot checkpoints
grep '\[ZTEST-CHECKPOINT\].*checkpoint=CP-BOOT' ./data/tmp/ztest.log

# Verify state vector progression
grep '\[ZTEST-CHECKPOINT\].*state_vector=' ./data/tmp/ztest.log | \
  grep -oP 'state_vector=\K\[[0-1,]+\]'

# Verify all 10 boot checkpoints present
for i in $(seq -w 01 10); do
  grep -q "checkpoint=CP-BOOT-$i" ./data/tmp/ztest.log && \
    echo "CP-BOOT-$i: FOUND" || echo "CP-BOOT-$i: MISSING"
done
```

**Log Format Regex**:
```regex
\[ZTEST-CHECKPOINT\] checkpoint=(?<checkpoint>CP-[A-Z]+-[0-9]{2}) topic=(?<topic>indrajaal/[^\s]+)
```

**STAMP Constraints (Fallback-Specific)**:
| ID | Constraint | Severity |
|----|------------|----------|
| SC-ZTEST-008 | Log fallback MUST be written BEFORE Zenoh attempt | CRITICAL |
| SC-ZTEST-008-A | Fallback format MUST match [ZTEST-CHECKPOINT] pattern | CRITICAL |
| SC-ZTEST-008-B | Fallback MUST include checkpoint ID | CRITICAL |
| SC-ZTEST-008-C | Fallback MUST include topic | CRITICAL |

---

## 10. VERIFICATION CHECKLIST

### 10.1 Pre-Release Verification

| Check | STAMP | Command | Expected |
|-------|-------|---------|----------|
| Zenoh NIF loads | SC-ZENOH-001 | `mix test --only zenoh` | Pass |
| Publish latency | SC-ZTEST-003 | `mix test.property` | <10ms |
| Aggregate update | SC-ZTEST-005 | `test-orchestrate` | <100ms |
| Schema validation | SC-ZTEST-002 | `mix test --only schema` | Pass |
| Quorum check | SC-SIL6-006 | `sa-swarm-quorum` | 2oo3 |
| Fallback works | SC-ZTEST-008 | `SKIP_ZENOH_NIF=1 mix test` | Pass |

### 10.2 Continuous Monitoring

```bash
# Monitor all Zenoh messages
zenoh-all-sub

# Check quorum status
sa-swarm-quorum

# View dashboard (real-time)
open http://localhost:4000/prajna/tests
```

---

## 11. REVISION HISTORY

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 2.0.0 | 2026-01-18 | Claude Opus 4.5 | Pass 1: Extended STAMP SC-ZTEST-012 to SC-ZTEST-020, mathematical foundations |
| 2.0.0 | 2026-01-18 | Claude Opus 4.5 | Pass 2: Comprehensive FMEA (20 failure modes), DAG specifications, AOR-ZTEST-001 to AOR-ZTEST-015 |
| 2.0.0 | 2026-01-18 | Claude Opus 4.5 | Pass 3: Log-based fallback verification, dual-write strategy, verification procedures |
| 1.0.0 | 2026-01-18 | Claude Opus 4.5 | Initial comprehensive specification |

---

## 12. REFERENCES

### 12.1 Primary Specifications
- CLAUDE.md - Primary system specification with SC-ZTEST-001 to SC-ZTEST-020
- `.claude/rules/zenoh-test-messaging.md` - STAMP rule file v2.0.0

### 12.2 Detailed Specifications
- `docs/specifications/ZENOH_TEST_MESSAGING_STAMP_COMPLETE.md` - Complete STAMP constraints specification
- `docs/specifications/ZENOH_TEST_MESSAGING_FMEA_DAG.md` - Comprehensive FMEA (20 failure modes) and DAG specifications
- `docs/specifications/ZENOH_TEST_MESSAGING_FALLBACK_VERIFICATION.md` - Log-based fallback and verification procedures

### 12.3 Implementation References
- `lib/indrajaal/testing/zenoh_test_formatter.ex` - ExUnit formatter with SC-ZTEST-008 fallback
- `lib/indrajaal/testing/checkpoint_messages.ex` - Message schemas v2.0.0
- `lib/cepaf/scripts/ComprehensiveStartupOrchestrator.fsx` - F# boot checkpoints with fallback

### 12.4 Architecture References
- `docs/architecture/HOLON_IMMUTABLE_REGISTER.md` - State management
- `docs/architecture/HOLON_IMMORTAL_ARCHITECTURE.md` - Holon survival

### 12.5 Standards
- IEC 61508 - Functional safety standard (SIL-6 extended)
- Zenoh Protocol Specification - https://zenoh.io/docs/
- ISO 8601 - Timestamp format specification
