#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/47-commit-plans.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

cd /mnt/c/dev/elixir/sys

echo "[$(date -Is)] status"
git status --short

echo
echo "[$(date -Is)] sys check --fast"
cd scripts
nix develop ../ --quiet --command gleam run -m sys_scripts -- check --fast 2>&1 | tail -10
cd ..

echo
echo "[$(date -Is)] staging"
git add plans/ .pi/bootstrap/47-commit-plans.sh

echo
echo "--- staged stat ---"
git diff --cached --stat

git commit -m 'docs(plans): 5-level WBS + design + implementation + tests

Four cross-referenced planning docs landing under plans/:

- plans/README.md         navigation index, status tracker, conventions
- plans/plan.md           5-level WBS: mission > phases > workstreams >
                          tasks > subtasks. Every node has an ID of
                          the form P{phase}.W{ws}.T{task}.S{sub}.
- plans/design.md         architecture, rationale, trade-offs, rejected
                          alternatives. Answers *why*.
- plans/tests.md          layered test strategy (L1 unit > L2
                          integration > L3 system > L4 acceptance)
                          with exact commands and assertions per task.
- plans/implementation.md per-phase file edits and commands. Answers
                          *how*.

Phases covered:
  P1  NixOS install on 3 VMs (boot from ISO, land stub, commit
      hardware-configuration.nix back).
  P2  Tailscale mesh + inventory.nix (single source of truth for
      host addresses) + sys inventory subcommand.
  P3  sops-nix wired end-to-end (per-host + cluster-scope secrets,
      .sops.yaml policy, sys secrets subcommand).
  P4  K3s cluster formation via deploy apply, 3 Ready nodes,
      kubeconfig extraction.
  P5  Longhorn storage + ingress + first workload + GKE parity via
      kustomize overlays.

Scope out: workload code, GKE billing, day-2 ops, observability,
GitOps, backups, multi-cluster federation. All deferred and noted in
design.md.'

echo
echo "[$(date -Is)] push"
git push origin main

echo
echo "[$(date -Is)] log"
git log --oneline | head -5
