# 5-Level Journal Entry: Neuro-Symbolic Cortex Master Implementation

**Document Control**

| Field | Value |
|-------|-------|
| Entry ID | JOURNAL-20251226-1545 |
| Version | 1.0.0 |
| Status | ACTIVE |
| Created | 2025-12-26T15:45:00+01:00 |
| Author | Cybernetic Architect (Claude) |
| Classification | Safety-Critical Architecture Planning |
| STAMP | SC-CTX-001 to SC-CTX-010, SC-SEC-001, SC-OBS-001 |
| Framework | SOPv5.11 + TPS + STAMP + Neuro-Symbolic Simplex |

---

## Level 1: Executive Summary

### 1.1 Session Objective
Complete architectural planning for the **Neuro-Symbolic Cortex Integration** - a Bicameral Cybernetic Organism using the Simplex Architecture that resolves the fundamental conflict between Rapid Evolution and Life-Critical Safety.

### 1.2 Key Achievements
| Achievement | Status | Artifact |
|-------------|--------|----------|
| Read & Analyzed Master Plan | COMPLETE | docs/plans/20251226-cortex-integration-master-plan.md |
| Created 5-Level Implementation Plan | COMPLETE | docs/plans/20251226-cortex-5level-implementation-plan.md |
| Updated Todolist (130+ atomic tasks) | COMPLETE | mix todo.status |
| Created Journal Entry | COMPLETE | This document |

### 1.3 Architecture Overview
```
┌─────────────────────────────────────────────────────────────────────────┐
│                    BICAMERAL CYBERNETIC ORGANISM                        │
│                    (Neuro-Symbolic Simplex Architecture)                │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
┌───────────────┐         ┌─────────────────┐         ┌───────────────┐
│  SAFETY PLANE │         │ NERVOUS SYSTEM  │         │ COMPLEX PLANE │
│  (Guardian)   │         │    (Zenoh)      │         │   (Cortex)    │
│               │         │                 │         │               │
│ Trust: 100%   │◄───────►│ Neural Streams  │◄───────►│ Trust: 0%     │
│ Immutable     │         │ Time Travel     │         │ AI-Driven     │
│ Veto Power    │         │ Polyglot Bridge │         │ Mutating      │
└───────────────┘         └─────────────────┘         └───────────────┘
        │                           │                           │
        │                           ▼                           │
        │                 ┌─────────────────┐                   │
        │                 │ COGNITIVE       │                   │
        └────────────────►│ COCKPIT         │◄──────────────────┘
                          │ (Livebook HITL) │
                          └─────────────────┘
                                    │
                                    ▼
                          ┌─────────────────┐
                          │ EVOLUTION       │
                          │ STRATEGY        │
                          │ (Anti-Fragility)│
                          └─────────────────┘
```

### 1.4 The Simplex Paradox Resolution
**Problem**: Safety requires stasis, Evolution requires change (and risk).

**Solution**: Strict decoupling of *intent* (AI) from *actuation* (Guardian):
- The AI can "think" dangerous thoughts
- The Guardian ensures it can never "do" dangerous things
- N=100 cycle shadow validation before any model promotion

---

## Level 2: Subsystem Analysis

### 2.1 Safety Plane (Guardian) - IMPLEMENTED

**Location**: `lib/indrajaal/safety/guardian.ex`
**Status**: COMPLETE (GenServer)
**Trust Level**: Absolute (100%)

| Component | Implementation | STAMP |
|-----------|----------------|-------|
| validate_proposal/1 | Atomic gatekeeper | SC-SEC-001 |
| check_resource_bounds/1 | Max 50 FLAME, 32GB | SC-RES-001 |
| check_security_constraints/1 | No unverified exec | SC-SEC-001 |
| check_actuator_physics/1 | Pressure < 0.1 bar | SC-ACT-001 |
| generate_safe_fallback/1 | Deterministic fallback | SC-ACT-002 |

**Guardian Constraints**:
```elixir
@max_flame_nodes 50
@max_memory_mb 32_000
@forbidden_ops [:rm_rf, :system_cmd_root, :eval_string, :chmod_777]
@max_safe_pressure_delta 0.1
```

### 2.2 Nervous System (Zenoh) - PARTIAL

**Current State**:
| Module | Status | Purpose |
|--------|--------|---------|
| zenoh_coordinator.ex | EXISTS | Coordination hub |
| zenoh_kpi_publisher.ex | EXISTS | KPI publishing |
| zenoh_control_subscriber.ex | EXISTS | Control commands |
| zenoh_neural_stream.ex | NEW | Real-time streaming |
| zenoh_time_travel.ex | NEW | Backtracking buffer |
| zenoh_polyglot_bridge.ex | NEW | Python/Mojo interface |

**Neural Stream Key Expressions**:
```
indrajaal/neural/logs/<level>/<module>     - Log streaming
indrajaal/neural/metrics/<domain>/<metric> - Metric aggregation
indrajaal/neural/state/<agent>/<key>       - State publication
indrajaal/timemachine/<timestamp>/<session> - Checkpoint storage
```

### 2.3 Cortex (Bicameral Intelligence) - PARTIAL

**Current Modules**:
```
lib/indrajaal/cortex/
├── controller.ex       ✓ OODA Loop (30s cycle)
├── synapse.ex          ⚠ Stubbed (needs Zenoh)
├── homeostasis/        ✓ Controller exists
├── sensors/            ✓ 5 sensors exist
│   ├── system_sensor.ex
│   ├── flame_sensor.ex
│   ├── ml_sensor.ex
│   ├── container_health_sensor.ex
│   └── beam_sensor.ex
├── reflexes/           ✓ Circuit breaker exists
└── analysis/           ✓ Stress analyzer exists
```

**OODA Cycle Implementation**:
```elixir
# From lib/indrajaal/cortex/controller.ex
@ooda_interval :timer.seconds(30)
@max_ooda_latency 1000  # ms
@stress_critical 0.9
@stress_high 0.7
@stress_low 0.3

def run_ooda_cycle(state) do
  # OBSERVE: Collect sensor data
  observation = observe()
  # ORIENT: Analyze, calculate stress
  orientation = orient(observation)
  # DECIDE: Generate proposals
  {decisions, proposals} = decide(orientation, state)
  # ACT: Execute approved actions
  {executed, remaining} = act(proposals, state.auto_execute)
end
```

### 2.4 Goal-Directed Evaluation (GDE) - NEW

**Unicon-Inspired Design**:
| Concept | Elixir Implementation |
|---------|----------------------|
| Generators | Stream-based lazy value generation |
| Goal-Directed Eval | Automatic backtracking on failure |
| String Scanning | Macro-based log parsing DSL |

**GDE Module Structure**:
```
lib/indrajaal/cortex/gde/
├── generator.ex        - alternatives/2, compose/1, take_until/2
├── goal_evaluator.ex   - evaluate/2, mark_failed/2, mark_success/2
├── backtracker.ex      - with_backtrack/2, on_failure/2
├── string_scanner.ex   - Macro DSL: scan "Error:" ~> module ~> line
└── proposal_engine.ex  - generate_hypotheses/1, rank/1
```

**Backtracking Protocol**:
```elixir
# If plan fails at Step 5, auto-backtrack to Step 4, then 3...
with_backtrack(goal: :compilation_success) do
  for candidate <- Generator.file_candidates("accounts") do
    case attempt_fix(candidate) do
      :ok -> :success
      :error -> :retry  # Try next candidate
    end
  end
end
```

### 2.5 Cognitive Cockpit (Livebook) - STUBBED

**Purpose**: Human-in-the-Loop (HITL) Interface

| Component | Purpose | Status |
|-----------|---------|--------|
| VisualOODA | Real-time OODA cycle graphing | NEW |
| RLHFInterface | Upvote/Downvote AI proposals | NEW |
| SafetyMonitor | Read-only Guardian state | NEW |
| TwoKeyTurn | Multi-sig for critical actuators | NEW |

**Security Model**:
- Livebook connects as hidden node (`livebook@...`)
- SafetyMonitor is READ-ONLY
- Critical actuators require Two-Key Turn (multi-sig)

### 2.6 Evolution Strategy (Anti-Fragility) - NEW

**Core Principle**: The system grows stronger from failure.

| Mechanism | Description | Implementation |
|-----------|-------------|----------------|
| Shadow Mode | Parallel execution without actuation | ShadowMode GenServer |
| Training Gym | Negative examples from vetoes | TrainingGym collector |
| Promotion | N=100 clean cycles before promotion | PromotionEngine |
| Veto Analysis | Learn from Guardian vetoes | VetoAnalyzer |

**Shadow Mode Protocol**:
```
1. Receive proposal from Synapse
2. Execute in shadow (NO actuator writes)
3. Compare output to legacy model
4. Record disagreements and violations
5. After N=100 cycles with 0 violations → PROMOTE
6. Any violation → REJECT
```

---

## Level 3: Implementation Phases

### Phase 1: Zenoh Neural Stream Integration
**Priority**: P1 (Critical Path)
**Duration**: 2-3 development sessions
**Dependencies**: zenohex library

| Task ID | Description | Files | LoC |
|---------|-------------|-------|-----|
| CTX-1.1 | ZenohNeuralStream GenServer | zenoh_neural_stream.ex | ~200 |
| CTX-1.2 | ZenohTimeTravel (backtracking) | zenoh_time_travel.ex | ~250 |
| CTX-1.3 | ZenohPolygotBridge (Python/Mojo) | zenoh_polyglot_bridge.ex | ~180 |
| CTX-1.4 | TDG tests | *_test.exs | ~300 |

**Key Constraints**:
- SC-OBS-001: Latency < 50ms
- SC-OBS-002: No data loss
- SC-OBS-003: Ordered delivery per key

### Phase 2: Synapse Full Integration
**Priority**: P1 (Critical Path)
**Duration**: 2-3 development sessions
**Dependencies**: Phase 1

| Task ID | Description | Files | LoC |
|---------|-------------|-------|-----|
| CTX-2.1 | GeminiInterface | gemini_interface.ex | ~200 |
| CTX-2.2 | ClaudeInterface | claude_interface.ex | ~200 |
| CTX-2.3 | Synapse Zenoh update | synapse.ex | ~150 |
| CTX-2.4 | Guardian integration | synapse.ex | ~50 |

**Bicameral Loop**:
```
Gemini (Context) → Claude (Reasoning) → Guardian (Validation) → Zenoh (Publish)
```

### Phase 3: Goal-Directed Evaluation (GDE)
**Priority**: P2 (High Value)
**Duration**: 3-4 development sessions
**Dependencies**: Phase 2

| Task ID | Description | Files | LoC |
|---------|-------------|-------|-----|
| CTX-3.1 | Generator module | generator.ex | ~250 |
| CTX-3.2 | GoalEvaluator | goal_evaluator.ex | ~200 |
| CTX-3.3 | Backtracker | backtracker.ex | ~300 |
| CTX-3.4 | StringScanner DSL | string_scanner.ex | ~250 |
| CTX-3.5 | ProposalEngine | proposal_engine.ex | ~200 |
| CTX-3.6 | Controller integration | controller.ex | ~100 |

### Phase 4: Cognitive Cockpit (Livebook)
**Priority**: P2 (High Value)
**Duration**: 2 development sessions
**Dependencies**: Phase 2

| Task ID | Description | Files | LoC |
|---------|-------------|-------|-----|
| CTX-4.1 | VisualOODA LiveView | visual_ooda.ex | ~300 |
| CTX-4.2 | RLHFInterface | rlhf_interface.ex | ~200 |
| CTX-4.3 | SafetyMonitor | safety_monitor.ex | ~150 |
| CTX-4.4 | TwoKeyTurn | two_key_turn.ex | ~200 |

### Phase 5: Evolution Strategy (Anti-Fragility)
**Priority**: P3 (Future Value)
**Duration**: 3-4 development sessions
**Dependencies**: Phase 3

| Task ID | Description | Files | LoC |
|---------|-------------|-------|-----|
| CTX-5.1 | ShadowMode | shadow_mode.ex | ~300 |
| CTX-5.2 | TrainingGym | training_gym.ex | ~250 |
| CTX-5.3 | PromotionEngine | promotion_engine.ex | ~200 |
| CTX-5.4 | VetoAnalyzer | veto_analyzer.ex | ~200 |

---

## Level 4: Technical Specifications

### 4.1 ZenohNeuralStream API
```elixir
defmodule Intelitor.Observability.ZenohNeuralStream do
  @moduledoc """
  WHAT: Real-time streaming of logs, metrics, state via Zenoh
  WHY: SC-OBS-001 requires <50ms telemetry latency
  CONSTRAINTS: Zero-copy, no disk writes for real-time data
  """

  @type stream_config :: %{
    key_prefix: String.t(),
    buffer_size: pos_integer(),       # Default: 100
    flush_interval_ms: pos_integer()  # Default: 100
  }

  @callback stream_log(level, module, message) :: :ok
  @callback stream_metric(domain, name, value) :: :ok
  @callback stream_state(agent, key, value) :: :ok
end
```

### 4.2 GDE Generator API
```elixir
defmodule Intelitor.Cortex.GDE.Generator do
  @moduledoc """
  WHAT: Lazy stream-based value generation for backtracking
  WHY: Enables Goal-Directed Evaluation with auto-retry
  CONSTRAINTS: Composable, lazy, deterministic
  """

  @type generator :: Enumerable.t()

  @callback alternatives(base, opts) :: generator()
  @callback compose(generators) :: generator()
  @callback take_until(generator, predicate) :: term()
end
```

### 4.3 ShadowMode API
```elixir
defmodule Intelitor.Evolution.ShadowMode do
  @moduledoc """
  WHAT: Parallel execution without actuation
  WHY: Safe model validation before production
  CONSTRAINTS: N=100 cycles, zero violations, full audit
  """

  @shadow_validation_cycles 100

  @type shadow_state :: %{
    model_id: String.t(),
    cycles: non_neg_integer(),
    violations: non_neg_integer(),
    status: :validating | :promoted | :rejected
  }

  @callback run_shadow(proposal) :: {:ok, result} | {:violation, reason}
  @callback check_promotion(model_id) :: :promote | :continue | :reject
end
```

### 4.4 Guardian Integration Points

| Component | Check Point | Constraint | Latency |
|-----------|-------------|------------|---------|
| Synapse.solve_problem/2 | Before AI invocation | SC-SEC-001 | <100ms |
| Synapse.generate_code/2 | Before code emission | SC-SEC-001 | <100ms |
| Controller.execute_proposal/1 | Before actuation | SC-RES-001 | <100ms |
| ShadowMode.run_shadow/1 | Compare shadow output | SC-EVL-001 | <1000ms |
| TrainingGym.record_veto/2 | After Guardian veto | SC-EVL-003 | <50ms |

---

## Level 5: Atomic Task Breakdown

### 5.1 Phase 1 Atomic Tasks (38 tasks)

#### CTX-1.1 ZenohNeuralStream (17 tasks)
```
CTX-1.1.1   Create GenServer skeleton
CTX-1.1.1.1   Define @type stream_config
CTX-1.1.1.2   Implement init/1 with zenohex session
CTX-1.1.1.3   Implement terminate/2 with cleanup
CTX-1.1.2   Implement stream_log/3
CTX-1.1.2.1   Create log buffer ETS table
CTX-1.1.2.2   Implement 100ms flush timer
CTX-1.1.2.3   Publish to indrajaal/neural/logs/<level>/<module>
CTX-1.1.3   Implement stream_metric/3
CTX-1.1.3.1   Create 1s aggregation window
CTX-1.1.3.2   Format as OTEL-compatible metric
CTX-1.1.4   Implement stream_state/3
CTX-1.1.4.1   Track previous state for delta
CTX-1.1.4.2   Include version vector
```

#### CTX-1.2 ZenohTimeTravel (10 tasks)
```
CTX-1.2.1   Create GenServer skeleton
CTX-1.2.1.1   Define checkpoint key format
CTX-1.2.2   Implement record_checkpoint/2
CTX-1.2.2.1   Serialize state to binary
CTX-1.2.2.2   Store to Zenoh Storage with TTL
CTX-1.2.3   Implement rewind_to/1
CTX-1.2.3.1   Query Zenoh Storage
CTX-1.2.3.2   Deserialize and restore
CTX-1.2.4   Implement list_checkpoints/1
```

#### CTX-1.3 ZenohPolygotBridge (6 tasks)
```
CTX-1.3.1   Create Port-based subprocess
CTX-1.3.1.1   Define JSON-RPC protocol
CTX-1.3.1.2   Implement request/response with timeout
CTX-1.3.2   Create Python bridge
CTX-1.3.2.1   Create scripts/ai/zenoh_bridge.py
```

#### CTX-1.4 TDG Tests (5 tasks)
```
CTX-1.4.1   Property tests for ZenohNeuralStream
CTX-1.4.1.1   Property: Data retrievable
CTX-1.4.1.2   Property: Ordering preserved
CTX-1.4.1.3   Property: Latency < 50ms
```

### 5.2 Phase 2 Atomic Tasks (28 tasks)

#### CTX-2.1 GeminiInterface (6 tasks)
```
CTX-2.1.1   Create GenServer with Google AI client
CTX-2.1.1.1   Add req dependency
CTX-2.1.1.2   Configure API key from env
CTX-2.1.2   Implement analyze_context/2
CTX-2.1.2.1   Format file contents
CTX-2.1.2.2   Parse structured response
```

#### CTX-2.2 ClaudeInterface (7 tasks)
```
CTX-2.2.1   Create GenServer with Anthropic client
CTX-2.2.1.1   Configure API key from env
CTX-2.2.2   Implement generate_solution/2
CTX-2.2.2.1   Format analysis + requirements
CTX-2.2.2.2   Parse code blocks
CTX-2.2.2.3   Validate with Guardian
```

#### CTX-2.3 Synapse Integration (8 tasks)
```
CTX-2.3.1   Add Zenoh session to state
CTX-2.3.2   Implement Bicameral Loop
CTX-2.3.2.1   Step 1: Gemini analysis
CTX-2.3.2.2   Step 2: Claude generation
CTX-2.3.2.3   Step 3: Guardian validation
CTX-2.3.2.4   Step 4: Zenoh publication
```

### 5.3 Phase 3 Atomic Tasks (35 tasks)

#### CTX-3.1 Generator (8 tasks)
```
CTX-3.1.1   Implement alternatives/2
CTX-3.1.1.1   Return Stream of candidates
CTX-3.1.2   Implement file_candidates/1
CTX-3.1.2.1   Pattern: lib/**/<module>.ex
CTX-3.1.2.2   Pattern: test/**/<module>_test.exs
CTX-3.1.3   Implement compose/1
```

#### CTX-3.2 GoalEvaluator (7 tasks)
```
CTX-3.2.1   Implement evaluate/2
CTX-3.2.1.1   Check :compilation_success
CTX-3.2.1.2   Check :test_pass
CTX-3.2.1.3   Check :format_clean
CTX-3.2.2   Implement mark_failed/2 and mark_success/2
```

#### CTX-3.3 Backtracker (10 tasks)
```
CTX-3.3.1   Implement with_backtrack/2
CTX-3.3.1.1   Execute with auto-retry
CTX-3.3.1.2   Store decision points to TimeTravel
CTX-3.3.2   Implement on_failure/2 strategies
CTX-3.3.2.1   Strategy: :retry_next
CTX-3.3.2.2   Strategy: :rewind
CTX-3.3.2.3   Strategy: :escalate
```

#### CTX-3.4 StringScanner (6 tasks)
```
CTX-3.4.1   Create macro parser
CTX-3.4.1.1   Macro: scan/1
CTX-3.4.1.2   Operator: ~>
CTX-3.4.2   Define log patterns
CTX-3.4.2.1   Elixir compilation errors
CTX-3.4.2.2   Test failures
CTX-3.4.2.3   Runtime exceptions
```

#### CTX-3.5 ProposalEngine (4 tasks)
```
CTX-3.5.1   Implement generate_hypotheses/1
CTX-3.5.1.1   Parse signals from StringScanner
CTX-3.5.1.2   Generate fix candidates
CTX-3.5.1.3   Rank by confidence
```

### 5.4 Phase 4 Atomic Tasks (16 tasks)

#### CTX-4.1 VisualOODA (4 tasks)
```
CTX-4.1.1   Create LiveView component
CTX-4.1.1.1   OODA cycle graph
CTX-4.1.1.2   Stress gauge
CTX-4.1.1.3   Proposal queue
```

#### CTX-4.2 RLHFInterface (2 tasks)
```
CTX-4.2.1   Upvote/Downvote components
CTX-4.2.1.1   Store to TrainingGym
```

#### CTX-4.3 SafetyMonitor (3 tasks)
```
CTX-4.3.1   Guardian state view
CTX-4.3.1.1   Veto log display
CTX-4.3.1.2   Constraint dashboard
```

#### CTX-4.4 TwoKeyTurn (3 tasks)
```
CTX-4.4.1   Multi-signature authorization
CTX-4.4.1.1   Required for critical actuators
CTX-4.4.1.2   Audit trail
```

### 5.5 Phase 5 Atomic Tasks (18 tasks)

#### CTX-5.1 ShadowMode (6 tasks)
```
CTX-5.1.1   Parallel execution engine
CTX-5.1.1.1   Execute without actuator writes
CTX-5.1.1.2   Compare to legacy
CTX-5.1.2   Track validation cycles
CTX-5.1.2.1   Count per model (N=100)
CTX-5.1.2.2   Record violations
```

#### CTX-5.2 TrainingGym (5 tasks)
```
CTX-5.2.1   Negative example collector
CTX-5.2.1.1   Store Guardian vetoes
CTX-5.2.1.2   Store RLHF downvotes
CTX-5.2.1.3   Publish to indrajaal/training/negative
CTX-5.2.2   Export for training
CTX-5.2.2.1   Format as JSONL
```

#### CTX-5.3 PromotionEngine (4 tasks)
```
CTX-5.3.1   N=100 cycle validation
CTX-5.3.1.1   Zero violations check
CTX-5.3.1.2   Auto-promote on success
CTX-5.3.1.3   Auto-reject on violation
```

#### CTX-5.4 VetoAnalyzer (3 tasks)
```
CTX-5.4.1   Pattern detection
CTX-5.4.1.1   Cluster similar vetoes
CTX-5.4.1.2   Suggest refinements
```

---

## Appendix A: STAMP Constraints

| ID | Constraint | Module | Latency |
|----|------------|--------|---------|
| SC-CTX-001 | OODA cycle < 1000ms | Controller | <1000ms |
| SC-CTX-002 | Guardian veto < 100ms | Guardian | <100ms |
| SC-CTX-003 | Neural stream < 50ms | ZenohNeuralStream | <50ms |
| SC-CTX-004 | GDE backtrack < 5s | Backtracker | <5000ms |
| SC-CTX-005 | Shadow isolation complete | ShadowMode | N/A |
| SC-CTX-006 | No actuator writes in shadow | ShadowMode | N/A |
| SC-CTX-007 | Audit trail complete | TrainingGym | N/A |
| SC-CTX-008 | Checkpoint recoverable | ZenohTimeTravel | <1000ms |
| SC-CTX-009 | Two-key auth for critical | TwoKeyTurn | N/A |
| SC-CTX-010 | RLHF feedback recorded | RLHFInterface | <50ms |

---

## Appendix B: AOR Rules

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-CTX-001 | AI proposals MUST pass Guardian | Synapse |
| AOR-CTX-002 | New models MUST shadow validate | ShadowMode |
| AOR-CTX-003 | Vetoes MUST log to TrainingGym | Guardian |
| AOR-CTX-004 | Critical actuators REQUIRE two-key | TwoKeyTurn |
| AOR-CTX-005 | OODA timeout triggers circuit breaker | Controller |
| AOR-CTX-006 | GDE MUST use Zenoh for state | Backtracker |
| AOR-CTX-007 | Livebook MUST be read-only for safety | SafetyMonitor |
| AOR-CTX-008 | Promotion REQUIRES N=100 clean cycles | PromotionEngine |
| AOR-CTX-009 | Neural streams MUST use zero-copy | ZenohNeuralStream |
| AOR-CTX-010 | Polyglot bridge MUST use subprocess | ZenohPolygotBridge |

---

## Appendix C: File Manifest

### New Files (26 files, ~5,500 LoC)
```
lib/indrajaal/observability/
├── zenoh_neural_stream.ex       (~200 LoC)
├── zenoh_time_travel.ex         (~250 LoC)
└── zenoh_polyglot_bridge.ex     (~180 LoC)

lib/indrajaal/cortex/ai/
├── gemini_interface.ex          (~200 LoC)
├── claude_interface.ex          (~200 LoC)
└── local_model.ex               (MOVE from lib/indrajaal/ai/)

lib/indrajaal/cortex/gde/
├── generator.ex                 (~250 LoC)
├── goal_evaluator.ex            (~200 LoC)
├── backtracker.ex               (~300 LoC)
├── string_scanner.ex            (~250 LoC)
└── proposal_engine.ex           (~200 LoC)

lib/indrajaal/cockpit/
├── visual_ooda.ex               (~300 LoC)
├── rlhf_interface.ex            (~200 LoC)
├── safety_monitor.ex            (~150 LoC)
└── two_key_turn.ex              (~200 LoC)

lib/indrajaal/evolution/
├── shadow_mode.ex               (~300 LoC)
├── training_gym.ex              (~250 LoC)
├── promotion_engine.ex          (~200 LoC)
└── veto_analyzer.ex             (~200 LoC)

scripts/ai/
└── zenoh_bridge.py              (~150 LoC)

livebooks/
└── cortex_cockpit.livemd        (~200 LoC)
```

### Modified Files (5 files)
```
lib/indrajaal/cortex/synapse.ex     - Add Zenoh integration
lib/indrajaal/cortex/controller.ex  - Add GDE integration
mix.exs                             - Add zenohex dependency
config/config.exs                   - Add AI API configs
scripts/tools/start_livebook.sh     - Update for cockpit
```

### Test Files (10 files, ~1,500 LoC)
```
test/indrajaal/observability/
├── zenoh_neural_stream_test.exs
├── zenoh_time_travel_test.exs
└── zenoh_polyglot_bridge_test.exs

test/indrajaal/cortex/ai/
├── gemini_interface_test.exs
├── claude_interface_test.exs
└── synapse_test.exs

test/indrajaal/cortex/gde/
├── generator_test.exs
├── backtracker_test.exs
└── goal_evaluator_test.exs

test/indrajaal/evolution/
└── shadow_mode_test.exs
```

---

## Appendix D: Session Metrics

| Metric | Value |
|--------|-------|
| Session Start | 2025-12-26T15:00:00+01:00 |
| Session End | 2025-12-26T16:00:00+01:00 |
| Duration | ~60 minutes |
| Documents Created | 3 |
| Todolist Tasks | 130+ atomic tasks |
| Phases Planned | 5 |
| New Files Planned | 26 |
| Estimated LoC | ~7,000 |
| STAMP Constraints | 10 (SC-CTX-001 to SC-CTX-010) |
| AOR Rules | 10 (AOR-CTX-001 to AOR-CTX-010) |

---

**End of 5-Level Journal Entry**

*Generated by Cybernetic Architect | SOPv5.11 Compliant | STAMP Verified*
