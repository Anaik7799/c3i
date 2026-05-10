# fp-core Rust Functional Rule for .agents

All Rust generated or modified by users or agents MUST use functional style and `fp-core = "0.1.9"` where applicable. This mirror is for OpenCode/Codex-style `.agents` consumers and is subordinate to:

- `.claude/rules/fp-core-rust-universal.md`
- `.gemini/rules/fp-core-rust-universal.md`
- `.claude/rules/functional-programming-rust.md`
- `.gemini/rules/functional-programming-rust.md`

## Required Shape

- Add `fp-core = "0.1.9"` when touching Rust functional logic and dependency changes are allowed.
- Prefer pure functions, immutable values, expression-oriented APIs, and explicit boundary services.
- Use `fp_core` traits/modules where they fit: `Functor`, `Apply`, `Applicative`, `Chain`, `Monad`, `Foldable`, `Semigroup`, `Monoid`, `Setoid`, `Lens`, `HKT`, and `compose`.
- Use `Option`/`Result`, iterators, `map`, `and_then`, `filter_map`, `fold`, `try_fold`, and law-tested algebraic composition.
- Target >=95% functional style in generated/modified Rust logic.
- Isolate IO, DB, network, filesystem, FFI, locks, and runtime state at module edges.
- Do not add runtime `unwrap`, `expect`, or `panic!` paths.

## Evidence

```bash
rg -n "fp_core|fp-core" <changed-rust-paths> Cargo.toml
rg -n "unwrap\\(|expect\\(|panic!|for .* in |while " <changed-rust-paths>
rg -n "\\.map\\(|\\.and_then\\(|\\.filter_map\\(|\\.fold\\(|\\.try_fold\\(|compose" <changed-rust-paths>
```
