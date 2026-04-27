#!/bin/bash
# Lenient verify script (no pipefail) so grep/head early-exits don't nuke
# the run. Every section is a separate subshell so one section's failure
# doesn't abort the rest.
set -u
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

OUT=/mnt/c/dev/elixir/sys/.pi/last-output.txt
: > "$OUT"

cd /mnt/c/dev/elixir/sys

run_section() {
  local title="$1"; shift
  {
    echo
    echo "=== $title ==="
    "$@" 2>&1
  } >> "$OUT"
}

filter_noise() {
  grep -vE 'sys devshell|^  gleam   :|^  erl     :|^  rustc   :|^  cargo   :|^  node    :|^  pnpm    :|^warning: Git tree|^    Compiled in|^    Running sys_scripts|^$'
}

run_section "git log" git log --oneline
run_section "git status" git status --short
run_section "gleam tests" bash -c '
  cd /mnt/c/dev/elixir/sys/scripts
  nix develop ../ --quiet --command gleam test 2>&1 | tail -5
'
run_section "cargo nextest" bash -c '
  cd /mnt/c/dev/elixir/sys
  nix develop --quiet --command cargo nextest run --workspace 2>&1 | tail -5
'
run_section "deploy plan nixos nix-k8s-master" bash -c '
  cd /mnt/c/dev/elixir/sys/scripts
  nix develop ../ --quiet --command gleam run -m sys_scripts -- deploy plan nixos nix-k8s-master 2>&1 |
    grep -vE "sys devshell|^  gleam   :|^  erl     :|^  rustc   :|^  cargo   :|^  node    :|^  pnpm    :|^warning: Git tree|^   Compiled in|^    Running sys_scripts|^$"
'
run_section "sysctl skills list (table)" bash -c '
  cd /mnt/c/dev/elixir/sys
  nix develop --quiet --command cargo run --quiet -p sysctl -- skills list 2>&1 |
    grep -vE "sys devshell|^  gleam   :|^  erl     :|^  rustc   :|^  cargo   :|^  node    :|^  pnpm    :|^warning: Git tree|^$"
'
run_section "sys doctor" bash -c '
  cd /mnt/c/dev/elixir/sys/scripts
  nix develop ../ --quiet --command gleam run -m sys_scripts -- doctor 2>&1 |
    grep -vE "sys devshell|^  gleam   :|^  erl     :|^  rustc   :|^  cargo   :|^  node    :|^  pnpm    :|^warning: Git tree|^   Compiled in|^    Running sys_scripts|^$" |
    tail -30
'
