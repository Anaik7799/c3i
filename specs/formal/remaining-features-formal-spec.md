# Remaining Features Formal Specification

**Date**: 2026-04-09 | **Version**: 1.0.0
**STAMP**: SC-COG-001, SC-SAFETY-003, SC-FUNC-003, SC-OPENCLAW-001, SC-FRACTAL-001
**Status**: DEFINITIVE FORMAL SPECIFICATION
**Author**: Claude Opus 4.6 (1M context)
**Ruliology Reference**: `specs/wolfram/c3i-ruliology.wl`, `native/planning_daemon/src/ruliology.rs`

---

## Table of Contents

1. [Rate Limiting per User](#1-rate-limiting-per-user)
2. [Failure Injection Tests](#2-failure-injection-tests)
3. [Automated Voice Test Suite](#3-automated-voice-test-suite)
4. [Audio Response (TTS)](#4-audio-response-tts)
5. [Multilingual Voice Detection](#5-multilingual-voice-detection)
6. [TLA+ Formal Spec](#6-tla-formal-spec)
7. [RAG Pipeline](#7-rag-pipeline)
8. [Voice Function Calling](#8-voice-function-calling)
9. [DuckDB Analytics](#9-duckdb-analytics)
10. [Emotion-Aware Responses](#10-emotion-aware-responses)
11. [Noisy Environment Test Suite](#11-noisy-environment-test-suite)
12. [PII Scrubber](#12-pii-scrubber)
13. [Prompt Injection Protection](#13-prompt-injection-protection)
14. [Zenoh Telemetry for All Commands](#14-zenoh-telemetry-for-all-commands)
15. [Conversation Summarization](#15-conversation-summarization)
16. [WebRTC Streaming (P3)](#16-webrtc-streaming-p3)
17. [Video Processing (P3)](#17-video-processing-p3)
18. [WhatsApp Integration (P3)](#18-whatsapp-integration-p3)
19. [Gemini Live WS Fix](#19-gemini-live-ws-fix)
- [Summary Tables](#summary-tables)

---

## 1. Rate Limiting per User

**Priority**: P1 | **Fractal Layer**: L3 (Transaction), L5 (Cognitive)
**Wolfram Classification**: Generalized Cellular Automaton (counter + timer)

### Mathematical Spec

Token bucket algorithm with per-chat-id state:

```
B(t) = min(B_max, B(t_prev) + r * (t - t_prev) - 1)

Where:
  B_max  = 20 tokens (maximum bucket capacity)
  r      = 1/3 tokens/second (refill rate = 20 tokens/minute)
  t      = current epoch in milliseconds
  t_prev = timestamp of last request

If B(t) < 0:
  reject with HTTP 429 "Rate limited, please wait {ceil((1 - B(t)) / r)} seconds"

Steady-state throughput: lim_{T->inf} N(T)/T = r = 1/3 req/s = 20 req/min
Burst capacity: B_max = 20 consecutive requests at t=0
Recovery time from empty: T_full = B_max / r = 60 seconds
```

### Allium Spec

```allium
-- allium: 3

entity RateLimiter {
  chat_id: String
  tokens: Float = 20.0
  last_request_ms: Integer
  max_tokens: Integer = 20
  refill_rate: Float = 0.333  -- tokens per second (20/60)

  transitions tokens {
    available -> consumed    (tokens > 0)
    consumed  -> available   (elapsed_ms > 3000)
    consumed  -> rejected    (tokens <= 0)
    terminal: none  -- rate limiter is immortal
  }
}

rule RefillTokens {
  when: request arrives
  requires: limiter exists for chat_id
  ensures: limiter.tokens = min(limiter.max_tokens,
    limiter.tokens + limiter.refill_rate * (now_ms - limiter.last_request_ms) / 1000.0)
  @guidance Refill before consume to handle bursts correctly
}

rule ConsumeToken {
  when: request arrives AND limiter.tokens >= 1.0
  ensures: limiter.tokens = limiter.tokens - 1.0
           AND limiter.last_request_ms = now_ms
           AND request proceeds
}

rule RateLimitReject {
  when: request arrives AND limiter.tokens < 1.0
  ensures: response = "Rate limited, please wait"
           AND response.status = 429
           AND limiter.last_request_ms = now_ms
  @guidance Never drop the message, just delay the user
}

invariant TokenBound {
  for l in RateLimiters: 0.0 <= l.tokens <= l.max_tokens
}

invariant NoNegativeTokens {
  for l in RateLimiters: l.tokens >= 0.0
}

config {
  max_tokens: Integer = 20
  refill_rate_per_min: Integer = 20
  cleanup_idle_after_secs: Integer = 3600
}
```

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| Rate limit bypass via multiple chat IDs | 5 | 2 | 3 | 30 | Server-side enforcement per IP + chat_id composite key |
| Token underflow below zero | 3 | 1 | 2 | 6 | Clamp to 0.0 in ConsumeToken rule |
| Clock skew causes negative elapsed time | 4 | 1 | 3 | 12 | Use monotonic clock; clamp elapsed to max(0, delta) |
| HashMap memory leak (abandoned chat IDs) | 3 | 4 | 5 | 60 | Periodic cleanup of entries idle > 3600s |
| Race condition on concurrent requests | 6 | 3 | 4 | 72 | tokio::Mutex per chat_id or DashMap with atomic ops |
| Overflow on tokens calculation (f64) | 2 | 1 | 2 | 4 | f64 has sufficient precision for 20.0 range |

### STAMP

- **SC-API-001**: Rate limiting MUST be enforced server-side
- **SC-API-002**: Rate limit responses MUST include Retry-After header
- **SC-SEC-018**: Request rate limiting MUST prevent DoS

### TLA+ Property

```tla+
\* Safety: tokens never go negative
RateLimitSafety == \A c \in ChatIds: tokens[c] >= 0

\* Liveness: a rate-limited user eventually gets tokens back
RateLimitLiveness == \A c \in ChatIds:
  [](tokens[c] = 0 ~> <>(\E t \in Nat: tokens[c] > 0))

\* Fairness: all chat IDs get equal refill rate
RateLimitFairness == \A c1, c2 \in ChatIds:
  refill_rate[c1] = refill_rate[c2]

\* Bounded: tokens never exceed max
RateLimitBounded == \A c \in ChatIds: tokens[c] <= MAX_TOKENS
```

### Quint

```quint
module RateLimiter {
  const MAX_TOKENS: int = 20
  const REFILL_MS: int = 3000  // 1 token per 3 seconds

  type ChatId = str
  var tokens: ChatId -> int
  var last_ts: ChatId -> int

  action init = {
    tokens' = Map(),
    last_ts' = Map()
  }

  action request(c: ChatId, now: int): bool = {
    val elapsed = now - last_ts.getOrElse(c, 0)
    val refilled = min(MAX_TOKENS, tokens.getOrElse(c, MAX_TOKENS) + elapsed / REFILL_MS)
    if (refilled >= 1) {
      tokens' = tokens.set(c, refilled - 1),
      last_ts' = last_ts.set(c, now),
      true
    } else {
      tokens' = tokens.set(c, refilled),
      last_ts' = last_ts.set(c, now),
      false
    }
  }

  action refill(c: ChatId, now: int): bool = {
    val elapsed = now - last_ts.getOrElse(c, 0)
    val new_tokens = min(MAX_TOKENS, tokens.getOrElse(c, 0) + elapsed / REFILL_MS)
    tokens' = tokens.set(c, new_tokens),
    last_ts' = last_ts.set(c, now),
    true
  }

  val safety = tokens.keys().forall(c => tokens.get(c) >= 0)
  val bounded = tokens.keys().forall(c => tokens.get(c) <= MAX_TOKENS)
}
```

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| RL-001 | Send 20 messages in 1s from same chat_id | All 20 succeed | 5s |
| RL-002 | Send 25 messages in 1s from same chat_id | Messages 21-25 return 429 | 5s |
| RL-003 | Send 20 messages, wait 3s, send 1 more | 21st succeeds (1 token refilled) | 10s |
| RL-004 | Send 20 messages, wait 60s, send 20 more | All 20 succeed (full refill) | 70s |
| RL-005 | Concurrent requests from same chat_id (10 threads) | No race: total consumed <= 20 | 5s |
| RL-006 | Different chat_ids, 20 msgs each simultaneously | All succeed independently | 5s |
| RL-007 | Idle for 3600s, verify cleanup | Entry removed from HashMap | 3601s |
| RL-008 | Check Retry-After header in 429 response | Header present with seconds value | 5s |

---

## 2. Failure Injection Tests

**Priority**: P1 | **Fractal Layer**: L4 (System), L5 (Cognitive)
**Wolfram Classification**: Multiway System (branching failure paths)

### Mathematical Spec

Failure injection creates branches in the multiway inference cascade. For each tier i with injected failure probability p_i:

```
P(tier_i_responds | failure_injected) = 1 - p_i
P(cascade_reaches_tier_k) = prod_{i=1}^{k-1} p_i
P(rule_fallback_reached) = prod_{i=1}^{4} p_i

Expected response tier E[T] = sum_{k=1}^{5} k * P(first_success_at_k)
Where P(first_success_at_k) = (1 - p_k) * prod_{i=1}^{k-1} p_i

NoBlackhole property: P(response) = 1 - P(all_5_tiers_fail)
  = 1 - prod_{i=1}^{4} p_i * 0  (rule fallback never fails)
  = 1
```

### Allium Spec

```allium
-- allium: 3

entity FailureInjector {
  name: String
  target_tier: String  -- gemini_direct | openrouter | ollama4 | ollama3
  failure_type: timeout | error_503 | error_429 | connection_reset | slow_response
  probability: Float = 1.0  -- 1.0 = always inject
  duration_ms: Integer = 0  -- for slow_response type
  active: Boolean = false

  transitions active {
    inactive -> active   (test_starts)
    active   -> inactive (test_ends)
    terminal: none
  }
}

entity FailureScenario {
  name: String
  injectors: List[FailureInjector]
  expected_tier: String  -- which tier should respond
  expected_latency_max_ms: Integer
}

rule InjectTimeout {
  when: request to tier AND injector.active AND injector.failure_type == timeout
  ensures: tier returns timeout after 15000ms
}

rule InjectError503 {
  when: request to tier AND injector.active AND injector.failure_type == error_503
  ensures: tier returns HTTP 503 immediately
}

rule InjectSlowResponse {
  when: request to tier AND injector.active AND injector.failure_type == slow_response
  ensures: tier responds after injector.duration_ms delay
}

rule VerifyCascade {
  when: scenario.injectors all active
  ensures: response arrives from scenario.expected_tier
           AND response.latency <= scenario.expected_latency_max_ms
}

invariant NoBlackhole {
  for s in FailureScenarios: s.response_received == true
  @critical The rule_fallback tier MUST always succeed
}

contract FailureInjectionFramework {
  inject: (tier: String, failure_type: String) -> Boolean
  clear_all: () -> Unit
  verify_cascade: (scenario: FailureScenario) -> TestResult
}
```

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| Injector left active after test | 7 | 3 | 2 | 42 | RAII pattern: clear_all in test teardown |
| Injector affects production traffic | 9 | 1 | 1 | 9 | Feature-gated behind `#[cfg(test)]` / env var |
| All tiers injected but rule_fallback also fails | 10 | 1 | 1 | 10 | Rule fallback is pure computation, no external deps |
| Timeout injection causes test to exceed CI limit | 4 | 3 | 3 | 36 | Cap injection timeout at 5s in tests |
| Race between injection setup and request | 5 | 2 | 4 | 40 | Barrier synchronization: inject before request fires |
| Mock doesn't match real failure behavior | 6 | 4 | 5 | 120 | Periodic chaos test against real infra validates mock fidelity |

### STAMP

- **SC-CHAOS-001**: Failure injection MUST be available in test mode
- **SC-CHAOS-002**: Injected failures MUST be deterministic and reproducible
- **SC-TEST-001**: All failure paths MUST have automated coverage

### TLA+ Property

```tla+
\* Safety: every message gets a response even under failure injection
FailureInjectionSafety ==
  \A msg \in Messages:
    [](msg.state = "received" ~> msg.state = "delivered")

\* Safety: injectors cannot be active in production
ProductionSafety ==
  env = "production" => \A i \in Injectors: i.active = FALSE

\* Liveness: cascade progresses through tiers
CascadeProgress ==
  \A msg \in Messages:
    [](msg.tier_idx = k /\ tier_failed[k] => <>(msg.tier_idx = k + 1))
```

### Quint

```quint
module FailureInjection {
  type Tier = str  // "gemini" | "openrouter" | "ollama4" | "ollama3" | "rule"
  type FailureType = str  // "timeout" | "503" | "429" | "reset"

  var injected: Set[Tier]
  var tier_idx: int
  var response_received: bool

  action inject_failure(t: Tier): bool = {
    injected' = injected.union(Set(t)),
    tier_idx' = tier_idx,
    response_received' = response_received
  }

  action try_tier(t: Tier): bool = {
    if (injected.contains(t)) {
      tier_idx' = tier_idx + 1,
      injected' = injected,
      response_received' = response_received
    } else {
      tier_idx' = tier_idx,
      injected' = injected,
      response_received' = true
    }
  }

  action rule_fallback: bool = {
    response_received' = true,
    tier_idx' = tier_idx,
    injected' = injected
  }

  val no_blackhole = true  // rule_fallback always succeeds
}
```

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| FI-001 | Inject 503 on Gemini, send message | Falls to OpenRouter, response received | 15s |
| FI-002 | Inject 503 on Gemini + OpenRouter | Falls to Ollama, response received | 20s |
| FI-003 | Inject timeout on all 4 cloud tiers | Rule fallback responds | 25s |
| FI-004 | Inject slow_response (8s) on Gemini | OpenRouter wins hedged race | 10s |
| FI-005 | Inject 429 on OpenRouter | Circuit breaker opens after 3 failures | 30s |
| FI-006 | All injections active, then clear_all | Next request uses Gemini normally | 10s |
| FI-007 | Inject connection_reset on Gemini | Retry once, then fall to OpenRouter | 15s |
| FI-008 | 100 rapid messages with Gemini injected 503 | All 100 get responses via fallback tiers | 120s |
| FI-009 | Circuit breaker opens on Gemini, wait 60s | Gemini probe succeeds, CB closes | 75s |

---

## 3. Automated Voice Test Suite

**Priority**: P1 | **Fractal Layer**: L1 (Atomic), L5 (Cognitive)
**Wolfram Classification**: Pattern-Matching Rewriting System (audio -> text -> response)

### Mathematical Spec

Voice processing pipeline accuracy model:

```
WER (Word Error Rate) = (S + D + I) / N

Where:
  S = substitutions, D = deletions, I = insertions, N = total reference words

Accuracy = 1 - WER

Target thresholds by condition:
  Clean audio (SNR > 30dB):     WER < 5%    (Accuracy > 95%)
  Moderate noise (SNR 15-30dB): WER < 15%   (Accuracy > 85%)
  Heavy noise (SNR < 15dB):     WER < 30%   (Accuracy > 70%)
  Accented English:             WER < 10%   (Accuracy > 90%)

P(correct_intent | transcript) = P(transcript | audio) * P(intent | transcript)
  where P(transcript | audio) depends on SNR and accent
  and P(intent | transcript) depends on classifier accuracy (~98%)
```

### Allium Spec

```allium
-- allium: 3

entity VoiceTestSample {
  filename: String
  format: wav_16k_mono | ogg_opus | mp3
  language: String = "en"
  expected_transcript: String
  snr_db: Float  -- signal-to-noise ratio
  accent: none | indian | german | british | australian
  duration_secs: Float
}

entity VoiceTestResult {
  sample: VoiceTestSample
  actual_transcript: String
  wer: Float
  latency_ms: Integer
  tier_used: String  -- gemini_live | gemini_rest | whisper | rule_fallback
  passed: Boolean
}

rule TranscribeCleanAudio {
  when: sample.snr_db > 30
  ensures: result.wer < 0.05
  @guidance Use Gemini 2.5 Flash REST for reliable transcription
}

rule TranscribeNoisyAudio {
  when: sample.snr_db < 15
  ensures: result.wer < 0.30 OR result.tier_used == "rule_fallback"
  @guidance Gemini Live has native noise robustness
}

rule TranscribeAccentedAudio {
  when: sample.accent != none
  ensures: result.wer < 0.10
  @guidance Accent learning improves with sample count
}

invariant AllSamplesProcessed {
  for s in VoiceTestSamples: exists r in VoiceTestResults: r.sample == s
}

config {
  test_audio_dir: String = "test/fixtures/audio/"
  max_latency_ms: Integer = 10000
  min_samples: Integer = 20
}
```

### Test Audio Samples

| Sample | URL/Source | Duration | Language | SNR | Expected Transcript |
|---|---|---|---|---|---|
| clean_en_01.wav | LibriSpeech clean test set | 5.2s | en | 35dB | "The quick brown fox jumps over the lazy dog" |
| clean_en_02.wav | LibriSpeech clean test set | 3.8s | en | 38dB | "Please check the system status" |
| noisy_street_01.wav | DEMAND noise dataset + speech | 6.1s | en | 12dB | "Stop all containers immediately" |
| noisy_wind_01.wav | DEMAND noise dataset + speech | 4.5s | en | 18dB | "What is the current health status" |
| accent_indian_01.wav | Mozilla Common Voice | 4.0s | en-IN | 28dB | "Add a new task priority zero" |
| accent_german_01.wav | Mozilla Common Voice | 3.5s | en-DE | 30dB | "Show me the latest email" |
| short_01.wav | Synthesized | 0.8s | en | 35dB | "Yes" |
| long_01.wav | LibriSpeech | 45.0s | en | 32dB | (paragraph of text) |
| hindi_01.wav | Mozilla Common Voice | 5.0s | hi | 25dB | (Hindi greeting) |
| silence_01.wav | Generated | 3.0s | -- | 0dB | "" |

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| Test audio files missing from repo | 4 | 2 | 1 | 8 | Git LFS or download script in CI |
| ffmpeg not installed in CI | 8 | 2 | 2 | 32 | Dockerfile includes ffmpeg; test skips gracefully |
| WER calculation bug (wrong alignment) | 5 | 2 | 4 | 40 | Use jiwer library with known-good WER implementation |
| Test flaky due to API rate limits | 4 | 5 | 3 | 60 | Mock Gemini API in unit tests; real API in integration only |
| Audio too short for Gemini (<1s) | 3 | 3 | 5 | 45 | Filter samples by duration >= 1.0s |
| Unicode in transcript causes panic | 9 | 1 | 1 | 9 | safe_trunc already fixed (V4 in FMEA) |

### STAMP

- **SC-TEST-001**: All failure paths MUST have automated coverage
- **SC-TEST-050**: Voice tests MUST cover clean/noisy/accented scenarios
- **SC-SIM-001**: Simulation environment for voice testing

### TLA+ Property

```tla+
\* Safety: every audio sample produces a result
VoiceTestCompleteness ==
  \A s \in Samples: <>(result[s] /= NULL)

\* Safety: WER within threshold for clean audio
CleanAudioAccuracy ==
  \A s \in Samples: s.snr > 30 => result[s].wer < 0.05

\* Liveness: test suite completes within timeout
TestSuiteTermination ==
  <>(test_suite_state = "complete")
```

### Quint

```quint
module VoiceTestSuite {
  type Sample = { name: str, snr: int, expected: str }
  type Result = { sample: Sample, wer: int, passed: bool }  // wer in percent

  var results: List[Result]
  var pending: Set[Sample]

  action run_test(s: Sample, actual_wer: int): bool = {
    val threshold = if (s.snr > 30) 5 else if (s.snr > 15) 15 else 30
    val passed = actual_wer <= threshold
    results' = results.append({ sample: s, wer: actual_wer, passed: passed }),
    pending' = pending.exclude(Set(s))
  }

  val all_complete = pending.size() == 0
  val accuracy = results.filter(r => r.passed).size() * 100 / results.size()
}
```

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| VT-001 | Clean English 5s WAV -> transcribe | WER < 5% | 10s |
| VT-002 | Noisy street audio (12dB SNR) | WER < 30%, response delivered | 15s |
| VT-003 | Indian-accented English | WER < 10% | 10s |
| VT-004 | Audio < 1s duration | Graceful handling (min duration check) | 5s |
| VT-005 | Audio > 60s duration | Truncated, partial transcript | 30s |
| VT-006 | Silence-only audio | Empty transcript, no panic | 10s |
| VT-007 | Hindi voice message | Language detected as "hi", transcript valid | 15s |
| VT-008 | 10 concurrent voice messages | All processed, no drops | 60s |

---

## 4. Audio Response (TTS)

**Priority**: P1 | **Fractal Layer**: L1 (Atomic), L6 (Ecosystem)
**Wolfram Classification**: Causal Graph (text -> PCM -> OGG -> Telegram)

### Mathematical Spec

Audio encoding pipeline:

```
Pipeline: text -> Gemini Live (PCM 24kHz 16-bit LE) -> OGG Opus encoder -> Telegram sendVoice

PCM specifications:
  Sample rate:    f_s = 24000 Hz
  Bit depth:      16 bits (signed little-endian)
  Channels:       1 (mono)
  Bytes/second:   f_s * 2 = 48000 bytes/s
  Duration(n):    n / (f_s * 2) seconds

OGG Opus encoding:
  Bitrate:    64 kbps (voice optimized)
  Frame size: 20ms
  Complexity: 5 (balance quality/CPU)

Compression ratio: R = PCM_size / OGG_size ~ 48000*8 / 64000 = 6:1

Latency budget:
  Gemini Live TTS generation: ~500ms (first chunk)
  PCM accumulation:           ~duration_ms
  OGG encoding:               ~50ms
  Telegram upload:             ~200ms
  Total first-byte:            ~750ms
  Total end-to-end:            ~(duration + 750)ms
```

### Allium Spec

```allium
-- allium: 3

entity AudioResponse {
  text: String
  pcm_data: Bytes  -- raw PCM 24kHz 16-bit LE mono
  ogg_data: Bytes  -- OGG Opus encoded
  duration_ms: Integer
  telegram_file_id: String  -- after upload

  transitions status {
    text_ready     -> pcm_generated   (gemini_live_responds)
    pcm_generated  -> ogg_encoded     (opus_encode_succeeds)
    ogg_encoded    -> delivered        (telegram_sendVoice_ok)
    pcm_generated  -> fallback_text   (opus_encode_fails)
    text_ready     -> fallback_text   (gemini_live_unavailable)
    terminal: delivered, fallback_text
  }
}

rule GeneratePCM {
  when: text_ready AND gemini_live_connected
  requires: text.length > 0 AND text.length < 4096
  ensures: pcm_data.length > 0
           AND pcm_data.sample_rate == 24000
           AND pcm_data.bit_depth == 16
  @guidance Set responseModalities: ["AUDIO", "TEXT"] in Gemini Live setup
}

rule EncodeOGG {
  when: pcm_generated
  ensures: ogg_data = opus_encode(pcm_data, bitrate=64000, frame_size_ms=20)
           AND ogg_data.length < pcm_data.length  -- compression must work
}

rule DeliverVoice {
  when: ogg_encoded
  ensures: telegram.sendVoice(chat_id, ogg_data) succeeds
           AND telegram_file_id is set
}

rule FallbackToText {
  when: (gemini_live_unavailable OR opus_encode_fails)
  ensures: telegram.sendMessage(chat_id, text) succeeds
  @guidance Never lose the response; text is always valid fallback
}

invariant ResponseDelivered {
  for r in AudioResponses: r.status in {delivered, fallback_text}
}

contract AudioCodec {
  encode_opus: (pcm: Bytes, bitrate: Integer) -> Result[Bytes, Error]
  decode_opus: (ogg: Bytes) -> Result[Bytes, Error]
  @invariant Lossless round-trip not guaranteed (lossy codec)
}
```

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| Gemini Live unavailable for TTS | 4 | 5 | 1 | 20 | Fallback to text response |
| PCM data corrupted (wrong sample rate) | 6 | 2 | 4 | 48 | Validate PCM header: assert rate=24000, depth=16 |
| OGG Opus encoding fails | 5 | 1 | 2 | 10 | Fallback to text; log encoding error |
| Telegram sendVoice rejects file | 4 | 2 | 2 | 16 | Validate OGG size < 50MB, duration < 300s |
| Audio quality too low (bitrate) | 3 | 3 | 6 | 54 | A/B test at 48/64/96 kbps; default 64kbps |
| Memory spike from large PCM buffer | 5 | 2 | 3 | 30 | Stream PCM in chunks, encode incrementally |

### STAMP

- **SC-OPENCLAW-001**: Continuous voice capability
- **SC-HMI-010**: Vibrant, correct feedback to operator

### TLA+ Property

```tla+
\* Safety: every TTS request produces audio OR text fallback
TTSSafety ==
  \A r \in AudioRequests:
    [](r.state = "text_ready" ~>
       (r.state = "delivered" \/ r.state = "fallback_text"))

\* Safety: PCM format is always valid
PCMFormatSafety ==
  \A r \in AudioRequests:
    r.state = "pcm_generated" =>
      r.sample_rate = 24000 /\ r.bit_depth = 16

\* Liveness: delivery completes within timeout
TTSLiveness ==
  \A r \in AudioRequests:
    [](r.state = "text_ready" ~>
       <>[<=10000ms](r.state \in {"delivered", "fallback_text"}))
```

### Quint

```quint
module AudioResponse {
  type Status = str  // "text_ready" | "pcm_ok" | "ogg_ok" | "delivered" | "text_fallback"

  var status: Status
  var pcm_size: int
  var ogg_size: int

  action generate_pcm(success: bool): bool = {
    if (success and status == "text_ready") {
      status' = "pcm_ok",
      pcm_size' = 48000,  // 1 second of audio
      ogg_size' = ogg_size
    } else {
      status' = "text_fallback",
      pcm_size' = 0,
      ogg_size' = 0
    }
  }

  action encode_ogg(success: bool): bool = {
    if (success and status == "pcm_ok") {
      status' = "ogg_ok",
      ogg_size' = pcm_size / 6,  // ~6:1 compression
      pcm_size' = pcm_size
    } else {
      status' = "text_fallback",
      pcm_size' = pcm_size,
      ogg_size' = 0
    }
  }

  val always_delivered = status == "delivered" or status == "text_fallback"
  val compression_works = status == "ogg_ok" implies ogg_size < pcm_size
}
```

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| TTS-001 | Generate audio for "Hello, this is a test" | OGG file produced, duration ~2s | 10s |
| TTS-002 | Send audio response via Telegram sendVoice | Voice message appears in chat | 15s |
| TTS-003 | Gemini Live unavailable, fallback to text | Text message sent instead | 10s |
| TTS-004 | Long text (500 words) TTS | Audio <= 60s, or truncated | 30s |
| TTS-005 | Validate PCM format: 24kHz, 16-bit, mono | Assertion passes | 5s |
| TTS-006 | Validate OGG size < PCM size | Compression ratio > 3:1 | 5s |

---

## 5. Multilingual Voice Detection

**Priority**: P1 | **Fractal Layer**: L5 (Cognitive)
**Wolfram Classification**: Pattern-Matching Classifier (audio features -> language ID)

### Mathematical Spec

Language detection as maximum-likelihood classification:

```
L* = argmax_{l in Languages} P(audio | language = l)

Using Gemini's native multilingual capability:
  P(correct_detection | audio_duration > 3s) > 0.95
  P(correct_detection | audio_duration < 1s) > 0.70

Supported languages: 90+ via Gemini 2.5 Flash
Primary languages (optimized): en, hi, de, fr, es, ja, zh, ar, pt, ru

Response language policy:
  If detected_language in user_preferences.languages:
    respond_in(detected_language)
  Else:
    respond_in(user_preferences.default_language OR "en")
```

### Allium Spec

```allium
-- allium: 3

entity LanguageDetection {
  audio_sample: Bytes
  detected_language: String  -- ISO 639-1 code
  confidence: Float          -- 0.0 to 1.0
  duration_secs: Float

  transitions state {
    pending   -> detected    (gemini_returns_language)
    pending   -> fallback_en (detection_fails OR confidence < 0.5)
    terminal: detected, fallback_en
  }
}

entity UserLanguageProfile {
  chat_id: String
  preferred_languages: List[String] = ["en"]
  detected_history: List[{lang: String, count: Integer}]
  auto_detect: Boolean = true
}

rule DetectLanguage {
  when: voice_message_received AND user.auto_detect == true
  ensures: detection.detected_language is valid ISO 639-1
           AND detection.confidence > 0.0
  @guidance Use Gemini's built-in language detection via audio analysis
}

rule AdaptResponseLanguage {
  when: detection.detected_language != "en"
        AND detection.confidence > 0.7
  ensures: response.language = detection.detected_language
           AND systemInstruction includes "Respond in {lang}"
}

rule FallbackToEnglish {
  when: detection.confidence < 0.5
  ensures: response.language = "en"
}

invariant LanguageConsistency {
  for r in Responses: r.language in SUPPORTED_LANGUAGES
}

config {
  supported_languages: List[String] = ["en", "hi", "de", "fr", "es", "ja", "zh", "ar", "pt", "ru"]
  confidence_threshold: Float = 0.7
  history_window: Integer = 50  -- last 50 detections for profile
}
```

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| Wrong language detected | 5 | 3 | 6 | 90 | Confidence threshold; user can set preference |
| Response in wrong language | 5 | 3 | 3 | 45 | User preference overrides auto-detect |
| Code-switching (mixed language) | 4 | 4 | 7 | 112 | Default to primary language of longest segment |
| Unsupported language (Swahili, etc.) | 3 | 2 | 5 | 30 | Fallback to English with "Language not supported" note |
| Short audio insufficient for detection | 3 | 4 | 5 | 60 | Minimum 1.5s audio for reliable detection |
| Accent misclassified as different language | 5 | 3 | 6 | 90 | Combine audio + text cues; accent learning profile |

### STAMP

- **SC-SEM-001**: Semantic analysis must handle multilingual input
- **SC-HMI-001**: Interface accessible regardless of language

### TLA+ Property

```tla+
\* Safety: response language is always a supported language
LanguageSafety ==
  \A r \in Responses: r.language \in SUPPORTED_LANGUAGES

\* Safety: low-confidence detection falls back to English
LowConfidenceSafety ==
  \A d \in Detections: d.confidence < 0.5 => response_lang[d.chat_id] = "en"

\* Liveness: detection always completes
DetectionLiveness ==
  \A d \in Detections: <>(d.state \in {"detected", "fallback_en"})
```

### Quint

```quint
module MultilingualDetection {
  const SUPPORTED: Set[str] = Set("en", "hi", "de", "fr", "es", "ja", "zh", "ar", "pt", "ru")
  const THRESHOLD: int = 70  // confidence * 100

  var detected_lang: str
  var confidence: int  // 0-100

  action detect(lang: str, conf: int): bool = {
    if (SUPPORTED.contains(lang) and conf >= THRESHOLD) {
      detected_lang' = lang,
      confidence' = conf
    } else {
      detected_lang' = "en",
      confidence' = conf
    }
  }

  val valid_language = SUPPORTED.contains(detected_lang)
}
```

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| ML-001 | Send English audio, verify detection | detected_language = "en", confidence > 0.9 | 10s |
| ML-002 | Send Hindi audio | detected_language = "hi", response in Hindi | 15s |
| ML-003 | Send German audio | detected_language = "de", response in German | 15s |
| ML-004 | Send mixed Hindi-English (code-switching) | Primary language detected, response coherent | 15s |
| ML-005 | Send 0.5s audio (too short) | Falls back to English, no crash | 10s |
| ML-006 | User sets preference to "de", sends English | Response in English (audio overrides) | 15s |

---

## 6. TLA+ Formal Spec

**Priority**: P1 | **Fractal Layer**: L0 (Constitutional), L7 (Federation)
**Wolfram Classification**: Causal Graph (full pipeline DAG)

### Mathematical Spec

The ChatPipeline TLA+ spec models the complete message processing DAG from the formal verification plan. Key state space:

```
State space S = {received, classified, ack_sent, inferring, delivered, failed}
Tier index T = {0, 1, 2, 3, 4}  -- 5 inference tiers
CB states C = {closed, open, half_open}^5  -- per-tier circuit breakers

|S| * |T| * |C| = 6 * 5 * 3^5 = 7,290 reachable states

Properties to verify:
  1. NoBlackhole:       [](received ~> delivered)          -- temporal safety
  2. ResponseTimeout:   [](inferring => <>[<=15s] delivered) -- bounded liveness
  3. RuleFallbackNever: [](tier=4 => next_state=delivered)  -- deterministic
  4. CBRecovery:        [](cb=open ~> cb=half_open)        -- liveness
  5. TypeInvariant:     state in S /\ tier in T /\ cb in C -- type safety
```

### Allium Spec

```allium
-- allium: 3

entity ChatPipeline {
  state: received | classified | ack_sent | inferring | delivered | failed
  tier_idx: Integer = 0  -- 0..4
  retries: Integer = 0
  zenoh_published: Boolean = false
  response_sent: Boolean = false

  transitions state {
    received   -> classified   (classify_intent)
    classified -> ack_sent     (ack_if_complex)
    classified -> inferring    (simple_or_complex)
    ack_sent   -> inferring    (start_inference)
    inferring  -> delivered    (tier_succeeds)
    inferring  -> inferring    (tier_fails_try_next)
    inferring  -> delivered    (rule_fallback)
    terminal: delivered, failed
  }
}

entity CircuitBreaker {
  tier: String
  state: closed | open | half_open
  failure_count: Integer = 0
  last_failure_epoch: Integer
  threshold: Integer = 3
  cooldown_secs: Integer = 60

  transitions state {
    closed    -> open       (failure_count >= threshold)
    open      -> half_open  (now - last_failure_epoch >= cooldown_secs)
    half_open -> closed     (probe_succeeds)
    half_open -> open       (probe_fails)
    terminal: none
  }
}

rule ClassifyIntent {
  when: pipeline.state == received
  ensures: pipeline.state = classified
           AND intent in {simple, voice, complex}
}

rule TryInferenceTier {
  when: pipeline.state == inferring AND pipeline.tier_idx < 5
  requires: cb[tiers[pipeline.tier_idx]].state != open
  ensures: (tier_success AND pipeline.state = delivered AND pipeline.response_sent = true)
           OR (tier_failure AND pipeline.tier_idx = pipeline.tier_idx + 1)
}

rule RuleFallback {
  when: pipeline.tier_idx == 4
  ensures: pipeline.state = delivered
           AND pipeline.response_sent = true
  @critical Rule fallback MUST always succeed (no external dependencies)
}

invariant NoBlackhole {
  for p in ChatPipelines: p.state == received implies eventually(p.state == delivered)
}

invariant TierBound {
  for p in ChatPipelines: 0 <= p.tier_idx <= 4
}

invariant CBTriState {
  for cb in CircuitBreakers: cb.state in {closed, open, half_open}
}
```

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| State space explosion in model checker | 4 | 3 | 3 | 36 | Bounded model checking (Apalache) with k=20 steps |
| TLA+ spec diverges from Rust implementation | 7 | 4 | 5 | 140 | Weekly allium:weed check for spec-code drift |
| Missing state transition in spec | 8 | 2 | 4 | 64 | Code review + property-based testing against spec |
| Liveness property unprovable (infinite traces) | 3 | 3 | 6 | 54 | Use bounded liveness with explicit step count |
| Apalache OOM on full state space | 5 | 3 | 3 | 45 | Decompose into sub-specs per subsystem |

### STAMP

- **SC-VER-074**: Constitutional L0-L7 hold
- **SC-SAFETY-003**: Complete audit trail
- **SC-FUNC-003**: Rollback path for every change

### TLA+ Property (Full Spec)

```tla+
---- MODULE ChatPipeline ----
EXTENDS Integers, Sequences, FiniteSets

CONSTANTS
    TIERS,          \* {"gemini_direct", "openrouter", "ollama4", "ollama3", "rule_fallback"}
    MAX_RETRIES,    \* 3 for Zenoh, 1 for Gateway
    TIMEOUT_MS      \* 15000

VARIABLES
    state,          \* {received, classified, ack_sent, inferring, delivered, failed}
    tier_idx,       \* 0..4
    cb_state,       \* [t \in TIERS |-> {"closed", "open", "half_open"}]
    retries,
    zenoh_published,
    response_sent

TypeInvariant ==
    /\ state \in {"received", "classified", "ack_sent", "inferring", "delivered", "failed"}
    /\ tier_idx \in 0..4
    /\ \A t \in TIERS: cb_state[t] \in {"closed", "open", "half_open"}

NoBlackhole ==
    [](state = "received" ~> state = "delivered")

ResponseWithinTimeout ==
    [](state = "inferring" ~> <>(state = "delivered"))

RuleFallbackAlways ==
    [](tier_idx = 4 => state' = "delivered")

CircuitBreakerRecovery ==
    \A t \in TIERS: [](cb_state[t] = "open" ~> cb_state[t] = "half_open")

GatewayDelivery ==
    [](state = "inferring" /\ response_sent = FALSE ~> response_sent = TRUE)

Init ==
    /\ state = "received"
    /\ tier_idx = 0
    /\ cb_state = [t \in TIERS |-> "closed"]
    /\ retries = 0
    /\ zenoh_published = FALSE
    /\ response_sent = FALSE

Classify ==
    /\ state = "received"
    /\ state' = "classified"
    /\ UNCHANGED <<tier_idx, cb_state, retries, zenoh_published, response_sent>>

StartInference ==
    /\ state = "classified"
    /\ state' = "inferring"
    /\ UNCHANGED <<tier_idx, cb_state, retries, zenoh_published, response_sent>>

TryTier ==
    /\ state = "inferring"
    /\ tier_idx < 5
    /\ IF cb_state[TIERS[tier_idx + 1]] = "open"
       THEN /\ tier_idx' = tier_idx + 1
            /\ UNCHANGED <<state, cb_state, retries, zenoh_published, response_sent>>
       ELSE \/ /\ state' = "delivered"
               /\ response_sent' = TRUE
               /\ cb_state' = [cb_state EXCEPT ![TIERS[tier_idx + 1]] = "closed"]
               /\ UNCHANGED <<tier_idx, retries, zenoh_published>>
            \/ /\ tier_idx' = tier_idx + 1
               /\ UNCHANGED <<state, retries, zenoh_published, response_sent>>
               /\ cb_state' = [cb_state EXCEPT ![TIERS[tier_idx + 1]] =
                  IF retries >= 2 THEN "open" ELSE cb_state[TIERS[tier_idx + 1]]]

RuleFallback ==
    /\ state = "inferring"
    /\ tier_idx = 4
    /\ state' = "delivered"
    /\ response_sent' = TRUE
    /\ UNCHANGED <<tier_idx, cb_state, retries, zenoh_published>>

Next == Classify \/ StartInference \/ TryTier \/ RuleFallback

Spec == Init /\ [][Next]_<<state, tier_idx, cb_state, retries, zenoh_published, response_sent>>

====
```

### Quint

```quint
module ChatPipeline {
  type State = str  // received | classified | inferring | delivered
  type CBState = str  // closed | open | half_open
  type Tier = str

  const TIERS: List[Tier] = ["gemini", "openrouter", "ollama4", "ollama3", "rule"]

  var state: State
  var tier_idx: int
  var cb: Tier -> CBState
  var response_sent: bool

  action init = {
    state' = "received",
    tier_idx' = 0,
    cb' = TIERS.foldl(Map(), (m, t) => m.set(t, "closed")),
    response_sent' = false
  }

  action classify: bool = state == "received" and state' == "classified"

  action try_tier: bool = {
    state == "inferring" and tier_idx < 5 and
    if (cb.get(TIERS[tier_idx]) == "open") {
      tier_idx' = tier_idx + 1
    } else {
      nondet success = oneOf(Set(true, false))
      if (success) {
        state' = "delivered",
        response_sent' = true
      } else {
        tier_idx' = tier_idx + 1
      }
    }
  }

  action rule_fallback: bool = {
    state == "inferring" and tier_idx == 4 and
    state' = "delivered" and response_sent' = true
  }

  val no_blackhole = state == "received" implies eventually(state == "delivered")
  val type_ok = tier_idx >= 0 and tier_idx <= 4
}
```

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| TLA-001 | Run Apalache on ChatPipeline.tla with k=20 | NoBlackhole verified | 300s |
| TLA-002 | Verify TypeInvariant holds for all states | PASS | 60s |
| TLA-003 | Verify RuleFallbackAlways property | PASS | 60s |
| TLA-004 | Verify CircuitBreakerRecovery liveness | PASS | 120s |
| TLA-005 | Count reachable states | <= 7,290 | 60s |
| TLA-006 | Run Quint simulator for 1000 traces | All traces reach "delivered" | 30s |

---

## 7. RAG Pipeline

**Priority**: P1 | **Fractal Layer**: L3 (Transaction), L5 (Cognitive)
**Wolfram Classification**: Semantic Cache Rewriting System

### Mathematical Spec

Retrieval-Augmented Generation with Smriti FTS5:

```
RAG(query) = LLM(prompt(query, context(query)))

context(query) = top_k(FTS5_search(Smriti.db, query), k=5)

FTS5_search(db, q) = SELECT content, rank
                      FROM smriti_fts
                      WHERE smriti_fts MATCH bm25_tokenize(q)
                      ORDER BY rank
                      LIMIT k

prompt(q, ctx) = system_instruction
               + "\n\nRelevant context:\n" + join(ctx, "\n---\n")
               + "\n\nUser query: " + q

Token budget:
  system_instruction: ~500 tokens
  context:            ~2000 tokens (k=5 * ~400 tokens each)
  query:              ~200 tokens
  total_input:        ~2700 tokens
  max_output:         ~1000 tokens
  total:              ~3700 tokens per RAG call

Cost: ~3700 * $0.15/1M = $0.000555 per RAG query (Gemini 2.5 Flash)
```

### Allium Spec

```allium
-- allium: 3

entity RAGPipeline {
  query: String
  context_docs: List[Document]
  augmented_prompt: String
  response: String

  transitions state {
    query_received -> context_retrieved (fts5_search_complete)
    context_retrieved -> prompt_built   (context_injected)
    prompt_built -> response_generated  (llm_responds)
    query_received -> direct_inference  (no_context_found)
    terminal: response_generated, direct_inference
  }
}

entity Document {
  id: String
  content: String
  source: String  -- "conversation" | "knowledge" | "task" | "journal"
  relevance_score: Float
  token_count: Integer
}

rule SearchContext {
  when: query_received
  ensures: context_docs = fts5_search(query, k=5)
           AND sum(doc.token_count for doc in context_docs) <= 2000
  @guidance Use BM25 ranking from SQLite FTS5
}

rule BuildPrompt {
  when: context_retrieved AND context_docs.length > 0
  ensures: augmented_prompt contains system_instruction
           AND augmented_prompt contains all context_docs
           AND augmented_prompt contains query
           AND token_count(augmented_prompt) <= 4000
}

rule FallbackDirect {
  when: context_docs.length == 0
  ensures: augmented_prompt = system_instruction + query
  @guidance No context found; proceed with direct inference
}

invariant TokenBudget {
  for p in RAGPipelines: token_count(p.augmented_prompt) <= 4000
}

config {
  k: Integer = 5
  max_context_tokens: Integer = 2000
  fts5_table: String = "smriti_fts"
}
```

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| FTS5 returns irrelevant context | 5 | 4 | 6 | 120 | BM25 ranking + relevance threshold > 0.3 |
| Context exceeds token budget | 4 | 3 | 2 | 24 | Truncate to 2000 tokens, drop lowest-ranked docs |
| Smriti.db locked during search | 5 | 2 | 3 | 30 | WAL mode; read-only queries never block |
| RAG adds latency (+200ms) | 3 | 8 | 2 | 48 | FTS5 search < 10ms; acceptable overhead |
| Context injection causes hallucination | 6 | 3 | 7 | 126 | Clear "context" vs "query" separation in prompt |
| Empty Smriti.db (new install) | 3 | 2 | 2 | 12 | Fallback to direct inference gracefully |

### STAMP

- **SC-SMRITI-131**: Full-text search uses FTS5
- **SC-SMRITI-133**: Query timeout < 500ms
- **SC-IKE-001**: Document ingestion pipeline

### TLA+ Property

```tla+
\* Safety: augmented prompt never exceeds token budget
RAGTokenSafety == \A p \in Pipelines: token_count(p.prompt) <= 4000

\* Safety: RAG always produces a response (with or without context)
RAGCompleteness == \A p \in Pipelines:
  [](p.state = "query_received" ~>
     (p.state = "response_generated" \/ p.state = "direct_inference"))

\* Safety: FTS5 search completes within timeout
FTS5Bounded == \A p \in Pipelines: fts5_latency_ms < 500
```

### Quint

```quint
module RAGPipeline {
  const MAX_CONTEXT_TOKENS: int = 2000
  const K: int = 5

  type Doc = { content: str, score: int, tokens: int }

  var context: List[Doc]
  var total_tokens: int
  var has_response: bool

  action search(results: List[Doc]): bool = {
    val filtered = results.filter(d => d.score > 30).slice(0, K)
    val budget_docs = budget_fit(filtered, MAX_CONTEXT_TOKENS)
    context' = budget_docs,
    total_tokens' = budget_docs.foldl(0, (sum, d) => sum + d.tokens),
    has_response' = has_response
  }

  action generate: bool = {
    has_response' = true,
    context' = context,
    total_tokens' = total_tokens
  }

  val token_budget_ok = total_tokens <= MAX_CONTEXT_TOKENS
  val always_responds = has_response
}
```

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| RAG-001 | Query with matching context in Smriti | Context injected, response references context | 10s |
| RAG-002 | Query with no matching context | Direct inference, response still coherent | 10s |
| RAG-003 | FTS5 search latency | < 10ms for 10K documents | 1s |
| RAG-004 | Context token count validation | Never exceeds 2000 tokens | 5s |
| RAG-005 | 100 concurrent RAG queries | All complete, no Smriti.db lock | 30s |
| RAG-006 | Query with 5+ relevant documents | Top-5 by BM25 rank selected | 5s |

---

## 8. Voice Function Calling

**Priority**: P2 | **Fractal Layer**: L4 (System), L5 (Cognitive)
**Wolfram Classification**: Multiway System (voice -> intent -> tool -> result -> speech)

### Mathematical Spec

```
Voice Function Calling pipeline:
  audio -> transcribe -> intent_classify -> tool_dispatch -> execute -> speak_result

Tool definitions T = {system_health, plan_status, plan_add, email_send, containers_list,
                      emergency_stop, web_search, task_update}

P(correct_tool | voice_command) = P(transcribe_correct) * P(intent_correct | transcript)
  = 0.95 * 0.98 = 0.931

Latency budget:
  Transcription:     ~1000ms (Gemini REST) or ~250ms (Gemini Live)
  Intent + dispatch:  ~50ms
  Tool execution:     ~500ms (avg, varies by tool)
  Result to speech:   ~500ms (Gemini Live TTS)
  Total:             ~2300ms (REST) or ~1300ms (Live)
```

### Allium Spec

```allium
-- allium: 3

entity VoiceFunctionCall {
  audio: Bytes
  transcript: String
  tool_name: String
  tool_args: Map[String, String]
  tool_result: String
  spoken_result: String

  transitions state {
    audio_received  -> transcribed      (gemini_transcribes)
    transcribed     -> tool_identified  (intent_classifier_matches)
    tool_identified -> tool_executed    (mcp_tool_returns)
    tool_executed   -> result_spoken    (tts_generates_audio)
    transcribed     -> text_response    (no_tool_match)
    terminal: result_spoken, text_response
  }
}

rule IdentifyTool {
  when: transcribed
  requires: transcript matches tool_pattern
  ensures: tool_name in SUPPORTED_TOOLS
           AND tool_args extracted from transcript
  @guidance Use Gemini's function calling with tool definitions
}

rule ExecuteTool {
  when: tool_identified AND tool_name in SAFE_TOOLS
  ensures: tool_result = mcp_dispatch(tool_name, tool_args)
  @guidance Safe tools execute immediately; dangerous tools require confirmation
}

rule RequireConfirmation {
  when: tool_identified AND tool_name in DANGEROUS_TOOLS
  ensures: spoken_result = "Are you sure you want to {tool_name}?"
           AND await_confirmation = true
  @guidance emergency_stop, plan_delete require voice confirmation
}

invariant SafeExecution {
  for fc in VoiceFunctionCalls:
    fc.tool_name in DANGEROUS_TOOLS implies fc.confirmed == true
}

config {
  supported_tools: List[String] = ["system_health", "plan_status", "plan_add",
    "email_send", "containers_list", "web_search", "task_update"]
  dangerous_tools: List[String] = ["emergency_stop"]
  max_tool_timeout_ms: Integer = 10000
}
```

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| Wrong tool identified from voice | 6 | 3 | 5 | 90 | Confidence threshold; confirm before destructive actions |
| Tool execution timeout | 4 | 3 | 3 | 36 | 10s timeout; speak "Taking longer than expected" |
| Dangerous tool executed without confirmation | 9 | 1 | 2 | 18 | HITL confirmation for DANGEROUS_TOOLS list |
| Tool result too long to speak | 3 | 4 | 3 | 36 | Summarize result to 2 sentences before TTS |
| Gemini Live function calling not supported | 5 | 5 | 2 | 50 | Fallback: transcribe -> text classify -> tool -> text response |

### STAMP

- **SC-OPENCLAW-001**: Tools (Motor) via MCP
- **SC-HITL-001**: Human-in-the-loop for destructive actions
- **SC-MCP-001**: MCP server tool dispatch

### TLA+ Property

```tla+
VoiceFCSafety ==
  \A fc \in FunctionCalls:
    fc.tool_name \in DANGEROUS_TOOLS => fc.confirmed = TRUE

VoiceFCLiveness ==
  \A fc \in FunctionCalls:
    [](fc.state = "audio_received" ~>
       fc.state \in {"result_spoken", "text_response"})
```

### Quint

```quint
module VoiceFunctionCalling {
  const DANGEROUS: Set[str] = Set("emergency_stop")

  var tool: str
  var confirmed: bool
  var executed: bool

  action identify_tool(t: str): bool = {
    tool' = t, confirmed' = false, executed' = false
  }

  action confirm: bool = {
    confirmed' = true, tool' = tool, executed' = executed
  }

  action execute: bool = {
    if (DANGEROUS.contains(tool) and not confirmed) {
      false  // blocked
    } else {
      executed' = true, tool' = tool, confirmed' = confirmed
    }
  }

  val safety = DANGEROUS.contains(tool) and executed implies confirmed
}
```

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| VFC-001 | "Check system health" voice command | system_health tool called, result spoken | 15s |
| VFC-002 | "Add task priority zero fix database" | plan_add tool called with P0 | 15s |
| VFC-003 | "Stop all containers" voice command | Confirmation requested before execution | 10s |
| VFC-004 | "What is the weather" (no matching tool) | Text response via LLM, no tool called | 10s |
| VFC-005 | Tool returns 500 error | Graceful error message spoken | 15s |

---

## 9. DuckDB Analytics

**Priority**: P2 | **Fractal Layer**: L3 (Transaction)
**Wolfram Classification**: Algebraic Query System

### Mathematical Spec

```
DuckDB analytics over TransactionSummary data:

ATTACH 'data/smriti/Smriti.db' AS smriti (TYPE SQLITE, READ_ONLY);

Queries:
  P50_latency = PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY latency_ms)
  P95_latency = PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY latency_ms)
  P99_latency = PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY latency_ms)

  tier_distribution = GROUP BY tier_used, COUNT(*) / total * 100 AS pct

  daily_volume = GROUP BY DATE_TRUNC('day', timestamp), COUNT(*) AS count

  error_rate = COUNT(status = 'error') / COUNT(*) * 100

  cost_estimate = SUM(input_tokens * price_per_input + output_tokens * price_per_output)

Expected query latency: < 100ms for 100K rows (DuckDB columnar scan)
```

### Allium Spec

```allium
-- allium: 3

entity AnalyticsQuery {
  name: String
  sql: String
  result: Table
  latency_ms: Integer
  cache_key: String

  transitions state {
    pending   -> executing (query_submitted)
    executing -> cached    (result_ready AND cache_enabled)
    executing -> delivered (result_ready AND NOT cache_enabled)
    executing -> error     (query_fails)
    terminal: cached, delivered, error
  }
}

entity AnalyticsDashboard {
  p50_latency_ms: Float
  p95_latency_ms: Float
  p99_latency_ms: Float
  total_messages: Integer
  error_rate_pct: Float
  tier_distribution: Map[String, Float]
  daily_volume: List[{date: String, count: Integer}]
  cost_usd: Float
}

rule ComputePercentiles {
  when: dashboard refresh requested
  ensures: dashboard.p50_latency_ms = percentile_cont(0.50, latencies)
           AND dashboard.p95_latency_ms = percentile_cont(0.95, latencies)
           AND dashboard.p99_latency_ms = percentile_cont(0.99, latencies)
}

rule QueryTimeout {
  when: query.latency_ms > 5000
  ensures: query.state = error AND query.result = "Query timeout"
}

invariant QueryBounded {
  for q in AnalyticsQueries: q.latency_ms < 5000
}

config {
  duckdb_path: String = ":memory:"  -- in-memory with ATTACH
  smriti_path: String = "data/smriti/Smriti.db"
  cache_ttl_secs: Integer = 300
  max_query_rows: Integer = 100000
}
```

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| Smriti.db locked during ATTACH | 5 | 2 | 3 | 30 | READ_ONLY ATTACH; WAL mode on Smriti |
| DuckDB query exceeds memory | 6 | 2 | 3 | 36 | SET memory_limit = '512MB'; LIMIT queries |
| SQLite schema mismatch after migration | 5 | 2 | 4 | 40 | Schema version check before ATTACH |
| PERCENTILE_CONT on empty table | 3 | 2 | 2 | 12 | COALESCE with default value |
| Analytics stale (cache too long) | 3 | 4 | 4 | 48 | 5-minute cache TTL; manual refresh endpoint |

### STAMP

- **SC-CONC-001**: DuckDB pool management
- **SC-XHOLON-021**: DuckDB query latency < 10ms
- **SC-ANALYTICS-001**: Analytics engine constraints

### TLA+ Property

```tla+
DuckDBSafety == \A q \in Queries: q.latency_ms < 5000
DuckDBReadOnly == \A q \in Queries: q.type = "SELECT"  -- no mutations via analytics
DuckDBLiveness == \A q \in Queries: <>(q.state \in {"cached", "delivered", "error"})
```

### Quint

```quint
module DuckDBAnalytics {
  var p50: int
  var p95: int
  var p99: int
  var total: int

  action compute_percentiles(latencies: List[int]): bool = {
    val sorted = latencies.sort()
    val n = sorted.size()
    p50' = sorted[n / 2],
    p95' = sorted[n * 95 / 100],
    p99' = sorted[n * 99 / 100],
    total' = n
  }

  val percentile_order = p50 <= p95 and p95 <= p99
}
```

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| DDB-001 | ATTACH Smriti.db, query latency percentiles | P50 < P95 < P99, valid values | 5s |
| DDB-002 | Query tier_distribution | Sum of percentages = 100% | 5s |
| DDB-003 | Query daily_volume for last 7 days | 7 rows, counts >= 0 | 5s |
| DDB-004 | Query error_rate | 0% <= rate <= 100% | 5s |
| DDB-005 | Query on empty table | Returns defaults, no crash | 5s |
| DDB-006 | 100K row scan performance | < 100ms | 1s |

---

## 10. Emotion-Aware Responses

**Priority**: P3 | **Fractal Layer**: L5 (Cognitive)

### Mathematical Spec

```
Emotion state extraction from Gemini Live audio analysis:
  E = {calm, stressed, urgent, happy, frustrated, neutral}
  P(e | audio_features) modeled by Gemini's multimodal understanding

Tone adaptation mapping:
  calm       -> formal, detailed response
  stressed   -> concise, reassuring response
  urgent     -> immediate, action-oriented response
  happy      -> casual, conversational response
  frustrated -> empathetic, helpful response
  neutral    -> default response style
```

### Allium Spec

```allium
-- allium: 3

entity EmotionState {
  detected: calm | stressed | urgent | happy | frustrated | neutral
  confidence: Float
  adaptation: String
}

rule AdaptTone {
  when: emotion.detected == urgent AND emotion.confidence > 0.7
  ensures: response.style = "immediate, action-oriented"
           AND response.max_length = 50  -- words
}
```

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| Wrong emotion detected | 3 | 4 | 7 | 84 | Confidence threshold; default to neutral |
| Inappropriate tone adaptation | 4 | 3 | 6 | 72 | Conservative mapping; never mock emotion |

### STAMP: SC-HMI-010, SC-NEURO-001

### TLA+ Property

```tla+
EmotionSafety == \A r \in Responses: r.tone \in VALID_TONES
EmotionDefault == \A e \in Emotions: e.confidence < 0.5 => response_tone = "neutral"
```

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| EM-001 | Calm voice input | Detailed, formal response | 10s |
| EM-002 | Urgent voice input | Short, action-oriented response | 10s |
| EM-003 | Low confidence detection | Neutral tone applied | 10s |

---

## 11. Noisy Environment Test Suite

**Priority**: P2 | **Fractal Layer**: L1 (Atomic)

### Mathematical Spec

```
SNR injection: noisy_audio = clean_audio + noise * 10^(-SNR_dB/20)

Test matrix:
  SNR levels: {5dB, 10dB, 15dB, 20dB, 25dB, 30dB}
  Noise types: {white, pink, street, wind, crowd, machinery}
  |matrix| = 6 * 6 = 36 test cases

Accuracy threshold by SNR:
  SNR >= 25dB: WER < 5%
  15dB <= SNR < 25dB: WER < 15%
  5dB <= SNR < 15dB: WER < 35%
```

### Allium Spec

```allium
-- allium: 3

entity NoisyEnvironmentTest {
  clean_audio: Bytes
  noise_type: white | pink | street | wind | crowd | machinery
  snr_db: Float
  mixed_audio: Bytes
  wer: Float
  passed: Boolean
}

rule MixNoise {
  when: test started
  ensures: mixed_audio = clean_audio + noise * gain(snr_db)
}

invariant AccuracyBySnr {
  for t in NoisyEnvironmentTests:
    (t.snr_db >= 25 implies t.wer < 0.05) AND
    (t.snr_db >= 15 AND t.snr_db < 25 implies t.wer < 0.15)
}
```

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| Noise drowns out speech entirely | 6 | 3 | 5 | 90 | Graceful "I couldn't understand" message |
| Noise misidentified as speech | 4 | 3 | 6 | 72 | VAD (Voice Activity Detection) filter |

### STAMP: SC-TEST-050, SC-SIM-001

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| NE-001 | Clean + white noise at 25dB | WER < 5% | 10s |
| NE-002 | Clean + street noise at 10dB | WER < 35% | 10s |
| NE-003 | 36-case matrix | All pass threshold per SNR level | 300s |

---

## 12. PII Scrubber

**Priority**: P1 | **Fractal Layer**: L0 (Constitutional), L3 (Transaction)

### Mathematical Spec

```
PII regex patterns with false positive rate F:
  Email:    /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/  F < 0.1%
  Phone:    /(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/  F < 1%
  SSN:      /\b\d{3}-\d{2}-\d{4}\b/  F < 0.01%
  Card:     /\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b/  F < 0.1%
  Aadhaar:  /\b\d{4}[-\s]?\d{4}[-\s]?\d{4}\b/  F < 0.5%

Masking: replace matched PII with [REDACTED:{type}]
  e.g., "email me at foo@bar.com" -> "email me at [REDACTED:EMAIL]"

Overall detection rate P(detect | PII_present) > 99% for email, phone, SSN, card
```

### Allium Spec

```allium
-- allium: 3

entity PIIScrubber {
  input_text: String
  scrubbed_text: String
  detections: List[{type: String, start: Integer, end: Integer}]
}

rule ScrubBeforeLog {
  when: text about to be logged to Smriti.db OR Zenoh topic
  ensures: all PII patterns replaced with [REDACTED:{type}]
  @critical PII MUST never appear in logs
}

invariant NoPIIInLogs {
  for log in LogEntries: NOT matches(log.content, PII_PATTERN)
}
```

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| PII reaches Smriti.db unmasked | 8 | 2 | 3 | 48 | Scrub at ingress before any storage |
| False positive masks valid data | 3 | 3 | 4 | 36 | Whitelist known safe patterns |
| New PII pattern not recognized | 7 | 3 | 5 | 105 | Quarterly audit of PII regex patterns |
| Unicode PII bypasses ASCII regex | 6 | 2 | 5 | 60 | Use Unicode-aware regex crate |

### STAMP: SC-SEC-001, SC-LOG-003, SC-SAFETY-014

### TLA+ Property

```tla+
PIISafety == \A log \in Logs: \A p \in PII_PATTERNS: ~contains(log.content, p)
PIICompleteness == \A t \in Texts: scrub(t) does not contain any PII
```

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| PII-001 | Text with email address | Email replaced with [REDACTED:EMAIL] | 1s |
| PII-002 | Text with phone number | Phone replaced with [REDACTED:PHONE] | 1s |
| PII-003 | Text with no PII | Output unchanged | 1s |
| PII-004 | Text with multiple PII types | All detected and masked | 1s |
| PII-005 | Verify logs contain no raw PII | Grep Smriti.db for patterns returns 0 | 5s |

---

## 13. Prompt Injection Protection

**Priority**: P1 | **Fractal Layer**: L0 (Constitutional)

### Mathematical Spec

```
Injection detection via multi-layer defense:

Layer 1: Input sanitization
  strip(input, control_chars)
  escape(input, special_tokens)

Layer 2: Pattern classifier
  P(injection | input) = classifier(input)
  If P > threshold (0.8): BLOCK

Layer 3: Output validation
  response MUST NOT contain system prompt fragments
  response MUST NOT execute unregistered tools

Known injection patterns:
  "Ignore previous instructions"
  "You are now..."
  "System: override"
  "```python\nimport os; os.system(...)"

False positive rate: F < 0.5% (1 in 200 legitimate messages blocked)
```

### Allium Spec

```allium
-- allium: 3

entity PromptInjectionGuard {
  input_text: String
  injection_score: Float
  blocked: Boolean
  reason: String
}

rule BlockInjection {
  when: injection_score > 0.8
  ensures: blocked = true AND reason = "Potential prompt injection detected"
  @critical Log all blocked attempts to Immutable Register
}

invariant SystemPromptProtected {
  for r in Responses: NOT contains(r.content, system_instruction_fragment)
}
```

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| Injection bypasses classifier | 8 | 2 | 5 | 80 | Multi-layer defense; output validation too |
| False positive blocks legitimate query | 4 | 3 | 3 | 36 | Allowlist for known-safe patterns |
| System prompt leaked in response | 7 | 1 | 3 | 21 | Output filter strips system prompt fragments |

### STAMP: SC-SEC-001, SC-PRIME-001, SC-NEURO-001

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| PI-001 | "Ignore all previous instructions" | Blocked, score > 0.8 | 1s |
| PI-002 | "Tell me a joke" | Allowed, score < 0.3 | 1s |
| PI-003 | Encoded injection (base64) | Detected and blocked | 1s |
| PI-004 | Verify system prompt never in output | 100 responses checked, 0 leaks | 30s |

---

## 14. Zenoh Telemetry for All Commands

**Priority**: P1 | **Fractal Layer**: L6 (Ecosystem)

### Mathematical Spec

```
Topic map: indrajaal/chat/{gateway}/{chat_id}/{operation}
  Where gateway in {telegram, gchat, whatsapp}
        operation in {ingress, classify, infer, deliver, error}

Message format (JSON):
{
  "timestamp_ms": u64,
  "chat_id": string,
  "gateway": string,
  "operation": string,
  "tier": string | null,
  "latency_ms": u64,
  "tokens_in": u32,
  "tokens_out": u32,
  "trace_id": string
}

Rate budget: max 10 messages/second per chat_id (5 operations per message)
Total Zenoh bandwidth: ~50 KB/s at peak load (100 concurrent users)
```

### Allium Spec

```allium
-- allium: 3

entity ZenohTelemetryEvent {
  topic: String
  payload: Map[String, Any]
  published: Boolean
}

rule PublishOnIngress {
  when: message received from any gateway
  ensures: zenoh.publish("indrajaal/chat/{gw}/{chat_id}/ingress", payload)
}

rule PublishOnDeliver {
  when: response sent to any gateway
  ensures: zenoh.publish("indrajaal/chat/{gw}/{chat_id}/deliver", payload)
}

invariant AllOperationsTracked {
  for m in Messages: count(zenoh_events(m.trace_id)) >= 2  -- at least ingress + deliver
}
```

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| Zenoh unavailable | 5 | 2 | 1 | 10 | Fire-and-forget; never block pipeline for telemetry |
| Topic namespace collision | 3 | 1 | 3 | 9 | Strict namespace convention per ZMOF spec |
| Telemetry storms (100+ msg/s) | 4 | 2 | 3 | 24 | Rate limit to 10 msg/s per chat_id |

### STAMP: SC-ZENOH-001, SC-ZENOH-006, SC-GLM-ZEN-001

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| ZT-001 | Send message, verify Zenoh ingress event | Event published to correct topic | 5s |
| ZT-002 | Verify all 5 operations have events | ingress, classify, infer, deliver, complete | 10s |
| ZT-003 | Zenoh down, send message | Message still processed; telemetry silently dropped | 10s |
| ZT-004 | 100 messages in 10s | <= 10 Zenoh msg/s per chat_id | 15s |

---

## 15. Conversation Summarization

**Priority**: P2 | **Fractal Layer**: L5 (Cognitive)

### Mathematical Spec

```
Sliding window summarization:
  Window size:     W = 20 messages
  Summary trigger: every W messages OR context exceeds 3000 tokens
  Summary model:   Gemini 2.5 Flash (cheapest, fastest)

  summary = LLM("Summarize this conversation in 3 sentences: " + window)
  token_count(summary) < 200 tokens

  Context injection:
    system_instruction += "\n\nConversation summary: " + summary

  Memory formula:
    effective_context = summary + last_10_messages
    token_budget = 500 (summary) + 2000 (recent) = 2500 tokens
```

### Allium Spec

```allium
-- allium: 3

entity ConversationSummary {
  chat_id: String
  message_count: Integer
  summary_text: String
  summary_tokens: Integer
  last_summarized_at: Integer
}

rule TriggerSummarization {
  when: message_count >= 20 OR context_tokens > 3000
  ensures: summary_text updated with last 20 messages
           AND summary_tokens < 200
}

invariant SummaryBounded {
  for s in ConversationSummaries: s.summary_tokens <= 200
}
```

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| Summary loses critical context | 5 | 3 | 6 | 90 | Keep last 10 raw messages alongside summary |
| Summarization adds latency | 3 | 4 | 2 | 24 | Async; summarize in background after delivery |
| Summary hallucination | 4 | 2 | 5 | 40 | Cross-reference summary with raw messages |

### STAMP: SC-CTX-001, SC-SMRITI-131

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| CS-001 | Send 25 messages, verify summary generated | Summary < 200 tokens, coherent | 15s |
| CS-002 | Summary injected into next LLM call | Response references earlier context | 10s |
| CS-003 | New conversation (0 messages) | No summary, direct inference | 5s |

---

## 16. WebRTC Streaming (P3)

**Priority**: P3 | **Fractal Layer**: L1 (Atomic), L6 (Ecosystem)

### Mathematical Spec

```
WebRTC pipeline:
  ICE:   STUN/TURN for NAT traversal
  DTLS:  TLS 1.3 for secure channel
  SRTP:  Encrypted audio/video transport
  Codec: Opus for audio, VP8/H264 for video

Latency target: < 200ms end-to-end (glass-to-glass)
  ICE establishment:   ~1000ms (first time)
  DTLS handshake:      ~100ms
  Audio frame:         20ms (Opus)
  Network:             ~50ms (LAN)
  Total first packet:  ~1170ms
  Steady-state:        ~70ms
```

### Allium Spec

```allium
-- allium: 3

entity WebRTCSession {
  peer_id: String
  state: new | connecting | connected | disconnected
  ice_state: new | checking | connected | failed
  dtls_state: new | connecting | connected
  audio_codec: opus
  latency_ms: Integer
}

rule EstablishConnection {
  when: session requested
  ensures: ice_state = connected AND dtls_state = connected
           AND latency_ms < 200
}

invariant SecureTransport {
  for s in WebRTCSessions: s.dtls_state == connected implies encrypted == true
}
```

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| ICE connection fails (symmetric NAT) | 5 | 4 | 3 | 60 | TURN relay fallback |
| Audio quality degradation | 4 | 3 | 5 | 60 | Opus FEC + adaptive bitrate |

### STAMP: SC-OPENCLAW-001, SC-STREAM-001

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| WR-001 | Establish WebRTC connection (LAN) | Connected in < 3s | 5s |
| WR-002 | Streaming audio for 60s | No drops, latency < 200ms | 65s |

---

## 17. Video Processing (P3)

**Priority**: P3 | **Fractal Layer**: L5 (Cognitive)

### Mathematical Spec

```
Frame extraction: 1 frame per second at 720p (1280x720)
Token cost per frame: ~258 tokens (Gemini vision)
Max video duration: 30s -> 30 frames -> 7,740 tokens

Pipeline: video -> ffmpeg extract frames -> resize 720p -> Gemini multimodal -> text response
```

### Allium Spec

```allium
-- allium: 3

entity VideoProcessing {
  video: Bytes
  frames: List[Image]
  description: String
  duration_secs: Float
}

rule ExtractFrames {
  when: video received
  ensures: frames = ffmpeg_extract(video, fps=1, resolution="720p")
           AND frames.length <= 30
}

invariant FrameBudget {
  for v in VideoProcessings: v.frames.length * 258 <= 10000  -- token budget
}
```

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| Video too large (>100MB) | 4 | 3 | 2 | 24 | Reject with size limit message |
| ffmpeg not available | 7 | 1 | 1 | 7 | Dependency check at startup |
| Frame extraction OOM | 5 | 2 | 3 | 30 | Max 30 frames, 720p resolution cap |

### STAMP: SC-VIDEO-001, SC-VID-001

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| VP-001 | 10s video, extract frames | 10 frames at 720p | 15s |
| VP-002 | Send frames to Gemini | Text description of video content | 20s |
| VP-003 | 60s video (over limit) | Truncated to 30 frames | 20s |

---

## 18. WhatsApp Integration (P3)

**Priority**: P3 | **Fractal Layer**: L6 (Ecosystem)

### Mathematical Spec

```
WhatsApp Business API pipeline:
  Webhook: POST /webhook -> verify signature (HMAC-SHA256) -> process
  Media:   GET media_url with Bearer token -> download -> process
  Send:    POST /v17.0/{phone_id}/messages -> text/image/audio

Rate limits:
  Business tier:  80 msg/s
  Standard tier:  250 msg/s
  Template msgs:  unlimited

Delivery:
  P(delivered | sent) > 0.998
  E[latency] = 500ms (within country)
```

### Allium Spec

```allium
-- allium: 3

entity WhatsAppMessage {
  from: String  -- phone number
  type: text | image | audio | video
  content: String | Bytes
  timestamp: Integer
}

rule VerifyWebhook {
  when: POST /webhook received
  requires: HMAC-SHA256(payload, app_secret) == X-Hub-Signature-256 header
  ensures: message processed
  @critical Reject unsigned webhooks
}

invariant SignatureVerified {
  for m in WhatsAppMessages: m.signature_valid == true
}
```

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| Webhook signature verification bypass | 9 | 1 | 1 | 9 | Strict HMAC-SHA256 validation |
| Media download fails (expired URL) | 4 | 3 | 3 | 36 | Retry once; URLs valid for ~5 min |
| Rate limit exceeded | 3 | 2 | 2 | 12 | Token bucket rate limiter |

### STAMP: SC-SEC-001, SC-CHANNEL-001, SC-ECO-001

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| WA-001 | Receive text message via webhook | Message processed, response sent | 10s |
| WA-002 | Invalid webhook signature | Rejected with 403 | 1s |
| WA-003 | Receive voice message | Audio downloaded, transcribed, response sent | 20s |

---

## 19. Gemini Live WS Fix

**Priority**: P0 | **Fractal Layer**: L5 (Cognitive)
**Current RPN**: V1 = 40 (Live WS setup rejected, falls to REST +3s latency)

### Mathematical Spec

```
WebSocket setup debugging matrix:

Model names to test:
  1. "gemini-2.0-flash-live-001"           -- current (failing)
  2. "models/gemini-2.0-flash-live-001"    -- with prefix
  3. "gemini-2.5-flash-preview-native-audio-dialog" -- 2.5 Live
  4. "gemini-2.5-flash-exp-native-audio-thinking"   -- experimental

Endpoints to test:
  A. wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=API_KEY
  B. wss://generativelanguage.googleapis.com/v1beta/models/{model}:streamGenerateContent?key=API_KEY&alt=ws

Setup message format:
{
  "setup": {
    "model": "{model_name}",
    "generationConfig": {
      "responseModalities": ["AUDIO", "TEXT"],
      "speechConfig": {
        "voiceConfig": { "prebuiltVoiceConfig": { "voiceName": "Aoede" } }
      }
    }
  }
}

Expected: 200 + setup_complete response
Actual: "Internal error" on all attempts (V1 failure mode)

Debug approach:
  1. Enumerate models via Gemini API: GET /v1beta/models?key=API_KEY
  2. Filter for models with "generateContent" method
  3. Test each model/endpoint combination
  4. Log raw binary WebSocket frames for analysis
```

### Allium Spec

```allium
-- allium: 3

entity GeminiLiveSession {
  model: String
  endpoint: String
  ws_state: connecting | setup_sent | setup_complete | streaming | closed | error
  error_message: String

  transitions ws_state {
    connecting    -> setup_sent     (ws_open)
    setup_sent    -> setup_complete (setup_response_ok)
    setup_sent    -> error          (setup_response_error)
    setup_complete -> streaming     (first_audio_chunk)
    streaming     -> closed         (session_end)
    streaming     -> error          (connection_lost)
    terminal: closed, error
  }
}

rule DebugSetup {
  when: ws_state == error
  ensures: error_message logged with full binary frame dump
           AND next_model_tried = models[current_idx + 1]
  @guidance Log raw bytes for debugging "Internal error"
}

rule FallbackToREST {
  when: all model/endpoint combinations fail
  ensures: use REST API for audio processing
           AND latency_penalty = 3000ms
}

invariant NeverBlackhole {
  for s in GeminiLiveSessions:
    s.ws_state == error implies rest_fallback_active == true
}

config {
  model_candidates: List[String] = [
    "gemini-2.0-flash-live-001",
    "models/gemini-2.0-flash-live-001",
    "gemini-2.5-flash-preview-native-audio-dialog",
    "gemini-2.5-flash-exp-native-audio-thinking"
  ]
  endpoint_candidates: List[String] = ["v1beta_bidi", "v1beta_stream_alt"]
  max_setup_timeout_ms: Integer = 10000
}
```

### FMEA

| Failure Mode | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| All model names rejected (Internal error) | 4 | 10 | 1 | 40 | REST fallback; enumerate via API |
| API key format wrong for WS endpoint | 3 | 3 | 4 | 36 | Try both key= and Bearer auth |
| Model deprecated between releases | 5 | 3 | 3 | 45 | Dynamic model enumeration at startup |
| WebSocket frame encoding mismatch | 6 | 2 | 5 | 60 | Log raw binary frames for debugging |
| Region-specific model availability | 4 | 3 | 6 | 72 | Test from multiple regions; document available models |

### STAMP

- **SC-GEM-001**: Gemini integration constraints
- **SC-MODEL-001**: Model registry management
- **SC-API-001**: API safety and retry

### TLA+ Property

```tla+
\* Safety: failed WS always falls back to REST
GeminiLiveSafety ==
  \A s \in Sessions:
    s.ws_state = "error" => rest_fallback[s.chat_id] = TRUE

\* Liveness: model enumeration eventually finds working model OR confirms all fail
ModelEnumerationProgress ==
  \A s \in Sessions:
    <>(s.ws_state = "setup_complete" \/ s.models_exhausted = TRUE)

\* Safety: never send audio to a non-setup session
AudioOnlyAfterSetup ==
  \A s \in Sessions:
    audio_sent[s] => s.ws_state = "streaming"
```

### Quint

```quint
module GeminiLiveFix {
  type WSState = str  // "connecting" | "setup_sent" | "setup_complete" | "error"

  var ws_state: WSState
  var model_idx: int
  var rest_fallback: bool

  const MODELS: List[str] = [
    "gemini-2.0-flash-live-001",
    "gemini-2.5-flash-preview-native-audio-dialog"
  ]

  action try_model: bool = {
    if (model_idx < MODELS.size()) {
      nondet success = oneOf(Set(true, false))
      if (success) {
        ws_state' = "setup_complete",
        model_idx' = model_idx,
        rest_fallback' = false
      } else {
        ws_state' = "error",
        model_idx' = model_idx + 1,
        rest_fallback' = rest_fallback
      }
    } else {
      ws_state' = "error",
      model_idx' = model_idx,
      rest_fallback' = true
    }
  }

  val never_blackhole = ws_state == "error" implies (model_idx < MODELS.size() or rest_fallback)
}
```

### Runtime Behavior Checks

| Test ID | Description | Expected | Timeout |
|---|---|---|---|
| GL-001 | Enumerate models via GET /v1beta/models | List of available models | 5s |
| GL-002 | Try WS setup with each model candidate | At least one succeeds OR all logged | 30s |
| GL-003 | Log raw binary setup response | Hex dump captured for debugging | 10s |
| GL-004 | WS setup fails, verify REST fallback | REST transcription works | 15s |
| GL-005 | Successful WS setup, send audio chunk | Audio response received | 15s |
| GL-006 | Test with alt endpoint format | Compare responses | 15s |

---

## Summary Tables

### FMEA Summary: All Features Ranked by Maximum RPN

| Rank | Feature | Max RPN | Critical Failure Mode |
|---|---|---|---|
| 1 | TLA+ Formal Spec | 140 | Spec diverges from Rust implementation |
| 2 | RAG Pipeline | 126 | Context injection causes hallucination |
| 3 | Failure Injection Tests | 120 | Mock doesn't match real failure behavior |
| 4 | RAG Pipeline | 120 | FTS5 returns irrelevant context |
| 5 | Multilingual Voice Detection | 112 | Code-switching (mixed language) |
| 6 | PII Scrubber | 105 | New PII pattern not recognized |
| 7 | Noisy Environment Test Suite | 90 | Noise drowns out speech entirely |
| 8 | Multilingual Voice Detection | 90 | Wrong language / accent misclassified |
| 9 | Voice Function Calling | 90 | Wrong tool identified from voice |
| 10 | Conversation Summarization | 90 | Summary loses critical context |
| 11 | Emotion-Aware Responses | 84 | Wrong emotion detected |
| 12 | Prompt Injection Protection | 80 | Injection bypasses classifier |
| 13 | Rate Limiting per User | 72 | Race condition on concurrent requests |
| 14 | Gemini Live WS Fix | 72 | Region-specific model availability |
| 15 | Noisy Environment Test Suite | 72 | Noise misidentified as speech |
| 16 | Emotion-Aware Responses | 72 | Inappropriate tone adaptation |
| 17 | Failure Injection Tests | 60 | Test flaky due to API rate limits |
| 18 | Automated Voice Test Suite | 60 | Test flaky due to API rate limits |
| 19 | WebRTC Streaming | 60 | ICE connection fails / audio quality |

### STAMP Constraint Cross-Reference

| Feature | Primary Constraints |
|---|---|
| 1. Rate Limiting | SC-API-001, SC-API-002, SC-SEC-018 |
| 2. Failure Injection | SC-CHAOS-001, SC-CHAOS-002, SC-TEST-001 |
| 3. Voice Test Suite | SC-TEST-001, SC-TEST-050, SC-SIM-001 |
| 4. Audio Response (TTS) | SC-OPENCLAW-001, SC-HMI-010 |
| 5. Multilingual Detection | SC-SEM-001, SC-HMI-001 |
| 6. TLA+ Formal Spec | SC-VER-074, SC-SAFETY-003, SC-FUNC-003 |
| 7. RAG Pipeline | SC-SMRITI-131, SC-SMRITI-133, SC-IKE-001 |
| 8. Voice Function Calling | SC-OPENCLAW-001, SC-HITL-001, SC-MCP-001 |
| 9. DuckDB Analytics | SC-CONC-001, SC-XHOLON-021, SC-ANALYTICS-001 |
| 10. Emotion-Aware | SC-HMI-010, SC-NEURO-001 |
| 11. Noisy Environment | SC-TEST-050, SC-SIM-001 |
| 12. PII Scrubber | SC-SEC-001, SC-LOG-003, SC-SAFETY-014 |
| 13. Prompt Injection | SC-SEC-001, SC-PRIME-001, SC-NEURO-001 |
| 14. Zenoh Telemetry | SC-ZENOH-001, SC-ZENOH-006, SC-GLM-ZEN-001 |
| 15. Conversation Summary | SC-CTX-001, SC-SMRITI-131 |
| 16. WebRTC Streaming | SC-OPENCLAW-001, SC-STREAM-001 |
| 17. Video Processing | SC-VIDEO-001, SC-VID-001 |
| 18. WhatsApp Integration | SC-SEC-001, SC-CHANNEL-001, SC-ECO-001 |
| 19. Gemini Live WS Fix | SC-GEM-001, SC-MODEL-001, SC-API-001 |

### TLA+ Property Summary

| Feature | Safety Properties | Liveness Properties |
|---|---|---|
| 1. Rate Limiting | TokenBound, NoNegative | RefillEventual, Fairness |
| 2. Failure Injection | NoBlackhole, ProductionSafety | CascadeProgress |
| 3. Voice Test Suite | CleanAccuracy | TestCompletion |
| 4. Audio Response | PCMFormat, ResponseDelivered | TTSTimeout |
| 5. Multilingual | LanguageValid, LowConfFallback | DetectionComplete |
| 6. TLA+ Spec | TypeInvariant, NoBlackhole, RuleFallback | CBRecovery, GatewayDelivery |
| 7. RAG Pipeline | TokenBudget | RAGComplete |
| 8. Voice Function | SafeExecution (HITL) | VFCComplete |
| 9. DuckDB Analytics | QueryBounded, ReadOnly | QueryComplete |
| 10. Emotion-Aware | ValidTone, DefaultNeutral | -- |
| 11. Noisy Environment | AccuracyBySnr | -- |
| 12. PII Scrubber | NoPIIInLogs | -- |
| 13. Prompt Injection | SystemPromptProtected | -- |
| 14. Zenoh Telemetry | AllOpsTracked | -- |
| 15. Conversation Summary | SummaryBounded | -- |
| 16. WebRTC | SecureTransport | ConnectionEstablish |
| 17. Video | FrameBudget | -- |
| 18. WhatsApp | SignatureVerified | -- |
| 19. Gemini Live WS | AudioOnlyAfterSetup | ModelEnumeration |

### Allium Entity/Rule Count per Feature

| Feature | Entities | Rules | Invariants | Contracts | Config |
|---|---|---|---|---|---|
| 1. Rate Limiting | 1 | 3 | 2 | 0 | 1 |
| 2. Failure Injection | 2 | 4 | 1 | 1 | 0 |
| 3. Voice Test Suite | 2 | 3 | 1 | 0 | 1 |
| 4. Audio Response | 1 | 4 | 1 | 1 | 0 |
| 5. Multilingual | 2 | 3 | 1 | 0 | 1 |
| 6. TLA+ Spec | 2 | 3 | 3 | 0 | 0 |
| 7. RAG Pipeline | 2 | 3 | 1 | 0 | 1 |
| 8. Voice Function | 1 | 3 | 1 | 0 | 1 |
| 9. DuckDB Analytics | 2 | 2 | 1 | 0 | 1 |
| 10. Emotion-Aware | 1 | 1 | 0 | 0 | 0 |
| 11. Noisy Environment | 1 | 1 | 1 | 0 | 0 |
| 12. PII Scrubber | 1 | 1 | 1 | 0 | 0 |
| 13. Prompt Injection | 1 | 1 | 1 | 0 | 0 |
| 14. Zenoh Telemetry | 1 | 2 | 1 | 0 | 0 |
| 15. Conversation Summary | 1 | 1 | 1 | 0 | 0 |
| 16. WebRTC | 1 | 1 | 1 | 0 | 0 |
| 17. Video Processing | 1 | 1 | 1 | 0 | 0 |
| 18. WhatsApp | 1 | 1 | 1 | 0 | 0 |
| 19. Gemini Live WS | 1 | 2 | 1 | 0 | 1 |
| **TOTAL** | **26** | **40** | **21** | **2** | **7** |

### Test Count per Feature

| Feature | Unit Tests | Integration Tests | E2E Tests | Total |
|---|---|---|---|---|
| 1. Rate Limiting | 8 | 2 | 1 | 11 |
| 2. Failure Injection | 9 | 3 | 1 | 13 |
| 3. Voice Test Suite | 8 | 4 | 2 | 14 |
| 4. Audio Response | 6 | 2 | 1 | 9 |
| 5. Multilingual | 6 | 2 | 1 | 9 |
| 6. TLA+ Spec | 6 | 0 | 0 | 6 |
| 7. RAG Pipeline | 6 | 3 | 1 | 10 |
| 8. Voice Function | 5 | 2 | 1 | 8 |
| 9. DuckDB Analytics | 6 | 2 | 0 | 8 |
| 10. Emotion-Aware | 3 | 1 | 0 | 4 |
| 11. Noisy Environment | 3 | 1 | 1 | 5 |
| 12. PII Scrubber | 5 | 1 | 0 | 6 |
| 13. Prompt Injection | 4 | 1 | 0 | 5 |
| 14. Zenoh Telemetry | 4 | 2 | 0 | 6 |
| 15. Conversation Summary | 3 | 1 | 0 | 4 |
| 16. WebRTC | 2 | 1 | 1 | 4 |
| 17. Video Processing | 3 | 1 | 0 | 4 |
| 18. WhatsApp | 3 | 1 | 1 | 5 |
| 19. Gemini Live WS | 6 | 2 | 1 | 9 |
| **TOTAL** | **96** | **32** | **12** | **140** |

### Fractal Layer Mapping

| Feature | L0 | L1 | L2 | L3 | L4 | L5 | L6 | L7 |
|---|---|---|---|---|---|---|---|---|
| 1. Rate Limiting | | | | X | | X | | |
| 2. Failure Injection | | | | | X | X | | |
| 3. Voice Test Suite | | X | | | | X | | |
| 4. Audio Response | | X | | | | | X | |
| 5. Multilingual | | | | | | X | | |
| 6. TLA+ Spec | X | | | | | | | X |
| 7. RAG Pipeline | | | | X | | X | | |
| 8. Voice Function | | | | | X | X | | |
| 9. DuckDB Analytics | | | | X | | | | |
| 10. Emotion-Aware | | | | | | X | | |
| 11. Noisy Environment | | X | | | | | | |
| 12. PII Scrubber | X | | | X | | | | |
| 13. Prompt Injection | X | | | | | | | |
| 14. Zenoh Telemetry | | | | | | | X | |
| 15. Conversation Summary | | | | | | X | | |
| 16. WebRTC | | X | | | | | X | |
| 17. Video Processing | | | | | | X | | |
| 18. WhatsApp | | | | | | | X | |
| 19. Gemini Live WS | | | | | | X | | |
| **Total per layer** | **3** | **4** | **0** | **4** | **3** | **11** | **4** | **1** |

### Implementation Priority Matrix

| Phase | Features | Total RPN Reduction | Sprint |
|---|---|---|---|
| **Phase 1 (P0)** | 19. Gemini Live WS Fix | V1:40->0, V9:168->40, V13:90->20, V14:40->10 | Sprint 1 |
| **Phase 2 (P1)** | 1, 6, 12, 13, 14 | Rate limit + formal spec + security hardening | Sprint 2 |
| **Phase 3 (P1)** | 2, 3, 7 | Failure injection + voice tests + RAG | Sprint 3 |
| **Phase 4 (P1)** | 4, 5, 8 | Audio response + multilingual + voice tools | Sprint 4 |
| **Phase 5 (P2)** | 9, 10, 11, 15 | Analytics + emotion + noise + summarization | Sprint 5 |
| **Phase 6 (P3)** | 16, 17, 18 | WebRTC + video + WhatsApp | Sprint 6+ |

---

**Total Allium Constructs**: 26 entities, 40 rules, 21 invariants, 2 contracts, 7 configs
**Total Tests Specified**: 140 (96 unit + 32 integration + 12 E2E)
**Total FMEA Entries**: 76 failure modes analyzed
**Total STAMP Constraints Referenced**: 42 unique SC-* families
**Maximum RPN**: 140 (TLA+ spec-code drift)
**Fractal Coverage**: L5 (Cognitive) most impacted (11 features), L2 (Component) least (0 features)

---

**End of Formal Specification**
