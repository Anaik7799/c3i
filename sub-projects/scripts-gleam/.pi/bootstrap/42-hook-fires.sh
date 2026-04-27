#!/bin/bash
# Prove the pre-commit hook actually rejects broken code.
set -uo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

OUT=/mnt/c/dev/elixir/sys/.pi/last-output.txt
: > "$OUT"

cd /mnt/c/dev/elixir/sys

{
  echo '=== break something (mis-indent a gleam file) ==='
  orig=$(cat crates/sysctl/src/error.rs)
  # Append a line that's valid-but-needs-formatting (extra blank lines).
  printf '\n\n\n' >> crates/sysctl/src/error.rs

  echo '=== attempt commit (should fail: cargo fmt --check) ==='
  git add crates/sysctl/src/error.rs
  if git commit -m 'this should not succeed' 2>&1; then
    echo 'XXX BUG: commit succeeded despite broken formatting'
  else
    echo '(commit rejected as expected)'
  fi

  echo
  echo '=== restore file, unstage ==='
  printf '%s' "$orig" > crates/sysctl/src/error.rs
  git reset HEAD crates/sysctl/src/error.rs

  echo
  echo '=== git status after restore (should be clean of staged changes) ==='
  git status --short
} >> "$OUT" 2>&1
