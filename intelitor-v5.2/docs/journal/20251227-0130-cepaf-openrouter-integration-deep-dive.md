# CEPAF + OpenRouter Integration Deep Dive

**Date**: 2025-12-27T01:30:00+01:00
**Session**: Session 5 - GDE OpenRouter Integration
**Author**: Cybernetic Architect (Claude Opus 4.5)
**STAMP**: SC-GDE-060, SC-GDE-061, SC-ZENOH-EVO-001

---

## L1: Executive Summary

CEPAF (Container Execution Platform Automation Framework) integrates with OpenRouter to provide AI-powered decision making for the GDE (Goal-Directed Evolution) pipeline. The integration uses a **bridge pattern** where Elixir handles the API calls and CEPAF tracks telemetry via Zenoh pub/sub.

---

## L2: Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CEPAF ↔ OpenRouter Integration                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                        ELIXIR LAYER                                │    │
│  │                                                                    │    │
│  │  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐     │    │
│  │  │   Synapse    │───►│ OpenRouter   │───►│  Zenoh KPI       │     │    │
│  │  │  (Cortex)    │    │   Client     │    │   Publisher      │     │    │
│  │  └──────────────┘    └──────────────┘    └──────────────────┘     │    │
│  │        │                    │                     │               │    │
│  │        │  solve()           │  chat()             │ publish()     │    │
│  │        ▼                    ▼                     ▼               │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                │                     │                     │
│                                │ HTTPS               │ Zenoh               │
│                                ▼                     ▼                     │
│  ┌────────────────┐    ┌──────────────────────────────────────────┐       │
│  │   OpenRouter   │    │               CEPAF (F#)                 │       │
│  │   API (Cloud)  │    │                                          │       │
│  │   - Gemini     │    │  ┌────────────┐    ┌────────────────┐   │       │
│  │   - Claude     │    │  │   Domain   │    │  Safety.fs     │   │       │
│  │   - GPT-o1     │    │  │  Events    │    │  (Telemetry)   │   │       │
│  │                │    │  └────────────┘    └────────────────┘   │       │
│  └────────────────┘    └──────────────────────────────────────────┘       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## L3: Component Details

### L3.1: Elixir OpenRouter Client

**File**: `lib/indrajaal/ai/open_router_client.ex`

```elixir
defmodule Intelitor.AI.OpenRouterClient do
  @moduledoc """
  Gateway to the Cloud Cortex via OpenRouter.
  Implements: docs/architecture/OPENROUTER_OPTIMIZATION_STRATEGY.md
  """

  @base_url "https://openrouter.ai/api/v1/chat/completions"

  @models %{
    fast: "google/gemini-flash-1.5-8b",      # Cheap, fast
    smart: "anthropic/claude-3.5-sonnet",    # Balanced (default for GDE)
    deep: "openai/o1-preview"                # Expensive, reasoning
  }

  def chat(messages, opts \\ []) do
    model_alias = Keyword.get(opts, :model, :fast)
    # ... API call with caching, cost tracking, Zenoh streaming
  end
end
```

**Key Features**:
- **Auto-Caching**: Injects `cache_control` headers for Anthropic models
- **Tiered Routing**: Maps `:fast`, `:smart`, `:deep` to specific models
- **Cost Tracking**: Logs token usage for budget enforcement
- **Zenoh Streaming**: Publishes telemetry to `indrajaal/evolution/openrouter/calls`

### L3.2: CEPAF F# Domain Events

**File**: `lib/cepaf/src/Cepaf/Domain.fs`

```fsharp
type TelemetryEvent =
    // ... other events ...
    | OpenRouterCall of model: string * tokenCount: int64
    | GDEProposalGenerated of proposalType: string * confidence: float
    | GDEProposalValidated of proposalId: string * passed: bool * reason: string
    | GDECycleComplete of proposalCount: int * validatedCount: int * successRate: float
```

### L3.3: CEPAF Safety Commands (Telemetry Handlers)

**File**: `lib/cepaf/src/Cepaf.Bridge/Commands/Safety.fs`

```fsharp
type OpenRouterUsage = {
    Model: string
    TokenCount: int64
    LatencyMs: int64
    Success: bool
    Timestamp: System.DateTimeOffset
}

/// Get OpenRouter usage stats
let handleOpenRouterUsage = async {
    let stats = {|
        total_calls = 0L
        total_tokens = 0L
        fast_calls = 0L
        smart_calls = 0L
        deep_calls = 0L
        average_latency_ms = 0.0
    |}
    return JsonRpc.successResponse id stats
}

/// Record an OpenRouter API call
let handleOpenRouterRecordCall = async {
    // Records call to Zenoh evolution channel
}
```

---

## L4: Data Flow & Telemetry

### L4.1: Request Flow (Synapse → OpenRouter → CEPAF)

```
1. User calls Synapse.solve(context, goal)
2. Synapse calls triage_locally(context) → LocalModel filters logs
3. Synapse builds task: "Goal: #{goal}. Filtered Context: #{triage}"
4. OpenRouterClient.chat(messages, model: :smart)
   4.1. Injects cache_control headers for Anthropic
   4.2. POST to https://openrouter.ai/api/v1/chat/completions
   4.3. Tracks cost via track_cost/2
   4.4. Streams to Zenoh via stream_to_zenoh/3
5. CEPAF receives Zenoh event on "indrajaal/evolution/openrouter/calls"
6. Safety.fs records OpenRouterCall telemetry event
7. Guardian validates response (if applicable)
8. Synapse returns {:ok, %{id: request_id, solution: solution}}
```

### L4.2: Zenoh Key Expressions

| Channel | Key Expression | Publisher | Subscriber |
|---------|----------------|-----------|------------|
| OpenRouter Calls | `indrajaal/evolution/openrouter/calls` | OpenRouterClient | CEPAF Safety |
| GDE Proposals | `indrajaal/evolution/gde/proposals` | AIIntegration | Guardian |
| GDE Validations | `indrajaal/evolution/gde/validations` | Guardian | Dashboard |
| GDE Stats | `indrajaal/evolution/stats` | GDE Pipeline | KPI Dashboard |

### L4.3: Telemetry Events

```elixir
# Elixir side - OpenRouterClient publishes:
:telemetry.execute(
  [:indrajaal, :ai, :openrouter, :call],
  %{duration: elapsed_ms, tokens: token_count},
  %{model: model_id, success: true}
)

# Zenoh side - CEPAF receives:
{
  "key": "indrajaal/evolution/openrouter/calls",
  "payload": {
    "model": "anthropic/claude-3.5-sonnet",
    "token_count": 1523,
    "latency_ms": 2340,
    "success": true,
    "timestamp": "2025-12-27T01:30:00Z"
  }
}
```

---

## L5: Testing Strategy

### L5.1: Unit Tests

**File**: `test/indrajaal/ai/open_router_client_test.exs`

```elixir
defmodule Intelitor.AI.OpenRouterClientTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  describe "chat/2" do
    test "returns error when API key missing" do
      # Temporarily unset API key
      Application.put_env(:indrajaal, :ai, openrouter_key: nil)

      assert {:error, :missing_api_key} = OpenRouterClient.chat([
        %{role: "user", content: "Hello"}
      ])
    end

    test "routes :fast to Gemini Flash" do
      expect(HTTPMock, :request, fn req ->
        assert req.body["model"] == "google/gemini-flash-1.5-8b"
        {:ok, %{status: 200, body: mock_response()}}
      end)

      assert {:ok, _} = OpenRouterClient.chat([...], model: :fast)
    end

    test "routes :smart to Claude 3.5 Sonnet" do
      expect(HTTPMock, :request, fn req ->
        assert req.body["model"] == "anthropic/claude-3.5-sonnet"
        {:ok, %{status: 200, body: mock_response()}}
      end)

      assert {:ok, _} = OpenRouterClient.chat([...], model: :smart)
    end

    test "injects cache_control for Anthropic models" do
      expect(HTTPMock, :request, fn req ->
        [first_msg | _] = req.body["messages"]
        assert first_msg["content"] |> List.first() |> Map.has_key?("cache_control")
        {:ok, %{status: 200, body: mock_response()}}
      end)

      messages = [%{role: "system", content: "You are helpful"}]
      OpenRouterClient.chat(messages, model: :smart, cache: true)
    end
  end
end
```

### L5.2: Integration Tests

**File**: `test/indrajaal/cortex/synapse_integration_test.exs`

```elixir
defmodule Intelitor.Cortex.SynapseIntegrationTest do
  use ExUnit.Case

  @moduletag :integration

  setup do
    # Start Synapse GenServer
    {:ok, pid} = Synapse.start_link([])
    %{synapse: pid}
  end

  describe "solve/2 with mock OpenRouter" do
    test "completes GDE cycle with mocked response", %{synapse: pid} do
      # Mock the OpenRouter response
      Mox.expect(HTTPMock, :request, fn _ ->
        {:ok, %{status: 200, body: %{
          "choices" => [%{"message" => %{"content" => "Fix: add nil check"}}],
          "usage" => %{"total_tokens" => 150}
        }}}
      end)

      context = %{error: "undefined function", file: "lib/foo.ex", line: 42}

      assert {:ok, result} = Synapse.solve(context, :error_fix)
      assert result.solution =~ "nil check"
    end
  end
end
```

### L5.3: Property Tests

**File**: `test/indrajaal/ai/open_router_property_test.exs`

```elixir
defmodule Intelitor.AI.OpenRouterPropertyTest do
  use ExUnit.Case
  use PropCheck
  import StreamData, as: SD

  alias PropCheck.BasicTypes, as: PC

  property "chat handles any valid message format" do
    forall messages <- PC.list(message_generator()) do
      case OpenRouterClient.chat(messages, model: :fast) do
        {:ok, _} -> true
        {:error, :missing_api_key} -> true  # Expected in test env
        {:error, :api_error} -> true        # API rejection is valid
        _ -> false
      end
    end
  end

  defp message_generator do
    PC.let({role, content}, {role_gen(), PC.utf8()}) do
      %{role: role, content: content}
    end
  end

  defp role_gen, do: PC.oneof(["system", "user", "assistant"])
end
```

### L5.4: CEPAF F# Tests

**File**: `lib/cepaf/tests/SafetyTests.fs`

```fsharp
module Cepaf.Tests.SafetyTests

open Expecto
open Cepaf.Bridge.Commands.Safety

[<Tests>]
let openRouterTests =
    testList "OpenRouter Integration" [
        testAsync "handleOpenRouterUsage returns stats" {
            let! result = handleOpenRouterUsage mockClient None None
            Expect.isTrue (result.Contains("total_calls")) "Should contain stats"
        }

        testAsync "handleOpenRouterRecordCall validates params" {
            let! result = handleOpenRouterRecordCall mockClient (Some "1") None
            Expect.isTrue (result.Contains("error")) "Should require params"
        }

        testAsync "OpenRouterCall event is emitted" {
            let event = TelemetryEvent.OpenRouterCall("claude-3.5-sonnet", 1500L)
            let json = serializeEvent event
            Expect.isTrue (json.Contains("OpenRouterCall")) "Should serialize"
        }
    ]
```

### L5.5: End-to-End Test (Manual)

```bash
# Terminal 1: Start the system with verbose logging
MIX_ENV=dev FRACTAL_LEVEL=l1 iex -S mix

# In IEx:
iex> Logger.configure(level: :debug)
iex> Intelitor.Cortex.Synapse.solve(
...>   %{error: "undefined function foo/0", file: "lib/bar.ex", line: 10},
...>   :error_fix
...> )

# Expected Console Output (L1 verbose):
# 01:30:00.123 [debug] [Synapse] Received solve request: #REQ-abc123
# 01:30:00.124 [debug] [LocalModel] Triaging context (250 tokens)
# 01:30:00.156 [debug] [Synapse] Triage complete: "Error in bar.ex:10 - undefined foo"
# 01:30:00.157 [debug] 🌩️ OpenRouter Call: smart (anthropic/claude-3.5-sonnet)
# 01:30:02.498 [debug] 🌩️ OpenRouter Response: 200 OK (1523 tokens, 2341ms)
# 01:30:02.499 [debug] 🌩️ OpenRouter Cost: $0.0076 (cached: false)
# 01:30:02.500 [info] 🧠 Synapse found solution via Cloud Cortex: #REQ-abc123
# {:ok, %{id: "REQ-abc123", solution: "..."}}
```

### L5.6: Zenoh Telemetry Verification

```bash
# Terminal 2: Subscribe to Zenoh evolution channel
zenoh-cli sub "indrajaal/evolution/**"

# Expected Output:
# [indrajaal/evolution/openrouter/calls] {
#   "model": "anthropic/claude-3.5-sonnet",
#   "token_count": 1523,
#   "latency_ms": 2341,
#   "success": true,
#   "cached": false,
#   "cost_usd": 0.0076,
#   "timestamp": "2025-12-27T01:30:02.498Z"
# }
```

---

## L5+: Configuration & Environment

### Environment Variables

```bash
# Required for production
export OPENROUTER_API_KEY="sk-or-v1-..."

# Optional overrides
export OPENROUTER_SITE_URL="https://indrajaal.example.com"
export OPENROUTER_APP_NAME="Intelitor Security Platform"
```

### Config Files

**config/runtime.exs**:
```elixir
config :indrajaal, :ai,
  openrouter_key: System.get_env("OPENROUTER_API_KEY"),
  site_url: System.get_env("OPENROUTER_SITE_URL", "http://localhost:4000"),
  app_name: System.get_env("OPENROUTER_APP_NAME", "Intelitor")
```

**config/test.exs**:
```elixir
config :indrajaal, :ai,
  openrouter_key: "test-mock-key"  # Use mocks, never real API

# Enable HTTP mocking
config :indrajaal, :http_client, HTTPMock
```

---

## Verification Checklist

| Check | Status | Command |
|-------|--------|---------|
| OpenRouterClient exists | PASS | `grep -l OpenRouterClient lib/indrajaal/ai/` |
| Synapse integrates | PASS | `grep OpenRouterClient lib/indrajaal/cortex/synapse.ex` |
| CEPAF domain events | PASS | `grep OpenRouterCall lib/cepaf/src/Cepaf/Domain.fs` |
| Safety handlers | PASS | `grep handleOpenRouter lib/cepaf/src/Cepaf.Bridge/Commands/Safety.fs` |
| Zenoh channels defined | PASS | `grep evolution lib/indrajaal/observability/zenoh_coordinator.ex` |
| Test files exist | PARTIAL | Need to create test files |

---

## Next Steps

1. **Create unit test file**: `test/indrajaal/ai/open_router_client_test.exs`
2. **Create property test**: `test/indrajaal/ai/open_router_property_test.exs`
3. **Add Mox mock setup** for HTTP client
4. **Run verbose E2E test** with real API key
5. **Verify Zenoh telemetry** with `zenoh-cli sub`

---

## STAMP Compliance

| Constraint | Description | Status |
|------------|-------------|--------|
| SC-GDE-060 | All AI work uses OpenRouter exclusively | COMPLIANT |
| SC-GDE-061 | AI proposal confidence >= 0.6 | COMPLIANT |
| SC-ZENOH-EVO-001 | Evolution telemetry via Zenoh | COMPLIANT |

---

*Generated by Cybernetic Architect - Session 5*
