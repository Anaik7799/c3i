#!/bin/bash
# EP-GEN-014 Pre-commit Hook
# Validates PropCheck/ExUnitProperties disambiguation before commits
#
# STAMP Constraint: SC-PROP-023, SC-PROP-024
# Install: ln -s .claude/hooks/ep014_check.sh .git/hooks/pre-commit

set -e

echo "EP-GEN-014 Pre-commit Check"
echo "==========================="

# Find files with both check all() and use PropCheck but missing except clause
violations=""

for f in $(git diff --cached --name-only --diff-filter=ACM | grep -E "test/.*\.exs$"); do
  if [ -f "$f" ]; then
    has_propcheck=$(grep -l "use PropCheck" "$f" 2>/dev/null || true)
    has_check_all=$(grep -l "check all(" "$f" 2>/dev/null || true)
    has_except=$(grep -l "except:" "$f" 2>/dev/null || true)

    if [ -n "$has_propcheck" ] && [ -n "$has_check_all" ] && [ -z "$has_except" ]; then
      violations="$violations\n  $f"
    fi
  fi
done

if [ -n "$violations" ]; then
  echo "EP-GEN-014 VIOLATION DETECTED!"
  echo "Files missing 'import ExUnitProperties, except: [...]':"
  echo -e "$violations"
  echo ""
  echo "Fix: Add after 'use PropCheck':"
  echo "  import ExUnitProperties, except: [property: 2, property: 3, check: 2]"
  echo "  alias PropCheck.BasicTypes, as: PC"
  echo "  alias StreamData, as: SD"
  exit 1
fi

# Check for header spacing bugs
header_bugs=$(git diff --cached -U0 | grep -E '^\+.*"(accept|x) - ' || true)

if [ -n "$header_bugs" ]; then
  echo "HEADER SPACING BUG DETECTED!"
  echo "Lines adding headers with spaces:"
  echo "$header_bugs"
  echo ""
  echo "Fix: Remove spaces from header names"
  echo "  'x - forwarded - for' -> 'x-forwarded-for'"
  exit 1
fi

echo "EP-GEN-014: All checks passed ✓"
exit 0
