# Journal Entry: Automated Tailscale Mesh Integration Plan

**Date:** 2025-12-19
**Time:** 10:30 CET
**Author:** Claude Code (Agent)
**Subject:** 5-Level Detailed Plan for Mesh-First Container Networking

## Level 1: Strategic Objective (Why?)
To achieve **Location Transparency** for all system components. We are moving from a fragile "Bridge Networking" model (dependent on host-specific IPAM) to a robust **Mesh Networking** model where every container has a persistent, cryptographic identity on the Tailnet. This enables the "Hybrid Core-Satellite" architecture where runners can float freely between cloud and edge.

## Level 2: Architectural Solution (What?)
We are implementing the **"Universal Sidecar Entrypoint"** pattern.
*   **Problem:** Sidecar containers are hard to coordinate with Erlang EPMD (port binding issues).
*   **Solution:** Embed `tailscaled` directly inside the application container but manage it via a custom `ENTRYPOINT` script that acts as a PID 1 supervisor.
*   **Key Tech:** Userspace networking (`--tun=userspace-networking`) to support Rootless Podman on NixOS.

## Level 3: Implementation Components (How?)
1.  **The Base Image (`Dockerfile.sopv51-base`):**
    *   Multi-stage copy of `tailscale` and `tailscaled` binaries.
    *   This ensures 100% of our downstream images are "Mesh Ready".
2.  **The Entrypoint Script (`scripts/containers/tailscale-entrypoint.sh`):**
    *   Detects if `/dev/net/tun` is available.
    *   Starts `tailscaled` in background.
    *   Authenticates using `TS_AUTHKEY`.
    *   Executes the main application (`iex`, `mix`, etc.).
3.  **The Orchestrator (`podman-compose.yml`):**
    *   Injects `TS_AUTHKEY`.
    *   Mounts `/var/lib/tailscale` for identity persistence.

## Level 4: Execution Workflow (The Sequence)
1.  **Build Base:** `podman build -f Dockerfile.sopv51-base -t localhost/sopv51-base:latest .`
2.  **Build App:** `podman build -f Dockerfile.sopv51-app -t localhost/sopv51-app:latest .`
3.  **Compose Up:** `podman-compose up -d` triggers the entrypoint.
4.  **Verification:** `podman exec indrajaal-app tailscale status` confirms mesh connectivity.

## Level 5: Detailed Mechanics & Constraints (The Micro-Details)
*   **Auth Key Strategy:** We will use **Reusable, Ephemeral Keys** tagged with `tag:container`. This prevents "Zombie Nodes" in the admin console; when the container dies, the node disappears.
*   **Volume Isolation:** Each service (`app`, `db`) MUST have its own unique volume for `/var/lib/tailscale` to prevent Identity Collision (FM-03).
*   **Log Prefixing:** The entrypoint script uses `[Tailscale-Entrypoint]` prefix for all logs to allow easy filtering via `grep`.
*   **Timeout Safety:** The script waits max 10s for the socket. If it fails, it aborts the container start to prevent "Silent Failure" (running without networking).

## Status Update
*   ✅ `scripts/containers/tailscale-entrypoint.sh` created.
*   ✅ Design Note `docs/architecture/MESH_NETWORKING_DESIGN.md` archived.
*   ⏳ Next: Apply changes to `Dockerfile.sopv51-base` and `Dockerfile.sopv51-app`.
