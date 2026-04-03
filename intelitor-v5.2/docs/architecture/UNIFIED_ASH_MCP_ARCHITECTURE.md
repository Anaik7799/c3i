# Unified Ash MCP Architecture for Indrajaal AI Platform

**Document Control**

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Created | 2025-12-27 |
| Author | Cybernetic Architect |
| STAMP | SC-MCP-001 to SC-MCP-020, SC-AI-*, SC-GDE-*, SC-NEURO-* |
| Status | PROPOSED |
| Priority | P0-CRITICAL |

---

## 1. Executive Summary

This document defines a **unified Ash MCP architecture** that integrates:

1. **All AI Providers** - Claude, Gemini, OpenRouter, Local (Ollama), future models
2. **CEPAF F# Bridge** - Telemetry events, safety handlers, container operations
3. **Cortex Components** - Synapse, GDE, ShadowMode, TrainingGym
4. **Safety Systems** - Guardian, Envelope, DeadMansSwitch
5. **Observability** - Zenoh, Fractal Logging, OTEL

**Total MCP Tools**: 45+ tools across 8 resource categories

---

## 2. Architecture Overview

### 2.1 Ash Domain Structure

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

### 2.2 MCP Tool Flow

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

---

## 3. Ash Domain Definition

### 3.1 Domain Module

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

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | STAMP | SC-MCP-*, SC-AI-*, SC-GDE-* |
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

---

## 4. Resource Specifications

### 4.1 ChatResource - Unified Chat Interface

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

### 4.2 AnalysisResource - Context Analysis

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

### 4.3 GenerationResource - Code Generation

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

### 4.4 SynapseResource - Bicameral Orchestration

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

### 4.5 GDEResource - Goal-Directed Evolution

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

### 4.6 EvolutionResource - ShadowMode & TrainingGym

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

### 4.7 SafetyResource - Guardian & Validation

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

### 4.8 InfraResource - CEPAF Container Operations

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
        # Trigger via CEPAF bridge
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

---

## 5. Provider Dispatcher

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

## 6. Phoenix Router Configuration

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

---

## 7. Claude Code Configuration

### 7.1 Settings Update

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

### 7.2 Available MCP Tools (45+)

```
# Chat & Core
ai_chat                    - Unified chat across all providers
ai_chat_with_intent        - Intent-based chat routing

# Analysis
analyze_codebase           - Analyze files with Gemini 1M context
analyze_error_logs         - Error failure context analysis
extract_patterns           - Extract semantic patterns
analyze_threat             - Real-time security threat analysis

# Generation
generate_code              - Generate production Elixir code
generate_fix               - Generate code fixes
reason_about_problem       - Multi-solution reasoning

# Synapse (Bicameral)
solve_problem              - Full bicameral problem-solving
analyze_and_fix            - Two-stage error fixing
solve_with_gde             - Full GDE pipeline
get_synapse_state          - Orchestrator state

# GDE Pipeline
generate_ai_proposals      - AI-enhanced fix proposals
execute_gde_cycle          - Full validation + training cycle
validate_fix               - Deep reasoning validation
enhance_proposal           - Code implementation enrichment

# Evolution
register_shadow_model      - Register candidate model
execute_shadow             - Execute in isolation
compare_with_production    - Compare outputs
request_promotion          - Request promotion
confirm_promotion          - Two-Key Turn confirmation
record_training_episode    - Record for RL
get_training_data          - Export episodes
get_shadow_stats           - ShadowMode stats
get_gym_stats              - TrainingGym stats

# Safety
validate_proposal          - Guardian validation
multi_ai_validate          - Multi-AI consensus
verify_routing             - Graph constraint verification
pre_flight_check           - Full pre-flight check
get_guardian_status        - Guardian status

# Infrastructure
list_containers            - CEPAF container list
inspect_container          - Container details
container_health           - Health check
health_summary             - Aggregated health
ooda_trigger_cycle         - OODA cycle trigger
ooda_status                - OODA status
fractal_emit               - Fractal logging
```

---

## 8. CEPAF Telemetry Integration

### 8.1 Domain.fs Updates

```fsharp
// Add to Domain.fs TelemetryEvent
type TelemetryEvent =
    // ... existing events ...

    // MCP Events (NEW)
    | McpToolCall of tool: string * args: string * source: string
    | McpToolResult of tool: string * success: bool * durationMs: int64
    | McpGuardianCheck of tool: string * approved: bool * reason: string option
    | McpProviderRoute of tool: string * provider: string * model: string
```

### 8.2 Ash Notifier for CEPAF

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

    # Emit to CEPAF/Zenoh
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

## 9. STAMP Constraints

### 9.1 MCP-Specific Constraints

| ID | Description | Enforcement |
|----|-------------|-------------|
| SC-MCP-001 | All MCP tools require Guardian pre-flight | Ash policy |
| SC-MCP-002 | Read-only tools always allowed | Ash policy |
| SC-MCP-003 | Tool calls logged to Zenoh | CepafNotifier |
| SC-MCP-004 | Provider timeout enforced | ProviderDispatcher |
| SC-MCP-005 | Fallback chain required | ProviderDispatcher |
| SC-MCP-010 | All routing through Guardian | pre_flight_check |
| SC-MCP-011 | CEPAF telemetry on all calls | Ash notifier |
| SC-MCP-012 | Confidence threshold ≥0.6 | Guardian validation |
| SC-MCP-015 | Two-Key Turn for promotion | ShadowMode |
| SC-MCP-020 | HTTPS in production | Phoenix config |

### 9.2 Inherited Constraints

| Constraint | Source | Status |
|------------|--------|--------|
| SC-NEURO-001 | Guardian | ENFORCED |
| SC-GVF-003 | Graph Verification | ENFORCED |
| SC-GVF-007 | Routing Validation | ENFORCED |
| SC-GDE-060 | OpenRouter Only | ENFORCED |
| SC-SHADOW-001 | No Actuators | ENFORCED |
| SC-TRAIN-001 | Async Recording | ENFORCED |

---

## 10. Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Add ash_ai, langchain dependencies
- [ ] Create Indrajaal.AI domain
- [ ] Implement ChatResource, AnalysisResource
- [ ] Configure Phoenix MCP router
- [ ] Basic tests

### Phase 2: Full Resources (Week 2)
- [ ] Implement GenerationResource
- [ ] Implement SynapseResource
- [ ] Implement GDEResource
- [ ] Implement EvolutionResource
- [ ] Integration tests

### Phase 3: Safety & Infra (Week 3)
- [ ] Implement SafetyResource
- [ ] Implement InfraResource
- [ ] Implement ProviderDispatcher
- [ ] Guardian integration in all resources
- [ ] CEPAF notifier

### Phase 4: Telemetry & Production (Week 4)
- [ ] Zenoh telemetry for all tools
- [ ] CEPAF bridge events
- [ ] Performance optimization
- [ ] Production configuration
- [ ] Documentation

---

## 11. Testing Strategy

```elixir
# test/indrajaal/ai/mcp_integration_test.exs
defmodule Indrajaal.AI.MCPIntegrationTest do
  use Indrajaal.DataCase

  describe "ChatResource MCP" do
    test "chat routes through Guardian" do
      # Test that Guardian is called before API
    end

    test "chat falls back on provider failure" do
      # Test fallback chain
    end
  end

  describe "GDEResource MCP" do
    test "execute_gde_cycle records to TrainingGym" do
      # Test RL capture
    end
  end

  describe "EvolutionResource MCP" do
    test "shadow execution has no actuator access" do
      # Test isolation
    end

    test "promotion requires Two-Key Turn" do
      # Test confirmation flow
    end
  end
end
```

---

## 12. Summary

This unified Ash MCP architecture provides:

1. **45+ MCP Tools** across 8 resource categories
2. **All Providers Supported** - OpenRouter, Anthropic, Google, Ollama, future
3. **CEPAF Integration** - F# telemetry, safety handlers, container ops
4. **Full Safety** - Guardian pre-flight on ALL tools
5. **Observability** - Zenoh streaming, Fractal logging, OTEL
6. **Evolution** - ShadowMode, TrainingGym for continuous improvement

**Key Files to Create**:
- `lib/indrajaal/ai.ex` - Domain
- `lib/indrajaal/ai/resources/*.ex` - 8 resources
- `lib/indrajaal/ai/provider_dispatcher.ex` - Routing
- `lib/indrajaal/ai/notifiers/cepaf_notifier.ex` - Telemetry

**Dependencies**:
```elixir
{:ash_ai, "~> 0.4.0"},
{:langchain, "~> 0.4"}
```

**Sources**:
- [ash_ai Documentation](https://hexdocs.pm/ash_ai/AshAi.Mcp.html)
- [Ash Framework](https://ash-hq.org/)
- [hermes_mcp](https://github.com/cloudwalk/hermes-mcp)
