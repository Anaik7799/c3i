# Phase 6 — Chaos / adversarial scenarios (8 scenarios)

Per existing **SC-CHAOS-001..005** + **SC-IMMUNE** (Mara agent precedent).

| # | Scenario | Action | Expected | Detection |
|---|---|---|---|---|
| 1 | BEAM kill mid-put | `kill -9 $beam_pid` while `vault.put` in flight | next boot: WAL recovers; partial put either committed or absent (atomic) | sqlite integrity_check; audit log gap < 5s after recovery |
| 2 | Storage corruption | `dd if=/dev/urandom bs=1 count=10 of=smriti_vault.db conv=notrunc` (corrupt 10 random bytes) | integrity_check fails → `VaultStorageCorrupt` rule → seal vault → switch to last GCS snapshot | P0 alarm `indrajaal/l0/vault/corrupt` |
| 3 | Audit gap forge | call NIF, then `truncate -s -1024 smriti_vault_audit.log` | `VaultAuditGap` rule fires within 5s | P1 investigate alarm |
| 4 | KEK ciphertext tamper | flip 1 bit in `smriti_kek.sealed` | TPM unseal fails → fall through to passphrase/KMS | unseal-attempt audit shows TPM rejection |
| 5 | Wrong master key | call `vault_unseal(handle, [0u8; 32])` with not-the-real-master-key | `VaultError::WrongKey`; vault remains sealed | `VaultUnsealAttemptFailed` rule |
| 6 | Concurrent unseal race | 10 threads call `vault_unseal` simultaneously with same valid key | exactly one succeeds; others get `AlreadyUnsealed` no-op error | thread safety preserved |
| 7 | Sync clock skew (server clock advance > 1h) | system clock jumps 2h forward | sync still pulls latest by version, not by timestamp; SC-SMRITI-110 attestation freshness still verified | no false hard-stale |
| 8 | Disk full during put | exhaust disk, attempt `vault.put` | NIF returns `StorageError`; vault state unchanged | error propagated to caller; no plaintext leak |

## Mara agent integration

Existing `immune-chaos-agent` ([zk-aeac27b117a70c4b]) drives chaos scenarios on a periodic cron. Add 8 vault scenarios to its rotation:

```bash
sa-plan-daemon schedule-add \
  --name vault_chaos_drill \
  --cron "0 5 * * 0" \
  --worker mara_agent \
  --module vault_chaos_drill \
  --priority 70 \
  --max-attempts 1
```

Weekly Sunday 05:00 UTC — picks 1 of 8 scenarios at random, runs, verifies expected behavior, posts results to Zenoh.

## Closure

8/8 scenarios survive (graceful degradation OR correct fail-closed). No fail-open observed.
