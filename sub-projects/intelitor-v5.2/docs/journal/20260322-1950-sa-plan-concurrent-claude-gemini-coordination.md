# 20260322-1950 — sa-plan Concurrent Claude+Gemini Bug Fix Coordination

## Context
- Branch: main
- Session: Post-GitIntelligence mesh integration, SIL-6 homeostasis achieved
- Recent commits:
  - 07c7f2fe7 evolve(core): wire git intelligence to mesh telemetry
  - e72a3d1ea feat(cepaf): GitIntelligence 10-layer fractal expansion — 16 modules, 181 tests
- System state: 100% constraint parity (2,261 SC-* / 482 AOR-*), KL divergence 0.0071 bits, Grade A
- Scenario: Multiple Claude instances AND Gemini instances concurrently fixing bugs via `sa-plan`

## Summary

Documents the coordination protocol for concurrent bug-fix operations when multiple Claude Code agents and Gemini agents simultaneously use `sa-plan` to claim, update, and complete tasks. Covers the complete concurrency stack from SQLite WAL mode through PlanningEnforcer access control to Chaya Digital Twin synchronization.

**Key finding**: The system achieves safe concurrent operation WITHOUT distributed locks through three complementary mechanisms:
1. **SQLite WAL mode** — unlimited concurrent readers, serialized writers (automatic)
2. **PlanningEnforcer** — 5-layer lock-free access control using `ConcurrentDictionary`
3. **Unidirectional Chaya sync** — Planning.db is SOLE authoritative source, never reverse-flows

---

## Technical Details

### 1. The Concurrency Problem

When multiple AI agents (Claude instances + Gemini instances) concurrently fix bugs:

```
Claude-1  ──► sa-plan update a1 InProgress ──► [fix bug] ──► sa-plan update a1 Completed
Claude-2  ──► sa-plan update b2 InProgress ──► [fix bug] ──► sa-plan update b2 Completed
Gemini-1  ──► sa-plan update c3 InProgress ──► [fix bug] ──► sa-plan update c3 Completed
Gemini-2  ──► sa-plan update d4 InProgress ──► [fix bug] ──► sa-plan update d4 Completed
                    │                                              │
                    ▼                                              ▼
              data/smriti/planning.db (SQLite WAL)          PROJECT_TODOLIST.md (artifact)
```

**Potential failure modes**:
- Two agents claim the same task (double-work)
- Write contention corrupts SQLite state
- Stale reads cause conflicting task status
- Markdown artifact becomes inconsistent with SQLite
- Chaya Digital Twin diverges from authoritative state

### 2. SQLite WAL Mode Concurrency (Layer 0 — Database)

The F# Planning CLI uses SQLite with WAL (Write-Ahead Log) mode, configured in `Repository.fs`:

```fsharp
// Connection string with WAL and busy timeout
let connStr = $"Data Source={dbPath};Journal Mode=WAL;Busy Timeout=30000"
```

**WAL Mode Concurrency Guarantees**:

| Operation | Behavior | Blocking? |
|-----------|----------|-----------|
| Read + Read | Fully concurrent, lock-free | Never |
| Read + Write | Concurrent — readers see pre-write snapshot | Never |
| Write + Write | Serialized via RESERVED→EXCLUSIVE lock | Writer waits up to 30s |
| Write + Read | Writer proceeds, reader sees consistent snapshot | Never |

**How this handles Claude+Gemini**:
- Claude-1 reads task list while Gemini-2 writes: both succeed instantly
- Claude-1 writes task a1 while Gemini-1 writes task c3: second writer waits for first to commit (typically <1ms for single-row upsert), then proceeds
- No corruption possible: SQLite guarantees ACID even under concurrent access

**STAMP**: SC-UTLTS-001 (WAL mode), SC-XHOLON-030 (no data loss on crash), SC-XHOLON-031 (ACID for writes)

### 3. PlanningEnforcer — 5-Layer Lock-Free Access Control (Layer 1)

`lib/cepaf/src/Cepaf.Planning.CLI/PlanningEnforcer.fs` provides thread-safe enforcement using `ConcurrentDictionary` (lock-free hash map):

```
┌─────────────────────────────────────────────────────────────┐
│                 PlanningEnforcer (5 Layers)                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Layer 1: Agent Classification                               │
│  ├─ Identify agent type (Claude, Gemini, Human, System)     │
│  ├─ Apply type-specific access rules                         │
│  └─ Unknown agents DENIED by default (SC-ENFORCE-021)       │
│                                                              │
│  Layer 2: Rate Limiting (10 requests/second per agent)       │
│  ├─ ConcurrentDictionary<AgentId, RequestTimestamp[]>        │
│  ├─ Sliding window rate check                                │
│  └─ Prevents API hammering by aggressive agents              │
│                                                              │
│  Layer 3: Circuit Breaker (3 violations → trip)              │
│  ├─ ConcurrentDictionary<AgentId, ViolationCount>            │
│  ├─ Trips after 3 violations (SC-ENFORCE-004)                │
│  ├─ Tripped agents get ALL requests denied                   │
│  └─ Reset requires Guardian approval (SC-ENFORCE-013)        │
│                                                              │
│  Layer 4: Path Validation                                    │
│  ├─ Forbidden patterns (PROJECT_TODOLIST.md, etc.)           │
│  ├─ Case-insensitive matching (SC-ENFORCE-010)               │
│  └─ Regex support for complex patterns (SC-ENFORCE-011)      │
│                                                              │
│  Layer 5: Anomaly Detection                                  │
│  ├─ Suspicious access pattern analysis (SC-ENFORCE-023)      │
│  ├─ Agent fingerprinting for impersonation (SC-ENFORCE-017)  │
│  └─ Results logged to immutable audit trail                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Thread Safety**: All enforcement state uses `ConcurrentDictionary` which provides:
- Lock-free reads via atomic compare-and-swap
- Fine-grained locking only on hash bucket collision (rare)
- No global lock — Claude-1 and Gemini-2 enforcement checks proceed in parallel

**STAMP**: SC-ENFORCE-001 to SC-ENFORCE-025

### 4. Task Lifecycle — Concurrent Bug Fix Walkthrough

#### Scenario: Claude-1 fixes bug a1, Gemini-1 fixes bug c3 simultaneously

```
T=0s   Claude-1                              Gemini-1
       │                                      │
       ├─ sa-plan update a1 InProgress        ├─ sa-plan update c3 InProgress
       │  │                                    │  │
       │  ├─ PlanningEnforcer.validate()       │  ├─ PlanningEnforcer.validate()
       │  │  ├─ L1: Agent=Claude ✓             │  │  ├─ L1: Agent=Gemini ✓
       │  │  ├─ L2: Rate < 10/s ✓             │  │  ├─ L2: Rate < 10/s ✓
       │  │  ├─ L3: No violations ✓            │  │  ├─ L3: No violations ✓
       │  │  ├─ L4: Path OK ✓                  │  │  ├─ L4: Path OK ✓
       │  │  └─ L5: Pattern normal ✓           │  │  └─ L5: Pattern normal ✓
       │  │                                    │  │
       │  ├─ Manager.updateTask("a1", ...)     │  ├─ Manager.updateTask("c3", ...)
       │  │  │                                 │  │  │
       │  │  ├─ Repository.updateTask()        │  │  ├─ Repository.updateTask()
       │  │  │  │                              │  │  │  │
       │  │  │  └─ SQLite: INSERT OR REPLACE   │  │  │  └─ SQLite: INSERT OR REPLACE
       │  │  │     (Writer A acquires WAL)     │  │  │     (Writer B waits ~0.1ms)
       │  │  │     ← commit (~0.5ms) ──────────┤  │  │     ← acquires WAL
       │  │  │                                 │  │  │     ← commit (~0.5ms)
       │  │  │                                 │  │  │
       │  │  ├─ Zenoh: publish task_updated    │  │  ├─ Zenoh: publish task_updated
       │  │  │  topic: indrajaal/planning/     │  │  │  topic: indrajaal/planning/
       │  │  │         events                  │  │  │         events
       │  │  │                                 │  │  │
       │  │  └─ Regenerate TODOLIST.md         │  │  └─ Regenerate TODOLIST.md
       │  │     (read-only artifact)           │  │     (last-writer-wins, OK because
       │  │                                    │  │      full regen from DB each time)
       │  │                                    │  │
       │  └─ stdout: "Updated a1 → InProgress"│  └─ stdout: "Updated c3 → InProgress"
       │                                      │
T=5m   ├─ [Claude fixes bug on branch         ├─ [Gemini fixes bug on branch
       │   multiverse/claude-fix-a1]          │   multiverse/gemini-fix-c3]
       │                                      │
T=10m  ├─ sa-plan update a1 Completed         ├─ sa-plan update c3 Completed
       │  (same flow as above)                │  (same flow as above)
       │                                      │
       └─ Merge multiverse/claude-fix-a1      └─ Merge multiverse/gemini-fix-c3
          to main (after Guardian approval)       to main (after Guardian approval)
```

**Key invariants maintained**:
1. **No double-claiming**: Each `sa-plan update` is an atomic `INSERT OR REPLACE` — if Claude and Gemini both try to claim the same task, the second write overwrites the first (last-writer-wins), but since they're working different tasks (a1 vs c3), no conflict occurs
2. **Consistent reads**: WAL mode ensures readers always see a complete, consistent snapshot
3. **Artifact regeneration**: `PROJECT_TODOLIST.md` is fully regenerated from SQLite on each mutation — no incremental edits that could corrupt

### 5. Chaya Digital Twin Synchronization (Layer 2)

Chaya maintains a downstream replica for mesh-aware task distribution:

```
┌──────────────────────────────────────────────────────────┐
│              SYNC DIRECTION (UNIDIRECTIONAL)               │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  data/smriti/planning.db (SQLite)                        │
│  ╔══════════════════════════════╗                        │
│  ║  AUTHORITATIVE SOURCE       ║                        │
│  ║  (SC-SYNC-PLAN-001)         ║                        │
│  ╚══════════╤═══════════════════╝                        │
│             │                                             │
│             │  Phase 1: Read all tasks from Planning.db   │
│             │  Phase 2: Map status enum (bijective)       │
│             │  Phase 3: Upsert to Chaya.db                │
│             │  Phase 4: Verify count match                │
│             │  Phase 5: Post-sync audit log               │
│             ▼                                             │
│  data/smriti/chaya.db (SQLite)                           │
│  ┌──────────────────────────────┐                        │
│  │  DOWNSTREAM REPLICA ONLY    │                        │
│  │  (SC-SYNC-PLAN-002)         │                        │
│  │                              │                        │
│  │  ⚠️ NEVER flows back to     │                        │
│  │    Planning.db               │                        │
│  │  (SC-SYNC-PLAN-004)         │                        │
│  └──────────────────────────────┘                        │
│                                                           │
│  PROJECT_TODOLIST.md                                      │
│  ┌──────────────────────────────┐                        │
│  │  GENERATED ARTIFACT ONLY    │                        │
│  │  (SC-SYNC-PLAN-003)         │                        │
│  │                              │                        │
│  │  ⚠️ FORBIDDEN for direct    │                        │
│  │    agent access              │                        │
│  │  (SC-TODO-001 to SC-TODO-009)│                        │
│  └──────────────────────────────┘                        │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

**Sync Trigger**: Every `sa-plan` mutation automatically triggers Chaya sync (SC-SYNC-PLAN-011).

**Concurrent sync safety**: If Claude-1 and Gemini-1 both trigger sync within the same second:
- Sync reads from Planning.db (WAL — concurrent reads OK)
- Sync writes to Chaya.db (also WAL — writes serialized automatically)
- Post-sync verification catches any count mismatch (SC-SYNC-PLAN-006)
- Sync is idempotent (SC-SYNC-PLAN-009) — running twice produces same result

### 6. Multiverse Branch Isolation for Code Changes

While `sa-plan` handles task state, the actual code changes happen on isolated branches:

```
main ──────────────────────────────────────────── main (updated)
  │                                                  ▲
  ├── multiverse/claude-1-fix-a1 ────────────────────┤ (merge after SIL-6 verify)
  │                                                  │
  ├── multiverse/claude-2-fix-b2 ────────────────────┤ (merge after SIL-6 verify)
  │                                                  │
  ├── multiverse/gemini-1-fix-c3 ────────────────────┤ (merge after SIL-6 verify)
  │                                                  │
  └── multiverse/gemini-2-fix-d4 ────────────────────┘ (merge after SIL-6 verify)
```

**Protocol per agent**:
1. Create `multiverse/{agent}-{scope}` branch from `main`
2. Make code changes on isolated branch
3. Run SIL-6 multi-channel verification (compile, test, quality, STAMP)
4. `sa-plan update {task_id} Completed` — updates Planning.db
5. Guardian approval required for merge to `main` (SC-GIT-006)
6. Fast-forward merge if no conflicts; rebase + re-verify if conflicts

**Conflict resolution**:
- If Claude-1 and Gemini-1 modify the same file, merge conflict detected at step 6
- Second agent to merge must: rebase from `main` → re-verify → attempt merge again
- Guardian has veto authority on any merge (AOR-CONST-003)

### 7. SafetyKernel Integration (Layer 3)

The F# SafetyKernel (`lib/cepaf/src/Cepaf.Planning.CLI/SafetyKernel.fs`) provides Guardian-integrated validation:

```fsharp
// Pre-execution validation for concurrent mutations
type SafetyKernel =
    static member validateMutation(agentId, taskId, newStatus) =
        // 1. Check Guardian pre-approval (SC-SAFETY-001)
        // 2. Detect conflicting active operations
        //    - If another agent is already updating this task → REJECT
        // 3. Validate state transition (e.g., Completed→InProgress forbidden)
        // 4. Record to immutable audit trail (SC-SAFETY-003)
        // 5. Check constitutional invariants (Ψ₀-Ψ₅)
```

**Active Operation Conflict Detection**:
- SafetyKernel maintains a `ConcurrentDictionary<TaskId, AgentId>` of in-flight mutations
- Before allowing an update, checks if another agent is currently modifying the same task
- If conflict detected: second agent receives `{:error, :conflict, "Task {id} being modified by {agent}"}`
- This prevents the double-claim scenario even when SQLite would allow the second write

### 8. Zenoh Event Flow for Coordination

All task mutations publish events via Zenoh dual-write (SC-ZTEST-008):

```
Agent (Claude/Gemini)
  │
  ├─► [ZTEST-CHECKPOINT] log fallback (ALWAYS first)
  │
  └─► Zenoh Publish
       topic: indrajaal/planning/events
       payload: {
         "event": "task_updated",
         "task_id": "a1",
         "agent_id": "claude-1",
         "old_status": "Pending",
         "new_status": "InProgress",
         "timestamp": "2026-03-22T19:50:00Z"
       }
       │
       ├─► Chaya Digital Twin (subscriber)
       │   └─ Updates local mesh state
       │
       ├─► Prajna Cockpit (subscriber)
       │   └─ Updates dashboard task display
       │
       └─► Other agents (subscribers)
           └─ See task claimed, skip it (coordination signal)
```

**Coordination via visibility**: When Claude-1 publishes `task_updated(a1, InProgress)`, Gemini-1 (if subscribed) sees this and knows not to claim task a1. This is a pull-model coordination — agents observe state rather than being commanded.

### 9. Failure Handling (Jidoka)

When an agent encounters a defect during concurrent bug fixing:

| Scenario | Detection | Response | STAMP |
|----------|-----------|----------|-------|
| SQLite busy timeout (30s) | `SQLITE_BUSY` error | Retry with exponential backoff (100ms→3200ms) | SC-XHOLON-030 |
| Agent crashes mid-fix | No heartbeat for 5min | Task auto-reverts to `Pending` (dead agent detection) | SC-DMS-001 |
| Merge conflict | Git conflict markers | Rebase, re-verify, re-attempt merge | SC-GIT-006 |
| Quality gate failure | compile/test/credo error | Agent halts (Jidoka), publishes failure event, task stays `InProgress` | AOR-TPS-001 |
| Rate limit exceeded | PlanningEnforcer L2 rejection | Agent backs off 30s, retries | SC-ENFORCE-018 |
| Circuit breaker tripped | 3 violations in window | ALL agent requests denied until Guardian reset | SC-ENFORCE-013 |

### 10. End-to-End Concurrent Bug Fix Protocol

**The complete protocol for N Claude + M Gemini agents fixing bugs concurrently**:

```
Phase 1: Task Discovery (No locks needed)
  ├─ Each agent: sa-plan list [pending]
  ├─ SQLite WAL: All reads concurrent, consistent snapshot
  └─ Agents select different tasks (coordination via Zenoh visibility)

Phase 2: Task Claim (Serialized writes, sub-ms)
  ├─ Each agent: sa-plan update {task_id} InProgress
  ├─ PlanningEnforcer validates (5 layers, ~1ms)
  ├─ SafetyKernel checks for active conflicts (~0.5ms)
  ├─ SQLite WAL serializes writes (automatic, ~0.5ms wait)
  ├─ Zenoh publishes claim event (agents see what's taken)
  └─ Chaya synced automatically

Phase 3: Bug Fix (Fully isolated, unlimited concurrency)
  ├─ Each agent works on multiverse/{agent}-{scope} branch
  ├─ No shared state during development
  ├─ Full SIL-6 verification runs per branch
  └─ Duration: minutes to hours (agent-dependent)

Phase 4: Completion (Serialized writes, sub-ms)
  ├─ Each agent: sa-plan update {task_id} Completed
  ├─ Same enforcement + safety pipeline as Phase 2
  ├─ Zenoh publishes completion event
  └─ Chaya synced

Phase 5: Merge (Sequential per branch, Guardian-gated)
  ├─ Agent requests merge to main
  ├─ Guardian approval required (SC-GIT-006)
  ├─ Fast-forward if no conflict
  ├─ Rebase + re-verify if conflict
  └─ Post-merge: Zenoh event, Digital Twin update
```

---

## STAMP Compliance

| ID | Constraint | Status |
|----|------------|--------|
| SC-SYNC-PLAN-001 | Planning.db is SOLE authoritative source | PASS — all mutations via sa-plan |
| SC-SYNC-PLAN-002 | Chaya.db is downstream replica ONLY | PASS — unidirectional sync |
| SC-SYNC-PLAN-004 | Chaya state NEVER flows back to Planning.db | PASS — enforced in sync protocol |
| SC-SYNC-PLAN-009 | Sync MUST be idempotent | PASS — full regen from DB |
| SC-SYNC-PLAN-011 | Every sa-plan mutation triggers Chaya sync | PASS — automatic on write |
| SC-ENFORCE-001 | Direct PROJECT_TODOLIST.md access blocked | PASS — 5-layer enforcement |
| SC-ENFORCE-004 | Circuit breaker at 3 violations | PASS — ConcurrentDictionary tracking |
| SC-ENFORCE-021 | Unknown agents denied by default | PASS — agent classification required |
| SC-TODO-001 to SC-TODO-009 | PROJECT_TODOLIST.md access control | PASS — generated artifact only |
| SC-UTLTS-001 | WAL mode for concurrent access | PASS — configured in Repository.fs |
| SC-XHOLON-030 | No data loss on crash | PASS — WAL mode with busy_timeout |
| SC-XHOLON-031 | ACID for SQLite writes | PASS — atomic INSERT OR REPLACE |
| SC-XHOLON-032 | No deadlocks | PASS — WAL single-writer serialization |
| SC-GIT-006 | Guardian approval for promote | PASS — multiverse merge gate |
| SC-SAFETY-001 | Guardian pre-approval for mutations | PASS — SafetyKernel integration |
| SC-SAFETY-003 | Complete audit trail | PASS — immutable register logging |
| SC-ZTEST-008 | Log fallback before Zenoh | PASS — dual-write pattern |

---

## Impact Analysis (4-Layer)

### L1-CODE (Score: 0)
- This is a protocol document, no code changes

### L2-DOMAIN (Score: 2)
- Documents concurrent access patterns for Planning.db
- Clarifies SafetyKernel conflict detection behavior
- Establishes coordination protocol for multi-AI-vendor scenarios

### L3-SYSTEM (Score: 1)
- Describes SQLite WAL behavior under concurrent agent load
- Documents PlanningEnforcer as coordination infrastructure
- Clarifies Zenoh event flow for task coordination

### L4-ECOSYSTEM (Score: 2)
- Establishes protocol for concurrent Claude + Gemini operations
- Defines failure handling matrix for multi-agent bug fixing
- Documents end-to-end 5-phase concurrent protocol

**Total Impact Score: 5 (LOW RISK)**

---

## FMEA Risk Analysis

| Failure Mode | S | O | D | RPN | Mitigation |
|-------------|---|---|---|-----|------------|
| Two agents claim same task | 7 | 3 | 3 | 63 | SafetyKernel conflict detection + Zenoh visibility |
| SQLite WAL write timeout | 5 | 2 | 4 | 40 | busy_timeout=30000, exponential backoff |
| Agent crashes mid-update | 6 | 3 | 5 | 90 | Dead agent detection (5min), task auto-revert |
| Chaya sync divergence | 4 | 2 | 3 | 24 | Post-sync count verification (SC-SYNC-PLAN-006) |
| Merge conflict on main | 5 | 4 | 2 | 40 | Rebase + re-verify protocol |
| Rate limit storm (N agents) | 4 | 3 | 2 | 24 | Per-agent rate limiting (10/s) |
| PlanningEnforcer bypass | 9 | 1 | 9 | 81 | Cryptographic proof required (SC-ENFORCE-015) |

---

## Key Architectural Decisions

### Why Lock-Free Over Distributed Locks?

1. **SQLite WAL provides natural serialization** — no need for external lock manager
2. **ConcurrentDictionary is O(1) amortized** — no contention scaling issues
3. **Agents are stateless clients** — each `sa-plan` invocation is independent
4. **Lock-free reads dominate** — agents read task lists far more often than they write
5. **No single point of failure** — no lock server to crash

### Why Unidirectional Chaya Sync?

1. **Single source of truth** — eliminates split-brain scenarios
2. **Simpler reasoning** — data flows one way, no circular dependencies
3. **Idempotent by design** — re-sync always produces correct state
4. **Audit-friendly** — Planning.db is the only place mutations happen

### Why Multiverse Branches?

1. **Total isolation** — agents can't step on each other's code changes
2. **Independent verification** — each branch gets full SIL-6 quality gate
3. **Guardian gate** — human-aligned merge control via constitutional veto
4. **Easy rollback** — delete branch, task reverts, no damage to main

---

## Next Steps

1. **Implement active heartbeat**: Agent heartbeat via Zenoh for faster dead-agent detection (currently 5min timeout)
2. **Task affinity**: Prefer assigning related tasks to the same agent type (Claude for Elixir, Gemini for F#)
3. **Conflict prediction**: Use git diff analysis to predict merge conflicts BEFORE agents start working
4. **Dashboard**: Prajna panel showing real-time agent activity (who claimed what, current status, ETA)
5. **Cross-agent learning**: Record fix patterns in SMRITI for future reference across Claude/Gemini instances
