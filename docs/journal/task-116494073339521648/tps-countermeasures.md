# Toyota Production System Countermeasures — Secrets Vault

**ZK**: [zk-25e3e7acb07262c9] TPS pattern · [zk-aeac27b117a70c4b] Jidoka anti-pattern (hard-fail on optional)

Per **SC-TPS-001..006** (existing) + the operator's "Setup Oban + Temporal + Slurm items so this class of issue cannot recur" directive, this document codifies the 7 TPS pillars applied to vault operations.

---

## 1. Jidoka — Stop the line on defect

**Pre-defect prevention** (5 mechanisms, each tracked):

| Mechanism | Tool | Trigger | Action | sa-plan |
|---|---|---|---|---|
| Pre-commit secret scan | git-secrets / regex | any commit | Refuse if `sk-ant-…`, `sk-or-…`, `AIza…`, `sk-proj-…` shape detected in staged content | 116494259712597823 |
| Cargo build crypto audit | `cargo tree | grep tongsuo` | every NIF build | Build fails if Tongsuo / SM2/3/4 in dep tree (SC-VAULT-CRYPTO-001) | embedded in Slice B CI |
| Wiring guard | `gleam test` `vault_wiring_test` | every test run | Fail if any caller uses `db::get_preference("secrets")` instead of `vault.get` | Slice F |
| Pre-deploy unseal probe | smoke test | container start | Fail if vault sealed > 30s after start (VaultSealedAtBoot rule) | Slice F |
| Pre-deploy plaintext probe | grep cron | nightly | Page operator if any committed file matches API-key regex | Slice F |

**Defect-detection-after** (3 mechanisms):

| Mechanism | Tool | Frequency | Detects | sa-plan |
|---|---|---|---|---|
| Cloud Audit reconciliation | sa-plan cron | daily 02:00 UTC | Out-of-band Secret Manager access (someone bypassed daemon) | 116494259714520936 |
| Vault audit log tail | `audit_log.rs` consumer | continuous | Audit gap > 5s after NIF call (VaultAuditGap rule) | Slice F |
| Smriti.db integrity check | sa-plan cron | hourly | `smriti_vault.db` corruption (VaultStorageCorrupt rule) | Slice F |

---

## 2. Andon — Signal board

**Cockpit dashboard tile** (per SC-AGUI-UI-008, 30-second refresh):

```
┌─ Secrets Vault Status ──────────────────────── 30s ago ─┐
│                                                          │
│  Vault state: ● ACTIVE (unsealed 14h ago via TPM)       │
│                                                          │
│  Per-secret freshness:                                   │
│    ● anthropic_api_key       fresh (3m ago)             │
│    ● openrouter_api_key      fresh (3m ago)             │
│    ● gemini_api_key          fresh (4m ago)             │
│    ● telegram_token          fresh (32m ago)            │
│    ● gmail_app_password      fresh (2h ago)             │
│    ● google_oauth_refresh    fresh (45m ago)            │
│    ● google_client_secret    fresh (8h ago)             │
│    ● gchat_webhook           fresh (6h ago)             │
│                                                          │
│  Last GCP sync: 2m 14s ago (success)                    │
│  Cloud Audit reconcile: 3h ago (in sync)                │
│                                                          │
│  Tongsuo absence: ✓ verified at last build              │
│  Plaintext on disk: ✓ none detected (last scan 12h ago) │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

**Andon escalation thresholds**:
- Green: all fresh, last sync < 10 min, no unseal failures
- Amber: any secret soft-stale, OR last sync > 10 min, OR online but circuit breaker open
- Red: any secret hard-stale, OR vault sealed > 30s after start, OR Tongsuo detected

Tracked: sa-plan 116494259716793828.

---

## 3. Kaizen — Continuous improvement

**Periodic improvement cycles** (5 cron jobs, all sa-plan-scheduled):

| Cycle | Frequency | Action | What improves |
|---|---|---|---|
| `vault_sync` | every 5 min | Pull latest from GCP Secret Manager | Freshness, cloud-truth alignment |
| `vault_audit_reconcile` | daily 02:00 UTC | Cross-check Cloud Audit vs RustyVault audit | Detect tampering |
| `vault_kek_rotation_check` | weekly Sun 03:00 UTC | Warn if KEK age > 90d | Key hygiene |
| `vault_policy_audit` | daily 04:00 UTC | Verify every secret has policy row, every policy has secret | Coverage drift |
| `vault_freshness_metrics` | every 30 s | Publish per-secret freshness to Zenoh | Andon dashboard |

Plus weekly TLA+ + Apalache model-check (per SC-CPIG-007) catching spec drift.

---

## 4. Heijunka — Load leveling (Slurm-style fairshare)

Per **SC-RCPSP-001..010** + new fairshare config:

```
Tier 1 (priority 1000): KEK ops — re-seal-tpm, KEK rotation
Tier 2 (priority  100): secret puts/gets (operator + caller traffic)
Tier 3 (priority   10): sync polls (every 5 min)
Tier 4 (priority    1): audit reconciliation (daily)

Quotas:
  max 2  concurrent KMS calls (avoid bursting GCP quota)
  max 10 concurrent Secret Manager calls
  max 20 concurrent vault.get calls (avoid lock contention on smriti_vault.db WAL)

Backpressure:
  if quota exhausted → queue with FIFO + per-tier priority
  if queue depth > 100 → emit Zenoh warning + amber dashboard
```

Implementation: existing `lib/cepaf_gleam/native/scripts_nif/src/fairshare.rs` ([zk-de13e287de7b9f74]) — add vault as a new fairshare domain. Tracked as part of Slice F.

---

## 5. Poka-yoke — Error proofing

**By construction prevention** (cannot make the mistake):

| Mistake | Poka-yoke |
|---|---|
| Adding new secret without policy row | Wiring guard test fails compile if `vault.put(name, _, _)` called for `name` not in `secret_policy` table |
| Caller bypasses vault | `db::get_preference` for category=`secrets` panics with `"use vault.get instead"` after Slice E migration |
| Plaintext API key in source | Pre-commit hook regex |
| Tongsuo crate in build | `cargo build` fails if dep tree contains tongsuo |
| Forgetting to seal on shutdown | `vault_supervisor` SIGTERM handler always seals; OTP supervision tree guarantees |
| Stale lease used | `lease_renew` called automatically when expiry - now < 60s (SecretLeaseExpiringSoon rule) |
| Secret committed in code review | grep guard in CI on PR diffs |

---

## 6. Genchi Genbutsu — Go and see (formal verification)

Instead of human attestation, **mechanical proof**:

| Property | Spec | Tool |
|---|---|---|
| `NoPlaintextAtRest` | TLA+ invariant | TLC + Apalache |
| `BootUnsealsKEK` | TLA+ invariant | TLC |
| `OfflineFreshness` | TLA+ liveness | TLC |
| `SyncConvergence` | TLA+ + version vector CRDT | TLC + Apalache |
| `Sealed → ¬PlaintextAccessible` | Agda type-level proof | Agda compile |
| `KekValid → vault.unseal succeeds` | Agda type-level proof | Agda compile |
| 12 RETE-UL rules sound w.r.t. spec | Allium + Agda | Allium tend |

Weekly cron (per SC-CPIG-007) re-runs all model checks.

---

## 7. Standardized work — One way to do each thing

After Slice F closes:

| Operation | The single way |
|---|---|
| Read a secret | `vault.get(name)` from Gleam, or `vault_provider.get` from Rust |
| Rotate a secret | `sa-plan vault put <name> <value>` (Guardian-gated for L0) |
| Set policy | `sa-plan vault policy-set <name> --ttl <s> --max-ttl <s>` |
| Read from `.pi/` | HTTPS GET `/api/v1/secret/<name>` (OIDC-gated) |
| Provisioning | `gleam run -m scripts/vault/provision` |
| Re-seal TPM after kernel update | `sa-plan vault re-seal-tpm` |
| Backup | (no operator action — automatic via existing `backup.rs`) |
| Restore | `sa-plan restore --target smriti_vault.db` |

Anything other than these 8 operations is a violation.

---

## Mapping to sa-plan tasks

| TPS pillar | sa-plan task | Closure criterion |
|---|---|---|
| Jidoka (pre-commit) | 116494259712597823 | Hook installed in `.git/hooks/pre-commit`; CI gate active |
| Andon (dashboard tile) | 116494259716793828 | `/secrets-vault` page renders 30s-refreshing tile |
| Kaizen (5 crons) | embedded in Slice F (116494259028115525) | All 5 cron entries in `oban_jobs` table |
| Heijunka (fairshare) | embedded in Slice F | `fairshare.rs` extended with vault domain |
| Poka-yoke (wiring guard) | embedded in Slice F | `vault_wiring_test.gleam` passing |
| Genchi Genbutsu (formal) | 116494259706964617 | TLA+ + Apalache + Agda specs in `specs/`; weekly cron green |
| Standardized work | embedded in Slice F doc pack | This file + skill + rule |

---

## Why the prior pattern failed

[zk-aeac27b117a70c4b] anti-pattern: "Hard-fail on optional service". Inverse here: SC-SEC-049 was *too* optional — it was advisory, not enforcing. The fix is to make the vault path **the only path** (Standardized Work) and the alternative paths fail at compile time (Poka-yoke). When the right thing is the only thing, the wrong thing becomes impossible.

The 7 pillars together are **defense in depth**: even if one fails (e.g., pre-commit hook bypassed via `--no-verify`), four other layers (CI gate, formal spec, RETE-UL rule, wiring guard) catch it.

---

**Closure**: this document becomes a sa-plan completion artifact when all 7 pillars are operational (estimated end of Slice F).
