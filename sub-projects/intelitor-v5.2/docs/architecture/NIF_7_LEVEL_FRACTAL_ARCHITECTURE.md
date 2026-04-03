# NIF 7-Level Fractal Architecture: The Biomorphic Bridge

**Version**: 1.0.0
**Date**: 2026-01-06
**Status**: ACTIVE
**Compliance**: SIL-6, STAMP, VTO
**Reference**: `docs/architecture/MASTER_CONTAINER_ARCHITECTURE_20251222.md`

## Executive Summary
This document defines the **7-Level Fractal Architecture** for Native Implemented Functions (NIFs) within the Indrajaal ecosystem. It treats NIFs not as external foreign bodies, but as **Biomorphic Organs** integrated deeply into the system's metabolic processes. The architecture ensures that high-performance Rust code (Zenoh, LineageAuth) operates with the same safety, observability, and resilience guarantees as the managed BEAM environment.

---

## The 7 Fractal Levels

### Level 1: Cellular (Atomic Code)
**Scope**: Rust Source Code (`native/`)
- **Definition**: The raw genetic material of the NIF.
- **Responsibilities**: Memory safety (Rust ownership), zero-cost abstractions, panic handling (via `catch_unwind`).
- **Safety Constraint**: **SC-NIF-L1**: No panic may ever cross the FFI boundary. All Rust panics must be trapped and converted to `{:error, reason}` tuples.
- **Verification**: `cargo test`, `clippy`, `rustfmt`.

### Level 2: Organelle (Resource Management)
**Scope**: Rustler Resource Arcs (`ResourceArc<T>`)
- **Definition**: The binding layer that wraps native structs in ref-counted BEAM terms.
- **Responsibilities**: Deterministic cleanup (Drop traits), concurrent access control (RwLock/Mutex), scheduler cooperation.
- **Safety Constraint**: **SC-NIF-L2**: All long-running NIFs (>1ms) MUST run on Dirty Schedulers (`DirtyCpu` or `DirtyIo`).
- **Verification**: Leak analysis, Scheduler throughput metrics.

### Level 3: Organ (Elixir Module)
**Scope**: Elixir Wrapper (`Indrajaal.Native.Zenoh`)
- **Definition**: The functional interface exposed to the system.
- **Responsibilities**: API ergonomics, error translation, fallback strategies (stubs when NIF missing).
- **Safety Constraint**: **SC-NIF-L3**: The module MUST provide a `check_nif_loaded/0` function and handle `:nif_not_loaded` gracefully during boot.
- **Verification**: Unit tests (`L1_NifUnitTest`), DocTests.

### Level 4: System (Process Integration)
**Scope**: GenServers (`Zenoh.Publisher`, `LineageAuth.Validator`)
- **Definition**: The active process managing the NIF's lifecycle.
- **Responsibilities**: State holding, supervision, message routing, backpressure.
- **Safety Constraint**: **SC-NIF-L4**: NIF crashes must be isolated. The owning process should crash and restart without taking down the node.
- **Verification**: Integration tests (`L2_NifIntegrationTest`), OTP Supervision tree analysis.

### Level 5: Organism (Container Node)
**Scope**: `indrajaal-app` Container
- **Definition**: The runtime environment hosting the NIF.
- **Responsibilities**: Dynamic linking (`.so` loading), toolchain availability (`cargo`, `libclang`), resource limits (cgroups).
- **Safety Constraint**: **SC-NIF-L5**: The container MUST provide a chemically pure build environment (Nix store) to prevent ABI mismatches (`glibc` vs `musl`).
- **Verification**: System tests (`L3_NifSystemTest`), VTO Probes.

### Level 6: Colony (Fractal Mesh)
**Scope**: Distributed Cluster (Tailscale)
- **Definition**: The interaction of NIF-enabled nodes across the network.
- **Responsibilities**: Zenoh Pub/Sub mesh, distributed consensus (LineageAuth signatures).
- **Safety Constraint**: **SC-NIF-L6**: NIFs must handle network partitions and latency without blocking the control plane.
- **Verification**: Stress tests (`L4_NifStressTest`), Network partition simulations.

### Level 7: Ecosystem (Autonomic Plane)
**Scope**: Global Federation (Cortex/Guardian)
- **Definition**: The self-healing, evolutionary intelligence governing the system.
- **Responsibilities**: Anomaly detection (via NIF telemetry), automated rollbacks, performance tuning.
- **Safety Constraint**: **SC-NIF-L7**: The system must detect "Metabolic Drift" (memory leaks, CPU spikes) caused by NIFs and trigger Apoptosis (restart) if needed.
- **Verification**: Safety/BDD tests (`L5_NifSafetyTest`), Long-running soak tests.

---

## Implementation Approach: The "Zenoh Pattern"

We adopt the **Zenoh Pattern** as the gold standard for NIFs:
1.  **Hybrid Toolchain**: Inject `cargo` via Nix for deterministic builds.
2.  **Lazy Compilation**: Check for pre-compiled artifacts; if missing, compile on boot (Patient Mode).
3.  **Quadplex Telemetry**: Emit health signals to Console, File, Prometheus, and Zenoh itself.
4.  **Bulletproof Wrappers**: Use `try/rescue` blocks around NIF calls in the Elixir layer to catch any unforeseen crashes.

**Signed**: Gemini (Cybernetic Architect)