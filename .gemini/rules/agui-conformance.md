# SC-AGUI-UI-CONFORMANCE Validator Protocol

## Mandate

**Every page in the C3I navigation graph MUST be measured against the 15 SC-AGUI-UI-* components.** Subjective "this page looks evolved" is not evidence. The validator fetches live HTML and counts substring matches for 10 HTML-detectable components, producing an objective per-page report card.

Anti-Stub-That-Lies per [zk-bd82645aedcb5ef4]: this validator measures, it does not assert.

ZK lineage: [zk-bd82645aedcb5ef4] Stub-That-Lies (RPN 729), [zk-df4ff2addb9bed8a] prior "sparse pages" audit pattern, [zk-741220214a931009] /planning evolution closure, SC-AGUI-UI-001..015 (parent rule).

## STAMP Constraints

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-AGUI-CONFORM-001 | Validator MUST probe live HTML at `http://vm-1.tail55d152.ts.net:4100/`, not source code | CRITICAL |
| SC-AGUI-CONFORM-002 | Validator MUST score 10 HTML-detectable components (UI-001..009 + UI-015) | HIGH |
| SC-AGUI-CONFORM-003 | 5 non-HTML-detectable constraints (UI-010, -011, -013, -014, -015) MUST be explicitly excluded with reason | HIGH |
| SC-AGUI-CONFORM-004 | Output MUST classify pages into 3 tiers: evolved (≥9/10), partial (5-8), sparse (<5) | HIGH |
| SC-AGUI-CONFORM-005 | Report MUST sort ascending (most sparse first) to direct attention | MEDIUM |
| SC-AGUI-CONFORM-006 | New pages MUST be added to the `pages` list in the SAME commit as their route registration | HIGH |

## 10 HTML-detectable component checks

| # | SC ID | Component | Substring indicators |
|---|---|---|---|
| 1 | UI-001 | 4 view modes (Grid/Kanban/Timeline/Analytics) | `data-view`, `kanban`, `timeline` |
| 2 | UI-002 | L0-L7 fractal filter chips | `fractal-l0`, `fractal-l1`, `layer-filter` |
| 3 | UI-003 | AI search (Ctrl+K) | `search-bar`, `Ctrl+K`, `ai-search` |
| 4 | UI-004 | Click-to-detail drill-down | `detail-panel`, `drill-down`, `task-detail` |
| 5 | UI-005 | Gemma AI chat widget | `gemma`, `chat-widget`, `chat-panel` |
| 6 | UI-006 | WebSocket bidirectional | `ws://`, `/ws/`, `WebSocket` |
| 7 | UI-007 | State change event log | `change-log`, `event-log`, `mutation-log` |
| 8 | UI-008 | 4-breakpoint responsive CSS | `@media`, `768px`, `1024px` |
| 9 | UI-009 | 44px touch targets | `min-height:44px`, `min-height: 44px`, `touch-target` |
| 10 | UI-015 | Glassmorphism CSS | `backdrop-filter`, `blur(`, `glass` |

Excluded with reason:
- **UI-010** Rust E2E test count — test suite, not HTML
- **UI-011** WS diff-detect push — server-side OTP actor
- **UI-013** 6 DAG scenarios — test suite
- **UI-014** Gemma context enrichment — server-side prompt build

## Live baseline (2026-05-16)

```
$ gleam run -m scripts/verify/agui_conformance
══ Report — sorted by score (ascending = most sparse first) ══
  ○ partial 5/10  /immune (and 27 other baseline pages)
  ○ partial 7/10  / · /dashboard · /cockpit
  ✓ evolved 9/10  /planning

summary: 1 evolved, 31 partial, 0 sparse — total 32 pages
```

The 28 pages at 5/10 share an identical profile — they have WS + responsive + touch-targets + glassmorphism (baseline template), but lack fractal filter chips, AI search, drill-down, Gemma chat, and change log. This is the concrete "sparseness" definition operators can act on.

## Reference implementation

`sub-projects/scripts-gleam/src/scripts/verify/agui_conformance.gleam` (~115 LOC) — probes 32 routes, prints per-page check list + sorted summary.

## Cross-references

- `.claude/rules/agentic-ui-responsive-design.md` — parent SC-AGUI-UI-001..015 specification
- `.claude/rules/page-spec-checker.md` — sibling structural conformance (per-page required substrings)
- `.claude/rules/cpig-consistency.md` — sibling governance validator pattern
- `docs/journal/learn-loop-hardening-20260516/journal.md` — closure pack for the institutional-memory arc

## Governance parity

Mirror at `.gemini/rules/agui-conformance.md` per SC-SYNC-DOC-007.
