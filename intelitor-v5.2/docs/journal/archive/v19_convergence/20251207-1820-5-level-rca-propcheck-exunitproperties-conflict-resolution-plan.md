# 5-Level RCA: PropCheck/ExUnitProperties Conflict Resolution Plan

**Date**: 2025-12-07 18:20 CEST
**Analyst**: Claude Code (Opus 4.5)
**Classification**: TPS/STAMP Compliant Analysis
**Status**: COMPREHENSIVE PLAN COMPLETE

---

## Executive Summary

The Indrajaal codebase has **164 test files** that use both PropCheck and ExUnitProperties (StreamData) for dual property-based testing as required by TDG compliance. However, macro naming conflicts between these two libraries cause compilation errors that prevent test execution.

---

## 5-Level Root Cause Analysis

### Level 1: Surface Problem
**Symptom**: Tests fail to compile with error:
```
error: function property/2 imported from both ExUnitProperties and PropCheck.Properties, call is ambiguous
error: function check/2 imported from both PropCheck and ExUnitProperties, call is ambiguous
```

### Level 2: Proximate Cause
- **164 files** use both `use PropCheck` and import/use ExUnitProperties
- Both libraries define `property/2` macro
- PropCheck's `use PropCheck` imports `check/2` from PropCheck.BasicTypes
- ExUnitProperties' `check all` macro requires `check/2` from ExUnitProperties
- Previous fix attempt excluded `check: 2` from ExUnitProperties import, but this breaks `check all` syntax

### Level 3: Contributing Factors
1. **Dual Library Requirement**: TDG compliance mandates both PropCheck AND ExUnitProperties
2. **Macro Naming Convention**: Both libraries chose similar names for core macros
3. **Inconsistent Fix Patterns**: Previous fixes applied `import ExUnitProperties, except: [property: 2, check: 2]` which:
   - Correctly resolves `property/2` conflict
   - **INCORRECTLY** excludes `check/2` which is needed for `check all` syntax
4. **Scale**: 44 files have this incorrect pattern and use `check all`

### Level 4: Systemic Issues
1. **Architecture Decision**: TDG requirement for dual property testing creates inherent conflict
2. **Documentation Gap**: No standardized pattern for dual library usage
3. **Code Generation**: AI-assisted code generation produced inconsistent import patterns
4. **Testing Infrastructure**: No pre-commit validation for import conflicts

### Level 5: Root Cause
**The fundamental conflict is that:**
- `use PropCheck` brings in PropCheck's `check/2` for counter-example validation
- `check all` syntax requires ExUnitProperties' `check/2` macro for StreamData generators
- These are **different functions with the same name serving different purposes**

---

## Research Findings

### Sources Consulted:
1. [PropCheck Documentation](https://hexdocs.pm/propcheck/PropCheck.Properties.html) - PropCheck v1.5.0
2. [ExUnitProperties Documentation](https://hexdocs.pm/stream_data/ExUnitProperties.html) - StreamData v1.2.0
3. [Elixir Import/Alias Documentation](https://hexdocs.pm/elixir/alias-require-and-import.html)
4. [Elixir Forum - Import and macro conflict](https://elixirforum.com/t/import-and-macro-conflict/21127)
5. [StreamData GitHub](https://github.com/whatyouhide/stream_data)
6. [PropCheck GitHub](https://github.com/alfert/propcheck)

### Key Finding from Documentation:
> "The `property/3` macro [in ExUnitProperties] defines property tests and automatically imports testing facilities... imports all functions from StreamData module [and] imports `check/2` for property assertions."

> "PropCheck... provides the macros and functions for property based testing using PropEr as base implementation."

---

## Solution Architecture

### Strategy: Fully Qualified Macro Usage

Since both libraries define conflicting macros, the safest approach is:

1. **For `property` macro**: Use `ExUnitProperties.property` when StreamData generators are used inside
2. **For `check all` macro**: Use `ExUnitProperties.check all` explicitly
3. **For PropCheck properties**: Use PropCheck's `property` macro directly (via `use PropCheck`)

### Three-Tier Fix Approach

#### Tier 1: Files using `check all` with excluded import (44 files)
**Current (BROKEN):**
```elixir
use PropCheck
import ExUnitProperties, except: [property: 2, check: 2]

# This fails - check is excluded
check all x <- integer() do
  assert x == x
end
```

**Fixed:**
```elixir
use PropCheck
import ExUnitProperties, except: [property: 2, check: 2]

# Use fully qualified - ExUnitProperties.check all
ExUnitProperties.check all x <- StreamData.integer() do
  assert x == x
end
```

#### Tier 2: Files using `ExUnitProperties.property` (57 files - already correct)
These use fully qualified names and should work.

#### Tier 3: Files with other undefined variable issues
These are separate bugs (underscore-prefixed variables used) that need individual fixes.

---

## Comprehensive Fix Plan

### Phase 1: Prepare Environment
```bash
# Ensure clean compilation state
mix clean
rm -rf _build/test

# Verify dependencies
mix deps.get
```

### Phase 2: Apply Batch Fix for check all Conflict (44 files)
Replace unqualified `check all` with `ExUnitProperties.check all` in files that exclude check:

```bash
# Find and fix files
grep -rl "check all" test/ | xargs grep -l "except: \[property: 2, check: 2\]" | while read file; do
  # Replace "check all" with "ExUnitProperties.check all" when not already qualified
  sed -i 's/^\(\s*\)check all /\1ExUnitProperties.check all /g' "$file"
  # Also handle inline check all
  sed -i 's/\([^.]\)check all /\1ExUnitProperties.check all /g' "$file"
done
```

### Phase 3: Fix Undefined Variable Issues
Files with `__variable` patterns being used (underscore prefix indicates unused):

```bash
# Find and fix underscore-prefixed variables that are actually used
grep -rl "__[a-z]" test/ | xargs grep -l "is used after being set" 2>/dev/null | head -20
# Manual fix: remove underscore prefix from used variables
```

### Phase 4: Fix `context` Undefined Variable Issues
Multiple test files reference `context` variable from setup without proper extraction:

```bash
# Find files with undefined context
grep -rl "undefined variable.*context" test/
# Fix: Ensure setup blocks return context properly
```

### Phase 5: Validate Compilation
```bash
NO_TIMEOUT=true PATIENT_MODE=enabled MIX_ENV=test mix compile 2>&1 | tee ./data/tmp/compile-after-fix.log
# Verify: grep -c "error:" ./data/tmp/compile-after-fix.log should be 0
```

### Phase 6: Run Test Suite with Exclusions
```bash
# Run tests excluding problematic categories first
NO_TIMEOUT=true PATIENT_MODE=enabled MIX_ENV=test mix test \
  --exclude advanced \
  --exclude wallaby \
  --exclude demo \
  --exclude integration \
  --seed 12345 \
  2>&1 | tee ./data/tmp/test-run-1.log
```

### Phase 7: Incremental Test Execution
Run tests domain by domain to identify remaining issues:

```bash
# Core domains first
for domain in observability analytics access_control accounts; do
  echo "=== Testing $domain ==="
  NO_TIMEOUT=true PATIENT_MODE=enabled MIX_ENV=test mix test test/indrajaal/$domain \
    --max-failures 10 \
    --seed 12345 \
    2>&1 | tee -a ./data/tmp/test-domain-$domain.log
done
```

---

## Expected Outcomes

| Metric | Before Fix | After Fix |
|--------|------------|-----------|
| Compilation Errors | ~50+ | 0 |
| Files with check/property conflict | 44 | 0 |
| Test Files Runnable | ~40% | 95%+ |
| TDG Compliance | Partial | Full |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Sed replacement breaks valid code | Low | High | Backup files first, careful regex |
| Some tests still fail after fix | Medium | Low | Expected for TDG (tests before implementation) |
| PropCheck counter-example storage affected | Low | Medium | Validate PropCheck functionality separately |

---

## Validation Checklist

- [ ] All test files compile without errors
- [ ] PropCheck `forall` properties execute correctly
- [ ] ExUnitProperties `check all` properties execute correctly
- [ ] No macro ambiguity errors remain
- [ ] TDG compliance maintained (both PropCheck AND ExUnitProperties used)
- [ ] Patient mode test execution completes

---

## STAMP Safety Compliance

This fix maintains compliance with:
- **SC-VAL-003**: 100% consensus across validation methods (no false positives from macro conflicts)
- **SC-CMP-025**: Zero compilation errors required
- **TDG Axiom 4**: Dual property testing maintained (PropCheck + ExUnitProperties)

---

## Recommended Execution Command

```bash
# Complete fix and test execution sequence
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true \
  ELIXIR_ERL_OPTIONS="+S 16" \
  bash -c '
    # Phase 2: Fix check all conflicts
    grep -rl "check all" test/ | xargs grep -l "except: \[property: 2, check: 2\]" | while read file; do
      sed -i "s/^\([[:space:]]*\)check all /\1ExUnitProperties.check all /g" "$file"
    done

    # Phase 5: Validate compilation
    mix compile 2>&1 | tee ./data/tmp/compile-after-fix.log

    # Phase 6: Run tests
    mix test --exclude advanced --exclude wallaby --exclude demo --exclude integration --seed 12345 2>&1 | tee ./data/tmp/test-run-final.log
  '
```

---

## Document Metadata

- **Analysis Method**: 5-Level RCA (TPS Methodology)
- **Sources**: 6 external references + codebase analysis
- **Files Analyzed**: 164 dual-library test files
- **Conflict Patterns Identified**: 3 (property/2, check/2, undefined variables)
- **Fix Coverage**: 44 files requiring batch fix + manual fixes for edge cases
