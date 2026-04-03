# 20260322-1330 — GitIntelligence Scope Alignment Complete

## Context
- Branch: main
- Parent: 20260322-1200 (GitIntelligence project complete)
- Task: Fix FS0039 compilation order error + expand scope compliance from 35.9% to 97.2%

## Summary

Fixed the F# compilation order error (FS0039) in Parser.fs by moving `mapHistoricalScope` before its point of use in `parseIcpSubject`. Expanded scope mappings from ~25 to 80+ entries covering all 130 unique scopes from 1-year git history analysis. Integrated `mapHistoricalScope` as a fallback in both `parseIcpSubject` and `computeScopeCompliance`, raising scope compliance from 35.9% to 97.2%.

## Technical Details

### FS0039 Fix
F# compiles functions in declaration order within a file. `mapHistoricalScope` was defined at line ~427 but referenced at lines 153 and 167 inside `parseIcpSubject`. Moved the function to line 135, between `classifyStyle` and `parseIcpSubject`.

### Scope Mapping Expansion
80+ mappings organized by target scope:
- **Core**: sprint-*, config, devenv, nix, architecture, singularity, etc.
- **App**: ash, phoenix, liveview, heex, webui, catalog
- **Mesh**: infrastructure, podman, sil4, sil6, biomorphic, fractal
- **Cepaf**: fsharp, cafe
- **Zenoh**: nif, rustler, ffi
- **Sentinel/Immune/Smriti/Prajna/Cortex/Plan/Obs/Vsm/Math/Fed/Formal/Test/Sync**: domain-specific mappings

### Remaining Invalid Scopes (9)
`c0`, `c1`, `g1-g2`, `g3`, `g4`, `ignorer`, `v21`, `warnings`, `zero-defect` — edge cases from legacy commits with no natural ICP scope mapping.

### Test Update
Test `invalid scopes detected` updated: `"sprint-54"` → `"xyzzy-nonsense"` since sprint-* now correctly maps to Core scope.

### Files Modified
| File | Lines Changed | Purpose |
|------|--------------|---------|
| `Parser.fs` | +84/-84 (moved) | Move mapHistoricalScope before parseIcpSubject |
| `GitIntelligenceTests.fs` | 3 lines | Update test to use genuinely invalid scope |

## STAMP Compliance
- SC-FUNC-001: System compiles at all times — 0 errors, 0 warnings
- SC-FSH-012: Domain patterns exhaustive — 80+ scope mappings
- SC-CHG-001: Structured change note (this journal)

## KPIs
- Build: 0 errors, 0 warnings
- Tests: 77/77 pass (0 failures)
- Scope compliance: 35.9% → **97.2%** (+170% relative improvement)
- GHS: 0.6709 (scope component now near-maximum)
- Invalid scopes: 130 → 9 (93% reduction)
- CLI commands: 6/6 verified (analyze, health, validate, classify, generate, guardrails)

## Next Steps
- Monitor GHS over future commits (target: >0.80 with consistent ICP adoption)
- Consider pre-commit hook integration using `git-intel validate`
- Zenoh publishing of git health metrics to `indrajaal/git/health` (lower priority)
