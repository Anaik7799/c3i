# Indrajaal Safety-Critical App Creation & Verification Protocol (SOPv5.11)

**Version**: 7.0.0-QUADPLEX-INTEGRATED
**Date**: 2025-12-22
**Classification**: SAFETY-CRITICAL / MANDATORY
**Standards Alignment**: IEC 61508 (SIL-2), ISO 26262 (ASIL-B), STAMP/STPA, FMEA, TDG, AOR
**Target Runtime**: Elixir $\ge$ 1.19, OTP $\ge$ 28, Rebar3 (Latest)
**Master Engine**: `scripts/verification/master_safety_protocol.exs`

---

## 1.0 Executive Summary

This document defines the rigorous protocols for building, verifying, and monitoring the Indrajaal application container. It now includes the **Quadplex Observability System**, ensuring that every state change and operational event is logged to four independent sinks for maximum auditability and resilience.

---

## 2.0 Quadplex Observability Integration (SC-OBS-069)

### 2.1 Failure Mode: State Amnesia
*   **Risk**: If the container crashes, in-memory logs are lost.
*   **Mitigation**: The **State Tracker** (CubDB) persists critical state changes to disk (`data/cubdb/system_state`) in real-time. This provides a "Black Box" flight recorder for post-mortem analysis.

### 2.2 Operational Requirement
All scripts and application components MUST use the `QuadplexLogger` backend. Direct use of `IO.puts` for critical information is **FORBIDDEN** (AOR-OBS-001).

---

## 3.0 The VTO Protocol (Verify-Then-Orchestrate)

[... Content remains consistent with previous versions, updated to reflect new logging ...]

### 3.1 Updated Verification Steps
1.  **Start VTO Orchestrator**: `elixir scripts/containers/vto_orchestrator.exs --action start`
2.  **Verify Logs**: Check `logs/session-*.log` for structured output.
3.  **Verify State**: Ensure `data/cubdb` is populated.

---

## 4.0 Lessons Learned (Updated)

*   **JSON Encoding**: Fixed by recursive sanitization in logger.
*   **Startup Race Conditions**: Fixed by `TelemetryMetricsWorker` and correct supervision ordering.
*   **Configuration**: Fixed by explicit `Config.config_s!` loading in test scripts.
*   **Oban Config**: Fixed by resilient `Application.get_env` defaults.

---

**Signed**: Gemini (Cybernetic Architect)
**Status**: ACTIVE PROTOCOL