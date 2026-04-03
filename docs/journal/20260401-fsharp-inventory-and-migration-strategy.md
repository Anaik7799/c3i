# F# Functionality Inventory and Migration Strategy

**Date**: 2026-04-01 10:00 CEST
**Author**: Gemini CLI
**Status**: ACTIVE
**Topic**: F# to Gleam Migration Planning

## 1. Executive Summary
This journal entry documents the comprehensive inventory of functionality currently implemented in the F# CEPAF codebase and defines a criticality-based migration strategy to Gleam. The inventory covers Planning, Sentinel/MCP, Smriti/Knowledge, and Container orchestration.

## 2. Functional Inventory (5-Level Detail)

### 2.1 Planning & Task Management (Cepaf.Planning)
1. **Core Task Engine**
   - 1.1 Task Entity Definition
     - 1.1.1 Lifecycle states (Todo, InProgress, Done, Blocked, Cancelled).
     - 1.1.2 Metadata (Priority, Timeline, Versioning, Set of Tags).
     - 1.1.3 Dependencies (TaskId set) and Estimate/Actual tracking.
   - 1.2 Task Operations
     - 1.2.1 Creation (simple/full), Update (versioned), Status transitions.
     - 1.2.2 Querying (overdue, complete, remaining time, age).
     - 1.2.3 List operations (filtering, sorting by status/priority/date).
2. **Planning Enforcement & Safety**
   - 2.1 SafetyKernel (Guardian Integration)
     - 2.1.1 Constitutional Invariant Verification (Ψ₀-Ψ₅).
     - 2.1.2 Founder's Directive Validation (Ω₀).
     - 2.1.3 Operational checks (Guardian pre-approval, resource bounds, concurrency).
   - 2.2 PlanningEnforcer (SC-TODO-001)
     - 2.2.1 Path validation (Forbidden list, regex patterns).
     - 2.2.2 Agent classification & fingerprinting (Human, AI, System).
     - 2.2.3 Circuit breaker & immutable audit log (Append-only).
3. **Orchestration & Integration**
   - 3.1 Startup Optimization
     - 3.1.1 Mathematical boot sequencing.
     - 3.1.2 Resource-aware parallelization.
   - 3.2 External Sync
     - 3.2.1 Markdown backup sync (PROJECT_TODOLIST.md).
     - 3.2.2 Chaya Simulation sync (Status/Priority mapping).
     - 3.2.3 Git integration (git add automated).

### 2.2 Sentinel & Swarm Verification (Cepaf.Sentinel.MCP)
1. **MCP Tooling**
   - 1.1 Swarm Verification (swarm_verify)
     - 1.1.1 OODA Loop compliance (5 tiers: Agent, Intelligence, Knowledge, Cortex, Strategy).
     - 1.1.2 Observability pipeline testing (OTEL → Prometheus → Grafana → Zenoh).
     - 1.1.3 Trace injection and per-container contribution checks.
   - 1.2 Container & Fractal Verification
     - 1.2.1 Deep fractal check (L0-L7 layers).
     - 1.2.2 Control plane round-trip verification.
     - 1.2.3 Embedded F# agent probes (binary presence, runtime health, sovereign state).
2. **Security & Resource Control**
   - 2.1 CPU Governor
     - 2.1.1 85% hard limit enforcement.
     - 2.1.2 Adaptive scheduler count adjustment.
   - 2.2 Sentinel Tools
     - 2.2.1 Real-time health monitoring.
     - 2.2.2 Anomaly detection.

### 2.3 Smriti & Knowledge Engine (Cepaf.Smriti & Cepaf.Knowledge)
1. **Data Persistence**
   - 1.1 Storage Backends
     - 1.1.1 DuckDB (Columnar/Analytics).
     - 1.1.2 SQLite (WAL mode/Sovereign state).
   - 1.2 Catalog Management
     - 1.2.1 Mesh Catalog (Service topology).
     - 1.2.2 Safe Catalog (STAMP-compliant registry).
2. **Knowledge Operations**
   - 2.1 Semantic Search
     - 2.1.1 Vector search integration.
     - 2.1.2 Entropy calculation for artifacts.
   - 2.2 Scaffolding & Docs
     - 2.2.1 TechDocs generation.
     - 2.2.2 System scorecard analytics.

## 3. Criticality-Based Migration Plan

| Phase | Goal | Priority | Components |
|:---|:---|:---|:---|
| **Phase 1** | Foundation & Core Logic | P0 | Core Types, Task Domain, SafetyKernel, Enforcer |
| **Phase 2** | Management & Persistence | P1 | Repository, Markdown Parser, Manager, Basic Catalog |
| **Phase 3** | Integration & Observability | P2 | Zenoh Adapter, MCP Tools, Swarm Verification, CPU Governor |
| **Phase 4** | Evolution & Analytics | P3 | Evolution Tools, Knowledge Engine, Search, Cockpit Backend |
| **Phase 5** | Infrastructure & Containers | P4 | Podman Orchestration, Kubernetes Bridge (DEFERRED) |

## 4. Fractal Check (L0-L7)
- **L0 (Constitutional)**: SafetyKernel ensures Ψ invariants. Verified.
- **L1 (Atomic)**: Base types and Result patterns are robust. Verified.
- **L2 (Component)**: Planning/Manager orchestration layer is solid. Verified.
- **L3 (Transaction)**: Repository handles atomic SQLite/DuckDB writes. Verified.
- **L4 (System)**: Container logic deferred, but pathing follows SC-CNT rules.
- **L5 (Cognitive)**: Knowledge engine entropy and search logic present. Verified.
- **L6 (Ecosystem)**: Zenoh adapter and Swarm verification handle mesh state. Verified.
- **L7 (Federation)**: Cross-holon protocols defined in Knowledge/Topology. Verified.

## 5. Next Steps
1. Initialize Phase 1 Gleam modules.
2. Port Task Domain logic with corresponding Gleam tests.
3. Implement SafetyKernel in Gleam with full STAMP compliance.
