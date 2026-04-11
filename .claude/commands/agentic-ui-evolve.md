# Agentic UI Evolution Skill

Apply the full planning page evolution pattern to any C3I page. Implements LiveView-equivalent WebSocket reactivity, Gemma AI chat, responsive mobile-first design, fractal navigation, and 179+ Rust E2E tests.

## Usage
`/agentic-ui-evolve <page-path>` — e.g., `/agentic-ui-evolve /dashboard`

## Ultrathink Alignment
Focus Areas: #4 (Homomorphic Tripartite UI), #6 (SLM Cognitive Kernels), #9 (OpenClaw Penta-Stack), #10 (HA Seamless Upgrades)

---

## Phase 1: Multi-View & Fractal Navigation
1. Add 4-view toggle (Grid/Kanban/Timeline/Analytics) with keyboard shortcuts 1-4
2. Add L0-L7 fractal layer filter chips with keyword classification (see rule for keyword table)
3. Add AI search bar (Ctrl+K) with 200ms debounce, grid filter + Zettelkasten knowledge lookup
4. Add click-to-detail drill-down with 5 actions: Knowledge, Related, STAMP, Sub-Tasks, AI Analysis
5. Add elegant gradient badges: P0 red glow, P1 amber, P2 green, P3 muted outline
6. Add state change event log (status_change, priority_change, new_task, task_removed, data_diff)
7. Remove dead code (SC-MUDA-001)

## Phase 2: Real-Time Dynamic Updates
1. Live header updates every 5s: weather bar (emoji + mood + score), status cards, progress ring SVGs
2. Active data refresh every 1s with row-level diff detection + highlight animation (CSS `rowPulse`)
3. Heartbeat indicator: green (live) / amber (stale >5s) / red (disconnected)
4. Card value flash teal for 1.5s when data changes

## Phase 3: Responsive Mobile-First Design
1. Base CSS targets mobile (<768px): 1-col grids, stacked layout
2. `@media (min-width:768px)`: 2-col cards/kanban, 4x1 rings (90px), tablet font scaling
3. `@media (min-width:1024px)`: auto-fill cards, 4-col kanban, 100px rings, full tables
4. `@media (min-width:1400px)`: 110px rings, 2rem gaps, 1.4rem ring values
5. `min-height:44px` on ALL interactive elements (buttons, chips, search, cards)
6. `safe-area-inset-bottom` for notched phones
7. `scroll-behavior:smooth`, `overscroll-behavior:none`
8. `-webkit-overflow-scrolling:touch` for momentum scroll on tables/timeline
9. Glassmorphism: `backdrop-filter:blur(8px-16px)` on cards, panels, headers
10. CSS variables for theming: `var(--bg)`, `var(--text)`, `var(--accent)`, `var(--border)`

## Phase 4: WebSocket (LiveView-Equivalent)
1. Add Mist WebSocket upgrade handler on `/ws/<page-name>` in `web/server.gleam`
2. WsState tracks `push_count: Int` and `last_status: String` for diff detection
3. `ws_on_init`: Send initial status snapshot on connection, return state with no timer
4. Client sends `"ping"` every 1s → server diff-checks status → responds with:
   - `"update"` (status + active + blocked JSON) when data changed
   - `"heartbeat"` (seq counter only) when data unchanged — saves bandwidth
5. Client can send search queries → server responds with NIF search results
6. Auto-reconnect: exponential backoff 1s→2s→4s→8s→...→30s max
7. Falls back to HTTP polling (5s) when WS disconnected
8. **All three transports (WS + SSE + HTTP) MUST report identical data**

## Phase 5: AI Agent Integration (Gemma 3/4)
1. Chat widget: floating panel with message history, typing indicator, model label
2. Default: Gemma 3 (port 11434, 3.3GB, ~5s response) — fast enough for interactive chat
3. Fallback: Gemma 4 (port 11435, 9.6GB) on Gemma 3 failure
4. Use `/api/chat` with message arrays (NEVER `/api/generate` — returns empty)
5. System prompt enriched with live page data: total/active/blocked/completed counts
6. 15s AbortController timeout. Graceful fallback to NIF search context
7. Add `/api/v1/ai/status` (model info + capabilities) and `/api/v1/ai/chat?q=` endpoints

## Phase 6: Testing (Mandatory)
### Gleam Tests (106+ per page)
- C1 Page Structure: init() defaults, empty state
- C2 Status Badges: cockpit mode colors at boundaries (0.3, 0.5, 0.7, 0.9)
- C3 Data Grids: all filter variants, task counts
- C4 Timeline: OODA cycle ordering, timestamps
- C5 Interactive: ALL Msg variants through update()
- C6 Media/Rich: health_score computation, progress ring values
- C7 AI Advisory: AG-UI lifecycle, tool calls, reasoning events
- C8 Action Buttons: HITL approval flow, cockpit escalation
- Prime Paths: chained multi-step update() sequences
- TUI Render: non-empty ANSI output verification

### Rust E2E Tests (179+ per page, pure Rust, zero Python)
| Section | Tests | Coverage |
|---------|-------|----------|
| A. Server Health | 2 | HTTPS 200 |
| B. API Endpoints | 10 | All routes |
| C. Live Data | 3 | Status counts |
| D. DOM Elements | 21 | All IDs present |
| E. Responsive CSS | 7 | Breakpoints + touch |
| F. Page Content | 7 | Sections + cards + SVGs |
| G. JS Features | 26 | All functions present |
| H. SSE Stream | 4 | Event types + retry |
| I. WebSocket | 5 | Upgrade + ping + search |
| J. Gemma AI | 1 | Responds with context |
| K. AI Status | 2 | Model + capabilities |
| L. Search | 2 | Returns results |

### DAG Scenarios (6 per page, 27+ stages)
| DAG | Stages | Path |
|-----|--------|------|
| M: Triage Journey | 5 | page→status→blocked→search→WS verify |
| N: Real-Time Monitor | 6 | WS→status→HTTP compare→3 pings monotonic |
| O: AI Analysis | 5 | AI status→tasks→Gemma→search keyword→chat |
| P: View Consistency | 7 | all tasks→count→match active/blocked/completed→search subset |
| Q: Transport Consistency | 4 | SSE→WS→compare→match HTTP |
| R: Page↔API Integrity | 3 | HTML contains count→JS ref'd→JS >50KB |

### Responsive Tests (60 per page)
| Section | Viewport | Tests |
|---------|----------|-------|
| S. Mobile Triage | <768px | 12 (1-col, touch, safe-area, scroll, wrap) |
| T. Tablet Review | 768-1024px | 8 (2-col, rings, fonts, labels) |
| U. Desktop Canvas | 1024px+ | 8 (auto-fill, 4-col, auto-fit, 100px) |
| V. Wide Desktop | 1400px+ | 4 (110px, 2rem, 1.4rem) |
| W. Cross-Viewport | All | 12 (DOM, blur, transitions, fluid, vars, colors) |
| X. Mobile Journey | <768px | 7 (weather→status→blocked→search→chat) |
| Y. Desktop Journey | 1024px+ | 8 (views→fractal→tables→export→WS) |

## Phase 7: Documentation & Notification
1. 15-section specification: architecture, features, state machines, API, visual design, user journeys, testing, ruliology, performance
2. 13-section journal entry (SC-SYNC-DOC-002)
3. Email via SMTP: `sa-plan-daemon send-email --to Abhijit.Naik@bountytek.com --subject "..." --body "..." --attach <spec.md>`
4. NEVER use Gmail MCP — ALWAYS SMTP via sa-plan-daemon

## Verification Criteria (ALL must pass)
- [ ] Gleam build: 0 errors
- [ ] Gleam tests: 0 failures (3,941+ total)
- [ ] Rust E2E: 179+ tests, 0 failures
- [ ] 21+ DOM elements dynamically updated
- [ ] 10+ API endpoints HTTP 200
- [ ] WebSocket upgrade HTTP 101
- [ ] WS ping→heartbeat verified
- [ ] WS search→results verified
- [ ] Gemma AI responds with task context
- [ ] 4 responsive breakpoints verified
- [ ] 44px touch targets verified
- [ ] SSE + WS + HTTP all report identical data
- [ ] 6 DAG scenarios pass
- [ ] Mobile + Desktop user journeys pass

## Reference
- Rule: `.claude/rules/agentic-ui-responsive-design.md`
- Agent: `.claude/agents/agentic-ui-designer.md`
- Spec: `docs/architecture/planning-page-specification.md`
- Journal: `docs/journal/20260411-planning-page-evolution.md`
