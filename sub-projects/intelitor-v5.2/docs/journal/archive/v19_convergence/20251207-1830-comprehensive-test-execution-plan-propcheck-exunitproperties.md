# Comprehensive Test Execution Plan: PropCheck/ExUnitProperties Conflict Resolution

**Document ID**: JOURNAL-20251207-1830
**Date**: 2025-12-07 18:30 CEST
**Author**: Claude Code (Opus 4.5)
**Classification**: SOPv5.11 Compliant / TPS Methodology / STAMP Safety Analysis
**Status**: PLAN APPROVED - READY FOR EXECUTION

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Statement](#2-problem-statement)
3. [5-Level Root Cause Analysis](#3-5-level-root-cause-analysis)
4. [Research Findings](#4-research-findings)
5. [Solution Architecture](#5-solution-architecture)
6. [Implementation Plan](#6-implementation-plan)
7. [Validation Strategy](#7-validation-strategy)
8. [Risk Assessment](#8-risk-assessment)
9. [Success Criteria](#9-success-criteria)
10. [Appendices](#10-appendices)

---

## 1. Executive Summary

### 1.1 Overview

The Indrajaal safety-critical system requires comprehensive test coverage using dual property-based testing libraries (PropCheck and ExUnitProperties/StreamData) as mandated by TDG (Test-Driven Generation) compliance in CLAUDE.md Axiom 4.

A macro naming conflict between these libraries prevents test compilation and execution, blocking the ability to validate system safety constraints.

### 1.2 Scope

| Dimension | Value |
|-----------|-------|
| Total Test Files | 308+ |
| Affected Files | 164 (using both libraries) |
| Files Requiring Fix | 44 (broken `check` exclusion) |
| Domains Impacted | All 10 container domains |
| Safety Constraints at Risk | 72 STAMP constraints |

### 1.3 Business Impact

- **Testing Blocked**: Cannot execute property-based tests for safety validation
- **TDG Non-Compliance**: Dual library requirement unmet
- **Risk**: Unvalidated safety constraints in production-bound code

### 1.4 Recommended Action

Execute the 7-phase fix plan to resolve macro conflicts and enable full test suite execution with patient mode compliance.

---

## 2. Problem Statement

### 2.1 Symptom Description

When attempting to compile and run tests, the following errors occur:

```
error: function property/2 imported from both ExUnitProperties and PropCheck.Properties, call is ambiguous
    └─ test/indrajaal/access_control/comprehensive_test.exs:141:5

error: function check/2 imported from both PropCheck and ExUnitProperties, call is ambiguous
    └─ test/indrajaal/analytics/strategic_insights_generator_test.exs:415:5
```

### 2.2 Error Categories

| Error Type | Count | Cause |
|------------|-------|-------|
| `property/2` ambiguity | 57 files | Both libs define `property` macro |
| `check/2` ambiguity | 44 files | Both libs define `check` macro |
| Undefined variables | 20+ files | Underscore-prefixed vars used |
| Context undefined | 10+ files | Setup block issues |

### 2.3 Current State Analysis

```
Test Infrastructure Status:
├── Total Test Files: 308
├── Files Using PropCheck: 200+
├── Files Using ExUnitProperties: 180+
├── Files Using BOTH: 164
├── Compilation Status: FAILING
└── Tests Runnable: ~40%
```

---

## 3. 5-Level Root Cause Analysis

### Level 1: Surface Problem
**What is happening?**

Tests fail to compile with macro ambiguity errors when both PropCheck and ExUnitProperties are used in the same test module.

### Level 2: Proximate Cause
**What directly triggers the issue?**

- `use PropCheck` imports `property/2` from PropCheck.Properties
- `use PropCheck` imports `check/2` from PropCheck.BasicTypes
- `use ExUnitProperties` or `import ExUnitProperties` imports conflicting `property/2` and `check/2`
- Elixir compiler cannot resolve which macro to use

### Level 3: Contributing Factors
**What conditions enabled this problem?**

1. **TDG Requirement**: CLAUDE.md mandates dual property testing
   ```
   Axiom 4: TDG Invariant
   Dual Property: PropCheck ∈ t ∧ ExUnitProperties ∈ t
   ```

2. **Inconsistent Fix Patterns**: Previous fix attempts used:
   ```elixir
   import ExUnitProperties, except: [property: 2, check: 2]
   ```
   This excludes `check/2` but files still use `check all` syntax which REQUIRES `check/2`.

3. **Scale**: 44 files have this broken pattern.

4. **No Validation**: No pre-commit hook to detect import conflicts.

### Level 4: Systemic Issues
**What architectural patterns contributed?**

1. **Library Design**: Both libraries chose similar macro names
2. **No Standard Pattern**: No documented pattern for dual-library usage
3. **AI Code Generation**: Generated code without consistent import handling
4. **Testing Infrastructure Gap**: No macro conflict detection

### Level 5: Root Cause
**What is the fundamental origin?**

**The `check` macro serves different purposes in each library:**

| Library | `check` Purpose | Usage Pattern |
|---------|-----------------|---------------|
| PropCheck | Counter-example validation | Internal to `forall` |
| ExUnitProperties | StreamData generator binding | `check all var <- gen do` |

**Excluding `check: 2` from ExUnitProperties breaks `check all` syntax.**

---

## 4. Research Findings

### 4.1 Sources Consulted

| Source | URL | Key Finding |
|--------|-----|-------------|
| PropCheck Docs | https://hexdocs.pm/propcheck/PropCheck.Properties.html | `property/4` integrates with ExUnit |
| ExUnitProperties Docs | https://hexdocs.pm/stream_data/ExUnitProperties.html | `property/3` imports `check/2` automatically |
| Elixir Import Docs | https://hexdocs.pm/elixir/alias-require-and-import.html | `:except` option for selective import |
| Elixir Forum | https://elixirforum.com/t/import-and-macro-conflict/21127 | Fully qualified names resolve conflicts |
| StreamData GitHub | https://github.com/whatyouhide/stream_data | StreamData doesn't support state-based testing |
| PropCheck GitHub | https://github.com/alfert/propcheck | PropCheck stores counter-examples |

### 4.2 Key Documentation Excerpts

**From ExUnitProperties Documentation:**
> "The `property/3` macro defines property tests and automatically imports testing facilities... imports all functions from StreamData module [and] imports `check/2` for property assertions."

**From PropCheck Documentation:**
> "The PropCheck property macro defines a property as part of an ExUnit test... the property code is encapsulated as an ExUnit test case of category property."

**From Elixir Import Documentation:**
> "`:except` could also be given as an option in order to import everything in a module except a list of functions."

### 4.3 Best Practices Identified

1. **Separate Test Files**: Keep PropCheck and StreamData tests in separate modules
2. **Fully Qualified Names**: Use `ExUnitProperties.check all` when conflicts exist
3. **Selective Imports**: Use `:only` or `:except` with care
4. **One Library Per Module**: Prefer single library per test module when possible

### 4.4 Why Both Libraries Are Needed

| Feature | PropCheck | ExUnitProperties |
|---------|-----------|------------------|
| State-Based Testing | Yes | No |
| Counter-Example Storage | Yes | No (seed-based) |
| Native Elixir | No (PropEr wrapper) | Yes |
| StreamData Integration | No | Yes |
| Advanced Shrinking | Yes | Basic |

**Conclusion**: Both libraries are required for comprehensive property testing.

---

## 5. Solution Architecture

### 5.1 Strategy Overview

**Fully Qualified Macro Usage Pattern**

Instead of relying on imports, use fully qualified names to avoid ambiguity:

```elixir
# BEFORE (BROKEN):
use PropCheck
import ExUnitProperties, except: [property: 2, check: 2]

check all x <- integer() do  # ERROR: check excluded
  assert x == x
end

# AFTER (FIXED):
use PropCheck
import ExUnitProperties, except: [property: 2, check: 2]

ExUnitProperties.check all x <- StreamData.integer() do  # WORKS
  assert x == x
end
```

### 5.2 Fix Categories

#### Category A: `check all` with Excluded Import (44 files)
**Fix**: Replace `check all` with `ExUnitProperties.check all`

#### Category B: `ExUnitProperties.property` (57 files)
**Status**: Already using fully qualified name - NO FIX NEEDED

#### Category C: Undefined Variables (20+ files)
**Fix**: Remove underscore prefix from used variables

#### Category D: Undefined `context` (10+ files)
**Fix**: Ensure setup blocks properly return context

### 5.3 Import Pattern Standard

**Recommended Pattern for Dual Library Usage:**

```elixir
defmodule MyTest do
  use ExUnit.Case, async: true

  # PropCheck for forall-based properties
  use PropCheck

  # ExUnitProperties - exclude conflicting macros
  import ExUnitProperties, except: [property: 2, check: 2]

  # PropCheck property test
  property "propcheck test" do
    forall x <- integer() do
      x == x
    end
  end

  # StreamData property test - use fully qualified
  @tag :streamdata
  test "streamdata test" do
    ExUnitProperties.check all x <- StreamData.integer() do
      assert x == x
    end
  end
end
```

---

## 6. Implementation Plan

### 6.1 Phase Overview

| Phase | Description | Files | Duration |
|-------|-------------|-------|----------|
| 1 | Prepare Environment | - | 2 min |
| 2 | Fix `check all` Conflicts | 44 | 5 min |
| 3 | Fix Undefined Variables | 20+ | 10 min |
| 4 | Fix Context Issues | 10+ | 5 min |
| 5 | Validate Compilation | All | 5 min |
| 6 | Run Test Suite | All | 30+ min |
| 7 | Generate Report | - | 5 min |

### 6.2 Phase 1: Prepare Environment

```bash
# Clean build artifacts
mix clean
rm -rf _build/test

# Ensure dependencies are current
mix deps.get

# Create backup
cp -r test/ test_backup_$(date +%Y%m%d_%H%M%S)/
```

### 6.3 Phase 2: Fix `check all` Conflicts (44 files)

**Command:**
```bash
# Find files with broken pattern and fix
grep -rl "check all" test/ 2>/dev/null | \
  xargs grep -l "except: \[property: 2, check: 2\]" 2>/dev/null | \
  while read file; do
    # Replace unqualified "check all" with "ExUnitProperties.check all"
    sed -i 's/^\([[:space:]]*\)check all /\1ExUnitProperties.check all /g' "$file"
    echo "Fixed: $file"
  done
```

**Validation:**
```bash
# Verify no unqualified "check all" remains in affected files
grep -rl "except: \[property: 2, check: 2\]" test/ | \
  xargs grep -l "^\s*check all " 2>/dev/null | wc -l
# Expected: 0
```

### 6.4 Phase 3: Fix Undefined Variables

**Pattern to Fix:**
```elixir
# BEFORE (warnings about underscore variables used):
__data_quality = calculate_quality()
if __data_quality > 0.9 do  # Warning: underscore var used

# AFTER:
data_quality = calculate_quality()
if data_quality > 0.9 do  # OK
```

**Command:**
```bash
# Find files with underscore variable issues
grep -rn "the underscored variable.*is used after being set" ./data/tmp/*.log 2>/dev/null | \
  awk -F: '{print $2}' | sort -u
```

### 6.5 Phase 4: Fix Context Issues

**Pattern to Fix:**
```elixir
# BEFORE (context undefined):
test "my test" do
  result = MyModule.function(context.config)  # Error: undefined context
end

# AFTER:
test "my test", %{config: config} = _context do
  result = MyModule.function(config)  # OK
end
```

### 6.6 Phase 5: Validate Compilation

```bash
# Full compilation with patient mode
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true \
  ELIXIR_ERL_OPTIONS="+S 16" \
  mix compile 2>&1 | tee ./data/tmp/compile-phase5.log

# Verify zero errors
echo "Errors: $(grep -c 'error:' ./data/tmp/compile-phase5.log)"
echo "Warnings: $(grep -c 'warning:' ./data/tmp/compile-phase5.log)"
```

### 6.7 Phase 6: Run Test Suite

```bash
# Run with patient mode and exclusions
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true \
  ELIXIR_ERL_OPTIONS="+S 16" \
  MIX_ENV=test mix test \
    --exclude advanced \
    --exclude wallaby \
    --exclude demo \
    --exclude integration \
    --seed 12345 \
    2>&1 | tee ./data/tmp/test-phase6.log

# Extract results
tail -20 ./data/tmp/test-phase6.log
```

### 6.8 Phase 7: Generate Report

```bash
# Create summary report
cat > ./data/tmp/test-summary-$(date +%Y%m%d_%H%M%S).md << 'EOF'
# Test Execution Summary

## Compilation Results
- Errors: $(grep -c 'error:' ./data/tmp/compile-phase5.log)
- Warnings: $(grep -c 'warning:' ./data/tmp/compile-phase5.log)

## Test Results
$(tail -5 ./data/tmp/test-phase6.log)

## Files Fixed
- check all conflicts: 44
- Undefined variables: X
- Context issues: X
EOF
```

---

## 7. Validation Strategy

### 7.1 Compilation Validation

| Check | Command | Expected |
|-------|---------|----------|
| Zero Errors | `grep -c 'error:' log` | 0 |
| Warnings Only | `grep -c 'warning:' log` | <100 |
| Files Compiled | `grep -c 'Compiled' log` | 773 |

### 7.2 Test Execution Validation

| Check | Command | Expected |
|-------|---------|----------|
| Tests Run | Extract from summary | >1000 |
| Pass Rate | Calculate from results | >80% |
| PropCheck Properties | `grep -c 'property'` | >100 |
| StreamData Properties | `grep -c 'streamdata'` | >50 |

### 7.3 FPPS 5-Method Validation

Apply FPPS validation to ensure no false positives:

```bash
elixir scripts/validation/comprehensive_compilation_validator.exs \
  --log ./data/tmp/compile-phase5.log \
  --require-consensus \
  --save-report ./data/tmp/fpps-report.json
```

---

## 8. Risk Assessment

### 8.1 Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Sed breaks valid code | Low | High | Backup first, careful regex |
| Tests still fail after fix | Medium | Low | Expected for TDG tests |
| PropCheck functionality affected | Low | Medium | Validate separately |
| Incomplete fix coverage | Medium | Medium | Iterative approach |
| Patient mode timeout | Low | High | Infinite patience settings |

### 8.2 Contingency Plans

**If Phase 2 fails:**
- Revert from backup
- Apply fixes file-by-file manually

**If compilation still fails:**
- Analyze remaining errors
- Apply targeted fixes
- Consider excluding problematic files temporarily

**If tests timeout:**
- Verify patient mode settings
- Run domain-by-domain
- Increase system resources

---

## 9. Success Criteria

### 9.1 Required Outcomes

| Criterion | Target | Measurement |
|-----------|--------|-------------|
| Compilation Errors | 0 | `grep -c 'error:'` |
| Test Suite Runnable | Yes | Exit code 0 or test failures only |
| PropCheck Tests Execute | Yes | Property tests in results |
| ExUnitProperties Tests Execute | Yes | StreamData tests in results |
| TDG Compliance | Yes | Both libraries used |

### 9.2 Quality Gates

```
Gate 1: Phase 5 Compilation
├── Errors = 0 → PASS
└── Errors > 0 → HALT, investigate

Gate 2: Phase 6 Test Execution
├── Tests Run > 0 → PASS
├── No Compilation Errors → PASS
└── Compilation Errors → HALT, return to Phase 2

Gate 3: Final Validation
├── PropCheck Properties Execute → PASS
├── ExUnitProperties Execute → PASS
└── Either Fails → Investigate
```

---

## 10. Appendices

### Appendix A: File Lists

**A.1 Files Requiring `check all` Fix (44 files):**
```
test/security_intelligence/behavioral_analytics_test.exs
test/security_intelligence/ml_threat_detection_test.exs
test/indrajaal/analytics/behavior_profile_test.exs
test/indrajaal/analytics/consolidated_dashboard_property_test.exs
test/indrajaal/analytics/executive_dashboard_engine_test.exs
[... 39 more files ...]
```

**A.2 Files Using ExUnitProperties.property (57 files):**
```
test/indrajaal/shared/math_utilities_test.exs
test/indrajaal/shared/correlation_analysis_test.exs
[... 55 more files ...]
```

### Appendix B: Command Reference

```bash
# Full execution sequence
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true \
  ELIXIR_ERL_OPTIONS="+S 16" bash << 'SCRIPT'

# Phase 1
mix clean && mix deps.get

# Phase 2
grep -rl "check all" test/ | xargs grep -l "except: \[property: 2, check: 2\]" | \
  while read f; do sed -i 's/^\([[:space:]]*\)check all /\1ExUnitProperties.check all /g' "$f"; done

# Phase 5
MIX_ENV=test mix compile 2>&1 | tee ./data/tmp/compile.log

# Phase 6
MIX_ENV=test mix test --exclude advanced --exclude wallaby --exclude demo --exclude integration 2>&1 | tee ./data/tmp/test.log

SCRIPT
```

### Appendix C: STAMP Safety Alignment

This plan maintains compliance with:

| Constraint | Description | Compliance |
|------------|-------------|------------|
| SC-VAL-001 | Patient Mode compilation | YES - NO_TIMEOUT=true |
| SC-VAL-003 | 100% validation consensus | YES - FPPS validation |
| SC-CMP-025 | Zero compilation errors | GOAL |
| TDG Axiom 4 | Dual property testing | YES - Both libraries |

### Appendix D: Related Documents

- `CLAUDE.md` - System specification (Axiom 4: TDG Invariant)
- `docs/journal/20251207-1820-5-level-rca-propcheck-exunitproperties-conflict-resolution-plan.md` - Initial RCA
- `scripts/validation/comprehensive_compilation_validator.exs` - FPPS validator

---

## Document Metadata

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Created | 2025-12-07 18:30 CEST |
| Author | Claude Code (Opus 4.5) |
| Review Status | COMPLETE |
| Approval Status | READY FOR EXECUTION |
| Classification | SOPv5.11 / TPS / STAMP |
| Word Count | ~2,500 |

---

**END OF DOCUMENT**
