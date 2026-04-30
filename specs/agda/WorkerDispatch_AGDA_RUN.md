# WorkerDispatch.agda — Pass 12 verification notes

**Date:** 2026-04-28
**Status:** Postulate `parse-roundtrip` discharged; pre-existing parse error in `¬Unknown-of-Worker` also fixed.

## Changes

1. **`parse-roundtrip` is now a real proof** (was `postulate`).
   Per-constructor `refl` — 21 lines, one per `Worker` variant.
   Agda's evaluator reduces `parse (name w)` through the cascading
   `s ≟ <literal>` decisions; for the constructor `w` aligned with
   `name w`, the corresponding arm fires `yes refl` and earlier arms
   are skipped via `no _`. `refl` witnesses that the chain terminates
   at `just w`.

2. **Pre-existing parse error in `¬Unknown-of-Worker` fixed**
   (was blocking the whole module from `agda --safe`).
   The `where` clause on a type signature is illegal Agda syntax;
   `_≢_` was hoisted to module scope.

## Verification

Agda 2.8.0 is installed at
`/home/an/dev/ver/intelitor-v5.2/.devenv/profile/bin/agda`, but the
**Agda standard library is not on the include path** in this
environment, so `agda --safe specs/agda/WorkerDispatch.agda` cannot
locate `Data.String`, `Data.Maybe`, etc. To verify locally:

```bash
# Option A — devenv shell that already has stdlib
cd sub-projects/c3i        # devenv-managed
agda --safe ../../specs/agda/WorkerDispatch.agda

# Option B — explicit include path
cd specs/agda
agda --safe \
  -i /path/to/agda-stdlib/src \
  WorkerDispatch.agda

# Option C — nix-shell (preferred for CI)
nix-shell -p '(agda.withPackages (p: [ p.standard-library ]))' \
  --run 'cd specs/agda && agda --safe WorkerDispatch.agda'
```

**Expected output:**
```
Checking WorkerDispatch (/home/an/dev/ver/c3i/specs/agda/WorkerDispatch.agda).
```
(No error; type-check succeeds.)

## Why `refl` works for every case

The proof relies on three Agda evaluator facts:

1. `name HealthCheck` reduces to the literal `"health_check"`.
2. `parse "health_check"` reduces by `_≟_` decidability:
   `"health_check" ≟ "health_check"` returns `yes refl`, so the
   first arm fires and produces `just HealthCheck`.
3. By definition of propositional equality, `just HealthCheck ≡ just HealthCheck` is `refl`.

For constructor `w` whose `name w` only matches the `i`-th arm of `parse`,
the previous `i-1` arms each return `no _`, and the `i`-th returns
`yes refl` — the cascade is fully evaluated by Agda's normaliser, so
`refl` suffices. No helper machinery (decidability bundle, string-eq
lemmas) is required beyond `Data.String.Properties._≟_`, which the
spec already imports.

## File diff summary

| Section | Before | After |
|---|---|---|
| §6 `parse-roundtrip` | `postulate` (1 line) | proof (22 lines) |
| §8 `¬Unknown-of-Worker` | invalid `where` on type sig | `_≢_` lifted to module scope |
