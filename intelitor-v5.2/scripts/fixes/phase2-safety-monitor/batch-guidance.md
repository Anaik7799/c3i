# Phase 2 Batch Execution Guidance

## Overview

This document provides detailed guidance for applying fixes to `lib/indrajaal/safety/monitor.ex` across 8 systematic batches.

**Total Errors**: 40 unique compilation errors
**Target File**: lib/indrajaal/safety/monitor.ex
**Safety Classification**: P1 (Safety-Critical) - Life-critical system
**Error Type**: Type A (Undefined variable - underscore prefix issues)

---

## Batch 1: violation_data Prefix Fixes

**Fixes**: 54 instances
**Pattern**: `{_violation_data, _new_state} = ...` → Used as `violation_data` without underscore
**Duration**: ~20 minutes

### Fix Strategy

**Problem**: Pattern match variables with underscore prefix, but used without underscore

```elixir
# ❌ WRONG (causes 54 errors):
{_violation_data, _new_state} = evaluate_constraint(...)
updated_violation = Map.merge(_violation_data, updates)  # Error: _violation_data undefined

# ✅ CORRECT:
{violation_data, new_state} = evaluate_constraint(...)
updated_violation = Map.merge(violation_data, updates)  # Works
```

### Manual Fix Procedure

1. Search for all instances of `_violation_data` in pattern matches
2. Remove underscore prefix when variable is actually used
3. Keep underscore if variable is truly unused

### Validation Commands

```bash
# After applying fixes
fish -c "set -x MIX_ENV dev; mix compile --force --all-warnings 2>&1 | tee ./data/tmp/batch1-validation.log"

# Expected result: 14 errors remaining (40 - 26 unique fixed in pattern = ~14)
grep -c "error:" ./data/tmp/batch1-validation.log
```

---

## Batch 2a: metadata Fixes (Part 1/3)

**Fixes**: 25 instances (first 25 of 66 total)
**Pattern**: `_metadata` parameter defined, used as `meta_data`
**Duration**: ~15 minutes

### Fix Strategy

**Problem**: Parameter named `_metadata` but code uses `meta_data`

```elixir
# ❌ WRONG (causes 66 errors):
defp check_constraint(constraint, value, _metadata) do
  Logger.metadata(meta_data)  # Error: meta_data undefined
end

# ✅ CORRECT Option 1 (rename usage):
defp check_constraint(constraint, value, _metadata) do
  Logger.metadata(_metadata)  # Works
end

# ✅ CORRECT Option 2 (remove underscore from parameter):
defp check_constraint(constraint, value, metadata) do
  Logger.metadata(metadata)  # Works
end
```

### Manual Fix Procedure

1. Find first 25 instances of `meta_data` usage
2. Either:
   - Change `meta_data` → `_metadata` (if parameter has underscore)
   - OR change parameter `_metadata` → `metadata` (if used)
3. Be consistent with the approach across the file

### Validation Commands

```bash
fish -c "set -x MIX_ENV dev; mix compile --force --all-warnings 2>&1 | tee ./data/tmp/batch2a-validation.log"

# Expected result: Errors decreasing
grep -c "error:" ./data/tmp/batch2a-validation.log
```

---

## Batch 2b: metadata Fixes (Part 2/3)

**Fixes**: 25 instances (middle 25 of 66 total)
**Pattern**: Continue _metadata pattern fixes
**Duration**: ~15 minutes

### Fix Strategy

Continue applying the same fix pattern from Batch 2a to the next 25 instances.

### Validation Commands

```bash
fish -c "set -x MIX_ENV dev; mix compile --force --all-warnings 2>&1 | tee ./data/tmp/batch2b-validation.log"
grep -c "error:" ./data/tmp/batch2b-validation.log
```

---

## Batch 2c: metadata Fixes (Part 3/3)

**Fixes**: 16 instances (final 16 of 66 total)
**Pattern**: Complete _metadata pattern fixes
**Duration**: ~10 minutes

### Fix Strategy

Complete the remaining metadata fixes to finish the pattern.

### Validation Commands

```bash
fish -c "set -x MIX_ENV dev; mix compile --force --all-warnings 2>&1 | tee ./data/tmp/batch2c-validation.log"
grep -c "error:" ./data/tmp/batch2c-validation.log
```

---

## Batch 3: constraint_name Fixes

**Fixes**: 24 instances
**Pattern**: `{_constraint_name, _result} = ...` → Used as `constraint_name`
**Duration**: ~12 minutes

### Fix Strategy

**Problem**: Pattern match with underscore, used without underscore

```elixir
# ❌ WRONG:
{_constraint_name, _result} = evaluate(...)
Logger.error("Constraint #{constraint_name} violated")  # Error: constraint_name undefined

# ✅ CORRECT:
{constraint_name, result} = evaluate(...)
Logger.error("Constraint #{constraint_name} violated")  # Works
```

### Manual Fix Procedure

1. Find all pattern matches with `_constraint_name`
2. Remove underscore if variable is used in function body
3. Update any `_result` variables used in same pattern match

### Validation Commands

```bash
fish -c "set -x MIX_ENV dev; mix compile --force --all-warnings 2>&1 | tee ./data/tmp/batch3-validation.log"
grep -c "error:" ./data/tmp/batch3-validation.log
```

---

## Batch 4: new_state Fixes

**Fixes**: 18 instances
**Pattern**: `{_result, _new_state} = ...` → Returned as `new_state`
**Duration**: ~10 minutes

### Fix Strategy

**Problem**: GenServer state management with underscore prefix

```elixir
# ❌ WRONG:
{_result, _new_state} = evaluate_constraint(...)
{:reply, result, new_state}  # Error: result and new_state undefined

# ✅ CORRECT:
{result, new_state} = evaluate_constraint(...)
{:reply, result, new_state}  # Works
```

### Manual Fix Procedure

1. Find all GenServer callbacks returning state
2. Remove underscore from `_new_state` in pattern matches
3. Ensure both `result` and `new_state` are handled

### Validation Commands

```bash
fish -c "set -x MIX_ENV dev; mix compile --force --all-warnings 2>&1 | tee ./data/tmp/batch4-validation.log"
grep -c "error:" ./data/tmp/batch4-validation.log
```

---

## Batch 5: Range Validation (min_val/max_val) Fixes Part 1

**Fixes**: 25 instances (first 25 of 36 total)
**Pattern**: `{_min_val, _max_val} = constraint.limit` → Used without underscore
**Duration**: ~15 minutes

### Fix Strategy

**Problem**: Range constraint checking with underscore prefix

```elixir
# ❌ WRONG:
{_min_val, _max_val} = constraint.limit
cond do
  value < min_val -> ...  # Error: min_val undefined
  value > max_val -> ...  # Error: max_val undefined
end

# ✅ CORRECT:
{min_val, max_val} = constraint.limit
cond do
  value < min_val -> ...  # Works
  value > max_val -> ...  # Works
end
```

### Manual Fix Procedure

1. Find first 25 instances of min_val/max_val pattern matches
2. Remove underscore prefix from both `_min_val` and `_max_val`
3. Verify usage in cond/case statements

### Validation Commands

```bash
fish -c "set -x MIX_ENV dev; mix compile --force --all-warnings 2>&1 | tee ./data/tmp/batch5-validation.log"
grep -c "error:" ./data/tmp/batch5-validation.log
```

---

## Batch 6: Range Validation Fixes Part 2

**Fixes**: 11 instances (remaining 11 of 36 total)
**Pattern**: Complete min_val/max_val fixes
**Duration**: ~8 minutes

### Fix Strategy

Complete the remaining range validation fixes.

### Validation Commands

```bash
fish -c "set -x MIX_ENV dev; mix compile --force --all-warnings 2>&1 | tee ./data/tmp/batch6-validation.log"
grep -c "error:" ./data/tmp/batch6-validation.log
```

---

## Batch 7: result Fixes

**Fixes**: 12 instances
**Pattern**: `{_result, _state} = ...` → Returned as `result`
**Duration**: ~8 minutes

### Fix Strategy

**Problem**: Result variables with underscore prefix in GenServer replies

```elixir
# ❌ WRONG:
{_result, _state} = validate(...)
{:reply, result, state}  # Error: result undefined

# ✅ CORRECT:
{result, state} = validate(...)
{:reply, result, state}  # Works
```

### Manual Fix Procedure

1. Find all GenServer callbacks with result pattern matches
2. Remove underscore from `_result` when used in reply
3. Check state handling is consistent

### Validation Commands

```bash
fish -c "set -x MIX_ENV dev; mix compile --force --all-warnings 2>&1 | tee ./data/tmp/batch7-validation.log"
grep -c "error:" ./data/tmp/batch7-validation.log
```

---

## Batch 8: Final State Management Fixes

**Fixes**: 30 instances (remaining patterns)
**Pattern**: Various state management variables
**Duration**: ~18 minutes

### Fix Strategy

**Problem**: Multiple state management patterns with underscore prefix

```elixir
# Patterns to fix:
# - updated_violation (6 instances)
# - updated_constraints (6 instances)
# - results (6 instances)
# - newstate (6 instances)
# - constraint_results (6 instances)

# ❌ WRONG:
{_updated_violation, _state} = update(...)
Map.put(state, :violations, updated_violation)  # Error: updated_violation undefined

# ✅ CORRECT:
{updated_violation, state} = update(...)
Map.put(state, :violations, updated_violation)  # Works
```

### Manual Fix Procedure

1. Find all remaining state management variables with underscore prefix
2. Remove underscores from variables used in function body
3. Verify all state transitions work correctly

### Validation Commands

```bash
fish -c "set -x MIX_ENV dev; mix compile --force --all-warnings 2>&1 | tee ./data/tmp/batch8-validation.log"

# Expected result: 0 errors (all fixed)
grep -c "error:" ./data/tmp/batch8-validation.log

# Should show: 0
```

---

## Final Validation

After completing all 8 batches, run comprehensive validation:

```bash
# Run the validation script
bash ./scripts/fixes/phase2-safety-monitor/validate-fixes.sh

# Expected results:
# - 0 errors in dev compilation
# - 0 errors in test compilation
# - 0 errors in prod compilation
# - 0 errors in xref analysis
# - All safety tests passing
```

---

## Rollback Procedures

If any batch fails, use the emergency rollback script:

```bash
# List available rollback points
bash ./scripts/fixes/phase2-safety-monitor/emergency-rollback.sh --list

# Rollback to before a specific batch
bash ./scripts/fixes/phase2-safety-monitor/emergency-rollback.sh batch-N-pre

# Example: Rollback to before batch 3
bash ./scripts/fixes/phase2-safety-monitor/emergency-rollback.sh batch-3-pre
```

---

## Success Criteria

✅ **Batch Success**: Error count decreases after each batch
✅ **Final Success**: 0 errors across ALL environments (dev/test/prod)
✅ **Static Analysis**: 0 errors in xref analysis
✅ **Tests**: All safety module tests passing
✅ **Git Tags**: All batch checkpoints created (batch-1-pre/post through batch-8-pre/post)

---

## Next Steps

After Phase 2 completion:
1. Document completion in journal
2. Update todo list to mark Phase 2 complete
3. Proceed to Phase 3: AEE SOPv5.11 + GDE Execution
