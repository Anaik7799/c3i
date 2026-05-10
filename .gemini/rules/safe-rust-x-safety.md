# Safe Rust X-Safety Rule

All generated or modified Rust must be safe-by-construction. Encode domain, protocol, concurrency, parsing, serialization, authorization, and resource-state invariants in Rust types wherever practical.

Mandatory checks:

- Prefer refined types, typestates, private fields, smart constructors, exhaustive enums, RAII guards, and checked conversions.
- Do not add production `unwrap`, `expect`, `panic!`, `todo!`, unchecked indexing, unchecked slicing, or `unreachable!` unless the impossible state is type-proven and documented.
- Do not add `unsafe` unless isolated to the smallest module, hidden behind safe APIs, documented with `SAFETY:` or `# Safety`, and backed by tests or verification.
- Do not use raw `String`, integer, JSON, or map values deep inside core logic when a domain type can represent the invariant.
- Do not hold blocking locks or guards across `.await`; document or encode lock ordering.
- Use `TryFrom`, `checked_*`, `saturating_*`, or explicit wrapping operations for numeric conversions.
- Redact secrets and review `Debug`, `Serialize`, and `Deserialize` derives for sensitive fields.
- Run focused Rust tests and available safety gates: `cargo fmt --check`, `cargo clippy --all-targets --all-features -- -D warnings`, `cargo test`, `cargo miri test`, `cargo kani`, `cargo audit`, or `cargo deny check`.

Source basis: `docs/rust-safety/safe-rust-x-safety-source-map.md`.
