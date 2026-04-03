# Integrated Analysis & Implementation: Fractal Mesh Architecture (SIL-6 Biomorphic)
**Version**: 2.0.0
**Date**: 2026-01-05
**Classification**: SAFETY-CRITICAL (SIL-6 Biomorphic)
**Status**: APPROVED FOR IMPLEMENTATION

## 1.0 Executive Summary

### 1.1 AS-IS State
*   **Architecture**: Single-node monolithic container set (`app`, `db`, `obs`).
*   **Orchestration**: Linear shell scripts.
*   **Compliance**: Partial SIL-2.
*   **Issues**: No redundancy (HFT=0), opaque startup, lack of transactionality during shutdown.

### 1.2 TO-BE State (Fractal Mesh)
*   **Architecture**: 3-Tier Fractal Topology (Dev, Cluster, Mesh).
    *   **Default**: Fractal Mesh (6 nodes: `db1`, `db2`, `obs`, `app-1`, `app-2`, `liveview`).
*   **Orchestration**: Biomorphic Supervisor (F# TUI) with OODA Loops.
*   **Compliance**: IEC 61508 SIL-6 Biomorphic (HFT=1 Redundancy).
*   **Visibility**: Real-time Digital Twin Dashboard.

## 2.0 5-Level Deep Analysis

### Level 1: Surface Topology & Configuration
*   **Dev Env**: Minimized footprint. `db` (Primary), `obs` (Lite), `app-1` (Seed).
*   **Cluster Env**: High-Availability Logic. `db` (Primary), `obs` (Full), `app-1` (Seed), `app-2` (Peer).
*   **Fractal Mesh**: Full Biomorphic Replica. `db1` (Primary), `db2` (Replica), `obs` (Central), `app-1`, `app-2`, `liveview`.
*   **Network**: 172.30.0.0/16 (Deterministic IP assignment).

### Level 2: Transaction Semantics (Startup/Shutdown)
*   **Atomic Startup**: `Preflight -> Data Plane -> Obs Plane -> Control Plane`.
*   **Atomic Shutdown**: `Drain -> Checkpoint -> Stop -> Verify`.
*   **Watchdog**: Elixir agent embedded in containers traps `SIGTERM`, enforces `CHECKPOINT` (DB) or `flush` (Obs), writes `shutdown_marker.json` to volume.

### Level 3: Cybernetic Control (OODA)
*   **Observe**: Zenoh streams & Health Checks (50ms interval).
*   **Orient**: Compare against `data/digital_twin_state.json`.
*   **Decide**: If `startup_time > 10s`, trigger `Jidoka` (Halt). If `db` unhealthy, pause `app`.
*   **Act**: Podman API commands via CEPAF.

### Level 4: Systemic Implications
*   **Resources**: Max Parallelization requires ~6 CPU cores during boot.
*   **Persistence**: Volume isolation (`fractal-db1-data` vs `fractal-db2-data`) prevents corruption.
*   **Security**: Capabilities Drop (`cap-drop: ALL`), Read-Only Root, Non-Root User.

### Level 5: Root Cause Prevention (Safety)
*   **Split Brain**: Prevented by Quorum check in Supervisor before `app` traffic enablement.
*   **Data Corruption**: Prevented by Watchdog 5-stage shutdown.
*   **Configuration Drift**: Prevented by `sil4_preflight_check.exs` hashing configs.

## 3.0 Implementation Specifications

### 3.1 Digital Twin & State
*   **File**: `data/digital_twin_state.json`
*   **Updates**: Written by Supervisor (F#) every cycle.
*   **Structure**:
    ```json
    {
      "mode": "fractal",
      "topology": ["db1", "db2", ...],
      "health_vector": {"db1": "healthy", ...},
      "last_heartbeat": "ISO8601"
    }
    ```

### 3.2 TUI App (Cockpitf Integrated)
*   **Language**: F# (scripting mode `fsx` for speed).
*   **Features**: ASCII Dashboard, Progress Bars, Log Tail, KPI Meters (Startup Time, Health %).
*   **Integration**: Wraps `podman-compose` commands.

## 4.0 STAMP & AOR Rules (5-Level Detail)

### 4.1 STAMP Safety Constraints (SC-FRACTAL)
*   **Level 1 (Topology)**: SC-FRACTAL-001 - The system SHALL NOT start unless the defined topology (Dev/Cluster/Fractal) is hash-verified against the local artifacts.
*   **Level 2 (Transactions)**: SC-FRACTAL-002 - EVERY container shutdown SHALL execute a `CHECKPOINT` signal before `SIGKILL`.
*   **Level 3 (Control)**: SC-FRACTAL-003 - The Supervisor SHALL trigger `Jidoka` (Emergency Halt) if any node health-check remains 'Pending' for > 15 seconds.
*   **Level 4 (Persistence)**: SC-FRACTAL-004 - The Digital Twin state file MUST be updated with a unique `transaction_id` for every state transition.
*   **Level 5 (Environmental)**: SC-FRACTAL-005 - Mesh containers SHALL run with `no-new-privileges` and a read-only root filesystem.

### 4.2 FMEA Risk Mitigation (FM-FRACTAL)
*   **Level 1 (Network)**: FM-FRACTAL-001 - **Failure**: Network Partition. **Mitigation**: Nodes enter 'Local Cache Mode' and retry sync every 2s.
*   **Level 2 (Data)**: FM-FRACTAL-002 - **Failure**: Primary DB Crash. **Mitigation**: Supervisor promotes Replica (DB2) to Primary and updates Apps.
*   **Level 3 (Observability)**: FM-FRACTAL-003 - **Failure**: Obs Container OOM. **Mitigation**: Apps throttle log volume until Obs health is restored.
*   **Level 4 (Orchestration)**: FM-FRACTAL-004 - **Failure**: Supervisor Crash. **Mitigation**: Watchdogs in containers maintain last-known-safe state.
*   **Level 5 (Security)**: FM-FRACTAL-005 - **Failure**: Unauthorized API call. **Mitigation**: All calls validated against the Twin's static config map.

### 4.3 TDG Verification Rules (TDG-FRACTAL)
*   **Level 1 (Unit)**: TDG-FRACTAL-001 - Verify F# record serialization to Digital Twin JSON.
*   **Level 2 (Mock)**: TDG-FRACTAL-002 - Simulate Podman API responses for all 6 nodes.
*   **Level 3 (Integration)**: TDG-FRACTAL-003 - Verify App-1 can reach DB-1 via container-internal DNS.
*   **Level 4 (Stress)**: TDG-FRACTAL-004 - Verify 10s SLA under 80% CPU load.
*   **Level 5 (Security)**: TDG-FRACTAL-005 - Verify `rm -rf` fails on read-only container root.

### 4.4 Agent Operating Rules (AOR-FRACTAL)
*   **Level 1 (Protocol)**: AOR-FRACTAL-001 - Agent SHALL use REST API for Podman interaction instead of raw CLI where feasible.
*   **Level 2 (Transparency)**: AOR-FRACTAL-002 - Agent SHALL display its "Thinking" trace in the Dashboard during the Decide phase of OODA.
*   **Level 3 (Atomicity)**: AOR-FRACTAL-003 - Agent SHALL NOT proceed to 'Control Plane' startup until 'Data Plane' is Healthy.
*   **Level 4 (Audit)**: AOR-FRACTAL-004 - Agent SHALL log every shell command exit code to the persistent audit log.
*   **Level 5 (Homeostasis)**: AOR-FRACTAL-005 - Agent SHALL auto-compact the Digital Twin state every 100 transitions.

## 4.0 Test Strategy
*   **Unit**: Verify TUI logic (Mock Podman).
*   **Integration**: Verify Mesh Gossip (App1 <-> App2).
*   **System**: Verify 10s SLA and Persistence across restarts.