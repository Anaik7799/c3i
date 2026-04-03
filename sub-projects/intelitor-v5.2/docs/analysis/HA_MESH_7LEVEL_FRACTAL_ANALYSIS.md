# SIL-6 HA Mesh 7-Level Fractal Analysis
**Version**: 21.3.0-SIL6 | **Date**: 2026-01-10 | **Status**: ACTIVE
**Architecture**: 3-Node HA Cluster + Zenoh 2oo3 Quorum + CEPAF Cognitive Plane

---

## 1. Executive Summary

This document provides a comprehensive 7-level fractal analysis of the Indrajaal SIL-6 High Availability Mesh, covering:
- **12 containers** in full mesh topology
- **3 Phoenix app instances** with HAProxy load balancing
- **3 Zenoh routers** with 2oo3 quorum consensus
- **Full observability** with OTEL, Prometheus, Grafana, Loki
- **Cognitive plane** with CEPAF Bridge and Cortex

---

## 2. Seven-Level Fractal Architecture (L0-L7)

### 2.1 Fractal Layer Definitions

```
L7: FEDERATION    ─────────────────────────────────────────────────────────────
    │  Cross-cluster coordination, multi-region HA, global consensus
    │  Entities: Federation peers, cross-holon attestation, global invariants
    │
L6: CLUSTER       ─────────────────────────────────────────────────────────────
    │  Erlang distribution, Zenoh mesh, HAProxy coordination
    │  Entities: Node discovery, leader election, quorum (2oo3)
    │
L5: NODE          ─────────────────────────────────────────────────────────────
    │  Container orchestration, resource limits, health checks
    │  Entities: Podman containers, network bridges, volume mounts
    │
L4: CONTAINER     ─────────────────────────────────────────────────────────────
    │  Process isolation, service boundaries, port mapping
    │  Entities: Phoenix, PostgreSQL, Zenoh, CEPAF, Grafana
    │
L3: HOLON         ─────────────────────────────────────────────────────────────
    │  Agent supervision, state machines, cognitive loops
    │  Entities: GenServers, Supervisors, OODA controllers
    │
L2: COMPONENT     ─────────────────────────────────────────────────────────────
    │  Module cohesion, API boundaries, domain contexts
    │  Entities: Ash domains, Phoenix contexts, Ecto schemas
    │
L1: FUNCTION      ─────────────────────────────────────────────────────────────
    │  I/O contracts, type safety, pure functions
    │  Entities: Functions, guards, pattern matches
    │
L0: RUNTIME       ─────────────────────────────────────────────────────────────
    │  BEAM VM, schedulers, memory, GC
    │  Entities: Processes, ETS tables, NIFs
```

### 2.2 Layer Interaction Matrix

| From\To | L0 | L1 | L2 | L3 | L4 | L5 | L6 | L7 |
|---------|----|----|----|----|----|----|----|----|
| **L0** | ● | ↑ | - | - | - | - | - | - |
| **L1** | ↓ | ● | ↑ | - | - | - | - | - |
| **L2** | - | ↓ | ● | ↑ | - | - | - | - |
| **L3** | - | - | ↓ | ● | ↑ | - | - | - |
| **L4** | - | - | - | ↓ | ● | ↑ | - | - |
| **L5** | - | - | - | - | ↓ | ● | ↑ | - |
| **L6** | - | - | - | - | - | ↓ | ● | ↑ |
| **L7** | - | - | - | - | - | - | ↓ | ● |

**Legend**: ● = self, ↑ = upward call, ↓ = downward call, - = no direct interaction

---

## 3. Mathematical Model

### 3.1 System State Space

Let the system state $S$ be defined as:

$$S = (C, N, Z, H, R)$$

Where:
- $C = \{c_1, c_2, ..., c_{12}\}$ — Set of 12 containers
- $N = \{n_1, n_2, n_3\}$ — Set of 3 app nodes
- $Z = \{z_1, z_2, z_3\}$ — Set of 3 Zenoh routers
- $H: C \to \{healthy, unhealthy, starting, stopped\}$ — Health function
- $R: N \times N \to \{connected, disconnected\}$ — Reachability relation

### 3.2 Availability Model

**Single Node Availability**:
$$A_{node} = \frac{MTBF}{MTBF + MTTR}$$

Given:
- $MTBF = 8760$ hours (1 year target)
- $MTTR = 0.5$ hours (30-minute recovery)

$$A_{node} = \frac{8760}{8760 + 0.5} = 0.999943 = 99.9943\%$$

**3-Node HA Cluster Availability** (requires 2 of 3):
$$A_{cluster} = \binom{3}{3}A^3 + \binom{3}{2}A^2(1-A)$$
$$A_{cluster} = A^3 + 3A^2(1-A)$$
$$A_{cluster} = (0.999943)^3 + 3(0.999943)^2(0.000057)$$
$$A_{cluster} = 0.999829 + 0.000171 = 0.999999 = 99.9999\%$$

### 3.3 Quorum Consensus (2oo3)

For Zenoh mesh with 2-out-of-3 voting:

$$P(quorum) = P(3/3) + P(2/3)$$
$$P(quorum) = p^3 + 3p^2(1-p)$$

Where $p = 0.999$ (individual router reliability):
$$P(quorum) = 0.999^3 + 3(0.999)^2(0.001)$$
$$P(quorum) = 0.997003 + 0.002994 = 0.999997$$

### 3.4 Load Balancing Distribution

HAProxy round-robin distribution with $n=3$ backends:

$$P(request \to node_i) = \frac{1}{n} = \frac{1}{3} = 0.333...$$

Expected requests per node over $N$ total requests:
$$E[requests_i] = \frac{N}{3}$$

Variance (assuming Poisson arrival):
$$Var[requests_i] = \frac{N}{3}$$

### 3.5 Failure Probability (SIL-6)

SIL-6 Probability of Failure on Demand (PFD):
$$PFD_{SIL6} < 10^{-7}$$

With Triple Modular Redundancy (TMR):
$$PFD_{TMR} = 3p^2 - 2p^3$$

Where $p = 10^{-4}$ (single component PFD):
$$PFD_{TMR} = 3(10^{-8}) - 2(10^{-12}) = 3 \times 10^{-8}$$

With 2oo3 voting:
$$PFD_{2oo3} = 3p^2(1-p) + p^3 \approx 3p^2 = 3 \times 10^{-8}$$

---

## 4. STAMP Analysis (Systems-Theoretic Accident Model and Processes)

### 4.1 Control Structure Diagram

```
                    ┌─────────────────────┐
                    │   FEDERATION (L7)   │
                    │  Global Invariants  │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │    HAPROXY (L6)     │
                    │  Load Distribution  │
                    └──────────┬──────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
┌───────▼───────┐      ┌───────▼───────┐      ┌───────▼───────┐
│   APP-1 (L4)  │      │   APP-2 (L4)  │      │   APP-3 (L4)  │
│  172.31.0.10  │◄────►│  172.31.0.11  │◄────►│  172.31.0.12  │
└───────┬───────┘      └───────┬───────┘      └───────┬───────┘
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │   ZENOH MESH (L6)   │
                    │   2oo3 Quorum       │
                    └──────────┬──────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
┌───────▼───────┐      ┌───────▼───────┐      ┌───────▼───────┐
│  ZENOH-1 (L4) │      │  ZENOH-2 (L4) │      │  ZENOH-3 (L4) │
│  172.31.0.40  │◄────►│  172.31.0.41  │◄────►│  172.31.0.42  │
└───────────────┘      └───────────────┘      └───────────────┘
```

### 4.2 STAMP Constraint Table

| ID | Constraint | Controller | Controlled Process | Severity |
|----|------------|------------|-------------------|----------|
| SC-HA-001 | Load balancer MUST distribute across healthy nodes | HAProxy | App-1,2,3 | CRITICAL |
| SC-HA-002 | Failed node MUST be removed within 30s | HAProxy | App-N | CRITICAL |
| SC-HA-003 | Zenoh quorum MUST maintain 2oo3 consensus | Zenoh-Proxy | Zenoh-1,2,3 | CRITICAL |
| SC-HA-004 | Database writes MUST be atomic across cluster | PostgreSQL | App-1,2,3 | CRITICAL |
| SC-HA-005 | DuckDB locks MUST be per-node isolated | HOLON_DATA_PATH | Prajna Register | CRITICAL |
| SC-HA-006 | Erlang cookie MUST be identical across cluster | RELEASE_COOKIE | App-1,2,3 | HIGH |
| SC-HA-007 | Build cache MUST complete before replica start | service_healthy | App-2,3 | HIGH |
| SC-HA-008 | Observability MUST aggregate from all nodes | OTEL Collector | App-1,2,3 | HIGH |
| SC-HA-009 | Failover MUST complete within 5s | Supervisor | Failed Node | CRITICAL |
| SC-HA-010 | State recovery MUST use holon SQLite/DuckDB | Immutable Register | App-N | CRITICAL |
| SC-HA-011 | Network partition MUST trigger split-brain prevention | Zenoh Quorum | Cluster | CRITICAL |
| SC-HA-012 | Health checks MUST run every 30s | Podman Healthcheck | All Containers | HIGH |

### 4.3 Hazard Analysis

| Hazard ID | Hazard Description | Potential Accident | Severity | Likelihood | Risk |
|-----------|--------------------|--------------------|----------|------------|------|
| HZ-001 | All 3 app nodes fail simultaneously | Complete service outage | 10 | 1 | 10 |
| HZ-002 | HAProxy fails | No request routing | 9 | 2 | 18 |
| HZ-003 | Database corruption | Data loss | 10 | 1 | 10 |
| HZ-004 | Zenoh quorum loss (2+ routers down) | Message bus failure | 8 | 2 | 16 |
| HZ-005 | DuckDB lock contention | Node startup failure | 7 | 4 | 28 |
| HZ-006 | Build cache race condition | Replica crash loop | 6 | 5 | 30 |
| HZ-007 | Network partition (split brain) | Inconsistent state | 9 | 2 | 18 |
| HZ-008 | Memory exhaustion | OOM kill | 7 | 3 | 21 |
| HZ-009 | Certificate expiry | TLS failure | 6 | 2 | 12 |
| HZ-010 | Erlang cookie mismatch | Cluster partitioning | 8 | 2 | 16 |

---

## 5. AOR (Autonomous Operational Rules) Matrix

### 5.1 HA Mesh Operational Rules

| ID | Rule | Trigger | Action | Verification |
|----|------|---------|--------|--------------|
| AOR-HA-001 | Node failure detected | Health check fails 3x | Remove from HAProxy pool | HAProxy stats |
| AOR-HA-002 | Node recovery detected | Health check passes | Add to HAProxy pool | Connection test |
| AOR-HA-003 | Quorum degraded | Zenoh router down | Alert + scale replacement | Quorum count |
| AOR-HA-004 | Memory pressure | >80% usage | Trigger GC + alert | Memory metrics |
| AOR-HA-005 | Request latency spike | p99 > 500ms | Scale horizontal | Latency metrics |
| AOR-HA-006 | Database connection pool exhausted | Pool at limit | Queue + backpressure | Pool metrics |
| AOR-HA-007 | Compilation needed | Code change detected | Trigger on app-1 first | Build status |
| AOR-HA-008 | DuckDB lock timeout | Lock wait > 5s | Restart with isolation | Lock status |
| AOR-HA-009 | Erlang cluster partitioned | Node unreachable | Attempt rejoin, then isolate | Cluster status |
| AOR-HA-010 | OTEL collector down | No traces received | Buffer locally, retry | Trace count |

### 5.2 OODA Loop Integration

```elixir
# AOR-HA OODA Cycle (30s interval)
defmodule Indrajaal.HA.OODAController do
  @cycle_interval_ms 30_000

  def observe do
    %{
      nodes: get_cluster_nodes(),
      health: get_health_status(),
      metrics: get_prometheus_metrics(),
      zenoh: get_zenoh_quorum_status(),
      haproxy: get_haproxy_stats()
    }
  end

  def orient(observations) do
    %{
      cluster_health: calculate_cluster_health(observations),
      degraded_nodes: find_degraded_nodes(observations),
      quorum_status: assess_quorum(observations),
      load_distribution: analyze_load(observations),
      anomalies: detect_anomalies(observations)
    }
  end

  def decide(orientation) do
    cond do
      orientation.quorum_status == :lost -> {:emergency, :restore_quorum}
      length(orientation.degraded_nodes) > 0 -> {:action, :heal_nodes}
      orientation.cluster_health < 0.8 -> {:alert, :investigate}
      true -> {:nominal, :continue}
    end
  end

  def act(decision) do
    case decision do
      {:emergency, action} -> execute_emergency(action)
      {:action, action} -> execute_action(action)
      {:alert, action} -> send_alert(action)
      {:nominal, _} -> log_nominal()
    end
  end
end
```

---

## 6. TDG (Test-Driven Generation) Specifications

### 6.1 Property-Based Test Generators

```elixir
# TDG Generator Specifications for HA Mesh
defmodule Indrajaal.HA.TDG.Generators do
  use PropCheck
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # Node state generator
  def node_state do
    PC.oneof([:healthy, :unhealthy, :starting, :stopped])
  end

  # Cluster configuration generator
  def cluster_config do
    PC.let([
      node_count <- PC.range(1, 5),
      zenoh_count <- PC.range(1, 3),
      quorum_size <- PC.range(1, 3)
    ]) do
      %{
        nodes: node_count,
        zenoh_routers: zenoh_count,
        quorum_size: min(quorum_size, zenoh_count)
      }
    end
  end

  # Request distribution generator
  def request_distribution do
    SD.list_of(
      SD.tuple({
        SD.member_of([:app_1, :app_2, :app_3]),
        SD.positive_integer()
      }),
      min_length: 1,
      max_length: 1000
    )
  end

  # Failure scenario generator
  def failure_scenario do
    PC.oneof([
      {:node_failure, PC.range(1, 3)},
      {:network_partition, PC.list(PC.range(1, 3))},
      {:zenoh_failure, PC.range(1, 3)},
      {:database_failure, :primary},
      {:haproxy_failure, :single}
    ])
  end
end
```

### 6.2 TDG Test Matrix

| Test Category | Generator | Properties | Coverage Target |
|---------------|-----------|------------|-----------------|
| Availability | cluster_config | Quorum maintained | 100% |
| Load Balance | request_distribution | Even distribution | 95% |
| Failover | failure_scenario | Recovery < 30s | 100% |
| Consensus | node_state | 2oo3 agreement | 100% |
| Isolation | holon_paths | No lock contention | 100% |

---

## 7. FMEA (Failure Mode and Effects Analysis)

### 7.1 FMEA Worksheet

| ID | Component | Failure Mode | Effect | Severity (S) | Occurrence (O) | Detection (D) | RPN | Mitigation |
|----|-----------|--------------|--------|--------------|----------------|---------------|-----|------------|
| FM-001 | HAProxy | Complete failure | No routing | 10 | 1 | 2 | 20 | Standby HAProxy |
| FM-002 | HAProxy | Misrouting | Wrong backend | 6 | 2 | 3 | 36 | Health checks |
| FM-003 | App-1 | Crash | 1/3 capacity | 5 | 3 | 2 | 30 | Auto-restart |
| FM-004 | App-2 | Crash | 1/3 capacity | 5 | 3 | 2 | 30 | Auto-restart |
| FM-005 | App-3 | Crash | 1/3 capacity | 5 | 3 | 2 | 30 | Auto-restart |
| FM-006 | 2 Apps | Crash | 2/3 capacity loss | 8 | 2 | 2 | 32 | Fast failover |
| FM-007 | All Apps | Crash | Complete outage | 10 | 1 | 1 | 10 | Multi-region |
| FM-008 | PostgreSQL | Crash | Data unavailable | 10 | 1 | 2 | 20 | Replica failover |
| FM-009 | PostgreSQL | Corruption | Data loss | 10 | 1 | 4 | 40 | Backup + WAL |
| FM-010 | Zenoh-1 | Crash | 2oo3 still valid | 3 | 3 | 2 | 18 | Auto-restart |
| FM-011 | Zenoh-1,2 | Crash | Quorum lost | 9 | 1 | 2 | 18 | Fast restart |
| FM-012 | DuckDB | Lock contention | Node fails start | 7 | 4 | 3 | 84 | HOLON_DATA_PATH |
| FM-013 | Build Cache | Race condition | Replica crash | 6 | 5 | 4 | 120 | service_healthy |
| FM-014 | Network | Partition | Split brain | 9 | 2 | 3 | 54 | Quorum voting |
| FM-015 | Memory | Exhaustion | OOM kill | 7 | 3 | 4 | 84 | Resource limits |
| FM-016 | OTEL | Collector down | No telemetry | 4 | 2 | 3 | 24 | Local buffer |
| FM-017 | Grafana | Dashboard down | No visibility | 3 | 2 | 2 | 12 | Prometheus direct |
| FM-018 | CEPAF Bridge | Crash | No F# integration | 5 | 3 | 2 | 30 | Auto-restart |
| FM-019 | Erlang Cookie | Mismatch | Cluster split | 8 | 2 | 5 | 80 | Config validation |
| FM-020 | Health Check | False positive | Premature removal | 6 | 2 | 4 | 48 | Multiple checks |

### 7.2 RPN Analysis Summary

```
HIGH RISK (RPN > 80):
  FM-013: Build Cache Race (RPN=120) ← MITIGATED with service_healthy
  FM-012: DuckDB Lock (RPN=84) ← MITIGATED with HOLON_DATA_PATH
  FM-015: Memory Exhaustion (RPN=84) ← Resource limits deployed
  FM-019: Erlang Cookie Mismatch (RPN=80) ← Config validation needed

MEDIUM RISK (RPN 40-80):
  FM-014: Network Partition (RPN=54)
  FM-020: False Positive Health (RPN=48)
  FM-009: PostgreSQL Corruption (RPN=40)

LOW RISK (RPN < 40):
  All others with existing mitigations
```

### 7.3 RPN Reduction Actions

| Original RPN | Failure Mode | Mitigation Applied | New RPN |
|--------------|--------------|-------------------|---------|
| 120 | Build Cache Race | `service_healthy` dependency | 24 |
| 84 | DuckDB Lock | `HOLON_DATA_PATH` isolation | 12 |
| 84 | Memory Exhaustion | 8GB limit per container | 42 |
| 80 | Erlang Cookie | Environment validation | 16 |

---

## 8. Dependency Graph Analysis

### 8.1 Container Dependency DAG

```
                              ┌──────────────┐
                              │   haproxy    │
                              └──────┬───────┘
                                     │ depends_on
                    ┌────────────────┼────────────────┐
                    │                │                │
              ┌─────▼─────┐    ┌─────▼─────┐    ┌─────▼─────┐
              │   app-1   │    │   app-2   │    │   app-3   │
              └─────┬─────┘    └─────┬─────┘    └─────┬─────┘
                    │                │                │
                    │                │ service_healthy
                    │                ├────────────────┘
                    │                │
                    ├────────────────┤
                    │                │
          ┌─────────┼────────┐       │
          │         │        │       │
    ┌─────▼───┐ ┌───▼───┐ ┌──▼──────▼──┐
    │   db    │ │  obs  │ │zenoh-router│
    └─────────┘ └───────┘ └─────┬──────┘
                                │ service_healthy
                    ┌───────────┼───────────┐
                    │           │           │
              ┌─────▼───┐ ┌─────▼───┐ ┌─────▼───┐
              │zenoh-1  │ │zenoh-2  │ │zenoh-3  │
              └─────────┘ └─────────┘ └─────────┘
```

### 8.2 Startup Order (Topological Sort)

```
Phase 1 (Parallel):  db, obs, zenoh-1, zenoh-2, zenoh-3
Phase 2 (Depends):   zenoh-router (waits for zenoh-1,2,3 healthy)
Phase 3 (Depends):   cepaf-bridge (waits for zenoh-router healthy)
Phase 4 (Depends):   cortex (waits for cepaf-bridge healthy)
Phase 5 (Depends):   app-1 (waits for db healthy, zenoh-router healthy)
Phase 6 (Depends):   app-2 (waits for app-1 healthy)
Phase 7 (Depends):   app-3 (waits for app-1 healthy)
Phase 8 (Depends):   haproxy (waits for app-1, app-2, app-3)
```

### 8.3 Critical Path Analysis

```
Critical Path: zenoh-1 → zenoh-router → app-1 → app-2 → haproxy
Critical Time: 15s + 10s + 900s + 30s + 10s = 965s (worst case)

Parallel Path: db (15s) || obs (60s) || zenoh-1,2,3 (10s)
Parallel Savings: max(15, 60, 10) = 60s vs 85s sequential = 25s saved
```

### 8.4 Graph Metrics

| Metric | Value | Interpretation |
|--------|-------|----------------|
| Nodes | 12 | Total containers |
| Edges | 18 | Dependencies |
| Depth | 8 | Startup phases |
| Critical Path | 965s | Max startup time |
| Parallelism | 0.42 | Parallel efficiency |
| Connectivity | 1.5 | Avg dependencies |

---

## 9. 5-Order Effects Analysis

### 9.1 Node Failure Cascade

```
Event: App-1 crashes

1st ORDER (Immediate, 0-1s):
  ├─ Process terminates
  ├─ Port 4000 stops responding
  └─ Erlang node leaves cluster

2nd ORDER (Seconds, 1-30s):
  ├─ HAProxy health check fails (3x10s = 30s)
  ├─ Zenoh detects subscriber gone
  ├─ Other nodes detect cluster change
  └─ OTEL stops receiving traces from app-1

3rd ORDER (Seconds-Minutes, 30s-5m):
  ├─ HAProxy removes app-1 from pool
  ├─ Load redistributed to app-2, app-3
  ├─ Prajna dashboard shows degraded state
  └─ Alerts fire to operators

4th ORDER (Minutes, 5m-30m):
  ├─ Podman restart policy triggers
  ├─ App-1 begins recovery
  ├─ Build cache already available (shared volume)
  └─ Health checks begin passing

5th ORDER (Minutes-Hours, 30m+):
  ├─ App-1 rejoins HAProxy pool
  ├─ Load rebalanced across 3 nodes
  ├─ Metrics return to baseline
  └─ Incident logged for review
```

### 9.2 Database Failure Cascade

```
Event: PostgreSQL crashes

1st ORDER (Immediate):
  ├─ Connections terminated
  ├─ In-flight transactions aborted
  └─ Port 5433 unreachable

2nd ORDER (Seconds):
  ├─ All 3 apps detect connection loss
  ├─ Ecto pool attempts reconnect
  ├─ Circuit breakers trip
  └─ Ash operations queue/fail

3rd ORDER (Seconds-Minutes):
  ├─ API endpoints return 503
  ├─ HAProxy marks backends unhealthy
  ├─ Prajna dashboard shows critical
  └─ All writes blocked

4th ORDER (Minutes):
  ├─ Podman restarts db container
  ├─ PostgreSQL recovery from WAL
  ├─ Connections re-established
  └─ Queued operations retry

5th ORDER (Hours):
  ├─ Service fully restored
  ├─ Data integrity verified
  ├─ Post-incident review
  └─ Preventive measures applied
```

---

## 10. BDD Use Cases

### 10.1 Feature: HA Load Balancing

```gherkin
Feature: High Availability Load Balancing
  As a system operator
  I want requests distributed across 3 app nodes
  So that no single node becomes a bottleneck

  Background:
    Given the HA mesh is running with 12 containers
    And all 3 app nodes are healthy
    And HAProxy is configured for round-robin

  Scenario: Even load distribution
    When 1000 requests are sent to the load balancer
    Then app-1 should receive approximately 333 requests
    And app-2 should receive approximately 333 requests
    And app-3 should receive approximately 333 requests
    And the distribution variance should be less than 5%

  Scenario: Node failure failover
    Given app-2 becomes unhealthy
    When HAProxy performs health check
    Then app-2 should be removed from the pool within 30 seconds
    And subsequent requests should be distributed only to app-1 and app-3
    And no requests should fail during failover

  Scenario: Node recovery
    Given app-2 was previously unhealthy
    When app-2 health checks pass 3 consecutive times
    Then app-2 should be added back to the pool
    And requests should be distributed across all 3 nodes
```

### 10.2 Feature: Zenoh Quorum Consensus

```gherkin
Feature: Zenoh 2oo3 Quorum Consensus
  As a message bus operator
  I want Zenoh to maintain 2oo3 quorum
  So that messages are reliably delivered

  Background:
    Given 3 Zenoh routers are running (zenoh-1, zenoh-2, zenoh-3)
    And zenoh-proxy is connected to all 3 routers

  Scenario: Single router failure maintains quorum
    Given zenoh-1 crashes
    When a message is published to "indrajaal/kpi/health"
    Then the message should be delivered to all subscribers
    And zenoh-2 and zenoh-3 should maintain consensus

  Scenario: Two router failures loses quorum
    Given zenoh-1 and zenoh-2 crash
    When a message is published
    Then the message should be queued
    And an alert should be generated
    And quorum status should show "degraded"

  Scenario: Router recovery restores quorum
    Given zenoh-1 was previously crashed
    When zenoh-1 recovers and passes health check
    Then zenoh-1 should rejoin the mesh
    And quorum status should show "healthy"
```

### 10.3 Feature: DuckDB Lock Isolation

```gherkin
Feature: Per-Node Holon Data Isolation
  As a system architect
  I want each app node to have isolated DuckDB storage
  So that there are no lock conflicts

  Background:
    Given HOLON_DATA_PATH is set to /app/data/holons for each node
    And each node has its own ha_appN_data volume

  Scenario: Concurrent DuckDB access
    Given app-1 is writing to its prajna_register.duckdb
    And app-2 is writing to its prajna_register.duckdb
    When app-3 attempts to write to its prajna_register.duckdb
    Then all 3 writes should succeed
    And no lock conflicts should occur

  Scenario: Node restart with isolated data
    Given app-2 crashes while holding a DuckDB connection
    When app-2 restarts
    Then app-2 should open its own DuckDB file
    And app-1 and app-3 should be unaffected
```

### 10.4 Feature: Build Cache Synchronization

```gherkin
Feature: Shared Build Cache with Healthy Dependencies
  As a developer
  I want app-2 and app-3 to wait for app-1 to compile
  So that they use the complete build cache

  Background:
    Given ha_build_cache volume is shared across all 3 apps
    And app-2 depends on app-1 with service_healthy condition
    And app-3 depends on app-1 with service_healthy condition

  Scenario: Clean start with compilation
    Given the build cache is empty
    When the HA mesh starts
    Then app-1 should compile first (approximately 15 minutes)
    And app-1 health check should pass after compilation
    And app-2 should start only after app-1 is healthy
    And app-3 should start only after app-1 is healthy
    And app-2 and app-3 should skip compilation (cache hit)

  Scenario: Incremental compilation
    Given the build cache contains a previous build
    When a code change is made and mesh restarts
    Then app-1 should perform incremental compilation
    And app-2 and app-3 should see the updated cache
```

### 10.5 Feature: End-to-End Request Flow

```gherkin
Feature: Complete Request Lifecycle in HA Mode
  As an API consumer
  I want my requests to be processed reliably
  So that the application serves my needs

  Scenario: Successful API request through HA stack
    Given the HA mesh is healthy
    When I send a GET request to http://localhost:4000/api/health
    Then the request should be routed through HAProxy
    And one of app-1, app-2, or app-3 should handle the request
    And the response should return within 100ms
    And the response should contain health status

  Scenario: Prajna cockpit access
    Given the HA mesh is healthy
    When I navigate to http://localhost:4000/prajna
    Then the Prajna C3I cockpit should load
    And metrics should be aggregated from all 3 nodes
    And the health score should reflect cluster state

  Scenario: Database write consistency
    Given a write request is sent to app-1
    When the data is committed to PostgreSQL
    Then the data should be visible from app-2
    And the data should be visible from app-3
    And all nodes should see consistent state
```

---

## 11. Formal Verification Assertions

### 11.1 Safety Invariants (Quint Specification)

```quint
module HAMeshSafety {
  type NodeState = Healthy | Unhealthy | Starting | Stopped
  type QuorumState = Valid | Degraded | Lost

  var nodes: Set[NodeId]
  var nodeStates: NodeId -> NodeState
  var zenohRouters: Set[RouterId]
  var routerStates: RouterId -> NodeState

  // INV-001: At least 1 app node must be healthy for service
  invariant AtLeastOneHealthyNode {
    exists n in nodes: nodeStates[n] == Healthy
  }

  // INV-002: Zenoh quorum requires 2 of 3 routers
  invariant ZenohQuorumValid {
    size({ r in zenohRouters: routerStates[r] == Healthy }) >= 2
    implies quorumState == Valid
  }

  // INV-003: HAProxy only routes to healthy nodes
  invariant HAProxyRoutesOnlyHealthy {
    forall n in haproxyPool: nodeStates[n] == Healthy
  }

  // INV-004: DuckDB paths are unique per node
  invariant UniqueHolonPaths {
    forall n1, n2 in nodes:
      n1 != n2 implies holonPath[n1] != holonPath[n2]
  }

  // INV-005: Build cache race prevention
  invariant BuildCacheOrdering {
    nodeStates[app2] == Healthy implies nodeStates[app1] == Healthy
    nodeStates[app3] == Healthy implies nodeStates[app1] == Healthy
  }
}
```

### 11.2 Temporal Properties (LTL)

```
// PROP-001: Eventually all nodes healthy after start
□(systemStarted → ◇(∀n ∈ nodes: healthy(n)))

// PROP-002: Failure always followed by recovery
□(failed(n) → ◇healthy(n))

// PROP-003: Quorum always eventually restored
□(quorumLost → ◇quorumValid)

// PROP-004: No split brain ever occurs
□¬(partition(A) ∧ partition(B) ∧ writes(A) ∧ writes(B))

// PROP-005: Request eventually served
□(request(r) → ◇response(r))
```

---

## 12. Metrics and KPIs

### 12.1 SIL-6 Compliance Metrics

| Metric | Target | Threshold | Current |
|--------|--------|-----------|---------|
| Availability | 99.9999% | > 99.999% | TBD |
| PFH (Probability of Failure/Hour) | < 10⁻¹² | < 10⁻¹¹ | TBD |
| Diagnostic Coverage | > 99.99% | > 99.9% | TBD |
| Safe Failure Fraction | > 99.9% | > 99% | TBD |
| MTBF | > 8760h | > 4380h | TBD |
| MTTR | < 0.5h | < 1h | TBD |

### 12.2 Operational KPIs

| KPI | Target | Alert Threshold |
|-----|--------|-----------------|
| Request latency (p99) | < 100ms | > 500ms |
| Error rate | < 0.01% | > 0.1% |
| Node availability | > 99.9% | < 99% |
| Quorum status | Valid | Degraded |
| Memory utilization | < 70% | > 85% |
| CPU utilization | < 60% | > 80% |

---

## 13. Appendices

### A. Container IP Address Map

| Container | IP Address | Ports |
|-----------|------------|-------|
| haproxy | 172.31.0.5 | 4000, 4001, 8404 |
| app-1 | 172.31.0.10 | 4000 (internal) |
| app-2 | 172.31.0.11 | 4000 (internal) |
| app-3 | 172.31.0.12 | 4000 (internal) |
| db | 172.31.0.20 | 5433 |
| obs | 172.31.0.30 | 3000, 4317, 9090 |
| zenoh-1 | 172.31.0.40 | 7447, 8000 |
| zenoh-2 | 172.31.0.41 | 7448, 8001 |
| zenoh-3 | 172.31.0.42 | 7449, 8002 |
| zenoh-proxy | 172.31.0.43 | - |
| cepaf-bridge | 172.31.0.50 | 9876 |
| cortex | 172.31.0.51 | 9877 |

### B. Volume Mapping

| Volume | Mount Point | Purpose |
|--------|-------------|---------|
| ha_db_data | /var/lib/postgresql/pgdata | PostgreSQL data |
| ha_obs_data | /data | Observability data |
| ha_app1_data | /app/data | App-1 holon data |
| ha_app2_data | /app/data | App-2 holon data |
| ha_app3_data | /app/data | App-3 holon data |
| ha_build_cache | /workspace/_build | Shared build cache |
| ha_deps_cache | /workspace/deps | Shared deps cache |

### C. Document Control

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Author | Claude Opus 4.5 |
| Created | 2026-01-10 |
| Classification | Internal |
| Review Cycle | Quarterly |
