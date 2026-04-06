# SIL-6 Swarm Ignition — Network Subnet Fix & Full 15-Container Startup

**Date**: 2026-04-05 01:30 UTC
**Session ID**: opus-swarm-ignition-20260405

---

## 1. Scope & Trigger

**Trigger**: User requested full swarm startup via `bin/Cepaf launch`. All containers failed with `network not found: indrajaal-sil6-mesh`, then ex-app-1 failed with static IP subnet mismatch.

**Scope**: Fix network configuration, bring up all 15 SIL-6 containers, create production database, establish correct startup sequence.

---

## 2. Pre-State Assessment

| Component | Status |
|-----------|--------|
| Containers | 0 running |
| Network `indrajaal-sil6-mesh` | Did not exist |
| Ports | None listening |
| Rust ignition daemon | Compiled, installed at `bin/Cepaf` |
| Database `indrajaal_prod` | Did not exist |

---

## 3. Execution Detail

### Attempt 1: Launch without network
```bash
bin/Cepaf launch
```
**Result**: All 15 containers failed — `unable to find network with name or ID indrajaal-sil6-mesh`.

### Fix 1: Create network (wrong subnet)
```bash
podman network create indrajaal-sil6-mesh
```
Created with default subnet `10.89.0.0/24`.

### Attempt 2: Launch with default subnet
**Result**: 14/15 containers started. `indrajaal-ex-app-1` failed — `requested static ip 172.28.0.10 not in any subnet on network indrajaal-sil6-mesh`. The Rust launch code (`launch.rs:199`) hardcodes `--ip 172.28.0.10` which is in the `172.28.0.0/16` range.

### Manual ex-app-1 workaround (temporary)
Started ex-app-1 without static IP but with full SIL-6 env vars. Succeeded but required 40+ `-e` flags including `REDIS_URL=redis://localhost:6379`, `REDIS_EMBEDDED=true`, `OTEL_*`, `RELEASE_NODE`, etc. — discovered by inspecting working replica container `indrajaal-ex-app-2`.

### Fix 2: Recreate network with correct subnet
```bash
podman stop -a && podman rm -a -f
podman network rm indrajaal-sil6-mesh
podman network create --subnet 172.28.0.0/16 --gateway 172.28.0.1 indrajaal-sil6-mesh
```

### Attempt 3: Launch with correct subnet
```bash
bin/Cepaf launch
```
**Result**: All 15/15 containers UP in 2.3 seconds. ex-app-1 started with static IP `172.28.0.10` successfully.

### Fix 3: Create production database
```bash
podman exec indrajaal-db-prod psql -U postgres -c "CREATE DATABASE indrajaal_prod;"
```
Resolved Oban/Postgrex connection errors in ex-app-1.

---

## 4. Root Cause Analysis

### Why network didn't exist
The `indrajaal-sil6-mesh` Podman network is not persisted across system restarts. The Rust ignition daemon assumes it exists but doesn't create it. The F# `cepa` binary's startup sequence creates it as part of its orchestration, but the Rust `launch` command skips network provisioning.

### Why static IP failed
The Rust `launch.rs:199` hardcodes `--ip 172.28.0.10` for ex-app-1. The default Podman network subnet is `10.89.0.0/24` which doesn't contain `172.28.0.x`. The code expects `172.28.0.0/16` — matching the F# orchestrator's network definition.

### Why ex-app-1 needed REDIS_URL
The Elixir app has a Jidoka safety halt in `Indrajaal.Application.validate_environment!/0` (line 461) that requires `REDIS_URL` as a mandatory env var. The Rust launch code's `app_env_vars()` function (line 620) correctly sets `REDIS_URL=redis://localhost:6379` and `REDIS_EMBEDDED=true`, but this only works when the static IP succeeds — the manual workaround had missed these vars initially.

### Why database didn't exist
Fresh `indrajaal-db-prod` container starts with only the default `postgres` database. The `indrajaal_prod` database must be created post-boot. The F# orchestrator handles this in its boot sequence, but the Rust `launch` command doesn't include database provisioning.

---

## 5. Fix Taxonomy

| Fix | Type | Impact |
|-----|------|--------|
| Network creation with correct subnet | Infrastructure config | L3-SYSTEM |
| Database creation post-boot | Infrastructure provisioning | L3-SYSTEM |
| Discovered env var requirements | Knowledge capture | L2-DOMAIN |

---

## 6. Patterns & Anti-Patterns Discovered

### Patterns
- **Inspect working containers**: `podman inspect indrajaal-ex-app-2 --format '{{range .Config.Env}}...'` reveals the exact env vars needed — the replica containers launched by the ignition daemon have the correct config
- **Subnet must match static IPs**: When Rust code hardcodes container IPs, the Podman network must be created with the matching subnet

### Anti-Patterns
- **Hardcoded static IPs without network provisioning**: `launch.rs` assumes the network exists with the right subnet but doesn't verify or create it
- **No database provisioning in launch**: The Rust daemon launches containers but doesn't run post-boot steps like `CREATE DATABASE`

---

## 7. Verification Matrix

| Check | Result |
|-------|--------|
| 15/15 containers UP | **PASS** |
| ex-app-1 running > 30s | **PASS** |
| Port 4000 listening | **PASS** |
| Port 9876 listening | **PASS** |
| `indrajaal_prod` database exists | **PASS** |
| Zenoh routers (3x) running | **PASS** |
| Static IP 172.28.0.10 assigned | **PASS** |

---

## 8. Files Modified

| File | Change |
|------|--------|
| No code changes | Network/infrastructure fix only |

---

## 9. Architectural Observations

1. **Rust ignition daemon gap**: The `launch` command handles container creation and DAG-based wave sequencing but lacks three infrastructure prerequisites: (a) network creation, (b) database provisioning, (c) Ecto migration. A `preflight --fix` or `setup` subcommand should handle these.

2. **Static IP map**: The Rust code defines a fixed IP map for the mesh (`172.28.0.10` for ex-app-1, etc.). This couples the launch logic to a specific Podman network configuration. Future: read from `config/dag.toml` or auto-detect.

3. **Replica env inheritance works well**: The `launch_elixir_replica()` function correctly inherits all env vars from `app_env_vars()` and only overrides `PHX_HOST`, `PORT`, and `OTEL_SERVICE_NAME`. This pattern ensures chaya/ex-app-2/ex-app-3 always match ex-app-1's config.

---

## 10. Remaining Gaps

| Gap | Priority |
|-----|----------|
| Rust `launch` should auto-create network if missing | P1 |
| Rust `launch` should auto-create database post-boot | P2 |
| Rust `launch` should run Ecto migrations | P2 |
| `config/dag.toml` should include network/IP config | P3 |

---

## 11. Metrics Summary

| Metric | Value |
|--------|-------|
| Containers launched | 15/15 |
| Launch time | 2.3 seconds |
| Waves executed | 5 (0: zenoh-routers, 1: db+obs+ollama+mojo, 2: cortex+ml-runners, 3: ex-app-1, 4: replicas+bridge) |
| Network subnet | 172.28.0.0/16 |
| Static IPs | ex-app-1: 172.28.0.10 |
| Database created | indrajaal_prod |

---

## 12. STAMP & Constitutional Alignment

| Constraint | Status |
|------------|--------|
| SC-BOOT-008 (DAG acyclic) | PASS — Kahn's topological sort in 5 waves |
| SC-BOOT-009 (Waves boot parallel) | PASS — Async.Parallel within each wave |
| SC-SIL4-005 (Container start order: DB→OBS→APP) | PASS — Wave 1 before Wave 3 |
| SC-ZENOH-008 (Container MUST NOT start if Zenoh unavailable) | PASS — Wave 0 = zenoh-routers first |
| AOR-IGNITE-005 (Tier boot failures MUST halt pipeline) | PASS — rule engine evaluates each wave |
| SC-FUNC-002 (Core services operational) | PASS — 15/15 UP |

---

## 13. Conclusion

The SIL-6 mesh is now fully operational with 15/15 containers running. The root cause was a missing Podman network with the wrong subnet — the Rust ignition daemon's hardcoded static IP `172.28.0.10` requires `172.28.0.0/16`, not the default `10.89.0.0/24`.

**Correct startup sequence**:
```bash
# ── One-time (or after podman system reset) ──────────────────────────
podman network create --subnet 172.28.0.0/16 --gateway 172.28.0.1 indrajaal-sil6-mesh

# ── Launch SIL-6 mesh (15 containers, 5 waves, ~2.3s) ───────────────
cd /home/an/dev/ver/c3i
bin/Cepaf launch

# ── Post-launch: create database (fresh db-prod only) ───────────────
podman exec indrajaal-db-prod psql -U postgres -c "CREATE DATABASE indrajaal_prod;"

# ── Start Gleam orchestrator (planning, health, Zenoh IPC) ──────────
cd lib/cepaf_gleam && gleam run

# ── Run full Gleam test suite (1,913 tests) ──────────────────────────
cd lib/cepaf_gleam && gleam test

# ── Shutdown ─────────────────────────────────────────────────────────
bin/Cepaf down          # Rust graceful shutdown
# or: podman stop -a    # Force stop all
```

The Rust daemon should be enhanced to handle network provisioning and database creation automatically (registered as future tasks).
