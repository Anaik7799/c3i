# Disk Lyapunov Detector Protocol (SC-DISK-LYAPUNOV)

## Mandate

**The disk-trend JSONL feed MUST be consumed by a detector that catches sustained growth.** SC-DISK-TREND classifies the *current sample* — useful for snapshot, useless for trajectory. A pattern like 80% → 85% → 90% across 3 disk_trend invocations is the **trajectory** toward the 95% runtime-hazard line, and the operator needs the alert *during the climb*, not at the peak.

Anti-Stub-That-Lies per [zk-bd82645aedcb5ef4]: the detector parses real samples from `data/logs/disk-trend.log`, never asserts free-space state.

ZK lineage: [zk-bd82645aedcb5ef4] Stub-That-Lies (RPN 729), [zk-c14e1d23afff486c] implicit-invariant family, perf-bench-20260516 § 10 (Remaining Gaps), [zk-426c4adf07d076ad] sibling LYAPUNOV-pattern parent.

## Alert tiers

| Threshold | Tier | Meaning |
|---|---|---|
| `max(last 10) >= 95%` | P0 | Runtime hazard |
| `max(last 10) >= 90%` | P1 | Elevated baseline |
| `last - first >= 5%` across last 10 samples | P1 | Sustained growth trajectory |
| else | ✓ | λ ≤ 0, stable |

## STAMP Constraints

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-DISK-LYAPUNOV-001 | Detector MUST read last 10 JSONL rows from `data/logs/disk-trend.log` | HIGH |
| SC-DISK-LYAPUNOV-002 | Detector MUST classify per the 4-tier table above | HIGH |
| SC-DISK-LYAPUNOV-003 | P0 / P1 outcomes MUST emit a `sa-plan add --priority` hint | HIGH |
| SC-DISK-LYAPUNOV-004 | Detector MUST tolerate empty/missing log without crashing | CRITICAL |
| SC-DISK-LYAPUNOV-005 | Detector MUST be invokable as `gleam run -m scripts/verify/disk_lyapunov` | HIGH |

## Reference implementation

`sub-projects/scripts-gleam/src/scripts/verify/disk_lyapunov.gleam` (~110 LOC) — tails 10 JSONL rows via FFI, extracts `pct`, applies 4-tier classification with both max-threshold and delta-threshold tests.

```
$ gleam run -m scripts/verify/disk_lyapunov
══ Disk Lyapunov Detector (SC-DISK-LYAPUNOV) ══
samples=2 first=88% last=88% max=88% Δ=0
✓ λ ≤ 0 — disk usage stable
```

## Mathematical model

```
Let R = last_10_rows from data/logs/disk-trend.log
Let P = [ row.pct for row in R ]
Let max_p = max(P)
Let Δ = last(P) - first(P)

decision = match (max_p, Δ):
  (m, _) where m >= 95  → P0 RUNTIME HAZARD
  (m, _) where m >= 90  → P1 ELEVATED
  (_, d) where d >= 5   → P1 SUSTAINED GROWTH
  (_, _)                → ✓ STABLE
```

## Pattern symmetry

This is the disk-domain mirror of SC-STOP-HOOK-LYAPUNOV. Together they form a uniform 2-stage observability pattern across both telemetry channels:

| Channel | Emitter | Detector |
|---|---|---|
| Stop-hook timing | SC-STOP-HOOK-TELE | SC-STOP-HOOK-LYAPUNOV |
| Disk capacity | SC-DISK-TREND | SC-DISK-LYAPUNOV |

## Cross-references

- `.claude/rules/disk-trend.md` (SC-DISK-TREND) — producer
- `.claude/rules/stop-hook-lyapunov.md` (SC-STOP-HOOK-LYAPUNOV) — pattern parent
- `.claude/rules/stop-hook-telemetry.md` (SC-STOP-HOOK-TELE) — sibling emitter
- `docs/journal/perf-bench-20260516/journal.md` § 10 — origin of the disposition

## Governance parity

Mirror at `.gemini/rules/disk-lyapunov.md` per SC-SYNC-DOC-007.
