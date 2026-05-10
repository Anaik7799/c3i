# Slice F — Closure: 7-phase test execution + dashboard tile + governance

**sa-plan**: 116494259028115525 (P0)
**Depends on**: Slices A-E. ⏳
**Effort estimate**: 1-2 sessions (mostly running existing harness + closure verification)
**Critical-path RPN**: 168

ZK: [zk-bd82645aedcb5ef4] no Stub-That-Lies (every claimed test pass MUST verify against real evidence)

---

## 1. Already shipped (governance + skeleton)

| Artefact | Pass | Status |
|---|---:|---|
| 7-phase test plan (README + 7 phase docs) | 1 | ✅ |
| TLA+ + Agda + Allium specs | 3 | ✅ written |
| 25 SC-VAULT + 1 SC-VAULT-CRYPTO + 15 AOR-VAULT registered | 1-3 | ✅ |
| 12 RETE-UL rules in 2 domains | 3 | ✅ |
| Pre-commit hook ARMED | 3 | ✅ |
| 4 Oban schedules + 4 cron-referenced gleam scripts | 3-4 | ✅ |
| Wiring guard 24+ tests | 1-4 | ✅ |
| 12 graphviz diagrams + journal + RCA + TPS + fractal matrix | 1 | ✅ |

**What's left**: actually run all 7 phases, build the cockpit dashboard tile, and produce the formal-proofs-passing evidence.

---

## 2. Phase 1-7 execution (per `test-plan/README.md`)

### F.1 — Phase 1 unit tests run (after Slice B/C/D/E)

```bash
cd lib/cepaf_gleam/native/rusty_vault_nif && cargo test --release
cd lib/cepaf_gleam && gleam test -- --module vault_test
cd lib/cepaf_gleam && gleam test -- --module vault_supervisor_test
cd lib/cepaf_gleam && gleam test -- --module vault_sync_actor_test
cd lib/cepaf_gleam && gleam test -- --module secret_api_test
```

**Closure**: 200+ tests pass; H ≥ 2.5 bits; CCM ≥ 0.90; ITQS ≥ 0.85.

### F.2 — Phase 2 integration tests (~50 tests)

```bash
cd lib/cepaf_gleam && gleam test -- --module vault_integration_test
cd lib/cepaf_gleam && gleam test -- --module vault_kek_chain_test
cd lib/cepaf_gleam && gleam test -- --module vault_gcp_mock_test
cd lib/cepaf_gleam && gleam test -- --module secret_api_e2e_test
```

### F.3 — Phase 3 property-based (5 properties × 1000 cases)

```bash
cd lib/cepaf_gleam && gleam test -- --module vault_property_test
# Counter-example budget: 0
```

### F.4 — Phase 4 formal verification

**TLA+**:
```bash
tlc -config specs/tla/RustyVaultIntegration.cfg specs/tla/RustyVaultIntegration.tla
# Expected: "Model checking completed. No error has been found."
```

**Apalache**:
```bash
apalache-mc check --inv NoPlaintextAtRest specs/tla/RustyVaultIntegration.tla
apalache-mc check --inv BootUnsealsKEK specs/tla/RustyVaultIntegration.tla
apalache-mc check --inv VersionMonotonic specs/tla/RustyVaultIntegration.tla
apalache-mc check --inv LeaseExpiryEnforced specs/tla/RustyVaultIntegration.tla
```

**Agda**:
```bash
agda --safe specs/agda/VaultStateMachine.agda
# Empty output = type-checks
```

**Allium tend** (when allium toolchain available):
```bash
allium tend specs/allium/secrets_vault.allium
```

### F.5 — Phase 5 E2E 1-week offline simulation (the killer test)

Per `test-plan/phase-5-e2e-offline.md`. Use FreezeGun-style time advance via injectable clock:

```bash
sudo iptables -A OUTPUT -d secretmanager.googleapis.com -j DROP
sudo iptables -A OUTPUT -d cloudkms.googleapis.com -j DROP

# Run offline simulation harness
gleam run -m scripts/test/vault_offline_sim -- --advance-days 7

# Verify all 8 expected outcomes (per phase-5-e2e-offline.md table)
sudo iptables -D OUTPUT -d secretmanager.googleapis.com -j DROP
sudo iptables -D OUTPUT -d cloudkms.googleapis.com -j DROP
```

**Per-secret per-TTL verification table** (must match phase-5 doc):
- 5min/7d secrets fail-closed at t=7d+ε ✓
- 30d/90d secrets remain fresh past t=7d ✓

### F.6 — Phase 6 chaos (8 scenarios)

Drive via `immune-chaos-agent` (Mara) with new vault scenarios added to its rotation. Weekly Sunday 05:00 UTC cron picks 1 random scenario.

```bash
sa-plan-daemon schedule-add \
  --name vault_chaos_drill \
  --cron "0 5 * * 0" \
  --worker mara_agent \
  --module vault_chaos_drill \
  --priority 70 \
  --max-attempts 1
```

Implement `mara_agent/src/vault_chaos.rs` (8 scenarios per phase-6-chaos.md).

### F.7 — Phase 7 UX (Playwright, 4 flows × 3 platforms = 12 runs)

```bash
cd tests/playwright && npx playwright test vault.spec.ts --project=chromium
cd tests/playwright && npx playwright test vault.spec.ts --project=firefox
cd tests/playwright && npx playwright test vault.spec.ts --project=mobile-chromium
```

Screenshots → `docs/journal/task-116494073339521648/screenshots/flow-{a,b,c,d}-{green,amber,red}.png`.

---

## 3. Cockpit dashboard tile (Andon)

**sa-plan task**: 116494259716793828 (Andon dashboard tile, 30s refresh)

### F.8 — Lustre page `ui/lustre/secrets_vault.gleam` (~150 LOC)

Per **SC-AGUI-UI-008** (30s refresh) + Andon escalation thresholds:

```gleam
pub type Model {
  Model(
    vault_state: String,
    last_sync_age: Int,
    counts: Counts,
    per_secret: List(SecretStatus),
    dashboard_color: String,
  )
}

pub fn init(_ctx) -> Model {
  Model(vault_state: "Sealed", last_sync_age: 0,
        counts: Counts(0, 0, 0), per_secret: [],
        dashboard_color: "amber")
}

pub type Msg {
  Tick
  StatusReceived(json: String)
}

pub fn update(model, msg) -> #(Model, Effect(Msg)) {
  case msg {
    Tick -> #(model, fetch_status_effect())
    StatusReceived(json) -> #(parse_status(json), effect.none())
  }
}

pub fn view(model: Model) -> Element(Msg) {
  div([class("vault-tile-" <> model.dashboard_color)], [
    h2([], [text("Secrets Vault")]),
    div([class("vault-state")], [text("State: " <> model.vault_state)]),
    div([class("sync-age")], [text("Last sync: " <> int.to_string(model.last_sync_age) <> "s ago")]),
    counts_widget(model.counts),
    per_secret_list(model.per_secret),
  ])
}
```

### F.9 — Wisp endpoint to feed the tile

Already exists: `GET /api/v1/secret-status` (Slice E secret_api.gleam). Lustre page polls every 30s.

### F.10 — TUI view `ui/tui/secrets_vault_view.gleam` (~80 LOC)

Triple-interface mandate (SC-GLM-UI-001) requires TUI counterpart:
```
╔═════ Secrets Vault Status ═════════════════════════════ 30s ago ═╗
║                                                                  ║
║  Vault state: ● ACTIVE (unsealed 14h ago via TPM)               ║
║                                                                  ║
║  Per-secret freshness:                                           ║
║    ● anthropic_api_key       fresh (3m ago)                     ║
║    ● openrouter_api_key      fresh (3m ago)                     ║
║    ● ...                                                         ║
║                                                                  ║
║  Last GCP sync: 2m 14s ago (success)                            ║
║  Cloud Audit reconcile: 3h ago (in sync)                        ║
║  Tongsuo absence: ✓ verified at last build                      ║
║                                                                  ║
╚═══════════════════════════════════════════════════════════════════╝
```

---

## 4. Cloud Audit reconciliation cron

**sa-plan task**: 116494259714520936

`sub-projects/scripts-gleam/src/scripts/verify/vault_audit_reconcile.gleam` already stubbed (Pass-4). Activate body:

```gleam
pub fn main() {
  // 1. gcloud logging read for last 24h
  let cloud_audit = exec_gcloud("logging read 'resource.type=\"secretmanager.googleapis.com\"' --freshness=24h --format=json")
  // 2. vault_audit_tail NIF for same window
  let local_audit = vault.audit_tail(get_handle(), now_seconds() - 86400)
  // 3. Set diff
  let cloud_set = build_set(cloud_audit)
  let local_set = build_set(local_audit)
  let cloud_only = set.difference(cloud_set, local_set)
  let local_only = set.difference(local_set, cloud_set)
  // 4. Emit P1 alerts if non-empty
  case set.size(cloud_only) {
    0 -> Nil
    _ -> open_p1_task("Cloud Audit shows access bypassing daemon", cloud_only)
  }
  // 5. Publish reconciliation report
  publish_zenoh("indrajaal/l4/sync/vault/audit_reconcile/<run>", report)
}
```

---

## 5. Closure email + ZK ingest

After all 7 phases pass:

```bash
sa-plan send-email \
  --to Abhijit.Naik@bountytek.com \
  --subject "Vault: Slice F closed — 7-phase tests + formal proofs + Andon tile + audit reconcile" \
  --body "..." \
  -a journal.md -a analysis.html -a deck.html \
  -a test-plan/README.md -a fractal-criticality-matrix.md \
  -a docs/journal/task-116494073339521648/slice-plans/

sa-plan ingest-docs

# Final task closures
sa-plan update 116494259028115525 completed   # Slice F
sa-plan update 116494073339521648 completed    # parent task
```

---

## 6. Files to create / modify (this slice)

| File | Action | LOC |
|---|---|---:|
| `lib/cepaf_gleam/src/cepaf_gleam/ui/lustre/secrets_vault.gleam` | new (Lustre tile) | +150 |
| `lib/cepaf_gleam/src/cepaf_gleam/ui/tui/secrets_vault_view.gleam` | new (TUI view) | +80 |
| `lib/cepaf_gleam/src/cepaf_gleam/ui/domain.gleam` | edit (+SecretsVault page enum) | +5 |
| `lib/cepaf_gleam/src/cepaf_gleam/ui/wisp/router.gleam` | edit (+/secrets-vault page route) | +5 |
| `sub-projects/scripts-gleam/src/scripts/verify/vault_audit_reconcile.gleam` | edit (wire body) | +120 |
| `sub-projects/scripts-gleam/src/scripts/verify/vault_kek_rotation_check.gleam` | edit (wire body) | +60 |
| `sub-projects/scripts-gleam/src/scripts/verify/vault_policy_audit.gleam` | edit (wire body) | +80 |
| `sub-projects/scripts-gleam/src/scripts/test/vault_offline_sim.gleam` | new (Phase 5 harness) | +180 |
| `sub-projects/c3i/native/planning_daemon/src/mara/vault_chaos.rs` | new (Phase 6 8 scenarios) | +250 |
| `tests/playwright/vault.spec.ts` | new (Phase 7 4 flows) | +220 |
| `lib/cepaf_gleam/test/vault_property_test.gleam` | new (Phase 3 5 properties) | +200 |
| `lib/cepaf_gleam/test/secret_api_e2e_test.gleam` | edit (Phase 2 fill-out) | +200 |

**Total**: ~1,550 LOC.

---

## 7. Verification gates

Closure criteria for entire vault evolution:
- ✅ Phase 1 unit: 200+ pass, H ≥ 2.5, CCM ≥ 0.90, ITQS ≥ 0.85
- ✅ Phase 2 integration: 0 failures
- ✅ Phase 3 property-based: 0 counter-examples in 5,000 generated cases
- ✅ Phase 4 formal: TLA+ + Apalache + Agda all green
- ✅ Phase 5 E2E offline: no fail-open at any TTL boundary
- ✅ Phase 6 chaos: 8/8 scenarios survive (graceful degradation OR correct fail-closed)
- ✅ Phase 7 UX: 4 flows × 3 platforms pass with screenshots + < 30s task completion
- ✅ Andon dashboard tile renders Lustre + TUI + Wisp endpoint feeds
- ✅ Cloud Audit reconciliation cron runs daily without P1 alarms
- ✅ All sa-plan vault tasks closed completed
- ✅ Email handoff sent + ZK ingest complete

---

## 8. Risks + mitigations

| Risk | Mitigation |
|---|---|
| Apalache install missing | document in devenv.nix; CI installs via `nix-env -iA apalache`. If unavailable, accept TLC-only |
| Agda type-checking fails on undefined operators | the `_⊎_` and `¬_` definitions in spec are added defensively; agda --safe verifies |
| Playwright E2E fragile | use `data-testid` attributes throughout Lustre tile; deterministic |
| 1-week offline simulation requires sudo iptables | document; offer alternative `tc qdisc` based fault injection in sandbox |
| Mara chaos drill might destabilize prod | weekly schedule + idempotent scenarios + dry-run flag for first run |

---

## 9. What ships at Slice F closure (the END state)

- Vault is **operational**: vault.put + vault.get + lease management + sync work end-to-end against real GCP
- Vault is **secure**: SC-VAULT-CRYPTO-001 verified; KEK chain works; SC-VAULT-001..025 enforced
- Vault is **observable**: dashboard tile + audit log + Cloud Audit reconcile + Zenoh per-access envelope
- Vault is **tested**: 7-phase coverage with formal proofs at every level
- Vault is **defended**: 7 TPS pillars in place (Jidoka pre-commit, Andon dashboard, Kaizen 5 crons, Heijunka fairshare, Poka-yoke wiring guard + poison pill, Genchi Genbutsu formal proofs, Standardized Work 8 canonical ops)
- Vault is **documented**: full doc pack + 5 slice plans + journal + RCA + TPS + criticality matrix
- The 8 leaked plaintext secrets are **migrated** to vault; `.pi/config.json` no longer has live key

The "1-week internet outage" hard requirement is **mechanically verified** by Phase 5 + the TLA+ `OfflineFreshness` invariant.

---

## 10. Cross-references
- All 5 slice plans (B-cont, C-cont, D-cont, E-cont, F): in `docs/journal/task-116494073339521648/slice-plans/`
- Plan: `/home/an/.claude/plans/deep-frolicking-wave.md`
- Task lineage: parent 116494073339521648 → 35+ subtasks across passes 1-5
- TLA+: `specs/tla/RustyVaultIntegration.tla` + .cfg
- Agda: `specs/agda/VaultStateMachine.agda`
- Allium: `specs/allium/secrets_vault.allium`
- Rule: `.claude/rules/secrets-vault.md` + `.gemini/` parity
- 12 PNG diagrams: `diagrams/png/01..12.png`
