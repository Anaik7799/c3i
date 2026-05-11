# Planning Grid Agentic UI Playwright Fractal Expansion Plan

Date: 2026-05-11
Task ID: 116554277441926495
Scope: `/planning?view=grid` Agentic UI testing, Playwright expansion, AG-UI/A2UI contracts, NIF-backed state, ZK search, WebSocket behavior, and SIL-6 fractal coverage.

## 1. Objective

Expand the current planning grid test suite from strong default-flow assurance into full operational assurance. The current suite proves the page renders, hydrates, filters, links, uses NIF-backed counts, handles common failures, and runs across Chromium, Firefox, WebKit, Mobile Chromium, and Mobile WebKit. The next step is to verify mutation, restart, reconnect, malformed data, generated UI rejection, visual stability, performance, and multi-tab behavior.

The target outcome is a planning page that is verified as a command surface, not just a dashboard. Operators should be able to trust that the page remains correct while tasks change, backend services restart, sockets drop, search races occur, generated UI payloads arrive, and multiple browser contexts are open.

## 2. Current Baseline

| Area | Current evidence |
|---|---|
| Live page audit | 48 passed, 0 failed. |
| Playwright planning full | 85 passed, 5 opt-in skipped. |
| Browser matrix | Chromium, Firefox, WebKit, Mobile Chromium, Mobile WebKit. |
| Per browser project | 17 passed, 1 restart skip, 0 failed. |
| Gleam tests | 9752 passed, 0 failed. |
| NIF status | total 3168, pending 1803, active/in_progress 56, blocked 19, completed 1290 in the preceding audit. |
| Freshness | NIF and WebSocket wiring reported fresh. |
| Page-spec alignment | 100 percent aligned. |

Existing Playwright coverage already protects route rendering, static anchors, runtime hydration, view switching, status filters, history navigation, fractal L0-L7 filtering, detail panel actions, AI/ZK search, API failure handling, responsive layouts, same-origin links, AG-UI/A2UI positive contracts, WebSocket server ticks, and WebKit launch.

## 3. Fractal Test Architecture

| Layer | Testing responsibility | Playwright expansion |
|---|---|---|
| L0 Constitutional | Hard rules, safe claims, allowlisted contracts, no unsafe generated UI. | Negative AG-UI/A2UI schema tests, XSS escaping, invalid component rejection, no unverified route/email claims. |
| L1 Atomic | Individual controls, fields, rows, buttons, chips, IDs, ARIA. | Button focus loops, chip state transitions, duplicate ID checks after repeated interactions, malformed row data fallback. |
| L2 Component | Grid, kanban, timeline, analytics, detail panel, search, WebSocket status. | Component-specific mutation, error, loading, empty, overflow, and keyboard/touch tests. |
| L3 Transaction | Multi-step user workflows across URL, filter, view, search, detail, history. | View + status + layer + history matrix; create/edit/status flow; search-to-detail flow; failed-write recovery. |
| L4 System | Lustre shell, Effect IIFE runtime, Wisp APIs, NIF status, WebSocket route. | Restart job, WS reconnect/backoff, NIF/API postconditions after mutations, freshness staleness simulation. |
| L5 Cognitive | ZK search, STAMP/FMEA/RETE-UL evidence, AG-UI events, A2UI proposals. | Search debounce/cancellation, ZK result navigation, contract rejection, evidence panel completeness tests. |
| L6 Ecosystem | Browser, mobile, CI, dependency, sandbox-free runtime parity. | Cross-browser screenshot baselines, WebKit-specific touch/focus checks, robust CI worker and dependency gates. |
| L7 Federation | Served links, handoff docs, email artifacts, external operator routes. | Task artifact route checks, docs link validation, customer/internal URL validation, report/dashboard publication checks. |

## 4. Test Suites To Add

### P0: Operational Safety

| Suite | Why required | Additional functionality validated | Page improvement |
|---|---|---|---|
| Controlled restart | Real services restart during operation. | WebSocket reconnect, page state preservation, stale data refresh. | Operators keep live planning without manual refresh after daemon churn. |
| Mutation/write flows | Current suite mostly proves read behavior. | Task create, edit, status update, validation errors, NIF/API postconditions. | Planning grid becomes verified as an operational editor. |
| Freshness degradation | Backend can be stale or partially disconnected. | Stale freshness response, degraded banner/state, safe read-only fallback. | Operators see trustworthy state instead of silently stale data. |

### P1: Resilience And Security

| Suite | Why required | Additional functionality validated | Page improvement |
|---|---|---|---|
| Search debounce/cancellation | Rapid queries can race. | Only latest ZK result renders; stale promises ignored; error state clears. | Search behaves according to operator intent. |
| WebSocket forced reconnect | Network drops are normal. | Close/error handling, retry timing, no duplicate message handlers. | Live updates recover without page reload. |
| Malformed API payloads | Bad data can reach the UI. | Missing fields, wrong enum values, invalid counts, bad JSON. | Page degrades predictably instead of breaking. |
| XSS/unsafe content | Task titles and ZK excerpts may contain unsafe text. | Escaping in rows, detail panels, search results, and generated UI surfaces. | Protects operator browser and layout integrity. |
| Negative AG-UI/A2UI contracts | Agentic UI generation must remain allowlisted. | Unknown event types, malformed events, invalid component proposals rejected. | Prevents unsafe or unsupported generated UI from rendering. |

### P2: UX Quality And Scale

| Suite | Why required | Additional functionality validated | Page improvement |
|---|---|---|---|
| Visual regression | Selector tests miss layout drift. | Stable screenshots for grid, kanban, timeline, analytics, detail panel. | Maintains scanability and control placement. |
| Performance budgets | Task volume and runtime logic can grow. | Hydration, first row render, filter latency, view switch latency, search latency. | Keeps the page fast enough for repeated operator use. |
| Multi-tab behavior | Operators open multiple planning views. | Cross-context isolation or synchronization semantics, stale tab refresh. | Defines reliable command-center workflows. |
| Deep-link normalization | Shared URLs can contain bad params. | Invalid `view`, `status`, `layer`, and combined query normalization. | Prevents blank or incoherent page states. |
| Mobile touch parity | Desktop keyboard tests do not prove touch. | Tap chips, view controls, detail actions, search, horizontal overflow. | Mobile and tablet operation become first-class. |

### P3: Publication And Governance

| Suite | Why required | Additional functionality validated | Page improvement |
|---|---|---|---|
| Documentation route validation | Handoff artifacts must be reachable. | Localhost, customer Tailscale, internal HTTPS links. | Operators can inspect evidence without guessing paths. |
| Coverage dashboard artifact | Test results need reviewable shape. | Per-component pass/fail matrix, skipped tests, residual risk. | Makes quality state visible outside terminal output. |
| Email/report send evidence | External handoff can fail silently. | Attachment availability and command-level send acceptance. | Keeps dissemination auditable. |

## 5. Component Coverage Plan

| Component | Required tests |
|---|---|
| Planning shell | HTTP 200, no 404 shell, title, required anchors, bundle loaded, no duplicate IDs. |
| View switcher | Grid/kanban/timeline/analytics active state, ARIA, history, invalid view fallback. |
| Status chips | Count parity with NIF API, filter results, history restore, mutation postconditions. |
| Fractal filters | L0-L7 chips, matrix equivalence, empty layer fallback, invalid layer normalization. |
| Task rows | Stable row identity, escaped text, status badges, keyboard navigation, virtualized/large data scroll. |
| Detail panel | STAMP, FMEA, RETE-UL, ZK, related tasks, subtasks, analysis actions, loading/error states. |
| ZK/AI search | Ctrl+K, mobile search, debounce, cancellation, stale results, failed search, result navigation. |
| WebSocket | Welcome/tick, reconnect, forced close, restart, no duplicate listeners, stale-state refresh. |
| AG-UI | Health/state positive contracts, 32-event negative schema checks, unknown event rejection. |
| A2UI | Page-spec positive contract, invalid component proposal rejection, allowlist enforcement. |
| Responsive shell | Mobile/tablet/desktop screenshots, touch interactions, no horizontal overflow. |
| Links/navigation | Same-origin links, report links, task artifact links, customer/internal URL availability. |

## 6. Playwright File Plan

| File | Ownership |
|---|---|
| `tests/playwright/planning.spec.ts` | Smoke, route, hydration, view mode, freshness, WebSocket baseline. |
| `tests/playwright/planning-full-functionality.spec.js` | Deep functional matrix, component behavior, links, responsive, AG-UI/A2UI positive contracts. |
| `tests/playwright/planning-mutations.spec.ts` | New P0 write workflows: create, edit, status update, validation errors, NIF postconditions. |
| `tests/playwright/planning-resilience.spec.ts` | New P1 restart, WebSocket reconnect, API malformed payloads, stale freshness, debounce. |
| `tests/playwright/planning-contracts.spec.ts` | New P1 AG-UI/A2UI negative schema and generated UI rejection tests. |
| `tests/playwright/planning-visual.spec.ts` | New P2 screenshot baselines and layout thresholds. |
| `tests/playwright/planning-performance.spec.ts` | New P2 hydration/filter/view/search timing budgets. |
| `tests/playwright/planning-preflight.mjs` | Environment, WebKit, NIF, page shell, and browser launch gates. |

## 7. Runtime And CI Matrix

| Project | Required coverage |
|---|---|
| Chromium desktop | Full default suite, mutation, resilience, contracts, performance. |
| Firefox desktop | Full default suite, contracts, major mutation smoke. |
| WebKit desktop | Full default suite, touch/focus quirks, visual smoke. |
| Mobile Chromium | Responsive, touch, search, detail panel, status/fractal chips. |
| Mobile WebKit | Responsive, touch, search, overflow, detail panel. |

Recommended CI jobs:

| Job | Command | Notes |
|---|---|---|
| Preflight | `npm run preflight` | Fast gate for runtime prerequisites. |
| Planning full | `npm run test:planning-full` | Default cross-browser confidence. |
| Planning WebKit | `npm run test:planning-webkit` | Safari/WebKit-specific coverage. |
| Planning robust | `npm run test:planning-robust` | Preflight plus full suite. |
| Controlled restart | `PLANNING_ENABLE_SERVICE_RESTART=1 npm run test:planning-full` | Isolated CI lane only. |

## 8. Data And NIF Strategy

1. Treat NIF-backed status as the source of truth for counts.
2. Read `/api/v1/plan/status` before and after any mutation.
3. For create/edit/status tests, assert both UI state and backend state.
4. Do not use brittle fixture counts unless the test owns the fixture.
5. For live data, assert invariants: totals are non-negative, chips sum coherently, changed task appears or status count changes as expected.
6. Use freshness gates to avoid interpreting stale backend state as UI failure.

## 9. AG-UI And A2UI Contract Strategy

Positive tests prove valid contracts are available. Negative tests prove unsafe generated UI cannot bypass the contract.

| Contract | Positive assertions | Negative assertions |
|---|---|---|
| AG-UI health | Endpoint returns healthy planning integration. | Unknown event type rejected. |
| AG-UI state | Required planning state keys present. | Malformed event payload rejected. |
| A2UI page spec | Planning page aligned, score reported. | Invalid component type rejected. |
| Generated UI proposal | Allowlisted components render only when valid. | Unsafe HTML/script and unsupported controls rejected. |

## 10. Exit Criteria

| Gate | Target |
|---|---|
| Default Playwright | 0 failures across configured browsers. |
| Restart lane | Controlled restart passes in isolated job. |
| Mutation lane | Create/edit/status postconditions pass against NIF/API truth. |
| Contract lane | Positive and negative AG-UI/A2UI tests pass. |
| Visual lane | Baselines pass within agreed thresholds. |
| Performance lane | Hydration, filter, view, and search timings stay under budgets. |
| Accessibility | Keyboard, ARIA state, focus order, and mobile touch checks pass. |
| Publication | Coverage dashboard, journal, links, and route checks are current. |

## 11. Implementation Phases

### Phase A: Stabilize Test Harness

- Keep preflight as the first gate.
- Ensure WebKit dependencies are installed and checked.
- Keep sandbox-free browser launch settings in Playwright config.
- Preserve current default suite as regression baseline.

### Phase B: Add P0 Safety Tests

- Add `planning-mutations.spec.ts`.
- Add controlled restart lane behind `PLANNING_ENABLE_SERVICE_RESTART=1`.
- Add freshness staleness simulation.
- Require NIF/API postconditions for writes.

### Phase C: Add P1 Resilience And Contract Tests

- Add `planning-resilience.spec.ts`.
- Add `planning-contracts.spec.ts`.
- Mock malformed payloads and unsafe text.
- Force WebSocket close and verify reconnect/backoff.
- Add debounce/cancellation tests for ZK search.

### Phase D: Add P2 UX Quality Tests

- Add `planning-visual.spec.ts`.
- Add `planning-performance.spec.ts`.
- Add mobile touch parity.
- Add multi-tab semantics.
- Add invalid deep-link normalization matrix.

### Phase E: Publish Coverage Dashboard

- Generate per-component coverage table.
- Record pass/fail/skip by browser project.
- Link current journal, diagrams, ZK note, and route manifest.
- Keep email/report evidence separate from delivery claims.

## 12. Dashboard Shape

The coverage dashboard should expose:

| Panel | Contents |
|---|---|
| Summary | Pass/fail/skip counts, browser matrix, timestamp, commit/worktree note. |
| Component Matrix | Rows by component, columns by static/dynamic/resilience/contracts/visual/performance. |
| Fractal Matrix | L0-L7 coverage status and missing tests. |
| NIF/Wiring | Status API, freshness API, WebSocket, page-spec alignment. |
| Recommended Work | P0-P3 backlog with owners and test files. |
| Evidence Links | Journal, HTML, deck, diagrams, ZK, manifest, Playwright reports. |

## 13. Test Naming Convention

Use names that encode component, behavior, and risk:

```text
planning/<component>/<behavior>/<risk>
```

Examples:

```text
planning/status-chips/mutation-updates-nif-counts/p0
planning/zk-search/debounce-suppresses-stale-results/p1
planning/ag-ui/rejects-unknown-event-type/p1
planning/websocket/reconnects-after-forced-close/p1
planning/mobile/touch-fractal-filter-no-overflow/p2
```

## 14. Non-Goals

- Do not make restart tests part of the default fast lane.
- Do not make tests depend on unrelated global task counts except through invariant checks.
- Do not bypass AG-UI/A2UI allowlists to make generated UI render.
- Do not introduce raw browser JavaScript outside the Effect TS IIFE runtime.
- Do not treat command-level email acceptance as delivery confirmation.

## 15. Resulting Page Improvements

When this plan is implemented, the planning page gains:

1. Verified write behavior, not just read behavior.
2. Safer operation during backend restarts and socket drops.
3. Reliable ZK search under rapid operator input.
4. Stronger generated UI safety through negative contract tests.
5. Better protection against malformed and unsafe task content.
6. Stable visual layout across desktop, tablet, mobile, and WebKit.
7. Performance budgets that protect scan speed as task volume grows.
8. Explicit multi-tab behavior for realistic command-center use.
9. Durable dashboard evidence for future reviews.
