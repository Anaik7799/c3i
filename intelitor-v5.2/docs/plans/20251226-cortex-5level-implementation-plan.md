# Neuro-Symbolic Cortex Integration: 5-Level Implementation Plan

**Document Control**

| Field | Value |
|-------|-------|
| Entry ID | PLAN-20251226-CORTEX |
| Version | 1.0.0 |
| Status | ACTIVE |
| Created | 2025-12-26T15:30:00+01:00 |
| Author | Cybernetic Architect (Claude) |
| Source | docs/plans/20251226-cortex-integration-master-plan.md |
| STAMP | SC-CTX-001 to SC-CTX-010, SC-SEC-001, SC-OBS-001 |

---

## Level 1: Executive Summary

**Goal**: Implement the Bicameral Cybernetic Organism using the Simplex Architecture with 5 core subsystems:

| Subsystem | Status | Priority | Complexity |
|-----------|--------|----------|------------|
| 1. Safety Plane (Guardian) | IMPLEMENTED | P0 | Medium |
| 2. Nervous System (Zenoh) | PARTIAL | P1 | High |
| 3. Cortex (Bicameral Intelligence) | PARTIAL | P1 | High |
| 4. Unicon Logical Paradigms (GDE) | NEW | P2 | Very High |
| 5. Cognitive Cockpit (Livebook) | STUBBED | P2 | Medium |
| 6. Evolution Strategy (Anti-Fragility) | NEW | P3 | High |

**Target Metrics**:
- OODA Latency: < 5s for agent decisions
- Guardian Veto Latency: < 100ms
- Zenoh Neural Stream Latency: < 50ms
- Shadow Mode Validation Cycles: N=100 before promotion

---

## Level 2: Subsystem Architecture

### 2.1 Safety Plane (Guardian) - IMPLEMENTED
```
lib/indrajaal/safety/guardian.ex (GenServer)
├── validate_proposal/1 - Atomic gatekeeper
├── check_resource_bounds/1 - SC-RES-001 (Max 50 FLAME, 32GB)
├── check_security_constraints/1 - SC-SEC-001 (No unverified exec)
├── check_actuator_physics/1 - SC-ACT-001 (Physics limits)
└── generate_safe_fallback/1 - Deterministic fallbacks
```

### 2.2 Nervous System (Zenoh) - PARTIAL
```
lib/indrajaal/observability/
├── zenoh_coordinator.ex     - EXISTS (needs enhancement)
├── zenoh_kpi_publisher.ex   - EXISTS
├── zenoh_control_subscriber.ex - EXISTS
├── zenoh_neural_stream.ex   - NEW (real-time log/metric streaming)
├── zenoh_time_travel.ex     - NEW (backtracking buffer)
└── zenoh_polyglot_bridge.ex - NEW (Python/Mojo interface)
```

### 2.3 Cortex (Bicameral Intelligence) - PARTIAL
```
lib/indrajaal/cortex/
├── controller.ex           - EXISTS (OODA loop engine)
├── synapse.ex              - EXISTS (stubbed, needs Zenoh integration)
├── ai/
│   ├── gemini_interface.ex - NEW (context awareness)
│   ├── claude_interface.ex - NEW (reasoning/synthesis)
│   └── local_model.ex      - MOVE from lib/indrajaal/ai/
├── sensors/                - EXISTS (5 sensors)
├── reflexes/               - EXISTS (circuit breaker)
└── homeostasis/            - EXISTS (controller)
```

### 2.4 Unicon Logical Paradigms (GDE) - NEW
```
lib/indrajaal/cortex/gde/
├── generator.ex            - Stream-based value generation
├── goal_evaluator.ex       - Goal success/failure detection
├── backtracker.ex          - Automatic retry with alternatives
├── string_scanner.ex       - Macro-based log parsing DSL
└── proposal_engine.ex      - Hypothesis generation for evolution
```

### 2.5 Cognitive Cockpit (Livebook) - STUBBED
```
scripts/tools/
├── start_livebook.sh       - EXISTS
lib/indrajaal/cockpit/
├── visual_ooda.ex          - NEW (real-time OODA graphing)
├── rlhf_interface.ex       - NEW (upvote/downvote proposals)
├── safety_monitor.ex       - NEW (Guardian state viewer)
└── two_key_turn.ex         - NEW (multi-sig authorization)
```

### 2.6 Evolution Strategy (Anti-Fragility) - NEW
```
lib/indrajaal/evolution/
├── shadow_mode.ex          - Parallel execution without actuation
├── training_gym.ex         - Negative example collection
├── promotion_engine.ex     - N-cycle validation before promotion
├── genetic_safety.ex       - FUTURE: Evolutionary safety envelope
└── veto_analyzer.ex        - Learn from Guardian vetoes
```

---

## Level 3: Implementation Phases

### Phase 1: Zenoh Neural Stream Integration (P1)
**Duration**: 2-3 development sessions
**Dependencies**: zenoh_coordinator.ex exists

| Task ID | Task | File | Status |
|---------|------|------|--------|
| CTX-1.1 | Create ZenohNeuralStream GenServer | lib/indrajaal/observability/zenoh_neural_stream.ex | NEW |
| CTX-1.2 | Implement real-time log streaming to Zenoh | zenoh_neural_stream.ex | NEW |
| CTX-1.3 | Create ZenohTimeTravel for backtracking buffer | lib/indrajaal/observability/zenoh_time_travel.ex | NEW |
| CTX-1.4 | Implement Zenoh Storage query for rewind | zenoh_time_travel.ex | NEW |
| CTX-1.5 | Create ZenohPolygotBridge for Python/Mojo | lib/indrajaal/observability/zenoh_polyglot_bridge.ex | NEW |
| CTX-1.6 | Add Zenoh dependency to mix.exs (zenohex) | mix.exs | MODIFY |
| CTX-1.7 | Create TDG tests for neural streams | test/indrajaal/observability/zenoh_neural_stream_test.exs | NEW |
| CTX-1.8 | Create TDG tests for time travel | test/indrajaal/observability/zenoh_time_travel_test.exs | NEW |

### Phase 2: Synapse Full Integration (P1)
**Duration**: 2-3 development sessions
**Dependencies**: Phase 1 complete

| Task ID | Task | File | Status |
|---------|------|------|--------|
| CTX-2.1 | Move LocalModel to lib/indrajaal/cortex/ai/ | lib/indrajaal/cortex/ai/local_model.ex | MOVE |
| CTX-2.2 | Create GeminiInterface for context awareness | lib/indrajaal/cortex/ai/gemini_interface.ex | NEW |
| CTX-2.3 | Create ClaudeInterface for reasoning | lib/indrajaal/cortex/ai/claude_interface.ex | NEW |
| CTX-2.4 | Update Synapse to use Zenoh for AI communication | lib/indrajaal/cortex/synapse.ex | MODIFY |
| CTX-2.5 | Implement Bicameral Loop (Gemini→Claude pipeline) | lib/indrajaal/cortex/synapse.ex | MODIFY |
| CTX-2.6 | Add Guardian validation to all Synapse outputs | lib/indrajaal/cortex/synapse.ex | MODIFY |
| CTX-2.7 | Create TDG tests for Synapse integration | test/indrajaal/cortex/synapse_test.exs | NEW |
| CTX-2.8 | Create TDG tests for AI interfaces | test/indrajaal/cortex/ai/*_test.exs | NEW |

### Phase 3: Goal-Directed Evaluation (GDE) (P2)
**Duration**: 3-4 development sessions
**Dependencies**: Phase 2 complete

| Task ID | Task | File | Status |
|---------|------|------|--------|
| CTX-3.1 | Create Generator module (lazy streams) | lib/indrajaal/cortex/gde/generator.ex | NEW |
| CTX-3.2 | Create GoalEvaluator (success/failure detection) | lib/indrajaal/cortex/gde/goal_evaluator.ex | NEW |
| CTX-3.3 | Create Backtracker (automatic retry logic) | lib/indrajaal/cortex/gde/backtracker.ex | NEW |
| CTX-3.4 | Create StringScanner DSL (macro-based parsing) | lib/indrajaal/cortex/gde/string_scanner.ex | NEW |
| CTX-3.5 | Create ProposalEngine (hypothesis generation) | lib/indrajaal/cortex/gde/proposal_engine.ex | NEW |
| CTX-3.6 | Integrate GDE with Cortex Controller | lib/indrajaal/cortex/controller.ex | MODIFY |
| CTX-3.7 | Add Zenoh backtracking via TimeTravel | lib/indrajaal/cortex/gde/backtracker.ex | MODIFY |
| CTX-3.8 | Create TDG property tests for generators | test/indrajaal/cortex/gde/generator_test.exs | NEW |
| CTX-3.9 | Create TDG tests for backtracking | test/indrajaal/cortex/gde/backtracker_test.exs | NEW |
| CTX-3.10 | Create TDG tests for goal evaluation | test/indrajaal/cortex/gde/goal_evaluator_test.exs | NEW |

### Phase 4: Cognitive Cockpit (Livebook) (P2)
**Duration**: 2 development sessions
**Dependencies**: Phase 2 complete

| Task ID | Task | File | Status |
|---------|------|------|--------|
| CTX-4.1 | Create VisualOODA LiveView component | lib/indrajaal/cockpit/visual_ooda.ex | NEW |
| CTX-4.2 | Create RLHFInterface for human feedback | lib/indrajaal/cockpit/rlhf_interface.ex | NEW |
| CTX-4.3 | Create SafetyMonitor (Guardian state viewer) | lib/indrajaal/cockpit/safety_monitor.ex | NEW |
| CTX-4.4 | Create TwoKeyTurn authorization module | lib/indrajaal/cockpit/two_key_turn.ex | NEW |
| CTX-4.5 | Update Livebook startup script | scripts/tools/start_livebook.sh | MODIFY |
| CTX-4.6 | Create Livebook notebook templates | livebooks/cortex_cockpit.livemd | NEW |
| CTX-4.7 | Integrate Cockpit with Zenoh streams | lib/indrajaal/cockpit/*.ex | MODIFY |

### Phase 5: Evolution Strategy (Anti-Fragility) (P3)
**Duration**: 3-4 development sessions
**Dependencies**: Phase 3 complete

| Task ID | Task | File | Status |
|---------|------|------|--------|
| CTX-5.1 | Create ShadowMode parallel executor | lib/indrajaal/evolution/shadow_mode.ex | NEW |
| CTX-5.2 | Create TrainingGym negative example collector | lib/indrajaal/evolution/training_gym.ex | NEW |
| CTX-5.3 | Create PromotionEngine (N-cycle validation) | lib/indrajaal/evolution/promotion_engine.ex | NEW |
| CTX-5.4 | Create VetoAnalyzer (learn from Guardian vetoes) | lib/indrajaal/evolution/veto_analyzer.ex | NEW |
| CTX-5.5 | Integrate ShadowMode with Synapse | lib/indrajaal/cortex/synapse.ex | MODIFY |
| CTX-5.6 | Connect TrainingGym to Local AI LoRA training | lib/indrajaal/evolution/training_gym.ex | MODIFY |
| CTX-5.7 | Create TDG tests for shadow mode | test/indrajaal/evolution/shadow_mode_test.exs | NEW |
| CTX-5.8 | Create TDG tests for training gym | test/indrajaal/evolution/training_gym_test.exs | NEW |

---

## Level 4: Detailed Specifications

### 4.1 ZenohNeuralStream Specification
```elixir
defmodule Indrajaal.Observability.ZenohNeuralStream do
  @moduledoc """
  Real-time streaming of logs, metrics, and state via Zenoh.

  WHAT: Replaces disk-based logging with Zenoh pub/sub
  WHY: SC-OBS-001 requires < 50ms telemetry latency
  CONSTRAINTS: Zero-copy, no disk writes for real-time data

  ## Key Expressions
  - indrajaal/neural/logs/<level>/<module>
  - indrajaal/neural/metrics/<domain>/<metric>
  - indrajaal/neural/state/<agent>/<key>

  ## STAMP Constraints
  - SC-OBS-001: Latency < 50ms
  - SC-OBS-002: No data loss
  - SC-OBS-003: Ordered delivery per key
  """

  use GenServer

  @type stream_config :: %{
    key_prefix: String.t(),
    buffer_size: pos_integer(),
    flush_interval_ms: pos_integer()
  }

  @callback stream_log(level :: atom(), module :: module(), message :: binary()) :: :ok
  @callback stream_metric(domain :: atom(), name :: atom(), value :: number()) :: :ok
  @callback stream_state(agent :: atom(), key :: atom(), value :: term()) :: :ok
end
```

### 4.2 GDE Generator Specification
```elixir
defmodule Indrajaal.Cortex.GDE.Generator do
  @moduledoc """
  Unicon-style Generators: Functions that return streams of potential values.

  WHAT: Lazy stream-based value generation for backtracking
  WHY: Enables Goal-Directed Evaluation with automatic retry
  CONSTRAINTS: Must be composable, lazy, and deterministic

  ## Usage
  ```elixir
  # Generate alternative file paths for a module
  for path <- Generator.file_candidates("accounts") do
    case File.read(path) do
      {:ok, content} -> content  # Success stops generation
      {:error, _} -> :fail       # Failure triggers next candidate
    end
  end
  ```
  """

  @type generator :: Enumerable.t()

  @callback alternatives(base :: term(), opts :: keyword()) :: generator()
  @callback backtrack(generator(), on_failure :: (term() -> :retry | :stop)) :: term()
  @callback compose(generators :: [generator()]) :: generator()
end
```

### 4.3 ShadowMode Specification
```elixir
defmodule Indrajaal.Evolution.ShadowMode do
  @moduledoc """
  Parallel execution without actuation for safe model validation.

  WHAT: Runs new AI models alongside legacy, compares outputs
  WHY: Prevents unsafe models from reaching production
  CONSTRAINTS: N=100 cycles of zero safety violations before promotion

  ## Protocol
  1. Receive proposal from Synapse
  2. Execute in shadow (no actuator writes)
  3. Compare output to legacy model
  4. Record disagreements and violations
  5. After N cycles with zero violations, promote

  ## STAMP Constraints
  - SC-EVL-001: Shadow mode isolation
  - SC-EVL-002: No side effects
  - SC-EVL-003: Full audit trail
  """

  @shadow_validation_cycles 100

  @type shadow_state :: %{
    model_id: String.t(),
    cycles: non_neg_integer(),
    violations: non_neg_integer(),
    disagreements: [term()],
    status: :validating | :promoted | :rejected
  }

  @callback run_shadow(proposal :: term()) :: {:ok, result :: term()} | {:violation, reason :: term()}
  @callback check_promotion(model_id :: String.t()) :: :promote | :continue | :reject
end
```

### 4.4 Guardian Integration Points

| Component | Guardian Check Point | Constraint |
|-----------|---------------------|------------|
| Synapse solve_problem/2 | Before AI invocation | SC-SEC-001 |
| Synapse generate_code/2 | Before code emission | SC-SEC-001 |
| Controller execute_proposal/1 | Before actuation | SC-RES-001, SC-ACT-001 |
| ShadowMode run_shadow/1 | Compare shadow output | SC-EVL-001 |
| TrainingGym record_veto/2 | After Guardian veto | SC-EVL-003 |

---

## Level 5: Implementation Tasks (Atomic)

### 5.1 Phase 1: Zenoh Neural Stream (12 Tasks)

#### CTX-1.1.1: Create ZenohNeuralStream GenServer skeleton
- File: `lib/indrajaal/observability/zenoh_neural_stream.ex`
- Lines: ~150
- STAMP: SC-OBS-001
- Test: `test/indrajaal/observability/zenoh_neural_stream_test.exs`

#### CTX-1.1.2: Implement stream_log/3 with batching
- Batch size: 100 messages or 100ms flush
- Key: `indrajaal/neural/logs/<level>/<module>`
- Format: JSON with timestamp, level, message, metadata

#### CTX-1.1.3: Implement stream_metric/3 with aggregation
- Aggregation window: 1 second
- Key: `indrajaal/neural/metrics/<domain>/<metric>`
- Format: OTEL-compatible metric format

#### CTX-1.1.4: Implement stream_state/3 with delta encoding
- Only publish changed values
- Key: `indrajaal/neural/state/<agent>/<key>`
- Include version vector for ordering

#### CTX-1.2.1: Create ZenohTimeTravel GenServer skeleton
- File: `lib/indrajaal/observability/zenoh_time_travel.ex`
- Lines: ~200
- STAMP: SC-OBS-002

#### CTX-1.2.2: Implement record_checkpoint/2
- Store current state snapshot to Zenoh Storage
- Key: `indrajaal/timemachine/<timestamp>/<session>`

#### CTX-1.2.3: Implement rewind_to/1
- Query Zenoh Storage for checkpoint
- Restore state from checkpoint
- Return delta since checkpoint

#### CTX-1.2.4: Implement list_checkpoints/1
- Return available checkpoints within time window
- Include metadata (size, key count, timestamp)

#### CTX-1.3.1: Create ZenohPolygotBridge skeleton
- File: `lib/indrajaal/observability/zenoh_polyglot_bridge.ex`
- Lines: ~180
- STAMP: SC-INT-001

#### CTX-1.3.2: Implement Python subprocess communication
- Use Port for zero-copy IPC
- Protocol: JSON-RPC over stdin/stdout

#### CTX-1.3.3: Implement Mojo interface (Future)
- Placeholder for high-performance inference

#### CTX-1.4.1: Create TDG tests for neural streams
- Property: All streamed data retrievable
- Property: Ordering preserved per key
- Property: Latency < 50ms (95th percentile)

### 5.2 Phase 2: Synapse Integration (10 Tasks)

#### CTX-2.1.1: Create GeminiInterface skeleton
- File: `lib/indrajaal/cortex/ai/gemini_interface.ex`
- API: Google AI Studio / Vertex AI
- Capability: Context ingestion, repository analysis

#### CTX-2.1.2: Implement analyze_context/2
- Input: File paths, query
- Output: Structured analysis with references
- Zenoh topic: `indrajaal/ai/gemini/request`

#### CTX-2.2.1: Create ClaudeInterface skeleton
- File: `lib/indrajaal/cortex/ai/claude_interface.ex`
- API: Anthropic API
- Capability: Code generation, reasoning

#### CTX-2.2.2: Implement generate_solution/2
- Input: Analysis from Gemini, requirements
- Output: Code proposal with explanation
- Guardian validation: Before emission

#### CTX-2.3.1: Update Synapse with Zenoh session
- Replace stub with actual zenohex calls
- Initialize session in init/1
- Clean up in terminate/2

#### CTX-2.3.2: Implement Bicameral Loop
- Step 1: Gemini context analysis
- Step 2: Claude solution generation
- Step 3: Guardian validation
- Step 4: Result publication

#### CTX-2.4.1: Add Guardian.validate_proposal/1 to solve_problem
- Call before AI invocation
- Reject if proposal violates SC-SEC-001

#### CTX-2.4.2: Add Guardian.validate_proposal/1 to generate_code
- Validate generated code before return
- Reject if code contains forbidden ops

#### CTX-2.5.1: Create TDG tests for Synapse
- Mock Zenoh session
- Test Bicameral Loop flow
- Test Guardian integration

### 5.3 Phase 3: GDE Implementation (15 Tasks)

#### CTX-3.1.1: Create Generator module with Stream primitives
- `alternatives/2`: Generate candidate values
- `compose/1`: Combine generators
- `take_until/2`: Stop on success

#### CTX-3.1.2: Implement file_candidates/1 generator
- Input: Module name
- Output: Stream of possible file paths
- Pattern: lib/**/<module>.ex, test/**/<module>_test.exs

#### CTX-3.2.1: Create GoalEvaluator with success/failure detection
- `evaluate/2`: Check if goal achieved
- `mark_failed/2`: Record failure reason
- `mark_success/2`: Record success path

#### CTX-3.2.2: Define standard goals
- `:compilation_success`: Zero errors
- `:test_pass`: All tests green
- `:format_clean`: No format violations

#### CTX-3.3.1: Create Backtracker with retry logic
- `with_backtrack/2`: Execute with auto-retry
- `on_failure/2`: Define retry strategy
- Integration with ZenohTimeTravel for state rewind

#### CTX-3.3.2: Implement backtrack state storage
- Store decision points to Zenoh
- Support branching factor limits
- Pruning strategy for old branches

#### CTX-3.4.1: Create StringScanner DSL
- Macro-based log parsing
- Pattern: `scan "Error:" ~> module ~> ":" ~> line`
- Output: Structured signal

#### CTX-3.4.2: Define common log patterns
- Elixir compilation errors
- Test failures
- Runtime exceptions

#### CTX-3.5.1: Create ProposalEngine skeleton
- Generate fix hypotheses from signals
- Rank by confidence
- Feed to Synapse for execution

#### CTX-3.6.1: Integrate GDE with Controller DECIDE phase
- Use Generator for proposal candidates
- Use GoalEvaluator for success check
- Use Backtracker for retry

### 5.4 Phase 4: Cognitive Cockpit (8 Tasks)

#### CTX-4.1.1: Create VisualOODA LiveView
- Real-time OODA cycle graph
- Stress score visualization
- Proposal queue display

#### CTX-4.2.1: Create RLHFInterface
- Upvote/Downvote buttons for proposals
- Feedback stored to TrainingGym
- User authentication required

#### CTX-4.3.1: Create SafetyMonitor
- Read-only Guardian state view
- Veto log display
- Constraint status dashboard

#### CTX-4.4.1: Create TwoKeyTurn module
- Multi-signature authorization
- Required for critical actuators
- Audit trail for all authorizations

### 5.5 Phase 5: Evolution Strategy (10 Tasks)

#### CTX-5.1.1: Create ShadowMode GenServer
- Parallel execution engine
- No actuator writes
- Result comparison

#### CTX-5.1.2: Implement shadow validation cycle
- Track cycles per model
- Record violations
- Check promotion criteria

#### CTX-5.2.1: Create TrainingGym collector
- Store Guardian vetoes
- Store RLHF feedback
- Export for AI training

#### CTX-5.2.2: Implement negative example format
- Include proposal, reason, fallback
- Include context (observation, orientation)
- Zenoh topic: `indrajaal/training/negative`

#### CTX-5.3.1: Create PromotionEngine
- N=100 cycle validation
- Zero violation requirement
- Automatic promotion on success

#### CTX-5.4.1: Create VetoAnalyzer
- Pattern detection in vetoes
- Suggest constraint refinements
- Feed to GeneticSafety (future)

---

## Appendix A: STAMP Constraints for Cortex

| ID | Constraint | Module |
|----|------------|--------|
| SC-CTX-001 | OODA cycle < 1000ms | Controller |
| SC-CTX-002 | Guardian veto < 100ms | Guardian |
| SC-CTX-003 | Neural stream < 50ms | ZenohNeuralStream |
| SC-CTX-004 | GDE backtrack < 5s | Backtracker |
| SC-CTX-005 | Shadow isolation complete | ShadowMode |
| SC-CTX-006 | No actuator writes in shadow | ShadowMode |
| SC-CTX-007 | Audit trail complete | TrainingGym |
| SC-CTX-008 | Checkpoint recoverable | ZenohTimeTravel |
| SC-CTX-009 | Two-key auth for critical | TwoKeyTurn |
| SC-CTX-010 | RLHF feedback recorded | RLHFInterface |

---

## Appendix B: AOR Rules for Cortex

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-CTX-001 | AI proposals MUST pass Guardian | Synapse |
| AOR-CTX-002 | New models MUST shadow validate | ShadowMode |
| AOR-CTX-003 | Vetoes MUST be logged to TrainingGym | Guardian |
| AOR-CTX-004 | Critical actuators REQUIRE two-key | TwoKeyTurn |
| AOR-CTX-005 | OODA timeout MUST trigger circuit breaker | Controller |
| AOR-CTX-006 | GDE MUST use Zenoh for state storage | Backtracker |
| AOR-CTX-007 | Livebook MUST be read-only for safety | SafetyMonitor |
| AOR-CTX-008 | Promotion REQUIRES N=100 clean cycles | PromotionEngine |
| AOR-CTX-009 | Neural streams MUST use zero-copy | ZenohNeuralStream |
| AOR-CTX-010 | Polyglot bridge MUST use subprocess | ZenohPolygotBridge |

---

**End of 5-Level Implementation Plan**

*Generated by Cybernetic Architect | SOPv5.11 Compliant | STAMP Verified*
