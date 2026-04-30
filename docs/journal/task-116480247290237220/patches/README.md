# Scheduler Kernel Patches — Task 116480247290237220

Two patches to extend the `sa-plan-daemon` scheduler:

1. **`0001-add-gleam_run-worker.patch`** — adds a `"gleam_run"` arm to
   `scheduler::run_scheduled()` in `scheduler.rs`. Reads `GLEAM_RUN_MODULE`
   (and optional `GLEAM_RUN_CWD`) env vars, spawns `gleam run -m <module>`
   via `tokio::process::Command`, captures stdout/stderr, records
   completion/failure via `workflow::record_event`. ~23 LOC.

2. **`0002-add-schedule-add-cli.patch`** — adds a `ScheduleAdd` clap
   subcommand to `main.rs::Commands` and its dispatcher. Args:
   `--name`, `--cron`, `--worker` (default `gleam_run`),
   `--module`, `--args` (default `{}`), `--priority`, `--max-attempts`.
   Performs a lazy `ALTER TABLE workflow_schedules ADD COLUMN args TEXT`
   (idempotent — failure ignored if column exists), then `INSERT … ON
   CONFLICT(id) DO UPDATE`. ~62 LOC including clap variant + dispatch arm.

## Apply

```bash
cd /home/an/dev/ver/c3i
git apply docs/journal/task-116480247290237220/patches/0001-add-gleam_run-worker.patch
git apply docs/journal/task-116480247290237220/patches/0002-add-schedule-add-cli.patch
```

Optionally check first:

```bash
git apply --check docs/journal/task-116480247290237220/patches/0001-add-gleam_run-worker.patch
git apply --check docs/journal/task-116480247290237220/patches/0002-add-schedule-add-cli.patch
```

## Build

```bash
cd sub-projects/c3i/native/planning_daemon
cargo build --release
```

(For projects under the gdrive FUSE mount, prefix with
`CARGO_TARGET_DIR=/home/an/dev/ver/c3i/sub-projects/work/` per
SC-GDRIVE-BUILD-001.)

## Verify post-apply

```bash
# 1. Direct gleam_run invocation via job-enqueue (expects the worker to
#    pick up GLEAM_RUN_MODULE; until job-enqueue propagates args→env, the
#    operator can export GLEAM_RUN_MODULE before scheduler-tick).
GLEAM_RUN_MODULE=scripts/verify/marionette_health \
  ./sub-projects/c3i/target/release/sa-plan-daemon job-enqueue \
    --worker gleam_run \
    --args '{"module":"scripts/verify/marionette_health"}' \
    --unique-key marionette-test-run

# 2. Add a cron schedule for it
./sub-projects/c3i/target/release/sa-plan-daemon schedule-add \
  --name marionette_health_15m \
  --cron "*/15 * * * *" \
  --worker gleam_run \
  --module scripts/verify/marionette_health

# 3. Confirm it shows up
./sub-projects/c3i/target/release/sa-plan-daemon schedule-list
```

## Caveats

- **Scheduler dispatch → env propagation.** `run_scheduled()` reads
  `GLEAM_RUN_MODULE` from env, but `oban::tick_once` / `cmd_scheduler_run`
  invoke workers without per-schedule env injection. The `args` column
  added in Patch 2 carries the module, but a follow-up patch is needed
  inside `oban.rs` to read `workflow_schedules.args.module` and either
  set it via `std::env::set_var` before calling `run_scheduled` or pass
  it as a function arg. The two patches here are intentionally minimal;
  the env→args bridge is documented as a known gap.
- **Schema migration.** Patch 2's `ALTER TABLE … ADD COLUMN args` is
  idempotent (errors on re-run are silenced via `let _ =`). For a
  cleaner migration, add the column to `workflow.rs::ensure_schema()`.
- **No tests modified.** Both patches are additive; existing tests should
  continue to pass. New tests for `gleam_run` and `schedule-add` are
  out of scope for this minimal patch pair.
