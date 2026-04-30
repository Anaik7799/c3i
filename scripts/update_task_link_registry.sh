#!/usr/bin/env bash
# update_task_link_registry.sh — refresh task-{id}-links.json per SC-FRACTAL-AUTO-001
# STAMP: SC-FRACTAL-AUTO-001, SC-FEAT-EVO-010, SC-FEAT-EVO-011
# ZK: [zk-3346fc607a1ef9e6] (no Stub-That-Lies — actual file enumeration)
#
# Walks docs/journal/, docs/screenshots/, docs/analysis/ for files that
# reference the task-id and writes a JSON registry.
#
# Usage: ./scripts/update_task_link_registry.sh <task-id>
set -euo pipefail

TASK_ID="${1:-}"
if [ -z "$TASK_ID" ]; then
  echo "Usage: $0 <task-id>" >&2
  exit 1
fi

ROOT=/home/an/dev/ver/c3i
REGISTRY="$ROOT/docs/journal/task-${TASK_ID}-links.json"
TAILSCALE_BASE="https://vm-1.tail55d152.ts.net:8443/task-id/$TASK_ID"

echo "=== update_task_link_registry $TASK_ID ==="
cd "$ROOT"

# Find all files referencing the task id
RELATED=$(grep -rln "$TASK_ID" docs/ 2>/dev/null | head -50 || true)

# Generate JSON registry via inline python
python3 -c "
import json, os, sys, glob, time
tid = '$TASK_ID'
tailscale = '$TAILSCALE_BASE'
root = '$ROOT'
related = []
for d in ('docs/journal', 'docs/screenshots', 'docs/analysis', 'docs/spec'):
    for path in glob.glob(root + '/' + d + '/**/*', recursive=True):
        if os.path.isfile(path):
            try:
                with open(path, errors='ignore') as f:
                    if tid in f.read(50000):
                        rel = path.replace(root + '/', '')
                        related.append({
                            'path': rel,
                            'tailscale': 'https://vm-1.tail55d152.ts.net:8443/' + rel,
                            'size_bytes': os.path.getsize(path),
                        })
            except Exception:
                pass
out = {
    'task_id': tid,
    'tailscale_url': tailscale,
    'generated_at_unix': int(time.time()),
    'related_artifacts': sorted(related, key=lambda x: x['path']),
    'artifact_count': len(related),
}
print(json.dumps(out, indent=2))
" > "$REGISTRY" || { echo "registry write failed"; exit 2; }

echo "  → $REGISTRY ($(jq '.artifact_count' "$REGISTRY" 2>/dev/null || echo "?") artifacts)"
