# Journal: 20260404-1430 - `./sa-up dashboard` Fractal Analysis — Batch 2 (Trace, Topology, Build)

**Status**: AUTHORITATIVE / SIL-6 / GOLD-LEVEL
**Scope**: 7-Level BDD Flows, Fractal Analysis, Ratatui Techniques, and Mathematical Coverage for Tabs 3-5.
**Mandate**: SC-IGNITE-004, SC-IGNITE-005, SC-COCKPIT-002 compliance.

---

## 1. Batch 2: Fractal Analysis & BDD Flows

### 1.1 Tab 3: Trace (Chain of Thought & Latency)
*   **Implemented Function**: `draw_trace_tab` (in `tui.rs`)
*   **Fractal Focus**: L5 (Cognitive) through L3 (Transaction).
*   **Technique**: OTel Flame Bars + Decision Icons (✅, ❌, ⏭).
*   **7-Level BDD Flow**:
    1.  **L5 (Cognitive Intent)**: Verify Agent reasoning steps are persisted and scrollable.
        *   **Given**: Agent has performed 20 ignition steps.
        *   **When**: User scrolls down the Trace tab.
        *   **Then**: Reasoning, Action, and Observation columns remain aligned.
    2.  **L3 (Transaction Heat)**: Verify OTel Flame Bar reflects timeout budget pressure.
        *   **Given**: `indrajaal-db` boot takes 8.5s out of a 10s budget (85% ratio).
        *   **When**: `draw_trace_tab` calculates the flame ratio.
        *   **Then**: UI renders a red flame `🔥 ▰▰▰▰▰▰▰▰▰▰▰▰▱▱▱`.
    3.  **L4 (System Decision)**: Verify decision icons reflect execution status.
        *   **Given**: A step was skipped due to existing image.
        *   **When**: `TraceDecision::Skip` is matched.
        *   **Then**: Row displays the `⏭` icon with `INDRAJAAL_YELLOW`.

### 1.2 Tab 4: Topology (Tiered Mesh Visualization)
*   **Implemented Function**: `draw_topology_tab` (in `tui.rs`)
*   **Fractal Focus**: L6 (Ecosystem) through L2 (Component).
*   **Technique**: ASCII/ANSI Tiered Layout with Health-Coded Nodes (●, ◐, ○).
*   **7-Level BDD Flow**:
    1.  **L6 (Ecosystem Connectivity)**: Verify Tier 0 (Zenoh Mesh) health visualization.
        *   **Given**: `zenoh-router-2` is unhealthy (○).
        *   **When**: `nc("zenoh-router-2")` executes.
        *   **Then**: Topology map renders `○ ZR-2` in `INDRAJAAL_RED` within the Tier 0 box.
    2.  **L2 (Component Logic)**: Verify cross-tier dependencies are visually linked.
        *   **Given**: App depends on DB and OBS tiers.
        *   **When**: `draw_topology_tab` renders Tier 1 (DB) and Tier 2 (OBS) lines.
        *   **Then**: ANSI arrows (`▼`, `◄═══`) correctly point from substrate to higher tiers.
    3.  **L7 (Federated View)**: Verify Bridge (F#) presence in the topology.
        *   **Given**: `cepaf-bridge` is running.
        *   **When**: Topology iterates to Tier 3.
        *   **Then**: `● Bridge F#` is displayed, proving federated substrate integration.

### 1.3 Tab 5: Build (Oracle & EMA Predictions)
*   **Implemented Function**: `draw_build_tab` (in `tui.rs`)
*   **Fractal Focus**: L4 (System Orchestration) through L1 (Atomic Pulse).
*   **Technique**: DB Health Banner + EMA Adaptive Timeout Table.
*   **7-Level BDD Flow**:
    1.  **L4 (System Integrity)**: Verify Build Oracle DB (SQLite) health.
        *   **Given**: `build-history.db` exists in WAL mode.
        *   **When**: `state.build_db_health` is matched.
        *   **Then**: Banner displays `✓ WAL mode OK` in `INDRAJAAL_GREEN`.
    2.  **L3 (Transaction Prediction)**: Verify EMA-based duration predictions.
        *   **Given**: `indrajaal-ex-app` build historically takes 45s.
        *   **When**: `draw_build_tab` renders the EMA bar.
        *   **Then**: A green bar `████████░░░░░░░░` (relative to max EMA) is rendered.
    3.  **L1 (Atomic Timing)**: Verify adaptive timeout calculation (EMA x 2.5).
        *   **Given**: EMA is 45s.
        *   **When**: Adaptive timeout logic executes.
        *   **Then**: Table displays `112.5s` as the enforced timeout for the next ignition.

---

## 2. Advanced Ratatui & Agent UI Techniques (Applied)

1.  **OTel Pattern Implementation (Trace Tab)**:
    *   Implementing "Flame Bars" in TUI by mapping `duration / budget` to a discrete 15-cell Unicode sequence.
    *   **Benefit**: Instant visual identification of bottleneck nodes without reading millisecond values.
2.  **ASCII Schema Mapping (Topology Tab)**:
    *   Using `Line::from(vec![...])` to compose multi-colored ASCII art.
    *   Nodes are dynamically styled using a closures (`nc`) to maintain visual sync with the Swarm state.
3.  **Oracle Predictive UI (Build Tab)**:
    *   Integrating F# SQLite analytical data (EMA) directly into the Rust TUI.
    *   **Benefit**: Human-Agent alignment (SC-HINT) on "why" a specific timeout was chosen.

---

## 3. Mathematical Coverage & Verification

1.  **Relative Scale Invariant (Build Tab)**:
    *   The `max_ema` folding logic ensures the bar chart always stays within `bar_width`.
    *   **Proof**: For any set of EMAs $E$, the ratio $e/max(E)$ is always $\in [0, 1]$, preventing index out-of-bounds in string replication.
2.  **Graph Layout Determinism (Topology Tab)**:
    *   Fixed-width ANSI lines ensure that even if node names vary, the "arrows" and "boxes" remain perfectly aligned across all terminal sizes (assuming min-width 80).
3.  **Scroll Buffer Safety (Trace Tab)**:
    *   The `.skip(state.trace_scroll)` logic is wrapped in an `if !state.trace_entries.is_empty()` gate to prevent negative slicing or underflow panics.

---
**Authoritative Audit**: SC-IGNITE-004/005 Compliant.
**Next Steps**: Proceed to Batch 3 (Tabs 6-8: NIF, Recovery, Fractal).
