#!/bin/bash
# Create a local bare repo under /root/git/sys.git, register it as
# `origin`, and push. This gives us a functioning remote with zero
# network assumptions; swap to GitHub/Codeberg/self-hosted later with
#   git remote set-url origin <new-url>  &&  git push -u origin main --force
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/25-git-remote.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

REPO=/mnt/c/dev/elixir/sys
REMOTE_DIR=/root/git/sys.git

echo "[$(date -Is)] ensuring $REMOTE_DIR"
mkdir -p "$(dirname "$REMOTE_DIR")"
if [ ! -d "$REMOTE_DIR" ]; then
  git init --bare -b main "$REMOTE_DIR"
else
  echo "  (already exists)"
fi

cd "$REPO"

echo
echo "[$(date -Is)] registering origin"
if git remote | grep -qx origin; then
  echo "  updating existing origin"
  git remote set-url origin "$REMOTE_DIR"
else
  git remote add origin "$REMOTE_DIR"
fi
git remote -v

echo
echo "[$(date -Is)] fetching (no-op on a fresh bare) & pushing"
# First push: force because the bare is empty; subsequent pushes are plain.
git push -u origin main

echo
echo "=== final remote state ==="
git --git-dir="$REMOTE_DIR" log --oneline -n 10
echo
echo "=== local tracking ==="
git branch -vv
