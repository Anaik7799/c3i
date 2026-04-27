#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/35-commit-and-push.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

REPO=/mnt/c/dev/elixir/sys
cd "$REPO"

# Make sure everything is formatted before we snapshot.
echo "[$(date -Is)] gleam format"
cd scripts && nix develop ../ --quiet --command gleam format src test && cd ..
echo "[$(date -Is)] cargo fmt"
nix develop --quiet --command cargo fmt --all

echo
echo "[$(date -Is)] git status"
git status --short

# ---- Commit 1: deploy backend + runtime fixes + README ----
echo
echo "[$(date -Is)] stage commit #1 (deploy/runtime/docs)"
git add \
  scripts/src/sys_scripts/commands/deploy.gleam \
  .pi/shell-init.sh \
  README.md \
  .pi/bootstrap/28-final-verify.sh \
  .pi/bootstrap/29-deploy-plan-nixos.sh \
  .pi/bootstrap/30-deploy-plan-cleanup.sh \
  .pi/bootstrap/31-probe-nix-expr.sh \
  .pi/bootstrap/32-probe-simple.sh \
  .pi/bootstrap/33-state-probe.sh

echo "--- commit #1 stat ---"
git diff --cached --stat

git commit -m 'feat(deploy): real nix backend for `plan nixos <host>`

- `deploy plan nixos <host>` now evaluates the flake'"'"'s
  nixosConfigurations.<host> and prints hostName / system /
  stateVersion / k3s role / firewall ports as indented JSON.
  Implementation: one `nix eval --impure --json --expr` call with
  an inline projection expression, piped through `jq --indent 2`,
  stderr suppressed, `set -o pipefail` so pipeline exit reflects
  nix failures (jq-on-empty-stdin would otherwise succeed and mask
  them). Single invocation instead of 6 => no repeated dirty-tree
  warnings and ~5x faster on a cold nix eval cache.
- `deploy plan k8s <ns>` still stubbed (Phase 3 work).
- `.pi/shell-init.sh`: removed the `set +u` / `set -u` dance around
  the nix profile sourcing. Leaving `set -u` active at the end of
  shellCommandPrefix aborts user commands that reference any unset
  variable, which bit us hard with pi'"'"'s Windows->WSL env-var
  stripping quirk.
- README.md (root): human-facing overview complementing AGENTS.md
  (which is agent-facing). Quick-start, toolchain table,
  status/roadmap table.'

# ---- Commit 2: sysctl skills list ----
echo
echo "[$(date -Is)] stage commit #2 (sysctl skills)"
git add \
  crates/sysctl/src/main.rs \
  crates/sysctl/src/skills.rs \
  .pi/bootstrap/34-sysctl-skills.sh \
  .pi/bootstrap/35-commit-and-push.sh

echo "--- commit #2 stat ---"
git diff --cached --stat

git commit -m 'feat(sysctl): `skills list [--json]` subcommand

- New module crates/sysctl/src/skills.rs:
    * discover(root): walk immediate subdirectories, parse each
      SKILL.md front-matter, return Vec<Skill> sorted by name.
    * parse_front_matter: hand-rolled line-based parser for the
      ---/---YAML-ish block. Handles CRLF, ignores unknown keys,
      validates presence + non-empty `name` and `description`.
    * render_table / render_json for the two output modes.
- main.rs: new `Skills { action: SkillAction }` enum wired through
  clap; `list --root <dir> --json --desc-width N`.
- 13 new tests (example + proptest) covering the parser and
  truncator. cargo nextest: 23/23 passing workspace-wide.
- cargo clippy -D warnings clean (one round of write_literal
  fixup, wrote the literal into the format string directly).
- Live demo against .pi/skills/ returns all 8 installed skills
  with correct names and descriptions, in both table and JSON.'

# ---- Push ----
echo
echo "[$(date -Is)] push"
git push origin main

echo
echo "=== final log ==="
git log --oneline | head -10
