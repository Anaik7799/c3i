# Phase 2: Systematic Fix Planning - Infrastructure

## Overview

This directory contains the systematic fix planning infrastructure for Phase 2 of the zero-error compilation initiative for the Indrajaal Safety Monitoring System.

**Classification**: Safety-Critical / Life-Critical Software
**Total Errors**: 40 unique compilation errors
**Target File**: `lib/indrajaal/safety/monitor.ex`
**Methodology**: TPS (Toyota Production System) + STAMP + AEE SOPv5.11

---

## Directory Contents

### 1. master-execution.sh
**Purpose**: Orchestrate the entire Phase 2 execution across all 8 batches

**Key Features**:
- Automated batch execution with validation
- Git checkpoint management (before/after each batch)
- Automated compilation validation after each batch
- Test execution and verification
- Emergency rollback on failure
- Comprehensive execution reporting

**Usage**:
```bash
# Execute complete Phase 2
./master-execution.sh

# The script will guide you through all 8 batches systematically
```

**What It Does**:
1. Creates git checkpoint before each batch
2. Prompts for manual fix application (or executes batch script)
3. Validates compilation after each batch
4. Runs safety module tests
5. Commits batch completion with tags
6. Provides rollback if batch fails
7. Generates final execution report

---

### 2. validate-fixes.sh
**Purpose**: Comprehensive multi-environment validation

**Key Features**:
- Multi-environment compilation (dev/test/prod)
- Static analysis (3 xref methods)
- Test suite execution
- Code quality checks (format, credo)
- Error consistency validation
- Detailed pass/fail reporting

**Usage**:
```bash
# Run comprehensive validation
./validate-fixes.sh

# Review results in data/tmp/validation-*.log
```

**Validation Steps**:
1. ✓ Development compilation
2. ✓ Test compilation
3. ✓ Production compilation
4. ✓ Unreachable code analysis
5. ✓ Undefined function analysis
6. ✓ Deprecated function analysis
7. ✓ Safety module tests
8. ✓ Code formatting check
9. ✓ Credo analysis
10. ✓ Error consistency verification

---

### 3. emergency-rollback.sh
**Purpose**: Emergency recovery to last known good state

**Key Features**:
- List available rollback points
- Create backup before rollback
- Verify rollback target exists
- Perform git reset to checkpoint
- Quick compilation verification
- Comprehensive rollback reporting

**Usage**:
```bash
# List available rollback points
./emergency-rollback.sh --list

# Rollback to before batch 3
./emergency-rollback.sh batch-3-pre

# Rollback with automatic backup
./emergency-rollback.sh --backup batch-2-post

# Force rollback without confirmation
./emergency-rollback.sh --force batch-1-pre

# Show help
./emergency-rollback.sh --help
```

**Rollback Targets**:
- `batch-N-pre`: State before batch N
- `batch-N-post`: State after batch N completed
- Any git tag or commit hash

---

### 4. batch-guidance.md
**Purpose**: Detailed fix guidance for all 8 batches

**Contents**:
- Comprehensive fix strategies for each batch
- Code examples (wrong vs correct)
- Manual fix procedures
- Validation commands
- Success criteria

**Batches Covered**:
1. **Batch 1**: 54 violation_data fixes
2. **Batch 2a/2b/2c**: 66 metadata fixes (split into 3 batches)
3. **Batch 3**: 24 constraint_name fixes
4. **Batch 4**: 18 new_state fixes
5. **Batch 5/6**: 36 range validation fixes (split into 2 batches)
6. **Batch 7**: 12 result fixes
7. **Batch 8**: 30 final state management fixes

---

## Quick Start Guide

### Option 1: Automated Execution (Recommended)

```bash
# Navigate to Phase 2 directory
cd /home/an/dev/indrajaal-demo/scripts/fixes/phase2-safety-monitor

# Execute master script
./master-execution.sh

# Follow the prompts for each batch
# Apply fixes as documented in batch-guidance.md
# Validation runs automatically after each batch
```

### Option 2: Manual Batch-by-Batch Execution

```bash
# 1. Review batch guidance
cat batch-guidance.md

# 2. Create checkpoint before batch 1
git add -A
git commit -m "Checkpoint before Batch 1"
git tag batch-1-pre

# 3. Apply fixes from batch-guidance.md for Batch 1

# 4. Validate compilation
fish -c "set -x MIX_ENV dev; mix compile --force --all-warnings 2>&1 | tee ./data/tmp/batch1-validation.log"

# 5. Check error count
grep -c "error:" ./data/tmp/batch1-validation.log

# 6. Run tests
mix test test/indrajaal/safety/

# 7. Commit batch completion
git add -A
git commit -m "Batch 1 complete: Fixed 54 violation_data errors"
git tag batch-1-post

# 8. Repeat for batches 2-8
```

### Option 3: Quick Validation Only

```bash
# Run comprehensive validation without making changes
./validate-fixes.sh

# Review results in data/tmp/validation-*.log
```

---

## Execution Flow

```
START
  │
  ├─→ Batch 1: violation_data fixes (54 fixes)
  │    ├─→ Git checkpoint (batch-1-pre)
  │    ├─→ Apply fixes
  │    ├─→ Validate compilation
  │    ├─→ Run tests
  │    └─→ Commit (batch-1-post)
  │
  ├─→ Batch 2a: metadata fixes part 1 (25 fixes)
  │    └─→ [same workflow]
  │
  ├─→ Batch 2b: metadata fixes part 2 (25 fixes)
  │    └─→ [same workflow]
  │
  ├─→ Batch 2c: metadata fixes part 3 (16 fixes)
  │    └─→ [same workflow]
  │
  ├─→ Batch 3: constraint_name fixes (24 fixes)
  │    └─→ [same workflow]
  │
  ├─→ Batch 4: new_state fixes (18 fixes)
  │    └─→ [same workflow]
  │
  ├─→ Batch 5: range validation part 1 (25 fixes)
  │    └─→ [same workflow]
  │
  ├─→ Batch 6: range validation part 2 (11 fixes)
  │    └─→ [same workflow]
  │
  └─→ Batch 8: final state management (30 fixes)
       └─→ [same workflow]

FINAL VALIDATION
  │
  ├─→ Multi-environment compilation (dev/test/prod)
  ├─→ Static analysis (3 xref methods)
  ├─→ Test suite execution
  ├─→ Code quality checks
  └─→ Success certification

COMPLETE
```

---

## Success Criteria

### Batch-Level Success
✅ Error count decreases after each batch
✅ Compilation succeeds (exit code 0)
✅ Tests execute without crashes
✅ Git checkpoint created successfully

### Phase-Level Success
✅ 0 errors in development compilation
✅ 0 errors in test compilation
✅ 0 errors in production compilation
✅ 0 errors in static analysis (all 3 xref methods)
✅ All safety module tests passing
✅ All 8 batches completed with checkpoints
✅ Comprehensive validation passing

---

## Rollback Strategy

### When to Rollback

**Immediate Rollback Required**:
- Compilation fails after batch with NEW errors
- Error count INCREASES instead of decreases
- Critical tests fail that were passing before
- File corruption or major syntax errors

**Cautious Continuation**:
- Error count stays same (batch may not have reached those errors yet)
- Non-safety tests fail (document and continue)
- Warnings increase (not blocking for error fixing)

### How to Rollback

```bash
# Quick rollback to last batch
./emergency-rollback.sh batch-N-pre

# Rollback with backup
./emergency-rollback.sh --backup batch-N-pre

# List all available rollback points
./emergency-rollback.sh --list
```

---

## Error Resolution Guide

### Common Issues

**Issue**: "Git tag already exists"
```bash
# Solution: Force update the tag
git tag batch-1-pre -f
```

**Issue**: "Compilation failed with same error count"
```bash
# Diagnosis: Fixes may not have been applied correctly
# Solution:
1. Review batch-guidance.md for the specific batch
2. Verify all fixes were applied
3. Check for typos in variable names
4. Re-run compilation to confirm
```

**Issue**: "Tests failing after fixes"
```bash
# Diagnosis: May need test updates for changed signatures
# Solution:
1. Review test failures
2. Update test expectations if needed
3. Ensure tests match new code structure
4. Re-run tests
```

**Issue**: "Error count increased"
```bash
# Diagnosis: Critical - systematic fix error
# Solution:
1. IMMEDIATE ROLLBACK: ./emergency-rollback.sh batch-N-pre
2. Review what was changed
3. Identify why errors increased
4. Document issue
5. Fix systematically
6. Re-apply batch
```

---

## Logging and Audit Trail

### Log Files Created

All logs saved in `/home/an/dev/indrajaal-demo/data/tmp/`:

**Batch Validation Logs**:
- `batch1-validation.log` through `batch8-validation.log`
- Contains compilation output for each batch

**Batch Test Logs**:
- `batch1-test.log` through `batch8-test.log`
- Contains test execution results for each batch

**Comprehensive Validation Logs**:
- `validation-dev.log` - Development compilation
- `validation-test.log` - Test compilation
- `validation-prod.log` - Production compilation
- `validation-xref-*.log` - Static analysis results
- `validation-safety-tests.log` - Test suite results
- `comprehensive-validation-TIMESTAMP.log` - Complete validation report

### Git History

**Tags Created**:
- `batch-1-pre` through `batch-8-pre` - Pre-batch checkpoints
- `batch-1-post` through `batch-8-post` - Post-batch completions

**Commits**:
- Each batch gets a detailed commit message
- Commit messages include: batch number, description, fix count

---

## Phase 2 Completion

### Final Steps

After all 8 batches complete successfully:

1. **Run Final Validation**:
   ```bash
   ./validate-fixes.sh
   ```

2. **Verify Zero Errors**:
   ```bash
   # All should show 0:
   grep -c "error:" ./data/tmp/validation-dev.log
   grep -c "error:" ./data/tmp/validation-test.log
   grep -c "error:" ./data/tmp/validation-prod.log
   ```

3. **Document Completion**:
   - Create journal entry for Phase 2 completion
   - Update PROJECT_TODOLIST.md
   - Mark Phase 2 complete in todo list

4. **Proceed to Phase 3**:
   - Phase 3: AEE SOPv5.11 + GDE Execution
   - 15-agent autonomous execution
   - Cybernetic feedback loops

---

## Support and Troubleshooting

### Need Help?

1. **Review Documentation**:
   - This README
   - `batch-guidance.md` for fix details
   - Phase 1 journal entry in `docs/journal/`

2. **Check Logs**:
   - Review validation logs in `data/tmp/`
   - Check git log for recent changes
   - Review error patterns in compilation output

3. **Use Rollback**:
   - Always available via `emergency-rollback.sh`
   - Creates automatic backup
   - Quick recovery to last known good state

4. **Emergency Contact**:
   - This is safety-critical software
   - Document all issues thoroughly
   - Apply TPS 5-Level RCA for failures

---

## Estimated Execution Time

**Total Time**: ~2.2 hours (132 minutes)

**Breakdown**:
- Batch 1: 20 minutes
- Batch 2a/2b/2c: 40 minutes total
- Batch 3: 12 minutes
- Batch 4: 10 minutes
- Batch 5/6: 23 minutes total
- Batch 7: 8 minutes
- Batch 8: 18 minutes
- Final Validation: 20 minutes

**Note**: Times include fix application, compilation, testing, and git operations.

---

## Safety-Critical Reminder

🚨 **This is life-critical software**

- Take time to verify each fix
- Never rush batch execution
- Always validate before proceeding
- Use rollback when in doubt
- Document all decisions
- Apply systematic approach

**Zero tolerance for shortcuts in safety-critical systems.**

---

## Phase 2 Objectives Recap

✅ Create systematic fix planning infrastructure
✅ Establish batch execution workflow
✅ Implement automated validation
✅ Provide emergency rollback capability
✅ Document all fix procedures
✅ Create audit trail mechanism
✅ Enable Phase 3 execution readiness

**Status**: Phase 2 infrastructure complete and ready for execution.
