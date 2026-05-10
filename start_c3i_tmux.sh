#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# C3I TMUX SESSION & DAEMON ORCHESTRATOR
# ═══════════════════════════════════════════════════════════════════════════════
# This script initializes the full C3I workspace in Tmux and boots all
# required background daemons: sa-plan, ferriskey, lifeline, timestamp-sync,
# ignition, cepaf (F#), cepaf-gleam, and scripts-gleam (pi/daemon).

SESSION_NAME="c3i-workspace"
WORKSPACE_DIR="/home/an/dev/ver/c3i"

# Check if session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Session $SESSION_NAME already exists. Attaching..."
    tmux attach-session -t "$SESSION_NAME"
    exit 0
fi

# Create a new session, detached, starting in the workspace directory
tmux new-session -d -s "$SESSION_NAME" -n "vm1-c1" -c "$WORKSPACE_DIR"

# ─── Setup Work Windows ────────────────────────────────────────────────────────
# Window 0: vm1-c1 (already created by new-session)
# Window 2: vm1-c2
tmux new-window -t "$SESSION_NAME:2" -n "vm1-c2" -c "$WORKSPACE_DIR"
# Window 3: vm1-c3
tmux new-window -t "$SESSION_NAME:3" -n "vm1-c3" -c "$WORKSPACE_DIR"

# Window 4: vm1-hx (Helix editor)
tmux new-window -t "$SESSION_NAME:4" -n "vm1-hx" -c "$WORKSPACE_DIR"
tmux send-keys -t "$SESSION_NAME:4" "hx ." C-m

# Window 5: vm1-btop (System monitoring)
tmux new-window -t "$SESSION_NAME:5" -n "vm1-btop" -c "$WORKSPACE_DIR"
tmux send-keys -t "$SESSION_NAME:5" "btop" C-m

# Window 6: vm1-g1 (Git/General)
tmux new-window -t "$SESSION_NAME:6" -n "vm1-g1" -c "$WORKSPACE_DIR"
tmux send-keys -t "$SESSION_NAME:6" "git status" C-m

# ─── Setup Daemons Window ──────────────────────────────────────────────────────
# Window 7: c3i-daemons (Splits into multiple panes for background tasks)
tmux new-window -t "$SESSION_NAME:7" -n "c3i-daemons" -c "$WORKSPACE_DIR"

# Pane 1: sa-plan-daemon & ignition
tmux send-keys -t "$SESSION_NAME:7.0" "echo 'Starting sa-plan-daemon...' && ./sub-projects/c3i/target/release/sa-plan-daemon daemon & ./sub-projects/c3i/target/release/ignition dashboard --auto-boot" C-m

# Pane 2: ferriskey-bridge
tmux split-window -h -t "$SESSION_NAME:7.0" -c "$WORKSPACE_DIR"
tmux send-keys -t "$SESSION_NAME:7.1" "echo 'Starting FerrisKey Bridge...' && cargo run --manifest-path sub-projects/ferriskey/Cargo.toml --release" C-m

# Pane 3: sa-auto-lifeline
tmux split-window -v -t "$SESSION_NAME:7.0" -c "$WORKSPACE_DIR"
tmux send-keys -t "$SESSION_NAME:7.2" "echo 'Starting sa-auto-lifeline...' && ./sa-auto-lifeline" C-m

# Pane 4: timestamp-sync & cepaf-gleam
tmux split-window -v -t "$SESSION_NAME:7.1" -c "$WORKSPACE_DIR"
tmux send-keys -t "$SESSION_NAME:7.3" "echo 'Starting timestamp-sync and cepaf-gleam...' && ~/.config/opencode/bin/timestamp-sync-hook.sh start && ./sa-gleam-start" C-m

# Pane 5: F# CEPAF Engine & scripts-gleam
tmux split-window -v -t "$SESSION_NAME:7.0" -c "$WORKSPACE_DIR"
tmux send-keys -t "$SESSION_NAME:7.4" "echo 'Starting scripts-gleam (pi/daemon) and F# CEPAF...' && cd sub-projects/scripts-gleam && gleam run -m scripts/pi/daemon start & cd ../.. && ./bin/Cepaf daemon" C-m

# Set layout for daemons window (tiled)
tmux select-layout -t "$SESSION_NAME:7" tiled

# Select the first window
tmux select-window -t "$SESSION_NAME:0"

echo "C3I Tmux session created with all daemons running in window 7."
echo "Attach with: tmux attach-session -t $SESSION_NAME"
