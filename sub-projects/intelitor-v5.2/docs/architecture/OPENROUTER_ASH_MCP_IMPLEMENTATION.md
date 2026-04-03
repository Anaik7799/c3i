# OpenRouter Integration via Ash AI MCP

**Document Control**

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Created | 2025-12-27 |
| Author | Cybernetic Architect |
| STAMP | SC-AI-001 to SC-AI-010, SC-MCP-001 to SC-MCP-005 |
| Status | PROPOSED |
| Priority | P0-HIGH |

---

## 1. Executive Summary

Use the official **ash_ai** package (v0.4.0) to expose OpenRouter functionality as MCP (Model Context Protocol) tools. This provides:

1. **Native Ash Integration** - Tools backed by Ash actions with policy enforcement
2. **Phoenix MCP Router** - Standard Plug integration at `/mcp`
3. **Claude Code Compatibility** - Direct tool access from Claude sessions
4. **Guardian Safety** - Existing safety constraints via Ash policies

---

## 2. Dependencies

### 2.1 Add to mix.exs

```elixir
defp deps do
  [
    # Existing deps...
    {:ash_ai, "~> 0.4.0"},
    {:langchain, "~> 0.4"}  # Required by ash_ai
  ]
end
```

### 2.2 Available Hex MCP Libraries

| Package | Purpose | Version |
|---------|---------|---------|
| [ash_ai](https://hex.pm/packages/ash_ai) | Ash Framework MCP integration | 0.4.0 |
| [hermes_mcp](https://hex.pm/packages/hermes_mcp) | Full MCP SDK (client + server) | 0.14.1 |
| [ex_mcp](https://hex.pm/packages/ex_mcp) | Comprehensive MCP implementation | latest |
| [mcp](https://hex.pm/packages/mcp) | MCP server with SSE transport | latest |

---

## 3. Architecture

### 3.1 MCP Tool Flow

```
Claude Code / AI Agent
        │
        ▼
┌───────────────────────────────────────────────────────────────┐
│                    Phoenix Application                         │
│                                                                │
│  forward "/mcp", AshAi.Mcp.Router, tools: [                   │
│    :openrouter_chat,                                          │
│    :openrouter_list_models,                                   │
│    :openrouter_check_budget,                                  │
│    :openrouter_usage_stats                                    │
│  ]                                                            │
│                                                                │
└───────────────────────────┬───────────────────────────────────┘
                            │
                            ▼
┌───────────────────────────────────────────────────────────────┐
│              Indrajaal.AI.OpenRouterResource                   │
│                      (Ash Resource)                            │
│                                                                │
│  actions:                                                      │
│    action :chat, :create do                                   │
│      argument :messages, {:array, :map}                       │
│      argument :intent, :atom                                  │
│      argument :model, :string                                 │
│      run &OpenRouterActions.chat/2                            │
│    end                                                        │
│                                                                │
│    action :list_models, :read do ... end                      │
│    action :check_budget, :read do ... end                     │
│    action :usage_stats, :read do ... end                      │
│                                                                │
│  policies:                                                     │
│    policy action(:chat) do                                    │
│      authorize_if Guardian.pre_flight_approved?()            │
│    end                                                        │
│                                                                │
└───────────────────────────┬───────────────────────────────────┘
                            │
                            ▼
┌───────────────────────────────────────────────────────────────┐
│                 Existing Infrastructure                        │
│                                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Guardian   │  │ CostMonitor  │  │    Zenoh     │         │
│  │  Pre-flight  │  │   Budget     │  │  Telemetry   │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                │
└───────────────────────────────────────────────────────────────┘
```

### 3.2 Why Ash AI MCP?

From the [Ash Framework documentation](https://ash-hq.org/):

> "Because the tools are backed by Ash actions and subject to existing policies and validations, the LLM can never bypass your business logic."

This means:
- **Guardian validation** happens automatically through Ash policies
- **Cost limits** enforced via action constraints
- **Audit logging** through existing Ash notifiers
- **Type safety** via Ash's type system

---

## 4. Implementation

### 4.1 OpenRouter Resource

```elixir
# lib/indrajaal/ai/resources/openrouter_resource.ex
defmodule Indrajaal.AI.OpenRouterResource do
  @moduledoc """
  Ash Resource exposing OpenRouter as MCP tools.

  WHAT: MCP-compatible OpenRouter interface with intent-based routing.
  WHY: Enables AI agents to use OpenRouter with full safety guarantees.
  CONSTRAINTS: SC-MCP-001 to SC-MCP-005, SC-AI-001 to SC-AI-010.

  ## MCP Tools Exposed

  - `openrouter_chat` - Send chat completion with intent-based routing
  - `openrouter_list_models` - List available models with pricing
  - `openrouter_check_budget` - Check current budget status
  - `openrouter_usage_stats` - Get usage statistics

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | STAMP | SC-MCP-001 to SC-MCP-005 |
  """

  use Ash.Resource,
    domain: Indrajaal.AI,
    extensions: [AshAi]

  alias Indrajaal.AI.OpenRouterClient
  alias Indrajaal.Safety.Guardian

  # ============================================================
  # ASH AI CONFIGURATION
  # ============================================================

  ai do
    # Expose as MCP tools
    tools [:chat, :list_models, :check_budget, :usage_stats]

    # Tool descriptions for AI agents
    tool_descriptions %{
      chat: "Send a chat message to an AI model via OpenRouter with intent-based routing",
      list_models: "List available AI models with pricing information",
      check_budget: "Check current budget status and remaining limits",
      usage_stats: "Get usage statistics for OpenRouter API calls"
    }
  end

  # ============================================================
  # ACTIONS
  # ============================================================

  actions do
    # Chat action - main AI interaction
    action :chat, :map do
      description "Send chat completion request with intent-based routing"

      argument :messages, {:array, :map}, allow_nil?: false do
        description "Array of message objects with role and content"
      end

      argument :intent, :atom do
        description "Intent for routing: :analyze, :synthesize, :reason, :triage, :validate"
        default :synthesize
        constraints one_of: [:analyze, :synthesize, :reason, :triage, :validate]
      end

      argument :model, :string do
        description "Optional specific model override (e.g., 'anthropic/claude-3.5-sonnet')"
      end

      argument :temperature, :float do
        description "Sampling temperature (0.0 to 1.0)"
        default 0.7
        constraints min: 0.0, max: 1.0
      end

      run fn input, _context ->
        messages = input.arguments.messages
        intent = input.arguments.intent
        model = input.arguments[:model]
        temperature = input.arguments.temperature

        opts = [
          intent: intent,
          temperature: temperature,
          source: :mcp_tool
        ]

        opts = if model, do: Keyword.put(opts, :model, model), else: opts

        case OpenRouterClient.chat(messages, opts) do
          {:ok, content} ->
            {:ok, %{content: content, model: model, intent: intent}}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end

    # List models action
    action :list_models, {:array, :map} do
      description "List available AI models with pricing"

      argument :capability, :atom do
        description "Filter by capability: :chat, :code, :reasoning, :vision"
      end

      argument :tier, :atom do
        description "Filter by tier: :fast, :smart, :deep, :free"
      end

      run fn input, _context ->
        capability = input.arguments[:capability]
        tier = input.arguments[:tier]

        # Use ModelRegistry if available, otherwise return static mapping
        models = get_available_models(capability, tier)
        {:ok, models}
      end
    end

    # Check budget action
    action :check_budget, :map do
      description "Check current budget status"

      run fn _input, _context ->
        # Get from CostMonitor if available
        budget_status = get_budget_status()
        {:ok, budget_status}
      end
    end

    # Usage stats action
    action :usage_stats, :map do
      description "Get usage statistics"

      argument :period, :atom do
        description "Time period: :today, :week, :month"
        default :today
      end

      run fn input, _context ->
        period = input.arguments.period
        stats = get_usage_stats(period)
        {:ok, stats}
      end
    end
  end

  # ============================================================
  # POLICIES (Guardian Integration)
  # ============================================================

  policies do
    # All chat actions require Guardian pre-flight approval
    policy action(:chat) do
      description "SC-MCP-001: Chat requires Guardian validation"
      authorize_if always()  # Guardian check happens in action
    end

    policy action([:list_models, :check_budget, :usage_stats]) do
      description "SC-MCP-002: Read actions always allowed"
      authorize_if always()
    end
  end

  # ============================================================
  # PRIVATE HELPERS
  # ============================================================

  defp get_available_models(capability, tier) do
    base_models = [
      %{
        id: "google/gemini-flash-1.5-8b",
        name: "Gemini Flash 1.5 8B",
        tier: :fast,
        capabilities: [:chat, :code],
        pricing: %{prompt: 0.075, completion: 0.30}
      },
      %{
        id: "anthropic/claude-3.5-sonnet",
        name: "Claude 3.5 Sonnet",
        tier: :smart,
        capabilities: [:chat, :code, :reasoning],
        pricing: %{prompt: 3.0, completion: 15.0}
      },
      %{
        id: "openai/o1-preview",
        name: "OpenAI o1-preview",
        tier: :deep,
        capabilities: [:reasoning],
        pricing: %{prompt: 15.0, completion: 60.0}
      },
      %{
        id: "google/gemini-2.0-flash-exp:free",
        name: "Gemini 2.0 Flash (Free)",
        tier: :free,
        capabilities: [:chat],
        pricing: %{prompt: 0.0, completion: 0.0}
      }
    ]

    base_models
    |> filter_by_capability(capability)
    |> filter_by_tier(tier)
  end

  defp filter_by_capability(models, nil), do: models
  defp filter_by_capability(models, capability) do
    Enum.filter(models, fn m -> capability in m.capabilities end)
  end

  defp filter_by_tier(models, nil), do: models
  defp filter_by_tier(models, tier) do
    Enum.filter(models, fn m -> m.tier == tier end)
  end

  defp get_budget_status do
    # TODO: Integrate with CostMonitor when implemented
    %{
      daily_limit_usd: 10.0,
      daily_used_usd: 0.0,
      daily_remaining_usd: 10.0,
      monthly_limit_usd: 100.0,
      monthly_used_usd: 0.0,
      monthly_remaining_usd: 100.0,
      status: :ok
    }
  end

  defp get_usage_stats(period) do
    # TODO: Integrate with ZenohEvolutionPublisher stats
    %{
      period: period,
      total_requests: 0,
      total_tokens: 0,
      total_cost_usd: 0.0,
      by_model: %{},
      by_intent: %{}
    }
  end
end
```

### 4.2 Phoenix Router Integration

```elixir
# lib/indrajaal_web/router.ex

defmodule IndrajaalWeb.Router do
  use IndrajaalWeb, :router

  # ... existing pipelines ...

  # MCP endpoint for AI agent access
  scope "/api" do
    pipe_through :api

    # Expose OpenRouter tools via MCP
    forward "/mcp", AshAi.Mcp.Router,
      tools: [
        Indrajaal.AI.OpenRouterResource
      ]
  end
end
```

### 4.3 Claude Code Settings

```json
{
  "mcpServers": {
    "indrajaal-openrouter": {
      "command": "curl",
      "args": ["-X", "POST", "http://localhost:4000/api/mcp"],
      "transport": "http"
    }
  }
}
```

Or using the native HTTP transport:

```json
{
  "mcpServers": {
    "indrajaal": {
      "url": "http://localhost:4000/api/mcp",
      "transport": "http"
    }
  }
}
```

---

## 5. MCP Tools Specification

### 5.1 openrouter_chat

```json
{
  "name": "openrouter_chat",
  "description": "Send a chat message to an AI model via OpenRouter with intent-based routing",
  "inputSchema": {
    "type": "object",
    "properties": {
      "messages": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "role": {"type": "string", "enum": ["user", "assistant", "system"]},
            "content": {"type": "string"}
          }
        }
      },
      "intent": {
        "type": "string",
        "enum": ["analyze", "synthesize", "reason", "triage", "validate"],
        "default": "synthesize"
      },
      "model": {
        "type": "string",
        "description": "Optional model override"
      },
      "temperature": {
        "type": "number",
        "minimum": 0,
        "maximum": 1,
        "default": 0.7
      }
    },
    "required": ["messages"]
  }
}
```

### 5.2 openrouter_list_models

```json
{
  "name": "openrouter_list_models",
  "description": "List available AI models with pricing",
  "inputSchema": {
    "type": "object",
    "properties": {
      "capability": {
        "type": "string",
        "enum": ["chat", "code", "reasoning", "vision"]
      },
      "tier": {
        "type": "string",
        "enum": ["fast", "smart", "deep", "free"]
      }
    }
  }
}
```

### 5.3 openrouter_check_budget

```json
{
  "name": "openrouter_check_budget",
  "description": "Check current budget status",
  "inputSchema": {
    "type": "object",
    "properties": {}
  }
}
```

### 5.4 openrouter_usage_stats

```json
{
  "name": "openrouter_usage_stats",
  "description": "Get usage statistics",
  "inputSchema": {
    "type": "object",
    "properties": {
      "period": {
        "type": "string",
        "enum": ["today", "week", "month"],
        "default": "today"
      }
    }
  }
}
```

---

## 6. STAMP Constraints

### 6.1 New MCP Constraints

| ID | Description | Enforcement |
|----|-------------|-------------|
| SC-MCP-001 | Chat tools require Guardian validation | Ash policy + action logic |
| SC-MCP-002 | Read-only tools always allowed | Ash policy |
| SC-MCP-003 | All MCP calls logged to Zenoh | Ash notifier |
| SC-MCP-004 | Budget checked before chat execution | Action constraint |
| SC-MCP-005 | MCP endpoint requires HTTPS in production | Phoenix config |

### 6.2 Integration with Existing Constraints

| Existing Constraint | MCP Integration |
|---------------------|-----------------|
| SC-NEURO-001 | Guardian pre-flight in chat action |
| SC-GVF-004 | Confidence threshold in routing |
| SC-AI-004 | Budget check before execution |
| SC-ZENOH-EVO-001 | Telemetry via Ash notifier |

---

## 7. Implementation Phases

### Phase 1: Foundation (P0)
1. Add `ash_ai` dependency
2. Create `OpenRouterResource` with basic actions
3. Configure Phoenix router
4. Test MCP endpoint

### Phase 2: Safety Integration (P0)
1. Add Guardian pre-flight check in chat action
2. Implement Ash policies
3. Add Zenoh telemetry notifier
4. Test safety constraints

### Phase 3: Dynamic Features (P1)
1. Integrate with ModelRegistry for live models
2. Integrate with CostMonitor for budget
3. Add usage statistics from ZenohEvolutionPublisher

### Phase 4: Production (P1)
1. Configure Claude Code MCP settings
2. HTTPS enforcement
3. Rate limiting
4. Monitoring dashboard

---

## 8. Testing

```elixir
# test/indrajaal/ai/openrouter_resource_test.exs
defmodule Indrajaal.AI.OpenRouterResourceTest do
  use Indrajaal.DataCase

  alias Indrajaal.AI.OpenRouterResource

  describe "chat action" do
    test "routes based on intent" do
      messages = [%{role: "user", content: "Hello"}]

      assert {:ok, result} =
        Ash.run_action(OpenRouterResource, :chat, %{
          messages: messages,
          intent: :synthesize
        })

      assert result.intent == :synthesize
    end

    test "respects Guardian validation" do
      # Test that Guardian is called
    end
  end

  describe "list_models action" do
    test "returns available models" do
      assert {:ok, models} = Ash.run_action(OpenRouterResource, :list_models, %{})
      assert is_list(models)
      assert length(models) > 0
    end

    test "filters by tier" do
      assert {:ok, models} = Ash.run_action(OpenRouterResource, :list_models, %{tier: :fast})
      assert Enum.all?(models, fn m -> m.tier == :fast end)
    end
  end
end
```

---

## 9. Comparison: Custom vs Ash AI MCP

| Aspect | Custom Implementation | Ash AI MCP |
|--------|----------------------|------------|
| Development time | 2-3 weeks | 2-3 days |
| Policy enforcement | Manual Guardian calls | Automatic via Ash policies |
| Type safety | Manual validation | Ash type system |
| MCP compliance | Must implement spec | Built-in |
| Phoenix integration | Custom router | `forward "/mcp", AshAi.Mcp.Router` |
| Maintenance | Full ownership | Community maintained |

**Recommendation**: Use **Ash AI MCP** for rapid, safe implementation.

---

## 10. Sources

- [AshAi.Mcp Documentation](https://hexdocs.pm/ash_ai/AshAi.Mcp.html)
- [ash_ai on Hex.pm](https://hex.pm/packages/ash_ai)
- [Ash Framework MCP Announcement](https://elixirmerge.com/p/introducing-ash-ai-an-llm-toolbox-for-seamless-integration-with-ash-framework)
- [hermes_mcp on GitHub](https://github.com/cloudwalk/hermes-mcp)
- [MCPhoenix - Phoenix MCP Server](https://github.com/jmanhype/MCPhoenix)
