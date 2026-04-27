#!/bin/bash
# Initialise the repo and produce the first commit.
#
# Steps:
#   1. Delete scripts/.git (stray from `gleam new` — never wanted)
#   2. Ensure .gitignore covers everything that shouldn't be tracked
#   3. git init at repo root (idempotent)
#   4. git config user.name/user.email if unset (local to this repo)
#   5. git add -A; status; commit
#   6. Print resulting log + stats
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/13-git-init.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

REPO=/mnt/c/dev/elixir/sys
cd "$REPO"

echo "[$(date -Is)] cleanup nested scripts/.git"
rm -rf scripts/.git

# Also remove any stray build artefacts from prior runs so they don't clutter
# the first commit (they're already gitignored but this keeps things tidy).
rm -f erl_crash.dump
rm -f scripts/erl_crash.dump

echo "[$(date -Is)] init"
if [ ! -d .git ]; then
  git init -b main
else
  echo "  (already a git repo)"
fi

echo "[$(date -Is)] ensure local user config"
if ! git config user.email >/dev/null; then
  git config user.email "abhij@local"
fi
if ! git config user.name >/dev/null; then
  git config user.name "abhij"
fi

echo "[$(date -Is)] stage & summarise"
git add -A
echo "--- git status --short ---"
git status --short
echo
echo "--- file count ---"
git diff --cached --numstat | wc -l
echo

# Abort if there's nothing to commit (idempotent re-run).
if git diff --cached --quiet; then
  echo "[skip] nothing staged (already committed?)"
  git log --oneline -n 5 || true
  exit 0
fi

echo "[$(date -Is)] commit"
git commit -m 'feat: nix-managed polyglot workspace + gleam-only scripts

- flake.nix pins gleam 1.15, erlang/OTP 27, rust 1.95, node 22, pnpm,
  rebar3, elixir 1.17, plus general dev tooling (git, gh, rg, fd, jq,
  just, direnv). rust-overlay honours rust-toolchain.toml when present.
- .envrc + direnv hook in root shell: cd auto-enters the devshell.
- .pi/ holds pi-agent project config:
    * settings.json wires shellCommandPrefix to load nix on every bash.
    * shell-init.sh exposes `in-shell <cmd>` helper.
    * skills/ holds 8 workspace-scoped skills (unpacked from .skill zips):
      fp-refactor, hyper-mgmt, nix-lang-master, nixos-architect, nixos-k8s,
      nixpkgs-contributor, pi-mono-agent, podman-master.
    * bootstrap/ one-shot scripts (gitignored); pre-Gleam only.
- scripts/ is the Gleam project that owns ALL workspace automation.
  entry: gleam run -m sys_scripts -- <cmd>
  commands: doctor, fmt, test, deploy, help
  23 tests (example + qcheck property tests) passing.
- AGENTS.md documents the runtime setup + known pi/WSL quirks so future
  sessions dont repeat the debugging.'

echo
echo "=== final log ==="
git log --oneline -n 10
echo
echo "=== tree stats ==="
git ls-files | wc -l
echo "tracked files"
