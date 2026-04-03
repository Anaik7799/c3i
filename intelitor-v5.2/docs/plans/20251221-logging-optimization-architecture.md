# 🧠 LOGGING OPTIMIZATION ARCHITECTURE & PLAN

**Version**: 1.0.0
**Date**: 2025-12-21
**Status**: DRAFT
**Framework**: SOPv5.11 + STAMP + OODA
**Goal**: Optimize logging for high-frequency subsystems (Cortex, OODA) to prevent telemetry overload while maintaining observability.

## 1.0 ARCHITECTURE

### 1.1 Problem Statement
The Autonomic System (Cortex/OODA) operates at millisecond latency. Default logging strategies (logging every cycle) generate excessive noise (~1000 logs/sec), flooding SigNoz and obscuring critical signals.

### 1.2 Solution: Centralized Logging Control
A new module `Indrajaal.Logging.Control` will manage logging verbosity dynamically.

```elixir
# Configuration Structure (in Application Environment)
config :indrajaal, :logging_control,
  global_level: :info,
  subsystems: %{
    cortex_ooda: %{
      level: :info,
      sampling_rate: 1000, # Log 1 in 1000 cycles
      suppress_patterns: [~r/Scale (UP|DOWN)/]
    },
    flame_runner: %{
      sampling_rate: 10
    }
  }
```

### 1.3 Components
1.  **`Indrajaal.Logging.Control`**: A GenServer or simple module (using Application env) to query logging permission.
2.  **`Indrajaal.Logging` Wrapper**: A wrapper around `Logger` that checks `Control` before emitting.
3.  **Dynamic Reconfiguration**: Ability to change sampling rates at runtime via `Indrajaal.Logging.Control.update/2`.

## 2.0 IMPLEMENTATION PLAN (5-Level)

### 2.1 - Foundation
- [ ] 2.1.1 - Define `Indrajaal.Logging.Control` struct and module.
- [ ] 2.1.2 - Add default configuration to `config/config.exs`.

### 2.2 - Integration
- [ ] 2.2.1 - Update `lib/indrajaal/cybernetic/ooda/loop.ex` to use sampling.
- [ ] 2.2.2 - Update `lib/indrajaal/flame/monitor.ex` (if exists) for sampling.

### 2.3 - Runtime Control
- [ ] 2.3.1 - Implement runtime configuration updates (enable debug mode for specific subsystems on the fly).

### 2.4 - Verification
- [ ] 2.4.1 - Verify log volume reduction.
- [ ] 2.4.2 - Ensure critical errors are NEVER suppressed.

## 3.0 SAFETY CONSTRAINTS (STAMP)

*   **SC-LOG-001**: Critical errors MUST bypass sampling and always be logged.
*   **SC-LOG-002**: Sampling rates MUST default to safe values (e.g., 100) if not configured.
*   **SC-LOG-003**: Dynamic updates MUST NOT cause system crashes (handle config missing).

## 4.0 JOURNAL
*   See `docs/journal/20251221-logging-optimization.md`.
