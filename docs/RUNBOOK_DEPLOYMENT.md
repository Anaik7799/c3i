# C3I Deployment Runbook: SIL-6 Mesh Orchestration
**Task ID**: 1077fb77
**Compliance**: DAL-A / SIL-6 / SC-IGNITE-001
**Version**: 21.4.0-RUST-AUTH

This document defines the authoritative procedure for bootstrapping and maintaining the C3I Biomorphic Mesh using the Rust Ignition Daemon (`ignition`).

---

## 1. Authoritative Bootstrap Sequence (`./sa-up`)

The C3I mesh is managed by the Rust Ignition Daemon, which provides a high-assurance, multi-phase entry point for system boot.

### 1.1 Pre-Flight Checks (Phase 1)
Before ignition, the system runs 18 pre-flight checks:
- **Substrate Guard**: Validates Axiom 0.1/0.2 (no host `_build/deps` contamination).
- **NIF Integrity**: Ensures ELF binaries are compatible with the container runtime.
- **Dependency Map**: Verifies network, image, and database availability.

### 1.2 Multi-Wave Ignition (Phase 2)
To bootstrap the mesh:
```bash
./sa-up
```
This command triggers the Rust `full` sequence:
1.  **Cleanup**: Automatically identifies and force-removes "ghost" containers (stuck in `Stopping` state).
2.  **Wave 0-1**: Starts `indrajaal-db-prod` and `zenoh-router-1,2,3`.
3.  **Wave 2-4**: Starts observability, bridge, cortex, and application layers.
4.  **Adaptive Timeouts**: Uses EMA (Exponential Moving Average) build history to adjust boot windows.

### 1.3 Post-Launch Verification (Phase 3)
The system confirms homeostasis via:
- **14-Point Probe**: Verifies HTTP, TCP, Redis, and OODA checkpoints.
- **FPPS Consensus**: Uses 5-method voting (Running, Port, Endpoint, Quorum, Twin) to confirm node health.

---

## 2. Planning Cockpit Access

The Planning system operates independently of the mesh state to ensure management availability even during network partitions.

### 2.1 Unified Tools
- **High-Speed**: `./sa-gleam status` (2-tier fallback: NIF -> `sqlite3` CLI).
- **Authoritative**: `./sa-plan status` (F# master).

### 2.2 Shared State
Both tools read from the same source of truth:
`sub-projects/c3i/data/smriti/planning.db`

---

## 3. Observability & IPC

### 3.1 Zenoh Backplane
Verify the IPC layer:
```bash
./sa-gleam status
```
Look for `✅ Zenoh session active & status published.`

### 3.2 OTel Telemetry
Spans are exported to `http://localhost:4318`. Verify connectivity:
```bash
curl -I http://localhost:4318/v1/traces
```

---

## 4. Recovery Procedures

### 4.1 System Apoptosis (Teardown)
To purge the mesh and substrate contamination:
```bash
./sa-gleam down
rm -rf deps _build  # If Axiom 0.1 violations found
```

### 4.2 Selective Restart
```bash
./sa-gleam restart-node <container-name>
```

---
**Author**: Gemini CLI Executive
**Status**: ACTIVE
**Audit**: SC-IGNITE-001 Compliant
