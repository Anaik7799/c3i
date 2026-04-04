---
description: Automated Ratatui + AG-UI TUI evolution — 7-layer testing, snapshot regression, Gemini visual loop, BDD scenarios
allowed-tools: Bash(cargo:*), Bash(cd:*), Bash(python:*), Bash(vhs:*), Read, Write, Edit, Grep, Glob, Agent
argument-hint: [action] [--cycles N] [--tab NAME] [--viewport WxH] [--gemini] [--fix]
---

# TUI Evolution Command — Automated Ratatui + AG-UI Testing Pipeline

Orchestrates the full 7-layer TUI testing pyramid for the Indrajaal Ignition Dashboard
with optional Gemini visual closed-loop evolution.

## Architecture

```
/tui-evolve pipeline
├── Phase 1: BUILD          cargo build --release (ignition daemon)
├── Phase 2: UNIT           cargo test --lib (L1 pure function tests)
├── Phase 3: SNAPSHOT       cargo test --test tui_snapshot (L2 golden files)
├── Phase 4: STYLE          cargo test --test tui_style (L3 cell color)
├── Phase 5: RESPONSIVE     Render at 80x24, 120x40, 200x60 (L5 viewport)
├── Phase 6: BDD-VERIFY     Validate BDD scenarios against code (L3+L5)
├── Phase 7: GEMINI-LOOP    [optional] Visual AI regression (L7)
└── Phase 8: REPORT         Coverage summary + gap analysis
```

## Actions

### `full` (default) — Run complete 7-layer pipeline
Execute all phases sequentially. Stop on first critical failure.

```
1. Build the ignition daemon
2. Run all inline #[cfg(test)] unit tests
3. Run snapshot regression tests (if tests/tui_snapshot.rs exists)
4. Run style cell assertions (if tests/tui_style.rs exists)
5. Render all 10 tabs at 3 viewports, check for panics
6. Cross-reference BDD scenarios against test coverage
7. Generate coverage report
```

### `audit` — Gap analysis across all 10 tabs

For each of the 10 TUI tabs (Swarm, Governor, Checks, Trace, Topology, Build, NIF, Recovery, Logs, AgentUI):
1. Read the tab's render function in tui.rs
2. Identify all states: default, loading, error, empty, selected
3. Check which states have unit tests
4. Report coverage gaps as a table
5. Generate test stubs for missing coverage

### `add-tests` — Auto-generate tests for uncovered modules

Read each module with 0 tests. For each:
1. Identify pure functions (no podman/async calls)
2. Generate `#[cfg(test)] mod tests` with boundary value tests
3. Write the tests directly into the source file
4. Run `cargo test` to verify they pass

Priority order: tui.rs > preflight.rs > podman.rs > main.rs

### `snapshot-init` — Create initial snapshot test infrastructure

1. Add `insta = "1"` to dev-dependencies in Cargo.toml
2. Create `tests/tui_snapshot.rs` with snapshot tests for all 10 tabs
3. Run tests to generate initial `.snap` files
4. Report: "N snapshots created. Run `cargo insta review` to accept."

### `evolve` — Gemini visual closed-loop (requires --gemini flag)

Run the Gemini closed-loop TUI testing pipeline:
1. Build the TUI binary
2. For each tab x viewport combination:
   a. Spawn TUI in headless PTY
   b. Navigate to the target tab
   c. Capture frame as PNG (via vhs or svg-term pipeline)
   d. Send to Gemini Vision for 7-dimension review
   e. Parse issues JSON response
3. Generate Rust test stubs for each issue found
4. Repeat until N consecutive clean passes (default: 3)

Configuration:
- `--cycles N`: Max iterations (default: 20)
- `--tab NAME`: Focus on specific tab (default: all)
- `--viewport WxH`: Specific viewport (default: 80x24,120x40,200x60)

### `fix` — Auto-fix identified issues

When `--fix` is provided with `evolve`:
1. Parse Gemini review JSON from last run
2. For each issue with severity "critical" or "major":
   a. Locate the render function in tui.rs
   b. Apply the suggested fix
   c. Re-run tests to verify no regression
3. Commit fixes with ICP v2.0 format

### `status` — Current test coverage dashboard

```bash
echo "═══ IGNITION DAEMON TUI TEST STATUS ═══"
echo ""
echo "Module Coverage:"
grep -c "#\[test\]" src/*.rs 2>/dev/null | sort -t: -k2 -rn
echo ""
echo "External Tests:"
grep -c "#\[test\]" tests/*.rs 2>/dev/null | sort -t: -k2 -rn
echo ""
echo "Total:"
grep -c "#\[test\]" src/*.rs tests/*.rs 2>/dev/null | awk -F: '{sum+=$2} END {print sum " tests"}'
echo ""
echo "Modules with ZERO tests:"
grep -c "#\[test\]" src/*.rs 2>/dev/null | grep ":0$" | cut -d: -f1
echo ""
echo "Tab Snapshot Coverage:"
ls tests/snapshots/*.snap 2>/dev/null | wc -l
echo " snapshots exist"
```

## STAMP Constraints Verified

| ID | Check | Layer |
|----|-------|-------|
| SC-UIGT-001 | All 10 tabs have unit tests | L1 |
| SC-UIGT-003 | Tab LTS states enumerated | L1+L2 |
| SC-HMI-010 | INDRAJAAL color palette verified via cell assertions | L3 |
| SC-COV-001 | Critical render paths covered >= 100% | L1-L5 |
| SC-UIGT-004 | Prime path coverage C_path >= 0.95 | L4+L5 |

## 10 TUI Tab Inventory

| # | Tab | Render Function | Key Widgets | Priority |
|---|-----|----------------|-------------|----------|
| 0 | Swarm | render_swarm_tab | HealthMatrix, ContainerTable, PhaseBar | P0 |
| 1 | Governor | render_governor_tab | CpuGauge, Sparkline, ParallelismConfig | P0 |
| 2 | Checks | render_checks_tab | PreflightList, VerifyList, FlameBar | P0 |
| 3 | Trace | render_trace_tab | TraceLog, FlameGraph, DecisionSummary | P1 |
| 4 | Topology | render_topology_tab | MeshGraph, QuorumRing, LatencyMatrix | P1 |
| 5 | Build | render_build_tab | EmaTable, BuildHistory, DbHealth | P1 |
| 6 | NIF | render_nif_tab | ValidationTable, DynLibList | P2 |
| 7 | Recovery | render_recovery_tab | PlaybookList, RecoveryLog, BudgetBar | P0 |
| 8 | Logs | render_logs_tab | LogStream, FilterBar, RateIndicator | P1 |
| 9 | AgentUI | render_agentui_tab | StateVector, ApprovalQueue, AuditLog | P2 |

## 7-Dimension Visual Review Criteria (for Gemini loop)

When reviewing TUI screenshots, assess:

1. **LAYOUT INTEGRITY**: Box-drawing complete, no overflow, padding consistent
2. **CONTENT COMPLETENESS**: All widgets labeled, no empty borders
3. **TYPOGRAPHY**: No mid-word truncation, columns aligned, Unicode correct
4. **COLOUR/CONTRAST**: Text readable, accent consistent, states color-coded
5. **NAVIGATION**: Focus visible, shortcuts shown, active tab highlighted
6. **STATE CORRECTNESS**: Loading=spinner, error=message, empty=illustration
7. **AESTHETIC QUALITY**: Score 1-10, balanced, professional terminal look

## INDRAJAAL Color Palette (for L3 style assertions)

```rust
const CYAN:    Color = Color::Rgb(0, 212, 170);    // accent
const GREEN:   Color = Color::Rgb(61, 214, 140);    // success
const YELLOW:  Color = Color::Rgb(245, 166, 35);    // warning
const RED:     Color = Color::Rgb(224, 82, 82);      // error
const MAGENTA: Color = Color::Rgb(176, 82, 224);    // recovery
const DIM:     Color = Color::Rgb(78, 86, 104);      // muted
```

## TestBackend Pattern (for L1/L2 tests)

```rust
use ratatui::backend::TestBackend;
use ratatui::Terminal;

fn render_tab_to_string(tab_fn: impl Fn(&mut Frame, Rect, &DashboardState), w: u16, h: u16) -> String {
    let backend = TestBackend::new(w, h);
    let mut term = Terminal::new(backend).unwrap();
    let state = DashboardState::default();
    term.draw(|f| tab_fn(f, f.area(), &state)).unwrap();
    format!("{:?}", term.backend())
}
```

## BDD Scenario Cross-Reference

Each BDD scenario in `test/features/ignition/ignition_lifecycle.feature` maps to:
- At least one unit test (L1)
- At least one snapshot test (L2) for the affected tab
- At least one style assertion (L3) for state transitions

Mapping file: `docs/specs/tui/bdd-test-traceability.md`

## Execution Workflow

```
DAILY (developer):
  /tui-evolve status                    # see gaps
  /tui-evolve add-tests                 # fill gaps automatically
  cargo test --lib                       # verify (< 1s)

PR MERGE:
  /tui-evolve full                      # complete pipeline

RELEASE:
  /tui-evolve evolve --gemini --cycles 20  # Gemini visual loop
```

## Files

| Path | Purpose |
|------|---------|
| `native/ignition_daemon/src/tui.rs` | TUI rendering (2,019 lines) |
| `native/ignition_daemon/src/types.rs` | DashboardState, ContainerRow |
| `native/ignition_daemon/tests/tui_unit.rs` | External unit tests |
| `native/ignition_daemon/tests/snapshots/` | Snapshot golden files |
| `docs/specs/tui/ignition-dashboard-spec.md` | 7-level component spec |
| `test/features/ignition/ignition_lifecycle.feature` | 50 BDD scenarios |
| `.claude/commands/tui-test.md` | Base TUI test skill |

## Related Skills

- `/tui-test` — Base testing commands (run, unit, snapshot, bench)
- `/test` — Elixir test execution
- `/review` — Code review
- `/evolution` — Code evolution with Guardian safety
