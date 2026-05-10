# Pi-Mono Vault Integration (SC-VAULT-025)

**Status**: Operator-facing guide. Wave 9 deliverable (vault-track supervisor, 2026-05-01).
**ZK refs**: [zk-3346fc607a1ef9e6] Stub-That-Lies, [zk-7c757e50a894be8b] hardware-backed sovereignty, [zk-1fd0d2523508fa2b] (vault Wave 7-8 closure).
**STAMP**: SC-VAULT-001..025, SC-VAULT-CRYPTO-001, SC-AUTH-001..008.

## 1. Why

Per **SC-VAULT-025**: all `.pi/` secret reads MUST go through an OIDC-protected Wisp REST endpoint backed by the RustyVault NIF. Plaintext API keys in `.pi/config.json` are a SC-VAULT-004 violation.

The pre-commit hook (`/home/an/dev/ver/c3i/.git/hooks/pre-commit` chaining `.claude/scripts/vault-precommit-secret-scan.sh`) blocks new commits that add plaintext key shapes — it does **not** retroactively redact existing files. Existing plaintext in `.pi/config.json` (Wave 9 W1 inventory: `pi.anthropic.apiKey`) is a **pre-existing condition** awaiting operator-supervised migration.

## 2. Architecture

```
+------------------+       (1) HTTPS                +-------------------+
|  Pi process      |  GET /api/v1/secret/:name      |  Wisp router      |
|  (.pi/anthropic- | -----------------------------> |  secret_api.gleam |
|   client.ts)     |  Authorization: Bearer <token> |                   |
+------------------+                                  +---------+---------+
        ^                                                       |
        | (4) base64(value), expires_at                         | (2) constant-time
        |                                                       |     bearer check
        |                                                       v
        |                                              +-----------------+
        |                                              |  vault.get      |
        |                                              |  (NIF)          |
        |                                              +--------+--------+
        |                                                       |
        |                                              (3) decrypt AES-256-GCM,
        |                                                  audit envelope on
        |                                                  indrajaal/l0/secret/
        |                                                  access/<name>
        |                                                       |
        +-------------------------------------------------------+

Zenoh OTel audit subscriber (Wave 8) observes envelopes and persists to
vault_audit_log table for forensic replay (SC-VAULT-008 append-only).
```

## 3. Operator setup (one-time)

### 3.1 KEK ceremony

Vault is sealed at boot (SC-VAULT-001). Until the KEK chain is provisioned, **no migration is possible**.

```
# Option A — operator passphrase (interactive, recommended for first cut):
gleam run -m scripts/vault/unseal_with_passphrase
# Argon2id(memory=64MB, iterations=3, parallelism=4) per SC-VAULT-021.

# Option B — TPM PCR 7 (deferred; track A in vault track):
gleam run -m scripts/vault/unseal_with_tpm

# Option C — Cloud KMS (deferred; track C in vault track):
gleam run -m scripts/vault/unseal_with_kms --region europe-north1
```

The first ceremony seeds:
- `data/kms/vault.db` (encrypted KV store, sqlite WAL `synchronous=FULL` per SC-VAULT-012)
- `data/kms/vault.audit.log` (append-only, rotated at 100 MB per SC-VAULT-022)
- `secret_policy` table seed rows (TTL/MaxTTL/RotationDays per layer)

### 3.2 REST Bearer token

The Pi REST endpoint authenticates callers via Bearer token (constant-time SHA-256 compare).

```
# Generate token + store hashed env on the wisp host:
gleam run -m scripts/vault/issue_pi_session_token > ~/.config/c3i/pi_session.token
chmod 600 ~/.config/c3i/pi_session.token

# Set on the wisp host (do NOT commit):
export C3I_VAULT_BEARER_TOKEN_HASH=$(gleam run -m scripts/vault/hash_token < ~/.config/c3i/pi_session.token)
```

The Pi process loads the plaintext token from `~/.config/c3i/pi_session.token` at startup and presents it on every `/api/v1/secret/:name` request.

### 3.3 Migrate `.pi/config.json` plaintext key

```
# Dry-run (default) — verifies inventory + policy, NEVER reads the secret value:
cd sub-projects/scripts-gleam
gleam run -m scripts/vault/migrate_secrets

# Real migration (operator-gated double-confirm):
gleam run -m scripts/vault/migrate_secrets -- --apply --i-understand-this-writes-secrets
```

After successful migration, replace `.pi/config.json` plaintext value with the placeholder marker:

```json
{
  "anthropic": {
    "apiKey": "<vault://anthropic_api_key>"
  }
}
```

This passes the SC-VAULT-004 pre-commit guard (placeholder syntax is exempted).

## 4. Adding a new secret

```
gleam run -m scripts/vault/put -- <name> --policy <l0_hot|l3_oauth|l3_smtp|l7_gateway>
# Reads value via getpass-style prompt (no echo, no history).
# Calls vault.put + round-trips via vault.get + zeroizes the buffer.
```

Policy presets (defined in `lib/cepaf_gleam/src/cepaf_gleam/vault.gleam`):

| Preset | TTL | MaxTTL | Rotation | Use |
|---|---:|---:|---:|---|
| `policy_l0_hot_key()` | 300 s | 7 d | 30 d | Anthropic, OpenRouter, Claude |
| `policy_l3_oauth_refresh()` | 3600 s | 30 d | 90 d | Gemini, OAuth refresh tokens |
| `policy_l3_smtp()` | 3600 s | 30 d | 90 d | SMTP app passwords |
| `policy_l7_gateway()` | 86400 s | 90 d | 365 d | Telegram, GChat, WhatsApp |

## 5. Rotation

```
# Operator-gated (SC-VAULT-023):
gleam run -m scripts/vault/rotate -- <name>
```

Rotation policy is per-secret (`secret_policy.rotation_days`). Background actor (`vault_supervisor.gleam`, Wave 8) emits `SecretRotationDue` RETE-UL fact when `now - rotated_at >= rotation_days`.

**Status**: actor scaffolded in Wave 8; CLI `rotate` subcommand deferred to a follow-up pass.

## 6. Audit trail

Every `vault.get` and `vault.put` emits a Zenoh envelope on `indrajaal/l0/secret/access/<name>` (SC-VAULT-009).

```
# Live tail:
zenoh-cli sub 'indrajaal/l0/secret/access/**'

# Recent N entries from append-only log:
gleam run -m scripts/vault/audit_tail -- --count 50
```

The Wave 8 audit subscriber persists every envelope to `vault_audit_log` table (sqlite WAL, append-only). Daily reconciliation against Cloud Audit (SC-VAULT-016) cron lands in a follow-up pass.

## 7. Troubleshooting

| HTTP code | Reason | Action |
|---:|---|---|
| 200 | OK | — |
| 401 | Missing/invalid Bearer | Verify `~/.config/c3i/pi_session.token` is readable AND `C3I_VAULT_BEARER_TOKEN_HASH` env matches its SHA-256 |
| 404 | Unknown secret name | Run `gleam run -m scripts/vault/list` to verify; secret may not be migrated yet |
| 429 | Rate limit (100/sec/caller) | Cache the value in-process up to TTL; SDK should not poll the endpoint |
| 503 | Vault sealed | Run KEK ceremony (§3.1); vault is sealed at boot per SC-VAULT-001 |

## 8. Cross-references

- `.claude/rules/secrets-vault.md` — full SC-VAULT-* rule (25 STAMP + 1 CRYPTO + 15 AOR + 12 RETE-UL)
- `lib/cepaf_gleam/src/cepaf_gleam/vault.gleam` — typed wrapper (SC-VAULT-003)
- `lib/cepaf_gleam/native/rusty_vault_nif/src/lib.rs` — NIF entry points
- `docs/journal/task-116494073339521648/journal.md` — vault feature journal (Wave 1-9)
- `docs/journal/task-116494073339521648/wave9-secret-inventory.md` — current inventory (this pass)
- `docs/journal/task-116494073339521648/wave9-fractal-coverage-matrix.md` — caller audit (deferred this pass)
- `docs/journal/task-116494073339521648/wave9-fractal-criticality-matrix.md` — fractal RPN (deferred this pass)

## 9. Wave 9 status

| Item | Status | Reason if deferred |
|---|---|---|
| Inventory across 4 sources | DONE | wave9-secret-inventory.md |
| Pre-commit hook armed | DONE | already chained via `.claude/scripts/vault-precommit-secret-scan.sh` (Wave 7) |
| Operator integration doc | DONE | this file |
| Migration tool (`migrate_secrets.gleam`) | DEFERRED | requires `secret_policy` table + KEK ceremony first; honest stub-free build pending |
| Wisp REST endpoint (`secret_api.gleam`) | DEFERRED | requires OIDC/Bearer substrate provisioning + token issuance flow |
| `.pi/anthropic-client.ts` flip | DEFERRED | atomic with REST endpoint landing; flipping early breaks Pi process |
| System-wide caller audit matrix | DEFERRED | scan executed (zsh=0, smriti=0, .pi=1) but mechanical flips blocked on items above |
| Full L0-L7 fractal criticality matrix | DEFERRED | content overlaps with existing `fractal-criticality-matrix.md`; needs careful merge to avoid duplication |
| Allium spec extensions | DEFERRED | linked to fractal matrix work |

The deferred items are blocked on **operator-supervised KEK ceremony**, which is correctly out of scope for an autonomous supervisor turn (Stub-That-Lies guard would be violated by faking unseal).
