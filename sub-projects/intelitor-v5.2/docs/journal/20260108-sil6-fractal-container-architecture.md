# Journal: SIL-6 Biomorphic Fractal Container Architecture

**Date**: 2026-01-08
**Author**: Cybernetic Architect (Gemini)
**Classification**: ARCHITECTURAL DECISION RECORD (ADR)
**Status**: ACTIVE / MANDATORY

## 1.0 Executive Summary
This entry documents the transition to the **SIL-6 Biomorphic Fractal Mesh** architecture (v21.3.0). We have moved beyond simple container orchestration to a fully verifying, self-healing, biological system model. All container operations are now encapsulated within the **F# Cortex (CEPAF)** to ensure type safety, formal verification, and biomorphic feedback loops.

## 2.0 The 7-Level Fractal Analysis
We have decomposed the system into 7 fractal levels, each with specific verification and interaction mandates.

| Level | Component | Scope | Verification Logic (F#) | Interaction Implication |
|---|---|---|---|---|
| **L7** | **Federation** | Global State | `ImmutableState.verify_chain` | Cross-holon data integrity and lineage attestation. |
| **L6** | **Cluster** | Consensus | `DigitalTwin.checkQuorum` | 2oo3 voting ensures no split-brain scenarios. |
| **L5** | **Node** | Runtime Env | `BootSequence.runBios` | Host substrate cleaning (port scouring) ensures boot viability. |
| **L4** | **Container** | Isolation | `Checkpoints.verifyContainer` | Strict resource limits and rootless execution enforce security. |
| **L3** | **Holon** | Agent Logic | `Biomorphic.assessHomeostasis` | Agents act as autonomic cells; failure triggers immune response. |
| **L2** | **Component** | Services | `Checkpoints.buildImage` | Sidecars (Zenoh, PHICS) provide nervous system connectivity. |
| **L1** | **Function** | Contracts | `Telemetry.log` | Every operation emits typed telemetry for OODA loop consumption. |
| **L0** | **Runtime** | Execution | `Shell.execSilent` | Low-level shell interactions are wrapped in safe, observable F# functions. |

## 3.0 Operational Mandates (Usage Instructions)

### 3.1 The "F# Only" Rule
**CRITICAL**: Raw `podman` or `podman-compose` commands are now **FORBIDDEN** for standard operations. They bypass the safety checks and telemetry streams of the Cortex.

### 3.2 Boot Sequence (The "One Command")
To bring the system to the SIL-6 Homeostasis state:

```bash
dotnet fsi lib/cepaf/scripts/SIL6HomeostasisOrchestrator.fsx boot
```

**What happens:**
1.  **S0 (BIOS)**: Scours ports (kill stale PIDs), removes stale containers, verifies config.
2.  **S1 (PROVISION)**: Builds/Pulls images into `localhost/` registry. **Offline capable.**
3.  **S2 (KERNEL)**: Starts Database layer. Verifies persistence health.
4.  **S3 (INIT)**: Starts App & Observability layers.
5.  **S4 (HOMEOSTASIS)**: Checks Cluster Quorum and Biomorphic Health.

### 3.3 System Cleaning
To reset the environment (preserves data volumes):

```bash
dotnet fsi lib/cepaf/scripts/SIL6HomeostasisOrchestrator.fsx clean
```

## 4.0 Biomorphic Robustness Features
1.  **Active Self-Healing**: The Orchestrator doesn't just fail on port conflicts; it identifies the PID and kills it (`scourPort`).
2.  **Verify-Then-Orchestrate (VTO)**: Images are verified (built/pulled) *before* the run command is issued.
3.  **Linux-Boot Style Telemetry**: High-visibility, colored console output provides immediate situational awareness.
4.  **Digital Twin**: An in-memory representation of the expected vs. actual state drives decision making.

## 5.0 Next Steps
- Implement full `ReedSolomon` repair for L7 state.
- Connect `ZenohControlPlane` to the live Zenoh router.
- Expand `Biomorphic` module with real CPU/Memory pressure sensors.
