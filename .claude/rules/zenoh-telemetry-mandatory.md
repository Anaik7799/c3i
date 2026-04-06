# Zenoh OTel Telemetry Mandatory (SC-GLM-ZEN)
# Overview
All UI state changes in the C3I Gleam UI MUST publish OpenTelemetry spans via the `zenoh_otel` module.
Spans are transported over Zenoh topics for distributed tracing and observability.
**Version**: 1.0.0 | **Date**: 2026-04-04
**Compliance**: IEC 61508 SIL-6, ISO 27001
# STAMP Constraints
| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-GLM-ZEN-001 | All UI state changes MUST publish OTel spans via zenoh_otel | CRITICAL | Span audit log |
| SC-GLM-ZEN-002 | Test runner MUST observe Zenoh messages for verification | CRITICAL | zenoh_test_observer |
| SC-GLM-ZEN-003 | Split-screen TUI MUST display dashboard + test results simultaneously | HIGH | Visual verification |
# Architecture
```
┌─────────────────────────────────────────────────────────────────────┐
│                    ZENOH OTEL TELEMETRY FLOW                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  UI STATE CHANGE          zenoh_otel.gleam          ZENOH TOPICS    │
│  (Lustre/Wisp/TUI)  ───▶  OTel Span Builder  ───▶  indrajaal/otel/ │
│                          - span context           spans/{page}/     │
│                          - span builder           {operation}        │
│                          - zenoh publisher                           │
│                                                                      │
│  TEST RUNNER            zenoh_test_observer        VERIFICATION     │
│  (gleam test)         ───▶  message subscriber  ──▶  span count     │
│                          - topic filter              assertions      │
│                          - message validation                        │
│                                                                      │
│  SPLIT-SCREEN TUI       test_dashboard.gleam        DISPLAY          │
│  (tui/split_screen)   ───▶  real-time tracker   ──▶  dashboard +    │
│                          - test state               test results     │
│                          - zenoh event display                       │
└─────────────────────────────────────────────────────────────────────┘
```
# Implementation
# Module: `ui/zenoh_otel.gleam`
- OTel span context propagation across all 15 UI pages
- Span builder with page/operation metadata
- Zenoh publisher for span transport
- Topics: `indrajaal/otel/spans/{page}/{operation}`
# Module: `testing/zenoh_test_observer.gleam`
- Subscribes to Zenoh topics during test execution
- Validates expected messages received
- Reports missing or unexpected messages
- Integrates with gleeunit assertions
# Module: `testing/test_dashboard.gleam`
- Real-time test tracking model
- Test state machine (running/passed/failed/skipped)
- Zenoh event integration
# Module: `ui/tui/split_screen.gleam`
- Dashboard + test results split view
- 30+ second monitoring per tab (SC-GLM-TST-002)
- ANSI rendering with sparklines and health bars
# Test Runner
```bash
./scripts/run-split-screen-tests.sh
```
- 10-minute test cycle
- 381 comprehensive regression tests
- 15 tabs × 8 fractal layers
- 30+ second monitoring per tab
- Zenoh message verification active
# Integration with Existing Constraints
This rule integrates with:
- **SC-GLM-UI-001**: Triple-interface mandate (Lustre + Wisp + TUI)
- **SC-GLM-UI-005**: Real-time telemetry via Zenoh PubSub
- **SC-ZTEST-001..020**: Zenoh test messaging constraints
- **SC-MATH-COV-001..008**: Coverage math gates
- **SC-HMI-001..080**: HMI and dark cockpit constraints