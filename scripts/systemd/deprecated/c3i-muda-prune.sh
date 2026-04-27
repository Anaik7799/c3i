#!/usr/bin/env bash
# C3I Fractal MUDA Pruner — eliminates resource waste autonomously
# Per SC-MUDA-001 and Toyota Production System (Jidoka)
# Runs every 5 min via c3i-muda-prune.timer
set -euo pipefail

LOG=/tmp/c3i-muda-prune.log
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

log() { echo "[$TS] $*" >> "$LOG"; }

# 1. Detect stale Stop-hook flock (stale = lock file exists but no holder)
if [ -f /tmp/c3i-stop-hook.lock ] && ! lsof /tmp/c3i-stop-hook.lock >/dev/null 2>&1; then
  rm -f /tmp/c3i-stop-hook.lock
  log "MUDA: removed stale flock /tmp/c3i-stop-hook.lock"
fi

# 2. Detect runaway ingest-docs (>15 min old = orphan)
for pid in $(pgrep -f "sa-plan-daemon ingest-docs" 2>/dev/null); do
  age=$(awk -v pid=$pid 'BEGIN{
    cmd="ps -o etimes= -p " pid; cmd | getline t; print t+0
  }' </dev/null 2>/dev/null || echo 0)
  if [ "$age" -gt 900 ]; then
    kill -TERM "$pid" 2>/dev/null && log "MUDA: TERM stale ingest-docs PID=$pid age=${age}s"
    sleep 5
    kill -KILL "$pid" 2>/dev/null || true
  fi
done

# 3. Detect swap pressure → log warning to health
SWAP_USED=$(awk '/SwapTotal/ {tot=$2} /SwapFree/ {fre=$2} END {if(tot>0) print int((tot-fre)*100/tot); else print 0}' /proc/meminfo)
if [ "$SWAP_USED" -gt 80 ]; then
  log "MUDA: swap pressure ${SWAP_USED}%; consider Slice memory cap reduction"
fi

# 4. Detect c3i.slice CPU near cap → log
SLICE_CPU=$(systemctl --user show c3i.slice -p CPUUsageNSec --value 2>/dev/null || echo 0)
if [ -n "$SLICE_CPU" ] && [ "$SLICE_CPU" -gt 0 ]; then
  log "MUDA: slice cpu_nsec=$SLICE_CPU"
fi

# 5. Detect failed units and reset (so they can restart)
for u in $(systemctl --user list-units --state=failed --type=service --no-legend --plain 2>/dev/null \
           | awk '{print $1}' | grep -E '^c3i-'); do
  systemctl --user reset-failed "$u"
  log "MUDA: reset-failed $u"
done

# 6. Tail-prune log to last 200 lines
tail -200 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"

exit 0
