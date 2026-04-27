#!/bin/bash
set -euo pipefail

OUT=/mnt/c/dev/elixir/sys/.pi/last-output.txt
: > "$OUT"

STAGE=/tmp/skill-probe
rm -rf "$STAGE"
mkdir -p "$STAGE"

for f in /mnt/c/dev/elixir/sys/*.skill; do
  b=$(basename "$f" .skill)
  d="$STAGE/$b"
  mkdir -p "$d"
  unzip -qq -o -d "$d" "$f"
  {
    echo "=== $b ==="
    echo "-- files --"
    (cd "$d" && find . -type f | sort)
    echo "-- front-matter --"
    awk '/^---$/{c++; next} c==1{print}' "$d/SKILL.md"
    echo
  } >> "$OUT"
done
