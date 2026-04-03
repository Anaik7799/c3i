# Zenoh Universal Integration Plan (ZUIP)

**Version**: 1.0.0 | **Date**: 2026-03-18 | **Status**: DESIGN COMPLETE
**Author**: Claude Opus 4.6 | **Sprint**: 50
**Compliance**: SC-ZTEST-001 to SC-ZTEST-020, SC-ZENOH-001 to SC-ZENOH-015
**Scope**: 7-Level Fractal Zenoh Integration across 87 functions, 134 topics, 66 gaps

---

## 0. Executive Summary

### Problem Statement

Audit of the Indrajaal SIL-6 Biomorphic Mesh reveals that **~35% of state mutations** across both F# and Elixir codebases occur without Zenoh mesh-wide publication. The system uses Phoenix.PubSub (local cluster only) and printfn/Logger (single-node only) for events that MUST be mesh-visible per SC-ZENOH-001.

### Findings

| Category | Total Gaps | P0 Critical | P1 High | P2 Medium |
|----------|-----------|-------------|---------|-----------|
| **Control Plane** | 11 | 6 | 4 | 1 |
| **Management Plane** | 8 | 3 | 3 | 2 |
| **Data Plane** | 47 | 5 | 20 | 22 |
| **Test Coverage** | 11 files | 7 | 2 | 2 |
| **TOTAL** | **77** | **21** | **29** | **27** |

### Constraints

- **Performance**: Hot path (>100 mutations/sec) MUST NOT add Zenoh sync publish
- **Safety**: Emergency operations MUST publish synchronously (<50ms)
- **Fallback**: SC-ZTEST-008 dual-write MUST be maintained for all new publish points
- **Budget**: Total throughput degradation MUST stay below 5%

---

## 1. Seven-Level Fractal Gap Analysis

### 1.1 L0 (Runtime) - Zenoh NIF & Session Management

**Status**: COMPLETE - No gaps found

| Component | File | Status |
|-----------|------|--------|
| Zenoh NIF (Rust) | `native/zenoh_nif/src/lib.rs` | Loaded via Rustler |
| Zenoh Elixir wrapper | `lib/indrajaal/native/zenoh.ex` | 331 lines, full API |
| Session management | `lib/indrajaal/observability/zenoh_session.ex` | GenServer with reconnect |

**Performance**: NIF boundary crossing ~0.1ms. No remediation needed.

---

### 1.2 L1 (Function) - Individual State-Mutating Functions

**Status**: CRITICAL - 47 functions mutate state without Zenoh

#### 1.2.1 Control Plane Functions (P0)

| Function | File | Current | Impact | Freq | Fix |
|----------|------|---------|--------|------|-----|
| `execute_command/3` | `master_control.ex:198` | Telemetry only | Guardian decisions invisible to mesh | <1/sec | Async publish |
| `emergency_stop/1` | `master_control.ex:258` | PubSub only | Emergency not mesh-wide | <1/min | **SYNC** publish |
| `broadcast_emergency/2` | `master_control.ex:594` | PubSub only | Federation nodes unaware | <1/min | **SYNC** publish |
| `emergencyStop` | `SafetyKernel.fs:629` | printfn | F# emergency invisible | <1/min | **SYNC** publish |
| `executeRollback` | `SafetyKernel.fs:656` | printfn | Rollback hidden from mesh | <1/min | **SYNC** publish |
| `quarantineAgent` | `SafetyKernel.fs:715` | printfn | Quarantine state hidden | <1/sec | Async publish |

#### 1.2.2 Management Plane Functions (P0-P1)

| Function | File | Current | Impact | Freq | Fix |
|----------|------|---------|--------|------|-----|
| `execute_boot/3` | `wave_executor.ex:268` | Telemetry | Boot phases invisible | 10 total | Async publish |
| `boot_container/3` | `wave_executor.ex:405` | Logger | Container lifecycle hidden | 14 total | Async publish |
| `execute_rollback/2` | `wave_executor.ex:442` | Telemetry | Rollback not coordinated | <1/min | **SYNC** publish |
| `capture/2` | `dying_gasp.ex:84` | Logger | Checkpoints not observable | <1/min | Async publish |

#### 1.2.3 Data Plane Functions (P1-P2)

| Function | File | Current | Impact | Freq | Fix |
|----------|------|---------|--------|------|-----|
| `record/4` | `smart_metrics.ex:238` | ETS + PubSub | Metrics local only | 200/sec | **SKIP** (batch) |
| `perform_sync/1` | `sentinel_bridge.ex:277` | GenServer state | Health local only | 1/30sec | Async publish |
| `broadcast_update/2` | `vital_signs.ex:545` | PubSub only | Vitals local only | 5/sec | Async publish |
| `recordViolation` | `PlanningEnforcer.fs:376` | printfn (TODO) | Violations invisible | <1/sec | Async publish |
| `saveTask` | `StandaloneChaya.fs:179` | SQLite only | Chaya task state hidden | <1/sec | Async publish |
| `saveOODACycle` | `StandaloneChaya.fs:244` | SQLite only | OODA state hidden | <1/sec | Async publish |

---

### 1.3 L2 (Component) - Module-Level State Management

**Status**: CRITICAL - 36 modules with GenServer/ETS mutations but no Zenoh

#### 1.3.1 Modules by Priority

**P0 (Control)**:
- `master_control.ex` - 5 handle_call/cast without Zenoh
- `SafetyKernel.fs` - 8 mutable state operations without Zenoh
- `PlanningEnforcer.fs` - 3 violation recording without Zenoh

**P1 (Coordination)**:
- `agent_manager.ex` - spawn/terminate/scale lifecycle invisible
- `cybernetic_controller.ex` - control corrections invisible
- `rolling_update.ex` - wave update state invisible
- `rollback_manager.ex` - emergency rollback decisions invisible
- `forensic_audit_trail.ex` - compliance events invisible (SC-REG-001)

**P2 (Observability)**:
- `smart_metrics.ex` - ETS metric inserts (HOT PATH - batch only)
- `vital_signs.ex` - component vitals PubSub only
- `sentinel_bridge.ex` - health sync GenServer only
- `watchdog_test.ex` - heartbeat/escalation GenServer only
- `token_revocation_cache.ex` - auth state invisible
- `Orchestration.fs` - 7 service/message bus operations

#### 1.3.2 ETS Operations Without Zenoh

| Table | Module | Mutations/sec | Action |
|-------|--------|--------------|--------|
| `:smart_metrics` | smart_metrics.ex | 200 | **BATCH** (1 publish/5sec) |
| `:pattern_db` | pattern_hunter.ex | 50-150 | **SKIP** |
| `:vital_signs` | vital_signs.ex | 5-10 | Async publish |
| `:token_cache` | token_revocation_cache.ex | <5 | Async publish |
| `:mcp_rate_limit` | mcp/foundation/auth.ex | 5-20 | Async publish |

---

### 1.4 L3 (Holon) - Agent/Holon State Sovereignty

**Status**: HIGH GAPS - Prajna cockpit partially integrated, F# Planning mostly done

#### 1.4.1 Prajna Cockpit Modules

| Module | File | PubSub | Zenoh | Gap |
|--------|------|--------|-------|-----|
| MasterControl | master_control.ex | 1 broadcast | Partial (health only) | Command/emergency |
| GuardianIntegration | guardian_integration.ex | 0 | 0 | **COMPLETE GAP** |
| SentinelBridge | sentinel_bridge.ex | 0 | 0 | **COMPLETE GAP** |
| SmartMetrics | smart_metrics.ex | 1 broadcast | 0 | **COMPLETE GAP** |
| AiCopilot | ai_copilot.ex | 1 broadcast | 0 | Recommendations |
| VitalSigns | vital_signs.ex | 2 broadcasts | 0 | **COMPLETE GAP** |
| Watchdog | watchdog.ex | 0 | 0 | **COMPLETE GAP** |
| ImmutableState | immutable_state.ex | 0 | 0 | **COMPLETE GAP** |
| DualChannel | dual_channel.ex | 0 | 0 | **COMPLETE GAP** |
| Messaging | messaging.ex | 1 broadcast | Subscribes only | No re-publish |

#### 1.4.2 F# Planning Modules (Post Sprint 49 fix)

| Module | File | Zenoh | Gap |
|--------|------|-------|-----|
| ZenohAdapter | ZenohAdapter.fs | Full dual-write | COMPLETE |
| Manager | Manager.fs | Via ZenohAdapter | COMPLETE |
| ChayaCLI | ChayaCLI.fs | Via ZenohAdapter | COMPLETE |
| Repository | Repository.fs | None (called via Manager) | Cold-start import |
| PlanningEnforcer | PlanningEnforcer.fs | TODO at line 378 | Violation telemetry |
| SafetyKernel | SafetyKernel.fs | None | Emergency + quarantine |
| Orchestration | Orchestration.fs | None | 7 service events |
| StandaloneChaya | StandaloneChaya.fs | None | SQLite mutations |

---

### 1.5 L4 (Container) - Container Lifecycle & Health

**Status**: CRITICAL - Container events almost entirely invisible

| Component | Current | Gap |
|-----------|---------|-----|
| Container birth (podman start) | wave_executor telemetry | No Zenoh checkpoint |
| Container health transition | Health check poll | No Zenoh event |
| Container death (podman stop) | dying_gasp Logger | No Zenoh checkpoint |
| Container resource usage | Prometheus metrics | No Zenoh stream |
| Container network state | None | No Zenoh topic |

**Missing Zenoh Topics** (SC-ZENOH-010 to SC-ZENOH-015):
```
indrajaal/container/{name}/birth
indrajaal/container/{name}/health_changed
indrajaal/container/{name}/death
indrajaal/container/{name}/metrics
indrajaal/container/{name}/dying_gasp
```

---

### 1.6 L5 (Node) - Node-Level Coordination

**Status**: HIGH - Phoenix.PubSub used exclusively, no Zenoh bridge

**Phoenix.PubSub Broadcast Points** (24 discovered):
- MasterControl: 1 (emergency only)
- SmartMetrics: 1 (metric updated)
- VitalSigns: 2 (component updates)
- AiCopilot: 1 (recommendations)
- ErrorPatternEngine: 1 (patterns detected)
- Sentinel: 1 (threats)
- ChangeTracker: 1 (realtime changes)
- Other modules: 16

**Gap**: None of these 24 PubSub broadcasts also publish to Zenoh. PubSub is Phoenix-cluster-scoped (Erlang distribution), while Zenoh reaches the full mesh including F# nodes, Cortex, and federation peers.

---

### 1.7 L6 (Cluster) - Consensus & Voting

**Status**: CRITICAL - Quorum decisions computed but not published

| Operation | Module | Published? |
|-----------|--------|-----------|
| 2oo3 voting result | quorum computation (Elixir) | NO |
| FPPS 5-method consensus | health validation | NO |
| Split-brain detection | HealthCoordinator.fs | NO |
| Cluster membership change | Erlang :net_kernel | NO |

**Missing Zenoh Topics**:
```
indrajaal/cluster/quorum/vote/{vote_id}
indrajaal/cluster/quorum/result/{vote_id}
indrajaal/cluster/consensus/state_vector
indrajaal/cluster/membership/{node_id}/{joined|left}
indrajaal/cluster/split_brain/detected
```

---

### 1.8 L7 (Federation) - Cross-Holon Communication

**Status**: HIGH - Partial integration exists in KMS federation

| Component | File | Zenoh Integration |
|-----------|------|-------------------|
| Federation Protocol | kms/federation/protocol.ex | Partial (some topics) |
| Replication | kms/federation/replication.ex | Partial |
| Version Vectors | kms/federation/version_vectors.ex | Partial |
| Holon Lifecycle | holon/ modules | Partial |

**Missing**:
```
indrajaal/federation/peer/{peer_id}/joined
indrajaal/federation/peer/{peer_id}/state_diverged
indrajaal/federation/replication/{peer_id}/complete
indrajaal/federation/attestation/{peer_id}/verified
```

---

## 2. Criticality-Based Prioritization

### 2.1 Criticality Tiers

```
TIER 0 (SURVIVAL): System cannot safely operate without these
  └─ Emergency stop, Apoptosis, Split-brain detection
     Impact: Uncoordinated emergency → cascading failure

TIER 1 (SAFETY): Safety decisions must be mesh-visible
  └─ Guardian veto, Rollback coordination, Quarantine
     Impact: Safety events invisible → repeated unsafe actions

TIER 2 (GOVERNANCE): Control decisions must be auditable
  └─ Command execution, Circuit breakers, 5-order effects
     Impact: Control blind spots → operational surprises

TIER 3 (OBSERVABILITY): System state must be observable
  └─ Health sync, Vital signs, Metrics, Container lifecycle
     Impact: Degraded monitoring → slower incident response

TIER 4 (COMPLETENESS): Full mesh integration for all state
  └─ Compliance, Auth, Coordination, Realtime changes
     Impact: Incomplete picture → missed correlations
```

### 2.2 Tier 0: Survival-Critical (Fix FIRST)

| ID | Gap | Module | Plane | Latency Req | Perf Impact |
|----|-----|--------|-------|-------------|-------------|
| T0-01 | Emergency stop not mesh-broadcast | master_control.ex | CONTROL | <50ms SYNC | <1ms cold path |
| T0-02 | Apoptosis phases not published | Apoptosis.fs | CONTROL | <100ms SYNC | <1ms cold path |
| T0-03 | F# emergency stop not published | SafetyKernel.fs | CONTROL | <50ms SYNC | <1ms cold path |
| T0-04 | Rollback not coordinated via Zenoh | wave_executor.ex | MGMT | <100ms SYNC | <1ms cold path |
| T0-05 | Split-brain detection not published | HealthCoordinator.fs | CONTROL | <50ms SYNC | <1ms cold path |

**Total Performance Impact**: ~0ms on steady-state (all cold path, <1/min frequency)

### 2.3 Tier 1: Safety-Critical

| ID | Gap | Module | Plane | Latency Req | Perf Impact |
|----|-----|--------|-------|-------------|-------------|
| T1-01 | Guardian decisions not published | master_control.ex | CONTROL | <50ms async | ~0ms (async) |
| T1-02 | Guardian veto not mesh-visible | guardian_integration.ex | CONTROL | <50ms async | ~0ms (async) |
| T1-03 | F# rollback not published | SafetyKernel.fs | CONTROL | <100ms async | ~0ms (async) |
| T1-04 | Quarantine state not published | SafetyKernel.fs | CONTROL | <100ms async | ~0ms (async) |
| T1-05 | Circuit breaker transitions hidden | master_control.ex | CONTROL | <50ms async | ~0ms (async) |
| T1-06 | ImmutableRegister block appends | immutable_state.ex | CONTROL | <100ms async | ~0ms (async) |

**Total Performance Impact**: ~0ms (all async, <1/sec frequency)

### 2.4 Tier 2: Governance

| ID | Gap | Module | Plane | Latency Req | Perf Impact |
|----|-----|--------|-------|-------------|-------------|
| T2-01 | Command execution results | master_control.ex | CONTROL | <100ms async | ~0ms |
| T2-02 | 5-order effects analysis | master_control.ex | CONTROL | <100ms async | ~0ms |
| T2-03 | Violation telemetry (TODO) | PlanningEnforcer.fs | CONTROL | <100ms async | ~0ms |
| T2-04 | Boot wave transitions | wave_executor.ex | MGMT | <100ms async | ~0ms |
| T2-05 | Container lifecycle events | wave_executor.ex | MGMT | <100ms async | ~0ms |
| T2-06 | Dying gasp checkpoints | dying_gasp.ex | MGMT | <100ms async | ~0ms |
| T2-07 | Rolling update state | rolling_update.ex | MGMT | <100ms async | ~0ms |

**Total Performance Impact**: ~0ms (all <10/min frequency)

### 2.5 Tier 3: Observability

| ID | Gap | Module | Plane | Latency Req | Perf Impact |
|----|-----|--------|-------|-------------|-------------|
| T3-01 | Health sync to Zenoh | sentinel_bridge.ex | DATA | <100ms async | ~0ms (1/30sec) |
| T3-02 | Vital signs to Zenoh | vital_signs.ex | DATA | <100ms async | <1% (5/sec async) |
| T3-03 | SmartMetrics **BATCH** | smart_metrics.ex | DATA | 5sec batch | <1% (1 pub/5sec) |
| T3-04 | Chaya SQLite mutations | StandaloneChaya.fs | DATA | <100ms async | ~0ms (<1/sec) |
| T3-05 | Watchdog heartbeat | watchdog.ex | DATA | <100ms async | <1% (10/sec async) |
| T3-06 | Quorum voting results | cluster modules | DATA | <100ms async | ~0ms (<1/sec) |

**Total Performance Impact**: <2% throughput on warm paths

### 2.6 Tier 4: Completeness

| ID | Gap | Module | Plane | Latency Req | Perf Impact |
|----|-----|--------|-------|-------------|-------------|
| T4-01 | Compliance audit events | forensic_audit_trail.ex | DATA | <200ms async | <1% |
| T4-02 | Auth token events | token_revocation_cache.ex | DATA | <200ms async | ~0ms |
| T4-03 | Agent lifecycle events | agent_manager.ex | DATA | <200ms async | ~0ms |
| T4-04 | Orchestration events | Orchestration.fs | DATA | <200ms async | ~0ms |
| T4-05 | Access control changes | access_control modules | DATA | <200ms async | ~0ms |
| T4-06 | DualChannel disagreement | dual_channel.ex | DATA | <100ms async | ~0ms |
| T4-07 | AiCopilot recommendations | ai_copilot.ex | DATA | <200ms async | ~0ms |
| T4-08 | PubSub→Zenoh bridge (24 broadcasts) | All PubSub modules | DATA | <200ms async | <2% |

**Total Performance Impact**: <3% throughput

---

## 3. Performance Impact Analysis

### 3.1 Current Zenoh Publish Cost Model

```
F# ZenohPublish.fs (Dual-Write):
  Step 1: eprintfn to stderr         ~0.3ms (log fallback)
  Step 2: printfn JSON to stdout      ~0.2ms (structured output)
  TOTAL:                              ~0.5ms per publish

Elixir ZenohBootPublisher (Task.start):
  Step 1: Task.start overhead         ~0μs (non-blocking)
  Step 2: Jason.encode!               ~0.2ms (JSON serialize)
  Step 3: Logger.info fallback        ~0.5ms (log line)
  Step 4: ZenohSession.publish        ~3-5ms (NIF + network)
  TOTAL ON CRITICAL PATH:             ~0μs (all async)
  TOTAL IN BACKGROUND:                ~4-6ms

Zenoh NIF Wire Publish (estimated):
  Elixir → Rustler NIF boundary       ~0.1ms
  Rust serialize                       ~0.2ms
  TCP to local Zenoh router            ~1.0ms
  Router routing                       ~1.0ms
  TOTAL:                               ~2-4ms (p50)
                                       ~8-10ms (p99)
```

### 3.2 Mutation Frequency Classification

```
HOT PATH (>100/sec) - DO NOT ADD SYNC ZENOH
├─ SmartMetrics.record           200/sec   0.1ms/op   BATCH ONLY
├─ PatternHunter baselines       50-150/sec           SKIP
└─ Real-time ETS inserts         100+/sec             SKIP

WARM PATH (1-100/sec) - ASYNC TASK.START OK
├─ Compliance audit              20-50/sec  +0ms critical path
├─ Health checks                 10/sec     +0ms critical path
├─ Heartbeat pulses              10/sec     +0ms critical path
├─ Vital signs updates           5-10/sec   +0ms critical path
├─ Container metrics             5/sec      +0ms critical path
└─ Logger events (candidate)     75/sec     +0ms critical path

COLD PATH (<1/sec) - SYNC PUBLISH OK
├─ Boot phase transitions        10 total   +3-5ms acceptable
├─ Emergency shutdown            <1/min     +3-5ms required
├─ Config changes                <1/min     +3-5ms acceptable
├─ Quarantine events             <1/sec     +3-5ms acceptable
└─ Guardian decisions            <1/sec     +3-5ms acceptable
```

### 3.3 Throughput Impact Projection

| Phase | Mutations Affected | Publish Strategy | Throughput Impact |
|-------|-------------------|------------------|-------------------|
| Tier 0 | 5 cold path | SYNC | **0.00%** (< 1/min) |
| Tier 1 | 6 cold path | Async Task.start | **0.00%** (<1/sec) |
| Tier 2 | 7 cold/warm | Async Task.start | **<0.5%** (<10/min) |
| Tier 3 | 6 warm path | Async + 1 batch | **<2.0%** (aggregated) |
| Tier 4 | 8 warm + bridge | Async + bridge | **<3.0%** (includes PubSub bridge) |
| **TOTAL** | **32 mutation points** | Mixed | **<5.0%** system-wide |

### 3.4 DO NOT ADD (Performance Protection)

These mutations MUST NOT get sync Zenoh publishing:

| Module | Reason | Alternative |
|--------|--------|-------------|
| `SmartMetrics.record/4` | 200/sec, 0.1ms baseline, Zenoh = 30x slower | Batch: 1 aggregate publish per 5 seconds |
| `PatternHunter baselines` | 50-150/sec, real-time collection | Skip entirely |
| `ETS hot inserts` | >100/sec various tables | Skip or batch |
| `Telemetry.execute` | 542 call sites | Batch via TelemetryBatcher GenServer |

---

## 4. Control & Management Plane Design (PRIORITY)

### 4.1 Control Plane Architecture

```
BEFORE (Current):
  MasterControl ──execute_command──► Guardian ──approved──► Action ──► Telemetry only
                                              └─vetoed───► Logger only

AFTER (Proposed):
  MasterControl ──execute_command──► Guardian ──approved──► Action ──► Telemetry
                                     │                       │         + Zenoh CP-CTRL-APPROVED
                                     │                       └──────► Zenoh CP-CTRL-EXECUTED
                                     └─vetoed──► Logger
                                                 + Zenoh CP-CTRL-VETOED
```

#### 4.1.1 Emergency Stop Path (T0-01, SYNC)

```
CURRENT:
  emergency_stop(reason)
    → Logger.critical(...)
    → Enum.each(@domains, broadcast_emergency)  # PubSub only
    → ImmutableRegister.append(...)
    → {:reply, :ok, %{status: :emergency_stopped}}

PROPOSED:
  emergency_stop(reason)
    → Logger.critical(...)
    → ZenohSession.publish_sync(                # SYNC - blocks until mesh sees it
        "indrajaal/control/emergency",
        %{reason: reason, timestamp: ..., node: node()})
    → Enum.each(@domains, broadcast_emergency)
    → ImmutableRegister.append(...)
    → {:reply, :ok, %{status: :emergency_stopped}}
```

**Design Decision**: SYNCHRONOUS publish. Emergency stop MUST be mesh-visible before returning.
Cost: +3-5ms on a <1/min operation. Acceptable.

#### 4.1.2 Guardian Decision Path (T1-01, T1-02, Async)

```
PROPOSED ADDITION to execute_command/3:
  case Guardian.propose(proposal) do
    {:approved, proof} ->
      Task.start(fn ->
        ZenohSession.publish("indrajaal/control/guardian/approved",
          %{proposal_id: id, domain: domain, action: action,
            proof: proof, timestamp: DateTime.utc_now()})
      end)
      result = execute_domain_action(...)
      ...

    {:vetoed, reason} ->
      Task.start(fn ->
        ZenohSession.publish("indrajaal/control/guardian/vetoed",
          %{proposal_id: id, domain: domain, action: action,
            reason: reason, timestamp: DateTime.utc_now()})
      end)
      {:reply, {:error, {:vetoed, reason}}, state}
  end
```

#### 4.1.3 Circuit Breaker Transitions (T1-05, Async)

```
PROPOSED: In update_circuit_breakers/2, when state transitions:
  defp update_circuit_breakers(breakers, health_scores) do
    Enum.reduce(health_scores, breakers, fn {domain, health}, acc ->
      current = Map.get(acc, domain, ...)
      new_state = compute_new_state(current, health)

      # NEW: Publish transition events
      if new_state.state != current.state do
        Task.start(fn ->
          ZenohSession.publish(
            "indrajaal/control/circuit_breaker/#{domain}",
            %{domain: domain,
              from: current.state, to: new_state.state,
              failures: new_state.failures,
              timestamp: DateTime.utc_now()})
        end)
      end

      Map.put(acc, domain, new_state)
    end)
  end
```

### 4.2 Management Plane Architecture

#### 4.2.1 Wave Executor Boot Phases (T2-04, Async)

```
PROPOSED ADDITIONS to wave_executor.ex:

  # At wave start:
  defp execute_wave(wave, config) do
    Task.start(fn ->
      ZenohSession.publish("indrajaal/deployment/wave/#{wave.id}/started",
        %{wave_id: wave.id, containers: wave.containers,
          timestamp: DateTime.utc_now()})
    end)
    ...
  end

  # At container boot:
  defp boot_container(container_id, wave, config) do
    case ContainerLifecycle.execute_startup(container_id) do
      {:ok, _state} ->
        Task.start(fn ->
          ZenohSession.publish(
            "indrajaal/deployment/container/#{container_id}/started",
            %{container_id: container_id, wave_id: wave.id,
              duration_ms: duration, timestamp: DateTime.utc_now()})
        end)
        ...

      {:error, reason} ->
        Task.start(fn ->
          ZenohSession.publish(
            "indrajaal/deployment/container/#{container_id}/failed",
            %{container_id: container_id, reason: inspect(reason),
              timestamp: DateTime.utc_now()})
        end)
        ...
    end
  end

  # At rollback (SYNC for safety):
  defp execute_rollback(started_containers, config) do
    ZenohSession.publish_sync(
      "indrajaal/deployment/rollback/initiated",
      %{containers: started_containers, timestamp: DateTime.utc_now()})
    ...
  end
```

#### 4.2.2 F# Apoptosis Phases (T0-02, SYNC for initiation)

```fsharp
// PROPOSED: In Apoptosis.fs, when apoptosis triggers:
member this.InitiateApoptosis(containerId: string, reason: string) =
    // SYNC publish - federation MUST know immediately
    Cepaf.Mesh.ZenohPublish.publish
        "CP-APOPTOSIS-INITIATED"
        "indrajaal/mesh/apoptosis/initiated"
        (sprintf "Apoptosis initiated for %s: %s" containerId reason)
        (sprintf """{"container":"%s","reason":"%s","timestamp":"%s"}"""
            containerId reason (DateTimeOffset.UtcNow.ToString("o")))

    // Continue with 6-phase protocol, async publish for each phase
    this.ExecutePhase(containerId, Phase.Notifying)
    ...
```

#### 4.2.3 F# SafetyKernel Emergency (T0-03, SYNC)

```fsharp
// PROPOSED: In SafetyKernel.fs
member this.EmergencyStop(reason: string) =
    // SYNC - survival-critical
    Cepaf.Mesh.ZenohPublish.publish
        "CP-SAFETY-EMERGENCY"
        "indrajaal/safety/emergency"
        (sprintf "EMERGENCY STOP: %s" reason)
        (sprintf """{"type":"EmergencyStop","reason":"%s","timestamp":"%s"}"""
            (reason.Replace("\"", "\\\""))
            (DateTimeOffset.UtcNow.ToString("o")))

    // Existing emergency logic...
    printfn "[SafetyKernel] EMERGENCY..."
```

---

## 5. Data Plane Design

### 5.1 Async Publish Pattern (Standard)

All warm/cold data plane mutations use this pattern:

```elixir
# Elixir: Non-blocking async publish
defp publish_zenoh_async(topic, payload) do
  Task.start(fn ->
    try do
      json = Jason.encode!(payload)
      # SC-ZTEST-008: Log fallback FIRST
      Logger.info("[ZTEST-CHECKPOINT] topic=#{topic} payload=#{json}")
      # Then attempt Zenoh
      ZenohSession.publish(topic, json)
    rescue
      e -> Logger.debug("[Zenoh] Publish failed: #{inspect(e)}")
    end
  end)
end
```

```fsharp
// F#: Already uses ZenohPublish dual-write
let publishAsync (event: SomeEvent) : unit =
    let checkpointId = toCheckpointId event
    let topic = toTopic event
    let message = toMessage event
    let json = toJson event
    Cepaf.Mesh.ZenohPublish.publish checkpointId topic message json
```

### 5.2 Batch Pattern (Hot Path Protection)

For SmartMetrics and other high-frequency mutations:

```elixir
# TelemetryBatcher GenServer
defmodule Indrajaal.Observability.TelemetryBatcher do
  use GenServer

  @flush_interval_ms 5_000
  @max_buffer_size 100

  def init(_) do
    schedule_flush()
    {:ok, %{buffer: [], count: 0}}
  end

  def handle_cast({:record, event}, state) do
    new_state = %{state | buffer: [event | state.buffer], count: state.count + 1}
    if new_state.count >= @max_buffer_size do
      flush(new_state)
    else
      {:noreply, new_state}
    end
  end

  def handle_info(:flush, state) do
    flush(state)
  end

  defp flush(state) do
    if state.count > 0 do
      Task.start(fn ->
        batch = %{
          timestamp: DateTime.utc_now(),
          event_count: state.count,
          metrics: Enum.reverse(state.buffer)
        }
        ZenohSession.publish("indrajaal/telemetry/batch", Jason.encode!(batch))
      end)
    end
    schedule_flush()
    {:noreply, %{state | buffer: [], count: 0}}
  end

  defp schedule_flush, do: Process.send_after(self(), :flush, @flush_interval_ms)
end
```

### 5.3 PubSub-to-Zenoh Bridge Pattern (L5 Fix)

For the 24 Phoenix.PubSub broadcasts that should also reach Zenoh:

```elixir
# Bridge module subscribes to PubSub topics and forwards to Zenoh
defmodule Indrajaal.Observability.PubSubZenohBridge do
  use GenServer

  @pubsub_topics [
    {"prajna:metrics", "indrajaal/prajna/metrics"},
    {"vital_signs:all", "indrajaal/prajna/vitals"},
    {"domain:*", "indrajaal/control/domain"},
    {"prajna:sentinel", "indrajaal/sentinel/events"}
  ]

  def init(_) do
    for {topic, _} <- @pubsub_topics do
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, topic)
    end
    {:ok, %{forwarded: 0}}
  end

  def handle_info(msg, state) do
    Task.start(fn ->
      {zenoh_topic, payload} = translate_message(msg)
      ZenohSession.publish(zenoh_topic, Jason.encode!(payload))
    end)
    {:noreply, %{state | forwarded: state.forwarded + 1}}
  end
end
```

---

## 6. Zenoh Topic Registry

### 6.1 New Topics Required (134 total, organized by plane)

#### Control Plane Topics (18)
```
indrajaal/control/emergency                    # T0-01 Emergency stop
indrajaal/control/guardian/approved             # T1-01 Guardian approval
indrajaal/control/guardian/vetoed               # T1-02 Guardian veto
indrajaal/control/command/{domain}/{action}     # T2-01 Command execution
indrajaal/control/effects/{domain}              # T2-02 5-order effects
indrajaal/control/circuit_breaker/{domain}      # T1-05 Circuit breaker
indrajaal/safety/emergency                      # T0-03 F# emergency
indrajaal/safety/rollback                       # T1-03 F# rollback
indrajaal/safety/quarantine/{agent_id}          # T1-04 Quarantine
indrajaal/safety/monitoring                     # T2-03 Safety monitoring
indrajaal/mesh/apoptosis/initiated              # T0-02 Apoptosis
indrajaal/mesh/apoptosis/phase/{phase}          # T0-02 Apoptosis phases
indrajaal/mesh/split_brain/detected             # T0-05 Split-brain
indrajaal/register/block/{holon_id}             # T1-06 Register block
indrajaal/planning/enforcement                  # T2-03 Violations
indrajaal/cluster/quorum/result/{vote_id}       # T3-06 Quorum
indrajaal/cluster/consensus/state_vector        # T3-06 Consensus
indrajaal/cluster/membership/{node_id}          # L6 Membership
```

#### Management Plane Topics (12)
```
indrajaal/deployment/wave/{wave_id}/started     # T2-04 Wave start
indrajaal/deployment/wave/{wave_id}/completed   # T2-04 Wave complete
indrajaal/deployment/container/{id}/started     # T2-05 Container birth
indrajaal/deployment/container/{id}/failed      # T2-05 Container failure
indrajaal/deployment/container/{id}/dying_gasp  # T2-06 Dying gasp
indrajaal/deployment/rollback/initiated         # T0-04 Rollback
indrajaal/deployment/rollback/completed         # T0-04 Rollback done
indrajaal/deployment/update/{id}/started        # T2-07 Rolling update
indrajaal/deployment/update/{id}/completed      # T2-07 Update done
indrajaal/deployment/update/{id}/paused         # T2-07 Update paused
indrajaal/deployment/checkpoint/created         # T2-06 Checkpoint
indrajaal/deployment/checkpoint/verified        # T2-06 Checkpoint ok
```

#### Data Plane Topics (14 new, excludes existing)
```
indrajaal/sentinel/health                       # T3-01 Health sync
indrajaal/sentinel/threats                      # T3-01 Threats
indrajaal/sentinel/advisories                   # T3-01 Advisories
indrajaal/prajna/vitals/{component_id}          # T3-02 Vital signs
indrajaal/telemetry/batch                       # T3-03 SmartMetrics batch
indrajaal/chaya/tasks/{task_id}                 # T3-04 Chaya mutation
indrajaal/chaya/ooda/{cycle_id}                 # T3-04 OODA cycle
indrajaal/watchdog/heartbeat                    # T3-05 Watchdog
indrajaal/compliance/forensic/{id}              # T4-01 Audit trail
indrajaal/auth/token_revoked/{jti}              # T4-02 Token events
indrajaal/coordination/agent/{id}/lifecycle     # T4-03 Agent lifecycle
indrajaal/orchestration/services                # T4-04 Service registry
indrajaal/orchestration/ooda                    # T4-04 OODA actions
indrajaal/prajna/copilot/recommendations        # T4-07 AI recommendations
```

### 6.2 Topic Depth Compliance (SC-ZTEST-017: depth <= 6)

All proposed topics verified: maximum depth = 5 levels. COMPLIANT.

### 6.3 Checkpoint ID Registry (SC-ZTEST-001: unique, SC-ZTEST-013: CP-{DOMAIN}-{NN})

```
CP-CTRL-01    Command executed
CP-CTRL-02    Command vetoed
CP-CTRL-03    Emergency stop
CP-CTRL-04    Circuit breaker opened
CP-CTRL-05    Circuit breaker closed
CP-SAFETY-01  F# emergency stop
CP-SAFETY-02  F# rollback executed
CP-SAFETY-03  Agent quarantined
CP-SAFETY-04  Split-brain detected
CP-DEPLOY-01  Wave started
CP-DEPLOY-02  Wave completed
CP-DEPLOY-03  Container started
CP-DEPLOY-04  Container failed
CP-DEPLOY-05  Rollback initiated
CP-DEPLOY-06  Dying gasp captured
CP-DEPLOY-07  Checkpoint created
CP-APOPTOSIS-01  Apoptosis initiated
CP-APOPTOSIS-02  Apoptosis phase transition
CP-APOPTOSIS-03  Apoptosis complete
CP-ENFORCE-01 Violation recorded
CP-GUARD-01   Proposal approved
CP-GUARD-02   Proposal vetoed
```

---

## 7. Test Coverage Plan

### 7.1 Tests Required per Tier

| Tier | Test Type | Count | Pattern |
|------|-----------|-------|---------|
| T0 | Sync publish verification | 5 | Assert Zenoh message arrives within 100ms |
| T1 | Async publish verification | 6 | Assert Zenoh message arrives within 1000ms |
| T2 | Async publish verification | 7 | Assert Zenoh message arrives within 2000ms |
| T3 | Batch publish verification | 6 | Assert aggregated message within 10000ms |
| T4 | Async publish verification | 8 | Assert Zenoh message arrives within 2000ms |

### 7.2 Test Pattern (Elixir)

```elixir
describe "emergency stop publishes to Zenoh (T0-01)" do
  setup do
    # Subscribe to Zenoh topic before triggering
    :ok = ZenohSession.subscribe("indrajaal/control/emergency", self())
    :ok
  end

  test "publishes synchronously within 100ms" do
    MasterControl.emergency_stop("test_reason")

    assert_receive {:zenoh_message,
      "indrajaal/control/emergency",
      payload}, 100

    decoded = Jason.decode!(payload)
    assert decoded["reason"] == "test_reason"
    assert decoded["timestamp"]  # ISO 8601
  end
end
```

### 7.3 Test Pattern (F# - Expecto)

```fsharp
testCase "Emergency stop publishes to Zenoh (T0-03)" <| fun () ->
    // Capture stderr output for dual-write verification
    let output = System.Text.StringBuilder()
    let originalErr = Console.Error
    use writer = new System.IO.StringWriter(output)
    Console.SetError(writer)

    SafetyKernel.emergencyStop "test_reason"

    Console.SetError(originalErr)
    let errOutput = output.ToString()

    // Verify SC-ZTEST-008 log fallback
    Expect.isTrue
        (errOutput.Contains("[ZTEST-CHECKPOINT]"))
        "Must write log fallback first"
    Expect.isTrue
        (errOutput.Contains("CP-SAFETY-EMERGENCY"))
        "Must include checkpoint ID"
```

### 7.4 Existing Test Files Requiring Zenoh Assertions

| Test File | Current Tests | Add Zenoh Assertions |
|-----------|--------------|---------------------|
| sentinel_bridge_test.exs | Health sync, threats | Verify Zenoh publish on sync |
| smart_metrics_test.exs | ETS record/get | Verify batch publish every 5sec |
| watchdog_test.exs | Heartbeat, escalation | Verify Zenoh heartbeat topic |
| immutable_state_test.exs | Block append, chain | Verify Zenoh block event |
| dual_channel_test.exs | Agreement, divergence | Verify Zenoh disagreement alert |
| mesh_digital_twin_test.exs | Twin state model | Verify state change publishes |
| mesh_quorum_fpps_test.exs | 2oo3 voting | Verify quorum result publishes |
| mesh_safety_services_test.exs | Guardian, Sentinel | Verify threat publishes |
| sprint_task_orchestrator_test.exs | Sprint checkpoints | Verify actual Zenoh messages |
| PlanningSyncTests.fs | 81 tests (adapter done) | Add sync flow Zenoh tests |
| mesh_topology_boot_test.exs | Boot DAG | Verify boot checkpoint publishes |

---

## 8. Implementation Phases

### Phase 1: Survival (Tier 0) — Week 1

**Scope**: 5 functions, 5 SYNC publish points, 5 tests
**Performance Impact**: 0.00% (all cold path, <1/min)
**Files Modified**: 4

| Task | File | Change | Test |
|------|------|--------|------|
| T0-01 | master_control.ex | Add SYNC Zenoh in emergency_stop | sync_publish_test |
| T0-02 | Apoptosis.fs | Add SYNC Zenoh in InitiateApoptosis | apoptosis_zenoh_test |
| T0-03 | SafetyKernel.fs | Add SYNC Zenoh in emergencyStop | safety_zenoh_test |
| T0-04 | wave_executor.ex | Add SYNC Zenoh in execute_rollback | rollback_zenoh_test |
| T0-05 | HealthCoordinator.fs | Add SYNC Zenoh on split-brain | splitbrain_zenoh_test |

### Phase 2: Safety (Tier 1) — Week 2

**Scope**: 6 functions, 6 async publish points, 6 tests
**Performance Impact**: 0.00% (all <1/sec)
**Files Modified**: 4

| Task | File | Change |
|------|------|--------|
| T1-01 | master_control.ex | Async Zenoh after Guardian.propose (approved path) |
| T1-02 | guardian_integration.ex | Async Zenoh after validate_proposal |
| T1-03 | SafetyKernel.fs | Async Zenoh in executeRollback |
| T1-04 | SafetyKernel.fs | Async Zenoh in quarantineAgent |
| T1-05 | master_control.ex | Async Zenoh on circuit breaker transition |
| T1-06 | immutable_state.ex | Async Zenoh after block append |

### Phase 3: Governance (Tier 2) — Week 3

**Scope**: 7 functions, 7 async publish points, 7 tests
**Performance Impact**: <0.5%
**Files Modified**: 5

| Task | File | Change |
|------|------|--------|
| T2-01 | master_control.ex | Async Zenoh for command execution result |
| T2-02 | master_control.ex | Async Zenoh for 5-order effects |
| T2-03 | PlanningEnforcer.fs | Replace TODO with real ZenohPublish |
| T2-04 | wave_executor.ex | Async Zenoh for wave start/complete |
| T2-05 | wave_executor.ex | Async Zenoh for container lifecycle |
| T2-06 | dying_gasp.ex | Async Zenoh for checkpoint events |
| T2-07 | rolling_update.ex | Async Zenoh for update state |

### Phase 4: Observability (Tier 3) — Week 4

**Scope**: 6 modules, mixed async+batch, 6 tests
**Performance Impact**: <2.0%
**Files Modified**: 7

| Task | File | Change |
|------|------|--------|
| T3-01 | sentinel_bridge.ex | Async Zenoh after perform_sync |
| T3-02 | vital_signs.ex | Async Zenoh alongside PubSub |
| T3-03 | smart_metrics.ex + TelemetryBatcher (new) | Batch publish every 5sec |
| T3-04 | StandaloneChaya.fs | Async Zenoh after SQLite mutations |
| T3-05 | watchdog.ex | Async Zenoh for heartbeat |
| T3-06 | Cluster quorum modules | Async Zenoh for voting results |

### Phase 5: Completeness (Tier 4) — Sprint 51+

**Scope**: 8 modules + PubSub bridge, async, 8 tests
**Performance Impact**: <3.0%
**Files Modified**: 9 + 1 new (PubSubZenohBridge)

| Task | File | Change |
|------|------|--------|
| T4-01 | forensic_audit_trail.ex | Async Zenoh for compliance events |
| T4-02 | token_revocation_cache.ex | Async Zenoh for auth events |
| T4-03 | agent_manager.ex | Async Zenoh for lifecycle events |
| T4-04 | Orchestration.fs | Async Zenoh via ZenohPublish |
| T4-05 | access_control modules | Async Zenoh for permission changes |
| T4-06 | dual_channel.ex | Async Zenoh for disagreement alerts |
| T4-07 | ai_copilot.ex | Async Zenoh for recommendations |
| T4-08 | PubSubZenohBridge (NEW) | Bridge 24 PubSub topics to Zenoh |

---

## 9. Backpressure & Circuit Breaker Design

### 9.1 Zenoh Circuit Breaker

```
State Machine:
  CLOSED ──(3 consecutive failures)──► OPEN
  OPEN ──(30 sec timeout)──► HALF_OPEN
  HALF_OPEN ──(1 success)──► CLOSED
  HALF_OPEN ──(1 failure)──► OPEN

In OPEN state:
  All publish calls → SC-ZTEST-008 log fallback only
  No Zenoh NIF calls attempted
  Telemetry counter incremented for dashboard visibility
```

### 9.2 Publish Timeout Budget

| Publish Type | Timeout | Fallback |
|--------------|---------|----------|
| SYNC (emergency) | 50ms | Log + proceed (safety first) |
| Async (warm path) | 10ms per Task | Task dies, log fallback |
| Batch (hot path) | 100ms per flush | Skip flush, buffer continues |

---

## 10. FMEA Risk Analysis

| ID | Failure Mode | S | O | D | RPN | Mitigation |
|----|-------------|---|---|---|-----|------------|
| FM-01 | Emergency stop unheard by federation | 9 | 2 | 3 | 54 | T0-01: SYNC publish |
| FM-02 | Apoptosis uncoordinated | 9 | 1 | 2 | 18 | T0-02: SYNC publish |
| FM-03 | Guardian veto invisible | 7 | 3 | 4 | 84 | T1-01: Async publish |
| FM-04 | Circuit breaker cascade silent | 6 | 3 | 4 | 72 | T1-05: Transition publish |
| FM-05 | Wave executor invisible to federation | 6 | 4 | 2 | 48 | T2-04: Wave publish |
| FM-06 | SmartMetrics Zenoh sync kills perf | 9 | 4 | 2 | 72 | BATCH: 1 pub/5sec |
| FM-07 | Zenoh router down during emergency | 8 | 2 | 9 | 144 | SC-ZTEST-008 log fallback |
| FM-08 | Task queue saturation | 6 | 2 | 5 | 60 | Task pool limit + monitor |
| FM-09 | Network partition (no Zenoh) | 6 | 2 | 9 | 108 | Log fallback + degrade |
| FM-10 | Split-brain undetected | 9 | 1 | 3 | 27 | T0-05: SYNC publish |

**Highest RPN**: FM-07 (Zenoh down during emergency) = 144
**Mitigation**: SC-ZTEST-008 dual-write ensures log fallback always works.
Emergency stop also uses Phoenix.PubSub (Erlang distribution) as secondary channel.

---

## 11. Success Criteria

### 11.1 Per-Phase Gates

| Phase | Gate | Metric |
|-------|------|--------|
| Phase 1 | All T0 publish points verified | 5/5 SYNC publishes work |
| Phase 2 | All T1 publish points verified | 6/6 async publishes work |
| Phase 3 | All T2 publish points verified | 7/7 async publishes work |
| Phase 4 | Batch publish operational | SmartMetrics batch 1/5sec |
| Phase 5 | PubSub bridge operational | 24 topics bridged |

### 11.2 Overall Metrics

| Metric | Before | After | Target |
|--------|--------|-------|--------|
| State mutations with Zenoh | ~65% | ~98% | >95% |
| Control plane Zenoh coverage | ~10% | 100% | 100% |
| Management plane Zenoh coverage | ~5% | 100% | 100% |
| Data plane Zenoh coverage | ~70% | ~95% | >90% |
| Throughput degradation | 0% | <5% | <5% |
| Emergency stop mesh latency | N/A (not published) | <50ms | <100ms |
| Test files with Zenoh assertions | 0/11 | 11/11 | 100% |

---

## 12. Dependencies & Risks

### 12.1 Dependencies

- ZenohSession GenServer must be started before any publish calls
- Zenoh NIF must be loaded (SKIP_ZENOH_NIF=0)
- Circuit breaker module may need to be created (Phase 1 prerequisite)
- TelemetryBatcher GenServer (new module, Phase 4)
- PubSubZenohBridge GenServer (new module, Phase 5)

### 12.2 Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Zenoh router not running during tests | HIGH | Tests fail | Use SC-ZTEST-008 log fallback in tests |
| Task queue overwhelmed on startup | LOW | Delayed publishes | Startup sequence already serialized |
| F# ZenohPublish I/O blocked | LOW | F# publish hangs | stderr/stdout are non-blocking |
| Breaking existing test expectations | MEDIUM | CI failure | Add Zenoh assertions incrementally |

---

## 13. Related Documents

- `CLAUDE.md` Section 5.0: Unified Safety Constraints (STAMP/SC)
- `.claude/rules/zenoh-telemetry-mandatory.md`: SC-ZENOH-001 to SC-ZENOH-015
- `.claude/rules/zenoh-test-messaging.md`: SC-ZTEST-001 to SC-ZTEST-020
- `.claude/rules/fsharp-sil6-mesh.md`: Mesh orchestration rules
- `docs/architecture/ZENOH_TEST_MESSAGING_COMPREHENSIVE.md`: 7x7 architecture spec
- `lib/cepaf/src/Cepaf/Mesh/ZenohPublish.fs`: F# dual-write implementation
- `lib/indrajaal/boot/zenoh_boot_publisher.ex`: Elixir boot publisher

---

## 14. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-03-18 | Claude Opus 4.6 | Initial comprehensive plan from 7-level audit |
