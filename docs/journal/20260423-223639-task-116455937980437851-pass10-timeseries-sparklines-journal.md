# Pass-10 · Robustness hardening (Pi cold-start safe)

Task: 116455937980437851

## Goal
Make all shipped features resilient under cold-start and continuous operation:
performance, stability, utility, correctness, and durability with STAMP/FMEA/RETE-lite.

## Shipped

1. **Backfill Jidoka hardening** (`p8_04_embed_backfill.gleam`)
   - Added `MAX_SECONDS` hard time budget (default 120s)
   - Added `HEARTBEAT_EVERY` progress heartbeat (default 10)
   - Added deterministic stop behavior (`stopped=true/false` in summary)
   - Added ETA/rate logging for operator visibility
   - Prevents "looks hung" during long fastembed calls

2. **Robustness gate module** (`p10_robustness_gate.gleam`)
   - STAMP/FMEA/RETE-lite checks every 60s
   - Checks:
     - control plane: sa-plan, kms health
     - correctness: integrity_check, foreign_key_check, WAL
     - utility: customer `/c3i` URL health (html/json/agents/history)
     - core services: zenoh session, fastembed info
   - Computes score/grade + alarms + recommended actions
   - Produces:
     - `docs/journal/monitor/robustness.json`
     - `docs/journal/monitor/robustness.md`

3. **Systemd durability**
   - Added and enabled `c3i-robustness-gate.service`
   - Auto-restart + persistent logs:
     - `data/monitor/robustness.log`

4. **Dashboard expansion** (`docs/dashboards/symbiosis.html`)
   - Added time-series sparklines from `history.ndjson`
   - Added per-agent table from `agents.json`
   - Added robustness panel from `robustness.json`
   - Added runtime controls: history window, poll rate, pause/resume

5. **Symbiosis monitor continuity** (`p9_symbiosis_monitor.gleam`)
   - Append-only history stream: `history.ndjson`
   - Per-agent rollup snapshot: `agents.json`

## Current gate output

- Score: **80 (B)**
- Alarms:
  - `COST_HIGH`
  - `EMBED_LOW`
- Utility URLs: all healthy
- Integrity/FK/WAL: healthy

## FMEA top risks (RPN)

1. cost per session high → RPN 336
2. embedding coverage low → RPN 294

## Customer URLs

- Dashboard: https://vm-1.tail55d152.ts.net/c3i/task-id/any/monitor/symbiosis.html
- Symbiosis JSON: https://vm-1.tail55d152.ts.net/c3i/task-id/any/monitor/symbiosis.json
- Robustness JSON: https://vm-1.tail55d152.ts.net/c3i/task-id/any/monitor/robustness.json
- Robustness MD: https://vm-1.tail55d152.ts.net/c3i/task-id/any/monitor/robustness.md

## Notes

Backfill remains compute-heavy (~2–3s/document under current ONNX profile). With Jidoka limits + heartbeats,
operators can run bounded windows repeatedly instead of waiting on opaque long runs.

## Phase-2 hardening (completed)

6. `p10_history_compactor.gleam`
   - trims `history.ndjson` to newest N lines (default 20k)
   - publishes compaction event to Zenoh topic `indrajaal/l4/sre/history_compactor`
   - timer: `c3i-history-compactor.timer` every 10 min

7. `p10_chaos_probe.gleam`
   - controlled chaos cycle for user services (stop/start/verify)
   - validates post-restart health of monitor endpoints
   - result emitted on `indrajaal/l4/sre/chaos_probe`
   - observed score: 100 in dry run

8. `p10_slo_guard.gleam`
   - evaluates robustness score against SLO threshold (default 75)
   - tracks consecutive violations in `slo-state.json`
   - emits paging event when breach persists N cycles (`SLO_CONSECUTIVE=3`)
   - timer: `c3i-slo-guard.timer` every 1 min

### Active timers / services

- `c3i-symbiosis-monitor.service` (5s)
- `c3i-robustness-gate.service` (60s)
- `c3i-rete-autofix.service` (300s, safe defaults)
- `c3i-history-compactor.timer` → service every 10 min
- `c3i-slo-guard.timer` → service every 1 min

### Safety defaults retained

- `AUTOFIX_ENABLED=false`
- `REQUIRE_GUARDIAN=true`
- `ALLOW_SOFT_BYPASS=false`


## Operations status panel added

- New generator: `scripts/pass10/p10_ops_status.gleam`
- New timer: `c3i-ops-status.timer` (every 1 min)
- New output: `docs/journal/monitor/ops-status.json`
- Dashboard section now displays:
  - service active/substate/pid/rc
  - timer active/next/last

URL:
- https://vm-1.tail55d152.ts.net/c3i/task-id/any/monitor/ops-status.json

### Ops badge logic (new)

Dashboard now computes explicit status badges:

- **DEGRADED (red)**
  - any critical service not `active/running` or `rc != 0`
- **WARN (yellow)**
  - services healthy, but timer cadence appears suspect (`next_mono <= last_mono`)
- **HEALTHY (green)**
  - all critical services healthy and no timer cadence warning

Displayed in panel header as `ops-global-badge`.
