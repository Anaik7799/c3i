#!/usr/bin/env bash
# =============================================================================
# Constraint Sync Check — SessionStart Metric Publisher
# Purpose: Count SC-*/AOR-* in code vs docs, publish gap metrics
# STAMP: SC-SYNC-DOC-003 (run on every session start)
#        SC-SYNC-DOC-004 (publish gap metrics)
#        SC-SYNC-DOC-011 (F# engine is sole authoritative census)
# Usage: ./scripts/verification/constraint_sync_check.sh
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

DLL="lib/cepaf/src/Cepaf.ConstraintSync/bin/Release/net10.0/constraint-sync.dll"

# --- Try compiled F# binary first (SC-SYNC-DOC-011: F# engine is sole authority) ---
if [ -f "$DLL" ] && command -v dotnet &>/dev/null; then
  # Compiled binary: ~500ms for full census (vs ~2.5s fsx)
  dotnet exec "$DLL" 2>/dev/null
  if [ $? -eq 0 ]; then
    exit 0
  fi
fi

# --- Fallback: bash rg-based counting (fast ~1s, used when binary not built) ---
TODAY=$(date +%Y-%m-%d)

SC_CODE=$(rg -o 'SC-[A-Z]+-[0-9]+' lib/ test/ --no-filename 2>/dev/null | sort -u | wc -l)
SC_CODE_FAMILIES=$(rg -o 'SC-[A-Z]+' lib/ test/ --no-filename 2>/dev/null | sort -u | wc -l)
SC_DOCS=$(rg -o 'SC-[A-Z]+-[0-9]+' CLAUDE.md .claude/rules/ --no-filename 2>/dev/null | sort -u | wc -l)
SC_DOCS_FAMILIES=$(rg -o 'SC-[A-Z]+' CLAUDE.md .claude/rules/ --no-filename 2>/dev/null | sort -u | wc -l)
AOR_CODE=$(rg -o 'AOR-[A-Z]+-[0-9]+' lib/ test/ --no-filename 2>/dev/null | sort -u | wc -l)
AOR_CODE_FAMILIES=$(rg -o 'AOR-[A-Z]+' lib/ test/ --no-filename 2>/dev/null | sort -u | wc -l)
AOR_DOCS=$(rg -o 'AOR-[A-Z]+-[0-9]+' CLAUDE.md .claude/rules/ --no-filename 2>/dev/null | sort -u | wc -l)
AOR_DOCS_FAMILIES=$(rg -o 'AOR-[A-Z]+' CLAUDE.md .claude/rules/ --no-filename 2>/dev/null | sort -u | wc -l)

RULES_COUNT=$(ls .claude/rules/*.md 2>/dev/null | wc -l)
AGENTS_COUNT=$(ls .claude/agents/*.md 2>/dev/null | wc -l)
COMMANDS_COUNT=$(ls .claude/commands/*.md 2>/dev/null | wc -l)
HOOKS_COUNT=$(ls .claude/hooks/* 2>/dev/null | wc -l)

SC_GAP=$((SC_CODE - SC_DOCS))
if [ "$SC_GAP" -lt 0 ]; then SC_GAP=0; fi
AOR_GAP=$((AOR_CODE - AOR_DOCS))
if [ "$AOR_GAP" -lt 0 ]; then AOR_GAP=0; fi

if [ "$SC_DOCS" -gt 0 ]; then
  SC_RATIO_INT=$((SC_CODE * 10 / SC_DOCS))
  SC_RATIO="$((SC_RATIO_INT / 10)).$((SC_RATIO_INT % 10))"
else
  SC_RATIO="INF"
fi

if [ "$AOR_DOCS" -gt 0 ]; then
  AOR_RATIO_INT=$((AOR_CODE * 10 / AOR_DOCS))
  AOR_RATIO="$((AOR_RATIO_INT / 10)).$((AOR_RATIO_INT % 10))"
else
  AOR_RATIO="INF"
fi

if [ "$SC_CODE" -gt 0 ]; then
  SC_GAP_PCT=$((SC_GAP * 100 / SC_CODE))
else
  SC_GAP_PCT=0
fi

if [ "$AOR_CODE" -gt 0 ]; then
  AOR_GAP_PCT=$((AOR_GAP * 100 / AOR_CODE))
else
  AOR_GAP_PCT=0
fi

if [ "$SC_DOCS" -gt 0 ]; then
  SC_RATIO_CHECK=$((SC_CODE * 10 / SC_DOCS))
else
  SC_RATIO_CHECK=999
fi

if [ "$SC_RATIO_CHECK" -le 15 ]; then
  HEALTH="HEALTHY"
elif [ "$SC_RATIO_CHECK" -le 50 ]; then
  HEALTH="DEGRADED"
else
  HEALTH="CRITICAL"
fi

SYNC_FILE="$PROJECT_ROOT/.claude/last_constraint_sync"
LAST_SYNC="never"
if [ -f "$SYNC_FILE" ]; then
  LAST_SYNC=$(cat "$SYNC_FILE")
fi

cat <<EOF
CONSTRAINT SYNC STATUS (SC-SYNC-DOC)          [$TODAY]
  SC-* Constraints:
    Code:     $SC_CODE unique across $SC_CODE_FAMILIES families
    Docs:     $SC_DOCS unique across $SC_DOCS_FAMILIES families
    Gap:      $SC_GAP undocumented (${SC_GAP_PCT}%)
    Ratio:    ${SC_RATIO}:1 (target: 1.0:1)
  AOR-* Rules:
    Code:     $AOR_CODE unique across $AOR_CODE_FAMILIES families
    Docs:     $AOR_DOCS unique across $AOR_DOCS_FAMILIES families
    Gap:      $AOR_GAP undocumented (${AOR_GAP_PCT}%)
    Ratio:    ${AOR_RATIO}:1 (target: 1.0:1)
  .claude/ Inventory:
    Rules:    $RULES_COUNT files | Agents: $AGENTS_COUNT | Commands: $COMMANDS_COUNT | Hooks: $HOOKS_COUNT
  Sync Health: $HEALTH | Last Full Sync: $LAST_SYNC
EOF
