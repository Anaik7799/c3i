# Test Infrastructure Specification: Wisp Webhook Federation

**Version**: 1.0.0
**Date**: 2026-04-08
**Classification**: TESTING FRAMEWORK

## 1. Overview
This document specifies the SIL-6 compliant test infrastructure required to validate the Wisp webhook receivers.

## 2. Test Tiers

### 2.1 Tier 1: Wisp HTTP Unit Testing
*   **Target**: `wisp/router.gleam`.
*   **Framework**: Gleam testing (using Wisp's testing utilities).
*   **Specific Tests**:
    *   `test_telegram_webhook_valid`: Send a mock Telegram JSON payload with the correct secret header. Assert a `200 OK` response.
    *   `test_telegram_webhook_invalid_secret`: Send a payload with a missing or incorrect secret. Assert a `401 Unauthorized` response.
    *   `test_malformed_json`: Send invalid JSON to the webhook endpoints. Assert a `400 Bad Request` response.

### 2.2 Tier 2: Zenoh Integration Testing
*   **Target**: Wisp $\rightarrow$ Zenoh integration.
*   **Framework**: Gleam integration tests.
*   **Specific Tests**:
    *   `test_webhook_publishes_intent`: Send a valid mock webhook. Subscribe to `indrajaal/l5/cog/intent/req` in the test and assert the intent payload is correctly formatted and published within 50ms.

## 3. Behavioral Constraints
*   **SC-WEBHOOK-001**: Webhook handlers MUST NOT perform blocking operations (e.g., database writes, LLM inference). They MUST only publish to Zenoh and return immediately.
*   **SC-WEBHOOK-002**: All webhook payloads MUST be cryptographically verified before processing to prevent unauthorized intent injection.
