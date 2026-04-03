# Level 1: System Context Architecture

**Document Version**: 1.0.0
**Date**: 2025-12-19
**Classification**: C4 Model - Level 1 (System Context)
**Framework**: SOPv5.11 + STAMP + TDG + Cybernetic

---

## 1. Executive Summary

Indrajaal is an enterprise-grade physical security management system designed for multi-tenant alarm monitoring, access control, and security intelligence. The system implements a **Cybernetic Architect Framework** with autonomous control loops, safety-critical compliance (IEC 61508 SIL-2), and distributed execution capabilities.

### Key Characteristics

| Characteristic | Value |
|----------------|-------|
| Architecture Style | Domain-Driven Design (DDD) with Cybernetic Control |
| Domains | 79 business domains organized in 11 tiers |
| Source Files | 1,508+ Elixir modules |
| Test Coverage | 1,005 test files with dual property-based testing |
| Safety Constraints | 195 STAMP safety constraints |
| Agent Architecture | 175 autonomous agents (5 Supervisor + 20 Helper + 100 Worker + 50 Specialist) |

---

## 2. System Context Diagram

```
                                    ┌──────────────────────────────────────────────────────────────┐
                                    │                    EXTERNAL SYSTEMS                           │
                                    └──────────────────────────────────────────────────────────────┘
                                                              │
         ┌────────────────────────────────────────────────────┼────────────────────────────────────────────────────┐
         │                                                    │                                                    │
         ▼                                                    ▼                                                    ▼
┌─────────────────┐                                 ┌─────────────────┐                                 ┌─────────────────┐
│   ALARM PANELS  │                                 │  ACCESS CONTROL │                                 │   VIDEO/NVR     │
│   (SIA DC-07)   │                                 │    DEVICES      │                                 │   SYSTEMS       │
│                 │                                 │                 │                                 │                 │
│ • Intrusion     │                                 │ • Readers       │                                 │ • IP Cameras    │
│ • Fire          │                                 │ • Controllers   │                                 │ • DVR/NVR       │
│ • Medical       │                                 │ • Locks         │                                 │ • Analytics     │
└────────┬────────┘                                 └────────┬────────┘                                 └────────┬────────┘
         │                                                    │                                                    │
         │              ┌─────────────────────────────────────┴─────────────────────────────────────┐              │
         │              │                                                                           │              │
         ▼              ▼                                                                           ▼              ▼
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                                      │
│                                          INTELITOR SECURITY PLATFORM                                                 │
│                                                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                                          CYBERNETIC CONTROL LAYER                                               │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │ │
│  │  │ OODA Loop    │  │   Cortex     │  │   STAMP      │  │    TPS       │  │    GDE       │  │   FLAME      │    │ │
│  │  │ <100ms cycle │  │ Homeostasis  │  │ 195 Safety   │  │ 5-Level RCA  │  │ Goal-Driven  │  │ Distributed  │    │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │ │
│  └─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                                              DOMAIN LAYER                                                       │ │
│  │                                                                                                                 │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐              │ │
│  │  │   ALARMS    │ │   ACCESS    │ │  ACCOUNTS   │ │   DEVICES   │ │   SITES     │ │ ANALYTICS   │              │ │
│  │  │             │ │  CONTROL    │ │             │ │             │ │             │ │             │              │ │
│  │  │ Processing  │ │ Grants      │ │ Users       │ │ Panels      │ │ Locations   │ │ ML/BI       │              │ │
│  │  │ Correlation │ │ Schedules   │ │ Teams       │ │ Zones       │ │ Areas       │ │ Prediction  │              │ │
│  │  │ Response    │ │ RBAC        │ │ Tenants     │ │ Sensors     │ │ Floors      │ │ Dashboards  │              │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘              │ │
│  │                                                                                                                 │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐              │ │
│  │  │  VISITORS   │ │   GUARD     │ │ MAINTENANCE │ │    VIDEO    │ │ COMPLIANCE  │ │ OBSERV-     │              │ │
│  │  │             │ │   TOURS     │ │             │ │             │ │             │ │ ABILITY     │              │ │
│  │  │ Check-in/   │ │ Patrols     │ │ Work Orders │ │ Analytics   │ │ ISO 27001   │ │ OpenTelemetry│             │ │
│  │  │ Credentials │ │ Checkpoints │ │ Scheduling  │ │ Playback    │ │ SOX/GDPR    │ │ SigNoz      │              │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘              │ │
│  └─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                                            INFRASTRUCTURE LAYER                                                 │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                      │ │
│  │  │  PostgreSQL  │  │ TimescaleDB  │  │    Redis     │  │   SigNoz     │  │  Tailscale   │                      │ │
│  │  │     17       │  │  Hypertables │  │    Cache     │  │    OTLP      │  │   VPN Mesh   │                      │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘                      │ │
│  └─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
         │                                                    │                                                    │
         │                                                    │                                                    │
         ▼                                                    ▼                                                    ▼
┌─────────────────┐                                 ┌─────────────────┐                                 ┌─────────────────┐
│   OPERATORS     │                                 │    CENTRAL      │                                 │   MOBILE APPS   │
│                 │                                 │    STATION      │                                 │                 │
│ • Security      │                                 │                 │                                 │ • iOS/Android   │
│ • Admin         │                                 │ • Monitoring    │                                 │ • Guard Tours   │
│ • Supervisors   │                                 │ • Dispatch      │                                 │ • Panic Alerts  │
└─────────────────┘                                 └─────────────────┘                                 └─────────────────┘
```

---

## 3. External Actors

### 3.1 Human Actors

| Actor | Description | Interaction Channels |
|-------|-------------|---------------------|
| **Security Operators** | Monitor alarms, dispatch guards, manage access | Web UI, Desktop App |
| **System Administrators** | Configure tenants, users, integrations | Admin Portal |
| **Guards/Patrol Officers** | Conduct tours, respond to incidents | Mobile App (iOS/Android) |
| **Visitors** | Self-service check-in, credential requests | Kiosk, Mobile App |
| **Tenants/Customers** | Multi-tenant account holders | Customer Portal |
| **Compliance Officers** | Audit, reporting, regulatory compliance | Reporting Dashboard |

### 3.2 System Actors

| Actor | Protocol | Purpose |
|-------|----------|---------|
| **Alarm Panels** | SIA DC-07, Contact ID, SIA IP | Alarm event ingestion |
| **Access Control Devices** | OSDP, Wiegand, RS-485 | Door/reader management |
| **Video Systems** | ONVIF, RTSP | Camera integration |
| **Central Monitoring Stations** | SIA DC-09 (XML) | Alarm forwarding |
| **Identity Providers** | SAML 2.0, OAuth 2.0 | SSO authentication |
| **External APIs** | REST, GraphQL | Third-party integrations |
| **SMS/Email Providers** | SMTP, Twilio API | Notifications |

---

## 4. System Boundaries

### 4.1 In Scope

- Multi-tenant alarm monitoring and processing
- Physical access control management (RBAC with anti-passback)
- Video management system integration
- Guard tour and patrol management
- Visitor management with credential issuance
- Real-time analytics and machine learning predictions
- Compliance reporting (ISO 27001, SOX 404, GDPR, HIPAA, PCI DSS)
- Mobile applications for field operations
- Cybernetic self-healing and autonomic control

### 4.2 Out of Scope

- Physical hardware manufacturing
- Cellular/radio transmission infrastructure
- End-user device management (BYOD)
- Building management systems (BMS) - future integration planned

---

## 5. Quality Attributes

### 5.1 Safety (IEC 61508 SIL-2)

| Requirement | Target | Implementation |
|-------------|--------|----------------|
| Systematic Capability | SIL 2 | STAMP safety constraints, FMEA analysis |
| Hardware Fault Tolerance | HFT 0 | Redundant sensors, failsafe modes |
| Proof Test Coverage | 90% | Continuous validation via TDG |
| Safe Failure Fraction | >90% | Device failsafe state machines |

### 5.2 Security (ISO 27001)

| Control | Implementation |
|---------|----------------|
| A.9 Access Control | RBAC with 51+ state machine tests |
| A.10 Cryptography | AES-256, TLS 1.3, HKDF key derivation |
| A.12 Operations Security | Audit logging, PII scrubbing |
| A.13 Communications Security | mTLS, Tailscale mesh |
| A.14 System Development | TDG methodology, SAST/DAST |

### 5.3 Performance

| Metric | Target | Measurement |
|--------|--------|-------------|
| OODA Loop Latency | <100ms | Cortex homeostasis monitoring |
| Alarm Processing | <500ms | End-to-end from panel to operator |
| API Response Time | P95 <200ms | OpenTelemetry traces |
| Concurrent Users | 100+ | Load testing with Artillery |
| Container Startup | <60s | Podman orchestration |

### 5.4 Scalability

| Dimension | Approach |
|-----------|----------|
| Horizontal | FLAME elastic compute for ML/analytics |
| Vertical | BEAM VM schedulers (+S 16:16) |
| Multi-tenant | Tenant-scoped resources via Ash |
| Geographic | libcluster + Tailscale mesh |

### 5.5 Availability

| Target | Implementation |
|--------|----------------|
| 99.9% Uptime | 3+ node HA cluster with quorum |
| RTO | <15 minutes | Automated failover |
| RPO | <1 minute | TimescaleDB continuous archiving |

---

## 6. Technology Stack

### 6.1 Core Technologies

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| **Language** | Elixir | 1.19.x | Primary language |
| **Runtime** | Erlang/OTP | 28 | BEAM VM |
| **Framework** | Phoenix | 1.7.x | Web framework |
| **Domain DSL** | Ash | 3.x | Resource modeling |
| **Database** | PostgreSQL | 17 | Primary datastore |
| **Time-series** | TimescaleDB | 2.x | Event history |
| **Cache** | Redis | 7.x | Session/cache store |
| **Containers** | Podman | 5.4.x | Container runtime |
| **Observability** | SigNoz | 0.50+ | OTLP backend |

### 6.2 Framework Stack (SOPv5.11)

| Framework | Purpose | Key Modules |
|-----------|---------|-------------|
| **OODA** | Cognitive control loop | Observer, Orientator, Decider, Actor |
| **STAMP** | Safety constraints | 195 SC-* constraints |
| **TPS** | Root cause analysis | 5-level problem solving |
| **TDG** | Test-driven generation | PropCheck + ExUnitProperties |
| **GDE** | Goal-directed evolution | Hypothesis → Simulate → Select → Execute |
| **AEE** | Autonomous tool execution | Compilation, deployment automation |
| **PHICS** | Container hot-reload | <50ms file sync |
| **FLAME** | Distributed compute | Elastic ML/analytics runners |

---

## 7. Deployment Topology

### 7.1 Three-Container Architecture

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                           HOST SYSTEM (NixOS)                                  │
├───────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐   │
│  │   indrajaal-app     │  │   indrajaal-db      │  │   indrajaal-obs     │   │
│  │                     │  │                     │  │                     │   │
│  │  CPU: 12 cores      │  │  CPU: 4 cores       │  │  CPU: 4 cores       │   │
│  │  RAM: 32 GB         │  │  RAM: 16 GB         │  │  RAM: 8 GB          │   │
│  │                     │  │                     │  │                     │   │
│  │  • Phoenix App      │  │  • PostgreSQL 17    │  │  • SigNoz           │   │
│  │  • 175 Agents       │  │  • TimescaleDB      │  │  • ClickHouse       │   │
│  │  • OODA/Cortex      │  │  • Redis            │  │  • OTLP Collector   │   │
│  │                     │  │                     │  │                     │   │
│  │  Port: 4000/4001    │  │  Port: 5433         │  │  Port: 3301/4317    │   │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘   │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                           PHICS Hot-Reload Layer (<50ms)                │ │
│  │                           Volume Mounts + inotify + fswatch             │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                           Tailscale Mesh (Identity-Based)               │ │
│  │                           Node Discovery via libcluster                 │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Production HA Cluster

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Node 1        │    │   Node 2        │    │   Node 3        │
│   (Primary)     │◄──►│   (Secondary)   │◄──►│   (Tertiary)    │
│                 │    │                 │    │                 │
│   Quorum: ✓     │    │   Quorum: ✓     │    │   Quorum: ✓     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                      │                      │
         └──────────────────────┴──────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │  Tailscale Mesh     │
                    │  (Identity-Based)   │
                    └─────────────────────┘
```

---

## 8. Communication Patterns

### 8.1 Synchronous

| Pattern | Protocol | Use Case |
|---------|----------|----------|
| REST API | HTTP/2 + TLS 1.3 | External integrations |
| GraphQL | HTTP/2 | Admin/reporting queries |
| gRPC | HTTP/2 | Internal microservice calls |

### 8.2 Asynchronous

| Pattern | Technology | Use Case |
|---------|------------|----------|
| Phoenix PubSub | In-memory | Real-time UI updates |
| Phoenix Channels | WebSocket | Live dashboards |
| Broadway | GenStage | Alarm event processing |
| Oban | PostgreSQL | Background job queue |

### 8.3 Event-Driven

| Event Type | Transport | Consumers |
|------------|-----------|-----------|
| Alarm Events | Broadway pipeline | Analytics, Notifications |
| Access Events | PubSub | Audit log, Real-time UI |
| System Telemetry | OTLP | SigNoz, Cortex sensors |

---

## 9. Cross-Cutting Concerns

### 9.1 Multi-Tenancy

- All core resources inherit from `Indrajaal.Shared.TenantResource`
- Tenant ID propagated via `Ash.PlugHelpers.set_tenant/2`
- Database-level row security (RLS) for PostgreSQL
- Isolated ETS caches per tenant

### 9.2 Observability

- OpenTelemetry SDK with auto-instrumentation
- Distributed tracing across all domains
- PII scrubbing in telemetry exports
- Custom Cortex sensors for health monitoring

### 9.3 Security

- JWT-based authentication with HKDF key derivation
- Rate limiting with ETS-backed token buckets
- Input validation via Ash changesets
- OWASP Top 10 mitigations

### 9.4 Compliance

- ISO 27001 control mapping
- SOX 404 audit trails
- GDPR data subject rights
- HIPAA PHI handling
- PCI DSS cardholder data protection

---

## 10. Related Documents

| Document | Description |
|----------|-------------|
| [Level 2: Container Architecture](level-2-container-architecture.md) | Deployment containers and services |
| [Level 3: Component Architecture](level-3-component-architecture.md) | 79 domains and their relationships |
| [Level 4: Module Architecture](level-4-module-architecture.md) | Detailed module dependencies |
| [Level 5: Code Architecture](level-5-code-architecture.md) | Patterns, interfaces, key functions |
| [Implementation Guide](../implementation-guide.md) | Developer setup and workflows |
| [Usage Guide](../usage-guide.md) | Operator and admin documentation |
| [Test Documentation](../testing/README.md) | Test strategy and execution |

---

**Document Generated By**: Claude Code (Opus 4.5)
**Framework**: SOPv5.11 + STAMP + TDG + C4 Model
**Compliance**: IEC 61508 SIL-2, ISO 27001, GDPR
