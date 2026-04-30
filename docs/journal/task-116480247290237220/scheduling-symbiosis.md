# Scheduling Symbiosis — Slurm + Oban + Temporal → sa-plan/scripts-gleam

> Task `116480247290237220`. Operator mandate: "review temporal, oban and slurm features, integrate all relevant slurm capabilities into the system. all fractal layers, full symbiosis slurm, oban and temporal services and features."
>
> Companion to `mcp-clarity.md`, `goals.md`, `spec.md`, `design.md`. Refines the `gleam_run` generic-worker design (rec. from prior turn) with Slurm-grade orchestration semantics.

ZK refs: [zk-11e75a5082df790f] (scripts-gleam isolation), [zk-e8c8efe2234f1344] (scripts-gleam common-module library), [zk-c0925afe640215b6] (anti-pattern: shell where Gleam should be), [zk-3e3c45be5cbff3ba] (SDLC + SRE lifecycle), [zk-44a047690971570e] (framework-first risk).

---

## 1. Three substrates compared (executive view)

| Capability | Slurm | Temporal | Oban | sa-plan today | Gap → absorb? |
|---|:-:|:-:|:-:|:-:|:-:|
| Async job submission | ✓ sbatch | ✓ workflow start | ✓ insert | ✓ job-enqueue | — |
| Cron / time-driven | ✓ | ✓ schedules | ✓ Cron plugin | ✓ workflow_schedules | — |
| Event-driven trigger | ─ | ✓ signals | ─ | ✓ Zenoh sched-observe | — |
| Retry + backoff | ✓ requeue | ✓ retry policy | ✓ | ✓ | — |
| Unique-key idempotency | ✓ singleton | ✓ workflow id | ✓ | ✓ | — |
| Priority | ✓ multifactor | int | int | int | **upgrade to multifactor** |
| **Job arrays** | **✓ --array=0-N** | child-workflows | ─ | ─ | **YES — absorb** |
| **Job dependencies (DAG)** | **✓ afterok/any** | ✓ child workflows | ─ | ─ | **YES — absorb** |
| **Partitions / queue policies** | **✓ per-queue caps** | ─ | queue names | queue names | **YES — absorb resource caps** |
| **Resource specs (cpu, mem, walltime)** | **✓** | ─ | ─ | ─ | **YES — absorb** |
| **Fair-share scheduling** | **✓ multifactor** | ─ | ─ | ─ | **YES — absorb** |
| **Backfill scheduling** | **✓** | ─ | ─ | ─ | **YES — absorb** |
| **QoS + preemption** | **✓** | ─ | ─ | ─ | **YES — absorb** |
| **Reservations (time-window)** | **✓** | ─ | ─ | ─ | **YES — absorb** |
| **Per-job accounting** | **✓ sacct** | metrics | telemetry | session_metrics partial | **YES — extend** |
| **Containment (cgroup)** | **✓** | ─ | erlang process | ─ | **YES — absorb (light)** |
| Federation (cross-cluster) | ✓ | ─ | ─ | ─ | next-sprint |
| Heterogeneous jobs | ✓ | child wf | ─ | ─ | low value |
| GRES (GPU plugins) | ✓ | ─ | ─ | ─ | not relevant yet |
| Power saving | ✓ | ─ | ─ | ─ | not relevant |
| Long-running activities | ─ | **✓ heartbeats** | ─ | ─ | **YES — absorb from Temporal** |
| Saga/compensation | ─ | **✓ rollback** | ─ | ─ | **YES — absorb from Temporal** |
| Signals / queries | ─ | **✓** | ─ | partial via Zenoh | **YES — formalise** |

**11 Slurm features + 3 Temporal features** worth absorbing on top of the existing Oban-style sa-plan substrate.

---

## 2. Design principles for absorption

1. **Stay within the kernel/userspace split** — sa-plan = kernel, scripts-gleam = userspace [zk-11e75a5082df790f]. New scheduling primitives go into sa-plan-daemon (Rust) **only when they need DB schema or scheduler-loop changes**. Everything else lives in scripts-gleam.
2. **Schema-first** — extend the `jobs` and `workflow_schedules` tables in Smriti.db with the minimum fields needed for Slurm-grade semantics. No new tables unless conceptually necessary.
3. **Generic dispatch ftw** — `gleam_run` worker (proposed prior turn) handles ALL custom workloads. Resource specs are job arguments interpreted by the worker's pre-flight.
4. **Backwards-compatible** — every existing job/schedule continues to work; new fields are nullable.
5. **OTel-everywhere** — every new capability publishes a Zenoh envelope (SC-ZMOF-001 + SC-PATROL-MCP-004 inheritance).

---

## 3. Schema deltas (Smriti.db)

### 3.1 `jobs` table — add fields
```sql
ALTER TABLE jobs ADD COLUMN cpu_request    INTEGER;             -- N cores
ALTER TABLE jobs ADD COLUMN mem_request_mb INTEGER;             -- soft cap (advisory)
ALTER TABLE jobs ADD COLUMN walltime_secs  INTEGER;             -- hard timeout
ALTER TABLE jobs ADD COLUMN qos            TEXT DEFAULT 'normal'; -- low|normal|high|critical
ALTER TABLE jobs ADD COLUMN array_index    INTEGER;             -- nullable; null for non-array
ALTER TABLE jobs ADD COLUMN array_total    INTEGER;             -- nullable
ALTER TABLE jobs ADD COLUMN depends_on     TEXT;                -- JSON array of job ids + trigger condition
ALTER TABLE jobs ADD COLUMN account        TEXT DEFAULT 'default'; -- fair-share key
-- accounting (filled on completion)
ALTER TABLE jobs ADD COLUMN cpu_ms_used    INTEGER;
ALTER TABLE jobs ADD COLUMN mem_peak_kb    INTEGER;
ALTER TABLE jobs ADD COLUMN exit_code      INTEGER;
```

### 3.2 New table — `partitions`
```sql
CREATE TABLE partitions (
  name              TEXT PRIMARY KEY,
  max_walltime_secs INTEGER,
  max_cpu_per_job   INTEGER,
  max_mem_per_job   INTEGER,
  default_qos       TEXT,
  priority_multiplier REAL DEFAULT 1.0,
  paused            INTEGER DEFAULT 0
);
```

### 3.3 New table — `reservations`
```sql
CREATE TABLE reservations (
  id            INTEGER PRIMARY KEY,
  name          TEXT UNIQUE,
  starts_at     TEXT,                 -- ISO-8601
  ends_at       TEXT,
  account       TEXT,                 -- whose jobs may consume
  cpu_reserved  INTEGER,
  mem_reserved_mb INTEGER,
  qos_required  TEXT
);
```

### 3.4 New table — `accounts`
```sql
CREATE TABLE accounts (
  name              TEXT PRIMARY KEY,
  parent_account    TEXT,
  fair_share_weight REAL DEFAULT 1.0,
  cpu_quota_secs    INTEGER,           -- per epoch (e.g. 24h)
  cpu_used_secs     INTEGER DEFAULT 0,
  decayed_at        TEXT
);
```

---

## 4. Rust patches (one-time, keep sa-plan-daemon stable thereafter)

| Patch | Purpose | Approx LOC |
|---|---|---:|
| **P1 `gleam_run` worker** (already proposed) | Dispatch any Gleam module by name | ~8 |
| **P2 `schedule-add` CLI** (already proposed) | Add new workflow_schedules without source mod | ~25 |
| **P3 schema migrations** (this doc) | Add 3 tables + 9 columns | ~50 SQL + 20 Rust |
| **P4 `job-array` flag on `job-enqueue`** | `--array=0-N` expands to N rows with shared parent | ~30 |
| **P5 `--depends-on` flag** | Parse + persist; scheduler skips until parent completes | ~40 |
| **P6 multifactor priority computation** | At dequeue, compute `score = age + fairshare + qos*W + partition + nice` | ~60 |
| **P7 backfill pass** | After main FIFO pass, walk small jobs; fill gaps | ~50 |
| **P8 reservation honour** | Dequeue refuses to start a job that would run during a conflicting reservation | ~30 |
| **P9 cgroup wrap** | When spawning `gleam run` on Linux, optionally wrap in `systemd-run --user --scope -p MemoryHigh=$mem -p CPUQuota=$cpu%` | ~25 |
| **P10 accounting hooks** | Capture wall_ms / rusage on child exit; persist to jobs row | ~30 |
| **P11 reservation/QoS CLI** | `sa-plan reservation create`, `sa-plan account create/update`, `sa-plan qos set` | ~80 |
| **TOTAL ONE-TIME** | | **~400 LOC Rust + 150 SQL** |

After this, every Slurm-grade capability is available via CLI + Smriti.db without further Rust changes.

---

## 5. Gleam-side helpers (scripts-gleam common modules)

```
sub-projects/scripts-gleam/src/scripts/common/
  job.gleam           → JobSpec record (cpu, mem, walltime, qos, array_idx)
  fairshare.gleam     → multifactor priority formula
  reservation.gleam   → time-window check
  array.gleam         → array expansion helper (--array=0-31)
  dependency.gleam    → DAG check
  account.gleam       → fair-share decay model
  saga.gleam          → compensation pattern (Temporal-style)
  signal.gleam        → Zenoh signal/query helper (Temporal-style)
  heartbeat.gleam     → long-running activity heartbeat (Temporal-style)
```

These are pure-Gleam libraries — recompile freely; sa-plan-daemon doesn't care.

---

## 6. Multifactor priority formula (Slurm parity)

```
priority(job) =
    w_age        * age_score(job)             // older waiting → higher
  + w_fairshare  * fairshare_score(job.account)
  + w_qos        * qos_weight(job.qos)
  + w_partition  * partition.priority_multiplier
  + w_nice       * (-job.nice)
  - w_size       * job.cpu_request            // smaller jobs preferred slightly

age_score(job)         = clamp((now - submitted) / 3600, 0, 24)        // 1 unit per hour, max 24
fairshare_score(acct)  = 1 - (acct.cpu_used_secs / acct.cpu_quota_secs)
qos_weight             = { low: 0, normal: 1, high: 5, critical: 50 }

decay: every hour, acct.cpu_used_secs *= 0.9    // half-life ~6.5 h
```

Default weights: `w_age=10, w_fairshare=20, w_qos=30, w_partition=5, w_nice=5, w_size=2`.

This is **Gleam-implementable** in `common/fairshare.gleam`. sa-plan-daemon's only hook is "call this Gleam fn at dequeue and use the returned ordering" — but that's a hot-path call. Better to translate the formula to Rust ONCE in P6 (60 LOC).

---

## 7. STAMP register (SC-SCHED-SYM-* family)

| ID | Constraint | Severity |
|---|---|---|
| SC-SCHED-SYM-001 | Job arrays MUST share a parent_id; array siblings dequeue independently but report into one summary | HIGH |
| SC-SCHED-SYM-002 | `--depends-on=afterok:N` MUST hold a job in `awaiting` state until N completes successfully | CRITICAL |
| SC-SCHED-SYM-003 | Partition resource caps MUST be enforced at admission (job rejected if cpu > partition.max_cpu_per_job) | HIGH |
| SC-SCHED-SYM-004 | Multifactor priority recomputed per dequeue; ordering MUST be deterministic given snapshot | HIGH |
| SC-SCHED-SYM-005 | Backfill MUST NOT delay any priority-N job by starting a priority-(N-k) one; Slurm conservative-backfill semantics | HIGH |
| SC-SCHED-SYM-006 | Reservations MUST be honoured — overlapping job dequeue refused with `BlockedByReservation` | CRITICAL |
| SC-SCHED-SYM-007 | Per-job accounting (cpu_ms_used, mem_peak_kb, exit_code) MUST be persisted on every completion | HIGH |
| SC-SCHED-SYM-008 | Cgroup wrap (when configured) MUST kill jobs exceeding hard limits with exit 137 (SIGKILL) | CRITICAL |
| SC-SCHED-SYM-009 | QoS preemption MUST signal SIGTERM, then SIGKILL after grace_secs | HIGH |
| SC-SCHED-SYM-010 | Saga compensations (Temporal-style) MUST run in reverse order on workflow rollback | HIGH |
| SC-SCHED-SYM-011 | Long-running activities MUST emit heartbeat envelopes ≤ heartbeat_secs; missing → declared failed | HIGH |
| SC-SCHED-SYM-012 | Signals + queries MUST publish on `indrajaal/l4/sched/signal/<workflow_id>/<name>` | MEDIUM |
| SC-SCHED-SYM-013 | All accounting fields MUST be queryable via `sa-plan account-stats` for fair-share computation | HIGH |
| SC-SCHED-SYM-014 | New schema migrations MUST be applied additively; never drop a column without a migration window | CRITICAL |
| SC-SCHED-SYM-015 | Federation (future) MUST NOT break single-cluster mode | HIGH |

---

## 8. RETE-UL extension (4 new rules at salience 50–80)

| Rule | Salience | When | Then |
|---|---:|---|---|
| `SchedFairShareSkew` | 80 | one account consumes > 50% of cpu_used_secs in last hour | warn + open task to review weights |
| `SchedReservationConflict` | 80 | new job submission overlaps active reservation | refuse + advisory |
| `SchedBackfillStarvation` | 70 | high-priority job waited > 4× expected (priority class p95) | escalate to next QoS tier |
| `SchedAccountingMissing` | 60 | completed job lacks cpu_ms_used | log + flag for retroactive sample |

Test-orchestration tier (60–95) has room. New family `Sched*` reserves 50–80 — no collisions.

---

## 9. Ruliology

**Rule 110 (emergence) extends to scheduling**: classify dequeue patterns over a 100-job sliding window into:
- `fair` — even distribution across accounts
- `concentrated` — one account dominates
- `starving` — same job/account waiting > p95
- `backfill_active` — short-job opportunism

Action: `concentrated` or `starving` → emit `SchedFairShareSkew`.

**Causal graph addition**: edge type `account_shared` between jobs from same account → enables blast-radius "if account X gets preempted, what queues drain?"

---

## 10. Mathematical artefacts (extended)

```
1. Multifactor priority (§6)
2. Fair-share decay:  acct.cpu_used_secs(t+1h) = 0.9 × acct.cpu_used_secs(t)
3. Backfill safety:   for each candidate small job c, accept iff
                      ∀ high-prio job h waiting: c.walltime_secs ≤ h.expected_start - now
4. QoS preemption rank: target = argmin_{j running} priority(j)  s.t.  qos(j) < qos(incoming)
5. Reservation overlap: ∃ R ∈ reservations: R.starts_at < submission.expected_end
                                          ∧ R.ends_at  > submission.expected_start
                                          ∧ R.cpu_reserved + jobs_during_R > capacity
                                          ∧ submission.account ∉ R.allowed_accounts
6. Accounting integrity (Allium invariant):
   ∀ j ∈ completed_jobs: j.cpu_ms_used ≠ NULL ∧ j.exit_code ≠ NULL
```

---

## 11. Fractal layer integration L0 → L7

| Layer | Slurm concept | C3I mapping |
|---|---|---|
| **L0 Constitutional** | resource quota enforcement | Cgroup hard-kill + reservation refusal — Ψ-2 reversibility |
| **L1 Atomic** | per-job rusage capture | `wait4()` syscall result → cpu_ms_used + mem_peak_kb |
| **L2 Component** | JobSpec + ResourceRequest types | `scripts/common/job.gleam` |
| **L3 Transaction** | per-job accounting row in jobs table | new schema columns (§3.1) |
| **L4 System** | scheduler dequeue loop with priority + backfill | sa-plan-daemon scheduler.rs (P6+P7) |
| **L5 Cognitive** | fair-share decision = OODA Decide | Gleam priority formula + RETE-UL `SchedFairShareSkew` |
| **L6 Ecosystem** | accounts hierarchy across users/agents | `accounts` table + Smriti.db |
| **L7 Federation** | multi-cluster job replication | future-sprint; out-of-scope this pass |

Vertical traceability: a fair-share violation observed at L5 (RETE-UL rule fires) traces to L3 (account row's `cpu_used_secs`), captured at L1 (per-job rusage), and remediated at L4 (next dequeue applies decay + new priority).

---

## 12. Symbiosis — final substrate composition

```
                        sa-plan-daemon (Rust kernel)
                          ↓ enqueue · schedule-add · scheduler-tick
                        ┌─────────────────────────────────────┐
                        │   GENERIC `gleam_run` WORKER         │
                        │   + Slurm-grade resource specs       │
                        │   + multifactor priority             │
                        │   + arrays · DAG deps · QoS · reserv.│
                        │   + per-job accounting · cgroup wrap │
                        │   + Temporal heartbeats · signals    │
                        └─────────────────────────────────────┘
                                        ↓ spawns
                        scripts-gleam (Gleam userspace)
                        ┌─────────────────────────────────────┐
                        │ scripts/common/                      │
                        │   job · fairshare · reservation      │
                        │   array · dependency · account       │
                        │   saga · signal · heartbeat          │
                        │ scripts/verify/                      │
                        │   marionette_health · dart_doctor    │
                        │   patrol_health · …infinite          │
                        └─────────────────────────────────────┘
                                        ↓ telemetry
                        Zenoh   indrajaal/l4/sched/**
                        Smriti  jobs · accounts · reservations
                        FMEA    aggregator
                        Dashboard live tile
                        RETE-UL rule_engine.rs (existing 52 + new 4 Sched* rules)
```

What's there from each:

- **Slurm**: arrays, DAG deps, partitions, multifactor priority, fair-share, backfill, QoS, preemption, reservations, accounting, cgroup containment.
- **Temporal**: long-running activities with heartbeats, sagas/compensations, signals, queries, schedules.
- **Oban**: queues, retry/backoff, unique-key idempotency, telemetry, persistence-to-Postgres-equivalent (Smriti.db).

---

## 13. Implementation roadmap (sprint order)

| Sprint | Work | Artefact |
|---|---|---|
| **Now** (operator confirms) | P1 + P2 (gleam_run + schedule-add) | first gleam-run validator running |
| **Sprint+1** | P3 (schema migrations) + P10 (accounting hooks) | per-job rusage in Smriti.db |
| **Sprint+1** | P4 (--array) + P5 (--depends-on) | DAG dispatch live |
| **Sprint+2** | P6 (multifactor priority) + P11 (account/QoS CLI) | fair-share live |
| **Sprint+2** | scripts-gleam common modules (job, fairshare, dependency, account) | Gleam parity with kernel |
| **Sprint+3** | P7 (backfill) + P8 (reservations) | full Slurm-parity scheduling |
| **Sprint+3** | P9 (cgroup wrap) | hard limits enforced |
| **Sprint+4** | Temporal-flavoured: saga.gleam + heartbeat.gleam + signal.gleam | sagas + long-running activities |
| **Sprint+5** | Federation (deferred — multi-cluster) | cross-mesh job routing |

---

## 14. Why not just run real Slurm?

Considered and rejected:

1. **Operational mismatch** — Slurm targets HPC clusters with shared filesystems + InfiniBand. C3I is a SIL-6 mesh with Zenoh transport.
2. **Containment style** — Slurm assumes a tightly-coupled login-node model. C3I uses Podman + ZMOF.
3. **Authentication** — Slurm's munge model conflicts with our RBAC (FerrisKey).
4. **Telemetry plumbing** — would need a sacct→Zenoh adapter; absorbing the ideas is cleaner than wiring two telemetry buses.
5. **Footprint** — Slurm controller + slurmd on every node is heavy for our 16-container mesh.

**Absorb the patterns; don't import the runtime.**

---

## 15. Conclusion

This design plus the prior turn's `gleam_run` proposal yields a substrate that:

- Is **Oban-style** (queues, retry, telemetry) ✓
- Is **Temporal-flavoured** (sagas, heartbeats, signals) — once Sprint+4 lands
- Is **Slurm-grade** (arrays, deps, partitions, fair-share, QoS, reservations, accounting, cgroups) — once Sprints +1..+3 land
- Stays **runtime-stable** (sa-plan-daemon Rust source touched ONCE for ~400 LOC across 11 patches; never again for new validators)
- Makes **scripts-gleam infinitely extensible** (recompile cheaply; add validators as pure Gleam modules)
- Carries **15 new STAMP IDs** (SC-SCHED-SYM-001..015) + **4 RETE-UL rules** + **6 math equations** + **fractal L0–L7 mapping**
- Aligns with **SC-SCRIPT-GLEAM-001** [zk-c0925afe640215b6] — no shell logic where Gleam should be

Recommendation: confirm to proceed with Sprint-Now (P1+P2 + Gleam port of validator). The remainder is a 5-sprint roadmap, fully sa-plan-native.
