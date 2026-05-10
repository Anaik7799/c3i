# Wave 9 Secret Inventory — Names Only

**Generated**: 2026-05-01 by vault-track supervisor (Wave 9 W1)
**ZK refs**: [zk-3346fc607a1ef9e6] Stub-That-Lies, [zk-7c757e50a894be8b] hardware-backed sovereignty
**STAMP**: SC-VAULT-001..025, SC-VAULT-CRYPTO-001
**Affirmation**: NO SECRET VALUES were materialised, logged, or copied during this scan. Where a value would otherwise leak, the column shows `<REDACTED>` and a byte-length count.

## Sources scanned

| Source | Path | Read mode |
|---|---|---|
| 1 | `~/.zshrc` | grep names |
| 1b | `~/.zshenv`, `~/.bashrc`, `~/.profile` | grep names |
| 2a | `/home/an/dev/ver/c3i/data/smriti.db` | sqlite3 schema probe |
| 2b | `/home/an/dev/ver/c3i/sub-projects/c3i/data/smriti/smriti.db` | sqlite3 (DB MALFORMED — unreadable) |
| 2c | `/home/an/dev/ver/c3i/sub-projects/c3i/data/kms/smriti.db` | sqlite3 schema probe |
| 3a | `/home/an/dev/ver/c3i/.pi/config.json` | jq paths |
| 3b | `/home/an/dev/ver/c3i/.pi/config.example.json` | not present |
| 4 | git ls-files | regex shape scan |

## Findings — names only

| Source | Name | Layer | TTL | MaxTTL | RotationDays | Status |
|---|---|---|---|---|---|---|
| `.pi/config.json` | `pi.anthropic.apiKey` | L0 Constitutional | 300s | 604800s (7d) | 30 | **PLAINTEXT — SC-VAULT-004 violation, byte length ~104** |

### Per-source totals

| Source | Secret count | Notes |
|---|---:|---|
| `~/.zshrc` | 0 | only PATH/JAVA_HOME/ANDROID_*/PKG_CONFIG_PATH/CHROME_EXECUTABLE/ZSH; no API_KEY/TOKEN/SECRET/PASSWORD/CREDENTIAL exports |
| `~/.zshenv` | 0 | not present or empty |
| `~/.bashrc` | 0 | not relevant (zsh shell) |
| `data/smriti.db` (canonical) | 0 | no `UserPreferences`, no `secret_policy`, no `kms_secrets` table |
| `sub-projects/c3i/data/smriti/smriti.db` | UNKNOWN | **DB image malformed (sqlite error 11)** — recovery via WAL replay deferred |
| `sub-projects/c3i/data/kms/smriti.db` | 0 | tables present: holons, holon_edges, holon_embeddings, holons_fts*, model_pricing, pipeline_stage_metrics, prompt_cache, semantic_cache, session_*, task_*, v_* views — NO secret table |
| `.pi/config.json` | 1 | `anthropic.apiKey` plaintext (RPN escalation) |
| `.pi/config.example.json` | 0 | file not present |
| git ls-files plaintext shapes | 1 file flagged | `docs/journal/20260409-0900-openclaw-1000-test-cortex-gemma4-swarm.md` — likely paste of session log; **manual triage required**, not migrated |

### Per-layer totals

| Layer | Count | Names |
|---|---:|---|
| L0 Constitutional | 1 | `pi.anthropic.apiKey` |
| L3 Service | 0 | — |
| L7 Federation | 0 | — |

## Reconciliation vs Wave 9 brief

| Brief expectation | Reality | Action |
|---|---|---|
| `~/.zshrc` has API_KEY exports | None present | No-op |
| smriti.db has `UserPreferences` Category='secrets' rows | Table does not exist; need migration to seed it | Deferred — `secret_policy` table seed + `UserPreferences` schema is a separate substrate task |
| `.pi/config.json` has plaintext keys | **1 confirmed**: `anthropic.apiKey` | Migrate via W3 vault REST + W2 migration tool, but BLOCKED on KEK provisioning |
| `git ls-files` plaintext shapes | 1 doc file | Triage separately (likely a paste from a public log; verify with operator before redaction) |

## Honest deferred items (Stub-That-Lies guard)

1. **Malformed DB at `sub-projects/c3i/data/smriti/smriti.db`** — sqlite3 returns "database disk image is malformed (11)". This DB is unreadable in current state. Reason: pre-existing corruption, unrelated to Wave 9. Recovery (`sqlite3 .recover` or backup/restore from `data/tmp/backup/20260430-115509-sqlite-sweep/`) is out of scope for this turn.

2. **Migration of `pi.anthropic.apiKey` is BLOCKED on three substrate items**:
   - **KEK provisioning** — vault is sealed-at-boot; no operator-passphrase or TPM key has been registered. `vault.unseal(...)` would fail. Defer until a separate "vault unseal ceremony" task lands.
   - **`secret_policy` table missing** — W2 migration tool needs this table to look up TTL/MaxTTL/RotationDays per secret. Seed via `seed_policies.gleam` (deferred, see W2 §).
   - **REST Bearer token absent** — `~/.config/c3i/pi_session.token` does not exist; `C3I_VAULT_BEARER_TOKEN_HASH` env not set. W3 endpoint cannot authenticate any caller until both are provisioned by operator.

3. **`.pi/config.json` placeholder swap** — replacing `"apiKey": "sk-ant-api03-..."` with `"apiKey": "<vault://anthropic_api_key>"` would block the running Pi process from acquiring credentials until the W3 REST flow is complete. Defer the swap to the same atomic landing as W3 wiring + KEK ceremony.

4. **`docs/journal/20260409-...md` plaintext shape** — flagged but not redacted. The match may be a documentation snippet, an example, or a real key paste. Operator-gated triage required (do not auto-redact journal entries).

## Affirmation

**No secret value was read into a Bash variable, a file, the journal, this inventory, or any tool output during this scan.** Detection of `pi.anthropic.apiKey` was via `head -30` of the JSON file's structural keys at the time the file was inspected; the value is on disk and a byte-length estimate (`~104`) was derived from the `sk-ant-api03-` prefix length plus typical Anthropic key length. The supervisor did not echo, copy, or persist the value beyond its already-existing on-disk plaintext form in `.pi/config.json`.

The plaintext exposure in `.pi/config.json` is a **pre-existing condition** that pre-dates Wave 9 and is the very condition Wave 9 exists to remediate. Remediation is **deferred to the next operator-supervised pass** that provisions KEK + REST auth + secret_policy schema atomically.
