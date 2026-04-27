# Pass-5 Regression Suite Result

**🔗 HTTPS Link**: https://vm-1.tail55d152.ts.net:8443/task-id/116450171390820012/20260422-212140-task-116450171390820012-swarm-ignition-ultrapass5-regression.md

**Task**: 116450171390820012 · Child: 116450172205924106 · Date: 2026-04-23 05:15 UTC

---

## 1. Summary

| Metric | Pass-4 | Pass-5 | Delta |
|---|---|---|---|
| Gleam test files | 223 | 220 | -3 (consolidated) |
| Gleam test LOC | 82,991 | 82,869 | -122 |
| Tests executed | 8,979 | 8,980 | +1 |
| Tests passed | 8,979 | **8,980** | +1 |
| Tests failed | 0 | **0** | 0 |
| Build warnings | many | many | — |
| Build errors | 0 | **0** | 0 |
| Build time | 0.24 s | 0.23 s | -0.01 s |

## 2. Test categories observed (C1–C10)

From the test runner boot log:

- `[C3I] ETS cache initialised`
- `[FRESHNESS-ACTOR] Initialised — level=fresh`
- `[C3I] Self-observer actor initialised (60 s cycle)`
- `[GUARD-GRID-ACTOR] Initialised — running first OODA tick`
- `[GUARD-GRID] HOT RELOAD triggered [health=1.0 entropy=0.0 lyapunov=-3.73 cascade=false]`
- `[C3I] Sentinel patrol initialised (35 pages)`
- `[C3I] Endocrine system initialised (7 hormones)`
- `[C3I] Immune learning initialised (antibody synthesis)`
- `[C3I] Health derivative tracker initialised (d(H)/dt)`
- `[C3I] Failure classifier ready (Poisson/Bursty/Periodic)`
- `[C3I] Zenoh federation initialised (europe-north1)`
- `[C3I] CRDT version vector initialised (c3i-primary)`
- `[C3I] IEC 61508 evidence loaded (coverage: 86%)`
- `[C3I] Claude metrics initialised (session: gleam-1776921287422)`
- `[C3I] All subsystems started. System is ALIVE.`

## 3. Triple-interface coverage

| Interface | Modules | Status |
|---|---|---|
| Lustre SSR pages | 53 | ✅ all build |
| Wisp REST handlers | 34 | ✅ all build |
| TUI views | 50 | ✅ all build |
| AG-UI event types | 34 | ✅ (target was 32; +2 evolved) |

## 4. Math gates (inherited, last audit)

| Gate | Value | Threshold | Pass |
|---|---|---|---|
| Shannon entropy H | 2.67 | ≥ 2.5 | ✅ |
| CCM | 0.770 | ≥ 0.90 | ⚠️ |
| ITQS | 0.736 | ≥ 0.85 | ⚠️ |
| D_EA | — | ≤ 0.10 | need audit |
| Tab coverage | 100 % | 100 % | ✅ |

CCM and ITQS are below gate — this becomes a pass-6 remediation target (no new child tasks needed; inherited from pass-4 gate).

## 5. Conclusion

- Green build, green tests.
- 1 new passing test observed (pass-5 additions to zenoh_otel.gleam).
- Net system delta: +1 test, -3 files, -122 LOC → **consolidation pass** (lower muda).
- CCM/ITQS remediation remains open; not blocking.
