# Agentic UI Responsive Design Protocol (SC-AGUI-UI)

## Mandate
Every C3I web page MUST implement the full agentic responsive design pattern. This protocol applies to all 31 pages. The Planning page (`/planning`) is the reference implementation.

**Ultrathink Alignment**: Focus Areas #4 (Homomorphic Tripartite UI), #6 (Embedded SLM Cognitive Kernels), #9 (OpenClaw Penta-Stack Agentic UI), #10 (HA Seamless Upgrades).

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-AGUI-UI-001 | Every page MUST have 4 view modes (Grid/Kanban/Timeline/Analytics) | HIGH |
| SC-AGUI-UI-002 | Every page MUST have L0-L7 fractal filter chips with keyword classification | HIGH |
| SC-AGUI-UI-003 | Every page MUST have AI search (Ctrl+K) with Zettelkasten lookup | HIGH |
| SC-AGUI-UI-004 | Every page MUST have click-to-detail drill-down (5 actions: Knowledge, Related, STAMP, Sub-Tasks, AI Analysis) | HIGH |
| SC-AGUI-UI-005 | Every page MUST have Gemma AI chat widget (Gemma 3 fast + Gemma 4 fallback) | MEDIUM |
| SC-AGUI-UI-006 | Every page MUST have WebSocket real-time bidirectional push on `/ws/<page>` | HIGH |
| SC-AGUI-UI-007 | Every page MUST have state change event log capturing mutations | MEDIUM |
| SC-AGUI-UI-008 | Every page MUST have responsive 4-breakpoint mobile-first CSS | CRITICAL |
| SC-AGUI-UI-009 | All interactive elements MUST have 44px min touch targets (WCAG 2.1 AA) | CRITICAL |
| SC-AGUI-UI-010 | Every page MUST pass 179+ Rust E2E tests (zero Python) | CRITICAL |
| SC-AGUI-UI-011 | WebSocket MUST use diff-detected push (heartbeat when unchanged, full data when changed) | HIGH |
| SC-AGUI-UI-012 | Triple transport (WS + SSE + HTTP polling) MUST report identical data (DAG scenario Q) | HIGH |
| SC-AGUI-UI-013 | Every page MUST have 6 multi-step DAG test scenarios for cross-component coverage | HIGH |
| SC-AGUI-UI-014 | Gemma system prompt MUST be enriched with live page-specific data context | HIGH |
| SC-AGUI-UI-015 | CSS MUST use glassmorphism (backdrop-filter:blur), gradient badges, pulse animations | MEDIUM |

---

## 1. LiveView-Equivalent WebSocket Architecture

Mist 6.0's `websocket()` provides LiveView-equivalent reactivity without Lustre server components:

```
Browser ──WebSocket──> wss://host:4100/ws/<page> ──> Mist OTP Actor (WsHandler)
  │                                                        │
  ├── "ping" every 1s ────────> diff-check status ─────────┤
  ├── "<search query>" ───────> NIF plan_search() ─────────┤
  <── "connected" (init) <──── initial status snapshot     │
  <── "update" (changed) <──── status + active + blocked   │
  <── "heartbeat" (same) <──── seq counter only            │
  <── "search" (results) <──── NIF search results          │
```

**Key Design Decisions**:
- **Client-driven ping** (not server-push timer): Client sends "ping" at desired rate (1s), server responds. Avoids Gleam OTP timer complexity in WebSocket context.
- **Diff-detected push**: Server compares current status JSON string with last-sent. Only pushes full data when status changes. ~90% of frames are tiny heartbeats → low bandwidth.
- **Bidirectional**: Same WebSocket carries both status updates AND search queries. No need for separate HTTP requests.
- **Auto-reconnect**: Exponential backoff (1s, 2s, 4s, 8s... max 30s). Falls back to HTTP polling (5s) when WS disconnected.

**Mist WebSocket Handler Pattern** (in `web/server.gleam`):
```gleam
pub type WsState { WsState(push_count: Int, last_status: String) }

fn ws_on_init(conn) -> #(WsState, Option(Selector)) {
  // Send initial status snapshot, return state with no timer selector
}

fn ws_handler(state, msg, conn) -> Next(WsState, WsMsg) {
  case msg {
    Text("ping") -> // diff-check status, send update or heartbeat
    Text(query) -> // search NIF, send results
    Closed | Shutdown -> stop()
  }
}
```

---

## 2. Triple Transport Layer

Every page serves data via three simultaneous transports. All MUST report identical data (verified by DAG scenario Q):

| Transport | Endpoint | Direction | Refresh | Fallback |
|-----------|----------|-----------|---------|----------|
| **WebSocket** | `/ws/<page>` | Bidirectional | 1s (client ping) | Primary |
| **SSE** | `/api/v1/<page>/stream` | Server→Client | On-connect snapshot | WS fallback |
| **HTTP** | `/api/v1/<page>/*` | Request→Response | Polling (5s-30s) | SSE fallback |

**JS Client Priority**: WebSocket → SSE (if WS fails) → HTTP polling (if both fail)

---

## 3. Responsive Breakpoints

| Breakpoint | Width | Cards | Kanban | Rings | Touch | Use Case |
|------------|-------|-------|--------|-------|-------|----------|
| **Mobile** | <768px | 1-col | 1-col | 2x2 (70px) | 44px min | On-call triage |
| **Tablet** | 768-1024px | 2-col | 2-col | 4x1 (90px) | 44px min | Sprint review |
| **Desktop** | 1024-1400px | auto-fill | 4-col | 4x1 (100px) | Standard | Investigation |
| **Wide** | 1400px+ | auto-fill | 4-col | 4x1 (110px) | Standard | Command center |

### Mobile-First CSS Rules
1. Base styles target mobile (<768px): 1-col grids, stacked layout
2. `@media (min-width:768px)` upgrades to tablet
3. `@media (min-width:1024px)` upgrades to desktop
4. `@media (min-width:1400px)` upgrades to wide
5. `min-height:44px` on all interactive elements (WCAG 2.1 AA)
6. `safe-area-inset-bottom` for notched phones
7. `scroll-behavior:smooth`, `overscroll-behavior:none`
8. `-webkit-overflow-scrolling:touch` for momentum scroll
9. `backdrop-filter:blur()` for glassmorphism cards and headers
10. CSS variables: `var(--bg)`, `var(--text)`, `var(--accent)`, `var(--border)`

### Mobile Triage Interface
- Weather bar wraps gracefully → instant situational awareness
- Status cards in 1-col → at-a-glance metrics
- Blocked tasks immediately visible → priority action
- AI search accessible (tap or Ctrl+K) → quick lookup
- Gemma chat → ask questions on the go
- Change log → monitor mutations in real-time

### Desktop Investigation Canvas
- 4 view modes → choose best visualization for the task
- Fractal L0-L7 filters → architectural analysis
- Full data tables → not truncated
- Export CSV/JSON → data extraction for external tools
- Keyboard shortcuts → power user efficiency
- WebSocket always-on → real-time updates

---

## 4. AI Agent Integration

### Dual-Model Gemma Pattern
```
User query → Gemma 3 (fast, 3.3GB, port 11434, ~5s)
             ↓ (15s timeout or error)
             Gemma 4 (deep, 9.6GB, port 11435, ~30s)
             ↓ (15s timeout or error)
             NIF search fallback (context-enriched JSON)
```

**Key Rules**:
- ALWAYS use `/api/chat` with message arrays (NOT `/api/generate`)
- System prompt MUST include live data: `"Status: {total} tasks, {active} active, {blocked} blocked"`
- 15s timeout via AbortController (JS) or reqwest timeout (Rust)
- Gemma 3 is the sweet spot: 3.3GB, ~5s response, good enough for interactive chat
- Gemma 4 (9.6GB) too slow for real-time UI but better for deep analysis

### Chat Widget Pattern
- Floating panel with message history
- Typing indicator with shimmer animation
- Model label shows which Gemma responded
- Graceful fallback message if both models offline

---

## 5. Fractal Layer Classification

Heuristic keyword matching from task/item title → L0-L7 layer:

| Layer | Color | Keywords |
|-------|-------|----------|
| L0 Constitutional | #ff6b6b | guardian, constitutional, psi, safety, emergency, sil4, sil6, prime |
| L1 Atomic/Debug | #ffd93d | nif, debug, trace, telemetry, otel, atomic, ffi |
| L2 Component | #6bcb77 | parser, component, form, badge, input, catalog, a2ui |
| L3 Transaction | #4d96ff | planning, task, state, db, sqlite, smriti, transaction |
| L4 System | #9b59b6 | podman, container, system, boot, build, image, docker |
| L5 Cognitive | #00d4aa | ooda, cortex, mcp, agent, llm, inference, reasoning |
| L6 Ecosystem | #e74c3c | zenoh, mesh, topology, quorum, cluster, ecosystem |
| L7 Federation | #f39c12 | federation, gateway, version, consensus, multi-node |

Default: L3 (Transaction). Filter chips enable fractal-aware analysis across all 4 views.

---

## 6. Color System (Dark Command Center)

| Semantic | Hex | Usage |
|----------|-----|-------|
| Primary/Accent | #00d4aa | Active states, links, highlights |
| Success | #3dd68c | Completed, healthy |
| Warning | #f5a623 | Degraded, stale |
| Critical | #ff4757 | Blocked, errors |
| P0 | #ff4757→#ff6b81 gradient | Critical safety (glow shadow) |
| P1 | #ffa502→#ffbe76 gradient | Core features |
| P2 | #2ed573→#7bed9f gradient | Routine |
| P3 | #7a8fa6 outline | Nice-to-have |
| Background | #0a0e17 | Page bg (navy dark) |
| Card | #141922 | Card panels |
| Text | #e0e6ed | Primary text |
| Muted | #7a8fa6 | Secondary, labels |
| Border | #1e2a3a | Dividers |

**Typography**: System UI for text, JetBrains Mono / monospace for IDs, code, logs.

---

## 7. Component Checklist (per page)

- [ ] Weather bar (system mood emoji + label + health score, live-updating)
- [ ] Progress rings (SVG, responsive 70px→90px→100px→110px)
- [ ] Status cards (live-updating via WS, card-grid responsive 1→2→auto-fill)
- [ ] View toggle (Grid/Kanban/Timeline/Analytics, keyboard 1-4)
- [ ] Fractal L0-L7 filter chips (keyword classification, persists across views)
- [ ] AI search bar (Ctrl+K, 200ms debounce, grid filter + Zettelkasten lookup)
- [ ] Data grids (Tabulator 6.3, sortable, filterable, paginated, export CSV/JSON)
- [ ] Kanban board (4-col desktop, 2-col tablet, 1-col mobile, priority-sorted)
- [ ] Timeline (Gantt-style horizontal bars, color-coded, horizontal scroll mobile)
- [ ] Analytics dashboard (key metrics, priority distribution, fractal distribution, status flow)
- [ ] Click-to-detail panel (5 actions: Knowledge, Related, STAMP, Sub-Tasks, AI Analysis)
- [ ] State change log (mutation feed: status_change, priority_change, new, removed, data_diff)
- [ ] Gemma AI chat widget (Gemma 3 fast + 4 fallback, context-enriched system prompt)
- [ ] Export (CSV/JSON from grid footer)
- [ ] Keyboard shortcuts (1-4 views, Ctrl+K search, R refresh, Esc close)
- [ ] WebSocket client (1s ping, diff-detected push, auto-reconnect, polling fallback)
- [ ] Heartbeat indicator (green=live, amber=stale, red=disconnected)

---

## 8. Mandatory DAG Test Scenarios (per page)

Every page MUST have these 6 cross-component DAG scenarios in the Rust E2E binary:

| DAG | Stages | Path |
|-----|--------|------|
| **M: Triage Journey** | 5 | page→status→blocked list→search first blocked→WS verify |
| **N: Real-Time Monitoring** | 6 | WS connect→status→HTTP compare→ping #1→ping #2→ping #3 (monotonic seq) |
| **O: AI-Assisted Analysis** | 5 | AI status→active tasks→Gemma query→search Gemma keyword→chat endpoint |
| **P: View Consistency** | 7 | all tasks→count by status→match active API→match blocked API→match completed API→search subset |
| **Q: Transport Consistency** | 4 | SSE total→WS total→compare SSE==WS→match HTTP (all three agree) |
| **R: Page↔API Integrity** | 3 | HTML contains live count→JS file referenced→JS file >50KB |

Plus 7 responsive test sections (S-Y): Mobile(12), Tablet(8), Desktop(8), Wide(4), Cross-viewport(12), Mobile Journey(7), Desktop Journey(8).

---

## 9. Architectural Observations (Proven Patterns)

1. **WebSocket via Mist is production-ready**: Mist 6.0 handles upgrade, framing, OTP actor lifecycle. Client-driven 1s ping provides LiveView-equivalent reactivity.
2. **Triple transport works**: HTTP + SSE + WebSocket simultaneously. JS prefers WS, falls back gracefully. All report identical data (DAG Q).
3. **Gemma 3 is the sweet spot**: 3.3GB, ~5s, fast enough for interactive chat. Gemma 4 (9.6GB) for deep analysis only.
4. **Fractal classification is valuable**: Heuristic keyword matching → 80%+ accuracy L0-L7. Enables fractal-aware filtering across all views.
5. **Rust E2E is superior**: 179 tests in one binary, <30s, no Python fragility.
6. **Diff-detected push saves bandwidth**: ~90% heartbeats, 10% data frames.
7. **Client-driven ping simplifies server**: No OTP timer complexity. Client controls rate.

---

## 10. Known Gaps & Roadmap

| Gap | Priority | Description |
|-----|----------|-------------|
| Drag-drop Kanban | P2 | Kanban read-only. Need POST to sa-plan-daemon for status mutations |
| True server-push | P3 | WS uses client ping. Could use Zenoh subscription → actor push |
| Gemma streaming | P3 | All-at-once responses. Could use `stream: true` for token-by-token |
| Task creation UI | P2 | Tasks via CLI only. Need inline creation form with Guardian approval |
| Multi-user WS | P3 | Independent connections. Could broadcast changes to all clients |
| Timeline zoom/pan | P3 | Fixed scale. Interactive zoom needed |
| Browser E2E (Playwright) | P2 | Rust tests verify API/WS, not browser rendering |

---

## Reference Implementation
- **Page**: `/planning` — `https://vm-1.tail55d152.ts.net:4100/planning`
- **Spec**: `docs/architecture/planning-page-specification.md` (674 lines, 15 sections)
- **Journal**: `docs/journal/20260411-planning-page-evolution.md` (325 lines, 13 sections)
- **JS**: `priv/static/planning-grid.js` (1,545 lines)
- **Server WS**: `web/server.gleam` WsHandler (323 lines)
- **Router**: `ui/wisp/router.gleam` SSE + AI + search routes
- **Gleam tests**: `test/planning_page_comprehensive_test.gleam` (1,270 lines, 106 tests)
- **Rust E2E**: `test/planning_e2e_rust.rs` (584+ lines, 179 tests)
- **Skill**: `.claude/commands/agentic-ui-evolve.md`
- **Agent**: `.claude/agents/agentic-ui-designer.md`
