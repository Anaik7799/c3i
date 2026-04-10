# Master Fractal Integration Matrix: Voice, Chat, Zenoh, and Observability
**Version**: 1.0.0
**Date**: 2026-04-09
**Mandate**: SC-OPENCLAW-001, SC-COG-001, SC-ZMOF-001, SC-GLM-ZEN-001

This matrix maps all system capabilities (Offline Voice, Chat, Zenoh Mesh, Observability, and Formal Specs) across all 8 Fractal Layers (L0-L7) and all system components.

## 1. System-Wide Integration Matrix

| Fractal Layer | Component | Offline Voice | Chat Processing | Zenoh Integration | Observability & Logging | Formal Specs |
|:---|:---|:---|:---|:---|:---|:---|
| **L0 Constitutional** | Guardian Gate (`guardian_nif`) | N/A | Validates prompt injections | Subscribes to `indrajaal/l0/const/` | Emits Guardian verification spans | `GuardianSafety.tla` |
| **L0 Constitutional** | Safety Kernel | Biometric Auth Rejection | Rate Limiting | Zenoh Pub/Sub for alerts | Logs `auth_rejected` | `SafeState.tla` |
| **L1 Atomic/NIF** | SQLite (`db.rs`) | Stores `voice_print`, `voice_accent_profile` | Stores `ConversationHistory`, `Feedback` | N/A | Logs slow queries (>5ms) | C bindings verification |
| **L1 Atomic/NIF** | FFMPEG (`gemini_live.rs`) | OGG -> PCM 16kHz conversion | N/A | N/A | Process exit code logging | `AudioCodec.tla` |
| **L2 Component** | Health Consensus | Triggers fallback on Whisper failure | Triggers Rule Fallback | Zenoh broadcast for quorum | OTel spans for health metrics | `Quorum.tla` |
| **L2 Component** | Inference Cascade (`mcp_inference.rs`) | 3-Tier: Live -> REST -> Whisper local | 5-Tier: Gemini -> OR -> Ollama -> Rule | N/A | Logs `latency_ms`, model used | `InferenceCascade.tla` |
| **L3 Transaction** | `TransactionSummary` | Records voice processing stats | Records chat latency and model | N/A | `db::get_recent_traces` | ACID property checks |
| **L3 Transaction** | RAG Pipeline (`rag.rs`) | N/A | Extracts context from tasks/history | N/A | Logs context injection length | `RagPipeline.tla` |
| **L4 System** | Podman Substrate | Manages local Whisper container (if used) | Manages Ollama container | N/A | Container health logs | `PodmanOps.allium` |
| **L4 System** | `sa-plan-daemon` | Authoritative Voice Pipeline Executor | Authoritative Chat Intent Executor | Authoritative Zenoh Client | Dual Logging (Terminal + SQLite) | `Ignition.allium` |
| **L5 Cognitive** | Cortex Daemon (`cortex.rs`) | Transcribes voice -> Contextual Prompt | Processes `TaskIntent`, `/command` | Subscribes to `indrajaal/l5/cog/intent/` | Emits pipeline traces (`PipelineTracer`) | `ChatPipeline.tla` (Apalache verified) |
| **L5 Cognitive** | Ruliology (`rule_engine.rs`) | Offline transcription fallback logic | Deterministic intent routing | Subscribes to `indrajaal/l5/cog/mcp/req/rule/` | Emits `RuleResult` traces | `Ruliology.allium` |
| **L5 Cognitive** | Auto-FMEA (`fmea.rs`) | Suggests mitigations for offline fallback | Detects LLM Timeouts (15s) | N/A | Logs `FmeaReport` to CLI | `FMEAAnalysis.tla` |
| **L6 Ecosystem** | Zenoh Router | Transports voice intent blobs | Transports chat intents | Root routing instance | Throughput and latency logs | `ZenohTopology.tla` |
| **L6 Ecosystem** | Gleam UI (`lustre`) | Displays `VoiceStatus` (Listening/Auth) | Displays `MessagesSnapshot` | `indrajaal/l5/cog/mcp/req/` | OTel span publishing | `TripleInterface.tla` |
| **L7 Federation** | Gateway (`gateway.rs`) | Dispatches transcript and response | Dispatches text and dual-channel Approvals | N/A | Logs `telegram` and `gchat` status | `FederationSync.tla` |
| **L7 Federation** | Discovery Protocol | N/A | N/A | Broadcasts presence | Logs new node pairing | `LeaderElection.tla` |

## 2. Component Deep Dive

### 2.1 Offline Voice (Whisper / Local)
- **Role**: Serves as the ultimate L3 fallback in the `process_voice` cascade if WebSocket (Gemini Live) and REST API endpoints fail.
- **Observability**: Traces `whisper-local` model usage and latency to `TransactionSummary`.
- **Formal Guarantee**: The system must never drop a voice intent (`NoBlackhole` property in TLA+).

### 2.2 Chat Components (RAG + Cortex)
- **Role**: Parses commands, queries RAG context, and formats prompts for the 5-Tier inference cascade.
- **Observability**: `PipelineTracer` logs every stage from `received` to `delivered`. Evolve loop harvests feedback.
- **Formal Guarantee**: `RuleFallbackNeverFails` ensures a valid string is always returned to the gateway.

### 2.3 Zenoh Mesh
- **Role**: Replaces traditional REST/HTTP for all internal agent and UI communication (MoZ Protocol).
- **Observability**: All telemetry and MCP tools ride over Zenoh.

### 2.4 Formal Specs (TLA+ / Apalache / Allium)
- **Role**: Mathematical verification of system state bounds.
- **Status**: `ChatPipeline.tla` verified with Apalache 0.44.2 (Zero Type errors, No deadlocks).
