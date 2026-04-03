# GUIDE: Sovereign System Stabilization & Homeostasis (v21.3.0-SIL6)

**Version**: 21.3.0-SIL6
**Last Updated**: 2026-01-11
**Classification**: L5-SPINE (Operational Manual)
**Framework**: SIL-6 Biomorphic Fractal Mesh
**Compliance**: IEC 61508 SIL-6, ISO 27001, GDPR, EN 50131, DO-178C DAL-A
**Orchestrator**: F# CEPAF (`sa-stabilize.fsx`)

---

## 1.0 THE "WHAT": System State Definition
When the system is in **Homeostasis**, it is a **6-Node Biomorphic Fractal Mesh** running on a **NixOS/Podman Substrate**.

### 1.1 Architecture (The Anatomy)
*   **Substrate**: Podman 5.4.1+ (Rootless).
*   **Network**: `intelitor-v52_fractal-mesh` (172.30.0.0/16).
*   **Nodes (Holons)**:
    1.  `indrajaal-db1`: Primary Data Store (PostgreSQL/TimescaleDB).
    2.  `indrajaal-db2`: Hot Replica (Streaming Replication).
    3.  `indrajaal-obs`: Senses (OTEL, SigNoz, Zenoh).
    4.  `indrajaal-app-1`: Seed Control Node (Phoenix/Elixir).
    5.  `indrajaal-app-2`: Join Control Node (Phoenix/Elixir).
    6.  `indrajaal-liveview`: Interface/Cockpit Node.

### 1.2 Dataflow (The Circulatory System)
*   **Quadplex Telemetry**: All nodes emit 4 streams:
    *   **Console**: ANSI logs for human operators.
    *   **File**: Persistent audit trail in `data/kms/`.
    *   **Zenoh**: Low-latency (<10ms) control plane signals.
    *   **OTEL**: High-volume metrics/traces to `indrajaal-obs`.
*   **Replication**: `db1` → `db2` (WAL Streaming).
*   **Distribution**: `app-1` ↔ `app-2` ↔ `liveview` via Erlang Distribution (`libcluster`).

### 1.3 Control Flow (The Nervous System)
*   **Fast OODA Loop**: The F# Cortex (`sa-status`, `sa-health`) polls the mesh every 100ms-10s.
*   **Decision Logic**:
    *   If **Healthy** → Maintain.
    *   If **Drift** → Alert.
    *   If **Failure** → Apoptosis (Kill & Restart).
*   **Axiom 0**: The functional invariant is checked *before* any mutation.

---

## 2.0 THE "HOW": Execution Protocol

### 2.1 The "God Command"
To stabilize the system from **ANY** state (broken, partial, or fresh), execute:

```bash
dotnet fsi sa-stabilize.fsx
```

### 2.2 What the Script Does (The Magic)
1.  **Phase 1: Apoptosis (Scour)**: It assumes the environment is hostile. It force-removes all containers, pods, and networks. It creates a **Void State**.
2.  **Phase 2: Genotype Alignment**: It ensures the Localhost Registry is up and images are correctly tagged (`latest`).
3.  **Phase 3: Ignition**: It invokes `sa-up.fsx` to transactionally boot the `podman-compose-fractal-mesh.yml`.
4.  **Phase 4: Convergence**: It waits for metabolic awakening and verifies 3/3 quorum.

---

## 3.0 THE "MUST NOT": Safety Constraints
*   **NEVER** use `docker-compose`. It ignores the SIL-6 safety envelopes.
*   **NEVER** manually start containers with `podman run`. Use the orchestrator.
*   **NEVER** ignore the **Dashboard**. If `sa-status` shows red, stop and fix.

---

## 4.0 Verification & Maintenance
*   **Check Health**: `dotnet fsi sa-health.fsx`
*   **View Dashboard**: `dotnet fsi sa-status.fsx --watch`
*   **Shutdown**: `dotnet fsi sa-down.fsx` (Graceful drain)

This guide guarantees a replicable, bulletproof path to system stability.

---

## Related Documents
- [USER_OPERATIONS_GUIDE.md](USER_OPERATIONS_GUIDE.md) - User command reference
- [SYSTEM_ONTOLOGY.md](SYSTEM_ONTOLOGY.md) - System ontology
- [COMPREHENSIVE_ARCHITECTURE_IMPLEMENTATION.md](COMPREHENSIVE_ARCHITECTURE_IMPLEMENTATION.md) - Architecture details
- [UNIFIED_SYSTEM_GUIDE.md](UNIFIED_SYSTEM_GUIDE.md) - Unified system guide
- [SYSTEM_INTUITION_5LEVEL_GUIDE.md](SYSTEM_INTUITION_5LEVEL_GUIDE.md) - 5-level understanding guide
