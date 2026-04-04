# Journal Entry: 20260404-1200 - Comprehensive Swarm Tab Test Specification

**Status**: AUTHORITATIVE / SIL-6
**Goal**: Document implemented functions and fractal test scenarios for the `./sa-up dashboard` Swarm Tab.
**Framework**: Fractal Level (L0-L7) x Component x 7-Level BDD Flow.

---

## 1. Batch 1: Layers L0-L2 (Constitutional, Atomic, Component)

### L0: Constitutional — Header: Mesh Integrity Gauge
*   **Implemented Function**: `draw_header` (in `tui.rs`)
*   **7-Level BDD Flow**:
    1.  **Scenario**: Verify Mesh Integrity Gauge reflects real-time health consensus.
    2.  **Fractal Layer**: L0 (Constitutional / Invariant).
    3.  **Given**: A mesh of 8 containers where exactly 2 have crashed (HealthStatus::Unhealthy).
    4.  **When**: The 2s auto-refresh cycle triggers `refresh_state`.
    5.  **System Response**: The `running_count` is calculated as 6.
    6.  **UI Verification**: `Mesh Integrity Score` gauge renders at `75%` with `INDRAJAAL_YELLOW` color.
    7.  **Fractal Impact**: Invariant "Quorum Safety" is monitored; human operator is alerted to substrate drift.

### L1: Atomic — Lifecycle Table: Resource Metrics
*   **Implemented Function**: `draw_swarm_tab` -> `Table::new` (in `tui.rs`)
*   **7-Level BDD Flow**:
    1.  **Scenario**: Verify individual container resource ticks are captured and displayed.
    2.  **Fractal Layer**: L1 (Atomic / Raw Pulse).
    3.  **Given**: `indrajaal-db-prod` is consuming 12% CPU according to `podman stats`.
    4.  **When**: `podman::get_all_stats()` is parsed into the `ContainerRow`.
    5.  **System Response**: `cpu_pct` field for `db-prod` is updated to `12`.
    6.  **UI Verification**: The `Resources` column for `indrajaal-db-prod` displays `CPU: 12% MEM: X%`.
    7.  **Fractal Impact**: Atomic substrate pressure is visualized, enabling L5 cognitive scaling.

### L2: Component — Mesh Health Matrix: Node Blocks
*   **Implemented Function**: `draw_swarm_tab` -> `matrix_chunks` loop (in `tui.rs`)
*   **7-Level BDD Flow**:
    1.  **Scenario**: Verify high-density health matrix reflects individual component objects.
    2.  **Fractal Layer**: L2 (Component / Object).
    3.  **Given**: `zenoh-router-3` is in `Degraded` status (Starting).
    4.  **When**: `draw_swarm_tab` iterates over `state.containers`.
    5.  **System Response**: Match arm selects `INDRAJAAL_YELLOW` for index 2.
    6.  **UI Verification**: The block labeled `Node 3` renders a yellow border and `Starting` status.
    7.  **Fractal Impact**: Human spatial recognition is mapped to component lifecycle states.

---

## 2. Batch 2: Layers L3-L5 (Transaction, System, Cognitive)

### L3: Transaction — Lifecycle Table: Boot Transition Sparklines
*   **Implemented Function**: `draw_swarm_tab` -> `visual_bar` mapping (in `tui.rs`)
*   **7-Level BDD Flow**:
    1.  **Scenario**: Verify wave-based transition state is animated correctly.
    2.  **Fractal Layer**: L3 (Transaction / Wave).
    3.  **Given**: A container has been `Created` but not yet `Started`.
    4.  **When**: `HealthStatus::Unhealthy` (with "created" status string) is processed.
    5.  **System Response**: `visual_bar` is set to `▰▰▰▰▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱ [PULLING/CREATING]`.
    6.  **UI Verification**: The `Boot Transition Graph` column shows 20% fill in `INDRAJAAL_RED`.
    7.  **Fractal Impact**: Provides visibility into the latency of image pulls vs. binary execution.

### L4: System — FMEA Metadata Pane: Node Details
*   **Implemented Function**: `draw_swarm_tab` -> `metadata_block` (in `tui.rs`)
*   **7-Level BDD Flow**:
    1.  **Scenario**: Verify selection-driven metadata inspection for system orchestration.
    2.  **Fractal Layer**: L4 (System / Orchestration).
    3.  **Given**: The user has navigated down to select `indrajaal-cortex`.
    4.  **When**: `state.selected_container` index matches the Cortex row.
    5.  **System Response**: The metadata lookup retrieves `Role: Cognitive` and `Criticality: SIL-6`.
    6.  **UI Verification**: The `FMEA / Metadata` pane displays `SIL-6` in `Red` and the active playbook.
    7.  **Fractal Impact**: Operator gains orchestration context needed for manual override or RCA.

### L5: Cognitive — Header: Agent CoT Ticker
*   **Implemented Function**: `draw_header` -> `latest_thought` (in `tui.rs`)
*   **7-Level BDD Flow**:
    1.  **Scenario**: Verify agent reasoning steps are visible to the operator.
    2.  **Fractal Layer**: L5 (Cognitive / Intent).
    3.  **Given**: The agent has just detected a `Ghost Container` and decided to purge it.
    4.  **When**: A `TraceEntry` is pushed to `state.trace_entries`.
    5.  **System Response**: The header logic pulls the `.last()` entry.
    6.  **UI Verification**: The scrolling ticker displays `🧠 CoT: [Purging] Stale indrajaal-db-prod detected`.
    7.  **Fractal Impact**: Human-Agent alignment (SC-HINT) is maintained during autonomous remediation.

---

## 3. Batch 3: Layers L6-L7 & Testing Infrastructure

### L6: Ecosystem — Live Logs Pane: Node Telemetry
*   **Implemented Function**: `draw_swarm_tab` -> `log_block` (in `tui.rs`)
*   **7-Level BDD Flow**:
    1.  **Scenario**: Verify real-time log streaming for ecosystem troubleshooting.
    2.  **Fractal Layer**: L6 (Ecosystem / Connectivity).
    3.  **Given**: `zenoh-router-1` is emitting "Backplane Connected" signals.
    4.  **When**: `zenoh-router-1` is selected via the `selected_container` index.
    5.  **System Response**: The log buffer for the selected ID is retrieved from the `tui-logger` repository.
    6.  **UI Verification**: The `Live Logs: zenoh-router-1` pane displays the corresponding info log string.
    7.  **Fractal Impact**: Ecosystem communication health is proven via empirical telemetry rather than inferred state.

### L7: Federation — Lifecycle Table: IP & Role Identification
*   **Implemented Function**: `draw_swarm_tab` -> `Table::new` (in `tui.rs`)
*   **7-Level BDD Flow**:
    1.  **Scenario**: Verify node identity and addressability within the federated mesh.
    2.  **Fractal Layer**: L7 (Federation / Convergence).
    3.  **Given**: The mesh has converged on the `172.28.0.0/24` overlay network.
    4.  **When**: `podman::container_ip(name)` successfully returns the internal address.
    5.  **System Response**: The `ip` field in `ContainerRow` is populated with the overlay string.
    6.  **UI Verification**: The `IP` column in the swarm table displays `172.28.0.10` for the app container.
    7.  **Fractal Impact**: Global addressability is verified, enabling cross-host peering and WAN bridging.

---

## 4. Testing Infrastructure & Operational Guidelines

### 4.1 Test Plan — The 50-Cycle UI Harness
*   **Execution**: `./target/release/ignition dashboard --test-ui`
*   **Logic**: Uses `ratatui::backend::TestBackend` to simulate 50 rendering cycles at 10ms intervals.
*   **Stress Vectors**:
    *   **Tab Switching**: Rapidly cycles `tab_index` 0-9 to verify layout stability and constraint math.
    *   **Selection Mutation**: Jumps `selected_container` index to verify metadata and log pane lookup resilience.
    *   **Overflow Assertions**: Validates that long container names and deep trace strings are truncated via `Constraint` rather than panicking.

### 4.2 Journaling Guidelines (SC-SYNC-DOC-002)
*   **Artifact Sync**: Every TUI modification MUST be accompanied by a character map diagram in the journal.
*   **BDD Mapping**: Every new UI component MUST include a 7-level BDD spec following the "Given/When/Then/Fractal" architecture.
*   **Authoritative State**: Plan updates MUST only be performed via `./sa-plan` to maintain F# SQLite parity.

### 4.3 Skill Application Matrix
*   **Rust Skill**: Implementation of `saturating_sub` on all `Rect` calculations to ensure SIL-6 stability on micro-terminals (80x24).
*   **Gleam Skill**: Bridging the F# `Planning.db` into the Rust TUI state vector via the `cepaf_gleam_ffi` layer.
*   **Automation Skill**: Continuous execution of the 50-cycle TUI stress test within the CI/CD pipeline.

---

## 5. Batch 4: Advanced Ratatui & Agent UI Techniques

### 5.1 Real-Time Wired Data & Async Control
*   **Technique**: **MPSC Command/Event Bus**
    *   **Implementation**: Use `tokio::sync::mpsc` to pipe podman log streams and OTel spans directly into the TUI state without locking the UI thread.
    *   **Behavioral State**: The `DashboardState` acts as a reactive model. Background tasks push "Delta" updates (e.g., `UpdateCpu(u8)`) which are applied by an `update()` function prior to the next `draw()` call.
*   **Technique**: **Atomic State Gating**
    *   **Implementation**: Critical operations (like `Ghost Purge`) require an `AG-UI ApprovalToken`. The UI renders a modal, and the background task `awaits` a cross-thread signal from the `crossterm` input handler.

### 5.2 Information Density & Generative UI (AG-UI)
*   **Technique**: **Braille Substrate Graphs**
    *   **Implementation**: Using `ratatui::symbols::braille` to render high-resolution history charts (e.g., CPU history) within a single character row.
*   **Technique**: **Dynamic Constraint Reflow**
    *   **Implementation**: Layout constraints that adjust based on `state.tab_index` and `state.selected_container`. For example, the `Live Logs` pane expands to 80% height when "Focus Mode" is toggled.
*   **Technique**: **Conditional Widget Composition**
    *   **Implementation**: A "Master Component" that switches its internal rendering logic based on the `Criticality` enum (e.g., SIL-6 nodes get a distinct double-border and flashing highlight).

### 5.3 Behavioral State & Cognitive Alignment (DevUI)
*   **Technique**: **Chain-of-Thought (CoT) Ticker**
    *   **Implementation**: A circular ring buffer of reasoning strings. The `TickerRenderer` implements a modulo-based string slice to create a smooth scrolling marquee effect in the header.
*   **Technique**: **Contextual FMEA Radar**
    *   **Implementation**: Mapping real-time health errors to static Failure Mode profiles. If a container enters `Degraded`, the UI automatically pulls the corresponding `RPN` and `Mitigation Playbook` into the detail pane.
*   **Technique**: **Intent-Aware Navigation**
    *   **Implementation**: The agent can "request" a tab switch (e.g., switching the user to the `Recovery` tab automatically when a cascade is detected) to guide human attention to critical events.

### 5.4 Robust Testing & Verification
*   **Technique**: **Deterministic Fixture Injection**
    *   **Implementation**: Passing a `--mock-state` flag to load a pre-configured `DashboardState` from JSON, enabling BDD testing of complex failure scenarios (e.g., 3-node partition) without real containers.
*   **Technique**: **Snapshot Diffing (Layer 2)**
    *   **Implementation**: Capturing the `TestBackend` buffer as a string and comparing it against a "Golden Snapshot" to detect layout regressions during CSS-token updates.

---
**Authoritative Audit**: SC-HMI-010 Compliant.
**Next Steps**: Execute the 50-cycle stress test with these advanced techniques enabled.
