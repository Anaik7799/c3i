#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# CLAUDE CODE TODO SYNCHRONIZATION HOOK
# ═══════════════════════════════════════════════════════════════════════════════
#
# This hook automatically synchronizes Claude Code session tasks with the
# project's PROJECT_TODOLIST.md file.
#
# STAMP COMPLIANCE:
#   SC-TODO-005: Export session tasks on session end
#   SC-TODO-006: Auto-export new tasks
#   SC-TODO-008: Maintain audit trail
#
# TRIGGER: After TodoWrite tool invocations
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Configuration
PROJECT_ROOT="/home/an/dev/ver/intelitor-v5.2"
SYNC_SCRIPT="${PROJECT_ROOT}/scripts/planning/claude_todo_sync.exs"
LOG_FILE="${PROJECT_ROOT}/logs/todo_sync_hook.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Log function
log() {
    echo "[$(date -Iseconds)] $1" >> "$LOG_FILE"
}

# Main sync function
sync_todos() {
    log "HOOK_TRIGGERED: Todo sync initiated"

    # Check if sync script exists
    if [[ ! -f "$SYNC_SCRIPT" ]]; then
        log "ERROR: Sync script not found: $SYNC_SCRIPT"
        exit 1
    fi

    # Execute sync
    cd "$PROJECT_ROOT"
    if elixir "$SYNC_SCRIPT" --sync --from-claude >> "$LOG_FILE" 2>&1; then
        log "SUCCESS: Todo sync completed"
    else
        log "WARNING: Todo sync had issues (non-fatal)"
    fi
}

# Execute if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    sync_todos
fi
