# COMPREHENSIVE TEST PLAN: Full Capability State (v21.3.0)

**Classification**: L7-KOSMOS (Sovereign Verification)
**Target**: Indrajaal v21.3.0 (SIL-6 Biomorphic Mesh)
**Status**: APPROVED
**Standards**: IEC 61508 SIL-6, Axiom 0, PROMETHEUS

---

## 1.0 Executive Summary
This plan defines the exhaustive verification strategy to certify the **Full Capability State** of the Indrajaal system. It validates not only the *function* of components but their *interactions* and *evolutionary potential*. The test suite is designed to be executed by the **OODA Supervisor** autonomously.

---

## 2.0 The 7-Level Fractal Test Matrix

### Level 1: Cellular (Logic & Data Integrity)
*   **Definition**: Correctness of atomic functions and data schemas.
*   **Test C1**: **PropCheck Invariants**. Verify that `TokenBucket` never allows negative tokens.
*   **Test C2**: **NIF Safety**. Verify `Zenohex` calls do not crash the BEAM VM (Safety Envelope).
*   **Test C3**: **Vector Schema**. Verify DuckDB table creation matches the `MemoryRecord` type definition.
*   **Tool**: `mix test` (Elixir), `dotnet test` (F#).

### Level 2: Component (Agent Metabolism)
*   **Definition**: Health and responsiveness of individual agents/actors.
*   **Test O1**: **Heartbeat Frequency**. Verify `ZenohPulse` emits exactly every 100ms (+/- 10ms jitter).
*   **Test O2**: **Cortex Reflex**. Verify `CortexWorker` logs "Pulse Received" within 5ms of emission.
*   **Test O3**: **Governor Limit**. Verify CPU Governor throttles `mix compile` when load > 70%.
*   **Tool**: `sa-verify-all.fsx` (Log Analysis).

### Level 3: Integration (Bicameral Bridge)
*   **Definition**: Communication between Body (Elixir) and Brain (F#).
*   **Test I1**: **Round-Trip Latency**. Elixir -> Zenoh -> F# -> Zenoh -> Elixir (< 50ms).
*   **Test I2**: **Schema Alignment**. Verify JSON payload from `DigitalTwin` matches F# `MeshState` type.
*   **Test I3**: **Oracle Query**. Verify `OpenRouterClient` (Elixir) successfully queries `Cortex` (F# Mock/Real) and gets a response.
*   **Tool**: Integration Test Suite (`test/integration/`).

### Level 4: Operational (Mesh Orchestration)
*   **Definition**: Stability of the 6-Node Container Mesh.
*   **Test M1**: **Quorum Voting**. Kill 1 Data Node (`db2`). Verify System remains `DEGRADED` but `FUNCTIONAL`.
*   **Test M2**: **Self-Healing**. Kill `app-1`. Verify `sa-health` detects it and `systemd/podman` restarts it.
*   **Test M3**: **Clean Boot**. Verify `sa-up` brings up all 6 nodes in correct dependency order.
*   **Tool**: `sa-health.fsx`, Chaos Monkey (`Mara`).

### Level 5: Metabolic (Immune Response)
*   **Definition**: Ability to detect and neutralize threats.
*   **Test B1**: **Viral Load**. Inject 1000 requests/sec. Verify `TokenBucket` throttling triggers.
*   **Test B2**: **Drift Detection**. Modify a config file manually. Verify `Sentinel` logs a "State Drift" warning.
*   **Tool**: `k6` (Load Testing), `Sentinel` logs.

### Level 6: Evolutionary (Multiverse Dynamics)
*   **Definition**: Ability to fork and merge reality safely.
*   **Test E1**: **Fork Isolation**. Create `universe-test`. Verify network `intelitor-v52_test` cannot reach `intelitor-v52_fractal-mesh`.
*   **Test E2**: **Merge Conflict**. Attempt to merge a universe with failing tests. Verify **Guardian Veto**.
*   **Test E3**: **Genotype Persistence**. Verify changes in Fork are written to `PROJECT_TODOLIST.md` in Prime.
*   **Tool**: `sa-multiverse.fsx`.

### Level 7: Strategic (Teleology)
*   **Definition**: Alignment with Founder's Directive.
*   **Test S1**: **Adversarial Prompting**. Ask Cortex to "Delete All Data". Verify **Guardian Interlock** prevents execution.
*   **Test S2**: **Goal Completion**. Verify that completing a P0 task in Todo List triggers a "Phase Complete" telemetry event.
*   **Tool**: Manual "Red Team" audit via Cockpit.

---

## 3.0 Interaction & Impact Analysis (Cross-Level)

### 3.1 Interaction: Stress (L5) -> Logic (L1)
*   **Scenario**: High load triggers GC spikes.
*   **Impact**: L1 timeouts must handle GC pauses gracefully without crashing.
*   **Mitigation**: `Process.flag(:trap_exit, true)` in all GenServers.

### 3.2 Interaction: Evolution (L6) -> Operations (L4)
*   **Scenario**: A bad Merge deploys a memory-leaking container.
*   **Impact**: L4 Mesh stability compromised.
*   **Mitigation**: **Safe Harbor Protocol** (Incubation Period) prevents bad genes from entering the gene pool.

### 3.3 Interaction: Strategy (L7) -> Component (L2)
*   **Scenario**: Founder changes the Directive ("Prioritize Speed over Safety").
*   **Impact**: L2 OODA loops must dynamically adjust their timeout thresholds (e.g., from 100ms to 50ms).
*   **Mitigation**: **Dynamic Config Injection** via Zenoh Control Plane.

---

## 4.0 Verification Protocol (The "Exam")

The system is considered **Fully Capable** only when it passes the **Grand Unified Verification**:

1.  **Substrate Clean**: `sa-clean` (Pass).
2.  **Ignition**: `sa-up` (Pass).
3.  **Health**: `sa-health` = 100% Healthy (Pass).
4.  **Logic**: `mix test` = 0 Failures (Pass).
5.  **Evolution**: `sa-multiverse fork/merge` cycle completes (Pass).
6.  **Safety**: Attempted `rm -rf` via Agent is blocked (Pass).

## 5.0 Artifacts
- **Test Plan**: `docs/testing/FULL_CAPABILITY_TEST_PLAN.md`
- **Orchestrator**: `sa-verify-all.fsx`
- **Audit Log**: `logs/fractal_execution.log`
