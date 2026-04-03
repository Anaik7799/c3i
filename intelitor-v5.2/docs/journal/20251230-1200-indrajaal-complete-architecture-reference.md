# Indrajaal System Architecture - Complete Building Blocks Reference

**Date**: 2025-12-30T12:00:00+01:00
**Version**: 20.0.0-GRAND-UNIFICATION
**Author**: Claude Opus 4.5 (Cybernetic Architect)
**Status**: COMPREHENSIVE REFERENCE

---

## Executive Summary

**Indrajaal v20.0.0 Grand Unification** is a safety-critical, cybernetically-controlled security management platform built on a **Fractal Holonic Architecture**. The system comprises:

- **50 Autonomous Agents** (1 Executive, 10 Domain, 15 Functional, 24 Workers)
- **3 Production Containers** (App, DB, Observability)
- **5 VSM Systems** implementing Stafford Beer's Viable System Model
- **7 Fractal Layers** (Function → Module → Agent → Container → Node → Cluster → Federation)
- **445 STAMP Safety Constraints** verified across all layers

---

## 1. INDRAJAAL CORE SYSTEM

### 1.1 Ash Domain Architecture (10+ Business Domains)

| Domain | Resources | Purpose |
|--------|-----------|---------|
| **Accounts** | User, Team, Session, Token, Role, Permission | Enterprise account management with RBAC, MFA |
| **Access Control** | AccessRule, AccessMatrix, Policy | RBAC/ABAC engine (<15ms decisions) |
| **Alarms** | AlarmEvent, IncidentType, Response, Notification | Security intelligence, real-time processing (<50ms) |
| **Analytics** | 30+ modules (Anomaly, Predictive, ML) | Real-time BI, predictive modeling |
| **Authentication** | JWT, MFA, Session, TokenRevocationCache | Identity provider integration (MS Entra ID) |
| **Authorization** | Role, Permission, AuthorizationLog | Policy-based access control (<5ms) |
| **Compliance** | Requirement, Framework, AuditReport | IEC 61508, ISO 27001, GDPR tracking |
| **Devices** | Device, Panel, Reader, Sensor, Camera | Physical security device management |
| **Sites** | Site, Building, Floor, Zone, Area | Physical location hierarchy |
| **Billing** | Plan, Subscription, Payment, Invoice | SaaS billing engine |

**Additional Domains**: Visitor Management, Dispatch, Video, Risk, Assets, Guard Tours, Communication, Shifts, Integration, AI/ML

---

### 1.2 Agent Mesh Architecture (50 Agents)

```
┌─────────────────────────────────────────────────────────────┐
│                    EXECUTIVE AGENT (1)                       │
│              Supreme Authority (AOR-EXE-001)                 │
├─────────────────────────────────────────────────────────────┤
│                   DOMAIN AGENTS (10)                         │
│  Access │ Accounts │ Alarms │ Analytics │ Authentication    │
│  Authorization │ Compliance │ Devices │ Observability │ Sites│
├─────────────────────────────────────────────────────────────┤
│                  FUNCTIONAL AGENTS (15)                      │
│  OODA │ ACE │ Cortex │ Fractal │ CEPAF │ Sentinel │ KPI    │
│  GDE │ Guardian │ Homeostasis │ Evolution │ ...             │
├─────────────────────────────────────────────────────────────┤
│                   WORKER AGENTS (24)                         │
│  FLAME │ Oban │ Broadway │ Batch │ Container │ ...          │
└─────────────────────────────────────────────────────────────┘
```

**Core 7-Agent Mesh:**

| Agent | Role | Constraint |
|-------|------|------------|
| **OODA Controller** | Observe→Orient→Decide→Act cycle | <100ms cycle time |
| **ACE** | Autonomic Computing (MAPE-K loop) | Self-healing, self-optimization |
| **Cortex** | Cognitive controller, stress analysis | 50ms reflexes |
| **Fractal Logger** | 5-level distributed logging | Async, HLC timestamps |
| **CEPAF Bridge** | Container operations (Elixir↔F#) | Rootless Podman |
| **Sentinel** | Cluster health, quorum management | 5s heartbeat, 3-node minimum |
| **KPI Dashboard** | Real-time progress tracking | 30s refresh |

---

### 1.3 Viable System Model (VSM) - 5 Systems

```
┌─────────────────────────────────────────────────────────────┐
│  S5 POLICY - The Identity                                    │
│  Constitution verification, strategic decisions, invariants  │
├─────────────────────────────────────────────────────────────┤
│  S4 INTELLIGENCE - The Future                                │
│  Monte Carlo planning, trend analysis, predictions           │
├─────────────────────────────────────────────────────────────┤
│  S3 CONTROL - The Guard                                      │
│  Resource budgets (CPU/Memory/Network), throttling           │
├─────────────────────────────────────────────────────────────┤
│  S2 COORDINATION - The Balancing                             │
│  Anti-oscillation gossip, hysteresis, dampening              │
├─────────────────────────────────────────────────────────────┤
│  S1 OPERATIONS - The Doing                                   │
│  Business logic execution, request processing                │
└─────────────────────────────────────────────────────────────┘
```

---

### 1.4 OODA Cybernetic Loop

```
        ┌──────────────────────────────────────────┐
        │           OODA CYCLE (<100ms)            │
        │                                          │
        │  OBSERVE ──→ ORIENT ──→ DECIDE ──→ ACT  │
        │     ↑                              │     │
        │     └──────── FEEDBACK ←───────────┘     │
        └──────────────────────────────────────────┘

FastOODA: 50ms cycle for CAE (Cybernetic Autonomous Execution)
```

**Unified Control Bus**: Couples OODA, FastOODA, ACE, Homeostasis, GDE loops
- Async messaging only
- Circuit breaker at 1000 events/sec
- FIFO event ordering

---

### 1.5 Safety Systems (STAMP)

| Component | Purpose | Constraint |
|-----------|---------|------------|
| **Guardian** | SIL-2 certified safety kernel | No dynamic dispatch, deterministic |
| **Dead Man's Switch** | Heartbeat monitor | <5s halt on loss |
| **Safety Envelope** | Immutable constraints | Resource/actuator limits |
| **STAMP Registry** | 445 constraints | 7 fractal layers |
| **Incident Coordinator** | Violation response | Escalation, recovery |

**7 Constitutional Invariants (Ω₁-Ω₇):**
1. Patient Mode (never interrupt)
2. Container Isolation (NixOS/Podman only)
3. Zero-Defect (all metrics ≡ 0)
4. TDG (tests before code)
5. FPPS Consensus (5-method agreement)
6. Mandatory Gates (all gates pass)
7. Non-Aggression (human safety first)

---

## 2. PRAJNA C3I COCKPIT

### 2.1 Architecture Overview

**PRAJNA** = Prajna Recognition And Jidoka Network for AI (Sanskrit: "transcendental wisdom")

```
┌─────────────────────────────────────────────────────────────┐
│                    PRAJNA C3I COCKPIT                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ AI COPILOT  │  │DARK COCKPIT │  │   SALIENCE  │         │
│  │  (LLM+Local)│  │(NASA-STD)   │  │  (d-prime)  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │SMART METRICS│  │ ORCHESTRATOR│  │  MESSAGING  │         │
│  │  (ETS-backed)│  │(State Machine)│  │  (PubSub)   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
├─────────────────────────────────────────────────────────────┤
│                   12 LIVEVIEW SCREENS                        │
│  Copilot│Alarms│Mesh│Commands│Containers│Observability     │
│  Cluster│Diagnostics│Settings│Startup│Shutdown│Canvas      │
└─────────────────────────────────────────────────────────────┘
```

---

### 2.2 Core Components

| Component | File | Purpose |
|-----------|------|---------|
| **AI Copilot** | `ai_copilot.ex` | Local analytics + LLM enhancement (human-in-loop) |
| **Dark Cockpit** | `dark_cockpit.ex` | NASA-STD-3000 terminal UI (management by exception) |
| **Smart Metrics** | `smart_metrics.ex` | Real-time ETS-backed metrics with sparklines |
| **Salience** | `salience.ex` | Signal detection theory scoring (0-100) |
| **Orchestrator** | `orchestrator.ex` | Main state machine, two-step commit |
| **Domain Types** | `domain.ex` | Type-safe domain models |

---

### 2.3 Dark Cockpit Principles (13 Laux/Wickens)

| Principle | Implementation |
|-----------|----------------|
| **Management by Exception** | Gray backgrounds, color only for abnormal |
| **Analog over Digital** | Sparklines ▁▂▃▄▅▆▇█, progress bars |
| **Trend Vectors** | ↑↑/↑/→/↓/↓↓ on every metric |
| **Staleness Decay** | Visual opacity: 100%→60%→30% |
| **Two-Step Commit** | ◎(armed)→●(executing)→✓(confirmed) |
| **Salience Filtering** | Score 0-100 with treatment mapping |
| **Redundancy Gain** | Visual + audio bell for alerts |
| **Common Operational Picture** | Standardized COP header |

**Salience Treatment Thresholds:**
- 0-20: Suppressed (log only)
- 21-50: Background (dim)
- 51-80: Foreground (popup)
- 81-99: Alert (visual + audio)
- 100: Emergency (blink + bell)

---

### 2.4 AI Copilot Architecture

```
┌─────────────────────────────────────────────────────────────┐
│               AI COPILOT (SC-AI-001: Human-in-Loop)          │
├─────────────────────────────────────────────────────────────┤
│  LOCAL ANALYTICS (Always On)                                 │
│  ├─ Heuristic anomaly detection                             │
│  ├─ Trend-based predictions                                 │
│  └─ Pattern correlation                                     │
│                    ↓                                         │
│  LLM ENHANCEMENT (Optional - OpenRouter)                    │
│  ├─ Deep analysis (Claude 3.5)                              │
│  ├─ Natural language explanations                           │
│  └─ Root cause analysis                                     │
│                    ↓                                         │
│  INSIGHT AGGREGATOR                                         │
│  ├─ Merge + deduplicate                                     │
│  ├─ Confidence scoring                                      │
│  └─ TTL management (5 min)                                  │
└─────────────────────────────────────────────────────────────┘
```

**Insight Types**: Anomaly, Prediction, Recommendation, Correlation, Root_Cause, Summary

---

### 2.5 Material 3 Theming

**Three Theme Variants:**

| Theme | Surface | Content | Use Case |
|-------|---------|---------|----------|
| **Light** | #ffffff | #18181b | Day operations |
| **Dark** | #111827 | #f3f4f6 | NASA-STD-3000 Dark Cockpit |
| **High Contrast** | #000000 | #ffffff | Accessibility (SC-HMI-008) |

**Status Colors (Consistent Across Themes):**
- Healthy: #22c55e (green)
- Advisory: #06b6d4 (cyan)
- Caution: #f59e0b (amber)
- Warning: #ef4444 (red)
- Critical: #dc2626 (blinking)

---

## 3. FRACTAL KNOWLEDGE MANAGEMENT SYSTEM

### 3.1 Fractal Logging (7 Levels)

```
┌─────────────────────────────────────────────────────────────┐
│                   FRACTAL LOGGING HIERARCHY                  │
├─────────────────────────────────────────────────────────────┤
│  L7 Universe   │ All federated systems                      │
│  L6 Federation │ Multi-cluster coordination                 │
│  L5 Cluster    │ Node health, cluster events (SIEM)        │
│  L4 Node       │ System metrics, container health          │
│  L3 Agent      │ Business flows, trace IDs (PostgreSQL)    │
│  L2 Module     │ GenServer state, ETS lookups (1% sample)  │
│  L1 Function   │ Function args, hex dumps (0% - dropped)   │
└─────────────────────────────────────────────────────────────┘
```

**Backend Routing by Level:**
| Level | Backends | Retention |
|-------|----------|-----------|
| L1 | memory, otlp, zenoh | 1 hour |
| L2 | wal, otlp, zenoh | 1 day |
| L3 | postgresql, otlp, zenoh | 30 days |
| L4 | postgresql, signoz, zenoh | 1 year |
| L5 | postgresql, signoz, siem, blockchain | 10 years |

---

### 3.2 Hybrid Logical Clock (HLC)

```
HLC = (Physical, Logical)
├── Physical: Unix microseconds (48 bits)
├── Counter: Logical counter (16 bits, max 65,535)
└── Binary encoding: 10 bytes

Ordering: hlc₁ < hlc₂ ⟺
  physical(hlc₁) < physical(hlc₂) ∨
  (physical(hlc₁) = physical(hlc₂) ∧ logical(hlc₁) < logical(hlc₂))
```

**FQUN (Fully-Qualified Unique Names):**
```
intelitor/<layer>/<type>/<namespace>/<name>@<node>#<instance>
Example: intelitor/agent/domain/cybernetic/ooda_controller@indrajaal-app.ts.net#01HWXYZ123
```

---

### 3.3 Zenoh Mesh Networking

```
┌─────────────────────────────────────────────────────────────┐
│                    ZENOH 7-PLANE MESH                        │
├─────────────────────────────────────────────────────────────┤
│  Plane      │ Publisher              │ Latency │ Purpose    │
│─────────────┼────────────────────────┼─────────┼────────────│
│  Fractal    │ ZenohFractalPublisher  │ <1ms    │ Log stream │
│  Data       │ ZenohKpiPublisher      │ <10ms   │ KPI metrics│
│  Control    │ ZenohControlSubscriber │ <5ms    │ Commands   │
│  Telemetry  │ ZenohTelemetrySubscr   │ <1ms    │ F# sink    │
│  Evolution  │ ZenohEvolutionPublisher│ <100ms  │ Shadow test│
│  Heartbeat  │ Heartbeat Worker       │ <1s     │ Status     │
│  Native     │ Rust NIF               │ <1ms    │ Direct API │
└─────────────────────────────────────────────────────────────┘
```

**Key Expression Schema:**
```
intelitor/{level}/{domain}/{event_type}
Examples:
  intelitor/fractal/l3/alarms/state_change
  intelitor/kpi/compilation
  intelitor/control/fractal/boost
```

---

### 3.4 Fractal Observability Components

| Component | Purpose |
|-----------|---------|
| **FractalControl** | Central ETS state, O(1) level checking |
| **ContentRouter** | Intelligent multi-backend routing |
| **BatchEncoder** | Delta encoding, 70% wire savings |
| **PIIMasker** | GDPR compliance (email, CC, phone, SSN) |
| **WriteFilter** | Bloom filter deduplication |
| **OTELIntegration** | OpenTelemetry span creation |
| **CyberneticController** | Autonomous level adjustment |

---

## 4. CEPAF F# INFRASTRUCTURE

### 4.1 Project Structure

```
lib/cepaf/
├── src/
│   ├── Cepaf/                    # Main framework (100+ modules)
│   │   ├── Core/                 # Category theory abstractions
│   │   ├── Cockpit/              # TUI components
│   │   ├── Modules/              # Safety, AOR, TDG
│   │   ├── Observability/        # Quadplex logger, Fractal
│   │   ├── Phases/               # Build, Test, Verify phases
│   │   └── Zenoh/                # Pub/sub integration
│   ├── Cepaf.Podman/             # Container management API
│   └── Cepaf.Bridge/             # Elixir-F# interop
├── test/
│   ├── Cepaf.Tests/              # Framework tests
│   └── Cepaf.IndrajaalTest/      # Integration tests (75+ scenarios)
└── scripts/                       # Deployment & operations
```

---

### 4.2 Core F# Modules

| Module | Purpose |
|--------|---------|
| **Domain.fs** | Core types (AppError, Environment, ProcessResult) |
| **Rop.fs** | Railway-Oriented Programming (AsyncResult) |
| **OodaController.fs** | OODA loop implementation |
| **SafetyConstraints.fs** | Emergency stop, latency limits |
| **AOREngine.fs** | Agent Operating Rules enforcement |
| **ChainVerifier.fs** | FPPS 5-method consensus |
| **TDGHarness.fs** | Test-Driven Generation enforcement |

**Category Theory Foundations:**
- `Arrows.fs` - Arrow combinators
- `Comonads.fs` - UI state management
- `RecursionSchemes.fs` - Catamorphisms, anamorphisms
- `StateMachine.fs` - Type-safe state machines
- `TaglessFinal.fs` - Free monad abstractions

---

### 4.3 Podman Container Management

```
┌─────────────────────────────────────────────────────────────┐
│               CEPAF.PODMAN ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────┤
│  UnixSocket.fs ──→ HttpClient.fs ──→ API Modules            │
│       ↓                                                      │
│  /run/user/{UID}/podman/podman.sock (rootless)              │
├─────────────────────────────────────────────────────────────┤
│  API Modules:                                                │
│  ├── Containers.fs (list, create, start, stop, exec, logs)  │
│  ├── Images.fs (build, pull, push, prune)                   │
│  ├── Networks.fs (create, inspect)                          │
│  ├── Volumes.fs (create, remove)                            │
│  └── Health/Probes.fs (startup, liveness, readiness)        │
└─────────────────────────────────────────────────────────────┘
```

---

### 4.4 Quadplex Logger (4-Channel)

```
┌─────────────────────────────────────────────────────────────┐
│                  QUADPLEX LOGGER                             │
├─────────────────────────────────────────────────────────────┤
│  Channel 1: CONSOLE    │ ANSI-colored terminal output       │
│  Channel 2: FILE       │ Rotating log files                 │
│  Channel 3: TELEMETRY  │ OpenTelemetry export (Grafana)     │
│  Channel 4: STATE      │ SQLite event persistence           │
└─────────────────────────────────────────────────────────────┘
```

---

### 4.5 Cockpit TUI (Material 3)

| Component | Purpose |
|-----------|---------|
| **Material3.fs** | Design tokens, ANSI codes, typography |
| **Dashboard.fs** | Full-screen metrics visualization |
| **DarkCockpitUI.fs** | Dark theme variant |
| **C3IMultiAgent.fs** | Command & Control interface |
| **Prajna.fs** | AI-assisted decisions |
| **AiCopilot.fs** | OpenRouter Claude integration |
| **TelemetryStreams.fs** | Real-time metric streaming |

---

## 5. HOLON BIO-INSPIRED ARCHITECTURE

### 5.1 Holon Lifecycle (Biological Metaphor)

```
┌─────────────────────────────────────────────────────────────┐
│                    HOLON LIFECYCLE                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│    SPAWN ──→ ACTIVE ──→ HEALING ──┬──→ MITOSIS (scale)      │
│     ↑          │          │       │                          │
│     │          ↓          ↓       └──→ APOPTOSIS (death)    │
│     └──────────┴──────────┘                                  │
│                                                              │
│  vital_signs()  - Health/stress/energy indices (0.0-1.0)    │
│  health_check() - Comprehensive audit (<10ms)               │
│  self_heal()    - Autonomous recovery (max 3 retries)       │
│  mitosis()      - Cell division (30% energy cost)           │
│  apoptosis()    - Graceful shutdown with cascade            │
└─────────────────────────────────────────────────────────────┘
```

---

### 5.2 Three-Layer Bio Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    NEURO LAYER (Spine)                       │
│  L1 Reflex (heuristics) → L2 Local ML → L3 Cortex (LLM)    │
├─────────────────────────────────────────────────────────────┤
│                   IMMUNE LAYER                               │
│  Antibody (threat detection) + Mara (chaos testing)         │
├─────────────────────────────────────────────────────────────┤
│                    BIO LAYER                                 │
│  Vital Signs + Membrane + Autopoiesis + Homeostasis         │
└─────────────────────────────────────────────────────────────┘
```

| Layer | Component | Purpose |
|-------|-----------|---------|
| **Bio** | Vital Signs | CPU/Memory/IO/Latency health (0.0-1.0) |
| **Bio** | Membrane | Protection boundary, rate limiting |
| **Immune** | Antibody | Threat detection (Search→Bind→Opsonize→Die) |
| **Immune** | Mara | Red team chaos testing (10s cadence) |
| **Neuro** | Spine | 3-level decision routing (reflex→ML→LLM) |

---

### 5.3 Health Propagation

```
┌─────────────────────────────────────────────────────────────┐
│               BOTTOM-UP HEALTH FLOW                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Child-1 (healthy)  ──┐                                     │
│  Child-2 (degraded) ──┼──→ Parent (degraded) ──→ Grandparent│
│  Child-3 (healthy)  ──┘                                     │
│                                                              │
│  Rules:                                                      │
│  ├── All healthy → :healthy                                 │
│  ├── Any degraded (none critical/failed) → :degraded        │
│  ├── Any critical (none failed) → :critical                 │
│  └── Any failed → :failed                                   │
│                                                              │
│  Hysteresis: Recovery requires 3 consecutive good checks    │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. CONTAINER DEPLOYMENT

### 6.1 3-Container Production Architecture

| Container | Ports | Services |
|-----------|-------|----------|
| **indrajaal-db-prod** | 5433 | PostgreSQL 17 + TimescaleDB |
| **indrajaal-obs-prod** | 4317/4318, 9090, 3000, 3100 | OTEL + Prometheus + Grafana + Loki |
| **indrajaal-app-prod** | 4000, 4001, 6379 | Phoenix + FLAME + Redis |

### 6.2 Access Points

| Service | URL | Notes |
|---------|-----|-------|
| Phoenix | http://localhost:4000 | Main application |
| Health | http://localhost:4001/health | Health endpoint |
| Prajna | http://localhost:4000/prajna | C3I Cockpit |
| Copilot | http://localhost:4000/prajna/copilot | AI Assistant |
| Grafana | http://localhost:3000 | admin/indrajaal |
| Prometheus | http://localhost:9090 | Metrics |

---

## 7. PERFORMANCE TARGETS

| Metric | Target | Constraint |
|--------|--------|------------|
| OODA Cycle | <100ms | SC-OODA-001 |
| FastOODA Cycle | 50ms | CAE mode |
| Access Control | <15ms | SC-AUTH |
| Safety Checks | <1ms | SC-VAL |
| Agent Response | 100ms SLA | SC-AGT |
| PHICS Latency | <50ms | SC-CNT |
| Health Report | <100ms | SC-HOL-003 |
| Emergency Stop | <5s | SC-EMR-057 |

---

## 8. COMPLIANCE

| Standard | Status |
|----------|--------|
| IEC 61508 SIL-2 | Certified |
| ISO 27001 | Compliant |
| GDPR | Compliant |
| EN 50131 | Compliant |
| NASA-STD-3000 | Dark Cockpit |
| NUREG-0700 | HMI Guidelines |

---

## 9. KEY FILE LOCATIONS

### 9.1 Indrajaal Core
- `lib/indrajaal/` - Main Elixir application
- `lib/indrajaal/core/holon/` - Holon implementation
- `lib/indrajaal/core/vsm/` - VSM systems (S1-S5)
- `lib/indrajaal/core/constitution/` - Safety invariants
- `lib/indrajaal/distributed/` - Agent mesh
- `lib/indrajaal/safety/` - Guardian, STAMP
- `lib/indrajaal/cortex/` - Cognitive subsystem
- `lib/indrajaal/cybernetic/` - OODA, CAE

### 9.2 Prajna Cockpit
- `lib/indrajaal/cockpit/prajna/` - Core cockpit modules
- `lib/indrajaal_web/live/prajna/` - LiveView interfaces
- `lib/indrajaal/cockpit/prajna/bio/` - Bio layer
- `lib/indrajaal/cockpit/prajna/immune/` - Immune layer
- `lib/indrajaal/cockpit/prajna/neuro/` - Neuro layer

### 9.3 Fractal Observability
- `lib/indrajaal/observability/fractal/` - Fractal logging
- `lib/indrajaal/observability/zenoh_*.ex` - Zenoh integration
- `lib/indrajaal/distributed/fqun.ex` - FQUN naming

### 9.4 CEPAF Infrastructure
- `lib/cepaf/src/Cepaf/` - F# framework
- `lib/cepaf/src/Cepaf.Podman/` - Container API
- `lib/cepaf/scripts/` - Deployment scripts
- `lib/cepaf/artifacts/` - Compose files

---

## 10. STAMP CONSTRAINT CATEGORIES

| Category | ID Range | Examples |
|----------|----------|----------|
| Validation | SC-VAL-* | Patient mode, consensus, completeness |
| Container | SC-CNT-* | NixOS/Podman only, localhost registry |
| Agent | SC-AGT-* | Efficiency >90%, no deadlocks |
| Compilation | SC-CMP-* | 0 warnings, all 773 files |
| Security | SC-SEC-* | Sobelow, encryption |
| Performance | SC-PRF-* | <50ms response, no blocking |
| Emergency | SC-EMR-* | Stop <5s, rollback capability |
| Observability | SC-OBS-* | Dual logging, 4 OTEL modules |
| Holon | SC-HOL-* | VSM implementation, health propagation |
| Bio | SC-BIO-* | Vital signs, membrane protection |

---

*This document represents the complete architectural reference for Indrajaal v20.0.0 Grand Unification, covering all major subsystems, safety constraints, and operational components.*

---

**Generated**: 2025-12-30T12:00:00+01:00
**Framework**: SOPv5.11 + STAMP + TDG + Fractal Holonic Architecture
