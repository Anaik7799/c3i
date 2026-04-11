---
paths:
- lib/cepaf/src/Cepaf.Planning/**/*.fs
- lib/cepaf/src/Cepaf.Planning.CLI/**/*.fs
- data/smriti/planning.db
- data/chaya/chaya.db
- PROJECT_TODOLIST.md
---
# Planning ↔ Chaya Digital Twin Synchronization Rules (SC-SYNC-PLAN)
# SUPREME SYNC MANDATE
**Planning.db (SQLite) is the SOLE AUTHORITATIVE SOURCE of task state.**
**Chaya.db is a DOWNSTREAM REPLICA. PROJECT_TODOLIST.md is a READ-ONLY ARTIFACT.**
**Data flows ONE direction: Planning.db → Chaya.db. NEVER the reverse.**
# Constitutional Alignment
This rule derives from and enforces:
- **Ψ₂ (Evolutionary Continuity)**: Complete task history preserved in authoritative store
- **Ψ₃ (Verification Capability)**: All sync operations verifiable and auditable
- **Ω₇ (Holon State Sovereignty)**: SQLite is authoritative; markdown is ephemeral artifact
- **SC-HOLON-009**: SQLite/DuckDB is the ONLY authoritative source of holon state
---
# 1.0 Data Flow Architecture (IMMUTABLE)
```
┌─────────────────────────────────────┐
│  Planning.db (SQLite)                │
│  data/smriti/planning.db             │
│                                     │
│  ★ SOLE AUTHORITATIVE SOURCE ★       │
│  Status: Pending|InProgress|         │
│          Completed|Blocked           │
└──────────┬──────────┬───────────────┘
│          │
[GENERATE]│          │[REPLICATE]
│          │
┌────────────────▼──┐   ┌───▼──────────────────┐
│ PROJECT_TODOLIST.md│   │ Chaya.db (SQLite)    │
│ (READ-ONLY ARTIFACT)│   │ data/chaya/chaya.db  │
│                    │   │                      │
│ ⚠️ NEVER import    │   │ Status: todo|        │
│   FROM this file   │   │   in_progress|done|  │
│   to overwrite     │   │   blocked            │
│   Planning.db      │   │                      │
└────────────────────┘   │ ★ DOWNSTREAM ONLY ★  │
└──────────────────────┘
```
# 1.1 Permitted Data Flows
| Flow | Direction | Trigger | Method |
|------|-----------|---------|--------|
| Planning → Markdown | Forward | `sa-plan add/update` | `Manager.updateBackup()` |
| Planning → Chaya | Forward | `sa-plan add/update` | Direct DB-to-DB sync |
| Markdown → Planning | **ONLY on cold start** | `Manager.initialize()` | Import if DB empty |
| Chaya → Planning | **FORBIDDEN** | — | — |
| Markdown → Chaya | **FORBIDDEN** | — | — |
# 1.2 Forbidden Data Flows (CRITICAL)
| Flow | Why Forbidden | Failure Mode |
|------|---------------|--------------|
| Markdown → Planning (when DB has data) | Stale markdown overwrites authoritative state | Tasks revert to old status |
| Markdown → Chaya | Regex parser loses tasks (105/114), wrong statuses | State corruption |
| Chaya → Planning | Downstream replica overwriting authoritative source | Split-brain |
---
# 2.0 STAMP Constraints (SC-SYNC-PLAN-001 to SC-SYNC-PLAN-020)
# 2.1 Authoritative Source Constraints
| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-SYNC-PLAN-001 | Planning.db is SOLE authoritative task state | CRITICAL | Code review |
| SC-SYNC-PLAN-002 | Chaya.db is downstream replica ONLY | CRITICAL | Code review |
| SC-SYNC-PLAN-003 | PROJECT_TODOLIST.md is generated artifact ONLY | CRITICAL | File header marker |
| SC-SYNC-PLAN-004 | Markdown import ONLY when Planning.db is empty (cold start) | CRITICAL | Guard check in code |
| SC-SYNC-PLAN-005 | `chaya-sync` MUST sync FROM Planning.db, NOT from markdown | CRITICAL | Code path audit |
# 2.2 Sync Integrity Constraints
| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-SYNC-PLAN-006 | Task count MUST match after sync: `|Planning| == |Chaya|` | CRITICAL | Post-sync assertion |
| SC-SYNC-PLAN-007 | Task status MUST match after sync (with enum mapping) | CRITICAL | Post-sync assertion |
| SC-SYNC-PLAN-008 | Status enum mapping MUST be bijective (no information loss) | HIGH | Unit test |
| SC-SYNC-PLAN-009 | Sync MUST be idempotent: `sync(sync(state)) == sync(state)` | HIGH | Property test |
| SC-SYNC-PLAN-010 | Sync MUST complete within 5 seconds for 1000 tasks | HIGH | Performance test |
# 2.3 Operational Constraints
| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-SYNC-PLAN-011 | Every `sa-plan add/update` MUST trigger Chaya sync | HIGH | Code path audit |
| SC-SYNC-PLAN-012 | Every `sa-plan add/update` MUST regenerate markdown | HIGH | Code path audit |
| SC-SYNC-PLAN-013 | Chaya-local tasks (added via `chaya add`) are Chaya-only | MEDIUM | Documentation |
| SC-SYNC-PLAN-014 | Sync failures MUST NOT corrupt either database | CRITICAL | Transaction safety |
| SC-SYNC-PLAN-015 | Sync MUST log operation to Zenoh telemetry | MEDIUM | Telemetry check |
# 2.4 Verification Constraints
| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-SYNC-PLAN-016 | Post-sync verification MUST run automatically | HIGH | Code path |
| SC-SYNC-PLAN-017 | Verification failure MUST be reported, not silently ignored | CRITICAL | Error handling |
| SC-SYNC-PLAN-018 | Task ID format MUST be consistent across both systems | HIGH | Schema validation |
| SC-SYNC-PLAN-019 | Timestamps MUST be UTC ISO 8601 in both systems | MEDIUM | Format check |
| SC-SYNC-PLAN-020 | Sync audit trail MUST be maintained in ChayaEventLog | HIGH | Event logging |
---
# 3.0 AOR Rules
> AOR-SYNC-PLAN-001 to AOR-SYNC-PLAN-012 — defined in CLAUDE.md §9.0
> Key: NEVER import from markdown when DB has data. ALWAYS sync from Planning.db. `sa-plan update` is primary interface.
> Recovery: Planning.db canonical on failure, regenerate Chaya from it, markdown import ONLY on cold start (empty DB).
---
# 4.0 Status Enum Mapping (BIJECTIVE)
# 4.1 Canonical Mapping Table
| Planning.db (F# DU) | Chaya.db (string) | Markdown | Display |
|----------------------|--------------------|-----------|---------|
| `Pending` | `"todo"` | `pending` | `[ ]` |
| `InProgress` | `"in_progress"` | `in_progress` | `[*]` |
| `Completed` | `"done"` | `completed` | `[x]` |
| `Blocked` | `"blocked"` | `blocked` | `[!]` |
| `Unknown s` | `"todo"` (default) | `s` | `[?]` |
# 4.2 Mapping Functions (F# Reference)
```fsharp
// Planning → Chaya (forward sync)
let planningStatusToChaya (status: TaskStatus) : string =
match status with
| Pending -> "todo"
| InProgress -> "in_progress"
| Completed -> "done"
| Blocked -> "blocked"
| Unknown _ -> "todo"
// Chaya → Planning (verification only, NOT for data flow)
let chayaStatusToPlanning (status: string) : TaskStatus =
match status with
| "todo" -> Pending
| "in_progress" -> InProgress
| "done" -> Completed
| "blocked" -> Blocked
| s -> Unknown s
```
# 4.3 Mapping Invariants
```
∀ status ∈ {Pending, InProgress, Completed, Blocked}:
chayaStatusToPlanning(planningStatusToChaya(status)) == status
∀ s ∈ {"todo", "in_progress", "done", "blocked"}:
planningStatusToChaya(chayaStatusToPlanning(s)) == s
```
---
# 5.0 FMEA Risk Analysis
# 5.1 Sync Failure Modes
| ID | Failure Mode | Cause | Effect | S | O | D | RPN | Mitigation | Constraint |
|----|--------------|-------|--------|---|---|---|-----|------------|------------|
| FMEA-SYNC-001 | Stale markdown overwrites Planning.db | `chaya-sync` imports from markdown | Tasks revert to old status; completed work lost | 9 | 7 | 3 | **189** | Guard: skip import when DB has data (SC-SYNC-PLAN-004) | SC-SYNC-PLAN-001 |
| FMEA-SYNC-002 | Regex parser drops tasks | Markdown parser matches 105/114 | 9 tasks invisible in Chaya | 7 | 8 | 4 | **224** | Sync from DB directly, not markdown (SC-SYNC-PLAN-005) | SC-SYNC-PLAN-005 |
| FMEA-SYNC-003 | Status enum mismatch | Unknown status string → default "todo" | Completed tasks shown as todo | 8 | 5 | 3 | **120** | Bijective mapping with exhaustive match (§4.0) | SC-SYNC-PLAN-008 |
| FMEA-SYNC-004 | Partial sync (crashes mid-sync) | OOM, disk full, process kill | Chaya partially updated | 7 | 3 | 5 | 105 | Transaction wrapping; verify counts post-sync | SC-SYNC-PLAN-014 |
| FMEA-SYNC-005 | Task count divergence | Different add paths (sa-plan vs chaya) | Planning ≠ Chaya counts | 6 | 6 | 4 | **144** | Post-sync count assertion (SC-SYNC-PLAN-006) | SC-SYNC-PLAN-006 |
| FMEA-SYNC-006 | Split-brain (dual writes) | Both systems modified independently | Conflicting state | 8 | 4 | 5 | **160** | Single authoritative source rule (SC-SYNC-PLAN-001) | SC-SYNC-PLAN-001 |
| FMEA-SYNC-007 | Sync not triggered on update | Code path misses Chaya sync call | Chaya becomes stale | 6 | 5 | 4 | 120 | Every sa-plan mutation triggers sync (SC-SYNC-PLAN-011) | SC-SYNC-PLAN-011 |
| FMEA-SYNC-008 | ID format collision | UUID vs hierarchical ID (46.1.0.0.0) | Wrong task updated | 8 | 2 | 3 | 48 | Consistent ID format (SC-SYNC-PLAN-018) | SC-SYNC-PLAN-018 |
| FMEA-SYNC-009 | Silent sync failure | Exception caught and swallowed | No error reported, stale state | 7 | 4 | 7 | **196** | Mandatory error reporting (SC-SYNC-PLAN-017) | SC-SYNC-PLAN-017 |
| FMEA-SYNC-010 | Planning.db corruption | Disk error, SQLite WAL issue | All task state lost | 9 | 1 | 6 | 54 | Regular backups, markdown as cold-start recovery | SC-SYNC-PLAN-015 |
# 5.2 Risk Classification
| Risk Level | RPN Range | Failure Modes | Required Action |
|------------|-----------|---------------|-----------------|
| **CRITICAL** | >200 | FMEA-SYNC-002 | Code fix MANDATORY before next release |
| **HIGH** | 100-200 | FMEA-SYNC-001,003,004,005,006,007,009 | Code fix within current sprint |
| **MEDIUM** | 50-100 | FMEA-SYNC-008,010 | Monitor and plan fix |
| **LOW** | <50 | — | Accept risk |
# 5.3 Critical RPN Summary
```
FMEA-SYNC-002: RPN 224 (CRITICAL) - Regex parser drops tasks
→ FIX: Sync Chaya directly from Planning.db, bypass markdown
FMEA-SYNC-009: RPN 196 (HIGH)     - Silent sync failure
→ FIX: Add explicit error reporting and count verification
FMEA-SYNC-001: RPN 189 (HIGH)     - Stale markdown overwrites DB
→ FIX: Guard against markdown import when DB has data
FMEA-SYNC-006: RPN 160 (HIGH)     - Split-brain dual writes
→ FIX: Enforce single authoritative source via code guards
FMEA-SYNC-005: RPN 144 (HIGH)     - Task count divergence
→ FIX: Post-sync count assertion
```
---
# 6.0 Code-Level Checks & Fixes
# 6.1 CRITICAL FIX: `ChayaCLI.syncWithProjectTodolist` (RPN 224, 189)
**File**: `lib/cepaf/src/Cepaf.Planning.CLI/ChayaCLI.fs` lines 244-286
**Current (BROKEN)**:
```fsharp
// Phase 1: Imports from markdown → overwrites Planning.db (WRONG!)
let imported = Cepaf.Planning.Repository.importFromProjectTodolist()
// Phase 2: Then syncs Planning → Chaya (too late, Planning already corrupted)
```
**Required Fix**:
```fsharp
// Phase 1: Read DIRECTLY from Planning.db (authoritative source)
let planningTasks = Cepaf.Planning.Repository.getAllTasks()
// Phase 2: Sync to Chaya.db
for task in planningTasks do
let chayaTask = convertPlanningToChaya task
ChayaRepository.saveTask config chayaTask
// Phase 3: Verify counts match
let chayaTasks = ChayaRepository.getAllTasks config
assert (planningTasks.Length = chayaTasks.Length)
// Phase 4: Regenerate markdown from Planning.db
Cepaf.Planning.Manager.updateBackup()
```
# 6.2 REQUIRED: Manager.updateStatus must sync Chaya (RPN 120)
**File**: `lib/cepaf/src/Cepaf.Planning/Manager.fs` line 91-112
**Current**: Updates Planning.db and regenerates markdown, but does NOT sync Chaya.
**Required**: After `updateBackup()`, also sync the changed task to Chaya.db.
# 6.3 REQUIRED: Manager.addTask must sync Chaya (RPN 120)
**File**: `lib/cepaf/src/Cepaf.Planning/Manager.fs` line 67-89
**Current**: Saves to Planning.db and regenerates markdown, but does NOT sync Chaya.
**Required**: After `updateBackup()`, also sync the new task to Chaya.db.
# 6.4 REQUIRED: Post-sync count verification (RPN 144)
**After any sync operation**, assert:
```fsharp
let planningCount = Repository.getAllTasks().Length
let chayaCount = ChayaRepository.getAllTasks(config).Length
if planningCount <> chayaCount then
printfn "[SYNC-ALERT] Count mismatch! Planning=%d Chaya=%d" planningCount chayaCount
// Log to Zenoh telemetry
```
# 6.5 Code Review Checklist
| Check | File | What to Verify | Constraint |
|-------|------|----------------|------------|
| CR-1 | ChayaCLI.fs:244-286 | Sync reads from Planning.db, NOT markdown | SC-SYNC-PLAN-005 |
| CR-2 | Manager.fs:91-112 | `updateStatus` syncs to Chaya after Planning | SC-SYNC-PLAN-011 |
| CR-3 | Manager.fs:67-89 | `addTask` syncs to Chaya after Planning | SC-SYNC-PLAN-011 |
| CR-4 | Manager.fs:50-65 | `initialize()` only imports markdown when DB empty | SC-SYNC-PLAN-004 |
| CR-5 | ChayaCLI.fs:244-286 | Post-sync count assertion present | SC-SYNC-PLAN-006 |
| CR-6 | ChayaCLI.fs:260-265 | Status mapping is exhaustive, no silent defaults | SC-SYNC-PLAN-008 |
| CR-7 | Manager.fs:17-20 | Markdown write is atomic (tmp + move) | SC-SYNC-PLAN-014 |
| CR-8 | All sync paths | Errors reported, not swallowed | SC-SYNC-PLAN-017 |
---
# 7.0 Verification Commands
```bash
# Verify sync state (counts must match)
sa-plan status       # Shows Planning.db totals
chaya-status         # Shows Chaya.db totals
# ⚠️ Compare: Pending+Completed counts MUST be equal
# Force re-sync from authoritative Planning.db to Chaya
# (After fixing ChayaCLI.syncWithProjectTodolist per §6.1)
chaya sync
# Verify individual task status
sa-plan list         # Planning view
chaya list           # Chaya view
# ⚠️ Status mapping: Completed↔done, Pending↔todo, InProgress↔in_progress
# Emergency: Rebuild Chaya from scratch
# 1. Delete Chaya.db
# 2. Run chaya sync (will create fresh from Planning.db)
```
---
# 8.0 Sync Protocol (Correct Implementation)
# 8.1 On `sa-plan add <title>` or `sa-plan update <id> <status>`
```
1. Validate input
2. Write to Planning.db (INSERT OR REPLACE)
3. Publish Zenoh event (TaskCreated/TaskUpdated)
4. Regenerate PROJECT_TODOLIST.md (atomic write)
5. Convert task to ChayaTask (status enum mapping §4.0)
6. Write to Chaya.db (INSERT OR REPLACE)
7. Verify: Planning.db count == Chaya.db count
8. Report success/failure
```
# 8.2 On `chaya sync` (Bulk Re-Sync)
```
1. Read ALL tasks from Planning.db (authoritative)
2. For each task:
a. Convert to ChayaTask (status enum mapping §4.0)
b. Write to Chaya.db (INSERT OR REPLACE)
3. Regenerate PROJECT_TODOLIST.md from Planning.db
4. Count verification:
a. planningCount = |Planning.db tasks|
b. chayaCount = |Chaya.db tasks|
c. ASSERT planningCount == chayaCount
5. Status verification (sample check):
a. Pick 5 random tasks
b. ASSERT Planning status maps to Chaya status
6. Report: "Synced N tasks. Counts verified."
```
# 8.3 On `chaya add <title>` (Chaya-Local)
```
1. Create task in Chaya.db only
2. This task is Chaya-local (not in Planning.db)
3. Does NOT affect Planning.db or markdown
4. Note: Task count will diverge (this is acceptable for Chaya-local tasks)
```
# 8.4 On System Cold Start (DB Empty)
```
1. Check Planning.db exists and has tasks
2. IF Planning.db is empty AND PROJECT_TODOLIST.md exists:
a. Import from markdown (cold start recovery)
b. This is the ONLY time markdown→Planning.db is permitted
3. IF Planning.db has data:
a. Skip markdown import entirely
b. Sync Planning.db → Chaya.db
c. Regenerate markdown from Planning.db
```
---
# 9.0 TDG (Test-Driven Generation) Specifications
# 9.1 Property Tests
| Property ID | Description | Generator | Constraint |
|-------------|-------------|-----------|------------|
| TDG-SYNC-001 | Status mapping roundtrip | All 4 statuses | SC-SYNC-PLAN-008 |
| TDG-SYNC-002 | Sync idempotency | Random task lists | SC-SYNC-PLAN-009 |
| TDG-SYNC-003 | Count preservation | Random task lists | SC-SYNC-PLAN-006 |
| TDG-SYNC-004 | Cold start import | Empty DB + markdown | SC-SYNC-PLAN-004 |
| TDG-SYNC-005 | Guard: no import when DB has data | Non-empty DB + stale markdown | SC-SYNC-PLAN-004 |
# 9.2 Integration Tests
| Test ID | Description | Expected |
|---------|-------------|----------|
| INT-SYNC-001 | `sa-plan add` creates task in both DBs | Count matches |
| INT-SYNC-002 | `sa-plan update` updates status in both DBs | Status matches |
| INT-SYNC-003 | `chaya sync` re-syncs all tasks from Planning | Full parity |
| INT-SYNC-004 | Stale markdown does NOT overwrite Planning.db | Planning.db unchanged |
| INT-SYNC-005 | Partial sync failure rolls back cleanly | No corruption |
---
# 10.0 Agent Operational Guidance
# 10.1 For Agents Completing Tasks
```bash
# CORRECT: Use sa-plan (syncs both systems)
sa-plan update 46.1.1.0.0 Completed
# WRONG: Only updates Chaya (Planning.db not updated)
chaya-update 46.1.1.0.0 Completed
# WRONG: Uses stale markdown import path (corrupts state)
chaya-sync
```
# 10.2 For Agents Checking Task Status
```bash
# CORRECT: Check authoritative source
sa-plan list
sa-plan status
# ACCEPTABLE: Check Chaya (may lag if sync broken)
chaya list
chaya-status
# FORBIDDEN (SC-TODO-001):
cat PROJECT_TODOLIST.md
```
# 10.3 For Agents After Bulk Operations
```bash
# After completing multiple tasks, verify sync:
sa-plan status    # Note: "Completed: N"
chaya-status      # Note: "Done: M"
# If N ≠ M, re-sync by updating tasks individually via sa-plan update
```
---
# 11.0 Monitoring & Telemetry
# 11.1 Zenoh Topics
| Topic | Event | Trigger |
|-------|-------|---------|
| `indrajaal/planning/events` | TaskCreated, TaskUpdated | `sa-plan add/update` |
| `indrajaal/planning/sync` | SyncStarted, SyncCompleted, SyncFailed | `chaya sync` |
| `indrajaal/planning/verification` | CountMatch, CountMismatch | Post-sync check |
# 11.2 Health Metrics
| Metric | Source | Alert Threshold |
|--------|--------|-----------------|
| planning_task_count | Planning.db | N/A (baseline) |
| chaya_task_count | Chaya.db | Diverges from planning_task_count |
| sync_duration_ms | Sync operation | > 5000ms |
| sync_failure_count | Error counter | > 0 |
| last_sync_timestamp | Event log | > 1 hour stale |
---
# 12.0 Related Documents
| Document | Location | Relationship |
|----------|----------|--------------|
| Todolist Access Control | `.claude/rules/todolist-access-control.md` | Access restrictions (SC-TODO-*) |
| Holon State Sovereignty | CLAUDE.md §1.0 (Ω₇) | SQLite authoritative mandate |
| F# Planning CLI | `lib/cepaf/src/Cepaf.Planning.CLI/` | Implementation |
| Chaya Digital Twin | `lib/cepaf/src/Cepaf.Planning/Chaya/` | Implementation |
| Planning Manager | `lib/cepaf/src/Cepaf.Planning/Manager.fs` | Business logic |
| Markdown Parser | `lib/cepaf/src/Cepaf.Planning/MarkdownParser.fs` | Artifact generation |
---
# 13.0 Revision History
| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-03-18 | Claude Opus 4.6 | Initial creation: 20 SC constraints, 15 AOR rules, 10 FMEA modes |