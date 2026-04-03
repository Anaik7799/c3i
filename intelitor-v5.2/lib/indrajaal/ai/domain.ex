defmodule Indrajaal.AIDomain do
  @moduledoc """
  AI Domain - Unified Artificial Intelligence Framework with MCP Support.

  ## Purpose

  Integrates OpenRouter-based AI models (Claude, Gemini, O1) with Ash resources for:
  - Real-time chat interface via ChatResource
  - Deep code/log analysis via AnalysisResource
  - Code generation with safety validation via GenerationResource
  - Multi-agent orchestration via SynapseResource

  ## Architecture

  ```
  ┌─────────────────────────────────────────────────────────────────────┐
  │                        Indrajaal.AIDomain                          │
  ├─────────────────────────────────────────────────────────────────────┤
  │                                                                     │
  │  ChatResource ───→ OpenRouter ───→ Zenoh Stream                    │
  │  AnalysisResource ───→ OpenRouter ───→ Guardian Validation         │
  │  GenerationResource ───→ OpenRouter ───→ Guardian Approval         │
  │  SynapseResource ───→ MCPRouter ───→ Multi-Model Coordination      │
  │                                                                     │
  └─────────────────────────────────────────────────────────────────────┘
  ```

  ## STAMP Constraints

  - SC-AI-001: All AI outputs validated with Guardian
  - SC-AI-002: Rate limiting enforced via OpenRouter
  - SC-AI-003: Cost tracking for all operations
  - SC-SEC-001: No code execution without Guardian approval
  - SC-NEURO-001: Simplex principle - Guardian gates all AI output

  ## Model Tiers

  - `:fast` - Gemini Flash 1.5 8B (quick operations, <1s)
  - `:smart` - Claude 3.5 Sonnet (code synthesis, reasoning)
  - `:deep` - OpenAI O1 Preview (complex analysis)

  ## Safety Integration

  - Guardian validates all responses before execution
  - Zenoh streams metrics to observability
  - Cost tracking prevents budget overrun
  - TrainingGym records near-miss and success episodes
  """

  use Ash.Domain,
    extensions: [AshJsonApi.Domain]

  resources do
    resource Indrajaal.AI.ChatResource
    resource Indrajaal.AI.AnalysisResource
    resource Indrajaal.AI.GenerationResource
    resource Indrajaal.AI.SynapseResource
  end

  authorization do
    authorize :by_default
  end
end
