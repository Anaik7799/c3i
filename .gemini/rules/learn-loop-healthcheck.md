# Learn-Loop Health Check Protocol (SC-LEARN-LOOP-HEALTHCHECK)

## Mandate

**One operator command MUST be able to verify the entire institutional-memory-loop defense-in-depth ring shipped in the perf-bench-20260516 closure arc.** Without an aggregator, each of the 5 validators must be invoked individually — operationally tedious and unlikely to be run regularly.

Anti-Stub-That-Lies per [zk-bd82645aedcb5ef4]: the aggregator actually invokes each validator via FFI and parses its real classification line. It does not assert health.

ZK lineage: [zk-bd82645aedcb5ef4] Stub-That-Lies (RPN 729), [zk-c14e1d23afff486c] implicit-invariant family, perf-bench-20260516 closure pack, [zk-426c4adf07d076ad] sibling telemetry pattern.

## Aggregated validators (5 — full ring)

| # | Validator | Layer | Function |
|---|---|---|---|
| 1 | `cpig_consistency` | L5 | governance honesty (score ↔ evidence) |
| 2 | `corpus_index` | L3 | structural perf invariant (6 required indexes) |
| 3 | `stop_hook_lyapunov` | L5 | stop-hook telemetry consumer |
| 4 | `disk_trend` | L4 | disk capacity emit + classify |
| 5 | `disk_lyapunov` | L5 | disk trajectory consumer |

## STAMP Constraints

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-LEARN-LOOP-HEALTHCHECK-001 | Aggregator MUST invoke each of the 5 validators via `gleam run` | HIGH |
| SC-LEARN-LOOP-HEALTHCHECK-002 | Aggregator MUST parse classification lines (`✗ P0 —`, `✗ P1 —`, `⚠ P2 —`) — NOT hint-string substrings | CRITICAL |
| SC-LEARN-LOOP-HEALTHCHECK-003 | Aggregator MUST print a unified summary table | HIGH |
| SC-LEARN-LOOP-HEALTHCHECK-004 | Adding a new institutional-memory-loop validator MUST append it to the `validators` list in the SAME commit | HIGH |
| SC-LEARN-LOOP-HEALTHCHECK-005 | Aggregator output MUST end with either `✓ all N validators report homeostasis` or `✗ N validator(s) reported alarm` | HIGH |

## Reference run (2026-05-16, post-7-pass closure arc)

```
$ gleam run -m scripts/verify/learn_loop_healthcheck
══ Learn-Loop Health Check (SC-LEARN-LOOP-HEALTHCHECK) ══
── scripts/verify/cpig_consistency ──
   ✓ CPIG matrix consistent: all score=1 gates have evidence
── scripts/verify/corpus_index ──
   ✓ all 6 required indexes present
── scripts/verify/stop_hook_lyapunov ──
   ✓ λ = 0 — OODA Learn loop in homeostasis
── scripts/verify/disk_trend ──
   ⚠ P2 — watch (perf-bench-20260516 baseline)
── scripts/verify/disk_lyapunov ──
   ✓ λ ≤ 0 — disk usage stable

── summary ──
  ✓  scripts/verify/cpig_consistency
  ✓  scripts/verify/corpus_index
  ✓  scripts/verify/stop_hook_lyapunov
  ✓  scripts/verify/disk_trend
  ✓  scripts/verify/disk_lyapunov

✓ all 5 validators report homeostasis
```

(Note: `disk_trend` prints `⚠ P2 — watch` for the live 88% baseline; aggregator treats P2 as informational, not alarm.)

## Cross-references — full defense-in-depth ring

- `.claude/rules/cpig-consistency.md` (SC-CPIG-CONSISTENCY)
- `.claude/rules/corpus-index.md` (SC-CORPUS-INDEX)
- `.claude/rules/stop-hook-telemetry.md` (SC-STOP-HOOK-TELE)
- `.claude/rules/stop-hook-lyapunov.md` (SC-STOP-HOOK-LYAPUNOV)
- `.claude/rules/fy27-peer-optional.md` (SC-FY27-PEER-OPTIONAL)
- `.claude/rules/disk-trend.md` (SC-DISK-TREND)
- `.claude/rules/disk-lyapunov.md` (SC-DISK-LYAPUNOV)
- `docs/journal/perf-bench-20260516/journal.md` — closure pack journal

## Governance parity

Mirror at `.gemini/rules/learn-loop-healthcheck.md` per SC-SYNC-DOC-007.
