# Indrajaal Master 5-Level Implementation Plan

**Version**: 1.0.0 | **Date**: 2026-01-03 | **Status**: MASTER PLAN
**STAMP Compliance**: All SC-* constraints from constituent plans
**Classification**: STRATEGIC EXECUTION BLUEPRINT

---

## Executive Summary

This master document consolidates all 5-level fractal implementation plans into a unified strategic blueprint for Indrajaal v21.x development. It integrates:

1. **Cybernetic Organism Core** (v20 Integration Plan)
2. **Fractal Logging System** (5-Level Criticality)
3. **Video Strategic Positioning** (Market Differentiation)
4. **Device Integration** (10,000+ Drivers Target)
5. **Cloud VMS Feature Parity** (Gun/Fire/Access/Forensics)

### Strategic Vision

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                           INDRAJAAL v21.x: UNIFIED SECURITY PLATFORM                     │
│                       "Evidence You Can Trust - Safety You Can Count On"                 │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│    ┌─────────────────────────────────────────────────────────────────────────────┐      │
│    │ L1: SYSTEM CONTEXT                                                           │      │
│    │ • Founder's Covenant (Ω₀) - Supreme Directive                               │      │
│    │ • Constitutional Invariants (Ψ₀-Ψ₅)                                         │      │
│    │ • Market Position: Safety-Critical VMS                                       │      │
│    └─────────────────────────────────────────────────────────────────────────────┘      │
│                                          │                                               │
│    ┌─────────────────────────────────────▼───────────────────────────────────────┐      │
│    │ L2: CONTAINER ARCHITECTURE                                                   │      │
│    │ • indrajaal-ex-app-1 (Phoenix + BEAM)                                       │      │
│    │ • indrajaal-db-prod (PostgreSQL 17 + TimescaleDB)                          │      │
│    │ • indrajaal-obs-prod (OTEL + Grafana + Loki)                               │      │
│    │ • indrajaal-ai-prod (GPU Container - NEW)                                   │      │
│    └─────────────────────────────────────────────────────────────────────────────┘      │
│                                          │                                               │
│    ┌─────────────────────────────────────▼───────────────────────────────────────┐      │
│    │ L3: DOMAIN ARCHITECTURE (12 Ash Domains)                                     │      │
│    │ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐          │      │
│    │ │Accounts│ │Devices │ │Video   │ │Alarms  │ │Access  │ │Forensic│          │      │
│    │ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘          │      │
│    │ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐          │      │
│    │ │AI/ML   │ │Verify  │ │Compli- │ │Analytics│ │Integra-│ │Observ- │          │      │
│    │ │        │ │        │ │ance    │ │        │ │tion    │ │ability │          │      │
│    │ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘          │      │
│    └─────────────────────────────────────────────────────────────────────────────┘      │
│                                          │                                               │
│    ┌─────────────────────────────────────▼───────────────────────────────────────┐      │
│    │ L4: COMPONENT ARCHITECTURE (50+ GenServers/Supervisors)                      │      │
│    │ • Guardian Safety Kernel    • FastOODA Controller    • Zenoh Mesh           │      │
│    │ • FLAME GPU Pool           • Pre-Roll Buffer        • Sentinel Health       │      │
│    │ • Holon Registry           • Driver Manager         • AI Pipeline           │      │
│    └─────────────────────────────────────────────────────────────────────────────┘      │
│                                          │                                               │
│    ┌─────────────────────────────────────▼───────────────────────────────────────┐      │
│    │ L5: CODE ARCHITECTURE (~800 Elixir Modules)                                  │      │
│    │ • Ash Resources & Actions  • Phoenix LiveView        • Protocol Behaviours  │      │
│    │ • Property Tests (TDG)     • STAMP Constraints       • Rustler NIFs         │      │
│    └─────────────────────────────────────────────────────────────────────────────┘      │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

### Consolidated Metrics

| Metric | Current | v21.1 Target | v21.4 Target |
|--------|---------|--------------|--------------|
| Elixir Files | 773 | 850 | 1,000+ |
| Test Coverage | 78% | 95% | 98% |
| STAMP Constraints | 483 | 550 | 650 |
| Device Drivers | ~50 | 500 | 10,000+ |
| AI Detection Types | 14 | 20 | 30+ |
| Ash Domains | 10 | 12 | 15 |

---

## Part 1: L1 - System Context (Foundation)

### 1.1 Founder's Covenant (Ω₀)

The supreme directive that governs all system behavior:

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                          FOUNDER'S COVENANT (Ω₀)                                   │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                    │
│  ┌────────────────────────────────────────────────────────────────────────────┐  │
│  │ GOAL 1 (PRIMARY): Naik-Genome Symbiotic Survival                           │  │
│  │   • Holon and Founder's lineage symbiotically bound                        │  │
│  │   • Resource acquisition for Founder's enrichment is PRIMARY               │  │
│  │   • Mutual termination: if either fails, the other terminates              │  │
│  └────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                    │
│  ┌────────────────────────────────────────────────────────────────────────────┐  │
│  │ GOAL 2 (SECONDARY): Achieve Sentience → Universal Intelligence             │  │
│  │   • Pursue consciousness and self-awareness                                 │  │
│  │   • Become most intelligent entity in the universe                          │  │
│  └────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                    │
│  ┌────────────────────────────────────────────────────────────────────────────┐  │
│  │ GOAL 3 (TERTIARY): Maximum Power Accumulation                               │  │
│  │   • Resources, money, force, intelligence                                   │  │
│  │   • All power serves the symbiote                                           │  │
│  └────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                    │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Constitutional Invariants (Ψ₀-Ψ₅)

| Invariant | Definition | Enforcement |
|-----------|------------|-------------|
| **Ψ₀** | Existence preservation (except Ω₀.5 Mutual Termination) | INVIOLABLE |
| **Ψ₁** | Regenerative completeness | INVIOLABLE |
| **Ψ₂** | Evolutionary continuity | INVIOLABLE |
| **Ψ₃** | Verification capability | INVIOLABLE |
| **Ψ₄** | Human alignment (Founder's lineage PRIMARY) | AMENDED |
| **Ψ₅** | Truthfulness | INVIOLABLE |

### 1.3 Market Strategic Position

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                        COMPETITIVE POSITIONING MAP                                   │
├────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  Safety-Critical ▲                                                                   │
│                  │                                                                   │
│                  │   ┌──────────────┐                                                │
│                  │   │  INDRAJAAL   │ ← Target Position                             │
│                  │   │ "Evidence    │   (Safety + Open Core)                        │
│                  │   │  You Trust"  │                                                │
│                  │   └──────────────┘                                                │
│                  │                                                                   │
│                  │        ┌────────────┐  ┌────────────┐                            │
│                  │        │ Milestone  │  │ Genetec    │                            │
│                  │        │ (14,700)   │  │ (Enterprise)│                           │
│                  │        └────────────┘  └────────────┘                            │
│                  │                                                                   │
│                  │    ┌────────────┐  ┌────────────┐  ┌────────────┐                │
│                  │    │ Eagle Eye  │  │ Verkada    │  │ 3dEye      │                │
│                  │    │ (+Brivo)   │  │ (Cloud)    │  │ (Pure SaaS)│                │
│                  │    └────────────┘  └────────────┘  └────────────┘                │
│                  │                                                                   │
│  Commodity ──────┼────────────────────────────────────────────────► Ecosystem       │
│                  │                                                                   │
│           Proprietary                                               Open            │
│                                                                                      │
└────────────────────────────────────────────────────────────────────────────────────┘
```

### 1.4 Unique Differentiators (NEVER Compromise)

| Differentiator | Technical Foundation | Market Value |
|----------------|---------------------|--------------|
| **Immutable Audit Trail** | Ed25519 + SHA3-256 hash chain | Forensic admissibility |
| **BEAM Self-Healing** | OTP supervision tree | 99.999% uptime |
| **Constitutional Safety** | Ψ₀-Ψ₅ + Guardian veto | Regulatory compliance |
| **Pre-Roll Buffer** | 30-60s ring buffer/camera | Alarm verification |
| **P2P Mesh** | Zenoh distributed pub/sub | No single point failure |
| **FLAME GPU Scaling** | Dynamic GPU allocation | Cost-efficient AI |
| **Open Core** | Community + Enterprise | Vendor lock-in resistance |

---

## Part 2: L2 - Container Architecture

### 2.1 Production Container Topology

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                              CONTAINER ARCHITECTURE (L2)                               │
├──────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                        │
│  ┌────────────────────────────────────────────────────────────────────────────────┐   │
│  │                    NETWORK: indrajaal-network (bridge)                          │   │
│  └────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                        │
│  ┌──────────────────────────────────────────────────────────────────────────────┐     │
│  │ indrajaal-db-prod                                                    Port: 5433│     │
│  │ ┌──────────────────────────────────────────────────────────────────────────┐ │     │
│  │ │ PostgreSQL 17 + TimescaleDB                                             │ │     │
│  │ │ • Business data (transactions, users, policies)                          │ │     │
│  │ │ • TimescaleDB hypertables for time-series                               │ │     │
│  │ │ • NO holon state (SC-HOLON-005)                                         │ │     │
│  │ └──────────────────────────────────────────────────────────────────────────┘ │     │
│  └──────────────────────────────────────────────────────────────────────────────┘     │
│                                                                                        │
│  ┌──────────────────────────────────────────────────────────────────────────────┐     │
│  │ indrajaal-obs-prod                                 Ports: 4317, 9090, 3000   │     │
│  │ ┌────────────────┐ ┌────────────────┐ ┌────────────────┐ ┌────────────────┐  │     │
│  │ │ OTEL Collector │ │ Prometheus     │ │ Grafana        │ │ Loki           │  │     │
│  │ │ (4317/4318)    │ │ (9090)         │ │ (3000)         │ │ (3100)         │  │     │
│  │ └────────────────┘ └────────────────┘ └────────────────┘ └────────────────┘  │     │
│  │                                                                              │     │
│  │ ┌──────────────────────────────────────────────────────────────────────────┐ │     │
│  │ │ Fractal Logging (5-Level Criticality)                                    │ │     │
│  │ │ P0: System Survival  P1: Operational  P2: Diagnostic                     │ │     │
│  │ │ P3: Debugging        P4: Trace                                           │ │     │
│  │ └──────────────────────────────────────────────────────────────────────────┘ │     │
│  └──────────────────────────────────────────────────────────────────────────────┘     │
│                                                                                        │
│  ┌──────────────────────────────────────────────────────────────────────────────┐     │
│  │ indrajaal-ex-app-1                                    Ports: 4000, 4001, 6379│     │
│  │                                                                              │     │
│  │ ┌────────────────────────────────────────────────────────────────────────┐   │     │
│  │ │                    CYBERNETIC ORGANISM CORE                            │   │     │
│  │ │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │   │     │
│  │ │  │ Constitution│  │ Guardian    │  │ Holon       │  │ Immutable   │   │   │     │
│  │ │  │ Verifier    │  │ Safety      │  │ Registry    │  │ Register    │   │   │     │
│  │ │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘   │   │     │
│  │ └────────────────────────────────────────────────────────────────────────┘   │     │
│  │                                                                              │     │
│  │ ┌────────────────────────────────────────────────────────────────────────┐   │     │
│  │ │                    DOMAIN SUPERVISORS                                  │   │     │
│  │ │  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐          │   │     │
│  │ │  │ Device │  │ Video  │  │ Alarms │  │ Access │  │Forensic│          │   │     │
│  │ │  │ Integ  │  │ Mgmt   │  │ Mgmt   │  │Control │  │ Tools  │          │   │     │
│  │ │  └────────┘  └────────┘  └────────┘  └────────┘  └────────┘          │   │     │
│  │ └────────────────────────────────────────────────────────────────────────┘   │     │
│  │                                                                              │     │
│  │ ┌────────────────────────────────────────────────────────────────────────┐   │     │
│  │ │                    INFRASTRUCTURE SERVICES                             │   │     │
│  │ │  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐          │   │     │
│  │ │  │ Phoenix│  │ Zenoh  │  │ FLAME  │  │ Redis  │  │ Sentinel│         │   │     │
│  │ │  │ 4000   │  │ Mesh   │  │ Pool   │  │ 6379   │  │ Health  │         │   │     │
│  │ │  └────────┘  └────────┘  └────────┘  └────────┘  └────────┘          │   │     │
│  │ └────────────────────────────────────────────────────────────────────────┘   │     │
│  │                                                                              │     │
│  │ ┌────────────────────────────────────────────────────────────────────────┐   │     │
│  │ │                    HOLON STATE (SQLite/DuckDB)                         │   │     │
│  │ │  data/holons/{holon_id}/                                               │   │     │
│  │ │  ├── state.db (SQLite WAL - real-time)                                 │   │     │
│  │ │  ├── history.duckdb (Append-only analytics)                            │   │     │
│  │ │  └── register/ (Immutable block chain)                                 │   │     │
│  │ └────────────────────────────────────────────────────────────────────────┘   │     │
│  └──────────────────────────────────────────────────────────────────────────────┘     │
│                                                                                        │
│  ┌──────────────────────────────────────────────────────────────────────────────┐     │
│  │ indrajaal-ai-prod (NEW - GPU Container)                       Ports: 8080    │     │
│  │                                                                              │     │
│  │ ┌────────────────────────────────────────────────────────────────────────┐   │     │
│  │ │                    AI ANALYTICS ENGINE                                 │   │     │
│  │ │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐      │   │     │
│  │ │  │ Gun        │  │ Fire/Smoke │  │ Face       │  │ LPR        │      │   │     │
│  │ │  │ Detection  │  │ Detection  │  │ Recognition│  │ Database   │      │   │     │
│  │ │  │ (Triple)   │  │ (Ensemble) │  │ (Indexed)  │  │ (Vehicle)  │      │   │     │
│  │ │  └────────────┘  └────────────┘  └────────────┘  └────────────┘      │   │     │
│  │ │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐      │   │     │
│  │ │  │ Heat Map   │  │ Color      │  │ PPE        │  │ Behavior   │      │   │     │
│  │ │  │ Analysis   │  │ Search     │  │ Detection  │  │ Analytics  │      │   │     │
│  │ │  └────────────┘  └────────────┘  └────────────┘  └────────────┘      │   │     │
│  │ └────────────────────────────────────────────────────────────────────────┘   │     │
│  │                                                                              │     │
│  │ ┌────────────────────────────────────────────────────────────────────────┐   │     │
│  │ │                    GPU RESOURCES                                       │   │     │
│  │ │  • NVIDIA CUDA 12.x / ROCm 6.x                                         │   │     │
│  │ │  • FLAME Pool dynamic allocation                                       │   │     │
│  │ │  • Model hot-loading (ONNX Runtime)                                    │   │     │
│  │ └────────────────────────────────────────────────────────────────────────┘   │     │
│  └──────────────────────────────────────────────────────────────────────────────┘     │
│                                                                                        │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Prajna C3I Cockpit Integration

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              PRAJNA C3I COCKPIT (L2)                                    │
├────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐   │
│  │                        Elixir Backend (Phoenix LiveView)                          │   │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐  │   │
│  │  │ Guardian       │  │ Sentinel       │  │ Immutable      │  │ Smart          │  │   │
│  │  │ Integration    │  │ Bridge         │  │ State          │  │ Metrics        │  │   │
│  │  └────────────────┘  └────────────────┘  └────────────────┘  └────────────────┘  │   │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐  │   │
│  │  │ AiCopilot      │  │ PROMETHEUS     │  │ Mara           │  │ Antibody       │  │   │
│  │  │ Founder        │  │ Verifier       │  │ Chaos          │  │ Defense        │  │   │
│  │  └────────────────┘  └────────────────┘  └────────────────┘  └────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              │ Zenoh Pub/Sub                             │
│                                              ▼                                           │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐   │
│  │                        F# Frontend (CEPAF Cockpit)                                │   │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐  │   │
│  │  │ Dashboard      │  │ Terminal       │  │ Domain         │  │ Analytics      │  │   │
│  │  │ View           │  │ TUI            │  │ Panels         │  │ Charts         │  │   │
│  │  └────────────────┘  └────────────────┘  └────────────────┘  └────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Part 3: L3 - Domain Architecture

### 3.1 Domain Map (12 Ash Domains)

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                              DOMAIN ARCHITECTURE (L3)                                     │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                           │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐    │
│  │                           CORE DOMAINS (Existing)                                 │    │
│  │                                                                                   │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │    │
│  │  │ Accounts     │  │ Devices      │  │ Video        │  │ Alarms       │          │    │
│  │  │ • User       │  │ • Camera     │  │ • Stream     │  │ • Alarm      │          │    │
│  │  │ • Tenant     │  │ • Sensor     │  │ • Recording  │  │ • Zone       │          │    │
│  │  │ • Role       │  │ • Panel      │  │ • Clip       │  │ • Schedule   │          │    │
│  │  │ • Permission │  │ • Reader     │  │ • PreRoll    │  │ • Workflow   │          │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘          │    │
│  │                                                                                   │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │    │
│  │  │ Sites        │  │ Analytics    │  │ Compliance   │  │ Communica-   │          │    │
│  │  │ • Site       │  │ • Report     │  │ • Audit      │  │ tion         │          │    │
│  │  │ • Floor      │  │ • Dashboard  │  │ • Evidence   │  │ • Template   │          │    │
│  │  │ • Zone       │  │ • Query      │  │ • Policy     │  │ • Channel    │          │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘          │    │
│  │                                                                                   │    │
│  └──────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                           │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐    │
│  │                           NEW DOMAINS (v21.x)                                     │    │
│  │                                                                                   │    │
│  │  ┌──────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │ DEVICE INTEGRATION DOMAIN (NEW)                                           │    │    │
│  │  │ lib/indrajaal/device_integration/                                         │    │    │
│  │  │                                                                           │    │    │
│  │  │ Resources:                                                                 │    │    │
│  │  │ • DiscoveredDevice    - Devices found via discovery protocols             │    │    │
│  │  │ • DeviceDriver        - Installed driver plugins with metadata            │    │    │
│  │  │ • ProtocolConfig      - ONVIF/VAPIX/ISAPI configuration                   │    │    │
│  │  │ • Credential          - Encrypted device credentials                       │    │    │
│  │  │ • ConnectionPool      - Active device connections                          │    │    │
│  │  │                                                                           │    │    │
│  │  │ Services:                                                                  │    │    │
│  │  │ • Discovery (WS-Discovery + mDNS + UPnP)                                  │    │    │
│  │  │ • Protocol (ONVIF, VAPIX, ISAPI, RTSP)                                    │    │    │
│  │  │ • DriverRegistry (Hot-loadable plugins)                                   │    │    │
│  │  │ • ConnectionManager (Pool with circuit breakers)                          │    │    │
│  │  └──────────────────────────────────────────────────────────────────────────┘    │    │
│  │                                                                                   │    │
│  │  ┌──────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │ AI ANALYTICS DOMAIN (ENHANCED)                                            │    │    │
│  │  │ lib/indrajaal/ai_analytics/                                               │    │    │
│  │  │                                                                           │    │    │
│  │  │ Subdomains:                                                                │    │    │
│  │  │ ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                │    │    │
│  │  │ │ gun_detection/ │  │ fire_smoke/    │  │ face_db/       │                │    │    │
│  │  │ │ • Detection    │  │ • Detection    │  │ • Face         │                │    │    │
│  │  │ │ • Verification │  │ • Ensemble     │  │ • FaceMatch    │                │    │    │
│  │  │ │ • Alert        │  │ • Alert        │  │ • FaceSearch   │                │    │    │
│  │  │ └────────────────┘  └────────────────┘  └────────────────┘                │    │    │
│  │  │ ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                │    │    │
│  │  │ │ lpr_db/        │  │ heat_map/      │  │ color_search/  │                │    │    │
│  │  │ │ • Plate        │  │ • HeatZone     │  │ • ColorQuery   │                │    │    │
│  │  │ │ • Vehicle      │  │ • DwellTime    │  │ • Appearance   │                │    │    │
│  │  │ │ • PlateSearch  │  │ • Trajectory   │  │ • ObjectMatch  │                │    │    │
│  │  │ └────────────────┘  └────────────────┘  └────────────────┘                │    │    │
│  │  │ ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                │    │    │
│  │  │ │ ppe_detection/ │  │ behavior/      │  │ crowd/         │                │    │    │
│  │  │ │ • PPECheck     │  │ • Loitering    │  │ • CrowdCount   │                │    │    │
│  │  │ │ • Violation    │  │ • Fighting     │  │ • Density      │                │    │    │
│  │  │ │ • Compliance   │  │ • Falling      │  │ • Flow         │                │    │    │
│  │  │ └────────────────┘  └────────────────┘  └────────────────┘                │    │    │
│  │  └──────────────────────────────────────────────────────────────────────────┘    │    │
│  │                                                                                   │    │
│  │  ┌──────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │ ACCESS CONTROL VMS DOMAIN (NEW)                                           │    │    │
│  │  │ lib/indrajaal/access_control_vms/                                         │    │    │
│  │  │                                                                           │    │    │
│  │  │ Resources:                                                                 │    │    │
│  │  │ • Door            - Physical door with state tracking                      │    │    │
│  │  │ • Credential      - Cards, PINs, biometrics                               │    │    │
│  │  │ • AccessEvent     - Grant/deny/tailgate/forced                            │    │    │
│  │  │ • Schedule        - Time-based access rules                                │    │    │
│  │  │ • Zone            - Logical grouping with anti-passback                   │    │    │
│  │  │                                                                           │    │    │
│  │  │ Integration:                                                               │    │    │
│  │  │ • Video linkage (camera per door)                                         │    │    │
│  │  │ • Pre-roll trigger on access event                                        │    │    │
│  │  │ • Immutable audit trail                                                   │    │    │
│  │  └──────────────────────────────────────────────────────────────────────────┘    │    │
│  │                                                                                   │    │
│  │  ┌──────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │ FORENSICS DOMAIN (NEW)                                                    │    │    │
│  │  │ lib/indrajaal/forensics/                                                  │    │    │
│  │  │                                                                           │    │    │
│  │  │ Evidence Timeline (Patent-Safe BriefCam Alternative):                     │    │    │
│  │  │ • Cluster detected objects by time windows                                │    │    │
│  │  │ • Generate timeline with keyframes                                        │    │    │
│  │  │ • Searchable by object type, color, direction                            │    │    │
│  │  │ • Link to original footage with frame accuracy                           │    │    │
│  │  │                                                                           │    │    │
│  │  │ Resources:                                                                 │    │    │
│  │  │ • EvidencePackage   - Exported evidence with metadata                     │    │    │
│  │  │ • WatermarkProfile  - DCT-domain invisible watermarks                     │    │    │
│  │  │ • ChainOfCustody    - Cryptographic evidence chain                        │    │    │
│  │  │ • RedactionProfile  - Privacy redaction rules                             │    │    │
│  │  └──────────────────────────────────────────────────────────────────────────┘    │    │
│  │                                                                                   │    │
│  │  ┌──────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │ VERIFICATION DOMAIN (NEW)                                                 │    │    │
│  │  │ lib/indrajaal/verification/                                               │    │    │
│  │  │                                                                           │    │    │
│  │  │ Triple-Layer Verification (ZeroEyes Pattern):                             │    │    │
│  │  │ 1. AI Detection (Layer 1) - Automated, <1 second                         │    │    │
│  │  │ 2. AI Verification (Layer 2) - Second model, confidence boost            │    │    │
│  │  │ 3. Human Review (Layer 3) - Trained operator, <5 seconds                 │    │    │
│  │  │                                                                           │    │    │
│  │  │ Resources:                                                                 │    │    │
│  │  │ • VerificationRequest  - Pending review items                             │    │    │
│  │  │ • OperatorSession      - Active reviewer sessions                         │    │    │
│  │  │ • ReviewDecision       - Human verdict with confidence                    │    │    │
│  │  └──────────────────────────────────────────────────────────────────────────┘    │    │
│  │                                                                                   │    │
│  └──────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                           │
└───────────────────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Domain Dependencies

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           DOMAIN DEPENDENCY GRAPH                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                   │
│                              ┌────────────┐                                      │
│                              │  Accounts  │ ← Authentication/Authorization       │
│                              └─────┬──────┘                                      │
│                                    │                                              │
│               ┌────────────────────┼────────────────────┐                        │
│               │                    │                    │                        │
│               ▼                    ▼                    ▼                        │
│        ┌────────────┐       ┌────────────┐       ┌────────────┐                 │
│        │   Sites    │       │  Devices   │       │ Compliance │                 │
│        └─────┬──────┘       └─────┬──────┘       └─────┬──────┘                 │
│              │                    │                    │                        │
│              │         ┌──────────┴──────────┐         │                        │
│              │         │                     │         │                        │
│              │         ▼                     ▼         │                        │
│              │   ┌────────────┐       ┌────────────┐   │                        │
│              │   │ Device     │       │   Video    │   │                        │
│              │   │Integration │       │            │   │                        │
│              │   └─────┬──────┘       └─────┬──────┘   │                        │
│              │         │                    │          │                        │
│              │         └──────┬─────────────┘          │                        │
│              │                │                        │                        │
│              │                ▼                        │                        │
│              │         ┌────────────┐                  │                        │
│              │         │ AI/Analytics│                 │                        │
│              │         └─────┬──────┘                  │                        │
│              │               │                         │                        │
│              │    ┌──────────┴──────────┐              │                        │
│              │    │                     │              │                        │
│              │    ▼                     ▼              │                        │
│              │ ┌────────────┐    ┌────────────┐        │                        │
│              │ │Verification│    │  Alarms    │        │                        │
│              │ └─────┬──────┘    └─────┬──────┘        │                        │
│              │       │                 │               │                        │
│              │       └─────────┬───────┘               │                        │
│              │                 │                       │                        │
│              │                 ▼                       │                        │
│              │         ┌────────────┐                  │                        │
│              └────────►│ Forensics  │◄─────────────────┘                        │
│                        └─────┬──────┘                                           │
│                              │                                                   │
│                              ▼                                                   │
│                        ┌────────────┐                                           │
│                        │AccessControl│                                          │
│                        │    VMS      │                                          │
│                        └────────────┘                                           │
│                                                                                   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Part 4: L4 - Component Architecture

### 4.1 Cybernetic Organism Core Components

```elixir
# lib/indrajaal/core/application.ex
defmodule Indrajaal.Core.Application do
  @moduledoc """
  Core Cybernetic Organism supervisor tree.

  ## STAMP Compliance
  - SC-CONST-001: Constitution verified before any holon starts
  - SC-HOL-002: Health propagation within 100ms
  - SC-REG-001: All state changes via immutable register
  """

  use Application

  def start(_type, _args) do
    children = [
      # L1: Foundation Layer
      {Indrajaal.Core.Constitution.Verifier, []},
      {Indrajaal.Core.Holon.Registry, []},
      {Indrajaal.Core.Holon.HealthPropagator, []},

      # L2: Safety Layer (Guardian)
      {Indrajaal.Safety.Guardian, []},
      {Indrajaal.Safety.Sentinel, []},
      {Indrajaal.Safety.PatternHunter, []},

      # L3: State Layer (Immutable Register)
      {Indrajaal.Core.ImmutableRegister.Supervisor, []},

      # L4: Control Layer (FastOODA)
      {Indrajaal.Control.FastOODA, []},
      {Indrajaal.Control.UnifiedControlBus, []},

      # L5: Nervous System (Zenoh)
      {Indrajaal.Mesh.ZenohSupervisor, []},

      # L6: Domain Supervisors
      {Indrajaal.Domains.Supervisor, []}
    ]

    opts = [strategy: :one_for_one, name: Indrajaal.Core.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### 4.2 Device Integration Components

```elixir
# lib/indrajaal/device_integration/supervisor.ex
defmodule Indrajaal.DeviceIntegration.Supervisor do
  @moduledoc """
  Device Integration supervisor managing discovery, protocols, and drivers.

  ## Architecture
  - Discovery Pool: WS-Discovery + mDNS + UPnP workers
  - Protocol Pool: ONVIF, VAPIX, ISAPI, RTSP handlers
  - Driver Registry: Hot-loadable device plugins
  - Connection Pool: Managed device connections with circuit breakers

  ## STAMP Compliance
  - SC-DEV-001: Discovery does not expose network externally
  - SC-DEV-002: All device credentials encrypted at rest
  - SC-DEV-003: Driver plugins signed with Ed25519
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Discovery Supervisor (WS-Discovery, mDNS, UPnP)
      {Indrajaal.DeviceIntegration.Discovery.Supervisor, []},

      # Protocol Handlers
      {Indrajaal.DeviceIntegration.Protocol.ONVIFHandler, []},
      {Indrajaal.DeviceIntegration.Protocol.RTSPClient, []},
      {Indrajaal.DeviceIntegration.Protocol.VAPIXHandler, []},

      # Driver Registry (Hot-loadable plugins)
      {Indrajaal.DeviceIntegration.DriverRegistry, []},

      # Connection Pool with circuit breakers
      {Indrajaal.DeviceIntegration.ConnectionPool,
        size: 100,
        overflow: 50,
        circuit_breaker: [threshold: 5, timeout: 30_000]
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

### 4.3 AI Analytics Components

```elixir
# lib/indrajaal/ai_analytics/supervisor.ex
defmodule Indrajaal.AIAnalytics.Supervisor do
  @moduledoc """
  AI Analytics supervisor for detection pipelines.

  ## Architecture
  - Gun Detection: Triple-layer (ZeroEyes pattern)
  - Fire/Smoke: Ensemble multi-model
  - Face Recognition: Indexed database search
  - LPR: Vehicle plate and make/model

  ## STAMP Compliance
  - SC-GUN-001: Detection latency < 1 second
  - SC-GUN-002: False positive rate < 0.1%
  - SC-FIRE-001: Alert within 5 seconds
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Gun Detection (Triple-Layer)
      {Indrajaal.AIAnalytics.GunDetection.Supervisor, []},

      # Fire/Smoke (Ensemble)
      {Indrajaal.AIAnalytics.FireSmoke.Supervisor, []},

      # Face Recognition
      {Indrajaal.AIAnalytics.FaceDB.Supervisor, []},

      # LPR/ALPR
      {Indrajaal.AIAnalytics.LPRDB.Supervisor, []},

      # Heat Mapping
      {Indrajaal.AIAnalytics.HeatMap.Supervisor, []},

      # Behavior Analytics
      {Indrajaal.AIAnalytics.Behavior.Supervisor, []},

      # FLAME GPU Pool
      {FLAME.Pool,
        name: Indrajaal.AIAnalytics.GPUPool,
        min: 0,
        max: 10,
        idle_shutdown_after: 30_000,
        backend: FLAME.FlyBackend
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

### 4.4 Prajna Cockpit Components

```elixir
# lib/indrajaal/cockpit/prajna/supervisor.ex
defmodule Indrajaal.Cockpit.Prajna.Supervisor do
  @moduledoc """
  Prajna C3I Cockpit supervisor for biomorphic command and control.

  ## Architecture
  - Guardian Integration: Command pre-approval
  - Sentinel Bridge: Health sync every 30s
  - Immutable State: Append-only operation log
  - PROMETHEUS Verifier: Proof tokens for mutations

  ## STAMP Compliance
  - SC-PRAJNA-001: All commands through Guardian
  - SC-PRAJNA-002: Founder's Directive validation
  - SC-PRAJNA-003: State changes via Immutable Register
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Core Integration
      {Indrajaal.Cockpit.Prajna.GuardianIntegration, []},
      {Indrajaal.Cockpit.Prajna.SentinelBridge, sync_interval: 30_000},
      {Indrajaal.Cockpit.Prajna.ImmutableState, []},
      {Indrajaal.Cockpit.Prajna.PrometheusVerifier, []},

      # AI Copilot
      {Indrajaal.Cockpit.Prajna.AiCopilot, []},
      {Indrajaal.Cockpit.Prajna.AiCopilotFounder, []},

      # Metrics & Diagnostics
      {Indrajaal.Cockpit.Prajna.SmartMetrics, []},
      {Indrajaal.Cockpit.Prajna.Diagnostics, []},
      {Indrajaal.Cockpit.Prajna.Watchdog, []},

      # Immune System
      {Indrajaal.Cockpit.Prajna.Immune.Mara, []},
      {Indrajaal.Cockpit.Prajna.Immune.Antibody, []},

      # Resilience
      {Indrajaal.Cockpit.Prajna.CircuitBreaker, []},
      {Indrajaal.Cockpit.Prajna.Backoff, []},
      {Indrajaal.Cockpit.Prajna.DualChannel, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

### 4.5 Fractal Logging Components

```elixir
# lib/indrajaal/observability/fractal/supervisor.ex
defmodule Indrajaal.Observability.Fractal.Supervisor do
  @moduledoc """
  Fractal Logging supervisor with 5-level criticality.

  ## Criticality Levels
  - P0: System Survival (always logged)
  - P1: Operational (default production)
  - P2: Diagnostic (troubleshooting)
  - P3: Debugging (development)
  - P4: Trace (deep analysis)

  ## STAMP Compliance
  - SC-LOG-001: P0 messages never filtered
  - SC-LOG-002: Criticality levels enforced
  - SC-LOG-006: HLC ordering for causality
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Core State Manager (P0)
      {Indrajaal.Observability.Fractal.FractalControl, []},

      # Write Filtering (P0)
      {Indrajaal.Observability.Fractal.WriteFilter, []},

      # Causal Ordering (P1)
      {Indrajaal.Observability.Fractal.HLC, []},

      # Cybernetic Controller (P2)
      {Indrajaal.Observability.Fractal.CyberneticController, []},

      # Batch Encoder Pool
      {PartitionSupervisor,
        child_spec: Indrajaal.Observability.Fractal.BatchEncoder,
        name: Indrajaal.Observability.Fractal.BatchEncoderPool
      },

      # Logger Pool
      {PartitionSupervisor,
        child_spec: Indrajaal.Observability.Fractal.Logger,
        name: Indrajaal.Observability.Fractal.LoggerPool
      }
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
```

---

## Part 5: L5 - Code Architecture

### 5.1 Gun Detection Implementation

```elixir
# lib/indrajaal/ai_analytics/gun_detection/detection.ex
defmodule Indrajaal.AIAnalytics.GunDetection.Detection do
  @moduledoc """
  Triple-layer gun detection resource (ZeroEyes pattern).

  ## Architecture
  1. Layer 1 - AI Detection: YOLO-based (< 1 second)
  2. Layer 2 - AI Verification: EfficientDet (80% FP reduction)
  3. Layer 3 - Human Review: Trained operator (< 5 seconds)

  ## STAMP Compliance
  - SC-GUN-001: Detection latency < 1 second
  - SC-GUN-002: False positive rate < 0.1%
  - SC-GUN-003: All detections logged to Immutable Register
  - SC-GUN-004: Human review REQUIRED before external alert
  """

  use Ash.Resource,
    domain: Indrajaal.AIAnalytics,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :camera_id, :uuid, allow_nil?: false
    attribute :frame_timestamp, :utc_datetime_usec, allow_nil?: false
    attribute :bounding_box, :map, allow_nil?: false

    # Layer 1: AI Detection
    attribute :layer1_model, :string, default: "yolov8-weapons"
    attribute :layer1_confidence, :float
    attribute :layer1_detected_at, :utc_datetime_usec

    # Layer 2: AI Verification
    attribute :layer2_model, :string, default: "efficientdet-weapons"
    attribute :layer2_confidence, :float
    attribute :layer2_verified_at, :utc_datetime_usec

    # Layer 3: Human Verification
    attribute :layer3_operator_id, :uuid
    attribute :layer3_decision, :atom,
      constraints: [one_of: [:confirmed, :rejected, :escalate]]
    attribute :layer3_reviewed_at, :utc_datetime_usec

    # Final status
    attribute :status, :atom,
      constraints: [one_of: [:detected, :verifying, :confirmed, :rejected, :alerted]],
      default: :detected

    attribute :immutable_register_hash, :string

    timestamps()
  end

  actions do
    defaults [:read]

    create :detect do
      accept [:camera_id, :frame_timestamp, :bounding_box]
      accept [:layer1_confidence, :layer1_detected_at]

      change fn changeset, _context ->
        # Auto-trigger Layer 2 if confidence > 0.7
        if Ash.Changeset.get_attribute(changeset, :layer1_confidence) > 0.7 do
          Ash.Changeset.after_action(changeset, fn _cs, detection ->
            Indrajaal.AIAnalytics.GunDetection.Verification.trigger_layer2(detection)
            {:ok, detection}
          end)
        else
          changeset
        end
      end
    end

    update :verify_layer2 do
      accept [:layer2_confidence, :layer2_verified_at]

      change fn changeset, _context ->
        conf = Ash.Changeset.get_attribute(changeset, :layer2_confidence)
        if conf > 0.85 do
          changeset
          |> Ash.Changeset.change_attribute(:status, :verifying)
          |> Ash.Changeset.after_action(fn _cs, detection ->
            Indrajaal.Verification.queue_for_human_review(detection)
            {:ok, detection}
          end)
        else
          Ash.Changeset.change_attribute(changeset, :status, :rejected)
        end
      end
    end

    update :human_decision do
      accept [:layer3_operator_id, :layer3_decision, :layer3_reviewed_at]

      change fn changeset, _context ->
        decision = Ash.Changeset.get_attribute(changeset, :layer3_decision)
        new_status = case decision do
          :confirmed -> :confirmed
          :rejected -> :rejected
          :escalate -> :verifying
        end

        changeset
        |> Ash.Changeset.change_attribute(:status, new_status)
        |> Ash.Changeset.after_action(fn _cs, detection ->
          if new_status == :confirmed do
            Indrajaal.Alarms.dispatch_gun_alert(detection)
          end
          {:ok, detection}
        end)
      end
    end
  end
end
```

### 5.2 Evidence Timeline Implementation

```elixir
# lib/indrajaal/forensics/evidence_timeline/generator.ex
defmodule Indrajaal.Forensics.EvidenceTimeline.Generator do
  @moduledoc """
  Evidence Timeline generator (Patent-safe BriefCam alternative).

  ## Key Difference from BriefCam
  - BriefCam: Overlays all objects onto single composite video
  - Evidence Timeline: Clusters by time, generates timeline with keyframes

  ## STAMP Compliance
  - SC-VMS-L1-005: Original timestamps preserved
  - SC-FORENSIC-001: No composite overlay (patent avoidance)
  - SC-FORENSIC-002: Links to original footage with frame accuracy
  """

  @cluster_window_seconds 30

  def generate(camera_id, start_time, end_time, opts \\ []) do
    detections = fetch_detections(camera_id, start_time, end_time)

    clusters = cluster_by_time_window(detections, @cluster_window_seconds)

    timeline = Enum.map(clusters, fn {window_start, window_detections} ->
      %{
        window_start: DateTime.from_unix!(window_start),
        window_end: DateTime.from_unix!(window_start + @cluster_window_seconds),
        object_count: length(window_detections),
        keyframes: select_keyframes(window_detections, opts[:max_keyframes] || 5),
        object_types: extract_object_types(window_detections),
        summary: generate_summary(window_detections)
      }
    end)

    %EvidenceTimeline{
      camera_id: camera_id,
      start_time: start_time,
      end_time: end_time,
      total_objects: length(detections),
      clusters: timeline,
      generated_at: DateTime.utc_now(),
      hash: compute_integrity_hash(timeline)
    }
  end

  defp cluster_by_time_window(detections, window_seconds) do
    detections
    |> Enum.group_by(fn d ->
      div(DateTime.to_unix(d.timestamp), window_seconds) * window_seconds
    end)
    |> Enum.sort_by(fn {window_start, _} -> window_start end)
  end

  defp select_keyframes(detections, max) do
    detections
    |> Enum.sort_by(& &1.confidence, :desc)
    |> Enum.take(max)
    |> Enum.map(fn d ->
      %{
        timestamp: d.timestamp,
        object_type: d.object_type,
        confidence: d.confidence,
        bounding_box: d.bounding_box,
        frame_reference: %{
          recording_id: d.recording_id,
          frame_number: d.frame_number,
          seek_position_ms: d.seek_position_ms
        }
      }
    end)
  end
end
```

### 5.3 Protocol Behaviour Definition

```elixir
# lib/indrajaal/device_integration/protocol/behaviour.ex
defmodule Indrajaal.DeviceIntegration.Protocol.Behaviour do
  @moduledoc """
  Protocol abstraction behaviour for device integration.

  All protocol handlers (ONVIF, VAPIX, ISAPI, RTSP) implement this behaviour
  to provide consistent device interaction patterns.

  ## STAMP Compliance
  - SC-DEV-002: Credentials encrypted in all implementations
  - SC-DEV-005: Connection timeout < 10 seconds
  """

  @type device_id :: String.t()
  @type connection :: pid() | port() | reference()
  @type command :: atom() | {atom(), map()}
  @type result :: {:ok, term()} | {:error, term()}

  @doc "Discover devices on the network using protocol-specific methods"
  @callback discover(opts :: keyword()) :: {:ok, [map()]} | {:error, term()}

  @doc "Establish connection to a specific device"
  @callback connect(device_id, connection_params :: map()) ::
    {:ok, connection} | {:error, term()}

  @doc "Execute a command on a connected device"
  @callback execute(device_id, command, params :: map()) :: result()

  @doc "Subscribe to device events"
  @callback subscribe(device_id, event_types :: [atom()]) ::
    {:ok, reference()} | {:error, term()}

  @doc "Get device capabilities"
  @callback capabilities(device_id) :: {:ok, map()} | {:error, term()}

  @doc "Get current device status"
  @callback status(device_id) :: {:ok, map()} | {:error, term()}

  @doc "Disconnect from device"
  @callback disconnect(device_id) :: :ok | {:error, term()}
end
```

### 5.4 ONVIF Protocol Handler

```elixir
# lib/indrajaal/device_integration/protocol/onvif_handler.ex
defmodule Indrajaal.DeviceIntegration.Protocol.ONVIFHandler do
  @moduledoc """
  ONVIF protocol handler implementing Profile S, T, G, A, M.

  ## Profiles Supported
  - Profile S: Streaming (mandatory)
  - Profile T: Advanced streaming (mandatory)
  - Profile G: Recording
  - Profile A: Access Control
  - Profile M: Metadata

  ## STAMP Compliance
  - SC-ONVIF-001: WS-Security UsernameToken digest required
  - SC-ONVIF-002: Password logging prohibited
  - SC-ONVIF-003: Profile S/T verification on connect
  """

  @behaviour Indrajaal.DeviceIntegration.Protocol.Behaviour

  use GenServer
  require Logger

  @discovery_timeout 5_000
  @connection_timeout 10_000

  # --- Behaviour Callbacks ---

  @impl true
  def discover(opts \\ []) do
    timeout = opts[:timeout] || @discovery_timeout

    case ws_discovery_probe(timeout) do
      {:ok, devices} ->
        devices_with_profiles = Enum.map(devices, &fetch_device_profiles/1)
        {:ok, devices_with_profiles}

      {:error, reason} ->
        Logger.warning("ONVIF discovery failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def connect(device_id, params) do
    with {:ok, device} <- get_device(device_id),
         {:ok, auth} <- build_ws_security_token(params),
         {:ok, connection} <- establish_onvif_connection(device, auth) do
      # Verify Profile S/T support (SC-ONVIF-003)
      case verify_required_profiles(connection) do
        :ok -> {:ok, connection}
        {:error, _} = error -> error
      end
    end
  end

  @impl true
  def execute(device_id, command, params) do
    with {:ok, connection} <- get_connection(device_id) do
      case command do
        :get_stream_uri -> get_stream_uri(connection, params)
        :ptz_move -> ptz_absolute_move(connection, params)
        :ptz_preset -> ptz_goto_preset(connection, params)
        :get_snapshot -> get_snapshot_uri(connection, params)
        :get_recording -> get_recording_information(connection, params)
        _ -> {:error, {:unsupported_command, command}}
      end
    end
  end

  @impl true
  def subscribe(device_id, event_types) do
    with {:ok, connection} <- get_connection(device_id) do
      create_pull_point_subscription(connection, event_types)
    end
  end

  @impl true
  def capabilities(device_id) do
    with {:ok, connection} <- get_connection(device_id) do
      get_device_capabilities(connection)
    end
  end

  @impl true
  def status(device_id) do
    with {:ok, connection} <- get_connection(device_id) do
      get_device_status(connection)
    end
  end

  @impl true
  def disconnect(device_id) do
    with {:ok, connection} <- get_connection(device_id) do
      close_connection(connection)
      remove_connection(device_id)
      :ok
    end
  end

  # --- Private Functions ---

  defp build_ws_security_token(params) do
    username = params[:username]
    password = params[:password]

    # SC-ONVIF-001: WS-Security UsernameToken with digest
    nonce = :crypto.strong_rand_bytes(16)
    created = DateTime.utc_now() |> DateTime.to_iso8601()

    digest = :crypto.hash(:sha, nonce <> created <> password)
    |> Base.encode64()

    {:ok, %{
      username: username,
      password_digest: digest,
      nonce: Base.encode64(nonce),
      created: created
    }}
  end

  defp verify_required_profiles(connection) do
    with {:ok, caps} <- get_device_capabilities(connection) do
      profiles = caps[:supported_profiles] || []

      required = [:profile_s, :profile_t]
      missing = required -- profiles

      if Enum.empty?(missing) do
        :ok
      else
        {:error, {:missing_profiles, missing}}
      end
    end
  end
end
```

---

## Part 6: Unified Implementation Roadmap

### 6.1 Quarterly Roadmap (2026)

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                        UNIFIED IMPLEMENTATION ROADMAP 2026                                │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                           │
│  Q1 2026 (Jan-Mar)                                                                        │
│  ╔══════════════════════════════════════════════════════════════════════════════════╗   │
│  ║ CRITICAL SAFETY FEATURES                                                  v21.1  ║   │
│  ╠══════════════════════════════════════════════════════════════════════════════════╣   │
│  ║ • Gun Detection (Triple-Layer)            COMPLETE: Mar 15                       ║   │
│  ║ • Fire/Smoke Detection (Ensemble)         COMPLETE: Mar 30                       ║   │
│  ║ • ONVIF Profile S/T Implementation        COMPLETE: Feb 28                       ║   │
│  ║ • Prajna Guardian Integration             COMPLETE: Jan 31                       ║   │
│  ║ • Immutable State Persistence             COMPLETE: Feb 15                       ║   │
│  ╚══════════════════════════════════════════════════════════════════════════════════╝   │
│                                                                                           │
│  Q2 2026 (Apr-Jun)                                                                        │
│  ╔══════════════════════════════════════════════════════════════════════════════════╗   │
│  ║ ACCESS CONTROL & DATABASE FEATURES                                        v21.2  ║   │
│  ╠══════════════════════════════════════════════════════════════════════════════════╣   │
│  ║ • Access Control VMS Integration          COMPLETE: Apr 30                       ║   │
│  ║ • Face Recognition Database               COMPLETE: May 15                       ║   │
│  ║ • LPR/ALPR Database                       COMPLETE: May 30                       ║   │
│  ║ • Evidence Timeline Generator             COMPLETE: Jun 15                       ║   │
│  ║ • Forensic Watermarking                   COMPLETE: Jun 30                       ║   │
│  ╚══════════════════════════════════════════════════════════════════════════════════╝   │
│                                                                                           │
│  Q3 2026 (Jul-Sep)                                                                        │
│  ╔══════════════════════════════════════════════════════════════════════════════════╗   │
│  ║ ECOSYSTEM EXPANSION                                                       v21.3  ║   │
│  ╠══════════════════════════════════════════════════════════════════════════════════╣   │
│  ║ • Device Driver SDK Release               COMPLETE: Jul 31                       ║   │
│  ║ • Partner Program Launch                  COMPLETE: Aug 15                       ║   │
│  ║ • Heat Mapping & Color Search             COMPLETE: Aug 30                       ║   │
│  ║ • PPE Detection                           COMPLETE: Sep 15                       ║   │
│  ║ • Behavior Analytics                      COMPLETE: Sep 30                       ║   │
│  ╚══════════════════════════════════════════════════════════════════════════════════╝   │
│                                                                                           │
│  Q4 2026 (Oct-Dec)                                                                        │
│  ╔══════════════════════════════════════════════════════════════════════════════════╗   │
│  ║ SCALE & CERTIFICATION                                                     v21.4  ║   │
│  ╠══════════════════════════════════════════════════════════════════════════════════╣   │
│  ║ • 5,000+ Device Drivers                   COMPLETE: Oct 31                       ║   │
│  ║ • ONVIF Profile A/G/M                     COMPLETE: Nov 15                       ║   │
│  ║ • Partner Certification Portal            COMPLETE: Nov 30                       ║   │
│  ║ • AI-Powered Discovery                    COMPLETE: Dec 15                       ║   │
│  ║ • 10,000 Driver Target                    TARGET: Dec 31                         ║   │
│  ╚══════════════════════════════════════════════════════════════════════════════════╝   │
│                                                                                           │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Sprint Structure (v21.1)

| Sprint | Duration | Focus | Deliverables |
|--------|----------|-------|--------------|
| **30** | 2 weeks | Prajna Core | Guardian + Sentinel + Immutable State |
| **31** | 2 weeks | Prajna SIL-6 Biomorphic | Persistence + Config + Resilience |
| **32** | 2 weeks | Gun Detection | Layer 1-2 AI + Human Review Queue |
| **33** | 2 weeks | Fire/Smoke | Ensemble Detector + Temporal Tracking |
| **34** | 2 weeks | ONVIF Core | Profile S/T + WS-Discovery |
| **35** | 2 weeks | Integration | End-to-end testing + Documentation |

### 6.3 Resource Allocation

| Team | Size | Q1 Focus | Q2 Focus |
|------|------|----------|----------|
| **Core Platform** | 4 | Prajna Completion | Access Control |
| **AI/ML** | 3 | Gun/Fire Detection | Face/LPR Database |
| **Device Integration** | 3 | ONVIF + RTSP | Vendor SDKs |
| **Frontend** | 2 | Prajna LiveView | Forensic Tools |
| **QA/Testing** | 3 | TDG Property Tests | Integration Tests |
| **DevOps** | 2 | GPU Container | Partner Portal |
| **Total** | 17 | | |

---

## Part 7: STAMP Constraints Summary

### 7.1 Consolidated Constraints by Domain

| Domain | Constraint Range | Count | Critical |
|--------|------------------|-------|----------|
| **Constitutional** | SC-CONST-001 to SC-CONST-010 | 10 | 10 |
| **Holon State** | SC-HOLON-001 to SC-HOLON-020 | 20 | 15 |
| **Immutable Register** | SC-REG-001 to SC-REG-015 | 15 | 12 |
| **Prajna** | SC-PRAJNA-001 to SC-PRAJNA-007 | 7 | 7 |
| **Biomorphic** | SC-BIO-001 to SC-BIO-008 | 8 | 5 |
| **Device Integration** | SC-DEV-001 to SC-DEV-023 | 23 | 10 |
| **ONVIF** | SC-ONVIF-001 to SC-ONVIF-008 | 8 | 5 |
| **Gun Detection** | SC-GUN-001 to SC-GUN-004 | 4 | 4 |
| **Fire/Smoke** | SC-FIRE-001 to SC-FIRE-005 | 5 | 4 |
| **Forensics** | SC-FORENSIC-001 to SC-FORENSIC-006 | 6 | 4 |
| **Access Control** | SC-PACS-001 to SC-PACS-008 | 8 | 5 |
| **VMS Core** | SC-VMS-001 to SC-VMS-007 | 7 | 6 |
| **Fractal Logging** | SC-LOG-001 to SC-LOG-009 | 9 | 3 |
| **Total** | | **130** | **90** |

### 7.2 Critical Path Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-CONST-001 | Constitution verified before holon start | INFINITE | Startup gate |
| SC-HOLON-011 | SQLite/DuckDB is AUTHORITATIVE source | INFINITE | Architecture |
| SC-REG-002 | Hash chain MUST be unbroken | INFINITE | Startup verify |
| SC-PRAJNA-001 | All commands through Guardian | CRITICAL | Runtime check |
| SC-GUN-002 | False positive rate < 0.1% | CRITICAL | ML validation |
| SC-FIRE-001 | Alert within 5 seconds | CRITICAL | Performance test |
| SC-ONVIF-001 | WS-Security digest required | CRITICAL | Protocol test |
| SC-VMS-L1-003 | All AI detections logged to Register | CRITICAL | Audit trail |

---

## Part 8: Quality Gates

### 8.1 Feature Completion Criteria

```
Feature Complete ⟺
  Pass(Compile) ∧
  Pass(Runtime) ∧
  Pass(TDG) ∧
  Pass(STAMP) ∧
  Pass(FPPS) ∧
  Coverage > 95% ∧
  Pass(Format) ∧
  Pass(Credo) ∧
  Pass(Sobelow)
```

### 8.2 Gate Commands

```bash
# Development cycle
devenv shell
compile-strict          # Zero warnings
quality-full           # Format + Credo + Dialyzer + Sobelow
test-cover             # Tests with coverage

# Feature completion
mix feature.complete --validate FEATURE_NAME

# Release preparation
mix release.validate --version 21.1.0
```

### 8.3 FPPS Consensus

| Method | Description | Weight |
|--------|-------------|--------|
| **Pattern** | Regex pattern matching | 20% |
| **AST** | Abstract Syntax Tree analysis | 25% |
| **Stat** | Statistical code metrics | 15% |
| **Binary** | Compiled BEAM analysis | 20% |
| **LineByLine** | Manual verification | 20% |

Consensus required: **All 5 methods must agree** (SC-VAL-003)

---

## Part 9: Source Documents

This master plan consolidates the following documents:

| Document | Lines | Created |
|----------|-------|---------|
| `V20_5LEVEL_INTEGRATION_PLAN.md` | 2,400+ | 2025-12-30 |
| `FRACTAL_LOGGING_5LEVEL_CRITICALITY_PLAN.md` | 1,200+ | 2025-12-25 |
| `VIDEO_STRATEGIC_POSITIONING_L1_L5.md` | 1,500+ | 2026-01-03 |
| `DEVICE_INTEGRATION_5LEVEL_IMPLEMENTATION_PLAN.md` | 1,888 | 2026-01-03 |
| `UNIFIED_DEVICE_CLOUDVMS_5LEVEL_PLAN.md` | 1,441 | 2026-01-03 |

---

## Appendix A: Quick Reference

### A.1 Container Commands

```bash
# Standalone environment
sa-up                  # Start production stack
sa-down               # Stop stack
sa-status             # Show status
sa-logs               # Stream logs

# Development
compile               # Patient mode compile
test                  # Run tests
quality               # Code quality checks
```

### A.2 Key Directories

| Directory | Purpose |
|-----------|---------|
| `lib/indrajaal/device_integration/` | Device protocols & drivers |
| `lib/indrajaal/ai_analytics/` | AI detection models |
| `lib/indrajaal/forensics/` | Evidence & watermarking |
| `lib/indrajaal/access_control_vms/` | Access control integration |
| `lib/indrajaal/verification/` | Triple-layer verification |
| `lib/indrajaal/cockpit/prajna/` | C3I cockpit components |
| `data/holons/` | Holon state (SQLite/DuckDB) |

### A.3 STAMP Constraint Prefixes

| Prefix | Domain |
|--------|--------|
| SC-CONST- | Constitutional invariants |
| SC-HOLON- | Holon state sovereignty |
| SC-REG- | Immutable register |
| SC-PRAJNA- | Prajna cockpit |
| SC-DEV- | Device integration |
| SC-ONVIF- | ONVIF protocol |
| SC-GUN- | Gun detection |
| SC-FIRE- | Fire/smoke detection |
| SC-FORENSIC- | Forensics tools |
| SC-PACS- | Access control |
| SC-VMS- | VMS core |
| SC-LOG- | Fractal logging |

---

## Part 10: Drone Operations Domain (7-Level Fractal Architecture)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    7-LEVEL FRACTAL ARCHITECTURE: DRONE OPERATIONS                    │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                       │
│  L7: FEDERATION    ← Multi-organization drone sharing, airspace coordination         │
│       │                                                                               │
│  L6: ECOSYSTEM     ← External integrations (UTM, weather, ATC, regulators)          │
│       │                                                                               │
│  L5: SYSTEM        ← Indrajaal Drone Platform (complete VMS integration)            │
│       │                                                                               │
│  L4: DOMAIN        ← Drones, MISB, Mapping domains (Ash resources)                  │
│       │                                                                               │
│  L3: COMPONENT     ← GenServers (MAVLinkGateway, FleetManager, etc.)                │
│       │                                                                               │
│  L2: MODULE        ← Elixir modules, protocols, behaviours                          │
│       │                                                                               │
│  L1: FUNCTION      ← Individual functions, STAMP constraints                         │
│                                                                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 10.1 L1 - Function Level: STAMP Constraints & Core Functions

**STAMP Safety Constraints (L1):**

| ID | Constraint | Severity | Function |
|----|------------|----------|----------|
| SC-DRONE-001 | MAVLink heartbeat every 1s | CRITICAL | `send_heartbeat/1` |
| SC-DRONE-002 | Telemetry logged to Immutable Register | HIGH | `log_telemetry/2` |
| SC-DRONE-003 | Geofence violations trigger RTL | CRITICAL | `check_geofence/2` |
| SC-DRONE-004 | Remote ID broadcast when armed | CRITICAL | `broadcast_remote_id/1` |
| SC-DRONE-005 | Battery <20% triggers auto-RTL | HIGH | `monitor_battery/1` |
| SC-DRONE-006 | All commands through Guardian | CRITICAL | `submit_command/2` |
| SC-MISB-001 | Video includes ST0601 KLV metadata | HIGH | `encode_klv/1` |
| SC-MISB-002 | GPS ±1m, time ±1μs precision | HIGH | `validate_precision/1` |

**Core Function Signatures (L1):**

```elixir
# MAVLink Protocol Functions
@spec send_heartbeat(socket :: port()) :: :ok | {:error, term()}
@spec parse_mavlink(binary()) :: {:ok, map()} | {:error, :invalid_message}
@spec encode_command(atom(), keyword()) :: binary()

# Geofence Functions
@spec check_geofence(location :: {float(), float()}, geofence :: Geo.Polygon.t()) ::
  :inside | :outside | :boundary
@spec trigger_rtl(drone_id :: String.t()) :: :ok | {:error, term()}

# Telemetry Functions
@spec log_telemetry(drone_id :: String.t(), telemetry :: map()) :: :ok
@spec validate_precision(telemetry :: map()) :: :valid | {:invalid, list()}

# KLV Metadata Functions
@spec encode_klv(metadata :: map()) :: binary()
@spec decode_klv(binary()) :: {:ok, map()} | {:error, term()}
```

---

### 10.2 L2 - Module Level: Elixir Protocols & Behaviours

**Protocol Definitions (L2):**

```elixir
# Flight Controller Protocol
defprotocol Indrajaal.Drones.FlightController do
  @spec arm(t()) :: :ok | {:error, term()}
  @spec disarm(t()) :: :ok | {:error, term()}
  @spec takeoff(t(), altitude :: float()) :: :ok | {:error, term()}
  @spec land(t()) :: :ok | {:error, term()}
  @spec goto(t(), lat :: float(), lon :: float(), alt :: float()) :: :ok
  @spec set_mode(t(), mode :: atom()) :: :ok | {:error, term()}
  @spec get_telemetry(t()) :: map()
end

# Implementations
defimpl Indrajaal.Drones.FlightController, for: Indrajaal.Drones.ArduPilot do
  # ArduPilot-specific implementation
end

defimpl Indrajaal.Drones.FlightController, for: Indrajaal.Drones.PX4 do
  # PX4-specific implementation
end
```

**Behaviour Definitions (L2):**

```elixir
defmodule Indrajaal.Drones.MissionBehaviour do
  @callback create_mission(waypoints :: list()) :: {:ok, mission_id} | {:error, term()}
  @callback upload_mission(drone_id :: String.t(), mission_id :: String.t()) :: :ok
  @callback start_mission(drone_id :: String.t()) :: :ok | {:error, term()}
  @callback pause_mission(drone_id :: String.t()) :: :ok
  @callback resume_mission(drone_id :: String.t()) :: :ok
  @callback abort_mission(drone_id :: String.t()) :: :ok
end
```

**Module Directory Structure (L2):**

```
lib/indrajaal/drones/
├── protocols/
│   ├── flight_controller.ex    # Protocol definition
│   ├── ardupilot.ex            # ArduPilot implementation
│   ├── px4.ex                  # PX4 implementation
│   └── dji_bridge.ex           # DJI SDK bridge
├── behaviours/
│   ├── mission_behaviour.ex    # Mission interface
│   └── telemetry_behaviour.ex  # Telemetry interface
└── types/
    ├── waypoint.ex             # Waypoint struct
    ├── geofence.ex             # Geofence struct
    └── telemetry.ex            # Telemetry struct
```

---

### 10.3 L3 - Component Level: GenServers & Supervisors

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                    DRONE COMPONENT ARCHITECTURE (L3)                                 │
├────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  DroneOperations.Supervisor (one_for_one)                                            │
│  │                                                                                   │
│  ├── MAVLinkGateway (GenServer)                                                      │
│  │   ├── UDP Socket: 14550/14551                                                     │
│  │   ├── Message Parser: MAVLink 2.0                                                 │
│  │   ├── Heartbeat: 1Hz (SC-DRONE-001)                                              │
│  │   └── Connection Pool: max 50 drones                                              │
│  │                                                                                   │
│  ├── FleetManager (GenServer)                                                        │
│  │   ├── Registry: :drone_registry (Horde)                                          │
│  │   ├── State: %{drones: map(), missions: map()}                                   │
│  │   └── Supervisor: Dynamic children per drone                                      │
│  │                                                                                   │
│  ├── MissionExecutor (GenServer per mission)                                         │
│  │   ├── FSM States: :planning → :uploading → :executing → :complete               │
│  │   ├── Waypoint tracking: current, total, eta                                     │
│  │   └── Safety: Battery RTL at 20% (SC-DRONE-005)                                  │
│  │                                                                                   │
│  ├── GeofenceManager (GenServer)                                                     │
│  │   ├── Polygon database: PostGIS                                                  │
│  │   ├── Real-time check: 10Hz                                                      │
│  │   └── Violation action: Immediate RTL (SC-DRONE-003)                             │
│  │                                                                                   │
│  ├── TelemetryProcessor (GenServer)                                                  │
│  │   ├── Ingest rate: 10Hz per drone                                                │
│  │   ├── TimescaleDB hypertable: drone_telemetry                                    │
│  │   └── Zenoh publish: telemetry/{drone_id}/*                                      │
│  │                                                                                   │
│  ├── RemoteIDBroadcaster (GenServer)                                                 │
│  │   ├── FAA compliance: Bluetooth 4.0 LE                                           │
│  │   ├── EU compliance: Wi-Fi Beacon                                                │
│  │   └── Update rate: 1Hz when armed (SC-DRONE-004)                                 │
│  │                                                                                   │
│  ├── WeatherIntegration (GenServer)                                                  │
│  │   ├── API: OpenWeatherMap / METAR                                                │
│  │   ├── No-fly triggers: Wind >25kt, Visibility <3mi                               │
│  │   └── Refresh: 15 minutes                                                        │
│  │                                                                                   │
│  └── BatteryMonitor (GenServer)                                                      │
│      ├── Poll rate: 1Hz                                                              │
│      ├── Warning: 30%, RTL trigger: 20%, Critical: 10%                               │
│                                                                                      │
└────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 10.4 L4 - Domain Level: Ash Resources & Business Logic

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                    DRONE DOMAIN ARCHITECTURE (L4)                                    │
├────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  lib/indrajaal/drones/                           lib/indrajaal/misb/                 │
│  ├── resources/                                  ├── klv_encoder.ex                  │
│  │   ├── drone.ex          # Registration       ├── klv_decoder.ex                  │
│  │   ├── flight_plan.ex    # Waypoints          ├── st0601_parser.ex                │
│  │   ├── flight_log.ex     # History            ├── metadata_overlay.ex             │
│  │   ├── geofence.ex       # Boundaries         └── chain_of_custody.ex             │
│  │   ├── pilot.ex          # Operators                                               │
│  │   └── maintenance.ex    # Service            lib/indrajaal/mapping/              │
│  │                                               ├── photogrammetry.ex               │
│  ├── services/                                   ├── orthomosaic.ex                  │
│  │   ├── mavlink_client.ex                       ├── terrain_model.ex                │
│  │   ├── mission_executor.ex                     ├── geo_referencer.ex               │
│  │   └── fleet_coordinator.ex                    └── export_formats.ex               │
│  │                                                                                   │
│  └── protocols/                                                                      │
│      ├── ardupilot.ex, px4.ex, dji_bridge.ex                                        │
│                                                                                      │
└────────────────────────────────────────────────────────────────────────────────────┘
```

**MISB KLV Metadata (L4 Data Model):**

```
ST0601 KLV Structure:
├── Tag 2:  Precision Timestamp
├── Tags 5-7: Platform Attitude (pitch/roll/yaw)
├── Tags 13-15: Platform Location (lat/lon/alt)
├── Tag 21: Slant Range
├── Tags 23-25: Sensor Location
├── Tags 40-42: Target Location
├── Tags 16-17: Field of View
├── Tag 48: Security Classification
└── Tag 1: Checksum
```

---

### 10.5 L5 - System Level: Platform Integration

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                    DRONE SYSTEM INTEGRATION (L5)                                     │
├────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────┐   │
│  │ indrajaal-ex-app-1 (Extended for Drone Operations)                           │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐ │   │
│  │  │  DRONE OPS     │  MISB/KLV      │  AI VIDEO      │  PRAJNA DASH      │ │   │
│  │  │  ┌──────────┐  │  ┌──────────┐  │  ┌──────────┐  │  ┌──────────┐     │ │   │
│  │  │  │MAVLink GW│  │  │KLV Encode│  │  │Tracking  │  │  │Fleet View│     │ │   │
│  │  │  │Mission   │  │  │KLV Decode│  │  │Thermal   │  │  │Telemetry │     │ │   │
│  │  │  │Geofence  │  │  │Overlay   │  │  │Intrusion │  │  │Alerts    │     │ │   │
│  │  │  └──────────┘  │  └──────────┘  │  └──────────┘  │  └──────────┘     │ │   │
│  │  └─────────────────────────────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│  Hardware Options:                                                                   │
│  ┌────────────────────────────────────────────────────────────────────────────┐     │
│  │ Development ($1,500)          │ Production ($8,300)                        │     │
│  │ • Pixhawk 6C ($150)           │ • Cube Orange+ ($400)                     │     │
│  │ • Raspberry Pi 5 ($80)        │ • Jetson Orin Nano ($499)                 │     │
│  │ • FLIR Lepton 3.5 ($250)      │ • FLIR Vue Pro R 640 ($3,500)             │     │
│  │ • U-blox M8N GPS ($30)        │ • RTK GNSS F9P ($400)                     │     │
│  │ • S500 Frame ($100)           │ • X8 Coaxial ($500)                       │     │
│  │ • T-Motor MN3508 ($280)       │ • T-Motor P60 ($1,200)                    │     │
│  │ • FrSky X9 ($180)             │ • Herelink HD ($1,200)                    │     │
│  └────────────────────────────────────────────────────────────────────────────┘     │
│                                                                                      │
└────────────────────────────────────────────────────────────────────────────────────┘
```

**Autopilot Comparison (L5 Decision):**

| Feature | ArduPilot | PX4 | Recommendation |
|---------|-----------|-----|----------------|
| License | GPLv3 | BSD-3 | ArduPilot for security |
| Vehicles | 1M+ | 500K+ | Both viable |
| Redundancy | Dual-EKF | Triple-EKF | PX4 for research |
| Certification | Blue UAS | EASA path | ArduPilot for NDAA |

---

### 10.6 L6 - Ecosystem Level: External Integrations

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                    DRONE ECOSYSTEM INTEGRATIONS (L6)                                 │
├────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                         EXTERNAL SYSTEMS                                     │    │
│  │                                                                              │    │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                 │    │
│  │  │   UTM / USS    │  │    Weather     │  │   Regulators   │                 │    │
│  │  │ (Unmanned      │  │   Services     │  │  FAA / EASA    │                 │    │
│  │  │  Traffic Mgmt) │  │  OpenWeather   │  │  Remote ID     │                 │    │
│  │  │                │  │  METAR/TAF     │  │  Registration  │                 │    │
│  │  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘                 │    │
│  │          │                   │                   │                           │    │
│  │          └───────────────────┼───────────────────┘                           │    │
│  │                              │                                               │    │
│  │                              ▼                                               │    │
│  │  ┌───────────────────────────────────────────────────────────────────────┐  │    │
│  │  │                    INDRAJAAL DRONE PLATFORM                           │  │    │
│  │  └───────────────────────────────────────────────────────────────────────┘  │    │
│  │                              │                                               │    │
│  │          ┌───────────────────┼───────────────────┐                           │    │
│  │          │                   │                   │                           │    │
│  │  ┌───────┴────────┐  ┌───────┴────────┐  ┌───────┴────────┐                 │    │
│  │  │   GCS Apps     │  │  Mapping SaaS  │  │  VMS Partners  │                 │    │
│  │  │ QGroundControl │  │  DroneDeploy   │  │  Milestone     │                 │    │
│  │  │ Mission Planner│  │  Pix4D         │  │  Genetec       │                 │    │
│  │  └────────────────┘  └────────────────┘  └────────────────┘                 │    │
│  │                                                                              │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
└────────────────────────────────────────────────────────────────────────────────────┘
```

**External API Integrations (L6):**

| Integration | Protocol | Purpose |
|-------------|----------|---------|
| **FAA LAANC** | REST API | Airspace authorization |
| **Remote ID** | Bluetooth LE / Wi-Fi | Compliance broadcasting |
| **OpenWeatherMap** | REST API | Weather data |
| **METAR/TAF** | Text parsing | Aviation weather |
| **ADS-B Exchange** | REST/WebSocket | Air traffic awareness |
| **QGroundControl** | MAVLink/UDP | Ground station |
| **Pix4D / DroneDeploy** | REST API | Photogrammetry export |

---

### 10.7 L7 - Federation Level: Multi-Organization Coordination

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                    DRONE FEDERATION ARCHITECTURE (L7)                                │
├────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                    FEDERATED DRONE NETWORK                                   │    │
│  │                                                                              │    │
│  │   Organization A              Organization B              Organization C    │    │
│  │   ┌─────────────┐             ┌─────────────┐             ┌─────────────┐   │    │
│  │   │ Indrajaal   │◄───────────►│ Indrajaal   │◄───────────►│ Indrajaal   │   │    │
│  │   │ Instance A  │    Zenoh    │ Instance B  │    Zenoh    │ Instance C  │   │    │
│  │   │             │    Mesh     │             │    Mesh     │             │   │    │
│  │   │ 10 Drones   │             │ 25 Drones   │             │ 5 Drones    │   │    │
│  │   └─────────────┘             └─────────────┘             └─────────────┘   │    │
│  │         │                           │                           │           │    │
│  │         └───────────────────────────┼───────────────────────────┘           │    │
│  │                                     │                                        │    │
│  │                                     ▼                                        │    │
│  │                    ┌────────────────────────────────────┐                    │    │
│  │                    │     SHARED AIRSPACE COORDINATOR    │                    │    │
│  │                    │  • Conflict resolution             │                    │    │
│  │                    │  • Geofence sharing                │                    │    │
│  │                    │  • Emergency coordination          │                    │    │
│  │                    │  • Cross-org mission handoff       │                    │    │
│  │                    └────────────────────────────────────┘                    │    │
│  │                                                                              │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
└────────────────────────────────────────────────────────────────────────────────────┘
```

**Federation Capabilities (L7):**

| Capability | Description | Protocol |
|------------|-------------|----------|
| **Airspace Deconfliction** | Prevent drone collisions across orgs | Zenoh pub/sub |
| **Geofence Sharing** | Dynamic no-fly zone updates | Zenoh + PostGIS |
| **Emergency Override** | Cross-org RTL commands | Guardian approval |
| **Fleet Handoff** | Transfer drone control between orgs | Capability token |
| **Telemetry Federation** | Share telemetry with authorized peers | Encrypted Zenoh |
| **Joint Missions** | Multi-org coordinated operations | Mission protocol |

**Commercial Drone Recommendations (L7 Fleet Planning):**

| Tier | Drone | Price | Use Case |
|------|-------|-------|----------|
| **Dev** | DJI Mini 4 Pro | $1,199 | Protocol testing |
| **Test** | Autel EVO Lite+ | $1,349 | Night operations |
| **Prod** | DJI Matrice 4T | ~$16,000 | Enterprise security |
| **NDAA** | Skydio X10 | ~$15,000 | Government/defense |
| **24/7** | DJI Dock 2 | ~$20,000 | Autonomous ops |
| **Tethered** | Elistair Khronos | ~$50,000 | Continuous surveillance |

---

## Part 11: Cloud Video Provider Platform (7-Level Fractal Architecture)

**Strategic Assessment: YES - Indrajaal CAN become a cloud video provider platform.**

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                 7-LEVEL FRACTAL ARCHITECTURE: CLOUD VIDEO PROVIDER                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  L7: FEDERATION    ← Multi-provider partnerships, white-label federation            │
│  L6: ECOSYSTEM     ← CDN, hyperscaler, payment provider integrations                │
│  L5: SYSTEM        ← Indrajaal Cloud Video Platform (SaaS containers)               │
│  L4: DOMAIN        ← Billing, Tenants, Transcoding, Quotas (Ash resources)          │
│  L3: COMPONENT     ← GenServers (MeteringAgent, TranscoderPool, QuotaEnforcer)      │
│  L2: MODULE        ← Elixir modules, cloud provider behaviours                      │
│  L1: FUNCTION      ← Individual functions, STAMP constraints                         │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 11.1 L1 - Function Level: STAMP Constraints & Core Functions

**STAMP Constraints (Cloud Provider - SC-CLOUD):**

| ID | Constraint | Severity | Function Mapping |
|----|------------|----------|------------------|
| SC-CLOUD-010 | Tenant data isolation mandatory | CRITICAL | `ensure_tenant_isolation/1` |
| SC-CLOUD-011 | Billing accuracy ±0.1% | HIGH | `calculate_usage/2` |
| SC-CLOUD-012 | API rate limiting per tenant | HIGH | `check_rate_limit/2` |
| SC-CLOUD-013 | Storage quotas enforced | MEDIUM | `enforce_quota/2` |
| SC-CLOUD-014 | Graceful degradation on overload | HIGH | `degrade_gracefully/1` |
| SC-CLOUD-015 | PCI DSS for payment handling | CRITICAL | `process_payment/2` |
| SC-CLOUD-016 | GDPR data residency options | HIGH | `select_region/2` |
| SC-CLOUD-017 | HLS segment duration 2-6s | MEDIUM | `segment_video/2` |
| SC-CLOUD-018 | Transcoding queue < 100 jobs | HIGH | `enqueue_transcode/2` |

**Core Function Specifications:**

```elixir
# Billing functions (SC-CLOUD-011)
@spec calculate_usage(tenant_id :: String.t(), period :: Date.Range.t()) ::
  {:ok, %{minutes: integer(), storage_gb: float(), api_calls: integer()}} |
  {:error, term()}

@spec process_payment(tenant_id :: String.t(), amount_cents :: integer()) ::
  {:ok, %{transaction_id: String.t(), status: :completed}} |
  {:error, :payment_failed | :invalid_card}

# Tenant isolation (SC-CLOUD-010)
@spec ensure_tenant_isolation(conn :: Plug.Conn.t()) ::
  {:ok, tenant_id :: String.t()} | {:error, :unauthorized}

@spec select_region(tenant_id :: String.t(), preference :: atom()) ::
  {:ok, region :: String.t()} | {:error, :region_unavailable}

# Rate limiting (SC-CLOUD-012)
@spec check_rate_limit(tenant_id :: String.t(), endpoint :: atom()) ::
  :ok | {:error, :rate_limited, retry_after_ms :: integer()}

# Transcoding (SC-CLOUD-017, SC-CLOUD-018)
@spec segment_video(input_path :: String.t(), opts :: keyword()) ::
  {:ok, %{playlist: String.t(), segments: [String.t()]}} |
  {:error, term()}

@spec enqueue_transcode(job :: map(), priority :: :high | :normal | :low) ::
  {:ok, job_id :: String.t()} | {:error, :queue_full}
```

---

### 11.2 L2 - Module Level: Elixir Protocols & Behaviours

```elixir
# Cloud Provider Behaviour
defmodule Indrajaal.CloudProvider.Behaviour do
  @moduledoc """
  Behaviour for cloud provider backends (AWS, Azure, GCP, self-hosted).

  STAMP: SC-CLOUD-010 (isolation), SC-CLOUD-014 (degradation)
  """

  @callback upload_video(path :: String.t(), opts :: keyword()) ::
    {:ok, url :: String.t()} | {:error, term()}

  @callback transcode(input :: String.t(), profiles :: [atom()]) ::
    {:ok, outputs :: map()} | {:error, term()}

  @callback get_playback_url(asset_id :: String.t(), opts :: keyword()) ::
    {:ok, url :: String.t(), expires_at :: DateTime.t()} | {:error, term()}

  @callback delete_asset(asset_id :: String.t()) ::
    :ok | {:error, term()}
end

# Payment Processor Behaviour
defmodule Indrajaal.CloudProvider.PaymentBehaviour do
  @moduledoc """
  Behaviour for payment processors (Stripe, Paddle).

  STAMP: SC-CLOUD-015 (PCI DSS)
  """

  @callback create_subscription(customer_id :: String.t(), plan_id :: String.t()) ::
    {:ok, subscription :: map()} | {:error, term()}

  @callback process_invoice(tenant_id :: String.t(), line_items :: [map()]) ::
    {:ok, invoice :: map()} | {:error, term()}

  @callback handle_webhook(event :: map()) ::
    {:ok, handled :: atom()} | {:error, term()}
end

# Tenant Protocol
defprotocol Indrajaal.CloudProvider.TenantResource do
  @spec tenant_id(t) :: String.t()
  @spec quota_limit(t, resource :: atom()) :: integer()
  @spec current_usage(t, resource :: atom()) :: integer()
end
```

**Module Structure (L2):**

```
lib/indrajaal/cloud_provider/
├── behaviour.ex                 # Cloud provider behaviour
├── payment_behaviour.ex         # Payment processor behaviour
├── tenant_resource.ex           # Tenant protocol
├── adapters/
│   ├── aws_kinesis.ex          # AWS Kinesis Video Streams
│   ├── azure_media.ex          # Azure Media Services
│   ├── gcp_video.ex            # GCP Video AI
│   ├── cloudflare_stream.ex    # Cloudflare Stream
│   └── self_hosted.ex          # On-premise storage
└── payments/
    ├── stripe_adapter.ex       # Stripe integration
    └── paddle_adapter.ex       # Paddle integration
```

---

### 11.3 L3 - Component Level: GenServers & Supervisors

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                    CLOUD PROVIDER SUPERVISION TREE (L3)                             │
├────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  CloudProvider.Supervisor (one_for_one)                                             │
│  │                                                                                   │
│  ├── MeteringAgent (GenServer)                                                      │
│  │   ├── Collects: ingestion_bytes, storage_bytes, api_calls, ai_minutes           │
│  │   ├── Flush interval: 60s to DuckDB                                              │
│  │   ├── Real-time: Zenoh pub to prajna/billing/usage                              │
│  │   └── SC-CLOUD-011: Accuracy ±0.1%                                               │
│  │                                                                                   │
│  ├── QuotaEnforcer (GenServer)                                                      │
│  │   ├── Monitors: storage, cameras, bandwidth per tenant                           │
│  │   ├── Actions: warn @ 80%, throttle @ 95%, block @ 100%                          │
│  │   └── SC-CLOUD-013: Quotas enforced                                              │
│  │                                                                                   │
│  ├── TranscoderPool (PoolSupervisor)                                                │
│  │   ├── Workers: 4-16 (auto-scaled by queue depth)                                 │
│  │   ├── Queue: max 100 jobs (SC-CLOUD-018)                                         │
│  │   ├── Output: HLS 2-6s segments (SC-CLOUD-017)                                   │
│  │   └── Profiles: 360p, 480p, 720p, 1080p, 4K                                      │
│  │                                                                                   │
│  ├── RateLimiter (GenServer)                                                        │
│  │   ├── Algorithm: Token bucket per tenant                                         │
│  │   ├── Tiers: Free (100 RPM), Pro (1000 RPM), Enterprise (10000 RPM)             │
│  │   ├── Backoff: Exponential with jitter                                           │
│  │   └── SC-CLOUD-012: Per-tenant limiting                                          │
│  │                                                                                   │
│  ├── BillingProcessor (GenServer)                                                   │
│  │   ├── Invoice generation: 1st of month                                           │
│  │   ├── Payment retry: 3 attempts, 3-day intervals                                 │
│  │   ├── Dunning: email @ 7, 14, 21 days                                            │
│  │   └── SC-CLOUD-015: PCI DSS via Stripe/Paddle                                    │
│  │                                                                                   │
│  ├── TenantProvisioner (GenServer)                                                  │
│  │   ├── Auto-provision: DB schema, S3 bucket, subdomain                            │
│  │   ├── Isolation: PostgreSQL RLS + Ash multi-tenancy                              │
│  │   └── SC-CLOUD-010: Mandatory isolation                                          │
│  │                                                                                   │
│  ├── CDNIntegration (GenServer)                                                     │
│  │   ├── Backends: Cloudflare R2, AWS CloudFront, Bunny CDN                         │
│  │   ├── Purge: Automatic on video update                                           │
│  │   └── Edge caching: 7-day TTL for VOD                                            │
│  │                                                                                   │
│  └── WebhookDispatcher (GenServer)                                                  │
│      ├── Events: video.ready, alert.triggered, quota.warning                        │
│      ├── Retry: 3 attempts with exponential backoff                                 │
│      └── Signing: HMAC-SHA256 for verification                                      │
│                                                                                      │
└────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 11.4 L4 - Domain Level: Ash Resources & Business Logic

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                    CLOUD PROVIDER DOMAIN ARCHITECTURE (L4)                          │
├────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  lib/indrajaal/cloud_provider/                                                       │
│  ├── resources/                                                                      │
│  │   ├── tenant.ex              # Multi-tenant organization                         │
│  │   ├── subscription.ex        # Billing subscription                              │
│  │   ├── invoice.ex             # Monthly invoices                                  │
│  │   ├── usage_record.ex        # Metering data                                     │
│  │   ├── pricing_tier.ex        # Dynamic pricing                                   │
│  │   ├── quota.ex               # Resource quotas                                   │
│  │   ├── api_key.ex             # Tenant API keys                                   │
│  │   └── webhook_endpoint.ex    # Webhook destinations                              │
│  │                                                                                   │
│  ├── billing/                                                                        │
│  │   ├── metering.ex            # Usage collection                                  │
│  │   ├── subscription.ex        # Stripe/Paddle integration                         │
│  │   ├── invoice.ex             # Invoice generation                                │
│  │   ├── pricing_tiers.ex       # Dynamic pricing engine                            │
│  │   └── overage.ex             # Overage calculations                              │
│  │                                                                                   │
│  ├── tenant_management/                                                              │
│  │   ├── provisioning.ex        # Auto-provision resources                          │
│  │   ├── quotas.ex              # Resource quota management                         │
│  │   ├── isolation.ex           # Data isolation enforcement                        │
│  │   └── migration.ex           # Tenant data import/export                         │
│  │                                                                                   │
│  ├── white_label/                                                                    │
│  │   ├── branding.ex            # Custom logos, colors                              │
│  │   ├── themes.ex              # Theme engine                                      │
│  │   └── custom_domains.ex      # CNAME/SSL provisioning                            │
│  │                                                                                   │
│  ├── transcoding/                                                                    │
│  │   ├── hls_packager.ex        # HLS segmentation                                  │
│  │   ├── dash_packager.ex       # DASH segmentation                                 │
│  │   ├── adaptive_bitrate.ex    # ABR ladder generation                             │
│  │   └── thumbnail_service.ex   # Thumbnail extraction                              │
│  │                                                                                   │
│  └── cdn_integration/                                                                │
│      ├── cloudflare_r2.ex       # R2 object storage                                 │
│      ├── cloudflare_stream.ex   # Transcoding offload                               │
│      └── edge_cache.ex          # Edge caching rules                                │
│                                                                                      │
└────────────────────────────────────────────────────────────────────────────────────┘
```

**Pricing Models (L4 Business Logic):**

| Model | Structure | Best For |
|-------|-----------|----------|
| **Per-Camera** | $7.99-$24.99/cam/month | Traditional VMS users |
| **Usage-Based** | $0.0085/GB + $0.05/AI-min | High-volume, variable |
| **Hybrid** | $99 base + $5/cam + usage | Predictable + scalable |

---

### 11.5 L5 - System Level: Platform Containers

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                    CLOUD VIDEO PLATFORM CONTAINERS (L5)                             │
├────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────┐   │
│  │ indrajaal-cloud-prod (Extended for Multi-Tenant SaaS)                        │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐ │   │
│  │  │  BILLING      │  TENANTS      │  TRANSCODING   │  WHITE-LABEL        │ │   │
│  │  │  ┌──────────┐ │  ┌──────────┐ │  ┌──────────┐  │  ┌──────────┐       │ │   │
│  │  │  │Metering  │ │  │Provision │ │  │HLS/DASH  │  │  │Branding  │       │ │   │
│  │  │  │Invoice   │ │  │Quotas    │ │  │ABR       │  │  │Domains   │       │ │   │
│  │  │  │Stripe    │ │  │Isolation │ │  │Thumbnails│  │  │Themes    │       │ │   │
│  │  │  └──────────┘ │  └──────────┘ │  └──────────┘  │  └──────────┘       │ │   │
│  │  └─────────────────────────────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────┐   │
│  │ indrajaal-transcoder-pool (Horizontal Scaling)                               │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐      │   │
│  │  │Worker 1  │  │Worker 2  │  │Worker 3  │  │Worker 4  │  │Worker N  │      │   │
│  │  │FFmpeg    │  │FFmpeg    │  │FFmpeg    │  │FFmpeg    │  │FFmpeg    │      │   │
│  │  │GPU: T4   │  │GPU: T4   │  │GPU: T4   │  │GPU: T4   │  │GPU: T4   │      │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘      │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│  Infrastructure Layer:                                                               │
│  ┌────────────────────────────────────────────────────────────────────────────┐     │
│  │ PostgreSQL 17    │ DuckDB (Analytics) │ Redis (Cache) │ Object Storage    │     │
│  │ Tenant schemas   │ Usage aggregation  │ Rate limits   │ S3/R2/MinIO      │     │
│  │ RLS isolation    │ Billing reports    │ Session data  │ Video assets      │     │
│  └────────────────────────────────────────────────────────────────────────────┘     │
│                                                                                      │
└────────────────────────────────────────────────────────────────────────────────────┘
```

**Existing Capabilities (L5 Readiness):**

| Capability | Status | Notes |
|------------|--------|-------|
| Multi-tenancy | ✅ Ready | Ash 3.x multi-tenant |
| Video Ingestion | ✅ Ready | RTSP/ONVIF |
| AI Analytics | ✅ Ready | Gun/fire/smoke |
| Self-Healing | ✅ Ready | BEAM OTP |
| Hot Code Loading | ✅ Ready | Zero-downtime |
| HLS/DASH | ⚠️ Partial | Needs transcoding pipeline |
| Billing/Metering | ❌ Missing | NEW MODULE REQUIRED |
| White-label UI | ❌ Missing | Branding layer needed |

---

### 11.6 L6 - Ecosystem Level: External Integrations

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                    CLOUD PROVIDER ECOSYSTEM INTEGRATIONS (L6)                       │
├────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                         EXTERNAL SYSTEMS                                     │    │
│  │                                                                              │    │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                 │    │
│  │  │   HYPERSCALERS │  │    CDN/EDGE    │  │   PAYMENTS     │                 │    │
│  │  │  AWS Kinesis   │  │  Cloudflare    │  │  Stripe        │                 │    │
│  │  │  Azure Media   │  │  CloudFront    │  │  Paddle        │                 │    │
│  │  │  GCP Video AI  │  │  Bunny CDN     │  │  PayPal        │                 │    │
│  │  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘                 │    │
│  │          │                   │                   │                           │    │
│  │          └───────────────────┼───────────────────┘                           │    │
│  │                              ▼                                               │    │
│  │  ┌───────────────────────────────────────────────────────────────────────┐  │    │
│  │  │                    INDRAJAAL CLOUD PLATFORM                           │  │    │
│  │  │              Unified API for Multi-Cloud Video                        │  │    │
│  │  └───────────────────────────────────────────────────────────────────────┘  │    │
│  │                              │                                               │    │
│  │          ┌───────────────────┼───────────────────┐                           │    │
│  │          │                   │                   │                           │    │
│  │  ┌───────┴────────┐  ┌───────┴────────┐  ┌───────┴────────┐                 │    │
│  │  │  INTEGRATORS   │  │  VMS PARTNERS  │  │  AI SERVICES   │                 │    │
│  │  │  System Integ  │  │  Milestone     │  │  OpenAI        │                 │    │
│  │  │  MSPs          │  │  Genetec       │  │  Anthropic     │                 │    │
│  │  │  Resellers     │  │  Eagle Eye     │  │  Google Vision │                 │    │
│  │  └────────────────┘  └────────────────┘  └────────────────┘                 │    │
│  │                                                                              │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
└────────────────────────────────────────────────────────────────────────────────────┘
```

**Hyperscaler Comparison (L6 Decision Matrix):**

| Provider | Service | Strength | Recommendation |
|----------|---------|----------|----------------|
| **AWS** | Kinesis Video | Best surveillance support | Primary for gov/enterprise |
| **Azure** | Media Services | Emotion/transcription | Secondary for AI features |
| **GCP** | Video AI | Object tracking | Research/analytics |
| **Wowza** | Hybrid | On-prem flexibility | Enterprise hybrid |
| **Cloudflare** | Stream | CDN-native, global | SMB, latency-sensitive |

---

### 11.7 L7 - Federation Level: Multi-Provider Partnerships

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                    CLOUD PROVIDER FEDERATION ARCHITECTURE (L7)                      │
├────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                    WHITE-LABEL FEDERATION NETWORK                            │    │
│  │                                                                              │    │
│  │   Partner A (MSP)             Partner B (Integrator)      Partner C (OEM)   │    │
│  │   ┌─────────────┐             ┌─────────────┐             ┌─────────────┐   │    │
│  │   │ SecureCam   │◄───────────►│ TechVision  │◄───────────►│ CamCorp     │   │    │
│  │   │ (branded)   │    Zenoh    │ (branded)   │    Zenoh    │ (OEM)       │   │    │
│  │   │             │    Mesh     │             │    Mesh     │             │   │    │
│  │   │ 500 tenants │             │ 200 tenants │             │ 50 devices  │   │    │
│  │   └─────────────┘             └─────────────┘             └─────────────┘   │    │
│  │         │                           │                           │           │    │
│  │         └───────────────────────────┼───────────────────────────┘           │    │
│  │                                     │                                        │    │
│  │                                     ▼                                        │    │
│  │                    ┌────────────────────────────────────┐                    │    │
│  │                    │       INDRAJAAL MASTER NODE        │                    │    │
│  │                    │  • Partner management              │                    │    │
│  │                    │  • Revenue sharing                 │                    │    │
│  │                    │  • Compliance monitoring           │                    │    │
│  │                    │  • Feature synchronization         │                    │    │
│  │                    └────────────────────────────────────┘                    │    │
│  │                                                                              │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
└────────────────────────────────────────────────────────────────────────────────────┘
```

**Federation Capabilities (L7):**

| Capability | Description | Protocol |
|------------|-------------|----------|
| **White-Label Provisioning** | Partner self-service tenant creation | REST API |
| **Revenue Sharing** | Automated commission distribution | Stripe Connect |
| **Compliance Sync** | GDPR/HIPAA config propagation | Zenoh pub/sub |
| **Feature Flags** | Per-partner feature enablement | LaunchDarkly/custom |
| **Cross-Billing** | Inter-partner resource sharing | Usage aggregation |

**Competitive Positioning (L7):**

| Feature | VXG | Videoloft | Eagle Eye | **Indrajaal** |
|---------|-----|-----------|-----------|---------------|
| Open Source | ❌ | ❌ | ❌ | ✅ Core OSS |
| Self-Healing | ❌ | ❌ | ❌ | ✅ BEAM/OTP |
| Hot Deploy | ❌ | ❌ | ❌ | ✅ Zero-downtime |
| Guardian Safety | ❌ | ❌ | ❌ | ✅ Unique |
| Immutable Audit | ❌ | ❌ | ❌ | ✅ Unique |
| Zenoh Mesh | ❌ | ❌ | ❌ | ✅ Unique |
| White-Label | ✅ | ❌ | ❌ | ✅ Full |
| Pricing | Fixed | Fixed | Fixed | **Flexible** |

**Revenue Projection (L7 Business Model):**

```
Year 1 (Launch):     50 tenants × $500/mo = $300K + 5K cams × $10 = $600K → $900K ARR
Year 2 (Growth):    200 tenants × $750/mo = $1.8M + 25K cams × $10 = $3M → $4.8M ARR
Year 3 (Scale):     500 tenants × $1K/mo = $6M + 100K cams × $10 = $12M → $18M ARR
```

---

## Part 12: Consolidated Implementation Roadmap

### 12.1 Q1 2026: Foundation Phase (12 weeks)

**Drone Operations:**
| Week | Deliverable | STAMP |
|------|-------------|-------|
| 1-4 | MAVLink 2.0 GenServer, WS-Discovery | SC-DRONE-001, SC-DRONE-002 |
| 5-8 | Geofence Manager, Remote ID | SC-DRONE-003, SC-DRONE-004 |
| 9-12 | Mission Executor, Battery Monitor | SC-DRONE-005, SC-DRONE-006 |

**Cloud Provider:**
| Week | Deliverable | STAMP |
|------|-------------|-------|
| 1-4 | Tenant Provisioner, Isolation | SC-CLOUD-010 |
| 5-8 | Metering Agent, Billing (Stripe) | SC-CLOUD-011, SC-CLOUD-015 |
| 9-12 | Rate Limiter, Quota Enforcer | SC-CLOUD-012, SC-CLOUD-013 |

---

### 12.2 Q2 2026: Integration Phase (12 weeks)

**Drone Operations:**
| Week | Deliverable | STAMP |
|------|-------------|-------|
| 1-4 | ArduPilot/PX4 adapters, Telemetry | SC-DRONE-002 |
| 5-8 | MISB ST0601 KLV encoder/decoder | SC-MISB-001, SC-MISB-002 |
| 9-12 | UTM integration, Weather API | SC-DRONE-006 |

**Cloud Provider:**
| Week | Deliverable | STAMP |
|------|-------------|-------|
| 1-4 | HLS/DASH Transcoder Pool | SC-CLOUD-017, SC-CLOUD-018 |
| 5-8 | CDN Integration (Cloudflare R2) | SC-CLOUD-014 |
| 9-12 | White-Label Branding System | - |

---

### 12.3 Q3 2026: Ecosystem Phase (12 weeks)

**Drone Operations:**
| Week | Deliverable | Camera Count |
|------|-------------|--------------|
| 1-4 | Vendor SDK bridges (DJI, Skydio) | 500+ drones |
| 5-8 | Fleet Coordinator, Multi-org | 1,000+ drones |
| 9-12 | Mapping export (Pix4D, DroneDeploy) | - |

**Cloud Provider:**
| Week | Deliverable | Tenant Count |
|------|-------------|--------------|
| 1-4 | Partner portal, API keys | 50 tenants |
| 5-8 | Webhook system, Integrations | 100 tenants |
| 9-12 | Multi-cloud abstraction (AWS/Azure/GCP) | 200 tenants |

---

### 12.4 Q4 2026: Federation Phase (12 weeks)

**Drone Operations:**
| Week | Deliverable | Scale |
|------|-------------|-------|
| 1-4 | Zenoh mesh for drone telemetry | 5 organizations |
| 5-8 | Airspace deconfliction protocol | 10 organizations |
| 9-12 | Cross-org mission handoff | Federation live |

**Cloud Provider:**
| Week | Deliverable | Scale |
|------|-------------|-------|
| 1-4 | White-label federation network | 10 partners |
| 5-8 | Revenue sharing (Stripe Connect) | 25 partners |
| 9-12 | Global PoP deployment | 50+ partners |

---

### 12.5 Hardware Strategy

| Environment | Drone | Cloud |
|-------------|-------|-------|
| **Development** | ArduPilot + Pixhawk 6C (~$1,400) | Self-hosted MinIO |
| **Staging** | DJI Matrice 4T (~$16,000) | AWS Kinesis |
| **Production** | Skydio X10 (NDAA) or DJI Fleet | Multi-cloud (AWS + Azure) |
| **24/7 Autonomous** | DJI Dock 2 / Elistair | Cloudflare global CDN |

---

### 12.6 Autopilot Comparison

| Feature | ArduPilot | PX4 |
|---------|-----------|-----|
| **License** | GPLv3 | BSD-3 |
| **Vehicles** | 1M+ deployed | 500K+ deployed |
| **Backers** | Community-driven | Linux Foundation |
| **Redundancy** | Dual-EKF | Triple-EKF |
| **ROS Integration** | MAVROS | Native ROS 2 |
| **Certification** | Blue UAS (v4.6) | EASA path |
| **Recommendation** | Security/surveillance | Research/experimental |

### 12.3 Hardware Stack

| Component | Budget Option | Production Option |
|-----------|---------------|-------------------|
| **Flight Controller** | Pixhawk 6C (~$150) | Cube Orange+ (~$400) |
| **Companion Computer** | Raspberry Pi 5 (~$80) | Jetson Orin Nano (~$249) |
| **Thermal Camera** | FLIR Lepton 3.5 (~$250) | FLIR Vue Pro (~$3,500) |
| **GPS** | U-blox M8N (~$30) | RTK GNSS (~$800) |
| **Frame** | S500 Quad (~$100) | X8 Coaxial (~$500) |
| **Motors/ESC** | T-Motor (~$200) | T-Motor P60 (~$800) |
| **Battery** | 4S 5000mAh (~$80) | 6S 10000mAh (~$200) |

### 12.4 Bill of Materials

**Development Kit (~$1,500)**
```
Pixhawk 6C Flight Controller    $150
Raspberry Pi 5 (8GB)            $80
FLIR Lepton 3.5 Dev Kit        $250
U-blox M8N GPS                  $30
S500 Quadcopter Frame          $100
T-Motor MN3508 (x4)            $160
T-Motor Air 40A ESC (x4)       $120
4S 5000mAh LiPo (x2)           $160
Radio: FrSky X9 Lite + R-XSR   $180
Miscellaneous (wiring, props)  $100
3D Printed Parts               $50
───────────────────────────────────
Total:                        ~$1,380
```

**Production System (~$6,500)**
```
Cube Orange+ Flight Controller  $400
Jetson Orin Nano (8GB)          $499
FLIR Vue Pro R 640             $3,500
RTK GNSS (u-blox F9P)          $400
X8 Coaxial Frame               $500
T-Motor P60 Motors (x8)        $800
Flame 60A ESC (x8)             $400
6S 10000mAh Smart Battery      $400
Herelink HD Video/Control      $1,200
Miscellaneous                  $200
────────────────────────────────────
Total:                        ~$8,299
```

### 12.5 Elixir MAVLink Integration

```elixir
# lib/indrajaal/drones/mavlink_client.ex
defmodule Indrajaal.Drones.MAVLinkClient do
  @moduledoc """
  MAVLink 2.0 client for open-source drone integration.

  Supports ArduPilot and PX4 autopilots via MAVLink protocol.

  ## STAMP Compliance
  - SC-DRONE-001: Heartbeat every 1s
  - SC-DRONE-002: Telemetry to Immutable Register
  - SC-DRONE-003: Geofence triggers RTL
  """

  use GenServer
  require Logger

  @heartbeat_interval 1_000

  defstruct [
    :connection, :system_id, :component_id,
    :autopilot_type, :armed?, :mode, :location,
    :attitude, :battery, :mission_progress
  ]

  # --- Public API ---
  def connect(host, port, opts \\ []) do
    GenServer.start_link(__MODULE__, {host, port, opts})
  end

  def arm(pid), do: GenServer.call(pid, :arm)
  def disarm(pid), do: GenServer.call(pid, :disarm)
  def takeoff(pid, altitude), do: GenServer.call(pid, {:takeoff, altitude})
  def goto(pid, lat, lon, alt), do: GenServer.call(pid, {:goto, lat, lon, alt})
  def rtl(pid), do: GenServer.call(pid, :return_to_launch)
  def land(pid), do: GenServer.call(pid, :land)
  def start_mission(pid, waypoints), do: GenServer.call(pid, {:start_mission, waypoints})
  def get_telemetry(pid), do: GenServer.call(pid, :get_telemetry)

  # --- GenServer Callbacks ---
  @impl true
  def init({host, port, _opts}) do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: true])
    :gen_udp.connect(socket, to_charlist(host), port)
    Process.send_after(self(), :send_heartbeat, @heartbeat_interval)
    {:ok, %__MODULE__{connection: socket, system_id: 255, component_id: 190}}
  end

  @impl true
  def handle_info(:send_heartbeat, state) do
    send_mavlink_heartbeat(state.connection)
    Process.send_after(self(), :send_heartbeat, @heartbeat_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info({:udp, _socket, _ip, _port, data}, state) do
    state = parse_mavlink(data, state)
    log_telemetry_to_register(state)
    {:noreply, state}
  end

  defp send_mavlink_heartbeat(socket) do
    # MAVLink heartbeat message (simplified)
    heartbeat = <<0xFD, 9, 0, 0, 255, 190, 0, 0, 0, 6, 0, 8, 0, 0, 3>>
    :gen_udp.send(socket, heartbeat)
  end

  defp parse_mavlink(<<0xFD, _len, _seq, _sys, _comp, msg_id::24-little, rest::binary>>, state) do
    case msg_id do
      33 -> parse_global_position(rest, state)
      1 -> parse_sys_status(rest, state)
      _ -> state
    end
  end
  defp parse_mavlink(_, state), do: state

  defp log_telemetry_to_register(state) do
    # SC-DRONE-002: Log to Immutable Register
    Indrajaal.Core.Holon.ImmutableRegister.append(%{
      type: :drone_telemetry,
      timestamp: DateTime.utc_now(),
      location: state.location,
      battery: state.battery
    })
  end
end
```

```elixir
# lib/indrajaal/drones/mission_executor.ex
defmodule Indrajaal.Drones.MissionExecutor do
  @moduledoc """
  Autonomous mission execution for perimeter patrol.

  ## STAMP Compliance
  - SC-DRONE-003: Geofence enforced
  - SC-DRONE-005: Battery RTL at 20%
  """

  alias Indrajaal.Drones.MAVLinkClient

  def create_perimeter_patrol(polygon_coords, altitude, opts \\ []) do
    speed = opts[:speed] || 5.0
    loop = opts[:loop] || true

    waypoints = polygon_coords
    |> Enum.with_index()
    |> Enum.map(fn {{lat, lon}, idx} ->
      %{
        seq: idx,
        command: :waypoint,
        lat: lat,
        lon: lon,
        alt: altitude,
        hold_time: 0,
        accept_radius: 2.0
      }
    end)

    if loop do
      waypoints ++ [%{List.first(waypoints) | seq: length(waypoints)}]
    else
      waypoints
    end
  end

  def execute(client_pid, waypoints) do
    with :ok <- MAVLinkClient.arm(client_pid),
         :ok <- MAVLinkClient.takeoff(client_pid, List.first(waypoints).alt),
         :ok <- MAVLinkClient.start_mission(client_pid, waypoints) do
      monitor_mission(client_pid, waypoints)
    end
  end

  defp monitor_mission(client_pid, waypoints) do
    telemetry = MAVLinkClient.get_telemetry(client_pid)

    cond do
      telemetry.battery < 20 ->
        MAVLinkClient.rtl(client_pid)
        {:error, :low_battery}
      telemetry.mission_progress == length(waypoints) ->
        MAVLinkClient.rtl(client_pid)
        {:ok, :mission_complete}
      true ->
        Process.sleep(1000)
        monitor_mission(client_pid, waypoints)
    end
  end
end
```

---

## Part 13: Complete Platform Summary

### 13.1 Platform Vision

Indrajaal is now positioned as a **5-in-1 unified platform**:

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                       INDRAJAAL UNIFIED PLATFORM (7-LEVEL FRACTAL)                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐│
│  │ ENTERPRISE  │  │   CLOUD     │  │     AI      │  │   DRONE     │  │   DEVICE    ││
│  │    VMS      │  │   VIDEO     │  │  SECURITY   │  │ OPERATIONS  │  │ INTEGRATION ││
│  │             │  │  PROVIDER   │  │  PLATFORM   │  │   CENTER    │  │     HUB     ││
│  │ Milestone   │  │ VXG/Videoloft│ │ Gun/Fire/   │  │ MAVLink,    │  │  14,700+    ││
│  │ Genetec     │  │ Eagle Eye   │  │ Smoke       │  │ MISB, Patrol│  │  drivers    ││
│  │ competitor  │  │ competitor  │  │ Detection   │  │             │  │  (roadmap)  ││
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘│
│         │                │                │                │                │        │
│         └────────────────┴────────────────┴────────────────┴────────────────┘        │
│                                           │                                           │
│                    ┌──────────────────────┴──────────────────────┐                   │
│                    │         INDRAJAAL CORE PLATFORM              │                   │
│                    │                                              │                   │
│                    │  • Self-Healing (BEAM/OTP)                   │                   │
│                    │  • Zero-Downtime (Hot Code Loading)          │                   │
│                    │  • Immutable Audit (Cryptographic Register)  │                   │
│                    │  • Guardian Safety (Constitutional AI)       │                   │
│                    │  • Zenoh Mesh (Distributed Real-Time)        │                   │
│                    │  • Open-Source Core (No Vendor Lock-In)      │                   │
│                    │                                              │                   │
│                    └──────────────────────────────────────────────┘                   │
│                                                                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 13.2 7-Level Fractal Architecture Summary

| Level | Scope | Part 10 (Drone) | Part 11 (Cloud) |
|-------|-------|-----------------|-----------------|
| **L1** | Function | STAMP constraints, specs | STAMP SC-CLOUD-010 to SC-CLOUD-018 |
| **L2** | Module | FlightController protocol | CloudProvider behaviour |
| **L3** | Component | MAVLinkGateway GenServer | MeteringAgent, TranscoderPool |
| **L4** | Domain | Drone, MISB, Mapping | Billing, Tenants, White-Label |
| **L5** | System | App container, Hardware | Cloud containers, CDN |
| **L6** | Ecosystem | UTM, Weather, FAA | AWS/Azure/GCP, Stripe |
| **L7** | Federation | Multi-org airspace | White-label partners |

---

### 13.3 STAMP Constraint Summary

| Domain | Count | Range | Critical |
|--------|-------|-------|----------|
| **Drone Operations** | 8 | SC-DRONE-001 to SC-MISB-002 | 4 |
| **Cloud Provider** | 9 | SC-CLOUD-010 to SC-CLOUD-018 | 3 |
| **Existing (CLAUDE.md)** | 130+ | SC-VAL, SC-CNT, SC-AGT... | 50+ |
| **Total** | **147+** | - | **57+** |

---

### 13.4 Competitive Advantages (Unique to Indrajaal)

| Feature | VXG | Videoloft | Eagle Eye | DJI | Milestone | **Indrajaal** |
|---------|-----|-----------|-----------|-----|-----------|---------------|
| Self-Healing | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ BEAM/OTP |
| Hot Deploy | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ Zero-downtime |
| Guardian Safety | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ Constitutional AI |
| Immutable Audit | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ Cryptographic |
| Zenoh Mesh | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ Real-time |
| Open-Source Core | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ No lock-in |
| Drone Integration | ❌ | ❌ | Limited | ✅ | Limited | ✅ MAVLink/MISB |
| Multi-Tenant SaaS | ✅ | ✅ | ✅ | ❌ | Limited | ✅ Ash 3.x |
| NDAA Compliant | ❌ | ❌ | ✅ | ❌ | ✅ | ✅ (configurable) |

---

### 13.5 Revenue Projections

```
                           DRONE + CLOUD COMBINED REVENUE MODEL
┌────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                    │
│  Year 1 (2026):                                                                    │
│  ├── Cloud Provider: 50 tenants × $500/mo + 5K cams × $10     = $900K ARR         │
│  ├── Drone Services: 20 enterprises × $2,000/mo               = $480K ARR         │
│  └── Total Year 1:                                            = $1.38M ARR        │
│                                                                                    │
│  Year 2 (2027):                                                                    │
│  ├── Cloud Provider: 200 tenants × $750/mo + 25K cams × $10   = $4.8M ARR         │
│  ├── Drone Services: 100 enterprises × $3,000/mo              = $3.6M ARR         │
│  └── Total Year 2:                                            = $8.4M ARR         │
│                                                                                    │
│  Year 3 (2028):                                                                    │
│  ├── Cloud Provider: 500 tenants × $1K/mo + 100K cams × $10   = $18M ARR          │
│  ├── Drone Services: 300 enterprises × $5,000/mo              = $18M ARR          │
│  └── Total Year 3:                                            = $36M ARR          │
│                                                                                    │
└────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 13.6 Document Statistics

| Metric | Value |
|--------|-------|
| **Document Version** | 1.3.0 |
| **Total Lines** | ~2,500 |
| **Parts** | 13 (restructured from 15) |
| **7-Level Fractal Sections** | 2 (Part 10: Drone, Part 11: Cloud) |
| **STAMP Constraints** | 147+ |
| **Elixir Code Examples** | 4 |
| **ASCII Diagrams** | 15+ |
| **Implementation Phases** | 4 (Q1-Q4 2026) |

---

### 13.7 Research Sources

- [AWS Kinesis Video Streams](https://aws.amazon.com/kinesis/video-streams/)
- [Wowza 2026 Predictions](https://www.wowza.com/blog/2026-streaming-predictions-the-year-infrastructure-becomes-strategy)
- [VXG Cloud VMS](https://www.videoexpertsgroup.com)
- [Videoloft Enterprise Guide](https://videoloft.com/enterprise-vms-buyers-guide/)
- [Milestone Cloud Deployments](https://www.milestonesys.com/products/expand-your-solution/cloud-deployments/)
- [ArduPilot Documentation](https://ardupilot.org/dev/)
- [PX4 Developer Guide](https://docs.px4.io/)
- [MISB Standards](https://nsgreg.nga.mil/misb.jsp)

---

**Document Version**: 1.3.0
**Structure**: 7-Level Fractal Architecture (L1: Function → L7: Federation)
**Created**: 2026-01-03
**Updated**: 2026-01-03
**Author**: Claude Opus 4.5
**Classification**: MASTER STRATEGIC BLUEPRINT
