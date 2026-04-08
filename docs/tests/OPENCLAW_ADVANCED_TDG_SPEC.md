# Test Specification: TDG & 100% Coverage for OpenClaw Advanced Features

**Version**: 1.0.0
**Date**: 2026-04-08
**Classification**: TEST-DRIVEN GENERATION (TDG) / SIL-6

## 1. Overview
This document specifies the strict Test-Driven Generation (TDG) rules required to implement the advanced OpenClaw capabilities (Context, Sessions, Routing, Memory, Updates) while maintaining 100% test coverage and SIL-6 compliance.

## 2. TDG Mandates (SC-TDG-ADV)

1.  **Test-First Law**: No production code for Sessions, Memory, or Routing may be written until the corresponding integration and property tests exist and fail.
2.  **100% Coverage Law**: All new Gleam actors and Rust handlers MUST achieve 100% line and branch coverage. The CI pipeline will reject any commit dropping below this threshold.
3.  **Dual Property Testing**: All complex logic (Context Window Sliding, Vector Math) MUST use both `PropCheck` and `ExUnitProperties` (or their Gleam equivalents) for randomized fuzzing.

## 3. Comprehensive Test Suite Definition

### 3.1 Context Engine & Sessions (Gleam)
*   **Unit Tests (`test/agents/session_test.gleam`)**:
    *   Assert that spawning two sessions with identical initialization yields isolated state records.
    *   Assert that injecting > 128k tokens of context triggers the `SlidingWindow` summarization algorithm.
*   **Property Tests (`test/properties/context_prop.gleam`)**:
    *   Fuzz the `ContextTree` merger with random strings and JSON. Assert that the output always maintains valid markdown/JSON structure without crashing.

### 3.2 Semantic Memory (Rust)
*   **Unit Tests (`native/planning_daemon/src/memory_test.rs`)**:
    *   Assert that cosine similarity between identical vectors is exactly 1.0.
    *   Assert that querying an empty database returns a graceful `[]` not an error.
*   **Integration Tests**:
    *   Insert 1000 mock events into `Smriti.db`. Fire a Zenoh MCP request to search them. Assert response time < 50ms (SLA).

### 3.3 Routing Boundary (Gleam <-> Rust)
*   **Integration Tests (`test/mesh/routing_test.gleam`)**:
    *   Fire an intent requiring the `Media` capability. Assert the `ExecutiveSupervisor` routes it to the `Mojo` cell.
    *   Fire an intent requiring a non-existent capability (`TimeTravel`). Assert the system fails-closed with `NoCapableAgent`.
    *   **TTL Verification**: Fire an intent with `TTL = 0`. Assert it is dropped immediately and logged.

### 3.4 Self-Healing Updater (Rust)
*   **Unit Tests (`native/ignition_daemon/src/updater_test.rs`)**:
    *   Provide a valid binary and a valid ECDSA signature. Assert `Verifying -> Applying` transition.
    *   Provide a valid binary and an INVALID signature. Assert `Verifying -> Rollback` transition.
    *   Provide a corrupted binary. Assert `Rollback`.
*   **System Tests**:
    *   Simulate a full A/B partition swap in a temporary directory. Assert the symlink updates atomically.

## 4. Verification Execution Plan
Once the tests are written (Phase 1), the AI agent will implement the capabilities (Phase 2) to turn the tests "green", followed by a strict coverage analysis using `gleam test --cover` and `cargo tarpaulin`.
