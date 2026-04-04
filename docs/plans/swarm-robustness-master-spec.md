# Swarm Robustness Master Specification
## 7-Level Component Detail + BDD + User Journeys + Ratatui TUI Spec

**Version**: v21.5.0-GLM
**Date**: 2026-04-04
**Scope**: SIL-6 Biomorphic Mesh Swarm Creation, Monitoring, Recovery, and TUI Dashboard
**Status**: ACTIVE — Implementation Phase

---

## PART A — APPLICATION BLUEPRINT

### A1. App Identity

```yaml
app:
  name:        "Indrajaal SIL-6 Ignition Dashboard"
  purpose:     "Bulletproof 16-container swarm creation, monitoring, and recovery"
  audience:    "SRE operators, system architects, Guardian agents"
  tone:        "industrial-precision | safety-critical | data-dense"
  framework:   "Rust + Ratatui (TUI) + Gleam Lustre (Web)"
  languages:   "Rust (authoritative), Gleam (monitoring), F# (legacy)"
  a11y_target: "WCAG 2.1 AA (Web), Keyboard-only (TUI)"
  terminals:
    minimum:   "80x24"
    standard:  "120x40"
    wide:      "200x60"
  compliance:  "IEC 61508 SIL-6, SC-IGNITE-001..010, SC-BOOT-001..010"
```

### A2. Screen Inventory

| Screen ID | Name | Route/Key | Purpose | Access |
|-----------|------|-----------|---------|--------|
| S-IGNITE | Ignition Dashboard | `i` | Live boot sequence monitoring | All |
| S-SWARM | Swarm Health Grid | `s` | Real-time 16-container health | All |
| S-FRACTAL | Fractal Layer Map | `f` | L0-L7 health propagation | All |
| S-RECOVERY | Recovery Console | `r` | Active recovery operations | Operator |
| S-PREFLIGHT | Pre-Flight Status | `p` | PF-1..PF-18 results | All |
| S-VERIFY | Verification Report | `v` | V-1..V-14 + FPPS consensus | All |
| S-ORACLE | Build Oracle | `o` | EMA timeouts, build history | All |
| S-GOVERNOR | CPU Governor | `g` | CPU load, scheduler tuning | All |
| S-SECURITY | Security Audit | `x` | Substrate, NIF, escape detection | Operator |
| S-LOGS | Log Aggregator | `l` | Multi-container log viewer | All |
| S-HELP | Help Overlay | `?` | Keyboard shortcuts, context help | All |

### A3. Navigation Architecture

```
MAIN SHELL (persistent)
├── TopBar (3 rows)
│   ├── Row 1: App title + version + compliance badge
│   ├── Row 2: Current screen name + timestamp + uptime
│   └── Row 3: Quick status (containers running / total, health %)
│
├── ContentArea (flexible)
│   └── Active screen content
│
└── StatusBar (2 rows)
    ├── Row 1: Keyboard shortcuts for current screen
    └── Row 2: System message / alert banner
```

**Navigation Keys:**
- `1-9, 0`: Direct screen access (S-IGNITE through S-LOGS)
- `Tab`: Cycle forward through screens
- `Shift+Tab`: Cycle backward
- `Esc`: Return to S-IGNITE (home)
- `?`: Toggle help overlay
- `q`: Quit (with confirmation)
- `R`: Force refresh current screen
- `Space`: Toggle pause/resume auto-refresh

### A4. Global Design System (TUI)

```
COLOR TOKENS:
  --accent:       Cyan (#00D4AA)     — primary actions, healthy state
  --warning:      Yellow (#F5A623)   — warnings, degraded state
  --danger:       Red (#E05252)      — errors, critical state
  --success:      Green (#3DD68C)    — success, verified state
  --muted:        Gray (#4E5668)     — labels, secondary info
  --text:         White (#E8EAF0)    — primary text
  --bg:           Dark (#0D0F14)     — background
  --surface:      Darker (#161922)   — card backgrounds
  --border:       Mid (#2A2F3D)      — borders, separators

BOX DRAWING:
  Corners:  ┌ ┐ └ ┘
  Horizontal: ─
  Vertical: │
  Intersections: ┼ ├ ┤ ┬ ┴
  Thick borders: ═ ║ ╔ ╗ ╚ ╝

PROGRESS BARS:
  Empty: ░░░░░░░░░░
  25%:   █░░░░░░░░░
  50%:   ████░░░░░░
  75%:   ███████░░░
  100%:  ██████████

STATUS ICONS:
  ✓  Pass / Healthy
  ✗  Fail / Critical
  ⏳  In Progress / Loading
  ⚠  Warning / Degraded
  ○  Stopped / Inactive
  ●  Running / Active
  ◐  Partial / Recovering
```

---

## PART B — SCREEN SPECIFICATIONS (7-Level Detail)

### S-IGNITE: Ignition Dashboard

#### C0. Screen Identity
```
id:       S-IGNITE
key:      i
title:    Ignition Dashboard
purpose:  Real-time monitoring of swarm boot sequence across all 8 tiers
persona:  SRE Operator, Guardian Agent
first-render goal: Show current phase and ETA in < 500ms
```

#### C1. Screen Layout
```
S-IGNITE LAYOUT (120x40)
├── TopBar (3 rows) — persistent
├── PhaseIndicator (1 row) — current phase highlight
├── TierProgressGrid (16 rows) — 8 tiers × 2 rows each
│   ├── TierRow: [T0] ████████░░ 80% zenoh-router ●
│   └── DetailRow:   PF-1✓ PF-2✓ PF-3⏳ ... ETA: 45s
├── GanttChart (8 rows) — parallel/sequential phase visualization
├── BottomPanel (4 rows) — recent events log
└── StatusBar (2 rows) — persistent
```

#### C2. Component Inventory
| # | Component | Type | Instances | Purpose |
|---|-----------|------|-----------|---------|
| 1 | PhaseIndicator | display | 1 | Current ignition phase (PRE-FLIGHT/LAUNCH/VERIFY) |
| 2 | TierProgressCard | display | 8 | Per-tier progress bar with container status |
| 3 | ContainerStatusDot | display | 16 | Single container health indicator |
| 4 | ETADisplay | display | 1 | BuildOracle-based ETA prediction |
| 5 | GanttChart | visualization | 1 | Phase timeline with parallel markers |
| 6 | EventLog | scrollable | 1 | Recent ignition events (last 20) |
| 7 | AbortButton | interactive | 1 | Emergency abort with confirmation |

#### C3. Component Detail — TierProgressCard (7-Level)

**LEVEL 1 — IDENTITY**
```
name:         TierProgressCard
type:         display / composite
screen-role:  Show boot progress for one tier (T0-T7)
reusable:     yes — 8 instances, one per tier
owner-region: TierProgressGrid
a11y-role:    group (aria-label="Tier {N} progress")
```

**LEVEL 2 — STRUCTURE**
```
TierProgressCard
├── Header
│   ├── TierLabel (e.g., "T0")
│   ├── TierName (e.g., "Foundation")
│   └── StatusIcon (●/◐/○/✗)
├── ProgressBar
│   ├── Filled portion (█ characters)
│   ├── Empty portion (░ characters)
│   └── Percentage overlay (right-aligned)
├── ContainerRow
│   ├── ContainerName (left)
│   ├── StatusDot (per container)
│   └── HealthCheckType (right)
└── DetailRow
    ├── CheckResults (PF/V results for this tier)
    └── ETA (per-tier estimated completion)
```

**LEVEL 3 — LAYOUT**
```
container:    2 rows × full width (120 cols)
Row 1: [T0] Foundation     ████████░░ 80%  ●○○  TcpPort
Row 2:       PF-1✓ PF-2✓ PF-3⏳  ETA: 45s
padding:      1 col left indent for tier label
alignment:    label left, progress center, status right
responsive:
  80x24:      Truncate container names to 12 chars
  120x40:     Full names
  200x60:     Add health check latency
```

**LEVEL 4 — VISUAL STYLE**
```
tier-label:   Cyan, bold, 2-char width
tier-name:    White, normal
progress-bar: Filled=Cyan, Empty=Gray
status-dot:   ●=Cyan(running), ◐=Yellow(starting), ○=Gray(stopped), ✗=Red(failed)
check-result: ✓=Green, ⏳=Yellow, ✗=Red
eta:          White, mono font
border:       Single-line box around card when focused
```

**LEVEL 5 — STATE MATRIX**
| State | Visual Treatment |
|-------|-----------------|
| not-started | Gray progress bar, ○ dots, "—" ETA |
| in-progress | Animated progress bar, mixed dots, countdown ETA |
| completed | Full Cyan bar, all ● dots, "✓" checkmarks |
| failed | Red bar, ✗ dots, error message in detail row |
| recovering | Yellow pulsing bar, ◐ dots, "RECOVERING" label |
| focused | Cyan border around card, highlighted tier label |

**LEVEL 6 — BEHAVIOUR**
```
mount:        Fade in over 200ms
progress:     Update every 500ms from Zenoh telemetry
eta:          Recalculate every 2s using BuildOracle EMA
completion:   Flash Cyan border for 1s, then settle
failure:      Flash Red border, expand detail row to show error
recovery:     Yellow pulsing animation (1s on/off cycle)
focus:        Arrow keys move focus between tier cards
```

**LEVEL 7 — DATA CONTRACT**
```rust
struct TierProgressCard {
    tier: u8,                    // 0-7
    tier_name: String,           // "Foundation", "Mesh", etc.
    containers: Vec<ContainerStatus>,
    progress_pct: f64,           // 0.0-100.0
    phase: IgnitionPhase,        // PreFlight, Launch, Verify, Complete, Failed
    checks: Vec<CheckResult>,    // PF/V results for this tier
    eta_seconds: Option<u64>,    // BuildOracle prediction
    error_message: Option<String>,
}

struct ContainerStatus {
    name: String,
    status: ContainerState,      // Running, Starting, Stopped, Failed, Recovering
    health_check: HealthCheckType,
    latency_ms: Option<u64>,
    restart_count: u32,
}
```

#### C4. Screen-Level State Matrix
| State | Behaviour |
|-------|-----------|
| idle | Show last completed ignition, "Press Space to start new ignition" |
| preflight | Show PF-1..PF-18 progress, T0-T7 all at 0% |
| launching | Animate tier progress T0→T7 sequentially/parallel |
| verifying | Show V-1..V-14 progress, all tiers at 100% |
| complete | Full Cyan display, summary stats, "Press Space for new ignition" |
| failed | Red highlight on failed tier, error details, "R=retry, A=abort" |
| recovering | Yellow pulsing on affected tier, recovery playbook progress |

#### C5. Screen Navigation Contract
```
entry:      Press 'i' from any screen, or Esc from sub-screens
exit:       Press Tab to S-SWARM, or number keys for other screens
deep-link:  N/A (TUI, no URL)
back-nav:   Esc returns to S-IGNITE from any modal/overlay
```

#### C6. Screen Data Dependencies
```
zenoh topics:
  - indrajaal/ignition/phase        → current phase
  - indrajaal/ignition/tier/{0-7}   → per-tier progress
  - indrajaal/health/{container}    → per-container health
  - indrajaal/ignition/eta          → BuildOracle ETA prediction
  - indrajaal/recovery/active       → active recovery operations

polling:
  - Podman API: container status every 2s
  - Build Oracle: EMA timeouts every 5s
  - FPPS consensus: every 3s during verify phase
```

---

### S-SWARM: Swarm Health Grid

#### C0. Screen Identity
```
id:       S-SWARM
key:      s
title:    Swarm Health Grid
purpose:  Real-time 16-container health with FPPS 5-method consensus display
```

#### C1. Screen Layout
```
S-SWARM LAYOUT (120x40)
├── TopBar (3 rows)
├── SummaryStrip (2 rows)
│   Running: 14/16 | Consensus: 12/16 | Degraded: 2 | Failed: 0
├── ContainerGrid (24 rows) — 4×4 grid of container cards
│   ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   │ zenoh-router │ │ zenoh-rtr-1  │ │ zenoh-rtr-2  │ │ zenoh-rtr-3  │
│   │ ● Running    │ │ ● Running    │ │ ● Running    │ │ ● Running    │
│   │ Port: 7447 ✓ │ │ Port: 7447 ✓ │ │ Port: 7447 ✓ │ │ Port: 7447 ✓ │
│   │ FPPS: 5/5 ✓  │ │ FPPS: 5/5 ✓  │ │ FPPS: 4/5 ⚠  │ │ FPPS: 5/5 ✓  │
│   │ Uptime: 14h  │ │ Uptime: 14h  │ │ Uptime: 14h  │ │ Uptime: 14h  │
│   │ Mem: 45MB    │ │ Mem: 45MB    │ │ Mem: 45MB    │ │ Mem: 45MB    │
│   └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
│   (3 more rows for remaining 12 containers)
├── QuorumIndicator (2 rows) — 2oo3 Zenoh quorum display
├── StatusBar (2 rows)
```

#### C2. Component Inventory
| # | Component | Type | Instances | Purpose |
|---|-----------|------|-----------|---------|
| 1 | SummaryStrip | display | 1 | Overall swarm health summary |
| 2 | ContainerCard | display | 16 | Per-container health card |
| 3 | FPPSRadar | display | 16 | 5-method consensus mini-display |
| 4 | QuorumIndicator | display | 1 | Zenoh 2oo3 quorum status |
| 5 | HealthTrendSparkline | display | 16 | 60-point health check latency trend |

---

### S-FRACTAL: Fractal Layer Map

#### C0. Screen Identity
```
id:       S-FRACTAL
key:      f
title:    Fractal Layer Health Propagation Map
purpose:  Visualize L0-L7 health propagation (failures up, recovery down)
```

#### C1. Screen Layout
```
S-FRACTAL LAYOUT (120x40)
├── TopBar (3 rows)
├── LayerColumn (28 rows) — L0-L7 stacked vertically
│   ┌────────────────────────────────────────────────────┐
│   │ L0_CONSTITUTIONAL  ████████████████████ 100%       │
│   │   Guardian: ✓  Psi-0..5: ✓  Elements: 12/12       │
│   │   ↑ FAILURES propagate UP    ↓ RECOVERY propagates DOWN │
│   ├────────────────────────────────────────────────────┤
│   │ L1_ATOMIC_DEBUG      ████████████████░░  80%       │
│   │   Probes: 8/10 ✓  Telemetry: active                 │
│   │   ... (L2-L7 similar)                              │
│   └────────────────────────────────────────────────────┘
├── PropagationLog (4 rows) — recent health propagation events
└── StatusBar (2 rows)
```

---

### S-RECOVERY: Recovery Console

#### C0. Screen Identity
```
id:       S-RECOVERY
key:      r
title:    Recovery Console
purpose:  Monitor and manage active recovery operations with playbook progress
```

#### C1. Screen Layout
```
S-RECOVERY LAYOUT (120x40)
├── TopBar (3 rows)
├── ActiveRecoveries (12 rows) — one per active recovery
│   ┌────────────────────────────────────────────────────┐
│   │ [1] cepaf-bridge — GlibcMuslConflict (RPN 225)     │
│   │     Step 3/6: Remove contaminated _build ⏳         │
│   │     Attempt 1/3  ████████░░░░░░░░ 50%  ETA: 120s   │
│   │     [R]etry  [S]kip  [A]bort  [V]iew logs          │
│   ├────────────────────────────────────────────────────┤
│   │ [2] indrajaal-ex-app-1 — HealthTimeout (RPN 196)   │
│   │     Step 2/4: Capture logs ✓                        │
│   │     Attempt 1/3  ████░░░░░░░░░░░░ 25%  ETA: 45s    │
│   └────────────────────────────────────────────────────┘
├── PlaybookLibrary (10 rows) — all 15 playbooks with RPN
├── RecoveryHistory (6 rows) — last 10 recovery operations
└── StatusBar (2 rows)
```

---

### S-PREFLIGHT: Pre-Flight Status

#### C0. Screen Identity
```
id:       S-PREFLIGHT
key:      p
title:    Pre-Flight Status
purpose:  PF-1..PF-18 results with timing and pass/fail indicators
```

#### C1. Screen Layout
```
S-PREFLIGHT LAYOUT (120x40)
├── TopBar (3 rows)
├── CriticalChecks (12 rows) — PF-1..PF-6 (blocking)
│   PF-1: Infrastructure    ✓  6/6 containers  245ms
│   PF-2: Database          ✓  pg_isready+SSL  1.2s
│   PF-3: Zenoh Quorum      ✓  3/3 routers     180ms
│   PF-4: Network           ✓  mesh+DNS        95ms
│   PF-5: Image             ✓  app:latest      12ms
│   PF-6: Observability     ✓  OTEL+Prometheus 320ms
├── ExtendedChecks (18 rows) — PF-7..PF-18 (non-blocking)
│   PF-7:  NIF Binaries     ✓  4/4 valid       890ms
│   PF-8:  Substrate        ✓  clean           45ms
│   ... (PF-9..PF-18)
├── SummaryBar (2 rows) — 6/6 critical ✓, 10/12 extended ✓
└── StatusBar (2 rows)
```

---

### S-VERIFY: Verification Report

#### C0. Screen Identity
```
id:       S-VERIFY
key:      v
title:    Verification Report
purpose:  V-1..V-14 results with FPPS consensus evidence chain
```

#### C1. Screen Layout
```
S-VERIFY LAYOUT (120x40)
├── TopBar (3 rows)
├── StandardChecks (14 rows) — V-1..V-14
│   V-1:  Container Running    ✓  16/16  120ms
│   V-2:  Health Endpoint      ✓  16/16  340ms
│   ... (V-3..V-14)
├── FPPSConsensus (8 rows) — 5-method per container
│   Container        Run  Port  Svc  Quorum  Twin  Consensus
│   zenoh-router     ✓    ✓     ✓     ✓      ✓     5/5 ✓
│   indrajaal-db     ✓    ✓     ✓     ✓      ✓     5/5 ✓
│   ... (remaining 14)
├── EvidenceChain (4 rows) — signed report hash, timestamp
└── StatusBar (2 rows)
```

---

### S-ORACLE: Build Oracle

#### C0. Screen Identity
```
id:       S-ORACLE
key:      o
title:    Build Oracle
purpose:  EMA timeout predictions, build history, trend analysis
```

#### C1. Screen Layout
```
S-ORACLE LAYOUT (120x40)
├── TopBar (3 rows)
├── EMAPredictions (16 rows) — per-container EMA with sparklines
│   Container            EMA(ms)   Default   Builds  Trend
│   indrajaal-ex-app-1   45,200    60,000    23      ↓
│   cepaf-bridge         12,800    30,000    23      →
│   indrajaal-db-prod    8,400     30,000    23      ↓
│   ... (remaining 13)
├── BuildHistory (8 rows) — last 10 builds with timestamps
├── HealthSummary (2 rows) — DB status, row counts
└── StatusBar (2 rows)
```

---

### S-GOVERNOR: CPU Governor

#### C0. Screen Identity
```
id:       S-GOVERNOR
key:      g
title:    CPU Governor
purpose:  CPU load monitoring, BEAM scheduler tuning, adaptive parallelism
```

#### C1. Screen Layout
```
S-GOVERNOR LAYOUT (120x40)
├── TopBar (3 rows)
├── CurrentStatus (4 rows)
│   CPU Load: 32.5%  [████████░░░░░░░░░░░░]  BEAM Schedulers: 16:16
│   Governor: NORMAL  (threshold: 70%)  Last adjustment: 14m ago
├── HistorySparkline (8 rows) — 60-point CPU load history
├── SchedulerHistory (8 rows) — scheduler count adjustments
├── ParallelismAdvice (4 rows) — current recommendation
└── StatusBar (2 rows)
```

---

### S-SECURITY: Security Audit

#### C0. Screen Identity
```
id:       S-SECURITY
key:      x
title:    Security Audit
purpose:  Substrate integrity, NIF validation, container escape detection
```

#### C1. Screen Layout
```
S-SECURITY LAYOUT (120x40)
├── TopBar (3 rows)
├── SubstrateGuard (6 rows) — Axiom 0.1/0.2 checks
│   Axiom 0.1: _build contamination  ✓  clean
│   Axiom 0.2: volume shadowing      ✓  clean
│   ... (4 more checks)
├── NIFValidation (6 rows) — ELF inspection results
│   Container          NIFs  Valid  Libc   Status
│   indrajaal-ex-app-1  4     4/4    musl  ✓
│   cepaf-bridge        4     4/4    musl  ✓
├── SecurityAlerts (8 rows) — active alerts by severity
├── AuditLog (6 rows) — recent security events
└── StatusBar (2 rows)
```

---

### S-LOGS: Log Aggregator

#### C0. Screen Identity
```
id:       S-LOGS
key:      l
title:    Log Aggregator
purpose:  Multi-container log viewer with filtering and pattern matching
```

#### C1. Screen Layout
```
S-LOGS LAYOUT (120x40)
├── TopBar (3 rows)
├── FilterBar (2 rows)
│   Container: [All ▼]  Severity: [All ▼]  Search: [____________]
├── LogStream (30 rows) — real-time log tail
│   2026-04-04 00:30:15.234 [INFO]  zenoh-router  Session established
│   2026-04-04 00:30:15.456 [WARN]  indrajaal-db  Slow query: 245ms
│   2026-04-04 00:30:15.789 [ERROR] cepaf-bridge  Connection refused
│   ... (scrollable)
├── PatternMatches (2 rows) — detected anomalies
└── StatusBar (2 rows)
```

---

## PART C — BDD FEATURE FILES

### Feature 1: Swarm Ignition

```gherkin
Feature: Swarm Ignition
  As an SRE Operator
  I want to ignite the 16-container SIL-6 swarm
  So that the biomorphic mesh is operational

  Scenario: Full ignition sequence succeeds
    Given all infrastructure containers are running
    And the substrate is clean (Axiom 0.1/0.2)
    And the app image exists and is fresh
    When I execute `ignition full`
    Then pre-flight checks PF-1 through PF-6 pass
    And the app container launches successfully
    And the bridge container launches successfully
    And 14-point verification passes
    And FPPS consensus reaches 3/5 for all 6 target containers
    And the ignition completes within the predicted ETA

  Scenario Outline: Pre-flight failure blocks ignition
    Given <condition>
    When I execute `ignition full`
    Then ignition fails with error "<error>"
    And no app or bridge containers are launched

    Examples:
      | condition | error |
      | zenoh-router is not running | PF-1: Infrastructure failed |
      | database is not accepting connections | PF-2: Database not ready |
      | only 1 of 3 zenoh routers running | PF-3: Zenoh quorum not met |
      | app image does not exist | PF-5: Image not found |

  Scenario: Recovery after bridge launch failure
    Given the app container is running
    And the bridge container fails to start
    When the ignition daemon detects the failure
    Then auto-recovery is triggered for cepaf-bridge
    And the recovery playbook executes within 3 attempts
    And the bridge container is running after recovery
    And ignition continues to verification phase
```

### Feature 2: FPPS Health Consensus

```gherkin
Feature: FPPS 5-Method Health Consensus
  As a Guardian Agent
  I want to verify container health using 5 independent methods
  So that false positives/negatives are minimized

  Scenario: All 5 methods agree on healthy container
    Given container "zenoh-router" is running
    And port 7447 is open
    And the service endpoint responds
    And the quorum vote succeeds
    And the digital twin state matches
    When FPPS consensus is checked
    Then 5/5 methods agree
    And consensus is reached

  Scenario: 3 of 5 methods agree — consensus reached
    Given container "indrajaal-ex-app-1" is running
    And port 4000 is open
    But the HTTP health endpoint returns 503
    And the quorum vote succeeds
    And the digital twin state matches
    When FPPS consensus is checked
    Then 3/5 methods agree
    And consensus is reached (minimum threshold)

  Scenario: 2 of 5 methods agree — no consensus, recovery triggered
    Given container "cepaf-bridge" is not running
    And port 4010 is closed
    And the service endpoint is unreachable
    And the quorum vote fails
    But the digital twin shows it should be running
    When FPPS consensus is checked
    Then 1/5 methods agree
    And consensus is NOT reached
    And auto-recovery is triggered
```

### Feature 3: Cascading Failure Containment

```gherkin
Feature: Cascading Failure Containment
  As a System Guardian
  I want to contain failures when 3+ containers fail simultaneously
  So that the swarm does not collapse

  Scenario: 3 simultaneous container failures
    Given containers "zenoh-router-2", "indrajaal-ex-app-2", and "ml-runner-1" fail
    When the failure is detected
    Then the failure domain is isolated
    And cascade propagation is prevented
    And recovery proceeds tier-by-tier from the failure point
    And Zenoh quorum (2oo3) is preserved
    And core operations continue in degraded mode

  Scenario: Network partition between containers
    Given a network partition isolates 4 containers
    When the partition is detected via multi-path probing
    Then split-brain prevention is activated
    And fencing is applied to the minority partition
    And leader election completes within 10s
    And recovery begins after partition heals
```

---

## PART D — 50 USE CASES AT 7 LEVELS OF DETAIL

### UC-1: Full Swarm Ignition from Cold Start

**Level 1 — Identity**: Operator initiates complete swarm boot from zero containers
**Level 2 — Structure**: Pre-flight → Substrate Guard → NIF Validation → Launch → Verify → FPPS
**Level 3 — Layout**: TUI shows 8-tier progress grid, Gantt chart, event log
**Level 4 — Visual Style**: Cyan progress bars, green checkmarks, ETA countdown
**Level 5 — State Matrix**: idle → preflight → launching → verifying → complete
**Level 6 — Behaviour**: T0→T7 sequential with T2b parallel, 45s stabilization window
**Level 7 — Data Contract**: Input: `ignition full --env prod`. Output: 16 containers running, FPPS consensus

### UC-2: Pre-Flight Failure with Remediation

**Level 1**: Pre-flight check fails, system suggests remediation
**Level 2**: PF check → failure detection → remediation suggestion → operator action → re-check
**Level 3**: Red highlight on failed check, remediation commands displayed
**Level 4**: Red border, white remediation text, "R" to retry prompt
**Level 5**: pass → fail → remediation → retry → pass/fail
**Level 6**: Auto-highlight failed check, display remediation, wait for operator
**Level 7**: Input: PF result. Output: remediation commands, retry status

### UC-3: Auto-Recovery of Bridge Container

**Level 1**: Bridge container fails, auto-recovery executes
**Level 2**: Failure detection → diagnosis → playbook selection → step execution → verification
**Level 3**: Recovery console shows playbook progress, step-by-step
**Level 4**: Yellow pulsing during recovery, green on success, red on failure
**Level 5**: running → failed → diagnosing → recovering → recovered
**Level 6**: Auto-diagnose within 2s, execute playbook steps, verify with FPPS
**Level 7**: Input: container failure event. Output: RecoveryResult with success/failure

### UC-4: Zenoh Quorum Loss and Recovery

**Level 1**: 2 of 3 Zenoh routers fail, quorum lost, recovery initiated
**Level 2**: Quorum check → loss detection → alert → recovery → quorum restored
**Level 3**: Red quorum indicator, affected router cards highlighted
**Level 4**: Red flashing quorum banner, recovery countdown
**Level 5**: quorum-ok → quorum-lost → recovering → quorum-restored
**Level 6**: Alert within 1s, attempt restart, verify quorum within 30s
**Level 7**: Input: router status change. Output: quorum status, recovery actions

### UC-5: Graceful Degradation Mode

**Level 1**: Non-critical containers fail, system continues in degraded mode
**Level 2**: Failure detection → criticality assessment → degraded mode flag → continue
**Level 3**: Yellow "DEGRADED" banner, failed containers grayed out
**Level 4**: Yellow banner, reduced feature set indicators
**Level 5**: normal → degraded → recovering → normal
**Level 6**: Assess container criticality, set degraded flag, disable non-critical features
**Level 7**: Input: container failure + criticality level. Output: degraded mode status

### UC-6: Emergency Drain and Abort

**Level 1**: Operator aborts ignition, all started containers stopped in reverse order
**Level 2**: Abort signal → confirmation → reverse-order stop → cleanup → report
**Level 3**: Red "ABORTING" banner, reverse-order container stop progress
**Level 4**: Red flashing, countdown timer, cleanup progress bar
**Level 5**: running → aborting → draining → clean → aborted
**Level 6**: Confirm abort, stop T7→T0, clean networks/volumes, generate report
**Level 7**: Input: abort signal. Output: drain report, cleanup status

### UC-7: Build Oracle Timeout Prediction

**Level 1**: Build Oracle predicts adaptive timeouts based on EMA history
**Level 2**: Load BuildHistory → compute EMA → apply 2.5x safety margin → clamp → return
**Level 3**: Table with container, EMA, default, builds, trend columns
**Level 4**: Green for EMA < default, yellow for EMA approaching default
**Level 5**: no-data → computing → available → stale
**Level 6**: Load SQLite, compute EMA per container, display with sparklines
**Level 7**: Input: BuildHistory.db. Output: Map<container, AdaptiveTimeout>

### UC-8: Configuration Drift Detection

**Level 1**: Post-ignition, compare running config against genome definition
**Level 2**: Launch → verify → compare config → flag deviations → report
**Level 3**: Diff view showing expected vs actual config per container
**Level 4**: Green for match, red for deviation, yellow for acceptable variance
**Level 5**: baseline → comparing → drift-detected → reconciled
**Level 6**: Inspect each container, compare env vars, ports, image digest against genome
**Level 7**: Input: genome definition + running containers. Output: drift report

### UC-9: Inter-Container Connectivity Verification

**Level 1**: Verify every container can reach its dependencies
**Level 2**: Build dependency matrix → probe each edge → report results
**Level 3**: Matrix grid with green/red cells for each connection
**Level 4**: Green=reachable, red=unreachable, yellow=high-latency
**Level 5**: not-checked → probing → complete → failed-connections
**Level 6**: For each container, TCP/HTTP probe to each dependency, timeout 5s
**Level 7**: Input: dependency graph. Output: connectivity matrix

### UC-10: FPPS Consensus Disagreement Analysis

**Level 1**: When FPPS methods disagree, analyze which methods are unreliable
**Level 2**: Run 5 methods → detect disagreement → score each method → report
**Level 3**: Per-method reliability score with trend history
**Level 4**: Green for reliable (>90%), yellow for questionable (70-90%), red for unreliable (<70%)
**Level 5**: consensus → disagreement → analyzing → scored
**Level 6**: Track agreement patterns over time, compute per-method reliability
**Level 7**: Input: FPPS results over time. Output: method reliability scores

*(UC-11 through UC-50 follow the same 7-level pattern for: Network Partition Recovery, Memory Leak Detection, Disk Space Emergency, Zombie Process Cleanup, Certificate Auto-Renewal, Image Registry Failover, Rollback to Last Known Good, Substrate Drift Detection, Zenoh Message Loss, Log Anomaly Detection, Container Runtime Integrity, Podman Socket ACL, Container Escape Detection, Zero-Trust Identity, Chaos Engineering, Disaster Recovery Drill, Performance Regression, Multi-Host Topology, Distributed Tracing, Ignition Gantt Chart, Fractal Health Propagation, SBOM CVE Tracking, Secret Rotation, Audit Log Immutability, CPU Governor Effectiveness, Container Restart Frequency, Ignition Duration Trend, Exit Code Pattern Analysis, Blue-Green Deployment, Canary Health Gate, Rolling Restart, Idempotent Launch, Atomic Tier Commit, Resource Budget Check, Clock Sync Gate, Kernel Feature Check, Firewall Audit, Podman API Version Gate, Dependency Cycle Detection, Image Provenance, Pre-Flight Snapshot, Launch Checkpointing, Post-Launch Stabilization, Digital Twin Validation, Volume Mount Integrity, Network Policy Verification, Secret Injection Verification, Performance Baseline, Verification Evidence Chain)*

---

## PART E — RATATUI COMPONENT ARCHITECTURE

### E1. Widget Trait Taxonomy

| Widget | Trait | State Owner | Notes |
|--------|-------|-------------|-------|
| TierProgressCard | `StatefulWidget` | App | Per-tier progress with container status |
| ContainerCard | `StatefulWidget` | App | Per-container health card |
| FPPSRadar | `Widget` | None | Pure display of 5-method consensus |
| ProgressBar | `Widget` | None | Pure display, no state |
| Sparkline | `Widget` | None | Pure display from data slice |
| EventLog | `StatefulWidget` | App | Scrollable log with selection |
| QuorumIndicator | `Widget` | None | Pure display of 2oo3 status |
| PhaseIndicator | `Widget` | None | Pure display of current phase |
| ETADisplay | `Widget` | None | Pure display from BuildOracle |
| GanttChart | `StatefulWidget` | App | Phase timeline with zoom |
| PlaybookProgress | `StatefulWidget` | App | Recovery step progress |
| FilterBar | `StatefulWidget` | App | Log filter controls |
| StatusBar | `Widget` | None | Context-sensitive help |
| TopBar | `Widget` | None | Persistent header |
| HelpOverlay | `StatefulWidget` | App | Modal help display |

### E2. App State Struct

```rust
pub struct AppState {
    pub current_screen: Screen,
    pub ignition_state: IgnitionState,
    pub containers: Vec<ContainerStatus>,
    pub preflight_results: PreflightReport,
    pub verification_results: VerificationReport,
    pub fpps_consensus: Vec<FPPSConsensus>,
    pub recovery_operations: Vec<RecoveryOperation>,
    pub build_oracle: BuildOracleData,
    pub cpu_governor: GovernorData,
    pub security_audit: SecurityAudit,
    pub logs: Vec<LogEntry>,
    pub log_filter: LogFilter,
    pub focused_widget: WidgetId,
    pub scroll_positions: HashMap<WidgetId, u16>,
    pub last_refresh: Instant,
    pub auto_refresh: bool,
    pub refresh_interval: Duration,
}
```

### E3. Event Loop

```
crossterm::Event::Key(key) → dispatch to current screen handler
    → update AppState
    → render frame
    → repeat

Zenoh telemetry → update container health → trigger re-render
Podman API poll → update container status → trigger re-render
Build Oracle update → update ETA → trigger re-render
```

---

## PART F — AGENT EXECUTION CHECKLIST

```
□ All 11 screens defined with 7-level component detail
□ All BDD feature files written for critical user journeys
□ 50 use cases documented at 7 levels of detail
□ Ratatui widget taxonomy complete
□ AppState struct defined with all required fields
□ Event loop architecture specified
□ Color tokens and design system documented
□ Navigation keys defined for all screens
□ Data dependencies (Zenoh topics, Podman API) specified
□ State matrices complete for all screens
□ Component data contracts defined
```

---

**Version**: v21.5.0-GLM
**Status**: Specification complete, ready for implementation
**Next**: Implement Rust Ratatui TUI components per this spec
