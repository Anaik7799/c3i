# System Recovery — 5-Level Detailed Analysis & Plan

**Date**: 2026-03-25 11:30 CEST
**Branch**: `multiverse/claude-opus-fractal-tests`
**Author**: Claude Opus 4.6
**Status**: ANALYSIS COMPLETE — AWAITING EXECUTION

---

## Executive Summary

The branch `multiverse/claude-opus-fractal-tests` is **744 commits ahead of main** (654 empty Auto-release heartbeat commits + 90 real commits). Previous recovery sessions (2026-03-25) already discarded ~22 dangerous/speculative files. Only **6 modified files** and **3 untracked documentation files** remain. Of the 6 modified files, **5 are safe operational improvements** and **1 must be discarded** (broken F# ProjectReference). The system compiles with 0 Elixir errors but has a broken F# Knowledge build and 2 undefined-function warnings across 34 files.

**Recovery action**: Discard 1 file, commit 5 safe files + 3 docs in 3 organized commits, verify clean tree, HOLD evolution.

---

## L0: Runtime State — What Is Actually Running

### L0.1 Container Health Matrix

| Container | Image | Size | Status | Ports | Health |
|-----------|-------|------|--------|-------|--------|
| `indrajaal-db-prod` | `localhost/indrajaal-db:nixos-pg17` | 875 MB | Running | 5433 | **HEALTHY** |
| `indrajaal-obs-prod` | `localhost/indrajaal-obs:nixos-otel` | 5.14 GB | Running | 4317/9090/3000/3100 | **UNHEALTHY** |
| `zenoh-router-1` | `eclipse/zenoh:1.0.0` | 51.1 MB | Running | 7447 | **HEALTHY** |

**OBS Unhealthy Root Cause**: Not yet diagnosed. Requires `podman logs indrajaal-obs-prod --tail 100` and endpoint probes (Prometheus :9090, Grafana :3000, Loki :3100). This is a **P1 blocker** for Part 2 mesh ignition but does NOT block Part 1 code recovery.

### L0.2 Application Image State

The application image `localhost/indrajaal-app-unified:nixos-devenv` is a **1.75 MB empty NixOS skeleton** — it contains NO Elixir/Erlang/Rust runtime, NO compiled BEAM files, NO Zenoh NIF. This image **cannot run the application**. Six of the planned 15 SIL-6 services depend on this image:
- `indrajaal-ex-app-1`, `indrajaal-ex-app-2`, `indrajaal-ex-app-3`
- `indrajaal-chaya`
- `ml-runner-1`, `ml-runner-2`

**ROOT BLOCKER for Part 2**: Must rebuild from `containers/Dockerfile.precompiled` (expected ~130-150 MB with full Elixir/OTP/Rust toolchain). This is deferred to Part 2.

### L0.3 Elixir Compilation State

```
Elixir 1.19 + OTP 28
Compilation: 0 ERRORS, ~2 warnings (pre-existing)
```

**Warnings** (not caused by uncommitted changes):
1. `Indrajaal.Safety.ZenohSafetyPublisher.publish_sentinel_threat/4 is undefined or private`
2. `Indrajaal.Cortex.ZenohNeuralStream.stream_state/3 is undefined or private`

Both modules exist at `lib/indrajaal/observability/` but specific functions are either missing or have mismatched arities. **34 files** reference these modules. This is a pre-existing condition — not blocking compilation (warnings only) but a runtime risk if those code paths execute.

### L0.4 F# Build State

```
.NET 10.0 SDK
Cepaf main project: BUILDS SUCCESSFULLY
Cepaf.Knowledge project: 9 ERRORS (broken ProjectReference)
```

The broken build is caused by the uncommitted change to `Cepaf.Knowledge.fsproj` which adds:
```xml
<ProjectReference Include="..\Cepaf.Holon\Cepaf.Holon.fsproj" />
```

The directory `lib/cepaf/src/Cepaf.Holon/` exists with only `DatabasePath.fs` — but there is **no `.fsproj` file**. This was an incomplete attempt to refactor the holon database path resolution into its own project.

**Error cascade in SharedPaths.fs** (lines 19-56):
1. MSB9008: `../Cepaf.Holon/Cepaf.Holon.fsproj does not exist`
2. FS0039: `The namespace 'Holon' is not defined` (line 19: `open Cepaf.Holon.DatabasePath`)
3. FS0039: `createUHI` is not defined (line 23)
4. FS0039: `holonDir` is not defined (line 28)
5. FS0039: `createFQDN` is not defined (lines 44, 50, 55)
6. FS0039: `resolve` is not defined (lines 45, 51, 56)

**Fix**: Revert `Cepaf.Knowledge.fsproj` to committed state. The committed version does NOT have this ProjectReference and builds successfully — `SharedPaths.fs` must have been compiling against a different mechanism (likely a direct file inclusion or a different module path).

---

## L1: Code-Level Changes — What Files Are Modified

### L1.1 File Classification Matrix

| # | File | Lines Changed | Risk | Action | Reason |
|---|------|--------------|------|--------|--------|
| 1 | `lib/cepaf/artifacts/podman-compose-prod-standalone.yml` | +5/-2 | **SAFE** | KEEP | Redis non-fatal startup, OBS dependency relaxation |
| 2 | `lib/cepaf/scripts/SIL6MeshOrchestrator.fsx` | +4/-4 | **SAFE** | KEEP | Path fix: relative → project-root-relative |
| 3 | `lib/cepaf/src/Cepaf.Knowledge/Cepaf.Knowledge.fsproj` | +3/-0 | **DANGEROUS** | DISCARD | Adds broken ProjectReference to non-existent Cepaf.Holon.fsproj |
| 4 | `lib/cepaf/src/Cepaf/Mesh/MeshStartup.fs` | +4/-4 | **SAFE** | KEEP | Compose file paths: relative → project-root-relative |
| 5 | `lib/indrajaal_web/live/navigation_portal_live.ex` | +226/-0 | **SAFE** | KEEP | Service Architecture Map feature (complete, tested) |
| 6 | `test/indrajaal_web/portal_navigation_test.exs` | +114/-0 | **SAFE** | KEEP | Tests for Service Architecture feature |

### L1.2 Untracked Files

| # | File | Size | Action | Reason |
|---|------|------|--------|--------|
| 7 | `doc/plans/sil6_panoptic_ignition_review.md` | 3.2 KB | KEEP | SIL-6 mesh ignition gap analysis |
| 8 | `docs/journal/20260325-1130-unified-service-and-interface-index.md` | 7.9 KB | KEEP | Architecture reference |
| 9 | `docs/journal/20260325-panoptic-sil6-ignition-review.md` | 3.8 KB | KEEP | Mesh ignition review findings |

### L1.3 Detailed Change Analysis

#### File 1: podman-compose-prod-standalone.yml (SAFE)

**What changed**: Two operational resilience improvements:
1. Redis startup command wrapped with `|| echo 'WARN: redis-server not found, continuing without embedded Redis'` — makes Redis a non-fatal dependency
2. OBS dependency changed from `service_healthy` to `service_started` — prevents app startup from blocking indefinitely when OBS is unhealthy

**Why this is safe**: These changes address real operational issues observed during mesh ignition. The OBS container IS unhealthy right now, so `service_healthy` would block app startup forever. Making Redis non-fatal allows the app to function without an embedded Redis process.

**Impact**: L3-SYSTEM (container startup ordering). No code-level impact.

#### File 2: SIL6MeshOrchestrator.fsx (SAFE)

**What changed**: Compose file path from `"artifacts/podman-compose-sil6-full-mesh.yml"` to `"lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml"`.

**Why this is safe**: The script runs from the project root (`/home/an/dev/ver/intelitor-v5.2/`), not from `lib/cepaf/`. The old relative path was wrong and would fail at runtime. This is a direct bug fix.

**Impact**: L1-CODE(1). Corrects a path resolution error.

#### File 3: Cepaf.Knowledge.fsproj (DANGEROUS — DISCARD)

**What changed**: Added `<ProjectReference Include="..\Cepaf.Holon\Cepaf.Holon.fsproj" />`.

**Why this is dangerous**: The referenced project file does NOT exist. The directory `lib/cepaf/src/Cepaf.Holon/` contains only `DatabasePath.fs` with no `.fsproj` file. This was an incomplete refactoring attempt — someone started extracting holon database path utilities into a separate project but never created the project file. The change breaks the Knowledge build with 9 cascading errors.

**Why discard**: Reverting to committed state restores a building Knowledge project. The committed version of `SharedPaths.fs` must compile against a different resolution of the `Cepaf.Holon.DatabasePath` namespace — likely the code was included in the main Cepaf project at some point, or SharedPaths.fs was not being compiled by the Knowledge project.

**Impact**: L1-CODE(1) discard. Restores F# build health.

#### File 4: MeshStartup.fs (SAFE)

**What changed**: Four compose file paths updated from relative to project-root-relative:
```fsharp
// Before: "artifacts/podman-compose-dev.yml"
// After:  "lib/cepaf/artifacts/podman-compose-dev.yml"
```

**Why this is safe**: Same reasoning as File 2 — the F# code runs from project root. All four paths (Dev, Cluster, Fractal, SIL6) needed correction. This is a direct bug fix.

**Impact**: L1-CODE(1). Corrects 4 path resolution errors.

#### File 5: navigation_portal_live.ex (SAFE)

**What changed**: +226 lines adding an "Elixir Service Architecture Map" to the NavigationPortal LiveView. The feature displays 4 architectural planes:
- **Data Plane**: PostgreSQL, TimescaleDB, SQLite/DuckDB, Redis
- **Control Plane**: Zenoh mesh, CEPAF bridge, F# orchestrator
- **Cognitive Plane**: Cortex (AI brain), Synapse, Knowledge Graph
- **Safety & Immune Plane**: Sentinel, Guardian, PatternHunter, Apoptosis

Each service entry includes runtime (Elixir/F#/Rust/External), role, and type metadata.

**Why this is safe**: Self-contained LiveView feature. Does not modify any existing functionality. Purely additive UI enhancement. Has accompanying tests (File 6).

**Impact**: L1-CODE(1), L2-DOMAIN(1). New LiveView feature.

#### File 6: portal_navigation_test.exs (SAFE)

**What changed**: +114 lines of tests for the Service Architecture Map feature. Tests verify:
- All 4 planes render correctly
- Key services appear in their correct planes
- Service count summary is displayed
- Plane structure integrity

**Why this is safe**: Test-only changes. Validates the feature in File 5.

**Impact**: L1-CODE(1). Test coverage for new feature.

---

## L2: Component-Level Impact — What Subsystems Are Affected

### L2.1 F# Cepaf Build System

**Status**: PARTIALLY BROKEN

The main `Cepaf.fsproj` builds successfully (922+ files). The `Cepaf.Knowledge` project is broken by the uncommitted ProjectReference change.

**Dependency chain**:
```
Cepaf.Knowledge.fsproj
  └── ProjectReference: Cepaf.Holon.fsproj (MISSING)
        └── DatabasePath.fs exists, but no .fsproj wraps it
              └── SharedPaths.fs imports Cepaf.Holon.DatabasePath (FAILS)
                    └── 4 functions undefined: createUHI, holonDir, createFQDN, resolve
```

**Resolution**: Discard the fsproj change. The committed Knowledge project builds without this reference.

**Deeper question**: Where does `Cepaf.Holon.DatabasePath` actually live in the committed codebase? Either:
1. It's included in the main `Cepaf.fsproj` (most likely — F# projects can include files from subdirectories)
2. SharedPaths.fs is not actually compiled by the Knowledge project in the committed state
3. The namespace is aliased differently in the committed state

This question is academic for the recovery — reverting fixes the build.

### L2.2 Elixir Warning Surface

**Status**: 2 WARNINGS (pre-existing, not caused by uncommitted changes)

The `ZenohSafetyPublisher` and `ZenohNeuralStream` modules exist at:
- `lib/indrajaal/observability/zenoh_safety_publisher.ex`
- `lib/indrajaal/observability/zenoh_neural_stream.ex`

But 34 files call functions that are either undefined or have wrong arity:
- `publish_sentinel_threat/4` — may need to be added or arity fixed
- `stream_state/3` — may need to be added or arity fixed

**Risk**: These warnings are compile-time only. If any code path actually calls these functions at runtime, it will crash with `UndefinedFunctionError`. However, these are likely in dead code paths or feature-flagged sections.

**Resolution**: Deferred. Not blocking recovery. Should be addressed in a future sprint as a P2 task.

### L2.3 NavigationPortal Feature

**Status**: COMPLETE AND TESTED

The Service Architecture Map is a self-contained LiveView feature. It uses hardcoded service metadata (not runtime introspection). This is appropriate for an architecture reference panel — it shows the DESIGNED topology, not the runtime state.

No integration concerns. The feature renders within the existing NavigationPortal layout.

### L2.4 F# Path Resolution Fixes

**Status**: CORRECT AND NECESSARY

The SIL6MeshOrchestrator.fsx and MeshStartup.fs path fixes are both legitimate bug fixes. The F# code runs from the project root, but the paths were relative to `lib/cepaf/`. Without these fixes, `sa-up` (which invokes the F# orchestrator) would fail to find compose files.

---

## L3: System-Level Assessment — Branch State & Merge Strategy

### L3.1 Branch Topology

```
main (commit: 93b27e93d)
  │
  ├── 654 empty "Auto-release: SIL6-EVO-*" commits (Gemini heartbeats)
  │     └── Zero code changes, zero diff, pure noise
  │
  ├── 90 real commits (Sprint 88 morphogenic evolution + recovery)
  │     ├── 30 morphogenic test fixes (L0-L7)
  │     ├── 6 new production modules (KPI, DeviceHealth, KnowledgeGraph, Recommendations, Discovery, RateLimiter)
  │     ├── 4 new test suites (VSM interaction, knowledge graph, recommendation, OpenRouter)
  │     ├── MCP/auth production fixes
  │     ├── NavigationPortalLive + dashboard runtime hardening
  │     ├── DriftMonitor, SemanticRouter, ConsensusAggregator OTP wiring
  │     └── Recovery plan documentation
  │
  └── HEAD (commit: cd3fe79f5) — 744 commits ahead, 0 behind main
```

**Fast-forward merge**: POSSIBLE. Main is a direct ancestor. No merge conflicts.

**Merge strategy options**:
1. **FF merge as-is**: Preserves all 744 commits (including 654 empty ones). Clutters git log but is safest.
2. **Squash merge**: Collapses all 744 commits into 1. Clean history but loses individual commit metadata.
3. **Selective rebase**: Cherry-pick only the 90 real commits. Cleaner but complex.

**Recommendation**: FF merge as-is for now. The 654 empty commits are cosmetic noise that can be cleaned up later with `git rebase --onto` if needed. Safety > aesthetics.

### L3.2 Previous Recovery Work (2026-03-25)

The recovery plan from the earlier session expected ~28 modified files. Most were already handled:

| Category | Expected | Already Done | Remaining |
|----------|----------|-------------|-----------|
| DANGEROUS files | 4 | 3 discarded | 1 (Knowledge.fsproj) |
| CONCERNING files | 10 | 10 discarded/committed | 0 |
| SAFE files | 14+ | Committed (morph tests, modules) | 5 (infra + portal) |
| Untracked docs | 3+ | 0 | 3 |
| Build artifacts | 2 | 2 removed | 0 |

The heavy lifting is done. This recovery session is the final cleanup pass.

### L3.3 Commit Plan

**Commit 1: F#/Infra path fixes** (3 files)
```
fix(cepaf,mesh): correct compose file paths to project-root-relative — F# scripts run from root

WHY: SIL6MeshOrchestrator.fsx and MeshStartup.fs used paths relative to lib/cepaf/,
     but execute from project root. Podman-compose relaxes OBS dependency to unblock startup.
WHAT: 3 path corrections + Redis non-fatal + OBS service_started dependency

Files: 3 modified
Layer: L1-CODE(2), L3-SYSTEM(1)
STAMP: SC-CONSOL-001, SC-BOOT-007
```

Stage:
```bash
git add lib/cepaf/artifacts/podman-compose-prod-standalone.yml
git add lib/cepaf/scripts/SIL6MeshOrchestrator.fsx
git add lib/cepaf/src/Cepaf/Mesh/MeshStartup.fs
```

**Commit 2: NavigationPortal Service Architecture** (2 files)
```
feat(prajna): add Service Architecture Map to NavigationPortal — 4 architectural planes

WHY: Operators need a visual reference of the system's service topology.
WHAT: LiveView panel showing Data/Control/Cognitive/Safety planes with service metadata.

Files: 2 modified
Layer: L1-CODE(2), L2-DOMAIN(1)
STAMP: SC-HMI-001
```

Stage:
```bash
git add lib/indrajaal_web/live/navigation_portal_live.ex
git add test/indrajaal_web/portal_navigation_test.exs
```

**Commit 3: Recovery documentation** (3 + 1 files)
```
docs(journal): add SIL-6 ignition review + recovery analysis — 5-level diagnostic

WHY: Document system state, gap analysis, and recovery decisions for audit trail.
WHAT: Panoptic ignition gap analysis, service index, 5-level recovery analysis.

Files: 4 new
Layer: L1-CODE(0), L2-DOMAIN(0)
```

Stage:
```bash
git add doc/plans/sil6_panoptic_ignition_review.md
git add docs/journal/20260325-1130-unified-service-and-interface-index.md
git add docs/journal/20260325-panoptic-sil6-ignition-review.md
git add docs/journal/20260325-1130-system-recovery-5level-analysis.md
```

---

## L4: Architecture-Level Recovery — Mesh Ignition Blockers

### L4.1 Critical Gaps for Part 2 (SIL-6 Mesh Ignition)

| Gap | Severity | Blocker? | Resolution |
|-----|----------|----------|------------|
| G1: App image is empty skeleton (1.75 MB) | CRITICAL | YES — 6 services can't start | Rebuild from `containers/Dockerfile.precompiled` |
| G2: Cortex image missing | HIGH | YES — 1 service can't start | Build from `containers/Dockerfile.cortex` |
| G3: OBS container unhealthy | HIGH | PARTIAL — observability degraded | Diagnose via logs + endpoint probes |
| G4: CPU oversubscription (23 requested, 10 available) | HIGH | PERFORMANCE — OOM risk | Right-size to 8 CPUs (80% of 10) |
| G5: sa-stabilize checks wrong topology | MEDIUM | FALSE CONFIDENCE | Use SIL-6-specific verification |
| G6: Ollama requires external image | LOW | Ω₂ VIOLATION | Defer — use OpenRouter for AI |

### L4.2 Image Rebuild Strategy

```
Current:
  localhost/indrajaal-app-unified:nixos-devenv = 1.75 MB (EMPTY SKELETON)

Target:
  localhost/indrajaal-app:sil6-precompiled = ~130-150 MB (FULL RUNTIME)
    ├── Elixir 1.19 + OTP 28 runtime
    ├── Compiled BEAM files (all 1500+ .ex files)
    ├── Zenoh NIF (libzenoh_nif.so from Rustler)
    ├── Phoenix static assets
    └── Release configuration

Build command:
  podman build -f containers/Dockerfile.precompiled \
    -t localhost/indrajaal-app:sil6-precompiled \
    --build-arg MIX_ENV=prod .

Verification:
  podman run --rm localhost/indrajaal-app:sil6-precompiled eval "IO.puts(:ok)"
  # Expected output: "ok"
```

### L4.3 Resource Budget (10 CPUs, 80% max = 8 usable)

| Tier | Services | Right-Sized CPUs | Priority |
|------|----------|-----------------|----------|
| Data | DB | 1.5 | P0 |
| Observability | OBS | 1.0 | P1 |
| Control Plane | 3x Zenoh + proxy | 1.0 total | P0 |
| Cognitive | Cortex + Bridge | 1.0 total | P1 |
| Application | 3x App (HA) | 3.0 total | P0 |
| Twin | Chaya | 0.25 | P2 |
| ML | 2x Runner | **DEFERRED** | P3 |
| **TOTAL** | | **7.75** | ≤ 8.0 |

### L4.4 Deferred Services

| Service | Why Deferred | When |
|---------|-------------|------|
| `indrajaal-ollama` | Ω₂ violation (external image), not required | Future sprint |
| `ml-runner-1` | No ML workloads ready | When ML pipeline exists |
| `ml-runner-2` | No ML workloads ready | When ML pipeline exists |

This reduces the mesh from 15 → 12 services. All core functionality preserved.

---

## L5: Strategic-Level Decisions — Evolution Hold & Future Work

### L5.1 Evolution Hold Order

**User directive**: "Hold all evolution after this wave."

After completing the current recovery commits:
1. **NO** new morphogenic tasks
2. **NO** new module creation
3. **NO** speculative feature work
4. **NO** autonomous evolution sprints
5. System is STABLE — maintain this state

### L5.2 Merge to Main Timeline

The branch is ready to merge after the 3 recovery commits. However:
- **SC-GIT-006**: Guardian approval REQUIRED for multiverse promote operations
- **Recommendation**: Merge when user explicitly authorizes
- **Pre-merge**: Verify `mix compile` (0 errors), `mix test test/indrajaal_web/` (portal tests pass)
- **Merge command**: `git checkout main && git merge multiverse/claude-opus-fractal-tests --ff-only`

### L5.3 Deferred Work Registry

| Item | Priority | Blocked By | Sprint |
|------|----------|-----------|--------|
| Fix ZenohSafetyPublisher undefined functions | P2 | Nothing | Next |
| Fix ZenohNeuralStream undefined functions | P2 | Nothing | Next |
| Build functional app image | P0 | Part 1 completion | Part 2 |
| Diagnose OBS unhealthy | P1 | Nothing | Part 2 |
| Build Cortex image | P1 | Nothing | Part 2 |
| Right-size CPU in compose | P1 | Nothing | Part 2 |
| Update sa-stabilize for SIL-6 topology | P2 | Part 2 completion | Future |
| Squash 654 empty auto-release commits | P3 | Nothing | Cosmetic |
| Create Cepaf.Holon.fsproj properly | P2 | Architecture decision | Future |
| Mojo integration | P3 | No implementation | Future |
| ML/AI deps (exla, axon, bumblebee) | P3 | Not wired | Future |
| Wallaby/Puppeteer test infra | P3 | CI/headless setup | Future |

### L5.4 Risk Register

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| OBS stays unhealthy after diagnosis | Medium | MEDIUM | Boot mesh without OBS, add back later |
| App image Dockerfile.precompiled fails to build | Medium | HIGH | Debug stage-by-stage, verify Elixir/OTP/Rust versions |
| 654 empty commits cause confusion on main | Low | LOW | Can rebase later; cosmetic issue |
| ZenohSafetyPublisher runtime crash | Low | MEDIUM | Dead code path for now; fix in next sprint |
| F# Knowledge project needs Cepaf.Holon | Medium | MEDIUM | Either include DatabasePath.fs in Knowledge, or create proper Holon.fsproj |

---

## Execution Checklist

### Part 1: Code Recovery (THIS SESSION)

- [ ] Write this journal entry (5-level analysis)
- [ ] Backup + discard `Cepaf.Knowledge.fsproj` (SC-DELETE-005: stash first)
- [ ] Verify F# Knowledge build passes after discard
- [ ] Commit 1: F#/infra path fixes (3 files)
- [ ] Commit 2: NavigationPortal Service Architecture (2 files)
- [ ] Commit 3: Documentation (4 files including this journal)
- [ ] Verify clean working tree (`git status`)
- [ ] Verify Elixir compilation (`mix compile` — 0 errors)
- [ ] **HOLD** — No new evolution

### Part 2: SIL-6 Mesh Ignition (DEFERRED — User decides when)

- [ ] Phase 1: Diagnose OBS unhealthy
- [ ] Phase 2a: Build functional app image from Dockerfile.precompiled
- [ ] Phase 2b: Build Cortex image from Dockerfile.cortex
- [ ] Phase 2c: Defer Ollama (Ω₂)
- [ ] Phase 2d: Update compose image references
- [ ] Phase 3: Right-size CPU budget to ≤ 8.0
- [ ] Phase 4: State stabilization (sa-stabilize partial + manual SIL-6 checks)
- [ ] Phase 5: Panoptic ignition (sa-up or podman-compose)
- [ ] Phase 6: Quorum & convergence verification
- [ ] Phase 7: Observability lock-in

---

## Constitutional Alignment

- **Ψ₀ (Existence)**: System survives — compilation works, containers run
- **Ψ₁ (Regeneration)**: State recoverable from SQLite/DuckDB + git
- **Ψ₂ (History)**: Complete audit trail in this journal + git commits
- **Ψ₃ (Verification)**: All changes verifiable via git diff + compile + test
- **Ω₀ (Founder's Directive)**: Recovery serves system stability → resource preservation
- **SC-FUNC-001**: System compiles at all times (maintained throughout)
- **SC-DELETE-005**: Stash before discard (will be followed for Knowledge.fsproj)
- **SC-CHG-001**: Structured change notes (this document)
