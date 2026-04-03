# Integrated System Architecture: AI/ML, KMS, OODA, Prajna Unified View

**Version**: 21.3.0-SIL6 | **Date**: 2026-03-19 | **Status**: ACTIVE
**Scope**: Complete subsystem integration across 8 fractal levels
**[Updated Sprint 51]**: Federation protocol, streaming, Route module, KMS.AI, Alarms, SMRITI, and Copilot NL are now fully implemented.

---

## Executive Summary

This document presents the unified integration architecture for all major subsystems:
- **AI/ML Intelligence Layer** (L6 Biosphere)
- **Knowledge Management System (KMS/Z-KMS)** (L3 Organ)
- **OODA Cybernetic Control** (All levels)
- **Prajna C3I Cockpit** (L4 Organism)
- **Biomorphic Mesh** (L5 Ecosystem)
- **Guardian Constitutional Core** (L7 Constitutional)

---

## 1.0 Unified Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    INDRAJAAL INTEGRATED SYSTEM ARCHITECTURE                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  L7 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  ┃                    GUARDIAN CONSTITUTIONAL CORE                       ┃  │
│  ┃   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  ┃  │
│  ┃   │  Founder    │──│ Invariants  │──│  Immutable  │                  ┃  │
│  ┃   │  Directive  │  │  Ψ₀-Ψ₅     │  │  Register   │                  ┃  │
│  ┃   └─────────────┘  └─────────────┘  └─────────────┘                  ┃  │
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛  │
│                                    ▲                                        │
│                                    │ Governance                             │
│  L6 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  ┃                    AI/ML INTELLIGENCE LAYER                           ┃  │
│  ┃   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  ┃  │
│  ┃   │  OpenRouter │──│  Consensus  │──│    GDE      │                  ┃  │
│  ┃   │  (Claude,   │  │   Engine    │  │  Evolution  │                  ┃  │
│  ┃   │   Gemini,   │  │             │  │             │                  ┃  │
│  ┃   │   Grok)     │  │             │  │             │                  ┃  │
│  ┃   └─────────────┘  └─────────────┘  └─────────────┘                  ┃  │
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛  │
│                                    ▲                                        │
│                                    │ Intelligence                           │
│  L5 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  ┃                    BIOMORPHIC MESH (ZENOH)                            ┃  │
│  ┃   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  ┃  │
│  ┃   │    Mesh     │──│  Quorum     │──│ Federation  │                  ┃  │
│  ┃   │ Coordinator │  │  Voting     │  │  Protocol   │                  ┃  │
│  ┃   └─────────────┘  └─────────────┘  └─────────────┘                  ┃  │
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛  │
│                                    ▲                                        │
│                                    │ Coordination                           │
│  L4 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  ┃                    PRAJNA C3I COCKPIT                                 ┃  │
│  ┃   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  ┃  │
│  ┃   │   Smart     │──│    AI       │──│  Sentinel   │                  ┃  │
│  ┃   │  Metrics    │  │  Copilot    │  │  Threats    │                  ┃  │
│  ┃   └─────────────┘  └─────────────┘  └─────────────┘                  ┃  │
│  ┃                         ▲                                             ┃  │
│  ┃                    OODA Control Loop                                  ┃  │
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛  │
│                                    ▲                                        │
│                                    │ Control                                │
│  L3 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  ┃                    DOMAIN SERVICES + Z-KMS                            ┃  │
│  ┃   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  ┃  │
│  ┃   │   Access    │──│   Alarms    │──│  Z-KMS      │                  ┃  │
│  ┃   │   Domain    │  │   Domain    │  │  Knowledge  │                  ┃  │
│  ┃   └─────────────┘  └─────────────┘  └─────────────┘                  ┃  │
│  ┃                                          │                            ┃  │
│  ┃                         ┌────────────────┴────────────────┐          ┃  │
│  ┃                         ▼                                 ▼          ┃  │
│  ┃   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  ┃  │
│  ┃   │   Zettel    │──│    Graph    │──│  RAG/Vector │                  ┃  │
│  ┃   │   Notes     │  │   Engine    │  │   Search    │                  ┃  │
│  ┃   └─────────────┘  └─────────────┘  └─────────────┘                  ┃  │
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛  │
│                                    ▲                                        │
│                                    │ Services                               │
│  L2 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  ┃                    CLUSTER / TISSUE                                   ┃  │
│  ┃   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  ┃  │
│  ┃   │  Cluster    │──│  Consensus  │──│ Aggregates  │                  ┃  │
│  ┃   │  Manager    │  │   (CRDT)    │  │  (DDD)      │                  ┃  │
│  ┃   └─────────────┘  └─────────────┘  └─────────────┘                  ┃  │
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛  │
│                                    ▲                                        │
│                                    │ Grouping                               │
│  L1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  ┃                    HOLON / CELLULAR                                   ┃  │
│  ┃   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  ┃  │
│  ┃   │   Holon     │──│   State     │──│  Sentinel   │                  ┃  │
│  ┃   │  Processes  │  │  (SQLite)   │  │  (Immune)   │                  ┃  │
│  ┃   └─────────────┘  └─────────────┘  └─────────────┘                  ┃  │
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛  │
│                                    ▲                                        │
│                                    │ State                                  │
│  L0 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  ┃                    QUANTUM / TYPES                                    ┃  │
│  ┃   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  ┃  │
│  ┃   │   Types     │──│   Crypto    │──│  Register   │                  ┃  │
│  ┃   │  @spec      │  │  Ed25519    │  │  Blocks     │                  ┃  │
│  ┃   └─────────────┘  └─────────────┘  └─────────────┘                  ┃  │
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2.0 Subsystem Integration Details

### 2.1 AI/ML ↔ KMS Integration

```
┌─────────────────────────────────────────────────────────────────┐
│                    AI/ML ↔ KMS INTEGRATION                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐              ┌──────────────────┐         │
│  │    AI/ML (L6)    │              │    Z-KMS (L3)    │         │
│  │                  │              │                  │         │
│  │ ┌──────────────┐ │   Vectors   │ ┌──────────────┐ │         │
│  │ │  Embedding   │◀┼──────────────┼▶│ VectorStore  │ │         │
│  │ │   Service    │ │              │ │              │ │         │
│  │ └──────────────┘ │              │ └──────────────┘ │         │
│  │        │         │              │        │         │         │
│  │        ▼         │   Context    │        ▼         │         │
│  │ ┌──────────────┐ │              │ ┌──────────────┐ │         │
│  │ │     RAG      │◀┼──────────────┼▶│   Zettel     │ │         │
│  │ │   Pipeline   │ │              │ │   Content    │ │         │
│  │ └──────────────┘ │              │ └──────────────┘ │         │
│  │        │         │              │        │         │         │
│  │        ▼         │  Generation  │        ▼         │         │
│  │ ┌──────────────┐ │              │ ┌──────────────┐ │         │
│  │ │   LLM API    │─┼──────────────┼▶│ Knowledge    │ │         │
│  │ │  (Claude)    │ │              │ │   Graph      │ │         │
│  │ └──────────────┘ │              │ └──────────────┘ │         │
│  └──────────────────┘              └──────────────────┘         │
│                                                                  │
│  Data Flow:                                                      │
│  1. Z-KMS provides context via VectorStore search               │
│  2. RAG pipeline retrieves relevant Zettels                     │
│  3. LLM generates responses with knowledge context              │
│  4. New knowledge flows back to Z-KMS as new Zettels            │
│                                                                  │
│  Protocols:                                                      │
│    Vector Search: pgvector cosine similarity                    │
│    Context: JSON with markdown content                          │
│    Generation: Streaming API response                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 OODA ↔ Prajna Integration

```
┌─────────────────────────────────────────────────────────────────┐
│                    OODA ↔ PRAJNA INTEGRATION                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│                    ┌─────────────────────────┐                  │
│                    │     PRAJNA COCKPIT      │                  │
│                    │         (L4)            │                  │
│                    └───────────┬─────────────┘                  │
│                                │                                 │
│      ┌─────────────────────────┼─────────────────────────┐      │
│      │                         │                         │      │
│      ▼                         ▼                         ▼      │
│  ┌─────────┐              ┌─────────┐              ┌─────────┐  │
│  │ OBSERVE │              │ ORIENT  │              │ DECIDE  │  │
│  │         │              │         │              │         │  │
│  │ • Smart │              │ • Pattern│             │ •Guardian│ │
│  │   Metrics│             │   Hunter │             │  Approval│ │
│  │ • Telemetry│           │ • Trend  │             │ • Proof  │ │
│  │ • Zenoh  │             │   Analysis│            │   Token  │ │
│  └────┬────┘              └────┬────┘              └────┬────┘  │
│       │                        │                        │       │
│       └────────────────────────┼────────────────────────┘       │
│                                ▼                                 │
│                          ┌─────────┐                            │
│                          │   ACT   │                            │
│                          │         │                            │
│                          │ •Execute│                            │
│                          │ •Log    │                            │
│                          │ •Verify │                            │
│                          └─────────┘                            │
│                                │                                 │
│                                ▼                                 │
│                    ┌─────────────────────────┐                  │
│                    │   IMMUTABLE REGISTER    │                  │
│                    │         (L7)            │                  │
│                    └─────────────────────────┘                  │
│                                                                  │
│  OODA Cycle Time: 30 seconds (SC-BIO-001)                       │
│                                                                  │
│  Integration Points:                                             │
│    OBSERVE: SmartMetrics collects from L1-L3                    │
│    ORIENT: PatternHunter + AI analysis                          │
│    DECIDE: Guardian approval for L4+ changes                    │
│    ACT: ProofToken + Immutable Register                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.3 Mesh ↔ All Subsystems Integration

```
┌─────────────────────────────────────────────────────────────────┐
│                    MESH INTEGRATION HUB                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│                    ┌─────────────────────────┐                  │
│                    │     ZENOH ROUTER        │                  │
│                    │      (Port 7447)        │                  │
│                    └───────────┬─────────────┘                  │
│                                │                                 │
│      ┌─────────────────────────┼─────────────────────────┐      │
│      │                         │                         │      │
│      ▼                         ▼                         ▼      │
│                                                                  │
│  indrajaal/                                                      │
│  ├── prajna/           ← L4 Prajna Cockpit                      │
│  │   ├── kpi              Health score, threat level            │
│  │   ├── alerts           Alert notifications                   │
│  │   └── control          Control commands                      │
│  │                                                               │
│  ├── ai/               ← L6 AI/ML Layer                         │
│  │   ├── requests         API request telemetry                 │
│  │   ├── responses        Model responses                       │
│  │   └── consensus        Voting results                        │
│  │                                                               │
│  ├── kms/              ← L3 Knowledge Management                │
│  │   ├── entropy          Zettel decay metrics                  │
│  │   ├── graph            Graph changes                         │
│  │   └── search           Search queries                        │
│  │                                                               │
│  ├── holon/            ← L1 Cellular                            │
│  │   ├── state            State changes                         │
│  │   └── health           Holon health                          │
│  │                                                               │
│  ├── mesh/             ← L5 Mesh Coordination                   │
│  │   ├── topology         Topology changes                      │
│  │   ├── quorum           Quorum status                         │
│  │   └── control          Mesh control                          │
│  │                                                               │
│  └── guardian/         ← L7 Constitutional                      │
│      ├── decisions        Approval/veto                         │
│      └── amendments       Constitutional changes                │
│                                                                  │
│  Every subsystem publishes to and subscribes from Zenoh         │
│  Real-time integration with < 5ms latency (SC-BRIDGE-003)       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3.0 Data Flow Integration

### 3.1 Request Lifecycle (End-to-End)

```
┌─────────────────────────────────────────────────────────────────┐
│                    REQUEST LIFECYCLE FLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. INGRESS (L0/L1)                                             │
│     └─▶ HTTP request arrives                                    │
│         └─▶ Type validation (L0)                                │
│             └─▶ Process receives (L1)                           │
│                                                                  │
│  2. ROUTING (L2/L3)                                             │
│     └─▶ Cluster routing (L2)                                    │
│         └─▶ Domain dispatch (L3)                                │
│             └─▶ Service handler                                 │
│                                                                  │
│  3. KNOWLEDGE (L3 Z-KMS)                                        │
│     └─▶ If knowledge query:                                     │
│         └─▶ Vector search                                       │
│             └─▶ Graph traversal                                 │
│                 └─▶ RAG retrieval                               │
│                                                                  │
│  4. INTELLIGENCE (L6 AI/ML)                                     │
│     └─▶ If AI required:                                         │
│         └─▶ Context assembly                                    │
│             └─▶ LLM API call                                    │
│                 └─▶ Response streaming                          │
│                                                                  │
│  5. CONTROL (L4 Prajna)                                         │
│     └─▶ Telemetry capture                                       │
│         └─▶ Metrics update                                      │
│             └─▶ OODA observation                                │
│                                                                  │
│  6. COORDINATION (L5 Mesh)                                      │
│     └─▶ Zenoh publish                                           │
│         └─▶ Cluster sync                                        │
│             └─▶ State replication                               │
│                                                                  │
│  7. GOVERNANCE (L7 Guardian)                                    │
│     └─▶ If state mutation:                                      │
│         └─▶ Proof token required                                │
│             └─▶ Audit log append                                │
│                 └─▶ Immutable Register                          │
│                                                                  │
│  8. EGRESS                                                       │
│     └─▶ Response assembly                                       │
│         └─▶ HTTP response                                       │
│                                                                  │
│  Total latency: < 200ms typical                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Knowledge Acquisition Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    KNOWLEDGE ACQUISITION FLOW                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  SOURCE ──────────────────────────────────────────────────────  │
│    │                                                             │
│    ├─▶ Document import (PDF, Markdown, HTML)                    │
│    ├─▶ Web scraping (with AI extraction)                        │
│    ├─▶ API integration (external knowledge bases)               │
│    └─▶ User input (direct Zettel creation)                      │
│                                                                  │
│  PROCESSING ──────────────────────────────────────────────────  │
│    │                                                             │
│    │  ┌─────────────────────────────────────────────────┐       │
│    │  │               AI PROCESSING (L6)                 │       │
│    │  │                                                   │       │
│    │  │  1. Content extraction (LLM parsing)             │       │
│    │  │  2. Entity recognition (NER)                     │       │
│    │  │  3. Link detection ([[wiki-links]])              │       │
│    │  │  4. Embedding generation (vector)                │       │
│    │  │  5. Summary creation                             │       │
│    │  │                                                   │       │
│    │  └─────────────────────────────────────────────────┘       │
│    │                        │                                    │
│    ▼                        ▼                                    │
│  STORAGE ─────────────────────────────────────────────────────  │
│    │                                                             │
│    │  ┌─────────────────────────────────────────────────┐       │
│    │  │              Z-KMS STORAGE (L3)                  │       │
│    │  │                                                   │       │
│    │  │  ┌───────────┐  ┌───────────┐  ┌───────────┐    │       │
│    │  │  │  SQLite   │  │  DuckDB   │  │  pgvector │    │       │
│    │  │  │  (Zettel) │  │ (History) │  │ (Vectors) │    │       │
│    │  │  └───────────┘  └───────────┘  └───────────┘    │       │
│    │  │                                                   │       │
│    │  └─────────────────────────────────────────────────┘       │
│    │                        │                                    │
│    ▼                        ▼                                    │
│  GRAPH UPDATE ────────────────────────────────────────────────  │
│    │                                                             │
│    │  1. Add node to knowledge graph                            │
│    │  2. Create edges from backlinks                            │
│    │  3. Calculate semantic similarity edges                    │
│    │  4. Update cluster assignments                             │
│    │  5. Recalculate entropy                                    │
│    │                                                             │
│    └─▶ Zenoh publish: indrajaal/kms/graph/update                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.3 Evolution Flow (GDE)

```
┌─────────────────────────────────────────────────────────────────┐
│                    EVOLUTION FLOW (GDE)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. GOAL IDENTIFICATION (L4 Prajna → L6 GDE)                    │
│     └─▶ System detects improvement opportunity                  │
│         └─▶ Performance regression                              │
│         └─▶ Error pattern                                       │
│         └─▶ Coverage gap                                        │
│                                                                  │
│  2. PROPOSAL GENERATION (L6 AI/ML)                              │
│     └─▶ AI generates code proposal                              │
│         └─▶ Multi-model consensus                               │
│             └─▶ Claude analysis                                 │
│             └─▶ Gemini validation                               │
│             └─▶ Grok verification                               │
│                                                                  │
│  3. SHADOW TESTING (L6 GDE)                                     │
│     └─▶ Fork shadow universe                                    │
│         └─▶ Apply proposal in isolation                         │
│             └─▶ Run test suite                                  │
│                 └─▶ Measure fitness                             │
│                                                                  │
│  4. GUARDIAN APPROVAL (L7 Constitutional)                       │
│     └─▶ Constitutional check                                    │
│         └─▶ Founder Directive alignment                         │
│             └─▶ Invariant verification                          │
│                 └─▶ Approval or veto                            │
│                                                                  │
│  5. DEPLOYMENT (L5 Mesh → L1-L3)                                │
│     └─▶ If approved:                                            │
│         └─▶ Generate proof token                                │
│             └─▶ Apply to production                             │
│                 └─▶ Log to Immutable Register                   │
│                     └─▶ Publish to Zenoh                        │
│                                                                  │
│  6. LEARNING (L6 TrainingGym)                                   │
│     └─▶ Record outcome                                          │
│         └─▶ Update model weights                                │
│             └─▶ Improve future proposals                        │
│                                                                  │
│  Evolution cycle: Hours to days                                 │
│  Rollback window: 24 hours (SC-REG-008)                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**[Updated Sprint 51]** Fitness scoring now uses real `:cover` module + mutation testing
instead of the previous random-based placeholder. Streaming API responses, federation
protocol, and Route module matching logic are fully implemented.

---

## 4.0 Cross-Subsystem APIs

### 4.1 Internal API Matrix

| From \ To | AI/ML | KMS | Prajna | Mesh | Guardian |
|-----------|-------|-----|--------|------|----------|
| **AI/ML** | - | VectorSearch, RAG | Telemetry | Publish | ProofRequest |
| **KMS** | Embed, Generate | - | Metrics | Sync | AuditLog |
| **Prajna** | Analyze, Recommend | Query, Store | - | Broadcast | Approve |
| **Mesh** | Distribute | Replicate | Coordinate | - | Attest |
| **Guardian** | Validate | Audit | Govern | Authorize | - |

### 4.2 API Contracts

```yaml
# AI/ML → KMS: Vector Search
POST /api/kms/vector/search
Content-Type: application/json
{
  "query": "string",
  "embedding": [float...],
  "limit": 10,
  "threshold": 0.8
}
Response: {
  "results": [
    {"zettel_id": "uuid", "score": 0.92, "content": "..."}
  ]
}

# KMS → AI/ML: Generate Embedding
POST /api/ai/embed
Content-Type: application/json
{
  "text": "string",
  "model": "text-embedding-3-small"
}
Response: {
  "embedding": [float...],
  "dimensions": 1536
}

# Prajna → Guardian: Request Approval
POST /api/guardian/propose
Content-Type: application/json
{
  "action": "deploy_code",
  "proposal": {...},
  "proof_token": "..."
}
Response: {
  "approved": true,
  "conditions": [...],
  "veto_reason": null
}

# Mesh → All: Zenoh Publish
Topic: indrajaal/{subsystem}/{event}
Payload: JSON
{
  "timestamp": "2026-01-11T12:00:00Z",
  "source": "node-1",
  "data": {...}
}
```

---

## 5.0 State Integration

### 5.1 Unified State Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    UNIFIED STATE MODEL                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                  HOLON SOVEREIGN STATE                   │    │
│  │                                                           │    │
│  │  ┌───────────────┐                                       │    │
│  │  │    SQLite     │ ◀── Real-time state (L1)             │    │
│  │  │   (WAL Mode)  │                                       │    │
│  │  │               │     • Holon state                     │    │
│  │  │               │     • Zettel content                  │    │
│  │  │               │     • Version vectors                 │    │
│  │  └───────────────┘                                       │    │
│  │         │                                                 │    │
│  │         │ Append-only                                     │    │
│  │         ▼                                                 │    │
│  │  ┌───────────────┐                                       │    │
│  │  │    DuckDB     │ ◀── History & analytics (L1)         │    │
│  │  │  (Columnar)   │                                       │    │
│  │  │               │     • Evolution history               │    │
│  │  │               │     • Audit log                       │    │
│  │  │               │     • Metrics history                 │    │
│  │  └───────────────┘                                       │    │
│  │                                                           │    │
│  └─────────────────────────────────────────────────────────┘    │
│                          │                                       │
│                          │ Replication (not authoritative)       │
│                          ▼                                       │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                DISTRIBUTED CACHES                         │    │
│  │                                                           │    │
│  │  ┌───────────────┐  ┌───────────────┐                    │    │
│  │  │  PostgreSQL   │  │    Redis      │                    │    │
│  │  │  (Business)   │  │   (Cache)     │                    │    │
│  │  │               │  │               │                    │    │
│  │  │  Transactional│  │  Session      │                    │    │
│  │  │  data ONLY    │  │  cache        │                    │    │
│  │  └───────────────┘  └───────────────┘                    │    │
│  │                                                           │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  SC-HOLON-011: SQLite/DuckDB is AUTHORITATIVE                   │
│  SC-HOLON-012: All other stores are ephemeral replicas          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 State Synchronization

```
┌─────────────────────────────────────────────────────────────────┐
│                    STATE SYNCHRONIZATION                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  SQLite (Authoritative)                                         │
│       │                                                          │
│       │ WAL commit                                               │
│       ▼                                                          │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                 VERSION VECTOR UPDATE                     │    │
│  │                                                           │    │
│  │   {                                                       │    │
│  │     "holon_id": "uuid",                                   │    │
│  │     "vector": {"node-1": 42, "node-2": 38},              │    │
│  │     "timestamp": "2026-01-11T12:00:00Z"                   │    │
│  │   }                                                       │    │
│  │                                                           │    │
│  └─────────────────────────────────────────────────────────┘    │
│       │                                                          │
│       │ Zenoh publish: indrajaal/holon/{id}/state               │
│       ▼                                                          │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                 PEER SYNCHRONIZATION                      │    │
│  │                                                           │    │
│  │  Node 1 ◀──────────────────────────▶ Node 2              │    │
│  │     │                                   │                 │    │
│  │     │         Zenoh Mesh                │                 │    │
│  │     │                                   │                 │    │
│  │  Node 3 ◀──────────────────────────▶ Node N              │    │
│  │                                                           │    │
│  └─────────────────────────────────────────────────────────┘    │
│       │                                                          │
│       │ CRDT merge (last-writer-wins with vector clock)         │
│       ▼                                                          │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                 EVENTUAL CONSISTENCY                      │    │
│  │                                                           │    │
│  │   All replicas converge within 1 second                   │    │
│  │   Conflict resolution: Vector clock comparison            │    │
│  │   Authoritative resolution: Source SQLite wins            │    │
│  │                                                           │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6.0 Observability Integration

### 6.1 Telemetry Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                    TELEMETRY PIPELINE                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  SOURCES                                                         │
│  ──────────────────────────────────────────────────────────────  │
│  │                                                               │
│  ├─▶ L0-L3: :telemetry.execute events                           │
│  ├─▶ L4 Prajna: SmartMetrics calculations                       │
│  ├─▶ L5 Mesh: Zenoh topic subscriptions                         │
│  ├─▶ L6 AI/ML: API response telemetry                           │
│  └─▶ L7 Guardian: Audit log entries                             │
│                                                                  │
│  COLLECTION                                                      │
│  ──────────────────────────────────────────────────────────────  │
│                         │                                        │
│                         ▼                                        │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              OTEL COLLECTOR (Port 4317/4318)             │    │
│  │                                                           │    │
│  │   Traces ───▶ Tempo/Jaeger                               │    │
│  │   Metrics ──▶ Prometheus                                  │    │
│  │   Logs ────▶ Loki                                        │    │
│  │                                                           │    │
│  └─────────────────────────────────────────────────────────┘    │
│                         │                                        │
│                         ▼                                        │
│  STORAGE                                                         │
│  ──────────────────────────────────────────────────────────────  │
│  │                                                               │
│  ├─▶ Prometheus (Port 9090): Time-series metrics                │
│  ├─▶ Loki (Port 3100): Structured logs                          │
│  ├─▶ DuckDB: Historical analytics                               │
│  └─▶ Immutable Register: Audit trail                            │
│                                                                  │
│  VISUALIZATION                                                   │
│  ──────────────────────────────────────────────────────────────  │
│  │                                                               │
│  ├─▶ Grafana (Port 3000): Dashboards                            │
│  ├─▶ Prajna Cockpit (Port 4000/prajna): C3I interface           │
│  └─▶ Zenoh real-time: Live updates                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 Metric Categories

| Category | Subsystem | Key Metrics |
|----------|-----------|-------------|
| **Health** | Prajna | health_score, threat_level, agent_count |
| **Performance** | All | latency_ms, throughput_rps, error_rate |
| **AI/ML** | Intelligence | api_latency, tokens_used, accuracy |
| **KMS** | Knowledge | zettel_count, entropy_avg, search_latency |
| **Mesh** | Ecosystem | node_count, quorum_status, sync_lag |
| **Constitutional** | Guardian | approvals, vetoes, invariant_checks |

---

## 7.0 Security Integration

### 7.1 Security Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                    SECURITY INTEGRATION                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  L7 CONSTITUTIONAL SECURITY                                      │
│  ──────────────────────────────────────────────────────────────  │
│  │                                                               │
│  ├─▶ Guardian: Absolute veto authority                          │
│  ├─▶ Proof tokens: PROMETHEUS verification                      │
│  ├─▶ Immutable Register: Tamper-proof audit                     │
│  └─▶ Cryptographic: Ed25519 signatures, SHA3-256 hashes         │
│                                                                  │
│  L6 AI SECURITY                                                  │
│  ──────────────────────────────────────────────────────────────  │
│  │                                                               │
│  ├─▶ Founder Directive alignment check                          │
│  ├─▶ Shadow testing before deployment                           │
│  ├─▶ Rollback capability (24h window)                           │
│  └─▶ API key rotation and rate limiting                         │
│                                                                  │
│  L5 MESH SECURITY                                                │
│  ──────────────────────────────────────────────────────────────  │
│  │                                                               │
│  ├─▶ Zenoh TLS encryption                                       │
│  ├─▶ Node authentication                                        │
│  ├─▶ Federation peer attestation                                │
│  └─▶ Network isolation                                          │
│                                                                  │
│  L4 PRAJNA SECURITY                                              │
│  ──────────────────────────────────────────────────────────────  │
│  │                                                               │
│  ├─▶ Session authentication                                     │
│  ├─▶ Role-based access control                                  │
│  ├─▶ Two-step commit for destructive actions                    │
│  └─▶ Audit logging                                              │
│                                                                  │
│  L3 DOMAIN SECURITY                                              │
│  ──────────────────────────────────────────────────────────────  │
│  │                                                               │
│  ├─▶ Ash authorization policies                                 │
│  ├─▶ Multi-tenancy isolation                                    │
│  ├─▶ Input validation                                           │
│  └─▶ OWASP compliance                                           │
│                                                                  │
│  L1-L2 PROCESS SECURITY                                          │
│  ──────────────────────────────────────────────────────────────  │
│  │                                                               │
│  ├─▶ Process isolation (BEAM scheduler)                         │
│  ├─▶ Capability tokens                                          │
│  ├─▶ SQLite encryption at rest                                  │
│  └─▶ Kernel process protection                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8.0 STAMP Constraints (Integration)

| ID | Constraint | Subsystems | Severity |
|----|------------|------------|----------|
| SC-INT-001 | AI/ML MUST use KMS for context retrieval | AI, KMS | HIGH |
| SC-INT-002 | All state mutations MUST be logged to Register | All | CRITICAL |
| SC-INT-003 | Cross-subsystem calls MUST include trace ID | All | HIGH |
| SC-INT-004 | Prajna OODA cycle MUST observe all L1-L3 | Prajna | CRITICAL |
| SC-INT-005 | Mesh MUST publish to Zenoh within 5ms | Mesh | HIGH |
| SC-INT-006 | Guardian MUST validate L4+ changes | Guardian | CRITICAL |
| SC-INT-007 | KMS entropy MUST be calculated every 24h | KMS | MEDIUM |
| SC-INT-008 | AI consensus MUST achieve 0.85 agreement | AI | HIGH |

---

## 9.0 AOR Rules (Integration)

| ID | Rule |
|----|------|
| AOR-INT-001 | Use Zenoh for all cross-subsystem real-time communication |
| AOR-INT-002 | Store knowledge in KMS, not in service-specific databases |
| AOR-INT-003 | Route AI requests through consensus engine |
| AOR-INT-004 | Observe all subsystems through Prajna SmartMetrics |
| AOR-INT-005 | Synchronize state via SQLite/DuckDB sovereignty model |
| AOR-INT-006 | Authenticate cross-subsystem calls with capability tokens |
| AOR-INT-007 | Log integration events to Immutable Register |
| AOR-INT-008 | Test integration points in shadow universe first |

---

## 10.0 Related Documents

| Document | Location |
|----------|----------|
| EIGHT_LEVEL_FRACTAL_ANALYSIS.md | docs/architecture/ |
| EIGHT_LEVEL_INTERACTION_MATRICES.md | docs/architecture/ |
| OBSERVER_OBSERVABILITY_SEPARATION.md | docs/architecture/ |
| SMRITI_COMPREHENSIVE_USECASES.md | docs/kms/ |
| SMRITI_FEATURE_SPECIFICATIONS.md | docs/kms/ |
| SMRITI_UI_UX_SPECIFICATION.md | docs/kms/ |
| CLAUDE.md | / |

---

**Document Control**

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Created | 2026-01-11 |
| Author | Claude Opus 4.5 |
| STAMP | SC-INT-001 to SC-INT-008 |
| AOR | AOR-INT-001 to AOR-INT-008 |

---

*This document is part of the Indrajaal SIL-6 Biomorphic Fractal Mesh specification.*
