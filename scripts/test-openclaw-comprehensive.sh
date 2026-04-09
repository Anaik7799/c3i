#!/usr/bin/env bash
# Comprehensive OpenClaw Interaction Test Suite
# Runs simulator + cortex daemon + 6-phase test covering all OpenClaw capabilities
# STAMP: SC-SIM-001, SC-COG-001, SC-ZMOF-001
# Usage: ./scripts/test-openclaw-comprehensive.sh [duration_secs]

set -euo pipefail

DURATION="${1:-300}"  # Default 5 minutes
PORT=9999
DAEMON="./sub-projects/c3i/target/release/sa-plan-daemon"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  OPENCLAW COMPREHENSIVE TEST SUITE                        ║"
echo "║  Duration: ${DURATION}s | Port: ${PORT}                   ║"
echo "╚═══════════════════════════════════════════════════════════╝"

# Check binary exists
if [ ! -f "$DAEMON" ]; then
    echo "❌ sa-plan-daemon not found. Building..."
    cd sub-projects/c3i/native/planning_daemon && cargo build --release && cd -
fi

# Run the sim-test subcommand
exec "$DAEMON" sim-test --port "$PORT" --duration-secs "$DURATION"
