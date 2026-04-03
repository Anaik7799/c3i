# DESIGN NOTE: Mesh-First Container Networking via Automated Tailscale Injection

**Date:** 2025-12-19
**Status:** PROPOSED
**Classification:** INFRASTRUCTURE / NETWORKING
**Component:** Container Orchestration Layer
**Reference:** Task 22.1 (Tailscale Rollout)

## 1. Architectural Overview

### 1.1 The Objective
To transition from legacy "Bridge Networking" (where containers rely on host port mapping and local Docker DNS) to a **Mesh Networking** model.
**Goal:** Every container, regardless of host location (local dev, staging, prod), possesses a unique, addressable identity (IP/DNS) on the private Tailnet.

### 1.2 The Solution: "Universal Sidecar Entrypoint"
Instead of running Tailscale as a separate "sidecar" container (which complicates localhost binding for things like Erlang Distribution), we implement an **Embedded Supervisor Pattern**.

1.  **Binary Injection:** The `tailscaled` and `tailscale` binaries are baked into the `sopv51-base` image.
2.  **Entrypoint Interception:** A custom script (`tailscale-entrypoint.sh`) becomes the `ENTRYPOINT` for the container.
3.  **Process Supervision:** This script starts `tailscaled` in the background, waits for the socket, authenticates, and *then* `exec`s the original application command (e.g., `mix phx.server`).

### 1.3 Topology Diagram
```mermaid
graph TD
    subgraph "Host Machine (NixOS)"
        PodmanSocket
        subgraph "Container A (App)"
            Entrypoint_A[tailscale-entrypoint.sh]
            Daemon_A[tailscaled (userspace)]
            App_A[Beam.smp]
            Entrypoint_A -->|Starts & Monitors| Daemon_A
            Entrypoint_A -->|Execs| App_A
            App_A -->|Localhost Bind| Daemon_A
        end
        subgraph "Container B (DB)"
            Entrypoint_B[tailscale-entrypoint.sh]
            Daemon_B[tailscaled (userspace)]
            DB_B[Postgres]
        end
    end
    Daemon_A <-->|Tailnet Tunnel| Daemon_B
```

---

## 2. Implementation Strategy

### 2.1 Layer 1: The Base Image Injection
We modify `Dockerfile.sopv51-base` to include the binaries. This ensures **every** downstream container inherits the capability.

**Strategy:** Use Multi-stage build to extract static binaries.
**Rationale:** Tailscale binaries are static Go binaries; they run on NixOS containers without glibc/musl dependency hell.

### 2.2 Layer 2: The Orchestration Entrypoint
The `tailscale-entrypoint.sh` script (created in previous step) handles the critical logic:
*   **Userspace Networking (`--tun=userspace-networking`):** Critical for Rootless Podman. We cannot rely on `/dev/net/tun` availability in unprivileged environments.
*   **State Persistence:** Mounts `/var/lib/tailscale` to a volume. This ensures the container keeps its IP/ID across restarts (preventing "node spam" in the Tailscale admin console).
*   **Auth Key Handling:** Checks for `TS_AUTHKEY` environment variable.

### 2.3 Layer 3: Configuration (Compose)
We leverage `tailscale.env` to inject the identity.

---

## 3. Usage Guide

### 3.1 Prerequisite: Generate Auth Key
1.  Go to Tailscale Admin Console > Settings > Keys.
2.  Generate an **Ephemeral Key** (if containers are temporary) or a **Reusable Key** with Tags (e.g., `tag:container`).
    *   *Recommendation:* Use `tag:indrajaal-dev` to auto-approve devices and manage ACLs.

### 3.2 Modifying `Dockerfile`
Update your `Dockerfile` to use the script:

```dockerfile
# ... inside Dockerfile ...
COPY scripts/containers/tailscale-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/tailscale-entrypoint.sh

# Set as Entrypoint
ENTRYPOINT ["/usr/local/bin/tailscale-entrypoint.sh"]

# CMD remains your app command
CMD ["iex", "-S", "mix", "phx.server"]
```

### 3.3 Running with Podman
Add the environment variables in `podman-compose.yml`:

```yaml
services:
  app:
    environment:
      - TS_AUTHKEY=${TS_AUTHKEY}
      - TS_HOSTNAME=indrajaal-app-${TS_HOST_ID}
    volumes:
      # Persist identity
      - tailscale_app_data:/var/lib/tailscale
    cap_add:
      # Optional: Required if attempting kernel networking, but userspace works without
      - NET_ADMIN 
```

---

## 4. System Interactions

### 4.1 Interaction with Erlang Distribution (EPMD)
**Challenge:** EPMD usually binds to 0.0.0.0 or localhost.
**Solution:**
1.  Tailscale creates a local interface (or socks5 proxy in userspace mode).
2.  We must configure `vm.args` to use the Tailscale IP name.
3.  Set `RELEASE_DISTRIBUTION=name` and `RELEASE_NODE=app@tailscale-dns-name`.

### 4.2 Interaction with Database
The App container will now address the database as `db-hostname.tailnet.ts.net` instead of the Podman service name `postgres`.
*   **Benefit:** The App can move to a completely different server without changing config, as long as it's on the Tailnet.

---

## 5. Failure Modes & RCA (STAMP Analysis)

| ID | Failure Mode | Symptom | Detection | Recovery/Mitigation |
| :--- | :--- | :--- | :--- | :--- |
| **FM-01** | **Userspace Networking Fail** | `tailscaled` starts but cannot route traffic. | Logs show `TUN/TAP error` despite userspace flag. | Ensure `SOCKS5_SERVER` or `HTTP_PROXY` env vars are set if using proxy mode. |
| **FM-02** | **Auth Key Exhaustion** | Container fails to start, logs `401 Unauthorized`. | `tailscale-entrypoint.sh` logs "Auth failed". | Use **Reusable Tags** in Tailscale ACLs. Do not use individual user keys. |
| **FM-03** | **State Conflict** | "Node is logged in as different user". | Logs show state mismatch. | Ensure volume `/var/lib/tailscale` is unique per service instance. |
| **FM-04** | **DNS Resolution** | App cannot find `db`. | `ping db` fails inside container. | Ensure `TS_ACCEPT_DNS=true`. Check `/etc/resolv.conf` override. |
| **FM-05** | **Zombie Nodes** | Tailscale Admin console flooded with dead containers. | Admin console clutter. | Use **Ephemeral** keys (`--ephemeral`) for dev containers so they disappear on disconnect. |

## 6. Debugging Procedures

### 6.1 Check Tailscale Status Inside Container
```bash
podman exec -it indrajaal-app tailscale status
```

### 6.2 View Entrypoint Logs
Since the entrypoint runs `tailscaled` in the background, its logs go to stdout.
```bash
podman logs indrajaal-app | grep "[Tailscale-Entrypoint]"
```

### 6.3 Force Re-Auth
If a node is stuck in a bad state:
1.  `podman-compose down`
2.  `podman volume rm indrajaal_tailscale_app_data` (Clear state volume)
3.  `podman-compose up` (Triggers fresh `tailscale up`)

## 7. Next Steps (Action Items)

1.  **Update Base Image:** Modify `Dockerfile.sopv51-base` to inject the binaries (Task 22.1.1.1).
2.  **Integrate Entrypoint:** Update `Dockerfile.sopv51-app` to `COPY` and set `ENTRYPOINT`.
3.  **Secrets Management:** Move `TS_AUTHKEY` to `.env` (git-ignored) or Vault; remove from shared `tailscale.env`.
