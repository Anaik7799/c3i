# Plan: Information Gaps Remediation

**Date**: 2026-04-08 | **Priority**: P1 | **STAMP**: SC-FUNC-001, SC-SYNC-DOC-001, SC-MUDA-001

---

## Gap Inventory: 14 Categories, 47 Items

### G1. Stale CLAUDE.md Metrics (P1 — 5 items)

CLAUDE.md shows outdated numbers that don't match runtime reality.

| Field | CLAUDE.md Says | Reality | Fix |
|-------|---------------|---------|-----|
| A2UI components | 115 | **233** | Update §6.0 and §8.2 |
| Total tests | 2,873 | **3,354** | Update §8.2 |
| Test files | 58 | **67** | Update §9.0 |
| Nav graph pages | 30 | **31** | Update §8.2 |
| Gleam modules | 130+ | **225** | Update §9.0 |

**Action**: Single edit pass on CLAUDE.md sections §6.0, §8.2, §9.0.
**Effort**: 15 min. **Risk**: None.

---

### G2. Missing Secrets in Smriti (P1 — 4 items)

| Key | Needed For | How to Obtain |
|-----|-----------|---------------|
| `openrouter_api_key` | LLM advisory (OODA orient/decide) | User provides or generates at openrouter.ai |
| `github_token` | PR creation, issue management, API | User generates at github.com/settings/tokens |
| `google_oauth_refresh` | Sheets/Docs/Slides/Tasks API | Run OAuth flow via `workspace_get_auth_url` |
| `telegram_chat_id` | Telegram gateway dispatch | Send `/start` to @c3i_talk_bot, get chat ID from response |

**Action**: User provides values → `sa-plan-daemon` or direct SQLite insert.
**Effort**: 10 min (user action required). **Risk**: None.

---

### G3. Git Config Not Set (P0 — 2 items)

`git config user.name` = "Your Name" and `user.email` = "your.email@example.com" — defaults, not configured.

**Action**:
```bash
git config user.name "Abhijit Naik"
git config user.email "abhijit.naik@boutytek.com"
```
**Effort**: 30 sec. **Risk**: None. **Impact**: All future commits get correct authorship.

---

### G4. 6 Broken Tests (P1 — from HA work)

| Test | Issue |
|------|-------|
| `cybernetic_initialize_hierarchy_49_agents_test` | `cybernetic.gleam` modified, hierarchy counts changed |
| `cybernetic_get_count_by_level_executive_test` | Same root cause |
| `cybernetic_get_count_by_level_domain_supervisor_test` | Same |
| `cybernetic_get_count_by_level_functional_supervisor_test` | Same |
| `cybernetic_get_count_by_level_worker_test` | Same |
| `boot_sequence_phases_test` | Boot phases count changed (12 vs expected) |

**Root cause**: Uncommitted HA changes modified `agents/cybernetic.gleam` and `agents/leadership.gleam`.
**Action**: Either commit the HA changes and fix tests, or stash them.
**Effort**: 30 min. **Risk**: Low — isolated to agent module.

---

### G5. Zenoh OTel `all_page_topics()` Covers Only 15/31 Pages (P1 — 16 items)

`zenoh_otel.gleam::all_page_topics()` returns topics for only the original 15 pages. The 16 newer pages (Prajna, Agents, Holon, Config, Git, Database, Bridge, Smriti, PlanningDashboard, Integrity, Evolution, Biomorphic, Homeostasis, Bicameral, Singularity, ComponentDemo) use `page_to_string()` fallback.

**Action**: Extend `all_page_topics()` to include all 31 page topics.
**Effort**: 20 min. **Risk**: None — additive change.

---

### G6. CCM/ITQS Below Threshold (P2 — 2 items)

| Metric | Current | Target | Gap |
|--------|---------|--------|-----|
| CCM | 0.770 | 0.90 | -0.13 |
| ITQS | 0.736 | 0.85 | -0.114 |

**Root cause**: C8 (Action Button, weight 3.0) and C7 (AI Advisory, weight 1.5) categories under-tested.
**Action**: Add ~200 tests targeting C8 Guardian consensus and C7 AG-UI event flow per page.
**Effort**: 2-3 sessions. **Risk**: Medium — requires careful test design.

---

### G7. Infrastructure Services Down (P2 — 5 items)

| Service | Port | Status | Impact |
|---------|------|--------|--------|
| Zenoh routers | 7447/7448/7449 | DOWN | No real-time mesh telemetry |
| PostgreSQL | 5433 | DOWN | No Ecto DB operations |
| OTel Collector | 4317 | DOWN | No distributed tracing |
| Grafana | 3000 | DOWN | No dashboard visualization |
| Prometheus | 9090 | DOWN | No metrics scraping |

**Action**: `sa-up` to boot the 16-container SIL-6 mesh, or selectively start needed services.
**Effort**: 5 min for `sa-up`, 60 min for full mesh verification.
**Risk**: May need image rebuilds if stale (>168h).

---

### G8. Missing Allium Specs for New Modules (P2 — 5 items)

| Module | Lines | Needs Spec |
|--------|-------|-----------|
| `c3i/nif.gleam` + `native/c3i_nif/` | 725 Rust + 75 Gleam | Entities: C3iNif, SystemHealth. Rules: NIF dispatch. |
| `moz/planning.gleam` + `moz/system.gleam` | 150 | Contract: MoZTransport. Rules: Zenoh dispatch. |
| `a2ui/catalog.gleam` (233 components) | 500+ | Entity: ComponentCatalog. Invariant: count >= 215. |
| `agui/event_stream_widget.gleam` | 130 | Entity: EventStream. Surface: StreamWidget. |
| `testing/ooda_test_monitor.gleam` | 350 | Contract: TestMonitor. Rules: Preflight, Jidoka. |

**Action**: Create `specs/allium/c3i_nif.allium`, `specs/allium/a2ui_catalog.allium`, etc.
**Effort**: 1 session. **Risk**: None.

---

### G9. 44 Orphaned Test Evolution DBs (P3 — Muda waste)

44 files matching `data/test_evolution_*.db` consuming ~5MB. Created by test evolution runs that never cleaned up.

**Action**: `rm sub-projects/c3i/data/test_evolution_*.db` (after backup per SC-DELETE-001).
**Effort**: 5 min. **Risk**: None — test data, not authoritative.

---

### G10. TUI View Count < Page Count (P3 — 2 items)

29 TUI views vs 31 pages. Missing: `ComponentDemo` TUI view and possibly one other.

**Action**: Create `ui/tui/component_demo_view.gleam`.
**Effort**: 30 min. **Risk**: None.

---

### G11. No Automated Smriti Refresh (P2 — 1 item)

`infra_state` category captures point-in-time TCP probes but has no auto-refresh mechanism. Stale within minutes.

**Action**: Add a `sa-plan-daemon` subcommand `refresh-state` that probes all endpoints and updates Smriti. Hook into session start.
**Effort**: 1 session. **Risk**: Low.

---

### G12. WhatsApp Gateway Not Configured (P3 — 2 items)

`whatsapp_token` and `whatsapp_phone` are empty. WhatsApp Business API requires Meta app approval.

**Action**: User creates WhatsApp Business account, obtains token.
**Effort**: User-dependent. **Risk**: None.

---

### G13. No Unified MCP Tool Catalog Endpoint (P2 — 1 item)

Three MCP providers (Claude 16, sa-plan 40+, Gleam 26) have no single endpoint listing ALL tools.

**Action**: Add `/api/v1/mcp/tools` endpoint in Gleam that aggregates from all 3 providers.
**Effort**: 1 session. **Risk**: Low.

---

### G14. Playwright Not in CI (P2 — 1 item)

421 Playwright tests exist but only run manually. No CI/CD integration.

**Action**: Add Playwright step to CI pipeline (`npx playwright test --project=chromium`).
**Effort**: 30 min. **Risk**: Needs headless browser in CI environment.

---

## Prioritized Execution Plan

### Immediate (P0 — do now, < 5 min)
1. **G3**: Fix git config (30 sec)

### Next Session (P1 — high impact, < 1 hour)
2. **G1**: Update CLAUDE.md stale metrics (15 min)
3. **G2**: Collect missing secrets from user (10 min)
4. **G4**: Fix or stash 6 broken HA tests (30 min)
5. **G5**: Extend `all_page_topics()` to 31 pages (20 min)

### Sprint (P2 — important, multi-session)
6. **G6**: CCM/ITQS improvement (+200 tests)
7. **G7**: Boot infrastructure (`sa-up`)
8. **G8**: Create Allium specs for new modules
9. **G11**: Automated Smriti state refresh
10. **G13**: Unified MCP tool catalog endpoint
11. **G14**: Playwright CI integration

### Backlog (P3 — nice to have)
12. **G9**: Clean orphaned test evolution DBs
13. **G10**: Missing TUI views
14. **G12**: WhatsApp configuration
