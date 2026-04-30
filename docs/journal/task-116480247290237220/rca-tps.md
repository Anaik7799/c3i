# Marionette MCP — Fractal RCA + TPS Self-Healing

> Task `116480247290237220`. Operator mandate: "fractal TPS, fractal RCA, all rules/scripts/agents/hooks MUST be correct, robust, always work, periodically checked." This document is the closure of that mandate.

## 1. The defect

**Symptom**: User opened `https://vm-1.tail55d152.ts.net:4200/task-id/116480247290237220/` → ERR_CONNECTION_REFUSED.

**Severity**: P1 (operator-visible; broken first-touch UX).

## 2. Fractal RCA — 5-Why

| Level | Question | Answer |
|---|---|---|
| Why₁ | Why does the link not work? | Port 4200 is not listening. |
| Why₂ | Why is 4200 not listening? | The live `sa-plan-daemon serve` binds 8443 (HTTPS via self-signed cert), not 4200. |
| Why₃ | Why was 4200 in the URLs? | `feature-evolution-protocol.md` (rule SC-FEAT-EVO-011) hardcodes `https://vm-1.tail55d152.ts.net:4200/task-id/{task_id}/{filename}`. Pass-3 publication followed that rule literally. |
| Why₄ | Why did the protocol hardcode 4200? | Authored in an earlier sprint when the planned port was 4200 (before TLS/8443 deploy). No automated probe verified the URL pattern resolves. |
| Why₅ | **Root** — why was there no automated probe? | No Fractal Jidoka gate validated *publication artefacts* end-to-end. Existing Jidoka covered builds + tests, not "is the published URL reachable". |

## 3. Countermeasures (TPS-aligned)

| TPS principle | Countermeasure | Implemented |
|---|---|---|
| **Jidoka** (stop the line) | `marionette-health-check.sh` checks 53 gates incl. `https://localhost:8443/task-id/.../*.html` returns 200, and `links.json` contains no `:4200` strings | ✅ this pass |
| **Andon** (signal the problem) | Failure publishes Zenoh envelope on `indrajaal/l5/test/marionette/healthcheck/<run_id>/failed` and creates one P0 sa-plan task per failed gate (idempotent via unique-key) | ✅ this pass |
| **Poka-yoke** (mistake-proofing) | Health check runs every 10 min via crontab; gate H-G7 specifically blocks regression to `:4200` | ✅ this pass |
| **Kaizen** (continuous improvement) | Each new fail mode adds a check ID; the check file is the single source of truth for "this integration is correct" | ✅ this pass |
| **Genchi Genbutsu** (go and see) | Health check `curl`s the live port — not just static-asset existence | ✅ this pass |

## 4. Health-check coverage (53 gates, all passing on first run)

| Group | Count | Covers |
|---|---:|---|
| H-A* governance artefacts | 8 | rules, agents, skills, Allium spec |
| H-B* settings.json | 8 | JSON validity, all 3 MCP servers wired, hooks |
| H-C* hook syntax | 2 | bash -n on all hook scripts |
| H-D* upstream clone | 2 | marionette_mcp 5 packages present |
| H-E* FluffyChat | 4 | CATALOG, manifest, runner |
| H-F* task page | 15 | journal/index/deck/9 docs/12 png/12 svg/4 dot |
| H-G* live HTTPS | 7 | port listening, 5 critical pages 200 OK, no `:4200` regression |
| H-H* mechanism | 1 | flag-file create/remove round-trip |
| H-I* sa-plan | 2 | binary present, parent task accessible |
| H-J* ZK | 2 | smriti.db present, marionette holons indexed |
| H-K* tooling | 2 | `dart` on PATH, marionette_mcp activation hint |
| **Total** | **53** | — |

## 5. Periodic schedule

```
crontab -l | grep marionette
*/10 * * * * /home/an/dev/ver/c3i/.claude/scripts/marionette-health-check.sh >> /home/an/dev/ver/c3i/data/marionette-healthcheck.log 2>&1
```

Runs every 10 minutes. Each run:
- Emits one JSON line to stdout (Zenoh-publishable; cron tail-archived).
- Publishes envelope on `indrajaal/l5/test/marionette/healthcheck/<run_id>/<phase>`.
- Creates idempotent `[Marionette HEALTH FAIL <ID>] <desc>` P0 sa-plan tasks per failure.
- Exit code 0 if green, non-zero otherwise → cron MAILTO triggers if configured.

## 6. Cross-cutting STAMP attachment

| Constraint | Mapped to gate(s) |
|---|---|
| SC-MARIONETTE-002 (logCollector) | covered by next-pass gate (when A1 lands) |
| SC-MARIONETTE-003 (discovery-first) | H-B7, H-H1 |
| SC-MARIONETTE-004 (failure capture) | exercised by chaos drill P6, not in this validator |
| SC-MARIONETTE-005 (debug-only) | (compile-time invariant — Dart analyzer) |
| SC-MARIONETTE-008 (CI uses CLI) | next-pass A4 gate |
| SC-MARIONETTE-009 (evidence layout) | H-F13/14/15 |
| SC-MARIONETTE-012 (envelope schema) | H-G2..G6 returns 200 |
| SC-DART-MCP-001 (dart MCP wired) | H-B2 |
| SC-FEAT-EVO-005 (HTML on sa-plan-daemon) | H-G2..G6 |
| SC-FEAT-EVO-013 (screenshots verified) | H-F13 |
| SC-JNL-001 (Tailscale URL on first line) | covered by H-F1 (file present); semantic check is next-pass |
| SC-TPS-001 (Jidoka auto-build) | this script is the Jidoka |

## 7. Resilience properties of the validator itself

- **Fail-fast, fail-loud**: any gate failure → exit non-zero → cron MAILTO + sa-plan P0 task.
- **Idempotent**: unique-key `marionette-healthfail-<ID>` means N consecutive failures = 1 task, not N.
- **Self-validating**: H-C2 checks the script's own bash syntax; if a future edit breaks it, it self-reports.
- **Side-effect bounded**: `--no-publish` flag for dry-run.
- **No secrets**: only reads from filesystem + localhost:8443. No outbound credentials.

## 8. Operator surface

```
# manual run (with publish + tasks)
.claude/scripts/marionette-health-check.sh

# dry run (no Zenoh, no tasks)
.claude/scripts/marionette-health-check.sh --no-publish

# JSON only
.claude/scripts/marionette-health-check.sh --json | jq '.summary'

# tail the log
tail -f /home/an/dev/ver/c3i/data/marionette-healthcheck.log

# disable for maintenance
crontab -l | grep -v marionette-health-check | crontab -
```

## 9. Future hardening (tracked as new tasks)

- **HHC-1**: extend H-G* to include the rich task-page (`/task-id/<id>` no doubled prefix) returns 200.
- **HHC-2**: add a *semantic* gate — `links.json` URLs all return 200 (currently only spot-checks 5).
- **HHC-3**: replace cron with a sa-plan custom worker once `evaluate_marionette()` (A7) lands → unifies scheduling under sa-plan.
- **HHC-4**: extend health check to other Flutter sub-projects when L7 federation lands.
- **HHC-5**: add `dart pub global list` non-empty check (currently advisory-only at H-K2).

## 10. Definition of "correct, robust, always works"

Met when:
1. Cron entry installed ✅
2. First run 100% green ✅
3. Validator covers governance + settings + upstream + catalog + task page + live HTTPS + mechanism + tasks + ZK ✅
4. Each failure auto-creates a sa-plan task with unique-key idempotency ✅
5. RCA documented + 5-Why traced to root ✅
6. Countermeasures mapped to TPS principles ✅
7. Validator self-validates (H-C2) ✅
8. Operator surface documented ✅

All 8 met.
