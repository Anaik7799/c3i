#!/bin/bash
# Enable direnv for root's bash inside WSL Ubuntu.
# After this, cd'ing into /mnt/c/dev/elixir/sys auto-enters the flake devshell
# (the first time you enter it, direnv asks to `direnv allow` — we do that here).
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/09-direnv.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

# 1. Install direnv into root's nix profile so it's always on PATH
#    (independent of the project devshell).
echo "[$(date -Is)] ensuring direnv in root's nix profile"
if ! command -v direnv >/dev/null 2>&1; then
  nix profile install nixpkgs#direnv
else
  echo "  already installed: $(command -v direnv) $(direnv --version)"
fi

# 2. Wire the shell hook into /root/.bashrc (idempotent).
echo "[$(date -Is)] wiring direnv hook into /root/.bashrc"
HOOK_MARKER='# >>> sys direnv hook (managed by pi bootstrap) >>>'
if ! grep -qF "$HOOK_MARKER" /root/.bashrc 2>/dev/null; then
  cat >> /root/.bashrc <<'EOF'

# >>> sys direnv hook (managed by pi bootstrap) >>>
# Nix profile needs to be sourced before direnv can find `nix`
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix.sh ]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
fi
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook bash)"
fi
# <<< sys direnv hook (managed by pi bootstrap) <<<
EOF
  echo "  hook appended"
else
  echo "  hook already present"
fi

# 3. Allow the project's .envrc once.
echo "[$(date -Is)] direnv allow /mnt/c/dev/elixir/sys"
cd /mnt/c/dev/elixir/sys
direnv allow .

# 4. Sanity: run direnv exec and confirm it activates the devshell.
echo "[$(date -Is)] verifying direnv exec produces the devshell PATH"
direnv exec . bash -c 'command -v gleam && gleam --version'

echo "[$(date -Is)] done"
