# Journal: SIL-6 Mesh Ignition — Fractal TPS Root Cause Analysis
**Date**: 2026-04-17
**Version**: v22.6.1-DHARMA
**Session**: Ignition boot sequence debugging + full fractal RCA

---

## 1. Scope & Trigger

Full system boot via `./sa-up` and `ignition full` revealed that post-launch verification fails at 11/17 checks with `NonCompliant` verdict. 1,457 error log lines, 3 GenServer crashes, 7/28 inter-container connectivity. The Gleam UI (port 4100) was healthy throughout — failures were entirely in the Elixir app layer (port 4000).

---

## 2. Pre-State Assessment

- 16 containers configured in 5-wave DAG boot hierarchy
- Images 2 weeks old (built 2026-03-31 to 2026-04-02)
- PostgreSQL uses anonymous volume (no named volume)
- ex-app-1 runs in dev mode (`mix phx.server`, not compiled release)
- Preflight has 21 checks (6 critical + 15 extended)

---

## 3. Execution Detail

### Sequence of Events

| Time | Event | Result |
|------|-------|--------|
| 02:51:02 | `ignition preflight` (standalone) | Created `indrajaal_prod` DB |
| 02:54:03 | `ignition full` → preflight | Confirms `indrajaal_prod` exists |
| 02:54:26 | `ignition full` → launch Wave 1 | **`force_remove()` destroys db-prod** → new anonymous volume → blank PostgreSQL |
| 02:54:37 | launch Wave 3 → ex-app-1 starts | `mix ecto.migrate 2>/dev/null` fails silently (DB gone) |
| 02:54:38 | Postgrex pool error-loops | "database indrajaal_prod does not exist" every 500ms |
| 02:54:44 | Ecto migration error | "Could not create schema migrations table" |
| 02:55:31 | Verify phase | V-2 (health), V-3 (UI), V-7, V-9, V-12, V-15 FAIL |
| 02:55:51 | Final verdict | **NonCompliant — 11/17 passed** |

---

## 4. Root Cause Analysis (5-Why)

```
WHY-1: Verification fails (11/17) with 136 errors
  ↓
WHY-2: ex-app-1 cannot connect to indrajaal_prod database
  ↓
WHY-3: indrajaal_prod does not exist at container boot time
  ↓
WHY-4: launch_generic() calls force_remove() + podman run → DESTROYS the DB container
        Preflight created indrajaal_prod at T=02:51:03
        Launch destroyed db-prod at T=02:54:26 → NEW anonymous volume → blank PostgreSQL
  ↓
WHY-5: No named volume for PostgreSQL data. Anonymous volume dies with container.
        db-prod entrypoint runs initdb on fresh /var/lib/postgresql/data → empty DB.
```

**Root cause: `launch.rs:450-451` calls `force_remove()` on ALL containers including `indrajaal-db-prod` before `podman run`, destroying the anonymous volume that preflight just provisioned.**

---

## 5. Fix Taxonomy

| # | Fix | Type | File | Line | RPN |
|---|-----|------|------|------|-----|
| 1 | Named volume for db-prod | Architecture | launch.rs | 450-470 | 1000 |
| 2 | Add `ecto.create` to app CMD | Logic | launch.rs | 49 | 180 |
| 3 | Add migrations to replica CMD | Logic | launch.rs | 524 | 240 |
| 4 | Stateful/stateless container categorization | Architecture | launch.rs | 450 | 500 |
| 5 | Fix PF-17 cortex binary path | Data | preflight.rs | 1115 | 30 |
| 6 | Use curl instead of nc for connectivity | Tooling | connectivity.rs | 240 | 100 |
| 7 | Remove `2>/dev/null` from ecto.migrate | Safety | launch.rs | 49 | 180 |
| 8 | Fix PF-15 release check | Data | preflight.rs | ~1072 | 30 |
| 9 | Add locales to NixOS image | Config | timescaledb-demo.nix | - | 10 |

---

## 6. Patterns & Anti-Patterns Discovered

### Anti-Patterns
- **Silent error suppression** (`2>/dev/null` on safety-critical migration) — Anti-Jidoka
- **Undifferentiated force_remove()** — treats stateful containers (DB) same as stateless (app)
- **Anonymous volumes for persistent data** — data loss on every `podman rm`
- **Dev mode in production containers** — `mix phx.server` instead of compiled release
- **Asymmetric CMD chains** — test CMD has `ecto.create` but prod CMD doesn't

### Patterns (Positive)
- **DAG-based boot ordering** — correct dependency resolution (DB before App)
- **ProofToken authentication** — cryptographic container identity
- **FPPS 5-method health consensus** — thorough multi-method verification
- **Rule engine gate at each wave** — `Proceed` only when tier healthy
- **45s stabilization wait** — allows container warm-up before verification

---

## 7. Verification Matrix

| Check | Before Fix | After Fix (Expected) |
|-------|-----------|---------------------|
| V-1 Container running | PASS | PASS |
| V-2 Health endpoint | FAIL | PASS |
| V-3 Web UI | FAIL | PASS |
| V-7 CepafPort | FAIL | PASS |
| V-9 Error rate | FAIL (136) | PASS (<5) |
| V-12 GenServer crashes | FAIL (3) | PASS (0) |
| V-15 Connectivity | FAIL (7/28) | PASS (24+/28) |
| V-16 Zenoh mesh | PASS | PASS |
| V-17 Partition | PASS | PASS |

---

## 8. Files Modified

None in this session (analysis only). Fixes to be implemented:

| File | Purpose | Lines Affected |
|------|---------|---------------|
| `native/ignition_daemon/src/launch.rs` | Named volume, CMD fixes, stateful guard | 49, 450-470, 524 |
| `native/ignition_daemon/src/preflight.rs` | PF-17 path, PF-15 check | 1115, ~1072 |
| `native/ignition_daemon/src/connectivity.rs` | curl-based probes | 240 |

---

## 9. Architectural Observations

1. **Preflight ↔ Launch contradiction**: Preflight provisions state that launch destroys. These two phases work at cross purposes. The architecture assumes containers persist between preflight and launch, but `force_remove()` violates this assumption.

2. **Container categorization needed**: The system treats all 16 containers identically in `force_remove()`. Stateful containers (db-prod) MUST be treated differently from stateless containers (app, zenoh, cortex).

3. **Dev mode vs Release mode**: The Elixir containers run `mix phx.server` (dev mode, compiles on boot) instead of a compiled OTP release. This adds 30-60s to boot time and creates the `cache_manifest.json` warning. A release build would eliminate this waste.

4. **Connectivity tooling gap**: NixOS-based containers lack `nc` (netcat). The connectivity matrix uses `nc -z` which fails with exit 127. Either install netcat in the NixOS derivation or switch probes to `curl`/`bash /dev/tcp`.

5. **ProofToken per-launch**: Each `ignition full` generates new proof tokens. Replicas that start after ex-app-1 get different tokens, causing ZenohSession auth failures ("ProofToken rejected: missing_proof_token").

---

## 10. Remaining Gaps

| Gap | Priority | Description |
|-----|----------|-------------|
| Named volume implementation | P0 | db-prod must survive container recreation |
| Migration idempotency | P0 | App CMD must handle fresh DB (create + migrate) |
| Replica migration coordination | P1 | Only one node should run migrations |
| Release builds | P2 | Eliminate dev-mode compilation on boot |
| Connectivity probe refactor | P1 | Replace nc with curl for NixOS compat |
| Verify phase DB checks | P1 | Add schema_migrations count to verification |

---

## 11. Metrics Summary

| Metric | Value |
|--------|-------|
| Containers launched | 16/16 |
| Verification score | 11/17 (NonCompliant) |
| Error log lines | 1,457 |
| GenServer crashes | 3 |
| Connectivity matrix | 7/28 reachable |
| Total boot time (full) | 107,744ms (~108s) |
| Stabilization wait | 45,000ms |
| DB creation time (preflight) | ~1s |
| FMEA items RPN ≥ 200 | 2 (P0 immediate action) |

---

## 12. STAMP & Constitutional Alignment

| Invariant | Status | Evidence |
|-----------|--------|----------|
| Psi-0 (Existence) | DEGRADED | System runs but with 1,457 errors |
| Psi-1 (Regeneration) | VIOLATED | DB state not recoverable after force_remove |
| Psi-2 (Reversibility) | OK | git revert possible |
| Psi-3 (Verification) | PARTIAL | Verify phase catches issues but can't fix them |
| Psi-5 (Truthfulness) | VIOLATED | `2>/dev/null` hides migration failure |
| Omega-0 (Founder) | DEGRADED | System boots but not fully functional |

STAMP constraints violated: SC-FUNC-004, SC-SATYA-001, SC-BOOT-002, SC-SIL4-007, SC-OODA-001

---

## 13. Conclusion

The SIL-6 mesh ignition has a critical architectural flaw: `force_remove()` treats all containers identically, destroying PostgreSQL data on every `ignition full` run. Combined with the silent error suppression on `mix ecto.migrate` and missing `mix ecto.create` in the production CMD, this creates a cascade of 1,457 errors across all Elixir containers.

The fix is straightforward: named volume for db-prod, `ecto.create` in all CMDs, and stateful container guards in the launch sequence. The Gleam UI layer (port 4100) is fully healthy and unaffected — this is purely an Elixir/Phoenix app layer issue.

TPS verdict: **Anti-Jidoka** (silent error suppression) + **Poka-Yoke failure** (no guard on stateful containers) + **Muda Type 7** (1,457 defect log lines from single root cause).

---

## 14. Gleam Defense Gap Analysis (cepaf-gleam)

Investigation of whether the Gleam layer (`lib/cepaf_gleam/`) had code that could have prevented this scenario.

### What EXISTS (but didn't help)

| Module | Capability | Gap |
|--------|-----------|-----|
| `podman/containers.gleam` | `remove(client, name, force)` | **No stateful guard** — force-removes blindly |
| `podman/manager.gleam` | `purge_mesh()` | Calls `remove(force=True)` on ALL containers — no exceptions |
| `ha/freshness_monitor.gleam` | Staleness escalation (Fresh→Stale→Dead) | Only monitors data freshness, not data persistence |
| `ha/guard_rules.gleam` | 30 guard rules (GR-001 to GR-030) | No data-volume preservation rules |
| `podman/domain.gleam` | `ContainerSummary` has `mounts: List(Mount)` | Type exists but never checked before removal |
| `testing/flight_check.gleam` | Preflight checks | **Stubbed** — returns `CheckPassed` hardcoded |

### What's MISSING (would have prevented this)

1. **`is_stateful(container)` guard** — No function checks if a container has data volumes before `force_remove()`. The `Mount` type is in the domain but never used defensively.

2. **`verify_db_connectivity()` flight check** — No Gleam-side check that `indrajaal_prod` exists and has `schema_migrations`. The Rust ignition does this (PF-2) but the Gleam flight_check is stubbed.

3. **`GR-031: DataVolumePreservation`** guard rule — The 30 existing guard rules cover cascade, mode, Jidoka, but none say "NEVER force-remove a container with a named/anonymous data volume."

4. **Volume-container correlation** — `podman/volumes.gleam` can list/inspect volumes, but nothing correlates "this volume belongs to db-prod, so protect it."

### Rust-Gleam Split Observation

The Rust ignition daemon (`launch.rs`) duplicated container removal logic (`force_remove()`) without leveraging the Gleam guard rule engine. Per SC-ARCH-SPLIT, operational logic belongs in Rust — but the Gleam layer's guard rules (GR-001..030) define the SAFETY POLICY. The Rust daemon should consult the Gleam guard rules (via NIF or Zenoh) before destructive container operations.

**Architectural gap**: No feedback loop from Gleam safety policy → Rust operational execution for container lifecycle management.

### Recommended New Guard Rules

| ID | Rule | Layer | Salience |
|----|------|-------|----------|
| GR-031 | DataVolumePreservation: NEVER force-remove containers with data volumes unless explicitly requested | L0 | 100 |
| GR-032 | MigrationVerification: Verify schema_migrations table exists before declaring DB healthy | L3 | 80 |
| GR-033 | StatefulContainerGuard: Containers tagged `stateful` require named volumes and skip force-remove | L4 | 90 |

### Files to Modify

| File | Change |
|------|--------|
| `podman/containers.gleam` | Add `is_stateful()` check before `remove(force=True)` |
| `podman/manager.gleam` | Guard `purge_mesh()` to skip stateful containers |
| `ha/guard_rules.gleam` | Add GR-031, GR-032, GR-033 |
| `testing/flight_check.gleam` | Implement real preflight checks (unstub) |
| `podman/domain.gleam` | Add `stateful: Bool` field to `ContainerSummary` |

---

## 15. Rule Engine & Ruliology Gap Analysis — Why This Wasn't Caught

### The Systemic Blindspot

Both systems — the 52-rule RETE-UL engine (13 domains) and the Wolfram cellular automata — are designed for **runtime health monitoring**, not **deployment lifecycle safety**. They observe the system *after it's running* and never question *how it got there*.

The rule engine is consulted at **exactly ONE point** in launch:
```
launch.rs:580 → evaluate_launch_tier() — ONLY at wave boundaries
```

The 6 calls to `force_remove()` (lines 187, 246, 315, 372, 450, 609) happen **before** any rule evaluation. The rule engine is a post-hoc judge, not a pre-hoc guardian.

### What Each System Covers vs What's Missing

**RETE-UL Rule Engine (52 rules, 13 domains):**

| Domain | Rules | Covers | Gap |
|--------|-------|--------|-----|
| Decision | 7 | Runtime health → action | No pre-destruction check |
| Preflight | 4 | Pre-boot gates | No "is data safe to destroy?" |
| Recovery | 6 | Post-failure playbooks | Reaction only, no prevention |
| Cascade | 3 | Failure propagation | No data loss propagation |
| **Partition** | **3** | **"PreserveData" when DB in minority** | **Only for network splits, not container lifecycle** |
| Launch | 3 | Wave-level go/no-go | No per-container safety check |
| Verify | 3 | Post-launch compliance | Detects problem *after* it happened |

**Irony**: A "PreserveData" rule EXISTS (partition domain, salience 90) — but only fires for network partition scenarios (split-brain). It doesn't fire for the simpler case: "you're about to delete the data volume."

**Ruliology (Wolfram Cellular Automata):**

The `container_lifecycle_automaton()` has 5 states: `Created → Running → Healthy → Degraded → Stopped`. Its transition table has `(Healthy, kill) → Stopped` but **no concept of data persistence**. There's no `DataLost` state or `force_remove_with_volume` input. It doesn't distinguish stateless containers (safe to kill) from stateful containers (destructive to kill).

**Gleam Guard Rules (GR-001..030):**

All 30 rules focus on fractal layer health, cascade detection, cockpit mode, and Jidoka halt. None address container lifecycle or data persistence. GR-008 `IsolateFailingL4` isolates L4 cells but doesn't prevent data destruction. GR-003 `ConstitutionalThreat` halts on L0 violation but data loss isn't classified as L0.

### 3 Structural Reasons Why It Wasn't Caught

**1. Wrong abstraction level (抽象の誤り)**

The rule engine operates at the *logical* level (health scores, cascade depth, quorum counts). Data volume lifecycle operates at the *physical* level (filesystem mounts, anonymous vs named volumes). The physical layer is invisible to the rule engine — it has no facts about volumes, mounts, or data persistence.

**2. Observation-action gap (観察と行動の断絶)**

```
                OBSERVE              DECIDE              ACT
Rule engine:    health scores        evaluate_*()        (advisory only)
force_remove(): (no observation)     (no rules)          podman rm -f
                └──── GAP ───────────┴──── GAP ──────────┘
```

`force_remove()` is a raw `podman rm -f` that bypasses the entire OODA loop. It doesn't observe (check volumes), orient (classify stateful/stateless), decide (consult rules), or act through the rule engine. It's a **reflex arc** that short-circuits the cognitive system.

**3. Causal graph incompleteness (因果グラフの不完全性)**

`CausalGraph::pipeline_dag()` in ruliology.rs models the chat processing pipeline. There's no `ContainerLifecycleDAG` that models:
```
preflight_create_db → launch_force_remove → db_data_lost → app_migration_fail → cascade_errors
```
This causal chain was never formalized. The causal graph covers *steady-state* data flow, not *deployment* lifecycle.

### Corrective Extensions

**New RETE-UL Domain: `lifecycle` (4 rules)**

| Rule | Salience | Condition | Action |
|------|----------|-----------|--------|
| BlockStatefulRemove | 100 | HasDataVolume AND ForceRemove | Block — use named volume or skip |
| WarnAnonymousVolume | 90 | HasDataVolume AND NOT NamedVolume | Warn — create named volume first |
| AllowStatelessRemove | 50 | NOT HasDataVolume | Allow |
| AllowNamedVolumeRemove | 40 | HasDataVolume AND NamedVolume | Allow — data persists |

**New Automaton: `stateful_container_lifecycle`**

Extends the 5-state container automaton with 2 new states:
- `DataPreserved` — container removed but data survives (named volume or graceful drain)
- `DataLost` — **terminal absorbing state** — anonymous volume destroyed, cannot recover

Key transitions:
- `(Healthy, force_remove_named) → DataPreserved` (safe)
- `(Healthy, force_remove_anonymous) → DataLost` (DESTRUCTIVE)
- `(DataLost, start) → DataLost` (absorbing — restarting can't recover lost data)

**New Causal Graph: `ContainerLifecycleDAG`**

Models the deployment lifecycle causal chain:
```
preflight_create_db → db_ready
launch_force_remove → volume_destroyed → db_empty → ecto_migrate_fail
                                                   → oban_crash
                                                   → postgrex_loop → error_cascade → verify_fail
```

`causal_cone("verify_fail")` traces back through the entire chain to `launch_force_remove`.

**Integration Point — launch.rs**

Every `force_remove()` call MUST pass through rule evaluation:
```rust
// BEFORE: Raw reflex arc
if podman::container_exists(name).await {
    podman::force_remove(name).await?;
}

// AFTER: Rule-gated destruction
if podman::container_exists(name).await {
    let has_volume = podman::has_data_volume(name).await;
    let named = podman::has_named_volume(name).await;
    let rule = rule_engine::evaluate_lifecycle(has_volume, named, true);
    match rule.decision.as_str() {
        "Block" => warn!("⛔ Blocked: {} — {}", name, rule.reason),
        "Warn" => { /* create named volume first, then remove */ }
        _ => podman::force_remove(name).await?,
    }
}
```

### TPS Principle Applied

**Genchi Genbutsu (現地現物)** — the rule engine never "goes and sees" the physical state (volumes, mounts) before deciding. It makes decisions based on logical abstractions (health scores) that are blind to the physical reality.

**Poka-Yoke (ポカヨケ)** — every destructive operation should be error-proofed by a rule gate. The `force_remove()` call is the system's most destructive operation and has zero error-proofing.

**Andon (アンドン)** — the causal graph should light up the `DataLost` absorbing state as a red signal BEFORE the transition happens, not after verification detects the cascade.
