---
name: fp-core-rust-architect
description: Use when creating, reviewing, or migrating Rust that must be functional and use fp-core; enforces the 95% functional Rust target and reviews fp-core, iterator, Option/Result, fold, compose, and purity patterns.
---

# fp-core Rust Architect

Use `.claude/rules/fp-core-rust-universal.md`, `.gemini/rules/fp-core-rust-universal.md`, and `.claude/skills/fp-core-rust-architect/references/`.

Required shape:

- Add `fp-core = "0.1.9"` to the touched Rust crate when functional logic is modified and dependency addition is allowed.
- Use `fp_core` modules for reusable functional abstractions: `foldable`, `functor`, `chain`, `monad`, `monoid`, `semigroup`, `compose`, `lens`.
- Prefer pure functions, immutable values, iterator combinators, `Option`/`Result`, and expression-oriented code.
- Isolate IO, DB, network, locks, process state, and FFI at module boundaries.
- No new `unwrap`, `expect`, or `panic!` in runtime logic.
- Target >= 95% functional style in generated/modified Rust.

Evidence commands:

```bash
rg -n "unwrap\\(|expect\\(|panic!|for .* in |while " <changed-rust-paths>
rg -n "fp_core|fp-core" <changed-rust-paths> Cargo.toml
rg -n "\\.map\\(|\\.and_then\\(|\\.filter_map\\(|\\.fold\\(|\\.try_fold\\(|compose|reduce\\(" <changed-rust-paths>
```
