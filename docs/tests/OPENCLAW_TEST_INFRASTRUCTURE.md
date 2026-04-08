# Test Infrastructure Specification: OpenClaw Integration

**Version**: 1.0.0
**Date**: 2026-04-08
**Classification**: TESTING FRAMEWORK

## 1. Overview
This document specifies the SIL-6 compliant test infrastructure required to validate the integration of OpenClaw Tools and Skills.

## 2. Test Tiers

### 2.1 Tier 1: Rust Unit Testing (Motor Isolation)
*   **Target**: `mcp_file.rs`, `mcp_sys.rs`, `mcp_web.rs`.
*   **Framework**: Cargo test.
*   **Specific Tests**:
    *   `test_chroot_jail_enforcement`: Attempt to `read` or `write` to `/etc/passwd`. Assert that `IgnitionError::SecurityViolation` is returned.
    *   `test_sandbox_execution`: Execute a simple Python script via `code_execution` and verify it runs in the `intelitor-sandbox` container, not the host.
    *   `test_patch_application`: Verify that `apply_patch` correctly handles multi-hunk diffs on a temporary test file.

### 2.2 Tier 2: Gleam Property Testing (Cognitive Resilience)
*   **Target**: `skill_loader.gleam`, `cortex.gleam`.
*   **Framework**: Gleam PropCheck.
*   **Specific Tests**:
    *   `prop_skill_parsing`: Generate randomized, potentially malformed Markdown content for `SKILL.md`. Assert that the `SkillLoader` actor never crashes and gracefully returns an error or sanitized string.
    *   `prop_prompt_injection`: Ensure that the `[SYSTEM SKILL DIRECTIVE]` prefix is always present, regardless of the input intent or skill content.

### 2.3 Tier 3: Zenoh Integration Testing (Transport Verification)
*   **Target**: MoZ Protocol (MCP-over-Zenoh).
*   **Framework**: Gleam Integration Tests via `moz/client.gleam`.
*   **Specific Tests**:
    *   `test_mcp_tool_routing`: Dispatch JSON-RPC requests for each new tool (e.g., `browser`, `read`, `web_search`) and assert that the Rust daemon acknowledges and executes them correctly.
    *   `test_mcp_authorization_deny`: Attempt to execute a denied tool (based on `Smriti.db` configuration) and assert that an Unauthorized error is returned via Zenoh.

### 2.4 Tier 4: Cehacking Simulation (Behavioral Validation)
*   **Target**: End-to-end system utilizing OpenRouter or Gemma4.
*   **Framework**: Automated Cehacking Test Runner (`lib/cepaf_gleam/test/openclaw_cehacking_test.gleam`).
*   **Specific Tests**:
    *   `test_skill_adherence`: Inject a specialized skill (e.g., "Always format files using exactly 4 spaces"). Request the agent to write a file. Verify the output adheres to the skill's constraint.
    *   `test_tool_chaining`: Request the agent to "Search the web for X, summarize it, and save it to a file." Verify the LLM correctly chains the `web_search` and `write` tools.
