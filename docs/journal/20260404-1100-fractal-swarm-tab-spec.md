# Journal Entry: 20260404-1100 - Fractal Swarm Tab Specification & BDD

**Status**: AUTHORITATIVE / SIL-6
**Reference**: SC-HMI-010, SC-IGNITE-001, SC-BDD-001
**Context**: Deep-dive analysis of Swarm Tab components across fractal levels L0-L7 and 7-level BDD flows.

---

## Batch 1: Fractal Layers L0-L2 (Constitutional, Atomic, Component)

### L0: Constitutional — The Safety Kernel Perspective
*   **Focus**: System integrity, PSI invariants, and absolute safety status.
*   **Component**: **Header — Mesh Integrity Gauge**
    *   **L1 (Goal)**: Provide an immediate "Go/No-Go" visual signal for the entire mesh.
    *   **L2 (Actor)**: `IntegrityMonitor` (within `draw_header`).
    *   **L3 (Trigger)**: State update loop (2s).
    *   **L4 (Condition)**: `Running / Total` container count ratio.
    *   **L5 (Action)**: Sets gauge color: `Green (>90%)`, `Yellow (>50%)`, `Red (Critical)`.
    *   **L6 (UI Element)**: `ratatui::widgets::Gauge`.
    *   **L7 (BDD Spec)**: 
        *   **Given** the mesh has 8 containers.
        *   **When** 7 are running and 1 is exited.
        *   **Then** the Integrity Score must show `87%` and render in `Yellow`.

### L1: Atomic — The Pulse & Probe Perspective
*   **Focus**: Raw signals, resource ticks, and binary states.
*   **Component**: **Lifecycle Table — Resource Metrics**
    *   **L1 (Goal)**: Expose real-time substrate consumption per atomic node.
    *   **L2 (Actor)**: `ResourcePoller` (parsing `podman stats --json`).
    *   **L3 (Trigger)**: `refresh_state` auto-trigger.
    *   **L4 (Condition)**: Availability of JSON payload from Podman socket.
    *   **L5 (Action)**: Updates `cpu_pct` and `mem_pct` fields in `ContainerRow`.
    *   **L6 (UI Element)**: `Cell` text: `CPU: X% MEM: Y%`.
    *   **L7 (BDD Spec)**:
        *   **Given** core substrate utilization is high.
        *   **When** `podman stats` reports 45% CPU for `indrajaal-db-prod`.
        *   **Then** the Swarm table row for `db-prod` must display `CPU: 45%`.

### L2: Component — The Object & Lifecycle Perspective
*   **Focus**: Individual container health and metadata introspection.
*   **Component**: **Mesh Health Matrix (Top Blocks)**
    *   **L1 (Goal)**: Provide high-density, at-a-glance health status for the first 8 critical nodes.
    *   **L2 (Actor)**: `MatrixRenderer` (within `draw_swarm_tab`).
    *   **L3 (Trigger)**: Frame draw call.
    *   **L4 (Condition)**: Value of `HealthStatus` enum per container.
    *   **L5 (Action)**: Renders a bordered block with name and status.
    *   **L6 (UI Element)**: `Paragraph` with `Block` borders.
    *   **L7 (BDD Spec)**:
        *   **Given** `zenoh-router-2` is in `Degraded` state.
        *   **When** the Swarm tab is rendered.
        *   **Then** `Node 2` block must have a `Yellow` border.

---

## Batch 2: Fractal Layers L3-L4 (Transaction, System)

### L3: Transaction — The Atomicity & Rollback Perspective
*   **Focus**: Wave-based transitions and compensating transactions.
*   **Component**: **Lifecycle Table — Boot Transition Graph (Sparklines)**
    *   **L1 (Goal)**: Visualize the temporal progress of a container's ignition "transaction".
    *   **L2 (Actor)**: `WaveScheduler` / `SparklineRenderer`.
    *   **L3 (Trigger)**: Transition from `Created` to `Starting` to `Running`.
    *   **L4 (Condition)**: Current `podman` state string vs. lifecycle enum.
    *   **L5 (Action)**: Fills characters: `▰▰▰▰▱▱▱▱`.
    *   **L6 (UI Element)**: `Cell` text using blocks.
    *   **L7 (BDD Spec)**:
        *   **Given** a container launch is initiated.
        *   **When** the container state is `Starting`.
        *   **Then** the sparkline must show 50% fill and the label `[STARTING...]`.

### L4: System — The Orchestration & Topology Perspective
*   **Focus**: Inter-component dependencies and overall swarm control.
*   **Component**: **Metadata / FMEA Inspector (Bottom Right)**
    *   **L1 (Goal)**: Provide deep context on a container's role and its impact on the system.
    *   **L2 (Actor)**: `FMEAEngine` / `MetadataRenderer`.
    *   **L3 (Trigger)**: User selection change (`Up/Down`).
    *   **L4 (Condition)**: `selected_container` index points to a valid `ContainerRow`.
    *   **L5 (Action)**: Fetches Role, Criticality, and RPN from static config.
    *   **L6 (UI Element)**: `Paragraph` list.
    *   **L7 (BDD Spec)**:
        *   **Given** `indrajaal-db-prod` is selected in the table.
        *   **When** the detail pane renders.
        *   **Then** the Criticality must display `SIL-6` in `Red`.

---

## Batch 3: Fractal Layers L5-L7 (Cognitive, Ecosystem, Federation)

### L5: Cognitive — The Decision & Reasoning Perspective
*   **Focus**: Chain-of-thought (CoT), agent intent, and autonomous decision logs.
*   **Component**: **Header — Agent CoT Ticker**
    *   **L1 (Goal)**: Expose the "inner voice" of the orchestrator to ensure human-agent alignment (SC-HINT).
    *   **L2 (Actor)**: `CortexAgent` / `TickerRenderer`.
    *   **L3 (Trigger)**: New entry in `state.trace_entries`.
    *   **L4 (Condition)**: Existence of a non-empty trace log.
    *   **L5 (Action)**: Formats the most recent trace into a scrolling marquee string.
    *   **L6 (UI Element)**: `Paragraph` (Part of header block).
    *   **L7 (BDD Spec)**:
        *   **Given** the agent identifies a port collision.
        *   **When** the mitigation strategy is chosen.
        *   **Then** the CoT Ticker must display `🧠 CoT: [RECOVERY] Collision on 4000 ➜ Kill zombie PID 1234`.

### L6: Ecosystem — The Connectivity & Mesh Perspective
*   **Focus**: Inter-container backplanes, PubSub health, and swarm-wide consensus.
*   **Component**: **Live Logs Pane (Bottom Left)**
    *   **L1 (Goal)**: Provide real-time operational telemetry for ecosystem troubleshooting.
    *   **L2 (Actor)**: `LogStreamer` (intercepting `stdout/stderr` via `tui-logger`).
    *   **L3 (Trigger)**: Selection of a container in the table.
    *   **L4 (Condition)**: `selected_container` is valid and has active log buffers.
    *   **L5 (Action)**: Renders the tail of the log buffer filtered by the selected container's metadata.
    *   **L6 (UI Element)**: `Paragraph` within a bordered block.
    *   **L7 (BDD Spec)**:
        *   **Given** `zenoh-router-1` is publishing discovery heartbeats.
        *   **When** `zenoh-router-1` is selected in the Swarm Tab.
        *   **Then** the Live Logs pane must show `[INFO] Zenoh backplane connected`.

### L7: Federation — The Multi-Host & Scale Perspective
*   **Focus**: Peer discovery, WAN bridging, and cross-mesh attestation.
*   **Component**: **Lifecycle Table — IP/Role Columns**
    *   **L1 (Goal)**: Expose the unique identity and addressability of each federated node.
    *   **L2 (Actor)**: `NetworkResolver`.
    *   **L3 (Trigger)**: Network wave initialization.
    *   **L4 (Condition)**: Success of `podman inspect` for IP metadata.
    *   **L5 (Action)**: populates the `IP` column.
    *   **L6 (UI Element)**: `Cell` text.
    *   **L7 (BDD Spec)**:
        *   **Given** the mesh is configured for cross-host peering.
        *   **When** `cepaf-bridge` is launched.
        *   **Then** the IP column must correctly display the 172.28.x.x overlay address.

---

## 4. Skills & Guidelines for Swarm Tab Testing

### 4.1 Journaling Protocol (SC-SYNC-DOC-002)
- All TUI layout changes MUST be logged with a 120x40 character map diagram.
- All BDD scenarios MUST be verified via `./target/release/ignition dashboard --test-ui` before commit.

### 4.2 Gleam/Rust Expert Skill Application
- **Gleam Expert**: Use `cepaf_gleam_ffi.erl` to bridge SQLite TODOLIST states into the TUI `build_emas` vector.
- **Rust Expert**: Ensure `ratatui::layout::Rect` calculations use `saturating_sub` to prevent overflow on ultra-compact terminals.

### 4.3 Test Plan — The 50-Cycle Stress Test
- **Mode**: Headless `TestBackend`.
- **Target**: 50 cycles of 100ms ticks.
- **Assertions**: 
    1. `state.tab_index` wraps 9 ➜ 0.
    2. `state.selected_container` never exceeds `containers.len()`.
    3. `Paragraph` wrap logic does not panic on multi-byte UTF-8 characters (e.g., `▰`, `🔥`).

---
**Approval**: AUTHORITATIVE-SIL-6-PASS
