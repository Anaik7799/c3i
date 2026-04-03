# Journal: OpenRouter Dynamic Manager Analysis & Implementation Approach

**Date**: 2025-12-27T04:30:00+01:00
**Author**: Cybernetic Architect (Claude Code)
**Priority**: P1-HIGH
**Status**: ANALYSIS COMPLETE, IMPLEMENTATION PROPOSED

---

## Executive Summary

Conducted comprehensive analysis of Intelitor's OpenRouter integration in response to user request for dynamic marketplace management. Identified gaps in current static implementation and designed a modular enhancement architecture that preserves existing P0-CRITICAL safety guarantees while adding:

1. **Dynamic Model Registry** - Real-time model discovery and pricing from OpenRouter API
2. **Intent-Based Routing** - Maps AI intents (analyze, synthesize, reason, triage, validate) to optimal models
3. **Cost Management** - Budget enforcement, rate limiting, and cost telemetry
4. **Routing Strategies** - Support for `:nitro`, `:floor`, and `:free` suffixes

---

## Current State Analysis

### Existing Components (Strengths)

| Component | Capability | Status |
|-----------|------------|--------|
| `OpenRouterClient` | Gateway with Guardian pre-flight, Graph verification | P0-CRITICAL complete |
| `ClaudeInterface` | Synthesis via Claude Sonnet | Production ready |
| `GeminiInterface` | Analysis via Gemini 1.5 Pro | Production ready |
| `ZenohEvolutionPublisher` | OpenRouter call telemetry | Streaming active |
| `Guardian` | Pre-flight security validation | Integrated |

### Current Model Mapping

```elixir
# Static 3-tier mapping (lib/indrajaal/ai/open_router_client.ex:36-40)
@models %{
  fast: "google/gemini-flash-1.5-8b",
  smart: "anthropic/claude-3.5-sonnet",
  deep: "openai/o1-preview"
}
```

### Identified Gaps

1. **No Dynamic Discovery**: Model catalog is hardcoded
2. **No Live Pricing**: Cannot optimize for cost at runtime
3. **No Intent Detection**: Requires explicit model selection
4. **No Budget Enforcement**: Costs can run unchecked
5. **No Routing Strategies**: Cannot leverage `:nitro/:floor/:free` suffixes
6. **No Rate Limiting**: API quota exhaustion risk

---

## User-Provided Pattern Analysis

The user provided a sophisticated OpenRouter Manager pattern that treats OpenRouter as a dynamic marketplace:

```elixir
defmodule OpenRouter do
  def chat(intent, messages, opts \\ []) do
    strategy = Registry.select_strategy(intent)
    request_params = opts
      |> Keyword.put(:model, strategy.model_id)
      |> Keyword.put(:provider_preferences, strategy.routing_headers)
    # ...
  end
end
```

Key concepts from user pattern:
- **Intent-first routing**: `chat(intent, messages, opts)` vs current `chat(messages, opts)`
- **Registry-based selection**: `Registry.select_strategy(intent)` for dynamic model choice
- **Provider preferences**: Headers for `:nitro`, `:floor`, `:free` routing

---

## Proposed Architecture

### Three Core Modules

1. **OpenRouter.ModelRegistry** (GenServer)
   - Fetches models from `https://openrouter.ai/api/v1/models`
   - Caches with configurable refresh interval (default: 1 hour)
   - Provides model lookup by tier and capability
   - Falls back to static mapping on API failure

2. **OpenRouter.IntentRouter** (Pure Logic)
   - Maps intents to optimal tier + strategy
   - Intent types: `:analyze`, `:synthesize`, `:reason`, `:triage`, `:validate`
   - Builds routing headers for OpenRouter provider preferences

3. **OpenRouter.CostMonitor** (GenServer)
   - Tracks daily/monthly costs by model and source
   - Enforces configurable budget limits
   - Rate limiting per minute
   - Triggers alerts at threshold

### Integration Flow

```
AI Request (with intent)
    │
    ▼
┌─────────────────┐
│  IntentRouter   │ ──► Select model + strategy
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  CostMonitor    │ ──► Check budget + rate limit
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Guardian Check  │ ──► P0-CRITICAL pre-flight (existing)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Graph Verify    │ ──► SC-GVF constraints (existing)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ OpenRouter API  │ ──► Execute with routing headers
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Record Cost     │ ──► CostMonitor + Zenoh telemetry
└─────────────────┘
```

---

## CEPAF Integration

The F# CEPAF system already has the foundation for OpenRouter telemetry:

```fsharp
// Domain.fs:124
| OpenRouterCall of model: string * tokenCount: int64
```

Proposed enhancement:
```fsharp
| OpenRouterCall of model: string * tokenCount: int64 * costUsd: float * intent: string
| OpenRouterBudgetAlert of alertType: string * currentUsage: float * limit: float
```

---

## Implementation Phases

### Phase 1: Core Infrastructure (P0)
- Create `OpenRouter.ModelRegistry`
- OpenRouter API integration
- Periodic refresh mechanism
- Tests

### Phase 2: Cost Management (P1)
- Create `OpenRouter.CostMonitor`
- Budget enforcement
- Rate limiting
- Zenoh integration
- Tests

### Phase 3: Intent Routing (P2)
- Create `OpenRouter.IntentRouter`
- Intent-to-model mappings
- Routing strategy headers
- AI interface updates
- Tests

### Phase 4: Enhanced Gateway (P2)
- Update `OpenRouterClient.chat/2`
- End-to-end integration
- CEPAF telemetry updates

---

## Files Created

1. `docs/architecture/OPENROUTER_DYNAMIC_MANAGER_IMPLEMENTATION.md`
   - Comprehensive implementation approach
   - Module specifications
   - STAMP constraints
   - Configuration examples
   - Testing strategy
   - Migration checklist

---

## Key Design Decisions

1. **Preserve P0-CRITICAL Safety**
   - Guardian pre-flight check remains mandatory
   - Graph verification unchanged
   - Fail-safe behavior on component unavailable

2. **Modular Architecture**
   - Each component (Registry, Router, CostMonitor) is independent
   - Can be rolled out incrementally
   - Existing code continues to work during migration

3. **Intent-First API**
   - New callers use `chat(messages, intent: :synthesize)`
   - Legacy callers continue with `chat(messages, model: :smart)`
   - Gradual migration path

4. **Observability**
   - All costs streamed to Zenoh
   - CEPAF receives enhanced telemetry
   - Budget alerts for proactive management

---

## New STAMP Constraints

| ID | Description |
|----|-------------|
| SC-AI-004 | Budget limits must be enforced before API calls |
| SC-AI-005 | Rate limits must prevent API exhaustion |
| SC-AI-006 | Model registry must refresh within 1 hour |
| SC-AI-007 | Intent routing must provide fallback |
| SC-AI-008 | Cost alerts must trigger at threshold |
| SC-AI-009 | Free tier must be used for triage |
| SC-AI-010 | All costs must be recorded to Zenoh |

---

## Conclusion

The OpenRouter Dynamic Manager design provides a clear path from the current static gateway to a sophisticated marketplace management system. The modular approach allows incremental rollout while preserving all existing safety guarantees.

**Next Steps**:
1. Review and approve implementation approach
2. Begin Phase 1: Core Infrastructure
3. Iterate based on production telemetry

**Documentation**: `docs/architecture/OPENROUTER_DYNAMIC_MANAGER_IMPLEMENTATION.md`
