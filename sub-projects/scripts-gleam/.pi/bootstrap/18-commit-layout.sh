#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/18-commit-layout.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

REPO=/mnt/c/dev/elixir/sys
cd "$REPO"

echo "[$(date -Is)] running gleam fmt + test before commit"
cd scripts
nix develop ../ --quiet --command gleam format src test
nix develop ../ --quiet --command gleam test 2>&1 | tail -5
cd "$REPO"

echo
echo "[$(date -Is)] git status"
git status --short

echo
echo "[$(date -Is)] staging"
git add -A

echo
echo "--- staged ---"
git diff --cached --stat

echo
echo "[$(date -Is)] commit"
git commit -m 'chore: organise docs + nix-configs skeleton, pnpm-manage skillfish

- move nas1-hardware-analysis.md and nixos-k8s-plan.md into docs/
  with an index and a Status header in each; AGENTS.md now shows the
  repo layout.
- scaffold nix-configs/ (hosts/nas1, k3s, modules) matching the K3s
  plan. READMEs only for now; Nix modules come when Phase 1 starts.
- switch skillfish to pnpm under the Nix-pinned toolchain: drop the
  npm-installed node_modules/package-lock.json, add a proper
  package.json with packageManager pin + node engine, commit
  pnpm-lock.yaml.
- document skill authoring / third-party install workflow in
  .pi/skills/README.md; we do not use skillfish bundle/install for
  our own skills (git is the source of truth).
- .gitignore: cover .pnpm-store, package-lock.json, yarn.lock, .claude/'

echo
git log --oneline -n 5
