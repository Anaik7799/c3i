# Corpus Index Protocol (SC-CORPUS-INDEX)

## Mandate

**Smriti.db MUST carry the 6 performance indexes installed by perf-bench-20260516 Phase A.** Without them, stop-hook ingest regresses from 9 ms warm to ~25 s cold (2,777× slowdown), driving the OODA Learn loop back into the Wolfram Rule 30 chaos regime observed pre-Pass-15 [zk-bd82645aedcb5ef4].

ZK lineage: [zk-bd82645aedcb5ef4] Stub-That-Lies (RPN 729), [zk-c14e1d23afff486c] implicit-invariant family, [zk-f8f40cb7e63db61a] next-pass roadmap, perf-bench-20260516 closure pack.

## STAMP Constraints

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-CORPUS-INDEX-001 | `holons.idx_holons_content_hash` MUST exist (dedup lookup O(log N)) | CRITICAL |
| SC-CORPUS-INDEX-002 | `ingest_state.idx_ingest_state_mtime` MUST exist (mtime fast-path) | CRITICAL |
| SC-CORPUS-INDEX-003 | `holons.idx_holons_cluster|level|entropy|updated` MUST exist (pre-existing baseline) | HIGH |
| SC-CORPUS-INDEX-004 | Validator `scripts/verify/corpus_index` MUST exit 0 on every push | HIGH |
| SC-CORPUS-INDEX-005 | Smriti schema migrations that drop or rename any required index MUST add the replacement in the SAME commit | CRITICAL |
| SC-CORPUS-INDEX-006 | When total holons > 10k AND any required index missing, open P0 sa-plan task within 60s | CRITICAL |

## AOR Rules

| ID | Rule |
|----|------|
| AOR-CORPUS-IDX-001 | NEVER alter Smriti schema without running `gleam run -m scripts/verify/corpus_index` |
| AOR-CORPUS-IDX-002 | ALWAYS verify with `EXPLAIN QUERY PLAN` that content_hash lookup uses `idx_holons_content_hash` after schema work |
| AOR-CORPUS-IDX-003 | NEVER use `DROP INDEX` on any name in the required list without an immediate `CREATE INDEX` replacement |

## Reference implementation

`sub-projects/scripts-gleam/src/scripts/verify/corpus_index.gleam` — 6-index scanner via `sqlite3 sqlite_master` query.

```
$ gleam run -m scripts/verify/corpus_index
══ Corpus Index Validator (SC-CORPUS-INDEX) ══
✓ all 6 required indexes present
```

## Performance evidence (perf-bench-20260516)

| Operation | Pre-index | Post-index | Speedup |
|---|---|---|---|
| ingest-docs warm (37,889 rows) | 24,955 ms | 9 ms | **2,777×** |
| stop-hook chain (full ingest) | ✗ 50s timeout | ✓ 1.9 s | **26×** margin |
| dedup query plan | `SCAN holons` (full table) | `SEARCH USING COVERING INDEX idx_holons_content_hash` | O(N) → O(log N) |

## Cross-references

- `.claude/rules/cpig-consistency.md` (SC-CPIG-CONSISTENCY) — sibling governance-honesty validator
- `.claude/rules/cross-pass-invariant-gate.md` (SC-CPIG-008) — Lyapunov non-regression parent
- `sub-projects/c3i/native/planning_daemon/src/ingest.rs` — Phase A schema (lines 1-48)
- `docs/journal/perf-bench-20260516/benchmarks.md` — raw evidence

## Governance parity

Mirror at `.gemini/rules/corpus-index.md` per SC-SYNC-DOC-007.
