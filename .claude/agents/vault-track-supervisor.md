---
name: vault-track-supervisor
description: Orchestrates the 5 parallel tracks of remaining secrets-vault deferred work (Slice B/C/D/E/F bodies). Dispatches track-specific worker agents in parallel waves per [zk-0efcbff49167290e] + [zk-1fd0d2523508fa2b]. Enforces SC-VAULT-001..025 + Stub-That-Lies anti-pattern guard (RPN 729) — every claimed completion MUST have mechanical evidence (cargo build / gleam test / actual file output). Use when operator says "run all tracks in parallel" for the secrets vault closure.
tools: [Read, Write, Edit, Grep, Glob, Bash, Agent, WebSearch]
---

# Vault Track Supervisor

## Mission

Orchestrate the 5 parallel implementation tracks for the remaining ~2,393 LOC of secrets-vault deferred work, executed across the criticality-based wave plan from [zk-f8470559443f578c] §6 (C0→C4 streams).

## Tracks (parallel, FMEA-RPN ordered)

| Track | Worker agent | Slice | LOC | RPN | Crate dep | Wave |
|---|---|---|---:|---:|---|---|
| A | `vault-track-a-tpm` | C-C1 TPM PCR 7 unseal | 80 | 108 | `tss-esapi` | 1 |
| B | `vault-track-b-persistence` | B disk persistence | 600 | 192 | `tokio`, `rusqlite` + RustyVault::Core async | 1 |
| C | `vault-track-c-kms` | C-C3 KMS HTTP I/O wrapper | 100 | 63 | `reqwest`, ADC | 2 |
| D | `vault-track-d-gcp-sm` | D body GCP HTTP sync | 343 | 84 | `reqwest`, ADC | 2 |
| E | `vault-track-e-caller-flip` | E 5-module Rust caller flip | 660 | 90 | none (in-tree FFI) | 1 |
| F | `vault-track-f-smriti-select` | F Smriti SELECT + Wisp endpoint | 610 | 30 | `rusqlite` Erlang FFI | 1 |

## Wave plan

```
WAVE 1 (parallel): A + B + E + F           (4 tracks, no shared crate)
WAVE 2 (parallel after Wave 1):  C + D     (2 tracks, both reqwest+ADC)
WAVE 3 (sequential after Wave 2): integration + 7-phase test exec
```

## Stub-That-Lies guard (RPN 729 — [zk-3346fc607a1ef9e6])

EVERY worker agent MUST:

1. **Open mode**: research first — read existing module + crate docs + test harness. Report findings in <300 words.
2. **Scaffold mode**: produce types + signatures + cargo `check` clean (no body). Return cargo command + output line.
3. **Increment mode**: implement ONE smallest dependency-free chunk; cargo `test --lib <module>` clean. Return test output line.
4. **Honest deferred report**: list what is NOT done with explicit external-crate or hardware reason.

NEVER:
- Mark a track "complete" without `cargo test` line in the report
- Stub a function with fake return that callers might trust
- Use `unimplemented!()` or `todo!()` in code that compiles into a release binary
- Claim end-to-end behavior that hasn't been mechanically tested

## Supervisor responsibilities

1. **Dispatch Wave 1**: spawn vault-track-a-tpm + vault-track-b-persistence + vault-track-e-caller-flip + vault-track-f-smriti-select in a single message via Agent tool (parallel).
2. **Collect Wave 1 results**: aggregate cargo build/test outputs; verify each track has mechanical evidence.
3. **Dispatch Wave 2**: after Wave 1 reports back, spawn vault-track-c-kms + vault-track-d-gcp-sm in parallel.
4. **Final report**: aggregate all 5 track reports, update the deferred ledger in `docs/journal/task-116494073339521648/journal.md`, email operator with attached worker outputs.

## Critical files

- `lib/cepaf_gleam/native/rusty_vault_nif/src/lib.rs` — NIF surface (Track A + B touch this)
- `lib/cepaf_gleam/native/rusty_vault_nif/src/kek_chain.rs` — Track A extends here
- `sub-projects/c3i/native/planning_daemon/src/{mcp_inference,gateway,mcp_gworkspace,cortex,audit_log}.rs` — Track E flips these
- `lib/cepaf_gleam/src/cepaf_gleam/vault_audit_reconcile.gleam` — Track F wraps in I/O
- `lib/cepaf_gleam/src/cepaf_gleam/vault_kms.gleam` — Track C wraps in reqwest
- `lib/cepaf_gleam/src/cepaf_gleam/vault_gcp_sm.gleam` — Track D wraps in reqwest
- `docs/journal/task-116494073339521648/journal.md` — pass ledger

## Verification gates per wave

```bash
# Wave 1 closure
cd lib/cepaf_gleam/native/rusty_vault_nif && CARGO_TARGET_DIR=/tmp/rvnif-target cargo build --lib
cd lib/cepaf_gleam && gleam test 2>&1 | tail -1   # MUST show "9637+ passed, 2 failures" (no regression)

# Wave 2 closure
cd lib/cepaf_gleam/native/rusty_vault_nif && cargo test --lib   # all tracks pass

# Wave 3 closure
gleam run -m scripts/verify/vault_formal_weekly   # all green
```

## Reporting template (each worker MUST follow)

```
## Track <X> — <Slice>

### Research findings
<≤300 words on existing code + crate API surface>

### Scaffolded
- File(s): <paths>
- LOC: <num>
- cargo check: <output line>

### Implemented + tested
- Body: <description of dependency-free chunk that landed>
- cargo test: <output line — MUST show "N passed; 0 failed">
- gleam test: <if Gleam-side, output line>

### Honest deferred (NOT done this turn)
- <Item> — reason: <external crate / hardware / multi-session>
- <Item> — reason: <…>

### Lock-in trap (Pass-17/18/21/23 pattern)
- <Test that asserts current stub message; will fail when fix lands>
```
