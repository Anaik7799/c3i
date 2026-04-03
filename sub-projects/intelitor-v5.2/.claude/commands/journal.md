---
description: Create a development journal entry with git context
allowed-tools: Write, Bash(date:*), Bash(git:*), Read, Grep, Glob
argument-hint: [topic-slug]
---

# Development Journal Entry — 13-Section Retrospective Standard

Create a timestamped journal entry in `docs/journal/` using the **mandatory 13-section format**.
Every journal entry MUST include ALL 13 sections. For smaller changes, sections may be brief
(1-2 lines) but NEVER omitted.

## File Path

```
docs/journal/$(date +%Y%m%d-%H%M)-$ARGUMENTS.md
```

IMPORTANT: Always `docs/journal/` — never `./journal/` or dated subdirectories.

## Mandatory 13-Section Format

```markdown
# [Title] — [Subtitle]

**Date**: YYYYMMDD-HHMM CEST
**Author**: [Agent ID]
**Commit**: `[sha]` (final), predecessors: `[sha]`, `[sha]`
**Version**: v[X.Y.Z]-SIL6
**Branch**: [branch name]
**STAMP**: [Primary SC-* constraints addressed]
**Compliance**: SC-SYNC-DOC-002 (journal mandatory for every plan)

---

## 1. Scope & Trigger

WHY this work was initiated. What event, audit, failure, or directive triggered it.
Include the scope boundary — what's in and what's explicitly out.

## 2. Pre-State Assessment

System state BEFORE the work began. Quantify:
- How many items broken/degraded/pending
- Relevant metrics (route health %, test count, compilation state)
- Service availability snapshot
- Known blockers or constraints

## 3. Execution Detail — Phase/Wave Breakdown

Detailed account of WHAT was done, organized by execution phase.
For multi-wave work, one subsection per wave with:
- Tasks completed (numbered)
- Root causes found and fixes applied
- Code snippets for non-obvious changes
- Compile/test verification after each phase

## 4. Root Cause Analysis

WHY things were broken. Classify root causes into categories.
Use the 5-Why method where appropriate. Group by pattern, not by file.

| Root Cause Class | Count | Example |
|-----------------|-------|---------|
| [Class A] | N | [one-liner] |
| [Class B] | N | [one-liner] |

## 5. Fix Taxonomy

HOW each class of problem was fixed. Include the general fix pattern
(reusable across future instances) not just the specific file edits.

```elixir
# Pattern: [name]
# Applies when: [condition]
[code template]
```

## 6. Patterns & Anti-Patterns Discovered

Reusable learnings extracted from this work session.

### Patterns (DO this)
- **[Pattern Name]**: [description + when to apply]

### Anti-Patterns (AVOID this)
- **[Anti-Pattern Name]**: [description + why it fails + what to do instead]

## 7. Verification Matrix

Proof that the work is correct. Include:
- Compilation status (errors, warnings)
- Test results (pass/fail/skip counts)
- Route/endpoint verification (HTTP status codes)
- Manual spot-checks performed

```
[Verification output — concrete evidence, not assertions]
```

## 8. Files Modified

Complete manifest of every file touched.

| File | Change Type | Lines | Notes |
|------|------------|-------|-------|
| `path/to/file.ex` | [new/modified/deleted] | +N/-M | [one-liner] |

**Total delta**: +X insertions, -Y deletions across Z files.

## 9. Architectural Observations

System-level insights that emerged from the work. Things that are NOT about the
specific fix but about the system's design, topology, or failure modes.
Include diagrams (ASCII) where they clarify structure.

## 10. Remaining Gaps

Honest assessment of what is NOT done. Prioritized.

| Gap | Priority | Notes |
|-----|----------|-------|
| [description] | P0-P3 | [why it's deferred, what unblocks it] |

## 11. Metrics Summary

Quantitative before/after comparison.

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| [metric] | [value] | [value] | [+/-] |

## 12. STAMP & Constitutional Alignment

Which safety constraints and constitutional invariants this work addresses.
- SC-* constraints satisfied or advanced
- AOR-* rules followed during execution
- Constitutional invariants (Psi-0 through Psi-5, Omega-0) preserved
- Any constraint violations encountered and how they were resolved

## 13. Conclusion

2-3 paragraph synthesis:
- What was accomplished (quantified)
- Most important insight or pattern discovered
- How this work positions the system for the next evolution step
```

## Section Scaling Guide

| Work Size | Sections 2-5 | Sections 6-9 | Sections 10-13 |
|-----------|-------------|--------------|-----------------|
| Trivial (1-3 files, <30 min) | 1-2 lines each | 1-2 lines each | 1-2 lines each |
| Standard (4-15 files, 1-4 hrs) | 1-2 paragraphs each | Full detail | Full detail |
| Major (15+ files, multi-wave) | Subsections per phase | Full detail + diagrams | Full detail |

Even trivial entries get all 13 headers — the discipline of filling them builds pattern
recognition over time.

## Information Theory

**Entropy Reduction**: $I_{journal} = H(S_{pre}) - H(S_{post})$ — each entry reduces system uncertainty

**Knowledge Density**: $\rho_K = \frac{\text{decisions} + \text{constraints} + \text{patterns} + \text{KPIs}}{\text{lines}}$

Target: $\rho_K \geq 0.3$ (at least one insight per 3 lines of prose)

## STAMP Constraints

| ID | Constraint |
|----|------------|
| SC-CHG-001 | Structured change notes |
| SC-CHG-002 | 4-layer impact analysis |
| SC-REG-001 | State mutations via append-only register |
| SC-SYNC-DOC-001 | Timestamps YYYYMMDD-HHMM CEST |
| SC-SYNC-DOC-002 | Every plan triggers a journal entry |
