#!/usr/bin/env bash
# recursive_feature_convergence.sh — N-pass convergence loop per SC-FRACTAL-AUTO-001
# STAMP: SC-FRACTAL-AUTO-001, SC-FEAT-EVO-006
# ZK: [zk-3346fc607a1ef9e6] (no Stub-That-Lies — actual loop, not fake)
#
# Runs the fractal evolution suite N times, capturing convergence trajectory.
# Idempotent re-runs allow detection of metric drift.
#
# Usage: ./scripts/recursive_feature_convergence.sh <task-id> [iterations=3]
set -euo pipefail

TASK_ID="${1:-}"
ITERS="${2:-3}"

if [ -z "$TASK_ID" ]; then
  echo "Usage: $0 <task-id> [iterations]" >&2
  exit 1
fi

ROOT=/home/an/dev/ver/c3i
SUITE="$ROOT/scripts/fractal_feature_evolution_suite.sh"
TRAJECTORY="$ROOT/docs/journal/task-${TASK_ID}-convergence-$(date +%Y%m%d-%H%M).log"

echo "=== recursive_feature_convergence — $ITERS iterations ==="
mkdir -p "$(dirname "$TRAJECTORY")"

for i in $(seq 1 "$ITERS"); do
  echo "" | tee -a "$TRAJECTORY"
  echo "--- iteration $i / $ITERS @ $(date -u +%Y-%m-%dT%H:%M:%SZ) ---" | tee -a "$TRAJECTORY"
  "$SUITE" "$TASK_ID" --skip-tests 2>&1 | tee -a "$TRAJECTORY"
done

echo "=== convergence trajectory written to $TRAJECTORY ==="
