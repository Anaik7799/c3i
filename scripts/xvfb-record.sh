#!/usr/bin/env bash
# C3I Xvfb Video Recording & Screenshot Environment
# SC-VERIFY-VISUAL-001..006
# Usage:
#   ./scripts/xvfb-record.sh screenshot <url> <output.png> [width] [height]
#   ./scripts/xvfb-record.sh video <url> <output.mp4> [duration_sec] [width] [height]
#   ./scripts/xvfb-record.sh start-xvfb [display_num]
#   ./scripts/xvfb-record.sh stop-xvfb [display_num]

set -euo pipefail

DISPLAY_NUM="${XVFB_DISPLAY:-99}"
WIDTH="${4:-1400}"
HEIGHT="${5:-900}"
CHROMIUM="/home/an/dev/ver/intelitor-v5.2/.devenv/profile/bin/chromium"

start_xvfb() {
    local disp="${1:-$DISPLAY_NUM}"
    if [ -f "/tmp/.X${disp}-lock" ]; then
        echo "[xvfb] Display :${disp} already running"
        return 0
    fi
    Xvfb ":${disp}" -screen 0 "${WIDTH}x${HEIGHT}x24" -ac +extension GLX +render -noreset &
    XVFB_PID=$!
    echo "$XVFB_PID" > "/tmp/xvfb-${disp}.pid"
    sleep 1
    echo "[xvfb] Started Xvfb on :${disp} (PID: $XVFB_PID)"
}

stop_xvfb() {
    local disp="${1:-$DISPLAY_NUM}"
    if [ -f "/tmp/xvfb-${disp}.pid" ]; then
        kill "$(cat /tmp/xvfb-${disp}.pid)" 2>/dev/null || true
        rm -f "/tmp/xvfb-${disp}.pid" "/tmp/.X${disp}-lock"
        echo "[xvfb] Stopped Xvfb on :${disp}"
    else
        echo "[xvfb] No Xvfb running on :${disp}"
    fi
}

screenshot() {
    local url="$1"
    local output="$2"
    local w="${3:-1400}"
    local h="${4:-900}"

    # Use Chromium headless (no Xvfb needed for screenshots)
    "$CHROMIUM" --headless --no-sandbox --disable-gpu \
        --screenshot="$output" \
        --window-size="${w},${h}" \
        "$url" 2>/dev/null

    local size
    size=$(stat -c%s "$output" 2>/dev/null || echo "0")
    echo "[screenshot] Captured: $output (${size} bytes)"
}

video() {
    local url="$1"
    local output="$2"
    local duration="${3:-15}"
    local w="${4:-1400}"
    local h="${5:-900}"
    local disp="$DISPLAY_NUM"

    # Start Xvfb if not running
    start_xvfb "$disp"
    export DISPLAY=":${disp}"

    # Launch Chromium in Xvfb
    "$CHROMIUM" --no-sandbox --disable-gpu \
        --window-size="${w},${h}" \
        --window-position=0,0 \
        "$url" &
    local CHROME_PID=$!
    sleep 3  # Wait for page load

    # Record with ffmpeg
    echo "[video] Recording ${duration}s of $url at ${w}x${h}..."
    ffmpeg -y -f x11grab -video_size "${w}x${h}" \
        -framerate 10 -i ":${disp}" \
        -t "$duration" \
        -c:v libx264 -preset ultrafast -crf 28 \
        -pix_fmt yuv420p \
        "$output" 2>/dev/null

    # Cleanup
    kill "$CHROME_PID" 2>/dev/null || true

    local size
    size=$(stat -c%s "$output" 2>/dev/null || echo "0")
    echo "[video] Recorded: $output (${size} bytes, ${duration}s)"
}

# Scroll recording - captures a user journey with scrolling
scroll_video() {
    local url="$1"
    local output="$2"
    local duration="${3:-20}"
    local w="${4:-1400}"
    local h="${5:-900}"
    local disp="$DISPLAY_NUM"

    start_xvfb "$disp"
    export DISPLAY=":${disp}"

    "$CHROMIUM" --no-sandbox --disable-gpu \
        --window-size="${w},${h}" \
        --window-position=0,0 \
        "$url" &
    local CHROME_PID=$!
    sleep 3

    # Start recording
    ffmpeg -y -f x11grab -video_size "${w}x${h}" \
        -framerate 10 -i ":${disp}" \
        -t "$duration" \
        -c:v libx264 -preset ultrafast -crf 28 \
        -pix_fmt yuv420p \
        "$output" &
    local FFMPEG_PID=$!

    # Scroll through the page using xdotool
    sleep 2
    nix-shell -p xdotool --run "
        export DISPLAY=:${disp}
        for i in \$(seq 1 $((duration - 4))); do
            xdotool key --window \$(xdotool search --name 'Chromium' | head -1) Page_Down 2>/dev/null || true
            sleep 1
        done
    " 2>/dev/null || true

    # Wait for ffmpeg to finish
    wait "$FFMPEG_PID" 2>/dev/null || true
    kill "$CHROME_PID" 2>/dev/null || true

    local size
    size=$(stat -c%s "$output" 2>/dev/null || echo "0")
    echo "[scroll-video] Recorded: $output (${size} bytes, ${duration}s)"
}

# Multi-page journey - records visiting multiple URLs
journey_video() {
    local output="$1"
    shift
    local urls=("$@")
    local duration_per_page=5
    local total_duration=$(( ${#urls[@]} * duration_per_page + 3 ))
    local w=1400
    local h=900
    local disp="$DISPLAY_NUM"

    start_xvfb "$disp"
    export DISPLAY=":${disp}"

    # Start with first URL
    "$CHROMIUM" --no-sandbox --disable-gpu \
        --window-size="${w},${h}" \
        --window-position=0,0 \
        "${urls[0]}" &
    local CHROME_PID=$!
    sleep 3

    # Start recording
    ffmpeg -y -f x11grab -video_size "${w}x${h}" \
        -framerate 10 -i ":${disp}" \
        -t "$total_duration" \
        -c:v libx264 -preset ultrafast -crf 28 \
        -pix_fmt yuv420p \
        "$output" &
    local FFMPEG_PID=$!

    # Navigate through pages using xdotool
    for url in "${urls[@]:1}"; do
        sleep "$duration_per_page"
        nix-shell -p xdotool --run "
            export DISPLAY=:${disp}
            # Open URL in address bar
            xdotool key --clearmodifiers ctrl+l 2>/dev/null || true
            sleep 0.3
            xdotool type --delay 30 '$url' 2>/dev/null || true
            sleep 0.3
            xdotool key Return 2>/dev/null || true
        " 2>/dev/null || true
    done

    # Wait for recording to finish
    wait "$FFMPEG_PID" 2>/dev/null || true
    kill "$CHROME_PID" 2>/dev/null || true

    local size
    size=$(stat -c%s "$output" 2>/dev/null || echo "0")
    echo "[journey-video] Recorded: $output (${size} bytes, ${total_duration}s, ${#urls[@]} pages)"
}

# Main dispatcher
case "${1:-help}" in
    screenshot)
        screenshot "${2:?URL required}" "${3:?Output file required}" "${4:-1400}" "${5:-900}"
        ;;
    video)
        video "${2:?URL required}" "${3:?Output file required}" "${4:-15}" "${5:-1400}" "${6:-900}"
        ;;
    scroll-video)
        scroll_video "${2:?URL required}" "${3:?Output file required}" "${4:-20}" "${5:-1400}" "${6:-900}"
        ;;
    journey)
        shift
        journey_video "$@"
        ;;
    start-xvfb)
        start_xvfb "${2:-$DISPLAY_NUM}"
        ;;
    stop-xvfb)
        stop_xvfb "${2:-$DISPLAY_NUM}"
        ;;
    help|*)
        echo "C3I Xvfb Video Recording Environment"
        echo ""
        echo "Usage:"
        echo "  $0 screenshot <url> <output.png> [width] [height]"
        echo "  $0 video <url> <output.mp4> [duration] [width] [height]"
        echo "  $0 scroll-video <url> <output.mp4> [duration] [width] [height]"
        echo "  $0 journey <output.mp4> <url1> <url2> [url3...]"
        echo "  $0 start-xvfb [display_num]"
        echo "  $0 stop-xvfb [display_num]"
        echo ""
        echo "Environment:"
        echo "  XVFB_DISPLAY=99  (default virtual display number)"
        echo "  Chromium: $CHROMIUM"
        echo "  Xvfb: $(which Xvfb)"
        echo "  ffmpeg: $(which ffmpeg)"
        echo "  xdotool: via nix-shell"
        ;;
esac
