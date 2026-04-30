<!-- Mirror of .claude/rules/marionette-fractal-jidoka.md; governance parity per SC-SYNC-DOC-007. -->
# Marionette Fractal Jidoka (SC-MARIONETTE-JIDOKA)

> Companion to `marionette-mcp-flutter-testing.md` and `dart-flutter-ai-mcp.md`. This rule mandates that the Marionette MCP integration be **continuously self-validated** in TPS Jidoka style: any drift in rules / agents / skills / scripts / hooks / settings / artefacts MUST stop the line and surface a P0 task.

## 1. Mandate

Per operator directive (2026-04-28): "all claude.md, rules, scripts, agents, code, hooks and any other fractal component related to this feature MUST be correct, MUST be robust, MUST always work, MUST be periodically checked by a job that ensures this is working as expected."

## 2. Implementation

| Layer | Artefact | Check |
|---|---|---|
| Validator | `.claude/scripts/marionette-health-check.sh` | 53 gates across 11 groups |
| Schedule | `crontab -l` `*/10 * * * *` | every 10 min |
| Telemetry | `indrajaal/l5/test/marionette/healthcheck/<run_id>/<phase>` | one envelope per run |
| Andon | sa-plan `[Marionette HEALTH FAIL <ID>] <desc>` P0 tasks | idempotent via unique-key |
| Log | `data/marionette-healthcheck.log` | append-only |

## 3. STAMP constraints

| ID | Constraint | Severity |
|---|---|---|
| SC-MARIONETTE-JIDOKA-001 | Health-check script MUST exist + be executable + pass `bash -n` | CRITICAL |
| SC-MARIONETTE-JIDOKA-002 | Health-check MUST run at least every 10 minutes | CRITICAL |
| SC-MARIONETTE-JIDOKA-003 | Every Marionette governance file (rule/agent/skill/spec/hook) MUST have a corresponding gate in the validator | CRITICAL |
| SC-MARIONETTE-JIDOKA-004 | Every published artefact (HTML, deck, journal, links) MUST have a "returns 200" live-HTTPS gate | HIGH |
| SC-MARIONETTE-JIDOKA-005 | Each gate failure MUST create a P0 sa-plan task (idempotent via unique-key) | HIGH |
| SC-MARIONETTE-JIDOKA-006 | Validator MUST publish a Zenoh envelope per run on `indrajaal/l5/test/marionette/healthcheck/**` | HIGH |
| SC-MARIONETTE-JIDOKA-007 | Validator MUST self-validate (script bash-n check on itself) | HIGH |
| SC-MARIONETTE-JIDOKA-008 | When a new governance file is added, the validator file MUST be updated in the SAME commit (Wiring-Guard pattern, SC-WIRE-002) | CRITICAL |
| SC-MARIONETTE-JIDOKA-009 | Failure to run for 30+ min → escalate to P0 (dead-man's switch) | HIGH |
| SC-MARIONETTE-JIDOKA-010 | Validator output MUST be machine-readable (single-line JSON on stdout) for downstream RETE-UL | HIGH |

## 4. RETE-UL rules (3 new, salience 95–85)

| Rule | Salience | When | Then |
|---|---:|---|---|
| `MarionetteHealthcheckRedline` | 95 | health-check `phase == failed` ∧ FAIL count ≥ 5 | P0 alert + page operator |
| `MarionetteHealthcheckMissed` | 90 | no health-check envelope in last 30 min | dead-man — P0 |
| `MarionetteHealthcheckLinkRot` | 85 | gate H-G* fails (any HTTPS 200 check) | P1 + open task automatically |

## 5. Cross-references

- `.claude/scripts/marionette-health-check.sh` — the validator (53 gates).
- `docs/journal/task-116480247290237220/rca-tps.md` — Fractal RCA + countermeasures.
- `crontab -l` — schedule entry.
- `indrajaal/l5/test/marionette/healthcheck/**` — Zenoh telemetry topic.
- Existing rules: `marionette-mcp-flutter-testing.md`, `dart-flutter-ai-mcp.md`, `patrol-mcp-zenoh.md`.

## 6. Governance parity

Mirror at `.gemini/rules/marionette-fractal-jidoka.md` next sync (SC-SYNC-DOC-007).

## 7. Operator surface

```
# Manual one-shot run
.claude/scripts/marionette-health-check.sh

# Status of last run
tail -1 /home/an/dev/ver/c3i/data/marionette-healthcheck.log | jq '.summary'

# Disable cron during maintenance
crontab -l | grep -v marionette-health-check | crontab -
```
