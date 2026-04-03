# FLAME Distributed Compute Strategy: Local, K8s, and Mesh

**Status**: DRAFT
**Author**: Gemini (Cybernetic Architect)
**Date**: 2025-12-24
**Compliance**: SOPv5.11, SC-FLAME-001 (No Local State), SC-CLU-001 (Identity Networking)

## 1. Executive Summary
This document defines the configuration and implementation strategy for running the Indrajaal FLAME distributed computing system across three distinct environments:
1.  **Local Simulation (Dev/Test)**: Single-node simulation for rapid development.
2.  **Kubernetes Production (Prod)**: Auto-scaling Pods via `FLAME.K8sBackend`.
3.  **Bare Metal Mesh (Mesh)**: Distributed execution across static nodes via Tailscale/WireGuard.

## 2. Current Architecture & Gaps

### 2.1 Current State
*   **Pools**: Defined in `Indrajaal.FLAME.Pools` (Intelligence, Video, Analytics).
*   **Supervision**: Pools are currently supervised directly by `Indrajaal.Application`, bypassing the dedicated `Indrajaal.Compute.FLAMESupervisor` (Empty).
*   **Backends**: `runtime.exs` supports `:prod` (K8s) and `:dev/:test` (Local).

### 2.2 Identified Gaps
*   **Gap 1 (Structural)**: `FLAMESupervisor` is unused, violating the "Single Responsibility Principle" for compute supervision.
*   **Gap 2 (Configuration)**: No explicit configuration exists for `MESH` environments (Bare Metal/Tailscale).
*   **Gap 3 (Backend)**: Bare Metal execution requires a strategy for runner placement (e.g., existing static nodes vs. spawning new system processes on remote hosts).

## 3. Implementation Strategy

### 3.1 Structural Refactoring (Gap 1)
**Objective**: Centralize FLAME management in `Indrajaal.Compute.FLAMESupervisor`.

**Action**:
1.  Move FLAME pool child specs from `lib/indrajaal/application.ex` to `lib/indrajaal/compute/flame_supervisor.ex`.
2.  Update `application.ex` to start only `Indrajaal.Compute.FLAMESupervisor`.

**Benefit**: Allows for sophisticated failure handling (e.g., if *all* compute fails, restart the supervisor, not the whole app) and cleaner startup logic.

### 3.2 Backend Configuration Strategy (Gap 2 & 3)

#### A. Local Simulation (Dev/Test)
*   **Backend**: `FLAME.Backend.Local`
*   **Mechanism**: Spawns runners as separate OS processes on the *same machine*.
*   **Config**: Default for `:dev` and `:test`.
*   **Use Case**: Development, CI/CD, Unit Testing.

#### B. Kubernetes Production (Prod)
*   **Backend**: `FLAME.K8sBackend`
*   **Mechanism**: Spawns runners as transient Kubernetes Pods.
*   **Config**: Active when `MIX_ENV=prod`.
*   **Use Case**: Production scaling, Cloud deployment.

#### C. Bare Metal Mesh (Mesh)
*   **Backend**: `FLAME.Backend.Fly` (if Fly.io) OR **Custom/Local Distributed**.
*   **Constraint**: For bare metal (Tailscale), we typically don't "spawn" new machines on demand like K8s. We utilize *existing* capacity or spawn processes on remote nodes.
*   **Proposed Solution**: Use `FLAME.Backend.Local` configured to connect to the specific parent node in the mesh, OR treating the mesh as a static cluster where FLAME runners are just processes on specific nodes.
*   **Refined Approach**: Since standard FLAME backends (Fly/K8s) assume "serverless" spawning capabilities, "Bare Metal Mesh" usually implies using `FLAME.Backend.Local` but distributed across a cluster formed by `libcluster`.
    *   *Correction*: FLAME is designed for "scale-to-zero" ephemeral runners. On bare metal, unless we have a hypervisor API (like Proxmox or a custom agent), we cannot "spawn" a new node.
    *   **Strategy**: For Mesh, we will configure FLAME to use **System Processes** on the *local* node (effectively behaving like Dev), BUT we will use `libcluster` to distribute the *requests* to nodes that *can* run FLAME. Alternatively, if the Mesh supports it (e.g. Fly.io hybrid), we use the Fly backend.
    *   **Decision**: For generic Bare Metal, we defaults to `FLAME.Backend.Local` (Process-based isolation) but ensuring the parent node has sufficient resources.

## 4. Implementation Plan

### Phase 1: Structural Hygiene
1.  **Refactor**: Move pools to `FLAMESupervisor`.
2.  **Verify**: Ensure standalone app still boots correctly.

### Phase 2: Mesh Configuration
1.  **Update `runtime.exs`**: Add specific config for `MESH` environment (conceptually mapping to `:prod` settings but with potentially different backends if needed).
2.  **Telemetry**: Ensure `TailscaleDNS` logic works for identifying these runners.

### Phase 3: Verification
1.  **Local**: Run `mix test`.
2.  **Mesh**: Simulate by running two nodes locally connected via `libcluster`.

## 5. Configuration Reference (Draft)

```elixir
# runtime.exs

flame_backend =
  case System.get_env("FLAME_STRATEGY") do
    "k8s" ->
      {FLAME.K8sBackend, [...]}
    "fly" ->
      {FLAME.FlyBackend, [...]}
    _ ->
      # Default to Local (Process-based) for Dev, Test, and Bare Metal
      FLAME.Backend.Local
  end
```
