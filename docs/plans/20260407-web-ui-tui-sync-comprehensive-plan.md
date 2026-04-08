# Comprehensive Web UI + TUI Sync Plan

**Date**: 2026-04-07 | **STAMP**: SC-GLM-UI-001, SC-ULTRA-001 #4 (Homomorphic Tripartite UI)
**Status**: PLAN | **Priority**: P1

---

## 1. Current State (Audit Results)

| Metric | Value | Target | Gap |
|--------|-------|--------|-----|
| Pages in domain.gleam | 30 | 30 | -- |
| Fully implemented (Lustre+TUI+Wisp) | 24/30 | 30 | 6 missing |
| Wisp API endpoints | 40+ | 30+ | EXCEEDS |
| Lustre web pages | 25/30 | 30 | 5 missing |
| TUI terminal views | 25/30 | 30 | 5 missing |
| Triple-interface compliance | 80% | 100% | **NONCOMPLIANT** |

### 6 Pages Missing Full Triple-Interface

| Page | Lustre | TUI | Wisp API | Fractal Layer |
|------|--------|-----|----------|---------------|
| Integrity | MISSING | MISSING | STUB | L0 Constitutional |
| Evolution | MISSING | MISSING | STUB | L5 Cognitive |
| Biomorphic | WIDGET ONLY | MISSING | STUB | L5 Cognitive |
| Homeostasis | WIDGET ONLY | MISSING | STUB | L2 Component |
| Bicameral | MISSING | MISSING | STUB | L0 Constitutional |
| Singularity | MISSING | MISSING | STUB | L7 Federation |

---

## 2. Plan Overview — 4 Waves

### Wave 1: Close Triple-Interface Gaps (6 pages x 3 interfaces = 18 files)
### Wave 2: Web UI Quality Improvements (real data, interactivity, AG-UI)
### Wave 3: TUI Feature Parity Uplift (sparklines, split-screen, dark cockpit)
### Wave 4: Zenoh Live Data + MCP Integration (NIF-backed real data everywhere)

---

## 3. Wave 1 — Close Triple-Interface Gaps (P0, SC-GLM-UI-001)

**Goal**: Every Page variant in domain.gleam has Lustre + TUI + Wisp endpoint with real data.

### 3.1 Integrity Page (L0 Constitutional)
- **Lustre**: `ui/lustre/integrity.gleam` — Hash chain viewer, constitution hash, Psi invariant status panel
- **TUI**: `ui/tui/integrity_view.gleam` — ANSI table: Psi-0..5 pass/fail, constitution hash, last verification timestamp
- **Wisp**: Upgrade `/api/v1/integrity` from stub to real data (read from verification modules)

### 3.2 Evolution Page (L5 Cognitive)
- **Lustre**: `ui/lustre/evolution.gleam` — Shannon entropy timeline, morphogenic cycle history, OODA decisions
- **TUI**: `ui/tui/evolution_view.gleam` — Sparkline of entropy over time, cycle count, mutation rate
- **Wisp**: Upgrade `/api/v1/evolution` with entropy metrics from coverage_math module

### 3.3 Biomorphic Page (L5 Cognitive)
- **Lustre**: `ui/lustre/biomorphic.gleam` — Full page wrapping existing biomorphic_matrix widget + immune/neuro/metabolic subsystem status
- **TUI**: `ui/tui/biomorphic_view.gleam` — 3-column subsystem health: Bio | Neuro | Immune
- **Wisp**: Upgrade `/api/v1/biomorphic` with subsystem health data

### 3.4 Homeostasis Page (L2 Component)
- **Lustre**: `ui/lustre/homeostasis.gleam` — PID controller visualization, setpoint/actual/error, control output
- **TUI**: `ui/tui/homeostasis_view.gleam` — PID parameters table + error sparkline
- **Wisp**: Upgrade `/api/v1/homeostasis` with PID state from metabolic module

### 3.5 Bicameral Page (L0 Constitutional)
- **Lustre**: `ui/lustre/bicameral.gleam` — 2oo3 voting panel, chamber status, veto history, consensus timeline
- **TUI**: `ui/tui/bicameral_view.gleam` — Chamber table: Guardian | Sentinel | Cortex with vote status
- **Wisp**: Upgrade `/api/v1/bicameral` with consensus data

### 3.6 Singularity Page (L7 Federation)
- **Lustre**: `ui/lustre/singularity.gleam` — Convergence estimator, capability timeline, safety boundary
- **TUI**: `ui/tui/singularity_view.gleam` — Capability score table, convergence %, safety margin
- **Wisp**: Upgrade `/api/v1/singularity` with estimation data

**Files created**: 12 new (6 Lustre + 6 TUI)
**Files modified**: 6 Wisp endpoints (stub -> real data)
**Estimated effort**: ~600 lines new code

---

## 4. Wave 2 — Web UI Quality Improvements (P1)

### 4.1 Real Data Integration
- Replace ALL hardcoded/mock data in Lustre pages with NIF-backed or Wisp API calls
- Priority: Planning (use planning_nif), Podman (use podman FFI), Zenoh (use zenoh_nif)
- Pattern: `init()` calls Wisp endpoint -> parses JSON -> populates Model

### 4.2 Interactive Features (SC-GLM-UI-002)
- **Navigation**: Keyboard shortcuts in web shell (j/k navigation, tab cycling)
- **Filtering**: Client-side task filtering on Planning page (by priority, status)
- **Sorting**: Column sort on data grids (clickable headers)
- **Search**: Global search bar using plan_search NIF tool
- **Dark Cockpit**: Implement 5-mode state machine in web (Dark/Dim/Normal/Bright/Emergency)

### 4.3 AG-UI Event Integration (SC-AGUI)
- Wire Lustre pages to AG-UI SSE stream (`/ag-ui/events`)
- Real-time updates: tool calls, reasoning, state deltas pushed to browser
- HITL modal for L0 Constitutional actions (Guardian approval)

### 4.4 HTML Rendering Quality
- `page_views.gleam`: Ensure all 30 pages render complete HTML with proper nav, header, content
- Responsive layout: CSS grid for dashboard panels
- Accessibility: ARIA labels, keyboard navigation, color contrast (WCAG 2.1 AA)

### 4.5 A2UI Component Integration
- Wire A2UI `renderer.gleam` into Lustre pages for agent-proposed UI components
- Validate all agent proposals through `validator.gleam` allowlist
- Enable: badge, button, data_table, progress, sparkline, alert, ooda_ring

---

## 5. Wave 3 — TUI Feature Parity Uplift (P1)

### 5.1 Missing TUI Features (vs Web)
- **Sparklines**: Real CPU/memory sparklines in metabolic, telemetry views (use `cockpit/visuals.gleam`)
- **Progress bars**: Build progress, verification progress in substrate, verification views
- **Color profiles**: Apply 4 color profiles (Dark Cockpit, Color Rich, WCAG, Monochrome) to TUI
- **Split-screen**: Already exists — verify all 30 pages work in split-screen mode

### 5.2 TUI Navigation
- Tab cycling (1-9 + 0 for pages 10+, or arrow keys)
- Status bar with page name + key hints
- Global search (/ to search tasks, Ctrl+F for page content)

### 5.3 TUI Dark Cockpit (SC-HMI-010)
- Implement `determine_mode()` in TUI renderer
- Healthy = minimal gray, Degraded = yellow accents, Critical = red dominant
- Auto-transition based on system health from Zenoh telemetry

### 5.4 TUI + Ratatui Convergence
- The Rust Ratatui TUI (`tui.rs`) is a 24-line stub — decision: **abandon Rust TUI, keep Gleam TUI only**
- Per SC-ARCH-SPLIT-002: UI = Gleam only. Rust TUI was experimental, Gleam TUI is authoritative
- Remove dead code from `tui.rs` or repurpose as NIF-backed widget data provider

---

## 6. Wave 4 — Zenoh Live Data + MCP Integration (P2)

### 6.1 Zenoh-Backed Real-Time Data
- All 30 pages subscribe to Zenoh topics for live updates
- Pattern: `zenoh_otel.gleam` publishes spans -> pages consume via `effects.gleam` subscriptions
- Topics per page: `indrajaal/ui/{page}/state` for state updates

### 6.2 MCP Tool Coverage
- Current: 10 MCP tools (7 plan + 3 utility)
- Target: 30+ MCP tools (1 per page minimum)
- Add NIF-backed tools for: `immune_status`, `zenoh_health`, `podman_containers`, `verification_run`, `kms_catalog`

### 6.3 Wisp API -> NIF Migration
- Migrate static Wisp JSON stubs to NIF-backed real queries
- Priority: podman (container status), zenoh (mesh health), immune (threat count)
- Each NIF reads from authoritative SQLite/DuckDB (SC-HOLON-009)

### 6.4 OTel Span Publishing (SC-GLM-ZEN-001)
- Verify all 30 pages publish OTel spans on state changes
- Audit `zenoh_otel.gleam` span coverage
- Add missing span publishers for Wave 1 pages (Integrity, Evolution, etc.)

---

## 7. File Impact Summary

| Wave | New Files | Modified Files | Lines (est) |
|------|-----------|----------------|-------------|
| Wave 1 | 12 | 6 + shell + router | ~600 |
| Wave 2 | 0 | 30 Lustre pages + page_views | ~1200 |
| Wave 3 | 0 | 25 TUI views + renderer | ~800 |
| Wave 4 | 5 NIF functions | 10 Wisp endpoints | ~500 |
| **Total** | **17** | **~71** | **~3100** |

---

## 8. Priority Matrix

| Task | Priority | SC-ULTRA-001 | Effort |
|------|----------|-------------|--------|
| Wave 1: 6 missing pages | P0 | #4 Homomorphic Tripartite UI | 2 sessions |
| Wave 2.1: Real data in Lustre | P1 | #4 | 2 sessions |
| Wave 2.2: Interactive features | P1 | #4 | 1 session |
| Wave 2.3: AG-UI integration | P1 | #4 | 1 session |
| Wave 3.1: TUI sparklines + progress | P1 | #4 | 1 session |
| Wave 3.2: TUI navigation | P2 | #4 | 1 session |
| Wave 3.3: Dark cockpit TUI | P2 | #4 | 1 session |
| Wave 4: Zenoh + MCP expansion | P2 | #3 + #7 | 2 sessions |

---

## 9. Verification Criteria

- `gleam build` — 0 warnings (SC-MUDA-001)
- `gleam test` — 2,787+ pass, 0 failures
- Every Page variant has: 1 Lustre module + 1 TUI view + 1 Wisp endpoint (SC-GLM-UI-001)
- Every Wisp endpoint returns typed JSON (SC-GLM-UI-003)
- OTel spans published for all 30 pages (SC-GLM-ZEN-001)
- Shannon entropy H >= 2.5 bits across test categories (SC-MATH-COV-001)
