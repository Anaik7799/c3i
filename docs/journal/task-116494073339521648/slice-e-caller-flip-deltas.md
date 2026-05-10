# Slice E Caller-Flip Delta Reference

**Status**: RESEARCH-ONLY. No source edits applied. Stub-That-Lies guard ([zk-3346fc607a1ef9e6], RPN 729) honored.
**Task**: `urn:c3i:task:misc:116494073339521648`
**Constraint family**: SC-VAULT-003 (all secret reads MUST go through `vault.gleam` typed wrapper or `secret_provider::get` Rust trait).
**Date**: 2026-05-01

## Summary table

| File | get_preference call sites | Vault-relevant calls | LOC delta estimate |
|---|---:|---:|---:|
| `mcp_inference.rs` | 8 | 8 (gemini_api_key×4, openrouter_api_key×2, openrouter_model×1, gemini_api_key_live×1) | +24 / −8 ≈ **+16** |
| `gateway.rs` | 11 | 11 (telegram_token×5, telegram_chat_id×4, gchat_webhook×2) | +33 / −11 ≈ **+22** |
| `mcp_gworkspace.rs` | 9 | 9 (google oauth/refresh/client_id/client_secret + gmail_username/password + gdrive_service_account_json + cached token rows + gchat_webhook fallback) | +27 / −9 ≈ **+18** |
| `cortex.rs` | 4 | 2 (671 voice_accent_profile is non-secret config; 1015 inference_cascade is non-secret; 1095 + 1815 are operator `/get <key>` and MCP `GetPreference` — these are **policy-gated passthrough**, not flip targets) | +6 / −2 ≈ **+4** |
| `audit_log.rs` | 0 | 0 | **0** |
| **TOTAL** | **32** | **30** | **≈ +60 LOC** |

Note: `cortex.rs` lines 1095 and 1815 are the `/get` Telegram command and the `GetPreference` MCP method. Both are **operator surfaces** that read by arbitrary key. They MUST NOT silently flip — instead, they MUST learn the secret-vs-config distinction at the same callsite (see "Special handling" below).

## Replacement template (Pass-27 vault_migration::decide pattern)

```rust
// BEFORE
let key = crate::db::get_preference("gemini_api_key").ok().flatten();

// AFTER (Slice E target — Rust-side vault::get with policy decision)
let key = match crate::vault::get_secret("gemini_api_key").await {
    Ok(plaintext) => Some(plaintext.expose_secret().to_string()),  // Zeroizing<Vec<u8>>
    Err(crate::vault::Error::HardStale) => {
        // SC-VAULT-006 fail-closed
        tracing::error!(target: "vault", "gemini_api_key hard-stale, refusing");
        None
    }
    Err(crate::vault::Error::NotFound) => {
        // Slice E migration window: legacy-with-guard
        match crate::vault_migration::decide("gemini_api_key") {
            Decision::UseLegacyWithGuard => crate::db::get_preference("gemini_api_key").ok().flatten(),
            Decision::TriggerMigration => { /* enqueue migration; return None */ None }
            Decision::RejectFailClosed => None,
            _ => None,
        }
    }
    Err(e) => { tracing::warn!(?e, "vault get failed"); None }
};
```

## Per-call table

### `sub-projects/c3i/native/planning_daemon/src/mcp_inference.rs`

| Line | Current (verbatim) | Replacement plan | Blocked by |
|---:|---|---|---|
| 302 | `let gemini_key = crate::db::get_preference("gemini_api_key").ok().flatten();` | `vault::get_secret("gemini_api_key").await` with HardStale fail-closed; flatten on NotFound via `vault_migration::decide` | Slice D (vault_migration), Slice C (vault.gleam Rust shim) |
| 310 | `let or_key = crate::db::get_preference("openrouter_api_key").ok().flatten();` | same pattern, name `openrouter_api_key` | Slice D |
| 346 | `let gemini_key = crate::db::get_preference("gemini_api_key").ok().flatten();` | same pattern (duplicate of L302) | Slice D |
| 347 | `let or_key = crate::db::get_preference("openrouter_api_key").ok().flatten();` | same pattern | Slice D |
| 578 | `let model: String = crate::db::get_preference("openrouter_model")` | **NOT a secret** — keep `db::get_preference`. Mark with comment `// non-secret config` | none |
| 623 | `let live_key = crate::db::get_preference("gemini_api_key_live").ok().flatten()` | vault path; preserve `.or_else` chain | Slice D |
| 624 | `.or_else(\|\| crate::db::get_preference("gemini_api_key").ok().flatten());` | second branch also flips | Slice D |
| 647 | `let gemini_key = crate::db::get_preference("gemini_api_key").ok().flatten();` | same pattern | Slice D |

**Effective vault flips: 7** (line 578 stays).

### `sub-projects/c3i/native/planning_daemon/src/gateway.rs`

| Line | Current | Replacement plan | Blocked by |
|---:|---|---|---|
| 29 | `let telegram_token = crate::db::get_preference("telegram_token").unwrap_or_default();` | `vault::get_secret("telegram_token").await.unwrap_or_default()` | Slice D |
| 30 | `let telegram_chat_id = crate::db::get_preference("telegram_chat_id").unwrap_or_default()` | **chat_id is identifier, not secret** — keep db::get_preference | none |
| 32 | `let gchat_webhook = crate::db::get_preference("gchat_webhook").unwrap_or_default()` | webhook URL is sensitive (contains token) — vault flip | Slice D |
| 58 | `let token = crate::db::get_preference("telegram_token").unwrap_or_default()?;` | vault flip; preserve `?` propagation via mapped error | Slice D |
| 59 | `let chat_id = crate::db::get_preference("telegram_chat_id").unwrap_or_default()` | keep | none |
| 92 | `let token = match crate::db::get_preference("telegram_token").unwrap_or_default() {` | vault flip in match scrutinee | Slice D |
| 95 | `let chat_id = crate::db::get_preference("telegram_chat_id").unwrap_or_default()` | keep | none |
| 126 | `let token = match crate::db::get_preference("telegram_token").unwrap_or_default() {` | vault flip | Slice D |
| 142 | `let telegram_token = crate::db::get_preference("telegram_token").unwrap_or_default();` | vault flip | Slice D |
| 143 | `let telegram_chat_id = crate::db::get_preference("telegram_chat_id").unwrap_or_default()` | keep | none |
| 145 | `let gchat_webhook = crate::db::get_preference("gchat_webhook").unwrap_or_default()` | vault flip | Slice D |

**Effective vault flips: 7** (chat_id ×4 stays).

### `sub-projects/c3i/native/planning_daemon/src/mcp_gworkspace.rs`

| Line | Current | Replacement plan | Blocked by |
|---:|---|---|---|
| 15 | `if let Ok(Some(cached)) = db::get_preference("google_access_token") {` | vault flip — access_token is bearer secret | Slice D |
| 16 | `if let Ok(Some(expires)) = db::get_preference("google_token_expires") {` | timestamp metadata — vault if co-located, else keep; **decision: vault** (lease-bound) | Slice D + lease metadata schema |
| 26 | `let refresh_token = db::get_preference("google_oauth_refresh")` | vault flip — long-lived secret | Slice D |
| 32 | `let client_id = db::get_preference("google_client_id")` | **NOT secret** (client_id is public OAuth identifier) — keep | none |
| 37 | `let client_secret = db::get_preference("google_client_secret")` | vault flip | Slice D |
| 187 | `.or_else(\|\| db::get_preference("gchat_webhook").ok().flatten());` | vault flip | Slice D |
| 302 | `let username = db::get_preference("gmail_username")` | **NOT secret** (email address) — keep | none |
| 305 | `let password = db::get_preference("gmail_app_password")` | vault flip — app password | Slice D |
| 393 | `let sa_json = db::get_preference("gdrive_service_account_json")` | vault flip — full SA key blob | Slice D |

**Effective vault flips: 7** (client_id, username stay).

### `sub-projects/c3i/native/planning_daemon/src/cortex.rs`

| Line | Current | Replacement plan | Blocked by |
|---:|---|---|---|
| 671 | `let accent_ctx = db::get_preference("voice_accent_profile")` | **NOT secret** — keep | none |
| 1015 | `let cascade = db::get_preference("inference_cascade").ok()...` | **NOT secret** — keep | none |
| 1095 | `match db::get_preference(key) { ... }` (operator `/get <key>` Telegram cmd) | **POLICY GATE**: lookup `secret_policy` table; if `is_secret` → reject with `"⛔ secret values are not exposed via /get"`; else → keep db::get_preference | Slice F (secret_policy table population), Slice D |
| 1815 | `db::get_preference(key).map(...)` (MCP `GetPreference` method) | same policy gate as 1095; reject secrets at MCP boundary (SC-VAULT-003) | Slice F + Slice D |

**Effective vault flips: 0; policy-gate insertions: 2.**

### `sub-projects/c3i/native/planning_daemon/src/audit_log.rs`

No `get_preference` calls. No flips needed. (Audit log is append-only and writes its own rows; it never reads operator-set preferences.)

## Order of application (sequenced)

1. **mcp_gworkspace.rs** (highest stakes — Google OAuth refresh tokens + SA JSON + Gmail app password). 7 flips. Smallest blast radius (one feature). Provides early integration test surface for vault::get.
2. **mcp_inference.rs** (LLM API keys — high frequency, hot path). 7 flips. Validates SC-VAULT-005 (no network on hot path) under the worst load.
3. **gateway.rs** (Telegram + Google Chat tokens). 7 flips. Verifies multi-callsite-per-function pattern (3 functions × ~3 callsites each).
4. **cortex.rs** policy gates (lines 1095, 1815). 2 inserts. **MUST come last** — depends on `secret_policy` table being fully populated (Slice F) so the gate has authoritative data to reject on.
5. (audit_log.rs — no work.)

Rationale for order: smallest scope first builds the vault::get migration shim with minimal regression risk; cortex.rs operator surface comes last because it requires every secret name to already be classified in `secret_policy` to avoid leaking via `/get`.

## Total LOC delta estimate

| Component | LOC added | LOC removed | Net |
|---|---:|---:|---:|
| Vault flips (28 sites × ~3 LOC) | ~84 | ~28 | **+56** |
| Policy gates (2 sites × ~6 LOC) | ~12 | 0 | **+12** |
| Imports (`use crate::vault;`, `use crate::vault_migration::Decision;` × 4 files) | ~8 | 0 | **+8** |
| **Total** | **~104** | **~28** | **≈ +76 LOC** |

(Earlier table summary said +60; refined estimate after per-call analysis is +76.)

## Special handling — operator surfaces (cortex.rs:1095 + 1815)

Both `/get <key>` (Telegram) and `GetPreference` (MCP) are **arbitrary-key read** surfaces. A naive flip to `vault::get` would either (a) silently return None for non-secret keys, breaking the operator command, or (b) bypass SC-VAULT-003 if it falls back to `db::get_preference` unconditionally.

**Required pattern**:

```rust
match db::get_secret_policy_class(key)? {
    Class::Secret => { /* refuse; log to audit; return policy-violation message */ }
    Class::Config => db::get_preference(key)  // unchanged
    Class::Unknown => { /* refuse with "key not registered in secret_policy"; SC-VAULT-013 */ }
}
```

This requires the `secret_policy` table (Slice F) to be authoritative over every key the operator may type. Slice E MUST NOT land cortex.rs flips until Slice F is merged.

## Cross-references

- `.claude/rules/secrets-vault.md` — SC-VAULT-001..025
- `lib/cepaf_gleam/src/cepaf_gleam/vault_migration.gleam` (Slice D) — `Decision` ADT
- `lib/cepaf_gleam/src/cepaf_gleam/vault.gleam` (Slice C) — typed wrapper
- ZK [zk-3346fc607a1ef9e6] — Stub-That-Lies anti-pattern (RPN 729)
- ZK [zk-bc979ad6f068038e] — original migration plan
