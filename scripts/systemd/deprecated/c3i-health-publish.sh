#!/usr/bin/env bash
# C3I service health probe → docs/health/services.json
# Publishes systemctl --user state for all c3i-* units.
# Per SC-SATYA-001 (display=truth): only observed state, never inferred.
set -euo pipefail

HEALTH_FILE="/home/an/dev/ver/c3i/docs/health/services.json"
TMP="${HEALTH_FILE}.tmp"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

emit_unit() {
  local u="$1"
  local active enabled load_state sub_state mem_kb cpu_pct rc=0
  active=$(systemctl --user is-active "$u" 2>/dev/null) || rc=$?
  enabled=$(systemctl --user is-enabled "$u" 2>/dev/null) || true
  load_state=$(systemctl --user show "$u" -p LoadState --value 2>/dev/null || echo unknown)
  sub_state=$(systemctl --user show "$u" -p SubState --value 2>/dev/null || echo unknown)
  mem_kb=$(systemctl --user show "$u" -p MemoryCurrent --value 2>/dev/null || echo 0)
  if [ "$mem_kb" = "[not set]" ] || [ -z "$mem_kb" ] || ! [[ "$mem_kb" =~ ^[0-9]+$ ]]; then mem_kb=0; fi
  cpu_pct=$(systemctl --user show "$u" -p CPUUsageNSec --value 2>/dev/null || echo 0)
  if [ -z "$cpu_pct" ] || [ "$cpu_pct" = "[not set]" ] || ! [[ "$cpu_pct" =~ ^[0-9]+$ ]]; then cpu_pct=0; fi
  printf '    {"unit":"%s","active":"%s","enabled":"%s","load":"%s","sub":"%s","memory_bytes":%s,"cpu_nsec":%s}' \
    "$u" "$active" "$enabled" "$load_state" "$sub_state" "$mem_kb" "$cpu_pct"
}

# Load average and total CPU (proc/stat snapshot — non-blocking)
LOAD=$(cut -d' ' -f1-3 /proc/loadavg)
NCPU=$(nproc)
norm() { local v="$1"; if [ -z "$v" ] || [ "$v" = "[not set]" ] || ! [[ "$v" =~ ^[0-9]+$ ]]; then echo 0; else echo "$v"; fi; }
SLICE_CPU_NSEC=$(norm "$(systemctl --user show c3i.slice -p CPUUsageNSec --value 2>/dev/null)")
SLICE_MEM=$(norm "$(systemctl --user show c3i.slice -p MemoryCurrent --value 2>/dev/null)")

UNITS=$(systemctl --user list-units --type=service --all --no-legend --plain 2>/dev/null \
  | awk '{print $1}' | grep -E '^c3i-.*\.service$' | sort)

{
  printf '{\n'
  printf '  "ts": "%s",\n' "$TS"
  printf '  "host": "%s",\n' "$(hostname -s)"
  printf '  "ncpu": %s,\n' "$NCPU"
  printf '  "loadavg": "%s",\n' "$LOAD"
  printf '  "slice_cpu_nsec": %s,\n' "$SLICE_CPU_NSEC"
  printf '  "slice_memory_bytes": %s,\n' "$SLICE_MEM"
  printf '  "units": [\n'
  first=1
  while read -r u; do
    [ -z "$u" ] && continue
    if [ $first -eq 0 ]; then printf ',\n'; fi
    emit_unit "$u"
    first=0
  done <<< "$UNITS"
  printf '\n  ]\n'
  printf '}\n'
} > "$TMP"

mv "$TMP" "$HEALTH_FILE"

# G5: publish to Zenoh topics (depends on G4 — REST :8000 reachable via --net=host)
ZENOH=http://127.0.0.1:8000
if curl -fsS --max-time 1 -X PUT "${ZENOH}/indrajaal/l2/health/snapshot" --data-binary @"$HEALTH_FILE" >/dev/null 2>&1; then
  python3 - <<PYEND 2>/dev/null || true
import json, urllib.request
d = json.load(open("$HEALTH_FILE"))
for u in d.get("units", []):
    name = u["unit"].replace(".service", "")
    base = "$ZENOH/indrajaal/l2/health/" + name
    pairs = [("state", u.get("active", "")),
             ("memory_bytes", str(u.get("memory_bytes", 0))),
             ("cpu_nsec", str(u.get("cpu_nsec", 0)))]
    for key, val in pairs:
        try:
            req = urllib.request.Request(base + "/" + key, data=str(val).encode(), method="PUT")
            urllib.request.urlopen(req, timeout=1)
        except Exception:
            pass
PYEND
fi
