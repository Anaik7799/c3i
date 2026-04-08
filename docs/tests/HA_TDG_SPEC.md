# Test Specification: TDG & 100% Coverage for HA Upgrades

**Version**: 1.0.0
**Date**: 2026-04-08
**Classification**: TEST-DRIVEN GENERATION (TDG) / SIL-6

## 1. Overview
This document specifies the strict Test-Driven Generation (TDG) rules required to implement the HA Active/Standby logic, ensuring zero downtime and 100% test coverage.

## 2. Comprehensive Test Suite Definition

### 2.1 Rust Leader Election (Motor Strip)
*   **Unit Tests (`native/planning_daemon/src/ha_test.rs`)**:
    *   `test_lease_acquisition`: Start two daemon instances in memory. Assert exactly one acquires the `LeaderLease`.
    *   `test_failover_latency`: Kill the primary instance. Assert the backup instance acquires the lease in $< 300ms$.
    *   `test_split_brain_prevention`: Simulate a network partition between the two nodes. Assert the SQLite database only accepts writes from the node that can reach the Zenoh quorum.

### 2.2 Gleam Graceful Drain (Cognitive Plane)
*   **Integration Tests (`test/mesh/ha_drain_test.gleam`)**:
    *   `test_drain_completes_active_intents`: Send 5 inference intents. Send the `SIGTERM` signal. Assert all 5 intents receive responses before the actor stops.
    *   `test_drain_rejects_new_intents`: Send `SIGTERM`. Send a new intent. Assert the intent is ignored by the draining node and picked up by the Backup node.

### 2.3 Substrate Orchestration
*   **System E2E Tests (`scripts/tests/ha_upgrade_e2e.sh`)**:
    *   Launch the 15-container mesh.
    *   Start a background process sending 10 ping intents per second to the Telegram Gateway.
    *   Trigger the `sa-plan deploy` command to cycle the Gleam Cortex and Rust Planner binaries.
    *   **Pass Criteria**: 0 dropped pings during the 30-second deployment window. 100% uptime verified.

## 3. TDG Mandates
1.  The `ha_upgrade_e2e.sh` script MUST be written and executing (and failing) before the Rust or Gleam code is modified.
2.  Code coverage for the new `ha_election` modules must be 100%.
