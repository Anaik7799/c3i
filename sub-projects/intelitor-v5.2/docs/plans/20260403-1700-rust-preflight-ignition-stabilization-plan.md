# Rust Preflight & Ignition Stabilization Plan

**Timestamp**: 20260403-1700 CEST
**Status**: ACTIVE
**Priority**: P0-HARDENING
**Related Journal**: `docs/journal/20260403-1700-app-container-500-ideas-rust-stabilization-journal.md`

---

## 1. Problem Statement

The application container (indrajaal-ex-app-1) repeatedly destabilizes the 16-container SIL-6 mesh during BUILD, boot, and early runtime. Five destabilization patterns have been identified with FMEA RPN scores ranging from 140-252. The root cause is fragmented operational intelligence: F#, Rust, and Elixir each accumulate knowledge in isolation with no bidirectional data flow.

## 2. Destabilization Patterns (FMEA)

| # | Pattern | S | O | D | RPN | Root Cause |
|---|---------|---|---|---|-----|------------|
| 1 | NIF compilation failure | 9 | 7 | 4 | 252 | cargo/deps not validated before build |
| 2 | glibc/musl NIF binary conflict | 9 | 5 | 5 | 225 | Host _build leaks into container (Axiom 0.1) |
| 3 | Fixed health timeouts | 7 | 7 | 4 | 196 | Hardcoded 30-60s ignores first-build 300s+ reality |
| 4 | Boot ordering races | 7 | 6 | 4 | 168 | App tier starts before DB/Zenoh confirmed ready |
| 5 | Operator observability gaps | 7 | 5 | 4 | 140 | TUI has no BUILD phase visibility |

## 3. Architecture: Current vs. Proposed

### 3.1 Current State (10 files, 3,029 LOC)

```
native/ignition_daemon/src/
├── main.rs        (236)  — CLI entry, 5 subcommands
├── tui.rs         (1015) — 4 tabs: Swarm, Governor, Checks, Trace
├── preflight.rs   (381)  — 6 checks: PF-1..PF-6
├── types.rs       (365)  — 33 constants
├── verify.rs      (246)  — 14 post-launch verifications
├── podman.rs      (204)  — podman interaction
├── health.rs      (199)  — Fixed timeout health checks
├── launch.rs      (197)  — Launch orchestration
├── governor.rs    (125)  — CPU governance
└── errors.rs      (61)   — Error types
```

### 3.2 Proposed State (15 files, ~7,779 LOC)

```
native/ignition_daemon/src/
├── main.rs              (236 + ~50)   — Add oracle + guard initialization
├── tui.rs               (1015 + ~800) — 8 tabs: +BUILD, +NIF, +DB, +Recovery
├── preflight.rs         (381 + ~600)  — 25 checks: PF-1..PF-25
├── health.rs            (199 + ~300)  — Adaptive EMA-based timeouts
├── nif_validator.rs     (NEW ~450)    — ELF inspection, glibc/musl detection
├── build_oracle.rs      (NEW ~500)    — Reads F# BuildHistory.db, computes adaptive timeouts
├── substrate_guard.rs   (NEW ~350)    — Axiom 0.1 enforcement, contamination detection
├── health_orchestra.rs  (NEW ~550)    — FPPS 5-method consensus health
├── recovery.rs          (NEW ~400)    — Automated recovery for top-5 failures
├── types.rs             (365 + ~100)  — New types for oracle, guard, orchestra
├── verify.rs            (246)         — Unchanged
├── launch.rs            (197 + ~50)   — Hook oracle + guard gates
├── podman.rs            (204)         — Unchanged
├── governor.rs          (125)         — Unchanged
└── errors.rs            (61 + ~50)    — New error variants
```

## 4. New Module Specifications

### 4.1 `nif_validator.rs` (~450 LOC) — NIF Binary Safety Layer

**Purpose**: Detect NIF compilation failures and glibc/musl conflicts BEFORE container boot.

**Capabilities**:
- ELF header inspection via `goblin` crate — read interpreter path to distinguish glibc vs musl
- Cargo toolchain validation — verify `cargo`, `rustc`, `rustup` availability and versions
- NIF .so file inspection — validate all `*.so` files in `_build/` match container libc
- Dependency tree audit — check Cargo.lock for version conflicts
- Cross-compilation detection — flag host-built NIFs in container context

**Key Functions**:
```rust
pub fn validate_nif_environment() -> Result<NifReport, NifError>
pub fn inspect_elf_binary(path: &Path) -> Result<ElfInfo, NifError>
pub fn detect_libc_mismatch(host_nif: &Path, container_libc: LibcType) -> bool
pub fn validate_cargo_toolchain() -> Result<ToolchainInfo, NifError>
pub fn audit_nif_dependencies() -> Result<Vec<NifDep>, NifError>
```

**FMEA Mitigation**: Reduces Pattern #1 RPN from 252 to ~84 (D: 4→2, better detection) and Pattern #2 RPN from 225 to ~45 (O: 5→1, prevention).

**STAMP**: SC-NIF-006 (never bypass NIF compilation), SC-NIF-001 to SC-NIF-005.

### 4.2 `build_oracle.rs` (~500 LOC) — Adaptive Intelligence Bridge

**Purpose**: Read F# BuildHistory.db (SQLite WAL) to provide adaptive timeouts and build predictions.

**Capabilities**:
- Read `build_ema` table for per-container EMA durations
- Compute adaptive health check timeouts: `timeout = ema_duration * 1.5 + safety_margin`
- Predict total ignition time from sum of individual container EMAs
- Detect anomalous builds (>3σ from EMA) and flag for operator review
- Track build success rate per container for reliability scoring

**Key Functions**:
```rust
pub fn connect_build_history(db_path: &Path) -> Result<BuildOracle, OracleError>
pub fn get_adaptive_timeout(&self, container: &str) -> Duration
pub fn predict_ignition_time(&self) -> Duration
pub fn get_build_success_rate(&self, container: &str) -> f64
pub fn detect_anomaly(&self, container: &str, actual_ms: u64) -> Option<Anomaly>
pub fn get_ema_history(&self) -> Vec<ContainerEma>
```

**Data Bridge**:
```
F# BuildHistory.fs                    Rust build_oracle.rs
       │                                     │
       ├─ UPSERT build_ema                   ├─ SELECT * FROM build_ema
       │  (container, ema_ms, count,         │  (read-only, WAL concurrent reader)
       │   last_build, alpha=0.3)            │
       │                                     ├─ Compute adaptive_timeout = ema * 1.5 + margin
       └─ build-history.db (WAL) ──────────→ └─ Detect anomalies (>3σ deviation)
```

**FMEA Mitigation**: Reduces Pattern #3 RPN from 196 to ~56 (D: 4→2, O: 7→4 via adaptive timeouts).

**Cargo.toml Addition**: `rusqlite = { version = "0.31", features = ["bundled"] }`

### 4.3 `substrate_guard.rs` (~350 LOC) — Axiom 0.1 Enforcement

**Purpose**: Prevent host-side build artifacts from contaminating container builds.

**Capabilities**:
- Detect host `_build/` and `deps/` directories when running in container mode
- Verify volume mounts don't shadow critical container paths (Axiom 0.2)
- Check for `ld-linux-x86-64.so.2` error signatures in recent logs
- Validate container filesystem isolation (no host library leakage)
- Pre-build cleanup recommendation (rm -rf _build deps when needed)

**Key Functions**:
```rust
pub fn check_substrate_integrity() -> Result<SubstrateReport, SubstrateError>
pub fn detect_build_contamination(project_root: &Path) -> Vec<Contamination>
pub fn validate_volume_mounts() -> Result<Vec<MountCheck>, SubstrateError>
pub fn check_library_isolation(container: &str) -> Result<LibraryReport, SubstrateError>
pub fn recommend_cleanup(contaminations: &[Contamination]) -> Vec<CleanupAction>
```

**FMEA Mitigation**: Reduces Pattern #2 RPN from 225 to ~45 (O: 5→1, prevention via early detection).

**STAMP**: Axiom 0.1 (Substrate Integrity Invariant), Axiom 0.2 (Volume Shadowing Safeguard).

### 4.4 `health_orchestra.rs` (~550 LOC) — FPPS 5-Method Consensus

**Purpose**: Replace single-probe TCP health checks with 5-method consensus.

**Capabilities**:
- Method 1: Container running state (podman inspect)
- Method 2: TCP port accessibility (connect probe)
- Method 3: Service endpoint response (HTTP /health or pg_isready)
- Method 4: Quorum voting (2oo3 for critical services)
- Method 5: Digital twin consistency (compare expected vs actual state)
- Configurable consensus threshold (default: 3/5 for normal, 5/5 for safety-critical)
- Per-container health profiles (DB needs pg_isready, app needs /health, etc.)

**Key Functions**:
```rust
pub fn assess_health(container: &str, profile: &HealthProfile) -> HealthVerdict
pub fn fpps_consensus(results: &[MethodResult], threshold: u8) -> ConsensusResult
pub fn create_health_profile(category: ContainerCategory) -> HealthProfile
pub fn run_all_methods(container: &str, profile: &HealthProfile) -> Vec<MethodResult>
pub fn adaptive_retry(container: &str, oracle: &BuildOracle) -> RetryConfig
```

**FMEA Mitigation**: Reduces Pattern #4 RPN from 168 to ~48 (D: 4→2, O: 6→3 via consensus).

**STAMP**: Ω₅ (Validation Consensus), SC-SIL4-023 (FPPS 3/5 consensus), SC-BIST-001 (3σ stability gate).

### 4.5 `recovery.rs` (~400 LOC) — Automated Recovery Playbook

**Purpose**: Deterministic recovery actions for the top-5 failure modes.

**Capabilities**:
- Pattern #1 (NIF failure): Auto-install cargo via rustup, retry NIF build
- Pattern #2 (glibc/musl): Auto rm -rf _build deps, trigger container rebuild
- Pattern #3 (timeout): Extend timeout using oracle EMA × 2, retry with backoff
- Pattern #4 (boot race): Insert wait-for-dependency gate, retry tier boot
- Pattern #5 (observability): Switch TUI to diagnostic mode, capture full trace
- Recovery history tracking (what was tried, what worked)
- Escalation to operator when automated recovery exhausted (3 attempts max)

**Key Functions**:
```rust
pub fn diagnose_failure(failure: &BootFailure) -> DiagnosisResult
pub fn select_playbook(diagnosis: &DiagnosisResult) -> Option<RecoveryPlaybook>
pub fn execute_recovery(playbook: &RecoveryPlaybook) -> RecoveryOutcome
pub fn escalate_to_operator(failure: &BootFailure, attempts: &[RecoveryOutcome]) -> Alert
pub fn track_recovery_history(outcome: &RecoveryOutcome) -> Result<(), RecoveryError>
```

**STAMP**: SC-IGNITE-003 (7-Level Fractal RCA on boot failure), SC-REGEN-002 to SC-REGEN-004.

## 5. Enhanced Module Specifications

### 5.1 `tui.rs` Enhancement (+~800 LOC) — 8-Tab Operator Cognition

**Current**: 4 tabs (Swarm, Governor, Checks, Trace)
**Proposed**: 8 tabs adding BUILD, NIF, DB, Recovery

| Tab | Content | Data Source |
|---|---|---|
| BUILD | Container synthesis progress, EMA timing, layer cache hits | build_oracle.rs + Zenoh |
| NIF | ELF inspection results, libc type, cargo toolchain | nif_validator.rs |
| DB | pg_isready, WAL status, connection pool, migration state | health_orchestra.rs |
| Recovery | Active playbooks, recovery history, escalation status | recovery.rs |

**Fractal Layer Mapping**:
- BUILD tab: L0 (constitution hash) + L1 (NIF compilation) + L4 (container image)
- NIF tab: L1 (atomic NIF) + L2 (Rustler components)
- DB tab: L3 (transaction layer) + L4 (system/container)
- Recovery tab: L5 (cognitive/decision) + L6 (ecosystem/mesh)

### 5.2 `preflight.rs` Enhancement (+~600 LOC) — PF-1 to PF-25

**Current PF-1..PF-6**:
| Check | Description |
|---|---|
| PF-1 | Podman socket available |
| PF-2 | Network exists |
| PF-3 | Required images present |
| PF-4 | Port availability |
| PF-5 | Volume mounts valid |
| PF-6 | CPU governor ready |

**New PF-7..PF-25**:
| Check | Description | Module |
|---|---|---|
| PF-7 | Cargo toolchain available | nif_validator |
| PF-8 | Rustc version compatible | nif_validator |
| PF-9 | NIF .so files present | nif_validator |
| PF-10 | NIF libc type matches container | nif_validator |
| PF-11 | No host _build contamination | substrate_guard |
| PF-12 | No host deps contamination | substrate_guard |
| PF-13 | Volume mounts don't shadow config | substrate_guard |
| PF-14 | BuildHistory.db accessible | build_oracle |
| PF-15 | EMA data available for key containers | build_oracle |
| PF-16 | Predicted ignition time within budget | build_oracle |
| PF-17 | PostgreSQL container responsive | health_orchestra |
| PF-18 | Zenoh router reachable (3σ latency) | health_orchestra |
| PF-19 | OTEL collector endpoint ready | health_orchestra |
| PF-20 | Elixir release built and present | substrate_guard |
| PF-21 | Mix deps compiled (container-side) | substrate_guard |
| PF-22 | Config files present (runtime.exs, etc.) | substrate_guard |
| PF-23 | Zenoh NIF loaded (SKIP_ZENOH_NIF=0) | nif_validator |
| PF-24 | Math NIF loaded | nif_validator |
| PF-25 | All previous recovery actions completed | recovery |

### 5.3 `health.rs` Enhancement (+~300 LOC) — Adaptive Timeouts

**Current**: Fixed `Duration::from_secs(30)` to `Duration::from_secs(60)`
**Proposed**: `oracle.get_adaptive_timeout(container)` with fallback to fixed

```rust
// Before (fixed):
let timeout = Duration::from_secs(30);

// After (adaptive):
let timeout = match oracle.get_adaptive_timeout(container) {
    Some(adaptive) => adaptive,
    None => Duration::from_secs(60), // conservative fallback for first build
};
```

## 6. Cargo.toml Additions

```toml
[dependencies]
# Existing deps unchanged...

# NEW: SQLite for BuildHistory bridge
rusqlite = { version = "0.31", features = ["bundled"] }

# NEW: ELF binary inspection for NIF validation
goblin = "0.8"

# NEW: Zenoh subscription for real-time F# events
zenoh = { version = "1.7", features = ["unstable"] }

# NEW: libc detection
libc = "0.2"
```

## 7. Data Flow Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    RUST ↔ F# DATA BRIDGE                                 │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  F# Layer                         Shared State         Rust Layer        │
│  ─────────                        ────────────         ──────────        │
│                                                                          │
│  BuildHistory.fs ──writes──→ build-history.db ──reads──→ build_oracle.rs │
│  (UPSERT EMA)                (SQLite WAL)          (SELECT read-only)    │
│                                                                          │
│  PanopticIgnition.fs              Zenoh                                  │
│  ──publishes──→ indrajaal/ignition/progress ──subscribes──→ tui.rs BUILD │
│  ──publishes──→ indrajaal/build/history ──subscribes──→ build_oracle.rs  │
│                                                                          │
│  PanopticIgnition.fs              Zenoh                                  │
│  ←──subscribes── indrajaal/preflight/status ──publishes── preflight.rs   │
│  (gate before tier 6-7)                       (PF-1..PF-25 results)      │
│                                                                          │
│  PanopticIgnition.fs              Zenoh                                  │
│  ←──subscribes── indrajaal/health/orchestra ──publishes── health_orch.rs │
│  (consensus results)                          (FPPS 5-method)            │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

## 8. Fractal Layer Coverage (L0-L7)

| Layer | BUILD Phase | DEPLOY Phase | RUN Phase |
|---|---|---|---|
| L0 Constitutional | Constitution hash in image | Guardian gate before deploy | Constitutional verification continuous |
| L1 Atomic/NIF | NIF compilation + ELF inspection | NIF .so deployment validation | NIF loaded status + Zenoh session |
| L2 Component | Elixir release assembly | GenServer supervisor tree | Component health monitoring |
| L3 Transaction | DB schema compilation | Migration execution | SQLite WAL + DuckDB pool |
| L4 System/Container | Dockerfile layer caching | Container image integrity | Port bindings + volume mounts |
| L5 Cognitive | Build prediction (EMA oracle) | OODA cycle initialization | Cortex AI model availability |
| L6 Ecosystem | Mesh topology planning | Swarm boot sequencing | 2oo3 quorum maintenance |
| L7 Federation | Version vector initialization | Peer discovery | Attestation + federation sync |

## 9. Implementation Roadmap (5 Waves)

### Wave 1 (P0, Days 1-3): Foundation Safety
- [ ] Implement `substrate_guard.rs` — Axiom 0.1/0.2 enforcement
- [ ] Implement `nif_validator.rs` — ELF inspection + cargo validation
- [ ] Add PF-7..PF-13 to `preflight.rs`
- [ ] Add `goblin` + `libc` to Cargo.toml
- **Gate**: All 5 existing preflight checks + 7 new checks pass

### Wave 2 (P0, Days 4-6): Adaptive Intelligence
- [ ] Implement `build_oracle.rs` — SQLite WAL reader + EMA consumer
- [ ] Enhance `health.rs` — Fixed → adaptive timeouts
- [ ] Add PF-14..PF-16 to `preflight.rs`
- [ ] Add `rusqlite` to Cargo.toml
- **Gate**: build_oracle reads EMA data from F# BuildHistory.db successfully

### Wave 3 (P1, Days 7-10): Consensus Health
- [ ] Implement `health_orchestra.rs` — FPPS 5-method consensus
- [ ] Add PF-17..PF-24 to `preflight.rs`
- [ ] Wire health_orchestra into launch.rs boot sequence
- **Gate**: FPPS consensus agrees on container health for all 16 containers

### Wave 4 (P1, Days 11-13): Operator Cognition
- [ ] Enhance `tui.rs` — 4→8 tabs (BUILD, NIF, DB, Recovery)
- [ ] Wire build_oracle, nif_validator, health_orchestra data into TUI
- [ ] Add `zenoh` to Cargo.toml for real-time F# event subscription
- **Gate**: All 8 TUI tabs render with live data from oracle + guard + orchestra

### Wave 5 (P1, Days 14-16): Recovery & Integration
- [ ] Implement `recovery.rs` — Automated playbooks for top-5 failures
- [ ] Add PF-25 to `preflight.rs`
- [ ] End-to-end integration test: F# → SQLite → Rust → TUI pipeline
- [ ] Add `zenoh` subscription for `indrajaal/ignition/progress` in TUI
- **Gate**: Full preflight (PF-1..PF-25) + ignition + 8-tab TUI + recovery playbook tested

## 10. Success Criteria

| Criterion | Metric | Target |
|---|---|---|
| Application container first-boot success rate | Consecutive successful boots | 10/10 |
| Average RPN across 5 patterns | Weighted mean | < 80 (from current ~196) |
| Operator time-to-diagnosis | From alert to root cause | < 60 seconds (from ~10 minutes) |
| TUI fractal coverage | L0-L7 layers with data | 8/8 |
| Preflight check count | Total PF checks | 25 (from 6) |
| Health check consensus | FPPS methods per container | 5 (from 1) |
| Build timeout accuracy | |actual - predicted| / actual | < 20% after 3 builds |
| Recovery automation rate | Auto-resolved / total failures | > 60% |

## 11. STAMP Constraint Coverage

| Constraint | Module | Coverage |
|---|---|---|
| SC-NIF-006 | nif_validator.rs | Full (never bypass NIF) |
| SC-BIST-001 | health_orchestra.rs | Full (3σ Zenoh gate) |
| SC-IGNITE-001 | build_oracle.rs | Full (step-by-step BUILD) |
| SC-IGNITE-003 | recovery.rs | Full (7-Level Fractal RCA) |
| SC-IGNITE-004 | tui.rs BUILD tab | Full (real-time progress) |
| SC-IGNITE-005 | build_oracle.rs | Full (EMA from SQLite) |
| SC-CPU-GOV-001 | governor.rs | Maintained (85% limit) |
| SC-FUNC-001 | substrate_guard.rs | Full (compilable state) |
| Axiom 0.1 | substrate_guard.rs | Full (substrate integrity) |
| Axiom 0.2 | substrate_guard.rs | Full (volume safeguard) |
| Ω₅ | health_orchestra.rs | Full (5-method consensus) |
| SC-HMI-010 | tui.rs 8 tabs | Full (chromatic feedback) |
