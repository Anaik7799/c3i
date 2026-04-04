# Allium v3 User Guide — C3I SIL-6 Biomorphic Mesh

**Version**: 1.0.0 | **Spec**: `specs/allium/ignition.allium` (1,923 lines, 26 sections) | **Date**: 2026-04-04

## What is Allium?

Allium is a behavioral specification language that captures **what the system should do** separately from **how the code does it**. When spec and code diverge, that's information — you've found either a bug or an unrecorded design decision.

- **Repository**: https://github.com/juxt/allium
- **Language Reference**: `.agents/skills/allium/references/language-reference.md` (104K, local)
- **Patterns**: `.agents/skills/allium/references/patterns.md` (88K, local)
- **Test Generation**: `.agents/skills/allium/references/test-generation.md` (10K, local)
- **SKILL.md**: `.agents/skills/allium/SKILL.md` (12K, local)

## Installation

### Claude Code Plugin (Recommended)
```bash
# Add JUXT marketplace
/plugin marketplace add juxt/claude-plugins

# Install Allium
/plugin install allium
```

### Already Installed (this project)
```bash
# Was installed via:
npx skills add juxt/allium --yes

# Installed to:
.agents/skills/allium/          # Official SKILL.md (12,712 lines)
.agents/skills/allium/references/language-reference.md (104K)
.agents/skills/allium/references/patterns.md (88K)
.agents/skills/allium/references/test-generation.md (10K)
.agents/skills/allium/skills/elicit/  # Structured conversation agent
.agents/skills/allium/skills/distill/ # Code → spec extraction
.agents/skills/allium/skills/propagate/ # Spec → test generation

# Project-specific additions:
.claude/commands/allium.md      # Custom skill extensions
.claude/rules/allium-behavioral-specs.md  # SC-ALLIUM constraints
```

### CLI Validator (Optional)
```bash
# macOS
brew tap juxt/allium && brew install allium

# Cargo
cargo install allium-cli
```

## Project Structure

```
specs/allium/
  ignition.allium          -- Main spec (1,189 lines)
                              16 entities, 16 rules, 5 contracts,
                              5 invariants, 3 surfaces, 20 config params
                              + STAMP, AOR, FMEA, UI, testing, formal verification

.claude/commands/
  allium.md                -- Skill file (/allium, /allium:tend, /allium:weed)

.claude/rules/
  allium-behavioral-specs.md -- SC-ALLIUM-001..008 protocol rule

docs/
  allium-user-guide.md     -- This file
```

## Quick Start

### 1. Read the Spec
```
Read specs/allium/ignition.allium
```

Key sections:
- **Lines 1-50**: External entities, enumerations
- **Lines 50-200**: Value types, config (20 parameters)
- **Lines 200-500**: Entities (Container, Genome, BootSequence, OodaCycle, etc.)
- **Lines 500-700**: Rules (boot, OODA, GRL, health, build, apoptosis, RCA)
- **Lines 700-800**: Invariants, surfaces, deferred specs, open questions
- **Lines 800-1189**: Formal verification, STAMP, AOR, FMEA, UI, testing

### 2. Use the Skill Commands

**Examine and suggest next steps:**
```
/allium
```

**Add a new feature:**
```
/allium:tend we need container log streaming with real-time search
```
The Tend agent will:
1. Read existing spec
2. Propose new entity `LogStream`, rule `StreamContainerLogs`, surface addition
3. Write the spec changes
4. Validate consistency

**Detect drift:**
```
/allium:weed native/ignition_daemon/src/ooda_supervisor.rs
```
The Weed agent will:
1. Read spec rules for OODA
2. Read the Rust source
3. Report: "Bug at line 207: `self.observation` doesn't exist — spec says observation passed as parameter"

**Generate tests:**
```
/allium:propagate
```
Generates test cases from rules' `requires`/`ensures` clauses.

### 3. Understand the Entity ↔ Code Mapping

| Allium Entity | Rust Struct | Gleam Type | File |
|--------------|-------------|------------|------|
| `Container` | `ContainerRow` / `GenomeEntry` | `domain.Page` (indirect) | `types.rs` |
| `Genome` | `SIL6_GENOME` array | n/a | `artifacts.rs` |
| `BootSequence` | Boot flow state | n/a | `launch.rs` |
| `OodaCycle` | `OodaCycle` | n/a | `ooda_supervisor.rs` |
| `Observation` | `Observation` | n/a | `ooda_supervisor.rs` |
| `Orientation` | `Orientation` | n/a | `ooda_supervisor.rs` |
| `GrlRule` | GRL string literal | n/a | `rule_engine.rs` |
| `RcaReport` | `RcaResult` | n/a | `seven_level_rca.rs` |
| `DyingGaspCheckpoint` | `DyingGaspCheckpoint` | n/a | `apoptosis.rs` |
| `HysteresisState` | `HysteresisController` | n/a | `hysteresis.rs` |
| `BuildHistory` | `BuildEmaRecord` | n/a | `build_oracle.rs` |

## Allium Language Essentials

### Entities (domain objects with identity)
```allium
entity Container {
    name: String
    health: HealthStatus
    is_running: this.health != unreachable  -- derived value

    transitions health {
        unknown -> healthy
        healthy -> degraded
        degraded -> unhealthy
        terminal: -- none (containers recover)
    }
}
```

### Rules (event-driven behavior)
```allium
rule RestartOnDrift {
    when: orient: Orientation where drift_detected
    let target = orient.twin_drifts.first
    requires: target != null
    requires: not orient.missing_critical_nodes
    ensures: target.container.health = healthy
    @guidance -- Salience 80. Restart only first drifted container.
}
```

- `when`: Trigger (state transition, temporal, creation, external action)
- `let`: Local binding
- `requires`: Precondition (must be true for rule to fire)
- `ensures`: Postcondition (state changes, entity creation, event emission)
- `@guidance`: Implementation notes for developers

### Contracts (module boundaries)
```allium
contract RuleEngine {
    evaluate: (obs: Observation, orient: Orientation) -> Decision
    @invariant Deterministic -- Same inputs → same output
    @invariant SubMillisecond -- < 1ms via RETE-UL
}
```

- `demands`: The counterpart MUST implement this
- `fulfils`: This surface provides the implementation

### Invariants (always-true properties)
```allium
invariant QuorumMaintained {
    for boot in BootSequences where phase != preflight:
        zenoh_routers_running >= 2
}
```
Must be **pure**: no `now`, no side effects, no mutations.

### Config (parameterized values)
```allium
config {
    ooda_cycle_sla_ms: Integer = 100
    cpu_hard_limit: Integer = 85
}
```
Referenced in rules: `config.ooda_cycle_sla_ms`

### Surfaces (actor-facing boundaries)
```allium
surface OperatorDashboard {
    facing viewer: Operator
    exposes: boot.phase, boot.progress
    provides: EmergencyStop(reason: String)
    contracts: demands PodmanOperations
    @guarantee OperatorCanAlwaysEmergencyStop
}
```

## Formal Verification Integration

The spec includes proof obligations for three formal systems:

### Agda (Dependent Types)
Verifies type-level properties at compile time:
- Boot phase monotonicity (phases never regress)
- Quorum preservation during upgrades
- Dying gasp totality (every termination checkpoints)
- OODA decision exhaustiveness

### Quint (Executable Specification)
State machine bounded model checking:
- DAG acyclicity before every tier boot
- Hysteresis convergence (always reaches stable state)
- Cascade containment bound (depth <= 3)
- Rule engine determinism

### TLA+ (Temporal Logic)
Distributed system correctness:
- Consensus safety (2oo3 routers agree)
- Boot completion liveness (eventually reaches swarm)
- Split-brain prevention (partitions always resolved)
- OODA fairness (all observations processed)

## FMEA Integration

15 failure modes with RPN (Severity × Occurrence × Detection):

| RPN | Failure | GRL Rule | Playbook |
|-----|---------|----------|----------|
| 252 | NIF Compilation | (preflight blocks) | rebuild deps |
| 225 | Glibc/Musl | (substrate_guard) | rm _build |
| 216 | Cascading Failure | GrlApoptosisCascade | tier isolation |
| 196 | Memory Leak | GrlDrainMemoryLeak | drain + restart |
| 196 | Health Timeout | GrlRestartOnDrift | increase timeout |

## Workflow: Adding a New Feature

**Example**: "Add container log streaming"

**Step 1**: `/allium:tend add container log streaming with real-time search`

**Step 2**: Tend agent writes to `specs/allium/ignition.allium`:
```allium
entity LogStream {
    container: Container
    lines: List<String>
    filter: String?
    is_active: Boolean
}

rule StartLogStream {
    when: StreamRequested(container_name, filter)
    let c = Container{name: container_name}
    requires: c.is_running
    ensures: LogStream.created(container: c, filter: filter, is_active: true)
}

rule StopLogStream {
    when: stream: LogStream.is_active becomes false
    ensures: not exists stream
}
```

**Step 3**: Implement in Rust (`podman.rs` or new `log_stream.rs`)

**Step 4**: `/allium:weed native/ignition_daemon/src/log_stream.rs`
- Reports alignment or drift

## Workflow: Detecting Drift

**Example**: OODA supervisor has a bug at line 207

**Step 1**: `/allium:weed native/ignition_daemon/src/ooda_supervisor.rs`

**Step 2**: Weed agent compares:
- Spec rule `OodaDecideViaRules` says: `when: orient: Orientation.created` (orient is a parameter)
- Code says: `self.observation` (self doesn't have this field)

**Step 3**: Reports: "DIVERGED: ooda_supervisor.rs:207 references `self.observation` but spec says observation is passed via `observe()` return value. Is the code wrong or spec aspirational?"

## Reference: All STAMP Constraints in Spec

| Family | IDs | Allium Mapping |
|--------|-----|---------------|
| SC-IGNITE | 001-008 | Rules: GeneticResynthesis, PreflightCheck, TierBoot |
| SC-BOOT | 001-012 | Entity: BootSequence, Rules: TierBoot, QuorumVerification |
| SC-SIL4 | 001-029 | Invariants: QuorumMaintained, Rules: ApoptosisInitiate |
| SC-OODA | 001-009 | Rules: OodaObserve/Orient/Decide/Act, Invariant: OodaCycleSLA |
| SC-EMR | 057 | Rule: EmergencyStop |
| SC-CPU-GOV | 001 | Invariant: CpuGovernorLimit |
| SC-RCA | 001-002 | Entity: RcaReport, Rule: SevenLevelAnalysis |
| SC-FMEA | 001-008 | 15 failure modes in FMEA section |
| SC-TUI-TEST | 001-010 | 7-layer testing pyramid in testing section |
| SC-GLM-TST | 001-002 | 8-category gold standard in testing section |
| SC-MATH-COV | 001-008 | Math gates (H, CCM, ITQS) in testing section |
| SC-HMI | 001-080 | UI dashboard spec (12 tabs, palette, dark cockpit) |

## Mathematical Structures in Spec (33 total)

The Allium spec documents all 33 mathematical structures used across the codebase:

| # | Structure | Category | Formula/Algorithm | File |
|---|-----------|----------|-------------------|------|
| 1 | Shannon Entropy (H) | Info Theory | H = -∑(p_i × log₂(p_i)) | coverage_math.gleam |
| 2 | Normalized Entropy | Info Theory | H_norm = H / 3.0 | coverage_math.gleam |
| 3 | Fleet Stability (FSI) | Info Theory | FSI = 1 - σ(H)/μ(H) | coverage_math.gleam |
| 4 | Composite Coverage (CCM) | Metrics | ∑(w_i × cov_i) / ∑(w_i) | coverage_math.gleam |
| 5 | Divergence (D_EA) | Metrics | \|expected\\tested\| / \|expected\| | coverage_math.gleam |
| 6 | ITQS | Metrics | 0.25H + 0.35CCM + 0.25(1-D) + 0.15FSI | coverage_math.gleam |
| 7 | Jaccard Similarity | Alignment | \|A∩B\| / \|A∪B\| | alignment.gleam |
| 8 | PageRank | Graph | rank = (1-d)/N + d×∑(rank/out) | nav_graph.gleam |
| 9 | Graph Density | Graph | \|E\| / N(N-1) | nav_graph.gleam |
| 10 | SCC Count | Graph | Strongly connected components | nav_graph.gleam |
| 11 | Chinese Postman | Graph | Min edge traversal | nav_graph.gleam |
| 12 | Kahn's Algorithm | DAG | Topological sort O(V+E) | prometheus.gleam, dag.rs |
| 13 | DFS Cycle Detection | DAG | White/Gray/Black coloring | dag.rs |
| 14 | Wave Parallelization | DAG | Level-by-level partitioning | dag.rs |
| 15 | Path Verification | DAG | Edge pair existence | prometheus.gleam |
| 16 | Set Exclusivity | DAG | path_a ∩ path_b = ∅ | prometheus.gleam |
| 17 | CPM Forward Pass | Scheduling | ES = max(EF_pred); EF = ES + dur | cpm.rs |
| 18 | CPM Backward Pass | Scheduling | LF = min(LS_succ); LS = LF - dur | cpm.rs |
| 19 | Float/Critical Path | Scheduling | float = LS - ES; critical if 0 | cpm.rs |
| 20 | Hysteresis Controller | State Machine | N-consecutive transitions | hysteresis.rs |
| 21 | PID Controller | Control | K_p×e + K_i×∫e + K_d×de/dt | F# Prajna |
| 22 | FPPS 5-Method Consensus | Consensus | ≥3/5 methods agree | health_orchestra.rs |
| 23 | 2oo3 Quorum Voting | Consensus | Q(N) = ⌊N/2⌋+1 | health.rs |
| 24 | EMA (Build Prediction) | Time Series | EMA_t = α×x + (1-α)×EMA_{t-1} | build_oracle.rs |
| 25 | CPU% Differential | Monitoring | active_Δ / total_Δ × 100 | governor.rs |
| 26 | Adaptive Parallelism | Resource | f(cpu%) → (schedulers, jobs, nice) | governor.rs |
| 27 | RETE-UL Algorithm | Expert System | Forward+backward chaining | rule_engine.rs |
| 28 | RPN (FMEA Risk) | Risk | S × O × D (max 1000) | recovery.rs |
| 29 | Category Morphisms | Type Theory | ≅ ↠ ↪ ∅ (CLR→BEAM) | MSTS rules |
| 30 | Standard Deviation | Statistics | σ = √(∑(x-μ)²/n) | coverage_math.gleam |
| 31 | Mean | Statistics | μ = ∑x/n | coverage_math.gleam |
| 32 | SHA-256 Hash | Crypto | Dying gasp checkpoint integrity | apoptosis.rs |
| 33 | Ed25519 Signature | Crypto | Container attestation | launch.rs |

## Reference: All AOR Rules in Spec

| Family | IDs | Allium Mapping |
|--------|-----|---------------|
| AOR-IGNITE | 001-005 | GeneticResynthesis before boot, health checks mandatory |
| AOR-OODA | 001-005 | Phase budgets (30/20/20/20ms), cycle SLA 100ms |
| AOR-FUNC | 001-008 | Compilation gate, rollback, halt on violation |
| AOR-TPS | 001-003 | Jidoka stop, Zenoh signal, 5-level RCA |
| AOR-ZENOH | 001-008 | NIF enabled, health every 10s, subscribe on startup |
| AOR-DELETE | 001-002 | Backup before deletion, present list to operator |

## Daily Workflow

### Starting a Session
1. Read `specs/allium/ignition.allium` to refresh behavioral context
2. Check `specs/allium/CHECKLIST.md` for completeness gaps
3. Use `/allium` to get current spec status

### Adding a Feature
```
1. /allium:tend <feature description>        # Grow spec from requirements
2. Implement in Rust/Gleam                    # Write code
3. /allium:weed <source-path>                 # Detect drift
4. /allium:propagate                          # Generate tests from spec
5. Update journal (13-section template)       # Document per SC-JOURNAL
```

### Debugging a Failure
```
1. Read rule in ignition.allium               # What SHOULD happen?
2. Read code in corresponding .rs/.gleam      # What DOES happen?
3. If diverged: fix code (bug) OR update spec (design change)
4. /allium:weed to verify alignment
```

### Before a Release
```
1. /allium:weed native/ignition_daemon/src/   # Check all Rust drift
2. /allium:weed lib/cepaf_gleam/src/          # Check all Gleam drift
3. Verify all open questions resolved          # Spec §13
4. Run CHECKLIST.md quality gates              # All items checked
5. gleam test (1,721+ pass, 0 fail)           # Math gates: H>=2.5, CCM>=0.90
6. cargo run --bin ignition split-test         # 0% panic rate
```

## Command Reference

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/allium` | Examine project, suggest actions | Start of session |
| `/allium:tend <req>` | Grow spec from requirements | Adding features |
| `/allium:weed <path>` | Detect spec ↔ code drift | After code changes |
| `/allium:distill` | Extract spec from existing code | Reverse engineering |
| `/allium:elicit` | Structured stakeholder conversation | New domain modeling |
| `/allium:propagate` | Generate tests from spec | Test creation |

## File Inventory

| File | Lines | Purpose |
|------|-------|---------|
| `specs/allium/ignition.allium` | 2,215 | Main spec (26 sections, 24 implemented + 35 planned GRL rules) |
| `specs/allium/TEMPLATE.allium` | 316 | Reusable template |
| `specs/allium/CHECKLIST.md` | 144 | Completeness checklist |
| `.claude/commands/allium.md` | 116 | Custom skill commands |
| `.claude/rules/allium-behavioral-specs.md` | 123 | SC-ALLIUM protocol |
| `.agents/skills/allium/SKILL.md` | 12,712 | Official Allium skill |
| `.agents/skills/allium/references/language-reference.md` | 104K | Full syntax reference |
| `.agents/skills/allium/references/patterns.md` | 88K | 9 reusable patterns |
| `.agents/skills/allium/references/test-generation.md` | 10K | Test generation guide |
| `docs/allium-user-guide.md` | this file | Usage guide |

## Spec Section Map (26 sections)

| §# | Section | Content |
|----|---------|---------|
| 1 | External Entities | PodmanDaemon, ZenohRouter, PostgresDB, OtelCollector, Guardian, OpenRouter |
| 2 | Enumerations | ImageCategory, Criticality, BootPhase, HealthStatus, OodaPhase, Decision, RcaLevel, FractalLayer, ApoptosisTrigger/Phase |
| 3 | Value Types | HealthConsensus, MethodResult, TwinDrift, BuildResult, CpmTask, CheckpointMessage |
| 4 | Config | 20 params (boot timing, OODA budgets, health, hysteresis, build, CPU, apoptosis, rules, LLM) |
| 5 | Entities | Container, Genome, HysteresisState, BootSequence, OodaCycle, Observation, Orientation, GrlRule, RcaReport, DyingGaspCheckpoint, BuildHistory |
| 6 | Contracts | PodmanOperations, HealthOrchestra, RuleEngine, LLMAdvisor, GuardianGate |
| 7 | Actors | Operator, AiAgent, Guardian |
| 8 | Rules | 16 rules: boot (4), OODA (5), GRL (7), health (2), build (1), apoptosis (2), RCA (1) |
| 9 | Invariants | QuorumMaintained, OodaCycleSLA, CpuGovernorLimit, DyingGaspBeforeShutdown, BuildHistoryEMA |
| 10 | Surfaces | OperatorDashboard, AiAdvisorInterface, ZenohMeshBus |
| 11 | Defaults | (none currently) |
| 12 | Deferred | CriticalPathMethod.optimize, MathematicalSystemMonitor.evaluate |
| 13 | Open Questions | 4 unresolved design decisions |
| 14 | Formal Verification | Agda (5 proofs), Quint (6 properties), TLA+ (6 temporal) |
| 15 | STAMP Constraints | SC-IGNITE, SC-BOOT, SC-SIL4, SC-OODA, SC-EMR, SC-CPU-GOV, SC-RCA, SC-TUI-TEST, SC-GLM-TST, SC-MATH-COV |
| 16 | AOR Rules | AOR-IGNITE, AOR-OODA, AOR-FUNC, AOR-TPS, AOR-ZENOH, AOR-DELETE |
| 17 | FMEA | 15 failure modes with RPN scoring and GRL rule mappings |
| 18 | UI Spec | 12-tab registry, INDRAJAAL palette, dark cockpit 5-mode, split-screen, Penta-Stack |
| 19 | Testing (basic) | Math gates (H, CCM, ITQS), BDD levels, flight check, observers |
| 20 | Mathematical Structures | 33 structures across 15 categories |
| 21 | Knowledge Map | 38 journals, 7 docs, 33 Rust, 13 Gleam, 15 F# files cross-referenced |
| 22 | UI Testing (detailed) | 7-layer pyramid, C1-C8, regression, graph-theory, Golden Triangle, AG-UI, tab matrix |
| 23 | Implementation Notes | 8 algorithms, caching strategies, known bugs |
| 24 | Design Principles & Patterns | 8 principles, 7 patterns |
| 25 | Anti-Patterns | 9 documented, with fixes |
| 26 | Journal Template | 13-section SC-JOURNAL mandatory structure |
