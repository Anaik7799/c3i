# Secrets Vault Protocol (SC-VAULT-001..025 + SC-VAULT-CRYPTO-001)

## Mandate

**All production secrets MUST live in the RustyVault NIF inside `lib/cepaf_gleam/`. All secret reads MUST go through `vault.gleam` typed wrapper. Plaintext API-key shapes MUST NOT appear in any committed file. Western cryptography only — no Tongsuo / SM2/SM3/SM4.**

ZK lineage: [zk-bc979ad6f068038e] migration plan · [zk-1eed80e0ca21da5f] inventory · [zk-eb058172ddabbc59] file-mount pattern · [zk-7c757e50a894be8b] hardware-backed sovereignty · [zk-bd82645aedcb5ef4] Stub-That-Lies · [zk-de13e287de7b9f74] hsm_vault.gleam reuse · [zk-92800ef179f24206] KMS L0 + version vectors · [zk-c1e9c949422ed9e7] secrets RCA precedent.

---

## STAMP constraints

### CRITICAL — INFINITE severity
| ID | Constraint |
|----|-----------|
| SC-VAULT-001 | Vault MUST be sealed at process start; explicit unseal required |
| SC-VAULT-002 | KEK MUST never be persisted in plaintext anywhere on disk |
| SC-VAULT-003 | All secret reads MUST go through `vault.gleam` typed wrapper or `secret_provider::get` Rust trait |
| SC-VAULT-004 | Plaintext API-key shapes MUST NOT appear in any committed file (`sk-ant-`, `sk-or-`, `AIza`, `sk-proj-`, etc.) |
| SC-VAULT-005 | Hot path (secret read) MUST NOT make network calls |
| SC-VAULT-006 | Hard-stale secret (now - fetched_at >= max_ttl) MUST fail-closed |
| SC-VAULT-CRYPTO-001 | NO `tongsuo` / SM2/SM3/SM4 in dependency tree of any vault-adjacent crate |

### CRITICAL severity
| ID | Constraint |
|----|-----------|
| SC-VAULT-007 | Boot KEK chain MUST attempt {TPM PCR 7, operator passphrase, Cloud KMS} in that order |
| SC-VAULT-008 | Vault audit log MUST be append-only (no UPDATE/DELETE) |
| SC-VAULT-009 | Every NIF call MUST emit Zenoh envelope on `indrajaal/l0/secret/access/<name>` |
| SC-VAULT-010 | Sync actor MUST circuit-break (3 fail / 60s cooldown) |
| SC-VAULT-011 | Conflict resolution MUST use monotonic version vector |
| SC-VAULT-012 | Storage backend MUST use SQLite WAL with `synchronous=FULL` |

### HIGH severity
| ID | Constraint |
|----|-----------|
| SC-VAULT-013 | Secret policy MUST be in `secret_policy` table; no hard-coded TTLs in callers |
| SC-VAULT-014 | Lease renewal MUST occur ≥ 60 s before expiry |
| SC-VAULT-015 | All KEK unseal events MUST be logged to immutable register |
| SC-VAULT-016 | Daily Cloud Audit reconciliation cron MUST run |
| SC-VAULT-017 | GCP region MUST be `europe-north1` (GDPR EU residency) |
| SC-VAULT-018 | IAM SA MUST have minimum 3 roles (`secretmanager.secretAccessor`, `secretmanager.secretVersionAdder`, `cloudkms.cryptoKeyEncrypterDecrypter`) |
| SC-VAULT-019 | CMEK keyring for Secret Manager MUST be different from KEK DR keyring |
| SC-VAULT-020 | `vault_supervisor.gleam` MUST be supervised by root supervisor with `one_for_all` strategy |

### MEDIUM severity
| ID | Constraint |
|----|-----------|
| SC-VAULT-021 | Operator passphrase MUST use argon2id(memory=64MB, iterations=3, parallelism=4) |
| SC-VAULT-022 | Vault audit log MUST be rotated at 100 MB |
| SC-VAULT-023 | `re-seal-tpm` CLI MUST be operator-gated (no automation) |
| SC-VAULT-024 | Provisioning script MUST be Gleam-only (per SC-SCRIPT-GLEAM-001) |
| SC-VAULT-025 | All `.pi/` secret reads MUST be via Wisp REST endpoint, never read from JSON |

---

## AOR rules

| ID | Rule |
|----|------|
| AOR-VAULT-001 | NEVER add `[patch.crates-io]` redirecting `openssl`/`openssl-sys` anywhere in the workspace |
| AOR-VAULT-002 | ALWAYS run `cargo tree | grep -iE 'tongsuo|sm[234]'` and verify empty before merging vault-related code |
| AOR-VAULT-003 | NEVER call `db::get_preference("secrets", _)` after Slice E migration — use `vault.get` |
| AOR-VAULT-004 | NEVER write secret values into JSON / TOML / YAML config files |
| AOR-VAULT-005 | ALWAYS update `secret_policy` table when introducing a new secret name |
| AOR-VAULT-006 | ALWAYS use `Zeroizing<Vec<u8>>` for plaintext bytes in Rust callers |
| AOR-VAULT-007 | NEVER log a secret value (PII scrubber must redact) |
| AOR-VAULT-008 | ALWAYS gate `.pi/` config reads through OIDC-protected Wisp endpoint |
| AOR-VAULT-009 | ALWAYS run pre-commit secret-scan hook before push |
| AOR-VAULT-010 | NEVER bypass Guardian gate for L0-sensitivity rotation (SC-SIL4-006) |
| AOR-VAULT-011 | ALWAYS preserve audit-log append-only; rotation goes through audit-rotate cron |
| AOR-VAULT-012 | ALWAYS verify GCS backup of `data/kms/` is current before vault state-changing operations |
| AOR-VAULT-013 | NEVER compile NIF with `crypto_adaptor_tongsuo` feature flag |
| AOR-VAULT-014 | ALWAYS test new RETE-UL rules with both online and offline path coverage |
| AOR-VAULT-015 | NEVER skip `vault_unseal` on boot — sealed vault is the safe default |

---

## RETE-UL rules (12 in 2 domains)

Domain `secret_freshness` (7):

| Rule | Salience | When | Then |
|---|---:|---|---|
| `SecretFresh` | 100 | `now - fetched_at < ttl` | hot path, no action |
| `SecretSoftStale` | 95 | `ttl ≤ age < max_ttl` ∧ online | trigger background sync |
| `SecretSoftStaleOffline` | 90 | `ttl ≤ age < max_ttl` ∧ offline | degraded mode, dashboard amber |
| `SecretHardStale` | 100 | `age ≥ max_ttl` | FAIL-CLOSED, P0 alarm |
| `SecretRotationDue` | 80 | `now - rotated_at ≥ rotation_days` | propose P1 rotation task |
| `SecretLeaseExpiringSoon` | 75 | `lease.expiry - now < 60s` | renew via NIF |
| `SecretBootUnsealFailed` | 100 | unseal returned err | P0 alarm; halt agent loops |

Domain `vault_integrity` (5):

| Rule | Salience | When | Then |
|---|---:|---|---|
| `VaultSealedAtBoot` | 100 | uptime > 30s ∧ sealed | P0 alarm |
| `VaultUnsealAttemptFailed` | 100 | TPM ∧ passphrase ∧ KMS all failed | P0; halt all OODA |
| `VaultStorageCorrupt` | 100 | sqlite integrity_check fails | seal vault; switch to GCS snapshot |
| `VaultAuditGap` | 90 | audit gap > 5s after NIF call | P1 investigate |
| `VaultTongsuoLinked` | 100 | cargo tree finds tongsuo | block release pipeline |

These join the existing 52 GRL rules → total **64 rules across 14 domains**.

---

## Pre-commit gate

Implementation: `.git/hooks/pre-commit` (added via Slice F, tracked sa-plan 116494259712597823)

```bash
#!/usr/bin/env bash
# SC-VAULT-004 enforcement
violations=$(git diff --cached -U0 | grep -E '^\+.*(sk-ant-api03|sk-or-v1|sk-proj-|AIza[A-Za-z0-9_-]{20,})' | grep -v 'placeholder\|example')
if [ -n "$violations" ]; then
  echo "[SC-VAULT-004 VIOLATION] plaintext API key detected in staged content:"
  echo "$violations"
  echo ""
  echo "Use 'sa-plan vault put <name> <value>' instead."
  exit 1
fi
```

---

## CI gate (Slice B closure)

```bash
cd lib/cepaf_gleam/native/rusty_vault_nif && cargo tree | grep -iE 'tongsuo|sm[234]' && exit 1
# Empty grep → exit 0 → proceed
```

---

## Pass-1+2+3 Extensions (2026-05-02 / 2026-05-03)

### SC-VAULT-026..029 (added Pass-2)
| ID | Severity | Purpose |
|---|---|---|
| SC-VAULT-026 | HIGH | `sa-plan-daemon vault {list,status,get,locate,put,migrate-from-prefs,env}` MUST be the operator surface for vault administration |
| SC-VAULT-027 | HIGH | Rust-side writer (`Vault::put` in `vault.rs`) MUST produce envelopes interop-compatible with the Gleam-NIF writer (same KEK file, same AES-256-GCM wire format) |
| SC-VAULT-028 | INFINITE | MCP `vault_get` MUST NOT be exposed to AI agents (read-only diagnostic tools `vault_list/status/locate` are safe) |
| SC-VAULT-029 | HIGH | Production `read_secret()` paths MUST emit `warn!`/`Logger.warning` line `[SC-VAULT-029]` when smriti.db preference fallback resolves a value (silent prod fallback antipattern from Pass-1 [zk-bf7c653fcf86e6ca]) |

### Operator surface (Pass-1)
- `sa-plan-daemon vault {list,status,get,locate,put,migrate-from-prefs,env}` — 7 subcommands

### Elixir surface (Pass-2)
- `Indrajaal.Secrets.{get/1, get!/2, invalidate/1}` — vault → app config → env-var resolution chain with 60s `:persistent_term` cache; 17 production call sites retrofitted across 11 modules

### MCP surface (Pass-3)
- `vault_list` / `vault_status` / `vault_locate` — JSON-RPC dispatch in `cortex.rs` ~line 1840; `vault_get` deliberately excluded per SC-VAULT-028

### Gleam surface (Pass-3 Slice B)
- `vault.put(handle, name, value, policy) -> Result(VersionInfo, VaultError)` — NIF-wired via `:rusty_vault_safe.vault_kv_put/5`

### KEK provisioning
- Sidecar file at `~/.config/c3i/vault.kek` (32 raw bytes, mode 0600); sourceable loader at `~/.config/c3i/vault.env`. Production: TPM PCR-7 unseal per SC-VAULT-007 (deferred Pass-4 hardware-gated).

## Cross-references
- `.claude/rules/constraint-registry.md` — register `SC-VAULT 001-029 (29)` under P0-SAFETY family
- `.claude/rules/wiring-guard.md` (SC-WIRE-001..007) — sibling for type-domain
- `.claude/rules/value-guard.md` (SC-VALUE-GUARD-001..008) — sibling for value-domain
- `.claude/rules/page-spec-checker.md` (SC-PAGE-SPEC-001..008) — sibling for spec conformance
- `lib/cepaf_gleam/src/cepaf_gleam/ha/hsm_vault.gleam` — reuse rotation policy logic
- `sub-projects/rusty_vault_vendored/VENDORING_NOTES.md` — vendoring audit trail
- `specs/tla/RustyVaultIntegration.tla` — TLA+ spec (Slice F)
- `specs/agda/VaultStateMachine.agda` — Agda type-level proofs (Slice F)
- `specs/allium/secrets_vault.allium` — Allium behavioral spec (Slice F)
- `docs/journal/task-116494073339521648/` — full doc pack

## Governance parity
Mirror at `.gemini/rules/secrets-vault.md` per SC-SYNC-DOC-007.
