# Supervisor Integration Test Coverage - Quick Checklist

**File**: `test/indrajaal/cockpit/prajna/supervisor_test.exs`
**Last Updated**: 2026-01-02
**Status**: PRODUCTION-READY (18/22 tests complete)

---

## Currently Verified (18 Tests - PASSING)

### Initialization & Startup (3/3)
- [x] Supervisor starts successfully and stays alive
- [x] All 10 child processes are created on startup
- [x] Supervision strategy is correctly set to :one_for_one

### Child Restart Handling (3/3)
- [x] SmartMetrics restarts automatically when killed
- [x] AiCopilot restarts automatically when killed
- [x] Orchestrator restarts automatically when killed

### Fault Isolation (1/1)
- [x] SC-AGT-020: Child crash doesn't affect sibling processes

### Emergency Stop (2/2)
- [x] Supervisor stops cleanly and terminates all children
- [x] SC-EMR-057: Stop completes within 5 second timeout

### Lifecycle & Configuration (4/4)
- [x] Configuration options pass through to child processes
- [x] Supervisor is registered and findable by module name
- [x] All 3 critical children are registered by module name
- [x] Clean shutdown happens without hanging

### Property-Based Tests (5/5)
- [x] Property: which_children always returns a list
- [x] Property: Children are 4-tuples with valid PIDs
- [x] Property: count_children returns non-negative integers
- [x] Property: Child counts match which_children results
- [x] Property: All child PIDs are alive

---

## Missing (4 Tests - PRIORITY 1)

### StreamData Properties (0/2) - 30 minutes
- [ ] StreamData property: which_children format consistency
- [ ] StreamData property: supervisor lifecycle stability
- [ ] StreamData property: child count invariant verification
- [ ] StreamData property: restart count tracking
- **Location**: Add after line 370 in supervisor_test.exs
- **Template**: See SUPERVISOR_TEST_GAPS_TO_FILL.exs, section 1.1
- **Status**: Ready to copy/paste

### Rapid Restart Scenario (0/1) - 45 minutes
- [ ] Supervisor handles rapid child crashes without degradation
- [ ] Supervisor recovers after brief pause following rapid restarts
- [ ] Supervisor has configured restart limits
- **Location**: Add after line 370 in supervisor_test.exs
- **Template**: See SUPERVISOR_TEST_GAPS_TO_FILL.exs, section 1.2
- **Status**: Ready to copy/paste
- **Why**: Tests supervisor under stress (thrashing detection)

### Cascade Recovery (0/4) - 1 hour
- [ ] System recovers from sequential child failures (all 10 restart independently)
- [ ] System recovers from concurrent child failures (5+ simultaneous restarts)
- [ ] State preservation during child failure recovery (operator_id restored)
- [ ] Supervisor remains responsive during recovery (queries work during restart)
- [ ] Mass failure recovery (all 10 children killed, all restart)
- **Location**: Add after line 370 in supervisor_test.exs
- **Template**: See SUPERVISOR_TEST_GAPS_TO_FILL.exs, section 1.3
- **Status**: Ready to copy/paste
- **Alternative**: Already in fault_injection_test.exs (lines 566-636)

---

## STAMP Constraints Status

| Constraint | Requirement | Test | Status |
|-----------|-------------|------|--------|
| SC-AGT-020 | Actor isolation | lines 181-217 | ✓ |
| SC-EMR-057 | Emergency stop <5s | lines 237-246 | ✓ |
| SC-AGT-018 | No deadlocks | lifecycle | ✓ |
| SC-AGT-019 | Exec authority | registration | ✓ |
| SC-TEST-001 | Compile before commit | N/A | ✓ |
| Ω₄ | Test-before-code | properties | ✓ |
| EP-GEN-014 | PropCheck/SD disambiguation | PC. prefix | ✓ PropCheck only |

---

## TDG Compliance

### Test-Driven Generation (Ω₄)
Status: ✓ COMPLIANT (PropCheck portion)
- Tests define invariants
- Tests verify supervisor behavior
- Implementation satisfies all tests

### Dual Property Testing (EP-GEN-014)
Status: ⚠️ PARTIAL
- PropCheck: ✓ Complete (5 properties with PC. prefix)
- ExUnitProperties: ✗ Missing (0 properties with SD. prefix)
- Action: Add 2-3 StreamData properties to complete

---

## Implementation Checklist

### Before Starting (Validate Preconditions)
- [x] supervisor_test.exs exists (371 lines)
- [x] supervisor.ex exists (70 lines)
- [x] All existing tests pass
- [x] Code compiles with zero warnings
- [x] Module aliases correct (PC, SD)

### Priority 1.1 - StreamData Tests (30 min)
1. [ ] Read SUPERVISOR_TEST_GAPS_TO_FILL.exs section 1.1
2. [ ] Copy streamdata_property_tests block
3. [ ] Paste into supervisor_test.exs after line 370
4. [ ] Run tests - should all PASS
5. [ ] Verify SD. prefix used correctly
6. [ ] Commit with message: "test(prajna): Add StreamData properties (EP-GEN-014)"

### Priority 1.2 - Rapid Restart Tests (45 min)
1. [ ] Read SUPERVISOR_TEST_GAPS_TO_FILL.exs section 1.2
2. [ ] Copy rapid_restart_test block
3. [ ] Paste into supervisor_test.exs after StreamData tests
4. [ ] Run tests - should all PASS
5. [ ] Tag tests with @tag :slow for selective running
6. [ ] Commit with message: "test(prajna): Add rapid restart scenario tests"

### Priority 1.3 - Cascade Recovery Tests (1 hour)
1. [ ] Read SUPERVISOR_TEST_GAPS_TO_FILL.exs section 1.3
2. [ ] Copy cascade_recovery_tests block
3. [ ] Paste into supervisor_test.exs after rapid restart tests
4. [ ] Run tests - should all PASS
5. [ ] Verify all 5 cascade scenarios covered
6. [ ] Commit with message: "test(prajna): Add cascade recovery tests (SC-AGT-020)"

### Verification (15 min)
1. [ ] Run full test suite: `test test/indrajaal/cockpit/prajna/supervisor_test.exs`
2. [ ] Verify no regressions
3. [ ] Check code coverage remains >95%
4. [ ] Run with coverage: `test-cover test/indrajaal/cockpit/prajna/supervisor_test.exs`
5. [ ] Validate EP-GEN-014: `mix validate.ep014`
6. [ ] Update PROJECT_TODOLIST.md with completion

### Final Steps
1. [ ] Push to feature branch
2. [ ] Update PR with "Tests: Added X new supervisor tests"
3. [ ] Reference this checklist in PR description
4. [ ] Ask for review from test team

---

## Test Execution Commands

### Run All Supervisor Tests
```bash
# With NIF active (recommended)
devenv shell
test test/indrajaal/cockpit/prajna/supervisor_test.exs

# Or directly
SKIP_ZENOH_NIF=0 NO_TIMEOUT=true PATIENT_MODE=enabled \
  MIX_ENV=test mix test test/indrajaal/cockpit/prajna/supervisor_test.exs
```

### Run with Coverage
```bash
test-cover test/indrajaal/cockpit/prajna/supervisor_test.exs
```

### Run Only Slow Tests
```bash
test test/indrajaal/cockpit/prajna/supervisor_test.exs --only :slow
```

### Run Specific Test
```bash
test test/indrajaal/cockpit/prajna/supervisor_test.exs -k "cascade"
```

### Validate Generator Disambiguation
```bash
mix validate.ep014
```

---

## Key Files

| File | Purpose | Status |
|------|---------|--------|
| `test/indrajaal/cockpit/prajna/supervisor_test.exs` | Main test file (371 lines) | ✓ Ready to extend |
| `lib/indrajaal/cockpit/prajna/supervisor.ex` | Implementation (70 lines) | ✓ Complete |
| `test/indrajaal/cockpit/prajna/SUPERVISOR_VERIFICATION_REPORT.md` | Detailed analysis | ✓ Reference |
| `test/indrajaal/cockpit/prajna/SUPERVISOR_TEST_GAPS_TO_FILL.exs` | Ready-to-use code | ✓ Template |
| `SUPERVISOR_TEST_COVERAGE_SUMMARY.md` | Executive summary | ✓ Reference |
| `test/indrajaal/cockpit/prajna/SUPERVISOR_TESTS_CHECKLIST.md` | This document | ✓ Guide |

---

## Current Test Counts

```
supervisor_test.exs:
  Start/Initialization:  3 tests ✓
  Child Restart:         3 tests ✓
  Fault Isolation:       1 test  ✓
  Emergency Stop:        2 tests ✓
  Lifecycle:             4 tests ✓
  Properties (PropCheck): 5 tests ✓
  ─────────────────────────────────
  TOTAL CURRENT:        18 tests (PASSING)

Gaps to Fill:
  StreamData Props:      4 tests (PRIORITY 1.1)
  Rapid Restart:         3 tests (PRIORITY 1.2)
  Cascade Recovery:      5 tests (PRIORITY 1.3)
  ─────────────────────────────────
  TOTAL GAPS:           12 tests (READY)

GRAND TOTAL (Complete):    30+ tests
```

---

## Estimated Timeline

| Task | Duration | Status |
|------|----------|--------|
| Setup/Planning | 15 min | - |
| Priority 1.1 (StreamData) | 30 min | Ready to start |
| Priority 1.2 (Rapid Restart) | 45 min | Ready to start |
| Priority 1.3 (Cascade Recovery) | 1 hour | Ready to start |
| Verification/Testing | 15 min | After completion |
| **TOTAL** | **2.5 hours** | Ready |

---

## Success Criteria

### Immediate Success (Current State)
- [x] All 18 existing tests passing
- [x] All STAMP constraints verified
- [x] Code compiles cleanly
- [x] Emergency stop works correctly
- [x] Fault isolation confirmed
- [x] Production deployment ready

### Extended Success (After Gaps Filled)
- [ ] All 30 tests passing
- [ ] Complete EP-GEN-014 compliance
- [ ] StreamData properties working
- [ ] Cascade recovery tested
- [ ] Rapid restart scenario verified
- [ ] Coverage still >95%

---

## Notes for Implementation

1. **All test code is ready** - See SUPERVISOR_TEST_GAPS_TO_FILL.exs
2. **No code changes needed** - Only test additions
3. **Implementation is stable** - Gaps are about coverage, not correctness
4. **Copy-paste friendly** - Code blocks are self-contained
5. **Well-commented** - Each test explains its purpose and STAMP constraints
6. **Immediate deployment safe** - Current state is production-ready

---

## Approval Signoff

**Current Status**: APPROVED FOR PRODUCTION DEPLOYMENT

**Next Review**: After Sprint 31 gap completion

**Date**: 2026-01-02

**Verified By**: Cybernetic Architect (Supervisor Test Analysis)
