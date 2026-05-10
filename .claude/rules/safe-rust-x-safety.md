# Safe Rust X-Safety Rule

## Mandate

All generated or modified Rust must be safe-by-construction. Treat Rust as an X-safe language: encode domain, protocol, concurrency, serialization, authorization, parsing, and resource-state invariants so invalid programs fail to compile wherever practical.

This rule composes with the local fp-core mandate: prefer functional data transformations, total functions, typed errors, immutable values, and explicit effect boundaries.

## Rules

| ID | Requirement | Severity |
| --- | --- | --- |
| SRXS-001 | Define every important invariant on a type, trait, lifetime, const generic, capability token, or sealed module boundary. | HIGH |
| SRXS-002 | Enforce invariants with private fields, smart constructors, checked conversions, typestate, RAII guards, and exhaustive enums. | HIGH |
| SRXS-003 | Consume invariants through signatures; internal functions should accept refined/domain types instead of raw `String`, integer, JSON, or map values. | HIGH |
| SRXS-004 | Do not add production `unwrap`, `expect`, `panic!`, `todo!`, unchecked indexing, unchecked slicing, or `unreachable!` unless impossible states are already type-proven and documented. | HIGH |
| SRXS-005 | Public APIs must not return `Option` or `Result` for caller-invalid inputs that could be ruled out by construction. Use parsers/newtypes before the API boundary. | MEDIUM |
| SRXS-006 | New `unsafe` is forbidden unless isolated to the smallest module, justified by a `SAFETY:` comment, hidden behind a safe wrapper, and backed by tests or verification. | CRITICAL |
| SRXS-007 | Every `unsafe fn` or `unsafe trait` must include a `# Safety` doc section with caller obligations and invariants. | CRITICAL |
| SRXS-008 | Numeric conversions must use `TryFrom`, `checked_*`, `saturating_*`, or intentionally named wrapping operations. Avoid bare `as` for narrowing or sign-changing conversions. | HIGH |
| SRXS-009 | Protocol and parser code must model specification states and errors with typed enums/structs; avoid lossy booleans, magic strings, and raw status codes in core logic. | HIGH |
| SRXS-010 | Locking must have a type-level or documented hierarchy. Do not hold blocking locks or guards across `.await`. | HIGH |
| SRXS-011 | Serialization of secrets and credentials must be explicit. Do not derive `Debug`, `Serialize`, or `Deserialize` for sensitive fields without redaction/validation review. | CRITICAL |
| SRXS-012 | Dependency safety gates must run when available: `cargo audit`, `cargo deny`, `cargo geiger`, or local equivalents. | MEDIUM |

## Required Workflow

1. List the invariants before editing code.
2. Move validation to boundaries: parse raw input into refined/domain types.
3. Make fields private when external mutation could violate an invariant.
4. Prefer total helper functions returning typed errors over panics.
5. Keep unsafe local, documented, and tested through safe wrappers.
6. Validate with the most specific available commands first, then broaden only as risk warrants.

## Validation Ladder

Use commands already configured in the project; do not add new tooling just to satisfy this list.

1. `cargo fmt --check`
2. `cargo clippy --all-targets --all-features -- -D warnings`
3. `cargo test`
4. `cargo miri test` for unsafe, aliasing, layout, or pointer-sensitive code.
5. `cargo kani` for bounded safety/correctness proofs where harnesses exist.
6. `cargo audit` or `cargo deny check` for supply-chain safety.

## Source Basis

See `docs/rust-safety/safe-rust-x-safety-source-map.md` for the reviewed talk, Netstack3 sources, and safe Rust reference map.
