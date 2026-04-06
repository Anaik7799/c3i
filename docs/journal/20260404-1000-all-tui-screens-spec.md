# Indrajaal Ignition TUI — Comprehensive 7-Level Screen Specification
## Parts A-O — Authoritative Design & Behavior Blueprint

**Date**: 2026-04-04
**Compliance**: SC-HMI-010, SC-BDD-001, SC-IGNITE-001
**Framework**: Rust + Ratatui (Terminal-Native)

---

## PART A — APPLICATION BLUEPRINT

### A1. App Identity
- **Name**: Indrajaal C3I Ignition Hub
- **Purpose**: Autonomous container orchestration and real-time mesh verification.
- **Audience**: Site Reliability Engineers, Cybernetic Architects.
- **Tone**: Cyber-industrial, high-density, authoritative.

### A2. Page Inventory (Tab Navigation)
1. **P-SWRM (Tab 0)**: Swarm Lifecycle Dashboard.
2. **P-GOV (Tab 1)**: Substrate Governor & Telemetry.
3. **P-CHK (Tab 2)**: Pre-Flight & Verification Matrix.
4. **P-TRC (Tab 3)**: DevUI Trace & OTel Flame Graphs.
5. **P-TOP (Tab 4)**: Mesh Topology DAG & Zenoh Stats.
6. **P-BLD (Tab 5)**: Build Oracle EMA Predictions.
7. **P-NIF (Tab 6)**: NIF Binary Validation Gate.
8. **P-RCV (Tab 7)**: FMEA Recovery Playbooks.
9. **P-LOG (Tab 8)**: Mission Log Console.
10. **P-AGT (Tab 9)**: Agent UI / Copilot Reasoning.

---

## PART B — 7-LEVEL COMPONENT DETAIL (Example: MeshHealthMatrix)

### COMPONENT: MeshHealthMatrix (P-SWRM)
──────────────────────────────────────────────────────────────
**LEVEL 1 — IDENTITY**: `MeshHealthMatrix`. Reusable widget for top-tier health awareness.
**LEVEL 2 — STRUCTURE**: 8-column grid of colored blocks.
**LEVEL 3 — LAYOUT**: Length(5) rows, horizontal split Percentage(12) per node.
**LEVEL 4 — VISUAL STYLE**: Bordered blocks using `HealthStatus` colors.
**LEVEL 5 — STATE MATRIX**: `Healthy (Green)`, `Degraded (Yellow)`, `Unhealthy (Red)`, `Waiting (Dim)`.
**LEVEL 6 — BEHAVIOUR**: Updates box color instantly on 2s state vector synchronization.
**LEVEL 7 — DATA CONTRACT**: Consumes `Vec<ContainerRow>`.

---

## PART C — PAGE DESCRIPTIONS (Wired Functionality)

### C0. P-SWRM (Swarm)
- **Diagram**: [8-Node Matrix] | [Lifecycle Table with Sparklines] | [Selected Node Log Pane]
- **Behavior**: `Up/Down` selects a node. The `Metadata` and `Live Logs` panes update to reflect the selection.
- **BDD**: `Given` node 3 is selected, `When` state updates, `Then` logs for node 3 are visible.

### C1. P-GOV (Governor)
- **Diagram**: [CPU/Mem/Disk/Net Heatmap] | [60-Sample CPU Sparkline] | [Parallelism Config]
- **Behavior**: Shows substrate saturation. Parallelism config updates based on CPU EMA.
- **BDD**: `Given` CPU > 80%, `When` tick occurs, `Then` scheduler count drops to 6.

### C2. P-CHK (Checks)
- **Diagram**: [Preflight Check List] | [Verification Check List] | [Quorum Consensus Ring]
- **Behavior**: Shows pass/fail for 20 points. Ring turns green when Zenoh Quorum ≥ 2oo3.
- **BDD**: `Given` PF-19 fails, `When` boot starts, `Then` launch is aborted.

### C3. P-TRC (Trace)
- **Diagram**: [CoT Decision Table] | [OTel Flame Graphs]
- **Behavior**: Maps duration to flame bar width. Emoji `🔥` fires if budget > 80%.
- **BDD**: `Given` DB migration takes 12s, `When` budget is 15s, `Then` bar is Orange.

### C4. P-TOP (Topology)
- **Diagram**: [ASCII Dependency DAG] | [Zenoh Telemetry Box]
- **Behavior**: Nodes color-coded by health. Zenoh stats show throughput/latency.
- **BDD**: `Given` Zenoh router 2 is down, `When` rendered, `Then` Peer Count = 2/3.

### C5. P-BLD (Build)
- **Diagram**: [EMA Table] | [WAL Mode Health] | [Prediction Trends]
- **Behavior**: Displays historical data used for adaptive timeouts.
- **BDD**: `Given` build-history.db exists, `When` loaded, `Then` WAL mode is verified.

### C6. P-NIF (NIF)
- **Diagram**: [Libc Flavor Banner] | [Symbol Table] | [Interpretation Path]
- **Behavior**: Scans `.so` files for glibc/musl compatibility.
- **BDD**: `Given` Alpine substrate, `When` scanned, `Then` NIF tab shows "MUSL" warning.

### C7. P-RCV (Recovery)
- **Diagram**: [Top-5 Failure Modes Table] | [Compensating Transaction Log]
- **Behavior**: Lists active recovery playbooks.
- **BDD**: `Given` Wave 1 failure, `When` rollback fires, `Then` transaction is logged.

### C8. P-LOG (Logs)
- **Diagram**: [Centralized Log Scroll]
- **Behavior**: Captures all `info/warn/error` from the daemon.
- **BDD**: `Given` any log emitted, `When` tab selected, `Then` message is visible.

### C9. P-AGT (Agent UI)
- **Diagram**: [Cortex Dialogue Box] | [Cognitive State] | [Active Directives]
- **Behavior**: Shows agent reasoning steps. Confidence score bar shifts dynamically.
- **BDD**: `Given` Agent decides to purge, `When` acting, `Then` dialogue shows "Ghost Purge".

---

## PART O — UNIFIED CLOSED-LOOP TESTING

### O1. Convergence Contract
- **Harness**: `sub-projects/c3i/target/release/ignition dashboard --test-ui`.
- **Cycles**: 50 full cycles.
- **Asserter**: Gemini Control loop verifies 0-panic exit code.
- **Logs**: All internal logs must be captured by `tui-logger` (no stdout leakage).

---
**Approval**: Gemini CLI Executive (SC-IGNITE-001)
