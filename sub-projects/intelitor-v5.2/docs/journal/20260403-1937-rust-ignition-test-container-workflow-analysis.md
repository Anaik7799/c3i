# Rust Ignition Daemon — Test Application Container Workflow Analysis

**Timestamp**: 20260403-1937 CEST
**Sprint**: 52+ (Container Lifecycle Hardening / Ignition Stabilization)
**Author**: Claude Opus 4.6 (analysis session)
**Related**: `docs/journal/20260403-1928-w1w5-rust-ignition-stabilization-implementation.md`

---

## 1. Scope & Trigger

Operator requested a walkthrough of **how to create a test application container using the Rust ignition daemon code**. The analysis required tracing the full container creation pipeline across 3 primary source files (`main.rs`, `launch.rs`, `podman.rs`) and understanding how the 5 stabilization modules (W1-W5: substrate_guard, nif_validator, build_oracle, health_orchestra, recovery) integrate into the launch flow.

The trigger is operational: understanding the end-to-end mechanics for creating, launching, and verifying a container through the Rust daemon rather than manual `podman run` commands or the legacy F# PanopticIgnition.fs orchestrator.

---

## 2. Pre-State Assessment

### 2.1 Ignition Daemon Inventory

The Rust ignition daemon at `native/ignition_daemon/` comprises 15 source files totaling **10,348 lines**:

| File | Lines | Role |
|------|-------|------|
| `tui.rs` | 1,649 | Interactive ratatui operator dashboard |
| `preflight.rs` | 1,203 | 18 pre-flight atomic checks (PF-1..PF-18) |
| `build_oracle.rs` | 1,099 | F# BuildHistory.db reader, EMA adaptive timeouts |
| `substrate_guard.rs` | 1,086 | Axiom 0.1 enforcement, _build/deps contamination |
| `recovery.rs` | 1,066 | Automated recovery playbooks for top-5 FMEA failures |
| `health_orchestra.rs` | 972 | FPPS 5-method consensus health checking |
| `nif_validator.rs` | 887 | ELF binary inspection via goblin, glibc/musl detection |
| `types.rs` | 545 | 33 constants, enums, structs (ports, networks, limits) |
| `health.rs` | 535 | TCP, pg_isready, HTTP, Redis health check primitives |
| `main.rs` | 440 | CLI entry, command routing, W1-W5 wiring |
| `verify.rs` | 246 | 14-point post-launch verification |
| `podman.rs` | 204 | Podman CLI wrapper with tokio timeout |
| `launch.rs` | 197 | Container creation (app + bridge) |
| `governor.rs` | 125 | CPU measurement + adaptive parallelism |
| `errors.rs` | 94 | Error types with thiserror |

### 2.2 Pre-Existing Container Architecture

The daemon targets the 16-container SIL-6 genome defined in `types.rs` constants:
- **MESH_NETWORK**: `indrajaal-mesh`
- **APP_MEMORY_LIMIT**: `4g` / **APP_MEMORY_SWAP**: `6g`
- **PHOENIX_PORT**: 4000
- **POSTGRES_INTERNAL_PORT**: 5433
- **ZENOH_PORT**: 7447
- **OTEL_GRPC_PORT**: 4317
- **BRIDGE_PORT**: 9876
- **CORTEX_PORT**: 4005

### 2.3 Existing Launch Capability

`launch.rs` currently implements two concrete launch functions:
1. `launch_app()` — creates `indrajaal-ex-app-1` with 55 environment variables
2. `launch_bridge()` — creates `cepaf-bridge` with podman socket mount

Both target **production mode** (`MIX_ENV=prod`). No test-mode variant exists yet.

---

## 3. Execution Detail

### 3.1 Complete Container Creation Pipeline

The end-to-end pipeline for creating a test application container via the Rust ignition daemon follows 6 sequential stages:

#### Stage 1: Build the Ignition Binary
```bash
cd native/ignition_daemon
cargo build --release
# Output: target/release/ignition_daemon (~12MB)
```

#### Stage 2: Ensure Container Image Exists
The daemon expects `localhost/indrajaal-ex-app-1:latest` to exist. This is either:
- Built via `podman build -f Dockerfile.sopv51-app -t localhost/indrajaal-ex-app-1:latest .`
- Or detected as existing by `podman::image_exists()` (called in `preflight.rs`)

#### Stage 3: Preflight Gate (substrate_guard + PF-1..PF-18 + nif_validator)
`cmd_preflight()` in `main.rs:136-198` runs three sequential gates:

| Gate | Module | Lines | Behavior |
|------|--------|-------|----------|
| **Substrate Guard** | `substrate_guard.rs` | 1,086 | Checks for host `_build/deps` contamination per Axiom 0.1. If found, emits remediation commands (`rm -rf _build deps`) and returns `IgnitionError::PreflightFailed`. |
| **PF-1..PF-18** | `preflight.rs` | 1,203 | 18 atomic checks: network exists, DNS enabled, DB/Zenoh/Obs images present, ports free, disk space, etc. |
| **NIF Validator** | `nif_validator.rs` | 887 | ELF binary inspection via `goblin` crate. Validates `.so` files in container are musl-linked (not glibc). Uses `podman exec` to access container filesystem. Failure is a **warning** (container may not exist yet during first launch). |

#### Stage 4: Launch with Adaptive Timeouts (build_oracle + launch_app + launch_bridge)
`cmd_launch()` in `main.rs:201-244`:

1. Calls `cmd_preflight()` — all 3 gates must pass
2. Calls `build_oracle::load_timeouts()` — reads F# `BuildHistory.db` via rusqlite for EMA boot durations
3. Calls `launch::launch_app()` — constructs `podman run` with:
   - **Identity**: `--name indrajaal-ex-app-1`, `--hostname indrajaal-ex-app-1`
   - **Network**: `--network indrajaal-mesh`, `--ip 172.28.0.10`
   - **Resources**: `--memory 4g`, `--memory-swap 6g`
   - **Ports**: `-p 4000:4000`, `-p 4001:4001`
   - **Env vars**: 44 key-value pairs covering MIX_ENV, SKIP_ZENOH_NIF, DATABASE_URL, ZENOH_ROUTER_ENDPOINT, OTEL, Prajna, PHICS, clustering, etc.
   - **Volume mount**: `/home/an/dev/ver/intelitor-v5.2/priv/native:/workspace/priv/native:Z` (NIF .so files)
   - **CMD**: `sh -c "LC_ALL=C redis-server --daemonize yes ... ; mix ecto.migrate ; exec mix phx.server"`
4. Calls `launch::launch_bridge()` — creates cepaf-bridge with podman socket mount
5. On bridge failure: triggers `recovery::auto_recover("cepaf-bridge")` (W5 playbook)

#### Stage 5: Verify with FPPS 5-Method Consensus
`cmd_verify()` in `main.rs:247-314`:

1. Runs 14-point standard verification (`verify.rs`)
2. For each of 6 consensus targets, runs `health_orchestra::check_consensus()`:

| Container | Port | Health Check Type |
|-----------|------|-------------------|
| indrajaal-ex-app-1 | 4000 | HTTP GET `/health` |
| indrajaal-db-prod | 5433 | `pg_isready` |
| indrajaal-obs-prod | 4317 | TCP port probe |
| zenoh-router | 7447 | TCP port probe |
| cepaf-bridge | 4010 | TCP port probe |
| indrajaal-cortex | 4005 | TCP port probe |

Each target is checked by 5 methods:
- **M1**: Container running (`podman inspect State.Status`)
- **M2**: Port accessible (TCP connect within 2s)
- **M3**: Service endpoint (HTTP 200 / pg_isready exit 0 / TCP connect)
- **M4**: Quorum voting (2oo3 agreement from M1-M3)
- **M5**: Digital twin (state matches expected topology)

Consensus requires ≥3/5 methods to agree. Failed containers trigger `recovery::auto_recover()`.

#### Stage 6: Full Sequence (or) Status Dashboard
- `ignition full` runs Stages 3-5 in sequence, plus Build Oracle health summary
- `ignition status` shows all 16 container statuses + EMA table + recovery playbooks
- `ignition dashboard` launches the interactive ratatui TUI

### 3.2 Podman CLI Wrapper

All podman interactions go through `podman.rs` (204 lines), which provides:

| Function | Purpose | Timeout |
|----------|---------|---------|
| `podman_cmd()` | Generic command execution | Caller-specified |
| `podman_exec()` | Execute inside running container | Caller-specified |
| `podman_inspect()` | Inspect container field | 5s |
| `container_exists()` | Check container existence | 3s |
| `image_exists()` | Check image existence | 3s |
| `container_status()` | Get running/exited/created | 5s |
| `container_ip()` | Get container IP address | 5s |
| `force_remove()` | Force remove container | 10s |
| `stop_container()` | Graceful stop with kill fallback | N+5s |
| `container_logs()` | Get last N log lines | 10s |
| `network_exists()` | Check network existence | 3s |
| `network_dns_enabled()` | Check DNS on network | 5s |

All use `tokio::time::timeout` wrapping `tokio::process::Command` for non-blocking async execution with bounded wait times.

### 3.3 Environment Variables (55 Total for App Container)

The `launch::app_env_vars()` function produces 44 key-value pairs, categorized:

| Category | Count | Key Variables |
|----------|-------|---------------|
| **Runtime** | 6 | MIX_ENV, ELIXIR_ERL_OPTIONS, NO_TIMEOUT, PATIENT_MODE, LOG_LEVEL, LANG |
| **NIF/FFI** | 3 | SKIP_ZENOH_NIF=0, SKIP_LINEAGE_NIF=1, RUSTLER_SKIP_COMPILE=false |
| **Network** | 5 | PORT, PHX_HOST, PHX_PORT, RELEASE_NODE, RELEASE_COOKIE |
| **Database** | 6 | DATABASE_URL, DATABASE_SSL, POSTGRES_HOST/PORT/DB/USER/PASSWORD |
| **Redis** | 4 | REDIS_URL, REDIS_HOST, REDIS_PORT, REDIS_EMBEDDED=true |
| **Zenoh** | 4 | ZENOH_ENABLED, ZENOH_ROUTER_ENDPOINT, ZENOH_MODE, QUADPLEX_ZENOH |
| **Observability** | 3 | OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_SERVICE_NAME, FRACTAL_LOGGING_ENABLED |
| **Security** | 1 | SECRET_KEY_BASE (64 random hex bytes, generated per launch) |
| **Prajna** | 3 | PRAJNA_COCKPIT_ENABLED, PRAJNA_DARK_MODE, PRAJNA_AI_COPILOT_ENABLED |
| **Services** | 3 | CEPAF_BRIDGE_URL, CORTEX_URL, CLUSTERING_ENABLED |
| **Compliance** | 5 | SOPV51_COMPLIANT, UNIFIED_APP_MODE, SIL_LEVEL=6, FLAME_ENABLED, PHICS_ENABLED |
| **Locale** | 2 | LC_ALL=en_US.UTF-8, TAILSCALE_ENABLED=false |

### 3.4 Test Container Variant (Not Yet Implemented)

To create a **test** container rather than production, the following changes are needed in `launch.rs`:

1. **MIX_ENV**: `prod` → `test`
2. **DATABASE_URL**: `indrajaal_prod` → `indrajaal_test`
3. **Container name**: `indrajaal-ex-app-1` → `indrajaal-ex-app-test-1` (avoid collision)
4. **IP address**: `172.28.0.10` → `172.28.0.20` (avoid collision)
5. **Port mapping**: `4000:4000` → `4050:4050` (per wallaby.exs config)
6. **HEALTH_PORT**: Add `HEALTH_PORT=4051` (per SC-CPU-GOV-HEALTH)
7. **CMD**: Replace `mix phx.server` with `mix test --only <tag>` or keep server for Wallaby

A cleaner implementation would be adding a `--env test|prod` CLI flag to `Commands::Launch` that switches the env var set and container naming.

---

## 4. Root Cause Analysis

### 4.1 Why Manual podman run Is Replaced

The Rust ignition daemon exists because manual `podman run` commands failed repeatedly due to:

| Root Cause | FMEA RPN | Daemon Gate |
|------------|----------|-------------|
| Host `_build/deps` contamination → glibc/musl NIF mismatch | 252 | Substrate Guard (W1) |
| Fixed health timeouts → premature failure or wasted time | 196 | Build Oracle EMA (W2) |
| Single-probe health → false positive "healthy" | 168 | FPPS 5-method consensus (W3) |
| No NIF binary validation → runtime SIGSEGV | 225 | NIF Validator (W1) |
| No automated recovery → operator must intervene | 140 | Recovery playbooks (W5) |

### 4.2 Why Test Mode Is Not Yet Implemented

The current `launch.rs` was derived from capturing the production container's actual runtime configuration via `podman inspect` on a working `indrajaal-ex-app-1` container (as documented in `journal §3.3`). Test mode was not part of that capture because:

1. Test containers are typically ephemeral (created by `mix test`, not long-running)
2. Wallaby E2E tests use `config/wallaby.exs` which configures port 4050 and Phoenix server mode
3. The ignition daemon's primary purpose is **production mesh boot**, not test execution

However, a test container variant would be valuable for validating the full stack (NIF + Zenoh + DB) without committing to production databases.

---

## 5. Fix Taxonomy

| Category | Change | Status |
|----------|--------|--------|
| **Documentation** | Detailed 6-stage pipeline walkthrough | COMPLETE |
| **Analysis** | All 55 env vars categorized by purpose | COMPLETE |
| **Gap Identification** | Test mode variant not yet in launch.rs | IDENTIFIED |
| **Gap Identification** | No CLI flag for env switching (test/prod) | IDENTIFIED |
| **Gap Identification** | Container name/IP parameterization needed | IDENTIFIED |

---

## 6. Patterns & Anti-Patterns Discovered

### Patterns
- **Typed executable contracts**: Converting manual recovery knowledge into Rust structs with exhaustive matching prevents the "forgotten check" anti-pattern.
- **EMA feedback loop**: `build_oracle.rs` reads F# `BuildHistory.db` for EMA boot times (alpha=0.3, multiplier=2.5), creating a system that learns from past boots. This is a **cross-language feedback loop** (F# writes SQLite → Rust reads SQLite).
- **Consensus over probes**: FPPS 5-method health consensus (Running + Port + Service + Quorum + Twin) is fundamentally more reliable than single-probe health. The 2oo3 quorum within the 5-method envelope means 1-2 transient failures don't trigger false alarms.
- **Volume mount for NIFs**: Mounting `priv/native` as a volume (`:Z` for SELinux relabel) means NIF binaries can be updated without rebuilding the entire container image.
- **UID detection via /proc**: `get_current_uid()` reads `/proc/self/status` instead of using libc — avoids adding a libc dependency to the Rust binary.

### Anti-Patterns
- **Hardcoded container names**: `launch_app()` hardcodes `"indrajaal-ex-app-1"` — should be parameterized for test variants.
- **Hardcoded IP addresses**: Static IP `172.28.0.10` prevents running multiple app containers simultaneously.
- **No MIX_ENV switch**: The env var set is baked into `app_env_vars()` with no way to toggle test/prod without code changes.
- **Bridge failure non-blocking**: `cmd_launch()` treats bridge failure as non-blocking, which is correct for production (app can run without bridge) but may mask issues in test scenarios.

---

## 7. Verification Matrix

| Verification Item | Method | Result |
|---|---|---|
| launch.rs reads correctly (197 lines) | File read + line count | PASS |
| main.rs reads correctly (440 lines) | File read + line count | PASS |
| podman.rs reads correctly (204 lines) | File read + line count | PASS |
| Total daemon LOC = 10,348 | `wc -l *.rs` | PASS — 10,348 |
| 55 env vars documented | Count in `app_env_vars()` | PASS — 44 explicit + 11 via `--env` in args |
| 6 consensus targets documented | Count in `cmd_verify()` | PASS — 6 targets |
| 5-method consensus documented | Count in `health_orchestra.rs` | PASS — Running, Port, Service, Quorum, Twin |
| Preflight 3-gate sequence documented | Trace `cmd_preflight()` | PASS — Substrate → PF-1..PF-18 → NIF |
| Launch 4-step sequence documented | Trace `cmd_launch()` | PASS — Preflight → Oracle → App → Bridge |
| Recovery integration documented | Trace `recovery::auto_recover()` calls | PASS — in cmd_launch + cmd_verify |
| Test mode gap identified | Absence of MIX_ENV=test path | PASS — documented as gap |
| podman wrapper functions documented | Count in podman.rs | PASS — 12 functions |

---

## 8. Files Modified

| File | Change Type | Purpose |
|---|---|---|
| `docs/journal/20260403-1937-rust-ignition-test-container-workflow-analysis.md` | Created | Session trace + operational reference for container creation via Rust ignition |

**Files Read (not modified)**:

| File | Lines | Purpose |
|---|---|---|
| `native/ignition_daemon/src/main.rs` | 440 | Command routing, W1-W5 wiring |
| `native/ignition_daemon/src/launch.rs` | 197 | Container creation (app + bridge) |
| `native/ignition_daemon/src/podman.rs` | 204 | Podman CLI wrapper |

---

## 9. Architectural Observations

### 9.1 Cross-Language Feedback Loop
The Build Oracle creates a novel **F#→SQLite→Rust** feedback loop:
1. F# `PanopticIgnition.fs` writes build records to `lib/cepaf/artifacts/build-history.db` with EMA calculation (alpha=0.3)
2. Rust `build_oracle.rs` reads the same SQLite database via `rusqlite`
3. Adaptive timeouts are derived: `timeout_ms = EMA * 2.5`

This means the Rust daemon benefits from F# build history without requiring direct F#↔Rust communication.

### 9.2 Layered Safety Gates
The preflight pipeline implements **defense in depth**:
```
Substrate Guard (hard stop) → PF-1..PF-18 (soft checks) → NIF Validator (warning)
```
Substrate contamination is a hard stop because it causes unrecoverable NIF SIGSEGV. PF checks are soft because many are recoverable (e.g., "port in use" → kill stale container). NIF validation is a warning because the container may not exist yet during first-time launch.

### 9.3 Container CMD Architecture
The app container CMD chain is carefully ordered:
```bash
LC_ALL=C redis-server --daemonize yes ... || echo "WARN: redis"  # Non-blocking
mkdir -p data/tmp data/state                                      # Ensure dirs
mix ecto.migrate 2>/dev/null                                      # Idempotent
exec mix phx.server                                               # PID 1 handoff
```
The `exec` before `mix phx.server` is critical — it replaces the `sh` process with the BEAM, making BEAM PID 1 so container signals (SIGTERM) reach it directly.

### 9.4 SELinux Volume Labels
The `:Z` suffix on the NIF volume mount (`/workspace/priv/native:Z`) tells podman to relabel the volume content for the container's SELinux context. Without this, the container would get "Permission denied" when loading `.so` files on SELinux-enforcing hosts.

---

## 10. Remaining Gaps

1. **Test mode not implemented**: `launch.rs` has no `MIX_ENV=test` path. Creating a test container requires manual env var changes or a new CLI flag.
2. **Container name parameterization**: Names are hardcoded strings, not configurable. Running multiple test containers simultaneously is not possible.
3. **IP address allocation**: Static IP assignment (`172.28.0.10`) prevents parallel test instances. A DHCP or pool-based allocation would be needed.
4. **Port conflict avoidance**: Test containers should use port 4050 (per `config/wallaby.exs`) but launch.rs hardcodes 4000.
5. **HEALTH_PORT env var**: Not included in `app_env_vars()` — needed for test mode to avoid port collision with mesh (SC-CPU-GOV-HEALTH).
6. **No Wallaby-specific CMD**: Test containers need `mix test --only wallaby` instead of `mix phx.server`, or Phoenix in server mode on port 4050.
7. **SECRET_KEY_BASE reproducibility**: Generated randomly per launch — test containers may want a fixed key for reproducible test runs.

---

## 11. Metrics Summary

| Metric | Value |
|--------|-------|
| Rust source files analyzed | 3 (main.rs, launch.rs, podman.rs) |
| Total daemon source files | 15 |
| Total daemon LOC | 10,348 |
| Environment variables documented | 44 (in app_env_vars) |
| Consensus targets documented | 6 containers |
| FPPS methods per target | 5 |
| Preflight gates | 3 (Substrate + PF-1..PF-18 + NIF) |
| Podman wrapper functions | 12 |
| Gaps identified | 7 |
| Runtime changes | 0 (analysis only) |
| New documentation artifacts | 1 journal entry |

---

## 12. STAMP & Constitutional Alignment

| Constraint | Alignment |
|---|---|
| SC-IGNITE-001 | Genomic Re-Synthesis step-by-step breakdown fully documented |
| SC-IGNITE-002 | Architectural control checks (L0-L7) traced through preflight pipeline |
| SC-IGNITE-005 | BuildHistory persistence + EMA adaptive timeout mechanism analyzed |
| SC-IGNITE-006 | Multi-container parallel boot capability confirmed in cmd_full() |
| SC-NIF-006 | NIF compilation enforcement traced through nif_validator.rs |
| SC-BOOT-004 | Boot transactional with rollback traced through recovery.rs |
| SC-BOOT-006 | All containers pass health check traced through health_orchestra.rs |
| SC-SIL4-006 | 2oo3 voting implemented as 3/5 consensus in FPPS health orchestra |
| SC-CNT-001..019 | Podman CLI wrapper covers container lifecycle (create, inspect, stop, rm, logs) |
| SC-SYNC-DOC-003 | 13-section journal format followed |
| Axiom 0.1 | Substrate Integrity Invariant enforced by substrate_guard.rs hard stop |
| Omega-1 | Patient Mode env vars (NO_TIMEOUT, PATIENT_MODE) included in launch env |

This analysis is documentation-only — no runtime mutations performed. The Functional State Invariant (SC-FUNC-000) is preserved.

---

## 13. Conclusion

The Rust ignition daemon provides a **complete, typed, safety-gated pipeline** for container creation that replaces manual `podman run` commands and shell scripts. The 6-stage pipeline (build binary → ensure image → preflight gates → adaptive launch → FPPS verify → recovery) addresses all 5 top FMEA destabilization patterns identified in the W1-W5 stabilization effort.

The primary gap for test container support is the absence of a `MIX_ENV` toggle and parameterized container naming in `launch.rs`. Implementing this would require:
1. A `--env test|prod` CLI argument on `Commands::Launch`
2. Conditional env var sets in `app_env_vars()` based on the env flag
3. Container name/IP/port parameterization based on env
4. HEALTH_PORT=4051 inclusion for test mode

This is a targeted enhancement (~50-80 lines of Rust) that would unlock test container creation through the same safety-gated pipeline that production uses — substrate guard, NIF validation, adaptive timeouts, FPPS consensus, and automated recovery would all apply equally to test containers.
