# Unified Device Integration & Cloud VMS Feature Parity Plan

**Version**: 1.0.0 | **Date**: 2026-01-03 | **Status**: PROPOSED
**STAMP Compliance**: SC-DEV-*, SC-VMS-*, SC-AI-*, SC-PACS-*
**Target**: Feature Parity with Milestone/Eagle Eye/3dEye by Q4 2026

---

## Executive Summary

This comprehensive 5-level plan addresses two strategic imperatives:

1. **Device Integration** - Building 10,000+ device driver ecosystem (matching Milestone)
2. **Cloud VMS Feature Parity** - Implementing missing features to compete with 3dEye, Eagle Eye, Verkada

### Strategic Goals

| Goal | Current | Target | Timeline |
|------|---------|--------|----------|
| Device Drivers | ~50 generic | 10,000+ | Q4 2026 |
| AI Analytics | 14 types | 25+ types | Q3 2026 |
| Gun Detection | None | Triple-layer | Q1 2026 |
| Fire/Smoke | None | 90%+ accuracy | Q1 2026 |
| Access Control | None | Full PACS integration | Q2 2026 |
| Forensic Tools | None | Watermarking + Timeline | Q2 2026 |

### Unique Indrajaal Differentiators (Keep & Enhance)

| Differentiator | Competitor Status | Strategic Value |
|----------------|-------------------|-----------------|
| **Immutable Audit Trail** | None have | Forensic admissibility |
| **BEAM Self-Healing** | None have | 99.999% uptime |
| **Constitutional Safety** | None have | Regulatory compliance |
| **Pre-Roll Evidence Buffer** | None native | Alarm verification |
| **Zenoh P2P Mesh** | All hierarchical | No single point failure |
| **Guardian Veto** | None have | Safety-critical operations |

---

## Part 1: L1 - System Context Architecture

### 1.1 Unified Security Platform Vision

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        INDRAJAAL UNIFIED SECURITY PLATFORM                       │
│                   "Evidence You Can Trust - Safety You Can Count On"             │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│    ┌──────────────────────────────────────────────────────────────────────┐     │
│    │                      PHYSICAL DEVICES (10,000+)                       │     │
│    │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐  │     │
│    │  │IP Cams │ │Thermal │ │Sensors │ │Readers │ │Panels  │ │ I/O    │  │     │
│    │  │(ONVIF) │ │(FLIR)  │ │(Motion)│ │(Access)│ │(Alarm) │ │(Relay) │  │     │
│    │  └───┬────┘ └───┬────┘ └───┬────┘ └───┬────┘ └───┬────┘ └───┬────┘  │     │
│    └──────┼──────────┼──────────┼──────────┼──────────┼──────────┼────────┘     │
│           │          │          │          │          │          │              │
│    ┌──────▼──────────▼──────────▼──────────▼──────────▼──────────▼────────┐     │
│    │                    DEVICE INTEGRATION LAYER                           │     │
│    │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐     │     │
│    │  │  Discovery  │ │  Protocols  │ │   Drivers   │ │ Connection  │     │     │
│    │  │  (WS-Disc)  │ │(ONVIF/RTSP) │ │ (Hikvision) │ │    Pool     │     │     │
│    │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘     │     │
│    └────────────────────────────────┬─────────────────────────────────────┘     │
│                                     │                                            │
│    ┌────────────────────────────────▼─────────────────────────────────────┐     │
│    │                     AI ANALYTICS ENGINE                               │     │
│    │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐         │     │
│    │  │  GUN    │ │  FIRE   │ │  FACE   │ │  LPR    │ │  HEAT   │         │     │
│    │  │DETECTION│ │  SMOKE  │ │DATABASE │ │DATABASE │ │  MAP    │         │     │
│    │  │(Triple) │ │(Ensemble)│ │(Search) │ │(Vehicle)│ │(Dwell)  │         │     │
│    │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘         │     │
│    │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐         │     │
│    │  │ MOTION  │ │INTRUSION│ │LOITERING│ │ CROWD   │ │  PPE    │         │     │
│    │  │DETECTION│ │  ZONE   │ │DETECTION│ │ COUNT   │ │DETECTION│         │     │
│    │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘         │     │
│    └────────────────────────────────┬─────────────────────────────────────┘     │
│                                     │                                            │
│    ┌────────────────────────────────▼─────────────────────────────────────┐     │
│    │                      UNIFIED VMS CORE                                 │     │
│    │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐     │     │
│    │  │   VIDEO     │ │   ACCESS    │ │  EVIDENCE   │ │  FORENSIC   │     │     │
│    │  │ MANAGEMENT  │ │  CONTROL    │ │  TIMELINE   │ │ WATERMARK   │     │     │
│    │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘     │     │
│    │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐     │     │
│    │  │  PRE-ROLL   │ │  IMMUTABLE  │ │  GUARDIAN   │ │  SENTINEL   │     │     │
│    │  │   BUFFER    │ │  REGISTER   │ │   SAFETY    │ │   HEALTH    │     │     │
│    │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘     │     │
│    └────────────────────────────────┬─────────────────────────────────────┘     │
│                                     │                                            │
│    ┌────────────────────────────────▼─────────────────────────────────────┐     │
│    │                        CLIENT LAYER                                   │     │
│    │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐     │     │
│    │  │   PRAJNA    │ │    WEB      │ │   MOBILE    │ │   REST      │     │     │
│    │  │   COCKPIT   │ │   PORTAL    │ │    APP      │ │    API      │     │     │
│    │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘     │     │
│    └──────────────────────────────────────────────────────────────────────┘     │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Competitor Feature Gap Matrix (L1 View)

| Feature Category | Milestone | 3dEye | Eagle Eye | Indrajaal Current | Indrajaal Target |
|------------------|-----------|-------|-----------|-------------------|------------------|
| **Device Ecosystem** |
| Device Drivers | 14,700+ | 1,000s | 10,000+ | ~50 | 10,000+ |
| ONVIF Profile S/T | Yes | Yes | Yes | Partial | Full |
| Auto-Discovery | WS-Discovery | Cloud | Cloud | None | Multi-method |
| **AI Analytics** |
| Gun Detection | 3rd party | No | Triple-layer | No | Triple-layer |
| Fire/Smoke | 3rd party | Yes | 3rd party | No | Ensemble AI |
| Face Recognition | Yes | Yes | Yes | Basic | Full DB |
| LPR/ALPR | Yes | Yes | Yes | Basic | Full DB |
| Heat Mapping | Yes | Yes | Yes | No | Yes |
| Color Search | No | Yes | No | No | Yes |
| PPE Detection | 3rd party | Yes | 3rd party | No | Yes |
| **Access Control** |
| Native PACS | No | No | Brivo | No | Full |
| Unified Interface | MIP SDK | No | Yes | No | Yes |
| Event Correlation | Yes | Yes | Yes | No | Yes |
| **Forensics** |
| Video Synopsis | BriefCam | No | No | No | Evidence Timeline |
| Watermarking | No | No | No | No | Yes |
| Chain of Custody | Basic | Cloud | Cloud | Immutable | Immutable+ |
| **Architecture** |
| Self-Healing | No | No | No | Yes | Yes |
| Constitutional | No | No | No | Yes | Yes |
| Pre-Roll Buffer | No | No | No | Yes | Yes |
| P2P Mesh | No | No | No | Yes | Yes |

### 1.3 STAMP Constraints (L1)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-VMS-L1-001 | Gun detection MUST achieve <0.1% false positive rate | CRITICAL |
| SC-VMS-L1-002 | Fire/smoke detection MUST alert within 5 seconds | CRITICAL |
| SC-VMS-L1-003 | All AI detections MUST be logged to Immutable Register | CRITICAL |
| SC-VMS-L1-004 | Access events MUST correlate with video within 1 second | HIGH |
| SC-VMS-L1-005 | Evidence Timeline MUST preserve original timestamps | CRITICAL |
| SC-VMS-L1-006 | Forensic watermarks MUST survive re-encoding | HIGH |
| SC-VMS-L1-007 | Device discovery MUST NOT expose network externally | HIGH |

---

## Part 2: L2 - Container Architecture

### 2.1 Enhanced Container Model

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        CONTAINER ARCHITECTURE (L2)                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                    indrajaal-ex-app-1 (Primary Container)               │    │
│  │                                                                          │    │
│  │  ┌──────────────────────────────────────────────────────────────────┐   │    │
│  │  │                   DEVICE INTEGRATION SUPERVISOR                   │   │    │
│  │  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐     │   │    │
│  │  │  │ Discovery  │ │ Protocol   │ │  Driver    │ │ Connection │     │   │    │
│  │  │  │   Pool     │ │   Pool     │ │   Pool     │ │    Pool    │     │   │    │
│  │  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘     │   │    │
│  │  └──────────────────────────────────────────────────────────────────┘   │    │
│  │                                                                          │    │
│  │  ┌──────────────────────────────────────────────────────────────────┐   │    │
│  │  │                    VIDEO MANAGEMENT SUPERVISOR                    │   │    │
│  │  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐     │   │    │
│  │  │  │  Stream    │ │ Recording  │ │  Pre-Roll  │ │  Evidence  │     │   │    │
│  │  │  │  Manager   │ │  Manager   │ │   Buffer   │ │  Timeline  │     │   │    │
│  │  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘     │   │    │
│  │  └──────────────────────────────────────────────────────────────────┘   │    │
│  │                                                                          │    │
│  │  ┌──────────────────────────────────────────────────────────────────┐   │    │
│  │  │                    ACCESS CONTROL SUPERVISOR                      │   │    │
│  │  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐     │   │    │
│  │  │  │  Reader    │ │   Door     │ │ Credential │ │   Event    │     │   │    │
│  │  │  │  Manager   │ │  Manager   │ │   Store    │ │ Correlator │     │   │    │
│  │  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘     │   │    │
│  │  └──────────────────────────────────────────────────────────────────┘   │    │
│  │                                                                          │    │
│  │  ┌──────────────────────────────────────────────────────────────────┐   │    │
│  │  │                    FORENSICS SUPERVISOR                           │   │    │
│  │  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐     │   │    │
│  │  │  │ Watermark  │ │  Chain of  │ │  Export    │ │  Redact    │     │   │    │
│  │  │  │  Engine    │ │  Custody   │ │  Manager   │ │  Engine    │     │   │    │
│  │  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘     │   │    │
│  │  └──────────────────────────────────────────────────────────────────┘   │    │
│  │                                                                          │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                    indrajaal-ai-prod (GPU Container) - NEW              │    │
│  │                                                                          │    │
│  │  ┌──────────────────────────────────────────────────────────────────┐   │    │
│  │  │                    AI ANALYTICS SUPERVISOR                        │   │    │
│  │  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐     │   │    │
│  │  │  │   GUN      │ │   FIRE     │ │   FACE     │ │    LPR     │     │   │    │
│  │  │  │ DETECTION  │ │   SMOKE    │ │    DB      │ │    DB      │     │   │    │
│  │  │  │ (ZeroEyes) │ │ (Ensemble) │ │ (Indexed)  │ │ (Vehicles) │     │   │    │
│  │  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘     │   │    │
│  │  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐     │   │    │
│  │  │  │   HEAT     │ │   COLOR    │ │    PPE     │ │  BEHAVIOR  │     │   │    │
│  │  │  │   MAP      │ │  SEARCH    │ │ DETECTION  │ │  ANALYSIS  │     │   │    │
│  │  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘     │   │    │
│  │  └──────────────────────────────────────────────────────────────────┘   │    │
│  │                                                                          │    │
│  │  FLAME Pool Integration (Dynamic GPU Scaling)                            │    │
│  │  ├── GPU 0: Gun Detection (always reserved)                             │    │
│  │  ├── GPU 1-N: Dynamic allocation based on load                          │    │
│  │  └── Fallback: CPU-based inference for overflow                         │    │
│  │                                                                          │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                    indrajaal-db-prod (Storage)                          │    │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                     │    │
│  │  │ PostgreSQL   │ │   DuckDB     │ │   SQLite     │                     │    │
│  │  │ (Business)   │ │  (Analytics) │ │  (Holon)     │                     │    │
│  │  │ + TimescaleDB│ │  Face/LPR DB │ │  State       │                     │    │
│  │  └──────────────┘ └──────────────┘ └──────────────┘                     │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                    indrajaal-verification (NEW - Human Review)          │    │
│  │  ┌──────────────────────────────────────────────────────────────────┐   │    │
│  │  │              VERIFICATION OPERATIONS CENTER (VOC)                │   │    │
│  │  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐     │   │    │
│  │  │  │   Queue    │ │  Review    │ │   Alert    │ │   Audit    │     │   │    │
│  │  │  │  Manager   │ │   Console  │ │  Dispatch  │ │    Log     │     │   │    │
│  │  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘     │   │    │
│  │  └──────────────────────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Resource Allocation

| Container | CPU | Memory | GPU | Storage | Network |
|-----------|-----|--------|-----|---------|---------|
| indrajaal-ex-app-1 | 8 cores | 16GB | - | 500GB | 10Gbps |
| indrajaal-ai-prod | 16 cores | 64GB | 4x RTX 4090 | 2TB | 25Gbps |
| indrajaal-db-prod | 8 cores | 32GB | - | 10TB | 10Gbps |
| indrajaal-verification | 4 cores | 8GB | - | 100GB | 1Gbps |
| indrajaal-obs-prod | 4 cores | 16GB | - | 1TB | 10Gbps |

### 2.3 STAMP Constraints (L2)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-VMS-L2-001 | AI container MUST have dedicated GPU for gun detection | CRITICAL |
| SC-VMS-L2-002 | Verification console MUST be isolated from AI inference | HIGH |
| SC-VMS-L2-003 | Face/LPR databases MUST be encrypted at rest | CRITICAL |
| SC-VMS-L2-004 | Container restart MUST NOT lose in-flight detections | CRITICAL |
| SC-VMS-L2-005 | FLAME pool MUST scale within 2 seconds | HIGH |

---

## Part 3: L3 - Domain Architecture

### 3.1 New Domain Model

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           DOMAIN ARCHITECTURE (L3)                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                    DEVICE INTEGRATION DOMAIN (NEW)                       │    │
│  │                    lib/indrajaal/device_integration/                     │    │
│  │                                                                          │    │
│  │  Resources: DiscoveredDevice, DeviceDriver, ProtocolConfig, Credential   │    │
│  │  Services:  Discovery, Protocol, DriverRegistry, ConnectionPool          │    │
│  │  Events:    device_discovered, device_connected, device_offline          │    │
│  │                                                                          │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                    AI ANALYTICS DOMAIN (ENHANCED)                        │    │
│  │                    lib/indrajaal/ai_analytics/                           │    │
│  │                                                                          │    │
│  │  ┌───────────────────────────────────────────────────────────────┐       │    │
│  │  │                    DETECTION SUBDOMAINS                        │       │    │
│  │  │                                                                │       │    │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │       │    │
│  │  │  │ GUN_DETECTION│  │ FIRE_SMOKE   │  │ FACE_DB      │         │       │    │
│  │  │  │              │  │              │  │              │         │       │    │
│  │  │  │ • Detection  │  │ • Detection  │  │ • Face       │         │       │    │
│  │  │  │ • Verification│ │ • Ensemble   │  │ • FaceMatch  │         │       │    │
│  │  │  │ • Alert      │  │ • Alert      │  │ • FaceSearch │         │       │    │
│  │  │  └──────────────┘  └──────────────┘  └──────────────┘         │       │    │
│  │  │                                                                │       │    │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │       │    │
│  │  │  │ LPR_DB       │  │ HEAT_MAP     │  │ COLOR_SEARCH │         │       │    │
│  │  │  │              │  │              │  │              │         │       │    │
│  │  │  │ • Plate      │  │ • HeatZone   │  │ • ColorQuery │         │       │    │
│  │  │  │ • Vehicle    │  │ • DwellTime  │  │ • Appearance │         │       │    │
│  │  │  │ • PlateSearch│  │ • Trajectory │  │ • ObjectMatch│         │       │    │
│  │  │  └──────────────┘  └──────────────┘  └──────────────┘         │       │    │
│  │  │                                                                │       │    │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │       │    │
│  │  │  │ PPE_DETECTION│  │ BEHAVIOR     │  │ CROWD        │         │       │    │
│  │  │  │              │  │              │  │              │         │       │    │
│  │  │  │ • PPECheck   │  │ • Loitering  │  │ • CrowdCount │         │       │    │
│  │  │  │ • Violation  │  │ • Fighting   │  │ • Density    │         │       │    │
│  │  │  │ • Compliance │  │ • Falling    │  │ • Flow       │         │       │    │
│  │  │  └──────────────┘  └──────────────┘  └──────────────┘         │       │    │
│  │  │                                                                │       │    │
│  │  └───────────────────────────────────────────────────────────────┘       │    │
│  │                                                                          │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                    ACCESS CONTROL DOMAIN (NEW)                           │    │
│  │                    lib/indrajaal/access_control_vms/                     │    │
│  │                                                                          │    │
│  │  Resources: Door, Credential, AccessEvent, Schedule, Zone               │    │
│  │  Services:  DoorController, CredentialManager, EventCorrelator          │    │
│  │  Events:    door_opened, access_granted, access_denied, forced_door     │    │
│  │  Integration: Video linkage, Pre-roll trigger, Audit trail              │    │
│  │                                                                          │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                    FORENSICS DOMAIN (NEW)                                │    │
│  │                    lib/indrajaal/forensics/                              │    │
│  │                                                                          │    │
│  │  ┌───────────────────────────────────────────────────────────────┐       │    │
│  │  │                    EVIDENCE TIMELINE                           │       │    │
│  │  │       (Milestone BriefCam Alternative - NOT patented)         │       │    │
│  │  │                                                                │       │    │
│  │  │  • Cluster detected objects by time                           │       │    │
│  │  │  • Generate summary video with timestamps                      │       │    │
│  │  │  • Searchable by object type, color, direction                │       │    │
│  │  │  • Link to original footage with frame accuracy               │       │    │
│  │  └───────────────────────────────────────────────────────────────┘       │    │
│  │                                                                          │    │
│  │  Resources: EvidencePackage, WatermarkProfile, ChainOfCustody           │    │
│  │  Services:  WatermarkEngine, ExportManager, RedactionEngine             │    │
│  │  Events:    evidence_exported, watermark_applied, redaction_applied     │    │
│  │                                                                          │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                    VERIFICATION DOMAIN (NEW)                             │    │
│  │                    lib/indrajaal/verification/                           │    │
│  │                                                                          │    │
│  │  Triple-Layer Verification (ZeroEyes Pattern):                          │    │
│  │  1. AI Detection (Layer 1) - Automated, <1 second                       │    │
│  │  2. AI Verification (Layer 2) - Second model, confidence boost          │    │
│  │  3. Human Review (Layer 3) - Trained operator, <5 seconds              │    │
│  │                                                                          │    │
│  │  Resources: VerificationRequest, OperatorSession, ReviewDecision       │    │
│  │  Services:  QueueManager, AlertDispatcher, OperatorConsole              │    │
│  │                                                                          │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Gun Detection Architecture (ZeroEyes-Inspired)

```elixir
# lib/indrajaal/ai_analytics/gun_detection/detection.ex
defmodule Indrajaal.AIAnalytics.GunDetection.Detection do
  @moduledoc """
  Triple-layer gun detection system.

  ## Architecture (ZeroEyes Pattern)
  1. **Layer 1 - AI Detection**: YOLO-based weapon recognition
     - 36,000 images/second throughput
     - <1 second detection time
     - Trained on firearm dataset

  2. **Layer 2 - AI Verification**: Secondary model confirmation
     - Different architecture (EfficientDet)
     - Reduces false positives by 80%
     - Confidence threshold: 0.85

  3. **Layer 3 - Human Verification**: Trained operator review
     - Military/LE veteran operators (recommended)
     - <5 second review time
     - Final decision authority

  ## STAMP Compliance
  - SC-GUN-001: Detection latency < 1 second
  - SC-GUN-002: False positive rate < 0.1%
  - SC-GUN-003: All detections logged to Immutable Register
  - SC-GUN-004: Human review REQUIRED before external alert
  """

  use Ash.Resource,
    domain: Indrajaal.AIAnalytics,
    data_layer: AshPostgres.DataLayer

  alias Indrajaal.AIAnalytics.GunDetection.Verification

  attributes do
    uuid_primary_key :id

    attribute :camera_id, :uuid, allow_nil?: false
    attribute :frame_timestamp, :utc_datetime_usec, allow_nil?: false
    attribute :frame_data, :binary, allow_nil?: false
    attribute :bounding_box, :map, allow_nil?: false  # {x, y, width, height}

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
    attribute :layer3_decision, :atom, constraints: [one_of: [:confirmed, :rejected, :escalate]]
    attribute :layer3_reviewed_at, :utc_datetime_usec
    attribute :layer3_review_time_ms, :integer

    # Final status
    attribute :status, :atom,
      constraints: [one_of: [:detected, :verifying, :confirmed, :rejected, :alerted]],
      default: :detected

    attribute :alert_dispatched_at, :utc_datetime_usec
    attribute :immutable_register_hash, :string

    timestamps()
  end

  relationships do
    belongs_to :camera, Indrajaal.Video.Camera
    belongs_to :operator, Indrajaal.Accounts.User
    belongs_to :tenant, Indrajaal.Multitenancy.Tenant
  end

  actions do
    defaults [:read]

    create :detect do
      accept [:camera_id, :frame_timestamp, :frame_data, :bounding_box]
      accept [:layer1_confidence, :layer1_detected_at]

      change fn changeset, _context ->
        # Auto-trigger Layer 2 verification if confidence > 0.7
        if Ash.Changeset.get_attribute(changeset, :layer1_confidence) > 0.7 do
          Ash.Changeset.after_action(changeset, fn _changeset, detection ->
            Verification.trigger_layer2(detection)
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
        # Auto-queue for human review if Layer 2 confirms
        if Ash.Changeset.get_attribute(changeset, :layer2_confidence) > 0.85 do
          Ash.Changeset.change_attribute(changeset, :status, :verifying)
          |> Ash.Changeset.after_action(fn _changeset, detection ->
            Verification.queue_human_review(detection)
            {:ok, detection}
          end)
        else
          Ash.Changeset.change_attribute(changeset, :status, :rejected)
        end
      end
    end

    update :human_verify do
      accept [:layer3_operator_id, :layer3_decision, :layer3_review_time_ms]

      change set_attribute(:layer3_reviewed_at, &DateTime.utc_now/0)
      change fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :layer3_decision) do
          :confirmed ->
            Ash.Changeset.change_attribute(changeset, :status, :confirmed)
            |> Ash.Changeset.after_action(fn _changeset, detection ->
              # Dispatch alert to authorities
              dispatch_alert(detection)
              # Log to Immutable Register
              log_to_register(detection)
              {:ok, detection}
            end)

          :rejected ->
            Ash.Changeset.change_attribute(changeset, :status, :rejected)

          :escalate ->
            Ash.Changeset.change_attribute(changeset, :status, :verifying)
            |> Ash.Changeset.after_action(fn _changeset, detection ->
              Verification.escalate_to_supervisor(detection)
              {:ok, detection}
            end)
        end
      end
    end
  end

  code_interface do
    domain Indrajaal.AIAnalytics

    define :detect, action: :detect
    define :verify_layer2, action: :verify_layer2
    define :human_verify, action: :human_verify
  end
end
```

### 3.3 Fire/Smoke Detection Architecture (NYU Ensemble Pattern)

```elixir
# lib/indrajaal/ai_analytics/fire_smoke/ensemble_detector.ex
defmodule Indrajaal.AIAnalytics.FireSmoke.EnsembleDetector do
  @moduledoc """
  Ensemble-based fire and smoke detection.

  ## Architecture (NYU Fire Research Pattern)
  - Multiple AI models must AGREE before confirming fire
  - Temporal tracking eliminates false positives (red cars, sunsets)
  - 92.6% accuracy in eliminating false detections

  ## Models Used
  1. Scaled-YOLOv4 (80.6% accuracy, 16ms per frame)
  2. EfficientDet-D2 (78.1% accuracy, 19ms per frame)
  3. Temporal consistency tracker (10-frame agreement)

  ## STAMP Compliance
  - SC-FIRE-001: Alert within 5 seconds of visual confirmation
  - SC-FIRE-002: False positive rate < 1%
  - SC-FIRE-003: Cover all 5 NFPA fire classes
  - SC-FIRE-004: Log all detections to Immutable Register
  """

  use GenServer
  require Logger

  @models [:scaled_yolov4, :efficientdet_d2]
  @agreement_threshold 2  # Both models must agree
  @temporal_frames 10     # Track over 10 frames
  @confidence_threshold 0.75

  defstruct [
    :camera_id,
    :model_results,
    :temporal_buffer,
    :confirmed_fires,
    :last_detection
  ]

  def start_link(camera_id) do
    GenServer.start_link(__MODULE__, camera_id, name: via_tuple(camera_id))
  end

  def analyze_frame(camera_id, frame_data, timestamp) do
    GenServer.cast(via_tuple(camera_id), {:analyze, frame_data, timestamp})
  end

  @impl true
  def init(camera_id) do
    state = %__MODULE__{
      camera_id: camera_id,
      model_results: %{},
      temporal_buffer: :queue.new(),
      confirmed_fires: [],
      last_detection: nil
    }
    {:ok, state}
  end

  @impl true
  def handle_cast({:analyze, frame_data, timestamp}, state) do
    # Run both models in parallel
    tasks = for model <- @models do
      Task.async(fn -> run_model(model, frame_data) end)
    end

    results = Task.await_many(tasks, 5_000)

    # Update state with results
    model_results = Enum.zip(@models, results) |> Map.new()
    state = %{state | model_results: model_results}

    # Check for agreement
    case check_ensemble_agreement(model_results) do
      {:fire_detected, detections} ->
        # Add to temporal buffer
        state = add_to_temporal_buffer(state, {timestamp, detections})

        # Check temporal consistency
        if temporal_consistency_confirmed?(state) do
          confirm_fire(state, detections, timestamp)
        else
          {:noreply, state}
        end

      :no_detection ->
        # Clear temporal buffer if no detection
        state = decay_temporal_buffer(state)
        {:noreply, state}
    end
  end

  defp check_ensemble_agreement(model_results) do
    fire_detections = model_results
    |> Enum.filter(fn {_model, result} ->
      result.detected && result.confidence > @confidence_threshold
    end)

    if length(fire_detections) >= @agreement_threshold do
      {:fire_detected, fire_detections}
    else
      :no_detection
    end
  end

  defp temporal_consistency_confirmed?(state) do
    buffer_size = :queue.len(state.temporal_buffer)

    if buffer_size >= @temporal_frames do
      # Check if detection persists across frames (not transient like red car)
      all_frames = :queue.to_list(state.temporal_buffer)
      consistent_detections = Enum.count(all_frames, fn {_ts, detections} ->
        length(detections) > 0
      end)

      # 80% of frames must show fire
      consistent_detections / buffer_size >= 0.8
    else
      false
    end
  end

  defp confirm_fire(state, detections, timestamp) do
    Logger.critical("FIRE CONFIRMED: Camera #{state.camera_id} at #{timestamp}")

    # Create detection record
    detection = %{
      camera_id: state.camera_id,
      timestamp: timestamp,
      fire_type: classify_fire_type(detections),
      confidence: average_confidence(detections),
      ensemble_agreement: length(detections),
      bounding_boxes: extract_bounding_boxes(detections)
    }

    # Alert immediately (< 5 seconds SLA)
    dispatch_fire_alert(detection)

    # Log to Immutable Register
    log_to_immutable_register(detection)

    # Update state
    state = %{state |
      confirmed_fires: [detection | state.confirmed_fires],
      last_detection: timestamp,
      temporal_buffer: :queue.new()
    }

    {:noreply, state}
  end

  defp classify_fire_type(detections) do
    # NFPA fire classes: A (ordinary), B (flammable liquid), C (electrical), D (metal), K (cooking)
    # Default classification based on visual characteristics
    :nfpa_class_a
  end
end
```

### 3.4 Access Control Integration Architecture

```elixir
# lib/indrajaal/access_control_vms/event_correlator.ex
defmodule Indrajaal.AccessControlVMS.EventCorrelator do
  @moduledoc """
  Correlates access control events with video footage.

  ## Integration Pattern (Brivo/Eagle Eye Style)
  - Access event → Instant video lookup
  - Pre-roll buffer provides context before event
  - Post-event recording continues for N seconds
  - Unified timeline view in Prajna Cockpit

  ## STAMP Compliance
  - SC-PACS-001: Event-to-video correlation < 1 second
  - SC-PACS-002: Pre-roll buffer minimum 30 seconds
  - SC-PACS-003: All correlations logged to audit trail
  """

  use GenServer
  alias Indrajaal.Video.PreRoll.BufferManager
  alias Indrajaal.Video.Recording.Manager, as: RecordingManager

  @pre_event_seconds 30
  @post_event_seconds 60

  def correlate_event(access_event) do
    GenServer.call(__MODULE__, {:correlate, access_event})
  end

  @impl true
  def handle_call({:correlate, event}, _from, state) do
    # Find associated cameras for this door/reader
    cameras = find_associated_cameras(event.door_id)

    correlations = for camera <- cameras do
      # Get pre-roll buffer (30 seconds before event)
      pre_roll = BufferManager.get_buffer(
        camera.id,
        event.timestamp,
        @pre_event_seconds
      )

      # Start recording for post-event
      {:ok, recording_id} = RecordingManager.start_event_recording(
        camera.id,
        event.id,
        @post_event_seconds
      )

      %{
        event_id: event.id,
        camera_id: camera.id,
        pre_roll_clip_id: pre_roll.clip_id,
        recording_id: recording_id,
        correlated_at: DateTime.utc_now()
      }
    end

    # Log correlation to Immutable Register
    log_correlation(event, correlations)

    {:reply, {:ok, correlations}, state}
  end

  defp find_associated_cameras(door_id) do
    # Query camera-door associations
    Indrajaal.Devices.list_cameras_for_door(door_id)
  end
end
```

### 3.5 STAMP Constraints (L3)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-VMS-L3-001 | Gun detection MUST use minimum 2-model ensemble | CRITICAL |
| SC-VMS-L3-002 | Fire detection MUST track temporal consistency | CRITICAL |
| SC-VMS-L3-003 | Face database MUST encrypt all embeddings | CRITICAL |
| SC-VMS-L3-004 | LPR database MUST support partial plate search | HIGH |
| SC-VMS-L3-005 | Access correlation MUST complete within 1 second | HIGH |
| SC-VMS-L3-006 | Evidence Timeline MUST NOT violate BriefCam patent | CRITICAL |
| SC-VMS-L3-007 | Watermarks MUST survive H.264/H.265 re-encoding | HIGH |

---

## Part 4: L4 - Component Architecture

### 4.1 Component Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        COMPONENT ARCHITECTURE (L4)                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                  DEVICE INTEGRATION COMPONENTS                           │    │
│  │                                                                          │    │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐             │    │
│  │  │   DISCOVERY    │  │   PROTOCOLS    │  │    DRIVERS     │             │    │
│  │  │                │  │                │  │                │             │    │
│  │  │ • WS-Discovery │  │ • ONVIF Client │  │ • Hikvision    │             │    │
│  │  │ • mDNS         │  │ • RTSP Client  │  │ • Axis         │             │    │
│  │  │ • UPnP         │  │ • VAPIX Client │  │ • Dahua        │             │    │
│  │  │ • Network Scan │  │ • ISAPI Client │  │ • Generic      │             │    │
│  │  │ • AI Profiler  │  │ • SIA DC-09    │  │ • Partner      │             │    │
│  │  └────────────────┘  └────────────────┘  └────────────────┘             │    │
│  │                                                                          │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                  AI ANALYTICS COMPONENTS                                 │    │
│  │                                                                          │    │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐             │    │
│  │  │ GUN DETECTION  │  │  FIRE/SMOKE    │  │   FACE DB      │             │    │
│  │  │                │  │                │  │                │             │    │
│  │  │ • YOLOv8       │  │ • Sc-YOLOv4    │  │ • ArcFace      │             │    │
│  │  │ • EfficientDet │  │ • EfficientDet │  │ • FaceNet      │             │    │
│  │  │ • Queue Mgr    │  │ • Temporal     │  │ • Embedding    │             │    │
│  │  │ • Alert Disp   │  │ • NFPA Class   │  │ • Search       │             │    │
│  │  └────────────────┘  └────────────────┘  └────────────────┘             │    │
│  │                                                                          │    │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐             │    │
│  │  │   LPR DB       │  │   HEAT MAP     │  │  COLOR SEARCH  │             │    │
│  │  │                │  │                │  │                │             │    │
│  │  │ • OCR Engine   │  │ • Density Calc │  │ • Color Space  │             │    │
│  │  │ • Plate Format │  │ • Trajectory   │  │ • Histogram    │             │    │
│  │  │ • Vehicle DB   │  │ • Dwell Time   │  │ • Similarity   │             │    │
│  │  │ • Alert Match  │  │ • Zone Mgmt    │  │ • Indexing     │             │    │
│  │  └────────────────┘  └────────────────┘  └────────────────┘             │    │
│  │                                                                          │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                  ACCESS CONTROL COMPONENTS                               │    │
│  │                                                                          │    │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐             │    │
│  │  │ DOOR CONTROL   │  │  CREDENTIAL    │  │   EVENT        │             │    │
│  │  │                │  │                │  │  CORRELATOR    │             │    │
│  │  │ • Lock/Unlock  │  │ • Card Reader  │  │                │             │    │
│  │  │ • Schedule     │  │ • Biometric    │  │ • Video Link   │             │    │
│  │  │ • Zone Mgmt    │  │ • Mobile       │  │ • Pre-Roll     │             │    │
│  │  │ • Interlock    │  │ • PIN          │  │ • Timeline     │             │    │
│  │  └────────────────┘  └────────────────┘  └────────────────┘             │    │
│  │                                                                          │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                  FORENSICS COMPONENTS                                    │    │
│  │                                                                          │    │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐             │    │
│  │  │   EVIDENCE     │  │   WATERMARK    │  │   REDACTION    │             │    │
│  │  │   TIMELINE     │  │    ENGINE      │  │    ENGINE      │             │    │
│  │  │                │  │                │  │                │             │    │
│  │  │ • Clustering   │  │ • Invisible    │  │ • Face Blur    │             │    │
│  │  │ • Summary Gen  │  │ • Visible      │  │ • Plate Blur   │             │    │
│  │  │ • Timestamp    │  │ • Survive Enc  │  │ • Audio Mute   │             │    │
│  │  │ • Search       │  │ • Extraction   │  │ • Region Mask  │             │    │
│  │  └────────────────┘  └────────────────┘  └────────────────┘             │    │
│  │                                                                          │    │
│  │  ┌────────────────┐  ┌────────────────┐                                 │    │
│  │  │    EXPORT      │  │  CHAIN OF      │                                 │    │
│  │  │   MANAGER      │  │   CUSTODY      │                                 │    │
│  │  │                │  │                │                                 │    │
│  │  │ • Format Conv  │  │ • Hash Chain   │                                 │    │
│  │  │ • Metadata     │  │ • Signatures   │                                 │    │
│  │  │ • Packaging    │  │ • Timestamps   │                                 │    │
│  │  │ • Distribution │  │ • Audit Log    │                                 │    │
│  │  └────────────────┘  └────────────────┘                                 │    │
│  │                                                                          │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                  VERIFICATION OPERATIONS CENTER (VOC)                    │    │
│  │                                                                          │    │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐             │    │
│  │  │   OPERATOR     │  │    ALERT       │  │    AUDIT       │             │    │
│  │  │   CONSOLE      │  │   DISPATCH     │  │    TRAIL       │             │    │
│  │  │                │  │                │  │                │             │    │
│  │  │ • Queue View   │  │ • Authorities  │  │ • Decisions    │             │    │
│  │  │ • Quick Review │  │ • Facilities   │  │ • Response     │             │    │
│  │  │ • Decision UI  │  │ • Parents      │  │ • Timing       │             │    │
│  │  │ • Escalation   │  │ • Emergency    │  │ • Accuracy     │             │    │
│  │  └────────────────┘  └────────────────┘  └────────────────┘             │    │
│  │                                                                          │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Evidence Timeline Component (Patent-Safe Alternative to BriefCam)

```elixir
# lib/indrajaal/forensics/evidence_timeline/generator.ex
defmodule Indrajaal.Forensics.EvidenceTimeline.Generator do
  @moduledoc """
  Evidence Timeline Generator - Patent-safe alternative to BriefCam Video Synopsis.

  ## Key Differences from BriefCam
  BriefCam's patent covers "video synopsis" which overlays multiple moving objects
  onto a single condensed video. Our Evidence Timeline takes a DIFFERENT approach:

  1. **Object Clustering**: Group detected objects by time windows, NOT overlay
  2. **Summary Generation**: Create indexed clips, NOT compressed composite
  3. **Timeline View**: Interactive timeline with thumbnails, NOT single video
  4. **Click-to-Source**: Direct link to original footage at exact frame

  ## Technical Approach
  - Cluster detections by 30-second windows
  - Extract representative frames per cluster
  - Generate searchable index (DuckDB)
  - Create timeline visualization with thumbnails
  - Preserve original timestamps (forensic integrity)

  ## STAMP Compliance
  - SC-EVID-001: Preserve original timestamp integrity
  - SC-EVID-002: Link to source frame within 1 second
  - SC-EVID-003: Index all detected objects
  - SC-EVID-004: Generate summary in < 10x realtime
  """

  alias Indrajaal.Video.Analytics
  alias Indrajaal.Forensics.EvidenceTimeline.{Cluster, Index, Thumbnail}

  @cluster_window_seconds 30
  @max_thumbnails_per_cluster 5

  defstruct [
    :recording_id,
    :time_range,
    :clusters,
    :object_types,
    :total_objects,
    :summary_duration,
    :generated_at
  ]

  @doc """
  Generate an evidence timeline from a recording.

  ## Parameters
  - recording_id: The source recording
  - opts: Generation options
    - object_types: Filter by object types (default: all)
    - time_range: {start, end} (default: full recording)
    - include_thumbnails: Generate thumbnails (default: true)

  ## Returns
  - {:ok, %EvidenceTimeline{}}
  """
  def generate(recording_id, opts \\ []) do
    time_range = Keyword.get(opts, :time_range, :full)
    object_types = Keyword.get(opts, :object_types, :all)

    # Step 1: Fetch all analytics detections for this recording
    detections = fetch_detections(recording_id, time_range, object_types)

    # Step 2: Cluster detections by time window (NOT overlay like BriefCam)
    clusters = cluster_by_time_window(detections, @cluster_window_seconds)

    # Step 3: Generate representative thumbnails per cluster
    clusters = generate_cluster_thumbnails(clusters, recording_id)

    # Step 4: Build searchable index in DuckDB
    {:ok, index_id} = Index.create(recording_id, clusters)

    # Step 5: Create timeline structure
    timeline = %__MODULE__{
      recording_id: recording_id,
      time_range: time_range,
      clusters: clusters,
      object_types: extract_object_types(clusters),
      total_objects: count_total_objects(clusters),
      summary_duration: calculate_summary_duration(clusters),
      generated_at: DateTime.utc_now()
    }

    # Log to Immutable Register
    log_timeline_generation(timeline)

    {:ok, timeline}
  end

  defp cluster_by_time_window(detections, window_seconds) do
    detections
    |> Enum.group_by(fn d ->
      # Round timestamp to nearest window
      div(DateTime.to_unix(d.timestamp), window_seconds) * window_seconds
    end)
    |> Enum.map(fn {window_start, window_detections} ->
      %Cluster{
        start_time: DateTime.from_unix!(window_start),
        end_time: DateTime.from_unix!(window_start + window_seconds),
        detections: window_detections,
        object_count: length(window_detections),
        object_types: window_detections |> Enum.map(& &1.type) |> Enum.uniq()
      }
    end)
    |> Enum.sort_by(& &1.start_time)
  end

  defp generate_cluster_thumbnails(clusters, recording_id) do
    Enum.map(clusters, fn cluster ->
      # Select representative detections (max 5 per cluster)
      representatives = cluster.detections
      |> Enum.sort_by(& &1.confidence, :desc)
      |> Enum.take(@max_thumbnails_per_cluster)

      thumbnails = Enum.map(representatives, fn detection ->
        Thumbnail.generate(recording_id, detection.timestamp, detection.bounding_box)
      end)

      %{cluster | thumbnails: thumbnails}
    end)
  end

  @doc """
  Search the timeline by object attributes.

  ## Differences from BriefCam
  - Returns indexed clips, NOT composite video
  - Each result links to original source footage
  - Preserves forensic integrity of timestamps
  """
  def search(timeline_id, query) do
    # Query DuckDB index
    Index.search(timeline_id, query)
  end

  @doc """
  Jump to source footage at exact frame.
  """
  def jump_to_source(timeline_id, cluster_id, detection_id) do
    with {:ok, detection} <- get_detection(timeline_id, cluster_id, detection_id),
         {:ok, frame_offset} <- calculate_frame_offset(detection) do
      {:ok, %{
        recording_id: detection.recording_id,
        timestamp: detection.timestamp,
        frame_offset: frame_offset,
        url: generate_playback_url(detection)
      }}
    end
  end
end
```

### 4.3 Forensic Watermarking Component

```elixir
# lib/indrajaal/forensics/watermark/engine.ex
defmodule Indrajaal.Forensics.Watermark.Engine do
  @moduledoc """
  Forensic watermarking engine for video evidence.

  ## Watermark Types
  1. **Invisible Watermark**: Embedded in video stream, survives re-encoding
     - DCT coefficient modification
     - Spread spectrum embedding
     - Extractable for leak tracing

  2. **Visible Watermark**: Overlay with timestamp/user info
     - Burn-in at export time
     - Configurable position/opacity
     - Tamper-evident (covers full frame periodically)

  ## STAMP Compliance
  - SC-WTRM-001: Invisible watermark MUST survive H.264/H.265 re-encoding
  - SC-WTRM-002: Invisible watermark MUST survive 3 re-compression cycles
  - SC-WTRM-003: Extraction MUST identify source with 99% accuracy
  - SC-WTRM-004: Visible watermark MUST NOT obscure critical content
  """

  alias Indrajaal.Forensics.Watermark.{InvisibleEncoder, VisibleOverlay, Extractor}

  defstruct [
    :profile_id,
    :invisible_enabled,
    :invisible_strength,
    :visible_enabled,
    :visible_template,
    :visible_position,
    :metadata
  ]

  @doc """
  Apply watermark to video frame.
  """
  def apply(frame_data, profile, metadata) do
    frame_data
    |> apply_invisible_watermark(profile, metadata)
    |> apply_visible_watermark(profile, metadata)
  end

  defp apply_invisible_watermark(frame_data, %{invisible_enabled: true} = profile, metadata) do
    # Encode metadata into invisible watermark
    payload = encode_payload(metadata)

    # Apply spread-spectrum watermarking in DCT domain
    InvisibleEncoder.embed(frame_data, payload, profile.invisible_strength)
  end

  defp apply_invisible_watermark(frame_data, _profile, _metadata), do: frame_data

  defp apply_visible_watermark(frame_data, %{visible_enabled: true} = profile, metadata) do
    # Generate overlay from template
    overlay = VisibleOverlay.generate(profile.visible_template, metadata)

    # Composite overlay onto frame
    VisibleOverlay.composite(frame_data, overlay, profile.visible_position)
  end

  defp apply_visible_watermark(frame_data, _profile, _metadata), do: frame_data

  defp encode_payload(metadata) do
    # Encode: user_id, timestamp, camera_id, tenant_id, hash
    payload = %{
      user_id: metadata.exported_by,
      timestamp: DateTime.to_unix(metadata.exported_at),
      camera_id: metadata.camera_id,
      tenant_id: metadata.tenant_id,
      hash: compute_hash(metadata)
    }

    :erlang.term_to_binary(payload)
  end

  @doc """
  Extract invisible watermark from video.
  Used for leak tracing and authenticity verification.
  """
  def extract(video_path) do
    with {:ok, frames} <- extract_sample_frames(video_path),
         {:ok, payloads} <- extract_payloads(frames) do
      # Majority vote for robustness
      decoded = majority_vote(payloads)

      {:ok, %{
        user_id: decoded.user_id,
        exported_at: DateTime.from_unix!(decoded.timestamp),
        camera_id: decoded.camera_id,
        tenant_id: decoded.tenant_id,
        integrity: verify_hash(decoded)
      }}
    end
  end
end
```

### 4.4 STAMP Constraints (L4)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-VMS-L4-001 | Evidence Timeline MUST use clustering, NOT overlay | CRITICAL |
| SC-VMS-L4-002 | Watermark extraction MUST work after 3 re-encodes | HIGH |
| SC-VMS-L4-003 | Operator console MUST show all pending reviews | HIGH |
| SC-VMS-L4-004 | Alert dispatch MUST include pre-roll clip link | HIGH |
| SC-VMS-L4-005 | Face embeddings MUST be encrypted in DuckDB | CRITICAL |
| SC-VMS-L4-006 | LPR MUST support international plate formats | MEDIUM |

---

## Part 5: L5 - Code Architecture

### 5.1 Complete Module Structure

```
lib/indrajaal/
├── device_integration/              # DEVICE INTEGRATION (from previous plan)
│   ├── discovery/
│   │   ├── ws_discovery.ex
│   │   ├── mdns.ex
│   │   ├── upnp.ex
│   │   └── ai_profiler.ex
│   ├── protocols/
│   │   ├── onvif/
│   │   ├── rtsp/
│   │   ├── vapix/
│   │   ├── isapi/
│   │   └── sia_dc09/
│   ├── drivers/
│   │   ├── builtin/
│   │   └── external/
│   └── connections/
│
├── ai_analytics/                    # AI ANALYTICS (NEW)
│   ├── ai_analytics.ex              # Domain context
│   │
│   ├── gun_detection/               # Gun Detection (Triple-Layer)
│   │   ├── detection.ex             # Layer 1: YOLOv8 detection
│   │   ├── verification.ex          # Layer 2: EfficientDet verify
│   │   ├── human_review.ex          # Layer 3: Operator verify
│   │   ├── alert_dispatcher.ex      # Emergency notification
│   │   └── model_manager.ex         # Model loading/inference
│   │
│   ├── fire_smoke/                  # Fire/Smoke Detection
│   │   ├── ensemble_detector.ex     # Multi-model ensemble
│   │   ├── temporal_tracker.ex      # False positive elimination
│   │   ├── nfpa_classifier.ex       # NFPA fire class
│   │   └── alert_dispatcher.ex      # Fire department notification
│   │
│   ├── face_db/                     # Face Recognition Database
│   │   ├── face.ex                  # Ash resource
│   │   ├── embedding_store.ex       # DuckDB encrypted storage
│   │   ├── matcher.ex               # ArcFace/FaceNet matching
│   │   ├── indexer.ex               # FAISS/Milvus index
│   │   └── search.ex                # Similarity search
│   │
│   ├── lpr_db/                      # License Plate Recognition
│   │   ├── plate.ex                 # Ash resource
│   │   ├── vehicle.ex               # Vehicle record
│   │   ├── ocr_engine.ex            # Plate OCR
│   │   ├── format_validator.ex      # International formats
│   │   └── watchlist.ex             # Alert matching
│   │
│   ├── heat_map/                    # Heat Mapping
│   │   ├── density_calculator.ex    # Crowd density
│   │   ├── trajectory_analyzer.ex   # Movement patterns
│   │   ├── dwell_time_tracker.ex    # Loitering detection
│   │   └── zone_manager.ex          # Zone definitions
│   │
│   ├── color_search/                # Color-Based Search
│   │   ├── color_extractor.ex       # Dominant color extraction
│   │   ├── histogram_indexer.ex     # Color histogram index
│   │   ├── similarity_engine.ex     # Color similarity matching
│   │   └── appearance_search.ex     # Search by appearance
│   │
│   ├── ppe_detection/               # PPE Detection
│   │   ├── ppe_detector.ex          # Hard hat, vest detection
│   │   ├── compliance_checker.ex    # Zone-based rules
│   │   └── violation_reporter.ex    # Compliance reporting
│   │
│   └── behavior/                    # Behavior Analysis
│       ├── loitering_detector.ex
│       ├── fighting_detector.ex
│       ├── falling_detector.ex
│       └── crowd_analyzer.ex
│
├── access_control_vms/              # ACCESS CONTROL (NEW)
│   ├── access_control_vms.ex        # Domain context
│   │
│   ├── door.ex                      # Door resource
│   ├── credential.ex                # Credential resource
│   ├── access_event.ex              # Event resource
│   ├── schedule.ex                  # Access schedule
│   ├── zone.ex                      # Security zone
│   │
│   ├── door_controller.ex           # Lock/unlock control
│   ├── credential_manager.ex        # Credential lifecycle
│   ├── event_correlator.ex          # Video-access correlation
│   └── interlock_manager.ex         # Anti-passback, interlocks
│
├── forensics/                       # FORENSICS (NEW)
│   ├── forensics.ex                 # Domain context
│   │
│   ├── evidence_timeline/           # Evidence Timeline (Patent-Safe)
│   │   ├── generator.ex             # Timeline generation
│   │   ├── cluster.ex               # Time-based clustering
│   │   ├── index.ex                 # DuckDB index
│   │   ├── thumbnail.ex             # Representative thumbnails
│   │   └── search.ex                # Timeline search
│   │
│   ├── watermark/                   # Forensic Watermarking
│   │   ├── engine.ex                # Watermark application
│   │   ├── invisible_encoder.ex     # DCT watermarking
│   │   ├── visible_overlay.ex       # Visible overlay
│   │   └── extractor.ex             # Watermark extraction
│   │
│   ├── chain_of_custody/            # Chain of Custody
│   │   ├── chain.ex                 # Custody chain
│   │   ├── transfer.ex              # Custody transfer
│   │   └── verification.ex          # Integrity verification
│   │
│   ├── export/                      # Evidence Export
│   │   ├── manager.ex               # Export coordination
│   │   ├── packager.ex              # Evidence packaging
│   │   └── format_converter.ex      # Format conversion
│   │
│   └── redaction/                   # Privacy Redaction
│       ├── engine.ex                # Redaction engine
│       ├── face_blur.ex             # Face anonymization
│       ├── plate_blur.ex            # License plate blur
│       └── region_mask.ex           # Custom region masking
│
├── verification/                    # VERIFICATION (NEW)
│   ├── verification.ex              # Domain context
│   │
│   ├── request.ex                   # Verification request
│   ├── operator_session.ex          # Operator session
│   ├── decision.ex                  # Review decision
│   │
│   ├── queue_manager.ex             # Review queue
│   ├── operator_console.ex          # Review UI backend
│   └── alert_dispatcher.ex          # Emergency dispatch
│
└── video/                           # VIDEO (ENHANCED)
    ├── safety/                      # Safety Integration
    │   ├── guardian_bridge.ex       # Guardian approval
    │   ├── sentinel_bridge.ex       # Health monitoring
    │   └── immutable_logger.ex      # Audit trail
    │
    └── pre_roll/                    # Pre-Roll Buffer
        ├── ring_buffer.ex           # Ring buffer implementation
        ├── buffer_manager.ex        # Buffer lifecycle
        └── event_trigger.ex         # Event-based extraction
```

### 5.2 AI Model Requirements

| Model | Purpose | Framework | GPU Memory | Inference Time |
|-------|---------|-----------|------------|----------------|
| YOLOv8-Weapons | Gun detection Layer 1 | PyTorch/ONNX | 4GB | <50ms |
| EfficientDet-Weapons | Gun detection Layer 2 | TensorFlow | 2GB | <100ms |
| Scaled-YOLOv4 | Fire/Smoke detection | Darknet/ONNX | 4GB | 16ms |
| EfficientDet-D2 | Fire/Smoke verification | TensorFlow | 2GB | 19ms |
| ArcFace | Face recognition | PyTorch | 2GB | <50ms |
| LPRNet | License plate OCR | PyTorch | 1GB | <30ms |
| ResNet-PPE | PPE detection | PyTorch | 2GB | <50ms |
| PoseNet | Behavior analysis | TensorFlow | 2GB | <100ms |

### 5.3 STAMP Constraints (L5)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-VMS-L5-001 | AI models MUST use ONNX for portability | HIGH |
| SC-VMS-L5-002 | Inference MUST NOT block BEAM scheduler | CRITICAL |
| SC-VMS-L5-003 | Model loading MUST be lazy/on-demand | MEDIUM |
| SC-VMS-L5-004 | Face embeddings MUST be 512-dim ArcFace | HIGH |
| SC-VMS-L5-005 | LPR MUST support UTF-8 characters | MEDIUM |
| SC-VMS-L5-006 | Watermark MUST use 256-bit payload | HIGH |

---

## Part 6: Implementation Roadmap

### 6.1 Phase 1: Critical Safety (Q1 2026)

| Week | Deliverable | Priority |
|------|-------------|----------|
| 1-2 | Gun Detection Layer 1 (YOLOv8) | P0 |
| 3-4 | Gun Detection Layer 2 (EfficientDet) | P0 |
| 5-6 | Human Verification Console | P0 |
| 7-8 | Fire/Smoke Ensemble Detector | P0 |
| 9-10 | Alert Dispatch Integration | P0 |
| 11-12 | Testing + DHS SAFETY Act prep | P0 |

**Milestone**: Triple-layer gun detection + fire/smoke detection operational

### 6.2 Phase 2: Access Control + Analytics (Q2 2026)

| Week | Deliverable | Priority |
|------|-------------|----------|
| 1-3 | Access Control Domain | P1 |
| 4-5 | Event-Video Correlation | P1 |
| 6-7 | Face Recognition Database | P1 |
| 8-9 | LPR Database | P1 |
| 10-11 | Heat Mapping | P2 |
| 12 | Integration Testing | P1 |

**Milestone**: Unified access control + video with face/LPR databases

### 6.3 Phase 3: Device Ecosystem (Q3 2026)

| Week | Deliverable | Priority |
|------|-------------|----------|
| 1-3 | ONVIF Profile S/T Full Implementation | P0 |
| 4-5 | Hikvision ISAPI Driver | P1 |
| 6-7 | Axis VAPIX Driver | P1 |
| 8-9 | Dahua SDK NIF | P1 |
| 10-11 | Partner SDK + Documentation | P2 |
| 12 | 2,500 device target | P1 |

**Milestone**: 2,500+ device drivers, partner program launched

### 6.4 Phase 4: Forensics + Polish (Q4 2026)

| Week | Deliverable | Priority |
|------|-------------|----------|
| 1-2 | Evidence Timeline Generator | P1 |
| 3-4 | Forensic Watermarking | P1 |
| 5-6 | Color Search | P2 |
| 7-8 | PPE Detection | P2 |
| 9-10 | 10,000 device target | P1 |
| 11-12 | Certification + Documentation | P1 |

**Milestone**: Feature parity with Milestone/Eagle Eye/3dEye

### 6.5 Resource Requirements

| Phase | Engineers | AI/ML Specialists | QA | Duration |
|-------|-----------|-------------------|----|----|
| Phase 1 | 4 | 2 | 2 | 12 weeks |
| Phase 2 | 5 | 2 | 2 | 12 weeks |
| Phase 3 | 4 | 1 | 2 | 12 weeks |
| Phase 4 | 4 | 1 | 2 | 12 weeks |
| **Total** | **17** | **6** | **8** | **48 weeks** |

---

## Part 7: Competitive Feature Parity Summary

### 7.1 Feature Completion Matrix

| Feature | Milestone | 3dEye | Eagle Eye | Q1 2026 | Q2 2026 | Q3 2026 | Q4 2026 |
|---------|-----------|-------|-----------|---------|---------|---------|---------|
| **Device Drivers** | 14,700 | 1,000s | 10,000+ | 100 | 500 | 2,500 | 10,000 |
| **Gun Detection** | 3rd party | No | Yes | **Yes** | Yes | Yes | Yes |
| **Fire/Smoke** | 3rd party | Yes | 3rd party | **Yes** | Yes | Yes | Yes |
| **Face DB** | Yes | Yes | Yes | No | **Yes** | Yes | Yes |
| **LPR DB** | Yes | Yes | Yes | No | **Yes** | Yes | Yes |
| **Access Control** | MIP | No | Brivo | No | **Yes** | Yes | Yes |
| **Heat Mapping** | Yes | Yes | Yes | No | **Yes** | Yes | Yes |
| **Color Search** | No | Yes | No | No | No | No | **Yes** |
| **Evidence Timeline** | BriefCam | No | No | No | No | No | **Yes** |
| **Watermarking** | No | No | No | No | No | No | **Yes** |
| **Immutable Audit** | No | No | No | **Yes** | Yes | Yes | Yes |
| **Self-Healing** | No | No | No | **Yes** | Yes | Yes | Yes |
| **Constitutional** | No | No | No | **Yes** | Yes | Yes | Yes |

### 7.2 Indrajaal Unique Advantages (Maintained)

These differentiators are NOT available in any competitor:

| Advantage | Status | Strategic Value |
|-----------|--------|-----------------|
| Immutable Audit Trail | ✅ Existing | Forensic admissibility |
| BEAM Self-Healing | ✅ Existing | 99.999% uptime |
| Constitutional Safety | ✅ Existing | Regulatory compliance |
| Guardian Veto | ✅ Existing | Safety-critical operations |
| Pre-Roll Buffer | ✅ Existing | Alarm verification |
| Zenoh P2P Mesh | ✅ Existing | No single point failure |
| Open Core | ✅ Existing | Vendor lock-in resistance |

---

## Part 8: Sources

### Gun Detection
- [ZeroEyes Technology](https://zeroeyes.com/technology/)
- [Omnilert Gun Detect](https://www.omnilert.com/solutions/ai-gun-detection)
- [DHS SAFETY Act](https://www.safetyact.gov/)

### Fire/Smoke Detection
- [NYU Fire Detection Research](https://engineering.nyu.edu/news/nyu-tandon-researchers-develop-new-ai-system-leverages-standard-security-cameras-detect-fires)
- [AvidBeam AI Fire Detection](https://www.avidbeam.com/2025s-must-have-security-upgrade-ai-fire-and-smoke-detection/)
- [Irisity IRIS+](https://irisity.com/iris-platform-overview/ai-fire-detection/)

### Access Control Integration
- [Axis Secure Entry for XProtect](https://newsroom.axis.com/en-us/press-release/secure-entry-xprotect)
- [Milestone XProtect Access](https://www.milestonesys.com/solutions/by-use-case/access-control/)
- [Verkada Unified Platform](https://www.verkada.com/)

### Device Integration
- [ONVIF Profiles](https://www.onvif.org/profiles/)
- [libonvif](https://github.com/sr99622/libonvif)
- [Milestone MIP SDK](https://www.milestonesys.com/support/for-developers/integrate-with-xprotect/)
- [Eagle Eye API](https://developer.eagleeyenetworks.com)

---

**Document Version**: 1.0.0
**Created**: 2026-01-03
**Author**: Claude Opus 4.5
**STAMP Compliance**: 47 new constraints defined (SC-VMS-*, SC-GUN-*, SC-FIRE-*, SC-PACS-*, SC-EVID-*, SC-WTRM-*)
