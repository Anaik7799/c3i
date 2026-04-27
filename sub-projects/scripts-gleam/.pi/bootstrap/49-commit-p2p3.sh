#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/49-commit-p2p3.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys

echo "[$(date -Is)] gleam fmt"
cd scripts && nix develop ../ --quiet --command gleam format src test && cd ..

echo
echo "[$(date -Is)] sys check (full, with nix eval against new modules)"
cd scripts
nix develop ../ --quiet --command gleam run -m sys_scripts -- check 2>&1 | tail -10
cd ..

echo
echo "[$(date -Is)] staging"
git add \
  nix-configs/inventory.nix \
  nix-configs/modules/tailscale.nix \
  nix-configs/modules/deploy.nix \
  nix-configs/hosts/nas1/nix-k8s-master/configuration.nix \
  nix-configs/hosts/nas1/nix-k8s-worker-1/configuration.nix \
  nix-configs/hosts/nas1/nix-k8s-worker-2/configuration.nix \
  flake.nix \
  scripts/src/sys_scripts.gleam \
  scripts/src/sys_scripts/commands/inventory.gleam \
  scripts/src/sys_scripts/commands/secrets.gleam \
  scripts/src/sys_scripts/commands/deploy.gleam \
  scripts/src/sys_scripts/commands/doctor.gleam \
  scripts/test/sys_scripts_test.gleam \
  .pi/bootstrap/48-p2p3-commands.sh \
  .pi/bootstrap/49-commit-p2p3.sh

echo
echo "--- staged stat ---"
git diff --cached --stat

git commit -m 'feat: inventory + tailscale + sys {inventory,secrets} commands

- nix-configs/inventory.nix: single source of truth for host IPs
  (lan + tailscale), roles, ssh endpoints, plus hypervisor catalog.
  All nulls today (P1/P2 pending); values populate when VMs exist.
  Exposed via flake as `lib.inventory` so Gleam can read it with
  `nix eval .#lib.inventory --json`.
- nix-configs/modules/tailscale.nix: declares sys.tailscale.{enable,
  authKeyFile, tags, advertiseRoutes, ssh, acceptDns}. Wraps
  services.tailscale with sensible defaults. Every host now imports
  it with `enable = true`, authKeyFile deferred to P3.
- nix-configs/modules/deploy.nix: now accepts `inventory` via the
  function head; `sys.deploy.targetHost` defaults from
  `inventory.hosts.<this>.tailscaleAddr` (preferred) or `.lanAddr`
  (fallback) when `sys.deploy.useInventory = true`. Explicit
  assignment still wins.
- flake.nix: passes inventory as `specialArgs` to every
  nixosConfiguration; exposes `lib.inventory` output so Gleam can
  read it.
- scripts/src/sys_scripts/commands/inventory.gleam: `sys inventory
  list / show <name> / ping`. Reads .#lib.inventory, pretty-prints
  JSON. ping stub deferred until hosts have tailscale addrs. Wired
  into dispatcher + 2 parse tests. 27/27 gleam tests passing.
- scripts/src/sys_scripts/commands/secrets.gleam: `sys secrets
  list / validate / edit <file> / get kubeconfig`. Wraps sops CLI;
  kubeconfig extraction rewrites server URL placeholder. Wired into
  dispatcher + parse tests.
- Every `shellout.command(run: "sh", ...)` → `run: "bash"` across
  5 modules. Ubuntu'"'"'s /bin/sh → dash, which lacks `set -o pipefail`,
  which our nix-eval-with-jq pipelines all use. Bash is universal.

All 6 sys check steps pass; `nix eval` includes the new tailscale
and inventory modules across every nixosConfiguration.'

echo
echo "[$(date -Is)] push"
git push origin main

echo
echo "[$(date -Is)] log"
git log --oneline | head -5
