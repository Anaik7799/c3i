# OpenRouter Optimization Plan: SIL-6 Biomorphic Integration

**Date**: 2026-01-13
**Version**: 1.0.0
**Status**: APPROVED for Execution

## 1.0 Executive Summary
This plan details the upgrade of the Indrajaal OpenRouter integration to achieve SIL-6 Biomorphic standards. The primary goals are **Zero Data Retention (ZDR)** compliance, **Overload Protection** via rate limiting and smart batching, and **Full Observability** via Zenoh and cost telemetry.

## 2.0 Feature x 10 Degrees of Interaction Analysis

| Degree | Scope | Interaction | Impact | Optimization Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **D1** | **Code (L1)** | `OpenRouterClient` API Calls | Basic connectivity | **Strict Typing**: Use typed structs for Request/Response. **Header Injection**: Standardize `HTTP-Referer`/`X-Title`. |
| **D2** | **Component (L2)** | `ProviderDispatcher` Routing | Selection logic | **ZDR Policy**: Middleware to inject `provider: { "zdr": true }`. **Streaming**: Real `Stream` implementation. |
| **D3** | **Process (L3)** | `PricingCache` Updates | Cost estimation | **Unified Client**: Reuse `OpenRouterClient` logic for model fetching to reduce code duplication. |
| **D4** | **Container (L4)** | Secrets Injection | API Key Security | **Dynamic Loading**: Hot-reload keys from `System.get_env` without restart. |
| **D5** | **Node (L5)** | Rate Limiting | 429 Prevention | **Token Bucket**: Local limiter (15 req/min) with exponential backoff. |
| **D6** | **Mesh (L6)** | Zenoh Telemetry | Usage Tracking | **Cost Aggregation**: Batch telemetry events (1 min windows) to reduce mesh noise. |
| **D7** | **Federation (L7)** | Model Registry | Model Availability | **Shared State**: Expose `PricingCache` to F# via internal API/File to unify model lists. |
| **D8** | **Ecosystem (L8)** | Fallback Strategy | Resilience | **Smart Routing**: Configurable fallback chain (Claude -> Gemini -> Llama). |
| **D9** | **Universe (L9)** | Drift Detection | Quality Assurance | **Golden Prompts**: Periodic benchmarks to verify model IQ stability. |
| **D10** | **Meta (L10)** | Self-Healing | Autonomic Repair | **Auto-Switch**: If a model returns 404/5xx, auto-switch to nearest equivalent in Pricing Cache. |

## 3.0 7-Level Detailed Execution Plan

### L1: Atomic (The Client) - `Indrajaal.AI.OpenRouterClient`
*   **AS-IS**: Basic `Req.post`, no streaming, no ZDR.
*   **TO-BE**:
    *   Add `provider: { "zdr": true }` to default body.
    *   Implement `chat_stream/3` using `Req.post(..., into: self())`.
    *   Standardize headers (`HTTP-Referer`, `X-Title`).
    *   Add `Req` middleware for logging and error normalization.

### L2: Component (The Dispatcher) - `Indrajaal.AI.ProviderDispatcher`
*   **AS-IS**: Stubs streaming, manual cost calc.
*   **TO-BE**:
    *   Connect `chat_stream` to `OpenRouterClient.chat_stream`.
    *   Inject ZDR flag based on `opts[:zdr]`.
    *   Handle `429` with internal retry before failing.

### L3: Process (The Cache) - `Indrajaal.AI.PricingCache`
*   **AS-IS**: Uses `Finch` directly.
*   **TO-BE**:
    *   Refactor to use `Req` for consistency.
    *   Add `cheapest_model(family)` helper (e.g., "cheapest claude").

### L4: Infrastructure (F#) - `Cepaf.Knowledge.OpenRouter`
*   **AS-IS**: Hardcoded "google/gemini-3-pro-preview".
*   **TO-BE**:
    *   Inject model via config/env.
    *   Add ZDR to request DTO.
    *   Align headers with Elixir client.

### L5: Node (Protection) - `Indrajaal.AI.RateLimiter`
*   **AS-IS**: Missing.
*   **TO-BE**:
    *   Implement `GenServer` based Token Bucket.
    *   Check bucket before `OpenRouterClient.chat`.

### L6: Mesh (Observability) - `Indrajaal.Observability.CostTracker`
*   **AS-IS**: Telemetry events.
*   **TO-BE**:
    *   Standardize event schema: `indrajaal.ai.cost` `{model, tokens, cost, provider}`.
    *   Ensure Zenoh publisher subscribes to this event.

### L7: Evolution (Optimization) - `Indrajaal.AI.ModelOptimizer`
*   **AS-IS**: Manual model selection.
*   **TO-BE**:
    *   Function to suggest "Better Model" based on PricingCache trends (e.g., "Switch to Flash-Lite for 50% savings").

## 4.0 Optimization & Recommendations (OpenRouter Specifics)

1.  **ZDR**: Enabled by default for all "Internal" contexts (`system_observer`, `security_audit`). Optional for "Public" interactions.
2.  **Context Caching**: OpenRouter supports prompt caching. We should structure prompts to maximize prefix matching (System Prompt first, stable context second).
3.  **Model Routing**: Use "openrouter/auto" or explicit lists for fallback redundancy if specific models are down.
4.  **Cost Limits**: Set hard limits in `PricingCache` to reject requests if daily budget exceeded.

## 5.0 Implementation Batching (Overload Protection)

*   **Batch 1**: Upgrade Elixir `OpenRouterClient` (ZDR + Streaming).
*   **Batch 2**: Upgrade `ProviderDispatcher` & `PricingCache`.
*   **Batch 3**: Upgrade F# Client.
*   **Batch 4**: Implement Rate Limiter & Telemetry refinements.
