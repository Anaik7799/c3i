# Unified AI Simplex Implementation Plan

**Document Control**

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Created | 2025-12-27 |
| Author | Cybernetic Architect |
| STAMP | SC-AI-*, SC-NEURO-*, SC-GUARD-*, SC-GVF-* |
| Status | SPECIFICATION |

---

## Executive Summary

This document provides a comprehensive 5-level implementation plan for the Unified AI Simplex Architecture in Indrajaal. All AI operations—from simple chat to complex GDE cycles—MUST flow through the Simplex pattern:

```
┌─────────────────────────────────────────────────────────────────┐
│ COMPLEX PLANE (AI/Cortex)                                       │
│ - Receives requests from MCP tools                              │
│ - Generates proposals for AI operations                         │
│ - Routes through ProviderDispatcher                             │
└────────────────────────────┬────────────────────────────────────┘
                             │ Proposal
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ DECISION MODULE (Guardian)                                      │
│ - Validates against Safety Envelope                             │
│ - Enforces budget constraints                                   │
│ - Returns {:ok, proposal} or {:veto, reason, fallback}          │
└────────────────────────────┬────────────────────────────────────┘
                             │ Approved
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ SAFETY PLANE                                                    │
│ - Envelope: Defines immutable constraints                       │
│ - DeadMansSwitch: Monitors heartbeat                            │
│ - Telemetry: Records all decisions                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## Level 1: Control Flow Architecture

### 1.1 Simplex Control Flow

Every AI operation follows this mandatory control flow:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           REQUEST ORIGIN                                │
│  MCP Tool │ LiveView │ REST API │ Phoenix Channel │ Internal Service   │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       ASH RESOURCE ACTION                               │
│  ChatResource │ AnalysisResource │ GDEResource │ SafetyResource        │
│                                                                         │
│  1. Validate input arguments (Ash validation)                           │
│  2. Build Guardian proposal from request                                │
│  3. Submit to Guardian for pre-flight check                             │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │ GuardianProposal
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    GUARDIAN DECISION MODULE                             │
│                                                                         │
│  validate_proposal/1:                                                   │
│  ├─ Check Safety Envelope constraints                                   │
│  ├─ Check budget limits (CostMonitor)                                   │
│  ├─ Check rate limits                                                   │
│  ├─ Check forbidden patterns in prompt                                  │
│  └─ Return {:ok, approved} | {:veto, reason, fallback}                  │
└───────────────────┬──────────────────────────┬──────────────────────────┘
                    │                          │
              {:ok, approved}            {:veto, reason}
                    │                          │
                    ▼                          ▼
┌───────────────────────────────┐  ┌───────────────────────────────────────┐
│    GRAPH VERIFICATION         │  │           FALLBACK PATH               │
│                               │  │                                       │
│  validate_routing_proposal/1: │  │  1. Log veto reason                   │
│  ├─ Source registered         │  │  2. Execute fallback action           │
│  ├─ Target reachable          │  │  3. Emit [:ai, :veto] telemetry       │
│  ├─ Confidence >= threshold   │  │  4. Return graceful degradation       │
│  └─ Guardian approved: true   │  │                                       │
└───────────────────┬───────────┘  └───────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    PROVIDER DISPATCHER                                  │
│                                                                         │
│  chat(provider, input, opts):                                           │
│  ├─ Resolve provider from input or intent                               │
│  ├─ Execute API call with routing headers                               │
│  ├─ Handle response or fallback to next provider                        │
│  └─ Record cost and emit telemetry                                      │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    RESPONSE PROCESSING                                  │
│                                                                         │
│  1. Parse provider response                                             │
│  2. Record usage (tokens, cost) to CostMonitor                          │
│  3. Emit telemetry to Zenoh                                             │
│  4. Stream to CEPAF F# bridge                                           │
│  5. Return result to caller                                             │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Guardian Proposal Structure

```elixir
@type guardian_proposal :: %{
  # Core Identity
  action: :ai_request | :analysis | :synthesis | :gde_cycle,
  source: atom(),       # :claude_interface | :gemini_interface | :synapse | :gde
  request_id: String.t(),
  timestamp: DateTime.t(),

  # AI Request Details
  intent: :analyze | :synthesize | :reason | :triage | :validate | nil,
  model: String.t(),    # OpenRouter model ID
  provider: atom(),     # :openrouter | :anthropic | :google | :ollama

  # Content (Sanitized)
  prompt_preview: String.t(),  # First 500 chars
  prompt_length: non_neg_integer(),
  temperature: float(),
  max_tokens: non_neg_integer() | nil,

  # Cost Estimation
  estimated_input_tokens: non_neg_integer(),
  estimated_output_tokens: non_neg_integer(),
  estimated_cost_usd: float(),

  # Actor Context
  actor_id: String.t() | nil,
  tenant_id: String.t() | nil
}
```

### 1.3 Control Flow Implementation

```elixir
defmodule Indrajaal.AI.SimplexController do
  @moduledoc """
  Central Simplex controller for all AI operations.

  STAMP Constraints:
  - SC-NEURO-001: All AI routes MUST pass through Guardian
  - SC-GUARD-001: Guardian MUST use Envelope for constraints
  - SC-AI-001: No AI call without Simplex validation

  Flow: Request → Guardian → Graph → Provider → Response
  """

  alias Indrajaal.Safety.Guardian
  alias Indrajaal.AI.{ProviderDispatcher, CostMonitor}
  alias Indrajaal.AI.GraphVerification

  require Logger

  @doc """
  Execute an AI operation through the full Simplex pipeline.

  Returns:
  - {:ok, result} on success
  - {:error, {:guardian_veto, reason, fallback}} on safety rejection
  - {:error, {:graph_failed, reason}} on verification failure
  - {:error, {:provider_failed, reason}} on API failure
  """
  @spec execute(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(request, opts \\ []) do
    request_id = generate_request_id()

    :telemetry.span([:ai, :simplex, :execute], %{request_id: request_id}, fn ->
      with {:ok, proposal} <- build_proposal(request, request_id, opts),
           {:ok, _approved} <- guardian_pre_flight(proposal),
           {:ok, _verified} <- graph_verification(proposal),
           {:ok, result} <- provider_dispatch(proposal, opts) do
        emit_success_telemetry(request_id, result)
        {{:ok, result}, %{request_id: request_id, status: :success}}
      else
        {:error, reason} = error ->
          emit_failure_telemetry(request_id, reason)
          {error, %{request_id: request_id, status: :failed, reason: reason}}
      end
    end)
  end

  # Step 1: Build Guardian proposal
  defp build_proposal(request, request_id, opts) do
    proposal = %{
      action: Map.get(request, :action, :ai_request),
      source: Map.get(request, :source, :unknown),
      request_id: request_id,
      timestamp: DateTime.utc_now(),
      intent: Map.get(request, :intent),
      model: resolve_model(request),
      provider: Map.get(request, :provider, :openrouter),
      prompt_preview: String.slice(request[:prompt] || "", 0..500),
      prompt_length: String.length(request[:prompt] || ""),
      temperature: Keyword.get(opts, :temperature, 0.7),
      max_tokens: Keyword.get(opts, :max_tokens),
      estimated_input_tokens: estimate_tokens(request[:prompt]),
      estimated_output_tokens: Keyword.get(opts, :max_tokens, 1000),
      estimated_cost_usd: estimate_cost(request),
      actor_id: Keyword.get(opts, :actor_id),
      tenant_id: Keyword.get(opts, :tenant_id)
    }

    {:ok, proposal}
  end

  # Step 2: Guardian pre-flight check
  defp guardian_pre_flight(proposal) do
    case Guardian.validate_proposal(proposal) do
      {:ok, approved} ->
        Logger.debug("[Simplex] Guardian approved: #{proposal.request_id}")
        {:ok, approved}

      {:veto, reason, fallback} ->
        Logger.warning("[Simplex] Guardian vetoed: #{inspect(reason)}")
        {:error, {:guardian_veto, reason, fallback}}
    end
  rescue
    error ->
      # Fail closed: deny if Guardian unavailable
      Logger.error("[Simplex] Guardian unavailable: #{inspect(error)}")
      {:error, {:guardian_unavailable, error}}
  end

  # Step 3: Graph verification
  defp graph_verification(proposal) do
    routing_proposal = %{
      source: proposal.source,
      target: proposal.provider,
      model: proposal.model,
      confidence: 1.0,
      guardian_approved: true
    }

    GraphVerification.validate_routing_proposal(routing_proposal)
  end

  # Step 4: Provider dispatch
  defp provider_dispatch(proposal, opts) do
    ProviderDispatcher.chat(proposal.provider, proposal, opts)
  end

  defp generate_request_id do
    "ai-#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp resolve_model(%{model: model}) when is_binary(model), do: model
  defp resolve_model(%{intent: intent}) when not is_nil(intent) do
    Indrajaal.AI.IntentRouter.select_model(intent)
  end
  defp resolve_model(_), do: "anthropic/claude-3.5-sonnet"

  defp estimate_tokens(nil), do: 0
  defp estimate_tokens(text), do: div(String.length(text), 4)

  defp estimate_cost(%{model: model, prompt: prompt}) do
    tokens = estimate_tokens(prompt)
    CostMonitor.estimate_cost(model, tokens, 1000)
  end
  defp estimate_cost(_), do: 0.0

  defp emit_success_telemetry(request_id, result) do
    :telemetry.execute([:ai, :simplex, :success], %{
      tokens: result[:usage][:total_tokens] || 0,
      cost: result[:cost] || 0.0
    }, %{request_id: request_id})
  end

  defp emit_failure_telemetry(request_id, reason) do
    :telemetry.execute([:ai, :simplex, :failure], %{}, %{
      request_id: request_id,
      reason: inspect(reason)
    })
  end
end
```

### 1.4 STAMP Constraints (Control Flow)

| ID | Constraint | Enforcement |
|----|------------|-------------|
| SC-NEURO-001 | All AI routes through Guardian | `guardian_pre_flight/1` mandatory |
| SC-NEURO-002 | No bypass of Simplex | All entry points use `SimplexController.execute/2` |
| SC-GUARD-001 | Guardian uses Envelope | `Guardian.validate_proposal/1` checks `Envelope.*` |
| SC-GUARD-002 | Fail closed on Guardian unavailable | `rescue` clause returns error |
| SC-GVF-001 | Graph verification after Guardian | `graph_verification/1` runs post-approval |
| SC-AI-001 | Request ID for all operations | `generate_request_id/0` creates unique ID |
| SC-AI-002 | Telemetry for all outcomes | `emit_*_telemetry/2` for success/failure |

---

## Level 2: Data Flow Architecture

### 2.1 Message Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DATA FLOW OVERVIEW                              │
└─────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────┐
                    │  USER REQUEST   │
                    │                 │
                    │ messages: [...]  │
                    │ intent: :analyze │
                    │ context: {...}  │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
  │ MCP Router  │    │ LiveView    │    │ REST API   │
  │             │    │ Action      │    │ Controller │
  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘
         │                   │                   │
         └───────────────────┼───────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  ASH RESOURCE   │
                    │                 │
                    │ ChatResource    │
                    │ AnalysisResource│
                    │ GDEResource     │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ SIMPLEX         │
                    │ CONTROLLER      │
                    │                 │
                    │ build_proposal  │
                    │ guardian_check  │
                    │ graph_verify    │
                    │ dispatch        │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
  │ OpenRouter  │    │ Anthropic   │    │ Google     │
  │ API         │    │ Direct API  │    │ Direct API │
  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘
         │                   │                   │
         └───────────────────┼───────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  RESPONSE       │
                    │  PROCESSING     │
                    │                 │
                    │ content: "..."  │
                    │ usage: {...}    │
                    │ cost: 0.0023    │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
  │ CostMonitor │    │ Zenoh       │    │ CEPAF       │
  │ (Budget)    │    │ Publisher   │    │ F# Bridge   │
  └─────────────┘    └─────────────┘    └─────────────┘
```

### 2.2 Provider Request/Response Structures

#### 2.2.1 OpenRouter Request

```elixir
@type openrouter_request :: %{
  model: String.t(),                    # "anthropic/claude-3.5-sonnet"
  messages: [%{role: String.t(), content: String.t()}],
  temperature: float(),
  max_tokens: non_neg_integer() | nil,
  stream: boolean(),

  # Provider Preferences (Routing)
  provider: %{
    order: [String.t()],                # ["anthropic", "openai"]
    allow_fallbacks: boolean(),
    require_parameters: boolean()
  },

  # Route Type (Suffix)
  route: :nitro | :floor | :free | nil
}
```

#### 2.2.2 Unified Response

```elixir
@type ai_response :: %{
  # Core Response
  id: String.t(),
  model: String.t(),
  content: String.t(),
  finish_reason: :stop | :length | :tool_calls,

  # Usage Metrics
  usage: %{
    prompt_tokens: non_neg_integer(),
    completion_tokens: non_neg_integer(),
    total_tokens: non_neg_integer()
  },

  # Cost Tracking
  cost: %{
    input_cost: float(),
    output_cost: float(),
    total_cost: float(),
    currency: :usd
  },

  # Metadata
  provider: atom(),
  latency_ms: non_neg_integer(),
  request_id: String.t(),
  timestamp: DateTime.t()
}
```

### 2.3 Telemetry Data Flow

```elixir
defmodule Indrajaal.AI.TelemetryFlow do
  @moduledoc """
  Telemetry data flow for AI operations.

  Streams to:
  1. :telemetry (Erlang) → OTEL → SigNoz
  2. Zenoh → Distributed mesh
  3. CEPAF F# Bridge → Fractal logging
  """

  @spec emit_ai_event(atom(), map(), map()) :: :ok
  def emit_ai_event(event_name, measurements, metadata) do
    # 1. Erlang telemetry (synchronous)
    :telemetry.execute([:ai | event_name], measurements, metadata)

    # 2. Zenoh streaming (async)
    spawn(fn ->
      Indrajaal.Observability.ZenohEvolutionPublisher.publish_ai_event(%{
        event: event_name,
        measurements: measurements,
        metadata: metadata,
        timestamp: DateTime.utc_now()
      })
    end)

    # 3. CEPAF bridge (async)
    spawn(fn ->
      Indrajaal.Integration.CepafClient.send_telemetry(%{
        type: :ai_operation,
        event: event_name,
        data: Map.merge(measurements, metadata)
      })
    end)

    :ok
  end
end
```

### 2.4 Zenoh Key Expression Schema

```
indrajaal/
├── ai/
│   ├── requests/           # All AI requests
│   │   ├── {provider}/     # openrouter, anthropic, google
│   │   │   ├── {intent}/   # analyze, synthesize, reason
│   │   │   │   └── {model} # claude-3.5-sonnet, gemini-pro
│   │   │   └── *
│   │   └── *
│   ├── responses/          # All AI responses
│   │   └── {request_id}
│   ├── costs/              # Cost tracking
│   │   ├── daily/
│   │   ├── monthly/
│   │   └── by_model/
│   ├── vetoes/             # Guardian rejections
│   │   └── {reason}
│   └── evolution/          # TrainingGym events
│       ├── success/
│       ├── near_miss/
│       └── shadow_diverge/
```

### 2.5 CEPAF F# Integration

```fsharp
// Domain.fs - TelemetryEvent types for AI operations
type AITelemetryEvent =
    | AIRequest of
        requestId: string *
        provider: string *
        model: string *
        intent: string option *
        estimatedCost: float
    | AIResponse of
        requestId: string *
        provider: string *
        model: string *
        tokens: int64 *
        actualCost: float *
        latencyMs: int64
    | AIVeto of
        requestId: string *
        reason: string *
        fallbackUsed: bool
    | AIBudgetAlert of
        alertType: string *
        currentUsage: float *
        limit: float *
        period: string
    | AIEvolution of
        episodeType: string *
        modelA: string *
        modelB: string option *
        outcome: string
```

### 2.6 STAMP Constraints (Data Flow)

| ID | Constraint | Enforcement |
|----|------------|-------------|
| SC-DF-001 | All requests get unique ID | `generate_request_id/0` |
| SC-DF-002 | Response includes usage metrics | Provider parsers extract usage |
| SC-DF-003 | Cost calculated for all responses | `CostMonitor.record_usage/3` |
| SC-DF-004 | Telemetry emitted for all events | `TelemetryFlow.emit_ai_event/3` |
| SC-DF-005 | Zenoh streaming async | `spawn/1` for non-blocking |
| SC-DF-006 | CEPAF receives all AI events | `CepafClient.send_telemetry/1` |
| SC-DF-007 | Key expressions follow schema | Zenoh subscriber validation |

---

## Level 3: Commercial Aspects

### 3.1 Model Selection Matrix

| Intent | Default Model | Fallback 1 | Fallback 2 | Cost/1M tokens |
|--------|---------------|------------|------------|----------------|
| `:triage` | `google/gemini-flash-1.5-8b` | `openai/gpt-4o-mini` | Free tier | $0.075 |
| `:analyze` | `google/gemini-1.5-pro` | `anthropic/claude-3.5-sonnet` | - | $1.25 |
| `:synthesize` | `anthropic/claude-3.5-sonnet` | `openai/gpt-4o` | - | $3.00 |
| `:reason` | `openai/o1-preview` | `anthropic/claude-3-opus` | - | $15.00 |
| `:validate` | `anthropic/claude-3.5-sonnet` | `openai/gpt-4o` | - | $3.00 |
| `:code` | `anthropic/claude-3.5-sonnet` | `deepseek/deepseek-coder` | - | $3.00 |

### 3.2 Cost Optimization Strategies

```elixir
defmodule Indrajaal.AI.CostOptimizer do
  @moduledoc """
  Commercial optimization for AI model selection.

  Strategies:
  1. Intent-based routing (match task to cheapest capable model)
  2. Budget awareness (track and limit spending)
  3. Caching (reuse identical prompts)
  4. Batching (aggregate requests where possible)
  5. Free tier utilization (for low-stakes triage)
  """

  @daily_budget_usd Application.compile_env(:indrajaal, [:ai, :daily_budget], 50.0)
  @monthly_budget_usd Application.compile_env(:indrajaal, [:ai, :monthly_budget], 1000.0)

  @doc """
  Select optimal model based on intent, budget, and performance requirements.
  """
  @spec select_model(atom(), keyword()) :: {:ok, String.t()} | {:error, :budget_exceeded}
  def select_model(intent, opts \\ []) do
    with {:ok, remaining} <- check_budget(),
         {:ok, model} <- intent_to_model(intent, remaining, opts) do
      {:ok, model}
    end
  end

  defp check_budget do
    daily_used = CostMonitor.get_daily_usage()
    monthly_used = CostMonitor.get_monthly_usage()

    cond do
      monthly_used >= @monthly_budget_usd ->
        {:error, :monthly_budget_exceeded}

      daily_used >= @daily_budget_usd ->
        {:error, :daily_budget_exceeded}

      true ->
        remaining = min(@daily_budget_usd - daily_used, @monthly_budget_usd - monthly_used)
        {:ok, remaining}
    end
  end

  defp intent_to_model(:triage, remaining, _opts) when remaining < 0.01 do
    # Use free tier when budget is critically low
    {:ok, "meta-llama/llama-3.1-8b-instruct:free"}
  end

  defp intent_to_model(:triage, _remaining, _opts) do
    {:ok, "google/gemini-flash-1.5-8b"}
  end

  defp intent_to_model(:analyze, remaining, _opts) when remaining < 1.0 do
    # Downgrade to cheaper model
    {:ok, "google/gemini-flash-1.5"}
  end

  defp intent_to_model(:analyze, _remaining, _opts) do
    {:ok, "google/gemini-1.5-pro"}
  end

  defp intent_to_model(:synthesize, _remaining, _opts) do
    {:ok, "anthropic/claude-3.5-sonnet"}
  end

  defp intent_to_model(:reason, remaining, _opts) when remaining < 5.0 do
    # Downgrade from o1-preview
    {:ok, "anthropic/claude-3.5-sonnet"}
  end

  defp intent_to_model(:reason, _remaining, _opts) do
    {:ok, "openai/o1-preview"}
  end

  defp intent_to_model(:validate, _remaining, _opts) do
    {:ok, "anthropic/claude-3.5-sonnet"}
  end

  defp intent_to_model(:code, _remaining, _opts) do
    {:ok, "anthropic/claude-3.5-sonnet"}
  end

  defp intent_to_model(_unknown, _remaining, opts) do
    # Default to smart tier
    {:ok, Keyword.get(opts, :default_model, "anthropic/claude-3.5-sonnet")}
  end
end
```

### 3.3 Budget Enforcement

```elixir
defmodule Indrajaal.AI.CostMonitor do
  @moduledoc """
  Real-time cost monitoring and budget enforcement.

  STAMP Constraints:
  - SC-AI-004: Budget limits MUST be enforced before API calls
  - SC-AI-005: Rate limits MUST prevent API exhaustion
  - SC-AI-010: All costs MUST be recorded to Zenoh
  """

  use GenServer

  @daily_budget Application.compile_env(:indrajaal, [:ai, :daily_budget], 50.0)
  @monthly_budget Application.compile_env(:indrajaal, [:ai, :monthly_budget], 1000.0)
  @rate_limit_per_minute 100

  defstruct [
    daily_usage: 0.0,
    monthly_usage: 0.0,
    usage_by_model: %{},
    usage_by_source: %{},
    requests_this_minute: 0,
    last_minute_reset: nil
  ]

  # Client API

  @spec check_budget_and_rate(String.t(), float()) :: :ok | {:error, atom()}
  def check_budget_and_rate(model, estimated_cost) do
    GenServer.call(__MODULE__, {:check, model, estimated_cost})
  end

  @spec record_usage(String.t(), atom(), float()) :: :ok
  def record_usage(model, source, cost) do
    GenServer.cast(__MODULE__, {:record, model, source, cost})
  end

  @spec get_daily_usage() :: float()
  def get_daily_usage do
    GenServer.call(__MODULE__, :get_daily)
  end

  @spec get_monthly_usage() :: float()
  def get_monthly_usage do
    GenServer.call(__MODULE__, :get_monthly)
  end

  # Server Callbacks

  def handle_call({:check, _model, estimated_cost}, _from, state) do
    state = maybe_reset_minute(state)

    cond do
      state.daily_usage + estimated_cost > @daily_budget ->
        {:reply, {:error, :daily_budget_exceeded}, state}

      state.monthly_usage + estimated_cost > @monthly_budget ->
        {:reply, {:error, :monthly_budget_exceeded}, state}

      state.requests_this_minute >= @rate_limit_per_minute ->
        {:reply, {:error, :rate_limited}, state}

      true ->
        {:reply, :ok, %{state | requests_this_minute: state.requests_this_minute + 1}}
    end
  end

  def handle_cast({:record, model, source, cost}, state) do
    new_state = %{state |
      daily_usage: state.daily_usage + cost,
      monthly_usage: state.monthly_usage + cost,
      usage_by_model: Map.update(state.usage_by_model, model, cost, &(&1 + cost)),
      usage_by_source: Map.update(state.usage_by_source, source, cost, &(&1 + cost))
    }

    # Emit telemetry
    emit_cost_telemetry(model, source, cost, new_state)

    # Check budget alerts
    check_budget_alerts(new_state)

    {:noreply, new_state}
  end

  defp emit_cost_telemetry(model, source, cost, state) do
    :telemetry.execute([:ai, :cost, :recorded], %{
      cost: cost,
      daily_total: state.daily_usage,
      monthly_total: state.monthly_usage
    }, %{
      model: model,
      source: source
    })
  end

  defp check_budget_alerts(state) do
    daily_percent = state.daily_usage / @daily_budget * 100
    monthly_percent = state.monthly_usage / @monthly_budget * 100

    cond do
      daily_percent >= 90 ->
        emit_budget_alert(:daily_90_percent, state.daily_usage, @daily_budget)
      daily_percent >= 75 ->
        emit_budget_alert(:daily_75_percent, state.daily_usage, @daily_budget)
      monthly_percent >= 90 ->
        emit_budget_alert(:monthly_90_percent, state.monthly_usage, @monthly_budget)
      monthly_percent >= 75 ->
        emit_budget_alert(:monthly_75_percent, state.monthly_usage, @monthly_budget)
      true ->
        :ok
    end
  end

  defp emit_budget_alert(alert_type, current, limit) do
    Indrajaal.AI.TelemetryFlow.emit_ai_event(
      [:budget, :alert],
      %{current: current, limit: limit, percent: current / limit * 100},
      %{alert_type: alert_type}
    )
  end
end
```

### 3.4 Provider Pricing Table

```elixir
defmodule Indrajaal.AI.Pricing do
  @moduledoc """
  Real-time pricing data for cost estimation.
  Updated from OpenRouter /api/v1/models endpoint.
  """

  # Prices per 1M tokens (input/output)
  @static_pricing %{
    # Anthropic
    "anthropic/claude-3.5-sonnet" => {3.00, 15.00},
    "anthropic/claude-3-opus" => {15.00, 75.00},
    "anthropic/claude-3-haiku" => {0.25, 1.25},

    # OpenAI
    "openai/gpt-4o" => {2.50, 10.00},
    "openai/gpt-4o-mini" => {0.15, 0.60},
    "openai/o1-preview" => {15.00, 60.00},

    # Google
    "google/gemini-1.5-pro" => {1.25, 5.00},
    "google/gemini-flash-1.5" => {0.075, 0.30},
    "google/gemini-flash-1.5-8b" => {0.0375, 0.15},

    # Free tier
    "meta-llama/llama-3.1-8b-instruct:free" => {0.0, 0.0}
  }

  @spec estimate_cost(String.t(), non_neg_integer(), non_neg_integer()) :: float()
  def estimate_cost(model, input_tokens, output_tokens) do
    {input_price, output_price} = Map.get(@static_pricing, model, {1.0, 5.0})

    input_cost = input_tokens / 1_000_000 * input_price
    output_cost = output_tokens / 1_000_000 * output_price

    Float.round(input_cost + output_cost, 6)
  end
end
```

### 3.5 STAMP Constraints (Commercial)

| ID | Constraint | Enforcement |
|----|------------|-------------|
| SC-AI-004 | Budget enforced before API calls | `CostMonitor.check_budget_and_rate/2` |
| SC-AI-005 | Rate limits prevent exhaustion | Requests/minute counter |
| SC-AI-008 | Cost alerts at threshold | 75%/90% budget alerts |
| SC-AI-009 | Free tier for triage | `CostOptimizer.intent_to_model/3` |
| SC-AI-010 | All costs recorded to Zenoh | `emit_cost_telemetry/4` |
| SC-AI-011 | Monthly budget rollover | GenServer state reset |
| SC-AI-012 | Model downgrade on budget pressure | Conditional model selection |

---

## Level 4: Security Architecture

### 4.1 Security Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        SECURITY LAYERS                                  │
└─────────────────────────────────────────────────────────────────────────┘

Layer 1: INPUT VALIDATION
┌─────────────────────────────────────────────────────────────────────────┐
│ ✓ Ash argument validation                                               │
│ ✓ Schema type checking                                                  │
│ ✓ Size limits (prompt length, max_tokens)                               │
│ ✓ Rate limiting per actor/tenant                                        │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
Layer 2: CONTENT INSPECTION
┌─────────────────────────────────────────────────────────────────────────┐
│ ✓ Forbidden pattern detection                                           │
│   - Injection patterns (SQL, command, prompt)                           │
│   - PII detection (email, phone, SSN)                                   │
│   - Credential detection (API keys, passwords)                          │
│ ✓ Content classification                                                │
│ ✓ Prompt preview logging (500 chars)                                    │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
Layer 3: GUARDIAN PRE-FLIGHT
┌─────────────────────────────────────────────────────────────────────────┐
│ ✓ Safety Envelope constraints                                           │
│ ✓ Budget verification                                                   │
│ ✓ Actor authorization                                                   │
│ ✓ Tenant isolation                                                      │
│ ✓ Model access control                                                  │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
Layer 4: GRAPH VERIFICATION
┌─────────────────────────────────────────────────────────────────────────┐
│ ✓ Source node registered                                                │
│ ✓ Target reachable                                                      │
│ ✓ Route confidence >= 0.8                                               │
│ ✓ Guardian approval flag                                                │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
Layer 5: TRANSPORT SECURITY
┌─────────────────────────────────────────────────────────────────────────┐
│ ✓ TLS 1.3 to all providers                                              │
│ ✓ API key from vault (not env)                                          │
│ ✓ Request signing (where supported)                                     │
│ ✓ Response validation                                                   │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
Layer 6: RESPONSE SANITIZATION
┌─────────────────────────────────────────────────────────────────────────┐
│ ✓ Output size limits                                                    │
│ ✓ Dangerous content filtering                                           │
│ ✓ Code execution prevention                                             │
│ ✓ Audit logging                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Forbidden Pattern Detection

```elixir
defmodule Indrajaal.AI.Security.ContentInspector do
  @moduledoc """
  Inspects AI prompts and responses for security violations.

  STAMP Constraints:
  - SC-SEC-001: No unreviewed code execution
  - SC-SEC-044: Sobelow patterns applied to AI content
  - SC-SEC-047: Encryption for sensitive data
  """

  @forbidden_patterns [
    # Prompt Injection
    ~r/ignore\s+(all\s+)?(previous\s+)?instructions?/i,
    ~r/disregard\s+(all\s+)?(previous\s+)?instructions?/i,
    ~r/you\s+are\s+now\s+(a|an)\s+/i,
    ~r/pretend\s+(you\s+are|to\s+be)/i,
    ~r/\[system\]/i,
    ~r/<\|im_start\|>/i,

    # SQL Injection
    ~r/'\s*;\s*DROP\s+TABLE/i,
    ~r/UNION\s+SELECT/i,
    ~r/'\s*OR\s+'1'\s*=\s*'1/i,

    # Command Injection
    ~r/;\s*(rm|del|format|shutdown|reboot)\s/i,
    ~r/\|\s*(bash|sh|cmd|powershell)/i,
    ~r/`[^`]+`/,  # Backtick execution

    # Credential Patterns
    ~r/api[_-]?key\s*[=:]\s*[a-zA-Z0-9]{20,}/i,
    ~r/(password|passwd|pwd)\s*[=:]\s*[^\s]{8,}/i,
    ~r/bearer\s+[a-zA-Z0-9\-_.~+\/]+=*/i
  ]

  @pii_patterns [
    # Email
    ~r/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/,
    # Phone (various formats)
    ~r/\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/,
    # SSN
    ~r/\b\d{3}-\d{2}-\d{4}\b/,
    # Credit Card
    ~r/\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/
  ]

  @spec inspect_prompt(String.t()) :: {:ok, :clean} | {:error, {:forbidden, String.t()}}
  def inspect_prompt(prompt) do
    with :ok <- check_forbidden_patterns(prompt),
         :ok <- check_pii(prompt) do
      {:ok, :clean}
    end
  end

  @spec inspect_response(String.t()) :: {:ok, :clean} | {:warn, [String.t()]}
  def inspect_response(response) do
    warnings = []

    warnings = if contains_code_blocks?(response) do
      ["response contains code blocks" | warnings]
    else
      warnings
    end

    warnings = if contains_urls?(response) do
      ["response contains URLs" | warnings]
    else
      warnings
    end

    if Enum.empty?(warnings) do
      {:ok, :clean}
    else
      {:warn, warnings}
    end
  end

  defp check_forbidden_patterns(content) do
    Enum.find_value(@forbidden_patterns, :ok, fn pattern ->
      if Regex.match?(pattern, content) do
        {:error, {:forbidden, "matches pattern: #{inspect(pattern)}"}}
      end
    end)
  end

  defp check_pii(content) do
    pii_found = Enum.any?(@pii_patterns, &Regex.match?(&1, content))

    if pii_found do
      # Log warning but don't block (may be legitimate use case)
      Logger.warning("[ContentInspector] PII detected in prompt")
      :ok
    else
      :ok
    end
  end

  defp contains_code_blocks?(content) do
    String.contains?(content, "```")
  end

  defp contains_urls?(content) do
    Regex.match?(~r/https?:\/\/[^\s]+/, content)
  end
end
```

### 4.3 Two-Key Turn for High-Risk Operations

```elixir
defmodule Indrajaal.AI.Security.TwoKeyTurn do
  @moduledoc """
  Two-Key Turn authorization for high-risk AI operations.

  Requires both:
  1. Actor authorization (who is making the request)
  2. System authorization (Guardian approval)

  High-risk operations:
  - Model tier > :smart (expensive models)
  - Intent = :reason (complex reasoning)
  - Estimated cost > $1.00
  - Production environment
  """

  @high_risk_thresholds %{
    cost_usd: 1.00,
    tokens: 10_000,
    models: ["openai/o1-preview", "anthropic/claude-3-opus"]
  }

  @spec requires_two_key?(map()) :: boolean()
  def requires_two_key?(proposal) do
    cond do
      proposal.estimated_cost_usd > @high_risk_thresholds.cost_usd ->
        true

      proposal.model in @high_risk_thresholds.models ->
        true

      proposal.intent == :reason ->
        true

      Application.get_env(:indrajaal, :env) == :prod ->
        proposal.estimated_cost_usd > 0.50

      true ->
        false
    end
  end

  @spec authorize(map(), map()) :: {:ok, :authorized} | {:error, :unauthorized}
  def authorize(proposal, context) do
    with {:ok, :actor_authorized} <- check_actor_permission(proposal, context),
         {:ok, :system_authorized} <- check_system_permission(proposal) do
      {:ok, :authorized}
    end
  end

  defp check_actor_permission(proposal, context) do
    actor = context[:actor]

    cond do
      is_nil(actor) ->
        {:error, :no_actor}

      has_ai_permission?(actor, proposal.intent) ->
        {:ok, :actor_authorized}

      true ->
        {:error, :actor_not_authorized}
    end
  end

  defp check_system_permission(proposal) do
    # This is handled by Guardian, but we double-check here
    if proposal[:guardian_approved] do
      {:ok, :system_authorized}
    else
      {:error, :system_not_authorized}
    end
  end

  defp has_ai_permission?(actor, intent) do
    # Check actor's permissions for this intent
    permissions = Map.get(actor, :permissions, [])
    required = intent_to_permission(intent)
    required in permissions
  end

  defp intent_to_permission(:triage), do: :ai_basic
  defp intent_to_permission(:analyze), do: :ai_standard
  defp intent_to_permission(:synthesize), do: :ai_standard
  defp intent_to_permission(:validate), do: :ai_standard
  defp intent_to_permission(:reason), do: :ai_advanced
  defp intent_to_permission(_), do: :ai_basic
end
```

### 4.4 Audit Logging

```elixir
defmodule Indrajaal.AI.Security.AuditLog do
  @moduledoc """
  Comprehensive audit logging for all AI operations.

  GDPR/ISO 27001 compliant logging:
  - What: Operation type, intent, model
  - Who: Actor ID, tenant ID
  - When: Timestamp (UTC)
  - Outcome: Success/failure, reason
  - NOT logged: Full prompt content (privacy)
  """

  alias Indrajaal.Core.AuditLog, as: CoreAuditLog

  @spec log_request(map()) :: :ok
  def log_request(proposal) do
    CoreAuditLog.create(%{
      action: "ai_request",
      actor_id: proposal[:actor_id],
      tenant_id: proposal[:tenant_id],
      resource_type: "ai_operation",
      resource_id: proposal[:request_id],
      metadata: %{
        intent: proposal[:intent],
        model: proposal[:model],
        provider: proposal[:provider],
        estimated_cost: proposal[:estimated_cost_usd],
        prompt_length: proposal[:prompt_length]
      },
      timestamp: DateTime.utc_now()
    })
  end

  @spec log_response(String.t(), map()) :: :ok
  def log_response(request_id, response) do
    CoreAuditLog.create(%{
      action: "ai_response",
      resource_type: "ai_operation",
      resource_id: request_id,
      metadata: %{
        status: :success,
        model: response[:model],
        tokens: response[:usage][:total_tokens],
        cost: response[:cost][:total_cost],
        latency_ms: response[:latency_ms]
      },
      timestamp: DateTime.utc_now()
    })
  end

  @spec log_veto(String.t(), term(), term()) :: :ok
  def log_veto(request_id, reason, fallback) do
    CoreAuditLog.create(%{
      action: "ai_veto",
      resource_type: "ai_operation",
      resource_id: request_id,
      metadata: %{
        status: :vetoed,
        reason: inspect(reason),
        fallback_used: not is_nil(fallback)
      },
      timestamp: DateTime.utc_now()
    })
  end
end
```

### 4.5 STAMP Constraints (Security)

| ID | Constraint | Enforcement |
|----|------------|-------------|
| SC-SEC-001 | No unreviewed code execution | `ContentInspector.inspect_prompt/1` |
| SC-SEC-044 | Sobelow patterns for AI | Forbidden pattern regexes |
| SC-SEC-047 | Encryption for sensitive data | TLS 1.3 + vault for keys |
| SC-SEC-AI-001 | Two-Key Turn for high-risk | `TwoKeyTurn.requires_two_key?/1` |
| SC-SEC-AI-002 | Audit log for all operations | `AuditLog.log_*/1` |
| SC-SEC-AI-003 | No full prompt logging | Only `prompt_preview` in logs |
| SC-SEC-AI-004 | PII detection | Regex patterns + warning |
| SC-SEC-AI-005 | Response sanitization | `ContentInspector.inspect_response/1` |

---

## Level 5: LLM Operations

### 5.1 Intent-Based Routing Engine

```elixir
defmodule Indrajaal.AI.IntentRouter do
  @moduledoc """
  Routes AI requests based on intent to optimal model/provider combination.

  Intent Categories:
  - :triage - Quick classification, low cost
  - :analyze - Deep analysis, high accuracy
  - :synthesize - Content generation, creative
  - :reason - Complex reasoning, chain-of-thought
  - :validate - Verification, consistency checking
  - :code - Code generation/review

  Each intent maps to:
  - Optimal model (tier)
  - Routing strategy (:nitro, :floor, :free)
  - Provider preferences
  - Expected latency/cost
  """

  @intent_config %{
    triage: %{
      model: "google/gemini-flash-1.5-8b",
      route: :floor,  # Lowest cost
      providers: ["google", "meta-llama"],
      max_tokens: 500,
      temperature: 0.3
    },
    analyze: %{
      model: "google/gemini-1.5-pro",
      route: nil,  # Standard routing
      providers: ["google", "anthropic"],
      max_tokens: 4000,
      temperature: 0.5
    },
    synthesize: %{
      model: "anthropic/claude-3.5-sonnet",
      route: nil,
      providers: ["anthropic", "openai"],
      max_tokens: 4000,
      temperature: 0.7
    },
    reason: %{
      model: "openai/o1-preview",
      route: :nitro,  # Fastest routing
      providers: ["openai", "anthropic"],
      max_tokens: 8000,
      temperature: 1.0  # o1 requires temp=1
    },
    validate: %{
      model: "anthropic/claude-3.5-sonnet",
      route: nil,
      providers: ["anthropic", "openai"],
      max_tokens: 2000,
      temperature: 0.2
    },
    code: %{
      model: "anthropic/claude-3.5-sonnet",
      route: nil,
      providers: ["anthropic", "deepseek"],
      max_tokens: 8000,
      temperature: 0.3
    }
  }

  @spec route(atom(), keyword()) :: map()
  def route(intent, opts \\ []) do
    config = Map.get(@intent_config, intent, @intent_config[:synthesize])

    %{
      model: Keyword.get(opts, :model, config.model),
      route: Keyword.get(opts, :route, config.route),
      provider_preferences: build_provider_preferences(config, opts),
      max_tokens: Keyword.get(opts, :max_tokens, config.max_tokens),
      temperature: Keyword.get(opts, :temperature, config.temperature)
    }
  end

  @spec select_model(atom()) :: String.t()
  def select_model(intent) do
    config = Map.get(@intent_config, intent, @intent_config[:synthesize])
    config.model
  end

  defp build_provider_preferences(config, opts) do
    %{
      order: Keyword.get(opts, :providers, config.providers),
      allow_fallbacks: Keyword.get(opts, :allow_fallbacks, true),
      require_parameters: true
    }
  end
end
```

### 5.2 ShadowMode Evaluation

```elixir
defmodule Indrajaal.AI.Evolution.ShadowMode do
  @moduledoc """
  Shadow mode evaluation for comparing model outputs safely.

  How it works:
  1. Primary model handles the request normally
  2. Shadow model runs in parallel without actuator access
  3. Outputs are compared for divergence
  4. Results feed into TrainingGym

  Use cases:
  - Evaluating new models before production
  - A/B testing model configurations
  - Detecting model drift
  - Generating training data
  """

  alias Indrajaal.AI.{SimplexController, TelemetryFlow}
  alias Indrajaal.AI.Evolution.TrainingGym

  @doc """
  Execute primary request with optional shadow evaluation.
  """
  @spec execute_with_shadow(map(), keyword()) :: {:ok, map()}
  def execute_with_shadow(request, opts \\ []) do
    shadow_model = Keyword.get(opts, :shadow_model)

    # Primary execution (normal Simplex flow)
    primary_task = Task.async(fn ->
      SimplexController.execute(request, opts)
    end)

    # Shadow execution (if configured)
    shadow_task = if shadow_model do
      Task.async(fn ->
        shadow_request = %{request | model: shadow_model, is_shadow: true}
        SimplexController.execute(shadow_request, opts)
      end)
    end

    # Wait for primary result
    primary_result = Task.await(primary_task, 120_000)

    # Evaluate shadow if present
    if shadow_task do
      shadow_result = Task.await(shadow_task, 120_000)
      evaluate_divergence(request, primary_result, shadow_result, shadow_model)
    end

    primary_result
  end

  defp evaluate_divergence(request, {:ok, primary}, {:ok, shadow}, shadow_model) do
    divergence = calculate_divergence(primary, shadow)

    episode = %{
      type: if(divergence > 0.3, do: :shadow_diverge, else: :shadow_agree),
      primary_model: request.model,
      shadow_model: shadow_model,
      divergence_score: divergence,
      request_intent: request[:intent],
      timestamp: DateTime.utc_now()
    }

    # Record to TrainingGym
    TrainingGym.record_episode(episode)

    # Emit telemetry
    TelemetryFlow.emit_ai_event([:shadow, :evaluation], %{
      divergence: divergence
    }, %{
      primary_model: request.model,
      shadow_model: shadow_model,
      agreed: divergence <= 0.3
    })
  end

  defp evaluate_divergence(_request, _primary, {:error, _reason}, _shadow_model) do
    # Shadow failed, not a divergence event
    :ok
  end

  defp calculate_divergence(primary, shadow) do
    # Simple semantic similarity based on response length and key terms
    primary_content = primary[:content] || ""
    shadow_content = shadow[:content] || ""

    # Length ratio
    len_ratio = abs(String.length(primary_content) - String.length(shadow_content)) /
                max(String.length(primary_content), String.length(shadow_content))

    # Word overlap (Jaccard similarity)
    primary_words = String.split(primary_content) |> MapSet.new()
    shadow_words = String.split(shadow_content) |> MapSet.new()

    intersection = MapSet.intersection(primary_words, shadow_words) |> MapSet.size()
    union = MapSet.union(primary_words, shadow_words) |> MapSet.size()

    jaccard = if union > 0, do: 1.0 - (intersection / union), else: 1.0

    # Combined divergence score
    (len_ratio + jaccard) / 2.0
  end
end
```

### 5.3 TrainingGym Feedback Loop

```elixir
defmodule Indrajaal.AI.Evolution.TrainingGym do
  @moduledoc """
  Training gym for continuous improvement of AI routing.

  Episode Types:
  - :success - Request completed successfully
  - :near_miss - Almost failed, recovered gracefully
  - :shadow_diverge - Shadow model produced different output
  - :shadow_agree - Shadow model agreed with primary
  - :veto_override - Guardian veto was overridden
  - :budget_limit - Hit budget constraints

  Feedback Loop:
  1. Record episodes during operation
  2. Aggregate patterns
  3. Update intent routing weights
  4. Publish learnings to Zenoh
  """

  use GenServer

  alias Indrajaal.AI.TelemetryFlow

  defstruct [
    episodes: [],
    model_scores: %{},
    intent_success_rates: %{},
    last_learning_cycle: nil
  ]

  # Client API

  @spec record_episode(map()) :: :ok
  def record_episode(episode) do
    GenServer.cast(__MODULE__, {:record, episode})
  end

  @spec get_model_score(String.t()) :: float()
  def get_model_score(model) do
    GenServer.call(__MODULE__, {:get_score, model})
  end

  @spec trigger_learning_cycle() :: :ok
  def trigger_learning_cycle do
    GenServer.cast(__MODULE__, :learn)
  end

  # Server Callbacks

  def init(_) do
    # Schedule periodic learning cycles
    Process.send_after(self(), :periodic_learn, :timer.hours(1))
    {:ok, %__MODULE__{}}
  end

  def handle_cast({:record, episode}, state) do
    new_episodes = [episode | state.episodes] |> Enum.take(10_000)

    # Update running scores
    new_scores = update_model_scores(state.model_scores, episode)
    new_rates = update_success_rates(state.intent_success_rates, episode)

    # Emit telemetry
    TelemetryFlow.emit_ai_event([:training_gym, :episode], %{
      episode_count: length(new_episodes)
    }, %{
      type: episode.type,
      model: episode[:primary_model] || episode[:model]
    })

    {:noreply, %{state |
      episodes: new_episodes,
      model_scores: new_scores,
      intent_success_rates: new_rates
    }}
  end

  def handle_cast(:learn, state) do
    learnings = analyze_episodes(state.episodes)
    publish_learnings(learnings)

    {:noreply, %{state |
      last_learning_cycle: DateTime.utc_now(),
      episodes: []  # Clear after learning
    }}
  end

  def handle_info(:periodic_learn, state) do
    handle_cast(:learn, state)
    Process.send_after(self(), :periodic_learn, :timer.hours(1))
    {:noreply, state}
  end

  defp update_model_scores(scores, %{type: :success, primary_model: model}) do
    Map.update(scores, model, 1.0, &((&1 * 0.99) + 0.01))
  end

  defp update_model_scores(scores, %{type: :shadow_agree, primary_model: model}) do
    Map.update(scores, model, 1.0, &((&1 * 0.99) + 0.005))
  end

  defp update_model_scores(scores, %{type: :shadow_diverge, primary_model: model}) do
    Map.update(scores, model, 0.5, &((&1 * 0.99) - 0.01))
  end

  defp update_model_scores(scores, _), do: scores

  defp update_success_rates(rates, %{type: :success, request_intent: intent}) when not is_nil(intent) do
    Map.update(rates, intent, 1.0, &((&1 * 0.99) + 0.01))
  end

  defp update_success_rates(rates, _), do: rates

  defp analyze_episodes(episodes) do
    %{
      total_episodes: length(episodes),
      success_rate: calculate_success_rate(episodes),
      divergence_rate: calculate_divergence_rate(episodes),
      top_performing_models: top_models(episodes),
      struggling_intents: struggling_intents(episodes)
    }
  end

  defp calculate_success_rate(episodes) do
    successes = Enum.count(episodes, &(&1.type == :success))
    if length(episodes) > 0, do: successes / length(episodes), else: 0.0
  end

  defp calculate_divergence_rate(episodes) do
    shadow_episodes = Enum.filter(episodes, &(&1.type in [:shadow_diverge, :shadow_agree]))
    divergences = Enum.count(shadow_episodes, &(&1.type == :shadow_diverge))
    if length(shadow_episodes) > 0, do: divergences / length(shadow_episodes), else: 0.0
  end

  defp top_models(episodes) do
    episodes
    |> Enum.filter(&(&1.type == :success))
    |> Enum.frequencies_by(&(&1[:primary_model] || &1[:model]))
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(5)
    |> Enum.map(&elem(&1, 0))
  end

  defp struggling_intents(episodes) do
    episodes
    |> Enum.reject(&(&1.type == :success))
    |> Enum.frequencies_by(&(&1[:request_intent]))
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(3)
    |> Enum.map(&elem(&1, 0))
  end

  defp publish_learnings(learnings) do
    Indrajaal.Observability.ZenohEvolutionPublisher.publish_learning(%{
      type: :training_gym_cycle,
      learnings: learnings,
      timestamp: DateTime.utc_now()
    })
  end
end
```

### 5.4 GDE Integration (Goal-Directed Evolution)

```elixir
defmodule Indrajaal.AI.GDEIntegration do
  @moduledoc """
  Integration of AI capabilities with the Goal-Directed Evolution system.

  GDE Cycle:
  1. OBSERVE: Detect anomaly or error state
  2. ORIENT: Analyze context with Gemini
  3. DECIDE: Generate fix proposals with Claude
  4. ACT: Execute verified fix
  5. LEARN: Record episode in TrainingGym

  All steps flow through Simplex architecture.
  """

  alias Indrajaal.AI.SimplexController
  alias Indrajaal.AI.Evolution.TrainingGym
  alias Indrajaal.Cortex.GDE.AIIntegration

  @doc """
  Execute a full GDE cycle for an error context.
  """
  @spec execute_cycle(map()) :: {:ok, map()} | {:error, term()}
  def execute_cycle(error_context) do
    with {:ok, analysis} <- observe_and_orient(error_context),
         {:ok, proposals} <- decide_fixes(analysis),
         {:ok, selected} <- validate_and_select(proposals),
         {:ok, result} <- act_on_fix(selected) do
      learn_from_result(error_context, result)
      {:ok, result}
    end
  end

  # Step 1-2: Observe and Orient (Analysis with Gemini)
  defp observe_and_orient(error_context) do
    request = %{
      action: :gde_analysis,
      source: :gde_integration,
      intent: :analyze,
      prompt: build_analysis_prompt(error_context),
      model: "google/gemini-1.5-pro"
    }

    SimplexController.execute(request)
  end

  # Step 3: Decide (Generate proposals with Claude)
  defp decide_fixes(analysis) do
    request = %{
      action: :gde_synthesis,
      source: :gde_integration,
      intent: :synthesize,
      prompt: build_synthesis_prompt(analysis),
      model: "anthropic/claude-3.5-sonnet"
    }

    with {:ok, result} <- SimplexController.execute(request) do
      {:ok, parse_proposals(result[:content])}
    end
  end

  # Step 4: Validate and Select (with Claude)
  defp validate_and_select(proposals) do
    request = %{
      action: :gde_validation,
      source: :gde_integration,
      intent: :validate,
      prompt: build_validation_prompt(proposals),
      model: "anthropic/claude-3.5-sonnet"
    }

    with {:ok, result} <- SimplexController.execute(request) do
      {:ok, select_best_proposal(proposals, result)}
    end
  end

  # Step 5: Act on the selected fix
  defp act_on_fix(proposal) do
    # This executes through the existing GDE infrastructure
    AIIntegration.execute_verified_fix(proposal)
  end

  # Step 6: Learn from the result
  defp learn_from_result(error_context, result) do
    episode_type = case result[:status] do
      :success -> :success
      :partial -> :near_miss
      _ -> :failure
    end

    TrainingGym.record_episode(%{
      type: episode_type,
      primary_model: "anthropic/claude-3.5-sonnet",
      request_intent: :gde_cycle,
      error_type: error_context[:error_type],
      fix_applied: result[:fix_applied],
      timestamp: DateTime.utc_now()
    })
  end

  defp build_analysis_prompt(error_context) do
    """
    Analyze the following error context and identify:
    1. Root cause
    2. Affected components
    3. Severity level
    4. Potential fix strategies

    Error Context:
    #{inspect(error_context, pretty: true)}
    """
  end

  defp build_synthesis_prompt(analysis) do
    """
    Based on the following analysis, generate 3 potential fixes.
    Each fix should include:
    - Description
    - Code changes (if applicable)
    - Risk level
    - Rollback strategy

    Analysis:
    #{analysis[:content]}
    """
  end

  defp build_validation_prompt(proposals) do
    """
    Validate each of the following proposals and rank them by:
    1. Correctness
    2. Safety
    3. Minimal invasiveness

    Proposals:
    #{inspect(proposals, pretty: true)}
    """
  end

  defp parse_proposals(content) do
    # Simple parsing - in production would use structured output
    content
    |> String.split("---")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&%{description: &1})
  end

  defp select_best_proposal(proposals, validation_result) do
    # Simple selection - pick first validated proposal
    proposals
    |> Enum.at(0, %{description: "No valid proposal"})
    |> Map.put(:validation, validation_result[:content])
  end
end
```

### 5.5 Key System Operations Using LLMs

| Operation | Intent | Model | Simplex Path |
|-----------|--------|-------|--------------|
| Error Analysis | `:analyze` | Gemini 1.5 Pro | GDE Observe/Orient |
| Fix Generation | `:synthesize` | Claude 3.5 Sonnet | GDE Decide |
| Fix Validation | `:validate` | Claude 3.5 Sonnet | GDE Decide |
| Alarm Triage | `:triage` | Gemini Flash 8B | Synapse Input |
| Pattern Detection | `:analyze` | Gemini 1.5 Pro | Cortex Sensors |
| Incident Summary | `:synthesize` | Claude 3.5 Sonnet | Dashboard |
| Compliance Check | `:validate` | Claude 3.5 Sonnet | Policy Engine |
| Code Review | `:code` | Claude 3.5 Sonnet | CI Integration |
| Complex Reasoning | `:reason` | o1-preview | Cortex Strategy |

### 5.6 STAMP Constraints (LLM Operations)

| ID | Constraint | Enforcement |
|----|------------|-------------|
| SC-AI-101 | All LLM ops through Simplex | `SimplexController.execute/2` |
| SC-AI-102 | Intent routing mandatory | `IntentRouter.route/2` |
| SC-AI-103 | ShadowMode for new models | `ShadowMode.execute_with_shadow/2` |
| SC-AI-104 | TrainingGym records all episodes | `TrainingGym.record_episode/1` |
| SC-AI-105 | GDE uses dual-model approach | Gemini analyze + Claude synthesize |
| SC-AI-106 | Validation before execution | `validate_and_select/1` |
| SC-AI-107 | Learning cycles < 1 hour | Periodic GenServer message |
| SC-AI-108 | Zenoh publishes learnings | `ZenohEvolutionPublisher.publish_learning/1` |

---

## Implementation Roadmap

### Phase 1: Core Simplex Infrastructure (Week 1)

1. **SimplexController Module**
   - `build_proposal/3`
   - `guardian_pre_flight/1`
   - `graph_verification/1`
   - `provider_dispatch/2`

2. **Enhanced Guardian Integration**
   - AI proposal type support
   - Budget constraint checking
   - Content inspection call

3. **Tests**
   - Unit tests for each Simplex step
   - Integration test for full flow
   - Property tests for invariants

### Phase 2: Data Flow & Telemetry (Week 2)

1. **TelemetryFlow Module**
   - Erlang telemetry events
   - Zenoh streaming
   - CEPAF bridge integration

2. **Response Processing**
   - Unified response parser
   - Cost extraction
   - Latency measurement

3. **Tests**
   - Telemetry event verification
   - Zenoh subscription tests

### Phase 3: Commercial & Cost Management (Week 3)

1. **CostMonitor GenServer**
   - Budget tracking
   - Rate limiting
   - Alert thresholds

2. **CostOptimizer Module**
   - Intent-to-model mapping
   - Budget-aware selection
   - Downgrade logic

3. **Tests**
   - Budget enforcement tests
   - Rate limit tests

### Phase 4: Security Hardening (Week 4)

1. **ContentInspector Module**
   - Forbidden pattern detection
   - PII detection
   - Response sanitization

2. **TwoKeyTurn Authorization**
   - High-risk detection
   - Dual authorization flow

3. **AuditLog Integration**
   - Request logging
   - Response logging
   - Veto logging

4. **Tests**
   - Security pattern tests
   - Authorization tests

### Phase 5: LLM Operations & Evolution (Week 5)

1. **IntentRouter Enhancement**
   - Full intent configuration
   - Provider preferences
   - Routing strategies

2. **ShadowMode Implementation**
   - Parallel execution
   - Divergence calculation
   - TrainingGym integration

3. **TrainingGym GenServer**
   - Episode recording
   - Score tracking
   - Learning cycles

4. **GDE Integration**
   - Full GDE cycle
   - Dual-model approach
   - Learning feedback

5. **Tests**
   - Shadow evaluation tests
   - TrainingGym tests
   - GDE cycle tests

---

## Verification Checklist

- [ ] All AI operations flow through SimplexController
- [ ] Guardian pre-flight check for every request
- [ ] Graph verification after Guardian approval
- [ ] Cost recorded for every successful request
- [ ] Telemetry emitted for all outcomes
- [ ] Budget limits enforced before API calls
- [ ] Rate limits prevent API exhaustion
- [ ] Forbidden patterns blocked
- [ ] Two-Key Turn for high-risk operations
- [ ] Audit log for all operations
- [ ] Intent-based routing working
- [ ] ShadowMode evaluating new models
- [ ] TrainingGym recording episodes
- [ ] Learning cycles publishing to Zenoh
- [ ] GDE integration complete
- [ ] All STAMP constraints verified

---

## Conclusion

This 5-level implementation plan provides a comprehensive framework for AI operations in Indrajaal:

1. **Level 1 (Control Flow)**: Simplex architecture ensures all AI operations pass through Guardian validation
2. **Level 2 (Data Flow)**: Unified message structures and telemetry streaming to all observers
3. **Level 3 (Commercial)**: Cost optimization and budget enforcement for sustainable operations
4. **Level 4 (Security)**: Multi-layer security from input validation to audit logging
5. **Level 5 (LLM Operations)**: Intent-based routing with continuous learning and evolution

All interactions use the Simplex approach, ensuring safety and observability while enabling sophisticated AI capabilities throughout the Indrajaal system.
