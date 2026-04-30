---
paths: "sub-projects/c3i/native/planning_daemon/**"
---

# Planning Daemon Test Surface — Rust-Only Mandate (SC-PD-RUST-ONLY)

## SUPREME MANDATE

**The `sub-projects/c3i/native/planning_daemon/` test, fixture-generation,
manifest, and CI surface MUST be 100 % Rust.**

No Python, no shell scripts with logic, no Node/JS, no other-language tooling
inside or transitively reachable from `cargo test -p planning_daemon`.

This rule was promoted on 2026-04-29 after migration of `tests/data/gen.py`
(226 lines) → `tests/fixture_regen.rs` (Rust, image + hound + serde_json +
sha2). See journal `docs/journal/20260429-0219-gemma4-multimodal-test-corpus-completion.md`
addendum and ZK refs [zk-3db8e4cfa04b5703] / [zk-de72a2ad16a4f3ba] ("no Python
fragility") and [zk-bf607c9df83ece3e] (SC-ARCH-SPLIT — Rust for ops).

## Why this rule exists

Pre-migration state had `tests/data/gen.py` as the synthetic-fixture generator.
That created two failure modes:

1. **CI fragility** — Python interpreter version drift, missing PIL/struct
   assumptions, OS-package dependency. The Rust `cargo test` surface depends
   only on the workspace toolchain.
2. **SC-ARCH-SPLIT violation** — Rust handles ops; Python sat in the middle
   of the test pipeline with no language-boundary contract.

Migration delivered the same 25 fixtures + manifest with strictly Rust
toolchain (`image`, `hound`, `serde_json`, `sha2`, `base64`). Manifest gate
`tests/inference_manifest_check.rs` enforces SHA-256 parity per
[zk-bd82645aedcb5ef4] "Stub That Lies" anti-pattern.

## STAMP Constraints

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-PD-RUST-ONLY-001 | `cargo test -p planning_daemon` MUST NOT spawn Python, Node, Ruby, Perl, or any non-Rust interpreter | CRITICAL |
| SC-PD-RUST-ONLY-002 | No `*.py` / `*.pyi` / `*.js` / `*.mjs` / `*.rb` / `*.pl` / `*.sh` files MAY exist under `native/planning_daemon/` (sole exception: vendored upstream `whisper.cpp/`) | CRITICAL |
| SC-PD-RUST-ONLY-003 | All fixture generation MUST use Rust `#[ignore]`-gated tests (current: `tests/fixture_regen.rs::{regenerate_fixtures, regenerate_manifest_toml}`) | CRITICAL |
| SC-PD-RUST-ONLY-004 | New test infrastructure MUST be added as `tests/*.rs` integration tests or `src/lib.rs` `#[cfg(test)] mod tests {}` units | CRITICAL |
| SC-PD-RUST-ONLY-005 | Helpers MUST live in `tests/helpers/mod.rs` and be `mod helpers;`-imported (per existing pattern) | HIGH |
| SC-PD-RUST-ONLY-006 | Manifest (`tests/data/MANIFEST.toml`) regen MUST be Rust-driven (`regenerate_manifest_toml` test) — never hand-edited or shell-scripted | CRITICAL |
| SC-PD-RUST-ONLY-007 | Dev-dependencies MUST be `crates.io` Rust crates (current: `tempfile`, `hound`); no `pip install` / `npm install` requirements | CRITICAL |
| SC-PD-RUST-ONLY-008 | If a future test needs PTY/TTY interaction, use a Rust crate (`portable-pty`, `nix::pty`); never `pty.fork()` via Python | HIGH |
| SC-PD-RUST-ONLY-009 | Vendored upstream code (`native/whisper.cpp/`) is exempt — modifying upstream breaks updates per SC-ARCH-SPLIT exception | HIGH |
| SC-PD-RUST-ONLY-010 | CI / cargo-check enforcement: presence of any non-Rust file under `native/planning_daemon/{src,tests}` (excluding vendored deps) is a P0 build-blocking violation | CRITICAL |

## AOR Rules

| ID | Rule |
|----|------|
| AOR-PD-RUST-ONLY-001 | NEVER create `*.py`/`*.sh`/`*.js` files in `native/planning_daemon/` |
| AOR-PD-RUST-ONLY-002 | When migrating existing scripts, port to Rust integration tests with `#[ignore]` gating for one-shot operations |
| AOR-PD-RUST-ONLY-003 | When the workspace already has a Rust crate covering the need (e.g. `image` for PNG, `hound` for WAV, `sha2` for SHA-256), use it; do NOT add inline interpreter calls |
| AOR-PD-RUST-ONLY-004 | The `MANIFEST.toml` regen flow is `regenerate_fixtures` then `regenerate_manifest_toml` then `inference_manifest_check`; never shell out |
| AOR-PD-RUST-ONLY-005 | Pre-commit hook (when added) MUST `find native/planning_daemon -name "*.py" -not -path "*/whisper.cpp/*"` and fail on non-empty result |
| AOR-PD-RUST-ONLY-006 | Code review: any PR adding non-Rust source to `native/planning_daemon/` (excluding `whisper.cpp/`) MUST be rejected |

## Forbidden Patterns

```bash
# FORBIDDEN — Python fixture generator (the original SC-PD-RUST-ONLY violation)
python3 tests/data/gen.py                       # VIOLATION SC-PD-RUST-ONLY-002

# FORBIDDEN — Shell scripts with logic
./tests/refresh_fixtures.sh                     # VIOLATION SC-PD-RUST-ONLY-002

# FORBIDDEN — Node helpers
node tests/manifest_regen.js                    # VIOLATION SC-PD-RUST-ONLY-001

# FORBIDDEN — pip install in dev workflow
pip install pillow numpy                        # VIOLATION SC-PD-RUST-ONLY-007

# FORBIDDEN — Python PTY drivers
import pty; pty.fork() ...                      # VIOLATION SC-PD-RUST-ONLY-008
```

## Authorised Patterns

```bash
# OK — Rust integration test for fixture regen
cargo test --test fixture_regen --release -- --ignored regenerate_fixtures
cargo test --test fixture_regen --release -- --ignored regenerate_manifest_toml

# OK — Rust unit / integration tests
cargo test -p planning_daemon

# OK — Rust manifest verification
cargo test --test inference_manifest_check --release

# OK — Adding a Rust dev-dep
[dev-dependencies]
hound = "3.5"
```

## CI gate (proposed pre-commit hook)

```bash
#!/usr/bin/env bash
# Reject any non-Rust source under planning_daemon (excluding vendored).
violations=$(find sub-projects/c3i/native/planning_daemon \
  \( -name "*.py" -o -name "*.pyi" -o -name "*.js" -o -name "*.mjs" \
     -o -name "*.rb" -o -name "*.pl" \) \
  -not -path "*/whisper.cpp/*")
if [ -n "$violations" ]; then
  echo "[SC-PD-RUST-ONLY-002 VIOLATION] Non-Rust source under planning_daemon:"
  echo "$violations"
  exit 1
fi
```

## RETE-UL rule (proposed addition to `evaluate_preflight`)

```grl
rule "PlanningDaemonRustOnly" salience 95 {
  when Preflight.NonRustFilesUnderPlanningDaemon == true
  then Preflight.Decision = "Block"; Preflight.Reason = "SC-PD-RUST-ONLY-002 violation";
}
```

## Cross-references

- `.claude/rules/rust-gleam-split.md` — SC-ARCH-SPLIT (parent rule)
- `.claude/rules/test-data-corpus.md` — SC-TESTDATA fixture corpus contract
- `.claude/rules/mistral-rust-api-mandate.md` — SC-INFER-RUST-API (mistral.rs mandate)
- `tests/fixture_regen.rs` — canonical Rust fixture generator (replaces gen.py)
- `tests/inference_manifest_check.rs` — SHA-256 parity gate
- Migration journal: `sub-projects/c3i/docs/journal/20260429-0219-gemma4-multimodal-test-corpus-completion.md`

## Governance parity

Mirror at `.gemini/rules/planning-daemon-rust-only-tests.md` per SC-SYNC-DOC-007.

## Constitutional alignment

- **SC-ARCH-SPLIT**: Rust for ops/tests, Gleam for UI/types — this rule is a domain-specific tightening of the parent split.
- **Ψ-2 (Reversibility)**: any non-Rust intrusion is `git revert`-able to the all-Rust baseline established 2026-04-29.
- **Ψ-3 (Verification)**: `cargo test -p planning_daemon` is the single verification gate; no out-of-band interpreter dependencies.
- **Omega-3 (Zero-Defect)**: removing language-boundary fragility eliminates a class of CI flakes.
