# Full Specification: Golden Triangle & 50 BDD Use Cases (7 Levels of Detail)

**Date**: 2026-04-04
**Compliance**: SC-HMI-010, SC-BDD-001, SC-IGNITE-001
**Context**: Deep dive into the Microsoft Agent Framework "Golden Triangle" (AG-UI, DevUI, OpenTelemetry) applied to the Rust Ignition Daemon's Ratatui TUI.

---

## PART I: The Golden Triangle at 7 Levels of Fractal Detail

### Level 1: Paradigm (The Efficiency Closed Loop)
The overarching philosophy that AI agent orchestration cannot be a "black box." The loop consists of Execution (Agent), Observation (OTel), Reasoning Visualization (DevUI), and Human Interaction (AG-UI).

### Level 2: Architecture (The Three Pillars)
1.  **AG-UI (Agent UI)**: The external-facing interface. Handles generative components, user approval gates, and state synchronization.
2.  **DevUI (Developer UI)**: The internal-facing interface. Visualizes the "Chain of Thought" (CoT), internal state transitions, and step-by-step reasoning.
3.  **OpenTelemetry (OTel)**: The quantitative perspective. Distributed tracing, metrics, and latency graphs.

### Level 3: Components (TUI Widgets)
-   **AG-UI**: Interactive Modals, Swarm Status Matrix, Consensus Quorum Ring.
-   **DevUI**: CoT Ticker Marquee, State Machine Sparklines, Dependency DAG.
-   **OTel**: Trace Tab Flame Graphs, Substrate Heatmap.

### Level 4: Interactions (Data Flow)
-   State vectors synchronize across the boundary every 2 seconds. OTel spans are closed and pushed to the Trace tab upon phase completion. The DevUI pulls from the `trace_entries` array to render the marquee.

### Level 5: Implementation (Rust/Ratatui)
-   Uses `crossterm` for non-blocking I/O. The `DashboardState` struct holds mutable references to `containers`, `trace_entries`, and `cpu_history`.

### Level 6: Element Behaviors (Keybindings & Ticks)
-   `Tab` / `Right`: Cycle tabs. `Up` / `Down`: Scroll logs or select containers.
-   Auto-refresh triggers a lightweight `governor::cpu_usage_fast()` check and a heavy `podman ps` sweep.

### Level 7: Substrate Metrics (The Metal)
-   Parsing `/proc/stat` for CPU ticks. Extracting `podman stats` via UDS (Unix Domain Sockets). Sending JSON payloads via HTTP to `localhost:4318`.

---

## PART II: 50 BDD Use Cases across 7 Levels of Detail

### Group A: Pre-Flight & Substrate (L0-L1)

#### UC 01: Axiom 0.1 Contamination Detection
**L1 Goal**: Ensure clean substrate. **L2 Actor**: Substrate Guard. **L3 Trigger**: Daemon Boot. **L4 Condition**: `_build` exists. **L5 Action**: Abort. **L6 UI Element**: Checks Tab Red `❌`.
**L7 BDD Spec**:
- **Given** the host has legacy compiled artifacts.
- **When** the daemon boots and renders the AG-UI Checks Tab.
- **Then** the DevUI CoT ticker flashes "Axiom 0.1 Violation".
- **And** the OTel flame graph records a 5ms failure span.

#### UC 02: Disk Quota Exhaustion
**L1 Goal**: Prevent mid-boot corruption. **L2 Actor**: Preflight (PF-19). **L3 Trigger**: Disk Check. **L4 Condition**: Free < 15%. **L5 Action**: Abort. **L6 UI Element**: Alert Modal.
**L7 BDD Spec**:
- **Given** host disk space is critically low (<15%).
- **When** the Preflight sequence initiates.
- **Then** the AG-UI renders a high-priority modal requesting cleanup.
- **And** the ignition sequence is halted.

#### UC 03: Podman Socket Unresponsive
**L1 Goal**: Ensure IPC health. **L2 Actor**: Preflight (PF-20). **L3 Trigger**: Socket Probe. **L4 Condition**: Timeout > 3s. **L5 Action**: Panic. **L6 UI Element**: Status Bar Error.
**L7 BDD Spec**:
- **Given** the Podman daemon is hung.
- **When** the TUI attempts to fetch the container list.
- **Then** the DevUI logs a socket timeout in the Trace Tab.
- **And** the AG-UI displays a "Socket Unresponsive" banner.

#### UC 04: Substrate Entropy Depletion
**L1 Goal**: Secure cryptography. **L2 Actor**: Preflight (PF-21). **L3 Trigger**: `/dev/random` read. **L4 Condition**: Pool < 256. **L5 Action**: Warn. **L6 UI Element**: Heatmap Warning.
**L7 BDD Spec**:
- **Given** the host entropy pool is depleted below 256 bytes.
- **When** the system runs preflight checks.
- **Then** the AG-UI Heatmap displays a flashing yellow indicator for I/O wait.
- **And** a warning is logged regarding slow crypto operations.

#### UC 05: Port Collision Detection
**L1 Goal**: Prevent bind failures. **L2 Actor**: Preflight (PF-10). **L3 Trigger**: Bind Test. **L4 Condition**: Port 4000 in use. **L5 Action**: Abort. **L6 UI Element**: Conflict Matrix Red.
**L7 BDD Spec**:
- **Given** a zombie process holds port 4000.
- **When** the Ignition daemon prepares Wave 2.
- **Then** the DevUI highlights the exact conflicting PID in the Trace tab.
- **And** the launch is aborted.

#### UC 06: Libc/Musl Mismatch
**L1 Goal**: Binary compatibility. **L2 Actor**: Preflight (PF-18). **L3 Trigger**: NIF Scan. **L4 Condition**: `ldd` fails. **L5 Action**: Warn. **L6 UI Element**: NIF Tab Mismatch.
**L7 BDD Spec**:
- **Given** a NIF is compiled for glibc but running on Alpine.
- **When** the user opens the NIF Compatibility Tab.
- **Then** the AG-UI displays a red matrix cell for the mismatched NIF.

#### UC 07: Stale Lockfile Purge
**L1 Goal**: Clean state. **L2 Actor**: Launch Pre-provisioning. **L3 Trigger**: `.pid` found. **L4 Condition**: File exists. **L5 Action**: Delete. **L6 UI Element**: CoT Ticker "Purged".
**L7 BDD Spec**:
- **Given** a previous hard crash left a `redis.pid`.
- **When** the daemon initiates the pre-provisioning step.
- **Then** the DevUI ticker shows `[Purging] Removed stale redis.pid`.

#### UC 08: Volume Directory Scaffold
**L1 Goal**: Correct permissions. **L2 Actor**: Launch Pre-provisioning. **L3 Trigger**: `mkdir -p`. **L4 Condition**: Missing dirs. **L5 Action**: Create. **L6 UI Element**: Info Log.
**L7 BDD Spec**:
- **Given** a fresh clone without `data/state`.
- **When** the user hits `Enter` to start ignition.
- **Then** the OTel trace logs a 2ms span for directory scaffolding.

#### UC 09: Atomic Network Verification
**L1 Goal**: Network isolation. **L2 Actor**: Podman API. **L3 Trigger**: `network exists`. **L4 Condition**: Missing. **L5 Action**: Create. **L6 UI Element**: Topology Tab.
**L7 BDD Spec**:
- **Given** the `indrajaal-sil6-mesh` network is absent.
- **When** Wave 0 starts.
- **Then** the DevUI logs the creation of the subnet in the CoT ticker.
- **And** the Topology tab shows the network as active.

#### UC 10: Clock Sync Drift
**L1 Goal**: Accurate telemetry. **L2 Actor**: NTP check. **L3 Trigger**: Time sync. **L4 Condition**: Delta > 50ms. **L5 Action**: Warn. **L6 UI Element**: Header Warning.
**L7 BDD Spec**:
- **Given** the host clock is drifting by more than 50ms.
- **When** the telemetry exporter initializes.
- **Then** the AG-UI displays a clock drift warning to prevent trace corruption.

### Group B: Container Lifecycle & Orchestration (L2-L4)

#### UC 11: Cryptographic Image Verification
**L1 Goal**: Image integrity. **L2 Actor**: SHA256 Check. **L3 Trigger**: `image inspect`. **L4 Condition**: Mismatch. **L5 Action**: Abort. **L6 UI Element**: Swarm Tab Red.
**L7 BDD Spec**:
- **Given** an image digest does not match the expected manifest.
- **When** the orchestrator prepares the `podman run` args.
- **Then** the DevUI halts the DAG and turns the node red.
- **And** logs a cryptographic failure.

#### UC 12: Stale State Reconciliation (Ghost Purging)
**L1 Goal**: Namespace availability. **L2 Actor**: Ghost Purger. **L3 Trigger**: `ps --all`. **L4 Condition**: Found `Stopping` state. **L5 Action**: `rm -f`. **L6 UI Element**: Sparkline Reset.
**L7 BDD Spec**:
- **Given** `zenoh-router-1` is stuck in `Stopping`.
- **When** Wave 0 initiates.
- **Then** the daemon executes a force remove.
- **And** the AG-UI sparkline resets to `[WAITING]` after the purge.

#### UC 13: Wave 0 (Zenoh) Launch
**L1 Goal**: Mesh backplane. **L2 Actor**: Wave Launcher. **L3 Trigger**: Launch. **L4 Condition**: 3 Routers up. **L5 Action**: Success. **L6 UI Element**: DAG Node Green.
**L7 BDD Spec**:
- **Given** the preflight is complete.
- **When** Wave 0 executes.
- **Then** the DevUI CoT ticker rapid-fires the launch of 3 routers.
- **And** the Topology DAG updates the router nodes to green.

#### UC 14: Compensating Transaction (Rollback)
**L1 Goal**: System safety. **L2 Actor**: Rollback Manager. **L3 Trigger**: Wave 1 Fail. **L4 Condition**: Non-zero exit. **L5 Action**: Wave 0 killed. **L6 UI Element**: Trace Tab Error.
**L7 BDD Spec**:
- **Given** the database container fails to start in Wave 1.
- **When** the orchestrator detects the non-zero exit code.
- **Then** the system executes a compensating transaction to remove Wave 0.
- **And** the Trace tab shows a red rollback span.

#### UC 15: State Machine Sparkline Transition
**L1 Goal**: Visual lifecycle. **L2 Actor**: State Poller. **L3 Trigger**: Lifecycle poll. **L4 Condition**: `Creating` -> `Starting`. **L5 Action**: Render. **L6 UI Element**: `▰▰▰▱▱`.
**L7 BDD Spec**:
- **Given** a container is pulling an image.
- **When** the image pull completes and execution begins.
- **Then** the AG-UI sparkline smoothly transitions from 20% to 50% fill.

#### UC 16: Dynamic Memory Scaling
**L1 Goal**: OOM prevention. **L2 Actor**: Governor Link. **L3 Trigger**: RAM Check. **L4 Condition**: High pressure. **L5 Action**: Throttle. **L6 UI Element**: Governor Tab.
**L7 BDD Spec**:
- **Given** the host is under severe memory pressure.
- **When** the application container is scheduled.
- **Then** the orchestrator injects a lower `--memory` limit.
- **And** the Governor tab reflects the throttled allocation.

#### UC 17: Container Dependency Graphing
**L1 Goal**: Visual topology. **L2 Actor**: DAG Renderer. **L3 Trigger**: State update. **L4 Condition**: Connected. **L5 Action**: Draw ASCII. **L6 UI Element**: Topology Tab.
**L7 BDD Spec**:
- **Given** the mesh is fully booted.
- **When** the user switches to the Topology tab.
- **Then** the AG-UI displays a fully connected, green ASCII flow chart of dependencies.

#### UC 18: Live StdErr Modal Capture
**L1 Goal**: Instant debugging. **L2 Actor**: Async Stream Parser. **L3 Trigger**: Launch Fail. **L4 Condition**: `.err` written. **L5 Action**: Display. **L6 UI Element**: Popup Modal.
**L7 BDD Spec**:
- **Given** a container crashes immediately upon execution.
- **When** the orchestrator writes the stderr to a file.
- **Then** the DevUI automatically pops up a modal displaying the exact crash trace.

#### UC 19: Adaptive Startup Timeouts (EMA)
**L1 Goal**: Smart budgeting. **L2 Actor**: Build Oracle. **L3 Trigger**: History read. **L4 Condition**: T=12s. **L5 Action**: Set limit. **L6 UI Element**: Flame Graph scale.
**L7 BDD Spec**:
- **Given** the database historically takes 12 seconds to boot.
- **When** the orchestrator schedules the DB launch.
- **Then** the OTel flame graph scales its 100% width to 12s * 2.5 margin.

#### UC 20: 2oo3 Zenoh Quorum Enforcement
**L1 Goal**: Consensus gating. **L2 Actor**: Health Orchestra. **L3 Trigger**: Quorum Poll. **L4 Condition**: 2 nodes up. **L5 Action**: Pass. **L6 UI Element**: Quorum Ring Green.
**L7 BDD Spec**:
- **Given** only 2 of 3 Zenoh routers successfully started.
- **When** the health orchestrator runs its checks.
- **Then** the AG-UI Quorum Ring displays "CONSENSUS REACHED" in green.
- **And** Wave 2 is allowed to proceed.

### Group C: TUI Interactions & DevUI (L5)

#### UC 21: Keybinding Navigation
**L1 Goal**: Fluid UX. **L2 Actor**: Crossterm Input. **L3 Trigger**: `Tab` pressed. **L4 Condition**: Index + 1. **L5 Action**: Render. **L6 UI Element**: Tab Highlight.
**L7 BDD Spec**:
- **Given** the dashboard is on the Swarm tab.
- **When** the user presses the `Tab` key.
- **Then** the AG-UI immediately renders the Governor tab.

#### UC 22: Container Row Selection
**L1 Goal**: Contextual details. **L2 Actor**: Cursor Tracker. **L3 Trigger**: `Down` arrow. **L4 Condition**: Index change. **L5 Action**: Highlight. **L6 UI Element**: Live Logs Pane.
**L7 BDD Spec**:
- **Given** the user is on the Swarm tab.
- **When** the user presses the `Down` arrow.
- **Then** the AG-UI highlights the next row.
- **And** updates the Live Logs pane for the newly selected container.

#### UC 23: Agent CoT Ticker Marquee
**L1 Goal**: Insight. **L2 Actor**: Trace Reader. **L3 Trigger**: State tick. **L4 Condition**: New entry. **L5 Action**: Update string. **L6 UI Element**: Header Marquee.
**L7 BDD Spec**:
- **Given** the orchestrator is executing a long-running task.
- **When** the 2-second refresh loop triggers.
- **Then** the DevUI header marquee updates with the latest trace decision (e.g., `[Launching] app ➜ Success`).

#### UC 24: Substrate Heatmap Rendering
**L1 Goal**: L0 Visibility. **L2 Actor**: `/proc/stat` parser. **L3 Trigger**: CPU high. **L4 Condition**: >80%. **L5 Action**: Red block. **L6 UI Element**: Governor Tab.
**L7 BDD Spec**:
- **Given** the host CPU is at 85%.
- **When** the user views the Governor tab.
- **Then** the AG-UI Substrate Heatmap displays red blocks for the active cores.

#### UC 25: OTel Flame Graph Rendering
**L1 Goal**: Latency tracking. **L2 Actor**: Ratio Calc. **L3 Trigger**: Trace update. **L4 Condition**: >0.8 ratio. **L5 Action**: 🔥 emoji. **L6 UI Element**: Trace Tab.
**L7 BDD Spec**:
- **Given** a container launch took 90% of its allocated EMA timeout budget.
- **When** the OTel trace is rendered in the TUI.
- **Then** the flame bar is colored red and prefixed with a fire emoji.

#### UC 26: Log Anomaly Highlighting
**L1 Goal**: Error spotting. **L2 Actor**: Regex Matcher. **L3 Trigger**: Log parse. **L4 Condition**: Match "failed". **L5 Action**: Red text. **L6 UI Element**: Trace Row.
**L7 BDD Spec**:
- **Given** an action log contains the word "failed".
- **When** the DevUI renders the Trace table.
- **Then** the specific row is rendered in bold red text.

#### UC 27: FMEA Threat Radar Display
**L1 Goal**: Risk awareness. **L2 Actor**: Metadata Pane. **L3 Trigger**: Row select. **L4 Condition**: High RPN. **L5 Action**: Display. **L6 UI Element**: AG-UI Pane.
**L7 BDD Spec**:
- **Given** a container has a historical Failure Mode with an RPN of 240.
- **When** that container is selected in the Swarm tab.
- **Then** the AG-UI Metadata pane flashes the high-risk FMEA profile.

#### UC 28: Interactive Playbook Execution
**L1 Goal**: HITL recovery. **L2 Actor**: Input Handler. **L3 Trigger**: Key `p`. **L4 Condition**: Confirm. **L5 Action**: Exec playbook. **L6 UI Element**: Modal.
**L7 BDD Spec**:
- **Given** the orchestrator pauses for human intervention.
- **When** the operator selects a recovery playbook and presses 'Enter'.
- **Then** the DevUI logs the manual override and executes the playbook.

#### UC 29: CPU Governor Threshold Feedback
**L1 Goal**: Throttling visibility. **L2 Actor**: Governor Logic. **L3 Trigger**: CPU >85%. **L4 Condition**: Exceeded. **L5 Action**: Pause. **L6 UI Element**: Governor Tab.
**L7 BDD Spec**:
- **Given** the system enters HEAVY mode (>85% CPU).
- **When** the orchestrator attempts to launch the next wave.
- **Then** the launch pauses and the AG-UI displays a "WAITING ON CPU" status.

#### UC 30: State Vector Synchronization
**L1 Goal**: Shared state. **L2 Actor**: Matrix Evaluator. **L3 Trigger**: All True. **L4 Condition**: Valid. **L5 Action**: Render green. **L6 UI Element**: Checks Tab.
**L7 BDD Spec**:
- **Given** all 6 preflight conditions are met.
- **When** the state vector is evaluated.
- **Then** the AG-UI displays `[C,M,N,Z,H,Q]  VALID ✓` in bright green.

### Group D: Telemetry & Mesh Homeostasis (L6-L7)

#### UC 31: ProofToken Environment Injection
**L1 Goal**: Secure auth. **L2 Actor**: Token Gen. **L3 Trigger**: Launch app. **L4 Condition**: Token created. **L5 Action**: Inject via tmpfs. **L6 UI Element**: CoT Ticker.
**L7 BDD Spec**:
- **Given** the app container requires Zenoh authentication.
- **When** the orchestrator launches the container.
- **Then** an Ed25519 token is generated and injected.
- **And** the DevUI logs the secure injection.

#### UC 32: Zenoh PubSub Validation
**L1 Goal**: IPC health. **L2 Actor**: Zenoh FFI. **L3 Trigger**: Ping. **L4 Condition**: Success. **L5 Action**: Link nodes. **L6 UI Element**: Topology Tab.
**L7 BDD Spec**:
- **Given** the Zenoh routers are running.
- **When** a ping is sent across the PubSub backplane.
- **Then** the AG-UI Topology tab visually links the nodes.

#### UC 33: OTel Span Export
**L1 Goal**: Traceability. **L2 Actor**: Hackney HTTP. **L3 Trigger**: Phase end. **L4 Condition**: HTTP 200. **L5 Action**: Log success. **L6 UI Element**: Trace Tab.
**L7 BDD Spec**:
- **Given** a boot phase completes.
- **When** the OTel span is exported to `localhost:4318`.
- **Then** the Trace tab confirms the successful HTTP 200 export.

#### UC 34: FPPS 5-Method Consensus
**L1 Goal**: Absolute health. **L2 Actor**: Health Orchestra. **L3 Trigger**: Verification. **L4 Condition**: All 5 pass. **L5 Action**: Mark healthy. **L6 UI Element**: Quorum Ring.
**L7 BDD Spec**:
- **Given** a container passes Running, Port, Endpoint, Quorum, and Twin checks.
- **When** the consensus is evaluated.
- **Then** the Quorum ring dynamically fills.
- **And** the container is marked green.

#### UC 35: Digital Twin Sync Indicator
**L1 Goal**: State parity. **L2 Actor**: Sync Checker. **L3 Trigger**: Poll. **L4 Condition**: Match. **L5 Action**: Green icon. **L6 UI Element**: AG-UI Pane.
**L7 BDD Spec**:
- **Given** the local SQLite state matches the remote Chaya state.
- **When** the sync status is checked.
- **Then** the AG-UI displays a "Twin Synced" indicator.

#### UC 36: Panic Detection Stream
**L1 Goal**: Early failure detection. **L2 Actor**: Async Parser. **L3 Trigger**: "nif_panic". **L4 Condition**: Match. **L5 Action**: Abort. **L6 UI Element**: Modal.
**L7 BDD Spec**:
- **Given** an Erlang NIF panics during boot.
- **When** the async parser reads the `stderr` stream.
- **Then** the boot is instantly aborted.
- **And** a real-time modal interrupts the view.

#### UC 37: Network Traffic Mini-Graph
**L1 Goal**: Bandwidth visibility. **L2 Actor**: Netlink. **L3 Trigger**: Poll. **L4 Condition**: RX/TX > 0. **L5 Action**: Update ASCII graph. **L6 UI Element**: Governor Tab.
**L7 BDD Spec**:
- **Given** the containers are exchanging data.
- **When** the 2s refresh occurs.
- **Then** the Governor tab displays ASCII bars mapping to `veth` bytes.

#### UC 38: Memory Allocation Treemap
**L1 Goal**: RAM visibility. **L2 Actor**: Podman Stats. **L3 Trigger**: Select. **L4 Condition**: Has stats. **L5 Action**: Render map. **L6 UI Element**: Detail Pane.
**L7 BDD Spec**:
- **Given** a container has a 4g limit but uses 256m.
- **When** the container is selected.
- **Then** the detail pane shows a treemap reflecting the usage vs limit.

#### UC 39: Lockfile Radar
**L1 Goal**: Deadlock prevention. **L2 Actor**: FS Scan. **L3 Trigger**: Preflight. **L4 Condition**: `.lock` found. **L5 Action**: Blink red. **L6 UI Element**: Checks Tab.
**L7 BDD Spec**:
- **Given** an active lock is preventing a transaction.
- **When** the Checks tab is rendered.
- **Then** the Lockfile Radar indicator blinks red.

#### UC 40: Container Lifecycle Swimlanes
**L1 Goal**: Parallelism visibility. **L2 Actor**: Timeline Gen. **L3 Trigger**: Trace Tab. **L4 Condition**: Multi-wave. **L5 Action**: Render Gantt. **L6 UI Element**: Trace Tab.
**L7 BDD Spec**:
- **Given** parallel boot sequences across 4 waves.
- **When** the Trace tab is viewed.
- **Then** it visualizes the concurrent lifecycles as swimlanes.

### Group E: Agentic Workflows & Auto-Recovery (L7+)

#### UC 41: Circuit Breaking on Launch (CrashLoopBackOff)
**L1 Goal**: Stop thrashing. **L2 Actor**: Retry Counter. **L3 Trigger**: Crash. **L4 Condition**: Count > 3 in 60s. **L5 Action**: Break. **L6 UI Element**: Red Status.
**L7 BDD Spec**:
- **Given** a container crashes 3 times within 1 minute.
- **When** it attempts a 4th launch.
- **Then** the orchestrator trips the circuit breaker and halts.

#### UC 42: Dynamic Secret Generation
**L1 Goal**: Secure keys. **L2 Actor**: Crypto Gen. **L3 Trigger**: Launch. **L4 Condition**: Needs key. **L5 Action**: Inject. **L6 UI Element**: CoT Ticker.
**L7 BDD Spec**:
- **Given** a service requires an AES-256 key.
- **When** the orchestrator prepares the launch.
- **Then** a key is generated on the fly and passed via ENV.

#### UC 43: PID Limit Enforcement
**L1 Goal**: Prevent fork bombs. **L2 Actor**: Config Builder. **L3 Trigger**: Prepare args. **L4 Condition**: PIDs > 4096. **L5 Action**: Enforce. **L6 UI Element**: Metadata Pane.
**L7 BDD Spec**:
- **Given** a container is configured with a PID limit.
- **When** it is launched.
- **Then** the AG-UI Metadata pane confirms the `--pids-limit` flag was applied.

#### UC 44: Automatic Fallback Tags
**L1 Goal**: Resilience. **L2 Actor**: Image Selector. **L3 Trigger**: `latest` fails. **L4 Condition**: `previous` exists. **L5 Action**: Relaunch. **L6 UI Element**: Trace Log.
**L7 BDD Spec**:
- **Given** the `latest` image fails to boot.
- **When** the rollback completes.
- **Then** the orchestrator automatically attempts to launch the `previous-stable` tag.

#### UC 45: Graceful Degradation Launch
**L1 Goal**: Partial availability. **L2 Actor**: Wave Logic. **L3 Trigger**: DB down. **L4 Condition**: Cache mode allowed. **L5 Action**: Launch degraded. **L6 UI Element**: Yellow Status.
**L7 BDD Spec**:
- **Given** the database wave fails completely.
- **When** the application wave starts.
- **Then** the app is launched in a "cache-only" degraded mode (Yellow status).

#### UC 46: BGP Route Announcement Tracking
**L1 Goal**: Network scaling. **L2 Actor**: BGP Monitor. **L3 Trigger**: Launch. **L4 Condition**: Route active. **L5 Action**: Log. **L6 UI Element**: Topology Tab.
**L7 BDD Spec**:
- **Given** a container requires BGP route injection.
- **When** it successfully launches.
- **Then** the Topology tab indicates the route is announced.

#### UC 47: Agent Confidence Score Meter
**L1 Goal**: Trust visibility. **L2 Actor**: AI Cortex. **L3 Trigger**: Decision made. **L4 Condition**: Confidence < 80%. **L5 Action**: Prompt HITL. **L6 UI Element**: Confidence Bar.
**L7 BDD Spec**:
- **Given** the agent is unsure about a recovery action.
- **When** it proposes the action.
- **Then** the AG-UI displays a low confidence score and requests human approval.

#### UC 48: Interactive "Kill Switch" Matrix
**L1 Goal**: Emergency control. **L2 Actor**: Input Handler. **L3 Trigger**: Key `k`. **L4 Condition**: Container selected. **L5 Action**: `SIGKILL`. **L6 UI Element**: Modal.
**L7 BDD Spec**:
- **Given** a container is spiraling out of control.
- **When** the user presses `k` on the selected row.
- **Then** the orchestrator immediately issues a `SIGKILL` via Podman.

#### UC 49: Boot Event Journaling
**L1 Goal**: Audit trail. **L2 Actor**: SQLite Logger. **L3 Trigger**: Boot complete. **L4 Condition**: Success. **L5 Action**: Write DB. **L6 UI Element**: CoT Ticker.
**L7 BDD Spec**:
- **Given** the full ignition sequence finishes successfully.
- **When** the final checks pass.
- **Then** a permanent event is logged to the central `ts_event_logs` database.

#### UC 50: Mission Accomplished Visuals
**L1 Goal**: Operator reward. **L2 Actor**: TUI Renderer. **L3 Trigger**: All Green. **L4 Condition**: Quorum reached. **L5 Action**: Animate. **L6 UI Element**: Header.
**L7 BDD Spec**:
- **Given** all 8 containers are healthy and quorum is reached.
- **When** the system enters the `Complete` phase.
- **Then** the TUI header displays a vibrant "✅ FULL IGNITION COMPLETE" banner.

---
**Approval**: Gemini CLI Executive
**Authorization**: UNIFIED-SYSTEM-IGNORE-PERMISSION
