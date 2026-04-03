#!/usr/bin/env bash
# Sentinel+Zenoh MCP Server launcher
# Resolves DOTNET_ROOT dynamically from PATH (nix-stable)
# Required because `dotnet run`/`dotnet exec` swap stdout/stderr on .NET 10
#
# Usage: ./run-mcp.sh              (stdio MCP server)
#        ./run-mcp.sh --build      (rebuild then run)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
BIN="$SCRIPT_DIR/bin/Release/net10.0/cepaf-sentinel-mcp"

# Build if binary missing or --build flag
if [ ! -f "$BIN" ] || [ "${1:-}" = "--build" ]; then
    dotnet build "$SCRIPT_DIR/Cepaf.Sentinel.MCP.fsproj" -c Release --verbosity quiet >&2
    [ "${1:-}" = "--build" ] && shift
fi

# Resolve DOTNET_ROOT from `dotnet` on PATH (nix-friendly)
export DOTNET_ROOT="${DOTNET_ROOT:-$(dirname "$(readlink -f "$(which dotnet)")")}"

# Zenoh FFI library
export LD_LIBRARY_PATH="${PROJECT_ROOT}/target/release:${LD_LIBRARY_PATH:-}"
export ZENOH_USE_NATIVE="${ZENOH_USE_NATIVE:-true}"

exec "$BIN" "$@"
