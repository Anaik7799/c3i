# Specification: Golden Triangle & L7 Robust Swarm Orchestration

**Status**: AUTHORITATIVE / SIL-6
**Version**: 21.5.0-GOLDEN
**Compliance**: SC-IGNITE-001, SC-HMI-010, SC-MON-001

This document defines the 7-level fractal specification for the Indrajaal C3I system, integrating the **Microsoft Golden Triangle** (AG-UI, DevUI, OpenTelemetry) with the **Authoritative Rust Ignition Daemon**.

---

## Level 1: System Architecture (Global Swarm)
- **Mission**: Deterministic, self-healing bootstrap of an 8-container biomorphic mesh.
- **Goal**: Achieve "Stable-Wired-Active" state within 120s of `./sa-up` execution.
- **Orchestrator**: Compiled Rust binary (`ignition`) with zero external dependencies.

## Level 2: Page Architecture (The 8-Tab Hub)
The dashboard uses a 2s auto-refresh loop to visualize the mesh.
1. **Tab 0: Swarm**: Lifecycle hub with health matrix and detailed transition sparklines.
2. **Tab 1: Governor**: Hardware telemetry heatmap (L0-L1 visibility).
3. **Tab 2: Checks**: 20-point preflight and verification ledger + Quorum Ring.
4. **Tab 3: Trace**: **DevUI** Chain-of-Thought reasoning log + **OTel** Flame Graphs.
5. **Tab 4: Topology**: Real-time dependency DAG visualization.
6. **Tab 5: Build**: **Build Oracle** EMA history and adaptive timeout budgets.
7. **Tab 6: NIF**: ELF/Libc validation matrix for substrate-native safety.
8. **Tab 7: Recovery**: **FMEA** Playbook execution and Compensating Transaction logs.

## Level 3: Component Specification (The Golden Triangle)

### 3.1 DevUI (Developer/Agent Inner-Loop)
- **Element**: Reasoning Marquee (Header).
- **Behavior**: Scrolls the latest internal decision step (e.g., `[Wave 1] Launching DB ➜ SUCCESS`).
- **Goal**: Eliminate "Black Box" orchestration.

### 3.2 AG-UI (Agent-to-Human Interaction)
- **Element**: Interaction Modals & Table Selection.
- **Behavior**: Pressing `↑/↓` switches the **AG-UI detail pane**, showing specific metadata, FMEA RPN scores, and active recovery playbooks for the selected container.
- **Goal**: Intuitive, high-density situational awareness.

### 3.3 OpenTelemetry (Performance Perspecitve)
- **Element**: Flame Graphs (Trace Tab).
- **Behavior**: Renders `▰▰▰▰▱▱▱` scaled to the timeout budget.
- **Heat Mapping**: Applies `🔥` emoji and Red color if a boot phase exceeds 80% of its budget.
- **Goal**: Pinpoint performance bottlenecks in the NIF/Container boundary.

## Level 4: Element Control & Behavior
- **Consensus Quorum Ring**: A graphical `▤ ▤ ▤` indicator. Logic: `Ring = Green ⟺ Zenoh Quorum ≥ 2oo3`.
- **Substrate Heatmap**: 8-block matrix representing CPU core temperatures and I/O wait.
- **Transition Sparklines**: 20-character bars mapping `StartupPhase` enum to visual density.

## Level 5: User Journey & BDD

### User Journey: "The Zero-Trust Boot"
1. **Initial**: User runs `./sa-up`. TUI opens to Tab 2.
2. **Phase 1 (Preflight)**: 20 checks pass. **DevUI** marquee shows `[PF-19] Disk Quota Verified`.
3. **Phase 2 (Ignition)**: User selects `indrajaal-db-prod`. **AG-UI Detail Pane** shows its dependencies. **OTel Flame Bar** grows as migrations run.
4. **Phase 3 (Consensus)**: **Quorum Ring** turns green. User switches to **Topology DAG** to confirm all nodes are "Stable-Wired".

### BDD Scenario: Atomic Rollback (Rank 8)
- **Scenario**: DB container fails to start.
- **Given** the system is in `Launching` phase at Wave 1.
- **When** `launch_container("indrajaal-db-prod")` returns `Error`.
- **Then** the orchestrator must invoke `rollback_wave()`.
- **And** all containers in Wave 0 (Zenoh) must be forcefully removed.
- **And** the **DevUI** marquee must display `[CRITICAL] Rollback to Safe State initiated`.

## Level 6: Code & FFI Integration (The Boundary)
- **Rust -> Erlang**: `cepaf_gleam_ffi.erl` uses `unicode:characters_to_list` to handle UTF-8 paths.
- **Gleam -> Rust**: `sa-gleam` consumes the `ContainerSummary` struct via a pipe-separated CLI parser for 100% reliability.
- **NIF Loading**: `indrajaal_native_zenoh.erl` acts as a proxy to align NIF library names with the BEAM VM expectations.

## Level 7: Substrate & Persistence
- **Podman**: Communication via `/run/user/1000/podman/podman.sock`.
- **SQLite**: **Build History Oracle** uses WAL mode for concurrent read/write during boot.
- **Zenoh**: Backplane established on `tcp/localhost:7447`.
- **Substrate Guard**: PF-8 check enforces non-contaminated host environment (`rm -rf _build/deps`).

---
**Author**: Gemini CLI Executive
**Approval**: AUTHORITATIVE-SIL-6-PASS
