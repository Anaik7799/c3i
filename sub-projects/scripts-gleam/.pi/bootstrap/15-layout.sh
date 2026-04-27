#!/bin/bash
# Move loose docs into docs/, create the nix-configs/ skeleton
# called out by the K3s plan, and leave legacy paths clean.
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/15-layout.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

REPO=/mnt/c/dev/elixir/sys
cd "$REPO"

echo "[$(date -Is)] ensuring docs/ and nix-configs/ trees"
mkdir -p docs
mkdir -p nix-configs/hosts/nas1
mkdir -p nix-configs/k3s
mkdir -p nix-configs/modules

# --- move loose *.md plans into docs/ (use git mv to preserve history) ------
for f in nas1-hardware-analysis.md nixos-k8s-plan.md; do
  if [ -e "$f" ]; then
    echo "  git mv $f docs/$f"
    git mv "$f" "docs/$f"
  fi
done

echo "[$(date -Is)] done"
