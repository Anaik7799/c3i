# Safe Rust X-Safety Governance — Netstack3 Research, Rules, Skills, ZK/Email Closure

**Date**: 2026-05-10
**Task ID**: 116549436589205923
**URN**: urn:c3i:task:misc:116549436589205923
**Priority**: P1
**Operator**: Abhijit Naik
**Recipient**: abhijit.naik@bountytek.com
**Scope**: Review RustConf 2024 “Safety in an Unsafe World”, Netstack3, and safe Rust web/video/article corpus; create safe-Rust skills and rules; capture learnings, RETE-UL/ruliological logic, STAMP/FMEA analysis, codegen rules, ZK ingestion, and email handoff.

---

## 1. Scope & Trigger

The operator requested a complete safe-Rust governance pass based on Joshua Liebow-Feeser’s RustConf 2024 talk “Safety in an Unsafe World”, Netstack3, and related web articles, YouTube talks, and webpages. The requested closure included:

- Review the talk at `https://youtu.be/qd3x5MCUrhw?is=KwWUrC9aWVBd3xTZ`.
- Interpret `netstat3` as Fuchsia `Netstack3`, the Rust networking stack discussed in the talk.
- Identify all useful safe-code web articles, talks, pages, and related references.
- Create skills and rules for safe Rust code.
- Capture detailed analysis, code generation rules, learning transfer, RETE-UL, ruliological reasoning, STAMP, and FMEA.
- Publish as Markdown journal, HTML report, slide deck, links manifest, ZK ingestion, and email.

The implementation scope covered the work surface and the canonical C3I tree so Claude, Gemini, OpenCode/Codex-compatible agents, and future C3I workflows can load the new rule automatically.

---

## 2. Pre-State Assessment

### Existing Constraints

- C3I already had a universal fp-core Rust rule: Rust changes should prefer functional abstractions, isolated IO/FFI boundaries, `Result`/`Option`, and no new panic paths.
- Existing rules focused on functional style and runtime governance but did not yet capture the Netstack3 “X-safety” method as a first-class rule.
- The work surface contained a safe-Rust source map and skills from the first pass, but the canonical C3I tree did not yet have the same rule/skill parity.

### Pre-State Gaps

| Gap | Risk | Closure Action |
| --- | --- | --- |
| No canonical X-safety rule | Future Rust code may remain memory-safe but protocol-unsafe | Added `.claude`, `.gemini`, and `.agents` safe-Rust rules/skills |
| No durable source map | Learning cannot be audited later | Added `docs/rust-safety/safe-rust-x-safety-source-map.md` |
| No journal bundle | Operator cannot review decisions, STAMP, FMEA, or ZK evidence | Created this bundle |
| No ZK ingestion | Search/retrieval cannot recall the learning | Planned `sa-plan ingest-docs` closure |
| No email handoff | Operator does not receive closure summary | Prepared and sent email with attachments |

---

## 3. Execution Detail

### 3.1 Source Review

Reviewed and captured the following source classes:

- **Primary talk**: Joshua Liebow-Feeser, “Safety in an Unsafe World”, RustConf 2024.
- **Talk slides**: Safety in an Unsafe World PDF.
- **LWN coverage**: “Safety in an unsafe world”, including Netstack3 lock-ordering and deployment evidence.
- **Fuchsia Netstack3 docs**: roadmap, contributing guide, docs directory, core/bindings split, static typing, parsing/serialization, dual-stack sockets.
- **Rust official docs**: unsafe keyword, undefined behavior, Rustonomicon exception safety, Rust Book unsafe chapter, Rust API Guidelines documentation sections.
- **Tooling docs**: Clippy, Miri, Kani, RustSec/cargo-audit, cargo-deny.
- **Safe abstraction references**: Rust for Linux safety-contract talks, Aria Beingessner unsafe-code talk, Jack Wrenn safe transmutation coverage, zerocopy docs.
- **Design primers**: Parse Don’t Validate, Type Safety Back and Forth, Ghosts of Departed Proofs, Typestate Pattern in Rust.

### 3.2 Rules and Skills Implemented

Canonical C3I files added or updated:

- `docs/rust-safety/safe-rust-x-safety-source-map.md`
- `.claude/rules/safe-rust-x-safety.md`
- `.gemini/rules/safe-rust-x-safety.md`
- `.claude/skills/safe-rust-x-safety/SKILL.md`
- `.gemini/skills/safe-rust-x-safety/SKILL.md`
- `.agents/skills/safe-rust-x-safety/SKILL.md`
- `CLAUDE.md`
- `GEMINI.md`
- `AGENTS.md`

Work-surface adapter files were also updated for local Codex/GPT compatibility.

### 3.3 Codegen Rule Transfer

The rule translates the Netstack3 X-safety method into codegen constraints:

1. **Define invariants** on types, lifetimes, traits, const generics, markers, capability tokens, typestates, or sealed modules.
2. **Enforce invariants** with private fields, smart constructors, checked conversions, RAII guards, exhaustive enums, and minimal unsafe wrappers.
3. **Consume invariants** only through APIs whose signatures prove preconditions are satisfied.
4. **Verify invariants** with focused tests first, then Miri/Kani/fuzzing/supply-chain gates where practical.

### 3.4 Touched Rust Alignment

The current gateway patch was adjusted to remove new production `expect`-based runtime creation. Blocking wrappers now return an initialization error instead of panicking:

- `send_telegram` → `block_on_runtime(async_send_telegram(...))`
- `poll_telegram` → `block_on_runtime(async_poll_telegram(...))`
- `send_matrix` → `block_on_runtime(async_send_matrix(...))`
- `poll_matrix` → `block_on_runtime(async_poll_matrix(...))`

Focused validation passed: `cargo fmt --check` and `cargo test gateway -- --nocapture`.

---

## 4. Root Cause Analysis

### Five-Why Analysis

1. **Why did safe-Rust governance need a new rule?**
   Existing rules enforced functional Rust style but did not explicitly encode arbitrary safety properties beyond memory/thread safety.

2. **Why is memory safety insufficient?**
   Safe Rust can still permit protocol bugs, lock-order deadlocks, auth-state confusion, invalid parsing states, numeric overflow, secret leakage, and panic-driven denial of service.

3. **Why use Netstack3 as a model?**
   Netstack3 demonstrates a production-scale Rust networking system using type-level design to encode safety properties such as protocol states, IP versions, parsing/serialization properties, and lock ordering.

4. **Why make this a skill and rule instead of a note?**
   Rules are loaded as governance; skills provide operational workflow. A note can be ignored. A rule and skill can route future agents into the method.

5. **Why include ZK/email artifacts?**
   C3I uses durable journal + ZK recall + operator notification as its closure pattern. Without durable ingestion and handoff, the learning does not become operational memory.

### Root Cause

The missing invariant was not “Rust code must be safe”; it was “Rust code must be designed so domain-invalid programs do not compile.” The new rule makes that invariant explicit and routeable.

---

## 5. Fix Taxonomy

| Category | Fix | Artifact |
| --- | --- | --- |
| Rule | Added SRXS-001..012 | `.claude/rules/safe-rust-x-safety.md`, `.gemini/rules/safe-rust-x-safety.md` |
| Skill | Added workflow/checklists | `.claude/skills/safe-rust-x-safety/SKILL.md`, `.gemini/skills/...`, `.agents/skills/...` |
| Source map | Captured reviewed talks/articles/tools | `docs/rust-safety/safe-rust-x-safety-source-map.md` |
| Adapter | Wired into CLAUDE/GEMINI/AGENTS routing | `CLAUDE.md`, `GEMINI.md`, `AGENTS.md` |
| Codegen | Added explicit safe-by-construction codegen guidance | Rule + skill bodies |
| Runtime patch | Removed new production runtime `expect` path | `src/gateway.rs` in work surface |
| Publication | Created journal, HTML, deck, email, manifest | This bundle |

---

## 6. Patterns & Anti-Patterns Discovered

### Patterns

- **X-safety loop**: definition → enforcement → consumption.
- **Functional core / imperative shell**: Netstack3’s core/bindings split mirrors C3I’s Rust/Gleam split and prior fp-core rule.
- **Parse, don’t validate**: raw input must become typed evidence at the boundary.
- **Phantom evidence**: zero-sized markers and phantom types can carry proof without runtime overhead.
- **Typestate APIs**: expose only methods valid for a state.
- **RAII safety**: guards can enforce lock ordering, token lifetimes, and cleanup.
- **Safe wrappers over unsafe**: unsafe code is a proof boundary, not a convenience tool.

### Anti-Patterns

- Public structs with invariant-breaking fields.
- Boolean validators that leave raw values in core logic.
- `unwrap`/`expect`/panic paths in production codegen.
- Caller obligations expressed only in comments when types can encode them.
- Async code holding blocking locks across `.await`.
- Secret-bearing structs with unredacted `Debug`/`Serialize`/`Deserialize` derives.
- Stringly protocol states and lossy error booleans.

---

## 7. Verification Matrix

| Check | Command / Evidence | Result |
| --- | --- | --- |
| Source map exists | `docs/rust-safety/safe-rust-x-safety-source-map.md` | PASS |
| Claude rule exists | `.claude/rules/safe-rust-x-safety.md` | PASS |
| Gemini rule exists | `.gemini/rules/safe-rust-x-safety.md` | PASS |
| Claude skill exists | `.claude/skills/safe-rust-x-safety/SKILL.md` | PASS |
| Gemini skill exists | `.gemini/skills/safe-rust-x-safety/SKILL.md` | PASS |
| OpenCode/Codex skill exists | `.agents/skills/safe-rust-x-safety/SKILL.md` | PASS |
| Agent routing updated | `AGENTS.md` safe-Rust section | PASS |
| Claude/Gemini routing updated | `CLAUDE.md`, `GEMINI.md` §3.7.1 | PASS |
| Rust formatting | `cargo fmt --check` in `/home/an/dev/ver/work` | PASS |
| Focused Rust tests | `cargo test gateway -- --nocapture` | PASS, 6 tests |
| Production panic audit | `rg '\.(unwrap|expect)\(|panic!|todo!|unreachable!' src/gateway.rs` | PASS for production; test-only expects remain |
| Link manifest validation | Rust finalizer `validate` mode | PASS |
| ZK ingestion | Escalated `./sa-plan ingest-docs` | PASS — 63 holons, 17 STAMP refs, 0 errors, total KMS holons 37677 |
| Email | Rust finalizer invoked `sa-plan send-email` | PASS — sent to `abhijit.naik@bountytek.com` with 6 attachments |

---

## 8. Files Modified

### Canonical C3I

- `docs/rust-safety/safe-rust-x-safety-source-map.md`
- `.claude/rules/safe-rust-x-safety.md`
- `.gemini/rules/safe-rust-x-safety.md`
- `.claude/skills/safe-rust-x-safety/SKILL.md`
- `.gemini/skills/safe-rust-x-safety/SKILL.md`
- `.agents/skills/safe-rust-x-safety/SKILL.md`
- `CLAUDE.md`
- `GEMINI.md`
- `AGENTS.md`
- `docs/journal/20260510-safe-rust-xsafety-netstack3-governance-journal.md`
- `docs/journal/20260510-safe-rust-xsafety-netstack3-governance-analysis.html`
- `docs/journal/20260510-safe-rust-xsafety-netstack3-governance-deck.html`
- `docs/journal/20260510-safe-rust-xsafety-netstack3-governance-email.md`
- `docs/journal/20260510-safe-rust-xsafety-netstack3-governance-index.html`
- `docs/journal/task-116549436589205923-links.json`

### Work Surface

- `docs/rust-safety/safe-rust-x-safety-source-map.md`
- `.claude/rules/safe-rust-x-safety.md`
- `.gemini/rules/safe-rust-x-safety.md`
- `.claude/skills/safe-rust-x-safety/SKILL.md`
- `.agents/skills/safe-rust-x-safety/SKILL.md`
- `CLAUDE.md`
- `AGENTS.md`
- `src/gateway.rs`
- `src/cli.rs`
- `config/work-config.toml`
- `USERS_GUIDE.md`

---

## 9. Architectural Observations

### C3I Fit

The X-safety rule complements C3I’s existing safety kernel:

- **fp-core** supplies functional style and algebraic transformations.
- **Safe Rust X-safety** supplies invariant encoding and proof-carrying APIs.
- **RETE-UL** supplies production-rule salience and dispatch governance.
- **STAMP/FMEA** supply system hazard modeling.
- **ZK ingestion** makes the method recallable by future agents.

### Netstack3 Transfer

Netstack3’s “core/bindings” split directly maps to C3I’s preferred architecture:

- core logic should be pure, platform-agnostic, and type-proven;
- shell logic should isolate IO, DB, network, FFI, and runtime effects;
- lock and protocol hazards should be encoded, not tested only after the fact.

---

## 10. Remaining Gaps

| Gap | Status | Recommended Closure |
| --- | --- | --- |
| Full live YouTube transcript not embedded | Accepted | Source map links talk/slides/LWN; avoid transcript dependency |
| Full C3I-wide Rust migration not executed | Out of scope | Apply rule incrementally to touched Rust modules |
| `cargo clippy -D warnings` not run globally | Deferred | Existing repo warning debt may block; run per touched crate |
| Miri/Kani not run | Deferred | No unsafe/layout proof harness touched in this pass |
| Cargo audit/deny not run | Deferred | Run when dependency changes are part of the patch |
| Route URLs not externally verified yet | Pending | Validate local paths and mark public routes expected unless curl succeeds |

---

## 11. Metrics Summary

| Metric | Value |
| --- | --- |
| Source categories reviewed | 7 |
| Primary sources captured | 25+ |
| New rule IDs | 12 |
| New skills/rules mirrored | Claude, Gemini, `.agents`, work adapter |
| Focused Rust tests run | 6 |
| Focused Rust test result | 6 passed, 0 failed |
| Production panic additions | 0 |
| Journal bundle artifacts | 6 |
| ZK status | Durable ingestion complete: 63 holons, 17 STAMP refs, 0 errors |
| Email status | Sent to `abhijit.naik@bountytek.com` |

---

## 12. STAMP & Constitutional Alignment

### STAMP Control Structure

| Controller | Control Action | Unsafe Control Action | Mitigation |
| --- | --- | --- | --- |
| Operator | Requests Rust codegen | Agent emits memory-safe but protocol-unsafe Rust | SRXS rule forces invariant modeling |
| Agent | Generates Rust | Adds `unwrap`, raw state, unchecked conversions | Rule blocks partial functions and requires typed boundaries |
| Reviewer | Reviews unsafe | Treats `unsafe` as local detail | Skill requires safety contract and safe-wrapper proof |
| CI/Verifier | Runs tests | Relies only on unit tests | Validation ladder adds Clippy/Miri/Kani/audit gates |
| ZK/RAG | Recalls guidance | Recalls stale fp-core-only rule | ZK ingestion adds X-safety corpus |

### STAMP Constraints

- SC-SRXS-001: New Rust must encode important domain invariants in types when practical.
- SC-SRXS-002: New unsafe must have documented proof obligations and safe wrappers.
- SC-SRXS-003: Rust codegen must not introduce production panic paths.
- SC-SRXS-004: Parser/protocol code must return typed domain values and typed errors.
- SC-SRXS-005: Async/concurrency code must not hold blocking locks across `.await`.

### Ruliological Logic

The governing rule is not “avoid unsafe”; it is “make the compiler carry the proof.” Ruliologically, the rule promotes constraints from comments/tests into admissibility criteria for generated code. A generated Rust patch is acceptable only if its public API carries enough proof for downstream functions to consume without revalidating raw state.

---

## 13. RETE-UL & FMEA Closure

### RETE-UL Rule Set

| Rule | Salience | Condition | Action |
| --- | ---: | --- | --- |
| `RustInvariantMissing` | 100 | Touched Rust accepts raw primitive where invariant matters | Require newtype/typestate/smart constructor |
| `ProductionPanicAdded` | 100 | New `unwrap`, `expect`, `panic!`, `todo!`, `unreachable!` in production | Block closure unless type-proven and documented |
| `UnsafeBoundaryAdded` | 100 | New `unsafe`, `unsafe fn`, or `unsafe trait` | Require `SAFETY:`/`# Safety`, safe wrapper, focused verification |
| `ParserLeaksRawState` | 90 | Parser validates but returns raw strings/maps | Return typed domain values/errors |
| `AsyncLockAwait` | 90 | Blocking guard crosses `.await` | Refactor lock scope or use async-safe primitive |
| `NumericNarrowing` | 80 | Narrowing/sign-changing `as` conversion | Use `TryFrom`, checked, saturating, or named wrapping op |
| `SecretDebugLeak` | 95 | Secret type derives unredacted debug/serialization | Redact or remove derives |
| `DependencySafetyChanged` | 70 | Dependency added/changed | Run audit/deny where available |

### FMEA

| Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Control |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| Protocol-invalid state accepted | Incorrect network/auth behavior | 9 | 5 | 4 | 180 | Domain types + parser boundary |
| Deadlock from lock inversion | Service hang | 9 | 4 | 5 | 180 | Lock hierarchy / type-level ordering |
| Unsafe wrapper unsound | UB for safe caller | 10 | 3 | 5 | 150 | Safety docs + safe-wrapper tests + Miri/Kani |
| Panic in production path | DoS / crash | 8 | 5 | 3 | 120 | No new panic rule + total functions |
| Secret logged/serialized | Credential exposure | 10 | 3 | 4 | 120 | Redaction and derive review |
| Numeric truncation | Incorrect bounds, bypass, overflow | 7 | 4 | 4 | 112 | Checked conversions |
| Supply-chain vulnerability | Compromise via dependency | 9 | 3 | 5 | 135 | audit/deny gates |

### Conclusion

The safe-Rust governance pass is complete at the rule/skill/artifact level. The operational learning is: safe Rust should not stop at memory safety; C3I Rust codegen must encode safety properties as compile-time evidence wherever practical. Netstack3 provides the model: make illegal states unrepresentable, make invalid control flows fail to compile, and reserve runtime tests for behavior that cannot be encoded statically.
