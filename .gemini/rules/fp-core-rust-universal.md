# fp-core Rust Functional Mandate (SC-FP-RUST-001..020)

## Mandate

Per operator directive 2026-05-09, all Rust generated or modified by users or agents MUST be functional by default and MUST use [`fp-core`](https://github.com/JasonShin/fp-core.rs) for functional abstractions wherever the touched code performs composition, mapping, chaining, folding, algebraic combination, lenses, equality/typeclass-style behavior, or higher-kinded patterns.

Target: at least 95% of generated/modified Rust logic should be functional code. Imperative code is allowed only at explicit IO/FFI/runtime boundaries or for justified performance-critical sections with a local comment or task note.

## Source Baseline

- GitHub: `https://github.com/JasonShin/fp-core.rs`
- Crate: `fp-core = "0.1.9"`
- Docs.rs: `https://docs.rs/fp-core`
- License: MIT
- Docs.rs modules observed: `applicative`, `apply`, `chain`, `comonad`, `compose`, `empty`, `extend`, `extract`, `foldable`, `functor`, `hkt`, `identity`, `lens`, `monad`, `monoid`, `pure`, `semigroup`, `setoid`
- Docs.rs item list includes traits: `Applicative`, `Apply`, `Chain`, `Comonad`, `Empty`, `Extend`, `Extract`, `Foldable`, `Functor`, `HKT`, `HKT3`, `Lens`, `Monad`, `Monoid`, `Pure`, `Semigroup`, `Setoid`; macro: `compose`; functions: `compose_two`, `fold_map`, `identity`
- Firecrawl research output: `/home/an/dev/ver/work/.firecrawl/fp-core-rust-artifacts.json`

## STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-FP-RUST-001 | Rust generated/modified by agents MUST prefer pure functions over mutation and side effects | CRITICAL |
| SC-FP-RUST-002 | Touched Rust modules needing FP abstractions MUST depend on and import `fp_core` | CRITICAL |
| SC-FP-RUST-003 | Use `fp_core::functor::*` or iterator `map` for mapping transformations; avoid hand-written mutation loops | HIGH |
| SC-FP-RUST-004 | Use `fp_core::chain::*` / monadic chaining patterns for nested `Option`/`Result` flow | HIGH |
| SC-FP-RUST-005 | Use `fp_core::foldable::*` / folds for accumulation; avoid mutable accumulators unless boundary/perf justified | HIGH |
| SC-FP-RUST-006 | Use `fp_core::semigroup::*` and `fp_core::monoid::*` for lawful combination identities where applicable | HIGH |
| SC-FP-RUST-007 | Use `fp_core::compose::*` or function composition for pipelines with reusable transformations | MEDIUM |
| SC-FP-RUST-008 | Use `fp_core::lens::*` for non-mutating nested updates where the pattern fits | MEDIUM |
| SC-FP-RUST-009 | Use `Option`/`Result` combinators instead of `unwrap`, `expect`, or sentinel values | CRITICAL |
| SC-FP-RUST-010 | IO, network, DB, filesystem, FFI, locks, and process state must be isolated at module edges | CRITICAL |
| SC-FP-RUST-011 | New Rust APIs should accept immutable references/owned values and return new values, not mutate inputs | HIGH |
| SC-FP-RUST-012 | Prefer iterator chains and combinators (`map`, `filter`, `filter_map`, `try_fold`, `collect`) over index loops | HIGH |
| SC-FP-RUST-013 | Error handling must be expression-oriented with `Result` and `?`; no panic paths in generated runtime logic | CRITICAL |
| SC-FP-RUST-014 | Shared state must be minimized; when required, wrap it behind a small effectful boundary API | HIGH |
| SC-FP-RUST-015 | Laws for new algebraic abstractions must be tested or documented: associativity, identity, composition, map identity/composition | HIGH |
| SC-FP-RUST-016 | Rust code in C3I native daemon/NIF paths must preserve safety/performance but still use functional structure inside business logic | HIGH |
| SC-FP-RUST-017 | Avoid introducing Python/shell replacement scripts when a Rust/Gleam functional path exists | MEDIUM |
| SC-FP-RUST-018 | At least 95% of generated/modified Rust logic lines should be expression/combinator/pure-function style | CRITICAL |
| SC-FP-RUST-019 | Imperative exceptions require justification in task notes, including why `fp_core`/iterator/combinator style is insufficient | HIGH |
| SC-FP-RUST-020 | Any Rust dependency decision must verify crate availability locally or through crates.io/docs.rs before committing | HIGH |

## Required Cargo Guidance

When a touched Rust crate lacks `fp-core` and the task modifies Rust logic, add:

```toml
fp-core = "0.1.9"
```

Then use imports narrowly:

```rust
use fp_core::foldable::*;
use fp_core::functor::*;
use fp_core::chain::*;
use fp_core::compose::*;
```

Only import modules needed by the touched code.

## Anti-Patterns

| Anti-pattern | Replacement |
|--------------|-------------|
| `for` loop mutating accumulator | `iter().fold(...)`, `try_fold(...)`, or `Foldable::reduce` |
| nested `match` on `Option`/`Result` | `map`, `and_then`, `or_else`, `map_err`, `transpose`, `?` |
| `unwrap` / `expect` in runtime code | typed `Result`, `Option`, or domain error |
| mutation-heavy nested update | pure constructor/update function or `Lens` pattern |
| global mutable singleton | dependency parameter, immutable config, or small boundary service |
| ad hoc combine identity | `Monoid` / `Semigroup` concept and law test |

## Verification

Use focused checks:

```bash
rg -n "unwrap\\(|expect\\(|panic!|for .* in |while " <changed-rust-paths>
rg -n "fp_core|fp-core" <changed-rust-paths> Cargo.toml
rg -n "\\.map\\(|\\.and_then\\(|\\.filter_map\\(|\\.fold\\(|\\.try_fold\\(|compose" <changed-rust-paths>
```

Then run the crate-specific Rust check/test command from local rules.
