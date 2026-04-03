# 5-Stage Deep Analysis: DB & OBS Transactional Shutdown
**Compliance**: SIL-6 Biomorphic / IEC 61508
**Objective**: Zero-loss shutdown for Data and Observability planes.

## Stage 1: Memory-to-Disk Synchronization (Flush)
*   **DB (Postgres)**: Must execute `CHECKPOINT`. This flushes the WAL buffers to disk.
*   **OBS (SigNoz/ClickHouse)**: Must flush the in-memory write-ahead logs. 
*   **Risk**: Power-cut during flush leads to corrupted blocks.
*   **Mitigation**: Atomic WAL file renaming.

## Stage 2: Connection Draining (Admission Control)
*   **Action**: Containers stop listening on public ports but maintain internal connectivity for final cleanup.
*   **App Interaction**: App nodes detect `connection_refused` and enter "Buffer Mode".

## Stage 3: Protocol Finalization
*   **Action**: Gracefully close all gRPC (OBS) and TCP (DB) streams. 
*   **Timeout**: 2 seconds. If streams don't close, escalate to Stage 4.

## Stage 4: Digital Twin State Snapshot
*   **Action**: Before the process dies, the **Watchdog Agent** writes the final LSN (Log Sequence Number) to `data/shutdown_marker.json`.
*   **Verification**: On next startup, the Digital Twin compares current state with this marker.

## Stage 5: Hard Termination (SIGKILL Fallback)
*   **Action**: OS-level termination.
*   **Constraint**: Only executed if Stages 1-4 complete within the 5s grace period.

## Implementation: The Watchdog Agent
We will embed a small Elixir script `indrajaal_watchdog.exs` in the container entrypoint that traps `SIGTERM` and executes these 5 stages.
