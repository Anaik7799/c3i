# Zenoh Full Integration Rules
**Version**: 1.0.0 | **Status**: MANDATORY | **SOPv5.11 Compliant**

## 1.0 Integration Scope

ALL key system components MUST have:
1. **Data Plane Access** - Publish/subscribe to Zenoh topics
2. **Control Plane Access** - Receive commands via Zenoh
3. **Coordination Plane** - Barrier sync and heartbeat

## 2.0 Component Zenoh Requirements

### 2.1 Elixir System Components
| Component | Data Topics | Control Topics |
|-----------|-------------|----------------|
| Application | `app/status`, `app/metrics` | `app/control/**` |
| Cortex | `cortex/sensors/**`, `cortex/reflexes/**` | `cortex/control/**` |
| Observability | `obs/kpi/**`, `obs/logs/**` | `obs/control/**` |
| Cluster | `cluster/nodes/**`, `cluster/health` | `cluster/control/**` |
| FLAME | `flame/pools/**`, `flame/jobs/**` | `flame/control/**` |

### 2.2 CEPAF Dashboard (F#/.NET)
| Component | Data Topics | Control Topics |
|-----------|-------------|----------------|
| KPI Display | Subscribe: `*/kpi/**` | N/A |
| Commands | N/A | Publish: `*/control/**` |
| Coordinator | `cepaf/status` | `cepaf/control/**` |

### 2.3 Standalone Containers
| Container | Data Topics | Control Topics |
|-----------|-------------|----------------|
| App | `container/app/**` | `container/app/control` |
| DB | `container/db/**` | `container/db/control` |
| Obs | `container/obs/**` | `container/obs/control` |

## 3.0 STAMP Constraints

### SC-ZENOH-INT-001: Universal Access
- ALL components MUST have Zenoh publisher/subscriber capability
- Fallback to direct IPC if Zenoh unavailable

### SC-ZENOH-INT-002: Data Plane Latency
- KPI data delivery: <100ms
- Metrics data delivery: <50ms
- Log data delivery: <200ms

### SC-ZENOH-INT-003: Control Plane Authority
- Commands require authentication token
- Acknowledgment within 1s
- Timeout handling with retry

### SC-ZENOH-INT-004: Coordination Plane
- Heartbeat every 10s
- Barrier timeout: 30s
- Split-brain detection via quorum

### SC-ZENOH-INT-005: Schema Compliance
- All messages MUST be JSON
- Include timestamp, source, sequence
- Version field for compatibility

## 4.0 AOR Rules

### AOR-ZENOH-INT-001: Startup Order
1. Zenoh Coordinator starts first
2. Data plane publishers start
3. Control plane subscribers start
4. Coordination plane last

### AOR-ZENOH-INT-002: Graceful Degradation
- Component continues if Zenoh unavailable
- Log warning, retry connection
- Use local fallback

### AOR-ZENOH-INT-003: Message Ordering
- Use sequence numbers
- Detect gaps, request retransmission
- Idempotent command handlers

## 5.0 TDG Requirements

### TDG-ZENOH-INT-001: Integration Tests
- Test all data plane flows
- Test all control plane commands
- Test coordination barriers

### TDG-ZENOH-INT-002: Property Tests
```elixir
alias PropCheck.BasicTypes, as: PC
alias StreamData, as: SD

# Data plane properties
property "all kpi messages delivered" do
  forall kpi <- PC.oneof([:compilation, :tests, :containers]) do
    # verify delivery
  end
end

# Control plane properties
check all(cmd <- SD.member_of([:refresh, :mode, :agent])) do
  # verify command handling
end
```

## 6.0 Key Expression Hierarchy

```
indrajaal/
├── kpi/                    # KPI Data Plane
│   ├── compilation
│   ├── tests
│   ├── containers
│   ├── performance
│   ├── progress
│   ├── stamp
│   └── todos
├── control/                # Control Plane
│   ├── refresh
│   ├── mode
│   └── agent/**
├── coord/                  # Coordination Plane
│   ├── heartbeat
│   ├── sync
│   └── barrier/**
├── cortex/                 # Cortex Subsystem
│   ├── sensors/**
│   ├── reflexes/**
│   └── control/**
├── cluster/                # Cluster Subsystem
│   ├── nodes/**
│   ├── health
│   └── control/**
├── flame/                  # FLAME Subsystem
│   ├── pools/**
│   ├── jobs/**
│   └── control/**
└── container/              # Container Subsystem
    ├── app/**
    ├── db/**
    └── obs/**
```

## 7.0 Implementation Checklist

- [ ] ZenohKpiPublisher - Data plane for KPIs
- [ ] ZenohControlSubscriber - Control plane receiver
- [ ] ZenohCoordinator - Coordination supervisor
- [ ] ZenohCortexBridge - Cortex integration
- [ ] ZenohClusterBridge - Cluster integration
- [ ] ZenohFlameBridge - FLAME integration
- [ ] ZenohContainerBridge - Container integration

## 8.0 Verification

```bash
# Test data plane
mix test test/indrajaal/observability/zenoh_*_test.exs

# Test full integration
mix test test/integration/zenoh_full_integration_test.exs

# Verify dashboard access
./scripts/monitoring/dashboard_status.sh
```
