# Standalone Runtime Testing Framework - 5-Level Implementation Journal
**Date**: 2025-12-29T20:00:00+01:00
**Status**: COMPLETE
**Framework**: SOPv5.11 + STAMP + OODA + Biomorphic Swarm + F#
**Mission**: 100% Runtime Coverage for Standalone CEPAF/Cockpit Environment

---

## L1: Executive Summary (System Level)

### Mission Objective
Implement a comprehensive runtime testing framework for the standalone CEPAF/Cockpit environment achieving:
- 100% Dataflow Coverage (all data paths validated)
- 100% Control Flow Coverage (all decision branches exercised)
- 100% Cockpit Operational Scenarios (all user journeys validated)
- Full UX/UI/CX/DX Evaluation (Nielsen's 10 heuristics + WCAG 2.1)
- Evolvability Assessment (architectural fitness functions)

### Results Summary

| Metric | Target | Achieved | Status |
|--------|--------|----------|--------|
| Test Scenarios Defined | 50+ | 57 | COMPLETE |
| F# Scripts Created | 2 | 2 | COMPLETE |
| Documentation Created | 1 | 1 | COMPLETE |
| UX Heuristics Covered | 10 | 10 | 100% |
| UI Criteria Covered | 4 | 4 | 100% |
| CX Metrics Covered | 4 | 4 | 100% |
| DX Metrics Covered | 4 | 4 | 100% |

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    STANDALONE RUNTIME TEST FRAMEWORK                 │
│                    F# Biomorphic Swarm Architecture                  │
└─────────────────────────────────────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        ▼                           ▼                           ▼
┌───────────────────┐     ┌───────────────────┐     ┌───────────────────┐
│ RuntimeTest       │     │ CockpitUX         │     │ Standalone        │
│ Orchestrator.fsx  │     │ Evaluator.fsx     │     │ TestEnv Scripts   │
│ (Swarm Mode)      │     │ (Heuristics)      │     │ (Setup/Teardown)  │
└───────────────────┘     └───────────────────┘     └───────────────────┘
        │                         │                         │
   ┌────┴────┐               ┌────┴────┐               ┌────┴────┐
   ▼         ▼               ▼         ▼               ▼         ▼
┌─────┐  ┌─────┐         ┌─────┐  ┌─────┐         ┌─────┐  ┌─────┐
│Data │  │Ctrl │         │ UX  │  │ UI  │         │CEPAF│  │Cock │
│Flow │  │Flow │         │Eval │  │Eval │         │Test │  │ pit │
└─────┘  └─────┘         └─────┘  └─────┘         └─────┘  └─────┘
```

---

## L2: Container/Domain Level

### 2.1 Artifacts Created

| Artifact Type | Path | Purpose | Size |
|---------------|------|---------|------|
| F# Script | `lib/cepaf/scripts/RuntimeTestOrchestrator.fsx` | Biomorphic swarm test execution | ~650 lines |
| F# Script | `lib/cepaf/scripts/CockpitUXEvaluator.fsx` | UX/UI/CX/DX evaluation | ~550 lines |
| Markdown Doc | `docs/testing/STANDALONE_RUNTIME_TESTING_PLAN.md` | 5-level test plan | ~1200 lines |
| Config | `config/standalone.exs` | Phoenix standalone config | ~90 lines |
| Template | `.env.standalone.template` | Environment variables | ~60 lines |
| Shell Script | `scripts/testing/cockpit_manual_test.sh` | Manual testing | ~150 lines |
| Shell Script | `scripts/testing/cepaf_remote_test.sh` | Remote F# testing | ~135 lines |
| Elixir Script | `scripts/testing/standalone_test_env.exs` | Environment setup | ~300 lines |
| Compose File | `lib/cepaf/artifacts/podman-compose-standalone-full.yml` | Full stack compose | ~120 lines |

### 2.2 Test Domain Coverage

| Domain | Scenarios | Categories | Priority |
|--------|-----------|------------|----------|
| Dataflow | 10 | DB, API, Event | P0 |
| Control Flow | 7 | OODA, Circuit Breaker, Auth | P0 |
| Cockpit | 40 | Operator, Admin, UX, UI, CX, DX, Ergonomics | P0 |
| Evolvability | 10 | Fitness, Extension, Maintainability | P1 |

---

## L3: Component Level

### 3.1 F# RuntimeTestOrchestrator.fsx

**Purpose**: Execute comprehensive runtime tests with biomorphic swarm intelligence

**Key Features**:
- Fast OODA Loop implementation (SC-OODA-001 to SC-OODA-006)
- Hysteresis mode to prevent decision oscillation (10% margin, 3-cycle hold)
- Concurrent swarm workers (up to 10 parallel)
- Real-time dashboard with progress visualization
- Automatic scaling based on resource availability

**Usage**:
```bash
# Full swarm mode (recommended)
dotnet fsi lib/cepaf/scripts/RuntimeTestOrchestrator.fsx --mode swarm

# Sequential mode
dotnet fsi lib/cepaf/scripts/RuntimeTestOrchestrator.fsx --mode sequential

# Single domain
dotnet fsi lib/cepaf/scripts/RuntimeTestOrchestrator.fsx --domain cockpit

# Single test
dotnet fsi lib/cepaf/scripts/RuntimeTestOrchestrator.fsx --mode single --domain dataflow --scenario DF-DB-001
```

**OODA Configuration**:
```fsharp
[<Literal>]
let OODACycleTargetMs = 100        // SC-OODA-001

[<Literal>]
let HysteresisMargin = 0.1         // SC-OODA-005: 10% margin

[<Literal>]
let HysteresisHoldCycles = 3       // SC-OODA-005: 3 cycle hold

[<Literal>]
let MaxConcurrentWorkers = 10      // Swarm parallelism
```

### 3.2 F# CockpitUXEvaluator.fsx

**Purpose**: Comprehensive UX/UI/CX/DX evaluation of Prajna Cockpit

**Key Features**:
- Nielsen's 10 Usability Heuristics evaluation
- UI Consistency audit (color, typography, components, spacing)
- Customer Experience metrics (task completion, time on task, error rate, SUS)
- Developer Experience metrics (TTFMA, documentation, API discoverability)
- Ergonomics assessment (keyboard, density, latency, dark mode)
- Information Architecture evaluation
- Aesthetics evaluation

**Usage**:
```bash
# Full evaluation
dotnet fsi lib/cepaf/scripts/CockpitUXEvaluator.fsx

# Specific category (future)
dotnet fsi lib/cepaf/scripts/CockpitUXEvaluator.fsx --category ux-heuristics
```

**Evaluation Categories**:
```fsharp
type EvaluationCategory =
    | UXHeuristics           // Nielsen's 10
    | UIConsistency          // Color, Typography, Components, Spacing
    | CustomerExperience     // Task Completion, Time, Errors, SUS
    | DeveloperExperience    // TTFMA, Docs, API, Errors
    | Ergonomics             // Keyboard, Density, Latency, Dark Mode
    | InformationArchitecture // Navigation, Content, Dashboard
    | Aesthetics             // Hierarchy, Brand, Modern Design
```

### 3.3 Standalone Environment Setup

**Quick Start Commands**:
```bash
# Option 1: Full automated setup (recommended)
elixir scripts/testing/standalone_test_env.exs --full

# Option 2: Start containers only
podman-compose -f lib/cepaf/artifacts/podman-compose-standalone-full.yml up -d

# Option 3: Manual Phoenix start
source .env.standalone.template
MIX_ENV=dev mix phx.server

# Option 4: CEPAF F# testing
./scripts/testing/cepaf_remote_test.sh --full

# Option 5: Cockpit manual testing
./scripts/testing/cockpit_manual_test.sh --start
```

**Access Points**:
| Service | URL | Notes |
|---------|-----|-------|
| Phoenix App | http://localhost:4001 | Main application |
| Prajna Cockpit | http://localhost:4001/prajna | C3I Dashboard |
| AI Copilot | http://localhost:4001/prajna/copilot | AI Assistant |
| LiveDashboard | http://localhost:4001/dev/dashboard | Dev tools |
| Grafana | http://localhost:3000 | Metrics (admin/indrajaal) |
| Prometheus | http://localhost:9090 | Raw metrics |

---

## L4: Module Level

### 4.1 Test Scenario Identifiers

#### Dataflow Tests (DF-*)
| ID | Name | Coverage |
|----|------|----------|
| DF-DB-001 | CRUD Lifecycle | All Ash resources |
| DF-DB-002 | Transaction Atomicity | Repo.transaction |
| DF-DB-003 | Query Optimization | Complex queries |
| DF-DB-004 | Migration Integrity | All migrations |
| DF-API-001 | REST Endpoints | All routes |
| DF-API-002 | WebSocket Channels | All channels |
| DF-API-003 | GraphQL Operations | Schema coverage |
| DF-EVT-001 | Telemetry Events | All events |
| DF-EVT-002 | PubSub Messages | All topics |
| DF-EVT-003 | OODA Observations | All sensors |

#### Control Flow Tests (CF-*)
| ID | Name | Coverage |
|----|------|----------|
| CF-OODA-001 | Normal OODA Cycle | All transitions |
| CF-OODA-002 | Hysteresis Mode | Dead-band logic |
| CF-OODA-003 | AI Orientation Fallback | Timeout handling |
| CF-CB-001 | Circuit Breaker States | All transitions |
| CF-CB-002 | Membrane Protection | Rate limiting |
| CF-AUTH-001 | JWT Token Lifecycle | All states |
| CF-AUTH-002 | MFA Flow | All methods |

#### Cockpit Tests (CK-*)
| ID | Name | Category |
|----|------|----------|
| CK-OP-001 | Morning Shift Startup | Operator Journey |
| CK-OP-002 | Alert Response | Operator Journey |
| CK-OP-003 | AI Copilot Query | Operator Journey |
| CK-AD-001 | User Management | Admin Journey |
| CK-AD-002 | System Configuration | Admin Journey |
| CK-AD-003 | Report Generation | Admin Journey |
| CK-UX-H01..H10 | Nielsen Heuristics | UX Evaluation |
| CK-UI-001..004 | UI Consistency | UI Evaluation |
| CK-CX-001..004 | Customer Experience | CX Metrics |
| CK-DX-001..004 | Developer Experience | DX Metrics |
| CK-ERG-001..004 | Ergonomics | Ergonomic Assessment |
| CK-IA-001..003 | Info Architecture | IA Evaluation |
| CK-AES-001..003 | Aesthetics | Aesthetic Evaluation |

#### Evolvability Tests (AF-*, EXT-*, MNT-*, ADP-*)
| ID | Name | Target |
|----|------|--------|
| AF-001 | Modularity Index | > 0.8 |
| AF-002 | Coupling Score | < 10 per module |
| AF-003 | Cohesion Score | > 0.7 |
| AF-004 | Test Coverage | > 95% |
| EXT-001 | Plugin Architecture | Behaviours |
| EXT-002 | Feature Flags | Runtime toggle |
| EXT-003 | API Versioning | Backward compat |
| MNT-001 | Code Complexity | < 10 cyclomatic |
| MNT-002 | Technical Debt | Decreasing |
| MNT-003 | Documentation Currency | 100% current |
| ADP-001 | Configuration External | All config |
| ADP-002 | Database Agnosticism | Ecto abstractions |
| ADP-003 | UI Theming | CSS variables |

### 4.2 STAMP Safety Constraints

| Constraint | Description | Implementation |
|------------|-------------|----------------|
| SC-OODA-001 | Cycle time < 100ms | OODACycleTargetMs = 100 |
| SC-OODA-005 | Hysteresis prevents oscillation | HysteresisMargin = 0.1, HysteresisHoldCycles = 3 |
| SC-OODA-006 | AI orientation with timeout | AI fallback to local heuristics |
| SC-BIO-001 | Holon autonomy | Self-contained test workers |
| SC-BIO-002 | Membrane protection | Rate limiting in swarm |
| SC-PRF-050 | Response < 50ms | Performance assertions |
| SC-SWARM-001 | Convergence threshold | 95% completion target |

---

## L5: Code Level

### 5.1 Key F# Type Definitions

```fsharp
// Test domain enumeration
type TestDomain =
    | Dataflow
    | ControlFlow
    | Cockpit
    | Evolvability

// OODA decision types
type OODADecision =
    | SpawnWorkers of int
    | ScaleDown
    | Wait
    | RetryFailed
    | Complete

// OODA state tracking
type OODAState = {
    Phase: OODAPhase
    CycleCount: int
    HysteresisCounter: int
    LastDecision: OODADecision option
    AvgCycleTimeMs: float
}

// Evaluation result structure
type EvaluationResult = {
    Category: EvaluationCategory
    Criterion: string
    Score: float
    MaxScore: float
    Rating: Score
    Notes: string list
    Recommendations: string list
}
```

### 5.2 Key Functions

```fsharp
// OODA cycle execution
let cycle (swarmState: SwarmState) (state: OODAState) : OODADecision * OODAState =
    let observations = observe swarmState
    let orientation = orient observations
    let (decision, newState) = decide orientation state
    (decision, newState)

// Hysteresis decision logic
let decide (orient: Orientation) (state: OODAState) : OODADecision * OODAState =
    let newDecision = determineAction orient
    let withinMargin = matchesLastDecision newDecision state.LastDecision

    if withinMargin && state.HysteresisCounter < HysteresisHoldCycles then
        (state.LastDecision |> Option.defaultValue newDecision,
         state.HysteresisCounter + 1)
    else
        (newDecision, 0)
```

---

## Usability Instructions

### Getting Started

1. **Prerequisites**:
   - .NET SDK 8.0+ (for F# scripts)
   - Elixir 1.19+ / OTP 27+
   - Podman 5.4.1+ (rootless)
   - PostgreSQL container running on port 5433

2. **Environment Setup**:
   ```bash
   # Copy environment template
   cp .env.standalone.template .env.standalone

   # Start standalone environment
   elixir scripts/testing/standalone_test_env.exs --full
   ```

3. **Run Full Test Suite**:
   ```bash
   # F# Runtime Tests (swarm mode)
   dotnet fsi lib/cepaf/scripts/RuntimeTestOrchestrator.fsx --mode swarm

   # F# UX Evaluation
   dotnet fsi lib/cepaf/scripts/CockpitUXEvaluator.fsx
   ```

4. **Manual Cockpit Testing**:
   ```bash
   # Start cockpit
   ./scripts/testing/cockpit_manual_test.sh --start

   # Open browser to http://localhost:4001/prajna

   # Stop when done
   ./scripts/testing/cockpit_manual_test.sh --stop
   ```

### Test Execution Modes

| Mode | Command | Use Case |
|------|---------|----------|
| Swarm | `--mode swarm` | Full parallel execution (default) |
| Sequential | `--mode sequential` | Debugging, ordered execution |
| Single | `--mode single --domain X --scenario Y` | Individual test |

### Report Interpretation

- **EXCELLENT (90-100%)**: Production ready
- **GOOD (70-89%)**: Minor improvements needed
- **FAIR (50-69%)**: Significant work required
- **NEEDS WORK (30-49%)**: Major issues
- **CRITICAL (0-29%)**: Blocking issues

---

## Files Modified/Created Summary

### New Files (9)
1. `lib/cepaf/scripts/RuntimeTestOrchestrator.fsx`
2. `lib/cepaf/scripts/CockpitUXEvaluator.fsx`
3. `docs/testing/STANDALONE_RUNTIME_TESTING_PLAN.md`
4. `lib/cepaf/artifacts/podman-compose-standalone-full.yml`
5. `.env.standalone.template`
6. `config/standalone.exs`
7. `scripts/testing/standalone_test_env.exs`
8. `scripts/testing/cockpit_manual_test.sh`
9. `scripts/testing/cepaf_remote_test.sh`

### Updated Files (pending)
- `CLAUDE.md` - Add F# test framework documentation
- `GEMINI.md` - Add F# test framework documentation

---

## References

- `journal/2025-12/20251229-1700-autonomous-agent-credo-biomorphic-mission.md`
- `docs/architecture/PRAJNA_5_LEVEL_SPECIFICATION.md`
- `docs/architecture/PRAJNA_C3I_COCKPIT.md`
- Nielsen's 10 Usability Heuristics
- WCAG 2.1 Guidelines
- Material Design 3 Guidelines
