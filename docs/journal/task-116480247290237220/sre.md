# Marionette MCP — SRE / Site Reliability Operations

> Task `116480247290237220`. Pattern follows existing C3I SRE template [zk-15fdb070d421e38b], [zk-3e3c45be5cbff3ba], [zk-a21856f7c72333af]. Defines runbooks, SLOs/SLIs, on-call workflow, incident classes, and chaos drills for Marionette MCP.

## 1. SLOs and SLIs

| ID | SLO | SLI | Window | Target | Threshold of action |
|---|---|---|---|---|---|
| SLO-MM-1 | Tool dispatch latency | p95(MCP round-trip) | 24 h | < 500 ms | > 800 ms → P3 |
| SLO-MM-2 | Discovery-first compliance | violations / total drive calls | 24 h | 0% | > 0% → P0 |
| SLO-MM-3 | Failure-evidence sufficiency | failed runs with full evidence / failed runs total | 24 h | 100% | < 100% → P0 |
| SLO-MM-4 | Test-run pass rate | passed / (passed+failed) | 7 d | ≥ 95% | < 90% → P1 |
| SLO-MM-5 | Multi-platform parity | starred tests covering A+L+W / total starred | 7 d | 100% | < 100% → P2 |
| SLO-MM-6 | Selector drift rate | runs flagged by `MarionetteSelectorDrift` | 7 d | < 5% | > 10% → P1 |
| SLO-MM-7 | Zenoh envelope delivery | envelopes published / runs × phases | 24 h | ≥ 99% | < 99% → P2 |
| SLO-MM-8 | Math gate H | Shannon entropy weekly | 7 d | ≥ 2.5 bits | < 2.3 → P3 |
| SLO-MM-9 | CI nightly P9 success | nightly suite green | 7 d | 7/7 | < 7/7 → P2 |
| SLO-MM-10 | Hot-reload state preservation | runs where `hot_reload` cleared flag | 24 h | 0 | > 0 → P1 |

## 2. Severity classes

- **P0** — discovery-first violation, evidence loss, release-mode binding active. Page on-call within 15 min.
- **P1** — selector drift cascade, hot-reload regression, parity miss on starred test. Open within 1 h.
- **P2** — CI nightly red, FMEA RPN climbing > 150 sustained, advisory back-log. Triage next business day.
- **P3** — entropy floor breach, latency drift, advisory not yet wired. Sprint backlog.

## 3. Runbooks

### RB-1 · Discovery-first violation flood (P0)

**Symptom**: `indrajaal/l5/test/marionette/<run_id>/violation` topic spikes; agent advisories pile up.

**Triage**:
1. `./sa-plan-daemon knowledge-search "discovery-first"` → cite [zk-bb4de67d97f807ac].
2. `tail /tmp/marionette-discovery-*.flag` — check flag file existence per session.
3. Inspect agent prompt history for recent change.

**Remediation**:
1. Stop the offending agent (TaskStop or kill PID).
2. Enforce SC-MARIONETTE-003 on the agent's system prompt.
3. Re-run the affected test cycle; verify zero violation envelopes.
4. Open RCA journal entry; ingest to ZK.

### RB-2 · Failed test without evidence (P0)

**Symptom**: `failed` envelope without `screenshot_path` payload.

**Triage**:
1. Check `docs/cache/marionette/<run_id>/` — should contain `screenshots/`, `logs.txt`, latest `tree.json`.
2. Check Allium invariant `EvidenceForFailure` — was the force-capture branch hit?

**Remediation**:
1. If `disconnect` happened before capture: bug in agent control flow → patch + redeploy.
2. If capture call returned empty: VM service may have died; restart Flutter debug session.
3. Mark TID as quarantined via `MarionetteFlakeQuarantine` until reproducible.

### RB-3 · Marionette enabled in release build (P0)

**Symptom**: `MarionetteReleaseBlock` rule fires; binding refused.

**Triage**:
1. `flutter build … --release` MUST not initialize the binding.
2. Inspect `lib/main.dart:60` — confirm `kDebugMode && !DISABLE_MARIONETTE` guard.
3. Check `--dart-define=DISABLE_MARIONETTE=true` in any release pipeline.

**Remediation**: revert + add CI gate that greps the binding initialization line for the guard.

### RB-4 · Selector drift cascade (P1)

**Symptom**: > 10% of runs hit `MarionetteSelectorDrift` advisory in 7 d.

**Triage**:
1. Run the causal-graph blast-radius query (G1 diagram): which test groups share selectors?
2. `mcp__marionette__get_interactive_elements` against the affected screen — diff vs baseline tree.
3. Identify the renamed/removed widget key.

**Remediation**:
1. Update CATALOG.md row(s) with new selector.
2. Re-run the causal cone (NOT the full catalog).
3. Open `learn-rule` task to add a new pattern entry to ZK if recurrent.

### RB-5 · Zenoh envelope delivery drop (P2)

**Symptom**: SLO-MM-7 < 99%; advisories arrive late.

**Triage**:
1. Zenoh router health: `/health` endpoint or `zenoh-cli` subscribe.
2. Inspect `tool/patrol-zenoh-bridge.sh` for recent edits.
3. Backpressure: check Rule 184 dropped frame count.

**Remediation**:
1. If router degraded — use ops-supervisor RB to recover.
2. If bridge buggy — revert + canary on one TID.
3. If backpressure normal — accept screenshot drops, ensure envelope path remains 100%.

### RB-6 · Hot-reload clears flag-file (P1)

**Symptom**: SLO-MM-10 > 0; `MarionetteHotReloadStatePreservation` invariant violated.

**Triage**:
1. Inspect hook command — ensure `hot_reload` is in the *no-op* branch of the case statement.
2. Verify session_id in flag-file path is stable across the reload.

**Remediation**: hook is keyed on session id, not reload count → patch hook regex.

### RB-7 · Apalache CI gate red (P2 — future)

**Symptom**: nightly Apalache check fails on `DiscoveryBeforeDrive`.

**Triage**: invariant violated by code path change since last green build → run `git bisect` against `.claude/settings.json` + flag-file logic.

**Remediation**: revert offending change; re-run; reopen the upstream design discussion.

## 4. Chaos drills (P6 of test plan)

Already enumerated in `test-plan.md` §P6. Each drill = 1 FMEA failure mode injected; each must trigger its mitigation rule and surface an advisory.

## 5. On-call rotation

| Role | Owner | Coverage |
|---|---|---|
| Primary | marionette-explorer agent (autonomous) | 24×7 |
| Escalation 1 | safety-validator agent | for P0 |
| Escalation 2 | constitutional-verifier agent | for L0 invariant violations |
| Human-in-loop | operator (Abhi) | P0 + L0 changes |

Auto-escalation pathway: violation → flag-file + Zenoh advisory → primary agent reacts → if SLO not recovered in 5 min → escalation 1 → if RB doesn't apply → escalation 2 → operator paged.

## 6. KPI dashboard requirements (B1)

The Lustre dashboard tile MUST show:

| Tile | Source | Refresh |
|---|---|---|
| Active sessions | `indrajaal/l5/test/marionette/**/start` minus `**/quit` | 1 s |
| Pass rate (24 h) | passed / (passed + failed) | 5 s |
| Discovery-first violations (24 h) | count of `**/violation` envelopes | 5 s |
| Top FMEA RPN | rolling FMEA aggregator | 30 s |
| Last envelope phase | most recent topic | 1 s |
| Coverage entropy H | weekly Shannon over 16 tools | 1 h |

## 7. Backups & disaster recovery

| Asset | Backup | Recovery point |
|---|---|---|
| `docs/cache/marionette/` | gdrive sync nightly (gdrive-upload) | 24 h |
| sa-plan tasks (smriti.db) | `sa-plan-daemon backup` weekly + on-edit | 7 d |
| Allium spec | git | continuous |
| Rule + agent + skill | git | continuous |
| Upstream clone | `git pull` weekly cron | 7 d |

DR drill: every quarter, restore Smriti.db from a snapshot, verify task IDs match expected, advisories replay correctly.

## 8. Capacity planning

- Per-test envelope: ~1 KB. 200 tests × 5 phases × 3 platforms × 30/day = 90 K msgs/day = 90 MB/day raw. Backpressure rule keeps this bounded.
- Screenshot per phase: ~300 KB. Drop on backpressure (Rule 184).
- Smriti `session_metrics` row: ~200 bytes. Negligible.

## 9. Compliance & audit

- Every test run produces an OTel-style envelope chain → audit trail per Allium `ZenohEventCoverage` invariant.
- Every gap (A1–A8, B1–B10) has a sa-plan task ID → traceable backlog.
- Every state change in `MarionetteSession` recorded in Smriti.db.
- Quarterly review: replay 30 days of envelopes through ruliology classifier; assert 0 P0 missed.

## 10. Service catalog entry

```
service: marionette-mcp
owner:   marionette-explorer agent (autonomous), Abhi (human escalation)
sla:     SLO-MM-1..10 (this doc §1)
tier:    L4 system (test orchestration)
deps:    Zenoh router, marionette_mcp pkg, marionette_cli, Flutter debug binding,
         sa-plan-daemon (smriti), rule_engine.rs (advisories)
status:  operational (not yet complete — see goals.md DoD)
```
