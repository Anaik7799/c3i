# Temporal Durable Execution × C3I — Replacing Cron with Workflow Orchestration
**Date**: 2026-04-18 | **Version**: v22.8.0
**Sources**: [Temporal.io](https://temporal.io), [Oban Pro](https://oban.pro), [Temporal Rust SDK](https://crates.io/crates/temporalio-sdk)

---

## 1. Scope & Trigger
Operator directive: replace simple cron scheduling with Temporal-style durable execution for autonomous OODA cycles. Evaluate Oban (Elixir) vs Temporal (Rust) for the Gleam+Rust stack.

---

## 2. Analysis: Cron vs Oban vs Temporal

### 2.1 Feature Comparison

| Feature | Cron | Oban (Elixir) | Temporal (Rust) | C3I Implementation |
|---------|------|---------------|----------------|-------------------|
| **Scheduling** | Time-based only | Time + event | Time + event + signal | Gleam OTP timer + Rust scheduler |
| **State persistence** | None | PostgreSQL | Temporal Server (Cassandra/PostgreSQL) | SQLite (Smriti.db) |
| **Retry logic** | None | Configurable | Configurable with backoff | Exponential backoff |
| **Failure recovery** | Restart from scratch | Resume from checkpoint | Resume from exact step | Resume from last checkpoint |
| **Long-running** | No | Yes (limited) | Yes (days/weeks/months) | Yes (OODA cycles continuous) |
| **Workflow DAG** | No | Pro: chain/fan-out | Native: child workflows | Native: guard_grid OODA |
| **Visibility** | Logs only | Dashboard | Full execution history | Zenoh OTel + ETS |
| **Language** | Shell | Elixir only | Rust core + polyglot | Gleam + Rust |
| **BEAM integration** | External | Native | Via Rust NIF | Native |
| **Durable execution** | No | Transactional (DB) | Event-sourced | Hybrid: ETS + SQLite |

### 2.2 Decision: Temporal-Inspired Architecture in Gleam+Rust

**Why NOT use Temporal directly**: Temporal requires a separate server (Cassandra/PostgreSQL cluster). C3I runs on a single node with SQLite. Adding Temporal Server adds operational complexity that contradicts SC-MUDA-001.

**Why NOT use Oban**: Oban requires PostgreSQL (we use SQLite) and Elixir (we use Gleam). Oban Pro is commercial.

**The C3I approach**: Implement Temporal's **concepts** (workflows, activities, durable execution) natively in Gleam+Rust using:
- **BEAM OTP actors** for workflow execution (fault-tolerant, supervised)
- **SQLite WAL** for durable state persistence (survives crashes)
- **Rust sa-plan-daemon** for activity execution (NIF bridge)
- **Zenoh** for workflow visibility (OTel spans)
- **ETS** for in-memory workflow state (fast reads)

---

## 3. Temporal Concepts → C3I Implementation

### 3.1 Workflows → Gleam OTP Actors

A Temporal Workflow is deterministic code that records side effects as events. In C3I, this maps to **OTP actors with SQLite checkpointing**:

```
Temporal Workflow:
  @workflow.run
  def ooda_cycle():
    health = await activity.execute(check_health)
    rules = await activity.execute(evaluate_rules)
    action = await activity.execute(decide_action)
    await activity.execute(execute_action, action)

C3I Equivalent (Gleam OTP Actor):
  pub fn ooda_tick(state: WorkflowState) -> WorkflowState {
    let health = activity_check_health(state)      // checkpoint
    let rules = activity_evaluate_rules(health)     // checkpoint
    let action = activity_decide_action(rules)      // checkpoint
    let result = activity_execute_action(action)    // checkpoint
    checkpoint_to_sqlite(state, result)             // durable
  }
```

### 3.2 Activities → Rust sa-plan-daemon Subcommands

A Temporal Activity is a side-effecting function with retries. In C3I, each sa-plan-daemon subcommand IS an activity:

| Temporal Activity | C3I Activity (sa-plan-daemon) | Retry Policy |
|------------------|------------------------------|-------------|
| `check_health` | `fitness --gleam-dir ...` | 3 retries, 5s backoff |
| `evaluate_rules` | Guard grid OODA tick (ETS) | No retry (pure) |
| `embed_holons` | `embed --parallel 4` | 1 retry, 60s timeout |
| `maintain_zk` | `zk-maintain` | 1 retry, 30s timeout |
| `send_alert` | `gateway --channel telegram` | 2 retries, 3s backoff |
| `save_session` | `session-save --session-id ...` | 2 retries, 1s backoff |
| `recommend_task` | `recommend` | No retry (read-only) |
| `hot_reload` | `hot-reload --port 4100` | 1 retry, 10s timeout |
| `ingest_docs` | `ingest-docs` | 1 retry, 60s timeout |

### 3.3 Workers → Rust Tokio Runtime

A Temporal Worker polls task queues and executes workflows/activities. In C3I, the **sa-plan-daemon daemon** process IS the worker:

```
Temporal Worker:
  worker = Worker(task_queue="ooda-queue")
  worker.register_workflow(OodaCycle)
  worker.register_activity(check_health)
  worker.run()

C3I Equivalent (Rust):
  // sa-plan-daemon daemon already runs continuously
  // Add workflow scheduling via tokio timers
  tokio::spawn(async {
    loop {
      let interval = Duration::from_secs(6 * 3600); // 6h
      tokio::time::sleep(interval).await;
      run_ooda_workflow().await;
    }
  });
```

### 3.4 Durable Execution → SQLite Event Log

Temporal persists every workflow event. C3I uses SQLite:

```sql
CREATE TABLE workflow_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  workflow_id TEXT NOT NULL,
  event_type TEXT NOT NULL,  -- 'started', 'activity_completed', 'checkpoint', 'failed', 'completed'
  activity_name TEXT,
  input_json TEXT,
  output_json TEXT,
  error_text TEXT,
  timestamp TEXT DEFAULT (datetime('now')),
  duration_ms INTEGER
);

CREATE TABLE workflow_schedules (
  id TEXT PRIMARY KEY,
  workflow_type TEXT NOT NULL,  -- 'ooda_6h', 'embed_daily', 'maintain_weekly'
  cron_expression TEXT,         -- '0 */6 * * *'
  last_run TEXT,
  next_run TEXT,
  enabled BOOLEAN DEFAULT 1,
  retry_policy_json TEXT
);
```

### 3.5 Signals & Queries → Zenoh PubSub

Temporal Signals trigger workflow actions externally. C3I uses Zenoh:

```
Temporal Signal:
  workflow.signal("pause_ooda")
  
C3I Equivalent:
  zenoh.put("indrajaal/workflow/signal/pause_ooda", payload)
  // Workflow actor subscribes to indrajaal/workflow/signal/**
```

---

## 4. Autonomous Workflow Definitions

### 4.1 OODA Autonomous Cycle (every 6 hours)

```
Workflow: ooda_autonomous_6h
Schedule: 0 */6 * * * (every 6 hours)
Timeout: 30 minutes
Retry: 2 attempts, 5 minute backoff

Steps:
  1. activity: fitness_check (5s timeout)
     → if score < 0.3: signal ALERT, skip remaining
  2. activity: embed_missing_holons (120s timeout)
     → embed any new holons since last run
  3. activity: zk_maintain (30s timeout)
     → detect stale holons, find duplicates
  4. activity: session_summary_report (5s timeout)
     → generate between-session event summary
  5. activity: recommend_tasks (5s timeout)
     → score pending tasks for next session
  6. checkpoint: save workflow state to SQLite
```

### 4.2 Health Monitoring (every 10 minutes)

```
Workflow: health_monitor_10m
Schedule: */10 * * * * (every 10 minutes)
Timeout: 2 minutes

Steps:
  1. activity: check_all_nif_pipelines (5s)
  2. activity: evaluate_guard_rules (1s)
  3. activity: compute_health_derivative (1s)
  4. activity: classify_failure_pattern (1s)
  5. decision: if health declining for 3 consecutive runs
     → activity: send_alert (3s)
     → activity: attempt_hot_reload (10s)
  6. checkpoint: update workflow_events
```

### 4.3 Knowledge Evolution (daily)

```
Workflow: knowledge_evolution_daily
Schedule: 0 3 * * * (3 AM daily)
Timeout: 1 hour

Steps:
  1. activity: ingest_new_documents (300s)
  2. activity: embed_all_missing (600s)
  3. activity: find_duplicates_threshold_0.95 (60s)
  4. activity: count_stale_holons_30d (5s)
  5. activity: generate_knowledge_report (5s)
  6. activity: email_report_to_operator (10s)
```

---

## 5. Implementation Plan

### 5.1 Rust: Workflow Engine (`workflow.rs`)

New file: `sub-projects/c3i/native/planning_daemon/src/workflow.rs`

```rust
//! Temporal-inspired durable workflow engine (SC-HA-001)
//! Replaces cron with stateful, checkpoint-based workflow execution.

pub struct WorkflowDefinition {
    pub id: String,
    pub workflow_type: String,
    pub schedule: String,          // cron expression
    pub timeout_secs: u64,
    pub retry_attempts: u32,
    pub retry_backoff_secs: u64,
}

pub struct WorkflowExecution {
    pub workflow_id: String,
    pub run_id: String,
    pub status: WorkflowStatus,
    pub current_step: usize,
    pub events: Vec<WorkflowEvent>,
}

pub enum WorkflowStatus {
    Running, Completed, Failed, TimedOut, Paused
}

pub struct WorkflowEvent {
    pub event_type: EventType,
    pub activity_name: String,
    pub timestamp: DateTime<Utc>,
    pub duration_ms: u64,
    pub result: Result<String, String>,
}

// Core execution loop
pub async fn run_workflow(def: &WorkflowDefinition) -> Result<(), IgnitionError> {
    ensure_schema()?;
    let run_id = Uuid::new_v4().to_string();
    record_event(&run_id, "started", "", "").await?;
    
    match def.workflow_type.as_str() {
        "ooda_6h" => run_ooda_autonomous(&run_id).await,
        "health_10m" => run_health_monitor(&run_id).await,
        "knowledge_daily" => run_knowledge_evolution(&run_id).await,
        _ => Err(IgnitionError::InternalError("Unknown workflow type".into())),
    }
}
```

### 5.2 Rust: Workflow Scheduler (`scheduler.rs`)

```rust
//! Workflow scheduler — replaces cron with durable execution scheduler

pub async fn run_scheduler() -> Result<(), IgnitionError> {
    info!("[scheduler] Starting durable workflow scheduler...");
    
    let schedules = load_schedules()?;  // from workflow_schedules table
    
    loop {
        for schedule in &schedules {
            if should_run_now(schedule) {
                tokio::spawn(async move {
                    let result = workflow::run_workflow(&schedule.definition).await;
                    if let Err(e) = result {
                        warn!("[scheduler] Workflow {} failed: {}", schedule.id, e);
                        // Retry logic with backoff
                    }
                });
                update_last_run(&schedule.id)?;
            }
        }
        tokio::time::sleep(Duration::from_secs(60)).await;  // check every minute
    }
}
```

### 5.3 Gleam: Workflow Visibility (`ha/workflow_monitor.gleam`)

```gleam
pub type WorkflowRun {
  WorkflowRun(
    workflow_id: String,
    run_id: String,
    status: String,
    current_step: Int,
    started_at: String,
    duration_ms: Int,
    events: List(WorkflowEvent),
  )
}

pub fn active_workflows() -> List(WorkflowRun)
pub fn workflow_history(workflow_id: String, limit: Int) -> List(WorkflowRun)
pub fn workflow_health() -> String  // JSON summary for dashboard
```

### 5.4 Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `planning_daemon/src/workflow.rs` | CREATE | Workflow engine core |
| `planning_daemon/src/scheduler.rs` | CREATE | Durable scheduler |
| `planning_daemon/src/main.rs` | MODIFY | +scheduler, +workflow-run subcommands |
| `cepaf_gleam/ha/workflow_monitor.gleam` | CREATE | Gleam visibility types |
| `cepaf_gleam/ui/wisp/router.gleam` | MODIFY | +/api/v1/workflows endpoint |
| `cepaf_gleam/test/workflow_monitor_test.gleam` | CREATE | Tests |

---

## 6. Oban Patterns Incorporated

From [Oban Pro](https://oban.pro):

| Oban Pattern | C3I Integration |
|-------------|----------------|
| **Chains** (sequential jobs) | Workflow steps execute in order |
| **Fan-out** (parallel jobs) | `tokio::join!` for parallel activities |
| **Unique jobs** (dedup) | workflow_id + schedule prevents duplicates |
| **Cron plugin** | scheduler.rs with cron expression parsing |
| **Lifecycle hooks** | WorkflowEvent log (started/completed/failed) |
| **Pruning** | Auto-delete events older than 30 days |
| **Node affinity** | Single-node (future: Zenoh leader election) |

---

## 7. Temporal Patterns Incorporated

From [Temporal.io](https://temporal.io):

| Temporal Pattern | C3I Integration |
|-----------------|----------------|
| **Durable execution** | SQLite event log survives crashes |
| **Activity retries** | Configurable per activity (attempts + backoff) |
| **Workflow timeouts** | Per-workflow timeout enforced |
| **Signals** | Zenoh PubSub: `indrajaal/workflow/signal/**` |
| **Queries** | `/api/v1/workflows` endpoint |
| **Child workflows** | Nested workflow calls |
| **Heartbeats** | Activity progress via ETS + Zenoh |
| **Versioning** | workflow_type + version in schedule table |
| **Visibility** | Full event history queryable |
| **Schedules** | Cron expressions in workflow_schedules table |

---

## 8. Why This Is Superior to Cron

| Dimension | Cron | Temporal-Inspired Workflows |
|-----------|------|---------------------------|
| **Failure** | Job dies, no recovery | Resume from last checkpoint |
| **State** | Stateless | Full event history in SQLite |
| **Visibility** | grep logs | /api/v1/workflows JSON + Zenoh OTel |
| **Retry** | Manual | Automatic with configurable backoff |
| **Dependencies** | None | Step-by-step with checkpoints |
| **Long-running** | Timeout kills | Heartbeat keeps alive |
| **Monitoring** | External | Integrated (guard_grid, SLO) |
| **Claude integration** | None | claude_metrics tracks workflow outcomes |

---

## 9. Evolutionary Tasks

| ID | Task | Priority |
|----|------|----------|
| WF-1 | Create workflow.rs — durable workflow engine core | P1 |
| WF-2 | Create scheduler.rs — replaces OP-5 cron with durable scheduler | P1 |
| WF-3 | Create workflow_monitor.gleam — visibility types | P1 |
| WF-4 | Add /api/v1/workflows endpoint | P2 |
| WF-5 | Define 3 initial workflows (OODA 6h, health 10m, knowledge daily) | P1 |
| WF-6 | Wire scheduler into sa-plan-daemon daemon startup | P1 |
| WF-7 | Add workflow_events + workflow_schedules SQLite tables | P1 |
| WF-8 | Zenoh signal integration for workflow control | P2 |

---

## 10. STAMP/FMEA/AOR Integration

| STAMP | Application |
|-------|------------|
| SC-HA-001 | Workflow engine provides durable execution (no lost state) |
| SC-FUNC-001 | Workflow checkpoint ensures system always recoverable |
| SC-DMS-001 | Health monitor workflow is the dead man's switch |
| SC-OODA-001 | OODA workflow formalizes the 10s/6h decision cycle |

| FMEA Mode | Mitigation via Workflow |
|-----------|----------------------|
| FM-01 NIF stale | Health 10m workflow auto-detects + alerts |
| FM-06 Embedding decay | Knowledge daily workflow auto-refreshes |
| FM-09 Orphaned modules | OODA 6h workflow runs fitness check |

---

## 11. Conclusion

Replacing cron with Temporal-inspired durable workflows gives C3I:
- **Crash recovery** — resume from exact checkpoint, not restart from scratch
- **Full visibility** — every activity logged with timing, result, errors
- **Automatic retry** — configurable per activity type
- **Claude integration** — workflow outcomes feed into session metrics
- **Zenoh signals** — external control (pause/resume/cancel) via PubSub

This is NOT adding a Temporal server dependency. It's implementing Temporal's **concepts** natively in Rust+Gleam using SQLite for durability and OTP actors for execution — the C3I way.

Sources:
- [Temporal.io — Durable Execution Platform](https://temporal.io)
- [Temporal Rust SDK](https://crates.io/crates/temporalio-sdk)
- [Oban Pro — Elixir Job Processing](https://oban.pro)
- [Temporal Rust Core at QCon SF 2025](https://www.infoq.com/news/2025/11/temporal-rust-polygot-sdk/)
- [Serban — Designing Robust Autonomous Systems](https://repository.ubn.ru.nl/bitstream/handle/2066/248590/248590.pdf)
