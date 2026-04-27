#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/44-apply-happy-path.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys

# Temporarily set a targetHost on the master so we can see the tool
# progress past the validation step. We'll restore afterwards.
CONFIG=/mnt/c/dev/elixir/sys/nix-configs/hosts/nas1/nix-k8s-master/configuration.nix
cp "$CONFIG" "$CONFIG.bak"

# Insert the targetHost before the closing brace.
python3 - <<'PY'
import re, pathlib
p = pathlib.Path('/mnt/c/dev/elixir/sys/nix-configs/hosts/nas1/nix-k8s-master/configuration.nix')
s = p.read_text()
insert = '  sys.deploy.targetHost = "root@10.99.99.99";\n'
# Insert right before the system.stateVersion line
s2 = re.sub(r'(\n\s*system\.stateVersion = "24\.05";\n)',
            '\n' + insert + r'\1', s, count=1)
assert s != s2, "sed replacement failed"
p.write_text(s2)
PY

echo "[$(date -Is)] updated config:"
grep -E 'sys\.deploy|stateVersion' "$CONFIG"

echo
echo "[$(date -Is)] gleam fmt"
cd scripts
nix develop ../ --quiet --command gleam format src test
nix develop ../ --quiet --command gleam test 2>&1 | tail -3
cd ..

echo
echo "[$(date -Is)] deploy apply nixos nix-k8s-master (expect reach nixos-rebuild then fail)"
cd scripts
# We expect this to fail at the nixos-rebuild step (either command-not-found
# inside the devshell, or ssh-no-such-host). Either way proves the wire-up.
nix develop ../ --quiet --command gleam run -m sys_scripts -- deploy apply nixos nix-k8s-master 2>&1 | \
  grep -vE '^sys devshell|^  gleam   :|^  erl     :|^  rustc   :|^  cargo   :|^  node    :|^  pnpm    :|^warning: Git tree|^   Compiled|^    Running|^$' || true
cd ..

echo
echo "[$(date -Is)] restoring config"
mv "$CONFIG.bak" "$CONFIG"
echo "[$(date -Is)] done"
