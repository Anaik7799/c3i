# CLAUDE.md Optimization Analysis — Context Budget & Structural Audit

**Date**: 2026-03-27 13:00 CEST
**Author**: Claude Opus 4.6
**Version**: v21.3.0-SIL6
**Scope**: Full structural analysis of CLAUDE.md for token efficiency and semantic deduplication

---

## 1. Problem Statement

CLAUDE.md is an L6 Artifact (§94.1) loaded into every Claude Code session. At 1,911 lines / 126,780 bytes, combined with 21 `.claude/rules/*.md` files (7,480 lines / 289,189 bytes), the total context budget consumed is approximately **104K tokens — 52% of the 200K session budget**.

This analysis identifies optimization opportunities to reduce token consumption while preserving 100% constraint coverage (SC-SYNC-DOC compliance).

## 2. Quantified Findings

### 2.1 Context Budget Breakdown

| Component | Lines | Bytes | Est. Tokens | % Budget |
|-----------|-------|-------|-------------|----------|
| CLAUDE.md | 1,911 | 126,780 | ~42K | 21% |
| .claude/rules/ (21 files) | 7,480 | 289,189 | ~62K | 31% |
| **Total** | **9,391** | **415,969** | **~104K** | **52%** |
| Available for work | — | — | ~96K | 48% |

### 2.2 Optimization Opportunities (843 lines, 44% of CLAUDE.md)

| Section | Lines | Issue | Recommendation |
|---------|-------|-------|----------------|
| §95.0 GA Release v21.1.0 | 183 | Stale (current: v21.3.0) | Remove or move to docs/verification/ |
| §96.0 GA Release Comprehensive | 202 | Stale + duplicates §95.0 | Remove or move to docs/verification/ |
| §97.0 BDD Integration (#1) | 72 | Already in docs/architecture/BDD_INTEGRATION_ARCHITECTURE.md | Replace with reference |
| §98.0 Devenv Commands (#1) | 61 | Overlaps §95.0 and §6.0 | Remove (§6.0 is authoritative) |
| §14.0 BEP Testing | 136 | Verbose tables, reference-only | Compress to 30-line summary |
| §16.0 Todolist System | 101 | Duplicated in .claude/rules/todolist-access-control.md | Replace with 10-line pointer |
| §5.1-5.2 P0/P1 inline | ~35 | Full details in reconciled-p0-safety.md and reconciled-p1-core.md | Replace with family references |
| §97.0 WebUI HMI (#2) | ~40 | Duplicated concepts across §99.0 Color Rich and §106.0 Cockpit | Consolidate |
| §96.0 HRP (#2) | ~25 | Low-value ceremony spec | Compress |
| Total recoverable | **~843** | | **44% of CLAUDE.md** |

### 2.3 Section Numbering Collisions

| Section # | Occurrence 1 | Occurrence 2 | Occurrence 3 |
|-----------|-------------|-------------|-------------|
| §96.0 | GA Release Comprehensive Checklist | Holographic Regeneration Protocol | — |
| §97.0 | BDD Integration Architecture | WebUI/HMI Dark Cockpit | Full Parallelization Mandate |
| §98.0 | Devenv Command Verification | Plan/Journal Sync Mandate | — |
| §99.0 | Track-Based CEPA Architecture | Color Rich Mechanism | — |

### 2.4 AOR Duplication Analysis

| Location | AOR-* Families | Unique IDs | Status |
|----------|---------------|------------|--------|
| CLAUDE.md §9.0 | 67 families | 344 IDs | **PRIMARY** source |
| .claude/rules/ | 30 families | 319 IDs | Supplementary (only 3 overlap) |
| Code | ~80+ families | 480 IDs | Implementation |

**Critical finding**: CLAUDE.md §9.0 is the PRIMARY source for 67 AOR families (344 unique IDs) — these are NOT duplicated in .claude/rules/ files. The §9.0 section (~350 lines, 18% of file) MUST be preserved.

### 2.5 SC-* Constraint Coverage

| Location | SC-* Families | Unique IDs | Relationship |
|----------|--------------|------------|--------------|
| CLAUDE.md §5.0 | ~62 families | ~269 IDs (shorthand) | Compact inline references |
| .claude/rules/reconciled-*.md | 395 families | 2,297 IDs | Full expanded detail |
| Code | 393 families | 2,257 IDs | Implementation |

**Pattern**: CLAUDE.md uses inline shorthand format (`SC-ENFORCE: ... (-001)`) while reconciled files use full IDs (`SC-ENFORCE-001`). The §5.1-5.2 inline summaries are fully covered by `reconciled-p0-safety.md` and `reconciled-p1-core.md`.

## 3. Proposed Optimization Plan

### Phase 1: Remove Stale Content (-446 lines)

1. **Delete §95.0-96.0 GA Release v21.1.0** (-385 lines) — stale for v21.3.0, reference docs exist in docs/verification/
2. **Delete §98.0 Devenv Commands (#1)** (-61 lines) — fully covered by §6.0

### Phase 2: Deduplicate with References (-250 lines)

3. **Replace §97.0 BDD Integration** with 5-line reference to docs/ (-67 lines)
4. **Replace §16.0 Todolist** with 10-line pointer to todolist-access-control.md (-91 lines)
5. **Compress §14.0 BEP Testing** to 30-line summary (-106 lines)

### Phase 3: Consolidate Sections (-147 lines)

6. **Remove §5.1-5.2 inline details** — keep family names only, reference reconciled files (-35 lines)
7. **Merge duplicate §97.0/§99.0** sections (-72 lines)
8. **Compress §96.0 HRP** (-25 lines)
9. **Renumber** all sections sequentially to eliminate collisions

### Phase 4: Fix Section Numbering

10. Renumber all sections sequentially: §0-§20 (current: §0-§107 with gaps and collisions)

### Expected Result

| Metric | Before | After | Savings |
|--------|--------|-------|---------|
| CLAUDE.md lines | 1,911 | ~1,068 | 843 (44%) |
| CLAUDE.md tokens | ~42K | ~24K | ~18K |
| Session budget available | 48% | 57% | +9% |
| SC-* coverage | 100% | 100% | No loss |
| AOR-* coverage | 100% | 100% | No loss |

## 4. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Removing §9.0 AOR rules loses PRIMARY source | CRITICAL | Do NOT remove §9.0 — it is the only location for 67 AOR families |
| Removing SC-* inline refs breaks session awareness | MEDIUM | Keep family names in §5.0 as index; detail in reconciled files |
| Removing GA checklist loses verification spec | LOW | Content preserved in docs/verification/ |
| Section renumbering breaks cross-references | MEDIUM | Search-replace all internal refs |

## 5. Constraint Compliance

This analysis conforms to:
- **SC-SYNC-DOC-001**: CLAUDE.md remains superset of all code constraints (no constraint deletion)
- **SC-SYNC-DOC-009**: Append-only — constraints moved to .claude/rules/, not deleted
- **AOR-CHG-002**: 4-layer impact analyzed before implementation
- **SC-PRIME-001**: L6 Artifact modification documented

## 6. Related Documents

- CLAUDE.md §94.1 — L6 Artifact classification
- .claude/rules/constraint-sync-mandatory.md — Sync mandate
- .claude/rules/reconciled-p0-safety.md — P0 constraint detail
- .claude/rules/reconciled-p1-core.md — P1 constraint detail
- docs/journal/20260327-1300-claude-md-optimization-analysis.md — This document

## 7. Journal Consolidation Note

As part of this session, 270 journal entries were migrated from `./journal/{2025-12,2026-01,2026-02,2026-03}/` to `docs/journal/` using `git mv` (preserving history). The `docs/journal/` directory is now the **sole authoritative location** for all development journal entries, containing 460 files total.

---

**Status**: Analysis complete. Implementation pending user approval.
**STAMP**: SC-CHG-001, SC-SYNC-DOC-001, SC-PRIME-001
**Layer**: L1-CODE(0), L2-DOMAIN(0), L3-SYSTEM(1), L4-ECOSYSTEM(2)
**Impact Score**: 8 (LOW RISK — documentation restructuring only)
