# Voice Processing Pipeline Architecture

**Version**: 1.0.0
**Date**: 2026-04-09
**STAMP**: SC-OPENCLAW-001, SC-COG-001, SC-SAFETY-022
**Source Files**: `gemini_live.rs`, `mcp_inference.rs`, `cortex.rs`, `ingress_polling.rs`

---

## 1. Voice Pipeline Architecture

```
                          VOICE PROCESSING PIPELINE — 2-Stage Architecture
                          =================================================

  TELEGRAM                  INGRESS                  CORTEX                   INFERENCE
  ========                  =======                  ======                   =========

  User speaks         1. getUpdates poll       4. Detect voice intent   6. STAGE 1: Transcription
  into phone          2. Download .ogg file    5. Load accent profile      (audio -> text)
       |              3. Base64 encode            from Smriti
       v                 |                        |                      7. STAGE 2: Text Inference
  +-----------+          v                        v                         (transcript -> response
  | Voice msg |     +----------+            +-----------+                    with full system context)
  | .ogg opus |     | Zenoh    |            | process   |
  |  ~5-30s   |---->| Publish  |----------->| _voice()  |
  +-----------+     | intent/  |            |           |               +--------------------------+
                    | req      |            | 5-Tier    |               | Smriti ConversationHistory|
                    +----------+            | Cascade   |<------------>| per chat_id, last 50 msgs|
                         |                  +-----------+               +--------------------------+
                         |                       |
                         |                       v
                         |              +-----------------+
                         |              | Gateway:        |
                         |              | Telegram reply  |
                         |              | + GChat mirror  |
                         |              +-----------------+
                         |
                    Zenoh Topic:
                    indrajaal/l5/cog/intent/req
                    Payload JSON:
                    {
                      "id": "tg-voice-<uuid>",
                      "type": "voice",
                      "voice_b64": "<base64 OGG>",
                      "voice_duration_secs": N,
                      "voice_mime": "audio/ogg",
                      "source": "telegram",
                      "chat_id": "<id>"
                    }
```

---

## 2. 5-Tier Voice Cascade

The voice processing uses a 5-tier cascade with automatic fallback. Each tier is tried in order; the first successful result wins.

```
  +-----------+     +-----------+     +------------+     +-----------+     +----------+
  | Tier 0    |     | Tier 1    |     | Tier 1b    |     | Tier 2    |     | Tier 3   |
  | Live WS   |--X->| REST 2.5  |--X->| REST 3.1   |--X->| Whisper   |--X->| Rule Ack |
  | (3.1 Flash|     | Flash     |     | Flash Lite |     | Local     |     | (Always  |
  |  Live)    |     | Multimodal|     | Preview    |     |           |     |  works)  |
  +-----------+     +-----------+     +------------+     +-----------+     +----------+
   ~250ms            ~2s               ~2s                ~5s               <1ms
   WebSocket         REST              REST               CLI               Static
   Full-duplex       Cloud             Cloud              Offline           Offline
```

| Tier | Model | Protocol | Latency | Connectivity | Notes |
|------|-------|----------|---------|--------------|-------|
| 0 | gemini-3.1-flash-live-preview | WebSocket | ~250ms | Cloud | Lowest latency, simultaneous transcription + response |
| 1 | gemini-2.5-flash | REST | ~2s | Cloud | Multimodal audio input, retry on 503 |
| 1b | gemini-3.1-flash-lite-preview | REST | ~2s | Cloud | Fallback model if 2.5 is overloaded |
| 2 | whisper (local binary) | CLI | ~5s | Offline | 100% local, works without internet |
| 3 | rule-based ack | In-process | <1ms | Offline | ALWAYS succeeds, acknowledges receipt |

**Circuit Breakers**: Tiers 1/1b share the Gemini circuit breaker (3 consecutive failures = 60s cooldown). Tiers 2 and 3 are local and never circuit-break.

**Retry Logic**: Tier 1 retries once on HTTP 503 with a 2-second delay before falling through to Tier 1b.

---

## 3. 2-Stage Processing

A critical design decision: voice processing is split into two stages because Gemini's `systemInstruction` is ignored when audio data is present in the request. This means the LLM cannot receive the full system prompt (Gmail access, Zenoh commands, task management, etc.) alongside audio.

### Stage 1: Audio to Transcript

```
Input:  base64-encoded OGG audio
Output: Raw transcription text (what the user said)
Model:  Any voice-capable tier (Live WS, REST multimodal, Whisper)
Prompt: "Listen to this voice message. First transcribe exactly what was said..."
```

### Stage 2: Transcript to Context-Aware Response

```
Input:  Transcription text + task summary + conversation history
Output: Full response with system capabilities awareness
Model:  Text inference cascade (Gemini Direct || OpenRouter hedged, Ollama fallback)
Prompt: Full SYSTEM_PROMPT (commands, capabilities, connected systems)
```

The Stage 2 prompt is enriched with:
- **Task summary**: Active/pending task counts from Smriti
- **Conversation history**: Last 10 messages for this chat_id
- **System prompt**: Full 340-character prompt with all /commands and capabilities

```rust
// From cortex.rs — Stage 2 prompt construction
let enhanced_prompt = format!(
    "User said (voice, {}s): \"{}\"\n\nTasks: {}\n\nRespond concisely.",
    duration, transcript, task_summary
);
```

---

## 4. Telegram Voice Note Integration

### Download Flow

```
Telegram Bot API
       |
       v
1. getUpdates (long-poll, offset-tracked)
       |
       v
2. Detect message.voice field
   file_id, duration, mime_type
       |
       v
3. getFile?file_id=<id>
   -> result.file_path
       |
       v
4. Download: /file/bot<token>/<file_path>
   -> audio_bytes (OGG Opus)
       |
       v
5. Base64 encode
   -> voice_b64 string
       |
       v
6. Publish to Zenoh:
   indrajaal/l5/cog/intent/req
   {type: "voice", voice_b64: "...", voice_duration_secs: N, ...}
```

### Implementation Details (ingress_polling.rs)

- **Polling offset**: Persisted to `Smriti.db` preference `telegram_poll_offset` to avoid replaying old messages after daemon restart
- **Retry on Zenoh publish**: 3 attempts with 100ms delay between failures
- **Dead letter logging**: If all 3 Zenoh publishes fail, the message is logged as a dead letter
- **Simulator support**: `SIMULATOR_TELEGRAM_URL` env var redirects to the mock HTTP server for testing

---

## 5. Gemini Live WebSocket Protocol

**File**: `gemini_live.rs` (227 lines)
**Model**: `models/gemini-3.1-flash-live-preview`
**Voice**: `Kore` (clear, professional)
**URL**: `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent`

### Protocol Sequence

```
Client                                      Gemini Live API
  |                                              |
  |--- WebSocket Connect (with API key) -------->|
  |                                              |
  |--- Setup JSON -------------------------------->|
  |   {                                          |
  |     "setup": {                               |
  |       "model": "models/gemini-3.1-flash-live-preview",
  |       "generationConfig": {                  |
  |         "responseModalities": ["TEXT"],       |
  |         "temperature": 0.2                   |
  |       },                                     |
  |       "systemInstruction": {...},            |
  |       "inputAudioTranscription": {},         |
  |       "outputAudioTranscription": {}         |
  |     }                                        |
  |   }                                          |
  |                                              |
  |<--- setupComplete ----------------------------|
  |                                              |
  |--- Audio Chunks (8KB each, PCM 16kHz) ------>|
  |   {"realtimeInput": {                        |
  |     "audio": {"data": "<b64>",               |
  |       "mimeType": "audio/pcm;rate=16000"}    |
  |   }}                                         |
  |   ... (repeated for all chunks) ...          |
  |                                              |
  |--- audioStreamEnd --------------------------->|
  |                                              |
  |<--- serverContent/inputTranscription ---------|
  |<--- serverContent/modelTurn/parts ------------|
  |<--- serverContent/turnComplete ---------------|
  |                                              |
  |--- WebSocket Close -------------------------->|
```

### Audio Conversion

OGG Opus audio from Telegram is converted to raw PCM via ffmpeg:

```
ffmpeg -i /tmp/c3i_voice_<ts>.ogg \
       -f s16le -acodec pcm_s16le \
       -ar 16000 -ac 1 -y \
       /tmp/c3i_voice_<ts>.pcm
```

Parameters: 16kHz sample rate, 16-bit signed little-endian, mono channel.

### Chunk Size

Audio is streamed in 8KB chunks (~250ms of 16kHz 16-bit mono audio). This provides smooth streaming without overwhelming the WebSocket.

### Response Parsing

The response can arrive as either `Text` or `Binary` WebSocket frames. Both are handled:

```rust
let text_str = match &msg {
    Ok(Message::Text(t)) => t.to_string(),
    Ok(Message::Binary(b)) => String::from_utf8_lossy(b).to_string(),
    ...
};
```

Three JSON paths are extracted:
- `/serverContent/inputTranscription/text` -- what the user said
- `/serverContent/outputTranscription/text` -- model's spoken response text
- `/serverContent/modelTurn/parts[].text` -- model's text response parts

---

## 6. Accent Learning

The system maintains a running accent profile in Smriti to improve transcription accuracy over time.

### Storage

- **Key**: `voice_accent_profile`
- **Category**: `agent`
- **Format**: Pipe-separated samples, capped at ~500 characters
- **Example**: `Sample: check status of containers | how are the tasks going | deploy the mesh`

### Accumulation Logic (cortex.rs)

```
1. Voice message arrives
2. Load accent_ctx from Smriti (voice_accent_profile)
3. Process voice through cascade
4. Extract transcription from between first pair of quotes
5. Take first 100 chars of transcript as new sample
6. Append: "{existing_profile} | {new_sample}"
7. Cap at 400 chars from existing + new sample
8. Save back to Smriti
```

### Usage in Prompts

The accent context is injected into both:
- **Live WS setup**: `systemInstruction` includes `"Known accent patterns: {accent_context}"`
- **REST multimodal**: System prompt includes `"Known accent patterns: {accent_context}"`

This helps the model adjust to the user's pronunciation patterns, regional accent, and typical vocabulary.

---

## 7. Conversation History Integration

### Table: ConversationHistory

```sql
CREATE TABLE IF NOT EXISTS ConversationHistory (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    chat_id         TEXT NOT NULL,
    source          TEXT NOT NULL,
    role            TEXT NOT NULL,    -- 'user' or 'assistant'
    content         TEXT NOT NULL,    -- max 2000 chars
    intent_id       TEXT,
    timestamp_ms    INTEGER NOT NULL
);
CREATE INDEX idx_conv_chat ON ConversationHistory(chat_id, timestamp_ms DESC);
```

### Retention Policy

- **Last 50 messages** per `chat_id` are retained
- Older messages are deleted on every new insert (bounded retention)
- Content is truncated to 2000 characters on insert

### Context Window for Voice

When processing Stage 2 (transcript to response), the last 10 conversation messages are loaded and formatted:

```rust
let history = db::conversation_get(&chat_id, 10).ok().unwrap_or_default();
let history_str = history.iter().rev()
    .map(|(role, content)| format!("{}: {}", role, trunc(content, 150)))
    .collect::<Vec<_>>().join("\n");
```

This gives the LLM context about what the user has been discussing in this chat session.

---

## 8. Safety-Critical Design

### Problem Statement

This system may be used in environments with bad connectivity (field operations, combat zones, emergency response, firefighting). Voice must always produce some response.

### Design Principles

1. **Never blackhole**: Tier 3 (rule-based ack) ALWAYS returns a response, even if all LLM tiers fail
2. **Graceful degradation**: Each tier failure logs a warning and tries the next tier
3. **Offline capability**: Tier 2 (Whisper) works completely offline; Tier 3 works without any external dependency
4. **Fast acknowledgment**: When used via Telegram with chat, the system sends "Processing voice..." immediately before starting the cascade
5. **Timeout bounded**: Live WS has 5s setup timeout + 10s response timeout; REST inherits 8s tier timeout

### Failure Mode Response

| Failure | Tier | User Sees |
|---------|------|-----------|
| Gemini API key missing | 0-1b skip | Falls through to Whisper or rule ack |
| Gemini 503 overloaded | 1 retry once | Tries 1b (different model), then Whisper |
| Live WS "Internal error" | 0 | Falls through to REST (Tier 1) |
| No internet | 0-1b fail | Whisper local transcription + text inference |
| Whisper not installed | 2 fail | Rule ack: "Voice message received (Ns). Could not transcribe" |
| ffmpeg not installed | 0 fail | Falls through to REST multimodal (no PCM needed) |

---

## 9. Known Issues and Fixes

### 9.1 Unicode Panic Fix

**Problem**: `&s[..max]` panics if `max` lands in the middle of a multi-byte UTF-8 character.

**Fix**: The `trunc()` function in `cortex.rs` walks backward to find a valid char boundary:

```rust
fn trunc(s: &str, max: usize) -> &str {
    if s.len() <= max { return s; }
    let mut end = max;
    while end > 0 && !s.is_char_boundary(end) { end -= 1; }
    &s[..end]
}
```

This is used everywhere strings are truncated: error messages, log output, database inserts.

### 9.2 Live WS Binary Response

**Problem**: The Gemini Live API sometimes sends `setupComplete` as a Binary WebSocket frame instead of Text.

**Fix**: Both `Message::Text` and `Message::Binary` are handled in the response loop:

```rust
let setup_text = match setup_msg {
    Message::Text(t) => t.to_string(),
    Message::Binary(b) => String::from_utf8_lossy(&b).to_string(),
    other => return Err(...)
};
```

### 9.3 systemInstruction Ignored for Audio

**Problem**: When sending `inline_data` (audio) in the REST API `contents`, the `systemInstruction` field is effectively ignored by Gemini. The model does not follow the system prompt.

**Fix**: This is the fundamental reason for the 2-stage architecture. Stage 1 is audio-only (transcription), and Stage 2 is text-only with the full system prompt.

### 9.4 Gemini Live "Internal error" on Setup

**Problem**: The Live WS API returns `{"error": "Internal error"}` instead of `setupComplete` for certain model names or configurations.

**Status**: OPEN. Currently falls through to Tier 1 (REST). May be a model name issue (`gemini-3.1-flash-live-preview` vs other variants) or a config issue.

---

## 10. Test Plan for Voice

### 10.1 Manual Testing via Telegram

1. Send a voice message to the Telegram bot
2. Verify "Processing voice..." acknowledgment appears within 2 seconds
3. Verify transcription appears in response (quoted text)
4. Verify context-aware response follows the transcription
5. Verify conversation history is recorded (`sa-plan-daemon` shell: check ConversationHistory table)
6. Verify accent profile accumulates (check `voice_accent_profile` preference)

### 10.2 Automated Testing with WAV Samples

**Status**: NOT YET IMPLEMENTED

**Plan**:
1. Source: `voxserv/audio_quality_testing_samples` (or similar public WAV corpus)
2. Convert WAV to OGG Opus via ffmpeg
3. Base64 encode and inject into simulator mock
4. Run `sa-plan-daemon sim-test --port 9999 --duration-secs 120`
5. Assert: transcription is non-empty, response is non-empty, latency < 10s
6. Assert: accent profile in Smriti is updated after test

### 10.3 Cascade Fallback Testing

1. Set `gemini_api_key` to invalid value in Smriti
2. Send voice message
3. Verify system falls through to Whisper or rule-based ack
4. Verify no panic or crash occurs
5. Reset API key and verify normal operation resumes

---

## 11. Gemini 3.1 Flash Live Features Roadmap

The following features are available in the Gemini 3.1 Flash Live API but are **NOT YET IMPLEMENTED** in the C3I voice pipeline.

| Feature | Description | Status |
|---------|-------------|--------|
| **Voice Activity Detection (VAD)** | Server-side detection of speech start/end, eliminating need for manual `audioStreamEnd` | Not implemented |
| **Barge-in** | User can interrupt the model while it is speaking/generating | Not implemented |
| **Emotional Recognition** | Detect emotion in voice (tone, pitch, cadence) for operator stress assessment | Not implemented |
| **Multilingual** | Automatic language detection and switching mid-conversation | Not implemented |
| **Audio Output** | Model responds with synthesized speech audio (currently TEXT only) | Not implemented (TEXT mode only) |
| **Session Resumption** | Resume a Live session after disconnect without re-sending setup | Not implemented |
| **Function Calling** | Model can invoke tools during voice conversation | Not implemented |
| **Continuous Streaming** | Keep WebSocket open for multi-turn voice conversation | Not implemented (single-shot per message) |

### Priority for Implementation

1. **Multilingual** -- Highest value for the operator who speaks multiple languages
2. **VAD** -- Reduces latency by not waiting for explicit end signal
3. **Barge-in** -- Natural conversation flow
4. **Continuous Streaming** -- Keeps TLS warm, reduces per-message latency
5. **Function Calling** -- "Send an email to X" directly from voice
6. **Emotional Recognition** -- Operator stress detection for safety (SC-SAFETY-022)

---

## Appendix A: Configuration Keys in Smriti

| Key | Category | Purpose |
|-----|----------|---------|
| `gemini_api_key` | `agent` | Google AI API key for Gemini models |
| `openrouter_api_key` | `agent` | OpenRouter API key for hedged requests |
| `telegram_token` | `infra_state` | Telegram Bot API token |
| `telegram_poll_offset` | `infra_state` | Last processed Telegram update ID |
| `voice_accent_profile` | `agent` | Accumulated accent learning samples |

## Appendix B: Timing Budget

```
Tier 0 (Live WS):
  OGG decode + ffmpeg PCM:  ~200ms
  WebSocket connect:        ~100ms
  Setup + setupComplete:    ~150ms
  Audio streaming:          ~50ms per 8KB chunk
  Model response:           ~500ms
  Total:                    ~1000-1500ms

Tier 1 (REST multimodal):
  HTTP request:             ~200ms
  Model processing:         ~1500ms
  Total:                    ~1700-2500ms

Stage 2 (Text inference, always runs after Stage 1):
  Hedged request:           ~500-2000ms
  Total voice pipeline:     ~1500-4500ms typical
```
