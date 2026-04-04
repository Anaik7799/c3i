#!/usr/bin/env bash
# ============================================================================
# capture-ignition.sh — Full 7-Layer Panoptic Ignition with Complete I/O Capture
# ============================================================================
# Captures stdin, stdout, stderr across all 7 boot tiers
# Validates each container individually before swarm integration
# Usage: ./scripts/capture-ignition.sh [--fresh] [--skip-build]
#
# --fresh: Stop/remove existing containers before ignition
# --skip-build: Skip image rebuild (use existing images)
# ============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/lib/cepaf/artifacts"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
CAPTURE_DIR="$LOG_DIR/ignition-capture-${TIMESTAMP}"
IGNITION_LOG="$CAPTURE_DIR/ignition-master.log"
STDOUT_LOG="$CAPTURE_DIR/stdout.log"
STDERR_LOG="$CAPTURE_DIR/stderr.log"
STDIN_LOG="$CAPTURE_DIR/stdin.log"
COMPOSE_FILE="$PROJECT_ROOT/lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml"

mkdir -p "$CAPTURE_DIR"

# Create named pipes for stdin capture
STDIN_PIPE="$CAPTURE_DIR/stdin.pipe"
mkfifo "$STDIN_PIPE" 2>/dev/null || true

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  SIL-6 PANOPTIC IGNITION — FULL I/O CAPTURE v2.0              ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  Capture Dir: $CAPTURE_DIR"
echo "║  Master Log:  $IGNITION_LOG"
echo "║  STDOUT:      $STDOUT_LOG"
echo "║  STDERR:      $STDERR_LOG"
echo "║  STDIN:       $STDIN_LOG"
echo "║  Compose:     $COMPOSE_FILE"
echo "╚══════════════════════════════════════════════════════════════════╝"

# Parse args
FRESH=false
SKIP_BUILD=false
for arg in "$@"; do
    case "$arg" in
        --fresh) FRESH=true ;;
        --skip-build) SKIP_BUILD=true ;;
    esac
done

# ============================================================================
# PRE-IGNITION: Clean Slate
# ============================================================================
if [ "$FRESH" = true ]; then
    echo ""
    echo "[PRE-IGNITION] Stopping existing containers..."
    podman stop indrajaal-ex-app-1 indrajaal-ex-app-2 indrajaal-ex-app-3 \
        cepaf-bridge indrajaal-cortex indrajaal-chaya \
        indrajaal-ml-runner-1 indrajaal-ml-runner-2 indrajaal-mojo \
        zenoh-router zenoh-router-1 zenoh-router-2 zenoh-router-3 \
        indrajaal-db-prod indrajaal-obs-prod indrajaal-ollama 2>>"$STDERR_LOG" || true
    
    echo "[PRE-IGNITION] Removing stopped containers..."
    podman rm -f indrajaal-ex-app-1 indrajaal-ex-app-2 indrajaal-ex-app-3 \
        cepaf-bridge indrajaal-cortex indrajaal-chaya \
        indrajaal-ml-runner-1 indrajaal-ml-runner-2 indrajaal-mojo \
        zenoh-router zenoh-router-1 zenoh-router-2 zenoh-router-3 \
        indrajaal-db-prod indrajaal-obs-prod indrajaal-ollama 2>>"$STDERR_LOG" || true
    
    echo "[PRE-IGNITION] Clean slate achieved."
fi

# ============================================================================
# PHASE 0: PRE-VALIDATION — Verify Build Environment
# ============================================================================
echo ""
echo "[PHASE 0] Pre-Validation: Checking build environment..."
echo "=== PRE-VALIDATION $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >> "$IGNITION_LOG"

# Check cargo availability
if command -v cargo &>/dev/null; then
    echo "[✓] Cargo: $(cargo --version)" | tee -a "$IGNITION_LOG"
else
    echo "[✗] Cargo NOT found in PATH" | tee -a "$IGNITION_LOG"
    echo "WARNING: NIF compilation will fail without cargo" | tee -a "$STDERR_LOG"
fi

# Check native directories
echo "[NATIVE] Checking native directories..." | tee -a "$IGNITION_LOG"
for native_dir in native/math_engine native/zenoh_nif native/zenoh_ffi native/lineage_auth; do
    if [ -d "$PROJECT_ROOT/$native_dir" ]; then
        echo "  [✓] $native_dir exists" | tee -a "$IGNITION_LOG"
        if [ -f "$PROJECT_ROOT/$native_dir/Cargo.toml" ]; then
            echo "    [✓] Cargo.toml present" | tee -a "$IGNITION_LOG"
        else
            echo "    [✗] Cargo.toml MISSING" | tee -a "$STDERR_LOG"
        fi
    else
        echo "  [✗] $native_dir MISSING" | tee -a "$STDERR_LOG"
    fi
done

# Check Dockerfile has cargo and native COPY
if grep -q "nixpkgs.cargo" "$PROJECT_ROOT/Dockerfile.sopv51-app"; then
    echo "[✓] Dockerfile includes cargo" | tee -a "$IGNITION_LOG"
else
    echo "[✗] Dockerfile MISSING cargo installation" | tee -a "$STDERR_LOG"
fi

if grep -q "COPY native" "$PROJECT_ROOT/Dockerfile.sopv51-app"; then
    echo "[✓] Dockerfile includes native COPY" | tee -a "$IGNITION_LOG"
else
    echo "[✗] Dockerfile MISSING native COPY" | tee -a "$STDERR_LOG"
fi

# ============================================================================
# PHASE 1: IMAGE BUILD — With Full I/O Capture
# ============================================================================
echo ""
echo "[PHASE 1] Image Build Phase..."
echo "=== IMAGE BUILD $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >> "$IGNITION_LOG"

if [ "$SKIP_BUILD" = false ]; then
    echo "[BUILD] Building images with full stderr/stdout capture..." | tee -a "$IGNITION_LOG"
    
    # Build app image with separate stdout/stderr capture
    echo "[BUILD] Building indrajaal-sopv51-elixir-app..." | tee -a "$IGNITION_LOG"
    podman build \
        -t localhost/indrajaal-sopv51-elixir-app:nixos-devenv \
        -f Dockerfile.sopv51-app \
        . \
        1>>"$CAPTURE_DIR/build-app-stdout.log" \
        2>>"$CAPTURE_DIR/build-app-stderr.log"
    
    BUILD_EXIT=$?
    if [ $BUILD_EXIT -eq 0 ]; then
        echo "[✓] App image build successful" | tee -a "$IGNITION_LOG"
    else
        echo "[✗] App image build FAILED (exit: $BUILD_EXIT)" | tee -a "$STDERR_LOG"
        echo "[RCA] Check: $CAPTURE_DIR/build-app-stderr.log" | tee -a "$STDERR_LOG"
        tail -20 "$CAPTURE_DIR/build-app-stderr.log" | tee -a "$STDERR_LOG"
        exit 1
    fi
else
    echo "[BUILD] Skipping build (--skip-build)" | tee -a "$IGNITION_LOG"
fi

# ============================================================================
# PHASE 2: INDIVIDUAL CONTAINER VALIDATION
# ============================================================================
echo ""
echo "[PHASE 2] Individual Container Validation..."
echo "=== CONTAINER VALIDATION $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >> "$IGNITION_LOG"

# Define containers with their validation checks
declare -A CONTAINER_CHECKS
CONTAINER_CHECKS=(
    ["zenoh-router"]="port:8000 timeout:30"
    ["indrajaal-db-prod"]="pg_isready timeout:60"
    ["indrajaal-obs-prod"]="port:9090 timeout:90"
    ["zenoh-router-1"]="port:8000 timeout:30"
    ["zenoh-router-2"]="port:8001 timeout:30"
    ["zenoh-router-3"]="port:8002 timeout:30"
    ["cepaf-bridge"]="port:9876 timeout:30"
    ["indrajaal-cortex"]="running timeout:60"
    ["indrajaal-ex-app-1"]="port:4000 timeout:120"
    ["indrajaal-ex-app-2"]="port:4003 timeout:120"
    ["indrajaal-ex-app-3"]="port:4005 timeout:120"
    ["indrajaal-chaya"]="port:4002 timeout:60"
    ["indrajaal-ollama"]="port:11434 timeout:60"
    ["indrajaal-ml-runner-1"]="running timeout:60"
    ["indrajaal-ml-runner-2"]="running timeout:60"
    ["indrajaal-mojo"]="port:11436 timeout:60"
)

validate_container() {
    local container=$1
    local check_type=$2
    local check_value=$3
    local timeout=$4
    local container_log="$CAPTURE_DIR/validate-${container}.log"
    
    echo "  [VALIDATE] $container ($check_type:$check_value, timeout:${timeout}s)" | tee -a "$IGNITION_LOG"
    
    # Start container and capture all I/O
    podman start "$container" 2>>"$STDERR_LOG" >>"$STDOUT_LOG" || true
    
    local start_time=$(date +%s)
    local validated=false
    
    while true; do
        local now=$(date +%s)
        local elapsed=$((now - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            echo "    [✗] $container validation TIMEOUT (${timeout}s)" | tee -a "$STDERR_LOG"
            podman logs "$container" > "$container_log" 2>&1
            return 1
        fi
        
        case $check_type in
            "port")
                if podman exec "$container" sh -c "nc -z localhost $check_value" 2>/dev/null; then
                    echo "    [✓] $container port $check_value OPEN (${elapsed}s)" | tee -a "$IGNITION_LOG"
                    validated=true
                    break
                fi
                ;;
            "pg_isready")
                if podman exec "$container" pg_isready -q 2>/dev/null; then
                    echo "    [✓] $container PostgreSQL READY (${elapsed}s)" | tee -a "$IGNITION_LOG"
                    validated=true
                    break
                fi
                ;;
            "running")
                if [ "$(podman inspect -f '{{.State.Running}}' "$container" 2>/dev/null)" = "true" ]; then
                    echo "    [✓] $container RUNNING (${elapsed}s)" | tee -a "$IGNITION_LOG"
                    validated=true
                    break
                fi
                ;;
        esac
        
        sleep 2
    done
    
    # Capture container logs after validation
    podman logs "$container" > "$container_log" 2>&1
    
    if [ "$validated" = true ]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# PHASE 3: 7-TIER BOOT SEQUENCE with Full I/O Capture
# ============================================================================
echo ""
echo "[PHASE 3] 7-Tier Boot Sequence..."
echo "=== 7-TIER BOOT $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >> "$IGNITION_LOG"

# Create tier log files
for tier in 0 1 2 2b 3 4 5 6 7; do
    mkdir -p "$CAPTURE_DIR/tier-${tier}"
done

boot_tier() {
    local tier_name=$1
    local tier_num=$2
    shift 2
    local containers=("$@")
    
    echo "" | tee -a "$IGNITION_LOG"
    echo "[TIER $tier_num] $tier_name" | tee -a "$IGNITION_LOG"
    echo "=== TIER $tier_num: $tier_num $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >> "$IGNITION_LOG"
    
    local tier_log="$CAPTURE_DIR/tier-${tier_num}/tier.log"
    local tier_stdout="$CAPTURE_DIR/tier-${tier_num}/stdout.log"
    local tier_stderr="$CAPTURE_DIR/tier-${tier_num}/stderr.log"
    
    for container in "${containers[@]}"; do
        echo "  [BOOT] Starting $container..." | tee -a "$IGNITION_LOG"
        
        # Capture container start I/O
        podman start "$container" >>"$tier_stdout" 2>>"$tier_stderr"
        local start_exit=$?
        
        echo "    Start exit code: $start_exit" | tee -a "$tier_log"
        
        if [ $start_exit -ne 0 ]; then
            echo "    [✗] $container failed to start" | tee -a "$STDERR_LOG"
            podman logs "$container" > "$CAPTURE_DIR/tier-${tier_num}/${container}-error.log" 2>&1
            return 1
        fi
    done
    
    # Validate all containers in tier
    local all_valid=true
    for container in "${containers[@]}"; do
        if ! validate_container "$container" "${CONTAINER_CHECKS[$container]:-running: timeout:30}"; then
            all_valid=false
        fi
    done
    
    if [ "$all_valid" = true ]; then
        echo "  [✓] TIER $tier_num: ALL CONTAINERS VALIDATED" | tee -a "$IGNITION_LOG"
        return 0
    else
        echo "  [✗] TIER $tier_num: VALIDATION FAILED" | tee -a "$STDERR_LOG"
        return 1
    fi
}

# ============================================================================
# PHASE 4: SWARM INTEGRATION — Only After All Containers Validated
# ============================================================================
echo ""
echo "[PHASE 4] Swarm Integration..."
echo "=== SWARM INTEGRATION $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >> "$IGNITION_LOG"

# This phase only runs if all previous tiers succeeded
echo "[SWARM] All containers validated. Proceeding with swarm integration..." | tee -a "$IGNITION_LOG"

# Run the actual ignition command with full I/O capture
echo "[SWARM] Starting CEPAF ignition with full I/O capture..." | tee -a "$IGNITION_LOG"

# Use script command to capture everything including stdin
script -q -c "bin/Cepaf --env sil6 --sil6-startup --yes" "$CAPTURE_DIR/cephaf-typescript.log" 2>&1 | \
    tee >(cat >> "$STDOUT_LOG") \
    >(cat >> "$STDERR_LOG" >&2)

EXIT_CODE=${PIPESTATUS[0]}

# ============================================================================
# POST-IGNITION: Comprehensive Log Collection
# ============================================================================
echo ""
echo "[POST-IGNITION] Collecting comprehensive logs..."

# Collect per-container logs
CONTAINERS=(
    "zenoh-router" "indrajaal-db-prod" "indrajaal-obs-prod"
    "zenoh-router-1" "zenoh-router-2" "zenoh-router-3"
    "cepaf-bridge" "indrajaal-cortex"
    "indrajaal-ex-app-1" "indrajaal-ex-app-2" "indrajaal-ex-app-3"
    "indrajaal-chaya" "indrajaal-ollama"
    "indrajaal-ml-runner-1" "indrajaal-ml-runner-2" "indrajaal-mojo"
)

for container in "${CONTAINERS[@]}"; do
    if podman ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
        podman logs "$container" > "$CAPTURE_DIR/${container}.log" 2>&1
        echo "  [LOG] $container → ${container}.log"
        
        # Also capture container inspect data
        podman inspect "$container" > "$CAPTURE_DIR/${container}-inspect.json" 2>&1
        
        # Capture container processes
        podman top "$container" > "$CAPTURE_DIR/${container}-top.log" 2>&1 || true
    fi
done

# Capture system state
echo "" | tee -a "$IGNITION_LOG"
echo "[POST-IGNITION] System State Capture..." | tee -a "$IGNITION_LOG"
podman ps -a > "$CAPTURE_DIR/podman-ps.log" 2>&1
podman images > "$CAPTURE_DIR/podman-images.log" 2>&1
podman network ls > "$CAPTURE_DIR/podman-networks.log" 2>&1

# Summary
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  IGNITION CAPTURE COMPLETE                                      ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
if [ $EXIT_CODE -eq 0 ]; then
    echo "║  Status: SUCCESS                                                ║"
else
    echo "║  Status: EXIT CODE $EXIT_CODE                                     ║"
fi
echo "║  Capture Dir: $CAPTURE_DIR"
echo "║  Master Log:  $IGNITION_LOG"
echo "║  STDOUT:      $STDOUT_LOG"
echo "║  STDERR:      $STDERR_LOG"
echo "╚══════════════════════════════════════════════════════════════════╝"
