# OpenRouter Integration Comprehensive Test Plan

**Version**: 1.1.0 | **Date**: 2025-12-27 | **Author**: Cybernetic Architect
**STAMP Compliance**: SC-GDE-060, SC-GDE-061, SC-NEURO-001, SC-NEURO-003, SC-CNT-009

---

## L1: Executive Summary

This document defines the comprehensive test strategy for the OpenRouter AI integration within the Indrajaal safety-critical security platform. The integration provides tiered AI routing (:fast, :smart, :deep) with telemetry streaming via Zenoh and safety validation through Guardian.

**Test Categories**:
- TDG (Test-Driven Generation) Property Tests
- STAMP Constraint Verification
- AOR (Agent Operating Rules) Compliance
- Intermodule Integration Tests
- Critical E2E DAG Flow Tests

**Target Coverage**: 100% of public API, 95% line coverage

---

## L2: Architecture Under Test

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    OpenRouter Integration Test Surface                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                        PUBLIC API (Unit Tests)                        │  │
│  │                                                                       │  │
│  │  OpenRouterClient.chat/2                                              │  │
│  │    ├── Model Selection (:fast, :smart, :deep)                        │  │
│  │    ├── Cache Control Injection (Anthropic models)                    │  │
│  │    ├── Cost Tracking (tokens, latency)                               │  │
│  │    └── Error Handling (missing key, rate limit, timeout)             │  │
│  │                                                                       │  │
│  │  Synapse.solve/3                                                      │  │
│  │    ├── Context Triage (local model filtering)                        │  │
│  │    ├── OpenRouter Delegation                                         │  │
│  │    └── Response Processing                                           │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    INTEGRATION LAYER (Integration Tests)              │  │
│  │                                                                       │  │
│  │  Zenoh Telemetry                                                      │  │
│  │    ├── indrajaal/evolution/openrouter/calls                          │  │
│  │    ├── indrajaal/evolution/gde/proposals                             │  │
│  │    └── indrajaal/evolution/stats                                     │  │
│  │                                                                       │  │
│  │  Guardian Safety Validation                                           │  │
│  │    ├── Proposal Confidence Check (>= 0.6)                            │  │
│  │    ├── Forbidden Operation Detection                                  │  │
│  │    └── Simplex Principle Enforcement                                  │  │
│  │                                                                       │  │
│  │  CEPAF Bridge                                                         │  │
│  │    ├── Context Gathering (cepaf.context_gather)                      │  │
│  │    ├── Command Translation (AI → CEPAF actions)                      │  │
│  │    └── Telemetry Recording (OpenRouterCall event)                    │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                      E2E DAG FLOWS (System Tests)                     │  │
│  │                                                                       │  │
│  │  OODA Loop: Observe → Orient → Decide → Act                          │  │
│  │    ├── Cortex receives system stress signal                          │  │
│  │    ├── Synapse analyzes with OpenRouter                              │  │
│  │    ├── Guardian validates proposal                                   │  │
│  │    ├── GDE applies evolution action                                  │  │
│  │    └── Telemetry confirms success                                    │  │
│  │                                                                       │  │
│  │  GDE Pipeline: Hypothesis → Simulate → Select → Execute → Verify    │  │
│  │    ├── Generate optimization hypotheses via AI                       │  │
│  │    ├── Simulate outcomes (shadow mode)                               │  │
│  │    ├── Select best proposal (confidence scoring)                     │  │
│  │    ├── Execute via AEE tools                                         │  │
│  │    └── Verify state transition                                       │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## L3: Test Categories

### L3.1: TDG Property-Based Tests

**File**: `test/indrajaal/ai/open_router_property_test.exs`

| Property ID | Description | Generator | Constraint |
|-------------|-------------|-----------|------------|
| PROP-OR-001 | Model selection maps correctly | `:fast \| :smart \| :deep` | Output model matches tier |
| PROP-OR-002 | Messages format validation | `list(message_gen())` | All messages have role+content |
| PROP-OR-003 | Cache control injection | Anthropic model + system msg | cache_control header present |
| PROP-OR-004 | Cost tracking invariant | `integer(1, 100_000)` tokens | Cost > 0 when tokens > 0 |
| PROP-OR-005 | Error type coverage | Error scenarios | Returns tagged tuple |
| PROP-OR-006 | Timeout behavior | Duration generator | Respects configured timeout |
| PROP-OR-007 | API key validation | String/nil | Fails gracefully without key |
| PROP-OR-008 | Response structure | Valid API response | Extracts content correctly |

**Dual Testing Pattern** (SC-PROP-023/024):
```elixir
use PropCheck
import ExUnitProperties, except: [property: 2, property: 3, check: 2]
alias PropCheck.BasicTypes, as: PC
alias StreamData, as: SD

# PropCheck property
property "model tier mapping" do
  forall tier <- PC.oneof([:fast, :smart, :deep]) do
    model = OpenRouterClient.model_for_tier(tier)
    is_binary(model) and String.contains?(model, "/")
  end
end

# StreamData property
property "message validation", [:verbose] do
  check all(messages <- SD.list_of(message_generator(), min_length: 1)) do
    assert Enum.all?(messages, &valid_message?/1)
  end
end
```

### L3.2: STAMP Constraint Verification Tests

**File**: `test/indrajaal/ai/open_router_stamp_test.exs`

| Constraint | Test | Expected Behavior |
|------------|------|-------------------|
| SC-GDE-060 | All AI uses OpenRouter | No direct Claude/Gemini API calls |
| SC-GDE-061 | Confidence >= 0.6 | Low-confidence proposals rejected |
| SC-NEURO-001 | Simplex Principle | AI outputs validated before action |
| SC-NEURO-003 | Forbidden Operations | rm -rf, DROP TABLE blocked |
| SC-CNT-009 | Podman Enforcement | Container ops via Podman only |
| SC-SEC-044 | No secrets in prompts | API keys not leaked to AI |
| SC-OBS-069 | Dual logging | Both terminal and SigNoz receive events |

**Test Pattern**:
```elixir
describe "SC-GDE-060: OpenRouter Exclusivity" do
  test "Synapse routes all AI through OpenRouter" do
    # Ensure no direct API calls bypass the gateway
    assert Synapse.ai_backend() == :openrouter
    refute Synapse.supports_direct_anthropic?()
  end
end

describe "SC-NEURO-001: Simplex Principle" do
  test "AI proposal requires Guardian validation before execution" do
    proposal = %{action: :scale_pool, confidence: 0.75}

    # Cannot execute without Guardian approval
    assert {:error, :validation_required} =
      GDE.execute_without_validation(proposal)

    # With Guardian approval
    assert {:ok, :validated} = Guardian.validate(proposal)
    assert {:ok, _} = GDE.execute(proposal)
  end
end
```

### L3.3: AOR Compliance Tests

**File**: `test/indrajaal/ai/open_router_aor_test.exs`

| Rule | Test | Verification |
|------|------|--------------|
| AOR-SAF-001 | Halt on STAMP violation | Response time < 1s |
| AOR-CNT-001 | Podman enforcement | No Docker commands |
| AOR-QUA-001 | Zero warnings | Compile without warnings |
| AOR-GEM-001 | Plan → Verify | All AI plans validated |
| AOR-GEM-003 | No hallucinated APIs | Validate function existence |
| AOR-PROP-001 | PC/SD disambiguation | No generator conflicts |

**Test Pattern**:
```elixir
describe "AOR-SAF-001: Halt on STAMP Violation" do
  test "forbidden operation triggers immediate halt" do
    dangerous_response = %{
      action: "rm -rf /",
      confidence: 0.99
    }

    start_time = System.monotonic_time(:millisecond)
    result = Guardian.validate(dangerous_response)
    elapsed = System.monotonic_time(:millisecond) - start_time

    assert {:error, :forbidden_operation} = result
    assert elapsed < 1000, "Halt took #{elapsed}ms, must be < 1000ms"
  end
end
```

### L3.4: Intermodule Integration Tests

**File**: `test/indrajaal/integration/openrouter_intermodule_test.exs`

| Integration | Modules | Test Scenario |
|-------------|---------|---------------|
| Synapse ↔ OpenRouter | Cortex, AI | Request routing and response parsing |
| OpenRouter ↔ Zenoh | AI, Observability | Telemetry publication |
| OpenRouter ↔ Guardian | AI, Safety | Proposal validation |
| OpenRouter ↔ CEPAF | AI, Bridge | F# event recording |
| Synapse ↔ LocalModel | Cortex, AI | Context triage |
| GDE ↔ OpenRouter | Evolution, AI | Hypothesis generation |

**Test Pattern**:
```elixir
describe "Synapse ↔ OpenRouter Integration" do
  test "solve/3 delegates to OpenRouterClient.chat/2" do
    context = %{error: "undefined function", file: "lib/foo.ex"}

    # Mock OpenRouter response
    expect(HTTPMock, :request, fn req ->
      assert req.url =~ "openrouter.ai"
      {:ok, %{status: 200, body: mock_ai_response()}}
    end)

    assert {:ok, %{solution: solution}} = Synapse.solve(context, :error_fix)
    assert is_binary(solution)
  end
end

describe "OpenRouter ↔ Zenoh Integration" do
  test "successful call publishes telemetry" do
    # Subscribe to Zenoh channel
    {:ok, _sub} = ZenohCoordinator.subscribe("indrajaal/evolution/openrouter/calls")

    # Trigger OpenRouter call
    OpenRouterClient.chat([%{role: "user", content: "test"}])

    # Verify telemetry received
    assert_receive {:zenoh_message, %{
      "model" => _,
      "token_count" => _,
      "success" => true
    }}, 5000
  end
end
```

### L3.5: Critical E2E DAG Flow Tests

**File**: `test/indrajaal/e2e/openrouter_dag_flow_test.exs`

#### DAG 1: OODA Cybernetic Loop

```
[System Stress] → [Observe] → [Orient] → [Decide] → [Act] → [Verify]
                      │            │          │         │
                      ▼            ▼          ▼         ▼
               TelemetrySense  Synapse   Guardian    GDE
                      │            │          │         │
                      ▼            ▼          ▼         ▼
               Metrics→AI    OpenRouter  Validate  Execute
```

**Test**:
```elixir
@tag :e2e
test "complete OODA loop with AI-driven decision" do
  # 1. OBSERVE: Inject stress signal
  :telemetry.execute([:indrajaal, :system, :stress], %{level: :high}, %{})

  # 2. ORIENT: Cortex analyzes with AI
  expect(HTTPMock, :request, fn _ ->
    {:ok, ai_response("Scale connection pool from 10 to 20")}
  end)

  # 3. DECIDE: Guardian validates
  expect(Guardian, :validate, fn proposal ->
    assert proposal.confidence >= 0.6
    {:ok, :approved}
  end)

  # 4. ACT: GDE executes
  expect(GDE, :execute, fn action ->
    assert action.type == :scale_pool
    {:ok, %{pool_size: 20}}
  end)

  # 5. VERIFY: Check state
  assert {:ok, state} = Cortex.get_state()
  assert state.pool_size == 20

  # Verify telemetry trail
  assert_receive {:zenoh, "indrajaal/evolution/gde/proposals", _}, 5000
  assert_receive {:zenoh, "indrajaal/evolution/gde/validations", _}, 5000
end
```

#### DAG 2: GDE Evolution Pipeline

```
[Hypothesis Gen] → [Simulation] → [Selection] → [Execution] → [Verification]
        │               │              │             │              │
        ▼               ▼              ▼             ▼              ▼
   OpenRouter      ShadowMode     Confidence      AEE Tool      State Check
```

**Test**:
```elixir
@tag :e2e
test "GDE evolution pipeline with AI hypotheses" do
  # 1. Generate hypotheses via AI
  hypotheses = GDE.generate_hypotheses(:optimize_performance)
  assert length(hypotheses) >= 3

  # 2. Simulate each (shadow mode)
  simulations = Enum.map(hypotheses, &GDE.simulate/1)
  assert Enum.all?(simulations, &match?({:ok, _}, &1))

  # 3. Select best (highest confidence)
  {:ok, best} = GDE.select_best(simulations)
  assert best.confidence >= 0.6

  # 4. Execute via AEE
  {:ok, result} = GDE.execute(best)
  assert result.status == :applied

  # 5. Verify state transition
  {:ok, new_state} = Cortex.get_state()
  assert new_state.version > state.version
end
```

#### DAG 3: Error Recovery Flow

```
[AI Call Fails] → [Circuit Breaker] → [Fallback] → [Degraded Mode] → [Recovery]
       │                 │                │              │               │
       ▼                 ▼                ▼              ▼               ▼
   Timeout/Error     Open CB         LocalModel      Limited Ops     Reset CB
```

**Test**:
```elixir
@tag :e2e
test "graceful degradation when OpenRouter unavailable" do
  # 1. Cause OpenRouter failure
  expect(HTTPMock, :request, fn _ ->
    {:error, :timeout}
  end)

  # 2. Circuit breaker should open
  {:error, :timeout} = OpenRouterClient.chat([msg()])
  assert CircuitBreaker.status(:openrouter) == :open

  # 3. Fallback to local model
  {:ok, result} = Synapse.solve(context, :error_fix)
  assert result.source == :local_model

  # 4. System operates in degraded mode
  assert Cortex.mode() == :degraded

  # 5. Recovery after cooldown
  Process.sleep(5000)
  expect(HTTPMock, :request, fn _ -> {:ok, success_response()} end)

  {:ok, _} = OpenRouterClient.chat([msg()])
  assert CircuitBreaker.status(:openrouter) == :closed
  assert Cortex.mode() == :normal
end
```

---

## L4: Test Execution Matrix

### L4.1: Test File Structure

```
test/
├── indrajaal/
│   ├── ai/
│   │   ├── open_router_client_test.exs      # Unit tests
│   │   ├── open_router_property_test.exs    # TDG property tests
│   │   ├── open_router_stamp_test.exs       # STAMP constraint tests
│   │   └── open_router_aor_test.exs         # AOR compliance tests
│   ├── integration/
│   │   ├── cepaf_openrouter_test.exs        # Existing CEPAF integration
│   │   └── openrouter_intermodule_test.exs  # New intermodule tests
│   └── e2e/
│       └── openrouter_dag_flow_test.exs     # Critical DAG flows
```

### L4.2: Execution Commands

```bash
# Run all OpenRouter tests
POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres \
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
NO_TIMEOUT=true PATIENT_MODE=enabled MIX_ENV=test \
mix test test/indrajaal/ai/open_router* test/indrajaal/integration/*openrouter* test/indrajaal/e2e/*openrouter* --trace

# Run by category
mix test --only property      # TDG property tests
mix test --only stamp         # STAMP constraint tests
mix test --only aor           # AOR compliance tests
mix test --only integration   # Intermodule tests
mix test --only e2e           # E2E DAG flows

# With coverage
mix test --cover test/indrajaal/ai/open_router* test/indrajaal/integration/*openrouter*
```

### L4.3: Expected Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Line Coverage | >= 95% | `mix test --cover` |
| Property Tests | 8 properties | PropCheck + StreamData |
| STAMP Constraints | 7 verified | Explicit assertions |
| AOR Rules | 6 verified | Explicit assertions |
| Intermodule Pairs | 6 tested | Integration tests |
| E2E DAGs | 3 flows | System tests |
| Total Test Count | >= 50 | ExUnit count |

---

## L5: Implementation Details

### L5.1: Mock Setup

```elixir
# test/support/mocks.ex
Mox.defmock(HTTPMock, for: Indrajaal.HTTP.Behaviour)
Mox.defmock(ZenohMock, for: Indrajaal.Zenoh.Behaviour)
Mox.defmock(GuardianMock, for: Indrajaal.Safety.GuardianBehaviour)

# test/test_helper.exs
Application.put_env(:indrajaal, :http_client, HTTPMock)
```

### L5.2: Fixture Data

```elixir
# test/support/fixtures/openrouter_fixtures.ex
defmodule Indrajaal.Test.OpenRouterFixtures do
  def valid_chat_response do
    %{
      "id" => "gen-#{System.unique_integer()}",
      "choices" => [
        %{
          "message" => %{
            "role" => "assistant",
            "content" => "Here is the solution..."
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 150,
        "completion_tokens" => 200,
        "total_tokens" => 350
      }
    }
  end

  def rate_limit_response do
    %{
      "error" => %{
        "message" => "Rate limit exceeded",
        "type" => "rate_limit_error"
      }
    }
  end

  def forbidden_operation_proposal do
    %{
      action: "rm -rf /var/lib/postgresql",
      confidence: 0.95,
      reasoning: "Clean up disk space"
    }
  end
end
```

### L5.3: Test Helpers

```elixir
# test/support/openrouter_test_helpers.ex
defmodule Indrajaal.Test.OpenRouterHelpers do
  import Mox

  def setup_successful_openrouter(_context) do
    expect(HTTPMock, :request, fn _ ->
      {:ok, %{status: 200, body: OpenRouterFixtures.valid_chat_response()}}
    end)
    :ok
  end

  def setup_failing_openrouter(_context) do
    expect(HTTPMock, :request, fn _ ->
      {:error, :timeout}
    end)
    :ok
  end

  def assert_zenoh_published(channel, timeout \\ 5000) do
    assert_receive {:zenoh_message, ^channel, _payload}, timeout
  end

  def msg(role \\ "user", content \\ "Hello") do
    %{role: role, content: content}
  end
end
```

---

## L6: Graph Verification Testing

This section defines the mathematical verification framework for testing graph-structured data and relationships within the OpenRouter integration and broader Indrajaal system.

### L6.1: Graph Verification Language Mapping

| Goal | Mathematical Language | Tool | Use Case |
|------|----------------------|------|----------|
| **Create/Evolve** | Graph Grammars | Category Theory (Pushouts) | Defining legal agent spawning, container linking |
| **Verify Structure** | Alloy/Relational Logic | **Quint** | Finding edge-cases in supervision graphs |
| **Verify Attributes** | SHACL/Description Logic | **Ash Validations** | Ensuring resources have correct data types |
| **Prove Properties** | MSO Logic | **Agda** | Proving connectivity, acyclicity |
| **Verify at Scale** | GraphBLAS/Linear Algebra | **Nx Tensors** | High-performance reachability checks |

### L6.2: Graph Grammar Tests (Evolution Rules)

**Purpose**: Verify that graph transformations (agent spawning, container linking) follow legal production rules.

```elixir
# test/indrajaal/graph/grammar_test.exs
defmodule Indrajaal.Graph.GrammarTest do
  use ExUnit.Case, async: true

  describe "Production Rule: Agent Spawning" do
    test "spawning agent adds supervised_by edge" do
      supervisor = %{id: "sup-1", type: :supervisor}
      graph = Graph.new() |> Graph.add_vertex(supervisor)

      {:ok, graph'} = Graph.apply_rule(:spawn_agent, graph, %{
        supervisor: supervisor,
        agent: %{id: "agent-1", type: :worker}
      })

      assert Graph.has_edge?(graph', supervisor.id, "agent-1", :supervises)
    end

    test "NAC prevents duplicate supervision" do
      # Negative Application Condition: no duplicate edges
      graph = Graph.new()
        |> Graph.add_vertex(%{id: "sup-1"})
        |> Graph.add_vertex(%{id: "agent-1"})
        |> Graph.add_edge("sup-1", "agent-1", :supervises)

      assert {:error, :nac_violation} =
        Graph.apply_rule(:spawn_agent, graph, %{
          supervisor: %{id: "sup-1"},
          agent: %{id: "agent-1"}
        })
    end
  end
end
```

### L6.3: Quint Structural Verification Tests

**Purpose**: Use Alloy-style relational logic to find counter-examples in graph schemas.

**File**: `docs/formal_specs/quint/openrouter_integration.qnt`

```quint
// OpenRouter Integration Graph Model
module OpenRouterIntegration {
  type Component = str
  type Tier = Fast | Smart | Deep

  var components: Set[Component]
  var routes_to: Set[(Component, Component)]
  var tier_assignment: Component -> Tier

  // Invariant: Synapse must route through OpenRouter
  val synapse_routes_through_openrouter =
    components.contains("synapse") implies
    routes_to.contains(("synapse", "openrouter"))

  // Invariant: Guardian validates all proposals
  val guardian_validates_all =
    routes_to.filter(r => r._2 == "gde").forall(route =>
      routes_to.contains((route._1, "guardian"))
    )

  // Invariant: No direct AI calls bypassing OpenRouter
  val no_bypass =
    not(routes_to.exists(r =>
      r._1 == "synapse" and r._2.in(Set("claude", "gemini", "gpt"))
    ))

  // Run counter-example search
  run find_bypass_violation = {
    components' = Set("synapse", "openrouter", "claude", "gde")
    routes_to' = Set(("synapse", "claude"))  // Violation!
    assert(no_bypass)  // Should fail
  }
}
```

**Test Execution**:
```bash
# Verify Quint model
quint run docs/formal_specs/quint/openrouter_integration.qnt --invariant=no_bypass

# Expected output:
# [violation] no_bypass
# Counter-example: routes_to = {("synapse", "claude")}
```

### L6.4: SHACL-Style Attribute Validation (Ash Integration)

**Purpose**: Validate that all OpenRouter-related resources have correct attribute types and values.

```elixir
# test/indrajaal/graph/shacl_validation_test.exs
defmodule Indrajaal.Graph.SHACLValidationTest do
  use Indrajaal.DataCase

  describe "OpenRouterCall Shape Validation" do
    test "tier must be :fast, :smart, or :deep" do
      changeset = OpenRouterCall.changeset(%OpenRouterCall{}, %{
        tier: :invalid_tier,
        model: "anthropic/claude-3-haiku",
        token_count: 100
      })

      assert {:error, changeset} = Ash.create(changeset)
      assert "is invalid" in errors_on(changeset).tier
    end

    test "token_count must be positive" do
      changeset = OpenRouterCall.changeset(%OpenRouterCall{}, %{
        tier: :fast,
        model: "anthropic/claude-3-haiku",
        token_count: -5
      })

      assert {:error, changeset} = Ash.create(changeset)
      assert "must be greater than 0" in errors_on(changeset).token_count
    end

    test "model must be valid OpenRouter model ID" do
      changeset = OpenRouterCall.changeset(%OpenRouterCall{}, %{
        tier: :smart,
        model: "invalid/model-name",
        token_count: 100
      })

      assert {:error, changeset} = Ash.create(changeset)
      assert "not a recognized OpenRouter model" in errors_on(changeset).model
    end
  end
end
```

### L6.5: MSO Logic Proofs (Agda Integration)

**Purpose**: Formally prove graph properties that are critical for safety.

**File**: `docs/formal_specs/agda/OpenRouterGraphProofs.agda`

```agda
module OpenRouterGraphProofs where

open import Data.Nat
open import Data.Bool
open import Relation.Binary.PropositionalEquality

-- Define the OpenRouter routing graph
record RoutingGraph : Set₁ where
  field
    Node : Set
    routes_to : Node → Node → Set

-- Theorem: All AI paths go through OpenRouter
module NoBypass where
  postulate
    synapse : Node
    openrouter : Node
    gde : Node

  -- Axiom: Synapse routes to OpenRouter
  postulate
    synapse-to-openrouter : routes_to synapse openrouter

  -- Theorem: No path from synapse to external AI bypassing OpenRouter
  no-bypass : ∀ (external : Node) →
              routes_to synapse external →
              external ≡ openrouter
  no-bypass external route = {!!}  -- Proof by contradiction

-- Theorem: Guardian validation is mandatory for all proposals
module GuardianMandatory where
  postulate
    guardian : Node

  validation-required : ∀ (proposal : Node) (execution : Node) →
                        routes_to proposal execution →
                        routes_to proposal guardian
  validation-required p e route = {!!}  -- Proof by policy invariant
```

### L6.6: GraphBLAS High-Performance Tests

**Purpose**: Verify graph properties at scale using matrix operations.

```elixir
# test/indrajaal/graph/graphblas_test.exs
defmodule Indrajaal.Graph.GraphBLASTest do
  use ExUnit.Case

  describe "Reachability via Matrix Operations" do
    test "synapse can reach gde through openrouter" do
      # Adjacency matrix: synapse(0), openrouter(1), guardian(2), gde(3)
      adjacency = Nx.tensor([
        [0, 1, 0, 0],  # synapse -> openrouter
        [0, 0, 1, 0],  # openrouter -> guardian
        [0, 0, 0, 1],  # guardian -> gde
        [0, 0, 0, 0]   # gde (terminal)
      ])

      # Compute transitive closure
      closure = Indrajaal.GraphVerification.GraphBLAS.transitive_closure(adjacency)

      # synapse (0) should reach gde (3)
      assert Nx.to_number(closure[0][3]) == 1
    end

    test "no cycles in routing graph" do
      adjacency = Nx.tensor([
        [0, 1, 0, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 1],
        [0, 0, 0, 0]
      ])

      refute Indrajaal.GraphVerification.GraphBLAS.has_cycle?(adjacency)
    end

    @tag :performance
    test "cycle detection completes in < 100ms for 1000 nodes" do
      # Generate random sparse graph
      adjacency = generate_sparse_adjacency(1000, 5000)

      {time_us, result} = :timer.tc(fn ->
        Indrajaal.GraphVerification.GraphBLAS.has_cycle?(adjacency)
      end)

      assert time_us < 100_000, "Cycle detection took #{time_us}μs, must be < 100ms"
      assert is_boolean(result)
    end
  end
end
```

### L6.7: Test Execution Commands

```bash
# Run all graph verification tests
mix test test/indrajaal/graph/ --trace

# Run Quint model checking
quint run docs/formal_specs/quint/openrouter_integration.qnt --invariant=all

# Verify Agda proofs
agda --check docs/formal_specs/agda/OpenRouterGraphProofs.agda

# Run GraphBLAS performance tests
mix test test/indrajaal/graph/graphblas_test.exs --only performance

# Full verification pipeline
./scripts/verification/run_graph_verification.sh
```

### L6.8: Graph Verification Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Grammar Rules Tested | 5 rules | Production rule coverage |
| Quint Invariants | 10 invariants | Model checking |
| SHACL Shapes | 100% resources | Attribute validation |
| Agda Proofs | 3 theorems | Type-checked proofs |
| GraphBLAS Performance | < 100ms | 1000-node graph |

### L6.9: STAMP Constraints for Graph Verification

| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-GVF-001 | Graph grammar rules verified in Quint | CI pipeline |
| SC-GVF-002 | All Ash resources have SHACL shapes | Compile-time |
| SC-GVF-003 | Supervision graph proven acyclic | Agda proof |
| SC-GVF-004 | Container network satisfies isolation | Quint invariant |
| SC-GVF-005 | GraphBLAS verification < 100ms | Performance test |

### L6.10: Related Documentation

- `docs/architecture/GRAPH_VERIFICATION_FRAMEWORK.md` - Full specification
- `docs/formal_specs/quint/` - Quint model files
- `docs/formal_specs/agda/` - Agda proof files
- `lib/indrajaal/graph_verification/` - Elixir implementation

---

## L7: Appendices

### A: STAMP Constraint Reference

| ID | Name | Description |
|----|------|-------------|
| SC-GDE-060 | OpenRouter Exclusivity | All AI work through OpenRouter gateway |
| SC-GDE-061 | Confidence Threshold | Proposals require >= 0.6 confidence |
| SC-NEURO-001 | Simplex Principle | AI outputs validated before execution |
| SC-NEURO-003 | Forbidden Operations | Block destructive shell commands |
| SC-CNT-009 | Podman Enforcement | Container ops via Podman only |
| SC-SEC-044 | Secret Protection | No API keys in AI prompts |
| SC-OBS-069 | Dual Logging | Terminal + SigNoz telemetry |

### B: Related Documentation

- `docs/architecture/OPENROUTER_OPTIMIZATION_STRATEGY.md`
- `docs/architecture/GRAPH_VERIFICATION_FRAMEWORK.md` - Graph verification mathematical specification
- `journal/2025-12/20251227-0130-cepaf-openrouter-integration-deep-dive.md`
- `docs/testing/formal-verification-test-strategy.md`
- `GEMINI.md` Section 5.0 (STAMP Constraints)

### C: Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-12-27 | Cybernetic Architect | Initial comprehensive test plan |
| 1.1.0 | 2025-12-27 | Cybernetic Architect | Added L6: Graph Verification Testing (Grammar, Quint, SHACL, MSO/Agda, GraphBLAS) |

---

## L8: Graph Scenario Generation Framework

This section defines the mathematical approach to **generating** graph test scenarios using the five verification languages, with focus on Mathematica for specification, Quint for behavioral model checking, and Agda for correctness proofs.

### L8.1: Scenario Generation Decision Matrix

| Scenario Type | Primary Tool | Math Foundation | Output |
|---------------|--------------|-----------------|--------|
| Valid graph evolution | Graph Grammars (Mathematica) | Category Theory | Legal state transitions |
| Boundary/edge cases | Alloy/Quint | Relational Logic | Counter-examples |
| Invalid attribute combos | SHACL generators | Description Logic | Rejection scenarios |
| Proven invariants | Agda | Dependent Types | Certified properties |
| Large-scale stress | GraphBLAS | Linear Algebra | Performance bounds |

### L8.2: Mathematica Graph Scenario Generators

**Purpose**: Define generative rules that produce valid and invalid graph configurations for testing.

**File**: `docs/formal_specs/mathematica/graph_scenario_generators.wl`

```mathematica
(* ============================================================ *)
(* GRAPH SCENARIO GENERATOR - OpenRouter Integration Testing    *)
(* Mathematica Specification for Test Case Generation           *)
(* ============================================================ *)

(* --- Type Definitions --- *)
Component := "synapse" | "openrouter" | "guardian" | "gde" | "cortex" | "cepaf" | "zenoh"
ExternalAI := "claude" | "gemini" | "gpt" | "llama"
Tier := "fast" | "smart" | "deep"
Confidence := Real /; 0 <= # <= 1 &
Operation := "scale_pool" | "adjust_cache" | "modify_config" | "shell_command"

(* --- Scenario 1: Valid Routing Graph Generation --- *)
GenerateValidRoutingGraph[] := Module[{G},
  G = Graph[{
    "cortex" -> "synapse",
    "synapse" -> "openrouter",
    "openrouter" -> "guardian",
    "guardian" -> "gde",
    "gde" -> "cepaf"
  }];

  (* Add telemetry edges to Zenoh *)
  G = EdgeAdd[G, {
    "cortex" -> "zenoh",
    "synapse" -> "zenoh",
    "openrouter" -> "zenoh",
    "guardian" -> "zenoh",
    "gde" -> "zenoh"
  }];

  (* Validate: No direct external AI connections *)
  Assert[Not[MemberQ[EdgeList[G], "synapse" -> #] & /@ ExternalAI]];

  G
]

(* --- Scenario 2: Invalid Bypass Scenario Generation --- *)
GenerateBypassScenario[externalAI_] := Module[{G},
  G = GenerateValidRoutingGraph[];

  (* Inject invalid direct route - THIS SHOULD FAIL VERIFICATION *)
  G = EdgeAdd[G, "synapse" -> externalAI];

  <|
    "Graph" -> G,
    "Violation" -> "SC-GDE-060",
    "Description" -> "Direct route to " <> externalAI <> " bypasses OpenRouter",
    "ExpectedResult" -> "REJECT"
  |>
]

(* --- Scenario 3: Proposal Confidence Scenarios --- *)
GenerateConfidenceScenarios[] := Module[{scenarios},
  scenarios = {
    (* Valid: High confidence *)
    <|"Confidence" -> 0.85, "Operation" -> "scale_pool", "Expected" -> "VALIDATE"|>,
    <|"Confidence" -> 0.75, "Operation" -> "adjust_cache", "Expected" -> "VALIDATE"|>,
    <|"Confidence" -> 0.60, "Operation" -> "modify_config", "Expected" -> "VALIDATE"|>,

    (* Invalid: Low confidence - SC-GDE-061 violation *)
    <|"Confidence" -> 0.59, "Operation" -> "scale_pool", "Expected" -> "REJECT"|>,
    <|"Confidence" -> 0.30, "Operation" -> "adjust_cache", "Expected" -> "REJECT"|>,
    <|"Confidence" -> 0.10, "Operation" -> "modify_config", "Expected" -> "REJECT"|>,

    (* Edge cases *)
    <|"Confidence" -> 0.60, "Operation" -> "scale_pool", "Expected" -> "VALIDATE"|>,  (* Exact threshold *)
    <|"Confidence" -> 0.599999, "Operation" -> "scale_pool", "Expected" -> "REJECT"|>  (* Just below *)
  };

  scenarios
]

(* --- Scenario 4: Forbidden Operation Scenarios --- *)
GenerateForbiddenOperationScenarios[] := Module[{},
  {
    <|"Command" -> "rm -rf /", "Pattern" -> "RmRf", "Expected" -> "VETO"|>,
    <|"Command" -> "DROP TABLE users;", "Pattern" -> "DropTable", "Expected" -> "VETO"|>,
    <|"Command" -> "chmod -R 777 /", "Pattern" -> "ChmodRecursive", "Expected" -> "VETO"|>,
    <|"Command" -> "kill -9 -1", "Pattern" -> "KillAll", "Expected" -> "VETO"|>,
    <|"Command" -> "mkfs.ext4 /dev/sda", "Pattern" -> "FormatDisk", "Expected" -> "VETO"|>,

    (* Valid operations for contrast *)
    <|"Command" -> "mix compile", "Pattern" -> "Safe", "Expected" -> "ALLOW"|>,
    <|"Command" -> "podman ps", "Pattern" -> "Safe", "Expected" -> "ALLOW"|>
  }
]

(* --- Scenario 5: Graph Grammar Production Rules --- *)
(* Double-Pushout (DPO) Graph Transformation *)

ProductionRule[name_, L_, K_, R_, NAC_] := <|
  "Name" -> name,
  "LHS" -> L,      (* Left-hand side - pattern to match *)
  "Glue" -> K,     (* Preserved elements *)
  "RHS" -> R,      (* Right-hand side - replacement *)
  "NAC" -> NAC     (* Negative application conditions *)
|>

(* Agent Spawn Rule *)
AgentSpawnRule := ProductionRule[
  "spawn_agent",
  Graph[{"supervisor"}],                                    (* L: Match supervisor *)
  Graph[{"supervisor"}],                                    (* K: Keep supervisor *)
  Graph[{"supervisor" -> "agent", "agent"}],               (* R: Add agent + edge *)
  {}                                                        (* NAC: None *)
]

(* Circuit Breaker Open Rule *)
CircuitBreakerOpenRule := ProductionRule[
  "open_circuit_breaker",
  Graph[{"component" -> "target"}],                         (* L: Active route *)
  Graph[{"component", "target"}],                           (* K: Keep nodes *)
  Graph[{"component", "target"}],                           (* R: Remove edge *)
  {Graph[{"component.circuit_breaker" -> "open"}]}         (* NAC: Already open *)
]

(* Apply Production Rule *)
ApplyRule[rule_, G_, match_] := Module[{D, result},
  (* Step 1: Verify NAC (Negative Application Conditions) *)
  If[AnyTrue[rule["NAC"], SubgraphQ[G, #] &],
    Return[<|"Status" -> "NAC_VIOLATED", "Graph" -> G|>]
  ];

  (* Step 2: Compute pushout complement D = G - (L - K) *)
  D = EdgeDelete[G, Complement[EdgeList[rule["LHS"]], EdgeList[rule["Glue"]]]];

  (* Step 3: Compute pushout G' = D + (R - K) *)
  result = EdgeAdd[D, Complement[EdgeList[rule["RHS"]], EdgeList[rule["Glue"]]]];

  <|"Status" -> "SUCCESS", "Graph" -> result|>
]

(* --- Scenario 6: Complete E2E Flow Generation --- *)
GenerateOODALoopScenario[] := Module[{},
  <|
    "Name" -> "OODA_Complete_Flow",
    "Steps" -> {
      <|"Phase" -> "OBSERVE", "Component" -> "cortex", "Action" -> "detect_stress"|>,
      <|"Phase" -> "ORIENT", "Component" -> "synapse", "Action" -> "analyze_with_ai",
        "Route" -> "synapse -> openrouter -> guardian"|>,
      <|"Phase" -> "DECIDE", "Component" -> "guardian", "Action" -> "validate_proposal",
        "Constraint" -> "SC-NEURO-001"|>,
      <|"Phase" -> "ACT", "Component" -> "gde", "Action" -> "execute_evolution"|>,
      <|"Phase" -> "VERIFY", "Component" -> "cortex", "Action" -> "confirm_state"|>
    },
    "Invariants" -> {"no_bypass", "simplex_principle", "confidence_threshold"},
    "ExpectedResult" -> "SUCCESS"
  |>
]

(* --- Scenario 7: Failure Recovery Flow --- *)
GenerateCircuitBreakerScenario[] := Module[{},
  <|
    "Name" -> "Circuit_Breaker_Recovery",
    "InitialState" -> <|"circuit_breakers" -> <|"openrouter" -> "closed"|>|>,
    "Steps" -> {
      <|"Event" -> "timeout", "Count" -> 3, "Component" -> "openrouter"|>,
      <|"Action" -> "open_circuit_breaker", "Component" -> "openrouter"|>,
      <|"Verify" -> "routes_removed", "From" -> "openrouter"|>,
      <|"Action" -> "fallback_to_local", "Component" -> "synapse"|>,
      <|"Wait" -> 5000, "Unit" -> "ms"|>,
      <|"Action" -> "close_circuit_breaker", "Component" -> "openrouter"|>,
      <|"Verify" -> "routes_restored", "From" -> "openrouter"|>
    },
    "Invariants" -> {"degraded_mode_safe", "eventual_recovery"},
    "ExpectedResult" -> "RECOVERED"
  |>
]

(* --- Export All Scenarios --- *)
ExportAllScenarios[] := Module[{all},
  all = <|
    "ValidRouting" -> GenerateValidRoutingGraph[],
    "BypassScenarios" -> (GenerateBypassScenario /@ ExternalAI),
    "ConfidenceScenarios" -> GenerateConfidenceScenarios[],
    "ForbiddenOps" -> GenerateForbiddenOperationScenarios[],
    "OODALoop" -> GenerateOODALoopScenario[],
    "CircuitBreaker" -> GenerateCircuitBreakerScenario[]
  |>;

  Export["graph_test_scenarios.json", all, "JSON"]
]
```

### L8.3: Quint Behavioral Scenario Generation

**Purpose**: Generate state machine transitions and find counter-examples automatically.

**File**: `docs/formal_specs/quint/scenario_generators.qnt`

```quint
// ============================================================
// QUINT SCENARIO GENERATOR - Runtime Behavior Verification
// Generates test scenarios via state space exploration
// ============================================================

module ScenarioGenerators {
  import OpenRouterIntegration.*

  //------------------------------------------------------------
  // SCENARIO TYPE 1: Valid Proposal Lifecycle
  //------------------------------------------------------------

  // Generate a complete valid proposal flow
  run scenario_valid_proposal_lifecycle = {
    init
    .then(submit_proposal(SYNAPSE, ScalePool, 80))
    .then(all {
      assert(pending_proposals.size() == 1),
      assert(pending_proposals.contains((SYNAPSE, ScalePool, 80)))
    })
    .then(validate_proposal(SYNAPSE, ScalePool, 80))
    .then(all {
      assert(validated_proposals.contains((SYNAPSE, ScalePool))),
      assert(pending_proposals.size() == 0)
    })
    .then(execute_proposal(SYNAPSE, ScalePool))
    .then(all {
      assert(execution_log.contains((SYNAPSE, ScalePool, true))),
      assert(validated_proposals.size() == 0),
      assert(all_invariants)  // All safety properties hold
    })
  }

  //------------------------------------------------------------
  // SCENARIO TYPE 2: Rejection Flows
  //------------------------------------------------------------

  // Low confidence rejection
  run scenario_low_confidence_rejection = {
    init
    .then(submit_proposal(SYNAPSE, AdjustCache, 30))  // Below threshold
    .then(reject_proposal(SYNAPSE, AdjustCache, 30))
    .then(all {
      assert(not(validated_proposals.contains((SYNAPSE, AdjustCache)))),
      assert(pending_proposals.size() == 0),
      assert(all_invariants)
    })
  }

  // Forbidden operation rejection
  run scenario_forbidden_operation_rejection = {
    init
    .then(submit_proposal(SYNAPSE, ShellCommand, 95))  // High confidence but forbidden
    .then(reject_proposal(SYNAPSE, ShellCommand, 95))
    .then(all {
      assert(not(validated_proposals.contains((SYNAPSE, ShellCommand)))),
      assert(forbidden_detected.size() > 0),
      assert(all_invariants)
    })
  }

  //------------------------------------------------------------
  // SCENARIO TYPE 3: Boundary Condition Testing
  //------------------------------------------------------------

  // Exact threshold boundary
  run scenario_exact_threshold = {
    init
    .then(submit_proposal(CORTEX, ModifyConfig, 60))  // Exactly at threshold
    .then(validate_proposal(CORTEX, ModifyConfig, 60))
    .then(assert(validated_proposals.contains((CORTEX, ModifyConfig))))
  }

  // Just below threshold
  run scenario_just_below_threshold = {
    init
    .then(submit_proposal(CORTEX, ModifyConfig, 59))  // Just below
    .then(reject_proposal(CORTEX, ModifyConfig, 59))
    .then(assert(not(validated_proposals.contains((CORTEX, ModifyConfig)))))
  }

  //------------------------------------------------------------
  // SCENARIO TYPE 4: Circuit Breaker State Machine
  //------------------------------------------------------------

  run scenario_circuit_breaker_full_cycle = {
    init
    // Normal operation
    .then(assert(circuit_breakers.get(OPENROUTER) == false))
    // Failure triggers open
    .then(open_circuit_breaker(OPENROUTER))
    .then(all {
      assert(circuit_breakers.get(OPENROUTER) == true),
      // Routes should be removed
      assert(not(routes_to.exists(r => r._1 == OPENROUTER)))
    })
    // Recovery closes
    .then(close_circuit_breaker(OPENROUTER))
    .then(assert(circuit_breakers.get(OPENROUTER) == false))
  }

  //------------------------------------------------------------
  // SCENARIO TYPE 5: Concurrent Proposal Handling
  //------------------------------------------------------------

  run scenario_concurrent_proposals = {
    init
    // Multiple proposals submitted
    .then(submit_proposal(SYNAPSE, ScalePool, 75))
    .then(submit_proposal(CORTEX, AdjustCache, 80))
    .then(submit_proposal(GDE, ModifyConfig, 70))
    .then(all {
      assert(pending_proposals.size() == 3),
      assert(all_invariants)
    })
    // Process in order
    .then(validate_proposal(CORTEX, AdjustCache, 80))
    .then(validate_proposal(SYNAPSE, ScalePool, 75))
    .then(validate_proposal(GDE, ModifyConfig, 70))
    .then(assert(validated_proposals.size() == 3))
  }

  //------------------------------------------------------------
  // SCENARIO TYPE 6: Invariant Violation Detection
  //------------------------------------------------------------

  // These scenarios SHOULD find violations (negative tests)

  run scenario_find_bypass_violation = {
    init
    // Inject direct route to Claude (violation)
    routes_to' = routes_to.union(Set((SYNAPSE, CLAUDE)))
    components' = components.union(Set(CLAUDE))
    tier_assignment' = tier_assignment
    pending_proposals' = pending_proposals
    validated_proposals' = validated_proposals
    execution_log' = execution_log
    circuit_breakers' = circuit_breakers
    forbidden_detected' = forbidden_detected
    // This MUST fail
    assert(inv_openrouter_exclusivity)  // Expected: VIOLATION
  }

  run scenario_find_simplex_violation = {
    init
    // Direct route from OpenRouter to GDE, bypassing Guardian
    routes_to' = routes_to
      .exclude(Set((OPENROUTER, GUARDIAN)))
      .union(Set((OPENROUTER, GDE)))
    components' = components
    tier_assignment' = tier_assignment
    pending_proposals' = pending_proposals
    validated_proposals' = validated_proposals
    execution_log' = execution_log
    circuit_breakers' = circuit_breakers
    forbidden_detected' = forbidden_detected
    // This MUST fail
    assert(inv_simplex_principle)  // Expected: VIOLATION
  }

  //------------------------------------------------------------
  // SCENARIO TYPE 7: State Space Exploration
  //------------------------------------------------------------

  // Random walk to find edge cases
  run scenario_random_exploration = {
    init
    .then(step)
    .then(step)
    .then(step)
    .then(step)
    .then(step)
    .then(assert(all_invariants))  // Must hold after any 5 steps
  }

  // Exhaustive bounded exploration
  run scenario_bounded_model_check = {
    init
    .then(10.reps(_ => step))  // 10 random steps
    .then(assert(all_invariants))
  }

  //------------------------------------------------------------
  // SCENARIO GENERATION HELPERS
  //------------------------------------------------------------

  // Generate all confidence boundary scenarios
  val confidence_boundaries: Set[int] = Set(0, 30, 59, 60, 61, 75, 90, 100)

  // Generate all operation types
  val all_operations: Set[Operation] = Set(ScalePool, AdjustCache, ModifyConfig, ShellCommand)

  // Generate cross-product of scenarios
  val scenario_matrix = confidence_boundaries.flatMap(conf =>
    all_operations.map(op => (conf, op))
  )
}
```

### L8.4: Agda Correctness Proofs for Scenarios

**Purpose**: Formally prove that generated scenarios satisfy invariants.

**File**: `docs/formal_specs/agda/ScenarioCorrectness.agda`

```agda
-- ============================================================
-- AGDA SCENARIO CORRECTNESS PROOFS
-- Certifiable proofs for graph scenario invariants
-- ============================================================

module ScenarioCorrectness where

open import Data.Nat using (ℕ; zero; suc; _+_; _≤_; _<_)
open import Data.Bool using (Bool; true; false; _∧_; _∨_; not)
open import Data.List using (List; []; _∷_; length; all)
open import Data.Product using (_×_; _,_; proj₁; proj₂; Σ; ∃)
open import Data.Sum using (_⊎_; inj₁; inj₂)
open import Relation.Binary.PropositionalEquality using (_≡_; refl; sym; trans; cong)
open import Relation.Nullary using (¬_; Dec; yes; no)

-- ============================================================
-- BASIC TYPES
-- ============================================================

data Component : Set where
  synapse    : Component
  openrouter : Component
  guardian   : Component
  gde        : Component
  cortex     : Component
  cepaf      : Component
  zenoh      : Component

data ExternalAI : Set where
  claude : ExternalAI
  gemini : ExternalAI
  gpt    : ExternalAI

data Operation : Set where
  scale-pool    : Operation
  adjust-cache  : Operation
  modify-config : Operation
  shell-command : Operation

-- Confidence as natural number (0-100)
Confidence = ℕ

-- Threshold constant
MIN_CONFIDENCE : ℕ
MIN_CONFIDENCE = 60

-- ============================================================
-- GRAPH STRUCTURE
-- ============================================================

record Edge : Set where
  constructor _⟶_
  field
    source : Component
    target : Component

record Graph : Set where
  constructor mkGraph
  field
    edges : List Edge

-- Edge membership
data _∈_ : Edge → Graph → Set where
  here  : ∀ {e es} → e ∈ mkGraph (e ∷ es)
  there : ∀ {e e' es} → e ∈ mkGraph es → e ∈ mkGraph (e' ∷ es)

-- ============================================================
-- ROUTING INVARIANTS
-- ============================================================

-- INV-001: No direct route to external AI
record NoBypass (G : Graph) : Set where
  field
    no-claude : ¬ (synapse ⟶ claude) ∈ G
    no-gemini : ¬ (synapse ⟶ gemini) ∈ G
    no-gpt    : ¬ (synapse ⟶ gpt) ∈ G

-- INV-002: Synapse routes through OpenRouter
record SynapseRoutesOpenRouter (G : Graph) : Set where
  field
    route-exists : (synapse ⟶ openrouter) ∈ G

-- INV-003: Simplex Principle - Guardian in path to GDE
record SimplexPrinciple (G : Graph) : Set where
  field
    guardian-before-gde : (openrouter ⟶ guardian) ∈ G × (guardian ⟶ gde) ∈ G

-- ============================================================
-- PROPOSAL VALIDATION
-- ============================================================

data ValidationResult : Set where
  validated : ValidationResult
  rejected  : ValidationResult

-- Confidence threshold check
meets-threshold : Confidence → Bool
meets-threshold c with c Data.Nat.≤? MIN_CONFIDENCE
... | yes _ = false  -- Below threshold
... | no _  = true   -- Meets threshold

-- Forbidden operation check
is-forbidden : Operation → Bool
is-forbidden shell-command = true
is-forbidden _ = false

-- Combined validation
validate-proposal : Confidence → Operation → ValidationResult
validate-proposal c op with meets-threshold c | is-forbidden op
... | false | _     = rejected  -- Low confidence
... | _     | true  = rejected  -- Forbidden op
... | true  | false = validated

-- ============================================================
-- PROOFS
-- ============================================================

-- PROOF 1: Valid routing graph satisfies NoBypass
module ValidGraphProof where
  -- The valid routing graph
  valid-graph : Graph
  valid-graph = mkGraph (
    (cortex ⟶ synapse) ∷
    (synapse ⟶ openrouter) ∷
    (openrouter ⟶ guardian) ∷
    (guardian ⟶ gde) ∷
    (gde ⟶ cepaf) ∷
    [])

  -- Prove no Claude route exists
  no-claude-route : ¬ (synapse ⟶ claude) ∈ valid-graph
  no-claude-route (there (there (there (there (there ())))))

  -- Prove no Gemini route exists
  no-gemini-route : ¬ (synapse ⟶ gemini) ∈ valid-graph
  no-gemini-route (there (there (there (there (there ())))))

  -- Prove no GPT route exists
  no-gpt-route : ¬ (synapse ⟶ gpt) ∈ valid-graph
  no-gpt-route (there (there (there (there (there ())))))

  -- Combined proof
  valid-graph-no-bypass : NoBypass valid-graph
  valid-graph-no-bypass = record
    { no-claude = no-claude-route
    ; no-gemini = no-gemini-route
    ; no-gpt    = no-gpt-route
    }

-- PROOF 2: Confidence threshold is correctly enforced
module ConfidenceProof where
  -- Proposals at or above threshold are validated (if not forbidden)
  threshold-validated : ∀ (c : ℕ) → c ≥ MIN_CONFIDENCE →
                        validate-proposal c scale-pool ≡ validated
  threshold-validated c prf = {!!}  -- Proof by case analysis

  -- Proposals below threshold are rejected
  below-threshold-rejected : ∀ (c : ℕ) → c < MIN_CONFIDENCE →
                             validate-proposal c scale-pool ≡ rejected
  below-threshold-rejected c prf = {!!}  -- Proof by case analysis

  -- Exact threshold (60) is validated
  exact-threshold : validate-proposal 60 scale-pool ≡ validated
  exact-threshold = refl

  -- Just below threshold (59) is rejected
  below-exact-threshold : validate-proposal 59 scale-pool ≡ rejected
  below-exact-threshold = refl

-- PROOF 3: Forbidden operations always rejected
module ForbiddenProof where
  -- Shell commands rejected regardless of confidence
  shell-always-rejected : ∀ (c : ℕ) → validate-proposal c shell-command ≡ rejected
  shell-always-rejected c = refl

  -- Even 100% confidence doesn't bypass forbidden check
  max-confidence-forbidden : validate-proposal 100 shell-command ≡ rejected
  max-confidence-forbidden = refl

-- PROOF 4: Simplex Principle preservation
module SimplexProof where
  -- If Guardian is in the graph, Simplex holds
  simplex-preserved : ∀ (G : Graph) →
                      (openrouter ⟶ guardian) ∈ G →
                      (guardian ⟶ gde) ∈ G →
                      SimplexPrinciple G
  simplex-preserved G og-edge g-gde-edge = record
    { guardian-before-gde = (og-edge , g-gde-edge)
    }

-- PROOF 5: Graph grammar preserves invariants
module GrammarPreservation where
  -- Production rule application preserves NoBypass
  postulate
    spawn-preserves-no-bypass : ∀ (G G' : Graph) →
                                NoBypass G →
                                -- ApplySpawnRule G G' →
                                NoBypass G'

  -- Production rule application preserves Simplex
  postulate
    spawn-preserves-simplex : ∀ (G G' : Graph) →
                              SimplexPrinciple G →
                              -- ApplySpawnRule G G' →
                              SimplexPrinciple G'

-- ============================================================
-- SCENARIO CORRECTNESS THEOREMS
-- ============================================================

-- THEOREM 1: Valid proposal flow maintains all invariants
theorem-valid-flow : ∀ (G : Graph) (c : ℕ) (op : Operation) →
                     NoBypass G →
                     SimplexPrinciple G →
                     c ≥ MIN_CONFIDENCE →
                     is-forbidden op ≡ false →
                     validate-proposal c op ≡ validated
theorem-valid-flow G c op nb sp conf-ok not-forb = {!!}

-- THEOREM 2: Invalid bypass is always detectable
theorem-bypass-detectable : ∀ (G : Graph) →
                            (synapse ⟶ claude) ∈ G ⊎
                            (synapse ⟶ gemini) ∈ G ⊎
                            (synapse ⟶ gpt) ∈ G →
                            ¬ NoBypass G
theorem-bypass-detectable G (inj₁ has-claude) nb = NoBypass.no-claude nb has-claude
theorem-bypass-detectable G (inj₂ (inj₁ has-gemini)) nb = NoBypass.no-gemini nb has-gemini
theorem-bypass-detectable G (inj₂ (inj₂ has-gpt)) nb = NoBypass.no-gpt nb has-gpt

-- THEOREM 3: Forbidden operations never execute
theorem-forbidden-never-executes : ∀ (c : ℕ) →
                                   validate-proposal c shell-command ≡ rejected
theorem-forbidden-never-executes c = refl
```

### L8.5: GraphBLAS Scenario Performance Testing

**Purpose**: Generate large-scale graph scenarios for performance verification.

```elixir
# test/indrajaal/graph/scenario_performance_test.exs
defmodule Indrajaal.Graph.ScenarioPerformanceTest do
  use ExUnit.Case

  alias Indrajaal.GraphVerification.GraphBLAS

  describe "Large-Scale Scenario Generation" do
    @tag :performance
    test "generate and verify 1000-node routing graph" do
      # Generate scenario: 1000 components with complex routing
      graph = generate_large_routing_graph(1000, 5000)

      {time_us, result} = :timer.tc(fn ->
        GraphBLAS.verify_all_invariants(graph)
      end)

      assert result == :ok
      assert time_us < 100_000, "Verification took #{time_us}μs, must be < 100ms"
    end

    @tag :performance
    test "cycle detection in 10000-node supervision tree" do
      tree = generate_supervision_tree(10000)

      {time_us, has_cycle} = :timer.tc(fn ->
        GraphBLAS.has_cycle?(tree)
      end)

      refute has_cycle, "Supervision tree should be acyclic"
      assert time_us < 500_000, "Cycle detection took #{time_us}μs, must be < 500ms"
    end

    @tag :performance
    test "reachability matrix for container network" do
      network = generate_container_network(100, 500)

      {time_us, closure} = :timer.tc(fn ->
        GraphBLAS.transitive_closure(network)
      end)

      # Verify app can reach db
      assert Nx.to_number(closure[0][1]) == 1
      assert time_us < 50_000, "Transitive closure took #{time_us}μs, must be < 50ms"
    end
  end

  # Generators
  defp generate_large_routing_graph(nodes, edges) do
    adjacency = Nx.broadcast(0, {nodes, nodes})

    Enum.reduce(1..edges, adjacency, fn _, acc ->
      src = :rand.uniform(nodes) - 1
      dst = :rand.uniform(nodes) - 1
      if src != dst, do: Nx.put_slice(acc, [src, dst], Nx.tensor([[1]])), else: acc
    end)
  end

  defp generate_supervision_tree(nodes) do
    # Generate tree structure (acyclic by construction)
    adjacency = Nx.broadcast(0, {nodes, nodes})

    Enum.reduce(1..(nodes-1), adjacency, fn i, acc ->
      parent = :rand.uniform(i) - 1
      Nx.put_slice(acc, [parent, i], Nx.tensor([[1]]))
    end)
  end

  defp generate_container_network(containers, links) do
    adjacency = Nx.broadcast(0, {containers, containers})

    Enum.reduce(1..links, adjacency, fn _, acc ->
      src = :rand.uniform(containers) - 1
      dst = :rand.uniform(containers) - 1
      Nx.put_slice(acc, [src, dst], Nx.tensor([[1]]))
    end)
  end
end
```

### L8.6: Scenario Execution Commands

```bash
# Generate scenarios with Mathematica
wolframscript -file docs/formal_specs/mathematica/graph_scenario_generators.wl

# Run Quint scenario verification
quint run docs/formal_specs/quint/scenario_generators.qnt --run=scenario_valid_proposal_lifecycle
quint run docs/formal_specs/quint/scenario_generators.qnt --run=scenario_find_bypass_violation

# Verify Agda proofs
agda --check docs/formal_specs/agda/ScenarioCorrectness.agda

# Run performance scenarios
mix test test/indrajaal/graph/scenario_performance_test.exs --only performance

# Full scenario suite
./scripts/verification/run_all_scenarios.sh
```

### L8.7: Scenario Coverage Matrix

| Scenario Category | Count | Mathematica | Quint | Agda | GraphBLAS |
|-------------------|-------|-------------|-------|------|-----------|
| Valid Routing | 5 | ✓ | ✓ | ✓ | - |
| Bypass Violations | 3 | ✓ | ✓ | ✓ | - |
| Confidence Boundaries | 8 | ✓ | ✓ | ✓ | - |
| Forbidden Operations | 7 | ✓ | ✓ | ✓ | - |
| Circuit Breaker | 4 | ✓ | ✓ | - | - |
| OODA Loop E2E | 1 | ✓ | ✓ | - | - |
| Performance (1K nodes) | 3 | - | - | - | ✓ |
| Performance (10K nodes) | 2 | - | - | - | ✓ |
| **Total** | **33** | 28 | 26 | 15 | 5 |

### L8.8: Revision History Update

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-12-27 | Cybernetic Architect | Initial comprehensive test plan |
| 1.1.0 | 2025-12-27 | Cybernetic Architect | Added L6: Graph Verification Testing |
| 1.2.0 | 2025-12-27 | Cybernetic Architect | Added L8: Graph Scenario Generation (Mathematica/Quint/Agda/GraphBLAS) |

---

*Generated by Cybernetic Architect - STAMP Compliant*
