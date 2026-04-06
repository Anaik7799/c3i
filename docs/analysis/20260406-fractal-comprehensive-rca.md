# Fractal Comprehensive Root Cause Analysis (RCA) & System Improvement Matrix

**Date**: 20260406-1400 CEST
**Status**: ACTIVE
**Framework**: 5-Level RCA + SIL-6 Swarm + STAMP

## Executive Summary
Following the full system runtime testing, verification, and artifact synchronization, this Fractal RCA identifies critical structural vulnerabilities, implementation gaps, and systemic anomalies remaining within the Indrajaal c3i Biomorphic Mesh. While the core safety tests (Gleam: 2787, Rust: 352) passed, the orchestration and network layers exhibit significant weaknesses requiring immediate evolutionary targeting.

## Fractal Root Cause Analysis (L0 - L7)

### L0 Constitutional: Illusion of Formal Verification
- **Symptom**: The TLA+/Apalache formal verification gate currently passes all actions.
- **Root Cause (Level 5)**: The verification gate is purely simulated via a 50ms `setTimeout` in the `neuromorphic_script` injected into the UI, rather than executing a true mathematical model checker on the backend.
- **Improvement Action**: Implement actual Apalache bindings in the Rust backend (`/api/v1/graph/verify`) to compile the current state into TLA+ and mathematically prove transition safety before returning HTTP 200.

### L1 Atomic/Debug: Ephemeral Networking & DB Connections
- **Symptom**: Elixir `mix test` loop fails with `econnrefused` on `localhost:5433`.
- **Root Cause (Level 5)**: Rootless Podman network namespaces isolate the test runner from the host's port mappings, preventing the ephemeral BEAM processes from reaching the TimescaleDB instance.
- **Improvement Action**: Migrate the test runner to execute *inside* the `indrajaal-sil6-mesh` Podman network, rather than from the host, ensuring native DNS resolution and port access without relying on host-bound loopbacks.

### L3 Transaction: Concurrency Deadlocks in Planning Daemon
- **Symptom**: `planning_daemon` database tests fail sporadically with "database is locked" unless constrained to `RUST_TEST_THREADS=1`.
- **Root Cause (Level 5)**: The SQLite WAL mode implementation in `sa-plan-daemon` lacks sufficient connection pooling and backoff mechanisms to handle highly concurrent read/write test streams.
- **Improvement Action**: Implement a dedicated connection pooler (e.g., `deadpool-sqlite` or `r2d2`) with exponential backoff and jitter for SQLite transactions in the Rust planning daemon.

### L4 System: Mesh Connectivity Matrix Failure
- **Symptom**: `./sa-up verify` reports `1/28 reachable, 27 failed` in the inter-container connectivity matrix.
- **Root Cause (Level 5)**: Containers are booting faster than the Zenoh routers can establish their gossip convergence, and the Podman DNS bridge is dropping initial TCP connections.
- **Improvement Action**: Introduce a deterministic readiness probe (L1) for Zenoh convergence. The `ignition` daemon must wait for cryptographic proof of router convergence before attempting to verify inter-container HTTP/TCP sockets.

### L6 Ecosystem: Zero-IP Identity Routing Incomplete
- **Symptom**: `indrajaal-ex-app-1` and `indrajaal-cortex` still experienced an IPAM collision over `172.28.0.10`, which required a hardcoded bypass in `launch.rs`.
- **Root Cause (Level 5)**: The system still fundamentally relies on the Podman bridge subnet (`172.28.0.0/16`) rather than fully offloading transport to the Zenoh overlay network.
- **Improvement Action**: Completely eliminate `--ip` and `--network` flags from the ignition daemon. Force all inter-container traffic through the `zenoh_router_plugin` using Zero-IP Identity (ZID) routing, rendering IPAM collisions mathematically impossible.

## Next Evolutionary Targets
1. **True TLA+ Backend Integration**: Eradicate UI simulation; enforce backend mathematical safety.
2. **Zenoh-Native Networking**: Deprecate Podman bridge networks in favor of pure Zenoh overlay routing.
3. **SQLite Concurrency Hardening**: Refactor `sa-plan-daemon` connection pooling.
4. **Test Environment Containerization**: Move all `mix test` and `gleam test` executions directly into the mesh namespace.