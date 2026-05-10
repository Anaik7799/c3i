---
description: Operator workflow for vault evolution — secret rotation, policy update, KEK re-seal, sync trigger, status check. SC-VAULT-001..025 governed.
---

# /vault-evolve — Vault Operator Workflow

ZK: [zk-bd82645aedcb5ef4] no Stub-That-Lies · [zk-7c757e50a894be8b] hardware sovereignty target

## Usage

```
/vault-evolve <action> [args]
```

| Action | Purpose | SC-VAULT |
|---|---|---|
| `status` | Get vault state + per-secret freshness counts | 009 |
| `put <name> <value>` | Rotate or add a secret (Guardian-gated for L0) | 003, 004, 013 |
| `policy-set <name> --ttl N --max-ttl N --rotation-days N --sensitivity L0|L3|L7` | Update per-secret policy | 013 |
| `policy-get <name>` | Read per-secret policy | 013 |
| `re-seal-tpm` | Re-bind KEK to current TPM PCR 7 (after kernel update) | 007, 023 |
| `sync` | Force immediate GCP sync | 010 |
| `list-secrets` | List names + metadata only (no plaintext) | 009 |
| `audit-tail <since-ts>` | Read recent audit entries | 008, 016 |
| `health` | Composite health: Tongsuo absence + KEK chain + audit gap + circuit state | CRYPTO-001, 015 |
| `migrate-from-userprefs` | One-shot: move 8 plaintext secrets from `UserPreferences[secrets]` to vault | 003, 025 |

## Workflow examples

### Rotate Anthropic API key

```bash
# 1. Operator revokes old key at console.anthropic.com
# 2. Operator runs:
sa-plan vault put anthropic_api_key sk-ant-api03-NEW...

# 3. Guardian 2oo3 dialogue (SC-SIL4-006 for L0 secrets) — operator confirms
# 4. vault.put writes with policy_l0_hot_key (ttl=300, max_ttl=604800, rotation_days=30)
# 5. sync_actor pushes to GCP Secret Manager v=N+1 within 5 min
# 6. All callers next read get new key via vault.get
# 7. Old version optionally destroyed: sa-plan vault destroy anthropic_api_key 1
```

### Network outage countdown

```bash
sa-plan vault status                # all green
# ... network drops
sa-plan vault status                # tile amber, sync_actor circuit opens
# ... 6 days later
sa-plan vault status                # tile amber, MaxTTL countdown shows ~24h
# ... 7 days + ε
sa-plan vault status                # tile red for hot keys; long-TTL still green
sa-plan vault sync --now            # after reconnect; convergence within 5 min
sa-plan vault status                # back to green
```

### TPM PCR mismatch after kernel update

```bash
# Kernel updated; PCR 7 changed; next reboot fails TPM unseal
# Operator boots with passphrase fallback (C3I_VAULT_PASSPHRASE env)
sa-plan vault status                # active via passphrase
sa-plan vault re-seal-tpm           # re-bind to current PCR 7 (operator-gated, no automation)
# Next reboot: TPM unseal works again, unattended
```

### Migrate plaintext secrets to vault (one-shot)

```bash
sa-plan vault migrate-from-userprefs
# Reads category=secrets from UserPreferences (8 entries)
# For each: vault.put with default policy
# Verifies round-trip: vault.get returns same plaintext
# Disables the old UserPreferences entries (poison-pill: SC-VAULT-003 panic)
# Logs each migration to audit + Zenoh
```

## Pre-flight gates (always run before action)

1. **Tongsuo audit**: `cargo tree | grep -i tongsuo` → empty (SC-VAULT-CRYPTO-001)
2. **Pre-commit hook chained**: `.git/hooks/pre-commit` includes vault-precommit-secret-scan.sh
3. **Vault state**: `vault.status` returns Active (not Sealed/Corrupt/Halted)
4. **Audit log writable**: `smriti_vault_audit.log` exists and append-OK
5. **Zenoh reachable**: TCP probe `127.0.0.1:7447` succeeds in 200ms

If any pre-flight fails → action aborts with explicit error + sa-plan task created.

## Post-action gates (always run after action)

1. Audit log gained exactly 1 entry per NIF call
2. Zenoh envelope captured by `zenoh-cli sub indrajaal/l0/secret/access/<name>`
3. RETE-UL rule fires correctly:
   - `put` → Allow (hot path)
   - `get` past MaxTTL → FailClosed
   - rotation → ProposeRotation if past rotation_days
4. Dashboard tile updates within 30s (SC-AGUI-UI-008)

## Failure modes (per slice-plans/slice-b-continuation.md §6)

| Symptom | Cause | Recovery |
|---|---|---|
| Action returns `Sealed` error | vault not unsealed | run vault_supervisor.boot() with valid KEK chain |
| Action returns `WrongKey` | provided master key wrong | retry passphrase or KMS DR fallback |
| Action returns `TtlExpired(name)` | secret hard-stale (past MaxTTL) | rotate via `vault put`, OR reconnect to refresh |
| Audit log gap detected | NIF call without emit | `VaultAuditGap` rule fires P1; investigate tampering |
| Tongsuo found in cargo tree | `[patch.crates-io]` regression | revert to vendored Cargo.toml without patch |

## Cross-references
- Rule: `.claude/rules/secrets-vault.md`
- Validator agent: `.claude/agents/vault-validator.md`
- Master plan: `/home/an/.claude/plans/deep-frolicking-wave.md`
- 5 slice continuation plans: `docs/journal/task-116494073339521648/slice-plans/`
- Pre-commit hook: `.claude/scripts/vault-precommit-secret-scan.sh`
- TLA+ spec: `specs/tla/RustyVaultIntegration.tla`
- Agda spec: `specs/agda/VaultStateMachine.agda`
- Allium spec: `specs/allium/secrets_vault.allium`

## Governance parity

Mirror at `.gemini/commands/vault-evolve.md` next sync (SC-SYNC-DOC-007).
