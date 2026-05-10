---
name: vault-track-e-caller-flip
description: Slice E worker — research-only audit of the 5 Rust planning_daemon callers that must flip from db::get_preference to vault.get. Produces a delta-diff document with exact line numbers per caller. NO source edits this turn (caller flip needs Slice B body live first). Per [zk-3346fc607a1ef9e6] no Stub-That-Lies.
tools: [Read, Grep, Glob, Bash, Write]
---

# Track E — 5-module Rust caller flip (research mode)

## Mission (Wave 1, parallel — RESEARCH ONLY)

Slice E flips 5 Rust callers from `db::get_preference("secrets", _)` to `vault.get(...)`. The flip CANNOT happen until Slice B body persistence is live (Track B Wave 1 + later session). This track produces a **delta diff document** with exact line numbers for each caller, ready for the operator to apply when Slice B closes.

## The 5 callers

```
sub-projects/c3i/native/planning_daemon/src/mcp_inference.rs
sub-projects/c3i/native/planning_daemon/src/gateway.rs
sub-projects/c3i/native/planning_daemon/src/mcp_gworkspace.rs
sub-projects/c3i/native/planning_daemon/src/cortex.rs
sub-projects/c3i/native/planning_daemon/src/audit_log.rs
```

## Workflow

1. For each caller: `grep -n 'get_preference' <file>` and capture line numbers + surrounding context
2. For each found match, draft the replacement using the Pass-27 `vault_migration::decide` decision matrix:

   ```rust
   // BEFORE:
   let key = db::get_preference("secrets", "anthropic_api_key")?;

   // AFTER:
   let action = vault_migration::decide("anthropic_api_key", vault_active, in_vault, in_legacy, in_pi, allow_legacy);
   let key = match action {
       UseVault => vault::get("anthropic_api_key")?,
       UseLegacyWithGuard(_) => db::get_preference("secrets", "anthropic_api_key")?,
       TriggerMigration(_) => migrate_then_get("anthropic_api_key")?,
       RejectFailClosed(reason) => return Err(VaultError::Sealed(reason)),
   };
   ```

3. Write the delta-diff document to `docs/journal/task-116494073339521648/slice-e-caller-flip-deltas.md`
4. Include a per-caller table: file, line, current code, replacement code, blocking dependency (Slice B body)
5. Report per supervisor template — emphasize NOTHING was applied

## Hard rules

- DO NOT edit any `.rs` source file in `planning_daemon/src/`
- DO NOT change `db::get_preference` signatures
- The output is a delta-diff REFERENCE document, not applied code
- Pass-21 lock-in tests in `vault_supervisor_test.gleam` will fire when the flip lands; do NOT pre-emptively touch them
