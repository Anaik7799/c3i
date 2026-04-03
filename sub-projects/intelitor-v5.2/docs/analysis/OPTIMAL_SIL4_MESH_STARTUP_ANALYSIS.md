# OPTIMAL SIL6 MESH STARTUP & SHUTDOWN: 5-Level Analysis & Architecture

**Date**: 2026-01-04
**Author**: Cybernetic Architect (Gemini)
**Classification**: SAFETY-CRITICAL (SIL-6 Biomorphic)
**Status**: VERIFIED IMPLEMENTATION

## 1.0 Executive Summary

This document defines the **Optimal SIL-6 Biomorphic Compliant Mesh Startup and Shutdown** strategy for the Indrajaal system. It establishes a unified, biomorphic, and transaction-oriented approach to managing the lifecycle of the fractal mesh across three distinct environments: **Dev**, **Cluster**, and **Fractal**.

**Core Mandate**: The system MUST prioritize safety (SIL-6 Biomorphic) over availability during state transitions. A partial or corrupted mesh MUST NOT be allowed to reach a "Healthy" state.

## 2.0 5-Level Deep Analysis (RCA & TPS)

### 2.1 Level 1: Surface (The Symptom)
*   **Current State**: Startup was monolithic. Failures in satellites were detected late.
*   **Target**: 10s SLA for mesh readiness. Granular control over topology.

### 2.2 Level 2: Proximate (The Mechanism)
*   **Issue**: `podman-compose` handles dependencies implicitly, leading to race conditions.
*   **Solution**: Explicit **Wave-Based Orchestration** implemented in F# (`MeshStartup.fs`). Wave 0 (Infra) -> Wave 1 (Seed) -> Wave 2 (Satellites).

### 2.3 Level 3: Contributing (System Design)
*   **Issue**: Lack of "Digital Twin" awareness during boot.
*   **Solution**: Hydrate `HealthCoordinator` and `ContainerLifecycleManager` *before* and *during* boot. Maintain a live **Digital Twin** state.

### 2.4 Level 4: Systemic (Architecture)
*   **Issue**: Tightly coupled shell scripts (`sa-up.sh`) were brittle.
*   **Solution**: Full migration to **F# SIL-6 Biomorphic Mesh Controller** (`SIL6MeshCLI.fs`).
*   **Requirement**: Introduce **Transaction Semantics**. Boot sequence is a transaction: `Begin -> Scour -> Boot Infra -> Boot Seed -> Boot Sats -> Commit`. Failure = `Rollback`.

### 2.5 Level 5: Root Cause (Philosophy)
*   **Issue**: The system was treated as a "machine" to be started, not an "organism".
*   **Solution**: **Biomorphic Scaling**. The mesh "wakes up" (Infrastructure), "gains consciousness" (Seed/Quorum), and then "grows" (Satellites).

## 3.0 Architecture: The Fractal Mesh Controller

### 3.1 Topology Modes
| Mode | Scope | Containers | Use Case |
|------|-------|------------|----------|
| **DEV** | Minimal | `db-primary`, `obs`, `app-1` | Fast code iteration, Unit tests |
| **CLUSTER** | HA Pair | `db-primary`, `obs`, `app-1`, `app-2` | Replication testing, Failover |
| **FRACTAL** | Full Mesh | `db-primary`, `obs`, `app-1`, `app-2`, `app-3` | Production simulation, Load test |

### 3.2 Transaction Protocol (SLA < 10s)
1.  **PREFLIGHT**: Scour ports (kill lingering PIDs).
2.  **WAVE 0 (Infra)**: Start DB & Obs.
    *   *Optimization*: Sequential to prevent Pod race (Wave 0.1 DB -> Wave 0.2 Obs).
3.  **WAVE 1 (Seed)**: Start `app-1`.
    *   *Gate*: Must connect to DB & Obs.
4.  **WAVE 2 (Growth)**: Start `app-2`, `app-3` (based on mode).
    *   *Gate*: Must peer with `app-1`.
5.  **VERIFY**: Check Quorum (N/2 + 1).
6.  **COMMIT**: Mark System HEALTHY.

### 3.3 Digital Twin Integration
The `HealthCoordinator` acts as the Digital Twin source of truth.
*   **Genotype**: The static `podman-compose.yml` definition.
*   **Phenotype**: The runtime state (PID, Port, Health Score).
*   **Divergence**: Any mismatch triggers **Jidoka** (Stop & Fix).

## 4.0 Safety Constraints (STAMP Updates)

*   **SC-SIL6-021 (Mode Integrity)**: The system SHALL NOT allow a "Fractal" mode start if resources are insufficient (pre-check).
*   **SC-SIL6-022 (Seed Preservation)**: In "Cluster" or "Fractal" mode, if `app-1` (Seed) dies, the mesh MUST trigger immediate Apoptosis (Shutdown).

## 5.0 Implementation Details

### 5.1 CLI Mapping
*   `sa-up` -> `mesh up fractal` (Default)
*   `sa-up dev` -> `mesh up dev`
*   `sa-up cluster` -> `mesh up cluster`

### 5.2 Verification
Run `sa-test.fsx` to verify all modes and fail-safe behaviors.

**Signed**:
*Cybernetic Architect (Gemini)*