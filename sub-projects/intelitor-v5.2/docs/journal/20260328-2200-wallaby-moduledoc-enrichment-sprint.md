# Wallaby @moduledoc Source-First Enrichment Sprint — SC-COV-021/022

**Date**: 20260328-2200 CEST
**Author**: Claude Opus 4.6
**Commit**: TBD (pending agent completion + compilation verification)
**Version**: v21.3.1-SIL6
**Branch**: main
**STAMP**: SC-COV-021, SC-COV-022, AOR-COV-016, AOR-COV-017
**Compliance**: SC-SYNC-DOC-002 (journal mandatory for every plan)

---

## 1. Scope & Trigger

**Trigger**: Executive directive to add detailed page specifications (design intent, expected behavior, BDD scenarios, UX flow, UI inventory, STAMP, FMEA) to every Wallaby test file's `@moduledoc`, making each test file a self-documenting reference for its page.

**Scope IN**:
- 49 Wallaby test files — enrich @moduledoc with 9-section page spec
- 3 standalone page spec documents in `docs/specs/pages/`
- EXPECTED vs AS-IS behavior audit across all 49 pages
- Gold Standard Template update in `.claude/rules/fractal-coverage-gold-standard.md`
- New STAMP constraints SC-COV-021, SC-COV-022
- New AOR rules AOR-COV-016, AOR-COV-017

**Scope OUT**:
- Test code changes (only @moduledoc modifications)
- Runtime E2E execution
- New test features (covered by parent sprint)

## 2. Pre-State Assessment

| Metric | Value |
|--------|-------|
| Wallaby files | 49 |
| Features | 1,823 |
| Avg entropy H | 2.73 bits |
| Files with enriched @moduledoc | 0 (only alarm_investigation had basic @moduledoc) |
| SC-COV constraints | SC-COV-008 to SC-COV-020 (13 total) |
| AOR-COV rules | AOR-COV-008 to AOR-COV-015 (8 total) |
| Page spec documents | 0 |
| EXPECTED vs AS-IS audit | None |

## 3. Execution Detail — Phase/Wave Breakdown

### Phase 1: Gold Standard Enrichment (Manual)
1. Read `alarm_investigation_live.ex` source — extracted 7 handle_events, mount assigns, flash messages
2. Enriched `alarm_investigation_live_wallaby_test.exs` @moduledoc from ~18 lines to ~90 lines
3. Added 9 sections: Page Identity, Design Intent, Expected Behavior, BDD Scenarios, UX Flow, UI Elements Inventory, STAMP, FMEA

### Phase 2: Rules & Constraints Update (Manual)
1. Added SC-COV-021 (moduledoc page spec mandatory) to CLAUDE.md
2. Added SC-COV-022 (source-first derivation) to CLAUDE.md
3. Added AOR-COV-016 (9-section @moduledoc format) to rules
4. Added AOR-COV-017 (extract from .ex source) to rules
5. Updated Gold Standard Template in `fractal-coverage-gold-standard.md` with full 9-section @moduledoc pattern

### Phase 3: P0 Safety Pages (Agent Batch 1 — context session 1)
- 8 files enriched before context exhaustion
- Files: alarm_investigation, dispatch_console, commands, containers, devices, diagnostics, shutdown, test_cockpit, prajna_live

### Phase 4: Remaining 40 Files (Agent Batches 1-4 — context session 2)
- Batch 1 (10 files): prajna core — access_control, alarms, analytics, cluster, compliance, copilot, git_intelligence, guardian_dashboard, guardian, health_sparkline
- Batch 2 (10 files): prajna extended — knowledge/*, mesh, observability, prometheus, register, sentinel_dashboard, settings
- Batch 3 (10 files): prajna remaining + operations — startup, threat, topology, video, access_dashboard, active_alarms, video_wall, zenoh_mesh_health, navigation_portal, monitoring_dashboard
- Batch 4 (10 files): admin/system — access_control_monitoring, admin/config, admin/system_status, config_management, crm/dashboard, performance_dashboard, permissions_management, stamp_tdg_gde_*, system_status

### Phase 5: Documentation (Agent — parallel)
- 3 page spec documents in `docs/specs/pages/`
- EXPECTED vs AS-IS behavior audit

### Phase 6: Verification (Pending)
- Compilation check after all agents complete
- Entropy re-verification (ensure no regressions)

## 4. Root Cause Analysis

| Root Cause Class | Count | Example |
|-----------------|-------|---------|
| Missing page context | 49 | @moduledoc had no design intent, expected behavior, or BDD |
| Source-test disconnect | 40+ | Test selectors written without reading LiveView source first |
| No spec standard | 1 | No template existed for @moduledoc page specs |

## 5. Fix Taxonomy

```elixir
# Pattern: Source-First @moduledoc Enrichment
# Applies when: Creating or updating Wallaby test files
# Steps:
# 1. Read LiveView .ex source
# 2. Extract mount assigns, handle_events, PubSub, timers
# 3. Write 9-section @moduledoc
# 4. Verify compilation

@moduledoc """
  ## Page Identity
  - **Route**: extracted from router.ex
  - **Module**: from defmodule in .ex source
  - **Title**: from page_title assign in mount/3

  ## Design Intent
  [From module @moduledoc in .ex source]

  ## Expected Behavior (Functional)
  - **On mount**: [from mount/3 assigns]
  - **handle_event "X"**: [from handle_event clauses]
  - **handle_info(:refresh)**: [from handle_info clauses]
  - **PubSub**: [from Phoenix.PubSub.subscribe calls]

  ## BDD Scenarios
  [Gherkin derived from handle_event + expected flash messages]

  ## UX Flow
  [Numbered steps from mount → interaction → outcome]

  ## UI Elements Inventory
  [Table from render/1 HEEx template elements]

  ## STAMP Constraints
  [SC-* from @moduledoc or comments in .ex source]

  ## FMEA Risks
  [Failure modes from FMEA analysis]
"""
```

## 6. Patterns & Anti-Patterns Discovered

### Patterns (DO this)
- **Source-First Enrichment**: Always read the LiveView .ex before writing/updating test @moduledoc — prevents hallucinated selectors and incorrect expected behavior
- **9-Section @moduledoc**: Consistent structure makes every test file a reference document — operators can understand page behavior without reading the .ex source
- **Parallel Agent Batching**: Split 40+ file modifications into 4x10 batches for parallel execution — respects agent context limits while maximizing throughput

### Anti-Patterns (AVOID this)
- **Test-First Spec**: Writing @moduledoc from test assertions alone misses untested handle_events and PubSub flows — always derive from source
- **Monolithic Agent Jobs**: Giving one agent 40+ files causes context exhaustion — batch into 10-file chunks

## 7. Verification Matrix

| Check | Status |
|-------|--------|
| Compilation (pre-enrichment) | PASS (0 errors, 2 warnings) |
| Gold Standard Template updated | PASS |
| SC-COV-021/022 in CLAUDE.md | PASS |
| AOR-COV-016/017 in rules | PASS |
| Compilation (post-enrichment) | PENDING (agents running) |
| Entropy verification | PENDING |
| All 49 files enriched | PENDING (9/49 done) |

## 8. Files Modified

| File | Change Type | Notes |
|------|------------|-------|
| `.claude/rules/fractal-coverage-gold-standard.md` | modified | 9-section @moduledoc template |
| `CLAUDE.md` | modified | SC-COV-021, SC-COV-022 added |
| `docs/analysis/20260328-wallaby-sprint-progress-state.md` | modified | Deliverables 18-21, remaining work updated |
| `docs/journal/20260328-2200-wallaby-moduledoc-enrichment-sprint.md` | new | This journal entry |
| 49× `test/**/*wallaby*.exs` | modified | @moduledoc enriched (9/49 done, 40 in progress) |
| `docs/specs/pages/*.md` | new | 3 page spec documents (in progress) |
| `docs/analysis/20260328-wallaby-expected-vs-asis-audit.md` | new | Expected vs AS-IS audit (in progress) |

## 9. Architectural Observations

The @moduledoc enrichment creates a **self-documenting test layer** — each Wallaby test file becomes a standalone reference for its page's design, behavior, and coverage. This aligns with the fractal principle: the test file mirrors the structure of the page it tests.

```
LiveView .ex source ──(source-first)──> Wallaby @moduledoc spec
       │                                        │
       │ implements                              │ documents
       ▼                                        ▼
  Page behavior <────(verified by)───── Wallaby test features
```

The 9-section format acts as a "genotype" that propagates consistently across all 49 test files, ensuring every page has discoverable documentation at the point of test execution.

## 10. Remaining Gaps

| Gap | Priority | Notes |
|-----|----------|-------|
| 40 files awaiting agent enrichment | P1 | 4 agents running in parallel |
| 3 page spec docs | P2 | Agent running |
| EXPECTED vs AS-IS audit | P2 | Agent running |
| Post-enrichment compilation | P1 | Blocked on agent completion |
| Runtime E2E execution | P3 | Requires devenv + Chrome + PostgreSQL |

## 11. Metrics Summary

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| SC-COV constraints | 13 (008-020) | 15 (008-022) | +2 |
| AOR-COV rules | 8 (008-015) | 10 (008-017) | +2 |
| Enriched @moduledoc files | 0 | 9 (49 target) | +9 |
| Page spec documents | 0 | 0 (3 in progress) | — |
| Gold Standard Template sections | 2 | 9 | +7 |

## 12. STAMP & Constitutional Alignment

- **SC-COV-021**: New — Wallaby @moduledoc MUST contain page spec (9 sections)
- **SC-COV-022**: New — Page spec MUST be derived from actual .ex source
- **AOR-COV-016**: New — @moduledoc format specification
- **AOR-COV-017**: New — Source-first extraction mandate
- **AOR-COV-008**: Enforced — Source read before selector writing
- **SC-SYNC-DOC-002**: This journal entry satisfies the plan→journal mandate
- **Ψ₃ (Verification Capability)**: All changes verifiable via compilation + entropy check

## 13. Conclusion

This continuation sprint adds a self-documenting layer to the Wallaby test suite by enriching every test file's @moduledoc with a 9-section page specification derived from the LiveView source. The Gold Standard Template now encodes this pattern for all future test files.

The key insight is that **test files should document intent, not just assert behavior** — the @moduledoc enrichment bridges the gap between "what the test checks" and "what the page should do," making each test file a reference for operators, reviewers, and future agents.

Once the 6 parallel agents complete and compilation is verified, the sprint will have produced: 49 enriched test files, 3 page spec documents, 1 gap audit, and 4 new STAMP/AOR constraints — completing deliverable #17 from the parent coverage sprint.
