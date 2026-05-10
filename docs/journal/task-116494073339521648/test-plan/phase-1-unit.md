# Phase 1 — Unit tests (200+ tests, < 30s wall)

## Coverage matrix

| Subject | Files | Tests | Math gate |
|---|---|---:|---|
| NIF round-trip | `tests/nif_test.rs` | 30 (10 NIFs × 3 cases each) | — |
| `vault.gleam` typed wrapper | `test/vault_test.gleam` | 40 (10 functions × 4 cases) | H ≥ 2.5 |
| `vault_supervisor.gleam` boot KEK chain | `test/vault_supervisor_test.gleam` | 25 (3 paths × {happy, fallback, fail}) | — |
| `vault_sync_actor.gleam` | `test/vault_sync_actor_test.gleam` | 30 (idle/syncing/circuit-open transitions) | CCM ≥ 0.90 |
| RETE-UL `secret_freshness` rules | `test/secret_freshness_rules_test.gleam` | 35 (7 rules × 5 boundary cases) | — |
| RETE-UL `vault_integrity` rules | `test/vault_integrity_rules_test.gleam` | 25 (5 rules × 5 boundary cases) | — |
| Wisp REST `secret_api.gleam` | `test/secret_api_test.gleam` | 20 (auth, freshness, error cases) | — |
| `vault_wiring_test.gleam` | wiring guard | 13 strict invariants | — |

**Total**: ~218 tests.

## Sample test (NIF)

```rust
// tests/nif_test.rs
#[test]
fn vault_init_creates_sealed_vault() {
    let temp = tempfile::tempdir().unwrap();
    let storage = temp.path().join("vault.db");
    let audit = temp.path().join("vault-audit.log");
    let handle = vault_init(&storage, &audit).unwrap();
    let status = vault_status(&handle).unwrap();
    assert!(status.sealed, "vault must be sealed at init (SC-VAULT-001)");
}

#[test]
fn vault_get_when_sealed_returns_sealed_error() {
    let h = init_for_test();
    // do NOT unseal
    let result = vault_kv_get(&h, "anthropic_api_key");
    assert!(matches!(result, Err(VaultError::Sealed)));
}

#[test]
fn vault_round_trip_unseal_put_get() {
    let h = init_for_test();
    let master_key = [0u8; 32];
    vault_unseal(&h, &master_key).unwrap();
    let policy = SecretPolicy { ttl: 300, max_ttl: 604_800, rotation_days: 30, sensitivity: L0 };
    vault_kv_put(&h, "test_secret", b"test_value", policy).unwrap();
    let value = vault_kv_get(&h, "test_secret").unwrap();
    assert_eq!(&*value, b"test_value");
}
```

## Sample test (Gleam wrapper)

```gleam
// test/vault_test.gleam
import gleeunit/should
import cepaf_gleam/vault

pub fn typed_error_on_sealed_test() {
  let assert Error(vault.Sealed) = vault.get(test_handle(), "anthropic_api_key")
}

pub fn fresh_after_put_test() {
  let h = unseal_for_test()
  let policy = vault.SecretPolicy(ttl: 300, max_ttl: 604_800, rotation_days: 30, sensitivity: vault.L0)
  let assert Ok(version_info) = vault.put(h, "k1", <<"v1":utf8>>, policy)
  should.equal(version_info.version, 1)
}
```

## Math gates

- **Shannon entropy** over test classes (happy/error/boundary/fallback/concurrency): H = -Σ(p_i log2 p_i) ≥ 2.5 bits
- **CCM** weighted coverage: ≥ 0.90 across {NIF, wrapper, supervisor, sync, rules, REST}
- **ITQS** integrated quality: ≥ 0.85

## Run

```bash
cd lib/cepaf_gleam && gleam test -- --module vault_test --module vault_supervisor_test --module vault_sync_actor_test
cd lib/cepaf_gleam/native/rusty_vault_nif && cargo test
```
