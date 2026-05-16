# CPIG Matrix Consistency Protocol (SC-CPIG-CONSISTENCY)

## Mandate

**Every gate scoring `1` in `docs/journal/task-116480247290237220/cpig-matrix.json` MUST carry a non-empty `evidence` array.** Score↔evidence drift is the failure class that produced the Pass-15 dishonesty (62/65 claimed → 60/65 honest after mechanical recount).

ZK lineage: [zk-bd82645aedcb5ef4] Stub-That-Lies (RPN 729), [zk-ca8c05bebfcae93f] Anti-Stub-That-Lies mechanical verification, [zk-f8f40cb7e63db61a] next-pass candidates, [zk-c14e1d23afff486c] implicit-invariant family.

## STAMP Constraints

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-CPIG-CONSISTENCY-001 | Every gate with `score=1` MUST have `evidence.length >= 1` | CRITICAL |
| SC-CPIG-CONSISTENCY-002 | The validator `scripts/verify/cpig_consistency` MUST exit 0 on every push | CRITICAL |
| SC-CPIG-CONSISTENCY-003 | A gate evidence string MUST NOT contain the literal `"gap"` when `score=1` | HIGH |
| SC-CPIG-CONSISTENCY-004 | Bumping a gate from 0→1 MUST add the proof artefact in the SAME commit | CRITICAL |
| SC-CPIG-CONSISTENCY-005 | Any consistency violation MUST open a P1 sa-plan task within 60s of detection | HIGH |

## AOR Rules

| ID | Rule |
|----|------|
| AOR-CPIG-CONS-001 | NEVER score a gate `1` without naming the artefact (TLA+ file, wiring_guard test, holon tag, email Message-ID) |
| AOR-CPIG-CONS-002 | ALWAYS run `gleam run -m scripts/verify/cpig_consistency` before pushing matrix changes |
| AOR-CPIG-CONS-003 | ALWAYS pair `zk_ingestion.score = 1` with a holon count > 0 query result in the same commit |

## Reference implementation

`sub-projects/scripts-gleam/src/scripts/verify/cpig_consistency.gleam` (107 LOC) — parses the matrix JSON, scans 13 × 5 = 65 gates, prints violations + sa-plan hint.

```
$ gleam run -m scripts/verify/cpig_consistency
══ CPIG Consistency Validator (SC-CPIG-CONSISTENCY) ══
✓ CPIG matrix consistent: all score=1 gates have evidence
```

## Cross-references

- `.claude/rules/cross-pass-invariant-gate.md` (SC-CPIG-001..015) — parent governance family
- `.claude/rules/wiring-guard.md` (SC-WIRE-001..007) — type-domain sibling
- `.claude/rules/value-guard.md` (SC-VALUE-GUARD-001..008) — value-domain sibling
- `sub-projects/scripts-gleam/src/scripts/verify/cpig_validator.gleam` — companion drift detector (informational)
- `docs/journal/perf-bench-20260516/` — Pass-15 closure pack that motivated this rule

## Governance parity

Mirror at `.gemini/rules/cpig-consistency.md` per SC-SYNC-DOC-007.
