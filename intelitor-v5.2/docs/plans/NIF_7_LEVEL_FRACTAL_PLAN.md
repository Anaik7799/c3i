# NIF 7-Level Fractal Plan: Biomorphic Convergence

**Version**: 1.0.0
**Date**: 2026-01-06
**Status**: ACTIVE
**Compliance**: SIL-6, STAMP, VTO

## Executive Summary
This plan defines the lifecycle and interaction model for Native Implemented Functions (NIFs) within the Indrajaal ecosystem, specifically targeting **Zenoh** (Control Plane Telemetry) and **LineageAuth** (Biomorphic Security). It ensures "Bulletproof" robustness through 7 fractal levels of integration.

---

## The 7 Fractal Levels

### Level 1: Cellular (Atomic Code)
**Scope**: Rust Source Code (`native/`)
- **Objective**: Memory safety, zero-cost abstractions.
- **Verification**: `cargo test`, `clippy`, `rustfmt`.
- **Constraint**: Must compile with `x86_64-unknown-linux-gnu` (host) and `musl` (container).

### Level 2: Tissue (Elixir Binding)
**Scope**: Elixir Modules (`Indrajaal.Native.Zenoh`, `Indrajaal.Safety.LineageAuth`)
- **Objective**: Fault isolation, crash protection.
- **Verification**: Unit tests ensuring NIF load, fallback to stubs if missing (graceful degradation).
- **Constraint**: Must verify checksum of loaded NIF binary.

### Level 3: Organ (Process Integration)
**Scope**: GenServers (`Zenoh.Publisher`, `LineageAuth.Validator`)
- **Objective**: Lifecycle management, state holding.
- **Verification**: OTP supervision, restart strategies.
- **Constraint**: NIF crashes must be trapped; use `Dirty Schedulers` for long ops.

### Level 4: System (Container/Pod)
**Scope**: `indrajaal-app` Container
- **Objective**: Runtime environment, dependency availability.
- **Verification**: Container health checks, VTO probes.
- **Constraint**: `LIBCLANG_PATH`, `RUST_SRC_PATH` must be present.

### Level 5: Organism (Node)
**Scope**: Host Node / VM
- **Objective**: Resource allocation, hardware mapping.
- **Verification**: CPU/RAM usage monitoring during NIF bursts.
- **Constraint**: No resource starvation of BEAM schedulers.

### Level 6: Population (Cluster/Mesh)
**Scope**: Fractal Mesh (Tailscale/Libcluster)
- **Objective**: Distributed state, consensus.
- **Verification**: Zenoh Pub/Sub across nodes.
- **Constraint**: NIFs must respect network partitions (CAP theorem).

### Level 7: Ecosystem (Federation)
**Scope**: Global Indrajaal Network
- **Objective**: Evolutionary adaptation, biomorphic feedback.
- **Verification**: Long-term stability, memory leak analysis.
- **Constraint**: Updates to NIFs must be backward compatible (rolling upgrades).

---

## Implementation Strategy

1.  **Toolchain Injection**: Use `devenv` to inject `rustc`, `cargo`, `clang` into the container build path.
2.  **Verbose Compilation**: Force `RUST_BACKTRACE=1` and verbose Cargo logs during startup.
3.  **Quadplex Telemetry**: Emit NIF status to Console, File, Telemetry, and Zenoh.
4.  **5-Layer Testing**: Implement strict testing gates for L1-L5.

## 5-Layer Test Specification

| Layer | Type | Description | Tool |
| :--- | :--- | :--- | :--- |
| **L1** | **Unit** | Verify NIF binary loads and exports functions | `ExUnit` |
| **L2** | **Integration** | Test Rust logic via Elixir interface | `ExUnit` + `Rustler` |
| **L3** | **System** | Verify Zenoh connectivity in container | `ExUnit` (Network) |
| **L4** | **Stress** | Loop NIF calls (10k iterations) | `Benchee` |
| **L5** | **Safety** | Fuzz inputs, check for crash dumps | `PropCheck` |

---

**Signed**: Gemini (Cybernetic Architect)
