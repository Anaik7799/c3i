# Unified AI Platform Master Specification

**Document Control**

| Field | Value |
|-------|-------|
| Version | 1.0.0-MASTER |
| Created | 2025-12-27 |
| Author | Cybernetic Architect (Claude Code) |
| STAMP | SC-AI-*, SC-MCP-*, SC-NEURO-*, SC-GUARD-*, SC-GVF-*, SC-SEC-*, SC-DF-* |
| Status | MASTER SPECIFICATION |
| Priority | P0-CRITICAL |

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Simplex Architecture Pattern](#3-simplex-architecture-pattern)
4. [Ash MCP Integration](#4-ash-mcp-integration)
5. [Provider Dispatcher & Routing](#5-provider-dispatcher--routing)
6. [OpenRouter Dynamic Manager](#6-openrouter-dynamic-manager)
7. [Guardian Pre-Flight System](#7-guardian-pre-flight-system)
8. [Control Flow (Level 1)](#8-control-flow-level-1)
9. [Data Flow (Level 2)](#9-data-flow-level-2)
10. [Commercial Aspects (Level 3)](#10-commercial-aspects-level-3)
11. [Security Architecture (Level 4)](#11-security-architecture-level-4)
12. [LLM Operations (Level 5)](#12-llm-operations-level-5)
13. [CEPAF F# Integration](#13-cepaf-f-integration)
14. [STAMP Constraints (Complete)](#14-stamp-constraints-complete)
15. [Implementation Roadmap](#15-implementation-roadmap)
16. [Testing Strategy](#16-testing-strategy)
17. [Configuration Reference](#17-configuration-reference)
18. [Appendices](#18-appendices)

---

## 1. Executive Summary

This master specification defines the **Unified AI Platform** for Indrajaal, integrating:

1. **All AI Providers** - Claude, Gemini, OpenRouter, Local (Ollama), future models
2. **Ash MCP Integration** - 45+ MCP tools across 8 resource categories
3. **Simplex Architecture** - All AI operations through Guardian → Decision Module → Safety Plane
4. **CEPAF F# Bridge** - Telemetry events, safety handlers, container operations
5. **Cortex Components** - Synapse, GDE, ShadowMode, TrainingGym
6. **Safety Systems** - Guardian, Envelope, DeadMansSwitch
7. **Observability** - Zenoh, Fractal Logging, OTEL

### 1.1 Core Principles

```
┌─────────────────────────────────────────────────────────────────┐
│ COMPLEX PLANE (AI/Cortex)                                       │
│ - Receives requests from MCP tools, LiveView, REST API          │
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

### 1.2 Key Deliverables

| Component | Description | MCP Tools |
|-----------|-------------|-----------|
| ChatResource | Unified chat interface | 2 tools |
| AnalysisResource | Context analysis (Gemini) | 4 tools |
| GenerationResource | Code generation (Claude) | 3 tools |
| SynapseResource | Bicameral orchestration | 4 tools |
| GDEResource | Goal-Directed Evolution | 4 tools |
| EvolutionResource | ShadowMode + TrainingGym | 9 tools |
| SafetyResource | Guardian + validation | 5 tools |
| InfraResource | CEPAF container ops | 7 tools |
| **Total** | | **45+ tools** |

---

## 2. Architecture Overview

### 2.1 System Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         CLAUDE CODE / AI AGENT                            │
│                                                                          │
│  mcp:ai:chat, mcp:ai:analyze, mcp:gde:execute_cycle, mcp:shadow:run     │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                    PHOENIX MCP ROUTER (/api/mcp)                         │
│                                                                          │
│  forward "/mcp", AshAi.Mcp.Router, tools: @all_mcp_resources            │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                         ASH RESOURCE LAYER                                │
│                                                                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐        │
│  │ ChatResource│ │AnalysisRes │ │GenerationRes│ │ SynapseRes  │        │
│  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └──────┬──────┘        │
│         │               │               │               │                │
│         └───────────────┴───────────────┴───────────────┘                │
│                                    │                                     │
│                        ┌───────────▼───────────┐                         │
│                        │   ASH POLICIES        │                         │
│                        │  (Guardian Validation)│                         │
│                        └───────────┬───────────┘                         │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                    SIMPLEX CONTROLLER                                     │
│                                                                          │
│  1. Build Guardian Proposal                                              │
│  2. Guardian Pre-Flight Check (SC-NEURO-001)                             │
│  3. Graph Verification (SC-GVF-*)                                        │
│  4. Provider Dispatch                                                    │
│  5. Response Processing + Telemetry                                      │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                      PROVIDER DISPATCHER                                  │
│                                                                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐        │
│  │ OpenRouter  │ │  Anthropic  │ │   Google    │ │   Ollama    │        │
│  │  Gateway    │ │   Direct    │ │   Direct    │ │   Local     │        │
│  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └──────┬──────┘        │
│         │               │               │               │                │
│         └───────────────┴───────────────┴───────────────┘                │
│                                    │                                     │
│                    ┌───────────────┼───────────────┐                     │
│                    ▼               ▼               ▼                     │
│              ┌──────────┐   ┌──────────┐   ┌──────────┐                 │
│              │ Guardian │   │  Zenoh   │   │  CEPAF   │                 │
│              │Pre-flight│   │Telemetry │   │  Bridge  │                 │
│              └──────────┘   └──────────┘   └──────────┘                 │
└──────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Ash Domain Structure

```
Indrajaal.AI (Ash Domain)
├── Indrajaal.AI.ProviderResource        # Provider management
├── Indrajaal.AI.ChatResource            # Unified chat interface
├── Indrajaal.AI.AnalysisResource        # Analysis tools
├── Indrajaal.AI.GenerationResource      # Code generation tools
├── Indrajaal.AI.SynapseResource         # Bicameral orchestration
├── Indrajaal.AI.GDEResource             # Goal-Directed Evolution
├── Indrajaal.AI.EvolutionResource       # ShadowMode + TrainingGym
├── Indrajaal.AI.SafetyResource          # Guardian + validation
└── Indrajaal.AI.InfraResource           # CEPAF container operations
```

### 2.3 Component Hierarchy

```
OpenRouter Dynamic Manager
├── ModelRegistry (GenServer)
│   ├── Live models from API
│   ├── Pricing data
│   └── Capabilities
├── IntentRouter (Pure Logic)
│   ├── Intent→Model mapping
│   ├── Strategies (:nitro, :floor, :free)
│   └── Fallbacks
├── CostMonitor (GenServer)
│   ├── Budget tracking
│   ├── Cost alerts
│   └── Rate limiting
└── OpenRouterGateway
    ├── Intent Analysis
    ├── Model Selection
    ├── Guardian Pre-Flight
    ├── Graph Verification
    ├── API Execution
    ├── Cost Recording
    └── Telemetry Streaming
```

---

## 3. Simplex Architecture Pattern

### 3.1 Core Flow

Every AI operation follows this mandatory flow:

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

### 3.2 Guardian Proposal Structure

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

### 3.3 SimplexController Implementation

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

---

## 4. Ash MCP Integration

### 4.1 Domain Definition

```elixir
# lib/indrajaal/ai.ex
defmodule Indrajaal.AI do
  @moduledoc """
  Unified AI Domain for Indrajaal.

  WHAT: Ash domain exposing all AI capabilities via MCP.
  WHY: Single entry point for Claude, Gemini, OpenRouter, and future providers.
  CONSTRAINTS: SC-MCP-001 to SC-MCP-020, SC-NEURO-001, SC-GVF-*.

  ## Resources

  - ProviderResource - Provider management and configuration
  - ChatResource - Unified chat completions
  - AnalysisResource - Context analysis and pattern extraction
  - GenerationResource - Code and content generation
  - SynapseResource - Bicameral orchestration
  - GDEResource - Goal-Directed Evolution pipeline
  - EvolutionResource - ShadowMode and TrainingGym
  - SafetyResource - Guardian and validation
  - InfraResource - CEPAF container operations
  """

  use Ash.Domain,
    extensions: [AshAi]

  resources do
    resource Indrajaal.AI.ProviderResource
    resource Indrajaal.AI.ChatResource
    resource Indrajaal.AI.AnalysisResource
    resource Indrajaal.AI.GenerationResource
    resource Indrajaal.AI.SynapseResource
    resource Indrajaal.AI.GDEResource
    resource Indrajaal.AI.EvolutionResource
    resource Indrajaal.AI.SafetyResource
    resource Indrajaal.AI.InfraResource
  end
end
```

### 4.2 ChatResource - Unified Chat Interface

```elixir
# lib/indrajaal/ai/resources/chat_resource.ex
defmodule Indrajaal.AI.ChatResource do
  @moduledoc """
  Unified chat interface supporting all providers.

  MCP Tools:
  - ai_chat - Send chat completion with provider selection
  - ai_chat_stream - Streaming chat completion

  Supports intents: :analyze, :synthesize, :reason, :triage, :validate
  """

  use Ash.Resource,
    domain: Indrajaal.AI,
    extensions: [AshAi]

  alias Indrajaal.AI.ProviderDispatcher
  alias Indrajaal.Safety.Guardian

  ai do
    tools [:chat, :chat_with_intent]

    tool_descriptions %{
      chat: "Send a chat message to an AI provider with automatic routing",
      chat_with_intent: "Send a chat message with explicit intent for optimal routing"
    }
  end

  actions do
    action :chat, :map do
      description "Unified chat completion across all providers"

      argument :messages, {:array, :map}, allow_nil?: false
      argument :provider, :atom do
        description "Provider: :openrouter, :anthropic, :google, :ollama, :auto"
        default :auto
      end
      argument :model, :string do
        description "Specific model ID or tier (:fast, :smart, :deep)"
      end
      argument :temperature, :float, default: 0.7
      argument :max_tokens, :integer

      run fn input, context ->
        with {:ok, provider} <- resolve_provider(input),
             {:ok, _} <- validate_with_guardian(input, context),
             {:ok, result} <- ProviderDispatcher.chat(provider, input) do
          emit_telemetry(:chat, provider, result)
          {:ok, result}
        end
      end
    end

    action :chat_with_intent, :map do
      description "Chat with explicit intent for optimal model routing"

      argument :messages, {:array, :map}, allow_nil?: false
      argument :intent, :atom do
        constraints one_of: [:analyze, :synthesize, :reason, :triage, :validate]
      end
      argument :context, :map do
        description "Additional context (files, error logs, etc.)"
      end

      run fn input, _context ->
        intent = input.arguments.intent
        strategy = get_intent_strategy(intent)

        ProviderDispatcher.chat_with_strategy(strategy, input)
      end
    end
  end

  policies do
    policy action(:chat) do
      authorize_if always()  # Guardian check in action
    end
  end

  defp resolve_provider(input) do
    case input.arguments.provider do
      :auto -> {:ok, select_best_provider(input)}
      provider -> {:ok, provider}
    end
  end

  defp validate_with_guardian(input, _context) do
    proposal = %{
      action: :ai_chat,
      source: :mcp_chat_resource,
      messages: input.arguments.messages,
      provider: input.arguments.provider
    }

    case Guardian.validate_proposal(proposal) do
      {:ok, _} -> {:ok, :approved}
      {:veto, reason, _} -> {:error, {:guardian_veto, reason}}
    end
  end

  defp get_intent_strategy(:analyze), do: %{tier: :smart, routing: :floor}
  defp get_intent_strategy(:synthesize), do: %{tier: :smart, routing: :nitro}
  defp get_intent_strategy(:reason), do: %{tier: :deep, routing: nil}
  defp get_intent_strategy(:triage), do: %{tier: :free, routing: :free}
  defp get_intent_strategy(:validate), do: %{tier: :smart, routing: nil}

  defp select_best_provider(_input), do: :openrouter

  defp emit_telemetry(action, provider, result) do
    :telemetry.execute(
      [:indrajaal, :mcp, :ai, action],
      %{tokens: result[:tokens] || 0},
      %{provider: provider, success: true}
    )
  end
end
```

### 4.3 AnalysisResource - Context Analysis

```elixir
# lib/indrajaal/ai/resources/analysis_resource.ex
defmodule Indrajaal.AI.AnalysisResource do
  @moduledoc """
  Analysis tools for codebase understanding.

  MCP Tools:
  - analyze_codebase - Analyze files with Gemini's 1M context
  - analyze_error_logs - Understand error failure context
  - extract_patterns - Extract semantic patterns
  - analyze_threat - Real-time security threat analysis
  """

  use Ash.Resource,
    domain: Indrajaal.AI,
    extensions: [AshAi]

  alias Indrajaal.Cortex.AI.GeminiInterface
  alias Indrajaal.AI.Security.MLThreatDetection

  ai do
    tools [:analyze_codebase, :analyze_error_logs, :extract_patterns, :analyze_threat]

    tool_descriptions %{
      analyze_codebase: "Analyze codebase files using Gemini's large context window",
      analyze_error_logs: "Analyze error logs to understand failure context",
      extract_patterns: "Extract semantic patterns from code (:dependencies, :architecture, :conventions)",
      analyze_threat: "Real-time security threat analysis (<100ms SLA)"
    }
  end

  actions do
    action :analyze_codebase, :map do
      argument :files, {:array, :string}, allow_nil?: false
      argument :query, :string, allow_nil?: false
      argument :context, :map

      run fn input, _ctx ->
        files = input.arguments.files
        query = input.arguments.query
        opts = [context: input.arguments[:context]]

        case GeminiInterface.analyze_context(files, query, opts) do
          {:ok, analysis} -> {:ok, analysis}
          {:error, reason} -> {:error, reason}
        end
      end
    end

    action :analyze_error_logs, :map do
      argument :logs, :string, allow_nil?: false
      argument :context, :map

      run fn input, _ctx ->
        GeminiInterface.analyze_error(input.arguments.logs, input.arguments[:context] || %{})
      end
    end

    action :extract_patterns, :map do
      argument :files, {:array, :string}, allow_nil?: false
      argument :pattern_type, :atom do
        constraints one_of: [:dependencies, :architecture, :conventions]
      end

      run fn input, _ctx ->
        GeminiInterface.extract_patterns(input.arguments.files, input.arguments.pattern_type)
      end
    end

    action :analyze_threat, :map do
      description "Real-time threat analysis with <100ms SLA"

      argument :threat_event, :map, allow_nil?: false

      run fn input, _ctx ->
        MLThreatDetection.analyze_threat(input.arguments.threat_event)
      end
    end
  end
end
```

### 4.4 GenerationResource - Code Generation

```elixir
# lib/indrajaal/ai/resources/generation_resource.ex
defmodule Indrajaal.AI.GenerationResource do
  @moduledoc """
  Code generation tools using Claude.

  MCP Tools:
  - generate_code - Generate production Elixir code
  - generate_fix - Generate code fixes based on error analysis
  - reason_about_problem - Reason about problems and propose solutions
  """

  use Ash.Resource,
    domain: Indrajaal.AI,
    extensions: [AshAi]

  alias Indrajaal.Cortex.AI.ClaudeInterface

  ai do
    tools [:generate_code, :generate_fix, :reason_about_problem]

    tool_descriptions %{
      generate_code: "Generate production-ready Elixir code from analysis and requirements",
      generate_fix: "Generate code fixes based on error analysis",
      reason_about_problem: "Reason about a problem and propose multiple solutions"
    }
  end

  actions do
    action :generate_code, :map do
      argument :analysis, :map, allow_nil?: false
      argument :requirements, :string, allow_nil?: false
      argument :constraints, {:array, :string}

      run fn input, _ctx ->
        ClaudeInterface.generate_solution(
          input.arguments.analysis,
          input.arguments.requirements,
          constraints: input.arguments[:constraints] || []
        )
      end
    end

    action :generate_fix, :map do
      argument :error_analysis, :map, allow_nil?: false
      argument :affected_files, {:array, :string}, allow_nil?: false

      run fn input, _ctx ->
        ClaudeInterface.generate_fix(
          input.arguments.error_analysis,
          input.arguments.affected_files
        )
      end
    end

    action :reason_about_problem, :map do
      argument :problem, :string, allow_nil?: false
      argument :context, :map

      run fn input, _ctx ->
        ClaudeInterface.reason(
          input.arguments.problem,
          input.arguments[:context] || %{}
        )
      end
    end
  end
end
```

### 4.5 SynapseResource - Bicameral Orchestration

```elixir
# lib/indrajaal/ai/resources/synapse_resource.ex
defmodule Indrajaal.AI.SynapseResource do
  @moduledoc """
  Bicameral Cortex orchestration (Gemini Analysis → Claude Synthesis).

  MCP Tools:
  - solve_problem - Full bicameral problem-solving loop
  - analyze_and_fix - Two-stage error fixing
  - solve_with_gde - Full GDE pipeline with AI
  - get_synapse_state - Get orchestrator state
  """

  use Ash.Resource,
    domain: Indrajaal.AI,
    extensions: [AshAi]

  alias Indrajaal.Cortex.Synapse

  ai do
    tools [:solve_problem, :analyze_and_fix, :solve_with_gde, :get_synapse_state]

    tool_descriptions %{
      solve_problem: "Solve a problem using full bicameral loop (Gemini analyze → Claude synthesize → Guardian validate)",
      analyze_and_fix: "Two-stage error fixing: Gemini analyzes, Claude generates fix",
      solve_with_gde: "Full Goal-Directed Evolution pipeline with AI proposals",
      get_synapse_state: "Get current Synapse orchestrator state"
    }
  end

  actions do
    action :solve_problem, :map do
      argument :context, :map, allow_nil?: false
      argument :goal, :atom do
        constraints one_of: [:compilation_success, :test_pass, :error_fix, :feature_complete]
      end
      argument :max_iterations, :integer, default: 5

      run fn input, _ctx ->
        Synapse.solve_problem(
          input.arguments.context,
          input.arguments.goal,
          max_iterations: input.arguments.max_iterations
        )
      end
    end

    action :analyze_and_fix, :map do
      argument :error_logs, :string, allow_nil?: false
      argument :context, :map

      run fn input, _ctx ->
        Synapse.analyze_and_fix(
          input.arguments.error_logs,
          input.arguments[:context] || %{}
        )
      end
    end

    action :solve_with_gde, :map do
      argument :error_logs, :string, allow_nil?: false
      argument :max_proposals, :integer, default: 5

      run fn input, _ctx ->
        Synapse.solve_with_gde(
          input.arguments.error_logs,
          max_proposals: input.arguments.max_proposals
        )
      end
    end

    action :get_synapse_state, :map do
      run fn _input, _ctx ->
        {:ok, Synapse.get_state()}
      end
    end
  end
end
```

### 4.6 GDEResource - Goal-Directed Evolution

```elixir
# lib/indrajaal/ai/resources/gde_resource.ex
defmodule Indrajaal.AI.GDEResource do
  @moduledoc """
  Goal-Directed Evolution pipeline for AI-assisted code fixes.

  MCP Tools:
  - generate_ai_proposals - Generate AI-enhanced fix proposals
  - execute_gde_cycle - Full GDE cycle with validation and training
  - validate_fix - Validate a fix proposal using deep reasoning
  - enhance_proposal - Enrich proposal with actual code
  """

  use Ash.Resource,
    domain: Indrajaal.AI,
    extensions: [AshAi]

  alias Indrajaal.Cortex.GDE.AIIntegration

  ai do
    tools [:generate_ai_proposals, :execute_gde_cycle, :validate_fix, :enhance_proposal]

    tool_descriptions %{
      generate_ai_proposals: "Generate AI-enhanced fix proposals using model hierarchy (fast→smart→deep)",
      execute_gde_cycle: "Execute full GDE cycle with Guardian validation and TrainingGym recording",
      validate_fix: "Validate a fix proposal using deep reasoning model",
      enhance_proposal: "Enrich a proposal with actual code implementation"
    }
  end

  actions do
    action :generate_ai_proposals, {:array, :map} do
      argument :error_context, :map, allow_nil?: false
      argument :max_proposals, :integer, default: 5

      run fn input, _ctx ->
        AIIntegration.generate_ai_proposals(
          input.arguments.error_context,
          max_proposals: input.arguments.max_proposals
        )
      end
    end

    action :execute_gde_cycle, :map do
      description "Full GDE cycle: generate → validate → train → telemetry"

      argument :error_context, :map, allow_nil?: false

      run fn input, _ctx ->
        AIIntegration.execute_gde_cycle(input.arguments.error_context)
      end
    end

    action :validate_fix, :map do
      argument :proposal, :map, allow_nil?: false
      argument :original_error, :map, allow_nil?: false

      run fn input, _ctx ->
        AIIntegration.validate_fix(
          input.arguments.proposal,
          input.arguments.original_error
        )
      end
    end

    action :enhance_proposal, :map do
      argument :proposal, :map, allow_nil?: false
      argument :file_content, :string, allow_nil?: false

      run fn input, _ctx ->
        AIIntegration.enhance_proposal(
          input.arguments.proposal,
          input.arguments.file_content
        )
      end
    end
  end
end
```

### 4.7 EvolutionResource - ShadowMode & TrainingGym

```elixir
# lib/indrajaal/ai/resources/evolution_resource.ex
defmodule Indrajaal.AI.EvolutionResource do
  @moduledoc """
  Evolution tools: ShadowMode for safe model evaluation, TrainingGym for RL capture.

  MCP Tools:
  - register_shadow_model - Register a candidate model for evaluation
  - execute_shadow - Execute shadow model without actuators
  - compare_with_production - Compare shadow vs production outputs
  - request_promotion - Request model promotion (returns token)
  - confirm_promotion - Two-Key Turn promotion confirmation
  - record_training_episode - Record success/near-miss for RL
  - get_training_data - Export training episodes
  - get_shadow_stats - Get ShadowMode statistics
  - get_gym_stats - Get TrainingGym statistics
  """

  use Ash.Resource,
    domain: Indrajaal.AI,
    extensions: [AshAi]

  alias Indrajaal.Cortex.Evolution.{ShadowMode, TrainingGym}

  ai do
    tools [
      :register_shadow_model,
      :execute_shadow,
      :compare_with_production,
      :request_promotion,
      :confirm_promotion,
      :record_training_episode,
      :get_training_data,
      :get_shadow_stats,
      :get_gym_stats
    ]

    tool_descriptions %{
      register_shadow_model: "Register a candidate AI model for shadow evaluation",
      execute_shadow: "Execute shadow model in isolation (no actuator access)",
      compare_with_production: "Compare shadow model output with production",
      request_promotion: "Request promotion of a shadow model (requires criteria met)",
      confirm_promotion: "Confirm promotion with Two-Key Turn (requires confirmation code)",
      record_training_episode: "Record success or near-miss episode for RL training",
      get_training_data: "Export training episodes for ML training",
      get_shadow_stats: "Get ShadowMode statistics",
      get_gym_stats: "Get TrainingGym statistics"
    }
  end

  actions do
    # ShadowMode actions
    action :register_shadow_model, :map do
      argument :model_config, :map, allow_nil?: false

      run fn input, _ctx ->
        ShadowMode.register_shadow(input.arguments.model_config)
      end
    end

    action :execute_shadow, :map do
      argument :model_id, :string, allow_nil?: false
      argument :input, :map, allow_nil?: false

      run fn input, _ctx ->
        ShadowMode.execute_shadow(input.arguments.model_id, input.arguments.input)
      end
    end

    action :compare_with_production, :map do
      argument :model_id, :string, allow_nil?: false
      argument :input, :map, allow_nil?: false

      run fn input, _ctx ->
        production_fn = fn i -> {:ok, "production_response"} end
        ShadowMode.compare_with_production(
          input.arguments.model_id,
          input.arguments.input,
          production_fn
        )
      end
    end

    action :request_promotion, :map do
      argument :model_id, :string, allow_nil?: false

      run fn input, _ctx ->
        ShadowMode.request_promotion(input.arguments.model_id)
      end
    end

    action :confirm_promotion, :map do
      argument :promotion_token, :string, allow_nil?: false
      argument :confirmation_code, :string, allow_nil?: false

      run fn input, _ctx ->
        ShadowMode.confirm_promotion(
          input.arguments.promotion_token,
          input.arguments.confirmation_code
        )
      end
    end

    # TrainingGym actions
    action :record_training_episode, :map do
      argument :episode_type, :atom do
        constraints one_of: [:success, :near_miss, :shadow_diverge, :shadow_agree]
      end
      argument :state_before, :map, allow_nil?: false
      argument :action, :map, allow_nil?: false
      argument :result_or_reason, :map

      run fn input, _ctx ->
        case input.arguments.episode_type do
          :success ->
            TrainingGym.record_success(
              input.arguments.state_before,
              input.arguments.action,
              input.arguments.result_or_reason
            )
          :near_miss ->
            TrainingGym.record_near_miss(
              input.arguments.state_before,
              input.arguments.action,
              input.arguments.result_or_reason
            )
          _ ->
            {:ok, :recorded}
        end
      end
    end

    action :get_training_data, {:array, :map} do
      argument :limit, :integer, default: 100

      run fn input, _ctx ->
        {:ok, TrainingGym.get_episodes(input.arguments.limit)}
      end
    end

    action :get_shadow_stats, :map do
      run fn _input, _ctx ->
        {:ok, ShadowMode.stats()}
      end
    end

    action :get_gym_stats, :map do
      run fn _input, _ctx ->
        {:ok, TrainingGym.stats()}
      end
    end
  end
end
```

### 4.8 SafetyResource - Guardian & Validation

```elixir
# lib/indrajaal/ai/resources/safety_resource.ex
defmodule Indrajaal.AI.SafetyResource do
  @moduledoc """
  Safety tools for Guardian validation and multi-AI consensus.

  MCP Tools:
  - validate_proposal - Validate action through Guardian
  - multi_ai_validate - Multi-AI validation with consensus
  - verify_routing - Verify routing graph constraints
  - pre_flight_check - Full pre-flight Guardian + Graph verification
  - get_guardian_status - Get Guardian status
  """

  use Ash.Resource,
    domain: Indrajaal.AI,
    extensions: [AshAi]

  alias Indrajaal.Safety.Guardian
  alias Indrajaal.Validation.MultiAiValidator
  alias Indrajaal.AI.OpenRouterClient

  ai do
    tools [
      :validate_proposal,
      :multi_ai_validate,
      :verify_routing,
      :pre_flight_check,
      :get_guardian_status
    ]

    tool_descriptions %{
      validate_proposal: "Validate an action proposal through Guardian safety kernel",
      multi_ai_validate: "Validate code with multiple AI validators (75% consensus required)",
      verify_routing: "Verify routing against STAMP graph constraints",
      pre_flight_check: "Full pre-flight Guardian + Graph verification (SC-NEURO-001)",
      get_guardian_status: "Get Guardian GenServer status"
    }
  end

  actions do
    action :validate_proposal, :map do
      argument :proposal, :map, allow_nil?: false

      run fn input, _ctx ->
        case Guardian.validate_proposal(input.arguments.proposal) do
          {:ok, approved} -> {:ok, %{approved: true, proposal: approved}}
          {:veto, reason, fallback} -> {:ok, %{approved: false, reason: reason, fallback: fallback}}
        end
      end
    end

    action :multi_ai_validate, :map do
      argument :code, :string, allow_nil?: false
      argument :validators, {:array, :atom}

      run fn input, _ctx ->
        MultiAiValidator.validate(
          input.arguments.code,
          validators: input.arguments[:validators]
        )
      end
    end

    action :verify_routing, :map do
      argument :source, :atom, allow_nil?: false
      argument :target_model, :string, allow_nil?: false
      argument :confidence, :float, default: 1.0

      run fn input, _ctx ->
        OpenRouterClient.verify_routing_graph(
          input.arguments.source,
          input.arguments.target_model,
          confidence: input.arguments.confidence
        )
      end
    end

    action :pre_flight_check, :map do
      argument :source, :atom, allow_nil?: false
      argument :model, :string, allow_nil?: false
      argument :prompt, :string, allow_nil?: false

      run fn input, _ctx ->
        OpenRouterClient.full_pre_flight_check(
          input.arguments.source,
          input.arguments.model,
          input.arguments.prompt
        )
      end
    end

    action :get_guardian_status, :map do
      run fn _input, _ctx ->
        {:ok, Guardian.status()}
      end
    end
  end
end
```

### 4.9 InfraResource - CEPAF Container Operations

```elixir
# lib/indrajaal/ai/resources/infra_resource.ex
defmodule Indrajaal.AI.InfraResource do
  @moduledoc """
  Infrastructure tools via CEPAF F# bridge.

  MCP Tools:
  - list_containers - List running containers
  - inspect_container - Get container details
  - container_health - Check container health
  - health_summary - Get aggregated health status
  - ooda_trigger_cycle - Trigger OODA control cycle
  - ooda_status - Get OODA loop status
  - fractal_emit - Emit fractal log entry
  """

  use Ash.Resource,
    domain: Indrajaal.AI,
    extensions: [AshAi]

  alias Indrajaal.Integration.CepafClient

  ai do
    tools [
      :list_containers,
      :inspect_container,
      :container_health,
      :health_summary,
      :ooda_trigger_cycle,
      :ooda_status,
      :fractal_emit
    ]

    tool_descriptions %{
      list_containers: "List all running containers via CEPAF",
      inspect_container: "Get detailed container information",
      container_health: "Check health status of a specific container",
      health_summary: "Get aggregated health status of all containers",
      ooda_trigger_cycle: "Trigger an OODA control loop cycle",
      ooda_status: "Get OODA loop status and pending proposals",
      fractal_emit: "Emit a log entry through the 5-level Fractal logging system"
    }
  end

  actions do
    action :list_containers, {:array, :map} do
      run fn _input, _ctx ->
        CepafClient.list_running_containers()
      end
    end

    action :inspect_container, :map do
      argument :container_id, :string, allow_nil?: false

      run fn input, _ctx ->
        CepafClient.get_container(input.arguments.container_id)
      end
    end

    action :container_health, :map do
      argument :container_id, :string, allow_nil?: false

      run fn input, _ctx ->
        CepafClient.container_health(input.arguments.container_id)
      end
    end

    action :health_summary, :map do
      run fn _input, _ctx ->
        CepafClient.health_summary()
      end
    end

    action :ooda_trigger_cycle, :map do
      run fn _input, _ctx ->
        CepafClient.execute_command(["ooda", "trigger"])
      end
    end

    action :ooda_status, :map do
      run fn _input, _ctx ->
        CepafClient.execute_command(["ooda", "status"])
      end
    end

    action :fractal_emit, :map do
      argument :level, :integer do
        constraints min: 1, max: 5
      end
      argument :channel, :string, allow_nil?: false
      argument :message, :string, allow_nil?: false

      run fn input, _ctx ->
        CepafClient.execute_command([
          "fractal", "emit",
          "--level", to_string(input.arguments.level),
          "--channel", input.arguments.channel,
          "--message", input.arguments.message
        ])
      end
    end
  end
end
```

### 4.10 Phoenix Router Configuration

```elixir
# lib/indrajaal_web/router.ex
defmodule IndrajaalWeb.Router do
  use IndrajaalWeb, :router

  # Existing pipelines...

  # MCP API endpoint
  scope "/api" do
    pipe_through [:api]

    # Unified MCP router exposing all AI resources
    forward "/mcp", AshAi.Mcp.Router,
      domain: Indrajaal.AI,
      tools: [
        # Chat & Core
        Indrajaal.AI.ChatResource,
        # Analysis
        Indrajaal.AI.AnalysisResource,
        # Generation
        Indrajaal.AI.GenerationResource,
        # Orchestration
        Indrajaal.AI.SynapseResource,
        # GDE Pipeline
        Indrajaal.AI.GDEResource,
        # Evolution
        Indrajaal.AI.EvolutionResource,
        # Safety
        Indrajaal.AI.SafetyResource,
        # Infrastructure
        Indrajaal.AI.InfraResource
      ]
  end
end
```

### 4.11 Claude Code Configuration

```json
{
  "mcpServers": {
    "indrajaal": {
      "url": "http://localhost:4000/api/mcp",
      "transport": "http",
      "description": "Indrajaal AI Platform - Full MCP Integration"
    }
  }
}
```

---

## 5. Provider Dispatcher & Routing

### 5.1 Provider Dispatcher

```elixir
# lib/indrajaal/ai/provider_dispatcher.ex
defmodule Indrajaal.AI.ProviderDispatcher do
  @moduledoc """
  Routes AI requests to appropriate providers with fallback chain.

  ## Provider Priority (Default)
  1. OpenRouter (gateway to all)
  2. Anthropic Direct (if OpenRouter down)
  3. Google Direct (if both down)
  4. Ollama Local (offline fallback)

  ## STAMP Constraints
  - SC-MCP-010: All routing through Guardian pre-flight
  - SC-MCP-011: Fallback chain must be configured
  - SC-MCP-012: Provider timeout must be enforced
  """

  alias Indrajaal.AI.OpenRouterClient
  alias Indrajaal.Safety.Guardian

  @providers %{
    openrouter: Indrajaal.AI.OpenRouterClient,
    anthropic: Indrajaal.AI.Providers.Anthropic,
    google: Indrajaal.AI.Providers.Google,
    ollama: Indrajaal.AI.Providers.Ollama
  }

  @fallback_chain [:openrouter, :anthropic, :google, :ollama]

  @doc """
  Route chat request to provider with automatic fallback.
  """
  def chat(provider, input, opts \\ []) do
    with {:ok, true} <- pre_flight_check(provider, input),
         {:ok, result} <- do_chat(provider, input, opts) do
      {:ok, result}
    else
      {:error, :provider_unavailable} ->
        fallback_chat(provider, input, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Route chat with specific routing strategy.
  """
  def chat_with_strategy(strategy, input) do
    provider = strategy[:provider] || :openrouter
    opts = build_routing_opts(strategy)

    chat(provider, input, opts)
  end

  defp pre_flight_check(provider, input) do
    prompt = extract_prompt(input)
    model = input.arguments[:model] || get_default_model(provider)

    OpenRouterClient.pre_flight_guardian_check(:mcp_dispatcher, model, prompt)
  end

  defp do_chat(:openrouter, input, opts) do
    messages = input.arguments.messages
    OpenRouterClient.chat(messages, opts)
  end

  defp do_chat(provider, input, opts) do
    module = Map.get(@providers, provider)
    if module && Code.ensure_loaded?(module) do
      apply(module, :chat, [input.arguments.messages, opts])
    else
      {:error, :provider_not_implemented}
    end
  end

  defp fallback_chat(failed_provider, input, opts) do
    remaining = Enum.drop_while(@fallback_chain, &(&1 != failed_provider))
    |> Enum.drop(1)

    Enum.reduce_while(remaining, {:error, :all_providers_failed}, fn provider, _acc ->
      case do_chat(provider, input, opts) do
        {:ok, result} -> {:halt, {:ok, result}}
        {:error, _} -> {:cont, {:error, :all_providers_failed}}
      end
    end)
  end

  defp build_routing_opts(%{tier: tier, routing: routing}) do
    model = tier_to_model(tier)
    headers = routing_to_headers(routing)

    [model: model] ++ headers
  end

  defp tier_to_model(:fast), do: "google/gemini-flash-1.5-8b"
  defp tier_to_model(:smart), do: "anthropic/claude-3.5-sonnet"
  defp tier_to_model(:deep), do: "openai/o1-preview"
  defp tier_to_model(:free), do: "google/gemini-2.0-flash-exp:free"

  defp routing_to_headers(:nitro), do: [routing_suffix: "nitro"]
  defp routing_to_headers(:floor), do: [routing_suffix: "floor"]
  defp routing_to_headers(:free), do: [routing_suffix: "free"]
  defp routing_to_headers(_), do: []

  defp get_default_model(:openrouter), do: "anthropic/claude-3.5-sonnet"
  defp get_default_model(:anthropic), do: "claude-3-5-sonnet-20241022"
  defp get_default_model(:google), do: "gemini-1.5-pro"
  defp get_default_model(:ollama), do: "llama3.2"

  defp extract_prompt(input) do
    input.arguments.messages
    |> Enum.filter(&(&1["role"] == "user"))
    |> Enum.map(&(&1["content"]))
    |> Enum.join("\n")
  end
end
```

---

## 6. OpenRouter Dynamic Manager

### 6.1 ModelRegistry

```elixir
# lib/indrajaal/openrouter/model_registry.ex
defmodule Indrajaal.OpenRouter.ModelRegistry do
  @moduledoc """
  Maintains live model catalog with pricing and capabilities.

  STAMP Constraints:
  - SC-AI-006: Model registry must refresh within 1 hour
  """

  use GenServer

  @refresh_interval_ms 3_600_000  # 1 hour

  defstruct [
    models: %{},
    model_tiers: %{
      fast: ["google/gemini-flash-1.5-8b", "google/gemini-2.0-flash-exp"],
      smart: ["anthropic/claude-3.5-sonnet", "anthropic/claude-sonnet-4"],
      deep: ["openai/o1-preview", "anthropic/claude-3-opus"],
      free: ["google/gemini-2.0-flash-exp:free", "meta-llama/llama-3.1-8b-instruct:free"]
    },
    last_refresh: nil,
    refresh_interval_ms: @refresh_interval_ms
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec get_model(atom(), atom()) :: {:ok, String.t()} | {:error, term()}
  def get_model(tier, strategy \\ nil) do
    GenServer.call(__MODULE__, {:get_model, tier, strategy})
  end

  @spec get_pricing(String.t()) :: {:ok, map()} | {:error, term()}
  def get_pricing(model_id) do
    GenServer.call(__MODULE__, {:get_pricing, model_id})
  end

  @spec list_models(atom()) :: [map()]
  def list_models(capability \\ nil) do
    GenServer.call(__MODULE__, {:list_models, capability})
  end

  @spec refresh_models() :: :ok | {:error, term()}
  def refresh_models do
    GenServer.call(__MODULE__, :refresh)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Schedule initial refresh
    Process.send_after(self(), :refresh, 0)
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:get_model, tier, _strategy}, _from, state) do
    models = Map.get(state.model_tiers, tier, [])
    case models do
      [first | _] -> {:reply, {:ok, first}, state}
      [] -> {:reply, {:error, :no_models_for_tier}, state}
    end
  end

  @impl true
  def handle_call({:get_pricing, model_id}, _from, state) do
    case Map.get(state.models, model_id) do
      nil -> {:reply, {:error, :model_not_found}, state}
      model -> {:reply, {:ok, model.pricing}, state}
    end
  end

  @impl true
  def handle_call({:list_models, _capability}, _from, state) do
    models = Map.values(state.models)
    {:reply, models, state}
  end

  @impl true
  def handle_call(:refresh, _from, state) do
    case fetch_models_from_api() do
      {:ok, models} ->
        new_state = %{state | models: models, last_refresh: DateTime.utc_now()}
        {:reply, :ok, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(:refresh, state) do
    case fetch_models_from_api() do
      {:ok, models} ->
        new_state = %{state | models: models, last_refresh: DateTime.utc_now()}
        schedule_refresh(state.refresh_interval_ms)
        {:noreply, new_state}
      {:error, _reason} ->
        # Retry sooner on failure
        schedule_refresh(60_000)
        {:noreply, state}
    end
  end

  defp fetch_models_from_api do
    api_key = Application.get_env(:indrajaal, :openrouter_api_key)
    headers = [{"Authorization", "Bearer #{api_key}"}]

    case Req.get("https://openrouter.ai/api/v1/models", headers: headers) do
      {:ok, %{status: 200, body: %{"data" => models}}} ->
        {:ok, parse_models(models)}
      {:ok, %{status: status}} ->
        {:error, {:api_error, status}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_models(models) do
    models
    |> Enum.map(fn m ->
      {m["id"], %{
        id: m["id"],
        name: m["name"],
        pricing: parse_pricing(m["pricing"]),
        context_length: m["context_length"],
        capabilities: parse_capabilities(m)
      }}
    end)
    |> Map.new()
  end

  defp parse_pricing(%{"prompt" => p, "completion" => c}) do
    %{prompt: String.to_float(p) * 1_000_000, completion: String.to_float(c) * 1_000_000}
  end
  defp parse_pricing(_), do: %{prompt: 0.0, completion: 0.0}

  defp parse_capabilities(_model), do: [:chat]

  defp schedule_refresh(interval) do
    Process.send_after(self(), :refresh, interval)
  end
end
```

### 6.2 IntentRouter

```elixir
# lib/indrajaal/openrouter/intent_router.ex
defmodule Indrajaal.OpenRouter.IntentRouter do
  @moduledoc """
  Maps AI intents to optimal model/strategy combinations.

  Intent Categories:
  - :triage - Quick classification, low cost
  - :analyze - Deep analysis, high accuracy
  - :synthesize - Content generation, creative
  - :reason - Complex reasoning, chain-of-thought
  - :validate - Verification, consistency checking
  - :code - Code generation/review
  """

  @intent_config %{
    triage: %{
      model: "google/gemini-flash-1.5-8b",
      route: :floor,
      providers: ["google", "meta-llama"],
      max_tokens: 500,
      temperature: 0.3
    },
    analyze: %{
      model: "google/gemini-1.5-pro",
      route: nil,
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
      route: :nitro,
      providers: ["openai", "anthropic"],
      max_tokens: 8000,
      temperature: 1.0
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

  @spec build_routing_headers(atom()) :: map()
  def build_routing_headers(:nitro) do
    %{
      "X-Provider-Preferences" => "speed",
      "X-OpenRouter-Suffix" => "nitro"
    }
  end

  def build_routing_headers(:floor) do
    %{
      "X-Provider-Preferences" => "price",
      "X-OpenRouter-Suffix" => "floor"
    }
  end

  def build_routing_headers(:free) do
    %{
      "X-Provider-Preferences" => "price",
      "X-OpenRouter-Suffix" => "free"
    }
  end

  def build_routing_headers(_), do: %{}

  defp build_provider_preferences(config, opts) do
    %{
      order: Keyword.get(opts, :providers, config.providers),
      allow_fallbacks: Keyword.get(opts, :allow_fallbacks, true),
      require_parameters: true
    }
  end
end
```

### 6.3 CostMonitor

```elixir
# lib/indrajaal/openrouter/cost_monitor.ex
defmodule Indrajaal.OpenRouter.CostMonitor do
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

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

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

  @spec estimate_cost(String.t(), non_neg_integer(), non_neg_integer()) :: float()
  def estimate_cost(model, input_tokens, output_tokens) do
    Indrajaal.AI.Pricing.estimate_cost(model, input_tokens, output_tokens)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{last_minute_reset: DateTime.utc_now()}}
  end

  @impl true
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

  @impl true
  def handle_call(:get_daily, _from, state) do
    {:reply, state.daily_usage, state}
  end

  @impl true
  def handle_call(:get_monthly, _from, state) do
    {:reply, state.monthly_usage, state}
  end

  @impl true
  def handle_cast({:record, model, source, cost}, state) do
    new_state = %{state |
      daily_usage: state.daily_usage + cost,
      monthly_usage: state.monthly_usage + cost,
      usage_by_model: Map.update(state.usage_by_model, model, cost, &(&1 + cost)),
      usage_by_source: Map.update(state.usage_by_source, source, cost, &(&1 + cost))
    }

    emit_cost_telemetry(model, source, cost, new_state)
    check_budget_alerts(new_state)

    {:noreply, new_state}
  end

  defp maybe_reset_minute(state) do
    now = DateTime.utc_now()
    if DateTime.diff(now, state.last_minute_reset, :second) >= 60 do
      %{state | requests_this_minute: 0, last_minute_reset: now}
    else
      state
    end
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
    :telemetry.execute([:ai, :budget, :alert], %{
      current: current,
      limit: limit,
      percent: current / limit * 100
    }, %{alert_type: alert_type})
  end
end
```

### 6.4 Pricing Module

```elixir
# lib/indrajaal/ai/pricing.ex
defmodule Indrajaal.AI.Pricing do
  @moduledoc """
  Real-time pricing data for cost estimation.
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

---

## 7. Guardian Pre-Flight System

### 7.1 Pre-Flight Flow

```
AI Request
    │
    ▼
┌─────────────────────────┐
│ pre_flight_guardian_check│
│                         │
│ 1. Create Guardian      │
│    proposal from request│
│ 2. Call Guardian.       │
│    validate_proposal/1  │
│ 3. Return approval or   │
│    veto                 │
└───────────┬─────────────┘
            │
    ┌───────┴───────┐
    │               │
   {:ok}        {:veto}
    │               │
    ▼               ▼
┌─────────┐    ┌─────────┐
│ Graph   │    │ BLOCKED │
│ Verify  │    │ + Log   │
└────┬────┘    └─────────┘
     │
     ▼
┌─────────┐
│ OpenAI  │
│ API Call│
└─────────┘
```

### 7.2 Implementation Functions

```elixir
# lib/indrajaal/ai/open_router_client.ex

@spec pre_flight_guardian_check(atom(), atom() | String.t(), String.t(), keyword()) ::
        {:ok, true} | {:error, term()}
def pre_flight_guardian_check(source, model, prompt, opts \\ []) do
  alias Indrajaal.Safety.Guardian

  guardian_proposal = %{
    action: :ai_request,
    source: source,
    model: normalize_model(model),
    prompt_preview: String.slice(prompt || "", 0..500),
    prompt_length: String.length(prompt || ""),
    temperature: Keyword.get(opts, :temperature, 0.7),
    timestamp: DateTime.utc_now()
  }

  case Guardian.validate_proposal(guardian_proposal) do
    {:ok, _approved_proposal} ->
      Logger.debug("[OpenRouter] Pre-flight Guardian check PASSED for #{source}")
      {:ok, true}

    {:veto, reason, fallback} ->
      Logger.warning(
        "🛡️ [OpenRouter] Pre-flight Guardian check VETOED: #{inspect(reason)}"
      )
      {:error, {:guardian_veto, reason, fallback}}
  end
rescue
  error ->
    # Fail safe: if Guardian is unavailable, deny the request
    Logger.error("[OpenRouter] Guardian unavailable: #{inspect(error)}")
    {:error, {:guardian_unavailable, error}}
end

@spec full_pre_flight_check(atom(), atom() | String.t(), String.t(), keyword()) ::
        {:ok, map()} | {:error, term()}
def full_pre_flight_check(source, model, prompt, opts \\ []) do
  confidence = Keyword.get(opts, :confidence, 1.0)

  # Step 1: Guardian pre-flight check
  with {:ok, true} <- pre_flight_guardian_check(source, model, prompt, opts) do
    # Step 2: Graph verification with guardian_approved: true
    routing_proposal = %{
      source: source,
      target: :openrouter,
      model: normalize_model(model),
      confidence: confidence,
      guardian_approved: true
    }

    case validate_routing_proposal(routing_proposal) do
      {:ok, _verified} ->
        {:ok, %{guardian_approved: true, source: source, model: normalize_model(model)}}

      error ->
        error
    end
  end
end

defp normalize_model(model) when is_atom(model), do: Map.get(@models, model, to_string(model))
defp normalize_model(model) when is_binary(model), do: model
defp normalize_model(model), do: to_string(model)
```

---

## 8. Control Flow (Level 1)

See Section 3 (Simplex Architecture Pattern) for the complete control flow specification.

**Key STAMP Constraints:**

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

## 9. Data Flow (Level 2)

### 9.1 Message Flow

```
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
  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘
         │                   │                   │
         └───────────────────┼───────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  ASH RESOURCE   │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ SIMPLEX         │
                    │ CONTROLLER      │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
  │ OpenRouter  │    │ Anthropic   │    │ Google     │
  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘
         │                   │                   │
         └───────────────────┼───────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  RESPONSE       │
                    │  PROCESSING     │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
  │ CostMonitor │    │ Zenoh       │    │ CEPAF       │
  └─────────────┘    └─────────────┘    └─────────────┘
```

### 9.2 Request/Response Structures

**OpenRouter Request:**
```elixir
@type openrouter_request :: %{
  model: String.t(),
  messages: [%{role: String.t(), content: String.t()}],
  temperature: float(),
  max_tokens: non_neg_integer() | nil,
  stream: boolean(),
  provider: %{
    order: [String.t()],
    allow_fallbacks: boolean(),
    require_parameters: boolean()
  },
  route: :nitro | :floor | :free | nil
}
```

**Unified Response:**
```elixir
@type ai_response :: %{
  id: String.t(),
  model: String.t(),
  content: String.t(),
  finish_reason: :stop | :length | :tool_calls,
  usage: %{
    prompt_tokens: non_neg_integer(),
    completion_tokens: non_neg_integer(),
    total_tokens: non_neg_integer()
  },
  cost: %{
    input_cost: float(),
    output_cost: float(),
    total_cost: float(),
    currency: :usd
  },
  provider: atom(),
  latency_ms: non_neg_integer(),
  request_id: String.t(),
  timestamp: DateTime.t()
}
```

### 9.3 Zenoh Key Expression Schema

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

### 9.4 Telemetry Flow

```elixir
defmodule Indrajaal.AI.TelemetryFlow do
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

---

## 10. Commercial Aspects (Level 3)

### 10.1 Model Selection Matrix

| Intent | Default Model | Fallback 1 | Fallback 2 | Cost/1M tokens |
|--------|---------------|------------|------------|----------------|
| `:triage` | `google/gemini-flash-1.5-8b` | `openai/gpt-4o-mini` | Free tier | $0.075 |
| `:analyze` | `google/gemini-1.5-pro` | `anthropic/claude-3.5-sonnet` | - | $1.25 |
| `:synthesize` | `anthropic/claude-3.5-sonnet` | `openai/gpt-4o` | - | $3.00 |
| `:reason` | `openai/o1-preview` | `anthropic/claude-3-opus` | - | $15.00 |
| `:validate` | `anthropic/claude-3.5-sonnet` | `openai/gpt-4o` | - | $3.00 |
| `:code` | `anthropic/claude-3.5-sonnet` | `deepseek/deepseek-coder` | - | $3.00 |

### 10.2 Budget Configuration

```elixir
# config/config.exs
config :indrajaal, Indrajaal.OpenRouter,
  api_key: System.get_env("OPENROUTER_API_KEY"),
  budgets: %{
    daily_limit_usd: 10.0,
    monthly_limit_usd: 100.0,
    per_request_limit_usd: 1.0,
    alert_threshold_percent: 80
  },
  rate_limits: %{
    requests_per_minute: 100,
    tokens_per_minute: 100_000
  },
  registry: %{
    refresh_interval_ms: 3_600_000,
    fallback_models: %{
      fast: "google/gemini-flash-1.5-8b",
      smart: "anthropic/claude-3.5-sonnet",
      deep: "openai/o1-preview"
    }
  }

# config/prod.exs
config :indrajaal, Indrajaal.OpenRouter,
  budgets: %{
    daily_limit_usd: 100.0,
    monthly_limit_usd: 1000.0
  }
```

### 10.3 Cost Optimization Strategy

```elixir
defmodule Indrajaal.AI.CostOptimizer do
  @daily_budget_usd Application.compile_env(:indrajaal, [:ai, :daily_budget], 50.0)
  @monthly_budget_usd Application.compile_env(:indrajaal, [:ai, :monthly_budget], 1000.0)

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
      monthly_used >= @monthly_budget_usd -> {:error, :monthly_budget_exceeded}
      daily_used >= @daily_budget_usd -> {:error, :daily_budget_exceeded}
      true ->
        remaining = min(@daily_budget_usd - daily_used, @monthly_budget_usd - monthly_used)
        {:ok, remaining}
    end
  end

  defp intent_to_model(:triage, remaining, _opts) when remaining < 0.01 do
    {:ok, "meta-llama/llama-3.1-8b-instruct:free"}
  end

  defp intent_to_model(:triage, _remaining, _opts), do: {:ok, "google/gemini-flash-1.5-8b"}
  defp intent_to_model(:analyze, remaining, _opts) when remaining < 1.0, do: {:ok, "google/gemini-flash-1.5"}
  defp intent_to_model(:analyze, _remaining, _opts), do: {:ok, "google/gemini-1.5-pro"}
  defp intent_to_model(:synthesize, _remaining, _opts), do: {:ok, "anthropic/claude-3.5-sonnet"}
  defp intent_to_model(:reason, remaining, _opts) when remaining < 5.0, do: {:ok, "anthropic/claude-3.5-sonnet"}
  defp intent_to_model(:reason, _remaining, _opts), do: {:ok, "openai/o1-preview"}
  defp intent_to_model(:validate, _remaining, _opts), do: {:ok, "anthropic/claude-3.5-sonnet"}
  defp intent_to_model(:code, _remaining, _opts), do: {:ok, "anthropic/claude-3.5-sonnet"}
  defp intent_to_model(_unknown, _remaining, opts) do
    {:ok, Keyword.get(opts, :default_model, "anthropic/claude-3.5-sonnet")}
  end
end
```

---

## 11. Security Architecture (Level 4)

### 11.1 Security Layers

```
Layer 1: INPUT VALIDATION
├─ Ash argument validation
├─ Schema type checking
├─ Size limits (prompt length, max_tokens)
└─ Rate limiting per actor/tenant

Layer 2: CONTENT INSPECTION
├─ Forbidden pattern detection
│  ├─ Injection patterns (SQL, command, prompt)
│  ├─ PII detection (email, phone, SSN)
│  └─ Credential detection (API keys, passwords)
├─ Content classification
└─ Prompt preview logging (500 chars)

Layer 3: GUARDIAN PRE-FLIGHT
├─ Safety Envelope constraints
├─ Budget verification
├─ Actor authorization
├─ Tenant isolation
└─ Model access control

Layer 4: GRAPH VERIFICATION
├─ Source node registered
├─ Target reachable
├─ Route confidence >= 0.8
└─ Guardian approval flag

Layer 5: TRANSPORT SECURITY
├─ TLS 1.3 to all providers
├─ API key from vault (not env)
├─ Request signing (where supported)
└─ Response validation

Layer 6: RESPONSE SANITIZATION
├─ Output size limits
├─ Dangerous content filtering
├─ Code execution prevention
└─ Audit logging
```

### 11.2 Content Inspector

```elixir
defmodule Indrajaal.AI.Security.ContentInspector do
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
    ~r/`[^`]+`/,

    # Credential Patterns
    ~r/api[_-]?key\s*[=:]\s*[a-zA-Z0-9]{20,}/i,
    ~r/(password|passwd|pwd)\s*[=:]\s*[^\s]{8,}/i,
    ~r/bearer\s+[a-zA-Z0-9\-_.~+\/]+=*/i
  ]

  @pii_patterns [
    ~r/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/,
    ~r/\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/,
    ~r/\b\d{3}-\d{2}-\d{4}\b/,
    ~r/\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/
  ]

  @spec inspect_prompt(String.t()) :: {:ok, :clean} | {:error, {:forbidden, String.t()}}
  def inspect_prompt(prompt) do
    with :ok <- check_forbidden_patterns(prompt),
         :ok <- check_pii(prompt) do
      {:ok, :clean}
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
      Logger.warning("[ContentInspector] PII detected in prompt")
    end
    :ok
  end
end
```

### 11.3 Two-Key Turn Authorization

```elixir
defmodule Indrajaal.AI.Security.TwoKeyTurn do
  @high_risk_thresholds %{
    cost_usd: 1.00,
    tokens: 10_000,
    models: ["openai/o1-preview", "anthropic/claude-3-opus"]
  }

  @spec requires_two_key?(map()) :: boolean()
  def requires_two_key?(proposal) do
    cond do
      proposal.estimated_cost_usd > @high_risk_thresholds.cost_usd -> true
      proposal.model in @high_risk_thresholds.models -> true
      proposal.intent == :reason -> true
      Application.get_env(:indrajaal, :env) == :prod -> proposal.estimated_cost_usd > 0.50
      true -> false
    end
  end

  @spec authorize(map(), map()) :: {:ok, :authorized} | {:error, :unauthorized}
  def authorize(proposal, context) do
    with {:ok, :actor_authorized} <- check_actor_permission(proposal, context),
         {:ok, :system_authorized} <- check_system_permission(proposal) do
      {:ok, :authorized}
    end
  end
end
```

### 11.4 Audit Logging

```elixir
defmodule Indrajaal.AI.Security.AuditLog do
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

---

## 12. LLM Operations (Level 5)

### 12.1 ShadowMode Evaluation

```elixir
defmodule Indrajaal.AI.Evolution.ShadowMode do
  @spec execute_with_shadow(map(), keyword()) :: {:ok, map()}
  def execute_with_shadow(request, opts \\ []) do
    shadow_model = Keyword.get(opts, :shadow_model)

    # Primary execution
    primary_task = Task.async(fn ->
      SimplexController.execute(request, opts)
    end)

    # Shadow execution
    shadow_task = if shadow_model do
      Task.async(fn ->
        shadow_request = %{request | model: shadow_model, is_shadow: true}
        SimplexController.execute(shadow_request, opts)
      end)
    end

    primary_result = Task.await(primary_task, 120_000)

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

    TrainingGym.record_episode(episode)
  end
end
```

### 12.2 TrainingGym Feedback Loop

```elixir
defmodule Indrajaal.AI.Evolution.TrainingGym do
  use GenServer

  defstruct [
    episodes: [],
    model_scores: %{},
    intent_success_rates: %{},
    last_learning_cycle: nil
  ]

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

  def handle_cast(:learn, state) do
    learnings = analyze_episodes(state.episodes)
    publish_learnings(learnings)

    {:noreply, %{state |
      last_learning_cycle: DateTime.utc_now(),
      episodes: []
    }}
  end

  defp analyze_episodes(episodes) do
    %{
      total_episodes: length(episodes),
      success_rate: calculate_success_rate(episodes),
      divergence_rate: calculate_divergence_rate(episodes),
      top_performing_models: top_models(episodes),
      struggling_intents: struggling_intents(episodes)
    }
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

### 12.3 GDE Integration

```elixir
defmodule Indrajaal.AI.GDEIntegration do
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
end
```

### 12.4 Key System Operations Using LLMs

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

---

## 13. CEPAF F# Integration

### 13.1 Domain.fs TelemetryEvent Updates

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

// MCP Events
type MCPTelemetryEvent =
    | McpToolCall of tool: string * args: string * source: string
    | McpToolResult of tool: string * success: bool * durationMs: int64
    | McpGuardianCheck of tool: string * approved: bool * reason: string option
    | McpProviderRoute of tool: string * provider: string * model: string
```

### 13.2 Ash Notifier for CEPAF

```elixir
# lib/indrajaal/ai/notifiers/cepaf_notifier.ex
defmodule Indrajaal.AI.Notifiers.CepafNotifier do
  @moduledoc """
  Ash Notifier that bridges MCP tool calls to CEPAF telemetry.
  """

  use Ash.Notifier

  alias Indrajaal.Integration.CepafZenohBridge

  @impl true
  def notify(%Ash.Notifier.Notification{} = notification) do
    action = notification.action.name
    resource = notification.resource

    CepafZenohBridge.publish_event(
      "mcp",
      to_string(action),
      %{
        resource: to_string(resource),
        action: action,
        timestamp: DateTime.utc_now(),
        success: notification.data != nil
      }
    )

    :ok
  end
end
```

---

## 14. STAMP Constraints (Complete)

### 14.1 Control Flow Constraints

| ID | Constraint | Enforcement |
|----|------------|-------------|
| SC-NEURO-001 | All AI routes through Guardian | `guardian_pre_flight/1` mandatory |
| SC-NEURO-002 | No bypass of Simplex | All entry points use `SimplexController.execute/2` |
| SC-GUARD-001 | Guardian uses Envelope | `Guardian.validate_proposal/1` checks `Envelope.*` |
| SC-GUARD-002 | Fail closed on Guardian unavailable | `rescue` clause returns error |
| SC-GVF-001 | Graph verification after Guardian | `graph_verification/1` runs post-approval |
| SC-GVF-003 | Synapse exclusivity | Route ownership verification |
| SC-GVF-004 | Confidence threshold | Routes require confidence >= 0.8 |

### 14.2 Data Flow Constraints

| ID | Constraint | Enforcement |
|----|------------|-------------|
| SC-DF-001 | All requests get unique ID | `generate_request_id/0` |
| SC-DF-002 | Response includes usage metrics | Provider parsers extract usage |
| SC-DF-003 | Cost calculated for all responses | `CostMonitor.record_usage/3` |
| SC-DF-004 | Telemetry emitted for all events | `TelemetryFlow.emit_ai_event/3` |
| SC-DF-005 | Zenoh streaming async | `spawn/1` for non-blocking |
| SC-DF-006 | CEPAF receives all AI events | `CepafClient.send_telemetry/1` |
| SC-DF-007 | Key expressions follow schema | Zenoh subscriber validation |

### 14.3 AI/OpenRouter Constraints

| ID | Constraint | Enforcement |
|----|------------|-------------|
| SC-AI-001 | Request ID for all operations | `generate_request_id/0` |
| SC-AI-002 | Telemetry for all outcomes | `emit_*_telemetry/2` |
| SC-AI-004 | Budget enforced before API calls | `CostMonitor.check_budget_and_rate/2` |
| SC-AI-005 | Rate limits prevent exhaustion | Requests/minute counter |
| SC-AI-006 | Model registry refresh < 1 hour | Periodic GenServer refresh |
| SC-AI-007 | Intent routing fallback | IntentRouter fallback_tier |
| SC-AI-008 | Cost alerts at threshold | 75%/90% budget alerts |
| SC-AI-009 | Free tier for triage | `CostOptimizer.intent_to_model/3` |
| SC-AI-010 | All costs recorded to Zenoh | `emit_cost_telemetry/4` |
| SC-AI-011 | Monthly budget rollover | GenServer state reset |
| SC-AI-012 | Model downgrade on budget pressure | Conditional model selection |

### 14.4 MCP Constraints

| ID | Constraint | Enforcement |
|----|------------|-------------|
| SC-MCP-001 | All MCP tools require Guardian pre-flight | Ash policy |
| SC-MCP-002 | Read-only tools always allowed | Ash policy |
| SC-MCP-003 | Tool calls logged to Zenoh | CepafNotifier |
| SC-MCP-004 | Provider timeout enforced | ProviderDispatcher |
| SC-MCP-005 | Fallback chain required | ProviderDispatcher |
| SC-MCP-010 | All routing through Guardian | pre_flight_check |
| SC-MCP-011 | CEPAF telemetry on all calls | Ash notifier |
| SC-MCP-012 | Confidence threshold >= 0.6 | Guardian validation |
| SC-MCP-015 | Two-Key Turn for promotion | ShadowMode |
| SC-MCP-020 | HTTPS in production | Phoenix config |

### 14.5 Security Constraints

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

### 14.6 LLM Operations Constraints

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

## 15. Implementation Roadmap

### Phase 1: Foundation (Week 1)
- [ ] Add ash_ai, langchain dependencies
- [ ] Create Indrajaal.AI domain
- [ ] Implement ChatResource, AnalysisResource
- [ ] Configure Phoenix MCP router
- [ ] Create SimplexController
- [ ] Basic tests

### Phase 2: Full Resources (Week 2)
- [ ] Implement GenerationResource
- [ ] Implement SynapseResource
- [ ] Implement GDEResource
- [ ] Implement EvolutionResource
- [ ] Integration tests

### Phase 3: Safety & Infrastructure (Week 3)
- [ ] Implement SafetyResource
- [ ] Implement InfraResource
- [ ] Implement ProviderDispatcher
- [ ] Guardian integration in all resources
- [ ] CEPAF notifier
- [ ] ModelRegistry GenServer
- [ ] CostMonitor GenServer

### Phase 4: Security (Week 4)
- [ ] ContentInspector module
- [ ] TwoKeyTurn authorization
- [ ] AuditLog integration
- [ ] Forbidden pattern detection
- [ ] PII detection

### Phase 5: LLM Operations & Evolution (Week 5)
- [ ] IntentRouter enhancement
- [ ] ShadowMode implementation
- [ ] TrainingGym GenServer
- [ ] GDE integration
- [ ] Learning cycles

### Phase 6: Telemetry & Production (Week 6)
- [ ] Zenoh telemetry for all tools
- [ ] CEPAF bridge events
- [ ] Performance optimization
- [ ] Production configuration
- [ ] Documentation

---

## 16. Testing Strategy

### 16.1 Test Categories

```elixir
# test/indrajaal/ai/mcp_integration_test.exs
defmodule Indrajaal.AI.MCPIntegrationTest do
  use Indrajaal.DataCase

  describe "ChatResource MCP" do
    test "chat routes through Guardian"
    test "chat falls back on provider failure"
  end

  describe "SimplexController" do
    test "full pipeline: Guardian → Graph → Provider → Response"
    test "handles Guardian veto gracefully"
    test "handles provider timeout with fallback"
  end

  describe "CostMonitor" do
    test "tracks usage by model and source"
    test "blocks requests exceeding budget"
    test "sends alerts at threshold"
    test "enforces rate limits"
  end

  describe "ContentInspector" do
    test "detects injection patterns"
    test "detects PII patterns"
    test "passes clean prompts"
  end

  describe "ShadowMode" do
    test "shadow execution has no actuator access"
    test "records divergence episodes"
    test "promotion requires Two-Key Turn"
  end

  describe "TrainingGym" do
    test "records success episodes"
    test "records near-miss episodes"
    test "learning cycles publish to Zenoh"
  end
end
```

### 16.2 Property Tests

```elixir
describe "SimplexController properties" do
  property "all requests generate unique IDs" do
    check all(request <- request_generator()) do
      {:ok, result} = SimplexController.execute(request)
      assert String.starts_with?(result.request_id, "ai-")
    end
  end

  property "Guardian veto never results in API call" do
    check all(request <- forbidden_request_generator()) do
      {:error, {:guardian_veto, _, _}} = SimplexController.execute(request)
    end
  end
end
```

---

## 17. Configuration Reference

### 17.1 Application Configuration

```elixir
# config/config.exs
config :indrajaal, Indrajaal.AI,
  daily_budget: 50.0,
  monthly_budget: 1000.0

config :indrajaal, Indrajaal.OpenRouter,
  api_key: System.get_env("OPENROUTER_API_KEY"),
  budgets: %{
    daily_limit_usd: 10.0,
    monthly_limit_usd: 100.0,
    per_request_limit_usd: 1.0,
    alert_threshold_percent: 80
  },
  rate_limits: %{
    requests_per_minute: 100,
    tokens_per_minute: 100_000
  },
  registry: %{
    refresh_interval_ms: 3_600_000
  }

# config/dev.exs
config :indrajaal, Indrajaal.OpenRouter,
  budgets: %{daily_limit_usd: 5.0, monthly_limit_usd: 50.0}

# config/prod.exs
config :indrajaal, Indrajaal.OpenRouter,
  budgets: %{daily_limit_usd: 100.0, monthly_limit_usd: 1000.0}
```

### 17.2 Dependencies

```elixir
# mix.exs
defp deps do
  [
    {:ash_ai, "~> 0.4.0"},
    {:langchain, "~> 0.4"},
    {:req, "~> 0.5"}
  ]
end
```

---

## 18. Appendices

### 18.1 OpenRouter API Reference

```
GET https://openrouter.ai/api/v1/models
Authorization: Bearer {API_KEY}

Response:
{
  "data": [
    {
      "id": "anthropic/claude-3.5-sonnet",
      "name": "Claude 3.5 Sonnet",
      "pricing": {"prompt": "0.003", "completion": "0.015"},
      "context_length": 200000
    }
  ]
}
```

### 18.2 Routing Suffixes

- `:nitro` - Speed-optimized routing
- `:floor` - Cost-optimized routing
- `:free` - Free tier only

### 18.3 MCP Tools Summary

```
# Chat & Core (2)
ai_chat, ai_chat_with_intent

# Analysis (4)
analyze_codebase, analyze_error_logs, extract_patterns, analyze_threat

# Generation (3)
generate_code, generate_fix, reason_about_problem

# Synapse (4)
solve_problem, analyze_and_fix, solve_with_gde, get_synapse_state

# GDE (4)
generate_ai_proposals, execute_gde_cycle, validate_fix, enhance_proposal

# Evolution (9)
register_shadow_model, execute_shadow, compare_with_production,
request_promotion, confirm_promotion, record_training_episode,
get_training_data, get_shadow_stats, get_gym_stats

# Safety (5)
validate_proposal, multi_ai_validate, verify_routing, pre_flight_check, get_guardian_status

# Infrastructure (7)
list_containers, inspect_container, container_health, health_summary,
ooda_trigger_cycle, ooda_status, fractal_emit

# TOTAL: 45+ MCP Tools
```

### 18.4 Migration Checklist

- [ ] Create `lib/indrajaal/ai.ex` - Domain
- [ ] Create `lib/indrajaal/ai/resources/*.ex` - 8 resources
- [ ] Create `lib/indrajaal/ai/simplex_controller.ex` - Controller
- [ ] Create `lib/indrajaal/ai/provider_dispatcher.ex` - Routing
- [ ] Create `lib/indrajaal/openrouter/model_registry.ex` - Registry
- [ ] Create `lib/indrajaal/openrouter/intent_router.ex` - Intent
- [ ] Create `lib/indrajaal/openrouter/cost_monitor.ex` - Costs
- [ ] Create `lib/indrajaal/ai/pricing.ex` - Pricing
- [ ] Create `lib/indrajaal/ai/security/*.ex` - Security
- [ ] Create `lib/indrajaal/ai/evolution/*.ex` - Evolution
- [ ] Create `lib/indrajaal/ai/notifiers/cepaf_notifier.ex` - Telemetry
- [ ] Update Phoenix router
- [ ] Update CEPAF Domain.fs
- [ ] Update Claude Code settings
- [ ] Write comprehensive tests
- [ ] Update documentation

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0-MASTER | 2025-12-27 | Cybernetic Architect | Initial master specification collating all documents |

---

**End of Document**
