# ZK Note: Planning Grid Agentic UI Full Coverage

id: zk-planning-grid-agentic-ui-full-coverage-20260511
task_id: 116554277441926495
urn: urn:c3i:task:misc:116554277441926495
date: 2026-05-11
tags: planning-grid, agentic-ui, ag-ui, a2ui, playwright, webkit, nif, zk-search, c3i, lustre, wisp, effect-iife

## Claim

The planning grid page at `/planning?view=grid` has strong current coverage for default static and dynamic operator behavior, including NIF-backed status counts, AG-UI/A2UI endpoint contracts, WebSocket server ticks, responsive layout, and cross-browser execution including WebKit.

## Evidence

- Live page audit: 48 passed, 0 failed.
- Playwright full functionality: 85 passed, 5 opt-in skipped.
- Browser matrix: Chromium, Firefox, WebKit, Mobile Chromium, Mobile WebKit.
- Gleam tests: 9752 passed.
- NIF status: total 3168, pending 1803, active/in_progress 56, blocked 19, completed 1290.
- Freshness: `nif_plan_status`, `nif_system_health`, `ws_planning_active`, `ws_dashboard_active`, and `all_wiring_functional` reported true in the preceding audit.
- Page spec: planning page alignment score 100 percent.

## Recommended Coverage Expansion

1. Controlled restart with `PLANNING_ENABLE_SERVICE_RESTART=1`.
2. Task create/edit/status mutation flows with NIF/API postconditions.
3. ZK search debounce/cancellation and stale result suppression.
4. Forced WebSocket close/reconnect/backoff tests.
5. Malformed payload and XSS escaping tests.
6. AG-UI/A2UI negative schema tests.
7. Visual regression snapshots across grid, kanban, timeline, analytics, and detail panel.
8. Performance budgets for hydration, filtering, view switching, and search.
9. Multi-tab synchronization or isolation semantics.
10. Invalid deep-link normalization for `view`, `status`, and `layer`.

## Why It Matters

The current suite proves that the planning grid works in normal operator flows. The recommended tests prove that the page remains correct under service churn, write operations, stale search races, invalid generated UI payloads, corrupted backend data, multi-tab workflows, and large-data performance pressure.

## Retrieval Summary

Use this note when planning further work on C3I planning page E2E coverage, Agentic UI contract validation, WebKit execution, NIF-backed UI truth checks, or ZK search reliability.
