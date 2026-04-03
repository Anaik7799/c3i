# OpenRouter Dynamic Manager Implementation Approach

**Document Control**

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Created | 2025-12-27 |
| Author | Cybernetic Architect |
| STAMP | SC-AI-001 to SC-AI-010, SC-NEURO-001, SC-GVF-* |
| Status | PROPOSED |
| Priority | P1-HIGH |

---

## 1. Executive Summary

This document defines the implementation approach for enhancing Indrajaal's OpenRouter integration from a **static gateway** to a **dynamic marketplace manager**. The system will treat OpenRouter as an intelligent routing layer with:

1. **Dynamic Model Registry** - Real-time model discovery and pricing
2. **Intent-Based Router** - Maps AI intents to optimal model/strategy
3. **Cost Monitor** - Budget enforcement and cost optimization
4. **CEPAF Integration** - F# bridge telemetry for cross-platform visibility

---

## 2. Current State Analysis

### 2.1 Existing Components

| Component | Location | Capability |
|-----------|----------|------------|
| `OpenRouterClient` | `lib/indrajaal/ai/open_router_client.ex` | Static 3-tier model mapping, Guardian pre-flight, Graph verification |
| `ClaudeInterface` | `lib/indrajaal/cortex/ai/claude_interface.ex` | Synthesis via `:smart` tier (Claude Sonnet) |
| `GeminiInterface` | `lib/indrajaal/cortex/ai/gemini_interface.ex` | Analysis via Gemini 1.5 Pro |
| `ZenohEvolutionPublisher` | `lib/indrajaal/observability/zenoh_evolution_publisher.ex` | OpenRouter call telemetry streaming |
| `Guardian` | `lib/indrajaal/safety/guardian.ex` | Pre-flight security validation |

### 2.2 Current Model Mapping (Static)

```elixir
# Current: Static tier-to-model mapping
@models %{
  fast: "google/gemini-flash-1.5-8b",
  smart: "anthropic/claude-3.5-sonnet",
  deep: "openai/o1-preview"
}
```

### 2.3 Gaps Identified

| Gap | Impact | Priority |
|-----|--------|----------|
| No dynamic model discovery | Cannot leverage new models automatically | P1 |
| No live pricing data | Cannot optimize for cost | P1 |
| No intent detection | Requires explicit model selection | P2 |
| No budget enforcement | Runaway costs possible | P1 |
| No routing strategies | Cannot use :nitro/:floor/:free suffixes | P2 |
| No rate limiting per model | API quota exhaustion risk | P2 |

---

## 3. Target Architecture

### 3.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       OPENROUTER DYNAMIC MANAGER                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐           │
│  │  ModelRegistry  │   │  IntentRouter   │   │   CostMonitor   │           │
│  │   (GenServer)   │   │  (Pure Logic)   │   │   (GenServer)   │           │
│  │                 │   │                 │   │                 │           │
│  │ • Live models   │   │ • Intent→Model  │   │ • Budget tracking│          │
│  │ • Pricing data  │   │ • Strategies    │   │ • Cost alerts    │          │
│  │ • Capabilities  │   │ • Fallbacks     │   │ • Rate limiting  │          │
│  └────────┬────────┘   └────────┬────────┘   └────────┬────────┘           │
│           │                     │                     │                     │
│           └──────────┬──────────┴──────────┬──────────┘                     │
│                      │                     │                                │
│                      ▼                     ▼                                │
│  ┌───────────────────────────────────────────────────────────────┐         │
│  │                    OpenRouterGateway                           │         │
│  │                                                                │         │
│  │  1. Intent Analysis (from caller context)                      │         │
│  │  2. Model Selection (via Registry + Router)                    │         │
│  │  3. Guardian Pre-Flight (SC-NEURO-001)                         │         │
│  │  4. Graph Verification (SC-GVF-*)                              │         │
│  │  5. API Call Execution                                         │         │
│  │  6. Cost Recording (via CostMonitor)                           │         │
│  │  7. Telemetry Streaming (via ZenohEvolutionPublisher)          │         │
│  └───────────────────────────────────────────────────────────────┘         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           EXISTING INTEGRATIONS                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐           │
│  │ ClaudeInterface │   │ GeminiInterface │   │   AIIntegration │           │
│  │   (Synthesis)   │   │   (Analysis)    │   │      (GDE)      │           │
│  └─────────────────┘   └─────────────────┘   └─────────────────┘           │
│                                                                             │
│  ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐           │
│  │    Guardian     │   │ ZenohEvolution  │   │   CEPAF Bridge  │           │
│  │  (Pre-flight)   │   │   Publisher     │   │  (F# Telemetry) │           │
│  └─────────────────┘   └─────────────────┘   └─────────────────┘           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Module Specifications

### 4.1 OpenRouter.ModelRegistry

**Purpose**: Maintains live model catalog with pricing and capabilities.

**Location**: `lib/indrajaal/openrouter/model_registry.ex`

**State Structure**:
```elixir
%{
  models: %{
    "anthropic/claude-3.5-sonnet" => %{
      id: "anthropic/claude-3.5-sonnet",
      name: "Claude 3.5 Sonnet",
      pricing: %{prompt: 3.0, completion: 15.0},  # per 1M tokens
      context_length: 200_000,
      capabilities: [:chat, :code, :reasoning],
      routing_options: [:nitro, :floor],
      last_updated: ~U[2025-12-27 04:00:00Z]
    },
    # ... other models
  },
  refresh_interval_ms: 3_600_000,  # 1 hour
  last_refresh: DateTime.t(),
  model_tiers: %{
    fast: ["google/gemini-flash-1.5-8b", "google/gemini-2.0-flash-exp"],
    smart: ["anthropic/claude-3.5-sonnet", "anthropic/claude-sonnet-4"],
    deep: ["openai/o1-preview", "anthropic/claude-3-opus"],
    free: ["google/gemini-2.0-flash-exp:free", "meta-llama/llama-3.1-8b-instruct:free"]
  }
}
```

**Key Functions**:
```elixir
# Fetch live models from OpenRouter API
@spec refresh_models() :: :ok | {:error, term()}

# Get optimal model for tier and strategy
@spec get_model(tier :: atom(), strategy :: atom()) :: {:ok, model_id()} | {:error, term()}

# Get pricing for a model
@spec get_pricing(model_id :: String.t()) :: {:ok, pricing()} | {:error, term()}

# List all available models with capabilities
@spec list_models(capability :: atom()) :: [model_info()]
```

**OpenRouter API Integration**:
```elixir
# Fetch from https://openrouter.ai/api/v1/models
defp fetch_models_from_api do
  headers = [{"Authorization", "Bearer #{api_key()}"}]

  case Req.get("https://openrouter.ai/api/v1/models", headers: headers) do
    {:ok, %{status: 200, body: %{"data" => models}}} ->
      {:ok, parse_models(models)}
    {:ok, %{status: status}} ->
      {:error, {:api_error, status}}
    {:error, reason} ->
      {:error, reason}
  end
end
```

### 4.2 OpenRouter.IntentRouter

**Purpose**: Maps AI intents to optimal model selection with routing strategies.

**Location**: `lib/indrajaal/openrouter/intent_router.ex`

**Intent Types**:
```elixir
@intents %{
  # Analysis intents → Prefer high-context models
  :analyze => %{
    preferred_tier: :smart,
    fallback_tier: :fast,
    strategies: [:floor],  # Cost-optimized for bulk analysis
    capabilities: [:chat, :context]
  },

  # Synthesis intents → Prefer reasoning models
  :synthesize => %{
    preferred_tier: :smart,
    fallback_tier: :smart,
    strategies: [:nitro],  # Speed-optimized for code generation
    capabilities: [:code, :reasoning]
  },

  # Reasoning intents → Prefer deep thinking models
  :reason => %{
    preferred_tier: :deep,
    fallback_tier: :smart,
    strategies: [],  # Default routing
    capabilities: [:reasoning]
  },

  # Triage intents → Fast, cheap classification
  :triage => %{
    preferred_tier: :free,
    fallback_tier: :fast,
    strategies: [:free],
    capabilities: [:chat]
  },

  # Validation intents → Reliable, deterministic
  :validate => %{
    preferred_tier: :smart,
    fallback_tier: :fast,
    strategies: [],
    capabilities: [:reasoning]
  }
}
```

**Key Functions**:
```elixir
# Select optimal model for intent
@spec select_model(intent :: atom(), opts :: keyword()) ::
        {:ok, %{model_id: String.t(), routing_headers: map()}} | {:error, term()}

# Get routing strategy for intent
@spec get_strategy(intent :: atom()) :: strategy()

# Build provider preferences for OpenRouter
@spec build_routing_headers(strategy :: atom()) :: map()
```

**Routing Strategy Headers**:
```elixir
defp build_routing_headers(:nitro) do
  %{
    "X-Provider-Preferences" => "speed",
    "X-OpenRouter-Suffix" => "nitro"
  }
end

defp build_routing_headers(:floor) do
  %{
    "X-Provider-Preferences" => "price",
    "X-OpenRouter-Suffix" => "floor"
  }
end

defp build_routing_headers(:free) do
  %{
    "X-Provider-Preferences" => "price",
    "X-OpenRouter-Suffix" => "free"
  }
end

defp build_routing_headers(_), do: %{}
```

### 4.3 OpenRouter.CostMonitor

**Purpose**: Tracks costs, enforces budgets, and provides cost analytics.

**Location**: `lib/indrajaal/openrouter/cost_monitor.ex`

**State Structure**:
```elixir
%{
  # Budget configuration
  budgets: %{
    daily_limit_usd: 10.0,
    monthly_limit_usd: 100.0,
    per_request_limit_usd: 1.0,
    alert_threshold_percent: 80
  },

  # Current usage
  usage: %{
    daily: %{
      total_usd: 0.0,
      by_model: %{},
      by_source: %{},
      request_count: 0
    },
    monthly: %{
      total_usd: 0.0,
      by_model: %{},
      by_source: %{}
    }
  },

  # Rate limiting
  rate_limits: %{
    requests_per_minute: 100,
    tokens_per_minute: 100_000,
    current_minute: %{requests: 0, tokens: 0, started_at: DateTime.t()}
  },

  # Alert state
  alerts: %{
    daily_alert_sent: false,
    monthly_alert_sent: false
  }
}
```

**Key Functions**:
```elixir
# Record a completed request
@spec record_usage(model_id :: String.t(), tokens :: integer(), cost_usd :: float(), source :: atom()) :: :ok

# Check if request is within budget
@spec check_budget(estimated_tokens :: integer(), model_id :: String.t()) ::
        :ok | {:error, :budget_exceeded | :rate_limited}

# Get current usage stats
@spec get_usage() :: usage_stats()

# Calculate cost for a request
@spec estimate_cost(model_id :: String.t(), tokens :: integer()) :: {:ok, float()} | {:error, term()}
```

**Budget Enforcement Flow**:
```elixir
def check_budget(estimated_tokens, model_id) do
  with :ok <- check_rate_limit(),
       :ok <- check_per_request_limit(estimated_tokens, model_id),
       :ok <- check_daily_limit(),
       :ok <- check_monthly_limit() do
    :ok
  end
end
```

---

## 5. Integration with Existing Systems

### 5.1 OpenRouterClient Enhancement

The existing `OpenRouterClient` will be enhanced to use the new components:

```elixir
# Enhanced chat/2 function
def chat(messages, opts \\ []) do
  intent = Keyword.get(opts, :intent, :synthesize)
  source = Keyword.get(opts, :source, :unknown)

  # 1. Get model via IntentRouter (or explicit)
  model_result = case Keyword.get(opts, :model) do
    nil -> IntentRouter.select_model(intent, opts)
    model when is_atom(model) -> IntentRouter.select_model_for_tier(model, opts)
    model when is_binary(model) -> {:ok, %{model_id: model, routing_headers: %{}}}
  end

  with {:ok, %{model_id: model_id, routing_headers: headers}} <- model_result,
       # 2. Check budget
       :ok <- CostMonitor.check_budget(estimate_tokens(messages), model_id),
       # 3. Guardian pre-flight (existing P0-CRITICAL)
       {:ok, true} <- pre_flight_guardian_check(source, model_id, extract_prompt(messages)),
       # 4. Graph verification (existing)
       {:ok, _} <- verify_routing_graph(source, model_id, [guardian_approved: true]) do

    # 5. Execute with routing headers
    result = execute_chat(messages, model_id, headers, opts)

    # 6. Record usage
    case result do
      {:ok, content, usage} ->
        cost = calculate_cost(model_id, usage)
        CostMonitor.record_usage(model_id, usage.total_tokens, cost, source)
        ZenohEvolutionPublisher.publish_openrouter_call(model_id, usage.total_tokens, usage.latency_ms, true)
        {:ok, content}
      {:error, _} = error ->
        error
    end
  end
end
```

### 5.2 AI Interface Updates

**ClaudeInterface** (Synthesis):
```elixir
# Use intent: :synthesize
case OpenRouterClient.chat(messages,
  intent: :synthesize,
  source: :claude_interface,
  model: :smart  # Optional: explicit tier
) do
  {:ok, content} -> parse_response(content)
  {:error, :budget_exceeded} -> {:error, :budget_exceeded}
  {:error, reason} -> {:error, reason}
end
```

**GeminiInterface** (Analysis):
```elixir
# Use intent: :analyze
case OpenRouterClient.chat(messages,
  intent: :analyze,
  source: :gemini_interface,
  model: :fast  # High-context, cost-optimized
) do
  {:ok, content} -> parse_analysis(content)
  {:error, reason} -> {:error, reason}
end
```

### 5.3 CEPAF Telemetry Events

Extend `Domain.fs` TelemetryEvent:
```fsharp
// Existing
| OpenRouterCall of model: string * tokenCount: int64

// Enhanced
| OpenRouterCall of model: string * tokenCount: int64 * costUsd: float * intent: string
| OpenRouterBudgetAlert of alertType: string * currentUsage: float * limit: float
| OpenRouterModelRefresh of modelCount: int * timestamp: DateTimeOffset
```

### 5.4 ZenohEvolutionPublisher Enhancement

Add new key expressions:
```elixir
@cost_key_prefix "#{@evolution_prefix}/openrouter/cost"
@budget_key_prefix "#{@evolution_prefix}/openrouter/budget"

# New publish functions
def publish_cost_update(model_id, cost_usd, cumulative_daily, cumulative_monthly) do
  GenServer.cast(__MODULE__, {:cost_update, model_id, cost_usd, cumulative_daily, cumulative_monthly})
end

def publish_budget_alert(alert_type, current, limit) do
  GenServer.cast(__MODULE__, {:budget_alert, alert_type, current, limit})
end
```

---

## 6. STAMP Constraints

### 6.1 New Constraints

| ID | Description | Enforcement |
|----|-------------|-------------|
| SC-AI-004 | Budget limits must be enforced before API calls | CostMonitor.check_budget/2 |
| SC-AI-005 | Rate limits must prevent API exhaustion | CostMonitor rate limiting |
| SC-AI-006 | Model registry must refresh within 1 hour | ModelRegistry periodic refresh |
| SC-AI-007 | Intent routing must provide fallback | IntentRouter fallback_tier |
| SC-AI-008 | Cost alerts must trigger at threshold | CostMonitor alert hooks |
| SC-AI-009 | Free tier must be used for triage | IntentRouter :triage → :free |
| SC-AI-010 | All costs must be recorded to Zenoh | ZenohEvolutionPublisher |

### 6.2 Existing Constraints (Preserved)

| ID | Description | Status |
|----|-------------|--------|
| SC-NEURO-001 | All routes through Guardian | ENFORCED (P0-CRITICAL) |
| SC-GVF-003 | Synapse exclusivity | ENFORCED |
| SC-GVF-004 | Confidence threshold | ENFORCED |
| SC-ZENOH-EVO-001 | OpenRouter call telemetry | ENFORCED |

---

## 7. Configuration

### 7.1 Application Config

```elixir
# config/config.exs
config :indrajaal, Indrajaal.OpenRouter,
  # API Configuration
  api_key: System.get_env("OPENROUTER_API_KEY"),

  # Budget Configuration
  budgets: %{
    daily_limit_usd: 10.0,
    monthly_limit_usd: 100.0,
    per_request_limit_usd: 1.0,
    alert_threshold_percent: 80
  },

  # Rate Limiting
  rate_limits: %{
    requests_per_minute: 100,
    tokens_per_minute: 100_000
  },

  # Model Registry
  registry: %{
    refresh_interval_ms: 3_600_000,  # 1 hour
    fallback_models: %{
      fast: "google/gemini-flash-1.5-8b",
      smart: "anthropic/claude-3.5-sonnet",
      deep: "openai/o1-preview"
    }
  }
```

### 7.2 Environment-Specific Overrides

```elixir
# config/dev.exs
config :indrajaal, Indrajaal.OpenRouter,
  budgets: %{
    daily_limit_usd: 5.0,
    monthly_limit_usd: 50.0
  }

# config/prod.exs
config :indrajaal, Indrajaal.OpenRouter,
  budgets: %{
    daily_limit_usd: 100.0,
    monthly_limit_usd: 1000.0
  }
```

---

## 8. Implementation Phases

### Phase 1: Core Infrastructure (P0)
1. Create `OpenRouter.ModelRegistry` GenServer
2. Implement OpenRouter API integration for model listing
3. Add periodic refresh mechanism
4. Write comprehensive tests

### Phase 2: Cost Management (P1)
1. Create `OpenRouter.CostMonitor` GenServer
2. Implement budget tracking and enforcement
3. Add rate limiting
4. Integrate with ZenohEvolutionPublisher
5. Write budget enforcement tests

### Phase 3: Intent Routing (P2)
1. Create `OpenRouter.IntentRouter` module
2. Define intent-to-model mappings
3. Implement routing strategy headers
4. Update AI interfaces to use intents
5. Write routing tests

### Phase 4: Enhanced Gateway (P2)
1. Update `OpenRouterClient.chat/2` with new flow
2. Integrate all components
3. End-to-end testing
4. CEPAF telemetry event updates

---

## 9. Testing Strategy

### 9.1 Unit Tests

```elixir
describe "OpenRouter.ModelRegistry" do
  test "refreshes models from API"
  test "returns fallback on API failure"
  test "caches models for configured interval"
  test "lists models by capability"
end

describe "OpenRouter.CostMonitor" do
  test "tracks usage by model and source"
  test "blocks requests exceeding budget"
  test "sends alerts at threshold"
  test "enforces rate limits"
end

describe "OpenRouter.IntentRouter" do
  test "maps intents to models"
  test "builds correct routing headers"
  test "falls back on model unavailable"
end
```

### 9.2 Integration Tests

```elixir
describe "OpenRouter Integration" do
  test "end-to-end chat with intent routing"
  test "budget enforcement blocks excessive requests"
  test "telemetry streams to Zenoh"
  test "CEPAF receives cost events"
end
```

---

## 10. Monitoring & Observability

### 10.1 Zenoh Key Expressions

```
indrajaal/evolution/openrouter/calls           - Individual call events
indrajaal/evolution/openrouter/cost/daily      - Daily cost aggregates
indrajaal/evolution/openrouter/cost/monthly    - Monthly cost aggregates
indrajaal/evolution/openrouter/budget/alerts   - Budget alerts
indrajaal/evolution/openrouter/models/refresh  - Model registry updates
```

### 10.2 Telemetry Events

```elixir
# OpenRouter telemetry events
[:openrouter, :chat, :start]
[:openrouter, :chat, :stop]
[:openrouter, :budget, :check]
[:openrouter, :budget, :exceeded]
[:openrouter, :registry, :refresh]
[:openrouter, :cost, :record]
```

---

## 11. Conclusion

This implementation transforms Indrajaal's OpenRouter integration from a static gateway to a dynamic, cost-aware, intent-based AI routing system while preserving all existing safety guarantees (Guardian pre-flight, Graph verification, STAMP constraints).

**Key Benefits**:
1. **Cost Control**: Budget enforcement prevents runaway costs
2. **Flexibility**: Intent-based routing adapts to use case
3. **Observability**: Full telemetry via Zenoh
4. **Maintainability**: Dynamic registry reduces config updates
5. **Safety**: All existing P0-CRITICAL checks preserved

**Estimated Implementation**: 4 phases, modular approach allows incremental rollout.

---

## Appendix A: OpenRouter API Reference

### Models Endpoint
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
      "context_length": 200000,
      "top_provider": {...}
    }
  ]
}
```

### Routing Suffixes
- `:nitro` - Speed-optimized routing
- `:floor` - Cost-optimized routing
- `:free` - Free tier only

### Provider Preferences Header
```
X-Provider-Preferences: {"speed": 1.0}  # Prioritize speed
X-Provider-Preferences: {"price": 1.0}  # Prioritize price
```

---

## Appendix B: Migration Checklist

- [ ] Create `lib/indrajaal/openrouter/` directory
- [ ] Implement `ModelRegistry` GenServer
- [ ] Implement `CostMonitor` GenServer
- [ ] Implement `IntentRouter` module
- [ ] Update `OpenRouterClient.chat/2`
- [ ] Update `ClaudeInterface` to use intents
- [ ] Update `GeminiInterface` to use intents
- [ ] Update `AIIntegration` to use intents
- [ ] Add Zenoh key expressions
- [ ] Update CEPAF Domain.fs
- [ ] Write comprehensive tests
- [ ] Update documentation
