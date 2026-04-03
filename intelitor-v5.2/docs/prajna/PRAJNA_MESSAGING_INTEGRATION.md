# PRAJNA MESSAGING INTEGRATION SPECIFICATION

**Version**: 1.0.0 | **Date**: 2025-12-27 | **Status**: AUTHORITATIVE
**Compliance**: SC-MSG-001 to SC-MSG-004, SC-TEL-001, SC-LOG-001

---

## Overview

PRAJNA Messaging Integration provides a unified protocol layer for all communication within the Indrajaal Security Monitoring Platform. This enables real-time bidirectional state synchronization between the 50-agent architecture and the PRAJNA Cockpit.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PRAJNA MESSAGING ARCHITECTURE                            │
│                                                                             │
│  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐                 │
│  │   ZENOH     │      │  PHOENIX    │      │    GRPC     │                 │
│  │  (C3I Mesh) │      │  (PubSub)   │      │  (Bridge)   │                 │
│  └──────┬──────┘      └──────┬──────┘      └──────┬──────┘                 │
│         │                    │                    │                         │
│         ▼                    ▼                    ▼                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │              UNIFIED MESSAGE MODEL (MessagingIntegration)           │   │
│  │                                                                      │   │
│  │  Message { Id, Timestamp, Protocol, Topic, Priority, Payload }      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│         │                    │                    │                         │
│         ▼                    ▼                    ▼                         │
│  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐                 │
│  │  FRACTAL    │      │  TELEMETRY  │      │   AUDIT     │                 │
│  │  LOGGING    │      │  DISPLAY    │      │   TRAIL     │                 │
│  └─────────────┘      └─────────────┘      └─────────────┘                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Protocol Layers

### 1.1 Zenoh (C3I Mesh Telemetry)

**Purpose**: Distributed pub/sub for real-time telemetry across the 50-agent mesh.

**Key Expressions**:
```
c3i/units/{zone}/{node}/telemetry    # Node metrics (CPU, Memory, Latency)
c3i/units/{zone}/{node}/status       # Node health status
c3i/ctrl/{zone}/{node}               # Command channel
c3i/alarms/{severity}                # Alarm events
c3i/metrics/{type}                   # Aggregated metrics
c3i/ai/insights                      # AI Copilot insights
c3i/ooda/{phase}                     # OODA cycle events
```

**Payload Format**:
```json
{
  "cpu": 45.2,
  "memory": 68.5,
  "latency": 12.3,
  "timestamp": "2025-12-27T14:32:45.123Z"
}
```

### 1.2 Phoenix PubSub (Internal Events)

**Purpose**: Real-time event distribution within the Elixir application for LiveView updates.

**Topics**:
```elixir
"prajna:metrics"     # Telemetry updates
"prajna:alarms"      # Alarm events
"prajna:commands"    # Command lifecycle
"prajna:insights"    # AI Copilot insights
"prajna:ooda"        # OODA cycle events
"prajna:containers"  # Container status
"prajna:nodes"       # Node status
"prajna:navigation"  # Navigation changes
```

**Event Types**:
```elixir
{:metric_updated, node_id, metric_type, value}
{:alarm_raised, alarm_id, level, message}
{:alarm_acknowledged, alarm_id, operator}
{:command_armed, command_id, node_id, command}
{:command_executed, command_id, result}
{:insight_generated, insight_type, content, confidence}
{:ooda_phase_changed, phase, cycle_ms}
{:container_state_changed, container_id, status}
{:node_state_changed, node_id, status}
{:navigation_changed, level, scope}
```

### 1.3 gRPC (CEPAF Bridge)

**Purpose**: Bidirectional communication between Elixir and F# components.

**Services**:
- `CepafBridge`: F# ↔ Elixir command/state sync
- `OpenRouter`: LLM integration
- `SigNoz`: Observability backend
- `Tailscale`: Mesh networking

---

## 2. Fractal Logging

### 2.1 Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        FRACTAL LOGGING HIERARCHY                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  LEVEL      SYMBOL   SEVERITY      RETENTION   USE CASE                    │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Spine      ⬤        Critical      Forever     System failures, safety     │
│  Thorax     ◉        Warning       30 days     Safety alerts, violations   │
│  Segment    ◎        Info          7 days      Operational events          │
│  Fiber      ○        Debug         24 hours    Diagnostics, troubleshoot   │
│  Gossamer   ·        Trace         1 hour      Development, detailed trace │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Usage

```elixir
# Elixir
FractalLogger.spine("Guardian", "System failure detected", %{node: "app-01"})
FractalLogger.thorax("Alarms", "High CPU alert", %{cpu: 92.5})
FractalLogger.segment("Commands", "Restart initiated", %{target: "db"})
FractalLogger.fiber("OODA", "Cycle complete", %{duration_ms: 763})
FractalLogger.gossamer("Telemetry", "Metric received", %{value: 42.0})
```

```fsharp
// F#
FractalLogging.logSpine "Guardian" "System failure detected" (Map.ofList [("node", "app-01")]) state
FractalLogging.logThorax "Alarms" "High CPU alert" (Map.ofList [("cpu", "92.5")]) state
FractalLogging.logSegment "Commands" "Restart initiated" (Map.ofList [("target", "db")]) state
FractalLogging.logFiber "OODA" "Cycle complete" (Map.ofList [("duration_ms", "763")]) state
FractalLogging.logGossamer "Telemetry" "Metric received" (Map.ofList [("value", "42.0")]) state
```

### 2.3 Display Integration

Each fractal log level maps to a display level:

| Log Level | Display Level | View |
|-----------|---------------|------|
| Spine | L0 | Critical status indicator |
| Thorax | L1 | Warning in summary |
| Segment | L2 | Operational log line |
| Fiber | L3 | Detail view entry |
| Gossamer | L4 | Raw trace data |

---

## 3. Telemetry Display

### 3.1 Metric Cards

```
┌─ CPU ────────────────────────────────────────────────────────────────────────┐
│ ● app-01  CPU: ▓▓▓▓▓▓▓░░░ 72% ↑  ▁▂▃▄▅▆▅▄▃▄▅▆▇▆▅▄▃▄▅▆                      │
│ ● app-02  CPU: ▓▓▓▓░░░░░░ 38% →  ▂▂▂▃▃▃▂▂▃▃▂▂▃▃▂▂▃▃▂▂                      │
│ ⚠ app-03  CPU: ▓▓▓▓▓▓▓▓▓░ 92% ↑↑ ▄▅▆▇▇▇▇█████████████                      │
│ ● app-04  CPU: ▓▓▓░░░░░░░ 31% ↓  ▅▄▄▃▃▃▃▂▂▂▂▂▂▂▁▁▁▁▁▁                      │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Staleness Indicators

| State | Icon | CSS | Meaning |
|-------|------|-----|---------|
| Fresh (<5s) | ● | `` | Data is current |
| Stale (5-30s) | ◐ | `opacity-60` | Data may be outdated |
| Very Stale (>30s) | ○ | `opacity-30` | Connection likely lost |

### 3.3 Trend Indicators

| Trend | Icon | Change Rate |
|-------|------|-------------|
| Rising Fast | ↑↑ | >5% increase |
| Rising | ↑ | 1-5% increase |
| Stable | → | <1% change |
| Falling | ↓ | 1-5% decrease |
| Falling Fast | ↓↓ | >5% decrease |

### 3.4 Sparklines

60-sample rolling window rendered as Unicode block characters:

```
▁▂▃▄▅▆▅▄▃▄▅▆▇▆▅▄▃▄▅▆  (20 chars, recent on right)
```

---

## 4. Implementation Files

### F# (CEPAF)

| File | Purpose |
|------|---------|
| `lib/cepaf/src/Cepaf/Cockpit/MessagingIntegration.fs` | Unified message model, Zenoh/gRPC integration |
| `lib/cepaf/src/Cepaf/Cockpit/Cockpit.fs` | Main orchestrator with messaging state |

### Elixir (Indrajaal)

| File | Purpose |
|------|---------|
| `lib/indrajaal/cockpit/prajna/messaging.ex` | Phoenix PubSub integration |
| `lib/indrajaal/observability/fractal_logger.ex` | 5-level fractal logging |
| `lib/indrajaal/cockpit/prajna/telemetry_display.ex` | Metric visualization |

---

## 5. Safety Constraints

### SC-MSG-001: Message Delivery Guarantee
**Requirement**: At-least-once delivery for all safety-critical messages.
**Implementation**: Acknowledgment with retry for Spine/Thorax level messages.

### SC-MSG-002: Message Ordering Preservation
**Requirement**: Messages within a topic maintain causal order.
**Implementation**: Timestamp-based ordering, sequence numbers for commands.

### SC-MSG-003: Protocol Failover Capability
**Requirement**: System continues operating if one protocol fails.
**Implementation**: Zenoh → PubSub → gRPC fallback chain.

### SC-MSG-004: Audit Logging for All Messages
**Requirement**: Complete audit trail for compliance.
**Implementation**: All messages logged at appropriate fractal level.

### SC-TEL-001: Telemetry Latency <100ms
**Requirement**: Display updates within 100ms of metric receipt.
**Implementation**: Direct PubSub broadcast, no queuing for telemetry.

### SC-LOG-001: Fractal Logging Hierarchy Enforcement
**Requirement**: Log entries MUST use correct fractal level.
**Implementation**: Type-safe API with level-specific functions.

---

## 6. Message Flow

### 6.1 Telemetry Flow

```
┌────────────┐     Zenoh      ┌────────────┐    PubSub    ┌────────────┐
│ Agent Node │ ─────────────→ │ Cockpit.fs │ ──────────→ │ LiveView   │
│ (Elixir)   │ c3i/units/*   │ (F#)       │ prajna:*    │ (Browser)  │
└────────────┘               └────────────┘              └────────────┘
      │                            │                           │
      │ Telemetry every 500ms      │ Parse & Enrich           │ Render
      │ {cpu, memory, latency}     │ Update State             │ <100ms
      │                            │ Log (Fiber)              │
```

### 6.2 Alarm Flow

```
┌────────────┐    Zenoh    ┌────────────┐   PubSub    ┌────────────┐
│ Sensor/    │ ──────────→ │ Messaging  │ ─────────→ │ Alarm      │
│ Detector   │ c3i/alarms  │ (Elixir)   │ prajna:    │ Center     │
└────────────┘  /warning   └────────────┘  alarms    └────────────┘
      │                          │                         │
      │ Alarm Event              │ Log (Thorax)           │ Display
      │ {level, source, msg}     │ Broadcast              │ <200ms
      │                          │ Play Sound             │
```

### 6.3 Command Flow

```
┌────────────┐   LiveView    ┌────────────┐   gRPC    ┌────────────┐
│ Operator   │ ─────────────→│ Commands   │ ────────→│ CEPAF      │
│ (Browser)  │ Arm Command  │ (Elixir)   │ Execute  │ (F#)       │
└────────────┘              └────────────┘           └────────────┘
      │                           │                        │
      │ Two-Step Commit           │ Log (Segment)         │ Zenoh
      │ Arm → Confirm             │ Audit Trail           │ c3i/ctrl
      │                           │ Timeout (5min)        │
```

---

## 7. Testing

### 7.1 Unit Tests

```bash
# Elixir
mix test test/indrajaal/cockpit/prajna/messaging_test.exs
mix test test/indrajaal/observability/fractal_logger_test.exs

# F#
dotnet test --filter "FullyQualifiedName~MessagingIntegration"
```

### 7.2 Integration Tests

```bash
# Full messaging stack
mix test test/integration/prajna_messaging_integration_test.exs
```

---

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-12-27 | Initial specification |

---

**END OF DOCUMENT**
