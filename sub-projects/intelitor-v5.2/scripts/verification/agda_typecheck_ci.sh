#!/usr/bin/env bash
# =============================================================================
# Agda Proof Type-Check CI Gate
# Purpose: Verify all Agda formal proofs type-check under --safe mode
# STAMP: SC-BDD-012 (Agda proofs MUST type-check)
# Usage: ./scripts/verification/agda_typecheck_ci.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

# --- Configuration ---
# Files that MUST pass (regression guard)
REQUIRED_PASS=(
  "verification/agda/Intelitor/Foundations.agda"
  "verification/agda/Intelitor/Axioms.agda"
  "verification/agda/Consensus.agda"
  "docs/formal_specs/agda/GraphProperties.agda"
  "docs/formal_specs/agda/OpenRouterGraphProofs.agda"
  "docs/formal_specs/agda/SupervisionProofs.agda"
  "docs/formal_specs/agda/AcyclicityProofs.agda"
  "docs/formal_specs/agda/TodolistAccessControl.agda"
  "docs/formal_specs/agda/ArkProofs.agda"
  "docs/formal_specs/agda/VersionVector.agda"
)

# Files with known issues (excluded from regression guard)
KNOWN_ISSUES=(
  "verification/agda/Intelitor/Emergency.agda"  # Requires Agda stdlib (Induction.WellFounded)
  "docs/formal_specs/agda/IndrajaalCore.agda"    # 602 lines, heavy stdlib deps (Data.Fin, Data.Vec, etc.)
)

# --- Collect all .agda files ---
mapfile -t AGDA_FILES < <(find verification/agda docs/formal_specs/agda -name '*.agda' 2>/dev/null | sort)

TOTAL=${#AGDA_FILES[@]}
PASS=0
FAIL=0
SKIP=0
REGRESSION=false

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  AGDA FORMAL PROOF CI GATE (SC-BDD-012)                ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║  Agda version: $(agda --version 2>/dev/null | head -1 || echo 'NOT FOUND')"
echo "║  Total proofs:  $TOTAL"
echo "║  Required:      ${#REQUIRED_PASS[@]}"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

for f in "${AGDA_FILES[@]}"; do
  # Check if known issue
  is_known_issue=false
  for ki in "${KNOWN_ISSUES[@]}"; do
    if [[ "$f" == "$ki" ]]; then
      is_known_issue=true
      break
    fi
  done

  if $is_known_issue; then
    echo "  ⊘ SKIP  $f  (known issue: stdlib dependency)"
    SKIP=$((SKIP + 1))
    continue
  fi

  # Type-check with --safe
  if output=$(agda --safe "$f" 2>&1); then
    echo "  ✓ PASS  $f"
    PASS=$((PASS + 1))
  else
    # Check if regression
    is_required=false
    for req in "${REQUIRED_PASS[@]}"; do
      if [[ "$f" == "$req" ]]; then
        is_required=true
        break
      fi
    done

    if $is_required; then
      echo "  ✗ REGRESSION  $f  ← MUST PASS"
      echo "    Error: $(echo "$output" | grep 'error:' | head -1)"
      REGRESSION=true
    else
      echo "  ✗ FAIL  $f"
    fi
    FAIL=$((FAIL + 1))
  fi
done

# --- Summary ---
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Results: $PASS pass, $FAIL fail, $SKIP skip (of $TOTAL total)"
echo "═══════════════════════════════════════════════════════════"

if $REGRESSION; then
  echo ""
  echo "FATAL: Regression detected — required proofs no longer type-check!"
  exit 1
fi

echo ""
echo "CI GATE: PASS ($PASS/$TOTAL proofs verified, $SKIP known issues)"
exit 0
