# sa-plan-daemon Scheduler & Workflow Guide

> Five `sa-plan` list commands, one daemon, two engines.
> Grounded in `sub-projects/c3i/native/planning_daemon/src/{oban.rs,workflow.rs,workers.rs}`.
> ZK refs: [zk-3d6c2ca4c011d463] workflow.rs · [zk-6a372492ee5f9373] scheduler.rs · [zk-adf28ee743f25c45] WF-* tasks.

---

## 1. The big picture

`sa-plan-daemon` ships **two execution engines** that share one SQLite file (`Smriti.db`):

| Engine | Borrowed from | What it executes | When to use |
|---|---|---|---|
| **Oban-style** | Elixir's Oban | Short-lived, idempotent jobs (seconds–minutes) | Cron-driven background work, fire-and-forget tasks |
| **Temporal-style** | Temporal.io | Long-running, stateful sagas (minutes–days) | Multi-step processes that must survive restarts, accept signals, return queries |

Both are orthogonal to **planning tasks** (`sa-plan add/update/status` — your 3,077-task todo list). Planning tasks are *intent records*; jobs and workflows are *execution units*. A workflow or job *can* mutate a planning task, but the inverse is rare.

```
┌──────────────────────────────────────────────────────────────────────┐
│                        sa-plan-daemon                                 │
│                                                                       │
│  ┌─────────────────────┐         ┌──────────────────────────────┐   │
│  │   OBAN (short)      │         │   TEMPORAL (long)            │   │
│  │                     │         │                              │   │
│  │  schedule_list      │         │  workflow_executions         │   │
│  │       │             │         │       │                      │   │
│  │       │ cron fires  │         │       │ start                │   │
│  │       ▼             │         │       ▼                      │   │
│  │   job_list ──┐      │         │  workflow_list (events)      │   │
│  │              │      │         │       ▲                      │   │
│  │              │ uses │         │       │ append-only          │   │
│  │              ▼      │         │       │                      │   │
│  │   queue_list        │         │  signals · queries · timers  │   │
│  └─────────────────────┘         └──────────────────────────────┘   │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  PLANNING TASKS (separate domain — sa-plan add/update/status)│    │
│  └──────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 2. Ontology — five commands, five tables

Each command reads exactly one (or one+aggregation) table. Memorise this and the rest follows.

| Command | Table read | Layer | Lifetime | Granularity |
|---|---|---|---|---|
| `schedule-list` | `workflow_schedules` | Oban — definition | permanent | "embed_refresh runs at `0 */6 * * *`" |
| `job-list` | `oban_jobs` | Oban — instance | minutes–hours | "job 4711, queue=embed, state=executing, attempt 2/5" |
| `queue-list` | `oban_queues` (+ aggregate `oban_jobs`) | Oban — resource | permanent | "queue `embed`: concurrency=2, available=3, executing=1" |
| `workflow-executions` | `workflow_executions` | Temporal — instance | hours–days | "saga abcd-1234, state=running, started 2 h ago" |
| `workflow-list` | `workflow_events` | Temporal — history | append-only | "event #87 at 12:01: ActivityCompleted(`embed_refresh`)" |

### Oban-side state machine (`oban_jobs.state`)

```
scheduled ──► available ──► executing ──► completed
                                ├─► retryable ──► (back to available)
                                └─► discarded   (max_attempts reached)
                       cancelled  (manual via job-cancel)
```

### Temporal-side state machine (`workflow_executions.state`)

```
running ──► completed
       ├──► failed
       ├──► cancelled  (cooperative — workflow-cancel)
       └──► terminated (hard-stop — workflow-terminate)
```

---

## 3. Worker registry — what jobs can actually run

Per `workers.rs::known_workers()` (24 registered workers, 2026-04-29):

| Worker | Purpose |
|---|---|
| `health_check` | system probe |
| `gleam_script`, `gleam_run` | gleam-side automation |
| `embed_refresh` | regenerate ZK embeddings |
| `zk_maintain` | ZK dedup, stale detection |
| `ingest_docs` | crawl docs/ into Smriti FTS5 |
| `feature_autopilot` | full post-feature pipeline |
| `knowledge_search_warmup` | prime FTS5 cache |
| `link_registry_refresh` | rebuild task-id link JSON |
| `send_email` | SMTP via lettre |
| `prune_jobs` | delete terminal jobs > N days |
| `lifeline_reset` | unstick `executing` jobs > N seconds |
| `reindex_db` | SQLite REINDEX + ANALYZE |
| `sa_plan_sync` | regenerate PROJECT_TODOLIST.md |
| `ooda_recommend` | recompute task priorities |
| `echo` | smoke test |
| `rust_build`, `gleam_build`, `pi_build`, `cargo_test`, `build_all_parallel` | build pipeline |

A worker name in `oban_jobs.worker` that is **not** in this list will fail with `unknown worker` (per SC-DISP-REGISTRY-002).

---

## 4. The five commands — when, why, how

### 4.1 `schedule-list` — cron definitions

```bash
./sa-plan schedule-list
```

**Use when**: "What's supposed to run automatically? When does the next embed-refresh fire?"

Auto-seeds defaults if the table is empty (per WF-5 in [zk-adf28ee743f25c45]). Companion commands:
- `schedule-add` — register a new cron
- `schedule-pause` / `schedule-trigger` — operator override
- `schedule-configure` — set queue, priority, backoff, max_attempts per schedule

### 4.2 `job-list` — concrete jobs

```bash
./sa-plan job-list                                  # last 20
./sa-plan job-list --queue embed --state executing  # filtered
./sa-plan job-list --json                           # machine-readable
./sa-plan job-list --limit 100
```

**Use when**: "Why didn't last night's embed-refresh complete? Are jobs stuck?"

Companion: `job-enqueue`, `job-cancel`, `job-retry`, `job-snooze`, `job-prune`, `job-lifeline`.

### 4.3 `queue-list` — resource pools

```bash
./sa-plan queue-list
```

**Use when**: "Why is this queue draining slowly? What's the concurrency limit?"

Default queues seeded by `oban.rs::ensure_schema`: `default`, `critical`, `maintenance`, `ingest`, `delivery` — each with `max_concurrency=4`.

Companion: `queue-pause`, `queue-set-concurrency`.

### 4.4 `workflow-executions` — long-running sagas

```bash
./sa-plan workflow-executions                              # last 20
./sa-plan workflow-executions --workflow-type ignest_docs  # filtered
./sa-plan workflow-executions --state running --json
```

**Use when**: "Is the long-running ingest workflow still alive? What's its current state?"

Sagas are durable: a daemon restart resumes from the last `workflow_event`, not from scratch. Companion: `workflow-start`, `workflow-signal`, `workflow-query`, `workflow-cancel`, `workflow-terminate`, `workflow-describe`, `workflow-continue-as-new`.

### 4.5 `workflow-list` — event history

```bash
./sa-plan workflow-list
```

**Use when**: "What did this workflow actually do? When did each step fire?"

This is the *durable history feed* — append-only events emitted by `workflow_executions`. It is the ground truth for replay and audit.

---

## 5. How they compose — three worked examples

### 5.1 "Refresh ZK embeddings every 6 hours"

```
schedule-list           shows  embed_refresh @ "0 */6 * * *"
        │
        │ cron fires
        ▼
job-list --queue embed  shows  job#4711 worker=embed_refresh state=available
        │
        │ scheduler tick assigns to executor
        ▼
queue-list              shows  queue=embed executing=1/2
        │
        │ worker runs embed_refresh (~3 min)
        ▼
job-list --state completed  shows  job#4711 attempt=1 completed
```

No workflow involved — single-shot job.

### 5.2 "Drive a multi-step ingest with retries and signals"

```
workflow-start ingest_corpus --input '{"path":"docs/"}'
        │
        ▼
workflow-executions     shows  abcd-1234 type=ingest_corpus state=running
        │
        │ saga schedules child jobs
        ▼
job-list --workflow-id abcd-1234  shows  10 chunked ingest_docs jobs
        │
        │ operator sends pause signal
        ▼
workflow-signal abcd-1234 pause
        │
        ▼
workflow-list           shows  ...,
                                event#42 ActivityCompleted(chunk_3),
                                event#43 SignalReceived(pause),
                                event#44 TimerStarted(resume_at=...)
```

Long-lived saga; jobs are just the worker units it dispatches.

### 5.3 "Operator audit — what touched planning task X?"

```
sa-plan status                shows  task X transitioned pending→completed
        │
        │ when? by which automation?
        ▼
workflow-list | grep <task-X>  shows  WorkflowCompleted emitting plan_update
        │
        ▼
workflow-executions <wf-id>   shows  the saga that owned that update
        │
        ▼
job-list --workflow-id <wf-id> shows  the worker jobs the saga spawned
```

This is the only flow where the scheduler internals connect back to planning tasks.

---

## 6. Decision tree — which command do I want?

```
"What background work exists?"
  │
  ├─ "What is supposed to run on a schedule?"        → schedule-list
  ├─ "What is running / queued / failed right now?"  → job-list
  ├─ "Which queue is bottlenecked?"                  → queue-list
  ├─ "Is my long-running process still alive?"       → workflow-executions
  └─ "What did that workflow actually do, step by step?" → workflow-list

"What planning tasks exist?"                          → sa-plan status   (different domain)
"What's recommended for me to work on next?"          → sa-plan recommend (different domain)
"Show me a rich interactive view"                     → sa-plan dashboard (TUI) or sa-plan serve (web :4200)
```

---

## 7. Common operator recipes

### Why is the daemon idle when it shouldn't be?

```
./sa-plan schedule-list                # any schedules paused?
./sa-plan queue-list                   # any queues paused or concurrency=0?
./sa-plan job-list --state available   # is anything queued at all?
./sa-plan job-list --state retryable   # backoff in progress?
```

### Stuck job

```
./sa-plan job-list --state executing
# pick the stale id N
./sa-plan job-snooze N --delay-seconds 0   # rearm
# or
./sa-plan job-lifeline                     # bulk reset all >N-seconds-stuck
```

### A workflow is hung

```
./sa-plan workflow-executions --state running
./sa-plan workflow-describe <wf-id>        # full history
./sa-plan workflow-cancel <wf-id>          # cooperative
./sa-plan workflow-terminate <wf-id>       # hard-stop (last resort)
```

### Bypass cron and fire a schedule manually

```
./sa-plan schedule-trigger <schedule-id>
./sa-plan job-list --limit 5               # see the just-enqueued job
```

---

## 8. What these commands are NOT

- They do **not** enumerate the 1,852 pending planning tasks. Use `sa-plan status` (totals only), `sa-plan dashboard` (TUI), or `sa-plan serve` (web :4200).
- They do **not** show OODA cortex traces, chat-pipeline traces, or RAG queries — those go to `transaction_trace` / Zenoh `indrajaal/l5/cog/trace/**`.
- They do **not** show MCP tool invocations directly — those ride MoZ on `indrajaal/mcp/req/**` and `.../res/**`.
- They do **not** show Zenoh telemetry — use `sched-observe` for live scheduler envelopes on `indrajaal/l4/sched/**`.

---

## 9. Cross-references

- Code: `sub-projects/c3i/native/planning_daemon/src/{oban.rs,workflow.rs,workers.rs,scheduler.rs}`
- Schemas: `oban.rs::ensure_schema` (8 tables), `workflow.rs::ensure_schema` (2 tables)
- Worker registry: `workers.rs::known_workers()` (24 workers)
- Constraints: SC-SCHED-OBAN-001, SC-SCHED-TMPRL-001, SC-DISP-REGISTRY-001..010, SC-HA-001, SC-FUNC-004
- Anti-pattern (registry drift): `.claude/rules/dispatcher-registry-consistency.md`
- Live observer: `./sa-plan sched-observe` (Zenoh `indrajaal/l4/sched/**`)
