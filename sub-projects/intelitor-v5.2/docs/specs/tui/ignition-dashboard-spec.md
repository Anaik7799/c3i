# Ignition Dashboard TUI Spec — 7-Level Component Detail
## Version 1.0 | Framework: Ratatui 0.28 + Crossterm 0.28

---

## APPLICATION BLUEPRINT

```yaml
app:
  name:        "Indrajaal Ignition Dashboard"
  binary:      "ignition dashboard [--auto-boot] [--test-ui]"
  purpose:     "Real-time SIL-6 mesh boot monitoring, health, recovery"
  audience:    "Mesh operators, SRE engineers, autonomous agents"
  tone:        "aerospace-cockpit | data-dense | fail-safe"
  framework:   "Ratatui 0.28 (Rust) + Crossterm 0.28"
  palette:     "INDRAJAAL (Cyan, Green, Yellow, Red, Magenta, Dim)"
  refresh:     "2s auto-refresh via tokio::interval"
  terminal:    "Min 80x24, Optimal 120x40, Max 200x60"
```

## GLOBAL DESIGN SYSTEM — INDRAJAAL PALETTE

```rust
// From ConsoleChannel.fs mapped to Ratatui
const CYAN:    Color = Color::Rgb(0, 212, 170);   // accent, healthy
const GREEN:   Color = Color::Rgb(61, 214, 140);   // success, pass
const YELLOW:  Color = Color::Rgb(245, 166, 35);   // warning, degraded
const RED:     Color = Color::Rgb(224, 82, 82);     // error, critical
const MAGENTA: Color = Color::Rgb(176, 82, 224);   // special, recovery
const DIM:     Color = Color::Rgb(78, 86, 104);    // muted, inactive
const BG:      Color = Color::Rgb(13, 15, 20);     // background
const SURFACE: Color = Color::Rgb(22, 25, 34);     // panel background
const BORDER:  Color = Color::Rgb(42, 47, 61);     // borders
const TEXT:    Color = Color::Rgb(232, 234, 240);   // primary text
const TEXT2:   Color = Color::Rgb(136, 146, 164);   // secondary text
```

## TAB INVENTORY

| Tab # | Key | Name | Purpose | Primary Widget |
|-------|-----|------|---------|----------------|
| 0 | 1 | Swarm | 16-container health grid + status table | Table + HealthMatrix |
| 1 | 2 | Governor | CPU governance, adaptive parallelism | Gauge + Sparkline |
| 2 | 3 | Checks | Preflight + verify results | Checklist + FlameBar |
| 3 | 4 | Trace | Agent decision chain, DevUI | TraceLog + ReasoningTree |
| 4 | 5 | Topology | Network mesh, Zenoh quorum ring | AsciiGraph + QuorumRing |
| 5 | 6 | Build | Build Oracle EMA, history | Table + TrendLine |
| 6 | 7 | NIF | NIF validator, ELF inspection | Table + BinaryView |
| 7 | 8 | Recovery | Playbook status, recovery log | StepList + Timeline |
| 8 | 9 | Logs | Container log viewer | ScrollableLog + Filter |
| 9 | 0 | Agent UI | AG-UI state vector, HITL gates | StatePanel + ApprovalDialog |

---

## TAB 0: SWARM — Container Health Grid

### LEVEL 1 — IDENTITY
```
name:       SwarmTab
type:       data-display / monitoring
tab-role:   Primary operational view — all 16 containers at a glance
a11y:       Container table is keyboard-navigable (j/k or arrow keys)
```

### LEVEL 2 — STRUCTURE
```
SwarmTab
├── Header Bar
│   ├── Phase Indicator     "PHASE 4: APPLICATION" with progress bar
│   ├── State Vector        [C M N Z H Q] color-coded binary
│   └── Boot Timer          "Boot: 2m 34s | ETA: ~1m 20s"
├── Health Matrix (4x4 grid)
│   └── ContainerTile x16   colored square per container
├── Container Table
│   ├── Header Row          Name | Status | IP | Ports | CPU | Mem | Uptime | FPPS
│   └── Data Rows x16       one per container, selected row highlighted
└── Status Bar
    ├── Key Hints           "[Tab] next  [j/k] select  [Enter] detail  [R] recover"
    └── Refresh Counter     "Refresh in 1.8s"
```

### LEVEL 3 — LAYOUT
```rust
let chunks = Layout::default()
    .direction(Direction::Vertical)
    .constraints([
        Constraint::Length(3),      // Header bar
        Constraint::Length(6),      // Health matrix (4 rows + border)
        Constraint::Min(10),        // Container table (fills remaining)
        Constraint::Length(1),      // Status bar
    ])
    .split(area);
```

### LEVEL 4 — VISUAL STYLE
```
Header:         bg=SURFACE, border=BORDER
Phase text:     fg=CYAN, bold
State vector:   true=GREEN "1", false=RED "0"
Health matrix:  Healthy=GREEN "●", Degraded=YELLOW "◐", Critical=RED "○", Down=DIM "·"
Table header:   fg=TEXT2, bold, underline
Table rows:     fg=TEXT, selected=reverse(CYAN)
FPPS column:    5 dots: each GREEN/RED matching 5-method consensus
Status bar:     fg=DIM, bg=BG
```

### LEVEL 5 — STATE MATRIX
```
┌─────────────┬──────────────────────────────────────────────┐
│ State        │ Visual Treatment                             │
├─────────────┼──────────────────────────────────────────────┤
│ booting      │ Phase indicator animates, tiles flash DIM    │
│ healthy      │ All tiles GREEN, state vector all 1          │
│ degraded     │ Failed tiles YELLOW, FPPS dots partial       │
│ critical     │ Failed tiles RED, state vector has 0s        │
│ recovering   │ Recovering tile MAGENTA pulse                │
│ empty        │ "No containers running" centered message     │
│ refreshing   │ Subtle spinner in header bar                 │
└─────────────┴──────────────────────────────────────────────┘
```

### LEVEL 6 — BEHAVIOUR
```
j/Down:     Move selection down in container table
k/Up:       Move selection up
Enter:      Open container detail popup (inspect + env + logs)
R:          Trigger recovery playbook for selected container
r:          Force refresh now
Tab:        Next tab
Shift+Tab:  Previous tab
1-0:        Direct tab access
q/Ctrl+C:   Quit dashboard
Auto:       Refresh every 2s via podman inspect + stats
```

### LEVEL 7 — DATA CONTRACT
```rust
struct SwarmTabState {
    containers: Vec<ContainerRow>,       // 16 entries
    selected_container: usize,           // 0-15
    phase: IgnitionPhase,                // Preflight..Complete
    state_vector: StateVector,           // [C,M,N,Z,H,Q]
    boot_start: Option<Instant>,         // boot timer
    ema_remaining_ms: Option<u64>,       // ETA from build oracle
}

struct ContainerRow {
    name: String,
    status: ContainerStatus,             // Running/Created/Exited/Error
    ip: String,
    ports: Vec<u16>,
    cpu_pct: f32,
    memory_mb: u32,
    memory_limit_mb: u32,
    uptime_secs: u64,
    fpps: [bool; 5],                     // 5-method consensus
    restart_count: u32,
}
```

---

## TAB 1: GOVERNOR — CPU Governance

### LEVEL 1 — IDENTITY
```
name:       GovernorTab
type:       monitoring / control
tab-role:   CPU utilization monitoring with adaptive parallelism display
```

### LEVEL 2 — STRUCTURE
```
GovernorTab
├── CPU Gauge              large gauge widget 0-100%
├── Sparkline Panel        30s CPU history as sparkline
├── Parallelism Config
│   ├── Schedulers         "+S {N}:{N}"
│   ├── Dirty IO           "+SDio {N}"
│   ├── Mix Jobs           "--jobs {N}"
│   └── Nice Level         "nice {N}"
├── Threshold Indicators   colored bars at 60/70/80/85%
└── Memory Panel           Available / Used / Cached from /proc/meminfo
```

### LEVEL 3 — LAYOUT
```rust
let chunks = Layout::default()
    .direction(Direction::Vertical)
    .constraints([
        Constraint::Length(5),      // CPU Gauge
        Constraint::Length(4),      // Sparkline
        Constraint::Length(8),      // Parallelism config
        Constraint::Min(5),         // Memory panel
    ])
    .split(area);
```

### LEVEL 4 — VISUAL STYLE
```
Gauge < 60%:   fg=GREEN, label="FULL SPEED"
Gauge 60-70%:  fg=CYAN, label="SLIGHT REDUCTION"
Gauge 70-80%:  fg=YELLOW, label="MODERATE THROTTLE"
Gauge 80-85%:  fg=RED, label="HEAVY THROTTLE"
Gauge > 85%:   fg=RED blink, label="WAITING (CPU > 85%)"
Sparkline:     fg=CYAN, filled with braille chars
```

### LEVEL 7 — DATA CONTRACT
```rust
struct GovernorTabState {
    cpu_pct: u8,
    cpu_history: VecDeque<u8>,           // 30 samples (60s at 2s)
    schedulers: u8,                       // 6/10/12/16
    dirty_io: u8,
    mix_jobs: u8,
    nice_level: u8,
    mem_available_mb: u64,
    mem_used_mb: u64,
    mem_cached_mb: u64,
}
```

---

## TAB 2: CHECKS — Preflight + Verification

### LEVEL 2 — STRUCTURE
```
ChecksTab
├── Preflight Panel (left)
│   └── Checklist x18      PF-1..PF-18 with pass/fail/skip icon + duration_ms
├── Verify Panel (right)
│   └── Checklist x14      V-1..V-14 with pass/fail icon + duration_ms
└── Summary Bar            "Preflight: 18/18 PASS (2.3s) | Verify: 14/14 PASS (45.2s)"
```

### LEVEL 4 — VISUAL STYLE
```
Pass:    GREEN "✓" + check name
Fail:    RED "✗" + check name + error detail
Skip:    DIM "○" + check name
Running: YELLOW "⏳" + check name (animated)
Duration flame bar: proportional width, GREEN < target, RED > target
```

---

## TAB 3: TRACE — Agent Decision Chain

### LEVEL 2 — STRUCTURE
```
TraceTab
├── Reasoning Tree (left 60%)
│   └── TraceEntry[] scrollable list with indentation
├── OTel Flame Bars (right 40%)
│   └── Per-phase latency bars relative to timeout budget
└── Decision Summary
    ├── Confidence Score     "92.4% (FPPS: 4/5)"
    └── Active Directive     "SC-IGNITE-006: Wave parallel boot"
```

### LEVEL 4 — VISUAL STYLE
```
TraceEntry decision:    CYAN prefix "DECIDE:"
TraceEntry observation: GREEN prefix "OBSERVE:"
TraceEntry action:      MAGENTA prefix "ACT:"
Flame bar < 50%:        GREEN "🟩"
Flame bar 50-80%:       YELLOW "🟧"
Flame bar > 80%:        RED "🔥"
```

---

## TAB 4: TOPOLOGY — Network Mesh

### LEVEL 2 — STRUCTURE
```
TopologyTab
├── ASCII Mesh Graph
│   ├── Zenoh Router Ring (3 nodes, 2oo3 quorum indicator)
│   ├── App Cluster (3 nodes, connected to routers)
│   ├── Cognitive Layer (cortex + bridge)
│   └── Satellite Nodes (ollama, mojo, ml-runners)
├── Quorum Status         "QUORUM: 3/3 ACHIEVED ✓"
├── Latency Matrix        container-to-container ping times
└── Connection Count      per-container active connections
```

---

## TAB 5: BUILD — Build Oracle

### LEVEL 2 — STRUCTURE
```
BuildTab
├── EMA Table
│   └── Container | Last Build | EMA Duration | Timeout | Prediction Accuracy
├── Build History (scrollable)
│   └── Timestamp | Container | Action | Duration | Cache Hit% | Success
└── DB Health              "WAL mode: ✓ | Rows: 247 | Age: 3d"
```

---

## TAB 6: NIF — NIF Validator

### LEVEL 2 — STRUCTURE
```
NifTab
├── Validation Results Table
│   └── NIF Name | Path | Libc Flavor | ELF Class | Machine | Valid
├── Dynamic Libraries (per selected NIF)
│   └── Library[] list from ELF inspection
└── Interpreter Path       "/lib64/ld-linux-x86-64.so.2"
```

---

## TAB 7: RECOVERY — Playbook Status

### LEVEL 2 — STRUCTURE
```
RecoveryTab
├── Active Playbooks (if any)
│   └── Playbook | Step N/M | Status | Retry K/3
├── Failure Mode Table
│   └── Mode | RPN | Steps | Max Retries | Escalation
├── Recovery History (scrollable)
│   └── Timestamp | Container | Mode | Success | Duration
└── Budget Status          "Recovery budget: 2/3 used (resets in 7m)"
```

---

## TAB 8: LOGS — Container Log Viewer

### LEVEL 2 — STRUCTURE
```
LogsTab
├── Log Stream (scrollable, auto-scroll when at bottom)
│   └── [container] [level] [timestamp] message
├── Filter Bar
│   ├── Container selector (all / specific)
│   ├── Level toggle (ERROR / WARN / INFO / DEBUG)
│   └── Search input ('/' to activate)
└── Rate Indicator         "42 lines/sec | 3 errors/min"
```

### LEVEL 6 — BEHAVIOUR
```
/:          Activate search mode (regex)
l:          Toggle live/paused mode
e:          Export visible logs to file
b:          Bookmark current line
j/k:        Scroll up/down
G:          Jump to bottom (follow mode)
g:          Jump to top
1-9:        Filter to specific container
0:          Show all containers
```

---

## TAB 9: AGENT UI — AG-UI State Vector

### LEVEL 2 — STRUCTURE
```
AgentUITab
├── State Vector Panel
│   └── [C=1 M=1 N=1 Z=1 H=0 Q=1] with transition timestamps
├── Active Agent Display
│   ├── Agent Name + Status
│   ├── Current Action
│   └── Reasoning Chain
├── HITL Approval Queue
│   └── Pending approvals with [Y] approve / [N] deny
├── Notification Queue
│   └── Dismissable alerts from recovery/health
└── Audit Log
    └── Scrollable history of all agent actions
```

---

## USER JOURNEY MAPS

### Journey 1: Happy Boot (Normal Path)
```
Operator runs: ignition dashboard --auto-boot
  1. TUI renders → Swarm tab active → "PHASE 0: PREFLIGHT" in header
  2. Checks tab updates live: PF-1 ✓, PF-2 ✓, ... PF-18 ✓
  3. Phase advances → "PHASE 1: FOUNDATION" → Zenoh tiles turn GREEN
  4. Phase advances → "PHASE 2: MESH" → Quorum tiles turn GREEN
  5. Phase advances → "PHASE 3: COGNITIVE" → Bridge/Cortex GREEN
  6. Phase advances → "PHASE 4: APPLICATION" → App-1 GREEN
  7. Phase advances → "PHASE 5: SWARM" → All remaining GREEN
  8. State vector: [1 1 1 1 1 1] → all GREEN
  9. Header: "BOOT COMPLETE — 16/16 containers healthy (3m 42s)"
  10. Operator reviews Topology tab → full mesh visible
```

### Journey 2: Failed Boot + Recovery
```
  1. Preflight passes → launch begins → Wave 2 starts
  2. cepaf-bridge fails → tile turns RED → error in Checks tab
  3. Recovery tab activates → "NIF Compilation Failure (RPN 252)"
  4. Playbook Step 1/5: Check Rust toolchain → PASS
  5. Playbook Step 2/5: Clean NIF artifacts → PASS
  6. Playbook Step 3/5: Rebuild NIF → PASS
  7. Playbook Step 4/5: Restart container → PASS
  8. Playbook Step 5/5: Health check → PASS
  9. Bridge tile turns GREEN → boot resumes
  10. Full boot completes → operator reviews Recovery History tab
```

### Journey 3: Degraded Mode
```
  1. Boot proceeds normally through Wave 4
  2. Wave 5: indrajaal-mojo fails (non-critical)
  3. Dashboard shows: "15/16 containers (DEGRADED — mojo unavailable)"
  4. Mojo tile turns YELLOW, not RED (non-critical container)
  5. Agent UI shows: "Degraded mode accepted — ML inference unavailable"
  6. Operator can press 'R' on mojo to attempt recovery
  7. System continues operating with reduced capability
```

---

## KEYBOARD SHORTCUT REFERENCE

| Key | Context | Action |
|-----|---------|--------|
| 1-9, 0 | Global | Switch to tab N |
| Tab | Global | Next tab |
| Shift+Tab | Global | Previous tab |
| j / Down | Table/List | Select next item |
| k / Up | Table/List | Select previous item |
| Enter | Table | Open detail for selected item |
| R | Swarm tab | Trigger recovery for selected container |
| r | Any tab | Force immediate refresh |
| p | Any tab | Run preflight checks |
| f | Any tab | Run full ignition sequence |
| / | Logs tab | Activate search |
| l | Logs tab | Toggle live/paused |
| e | Logs tab | Export logs to file |
| b | Logs tab | Bookmark current line |
| G | Logs tab | Jump to bottom |
| g | Logs tab | Jump to top |
| ? or h | Any tab | Show help overlay |
| q | Any tab | Quit (with confirmation if boot in progress) |
| Ctrl+C | Any tab | Graceful shutdown + terminal cleanup |
| Y | Agent UI | Approve pending HITL action |
| N | Agent UI | Deny pending HITL action |

---

## CROSS-TAB NAVIGATION ARCHITECTURE

```
Tab Bar (always visible at top)
  [1:Swarm] [2:Gov] [3:Checks] [4:Trace] [5:Topo] [6:Build] [7:NIF] [8:Recovery] [9:Logs] [0:AgentUI]

Active tab: CYAN background + bold text
Inactive tabs: DIM text
Tabs with errors: RED badge count (e.g., "Recovery [2]")
```

---

*spec version: 1.0 | framework: Ratatui 0.28 | task: 36f27d4d*
