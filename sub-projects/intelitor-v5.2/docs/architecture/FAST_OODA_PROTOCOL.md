# Fast OODA Protocol Specification

**Version**: 1.0.0
**Target Latency**: $\delta_{ooda} < 5s$ (for Agent Decisions)

## 1. Overview

The **Fast OODA Loop** minimizes the time between observing a system anomaly (e.g., test failure) and executing a corrective action. It relies on **Zenoh** for data transport and **Unicon-style GDE** for decision making.

## 2. The Loop

### Phase 1: Observe (Latency: < 10ms)
*   **Mechanism**: Zenoh Streams.
*   **Action**: Compiler/Test runner emits events to `indrajaal/logs/**`.
*   **Constraint**: No disk I/O for log analysis. Stream scanning only.

### Phase 2: Orient (Latency: < 50ms)
*   **Mechanism**: Unicon Pattern Scanners (Elixir Macros).
*   **Action**: `Indrajaal.Scanner` parses the stream for known Error Patterns (EP-###).
*   **Result**: Structured Context Object (File, Line, Error Type).

### Phase 3: Decide (Latency: < 2s)
*   **Mechanism**: Bicameral AI (Synapse).
*   **Action**:
    1.  **Gemini** validates context (is this a new error?).
    2.  **Claude** generates a fix (GDE Generator).
*   **Optimization**: If a known pattern, skip AI and apply deterministic fix (Level 1 fix).

### Phase 4: Act (Latency: < 1s)
*   **Mechanism**: CEPAF (Container Control).
*   **Action**:
    1.  Apply patch.
    2.  Hot-reload code (PHICS) or restart container (CEPAF).

## 3. Unicon Integration

The "Decide" phase is not linear; it is a **Generator**:

```elixir
# Conceptual Unicon Logic
suspend solve_error(ctx) do
  try_deterministic_fix(ctx) |
  try_claude_fix(ctx) |
  try_rollback()
end
```

## 4. Metrics

*   $\delta_{observe}$: Time from log emission to scanner receipt.
*   $\delta_{orient}$: Time to match regex/pattern.
*   $\delta_{decide}$: LLM inference time.
*   $\delta_{act}$: Compilation/Container restart time.

**Goal**: Minimize $\sum \delta$.
