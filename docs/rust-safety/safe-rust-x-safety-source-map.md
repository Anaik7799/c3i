# Safe Rust X-Safety Source Map

Date: 2026-05-10

Scope: source review for safe Rust rules and skills, based on the RustConf 2024 talk `Safety in an Unsafe World`, Fuchsia Netstack3, and adjacent Rust safety material. The user term `netstat3` is interpreted as `Netstack3`, the Fuchsia Rust networking stack referenced by the talk.

## Reviewed Sources

| Source | Type | Use In Rules |
| --- | --- | --- |
| [Joshua Liebow-Feeser: Safety in an Unsafe World, RustConf 2024](https://www.youtube.com/watch?v=qd3x5MCUrhw) | YouTube talk | Core X-safety method: make invalid programs fail at compile time. |
| [Safety in an Unsafe World slides](https://joshlf.com/files/talks/Safety%20in%20an%20Unsafe%20World.pdf) | Slides | Definition → enforcement → consumption framework; panic and partial-function guidance. |
| [LWN: Safety in an unsafe world](https://lwn.net/Articles/995814/) | Article | Netstack3 field evidence, lock-ordering example, tradeoffs around complexity. |
| [RustConf 2024 program](https://2024.rustconf.com/programs/) | Conference page | Talk abstract and topic boundaries. |
| [Fuchsia roadmap: Netstack3](https://fuchsia.dev/fuchsia-src/contribute/roadmap/2021/netstack3) | Project doc | Netstack3 goals: Rust-based network stack, Fuchsia ownership, dynamic networking requirements. |
| [Netstack.FM Episode 8: Fuchsia’s Netstack3](https://netstack.fm/) | Podcast/show notes | Netstack3 protocol surface and production networking context. |
| [Netstack.FM Episode 10: zerocopy](https://netstack.fm/) | Podcast/show notes | Safe zero-copy packet parsing, Kani, formal verification, Safe Transmute context. |
| [Netstack3 Async Socket Handler Case Study](https://rust-lang.github.io/async-fundamentals-initiative/evaluation/case-studies/socket-handler.html) | Rust async case study | Async handler typing and protocol-specific handler separation. |
| [Rust for Linux: Code Documentation & Tests](https://www.linuxfoundation.org/webinars/rust-for-linux-code-documentation-tests) | Webinar | Safety contracts, code documentation, doctests and kernel-style unsafe review. |
| [Rust Reference: unsafe keyword](https://doc.rust-lang.org/reference/unsafe-keyword.html) | Official language reference | Unsafe marks extra safety conditions or asserts conditions are satisfied. |
| [Rust Reference: undefined behavior](https://doc.rust-lang.org/reference/behavior-considered-undefined.html) | Official language reference | Unsafe code must be sound for safe clients; UB list is not exhaustive. |
| [Rustonomicon: exception safety](https://doc.rust-lang.org/nomicon/exception-safety.html) | Official unsafe guide | Panic/unwind safety for unsafe internals and transient invalid states. |
| [Rust API Guidelines: documentation](https://rust-lang.github.io/api-guidelines/documentation.html) | Official guideline | `# Safety`, `# Panics`, `# Errors`, examples, invariants. |
| [Rust Book: Unsafe Rust](https://rust-lang.github.io/book/ch20-01-unsafe-rust.html) | Official book | Unsafe is a constrained escape hatch, not a general bypass. |
| [Clippy docs](https://doc.rust-lang.org/stable/clippy/) | Official lint docs | Static lint categories for correctness, suspicious code, complexity, perf. |
| [Miri](https://github.com/rust-lang/miri/) | Rust tool | UB detection for unsafe contracts and interpreter-based test execution. |
| [Kani Rust Verifier](https://model-checking.github.io/kani/) | Verification tool | Prove safety/correctness properties, panics, overflow, assertions, contracts. |
| [RustSec Advisory Database](https://rustsec.org/) | Supply-chain security | `cargo audit`, `cargo deny`, vulnerable/yanked dependency checks. |
| [Ferrocene Safety Manual: Handling Unsafety](https://public-docs.ferrocene.dev/main/safety-manual/rustc/unsafety.html) | Safety manual | Localize unsafe, avoid UB, prefer existing core unsafe APIs over novel unsafe. |
| [Pitfalls of Safe Rust](https://corrode.dev/blog/pitfalls-of-safe-rust/) | Article | Safe Rust still has logic, panic, overflow, serialization, TOCTOU, input-bound risks. |
| [zerocopy crate docs](https://docs.rs/zerocopy/latest/zerocopy/) | Crate docs | Derive-checked byte validity, alignment, zero-copy packet parsing patterns. |
| [Parse, Don’t Validate](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/) | Article | Boundary parsing and proof-carrying values. |
| [Type Safety Back and Forth](https://www.parsonsmatt.org/2017/10/11/type_safety_back_and_forth.html) | Article | Moving preconditions into type signatures and APIs. |
| [Ghosts of Departed Proofs](https://www.iog.io/en/research/library/papers/ghosts-of-departed-proofs-functional-pearls/) | Paper | Phantom proof tokens and zero-runtime precondition evidence. |
| [The Typestate Pattern in Rust](https://cliffle.com/blog/rust-typestate/) | Article | Compile-time state transitions and APIs that hide invalid methods. |

## Extracted Operating Model

1. **Define** the safety property on something Rust can reason about: a type, lifetime, trait, const generic, capability token, marker, typestate, or sealed module boundary.
2. **Enforce** the property at the smallest ownership boundary with private fields, smart constructors, sealed traits, exhaustive enums, RAII guards, checked conversions, and limited unsafe.
3. **Consume** the property only through APIs whose signatures prove the preconditions are already satisfied.
4. **Verify** with compiler gates, unit/property tests, Miri for UB-sensitive paths, Kani for bounded proofs, fuzzing for parsers, and dependency audits.

## Safe Rust Rule Themes

- **X-safety over memory-safety only**: Rust’s baseline memory/thread safety is insufficient for protocol, crypto, locking, parsing, serialization, authorization, and resource-state correctness.
- **Parse, do not validate late**: Convert raw inputs into domain types at boundaries; internal functions should accept refined types, not raw strings/integers/maps.
- **No illegal public states**: Public fields must not expose invariants. Use private fields, sealed constructors, and domain-specific newtypes.
- **Partial functions are smells**: `panic!`, indexing, unchecked slicing, `unwrap`, `expect`, and caller-invalid `Option`/`Result` returns indicate missing type modeling.
- **Unsafe is a proof boundary**: New unsafe requires a documented safety contract, a local module boundary, tests that exercise safe wrappers, and preferably Miri/Kani.
- **Locking must be designed**: Enforce ordering with types or a documented lock hierarchy. Never hold blocking locks or guards across `.await`.
- **Protocol errors should mirror specifications**: Complex protocol rules deserve complex but faithful enums, not stringly errors or lossy booleans.
- **Supply chain is part of safety**: Audit dependencies, licenses, yanked crates, build scripts, unsafe-heavy crates, and transitive risk.

## Required Review Checklist

- Every public API states which invariants it requires and returns only states it can uphold.
- Every constructor either proves invariants or is private/internal.
- Every `unsafe` block has a nearby `SAFETY:` explanation and is hidden behind safe APIs.
- Every `unsafe fn` or `unsafe trait` has a `# Safety` section.
- Every public panic has a `# Panics` section, or the panic is removed.
- Every numeric conversion is `TryFrom`, `checked_*`, `saturating_*`, or explicitly wrapping.
- Every parser returns a typed AST/domain value; raw JSON/string input does not leak into core logic.
- Every lock has an ordering story; async code does not hold non-async guards across `.await`.
- Every dependency gate has at least `cargo audit` or `cargo deny` when available.
- Every touched Rust module has focused tests; unsafe and parser code also gets Miri, fuzz, or Kani when practical.
