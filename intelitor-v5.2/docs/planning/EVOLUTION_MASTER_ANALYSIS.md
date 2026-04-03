# INDRAJAAL SYSTEM EVOLUTION MASTER ANALYSIS
## Version 21.3.0-SIL6 | Sprint 46+ Evolution Roadmap

```
    ●╮       ╭●
     ╰╮ ╭─╮ ╭╯
  ●───◉─┤◈├─◉───●   EVOLUTION ANALYSIS
     ╭╯ ╰─╯ ╰╮       10-Level Detail × 10-Level Interaction
    ●╯       ╰●       Comprehensive Development Plan
```

**Document ID**: DOC-EVO-2026-01-14
**Status**: ACTIVE
**Author**: Claude Opus 4.5
**Created**: 2026-01-14
**STAMP Compliance**: SC-CHG-001, SC-DOC-001

---

## TABLE OF CONTENTS

1. [Executive Summary](#1-executive-summary)
2. [10-Level Detail Framework](#2-10-level-detail-framework)
3. [10-Level Interaction Matrix](#3-10-level-interaction-matrix)
4. [Feature Evolution Catalog](#4-feature-evolution-catalog)
5. [Requirements Specification](#5-requirements-specification)
6. [Architecture Design](#6-architecture-design)
7. [Dataflow Analysis](#7-dataflow-analysis)
8. [Control Flow Design](#8-control-flow-design)
9. [Implementation Plan](#9-implementation-plan)
10. [Testing Strategy](#10-testing-strategy)
11. [Interaction Issues & Mitigations](#11-interaction-issues--mitigations)
12. [Usage Documentation](#12-usage-documentation)
13. [References](#13-references)

---

## 1. EXECUTIVE SUMMARY

### 1.1 Evolution Scope

This document provides comprehensive analysis for evolving the Indrajaal system from its current 95% completion state to full enterprise capability across 8 evolution domains:

| Domain | Features | Priority | Effort |
|--------|----------|----------|--------|
| **E1: Zenoh.Net Integration** | Real pub/sub mesh | P0 | 3 sprints |
| **E2: Vector Similarity Search** | FAISS/HNSW semantic search | P0 | 2 sprints |
| **E3: Hierarchical Task IDs** | Fractal ID scheme | P1 | 1 sprint |
| **E4: Planning System Enhancement** | Dependencies, telemetry | P1 | 2 sprints |
| **E5: Podman API Completion** | Streaming, exec | P2 | 2 sprints |
| **E6: Business Domains (8)** | Access, Guard Tour, etc. | P1 | 8 sprints |
| **E7: SMRITI Knowledge Evolution** | AI patterns, federation | P2 | 3 sprints |
| **E8: Observability Enhancement** | SIL-6 dashboard | P2 | 2 sprints |

**Total Estimated Effort**: 23 sprints (assuming 2-week sprints)

### 1.2 Success Criteria

```
┌─────────────────────────────────────────────────────────────┐
│  EVOLUTION SUCCESS METRICS                                  │
├─────────────────────────────────────────────────────────────┤
│  Domain Completion:     19/20 → 27/27 (100%)               │
│  Feature Coverage:      Current → +47 new features          │
│  Test Coverage:         95% → 98%                           │
│  STAMP Constraints:     615 → 750+                          │
│  SIL Level:             SIL-6 maintained                    │
│  Intelligence Factor:   1.0x → 1.52x                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 10-LEVEL DETAIL FRAMEWORK

### 2.1 Level Definitions

| Level | Name | Scope | Artifact |
|-------|------|-------|----------|
| L0 | **Vision** | Strategic intent | Mission statement |
| L1 | **Domain** | Business capability | Domain model |
| L2 | **Feature** | User-facing function | Feature spec |
| L3 | **Component** | Module/service | Component design |
| L4 | **Interface** | API/contract | Interface spec |
| L5 | **Function** | Implementation unit | Function spec |
| L6 | **Algorithm** | Logic/computation | Algorithm design |
| L7 | **Data** | State/storage | Data model |
| L8 | **Protocol** | Communication | Protocol spec |
| L9 | **Deployment** | Infrastructure | Deploy config |

### 2.2 Level Application Matrix

```
Evolution Domain    L0  L1  L2  L3  L4  L5  L6  L7  L8  L9
─────────────────────────────────────────────────────────────
E1: Zenoh.Net       ●   ●   ●   ●   ●   ●   ●   ●   ●   ●
E2: Vector Search   ●   ●   ●   ●   ●   ●   ●   ●   ○   ●
E3: Hierarchical ID ●   ●   ●   ●   ●   ●   ●   ●   ○   ○
E4: Planning Enh.   ●   ●   ●   ●   ●   ●   ●   ●   ●   ●
E5: Podman API      ●   ●   ●   ●   ●   ●   ●   ●   ●   ●
E6: Business Dom.   ●   ●   ●   ●   ●   ●   ●   ●   ●   ●
E7: SMRITI Evol.    ●   ●   ●   ●   ●   ●   ●   ●   ●   ●
E8: Observability   ●   ●   ●   ●   ●   ●   ○   ●   ●   ●

● = Required  ○ = Optional
```

---

## 3. 10-LEVEL INTERACTION MATRIX

### 3.1 Interaction Level Definitions

| Level | Name | Description | Stakeholder |
|-------|------|-------------|-------------|
| I0 | **Constitutional** | Ψ₀-Ψ₅ invariant compliance | Guardian |
| I1 | **Operational** | Ω₀-Ω₉ axiom adherence | Executive Agent |
| I2 | **Safety** | SC-* constraint verification | Safety Validator |
| I3 | **Agent Rules** | AOR-* rule compliance | Domain Agents |
| I4 | **Error Patterns** | EP-* pattern handling | Debugger |
| I5 | **FMEA** | Failure mode analysis | Risk Analyst |
| I6 | **TDG** | Test-driven generation | Test Generator |
| I7 | **BDD** | Behavior-driven validation | Product Owner |
| I8 | **Integration** | Cross-system interaction | Architect |
| I9 | **Federation** | Multi-holon coordination | Federation |

### 3.2 Evolution × Interaction Matrix

```
                    I0   I1   I2   I3   I4   I5   I6   I7   I8   I9
                   CON  OPR  SAF  AOR  ERR  FME  TDG  BDD  INT  FED
────────────────────────────────────────────────────────────────────
E1: Zenoh.Net       H    H    H    H    M    H    H    M    H    H
E2: Vector Search   M    H    M    M    M    M    H    H    M    M
E3: Hierarchical    L    M    L    M    L    L    H    M    M    L
E4: Planning        M    H    M    H    M    M    H    H    H    M
E5: Podman API      L    H    M    M    M    M    H    M    H    L
E6: Business Dom.   H    H    H    H    M    H    H    H    H    M
E7: SMRITI          H    H    H    H    M    M    H    H    H    H
E8: Observability   M    H    H    M    M    H    H    M    H    M

H = High priority  M = Medium  L = Low
```

---

## 4. FEATURE EVOLUTION CATALOG

### 4.1 E1: Zenoh.Net Integration

#### 4.1.1 Feature Summary
| ID | Feature | Description | Priority |
|----|---------|-------------|----------|
| E1-F01 | Zenoh Session Manager | Connection lifecycle management | P0 |
| E1-F02 | Publisher API | Topic-based message publishing | P0 |
| E1-F03 | Subscriber API | Topic subscription with handlers | P0 |
| E1-F04 | Queryable API | Request-response patterns | P1 |
| E1-F05 | Key Expression Router | Hierarchical topic matching | P1 |
| E1-F06 | QoS Configuration | Reliability, ordering settings | P1 |
| E1-F07 | Session Reconnection | Auto-reconnect with backoff | P0 |
| E1-F08 | Telemetry Bridge | Metrics/logs via Zenoh | P1 |
| E1-F09 | Cluster Discovery | Peer discovery protocol | P2 |
| E1-F10 | Federation Gateway | Cross-holon Zenoh bridge | P2 |

#### 4.1.2 Current State Analysis
```fsharp
// Current: lib/cepaf/src/Cepaf.Planning/ZenohAdapter.fs
module Cepaf.Planning.ZenohAdapter

// TODO: Integrate actual Zenoh.Net.Api when available in deps
let publish (topic: string) (message: string) =
    printfn $"[ZENOH-PLACEHOLDER] Publishing to {topic}: {message}"

let subscribe (topic: string) (handler: string -> unit) =
    printfn $"[ZENOH-PLACEHOLDER] Subscribing to {topic}"
```

#### 4.1.3 Target State
```fsharp
// Target: Real Zenoh.Net integration
module Cepaf.Planning.ZenohAdapter

open Zenoh.Net

type ZenohConfig = {
    Mode: ZenohMode
    ConnectEndpoints: string list
    ListenEndpoints: string list
    Timeout: TimeSpan
    RetryPolicy: RetryPolicy
}

type ZenohSession = {
    Session: Session
    Publishers: Map<string, Publisher>
    Subscribers: Map<string, Subscriber>
    Config: ZenohConfig
}

let createSession (config: ZenohConfig) : Result<ZenohSession, ZenohError> =
    // Real implementation with connection management

let publish (session: ZenohSession) (keyExpr: string) (payload: byte[]) =
    // Real pub/sub with QoS

let subscribe (session: ZenohSession) (keyExpr: string) (handler: Sample -> unit) =
    // Real subscription with callback
```

---

### 4.2 E2: Vector Similarity Search

#### 4.2.1 Feature Summary
| ID | Feature | Description | Priority |
|----|---------|-------------|----------|
| E2-F01 | Embedding Generator | Text to vector conversion | P0 |
| E2-F02 | Vector Index | HNSW index structure | P0 |
| E2-F03 | Similarity Search | k-NN query execution | P0 |
| E2-F04 | Hybrid Search | Vector + keyword combined | P1 |
| E2-F05 | Index Persistence | Durable vector storage | P0 |
| E2-F06 | Incremental Updates | Real-time index updates | P1 |
| E2-F07 | Batch Operations | Bulk insert/delete | P1 |
| E2-F08 | Dimension Reduction | PCA/UMAP compression | P2 |
| E2-F09 | Multi-Vector Search | Multiple query vectors | P2 |
| E2-F10 | Federation Sync | Cross-holon vector sharing | P2 |

#### 4.2.2 Current State
```fsharp
// Current: lib/cepaf/src/Cepaf.Podman/Vector/VectorStore.fs
// Placeholder for vector similarity search
let searchSimilar (query: float[]) (k: int) =
    [] // Placeholder returns empty
```

#### 4.2.3 Target Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    VECTOR SEARCH ARCHITECTURE               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   Embedding  │───▶│  HNSW Index  │◀───│   DuckDB     │  │
│  │   Generator  │    │  (In-Memory) │    │  (Persist)   │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         │                   │                    │          │
│         ▼                   ▼                    ▼          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                  Query Processor                      │  │
│  │  • k-NN Search    • Hybrid (Vector + Text)           │  │
│  │  • Range Search   • Filtered Search                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### 4.3 E3: Hierarchical Task IDs

#### 4.3.1 Feature Summary
| ID | Feature | Description | Priority |
|----|---------|-------------|----------|
| E3-F01 | ID Generation | Fractal ID scheme | P0 |
| E3-F02 | Parent-Child Links | Hierarchy navigation | P0 |
| E3-F03 | Subtask Tracking | Completion propagation | P1 |
| E3-F04 | ID Validation | Format verification | P0 |
| E3-F05 | Migration Tool | GUID to hierarchical | P1 |

#### 4.3.2 ID Scheme Design
```
Format: [Sprint].[Epic].[Story].[Task].[Subtask]

Examples:
  46.0.0.0.0     = Sprint 46 root
  46.1.0.0.0     = Epic 1 in Sprint 46
  46.1.2.0.0     = Story 2 in Epic 1
  46.1.2.3.0     = Task 3 in Story 2
  46.1.2.3.4     = Subtask 4 in Task 3

Rules:
  - Each level 0-99 (2 digits)
  - Parent completion requires all children complete
  - Orphan detection on invalid parent references
```

---

### 4.4 E4: Planning System Enhancement

#### 4.4.1 Feature Summary
| ID | Feature | Description | Priority |
|----|---------|-------------|----------|
| E4-F01 | Dependency Graph | Task dependency DAG | P0 |
| E4-F02 | Critical Path | Longest path calculation | P1 |
| E4-F03 | Cycle Detection | Prevent circular deps | P0 |
| E4-F04 | OODA Telemetry | Cycle time metrics | P1 |
| E4-F05 | Mesh Distribution | Multi-node task spread | P1 |
| E4-F06 | Auto-Scheduling | Dependency-aware ordering | P2 |
| E4-F07 | Gantt Export | Timeline visualization | P2 |
| E4-F08 | Burndown Charts | Progress tracking | P2 |

---

### 4.5 E5: Podman API Completion

#### 4.5.1 Feature Summary
| ID | Feature | Description | Priority |
|----|---------|-------------|----------|
| E5-F01 | Volume Streaming | Async volume data | P1 |
| E5-F02 | Image Layer Stream | Layer download/upload | P1 |
| E5-F03 | Exec with PTY | Interactive terminal | P1 |
| E5-F04 | Log Streaming | Real-time container logs | P0 |
| E5-F05 | Stats Streaming | Live resource metrics | P1 |
| E5-F06 | Event Subscription | Container lifecycle events | P1 |
| E5-F07 | Network Management | CNI integration | P2 |
| E5-F08 | Secret Management | Secure credential store | P2 |

---

### 4.6 E6: Business Domains (8 New)

#### 4.6.1 Domain Catalog

| Domain | Resources | Complexity | Sprint Est. |
|--------|-----------|------------|-------------|
| **D1: Access Control** | 10 | High | 2 |
| **D2: Guard Tour** | 8 | Medium | 1 |
| **D3: Analytics** | 12 | High | 2 |
| **D4: Communication** | 6 | Medium | 1 |
| **D5: Asset Management** | 8 | Medium | 1 |
| **D6: Risk Management** | 10 | High | 1 |
| **D7: Visitor Management** | 6 | Low | 0.5 |
| **D8: Training** | 8 | Medium | 0.5 |

#### 4.6.2 D1: Access Control Domain Detail

```elixir
# Resources to implement:
defmodule Indrajaal.AccessControl do
  # Core Resources
  - Permission          # Atomic permission unit
  - Role                # Permission collection
  - RoleAssignment      # User-Role binding
  - AccessPolicy        # Conditional access rules
  - AccessGroup         # User groupings

  # Audit Resources
  - AccessLog           # Access attempt records
  - PolicyViolation     # Violation tracking
  - PrivilegeEscalation # Escalation requests

  # Integration Resources
  - ExternalIdentity    # SSO/LDAP integration
  - AccessToken         # JWT/OAuth tokens
end
```

---

### 4.7 E7: SMRITI Knowledge Evolution

#### 4.7.1 Feature Summary
| ID | Feature | Description | Priority |
|----|---------|-------------|----------|
| E7-F01 | Pattern Mining | Auto-discover code patterns | P1 |
| E7-F02 | Knowledge Graph | Semantic relationships | P0 |
| E7-F03 | Federation Protocol | Cross-holon sync | P2 |
| E7-F04 | Spaced Repetition | SM-2 for retention | P1 |
| E7-F05 | Context Distillation | Session to holon | P1 |
| E7-F06 | Semantic Search | Vector-based retrieval | P1 |
| E7-F07 | Lineage Tracking | Knowledge provenance | P1 |
| E7-F08 | AI Agent Memory | Persistent agent context | P0 |

---

### 4.8 E8: Observability Enhancement

#### 4.8.1 Feature Summary
| ID | Feature | Description | Priority |
|----|---------|-------------|----------|
| E8-F01 | SIL-6 Dashboard | Biomorphic health view | P0 |
| E8-F02 | Trace Correlation | Distributed tracing | P1 |
| E8-F03 | Anomaly Detection | ML-based alerts | P2 |
| E8-F04 | SLA Monitoring | Service level tracking | P1 |
| E8-F05 | Capacity Planning | Resource forecasting | P2 |
| E8-F06 | Chaos Engineering | Fault injection | P2 |

---

## 5. REQUIREMENTS SPECIFICATION

### 5.1 Functional Requirements

#### 5.1.1 E1: Zenoh.Net Integration Requirements

| REQ-ID | Requirement | Priority | Verification |
|--------|-------------|----------|--------------|
| E1-REQ-001 | System SHALL establish Zenoh session within 5s | P0 | Integration Test |
| E1-REQ-002 | System SHALL reconnect on session loss with exponential backoff | P0 | Chaos Test |
| E1-REQ-003 | Publisher SHALL deliver messages within 100ms (p99) | P0 | Performance Test |
| E1-REQ-004 | Subscriber SHALL receive messages in FIFO order | P0 | Protocol Test |
| E1-REQ-005 | System SHALL support 1000+ concurrent subscriptions | P1 | Load Test |
| E1-REQ-006 | System SHALL log all pub/sub operations to telemetry | P1 | Audit Test |
| E1-REQ-007 | System SHALL support QoS levels: BestEffort, Reliable | P1 | Protocol Test |
| E1-REQ-008 | System SHALL discover peers within 10s | P2 | Integration Test |
| E1-REQ-009 | System SHALL route messages across federation | P2 | Federation Test |
| E1-REQ-010 | System SHALL handle network partitions gracefully | P0 | Chaos Test |

#### 5.1.2 E2: Vector Search Requirements

| REQ-ID | Requirement | Priority | Verification |
|--------|-------------|----------|--------------|
| E2-REQ-001 | System SHALL generate embeddings for text < 100ms | P0 | Performance Test |
| E2-REQ-002 | System SHALL support 1M+ vectors in index | P0 | Scale Test |
| E2-REQ-003 | System SHALL execute k-NN query < 50ms (k=10) | P0 | Performance Test |
| E2-REQ-004 | System SHALL persist index to DuckDB | P0 | Durability Test |
| E2-REQ-005 | System SHALL support incremental index updates | P1 | Functional Test |
| E2-REQ-006 | System SHALL support hybrid vector+keyword search | P1 | Functional Test |
| E2-REQ-007 | System SHALL achieve 95% recall@10 | P1 | Quality Test |
| E2-REQ-008 | System SHALL compress vectors with <5% quality loss | P2 | Quality Test |

### 5.2 Non-Functional Requirements

| Category | Requirement | Target |
|----------|-------------|--------|
| **Performance** | API response time | < 50ms (p99) |
| **Scalability** | Concurrent users | 10,000+ |
| **Availability** | Uptime SLA | 99.99% |
| **Reliability** | Data durability | 99.999999% |
| **Security** | Encryption | TLS 1.3 + Ed25519 |
| **Compliance** | Safety level | SIL-6 maintained |

### 5.3 STAMP Constraint Requirements

| SC-ID | Constraint | Evolution Domain |
|-------|------------|------------------|
| SC-EVO-001 | All evolution features SHALL maintain functional invariant | All |
| SC-EVO-002 | All APIs SHALL be backward compatible within major version | All |
| SC-EVO-003 | All features SHALL have 95%+ test coverage | All |
| SC-EVO-004 | All features SHALL pass FMEA with RPN < 100 | All |
| SC-EVO-005 | All features SHALL integrate with Guardian | All |
| SC-EVO-006 | All features SHALL publish telemetry to Zenoh | E1+ |
| SC-EVO-007 | All business domains SHALL use Ash 3.x patterns | E6 |
| SC-EVO-008 | All features SHALL support federation mode | E1, E7 |

---

*Document continues in Part 2...*
