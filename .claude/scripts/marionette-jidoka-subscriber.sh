#!/usr/bin/env bash
# marionette-jidoka-subscriber.sh — event-driven Jidoka reactor.
#
# Listens on Zenoh `indrajaal/l4/sched/**` for sa-plan-daemon scheduler events
# (Oban-style health_check, embed_refresh, zk_maintain completions). On every
# scheduler tick or health_check completion, runs the Marionette validator.
# This replaces the prior crontab-based scheduling per operator mandate
# "cron MUST use sa-plan job management and Oban/Temporal services".
#
# Activation:
#   bash marionette-jidoka-subscriber.sh                # foreground
#   nohup bash marionette-jidoka-subscriber.sh &        # detached (until shell exit)
#   systemctl --user start marionette-jidoka.service    # persistent (preferred)
#
# STAMP: SC-MARIONETTE-JIDOKA-002 (≥ every 10 min) · SC-MARIONETTE-JIDOKA-006 (Zenoh)

set -uo pipefail
ROOT="${C3I_ROOT:-/home/an/dev/ver/c3i}"
PATH="/usr/bin:/usr/local/bin:$PATH"
SAP="$ROOT/sub-projects/c3i/target/release/sa-plan-daemon"
VALIDATOR="$ROOT/.claude/scripts/marionette-health-check.sh"
LOG="$ROOT/data/marionette-healthcheck.log"
LAST_RUN_FILE="/tmp/marionette-jidoka-last-run"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LOG"; }

# Run validator ONCE at startup so we have a baseline immediately.
log "subscriber starting — initial validator run"
"$VALIDATOR" >> "$LOG" 2>&1
date +%s > "$LAST_RUN_FILE"

# Pulse the sa-plan scheduler so it enqueues + drains health_check periodically.
# This relies on the existing 4 workflow_schedules (embed_daily, health_10m, ...)
# Tick is idempotent: if no jobs are due it's a no-op.
pulse_scheduler() {
  cd "$ROOT" && "$SAP" scheduler-tick >> "$LOG" 2>&1
}

# Subscribe to scheduler telemetry; run validator on every health_check completion
# and at most once per 10-minute window (debounce against burst bursts).
log "subscriber: subscribing to indrajaal/l4/sched/**"
DEBOUNCE_SECS=600

cd "$ROOT" && "$SAP" sched-observe --json --pattern 'indrajaal/l4/sched/**' 2>>"$LOG" |
while IFS= read -r line; do
  # Pulse the scheduler (cheap, idempotent) on every event.
  pulse_scheduler

  # Debounced validator run: only if last_run > DEBOUNCE_SECS ago.
  NOW=$(date +%s)
  LAST=$(cat "$LAST_RUN_FILE" 2>/dev/null || echo 0)
  if (( NOW - LAST >= DEBOUNCE_SECS )); then
    log "scheduler event triggered validator (debounce ok, ${DEBOUNCE_SECS}s)"
    "$VALIDATOR" >> "$LOG" 2>&1
    date +%s > "$LAST_RUN_FILE"
  fi
done
