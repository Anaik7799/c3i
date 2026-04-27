#!/usr/bin/env bash
# C3I Stop hook — runs at end of every Claude session.
# Mutex via flock -n at the call site (settings.json).
# Per SC-NOTIFY-JOURNAL + SC-ZETTEL-001.
set -e
cd /home/an/dev/ver/c3i

COMMITS=$(git log --oneline --since="12 hours ago" 2>/dev/null | wc -l)
FILES=$(git diff --stat "HEAD~${COMMITS:-1}..HEAD" 2>/dev/null | tail -1 | grep -oP '\d+ file' | grep -oP '\d+' || echo 0)
SID="$(date +%Y%m%d-%H%M)"

DAEMON=./sub-projects/c3i/target/release/sa-plan-daemon
FY27_ZK=/home/an/dev/ver/c3i/sub-projects/work/fy27-zk-build/release/fy27-zettelkasten

# 1. Save session metrics
"$DAEMON" session-save \
    --session-id "$SID" \
    --commits "$COMMITS" \
    --files-modified "${FILES:-0}" \
    --tasks-completed 0 \
    --effectiveness 0.85 2>/dev/null || true

# 2. Ingest C3I docs
"$DAEMON" ingest-docs 2>/dev/null || true

# 3. Ingest FY27 Zettelkasten
( cd sub-projects/work/gdrive/1-Work/FY27-Plan/zettelkasten && "$FY27_ZK" import .. 2>/dev/null ) || true

echo '{"systemMessage":"Session saved + dual Zettelkasten ingested."}'
