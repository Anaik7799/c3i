#!/bin/bash
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

OUT=/mnt/c/dev/elixir/sys/.pi/last-output.txt
: > "$OUT"

cd /mnt/c/dev/elixir/sys

{
  echo '=== git log ==='
  git log --oneline | head -10
  echo
  echo '=== git status ==='
  git status --short
  echo
  echo '=== pending diffs (first 60 lines) ==='
  git diff | head -60
} >> "$OUT" 2>&1
