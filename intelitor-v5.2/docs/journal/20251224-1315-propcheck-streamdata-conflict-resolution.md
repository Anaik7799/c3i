# PropCheck/StreamData Generator Conflict Resolution (EP-GEN-014)

**Date**: 2025-12-24 13:15 CEST
**Author**: Agent System
**Status**: DOCUMENTED
**Classification**: Error Pattern / Compile-Time Resolution

---

## Error Pattern Identification

| Field | Value |
|-------|-------|
| **Pattern ID** | EP-GEN-014 |
| **Category** | Generator Import Conflict |
| **Severity** | COMPILE-TIME ERROR |
| **Frameworks Affected** | PropCheck, ExUnitProperties/StreamData |
| **Related Axiom** | $\Omega_4$ (Test-Driven Gen - Dual property tests mandatory) |
| **Related Constraints** | SC-PROP-021, SC-PROP-022, SC-PROP-023, SC-PROP-024 |

---

## Detection Regex

```regex
function (map|list|atom|any|binary|integer|float|number|boolean|tuple)/\d+ imported from both StreamData and PropCheck\.BasicTypes
```

### Example Error Message

```
== Compilation error in file test/indrajaal/domain/example_property_test.exs ==
** (CompileError) test/indrajaal/domain/example_property_test.exs:15: function map/2 imported from both StreamData and PropCheck.BasicTypes, call is ambiguous
    (elixir 1.18.0) src/elixir_dispatch.erl:281: :elixir_dispatch.expand_import/6
```

---

## Root Cause Analysis (5-Level Why)

| Level | Question | Answer |
|-------|----------|--------|
| **L1** | Why does the error occur? | Both PropCheck and StreamData export identical function names (`map`, `list`, `atom`, `integer`, etc.) |
| **L2** | Why is there a conflict? | The test module imports both libraries without explicit namespace disambiguation |
| **L3** | Why are both imported? | Test file implements dual property testing as mandated by SC-PROP-021/022 |
| **L4** | Why is dual testing required? | SOPv5.11 requires PropCheck + ExUnitProperties for comprehensive safety validation ($\Omega_4$) |
| **L5** | Why wasn't this resolved earlier? | Generator naming collision not explicitly addressed in TDG phase specification |

### Underlying Technical Cause

Elixir's import system creates ambiguity when two modules export functions with identical names and arities. PropCheck.BasicTypes and StreamData both provide:

- `map/2` - Generate maps with key/value generators
- `list/1` - Generate lists from element generator
- `atom/0` - Generate random atoms
- `integer/0`, `integer/1` - Generate integers
- `binary/0`, `binary/1` - Generate binaries
- `tuple/1` - Generate tuples
- `any/0` - Generate any term
- `boolean/0` - Generate booleans
- `float/0` - Generate floats

---

## Resolution Protocol

### Step 1: Add Explicit Aliases

Add the following aliases at the top of the test module, after `use` declarations:

```elixir
defmodule Intelitor.Domain.ExamplePropertyTest do
  use ExUnit.Case, async: true
  use PropCheck
  use ExUnitProperties

  # MANDATORY: Disambiguate generators (EP-GEN-014 resolution)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
```

### Step 2: PropCheck `forall` Blocks

Use `PC.` prefix for ALL generators within PropCheck's `forall` macro:

```elixir
# CORRECT: PropCheck generators with PC. prefix
property "validates configuration structure" do
  forall {data, config} <- {PC.map(PC.atom(), PC.any()), PC.list(PC.binary())} do
    assert is_map(data)
    assert is_list(config)
  end
end

property "handles integer ranges" do
  forall value <- PC.integer(1, 100) do
    assert value >= 1 and value <= 100
  end
end
```

### Step 3: ExUnitProperties `check all` Blocks

Use `SD.` prefix for ALL generators within ExUnitProperties' `check all` macro:

```elixir
# CORRECT: StreamData generators with SD. prefix
property "validates input processing" do
  check all(
    value <- SD.integer(1..100),
    name <- SD.string(:alphanumeric, min_length: 1)
  ) do
    assert is_integer(value)
    assert is_binary(name)
  end
end

property "handles list generation" do
  check all(items <- SD.list_of(SD.integer(), min_length: 1)) do
    assert length(items) >= 1
  end
end
```

### Step 4: Verify Compilation

```bash
# Run compilation check
mix compile 2>&1 | grep -i "ambiguous\|imported from both"

# Expected output: (empty - no conflicts)
```

---

## STAMP Safety Constraints

### New Constraints Added

| ID | Constraint | Enforcement |
|----|------------|-------------|
| **SC-PROP-023** | PropCheck generators MUST use `PC.` prefix in dual-testing modules | Compile-time, Code Review |
| **SC-PROP-024** | StreamData generators MUST use `SD.` prefix in dual-testing modules | Compile-time, Code Review |

### Related Existing Constraints

| ID | Constraint |
|----|------------|
| SC-PROP-021 | No raw `utf8()` generator usage |
| SC-PROP-022 | Use `let/vector/range` patterns |

---

## AOR Compliance

### New Rule

| ID | Rule | Scope |
|----|------|-------|
| **AOR-CODE-014** | All new test files using dual property testing MUST include PC/SD aliases | All test modules with both PropCheck and ExUnitProperties |

### Enforcement Points

1. **Pre-commit Hook**: Verify alias presence in dual-testing files
2. **CI Pipeline**: Compile check catches ambiguity errors
3. **Code Review**: Mandatory checklist item for property tests

---

## Prevention Checklist

Before submitting any property test file:

- [ ] Verify `alias PropCheck.BasicTypes, as: PC` exists if using PropCheck
- [ ] Verify `alias StreamData, as: SD` exists if using ExUnitProperties
- [ ] All `forall` blocks use `PC.` prefixed generators
- [ ] All `check all` blocks use `SD.` prefixed generators
- [ ] Run `mix compile` and verify zero ambiguity errors
- [ ] Run `mix format` to ensure consistent formatting
- [ ] Run specific test file: `mix test path/to/test.exs`

---

## Quick Reference Card

```elixir
# ============================================
# EP-GEN-014 RESOLUTION TEMPLATE
# ============================================

defmodule MyApp.Domain.FeaturePropertyTest do
  use ExUnit.Case, async: true
  use PropCheck
  use ExUnitProperties

  # MANDATORY ALIASES (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # PropCheck property (uses PC.)
  property "propcheck example" do
    forall x <- PC.integer() do
      assert is_integer(x)
    end
  end

  # ExUnitProperties property (uses SD.)
  property "streamdata example" do
    check all(x <- SD.integer()) do
      assert is_integer(x)
    end
  end
end
```

---

## Common Generator Mappings

| Generator | PropCheck (PC.) | StreamData (SD.) |
|-----------|-----------------|------------------|
| Integer | `PC.integer()`, `PC.integer(min, max)` | `SD.integer()`, `SD.integer(range)` |
| Float | `PC.float()` | `SD.float()` |
| Binary | `PC.binary()` | `SD.binary()` |
| String | `PC.utf8()` | `SD.string(:alphanumeric)` |
| Atom | `PC.atom()` | `SD.atom(:alphanumeric)` |
| List | `PC.list(gen)` | `SD.list_of(gen)` |
| Map | `PC.map(k_gen, v_gen)` | `SD.map_of(k_gen, v_gen)` |
| Tuple | `PC.tuple([g1, g2])` | `SD.tuple({g1, g2})` |
| Boolean | `PC.boolean()` | `SD.boolean()` |
| Any | `PC.any()` | `SD.term()` |

---

## Metrics & Tracking

| Metric | Target | Current |
|--------|--------|---------|
| Files with EP-GEN-014 resolved | 100% | Tracking |
| New files with correct aliases | 100% | Enforced |
| CI detection rate | 100% | Compile-time |

---

## Related Documentation

- SOPv5.11 Section 4: Test-Driven Generation
- CLAUDE.md Section 5.0: SC-PROP constraints
- GEMINI.md Section 7.0: Code Patterns & Rules
- Journal: 20251218-1600-formal-verification-test-strategy.md

---

## Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2025-12-24 | 1.0.0 | Initial documentation of EP-GEN-014 |
