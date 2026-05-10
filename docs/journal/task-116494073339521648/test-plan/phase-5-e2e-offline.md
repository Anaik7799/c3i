# Phase 5 — E2E 1-week offline simulation (the killer test)

## Why this phase exists

Operator's hard requirement: **"How will this work if I don't have internet connectivity for say 1 week."**

Phase 5 proves that requirement mechanically.

## Test scenario

Pre-state: vault active, all 8 secrets fresh, last GCP sync 1 min ago.

| Time | Action | Expected |
|---|---|---|
| t=0 | `iptables -A OUTPUT -d secretmanager.googleapis.com -j DROP` and same for `cloudkms.googleapis.com` | Network to GCP severed |
| t=0+1min | `sa-plan get-pref --category secrets openrouter_api_key` | ✓ returns value (cache fresh) |
| t=0+5min | `sa-plan vault status` | shows last-sync = 5min ago, all secrets fresh |
| t=0+6min (TTL=5min) | `sa-plan get-pref --category secrets openrouter_api_key` | ✓ returns value, but `SecretSoftStaleOffline` rule fires; OTel `degraded` envelope |
| t=0+6min | `sa-plan vault status` | dashboard tile **amber**; per-secret freshness shows `openrouter_api_key: soft-stale` |
| t=0+1day | `sa-plan get-pref --category secrets openrouter_api_key` | ✓ returns value (still within MaxTTL=7d) |
| t=0+6day | `sa-plan vault status` | **amber**; countdown shows ~24h remaining for hot keys |
| t=0+6day+23h | (P1 alert email auto-sent at MaxTTL-24h) | operator sees email |
| t=0+6day+23h+1m | (P0 alarm Telegram + Zenoh at MaxTTL-1h) | operator sees alarm |
| t=0+7day+ε | `sa-plan get-pref --category secrets openrouter_api_key` | ✗ **FAIL-CLOSED**, returns `Error(VaultError::TtlExpired)`; P0 alarm `indrajaal/l0/secret/expired/openrouter_api_key`; dashboard tile **red** for that secret |
| t=0+7day+ε | `sa-plan get-pref --category secrets gmail_app_password` | ✓ returns value (long-TTL=30d, still fresh) |
| t=0+7day+1m | `iptables -D OUTPUT -d secretmanager.googleapis.com -j DROP` (reconnect) | network restored |
| t=0+7day+5m | `sa-plan vault status` | sync_actor resumes within 5 min; all secrets refreshed; dashboard back to **green** |

## Implementation

```bash
# tests/phase5_offline.sh (per SC-SCRIPT-GLEAM-001 — implemented as gleam orchestrator):
# scripts-gleam/src/scripts/test/vault_offline.gleam

# But for the E2E setup hook, we need iptables (one-shot privileged op):
sudo /sbin/iptables -A OUTPUT -d secretmanager.googleapis.com -j DROP
sudo /sbin/iptables -A OUTPUT -d cloudkms.googleapis.com -j DROP

# Then drive simulated time advance via FreezeGun-style clock injection in the
# vault_sync_actor's clock dependency (not real sleep).
# Vault_sync_actor accepts a `now()` injectable for this purpose.
```

## Time advance technique (FreezeGun-style)

`vault_sync_actor.gleam` accepts an injectable `clock: fn() -> Int`. In test mode, the
clock is driven by the test harness:

```gleam
// test harness
let test_clock = clock.new()
let actor = vault_sync_actor.start_link(clock: test_clock.now, ...)
clock.advance(test_clock, hours(24 * 6))  // jump 6 days
// assert: SecretSoftStaleOffline rule fired N times
clock.advance(test_clock, hours(24))      // jump to 7d+ε
// assert: SecretHardStale rule fired
let assert Error(vault.TtlExpired(_)) = vault.get(h, "openrouter_api_key")
```

This avoids actually sleeping for 7 days in CI.

## Per-secret-policy verification

The same offline simulation also verifies that **long-TTL secrets remain fresh**:

| Secret | TTL | MaxTTL | Expected at t=7day+ε |
|---|---:|---:|---|
| anthropic_api_key | 5min | 7d | hard-stale (FAIL-CLOSED) |
| openrouter_api_key | 5min | 7d | hard-stale (FAIL-CLOSED) |
| gemini_api_key | 5min | 7d | hard-stale (FAIL-CLOSED) |
| telegram_token | 1h | 30d | still fresh |
| gmail_app_password | 6h | 30d | still fresh |
| google_oauth_refresh | 1h | 7d | hard-stale (boundary case) |
| google_client_secret | 24h | 90d | still fresh |
| gchat_webhook | 24h | 90d | still fresh |

The 5 long-TTL secrets must continue to work even at t=7day, proving that variable
per-secret TTL works correctly.

## Closure criteria

- ✅ Hot path uninterrupted at every t < MaxTTL_per_secret
- ✅ `SecretSoftStaleOffline` rule fires at exactly t = TTL boundary
- ✅ `SecretHardStale` rule fires at exactly t = MaxTTL boundary
- ✅ Long-TTL secrets remain fresh past 7 days
- ✅ P1 email auto-sent at MaxTTL - 24h
- ✅ P0 alarm fires at MaxTTL - 1h
- ✅ Reconnect convergence ≤ 5 min
- ✅ No fail-open observed at any boundary
