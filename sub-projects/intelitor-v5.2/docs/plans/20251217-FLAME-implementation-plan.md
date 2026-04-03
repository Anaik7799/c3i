# Implementation Plan: FLAME Integration (v1.0.0)

**Classification**: 🛡️ IMMUTABLE IMPLEMENTATION BLUEPRINT
**Reference**: docs/architecture/20251217-HA-FLAME-hybrid-architecture.md
**Status**: APPROVED FOR EXECUTION
**Date**: 2025-12-17

## 1.0 Executive Summary

This plan details the integration of **FLAME** into the Indrajaal system. It focuses on enabling specific, high-load domains to offload execution to ephemeral runners.

## 2.0 5-Level Implementation Hierarchy

### Level 1: Dependencies & Foundation
*   **Goal**: Enable FLAME capabilities.
*   **Tasks**:
    1.  Add `{:flame, "~> 0.5"}` to `mix.exs`.
    2.  Add `{:flame_k8s_backend, "~> 0.5"}` (and/or `flame_podman_backend` if available/custom).
    3.  Run `mix deps.get`.

### Level 2: Pool Configuration (The Control Plane)
*   **Goal**: Define the "Satellites".
*   **Tasks**:
    1.  Update `lib/indrajaal/application.ex` to start `FLAME.Pool` supervisors.
    2.  Define `Indrajaal.FLAME.IntelligencePool`.
    3.  Define `Indrajaal.FLAME.VideoPool`.
    4.  Define `Indrajaal.FLAME.AnalyticsPool`.
    5.  Update `config/runtime.exs` to configure Backends (Local for Dev, K8s for Prod).

### Level 3: Domain Refactoring (The Logic)
*   **Goal**: "FLAME-ify" heavy functions.
*   **Tasks**:
    1.  Refactor `Indrajaal.Intelligence` context to wrap inference in `FLAME.call`.
    2.  Refactor `Indrajaal.Analytics` to wrap report generation.
    3.  Ensure all arguments passed to `FLAME.call` are serializable.

### Level 4: Backend Integration (The Physics)
*   **Goal**: Ensure Runners can boot and connect.
*   **Tasks**:
    1.  Configure `env` variables for Runners (they need `DATABASE_URL`, `TAILSCALE_KEY` etc. if they access DB directly).
    2.  Ensure Runner Container Image is available.

### Level 5: Validation & Tuning
*   **Goal**: Verify Elasticity.
*   **Tasks**:
    1.  Test: Run `mix test` (FLAME defaults to LocalBackend, should pass).
    2.  Load Test: Trigger 10 concurrent heavy tasks. Verify 10 runners spawn (in Prod/Mock mode).

---

## 3.0 Critical Path

1.  **Dependencies** (L1) -> Unlocks L2.
2.  **Configuration** (L2) -> Unlocks L3.
3.  **Refactoring** (L3) -> Enables functionality.

---

## 4.0 Validation Gates

*   **Gate 1 (Compile)**: `mix compile` passes with FLAME deps.
*   **Gate 2 (Local)**: `FLAME.call` works with `LocalBackend`.
*   **Gate 3 (Isolation)**: Crash in `FLAME.call` does not crash Parent Node.
