#!/usr/bin/env bash
set -euo pipefail

# Pi constant drift guard for .claude artifacts
# Fails if known stale literals reappear.

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

TARGETS=(.claude/rules .claude/commands .claude/agents)

# Forbidden stale patterns (regex)
read -r -d '' FORBIDDEN <<'EOF' || true
currently 87
Expected: 87 \(14 Pi \+ 73 C3I MCP\)
Bridge modules: 5/5
all 5 Pi bridge modules
all 5 Pi bridge
5 Pi bridge modules
currently 44
44 registered
EOF

# Required baseline patterns (at least one hit each family)
REQUIRED=(
  "93 total \(6 Claude \+ 14 Pi \+ 73 C3I MCP\)"
  "29 Pi events ↔ 32 AG-UI events"
)

fail=0

echo "[pi-const-check] scanning ${TARGETS[*]}"

while IFS= read -r pat; do
  [[ -z "$pat" ]] && continue
  if rg -n --no-heading -S "$pat" "${TARGETS[@]}" >/tmp/pi-const-forbidden.txt 2>/dev/null; then
    echo "❌ Forbidden stale pattern found: $pat"
    cat /tmp/pi-const-forbidden.txt
    fail=1
  fi
done <<< "$FORBIDDEN"

for req in "${REQUIRED[@]}"; do
  if ! rg -n --no-heading -S "$req" "${TARGETS[@]}" >/tmp/pi-const-required.txt 2>/dev/null; then
    echo "❌ Required baseline pattern missing: $req"
    fail=1
  else
    echo "✅ Required pattern present: $req"
  fi
done

if [[ "$fail" -ne 0 ]]; then
  echo "[pi-const-check] FAILED"
  exit 1
fi

echo "[pi-const-check] PASS"
