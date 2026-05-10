#!/usr/bin/env bash
# Pre-commit hook — refuse plaintext API key shapes in staged content.
# SC-VAULT-004 enforcement (Jidoka — stop the line on defect).
#
# Install via:
#   ln -sf $(pwd)/.claude/scripts/vault-precommit-secret-scan.sh .git/hooks/pre-commit
#
# Bypass (NEVER in production): git commit --no-verify

set -euo pipefail

# Patterns of well-known production API keys (regex)
PATTERNS=(
  'sk-ant-api03-[A-Za-z0-9_-]{40,}'      # Anthropic
  'sk-or-v1-[a-f0-9]{40,}'                # OpenRouter
  'sk-proj-[A-Za-z0-9_-]{40,}'            # OpenAI project keys
  'AIza[A-Za-z0-9_-]{30,}'                # Google API keys
  'ghp_[A-Za-z0-9]{30,}'                   # GitHub PAT
  'gho_[A-Za-z0-9]{30,}'                   # GitHub OAuth
  'xoxb-[0-9]+-[0-9]+-[A-Za-z0-9]+'        # Slack bot token
)

# Files to scan: staged additions/modifications (-A = include all, U0 = no context)
DIFF=$(git diff --cached -U0 --diff-filter=AM 2>/dev/null || true)

if [ -z "$DIFF" ]; then
  exit 0
fi

VIOLATIONS=""
for pat in "${PATTERNS[@]}"; do
  # Match only on added lines (start with +, not +++)
  matches=$(echo "$DIFF" | grep -E "^\+[^+]" | grep -E "$pat" || true)
  # Suppress placeholder/example lines (operator can intentionally include placeholders)
  matches=$(echo "$matches" | grep -vE "(placeholder|example|REPLACE_ME|YOUR_KEY_HERE|<set via|sk-ant-api03-PLACEHOLDER)" || true)
  if [ -n "$matches" ]; then
    VIOLATIONS+="$matches"$'\n'
  fi
done

if [ -n "$VIOLATIONS" ]; then
  cat >&2 <<EOF
[SC-VAULT-004 VIOLATION] Plaintext API key shape detected in staged content:

$VIOLATIONS

Use the vault instead:
  sa-plan vault put <name> <value> --policy <l0_hot|l3_oauth|l3_smtp|l7_gateway>

If this is a placeholder for an example file, include "placeholder" or "<set via..."
in the same line so the scanner ignores it.

To bypass for THIS commit only (NOT recommended):
  git commit --no-verify

Bypassing leaves a permanent audit trail and triggers a P0 sa-plan task.
EOF
  exit 1
fi

exit 0
