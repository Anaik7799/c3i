# 🧬 INTELITOR DEEP-DIVE ARCHITECTURE IMPLEMENTATION PLAN

**Version**: 1.1.0-DEEP-DIVE
**Status**: 🟢 **READY**
**Date**: 2025-12-18
**Sources**: 
- `HA-cluster-transition-specification.md`
- `HA-FLAME-hybrid-architecture.md`
- `AUTONOMIC-SYSTEM-MASTER-PLAN.md`

## 21.0 - Autonomic Architecture Deep-Dive (P1)
**Status**: pending | **Priority**: P1
**Description**: Specific, low-level implementation of the "Substrate", "Cell", and "Limb" layers based on immutable architecture axioms.

### 21.1 - Substrate: Tailscale Mesh & Networking (P1)
**Status**: pending | **Priority**: P1 | **Parent**: 21.0
**Source**: `HA-cluster-transition-specification.md`

#### 21.1.1 - Container Infrastructure (L5 Physics) (P1)
**Status**: pending | **Priority**: P1 | **Parent**: 21.1
**Goal**: Enable WireGuard networking at the OS/Container level.

##### 21.1.1.1 - Tailscale Binary Integration
**Status**: pending | **Priority**: P1 | **Parent**: 21.1.1
- **Task**: Update `Containerfile` / `Dockerfile`
- **Action**: `COPY --from=docker.io/tailscale/tailscale:stable /usr/local/bin/tailscaled /usr/local/bin/tailscaled`
- **Action**: `COPY --from=docker.io/tailscale/tailscale:stable /usr/local/bin/tailscale /usr/local/bin/tailscale`

##### 21.1.1.2 - Boot Script Orchestration
**Status**: pending | **Priority**: P1 | **Parent**: 21.1.1
- **Task**: Create `bin/start_ha.sh`
- **Logic**: 
  1. Start `tailscaled --tun=userspace-networking`
  2. Run `tailscale up --authkey=$TS_AUTHKEY --hostname=app-$REPLICA_ID`
  3. Export `RELEASE_NODE` IP
  4. Exec `$REL_NAME start`

##### 21.1.1.3 - Runtime Environment Configuration
**Status**: pending | **Priority**: P1 | **Parent**: 21.1.1
- **Task**: Update `rel/env.sh.eex`
- **Code**: `export RELEASE_NODE=indrajaal@$(tailscale ip -4)`
- **Code**: `export RELEASE_DISTRIBUTION=name`

#### 21.1.2 - Cluster Discovery Strategy (L3 Network) (P1)
**Status**: pending | **Priority**: P1 | **Parent**: 21.1
**Goal**: Configure `libcluster` for MagicDNS discovery.

##### 21.1.2.1 - Topology Configuration
**Status**: pending | **Priority**: P1 | **Parent**: 21.1.2
- **Task**: Update `config/runtime.exs`
- **Strategy**: `Cluster.Strategy.Epmd` or `DNS`
- **Config**: `hosts: [:"app-1@app-1", :"app-2@app-2", :"app-3@app-3"]` (MagicDNS names)

##### 21.1.2.2 - EPMD Binding
**Status**: pending | **Priority**: P1 | **Parent**: 21.1.2
- **Task**: Configure `vm.args`
- **Constraint**: Bind EPMD/Dist ports to `tailscale0` interface only (SC-NET-002)

### 21.2 - Cell: Sentinel Safety Kernel (P1)
**Status**: pending | **Priority**: P1 | **Parent**: 21.0
**Source**: `HA-cluster-transition-specification.md`

#### 21.3.0 - Sentinel Implementation (L2 Control) (P1)
**Status**: pending | **Priority**: P1 | **Parent**: 21.2
**Goal**: Prevent Split-Brain via Quorum Logic.

##### 21.3.0.1 - GenServer Structure
**Status**: pending | **Priority**: P1 | **Parent**: 21.3.0
- **Task**: Create `lib/indrajaal/cluster/sentinel.ex`
- **State**: `%{nodes: MapSet, quorum: integer, status: :healthy}`

##### 21.3.0.2 - Node Monitoring
**Status**: pending | **Priority**: P1 | **Parent**: 21.3.0
- **Task**: Handle `:nodeup` / `:nodedown`
- **Logic**: Update `state.nodes` set, recalculate `size(nodes)`.

##### 21.3.0.3 - Quorum Logic
**Status**: pending | **Priority**: P1 | **Parent**: 21.3.0
- **Task**: Implement `quorum?()` predicate
- **Formula**: `active_nodes >= (total_expected / 2) + 1`

##### 21.3.0.4 - Debounce Mechanism
**Status**: pending | **Priority**: P1 | **Parent**: 21.3.0
- **Task**: Implement 5s debounce for `:nodedown` events to prevent flapping.

#### 21.2.2 - Apoptosis Protocol (Self-Preservation) (P1)
**Status**: pending | **Priority**: P1 | **Parent**: 21.2
**Goal**: Graceful self-termination on partition.

##### 21.2.2.1 - Intentional Leave
**Status**: pending | **Priority**: P1 | **Parent**: 21.2.2
- **Task**: Implement `initiate_apoptosis/0`
- **Action**: Log CRITICAL alert -> `System.stop(1)` -> `tailscale logout`

### 21.3 - Limbs: FLAME Hybrid Architecture (P2)
**Status**: pending | **Priority**: P2 | **Parent**: 21.0
**Source**: `HA-FLAME-hybrid-architecture.md`

#### 21.3.1 - FLAME Pools Configuration (L3 Limbs) (P2)
**Status**: pending | **Priority**: P2 | **Parent**: 21.3
**Goal**: Define elastic compute boundaries.

##### 21.3.1.1 - Intelligence Pool
**Status**: pending | **Priority**: P2 | **Parent**: 21.3.1
- **Task**: Define `Indrajaal.FLAME.IntelligencePool`
- **Specs**: `min: 0`, `max: 10`, `boot_timeout: 30s`
- **Workload**: CPU-intensive (ML)

##### 21.3.1.2 - Video Pool
**Status**: pending | **Priority**: P2 | **Parent**: 21.3.1
- **Task**: Define `Indrajaal.FLAME.VideoPool`
- **Specs**: `min: 0`, `max: 20`
- **Workload**: Memory/GPU-intensive

#### 21.3.2 - Domain Integration ("Flame Pattern") (P2)
**Status**: pending | **Priority**: P2 | **Parent**: 21.3
**Goal**: Wrap heavy functions in FLAME calls.

##### 21.3.2.1 - Intelligence Wrapper
**Status**: pending | **Priority**: P2 | **Parent**: 21.3.2
- **File**: `lib/indrajaal/intelligence/entry.ex`
- **Code**: `FLAME.call(IntelligencePool, fn -> ... end)`

##### 21.3.2.2 - State Safety Check (SC-FLM-001)
**Status**: pending | **Priority**: P2 | **Parent**: 21.3.2
- **Task**: Verify wrapped functions do NOT rely on `Process.get` or local `ETS`.
- **Validation**: Manual code review + Test assertion.

### 21.4 - Reflex: Circuit Breakers (P2)
**Status**: pending | **Priority**: P2 | **Parent**: 21.0
**Source**: `AUTONOMIC-SYSTEM-MASTER-PLAN.md`

#### 21.4.1 - Fuse Integration (L4 Reflex) (P2)
**Status**: pending | **Priority**: P2 | **Parent**: 21.4

##### 21.4.1.1 - Circuit Breaker Module
**Status**: pending | **Priority**: P2 | **Parent**: 21.4.1
- **Task**: Implement `Indrajaal.Reflex.CircuitBreaker`
- **Lib**: `:fuse`
- **Config**: 5 failures / 60s window.

##### 21.4.1.2 - External API Guard
**Status**: pending | **Priority**: P2 | **Parent**: 21.4.1
- **Task**: Wrap all `Req` calls to 3rd party APIs with `CircuitBreaker`.

### 21.5 - Cortex: Telemetry Sensors (P2)
**Status**: pending | **Priority**: P2 | **Parent**: 21.0
**Source**: `AUTONOMIC-SYSTEM-MASTER-PLAN.md`

#### 21.5.1 - Sensor Implementation (L5 Cortex) (P2)
**Status**: pending | **Priority**: P2 | **Parent**: 21.5

##### 21.5.1.1 - Queue Sensor
**Status**: pending | **Priority**: P2 | **Parent**: 21.5.1
- **Task**: Implement `Indrajaal.Cortex.Sensor.Queue`
- **Metric**: `vm.total_run_queue_lengths.total`

##### 21.5.1.2 - Latency Sensor
**Status**: pending | **Priority**: P2 | **Parent**: 21.5.1
- **Task**: Implement `Indrajaal.Cortex.Sensor.Latency`
- **Metric**: `phoenix.endpoint.stop.duration` (P99)
