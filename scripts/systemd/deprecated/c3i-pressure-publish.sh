#!/usr/bin/env bash
# G6: PSI memory-pressure publisher with Lyapunov hysteresis
# Reads /sys/fs/cgroup/.../c3i.slice/memory.pressure → publishes to indrajaal/l4/system/pressure
#
# V(t) = avg10_full from PSI
# θ_low  = 0.5  → Nominal      → RETE D14 fires FullSpeed
# θ_high = 5.0  → HighPressure  → RETE D14 fires HeavyThrottle
# θ_crit = 20.0 → Critical      → emergency throttle
#
# Hysteresis gap Δ = θ_high - θ_low = 4.5 prevents oscillation.
# Stability: dV/dt × T_r < Δ; at observed 0.001 unit/s × 5 s response = 0.005 < 4.5 ✓
set -euo pipefail

PSI=/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/c3i.slice/memory.pressure
ZENOH=http://127.0.0.1:8000
PRESSURE_TOPIC=indrajaal/l4/system/pressure
LEVEL_TOPIC=indrajaal/l4/system/pressure_level
HYSTERESIS=/tmp/c3i-pressure-state

if [ ! -r "$PSI" ]; then
  echo "PSI file not readable: $PSI" >&2
  exit 0  # not a hard failure; cgroup may not have PSI yet
fi

# Parse "full avg10=N.NN avg60=... avg300=... total=..."
AVG10=$(awk '/^full/ { for (i=2;i<=NF;i++) if ($i ~ /^avg10=/) { gsub("avg10=","",$i); print $i } }' "$PSI")
AVG60=$(awk '/^full/ { for (i=2;i<=NF;i++) if ($i ~ /^avg60=/) { gsub("avg60=","",$i); print $i } }' "$PSI")

# Hysteresis: read previous level
PREV_LEVEL=Nominal
[ -f "$HYSTERESIS" ] && PREV_LEVEL=$(cat "$HYSTERESIS")

# Decision tree with hysteresis
LEVEL=$(awk -v v="$AVG10" -v p="$PREV_LEVEL" 'BEGIN{
  if (v > 20.0) { print "Critical"; exit }
  if (v > 5.0)  { print "HighPressure"; exit }
  # Hysteresis: only return to Nominal when below 0.5 (not just below 5.0)
  if (p == "HighPressure" && v > 0.5) { print "HighPressure"; exit }
  if (p == "Critical" && v > 5.0)     { print "HighPressure"; exit }
  print "Nominal"
}')

# Publish to Zenoh
PAYLOAD=$(printf '{"level":"%s","avg10":%s,"avg60":%s,"ts":"%s"}' \
  "$LEVEL" "$AVG10" "$AVG60" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")
curl -fsS --max-time 1 -X PUT "${ZENOH}/${PRESSURE_TOPIC}" --data-binary "$PAYLOAD" >/dev/null 2>&1 || true
curl -fsS --max-time 1 -X PUT "${ZENOH}/${LEVEL_TOPIC}" --data-binary "$LEVEL" >/dev/null 2>&1 || true

# Persist for hysteresis next iteration
echo "$LEVEL" > "$HYSTERESIS"

# Emergency action: if Critical and previous was also Critical (sustained), kill highest OOM
if [ "$LEVEL" = "Critical" ] && [ "$PREV_LEVEL" = "Critical" ]; then
  HIGHEST_OOM_UNIT=$(systemctl --user list-units --type=service --no-legend --plain 2>/dev/null \
    | awk '{print $1}' | grep '^c3i-' | while read -r u; do
        oom=$(systemctl --user show "$u" -p OOMScoreAdjust --value 2>/dev/null)
        echo "$oom $u"
      done | sort -rn | head -1 | awk '{print $2}')
  if [ -n "$HIGHEST_OOM_UNIT" ]; then
    logger -t c3i-pressure "EMERGENCY: sustained Critical pressure, restarting $HIGHEST_OOM_UNIT"
    systemctl --user restart "$HIGHEST_OOM_UNIT" 2>/dev/null || true
  fi
fi

echo "$LEVEL avg10=$AVG10 avg60=$AVG60"
