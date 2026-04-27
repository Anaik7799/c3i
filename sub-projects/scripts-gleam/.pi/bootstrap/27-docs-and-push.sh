#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/27-docs-and-push.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys

git add AGENTS.md scripts/README.md .pi/bootstrap/

echo "=== staged ==="
git diff --cached --stat

echo
echo "=== commit ==="
git commit -m 'docs: AGENTS.md + scripts README reflect Rust/NixOS/remote setup'

echo
echo "=== push ==="
git push origin main

echo
echo "=== final log ==="
git log --oneline
