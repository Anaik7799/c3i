# SIL6 Mesh Startup & Shutdown: Comprehensive Analysis and Implementation Specification

**Version**: 2.0.0-Biomorphic
**Compliance**: SIL-6 Biomorphic (IEC 61508) | SC-SIL6-001
**SLA Targets**: Startup < 10s | Shutdown < 5s
**Orchestration Logic**: F# Category-Theory based CEPAF Cortex

## 1. Executive Summary
This document defines the transition from a "Shell-and-Wait" container model to a "Deterministic Biomorphic Fractal" orchestration system. By applying Google-scale "Lameduck" states, Automotive "Static Snapshots," and Linux "Socket Activation," we achieve a mesh that behaves as a single, fault-tolerant biological organism.

## 2. AS-IS Analysis (Current Approach)
- **Execution**: Asynchronous shell calls to `podman-compose`.
- **Determinism**: Zero. Success is inferred from process exit codes, which often lie if the internal service is still "boot-looping."
- **Observability**: Flat, disconnected logs. No "Flight Recorder" capability.
- **Issues**:
    - **Thundering Herd**: Parallel boot of DB and App causes immediate 503 errors and connection pool exhaustion.
    - **Entropy**: Container state drifts from host configuration without detection.
    - **Shutdown**: SIGKILL approach leads to uncommitted DB transactions and 2% packet loss during node churn.

## 3. Proposed Approach (TO-BE)
### 3.1 The Bicameral Controller Architecture
- **The Cortex (F# OptimalMesh)**: High-velocity actuator managing Kahn’s Algorithm for topological sorting.
- **The Guardian (SIL6 Validator)**: Mandatory logic gate. No command is executed without a cryptographic "Proof Token" verifying safety invariants.

### 3.2 Twin Architecture: The Digital Genotype
Every holon (container) is tracked via a formal data structure:
```fsharp
type HolonConfig = {
    Id: string; IP: string; Port: int; 
    Dependencies: string list; HealthEndpoint: string
}

type HolonTwin = {
    Genotype: HolonConfig; // The Plan
    Phenotype: RuntimeState; // The Actual
    Divergence: float; // Divergence Score
    Entropy: float; // Structural Disorder
}
```

## 4. Algorithmic Strategies & Data Flow
### 4.1 Startup: Wave-Based Dependency Parallelization
1. **PREFLIGHT**: Host-level socket probing. If port 5433 is blocked, abort immediately (Transaction Integrity).
2. **WAVE 1 (Persistence)**: Synchronous boot of `db-primary`. F# probes the REST API of Podman to verify "Healthy" status before proceeding.
3. **WAVE 2 (Control Plane)**: Parallel boot of `indrajaal-obs` and Zenoh bridges.
4. **WAVE 3 (Mesh Wave)**: Staggered boot of App nodes with **5-50ms Jitter** to prevent CPU spikes (Automotive/Windows philosophy).

### 4.2 Shutdown: The Lameduck Transition
1. **SIGNAL**: Broadcast `LAMEDUCK` over Zenoh Control Plane.
2. **DRAIN**: Load balancer moves traffic away. Holon enters "Drain Mode" but remains online.
3. **FLUSH**: Persistent agents (DB/OBS) flush circular buffers to disk.
4. **TEARDOWN**: Surgical container stop in reverse dependency order.

## 5. Transaction Behavior & Determinism
- **ACID Container Ops**: Every wave is a transaction. If a satellite node fails to stabilize, the Cortex triggers an automatic rollback of the wave.
- **Proof Tokens**: SIL6 requirement. Every transition (Off -> Starting -> Ready) is signed by the Guardian.

## 6. Telemetry: Zenoh Control Plane
- **Fractal Logging**: Level 1 (Local) to Level 5 (Ecosystem) logs.
- **Zenoh**: Used for high-frequency control plane state sync.
- **Sampling**: 0.1% for healthy flows; 100% for error-triggered circular buffer flushes (Google/Automotive way).