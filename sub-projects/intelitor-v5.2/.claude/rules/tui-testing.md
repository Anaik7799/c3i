# Ratatui TUI Testing Rules (SC-TUI-TEST)

## SUPREME MANDATE

**ALL Ratatui TUI rendering code MUST have 7-layer test coverage before release.**

The Ignition Dashboard TUI (native/ignition_daemon/src/tui.rs, 2,019 lines, 10 tabs)
is the primary operator interface for the most critical system operation (swarm boot).
Untested rendering logic leads to operator errors during mesh ignition.

---

## STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-TUI-TEST-001 | Every TUI tab MUST have at least 3 unit tests (default, loading, error states) | CRITICAL |
| SC-TUI-TEST-002 | Every TUI tab MUST have a snapshot test via insta crate | HIGH |
| SC-TUI-TEST-003 | INDRAJAAL color palette MUST be verified via cell-level style assertions | HIGH |
| SC-TUI-TEST-004 | TUI MUST render correctly at 80x24, 120x40, and 200x60 viewports | HIGH |
| SC-TUI-TEST-005 | All keyboard shortcuts MUST be tested (tab cycling, container selection, recovery) | HIGH |
| SC-TUI-TEST-006 | DashboardState::default() MUST produce a valid renderable state | CRITICAL |
| SC-TUI-TEST-007 | No TUI render function may panic on empty/null data | CRITICAL |
| SC-TUI-TEST-008 | Status bar MUST always display valid key hints | MEDIUM |
| SC-TUI-TEST-009 | Tab bar MUST highlight active tab in CYAN | MEDIUM |
| SC-TUI-TEST-010 | Container health colors MUST match: GREEN=healthy, YELLOW=degraded, RED=critical | HIGH |

## AOR Rules

| ID | Rule |
|----|------|
| AOR-TUI-TEST-001 | Run `/tui-test status` before any TUI code change to identify gaps |
| AOR-TUI-TEST-002 | After modifying tui.rs, run `cargo test --lib` to verify no regressions |
| AOR-TUI-TEST-003 | New TUI tabs MUST include tests in the same commit |
| AOR-TUI-TEST-004 | Snapshot changes MUST be reviewed via `cargo insta review` before accepting |
| AOR-TUI-TEST-005 | Use `/tui-evolve audit` to identify untested widget states |
| AOR-TUI-TEST-006 | Color assertions MUST use INDRAJAAL palette constants, not raw RGB values |
| AOR-TUI-TEST-007 | TUI tests MUST NOT require running containers (use DashboardState fixtures) |
| AOR-TUI-TEST-008 | Gemini visual loop (`/tui-evolve evolve --gemini`) MUST pass before release |

## 7-Layer Testing Pyramid

| Layer | Tool | Speed | CI Stage | Coverage Target |
|-------|------|-------|----------|-----------------|
| L1 Unit | TestBackend + #[test] | <1s | Every commit | All tabs x all states |
| L2 Snapshot | insta golden files | <3s | Every commit | 10 tabs x 3 viewports |
| L3 Style | Buffer cell fg/bg | <1s | Every commit | All health colors + selection |
| L4 Integration | PTY harness | <30s | PR merge | Keyboard nav + tab cycling |
| L5 Responsive | Viewport matrix | <10s | PR merge | 80x24 + 120x40 + 200x60 |
| L6 Accessibility | Focus order | <60s | Nightly | All focusable elements |
| L7 Visual | Gemini closed-loop | <45min | Release | 7-dimension review score >= 7 |

## INDRAJAAL Color Palette (Authoritative)

```rust
// From ConsoleChannel.fs, mapped to Ratatui
const CYAN:    Color = Color::Rgb(0, 212, 170);   // accent, healthy, active tab
const GREEN:   Color = Color::Rgb(61, 214, 140);   // success, container running
const YELLOW:  Color = Color::Rgb(245, 166, 35);   // warning, degraded
const RED:     Color = Color::Rgb(224, 82, 82);     // error, critical, failed
const MAGENTA: Color = Color::Rgb(176, 82, 224);   // recovery, special
const DIM:     Color = Color::Rgb(78, 86, 104);     // muted, inactive, not running
```

## Test Pattern

```rust
#[cfg(test)]
mod tests {
    use ratatui::backend::TestBackend;
    use ratatui::Terminal;

    #[test]
    fn test_tab_renders_without_panic() {
        let backend = TestBackend::new(120, 40);
        let mut terminal = Terminal::new(backend).unwrap();
        let state = DashboardState::default();
        terminal.draw(|f| render_tab(f, f.area(), &state)).unwrap();
        // If we reach here, the tab renders without panic
    }
}
```

## Related Documents

- `.claude/commands/tui-test.md` -- Base TUI test execution skill
- `.claude/commands/tui-evolve.md` -- Automated 7-layer evolution pipeline
- `docs/specs/tui/ignition-dashboard-spec.md` -- 7-level component spec for all 10 tabs
- `test/features/ignition/ignition_lifecycle.feature` -- 50 BDD scenarios
- `docs/journal/2026-04/20260404-0100-swarm-robustness-masterplan.md` -- 200 ranked ideas
