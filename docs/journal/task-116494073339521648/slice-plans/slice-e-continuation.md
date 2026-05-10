# Slice E continuation — caller flip across 5 modules + .pi/ migration + Wisp router wiring

**sa-plan**: 116494259026350434 (P0)
**Depends on**: Slice B (NIF read working). ⏳
**Effort estimate**: 1-2 sessions
**Critical-path RPN**: 288 (second-highest)

ZK: [zk-bd82645aedcb5ef4] no Stub-That-Lies (caller flip MUST actually use vault, not just claim to)

---

## 1. Already shipped (Slice E partial, Pass-4)

| Artefact | Status |
|---|---|
| `lib/cepaf_gleam/src/cepaf_gleam/ui/wisp/secret_api.gleam` | ✅ skeleton (3 endpoints, OIDC-gated) |
| `secret_status_json`, `secret_value_json`, `secret_status_summary_json` | ✅ |
| `require_auth` Bearer-token gate | ✅ stub |
| `emit_access_audit` SC-VAULT-009 hook | ✅ stub |
| Wiring guard +3 tests | ✅ |

**What's stubbed**:
- `require_auth` returns Ok stubbed username; doesn't validate JWT yet
- `emit_access_audit` is a no-op
- No Wisp router entry yet (endpoint not callable)
- No callers actually use this (planning_daemon still reads `UserPreferences[secrets]`)

---

## 2. Wire Wisp router + handler (~120 LOC Gleam)

### E.1 — Add router entries in `ui/wisp/router.gleam`

```gleam
// Add 3 routes (OIDC-gated):
GET  /api/v1/secret/<name>          -> secret_get_handler
GET  /api/v1/secret/<name>/status   -> secret_status_handler
GET  /api/v1/secret-status           -> secret_summary_handler
```

### E.2 — Handler implementations (~80 LOC Gleam in `ui/wisp/secret_api.gleam`)

```gleam
pub fn secret_get_handler(req: Request, name: String) -> Response {
  case require_auth(get_authorization_header(req)) {
    Error(reason) -> response_401(error_json("unauthorized", reason))
    Ok(caller) -> {
      case vault.get(get_vault_handle(), name) {
        Ok(value) -> {
          let value_str = bit_array.to_string(value) |> result.unwrap("")
          let body = secret_value_json(name, value_str, get_version(name))
          let _ = emit_access_audit(caller, name, "ok")
          response_200_json(body)
        }
        Error(vault.NotFound(_)) -> {
          let _ = emit_access_audit(caller, name, "not_found")
          response_404(error_json("not_found", name))
        }
        Error(vault.TtlExpired(_)) -> {
          let _ = emit_access_audit(caller, name, "ttl_expired")
          response_403(error_json("ttl_expired", "fail-closed at MaxTTL"))
        }
        Error(vault.VaultSealed) -> {
          let _ = emit_access_audit(caller, name, "sealed")
          response_503(error_json("sealed", "vault not ready"))
        }
        Error(_) -> response_500(error_json("internal", ""))
      }
    }
  }
}
```

### E.3 — Real OIDC validation (~40 LOC, reuse `auth/oidc.gleam`)

Replace stub `require_auth`:
```gleam
pub fn require_auth(authorization: String) -> Result(String, String) {
  use token <- result.try(extract_bearer(authorization))
  use claims <- result.try(oidc.validate(token, jwks_url(), 5))
  use _ <- result.try(rbac.check_permission(claims, rbac.SecretRead))
  Ok(claims.username)
}
```

### E.4 — Real audit emission (~30 LOC)

```gleam
pub fn emit_access_audit(caller: String, name: String, result: String) -> Nil {
  let payload = json.object([
    #("at", json.int(timestamp.now_seconds())),
    #("caller", json.string(caller)),
    #("name", json.string(name)),
    #("result", json.string(result)),
  ]) |> json.to_string

  let topic = "indrajaal/l0/secret/access/" <> name
  let _ = zenoh_otel.publish(topic, payload)
  // Also append to local audit register
  let _ = audit_register.append(payload)
  Nil
}
```

---

## 3. Caller flip across 5 modules in planning_daemon

### E.5 — `mcp_inference.rs` — OpenRouter API key

Current:
```rust
let key = db::get_preference("openrouter_api_key")?.unwrap_or_default();
```

After:
```rust
// Option A: direct Rust call to vault provider (no network round-trip)
let key = vault_provider::get("openrouter_api_key")
    .ok_or(InferenceError::SecretMissing)?;
// Returns Zeroizing<Vec<u8>>; convert to &str only at API call site, drop ASAP
```

vault_provider is a new shared Rust module (see E.7). LOC: ~5 changed.

### E.6 — Same flip for 4 other modules

| Module | Secret used | LOC delta |
|---|---|---:|
| `mcp_inference.rs` | openrouter_api_key, gemini_api_key | ~10 |
| `gateway.rs` | telegram_token, gchat_webhook | ~15 |
| `mcp_gworkspace.rs` | google_oauth_refresh, google_client_secret | ~12 |
| `cortex.rs` | gemini_api_key, anthropic_api_key (if used in cortex) | ~8 |
| `audit_log.rs` | smtp app password (if applicable) | ~5 |

**Total**: ~50 LOC across 5 files.

### E.7 — `vault_provider.rs` — direct Rust caller into NIF (~80 LOC Rust)

```rust
// sub-projects/c3i/native/planning_daemon/src/vault_provider.rs
// Direct in-process call into rusty_vault_nif (skips BEAM).
// Same vault.db, same audit, same SC-VAULT enforcement.

use std::sync::OnceLock;
use rusty_vault::core::Core;
use zeroize::Zeroizing;

static VAULT_HANDLE: OnceLock<VaultHandle> = OnceLock::new();

pub fn init(storage_path: &Path, audit_path: &Path) -> Result<(), VaultError> {
    let handle = VaultHandle::new(storage_path, audit_path)?;
    VAULT_HANDLE.set(handle).map_err(|_| VaultError::AlreadyInit)?;
    Ok(())
}

pub fn unseal(master_key: &[u8]) -> Result<(), VaultError> {
    let handle = VAULT_HANDLE.get().ok_or(VaultError::NotInit)?;
    handle.unseal(master_key)
}

pub fn get(name: &str) -> Result<Zeroizing<Vec<u8>>, VaultError> {
    let handle = VAULT_HANDLE.get().ok_or(VaultError::NotInit)?;
    handle.kv_get(name)
}
```

**Concurrency**: `OnceLock` ensures single init; internal Mutex on `Core` ensures concurrent reads serialize safely.

### E.8 — `db::get_preference("secrets", _)` poison-pill (~15 LOC Rust)

After Slice E ships, change `db::get_preference` to **panic** when called for category `secrets`:
```rust
pub fn get_preference(key: &str) -> Result<Option<String>, IgnitionError> {
    // SC-VAULT-003 enforcement: secrets must come from vault, not UserPreferences
    if is_secret_category(key) {
        panic!("[SC-VAULT-003 VIOLATION] db::get_preference for secret '{}' — use vault_provider::get instead", key);
    }
    // ... existing logic
}
```

This is the Poka-yoke per TPS countermeasures — makes the wrong path impossible.

---

## 4. .pi/ migration

### E.9 — Modify `.pi/anthropic-client.ts:42-53` (~20 LOC TypeScript)

Current constructor reads `config.json:apiKey`. Replace with:
```typescript
async function getAnthropicKey(): Promise<string> {
  const resp = await fetch('https://localhost:4200/api/v1/secret/anthropic_api_key', {
    headers: { Authorization: `Bearer ${process.env.C3I_PI_TOKEN}` },
    timeout: 5000,
  });
  if (!resp.ok) throw new Error(`Vault fetch failed: ${resp.status}`);
  const body = await resp.json();
  return body.value;
}
```

`C3I_PI_TOKEN` is provisioned by `sa-plan vault create-pi-token` — short-lived (1h) JWT scoped to `secret_read:anthropic_api_key`.

### E.10 — Replace `.pi/config.json` plaintext key with placeholder

```json
{
  "apiKey": "<set via sa-plan vault put anthropic_api_key>"
}
```

And `.pi/config.example.json` same — restore the placeholder shape so it's not a real key.

### E.11 — Pi token issuance CLI (~50 LOC Rust + Gleam)

`sa-plan vault create-pi-token` issues a short-lived JWT signed with vault master key. Pi reads from env. Documented in `.pi/README.md`.

---

## 5. Files to create / modify

| File | Action | LOC |
|---|---|---:|
| `lib/cepaf_gleam/src/cepaf_gleam/ui/wisp/router.gleam` | edit (+3 routes) | +30 |
| `lib/cepaf_gleam/src/cepaf_gleam/ui/wisp/secret_api.gleam` | edit (handlers, real auth, real audit) | +150 |
| `sub-projects/c3i/native/planning_daemon/src/vault_provider.rs` | new (in-process) | +80 |
| `sub-projects/c3i/native/planning_daemon/src/{mcp_inference,gateway,mcp_gworkspace,cortex,audit_log}.rs` | edit (caller flip) | +50 |
| `sub-projects/c3i/native/planning_daemon/src/db.rs` | edit (poison-pill on secrets category) | +15 |
| `sub-projects/c3i/native/planning_daemon/src/cli.rs` | edit (`sa-plan vault create-pi-token`) | +60 |
| `.pi/anthropic-client.ts` | edit (lines 42-53) | +20 / -10 |
| `.pi/config.json` | edit (placeholder) | -1 / +1 |
| `.pi/config.example.json` | edit (placeholder) | -1 / +1 |
| `lib/cepaf_gleam/test/secret_api_e2e_test.gleam` | new | +200 |
| `sub-projects/c3i/native/planning_daemon/tests/vault_provider_test.rs` | new | +120 |

**Total**: ~755 LOC.

---

## 6. Verification gates

```bash
# Build
cd lib/cepaf_gleam && gleam build && gleam test
cd sub-projects/c3i/native/planning_daemon && cargo build --release

# Verify caller flip — should fail-fast if any caller still uses db::get_preference
cargo test --test caller_flip_test  # new test asserts no calls to db::get_preference for secrets category

# Wisp REST E2E
curl -sk -H "Authorization: Bearer $TOKEN" https://localhost:4200/api/v1/secret-status | jq .
# Returns: {vault_state: "Active", counts: {...}, dashboard_color: "green", per_secret: [...]}

# Pi/.pi/ migration verify
cd .pi && node -e "
  process.env.C3I_PI_TOKEN = '$TOKEN';
  const c = require('./anthropic-client');
  c.getKey().then(k => { console.log('Key fetched, len=' + k.length); });
"

# Anti-pattern guard (post-flip)
git ls-files -z | xargs -0 grep -E "db::get_preference\(\"secrets" && exit 1
# Empty grep == no caller bypassing the vault
```

Closure criteria:
- ✅ All 3 Wisp endpoints return correct status codes (200/401/403/404/503)
- ✅ OIDC validation rejects expired/wrong-issuer/wrong-audience tokens
- ✅ All 5 planning_daemon modules use `vault_provider::get`, not `db::get_preference`
- ✅ Poison-pill panic fires if any code regression tries `db::get_preference("secrets", _)`
- ✅ `.pi/config.json` no longer contains live key (only placeholder)
- ✅ Pi anthropic-client successfully fetches via REST endpoint
- ✅ Audit log shows 1 entry per secret access from any caller (Pi or planning_daemon)
- ✅ Zenoh subscription to `indrajaal/l0/secret/access/**` captures all events

---

## 7. Risks + mitigations

| Risk | Mitigation |
|---|---|
| In-process `vault_provider` and NIF-mediated `rusty_vault_nif` access same vault.db concurrently | both use SQLite WAL with `synchronous=FULL`; reads are lock-free; writes serialize via vault.lock |
| Pi runtime can't reach localhost:4200 (firewall) | document in `.pi/README.md`; add `C3I_PI_VAULT_URL` env override; fallback to env-var read of `ANTHROPIC_API_KEY` for dev only |
| `db::get_preference` poison-pill breaks unrelated callers | only category=secrets panics; other prefs (agent, infrastructure, identity) unaffected |
| `.pi/anthropic-client.ts` unit tests fail in offline CI | mock vault REST endpoint in test setup |
| Forgetting to remove `.pi/config.json` after migration | pre-commit hook (already ARMED) catches plaintext shape on next commit |

---

## 8. Cross-references
- SC-VAULT-003 enforced by E.6 + E.8 poison-pill
- SC-VAULT-009 enforced by E.4 audit emission
- SC-VAULT-025 enforced by E.9-E.10 (.pi/ via REST only)
- RETE-UL `VaultSealedAtBoot` (sal 100) — fires from E.2 if vault sealed when caller arrives
- RETE-UL `SecretHardStale` (sal 100) — fires from E.2 ttl_expired path
- TPS Poka-yoke pillar — E.8 makes wrong path impossible
- Pre-commit hook (Pass-3 ARMED) — final guard against E.10 regression
