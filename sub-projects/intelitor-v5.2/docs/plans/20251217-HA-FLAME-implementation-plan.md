# Implementation Plan: Safety-Critical HA + FLAME Transition (v2.0.0)

**Classification**: 🛡️ IMMUTABLE IMPLEMENTATION BLUEPRINT (Safety Critical)
**Reference**: docs/architecture/20251217-HA-FLAME-hybrid-architecture.md
**Status**: APPROVED FOR EXECUTION
**Date**: 2025-12-17
**Frameworks**: SOPv5.11 + STAMP + OODA + TDG + AOR + FPPS

## 1.0 Executive Summary

This plan details the safety-critical transformation of Indrajaal into a Distributed Mesh (Core) with Elastic Satellites (FLAME).
**Constraint**: "Human lives will be lost if this fails."
**Strategy**: Zero-Trust Networking, Deterministic State Management, and Total Observability.

## 2.0 5-Level Implementation Hierarchy

### Level 1: Foundation & Dependencies (The Substrate)
*   **Safety Goal**: Ensure dependency supply chain security and compatibility.
*   **STAMP Constraint**: SC-SEC-001 (Dependency Integrity).
*   **Tasks**:
    1.  **Dependency Injection**:
        *   Add `{:libcluster, "~> 3.3"}`.
        *   Add `{:flame, "~> 0.5"}`.
        *   Add `{:flame_k8s_backend, "~> 0.5"}`.
    2.  **Validation (TDG)**:
        *   Create `test/infra/dependency_test.exs` to verify library versions and checksums.
        *   Run `mix hex.audit` (Security Scan).

### Level 2: Safety Kernel & Pool Configuration (The Control Plane)
*   **Safety Goal**: Prevent Split-Brain and Resource Starvation.
*   **STAMP Constraint**: SC-REL-001 (Cluster Quorum), SC-RES-005 (Resource Isolation).
*   **Tasks**:
    1.  **Cluster Sentinel (TDG First)**:
        *   Create `test/cluster/sentinel_test.exs`: Verify Debounce (5s) and Quorum Logic (Min 2).
        *   Implement `lib/indrajaal/cluster/sentinel.ex`.
    2.  **FLAME Pools (AOR Compliant)**:
        *   Create `lib/indrajaal/flame/pools.ex`.
        *   Define Pools with strict `max_concurrency` to prevent Core starvation.
        *   **Telemetry**: Emit `[:indrajaal, :flame, :pool, :exhausted]` events.
    3.  **Supervisor Registration**:
        *   Update `lib/indrajaal/application.ex` with `one_for_one` strategy and `max_restarts`.

### Level 3: Network & Discovery (The Mesh)
*   **Safety Goal**: Authenticated, Encrypted, Identity-Based Connectivity.
*   **STAMP Constraint**: SC-SEC-043 (Network Isolation).
*   **Tasks**:
    1.  **Libcluster Config**:
        *   Configure `Cluster.Strategy.Epmd` with Tailscale MagicDNS.
        *   **OODA Loop**: Monitor `[:libcluster, :node_up]` events for rapid topology awareness.
    2.  **FLAME Backend Config**:
        *   Configure `FLAME.K8sBackend` with strict CPU/RAM limits matching `CURRENT_STATUS_UPDATE.md`.
    3.  **Observability (OODA)**:
        *   Implement `Indrajaal.Observability.ClusterMonitor` to log Topology changes to SigNoz immediately.

### Level 4: Domain Refactoring & Lifecycle (The Logic)
*   **Safety Goal**: Deterministic execution of heavy workloads.
*   **STAMP Constraint**: SC-DAT-001 (Data Integrity).
*   **Tasks**:
    1.  **Intelligence Domain (TDG)**:
        *   Create `test/intelligence/flame_integration_test.exs`.
        *   Refactor `Indrajaal.Intelligence` to use `FLAME.call`.
        *   **Defensive Coding**: Add `try/rescue` block around `FLAME.call` to fallback or alert on crash.
    2.  **Lifecycle Hooks**:
        *   Implement `handle_shutdown/0`.
        *   **Safety Check**: Ensure `FLAME.drain` completes before VM halt.

### Level 5: Infrastructure & Deployment (The Physics)
*   **Safety Goal**: Immutable Infrastructure.
*   **STAMP Constraint**: SC-OPS-009 (Immutable Deployments).
*   **Tasks**:
    1.  **Container Update**:
        *   Hard-code Tailscale version in `Containerfile`.
        *   Verify SHA256 of Tailscale binary.
    2.  **Orchestration**:
        *   Configure Liveness/Readiness probes to fail if Tailscale is down.
    3.  **Chaos Testing (Verification)**:
        *   Simulate `tailscale down`. Verify Sentinel triggers Circuit Breaker.
        *   Simulate FLAME Runner crash. Verify Parent handles error gracefully.

---

## 3.0 Critical Path & Dependencies

1.  **Dependencies** (L1) -> Unlocks L2.
2.  **Safety Kernel Tests** (L2) -> Must pass BEFORE implementation.
3.  **Sentinel** (L2) -> Guardrail for Network Config (L3).
4.  **Network Config** (L3) -> Prerequisite for FLAME (L4).
5.  **Refactoring** (L4) -> Requires Pools (L2) and Network (L3).

---

## 4.0 Validation Gates (STAMP Compliance)

*   **Gate 1 (Dependencies)**: `mix hex.audit` passes.
*   **Gate 2 (Sentinel)**: `test/cluster/sentinel_test.exs` passes (Quorum Logic Verified).
*   **Gate 3 (FLAME)**: `test/intelligence/flame_integration_test.exs` passes (Serialization Verified).
*   **Gate 4 (Network)**: Node connects to Tailscale and passes `epmd` check.
*   **Gate 5 (Chaos)**: System survives single-node kill without data loss.

---

## 5.0 Rollback Plan (Safety Critical)

If any Anomaly is detected (OODA "Decide" Phase):
1.  **Trigger**: `Indrajaal.Emergency.Stop`.
2.  **Action**: Revert `FLAME_BACKEND` to `Local`.
3.  **Action**: Disable Clustering (Topology = []).
4.  **State**: Monolith Mode (Safe, degraded capacity).