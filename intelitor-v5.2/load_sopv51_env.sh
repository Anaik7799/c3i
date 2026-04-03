#!/usr/bin/env bash
# SOPv5.1 Environment Loader
# Agent: Source this file to load all SOPv5.1 environment variables

echo "🚀 Loading SOPv5.1 environment..."
source /home/an/dev/elixir/ash/indrajaal-demo/.env.sopv51
echo "✅ SOPv5.1 environment loaded"
echo "  ELIXIR_ERL_OPTIONS: $ELIXIR_ERL_OPTIONS"
echo "  PHICS_ENABLED: $PHICS_ENABLED"
echo "  NO_TIMEOUT: $NO_TIMEOUT"
