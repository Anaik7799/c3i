#!/usr/bin/env zsh
# CPU Governor for Indrajaal Agent Operations
# SC-CPU-GOV-001: CPU MUST NOT exceed 85% during agent operations
# Source this file before running heavy commands:
#   source scripts/cpu-governor.sh
#   governed_compile
#   governed_test test/some_test.exs --only wallaby

# No set -euo pipefail when sourced — functions handle their own errors

# ── Configuration ─────────────────────────────────────────────────────
CPU_HARD_LIMIT=85          # Absolute maximum — wait if exceeded
CPU_THROTTLE_THRESHOLD=80  # Reduce parallelism above this
CPU_RESUME_THRESHOLD=75    # Resume after waiting when CPU drops below this
CPU_CHECK_INTERVAL=2       # Seconds between checks during wait-loop
CPU_MAX_WAIT=120           # Maximum seconds to wait before aborting
GOVERNOR_NICE=10           # Default nice level for governed processes

# ── Core: CPU Measurement ─────────────────────────────────────────────
cpu_usage() {
    # Returns integer CPU % (0-100) averaged over 1 second
    # Uses /proc/stat differential for accuracy
    local cpu1 idle1 cpu2 idle2 total_diff idle_diff
    read -r _ user1 nice1 sys1 idle1 iow1 irq1 sirq1 _ < /proc/stat
    cpu1=$((user1 + nice1 + sys1 + iow1 + irq1 + sirq1))
    sleep 1
    read -r _ user2 nice2 sys2 idle2 iow2 irq2 sirq2 _ < /proc/stat
    cpu2=$((user2 + nice2 + sys2 + iow2 + irq2 + sirq2))
    total_diff=$(( (cpu2 + idle2) - (cpu1 + idle1) ))
    idle_diff=$((idle2 - idle1))
    if [ "$total_diff" -eq 0 ]; then
        echo "0"
    else
        echo $(( (total_diff - idle_diff) * 100 / total_diff ))
    fi
}

# Fast CPU check — uses /proc/stat snapshot (instant, no sleep)
# Takes two 100ms-apart snapshots for accurate instantaneous reading
cpu_usage_fast() {
    local c1 i1 c2 i2 td id
    read -r _ u1 n1 s1 i1 w1 q1 r1 _ < /proc/stat
    c1=$((u1 + n1 + s1 + w1 + q1 + r1))
    sleep 0.1
    read -r _ u2 n2 s2 i2 w2 q2 r2 _ < /proc/stat
    c2=$((u2 + n2 + s2 + w2 + q2 + r2))
    td=$(( (c2 + i2) - (c1 + i1) ))
    id=$((i2 - i1))
    if [ "$td" -eq 0 ]; then
        echo "0"
    else
        echo $(( (td - id) * 100 / td ))
    fi
}

# ── Wait Loop ─────────────────────────────────────────────────────────
cpu_wait_if_high() {
    local current elapsed=0
    current=$(cpu_usage_fast)

    if [ "$current" -le "$CPU_HARD_LIMIT" ]; then
        return 0
    fi

    echo "[CPU-GOV] CPU at ${current}% (limit: ${CPU_HARD_LIMIT}%). Waiting for < ${CPU_RESUME_THRESHOLD}%..."

    while [ "$elapsed" -lt "$CPU_MAX_WAIT" ]; do
        sleep "$CPU_CHECK_INTERVAL"
        elapsed=$((elapsed + CPU_CHECK_INTERVAL))
        current=$(cpu_usage_fast)

        if [ "$current" -le "$CPU_RESUME_THRESHOLD" ]; then
            echo "[CPU-GOV] CPU at ${current}%. Resuming."
            return 0
        fi

        echo "[CPU-GOV] CPU at ${current}% (${elapsed}s/${CPU_MAX_WAIT}s)..."
    done

    echo "[CPU-GOV] WARNING: CPU still at ${current}% after ${CPU_MAX_WAIT}s. Proceeding with minimum parallelism."
    return 0
}

# ── Adaptive Environment ──────────────────────────────────────────────
adaptive_env() {
    # Sets ELIXIR_ERL_OPTIONS, MIX_JOBS, and GOVERNOR_NICE based on CPU
    local current
    current=$(cpu_usage_fast)

    if [ "$current" -lt 60 ]; then
        export ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"
        export MIX_JOBS=16
        export GOVERNOR_NICE=10
        echo "[CPU-GOV] CPU ${current}% → Full speed: +S 16:16, --jobs 16"
    elif [ "$current" -lt 70 ]; then
        export ELIXIR_ERL_OPTIONS="+S 12:12 +SDio 12"
        export MIX_JOBS=12
        export GOVERNOR_NICE=10
        echo "[CPU-GOV] CPU ${current}% → Slight reduction: +S 12:12, --jobs 12"
    elif [ "$current" -lt 80 ]; then
        export ELIXIR_ERL_OPTIONS="+S 10:10 +SDio 10"
        export MIX_JOBS=10
        export GOVERNOR_NICE=15
        echo "[CPU-GOV] CPU ${current}% → Moderate throttle: +S 10:10, --jobs 10"
    elif [ "$current" -le 85 ]; then
        export ELIXIR_ERL_OPTIONS="+S 6:6 +SDio 6"
        export MIX_JOBS=6
        export GOVERNOR_NICE=19
        echo "[CPU-GOV] CPU ${current}% → Heavy throttle: +S 6:6, --jobs 6"
    else
        cpu_wait_if_high
        # After waiting, re-evaluate
        adaptive_env
        return
    fi
}

# ── Governed Compile ──────────────────────────────────────────────────
governed_compile() {
    cpu_wait_if_high
    adaptive_env

    echo "[CPU-GOV] Starting governed compilation (nice=$GOVERNOR_NICE, jobs=$MIX_JOBS)"

    nice -n "$GOVERNOR_NICE" env \
        NO_TIMEOUT=true \
        PATIENT_MODE=enabled \
        SKIP_ZENOH_NIF=0 \
        WALLABY_ENABLED=true \
        ELIXIR_ERL_OPTIONS="$ELIXIR_ERL_OPTIONS" \
        MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
        mix compile --jobs "$MIX_JOBS" "$@"

    local exit_code=$?
    echo "[CPU-GOV] Compilation finished (exit=$exit_code, CPU=$(cpu_usage_fast)%)"
    return $exit_code
}

# ── Governed Test ─────────────────────────────────────────────────────
governed_test() {
    cpu_wait_if_high
    adaptive_env

    echo "[CPU-GOV] Starting governed test (nice=$GOVERNOR_NICE, jobs=$MIX_JOBS)"

    nice -n "$GOVERNOR_NICE" env \
        WALLABY_ENABLED=true \
        WALLABY_CHROME_PATH="''${WALLABY_CHROME_PATH:-google-chrome-unstable}" \
        SKIP_ZENOH_NIF=0 \
        NO_TIMEOUT=true \
        PATIENT_MODE=enabled \
        HEALTH_PORT="${HEALTH_PORT:-4051}" \
        ELIXIR_ERL_OPTIONS="$ELIXIR_ERL_OPTIONS" \
        POSTGRES_USER="${POSTGRES_USER:-postgres}" \
        POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}" \
        DATABASE_URL="${DATABASE_URL:-ecto://postgres:postgres@localhost:5433/indrajaal_test}" \
        MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
        MIX_ENV=test mix test "$@"

    local exit_code=$?
    echo "[CPU-GOV] Test finished (exit=$exit_code, CPU=$(cpu_usage_fast)%)"
    return $exit_code
}

# ── Governed Wallaby E2E Test ─────────────────────────────────────────
governed_wallaby() {
    cpu_wait_if_high
    adaptive_env

    echo "[CPU-GOV] Starting governed Wallaby E2E test (nice=$GOVERNOR_NICE)"

    nice -n "$GOVERNOR_NICE" env \
        WALLABY_ENABLED=true \
        WALLABY_CHROME_PATH="''${WALLABY_CHROME_PATH:-google-chrome-unstable}" \
        SKIP_ZENOH_NIF=0 \
        NO_TIMEOUT=true \
        PATIENT_MODE=enabled \
        HEALTH_PORT="${HEALTH_PORT:-4051}" \
        ELIXIR_ERL_OPTIONS="$ELIXIR_ERL_OPTIONS" \
        POSTGRES_USER="${POSTGRES_USER:-postgres}" \
        POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}" \
        DATABASE_URL="${DATABASE_URL:-ecto://postgres:postgres@localhost:5433/indrajaal_test}" \
        MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
        MIX_ENV=test mix test --only wallaby "$@"

    local exit_code=$?
    echo "[CPU-GOV] Wallaby test finished (exit=$exit_code, CPU=$(cpu_usage_fast)%)"
    return $exit_code
}

# ── Governed Generic Execution ────────────────────────────────────────
governed_exec() {
    cpu_wait_if_high
    adaptive_env

    echo "[CPU-GOV] Executing: $* (nice=$GOVERNOR_NICE)"
    nice -n "$GOVERNOR_NICE" "$@"
    local exit_code=$?
    echo "[CPU-GOV] Finished (exit=$exit_code, CPU=$(cpu_usage_fast)%)"
    return $exit_code
}

# ── Status Report ─────────────────────────────────────────────────────
cpu_governor_status() {
    local current cores load
    current=$(cpu_usage_fast)
    cores=$(nproc)
    load=$(cat /proc/loadavg | cut -d' ' -f1-3)

    echo "╔═══════════════════════════════════════════════════╗"
    echo "║  CPU GOVERNOR STATUS                              ║"
    echo "╠═══════════════════════════════════════════════════╣"
    printf "║  CPU Utilization:  %3d%%                           ║\n" "$current"
    printf "║  Cores:            %3d                             ║\n" "$cores"
    printf "║  Load Average:     %-30s║\n" "$load"
    printf "║  Hard Limit:       %3d%%                           ║\n" "$CPU_HARD_LIMIT"
    printf "║  Throttle At:      %3d%%                           ║\n" "$CPU_THROTTLE_THRESHOLD"
    echo "║                                                   ║"

    if [ "$current" -lt 60 ]; then
        echo "║  Mode: FULL SPEED (+S 16:16, --jobs 16)          ║"
    elif [ "$current" -lt 70 ]; then
        echo "║  Mode: SLIGHT REDUCTION (+S 12:12, --jobs 12)    ║"
    elif [ "$current" -lt 80 ]; then
        echo "║  Mode: MODERATE THROTTLE (+S 10:10, --jobs 10)   ║"
    elif [ "$current" -le 85 ]; then
        echo "║  Mode: HEAVY THROTTLE (+S 6:6, --jobs 6)         ║"
    else
        echo "║  Mode: WAITING (CPU too high, paused)             ║"
    fi

    echo "╚═══════════════════════════════════════════════════╝"
}

# Functions are available when sourced — no export -f needed for zsh
