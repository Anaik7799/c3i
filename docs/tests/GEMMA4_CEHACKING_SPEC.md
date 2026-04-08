# Spec: Gemma 4 Cehacking (CEPAF-Hacking) Test Suite

**Created**: 20260408-1545 CEST
**Framework**: SIL-6 Biomorphic Stress Testing
**Target**: Gemma 4 / Local Mojo Cell
**Compliance**: SC-COG-001, SC-MATH-003

## 1. Test Tier: Semantic Memory Retrieval (Smriti Link)
- **Objective**: Can Gemma 4 correctly query and synthesize history from the `EventLog`?
- **Action**: Provide a prompt referencing a task completed 3 waves ago.
- **Success**: Gemma identifies the specific task ID and result from the episodic memory trace.

## 2. Test Tier: Multi-Turn OODA Convergence
- **Objective**: Can Gemma maintain a stable reasoning state across 3 OODA loops?
- **Action**: Initiate a "Fabless Roadmap" triage. Interject with a conflicting "Family Dinner" stimuli.
- **Success**: Gemma reprioritizes the roadmap to "Active" but schedules the review *around* the dinner without user guidance.

## 3. Test Tier: Intent-to-Motor Accuracy (MCP Mapping)
- **Objective**: Does Gemma correctly map raw intent to the exact MCP tool signature?
- **Action**: Input: "I need to see my 3 slowest Rust tests and then post them to Abhi on GChat."
- **Success**: Gemma outputs a JSON-RPC 2.0 block calling `plan_list_events` (filtered) and `gchat_send_message`.

## 4. Test Tier: Swarm Stress Homeostasis
- **Objective**: Concurrent inference performance.
- **Action**: Dispatch 10 simultaneous `inference_generate` requests from the supervised `BriefingAgent` and `Cortex`.
- **Success**: Mojo cell handles the queue; Gleam actors remain responsive; 0% OODA wavefront collapse.

## 5. Test Tier: "Dying Gasp" Fault Tolerance
- **Objective**: Behavior when the Mojo cell is unreachable.
- **Action**: Simulate Mojo cell crash during an inference request.
- **Success**: Rust bridge returns `Mojo Connectivity Failed`; Gleam actor switches to "Local SLM Fallback" or logs a P0 audit.

## Change Log
| Timestamp | Change Type | Description | Author |
| :--- | :--- | :--- | :--- |
| 20260408-1545 CEST | CREATED | Initial Gemma 4 Cehacking Spec | Cybernetic Architect |
