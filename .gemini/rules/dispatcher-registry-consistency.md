# Dispatcher Registry Consistency Protocol (SC-DISP-REGISTRY)

> Pass-11 governance artefact. Task: 116480247290237220.
> Sibling-family ZK refs: [zk-bb4de67d97f807ac] (selector-guessing parent anti-pattern — "the source-of-truth is the running system, not a static list"), [zk-c14e1d23afff486c] (implicit-invariant family — silent drift between two co-dependent lists).

## SUPREME MANDATE — INVIOLABLE

**Every worker name in `sub-projects/c3i/native/planning_daemon/src/workers.rs::dispatch` match arms MUST appear in `known_workers()`, AND every name in `known_workers()` MUST have a corresponding match arm.**

**The legacy `scheduler.rs` workflow path MUST NOT introduce new oban worker names** — it is deprecated; new workers land exclusively in `workers.rs::dispatch` so that the registry stays the single source of truth.

This rule prevents the Pass-10 production incident (commit `106862017d`) where a worker was wired into `dispatch()` without being added to `known_workers()`, causing oban_jobs to be silently rejected as "unknown worker" while the daemon claimed registry health.

## Why this rule exists (anti-pattern lineage)

The bug pattern is identical to the Marionette "selector-guessing" failure mode [zk-bb4de67d97f807ac]: **two parallel lists describing the same truth, kept in sync only by human discipline**. The Gleam analogue (SC-WIRE-001) already mandates that adding a Model field MUST update `wiring_guard.gleam` in the same commit; this rule is its Rust counterpart.

```
known_workers()           dispatch() match arms
       │                          │
       └────── must be ═══════════┘
              symmetric
```

Drift in either direction is silent until production fires a job — and then it fires P0.

## STAMP Constraints

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-DISP-REGISTRY-001 | `workers.rs` is the SINGLE authoritative dispatcher for `oban_jobs`. No other module may pattern-match on worker name strings to dispatch jobs. | CRITICAL |
| SC-DISP-REGISTRY-002 | Every match arm name in `workers.rs::dispatch` MUST be present in `known_workers()`. Missing entries are a build-blocking violation. | CRITICAL |
| SC-DISP-REGISTRY-003 | Every name in `known_workers()` MUST have a corresponding match arm in `dispatch()`. Orphan registrations are a build-blocking violation. | CRITICAL |
| SC-DISP-REGISTRY-004 | The legacy `scheduler.rs` workflow path MUST NOT add new oban worker names. It is deprecated; new workers land in `workers.rs::dispatch` only. | HIGH |
| SC-DISP-REGISTRY-005 | `tests/dispatcher_registry_test.rs` MUST run on every PR (CI gate); a failure blocks merge. | CRITICAL |
| SC-DISP-REGISTRY-006 | Adding a worker requires updates to BOTH `known_workers()` AND `dispatch()` in the SAME commit. Split commits are a violation. | HIGH |
| SC-DISP-REGISTRY-007 | Worker names MUST be `lowercase_snake_case` ASCII strings. No camelCase, no kebab-case, no whitespace. | HIGH |
| SC-DISP-REGISTRY-008 | Worker name strings MUST be unique. No two names may differ only in case, whitespace, or trailing punctuation. | HIGH |
| SC-DISP-REGISTRY-009 | `known_workers()` MUST be sorted alphabetically (stable diff hygiene). | MEDIUM |
| SC-DISP-REGISTRY-010 | Any `"unknown worker"` error observed in production logs MUST trigger a P0 sa-plan task within 60 seconds via the audit pipeline. | CRITICAL |

## AOR Rules

| ID | Rule |
|----|------|
| AOR-DISP-REGISTRY-001 | BEFORE adding a new oban worker, READ `workers.rs` end-to-end and confirm the registry pattern. |
| AOR-DISP-REGISTRY-002 | ALWAYS update `known_workers()` and `dispatch()` together in the same commit (atomic wiring). |
| AOR-DISP-REGISTRY-003 | NEVER duplicate a worker name across `scheduler.rs` (legacy) and `workers.rs` (current). Pick `workers.rs`. |
| AOR-DISP-REGISTRY-004 | RUN `cargo test -p planning_daemon --test dispatcher_registry_test` before pushing any change touching `workers.rs`. |
| AOR-DISP-REGISTRY-005 | RUN the scripts-gleam validator (`gleam run -m scripts/verify/dispatcher_registry`) as part of the pre-commit gate. |
| AOR-DISP-REGISTRY-006 | NEVER silently swallow `"unknown worker"` errors — propagate as P0 task. |
| AOR-DISP-REGISTRY-007 | When deprecating a worker, remove it from BOTH `known_workers()` AND `dispatch()` in the same commit. |
| AOR-DISP-REGISTRY-008 | DOCUMENT every new worker in the journal with its URN, fractal layer, and FMEA row. |

## Pre-commit Gate (scripts-gleam validator)

Per SC-SCRIPT-GLEAM-001, the validator is implemented as a Gleam module — **not** a shell script:

```
cd sub-projects/scripts-gleam
gleam run -m scripts/verify/dispatcher_registry
```

The validator MUST:

1. Parse `sub-projects/c3i/native/planning_daemon/src/workers.rs` and extract:
   - the `known_workers()` returned vector
   - every `match` arm name in `dispatch()`
2. Compute `A = match_arms - known_workers` (orphan match arms) and `B = known_workers - match_arms` (orphan registrations).
3. Fail (exit 1) if `A ∪ B ≠ ∅`, emitting both sets to stdout as machine-readable JSON.
4. Additionally scan `scheduler.rs` for new worker names; fail if any string literal there is not also in `known_workers()`.
5. Publish a Zenoh envelope on `indrajaal/l4/sched/dispatcher_registry/<run_id>/{ok|fail}` per SC-SCHED-TELE-MANDATORY.

## RETE-UL Rules (4 rules, salience 100..90)

These rules join the existing RETE-UL engine in `lib/cepaf_gleam/src/cepaf_gleam/rules/engine.gleam` (domain: dispatcher governance):

| Rule | Salience | When | Then |
|------|---------:|------|------|
| `DispatcherRegistryDriftRedline` | 100 | validator output `\|A ∪ B\|` ≥ 1 | hard block PR; emit P0 task; page operator |
| `DispatcherUnknownWorkerInProd` | 95 | Zenoh envelope `indrajaal/l4/sched/oban/*/error` matches `"unknown worker"` | open P0 sa-plan task within 60s, idempotent by worker_name |
| `DispatcherSchedulerLegacyAdd` | 95 | diff adds new string literal in `scheduler.rs` not present in `workers.rs::known_workers()` | block PR; require migration to `workers.rs` |
| `DispatcherKnownNotSorted` | 90 | `known_workers()` not alphabetically sorted | warn (P2); auto-fix via `cargo fmt` companion task |

## Concrete worked example (the Pass-10 bug + fix)

### Before (broken)

```rust
// workers.rs
pub fn known_workers() -> Vec<&'static str> {
    vec!["embed_refresh", "link_extractor"]
}

pub async fn dispatch(name: &str, args: Value) -> Result<()> {
    match name {
        "embed_refresh"  => embed_refresh::run(args).await,
        "link_extractor" => link_extractor::run(args).await,
        "kpi_rollup"     => kpi_rollup::run(args).await,   // ← orphan match arm
        _                => Err(anyhow!("unknown worker: {name}")),
    }
}
```

Operators saw `kpi_rollup` jobs scheduled successfully, then silently rejected at dispatch with `"unknown worker"` because the Smriti.db oban_jobs queue was filtered against `known_workers()` upstream — `kpi_rollup` never made it to `dispatch()` at all. Symmetric drift, opposite direction.

### After (correct)

```rust
// workers.rs
pub fn known_workers() -> Vec<&'static str> {
    vec!["embed_refresh", "kpi_rollup", "link_extractor"]   // ← sorted, complete
}

pub async fn dispatch(name: &str, args: Value) -> Result<()> {
    match name {
        "embed_refresh"  => embed_refresh::run(args).await,
        "kpi_rollup"     => kpi_rollup::run(args).await,
        "link_extractor" => link_extractor::run(args).await,
        _                => Err(anyhow!("unknown worker: {name}")),
    }
}
```

### Operator drift-check one-liners

```bash
# extract names from known_workers()
rg -nP '"\K[a-z_]+(?=")' sub-projects/c3i/native/planning_daemon/src/workers.rs \
  | awk -F: '/known_workers/{flag=1} flag && /"/{print $NF}' | sort -u > /tmp/known.txt

# extract names from dispatch() match arms
rg -nP '^\s*"\K[a-z_]+(?="\s*=>)' sub-projects/c3i/native/planning_daemon/src/workers.rs \
  | sort -u > /tmp/arms.txt

# symmetric diff — MUST be empty
diff /tmp/known.txt /tmp/arms.txt
```

Empty diff = compliant. Any line = SC-DISP-REGISTRY-002 or -003 violation.

## Cross-references

- **Pass-10 fix commit**: `106862017d` (added `kpi_rollup` to `known_workers()` after silent prod incident).
- **Sibling rule (Gleam side)**: `.claude/rules/wiring-guard.md` (SC-WIRE-001..007) — the Gleam analogue for Model/Msg drift.
- **Validator host**: `sub-projects/scripts-gleam/src/scripts/verify/dispatcher_registry.gleam` (per SC-SCRIPT-GLEAM-001).
- **Telemetry envelope**: SC-SCHED-TELE-MANDATORY (`indrajaal/l4/sched/dispatcher_registry/**`).
- **Single-dispatcher constraint**: SC-SCHED-WORK-001 (one `workers::dispatch`).
- **Validator agent**: `.claude/agents/dispatcher-registry-validator.md` (this rule's primary executor).
- **Registry parity**: `.claude/rules/constraint-registry.md` — register family `SC-DISP-REGISTRY 001-010 (10)` under P0-SAFETY.
- **Governance parity**: mirror at `.gemini/rules/dispatcher-registry-consistency.md` next sync (SC-SYNC-DOC-007).

## ZK lineage

This anti-pattern is the **Rust dispatch sibling** of the family rooted at:

- [zk-bb4de67d97f807ac] — *Selector guessing*: trusting a static list rather than the running system.
- [zk-c14e1d23afff486c] — *Implicit invariant between co-dependent lists*: silent drift, late detection, P0 outcome.

Both teach the same lesson: **two lists that must be equal MUST be checked by a machine, not by humans**.
