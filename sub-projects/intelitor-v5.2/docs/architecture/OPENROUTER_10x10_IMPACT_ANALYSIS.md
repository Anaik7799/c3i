# OpenRouter 10x10 Impact Analysis & Optimization Strategy

**Date**: 2026-01-13
**Target**: SIL-6 Biomorphic Compliance
**Status**: APPROVED

## 1.0 Executive Summary
This document analyzes the integration of OpenRouter (OR) across the Indrajaal system using a 10-level scale x 10-degree interaction matrix. It defines the specifications for a "Biomorphic AI Client" that ensures Zero Data Retention (ZDR), optimal cost routing, and immune-system-like resilience against model failures.

## 2.0 10x10 Deep Analysis Matrix

| Level | Scope | Interaction | Impact | Optimization Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **L1** | **Code** | **API Client** | Raw HTTP calls, Header injection (`HTTP-Referer`, `X-Title`). | **Strict Typing**: Use F# records / Elixir Structs for Request/Response to prevent schema drift. |
| **L2** | **Component** | **ZDR Compliance** | Injecting `provider: { "zdr": true }` into payloads. | **Policy Enforcement**: Middleware that *always* injects ZDR headers for non-public data. |
| **L3** | **Process** | **Streaming** | Handling SSE (Server-Sent Events) for real-time feedback. | **Backpressure**: Reactive streams (GenStage/MailboxProcessor) to handle token generation rates. |
| **L4** | **Container** | **Secrets** | `OPENROUTER_API_KEY` injection. | **Rotation**: Dynamic key reloading without container restart. |
| **L5** | **Node** | **Rate Limiting** | Handling `429` responses locally. | **Token Bucket**: Local rate limiter (15 req/min) to prevent upstream bans. |
| **L6** | **Mesh** | **Cost Telemetry** | Publishing `usage.total_tokens` to Zenoh. | **Aggregation**: `CostTracker` actor aggregates costs per-minute to reduce Zenoh noise. |
| **L7** | **Federation** | **Model Registry** | Syncing available models (`GET /models`). | **Dynamic Selection**: Periodic fetch of model list to discover cheaper/better alternatives. |
| **L8** | **Ecosystem** | **Fallback** | `models: ["anthropic/claude...", "google/gemini..."]`. | **Smart Routing**: Use OR's native fallback + client-side retry for redundancy. |
| **L9** | **Universe** | **Drift** | Tracking answer quality over months. | **Benchmarking**: Daily "Golden Prompt" tests to verify model IQ hasn't degraded. |
| **L10** | **Meta** | **Self-Healing** | AI debugging its own API connection errors. | **Auto-Config**: AI suggests switching model IDs if `404` or `Deprecation` is detected. |

## 3.0 Current Implementation Status & Gaps

### 3.1 Current F# Validator (`CompilationValidatorCore.fsx`)
*   **Status**: Uses `Cortex` module with `simulateApiCall`.
*   **Gap**: No real network calls. No ZDR headers. Hardcoded model IDs.
*   **Risk**: Blindness to real-world latency and cost.

### 3.2 Current Elixir Core (Inferred)
*   **Status**: Likely standard `Req` or `Tesla` client.
*   **Gap**: Unlikely to have advanced ZDR or dynamic routing.

## 4.0 Optimization Strategy (The Biomorphic Client)

### 4.1 ZDR (Zero Data Retention) Mandate
**Rule**: All operational telemetry and code validation requests MUST enable ZDR.
**Implementation**:
```json
{
  "messages": [...],
  "model": "anthropic/claude-3.5-sonnet",
  "provider": {
    "zdr": true
  }
}
```

### 4.2 Cost-Aware Routing
**Rule**: Use "Free/Cheap" models for L1/L2 analysis, "Smart" models for L3+.
**Logic**:
1.  **Reflex**: Check `mistralai/mistral-7b-instruct:free` (Cost: $0).
2.  **Routine**: Check `google/gemini-2.0-flash-lite` (Cost: Very Low).
3.  **Critical**: Check `anthropic/claude-3.5-sonnet` (Cost: Moderate).

### 4.3 Resilience Pattern (The Immune System)
1.  **Circuit Breaker**: Trip after 3 consecutive `5xx` or `429` errors.
2.  **Jittered Backoff**: Wait `2^n + random(ms)` before retrying.
3.  **Fallback Chain**: If Primary Model fails, Client automatically retries with Secondary Model ID.

## 5.0 Implementation Roadmap (Sprint 43/44)

### Phase 1: The "Real" Client (F#)
*   Replace `simulateApiCall` with `Http.Client` implementation.
*   Implement `provider` struct for ZDR.
*   Implement `usage` parsing for Cost.

### Phase 2: System-Wide Integration
*   Port F# logic to Elixir `OpenRouterClient` module.
*   Ensure both clients share Zenoh cost topics.

### Phase 3: Dynamic Evolution
*   Create a task to periodically query `https://openrouter.ai/api/v1/models` and update the `fallbackChain` automatically based on pricing/context length.
