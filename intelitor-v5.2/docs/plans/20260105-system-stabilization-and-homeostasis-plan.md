# Plan: System Stabilization and Homeostasis Restoration (v21.3.0)

**Created**: 20260105-1030 CEST
**Last Updated**: 20260105-1030 CEST
**Status**: IN PROGRESS
**Framework**: SOPv5.11 + SIL-6 Biomorphic Mesh + Fast OODA
**Architecture**: 6-Node Fractal Cluster

---

## 1.0 Executive Summary
Following a **Deep Substrate Scour**, the Indrajaal system is in a **Total Void State**. This plan orchestrates the transactional re-materialization of the **Fractal Mesh** genotype. Every stage is verified by the F# CEPAF Cortex using **2oo3 Voting** and **FPPS 5-Method Consensus**. The ultimate goal is to achieve **Homeostasis** where the system autonomously maintains its safety envelope and functional invariant (Axiom 0).

---

## 2.0 Change Log
| Timestamp | Change Type | Description | Author |
|-----------|-------------|-------------|--------|
| 20260105-1030 CEST | CREATED | Initial restoration plan post-scour | Cybernetic Supervisor |

---

## 3.0 5-Level Detailed Plan

### 3.1 - Strategic Objective: Restore SIL-6 Fractal Mesh (Priority: P0)

#### 3.1.1 - Phase 1: Substrate Materialization (Priority: P0)
##### 3.1.1.1 - Network Plane Reconstitution
- 3.1.1.1.1 - Create `intelitor-v52_fractal-mesh` bridge (172.30.0.0/16) (Priority: P0)
- 3.1.1.1.2 - Verify IPAM isolation and DNS resolution (Priority: P0)

##### 3.1.1.2 - Data Plane Ignition
- 3.1.1.2.1 - Boot `indrajaal-db1` (Primary primary) (Priority: P0)
- 3.1.1.2.2 - Verify `pg_isready` and TimescaleDB extension (Priority: P0)
- 3.1.1.2.3 - Boot `indrajaal-db2` (Hot replica) (Priority: P1)
- 3.1.1.2.4 - Establish streaming replication lag < 10ms (Priority: P1)

##### 3.1.1.3 - Observability Plane Link
- 3.1.1.3.1 - Boot `indrajaal-obs` (OTEL + SigNoz) (Priority: P0)
- 3.1.1.3.2 - Verify 4317 (gRPC) and 4318 (HTTP) readiness (Priority: P0)
- 3.1.1.3.3 - Establish Quadplex Logger state persistence (Priority: P1)

##### 3.1.1.4 - Control Plane Convergence
- 3.1.1.4.1 - Boot `indrajaal-app-1` (Seed node) (Priority: P0)
- 3.1.1.4.2 - Boot `indrajaal-app-2` (Join node) (Priority: P0)
- 3.1.1.4.3 - Verify `libcluster` formation (Quorum > 1) (Priority: P0)

#### 3.1.2 - Phase 2: Logic & Safety Convergence (Priority: P0)
##### 3.1.2.1 - F# Cortex Synchronization
- 3.1.2.1.1 - Link CEPAF Port Handler to Elixir Guardian (Priority: P0)
- 3.1.2.1.2 - Synchronize Digital Twin state structure (Priority: P0)

##### 3.1.2.2 - Safety Plane Activation
- 3.1.2.2.1 - Perform initial STAMP safety constraint audit (Priority: P0)
- 3.1.2.2.2 - Execute 2oo3 Voting on system genesis state (Priority: P0)

#### 3.1.3 - Phase 3: Homeostatic Awakening (Priority: P1)
##### 3.1.3.1 - Immune System Initialization
- 3.1.3.1.1 - Launch Sentinel Heartbeat loop (30s interval) (Priority: P1)
- 3.1.3.1.2 - Enable Antibody pattern matching for substrate anomalies (Priority: P1)

#### 3.1.4 - Phase 4: Intelligence & UI Link (Priority: P1)
##### 3.1.4.1 - C3I Cockpit Activation
- 3.1.4.1.1 - Boot `indrajaal-liveview` (Dashboard holon) (Priority: P1)
- 3.1.4.1.2 - Establish Zenoh real-time telemetry stream to UI (Priority: P1)

#### 3.1.5 - Phase 5: Continuous Homeostasis (Priority: P0)
##### 3.1.5.1 - OODA Supervisor Handoff
- 3.1.5.1.1 - Enable OodaSupervisor (100ms cycle time) (Priority: P0)
- 3.1.5.1.2 - Set Redline thresholds for metabolic scaling (Priority: P1)

---

## 4.0 Success Criteria
1. **Quorum**: 3/3 container planes (Data, Obs, Control) reporting HEALTHY.
2. **Connectivity**: Low-latency mesh communication verified between all 6 nodes.
3. **Safety**: Zero STAMP constraint violations at boot.
4. **Latency**: OODA cognitive loop < 30ms.
5. **Observability**: 100% of telemetry flowing to Quadplex backends.

---

## 5.0 Risk Assessment (5-Level RCA)
- **Hazard**: Startup Deadlock (L1)
- **Proximate Cause**: Port conflict or IPAM exhaustion (L2)
- **Contributing Factor**: Residual networks from legacy executions (L3)
- **Mitigation**: Nuclear Scour (sa-clean + podman prune) before ignition (L4)
- **Root Cause Prevention**: Transactional boot sequence with pre-flight verification (L5)
