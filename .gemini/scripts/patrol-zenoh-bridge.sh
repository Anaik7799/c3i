#!/usr/bin/env bash
# patrol-zenoh-bridge.sh
# Bridges Patrol MCP / Marionette MCP / CLI tool calls onto Zenoh.
# Used by the PostToolUse hook in .claude/settings.json AND as a CLI fallback
# when MCP transport is unavailable.
#
# SC-PATROL-MCP-003 / -004 / -010
#
# Usage (hook mode — receives JSON event on stdin):
#   patrol-zenoh-bridge.sh hook
#
# Usage (CLI fallback — wraps `patrol` or `marionette` and emits envelopes):
#   patrol-zenoh-bridge.sh run --target integration_test/patrol_test.dart \
#                              --device chrome --web-headless
#
#   patrol-zenoh-bridge.sh marionette --uri ws://127.0.0.1:8181/ws \
#                              tap --text "Submit"
#
# Topics:
#   indrajaal/l5/test/patrol/<run_id>/<phase>
#   indrajaal/l5/test/marionette/<session_id>/<phase>

set -euo pipefail

SCRIPT_NAME="patrol-zenoh-bridge"
ZENOH_ENDPOINT="${ZENOH_CONNECT:-tcp/localhost:7447}"
ZENOH_HTTP="${ZENOH_HTTP:-http://localhost:8000}"
SOURCE_TAG="${SOURCE_TAG:-claude-code}"

# ---------- helpers ----------
now_iso() { date -u +"%Y-%m-%dT%H:%M:%S.%3NZ"; }
new_id()  { command -v uuidgen >/dev/null && uuidgen || echo "$(date +%s%N)-$$"; }

publish() {
  local topic="$1" payload="$2"
  # 1) Try the Zenoh REST API (preferred, no NIF required)
  if curl -sS -X PUT --max-time 2 \
       -H "Content-Type: application/json" \
       --data-binary "$payload" \
       "${ZENOH_HTTP}/${topic}" >/dev/null 2>&1; then
    return 0
  fi
  # 2) Fallback: append to a file the Rust cortex tail-publishes
  local fallback="${PROJECT_ROOT:-/home/an/dev/ver/c3i}/data/tmp/patrol-zenoh.jsonl"
  mkdir -p "$(dirname "$fallback")"
  printf '%s\t%s\n' "$topic" "$payload" >> "$fallback"
}

envelope() {
  local urn="$1" run_id="$2" phase="$3" platform="$4" target="$5" payload_extra="$6"
  cat <<EOF
{"at":"$(now_iso)","source":"${SOURCE_TAG}","urn":"${urn}","run_id":"${run_id}","phase":"${phase}","platform":"${platform}","test_target":"${target}","payload":${payload_extra:-{}}}
EOF
}

# ---------- hook mode ----------
# Reads a Claude Code PostToolUse hook event off stdin, filters mcp__patrol__*
# and mcp__marionette__* events, publishes to Zenoh.
hook_mode() {
  local event
  event="$(cat)"
  local tool
  tool="$(echo "$event" | jq -r '.tool_name // ""')"
  case "$tool" in
    mcp__patrol__*)
      local phase="${tool#mcp__patrol__}"
      local run_id
      run_id="$(echo "$event" | jq -r '.tool_input.run_id // env.PATROL_RUN_ID // empty')"
      [ -z "$run_id" ] && run_id="$(new_id)"
      local platform
      platform="$(echo "$event" | jq -r '.tool_input.device // .tool_input.platform // "unknown"')"
      local target
      target="$(echo "$event" | jq -r '.tool_input.target // ""')"
      local payload
      payload="$(echo "$event" | jq -c '{tool_input,tool_response}')"
      publish "indrajaal/l5/test/patrol/${run_id}/${phase}" \
              "$(envelope "urn:c3i:test:patrol:${run_id}" "$run_id" "$phase" "$platform" "$target" "$payload")"
      ;;
    mcp__marionette__*)
      local phase="${tool#mcp__marionette__}"
      local session_id
      session_id="$(echo "$event" | jq -r '.tool_input.session_id // env.MARIONETTE_SESSION_ID // empty')"
      [ -z "$session_id" ] && session_id="$(new_id)"
      local payload
      payload="$(echo "$event" | jq -c '{tool_input,tool_response}')"
      publish "indrajaal/l5/test/marionette/${session_id}/${phase}" \
              "$(envelope "urn:c3i:test:marionette:${session_id}" "$session_id" "$phase" "marionette" "" "$payload")"
      ;;
    *) : ;; # not our event — ignore silently
  esac
}

# ---------- CLI fallback: run ----------
cli_run() {
  local run_id; run_id="$(new_id)"
  export PATROL_RUN_ID="$run_id"
  local target="" device="unknown"
  # crude flag scan to find target/device for the envelope
  local args=("$@")
  for ((i=0; i<${#args[@]}; i++)); do
    case "${args[$i]}" in
      --target) target="${args[$((i+1))]}";;
      --device|-d) device="${args[$((i+1))]}";;
    esac
  done

  publish "indrajaal/l5/test/patrol/${run_id}/start" \
          "$(envelope "urn:c3i:test:patrol:${run_id}" "$run_id" "start" "$device" "$target" '{}')"

  # SC-PATROL-MCP-006: ensure MarionetteBinding stays out of test runs
  local rc=0
  patrol test --dart-define=DISABLE_MARIONETTE=true "$@" || rc=$?

  local phase=$([ "$rc" -eq 0 ] && echo "passed" || echo "failed")
  publish "indrajaal/l5/test/patrol/${run_id}/${phase}" \
          "$(envelope "urn:c3i:test:patrol:${run_id}" "$run_id" "$phase" "$device" "$target" "{\"exit_code\":$rc}")"
  return $rc
}

# ---------- CLI fallback: marionette ----------
cli_marionette() {
  local session_id; session_id="$(new_id)"
  export MARIONETTE_SESSION_ID="$session_id"
  publish "indrajaal/l5/test/marionette/${session_id}/start" \
          "$(envelope "urn:c3i:test:marionette:${session_id}" "$session_id" "start" "marionette" "" "{}")"
  local rc=0
  marionette "$@" || rc=$?
  local phase=$([ "$rc" -eq 0 ] && echo "ok" || echo "error")
  publish "indrajaal/l5/test/marionette/${session_id}/${phase}" \
          "$(envelope "urn:c3i:test:marionette:${session_id}" "$session_id" "$phase" "marionette" "" "{\"exit_code\":$rc}")"
  return $rc
}

# ---------- entrypoint ----------
case "${1:-}" in
  hook)        shift; hook_mode "$@";;
  run)         shift; cli_run "$@";;
  marionette)  shift; cli_marionette "$@";;
  *)
    cat >&2 <<USAGE
$SCRIPT_NAME — bridge patrol/marionette MCP+CLI events to Zenoh
  $SCRIPT_NAME hook                    (reads PostToolUse JSON on stdin)
  $SCRIPT_NAME run --target X --device Y [...]
  $SCRIPT_NAME marionette --uri ws://... <subcommand>
USAGE
    exit 2
    ;;
esac
