# Disk Trend Monitor Protocol (SC-DISK-TREND)

## Mandate

**Filesystem usage on the C3I dev host MUST be observed periodically.** Perf-bench-20260516 baseline measured `/dev/sda2 at 88% used (1.2 TB total, 145 GB free)`. Without a rolling trend log, runtime hazards (Smriti.db growth blocked, WAL checkpoint failure, cargo build OOD) only surface when a write fails — too late.

Anti-Stub-That-Lies per [zk-bd82645aedcb5ef4]: the monitor reads `df -P /` and appends real measurements; it does not assert any state.

ZK lineage: [zk-bd82645aedcb5ef4] Stub-That-Lies (RPN 729), [zk-f8f40cb7e63db61a] next-pass roadmap, [zk-426c4adf07d076ad] sibling telemetry pattern, perf-bench-20260516 § 10 (Remaining Gaps).

## Alert tiers

| Threshold | Tier | Meaning |
|---|---|---|
| `used >= 95%` | P0 | Runtime hazard — Smriti.db growth blocked, cargo build will fail |
| `used >= 90%` | P1 | Sustained pressure — plan a cleanup pass |
| `used >= 80%` | P2 | Watch — perf-bench-20260516 baseline (88%) |
| else | ✓ | Nominal |

## STAMP Constraints

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-DISK-TREND-001 | Monitor MUST read `df -P /` (not `df -h` — POSIX block units stable across coreutils versions) | HIGH |
| SC-DISK-TREND-002 | Monitor MUST append one JSONL row per invocation to `data/logs/disk-trend.log` | HIGH |
| SC-DISK-TREND-003 | JSONL schema MUST include `at, pct, used_kb, avail_kb` | HIGH |
| SC-DISK-TREND-004 | Classification MUST follow the 4-tier table above | HIGH |
| SC-DISK-TREND-005 | Log MUST be gitignored (rolling forensic, not committed) | MEDIUM |
| SC-DISK-TREND-006 | P0 / P1 outcomes MUST emit a `sa-plan add --priority` hint | HIGH |

## Reference implementation

`sub-projects/scripts-gleam/src/scripts/verify/disk_trend.gleam` (~90 LOC) — single FFI call to `df -P /`, parse capacity column, append + classify.

```
$ gleam run -m scripts/verify/disk_trend
══ Disk Trend Monitor (SC-DISK-TREND) ══
used: 88%
⚠ P2 — watch (perf-bench-20260516 baseline)
```

JSONL row format:
```json
{"at":"20260516-0833","pct":88,"used_kb":1022505404,"avail_kb":151976460}
```

## Cross-references

- `.claude/rules/stop-hook-telemetry.md` (SC-STOP-HOOK-TELE) — sibling JSONL pattern
- `.claude/rules/stop-hook-lyapunov.md` (SC-STOP-HOOK-LYAPUNOV) — sibling consumer pattern
- `.claude/rules/corpus-index.md` (SC-CORPUS-INDEX) — Smriti.db perf depends on free space
- `docs/journal/perf-bench-20260516/benchmarks.md` § Disk — 88% baseline measurement

## Governance parity

Mirror at `.gemini/rules/disk-trend.md` per SC-SYNC-DOC-007.
