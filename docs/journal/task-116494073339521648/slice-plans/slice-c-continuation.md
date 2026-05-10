# Slice C continuation — wire KEK chain (TPM 2.0 / argon2id passphrase / Cloud KMS DR)

**sa-plan**: 116494259021299827 (P1)
**Depends on**: Slice B (NIF unseal accepts master key bytes). ⏳
**Unblocks**: production deployment (vault can boot unattended on TPM-equipped hosts)
**Effort estimate**: 1-2 sessions
**Critical-path RPN**: 160

ZK: [zk-7c757e50a894be8b] hardware-backed sovereignty target · [zk-92800ef179f24206] KMS L0 + version vectors

---

## 1. What's already shipped (Slice C skeleton, Pass-3)

| Artefact | Status | LOC |
|---|---|---:|
| `lib/cepaf_gleam/src/cepaf_gleam/vault_supervisor.gleam` | ✅ skeleton | 160 |
| `KekSource`, `UnsealAttempt`, `ChainResult`, `SupervisorConfig`, `OptionBytes` types | ✅ | — |
| `boot/2` chain orchestrator (TPM → passphrase → KMS) | ✅ types only | — |
| 3 stub fns (`attempt_tpm_unseal`, `attempt_passphrase_unseal`, `attempt_kms_unseal`) | ✅ stubs | — |
| Wiring guard +3 tests | ✅ | — |

**What's stubbed**: all 3 source functions return `NoneBytes`; chain always falls through to "all paths failed".

---

## 2. Three KEK source bindings

### C.1 — TPM 2.0 PCR 7 unseal via tss-esapi

**Crate**: `tss-esapi = "8.0"` (Mozilla TPM 2.0 binding) — pure Rust, FIPS-aligned.

**Provisioning** (one-shot, operator-driven via `sa-plan vault re-seal-tpm`):
```rust
use tss_esapi::{
    Context, Tcti,
    structures::{PcrSelectionList, PcrSlot, SymmetricDefinition},
    interface_types::algorithm::HashingAlgorithm,
};

fn provision_tpm_seal(master_key: &[u8; 32]) -> Result<Vec<u8>, TpmError> {
    let mut ctx = Context::new(Tcti::Device(Default::default()))?;

    // Build PCR 7 selection (Secure Boot policy)
    let pcr_selection = PcrSelectionList::builder()
        .with_selection(HashingAlgorithm::Sha256, &[PcrSlot::Slot7])
        .build()?;

    // Read current PCR 7 value to capture in policy
    let (_, _, pcr_data) = ctx.pcr_read(pcr_selection.clone())?;

    // Create primary key, derive seal child key bound to PCR 7 policy
    let primary = ctx.create_primary(...)?;
    let seal_child = ctx.create_with_policy(primary, master_key, pcr_data)?;

    // Persist to NV index, return ciphertext for /var/lib/c3i/smriti_kek.sealed
    Ok(seal_child.private)
}
```

**Unseal** (every boot):
```rust
fn attempt_tpm_unseal(sealed_path: &Path) -> Option<Zeroizing<Vec<u8>>> {
    if !Path::new("/dev/tpm0").exists() {
        return None;
    }
    let mut ctx = Context::new(Tcti::Device(Default::default())).ok()?;
    let ciphertext = std::fs::read(sealed_path).ok()?;

    // Reconstruct PCR 7 policy
    let pcr_selection = PcrSelectionList::builder()
        .with_selection(HashingAlgorithm::Sha256, &[PcrSlot::Slot7])
        .build().ok()?;

    let plaintext = ctx.unseal_with_policy(ciphertext, pcr_selection).ok()?;
    Some(Zeroizing::new(plaintext.to_vec()))
}
```

**Failure mode**: PCR 7 changed (kernel update) → unseal fails → fall to passphrase. Operator runs `sa-plan vault re-seal-tpm` after kernel updates to re-bind.

**LOC**: ~120 Rust in new `lib/cepaf_gleam/native/rusty_vault_nif/src/kek_tpm.rs`.

### C.2 — Operator passphrase via argon2id

**Crate**: `argon2 = "0.5"` (RustCrypto, pure Rust, FIPS-pending).

```rust
use argon2::{Argon2, Algorithm, Version, Params};
use zeroize::Zeroizing;

fn attempt_passphrase_unseal(passphrase: &str, salt_path: &Path) -> Option<Zeroizing<Vec<u8>>> {
    let salt = std::fs::read(salt_path).ok()?;
    if salt.len() != 32 { return None; }

    // SC-VAULT-021: argon2id(memory=64MB, t=3, p=4)
    let params = Params::new(64 * 1024, 3, 4, Some(32)).ok()?;
    let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);

    let mut output = Zeroizing::new(vec![0u8; 32]);
    argon2.hash_password_into(passphrase.as_bytes(), &salt, &mut output).ok()?;
    Some(output)
}
```

**Provisioning**:
- Operator types passphrase once during `sa-plan vault init`
- Random 32-byte salt written to `smriti_kek_salt.bin` (mode 0600)
- Passphrase NEVER persisted (argon2 derive happens fresh each boot)

**Failure mode**: wrong passphrase → derived key is wrong → vault.unseal returns WrongKey → fall through to KMS.

**Operator UX**: at boot, the supervisor reads passphrase from `C3I_VAULT_PASSPHRASE` env (set via systemd-creds or operator interactive prompt). Production: bind via `tpm2-totp`-like or interactive `--unattended=false` mode.

**LOC**: ~80 Rust in `kek_passphrase.rs`.

### C.3 — Cloud KMS DR fallback via reqwest

**Pattern**: reuse `backup.rs` ADC auth.

```rust
use serde_json::json;

async fn attempt_kms_unseal(ciphertext_path: &Path) -> Option<Zeroizing<Vec<u8>>> {
    // Probe network: 200ms timeout; fail fast if offline
    if !network_reachable("cloudkms.googleapis.com:443", Duration::from_millis(200)).await {
        return None;
    }

    let ciphertext = std::fs::read(ciphertext_path).ok()?;
    let token = adc_token().await.ok()?;

    let url = format!(
        "https://cloudkms.googleapis.com/v1/projects/{project}/locations/europe-north1/keyRings/c3i-secrets-dr/cryptoKeys/kek-cmek:decrypt",
        project = "durable-limiter-457011-u7"
    );

    let body = json!({"ciphertext": base64::encode(&ciphertext)});
    let resp = reqwest::Client::new()
        .post(&url)
        .bearer_auth(token)
        .json(&body)
        .timeout(Duration::from_secs(5))
        .send().await.ok()?;

    let plaintext_b64 = resp.json::<serde_json::Value>().await.ok()?
        .get("plaintext")?.as_str()?.to_string();
    let plaintext = base64::decode(&plaintext_b64).ok()?;
    Some(Zeroizing::new(plaintext))
}
```

**Provisioning**:
- One-shot: encrypt master key with CMEK at vault init, store ciphertext on disk + `gs://c3i-backups/kek-cloud-sealed.bin`
- IAM: service account needs `roles/cloudkms.cryptoKeyEncrypterDecrypter` on `c3i-secrets-dr` keyring (separate from Secret Manager keyring per SC-VAULT-019)

**Failure mode**: network unreachable, IAM revoked, KMS quota → returns None → halt vault (no further fallback).

**LOC**: ~100 Rust in `kek_kms.rs`.

---

## 3. Wiring into the NIF + Gleam supervisor

### C.4 — NIF surface for KEK chain (~80 LOC Rust)

Add 1 new NIF: `vault_unseal_with_chain(handle, config_json) -> {ok, source_atom} | {error, reason}` which internally:
1. Tries TPM (kek_tpm::attempt_tpm_unseal)
2. Falls to passphrase (kek_passphrase::attempt_passphrase_unseal)
3. Falls to KMS (kek_kms::attempt_kms_unseal — async, run inside tokio runtime)
4. Calls existing `vault_unseal` with whichever master key succeeded
5. Logs every attempt to immutable register

### C.5 — Wire `vault_supervisor.gleam` stubs to NIF (~80 LOC Gleam)

Replace 3 stub bodies with calls to `vault_unseal_with_chain`:
```gleam
fn attempt_tpm_unseal(path, attempts) {
  // Single NIF call returns chain result; we just decode source atom
  case rusty_vault_nif.vault_unseal_with_chain(handle, json_config) {
    #(Ok, "tpm") -> #(SomeBytes(<<>>), [Attempted(Tpm, True, "ok"), ..attempts])
    #(Ok, _) -> #(NoneBytes, attempts)  // chain succeeded but at later step
    #(Error, reason) -> #(NoneBytes, [Attempted(Tpm, False, reason), ..attempts])
  }
}
```

Or simpler: collapse the 3 stubs into a single Gleam call that invokes the NIF chain orchestrator and returns ChainResult directly.

### C.6 — Provisioning script (~120 LOC Gleam, per SC-SCRIPT-GLEAM-001)

`sub-projects/scripts-gleam/src/scripts/vault/provision.gleam`:
- `gleam run -m scripts/vault/provision -- --tpm` → seal master key with TPM PCR 7
- `gleam run -m scripts/vault/provision -- --passphrase` → derive salt, store, prompt operator
- `gleam run -m scripts/vault/provision -- --kms-dr` → encrypt master with Cloud KMS, upload ciphertext

CLI dispatch via `sa-plan vault init` → calls `gleam run -m scripts/vault/provision`.

### C.7 — Re-seal-tpm CLI for kernel-update remediation (~40 LOC Gleam)

Operator runs `sa-plan vault re-seal-tpm` after kernel updates. Re-binds master key to current PCR 7 value. SC-VAULT-023: operator-gated, no automation.

---

## 4. Test plan additions

| Test | Scope | File |
|---|---|---|
| `tpm_unseal_with_correct_pcr_succeeds` | unit | `tests/kek_tpm_test.rs` |
| `tpm_unseal_with_wrong_pcr_fails` | unit | same |
| `tpm_unseal_with_no_tpm_returns_none` | unit | same |
| `passphrase_correct_derives_master` | unit | `tests/kek_passphrase_test.rs` |
| `passphrase_wrong_derives_different_key` | unit (negative) | same |
| `kms_unseal_with_valid_token_succeeds` | integration (mock GCP) | `tests/kek_kms_test.rs` |
| `kms_unseal_offline_returns_none_fast` | integration (200ms) | same |
| `chain_tpm_first_then_falls_to_passphrase` | integration | `test/vault_kek_chain_test.gleam` |
| `chain_all_fail_returns_chain_failed` | integration | same |
| `re_seal_tpm_after_kernel_update` | E2E | manual playbook |

---

## 5. Files to create / modify

| File | Action | LOC |
|---|---|---:|
| `lib/cepaf_gleam/native/rusty_vault_nif/src/kek_tpm.rs` | new | +120 |
| `lib/cepaf_gleam/native/rusty_vault_nif/src/kek_passphrase.rs` | new | +80 |
| `lib/cepaf_gleam/native/rusty_vault_nif/src/kek_kms.rs` | new (async tokio) | +100 |
| `lib/cepaf_gleam/native/rusty_vault_nif/src/lib.rs` | edit (+vault_unseal_with_chain) | +80 |
| `lib/cepaf_gleam/native/rusty_vault_nif/Cargo.toml` | edit (+tss-esapi, +argon2, +tokio rt-multi-thread) | +6 |
| `lib/cepaf_gleam/src/cepaf_gleam/vault_supervisor.gleam` | edit (wire stubs to NIF) | +80 |
| `sub-projects/scripts-gleam/src/scripts/vault/provision.gleam` | new | +120 |
| `sub-projects/scripts-gleam/src/scripts/vault/re_seal_tpm.gleam` | new | +40 |
| `lib/cepaf_gleam/native/rusty_vault_nif/tests/kek_*.rs` | new (4 files) | +180 |
| `lib/cepaf_gleam/test/vault_kek_chain_test.gleam` | new | +80 |
| `sub-projects/c3i/native/planning_daemon/src/cli.rs` | edit (+vault subcommands) | +60 |

**Total**: ~946 LOC.

---

## 6. Verification gates

```bash
# Unit
cargo test --test kek_tpm_test --test kek_passphrase_test --test kek_kms_test

# Integration with mock GCP
cd lib/cepaf_gleam && gleam test -- --module vault_kek_chain_test

# E2E provisioning
gleam run -m scripts/vault/provision -- --passphrase
sa-plan vault status                    # should show unsealed via passphrase

# Network-down simulation
sudo iptables -A OUTPUT -d cloudkms.googleapis.com -j DROP
sa-plan vault status                    # KMS path failed; TPM/passphrase still works
sudo iptables -D OUTPUT -d cloudkms.googleapis.com -j DROP
```

Closure criteria:
- ✅ At least one of 3 KEK paths unseals successfully on a real boot
- ✅ Wrong-passphrase test fails closed (no fall-through to wrong key)
- ✅ TPM PCR mismatch falls to passphrase, not to "halt"
- ✅ All 3 paths offline → `ChainFailed` + P0 alarm
- ✅ Audit log records every attempt (success and failure)

---

## 7. Risks + mitigations

| Risk | Mitigation |
|---|---|
| `tss-esapi` requires libtss2-dev system package | document in devenv.nix as buildInput; CI `apt-get install libtss2-dev` |
| Operator forgets passphrase during outage | operator MUST set passphrase OR Cloud KMS DR; documented as gate in §6 closure |
| TPM PCR change → automated boot fails after kernel update | `re_seal_tpm` cron warns weekly when PCR changed but vault unattended-boot OK; operator acts |
| Cloud KMS DR keyring deleted by mistake | gs://c3i-backups also stores ciphertext — restore path documented |
| Race between async KMS call and supervisor timeout | 5s timeout on KMS POST; fall to halt if exceeded |

---

## 8. Cross-references
- TLA+ `BootUnsealsKEK` invariant — exactly verified by C.1-C.3 chain
- Agda `KekValid → vault.unseal succeeds` — C.5 wires this proof to runtime
- RETE-UL `VaultUnsealAttemptFailed` rule (sal 100) — fires when chain returns `ChainFailed`
- Allium `KekChain` contract — all 3 sources implement
