# Phase 3 — Wiring + page-spec + value-guard (L0, L2, L3, L4)

## Tests

| Test | Authority | Verifier |
|---|---|---|
| `wiring_guard_test` (33 page inits + 32 events + 6 models + 21 roundtrips + 3 strict invariants = 95 connections) | SC-WIRE-001..007 | `gleam test wiring_guard_test` |
| Page-spec checker for `/planning` (`required_substrings = ["all-grid","blocked-grid","active-grid","planning-grid.bundled.js","task-detail-panel"]`) — alignment must equal `5/5` | SC-PAGE-SPEC-001..008 | `gleam run -m scripts/verify/page_checker` |
| Value-guard scan against `Tasks` table (priority/status/spam) — `violations.total = 0` | SC-VALUE-GUARD-001..008 | `gleam run -m scripts/verify/data_quality_scan` |
| Freshness L0 actor wiring — `/api/v1/health/freshness.staleness == "fresh"` | SC-TRUTH-001..010 · SC-DMS-001 | `curl /api/v1/health/freshness` |
| Hot-reload md5 verification | SC-HA-RELOAD-003 | `curl /api/v1/reload` returns `no_changes` after build |
| AG-UI 32-event round-trip | SC-AGUI-001..010 | `agui_router_test`, `agui_event_test` |
| A2UI catalog allow-listing (233 components) | SC-A2UI-001..008 | `a2ui_validator_test` |

## Exit criteria

- All wiring tests pass: 95+ verified connections.
- Page-spec drift = 0 across 32 pages (live).
- Value-guard scan reports `total=0` violations.
- Freshness fresh; reload `no_changes`.
- D_EA ≤ 0.10.
