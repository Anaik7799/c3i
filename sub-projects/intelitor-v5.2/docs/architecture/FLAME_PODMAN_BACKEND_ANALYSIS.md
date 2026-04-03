# Analysis: Podman-Based FLAME Backend for Bare Metal/Mesh

**Status**: DRAFT
**Author**: Gemini (Cybernetic Architect)
**Date**: 2025-12-24
**Objective**: Enable FLAME to spawn runners as ephemeral **Podman containers** on Bare Metal/Mesh nodes, providing superior isolation compared to `FLAME.Backend.Local` (OS processes).

## 1. Context & Motivation
*   **Current State**:
    *   **Local/Dev**: Uses `FLAME.Backend.Local` (OS Ports/Processes). Good for speed, weak isolation.
    *   **K8s**: Uses `FLAME.K8sBackend` (Pods). Excellent isolation and scaling.
    *   **Bare Metal**: Currently defaults to `Local`. Weak isolation; resource contention on the parent node is risky.
*   **Goal**: Create `Indrajaal.FLAME.Backend.Podman`.
*   **Benefits**:
    *   **Isolation**: Runners have their own filesystem, resource limits (CPU/RAM via cgroups), and network namespace.
    *   **Consistency**: Matches the "Container-Native" axiom of the project.
    *   **Cleanliness**: "Scale-to-zero" really means the container is deleted, leaving no artifacts.

## 2. Technical Requirements

### 2.1 The FLAME Backend Contract
A FLAME backend must implement the `FLAME.Backend` behaviour (or at least provide a `start_link/1` compatible generic server structure that manages the lifecycle).
Key responsibilities:
1.  **Start**: Execute the runner (e.g., `podman run ...`).
2.  **Connect**: Ensure the runner connects back to the parent node (Erlang distribution).
3.  **Monitor**: Watch the runner process/container.
4.  **Terminate**: Cleanup (e.g., `podman rm -f ...`) on exit.

### 2.2 The Podman Command Strategy
To spawn a runner that joins the cluster, the container needs:
1.  **Network**: Access to the parent node.
    *   **Mode**: `--network host` (Simplest for Mesh/Tailscale) OR specific bridge network.
2.  **Environment**:
    *   `FLAME_PARENT`: The parent node name (e.g., `indrajaal@host`).
    *   `PHX_SERVER`: `false` (Runners don't serve HTTP).
    *   `RELEASE_NODE`: Unique name for the runner.
    *   `RELEASE_COOKIE`: Must match parent.
3.  **Image**: The same image as the parent (usually).

**Draft Command**:
```bash
podman run --rm -d \
  --name flame-runner-<UUID> \
  --network host \
  --env FLAME_PARENT=<PARENT_NODE> \
  --env RELEASE_COOKIE=<COOKIE> \
  localhost/indrajaal-sopv51-elixir-app:nixos-devenv \
  /app/bin/server start
```

## 3. Implementation Plan (`Indrajaal.FLAME.Backend.Podman`)

### 3.1 Module Structure
We will create `lib/indrajaal/flame/backend/podman.ex`.

```elixir
defmodule Indrajaal.FLAME.Backend.Podman do
  @behaviour FLAME.Backend

  def init(opts) do
    # 1. Validate Podman availability
    # 2. Configure defaults (image, network mode)
    {:ok, state}
  end

  def start_child(state) do
    # 1. Generate unique runner name
    # 2. Construct `podman run` command
    # 3. Execute via System.cmd or Port
    # 4. Return {:ok, pid}
  end
end
```

### 3.2 Challenges & Mitigations
*   **Networking**:
    *   *Challenge*: Runner container connecting back to Parent process.
    *   *Solution*: Use `--network host` for Bare Metal/Mesh to share the Tailscale interface.
*   **Image Availability**:
    *   *Challenge*: The image must exist on the host.
    *   *Solution*: Rely on the "Localhost Registry" axiom (SC-CNT-010). The image `localhost/indrajaal-sopv51-elixir-app:nixos-devenv` should be pre-pulled/built.
*   **Permissions**:
    *   *Challenge*: The App container (running the backend) needs to spawn sibling containers.
    *   *Solution*: **Docker-in-Docker (DinD)** or **Podman-in-Podman**. This requires binding the Podman socket (`/run/podman/podman.sock`) into the App container.
    *   *Compliance*: This is acceptable for the "App" container in a controlled Mesh environment, provided it's Rootless.

## 4. Proposed `runtime.exs` Configuration

```elixir
# runtime.exs

config :flame, :backend,
  case System.get_env("FLAME_STRATEGY") do
    "podman" ->
      {Indrajaal.FLAME.Backend.Podman, [
        image: "localhost/indrajaal-sopv51-elixir-app:nixos-devenv",
        network: "host", # Required for Tailscale/EPMD binding
        cpu: "1.0",
        memory: "512m"
      ]}
    "k8s" -> ...
    _ -> FLAME.Backend.Local
  end
```

## 5. Next Steps
1.  Create the `Indrajaal.FLAME.Backend.Podman` module.
2.  Implement the `remote_boot` logic using `System.cmd("podman", ...)`.
3.  Test by setting `FLAME_STRATEGY=podman`.

```