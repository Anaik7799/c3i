---
paths:
  - test/**/*.exs
  - lib/indrajaal/testing/**/*.ex
  - lib/indrajaal/boot/**/*.ex
  - lib/cepaf/src/Cepaf/Mesh/*Publisher*.fs
  - lib/cepaf/src/Cepaf/Mesh/*Checkpoint*.fs
---

# Zenoh Real-Time Test Messaging System (SC-ZTEST)

## Overview

This rule file governs the Zenoh pub/sub real-time test messaging system that replaces log-based verification with checkpoint-based messages for <100ms test feedback.

**Version**: 3.0.0 | **Date**: 2026-04-04 | **Phase**: 9 (Gleam Test Observer Integration)
**Compliance**: IEC 61508 SIL-6, ISO 27001 | **Fallback**: Log-based per SC-ZTEST-008

## Extensions: Gleam Test Observer & OTel Integration (v3.0.0)

### New Gleam Components
- `testing/zenoh_test_observer.gleam` — Zenoh message verification during gleeunit tests
- `ui/zenoh_otel.gleam` — OTel span publishing for all 15 UI pages over Zenoh
- `testing/test_dashboard.gleam` — Real-time test tracking model
- `ui/tui/split_screen.gleam` — Dashboard + test results split view
- `scripts/run-split-screen-tests.sh` — 10-minute test cycle (381 tests)

### New STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-GLM-ZEN-001 | All UI state changes MUST publish OTel spans via zenoh_otel | CRITICAL |
| SC-GLM-ZEN-002 | Test runner MUST observe Zenoh messages for verification | CRITICAL |
| SC-GLM-ZEN-003 | Split-screen TUI MUST display dashboard + test results simultaneously | HIGH |
| SC-GLM-TST-001 | 100+ regression tests required per release | CRITICAL |
| SC-GLM-TST-002 | Each tab monitored for 30+ seconds during verification | HIGH |

### Test Metrics (Current)
- Total Tests: 1,559 passed, 0 failures
- Shannon Entropy H: 2.67 bits (weighted mean, >= 2.5 threshold)
- CCM: 0.770 (improving, target 0.90)
- ITQS: 0.736 (improving, target 0.85)
- Tab Coverage: 100% (15/15 tabs × 8 fractal layers)

## Extensions: Gleam Test Observer & OTel Integration (v3.0.0)

### New Gleam Components
- `testing/zenoh_test_observer.gleam` — Zenoh message verification during gleeunit tests
- `ui/zenoh_otel.gleam` — OTel span publishing for all 15 UI pages over Zenoh
- `testing/test_dashboard.gleam` — Real-time test tracking model
- `ui/tui/split_screen.gleam` — Dashboard + test results split view
- `scripts/run-split-screen-tests.sh` — 10-minute test cycle (381 tests)

### New STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-GLM-ZEN-001 | All UI state changes MUST publish OTel spans via zenoh_otel | CRITICAL |
| SC-GLM-ZEN-002 | Test runner MUST observe Zenoh messages for verification | CRITICAL |
| SC-GLM-ZEN-003 | Split-screen TUI MUST display dashboard + test results simultaneously | HIGH |
| SC-GLM-TST-001 | 100+ regression tests required per release | CRITICAL |
| SC-GLM-TST-002 | Each tab monitored for 30+ seconds during verification | HIGH |

### Test Metrics (Current)
- Total Tests: 1,559 passed, 0 failures
- Shannon Entropy H: 2.67 bits (weighted mean, >= 2.5 threshold)
- CCM: 0.770 (improving, target 0.90)
- ITQS: 0.736 (improving, target 0.85)
- Tab Coverage: 100% (15/15 tabs × 8 fractal layers)

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     ZENOH TEST MESSAGING ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  PUBLISHERS                      ZENOH MESH                   SUBSCRIBERS   │
│                                                                              │
│  ┌──────────────────┐           ┌────────────┐           ┌────────────────┐ │
│  │ ExUnit Tests     │──publish─▶│            │◀──subscribe│ TestOrchestrator│
│  │ (ZenohFormatter) │           │   Zenoh    │           │ (Aggregator)   │ │
│  └──────────────────┘           │   Router   │           └───────┬────────┘ │
│         │                       │   7447     │                   │          │
│         ▼ (SC-ZTEST-008)        │            │           ┌───────▼────────┐ │
│  ┌──────────────────┐           │            │           │ Phoenix.PubSub │ │
│  │ LOG FALLBACK     │           │            │           │ "zenoh:tests"  │ │
│  │ [ZTEST-CHECKPOINT]│          │            │           └───────┬────────┘ │
│  └──────────────────┘           │            │                   │          │
│                                 │            │           ┌───────▼────────┐ │
│  ┌──────────────────┐           │            │           │ LiveView       │ │
│  │ F# Boot/Smoke    │──publish─▶│            │           │ Dashboard      │ │
│  │ (Publishers)     │           └────────────┘           └────────────────┘ │
│  └──────────────────┘                                                       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 1.0 STAMP Constraints (SC-ZTEST-001 to SC-ZTEST-020)

### 1.1 Core Messaging Constraints

| ID | Constraint | Severity | Layer | Verification | Mathematical Basis |
|----|------------|----------|-------|--------------|-------------------|
| SC-ZTEST-001 | All checkpoints MUST have unique topic | CRITICAL | L1 | Topic registry | $\forall c_i, c_j: topic(c_i) \neq topic(c_j)$ |
| SC-ZTEST-002 | Messages MUST include checkpoint ID | CRITICAL | L2 | Schema validation | $\forall m: checkpoint\_id(m) \in \mathcal{C}$ |
| SC-ZTEST-003 | Publish latency < 10ms per message | HIGH | L0 | Telemetry | $L_{publish} < 10ms$ (p99) |
| SC-ZTEST-004 | Formatter MUST be non-blocking (async) | CRITICAL | L1 | Code review | $\neg\exists blocking\_call$ |
| SC-ZTEST-005 | Orchestrator aggregate update < 100ms | HIGH | L5 | E2E test | $L_{aggregate} < 100ms$ |
| SC-ZTEST-006 | Boot checkpoints MUST include state vector | HIGH | L3 | Message validation | $\forall m_{boot}: \vec{S}(m) \neq \emptyset$ |
| SC-ZTEST-007 | Test failures MUST include full context | HIGH | L2 | Schema validation | $|context(failure)| \geq 3$ fields |
| SC-ZTEST-008 | Log-based fallback when Zenoh unavailable | CRITICAL | L0 | Integration test | $fallback(zenoh\_fail) = log\_output$ |
| SC-ZTEST-009 | F# scripts MUST publish boot checkpoints | HIGH | L3 | Integration test | $\forall script_{F\#}: publishes(CP_{boot})$ |
| SC-ZTEST-010 | Jidoka gates MUST publish pass/fail status | HIGH | L3 | Gate verification | $\forall gate: publishes(status)$ |
| SC-ZTEST-011 | State vector changes MUST be published | HIGH | L3 | Event verification | $\Delta\vec{S} \implies publish(\vec{S}_{new})$ |

### 1.2 Extended Constraints (Pass 1 Additions)

| ID | Constraint | Severity | Layer | Verification | Mathematical Basis |
|----|------------|----------|-------|--------------|-------------------|
| SC-ZTEST-012 | Message ordering MUST be FIFO per topic | HIGH | L4 | Sequence test | $\forall t: order(m_i) < order(m_j) \iff ts(m_i) < ts(m_j)$ |
| SC-ZTEST-013 | Checkpoint ID format: CP-{DOMAIN}-{NN} | MEDIUM | L2 | Regex validation | $id \in \{CP\text{-}[A-Z]+\text{-}[0-9]{2}\}$ |
| SC-ZTEST-014 | Schema version MUST be semver compliant | MEDIUM | L2 | Regex validation | $version \in \{[0-9]+\.[0-9]+\.[0-9]+\}$ |
| SC-ZTEST-015 | Timestamp MUST be ISO 8601 UTC | MEDIUM | L2 | Format validation | $ts \in ISO8601\_UTC$ |
| SC-ZTEST-016 | Payload size < 64KB per message | HIGH | L4 | Size check | $|payload| < 65536$ bytes |
| SC-ZTEST-017 | Topic depth <= 6 levels | MEDIUM | L1 | Path validation | $depth(topic) \leq 6$ |
| SC-ZTEST-018 | Subscriber timeout = 5 seconds | HIGH | L5 | Config validation | $T_{subscribe} = 5000ms$ |
| SC-ZTEST-019 | Publisher retry count = 3 | MEDIUM | L1 | Config validation | $retry_{max} = 3$ |
| SC-ZTEST-020 | Quorum messages require 2oo3 consensus | CRITICAL | L6 | Quorum test | $healthy \geq \lfloor N/2 \rfloor + 1$ |

---

## 2.0 AOR Rules
> AOR-ZTEST-001 to AOR-ZTEST-015 — defined in CLAUDE.md §9.0
> Key: ZenohTestFormatter, async-only publishing, log fallback BEFORE Zenoh, state vector in boot, FIFO ordering, 2oo3 consensus

---

## 3.0 Mathematical Foundations

### 3.1 State Vector Algebra

**Definition**: The system state is represented by a 6-dimensional binary vector:
$$\vec{S} = [s_1, s_2, s_3, s_4, s_5, s_6] \in \{0, 1, \_\}^6$$

where:
- $s_1$ = Compile status (Valid=1, Invalid=0, Pending=_)
- $s_2$ = Migrations status
- $s_3$ = Containers status
- $s_4$ = Zenoh status
- $s_5$ = Health status
- $s_6$ = Quorum status

**Valid Startup Predicate**:
$$ValidStartup(\vec{S}) \iff \prod_{i=1}^{6} s_i = 1$$

**State Transition Function**:
$$\sigma: \vec{S} \times \mathcal{E} \to \vec{S}$$

where $\mathcal{E} = \{e_1, e_2, ..., e_n\}$ is the set of checkpoint events.

**Monotonicity Theorem**:
$$\forall i, t_1 < t_2: s_i(t_1) = 1 \implies s_i(t_2) = 1$$

### 3.2 Latency Budget Algebra

**Total E2E Latency Budget**: $L_{total} = 100ms$

**Latency Composition**:
$$L_{total} = L_{publish} + L_{route} + L_{subscribe} + L_{process} + L_{aggregate}$$

**Budget Allocation**:
| Component | Budget | Constraint |
|-----------|--------|------------|
| $L_{publish}$ | 10ms | SC-ZTEST-003 |
| $L_{route}$ | 15ms | Network + router |
| $L_{subscribe}$ | 10ms | Zenoh delivery |
| $L_{process}$ | 15ms | Message parsing |
| $L_{aggregate}$ | 50ms | Aggregation window |
| **Total** | **100ms** | SC-ZTEST-005 |

### 3.3 Quorum Mathematics

**Quorum Size**:
$$Q(N) = \lfloor N/2 \rfloor + 1$$

**Availability Function**:
$$A(N, f) = \begin{cases}
1 & \text{if } N - f \geq Q(N) \\
0 & \text{otherwise}
\end{cases}$$

**Probability of Quorum** (assuming independent failures):
$$P(quorum) = \sum_{k=Q(N)}^{N} \binom{N}{k} p^k (1-p)^{N-k}$$

For N=3, Q=2, p=0.99:
$$P(quorum) = 0.999702$$

### 3.4 Checkpoint DAG Formal Definition

**DAG Definition**:
$$G = (V, E)$$

where:
- $V = \{CP\text{-}BOOT\text{-}01, ..., CP\text{-}BOOT\text{-}10\}$ (checkpoints)
- $E \subseteq V \times V$ (dependencies)

**Topological Order Existence**:
$$\exists \tau: V \to \mathbb{N} \text{ such that } (u,v) \in E \implies \tau(u) < \tau(v)$$

**Critical Path Length**:
$$CPL = \max_{\pi \in Paths(G)} \sum_{v \in \pi} duration(v)$$

### 3.5 FMEA Risk Priority Number

**RPN Calculation**:
$$RPN = S \times O \times D$$

where:
- $S$ = Severity (1-10)
- $O$ = Occurrence probability (1-10)
- $D$ = Detection difficulty (1-10)

**Risk Classification**:
$$Risk(RPN) = \begin{cases}
\text{CRITICAL} & RPN > 200 \\
\text{HIGH} & 100 < RPN \leq 200 \\
\text{MEDIUM} & 50 < RPN \leq 100 \\
\text{LOW} & RPN \leq 50
\end{cases}$$

---

## 4.0 7-Level Fractal Constraint Mapping

### 4.1 Layer-Constraint Matrix

```
Layer    │ Primary SC-ZTEST │ Secondary │ Tertiary │
─────────┼──────────────────┼───────────┼──────────┤
L0-Runtime  │ 003, 004, 008    │ 019       │ -        │
L1-Function │ 001, 017         │ 004       │ 019      │
L2-Component│ 002, 006, 007    │ 013-015   │ 016      │
L3-Holon    │ 009, 010, 011    │ 006       │ -        │
L4-Container│ 012, 016         │ 018       │ -        │
L5-Node     │ 005, 018         │ 012       │ -        │
L6-Cluster  │ 020              │ 005       │ -        │
```

### 4.2 Cross-Layer Interactions

| From Layer | To Layer | Interaction | Constraint |
|------------|----------|-------------|------------|
| L0→L1 | NIF→Publisher | Function call | SC-ZTEST-003 |
| L1→L2 | Publisher→Schema | Message format | SC-ZTEST-002 |
| L2→L3 | Schema→StateMachine | State update | SC-ZTEST-011 |
| L3→L4 | StateMachine→Router | Message routing | SC-ZTEST-012 |
| L4→L5 | Router→Orchestrator | Aggregation | SC-ZTEST-005 |
| L5→L6 | Orchestrator→Quorum | Consensus | SC-ZTEST-020 |

---

## 5.0 Boot Phase Checkpoints (CP-BOOT-*)

| Checkpoint | Topic | Trigger | State Vector Impact |
|------------|-------|---------|---------------------|
| CP-BOOT-01 | `indrajaal/boot/preflight/start` | Startup initiated | [0,0,0,0,0,0] |
| CP-BOOT-02 | `indrajaal/boot/preflight/complete` | DAG validated | [0,0,0,0,0,0] |
| CP-BOOT-03 | `indrajaal/boot/foundation/db_ready` | PostgreSQL healthy | [1,1,1,0,0,0] |
| CP-BOOT-04 | `indrajaal/boot/foundation/obs_ready` | Observability ready | [1,1,1,0,0,0] |
| CP-BOOT-05 | `indrajaal/boot/mesh/quorum` | Zenoh 2oo3 achieved | [1,1,1,1,0,0] |
| CP-BOOT-06 | `indrajaal/boot/cognitive/bridge` | CEPAF bridge connected | [1,1,1,1,0,0] |
| CP-BOOT-07 | `indrajaal/boot/cognitive/cortex` | Cortex AI online | [1,1,1,1,0,0] |
| CP-BOOT-08 | `indrajaal/boot/app/seed_ready` | Primary app healthy | [1,1,1,1,1,0] |
| CP-BOOT-09 | `indrajaal/boot/homeostasis/verified` | All health checks pass | [1,1,1,1,1,1] |
| CP-BOOT-10 | `indrajaal/boot/complete` | Full mesh operational | [1,1,1,1,1,1] |

---

## 6.0 Test Checkpoints (CP-TEST-*)

| Checkpoint | Topic | Trigger |
|------------|-------|---------|
| CP-TEST-01 | `indrajaal/test/suite/start` | ExUnit suite begins |
| CP-TEST-02 | `indrajaal/test/compile/complete` | Test compilation done |
| CP-TEST-03 | `indrajaal/test/db/sandbox_ready` | Ecto sandbox ready |
| CP-TEST-04 | `indrajaal/test/factories/loaded` | Factories initialized |
| CP-TEST-05 | `indrajaal/test/module/{name}/start` | Module tests begin |
| CP-TEST-06 | `indrajaal/test/module/{name}/complete` | Module tests done |
| CP-TEST-07 | `indrajaal/test/suite/complete` | All tests finished |
| CP-TEST-08 | `indrajaal/test/coverage/report` | Coverage generated |

---

## 7.0 Smoke Test Checkpoints (CP-SMOKE-*)

| Checkpoint | Topic | Trigger |
|------------|-------|---------|
| CP-SMOKE-01 | `indrajaal/smoke/batch/start` | Smoke batch begins |
| CP-SMOKE-02 | `indrajaal/smoke/api/complete` | API tests done |
| CP-SMOKE-03 | `indrajaal/smoke/db/complete` | DB tests done |
| CP-SMOKE-04 | `indrajaal/smoke/zenoh/complete` | Zenoh tests done |
| CP-SMOKE-05 | `indrajaal/smoke/perf/complete` | Performance tests done |
| CP-SMOKE-06 | `indrajaal/smoke/security/complete` | Security tests done |
| CP-SMOKE-07 | `indrajaal/smoke/resilience/complete` | Resilience tests done |
| CP-SMOKE-08 | `indrajaal/smoke/batch/complete` | All smoke tests done |

---

## 8.0 Log-Based Fallback (SC-ZTEST-008)

### 8.1 Fallback Format

When Zenoh is unavailable, all checkpoints MUST be written to structured logs:

```
[ZTEST-CHECKPOINT] checkpoint={id} topic={topic} message={msg} state_vector={vec} timestamp={ts}
```

### 8.2 Fallback Implementation Pattern

```elixir
# Elixir pattern
defp log_checkpoint_fallback(topic, message) do
  checkpoint_id = Map.get(message, :checkpoint, "unknown")
  type = Map.get(message, :type, "unknown")
  Logger.info(
    "[ZTEST-CHECKPOINT] topic=#{topic} checkpoint=#{checkpoint_id} type=#{type} payload=#{Jason.encode!(message)}",
    domain: :zenoh_test
  )
end
```

```fsharp
// F# pattern
let logCheckpointFallback (checkpointId: string) (topic: string) (message: string) (stateVectorStr: string) =
    let timestamp = DateTimeOffset.UtcNow.ToString("o")
    printfn "[ZTEST-CHECKPOINT] checkpoint=%s topic=%s message=%s state_vector=%s timestamp=%s"
        checkpointId topic message stateVectorStr timestamp
```

### 8.3 Fallback Parsing Regex

```regex
\[ZTEST-CHECKPOINT\] checkpoint=(?<checkpoint>[^\s]+) topic=(?<topic>[^\s]+) (?:message=(?<message>[^\s]+) )?(?:state_vector=(?<state_vector>\[[^\]]+\]) )?(?:type=(?<type>[^\s]+) )?(?:payload=(?<payload>\{.*\}) )?timestamp=(?<timestamp>[^\s]+)
```

### 8.4 Dual-Write Strategy

1. **ALWAYS** write to log first (guaranteed durability)
2. **THEN** attempt Zenoh publish (best-effort real-time)
3. **ON FAILURE** Zenoh publish already has log backup

---

## 9.0 TDG Generators
> Dual property tests (PC. + SD.) mandatory — see CLAUDE.md §7.0, EP-GEN-014

```elixir
# Generator for checkpoint IDs
def checkpoint_id_gen do
  SD.bind(SD.member_of(["BOOT", "TEST", "SMOKE"]), fn domain ->
    SD.bind(SD.integer(1..99), fn num ->
      "CP-#{domain}-#{String.pad_leading(to_string(num), 2, "0")}"
    end)
  end)
end

# Generator for state vectors
def state_vector_gen do
  SD.fixed_list([
    SD.member_of([0, 1]),  # Compile
    SD.member_of([0, 1]),  # Migrations
    SD.member_of([0, 1]),  # Containers
    SD.member_of([0, 1]),  # Zenoh
    SD.member_of([0, 1]),  # Health
    SD.member_of([0, 1])   # Quorum
  ])
end

# Generator for topics
def topic_gen do
  SD.bind(SD.list_of(SD.string(:alphanumeric, min_length: 1, max_length: 20), min_length: 2, max_length: 6), fn parts ->
    "indrajaal/" <> Enum.join(parts, "/")
  end)
end
```

### 9.2 Property Specifications

| Property ID | Description | Generator | Constraint |
|-------------|-------------|-----------|------------|
| TDG-ZTEST-001 | Checkpoint ID uniqueness | checkpoint_id_gen | SC-ZTEST-001 |
| TDG-ZTEST-002 | State vector validity | state_vector_gen | SC-ZTEST-006 |
| TDG-ZTEST-003 | Topic depth limit | topic_gen | SC-ZTEST-017 |
| TDG-ZTEST-004 | Timestamp format | timestamp_gen | SC-ZTEST-015 |
| TDG-ZTEST-005 | Payload size limit | SD.binary(max: 65535) | SC-ZTEST-016 |
| TDG-ZTEST-006 | Latency < 10ms | timing_gen | SC-ZTEST-003 |
| TDG-ZTEST-007 | FIFO ordering | sequence_gen | SC-ZTEST-012 |
| TDG-ZTEST-008 | Quorum consensus | quorum_gen | SC-ZTEST-020 |

---

## 10.0 FMEA Risk Analysis (Extended)

| ID | Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation | Constraint |
|----|--------------|----------|------------|-----------|-----|------------|------------|
| FMEA-ZTEST-001 | Zenoh unavailable | 7 | 3 | 8 | 168 | Log fallback | SC-ZTEST-008 |
| FMEA-ZTEST-002 | Message lost | 5 | 2 | 6 | 60 | At-least-once | SC-ZTEST-004 |
| FMEA-ZTEST-003 | High latency | 6 | 3 | 4 | 72 | Async publish | SC-ZTEST-003 |
| FMEA-ZTEST-004 | Schema mismatch | 4 | 2 | 3 | 24 | Version field | SC-ZTEST-014 |
| FMEA-ZTEST-005 | Dashboard stale | 5 | 3 | 2 | 30 | Heartbeat | SC-ZTEST-005 |
| FMEA-ZTEST-006 | State vector corrupt | 8 | 1 | 5 | 40 | Validation | SC-ZTEST-006 |
| FMEA-ZTEST-007 | Topic collision | 9 | 1 | 3 | 27 | Registry | SC-ZTEST-001 |
| FMEA-ZTEST-008 | FIFO violation | 6 | 2 | 4 | 48 | Sequencing | SC-ZTEST-012 |
| FMEA-ZTEST-009 | Quorum lost | 9 | 2 | 3 | 54 | 2oo3 voting | SC-ZTEST-020 |
| FMEA-ZTEST-010 | Log fallback unreadable | 5 | 2 | 4 | 40 | Regex test | AOR-ZTEST-013 |

---

## 11.0 Topic Hierarchy

```
indrajaal/
├── boot/
│   ├── preflight/{start|complete}
│   ├── foundation/{start|complete|db_ready|obs_ready}
│   ├── mesh/{start|complete|quorum}
│   ├── cognitive/{start|complete|bridge|cortex}
│   ├── app/{start|complete|seed_ready}
│   ├── homeostasis/{start|complete|verified}
│   ├── container/{name}/{started|health|ready}
│   ├── state_vector
│   └── complete
│
├── test/
│   ├── suite/{start|complete}
│   ├── compile/{start|complete}
│   ├── module/{name}/{start|complete}
│   ├── case/{test_id}/{start|pass|fail|skip}
│   ├── coverage/report
│   └── summary
│
├── smoke/
│   ├── batch/{batch_id}/{start|progress|complete}
│   ├── node/{node_id}/result
│   ├── category/{api|db|zenoh|perf|security|resilience}/complete
│   └── summary
│
└── orchestrator/
    ├── status
    ├── aggregate
    └── alerts
```

---

## 12.0 Message Schemas

### 12.1 Boot Checkpoint Message

```json
{
  "checkpoint": "CP-BOOT-01",
  "topic": "indrajaal/boot/preflight/start",
  "message": "Comprehensive SIL-6 startup initiated",
  "state_vector": "[0,0,0,0,0,0]",
  "timestamp": "2026-01-18T12:00:00.000Z",
  "schema_version": "2.0.0"
}
```

### 12.2 Test Result Message

```json
{
  "type": "test_passed",
  "checkpoint": "CP-TEST-TX-02",
  "test_id": "uuid",
  "module": "Indrajaal.MyModuleTest",
  "name": "test description",
  "duration_us": 1234,
  "assertions": 5,
  "timestamp": "2026-01-18T12:00:01.234Z"
}
```

### 12.3 Failure Context Message (SC-ZTEST-007)

```json
{
  "type": "test_failed",
  "checkpoint": "CP-TEST-TX-03",
  "test_id": "uuid",
  "duration_us": 5678,
  "failure": {
    "type": "assertion",
    "message": "Expected true, got false",
    "left": "actual_value",
    "right": "expected_value",
    "stacktrace": ["file:line", "..."]
  },
  "timestamp": "2026-01-18T12:00:05.678Z"
}
```

---

## 13.0 Implementation Files

### 13.1 Elixir Modules

| File | Purpose | STAMP |
|------|---------|-------|
| `lib/indrajaal/testing/zenoh_test_formatter.ex` | ExUnit formatter | SC-ZTEST-001,002,004,008 |
| `lib/indrajaal/testing/zenoh_test_orchestrator.ex` | Central aggregator | SC-ZTEST-005 |
| `lib/indrajaal/boot/zenoh_boot_publisher.ex` | Boot publisher | SC-ZTEST-006,009 |
| `lib/indrajaal/testing/checkpoint_messages.ex` | Message schemas | SC-ZTEST-002,007 |

### 13.2 F# Modules

| File | Purpose | STAMP |
|------|---------|-------|
| `lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx` | Swarm integration | SC-ZTEST-008,009,010 |
| `lib/cepaf/scripts/ComprehensiveStartupOrchestrator.fsx` | Jidoka integration | SC-ZTEST-008,009,010 |

---

## 14.0 Verification Commands

```bash
# Subscribe to all boot checkpoints
zenoh-boot-sub     # devenv command

# Subscribe to all test checkpoints
zenoh-test-sub     # devenv command

# Subscribe to all smoke checkpoints
zenoh-smoke-sub    # devenv command

# Subscribe to all checkpoints
zenoh-all-sub      # devenv command

# Run tests with Zenoh orchestration
test-orchestrate   # devenv command

# Verify fallback log parsing
grep '\[ZTEST-CHECKPOINT\]' logs/*.log | head -10
```

---

## 15.0 Success Criteria

| Metric | Target | Verification |
|--------|--------|--------------|
| Checkpoint coverage | 100% | All 26 checkpoints have topics |
| Publish latency | <10ms | Telemetry measurement |
| E2E latency | <100ms | Dashboard update timing |
| Log fallback | 100% | All messages have log backup |
| Dashboard updates | Real-time | Visual verification |
| State vector sync | Every change | Event verification |
| Fallback parseable | 100% | Regex validation |

---

## 16.0 Integration with Existing Constraints

This rule integrates with:
- **SC-ZENOH-001**: Zenoh NIF must be loaded (SKIP_ZENOH_NIF=0)
- **SC-ZENOH-002**: Zenoh router reachable from all app nodes
- **SC-BRIDGE-001**: Message buffer FIFO ordering
- **SC-BRIDGE-003**: Latency budget 50ms
- **SC-OBS-069**: Dual Log (Term+Zenoh)
- **SC-SIL6-001**: Mesh boot 5 stages
- **SC-SIL6-006**: 2oo3 voting MANDATORY

---

## 17.0 DAG Dependency Rules

### 17.1 Boot Checkpoint DAG

```
CP-BOOT-01 → CP-BOOT-02 → CP-BOOT-03 → CP-BOOT-05 → CP-BOOT-08 → CP-BOOT-09 → CP-BOOT-10
                       ↘                 ↗
                         CP-BOOT-04 ────┘
                         CP-BOOT-06 → CP-BOOT-07 ↗
```

### 17.2 DAG Constraints

| ID | Constraint | Mathematical Form |
|----|------------|-------------------|
| DAG-ZTEST-001 | Acyclic dependency graph | $\nexists$ cycle in $G$ |
| DAG-ZTEST-002 | Single source (CP-BOOT-01) | $|sources(G)| = 1$ |
| DAG-ZTEST-003 | Single sink (CP-BOOT-10) | $|sinks(G)| = 1$ |
| DAG-ZTEST-004 | Critical path ≤ 7 hops | $CPL(G) \leq 7$ |
| DAG-ZTEST-005 | Parallel factor ≥ 2 | $width(G) \geq 2$ |

---

## 18.0 Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-01-18 | Claude Opus 4.5 | Initial creation |
| 2.0.0 | 2026-01-18 | Claude Opus 4.5 | Pass 1: Extended STAMP (012-020), Math foundations, TDG, FMEA, DAG rules |
| 2.0.0 | 2026-01-18 | Claude Opus 4.5 | Pass 2: Comprehensive FMEA (20 failure modes), extended AOR rules (001-015) |
| 2.0.0 | 2026-01-18 | Claude Opus 4.5 | Pass 3: Log-based fallback verification, dual-write strategy, verification procedures |

---

## 19.0 Specification Documents

### 19.1 Primary Specifications
| Document | Purpose | Location |
|----------|---------|----------|
| ZENOH_TEST_MESSAGING_COMPREHENSIVE.md | Complete 7x7 architecture spec | `docs/architecture/` |
| ZENOH_TEST_MESSAGING_STAMP_COMPLETE.md | Extended STAMP constraints | `docs/specifications/` |
| ZENOH_TEST_MESSAGING_FMEA_DAG.md | FMEA (20 failure modes) and DAG specs | `docs/specifications/` |
| ZENOH_TEST_MESSAGING_FALLBACK_VERIFICATION.md | Log-based fallback verification | `docs/specifications/` |

### 19.2 Key Standards
- IEC 61508 (SIL-6 Extended)
- ISO 8601 (Timestamp format)
- Zenoh Protocol Specification
