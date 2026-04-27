#!/bin/bash
set -euo pipefail

OUT=/mnt/c/dev/elixir/sys/.pi/last-output.txt
: > "$OUT"

cd /mnt/c/dev/elixir/sys

{
  echo '=== before ==='
  ls -la ./\` 2>&1 || true

  echo
  echo '=== git rm the backtick file ==='
  git rm -- ./\`

  echo
  echo '=== status ==='
  git status --short

  echo
  echo '=== commit ==='
  git commit -m 'chore: remove stray backtick file (leftover from early probe)'

  echo
  echo '=== log ==='
  git log --oneline -n 5
} >> "$OUT" 2>&1
