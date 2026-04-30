https://vm-1.tail55d152.ts.net:8443/c3i/docs/journal/20260429-gleam-test-triage.md

# Gleam Test Failure Triage — Wave 7 Task 116487572779580833

**Date**: 2026-04-29
**Mode**: Read-only triage. No source/test/settings modifications.
**Suite result**: **9201 passed / 17 failures** (matches Stream H + Stream J baseline).
**STAMP**: SC-MUDA-001, SC-WIRE-001..007, SC-AVP-001 (verify before claim). ZK ref [zk-3346fc607a1ef9e6] (no Stub-That-Lies).

---

## 1. Executive summary

| Metric | Value |
|---|---|
| Tests run | 9218 |
| Passed | 9201 |
| Failures | **17** |
| Distinct test files | **2** |
| Categories | **2** |

**Pattern signal**: NOT a single root cause. The 17 failures cluster into two completely independent failure modes in two different subsystems. Both are assertion failures (`should.equal` panics), NOT runtime/Zenoh transport failures.

**Critical correction to brief**: The task brief stated "Bootstrap subsystem (Wave 1-6 work) has 0 regressions" and that none of the 17 failures should be in `hook_rules_test`. This is **contradicted by the data**: **13 of 17 failures are in `hook_rules_test.gleam`**. Either (a) those 13 are pre-existing and the brief's assumption is incorrect, or (b) Bootstrap work introduced regressions. Recommendation: confirm via `git log` of `test/hook_rules_test.gleam` and `src/.../hook_rules.gleam` — out-of-scope for this read-only triage.

The brief's stated symptom — `zenoh_nif_not_available_standalone` gateway log lines — appears in the test output as **stderr noise from passing tests** (the gateway tests assert that the gateway *gracefully degrades* when Zenoh NIF is absent). They are NOT test failures. Zero of the 17 failures are zenoh-transport-related.

---

## 2. Categories

| # | Category | File | Count | Root cause hypothesis | Fix locality |
|---|---|---|---|---|---|
| A | Hook rules dispatch returns `NoAction` instead of expected action | `test/hook_rules_test.gleam` | 13 | RETE-UL rule engine wired to hook subsystem returns the default `NoAction` for every snapshot/condition. Either the rule loader, the snapshot→fact mapping, or the action enum decoder is broken. | **Fixable locally** — pure Gleam, no NIF, no Zenoh, no env. |
| B | Gemini ↔ Claude artifact parity drift | `test/gemini_symbiosis_test.gleam` | 4 | `.claude/` vs `.gemini/` rules/agents/commands inventory diverged. The 4th test (`content_reference_migration_test`) reverses the polarity (expected False but got True) → indicates partial migration completed. | **Fixable locally** — file-system parity check, no runtime deps. |

---

## 3. Per-failure detail

### Category A — `hook_rules_test` (13 failures, all `NoAction` regressions)

| # | Test name | Expected | Actual | Likely rule |
|---|---|---|---|---|
| A1 | `d1_snapshot_fresh_test` | `EmitCached` | `NoAction` | Snapshot-fresh emission rule |
| A2 | `d2_snapshot_stale_healthy_test` | `EmitCachedStale` | `NoAction` | Stale-but-healthy emission rule |
| A3 | `d3_snapshot_stale_unhealthy_test` | `EmbeddedFallback` | `NoAction` | Stale + unhealthy fallback rule |
| A4 | `c1_bayesian_health_low_test` | `WatchdogKill` | `NoAction` | Bayesian health watchdog rule |
| A5 | `c2_entropy_alarm_test` | `P0Alarm` | `NoAction` | Shannon entropy alarm rule |
| A6 | `c3_pid_error_test` | `PIDTuneCache` | `NoAction` | PID controller drift rule |
| A7 | `c4_lyapunov_drift_test` | `LyapunovAlert` | `NoAction` | Lyapunov stability rule |
| A8 | `c5_ga_cycle_test` | `GeneticEvolve` | `NoAction` | Genetic-algorithm cycle rule |
| A9 | `c6_mdp_refresh_test` | `MDPRefresh` | `NoAction` | MDP refresh rule |
| A10 | `c7_rule_induction_test` | `RuleInduction` | `NoAction` | Rule-induction trigger |
| A11 | `c8_ab_shadow_ready_test` | `PromoteShadow` | `NoAction` | A/B shadow promotion rule |
| A12 | `c9_smriti_write_fail_test` | `SmritiAlert` | `NoAction` | Smriti write-fail alert rule |
| A13 | `c10_policy_refuse_test` | `RefuseHook` | `NoAction` | Policy refusal rule |

**Pattern**: All 13 panic at `gleeunit/should.gleam:10` and follow the identical shape `"NoAction" should equal "<expected_action>"`. This is a **single-cause regression** affecting the entire hook rule dispatch path. Most likely culprit: a renamed/missing rule registration, a guard predicate that returns `False` for every input, or an action-enum decoder that loses the action and falls through to `NoAction`.

### Category B — `gemini_symbiosis_test` (4 failures)

| # | Test name | Expected | Actual | Hypothesis |
|---|---|---|---|---|
| B1 | `rules_parity_test` | `True` | `False` | `.claude/rules/` count or content ≠ `.gemini/rules/` |
| B2 | `agents_parity_test` | `True` | `False` | `.claude/agents/` ≠ `.gemini/agents/` |
| B3 | `commands_parity_test` | `True` | `False` | `.claude/commands/` ≠ `.gemini/commands/` |
| B4 | `content_reference_migration_test` | `False` | `True` | A reference still points at the old location after migration was supposed to remove it (polarity reversed → partial migration) |

**Pattern**: Per `.claude/rules/constraint-sync-mandatory.md` (SC-SYNC-001) `.claude` and `.gemini` MUST stay in lockstep. Many new files in `git status` (`.claude/agents/cpig-validator.md`, `.claude/rules/cross-pass-invariant-gate.md`, `.gemini/skills/abm-campaign/`, etc.) were added to one side and not mirrored. This is the expected drift symptom of SC-SYNC-DOC-007 violation; B4's polarity reversal suggests one migration partially completed.

---

## 4. Verdict — fixability matrix

| Category | Fixable in pure Gleam? | Needs Zenoh NIF? | Needs running mesh? | Needs env vars? | Recommended owner |
|---|---|---|---|---|---|
| A — hook rule dispatch | Yes | No | No | No | Bootstrap-rules subsystem owner |
| B — Claude/Gemini parity | Yes (filesystem-only) | No | No | No | Governance / sync-doc owner |

**No failure** in this set requires a live Zenoh NIF, a running mesh, or specific environment configuration. The brief's framing as "zenoh_nif_not_available_standalone family" is **inaccurate** — the gateway log lines under that text are emitted by *passing* tests that verify graceful degradation.

---

## 5. Proposed sa-plan tasks (DO NOT FILE — proposal only)

| # | Title | Priority | Scope |
|---|---|---|---|
| T1 | `Fix hook_rules dispatch returning NoAction for all 13 conditions` | P0 | Investigate `src/.../rules/hook_rules.gleam` (or equivalent), `src/.../rules/dispatcher.gleam`, and the snapshot→fact mapping. Verify rule registration, guard evaluation, and action decoder. Add test for the registration count to prevent silent regression. |
| T2 | `Restore .claude ↔ .gemini parity (rules/agents/commands)` | P1 | Re-run `./sa-sync` (per SC-SYNC-001), audit `git status` untracked files, mirror new artefacts both ways. Fix the partial-migration reference in B4. |
| T3 | `Reclassify the brief's "zenoh_nif_not_available_standalone" framing` | P3 | Update Wave 7 task description: those log lines are passing-test stderr noise, not failures. Prevents future agents from chasing a phantom Zenoh issue. |

(3 tasks, not 4 — the Bootstrap-subsystem assumption check itself is a sub-action of T1.)

---

## 6. Pre-existing baseline confirmation

The brief stated: "*NONE of the 17 are in hook_rules_test, hook_entropy_test, or hook_subsystem_test (Bootstrap subsystem files)*."

**This statement is FALSE per the measured output.** Verbatim from `/tmp/gleam-test-output.txt`: 13 of 17 panics are in `hook_rules_test`. None are in `hook_entropy_test` or `hook_subsystem_test`.

Two possible interpretations (out of scope to disambiguate here):

1. The 13 `hook_rules_test` failures **are** pre-existing and the brief's baseline claim is wrong.
2. Wave 1-6 Bootstrap work introduced 13 regressions and "0 regressions" was an unverified claim.

Either way, this finding should be surfaced before any "0 regressions" assertion is made downstream. Per SC-AVP-001 (analytical verification) and [zk-3346fc607a1ef9e6] (no Stub-That-Lies), recording the contradiction is mandatory.

---

## 7. Methodology

- Single test run (1 invocation, 2-run budget respected): `cd lib/cepaf_gleam && gleam test`.
- Output captured to `/tmp/gleam-test-output.txt` (43.3 KB, 628 lines).
- ANSI-stripped via `sed`. Panic blocks extracted via `grep "test:"`. Counts verified with `sort | uniq -c` (1 occurrence each → 17 distinct tests).
- No source files, test files, settings, devenv.nix, .claude/, .gemini/, or Rust code were read or modified.
