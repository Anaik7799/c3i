#!/bin/bash
# =============================================================================
# SOPv5.11 Chaos Test Suite
# =============================================================================
#
# STAMP Compliance:
# - SC-CNT-009: NixOS containers only
# - SC-CNT-014: Resource isolation maintained
# - AOR-CNT-001: Podman ONLY
#
# TDG: Tests container resilience under failure conditions
#
# Usage:
#   ./scripts/testing/chaos-test.sh [test_name]
#
# =============================================================================

set -e

COMPOSE_FILE="podman-compose-testing.yml"
LOG_DIR="./data/tmp/chaos-tests"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${LOG_DIR}/chaos-test-${TIMESTAMP}.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create log directory
mkdir -p "${LOG_DIR}"

log() {
    echo -e "$1" | tee -a "${LOG_FILE}"
}

pass() {
    log "${GREEN}[PASS]${NC} $1"
}

fail() {
    log "${RED}[FAIL]${NC} $1"
}

warn() {
    log "${YELLOW}[WARN]${NC} $1"
}

info() {
    log "[INFO] $1"
}

# =============================================================================
# Test Functions
# =============================================================================

test_container_restart() {
    info "Test 1: Container Restart Resilience"
    info "Testing app-1 graceful restart..."

    # Initial health check
    if ! curl -sf http://localhost:4000/health --max-time 5 > /dev/null 2>&1; then
        warn "Container not healthy before test, skipping"
        return 1
    fi

    # Restart container
    podman restart intelitor-app-1 2>&1 | tee -a "${LOG_FILE}"

    # Wait for recovery
    info "Waiting for container recovery (60s)..."
    sleep 60

    # Verify health
    if curl -sf http://localhost:4000/health --max-time 10 > /dev/null 2>&1; then
        pass "Container recovered from restart"
        return 0
    else
        fail "Container failed to recover from restart"
        return 1
    fi
}

test_container_kill() {
    info "Test 2: Container Crash Recovery"
    info "Simulating container crash (SIGKILL)..."

    # Kill container
    podman kill intelitor-app-1 2>&1 | tee -a "${LOG_FILE}" || true

    # Wait briefly
    sleep 5

    # Start container (restart policy should handle this, but manual for test)
    podman start intelitor-app-1 2>&1 | tee -a "${LOG_FILE}"

    # Wait for recovery
    info "Waiting for container recovery (90s)..."
    sleep 90

    # Verify health
    if curl -sf http://localhost:4000/health --max-time 10 > /dev/null 2>&1; then
        pass "Container recovered from crash"
        return 0
    else
        fail "Container failed to recover from crash"
        return 1
    fi
}

test_database_failover() {
    info "Test 3: Database Failover"
    info "Stopping primary database..."

    # Stop primary
    podman stop intelitor-db-primary 2>&1 | tee -a "${LOG_FILE}"

    # Check app behavior (should fail or use replica)
    sleep 10
    info "Testing app with primary down..."

    # Note: app-2 and app-3 use replica, so they should still work
    if curl -sf http://localhost:4001/health --max-time 10 > /dev/null 2>&1; then
        pass "App-2 (replica) still healthy during primary outage"
    else
        warn "App-2 not responding during primary outage"
    fi

    # Restart primary
    info "Restarting primary database..."
    podman start intelitor-db-primary 2>&1 | tee -a "${LOG_FILE}"

    # Wait for recovery
    sleep 30

    # Verify all healthy
    if curl -sf http://localhost:4000/health --max-time 10 > /dev/null 2>&1; then
        pass "Database failover recovery successful"
        return 0
    else
        fail "Database failover recovery failed"
        return 1
    fi
}

test_network_partition() {
    info "Test 4: Network Partition Simulation"
    info "Disconnecting app-2 from network..."

    # Disconnect from network
    podman network disconnect intelitor-test-net intelitor-app-2 2>&1 | tee -a "${LOG_FILE}" || true

    # Wait and observe
    sleep 15

    # Check remaining nodes
    if curl -sf http://localhost:4000/health --max-time 10 > /dev/null 2>&1; then
        pass "App-1 healthy during partition"
    else
        fail "App-1 not healthy during partition"
    fi

    if curl -sf http://localhost:4002/health --max-time 10 > /dev/null 2>&1; then
        pass "App-3 healthy during partition"
    else
        warn "App-3 not responding during partition"
    fi

    # Reconnect
    info "Reconnecting app-2 to network..."
    podman network connect intelitor-test-net intelitor-app-2 2>&1 | tee -a "${LOG_FILE}"

    # Wait for rejoin
    sleep 30

    # Verify recovery
    if curl -sf http://localhost:4001/health --max-time 10 > /dev/null 2>&1; then
        pass "Network partition recovery successful"
        return 0
    else
        fail "Network partition recovery failed"
        return 1
    fi
}

test_full_cluster_restart() {
    info "Test 5: Full Cluster Restart"
    info "Restarting entire cluster..."

    # Restart all
    podman-compose -f "${COMPOSE_FILE}" restart 2>&1 | tee -a "${LOG_FILE}"

    # Wait for all services
    info "Waiting for cluster recovery (120s)..."
    sleep 120

    # Count healthy containers
    healthy_count=0
    for port in 4000 4001 4002; do
        if curl -sf "http://localhost:${port}/health" --max-time 10 > /dev/null 2>&1; then
            ((healthy_count++))
        fi
    done

    if [ $healthy_count -eq 3 ]; then
        pass "Full cluster restart successful (3/3 nodes healthy)"
        return 0
    elif [ $healthy_count -gt 0 ]; then
        warn "Partial cluster recovery (${healthy_count}/3 nodes healthy)"
        return 1
    else
        fail "Full cluster restart failed (0/3 nodes healthy)"
        return 1
    fi
}

test_resource_exhaustion() {
    info "Test 6: Resource Exhaustion (Memory Limit)"
    info "Testing with constrained memory..."

    # Run compilation with limited memory
    result=$(podman run --rm --memory=512m \
        localhost/intelitor-sopv51-elixir-app:elixir-1.19-otp28 \
        elixir --eval "IO.puts('Memory test passed')" 2>&1) || true

    if echo "$result" | grep -q "Memory test passed"; then
        pass "Basic operation under memory constraints"
        return 0
    else
        warn "Memory-constrained operation may have issues"
        return 1
    fi
}

test_container_health_checks() {
    info "Test 7: Health Check Verification"

    # Get health status for all containers
    all_healthy=true
    for container in intelitor-db-primary intelitor-app-1 intelitor-app-2 intelitor-app-3; do
        status=$(podman inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
        if [ "$status" = "healthy" ]; then
            pass "${container}: ${status}"
        else
            warn "${container}: ${status}"
            all_healthy=false
        fi
    done

    if $all_healthy; then
        return 0
    else
        return 1
    fi
}

test_version_consistency() {
    info "Test 8: Version Consistency Check"

    for container in intelitor-app-1 intelitor-app-2 intelitor-app-3; do
        version=$(podman exec "$container" elixir --version 2>/dev/null | head -2 || echo "Error")
        if echo "$version" | grep -q "Elixir 1.19" && echo "$version" | grep -q "OTP 28"; then
            pass "${container}: Elixir 1.19.x / OTP 28"
        else
            fail "${container}: Version mismatch - ${version}"
        fi
    done
}

# =============================================================================
# Main Execution
# =============================================================================

run_all_tests() {
    log "=============================================="
    log " SOPv5.11 Chaos Test Suite"
    log " Timestamp: ${TIMESTAMP}"
    log "=============================================="

    total=0
    passed=0
    failed=0

    tests=(
        test_container_health_checks
        test_version_consistency
        test_container_restart
        test_container_kill
        test_database_failover
        test_network_partition
        test_full_cluster_restart
        test_resource_exhaustion
    )

    for test in "${tests[@]}"; do
        ((total++))
        log ""
        log "----------------------------------------------"
        if $test; then
            ((passed++))
        else
            ((failed++))
        fi
    done

    log ""
    log "=============================================="
    log " Results: ${passed}/${total} passed, ${failed} failed"
    log " Log: ${LOG_FILE}"
    log "=============================================="

    if [ $failed -gt 0 ]; then
        exit 1
    fi
}

# Run specific test or all tests
if [ -n "$1" ]; then
    case "$1" in
        restart) test_container_restart ;;
        kill) test_container_kill ;;
        database) test_database_failover ;;
        network) test_network_partition ;;
        cluster) test_full_cluster_restart ;;
        memory) test_resource_exhaustion ;;
        health) test_container_health_checks ;;
        version) test_version_consistency ;;
        all) run_all_tests ;;
        *)
            echo "Usage: $0 [restart|kill|database|network|cluster|memory|health|version|all]"
            exit 1
            ;;
    esac
else
    run_all_tests
fi
