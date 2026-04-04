# Journal: 20260404-1400 - `./sa-up dashboard` Fractal Analysis — Batch 1 (Swarm, Governor, Checks)

**Status**: AUTHORITATIVE / SIL-6 / GOLD-LEVEL
**Scope**: 7-Level BDD Flows, Fractal Analysis, Ratatui Techniques, and Mathematical Coverage for Tabs 0-2.
**Mandate**: SC-HMI-010, SC-COV-012, SC-CPU-GOV compliance.

---

## 1. Batch 1: Fractal Analysis & BDD Flows

### 1.1 Tab 0: Swarm (Substrate Orchestration)
*   **Implemented Function**: `draw_swarm_tab` (in `tui.rs`)
*   **Fractal Focus**: L0 (Constitutional) through L7 (Federation).
*   **Technique**: High-density resource table + visual status matrix.
*   **7-Level BDD Flow**:
    1.  **L0 (Constitutional)**: Verify Mesh Integrity Score reflects real-time 2oo3 quorum.
        *   **Given**: 16 nodes defined; 14 running.
        *   **When**: `draw_header` calculates `running / total`.
        *   **Then**: Gauge renders at 87.5% with `INDRAJAAL_YELLOW`.
    2.  **L1 (Atomic)**: Verify individual container resource ticks (CPU/MEM) are captured.
        *   **Given**: `indrajaal-db` CPU spikes to 92%.
        *   **When**: `podman stats` populates the `ContainerRow`.
        *   **Then**: Resource column displays `CPU: 92%` in blinking `INDRAJAAL_RED`.
    3.  **L2 (Component)**: Verify grid matrix accurately maps to node status.
        *   **Given**: Node index 5 (`cortex`) is in `Degraded` status.
        *   **When**: `matrix_chunks` loop renders the grid.
        *   **Then**: Block #5 displays a yellow border and "Degraded" label.
    4.  **L3 (Transaction)**: Verify wave-based boot animation (PULLING/CREATING).
        *   **Given**: Container state is "Created".
        *   **When**: `visual_bar` string logic executes.
        *   **Then**: Sparkline shows 20% fill with `[CREATED]` suffix.
    5.  **L4 (System)**: Verify selection-driven metadata inspection for RCA.
        *   **Given**: User highlights `indrajaal-api`.
        *   **When**: `state.selected_container` index matches.
        *   **Then**: Detail pane shows `SIL-6 / High Criticality` metadata.
    6.  **L5 (Cognitive)**: Verify Agent CoT Ticker is visible.
        *   **Given**: Agent detects a ghost lock.
        *   **When**: `draw_header` pulls the latest `TraceEntry`.
        *   **Then**: Marquee ticker displays "🧠 CoT: [Purging] Ghost Lock".
    7.  **L6/L7 (Ecosystem/Federation)**: Verify overlay network addressability.
        *   **Given**: Mesh converged on `172.28.0.0/24`.
        *   **When**: `draw_swarm_tab` renders IP column.
        *   **Then**: Node IPs are correctly displayed for all 16 holons.

### 1.2 Tab 1: Governor (Substrate Heatmap & Throttling)
*   **Implemented Function**: `draw_governor_tab` (in `tui.rs`)
*   **Fractal Focus**: L1 (Atomic) through L4 (System).
*   **Technique**: CPU Sparkline history + Parallelism constraint table.
*   **7-Level BDD Flow**:
    1.  **L1 (Atomic Pulse)**: Verify CPU sparkline updates in real-time.
        *   **Given**: Host CPU load fluctuates (60% to 90%).
        *   **When**: `DashboardState::update` pushes ticks to history buffer.
        *   **Then**: `ratatui::widgets::Sparkline` renders the last 100 ticks.
    2.  **L2 (Component Heat)**: Verify substrate heatmap reflects core pressure.
        *   **Given**: Logical cores 4-7 are under heavy load.
        *   **When**: `Substrate Heatmap` block renders.
        *   **Then**: Core indicators transition from `INDRAJAAL_GREEN` to `INDRAJAAL_RED`.
    3.  **L3 (Transaction Flow)**: Verify parallelism throttling (SC-CPU-GOV).
        *   **Given**: Global CPU > 85%.
        *   **When**: Governor state is updated.
        *   **Then**: `Parallelism` table shows `Max Jobs` reduced from 16 to 6.
    4.  **L4 (System Gate)**: Verify governor "Wait Loop" state.
        *   **Given**: CPU remains > 90% for 3 cycles.
        *   **When**: `draw_governor_tab` evaluates `state.governor_mode`.
        *   **Then**: UI displays high-contrast "PAUSED: WAITING FOR CPU COOLDOWN" modal.

### 1.3 Tab 2: Checks (State Vector & BIST/POST)
*   **Implemented Function**: `draw_checks_tab` (in `tui.rs`)
*   **Fractal Focus**: L0 (Constitutional) through L4 (System).
*   **Technique**: 70/30 split layout with State Vector [C,M,N,Z,H,Q].
*   **7-Level BDD Flow**:
    1.  **L0 (Constitutional)**: Verify the 6-Factor State Vector (SV).
        *   **Given**: Compile (C), Migrations (M), Nodes (N), Zenoh (Z), Health (H), Quorum (Q).
        *   **When**: `draw_checks_tab` evaluates `state.state_vector`.
        *   **Then**: SV displays `[C, M, N, Z, H, Q]` with individual green/red colors.
    2.  **L1 (Atomic BIST)**: Verify low-level NIF/Port probes.
        *   **Given**: Zenoh NIF fails to load.
        *   **When**: `check_zenoh_nif()` probe executes.
        *   **Then**: The `Z` (Zenoh) factor in the SV transitions to red.
    3.  **L4 (System Integrity)**: Verify overall system validity.
        *   **Given**: All 6 factors in the SV are true.
        *   **When**: `sv.is_valid()` executes.
        *   **Then**: UI displays "VALID ✓" in bold `INDRAJAAL_GREEN`.

---

## 2. Advanced Ratatui & Agent UI Techniques (Applied)

1.  **Asynchronous MPSC Wiring**:
    *   Podman stats and OTel spans are piped into a `tokio::sync::mpsc` channel.
    *   The `tui_loop` uses `poll_event` to process UI input while simultaneously draining the channel.
    *   **Benefit**: Zero latency in TUI rendering regardless of backend load.
2.  **Constraint Reflow (DevUI)**:
    *   The `Body` area uses `Constraint::Min(10)` and `Constraint::Percentage(X)`.
    *   When an agent enters a "Thinking" state, the `draw_header` expands to `Constraint::Length(5)` to show more CoT context.
3.  **Braille Sparklines**:
    *   CPU history in the Governor tab uses Braille symbols to double vertical resolution within a single row.
4.  **Behavioral State Modals**:
    *   Destructive actions trigger `ConfirmModal` state. The UI thread halts event propagation to the dashboard until the modal is resolved.

---

## 3. Mathematical Coverage & Verification

1.  **Graph Theory (Prime Path Coverage)**:
    *   The 12-tab state machine is verified by a test harness that injects `KeyCode::Right` 11 times and ensures no layout panic occurs at any `tab_index`.
2.  **Boundary Stress (80x24 Invariant)**:
    *   Verified via `TestBackend` at 80x24 resolution.
    *   All `Layout::split` calls use `saturating_sub` or `Constraint::Min` to prevent negative area panics.
3.  **State Entropy (SC-COV-012)**:
    *   Tests inject mock vectors where `containers.len() == 0`, `containers.len() == 100`, and `cpu_pct == 255` (overflow simulation) to verify UI resilience.

---
**Authoritative Audit**: SC-HMI-010 Compliant.
**Next Steps**: Proceed to Batch 2 (Tabs 3-5: Trace, Topology, Build).
