#!/usr/bin/env bash
# singularity_audit_loop.sh - Continuous Singularity Homeostasis Audit

# 1. Start F# Biomorphic Kernel
killall -9 dotnet fsi sa-mesh.fsx > /dev/null 2>&1 || true
dotnet fsi sa-mesh.fsx ignite > data/logs/ignite_loop.log 2>&1 &
IGNITE_PID=$!

echo "🚀 BIOMORPHIC KERNEL IGNITED (PID: $IGNITE_PID)"
echo "⏳ Waiting for stabilization..."
sleep 30

# 2. Continuous Audit Loop
ITERATION=1
while true; do
  clear
  echo "================================================================================"
  echo "   🌐 INDRAJAAL SINGULARITY AUDIT :: ITERATION $ITERATION"
  echo "================================================================================"
  
  echo -n "  [WebUI] singularity page: "
  curl -sf http://localhost:5000/singularity | grep -q "Singularity" && echo "✓ OK" || echo "✗ FAIL"
  
  echo -n "  [TUI]   render check:     "
  dotnet fsi test_singularity_tui.fsx | grep -q "100%" && echo "✓ OK" || echo "✗ FAIL"
  
  echo -n "  [AI]    authority topic:  "
  AI_DATA=$(curl -s http://localhost:8000/indrajaal/health/sentinel)
  if [ "$AI_DATA" != "[]" ] && [ -n "$AI_DATA" ]; then
    echo "✓ ONLINE"
    echo "    → $(echo $AI_DATA | jq -c '.[0].value // .')"
  else
    echo "✗ OFFLINE (Check ignite_loop.log)"
  fi

  echo -n "  [Swarm] homeostasis:      "
  HEALTH_DATA=$(curl -s http://localhost:8000/indrajaal/health/aggregate)
  if [ "$HEALTH_DATA" != "[]" ] && [ -n "$HEALTH_DATA" ]; then
    echo "✓ VERIFIED"
  else
    echo "⏳ PROBING..."
  fi

  echo ""
  elixir scripts/reporting/singularity_dashboard.exs | tail -n 15
  
  ITERATION=$((ITERATION + 1))
  sleep 10
done
