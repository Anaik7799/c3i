# Stop-Hook Lyapunov Detector Protocol (SC-STOP-HOOK-LYAPUNOV)

## Mandate

**The OODA Learn loop MUST be monitored for regression via the rolling JSONL feed produced under SC-STOP-HOOK-TELE.** Three alert tiers govern operator escalation:

| Threshold | Tier | Meaning |
|---|---|---|
| any single `elapsed_s >= 30` | P0 | Approaching the 50 s pre-Phase-A timeout boundary |
| `>= 3` of last 10 runs with `elapsed_s >= 5` | P1 | Sustained sub-second baseline broken |
| `1..2` of last 10 with `elapsed_s >= 5` | P2 | Transient spike — monitor |
| else | ✓ | λ = 0, homeostasis |

This rule closes the loop opened by perf-bench-20260516: SC-STOP-HOOK-TELE emits, this detector observes. Without it, the JSONL feed is unread substrate. Anti-Stub-That-Lies per [zk-bd82645aedcb5ef4] — the detector parses real measurements, never asserts performance.

ZK lineage: [zk-bd82645aedcb5ef4] Stub-That-Lies (RPN 729), [zk-c14e1d23afff486c] implicit-invariant family, [zk-426c4adf07d076ad] SC-STOP-HOOK-TELE producer, [zk-f8f40cb7e63db61a] next-pass roadmap.

## STAMP Constraints

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-STOP-HOOK-LYAPUNOV-001 | Detector MUST read the last 10 JSONL rows from `data/logs/stop-hook-timing.log` | HIGH |
| SC-STOP-HOOK-LYAPUNOV-002 | Detector MUST classify per the 4-tier table above | HIGH |
| SC-STOP-HOOK-LYAPUNOV-003 | P0 / P1 outcomes MUST emit a `sa-plan add --priority` hint | HIGH |
| SC-STOP-HOOK-LYAPUNOV-004 | Detector MUST tolerate empty/missing log without crashing | CRITICAL |
| SC-STOP-HOOK-LYAPUNOV-005 | Detector MUST be invokable as `gleam run -m scripts/verify/stop_hook_lyapunov` | HIGH |
| SC-STOP-HOOK-LYAPUNOV-006 | Detector SHOULD run hourly via sa-plan-daemon workflow_schedules (deferred — manual invocation acceptable for P3) | MEDIUM |

## Reference implementation

`sub-projects/scripts-gleam/src/scripts/verify/stop_hook_lyapunov.gleam` (~110 LOC) — tails 10 JSONL rows via FFI, extracts `elapsed_s`, applies 4-tier classification.

```
$ gleam run -m scripts/verify/stop_hook_lyapunov
══ Stop-Hook Lyapunov Detector (SC-STOP-HOOK-LYAPUNOV) ══
samples=2 max_elapsed_s=0 high(>=5s)=0 high(>=30s)=0
✓ λ = 0 — OODA Learn loop in homeostasis
```

## Mathematical model

```
Let R = last_10_rows from data/logs/stop-hook-timing.log
Let E = { row.elapsed_s : row ∈ R }
Let high_5  = |{ e ∈ E : e ≥ 5 }|
Let high_30 = |{ e ∈ E : e ≥ 30 }|

decision = match (high_30, high_5):
  (n, _) where n > 0  → P0 ALARM
  (_, n) where n ≥ 3  → P1 ALARM (sustained)
  (_, n) where n ≥ 1  → P2 WATCH
  (_, _)              → ✓ HEALTHY (λ = 0)
```

## Cross-references

- `.claude/rules/stop-hook-telemetry.md` (SC-STOP-HOOK-TELE) — producer
- `.claude/rules/corpus-index.md` (SC-CORPUS-INDEX) — root-cause perf invariant
- `.claude/rules/cpig-consistency.md` (SC-CPIG-CONSISTENCY) — governance-honesty sibling
- `sub-projects/scripts-gleam/src/scripts/sysd/stop_hook.gleam` — JSONL emitter
- `docs/journal/perf-bench-20260516/journal.md` — Lyapunov arc baseline (T1-T9)

## Governance parity

Mirror at `.gemini/rules/stop-hook-lyapunov.md` per SC-SYNC-DOC-007.
