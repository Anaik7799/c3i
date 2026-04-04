#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# Indrajaal ELIXIR_ERL_OPTIONS +fnu Checker - Shell Wrapper
# ═══════════════════════════════════════════════════════════════════════════
#
# Usage:
#   ./check-env.sh                    # Check with defaults
#   ./check-env.sh --fix              # Auto-fix violations
#   ./check-env.sh --json            # JSON output
#   ./check-env.sh --github           # GitHub Actions format
#   ./check-env.sh scripts/          # Check specific directory
#
# Exit codes:
#   0 - All checks passed
#   1 - Violations found
#   2 - Error
#
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER_BIN="${CHECKER_BIN:-target/release/indrajaal-env-checker}"

# Default settings
MODE="strict"
FORMAT="text"
PATH="."
FIX="no"
QUIET="no"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --fix|-f)
            FIX="yes"
            shift
            ;;
        --json|-j)
            FORMAT="json"
            shift
            ;;
        --compact|-c)
            FORMAT="compact"
            shift
            ;;
        --github|-g)
            FORMAT="github"
            shift
            ;;
        --quiet|-q)
            QUIET="yes"
            shift
            ;;
        --help|-h)
            echo "Indrajaal ELIXIR_ERL_OPTIONS +fnu Checker"
            echo ""
            echo "Usage: $0 [OPTIONS] [PATH]"
            echo ""
            echo "Options:"
            echo "  --fix, -f       Auto-fix violations"
            echo "  --json, -j      JSON output"
            echo "  --compact, -c   Compact output"
            echo "  --github, -g   GitHub Actions format"
            echo "  --quiet, -q    Quiet mode"
            echo "  --help, -h      Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                    # Check current directory"
            echo "  $0 scripts/          # Check scripts directory"
            echo "  $0 --fix              # Auto-fix all violations"
            echo "  $0 --github           # CI/CD integration"
            exit 0
            ;;
        *)
            PATH="$1"
            shift
            ;;
    esac
done

# Build if needed
if [[ ! -f "$CHECKER_BIN" ]]; then
    echo "Building indrajaal-env-checker..."
    cd "$SCRIPT_DIR/src/rust/indrajaal_env_checker"
    cargo build --release 2>/dev/null || cargo build
    CHECKER_BIN="$SCRIPT_DIR/src/rust/indrajaal_env_checker/target/release/indrajaal-env-checker"
fi

# Build command
CMD=("$CHECKER_BIN" --path "$PATH" --format "$FORMAT")

if [[ "$FIX" == "yes" ]]; then
    CMD+=(--fix)
fi

if [[ "$QUIET" == "yes" ]]; then
    CMD+=(--quiet)
fi

# Run checker
exec "${CMD[@]}"
