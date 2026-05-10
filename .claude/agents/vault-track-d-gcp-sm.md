---
name: vault-track-d-gcp-sm
description: Slice D worker — reqwest+ADC HTTP wrapper around Pass-28 GCP SM request builder (vault_gcp_sm.gleam). Wave-2 partner with vault-track-c-kms; both share the ADC token-resolution helper. Per [zk-3346fc607a1ef9e6] no Stub-That-Lies.
tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# Track D — GCP Secret Manager HTTP I/O wrapper (Wave 2)

## Mission

Pass-28 shipped the pure GCP Secret Manager request builders (`vault_gcp_sm.gleam` — list/access/addVersion). This track scaffolds the **HTTP execution layer** that consumes those envelopes and produces real HTTPS calls to `secretmanager.googleapis.com`.

Wave-2 scope: HTTP wrapper + reuse of Track C's `vault_adc_token.gleam` for token resolution. Erlang shim returns `{error, "http_not_yet_wired"}` until explicit enablement.

## Workflow

1. Read `lib/cepaf_gleam/src/cepaf_gleam/vault_gcp_sm.gleam` for SmRequest shape (Pass-28)
2. Wait for/coordinate with Track C's `vault_adc_token.gleam` — if it doesn't yet exist when you start, create it as a 1-function stub (signature only; Track C will populate). Do NOT duplicate.
3. Create `lib/cepaf_gleam/src/cepaf_gleam/vault_gcp_sm_io.gleam` with:
   - `pub fn execute(req: SmRequest) -> Result(String, String)` — calls FFI, returns body or error
   - `@external(erlang, "vault_gcp_sm_io_ffi", "execute_request") fn ffi_execute(method: String, url: String, headers: List(#(String, String)), body: String) -> Result(String, String)`
   - Convenience functions:
     - `pub fn list_secrets(project: String, page_size: Int, token: SmAdcToken) -> Result(String, String)` — chains build_list_request → execute
     - `pub fn access_secret(ref: SecretManagerRef, version: String, token: SmAdcToken) -> Result(String, String)` — chains build_access_request → execute → parse_access_response
     - `pub fn add_version(ref: SecretManagerRef, payload_b64: String, token: SmAdcToken) -> Result(String, String)` — chains build_add_version_request → execute → parse_add_version_response
4. Create `lib/cepaf_gleam/src/vault_gcp_sm_io_ffi.erl`:
   - `-module(vault_gcp_sm_io_ffi).`
   - `-export([execute_request/4]).`
   - `execute_request(_M, _U, _H, _B) -> {error, <<"http_not_yet_wired">>}.`
5. Create `lib/cepaf_gleam/test/vault_gcp_sm_io_test.gleam` with 6+ tests:
   - `list_secrets_returns_http_not_yet_wired_until_ffi_lands`
   - `access_secret_returns_http_not_yet_wired`
   - `add_version_returns_http_not_yet_wired`
   - `list_secrets_propagates_empty_project_error_before_ffi`
   - `access_secret_propagates_invalid_secret_id_before_ffi`
   - `add_version_propagates_invalid_secret_id_before_ffi`
6. Run `cd lib/cepaf_gleam && gleam build && gleam test` — clean build + tests pass
7. Report per supervisor template under 400 words

## Hard rules (Stub-That-Lies guard)

- DO NOT execute real HTTPS calls
- DO NOT add cargo deps (this is Gleam side; Track B owns Rust HTTP if any)
- All 3 convenience functions MUST validate input via Pass-28 builders BEFORE calling FFI (fail-fast)
- Test suite MUST verify the not-yet-wired error path — typed error, not crash
- DO NOT duplicate `vault_adc_token.gleam` — coordinate with Track C
