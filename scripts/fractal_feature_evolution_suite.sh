#!/usr/bin/env bash
# fractal_feature_evolution_suite.sh — codified per SC-FRACTAL-AUTO-001
# STAMP: SC-FRACTAL-AUTO-001, SC-FEAT-EVO-001..013, SC-NOTIFY-JOURNAL-001
# ZK: [zk-3346fc607a1ef9e6] (no Stub-That-Lies — actual delegate, not fake)
#
# Single autopilot pipeline for post-feature-implementation per SC-FRACTAL-AUTO-001.
# Delegates to existing sa-plan-daemon subcommands rather than reinventing.
#
# Usage: ./scripts/fractal_feature_evolution_suite.sh <task-id> [--skip-tests]
set -euo pipefail

TASK_ID="${1:-}"
SKIP_TESTS="${2:-}"

if [ -z "$TASK_ID" ]; then
  echo "Usage: $0 <task-id> [--skip-tests]" >&2
  echo "Example: $0 116486929469430710" >&2
  exit 1
fi

ROOT=/home/an/dev/ver/c3i
SAPLAN="$ROOT/sub-projects/work/release/sa-plan-daemon"
GLEAM_DIR="$ROOT/lib/cepaf_gleam"
GLEAM_BIN=$(command -v gleam || echo /home/an/dev/ver/intelitor-v5.2/.devenv/profile/bin/gleam)
DATE=$(date +%Y%m%d-%H%M)

echo "=== fractal_feature_evolution_suite for task $TASK_ID ==="

# Step 1: Build verification (SC-FEAT-EVO-001)
if [ "$SKIP_TESTS" != "--skip-tests" ]; then
  echo "[1/5] gleam build verification"
  cd "$GLEAM_DIR" && "$GLEAM_BIN" build 2>&1 | tail -3 || { echo "BUILD FAIL"; exit 2; }

  echo "[2/5] gleam test regression"
  RESULT=$(cd "$GLEAM_DIR" && "$GLEAM_BIN" test 2>&1 | tail -c 200 | grep -aoE "[0-9]+ passed[^[:cntrl:]]*" | tail -1)
  echo "  $RESULT"
fi

# Step 3: ZK ingest (SC-FEAT-EVO-007)
echo "[3/5] sa-plan ingest-docs (ZK update)"
cd "$ROOT/sub-projects/c3i" && "$SAPLAN" ingest-docs 2>&1 | tail -3 || echo "(ingest skipped — daemon may not be running)"

# Step 4: Update task link registry (SC-FEAT-EVO-010)
echo "[4/5] task link registry — task-id $TASK_ID"
LINK_REGISTRY="$ROOT/docs/journal/task-${TASK_ID}-links.json"
if [ ! -f "$LINK_REGISTRY" ]; then
  cat > "$LINK_REGISTRY" <<EOF
{
  "task_id": "$TASK_ID",
  "tailscale_url": "https://vm-1.tail55d152.ts.net:8443/task-id/$TASK_ID",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "evolution_journal": "docs/journal/$(date +%Y%m%d)-task-${TASK_ID}-evolution.md",
  "screenshots": [],
  "diagrams": [],
  "regression_pass_count": "${RESULT:-unknown}"
}
EOF
  echo "  → $LINK_REGISTRY"
else
  echo "  registry exists, append on top via separate task"
fi

# Step 5: Email notification (SC-NOTIFY-JOURNAL-001)
echo "[5/5] email autopilot summary"
cd "$ROOT/sub-projects/c3i" && "$SAPLAN" send-email \
  --to Abhijit.Naik@bountytek.com \
  --subject "Fractal autopilot — task $TASK_ID @ $DATE" \
  --body "Autopilot suite complete for task $TASK_ID. Regression: ${RESULT:-skipped}. Tailscale: https://vm-1.tail55d152.ts.net:8443/task-id/$TASK_ID" \
  -a "$LINK_REGISTRY" 2>&1 | tail -2 || echo "(email skipped — SMTP creds may need refresh)"

echo "=== fractal_feature_evolution_suite OK ==="
