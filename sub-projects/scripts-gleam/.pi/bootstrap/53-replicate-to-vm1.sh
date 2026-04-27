#!/bin/bash
# Replicate the sys workspace's pi-agent setup to vm-1:/home/an/dev/ver/c3i/sub-projects/scripts-gleam
set -euo pipefail

SRC=/mnt/c/dev/elixir/sys
DEST=an@vm-1.tail55d152.ts.net:/home/an/dev/ver/c3i/sub-projects/scripts-gleam
PASS='!!779977!!'

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/53-replicate-to-vm1.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

echo "[$(date -Is)] creating backup of existing .pi on vm-1"
sshpass -p "$PASS" ssh an@vm-1.tail55d152.ts.net \
  "cd /home/an/dev/ver/c3i/sub-projects/scripts-gleam && mv .pi .pi.backup-\$(date +%Y%m%d-%H%M%S) 2>/dev/null || echo '(no existing .pi)'"

echo
echo "[$(date -Is)] copying .pi/"
sshpass -p "$PASS" scp -r "$SRC/.pi" "$DEST/"

echo
echo "[$(date -Is)] copying AGENTS.md, README, flake, .envrc"
sshpass -p "$PASS" scp \
  "$SRC/AGENTS.md" \
  "$SRC/README.md" \
  "$SRC/flake.nix" \
  "$SRC/flake.lock" \
  "$SRC/.envrc" \
  "$SRC/.gitignore" \
  "$DEST/"

echo
echo "[$(date -Is)] copying scripts/ source (not build artefacts)"
sshpass -p "$PASS" ssh an@vm-1.tail55d152.ts.net \
  "cd /home/an/dev/ver/c3i/sub-projects/scripts-gleam && rm -rf scripts.old && mv scripts scripts.old 2>/dev/null || true"
sshpass -p "$PASS" scp -r "$SRC/scripts" "$DEST/"
sshpass -p "$PASS" ssh an@vm-1.tail55d152.ts.net \
  "cd /home/an/dev/ver/c3i/sub-projects/scripts-gleam/scripts && rm -rf build _build"

echo
echo "[$(date -Is)] copying plans/, docs/, nix-configs/inventory.nix"
sshpass -p "$PASS" scp -r "$SRC/plans" "$SRC/docs" "$DEST/"
sshpass -p "$PASS" ssh an@vm-1.tail55d152.ts.net \
  "mkdir -p /home/an/dev/ver/c3i/sub-projects/scripts-gleam/nix-configs"
sshpass -p "$PASS" scp "$SRC/nix-configs/inventory.nix" \
  "$DEST/nix-configs/"

echo
echo "[$(date -Is)] fixing shell-init.sh path to match new location"
sshpass -p "$PASS" ssh an@vm-1.tail55d152.ts.net \
  "cd /home/an/dev/ver/c3i/sub-projects/scripts-gleam && sed -i 's|/mnt/c/dev/elixir/sys|/home/an/dev/ver/c3i/sub-projects/scripts-gleam|g' .pi/shell-init.sh .pi/settings.json"

echo
echo "[$(date -Is)] verify"
sshpass -p "$PASS" ssh an@vm-1.tail55d152.ts.net \
  "cd /home/an/dev/ver/c3i/sub-projects/scripts-gleam && ls -la"

echo
echo "[$(date -Is)] done"
