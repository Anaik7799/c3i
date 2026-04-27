#!/bin/bash
# Extract every *.skill zip at the repo root into .pi/skills/<name>/
# and remove the zip. Idempotent: re-running overwrites the extracted tree.
set -euo pipefail
source /mnt/c/dev/elixir/sys/.pi/shell-init.sh

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/11-install-skills.log
: > "$LOG"
exec > >(tee "$LOG") 2>&1

REPO=/mnt/c/dev/elixir/sys
DEST="$REPO/.pi/skills"
mkdir -p "$DEST"

shopt -s nullglob
archives=( "$REPO"/*.skill )
shopt -u nullglob

if [ ${#archives[@]} -eq 0 ]; then
  echo "[skip] no *.skill archives at repo root"
  exit 0
fi

for f in "${archives[@]}"; do
  name=$(basename "$f" .skill)
  target="$DEST/$name"
  echo "[install] $name -> $target"
  rm -rf "$target"
  mkdir -p "$target"
  unzip -qq -o -d "$target" "$f"
  # sanity: must contain SKILL.md with a 'name:' front-matter entry
  if ! grep -q '^name:' "$target/SKILL.md" 2>/dev/null; then
    echo "  ERROR: $target/SKILL.md missing or malformed"
    exit 1
  fi
  rm -f "$f"
done

echo
echo "=== installed skills ==="
for d in "$DEST"/*/; do
  n=$(basename "$d")
  desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$d/SKILL.md")
  printf '  %-22s %s\n' "$n" "${desc:0:80}"
done
