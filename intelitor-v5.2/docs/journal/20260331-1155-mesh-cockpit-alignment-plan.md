# Mesh Cockpit Page Alignment Plan — SIL-6 Biomorphic Fractal Mesh
**Timestamp**: 20260331-1155 CEST
**Type**: Architecture Alignment + Implementation Plan
**Author**: Claude Opus 4.6
**Status**: ACTIVE

---

## 1. Scope & Trigger

**Trigger**: User directive to align `/cockpit/mesh` page with current swarm state, identify full function/use-case set, rank by criticality/UX/STAMP/FMEA, review CEPAF code, and enable all fractal interactions.

**Scope**:
- `lib/indrajaal_web/live/prajna/mesh_live.ex` (835 lines) — PRIMARY LiveView
- F# CEPAF Mesh backend: 10+ files, ~5,800 lines
- Elixir Mesh modules: 6+ files, ~4,000 lines
- Zenoh key expressions: 10+ topics
- Test coverage: 31 test files + missing page spec + BDD feature

**Current Swarm State**: 4/15 containers running (zenoh-router, indrajaal-db-prod, indrajaal-obs-prod, indrajaal-ex-app-1)

---

## 2. Pre-State Assessment

### Current mesh_live.ex Capabilities
| Function | Status | Notes |
|----------|--------|-------|
| 15-container topology view | Working | Real Podman query via `System.cmd` |
| 7-tier boot hierarchy | Working | EID-compliant layout |
| Container status (running/stopped) | Working | `podman ps -a --format json` |
| Node selection + detail panel | Working | select_node/clear_selection events |
| BEAM intrinsics (app-1) | Working | `:erlang.memory()`, system_info |
| Category counts (B/P/S) | Working | Header bar |
| Status icons + color coding | Working | Green/red/gray |
| 3s auto-refresh | Working | handle_info(:refresh) |
| PubSub node updates | Working | prajna:mesh subscription |
| Navigate to diagnostics | Working | view_logs → push_navigate |
| Restart/Stop buttons | **Flash-only** | No actual Podman commands |
| Zenoh telemetry | **Missing** | Not subscribed to indrajaal/health/* |
| CEPAF bridge calls | **Missing** | No F# HealthCoordinator integration |
| Real metrics (non-app nodes) | **Simulated** | Gentle random walk |

### F# CEPAF Backend Capabilities (Available but Not Wired)
| Module | Lines | Key Functions |
|--------|-------|---------------|
| PanopticIgnition.fs | 847 | sil6Genome, geneticResynthesis, igniteMesh, DashboardState |
| HealthCoordinator.fs | 602 | CheckQuorum, DetectSplitBrain, FppsConsensus, AggregateHealth, ShouldTriggerApoptosis |
| ContainerLifecycleManager.fs | 593 | AdvanceStartup (5 phases), AdvanceShutdown (6 phases), PhaseTransitions |
| DigitalTwin.fs | 890 | HolonGenotype, ContainerHealth, ContainerRole, StartupPhase |
| SIL6MeshCLI.fs | 1613 | sa-up, sa-down, sa-status, sa-verify commands |
| BuildHistory.fs | 317 | SQLite build timing, EMA (alpha=0.3), build_history + build_ema tables |
| BuildStreamMonitor.fs | 462 | Streaming Podman build output parser |
| MeshStartup.fs | 451 | Boot orchestration |
| MeshShutdown.fs | 456 | 6-phase graceful shutdown |
| MeshDashboard.fs | 448 | ANSI TUI dashboard |

---

## 3. Execution Detail — 3-Wave Implementation Plan

### Wave 1: P0 Safety-Critical (6 features, FMEA RPN ≥ 270)

#### W1.1: Emergency Stop with Arm→Confirm→Guardian Flow (RPN 400)
- **STAMP**: SC-CTRL-004, SC-SAFETY-001, SC-SAFETY-022
- **What**: Add two-step commit emergency stop — arm button shows confirmation dialog, confirm triggers `MasterControl.emergency_stop/1` or Podman stop-all
- **Why**: Currently NO emergency stop capability on the mesh page. SC-CTRL-004 requires < 5 seconds.
- **Files**: `mesh_live.ex` — new handle_event("emergency_stop_arm"), handle_event("emergency_stop_confirm")
- **UX**: Red banner at top when armed, countdown timer, Guardian approval flash

#### W1.2: Quorum Health Indicator (RPN 280)
- **STAMP**: SC-SIL4-011, SC-QUORUM-001
- **What**: Header bar shows quorum status: "QUORUM: 4/15 healthy (need 8)" with color coding
- **Why**: HealthCoordinator.CheckQuorum() returns QuorumAchieved/QuorumNotAchieved/InsufficientNodes — must be visible
- **Files**: `mesh_live.ex` — new assign `:quorum_status`, computed from running node count
- **Formula**: `floor(N/2) + 1` where N = total registered nodes

#### W1.3: Split-Brain Detection Alert Banner (RPN 360)
- **STAMP**: SC-SIL4-015
- **What**: Alert banner when split-brain detected — shows partition info (which nodes in each partition, seed node locations)
- **Why**: HealthCoordinator.DetectSplitBrain() identifies when seeds exist in both partitions
- **Files**: `mesh_live.ex` — new assign `:split_brain_status`, rendered as CRITICAL alert banner
- **Condition**: Triggered when unreachable nodes > 0 AND seeds in both partitions

#### W1.4: Apoptosis Warning Panel (RPN 320)
- **STAMP**: SC-SIL4-015, SC-SAFETY-020
- **What**: CRITICAL warning when ShouldTriggerApoptosis conditions met (split-brain OR quorum-lost+seeds-down)
- **Why**: Auto-halt trigger condition must be visible to operator before it fires
- **Files**: `mesh_live.ex` — computed from quorum + split-brain + seed health
- **UX**: Red pulsing banner: "APOPTOSIS CONDITION MET — System may auto-halt"

#### W1.5: Real Container Restart/Stop (RPN 320)
- **STAMP**: SC-SAFETY-001, SC-CTRL-006, SC-PHICS-003
- **What**: Wire restart_node and stop_node to actual Podman commands via Guardian-gated two-step commit
- **Flow**: Click RESTART → "Armed" state → Confirm within 10s → `System.cmd("podman", ["restart", id])` → flash result
- **Files**: `mesh_live.ex` — rewrite handle_event("restart_node"), handle_event("stop_node") + new "confirm_restart"/"confirm_stop"
- **Safety**: SC-SAFETY-001 requires multi-step commit for destructive actions

#### W1.6: Zenoh Telemetry Consumption (RPN 270)
- **STAMP**: SC-ZENOH-001, SC-CTRL-007
- **What**: Subscribe to `indrajaal/health/*` Zenoh topics via ZenohMesh module for real-time health data
- **Why**: Currently polling Podman directly — misses F# HealthCoordinator enriched data (quorum, FPPS, circuit breaker)
- **Files**: `mesh_live.ex` mount/3 — add Zenoh subscription; new handle_info for Zenoh messages
- **Fallback**: If Zenoh unavailable, continue Podman polling (graceful degradation)

### Wave 2: P1 Core Functionality (9 features, FMEA RPN 120-200)

#### W2.1: Real Container Metrics for All Nodes (RPN 180)
- **STAMP**: SC-MON-002, SC-MON-003
- **What**: Replace simulated gentle random walk with actual `podman stats --no-stream --format json` for all running containers
- **Files**: `mesh_live.ex` — rewrite `update_node_metrics/1` to call `podman stats` for running containers
- **Interval**: Every 3s refresh (existing timer), batch query

#### W2.2: Aggregate Health Score in Header (RPN 160)
- **STAMP**: SC-MON-004
- **What**: Overall mesh health percentage in header bar: "HEALTH: 27% (4/15)" with gradient color
- **Computation**: `running_count / total_count * 100`, weighted by role criticality
- **Files**: `mesh_live.ex` — new helper `aggregate_health_score/1`

#### W2.3: Boot/Ignition Progress Display (RPN 200)
- **STAMP**: SC-IGNITE-004
- **What**: When boot in progress, show progress bar + thinking messages from PanopticIgnition DashboardState
- **Why**: SC-IGNITE-004 requires "Thinking" and real-time synthesis progress display
- **Files**: `mesh_live.ex` — new handle_info for ignition progress PubSub messages
- **UX**: Progress bar with percentage, current phase label, thinking messages

#### W2.4: Start Single Container Button (RPN 200)
- **STAMP**: SC-SIL4-005
- **What**: For stopped containers, show "START" button that executes `podman start <id>`
- **Flow**: Two-step commit like restart/stop — arm then confirm
- **Files**: `mesh_live.ex` — new handle_event("start_node"), handle_event("confirm_start")

#### W2.5: Mesh Verify Command (RPN 180)
- **STAMP**: SC-VER-031
- **What**: "VERIFY" button that runs mesh verification (check all containers healthy, ports, Zenoh)
- **Files**: `mesh_live.ex` — new handle_event("verify_mesh"), calls MasterControl or sa-verify
- **Result**: Flash message with verification summary

#### W2.6: Container Lifecycle Phase Display (RPN 160)
- **STAMP**: SC-SIL4-012, SC-SIL4-013
- **What**: Show current lifecycle phase per container (Created→Starting→Initializing→Connecting→Running)
- **Files**: `mesh_live.ex` — add `lifecycle_phase` field to node assign
- **Render**: Small phase badge on each container card

#### W2.7: FPPS Consensus Indicator (RPN 150)
- **STAMP**: SC-VAL-003, Omega-5
- **What**: Per-node badge showing "5/5 FPPS" or "3/5 DEGRADED" from 5-point validation
- **Computation**: Pattern, AST/health, statistical/failures, binary/heartbeat, line/response-time
- **Files**: `mesh_live.ex` — compute FPPS locally from available metrics

#### W2.8: Circuit Breaker Status (RPN 140)
- **STAMP**: SC-SIL4-019
- **What**: Show consecutive failure count per node; highlight nodes at/over threshold (3)
- **Files**: `mesh_live.ex` — track `consecutive_failures` in node assign
- **UX**: Orange warning badge when failures ≥ 2, red when ≥ 3 (circuit breaker open)

#### W2.9: Seed Node Indicators (RPN 120)
- **STAMP**: SC-SIL4-009
- **What**: Visual distinction for seed node (indrajaal-ex-app-1) — star icon, priority display
- **Files**: `mesh_live.ex` — role-based check in render_node, special seed badge
- **Why**: Seed health is critical for cluster stability

### Wave 3: P2 Enhanced Experience (5 features, FMEA RPN 60-120)

#### W3.1: Build History with EMA Timings (RPN 100)
- **STAMP**: SC-IGNITE-005
- **What**: Panel showing last build duration + EMA estimate per container from BuildHistory.fs SQLite
- **Files**: `mesh_live.ex` — query build-history.db on mount, show in detail panel

#### W3.2: Tier Boot Button (RPN 120)
- **STAMP**: SC-IGNITE-006, SC-SWARM-001
- **What**: Boot all containers in a tier simultaneously (Async.Parallel per SC-SWARM-001)
- **Files**: `mesh_live.ex` — new handle_event("boot_tier"), two-step commit

#### W3.3: Digital Twin State View (RPN 90)
- **STAMP**: SC-CHAYA-001, Omega-8
- **What**: Show whether Digital Twin is in sync, last sync timestamp
- **Files**: `mesh_live.ex` — subscribe to Chaya PubSub topic

#### W3.4: Image Staleness Indicator (RPN 70)
- **STAMP**: SC-IGNITE-007
- **What**: Show image age per container, flag stale (>168h = 7 days)
- **Files**: `mesh_live.ex` — query `podman image inspect` for creation date

#### W3.5: 5-Order Effects Log (RPN 60)
- **STAMP**: SC-CTRL-003
- **What**: Collapsible panel showing cascade analysis for recent operations
- **Files**: `mesh_live.ex` — new assign `:effects_log`, render as timeline

---

## 4. Root Cause Analysis

**Why is the page incomplete?**
- The LiveView was rewritten for 15-container genome (2026-03-31) but focused on topology visualization only
- F# CEPAF backend capabilities (HealthCoordinator, ContainerLifecycleManager) were developed independently without LiveView integration points
- No Zenoh subscriber bridge exists between F# health data and Elixir LiveView PubSub
- Two-step commit pattern (SC-SAFETY-001) not yet implemented for any action button

---

## 5. Fix Taxonomy

| Category | Count | Examples |
|----------|-------|---------|
| Missing Feature | 14 | Emergency stop, quorum, split-brain, real control |
| Simulated → Real | 3 | Container metrics, Zenoh data, FPPS consensus |
| UI Enhancement | 3 | Aggregate health bar, lifecycle phases, seed indicators |

---

## 6. Patterns & Anti-Patterns Discovered

### Patterns (Good)
- **EID Compliance**: 7-tier topology layout correctly models functional hierarchy
- **Genome Fidelity**: @sil6_genome module attribute matches PanopticIgnition.fs exactly
- **PubSub Architecture**: prajna:mesh subscription already in place for future enrichment
- **Category Type System**: Built/Pulled/Shared correctly mirrors F# ImageCategory DU

### Anti-Patterns (To Fix)
- **Flash-Only Control**: Buttons that show messages but take no action (restart_node, stop_node)
- **Direct Podman Polling**: Bypasses F# health enrichment layer (quorum, FPPS, circuit breaker)
- **Simulated Metrics**: Random walk for non-app containers hides real state
- **Missing Safety UI**: No emergency stop, no quorum display, no split-brain alert — violates SC-CTRL-004, SC-SIL4-011, SC-SIL4-015

---

## 7. Verification Matrix

| Wave | Feature | Verification Method |
|------|---------|-------------------|
| W1.1 | Emergency stop | Manual test: arm→confirm→verify containers stop |
| W1.2 | Quorum indicator | Assert correct N/M/K display for 4/15 swarm |
| W1.3 | Split-brain alert | Simulate unreachable nodes, verify banner |
| W1.4 | Apoptosis warning | Verify trigger conditions computed correctly |
| W1.5 | Real restart/stop | Execute restart on stopped container, verify status change |
| W1.6 | Zenoh telemetry | Verify subscription active when Zenoh router available |
| W2.* | Core features | LiveView test assertions + manual visual verification |
| W3.* | Enhanced features | Manual verification + Wallaby E2E |

---

## 8. Files Modified (Planned)

| File | Action | Wave |
|------|--------|------|
| `lib/indrajaal_web/live/prajna/mesh_live.ex` | Major rewrite | W1-W3 |
| `lib/indrajaal/cockpit/prajna/master_control.ex` | Wire emergency_stop | W1 |
| `lib/indrajaal/cockpit/prajna/mesh_health.ex` | New module — quorum/split-brain | W1 |
| `test/indrajaal_web/live/prajna/mesh_live_test.exs` | Update assertions | W1-W3 |
| `docs/specs/pages/mesh_live.md` | New page spec | W1 |

---

## 9. Architectural Observations

1. **Capability Asymmetry**: F# backend has ~5,800 lines of rich health/lifecycle logic; LiveView only surfaces ~15% via raw Podman polling
2. **Missing Bridge**: No Zenoh→PubSub→LiveView pipeline for F# health data; this is the single biggest integration gap
3. **Two-Step Commit Gap**: SC-SAFETY-001 requires arm→confirm for destructive actions; currently zero buttons implement this
4. **EID Principle Violation**: Page shows topology (physical) but not behavior (functional flows per SC-EID-001)

---

## 10. Remaining Gaps

- Full Wallaby E2E test file for mesh page (SC-COV-008)
- BDD feature file for mesh scenarios
- Page spec document at `docs/specs/pages/mesh_live.md`
- Zenoh→PubSub bridge for F# HealthCoordinator data (architectural prerequisite)

---

## 11. Metrics Summary

| Metric | Before | After (Target) |
|--------|--------|----------------|
| Implemented features | 10 | 30 |
| Flash-only buttons | 2 | 0 |
| Simulated metrics | 11 containers | 0 containers |
| STAMP constraints covered | 8 | 25+ |
| FMEA max unmitigated RPN | 400 | < 100 |
| Fractal layers wired | L1-L2 | L0-L7 |

---

## 12. STAMP & Constitutional Alignment

| Constraint | Current | Target |
|-----------|---------|--------|
| SC-CTRL-004 (Emergency stop < 5s) | VIOLATION | Compliant |
| SC-SIL4-011 (Quorum display) | VIOLATION | Compliant |
| SC-SIL4-015 (Split-brain alert) | VIOLATION | Compliant |
| SC-SAFETY-001 (Two-step commit) | VIOLATION | Compliant |
| SC-MON-002 (Infrastructure metrics) | PARTIAL | Compliant |
| SC-IGNITE-004 (Boot progress) | VIOLATION | Compliant |
| SC-ZENOH-001 (Zenoh telemetry) | VIOLATION | Compliant |
| SC-HMI-010 (Color Rich) | PARTIAL | Compliant |
| SC-EID-001 (Functional flows) | VIOLATION | Compliant |
| Psi-0 (Existence) | AT RISK | Protected |

---

## 13. Conclusion

The mesh cockpit page is architecturally sound (correct genome, EID layout, PubSub subscription) but functionally incomplete. 20 missing features span all 7 fractal layers. The 3-wave implementation plan prioritizes safety-critical features first (emergency stop, quorum, split-brain, real container control) before core functionality and enhanced experience. Total FMEA RPN will drop from ~3,600 (sum of unmitigated) to < 500 after Wave 1 completion.

**Critical Path**: Wave 1 features are all independent and can be implemented in parallel within the same file. No F# code changes required for Wave 1 — all safety logic can be computed from Podman state available on the Elixir side. Wave 2+ will benefit from Zenoh bridge integration.
