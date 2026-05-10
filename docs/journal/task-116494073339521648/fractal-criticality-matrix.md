# Fractal Criticality Matrix — Secrets Vault (L0-L7 × 10 components)

Per **SC-FRAC-RRF-001..010**.

ZK: [zk-de13e287de7b9f74] reuse `ha/hsm_vault.gleam` · [zk-92800ef179f24206] KMS L0 · [zk-bd82645aedcb5ef4] no Stub-That-Lies

---

## Matrix legend

| Column | Meaning |
|---|---|
| State mgmt | What state machine governs this row |
| Health | What "healthy" looks like |
| Recovery | Recovery mechanism if it breaks |
| Boundary | Interface contract |
| P/C comm | How parent and child layers communicate |
| Zenoh+OTel | Topic / span family |
| AG-UI/A2UI | UI surface (if any) |
| STAMP refs | SC-* constraint family |
| RETE-UL | RETE rule(s) firing on this row |
| FMEA RPN | Risk priority before mitigation |

---

## L0 — Constitutional

| Component | State mgmt | Health | Recovery | Boundary | P/C comm | Zenoh+OTel | AG-UI/A2UI | STAMP refs | RETE-UL | FMEA RPN |
|---|---|---|---|---|---|---|---|---|---|---:|
| Guardian seal | sealed/unsealing/active/sealing/corrupt/halted FSM | unseal succeeded? | re-seal-tpm CLI | KEK chain interface | supervisor → vault | indrajaal/l0/const/seal/<phase> | Dashboard tile (top-bar) | SC-VAULT-001..002 | VaultSealedAtBoot | 504 |
| Ψ-2 reversibility | every state change → audit log | audit log gap < 5s after each NIF call | replay from audit | NIF emit on every call | NIF → audit_log.rs | indrajaal/l0/secret/access/<name> | Audit log viewer | SC-VAULT-008 | VaultAuditGap | 240 |

L0 ΣRPN = **744**

---

## L1 — Atomic / NIF

| Component | State mgmt | Health | Recovery | Boundary | P/C comm | Zenoh+OTel | AG-UI/A2UI | STAMP refs | RETE-UL | FMEA RPN |
|---|---|---|---|---|---|---|---|---|---|---:|
| rusty_vault_nif | RAII handle, dirty-IO scheduled | NIF doesn't panic; zeroize tracked | rustler restart | erlang term ↔ rust struct | erl_nif | indrajaal/l1/atomic/vault/<op> | — | SC-NIF-001..006, SC-VAULT-005 | — | 240 |
| zeroize crate | per-allocation guards | plaintext zeroed on drop | (compiler-enforced) | Drop trait | (compile-time) | — | — | SC-VAULT-002 | — | 120 |

L1 ΣRPN = **360**

---

## L2 — Component

| Component | State mgmt | Health | Recovery | Boundary | P/C comm | Zenoh+OTel | AG-UI/A2UI | STAMP refs | RETE-UL | FMEA RPN |
|---|---|---|---|---|---|---|---|---|---|---:|
| vault.gleam | Result(_, VaultError) | typed errors, exhaustive | retry on transient | gleam ↔ erl ↔ rust | gleam_otp | indrajaal/l2/comp/vault | — | SC-VAULT-003 | — | 120 |
| Wisp REST endpoint | OIDC gate | /api/v1/secret/<name> returns 200 only when authn ok | re-issue token | Bearer token | http | indrajaal/l2/web/secret_api | A2UI form | SC-AUTH-001..008 | — | 168 |

L2 ΣRPN = **288**

---

## L3 — Transaction

| Component | State mgmt | Health | Recovery | Boundary | P/C comm | Zenoh+OTel | AG-UI/A2UI | STAMP refs | RETE-UL | FMEA RPN |
|---|---|---|---|---|---|---|---|---|---|---:|
| K/V v2 versioning | monotonic version vector per name | version always > predecessor | (CRDT recovery via sync) | RustyVault::core::write_kv | NIF | indrajaal/l3/txn/vault/put | — | SC-VAULT-011 | — | 175 |
| smriti_vault.db | SQLite WAL + integrity_check | integrity check passes | restore from GCS snapshot | RustyVault::storage | NIF | — | — | SC-VAULT-012, SC-XHOLON-011..012 | VaultStorageCorrupt | 240 |
| Transit engine | per-secret AES-256-GCM | nonce never reused | (HKDF derive new) | RustyVault::transit | NIF | — | — | SC-VAULT-002 | — | 90 |

L3 ΣRPN = **505**

---

## L4 — System

| Component | State mgmt | Health | Recovery | Boundary | P/C comm | Zenoh+OTel | AG-UI/A2UI | STAMP refs | RETE-UL | FMEA RPN |
|---|---|---|---|---|---|---|---|---|---|---:|
| vault_sync_actor | OTP gen_server, idle/syncing/circuit-open | last sync < 10 min | exponential backoff, circuit reset | reqwest → GCP | gen_server | indrajaal/l4/sync/vault | sync status tile | SC-VAULT-010 | SecretSoftStale × Online | 168 |
| Cloud KMS DR fallback | only path 3 of unseal chain | KMS reachable at boot only | fall-through to halt | google-cloud-kms / reqwest | NIF | indrajaal/l4/system/kms_dr | — | SC-VAULT-007 | — | 105 |
| Slurm-style fairshare | tier 1-4 priority queue | queue depth < 100 | drop oldest in tier 4 | scripts_nif/fairshare.rs | NIF | indrajaal/l4/sched/fairshare | — | SC-RCPSP-001..010 | — | 60 |

L4 ΣRPN = **333**

---

## L5 — Cognitive

| Component | State mgmt | Health | Recovery | Boundary | P/C comm | Zenoh+OTel | AG-UI/A2UI | STAMP refs | RETE-UL | FMEA RPN |
|---|---|---|---|---|---|---|---|---|---|---:|
| OODA freshness rules (7) | RETE-UL working memory | rules fire in < 1 ms | (rule engine restart) | rules/engine.gleam | gen_server | indrajaal/l5/cog/freshness | dashboard freshness | SC-VAULT-013, SC-VAULT-014 | 7 rules in secret_freshness | 90 |
| hsm_vault.gleam policy | rotation policy decision | Allow/Deny/Reason | (policy fix in code) | gleam fn | gleam call | — | — | SC-KMS-001..023 | — | 60 |

L5 ΣRPN = **150**

---

## L6 — Ecosystem

| Component | State mgmt | Health | Recovery | Boundary | P/C comm | Zenoh+OTel | AG-UI/A2UI | STAMP refs | RETE-UL | FMEA RPN |
|---|---|---|---|---|---|---|---|---|---|---:|
| Version vector CRDT | per-secret VV | monotonic increment | (CRDT merge handles divergence) | sync layer | reqwest | indrajaal/l6/eco/vault/version | — | SC-XHOLON-007, SC-VAULT-011 | — | 105 |
| Mesh Zenoh fed | publish/subscribe | router reachable | reconnect with backoff | Zenoh client | NIF | indrajaal/l6/eco/vault/** | — | SC-ZENOH-001..008 | — | 81 |

L6 ΣRPN = **186**

---

## L7 — Federation

| Component | State mgmt | Health | Recovery | Boundary | P/C comm | Zenoh+OTel | AG-UI/A2UI | STAMP refs | RETE-UL | FMEA RPN |
|---|---|---|---|---|---|---|---|---|---|---:|
| Cloud KMS CMEK | europe-north1 keyring | key not revoked | re-encrypt with new key version | google-cloud-kms | reqwest | indrajaal/l7/fed/cmek | — | SC-VAULT-017, SC-VAULT-019 | — | 88 |
| GCP Secret Manager | versioned k→v | latest version readable | re-create secret if deleted | google-cloud-secretmanager | reqwest | indrajaal/l7/fed/secret_manager | — | SC-VAULT-017..018 | — | 88 |
| Cross-mesh attestation | Ed25519 signed leases | signature verifies, age < 1h | (federation protocol) | mesh fed gateway | Zenoh | indrajaal/l7/fed/vault/attest | — | SC-FED-006, SC-SMRITI-110 | — | 105 |

L7 ΣRPN = **281**

---

## Total

| Layer | ΣRPN | % of total |
|---|---:|---:|
| L0 | 744 | 25% |
| L1 | 360 | 12% |
| L2 | 288 | 10% |
| L3 | 505 | 17% |
| L4 | 333 | 11% |
| L5 | 150 | 5% |
| L6 | 186 | 6% |
| L7 | 281 | 9% |
| **Total ΣRPN** | **2,847** | 100% |

**Mitigation target post-Slice-F**: < 600 (79% reduction). Achieved by:
- Slice A scrub: −200 (Tongsuo risk eliminated)
- Slice B NIF: −400 (zeroize + RAII guards)
- Slice C KEK chain: −300 (3-path fallback)
- Slice D sync: −250 (circuit breaker + offline tolerance)
- Slice E caller flip: −500 (single canonical path)
- Slice F governance: −600 (formal proofs + 12 RETE-UL rules + pre-commit + wiring guard)

Total mitigation = **2,250 RPN reduction** → post-mitigation ΣRPN = **597** ✓

---

## Critical-path execution (RPN-descending)

Already in plan §18; reproduced here for cross-reference:

```
1. L0 Guardian seal (RPN 504) — Slice A + Slice C
2. L3 smriti_vault.db (RPN 240) — Slice B
3. L0 Ψ-2 reversibility (RPN 240) — Slice F
4. L1 rusty_vault_nif (RPN 240) — Slice B
5. L3 K/V v2 versioning (RPN 175) — Slice B
6. L2 Wisp REST (RPN 168) — Slice E
7. L4 sync_actor (RPN 168) — Slice D
8. L7 mesh attestation (RPN 105) — Slice F
9. L4 KMS DR (RPN 105) — Slice C
10. L6 version vector (RPN 105) — Slice D
[remaining 9 rows omitted for brevity]
```

---

## P0/P1 priority gating

Per **SC-FRAC-RRF-005..006**:

- **P0** (must include rollback + Guardian gate + FEMA response note): rows with RPN ≥ 300 → 4 rows (Guardian seal, smriti_vault.db, Ψ-2, NIF)
- **P1** (must include retry/backoff + ops runbook): rows with RPN 150-299 → 5 rows (K/V version, Wisp REST, sync_actor, transit engine, hsm_vault)
- **P2** (must include detection + mitigation test): rows with RPN < 150 → 11 rows
- **P3** (non-regression proof): N/A — all rows are functional

P0 rows are the **safety kernel** of the vault. They cannot regress without operator approval (SC-VAULT-023).

---

## Ruliological view

Treating the matrix as a Wolfram-style cellular automaton:

- **Rule 110**: layer-to-layer cascading. If L0 seals, L1-L7 all enter degraded; if L7 (GCP) is down, only L4 sync degrades.
- **Rule 30**: Σ(failure entropy across rows). Healthy steady-state = low entropy (most rows green); chaos = entropy spike → Rule 30 detector fires P0.
- **Rule 184**: traffic pattern across the matrix. Hot path is L0 → L1 → L2 → L3 (read). Cold path is L4 → L7 (sync). Loaded path is L5 → L0 (rule eval). Slurm fairshare ensures tiers don't starve.
- **Causal graph**: edges from this matrix form the basis of blast-radius analysis. A single L4 failure ripples to L6 (mesh consistency) but not to L0-L3 (hot path).

---

This matrix is a living artefact: any new component (e.g., HSM-backed transit DEK in tier-3 future) gets a new row added with its own STAMP/RETE/FMEA columns. The wiring guard test verifies every component has a row before it's allowed into the build (SC-FRAC-RRF-001).
