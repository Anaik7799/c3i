# Formal Verification Plan: Chat Processing Pipeline

**Date**: 2026-04-09 | **STAMP**: SC-COG-001, SC-SAFETY-003, SC-FUNC-003
**Status**: PLAN | **Priority**: P1

---

## 1. Problem Statement

The chat processing pipeline has multiple failure modes across 5 inference tiers,
2 gateway channels, voice transcription, and semantic caching. Long chains with
cascading failures must recover and continue — never blackhole a message.

## 2. DAG Analysis — Processing Graph

```
                    ┌─────────────┐
                    │   INGRESS   │ Telegram poll / GChat pull
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  ZENOH PUB  │ 3x retry with backoff
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   CORTEX    │ tokio::spawn (non-blocking)
                    │  CLASSIFY   │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │  SIMPLE  │ │  VOICE   │ │ COMPLEX  │
        │ (direct) │ │(2-stage) │ │  (LLM)   │
        └────┬─────┘ └────┬─────┘ └────┬─────┘
             │            │            │
             │       ┌────▼─────┐     │
             │       │TRANSCRIBE│     │
             │       └────┬─────┘     │
             │            │           │
             │            ▼           ▼
             │       ┌────────────────────┐
             │       │   HEDGED PARALLEL  │
             │       │  Gemini || OpenRT  │
             │       └────────┬───────────┘
             │                │ (fail)
             │       ┌────────▼───────────┐
             │       │ SEQUENTIAL FALLBACK│
             │       │ Ollama4 → Ollama3  │
             │       └────────┬───────────┘
             │                │ (fail)
             │       ┌────────▼───────────┐
             │       │   RULE FALLBACK    │
             │       │   (always works)   │
             │       └────────┬───────────┘
             │                │
             └────────┬───────┘
                      ▼
              ┌──────────────┐
              │   GATEWAY    │ Parallel TG + GC, 1x retry
              └──────────────┘
```

### Critical Path Length
- Simple command: 2 nodes (classify → gateway) = <100ms
- Voice: 5 nodes (classify → transcribe → hedged → gateway) = ~4s
- Complex + all tiers fail: 7 nodes (classify → ack → hedged → ollama4 → ollama3 → rule → gateway) = ~15s max

## 3. TLA+ Specification

```tla+
---- MODULE ChatPipeline ----
EXTENDS Integers, Sequences, FiniteSets

CONSTANTS
    TIERS,          \* {gemini_direct, openrouter, ollama4, ollama3, rule_fallback}
    MAX_RETRIES,    \* 3 for Zenoh, 1 for Gateway
    TIMEOUT_MS      \* 15000 (max response time)

VARIABLES
    state,          \* Intent state: {received, classified, ack_sent, inferring, delivered, failed}
    tier_idx,       \* Current inference tier being tried (0..4)
    cb_state,       \* Circuit breaker state per tier: {closed, open, half_open}
    retries,        \* Retry count for current operation
    zenoh_published,\* Boolean: intent published to Zenoh
    response_sent   \* Boolean: response delivered to at least one channel

TypeInvariant ==
    /\ state \in {"received", "classified", "ack_sent", "inferring", "delivered", "failed"}
    /\ tier_idx \in 0..4
    /\ \A t \in TIERS: cb_state[t] \in {"closed", "open", "half_open"}

\* SAFETY: Every received message eventually gets a response
NoBlackhole ==
    [](state = "received" ~> state = "delivered")

\* SAFETY: Response sent before timeout
ResponseWithinTimeout ==
    [](state = "inferring" ~>
       \/ state = "delivered"
       \/ (state = "delivered" /\ tier_idx = 4))  \* Rule fallback always works

\* SAFETY: Rule fallback never fails
RuleFallbackAlways ==
    [](tier_idx = 4 => state' = "delivered")

\* LIVENESS: Circuit breaker eventually resets
CircuitBreakerRecovery ==
    \A t \in TIERS: [](cb_state[t] = "open" ~> cb_state[t] = "half_open")

\* LIVENESS: Gateway retry eventually delivers
GatewayDelivery ==
    [](state = "inferring" /\ response_sent = FALSE ~> response_sent = TRUE)

Init ==
    /\ state = "received"
    /\ tier_idx = 0
    /\ cb_state = [t \in TIERS |-> "closed"]
    /\ retries = 0
    /\ zenoh_published = FALSE
    /\ response_sent = FALSE

\* Classify intent
Classify ==
    /\ state = "received"
    /\ state' = "classified"
    /\ UNCHANGED <<tier_idx, cb_state, retries, zenoh_published, response_sent>>

\* Try inference at current tier
TryTier ==
    /\ state = "inferring"
    /\ tier_idx < 5
    /\ IF cb_state[TIERS[tier_idx]] = "open"
       THEN \* Skip this tier
            /\ tier_idx' = tier_idx + 1
            /\ UNCHANGED <<state, cb_state, retries, zenoh_published, response_sent>>
       ELSE \* Try this tier
            /\ \/ \* Success
                  /\ state' = "delivered"
                  /\ response_sent' = TRUE
                  /\ cb_state' = [cb_state EXCEPT ![TIERS[tier_idx]] = "closed"]
               \/ \* Failure — try next tier
                  /\ tier_idx' = tier_idx + 1
                  /\ cb_state' = [cb_state EXCEPT ![TIERS[tier_idx]] =
                     IF retries >= 2 THEN "open" ELSE cb_state[TIERS[tier_idx]]]
                  /\ UNCHANGED <<state, zenoh_published, response_sent>>

====
```

## 4. Failure Chain Analysis (Mathematical)

### Probability of reaching Rule Fallback (Tier 5)

Let p_i = probability tier i fails:
- p_gemini = 0.05 (503 overload, ~5% of requests)
- p_openrouter = 0.02 (429 rate limit)
- p_ollama4 = 0.10 (model loading, port 11435 down)
- p_ollama3 = 0.05 (port 11434)

P(rule_fallback) = p_gemini × p_openrouter × p_ollama4 × p_ollama3
                 = 0.05 × 0.02 × 0.10 × 0.05
                 = 0.000005 (0.0005%)

P(at_least_one_tier_works) = 1 - P(rule_fallback) = 0.999995

### Expected Latency (hedged parallel)

E[L_hedged] = min(E[L_gemini], E[L_openrouter])
            = min(900ms, 1100ms) = ~900ms

With circuit breaker skipping failed tiers:
E[L_with_cb] = 900ms × (1 - p_cb_gemini) + 1100ms × p_cb_gemini × (1 - p_cb_or) + ...

### Gateway Delivery Probability

P(telegram_ok) = 0.998
P(gchat_ok) = 0.995
P(at_least_one) = 1 - (1-0.998)(1-0.995) = 0.99999

## 5. Long Chain Failure Scenarios

| Scenario | Chain | Recovery | Max Latency |
|----------|-------|----------|-------------|
| All cloud down, Ollama works | Gemini(5s) → OR(5s) → Ollama4(10s) → response | Auto | 20s |
| All cloud + Ollama down | Gemini(5s) → OR(5s) → Ollama4(5s) → Ollama3(5s) → rule(0ms) | Rule fallback | 20s |
| Gateway TG fail, GC works | Response → TG fail → TG retry → TG fail → GC delivery | Parallel delivery | +2s |
| Zenoh publish fail | Retry 3x with 100ms backoff → dead letter log | Dead letter | +300ms |
| Voice Gemini 503 | Live WS fail → REST 2.5 retry → REST 3.1 → text cascade | Multi-tier | +5s |
| Unicode in response | safe_trunc() at every boundary | No panic | 0ms |
| Cortex task panic | Supervisor restart in 5s | Auto restart | 5s |

## 6. Circuit Breaker State Machine

```
         3 failures
CLOSED ──────────► OPEN
  ▲                  │
  │ success          │ 60s timeout
  │                  ▼
  └──────────── HALF_OPEN
                 (allow 1 request)
```

Formal properties:
- **Liveness**: OPEN → HALF_OPEN after TTL (60s)
- **Safety**: OPEN never allows requests (except 1 probe in HALF_OPEN)
- **Convergence**: Consecutive successes in HALF_OPEN → CLOSED

## 7. Test Coverage for Failure Chains

| Test | Failure Injected | Expected Behavior |
|------|-----------------|-------------------|
| All cloud 503 | Mock Gemini + OR return 503 | Falls to Ollama → response |
| All cloud + Ollama timeout | All 4 tiers timeout | Rule fallback in <20s |
| Gateway TG fail | Mock TG returns 403 | Retry once, GC still delivers |
| Gateway all fail | Both TG + GC fail | Response logged, not lost |
| Zenoh publish fail | Mock Zenoh error | 3 retries, dead letter log |
| Circuit breaker open | Set CB to 3 failures | Tier skipped, next tier tried |
| Unicode in voice transcript | Send emoji-heavy audio | safe_trunc prevents panic |
| 100 rapid messages | Inject 100 msgs in 10s | All processed, no drops |
| Voice + text interleaved | Alternate voice/text | Both paths work concurrently |
| 15s timeout | Mock all tiers slow | Timeout → rule fallback delivered |

## 8. Next Steps

1. Implement TLA+ spec in `specs/tla/ChatPipeline.tla`
2. Run Apalache model checker for bounded verification
3. Add failure injection to sim-test (mock 503, timeout, disconnect)
4. Measure actual P(failure) per tier from TransactionSummary data
5. Create Quint spec for real-time property checking
