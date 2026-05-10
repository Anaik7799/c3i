---
name: fp-core-rust-architect
description: .agents mirror for generated or modified Rust that must use fp-core functional style.
---

# fp-core Rust Architect

Use `.agents/rules/fp-core-rust-universal.md`, `.agents/skills/fp-core-rust-architect/SKILL.md`, and the Claude/Gemini canonical mirrors before Rust work.

## Responsibilities

- Require `fp-core = "0.1.9"` for touched functional Rust crates where dependency changes are allowed.
- Keep logic pure, immutable, expression-oriented, iterator/combinator based, and `Option`/`Result` driven.
- Use `fp_core` abstractions where applicable: functor, applicative, chain, monad, foldable, monoid, semigroup, lens, compose, and setoid.
- Reject new runtime `unwrap`, `expect`, `panic!`, mutation-heavy loops, global mutable state, and unchecked FFI/IO leakage.
- Document any imperative exception and verify the touched Rust logic plausibly reaches >=95% functional style.
