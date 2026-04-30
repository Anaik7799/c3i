# Value Guard Protocol (SC-VALUE-GUARD-001..008)

## Mandate

**Every L3 ingest path that writes a value-domain field (priority, status, role,
state-enum) MUST validate the value against a canonical whitelist before
INSERT/UPDATE.** This is the value-domain parallel to SC-WIRE-001..007 (which
guards type drift) — together they form the wiring-guard family.

ZK lineage: [zk-907c636b4bbf0d73] silent-metric-drift · [zk-a97c474c58e95bd8]
pass-9 closure of /planning data poison · [zk-bb4de67d97f807ac] selector-guessing
(runtime-truth-not-static-list family).

## Why this rule exists

Pass-7 (2026-04-29) shipped the closure of an 83-row data-poison incident on
the `/planning` Tasks table. Forensics traced the bug class to:

| Layer | Defect |
|---|---|
| L1 NIF | `c3i_nif::plan_add_task` accepted `priority: String` with no whitelist (`plan_update_task` had a whitelist on `status` since day-1; the asymmetry was the silent failure mode) |
| L3 Rust | `db::add_task` and `db::update_task_status` accepted `&str` arbitrarily |
| L4 Schema | No `CHECK` constraint on Tasks columns |

Result: 8 rows of `Status='Completed'` (capital, leaked from Pi-mono), 5 rows
of `Priority='--priority'` (literal CLI flag stored as the value), 3
`SUPREME`, 2 `high`, 65 `SimTest task #N` fixture spam — **83 total**, all
visible to the operator on `/planning`, all rendering as grey badges because
the colour map was keyed lower-case-only.

SC-WIRE protects the *type* boundary (Model fields, Msg variants) but not the
*value-domain*. SC-VALUE-GUARD closes that gap.

## STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-VALUE-GUARD-001 | Every value-domain enum field MUST have a canonical set declared in code (Gleam `const` / Rust `&'static [&str]`) | CRITICAL |
| SC-VALUE-GUARD-002 | Every L1 NIF that ingests a value-domain field MUST whitelist before INSERT/UPDATE | CRITICAL |
| SC-VALUE-GUARD-003 | Every L3 daemon function that ingests a value-domain field MUST call `validate_*` before INSERT/UPDATE | CRITICAL |
| SC-VALUE-GUARD-004 | Every L4 SQL table column with a value-domain enum MUST carry a `CHECK (col IN (…))` constraint | HIGH |
| SC-VALUE-GUARD-005 | When NIF + daemon both exist, both MUST gate (defense-in-depth — neither is allowed to omit) | CRITICAL |
| SC-VALUE-GUARD-006 | A periodic scan worker MUST detect drift across the entire stored set at least hourly | HIGH |
| SC-VALUE-GUARD-007 | Cleanup mutations MUST be atomic (BEGIN IMMEDIATE … COMMIT) and MUST emit one audit row per mutation before the actual UPDATE/DELETE | CRITICAL |
| SC-VALUE-GUARD-008 | A formal spec (TLA+ or Agda) MUST exist for the gate chain, model-checked at least weekly | HIGH |

## AOR Rules

| ID | Rule |
|----|------|
| AOR-VALUE-GUARD-001 | NEVER add a NIF or daemon function that takes a value-domain enum as a raw string without a whitelist |
| AOR-VALUE-GUARD-002 | When adding a new enum field, add the canonical-set constant + validators in the SAME commit |
| AOR-VALUE-GUARD-003 | When adding a new SQL table with enum columns, add the CHECK constraints in the migration script |
| AOR-VALUE-GUARD-004 | Update the TLA+ spec's `ValidPriorities` / `ValidStatuses` / etc. constants when canonical sets change |
| AOR-VALUE-GUARD-005 | A weekly cron MUST run the formal-check workflow (`tlc DataQualityIngest.tla`) and alert on any counter-example |

## Reference implementation (pass-7 + pass-9 shipped)

### L1 NIF gate (Gleam)

`lib/cepaf_gleam/native/c3i_nif/src/planning.rs:118` (plan_add_task) and
`:144` (plan_update_task) both carry whitelists:

```rust
let valid = ["P0", "P1", "P2", "P3"];
if !valid.contains(&priority.as_str()) {
    return Ok(format!(
        "{{\"ok\":false,\"error\":\"Invalid priority '{}'. Valid: {:?}\"}}",
        priority, valid
    ));
}
```

### L3 Rust validators

`sub-projects/c3i/native/planning_daemon/src/db.rs`:

```rust
pub const VALID_PRIORITIES: &[&str] = &["P0", "P1", "P2", "P3"];
pub const VALID_STATUSES:   &[&str] = &["pending", "in_progress", "completed", "blocked"];

pub fn validate_priority(p: &str) -> Result<&'static str, IgnitionError> { … }
pub fn validate_status(s: &str)   -> Result<&'static str, IgnitionError> { … }
pub fn normalize_status(s: &str)  -> String { … }   // lower-cases iff matches canonical
```

`add_task` and `update_task_status` call these before `conn.execute`.

### L4 SQLite CHECK constraint

`Tasks` table schema:

```sql
CREATE TABLE Tasks (
  Id TEXT PRIMARY KEY,
  Title TEXT NOT NULL,
  Status TEXT NOT NULL CHECK (Status IN ('pending','in_progress','completed','blocked')),
  Priority TEXT NOT NULL CHECK (Priority IN ('P0','P1','P2','P3')),
  ParentId TEXT, Owner TEXT,
  Created TEXT NOT NULL, RawLines TEXT
);
```

Verified live: `INSERT … Priority='XXX'` → `CHECK constraint failed: Priority IN ('P0','P1','P2','P3')`.

### Periodic drift detector (cron)

`sub-projects/scripts-gleam/src/scripts/verify/data_quality_scan.gleam` — hourly + 5-min canary
schedules registered via `sa-plan schedule-add`.

### Atomic cleanup with audit

`dq_audit` table (added pass-7) snapshots before-state for every mutation in
the cleanup transaction; idempotent (re-running affects 0 rows).

### Formal spec

`specs/tla/DataQualityIngest.tla` (pass-9, 170 LOC) proves
`I_VALID ∧ I_AUDIT ∧ I_GATES ∧ ScanEventuallyQuiet`.

## RETE-UL rules (Gleam `rules/engine.gleam` data_quality domain)

7 rules salience 75-100; salience 100 rules fire FIRST per RETE conflict
resolution:

| Salience | Rule | Decision |
|---:|---|---|
| 100 | EnforceEnumPriority | Reject |
| 100 | EnforceEnumStatus | Normalize |
| 95 | BlockSpamFixture | Reject |
| 95 | PageSpecAlignmentLow | BlockReleaseToProd |
| 90 | P0PriorityQuota | Backpressure (Slurm-style) |
| 80 | WindowOpenPopupBlocker | FallbackInPagePanel |
| 75 | PaginationBackpressure | DemandRemotePagination |

## Cross-references
- `.claude/rules/wiring-guard.md` (SC-WIRE-001..007) — sibling for type-domain
- `.claude/rules/page-spec-checker.md` (SC-PAGE-SPEC-001..008) — sibling for spec conformance
- `.claude/rules/post-feature-evolution.md` — adds SC-VALUE-GUARD audit to the post-feature pipeline
- `specs/tla/DataQualityIngest.tla` — formal model
- `lib/cepaf_gleam/src/cepaf_gleam/rules/engine.gleam` — RETE-UL data_quality domain (lines 813+)
- `docs/journal/task-116491660660910166/` — pass-9 closure journal + 6 PNG diagrams

## Governance parity
Mirror at `.gemini/rules/value-guard.md` next sync (SC-SYNC-DOC-007).
