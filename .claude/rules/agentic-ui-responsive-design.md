# Agentic UI Responsive Design Protocol (SC-AGUI-UI)

## Mandate
Every C3I web page MUST implement the full agentic responsive design pattern established by the Planning page evolution (v22.7.0-PLANNING). This protocol applies to all 31 pages.

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-AGUI-UI-001 | Every page MUST have 4 view modes (Grid/Kanban/Timeline/Analytics) | HIGH |
| SC-AGUI-UI-002 | Every page MUST have L0-L7 fractal filter chips | HIGH |
| SC-AGUI-UI-003 | Every page MUST have AI search (Ctrl+K) with Zettelkasten lookup | HIGH |
| SC-AGUI-UI-004 | Every page MUST have click-to-detail drill-down (5 actions) | HIGH |
| SC-AGUI-UI-005 | Every page MUST have Gemma AI chat widget | MEDIUM |
| SC-AGUI-UI-006 | Every page MUST have WebSocket real-time push | HIGH |
| SC-AGUI-UI-007 | Every page MUST have state change event log | MEDIUM |
| SC-AGUI-UI-008 | Every page MUST have responsive 4-breakpoint CSS | CRITICAL |
| SC-AGUI-UI-009 | All interactive elements MUST have 44px min touch targets | CRITICAL |
| SC-AGUI-UI-010 | Every page MUST pass the Rust E2E test suite | CRITICAL |

## Responsive Breakpoints (Mandatory)
| Breakpoint | Width | Layout | Use Case |
|------------|-------|--------|----------|
| Mobile | <768px | 1-col stacked, 44px touch | On-call triage |
| Tablet | 768-1024px | 2-col cards/kanban, 4x1 rings | Sprint review |
| Desktop | 1024-1400px | auto-fill, 4-col kanban | Investigation canvas |
| Wide | 1400px+ | Expanded rings, larger fonts | Command center |

## Mobile-First CSS Rules
1. Base styles target mobile (<768px): 1-col grids, stacked layout
2. `@media (min-width:768px)` upgrades to tablet
3. `@media (min-width:1024px)` upgrades to desktop
4. `@media (min-width:1400px)` upgrades to wide
5. All interactive elements: `min-height:44px` (WCAG 2.1 AA)
6. `safe-area-inset-bottom` for notched phones
7. `scroll-behavior:smooth`, `overscroll-behavior:none`
8. `-webkit-overflow-scrolling:touch` for momentum scroll
9. `backdrop-filter:blur()` for glassmorphism
10. CSS variables for theming: `var(--bg)`, `var(--text)`, `var(--accent)`

## Component Checklist (per page)
- [ ] Weather bar (system mood, health score)
- [ ] Progress rings (SVG, responsive sizing)
- [ ] Status cards (live-updating, card-grid responsive)
- [ ] View toggle (Grid/Kanban/Timeline/Analytics)
- [ ] Fractal L0-L7 filter chips
- [ ] AI search bar (Ctrl+K, debounce 200ms)
- [ ] Data grids (Tabulator, sortable, filterable)
- [ ] Kanban board (priority-sorted, fractal indicators)
- [ ] Timeline (Gantt-style, horizontal scroll on mobile)
- [ ] Analytics dashboard (key metrics, distributions)
- [ ] Click-to-detail panel (5 actions)
- [ ] State change log (mutation feed)
- [ ] Gemma AI chat widget
- [ ] Export (CSV/JSON)
- [ ] Keyboard shortcuts (1-4, Ctrl+K, R, Esc)

## Transport Layer
- WebSocket on `/ws/<page-name>` — bidirectional, 1s ping, diff-detected push
- SSE fallback on `/api/v1/<page>/stream` — unidirectional
- HTTP polling fallback — 5s when WS disconnected

## AI Agent Integration
- Gemma 3 (port 11434, 3.3GB) — fast, default for interactive chat
- Gemma 4 (port 11435, 9.6GB) — deep analysis, fallback
- `/api/chat` endpoint with message arrays (NOT `/api/generate`)
- System prompt enriched with live page-specific data
- 15s timeout with AbortController

## Color System (Dark Command Center)
| Semantic | Color | Hex | Usage |
|----------|-------|-----|-------|
| Primary/Accent | Teal | #00d4aa | Active, links, highlights |
| Success | Green | #3dd68c | Completed, healthy |
| Warning | Amber | #f5a623 | Degraded, stale |
| Critical | Red | #ff4757 | Blocked, errors |
| P0 | Red gradient | #ff4757→#ff6b81 | Critical safety |
| P1 | Amber gradient | #ffa502→#ffbe76 | Core features |
| P2 | Green gradient | #2ed573→#7bed9f | Routine |
| P3 | Muted | #7a8fa6 | Nice-to-have |
| Background | Navy | #0a0e17 | Page bg |
| Card | Dark panel | #141922 | Cards |
| Text | Light | #e0e6ed | Primary |
| Muted | Blue-gray | #7a8fa6 | Secondary |

## Testing (Mandatory per page)
- 106+ Gleam tests (C1-C8 gold standard + prime paths)
- 179+ Rust E2E tests (12 dimensions + 6 DAG scenarios + 7 responsive sections)
- Mobile journey test (triage: weather→status→blocked→search→chat)
- Desktop journey test (investigation: views→fractal→tables→export→WS)

## Reference Implementation
- Page: `/planning` (https://vm-1.tail55d152.ts.net:4100/planning)
- Spec: `docs/architecture/planning-page-specification.md`
- Journal: `docs/journal/20260411-planning-page-evolution.md`
- JS: `priv/static/planning-grid.js` (1,545 lines)
- E2E: `test/planning_e2e_rust.rs` (584+ lines)
