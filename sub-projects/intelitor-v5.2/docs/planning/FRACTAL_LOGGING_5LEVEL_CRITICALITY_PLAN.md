# Fractal Logging System: 5-Level Criticality Implementation Plan
**Version**: 1.0.0 | **Date**: 2025-12-25 | **Status**: APPROVED
**Reference**: 20251224-204500-FRACTAL_LOGGING_SYSTEM_MASTER_GEMINI_v3.md

---

## Executive Summary

This plan implements the Fractal Controllable Logging System with **5 Criticality Levels** (P0-P4), covering:
- Full TDG (Test-Driven Generation) methodology
- STAMP (Systems-Theoretic Accident Model) safety constraints
- AOR (Agent Operating Rules) for 4 Verification Agents
- CEPAF standalone environment and container integration
- Supervisor-based architecture with Cybernetic Mode

## Current Implementation Status

### Implemented Modules (Phase 1-4 Complete)
| Module | Status | Tests | STAMP |
|--------|--------|-------|-------|
| FractalControl | ✅ Complete | ✅ | SC-LOG-001,002,005,006 |
| WriteFilter | ✅ Complete | ✅ | SC-LOG-008 |
| BatchEncoder | ✅ Complete | ✅ | SC-LOG-007 |
| ContentRouter | ✅ Complete | ✅ | - |
| KeyExpression | ✅ Complete | ❌ | SC-LOG-009 |
| HLC | ✅ Complete | ❌ | SC-LOG-006 |
| Decorator | ✅ Complete | ✅ | SC-LOG-003,004 |
| OtelIntegration | ✅ Complete | ✅ | SC-LOG-004 |
| PIIMasker | ✅ Complete | ❌ | SC-LOG-003 |
| Logger | ✅ Complete | ❌ | - |

### Gaps Identified
1. Missing tests for: KeyExpression, HLC, PIIMasker, Logger
2. Missing TDG property tests across all modules
3. Missing CEPAF container integration
4. Missing 4-Agent supervision tree
5. Missing Cybernetic Mode for autonomous control

---

## P0: CRITICAL FOUNDATION (Must Complete First)

### P0.1: Supervisor Architecture (4 Agents)

```
┌─────────────────────────────────────────────────────────────────┐
│          Indrajaal.Observability.Fractal.Supervisor             │
│                    (RestForOne Strategy)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Agent 1:        │  │ Agent 2:        │  │ Agent 3:        │  │
│  │ FractalControl  │  │ WriteFilter     │  │ HLC             │  │
│  │ (GenServer)     │  │ (GenServer)     │  │ (GenServer)     │  │
│  │ Priority: P0    │  │ Priority: P0    │  │ Priority: P1    │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────────────────────────┐   │
│  │ Agent 4:        │  │ PartitionSupervisor:                │   │
│  │ CyberneticCtrl  │  │ BatchEncoder (N partitions)         │   │
│  │ (Cortex Mode)   │  │ Logger (N partitions)               │   │
│  │ Priority: P2    │  │ Priority: P1                        │   │
│  └─────────────────┘  └─────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### P0.1.1: Implementation Tasks
```elixir
# lib/indrajaal/observability/fractal/supervisor.ex
defmodule Indrajaal.Observability.Fractal.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Agent 1: Core State Manager (P0)
      {Indrajaal.Observability.Fractal.FractalControl, []},

      # Agent 2: Write Filtering (P0)
      {Indrajaal.Observability.Fractal.WriteFilter, []},

      # Agent 3: Causal Ordering (P1)
      {Indrajaal.Observability.Fractal.HLC, []},

      # Agent 4: Cybernetic Controller (P2)
      {Indrajaal.Observability.Fractal.CyberneticController, []},

      # Partitioned Logger Pool
      {PartitionSupervisor,
        child_spec: Indrajaal.Observability.Fractal.Logger,
        name: Indrajaal.Observability.Fractal.LoggerPool
      }
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
```

### P0.2: ETS Table Initialization

| Table | Type | Options | Purpose |
|-------|------|---------|---------|
| `:fractal_config` | ordered_set | read_concurrency | Policy storage |
| `:fractal_boosts` | set | write_concurrency | Active boosts |
| `:fractal_subscriptions` | bag | read_concurrency | Zenoh subscribers |
| `:fractal_aliases` | set | read_concurrency | Key alias compression |

### P0.3: STAMP Constraint: SC-LOG-001 (Async Dispatch)

```elixir
# CRITICAL: Never block on log emission
defp emit_async(log_entry) do
  # SC-LOG-001: All emissions via Task.start
  Task.start(fn ->
    FractalControl.dispatch(log_entry)
  end)
end
```

---

## P1: HIGH PRIORITY - STAMP Safety Constraints

### P1.1: SC-LOG Safety Constraint Matrix

| ID | Constraint | Implementation | Verification |
|----|------------|----------------|--------------|
| SC-LOG-001 | Async dispatch (never block) | Task.start wrapper | Property test |
| SC-LOG-002 | Auto-throttle at CPU > 90% | LoadShedder GenServer | Integration test |
| SC-LOG-003 | PII masking at decorator | PIIMasker module | Unit test + TDG |
| SC-LOG-004 | L1/L2 must link to L3 TraceID | OtelIntegration | Integration test |
| SC-LOG-005 | Boosts require TTL (max 1hr) | FractalControl validation | Property test |
| SC-LOG-006 | L3+ logs MUST use HLC | HLC.now() enforcement | Unit test |
| SC-LOG-007 | Batch flush within 10ms | BatchEncoder timer | Performance test |
| SC-LOG-008 | Write filter <1% false negative | Bloom filter sizing | Statistical test |
| SC-LOG-009 | Key aliases pre-registered | Application startup | Integration test |
| SC-LOG-010 | Admin space authenticated | Token verification | Security test |

### P1.2: Load Shedding Implementation (SC-LOG-002)

```elixir
defmodule Indrajaal.Observability.Fractal.LoadShedder do
  @moduledoc """
  SC-LOG-002: Auto-throttle at CPU > 90%

  STAMP Constraint: Observability MUST NOT kill the observed.
  """

  use GenServer

  @shed_threshold 0.90
  @resume_threshold 0.70
  @check_interval_ms 5_000

  def handle_info(:check_load, state) do
    cpu = :cpu_sup.util()

    new_state =
      cond do
        cpu > @shed_threshold and not state.shedding ->
          Logger.warning("[FRACTAL] Load shedding activated: CPU #{cpu}%")
          FractalControl.activate_load_shedding(:cpu_overload)
          %{state | shedding: true}

        cpu < @resume_threshold and state.shedding ->
          Logger.info("[FRACTAL] Load shedding deactivated: CPU #{cpu}%")
          FractalControl.deactivate_load_shedding()
          %{state | shedding: false}

        true ->
          state
      end

    Process.send_after(self(), :check_load, @check_interval_ms)
    {:noreply, new_state}
  end
end
```

### P1.3: HLC Timestamp Enforcement (SC-LOG-006)

```elixir
# In Decorator macro expansion
defp enforce_hlc_timestamp(level, entry) when level in [:l3, :l4, :l5] do
  hlc = Indrajaal.Observability.Fractal.HLC.now()
  %{entry | hlc: hlc}
end

defp enforce_hlc_timestamp(_level, entry), do: entry
```

---

## P2: MEDIUM PRIORITY - TDG Property Tests

### P2.1: TDG Methodology for Fractal Modules

```
┌─────────────────────────────────────────────────────────────────┐
│                    TDG VERIFICATION PIPELINE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. PROPERTY FIRST (TDG-LOG-001)                                │
│     ├── Define failing property test                            │
│     └── Document expected behavior                              │
│                                                                 │
│  2. SPECIFICATION (TDG-LOG-002)                                 │
│     ├── Formalize in Quint (optional)                           │
│     └── Define safety constraints                               │
│                                                                 │
│  3. IMPLEMENTATION (TDG-LOG-003)                                │
│     ├── Write code to pass tests                                │
│     └── Verify STAMP compliance                                 │
│                                                                 │
│  4. CONTINUOUS VERIFICATION (TDG-LOG-004)                       │
│     ├── Run property tests in CI                                │
│     └── Monitor for regressions                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### P2.2: TDG Property Test Suite

```elixir
# test/indrajaal/observability/fractal/tdg_property_tests.exs
defmodule Indrajaal.Observability.Fractal.TDGPropertyTests do
  @moduledoc """
  TDG Property Tests for Fractal Logging System.

  Dual property testing (PropCheck + ExUnitProperties) per SC-PROP-023/024.
  """

  use ExUnit.Case, async: false
  use PropCheck
  # SC-PROP-024: Disambiguate generators
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # ============================================================
  # TDG-LOG-001: Log Admission Property
  # ============================================================

  property "L1 logs are ONLY emitted when boost is active (PropCheck)" do
    forall {key, context} <- {PC.utf8(), context_gen()} do
      # Setup: No boost active
      FractalControl.clear_boosts()

      # Action: Attempt L1 emission
      result = FractalControl.should_log?(key, :l1, context)

      # Assert: Must be rejected without boost
      result == false
    end
  end

  property "L4 logs are always emitted (PropCheck)" do
    forall key <- PC.utf8() do
      result = FractalControl.should_log?(key, :l4, %{})
      result == true
    end
  end

  # ExUnitProperties variant
  property "HLC timestamps are monotonically increasing (StreamData)" do
    check all(count <- SD.integer(1..100)) do
      timestamps = for _ <- 1..count, do: HLC.now()

      timestamps
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.all?(fn [t1, t2] -> HLC.compare(t1, t2) == :lt end)
    end
  end

  # ============================================================
  # TDG-LOG-002: Write Filter Property
  # ============================================================

  property "Write filter has <1% false negative rate (PropCheck)" do
    forall keys <- PC.list(PC.utf8()) do
      # Register all keys
      Enum.each(keys, &WriteFilter.record/1)

      # Check all keys return :emit (false negative = returns :skip wrongly)
      results = Enum.map(keys, &WriteFilter.should_emit?/1)

      false_negatives = Enum.count(results, &(&1 == :skip))
      false_negative_rate = false_negatives / max(length(keys), 1)

      false_negative_rate < 0.01
    end
  end

  # ============================================================
  # TDG-LOG-003: Batch Encoder Property
  # ============================================================

  property "Batch encoding achieves >65% wire savings (PropCheck)" do
    forall messages <- PC.list(log_entry_gen(), max: 100, min: 10) do
      without_batch = Enum.sum(Enum.map(messages, &byte_size(:erlang.term_to_binary(&1))))
      with_batch = byte_size(BatchEncoder.encode_batch(messages))

      savings_pct = 1 - (with_batch / without_batch)
      savings_pct > 0.65
    end
  end

  # ============================================================
  # GENERATORS
  # ============================================================

  defp context_gen do
    PC.let({user_id, tenant_id} <- {PC.utf8(), PC.utf8()}) do
      %{user_id: user_id, tenant_id: tenant_id}
    end
  end

  defp log_entry_gen do
    PC.let({key, level, msg} <- {PC.utf8(), PC.oneof([:l1, :l2, :l3, :l4, :l5]), PC.utf8()}) do
      %{key: key, level: level, message: msg, timestamp: System.os_time(:microsecond)}
    end
  end
end
```

### P2.3: TDG Rules (TDG-LOG)

| Rule ID | Rule | Enforcement | Gate |
|---------|------|-------------|------|
| TDG-LOG-001 | Property MUST be written before implementation | Pre-commit hook | CI |
| TDG-LOG-002 | All STAMP constraints have property tests | Code review | CI |
| TDG-LOG-003 | 95% code coverage on Fractal modules | mix test --cover | CI |
| TDG-LOG-004 | PropCheck + ExUnitProperties dual testing | Module check | CI |

---

## P3: STANDARD - AOR Integration (4 Verification Agents)

### P3.1: Agent Operating Rules (AOR-LOG)

| Rule ID | Rule | Condition | Consequence |
|---------|------|-----------|-------------|
| AOR-LOG-001 | Agent MUST check health before enabling L1 zoom | FractalControl.status() | Block boost if unhealthy |
| AOR-LOG-002 | Agent MUST NOT modify policies without journal entry | Delta detected | Create journal entry |
| AOR-LOG-003 | Agent MUST verify consensus after boost | Boost applied | Check SigNoz + local |

### P3.2: AOR-FV (Formal Verification) Rules

```
┌─────────────────────────────────────────────────────────────────┐
│                AOR: VERIFICATION AGENT OPERATING RULES           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  AOR-FV-001: SPEC BEFORE CODE                                   │
│    "No implementation SHALL begin without an approved spec."    │
│    ℱ(¬∃spec ⟹ ¬∃impl)                                          │
│                                                                 │
│  AOR-FV-002: NO HALLUCINATED PROPERTIES                         │
│    "Every property MUST trace to a documented SC-* constraint." │
│    ∀prop: prop.source ∈ {SC-LOG-*, SC-CNT-*, ...}               │
│                                                                 │
│  AOR-FV-003: PROOF COMPLETENESS                                 │
│    "No partial proofs SHALL be committed."                      │
│    ℱ(∃partial_proof ⟹ merge_blocked)                           │
│                                                                 │
│  AOR-FV-004: VERIFICATION BEFORE MERGE                          │
│    "mix verify.all MUST pass before merge."                     │
│    𝒪(merge ⟹ verify.all.pass)                                   │
│                                                                 │
│  AOR-FV-005: SPEC EVOLUTION PROTOCOL                            │
│    "Any spec change triggers full re-verification."             │
│    Δspec ⟹ reverify_all                                         │
│                                                                 │
│  AOR-FV-006: HAZARD TRACEABILITY                                │
│    "Every hazard H-* MUST link to safety constraints."          │
│    ∀H-*: ∃{SC-*, TDG-*, AOR-*}                                  │
│                                                                 │
│  AOR-FV-007: VERIFICATION AGENT AUTHORITY                       │
│    "Verification failures BLOCK merge unconditionally."         │
│    verify.fail ⟹ ¬merge                                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### P3.3: 4-Agent Architecture

```elixir
defmodule Indrajaal.Observability.Fractal.Agents do
  @moduledoc """
  4-Agent Architecture for Fractal Logging System.

  Agent 1: ControlAgent     - Manages FractalControl state
  Agent 2: FilterAgent      - Manages WriteFilter operations
  Agent 3: TemporalAgent    - Manages HLC and causal ordering
  Agent 4: CyberneticAgent  - Autonomous homeostatic control (Cortex Mode)
  """

  defmodule ControlAgent do
    @moduledoc "Agent 1: Core State Management"
    use GenServer

    @aor_rules [:AOR_LOG_001, :AOR_LOG_002, :AOR_LOG_003]

    def apply_boost(key_expr, depth, ttl, reason) do
      # AOR-LOG-001: Check health first
      with :ok <- verify_health(),
           :ok <- validate_boost(key_expr, depth, ttl),
           {:ok, boost_id} <- FractalControl.focus(key_expr, depth, ttl, reason) do
        # AOR-LOG-002: Journal entry
        create_journal_entry(:boost_applied, %{
          boost_id: boost_id,
          key_expr: key_expr,
          depth: depth,
          reason: reason
        })
        {:ok, boost_id}
      end
    end

    defp verify_health do
      case FractalControl.status() do
        %{healthy: true} -> :ok
        _ -> {:error, :unhealthy_system}
      end
    end
  end

  defmodule CyberneticAgent do
    @moduledoc """
    Agent 4: Cybernetic Controller (Cortex Mode)

    Implements OODA Loop for autonomous observability control.
    """
    use GenServer

    @ooda_cycle_ms 10_000

    defstruct [
      :mode,          # :passive | :active | :autonomous
      :observations,  # Recent system observations
      :orientation,   # Current system assessment
      :decision,      # Pending action
      :confidence     # Decision confidence (0.0 - 1.0)
    ]

    def handle_info(:ooda_cycle, state) do
      new_state =
        state
        |> observe()      # Gather telemetry
        |> orient()       # Assess patterns
        |> decide()       # Choose action
        |> act()          # Execute if confidence > threshold

      Process.send_after(self(), :ooda_cycle, @ooda_cycle_ms)
      {:noreply, new_state}
    end

    defp observe(state) do
      %{state | observations: %{
        cpu: :cpu_sup.util(),
        memory: :memsup.get_memory_data(),
        log_throughput: FractalControl.get_throughput(),
        error_rate: FractalControl.get_error_rate()
      }}
    end

    defp orient(%{observations: obs} = state) do
      assessment = cond do
        obs.cpu > 0.90 -> :overload
        obs.error_rate > 0.05 -> :degraded
        obs.log_throughput < 100 -> :idle
        true -> :normal
      end

      %{state | orientation: assessment}
    end

    defp decide(%{orientation: :overload} = state) do
      %{state | decision: :activate_load_shedding, confidence: 0.95}
    end

    defp decide(%{orientation: :degraded} = state) do
      %{state | decision: :enable_l1_debugging, confidence: 0.75}
    end

    defp decide(state) do
      %{state | decision: :maintain_status_quo, confidence: 1.0}
    end

    defp act(%{decision: :activate_load_shedding, confidence: c} = state) when c > 0.9 do
      FractalControl.activate_load_shedding(:autonomous)
      state
    end

    defp act(%{decision: :enable_l1_debugging, confidence: c} = state) when c > 0.8 do
      FractalControl.focus("**/*error*", :l1, 60_000, "autonomous_debug")
      state
    end

    defp act(state), do: state
  end
end
```

---

## P4: ENHANCEMENT - CEPAF Container Integration

### P4.1: CEPAF Standalone Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CEPAF 4-CONTAINER TOPOLOGY                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ indrajaal-app   │  │ indrajaal-db    │  │ indrajaal-obs   │  │
│  │ (Phoenix/4000)  │  │ (PG17/5433)     │  │ (OTEL/SigNoz)   │  │
│  │                 │  │                 │  │                 │  │
│  │  ┌───────────┐  │  │  ┌───────────┐  │  │  ┌───────────┐  │  │
│  │  │ Fractal   │  │  │  │ TimescaleDB│  │  │  │ Collector │  │  │
│  │  │ Supervisor│──┼──┼──│ Log Store │──┼──┼──│ Pipeline  │  │  │
│  │  └───────────┘  │  │  └───────────┘  │  │  └───────────┘  │  │
│  │        │        │  │                 │  │        │        │  │
│  │  ┌───────────┐  │  │                 │  │  ┌───────────┐  │  │
│  │  │ 4 Agents  │  │  │                 │  │  │ SigNoz UI │  │  │
│  │  │ Control   │  │  │                 │  │  │ :8080     │  │  │
│  │  └───────────┘  │  │                 │  │  └───────────┘  │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
│  Tailscale Mesh: fractal.indrajaal.ts.net                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### P4.2: podman-compose Configuration

```yaml
# podman-compose-fractal.yml
version: "3.9"
services:
  indrajaal-app:
    image: localhost/indrajaal-app:latest
    container_name: indrajaal-app
    environment:
      - FRACTAL_LOGGING_ENABLED=true
      - FRACTAL_DEFAULT_LEVEL=l4
      - FRACTAL_ZENOH_FEATURES=key_expressions,write_filter,hlc,batch_encoding
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://indrajaal-obs:4318
    ports:
      - "4000:4000"
    depends_on:
      - indrajaal-db
      - indrajaal-obs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  indrajaal-db:
    image: localhost/indrajaal-db:latest
    container_name: indrajaal-db
    environment:
      - POSTGRES_USER=indrajaal
      - POSTGRES_PASSWORD=indrajaal_dev
    ports:
      - "5433:5432"
    volumes:
      - indrajaal-db-data:/var/lib/postgresql/data

  indrajaal-obs:
    image: localhost/indrajaal-obs:latest
    container_name: indrajaal-obs
    ports:
      - "4318:4318"   # OTLP gRPC
      - "4317:4317"   # OTLP HTTP
      - "8080:8080"   # SigNoz UI
    environment:
      - FRACTAL_BATCH_FLUSH_MS=10
      - FRACTAL_CONTENT_ROUTING=enabled

volumes:
  indrajaal-db-data:
```

### P4.3: CEPAF F# Integration

```fsharp
// lib/cepaf/src/Cepaf/Observability/Fractal/FractalBridge.fs
namespace Cepaf.Observability.Fractal

open System
open FSharp.Data

/// Bridge for F# components to emit to Elixir Fractal Logging
module FractalBridge =

    /// Fractal levels matching Elixir atoms
    type FractalLevel = L1 | L2 | L3 | L4 | L5

    /// Log entry for cross-language emission
    type LogEntry = {
        Key: string
        Level: FractalLevel
        Message: string
        Context: Map<string, string>
        HlcTimestamp: int64 option
    }

    /// Emit via OTLP to indrajaal-obs container
    let emit (entry: LogEntry) =
        let level = match entry.Level with
                    | L1 -> "l1" | L2 -> "l2" | L3 -> "l3"
                    | L4 -> "l4" | L5 -> "l5"

        // Send to OTLP collector
        async {
            let! response =
                Http.AsyncRequestString(
                    "http://indrajaal-obs:4318/v1/logs",
                    headers = [
                        "Content-Type", "application/json"
                        "X-Fractal-Level", level
                    ],
                    body = TextRequest (JsonConvert.SerializeObject entry)
                )
            return response
        }
```

---

## Implementation Timeline (5 Phases)

### Phase 1: P0 Critical Foundation (Priority: IMMEDIATE)
- [ ] Create Fractal.Supervisor module
- [ ] Initialize 4-agent architecture
- [ ] Configure ETS tables
- [ ] Verify SC-LOG-001 compliance

### Phase 2: P1 STAMP Compliance (Priority: HIGH)
- [ ] Implement LoadShedder (SC-LOG-002)
- [ ] Add HLC enforcement (SC-LOG-006)
- [ ] Verify batch timing (SC-LOG-007)
- [ ] Test write filter accuracy (SC-LOG-008)

### Phase 3: P2 TDG Property Tests (Priority: MEDIUM)
- [ ] Create TDG property test suite
- [ ] Dual PropCheck/ExUnitProperties tests
- [ ] Achieve 95% coverage
- [ ] CI/CD integration

### Phase 4: P3 AOR Agent Integration (Priority: STANDARD)
- [ ] Implement ControlAgent
- [ ] Implement FilterAgent
- [ ] Implement TemporalAgent
- [ ] Implement CyberneticAgent

### Phase 5: P4 CEPAF Integration (Priority: ENHANCEMENT)
- [ ] Create podman-compose-fractal.yml
- [ ] Implement FractalBridge.fs
- [ ] Container health verification
- [ ] End-to-end testing

---

## Verification Gates

| Phase | Gate | Command | Pass Criteria |
|-------|------|---------|---------------|
| 1 | Supervisor starts | `mix test test/fractal/supervisor_test.exs` | All 4 agents running |
| 2 | STAMP compliance | `mix fractal.verify.stamp` | All SC-LOG-* pass |
| 3 | TDG coverage | `mix test --cover` | ≥95% coverage |
| 4 | AOR compliance | `mix fractal.verify.aor` | All AOR-* pass |
| 5 | Container integration | `mix fractal.test.containers` | All 4 containers healthy |

---

## STAMP Hazard Analysis

| Hazard ID | Description | Control | Constraint |
|-----------|-------------|---------|------------|
| H-LOG-001 | Log flooding crashes system | LoadShedder | SC-LOG-002 |
| H-LOG-002 | PII leaked in logs | PIIMasker | SC-LOG-003 |
| H-LOG-003 | Causal ordering lost | HLC | SC-LOG-006 |
| H-LOG-004 | Boost never expires | TTL enforcement | SC-LOG-005 |
| H-LOG-005 | Unauthorized admin access | Token verification | SC-LOG-010 |

---

## Appendix A: Module Dependency Graph

```
                     ┌─────────────────┐
                     │  Supervisor     │
                     └────────┬────────┘
                              │
           ┌──────────────────┼──────────────────┐
           │                  │                  │
    ┌──────▼──────┐    ┌──────▼──────┐    ┌──────▼──────┐
    │FractalControl│    │ WriteFilter │    │    HLC      │
    └──────┬──────┘    └──────┬──────┘    └──────┬──────┘
           │                  │                  │
           └──────────────────┼──────────────────┘
                              │
                     ┌────────▼────────┐
                     │   Decorator     │
                     │  (@fractal)     │
                     └────────┬────────┘
                              │
           ┌──────────────────┼──────────────────┐
           │                  │                  │
    ┌──────▼──────┐    ┌──────▼──────┐    ┌──────▼──────┐
    │KeyExpression│    │ BatchEncoder│    │ContentRouter│
    └─────────────┘    └─────────────┘    └─────────────┘
```

---

*Document Generated: 2025-12-25T10:00:00+01:00*
*Reference: FRACTAL_LOGGING_SYSTEM_MASTER_GEMINI_v3.md*
*Compliance: SOPv5.11 + STAMP + TDG + AOR*
