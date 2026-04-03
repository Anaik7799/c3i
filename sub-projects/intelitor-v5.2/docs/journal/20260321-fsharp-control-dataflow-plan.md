# Plan: F#-Native Control & Dataflow Singularity (100% Fractal Coverage)

**Date**: 2026-03-21
**Status**: APPROVED
**Framework**: SIL-6 Biomorphic + Information Theory + L7 Fractal Matrix + Bicameral HMI

## 1. Executive Summary
This plan establishes a mathematically verified mechanism for achieving and sustaining **100% control path and dataflow coverage** in the F# kernel. By utilizing reflective discovery, high-entropy fuzzing, and biomorphic test vectors, the system will continuously explore its own logic branches across all fractal layers (L1-L7) during the continuous enterprise demo cycle. The results are visible in real-time via a unified Singularity Dashboard accessible through CEPAF TUI and Web UI via Tailscale FQDNs.

## 2. The Fractal Coverage Matrix (Elements x Layers x Paths)
Coverage is verified across the following dimensions:
*   **Elements**: Agents, Holons, Envelopes, Containers, Pods, Networks, DAGs.
*   **Layers**: L1 (Atomic) -> L7 (Federation).
*   **Paths**: All logic branches (control-flow) and all state transitions (dataflow).

## 3. Architecture & Implementation
### 3.1. Reflective Exploration Engine (`SingularityExplorer.fs`)
-   Dynamically scans the `Cepaf.*` AST and compiled DLLs.
-   Identifies all execution paths and data mutation endpoints.
-   Calculates the theoretical State Space size.

### 3.2. Formal Test Vectors via Zenoh
-   **Control Flow Vectors**: Emitted to `indrajaal/telemetry/paths/visited/{hash}`.
-   **Dataflow Vectors**: Emitted to `indrajaal/telemetry/dataflow/transitions/{src}/{dst}`.
-   These signals inform the broader Swarm that a formally verified test is in progress.

### 3.3. HMI Integration (TUI & Web UI)
-   **CEPAF TUI**: New `SingularityView` displaying coverage density and Jidoka status.
-   **F# Web UI**: Dedicated `/singularity` page with real-time vector visualization.

## 4. Access Protocol (Tailscale FQDNs)
The following paths provide secure, encrypted access to the singularity metrics:
*   **Prajna Web UI**: `http://prajna.indrajaal.tailscale:4001/singularity`
*   **CEPAF Bridge API**: `http://cepaf-bridge.indrajaal.tailscale:9876/telemetry/coverage`
*   **Zenoh Control Plane**: `http://zenoh-router.indrajaal.tailscale:8000/indrajaal/telemetry/paths/**`
*   **TUI Access**: `ssh user@indrajaal-ex-app-1.indrajaal.tailscale -t 'sa-mesh monitor'` (then press [S])

## 5. Demo Simulation & Jidoka
-   Periodic `PUT "sim-singularity"` signal issued by the demo executor.
-   **Jidoka Gate**: Autonomous halt if coverage drops below 100% or KL-Divergence exceeds threshold.

## 6. Mathematical Verification
-   Shannon Entropy (H) verification of path randomness.
-   KL-Divergence ($D_{KL}$) check between Intent and Realized Outcome.
