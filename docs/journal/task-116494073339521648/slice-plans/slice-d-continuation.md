# Slice D continuation — wire GCP Secret Manager HTTP client + sync actor body

**sa-plan**: 116494259024062400 (P1)
**Depends on**: Slice B (NIF read/write working). ⏳
**Effort estimate**: 1 session
**Critical-path RPN**: 175

---

## 1. Already shipped (Slice D skeleton, Pass-4)

| Artefact | Status |
|---|---|
| `lib/cepaf_gleam/src/cepaf_gleam/vault_sync_actor.gleam` (165 LOC) | ✅ skeleton |
| State / Msg / SyncOutcome / SyncDirection types | ✅ |
| Circuit breaker logic (`circuit_should_open`, `circuit_open_for`) | ✅ tested |
| Conflict resolution (`decide_direction/3`) | ✅ tested 4 cases |
| `vault_sync.gleam` cron script | ✅ stub |

**What's stubbed**: `handle_tick` body just returns `Nominal(0,0,1)`; doesn't actually pull/push from GCP.

---

## 2. GCP Secret Manager HTTP client

### D.1 — ADC token helper (~40 LOC Rust, in NIF or shared crate)

Already exists in `sub-projects/c3i/native/planning_daemon/src/backup.rs`. Slice D imports it via:

Option A — extract `backup.rs` ADC logic into shared `src/gcp_auth.rs` module, both `backup.rs` and the new `secret_manager_client.rs` use it.

Option B — duplicate (~30 LOC). Pick A — single source of truth.

```rust
// shared: sub-projects/c3i/native/planning_daemon/src/gcp_auth.rs
pub async fn adc_token() -> Result<String, GcpAuthError> {
    // Read $GOOGLE_APPLICATION_CREDENTIALS or fall to gcloud metadata server
    // Cache with 50min TTL (tokens are 1h)
    // Return bearer token
}
```

### D.2 — Secret Manager client (~120 LOC Rust in `secret_manager_client.rs`)

```rust
use serde_json::json;
use std::time::Duration;

const PROJECT: &str = "durable-limiter-457011-u7";
const REGION: &str = "europe-north1";

pub struct SecretManagerClient {
    http: reqwest::Client,
    base_url: String,
}

impl SecretManagerClient {
    pub fn new() -> Self {
        Self {
            http: reqwest::Client::builder()
                .timeout(Duration::from_secs(5))
                .build().unwrap(),
            base_url: format!("https://secretmanager.googleapis.com/v1/projects/{}", PROJECT),
        }
    }

    /// GET .../secrets — list all secrets in the project
    pub async fn list_secrets(&self) -> Result<Vec<SecretMeta>, SmError> {
        let token = adc_token().await?;
        let url = format!("{}/secrets?pageSize=100", self.base_url);
        let resp = self.http.get(&url).bearer_auth(token).send().await?;
        let body: ListSecretsResponse = resp.json().await?;
        Ok(body.secrets)
    }

    /// GET .../secrets/<name>/versions/latest:access — fetch latest plaintext
    pub async fn access_latest(&self, name: &str) -> Result<Vec<u8>, SmError> {
        let token = adc_token().await?;
        let url = format!("{}/secrets/{}/versions/latest:access", self.base_url, name);
        let resp = self.http.get(&url).bearer_auth(token).send().await?;
        let body: AccessResponse = resp.json().await?;
        Ok(base64::decode(&body.payload.data)?)
    }

    /// POST .../secrets/<name>:addVersion — push new value
    pub async fn add_version(&self, name: &str, value: &[u8]) -> Result<i64, SmError> {
        let token = adc_token().await?;
        let url = format!("{}/secrets/{}:addVersion", self.base_url, name);
        let body = json!({"payload": {"data": base64::encode(value)}});
        let resp = self.http.post(&url).bearer_auth(token).json(&body).send().await?;
        let body: AddVersionResponse = resp.json().await?;
        Ok(body.version_number)
    }

    /// Network probe: 200ms TCP connect to fail-fast
    pub async fn probe(&self) -> bool {
        tokio::time::timeout(
            Duration::from_millis(200),
            tokio::net::TcpStream::connect("secretmanager.googleapis.com:443")
        ).await.is_ok()
    }
}
```

### D.3 — NIF surface for sync (~60 LOC Rust)

Add 3 NIFs:
- `gcp_sm_list() -> {ok, list({name, latest_version})} | {error, reason}`
- `gcp_sm_access(name) -> {ok, plaintext_bin, version} | {error, reason}`
- `gcp_sm_add_version(name, value) -> {ok, version} | {error, reason}`

Wraps `SecretManagerClient` async calls in `tokio::runtime::Handle::block_on` since NIF is dirty-IO scheduled.

### D.4 — Wire `vault_sync_actor.gleam` body (~120 LOC Gleam)

Replace `handle_tick`:
```gleam
pub fn handle_tick(state: State, now_seconds: Int) -> #(State, SyncOutcome) {
  case state.circuit_open_until > now_seconds {
    True -> #(state, CircuitOpen(state.circuit_open_until - now_seconds))
    False -> {
      // Probe network
      case rusty_vault_nif.gcp_sm_probe() {
        False -> #(handle_network_probe(state, False), Degraded("offline"))
        True -> sync_now(state, now_seconds)
      }
    }
  }
}

fn sync_now(state: State, now: Int) -> #(State, SyncOutcome) {
  let started = now
  let result = case rusty_vault_nif.gcp_sm_list() {
    Ok(remote_secrets) -> {
      let pulled = list.fold(remote_secrets, 0, fn(count, remote) {
        case decide_direction_for(state.handle, remote.name, remote.version) {
          Pull(v) -> {
            case rusty_vault_nif.gcp_sm_access(remote.name) {
              Ok(#(plaintext, v)) -> {
                let _ = vault.put(state.handle, remote.name, plaintext, default_policy_for(remote.name))
                count + 1
              }
              Error(_) -> count
            }
          }
          _ -> count
        }
      })
      let pushed = push_unsynced_local(state.handle)
      Nominal(pulled, pushed, now - started)
    }
    Error(_) -> {
      let new_state = record_failure(state, now)
      Degraded("gcp list failed")
    }
  }
  #(record_success(state, now), result)
}
```

### D.5 — Activate the cron-wired vault_sync.gleam script (~40 LOC Gleam)

Replace stub body in `sub-projects/scripts-gleam/src/scripts/verify/vault_sync.gleam`:
```gleam
pub fn main() {
  // Cron tick → invoke vault_sync_actor.handle_tick once
  let handle = open_or_attach_vault()
  let state = vault_sync_actor.init(handle)
  let #(_new_state, outcome) = vault_sync_actor.handle_tick(state, now_seconds())
  publish_zenoh_outcome(outcome)
  case outcome {
    Nominal(_, _, _) -> System.exit(0)
    Degraded(_) -> System.exit(1)  // soft fail; cron will retry
    CircuitOpen(_) -> System.exit(0)  // not an error, just skipping
  }
}
```

---

## 3. Files to create / modify

| File | Action | LOC |
|---|---|---:|
| `sub-projects/c3i/native/planning_daemon/src/gcp_auth.rs` | extract from backup.rs | +50 |
| `sub-projects/c3i/native/planning_daemon/src/backup.rs` | edit (use shared gcp_auth) | -30 +5 |
| `lib/cepaf_gleam/native/rusty_vault_nif/src/secret_manager_client.rs` | new | +180 |
| `lib/cepaf_gleam/native/rusty_vault_nif/src/lib.rs` | edit (+3 NIFs) | +60 |
| `lib/cepaf_gleam/native/rusty_vault_nif/Cargo.toml` | edit (+reqwest, +base64) | +3 |
| `lib/cepaf_gleam/src/cepaf_gleam/vault_sync_actor.gleam` | edit (wire body) | +120 |
| `sub-projects/scripts-gleam/src/scripts/verify/vault_sync.gleam` | edit (wire main) | +40 |
| `lib/cepaf_gleam/native/rusty_vault_nif/tests/secret_manager_test.rs` | new (with wiremock) | +120 |
| `lib/cepaf_gleam/test/vault_sync_integration_test.gleam` | new | +120 |

**Total**: ~668 LOC.

---

## 4. Verification gates

```bash
# Mock GCP server for local tests
cd lib/cepaf_gleam/native/rusty_vault_nif && cargo test --test secret_manager_test

# Integration: real GCP (requires ADC token + IAM bind)
cd lib/cepaf_gleam && gleam test -- --module vault_sync_integration_test

# Cron tick verification
gleam run -m scripts/verify/vault_sync
# Should print: [vault_sync] cron tick + outcome (Nominal/Degraded/CircuitOpen)

# Offline simulation
sudo iptables -A OUTPUT -d secretmanager.googleapis.com -j DROP
gleam run -m scripts/verify/vault_sync
# Should print: outcome=Degraded(offline) + exit 1

# Circuit breaker
# 3 consecutive failures should open circuit, 4th tick returns CircuitOpen
```

Closure criteria:
- ✅ List secrets returns ≥ 1 entry from europe-north1
- ✅ Access returns the same plaintext that vault.get returns post-sync
- ✅ Add-version increments remote version monotonically
- ✅ Probe returns False within 250ms when network down
- ✅ Circuit breaker opens after 3 failures, closes after 60s
- ✅ Conflict resolution: simulate local rotation while offline, sync on reconnect → push uploads new version

---

## 5. Risks + mitigations

| Risk | Mitigation |
|---|---|
| ADC token expires mid-sync | refresh on 401; cache with 50min TTL not 60min |
| GCP quota exceeded (2,500 reads/min) | sync only changed versions per `list_secrets` page filter; backoff |
| Secret deleted in GCP console | sync sees 404 on access → emit `indrajaal/l0/secret/sync/remote_deleted` → operator decides |
| `tokio::block_on` inside dirty-IO NIF causes deadlock | use `Handle::current()` not `Runtime::new()` per call; one runtime per process |
| Region pinning enforcement | env var `GCP_VAULT_REGION=europe-north1`; fail closed if unset |

---

## 6. Cross-references
- TLA+ `SyncConvergence` liveness — verified by D.4 conflict resolution
- RETE-UL `SecretSoftStale` (sal 95) → triggers D.4 sync_now()
- RETE-UL `VaultAuditGap` (sal 90) → triggers if D.4 emits sync without audit log entry
- Allium `GcpSync` contract — all 4 ops in D.2 implement
- Pre-commit hook (Pass-3, ARMED) ensures no plaintext SM API responses leak to logs
