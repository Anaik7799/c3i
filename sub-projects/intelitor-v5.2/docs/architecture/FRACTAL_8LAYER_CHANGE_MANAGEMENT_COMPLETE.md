# 8-Layer Fractal Change Management Complete Specification

**Version**: 21.3.0-SIL6 | **Date**: 2026-01-10 | **Author**: Claude Opus 4.5
**Status**: ACTIVE | **Compliance**: IEC 61508 SIL-6 (Biomorphic Extended)
**Degrees of Detail**: 8 (Specification → Monitoring)

---

## Document Control

| Field | Value |
|-------|-------|
| Document ID | FCMS-21.3.0-001 |
| Classification | INTERNAL |
| Review Cycle | Quarterly |
| Owner | Architecture Team |
| STAMP Coverage | SC-CHG-*, SC-FUNC-*, SC-OODA-* |

---

## Table of Contents

### 8 Degrees of Detail

1. **D1: SPECIFICATION** - Requirements, constraints, invariants
2. **D2: ARCHITECTURE** - 8-layer structure, component relationships
3. **D3: IMPLEMENTATION** - Code patterns, algorithms, data structures
4. **D4: USAGE** - Commands, workflows, procedures
5. **D5: PROCESSES** - SOPs, change workflows, approvals
6. **D6: REFERENCES** - Related documents, standards, mappings
7. **D7: OPERATIONS** - Runtime behavior, monitoring, alerting
8. **D8: EVOLUTION** - Adaptation, learning, improvement

---

# DEGREE 1: SPECIFICATION

## 1.1 Core Requirements

### 1.1.1 Functional Requirements

| ID | Requirement | Priority | STAMP |
|----|-------------|----------|-------|
| FR-001 | System MUST maintain functional state across all changes | P0 | SC-FUNC-001 |
| FR-002 | All changes MUST be traceable via Immutable Register | P0 | SC-REG-001 |
| FR-003 | 8-layer fractal architecture MUST be preserved | P0 | SC-ARCH-001 |
| FR-004 | OODA loops MUST execute within layer-specific timing | P0 | SC-OODA-001 |
| FR-005 | Swarming MUST coordinate 50 agents across layers | P1 | SC-BIO-003 |
| FR-006 | GDE MUST evolve code through 6-phase cycle | P1 | SC-GDE-001 |
| FR-007 | Guardian MUST validate all L3+ changes | P0 | SC-GDE-004 |
| FR-008 | Rollback MUST be possible at 4 layers | P0 | SC-CHG-REVERSE |

### 1.1.2 Non-Functional Requirements

| ID | Requirement | Target | Constraint |
|----|-------------|--------|------------|
| NFR-001 | OODA L1 cycle time | <1ms | SC-OODA-L1-001 |
| NFR-002 | OODA L7 cycle time | <1s | SC-OODA-L7-001 |
| NFR-003 | Agent swarm size | 25-50 | SC-BIO-003 |
| NFR-004 | Context compaction threshold | 75% | SC-BIO-004 |
| NFR-005 | Quality gate pass rate | 80%+ | SC-BIO-002 |
| NFR-006 | Error budget consumption | <80% | SC-SRE-001 |
| NFR-007 | Rollback time L1 | <1s | SC-EMR-057 |
| NFR-008 | Rollback time L4 | <5min | SC-EMR-060 |

### 1.1.3 Constitutional Invariants (Ψ₀-Ψ₅)

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                    CONSTITUTIONAL INVARIANTS (IMMUTABLE)                       ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  Ψ₀ EXISTENCE ─────────────────────────────────────────────────────────────   ║
║      System MUST survive ALL operations                                        ║
║      Exception: Ω₀.5 Mutual Termination clause                                ║
║                                                                                ║
║  Ψ₁ REGENERATION ──────────────────────────────────────────────────────────   ║
║      Complete state reconstructible from SQLite/DuckDB ONLY                    ║
║      External dependencies = 0 for regeneration                                ║
║                                                                                ║
║  Ψ₂ HISTORY ───────────────────────────────────────────────────────────────   ║
║      Evolution lineage MUST be complete in DuckDB                              ║
║      No gaps in change history permitted                                       ║
║                                                                                ║
║  Ψ₃ VERIFICATION ──────────────────────────────────────────────────────────   ║
║      All state changes MUST be verifiable via hash chain                       ║
║      FPPS 5-method consensus for critical paths                                ║
║                                                                                ║
║  Ψ₄ HUMAN ALIGNMENT ───────────────────────────────────────────────────────   ║
║      PRIMARY: Founder's lineage (Ω₀)                                           ║
║      SECONDARY: Humanity benefit                                               ║
║                                                                                ║
║  Ψ₅ TRUTHFULNESS ──────────────────────────────────────────────────────────   ║
║      No deception in any communication                                         ║
║      Audit trail MUST reflect actual actions                                   ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

## 1.2 STAMP Constraints (Change Management)

### 1.2.1 Core Change Constraints

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-CHG-001 | All changes MUST have structured change notes | CRITICAL | Pre-commit hook |
| SC-CHG-002 | 4-layer impact analysis MANDATORY before merge | CRITICAL | PR template |
| SC-CHG-003 | Reversal procedure MUST be documented | CRITICAL | PR checklist |
| SC-CHG-004 | Version MUST be updated on release | HIGH | CI gate |
| SC-CHG-005 | In-file change history MUST be maintained | HIGH | Code review |
| SC-CHG-006 | CHANGELOG.md MUST be updated per PR | HIGH | PR template |
| SC-CHG-007 | Breaking changes REQUIRE Guardian approval | CRITICAL | PR label |
| SC-CHG-008 | Rollback MUST be tested before merge | CRITICAL | CI gate |
| SC-CHG-009 | Impact score > 20 REQUIRES architecture review | HIGH | PR label |
| SC-CHG-010 | All changes logged to Immutable Register | CRITICAL | Post-commit hook |

### 1.2.2 Layer-Specific Constraints

| Layer | Constraint ID | Constraint | OODA Budget |
|-------|---------------|------------|-------------|
| L0 | SC-L0-001 | NO CHANGES PERMITTED | N/A |
| L1 | SC-L1-001 | Pure function changes only | <1ms |
| L2 | SC-L2-001 | GenServer state awareness required | 100ms |
| L3 | SC-L3-001 | SQLite/DuckDB state sovereignty | <100ms |
| L4 | SC-L4-001 | Container health check mandatory | 10s |
| L5 | SC-L5-001 | BEAM scheduler configuration only | 500ms |
| L6 | SC-L6-001 | 2oo3 quorum required | 30s |
| L7 | SC-L7-001 | Federation protocol negotiation | 1s |

## 1.3 AOR Rules (Change Management)

### 1.3.1 Core AOR Rules

| ID | Rule | Violation Response |
|----|------|-------------------|
| AOR-CHG-001 | DOCUMENT change before coding | Block commit |
| AOR-CHG-002 | ANALYZE 4-layer impact before PR | Block merge |
| AOR-CHG-003 | PLAN reversal procedure before deployment | Block deploy |
| AOR-CHG-004 | UPDATE version on every release | CI failure |
| AOR-CHG-005 | TRACK changes in file headers | Code review flag |
| AOR-CHG-006 | LOG to Immutable Register post-commit | Audit violation |
| AOR-CHG-007 | VERIFY rollback works in staging | Block production |
| AOR-CHG-008 | NOTIFY stakeholders of breaking changes | Process violation |
| AOR-CHG-009 | PRESERVE change history in git | Never rebase shared |
| AOR-CHG-010 | CHECKPOINT before risky operations | Mandatory L3+ |

### 1.3.2 OODA-Specific AOR Rules

| ID | Rule | Layer Scope |
|----|------|-------------|
| AOR-OODA-001 | OBSERVE system state before any action | All |
| AOR-OODA-002 | ORIENT with 5-order impact analysis | L2+ |
| AOR-OODA-003 | DECIDE with constitutional check | L3+ |
| AOR-OODA-004 | ACT with telemetry and rollback ready | All |
| AOR-OODA-005 | VERIFY cascade effects post-action | All |

---

# DEGREE 2: ARCHITECTURE

## 2.1 8-Layer Fractal Architecture

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                    8-LAYER FRACTAL ARCHITECTURE (L0-L7)                        ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  L7: FEDERATION ─────────────────────────────────────────────────────────────  ║
║      │ Cross-holon coordination, global consensus, attestation                 ║
║      │ OODA: 1s | Impact: ×4 | Agents: Executive oversight                    ║
║      │ Change Velocity: VERY LOW | Guardian: REQUIRED                          ║
║      ▼                                                                         ║
║  L6: CLUSTER ────────────────────────────────────────────────────────────────  ║
║      │ 2oo3 voting, quorum consensus, mesh coordination                        ║
║      │ OODA: 30s sync | Impact: ×4 | Agents: Domain supervisors               ║
║      │ Change Velocity: VERY LOW | Guardian: REQUIRED                          ║
║      ▼                                                                         ║
║  L5: NODE ───────────────────────────────────────────────────────────────────  ║
║      │ BEAM VM, scheduler, OTP supervision, resource management               ║
║      │ OODA: 500ms | Impact: ×4 | Agents: Functional agents                   ║
║      │ Change Velocity: LOW | Guardian: RECOMMENDED                            ║
║      ▼                                                                         ║
║  L4: CONTAINER ──────────────────────────────────────────────────────────────  ║
║      │ Podman orchestration, health checks, network isolation                  ║
║      │ OODA: 10s | Impact: ×3 | Agents: Container managers                    ║
║      │ Change Velocity: LOW | Guardian: RECOMMENDED                            ║
║      ▼                                                                         ║
║  L3: HOLON/AGENT ────────────────────────────────────────────────────────────  ║
║      │ Agent logic, SQLite/DuckDB state, Immutable Register                   ║
║      │ OODA: <100ms | Impact: ×3 | Agents: Domain workers                     ║
║      │ Change Velocity: MEDIUM | Guardian: CONDITIONAL                         ║
║      ▼                                                                         ║
║  L2: MODULE/COMPONENT ───────────────────────────────────────────────────────  ║
║      │ GenServer state, Ash domains, OTP behaviors                            ║
║      │ OODA: 100ms | Impact: ×2 | Agents: Code workers                        ║
║      │ Change Velocity: MEDIUM-HIGH | Guardian: OPTIONAL                       ║
║      ▼                                                                         ║
║  L1: FUNCTION ───────────────────────────────────────────────────────────────  ║
║      │ Pure functions, I/O contracts, type specs                              ║
║      │ OODA: <1ms | Impact: ×1 | Agents: Micro-workers                        ║
║      │ Change Velocity: HIGH | Guardian: NOT REQUIRED                          ║
║      ▼                                                                         ║
║  L0: CONSTITUTION ───────────────────────────────────────────────────────────  ║
║      │ Ψ₀-Ψ₅ invariants, Founder's Directive (Ω₀)                             ║
║      │ IMMUTABLE - No changes permitted                                        ║
║      │ Change Velocity: ZERO | Guardian: DEUS EX MACHINA ONLY                  ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

## 2.2 Layer Responsibility Matrix

| Layer | Responsibility | State Store | Change Freq | OODA | Impact |
|-------|---------------|-------------|-------------|------|--------|
| L0 | Constitutional invariants | Hardcoded | NEVER | N/A | ∞ |
| L1 | Pure function logic | None (stateless) | High | <1ms | ×1 |
| L2 | Module/component behavior | GenServer state | Medium | 100ms | ×2 |
| L3 | Agent coordination | SQLite/DuckDB | Medium | <100ms | ×3 |
| L4 | Container lifecycle | Volume mounts | Low | 10s | ×3 |
| L5 | Runtime environment | BEAM/OTP | Low | 500ms | ×4 |
| L6 | Cluster consensus | Distributed state | Very Low | 30s | ×4 |
| L7 | Federation coordination | Cross-holon | Very Low | 1s | ×4 |

## 2.3 Agent Swarm Architecture (50 Agents)

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                      AGENT SWARM ARCHITECTURE (50 AGENTS)                      ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  LAYER 1: EXECUTIVE (1 Agent) ────────────────────────────────────────────    ║
║  │  EXEC-001: Master Orchestrator (Opus model)                                 ║
║  │  • Veto authority over all changes                                          ║
║  │  • /compact trigger at 75% context                                          ║
║  │  • Strategic OODA (1s cycle)                                                ║
║  │  • L5-L7 change approval                                                    ║
║  └─────────────────────────────────────────────────────────────────────────    ║
║                                                                                ║
║  LAYER 2: DOMAIN SUPERVISORS (10 Agents) ─────────────────────────────────    ║
║  │  SUP-ACCESS    │ Access control domain                                      ║
║  │  SUP-ALARMS    │ Alarm management domain                                    ║
║  │  SUP-DEVICES   │ Device management domain                                   ║
║  │  SUP-SAFETY    │ Safety & compliance domain                                 ║
║  │  SUP-BILLING   │ Billing & metering domain                                  ║
║  │  SUP-CONFIG    │ Configuration domain                                       ║
║  │  SUP-INTEGR    │ Integration domain                                         ║
║  │  SUP-ANALYT    │ Analytics domain                                           ║
║  │  SUP-COMPLI    │ Compliance domain                                          ║
║  │  SUP-INTELLI   │ Intelligence domain (Sonnet model)                        ║
║  └─────────────────────────────────────────────────────────────────────────    ║
║                                                                                ║
║  LAYER 3: FUNCTIONAL AGENTS (15 Agents) ──────────────────────────────────    ║
║  │  Guardian      │ Safety kernel, constitutional checks                       ║
║  │  Sentinel      │ Health monitoring, threat detection                        ║
║  │  PatternHunter │ Pre-error pattern detection                                ║
║  │  TrainingGym   │ RL learning, fitness tracking                              ║
║  │  GDE           │ Goal-Directed Evolution controller                         ║
║  │  MetricsSink   │ Telemetry aggregation                                      ║
║  │  TelemetryHub  │ OTEL integration                                           ║
║  │  EventRouter   │ UnifiedBus routing                                         ║
║  │  StateManager  │ Holon state coordination                                   ║
║  │  CacheLayer    │ ETS/DETS caching                                           ║
║  │  BridgeSvc     │ Zenoh-LiveView bridge                                      ║
║  │  AuthProvider  │ UCAN/DID authentication                                    ║
║  │  AuditLogger   │ Immutable Register logging                                 ║
║  │  NotifyEngine  │ Alert distribution                                         ║
║  │  HealthCheck   │ FPPS validation                                            ║
║  └─────────────────────────────────────────────────────────────────────────    ║
║                                                                                ║
║  LAYER 4: WORKER AGENTS (24 Agents) ──────────────────────────────────────    ║
║  │  WRK-COMPILE-{1-3}    │ Parallel compilation (Haiku)                        ║
║  │  WRK-TEST-{1-5}       │ Test execution                                      ║
║  │  WRK-CREDO-{1-2}      │ Code quality checks                                 ║
║  │  WRK-FIX-{1-5}        │ Bug fix workers                                     ║
║  │  WRK-DOC-{1-2}        │ Documentation generation                            ║
║  │  WRK-EXPLORE-{1-3}    │ Codebase exploration                                ║
║  │  WRK-SWARM-{1-4}      │ Swarm coordination                                  ║
║  └─────────────────────────────────────────────────────────────────────────    ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

## 2.4 Three OODA Loop Implementations

| OODA Type | Cycle Time | Layers | Purpose | Agents |
|-----------|------------|--------|---------|--------|
| Fast OODA | 50ms | L1, L2 | Immediate code changes | WRK-* workers |
| Distributed OODA | <100ms | L3, L4 | Agent/container coordination | SUP-* supervisors |
| Strategy OODA | 1s | L5, L6, L7 | System-wide decisions | EXEC-001 |

### 2.4.1 OODA Timing Budget

| Phase | Fast (L1-L2) | Distributed (L3-L4) | Strategy (L5-L7) |
|-------|--------------|---------------------|------------------|
| OBSERVE | 5ms | 20ms | 200ms |
| ORIENT | 15ms | 30ms | 300ms |
| DECIDE | 15ms | 25ms | 250ms |
| ACT | 15ms | 25ms | 250ms |
| **Total** | **50ms** | **100ms** | **1000ms** |

## 2.5 5 Swarm Algorithms

| Algorithm | Use Case | Layers | Change Management Integration |
|-----------|----------|--------|------------------------------|
| Particle Swarm | Global optimization | L5-L7 | Best solution discovery |
| Ant Colony | Path finding | L3-L4 | Optimal change sequence |
| Bee Algorithm | Resource allocation | L2-L3 | Agent task distribution |
| Firefly | Clustering | L1-L2 | Related change grouping |
| Grey Wolf | Leadership | All | Supervisor hierarchy |

## 2.6 Elixir Core vs F# Cortex Separation

### 2.6.1 Responsibility Matrix

| Domain | Elixir Core | F# Cortex | Rationale |
|--------|-------------|-----------|-----------|
| **Runtime** | BEAM VM, OTP supervision | N/A | Native runtime |
| **State** | SQLite/DuckDB access | State queries | Elixir owns state |
| **Agents** | GenServer, Agent modules | Agent orchestration | F# coordinates |
| **OODA** | Fast OODA (<100ms) | Strategy OODA | F# for complex decisions |
| **Mesh** | Zenoh NIF bindings | SIL6MeshCLI, Panopticon | F# for SIL-6 Biomorphic ops |
| **Evolution** | GDE execution | Evolution planning | F# proposes, Elixir executes |
| **Monitoring** | Telemetry, OTEL | Dashboard TUI | F# observes Elixir |
| **Guardian** | Validation execution | Constitutional analysis | F# validates, Elixir enforces |

### 2.6.2 Elixir Core Modules

```
lib/indrajaal/
├── core/                       # L0-L1: Constitutional & Function Layer
│   ├── constitution.ex         # Ψ₀-Ψ₅ invariants (IMMUTABLE)
│   ├── founder_directive.ex    # Ω₀ implementation
│   └── functional_invariant.ex # SC-FUNC-* enforcement
├── domains/                    # L2: Module Layer (10 Ash domains)
│   ├── access/
│   ├── alarms/
│   ├── devices/
│   └── ...
├── agents/                     # L3: Holon/Agent Layer
│   ├── guardian.ex             # Safety kernel
│   ├── sentinel.ex             # Health monitoring
│   ├── training_gym.ex         # RL learning
│   └── gde_controller.ex       # Evolution execution
├── cortex/                     # L3-L4: Fast OODA
│   ├── fast_ooda.ex            # 50ms cycle
│   ├── unified_bus.ex          # Event routing
│   └── swarm_coordinator.ex    # Agent swarming
├── holon/                      # L3: State sovereignty
│   ├── sqlite_store.ex         # Real-time state
│   ├── duckdb_store.ex         # Analytics/history
│   └── immutable_register.ex   # Blockchain state
└── mesh/                       # L4-L5: Container/Node
    ├── container_manager.ex    # Podman orchestration
    ├── health_coordinator.ex   # FPPS validation
    └── zenoh_bridge.ex         # Mesh communication
```

### 2.6.3 F# Cortex Modules

```
lib/cepaf/src/
├── Core/                       # Foundation
│   ├── Domain.fs               # Domain types
│   ├── Constitution.fs         # Constitutional verification
│   └── Validation.fs           # Invariant checking
├── Mesh/                       # L4-L7: SIL-6 Biomorphic Operations
│   ├── SIL6MeshCLI.fs          # Unified entry point
│   ├── PanopticonOrchestrator.fs # Boot orchestration
│   ├── HealthCoordinator.fs    # 2oo3 voting
│   ├── Apoptosis.fs            # Controlled shutdown
│   └── FederationProtocol.fs   # Cross-holon
├── Intelligence/               # Strategy Layer
│   ├── EvolutionPlanner.fs     # GDE proposals
│   ├── ImpactAnalyzer.fs       # 5-order effects
│   └── ConstitutionalOracle.fs # Ψ verification
├── Observability/              # Observer Layer (SEPARATED)
│   ├── DigitalTwin.fs          # Authoritative state mirror
│   ├── TelemetryReceiver.fs    # Metric collection
│   ├── DashboardTUI.fs         # Terminal UI
│   └── AlertManager.fs         # Notification routing
└── Integration/                # Bridge Layer
    ├── ElixirBridge.fs         # Elixir ↔ F# RPC
    ├── ZenohClient.fs          # Mesh pub/sub
    └── DuckDBClient.fs         # Analytics queries
```

## 2.7 Observer/Observed Separation Pattern

### 2.7.1 Separation Principle

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║              OBSERVER/OBSERVED SEPARATION (DURING EVOLUTION)                   ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  OBSERVED SYSTEM (Elixir Core) ─────────────────────────────────────────────  ║
║  │                                                                             ║
║  │  ┌─────────────────────────────────────────────────────────────────────┐   ║
║  │  │  Production Code (L1-L5)                                            │   ║
║  │  │  • GenServers, Agents, Supervisors                                  │   ║
║  │  │  • Ash Resources, Domains                                           │   ║
║  │  │  • SQLite/DuckDB State                                              │   ║
║  │  │  • EVOLVING during GDE cycle                                        │   ║
║  │  └─────────────────────────────────────────────────────────────────────┘   ║
║  │                          │                                                  ║
║  │                          │ Telemetry Events (READONLY)                      ║
║  │                          ▼                                                  ║
║  │  ┌─────────────────────────────────────────────────────────────────────┐   ║
║  │  │  Telemetry Bus (Zenoh + Phoenix.PubSub)                             │   ║
║  │  │  • :telemetry events                                                │   ║
║  │  │  • zenoh:kpi, zenoh:metrics, zenoh:health                           │   ║
║  │  │  • IMMUTABLE EVENT STREAM                                           │   ║
║  │  └─────────────────────────────────────────────────────────────────────┘   ║
║  │                          │                                                  ║
║  └──────────────────────────┼──────────────────────────────────────────────   ║
║                             │                                                  ║
║  ═══════════════════════════╪═══════════════════════════════════════════════  ║
║  SEPARATION BOUNDARY        │  (No write access from observer to observed)    ║
║  ═══════════════════════════╪═══════════════════════════════════════════════  ║
║                             │                                                  ║
║  OBSERVER SYSTEM (F# Cortex) ───────────────────────────────────────────────  ║
║  │                          ▼                                                  ║
║  │  ┌─────────────────────────────────────────────────────────────────────┐   ║
║  │  │  DigitalTwin.fs (READ-ONLY MIRROR)                                  │   ║
║  │  │  • Receives telemetry, does NOT modify source                       │   ║
║  │  │  • Maintains shadow state for analysis                              │   ║
║  │  │  • STABLE during evolution                                          │   ║
║  │  └─────────────────────────────────────────────────────────────────────┘   ║
║  │                          │                                                  ║
║  │                          ▼                                                  ║
║  │  ┌─────────────────────────────────────────────────────────────────────┐   ║
║  │  │  Intelligence Layer (ISOLATED)                                      │   ║
║  │  │  • EvolutionPlanner: Proposes changes                               │   ║
║  │  │  • ImpactAnalyzer: Calculates effects                               │   ║
║  │  │  • ConstitutionalOracle: Verifies invariants                        │   ║
║  │  │  • CANNOT directly modify Elixir code                               │   ║
║  │  └─────────────────────────────────────────────────────────────────────┘   ║
║  │                          │                                                  ║
║  │                          │ Proposals (via Guardian gate)                    ║
║  │                          ▼                                                  ║
║  │  ┌─────────────────────────────────────────────────────────────────────┐   ║
║  │  │  Guardian Bridge (CONTROLLED WRITE PATH)                            │   ║
║  │  │  • Single point of mutation authorization                           │   ║
║  │  │  • Constitutional validation required                                │   ║
║  │  │  • Shadow test before activation                                     │   ║
║  │  └─────────────────────────────────────────────────────────────────────┘   ║
║  │                                                                             ║
║  └─────────────────────────────────────────────────────────────────────────   ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### 2.7.2 STAMP Constraints (Observer Separation)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-OBS-001 | Observer MUST NOT directly modify observed state | CRITICAL |
| SC-OBS-002 | All mutations MUST go through Guardian gate | CRITICAL |
| SC-OBS-003 | DigitalTwin MUST be read-only mirror | HIGH |
| SC-OBS-004 | Telemetry stream MUST be immutable | HIGH |
| SC-OBS-005 | Evolution proposals MUST be validated before execution | CRITICAL |
| SC-OBS-006 | Observer isolation MUST survive system evolution | CRITICAL |

### 2.7.3 AOR Rules (Observer Separation)

| ID | Rule |
|----|------|
| AOR-OBS-001 | F# Cortex SHALL receive telemetry via Zenoh subscription only |
| AOR-OBS-002 | F# Cortex SHALL NOT have direct access to Elixir GenServers |
| AOR-OBS-003 | Evolution proposals SHALL be sent to Guardian for validation |
| AOR-OBS-004 | DigitalTwin SHALL sync via event stream, not direct queries |
| AOR-OBS-005 | Dashboard TUI SHALL display cached state, not live queries |

---

# DEGREE 3: IMPLEMENTATION

## 3.1 Change Note Structure

### 3.1.1 Elixir Change Note Module

```elixir
defmodule Indrajaal.ChangeManagement.ChangeNote do
  @moduledoc """
  Structured change note for 8-layer fractal architecture.

  ## STAMP Constraints
  - SC-CHG-001: All changes MUST have structured change notes
  - SC-CHG-002: 4-layer impact analysis MANDATORY

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-01-10 | Claude | Initial implementation |
  """

  @type layer :: :L0 | :L1 | :L2 | :L3 | :L4 | :L5 | :L6 | :L7
  @type severity :: :none | :low | :medium | :high | :critical

  @enforce_keys [:change_id, :layer, :type, :impact_score]
  defstruct [
    :change_id,
    :layer,
    :type,
    :impact_score,
    :author,
    :timestamp,
    :files_modified,
    :modules_affected,
    :reversibility_plan,
    :constitutional_check,
    :guardian_approval,
    :shadow_tested
  ]

  @spec new(Keyword.t()) :: {:ok, t()} | {:error, term()}
  def new(attrs) do
    change_id = generate_change_id()
    timestamp = DateTime.utc_now()

    note = struct(__MODULE__,
      Keyword.merge(attrs, [
        change_id: change_id,
        timestamp: timestamp,
        constitutional_check: :pending,
        guardian_approval: nil,
        shadow_tested: false
      ])
    )

    with :ok <- validate_layer(note.layer),
         :ok <- validate_impact_score(note.impact_score, note.layer) do
      {:ok, note}
    end
  end

  @spec generate_change_id() :: String.t()
  defp generate_change_id do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    hash = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "CHG-#{timestamp}-#{hash}"
  end

  @spec validate_layer(layer()) :: :ok | {:error, :invalid_layer}
  defp validate_layer(layer) when layer in ~w(L0 L1 L2 L3 L4 L5 L6 L7)a, do: :ok
  defp validate_layer(_), do: {:error, :invalid_layer}

  @spec validate_impact_score(integer(), layer()) :: :ok | {:error, term()}
  defp validate_impact_score(_score, :L0), do: {:error, :l0_immutable}
  defp validate_impact_score(score, _) when score >= 0 and score <= 50, do: :ok
  defp validate_impact_score(score, _), do: {:error, {:invalid_score, score}}
end
```

### 3.1.2 F# Constitutional Verification

```fsharp
// lib/cepaf/src/Intelligence/ConstitutionalOracle.fs
namespace Indrajaal.Intelligence

open System
open Indrajaal.Core.Domain

/// Constitutional Oracle for Ψ₀-Ψ₅ verification
/// OBSERVER ONLY - Does not modify observed system
module ConstitutionalOracle =

    /// Constitutional invariants (Ψ₀-Ψ₅)
    type Invariant =
        | Existence       // Ψ₀: System survives all operations
        | Regeneration    // Ψ₁: State reconstructible from SQLite/DuckDB
        | History         // Ψ₂: Evolution lineage complete
        | Verification    // Ψ₃: All changes verifiable
        | HumanAlignment  // Ψ₄: Founder's lineage primary
        | Truthfulness    // Ψ₅: No deception

    /// Verification result
    type VerificationResult =
        | Passed of Invariant
        | Failed of Invariant * reason: string
        | Skipped of Invariant * reason: string

    /// Verify all constitutional invariants for a change proposal
    let verifyChange (proposal: ChangeProposal) : VerificationResult list =
        [
            verifyExistence proposal
            verifyRegeneration proposal
            verifyHistory proposal
            verifyVerification proposal
            verifyHumanAlignment proposal
            verifyTruthfulness proposal
        ]

    /// Ψ₀: Existence - System must survive
    let private verifyExistence (proposal: ChangeProposal) =
        match proposal.Layer with
        | L0 -> Failed (Existence, "L0 is immutable - existence violation")
        | _ when proposal.ImpactScore > 40 ->
            Failed (Existence, $"Impact score {proposal.ImpactScore} threatens system survival")
        | _ -> Passed Existence

    /// Ψ₁: Regeneration - State must be reconstructible
    let private verifyRegeneration (proposal: ChangeProposal) =
        if proposal.AffectsStateStore && not proposal.HasMigrationPath then
            Failed (Regeneration, "State change without migration path")
        else
            Passed Regeneration

    /// Ψ₄: Human Alignment - Founder's lineage primary
    let private verifyHumanAlignment (proposal: ChangeProposal) =
        match proposal.FounderImpact with
        | Positive -> Passed HumanAlignment
        | Neutral -> Passed HumanAlignment
        | Negative -> Failed (HumanAlignment, "Change harms Founder's lineage")

    /// Check if all invariants pass
    let allPass (results: VerificationResult list) =
        results |> List.forall (function
            | Passed _ -> true
            | Failed _ -> false
            | Skipped _ -> true)
```

## 3.2 OODA Loop Implementation

### 3.2.1 Elixir Fast OODA (50ms)

```elixir
defmodule Indrajaal.Cortex.FastOODA do
  @moduledoc """
  Fast OODA loop for L1-L2 layer changes.
  Target cycle time: 50ms

  ## STAMP Constraints
  - SC-OODA-001: Cycle time < 100ms
  - SC-BIO-001: OODA cycle < 100ms for L1-L3

  ## Observer/Observed
  This module is OBSERVED by F# DigitalTwin via telemetry.
  It does NOT directly communicate with F# layer.
  """

  use GenServer
  require Logger

  @cycle_interval_ms 50
  @observe_budget_ms 5
  @orient_budget_ms 15
  @decide_budget_ms 15
  @act_budget_ms 15

  defstruct [
    :buffer,
    :hysteresis,
    :last_decision,
    :cycle_count,
    :telemetry_ref
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Emit telemetry for observer
    :telemetry.execute([:ooda, :fast, :init], %{}, %{layer: :L1_L2})

    # Schedule first cycle
    Process.send_after(self(), :cycle, @cycle_interval_ms)

    {:ok, %__MODULE__{
      buffer: [],
      hysteresis: %{margin: 0.1, hold_cycles: 3, current_hold: 0},
      cycle_count: 0
    }}
  end

  @impl true
  def handle_info(:cycle, state) do
    start_time = System.monotonic_time(:microsecond)

    # OBSERVE (5ms budget)
    {observations, observe_time} = timed_observe(state)

    # ORIENT (15ms budget)
    {analysis, orient_time} = timed_orient(observations, state)

    # DECIDE (15ms budget)
    {decision, decide_time} = timed_decide(analysis, state)

    # ACT (15ms budget)
    {result, act_time} = timed_act(decision, state)

    total_time = System.monotonic_time(:microsecond) - start_time

    # Emit cycle telemetry for observer (F# DigitalTwin)
    :telemetry.execute([:ooda, :fast, :cycle], %{
      cycle_time_us: total_time,
      observe_us: observe_time,
      orient_us: orient_time,
      decide_us: decide_time,
      act_us: act_time,
      cycle_number: state.cycle_count + 1
    }, %{layer: :L1_L2})

    # Schedule next cycle
    Process.send_after(self(), :cycle, @cycle_interval_ms)

    {:noreply, %{state |
      cycle_count: state.cycle_count + 1,
      last_decision: decision
    }}
  end

  defp timed_observe(state) do
    start = System.monotonic_time(:microsecond)

    observations = %{
      compile_errors: check_compile_state(),
      test_failures: check_test_state(),
      quality_issues: check_quality_state(),
      pending_changes: get_pending_changes()
    }

    elapsed = System.monotonic_time(:microsecond) - start
    {observations, elapsed}
  end

  defp timed_orient(observations, state) do
    start = System.monotonic_time(:microsecond)

    analysis = %{
      stress_level: calculate_stress(observations),
      priority_queue: prioritize_changes(observations.pending_changes),
      impact_forecast: forecast_impact(observations)
    }

    elapsed = System.monotonic_time(:microsecond) - start
    {analysis, elapsed}
  end

  defp timed_decide(analysis, state) do
    start = System.monotonic_time(:microsecond)

    decision =
      cond do
        analysis.stress_level > 0.8 ->
          {:escalate, :high_stress}

        length(analysis.priority_queue) > 0 ->
          {:process, hd(analysis.priority_queue)}

        true ->
          {:idle, :no_pending}
      end
      |> apply_hysteresis(state.hysteresis)

    elapsed = System.monotonic_time(:microsecond) - start
    {decision, elapsed}
  end

  defp timed_act(decision, state) do
    start = System.monotonic_time(:microsecond)

    result =
      case decision do
        {:escalate, reason} ->
          Indrajaal.UnifiedBus.broadcast({:escalation, reason})
          :escalated

        {:process, change} ->
          execute_change(change)

        {:idle, _} ->
          :idle
      end

    elapsed = System.monotonic_time(:microsecond) - start
    {result, elapsed}
  end
end
```

### 3.2.2 F# Strategy OODA (1s) - Observer

```fsharp
// lib/cepaf/src/Intelligence/StrategyOODA.fs
namespace Indrajaal.Intelligence

open System
open System.Threading
open Indrajaal.Observability

/// Strategy OODA loop for L5-L7 decisions
/// OBSERVER ONLY - Receives telemetry, proposes through Guardian
module StrategyOODA =

    /// OODA cycle budget (1000ms total)
    let private observeBudgetMs = 200
    let private orientBudgetMs = 300
    let private decideBudgetMs = 250
    let private actBudgetMs = 250

    /// State received from Elixir via telemetry (READ-ONLY)
    type ObservedState = {
        ClusterHealth: float
        FederationStatus: string
        PendingEvolutions: EvolutionProposal list
        ErrorBudgetRemaining: float
        LastCycleMetrics: OODAMetrics option
    }

    /// Strategy decision (to be validated by Guardian)
    type StrategyDecision =
        | ApproveEvolution of EvolutionProposal
        | RejectEvolution of EvolutionProposal * reason: string
        | RequestScaleUp of nodeCount: int
        | RequestScaleDown of nodeCount: int
        | TriggerEmergencyMode of reason: string
        | MaintainCurrentState

    /// Run one strategy OODA cycle
    let runCycle (digitalTwin: DigitalTwin) : StrategyDecision =
        let startTime = DateTime.UtcNow

        // OBSERVE: Read from DigitalTwin (observer pattern)
        let observed = observe digitalTwin

        // ORIENT: Analyze with constitutional awareness
        let analysis = orient observed

        // DECIDE: Choose strategy with Guardian consultation
        let decision = decide analysis

        // ACT: Submit proposal (does NOT execute directly)
        act decision digitalTwin

        // Emit metrics for meta-observation
        let cycleTime = (DateTime.UtcNow - startTime).TotalMilliseconds
        TelemetryReceiver.emit "ooda.strategy.cycle" cycleTime

        decision

    /// OBSERVE phase: Read from DigitalTwin only
    let private observe (twin: DigitalTwin) : ObservedState =
        {
            ClusterHealth = twin.GetClusterHealth()
            FederationStatus = twin.GetFederationStatus()
            PendingEvolutions = twin.GetPendingEvolutions()
            ErrorBudgetRemaining = twin.GetErrorBudget()
            LastCycleMetrics = twin.GetLastOODAMetrics()
        }

    /// ORIENT phase: Constitutional analysis
    let private orient (state: ObservedState) =
        let constitutionalCheck =
            state.PendingEvolutions
            |> List.map ConstitutionalOracle.verifyChange

        let impactAnalysis =
            state.PendingEvolutions
            |> List.map ImpactAnalyzer.analyze5Order

        {|
            ConstitutionalResults = constitutionalCheck
            ImpactResults = impactAnalysis
            SystemStress = calculateStress state
            Recommendations = generateRecommendations state
        |}

    /// DECIDE phase: Choose action (hysteresis applied)
    let private decide (analysis) =
        if analysis.SystemStress > 0.9 then
            TriggerEmergencyMode "System stress > 90%"
        elif analysis.SystemStress < 0.3 && hasApprovedEvolutions analysis then
            ApproveEvolution (selectBestEvolution analysis)
        else
            MaintainCurrentState

    /// ACT phase: Submit to Guardian (does NOT execute)
    let private act (decision: StrategyDecision) (twin: DigitalTwin) =
        match decision with
        | ApproveEvolution proposal ->
            // Submit to Guardian via Zenoh - NOT direct execution
            Guardian.submitProposal proposal
        | TriggerEmergencyMode reason ->
            // Alert only - Elixir handles actual emergency
            AlertManager.triggerEmergency reason
        | _ -> ()
```

## 3.3 Guardian Safety Kernel

### 3.3.1 Elixir Guardian (Executor)

```elixir
defmodule Indrajaal.Agents.Guardian do
  @moduledoc """
  Safety kernel for all L3+ changes.
  Single point of mutation authorization.

  ## STAMP Constraints
  - SC-GDE-001: Guardian validation required
  - SC-GDE-004: Proposal threshold ≥0.85
  - SC-CONST-007: Guardian has absolute veto

  ## Observer/Observed Pattern
  - Receives proposals from F# Cortex via Zenoh
  - Executes validated changes in Elixir runtime
  - Emits telemetry for F# observation
  """

  use GenServer
  require Logger

  @approval_threshold 0.85
  @validation_checks 6

  defstruct [
    :pending_proposals,
    :approved_queue,
    :rejected_log,
    :veto_active
  ]

  # Proposal received from F# via Zenoh
  def handle_cast({:proposal, proposal}, state) do
    Logger.info("Guardian received proposal: #{proposal.id}")

    # Emit telemetry for observer
    :telemetry.execute([:guardian, :proposal, :received], %{
      proposal_id: proposal.id,
      layer: proposal.layer
    }, %{})

    # Run 6 validation checks
    validation_result = validate_proposal(proposal)

    case validation_result do
      {:approved, score} when score >= @approval_threshold ->
        Logger.info("Proposal approved with score #{score}")
        execute_approved(proposal, state)

      {:rejected, reason} ->
        Logger.warn("Proposal rejected: #{inspect(reason)}")
        reject_proposal(proposal, reason, state)
    end
  end

  defp validate_proposal(proposal) do
    checks = [
      check_constitutional_compliance(proposal),
      check_stamp_constraints(proposal),
      check_shadow_test_results(proposal),
      check_impact_score(proposal),
      check_reversibility(proposal),
      check_founder_directive(proposal)
    ]

    passed = Enum.count(checks, &(&1 == :ok))
    score = passed / @validation_checks

    if score >= @approval_threshold do
      {:approved, score}
    else
      failed_checks = Enum.filter(checks, &(&1 != :ok))
      {:rejected, {:validation_failed, failed_checks}}
    end
  end

  defp execute_approved(proposal, state) do
    # Log to Immutable Register BEFORE execution
    Indrajaal.Holon.ImmutableRegister.append_block(%{
      type: :evolution_approved,
      proposal_id: proposal.id,
      timestamp: DateTime.utc_now(),
      guardian_score: proposal.score
    })

    # Execute in Elixir runtime
    result = execute_evolution(proposal)

    # Emit completion telemetry
    :telemetry.execute([:guardian, :execution, :complete], %{
      proposal_id: proposal.id,
      result: result
    }, %{})

    {:noreply, %{state | approved_queue: [proposal | state.approved_queue]}}
  end
end
```

---

# DEGREE 4: USAGE

## 4.1 DevEnv Commands

### 4.1.1 Core Change Management Commands

```bash
# Enter development environment
devenv shell

# Compilation with Patient Mode (SC-METRICS-003)
compile                    # Standard compile with 16 schedulers
compile-strict             # Compile with warnings as errors
compile-profile            # Profiled compilation with timing

# Quality Gates
quality                    # Format + Credo
quality-full               # + Dialyzer + Sobelow

# Testing
test                       # Run tests with SKIP_ZENOH_NIF=0
test-cover                 # Generate coverage report

# SIL-6 Biomorphic Mesh Operations
sa-up                      # Boot mesh (5 stages)
sa-down                    # Transactional shutdown
sa-status                  # Health check
sa-health                  # FPPS 5-point validation
sa-verify                  # 2oo3 voting verification

# Checkpoint/Restore
sa-checkpoint [phase]      # Create checkpoint (1|2|3|4|full)
sa-checkpoint-restore      # Restore from checkpoint
sa-checkpoint-verify       # Run verification suite

# Database
db-setup                   # Create + migrate
db-migrate                 # Apply pending migrations
db-reset                   # Drop + recreate
```

### 4.1.2 Change Workflow Commands

```bash
# 1. Before making changes - Checkpoint current state
sa-checkpoint --phase full

# 2. Make changes and compile
compile-strict

# 3. Run quality gates
quality-full

# 4. Run tests
test-cover

# 5. Verify mesh health
sa-health

# 6. If all pass, commit with change note
git commit -m "$(cat <<'EOF'
feat(agents): Add PatternHunter pre-error detection

Change-Id: CHG-20260110-143000-abc123
Impact-Score: 15
Layers-Affected: L2,L3
Reversal: git revert $(git rev-parse HEAD)

STAMP: SC-IMMUNE-004, SC-CHG-001
AOR: AOR-IMMUNE-003

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

## 4.2 Impact Score Calculation

### 4.2.1 Formula

```
Impact Score = Σ(Layer Weight × Severity)

Layer Weights:
  L1-CODE:      ×1
  L2-DOMAIN:    ×2
  L3-SYSTEM:    ×3
  L4-ECOSYSTEM: ×4

Severity Levels:
  NONE:     0
  LOW:      1-2
  MEDIUM:   3-5
  HIGH:     6-8
  CRITICAL: 9-12
```

### 4.2.2 Example Calculations

| Change Type | L1 | L2 | L3 | L4 | Total | Mode |
|-------------|----|----|----|----|-------|------|
| Bug fix (function) | 2×1=2 | 0 | 0 | 0 | 2 | NORMAL |
| Add API endpoint | 2×1=2 | 4×2=8 | 0 | 0 | 10 | NORMAL |
| Database schema | 2×1=2 | 4×2=8 | 3×3=9 | 0 | 19 | NORMAL |
| Container config | 0 | 2×2=4 | 5×3=15 | 3×4=12 | 31 | CRITICAL |
| Breaking API | 3×1=3 | 6×2=12 | 6×3=18 | 8×4=32 | 65 | EMERGENCY |

### 4.2.3 Operational Mode Thresholds

| Mode | Score Range | Required Actions |
|------|-------------|------------------|
| NORMAL | 0-20 | Standard review |
| HIGH-RISK | 21-30 | Senior review required |
| CRITICAL | 31-40 | Architecture review + Guardian |
| EMERGENCY | 40+ | HALT + rollback |

## 4.3 Reversibility Commands

### 4.3.1 Layer 1: Git Reversal

```bash
# Revert single commit
git revert $(git rev-parse HEAD) --no-edit

# Revert range
git revert older_sha..newer_sha --no-edit

# Verify
compile-strict && test
```

### 4.3.2 Layer 2: Code Reversal

```bash
# Restore from backup
cp _backup/file.ex.bak lib/path/file.ex

# Force recompile
mix compile --force

# Verify specific tests
mix test --only affected
```

### 4.3.3 Layer 3: Database Reversal

```bash
# Rollback migration
mix ecto.rollback --step 1

# Restore from checkpoint
sa-checkpoint-restore --phase 1

# Verify data
mix run scripts/verify_data_integrity.exs
```

### 4.3.4 Layer 4: System Reversal

```bash
# Container rollback
podman tag localhost/indrajaal-app:latest localhost/indrajaal-app:failed
podman tag localhost/indrajaal-app:previous localhost/indrajaal-app:latest
sa-down && sa-up

# Full system restore
sa-checkpoint-restore --phase full
```

---

# DEGREE 5: PROCESSES

## 5.1 Standard Operating Procedures (SOPs)

### 5.1.1 SOP-CHG-001: Standard Change Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SOP-CHG-001: STANDARD CHANGE WORKFLOW                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  STEP 1: PLAN (Pre-Implementation)                                          │
│  ├─ Create Change Note with structure from Section 1.0                      │
│  ├─ Calculate 4-layer impact score                                          │
│  ├─ Document reversibility procedure                                        │
│  ├─ If impact > 20: Schedule architecture review                           │
│  └─ If impact > 30: Obtain Guardian pre-approval                           │
│                                                                              │
│  STEP 2: CHECKPOINT (State Preservation)                                    │
│  ├─ Run: sa-checkpoint --phase full                                         │
│  ├─ Verify checkpoint created                                               │
│  └─ Record checkpoint ID in change note                                     │
│                                                                              │
│  STEP 3: IMPLEMENT (Code Changes)                                           │
│  ├─ Create feature branch                                                   │
│  ├─ Write tests FIRST (TDG - SC-TDG-001)                                   │
│  ├─ Implement changes                                                       │
│  ├─ Update in-file change history                                          │
│  └─ Update CHANGELOG.md                                                     │
│                                                                              │
│  STEP 4: VERIFY (Quality Gates)                                             │
│  ├─ Run: compile-strict                                                     │
│  ├─ Run: quality-full                                                       │
│  ├─ Run: test-cover                                                         │
│  ├─ Verify coverage >= 95%                                                  │
│  └─ Run: sa-health                                                          │
│                                                                              │
│  STEP 5: REVIEW (Peer Approval)                                             │
│  ├─ Impact 0-20: Standard review (1 approver)                              │
│  ├─ Impact 21-30: Senior review (2 approvers)                              │
│  └─ Impact 31+: Architecture + Guardian (3 approvers)                      │
│                                                                              │
│  STEP 6: MERGE (Controlled Integration)                                     │
│  ├─ Squash or merge (preserve history)                                     │
│  ├─ Log to Immutable Register                                              │
│  ├─ Tag release if applicable                                              │
│  └─ Update PROJECT_TODOLIST.md                                             │
│                                                                              │
│  STEP 7: MONITOR (Post-Deployment)                                         │
│  ├─ Watch for regression in next 24h                                       │
│  ├─ Verify OODA cycles stable                                              │
│  ├─ Check Sentinel for anomalies                                           │
│  └─ Close change ticket on success                                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.1.2 SOP-CHG-002: Emergency Rollback

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SOP-CHG-002: EMERGENCY ROLLBACK                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  TRIGGER CONDITIONS:                                                        │
│  ├─ Constitutional invariant violation detected                            │
│  ├─ Impact score exceeded 40                                               │
│  ├─ Compilation failure after merge                                        │
│  ├─ Test suite failure rate > 10%                                          │
│  └─ Sentinel threat level CRITICAL                                         │
│                                                                              │
│  IMMEDIATE ACTIONS (< 1 minute):                                            │
│  ├─ Run: sa-emergency                                                       │
│  ├─ Notify: Guardian escalation                                            │
│  └─ Log: Incident start timestamp                                          │
│                                                                              │
│  ROLLBACK EXECUTION (< 5 minutes):                                          │
│  ├─ Determine affected layer(s)                                            │
│  ├─ Execute layer-appropriate rollback                                     │
│  │   ├─ L1 only: git revert                                                │
│  │   ├─ L2 involved: + mix compile --force                                 │
│  │   ├─ L3 involved: + mix ecto.rollback                                   │
│  │   └─ L4 involved: sa-checkpoint-restore --phase full                    │
│  └─ Verify functional state restored                                       │
│                                                                              │
│  POST-ROLLBACK (< 30 minutes):                                              │
│  ├─ Run: compile-strict && test                                            │
│  ├─ Run: sa-health                                                          │
│  ├─ Verify: All OODA cycles operational                                    │
│  └─ Document: Root cause preliminary                                       │
│                                                                              │
│  POSTMORTEM (< 24 hours):                                                   │
│  ├─ 5-Why RCA analysis                                                     │
│  ├─ Update FMEA with new failure mode                                      │
│  ├─ Add STAMP constraint if needed                                         │
│  └─ Train agents with episode in TrainingGym                               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.1.3 SOP-CHG-003: GDE Evolution Cycle

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SOP-CHG-003: GDE EVOLUTION CYCLE                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  PHASE 1: PROPOSAL GENERATION (F# Cortex - Observer)                       │
│  ├─ EvolutionPlanner analyzes DuckDB history                               │
│  ├─ Generates improvement proposals                                        │
│  ├─ Calculates fitness scores                                              │
│  └─ Maintains diversity floor (0.3)                                        │
│                                                                              │
│  PHASE 2: CONSTITUTIONAL CHECK (F# Cortex - Observer)                      │
│  ├─ ConstitutionalOracle verifies Ψ₀-Ψ₅                                    │
│  ├─ Founder's Directive (Ω₀) alignment check                               │
│  ├─ STAMP constraint validation                                            │
│  └─ Impact score calculation                                               │
│                                                                              │
│  PHASE 3: SHADOW TESTING (Elixir - Isolated)                               │
│  ├─ Fork shadow environment                                                │
│  ├─ Apply proposed changes                                                 │
│  ├─ Run full test suite                                                    │
│  └─ Collect metrics WITHOUT production impact                              │
│                                                                              │
│  PHASE 4: GUARDIAN VALIDATION (Elixir - Executor)                          │
│  ├─ Guardian receives proposal via Zenoh                                   │
│  ├─ Runs 6 validation checks                                               │
│  ├─ Calculates approval score                                              │
│  └─ Threshold: >= 0.85 for approval                                        │
│                                                                              │
│  PHASE 5: ACTIVATION (Elixir - Executor)                                   │
│  ├─ Log to Immutable Register                                              │
│  ├─ Progressive rollout (5% → 25% → 100%)                                  │
│  ├─ Continuous health monitoring                                           │
│  └─ Rollback trigger on degradation                                        │
│                                                                              │
│  PHASE 6: LEARNING (Both Layers)                                           │
│  ├─ Record episode to TrainingGym                                          │
│  ├─ Update Q-table for layer                                               │
│  ├─ Adjust fitness function weights                                        │
│  └─ Emit telemetry for observer                                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 5.2 Approval Matrices

### 5.2.1 Change Approval Matrix

| Impact Score | Approvers Required | Guardian | Shadow Test | Checkpoint |
|--------------|-------------------|----------|-------------|------------|
| 0-10 | 1 (peer) | No | Optional | Recommended |
| 11-20 | 1 (peer) | No | Recommended | Required |
| 21-30 | 2 (senior) | Notify | Required | Required |
| 31-40 | 3 (arch + senior) | Required | Required | Required |
| 40+ | BLOCKED | Veto | N/A | Emergency |

### 5.2.2 Layer-Based Approval

| Layer | Standard Change | Breaking Change | Emergency |
|-------|-----------------|-----------------|-----------|
| L0 | BLOCKED | BLOCKED | BLOCKED |
| L1 | Peer | Senior | Immediate revert |
| L2 | Peer | Architecture | Immediate revert |
| L3 | Senior | Guardian | Checkpoint restore |
| L4 | Architecture | Guardian | Container rollback |
| L5 | Guardian | Guardian + Exec | Full restore |
| L6 | Guardian + Exec | BLOCKED | Cluster failover |
| L7 | Federation Council | BLOCKED | Federation isolate |

---

# DEGREE 6: REFERENCES

## 6.1 Related Documents

| Document | Location | Purpose |
|----------|----------|---------|
| CLAUDE.md | `/CLAUDE.md` | System specification |
| GEMINI.md | `/GEMINI.md` | AI architect spec |
| Founder's Directive | `docs/architecture/HOLON_FOUNDERS_DIRECTIVE.md` | Ω₀ specification |
| Immortal Architecture | `docs/architecture/HOLON_IMMORTAL_ARCHITECTURE.md` | SIL-6 design |
| Immutable Register | `docs/architecture/HOLON_IMMUTABLE_REGISTER.md` | Blockchain state |
| Formal Specification | `docs/formal_specs/HOLON_FORMAL_SPECIFICATION.md` | Mathematical foundations |
| Constitutional Reconfig | `docs/architecture/HOLON_CONSTITUTIONAL_RECONFIGURATION.md` | Radical adaptability |
| Change Management Rule | `.claude/rules/change-management.md` | SC-CHG-000 |
| Agent Cognitive Protocol | `.claude/rules/agent-cognitive-protocol.md` | OODA rules |
| Functional Invariant | `.claude/rules/functional-invariant.md` | SC-FUNC-000 |
| GA Release Verification | `.claude/rules/ga-release-verification.md` | Release gates |

## 6.2 Standards Compliance

| Standard | Requirement | Coverage |
|----------|-------------|----------|
| IEC 61508 SIL-6 | Safety integrity | SC-SIL6-* |
| ISO 27001 | Information security | SC-SEC-* |
| GDPR | Data protection | SC-GDPR-* |
| EN 50131 | Intrusion systems | SC-EN50131-* |
| DO-178C DAL-A | Airborne software | SC-DO178-* |

## 6.3 Process Mappings

### 6.3.1 SDLC Phase Mapping

| Phase | Agents | Tools | SOPs |
|-------|--------|-------|------|
| DESIGN | fractal-architect, holon-analyzer, impact-analyzer | Quint, Agda, FMEA | SOP-DES-* |
| BUILD | code-evolution, test-generator, code-reviewer | TDG, PropCheck | SOP-BLD-* |
| DEPLOY | deploy-supervisor, script-finder | Podman, UCR | SOP-DEP-* |
| OPERATE | operate-supervisor, prajna-operator | Sentinel, Zenoh | SOP-OPS-* |

### 6.3.2 STAMP → AOR Mapping

| STAMP Constraint | Enforcing AOR Rule |
|------------------|-------------------|
| SC-CHG-001 | AOR-CHG-001 (DOCUMENT before coding) |
| SC-CHG-002 | AOR-CHG-002 (ANALYZE 4-layer impact) |
| SC-CHG-003 | AOR-CHG-003 (PLAN reversal) |
| SC-FUNC-001 | AOR-FUNC-001 (VERIFY compilation) |
| SC-OODA-001 | AOR-OODA-001 (OBSERVE before action) |
| SC-OBS-001 | AOR-OBS-001 (Telemetry subscription only) |

---

# DEGREE 7: OPERATIONS

## 7.1 Runtime Monitoring

### 7.1.1 OODA Cycle Metrics

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                           OODA CYCLE DASHBOARD                                 ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  FAST OODA (L1-L2)                              [Target: 50ms]                ║
║  ├─ Current: 45ms                                                             ║
║  ├─ Observe: 4ms ████░░░░░░░░░░░░░░░░ (5ms budget)                           ║
║  ├─ Orient:  12ms █████████░░░░░░░░░░ (15ms budget)                          ║
║  ├─ Decide:  14ms ██████████░░░░░░░░░ (15ms budget)                          ║
║  └─ Act:     15ms ███████████░░░░░░░░ (15ms budget)                          ║
║                                                                                ║
║  DISTRIBUTED OODA (L3-L4)                       [Target: 100ms]               ║
║  ├─ Current: 87ms                                                             ║
║  ├─ Observe: 18ms ████████░░░░░░░░░░░ (20ms budget)                          ║
║  ├─ Orient:  28ms ██████████░░░░░░░░░ (30ms budget)                          ║
║  ├─ Decide:  22ms █████████░░░░░░░░░░ (25ms budget)                          ║
║  └─ Act:     19ms ████████░░░░░░░░░░░ (25ms budget)                          ║
║                                                                                ║
║  STRATEGY OODA (L5-L7)                          [Target: 1000ms]              ║
║  ├─ Current: 850ms                                                            ║
║  ├─ Observe: 180ms █████████░░░░░░░░░ (200ms budget)                         ║
║  ├─ Orient:  280ms ██████████░░░░░░░░ (300ms budget)                         ║
║  ├─ Decide:  220ms █████████░░░░░░░░░ (250ms budget)                         ║
║  └─ Act:     170ms ███████░░░░░░░░░░░ (250ms budget)                         ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### 7.1.2 Agent Swarm Status

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                           AGENT SWARM STATUS                                   ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  EXECUTIVE (1/1)                                                              ║
║  └─ EXEC-001: ACTIVE ● Strategy OODA running                                 ║
║                                                                                ║
║  SUPERVISORS (10/10)                                                          ║
║  ├─ SUP-ACCESS:  ACTIVE ●   ├─ SUP-BILLING:  ACTIVE ●                        ║
║  ├─ SUP-ALARMS:  ACTIVE ●   ├─ SUP-CONFIG:   ACTIVE ●                        ║
║  ├─ SUP-DEVICES: ACTIVE ●   ├─ SUP-INTEGR:   ACTIVE ●                        ║
║  ├─ SUP-SAFETY:  ACTIVE ●   ├─ SUP-ANALYT:   ACTIVE ●                        ║
║  └─ SUP-COMPLI:  ACTIVE ●   └─ SUP-INTELLI:  ACTIVE ●                        ║
║                                                                                ║
║  FUNCTIONAL (15/15)                                                           ║
║  ├─ Guardian:     ACTIVE ●  0 pending proposals                              ║
║  ├─ Sentinel:     ACTIVE ●  Threat level: LOW                                ║
║  ├─ PatternHunter:ACTIVE ●  Patterns detected: 3                             ║
║  ├─ TrainingGym:  ACTIVE ●  Episodes: 1,247                                  ║
║  └─ ...                                                                       ║
║                                                                                ║
║  WORKERS (20/24)                                                              ║
║  ├─ WRK-COMPILE:  3/3 ACTIVE                                                 ║
║  ├─ WRK-TEST:     4/5 ACTIVE (1 idle)                                        ║
║  ├─ WRK-CREDO:    2/2 ACTIVE                                                 ║
║  ├─ WRK-FIX:      5/5 ACTIVE                                                 ║
║  ├─ WRK-DOC:      2/2 ACTIVE                                                 ║
║  ├─ WRK-EXPLORE:  2/3 ACTIVE (1 idle)                                        ║
║  └─ WRK-SWARM:    2/4 ACTIVE (2 idle)                                        ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### 7.1.3 Telemetry Endpoints

| Metric | Zenoh Topic | Prometheus Metric |
|--------|-------------|-------------------|
| OODA Fast Cycle | `indrajaal/ooda/fast/cycle` | `ooda_fast_cycle_ms` |
| OODA Strategy Cycle | `indrajaal/ooda/strategy/cycle` | `ooda_strategy_cycle_ms` |
| Agent Count | `indrajaal/agents/count` | `agent_swarm_total` |
| Guardian Proposals | `indrajaal/guardian/proposals` | `guardian_proposals_total` |
| Impact Score | `indrajaal/changes/impact` | `change_impact_score` |
| Error Budget | `indrajaal/sre/error_budget` | `error_budget_remaining` |

## 7.2 Alerting Rules

### 7.2.1 OODA Timing Alerts

| Alert | Condition | Severity | Action |
|-------|-----------|----------|--------|
| OODA_FAST_SLOW | cycle > 100ms | WARNING | Scale workers |
| OODA_FAST_CRITICAL | cycle > 200ms | CRITICAL | Emergency mode |
| OODA_STRATEGY_SLOW | cycle > 2s | WARNING | Check F# health |
| OODA_STRATEGY_CRITICAL | cycle > 5s | CRITICAL | Fallback to local |

### 7.2.2 Change Management Alerts

| Alert | Condition | Severity | Action |
|-------|-----------|----------|--------|
| IMPACT_HIGH_RISK | score > 20 | INFO | Notify senior |
| IMPACT_CRITICAL | score > 30 | WARNING | Block auto-merge |
| IMPACT_EMERGENCY | score > 40 | CRITICAL | Halt all changes |
| CONSTITUTIONAL_VIOLATION | Ψ check failed | CRITICAL | Immediate rollback |

---

# DEGREE 8: EVOLUTION

## 8.1 Continuous Improvement

### 8.1.1 TrainingGym Learning Loop

```elixir
# Episode Recording for Q-Learning
%Episode{
  proposal_id: "EVO-2026-001",
  layer: :L3,
  action: :refactor,
  pre_state: %{coverage: 92.5, complexity: 15.2},
  post_state: %{coverage: 94.1, complexity: 12.8},
  reward: calculate_reward(pre, post),  # +1.0 (improvement)
  timestamp: ~U[2026-01-10 14:30:00Z]
}

# Q-Table Update
Q(L3, refactor) = Q(L3, refactor) + α * (reward + γ * max(Q(s')) - Q(L3, refactor))
```

### 8.1.2 Fitness Function Evolution

```
Fitness = w₁(Coverage) + w₂(PassRate) + w₃(MutationScore) - w₄(Complexity)

Initial Weights:
  w₁ = 0.3 (coverage)
  w₂ = 0.3 (pass rate)
  w₃ = 0.2 (mutation score)
  w₄ = 0.2 (complexity penalty)

Adaptive Update:
  If coverage improves consistently → increase w₁
  If regressions occur → increase w₂
  If mutations survive → increase w₃
```

### 8.1.3 STAMP Constraint Evolution

New constraints added based on postmortems:

| Incident | New Constraint | Added Date |
|----------|----------------|------------|
| Observer wrote to observed | SC-OBS-001 | 2026-01-10 |
| OODA cycle timeout | SC-OODA-005 (hysteresis) | 2026-01-08 |
| Agent count exceeded API limit | SC-API-001 | 2026-01-05 |

## 8.2 Architecture Evolution Patterns

### 8.2.1 Permitted Evolutions by Layer

| Layer | Permitted | Requires Guardian | Forbidden |
|-------|-----------|-------------------|-----------|
| L0 | NONE | N/A | ALL |
| L1 | Function signature, logic | Breaking changes | State addition |
| L2 | GenServer behavior, API | Breaking API | External deps |
| L3 | Agent logic, coordination | State schema | Constitutional |
| L4 | Container config, scaling | Image changes | Network topology |
| L5 | Scheduler config, flags | OTP version | BEAM version |
| L6 | Node addition/removal | Quorum rules | Consensus protocol |
| L7 | Protocol version | Federation rules | Trust model |

### 8.2.2 Radical Reconfiguration Protocol

Per SC-RECONFIG-*, radical changes permitted when:

1. Survival pressure documented
2. Constitutional invariants preserved
3. Shadow testing completed
4. Guardian approval obtained
5. Rollback path verified

---

# APPENDIX A: QUICK REFERENCE

## A.1 Impact Score Quick Calculator

```
L1 (Function):    Severity × 1
L2 (Module):      Severity × 2
L3 (Agent):       Severity × 3
L4 (Container):   Severity × 3 (capped)
L5+ (Node/Cluster): Severity × 4

Severity: NONE=0, LOW=2, MEDIUM=5, HIGH=8, CRITICAL=12

Mode: 0-20=NORMAL, 21-30=HIGH-RISK, 31-40=CRITICAL, 40+=EMERGENCY
```

## A.2 Essential Commands

```bash
# Daily workflow
devenv shell && compile && test && quality

# Before risky change
sa-checkpoint --phase full

# After failed change
sa-checkpoint-restore --phase full

# Emergency
sa-emergency
```

## A.3 Key STAMP IDs

| Constraint | Meaning |
|------------|---------|
| SC-FUNC-001 | System MUST compile |
| SC-CHG-001 | Changes need notes |
| SC-OODA-001 | Cycle < 100ms |
| SC-OBS-001 | Observer separation |
| SC-GDE-004 | Guardian threshold 0.85 |

---

**Document End**

| Field | Value |
|-------|-------|
| Total Pages | ~80 |
| STAMP Coverage | 150+ constraints |
| AOR Coverage | 100+ rules |
| Last Updated | 2026-01-10 |
| Next Review | 2026-04-10 |

