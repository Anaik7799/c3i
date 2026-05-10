# Track E — Pass-34 caller-flip delta diff (NOT YET APPLIED)

**Status**: research-only. The diff below is the **first safe caller flip**
identified per the Pass-32 delta doc analysis. **Source files are NOT edited
in Pass-34**; this document is the spec for a future single-file pass.

## Why mcp_gworkspace.rs first

Lowest blast radius:
1. Single function (`refresh_access_token`) reads 3 secret-shaped values:
   `google_oauth_refresh`, `google_client_id`, `google_client_secret`.
2. All 3 are read inside one fn body in a 5-line window (lines 26–43).
3. Caller is async-aware already (uses `reqwest::Client`), so the future
   `vault::get` async signature drops in cleanly.
4. SMTP/gdrive callers (lines 302, 305, 393) follow the SAME pattern, so
   getting this right unblocks 4 more flips with copy-paste.
5. No circular dep with `db::set_preference("google_oauth_refresh", ...)`
   on line 132 — that's the OAuth-refresh **write-back** path which the
   Slice E §5 plan flips to `vault::put` in a separate sub-task.

## Proposed diff (3-segment, ~9 lines net)

```diff
--- a/sub-projects/c3i/native/planning_daemon/src/mcp_gworkspace.rs
+++ b/sub-projects/c3i/native/planning_daemon/src/mcp_gworkspace.rs
@@ -23,18 +23,18 @@ async fn refresh_access_token(client: &reqwest::Client) -> Result<String, Ignit
         }
     }

-    let refresh_token = db::get_preference("google_oauth_refresh")
+    let refresh_token = vault::get("google_oauth_refresh").await
         .map_err(|e| IgnitionError::ConfigError(format!("Smriti read failed: {e}")))?
         .ok_or_else(|| IgnitionError::ConfigError(
             "No google_oauth_refresh in Smriti. Store it first.".into()
         ))?;

-    let client_id = db::get_preference("google_client_id")
+    let client_id = vault::get("google_client_id").await
         .ok().flatten()
         .or_else(|| std::env::var("GOOGLE_CLIENT_ID").ok())
         .unwrap_or_default();

-    let client_secret = db::get_preference("google_client_secret")
+    let client_secret = vault::get("google_client_secret").await
         .ok().flatten()
         .or_else(|| std::env::var("GOOGLE_CLIENT_SECRET").ok())
         .unwrap_or_default();
```

## Preconditions before applying

1. `vault::get(name) -> Result<Option<String>, VaultError>` (async) MUST exist
   in `planning_daemon::vault` — not yet implemented. Currently this would be
   the SECOND turn after `vault.gleam` Rust callable surface lands.
2. `vault.gleam` typed wrapper MUST be NIF-exported (Slice E sub-task).
3. The 3 secrets MUST be migrated from `UserPreferences` to `kv_entries`
   via the migration script (already drafted in `vault_migration.gleam`).

## Lock-in trap that will fire when this diff lands

The current STAMP rule SC-VAULT-003 says "all secret reads MUST go through
`vault.gleam` typed wrapper or `secret_provider::get` Rust trait". Once this
diff applies, `db::get_preference("google_oauth_refresh")` no longer
appears in this fn — but a CI grep gate (TODO: add as
`scripts/verify/vault_secret_callers.gleam`) will still find it at lines
132 (write), 302 (gmail), 305 (gmail), 393 (gdrive). Those are the next
4 flips.

## Estimated LOC reduction in the deferred ledger

- Removes ~3 LOC × 1 caller = 3 LOC from "E 5-module Rust caller flip" item
  in §38.9 of journal.md.
- Once all 5 callers (mcp_gworkspace.rs ×3 + ×2 in cortex/gateway) flip,
  the full ~76 LOC item closes.

## Honest deferred (NOT done this turn, by design)

- Source edit deferred per Wave-3 prompt instruction "produce a unified
  diff in delta-diff.md showing the exact 3-5 line change — but DO NOT
  apply yet (no source edits)".
- `vault::get` Rust callable not yet implemented (separate task).
- CI grep gate `scripts/verify/vault_secret_callers.gleam` not yet authored
  (separate task; would belong to Track E continuation).

— end of Track E delta-diff —
