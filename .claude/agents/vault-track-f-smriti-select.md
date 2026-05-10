---
name: vault-track-f-smriti-select
description: Slice F worker — Smriti.db SELECT pure SQL query strings + Erlang FFI binding signatures for secret_policy actuals. NO execution this turn. Produces a Gleam module that prepares the queries; full execution lands when Slice B body is live. Per [zk-3346fc607a1ef9e6] no Stub-That-Lies.
tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# Track F — Smriti SELECT for actuals (Wave 1, parallel)

## Mission

Slice F audit reconcile (Pass-24) compares EXPECTED policies (from `vault.gleam` defaults) vs ACTUAL rows (from Smriti.db `secret_policy` table). The expected side is already pure (Pass-24); the actual side needs a Smriti.db SELECT wrapper.

This track produces:
1. The SQL query strings as constants
2. A pure-Gleam `parse_row` function that converts Erlang term tuples → `ActualPolicy`
3. The Erlang FFI binding signature (NOT yet executing the query)
4. Tests that the parse function handles canonical row shapes

## Workflow

1. Read `sub-projects/c3i/native/planning_daemon/src/db.rs` for the `secret_policy` table DDL (added Pass-6)
2. Read `lib/cepaf_gleam/src/cepaf_gleam/vault_audit_reconcile.gleam` for the `ActualPolicy` shape
3. Create `lib/cepaf_gleam/src/cepaf_gleam/vault_audit_reconcile_io.gleam`:
   - `pub const select_all_policies_sql = "SELECT name, ttl, max_ttl, sensitivity FROM secret_policy"`
   - `pub fn parse_row(row: #(String, Int, Int, String)) -> ActualPolicy { ... }` — pure
   - `pub fn parse_rows(rows: List(#(String, Int, Int, String))) -> List(ActualPolicy)` — pure
   - `@external(erlang, "vault_smriti_ffi", "select_actual_policies") fn ffi_select(_: String) -> Result(List(#(String, Int, Int, String)), String)` — signature only, no implementation
4. Create `lib/cepaf_gleam/src/vault_smriti_ffi.erl` Erlang stub that calls `erlang:nif_error(not_yet_wired)` for the FFI (mirrors Pass-22 Erlang shim pattern)
5. Add `lib/cepaf_gleam/test/vault_audit_reconcile_io_test.gleam` with 5+ tests on `parse_row` covering canonical + edge cases (empty name, zero ttl, non-canonical sensitivity)
6. Run `gleam build` + `gleam test` — both must be green
7. Report per supervisor template

## Hard rules

- DO NOT execute SQL against Smriti.db (no actual SELECT)
- DO NOT add `rusqlite` or any SQL execution dep
- The FFI signature is type-only; the Erlang shim raises `nif_error` (matches Pass-22 pattern)
- `parse_row` is REAL pure code — exhaustively tested
