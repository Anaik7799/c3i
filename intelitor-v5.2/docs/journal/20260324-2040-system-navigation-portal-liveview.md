# System Navigation Portal — LiveView Implementation

**Date**: 2026-03-24
**Author**: Claude Opus 4.6
**Branch**: multiverse/claude-opus-fractal-tests
**Status**: Complete (4 Waves)

## Summary

Replaced the generic Phoenix boilerplate root page (`/`) with a comprehensive System Navigation Portal implemented as a Phoenix LiveView. The portal serves as the single entry point linking to ALL web UI routes, grouped into 7 categories with SC-HMI-001 Dark Cockpit compliance.

## Design Decision: LiveView over Static PageController

The plan originally specified a static `PageController` for resilience. The user overrode this: **"only use live view"**. The LiveView approach provides:
- Theme integration via `live_session :themed` (ThemeHook auto-applied)
- Future enhancement path (live route health indicators)
- Consistent UX with the rest of the Prajna cockpit

## 4-Wave Implementation

### Wave 1 (P0): Fix 6 Broken Routes — COMPLETE
Fixed LiveView modules returning 500 errors:

| Module | Bug | Fix |
|--------|-----|-----|
| `containers_live.ex` | No clause for `:redis` in `container_extra_metrics/1` | Added `:redis` + catch-all `_` clause |
| `cluster_live.ex` | `init_*` functions crash on missing data | try/rescue with safe defaults |
| `video_live.ex` | `init_*` functions crash on missing data | try/rescue with safe defaults |
| `compliance_live.ex` | `init_*` functions crash on missing data | try/rescue with safe defaults |
| `stamp_tdg_gde_dashboard_live.ex` | 21 missing assigns, duplicate @spec, HTML attr errors | Added all assigns, fixed specs and attrs |
| `monitoring_dashboard_live.ex` | `get_*` functions crash, `def` instead of `defp` | try/rescue, access fixed |

### Wave 2 (P0): Build Navigation Portal — COMPLETE
Created `NavigationPortalLive` (`lib/indrajaal_web/live/navigation_portal_live.ex`):
- `@route_categories` module attribute with 7 categories, ~56 routes
- 2-column responsive grid (`grid-cols-1 md:grid-cols-2`)
- Color-coded left accent border per category
- Header: INDRAJAAL + version (v21.3.0-SIL6) + node name
- Footer: total route count + compliance info
- All semantic color classes (SC-HMI-001): `bg-surface-primary`, `text-content-primary`, etc.

Router change: Replaced static `get "/", PageController, :home` with `live "/", NavigationPortalLive, :index` inside `live_session :themed`.

### Wave 3 (P1): Release Gate Test — COMPLETE (9/9 PASS)
Created `test/indrajaal_web/portal_navigation_test.exs`:
- 9 test cases across 3 describe blocks
- Verifies all 7 categories render
- Verifies route links for cockpit (18 paths), ops, analytics, admin, health, API
- SC-HMI-001 compliance: refutes `text-zinc-*` and `bg-zinc-*`
- Portal metadata: node name and version

Test discovery: `FoundationSupervisor` starts an unconditional Bandit health server on port 4001 that conflicts with dev server during tests. Fix: `HEALTH_PORT=4099` env var.

### Wave 4 (P2): Layout Polish — COMPLETE
- `app.html.heex`: Version `v0.1.0` → `v21.3.0-SIL6`
- `app.html.heex`: Content width `max-w-2xl` → `max-w-7xl`

## Files Changed

| File | Action | Lines |
|------|--------|-------|
| `lib/indrajaal_web/live/navigation_portal_live.ex` | Created | ~300 |
| `lib/indrajaal_web/router.ex` | Modified | Replaced static route with LiveView |
| `lib/indrajaal_web/components/layouts/app.html.heex` | Modified | Version + width |
| `lib/indrajaal_web/live/prajna/containers_live.ex` | Fixed | +2 clauses |
| `lib/indrajaal_web/live/prajna/cluster_live.ex` | Fixed | try/rescue wrappers |
| `lib/indrajaal_web/live/prajna/video_live.ex` | Fixed | try/rescue wrappers |
| `lib/indrajaal_web/live/prajna/compliance_live.ex` | Fixed | try/rescue wrappers |
| `lib/indrajaal_web/live/stamp_tdg_gde_dashboard_live.ex` | Fixed | 21 assigns + specs |
| `lib/indrajaal_web/live/monitoring_dashboard_live.ex` | Fixed | getters + access |
| `test/indrajaal_web/portal_navigation_test.exs` | Created | ~140 |

## STAMP Constraints

- **SC-PORTAL-001**: Root page links to ALL routes in registry
- **SC-PORTAL-002**: All linked routes return HTTP 200
- **SC-HMI-001**: Dark Cockpit compliance (semantic colors only)

## Verification

```
$ mix test test/indrajaal_web/portal_navigation_test.exs
9 tests, 0 failures
```

## Route Categories (7)

1. **C3I Cockpit** (30 routes) — `/cockpit/*`
2. **Operations Center** (4 routes) — `/ops/*`
3. **Analytics & Monitoring** (4 routes) — `/analytics/*`, `/monitoring/*`
4. **Administration** (4 routes) — `/admin/*`
5. **Health Probes** (4 routes) — `/health`, `/ready`, `/startup`, `/api/health`
6. **API Reference** (8 routes) — `/api/v1/*`, `/api/analytics/*`, `/api/kms/*`
7. **Dev Tools** (2 routes) — `/dev/*`
