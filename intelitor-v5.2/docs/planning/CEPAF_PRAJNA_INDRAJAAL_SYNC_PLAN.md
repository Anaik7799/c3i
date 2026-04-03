# CEPAF-Prajna-Indrajaal Full System Sync Plan

**Version**: 21.1.0 | **Date**: 2026-01-02 | **Status**: PLANNING
**Framework**: SOPv5.11 + STAMP + Constitutional AI

---

## Executive Summary

This document defines the complete synchronization plan between:
- **CEPAF** (F# TUI Cockpit) - 63,000+ LOC, 27 Cockpit modules
- **Prajna** (Elixir Backend Cockpit) - 35+ modules, 836 tests
- **Indrajaal Core** - Safety, Constitution, Observability, Distributed Mesh

**Goal**: Achieve 100% bidirectional sync with zero data loss, <50ms latency, and full Constitutional compliance.

---

## 1. Current State Analysis

### 1.1 CEPAF Capabilities (F#)

| Component | Modules | Status | Sync Gap |
|-----------|---------|--------|----------|
| **Cockpit Core** | 27 | Active | Partial HTTP bridge |
| **Observability** | 20 | Active | Zenoh connected |
| **Core Patterns** | 24 | Active | N/A (internal) |
| **Podman Integration** | 14 | Active | Container events missing |
| **Knowledge Base** | 4 | Active | DuckDB not synced |

**Key CEPAF Modules**:
- `GuardianIntegration.fs` - HTTP bridge to Elixir Guardian
- `SentinelBridge.fs` - Health sync (30s interval)
- `ElixirBridge.fs` - Circuit breaker, retry, auth
- `ImmutableState.fs` - Local Ed25519 signing
- `ZenohSession.fs` - Real-time pub/sub
- `Prajna.fs` - Bio-inspired TUI

### 1.2 Prajna Capabilities (Elixir)

| Component | Modules | Status | Sync Gap |
|-----------|---------|--------|----------|
| **Core Infrastructure** | 12 | Active | CEPAF needs API |
| **Resilience** | 8 | Active | CEPAF needs callbacks |
| **Immune System** | 3 | Active | Partial Zenoh pub |
| **Biomorphic** | 4 | Active | No CEPAF visibility |
| **LiveView** | 13 | Active | CEPAF can't access |

**Key Prajna Modules**:
- `guardian_integration.ex` - Command pre-approval gate
- `sentinel_bridge.ex` - Immune system sync
- `immutable_state.ex` - Append-only register
- `prometheus_verifier.ex` - Proof tokens
- `config.ex` - Centralized configuration
- `ai_copilot.ex` - AI recommendations

### 1.3 Indrajaal Core Systems

| System | Location | CEPAF Access | Prajna Access |
|--------|----------|--------------|---------------|
| **Guardian** | `lib/indrajaal/safety/` | HTTP API | Direct |
| **Sentinel** | `lib/indrajaal/safety/` | HTTP + Zenoh | Direct |
| **Constitution** | `lib/indrajaal/core/constitution/` | HTTP API | Direct |
| **ImmutableRegister** | `lib/indrajaal/core/holon/` | HTTP API | Direct |
| **FounderDirective** | `lib/indrajaal/core/holon/` | HTTP API | Direct |
| **AgentMesh** | `lib/indrajaal/distributed/` | Zenoh only | Direct |
| **Zenoh Network** | `lib/indrajaal/observability/` | Direct | Direct |
| **Alarms** | `lib/indrajaal/alarms/` | HTTP + Zenoh | Direct |
| **Devices** | `lib/indrajaal/devices/` | HTTP + Zenoh | Direct |
| **AccessControl** | `lib/indrajaal/access_control/` | HTTP + Zenoh | Direct |

---

## 2. Sync Architecture

### 2.1 Communication Layers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CEPAF (F# TUI)                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Prajna.fs   │  │ElixirBridge │  │ZenohSession │  │ Knowledge   │        │
│  │ (TUI)       │  │ (HTTP)      │  │ (PubSub)    │  │ (DuckDB)    │        │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘        │
└─────────┼────────────────┼────────────────┼────────────────┼───────────────┘
          │                │                │                │
          │    ┌───────────┴────────────────┴───────────────┐│
          │    │        SYNC LAYER (THIS PLAN)              ││
          │    │  ┌─────────────────────────────────────┐   ││
          │    │  │ L1: HTTP REST API (Commands)        │   ││
          │    │  │ L2: Zenoh PubSub (Real-time)        │   ││
          │    │  │ L3: DuckDB Sync (History)           │   ││
          │    │  │ L4: Constitutional Verification     │   ││
          │    │  └─────────────────────────────────────┘   ││
          │    └────────────────────────────────────────────┘│
          │                │                │                │
┌─────────┼────────────────┼────────────────┼────────────────┼───────────────┐
│         │                │                │                │               │
│  ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐       │
│  │ Prajna      │  │ PrajnaAPI   │  │ Zenoh       │  │ DuckDB      │       │
│  │ Supervisor  │  │ Controller  │  │ Publishers  │  │ Knowledge   │       │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘       │
│         │                │                │                │               │
│         └────────────────┴────────────────┴────────────────┘               │
│                                    │                                        │
│                     PRAJNA ELIXIR COCKPIT                                  │
└────────────────────────────────────┼───────────────────────────────────────┘
                                     │
┌────────────────────────────────────┼───────────────────────────────────────┐
│                     INDRAJAAL CORE SYSTEMS                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │ Guardian    │  │ Sentinel    │  │ Constitution│  │ AgentMesh   │       │
│  │ (Safety)    │  │ (Immune)    │  │ (Invariants)│  │ (Distributed)│       │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
│                                                                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │ Alarms      │  │ Devices     │  │AccessControl│  │ Sites       │       │
│  │ Domain      │  │ Domain      │  │ Domain      │  │ Domain      │       │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
└────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Sync Protocols

| Layer | Protocol | Latency | Use Case |
|-------|----------|---------|----------|
| **L1 HTTP** | REST/JSON | <500ms | Commands, mutations |
| **L2 Zenoh** | PubSub | <50ms | Real-time telemetry |
| **L3 DuckDB** | SQL/Parquet | <1s | History, analytics |
| **L4 Constitutional** | Verification | <5ms | Invariant checks |

---

## 3. Gap Analysis

### 3.1 Critical Gaps (P0)

| Gap ID | Description | CEPAF | Prajna | Impact |
|--------|-------------|-------|--------|--------|
| **GAP-001** | Container events not published to Zenoh | Missing | N/A | No real-time container visibility |
| **GAP-002** | DuckDB knowledge not synced | Local only | Local only | Duplicate history stores |
| **GAP-003** | AgentMesh status not exposed | Zenoh only | Direct | CEPAF can't manage agents |
| **GAP-004** | Biomorphic layer hidden | N/A | Internal | CEPAF can't see holon health |
| **GAP-005** | LiveView data not accessible | N/A | LiveView only | No shared dashboard state |

### 3.2 High Priority Gaps (P1)

| Gap ID | Description | Impact |
|--------|-------------|--------|
| **GAP-006** | Alarm correlation not visible in CEPAF | Can't see storm detection |
| **GAP-007** | Device state changes not published | Missing sensor updates |
| **GAP-008** | Access control audit not synced | Incomplete audit trail |
| **GAP-009** | Sentinel threat taxonomy not exposed | Can't display threat types |
| **GAP-010** | Constitutional amendment history missing | Can't verify Ψ₀-Ψ₅ evolution |

### 3.3 Medium Priority Gaps (P2)

| Gap ID | Description |
|--------|-------------|
| **GAP-011** | OODA cycle metrics not visible |
| **GAP-012** | API rate limit status not shared |
| **GAP-013** | Fractal log levels not configurable from CEPAF |
| **GAP-014** | Theme preferences not synced |
| **GAP-015** | Feature flags not bidirectional |

---

## 4. Sync Implementation Plan

### 4.1 Phase 1: Core API Expansion (Sprint 32)

#### 4.1.1 New PrajnaController Endpoints

```elixir
# lib/indrajaal_web/controllers/api/prajna_controller.ex

# Container Operations (GAP-001)
get "/containers/status"      # All container health
get "/containers/:id/logs"    # Container logs stream
post "/containers/:id/action" # Start/stop/restart

# Agent Mesh (GAP-003)
get "/mesh/agents"            # All agent status
get "/mesh/agents/:id"        # Specific agent
post "/mesh/agents/:id/command" # Send command

# Biomorphic Layer (GAP-004)
get "/bio/holons"             # All holon status
get "/bio/holons/:id/vitals"  # Vital signs
get "/bio/membrane/:id"       # Membrane status

# Domain Data (GAP-006, GAP-007, GAP-008)
get "/alarms/correlation"     # Storm detection status
get "/devices/state"          # All device states
get "/access/audit"           # Audit log stream
```

**STAMP Constraints**:
- SC-SYNC-011: Container endpoints require Guardian approval
- SC-SYNC-012: Agent commands logged to ImmutableRegister
- SC-SYNC-013: Biomorphic data read-only (no external mutations)

#### 4.1.2 New Zenoh Publishers

```elixir
# lib/indrajaal/observability/zenoh_publishers/

# Container events publisher
defmodule Indrajaal.Observability.ZenohContainerPublisher do
  # Publishes to: indrajaal/containers/**
  # Events: started, stopped, health_changed, resource_alert
end

# Agent mesh publisher
defmodule Indrajaal.Observability.ZenohAgentMeshPublisher do
  # Publishes to: indrajaal/mesh/**
  # Events: agent_spawned, agent_died, command_executed
end

# Biomorphic publisher
defmodule Indrajaal.Observability.ZenohBiomorphicPublisher do
  # Publishes to: indrajaal/bio/**
  # Events: holon_health, membrane_breach, vital_change
end

# Domain publishers
defmodule Indrajaal.Observability.ZenohAlarmCorrelationPublisher do
  # Publishes to: indrajaal/alarms/correlation/**
end

defmodule Indrajaal.Observability.ZenohDeviceStatePublisher do
  # Publishes to: indrajaal/devices/state/**
end

defmodule Indrajaal.Observability.ZenohAccessAuditPublisher do
  # Publishes to: indrajaal/access/audit/**
end
```

### 4.2 Phase 2: CEPAF Integration (Sprint 32-33)

#### 4.2.1 New CEPAF Subscribers

```fsharp
// lib/cepaf/src/Cepaf/Zenoh/

// Container subscriber
module ContainerSubscriber =
    let subscribe session =
        ZenohChannel.subscribe session "indrajaal/containers/**"
        |> AsyncSeq.map ContainerEvent.parse

// Agent mesh subscriber
module AgentMeshSubscriber =
    let subscribe session =
        ZenohChannel.subscribe session "indrajaal/mesh/**"
        |> AsyncSeq.map AgentEvent.parse

// Biomorphic subscriber
module BiomorphicSubscriber =
    let subscribe session =
        ZenohChannel.subscribe session "indrajaal/bio/**"
        |> AsyncSeq.map BioEvent.parse
```

#### 4.2.2 New CEPAF Cockpit Panels

```fsharp
// lib/cepaf/src/Cepaf/Cockpit/

// Container dashboard
module ContainerDashboard =
    type State = { containers: Container list; lastUpdate: DateTime }
    let render state = // Real-time container grid

// Agent mesh dashboard
module AgentMeshDashboard =
    type State = { agents: Agent list; topology: Graph }
    let render state = // Force-directed graph visualization

// Biomorphic dashboard
module BiomorphicDashboard =
    type State = { holons: Holon list; membrane: MembraneStatus }
    let render state = // Organism-style health view

// Domain dashboards
module AlarmCorrelationDashboard = ...
module DeviceStateDashboard = ...
module AccessAuditDashboard = ...
```

### 4.3 Phase 3: DuckDB Sync (Sprint 33)

#### 4.3.1 Shared DuckDB Schema

```sql
-- Shared tables synced between CEPAF and Prajna

-- Evolution history (append-only)
CREATE TABLE IF NOT EXISTS evolution_history (
    id UUID PRIMARY KEY,
    holon_id UUID NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    payload JSON NOT NULL,
    hash_prev VARCHAR(64) NOT NULL,
    hash_current VARCHAR(64) NOT NULL,
    signature VARCHAR(128) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    synced_at TIMESTAMP
);

-- Agent activity log
CREATE TABLE IF NOT EXISTS agent_activity (
    id UUID PRIMARY KEY,
    agent_fqun VARCHAR(255) NOT NULL,
    action VARCHAR(50) NOT NULL,
    params JSON,
    result JSON,
    duration_ms INTEGER,
    created_at TIMESTAMP NOT NULL
);

-- Alarm correlation state
CREATE TABLE IF NOT EXISTS alarm_correlation (
    id UUID PRIMARY KEY,
    correlation_id UUID NOT NULL,
    alarm_ids UUID[] NOT NULL,
    pattern_type VARCHAR(50),
    confidence FLOAT,
    created_at TIMESTAMP NOT NULL
);
```

#### 4.3.2 Sync Protocol

```elixir
# lib/indrajaal/knowledge/duckdb_sync.ex

defmodule Indrajaal.Knowledge.DuckDBSync do
  @sync_interval :timer.seconds(60)

  def sync_to_cepaf do
    # 1. Query new records since last sync
    # 2. Serialize to Parquet
    # 3. Publish via Zenoh: indrajaal/sync/duckdb
    # 4. Update sync cursor
  end

  def receive_from_cepaf(parquet_data) do
    # 1. Validate schema
    # 2. Verify signatures
    # 3. Merge into local DuckDB
    # 4. Publish confirmation
  end
end
```

### 4.4 Phase 4: Constitutional Verification (Sprint 34)

#### 4.4.1 Cross-System Verification

```elixir
# lib/indrajaal/core/constitution/cross_verifier.ex

defmodule Indrajaal.Core.Constitution.CrossVerifier do
  @doc """
  Verifies constitutional state is consistent across CEPAF and Prajna.
  """

  def verify_sync do
    with {:ok, prajna_hash} <- get_prajna_constitution_hash(),
         {:ok, cepaf_hash} <- get_cepaf_constitution_hash(),
         true <- prajna_hash == cepaf_hash do
      :ok
    else
      {:mismatch, prajna, cepaf} ->
        Logger.error("Constitutional mismatch detected!")
        trigger_reconciliation(prajna, cepaf)
    end
  end
end
```

#### 4.4.2 Amendment Propagation

```elixir
# When Ψ₀-Ψ₅ are checked/verified, propagate to CEPAF

defmodule Indrajaal.Core.Constitution.AmendmentPropagator do
  def propagate_to_cepaf(amendment) do
    # 1. Sign amendment with Guardian key
    # 2. Publish to Zenoh: indrajaal/constitutional/amendments
    # 3. Wait for CEPAF acknowledgment
    # 4. Log to ImmutableRegister
  end
end
```

---

## 5. New STAMP Constraints

### 5.1 Sync Constraints (SC-SYNC)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SYNC-011 | Container actions require Guardian approval | CRITICAL |
| SC-SYNC-012 | Agent commands logged to ImmutableRegister | HIGH |
| SC-SYNC-013 | Biomorphic data read-only from external | HIGH |
| SC-SYNC-014 | DuckDB sync interval max 60s | MEDIUM |
| SC-SYNC-015 | Constitutional sync verified every 30s | CRITICAL |
| SC-SYNC-016 | Zenoh message ordering preserved | HIGH |
| SC-SYNC-017 | Sync failures trigger circuit breaker | HIGH |
| SC-SYNC-018 | All sync events have HLC timestamps | MEDIUM |
| SC-SYNC-019 | Cross-holon attestation required for federation | HIGH |
| SC-SYNC-020 | Sync state persisted before shutdown | CRITICAL |

### 5.2 CEPAF Constraints (SC-CEPAF)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-CEPAF-001 | All mutations via Elixir backend | CRITICAL |
| SC-CEPAF-002 | Local state is cache, not authoritative | CRITICAL |
| SC-CEPAF-003 | Stale data marked after 5s | HIGH |
| SC-CEPAF-004 | Connection loss triggers degraded mode | HIGH |
| SC-CEPAF-005 | Reconnect with exponential backoff | MEDIUM |
| SC-CEPAF-006 | Theme changes synced to backend | LOW |
| SC-CEPAF-007 | Knowledge queries cached 60s | MEDIUM |
| SC-CEPAF-008 | F# exceptions logged to Elixir | HIGH |

---

## 6. New AOR Rules

### 6.1 Sync Rules (AOR-SYNC)

| ID | Rule |
|----|------|
| AOR-SYNC-011 | Verify Elixir backend before any mutation |
| AOR-SYNC-012 | Log all sync operations to fractal L3 |
| AOR-SYNC-013 | Retry failed syncs with jitter |
| AOR-SYNC-014 | Invalidate cache on reconnection |
| AOR-SYNC-015 | Prefer Zenoh over HTTP for real-time |
| AOR-SYNC-016 | Batch HTTP requests when possible |
| AOR-SYNC-017 | Compress DuckDB sync payloads |
| AOR-SYNC-018 | Verify HLC ordering on receive |

### 6.2 CEPAF Rules (AOR-CEPAF)

| ID | Rule |
|----|------|
| AOR-CEPAF-001 | Display connection status prominently |
| AOR-CEPAF-002 | Disable mutation buttons when disconnected |
| AOR-CEPAF-003 | Show sync lag in dashboard |
| AOR-CEPAF-004 | Graceful degradation to read-only |
| AOR-CEPAF-005 | Preserve user actions during reconnect |
| AOR-CEPAF-006 | Queue mutations during brief disconnects |

---

## 7. Zenoh Topic Map (Complete)

### 7.1 Existing Topics

| Topic Pattern | Publisher | Subscribers |
|---------------|-----------|-------------|
| `indrajaal/kpi/**` | ZenohKpiPublisher | CEPAF, Dashboard |
| `indrajaal/metrics/**` | ZenohMetricsPublisher | Sentinel, Cortex |
| `indrajaal/alarms/**` | AlarmsContext | CEPAF, LiveView |
| `indrajaal/health/**` | SentinelBridge | CEPAF, Dashboard |
| `indrajaal/agents/**` | AgentMesh | CEPAF, Dashboard |
| `indrajaal/safety/**` | Guardian | CEPAF, Orchestrator |
| `indrajaal/evolution/**` | ImmutableRegister | CEPAF, Audit |
| `indrajaal/fractal/**` | FractalLogger | CEPAF, SigNoz |

### 7.2 New Topics (This Plan)

| Topic Pattern | Publisher | Subscribers | Sprint |
|---------------|-----------|-------------|--------|
| `indrajaal/containers/**` | ZenohContainerPublisher | CEPAF | 32 |
| `indrajaal/mesh/**` | ZenohAgentMeshPublisher | CEPAF | 32 |
| `indrajaal/bio/**` | ZenohBiomorphicPublisher | CEPAF | 32 |
| `indrajaal/alarms/correlation/**` | ZenohAlarmCorrelationPublisher | CEPAF | 32 |
| `indrajaal/devices/state/**` | ZenohDeviceStatePublisher | CEPAF | 32 |
| `indrajaal/access/audit/**` | ZenohAccessAuditPublisher | CEPAF | 32 |
| `indrajaal/sync/duckdb` | DuckDBSync | CEPAF | 33 |
| `indrajaal/constitutional/amendments` | AmendmentPropagator | CEPAF | 34 |
| `indrajaal/constitutional/verify` | CrossVerifier | CEPAF | 34 |

---

## 8. Implementation Timeline

### Sprint 32: Core API Expansion

| Task | Owner | Days | Deps |
|------|-------|------|------|
| Add container endpoints | Backend | 2 | - |
| Add mesh endpoints | Backend | 2 | - |
| Add bio endpoints | Backend | 1 | - |
| Create ZenohContainerPublisher | Backend | 1 | - |
| Create ZenohAgentMeshPublisher | Backend | 1 | - |
| Create ZenohBiomorphicPublisher | Backend | 1 | - |
| Add domain publishers (3) | Backend | 2 | - |
| **Total** | | **10** | |

### Sprint 33: CEPAF Integration + DuckDB

| Task | Owner | Days | Deps |
|------|-------|------|------|
| Create CEPAF subscribers (6) | CEPAF | 3 | Sprint 32 |
| Create CEPAF dashboards (6) | CEPAF | 4 | Subscribers |
| Define DuckDB shared schema | Both | 1 | - |
| Implement DuckDBSync module | Backend | 2 | Schema |
| Implement CEPAF DuckDB receiver | CEPAF | 2 | Schema |
| Integration tests | Both | 2 | All above |
| **Total** | | **14** | |

### Sprint 34: Constitutional Verification

| Task | Owner | Days | Deps |
|------|-------|------|------|
| Create CrossVerifier | Backend | 2 | - |
| Create AmendmentPropagator | Backend | 2 | - |
| CEPAF constitutional panel | CEPAF | 2 | Propagator |
| Reconciliation logic | Both | 2 | Verifier |
| End-to-end testing | Both | 2 | All above |
| **Total** | | **10** | |

---

## 9. Testing Strategy

### 9.1 Unit Tests

```elixir
# test/indrajaal/observability/zenoh_container_publisher_test.exs
# test/indrajaal/observability/zenoh_agent_mesh_publisher_test.exs
# test/indrajaal/observability/zenoh_biomorphic_publisher_test.exs
# test/indrajaal/knowledge/duckdb_sync_test.exs
# test/indrajaal/core/constitution/cross_verifier_test.exs
```

### 9.2 Integration Tests

```elixir
# test/integration/cepaf_prajna_sync_test.exs
describe "CEPAF-Prajna Sync" do
  test "container events published and received" do
    # Start container
    # Verify Zenoh message
    # Verify CEPAF receives
  end

  test "DuckDB sync round-trip" do
    # Insert in Prajna
    # Trigger sync
    # Verify in CEPAF DuckDB
  end

  test "constitutional verification passes" do
    # Get both hashes
    # Verify match
  end
end
```

### 9.3 Property Tests

```elixir
# test/property/sync_ordering_test.exs
property "Zenoh messages maintain HLC ordering" do
  forall messages <- list_of(zenoh_message()) do
    # Publish in order
    # Receive
    # Verify HLC ordering preserved
  end
end
```

---

## 10. Success Criteria

### 10.1 Functional Criteria

| Criterion | Metric | Target |
|-----------|--------|--------|
| Container visibility | Events received | 100% |
| Agent mesh visibility | Agents visible | 100% |
| Biomorphic visibility | Holons visible | 100% |
| DuckDB sync | Records synced | 100% |
| Constitutional sync | Hash match rate | 100% |

### 10.2 Performance Criteria

| Criterion | Metric | Target |
|-----------|--------|--------|
| Zenoh latency | p99 | <50ms |
| HTTP latency | p99 | <500ms |
| DuckDB sync | Interval | <60s |
| Constitutional verify | Interval | <30s |
| Stale data detection | Threshold | <5s |

### 10.3 Reliability Criteria

| Criterion | Metric | Target |
|-----------|--------|--------|
| Sync uptime | Availability | >99.9% |
| Message loss | Rate | <0.01% |
| Reconnect time | p99 | <10s |
| Data consistency | Divergence | 0% |

---

## 11. Risk Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Zenoh connection instability | Medium | High | Circuit breaker + reconnect |
| DuckDB schema drift | Low | High | Version in every record |
| Constitutional desync | Low | Critical | 30s verification cycle |
| Network partition | Medium | High | Graceful degradation mode |
| Rate limiting | Medium | Medium | Backoff + queue |

---

## 12. Rollback Plan

1. **Feature flags**: All new sync features behind flags
2. **Version compatibility**: New messages include version field
3. **Graceful degradation**: CEPAF falls back to HTTP-only mode
4. **DuckDB isolation**: Separate tables for synced data
5. **Constitutional rollback**: Maintain last-known-good hash

---

## Appendix A: File Locations

### New Elixir Files

```
lib/indrajaal_web/controllers/api/prajna_controller.ex  (extend)
lib/indrajaal/observability/zenoh_container_publisher.ex
lib/indrajaal/observability/zenoh_agent_mesh_publisher.ex
lib/indrajaal/observability/zenoh_biomorphic_publisher.ex
lib/indrajaal/observability/zenoh_alarm_correlation_publisher.ex
lib/indrajaal/observability/zenoh_device_state_publisher.ex
lib/indrajaal/observability/zenoh_access_audit_publisher.ex
lib/indrajaal/knowledge/duckdb_sync.ex
lib/indrajaal/core/constitution/cross_verifier.ex
lib/indrajaal/core/constitution/amendment_propagator.ex
```

### New F# Files

```
lib/cepaf/src/Cepaf/Zenoh/ContainerSubscriber.fs
lib/cepaf/src/Cepaf/Zenoh/AgentMeshSubscriber.fs
lib/cepaf/src/Cepaf/Zenoh/BiomorphicSubscriber.fs
lib/cepaf/src/Cepaf/Cockpit/ContainerDashboard.fs
lib/cepaf/src/Cepaf/Cockpit/AgentMeshDashboard.fs
lib/cepaf/src/Cepaf/Cockpit/BiomorphicDashboard.fs
lib/cepaf/src/Cepaf/Cockpit/AlarmCorrelationDashboard.fs
lib/cepaf/src/Cepaf/Cockpit/DeviceStateDashboard.fs
lib/cepaf/src/Cepaf/Cockpit/AccessAuditDashboard.fs
lib/cepaf/src/Cepaf/Knowledge/DuckDBReceiver.fs
lib/cepaf/src/Cepaf/Cockpit/ConstitutionalPanel.fs
```

---

**Document Status**: READY FOR REVIEW
**Next Action**: User approval, then Sprint 32 implementation
