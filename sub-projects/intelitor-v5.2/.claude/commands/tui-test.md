---
description: Ratatui TUI testing — unit, snapshot, style, responsive, integration for ignition dashboard
allowed-tools: Bash(cargo:*), Bash(cd:*), Read, Write, Edit, Grep, Glob, Agent
argument-hint: [action] [--tab N] [--viewport WxH] [--snapshot-update]
---

# Ratatui TUI Testing Skill (SC-UIGT, SC-HMI-010)

7-layer testing for the Ignition Dashboard TUI (native/ignition_daemon).

## Architecture

```
TUI TESTING STACK
├── L1 Unit (TestBackend)      cargo test (inline #[cfg(test)])     <1s
├── L2 Snapshot (insta)        cargo test --test tui_snapshot       <3s
├── L3 Style (Buffer cells)    cargo test --test tui_style          <1s
├── L4 Integration (PTY)       cargo test --test tui_integration    <30s
├── L5 Responsive (resize)     cargo test --test tui_responsive     <10s
├── L6 Accessibility           cargo test --test tui_a11y           <60s
└── L7 Visual (Gemini loop)    python scripts/gemini_loop.py        <45min
```

## Actions

### `run` (default) — Run all TUI tests
```bash
cd native/ignition_daemon && cargo test 2>&1
```

### `unit` — Layer 1 unit tests only (fast)
```bash
cd native/ignition_daemon && cargo test --lib 2>&1
```

### `snapshot` — Layer 2 snapshot tests
```bash
cd native/ignition_daemon && cargo test --test tui_snapshot 2>&1
```

### `snapshot-update` — Accept new snapshots
```bash
cd native/ignition_daemon && cargo insta review 2>&1
```

### `style` — Layer 3 style/color cell assertions
```bash
cd native/ignition_daemon && cargo test --test tui_style 2>&1
```

### `responsive` — Layer 5 viewport matrix
```bash
cd native/ignition_daemon && cargo test --test tui_responsive 2>&1
```

### `bench` — Run Criterion benchmarks
```bash
cd native/ignition_daemon && cargo bench 2>&1
```

### `coverage` — Test coverage report
```bash
cd native/ignition_daemon && cargo tarpaulin --out html --output-dir target/coverage 2>&1
```

### `audit` — Full audit: tests + clippy + coverage
```bash
cd native/ignition_daemon && cargo test 2>&1 && cargo clippy -- -W clippy::all 2>&1
```

### `add` — Add tests to a specific module
When action is `add`, read the target module source, identify untested pure functions,
and add `#[cfg(test)] mod tests` with comprehensive coverage. Focus on:
- Boundary values for numeric functions
- Edge cases (empty input, zero, overflow)
- All enum variant coverage
- Constant alignment with F# Core.fs values
- State machine transition tables

### `status` — Show test coverage summary
```bash
cd native/ignition_daemon && echo "=== Module Test Coverage ===" && \
grep -c "#\[test\]" src/*.rs 2>/dev/null | sort -t: -k2 -rn && \
echo "=== External Test Files ===" && \
grep -c "#\[test\]" tests/*.rs 2>/dev/null | sort -t: -k2 -rn && \
echo "=== Total ===" && \
(grep -c "#\[test\]" src/*.rs tests/*.rs 2>/dev/null | awk -F: '{sum+=$2} END {print sum " tests"}')
```

## STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-UIGT-001 | All 10 TUI tabs MUST have unit tests | CRITICAL |
| SC-UIGT-003 | Each tab LTS MUST enumerate all states and transitions | HIGH |
| SC-UIGT-004 | Prime path coverage C_path >= 0.95 for critical tabs | CRITICAL |
| SC-HMI-010 | Color Rich chromatic feedback verified via cell assertions | HIGH |
| SC-COV-001 | Static coverage >= 100% for critical render paths | CRITICAL |

## 10 TUI Tabs (Test Inventory)

| Tab | Key | Name | Inline Tests | Snapshot | Status |
|-----|-----|------|-------------|----------|--------|
| 0 | 1 | Swarm | NEEDED | NEEDED | Priority |
| 1 | 2 | Governor | NEEDED | NEEDED | Priority |
| 2 | 3 | Checks | NEEDED | NEEDED | Priority |
| 3 | 4 | Trace | NEEDED | NEEDED | Medium |
| 4 | 5 | Topology | NEEDED | NEEDED | Medium |
| 5 | 6 | Build | NEEDED | NEEDED | Medium |
| 6 | 7 | NIF | NEEDED | NEEDED | Low |
| 7 | 8 | Recovery | NEEDED | NEEDED | Priority |
| 8 | 9 | Logs | NEEDED | NEEDED | Medium |
| 9 | 0 | Agent UI | NEEDED | NEEDED | Low |

## Test Patterns

### Layer 1: Unit Test (TestBackend)
```rust
#[cfg(test)]
mod tests {
    use ratatui::backend::TestBackend;
    use ratatui::Terminal;

    fn make_terminal() -> Terminal<TestBackend> {
        Terminal::new(TestBackend::new(120, 40)).unwrap()
    }

    #[test]
    fn test_swarm_tab_renders_container_table() {
        let mut term = make_terminal();
        let state = DashboardState::default();
        term.draw(|f| render_swarm_tab(f, f.area(), &state)).unwrap();
        let buf = format!("{:?}", term.backend());
        assert!(buf.contains("Swarm"));
    }
}
```

### Layer 2: Snapshot Test (insta)
```rust
use insta::assert_snapshot;

#[test]
fn snapshot_swarm_tab_default() {
    let output = render_to_string(120, 40, |f| {
        let state = DashboardState::default();
        render_swarm_tab(f, f.area(), &state);
    });
    assert_snapshot!("swarm_default", output);
}
```

### Layer 3: Style Assertion
```rust
#[test]
fn test_healthy_container_uses_green() {
    let mut term = make_terminal();
    let mut state = DashboardState::default();
    state.containers[0].status = ContainerStatus::Running;
    term.draw(|f| render_swarm_tab(f, f.area(), &state)).unwrap();
    let cell = &term.backend().buffer()[(col, row)];
    assert_eq!(cell.fg, Color::Rgb(61, 214, 140)); // GREEN from INDRAJAAL palette
}
```

### Layer 5: Responsive Matrix
```rust
#[test]
fn test_swarm_tab_at_all_viewports() {
    for (w, h) in [(80, 24), (120, 40), (200, 60)] {
        let mut term = Terminal::new(TestBackend::new(w, h)).unwrap();
        let state = DashboardState::default();
        term.draw(|f| render_swarm_tab(f, f.area(), &state)).unwrap();
        let buf = format!("{:?}", term.backend());
        assert!(buf.contains("Swarm"), "Failed at {}x{}", w, h);
    }
}
```

## Module Test Status

Run `/tui-test status` to see current coverage across all modules.

## INDRAJAAL Color Palette (for style assertions)

```rust
const CYAN:    Color = Color::Rgb(0, 212, 170);    // accent, healthy
const GREEN:   Color = Color::Rgb(61, 214, 140);    // success, pass
const YELLOW:  Color = Color::Rgb(245, 166, 35);    // warning, degraded
const RED:     Color = Color::Rgb(224, 82, 82);      // error, critical
const MAGENTA: Color = Color::Rgb(176, 82, 224);    // special, recovery
const DIM:     Color = Color::Rgb(78, 86, 104);      // muted, inactive
```

## Files

| File | Purpose |
|------|---------|
| `native/ignition_daemon/src/tui.rs` | TUI rendering (2,019 lines, 10 tabs) |
| `native/ignition_daemon/src/types.rs` | DashboardState, ContainerRow, etc. |
| `native/ignition_daemon/tests/tui_unit.rs` | External unit tests |
| `native/ignition_daemon/Cargo.toml` | Dependencies (ratatui 0.28) |
| `docs/specs/tui/ignition-dashboard-spec.md` | 7-level component spec |
| `test/features/ignition/ignition_lifecycle.feature` | BDD scenarios |

## Related Skills
- `/test` — Elixir test execution
- `/compile` — Patient Mode compilation
- `/review` — Code review
- `/stamp` — STAMP constraint validation
