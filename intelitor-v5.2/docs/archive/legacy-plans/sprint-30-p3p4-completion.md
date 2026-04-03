# Sprint 30 P3/P4 Completion Plan - 100% Goal Achievement
**Version**: 1.0.0 | **Date**: 2026-01-02 | **Target**: v21.1.0 Release

## Executive Summary
Complete Sprint 30 P3 (Coverage & Verification) and P4 (Quality Gate & Merge) with maximum parallelization across all available services.

## Current Status (from quality gate run)
- **Format**: FAILING - 5 LiveView files need formatting
- **Tests**: FAILING - StreamData alias error + @describetag errors
- **Credo**: INTERRUPTED - needs re-run after fixes

## Phase 1: Critical Fixes (Sequential - Blocks Everything)
**Duration**: ~5 minutes | **Parallelization**: None (fixes block subsequent phases)

### 1.1 Format All Code
```bash
SKIP_ZENOH_NIF=0 MIX_ENV=test mix format
```
Files to format:
- lib/indrajaal_web/live/prajna/devices_live.ex
- lib/indrajaal_web/live/prajna/video_live.ex
- lib/indrajaal_web/live/prajna/analytics_live.ex
- lib/indrajaal_web/live/prajna/compliance_live.ex
- lib/indrajaal_web/live/prajna/access_control_live.ex

### 1.2 Fix StreamData Alias Error
**File**: test/channels/alarm_channel_test.exs:575
**Error**: `StreamData.SD.member_of/1` is undefined
**Fix**: Change `StreamData.SD.member_of` to `SD.member_of` (alias already defined)

### 1.3 Fix @describetag Errors
**File**: test/observability/tdg/signoz_integration_test.exs
**Error**: `@describetag must be set inside describe/2 blocks`
**Fix**: Move @describetag inside describe blocks or change to @tag

### 1.4 Fix Unused Variable Warning
**File**: test/observability/tdg/signoz_integration_test.exs:54
**Error**: `variable "spans" is unused`
**Fix**: Prefix with underscore: `_spans`

## Phase 2: Parallel Quality Gates (Maximum Parallelization)
**Duration**: ~10 minutes | **Parallelization**: 6 agents in parallel

After Phase 1 fixes, run ALL quality gates in parallel:

| Agent | Task | Command | STAMP |
|-------|------|---------|-------|
| Agent-1 | Full Test Suite | `mix test --cover` | SC-TEST-001 |
| Agent-2 | Credo Strict | `mix credo --strict` | SC-CREDO-001 |
| Agent-3 | Sobelow Security | `mix sobelow --exit` | SC-SEC-044 |
| Agent-4 | Dialyzer Types | `mix dialyzer` | SC-TYPE-001 |
| Agent-5 | Compile Strict | `mix compile --warnings-as-errors` | SC-CMP-025 |
| Agent-6 | Format Check | `mix format --check-formatted` | SC-FMT-001 |

## Phase 3: Verification & Documentation (Parallel)
**Duration**: ~5 minutes | **Parallelization**: 4 agents

| Agent | Task | Output |
|-------|------|--------|
| Agent-7 | Coverage Report | Generate HTML coverage report |
| Agent-8 | Test Summary | Document test counts, properties |
| Agent-9 | Constraint Audit | Verify STAMP constraints met |
| Agent-10 | Changelog Update | Update CHANGELOG.md |

## Phase 4: Commit & Release (Sequential)
**Duration**: ~3 minutes | **Parallelization**: None (git operations)

### 4.1 Stage All Changes
```bash
git add -A
```

### 4.2 Create Sprint 30 Completion Commit
```bash
git commit -m "$(cat <<'EOF'
feat(prajna): Complete Sprint 30 P3/P4 - Quality Gate & Release v21.1.0

## P3: Coverage & Verification
- Full test suite: X tests, Y properties, 0 failures
- Code quality: Credo strict passed
- Security scan: Sobelow passed
- Type checking: Dialyzer passed
- Format check: All files formatted

## P4: Quality Gate & Merge
- Compile with warnings-as-errors: PASSED
- Coverage: >95%
- All STAMP constraints verified

## Sprint 30 Deliverables
- 24 Prajna core modules
- 20 LiveView components
- 26 test files
- 907+ tests, 155+ properties

STAMP: SC-PRAJNA-*, SC-BIO-*, SC-TEST-*, SC-CMP-025
Framework: SOPv5.11 + IEC 61508 SIL-2

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### 4.3 Create Release Tag
```bash
git tag -a v21.1.0 -m "Release v21.1.0 - Founder's Covenant + Prajna C3I Cockpit"
```

### 4.4 Push to Remote
```bash
git push origin main
git push origin v21.1.0
```

## Success Criteria (100% Completion)

| Gate | Requirement | Status |
|------|-------------|--------|
| Compile | 0 errors, 0 warnings | ⏳ |
| Tests | 100% pass rate | ⏳ |
| Coverage | >95% | ⏳ |
| Format | All formatted | ⏳ |
| Credo | 0 issues (strict) | ⏳ |
| Sobelow | 0 security issues | ⏳ |
| Dialyzer | 0 type errors | ⏳ |
| Commit | Created | ⏳ |
| Tag | v21.1.0 created | ⏳ |
| Push | Remote updated | ⏳ |

## Rollback Plan
If any gate fails:
1. `git reset --soft HEAD~1` (uncommit)
2. Fix issues identified
3. Re-run Phase 2
4. Continue from Phase 4

## Agent Assignment Matrix

```
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 1: SEQUENTIAL FIXES (Claude Main)                         │
├─────────────────────────────────────────────────────────────────┤
│ [1.1] mix format ──► [1.2] Fix alias ──► [1.3] Fix tags        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 2: PARALLEL QUALITY GATES (6 Agents)                      │
├──────────┬──────────┬──────────┬──────────┬──────────┬─────────┤
│ Agent-1  │ Agent-2  │ Agent-3  │ Agent-4  │ Agent-5  │ Agent-6 │
│ Tests    │ Credo    │ Sobelow  │ Dialyzer │ Compile  │ Format  │
└──────────┴──────────┴──────────┴──────────┴──────────┴─────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 3: PARALLEL VERIFICATION (4 Agents)                       │
├────────────────┬────────────────┬────────────────┬──────────────┤
│ Agent-7        │ Agent-8        │ Agent-9        │ Agent-10     │
│ Coverage       │ Test Summary   │ STAMP Audit    │ Changelog    │
└────────────────┴────────────────┴────────────────┴──────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 4: SEQUENTIAL RELEASE (Claude Main)                       │
├─────────────────────────────────────────────────────────────────┤
│ [4.1] git add ──► [4.2] Commit ──► [4.3] Tag ──► [4.4] Push    │
└─────────────────────────────────────────────────────────────────┘
```

## Execution Command
```bash
# Phase 1: Run from Claude main
# Phase 2: Launch 6 Task agents in parallel
# Phase 3: Launch 4 Task agents in parallel
# Phase 4: Run from Claude main
```
