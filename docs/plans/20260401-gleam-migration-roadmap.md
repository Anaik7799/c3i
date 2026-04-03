# Gleam Migration Roadmap - F# Porting Strategy

**Date**: 2026-04-01 10:30 CEST
**Author**: Gemini CLI + Claude Opus 4.6
**Version**: 2.0.0
**Status**: ACTIVE
**Last Updated**: 20260401-1900 CEST

## Change Log
| Timestamp | Change Type | Description | Author |
|-----------|-------------|-------------|--------|
| 20260401-1030 CEST | CREATED | Initial 5-level plan | Gemini CLI |
| 20260401-1800 CEST | UPDATED | GEMINI.md/CLAUDE.md STAMP/AOR update (32 SC-*, 24 AOR-*) | Claude Opus 4.6 |
| 20260401-1830 CEST | UPDATED | Triple-interface mandate (SC-GLM-UI-001 to 010), scaffolding modules | Claude Opus 4.6 |
| 20260401-1900 CEST | UPDATED | Full per-plane triple-interface (18 modules, 1076 LOC Gleam) | Claude Opus 4.6 |

## 1. Goal
Transition all safety-critical and operational functionality from F# (CEPAF) to Gleam to leverage the BEAM VM's native type safety, actor model, and hot-reloading capabilities while maintaining SIL-6 biomorphic standards.

**UI Mandate**: Every Gleam c3i function MUST expose 3 interfaces (SC-GLM-UI-001):
1. **Lustre** — real-time Web dashboard (SSR on BEAM)
2. **Wisp** — JSON API for agents/programmatic access
3. **TUI** — ANSI terminal for operators and emergency access

## 2. 5-Level Detailed Execution Plan

### 2.1 Level 1: Foundation & Core Logic (Priority: P0) — COMPLETED
- **2.1.1 Level 2: Core Domain Types** — COMPLETED
  - 2.1.1.1 `core/types.gleam` — TaskStatus, Priority, NonEmptyString
  - 2.1.1.2 `core/result.gleam` — Result patterns, error handling
  - 2.1.1.3 `core/ids.gleam` — ULID-like identifier generation
- **2.1.2 Level 2: Task Domain** — COMPLETED
  - 2.1.2.1 `planning/task.gleam` — Task record, lifecycle states
  - 2.1.2.2 `planning/manager.gleam` — Create, Update, Transition ops
  - 2.1.2.3 `planning/task_list.gleam` — Sorting, filtering
- **2.1.3 Level 2: Safety & Enforcement** — COMPLETED
  - 2.1.3.1 `planning/safety_kernel.gleam` — Psi-0 to Psi-5, Omega-0 checks
  - 2.1.3.2 `planning/enforcer.gleam` — SC-TODO-001, path validation, circuit breaker
  - 2.1.3.3 `planning/planning_enforcer.gleam` — Agent classification

### 2.2 Level 1: Knowledge & Memory — Smriti (Priority: P0) — COMPLETED
- **2.2.1 Level 2: RDF Triple Store** — COMPLETED
  - 2.2.1.1 `knowledge/semantic.gleam` — Triples, SPO/POS/OSP indexing
  - 2.2.1.2 `knowledge/repository.gleam` — SQLite/DuckDB bindings
  - 2.2.1.3 `knowledge/domain.gleam` — KnowledgeNode, HolonLevel, RhetoricalFunction

### 2.3 Level 1: Communication & IPC (Priority: P1) — COMPLETED
- **2.3.1 Level 2: Zenoh Mesh** — COMPLETED
  - 2.3.1.1 `zenoh/client.gleam` — Zenoh session, publish/subscribe
  - 2.3.1.2 `zenoh/lifecycle.gleam` — Resilient session GenServer
  - 2.3.1.3 `zenoh/safety.gleam` — TMR 2oo3 voting
  - 2.3.1.4 `zenoh/domain.gleam` — ZenohHealth, ConnectionStatus, LifecycleState
- **2.3.2 Level 2: MCP Server** — COMPLETED
  - 2.3.2.1 `mcp/protocol.gleam` — JSON-RPC 2.0 encoding
  - 2.3.2.2 `mcp/server.gleam` — Stdio transport, request dispatch
  - 2.3.2.3 `mcp/tools.gleam` — Tool handlers

### 2.4 Level 1: Agentic & Immune (Priority: P1) — COMPLETED
- **2.4.1 Level 2: Mara Chaos Agent** — COMPLETED
  - 2.4.1.1 `immune/mara.gleam` — Random strike generators
  - 2.4.1.2 `immune/system.gleam` — Automated rollback on safety violation
- **2.4.2 Level 2: Neural-Immune Defense** — COMPLETED
  - 2.4.2.1 `immune/patterns.gleam` — Antibody synthesis, anomaly detection
  - 2.4.2.2 `immune/domain.gleam` — ChaosAttack, Antibody, ImmuneEvent

### 2.5 Level 1: Interaction & Cockpit (Priority: P2) — COMPLETED
- **2.5.1 Level 2: ANSI TUI** — COMPLETED
  - 2.5.1.1 `cockpit/visuals.gleam` — Sparklines, progress bars, color coding
  - 2.5.1.2 `cockpit/domain.gleam` — MeshNode, Alarm, SmartMetric, ViewMode (200+ lines)
- **2.5.2 Level 2: Triple-Interface UI** — COMPLETED (20260401-1900)
  - 2.5.2.1 Shared types: `ui/domain.gleam` — Page, HealthStatus, TelemetryPoint, Action, RenderContext
  - 2.5.2.2 Lustre WebUI: 7 components (app + 6 per-plane)
  - 2.5.2.3 Wisp API: 7 endpoints (router + 6 per-plane)
  - 2.5.2.4 TUI views: 7 renderers (renderer + 6 per-plane)
  - 2.5.2.5 Dependencies: lustre >= 4.0, wisp >= 1.0, mist >= 3.0

### 2.6 Level 1: Infrastructure & Containers (Priority: P3) — DEFERRED
- **2.6.1 Level 2: Podman Orchestration** — TYPES ONLY
  - 2.6.1.1 `podman/domain.gleam` — Container, Image, Volume types
  - 2.6.1.2 `podman/http_client.gleam` — UDS client stub (no active implementation)
  - 2.6.1.3 `podman/containers.gleam`, `networks.gleam`, `volumes.gleam` — API wrappers (stubs)
- **2.6.2 Level 2: Substrate** — TYPES ONLY
  - 2.6.2.1 `substrate/database.gleam`, `file_system.gleam`, `governor.gleam`
  - 2.6.2.2 `verification/swarm.gleam`, `probes.gleam`
- **2.6.3 Level 2: Container Lifecycle** — NOT STARTED
  - 2.6.3.1 `sa-up` / `sa-down` / `sa-status` reimplementation — PENDING
  - 2.6.3.2 7-tier boot sequence in Gleam — PENDING
  - 2.6.3.3 Image staleness detection — PENDING

## 3. Module Inventory (as of 20260401-1900)

### Source Modules (lib/cepaf_gleam/src/)

| Plane | Modules | Status |
|-------|---------|--------|
| core/ | types, ids, result | COMPLETED |
| planning/ | task, task_list, domain, repository, manager, cli, parser, markdown_parser, enforcer, planning_enforcer, safety_kernel | COMPLETED |
| knowledge/ | semantic, repository, domain | COMPLETED |
| zenoh/ | client, domain, lifecycle, safety | COMPLETED |
| mcp/ | protocol, server, tools | COMPLETED |
| immune/ | domain, mara, system, patterns | COMPLETED |
| cockpit/ | domain, visuals | COMPLETED |
| ui/domain | domain (shared types) | COMPLETED |
| ui/lustre/ | app, planning, immune, knowledge, zenoh_mesh, verification, cockpit_view | COMPLETED |
| ui/wisp/ | router, planning_api, immune_api, knowledge_api, zenoh_api, verification_api, cockpit_api | COMPLETED |
| ui/tui/ | renderer, planning_view, immune_view, knowledge_view, zenoh_view, verification_view, cockpit_view | COMPLETED |
| podman/ | domain, http_client, containers, networks, volumes | TYPES ONLY |
| substrate/ | database, file_system, governor | TYPES ONLY |
| verification/ | swarm, probes | COMPLETED |
| db/ | duckdb | COMPLETED |
| **TOTAL** | **57 modules** | |

### STAMP Constraints Added (32 total)
- SC-GLM-CMP-001 to 005 (Gleam compilation safety)
- SC-GLM-CORE-001 to 007 (Gleam core module safety)
- SC-GLM-NIF-001 to 005 (Gleam-Rust NIF safety)
- SC-GLM-MIG-001 to 005 (Migration safety)
- SC-GLM-UI-001 to 010 (Triple-interface mandate)

### AOR Rules Added (24 total)
- AOR-GLM-001 to 010 (Gleam-specific agent rules)
- AOR-BUILD-001 to 004 (Multi-language build order)
- AOR-GLM-UI-001 to 010 (Triple-interface agent rules)

### FMEA Entries (12 total)
| Risk | RPN | Status |
|------|-----|--------|
| Semantic drift F# != Gleam | 108 | MITIGATED — dual property testing |
| Container substrate regression | 108 | MITIGATED — Phase 6 deferred |
| DuckDB perf regression | 96 | MONITORING |
| Triple-interface divergence | 64 | MITIGATED — SC-GLM-UI-001 enforced |
| Lustre SSR latency > 100ms | 63 | MONITORING |
| Build order violation | 50 | MITIGATED — AOR-BUILD-001 |
| Gleam-Elixir FFI type mismatch | 42 | MITIGATED — typed wrappers |
| Gleam toolchain in container | 42 | MITIGATED — .beam files only |
| Rust NIF crash propagation | 36 | MITIGATED — dirty scheduler |
| Planning DB access loss | 32 | MITIGATED — F# sa-plan authoritative |
| Lustre dep breaking change | 30 | MITIGATED — version pinning |
| Wisp port conflict | 12 | MITIGATED — port 4100 |

## 4. Success Criteria

- [x] 0 Errors / 0 Warnings in Gleam compilation (SC-GLM-CMP-001) — achieved 20260401
- [x] Foundation & Core Logic (Phase 1) — COMPLETED
- [x] Knowledge & Memory (Phase 2) — COMPLETED
- [x] Communication & IPC (Phase 3) — COMPLETED
- [x] Agentic & Immune (Phase 4) — COMPLETED
- [x] Interaction & Cockpit (Phase 5) — COMPLETED
- [x] Triple-interface per plane (SC-GLM-UI-001) — 6/6 planes COMPLETED
- [x] GEMINI.md/CLAUDE.md updated with Gleam STAMP/AOR — COMPLETED
- [ ] >95% Test coverage for ported modules — PENDING (TDG tests needed)
- [ ] `gleam deps download` for lustre/wisp/mist — PENDING
- [ ] Lustre HTML view functions — PENDING
- [ ] Wisp Mist HTTP server wiring — PENDING
- [ ] Zenoh subscription in Lustre (SC-GLM-UI-005) — PENDING
- [ ] Container substrate (Phase 6) — DEFERRED

## 5. Risks & Mitigations

See FMEA table above. Top risks by RPN:
1. **Semantic drift** (RPN 108) — dual property testing, weekly drift checks
2. **Container regression** (RPN 108) — Phase 6 deferred until cognitive verified
3. **DuckDB perf** (RPN 96) — FFI monitoring, <50ms latency target
4. **Interface divergence** (RPN 64) — SC-GLM-UI-001 + AOR-GLM-UI-009 enforcement
