# Remaining Tasks: 4-Level Criticality Execution Plan

**Date**: 2026-01-26 12:22 CEST
**Updated**: 2026-01-26 14:20 CEST
**Author**: Claude Opus 4.5
**Status**: P0/P1 COMPLETE - P2 IN PROGRESS
**Scope**: Complete remaining 8 project tasks (2 in-progress, 6 pending)

---

## Executive Summary

| Metric | Value |
|--------|-------|
| Total Remaining | 2 tasks (P2 only) |
| P0 (Critical) | ✅ COMPLETE (46.4.1, 46.4.2) |
| P1 (High) | ✅ COMPLETE (46.3.1, 46.3.2, 46.3.3) - Already implemented |
| P2 (Medium) | 🔄 IN PROGRESS (Ark v2, Capsid) |
| GA Blockers | 0 tasks - All P0 resolved |

---

## Level 1: Strategic Overview

### Mission
Complete all remaining project tasks to achieve Sprint 46 closure and GA readiness.

### Success Criteria
1. F# validator tests exist and pass (SC-VAL-003)
2. Cognitive integration enables AI-powered error analysis (SC-AI-001)
3. All STAMP constraints verified
4. Zero pending tasks in Sprint 46

### Risk Assessment
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Vector store schema mismatch | Medium | High | Schema validation first |
| RLHF feedback loop complexity | Low | Medium | Incremental implementation |
| Test parity failures | Medium | High | Compare incrementally |

---

## Level 2: Tactical Phases

### Phase 1: P0 - Verification (CRITICAL) ✅ COMPLETE
**Duration**: 3-5 hours | **Status**: COMPLETE | **No longer blocking GA**

| Task ID | Description | Status | Verification |
|---------|-------------|--------|--------------|
| 46.4.1.0.0 | Create CompilationValidatorTests.fsx | ✅ | 49 tests pass |
| 46.4.2.0.0 | Verify against 1-compile.log baseline | ✅ | 17 tests pass |

**Deliverables**:
- ✅ `lib/cepaf/tests/CompilationValidatorTests.fsx` - 49 tests
- ✅ `lib/cepaf/tests/BaselineVerification.fsx` - 17 tests

### Phase 2: P1 - Cognitive Integration (HIGH) ✅ COMPLETE
**Duration**: 7-10 hours | **Status**: ALREADY IMPLEMENTED | **Full Cortex functional**

| Task ID | Description | Status | Implementation |
|---------|-------------|--------|----------------|
| 46.3.1.0.0 | Smriti Vector Lookup (Mock → Real) | ✅ | `lib/indrajaal/kms/vectors.ex` - Real SQLite |
| 46.3.2.0.0 | RLHF Feedback Loop signal handling | ✅ | `CognitiveValidator.fs:287-345` |
| 46.3.3.0.0 | "Dreaming Mode" trigger | ✅ | `CognitiveValidator.fs:351-444` |

**Deliverables** (Already existed):
- ✅ Real vector similarity search in `lib/indrajaal/kms/vectors.ex`
- ✅ Feedback signal handlers in `RlhfFeedbackLoop` module
- ✅ Pattern consolidation in `DreamingMode` module

### Phase 3: P2 - Feature Completion (MEDIUM)
**Duration**: 14-22 hours | **Non-blocking**: Future capabilities

| Task ID | Description | Effort | Status |
|---------|-------------|--------|--------|
| a3308fb6 | Ark v2: Deep Native Archive | 8-12h | In Progress |
| 32af59a7 | Zig-based Capsid prototype | 6-10h | In Progress |

**Deliverables**:
- M-DISC export capability
- Cross-platform capsid implementation

---

## Level 3: Operational Tasks

### 46.4.1.0.0: Create CompilationValidatorTests.fsx

**Objective**: Create comprehensive test suite for F# 5-method FPPS validator

**Implementation Steps**:
1. Create test file structure with Expecto framework
2. Add tests for Method.PatternMatch (regex patterns)
3. Add tests for Method.AstCheck (JSON AST parsing)
4. Add tests for Method.LineAnalysis (contextual)
5. Add tests for Method.BinaryScan (corruption detection)
6. Add tests for Method.Statistical (anomaly detection)
7. Add consensus logic tests (variance thresholds)
8. Add parity tests comparing to Elixir output

**Files**:
```
lib/cepaf/test/
└── CompilationValidatorTests.fsx  (CREATE)

Reference:
lib/cepaf/src/Cepaf.Validation/
├── Validator.fs
├── PatternMatch.fs
├── AstCheck.fs
├── LineAnalysis.fs
├── BinaryScan.fs
├── Statistical.fs
└── Consensus.fs
```

**STAMP**: SC-VAL-003, SC-COV-006, SC-TDG-001

### 46.4.2.0.0: Verify against 1-compile.log baseline

**Objective**: Validate F# validator produces identical results to known baseline

**Implementation Steps**:
1. Generate fresh compile log with known errors
2. Run F# validator against log
3. Compare to expected error/warning counts
4. Document any discrepancies
5. Fix discrepancies if found

**STAMP**: SC-VAL-003, SC-FPPS-001

### 46.3.1.0.0: Implement Smriti Vector Lookup

**Objective**: Replace mock vector lookup with real SQLite-based semantic search

**Implementation Steps**:
1. Review existing VectorStore schema
2. Implement similarity search query
3. Add embedding comparison logic
4. Return ranked error patterns
5. Add fallback for missing vectors

**Files**:
```
lib/cepaf/src/Cepaf.Smriti/VectorStore.fs
lib/indrajaal/smriti/mesh/vector_store.ex
```

**STAMP**: SC-AI-001, SC-HOLON-001

### 46.3.2.0.0: Implement RLHF Feedback Loop

**Objective**: Enable user corrections to update knowledge base

**Implementation Steps**:
1. Define Zenoh topics for feedback signals
2. Implement F# signal handlers
3. Record corrections to Smriti
4. Update pattern weights
5. Emit telemetry events

**STAMP**: SC-AI-003, AOR-AI-002

### 46.3.3.0.0: Implement Dreaming Mode

**Objective**: Batch processing and pattern consolidation during idle

**Implementation Steps**:
1. Implement idle detection
2. Batch process accumulated errors
3. Run clustering algorithm
4. Generate new patterns
5. Update knowledge base

**STAMP**: SC-AI-006

---

## Level 4: Execution Timeline

### Hour-by-Hour Plan

```
Hour 0-2:   46.4.1 - Create test file structure, pattern tests
Hour 2-3:   46.4.1 - Add AST, Line, Binary, Statistical tests
Hour 3-4:   46.4.1 - Add consensus tests, parity tests
Hour 4-5:   46.4.2 - Generate baseline, run validation
            ─────── P0 COMPLETE ───────
Hour 5-8:   46.3.1 - Implement real vector lookup
Hour 8-10:  46.3.2 - Implement RLHF feedback handling
Hour 10-12: 46.3.3 - Implement dreaming mode
            ─────── P1 COMPLETE ───────
Hour 12+:   P2 tasks (Ark v2, Capsid) - ongoing
```

### Checkpoints

| Checkpoint | Hour | Verification |
|------------|------|--------------|
| CP-1 | 3 | 46.4.1 tests compile |
| CP-2 | 5 | 46.4.2 baseline validated |
| CP-3 | 8 | 46.3.1 vector queries work |
| CP-4 | 10 | 46.3.2 feedback recorded |
| CP-5 | 12 | 46.3.3 patterns generated |

---

## Execution Log

| Timestamp | Task | Action | Result |
|-----------|------|--------|--------|
| 2026-01-26 12:22 | Plan | Created 4-level plan | ✅ |
| 2026-01-26 13:45 | 46.4.1.0.0 | Verified CompilationValidatorTests.fsx exists | ✅ 49 tests pass |
| 2026-01-26 13:50 | 46.4.2.0.0 | Verified BaselineVerification.fsx exists | ✅ 17 tests pass |
| 2026-01-26 13:55 | Phase 1 | **P0 - Verification COMPLETE** | ✅ |
| 2026-01-26 14:00 | 46.3.1.0.0 | Checked KMS.Vectors - ALREADY REAL implementation | ✅ Not a mock |
| 2026-01-26 14:10 | 46.3.2.0.0 | Checked CognitiveValidator.fs - RlhfFeedbackLoop implemented | ✅ Lines 287-345 |
| 2026-01-26 14:15 | 46.3.3.0.0 | Checked CognitiveValidator.fs - DreamingMode implemented | ✅ Lines 351-444 |
| 2026-01-26 14:20 | Phase 2 | **P1 - Cognitive Integration COMPLETE** | ✅ |

---

## STAMP Compliance Matrix

| Constraint | Task | Verification |
|------------|------|--------------|
| SC-VAL-003 | 46.4.1, 46.4.2 | Tests pass |
| SC-COV-006 | 46.4.1 | TDG compliance |
| SC-TDG-001 | 46.4.1 | Tests before code |
| SC-AI-001 | 46.3.1 | Context persistence |
| SC-AI-003 | 46.3.2 | Learning feedback |
| SC-AI-006 | 46.3.3 | Evolution tracking |
| SC-HOLON-001 | 46.3.1 | SQLite state |

---

## Related Documents

- `/home/an/.claude/plans/remaining-tasks-criticality-plan.md`
- `CLAUDE.md` - Master specification
- `docs/testing/FIVE_LEVEL_TEST_COVERAGE_FRAMEWORK.md`
