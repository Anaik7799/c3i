# Indrajaal HA + FLAME Hybrid Architecture Specification (v1.2.0)

**Classification**: 🛡️ IMMUTABLE ARCHITECTURE AXIOMS
**Status**: APPROVED FOR IMPLEMENTATION
**Framework**: SOPv5.1 + STAMP + HA-Mesh + Tailscale + FLAME
**Date**: 2025-12-17

---

## 1.0 Executive Summary

This specification defines the "Hybrid Core-Satellite" architecture for `Indrajaal`. It combines the resilience of the **Tailscale HA Mesh** (Core) with the elasticity of **FLAME Serverless Runners** (Satellites).

**Strategic Shift**:
*   **Previous**: "Scale Out" (Add more permanent nodes to the cluster).
*   **New**: "Scale Up/Down On-Demand" (Spin up ephemeral nodes for specific operations).

### 1.1 Core Axioms
1.  **Core is Persistent**: The 3-node HA Mesh (Control Plane) never scales to zero. It manages state, routing, and websockets.
2.  **Compute is Ephemeral**: Heavy compute tasks (ML, ETL, Video) run on FLAME nodes that exist *only* for the duration of the task.
3.  **Identity is Network**: Tailscale secures the Core; FLAME secures the Parent-Child link (or runs within the Tailnet context).

---

## 2.0 Infrastructure Topology

### 2.1 The Two Planes

| Plane | Component | Scaling | Role |
| :--- | :--- | :--- | :--- |
| **Control Plane** (Core) | **Indrajaal App** (x3) | Static HA | HTTP/WS handling, PubSub hub, Cluster Sentinel, DB Connection Pool. |
| **Compute Plane** (Satellites) | **FLAME Runners** | Elastic (0 to $\infty$) | "Heavy Lifting": ML Inference, Video Transcoding, Report Generation. |

### 2.2 Container Role Expansion

| Component | Role | Connectivity |
| :--- | :--- | :--- |
| **App Node** | Parent | Tailscale Mesh (Full Access) |
| **FLAME Runner** | Child | Ephemeral Link to Parent (via FLAME Backend) |
| **PgBouncer** | Middleware | Tailscale IP |
| **TimescaleDB** | State | Tailscale IP |

---

## 3.0 FLAME Integration Strategy

### 3.1 Domain Segmentation
We will "FLAME-ify" specific domains by wrapping their entry points in `FLAME.call/3`.

| Domain | Operation | Workload Type | Pool Strategy |
| :--- | :--- | :--- | :--- |
| **Intelligence** | `analyze_threat/1` | CPU Intensive (ML) | `min: 0, max: 10`, High CPU Runners |
| **Video** | `process_stream/1` | Memory/CPU Intensive | `min: 0, max: 20`, GPU Runners (future) |
| **Analytics** | `generate_report/1` | Memory Intensive | `min: 0, max: 5`, High RAM Runners |
| **Maintenance** | `run_backup/0` | I/O Intensive | `min: 0, max: 2` |

### 3.2 Code Pattern (The "Flame Pattern")
All heavy operations MUST follow this pattern to ensure they run locally in Dev/Test but remotely in Prod:

```elixir
def analyze_threat(data) do
  FLAME.call(Indrajaal.FLAME.IntelligencePool, fn ->
    # This code runs on the ephemeral runner
    Indrajaal.Intelligence.Engine.run_inference(data)
  end)
end
```

---

## 4.0 Control Flow & Lifecycle

### 4.1 Execution Path (FLAME Call)
1.  **Request**: User hits API (on Core Node A).
2.  **Decision**: `Intelligence` domain determines task is heavy.
3.  **FLAME Trigger**: Calls `FLAME.call(IntelligencePool, func)`.
4.  **Backend Action**:
    *   **Dev**: Spawns local process (immediate).
    *   **Prod (K8s)**: Calls K8s API -> Schedules Pod -> Pod Boots -> Connects to Parent.
5.  **Execution**: Function runs on Child Node.
6.  **Return**: Result sent back to Parent Node A.
7.  **Teardown**: Child Node terminates after `idle_shutdown_after` (e.g., 30s).

### 4.2 State Safety (STAMP SC-FLM-001)
*   **Constraint**: FLAME Runners **MUST NOT** rely on local state (ETS/Process Dictionary) persisting between calls.
*   **Constraint**: FLAME Runners **MUST** fetch fresh state from DB (via Tailscale/PgBouncer) or accept all context as arguments.

---

## 5.0 SRE & Failure Modes

### 5.1 Scenario: FLAME Runner Crash
*   **Event**: Child node OOMs or crashes during `FLAME.call`.
*   **Outcome**: The `FLAME.call` raises an exception in the Parent.
*   **Recovery**: Parent catches exception, logs telemetry, and returns error (or retries locally if configured). Core system remains stable.

### 5.2 Scenario: Backend Starvation
*   **Event**: K8s cluster full, cannot schedule Runner.
*   **Outcome**: `FLAME.call` times out.
*   **Mitigation**: Configure `FLAME.Pool` with `timeout` and fallback strategies (e.g., `run_local_on_timeout: false` to protect Core).

---

## 6.0 Implementation Plan

- [ ] **1. Dependencies**
    - [ ] Add `{:flame, "~> 0.5"}` to `mix.exs`.
    - [ ] Add `{:flame_k8s_backend, "~> 0.5"}` (for Prod).

- [ ] **2. Configuration**
    - [ ] Define Pools in `application.ex`:
        *   `Indrajaal.FLAME.IntelligencePool`
        *   `Indrajaal.FLAME.VideoPool`
        *   `Indrajaal.FLAME.AnalyticsPool`
    - [ ] Configure `runtime.exs` for FLAME Backend selection.

- [ ] **3. Refactoring**
    - [ ] Identify "Heavy" functions in Domains.
    - [ ] Wrap logic in `FLAME.call`.

- [ ] **4. Infrastructure**
    - [ ] Ensure `ServiceAccount` in K8s has permissions to spawn Pods.
    - [ ] Ensure Runner Container image is optimized for fast boot (AOT compilation).

---

**Approval**:
*   **Scalability**: Validated against SC-PERF-056 (Elastic Scaling).
*   **Safety**: Validated against SC-STABILITY-001 (Core Isolation).
