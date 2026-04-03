# Level 3: Component Architecture

**Version**: 1.0.0
**Date**: 2025-12-19
**C4 Model Level**: Component (Zoom into containers)
**Compliance**: SOPv5.11 + STAMP + IEC 61508 SIL-2

---

## 1. Executive Summary

This document details the internal component structure within each of the three Indrajaal containers. Level 3 zooms into the containers defined in Level 2 to reveal the major structural building blocks and their interactions.

### Component Distribution

| Container | Components | Primary Technology | Key Patterns |
|-----------|------------|-------------------|--------------|
| **indrajaal-app** | 12 major components | Elixir/OTP | Supervision trees, GenServers, Broadway |
| **indrajaal-db** | 4 components | PostgreSQL | Extensions, Replication |
| **indrajaal-obs** | 5 components | Go/ClickHouse | OTLP, Time-series |

---

## 2. Application Container Components

### 2.1 Component Overview Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         INTELITOR-APP CONTAINER                                  │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                    CYBERNETIC CONTROL LAYER                              │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │    │
│  │  │   Cortex    │  │    OODA     │  │     GDE     │  │  Framework  │     │    │
│  │  │ Controller  │◄─┤   Engine    │◄─┤   Engine    │◄─┤Orchestrator │     │    │
│  │  │             │  │             │  │             │  │             │     │    │
│  │  │ Homeostasis │  │ Observe     │  │ Hypothesize │  │ 7 Subsystem │     │    │
│  │  │ Sensors     │  │ Orient      │  │ Simulate    │  │ Coordinator │     │    │
│  │  │ Reflexes    │  │ Decide      │  │ Select      │  │             │     │    │
│  │  │             │  │ Act         │  │ Execute     │  │             │     │    │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘     │    │
│  └─────────┼────────────────┼────────────────┼────────────────┼────────────┘    │
│            │                │                │                │                  │
│            ▼                ▼                ▼                ▼                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                      COORDINATION LAYER                                  │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │    │
│  │  │    Agent    │  │    Load     │  │   Safety    │  │  Multi-Agent│     │    │
│  │  │   Manager   │  │  Balancer   │  │   Monitor   │  │ Coordinator │     │    │
│  │  │             │  │             │  │             │  │             │     │    │
│  │  │ 50 Agents   │  │ Adaptive    │  │ STAMP       │  │ Task Queue  │     │    │
│  │  │ Hierarchy   │  │ Strategy    │  │ Enforcement │  │ Consensus   │     │    │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘     │    │
│  └─────────┼────────────────┼────────────────┼────────────────┼────────────┘    │
│            │                │                │                │                  │
│            ▼                ▼                ▼                ▼                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                       DOMAIN SERVICES LAYER                              │    │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐  │    │
│  │  │  Access   │ │ Accounts  │ │  Alarms   │ │ Analytics │ │Compliance │  │    │
│  │  │  Control  │ │           │ │           │ │           │ │           │  │    │
│  │  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └─────┬─────┘  │    │
│  │        │             │             │             │             │        │    │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐  │    │
│  │  │  Devices  │ │  Sites    │ │ Visitors  │ │Guard Tours│ │Risk Mgmt  │  │    │
│  │  │           │ │           │ │           │ │           │ │           │  │    │
│  │  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └─────┬─────┘  │    │
│  │        │             │             │             │             │        │    │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │    │
│  │  │              ASH FRAMEWORK (Resource/Domain Registry)            │   │    │
│  │  │   79 Domains │ 400+ Resources │ AshPostgres │ AshJsonApi        │   │    │
│  │  └──────────────────────────────────┬──────────────────────────────┘   │    │
│  └─────────────────────────────────────┼──────────────────────────────────┘    │
│                                        │                                        │
│                                        ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                        WEB/API LAYER (Phoenix)                           │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │    │
│  │  │   Router    │  │  LiveView   │  │    REST     │  │  WebSocket  │     │    │
│  │  │  Pipelines  │  │ Components  │  │    API      │  │  Channels   │     │    │
│  │  │             │  │             │  │             │  │             │     │    │
│  │  │ Auth        │  │ Dashboard   │  │ OpenAPI 3.1 │  │ UserSocket  │     │    │
│  │  │ API         │  │ AlarmLive   │  │ Controllers │  │ MobileSocket│     │    │
│  │  │ Browser     │  │ ReportsLive │  │ JSON Views  │  │ Presence    │     │    │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘     │    │
│  └─────────┼────────────────┼────────────────┼────────────────┼────────────┘    │
│            │                │                │                │                  │
│            ▼                ▼                ▼                ▼                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                    INFRASTRUCTURE SERVICES                               │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │    │
│  │  │   FLAME     │  │  Broadway   │  │    Oban     │  │ Telemetry   │     │    │
│  │  │   Pools     │  │  Pipelines  │  │   Workers   │  │   System    │     │    │
│  │  │             │  │             │  │             │  │             │     │    │
│  │  │ Intelligence│  │ AlarmEvents │  │ Scheduled   │  │ OpenTelemetry│    │    │
│  │  │ Video       │  │ DeviceEvents│  │ Background  │  │ Metrics     │     │    │
│  │  │ Analytics   │  │ Telemetry   │  │ Maintenance │  │ Spans       │     │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘     │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Cybernetic Control Layer Components

### 3.1 Cortex Controller

The Cortex is the autonomic nervous system of Indrajaal, responsible for self-regulation and homeostasis.

```
┌─────────────────────────────────────────────────────────────────┐
│                     CORTEX CONTROLLER                            │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                      SENSORS                               │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐       │  │
│  │  │ System  │  │Container│  │  FLAME  │  │   ML    │       │  │
│  │  │ Sensor  │  │ Health  │  │ Sensor  │  │ Sensor  │       │  │
│  │  │         │  │ Sensor  │  │         │  │         │       │  │
│  │  │ CPU     │  │ Podman  │  │ Pool    │  │ Anomaly │       │  │
│  │  │ Memory  │  │ Metrics │  │ Status  │  │ Detect  │       │  │
│  │  │ Disk    │  │ Latency │  │ Scaling │  │ Predict │       │  │
│  │  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘       │  │
│  └───────┼───────────┼───────────┼───────────┼───────────────┘  │
│          │           │           │           │                   │
│          ▼           ▼           ▼           ▼                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    HOMEOSTASIS ENGINE                      │  │
│  │                                                            │  │
│  │  Stress Score Calculation: σ = Σ(wᵢ × mᵢ) / Σwᵢ          │  │
│  │  Target Range: 0.3 ≤ σ ≤ 0.6                              │  │
│  │                                                            │  │
│  │  Actions:                                                  │  │
│  │  - σ < 0.3 → Scale down, release resources                │  │
│  │  - σ > 0.6 → Scale up, activate FLAME pools               │  │
│  │  - σ > 0.8 → Emergency mode, shed non-critical load       │  │
│  └───────────────────────────────────────────────────────────┘  │
│          │                                                       │
│          ▼                                                       │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                       REFLEXES                             │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │  │
│  │  │  Circuit    │  │   Rate      │  │  Memory     │        │  │
│  │  │  Breakers   │  │  Limiters   │  │  Pressure   │        │  │
│  │  │             │  │             │  │  Response   │        │  │
│  │  │ External    │  │ API         │  │ GC Trigger  │        │  │
│  │  │ Services    │  │ Throttle    │  │ Cache Evict │        │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘        │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Location**: `lib/indrajaal/cortex/`

| Subcomponent | File | Purpose |
|--------------|------|---------|
| Controller | `controller.ex` | Main Cortex GenServer |
| Homeostasis | `homeostasis.ex` | Stress calculation and adaptation |
| SystemSensor | `sensors/system_sensor.ex` | OS metrics collection |
| ContainerHealthSensor | `sensors/container_health_sensor.ex` | Podman health checks |
| FLAMESensor | `sensors/flame_sensor.ex` | FLAME pool monitoring |
| MLSensor | `sensors/ml_sensor.ex` | Anomaly detection |
| CircuitBreaker | `reflexes/circuit_breaker.ex` | External service protection |
| RateLimiter | `reflexes/rate_limiter.ex` | Request throttling |

### 3.2 OODA Loop Engine

The OODA (Observe-Orient-Decide-Act) loop provides fast feedback cycles for adaptive decision-making.

```
┌─────────────────────────────────────────────────────────────┐
│                     OODA LOOP ENGINE                         │
│                                                              │
│     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│     │ OBSERVE │────▶│ ORIENT  │────▶│ DECIDE  │────▶│   ACT   │
│     │         │     │         │     │         │     │         │
│     │ Collect │     │ Analyze │     │ Select  │     │ Execute │
│     │ Metrics │     │ Context │     │Strategy │     │ Action  │
│     │         │     │         │     │         │     │         │
│     └────┬────┘     └────┬────┘     └────┬────┘     └────┬────┘
│          │               │               │               │
│          │               │               │               │
│          └───────────────┴───────────────┴───────────────┘
│                              │
│                         FEEDBACK
│                                                              │
│  Loop Latencies:                                             │
│  - Fast Loop (Emergency): <100ms                             │
│  - Standard Loop: <1000ms                                    │
│  - Deep Analysis Loop: <5000ms                               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Location**: `lib/indrajaal/cybernetic/ooda/`

| Phase | File | Function |
|-------|------|----------|
| Observe | `observer.ex` | Data collection from sensors |
| Orient | `orientator.ex` | Pattern analysis, threat assessment |
| Decide | `decider.ex` | Strategy selection with confidence |
| Act | `actor.ex` | Action execution via AEE tools |
| Coordinator | `ooda_coordinator.ex` | Loop orchestration |

### 3.3 GDE Engine (Goal-Directed Evolution)

GDE enables autonomous system evolution through hypothesize-simulate-select-execute cycles.

```
┌─────────────────────────────────────────────────────────────┐
│                      GDE ENGINE                              │
│                                                              │
│  ┌──────────────┐                                           │
│  │ HYPOTHESIZE  │ Generate candidate state transitions      │
│  │              │ Based on: Goals, Constraints, History     │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐                                           │
│  │  SIMULATE    │ Evaluate probability of success           │
│  │              │ P(Success | Transition, Knowledge, Ψ)     │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐                                           │
│  │   SELECT     │ ArgMax[Value(S'), Subject[Ψ]]            │
│  │              │ Where Ψ = STAMP Safety Constraints        │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐                                           │
│  │   EXECUTE    │ Perform transition via AEE tools         │
│  │              │ With rollback capability                  │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐                                           │
│  │   VERIFY     │ Check S_realized ≈ S_expected            │
│  │              │ Update knowledge base on outcome          │
│  └──────────────┘                                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Location**: `lib/indrajaal/cybernetic/gde/`

### 3.4 Framework Orchestrator

Coordinates all 7 cybernetic subsystems as defined in SOPv5.11.

**Location**: `lib/indrajaal/cybernetic/framework_orchestrator.ex`

```elixir
# 7 Cybernetic Subsystems
@subsystems [
  :goal_ingestion,      # Phase 1: Parse and validate goals
  :strategy_formulation, # Phase 2: Create execution strategy
  :execution_planning,   # Phase 3: Plan resource allocation
  :parallel_execution,   # Phase 4: Execute with agents
  :monitoring_analysis,  # Phase 5: Track and analyze
  :learning_consolidation, # Phase 6: Update knowledge
  :adaptive_optimization # Phase 7: Optimize based on feedback
]
```

---

## 4. Coordination Layer Components

### 4.1 Agent Manager

Manages the 50-agent hierarchy defined in CLAUDE.md.

```
┌─────────────────────────────────────────────────────────────┐
│                     AGENT MANAGER                            │
│                                                              │
│  Layer 1: Executive (1)                                      │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              EXECUTIVE DIRECTOR                          ││
│  │              Supreme Authority                           ││
│  └─────────────────────────┬───────────────────────────────┘│
│                            │                                 │
│  Layer 2: Domain Supervisors (10)                           │
│  ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐  │
│  │Access│Accts │Alarms│Analyt│Comms │Compli│Device│Sites │  │
│  │Ctrl  │      │      │ics   │      │ance  │s     │      │  │
│  └──┬───┴──┬───┴──┬───┴──┬───┴──┬───┴──┬───┴──┬───┴──┬───┘  │
│     │      │      │      │      │      │      │               │
│  Layer 3: Functional Supervisors (15)                        │
│  ┌────────────┬────────────┬────────────┬────────────┐       │
│  │Compilation │  Quality   │Performance │  Security  │       │
│  │Specialists │ Assurance  │  Monitors  │  Auditors  │       │
│  │    (5)     │    (5)     │    (3)     │    (2)     │       │
│  └─────┬──────┴─────┬──────┴─────┬──────┴─────┬──────┘       │
│        │            │            │            │               │
│  Layer 4: Workers (24)                                       │
│  ┌────────────┬────────────┬────────────┐                    │
│  │   File     │  Pattern   │ Continuous │                    │
│  │ Processors │Recognizers │ Validators │                    │
│  │    (8)     │    (8)     │    (8)     │                    │
│  └────────────┴────────────┴────────────┘                    │
│                                                              │
│  Total: 1 + 10 + 15 + 24 = 50 Agents                        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Location**: `lib/indrajaal/coordination/agent_manager.ex`

### 4.2 Load Balancer

Adaptive load distribution across agents and FLAME pools.

**Location**: `lib/indrajaal/coordination/load_balancer.ex`

| Strategy | Use Case | Configuration |
|----------|----------|---------------|
| Round Robin | Default distribution | `strategy: :round_robin` |
| Least Loaded | High variance workloads | `strategy: :least_loaded` |
| Weighted | Priority tasks | `strategy: :weighted` |
| Adaptive | Auto-tuning | `strategy: :adaptive` |

### 4.3 Safety Monitor

Real-time STAMP constraint enforcement.

**Location**: `lib/indrajaal/coordination/safety_monitor.ex`

```elixir
# STAMP Constraints Monitored (195 total)
@constraint_categories [
  :validation_process,    # SC-VAL-001 to SC-VAL-008
  :container_safety,      # SC-CNT-009 to SC-CNT-016
  :agent_coordination,    # SC-AGT-017 to SC-AGT-024
  :compilation_safety,    # SC-CMP-025 to SC-CMP-032
  :data_integrity,        # SC-DAT-033 to SC-DAT-040
  :security,              # SC-SEC-041 to SC-SEC-048
  :performance,           # SC-PRF-049 to SC-PRF-056
  :emergency_response,    # SC-EMR-057 to SC-EMR-064
  :observability          # SC-OBS-065 to SC-OBS-072
]
```

### 4.4 Multi-Agent Coordinator

Task distribution and consensus management.

**Location**: `lib/indrajaal/coordination/advanced_multi_agent_coordinator.ex`

---

## 5. Domain Services Layer Components

### 5.1 Ash Framework Integration

All domain models are built on Ash Framework 3.x with AshPostgres.

```
┌─────────────────────────────────────────────────────────────┐
│                    ASH FRAMEWORK CORE                        │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                   DOMAIN REGISTRY                        ││
│  │  79 Domains registered via Indrajaal.Domains            ││
│  │  400+ Resources with CRUD actions                       ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ AshPostgres │  │ AshJsonApi  │  │AshGraphql   │         │
│  │             │  │             │  │             │         │
│  │ PostgreSQL  │  │ OpenAPI 3.1 │  │ Absinthe    │         │
│  │ DataLayer   │  │ Auto-gen    │  │ Schema      │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │AshAuthentic │  │AshAuthorize │  │AshStateMach │         │
│  │             │  │             │  │             │         │
│  │ JWT/Session │  │ RBAC/ABAC   │  │ Workflow    │         │
│  │ MFA         │  │ Policies    │  │ Transitions │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Core Domain Components

| Domain | Location | Resources | Purpose |
|--------|----------|-----------|---------|
| AccessControl | `lib/indrajaal/access_control/` | AccessGrant, Permission, Role | Physical access management |
| Accounts | `lib/indrajaal/accounts/` | User, Team, Tenant | Multi-tenant user management |
| Alarms | `lib/indrajaal/alarms/` | AlarmEvent, AlarmZone, AlarmResponse | Security alarm processing |
| Analytics | `lib/indrajaal/analytics/` | Report, Dashboard, Metric | Business intelligence |
| Authentication | `lib/indrajaal/authentication/` | Session, Token, MFA | Identity verification |
| Authorization | `lib/indrajaal/authorization/` | Policy, Permission, Scope | Access control |
| Communication | `lib/indrajaal/communication/` | Notification, Message, Template | Multi-channel messaging |
| Compliance | `lib/indrajaal/compliance/` | Assessment, Framework, Control | Regulatory compliance |
| Devices | `lib/indrajaal/devices/` | Device, DeviceType, DeviceState | Physical device management |
| GuardTours | `lib/indrajaal/guard_tours/` | Tour, Checkpoint, Scan | Guard patrol management |
| Intelligence | `lib/indrajaal/intelligence/` | Prediction, Pattern, Alert | ML-based security intelligence |
| RiskManagement | `lib/indrajaal/risk_management/` | RiskAssessment, Control, Mitigation | Risk analysis |
| Sites | `lib/indrajaal/sites/` | Site, Zone, Location | Physical location hierarchy |
| Visitors | `lib/indrajaal/visitor_management/` | Visitor, Visit, Badge | Visitor tracking |

### 5.3 Domain Registration Pattern

```elixir
# lib/indrajaal/domains.ex
defmodule Indrajaal.Domains do
  @domains [
    Indrajaal.AccessControl,
    Indrajaal.Accounts,
    Indrajaal.Alarms,
    Indrajaal.Analytics,
    # ... 75 more domains
  ]

  def all, do: @domains

  def resources do
    Enum.flat_map(@domains, & &1.resources())
  end
end
```

---

## 6. Web/API Layer Components

### 6.1 Phoenix Router

```
┌─────────────────────────────────────────────────────────────┐
│                     PHOENIX ROUTER                           │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    PIPELINES                             ││
│  │  :browser → [session, csrf, layouts]                    ││
│  │  :api → [json_accept, auth_token]                       ││
│  │  :authenticated → [require_auth, audit_log]             ││
│  │  :admin → [require_admin, rate_limit]                   ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                     SCOPES                               ││
│  │                                                          ││
│  │  /                        → PageController               ││
│  │  /dashboard/*             → DashboardLive                ││
│  │  /alarms/*                → AlarmLive                    ││
│  │  /reports/*               → ReportsLive                  ││
│  │  /api/v1/*                → REST Controllers             ││
│  │  /api/json/*              → AshJsonApi (auto-generated)  ││
│  │  /api/graphql             → AshGraphql (Absinthe)        ││
│  │  /mobile/*                → MobileAPI                    ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Location**: `lib/indrajaal_web/router.ex`

### 6.2 LiveView Components

| Component | Location | Purpose |
|-----------|----------|---------|
| DashboardLive | `lib/indrajaal_web/live/dashboard_live.ex` | Real-time security dashboard |
| AlarmLive | `lib/indrajaal_web/live/alarm_live.ex` | Alarm monitoring interface |
| ReportsLive | `lib/indrajaal_web/live/reports_live.ex` | Report generation |
| DevicesLive | `lib/indrajaal_web/live/devices_live.ex` | Device management |
| UsersLive | `lib/indrajaal_web/live/users_live.ex` | User administration |

### 6.3 WebSocket Channels

```elixir
# lib/indrajaal_web/channels/user_socket.ex
defmodule IndrajaalWeb.UserSocket do
  use Phoenix.Socket

  channel "alarm:*", IndrajaalWeb.AlarmChannel
  channel "device:*", IndrajaalWeb.DeviceChannel
  channel "presence:*", IndrajaalWeb.PresenceChannel
  channel "notification:*", IndrajaalWeb.NotificationChannel
end
```

---

## 7. Infrastructure Services Components

### 7.1 FLAME Pools

Elastic compute for heavy workloads.

```
┌─────────────────────────────────────────────────────────────┐
│                      FLAME POOLS                             │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ INTELLIGENCE POOL                                        ││
│  │ - Threat Classification                                  ││
│  │ - Anomaly Detection                                      ││
│  │ - NLP Alarm Correlation                                  ││
│  │ Config: min: 0, max: 10, max_concurrency: 5             ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ VIDEO POOL                                               ││
│  │ - Object Detection                                       ││
│  │ - Motion Analysis                                        ││
│  │ - Video Transcoding                                      ││
│  │ Config: min: 0, max: 20, max_concurrency: 3             ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ ANALYTICS POOL                                           ││
│  │ - Report Generation                                      ││
│  │ - Data Aggregation                                       ││
│  │ - Batch Processing                                       ││
│  │ Config: min: 1, max: 5, max_concurrency: 10             ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Location**: `lib/indrajaal/flame/`

### 7.2 Broadway Pipelines

Event-driven data processing.

```elixir
# lib/indrajaal/broadway/alarm_pipeline.ex
defmodule Indrajaal.Broadway.AlarmPipeline do
  use Broadway

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {BroadwayRabbitMQ.Producer,
          queue: "alarm_events",
          connection: [host: "localhost"]
        },
        concurrency: 5
      ],
      processors: [
        default: [concurrency: 10]
      ],
      batchers: [
        default: [batch_size: 100, batch_timeout: 1000]
      ]
    )
  end
end
```

| Pipeline | Purpose | Throughput |
|----------|---------|------------|
| AlarmPipeline | Alarm event ingestion | 10,000/sec |
| DevicePipeline | Device telemetry | 50,000/sec |
| TelemetryPipeline | System metrics | 100,000/sec |

**Location**: `lib/indrajaal/broadway/`

### 7.3 Oban Workers

Background job processing.

```elixir
# lib/indrajaal/workers/
@oban_queues [
  default: 10,
  mailers: 20,
  reports: 5,
  maintenance: 3,
  alerts: 50,
  analytics: 10
]
```

| Queue | Workers | Purpose |
|-------|---------|---------|
| default | 10 | General background tasks |
| mailers | 20 | Email delivery |
| reports | 5 | Report generation |
| maintenance | 3 | System maintenance |
| alerts | 50 | Alert processing |
| analytics | 10 | Analytics computation |

**Location**: `lib/indrajaal/workers/`

### 7.4 Telemetry System

OpenTelemetry integration for observability.

```
┌─────────────────────────────────────────────────────────────┐
│                    TELEMETRY SYSTEM                          │
│                                                              │
│  ┌──────────────────────┐  ┌──────────────────────┐         │
│  │    :telemetry        │  │  OpenTelemetry SDK   │         │
│  │                      │  │                      │         │
│  │  Event Handlers      │─▶│  Spans               │─────┐   │
│  │  Metrics Aggregation │  │  Metrics             │     │   │
│  │  Custom Events       │  │  Traces              │     │   │
│  └──────────────────────┘  └──────────────────────┘     │   │
│                                                          │   │
│                                                          ▼   │
│  ┌──────────────────────────────────────────────────────────┐│
│  │                     OTLP EXPORTER                        ││
│  │                                                          ││
│  │  Endpoint: http://indrajaal-obs:4317 (gRPC)             ││
│  │  Protocol: OpenTelemetry Protocol                        ││
│  │  Batch Size: 512 spans                                   ││
│  │  Export Interval: 5000ms                                 ││
│  └──────────────────────────────────────────────────────────┘│
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Location**: `lib/indrajaal/observability/`

---

## 8. Database Container Components

### 8.1 Database Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                   INTELITOR-DB CONTAINER                     │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                  POSTGRESQL 17 CORE                      ││
│  │                                                          ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      ││
│  │  │   Query     │  │  Storage    │  │  WAL        │      ││
│  │  │  Planner    │  │   Engine    │  │  Manager    │      ││
│  │  │             │  │             │  │             │      ││
│  │  │ Cost-based  │  │ Heap/Index  │  │ Streaming   │      ││
│  │  │ Optimizer   │  │ MVCC        │  │ Replication │      ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘      ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                  TIMESCALEDB EXTENSION                   ││
│  │                                                          ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      ││
│  │  │ Hypertables │  │ Compression │  │ Continuous  │      ││
│  │  │             │  │             │  │ Aggregates  │      ││
│  │  │ Auto-chunk  │  │ Column-wise │  │             │      ││
│  │  │ by time     │  │ Compression │  │ Rollup      │      ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘      ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                  CONNECTION POOLING                      ││
│  │                                                          ││
│  │  PgBouncer (External) or Built-in Pool                  ││
│  │  - Pool Size: 50 connections                            ││
│  │  - Timeout: 30 seconds                                   ││
│  │  - Statement Caching: Enabled                           ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    BACKUP/RECOVERY                       ││
│  │                                                          ││
│  │  - pg_dump scheduled backups                            ││
│  │  - Point-in-time recovery via WAL archiving             ││
│  │  - Replication to standby (optional)                    ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 8.2 Database Schemas

| Schema | Purpose | Key Tables |
|--------|---------|------------|
| public | Core domain data | users, teams, tenants, sites |
| alarms | Alarm management | alarm_events, alarm_zones, alarm_responses |
| access | Access control | access_grants, access_logs, credentials |
| analytics | Time-series data | metrics, reports, dashboards |
| audit | Audit trail | audit_logs, change_history |

---

## 9. Observability Container Components

### 9.1 Observability Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                   INTELITOR-OBS CONTAINER                    │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                     SIGNOZ CORE                          ││
│  │                                                          ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      ││
│  │  │   OTLP      │  │   Query     │  │   Alert     │      ││
│  │  │  Receiver   │  │   Service   │  │   Manager   │      ││
│  │  │             │  │             │  │             │      ││
│  │  │ gRPC: 4317  │  │ HTTP: 8080  │  │ Rules       │      ││
│  │  │ HTTP: 4318  │  │ PromQL      │  │ Channels    │      ││
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘      ││
│  └─────────┼────────────────┼────────────────┼─────────────┘│
│            │                │                │               │
│            ▼                ▼                ▼               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                   CLICKHOUSE STORAGE                     ││
│  │                                                          ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      ││
│  │  │   Traces    │  │   Metrics   │  │    Logs     │      ││
│  │  │   Table     │  │   Table     │  │   Table     │      ││
│  │  │             │  │             │  │             │      ││
│  │  │ Columnar    │  │ Aggregated  │  │ Full-text   │      ││
│  │  │ Storage     │  │ MergeTree   │  │ Search      │      ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘      ││
│  │                                                          ││
│  │  Data Retention:                                         ││
│  │  - Traces: 15 days                                       ││
│  │  - Metrics: 30 days                                      ││
│  │  - Logs: 7 days                                          ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    WEB DASHBOARD                         ││
│  │                                                          ││
│  │  Port: 3301                                              ││
│  │  Features:                                               ││
│  │  - Trace visualization                                   ││
│  │  - Metric dashboards                                     ││
│  │  - Log explorer                                          ││
│  │  - Alert configuration                                   ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 10. Component Interactions

### 10.1 Request Flow Diagram

```
                           HTTP Request
                                │
                                ▼
┌───────────────────────────────────────────────────────────────┐
│                         PHOENIX                                │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    │
│  │ Router  │───▶│Plug Auth│───▶│Controller│───▶│ View    │    │
│  └─────────┘    └─────────┘    └────┬─────┘    └─────────┘    │
└────────────────────────────────────┼──────────────────────────┘
                                     │
                                     ▼
┌───────────────────────────────────────────────────────────────┐
│                      ASH FRAMEWORK                             │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    │
│  │ Action  │───▶│ Policy  │───▶│ Change  │───▶│Data Layer│   │
│  │ Dispatch│    │ Check   │    │ Validate│    │ Execute │    │
│  └─────────┘    └─────────┘    └─────────┘    └────┬─────┘    │
└────────────────────────────────────────────────────┼──────────┘
                                                     │
                                                     ▼
┌───────────────────────────────────────────────────────────────┐
│                      POSTGRESQL                                │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐                    │
│  │ Query   │───▶│ Execute │───▶│ Return  │                    │
│  │ Plan    │    │         │    │ Results │                    │
│  └─────────┘    └─────────┘    └─────────┘                    │
└───────────────────────────────────────────────────────────────┘
```

### 10.2 Telemetry Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Phoenix    │     │  Ash/Ecto    │     │   FLAME      │
│  Telemetry   │     │  Telemetry   │     │  Telemetry   │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                    │                    │
       └────────────────────┼────────────────────┘
                            │
                            ▼
                 ┌──────────────────────┐
                 │  OpenTelemetry SDK   │
                 │  (Batch Processor)   │
                 └──────────┬───────────┘
                            │
                            ▼
                 ┌──────────────────────┐
                 │   OTLP Exporter      │
                 │   gRPC: 4317         │
                 └──────────┬───────────┘
                            │
                            ▼
                 ┌──────────────────────┐
                 │   SigNoz Receiver    │
                 │   (indrajaal-obs)    │
                 └──────────────────────┘
```

---

## 11. STAMP Safety Constraints by Component

| Constraint | Component | Enforcement |
|------------|-----------|-------------|
| SC-CNT-009 | All | Container-only execution |
| SC-AGT-017 | Agent Manager | >90% efficiency |
| SC-AGT-018 | Load Balancer | No deadlocks |
| SC-VAL-003 | FPPS Validator | 5-method consensus |
| SC-FLAME-001 | FLAME Pools | No local state reliance |
| SC-CLU-001 | Cluster Sentinel | Quorum for writes |
| SC-OBS-065 | Telemetry System | Real-time metrics |

---

## 12. References

- **Level 1**: [System Context Architecture](level-1-system-context.md)
- **Level 2**: [Container Architecture](level-2-container-architecture.md)
- **Level 4**: Module Architecture (Next)
- **CLAUDE.md**: Mathematical specifications
- **Ash Framework**: https://ash-hq.org/

---

**Document Version**: 1.0.0
**Last Updated**: 2025-12-19
**Author**: Claude Opus 4.5 (Cybernetic Architect)
**Compliance**: SOPv5.11, STAMP, IEC 61508 SIL-2
