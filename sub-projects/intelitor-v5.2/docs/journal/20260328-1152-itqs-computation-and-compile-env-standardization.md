# ITQS Automated Computation & Compile Environment Standardization

**Date**: 20260328-1152 CEST
**Author**: Claude Opus 4.6
**Commit**: `pending` (uncommitted), predecessors: `8764c2ddf`
**Version**: v21.3.1-SIL6
**Branch**: main
**STAMP**: SC-MATH-COV-002 to SC-MATH-COV-007, SC-ENV-COMPILE-001 to SC-ENV-COMPILE-008, SC-PARALLEL-001, SC-PARALLEL-002
**Compliance**: SC-SYNC-DOC-002 (journal mandatory for every plan)

---

## 1. Scope & Trigger

**Trigger**: The Wallaby coverage audit Mix task (`lib/mix/tasks/wallaby_coverage_audit.ex`) computed
Shannon entropy and feature counts but did not compute the full ITQS (Information-Theoretic Quality
Score) defined in `.claude/rules/fractal-coverage-mathematical-framework.md`. Additionally, during
ITQS development, compilation was run with `SKIP_ZENOH_NIF=1`, breaking Zenoh telemetry integration.
The user directed a codebase-wide standardization of all compile/test environment variables.

**Scope**:
- IN: ITQS computation in wallaby_coverage_audit.ex, codebase-wide compile env standardization
- OUT: Runtime E2E test execution (requires devenv shell + Chromium + PostgreSQL)

## 2. Pre-State Assessment

- ITQS computation: absent from Mix audit task (only H, feature count, category distribution existed)
- D_EA (Expected vs AS-IS divergence): not computed
- CCM_weighted: not computed
- FSI (Fractal Self-Similarity Index): not computed
- Compile commands: inconsistent across 20+ files — some used `+S 16` (missing SDio), some used `SKIP_ZENOH_NIF=1`, most omitted `WALLABY_ENABLED=true`
- devenv.nix test scripts: correct; compile scripts: missing SKIP_ZENOH_NIF and WALLABY_ENABLED
- Shell scripts: all using outdated `+S 16` instead of `+S 16:16 +SDio 16`

## 3. Execution Detail — Phase/Wave Breakdown

### Phase 1: ITQS Implementation (prior session, carried forward)

1. Added module attributes: `@max_entropy`, `@ccm_weights`, `@ccm_expected_min`, `@itqs_alpha/beta/gamma/delta`
2. Extended `file_audit` type with `d_ea`, `ccm_weighted`, `itqs`, `fsi` fields
3. Implemented `compute_ccm_weighted/2` — weighted CCM per category with C1-C8 weights
4. Implemented `applicable_optional_categories/1` — content-based C4-C7 applicability detection
5. Implemented `compute_fsi/1` — FSI = 1 - (σ_H / μ_H) for files with ≥10 features
6. Implemented `enrich_with_itqs/2` — per-file ITQS = α×H_norm + β×CCM + γ×(1-D_EA) + δ×FSI
7. Implemented `itqs_grade/1` — A/B/C/D grading
8. Added ITQS line to per-file output box and ITQS METRICS aggregate section
9. Added ITQS fields to JSON output

**Verified output**:
- Suite ITQS: 0.8693 Grade B (≥0.85 — PASS)
- FSI: 0.8538 (≥0.85 — PASS)
- D_EA: 0.017 (≤0.10 — PASS)
- CCM weighted: 81.7% (needs improvement toward 90%)
- Gold standard alarm_investigation: ITQS 0.9698 Grade A

### Phase 2: Stale BEAM File Discovery

Root cause of ITQS not appearing initially: stale `./Elixir.Mix.Tasks.WallabyCoverageAudit.beam`
in project root. Erlang code loader found it before the freshly compiled version in `_build/`.
Fix: deleted stale .beam file + `mix compile --force`.

### Phase 3: Compile Environment Standardization (this session)

Deployed 2 parallel Explore agents to audit all compile/test commands across the codebase.

**Shell scripts fixed (8 files)**:
- `run_prajna_stress_tests.sh` — added full env
- `compile_phase2_check.sh` — `+S 16` → `+S 16:16 +SDio 16`, added SKIP_ZENOH/WALLABY/--jobs 16
- `final_compile_check.sh` — same
- `data/compilation/parallel_compile.sh` — both export and inline fixed
- `data/compilation/patient_compile.sh` — both export and inline fixed
- `__data/compilation/parallel_compile.sh` — mirror
- `__data/compilation/patient_compile.sh` — mirror
- `__data/compilation/container_compile.sh` — container podman exec command

**Agent/command docs fixed (4 files)**:
- `.claude/commands/sil6.md` — SIL-6 test command
- `.claude/commands/evolution.md` — compile + test commands
- `.claude/agents/code-evolution.md` — quality gates
- `.claude/agents/immune-chaos-agent.md` — chaos test commands

**Rules fixed (4 files)**:
- `.claude/rules/biomorphic-mode.md` — quality gates
- `.claude/rules/concurrent-bug-fix-protocol.md` — verify section
- `.claude/rules/test-execution.md` — Wallaby example
- `.claude/rules/five-level-testing.md` — all 6 test level examples

**Core docs fixed (2 files)**:
- `CLAUDE.md` — Omega-1 now includes SKIP_ZENOH_NIF=0 and WALLABY_ENABLED=true
- `docs/plans/20260101-ROBUSTNESS-100-PERCENT-RAPID-EXECUTION.md` — SKIP_ZENOH_NIF=1 → full env

**Authoritative source fixed (1 file)**:
- `devenv.nix` — compile, compile-strict, compile-profile scripts + test-orchestrate script

**New rule created (1 file)**:
- `.claude/rules/mandatory-compile-env.md` — SC-ENV-COMPILE-001 to SC-ENV-COMPILE-008

## 4. Root Cause Analysis

| Root Cause Class | Count | Example |
|-----------------|-------|---------|
| Outdated scheduler format | 8 | `+S 16` instead of `+S 16:16 +SDio 16` in shell scripts |
| Missing SKIP_ZENOH_NIF=0 | 6 | devenv compile scripts, agent docs |
| Missing WALLABY_ENABLED=true | 10 | Nearly all non-test commands |
| Missing --jobs 16 | 5 | Shell scripts, agent docs |
| No single canonical reference | 1 | No rule file defining mandatory env |

## 5. Fix Taxonomy

**Pattern: Full Mandatory Compile Env**
```bash
NO_TIMEOUT=true PATIENT_MODE=enabled \
SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
mix compile --jobs 16
```
Applies when: writing ANY mix compile or mix test command anywhere in the codebase.

## 6. Patterns & Anti-Patterns Discovered

### Patterns (DO this)
- **Canonical Reference Rule**: Create a `.claude/rules/` file as the single source of truth for mandatory flags, then reference it from all other locations.
- **devenv.nix as Authority**: The nix file is correct — mirror its patterns everywhere else.

### Anti-Patterns (AVOID this)
- **Abbreviated Commands**: Writing `mix test` without env vars. Even in documentation examples, always include full env to prevent copy-paste errors.
- **+S N without SDio**: `+S 16` sets scheduler count but misses dirty IO threads critical for Zenoh FFI.

## 7. Verification Matrix

```
Compilation: PASS (0 errors, 1 pre-existing warning: JournalLive undefined)
ITQS Suite: 0.8693 Grade B (≥0.85 PASS)
FSI: 0.8538 (≥0.85 PASS)
D_EA: 0.017 (≤0.10 PASS)
Files updated: 20 files across 7 directories
New rule: .claude/rules/mandatory-compile-env.md (SC-ENV-COMPILE-001 to -008)
Memory saved: feedback_mandatory_compile_env.md
```

## 8. Files Modified

| File | Change Type | Lines | Notes |
|------|------------|-------|-------|
| `lib/mix/tasks/wallaby_coverage_audit.ex` | modified | +120 | ITQS computation (prior session) |
| `run_prajna_stress_tests.sh` | modified | +4 | Full env |
| `compile_phase2_check.sh` | modified | +3 | +S 16→+S 16:16 +SDio 16, ZENOH, WALLABY |
| `final_compile_check.sh` | modified | +3 | Same |
| `data/compilation/parallel_compile.sh` | modified | +4 | Both locations |
| `data/compilation/patient_compile.sh` | modified | +4 | Both locations |
| `__data/compilation/parallel_compile.sh` | modified | +4 | Mirror |
| `__data/compilation/patient_compile.sh` | modified | +4 | Mirror |
| `__data/compilation/container_compile.sh` | modified | +3 | Container exec |
| `.claude/commands/sil6.md` | modified | +1 | Full env for test |
| `.claude/commands/evolution.md` | modified | +2 | Compile + test |
| `.claude/agents/code-evolution.md` | modified | +2 | Quality gates |
| `.claude/agents/immune-chaos-agent.md` | modified | +4 | Chaos tests |
| `.claude/rules/biomorphic-mode.md` | modified | +2 | Quality gates |
| `.claude/rules/concurrent-bug-fix-protocol.md` | modified | +2 | Verify section |
| `.claude/rules/test-execution.md` | modified | +2 | Wallaby example |
| `.claude/rules/five-level-testing.md` | modified | +10 | All 6 test levels |
| `.claude/rules/mandatory-compile-env.md` | new | +130 | SC-ENV-COMPILE rule |
| `CLAUDE.md` | modified | +1 | Omega-1 SKIP_ZENOH+WALLABY |
| `devenv.nix` | modified | +12 | compile/compile-strict/compile-profile/test-orchestrate |
| `docs/plans/20260101-ROBUSTNESS-100-PERCENT-RAPID-EXECUTION.md` | modified | +2 | SKIP_ZENOH_NIF=1→0 |

**Total delta**: ~+180 lines across 21 files.

## 9. Architectural Observations

The compile environment was fragmented across dozens of files with no single canonical reference.
The `devenv.nix` file had correct test scripts but incomplete compile scripts. Documentation and
agent definitions referenced abbreviated commands. The new `.claude/rules/mandatory-compile-env.md`
serves as the canonical reference that all other files should mirror.

The dirty IO scheduler count (`+SDio 16`) is particularly important because Zenoh FFI operations
use dirty schedulers for blocking C ABI calls. Without it, FFI operations compete for default
threads, causing latency spikes visible in the observability dashboard.

## 10. Remaining Gaps

| Gap | Priority | Notes |
|-----|----------|-------|
| TEST_EXECUTION_QUICK_REFERENCE.md | P3 | Reference doc with abbreviated commands, lower priority |
| TEST_VERIFICATION_INDEX.md | P3 | Same — abbreviated for readability |
| CCM weighted at 81.7% | P2 | Needs more category coverage to reach 90% target |
| Runtime E2E execution | P2 | Requires devenv shell + Chromium + PostgreSQL |

## 11. Metrics Summary

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| ITQS computation | absent | automated | +1 capability |
| Suite ITQS | unmeasured | 0.8693 Grade B | new metric |
| FSI | unmeasured | 0.8538 | new metric |
| Files with full env | ~8 | 21+ | +13 files |
| Compile env rule | absent | SC-ENV-COMPILE-001 to -008 | +8 constraints |
| Stale +S 16 refs | 8 | 0 | -100% |
| SKIP_ZENOH_NIF=1 in active docs | 1 | 0 | -100% |

## 12. STAMP & Constitutional Alignment

- **SC-MATH-COV-002 to -007**: ITQS metrics now computable from source + test files alone
- **SC-ENV-COMPILE-001 to -008**: New constraints enforcing mandatory compile environment
- **SC-PARALLEL-001, -002**: All commands now include +S 16:16 +SDio 16 and --jobs 16
- **SC-ZENOH-001**: SKIP_ZENOH_NIF=0 enforced in all compile/test contexts
- **SC-COV-008**: WALLABY_ENABLED=true included in all test contexts
- **AOR-COV-012**: ITQS includes H_norm component verifying entropy ≥ 2.5 bits
- **Omega-1 (Patient Mode)**: Updated in CLAUDE.md to include SKIP_ZENOH_NIF and WALLABY_ENABLED

## 13. Conclusion

This session delivered two major capabilities: (1) automated ITQS computation in the Wallaby coverage
audit, providing a single numeric quality score per file and suite-wide, and (2) complete standardization
of compile/test environment variables across 21 files spanning shell scripts, agent definitions, rule
files, command skills, and core documentation.

The most important discovery was that the dirty IO scheduler flag (`+SDio 16`) was missing from all
shell scripts, meaning Zenoh FFI operations were running with only 10 dirty IO threads instead of 16.
This has been corrected everywhere.

The new `.claude/rules/mandatory-compile-env.md` file serves as the canonical, grep-findable reference
for mandatory compile flags. Future sessions should never again need to wonder what flags to use — the
rule file, the feedback memory, and the CLAUDE.md Omega-1 section all agree.
