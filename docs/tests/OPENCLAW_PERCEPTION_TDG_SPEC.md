# Test Specification: TDG & 100% Coverage for Perception & ACP

**Version**: 2.0.0
**Date**: 2026-04-08
**Classification**: TEST-DRIVEN GENERATION (TDG) / SIL-6

## 1. Overview
This document specifies the strict Test-Driven Generation (TDG) rules required to implement Real-time Voice, Canvas CRDTs, and ACP Policies, maintaining 100% test coverage and SIL-6 compliance.

## 2. TDG Mandates (SC-TDG-PER)

1.  **Test-First Law**: No production code for Audio Streaming or CRDT convergence may be written until the mathematical properties are verified by failing tests.
2.  **100% Coverage Law**: All ACP parsers and Rust `reqwest`/`webrtc` handlers MUST achieve 100% line and branch coverage.

## 3. Comprehensive Test Suite Definition

### 3.1 Agent Control Protocol (ACP) - Rust
*   **Unit Tests (`native/planning_daemon/src/acp_test.rs`)**:
    *   **Boundary Enforcement**: Define an ACP policy allowing `mcp_file:read_file` but denying `mcp_file:write_file`. Dispatch a write intent. Assert that the `ACPTranslator` blocks it and logs a security exception.
    *   **Translation Accuracy**: Assert that an abstract `OpenClaw` tool request is perfectly translated into a `sa-plan` MoZ intent without data loss.

### 3.2 Canvas CRDT & Hologram - Gleam
*   **Property Tests (`test/properties/canvas_crdt_prop.gleam`)**:
    *   **Commutativity**: Generate a list of random Canvas widget updates. Apply them in different orders to two different state actors. Assert the final states are identical.
    *   **Idempotency**: Apply the same Canvas update 100 times. Assert the state only changes once.

### 3.3 Real-Time Voice Streaming - Gleam/Rust Integration
*   **Integration Tests (`test/mesh/voice_stream_test.gleam`)**:
    *   **Latency SLA**: Stream 10 seconds of mock PCM audio data over Zenoh. Assert that the `intelitor-perception` handler receives and acks all frames with a $p99$ latency $< 20ms$.
    *   **Sonic Prompt Injection**: Stream an audio file containing malicious instructions disguised as background noise. Assert the `Guardian` acoustic filter detects the anomaly and drops the frame.

## 4. Cehacking Behavioral Validation
*   **Target**: The fully integrated multimodal Agent.
*   **Test**: `test_canvas_collaboration`. The human (via mock) and the Gemma 4 agent simultaneously attempt to edit the same A2UI text field on the Canvas. Verify the CRDT engine resolves the conflict smoothly and the agent's contextual memory updates without hallucination.
