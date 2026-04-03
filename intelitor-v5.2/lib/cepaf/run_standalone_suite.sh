#!/usr/bin/env bash
# CEPAF Standalone Test Suite Runner
# STAMP: SC-CEP-001 (Locality), SC-OBS-069 (Dual Logging)
set -e

# Environment configurations
DB_TEST_ENVS=("DEV" "TEST" "DEMO" "PROD" "SYSTEM_STANDALONE_DB_TEST" "MESH")
OBS_TEST_ENVS=("SYSTEM_STANDALONE_OBS_TEST")
ALL_ENVS=("${DB_TEST_ENVS[@]}" "${OBS_TEST_ENVS[@]}")

# Paths (SC-CEP-001 Compliant)
DLL="lib/cepaf/src/Cepaf/bin/Release/net8.0/Cepaf.dll"
LOG_DIR="lib/cepaf/artifacts"

mkdir -p "$LOG_DIR"

run_db_tests() {
    echo "=== Database Standalone Tests ==="
    for env in "${DB_TEST_ENVS[@]}"; do
        echo "Testing environment: $env"
        # Sterilize containers
        podman ps -aq --filter "label=project=intelitor" | xargs -r podman rm -f || true

        # Run DB test
        devenv shell -- "dotnet exec $DLL --no-build -e $env -d" > "$LOG_DIR/${env,,}_db_test.log" 2>&1 || true
        echo "Completed $env - Log: $LOG_DIR/${env,,}_db_test.log"
    done
}

run_obs_tests() {
    echo "=== Observability Standalone Tests ==="
    for env in "${OBS_TEST_ENVS[@]}"; do
        echo "Testing environment: $env"
        # Sterilize containers
        podman ps -aq --filter "label=project=intelitor" | xargs -r podman rm -f || true

        # Run OBS test
        devenv shell -- "dotnet exec $DLL --no-build -e $env -o" > "$LOG_DIR/${env,,}_obs_test.log" 2>&1 || true
        echo "Completed $env - Log: $LOG_DIR/${env,,}_obs_test.log"
    done
}

run_all_tests() {
    run_db_tests
    run_obs_tests
}

# Parse arguments
case "${1:-all}" in
    db)
        run_db_tests
        ;;
    obs)
        run_obs_tests
        ;;
    all)
        run_all_tests
        ;;
    *)
        echo "Usage: $0 [db|obs|all]"
        echo "  db  - Run database standalone tests"
        echo "  obs - Run observability standalone tests"
        echo "  all - Run all tests (default)"
        exit 1
        ;;
esac

echo "=== All tests completed. Logs in: $LOG_DIR ==="
