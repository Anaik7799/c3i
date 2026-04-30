https://vm-1.tail55d152.ts.net:8443/c3i/docs/journal/20260429-apalache-model-check-results.md

# Apalache Model Check Results — HookSubsystem.tla

**Task**: 116487357138401611 (Wave 4)
**STAMP**: SC-BOOTSTRAP-005, SC-FRAC-RRF-001..010
**ZK**: [zk-5d2236e838f2c6fe] formal verification mandate · [zk-3346fc607a1ef9e6] no Stub That Lies
**Date**: 2026-04-29
**Verifier**: Apalache 0.57.0

## 1. Apalache Install

| Field | Value |
|---|---|
| Method | GitHub release tarball (no `scripts/install_apalache.sh` existed; nixpkgs has no `apalache-mc`) |
| Source | https://github.com/apalache-mc/apalache/releases/download/v0.57.0/apalache-0.57.0.tgz |
| Binary path | `/home/an/.local/opt/apalache-0.57.0/bin/apalache-mc` |
| `apalache-mc version` | `0.57.0` (build `635865a`) |
| Java runtime | OpenJDK Temurin 21.0.11 |
| Install status | **SUCCESS** |

Note: there was no pre-existing `scripts/install_apalache.sh` to follow; the install was done directly via `curl` + `tar`. A reusable install script remains a follow-up.

## 2. Per-Invariant Results

CLI form: `apalache-mc check --inv=<NAME> --length=<N> specs/tla/HookSubsystem.tla`

| # | Invariant | Length | Result | Notes |
|---|---|---:|---|---|
| 1 | `HookAlwaysEmits` | 3 | **SKIPPED — parse error** | Module fails SANY parse (see §3) |
| 2 | `DaemonHealthBounded` | 5 | **SKIPPED — parse error** | Same parse failure |
| 3 | `NoSilentFail` | 3 | **SKIPPED — parse error** | Same |
| 4 | `SnapshotFresh` | 3 | **SKIPPED — parse error** | Same |
| 5 | `LockExclusive` | 3 | **SKIPPED — parse error** | Same |
| 6 | `SeqlockOrderedWriter` | 3 | **SKIPPED — parse error** | Same |
| 7 | `FailClosed` | 3 | **SKIPPED — parse error** | Same |
| 8 | `HookTerminates` (liveness) | 3 | **SKIPPED — parse error** | Same; also Apalache liveness support is limited |
| 9 | `PIDConverges` (liveness) | 3 | **SKIPPED — parse error** | Same |

## 3. Truth-Signal: Why All Invariants Blocked

Apalache's SANY parser rejects the spec at file-parse time, before any
invariant is evaluated. Verbatim error:

```
line 63, col 67 to line 63, col 70 of module HookSubsystem
Unknown operator: `NONE'.

line 64, col 72 to line 64, col 75 of module HookSubsystem
Unknown operator: `NONE'.
```

Offending lines (verbatim, lines 62-64 of the spec):

```tla
ErrorExplicit(o) == \/ o = "Success"
                    \/ o.outcome = "Degraded_Stale" /\ o.reason # NONE
                    \/ o.outcome = "Failed_DaemonDown" /\ o.evidence # NONE
```

`NONE` is a TLC reserved model value, not a TLA+ operator. Apalache
does not implicitly bind it (TLC binds it as a special symbol via
`MODEL VALUES NONE` in the .cfg). The current `HookSubsystem.cfg` does
**not** declare `NONE` as a model value (it is also not used by the
`SPECIFICATION Spec` line). The result is the same parse failure under
either tool with the current artefacts.

Per task constraints (and per the [zk-3346fc607a1ef9e6] no-Stub-That-Lies
mandate) the spec was **not** rewritten to make verification superficially
succeed. The parse failure is the truth signal.

## 4. What Is Mechanically Verified Right Now

**0 of 8 invariants** are mechanically verified by Apalache.

The eight invariants remain TLA+ assertions on paper only. The Allium
specification + the prose claim of "TLA+ ✓" elsewhere in the matrix are
not yet substantiated by tool output.

## 5. Remediation Paths (deferred — not done in this session)

Three orthogonal options, in order of intrusiveness:

1. **Declare `NONE` as a model value** in `HookSubsystem.cfg` (`CONSTANT NONE = NONE` plus `MODEL VALUES NONE`) — requires a config edit, no spec edit.
2. **Promote `NONE` to a constant** in the spec (`CONSTANTS … NONE`) and instantiate it in `.cfg`. Minimal spec edit, preserves intent.
3. **Replace `NONE` with `"NONE"`** (string) inside `ErrorExplicit`. Smallest semantic change, but technically a spec rewrite — out of scope for this Wave 4 task.

Option 1 was not pursued in this session because the task constraints
explicitly limited edits to `docs/journal/` and `docs/analysis/.../matrix.md §9`.
Filing follow-up: a P1 sa-plan task for "wire `NONE` into HookSubsystem.cfg
and re-run all 8 invariants".

## 6. Honest Open Items

- Spec is unparseable by Apalache as-shipped → no bytecode verification done.
- Liveness invariants (`HookTerminates`, `PIDConverges`) would in any case
  require the `tendermint`/PROPERTY workflow in Apalache, not bare `--inv=`.
- TLC alternative was not attempted; `HookSubsystem.cfg` has no `INIT/NEXT`
  or model-value bindings for `NONE`, so TLC would also stop at the same
  symbol resolution step.
- Counterexample traces: none produced (parser stopped before checking).

## 7. Verdict

**Mechanically verified: 0 / 8 invariants.**
Reason: SANY parse error on `NONE` (lines 63-64 of `HookSubsystem.tla`).
Status: blocked at L1 (toolchain integration), not at L0 (spec authorship).
Resolution path: §5 option 1 or 2, tracked as a follow-up sa-plan task.

---

## Stream L: Re-run after `NONE` Remediation (2026-04-29 12:20 UTC)

### Fix applied

Two minimal edits, no semantic changes:

1. `specs/tla/HookSubsystem.tla` — added `NONE` to `CONSTANTS` declaration block:
   ```tla
   CONSTANTS
       HookKinds, Agents, MaxRetries, CacheTTLms,
       WatchdogTimeoutMs, MaxLockAgeSec, MaxStateBound,
       NONE   \* sentinel model value for absent reason/evidence/holder
   ```
2. `specs/tla/HookSubsystem.cfg` — bound `NONE` as a model value, dropped 4 spurious
   constants (`MaxRingBuffer`, `HighRateThreshold`, `LowRateThreshold`,
   `SetpointHitRate`) that the spec never declared, added the missing
   `MaxStateBound = 4`, and added `NONE = "NONE"`.
3. `specs/tla/HookSubsystem.tla:165` — replaced `1.5` with `15` (Apalache rejects
   `TlaDecimal` literals; rescaled fitness comparison ×10, baseline becomes 10
   instead of 1.0). Documented in-line as "(×10 scaled, Apalache has no decimals)".

### Apalache invocation tail (proves NONE is past)

```
PASS #0: SanyParser                                               I@12:20:43
PASS #1: TypeCheckerSnowcat                                       I@12:20:43
HookSubsystem.tla:44:5-44:13: type input error: Expected a type annotation for VARIABLE mdp_state
```

SANY (the parser) now succeeds; the next pass (`Snowcat` type-check) is what
fails. The `NONE` and decimal blockers are mechanically eliminated.

### Per-invariant results table (length=3)

| # | Invariant | Outcome | Reason |
|---|-----------|---------|--------|
| 1 | DaemonHealthBounded     | SKIP | Snowcat: mdp_state needs `\* @type:` annotation |
| 2 | HookAlwaysEmits         | SKIP | same |
| 3 | NoSilentFail            | SKIP | same |
| 4 | SnapshotFresh           | SKIP | same |
| 5 | LockExclusive           | SKIP | same |
| 6 | SeqlockOrderedWriter    | SKIP | same |
| 7 | FailClosed              | SKIP | same |
| 8 | HookTerminates          | SKIP | same |
| 9 | PIDConverges (extra)    | SKIP | same |

All 9 fail at the same point: `HookSubsystem.tla:44:5-44:13 type input error:
Expected a type annotation for VARIABLE mdp_state`. The error is identical for
every invariant because Apalache type-checks the entire module before
proceeding to the model-checker. Once one variable annotation is added the
checker advances to the next variable, then operators, etc.

### Counterexamples

None. The model-checker never executed; no state-space was explored.

### Truth verdict (per [zk-3346fc607a1ef9e6])

- **Mechanically verified: 0 / 8 invariants** (unchanged from Stream G/K).
- **Blocker status changed**: was *L0 spec authorship* (NONE syntactic), now
  *L1 toolchain* (Apalache 0.57's mandatory `Snowcat` type-check requires
  `\* @type:` annotations on every `VARIABLE` and key operator).
- **Honest progress**: NONE syntactic blocker eliminated; one decimal-literal
  blocker eliminated; cfg cleaned of 4 spurious constants. Spec now passes
  PASS #0 (SanyParser) where Stream K halted.

### Next remediation task (recommended sa-plan ticket, not done in this stream)

Add `\* @type:` annotations to the 12 VARIABLEs and ~6 record-returning
operators in `HookSubsystem.tla`. Estimated 50–80 LOC, no semantic change.
Apalache type-grammar: `\* @type: <set-of-records>;` etc. Reference example
from Apalache `examples/` would land us at PASS #2 (rewriter) and let real
model-checking begin.

Until that ticket lands, fractal-criticality matrix §9 row "Apalache (TLA+)"
remains **0/8 mechanically verified** but the *failure mode* should be
re-classified from `parse error: NONE` to `type-annotation gap`.


---

## Stream M: post-@type results (2026-04-29, Wave 6 task 116487498920757647)

### Annotations added
- **VARIABLEs annotated**: 12 (all of them: daemon_state, daemon_health,
  snapshot, lock, hook_in_flight, telemetry_log, ring_buffer, pid_state,
  bayesian_state, mdp_state, ga_population, rules_fired)
- **CONSTANTs annotated**: 8 (HookKinds, Agents, MaxRetries, CacheTTLms,
  WatchdogTimeoutMs, MaxLockAgeSec, MaxStateBound, NONE)
- **Operators annotated**: 5 (Now, Outcome, BayesianUpdate, PIDUpdate, SeqlockWrite)
- **Operators removed**: 1 (`ErrorExplicit` — dead, never referenced from any
  invariant or action, and contained an internal type contradiction
  `o = "Success"` vs `o.outcome = "..."`. Removal does not change verified
  behaviour because no invariant or action calls it.)
- **Snowcat iterations**: 1 (passed first try with the annotation set above)

### Per-invariant model-check results (--length=3, HookSubsystem.cfg)

| # | Invariant | Verdict | Time |
|---|-----------|---------|------|
| 1 | HookAlwaysEmits       | PASS | 1.6 s |
| 2 | DaemonHealthBounded   | PASS | 1.6 s |
| 3 | LockExclusive         | PASS | 1.5 s |
| 4 | StaleLockCleared      | PASS | 1.5 s |
| 5 | TelemetryMonotonic    | PASS | 1.5 s |
| 6 | NoSilentFail          | PASS | 1.5 s |
| 7 | SnapshotFresh         | PASS | 1.6 s |
| 8 | SeqlockOrderedWriter  | PASS | 1.6 s |
| 9 | FailClosed            | PASS | 1.7 s |
| 10 | PIDBounded           | PASS | 1.6 s |
| 11 | GAPopulationSize     | **COUNTEREXAMPLE** | 1.7 s |
| 12 | CrashIsolation       | PASS | 1.5 s |

Liveness invariants (HookTerminates, HungDaemonKilled, DownDaemonRestarts,
PIDConverges, GAImprovesFitness): SKIPPED — Apalache liveness needs
`PROPERTY` workflow, not `--inv=`. Out of scope for this stream.

### Counterexample: GAPopulationSize

```
Init violates the invariant from step 0:
  ga_population = { [id |-> 1, fitness |-> 1] }   (Cardinality = 1)
  invariant requires Cardinality(ga_population) = 10
```

**Truth signal**: `Init` contradicts `GAPopulationSize` directly. The
invariant either needs to be relaxed (`>= 1`) to match the abstract
single-genome init, or `Init` needs to populate 10 genomes. This is a real
spec bug, not an annotation issue. Reported as-is per
[zk-3346fc607a1ef9e6] (no Stub-That-Lies).

### Truth verdict

**11 of 12 safety invariants are NOW mechanically verified by Apalache 0.57**
on the bounded model `MaxStateBound=4, length=3`. The 12th
(`GAPopulationSize`) is correctly *falsified* — Apalache caught a real
inconsistency between `Init` and the invariant. Either fix is a
single-line spec edit; not in scope for this annotation stream.

### Snowcat layer status

**CLEARED.** Pass #1 (Snowcat) now PASSES on the first iteration. Real
model-checking begins at PASS #13 (BoundedChecker). The
"L1 toolchain blocker" identified in Stream L is closed.

---

## Stream P: Post-Init-Fix + Liveness (Wave 7, 2026-04-29)

### PART 1 — GAPopulationSize Fix

**Diff** (HookSubsystem.tla:263, Init action):

```diff
-    /\ ga_population = {[id |-> 1, fitness |-> 1]}  \* abstract initial
+    /\ ga_population = {[id |-> i, fitness |-> 0] : i \in 1..10}  \* fixed pop=10 per design.md §10
```

Rationale: Option A from task brief — matches Wave 6 design intent (GA population fixed at 10). Option B (relax invariant to `<=10`) would weaken the contract.

### 12 Safety Invariants Re-verification (post-fix)

| # | Invariant | Result |
|---|-----------|--------|
| 1 | GAPopulationSize | PASS |
| 2 | HookAlwaysEmits | PASS |
| 3 | DaemonHealthBounded | PASS |
| 4 | LockExclusive | PASS |
| 5 | StaleLockCleared | PASS |
| 6 | TelemetryMonotonic | PASS |
| 7 | NoSilentFail | PASS |
| 8 | SnapshotFresh | PASS |
| 9 | SeqlockOrderedWriter | PASS |
| 10 | FailClosed | PASS |
| 11 | PIDBounded | PASS |
| 12 | CrashIsolation | PASS |

**12/12 PASS.** No regressions.

Command: `apalache-mc check --config=specs/tla/HookSubsystem.cfg --inv=<NAME> --length=3 specs/tla/HookSubsystem.tla`

### PART 2 — Liveness via --temporal

Apalache 0.57.0 supports temporal properties via the `--temporal` flag (NOT `--prop`; that flag does not exist in this version).

Command: `apalache-mc check --config=specs/tla/HookSubsystem.cfg --temporal=<NAME> --length=3 specs/tla/HookSubsystem.tla`

| # | Liveness Property | Result | Notes |
|---|-------------------|--------|-------|
| 1 | HookTerminates | NOT-SUPPORTED | `\A h \in hook_in_flight : <>(...)` — Apalache fails to bind `h` as temporal: "SubstRule: Variable h$1 is not assigned a value". Quantification over time-varying set is not supported by Apalache's bounded temporal encoding. |
| 2 | HungDaemonKilled | PASS | Leads-to (`~>`) verified at length=3 |
| 3 | DownDaemonRestarts | PASS | Leads-to (`~>`) verified at length=3 |
| 4 | PIDConverges | PASS | `<>[]` verified at length=3 |
| 5 | GAImprovesFitness | COUNTEREXAMPLE | `<>(\E g \in ga_population : g.fitness > 15)` — violated because `GeneticEvolve` action is abstracted as `ga_population' = ga_population` (no-op). Fitness can never exceed initial value (0). This is a known incomplete-spec gap (see GA action line 241-245); reflects HONEST modeling per [zk-3346fc607a1ef9e6]. |

### Truth Verdict

- **Mechanically verified**: 12 safety + 3 liveness = **15/17** (88%)
- **Declared**: 12 safety + 5 liveness = 17 total
- **Honest gaps**: 2 — (1) HookTerminates blocked by Apalache temporal-quantifier limitation, (2) GAImprovesFitness counterexample due to abstract `GeneticEvolve` no-op (spec-design gap, not verifier failure).

Per [zk-3346fc607a1ef9e6]: gaps reported, not stubbed.

### LOC Delta
- Spec: 1 line (Init seed expression)
- Journal: +50 lines (this section)
- Matrix: §9 totals updated (next)
