# Stop-Hook Telemetry Protocol (SC-STOP-HOOK-TELE)

## Mandate

**Every stop-hook invocation MUST append one JSONL row to `data/logs/stop-hook-timing.log`** capturing session id, elapsed seconds, both peer return codes, and computed statuses. Without rolling forensics there is no Lyapunov detector input — a regression from 9 ms warm to 25 s cold would only be visible at the next user-observed timeout, repeating the pre-Pass-15 chaos arc [zk-bd82645aedcb5ef4].

ZK lineage: [zk-bd82645aedcb5ef4] Stub-That-Lies (RPN 729 — measure, don't assert), [zk-c14e1d23afff486c] implicit-invariant family, [zk-f8f40cb7e63db61a] next-pass roadmap, perf-bench-20260516 closure pack.

## STAMP Constraints

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-STOP-HOOK-TELE-001 | Stop-hook MUST record `epoch_s()` at start AND end | HIGH |
| SC-STOP-HOOK-TELE-002 | Stop-hook MUST append exactly one JSONL row per invocation | HIGH |
| SC-STOP-HOOK-TELE-003 | JSONL schema MUST include `at, elapsed_s, c3i_rc, fy27_rc, c3i, fy27` keys | HIGH |
| SC-STOP-HOOK-TELE-004 | Telemetry append failure MUST NOT propagate (best-effort) | CRITICAL |
| SC-STOP-HOOK-TELE-005 | `elapsed_s >= 5` for 3 consecutive runs triggers P1 sa-plan task | MEDIUM |
| SC-STOP-HOOK-TELE-006 | Log MUST be append-only; rotation only via dedicated cron | MEDIUM |

## JSONL schema

```json
{"at":"YYYYMMDD-HHMM","elapsed_s":N,"c3i_rc":N,"fy27_rc":N,"c3i":"ok|degraded","fy27":"ok|absent|timeout|degraded"}
```

Example (live, 2026-05-16 08:26):
```
{"at":"20260516-0826","elapsed_s":0,"c3i_rc":0,"fy27_rc":127,"c3i":"ok","fy27":"absent"}
```

`elapsed_s=0` means sub-second completion (healthy). `elapsed_s>=5` is the SC-STOP-HOOK-TELE-005 alert threshold.

## Anti-pattern guard

Per [zk-bd82645aedcb5ef4]: this rule does NOT assert performance — it records it. Future Lyapunov detectors will read this log via:

```sql
-- next-pass detector example
SELECT COUNT(*) FROM jsonl_rows WHERE elapsed_s >= 5
  AND at > (now - 1h)
```

## Cross-references

- `.claude/rules/corpus-index.md` (SC-CORPUS-INDEX) — sibling perf-invariant guard
- `.claude/rules/cpig-consistency.md` (SC-CPIG-CONSISTENCY) — sibling governance-honesty guard
- `sub-projects/scripts-gleam/src/scripts/sysd/stop_hook.gleam` — emitter
- `data/logs/stop-hook-timing.log` — rolling forensic log
- `docs/journal/perf-bench-20260516/journal.md` — Lyapunov arc baseline

## Governance parity

Mirror at `.gemini/rules/stop-hook-telemetry.md` per SC-SYNC-DOC-007.
