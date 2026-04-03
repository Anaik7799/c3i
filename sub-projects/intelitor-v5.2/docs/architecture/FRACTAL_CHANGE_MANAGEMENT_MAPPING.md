# Fractal Change Management Mapping (SC-CHG-FRACTAL)

**Version**: 21.3.0-SIL6 | **Date**: 2026-01-10 | **Author**: Claude Opus 4.5
**Status**: ACTIVE | **Compliance**: IEC 61508 SIL-6 (Biomorphic Extended)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [8-Layer Fractal Architecture Overview](#2-8-layer-fractal-architecture-overview)
3. [Layer-by-Layer Change Management Mapping](#3-layer-by-layer-change-management-mapping)
4. [OODA Loop Integration by Layer](#4-ooda-loop-integration-by-layer)
5. [Swarming Capabilities Across Layers](#5-swarming-capabilities-across-layers)
6. [Intelligent Code Evolution Integration](#6-intelligent-code-evolution-integration)
7. [Evolutionary and Operational Modes](#7-evolutionary-and-operational-modes)
8. [Impact Score Matrix](#8-impact-score-matrix)
9. [STAMP Constraints by Layer](#9-stamp-constraints-by-layer)
10. [AOR Rules by Layer](#10-aor-rules-by-layer)
11. [FMEA Risk Analysis](#11-fmea-risk-analysis)
12. [Implementation Patterns](#12-implementation-patterns)

---

## 1. Executive Summary

This document maps the **Change Management Protocol (SC-CHG-000)** to the **8-Layer Fractal Architecture (L0-L7)**, integrating:

- **Fast OODA Loops** at each architectural layer
- **Intelligent Swarming** with 5 algorithms across 50 agents
- **Goal-Directed Evolution (GDE)** for autonomous code improvement
- **Biomorphic Self-Healing** with Constitutional verification
- **4-Layer Reversibility** (Git → Code → Database → System)

### Key Metrics

| Metric | Value | Constraint |
|--------|-------|------------|
| Total STAMP Constraints | 67+ per layer | SC-FUNC-001 |
| OODA Cycle Range | 50ms - 1s | SC-OODA-001 |
| Agent Swarm Size | 25-50 agents | SC-BIO-003 |
| Reversibility Layers | 4 | SC-CHG-REVERSE |
| Constitutional Invariants | 6 (Ψ₀-Ψ₅) | SC-CONST-001 |

---

## 2. 8-Layer Fractal Architecture Overview

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                    8-LAYER FRACTAL ARCHITECTURE (L0-L7)                        ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  L7: FEDERATION ─────────────────────────────────────────────────────────────  ║
║      │ Cross-holon coordination, global consensus, attestation                 ║
║      │ OODA: 1s | Impact: ×4 | Agents: Executive oversight                    ║
║      ▼                                                                         ║
║  L6: CLUSTER ────────────────────────────────────────────────────────────────  ║
║      │ 2oo3 voting, quorum consensus, mesh coordination                        ║
║      │ OODA: 30s sync | Impact: ×3 | Agents: Domain supervisors               ║
║      ▼                                                                         ║
║  L5: NODE ───────────────────────────────────────────────────────────────────  ║
║      │ BEAM VM, scheduler, OTP supervision, resource management               ║
║      │ OODA: 500ms | Impact: ×3 | Agents: Functional agents                   ║
║      ▼                                                                         ║
║  L4: CONTAINER ──────────────────────────────────────────────────────────────  ║
║      │ Podman orchestration, health checks, network isolation                  ║
║      │ OODA: 10s | Impact: ×2 | Agents: Container managers                    ║
║      ▼                                                                         ║
║  L3: HOLON/AGENT ────────────────────────────────────────────────────────────  ║
║      │ Agent logic, SQLite/DuckDB state, Immutable Register                   ║
║      │ OODA: <100ms | Impact: ×2 | Agents: Domain workers                     ║
║      ▼                                                                         ║
║  L2: MODULE/COMPONENT ───────────────────────────────────────────────────────  ║
║      │ GenServer state, Ash domains, OTP behaviors                            ║
║      │ OODA: 100ms | Impact: ×1 | Agents: Code workers                        ║
║      ▼                                                                         ║
║  L1: FUNCTION ───────────────────────────────────────────────────────────────  ║
║      │ Pure functions, I/O contracts, type specs                              ║
║      │ OODA: <1ms | Impact: ×1 | Agents: Micro-workers                        ║
║      ▼                                                                         ║
║  L0: CONSTITUTION ───────────────────────────────────────────────────────────  ║
║      │ Ψ₀-Ψ₅ invariants, Founder's Directive (Ω₀)                             ║
║      │ IMMUTABLE - No changes permitted                                        ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### Layer Responsibility Matrix

| Layer | Responsibility | State Store | Change Frequency |
|-------|---------------|-------------|------------------|
| L0 | Constitutional invariants | Hardcoded | NEVER |
| L1 | Pure function logic | None (stateless) | High |
| L2 | Module/component behavior | GenServer state | Medium |
| L3 | Agent coordination | SQLite/DuckDB | Medium |
| L4 | Container lifecycle | Volume mounts | Low |
| L5 | Runtime environment | BEAM/OTP | Low |
| L6 | Cluster consensus | Distributed state | Very Low |
| L7 | Federation coordination | Cross-holon | Very Low |

---

## 3. Layer-by-Layer Change Management Mapping

### 3.1 L0: Constitution Layer (IMMUTABLE)

**Change Policy**: NO CHANGES PERMITTED

The Constitution layer contains the 6 inviolable axioms (Ψ₀-Ψ₅):

| Axiom | Name | Description |
|-------|------|-------------|
| Ψ₀ | Existence | System MUST survive all operations |
| Ψ₁ | Regeneration | Complete state reconstructible from SQLite/DuckDB |
| Ψ₂ | History | Evolution lineage complete in DuckDB |
| Ψ₃ | Verification | All state changes verifiable |
| Ψ₄ | Human Alignment | PRIMARY=Founder's lineage, SECONDARY=humanity |
| Ψ₅ | Truthfulness | No deception in any communication |

**STAMP Constraints**:
- SC-CONST-001 to SC-CONST-010 (all INFINITE severity)
- Any attempt to modify L0 triggers immediate system halt

**Guardian Override**: Only human-signed "Deus Ex Machina" authorization

---

### 3.2 L1: Function Layer

**Change Policy**: High velocity, pure function mutations

| Aspect | Protocol | Constraint |
|--------|----------|------------|
| OODA Cycle | <1ms | SC-OODA-L1-001 |
| Impact Multiplier | ×1 | SC-CHG-IMPACT-L1 |
| Reversibility | Instant (git revert) | SC-CHG-REVERSE-L1 |
| Testing | TDG with PropCheck/StreamData | SC-TDG-001 |
| Quality Gate | Type specs, dialyzer | SC-QUA-L1-001 |

**Change Note Requirements**:
```elixir
# L1 Change Note (Lightweight)
@change_log %{
  layer: :L1,
  function: "calculate_impact/2",
  type: :bugfix,
  impact_score: 2,  # L1 × LOW = 1 × 2
  reversibility: "git revert",
  tests_added: 3
}
```

**OODA Integration**:
- Observe: Type check failures, spec violations
- Orient: Impact on callers (DFG analysis)
- Decide: Direct fix or refactor
- Act: Edit with immediate compile verification

---

### 3.3 L2: Module/Component Layer

**Change Policy**: Moderate velocity, GenServer state awareness

| Aspect | Protocol | Constraint |
|--------|----------|------------|
| OODA Cycle | 100ms | SC-OODA-L2-001 |
| Impact Multiplier | ×2 | SC-CHG-IMPACT-L2 |
| Reversibility | Git + compile | SC-CHG-REVERSE-L2 |
| Testing | Integration + property | SC-TEST-L2-001 |
| Quality Gate | Credo strict, format | SC-QUA-L2-001 |

**Change Note Requirements**:
```elixir
# L2 Change Note (Standard)
@change_log %{
  layer: :L2,
  module: "Indrajaal.Alarms.AuditLog",
  type: :feature,
  impact_score: 8,  # L2 × MEDIUM = 2 × 4
  files_modified: ["lib/indrajaal/alarms/audit_log.ex"],
  api_changes: [{:add, "log_event/3"}],
  backward_compatible: true,
  reversibility: "git revert + mix compile --force"
}
```

**Swarming Pattern**:
- WRK-COMPILE-{1-3}: Parallel compilation workers
- WRK-CREDO-{1-2}: Quality check workers
- Coordination via UnifiedBus

---

### 3.4 L3: Holon/Agent Layer

**Change Policy**: Careful velocity, state sovereignty critical

| Aspect | Protocol | Constraint |
|--------|----------|------------|
| OODA Cycle | <100ms | SC-OODA-L3-001 |
| Impact Multiplier | ×3 | SC-CHG-IMPACT-L3 |
| Reversibility | Git + DB rollback | SC-CHG-REVERSE-L3 |
| Testing | Agent simulation | SC-TEST-L3-001 |
| State Store | SQLite/DuckDB ONLY | SC-HOLON-001 |

**Change Note Requirements**:
```elixir
# L3 Change Note (Comprehensive)
@change_log %{
  layer: :L3,
  holon: "security_agent",
  type: :refactor,
  impact_score: 15,  # L3 × MEDIUM = 3 × 5
  state_migrations: ["20260110120000_add_threat_level.sql"],
  immutable_register: true,  # Changes logged to blockchain
  guardian_approval: "GUARDIAN-2026-001",
  shadow_tested: true,
  reversibility: "git revert + SQLite restore + Register rollback"
}
```

**Agent Coordination**:
- 10 Domain Supervisors manage agent state
- TrainingGym records action outcomes
- Guardian validates all mutations

---

### 3.5 L4: Container Layer

**Change Policy**: Low velocity, infrastructure focus

| Aspect | Protocol | Constraint |
|--------|----------|------------|
| OODA Cycle | 10s | SC-OODA-L4-001 |
| Impact Multiplier | ×4 | SC-CHG-IMPACT-L4 |
| Reversibility | Image rollback | SC-CHG-REVERSE-L4 |
| Testing | Container integration | SC-TEST-L4-001 |
| Orchestration | Podman rootless | SC-CNT-012 |

**Change Note Requirements**:
```yaml
# L4 Change Note (Container Manifest)
layer: L4
container: indrajaal-ex-app-1
type: config_change
impact_score: 24  # L4 × MEDIUM = 4 × 6
changes:
  - file: podman-compose-prod-standalone.yml
    section: services.app.environment
    modification: add_env_var
ports_affected: [4000, 4001]
volumes_affected: ["/data/holons"]
health_check_updated: true
reversibility: |
  podman tag localhost/indrajaal-app:v[NEW] localhost/indrajaal-app:failed
  podman tag localhost/indrajaal-app:v[OLD] localhost/indrajaal-app:latest
  sa-down && sa-up
```

**3-Container Architecture**:
| Container | Ports | Services |
|-----------|-------|----------|
| indrajaal-db-prod | 5433 | PostgreSQL 17 + TimescaleDB |
| indrajaal-obs-prod | 4317, 9090, 3000 | OTEL + Prometheus + Grafana |
| indrajaal-ex-app-1 | 4000, 4001, 6379 | Phoenix + FLAME + Redis |

---

### 3.6 L5: Node Layer

**Change Policy**: Very low velocity, BEAM/OTP level

| Aspect | Protocol | Constraint |
|--------|----------|------------|
| OODA Cycle | 500ms observation | SC-OODA-L5-001 |
| Impact Multiplier | ×4 | SC-CHG-IMPACT-L5 |
| Reversibility | Runtime restart | SC-CHG-REVERSE-L5 |
| Testing | Distributed tests | SC-TEST-L5-001 |
| Runtime | Elixir 1.19+, OTP 28+ | SC-ENV-001 |

**Change Note Requirements**:
```elixir
# L5 Change Note (Node Configuration)
@change_log %{
  layer: :L5,
  node: "indrajaal@localhost",
  type: :config,
  impact_score: 28,  # L5 × HIGH = 4 × 7
  erlang_flags: ["+S 16:16", "+SDio 16"],
  supervision_tree_changes: [:root_supervisor],
  schedulers_affected: true,
  reversibility: "Runtime restart with previous config"
}
```

**Scheduler Configuration**:
```bash
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"  # 16 schedulers
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8   # Parallel deps
```

---

### 3.7 L6: Cluster Layer

**Change Policy**: Very low velocity, consensus critical

| Aspect | Protocol | Constraint |
|--------|----------|------------|
| OODA Cycle | 30s sync | SC-OODA-L6-001 |
| Impact Multiplier | ×4 | SC-CHG-IMPACT-L6 |
| Reversibility | Cluster reconfiguration | SC-CHG-REVERSE-L6 |
| Testing | Quorum simulation | SC-TEST-L6-001 |
| Consensus | 2oo3 voting | SC-SIL6-006 |

**Change Note Requirements**:
```elixir
# L6 Change Note (Cluster Consensus)
@change_log %{
  layer: :L6,
  cluster: "production",
  type: :scaling,
  impact_score: 36,  # L6 × HIGH = 4 × 9
  nodes_affected: [:node1, :node2, :node3],
  quorum_maintained: true,  # CRITICAL
  voting_protocol: "2oo3",
  federation_notified: true,
  reversibility: "Cluster rollback with state sync"
}
```

**Quorum Rules**:
- Quorum = floor(N/2) + 1
- Changes require 2oo3 voting approval
- Zenoh mesh coordination mandatory

---

### 3.8 L7: Federation Layer

**Change Policy**: Extremely low velocity, cross-holon

| Aspect | Protocol | Constraint |
|--------|----------|------------|
| OODA Cycle | 1s strategy | SC-OODA-L7-001 |
| Impact Multiplier | ×4 | SC-CHG-IMPACT-L7 |
| Reversibility | Federation protocol | SC-CHG-REVERSE-L7 |
| Testing | Formal verification | SC-TEST-L7-001 |
| Attestation | Hourly cross-holon | SC-REG-013 |

**Change Note Requirements**:
```elixir
# L7 Change Note (Federation Protocol)
@change_log %{
  layer: :L7,
  federation: "global",
  type: :protocol_update,
  impact_score: 48,  # L7 × CRITICAL = 4 × 12
  holons_affected: [:holon_alpha, :holon_beta],
  protocol_version: "2.1.0",
  attestation_required: true,
  guardian_chain: ["GUARDIAN-ALPHA", "GUARDIAN-BETA"],
  constitutional_check: :passed,
  reversibility: "Federation rollback with distributed consensus"
}
```

**Federation Protocol**:
- Protocol version negotiation before cross-holon communication
- Ed25519 signed attestations
- Merkle proofs for state verification

---

## 4. OODA Loop Integration by Layer

### 4.1 Three OODA Implementations

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                         OODA LOOP IMPLEMENTATIONS                              ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  FAST OODA (50ms) ─────────────────────────────────────────────────────────   ║
║  │ Layers: L1, L2                                                             ║
║  │ Purpose: Immediate response to code-level changes                          ║
║  │ Agents: WRK-* workers                                                       ║
║  │                                                                             ║
║  │ OBSERVE ──────► ORIENT ──────► DECIDE ──────► ACT                          ║
║  │    5ms           15ms           15ms          15ms                          ║
║  └────────────────────────────────────────────────────────────────────────    ║
║                                                                                ║
║  DISTRIBUTED OODA (<100ms) ────────────────────────────────────────────────   ║
║  │ Layers: L3, L4                                                             ║
║  │ Purpose: Agent and container coordination                                   ║
║  │ Agents: SUP-* supervisors                                                   ║
║  │                                                                             ║
║  │ OBSERVE ──────► ORIENT ──────► DECIDE ──────► ACT                          ║
║  │   20ms           30ms           25ms          25ms                          ║
║  └────────────────────────────────────────────────────────────────────────    ║
║                                                                                ║
║  STRATEGY OODA (1s) ───────────────────────────────────────────────────────   ║
║  │ Layers: L5, L6, L7                                                         ║
║  │ Purpose: System-wide and federation decisions                              ║
║  │ Agents: EXEC-001 executive                                                  ║
║  │                                                                             ║
║  │ OBSERVE ──────► ORIENT ──────► DECIDE ──────► ACT                          ║
║  │  200ms          300ms          250ms         250ms                          ║
║  └────────────────────────────────────────────────────────────────────────    ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### 4.2 OODA Timing Requirements by Layer

| Layer | OODA Cycle | Observe | Orient | Decide | Act |
|-------|------------|---------|--------|--------|-----|
| L0 | N/A | - | - | - | - |
| L1 | <1ms | 0.2ms | 0.3ms | 0.3ms | 0.2ms |
| L2 | 100ms | 20ms | 30ms | 30ms | 20ms |
| L3 | <100ms | 20ms | 30ms | 25ms | 25ms |
| L4 | 10s | 2s | 3s | 3s | 2s |
| L5 | 500ms | 100ms | 150ms | 150ms | 100ms |
| L6 | 30s | 5s | 10s | 10s | 5s |
| L7 | 1s | 200ms | 300ms | 300ms | 200ms |

### 4.3 OODA Integration with Change Management

```elixir
defmodule Indrajaal.ChangeManagement.OODAIntegration do
  @moduledoc """
  Integrates OODA loop with change management at each layer.

  ## STAMP Constraints
  - SC-OODA-001: OODA cycle < 100ms for L1-L3
  - SC-CHG-001: All changes via structured change notes
  """

  alias Indrajaal.Guardian
  alias Indrajaal.ImmutableRegister

  @spec execute_change(change_note :: map(), layer :: atom()) ::
    {:ok, result :: map()} | {:error, reason :: term()}
  def execute_change(change_note, layer) do
    with :ok <- observe(layer),
         {:ok, analysis} <- orient(change_note, layer),
         {:ok, decision} <- decide(analysis, layer),
         {:ok, result} <- act(decision, layer) do
      # Record to Immutable Register
      ImmutableRegister.append_block(%{
        type: :change_executed,
        layer: layer,
        change_note: change_note,
        result: result,
        timestamp: DateTime.utc_now()
      })

      {:ok, result}
    end
  end

  defp observe(layer) do
    # Layer-specific observation within OODA timing budget
    case layer do
      :L1 -> observe_function_state()    # <1ms
      :L2 -> observe_module_state()      # 20ms
      :L3 -> observe_agent_state()       # 20ms
      :L4 -> observe_container_state()   # 2s
      :L5 -> observe_node_state()        # 100ms
      :L6 -> observe_cluster_state()     # 5s
      :L7 -> observe_federation_state()  # 200ms
    end
  end

  defp orient(change_note, layer) do
    # 5-order impact analysis
    impact = calculate_impact(change_note, layer)

    # Risk assessment
    risk = assess_risk(impact)

    # Constitutional check (L0)
    with :ok <- Guardian.verify_constitutional_compliance(change_note) do
      {:ok, %{impact: impact, risk: risk}}
    end
  end

  defp decide(%{impact: impact, risk: risk}, layer) do
    cond do
      risk >= 31 ->
        # CRITICAL: Requires Guardian approval
        {:ok, %{action: :await_guardian, escalation: :critical}}

      risk >= 21 ->
        # HIGH: Requires architecture review
        {:ok, %{action: :architecture_review, escalation: :high}}

      risk >= 11 ->
        # MEDIUM: Requires senior review
        {:ok, %{action: :senior_review, escalation: :medium}}

      true ->
        # LOW: Standard execution
        {:ok, %{action: :execute, escalation: :low}}
    end
  end

  defp act(decision, layer) do
    case decision.action do
      :execute -> execute_layer_change(layer)
      :senior_review -> await_review_then_execute(layer, :senior)
      :architecture_review -> await_review_then_execute(layer, :architecture)
      :await_guardian -> Guardian.request_approval(layer)
    end
  end
end
```

---

## 5. Swarming Capabilities Across Layers

### 5.1 Agent Swarm Architecture

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                      AGENT SWARM ARCHITECTURE (50 AGENTS)                      ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  LAYER 1: EXECUTIVE (1 Agent) ─────────────────────────────────────────────   ║
║  │                                                                             ║
║  │  ┌─────────────────────────────────────────────────────────────────┐       ║
║  │  │  EXEC-001: Master Orchestrator (Opus model)                     │       ║
║  │  │  • Veto authority over all changes                              │       ║
║  │  │  • /compact trigger at 75% context                              │       ║
║  │  │  • Strategic OODA (1s cycle)                                    │       ║
║  │  └─────────────────────────────────────────────────────────────────┘       ║
║  │                                                                             ║
║  └──────────────────────────────────────────────────────────────────────────  ║
║                                                                                ║
║  LAYER 2: DOMAIN SUPERVISORS (10 Agents) ──────────────────────────────────   ║
║  │                                                                             ║
║  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           ║
║  │  │ SUP-ACCESS  │ │ SUP-ALARMS  │ │ SUP-DEVICES │ │ SUP-SAFETY  │           ║
║  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘           ║
║  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           ║
║  │  │ SUP-BILLING │ │ SUP-CONFIG  │ │ SUP-INTEGR  │ │ SUP-ANALYT  │           ║
║  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘           ║
║  │  ┌─────────────┐ ┌─────────────┐                                            ║
║  │  │ SUP-COMPLI  │ │ SUP-INTELLI │ (Sonnet model)                            ║
║  │  └─────────────┘ └─────────────┘                                            ║
║  │                                                                             ║
║  └──────────────────────────────────────────────────────────────────────────  ║
║                                                                                ║
║  LAYER 3: FUNCTIONAL AGENTS (15 Agents) ───────────────────────────────────   ║
║  │                                                                             ║
║  │  ┌───────────────────────────────────────────────────────────────────────┐ ║
║  │  │ Guardian  │ Sentinel │ PatternHunter │ TrainingGym │ GDE Controller  │ ║
║  │  └───────────────────────────────────────────────────────────────────────┘ ║
║  │  ┌───────────────────────────────────────────────────────────────────────┐ ║
║  │  │ MetricsSink │ TelemetryHub │ EventRouter │ StateManager │ CacheLayer │ ║
║  │  └───────────────────────────────────────────────────────────────────────┘ ║
║  │  ┌───────────────────────────────────────────────────────────────────────┐ ║
║  │  │ BridgeSvc │ AuthProvider │ AuditLogger │ NotifyEngine │ HealthCheck  │ ║
║  │  └───────────────────────────────────────────────────────────────────────┘ ║
║  │                                                                             ║
║  └──────────────────────────────────────────────────────────────────────────  ║
║                                                                                ║
║  LAYER 4: WORKER AGENTS (24 Agents) ───────────────────────────────────────   ║
║  │                                                                             ║
║  │  WRK-COMPILE-{1-3}    │ Parallel compilation (Haiku model)                 ║
║  │  WRK-TEST-{1-5}       │ Test execution                                     ║
║  │  WRK-CREDO-{1-2}      │ Code quality                                       ║
║  │  WRK-FIX-{1-5}        │ Bug fixes                                          ║
║  │  WRK-DOC-{1-2}        │ Documentation                                      ║
║  │  WRK-EXPLORE-{1-3}    │ Codebase exploration                               ║
║  │  WRK-SWARM-{1-4}      │ Swarm coordination                                 ║
║  │                                                                             ║
║  └──────────────────────────────────────────────────────────────────────────  ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### 5.2 Five Swarm Algorithms

| Algorithm | Use Case | Change Management Integration |
|-----------|----------|------------------------------|
| **Particle Swarm** | Global optimization | Best solution discovery across agents |
| **Ant Colony** | Path finding | Optimal change sequence identification |
| **Bee Algorithm** | Resource allocation | Agent task distribution |
| **Firefly** | Clustering | Related change grouping |
| **Grey Wolf** | Leadership hierarchy | Supervisor coordination |

### 5.3 UnifiedBus Communication

```elixir
defmodule Indrajaal.UnifiedBus do
  @moduledoc """
  Central async messaging hub for swarm coordination.

  ## STAMP Constraints
  - SC-BUS-001: Async messaging only
  - SC-BUS-002: No blocking operations
  - SC-BUS-003: Circuit breaker at 1000 events/sec
  - SC-BUS-004: Event ordering preserved
  - SC-BUS-005: Telemetry on all events
  """

  use GenServer

  @circuit_breaker_threshold 1000
  @event_buffer_size 10_000

  def broadcast_change(change_event) do
    GenServer.cast(__MODULE__, {:broadcast, change_event})
  end

  def subscribe(agent_id, topics) do
    GenServer.call(__MODULE__, {:subscribe, agent_id, topics})
  end

  # Change events routed by layer
  def route_to_layer(event, layer) do
    topics = layer_topics(layer)
    Enum.each(topics, &Phoenix.PubSub.broadcast(Indrajaal.PubSub, &1, event))
  end

  defp layer_topics(layer) do
    case layer do
      :L1 -> ["change:function", "swarm:workers"]
      :L2 -> ["change:module", "swarm:workers"]
      :L3 -> ["change:agent", "swarm:supervisors"]
      :L4 -> ["change:container", "swarm:supervisors"]
      :L5 -> ["change:node", "swarm:executive"]
      :L6 -> ["change:cluster", "swarm:executive"]
      :L7 -> ["change:federation", "swarm:executive"]
    end
  end
end
```

### 5.4 Swarming by Layer

| Layer | Swarm Strategy | Agents Involved | Coordination |
|-------|----------------|-----------------|--------------|
| L0 | N/A (immutable) | None | - |
| L1-L2 | Parallel workers | WRK-{COMPILE,TEST,FIX} | UnifiedBus broadcast |
| L3 | Domain-specific | SUP-{DOMAIN} + workers | Topic-based routing |
| L4 | Container-focused | Container managers | Health check consensus |
| L5-L6 | Supervisory | EXEC + SUP-* | Hierarchical escalation |
| L7 | Cross-holon | Executive only | Federation protocol |

---

## 6. Intelligent Code Evolution Integration

### 6.1 Goal-Directed Evolution (GDE) 6-Phase Cycle

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                      GDE 6-PHASE EVOLUTION CYCLE                               ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  Phase 1: PROPOSAL ──────────────────────────────────────────────────────     ║
║  │ • AI agents (Gemini + Claude) generate code improvement proposals          ║
║  │ • Fitness function evaluation: coverage, pass rate, mutation score         ║
║  │ • Diversity floor: 0.3 (prevent convergence)                               ║
║  └──────────────────────────────────────────────────────────────────────────  ║
║                                     ▼                                          ║
║  Phase 2: CONSTITUTIONAL CHECK ──────────────────────────────────────────     ║
║  │ • Verify Ψ₀-Ψ₅ compliance                                                  ║
║  │ • Founder's Directive (Ω₀) alignment                                       ║
║  │ • STAMP constraint validation                                               ║
║  └──────────────────────────────────────────────────────────────────────────  ║
║                                     ▼                                          ║
║  Phase 3: SHADOW TESTING ────────────────────────────────────────────────     ║
║  │ • Parallel execution without actuator access                               ║
║  │ • Full test suite in shadow mode                                           ║
║  │ • Collect metrics without production impact                                 ║
║  └──────────────────────────────────────────────────────────────────────────  ║
║                                     ▼                                          ║
║  Phase 4: GUARDIAN VALIDATION ───────────────────────────────────────────     ║
║  │ • 6 validation checks per proposal                                          ║
║  │ • Safety margin calculation                                                 ║
║  │ • Approval threshold: ≥0.85                                                 ║
║  └──────────────────────────────────────────────────────────────────────────  ║
║                                     ▼                                          ║
║  Phase 5: ACTIVATION ────────────────────────────────────────────────────     ║
║  │ • Progressive rollout (canary → staged → full)                             ║
║  │ • Continuous monitoring during activation                                   ║
║  │ • Rollback trigger on degradation                                           ║
║  └──────────────────────────────────────────────────────────────────────────  ║
║                                     ▼                                          ║
║  Phase 6: LEARNING ──────────────────────────────────────────────────────     ║
║  │ • Record outcome to TrainingGym                                             ║
║  │ • Q-learning style reinforcement                                            ║
║  │ • Update fitness function weights                                           ║
║  └──────────────────────────────────────────────────────────────────────────  ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### 6.2 Bicameral AI Architecture

| AI System | Role | Specialization |
|-----------|------|----------------|
| **Gemini (Pro/Flash)** | Analysis | AST probing, semantic analysis, dependency graphs |
| **Claude (Opus/Sonnet/Haiku)** | Synthesis | Code generation, refactoring, documentation |

**Model Selection by Task**:
| Task Type | Model | Reasoning |
|-----------|-------|-----------|
| Complex architecture | Claude Opus | Deep reasoning required |
| Code review | Claude Sonnet | Balance of quality/cost |
| Worker tasks | Claude Haiku | Cost efficiency |
| Static analysis | Gemini Pro | Pattern matching strength |
| Quick checks | Gemini Flash | Speed |

### 6.3 Guardian Safety Kernel

```elixir
defmodule Indrajaal.Guardian do
  @moduledoc """
  Safety kernel for intelligent code evolution.
  Implements Simplex architecture with fallback.

  ## STAMP Constraints
  - SC-GDE-001: Guardian validation required
  - SC-GDE-002: Shadow testing mandatory
  - SC-GDE-003: Rollback capability
  - SC-GDE-004: Proposal threshold ≥0.85
  """

  @approval_threshold 0.85
  @validation_checks 6

  defstruct [:complex_controller, :safety_controller, :decision_module]

  @spec validate_evolution(proposal :: map()) ::
    {:approved, score :: float()} | {:rejected, reason :: term()}
  def validate_evolution(proposal) do
    checks = [
      check_constitutional_compliance(proposal),
      check_stamp_constraints(proposal),
      check_shadow_test_results(proposal),
      check_impact_score(proposal),
      check_reversibility(proposal),
      check_founder_directive(proposal)
    ]

    passed = Enum.count(checks, &(&1 == :ok))
    score = passed / @validation_checks

    if score >= @approval_threshold do
      {:approved, score}
    else
      {:rejected, {:score_below_threshold, score}}
    end
  end

  defp check_constitutional_compliance(proposal) do
    # Verify Ψ₀-Ψ₅ invariants
    invariants = [:existence, :regeneration, :history, :verification, :alignment, :truthfulness]

    Enum.all?(invariants, fn inv ->
      verify_invariant(proposal, inv)
    end) && :ok || {:error, :constitutional_violation}
  end

  defp check_founder_directive(proposal) do
    # SC-FOUNDER-001: ALL actions serve Founder's lineage
    cond do
      proposal.impact.founder_benefit > 0 -> :ok
      proposal.impact.founder_neutral? -> :ok
      true -> {:error, :founder_directive_violation}
    end
  end
end
```

### 6.4 TrainingGym Integration

```elixir
defmodule Indrajaal.TrainingGym do
  @moduledoc """
  Q-learning style reinforcement for code evolution.

  Records episodes of:
  - Proposal characteristics
  - Execution outcomes
  - Fitness improvements
  - Failure patterns
  """

  @spec record_episode(episode :: map()) :: :ok
  def record_episode(episode) do
    # Store in DuckDB for analysis
    DuckDB.insert(:training_episodes, %{
      proposal_id: episode.proposal_id,
      layer: episode.layer,
      action_type: episode.action_type,
      pre_fitness: episode.pre_fitness,
      post_fitness: episode.post_fitness,
      reward: calculate_reward(episode),
      timestamp: DateTime.utc_now()
    })

    # Update Q-table for layer
    update_q_table(episode.layer, episode)

    :ok
  end

  defp calculate_reward(episode) do
    delta = episode.post_fitness - episode.pre_fitness

    cond do
      delta > 0.1 -> 1.0     # Strong improvement
      delta > 0.0 -> 0.5     # Mild improvement
      delta == 0.0 -> 0.0    # No change
      delta > -0.1 -> -0.5   # Mild regression
      true -> -1.0           # Strong regression
    end
  end
end
```

---

## 7. Evolutionary and Operational Modes

### 7.1 Four Evolutionary Phases (SDLC)

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                    EVOLUTIONARY PHASES (DESIGN → OPERATE)                      ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  PHASE 1: DESIGN ────────────────────────────────────────────────────────     ║
║  │ Agents: fractal-architect, holon-analyzer, impact-analyzer                 ║
║  │ Tools: Quint, Agda, FMEA, constitutional-verifier                          ║
║  │                                                                             ║
║  │ Change Protocol:                                                            ║
║  │ • 4-layer impact analysis BEFORE any implementation                         ║
║  │ • Constitutional invariant check                                            ║
║  │ • Reversibility plan documented                                             ║
║  │ • Guardian pre-approval for L5+ changes                                     ║
║  └──────────────────────────────────────────────────────────────────────────  ║
║                                     ▼                                          ║
║  PHASE 2: BUILD ─────────────────────────────────────────────────────────     ║
║  │ Agents: code-evolution, code-debugger, test-generator, code-reviewer       ║
║  │ Tools: TDG, PropCheck, ExUnitProperties, Credo, Dialyzer                   ║
║  │                                                                             ║
║  │ Change Protocol:                                                            ║
║  │ • TDG: Tests BEFORE implementation                                          ║
║  │ • Dual property tests (PropCheck + StreamData)                              ║
║  │ • Shadow testing before activation                                          ║
║  │ • In-file change tracking (moduledoc updates)                               ║
║  └──────────────────────────────────────────────────────────────────────────  ║
║                                     ▼                                          ║
║  PHASE 3: DEPLOY ────────────────────────────────────────────────────────     ║
║  │ Agents: deploy-supervisor, script-finder, robustness-analyzer              ║
║  │ Tools: Podman, sa-up/down, checkpoint/restore                              ║
║  │                                                                             ║
║  │ Change Protocol:                                                            ║
║  │ • Checkpoint state before deployment                                        ║
║  │ • Progressive rollout (canary 5% → staged 25% → full 100%)                 ║
║  │ • Health checks at each stage                                               ║
║  │ • Rollback on degradation                                                   ║
║  └──────────────────────────────────────────────────────────────────────────  ║
║                                     ▼                                          ║
║  PHASE 4: OPERATE ───────────────────────────────────────────────────────     ║
║  │ Agents: operate-supervisor, prajna-operator, immune-chaos-agent            ║
║  │ Tools: Zenoh, OTEL, Grafana, Sentinel, PatternHunter                       ║
║  │                                                                             ║
║  │ Change Protocol:                                                            ║
║  │ • Continuous OODA monitoring                                                ║
║  │ • SRE error budget tracking                                                 ║
║  │ • Postmortem for incidents                                                  ║
║  │ • Continuous improvement via TrainingGym                                    ║
║  └──────────────────────────────────────────────────────────────────────────  ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### 7.2 Four Operational Modes

| Mode | Impact Score | Description | Change Velocity |
|------|--------------|-------------|-----------------|
| **NORMAL** | 0-20 | Standard operations | High |
| **HIGH-RISK** | 21-30 | Senior review required | Medium |
| **CRITICAL** | 31-40 | Architecture review + Guardian | Low |
| **EMERGENCY** | 40+ | Immediate halt + rollback | Zero |

### 7.3 Operational Mode State Machine

```
                    ┌─────────────────────┐
                    │      NORMAL         │
                    │   (0-20 impact)     │
                    └──────────┬──────────┘
                               │
                    Impact > 20│
                               ▼
                    ┌─────────────────────┐
                    │     HIGH-RISK       │
                    │   (21-30 impact)    │◄────────┐
                    └──────────┬──────────┘         │
                               │                    │
                    Impact > 30│          Impact <= 20
                               ▼                    │
                    ┌─────────────────────┐         │
                    │      CRITICAL       │─────────┘
                    │   (31-40 impact)    │
                    └──────────┬──────────┘
                               │
                    Impact > 40│ OR
                    Constitution violated
                               ▼
                    ┌─────────────────────┐
                    │     EMERGENCY       │
                    │   (40+ impact)      │
                    │   HALT ALL CHANGES  │
                    └─────────────────────┘
```

### 7.4 SRE Integration

```elixir
defmodule Indrajaal.SRE.ChangeControl do
  @moduledoc """
  SRE-based change control with error budgets.

  Integrates with change management to:
  - Track error budget consumption
  - Block deploys when budget exhausted
  - Manage progressive rollouts
  - Trigger postmortems
  """

  @slo_availability 0.999  # 99.9% availability target
  @budget_threshold 0.2    # 20% minimum remaining

  def can_deploy? do
    case ErrorBudget.remaining() do
      %{percentage_remaining: remaining} when remaining >= @budget_threshold ->
        {:ok, :deploy_allowed}

      %{percentage_remaining: remaining} ->
        {:error, {:budget_exhausted, remaining}}
    end
  end

  def progressive_rollout(deployment_id, stages \\ [:canary, :staged, :full]) do
    Enum.reduce_while(stages, {:ok, 0}, fn stage, {:ok, _} ->
      case rollout_stage(deployment_id, stage) do
        :ok ->
          # Wait for health verification
          if health_verified?(deployment_id, stage) do
            {:cont, {:ok, stage_percentage(stage)}}
          else
            rollback(deployment_id)
            {:halt, {:error, {:health_check_failed, stage}}}
          end

        {:error, reason} ->
          rollback(deployment_id)
          {:halt, {:error, reason}}
      end
    end)
  end

  defp stage_percentage(:canary), do: 5
  defp stage_percentage(:staged), do: 25
  defp stage_percentage(:full), do: 100
end
```

---

## 8. Impact Score Matrix

### 8.1 4-Layer Impact Calculation

```
Impact Score = Σ(Layer Weight × Severity)

Layer Weights:
  L1-CODE:      ×1
  L2-DOMAIN:    ×2
  L3-SYSTEM:    ×3
  L4-ECOSYSTEM: ×4

Severity Levels:
  NONE:     0
  LOW:      1-2
  MEDIUM:   3-4
  HIGH:     5-7
  CRITICAL: 8-10
```

### 8.2 Impact Matrix by Fractal Layer

| Fractal Layer | L1-CODE | L2-DOMAIN | L3-SYSTEM | L4-ECOSYSTEM | Max Score |
|---------------|---------|-----------|-----------|--------------|-----------|
| L0 Constitution | - | - | - | - | INFINITE |
| L1 Function | 2 | 0 | 0 | 0 | 2 |
| L2 Module | 3 | 4 | 0 | 0 | 7 |
| L3 Holon | 3 | 6 | 6 | 0 | 15 |
| L4 Container | 2 | 4 | 9 | 4 | 19 |
| L5 Node | 2 | 4 | 9 | 8 | 23 |
| L6 Cluster | 3 | 6 | 9 | 12 | 30 |
| L7 Federation | 4 | 8 | 12 | 16 | 40 |

### 8.3 Decision Matrix

| Impact Score | Risk Level | Required Review | Change Velocity |
|--------------|------------|-----------------|-----------------|
| 0-10 | LOW | Standard (peer review) | Fast (< 1 hour) |
| 11-20 | MEDIUM | Senior engineer | Medium (< 4 hours) |
| 21-30 | HIGH | Architecture review | Slow (< 1 day) |
| 31-40 | CRITICAL | Guardian approval | Very slow (< 1 week) |
| 40+ | EMERGENCY | HALT + escalation | None until resolved |

---

## 9. STAMP Constraints by Layer

### 9.1 L0: Constitution Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-CONST-001 | Ψ₀ Existence INVIOLABLE | INFINITE |
| SC-CONST-002 | Ψ₁ Regeneration INVIOLABLE | INFINITE |
| SC-CONST-003 | Ψ₂ History INVIOLABLE | INFINITE |
| SC-CONST-004 | Ψ₃ Verification INVIOLABLE | INFINITE |
| SC-CONST-005 | Ψ₄ Human Alignment AMENDED | INFINITE |
| SC-CONST-006 | Ψ₅ Truthfulness INVIOLABLE | INFINITE |
| SC-CONST-007 | Guardian has absolute veto | CRITICAL |

### 9.2 L1-L2: Function/Module Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-FUNC-001 | System MUST compile | CRITICAL |
| SC-TDG-001 | Tests BEFORE code | CRITICAL |
| SC-PROP-023 | PC/SD alias disambiguation | HIGH |
| SC-CREDO-001 | No apply/2 anti-pattern | HIGH |
| SC-VAR-001 | No underscore on used vars | HIGH |

### 9.3 L3: Holon/Agent Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-HOLON-001 | SQLite/DuckDB state only | CRITICAL |
| SC-HOLON-009 | SQLite is authoritative | CRITICAL |
| SC-REG-001 | Append-only register | CRITICAL |
| SC-IMMUNE-001 | Sentinel continuous monitoring | HIGH |

### 9.4 L4-L5: Container/Node Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-CNT-009 | NixOS/Podman only | CRITICAL |
| SC-CNT-012 | Rootless containers | CRITICAL |
| SC-PRF-050 | Response < 50ms | HIGH |
| SC-EMR-057 | Stop < 5s | CRITICAL |

### 9.5 L6-L7: Cluster/Federation Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SIL6-006 | 2oo3 voting mandatory | CRITICAL |
| SC-SIL6-011 | Quorum = floor(N/2)+1 | CRITICAL |
| SC-REG-013 | Cross-holon attestation | HIGH |
| SC-RECONFIG-001 | L1-L7 reconfigurable | HIGH |

---

## 10. AOR Rules by Layer

### 10.1 Universal AOR Rules

| ID | Rule | Applicability |
|----|------|---------------|
| AOR-FUNC-001 | VERIFY compilation before commit | ALL |
| AOR-FUNC-002 | CHECKPOINT before risky ops | L3+ |
| AOR-FUNC-005 | ROLLBACK on degradation | ALL |
| AOR-FUNC-008 | HALT on invariant violation | ALL |

### 10.2 Layer-Specific AOR Rules

| Layer | Key AOR Rules |
|-------|--------------|
| L1-L2 | AOR-VAR-001, AOR-CREDO-001, AOR-TEST-001 |
| L3 | AOR-HOLON-001 to AOR-HOLON-020 |
| L4 | AOR-CNT-001, AOR-MESH-001 to AOR-MESH-010 |
| L5-L6 | AOR-API-001 to AOR-API-008, AOR-CLI-001 |
| L7 | AOR-RECONFIG-001 to AOR-RECONFIG-007 |

---

## 11. FMEA Risk Analysis

### 11.1 Cross-Layer Failure Modes

| Failure Mode | Layer | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|-------|----------|------------|-----------|-----|------------|
| Constitutional violation | L0 | 10 | 1 | 10 | 100 | Guardian veto, immediate halt |
| Compile failure | L1-L2 | 8 | 5 | 2 | 80 | Pre-commit hooks, Patient Mode |
| Agent state corruption | L3 | 9 | 2 | 5 | 90 | SQLite backup, register rollback |
| Container crash | L4 | 7 | 4 | 3 | 84 | Health checks, auto-restart |
| Node isolation | L5-L6 | 8 | 2 | 4 | 64 | Quorum consensus, failover |
| Federation split | L7 | 9 | 1 | 6 | 54 | Attestation protocol, reconciliation |

### 11.2 RPN Thresholds

| RPN Range | Risk Level | Action Required |
|-----------|------------|-----------------|
| 0-30 | LOW | Standard monitoring |
| 31-60 | MEDIUM | Documented mitigation |
| 61-80 | HIGH | Active mitigation + review |
| 81-100 | CRITICAL | Immediate action required |

---

## 12. Implementation Patterns

### 12.1 Change Execution Template

```elixir
defmodule Indrajaal.ChangeManagement.Executor do
  @moduledoc """
  Template for executing changes with full protocol compliance.
  """

  alias Indrajaal.{Guardian, ImmutableRegister, UnifiedBus}

  def execute_change(change_note) do
    layer = determine_layer(change_note)

    with :ok <- pre_flight_checks(layer),
         {:ok, impact} <- calculate_impact(change_note, layer),
         {:ok, mode} <- determine_operational_mode(impact),
         :ok <- get_required_approvals(mode),
         :ok <- checkpoint_state(layer),
         {:ok, result} <- apply_change(change_note),
         :ok <- verify_functionality(),
         :ok <- log_to_register(change_note, result) do
      # Broadcast success to swarm
      UnifiedBus.broadcast_change(%{
        type: :change_complete,
        layer: layer,
        impact: impact,
        result: result
      })

      {:ok, result}
    else
      {:error, reason} ->
        # Trigger rollback
        rollback_change(change_note, reason)
        {:error, reason}
    end
  end

  defp pre_flight_checks(layer) do
    checks = [
      {:constitution, &check_constitutional_compliance/0},
      {:compilation, &check_compile_status/0},
      {:containers, &check_container_health/0}
    ]

    Enum.reduce_while(checks, :ok, fn {name, check_fn}, :ok ->
      case check_fn.() do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {name, reason}}}
      end
    end)
  end
end
```

### 12.2 Swarm Coordination Pattern

```elixir
defmodule Indrajaal.Swarm.Coordinator do
  @moduledoc """
  Coordinates agent swarm for parallel change execution.
  """

  alias Indrajaal.UnifiedBus

  @max_parallel_workers 20

  def distribute_changes(change_batch) when is_list(change_batch) do
    # Group by layer for efficient execution
    grouped = Enum.group_by(change_batch, & &1.layer)

    # Execute L1-L2 in parallel (worker agents)
    l1_l2_changes = Map.get(grouped, :L1, []) ++ Map.get(grouped, :L2, [])
    l1_l2_tasks = spawn_workers(l1_l2_changes, :parallel)

    # Execute L3+ sequentially with proper coordination
    higher_layer_changes =
      [:L3, :L4, :L5, :L6, :L7]
      |> Enum.flat_map(&Map.get(grouped, &1, []))

    # Wait for L1-L2 before L3+
    l1_l2_results = Task.await_many(l1_l2_tasks)

    if Enum.all?(l1_l2_results, &match?({:ok, _}, &1)) do
      execute_sequential(higher_layer_changes)
    else
      {:error, :lower_layer_failures}
    end
  end

  defp spawn_workers(changes, :parallel) do
    changes
    |> Enum.take(@max_parallel_workers)
    |> Enum.map(fn change ->
      Task.async(fn ->
        UnifiedBus.broadcast_change(%{type: :worker_assigned, change: change})
        ChangeExecutor.execute_change(change)
      end)
    end)
  end
end
```

---

## Document Control

| Field | Value |
|-------|-------|
| Document ID | ARCH-FRACTAL-CHG-001 |
| Version | 1.0.0 |
| Status | ACTIVE |
| Author | Claude Opus 4.5 |
| Created | 2026-01-10 |
| Last Updated | 2026-01-10 |
| Review Cycle | Quarterly |

## Related Documents

| Document | Location |
|----------|----------|
| Change Management Protocol | `.claude/rules/change-management.md` |
| SOP Guide | `docs/sop/CHANGE_MANAGEMENT_PROTOCOL_GUIDE.md` |
| Holon Architecture | `docs/architecture/HOLON_IMMORTAL_ARCHITECTURE.md` |
| Immutable Register | `docs/architecture/HOLON_IMMUTABLE_REGISTER.md` |
| Fast OODA Protocol | `docs/architecture/FAST_OODA_PROTOCOL.md` |
| Constitutional Reconfiguration | `docs/architecture/HOLON_CONSTITUTIONAL_RECONFIGURATION.md` |
| CAE Architecture | `docs/architecture/20251229-1200-cae-fractal-architecture-summary.md` |
| Agent Cognitive Protocol | `.claude/rules/agent-cognitive-protocol.md` |

---

**STAMP**: SC-CHG-FRACTAL-001 to SC-CHG-FRACTAL-010
**AOR**: AOR-CHG-FRACTAL-001 to AOR-CHG-FRACTAL-010

*This document is subject to the Change Management Protocol (SC-CHG-000) and requires Guardian approval for modifications.*
