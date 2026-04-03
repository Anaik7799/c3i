# Implementation Plan: Tailscale-Based HA Cluster Transition (v1.0.0)

**Classification**: 🛡️ IMMUTABLE IMPLEMENTATION BLUEPRINT
**Reference**: docs/architecture/20251217-HA-cluster-transition-specification.md
**Status**: APPROVED FOR EXECUTION
**Date**: 2025-12-17

## 1.0 Executive Summary

This plan details the step-by-step execution of the **Tailscale-Based HA Cluster Transition**. It transforms the current single-node Indrajaal deployment into a resilient, globally addressable mesh cluster secured by WireGuard.

**Primary Objective**: Enable 3-node HA with zero-trust networking.
**Constraint**: Maintain STAMP compliance (SC-SEC-043, SC-REL-001) throughout the transition.

## 2.0 5-Level Implementation Hierarchy

### Level 1: Foundation & Dependencies (The Substrate)
*   **Goal**: Enable Distributed Erlang capabilities within the project.
*   **Tasks**:
    1.  Add `{:libcluster, "~> 3.3"}` to `mix.exs`.
    2.  Add `{:dns_cluster, "~> 0.1.1"}` (optional helper) or rely on `libcluster` strategies.
    3.  Run `mix deps.get` and validate dependency tree.

### Level 2: Safety Kernel (The Control Plane)
*   **Goal**: Implement the `ClusterSentinel` to prevent Split-Brain.
*   **Tasks**:
    1.  Create `lib/indrajaal/cluster/sentinel.ex`.
    2.  Implement "Debounce Logic" (5s wait).
    3.  Implement "Quorum Logic" (Minimum 2 nodes).
    4.  Implement "Intentional Leave" handling for graceful shutdown.
    5.  Register `Sentinel` in `Application.ex`.

### Level 3: Network & Discovery (The Mesh)
*   **Goal**: Configure Tailscale-aware node discovery.
*   **Tasks**:
    1.  Update `config/runtime.exs` with `libcluster` topology.
    2.  Configure `Cluster.Strategy.Epmd` or `DNS` to use Tailscale MagicDNS names (`app-1`, `app-2`).
    3.  Create/Update `rel/env.sh.eex` to set `RELEASE_NODE` dynamically using `tailscale ip`.
    4.  Configure `vm.args` to bind EPMD to `tailscale0` interface.

### Level 4: Lifecycle Management (The OODA Loop)
*   **Goal**: Orchestrate startup and shutdown sequences.
*   **Tasks**:
    1.  Update `lib/indrajaal/application.ex` with `System.set_handler(:terminate, ...)` hook.
    2.  Implement `handle_shutdown/0` function to broadcast "Intentional Leave".
    3.  Configure `Phoenix.Endpoint` draining timeout (25s).
    4.  Create container startup script `bin/start_ha.sh` to handle `tailscale up` before app boot.

### Level 5: Infrastructure & Deployment (The Physics)
*   **Goal**: Deploy the mesh infrastructure.
*   **Tasks**:
    1.  Update `Containerfile` to install `tailscale` binary.
    2.  Generate Tailscale Auth Key (Reusable, Ephemeral).
    3.  Update `podman-compose.yml` (or K8s manifest) to launch 3 replicas (`app-1`, `app-2`, `app-3`).
    4.  Configure "Sidecar" pattern if running in K8s (optional, native preferred for Podman).

---

## 3.0 Critical Path & Dependencies

1.  **Dependency Injection** (L1) -> Unlocks L2 & L3 code.
2.  **Safety Kernel** (L2) -> Must be tested BEFORE multi-node deployment to prevent data corruption.
3.  **Network Config** (L3) -> Requires Tailscale Auth Key.
4.  **Lifecycle** (L4) -> Depends on `Sentinel` (L2).
5.  **Infrastructure** (L5) -> Final assembly.

---

## 4.0 Validation Gates

*   **Gate 1 (Compile)**: `mix compile --warnings-as-errors` passes with `libcluster`.
*   **Gate 2 (Sentinel)**: Unit tests for `Sentinel` verify debounce and quorum logic.
*   **Gate 3 (Mesh)**: 3 local nodes (dev mode) connect via Gossip (simulating Tailscale).
*   **Gate 4 (Tailscale)**: Container build succeeds with Tailscale binary.

---

## 5.0 Rollback Plan

If Tailscale connectivity fails or cluster instability is detected:
1.  **Revert** `runtime.exs` topology to empty list (disables clustering).
2.  **Revert** `env.sh.eex` to use loopback/local IP.
3.  **Scale Down** to 1 replica.
4.  System degrades to "Monolith Mode" (Current State) - **Safe State**.
