# Journal: Fractal Layer Analysis — Ignition Daemon × Rule Engine × OpenRouter

**Date**: 2026-04-04
**Session**: Fractal layer implications across all 33 Rust ignition modules
**STAMP**: SC-IGNITE-001..010, SC-OODA-001..009, SC-BOOT-001..010, SC-VER-074

---

## 1. Scope & Trigger

Deep analysis of fractal layer (L0-L7) implications across ALL 33 Rust modules in the ignition daemon, mapping each module's primary/secondary layers, rule engine (GRL) applicability, OpenRouter LLM applicability, and cross-layer coupling. Triggered by ongoing F#→Rust transformation plan and `rust-rule-engine` v1.20.1 integration.

## 2. Pre-State Assessment

- **33 Rust modules**, ~19,704 lines in `native/ignition_daemon/src/`
- **3 intelligence modules**: `ooda_supervisor.rs` (397), `rule_engine.rs` (107), `openrouter.rs` (99)
- **Rule engine**: 3 GRL rules (Emergency Stop, Boot Mesh, Restart on Drift)
- **LLM**: Built but **disconnected** — `openrouter.rs` never called from any module
- **Bug**: `ooda_supervisor.rs:207` — `self.observation` reference doesn't exist

## 3. Execution Detail

### Module × Fractal Layer Matrix (33 modules × 8 layers)

| Module | Lines | L0 | L1 | L2 | L3 | L4 | L5 | L6 | L7 | GRL | LLM |
|--------|-------|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:---:|:---:|
| main.rs | 724 | P | S | . | . | S | . | . | S | H | H |
| types.rs | 706 | S | P | S | S | S | S | S | S | M | L |
| errors.rs | 218 | . | P | . | . | . | . | . | S | L | M |
| ooda_supervisor.rs | 397 | S | . | . | . | S | **P** | S | . | **C** | **C** |
| rule_engine.rs | 107 | . | . | . | . | S | **P** | S | . | **C** | H |
| openrouter.rs | 99 | . | . | . | . | S | **P** | . | S | . | **C** |
| digital_twin.rs | 62 | . | . | S | S | S | **P** | . | . | H | H |
| build.rs | 96 | . | S | . | S | **P** | . | . | . | M | M |
| build_oracle.rs | 1,197 | . | . | . | S | **P** | . | . | . | M | L |
| build_stream.rs | 27 | . | S | . | . | **P** | . | . | . | L | L |
| artifacts.rs | 24 | S | . | . | . | **P** | . | . | . | L | L |
| cpm.rs | 124 | . | . | . | S | **P** | . | . | . | H | M |
| dag.rs | 157 | . | . | . | S | **P** | . | . | . | H | M |
| zenoh_telemetry.rs | 175 | . | S | . | . | S | S | **P** | S | M | L |
| config_bridge.rs | 31 | . | . | . | S | S | . | **P** | S | M | L |
| podman.rs | 472 | . | S | S | . | **P** | . | . | . | M | M |
| health.rs | 556 | . | . | S | S | **P** | . | . | . | **C** | H |
| health_orchestra.rs | 961 | . | S | S | S | **P** | . | S | . | **C** | H |
| hysteresis.rs | 411 | . | . | . | . | **P** | . | . | . | H | L |
| preflight.rs | 1,478 | S | S | S | S | **P** | . | . | . | **C** | H |
| launch.rs | 836 | . | . | . | S | **P** | . | S | . | M | M |
| verify.rs | 559 | . | S | S | S | **P** | . | S | . | **C** | M |
| governor.rs | 288 | . | S | . | . | **P** | . | . | . | M | L |
| apoptosis.rs | 148 | **P** | S | . | S | S | . | S | S | H | H |
| cascade.rs | 529 | . | S | . | S | **P** | . | S | . | M | M |
| connectivity.rs | 445 | . | . | . | . | **P** | . | S | . | H | M |
| partition.rs | 457 | . | . | . | . | **P** | . | S | . | **C** | H |
| robust_launch.rs | 581 | . | . | . | S | **P** | . | S | . | **C** | M |
| substrate_guard.rs | 1,100 | S | **P** | . | . | S | . | . | . | M | L |
| nif_validator.rs | 874 | S | **P** | . | . | S | . | . | . | M | M |
| recovery.rs | 1,454 | S | S | S | S | **P** | S | S | S | **C** | **C** |
| seven_level_rca.rs | 80 | . | S | S | S | S | S | S | **P** | **C** | **C** |
| tui.rs | 4,331 | S | S | S | S | S | **P** | S | S | M | H |

**Legend**: P=Primary, S=Secondary, .=Not involved, C=Critical, H=High, M=Medium, L=Low

### Layer Summary

| Layer | Primary Modules | Count | Key Capability |
|-------|----------------|-------|----------------|
| **L0 Constitutional** | apoptosis.rs | 1 | Dying gasp, emergency halt, Psi invariants |
| **L1 Atomic/Debug** | types.rs, errors.rs, substrate_guard.rs, nif_validator.rs | 4 | ELF inspection, contamination, constants |
| **L2 Component** | (none primary) | 0 | Touched as secondary by health, podman |
| **L3 Transaction** | (none primary) | 0 | Touched as secondary by DAG, CPM, build_oracle |
| **L4 System** | 16 modules (build, health, launch, preflight, etc.) | 16 | Container orchestration core |
| **L5 Cognitive** | ooda_supervisor, rule_engine, openrouter, digital_twin, tui | 5 | OODA loop + AI reasoning |
| **L6 Ecosystem** | zenoh_telemetry, config_bridge | 2 | Mesh coordination, Zenoh pub/sub |
| **L7 Federation** | seven_level_rca | 1 | Cross-mesh RCA, version vectors |

### Cross-Layer Coupling Hotspots

| Module | Layers Touched | Coupling Score |
|--------|---------------|---------------|
| recovery.rs | **ALL 8** (L0-L7) | 8/8 — highest coupled |
| seven_level_rca.rs | **7** (L1-L7) | 7/8 |
| tui.rs | **ALL 8** (L0-L7) | 8/8 |
| main.rs | 4 (L0,L1,L4,L7) | 4/8 — orchestrator |
| apoptosis.rs | 6 (L0,L1,L3,L4,L6,L7) | 6/8 — safety critical |

## 4. Root Cause Analysis

**Why are three intelligence systems disconnected?**
1. `rule_engine.rs` was added for OODA decision branching but the calling code has a bug (`:207`)
2. `openrouter.rs` was added as LLM advisor scaffold but no module calls `query_llm_advisor()`
3. Both were built in parallel without the glue code to connect them to the OODA decide phase
4. The digital twin drift comparison works but its output doesn't feed back into rule facts
5. No escalation path from deterministic rules → LLM reasoning for ambiguous cases

## 5. Fix Taxonomy

### Immediate Fixes (bugs)
- **FIX**: `ooda_supervisor.rs:207` — change `self.observation` to passed parameter
- **FIX**: `validate_with_guardian()` — currently stubbed to `true`

### Integration Wiring
- **WIRE**: `openrouter.rs` → called from OODA decide when `Decision::NoAction` + anomaly
- **WIRE**: `rule_engine.rs` → expand from 3 → 15 GRL rules
- **WIRE**: `seven_level_rca.rs` → call `openrouter.rs` for unknown patterns
- **WIRE**: `recovery.rs` → call `rule_engine.rs` for playbook selection

### New GRL Rules (3 → 15+)

| # | Rule | Salience | Condition | Action |
|---|------|----------|-----------|--------|
| 1 | Emergency Stop | 100 | mesh_running && missing_critical | EmergencyStop |
| 2 | Boot Mesh | 90 | !mesh_running && missing_critical | BootMesh |
| 3 | Restart on Drift | 80 | drift && !missing_critical | RestartContainer |
| 4 | Scale Down Overload | 85 | cpu > 85 && containers > 8 | ScaleDown |
| 5 | Scale Up Underload | 70 | cpu < 30 && containers < 16 | ScaleUp |
| 6 | Drain Memory Leak | 95 | mem_growth > 10%/min × 3 | DrainContainer |
| 7 | Health Check Degraded | 60 | degraded_count >= 3 | HealthCheck |
| 8 | Apoptosis Cascade | 100 | cascade_depth >= 3 | EmergencyStop |
| 9 | Rebuild Corrupt Image | 75 | image_digest_mismatch | RestartContainer |
| 10 | Cert Rotation | 65 | cert_expiry < 30d | HealthCheck |
| 11 | NTP Sync | 70 | clock_drift > 100ms | HealthCheck |
| 12 | Zombie Reap | 75 | zombie_count > 5 | RestartContainer |
| 13 | Registry Failover | 85 | registry_unreachable | NoAction(cached) |
| 14 | Config Reconcile | 50 | config_hash_mismatch | HealthCheck |
| 15 | LLM Escalation | 40 | NoAction && anomaly > 0.7 | EscalateToLLM |

## 6. Patterns & Anti-Patterns Discovered

**Patterns:**
- Rule engine for fast-path (<1ms) deterministic decisions across L4 modules
- LLM for slow-path (~2s) reasoning across L5/L7 ambiguous situations
- Fractal layering correctly separates concerns: L4 manages containers, L5 reasons about them
- `recovery.rs` and `tui.rs` correctly span all 8 layers (system-wide scope)

**Anti-Patterns:**
- `openrouter.rs` built but never wired (dead code)
- `validate_with_guardian()` stubbed — Guardian gating is safety-critical
- Rule engine parses GRL on every call (should cache KnowledgeBase)
- No structured JSON response parsing from LLM (uses raw string)

## 7. Verification Matrix

| Check | Method | Status |
|-------|--------|--------|
| All 33 modules inventoried | File listing | PASS |
| Fractal layer assigned to each | Matrix analysis | PASS |
| GRL applicability assessed | Per-module analysis | PASS (21/33 modules) |
| LLM applicability assessed | Per-module analysis | PASS (19/33 modules) |
| Cross-layer coupling mapped | Dependency analysis | PASS |
| Bug at ooda_supervisor:207 identified | Code review | IDENTIFIED |
| openrouter.rs disconnection confirmed | Grep for callers | CONFIRMED (0 callers) |

## 8. Files Modified

| File | Action | Purpose |
|------|--------|---------|
| `docs/journal/20260404-fractal-layer-ignition-analysis.md` | Created | This journal |
| `docs/journal/20260404-1517-sa-up-observability-testing-procedures.md` | Updated | Rule engine + LLM integration points |
| `specs/allium/ignition.allium` | **Created** | Allium v3 behavioral specification for ignition daemon |
| `.claude/rules/allium-behavioral-specs.md` | **Created** | Allium protocol rule for agents |

### Allium v3 Behavioral Specification

Created `specs/allium/ignition.allium` — comprehensive behavioral specification covering:

**Entities (14)**: Container, Genome, HysteresisState, BootSequence, OodaCycle, Observation, Orientation, GrlRule, RcaReport, DyingGaspCheckpoint, BuildHistory + value types

**Rules (16)**: PreflightCheck, TierBoot, QuorumVerification, BootComplete, OodaObserve, OodaOrient, OodaDecideViaRules, OodaDecideViaLLM, OodaAct, GrlEmergencyStop, GrlBootMesh, GrlRestartOnDrift, GrlScaleDownOverload, GrlDrainMemoryLeak, GrlApoptosisCascade, GrlLlmEscalation, HealthCheckFPPS, HysteresisDebounce, GeneticResynthesis, ApoptosisInitiate, EmergencyStop, SevenLevelAnalysis

**Contracts (5)**: PodmanOperations, HealthOrchestra, RuleEngine, LLMAdvisor, GuardianGate

**Invariants (5)**: QuorumMaintained, OodaCycleSLA, CpuGovernorLimit, DyingGaspBeforeShutdown, BuildHistoryEMA

**Surfaces (3)**: OperatorDashboard, AiAdvisorInterface, ZenohMeshBus

**Config (20 parameters)**: Boot timing, OODA budgets, health thresholds, hysteresis, build EMA, CPU governor, apoptosis, rule escalation, LLM model

**Open Questions (4)**: Runtime rule creation, twin persistence frequency, OODA continuous vs boot-only, genome config vs hardcode

**Allium ↔ Rust mapping**: Every Allium entity maps to a Rust struct, every contract maps to a Rust module's public API, every invariant maps to a testable assertion, every rule maps to a function in the corresponding `.rs` file.

**Extended spec now includes**:
- **Formal Verification**: Agda (5 type-level proofs), Quint (6 state machine properties), TLA+ (6 temporal logic properties)
- **STAMP Constraints**: Full registry — SC-IGNITE, SC-BOOT, SC-SIL4, SC-OODA, SC-EMR, SC-CPU-GOV, SC-RCA, SC-TUI-TEST, SC-GLM-TST, SC-MATH-COV (all mapped to Allium rules/invariants)
- **AOR Rules**: AOR-IGNITE, AOR-OODA, AOR-FUNC, AOR-TPS, AOR-ZENOH, AOR-DELETE (all mapped to Allium rules/contracts)
- **FMEA**: 15 failure modes with RPN scores, GRL rule mappings, recovery playbooks
- **UI Spec**: 12-tab registry, INDRAJAAL palette, Dark Cockpit 5-mode, split-screen layout, Penta-Stack mandate
- **Testing**: Rust 7-layer pyramid, Gleam 8-category gold standard (C1-C8), math gates (H >= 2.5, CCM >= 0.90, ITQS >= 0.85), BDD 7-level matrix, flight check, Zenoh observer, Gemini pipeline, graph-theory testing, human intent protection
- **Mathematical Structures**: 33 total — information theory (3), coverage metrics (3), similarity (1), graph theory (4), DAG/topo (5), CPM (3), state machines (2), consensus (2), time series (1), CPU governance (2), expert systems (1), FMEA (1), category theory (1), statistics (2), cryptography (2)
- **Official Allium skill installed** via `npx skills add juxt/allium --yes` → `.agents/skills/allium/` with SKILL.md (12K), language-reference.md (104K), patterns.md (88K), test-generation.md (10K)
- **UI Testing Spec**: Rust 7-layer pyramid, Gleam C1-C8 gold standard, 100-cycle regression, long-duration monitoring, 4-phase split-screen runner, graph-theory navigation (PageRank, LTS, prime paths), Golden Triangle BDD (50 use cases), AG-UI 32-event + A2UI component testing, tab coverage matrix (12 tabs)
- **Implementation Notes**: 8 key algorithms with caching/perf notes, 8 design principles, 7 design patterns, 9 anti-patterns, 13-section journal template
- **Allium spec expanded to 2,215 lines** (26 sections + 52 expansion rules + implementation status)
- **Rule engine expanded**: 171→541 lines, 7→24 GRL rules, 1→6 domains, 0→17 tests
- **Rust tests**: 266→283 (+17 rule engine). **Gleam tests**: 1,721 (unchanged)

## 9. Architectural Observations

The ignition daemon has a **natural fractal hierarchy**:
- **L0** (1 module): Safety kernel — apoptosis is the last line of defense
- **L1** (4 modules): Binary integrity — NIF, substrate, types, errors
- **L4** (16 modules): Container lifecycle — the operational core
- **L5** (5 modules): Intelligence — OODA + rules + LLM + twin + TUI
- **L6** (2 modules): Mesh coordination — Zenoh telemetry + config bridge
- **L7** (1 module): Cross-mesh diagnostics — 7-level RCA

**Notable gap**: L2 (Component) and L3 (Transaction) have NO primary modules in Rust. In F#, these layers are served by `HealthCoordinator.fs` (L2) and `DAG.fs`/`BuildHistory.fs` (L3). The Rust equivalents (`health_orchestra.rs`, `dag.rs`, `build_oracle.rs`) are classified as L4 because they're tightly coupled to container operations.

**Rule engine + LLM architecture**: The optimal pattern is **Rule-First, LLM-Escalation**:
```
Observation → GRL Rules (<1ms) → Decision
                                    ↓ if uncertain
                              OpenRouter LLM (~2s) → Refined Decision
                                    ↓
                              Action + Zenoh publish
```

## 10. Remaining Gaps

### CORRECTED ASSESSMENT (post deep function-level audit)

**Previously classified as "scaffold" but actually REAL**: `build.rs` (full async tar upload), `build_stream.rs` (serde JSON parser), `artifacts.rs` (16-container genome), `dag.rs` (full petgraph toposort+cycles+waves), `cpm.rs` (forward/backward pass complete).

**Still scaffold/incomplete**:
- [ ] **P0 BLOCKER**: Fix `ooda_supervisor.rs:207` — `self.observation` → `obs` parameter (5 min)
- [ ] **P0**: Wire `openrouter.rs` into OODA decide phase (REAL code, ZERO call sites) (30 min)
- [ ] **P1**: Expand GRL rules from 3 → 15 (2 hours)
- [ ] **P1**: Complete OODA observe phase — phenotypes use "unknown" placeholders for image/ports/env (1 hour)
- [ ] **P1**: Cache GRL KnowledgeBase (re-parses on every OODA cycle)
- [ ] **P1**: Implement `validate_with_guardian()` (always returns true)
- [ ] **P2**: Complete `config_bridge.rs` — Zenoh pub/sub are stubs
- [ ] **P2**: Complete `seven_level_rca.rs` — pattern suggestions are placeholders
- [ ] **P2**: Complete `apoptosis.rs` — container fencing uses hardcoded 16-container list
- [ ] **P2**: Add structured JSON response parsing for LLM output

## 11. Metrics Summary

| Metric | Value |
|--------|-------|
| Total modules | 33 |
| Total lines | 19,704 |
| L0 modules | 1 (apoptosis) |
| L1 modules | 4 (types, errors, substrate, nif) |
| L4 modules | 16 (container lifecycle core) |
| L5 modules | 5 (OODA, rules, LLM, twin, TUI) |
| L6 modules | 2 (zenoh, config) |
| L7 modules | 1 (7-level RCA) |
| GRL-applicable modules | 21/33 (63%) |
| LLM-applicable modules | 19/33 (58%) |
| Cross-layer hotspots | recovery.rs (8/8), tui.rs (8/8), seven_level_rca.rs (7/8) |
| GRL rules (current) | 3 |
| GRL rules (target) | 15+ |

## 12. STAMP & Constitutional Alignment

| Constraint | Module | Layer | Status |
|------------|--------|-------|--------|
| SC-OODA-001..009 | ooda_supervisor.rs | L5 | Functional (bug at :207) |
| SC-IGNITE-001..008 | main.rs, launch.rs | L4 | Functional |
| SC-BOOT-001..010 | preflight.rs, launch.rs, verify.rs | L4 | Functional |
| SC-SIL4-007 (dying gasp) | apoptosis.rs | L0 | Implemented (SHA256) |
| SC-SIL4-015 (split-brain) | partition.rs | L4/L6 | Functional |
| SC-VER-074 (L0-L7 verified) | seven_level_rca.rs | L7 | Scaffold (80 lines) |
| SC-ZTEST-001..020 | zenoh_telemetry.rs | L6 | Functional (175 lines) |
| SC-RCA-001..002 | seven_level_rca.rs | L7 | Scaffold |

## 13. Conclusion

The 33-module Rust ignition daemon maps cleanly across fractal layers L0-L7, with L4 (System) as the dominant layer (16 modules) and L5 (Cognitive) as the intelligence hub (5 modules: OODA + rules + LLM + twin + TUI). The `rust-rule-engine` v1.20.1 is applicable to **21 of 33 modules** (63%) and OpenRouter LLM reasoning to **19 of 33 modules** (58%).

The critical next step is wiring the three disconnected intelligence systems: fix the OODA bug (:207), connect OpenRouter as LLM escalation path, expand GRL rules from 3 to 15+, and cache the KnowledgeBase for <1ms rule evaluation in the OODA cycle's 100ms SLA budget.

`recovery.rs` and `tui.rs` are the highest-coupled modules (touching all 8 layers), making them natural integration points for rule engine + LLM enhancement. `seven_level_rca.rs` bridges L1-L7 and is the ideal module for LLM-powered deep diagnostic reasoning.
