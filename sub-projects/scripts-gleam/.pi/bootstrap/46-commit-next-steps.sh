#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/46-commit-next-steps.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys

echo "[$(date -Is)] status"
git status --short

echo
echo "[$(date -Is)] staging"
git add \
  .github/workflows/check.yml \
  .gitignore \
  flake.nix flake.lock \
  nix-configs/modules/deploy.nix \
  nix-configs/modules/secrets.nix \
  nix-configs/hosts/nas1/nix-k8s-master/configuration.nix \
  nix-configs/hosts/nas1/nix-k8s-worker-1/configuration.nix \
  nix-configs/hosts/nas1/nix-k8s-worker-2/configuration.nix \
  nix-configs/k3s/server.nix \
  scripts/src/sys_scripts/commands/deploy.gleam \
  scripts/test/sys_scripts_test.gleam \
  .pi/bootstrap/43-apply-backend.sh \
  .pi/bootstrap/44-apply-happy-path.sh \
  .pi/bootstrap/45-full-integration.sh \
  .pi/bootstrap/46-commit-next-steps.sh

echo
echo "--- staged stat ---"
git diff --cached --stat

# Pre-commit hook will run sys check --fast; we want it to because it
# validates everything we just changed.
git commit -m 'feat: ci + deploy apply + sops-nix + dispatcher guard

- `deploy apply nixos <host>`: real SSH backend that reads
  sys.deploy.targetHost from the flake, validates it is set, and
  shells out to `nixos-rebuild {switch|dry-run} --flake .#<host>
  --target-host <addr> --use-remote-sudo`. --dry-run is default;
  --execute flips to switch. Added nixos-rebuild + openssh to the
  devshell so the deploy tool has everything it needs.
- modules/deploy.nix: declares sys.deploy.targetHost option
  (nullOr str, default null) and is imported by every host.
- modules/secrets.nix: scaffolds sops-nix — declares sys.secrets
  enable flag, wires age key from the host ssh_host_ed25519_key.
  Host configs comment out the real sops.secrets.k3s-token pending
  the first actual VM install.
- flake: sops-nix added as an input (nixpkgs-follows); every
  nixosConfiguration now imports sops-nix.nixosModules.sops.
- dispatcher: every_known_keyword_is_wired_test asserts that each
  documented CLI keyword parses to a non-Unknown Command. 25/25
  gleam tests pass.
- .github/workflows/check.yml: runs `sys check --fast` then
  `sys check` on push + PR. Uses the Determinate Nix installer +
  magic-nix-cache action. Dormant until origin is a real remote.
- .gitignore: exclude /secrets/ until a .sops.yaml policy is in
  place.

All 6 sys check steps green: gleam format/test, cargo fmt/clippy/
nextest, nix eval across devshell + 3 nixosConfigurations.'

echo
echo "[$(date -Is)] push"
git push origin main

echo
echo "[$(date -Is)] log"
git log --oneline | head -5
