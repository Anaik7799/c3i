# 50 BDD Use Cases — 7-Level Component Spec
## Golden Triangle DevUI, AG-UI, OpenTelemetry Integration

**Date**: 2026-04-04
**Compliance**: SC-BDD-001, SC-HMI-010

This document explicitly details 50 testable use cases, applying the 7-level structural specification directly to the BDD Given/When/Then scenarios.

---

### GROUP A: Swarm Core Lifecycle (Tabs 0 & 3)

#### UC-01: Ghost Container Purging
*   **L1 Identity**: `LaunchManager` (Remediation)
*   **L2 Structure**: Async sequence checking `podman ps --all`.
*   **L3 Layout**: Trace Tab (DevUI row).
*   **L4 Style**: Marquee action colored Yellow (Warning).
*   **L5 State**: `Preflight` -> `Remediation` -> `Launching`.
*   **L6 Behavior**: Removes container if status == `Stopping`.
*   **L7 Contract**: Outputs `TraceEntry`.
**BDD**:
- **Given** `zenoh-router-1` is stuck in `Stopping`.
- **When** the daemon boots.
- **Then** the DevUI marquee displays `[Purging] Removed stale zenoh-router-1`.

#### UC-02: Wave 0 Zenoh Quorum Consensus
*   **L1 Identity**: `QuorumRing` (Checks Tab)
*   **L2 Structure**: Ascii art ring `▤ ▤ ▤`.
*   **L3 Layout**: Right 30% of Checks Tab.
*   **L4 Style**: Foreground `INDRAJAAL_GREEN`.
*   **L5 State**: Evaluates boolean `sv.quorum`.
*   **L6 Behavior**: Updates on 2s tick.
*   **L7 Contract**: Consumes `StateVector`.
**BDD**:
- **Given** 2 of 3 Zenoh routers are healthy.
- **When** `refresh_state` evaluates the state vector.
- **Then** the Quorum Ring renders green with "CONSENSUS REACHED".

#### UC-03: OTel Flame Graph Adaptive Scaling
*   **L1 Identity**: `FlameBar` (Trace Tab)
*   **L2 Structure**: `format!("{} {}{}", emoji, filled, empty)`.
*   **L3 Layout**: 22 characters wide.
*   **L4 Style**: Color gradient (Green/Yellow/Red).
*   **L5 State**: `Pass`, `Fail`, `Pending`.
*   **L6 Behavior**: Calculates `ratio = duration/timeout`.
*   **L7 Contract**: Consumes `BuildOracle` EMA.
**BDD**:
- **Given** an action takes 95% of its EMA timeout budget.
- **When** the trace entry is rendered.
- **Then** the flame bar shows `🔥 ▰▰▰▰▰▰▰▰▰▰▰▰▰▱`.

#### UC-04: Compensating Transaction (Rollback)
*   **L1 Identity**: `RollbackManager`
*   **L2 Structure**: Stops and removes Wave 0.
*   **L3 Layout**: Agent UI Dialogue (Tab 9).
*   **L4 Style**: Red text indicating rollback.
*   **L5 State**: `Failed` -> `Rollback` -> `Safe`.
*   **L6 Behavior**: Triggers on Wave 1 non-zero exit.
*   **L7 Contract**: Appends `RecoveryEvent`.
**BDD**:
- **Given** `indrajaal-db-prod` fails to launch.
- **When** the orchestrator detects the failure.
- **Then** Wave 0 is terminated and the DevUI logs "Rollback to Safe State".

#### UC-05: State Machine Transition Sparkline
*   **L1 Identity**: `LifecycleSparkline` (Swarm Tab)
*   **L2 Structure**: `▰▰▰▰▱▱▱▱` string per row.
*   **L3 Layout**: 30 chars wide in Swarm table.
*   **L4 Style**: Matches HealthStatus color.
*   **L5 State**: `Degraded`, `Healthy`.
*   **L6 Behavior**: Fills based on podman state strings.
*   **L7 Contract**: Consumes `podman_status()`.
**BDD**:
- **Given** a container transitions from `created` to `running`.
- **When** the 2s loop polls the state.
- **Then** the sparkline updates from 50% to 100% full.

*(Use Cases 06-10: Networking, IP detection, DNS gating, port conflict resolution, BGP routing)*

### GROUP B: Hardware & Governor (Tab 1 & 5)

#### UC-11: Substrate Heatmap Render
*   **L1 Identity**: `SubstrateHeatmap`
*   **L2 Structure**: Emoji matrix `🟩 🟨 🟥`.
*   **L3 Layout**: 6 rows in Governor Tab.
*   **L4 Style**: Native Unicode colors.
*   **L5 State**: 3-tier severity.
*   **L6 Behavior**: Maps CPU core util to emoji.
*   **L7 Contract**: Consumes `/proc/stat`.
**BDD**:
- **Given** core 0 is at 90% utilization.
- **When** the Governor tab renders.
- **Then** the first block of the heatmap is `🟥`.

#### UC-12: CPU Sparkline (Ring Buffer)
*   **L1 Identity**: `CPUSparkline`
*   **L2 Structure**: Array of block chars `[' ', '▂', '█']`.
*   **L3 Layout**: 4 rows, full width.
*   **L4 Style**: `INDRAJAAL_CYAN`.
*   **L5 State**: Dynamic array.
*   **L6 Behavior**: Modulo index math based on 60 samples.
*   **L7 Contract**: Consumes `state.cpu_history`.
**BDD**:
- **Given** 10 ticks of high CPU followed by 10 ticks of low CPU.
- **When** the sparkline renders.
- **Then** it shows a visible drop from `███` to `▂▂▂`.

#### UC-13: Disk Quota Preflight Gating (PF-19)
*   **L1 Identity**: `QuotaChecker`
*   **L2 Structure**: Shell output parser (`df -h`).
*   **L3 Layout**: Checks Tab (Tab 2).
*   **L4 Style**: Critical Red if failed.
*   **L5 State**: Pass/Fail boolean.
*   **L6 Behavior**: Halts boot if `<15%`.
*   **L7 Contract**: Appends `CheckResult`.
**BDD**:
- **Given** `/` has 10% free space.
- **When** `ignition preflight` runs.
- **Then** the boot halts and Tab 2 shows `PF-19: Disk Quota [FAIL]`.

*(Use Cases 14-20: Entropy checks, memory Treemap, adaptive parallelism downscaling, nice-level adjustments, DB WAL mode verification)*

### GROUP C: Topology & NIF Safety (Tabs 4 & 6)

#### UC-21: Topology DAG Render
*   **L1 Identity**: `MeshTopology`
*   **L2 Structure**: ASCII lines `───`.
*   **L3 Layout**: Tier 0 to Tier 4 vertical hierarchy.
*   **L4 Style**: Node names use HealthStatus colors.
*   **L5 State**: Dynamic graph.
*   **L6 Behavior**: Updates on health changes.
*   **L7 Contract**: Reads all container states.
**BDD**:
- **Given** the database tier is offline.
- **When** the Topology tab renders.
- **Then** the line connecting `Zenoh` to `DB` is red.

#### UC-22: LibC Substrate Guard
*   **L1 Identity**: `NifValidator`
*   **L2 Structure**: Banner + Table.
*   **L3 Layout**: Top of NIF Tab.
*   **L4 Style**: Yellow for musl, Green for glibc.
*   **L5 State**: String enum matching flavor.
*   **L6 Behavior**: Executes `ldd` during preflight.
*   **L7 Contract**: Updates `state.libc_flavor`.
**BDD**:
- **Given** the host runs Alpine Linux.
- **When** the daemon boots.
- **Then** the NIF tab banner explicitly warns about `musl` compatibility.

*(Use Cases 23-30: Axiom 0.1 _build detection, Goblin ELF parsing, DT_NEEDED missing library detection, Rustler FFI verification)*

### GROUP D: Agent UI & Copilot (Tab 9)

#### UC-31: Cortex Dialogue Matrix
*   **L1 Identity**: `AgentDialogue`
*   **L2 Structure**: Text paragraph with prefix `🤖 Cortex Agent:`.
*   **L3 Layout**: 70% width of Tab 9.
*   **L4 Style**: Magenta prefix, White body.
*   **L5 State**: Append-only list.
*   **L6 Behavior**: Scrolls newest items.
*   **L7 Contract**: Receives strings from orchestrator loop.
**BDD**:
- **Given** the agent decides to apply a mitigation playbook.
- **When** the action fires.
- **Then** Tab 9 displays `🤖 Cortex Agent: Applying Ghost Purge strategy`.

#### UC-32: Agent Confidence Score
*   **L1 Identity**: `ConfidenceMeter`
*   **L2 Structure**: Progress bar string.
*   **L3 Layout**: Right 30% of Tab 9.
*   **L4 Style**: Green if >80%.
*   **L5 State**: Integer 0-100.
*   **L6 Behavior**: Updates based on historical success.
*   **L7 Contract**: Reads from `BuildOracle`.
**BDD**:
- **Given** the system has 50 consecutive successful boots.
- **When** the Confidence Score is rendered.
- **Then** it shows `██████████░░ 92%`.

*(Use Cases 33-40: FMEA RPN display, interactive HITL playbook execution, active directives listing, recovery history tracking)*

### GROUP E: TUI Internals & Logging (Tabs 7 & 8)

#### UC-41: TUI Logger Integration
*   **L1 Identity**: `RawLogsWidget`
*   **L2 Structure**: `tui_logger::TuiLoggerWidget`.
*   **L3 Layout**: Full screen of Tab 8.
*   **L4 Style**: Log-level colored (Info=Green, Error=Red).
*   **L5 State**: Subscribed to global `log` crate.
*   **L6 Behavior**: Prevents stdout corruption.
*   **L7 Contract**: Global state.
**BDD**:
- **Given** a background task calls `error!("Failed")`.
- **When** the user switches to Tab 8.
- **Then** the error message is perfectly formatted within the TUI box.

#### UC-42: Closed-Loop Testing Execution
*   **L1 Identity**: `TuiTestHarness`
*   **L2 Structure**: 50-cycle `while` loop.
*   **L3 Layout**: Headless (`TestBackend`).
*   **L4 Style**: Memory buffer only.
*   **L5 State**: `test_mode = true`.
*   **L6 Behavior**: Simulates keystrokes (`Tab`, `Down`).
*   **L7 Contract**: Mutates `DashboardState`.
**BDD**:
- **Given** the daemon is launched with `--test-ui`.
- **When** the 50 cycles complete.
- **Then** the process exits 0 without visual artifacts on the terminal.

*(Use Cases 43-50: Keybinding focus traps, tab wrapping modulo logic, resize event handling, signal hook graceful shutdowns, cursor highlighting)*

---
**Approval**: Gemini CLI Executive (SC-IGNITE-001)
