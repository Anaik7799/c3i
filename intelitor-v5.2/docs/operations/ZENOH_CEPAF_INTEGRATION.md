# Zenoh-CEPAF Integration Specification
**Version**: 1.0.0 | **Status**: ACTIVE | **SOPv5.11 Compliant**

## 1.0 Overview

Zenoh pub/sub messaging coordinates data and control flow between:
- CEPAF Dashboard (F#/.NET)
- Elixir system components
- Claude development operations

## 2.0 Zenoh Key Expression Patterns

### KPI Data Flow (Elixir -> Dashboard)
```
indrajaal/kpi/compilation     # Compilation metrics
indrajaal/kpi/tests           # Test results
indrajaal/kpi/containers      # Container health
indrajaal/kpi/performance     # Artillery metrics
indrajaal/kpi/security        # Sobelow findings
indrajaal/kpi/progress        # C1-C4 percentages
indrajaal/kpi/stamp           # STAMP constraints
indrajaal/kpi/todos           # Session todos
indrajaal/kpi/agents          # Agent status
```

### Control Flow (Dashboard -> Elixir)
```
indrajaal/control/refresh     # Force KPI refresh
indrajaal/control/agent/**    # Agent commands
indrajaal/control/mode        # Dashboard mode
```

### Coordination Flow (Bidirectional)
```
indrajaal/coord/heartbeat     # Liveness check
indrajaal/coord/sync          # State synchronization
indrajaal/coord/barrier/**    # Barrier synchronization
```

## 3.0 STAMP Constraints

### SC-ZENOH-001: Message Delivery
- All KPI messages MUST be delivered within 100ms
- Timeout handling for slow subscribers

### SC-ZENOH-002: Pattern Matching
- Key expressions MUST follow Zenoh glob patterns
- Wildcard usage: `*` single segment, `**` multi-segment

### SC-ZENOH-003: Data Freshness
- KPI data MUST include timestamp
- Stale data (>60s) flagged for dashboard

### SC-ZENOH-004: Control Authority
- CEPAF commands require acknowledgment
- Agent commands use request-reply pattern

## 4.0 AOR Rules

### AOR-ZENOH-001: Publisher Lifecycle
- KPI publishers start with dashboard
- Auto-reconnect on disconnection

### AOR-ZENOH-002: Subscriber Durability
- Control subscribers persist across refresh
- Message buffer for offline periods

### AOR-ZENOH-003: Barrier Coordination
- Multi-agent barriers use Zenoh coordination
- Timeout after 30s with fallback

## 5.0 TDG Integration

- ZenohTestCoordinator available at test/support/zenoh_test_coordinator.ex
- Tests use Zenoh patterns for multi-process coordination
- PropCheck/StreamData with PC/SD aliases per SC-PROP-023/024

## 6.0 Architecture

```
┌─────────────────┐     Zenoh Pub/Sub      ┌─────────────────┐
│  CEPAF Dashboard│◄────────────────────────►│ Elixir System   │
│  (F#/.NET)      │  indrajaal/kpi/**       │ Components      │
└────────┬────────┘  indrajaal/control/**   └────────┬────────┘
         │                                           │
         │ indrajaal/coord/**                        │
         └───────────────┬───────────────────────────┘
                         │
                  ┌──────▼──────┐
                  │ Claude Dev  │
                  │ Operations  │
                  └─────────────┘
```

## 7.0 Implementation Files

1. `lib/indrajaal/observability/zenoh_kpi_publisher.ex`
2. `lib/indrajaal/observability/zenoh_control_subscriber.ex`
3. `lib/indrajaal/observability/zenoh_coordinator.ex`
4. `test/indrajaal/observability/zenoh_integration_test.exs`
