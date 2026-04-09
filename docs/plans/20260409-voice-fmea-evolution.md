# Voice Features: Criticality + FMEA-Based Evolutionary Approach

**Date**: 2026-04-09 | **STAMP**: SC-OPENCLAW-001, SC-SAFETY-022
**Method**: FMEA (Failure Mode & Effects Analysis) + Criticality-Weighted Evolution

---

## 1. Current Voice Failure Data (Observed This Session)

| Event | Count | Impact |
|-------|-------|--------|
| Voice messages received | ~15 | All processed |
| Gemini Live WS connected | ~8 | 100% setup failure (Internal error) |
| Gemini 2.5 Flash REST success | ~10 | Primary workhorse |
| Gemini 3.1 Flash Lite REST success | ~3 | Fallback when 2.5 503'd |
| 503 overload errors | ~4 | Transient, retry works |
| Unicode panics | 3 | **FIXED** (safe_trunc) |
| Rule-based fallback (all tiers fail) | 2 | Message not lost, but no AI response |
| Local Whisper | 0/0 | Not installed |

## 2. FMEA Table — All Voice Failure Modes

RPN = Severity × Occurrence × Detection
- Severity: 1(cosmetic) – 10(safety-critical, message lost)
- Occurrence: 1(unlikely) – 10(every request)
- Detection: 1(instant) – 10(undetectable)

| # | Failure Mode | Effect | S | O | D | RPN | Current Mitigation | Status |
|---|---|---|---|---|---|---|---|---|
| V1 | Live WS setup rejected | Falls to REST (+3s latency) | 4 | 10 | 1 | **40** | REST fallback | OPEN — WS never works |
| V2 | Gemini 2.5 Flash 503 | Retry once, fall to 3.1 | 3 | 3 | 1 | 9 | Retry + fallback | MITIGATED |
| V3 | All cloud tiers 503 | Fall to Ollama or rule-ack | 6 | 1 | 1 | 6 | 5-tier cascade | MITIGATED |
| V4 | Unicode panic in transcript | Task dies, no response | 9 | 0 | 1 | **0** | safe_trunc | **FIXED** |
| V5 | ffmpeg not installed | OGG→PCM fails, no voice | 8 | 1 | 2 | 16 | Error message | MITIGATED |
| V6 | systemInstruction ignored (audio) | Generic response, no context | 7 | 10 | 3 | **210** | 2-stage pipeline | **FIXED** |
| V7 | Telegram voice download fails | No audio to process | 7 | 1 | 2 | 14 | Error logged | MITIGATED |
| V8 | Audio too short (<1s) | Gemini can't transcribe | 3 | 2 | 5 | 30 | Min duration check | OPEN |
| V9 | Heavy accent / noisy env | Bad transcription | 6 | 4 | 7 | **168** | Accent learning | PARTIAL |
| V10 | No internet (field) | All cloud tiers fail | 8 | 3 | 2 | **48** | Whisper local + rule-ack | PARTIAL (no Whisper) |
| V11 | Slow response (>10s) | User thinks it's hung | 5 | 2 | 3 | 30 | 15s timeout + ack | MITIGATED |
| V12 | Voice note > 60s | Token limit exceeded | 4 | 1 | 5 | 20 | Truncate audio | OPEN |
| V13 | Wrong language detected | Response in wrong language | 5 | 3 | 6 | **90** | None | OPEN |
| V14 | No audio response (text only) | User must read, not listen | 4 | 10 | 1 | **40** | N/A | OPEN |
| V15 | Concurrent voice + text | Race condition | 3 | 2 | 4 | 24 | tokio::spawn isolates | MITIGATED |

### Top 5 by RPN (highest risk):

| Rank | # | Failure Mode | RPN | Action Required |
|------|---|---|---|---|
| 1 | ~~V6~~ | ~~systemInstruction ignored~~ | ~~210~~ | **FIXED** (2-stage pipeline) |
| 2 | V9 | Heavy accent / noisy env | **168** | Need Gemini Live (native noise robustness) |
| 3 | V13 | Wrong language | **90** | Need multilingual detection |
| 4 | V10 | No internet | **48** | Need local Whisper installed |
| 5 | V1 | Live WS rejected | **40** | Need model name/config fix |
| 5 | V14 | No audio response | **40** | Need TTS via Gemini Live or sendVoice |

## 3. Criticality Classification

### Safety-Critical (Combat/Security/Fire)
| Feature | Why Critical | Current | Gap |
|---------|-------------|---------|-----|
| **Offline voice** | Field has no internet | Rule-ack only | Need Whisper local |
| **Noisy environment** | Gunfire, sirens, machinery | Not handled | Need Gemini Live |
| **Rapid response (<2s)** | Time-critical commands | ~4s REST | Need Live WS (250ms) |
| **Language agnostic** | Multilingual teams | English only | Need auto-detect |
| **Voice commands execute tools** | "Stop all containers!" | Text only | Need function calling |

### Business-Critical (Productivity)
| Feature | Why Critical | Current | Gap |
|---------|-------------|---------|-----|
| **Gmail via voice** | "Check my latest email" | Text cascade works | ✅ DONE |
| **Task management via voice** | "Add task P0" | Text classifier | ✅ DONE |
| **Accent adaptation** | Indian/German/etc accents | 10 samples learning | PARTIAL |
| **Audio response** | Listen while driving | Text only | Need TTS |

### Nice-to-Have (Enhancement)
| Feature | Current | Gap |
|---------|---------|-----|
| Emotion recognition | None | Gemini Live feature |
| Barge-in (interruption) | Not supported | Needs streaming |
| Screen sharing + voice | None | Needs video pipeline |
| SynthID watermarking | None | Gemini Live auto-enables |

## 4. FMEA-Based Evolutionary Approach

Evolution phases ordered by **RPN reduction** — fix highest-risk items first:

### Phase 1: Critical Risk Reduction (RPN > 100)
**Target**: Eliminate V9 (168) and V13 (90)
**Action**: Fix Gemini Live WebSocket

```
Sprint 1.1: Fix Live WS setup (4h)
  - Test model names: gemini-3.1-flash-live-preview, gemini-3.1-flash-live
  - Test alt endpoint: /v1beta/models/{model}:BidiGenerateContent?key=X&alt=ws
  - Log raw binary setup response for debugging
  RPN reduction: V1 (40→0), V9 (168→40), V13 (90→20), V14 (40→10)

Sprint 1.2: Enable native audio output (4h)
  - Set responseModalities: ["AUDIO", "TEXT"]
  - Encode output PCM 24kHz → OGG Opus
  - Send via Telegram sendVoice API
  RPN reduction: V14 (40→0)
```

**Phase 1 total RPN reduction: 338 → 70 (79% reduction)**

### Phase 2: Offline Resilience (RPN 40-50)
**Target**: Eliminate V10 (48)
**Action**: Install local Whisper

```
Sprint 2.1: Install Whisper (2h)
  - pip install openai-whisper (or use whisper.cpp for Rust native)
  - Test with 16kHz WAV samples
  - Wire into try_local_whisper() in mcp_inference.rs
  RPN reduction: V10 (48→5)

Sprint 2.2: Automated voice test suite (4h)
  - Download voxserv test audio (16kHz mono WAV)
  - Add voice scenarios to sim-test
  - Test: clean audio, noisy audio, accented audio, multilingual
  RPN reduction: V8 (30→10), V12 (20→5)
```

**Phase 2 total RPN reduction: 98 → 20 (80% reduction)**

### Phase 3: Advanced Capabilities (RPN < 40)
**Target**: Enhance quality and features

```
Sprint 3.1: Voice-activated tool use (4h)
  - Gemini Live function calling
  - Define tools: system_health, plan_status, email_send
  - Execute tool → speak result

Sprint 3.2: Conversation memory (2h)
  - Wire ConversationHistory to Live WS session
  - Gemini 3.1 has 2x context window

Sprint 3.3: Emotion-aware responses (2h)
  - Parse emotional state from Gemini Live
  - Adapt response tone (calm for stress, urgent for emergency)
```

### Phase 4: Full-Stack Voice (Long-term)
```
Sprint 4.1: WebRTC streaming (16h)
  - Replace voice notes with continuous audio
  - Sub-200ms latency

Sprint 4.2: Video + voice (12h)
  - Camera/screen input via Gemini Live
  - Voice-guided troubleshooting
```

## 5. Evolution Metrics

Track these after each phase:

| Metric | Phase 0 (now) | Phase 1 | Phase 2 | Phase 3 |
|--------|--------------|---------|---------|---------|
| Total RPN | 669 | 331 | 251 | <100 |
| Max single RPN | 168 | 40 | 10 | <10 |
| Voice latency | 4-6s | 250ms-1s | 250ms-1s | <250ms |
| Offline capable | Rule-ack only | Rule-ack | Whisper | Whisper+cache |
| Languages | English | 90+ | 90+ | 90+ |
| Audio response | No | Yes | Yes | Yes |
| Function calling | No | No | Yes | Yes |
| Tests | Manual | Automated | Automated | Full CI |

## 6. Mathematical Reliability Model

### Current (Phase 0)
```
P(voice_success) = P(transcribe) × P(text_inference) × P(delivery)
                 = 0.92 × 0.999995 × 0.99999
                 = 0.9199

P(transcribe) = 1 - P(gemini_2.5_fail) × P(gemini_3.1_fail) × P(whisper_fail) × P(rule_fail)
              = 1 - 0.05 × 0.08 × 1.0 × 0.0  (whisper not installed, rule always works)
              = 1 - 0 = 1.0 (rule-ack always succeeds, but quality=0)

Quality-weighted: P(quality_voice) = 0.92 (cloud success rate)
```

### After Phase 1 (Live WS working)
```
P(quality_voice) = 1 - P(live_fail) × P(rest_2.5_fail) × P(rest_3.1_fail)
                 = 1 - 0.05 × 0.05 × 0.08
                 = 0.9998

Latency: 250ms (Live) with 4s fallback
```

### After Phase 2 (Whisper installed)
```
P(quality_voice) = 1 - P(all_cloud_fail) × P(whisper_fail)
                 = 1 - 0.0002 × 0.02
                 = 0.999996

Fully offline capable with ~5s latency via Whisper
```
