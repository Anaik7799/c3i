# KMS 5-Level Implementation Plan
**Date**: 2025-12-30T17:00:00+01:00
**Version**: 1.0.0
**Status**: ACTIVE
**Framework**: SOPv5.11 + STAMP + TDG + 5-Level Hierarchy

---

## Executive Summary

This plan details the complete implementation of the Fractal Holonic Knowledge Management System (KMS) following the 5-level hierarchical task decomposition pattern.

### Current Status
```
Phase 0-2: Foundation + APIs  ████████████████████ 100% ✅
Phase 3: UI Components        ██████████░░░░░░░░░░  50% ⏳
Phase 4: Integration          ░░░░░░░░░░░░░░░░░░░░   0% ❌
Phase 5: Advanced             ░░░░░░░░░░░░░░░░░░░░   0% ❌
```

### STAMP Safety Constraints
- **SC-KMS-001**: SQLite + DuckDB only (no ETS/DETS/Khepri for persistence)
- **SC-KMS-002**: Cross-runtime access (Elixir + F# share databases)
- **SC-KMS-003**: Portable holons (directory copy = full backup)
- **SC-KMS-004**: OODA cycle <100ms on SQLite hot path

---

## L5.0 STRATEGIC LAYER (Supervisor)

### 5.0.0.0.0 - KMS Grand Unification Goal [L5-SUPERVISOR]
**Status**: in_progress | **Priority**: P0 | **Agent**: L5-SUPERVISOR
**THINKING**: Orchestrating KMS implementation across 6 domain agents
**DOING**: Monitoring progress, resolving cross-agent dependencies

**Metrics**:
- Total Tables: 29 (implemented)
- Total Functions: ~150 (implemented)
- UI Integration: 0% → 100%
- AI Integration: 0% → 100%
- Completion Target: 100%

**Success Criteria**:
- [ ] All 6 domain agents report 100% completion
- [ ] Phoenix LiveView dashboard operational at `/prajna/knowledge`
- [ ] F# Cockpit wired to SharedKMS
- [ ] Graphiti → KMS sync operational
- [ ] AI auto-classification working
- [ ] Zero compilation errors/warnings

---

## L4.0 TACTICAL LAYER (6 Domain Agents)

### 4.1.0.0.0 - L4-KMS-CORE: Core Infrastructure [COMPLETED]
**Status**: completed | **Priority**: P0 | **Agent**: L4-KMS-CORE
**THINKING**: Foundation databases and APIs
**DONE**: SQLite schema, DuckDB analytics, Vector search, Elixir API, F# SharedKMS

**Deliverables**:
- ✅ `lib/indrajaal/kms/kms.ex` - Main API
- ✅ `lib/indrajaal/kms/sqlite.ex` - SQLite OLTP
- ✅ `lib/indrajaal/kms/analytics.ex` - DuckDB OLAP
- ✅ `lib/indrajaal/kms/vectors.ex` - Vector similarity
- ✅ `lib/cepaf/src/Cepaf.Knowledge/SharedKMS.fs` - F# access

---

### 4.2.0.0.0 - L4-KMS-DOMAIN: Domain Modules [COMPLETED]
**Status**: completed | **Priority**: P1 | **Agent**: L4-KMS-DOMAIN
**THINKING**: Domain-specific knowledge modules
**DONE**: Developer, Product, SRE modules with 27 tables

**Deliverables**:
- ✅ `lib/indrajaal/kms/developer.ex` - Code linking, ADRs, patterns
- ✅ `lib/indrajaal/kms/product.ex` - Features, releases, KPIs
- ✅ `lib/indrajaal/kms/sre.ex` - Runbooks, SLOs, chaos engineering

---

### 4.3.0.0.0 - L4-KMS-PHOENIX: Phoenix Integration [PENDING]
**Status**: pending | **Priority**: P1 | **Agent**: L4-KMS-PHOENIX
**THINKING**: REST API and LiveView for web access
**DOING**: Creating controllers and LiveView components

**Dependencies**: L4-KMS-CORE (completed)
**Blocks**: L4-KMS-FSHARP (needs API endpoints)

---

### 4.4.0.0.0 - L4-KMS-FSHARP: F# Cockpit Integration [PENDING]
**Status**: pending | **Priority**: P1 | **Agent**: L4-KMS-FSHARP
**THINKING**: Wire Material3 components to SharedKMS
**DOING**: TreeView, DataBrowser, SmartMetric integration

**Dependencies**: L4-KMS-CORE (completed), L4-KMS-PHOENIX (partial)
**Blocks**: None (can work in parallel)

---

### 4.5.0.0.0 - L4-KMS-GRAPHITI: Knowledge Graph Integration [PENDING]
**Status**: pending | **Priority**: P1 | **Agent**: L4-KMS-GRAPHITI
**THINKING**: Sync Graphiti knowledge graph to KMS holons
**DOING**: Bidirectional sync, event propagation

**Dependencies**: L4-KMS-CORE (completed)
**Blocks**: L4-KMS-AI (needs graph data)

---

### 4.6.0.0.0 - L4-KMS-AI: AI Integration [PENDING]
**Status**: pending | **Priority**: P2 | **Agent**: L4-KMS-AI
**THINKING**: Auto-classification, recommendations, gardening
**DOING**: OpenRouter integration, embedding generation

**Dependencies**: L4-KMS-CORE (completed), L4-KMS-GRAPHITI (partial)
**Blocks**: None (final layer)

---

## L3.0 OPERATIONAL LAYER (Tasks per Agent)

### L4-KMS-PHOENIX Tasks (4.3.x.0.0)

#### 4.3.1.0.0 - Create KMS REST Controller
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.0.0.0
**THINKING**: RESTful API for CRUD operations
**DOING**: Writing `lib/indrajaal_web/controllers/api/kms_controller.ex`

**Endpoints**:
- `GET /api/kms/holons` - List holons
- `GET /api/kms/holons/:id` - Get holon
- `POST /api/kms/holons` - Create holon
- `PUT /api/kms/holons/:id` - Update holon
- `DELETE /api/kms/holons/:id` - Delete holon
- `GET /api/kms/search` - Full-text search
- `GET /api/kms/health` - Health report
- `GET /api/kms/entropy` - Entropy report

#### 4.3.2.0.0 - Create KMS LiveView Dashboard
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.0.0.0
**THINKING**: Real-time knowledge browser at `/prajna/knowledge`
**DOING**: Writing `lib/indrajaal_web/live/prajna/knowledge_live.ex`

**Components**:
- Holon tree browser (hierarchical)
- Holon detail panel
- Search interface (FTS5)
- Health dashboard (vital signs)
- Event timeline

#### 4.3.3.0.0 - Create Domain-Specific Views
**Status**: pending | **Priority**: P2 | **Parent**: 4.3.0.0.0
**THINKING**: Specialized views for Developer/Product/SRE domains
**DOING**: Domain-specific LiveView components

**Views**:
- `/prajna/knowledge/developer` - Code links, ADRs, patterns
- `/prajna/knowledge/product` - Features, releases, feedback
- `/prajna/knowledge/sre` - Runbooks, SLOs, incidents

#### 4.3.4.0.0 - Add Router Routes
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.0.0.0
**THINKING**: Wire routes in router.ex
**DOING**: Adding API and LiveView routes

---

### L4-KMS-FSHARP Tasks (4.4.x.0.0)

#### 4.4.1.0.0 - Wire TreeView to SharedKMS
**Status**: pending | **Priority**: P1 | **Parent**: 4.4.0.0.0
**THINKING**: Hierarchical holon browser in F# cockpit
**DOING**: Calling `SharedKMS.getChildren()` for tree expansion

#### 4.4.2.0.0 - Wire DataBrowser to SharedKMS
**Status**: pending | **Priority**: P1 | **Parent**: 4.4.0.0.0
**THINKING**: Tabular holon view with sorting/filtering
**DOING**: Calling `SharedKMS.listHolons()` with pagination

#### 4.4.3.0.0 - Wire SmartMetric to SharedKMS
**Status**: pending | **Priority**: P1 | **Parent**: 4.4.0.0.0
**THINKING**: Health dashboard with sparklines
**DOING**: Calling `SharedKMS.getHealthReport()` for metrics

#### 4.4.4.0.0 - Wire Prajna Bio-Holon View
**Status**: pending | **Priority**: P2 | **Parent**: 4.4.0.0.0
**THINKING**: Bio-inspired holon visualization
**DOING**: Displaying vital signs, lifecycle state

#### 4.4.5.0.0 - Add KMS ViewMode to Cockpit
**Status**: pending | **Priority**: P1 | **Parent**: 4.4.0.0.0
**THINKING**: Add Knowledge view mode to PRAJNA cockpit
**DOING**: Extending ViewMode enum, adding navigation

---

### L4-KMS-GRAPHITI Tasks (4.5.x.0.0)

#### 4.5.1.0.0 - Create Graphiti → KMS Sync
**Status**: pending | **Priority**: P1 | **Parent**: 4.5.0.0.0
**THINKING**: Import Graphiti nodes as KMS holons
**DOING**: Writing sync adapter

#### 4.5.2.0.0 - Create KMS → Graphiti Sync
**Status**: pending | **Priority**: P2 | **Parent**: 4.5.0.0.0
**THINKING**: Export KMS holons to Graphiti for graph analysis
**DOING**: Writing export adapter

#### 4.5.3.0.0 - Runtime Holon Sync
**Status**: pending | **Priority**: P2 | **Parent**: 4.5.0.0.0
**THINKING**: Sync live agent holons to KMS
**DOING**: Capturing agent state changes as holon events

#### 4.5.4.0.0 - Event Propagation
**Status**: pending | **Priority**: P2 | **Parent**: 4.5.0.0.0
**THINKING**: Propagate KMS events to interested parties
**DOING**: Phoenix.PubSub integration

---

### L4-KMS-AI Tasks (4.6.x.0.0)

#### 4.6.1.0.0 - Auto-Classification on Create
**Status**: pending | **Priority**: P2 | **Parent**: 4.6.0.0.0
**THINKING**: Classify new holons using AI
**DOING**: OpenRouter integration for classification

#### 4.6.2.0.0 - Auto-Embedding Generation
**Status**: pending | **Priority**: P2 | **Parent**: 4.6.0.0.0
**THINKING**: Generate embeddings for semantic search
**DOING**: Voyage-3 embeddings via OpenRouter

#### 4.6.3.0.0 - AI Gardener Automation
**Status**: pending | **Priority**: P3 | **Parent**: 4.6.0.0.0
**THINKING**: Auto-detect stale/unhealthy holons
**DOING**: Scheduled entropy calculation and alerting

#### 4.6.4.0.0 - AI Recommendations
**Status**: pending | **Priority**: P3 | **Parent**: 4.6.0.0.0
**THINKING**: Suggest related knowledge
**DOING**: Vector similarity + LLM recommendations

#### 4.6.5.0.0 - Oracle Consultation Interface
**Status**: pending | **Priority**: P3 | **Parent**: 4.6.0.0.0
**THINKING**: Natural language knowledge queries
**DOING**: RAG pipeline with KMS context

---

## L2.0 IMPLEMENTATION LAYER (Subtasks)

### L4-KMS-PHOENIX L2 Tasks (4.3.1.x.0)

#### 4.3.1.1.0 - Define KMS Controller Module
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.1.0.0
**File**: `lib/indrajaal_web/controllers/api/kms_controller.ex`

#### 4.3.1.2.0 - Implement Index Action (List Holons)
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.1.0.0
**Action**: `GET /api/kms/holons`

#### 4.3.1.3.0 - Implement Show Action (Get Holon)
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.1.0.0
**Action**: `GET /api/kms/holons/:id`

#### 4.3.1.4.0 - Implement Create Action
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.1.0.0
**Action**: `POST /api/kms/holons`

#### 4.3.1.5.0 - Implement Update Action
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.1.0.0
**Action**: `PUT /api/kms/holons/:id`

#### 4.3.1.6.0 - Implement Delete Action
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.1.0.0
**Action**: `DELETE /api/kms/holons/:id`

#### 4.3.1.7.0 - Implement Search Action
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.1.0.0
**Action**: `GET /api/kms/search?q=`

#### 4.3.1.8.0 - Implement Health Report Action
**Status**: pending | **Priority**: P2 | **Parent**: 4.3.1.0.0
**Action**: `GET /api/kms/health`

#### 4.3.1.9.0 - Implement Entropy Report Action
**Status**: pending | **Priority**: P2 | **Parent**: 4.3.1.0.0
**Action**: `GET /api/kms/entropy`

---

### L4-KMS-PHOENIX L2 Tasks (4.3.2.x.0)

#### 4.3.2.1.0 - Create KnowledgeLive Module
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.2.0.0
**File**: `lib/indrajaal_web/live/prajna/knowledge_live.ex`

#### 4.3.2.2.0 - Create TreeBrowser Component
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.2.0.0
**Component**: Hierarchical holon tree with expand/collapse

#### 4.3.2.3.0 - Create DetailPanel Component
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.2.0.0
**Component**: Holon detail view with vital signs

#### 4.3.2.4.0 - Create SearchBox Component
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.2.0.0
**Component**: FTS5 search with results

#### 4.3.2.5.0 - Create HealthDashboard Component
**Status**: pending | **Priority**: P2 | **Parent**: 4.3.2.0.0
**Component**: Metrics grid with sparklines

#### 4.3.2.6.0 - Create EventTimeline Component
**Status**: pending | **Priority**: P2 | **Parent**: 4.3.2.0.0
**Component**: Recent events feed

---

### L4-KMS-FSHARP L2 Tasks (4.4.1.x.0)

#### 4.4.1.1.0 - Add KMS Data Source to TreeView
**Status**: pending | **Priority**: P1 | **Parent**: 4.4.1.0.0
**File**: `lib/cepaf/src/Cepaf/Cockpit/Material3.fs`

#### 4.4.1.2.0 - Implement Tree Node Loading
**Status**: pending | **Priority**: P1 | **Parent**: 4.4.1.0.0
**Function**: `loadKmsTreeNode : holonId -> TreeNode list`

#### 4.4.1.3.0 - Implement Node Expansion
**Status**: pending | **Priority**: P1 | **Parent**: 4.4.1.0.0
**Function**: Lazy load children on expand

#### 4.4.1.4.0 - Add Icon by Holon Type
**Status**: pending | **Priority**: P2 | **Parent**: 4.4.1.0.0
**Mapping**: knowledge=📚, process=⚙️, agent=🤖, artifact=📄, index=🔍

---

### L4-KMS-AI L2 Tasks (4.6.1.x.0)

#### 4.6.1.1.0 - Create Classifier Module
**Status**: pending | **Priority**: P2 | **Parent**: 4.6.1.0.0
**File**: `lib/indrajaal/kms/ai/classifier.ex`

#### 4.6.1.2.0 - Integrate OpenRouter Client
**Status**: pending | **Priority**: P2 | **Parent**: 4.6.1.0.0
**Function**: Call Claude Haiku for fast classification

#### 4.6.1.3.0 - Add Classification Hook on Create
**Status**: pending | **Priority**: P2 | **Parent**: 4.6.1.0.0
**Hook**: Auto-classify after `KMS.create_holon/1`

---

## L1.0 ATOMIC LAYER (Actions)

### L4-KMS-PHOENIX L1 Tasks (4.3.1.1.x)

#### 4.3.1.1.1 - Add `use IndrajaalWeb, :controller`
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.1.1.0

#### 4.3.1.1.2 - Add `alias Indrajaal.KMS`
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.1.1.0

#### 4.3.1.1.3 - Add `action_fallback IndrajaalWeb.FallbackController`
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.1.1.0

---

### L4-KMS-PHOENIX L1 Tasks (4.3.1.2.x)

#### 4.3.1.2.1 - Parse query params (type, limit, offset)
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.1.2.0

#### 4.3.1.2.2 - Call `KMS.list_holons/1`
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.1.2.0

#### 4.3.1.2.3 - Render JSON response
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.1.2.0

---

### L4-KMS-PHOENIX L1 Tasks (4.3.2.1.x)

#### 4.3.2.1.1 - Add `use IndrajaalWeb, :live_view`
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.2.1.0

#### 4.3.2.1.2 - Implement `mount/3` callback
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.2.1.0

#### 4.3.2.1.3 - Implement `handle_params/3` for navigation
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.2.1.0

#### 4.3.2.1.4 - Implement `render/1` with components
**Status**: pending | **Priority**: P1 | **Parent**: 4.3.2.1.0

---

### L4-KMS-FSHARP L1 Tasks (4.4.1.1.x)

#### 4.4.1.1.1 - Import SharedKMS module
**Status**: pending | **Priority**: P1 | **Parent**: 4.4.1.1.0

#### 4.4.1.1.2 - Add KMS node type to TreeNode union
**Status**: pending | **Priority**: P1 | **Parent**: 4.4.1.1.0

#### 4.4.1.1.3 - Wire render function to KMS data
**Status**: pending | **Priority**: P1 | **Parent**: 4.4.1.1.0

---

## DEPENDENCY GRAPH

```
L5-SUPERVISOR
     │
     ├──▶ L4-KMS-CORE ✅ ─────────────────────────────────────────────┐
     │         │                                                       │
     │         └─── sqlite.ex ✅ ─── analytics.ex ✅ ─── vectors.ex ✅│
     │                                                                 │
     ├──▶ L4-KMS-DOMAIN ✅ ────────────────────────────────────────────┤
     │         │                                                       │
     │         └─── developer.ex ✅ ─── product.ex ✅ ─── sre.ex ✅   │
     │                                                                 │
     ├──▶ L4-KMS-PHOENIX ◀─────────────────────────────────────────────┤
     │         │                                                       │
     │         ├─── 4.3.1 Controller ─── 4.3.2 LiveView               │
     │         └─── 4.3.3 Domain Views ─── 4.3.4 Router               │
     │                                                                 │
     ├──▶ L4-KMS-FSHARP ◀──────────────────────────────────────────────┤
     │         │                                                       │
     │         ├─── 4.4.1 TreeView ─── 4.4.2 DataBrowser              │
     │         └─── 4.4.3 SmartMetric ─── 4.4.4 Bio-Holon             │
     │                                                                 │
     ├──▶ L4-KMS-GRAPHITI ◀────────────────────────────────────────────┤
     │         │                                                       │
     │         ├─── 4.5.1 Graph→KMS ─── 4.5.2 KMS→Graph               │
     │         └─── 4.5.3 Runtime Sync ─── 4.5.4 Events               │
     │                                                                 │
     └──▶ L4-KMS-AI ◀──────────────────────────────────────────────────┘
               │
               ├─── 4.6.1 Classification ─── 4.6.2 Embeddings
               └─── 4.6.3 Gardener ─── 4.6.4 Recommendations
```

---

## TASK STATISTICS

| Level | Total | Completed | Pending | Blocked |
|-------|-------|-----------|---------|---------|
| L5 | 1 | 0 | 1 | 0 |
| L4 | 6 | 2 | 4 | 0 |
| L3 | 19 | 0 | 19 | 0 |
| L2 | 28 | 0 | 28 | 0 |
| L1 | 16 | 0 | 16 | 0 |
| **Total** | **70** | **2** | **68** | **0** |

---

## PRIORITY MATRIX

| Priority | Tasks | Description |
|----------|-------|-------------|
| **P0** | 1 | Fix compilation errors (blocking) |
| **P1** | 25 | Core Phoenix/F# integration |
| **P2** | 28 | Domain views, Graphiti sync, AI classification |
| **P3** | 14 | Advanced AI features |

---

## EXECUTION ORDER

### Week 1: Phoenix Integration
1. 4.3.1.0.0 - KMS REST Controller
2. 4.3.2.0.0 - KMS LiveView Dashboard
3. 4.3.4.0.0 - Router Routes

### Week 2: F# Integration
4. 4.4.1.0.0 - Wire TreeView
5. 4.4.2.0.0 - Wire DataBrowser
6. 4.4.3.0.0 - Wire SmartMetric
7. 4.4.5.0.0 - Add KMS ViewMode

### Week 3: Graphiti Integration
8. 4.5.1.0.0 - Graphiti → KMS Sync
9. 4.5.2.0.0 - KMS → Graphiti Sync
10. 4.5.3.0.0 - Runtime Holon Sync

### Week 4: AI Integration
11. 4.6.1.0.0 - Auto-Classification
12. 4.6.2.0.0 - Auto-Embedding
13. 4.6.3.0.0 - AI Gardener

### Week 5: Polish & Testing
14. 4.3.3.0.0 - Domain-Specific Views
15. 4.4.4.0.0 - Bio-Holon View
16. 4.6.4.0.0 - AI Recommendations
17. 4.6.5.0.0 - Oracle Consultation

---

## QUICK COMMANDS

```bash
# Check KMS status
mix todo.status --filter "KMS"

# Run KMS tests
MIX_ENV=test mix test test/indrajaal/kms/

# Start with KMS enabled
mix phx.server

# Access KMS LiveView
open http://localhost:4000/prajna/knowledge

# Access KMS API
curl http://localhost:4000/api/kms/holons
```

---

**Document End**

*Generated: 2025-12-30T17:00:00+01:00*
*Framework: SOPv5.11 + STAMP + TDG + 5-Level Hierarchy*
*Tasks: 70 total, 68 pending, 2 completed*
