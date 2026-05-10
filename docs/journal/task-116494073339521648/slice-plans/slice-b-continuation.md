# Slice B continuation — wire RustyVault::core::Core into NIF stub bodies

**sa-plan**: 116494382047537935 (P0)
**Depends on**: Slice A complete (vendored crate, scrubbed). ✅
**Unblocks**: Slice C, E
**Effort estimate**: 2-3 sessions
**Critical-path RPN**: 180

ZK: [zk-de13e287de7b9f74] reuse `ha/hsm_vault.gleam` rotation policy · [zk-bd82645aedcb5ef4] no Stub-That-Lies (every claimed encryption MUST produce ciphertext)

---

## 1. What's already shipped (Slice B partial, Pass-2)

| Artefact | Status | LOC |
|---|---|---:|
| `lib/cepaf_gleam/native/rusty_vault_nif/Cargo.toml` | ✅ | 30 |
| `lib/cepaf_gleam/native/rusty_vault_nif/src/lib.rs` | ✅ skeleton | 360 |
| 10 NIF entry points compile + dispatch on FSM state | ✅ | — |
| `VaultHandle` resource, `VaultState` enum, `VaultError` enum, atoms | ✅ | — |
| `lib/cepaf_gleam/src/rusty_vault_nif.erl` Erlang shim | ✅ | 31 |
| `lib/cepaf_gleam/src/cepaf_gleam/vault.gleam` typed wrapper | ✅ stubs | 165 |
| `cargo check --release` PASS, SC-VAULT-CRYPTO-001 verified | ✅ | — |

**What's stubbed**: `vault_kv_put`, `vault_kv_get`, `vault_kv_versions`, `vault_kv_destroy`, `vault_lease_renew`, `vault_audit_tail` return shaped errors but don't actually touch RustyVault Core.

---

## 2. RustyVault::core API mapping (this slice)

Map of NIF stub → upstream RustyVault entry point:

| NIF | RustyVault Core call | Notes |
|---|---|---|
| `vault_init` | `Core::new(config)` + `Core::init(seal_config, recovery_config)` | seal_config = Shamir threshold 1/1 (single operator); recovery = none (we use TPM/passphrase/KMS chain instead) |
| `vault_unseal` | `Core::unseal(key)` | accepts master key bytes |
| `vault_seal` | `Core::seal()` | drops master key from RAM |
| `vault_status` | `Core::sealed_state()` + `Core::ha_state()` | returns map of sealed/active/standby/etc. |
| `vault_kv_put` | mount kv-v2 backend → `LogicalRequest::write("secret/data/<name>", serde_json!{"data":{"value":<b64>},"options":{"max_versions":N}})` | requires kv-v2 mounted at boot via `Core::mount_logical_backend("secret/", "kv", ...)` |
| `vault_kv_get` | `LogicalRequest::read("secret/data/<name>")` | returns `Response::data` map; extract `data.value` field, base64 decode |
| `vault_kv_versions` | `LogicalRequest::read("secret/metadata/<name>")` | returns versions map |
| `vault_kv_destroy` | `LogicalRequest::write("secret/destroy/<name>", {"versions":[N]})` | hard delete a specific version |
| `vault_lease_renew` | `LeaseManager::renew(lease_id, increment)` | returns new expiry |
| `vault_audit_tail` | read audit FileBackend log file directly OR `Core::audit().list_entries(since)` | local JSON log |

---

## 3. Ordered work items

### B.1 — Mount kv-v2 backend at init (~80 LOC Rust)

Modify `vault_init` to:
1. Create `Core::default()` config pointing at `smriti_vault.db`
2. Initialize Shamir 1/1 (single key, no split — operator + KEK chain handles this above)
3. Mount kv-v2 at path `"secret/"` with `max_versions=10`
4. Mount audit FileBackend pointing at `smriti_vault_audit.log`
5. Persist to disk; transition to Sealed state
6. Return ResourceArc<VaultHandle>

Test: `vault_init_creates_persistent_state_test` — call init twice in same path, second call recovers existing vault.

### B.2 — Wire vault_kv_put body (~40 LOC Rust)

```rust
let core = handle.core.lock().unwrap();
if !core.unsealed() { return /* sealed error */; }

// SC-VAULT-CRYPTO-001 enforced upstream — Core uses our western-only crate
let req = LogicalRequest::new(Operation::Update)
    .with_path(format!("secret/data/{}", name))
    .with_data(json!({
        "data": { "value": base64::encode(value.as_slice()) },
        "options": { "max_versions": policy_max_versions }
    }));

let resp = core.handle_request(&req)?;
let version = resp.data["data"]["metadata"]["version"].as_i64()?;

// Persist policy to smriti.db secret_policy table (separate connection)
write_policy_row(&handle.smriti_conn, name, ttl_sec, max_ttl_sec)?;

// SC-VAULT-009: emit audit envelope (calls audit log + Zenoh)
emit_audit_event(&handle, "put", name, "ok");

Ok(VersionInfo { version, lease_id: format!("kv:{}:{}", name, version) })
```

Test: `vault_put_then_get_round_trip_test` (Phase 2 integration).

### B.3 — Wire vault_kv_get body (~40 LOC Rust)

```rust
let core = handle.core.lock().unwrap();
if !core.unsealed() { return /* sealed */; }

let req = LogicalRequest::new(Operation::Read)
    .with_path(format!("secret/data/{}", name));

match core.handle_request(&req) {
    Ok(resp) => {
        let value_b64 = resp.data["data"]["value"].as_str()?;
        let value = base64::decode(value_b64)?;

        // SC-VAULT-006: check freshness against secret_policy
        let policy = read_policy_row(&handle.smriti_conn, name)?;
        let fetched_at = resp.data["data"]["metadata"]["created_time"]?;
        let age = now() - fetched_at;
        if age >= policy.max_ttl_seconds {
            emit_audit_event(&handle, "get", name, "ttl_expired");
            return /* TtlExpired error */;
        }

        emit_audit_event(&handle, "get", name, "ok");
        // Wrap in Zeroizing<Vec<u8>>
        Ok(Zeroizing::new(value))
    }
    Err(_) => /* NotFound */
}
```

Test: `get_returns_ttl_expired_when_past_max_ttl_test`.

### B.4 — Wire remaining 4 stubs (~120 LOC Rust)

`vault_kv_versions`, `vault_kv_destroy`, `vault_lease_renew`, `vault_audit_tail` follow same pattern. Each reads from Core, formats, returns.

### B.5 — Update vault.gleam typed wrapper to consume real responses (~80 LOC Gleam)

Replace stub bodies with `dynamic.field` decoding:

```gleam
pub fn put(handle, name, value, policy) -> Result(VersionInfo, VaultError) {
  let #(tag, payload) = ffi_kv_put(handle, name, value, policy.ttl, policy.max_ttl)
  case atom.to_string(tag) {
    "ok" -> {
      // payload is %{version: int, lease_id: bin}
      let version = decode_version(payload)
      let lease_id = decode_lease_id(payload)
      Ok(VersionInfo(version: version, lease_id: lease_id))
    }
    "error" -> Error(parse_error_payload(payload))
  }
}
```

Add helper module `cepaf_gleam/vault_ffi_decode.gleam` (~60 LOC) for term-decoding boilerplate.

### B.6 — Audit fan-out helper (~30 LOC Rust)

```rust
fn emit_audit_event(handle: &VaultHandle, op: &str, name: &str, result: &str) {
    // Append to RustyVault audit log file
    let entry = json!({"ts": now(), "op": op, "name": name, "result": result});
    handle.audit_writer.lock().unwrap().write_all(entry.to_string().as_bytes());

    // Publish Zenoh envelope (SC-VAULT-009)
    publish_zenoh(
        format!("indrajaal/l0/secret/access/{}", name),
        entry.to_string()
    );
}
```

Reuses `zenoh_telemetry.rs` patterns from planning_daemon.

### B.7 — Test extensions (~250 LOC Rust + Gleam)

**Rust unit tests** (`tests/nif_test.rs`):
- `init_creates_sealed_vault_with_kv_mounted`
- `unseal_with_correct_master_key_succeeds`
- `unseal_with_wrong_key_returns_wrong_key_error`
- `put_then_get_round_trip`
- `get_after_max_ttl_returns_expired`
- `versions_returns_all_history`
- `destroy_removes_specific_version`
- `lease_renew_extends_expiry`
- `audit_tail_returns_recent_entries`
- `seal_zeroizes_master_then_get_fails_sealed`

**Gleam integration tests** (`test/vault_integration_test.gleam`):
- `full_round_trip_test`
- `policy_enforcement_test`
- `ttl_boundary_test`
- `concurrent_get_safety_test`

---

## 4. Files to create / modify

| File | Action | LOC delta |
|---|---|---:|
| `lib/cepaf_gleam/native/rusty_vault_nif/src/lib.rs` | edit (B.1-B.4, B.6) | +400 |
| `lib/cepaf_gleam/native/rusty_vault_nif/src/audit.rs` | new | +50 |
| `lib/cepaf_gleam/native/rusty_vault_nif/src/policy_db.rs` | new (smriti.db conn for secret_policy) | +80 |
| `lib/cepaf_gleam/native/rusty_vault_nif/Cargo.toml` | edit (+rusqlite, base64, zenoh) | +5 |
| `lib/cepaf_gleam/native/rusty_vault_nif/tests/nif_test.rs` | new (B.7 Rust tests) | +250 |
| `lib/cepaf_gleam/src/cepaf_gleam/vault.gleam` | edit (B.5) | +80 |
| `lib/cepaf_gleam/src/cepaf_gleam/vault_ffi_decode.gleam` | new | +60 |
| `lib/cepaf_gleam/test/vault_integration_test.gleam` | new (B.7 Gleam tests) | +200 |
| `sub-projects/c3i/native/planning_daemon/src/db.rs` | edit (CREATE TABLE secret_policy) | +50 |

**Total**: ~1,175 LOC code + tests.

---

## 5. Verification gates

```bash
# Build gates
cd lib/cepaf_gleam/native/rusty_vault_nif && cargo build --release
cd lib/cepaf_gleam && gleam build && gleam test

# Crypto audit (must remain empty)
cd lib/cepaf_gleam/native/rusty_vault_nif && cargo tree | grep -iE 'tongsuo|sm[234]'

# NIF round-trip
cd lib/cepaf_gleam/native/rusty_vault_nif && cargo test --release

# Integration tests
cd lib/cepaf_gleam && gleam test -- --module vault_integration_test
```

Closure criteria (all must pass):
- ✅ `cargo build --release` produces `librusty_vault_nif.so`
- ✅ NIF tests: 10/10 pass
- ✅ Gleam integration tests: 4/4 pass
- ✅ vault.put then vault.get round-trip returns the same plaintext bytes
- ✅ Tongsuo absence audit empty
- ✅ No fail-open at TTL boundary
- ✅ Audit log file grows by 1 entry per NIF call
- ✅ Zenoh envelope captured by `zenoh-cli sub 'indrajaal/l0/secret/access/**'`

---

## 6. Risks + mitigations

| Risk | Mitigation |
|---|---|
| RustyVault::core API may differ from upstream Vault docs | Read `sub-projects/rusty_vault_vendored/src/core/mod.rs` directly; pattern-match on actual signatures |
| `Core::new` may want async init | wrap in `tokio::runtime::Runtime::block_on` inside the dirty-IO NIF; never block scheduler thread |
| KV v2 mount config may need additional fields | Test `vault_init` early; iterate signature |
| Zenoh client init in NIF context | reuse `zenoh::open` pattern from `planning_daemon::zenoh_telemetry` |
| audit log rotation when file grows past 100 MB (SC-VAULT-022) | log rotation handler in `audit.rs`; test in integration phase |
| smriti.db CREATE TABLE conflicts with running daemon | run as IF NOT EXISTS; verified by integration test fixture |

---

## 7. Cross-references
- TLA+ invariant `BootUnsealsKEK` → verified by B.1 (init must produce a sealed vault that requires explicit unseal)
- Agda type-level proof `Sealed → ¬PlaintextAccessible` → enforced by B.3 (get returns Sealed if not active)
- RETE-UL rule `SecretFresh` (sal 100) → consumed by B.3 freshness check
- RETE-UL rule `SecretBootUnsealFailed` → triggered when B.2/B.3 sees Sealed state with positive uptime
- Allium contract `VaultStorage` → all 10 NIFs satisfy this contract
- Doc pack: this slice closes the §11 first table row
