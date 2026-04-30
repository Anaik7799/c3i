# Phase 5 — End-to-end UX (L4, L5)

## Channels

1. **Playwright (browser)** — primary regression channel via `mcp__playwright__*`.
2. **Marionette (Flutter sub-projects)** — discovery + selector authoring (SC-MARIONETTE-003).
3. **Patrol (Flutter regression)** — multi-platform parity (SC-PATROL-MCP-005).

## Playwright suite (already executed, captured under `playwright/playwright-report.md`)

| ID | Section | Assertion |
|---|---|---|
| A.1 | Boot | HTTP 200 + 0 console errors |
| A.2 | Title | live counts in title (e.g. `19 blocked · 53 active · 3082 total`) |
| A.3 | DOM | required IDs present (`*-section`, `task-detail-panel`, `planning-grid.js`) |
| B.1..B.4 | View toggle | each click → only matching `*-section` visible |
| C.1..C.3 | Live data | NIF status, freshness, pages list match invariants |
| D | WebSocket | connect + ping + first frame < 200 ms |
| E | Fractal chips | click `L0` → highlight + filter applied |
| F | AI search | Ctrl+K focusable, debounced filter |
| G | DAG-Q | WS=SSE=HTTP within ±1 |
| H | Responsive | 375 / 768 / 1400 viewports rendered |
| I | Heartbeat | `staleness:"fresh"` during run |

## Cross-browser matrix

| Browser | Status |
|---|---|
| Chromium (MCP) | ✓ run 2026-04-30 |
| Firefox | TODO (P2 next pass) |
| WebKit | TODO (P3) |

## Marionette / Patrol parity (Flutter sub-projects)

`/planning` is a web page; Marionette/Patrol tests apply only when a Flutter sub-project mirrors planning data (e.g. FluffyChat dashboard tile). Out of scope for this pack; tracked under SC-MARIONETTE-001..012.

## Exit criteria

- Playwright suite 17/17 components green.
- 0 console errors, 0 4xx/5xx network responses.
- ΣRPN reduction ≥ 35 %.
