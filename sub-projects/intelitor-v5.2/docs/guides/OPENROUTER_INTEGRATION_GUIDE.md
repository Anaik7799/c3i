# OpenRouter Integration Guide: Architecture, Implementation & Usage

**Version**: 21.3.0-SIL6
**Date**: 2026-01-11
**Status**: ACTIVE
**Framework**: SOPv5.11 + STAMP + OODA + Biomorphic
**Compliance**: SIL-6 Biomorphic Fractal Mesh
**Related**: `GEMINI.md` (Sections 94.0, 95.0), `docs/architecture/OPENROUTER_DYNAMIC_MANAGER_IMPLEMENTATION.md`

---

## 1.0 Architecture: The 7-Level Fractal Model

Indrajaal integrates OpenRouter as its **Cognitive Cortex**, providing high-level reasoning capabilities to the otherwise deterministic system. This integration is structured fractally across 7 levels of abstraction.

| Level | Scope | Component | Responsibility |
|---|---|---|---|
| **L1** | **Atomic** | `OpenRouterClient.chat/2` | Raw HTTP/SSE execution, Headers, Request signing. |
| **L2** | **Component** | `ProviderDispatcher` | Retry logic, Fallback chains, Response normalization. |
| **L3** | **Holon** | `Synapse`, `Guardian` | Context assembly, **Safety Verification**, OODA Loop orientation. |
| **L4** | **Container** | `indrajaal-app`, `cepaf` | Runtime environment, Secret injection, Podman Bridge. |
| **L5** | **Node** | `PricingCache` | Budget enforcement, Local caching, Rate Limiting. |
| **L6** | **Mesh** | `ZenohEvolutionPublisher` | Distributed Telemetry, Hive Mind Analysis. |
| **L7** | **Federation** | `ModelRegistry` | Global Model Selection, Drift Detection, Alignment. |

### 1.1 The Bicameral Mind Pattern
The system splits cognition into two planes:
1.  **Safety Plane (Guardian)**: Deterministic, verified Elixir code. Vetoes unsafe actions.
2.  **Complex Plane (Cortex)**: Non-deterministic AI (OpenRouter). Generates creative proposals.

**Invariant**: `inv_openrouter_exclusivity` (Synapse → OpenRouter → Guardian). Direct access to external AI is FORBIDDEN.

---

## 2.0 Implementation: The Dual-Stack Strategy

The system uses a **Dual-Stack Cognitive Architecture** to serve both the Application Core (Elixir) and the Infrastructure Orchestrator (F#).

### 2.1 Stack A: Application Cortex (Elixir)
**Gateway**: `Indrajaal.AI.OpenRouterClient` (`lib/indrajaal/ai/open_router_client.ex`)

*   **Synapse**: The brain. Uses `OpenRouterClient.chat/2` to solve complex problems.
*   **FastOODA**: Uses `model: :fast` (e.g., Gemini Flash) for <50ms orientation.
*   **GDE Engine**: Uses `model: :smart` (e.g., Claude 3.5 Sonnet) for code generation.

**Safety Mechanism**:
```elixir
# lib/indrajaal/ai/open_router_client.ex
def pre_flight_guardian_check(source, model, prompt) do
  # 1. Check Circuit Breaker
  # 2. Check Budget
  # 3. Guardian.validate_proposal(prompt)
end
```

### 2.2 Stack B: Infrastructure Cortex (F#)
**Gateway**: `Cepaf.Knowledge.OpenRouter` (`lib/cepaf/src/Cepaf.Knowledge/OpenRouter.fs`)

*   **Deployment Medic**: Analyzes `sa-deploy` failures.
*   **Test Swarm**: Categorizes flaky tests in `ComprehensiveRuntimeTests.fsx`.
*   **Runtime Validator**: Validates system state against intent.

**Integration**:
F# components share the `OPENROUTER_API_KEY` injected via `podman-compose.yml`.

---

## 3.0 Usage Guide

### 3.1 Configuration
The system is pre-configured to use `anthropic/claude-3.5-sonnet` as the default model.

**Environment Variables (.envrc / Runtime)**:
```bash
export OPENROUTER_API_KEY="sk-or-v1-..."
export OPENROUTER_MODEL="anthropic/claude-3.5-sonnet" # Optional override
```

**Runtime Configuration (`config/runtime.exs`)**:
```elixir
config :indrajaal, Indrajaal.AI.OpenRouter,
  api_key: System.get_env("OPENROUTER_API_KEY"),
  site_url: "https://indrajaal.ai",
  app_name: "Indrajaal"
```

### 3.2 Developer Usage (Elixir)

**Basic Chat**:
```elixir
alias Indrajaal.AI.OpenRouterClient

{:ok, response} = OpenRouterClient.chat([
  %{role: "user", content: "Explain the architecture of Indrajaal."}
], model: :smart)
```

**Streaming (LiveView)**:
```elixir
OpenRouterClient.chat(messages, stream: true, into: self())
# Receives {:openrouter_chunk, "text"} messages
```

**Cost-Aware Call**:
```elixir
# Checks budget before sending
case OpenRouterClient.chat(msgs, check_budget: true) do
  {:error, :budget_exceeded} -> Logger.warning("Budget limit hit")
  {:ok, resp} -> Process.response(resp)
end
```

### 3.3 Operational Commands (CLI)

**Check Budget & Usage**:
```bash
mix openrouter.budget
# Output:
# Daily: $0.45 / $5.00
# Status: HEALTHY
```

**Test Connectivity**:
```bash
mix openrouter.ping
# Output:
# Pong! Latency: 145ms. Model: anthropic/claude-3.5-sonnet
```

**Trace Request**:
```bash
mix openrouter.trace <request_id>
# Output:
# [2026-01-09 10:00:00] Synapse -> OpenRouter -> Guardian (Vetoed)
```

### 3.4 F# Script Usage

**Run Deployment with AI Medic**:
```bash
OPENROUTER_API_KEY=sk-... dotnet fsi lib/cepaf/scripts/ProductionDeploymentOrchestrator.fsx --deploy
```

**Run Tests with AI Analysis**:
```bash
OPENROUTER_API_KEY=sk-... dotnet fsi lib/cepaf/scripts/ComprehensiveRuntimeTests.fsx --mode swarm
```

### 3.5 Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `{:error, :missing_api_key}` | Env var not set | Check `.envrc` or container env |
| `429 Too Many Requests` | Rate limit hit | System auto-retries (backoff). Wait. |
| `402 Payment Required` | OpenRouter credits 0 | Top up OpenRouter account |
| `{:error, :guardian_veto}` | Unsafe prompt | Check `Guardian` logs for veto reason |

---

## 4.0 Compliance & Safety

**STAMP Constraints**:
*   **SC-OR-L3-001**: All proposals MUST pass `Guardian.validate_proposal/1`.
*   **SC-OR-L5-001**: Daily spending limit ENFORCED by `PricingCache`.

**Audit**:
All calls are logged to Zenoh topic `indrajaal/evolution/openrouter/calls`.
**PII Warning**: Logs are redacted by default. Do not enable debug logging in production.

---

## 5.0 Related Documents
- USER_OPERATIONS_GUIDE.md - Daily operations and command reference
- GEMINI.md - Full system specifications
- INDRAJAAL_PRAJNA_EXPLAINED.md - Prajna capabilities
- docs/architecture/OPENROUTER_DYNAMIC_MANAGER_IMPLEMENTATION.md - Implementation details
- OPERATIONAL_RUNBOOK.md - Operating procedures
