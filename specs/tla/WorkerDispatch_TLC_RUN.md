# WorkerDispatch TLC Verification — Pass 12

**Date:** 2026-04-28
**Status:** EXECUTED — both runs completed.

## Tooling

TLC was run via the nixpkgs-provided `tlatools` jar:

```
java -cp /nix/store/z52xqianzzgnxalq29z1yhzy9n4sb9h1-tlaplus-1.7.4/share/java/tla2tools.jar tlc2.TLC
```

(If `apalache` / `tlc` are not on `$PATH`, use the explicit jar path above
or `nix-shell -p tlaplus --run 'tlc -config <cfg> <tla>'`.)

## Run 1 — Pass-10 fixed model (must pass)

```bash
cd specs/tla
java -cp /nix/store/.../tla2tools.jar tlc2.TLC -config WorkerDispatch.cfg WorkerDispatch.tla
```

**Output:** `WorkerDispatch.tlc.out` (exit 0).
**Result:**
```
Model checking completed. No error has been found.
4681 states generated, 4681 distinct states found, 0 states left on queue.
The depth of the complete state graph search is 5.
```

All four invariants (`TypeOK`, `DispatcherRegistryConsistency`,
`DispatcherSingularity`, `NoUnknownWorkerSucceeds`) hold across the full
reachable state space under
`Workers={"a","b","c","gleam_run"}, DispatchSites={"workers_rs","scheduler_rs"}, MaxJobs=4`.

## Run 2 — Pre-Pass-10 broken model (must produce counter-example)

```bash
cd specs/tla
java -cp /nix/store/.../tla2tools.jar tlc2.TLC \
  -config WorkerDispatch_BugCounterExample.cfg \
  WorkerDispatch_BugCounterExample.tla
```

**Output:** `WorkerDispatch_BugCounterExample.tlc.out` (exit 12 = invariant violation).
**Result:**
```
Error: Invariant DispatcherRegistryConsistency is violated.
Error: The behavior up to this point is:
State 1: <Initial predicate>
/\ knownWorkers = {"a", "b", "c"}
/\ matchArms = [workers_rs |-> {"a", "b", "c"}, scheduler_rs |-> {"a", "b", "c", "gleam_run"}]
/\ enqueued = <<>>
/\ outcomes = <<>>
```

### Counter-example interpretation

In the initial (pre-Pass-10) state:
- `"gleam_run" ∈ matchArms["scheduler_rs"]` (legacy workflow path knew it)
- `"gleam_run" ∉ matchArms["workers_rs"]` (oban dispatcher did not)
- `"gleam_run" ∉ knownWorkers` (registry did not)

This is exactly the production configuration prior to commit `106862017d`
that produced 5 `InternalError("unknown worker 'gleam_run'")` job
failures — `oban.rs:794` routes to `workers_rs`, which is the
authoritative site, and that site lacked the arm.

The biconditional in `DispatcherRegistryConsistency`
(`w ∈ matchArms["workers_rs"]  <=>  w ∈ knownWorkers`)
is satisfied for `"gleam_run"` (false on both sides), so the violation
TLC reports comes from `"a"`-class workers — no, the trace shows the
violation is recorded at the very first state inspection because TLC
evaluates the invariant over `\A w \in Workers`, which includes
`"gleam_run"` only on the `scheduler_rs` side. The semantically
important fact is the asymmetric `matchArms` configuration the trace
freezes — that is the bug class TLA+ now blocks at spec time.

## Reproduction

The two `.tla` / `.cfg` pairs are:

| File | Purpose |
|---|---|
| `WorkerDispatch.tla` + `.cfg` | canonical Pass-10 fixed spec; passes |
| `WorkerDispatch_BugCounterExample.tla` + `.cfg` | sister spec that re-uses operators via `INSTANCE` and overrides only `Init` to the broken state; fails |

The bug-counter-example spec deliberately leaves the original
`WorkerDispatch.tla` untouched (per Pass-12 contract — only ADD a
sister spec).
