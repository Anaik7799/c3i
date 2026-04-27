#!/bin/bash
set -u
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

OUT=/mnt/c/dev/elixir/sys/.pi/last-output.txt
: > "$OUT"

cd /mnt/c/dev/elixir/sys

{
  echo '=== git log (full session) ==='
  git log --oneline
  echo
  echo '=== tree structure ==='
  git ls-tree --name-only HEAD | sort
  echo
  echo '=== test counts ==='
  echo -n 'gleam: '
  cd scripts && nix develop ../ --quiet --command gleam test 2>&1 | grep 'passed' | tail -1 && cd ..
  echo -n 'rust:  '
  nix develop --quiet --command cargo nextest run --workspace 2>&1 | grep Summary | tail -1
  echo
  echo '=== sys check (final full run) ==='
  cd scripts
  nix develop ../ --quiet --command gleam run -m sys_scripts -- check 2>&1 | tail -10
  cd ..
  echo
  echo '=== sys commands available ==='
  cd scripts
  nix develop ../ --quiet --command gleam run -m sys_scripts -- help 2>&1 | \
    grep -E '  [a-z]' | grep -vE 'sys devshell|gleam   :|erl     :|rustc   :|cargo   :|node    :|pnpm    :'
  cd ..
  echo
  echo '=== inventory snapshot ==='
  cd scripts
  nix develop ../ --quiet --command gleam run -m sys_scripts -- inventory list 2>&1 | \
    grep -vE 'sys devshell|gleam   :|erl     :|rustc   :|cargo   :|node    :|pnpm    :|warning: Git|Compiled in|Running sys_scripts' | \
    head -40
  cd ..
  echo
  echo '=== files tracked (count) ==='
  git ls-files | wc -l
} >> "$OUT" 2>&1
