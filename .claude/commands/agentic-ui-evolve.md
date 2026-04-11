# Agentic UI Evolution Skill

Apply the full planning page evolution pattern to any C3I page.

## Usage
`/agentic-ui-evolve <page-path>` — e.g., `/agentic-ui-evolve /dashboard`

## Phases

### Phase 1: Multi-View & Fractal Navigation
1. Add 4-view toggle (Grid/Kanban/Timeline/Analytics) with keyboard shortcuts 1-4
2. Add L0-L7 fractal layer filter chips with keyword classification
3. Add AI search bar (Ctrl+K) with Zettelkasten knowledge lookup
4. Add click-to-detail drill-down with 5 actions: Knowledge, Related, STAMP, Sub-Tasks, AI Analysis
5. Add elegant gradient badges (P0-P3 with glow/pulse)
6. Add state change event log
7. Remove dead code (SC-MUDA-001)

### Phase 2: Real-Time Dynamic Updates
1. Add live header updates (weather bar + status cards) refreshing every 5s
2. Add 1s active data refresh with row-level diff detection and highlight animation
3. Add heartbeat indicator (green/amber/red)

### Phase 3: Responsive Design
1. Mobile-first CSS with 4 breakpoints (mobile <768, tablet 768+, desktop 1024+, wide 1400+)
2. 44px minimum touch targets on all interactive elements
3. Safe area inset, smooth scroll, overscroll prevention
4. Kanban: 1col→2col→4col. Cards: 1col→2col→auto-fill. Rings: 2x2→4x1

### Phase 4: WebSocket
1. Add Mist WebSocket upgrade on /ws/<page-name>
2. Client sends "ping" every 1s, server responds with diff-detected data
3. Bidirectional search queries over same connection
4. Auto-reconnect with exponential backoff (1s→30s), polling fallback

### Phase 5: AI Agent Integration
1. Add Gemma 3 (fast, port 11434) + Gemma 4 (deep, port 11435) chat widget
2. Use /api/chat with message arrays, system prompt with live data context
3. 15s timeout, graceful fallback to NIF search

### Phase 6: Testing
1. Write 100+ Gleam tests (C1-C8 gold standard + prime paths)
2. Write Rust E2E binary (179+ tests across 25 sections: A-Y)
3. Include 6 DAG scenarios + 7 responsive viewport sections
4. Include mobile triage + desktop investigation user journeys

### Phase 7: Documentation
1. 15-section specification (architecture, features, state machines, API, design, journeys, testing, ruliology)
2. 13-section journal entry
3. Email via SMTP (sa-plan-daemon send-email)

## Verification Criteria
- ALL Gleam tests pass (0 failures)
- ALL 179+ Rust E2E tests pass
- 21+ DOM elements dynamically updated
- 10+ API endpoints HTTP 200
- WebSocket upgrade 101
- Gemma AI responds with context
- 4 responsive breakpoints verified
- 44px touch targets verified

## Reference
- Rule: `.claude/rules/agentic-ui-responsive-design.md`
- Spec: `docs/architecture/planning-page-specification.md`
- Journal: `docs/journal/20260411-planning-page-evolution.md`
