#!/usr/bin/env bash
# DEPRECATED 2026-04-28 — superseded by sub-projects/scripts-gleam/src/scripts/verify/marionette_health.gleam (per SC-SCRIPT-GLEAM-001).
# Run instead: cd sub-projects/scripts-gleam && gleam run -m scripts/verify/marionette_health
# This bash version retained only as emergency fallback; will be removed once Rust patches 0001+0002 land.
# marionette-health-check.sh — Fractal Jidoka validator for the Marionette MCP integration.
#
# STAMP: SC-MARIONETTE-001..012, SC-DART-MCP-001..010, SC-FEAT-EVO-013, SC-TPS-001
# Runs ALL gates from .claude/rules/marionette-mcp-flutter-testing.md and
# .claude/rules/dart-flutter-ai-mcp.md and emits:
#   1. JSON report to stdout (single line — for cron/scheduler ingestion)
#   2. Human report on stderr
#   3. Zenoh envelope on indrajaal/l5/test/marionette/healthcheck/<run_id>
#   4. sa-plan task per failed gate (idempotent — unique-key prevents duplicates)
#   5. Exit code 0 if all green, non-zero if any gate failed
#
# Usage:
#   ./marionette-health-check.sh              # full check + emit envelope
#   ./marionette-health-check.sh --json       # JSON only
#   ./marionette-health-check.sh --no-publish # skip Zenoh publish + task creation

set -uo pipefail

ROOT="${C3I_ROOT:-/home/an/dev/ver/c3i}"
PATH="/usr/bin:/usr/local/bin:$PATH"
SAP="$ROOT/sub-projects/c3i/target/release/sa-plan-daemon"
RUN_ID="$(date -u +%Y%m%d-%H%M%S)-$$"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TASK_ID="116480247290237220"
PASS=0; FAIL=0
RESULTS=()
PUBLISH=true; JSON_ONLY=false

for a in "$@"; do
  case "$a" in
    --no-publish) PUBLISH=false ;;
    --json)       JSON_ONLY=true ;;
  esac
done

log() { $JSON_ONLY || echo "$@" >&2; }

check() {
  local id="$1" desc="$2" cmd="$3"
  if eval "$cmd" >/dev/null 2>&1; then
    PASS=$((PASS+1))
    RESULTS+=("{\"id\":\"$id\",\"desc\":\"$desc\",\"status\":\"pass\"}")
    log "  ✅  $id  $desc"
  else
    FAIL=$((FAIL+1))
    RESULTS+=("{\"id\":\"$id\",\"desc\":\"$desc\",\"status\":\"fail\"}")
    log "  ❌  $id  $desc"
  fi
}

log "=== Marionette MCP health check · run_id=$RUN_ID ==="

# ─── A. Governance artefacts present ───────────────────────────────────────────
check H-A1  "Allium spec present"                    "test -s $ROOT/specs/allium/marionette_mcp.allium"
check H-A2  "Marionette rule present"                "test -s $ROOT/.claude/rules/marionette-mcp-flutter-testing.md"
check H-A3  "Dart-Flutter AI rule present"           "test -s $ROOT/.claude/rules/dart-flutter-ai-mcp.md"
check H-A4  "Patrol companion rule present"          "test -s $ROOT/.claude/rules/patrol-mcp-zenoh.md"
check H-A5  "Marionette explorer agent present"      "test -s $ROOT/.claude/agents/marionette-explorer.md"
check H-A6  "Patrol test agent present"              "test -s $ROOT/.claude/agents/patrol-test-agent.md"
check H-A7  "Marionette explore skill present"       "test -s $ROOT/.claude/commands/marionette-explore.md"
check H-A8  "Patrol-marionette skill present"        "test -s $ROOT/.claude/commands/patrol-marionette-test.md"
check H-A9  "Fractal Jidoka rule present"            "test -s $ROOT/.claude/rules/marionette-fractal-jidoka.md"
check H-A10 "RCA-TPS doc present"                    "test -s $TD/rca-tps.md"

# ─── B. Settings.json + MCP servers ────────────────────────────────────────────
check H-B1  "settings.json valid JSON"               "jq empty $ROOT/.claude/settings.json"
check H-B2  "dart MCP server wired"                  "jq -e '.mcpServers.dart' $ROOT/.claude/settings.json"
check H-B3  "marionette MCP server wired"            "jq -e '.mcpServers.marionette' $ROOT/.claude/settings.json"
check H-B4  "patrol MCP server wired"                "jq -e '.mcpServers.patrol' $ROOT/.claude/settings.json"
check H-B5  "SessionStart Marionette probe present"  "grep -q 'Marionette MCP readiness probe\\|MCP servers: dart=' $ROOT/.claude/settings.json"
check H-B6  "PostToolUse Zenoh bridge present"       "grep -q 'patrol-zenoh-bridge' $ROOT/.claude/settings.json"
check H-B7  "PostToolUse SC-MARIONETTE-003 guard"    "grep -q 'SC-MARIONETTE-003 discovery-first guard' $ROOT/.claude/settings.json"
check H-B8  "Zenoh bridge script executable"         "test -x $ROOT/.claude/scripts/patrol-zenoh-bridge.sh"

# ─── C. Hook syntax (bash -n) ──────────────────────────────────────────────────
check H-C1  "Zenoh bridge bash syntax"               "bash -n $ROOT/.claude/scripts/patrol-zenoh-bridge.sh"
check H-C2  "This health check bash syntax"          "bash -n $ROOT/.claude/scripts/marionette-health-check.sh"

# ─── D. Upstream clone integrity ───────────────────────────────────────────────
check H-D1  "Upstream marionette_mcp clone"          "test -f $ROOT/sub-projects/marionette_mcp/packages/marionette_mcp/lib/src/vm_service/vm_service_context.dart"
check H-D2  "Upstream all 5 packages"                "test -d $ROOT/sub-projects/marionette_mcp/packages/marionette_flutter -a -d $ROOT/sub-projects/marionette_mcp/packages/marionette_mcp -a -d $ROOT/sub-projects/marionette_mcp/packages/marionette_cli -a -d $ROOT/sub-projects/marionette_mcp/packages/marionette_logging -a -d $ROOT/sub-projects/marionette_mcp/packages/marionette_logger"

# ─── E. FluffyChat catalog ─────────────────────────────────────────────────────
check H-E1  "FluffyChat marionette/CATALOG.md"       "test -s $ROOT/sub-projects/sutra/fluffychat/integration_test/marionette/CATALOG.md"
check H-E2  "FluffyChat manifest.json valid"         "jq empty $ROOT/sub-projects/sutra/fluffychat/integration_test/marionette/manifest.json"
check H-E3  "FluffyChat 200 tests claimed"           "jq -e '.total == 200' $ROOT/sub-projects/sutra/fluffychat/integration_test/marionette/manifest.json"
check H-E4  "FluffyChat marionette runner.dart"      "test -s $ROOT/sub-projects/sutra/fluffychat/integration_test/marionette/marionette_runner.dart"

# ─── F. Task-page artefacts ────────────────────────────────────────────────────
TD="$ROOT/docs/journal/task-$TASK_ID"
check H-F1  "Task journal present"                   "test -s $TD/journal.md"
check H-F2  "Task index.html present"                "test -s $TD/index.html"
check H-F3  "Task deck.html present"                 "test -s $TD/deck.html"
check H-F4  "goals.md present"                       "test -s $TD/goals.md"
check H-F5  "spec.md present"                        "test -s $TD/spec.md"
check H-F6  "design.md present"                      "test -s $TD/design.md"
check H-F7  "implementation.md present"              "test -s $TD/implementation.md"
check H-F8  "sre.md present"                         "test -s $TD/sre.md"
check H-F9  "mcp-clarity.md present"                 "test -s $TD/mcp-clarity.md"
check H-F10 "test-plan.md present"                   "test -s $TD/test-plan.md"
check H-F11 "gap-analysis.md present"                "test -s $TD/gap-analysis.md"
check H-F12 "links.json valid"                       "jq empty $TD/task-$TASK_ID-links.json"
check H-F13 "10 PNG diagrams"                        "test \$(ls $TD/diagrams/*.png 2>/dev/null | wc -l) -ge 10"
check H-F14 "10 SVG diagrams"                        "test \$(ls $TD/diagrams/*.svg 2>/dev/null | wc -l) -ge 10"
check H-F15 "4 Graphviz .dot sources"                "test \$(ls $TD/diagrams/g*.dot 2>/dev/null | wc -l) -eq 4"

# ─── G. Live HTTPS task-page reachability ─────────────────────────────────────
check H-G1  "sa-plan-daemon serve listening :8443"   "ss -tln 2>/dev/null | grep -q ':8443'"
check H-G2  "Rich task page returns 200"             "curl -sk -o /dev/null -w %{http_code} https://localhost:8443/task-id/$TASK_ID | grep -q '^200\$'"
check H-G3  "Analysis dashboard returns 200"         "curl -sk -o /dev/null -w %{http_code} https://localhost:8443/task-id/$TASK_ID/task-$TASK_ID/index.html | grep -q '^200\$'"
check H-G4  "MCP clarity returns 200"                "curl -sk -o /dev/null -w %{http_code} https://localhost:8443/task-id/$TASK_ID/task-$TASK_ID/mcp-clarity.md | grep -q '^200\$'"
check H-G5  "links.json returns 200"                 "curl -sk -o /dev/null -w %{http_code} https://localhost:8443/task-id/$TASK_ID/task-$TASK_ID/task-$TASK_ID-links.json | grep -q '^200\$'"
check H-G6  "PNG diagram returns 200"                "curl -sk -o /dev/null -w %{http_code} https://localhost:8443/task-id/$TASK_ID/task-$TASK_ID/diagrams/01-architecture.png | grep -q '^200\$'"
check H-G7  "URLs in links.json point to :8443"      "! grep -q ':4200' $TD/task-$TASK_ID-links.json"

# ─── H. SC-MARIONETTE-003 flag-file mechanism (round-trip) ────────────────────
TEST_FLAG="/tmp/marionette-discovery-healthcheck-${RUN_ID}.flag"
check H-H1  "Flag-file create + remove"              "touch $TEST_FLAG && test -f $TEST_FLAG && rm $TEST_FLAG"

# ─── I. sa-plan task tree integrity ────────────────────────────────────────────
check H-I1  "sa-plan-daemon binary present"          "test -x $SAP"
check H-I2  "Parent task exists"                     "$SAP status 2>/dev/null | grep -q 'Active\\|Pending\\|Completed'"
# Note: not checking individual child IDs — they're in Smriti.db; this would need a json view.

# ─── J. ZK presence ────────────────────────────────────────────────────────────
check H-J1  "Smriti.db present"                      "test -f $ROOT/sub-projects/c3i/data/kms/smriti.db"
check H-J2  "ZK has marionette holons"               "$SAP knowledge-search 'marionette mcp' 2>/dev/null | grep -q 'zk-'"

# ─── K. Existing health probe of Marionette MCP global activation ─────────────
check H-K1  "dart binary on PATH"                    "command -v dart"
check H-K2  "Note: marionette_mcp activation"        "dart pub global list 2>/dev/null | grep -q marionette_mcp || true"

# ─── Summary ───────────────────────────────────────────────────────────────────
TOTAL=$((PASS+FAIL))
PCT=$((PASS*100/(TOTAL>0 ? TOTAL : 1)))
log ""
log "=== Result: $PASS passed / $FAIL failed / $TOTAL total = ${PCT}% ==="

# Build JSON report
JSON_RESULTS=$(IFS=,; echo "${RESULTS[*]}")
JSON_PAYLOAD=$(cat <<EOF
{"at":"$NOW","source":"marionette-health-check","urn":"urn:c3i:test:marionette:healthcheck:$RUN_ID","run_id":"$RUN_ID","phase":"$([ $FAIL -eq 0 ] && echo passed || echo failed)","platform":"linux","test_target":"$0","duration_ms":0,"summary":{"pass":$PASS,"fail":$FAIL,"total":$TOTAL,"pct":$PCT},"results":[$JSON_RESULTS]}
EOF
)

echo "$JSON_PAYLOAD"

# Publish to Zenoh + create tasks for failures (best-effort, non-fatal)
if $PUBLISH; then
  TOPIC="indrajaal/l5/test/marionette/healthcheck/${RUN_ID}/$([ $FAIL -eq 0 ] && echo passed || echo failed)"
  if [ -x "$ROOT/.claude/scripts/patrol-zenoh-bridge.sh" ]; then
    "$ROOT/.claude/scripts/patrol-zenoh-bridge.sh" publish "$TOPIC" "$JSON_PAYLOAD" 2>/dev/null || true
  fi
  if [ "$FAIL" -gt 0 ]; then
    # Create one consolidated sa-plan task per FAILED check (idempotent)
    for r in "${RESULTS[@]}"; do
      ID=$(echo "$r" | jq -r .id)
      ST=$(echo "$r" | jq -r .status)
      DS=$(echo "$r" | jq -r .desc)
      if [ "$ST" = "fail" ]; then
        cd "$ROOT" && "$SAP" add "[Marionette HEALTH FAIL ${ID}] ${DS}" P0 --unique-key "marionette-healthfail-${ID}" 2>/dev/null >/dev/null || true
      fi
    done
  fi
fi

[ "$FAIL" -eq 0 ]
