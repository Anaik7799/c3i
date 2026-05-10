---
name: vault-track-a-tpm
description: Slice C-C1 worker — TPM PCR 7 unseal scaffolding via tss-esapi. Research the crate, add Cargo dep, scaffold types in kek_chain.rs, gate with cargo check. Per [zk-3346fc607a1ef9e6] no Stub-That-Lies; report only what compiles.
tools: [Read, Write, Edit, Grep, Glob, Bash, WebSearch, WebFetch]
---

# Track A — TPM PCR 7 unseal (C-C1)

## Mission (Wave 1, parallel)

Add `tss-esapi` Rust crate to `rusty_vault_nif` and scaffold the TPM PCR 7 unseal types in `kek_chain.rs` (Pass-13/14 module). DO NOT attempt a real unseal — TPM hardware not available in this env.

## Workflow

1. Read `lib/cepaf_gleam/native/rusty_vault_nif/src/kek_chain.rs` (Pass-14 added `tpm_present()` probe)
2. Research tss-esapi 7.x API surface for `Context::unseal_with_policy` and PCR 7 policy session — produce ≤300 word summary
3. Add `tss-esapi = "7"` to `Cargo.toml` `[dependencies]`
4. Run `CARGO_TARGET_DIR=/tmp/rvnif-target cargo check --lib` — if it doesn't compile (e.g. system TSS lib missing), revert and report blocker honestly
5. If it compiles: scaffold `pub fn tpm_unseal_pcr7(blob: &[u8]) -> Result<Zeroizing<Vec<u8>>, KekDeriveError>` returning a `DeriveFailed("tpm_unseal_not_yet_wired")` — TYPE-LEVEL gate only
6. Add 1 unit test that proves the function returns the expected error when called (lock-in trap per Pass-17/21 pattern)
7. Run `cargo test --lib kek_chain::tests::tpm_unseal_returns_not_yet_wired_error`
8. Report per supervisor template

## Hard rules (Stub-That-Lies guard)

- DO NOT call any TPM hardware API
- DO NOT add `unsafe` blocks
- DO NOT use `unimplemented!()` / `todo!()` macros
- The function MUST return a typed `Err` with stable reason token `"tpm_unseal_not_yet_wired"`
