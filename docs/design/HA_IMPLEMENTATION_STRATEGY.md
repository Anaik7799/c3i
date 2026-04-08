# Design: High Availability Implementation Strategy

**Version**: 1.0.0
**Date**: 2026-04-08
**Classification**: IMPLEMENTATION STRATEGY / SIL-6

## 1. Overview
This document specifies the technical implementation of the A/B deployment pattern for zero-downtime upgrades of the `sa-plan-daemon` and `cepaf_gleam` Cortex.

## 2. Zenoh Leader Election (The Lock)
We will leverage Zenoh's distributed querying and key-value store capabilities to implement a Leader Election algorithm.

1.  **Lease Key**: `indrajaal/l4/system/leader_lease`
2.  **Heartbeat**: The Primary node publishes to this key every 100ms with a TTL of 300ms.
3.  **Standby Monitoring**: The Backup node subscribes to this key. If no heartbeat is received for 300ms, it attempts to acquire the lease.

## 3. Substrate Orchestration (`sa-up` & Podman)
The deployment script (`sa-up`) must be refactored into a Blue/Green orchestrator.

### The Seamless Upgrade Flow:
1.  **State**: `cortex-primary` (v1.0) is running and holds the lease. `cortex-backup` is not running.
2.  **Deploy**: Developer runs `sa-plan deploy`.
3.  **Spin Up**: Orchestrator spawns `cortex-backup` (v1.1) in `Standby` mode.
4.  **Health Check**: Orchestrator verifies `cortex-backup` is healthy (FPPS consensus passes).
5.  **Signal Drain**: Orchestrator sends `SIGTERM` (or Zenoh Intent `SystemDrain`) to `cortex-primary`.
6.  **Drain**: `cortex-primary` stops accepting new intents, finishes active OODA loops, and deletes its lease heartbeat.
7.  **Handover**: `cortex-backup` detects the lease expiration, assumes Primary status, and begins processing intents.
8.  **Terminate**: `cortex-primary` exits gracefully. The Orchestrator renames `cortex-backup` to `cortex-primary` (or updates routing logic) for the next cycle.

## 4. Rust Motor Strip Modifications
*   **`src/main.rs`**: Add `--mode primary|backup` CLI flag.
*   **`src/zenoh_telemetry.rs`**: Implement the heartbeat publishing logic.
*   **`src/cortex.rs`**: Wrap the main OODA loop in a lease-check. If the lease is lost, pause `mcp_subscriber` polling.

## 5. Gleam Cognitive Plane Modifications
*   **`agents/cybernetic.gleam`**: The `ExecutiveSupervisor` must spawn a `LeadershipMonitor` actor that watches the Zenoh lease and cascades the `Standby` or `Active` state to the Cortex and Workspace agents.
