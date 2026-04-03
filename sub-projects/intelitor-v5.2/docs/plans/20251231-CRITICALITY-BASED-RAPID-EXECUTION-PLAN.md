# CRITICALITY-BASED RAPID EXECUTION BIOMORPHIC PLAN

```
    ●╮       ╭●
     ╰╮ ╭─╮ ╭╯
  ●───◉─┤◈├─◉───●   INDRAJAAL CRITICALITY MATRIX
     ╭╯ ╰─╯ ╰╮       इन्द्रजाल
    ●╯       ╰●       Fast OODA + 100% Goal + Full Transparency
```

**Created**: 2025-12-31T22:00:00+01:00
**Version**: 21.3.0-CRITICALITY-RAPID
**Status**: ACTIVE EXECUTION
**Goal**: 100% Comprehensive Coverage Across 10 Dimensions
**Framework**: SOPv5.11 + TPS + STAMP + TDG + GDE + FMEA + Fast OODA

---

## 1. CRITICALITY MATRIX

### 1.1 Priority Classification (P0-P3)

| Priority | Meaning | SLA | Blocking |
|----------|---------|-----|----------|
| **P0** | CRITICAL - System non-functional | Immediate | YES |
| **P1** | HIGH - Core functionality impaired | &lt;1 hour | YES |
| **P2** | MEDIUM - Feature incomplete | &lt;4 hours | NO |
| **P3** | LOW - Enhancement/Polish | &lt;24 hours | NO |

### 1.2 Current Criticality Assessment

| Component | Status | Priority | Blocker? | Notes |
|-----------|--------|----------|----------|-------|
| Elixir 1.19.4 / OTP 28 | ✅ VERIFIED | - | - | Foundation ready |
| Compilation (0 errors) | ✅ PASS | - | - | Clean compile |
| Compilation (0 warnings) | 🔄 PARTIAL | P1 | NO | ~50 test warnings |
| Zenoh NIF Loading | ✅ LOADS | P0 | NO | Session connects |
| Zenoh Connection | ⚠️ WARN | P2 | NO | Expected in dev |
| OODA Loop | ✅ EXISTS | P1 | NO | Needs sensor discovery |
| Fast OODA &lt;100ms | 🔄 PENDING | P1 | NO | Not validated |
| Test Suite | ✅ EXISTS | P1 | NO | 836 test files |
| Runtime Coverage | 🔄 PENDING | P1 | NO | Need baseline |
| STAMP Constraints | ✅ 445+ | P2 | NO | Documented |
| Fractal Logging | ✅ EXISTS | P2 | NO | L0-L4 implemented |
| DirectedTelescope | ✅ FIXED | P2 | NO | nodes() bug fixed |

---

## 2. RESOURCE INVENTORY

### 2.1 Claude Folder Assets

| Asset Type | Count | Location | Usage |
|------------|-------|----------|-------|
| **Slash Commands** | 7 | `.claude/commands/` | `/compile`, `/test`, `/quality`, `/sa`, `/stamp`, `/rca`, `/journal` |
| **Subagents** | 4 | `.claude/agents/` | safety-validator, test-generator, code-reviewer, script-finder |
| **Modular Rules** | 4 | `.claude/rules/` | ash-resources, property-testing, safety-critical, factories |
| **Hooks** | 2 | `.claude/hooks/` | todo_sync_hook.sh, ep014_check.sh |
| **LSP Plugin** | 1 | `.claude/plugins/elixir-lsp/` | 10 languages + 6 frameworks |

### 2.2 MCP Servers (17 Configured)

| MCP Server | Purpose | Criticality Use |
|------------|---------|-----------------|
| **postgres** | DB queries, schema | Runtime testing |
| **git** | Diff, log, blame | Code review, merge |
| **filesystem** | Secure file ops | Batch operations |
| **memory** | Knowledge graph | Context persistence |
| **sequential-thinking** | RCA, architecture | 5-Level debugging |
| **fetch** | Web docs | API reference |
| **sqlite** | Holon state | SC-HOLON-001 |
| **duckdb** | Analytics history | SC-HOLON-003 |
| **podman** | Container mgmt | SC-CNT-009 |
| **puppeteer** | Browser automation | E2E testing |
| **sentry** | Error tracking | Runtime transparency |
| **redis** | Cache, pub/sub | Performance |

### 2.3 Script Directories (1,475 scripts in 87 dirs)

| Category | Key Scripts | Usage |
|----------|-------------|-------|
| **compilation** | `scripts/compilation/*.exs` | Patient Mode compile |
| **testing** | `scripts/testing/*.exs` | Test execution |
| **monitoring** | `scripts/monitoring/*.sh` | Runtime transparency |
| **rca** | `scripts/rca/*.exs` | 5-Level RCA |
| **validation** | `scripts/validation/*.exs` | STAMP/TDG checks |

---

## 3. FAST OODA EXECUTION LOOP

### 3.1 Loop Architecture (&lt;100ms Total)

```
┌─────────────────────────────────────────────────────────────────────┐
│                    FAST OODA EXECUTION CYCLE                        │
├────────────────┬────────────────┬────────────────┬─────────────────┤
│   OBSERVE      │    ORIENT      │    DECIDE      │      ACT        │
│    20ms        │     30ms       │     30ms       │     20ms        │
├────────────────┼────────────────┼────────────────┼─────────────────┤
│ • Zenoh Sensors│ • AI/LLM       │ • Guardian     │ • GenServer     │
│ • Metrics      │ • Context      │ • STAMP Veto   │ • Zenoh Pub     │
│ • Health       │ • Inference    │ • AOR Check    │ • State Update  │
│ • Telemetry    │ • Prediction   │ • FMEA Risk    │ • Fractal Log   │
└────────────────┴────────────────┴────────────────┴─────────────────┘
         │                │                │               │
         └────────────────┴────────────────┴───────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │   FRACTAL LOGGING       │
                    │   L0=Spine (Critical)   │
                    │   L1=Thorax (Warning)   │
                    │   L2=Segment (Info)     │
                    │   L3=Fiber (Debug)      │
                    │   L4=Gossamer (Trace)   │
                    └─────────────────────────┘
```

### 3.2 SC-OODA Constraints

| Constraint | Target | Enforcement |
|------------|--------|-------------|
| SC-OODA-001 | Cycle &lt;100ms | Timer watchdog |
| SC-OODA-002 | Quality 80%+ | Gate enforcement |
| SC-OODA-003 | Async observe | Non-blocking sensors |
| SC-OODA-004 | No blocking | GenServer.cast only |
| SC-OODA-005 | Hysteresis | 10% margin, 3-cycle hold |
| SC-OODA-006 | AI timeout 20ms | Local heuristic fallback |

---

## 4. 10-DIMENSION COVERAGE MATRIX

### 4.1 Coverage Dimensions

| Dim | Name | Tool | Target | Current | Status |
|-----|------|------|--------|---------|--------|
| D1 | **Static** | Dialyzer | 0 warnings | TBD | 🔄 PENDING |
| D2 | **Runtime** | ExUnit/ExCoveralls | 100% lines | TBD | 🔄 PENDING |
| D3 | **Mathematical** | Quint/Agda | State proofs | EXISTS | ✅ DOCS |
| D4 | **BDD** | Gherkin/WhiteBread | User stories | PARTIAL | 🔄 PENDING |
| D5 | **STAMP** | SC-* Constraints | 445 verified | 445 | ✅ DONE |
| D6 | **AOR** | Agent Rules | 100+ enforced | 100+ | ✅ DONE |
| D7 | **TDG** | Test-Driven Gen | Tests BEFORE | ACTIVE | ✅ ACTIVE |
| D8 | **FMEA** | Failure Mode | High-RPN mitigated | PARTIAL | 🔄 PENDING |
| D9 | **Quality** | Credo/Format | 0 issues | TBD | 🔄 PENDING |
| D10 | **Security** | Sobelow | 0 vulns | TBD | 🔄 PENDING |

### 4.2 Verification Commands

```bash
# D1: Static Analysis
mix dialyzer --format short

# D2: Runtime Coverage
MIX_ENV=test mix test --cover --export-coverage default

# D4: BDD Features
mix white_bread.run

# D5: STAMP Verification
mix stamp.verify

# D7: TDG Compliance
mix validate.ep014

# D9: Quality Gate
mix format --check-formatted && mix credo --strict

# D10: Security
mix sobelow --exit
```

---

## 5. RUNTIME TRANSPARENCY STACK

### 5.1 Components

| Component | Module | Purpose |
|-----------|--------|---------|
| **DirectedTelescope** | `lib/indrajaal/observability/directed_telescope.ex` | RCA debugger |
| **FractalLogger** | `lib/indrajaal/observability/fractal/` | 5-level logging |
| **ZenohCoordinator** | `lib/indrajaal/observability/zenoh_coordinator.ex` | Stream orchestration |
| **DualLogging** | `lib/indrajaal/observability/dual_logging.ex` | Terminal + SigNoz |
| **FastOODA** | `lib/indrajaal/cortex/fast_ooda.ex` | 50ms cycle loop |

### 5.2 RCA Debugger Usage

```elixir
# Zoom into Zenoh topic pattern
{:ok, pid} = Indrajaal.Observability.DirectedTelescope.zoom_zenoh("indrajaal/**/kpi", 10_000)

# Inspect holon internal state
{:ok, state} = Indrajaal.Observability.DirectedTelescope.inspect_holon(Indrajaal.Cybernetic.OODA.Loop)

# Trace process messages
:ok = Indrajaal.Observability.DirectedTelescope.trace_process(:ooda_loop, 10)

# Get comprehensive snapshot
snapshot = Indrajaal.Observability.DirectedTelescope.comprehensive_snapshot()
```

### 5.3 Fractal Logging Levels

| Level | Name | Retention | Use Case |
|-------|------|-----------|----------|
| L0 | Spine | Infinite | Critical alerts, system failures |
| L1 | Thorax | 30 days | Warnings, degraded performance |
| L2 | Segment | 7 days | Info, normal operations |
| L3 | Fiber | 24 hours | Debug, development |
| L4 | Gossamer | 1 hour | Trace, high-frequency |

---

## 6. EXECUTION PHASES

### Phase 1: Foundation Verification [P0] - ACTIVE

**Objective**: Confirm Elixir 1.19.4 + Erlang/OTP 28 + Zero compilation errors

**Actions**:
1. ✅ Verify `elixir --version` = 1.19.4
2. ✅ Verify OTP 28
3. ✅ `mix compile` = 0 errors
4. 🔄 `mix compile --warnings-as-errors` (test warnings acceptable)

**MCP Usage**: `git` for status, `filesystem` for file checks

### Phase 2: Nervous System [P0]

**Objective**: Zenoh NIF loads + Fractal logging active

**Actions**:
1. ✅ Zenoh NIF compiles (Rustler 0.37)
2. ⚠️ Zenoh session connects (expected fail in dev - no zenoh server)
3. ✅ Fractal logging supervisor starts
4. ✅ DirectedTelescope available

**MCP Usage**: `podman` for container checks, `sqlite` for holon state

### Phase 3: Fast OODA Activation [P1]

**Objective**: OODA cycle &lt;100ms with sensor discovery

**Actions**:
1. Fix OODA Loop sensor discovery (homeostasis retry)
2. Validate cycle time with timer
3. Enable Guardian STAMP veto
4. Integrate Active Inference with 20ms timeout

**MCP Usage**: `sequential-thinking` for RCA, `memory` for context

### Phase 4: 100% Coverage [P1]

**Objective**: All 10 dimensions GREEN

**Actions**:
1. Run full test suite with coverage
2. Execute Dialyzer
3. Run Credo strict
4. Run Sobelow
5. Generate LCOV report

**MCP Usage**: `postgres` for DB tests, `puppeteer` for E2E

### Phase 5: Runtime Transparency [P2]

**Objective**: Full observability with RCA debugger

**Actions**:
1. Start standalone stack (`sa-up`)
2. Verify Zenoh streams
3. Test DirectedTelescope commands
4. Validate fractal log levels

**MCP Usage**: `sentry` for errors, `redis` for cache

### Phase 6: Mainline Merge [P0]

**Objective**: SIL-2 certified merge to main

**Actions**:
1. All quality gates pass
2. Coverage report generated
3. Create PR with summary
4. Merge to main
5. Tag v20.3.2

**MCP Usage**: `git` for merge, `github` for PR

---

## 7. IMMEDIATE EXECUTION QUEUE

### 7.1 Next Actions (Priority Order)

| # | Action | Tool | Expected Time |
|---|--------|------|---------------|
| 1 | Run test suite with coverage | `mix test --cover` | 5-10 min |
| 2 | Check test warnings count | Review output | 1 min |
| 3 | Run quality gate | `/quality` skill | 3-5 min |
| 4 | Validate OODA cycle time | FastOODA check | 1 min |
| 5 | Generate coverage report | `mix coveralls` | 2 min |

### 7.2 Success Criteria

| Metric | Target | Current |
|--------|--------|---------|
| Compilation Errors | 0 | 0 ✅ |
| Compilation Warnings | 0 (src only) | TBD |
| Test Files | 836 | 836 ✅ |
| Test Passing | 100% | TBD |
| Line Coverage | &gt;95% | TBD |
| Dialyzer Warnings | 0 | TBD |
| Credo Issues | 0 | TBD |
| Sobelow Vulns | 0 | TBD |
| OODA Cycle | &lt;100ms | TBD |

---

## 8. STAMP/AOR/TDG/FMEA INTEGRATION

### 8.1 Key Constraints

**STAMP (445 constraints)**:
- SC-VAL-001: Patient Mode only
- SC-CNT-009: NixOS/Podman only
- SC-AGT-017: Agent efficiency &gt;90%
- SC-OODA-001: Cycle &lt;100ms
- SC-NIF-004: Rustler version sync
- SC-HOLON-001: SQLite for holon state

**AOR (100+ rules)**:
- AOR-EXE-001: Executive authority
- AOR-OODA-001: Cycle time mandate
- AOR-HOLON-001: SQLite sovereignty
- AOR-FOUNDER-001: Ω₀ priority

**TDG Mandate (Ω₄)**:
- Tests MUST exist before code
- Dual property tests (PropCheck + ExUnitProperties)
- PC/SD aliases for disambiguation

**FMEA High-RPN Modes**:
| Mode | RPN | Mitigation |
|------|-----|------------|
| NIF Load Failure | 80 | SC-NIF-003 fallback |
| OODA Timeout | 70 | Local heuristics |
| DB Connection Loss | 75 | Circuit breaker |
| Zenoh Disconnect | 65 | Reconnect + buffer |

---

## 9. MCP SERVER INTEGRATION MAP

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MCP SERVER INTEGRATION                           │
├─────────────────┬───────────────────────────────────────────────────┤
│   DEVELOPMENT   │                                                   │
│   ┌─────────┐   │   ┌─────────┐   ┌─────────┐   ┌─────────┐        │
│   │ git     │───┼──▶│filesystem│──▶│ memory  │──▶│ github  │        │
│   └─────────┘   │   └─────────┘   └─────────┘   └─────────┘        │
├─────────────────┼───────────────────────────────────────────────────┤
│   DATA LAYER    │                                                   │
│   ┌─────────┐   │   ┌─────────┐   ┌─────────┐                      │
│   │ postgres│───┼──▶│ sqlite  │──▶│ duckdb  │                      │
│   └─────────┘   │   └─────────┘   └─────────┘                      │
│   (Business)    │   (Holon State)  (Analytics)                     │
├─────────────────┼───────────────────────────────────────────────────┤
│   RUNTIME       │                                                   │
│   ┌─────────┐   │   ┌─────────┐   ┌─────────┐   ┌─────────┐        │
│   │ podman  │───┼──▶│ redis   │──▶│ sentry  │──▶│puppeteer│        │
│   └─────────┘   │   └─────────┘   └─────────┘   └─────────┘        │
│   (Containers)  │   (Cache)        (Errors)      (E2E)             │
├─────────────────┼───────────────────────────────────────────────────┤
│   COGNITIVE     │                                                   │
│   ┌─────────────────────────────┐   ┌─────────┐                    │
│   │ sequential-thinking (RCA)   │──▶│ fetch   │                    │
│   └─────────────────────────────┘   └─────────┘                    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 10. MERGE PROTOCOL

### 10.1 Pre-Merge Checklist

- [ ] All 10 coverage dimensions GREEN
- [ ] Zero compilation warnings (source)
- [ ] Test suite 100% passing
- [ ] Coverage &gt;95%
- [ ] Dialyzer clean
- [ ] Credo clean
- [ ] Sobelow clean
- [ ] OODA &lt;100ms validated
- [ ] STAMP report generated
- [ ] Journal entry created

### 10.2 Merge Commands

```bash
# Final quality gate
mix format --check-formatted && \
mix credo --strict && \
mix dialyzer && \
mix sobelow --exit && \
mix test --cover

# Merge to main
git checkout main
git merge --no-ff feature/20251231-rapid-execution-biomorphic-actualization
git tag -a v20.3.2 -m "Biomorphic Rapid Actualization - 100% Coverage"
git push origin main --tags
```

---

*Plan Owner: Cybernetic Architect | Created: 2025-12-31T22:00:00+01:00*
*Framework: SOPv5.11 + STAMP + TDG + FMEA + Fast OODA*
*Target: v20.3.2 SIL-2 Certified*
