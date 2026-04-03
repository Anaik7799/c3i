# 5-Level Comprehensive Analysis: Podman-Based FLAME Backend

**Status**: FINAL
**Date**: 2025-12-24
**Subject**: Architectural & Implementation Evaluation of `Indrajaal.FLAME.Backend.Podman`
**Target Environment**: Bare Metal Mesh (Tailscale) & Local Dev

---

## Level 1: Functional Architecture & Network Topology

### 1.1 The "Sibling Container" Pattern
Instead of the "Child Process" model (Local Backend) or "Pod" model (K8s), we will implement the **Sibling Container** pattern.
*   **Mechanism**: The Parent App container mounts the host's Podman socket (`/run/podman/podman.sock`).
*   **Action**: The Parent spawns *new* containers alongside itself on the host.
*   **Benefit**: True resource isolation (cgroups) and filesystem isolation, unlike OS processes.

### 1.2 Network Strategy: The "Host Piggyback"
*   **Problem**: Erlang distribution (EPMD + Random Ports) is notoriously difficult to NAT/Bridge without complex configuration.
*   **Constraint**: In a Tailscale Mesh, the *Host* holds the identity, not the container (usually).
*   **Solution**: Runners MUST use `--network host`.
    *   This allows the Runner to bind to the Host's Tailscale IP interface directly.
    *   It eliminates the need for port mapping.
    *   It simplifies EPMD discovery (Host EPMD sees both Parent and Runner).

### 1.3 Lifecycle Management
*   **Start**: `podman run --detach --rm ...` (Run in background, auto-delete on exit).
*   **Stop**: `podman kill <id>` (SigKill) or `podman stop <id>` (SigTerm).
*   **Crash**: If the Parent crashes, the Runner (detached) might become orphaned.
    *   *Mitigation*: Use `--pid host` or a "Reaper" process (SC-FLAME-006) to clean up orphaned runners on Parent restart.

---

## Level 2: Security & STAMP Safety Analysis

### 2.1 Hazard Analysis (H-1: Container Escape)
*   **Risk**: The Parent Container has access to the Docker/Podman socket. This is effectively Root access to the host (if Rootful) or User access (if Rootless).
*   **Control (SC-SEC-050)**: The Parent App MUST run as **Rootless Podman**. This limits the blast radius to the user's namespace, not the system root.

### 2.2 Hazard Analysis (H-2: Resource Exhaustion)
*   **Risk**: Unbounded spawning of runners consumes all Host RAM.
*   **Control (SC-FLAME-003)**: Hard limits injected into `podman run` args.
    *   `--memory=<pool_config.memory>`
    *   `--cpus=<pool_config.cpus>`
    *   These must be derived from `Indrajaal.FLAME.Pools` configuration.

### 2.3 Image Provenance (SC-CNT-010)
*   **Constraint**: Runners MUST use the exact same image version as the Parent to ensure code compatibility (BEAM bytecodes).
*   **Mechanism**: The Backend must auto-detect its own image ID/Tag via `env` or introspection and pass that to the Runner.

---

## Level 3: Observability & Telemetry Strategy

### 3.1 The "Black Box" Problem
Ephemeral containers disappear (`--rm`), taking their stdout/stderr logs with them.
*   **Traditional Solution**: Log drivers (journald/json-file).
*   **FLAME Solution**: Telemetry Push.

### 3.2 Quadplex Integration
1.  **Console**: `podman logs` on the Runner is only visible if we tail it. We likely won't.
2.  **Telemetry**: The Runner *must* connect to the Cluster. Once connected, it streams `:telemetry` events back to the Parent (or directly to OTEL collector if configured).
3.  **Action**: The Runner's `runtime.exs` must auto-configure `OTEL_EXPORTER_OTLP_ENDPOINT` to point to the `indrajaal-obs` service (likely `localhost:4317` since we are `--network host`).

### 3.3 Correlation
*   **Trace ID**: The Parent must pass the active `TraceContext` to the Runner via Environment Variables (`OTEL_TRACE_PARENT`).

---

## Level 4: Implementation Specification

### 4.1 Module Design
**Module**: `Indrajaal.FLAME.Backend.Podman`
**Behaviour**: `FLAME.Backend`

**Struct**:
```elixir
defstruct [
  :node_base,    # Base name for the node
  :image,        # Docker/Podman image URI
  :cpu,          # CPU shares/quota
  :memory,       # Memory limit
  :env,          # Map of env vars
  :boot_timeout  # ms to wait for boot
]
```

### 4.2 The "Boot" Sequence (start_child/1)
1.  **Resolve Image**: `System.get_env("CONTAINER_IMAGE")` or default.
2.  **Generate Name**: `flame-<pool>-<uuid>`.
3.  **Construct Command**:
    ```bash
podman run -d --rm \
  --name <name> \
  --network host \
  --env FLAME_PARENT=<parent_node> \
  --env PHX_SERVER=false \
  --env RELEASE_NODE=<name> \
  <resource_limits> \
  <image> \
  /app/bin/server start
    ```
4.  **Execute**: `System.cmd("podman", args)`.
5.  **Wait**: FLAME internal logic waits for the node to appear in `Node.list()`.

---

## Level 5: Risk & Mitigation Matrix (FMEA)

| Failure Mode | Effect | RPN (Risk Priority) | Mitigation |
| :--- | :--- | :--- | :--- |
| **Parent Crash** | Orphaned Runners leak resources | High (16) | **Labeling**: Apply `created-by=indrajaal-flame`. **Reaper**: On Startup, `podman rm -f -l created-by=...` |
| **Image Mismatch** | Runner crashes on boot (Code loading) | Medium (9) | **Strict Versioning**: Use SHA digest for image reference, not tags. |
| **Socket Missing** | Backend crashes loop | Critical (20) | **Pre-flight Check**: Verify `/run/podman/podman.sock` access in `init/1`. Fail fast if missing. |
| **Network Partition** | Runner starts but can't connect | Medium (8) | **Timeout**: FLAME handles this. **Kill**: Backend kills container on timeout. |

---

## Conclusion & Recommendation

The **Podman-Based FLAME Backend** is architecturally sound and aligns perfectly with the "Container-Native" and "Cybernetic" axioms of the project.

**Go/No-Go**: **GO**.

**Critical Implementation Path**:
1.  Implement `lib/indrajaal/flame/backend/podman.ex`.
2.  Add "Reaper" logic to `init/1` to clean up old runners.
3.  Configure `runtime.exs` to select this backend when `FLAME_STRATEGY=podman`.
