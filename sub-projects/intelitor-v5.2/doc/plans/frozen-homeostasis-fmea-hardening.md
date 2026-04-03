# Frozen Homeostasis Protocol — Comprehensive FMEA & Hardening Plan

**Date**: 2026-03-25
**Version**: 1.0.0
**Status**: ACTIVE — Documentation Only (No Code/Infra Mutations)
**Branch**: `multiverse/claude-opus-fractal-tests` (748+ ahead of main)
**Compliance**: IEC 61508 SIL-6 Biomorphic Extended
**Protocol**: Frozen Homeostasis — ALL changes require recoverability + clean room testing + manual approval

---

## 0. Executive Summary

Following successful SIL-6 Panoptic Mesh ignition (15 containers running, HOMEOSTASIS_ACHIEVED broadcast via Zenoh on 2026-03-25), a comprehensive system audit identified **87 issues** across 7 categories. This document catalogs every failure mode with FMEA Risk Priority Numbers (RPN), defines new STAMP constraints (SC-HOMEOSTASIS-*, SC-CLEANROOM-*, SC-RECOV-*), and establishes recoverability procedures for each proposed remediation.

**The Frozen Homeostasis Protocol mandates**: No change to the running mesh without (a) recoverability identified, (b) clean room testing in multiverse worktree, (c) manual approval per change.

---

## 1. FMEA Methodology

**RPN = Severity × Occurrence × Detection**

| Rating | Severity (S) | Occurrence (O) | Detection (D) |
|--------|-------------|----------------|---------------|
| 10 | System death / data loss | Certain on every boot | Undetectable until failure |
| 9 | Safety function lost | Almost certain | Detection only post-incident |
| 8 | Major function lost | High | Detected only by deep audit |
| 7 | Function degraded | Moderately high | Detected by automated test |
| 6 | Subsystem impaired | Moderate | Detected by health check |
| 5 | Minor function lost | Low-moderate | Detected by monitoring |
| 4 | Inconvenience | Low | Detected by warning |
| 3 | Cosmetic / doc gap | Very low | Detected by review |
| 2 | Negligible | Remote | Obvious on inspection |
| 1 | None | Nearly impossible | Immediately visible |

**Action Thresholds**:
- RPN ≥ 200: **P0-CRITICAL** — Must remediate before any new work
- RPN ≥ 100: **P1-HIGH** — Remediate in next sprint
- RPN ≥ 50: **P2-MEDIUM** — Schedule for remediation
- RPN < 50: **P3-LOW** — Track, remediate opportunistically

---

## 2. FMEA Register — All 87 Issues

### Category A: Topology Inconsistencies (12 Issues)

| ID | Failure Mode | S | O | D | RPN | Layer | Recoverability |
|----|-------------|---|---|---|-----|-------|----------------|
| A-001 | **TopologyValidator hardcodes 5-node fractal-cluster** (db, obs, app-1/2/3) but actual SIL-6 mesh has 15 containers — Zenoh routers, bridge, cortex, chaya, ml-runners all missing | 8 | 9 | 7 | **504** | L1-CODE | `git revert` — update `@fractal_cluster_dependencies` in topology_validator.ex |
| A-002 | **DigitalTwin default_genotypes** defines 5-node cluster topology (db, obs, app-1/2/3) with `indrajaal-cluster-net` network — doesn't match SIL-6 `indrajaal-sil6-mesh` network | 7 | 9 | 7 | **441** | L1-CODE | `git revert` — update digital_twin.ex default_genotypes/0 |
| A-003 | **Deployment.Config** defines 3-container topology (db, obs, app) with demo-era image names (`indrajaal-sopv51-elixir-app`, `indrajaal-prometheus-demo`) | 7 | 9 | 6 | **378** | L1-CODE | `git revert` — update config.ex containers/1 |
| A-004 | **SIL-6 compose file** comments updated to "15-Container Architecture" matching actual service count | 4 | 10 | 3 | **120** | L0-DOC | RESOLVED — compose file comments updated |
| A-005 | **SIL-6 compose** architecture diagram (line 979) says "6 Containers" — outdated by 3+ generations | 3 | 10 | 3 | **90** | L0-DOC | Edit compose file comments only |
| A-006 | **SIL-6 compose** resource summary table (line 1035) lists 6 containers — same generation lag | 3 | 10 | 3 | **90** | L0-DOC | Edit compose file comments only |
| A-007 | **prod-standalone compose** says "3 Container Architecture" but defines 4 services (db, obs, app, zenoh-router) | 3 | 10 | 3 | **90** | L0-DOC | Edit compose file comments only |
| A-008 | **MeshStartup.fs** `defaultConfig` defaults to `Dev` RunMode, not `SIL6` — accidental dev-mode boot in production | 7 | 4 | 5 | **140** | L1-CODE | `git revert` — change default to SIL6 in MeshStartup.fs |
| A-009 | **sa-stabilize.fsx** validates an 8-service topology (registry:5000, db2:5434, liveview:4002) that doesn't exist in SIL-6 mesh | 7 | 8 | 6 | **336** | L1-CODE | Update sa-stabilize.fsx topology map |
| A-010 | **16 compose files** exist in artifacts/ — no clear deprecation lifecycle, any could be accidentally referenced | 5 | 5 | 5 | **125** | L0-DOC | Add DEPRECATED headers to legacy files |
| A-011 | **HA full-mesh compose** uses different images (`indrajaal-timescaledb-demo`, `indrajaal-obs-unified`) than SIL-6 compose (`indrajaal-db:nixos-pg17`, `indrajaal-obs:nixos-otel`) | 6 | 5 | 6 | **180** | L2-INFRA | `git revert` — standardize image names or deprecate |
| A-012 | **Genotype cookie mismatch**: DigitalTwin uses `fractal_mesh_cookie`, SIL-6 compose uses `indrajaal_prod_cookie`, prod-standalone uses `SIL6_SAFETY_CRITICAL_COOKIE_DO_NOT_SHARE` — nodes CANNOT cluster across topologies | 8 | 7 | 6 | **336** | L3-SYSTEM | Standardize cookie across all artifacts |

### Category B: Security Issues (8 Issues)

| ID | Failure Mode | S | O | D | RPN | Layer | Recoverability |
|----|-------------|---|---|---|-----|-------|----------------|
| B-001 | **SIL-6 compose** hardcodes `POSTGRES_PASSWORD: postgres` (line ~90) | 9 | 10 | 3 | **270** | L3-SYSTEM | Replace with env var `${POSTGRES_PASSWORD}` |
| B-002 | **SIL-6 compose** hardcodes `GF_SECURITY_ADMIN_PASSWORD: indrajaal` | 7 | 10 | 3 | **210** | L3-SYSTEM | Replace with env var |
| B-003 | **SIL-6 compose** hardcodes `SECRET_KEY_BASE: production_equivalent_secret_key_base_64_chars_minimum_here_change_me` | 9 | 10 | 3 | **270** | L3-SYSTEM | Replace with env var |
| B-004 | **SIL-6 compose** hardcodes `RELEASE_COOKIE: indrajaal_prod_cookie` | 8 | 10 | 3 | **240** | L3-SYSTEM | Replace with env var |
| B-005 | **Deployment.Config** hardcodes DB password `indrajaal_dev` and secret key base | 7 | 10 | 4 | **280** | L1-CODE | Use Application.get_env/3 |
| B-006 | **DigitalTwin default_genotypes** hardcodes `POSTGRES_PASSWORD: postgres` and `SECRET_KEY_BASE: fractal_cluster_secret_key_base` | 7 | 10 | 5 | **350** | L1-CODE | Use runtime config |
| B-007 | **prod-standalone compose** hardcodes `SIL6_SAFETY_CRITICAL_COOKIE_DO_NOT_SHARE` as RELEASE_COOKIE | 8 | 10 | 3 | **240** | L3-SYSTEM | Use env var |
| B-008 | **Deployment.Config** hardcodes `DATABASE_URL` with credentials inline | 7 | 10 | 4 | **280** | L1-CODE | Use env var interpolation |

### Category C: Resource Allocation Issues (10 Issues)

| ID | Failure Mode | S | O | D | RPN | Layer | Recoverability |
|----|-------------|---|---|---|-----|-------|----------------|
| C-001 | **OBS resource reversal**: SIL-6 compose gives OBS 2G/0.5CPU; prod-standalone gives 10G/6CPU — SIL-6 OBS chronically unhealthy | 8 | 10 | 6 | **480** | L2-INFRA | Edit compose resource limits |
| C-002 | **App asymmetry**: App-1 gets 20G/2CPU, App-2 gets 2G/1CPU, App-3 gets 1G/0.5CPU — App-2/3 will OOM under load | 7 | 7 | 5 | **245** | L2-INFRA | Equalize app resources |
| C-003 | **CPU oversubscription**: SIL-6 compose requests ~23 CPUs total; system has 10 physical CPUs (80% budget = 8) | 7 | 8 | 4 | **224** | L2-INFRA | Right-size per Phase 3 of plan |
| C-004 | **HA compose** gives each app node 8G/6CPU (total 24G/18CPU for apps alone) — exceeds most dev machines | 6 | 6 | 4 | **144** | L2-INFRA | Right-size or document minimum hw |
| C-005 | **DigitalTwin genotype** defines OBS with 10G/6CPU but SIL-6 compose gives it 2G/0.5CPU — genotype ≠ phenotype | 7 | 9 | 7 | **441** | L1-CODE | Reconcile genotype to match compose |
| C-006 | **Cortex resource budget**: SIL-6 gives cortex 4G/1CPU but cortex runs `sleep 3600` — wasted resources | 4 | 10 | 3 | **120** | L2-INFRA | Defer cortex or reduce resources |
| C-007 | **ML runners**: ml-runner-1/2 compile app then `sleep infinity` — consuming 2G each for no workload | 4 | 10 | 3 | **120** | L2-INFRA | Defer or use restart: "no" |
| C-008 | **Ollama**: 8G reserved for ollama container with no implementation | 5 | 10 | 3 | **150** | L2-INFRA | Defer or use restart: "no" |
| C-009 | **Total RAM**: SIL-6 compose requests ~52G total; system may have 32-64G — OOM risk | 6 | 6 | 4 | **144** | L2-INFRA | Audit actual host RAM, right-size |
| C-010 | **DigitalTwin genotype** hardcodes IP addresses (172.30.0.x) that don't match SIL-6 network (172.28.0.x) | 6 | 9 | 6 | **324** | L1-CODE | Update IPs or use DNS names |

### Category D: Non-Functional / Placeholder Components (8 Issues)

| ID | Failure Mode | S | O | D | RPN | Layer | Recoverability |
|----|-------------|---|---|---|-----|-------|----------------|
| D-001 | **Cortex entrypoint override**: Compose replaces `dotnet Cepaf.dll --cortex` with `bash -c "echo 'Cortex standby' && while true; do sleep 3600; done"` — Cortex never runs | 6 | 10 | 3 | **180** | L2-INFRA | Implement --cortex CLI or defer container |
| D-002 | **ML runners**: Both execute `mix compile && sleep infinity` — no actual ML workload | 4 | 10 | 3 | **120** | L2-INFRA | Defer until ML pipeline exists |
| D-003 | **App-dev image**: Sets `MIX_ENV=prod` but mounts source (`../../../:/workspace:z`) — prod env with dev workflow | 5 | 10 | 5 | **250** | L2-INFRA | Set MIX_ENV=dev or build precompiled |
| D-004 | **Ollama**: Uses `ollama/ollama:latest` — external pull violates Ω₂ (localhost-only) | 6 | 10 | 4 | **240** | L3-SYSTEM | Pull, retag to localhost/, or defer |
| D-005 | **prod-standalone** uses broken `indrajaal-app-unified:nixos-devenv` image (1.75MB NixOS skeleton, no Elixir runtime) | 9 | 8 | 5 | **360** | L2-INFRA | Update to `indrajaal-app-dev:sil6` |
| D-006 | **9 deployment modules** prefixed with `_` (underscore): TrafficSplitter, UserTargeting, GrafanaManager, etc. — disabled/dead code | 3 | 10 | 2 | **60** | L1-CODE | Document status or remove |
| D-007 | **Deployment.Config** references legacy image names (`indrajaal-sopv51-elixir-app`, `indrajaal-prometheus-demo`) that don't exist | 6 | 7 | 5 | **210** | L1-CODE | Update to current image names |
| D-008 | **OBS container** running but persistently unhealthy (broken NixOS skeleton image for OBS) | 8 | 10 | 2 | **160** | L2-INFRA | Rebuild OBS image or defer |

### Category E: Script & Command Issues (20 Issues — Top Items)

| ID | Failure Mode | S | O | D | RPN | Layer | Recoverability |
|----|-------------|---|---|---|-----|-------|----------------|
| E-001 | **sa-stabilize** validates wrong topology (8 legacy services) giving false confidence | 7 | 8 | 7 | **392** | L1-CODE | Update topology map in fsx |
| E-002 | **sa-up** calls `dotnet fsi SIL6MeshOrchestrator.fsx` but SC-CEP-005 mandates pre-compiled binaries for prod | 6 | 8 | 5 | **240** | L1-CODE | Pre-compile orchestrator |
| E-003 | **sa-clean** maps to `mesh clean` which destroys ALL volumes — no selective cleanup | 8 | 4 | 4 | **128** | L1-CODE | Add selective mode or confirmation |
| E-004 | **sa-scour** is alias for `sa-clean` (nuclear option) — too easy to invoke accidentally | 8 | 3 | 3 | **72** | L0-CONFIG | Add confirmation prompt |
| E-005 | **sa-health** runs FPPS validation but FPPS requires full OBS pipeline — fails if OBS unhealthy | 6 | 7 | 5 | **210** | L1-CODE | Graceful degradation when OBS down |
| E-006 | **sa-checkpoint** calls non-existent `checkpoint` subcommand of SIL6MeshOrchestrator | 6 | 5 | 6 | **180** | L1-CODE | Implement checkpoint subcommand |
| E-007 | **sa-verify** calls non-existent `verify` subcommand | 6 | 5 | 6 | **180** | L1-CODE | Implement verify subcommand |
| E-008 | **sa-emergency** calls non-existent `emergency` subcommand | 9 | 3 | 6 | **162** | L1-CODE | Implement emergency stop (SC-EMR-057: <5s) |
| E-009 | **sa-monitor** calls non-existent `monitor` subcommand | 4 | 5 | 6 | **120** | L1-CODE | Implement or document as future |
| E-010 | **devenv.nix** `sa-*` commands don't validate F# compilation before invoking fsx scripts | 5 | 8 | 5 | **200** | L0-CONFIG | Add pre-check: `dotnet build` |
| E-011 | **test** command doesn't set `MIX_ENV=test` explicitly (relies on mix alias) | 4 | 4 | 3 | **48** | L0-CONFIG | Add explicit `MIX_ENV=test` |
| E-012 | **compile** command doesn't log to `./data/tmp/1-compile.log` as mandated by Ω₁ | 4 | 8 | 4 | **128** | L0-CONFIG | Add `tee -a ./data/tmp/1-compile.log` |
| E-013 | **cepaf-build** only builds Cepaf.fsproj but system has 10+ F# projects | 5 | 7 | 5 | **175** | L0-CONFIG | Build solution or all projects |
| E-014 | **cockpitf** uses `dotnet fsi` for deployment (fsx interpretation violates SC-CEP-005) | 6 | 7 | 5 | **210** | L0-CONFIG | Pre-compile cockpit commands |
| E-015 | **constraint-sync** rebuilds binary on every invocation even if already built | 3 | 8 | 2 | **48** | L0-CONFIG | Check binary exists before build |
| E-016 | **No input validation** on sa-plan arguments (task IDs not verified before update) | 5 | 5 | 5 | **125** | L1-CODE | Add input validation |
| E-017 | **sa-logs** defaults to app-1 but doesn't verify container exists | 4 | 5 | 4 | **80** | L0-CONFIG | Check container before logs |
| E-018 | **chaya-sync** is DEPRECATED (AOR-SYNC-PLAN-010) but still callable from devenv | 6 | 4 | 4 | **96** | L0-CONFIG | Remove or add deprecation warning |
| E-019 | **zenoh-*-sub** commands use fsx scripts — may fail if dotnet/fsi not available | 4 | 5 | 5 | **100** | L0-CONFIG | Pre-compile or add fallback |
| E-020 | **help** command is just text — doesn't dynamically list available commands | 2 | 10 | 2 | **40** | L0-CONFIG | Generate help from devenv.nix |

### Category F: Fractal Test Coverage Gaps (14 Issues)

| ID | Failure Mode | S | O | D | RPN | Layer | Recoverability |
|----|-------------|---|---|---|-----|-------|----------------|
| F-001 | **L7 Federation tests**: 0% coverage — no tests exist for cross-holon federation | 7 | 8 | 8 | **448** | L7-FED | Write federation tests in clean room |
| F-002 | **L6 Cluster tests**: ~20% — only basic HA mesh chaos tests exist | 6 | 7 | 7 | **294** | L6-CLUSTER | Write cluster consensus tests |
| F-003 | **L5 Node tests**: ~40% — missing Zenoh NIF integration, OTEL pipeline tests | 5 | 6 | 6 | **180** | L5-NODE | Write node-level tests |
| F-004 | **L4 Container tests**: ~60% — topology_boot_test and deployment_modules_test exist but don't cover SIL-6 15-node topology | 5 | 6 | 5 | **150** | L4-CNT | Update topology tests |
| F-005 | **L3 Holon tests**: ~70% — good coverage but missing MCP, Sentinel integration | 4 | 5 | 5 | **100** | L3-HOLON | Write integration tests |
| F-006 | **L2 Component tests**: ~80% — domain-level tests good but morphogenic tests had 30 failures (fixed in Sprint 88) | 3 | 4 | 4 | **48** | L2-COMP | Monitor morphogenic suite |
| F-007 | **L1 Function tests**: ~90% — good unit coverage | 2 | 3 | 3 | **18** | L1-FUNC | Maintain |
| F-008 | **SIL-6 mesh integration test** (mesh_integration_live_test.exs) requires running containers — can't run in CI | 5 | 8 | 6 | **240** | L4-CNT | Add container-less mock mode |
| F-009 | **F# test coverage**: 549 Expecto tests cover ~60% of F# code — key gaps in orchestrator, planning | 5 | 6 | 6 | **180** | L1-FUNC | Write F# tests |
| F-010 | **No mutation testing**: No PIT/mutant framework for either Elixir or F# | 4 | 10 | 7 | **280** | L2-COMP | Evaluate StreamData + mutation |
| F-011 | **No chaos testing in CI**: Chaos tests exist (ha_mesh_chaos_test.exs) but tagged :requires_containers | 5 | 8 | 5 | **200** | L6-CLUSTER | Add chaos test pipeline |
| F-012 | **Formal verification gaps**: Only 2 Agda proofs (GraphProperties, AcyclicityProofs) — should cover safety invariants | 6 | 8 | 7 | **336** | L7-FED | Write more Agda/Quint specs |
| F-013 | **BDD coverage**: 85 feature files exist but many are stubs or not wired to step definitions | 4 | 7 | 5 | **140** | L3-HOLON | Wire feature files to step defs |
| F-014 | **Overall grade C+**: Composite fractal test score below target B+ for GA release | 5 | 8 | 5 | **200** | ALL | Systematic test wave |

### Category G: .claude Directory & Documentation Issues (15 Issues)

| ID | Failure Mode | S | O | D | RPN | Layer | Recoverability |
|----|-------------|---|---|---|-----|-------|----------------|
| G-001 | **CLAUDE.md references v21.3.0** but mix.exs may differ — version drift between spec and code | 3 | 6 | 3 | **54** | L0-DOC | Verify and align versions |
| G-002 | **15-Container Architecture** now referenced throughout CLAUDE.md and all active artifacts | 4 | 10 | 3 | **120** | L0-DOC | RESOLVED — full 14→15 propagation complete |
| G-003 | **5 .claude/rules/*.md files** reference 3-container or 4-container topologies | 3 | 8 | 4 | **96** | L0-DOC | Update topology refs in rules |
| G-004 | **.claude/rules/biomorphic-mode.md** references 25-agent architecture but actual swarm may differ | 3 | 6 | 4 | **72** | L0-DOC | Verify agent count |
| G-005 | **GEMINI.md** may have version/topology drift from CLAUDE.md (should be synced) | 3 | 7 | 4 | **84** | L0-DOC | Cross-check GEMINI.md |
| G-006 | **16 compose files** in artifacts/ — no inventory document listing which are active vs deprecated | 4 | 8 | 4 | **128** | L0-DOC | Create compose inventory |
| G-007 | **5 Dockerfiles** in artifacts/ — no clear mapping to which compose files use which | 3 | 7 | 4 | **84** | L0-DOC | Add to compose inventory |
| G-008 | **sa-* command help** doesn't match devenv.nix reality (some sa-* commands reference non-existent subcommands) | 4 | 7 | 5 | **140** | L0-DOC | Audit help output vs implementation |
| G-009 | **46 F# scripts** in lib/cepaf/scripts/ — no inventory or status tracking | 3 | 8 | 4 | **96** | L0-DOC | Create F# script inventory |
| G-010 | **recovery plan** references Dockerfile.precompiled for app image but actual build used Dockerfile.app-dev | 3 | 5 | 3 | **45** | L0-DOC | Update plan to match reality |
| G-011 | **AGENT_BOOTSTRAP.md** not verified for currency with current system state | 3 | 6 | 5 | **90** | L0-DOC | Audit bootstrap doc |
| G-012 | **30+ journal files from 2026-03-25** — not indexed or cross-referenced | 2 | 10 | 2 | **40** | L0-DOC | Index in docs/journal/INDEX.md |
| G-013 | **SMRITI knowledge ingestion** not yet done for journal files (per user memory directive) | 4 | 8 | 6 | **192** | L3-HOLON | Implement SMRITI ingestion pipeline |
| G-014 | **Constraint sync cache** (`.claude/constraint_sync_cache.json`) may be stale after Sprint 88 changes | 3 | 6 | 3 | **54** | L0-CONFIG | Re-run constraint-sync |
| G-015 | **Plan file** (`mighty-spinning-frog.md`) has Part 1 complete but Part 2 checklist items partially checked | 2 | 8 | 2 | **32** | L0-DOC | Update plan file |

---

## 3. RPN Summary by Priority

### P0-CRITICAL (RPN ≥ 200) — 23 Issues

| Rank | ID | RPN | Description | Category |
|------|----|-----|-------------|----------|
| 1 | A-001 | 504 | TopologyValidator hardcodes 5-node topology | Topology |
| 2 | C-001 | 480 | OBS resource reversal (2G vs 10G) | Resources |
| 3 | F-001 | 448 | L7 Federation tests: 0% coverage | Testing |
| 4 | A-002 | 441 | DigitalTwin genotype 5-node mismatch | Topology |
| 5 | C-005 | 441 | Genotype OBS 10G ≠ compose OBS 2G | Resources |
| 6 | E-001 | 392 | sa-stabilize validates wrong topology | Scripts |
| 7 | A-003 | 378 | Deployment.Config 3-container topology | Topology |
| 8 | D-005 | 360 | prod-standalone uses broken NixOS image | Placeholder |
| 9 | B-006 | 350 | DigitalTwin hardcodes passwords | Security |
| 10 | A-012 | 336 | Cookie mismatch across 3 artifacts | Topology |
| 11 | A-009 | 336 | sa-stabilize validates legacy services | Topology |
| 12 | F-012 | 336 | Only 2 formal verification proofs | Testing |
| 13 | C-010 | 324 | DigitalTwin hardcodes wrong IPs | Resources |
| 14 | F-002 | 294 | L6 Cluster tests: ~20% coverage | Testing |
| 15 | B-005 | 280 | Deployment.Config hardcodes credentials | Security |
| 16 | B-008 | 280 | DATABASE_URL with inline credentials | Security |
| 17 | F-010 | 280 | No mutation testing framework | Testing |
| 18 | B-001 | 270 | SIL-6 compose hardcodes POSTGRES_PASSWORD | Security |
| 19 | B-003 | 270 | SIL-6 compose hardcodes SECRET_KEY_BASE | Security |
| 20 | D-003 | 250 | App-dev: MIX_ENV=prod with source mount | Placeholder |
| 21 | C-002 | 245 | App resource asymmetry (20G/2G/1G) | Resources |
| 22 | B-004 | 240 | SIL-6 compose hardcodes RELEASE_COOKIE | Security |
| 23 | D-004 | 240 | Ollama violates Ω₂ localhost-only | Placeholder |

### P1-HIGH (RPN 100-199) — 28 Issues

| Rank | ID | RPN | Description |
|------|----|-----|-------------|
| 24 | E-002 | 240 | sa-up uses fsx (violates SC-CEP-005) |
| 25 | B-007 | 240 | prod-standalone hardcodes cookie |
| 26 | F-008 | 240 | SIL-6 integration test requires containers |
| 27 | C-003 | 224 | CPU oversubscription (23 > 10 CPUs) |
| 28 | B-002 | 210 | SIL-6 compose hardcodes Grafana password |
| 29 | D-007 | 210 | Config references non-existent images |
| 30 | E-005 | 210 | sa-health fails when OBS unhealthy |
| 31 | E-014 | 210 | cockpitf uses fsx (violates SC-CEP-005) |
| 32 | E-010 | 200 | sa-* don't validate F# build first |
| 33 | F-011 | 200 | No chaos testing in CI |
| 34 | F-014 | 200 | Overall grade C+ below target |
| 35 | G-013 | 192 | SMRITI ingestion not done |
| 36 | A-011 | 180 | HA compose uses different images |
| 37 | D-001 | 180 | Cortex entrypoint = sleep 3600 |
| 38 | E-006 | 180 | sa-checkpoint: non-existent subcommand |
| 39 | E-007 | 180 | sa-verify: non-existent subcommand |
| 40 | F-003 | 180 | L5 Node tests: ~40% coverage |
| 41 | F-009 | 180 | F# test coverage: ~60% |
| 42 | E-013 | 175 | cepaf-build only builds 1 of 10+ projects |
| 43 | E-008 | 162 | sa-emergency: non-existent subcommand |
| 44 | D-008 | 160 | OBS container persistently unhealthy |
| 45 | C-008 | 150 | 8G reserved for unused ollama |
| 46 | F-004 | 150 | L4 Container tests don't cover SIL-6 |
| 47 | C-004 | 144 | HA compose exceeds dev machine resources |
| 48 | C-009 | 144 | Total RAM ~52G may exceed host |
| 49 | A-008 | 140 | MeshStartup defaults to Dev mode |
| 50 | F-013 | 140 | BDD feature stubs not wired |
| 51 | G-008 | 140 | sa-* help doesn't match reality |

### P2-MEDIUM (RPN 50-99) — 18 Issues

IDs: A-004(120), A-010(125), C-006(120), C-007(120), D-002(120), E-003(128), E-009(120), E-012(128), E-016(125), E-019(100), F-005(100), G-002(120), G-003(96), G-006(128), G-009(96), G-011(90), A-005(90), A-006(90)

### P3-LOW (RPN < 50) — 18 Issues

IDs: A-007(90), E-004(72), E-017(80), E-018(96), G-004(72), G-005(84), G-007(84), G-014(54), G-001(54), E-011(48), E-015(48), F-006(48), G-010(45), G-012(40), E-020(40), G-015(32), F-007(18), D-006(60)

---

## 4. New STAMP Constraints

### SC-HOMEOSTASIS (Frozen Homeostasis Protocol)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-HOMEOSTASIS-001 | Once mesh reaches HOMEOSTASIS_ACHIEVED state, NO infrastructure mutations without recoverability plan | CRITICAL | Manual gate |
| SC-HOMEOSTASIS-002 | All L0-L2 changes MUST be tested in multiverse clean room first | CRITICAL | Worktree isolation |
| SC-HOMEOSTASIS-003 | Each proposed change MUST document its rollback procedure before execution | CRITICAL | Documentation gate |
| SC-HOMEOSTASIS-004 | Container image changes require side-by-side comparison (old image preserved as :prev tag) | HIGH | Image tagging |
| SC-HOMEOSTASIS-005 | Compose file changes MUST preserve previous version (git stash or backup copy) | HIGH | SC-DELETE-005 |
| SC-HOMEOSTASIS-006 | Network topology changes MUST NOT be applied during production hours | HIGH | Time window |
| SC-HOMEOSTASIS-007 | Resource limit changes require `podman stats` baseline capture before AND after | HIGH | Metrics |
| SC-HOMEOSTASIS-008 | Secret/credential rotation MUST use env vars, never inline values | CRITICAL | Security review |
| SC-HOMEOSTASIS-009 | Homeostasis state MUST be re-verified (sa-health) after any mutation | CRITICAL | Post-change gate |
| SC-HOMEOSTASIS-010 | Homeostasis violation log MUST be appended to Immutable Register | HIGH | Audit trail |

### SC-CLEANROOM (Multiverse Clean Room Testing)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-CLEANROOM-001 | Clean room testing MUST use `git worktree` isolation (NOT branch-in-place) | CRITICAL | Worktree creation |
| SC-CLEANROOM-002 | Clean room worktree MUST compile with 0 errors before any test | CRITICAL | Compile gate |
| SC-CLEANROOM-003 | Clean room tests MUST NOT affect the running mesh (separate ports, separate network) | CRITICAL | Port isolation |
| SC-CLEANROOM-004 | Clean room container images MUST use unique tags (`:cleanroom-YYYYMMDD`) | HIGH | Image tagging |
| SC-CLEANROOM-005 | Clean room worktree MUST be deleted after testing (no orphaned worktrees) | MEDIUM | Cleanup script |
| SC-CLEANROOM-006 | Clean room test results MUST be captured in a verification report | HIGH | Test report |
| SC-CLEANROOM-007 | Changes passing clean room MUST be reviewed manually before merge to active branch | CRITICAL | Manual review |
| SC-CLEANROOM-008 | Clean room network MUST use separate subnet from active mesh (e.g., 172.29.0.0/16) | HIGH | Network isolation |
| SC-CLEANROOM-009 | Clean room database MUST use separate volume (NOT shared with production DB) | CRITICAL | Volume isolation |
| SC-CLEANROOM-010 | Clean room testing time budget: max 4 hours per change set | MEDIUM | Time gate |

### SC-RECOV (Recoverability)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-RECOV-001 | Every infrastructure change MUST have a documented rollback procedure | CRITICAL | Doc gate |
| SC-RECOV-002 | Rollback procedure MUST be tested before the forward change is applied | CRITICAL | Pre-test |
| SC-RECOV-003 | Image rollback: previous image MUST be preserved with `:prev` tag | HIGH | Image policy |
| SC-RECOV-004 | Compose rollback: previous compose file MUST be git-stashed or backed up | HIGH | File backup |
| SC-RECOV-005 | Database rollback: `pg_dump` before schema changes | CRITICAL | Dump gate |
| SC-RECOV-006 | Volume rollback: snapshot volumes before destructive operations | HIGH | Volume snapshot |
| SC-RECOV-007 | Network rollback: document all port/subnet changes for reversal | HIGH | Doc gate |
| SC-RECOV-008 | Rollback time budget: all rollbacks MUST complete in < 5 minutes | HIGH | SC-EMR-057 |
| SC-RECOV-009 | Rollback verification: after rollback, sa-health MUST pass | CRITICAL | Post-check |
| SC-RECOV-010 | Rollback cascade: if rollback fails, escalate to sa-emergency | CRITICAL | Escalation |

---

## 5. New AOR Rules

### AOR-HOMEOSTASIS (Frozen Homeostasis Operations)

| ID | Rule | When |
|----|------|------|
| AOR-HOMEOSTASIS-001 | CAPTURE `podman stats` baseline before ANY infrastructure change | Before change |
| AOR-HOMEOSTASIS-002 | VERIFY mesh health (`sa-health` or manual `podman ps`) before AND after change | Before+after |
| AOR-HOMEOSTASIS-003 | DOCUMENT rollback procedure BEFORE executing forward change | Before change |
| AOR-HOMEOSTASIS-004 | PRESERVE previous container images with `:prev` tag before rebuild | Before build |
| AOR-HOMEOSTASIS-005 | STASH compose file changes with `git stash` before editing | Before edit |
| AOR-HOMEOSTASIS-006 | NEVER apply untested compose changes to the running mesh directly | Always |
| AOR-HOMEOSTASIS-007 | BROADCAST state change via Zenoh after any mesh mutation | After change |
| AOR-HOMEOSTASIS-008 | LOG all homeostasis-affecting operations to session audit trail | Always |
| AOR-HOMEOSTASIS-009 | HALT and ROLLBACK if post-change health check fails | On failure |
| AOR-HOMEOSTASIS-010 | DEFER non-critical changes until clean room capacity available | When busy |

### AOR-CLEANROOM (Clean Room Testing Operations)

| ID | Rule | When |
|----|------|------|
| AOR-CLEANROOM-001 | CREATE worktree: `git worktree add ../cleanroom-YYYYMMDD multiverse/claude-opus-fractal-tests` | Start of test |
| AOR-CLEANROOM-002 | COMPILE in worktree: `cd ../cleanroom-*; mix compile` before any test | Before test |
| AOR-CLEANROOM-003 | USE separate compose file for clean room with offset ports (+1000) | For containers |
| AOR-CLEANROOM-004 | VERIFY no port conflicts between clean room and active mesh | Before boot |
| AOR-CLEANROOM-005 | REMOVE worktree: `git worktree remove ../cleanroom-*` after testing | End of test |
| AOR-CLEANROOM-006 | NEVER `git worktree` to the same directory as the active mesh | Always |
| AOR-CLEANROOM-007 | REPORT test results to user before merging clean room changes | After test |
| AOR-CLEANROOM-008 | TAG clean room images: `localhost/indrajaal-*:cleanroom-YYYYMMDD` | During build |
| AOR-CLEANROOM-009 | ISOLATE clean room network: use `indrajaal-cleanroom-net` (172.29.0.0/16) | For containers |
| AOR-CLEANROOM-010 | DIFF clean room changes against active branch before merge | Before merge |

### AOR-RECOV (Recoverability Operations)

| ID | Rule | When |
|----|------|------|
| AOR-RECOV-001 | WRITE rollback script BEFORE writing forward script | Before change |
| AOR-RECOV-002 | TEST rollback script in clean room BEFORE testing forward script | Before change |
| AOR-RECOV-003 | KEEP rollback window: 24 hours of rollback capability for every change | Post-change |
| AOR-RECOV-004 | PRESERVE: `podman tag image:current image:prev` before rebuild | Before build |
| AOR-RECOV-005 | BACKUP: `pg_dump` before any migration or schema change | Before migration |
| AOR-RECOV-006 | SNAPSHOT: `podman volume export` for critical volumes before destructive ops | Before destruction |
| AOR-RECOV-007 | VERIFY: Run `sa-health` after EVERY rollback to confirm system recovered | After rollback |
| AOR-RECOV-008 | ESCALATE: If rollback fails within 5 minutes, invoke `sa-emergency` | On timeout |
| AOR-RECOV-009 | DOCUMENT: Append rollback result to session audit trail | After rollback |
| AOR-RECOV-010 | LEARN: Record why rollback was needed in docs/journal/ for pattern analysis | After incident |

---

## 6. Recoverability Matrix — Top 15 Proposed Remediations

Each remediation is ordered by RPN and includes the complete recoverability procedure.

### R-001: Update TopologyValidator to SIL-6 topology (A-001, RPN 504)

**Change**: Update `@fractal_cluster_dependencies` in `topology_validator.ex` to include all 15 SIL-6 containers with correct dependency DAG.

**Clean Room Procedure**:
1. `git worktree add ../cleanroom-topo HEAD`
2. Edit `lib/indrajaal/deployment/topology_validator.ex` — replace 5-node graph with 15-node SIL-6 DAG
3. `cd ../cleanroom-topo && mix compile && mix test test/sil6/topology_boot_test.exs`
4. Verify DAG acyclicity: `mix run -e "IO.inspect Indrajaal.Deployment.TopologyValidator.topological_sort(Indrajaal.Deployment.TopologyValidator.default_graph())"`

**Rollback**: `git checkout -- lib/indrajaal/deployment/topology_validator.ex`

**Verification**: Compile + topology test suite passes

---

### R-002: Fix OBS resource allocation (C-001, RPN 480)

**Change**: Update `podman-compose-sil6-full-mesh.yml` OBS resource limits from 2G/0.5CPU to 4G/2CPU (minimum viable).

**Clean Room Procedure**:
1. Backup: `cp lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml data/tmp/backup/`
2. Edit resource limits for `indrajaal-obs-prod` service
3. Clean room boot: `podman-compose -f cleanroom-compose.yml up -d indrajaal-obs-prod`
4. Verify OBS health: `curl -sf http://localhost:19090/-/healthy` (offset port +10000)

**Rollback**: `cp data/tmp/backup/podman-compose-sil6-full-mesh.yml lib/cepaf/artifacts/`

**Verification**: OBS container reaches `healthy` state within 60s

---

### R-003: Update DigitalTwin genotypes to SIL-6 (A-002, RPN 441)

**Change**: Rewrite `default_genotypes/0` in `lib/indrajaal/mesh/digital_twin.ex` to define all 15 SIL-6 containers with correct images, IPs, resources.

**Clean Room Procedure**:
1. `git worktree add ../cleanroom-dt HEAD`
2. Edit `digital_twin.ex` — add Zenoh routers, bridge, cortex, chaya, ml-runners
3. Update IP addresses from 172.30.0.x to 172.28.0.x (SIL-6 subnet)
4. Update cookie to match SIL-6 compose value
5. `cd ../cleanroom-dt && mix compile && mix test test/sil6/digital_twin_test.exs`

**Rollback**: `git checkout -- lib/indrajaal/mesh/digital_twin.ex`

**Verification**: 30 digital twin tests pass + genotype matches compose file services

---

### R-004: Remove hardcoded secrets from compose (B-001/B-003/B-004, RPN 270+)

**Change**: Replace all hardcoded passwords/secrets in compose files with `${ENV_VAR}` references. Create `.env.example` with placeholder values.

**Clean Room Procedure**:
1. Create `lib/cepaf/artifacts/.env.sil6` with actual values
2. Create `lib/cepaf/artifacts/.env.sil6.example` with placeholder values
3. Add `.env.sil6` to `.gitignore`
4. Update compose: `POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-changeme}`
5. Test: `podman-compose --env-file .env.sil6 -f compose.yml config` (validates substitution)

**Rollback**: Restore compose from git + remove .env files

**Verification**: `podman-compose config` resolves all env vars; no plaintext secrets in compose

---

### R-005: Fix sa-stabilize topology (E-001, RPN 392)

**Change**: Update `SIL6MeshOrchestrator.fsx` topology validation to check the actual 15 SIL-6 services instead of 8 legacy services.

**Clean Room Procedure**:
1. Backup: `cp lib/cepaf/scripts/SIL6MeshOrchestrator.fsx data/tmp/backup/`
2. Edit topology map: replace legacy services (registry:5000, db2:5434) with SIL-6 services
3. Test in clean room: `dotnet fsi SIL6MeshOrchestrator.fsx stabilize`

**Rollback**: Restore from backup

**Verification**: `sa-stabilize` validates all 15 SIL-6 services correctly

---

### R-006 through R-015: See full recoverability matrix in Appendix A.

---

## 7. Remediation Priority Queue

Based on RPN and dependency ordering:

### Wave 1: Documentation-Only Fixes (No infrastructure risk)
*Can be done immediately without clean room*

1. Update compose file comments to match 15-container reality (A-004/005/006/007)
2. Update CLAUDE.md §6.0 container table (G-002)
3. Create compose file inventory document (G-006)
4. Create F# script inventory document (G-009)
5. Update plan file checklist (G-015)

### Wave 2: Code Alignment (Clean room required, L1 only)
*All changes are `git revert`-able*

1. TopologyValidator SIL-6 update (A-001, RPN 504)
2. DigitalTwin genotype update (A-002, RPN 441)
3. Deployment.Config modernization (A-003, RPN 378)
4. sa-stabilize topology fix (E-001, RPN 392)

### Wave 3: Security Hardening (Clean room required, L1-L3)
*Env var substitution across compose + code*

1. Compose secret externalization (B-001/002/003/004)
2. Code credential removal (B-005/006/008)
3. Cookie standardization (A-012)

### Wave 4: Resource Right-Sizing (Requires running mesh, careful testing)
*Higher risk — needs podman stats baseline + comparison*

1. OBS resource fix (C-001, RPN 480)
2. App resource equalization (C-002)
3. CPU budget enforcement (C-003)
4. Cortex/Ollama/ML-runner deferral or reduction (C-006/007/008)

### Wave 5: Script Hardening (Clean room + manual verification)
*Medium risk — sa-* commands used frequently*

1. sa-up pre-compilation (E-002)
2. Missing subcommand implementation (E-006/007/008)
3. sa-health degraded mode (E-005)
4. Input validation (E-016)

### Wave 6: Test Coverage (New code, lowest infrastructure risk)
*Clean room, but no mesh impact*

1. L7 Federation tests (F-001)
2. L6 Cluster tests (F-002)
3. Formal verification expansion (F-012)
4. Mutation testing evaluation (F-010)

---

## 8. Current Mesh State Snapshot (2026-03-25)

For reference — the state that Frozen Homeostasis protects:

| Service | Status | Image | CPU | RAM | Notes |
|---------|--------|-------|-----|-----|-------|
| indrajaal-db-prod | Healthy | localhost/indrajaal-db:nixos-pg17 | 2.0 | 4G | PostgreSQL 17 |
| indrajaal-obs-prod | **UNHEALTHY** | localhost/indrajaal-obs:nixos-otel | 0.5 | 2G | Root cause: resource starvation |
| zenoh-router-1 | Healthy | eclipse/zenoh:1.0.0 | 0.5 | 512M | Port 7447 |
| zenoh-router-2 | Healthy | eclipse/zenoh:1.0.0 | 0.5 | 512M | Port 7448 |
| zenoh-router-3 | Healthy | eclipse/zenoh:1.0.0 | 0.5 | 512M | Port 7449 |
| zenoh-proxy | Healthy | eclipse/zenoh:1.0.0 | 0.5 | 512M | Legacy alias |
| cepaf-bridge | Running | localhost/indrajaal-cepaf:bridge | 0.5 | 2G | F# bridge |
| indrajaal-cortex | Running | localhost/indrajaal-cortex:sil6 | 1.0 | 4G | Sleep placeholder |
| indrajaal-ollama | Running | localhost/ollama:latest | 1.0 | 8G | External image |
| indrajaal-ex-app-1 | Healthy | localhost/indrajaal-app-dev:sil6 | 2.0 | 20G | Seed node |
| indrajaal-ex-app-2 | Healthy | localhost/indrajaal-app-dev:sil6 | 1.0 | 2G | Satellite |
| indrajaal-ex-app-3 | Healthy | localhost/indrajaal-app-dev:sil6 | 0.5 | 1G | Satellite |
| indrajaal-chaya | Running | localhost/indrajaal-app-dev:sil6 | 0.25 | 1G | Digital Twin |
| ml-runner-1 | Running | localhost/indrajaal-app-dev:sil6 | 0.5 | 2G | Sleep infinity |
| ml-runner-2 | Running | localhost/indrajaal-app-dev:sil6 | 0.5 | 2G | Sleep infinity |

**Zenoh 2oo3 Quorum**: VERIFIED (3/3 routers healthy)
**Phoenix Health**: App-1, App-2, App-3 all returning healthy
**OBS**: Known unhealthy — deferred to Wave 4 remediation
**HOMEOSTASIS_ACHIEVED**: Broadcast 2026-03-25

---

## 9. Frozen Homeostasis Enforcement Checklist

Before ANY change to the running mesh:

```
PRE-CHANGE CHECKLIST (ALL MUST PASS)
═══════════════════════════════════════════════════════
□ 1. Change documented in this FMEA register (Section 2)
□ 2. RPN calculated with S×O×D formula
□ 3. Recoverability procedure written (Section 6 or new)
□ 4. Rollback tested in clean room
□ 5. Forward change tested in clean room
□ 6. podman stats baseline captured
□ 7. Manual approval obtained from operator
□ 8. Previous artifacts preserved (image:prev, file backup)
═══════════════════════════════════════════════════════

POST-CHANGE CHECKLIST (ALL MUST PASS)
═══════════════════════════════════════════════════════
□ 1. podman stats comparison (before vs after)
□ 2. sa-health passes OR degradation documented
□ 3. Zenoh 2oo3 quorum maintained
□ 4. Phoenix health endpoints responding
□ 5. Change logged to session audit trail
□ 6. FMEA register updated with actual outcome
□ 7. HOMEOSTASIS_ACHIEVED re-broadcast if mesh modified
═══════════════════════════════════════════════════════
```

---

## 10. Constitutional Alignment

This document enforces:
- **Ψ₀ (Existence)**: Mesh survives all operations via recoverability mandate
- **Ψ₁ (Regeneration)**: Clean room isolation prevents corruption of running state
- **Ψ₂ (History)**: FMEA register preserves complete audit trail
- **Ψ₃ (Verification)**: Pre/post checklists verify integrity
- **Ω₀ (Founder's Directive)**: System stability serves symbiotic survival
- **SC-FUNC-001**: System MUST compile at all times
- **SC-EMR-057**: Emergency stop < 5 seconds (rollback time budget)
- **SC-DELETE-001**: Untracked files backed up before deletion

---

## Appendix A: Full Recoverability Matrix (R-006 through R-015)

### R-006: Update Deployment.Config to SIL-6 (A-003, RPN 378)
- **Change**: Update `containers/1` in config.ex with SIL-6 image names and 15-container definition
- **Rollback**: `git checkout -- lib/indrajaal/deployment/config.ex`
- **Verification**: `mix compile` + deployment config test

### R-007: Fix prod-standalone broken image (D-005, RPN 360)
- **Change**: Replace `indrajaal-app-unified:nixos-devenv` with `indrajaal-app-dev:sil6` in prod-standalone compose
- **Rollback**: `git checkout -- lib/cepaf/artifacts/podman-compose-prod-standalone.yml`
- **Verification**: `podman-compose config` validates

### R-008: Remove hardcoded credentials from code (B-005/006, RPN 280-350)
- **Change**: Replace hardcoded passwords in config.ex and digital_twin.ex with `System.get_env/2`
- **Rollback**: `git checkout -- lib/indrajaal/deployment/config.ex lib/indrajaal/mesh/digital_twin.ex`
- **Verification**: Compile + no plaintext passwords in git diff

### R-009: Standardize cookies across artifacts (A-012, RPN 336)
- **Change**: Use single `RELEASE_COOKIE` env var in all compose files and Elixir code
- **Rollback**: Restore from backup copies
- **Verification**: All compose files reference `${RELEASE_COOKIE}`

### R-010: Fix DigitalTwin IP addresses (C-010, RPN 324)
- **Change**: Update 172.30.0.x to 172.28.0.x in digital_twin.ex
- **Rollback**: `git checkout -- lib/indrajaal/mesh/digital_twin.ex`
- **Verification**: IPs match SIL-6 compose network definition

### R-011: Pre-compile SIL6MeshOrchestrator (E-002, RPN 240)
- **Change**: Build F# orchestrator as DLL; update sa-up to use `dotnet exec` instead of `dotnet fsi`
- **Rollback**: Revert devenv.nix sa-up command to fsx version
- **Verification**: `sa-up` boots mesh successfully from compiled binary

### R-012: App-dev MIX_ENV fix (D-003, RPN 250)
- **Change**: Set `MIX_ENV=dev` in Dockerfile.app-dev (since source is mounted, not precompiled)
- **Rollback**: `git checkout -- lib/cepaf/artifacts/Dockerfile.app-dev`
- **Verification**: App container compiles and boots in dev mode

### R-013: Implement sa-emergency (E-008, RPN 162)
- **Change**: Add `emergency` subcommand to SIL6MeshOrchestrator.fsx — force-stops all containers within 5s
- **Rollback**: Remove new code from .fsx
- **Verification**: `sa-emergency` stops all 15 containers in < 5s

### R-014: Fix Genotype/Phenotype resource mismatch (C-005, RPN 441)
- **Change**: Update DigitalTwin genotype resource values to match actual SIL-6 compose allocations
- **Rollback**: `git checkout -- lib/indrajaal/mesh/digital_twin.ex`
- **Verification**: Genotype resources match compose limits

### R-015: L7 Federation test suite (F-001, RPN 448)
- **Change**: Create `test/sil6/federation_test.exs` with cross-holon communication tests
- **Rollback**: `git rm test/sil6/federation_test.exs`
- **Verification**: New tests compile and pass (at least stub/pending)

---

*End of FMEA Document — Frozen Homeostasis Protocol v1.0.0*
*Generated: 2026-03-25 | Total Issues: 87 | P0-Critical: 23 | P1-High: 28 | P2-Medium: 18 | P3-Low: 18*
