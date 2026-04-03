# Unified Service Orchestration and Coordination
## Cortex-Prajna-Smriti-CEPAF-Planning-Chaya Integration

**Version**: 21.3.0-SIL6 | **STAMP**: SC-ORCH-001 to SC-ORCH-015 | **AOR**: AOR-ORCH-001 to AOR-ORCH-015
**Status**: ACTIVE | **Criticality**: Level 5 (CRITICAL) - Central Nervous System

---

## 1.0 Architecture Overview

### 1.1 Service Topology

```
                    ┌─────────────────────────────────────────────┐
                    │              ORCHESTRATION LAYER            │
                    │         (Unified Service Coordination)       │
                    └───────────────────┬─────────────────────────┘
                                        │
        ┌───────────────┬───────────────┼───────────────┬─────────────────┐
        │               │               │               │                 │
   ┌────▼────┐    ┌─────▼─────┐   ┌─────▼─────┐   ┌─────▼─────┐    ┌─────▼─────┐
   │ CORTEX  │    │  PRAJNA   │   │  SMRITI   │   │   CEPAF   │    │   CHAYA   │
   │   AI    │    │   C3I     │   │ Knowledge │   │ Framework │    │  Digital  │
   │ Cognitive│    │ Cockpit   │   │  Memory   │   │           │    │   Twin    │
   └────┬────┘    └─────┬─────┘   └─────┬─────┘   └─────┬─────┘    └─────┬─────┘
        │               │               │               │                 │
        │    ┌──────────┼───────────────┼───────────────┤                 │
        │    │          │               │               │                 │
   ┌────▼────▼──────────▼───────────────▼───────────────▼─────────────────▼────┐
   │                          PLANNING SYSTEM                                    │
   │                  (F# CLI Authoritative Interface)                          │
   │                   SC-TODO-001 to SC-TODO-008 Enforced                       │
   └────────────────────────────────────────────────────────────────────────────┘
                                        │
                           ┌────────────▼────────────┐
                           │  PROJECT_TODOLIST.md   │
                           │ (Human-readable backup) │
                           │    AGENT ACCESS BLOCKED │
                           └─────────────────────────┘
```

### 1.2 Service Roles

| Service | Role | Criticality | STAMP Range |
|---------|------|-------------|-------------|
| **Cortex** | AI/Cognitive processing, LLM integration | HIGH | SC-NEURO-001 to SC-NEURO-003 |
| **Prajna** | C3I Command Cockpit, Guardian, Sentinel | CRITICAL | SC-PRAJNA-001 to SC-PRAJNA-005 |
| **Smriti** | Knowledge/Memory system, holons, history | HIGH | SC-SMRITI-001 to SC-SMRITI-050 |
| **CEPAF** | Orchestration framework, containers, mesh | CRITICAL | SC-MESH-001 to SC-MESH-010 |
| **Planning** | Task management, PROJECT_TODOLIST.md sync | HIGH | SC-PLAN-001 to SC-PLAN-015 |
| **Chaya** | Digital Twin, standalone operation, mesh | HIGH | SC-CHAYA-001 to SC-CHAYA-010 |
| **Guardian** | Safety Kernel, veto authority | INFINITE | SC-CONST-001 to SC-CONST-020 |

---

## 2.0 STAMP Safety Constraints (SC-ORCH-*)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-ORCH-001 | Task creation MUST coordinate with Prajna, Smriti, Chaya | CRITICAL | Integration Test |
| SC-ORCH-002 | Task updates MUST propagate to Smriti history | HIGH | Audit Log |
| SC-ORCH-003 | Task completion MUST record in permanent storage | HIGH | DuckDB Verify |
| SC-ORCH-004 | OODA cycle MUST complete within 100ms | HIGH | Telemetry |
| SC-ORCH-005 | Critical actions MUST get Guardian approval | CRITICAL | Gate Check |
| SC-ORCH-006 | AI assistance MUST go through Cortex | HIGH | Interface Check |
| SC-ORCH-007 | Knowledge queries MUST use Smriti | HIGH | API Verify |
| SC-ORCH-008 | Mesh distribution MUST use Chaya | HIGH | Mesh Check |
| SC-ORCH-009 | All inter-service messages MUST be logged | MEDIUM | Audit Trail |
| SC-ORCH-010 | Service health MUST be monitored continuously | HIGH | Health Check |
| SC-ORCH-011 | Message bus MUST deliver Critical messages first | HIGH | Priority Queue |
| SC-ORCH-012 | Service registration MUST be atomic | HIGH | Transaction |
| SC-ORCH-013 | Access control MUST be enforced at orchestration layer | CRITICAL | ACL Check |
| SC-ORCH-014 | Event log MUST be append-only | HIGH | Immutable Register |
| SC-ORCH-015 | Coordination MUST be idempotent | HIGH | Idempotency Key |

---

## 3.0 Agent Operating Rules (AOR-ORCH-*)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-ORCH-001 | ALWAYS coordinate task operations across services | Pre-operation hook |
| AOR-ORCH-002 | NEVER bypass Guardian for critical actions | Gate validation |
| AOR-ORCH-003 | ALWAYS record events to Smriti | Post-operation hook |
| AOR-ORCH-004 | ALWAYS distribute via Chaya for mesh operations | Mesh router |
| AOR-ORCH-005 | ALWAYS check service health before operations | Health check |
| AOR-ORCH-006 | NEVER ignore message delivery failures | Retry with backoff |
| AOR-ORCH-007 | ALWAYS use MessageBus for inter-service communication | API enforcement |
| AOR-ORCH-008 | ALWAYS validate access before operations | ACL check |
| AOR-ORCH-009 | ALWAYS log coordination events | Telemetry hook |
| AOR-ORCH-010 | NEVER hard-code service endpoints | Config injection |
| AOR-ORCH-011 | ALWAYS use priority-based message delivery | Priority queue |
| AOR-ORCH-012 | ALWAYS handle service unavailability gracefully | Circuit breaker |
| AOR-ORCH-013 | ALWAYS include correlation IDs for tracing | Distributed trace |
| AOR-ORCH-014 | NEVER expose internal service details externally | API gateway |
| AOR-ORCH-015 | ALWAYS validate message payloads | Schema validation |

---

## 4.0 Control Flow

### 4.1 Task Creation Flow

```
User/Agent Request
       │
       ▼
┌──────────────────┐
│  Access Control  │ ◄── SC-TODO-001: Block direct access
│  Validation      │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Guardian        │ ◄── SC-ORCH-005: Safety approval
│  Pre-Approval    │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Planning CLI    │ ◄── SC-PLAN-001: Authoritative interface
│  Task Creation   │
└────────┬─────────┘
         │
         ├──────────────────────┬──────────────────────┐
         │                      │                      │
         ▼                      ▼                      ▼
┌────────────────┐    ┌────────────────┐    ┌────────────────┐
│    Prajna      │    │    Smriti      │    │     Chaya      │
│   Validation   │    │   Knowledge    │    │  Digital Twin  │
│                │    │   Storage      │    │  Notification  │
└────────────────┘    └────────────────┘    └────────────────┘
         │                      │                      │
         └──────────────────────┼──────────────────────┘
                                │
                                ▼
                      ┌────────────────┐
                      │  Event Log     │
                      │ (Immutable)    │
                      └────────────────┘
```

### 4.2 OODA Cycle Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    OODA CYCLE (<100ms)                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  OBSERVE (10ms)        ORIENT (30ms)       DECIDE (20ms)   │
│  ┌─────────────┐      ┌─────────────┐     ┌─────────────┐  │
│  │ Query all   │      │ Analyze     │     │ Determine   │  │
│  │ services    │ ───▶ │ health      │ ──▶ │ actions     │  │
│  │ health      │      │ metrics     │     │ based on    │  │
│  └─────────────┘      └─────────────┘     │ thresholds  │  │
│                                           └──────┬──────┘  │
│                                                  │          │
│                              ACT (40ms)          │          │
│                        ┌─────────────────────────▼───────┐  │
│                        │ Execute decisions:              │  │
│                        │ - alert_degraded               │  │
│                        │ - scale_healthy                │  │
│                        │ - continue_normal              │  │
│                        └─────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 5.0 Data Flow

### 5.1 Message Types

| Type | Priority | Use Case |
|------|----------|----------|
| **Critical** | Highest | Guardian alerts, Emergency stops |
| **High** | High | Task mutations, State changes |
| **Normal** | Normal | Regular operations, Queries |
| **Low** | Lowest | Telemetry, Analytics |

### 5.2 Service Message Structure

```fsharp
type ServiceMessage = {
    Id: Guid                      // Unique message ID
    Source: ServiceId             // Sending service
    Target: ServiceId             // Receiving service
    Priority: MessagePriority     // Critical/High/Normal/Low
    Payload: string               // JSON-encoded data
    Timestamp: DateTime           // UTC timestamp
    RequiresAck: bool             // Acknowledgment needed
    CorrelationId: Guid option    // For request tracing
}
```

### 5.3 Coordination Events

| Event | Triggered By | Data |
|-------|--------------|------|
| TaskCreated | coordinateTaskCreation | taskId, title |
| TaskUpdated | coordinateTaskUpdate | taskId, field, newValue |
| TaskCompleted | coordinateTaskCompletion | taskId |
| ServiceRegistered | register | ServiceId |
| ServiceUnregistered | unregister | ServiceId |
| HealthCheckFailed | health monitor | ServiceId, reason |
| GuardianAlert | Guardian | level, message |
| OODACycleCompleted | coordinateOODACycle | duration |
| KnowledgeUpdated | Smriti | holonId |
| MeshTopologyChanged | Chaya | nodeCount |

---

## 6.0 Usage Scenarios

### 6.1 Human Operator

**CLI Commands:**
```bash
# Status and health
sa-orch status              # View all services health
sa-orch-status              # Same as above
sa-orch-health              # Detailed health check

# Planning tasks
sa-plan status              # View tasks
sa-plan add "Title" P1      # Add task with priority
sa-plan update ID done      # Update task status
sa-plan list pending        # Filter by status

# Chaya Digital Twin
chaya-status                # View Chaya health
chaya-ooda                  # Run OODA cycle
chaya-mesh                  # View mesh topology
```

**GUI Access:**
- Prajna Cockpit: `http://localhost:4000/prajna`
- AI Copilot: `http://localhost:4000/prajna/copilot`

### 6.2 Autonomous Agent

**CRITICAL: Direct file access is BLOCKED (SC-TODO-001)**

**Authorized Methods:**
```fsharp
// F# API access
open Cepaf.Planning.Manager
Manager.addTask None "Task title" (Some "P1")
Manager.updateStatus "task-id" "done"

// Orchestration coordination
open Cepaf.Planning.Coordination
Coordination.coordinateTaskCreation "id" "title" "P1"
Coordination.requestGuardianApproval "action" "context"
Coordination.requestCortexAssistance "query"
```

**Access Control Validation:**
```fsharp
open Cepaf.Planning.OrchestrationAccessControl
let allowed = validateAccess "agent-123" "read"
if allowed then
    // Proceed with operation
else
    // Handle rejection
```

### 6.3 Joint Human-Agent Collaboration

**Workflow:**
1. Human creates task via GUI/CLI
2. Agent receives task via Chaya notification
3. Agent processes task with Guardian oversight
4. Agent updates status via F# API
5. Human reviews completion in GUI
6. System records full lineage to Smriti

**Coordination Protocol:**
```
Human ───┬──▶ Planning CLI ───▶ Create Task
         │
Agent ◀──┴── Chaya ◀──────────── Notification
         │
         ├──▶ Cortex ──────────▶ AI Processing
         │
         ├──▶ Guardian ────────▶ Approval
         │
         └──▶ Planning CLI ───▶ Update Status
                    │
Human ◀────────────┴───────────── Review/Approve
```

---

## 7.0 CLI/GUI/TUI Commands

### 7.1 CLI Commands Reference

| Command | Description | STAMP |
|---------|-------------|-------|
| `sa-orch [cmd]` | Orchestration operations | SC-ORCH-001 |
| `sa-orch-status` | Service health and coordination | SC-ORCH-010 |
| `sa-orch-init` | Initialize all 7 services | SC-ORCH-012 |
| `sa-orch-ooda` | Run OODA cycle coordination | SC-ORCH-004 |
| `sa-orch-health` | All services health check | SC-ORCH-010 |
| `sa-plan [cmd]` | Planning CLI operations | SC-PLAN-001 |
| `chaya [cmd]` | Chaya Digital Twin operations | SC-CHAYA-001 |

### 7.2 GUI Endpoints

| Endpoint | Description |
|----------|-------------|
| `/prajna` | Main C3I Cockpit |
| `/prajna/copilot` | AI Copilot interface |
| `/prajna/guardian` | Guardian approval queue |
| `/prajna/sentinel` | Sentinel monitoring |
| `/prajna/analytics` | System analytics |

### 7.3 TUI Dashboard

```
╔══════════════════════════════════════════════════════════════════╗
║              INDRAJAAL ORCHESTRATION DASHBOARD                    ║
╠══════════════════════════════════════════════════════════════════╣
║  SERVICES                                                         ║
║  ┌────────┬──────────┬────────┬──────────────┐                   ║
║  │ Service│ Status   │ Health │ Last HB      │                   ║
║  ├────────┼──────────┼────────┼──────────────┤                   ║
║  │ Cortex │ Online   │  100%  │ 2s ago       │                   ║
║  │ Prajna │ Online   │  100%  │ 1s ago       │                   ║
║  │ Smriti │ Online   │  100%  │ 3s ago       │                   ║
║  │ CEPAF  │ Online   │  100%  │ 2s ago       │                   ║
║  │ Planning│ Online  │  100%  │ 1s ago       │                   ║
║  │ Chaya  │ Online   │  100%  │ 2s ago       │                   ║
║  │ Guardian│ Online  │  100%  │ 1s ago       │                   ║
║  └────────┴──────────┴────────┴──────────────┘                   ║
║                                                                   ║
║  OODA CYCLE: 48ms (target: <100ms)  ✓                            ║
║  MESSAGE BUS: 0 pending | 1247 delivered                          ║
║  EVENTS: 89 logged today                                          ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## 8.0 UI/UX/CX/DX Aspects

### 8.1 User Interface (UI)

**Design Principles:**
- Fractal information density
- Real-time status updates (30s refresh)
- Color-coded health indicators
- Expandable/collapsible sections

**Visual Feedback:**
| Status | Color | Icon |
|--------|-------|------|
| Online | Green | ● |
| Degraded | Yellow | ◐ |
| Offline | Red | ○ |
| Starting | Blue | ◑ |

### 8.2 User Experience (UX)

**Workflow Optimization:**
- Single-command task creation
- Auto-completion for task IDs
- Batch operations support
- Keyboard shortcuts

**Error Handling:**
- Clear error messages
- Suggested remediation
- Automatic retry with backoff
- Graceful degradation

### 8.3 Customer Experience (CX)

**Support Features:**
- Built-in help (`sa-orch help`)
- Contextual documentation
- Error code lookup
- Audit trail access

**Feedback Mechanisms:**
- Task completion notifications
- Health alert subscriptions
- Progress tracking
- SLA monitoring

### 8.4 Developer Experience (DX)

**API Design:**
- Type-safe F# interfaces
- Comprehensive documentation
- Example code snippets
- Integration test templates

**Debugging Support:**
- Distributed tracing
- Correlation IDs
- Verbose logging mode
- State inspection tools

---

## 9.0 Fractal Architecture Integration

### 9.1 Layer Mapping

| Layer | Orchestration Role |
|-------|-------------------|
| L0 Runtime | Message serialization |
| L1 Function | Service method calls |
| L2 Component | Module coordination |
| L3 Holon | Agent state management |
| L4 Container | Service deployment |
| L5 Node | Health monitoring |
| L6 Cluster | Consensus coordination |
| L7 Federation | Cross-holon messaging |

### 9.2 10x10 Interaction Matrix

```
              │ Cortex│Prajna│Smriti│ CEPAF│ Plan │ Chaya│ Guard│
──────────────┼───────┼──────┼──────┼──────┼──────┼──────┼──────┤
Cortex        │   -   │  AI  │  KG  │  INF │ TASK │ SYNC │ SAFE │
Prajna        │  AI   │   -  │  LOG │  CMD │ STAT │ TWIN │ VETO │
Smriti        │  KG   │  LOG │   -  │  CFG │ HIST │  MEM │ AUDIT│
CEPAF         │  INF  │  CMD │  CFG │   -  │ ORCH │ MESH │ CTRL │
Planning      │ TASK  │ STAT │  HIST│ ORCH │   -  │ DIST │ APPR │
Chaya         │ SYNC  │ TWIN │  MEM │ MESH │ DIST │   -  │ MON  │
Guardian      │ SAFE  │ VETO │ AUDIT│ CTRL │ APPR │  MON │   -  │
```

**Legend:**
- AI: AI Processing | KG: Knowledge Graph | INF: Infrastructure
- CMD: Commands | STAT: Status | HIST: History | CFG: Configuration
- ORCH: Orchestration | MESH: Mesh Ops | DIST: Distribution
- SAFE: Safety Check | VETO: Veto Power | AUDIT: Audit Log
- CTRL: Control | APPR: Approval | MON: Monitoring | SYNC: Sync

---

## 10.0 Related Documents

| Document | Location |
|----------|----------|
| Planning System Specification | `docs/planning/PLANNING_SYSTEM_SPECIFICATION.md` |
| Fractal Extension | `docs/planning/PLANNING_SYSTEM_FRACTAL_EXTENSION.md` |
| Access Control Rules | `.claude/rules/todolist-access-control.md` |
| BDD Test Suite | `test/features/planning/` |
| Agda Proofs | `docs/formal_specs/agda/TodolistAccessControl.agda` |
| Quint Models | `docs/formal_specs/quint/todolist_access_control.qnt` |

---

## 11.0 Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-01-16 | Claude Opus 4.5 | Initial creation |

---

*Generated: 2026-01-16*
*STAMP: SC-ORCH-001 to SC-ORCH-015*
*AOR: AOR-ORCH-001 to AOR-ORCH-015*
*Compliance: IEC 61508 SIL-6, ISO 27001*
