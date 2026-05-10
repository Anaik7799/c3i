---
name: safe-rust-x-safety
description: Create, review, or refactor Rust code using safe-by-construction X-safety patterns from RustConf 2024 Safety in an Unsafe World and Fuchsia Netstack3. Trigger for Rust APIs, parsers, networking, async, locks, unsafe code, FFI, protocol modeling, serialization, crypto, zero-copy, or supply-chain safety.
---

# Safe Rust X-Safety

## Rule

Make invalid states unrepresentable and invalid programs fail to compile.

Use the Definition → Enforcement → Consumption loop:

- **Definition**: attach the invariant to a type, trait, lifetime, const generic, marker, capability token, typestate, or sealed module.
- **Enforcement**: prove construction and mutation with private fields, smart constructors, checked conversions, RAII guards, exhaustive enums, and minimal unsafe.
- **Consumption**: only rely on the invariant through signatures that carry proof.

## Workflow

1. Enumerate invariants and raw input boundaries.
2. Parse raw inputs into domain types immediately.
3. Replace primitive obsession with newtypes/typestates.
4. Remove production `unwrap`, `expect`, `panic!`, unchecked indexing/slicing, and unchecked numeric casts.
5. Keep unsafe local, documented, and hidden behind safe wrappers.
6. Model protocol states and errors faithfully with enums/structs.
7. Validate with focused tests, then available safety tools.

## Safety Gates

- `cargo fmt --check`
- `cargo clippy --all-targets --all-features -- -D warnings`
- `cargo test`
- `cargo miri test` when unsafe/layout/aliasing code is touched.
- `cargo kani` when proof harnesses exist.
- `cargo audit` or `cargo deny check` when dependency risk matters.

## Anti-Patterns

- Public structs with fields that can violate invariants.
- Validation functions that return `bool` while the rest of the code keeps raw values.
- `Option` or `Result` from public APIs for caller mistakes that a constructor could prevent.
- `unsafe impl Send/Sync` without a proof.
- Holding blocking lock guards across `.await`.
- Secret-bearing types deriving unredacted `Debug`, `Serialize`, or `Deserialize`.

Reference source map: `docs/rust-safety/safe-rust-x-safety-source-map.md`.
