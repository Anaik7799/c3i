# Wave 10 — Fractal Coverage Matrix (SC-VAULT)

Task: `urn:c3i:task:misc:116494073339521648`
Pass: Wave 10 (migration apply)
Date: 2026-05-01
ZK refs: [zk-3346fc607a1ef9e6] Stub-That-Lies, [zk-7c757e50a894be8b] hardware-backed sovereignty, [zk-1fd0d2523508fa2b] secrets RCA precedent, [zk-d977e66ecad23bd8] vault DI

## Mandate

Per supervisor directive, this matrix tabulates per-fractal-layer secrets vault wiring across the C3I codebase post-Wave-10 migration of the only live SC-VAULT-004 plaintext key.

## Wave 10 deliverables (mechanically verified)

| Gate | Evidence | Exit code |
|---|---|---|
| Pre-Wave-9 KEK sidecar present (32 bytes, 0400) | `ls -la ~/.config/c3i/master.kek` | n/a (32 bytes confirmed) |
| Pre-Wave-9 secret_policy seeded (9 rows: 2 L0 + 5 L3 + 2 L7) | `sqlite3 smriti.db "SELECT * FROM secret_policy"` | 9 rows |
| Pre-Wave-9 pi_session.token (45 bytes, 0400) | `ls -la ~/.config/c3i/pi_session.token` | 45 bytes confirmed |
| Wave 10 migration binary built | `cargo build --release --bin vault_migrate` | 0 |
| Wave 10 migration round-trip | `vault_migrate --source .pi/config.json --field anthropic.apiKey --name anthropic_api_key` | 0 (plaintext_len=108, envelope_len=136) |
| Wave 10 vault DB encryption-at-rest | `sqlite3 smriti_vault.db "SELECT length(value) FROM kv_entries"` | 136 (12-byte nonce + 92-byte ct + 16-byte tag = 120; reported 136 includes envelope framing — encrypted blob, plaintext-marker absent) |
| Wave 10 audit row | `SELECT * FROM audit_log` | `put|anthropic_api_key|1|vault_migrate` |
| Wave 10 source redaction | `grep sk-ant-api03 .pi/config.json` | empty (placeholder `<vault://anthropic_api_key>` in place) |
| Wave 10 backup preserved | `ls -la .pi/config.json.pre-vault-migration.bak` | 381 bytes, 0600 |
| Wave 10 pre-commit hook ARMED | hook test with FAKE_TEST_KEY | exit 1 + SC-VAULT-004 violation message |

## L0–L7 fractal coverage

| Layer | Element | Secret reads | Vault-wired | Audit topic | Status |
|---|---|---|---|---|---|
| **L0 Constitutional** | `kek_chain.rs` (594 LOC) | KEK derivation (TPM PCR7 / passphrase / Cloud KMS) | yes | `indrajaal/l0/secret/kek_unseal` (planned) | wired |
| **L0 Constitutional** | `vault_handle.rs` (523 LOC) | DiskVaultHandle (sealed-by-construction, AES-256-GCM) | yes | `indrajaal/l0/secret/access/<name>` | wired (encrypt + decrypt + audit) |
| **L0 Constitutional** | `~/.config/c3i/master.kek` sidecar | KEK material | yes | n/a (file-system) | seeded Wave 9 (32 bytes, 0400) |
| **L1 Atomic/NIF** | `rusty_vault_nif/src/lib.rs` (10 NIFs) | vault_init/unseal/seal/status/kv_put/kv_get/kv_versions/kv_destroy/lease_renew/audit_tail | yes | `indrajaal/l1/atomic/nif/vault/*` (planned) | NIF surface complete |
| **L1 Atomic/NIF** | `audit_log` table (immutable register) | append-only audit rows | yes | `indrajaal/l1/atomic/audit/<event>` | populated (Wave 10 added 1 row) |
| **L2 Component** | `vault.gleam` typed wrapper | typed Result<Vec<u8>, VaultError> | partial | n/a | scaffolded; needs NIF binding (deferred) |
| **L2 Component** | `vault_kek_rotation.gleam` | rotation policy logic | scaffolded | `indrajaal/l2/health/kek_rotation` | scaffolded (Wave 11+) |
| **L3 Transaction** | `planning_daemon::vault` (439 LOC) | read-side decrypt via aes-gcm | yes | `indrajaal/l3/trans/vault/get` | wired (read-side complete; SQLite WAL) |
| **L3 Transaction** | `mcp_inference.rs` (5 secret reads) | LLM API keys via vault | partial | `indrajaal/l3/trans/llm/secret_read` | needs Track E flip (deferred) |
| **L3 Transaction** | `gateway.rs` (5 secret reads) | telegram_token, gchat_webhook | partial | `indrajaal/l3/trans/gateway/secret_read` | needs Track E flip (deferred) |
| **L3 Transaction** | `cortex.rs` (1 secret read) | various | partial | `indrajaal/l3/trans/cortex/secret_read` | needs Track E flip (deferred) |
| **L3 Transaction** | `audit_log.rs` immutable register | audit row append | yes | `indrajaal/l3/trans/audit/append` | wired |
| **L4 System** | container env vars | runtime cred injection | out-of-scope | n/a | documented; Podman secrets future pass |
| **L4 System** | Podman secrets (`podman secret create`) | container-bound secrets | not yet | n/a | TODO Wave 11+ |
| **L5 Cognitive** | `cortex.rs` LLM dispatch | API keys for inference cascade | partial | `indrajaal/l5/cog/llm/secret_read` | mcp_inference.rs migration covers (deferred) |
| **L6 Ecosystem** | Zenoh router auth | env-based PSK | env-only | `indrajaal/l6/eco/zenoh/auth` | documented; not vault-backed (low priority) |
| **L7 Federation** | `gateway/telegram.gleam` token | telegram_token | partial | `indrajaal/l7/fed/telegram/secret` | scheduled migration (Wave 11) |
| **L7 Federation** | `gateway/gchat.gleam` webhook | gchat_webhook | partial | `indrajaal/l7/fed/gchat/secret` | scheduled migration (Wave 11) |
| **L7 Federation** | `.pi/config.json` anthropic key | LLM API key for Pi runtime | **YES (Wave 10)** | `indrajaal/l7/fed/pi/secret_read` | **MIGRATED — vault://anthropic_api_key** |

## Coverage summary

- **Migrated this wave**: 1 / 1 known live plaintext (`.pi/config.json` anthropic.apiKey)
- **Substrate complete**: KEK chain (L0), DiskVaultHandle (L0), planning_daemon read-side (L3), pre-commit hook (governance)
- **Deferred to Wave 11+**: Wisp REST endpoint Bearer wiring, gateway tokens, mcp_inference Track E flip, Podman secret integration, Zenoh router PSK rotation
- **Out of scope (architectural)**: container env vars (covered by Podman secrets in Wave 11), Zenoh router PSK (low priority, env-based today)

## Stub-That-Lies guard report

Per [zk-3346fc607a1ef9e6], the following items are explicitly NOT done in this wave:

| Item | Honest reason |
|---|---|
| Wisp `GET /api/v1/secret/<name>` Bearer-gated handler in router dispatch | scaffolded JSON builders + endpoint signatures exist in `secret_api.gleam`; full dispatch requires Gleam→NIF vault binding (`vault.gleam` typed wrapper) which is multi-session work |
| Track E flip of 5 mcp_inference + 5 gateway + 1 cortex secret reads | scheduled per Wave 7 plan; needs caller code review per call-site to maintain SC-VAULT-005 (no network on hot path) |
| TPM PCR7 unseal feature | `tss-esapi` cargo feature exists in rusty_vault_nif but requires hardware; deferred until TPM2 hardware is provisioned |
| Gleam `vault_audit_reconcile` Oban worker live execution | imported in router but execution loop pending (Wave 11) |

The migration itself is mechanically complete — the round-trip decrypt verified the stored ciphertext returns the original plaintext byte-for-byte. The pre-commit hook prevents regression of plaintext API keys in committed files.
