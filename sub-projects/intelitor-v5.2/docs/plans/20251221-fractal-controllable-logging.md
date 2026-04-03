# 🧠 FRACTAL CONTROLLABLE LOGGING ARCHITECTURE

**Version**: 1.0.0
**Date**: 2025-12-21
**Status**: DRAFT
**Framework**: SOPv5.11 + STAMP + OODA
**Goal**: Extend the `Indrajaal.Logging.Control` pattern to all runtime subsystems (Phoenix, Ecto, Oban, Business), creating a fractal, self-similar control surface for observability.

## 1.0 ARCHITECTURE

### 1.1 The Fractal Pattern
Every subsystem $S$ exposes a logging interface $L_S$ that adheres to the global control contract $C$.
$$ \forall S \in \text{Subsystems}, \text{Log}(S, m) \iff C(S, \text{Level}(m)) $$

### 1.2 Subsystem Mapping
We define specific IDs for controllable subsystems:

| Subsystem | ID | Description |
|-----------|----|-------------|
| **Phoenix** | `:phoenix_request` | HTTP requests/responses |
| **Ecto** | `:ecto_query` | Database SQL queries |
| **Oban** | `:oban_job` | Background job execution |
| **Business** | `:business_event` | High-level domain events (Alarms, Devices) |
| **Security** | `:security_event` | Auth, Rate Limits (Higher default safety) |
| **Performance**| `:performance_metric`| Raw timing data |

### 1.3 Implementation Strategy
1.  **Central Config**: Expand `config :indrajaal, :logging_control` to include these keys.
2.  **Telemetry Interception**:
    *   The `Indrajaal.Observability.TelemetryEnhancement` module already acts as a central hub for many of these.
    *   We will inject `Indrajaal.Logging.Control.should_log?/2` checks into its handler functions.
3.  **Default Loggers**:
    *   *Phase 2*: We will eventually disable default Phoenix/Ecto loggers to prevent bypassing the control plane. For now, we focus on the "Enhanced" telemetry logs.

## 2.0 IMPLEMENTATION PLAN (5-Level)

### 2.1 - Design & Config
- [ ] 2.1.1 - Define default sampling rates for all new subsystems in `config/config.exs`.
- [ ] 2.1.2 - Create `docs/plans/20251221-fractal-controllable-logging.md`.

### 2.2 - Core Refactoring
- [ ] 2.2.1 - Refactor `Indrajaal.Observability.TelemetryEnhancement`.
    - Update `handle_business_event` to check `:business_event`.
    - Update `handle_performance_event` to check `:performance_metric`.
    - Update `handle_security_event` to check `:security_event`.

### 2.3 - Runtime Extensions
- [ ] 2.3.1 - Add CLI helper `Indrajaal.Logging.Control.set_debug(:subsystem)` for easy developer access.

### 2.4 - Verification
- [ ] 2.4.1 - Verify that setting `:performance_metric` to `sampling_rate: 100` actually reduces log volume.

## 3.0 SAFETY CONSTRAINTS (STAMP)

*   **SC-LOG-004**: Security events must have a default sampling rate of 1 (Log Everything) unless explicitly overridden with high privileges.
*   **SC-LOG-005**: Control checks must be non-blocking (<10µs overhead).

## 4.0 JOURNAL
*   See `docs/journal/20251221-fractal-logging.md`.
