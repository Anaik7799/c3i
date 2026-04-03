---
description: F# Planning system — task management via Planning CLI with Zenoh sync
allowed-tools: mcp__sentinel-zenoh__zenoh_query, mcp__sentinel-zenoh__zenoh_sub, Bash(sa-plan:*), Bash(dotnet:*), Read, Grep
argument-hint: [list|add|update|status|sync] [args]
---

# Planning System (SC-PLAN-001 to SC-PLAN-003, SC-TODO-001 to SC-TODO-009)

F# Planning CLI as sole authoritative task interface. **PROJECT_TODOLIST.md is FORBIDDEN for direct access.**

## Mathematical Foundation

**Task Lattice** $\mathcal{T} = (T, \leq, \sqcup, \sqcap)$:
$$t_1 \leq t_2 \iff \text{blocks}(t_1, t_2), \quad \text{Status}: T \to \{P, I, C, B\}$$

**Sync Homomorphism** $\phi: \text{Planning.db} \to \text{Chaya.db}$:
$$\phi \text{ is idempotent}: \phi \circ \phi = \phi$$
$$\phi \text{ is monotone}: t_1 \leq t_2 \implies \phi(t_1) \leq \phi(t_2)$$

**Hierarchical Numbering** (5-level):
$$\text{TaskID} = n_1.n_2.n_3.n_4.n_5 \in \mathbb{N}^5$$

## Usage
```
/plan list                    # List all tasks
/plan list pending            # Filter by status
/plan add "Task description"  # Add new task
/plan update 42.1.0.0.0 Completed  # Update status
/plan status                  # Project status summary
/plan sync                    # Verify Planning↔Chaya sync
```

## Commands (SC-TODO-004: ALL access via F# Planning Agent)

### List Tasks
```bash
sa-plan list
sa-plan list pending
sa-plan list completed
```

### Add Task
```bash
sa-plan add "Implement circuit breaker for FFI bridge" P1
```

### Update Status
```bash
sa-plan update 42.1.0.0.0 Completed
sa-plan update 43.1.1.0.0 InProgress
```

### Project Status
```bash
sa-plan status
```

### Sync Verification (SC-SYNC-PLAN-001 to SC-SYNC-PLAN-012)
1. Query Planning.db task count via CLI
2. Subscribe to sync events: `zenoh_sub(action: "subscribe", key: "indrajaal/planning/events")`
3. Poll for sync confirmations: `zenoh_sub(action: "poll", id: "{id}")`
4. Verify counts match (SC-SYNC-PLAN-006)
5. Check Chaya downstream: `zenoh_query(action: "get", key: "indrajaal/chaya/status")`

## Data Flow (Strict Unidirectional)
```
sa-plan CLI → Planning.db (AUTHORITATIVE)
                ↓ (sync)
             Chaya.db (REPLICA)
                ↓ (generate)
             PROJECT_TODOLIST.md (READ-ONLY ARTIFACT)
```

## FORBIDDEN ($\mathbb{F}_{TODO}$)
- `Read("PROJECT_TODOLIST.md")` → SC-TODO-001 VIOLATION
- `Write("PROJECT_TODOLIST.md")` → SC-TODO-002 VIOLATION
- `Bash("cat PROJECT_TODOLIST.md")` → SC-TODO-003 VIOLATION

## STAMP Constraints
| ID | Constraint |
|----|------------|
| SC-PLAN-001 | F# Planning CLI authoritative |
| SC-PLAN-002 | PROJECT_TODOLIST.md sync via sa-plan |
| SC-PLAN-003 | SQLite persistence for tasks |
| SC-TODO-001 | Agents SHALL NOT read PROJECT_TODOLIST.md directly |
| SC-TODO-002 | Agents SHALL NOT write PROJECT_TODOLIST.md directly |
| SC-TODO-003 | Agents SHALL NOT use shell to access PROJECT_TODOLIST.md |
| SC-TODO-004 | All access MUST use F# Planning Agent via Zenoh |
| SC-TODO-005 | PROJECT_TODOLIST.md is generated artifact ONLY |
| SC-TODO-006 | Todolist state authoritative in SQLite/DuckDB |
| SC-TODO-009 | Planning Agent is SOLE entity with write access |
| SC-SYNC-PLAN-001 | NEVER import from markdown when Planning.db has data |
| SC-SYNC-PLAN-002 | ALWAYS sync Chaya FROM Planning.db directly |
| SC-SYNC-PLAN-005 | chaya-sync MUST sync FROM Planning.db NOT markdown |
| SC-SYNC-PLAN-006 | Task count MUST match post-sync |
| SC-SYNC-PLAN-009 | Sync MUST be idempotent |
| SC-SYNC-PLAN-014 | Sync failures MUST NOT corrupt either DB |
| SC-CHAYA-001 | Standalone operation mode |
| SC-CHAYA-002 | OODA cycle < 30ms |
| SC-CHAYA-004 | Sync with PROJECT_TODOLIST.md |

## Zenoh Events
| Topic | Event | Direction |
|-------|-------|-----------|
| indrajaal/planning/events | Task CRUD | Publish |
| indrajaal/planning/sync | Sync status | Publish |
| indrajaal/chaya/status | Twin state | Subscribe |
