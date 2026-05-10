---
name: fp-core-rust-architect
description: Use when creating, reviewing, or migrating Rust that must be functional and use fp-core. Covers fp-core crate setup, Functor/Chain/Monad/Foldable/Monoid/Semigroup/Compose/Lens patterns, 95% functional code target, mutation reduction, Rust daemon/NIF boundaries, and review gates for unwrap/panic/imperative loops.
---

# fp-core Rust Architect

## Trigger

Use for any generated or modified Rust (`*.rs`, `Cargo.toml`) in C3I, nested C3I, pi-mono tooling, native daemons, NIFs, scripts, or examples.

## Required Reading

1. `.claude/rules/fp-core-rust-universal.md`
2. `.claude/rules/functional-programming-rust.md` if present in the task scope
3. `references/artifacts.md`
4. `references/patterns.md`
5. `references/review-checklist.md`

## Workflow

1. Identify the Rust crate and nearest `Cargo.toml`.
2. If Rust logic is touched and `fp-core` is absent, add `fp-core = "0.1.9"` unless the crate cannot accept dependencies; document exception.
3. Convert imperative logic to expressions, iterators, folds, combinators, and `fp_core` traits/modules.
4. Keep IO/DB/network/FFI/locks at the edge; keep business logic pure.
5. Replace `unwrap`/`expect`/panic paths with typed `Result`/`Option`.
6. Estimate functional ratio for touched logic; target >= 95%.
7. Run local Rust checks/tests from AGENTS/CLAUDE rules.

## Minimal Imports

```rust
use fp_core::foldable::*;
use fp_core::functor::*;
use fp_core::chain::*;
use fp_core::compose::*;
```

Import only what the touched code uses.

## Review Gate

Reject generated/modified Rust that adds panic paths, mutable accumulation where a fold fits, unisolated side effects, global mutable state, or no `fp_core` usage in functional business logic.
