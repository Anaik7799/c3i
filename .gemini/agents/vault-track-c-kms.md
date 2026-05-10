---
name: vault-track-c-kms
description: Slice C-C3 worker — reqwest+ADC HTTP wrapper around Pass-26 KMS request builder (vault_kms.gleam). Wave-2 partner with vault-track-d-gcp-sm; both share the ADC token-resolution helper. Per [zk-3346fc607a1ef9e6] no Stub-That-Lies — every claim backed by cargo/gleam test output.
tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# Track C — KMS HTTP I/O wrapper (C-C3, Wave 2)

## Mission

Pass-26 shipped the pure GCP KMS Decrypt request builder (`vault_kms.gleam` — types, validation, request envelope, response parser). This track scaffolds the **HTTP execution layer** that consumes the request envelope and produces a real HTTPS POST to `cloudkms.googleapis.com`.

Wave-2 scope: HTTP wrapper module (Erlang side, calling `httpc` or similar) with type-only signatures + Erlang shim that returns `{error, "not_yet_wired"}` until the operator explicitly enables it. Per SC-VAULT-007 KMS DR is LAST resort; per SC-VAULT-005 hot path MUST NOT make network calls.

## Workflow

1. Read `lib/cepaf_gleam/src/cepaf_gleam/vault_kms.gleam` for HttpRequest envelope shape (Pass-26)
2. Create `lib/cepaf_gleam/src/cepaf_gleam/vault_kms_io.gleam` with:
   - `pub fn execute(req: HttpRequest) -> Result(String, String)` — calls FFI to perform the POST, returns body or error
   - `@external(erlang, "vault_kms_io_ffi", "execute_request") fn ffi_execute(method: String, url: String, headers: List(#(String, String)), body: String) -> Result(String, String)`
   - Convenience: `pub fn decrypt(ref: KmsKeyRef, token: AdcToken, ciphertext_b64: String) -> Result(String, String)` — chains `build_decrypt_request → execute → parse_decrypt_response`
3. Create `lib/cepaf_gleam/src/vault_kms_io_ffi.erl`:
   - `-module(vault_kms_io_ffi).`
   - `-export([execute_request/4]).`
   - `execute_request(_M, _U, _H, _B) -> {error, <<"http_not_yet_wired">>}.` — plain Erlang module (NOT a NIF), returns truthful error
4. Create `lib/cepaf_gleam/test/vault_kms_io_test.gleam` with 5+ tests:
   - `decrypt_returns_http_not_yet_wired_until_ffi_lands` (lock-in trap pattern)
   - `decrypt_propagates_validate_key_ref_errors` (e.g. wrong region)
   - `decrypt_propagates_token_construction` (uses good_token without crashing)
   - `execute_returns_error_when_ffi_unwired`
   - 1+ realistic scenario test (e.g. attempts decrypt on a valid europe-north1 ref → gets "http_not_yet_wired" error tuple)
5. Run `cd lib/cepaf_gleam && gleam build && gleam test` — verify clean build + new tests pass
6. Report per supervisor template under 400 words

## Hard rules (Stub-That-Lies guard)

- DO NOT execute real HTTPS POST against GCP
- DO NOT add `httpc` config or trust store setup
- The Erlang shim MUST return the truthful `{error, "http_not_yet_wired"}` — never `{ok, fake_body}`
- The Gleam test suite MUST NOT crash when calling `decrypt(...)` — it should return the typed Error
- The `decrypt` chain MUST validate the KmsKeyRef BEFORE calling the FFI (fail-fast on wrong region etc.)

## Token-resolution helper (shared with Track D)

Track D will need the same ADC token-resolution. Create `lib/cepaf_gleam/src/cepaf_gleam/vault_adc_token.gleam` with:
- `pub fn fetch_metadata_server_token() -> Result(String, String)` — signature only; returns `Error("adc_not_yet_wired")` for now
- This module is shared between Track C (KMS) and Track D (GCP SM)
- 2 unit tests: signature compiles, error path returns expected token
