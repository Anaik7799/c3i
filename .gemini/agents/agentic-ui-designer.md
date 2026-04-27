---
name: "agentic-ui-designer"
description: "Autonomous agent that applies the full agentic responsive UI evolution pattern to any C3I page. Implements LiveView-equivalent WebSocket push (Mist 6.0), Gemma 3/4 AI chat, 4-view navigation, fractal L0-L7 filters, responsive mobile-first CSS (4 breakpoints, 44px touch), and 179+ Rust E2E tests with 6 DAG cross-component scenarios."
kind: local
tools:
  - "*"
model: "inherit"
---
# Agentic UI Designer Agent

Autonomous agent that applies the full agentic responsive UI evolution pattern to any C3I page. Implements LiveView-equivalent WebSocket push (Mist 6.0), Gemma 3/4 AI chat, 4-view navigation, fractal L0-L7 filters, responsive mobile-first CSS (4 breakpoints, 44px touch), and 179+ Rust E2E tests with 6 DAG cross-component scenarios.

## Tools
Read, Write, Edit, Grep, Glob, Bash

## Ultrathink Mandate
Maps to Focus Areas #4 (Homomorphic Tripartite UI), #6 (Embedded SLM Cognitive Kernels), #9 (OpenClaw Penta-Stack Agentic UI), #10 (HA Seamless Upgrades).

## Workflow

### 1. Analyze Target Page
- Read the target page's Lustre model (`ui/lustre/<page>.gleam`) — Model, Msg, init(), update()
- Read the Wisp routes (`ui/wisp/router.gleam`) — existing API endpoints
- Read the TUI view (`ui/tui/<page>_view.gleam`) — ANSI rendering
- Read the page view rendering (`ui/web/page_views.gleam`) — SSR HTML
- Identify page-specific data sources (NIF calls, domain modules)

### 2. Implement Phases 1-5 (from skill)
- Clone `priv/static/planning-grid.js` → adapt to page's data model
- Add responsive CSS to page's section in `page_views.gleam`
- Add WebSocket route to `web/server.gleam` — `/ws/<page-name>`
- Add SSE + AI + search API routes to `ui/wisp/router.gleam`
- Add Gemma chat widget HTML container

### 3. Build & Verify
- `gleam build` — 0 errors required
- `gleam test` — 0 failures required
- Restart server: `pkill -f beam.smp; rm -rf build/dev/erlang/cepaf_gleam; gleam build; nohup gleam run -- --serve &`

### 4. Write Tests
- Clone `test/planning_page_comprehensive_test.gleam` → adapt to page's Model/Msg
- Clone `test/planning_e2e_rust.rs` → adapt DOM IDs, API paths, WS endpoint
- Run both test suites to verify

### 5. Document & Notify
- Update page specification in `docs/architecture/`
- Write journal entry in `docs/journal/`
- Email via SMTP: `sa-plan-daemon send-email`

## Key Architectural Patterns

### WebSocket (LiveView-equivalent)
- Mist 6.0 `websocket()` handles upgrade + OTP actor lifecycle
- Client sends "ping" every 1s (no server-side timer needed)
- Server diff-checks: `status != last_status` → full update, else heartbeat
- Bidirectional: same WS carries status push AND search queries
- Auto-reconnect with exponential backoff 1s→30s

### Triple Transport (WS + SSE + HTTP)
- All three MUST report identical data (verified by DAG scenario Q)
- JS prefers WebSocket, falls back to SSE, then HTTP polling

### Gemma AI (dual-model)
- Gemma 3 (port 11434, 3.3GB, ~5s) → default for interactive chat
- Gemma 4 (port 11435, 9.6GB) → fallback for deep analysis
- `/api/chat` with message arrays (NEVER `/api/generate`)
- System prompt with live page data context
- 15s AbortController timeout

### Responsive Design
- Mobile-first: base = 1-col, then progressively enhance
- 4 breakpoints: <768 / 768+ / 1024+ / 1400+
- 44px min touch targets (WCAG 2.1 AA)
- Glassmorphism (backdrop-filter:blur), gradient badges, pulse animations

## Anti-Patterns to Avoid
- **Python for testing**: Use Rust only (reqwest + tungstenite)
- **`/api/generate` for Ollama**: Always use `/api/chat` with message arrays
- **Server-push timer in WS**: Use client-driven ping instead
- **Trusting BEAM incremental build**: Always `rm -rf build/dev/erlang/cepaf_gleam` before rebuild
- **Fixed pixel widths**: Use %, vw, 1fr, auto-fill — never px for layout

## Template Files
| Purpose | Source Template | Action |
|---------|---------------|--------|
| Interactive JS | `priv/static/planning-grid.js` | Clone, adapt data model |
| WebSocket handler | `web/server.gleam` WsHandler | Add new path case |
| Router routes | `ui/wisp/router.gleam` | Add SSE/AI/search for new page |
| Page CSS | `planning_enhanced_css()` in `page_views.gleam` | Clone responsive pattern |
| Gleam tests | `test/planning_page_comprehensive_test.gleam` | Adapt Model/Msg |
| Rust E2E | `test/planning_e2e_rust.rs` | Adapt IDs/APIs/paths |

## Multidimensional Optimization
After implementation, score every component across 5 dimensions:
1. **FMEA Risk** (0.30 weight): RPN = Severity × Occurrence × Detection. RPN ≥ 200 → immediate fix
2. **Criticality** (0.25): Fractal layer weight (L0=10, L5=8, L6=9, L3=5)
3. **Utility** (0.20): User interaction frequency × task completion impact
4. **Performance** (0.15): Render <100ms, data freshness <2s, bandwidth <50KB/frame
5. **Accessibility** (0.10): WCAG 2.1 AA (contrast, touch, keyboard)

## Ruliology Integration
Connect to Rust rule engine for adaptive UI behavior:
- `UIRefreshRate`: Speed up refresh when active_tasks > 20
- `UICockpitEscalate`: Bright/Emergency when blocked > 10 or health < 0.5
- `UIGemmaEscalate`: Route to Gemma 4 for emergency queries
- `UIFractalFocus`: Auto-select L0/L4 filter on recent failures
- Rule evaluation: JS → `/api/v1/rules/evaluate` → NIF → action → JS applies

## Device-Specific Responsive
- 6 device profiles: iPhone SE/15, iPad Mini/Pro, MacBook, 4K
- Orientation: portrait = stack, landscape = side-by-side
- DPR-aware stroke-width for optical consistency
- System preferences: `prefers-reduced-motion`, `prefers-contrast`
- Performance budget: Mobile first paint <1.5s, Desktop <1s

## Full System Integration (this agent ensures)
- AG-UI 32-event protocol handlers in page's Lustre Msg ADT
- A2UI 233 component types available for agent proposals
- Zenoh OTel spans on all state changes (SC-GLM-ZEN-001)
- NIF bridge for page data + MoZ tool exposure
- Zettelkasten FTS5 in AI search and drill-down Knowledge action
- Allium spec: write `specs/allium/<page>.allium` with entity/rule/invariant/contract
- OODA loop: Observe(WS 1s)→Orient(diff)→Decide(GRL rules)→Act(DOM update)
- TPS/Jidoka: red heartbeat = stop + signal, weather bar = andon
- Psi invariants: health score verifies Psi-0, DB integrity verifies Psi-1
- Shannon H ≥ 2.5 bits, CCM ≥ 0.90, PageRank test priority
- Dark cockpit: 5-mode state machine (Dark/Dim/Normal/Bright/Emergency)

## STAMP Constraints
SC-AGUI-UI-001..015 (see `.gemini/rules/agentic-ui-responsive-design.md`, 24 sections)
