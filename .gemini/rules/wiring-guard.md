# Dynamic Wiring Guard Protocol (SC-WIRE)

## SUPREME MANDATE

**ALL Model type changes MUST update `testing/wiring_guard.gleam` FIRST.**

This rule exists because AI code generation (Gemini, Gemini, OpenCode) repeatedly breaks dynamic wiring by adding fields to Model types without updating all downstream constructors.

## The Problem

When an agent adds a field to a Model type (e.g., `SmritiModel`):
1. The `init()` function is updated
2. The `update()` function may be updated
3. But **test files**, **view files**, and **API files** that directly construct the Model are NOT updated
4. This causes **scattered compile errors** across 70+ test files
5. The agent wastes time hunting down every broken constructor

## The Solution

`testing/wiring_guard.gleam` is a **single file** that constructs EVERY Model type.
If any Model changes, **this one file fails to compile FIRST** — not scattered across the codebase.

## STAMP Constraints

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-WIRE-001 | wiring_guard.gleam MUST compile before any test | CRITICAL |
| SC-WIRE-002 | Adding a field to ANY Model type MUST update wiring_guard.gleam in the SAME commit | CRITICAL |
| SC-WIRE-003 | Adding a Msg variant MUST update the corresponding update() function in the SAME commit | CRITICAL |
| SC-WIRE-004 | wiring_guard.verify_all() MUST return the correct connection count | HIGH |
| SC-WIRE-005 | New Lustre pages MUST be added to verify_all_inits() | HIGH |
| SC-WIRE-006 | New Model types with fragile constructors MUST get their own verify_*_wiring() function | HIGH |
| SC-WIRE-007 | Test files MUST use init() constructors, NOT direct Model() constructors | HIGH |

## AOR Rules

| ID | Rule |
|----|------|
| AOR-WIRE-001 | Before modifying ANY type in ui/lustre/*.gleam, READ wiring_guard.gleam first |
| AOR-WIRE-002 | After adding a Model field, update wiring_guard.gleam BEFORE running gleam build |
| AOR-WIRE-003 | After adding a Lustre page, add its init() to verify_all_inits() |
| AOR-WIRE-004 | Run `gleam test` AFTER every Model change — wiring_guard_test catches breaks immediately |
| AOR-WIRE-005 | Use init() functions in tests instead of direct Model constructors |
| AOR-WIRE-006 | When fixing a wiring break, fix wiring_guard.gleam FIRST, then the test files |

## Files

| File | Purpose |
|------|---------|
| `testing/wiring_guard.gleam` | Canonical constructors for ALL Model types (source of truth) |
| `test/wiring_guard_test.gleam` | Tests that verify all connections (9 tests, 71 verified connections) |
| `.gemini/rules/wiring-guard.md` | This rule |

## Verified Connections (71 total)

- 33 page init() functions (every Lustre page)
- 32 AG-UI event constructors (all 32 types)
- 6 critical Model wiring checks (cortex, federation, bridge, config, smriti, telemetry)

## Anti-Pattern Examples

```gleam
// ❌ BAD — Direct Model constructor in test (breaks when fields added)
let model = SmritiModel(catalog_entries: 0, embeddings_stored: 0, ...)

// ✅ GOOD — Use init() (wiring_guard ensures init() is always complete)
let model = smriti.init()

// ❌ BAD — Add field without updating wiring_guard
// Edit smriti.gleam: add `new_field: Int` to SmritiModel
// Forget to update wiring_guard.gleam → breaks silently in test files

// ✅ GOOD — Update wiring_guard FIRST
// 1. Edit smriti.gleam: add `new_field: Int`
// 2. Edit smriti.gleam init(): add `new_field: 0`
// 3. Edit wiring_guard.gleam: verify_smriti_wiring() already calls init() → auto-verified
// 4. gleam build → 0 errors
```
