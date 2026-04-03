# Clustering Operations Guide

**Version**: 21.3.0-SIL6
**Date**: 2026-01-11
**Compliance**: SIL-6 Biomorphic Fractal Mesh

---

## Overview

Indrajaal runs as a distributed Erlang cluster using `libcluster`. The architecture supports dynamic discovery and is designed to work seamlessly in both local development (localhost), networked development (Tailscale), and production (Kubernetes).

## 🚀 Startup

To start the cluster, use the robust startup script:

```bash
./scripts/cluster/start_cluster.sh
```

### What happens during startup:
1.  **Preflight Checks**: Verifies `elixir`, `mix`, `epmd`, and port availability.
2.  **Network Detection**: Automatically detects if you are running on Tailscale or Localhost and configures the node names accordingly.
3.  **Compilation**: Compiles the application.
4.  **Process Launch**: Starts `app-1` (Port 4000) and `app-2` (Port 4001) in the background.
5.  **Health Polling**: Waits for `/api/v1/health` to return 200 OK before proceeding.
6.  **Logging**: Redirects all output to `data/logs/cluster/app-X.log`.

## 📈 Dynamic Scaling

You can add or remove nodes from the cluster dynamically without restarting the core nodes.

### Adding Nodes
To add a new node (e.g., `app-3`), run:

```bash
./scripts/cluster/scale.sh start 3
```

This will:
1.  Start `app-3` on port 4002.
2.  Configure it to discover `app-1` and `app-2`.
3.  Automatically join the distributed mesh.

### Removing Nodes
To remove a node gracefully:

```bash
./scripts/cluster/scale.sh stop 3
```

This sends a shutdown signal to the specific node process.

## 🛑 Shutdown

To stop the cluster, simply press `Ctrl+C` in the terminal where `start_cluster.sh` is running.

The script handles `SIGINT` and `SIGTERM` to perform a graceful shutdown:
1.  Sends `SIGTERM` to the BEAM processes.
2.  Waits up to 10 seconds for them to close connections and terminate.
3.  Force kills (`SIGKILL`) only if they are stuck.

## 📝 Logging

Logs are **not** printed to the console to keep the output clean. Instead, they are captured in:

*   `data/logs/cluster/app-1.log`
*   `data/logs/cluster/app-2.log`

To tail the logs in real-time:

```bash
tail -f data/logs/cluster/app-1.log
```

## 🔌 Remote Console (Remote Login)

To connect to a running node (e.g., to inspect state or run commands), use the remote console script:

```bash
./scripts/cluster/remote_console.sh [node_name]
```

**Examples:**

*   Connect to `app-1`: `./scripts/cluster/remote_console.sh app-1`
*   Connect to `app-2`: `./scripts/cluster/remote_console.sh app-2`

This script automatically detects the correct network interface (Tailscale vs Localhost) to match the running nodes.

## 🔧 Troubleshooting

### "Node not reachable"
*   Ensure you are using the same network environment. If `start_cluster.sh` detected Tailscale, your remote console must also detect it.
*   Check `data/logs/cluster/app-X.log` for startup errors.
*   Ensure both nodes share the same cookie (default is set in `mix.exs` or `rel/env.sh.eex`).

### "Port already in use"
*   The script tries to kill old processes, but if a zombie process remains, run:
    ```bash
    lsof -i :4000 -t | xargs kill -9
    lsof -i :4001 -t | xargs kill -9
    ```

---

## Related Documents
- USER_OPERATIONS_GUIDE.md - Daily operations and command reference
- SIL6_MESH_CLI_USER_GUIDE.md - Mesh operations
- OPERATIONAL_RUNBOOK.md - Operating procedures
- AGENT_BOOTSTRAP.md - Agent onboarding
