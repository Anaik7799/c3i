# Journal Entry: Expanding the Mesh to Infrastructure

**Date:** 2025-12-19
**Time:** 11:00 CET
**Author:** Claude Code (Agent)
**Subject:** 5-Level Plan for Infrastructure Mesh Networking

## Level 1: Strategic Objective
To eliminate the "Split-Brain" networking topology where Apps are on the Mesh but Databases are not. We aim for a unified control plane where *every* component is addressable via Tailscale DNS, enabling true location transparency and easy migration between Development, Demo, and Production environments.

## Level 2: Architectural Innovation
We are introducing the **Nix-Native Tailscale Wrapper**.
*   **Why?** Unlike Dockerfiles, our Nix containers are built purely functionally. We cannot hack in a shell script via `COPY`.
*   **What?** A Nix function that wraps existing entrypoints (like the Postgres startup script) inside a Tailscale supervisor, ensuring the daemon is active before the service starts.

## Level 3: Implementation Strategy
1.  **Library Creation:** Develop `containers/lib/tailscale.nix` to encapsulate the wrapping logic and binary provision.
2.  **Container Refactoring:**
    *   `indrajaal-timescaledb-demo.nix`: Inject wrapper.
    *   `indrajaal-redis-demo.nix`: Inject wrapper.
    *   `nginx-nixos.nix`: Inject wrapper.
3.  **Orchestration Update:** Modify `podman-compose.yml` to allocate state volumes and inject auth keys for these new mesh nodes.

## Level 4: Execution Sequence
1.  **Refactor:** Create the Nix library file.
2.  **Apply:** Modify the `.nix` container definitions one by one.
3.  **Rebuild:** Run `nix-build containers/indrajaal-timescaledb-demo.nix` (etc.) to generate the new images.
4.  **Load:** `podman load < result` to register the new images.
5.  **Deploy:** `podman-compose up -d` with the updated configuration.

## Level 5: Technical Constraints
*   **User Permissions:** The wrapper script runs as PID 1 (effectively root in the container namespace). It must handle the setup of `/var/lib/tailscale` before dropping privileges to `postgres` or `redis` user for the main application.
*   **Userspace Networking:** Just like the App container, we will default to `--tun=userspace-networking` to ensure compatibility with Rootless Podman and restricted environments.
*   **State Persistence:** We rely on `podman` volumes to persist `tailscaled.state`. If this volume is lost, the node gets a new identity, potentially cluttering the admin console.

## Status
*   ✅ Design Note `docs/architecture/NIX_MESH_WRAPPER_DESIGN.md` created.
*   ⏳ Pending: Implementation of `containers/lib/tailscale.nix`.
