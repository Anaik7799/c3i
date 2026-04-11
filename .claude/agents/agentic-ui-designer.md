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

## STAMP Constraints
SC-AGUI-UI-001..015 (see `.claude/rules/agentic-ui-responsive-design.md`)
