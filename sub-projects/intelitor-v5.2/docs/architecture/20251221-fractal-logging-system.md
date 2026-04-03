# 🧠 FRACTAL CONTROLLABLE LOGGING: ARCHITECTURE & IMPLEMENTATION

**Version**: 2.0.0
**Date**: 2025-12-21
**Status**: ACTIVE
**Framework**: SOPv5.11 + STAMP + OODA + AEE
**Criticality**: P1 (Foundation/Production)

## 1.0 EXECUTIVE SUMMARY
The **Fractal Controllable Logging (FCL)** architecture provides a unified, self-similar control plane for all system telemetry and logging. By centralizing verbosity and sampling logic in `Indrajaal.Logging.Control`, we decouple "instrumentation" (what can be logged) from "observation" (what is logged), protecting the system from telemetry overload (Anti-Fragility) while enabling deep inspection on demand (Observability).

---

## 2.0 ARCHITECTURE (Fractal & Configurable)

### 2.1 The Fractal Control Pattern
The system is composed of nested subsystems (OODA -> Cortex -> Agents -> Infrastructure). The logging control mirrors this structure.

$$ \text{Log}(S, L) = \text{GlobalPolicy}(L) \land \text{SubsystemPolicy}(S, L) \land \text{Sampling}(S) $$

*   **Global Policy**: "Is this level allowed globally?" (e.g., enable/disable `:debug` globally).
*   **Subsystem Policy**: "Is this subsystem allowed to log at this level?" (e.g., silence `flame_runner` noise).
*   **Sampling**: "Probabilistic admission for high-volume streams." (e.g., 1 in 1000 for OODA loops).

### 2.2 Dataflow & Control Flow

**Control Flow:**
1.  **Event Source** (Business Logic/Handler) emits data.
2.  **Gatekeeper** (`TelemetryEnhancement`) consults `Indrajaal.Logging.Control`.
3.  **`Logging.Control`** reads Application Config (ETS/Env).
4.  **Decision**: `true` (emit) or `false` (suppress).

**Data Flow (If Emitted):**
1.  **Logger**: Elixir Logger processes the message.
2.  **Backends**:
    *   `:console` -> stdout (Developer visibility)
    *   `LoggerJSON` -> SigNoz (Structured observability)
    *   `OpenTelemetry` -> Spans/Traces (Performance correlation)

### 2.3 Configuration Architecture
Configuration is managed via Elixir's `config` system, allowing overrides at:
1.  **Compile Time**: `config.exs` defaults.
2.  **Boot Time**: `runtime.exs` (Environment variables).
3.  **Run Time**: `Indrajaal.Logging.Control.update/2` (Dynamic injections).

### 2.4 Fractal Component Map

| Component | Fractal Depth | Telemetry ID | Default Rate | Safety Constraint |
|-----------|---------------|--------------|--------------|-------------------|
| **Cortex** | L5 (Cognitive) | `:cortex_ooda` | 1:1000 | SC-LOG-003 |
| **Business** | L4 (Domain) | `:business_event` | 1:1 | SC-LOG-001 |
| **Security** | L3 (Protection)| `:security_event` | 1:1 (Strict)| SC-LOG-004 |
| **Infra** | L2 (Compute) | `:flame_runner` | 1:10 | - |
| **Performance**| L1 (Physics) | `:performance_metric`| 1:100 | SC-LOG-005 |

---

## 3.0 IMPLEMENTATION DETAILS (5 Levels)

### Level 1: Physics (The Code)
*   **Module**: `Indrajaal.Logging.Control`
*   **Mechanism**: `should_log?(subsystem, level)` -> Boolean
*   **Optimization**: Config cached in Application environment (read-optimized).

### Level 2: Instrumentation
*   **Hub**: `Indrajaal.Observability.TelemetryEnhancement`
*   **Handlers**:
    *   `handle_business_event`: Wraps logs.
    *   `handle_security_event`: Wraps logs, enforces SC-LOG-004.
    *   `handle_performance_event`: Samples Span creation (CPU saver).

### Level 3: Configuration
*   **File**: `config/config.exs`
*   **Structure**: nested map of subsystems with `level` and `sampling_rate`.

### Level 4: Operation (Runtime)
*   **Commands**:
    *   `Indrajaal.Logging.Control.update(:cortex_ooda, %{sampling_rate: 1})` (Enable full debug).
    *   `mix run scripts/validation/logging_control_verification.exs` (Verify integrity).

### Level 5: Cybernetic Feedback
*   **Feedback Loop**: The **OODA Loop** itself monitors log volume (future) and can auto-throttle specific subsystems via `Control.update/2` if "Context Pressure" exceeds thresholds.

---

## 4.0 USAGE GUIDE

### 4.1 Developer Workflow
**Scenario**: Debugging a specific business logic issue.
1.  Log is currently silent due to sampling.
2.  Developer runs: `iex -S mix`
3.  Execute: `Indrajaal.Logging.Control.update(:business_event, %{sampling_rate: 1, level: :debug})`
4.  Run reproduction steps.
5.  Full logs appear.

### 4.2 Production Tuning
**Scenario**: `performance_metric` flooding SigNoz.
1.  Deploy config change: `config :indrajaal, :logging_control, subsystems: %{performance_metric: %{sampling_rate: 1000}}`
2.  Or hot-patch via Remote Console: `Indrajaal.Logging.Control.update(:performance_metric, %{sampling_rate: 1000})`

---

## 5.0 NEXT STEPS (Roadmap)

### 5.1 Immediate (Current Sprint)
- [ ] Create `Indrajaal.Logging.Control` module and configuration.
- [ ] Refactor `TelemetryEnhancement` to use `Control`.
- [ ] Verify security event safety (never suppressed by accident).

### 5.2 Near Term (Verification)
- [ ] Run load test with new sampling to verify CPU reduction.
- [ ] Verify SigNoz ingestion rate drop.

### 5.3 Strategic (Autonomic)
- [ ] Connect `ResourceMonitor` to `Logging.Control` to auto-throttle logging during CPU spikes (Homeostasis).

---

*Generated by Cybernetic Architect (Gemini)*