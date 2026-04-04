#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# INDRAJAAL TIMESTAMP SYNC AGENT
# Ensures system, OpenCode agent, and model timestamps do not drift
# Version: v21.3.2-SIL6
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Resolve the project root (scripts/timestamp -> scripts -> project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Use same data directory as Rust daemon for consistency
DAEMON_ROOT="${HOME}/.local/share/indrajaal-timestamp-sync"
LOG_FILE="${DAEMON_ROOT}/logs/timestamp-sync.log"
LOCK_FILE="/tmp/indrajaal-timestamp-sync.lock"
STATE_FILE="${DAEMON_ROOT}/data/state/timestamp-state.json"

# Timestamp drift thresholds (in seconds)
MAX_DRIFT=5           # Max acceptable drift before correction
DRIFT_WARNING=2        # Drift level that triggers warning
DRIFT_CRITICAL=10     # Drift level that triggers alert

# ═══════════════════════════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════════════════════════

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S %Z')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# ENSURE LOG DIR
# ═══════════════════════════════════════════════════════════════════════════════

ensure_dirs() {
    local log_dir state_dir
    log_dir="${DAEMON_ROOT}/logs"
    state_dir="${DAEMON_ROOT}/data/state"
    mkdir -p "$log_dir" 2>/dev/null || true
    mkdir -p "$state_dir" 2>/dev/null || true
    log "DEBUG" "Ensured directories: $log_dir, $state_dir"
}

# ═══════════════════════════════════════════════════════════════════════════════
# GET CURRENT TIMESTAMPS FROM MULTIPLE SOURCES
# ═══════════════════════════════════════════════════════════════════════════════

get_system_timestamp() {
    echo "$(date +%s)"
}

get_ntp_timestamp() {
    # Try NTP first, fallback to system
    if command -v ntpdate &>/dev/null; then
        ntpdate -q pool.ntp.org 2>/dev/null | head -1 | awk '{print $2}' || echo "$(get_system_timestamp)"
    elif command -v timedatectl &>/dev/null; then
        # Use timedatectl for servers without ntpdate
        timedatectl show --property=NTPSynchronized --value 2>/dev/null || echo "unknown"
    else
        echo "unavailable"
    fi
}

get_opencode_timestamp() {
    # Read OpenCode session start time from environment/state
    if [[ -n "${OPENCODE_SESSION_START:-}" ]]; then
        echo "$OPENCODE_SESSION_START"
    elif [[ -f "$STATE_FILE" ]]; then
        jq -r '.opencode_session_start // empty' "$STATE_FILE" 2>/dev/null || echo "$(get_system_timestamp)"
    else
        echo "$(get_system_timestamp)"
    fi
}

get_model_timestamp() {
    # Model timestamp is typically injected at session start
    # This is a placeholder - actual implementation depends on OpenCode internals
    if [[ -f "$STATE_FILE" ]]; then
        jq -r '.model_timestamp // empty' "$STATE_FILE" 2>/dev/null || echo "$(get_system_timestamp)"
    else
        echo "$(get_system_timestamp)"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# CALCULATE DRIFT BETWEEN SOURCES
# ═══════════════════════════════════════════════════════════════════════════════

calculate_drift() {
    local source1="$1"
    local source2="$2"
    local ts1 ts2
    
    ts1="$("$source1")"
    ts2="$("$source2")"
    
    echo $((ts1 - ts2))
}

calculate_abs_drift() {
    local drift
    drift=$(calculate_drift "$1" "$2")
    echo "${drift#-}"  # Absolute value
}

# ═══════════════════════════════════════════════════════════════════════════════
# SYNC TIMESTAMPS
# ═══════════════════════════════════════════════════════════════════════════════

sync_ntp() {
    log "INFO" "Attempting NTP sync..."
    
    if command -v ntpdate &>/dev/null; then
        if sudo ntpdate pool.ntp.org 2>/dev/null; then
            log "INFO" "NTP sync successful"
            return 0
        else
            log "WARN" "NTP sync failed - insufficient permissions or network issue"
            return 1
        fi
    elif command -v timedatectl &>/dev/null; then
        if timedatectl set-ntp true 2>/dev/null; then
            log "INFO" "timedatectl NTP sync enabled"
            return 0
        else
            log "WARN" "timedatectl NTP sync failed"
            return 1
        fi
    fi
    
    log "WARN" "No NTP client available"
    return 1
}

update_opencode_state() {
    local system_ts="$1"
    local model_ts="$2"
    local drift="$3"
    local last_sync last_sync_iso
    
    last_sync=$(date +%s)
    last_sync_iso=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
    
    printf '%s\n' \
        "{" \
        "  \"last_sync\": ${last_sync}," \
        "  \"last_sync_iso\": \"${last_sync_iso}\"," \
        "  \"opencode_session_start\": ${system_ts}," \
        "  \"model_timestamp\": ${model_ts}," \
        "  \"system_to_model_drift\": ${drift}," \
        "  \"sync_source\": \"Indrajaal Timestamp Sync Agent v21.3.2-SIL6\"" \
        "}" > "$STATE_FILE"
    
    log "INFO" "Updated timestamp state file: $STATE_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ALERTS
# ═══════════════════════════════════════════════════════════════════════════════

send_alert() {
    local severity="$1"
    local message="$2"
    
    log "$severity" "ALERT: $message"
    
    # Publish to Zenoh if available
    if command -v zendisc &>/dev/null || [[ -S /tmp/zenoh.sock ]]; then
        # Publish alert to indrajaal/telemetry/timestamp-sync/alerts topic
        log "INFO" "Would publish alert to Zenoh: $severity - $message"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN SYNC LOGIC
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    ensure_dirs
    
    log "INFO" "════════════════════════════════════════════════════════════"
    log "INFO" "Indrajaal Timestamp Sync Agent v21.3.2-SIL6"
    log "INFO" "════════════════════════════════════════════════════════════"
    
    # Acquire lock to prevent concurrent runs
    if ! mkdir "$LOCK_FILE" 2>/dev/null; then
        log "WARN" "Another instance is running, exiting"
        exit 0
    fi
    trap "rm -rf $LOCK_FILE" EXIT
    
    local system_ts model_ts drift abs_drift
    
    system_ts=$(get_system_timestamp)
    model_ts=$(get_model_timestamp)
    drift=$((system_ts - model_ts))
    abs_drift="${drift#-}"
    
    log "INFO" "System timestamp:   $system_ts ($(date -d @$system_ts '+%Y-%m-%d %H:%M:%S %Z'))"
    log "INFO" "Model timestamp:    $model_ts ($(date -d @$model_ts '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || echo "unknown"))"
    log "INFO" "Current drift:      ${drift}s"
    
    # Check drift levels
    if (( abs_drift > DRIFT_CRITICAL )); then
        log "ERROR" "CRITICAL drift detected: ${abs_drift}s > ${DRIFT_CRITICAL}s threshold"
        send_alert "ERROR" "Critical timestamp drift: ${abs_drift}s"
        
        # Attempt NTP sync
        if sync_ntp; then
            log "INFO" "NTP sync corrected drift"
        else
            log "ERROR" "Could not correct drift - manual intervention required"
        fi
    elif (( abs_drift > MAX_DRIFT )); then
        log "WARN" "Warning: drift ${abs_drift}s exceeds max ${MAX_DRIFT}s"
        send_alert "WARN" "Timestamp drift warning: ${abs_drift}s"
    elif (( abs_drift > DRIFT_WARNING )); then
        log "INFO" "Minor drift detected: ${abs_drift}s (acceptable)"
    else
        log "INFO" "Drift within acceptable range: ${abs_drift}s"
    fi
    
    # Update state
    update_opencode_state "$system_ts" "$model_ts" "$drift"
    
    log "INFO" "Timestamp sync completed successfully"
    log "INFO" "════════════════════════════════════════════════════════════"
}

# ═══════════════════════════════════════════════════════════════════════════════
# RUN
# ═══════════════════════════════════════════════════════════════════════════════

main "$@"
