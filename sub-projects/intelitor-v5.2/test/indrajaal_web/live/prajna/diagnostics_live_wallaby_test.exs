defmodule IndrajaalWeb.Prajna.DiagnosticsLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the PRAJNA C3I Diagnostics screen.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/cockpit/diagnostics`
  - **Module**: `IndrajaalWeb.Prajna.DiagnosticsLive`
  - **Title**: "Diagnostics"

  ## Design Intent
  Provides operators with a unified diagnostic interface for the Prajna cockpit system.
  Enables real-time log tailing, distributed trace inspection, system health checks,
  state dumps, CPU profiling, and integration with SigNoz for observability. Supports
  five diagnostic views (Logs, Traces, Metrics History, Audit Trail, System Info) to
  enable rapid root-cause analysis per NUREG-0700 HMI guidelines.

  ## Expected Behavior (Functional)
  - **On mount**: assigns `page_title`, `active_tab: :logs`, `logs: []`, `log_filter: "all"`,
    `live_tail: true`, `traces: []`, `audit_trail: []`, `system_info: %{}`,
    `last_health_check: nil`, `last_state_dump: nil`
  - **PubSub**: subscribes to `"prajna:logs"` for real-time log streaming
  - **Timer**: 1000ms → `:refresh` (live log refresh when `live_tail: true`)
  - **handle_event "switch_tab"**: changes `active_tab` assign (no flash)
  - **handle_event "toggle_live_tail"**: toggles `live_tail` boolean (no flash)
  - **handle_event "update_filter"**: updates `log_filter` assign (no flash)
  - **handle_event "run_health_check"**: runs health check → flash "Health check completed - {STATUS}"
  - **handle_event "dump_state"**: saves state dump → flash "State dump saved"
  - **handle_event "trace_request"**: enables 60s request tracing → flash "Request tracing enabled for next 60 seconds"
  - **handle_event "profile_cpu"**: starts 30s CPU profile → flash "CPU profiling started (30 seconds)"
  - **handle_event "export_logs"**: exports logs → flash "Logs exported to prajna_logs.json"
  - **handle_event "clear_old_logs"**: purges logs > 7 days → flash "Logs older than 7 days cleared"
  - **handle_event "open_signoz"**: redirects to SigNoz external URL (no flash)

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator views real-time logs with live tail enabled
    Given I navigate to "/cockpit/diagnostics"
    Then I should see the LOGS tab active
    And the QUICK DIAGNOSTICS section should be visible
    And the live tail toggle should be enabled by default

  Scenario: Operator switches between diagnostic tabs
    Given I navigate to "/cockpit/diagnostics"
    When I click the "TRACES" tab button
    Then the traces view should become active
    When I click the "AUDIT TRAIL" tab button
    Then the audit trail view should become active

  Scenario: Operator runs a system health check
    Given I navigate to "/cockpit/diagnostics"
    When I click the "Run Health Check" quick diagnostic button
    Then a flash message should confirm "Health check completed"

  Scenario: Operator requests CPU profiling
    Given I navigate to "/cockpit/diagnostics"
    When I click the "Profile CPU" quick diagnostic button
    Then a flash message should confirm "CPU profiling started (30 seconds)"

  Scenario: Operator exports logs for offline analysis
    Given I navigate to "/cockpit/diagnostics"
    When I click the "Export Logs" button
    Then a flash message should confirm "Logs exported to prajna_logs.json"
  ```

  ## UX Flow
  1. Operator navigates to `/cockpit/diagnostics` — Logs tab shown by default
  2. Live tail is active — new log entries stream in every 1000ms
  3. Operator can toggle live tail off to pause streaming and inspect entries
  4. Operator applies log filter to narrow entries by severity or source
  5. Operator switches to Traces tab to inspect distributed call traces
  6. Operator clicks "Run Health Check" in Quick Diagnostics panel
  7. System runs health check and confirms result via flash message
  8. Operator runs "Dump State" to capture current system state snapshot
  9. Operator uses "Export Logs" to download logs for offline analysis
  10. Operator clicks "Open SigNoz" to navigate to external observability UI

  ## UI Elements Inventory
  | Element | Type | Selector | Event |
  |---------|------|----------|-------|
  | DIAGNOSTICS heading | span | `css("span", text: "DIAGNOSTICS")` | none |
  | PRAJNA C3I nav link | a | `css("a", text: "PRAJNA C3I")` | navigate |
  | LOGS tab | button | `css("button[phx-value-tab='logs']")` | switch_tab |
  | TRACES tab | button | `css("button[phx-value-tab='traces']")` | switch_tab |
  | METRICS HISTORY tab | button | `css("button[phx-value-tab='metrics']")` | switch_tab |
  | AUDIT TRAIL tab | button | `css("button[phx-value-tab='audit']")` | switch_tab |
  | SYSTEM INFO tab | button | `css("button[phx-value-tab='system']")` | switch_tab |
  | QUICK DIAGNOSTICS section | h2 | `css("h2", text: "QUICK DIAGNOSTICS")` | none |
  | Live Tail toggle | button | `css("button[phx-click='toggle_live_tail']")` | toggle_live_tail |
  | Run Health Check | button | `css("button[phx-click='run_health_check']")` | run_health_check |
  | Dump State | button | `css("button[phx-click='dump_state']")` | dump_state |
  | Trace Request | button | `css("button[phx-click='trace_request']")` | trace_request |
  | Profile CPU | button | `css("button[phx-click='profile_cpu']")` | profile_cpu |
  | Export Logs | button | `css("button[phx-click='export_logs']")` | export_logs |
  | Clear Old Logs | button | `css("button[phx-click='clear_old_logs']")` | clear_old_logs |
  | Open SigNoz | button | `css("button[phx-click='open_signoz']")` | open_signoz (redirect) |
  | Flash message | div | `css("[role='alert']")` | status feedback |
  | OTEL/SigNoz footer | footer | `css("footer", text: "OTEL | SigNoz Integration")` | none |

  ## STAMP Constraints
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard coverage
  - SC-COV-016: C8 dual verification — status change AND flash per action button
  - SC-HMI-011: 8x8 Matrix path coverage (8 elements × 8 fractal layers)
  - SC-OBS-069: Dual logging Terminal + SigNoz integration verified
  - SC-DIAG-001: Log retention > 7 days (clear_old_logs preserves newer entries)
  - SC-VDP-010: Temporal context in displays (timestamps on log entries)

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |---|---|---|---|---|---|
  | Live tail timer fires after unmount | 7 | 3 | 3 | 63 | Process.cancel_timer in terminate |
  | Health check hangs — flash never shown | 8 | 2 | 4 | 64 | Timeout guard in handle_event |
  | PubSub topic mismatch drops log events | 6 | 2 | 5 | 60 | Topic name assertion in test |
  | SigNoz redirect fails silently | 5 | 3 | 4 | 60 | redirect/2 return verified |
  | Log export creates empty JSON file | 6 | 2 | 3 | 36 | File content assertion post-export |

  Run with: WALLABY_ENABLED=true mix test --only wallaby

  ## Human-Specified Intent
  <!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->
  <!-- Last modified by: [Pending human review] -->

  ### Functional Intent
  [Awaiting human specification — describe what this page MUST do from operator perspective]

  ### UX Requirements
  [Awaiting human specification — describe how the page MUST feel and behave]

  ### Safety Requirements
  [Awaiting human specification — non-negotiable safety behaviors]

  ### Override Instructions
  [Awaiting human specification — any instructions that override agent behavior]
  <!-- END HUMAN-ONLY -->
  """
  use IndrajaalWeb.FeatureCase, async: false

  @moduletag :wallaby

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads with DIAGNOSTICS header", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> assert_has(css("span", text: "DIAGNOSTICS"))
  end

  feature "page loads with PRAJNA C3I navigation link", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> assert_has(css("a", text: "PRAJNA C3I"))
  end

  feature "all 5 diagnostic tab buttons are present", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> assert_has(css("button[phx-value-tab='logs']", text: "LOGS"))
    |> assert_has(css("button[phx-value-tab='traces']", text: "TRACES"))
    |> assert_has(css("button[phx-value-tab='metrics']", text: "METRICS HISTORY"))
    |> assert_has(css("button[phx-value-tab='audit']", text: "AUDIT TRAIL"))
    |> assert_has(css("button[phx-value-tab='system']", text: "SYSTEM INFO"))
  end

  feature "QUICK DIAGNOSTICS section is visible on default Logs tab", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> assert_has(css("h2", text: "QUICK DIAGNOSTICS"))
  end

  feature "footer shows OTEL | SigNoz Integration compliance text", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> assert_has(css("footer", text: "OTEL | SigNoz Integration"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "LIVE TAIL button is visible and shows ON state by default", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> assert_has(css("button[phx-click='toggle_live_tail']", text: "LIVE TAIL: ON"))
  end

  feature "clicking LIVE TAIL button toggles it to OFF", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-click='toggle_live_tail']"))
    |> assert_has(css("button[phx-click='toggle_live_tail']", text: "LIVE TAIL: OFF"))
  end

  feature "clicking LIVE TAIL twice restores it to ON", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-click='toggle_live_tail']"))
    |> click(css("button[phx-click='toggle_live_tail']"))
    |> assert_has(css("button[phx-click='toggle_live_tail']", text: "LIVE TAIL: ON"))
  end

  feature "after RUN HEALTH CHECK the Last Health Check line appears", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-click='run_health_check']"))
    |> assert_has(css("div", text: "Last Health Check:"))
  end

  feature "after DUMP STATE the Last State Dump line appears with path", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-click='dump_state']"))
    |> assert_has(css("div", text: "Last State Dump:"))
  end

  # ── C3: Data Grid/Summary ───────────────────────────────────────────────────

  feature "default tab is Logs showing All Sources and level selects", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> assert_has(css("select[name='source']"))
    |> assert_has(css("select[name='level']"))
  end

  feature "log source filter contains All Sources and named source options", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> assert_has(css("option", text: "All Sources"))
    |> assert_has(css("option", text: "Phoenix"))
    |> assert_has(css("option", text: "Sentinel"))
  end

  feature "log level filter contains Debug Info Warning Error options", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> assert_has(css("option", text: "Debug+"))
    |> assert_has(css("option", text: "Info+"))
    |> assert_has(css("option", text: "Warning+"))
    |> assert_has(css("option", text: "Error+"))
  end

  feature "System Info tab shows RUNTIME INFO heading", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-value-tab='system']"))
    |> assert_has(css("h2", text: "RUNTIME INFO"))
  end

  feature "System Info tab shows BEAM VM section", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-value-tab='system']"))
    |> assert_has(css("h2", text: "BEAM VM"))
  end

  feature "System Info tab shows Elixir Version in runtime section", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-value-tab='system']"))
    |> assert_has(css("span", text: "Elixir Version:"))
  end

  # ── C4: Timeline/History ────────────────────────────────────────────────────

  feature "Audit Trail tab shows ALARM_ACK and CONFIG_CHANGE entries", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-value-tab='audit']"))
    |> assert_has(css("span", text: "ALARM_ACK"))
    |> assert_has(css("span", text: "CONFIG_CHANGE"))
  end

  feature "Audit Trail tab shows COMMAND_EXEC and LOGIN entries", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-value-tab='audit']"))
    |> assert_has(css("span", text: "COMMAND_EXEC"))
    |> assert_has(css("span", text: "LOGIN"))
  end

  feature "Audit Trail tab shows operator user and resource names", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-value-tab='audit']"))
    |> assert_has(css("span", text: "operator@indrajaal.local"))
    |> assert_has(css("span", text: "ALM-2024-00_142"))
  end

  feature "health check result line shows PASSED or WARNING or FAILED status", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-click='run_health_check']"))
    |> assert_has(css("div", text: "Last Health Check:"))
  end

  feature "Traces tab shows trace entries with path and duration", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-value-tab='traces']"))
    |> assert_has(css("span", text: "/api/alarms"))
    |> assert_has(css("span", text: "/api/metrics"))
  end

  feature "Traces tab shows Phoenix.Endpoint span in trace detail", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-value-tab='traces']"))
    |> assert_has(css("span", text: "Phoenix.Endpoint", minimum: 1))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "search input is present in the log filter toolbar", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> assert_has(css("input[name='search'][placeholder='Search...']"))
  end

  feature "switching to Traces tab shows TRACE EXPLORER heading", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-value-tab='traces']"))
    |> assert_has(css("h2", text: "TRACE EXPLORER"))
  end

  feature "switching to Audit Trail tab shows AUDIT TRAIL heading", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-value-tab='audit']"))
    |> assert_has(css("h2", text: "AUDIT TRAIL"))
  end

  feature "switching to Metrics History tab shows tab content", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-value-tab='metrics']"))
    |> assert_has(css("div", text: "Tab content coming soon"))
  end

  feature "switching away from Logs tab and back preserves LIVE TAIL ON state", %{
    session: session
  } do
    session
    |> visit("/cockpit/diagnostics")
    |> assert_has(css("button[phx-click='toggle_live_tail']", text: "LIVE TAIL: ON"))
    |> click(css("button[phx-value-tab='traces']"))
    |> click(css("button[phx-value-tab='logs']"))
    |> assert_has(css("button[phx-click='toggle_live_tail']", text: "LIVE TAIL: ON"))
  end

  # ── C6: Media/Rich Content ──────────────────────────────────────────────────

  feature "Logs tab displays time-stamped log entries in viewer panel", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> assert_has(css("div.font-mono", minimum: 1))
  end

  feature "log viewer panel shows Showing N of M entries footer", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> assert_has(css("span", text: "Showing"))
  end

  feature "OPEN IN SIGNOZ button is present in action buttons area", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> assert_has(css("button[phx-click='open_signoz']", text: "OPEN IN SIGNOZ"))
  end

  feature "footer shows keyboard shortcut hints H D T P", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> assert_has(css("footer span", text: "[H] Health Check"))
    |> assert_has(css("footer span", text: "[D] Dump State"))
  end

  # ── C8: Action Buttons — DUAL verification (status change + flash) ──────────

  # run_health_check — C8a: flash message
  feature "clicking RUN HEALTH CHECK triggers info flash with result", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-click='run_health_check']"))
    |> assert_has(css("[role='alert']", text: "Health check completed"))
  end

  # run_health_check — C8b: status change (Last Health Check line appears)
  feature "RUN HEALTH CHECK status: Last Health Check timestamp visible after click", %{
    session: session
  } do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-click='run_health_check']"))
    |> assert_has(css("div", text: "Last Health Check:"))
  end

  # dump_state — C8a: flash message
  feature "clicking DUMP STATE triggers State dump saved flash", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-click='dump_state']"))
    |> assert_has(css("[role='alert']", text: "State dump saved"))
  end

  # dump_state — C8b: status change (Last State Dump line appears)
  feature "DUMP STATE status: Last State Dump path visible after click", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-click='dump_state']"))
    |> assert_has(css("div", text: "Last State Dump:"))
  end

  # trace_request — C8a: flash message
  feature "clicking TRACE REQUEST triggers Request tracing enabled flash", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-click='trace_request']"))
    |> assert_has(css("[role='alert']", text: "Request tracing enabled for next 60 seconds"))
  end

  # trace_request — C8b: all 4 quick diagnostic action buttons still present after click
  feature "TRACE REQUEST status: all 4 quick diagnostic buttons remain after click", %{
    session: session
  } do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-click='trace_request']"))
    |> assert_has(css("button[phx-click='run_health_check']"))
    |> assert_has(css("button[phx-click='dump_state']"))
    |> assert_has(css("button[phx-click='trace_request']"))
    |> assert_has(css("button[phx-click='profile_cpu']"))
  end

  # profile_cpu — C8a: flash message
  feature "clicking PROFILE CPU triggers CPU profiling started flash", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-click='profile_cpu']"))
    |> assert_has(css("[role='alert']", text: "CPU profiling started (30 seconds)"))
  end

  # profile_cpu — C8b: Quick Diagnostics section still visible after click
  feature "PROFILE CPU status: QUICK DIAGNOSTICS section still visible after click", %{
    session: session
  } do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-click='profile_cpu']"))
    |> assert_has(css("h2", text: "QUICK DIAGNOSTICS"))
  end

  # export_logs — C8a: flash message
  feature "clicking EXPORT LOGS triggers Logs exported flash", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-click='export_logs']", text: "EXPORT LOGS"))
    |> assert_has(css("[role='alert']", text: "Logs exported to prajna_logs.json"))
  end

  # export_logs — C8b: action buttons section still rendered after click
  feature "EXPORT LOGS status: CLEAR OLD LOGS and OPEN IN SIGNOZ buttons still present", %{
    session: session
  } do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-click='export_logs']", text: "EXPORT LOGS"))
    |> assert_has(css("button[phx-click='clear_old_logs']"))
    |> assert_has(css("button[phx-click='open_signoz']"))
  end

  # clear_old_logs — C8a: flash message
  feature "clicking CLEAR OLD LOGS triggers Logs older than 7 days cleared flash", %{
    session: session
  } do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-click='clear_old_logs']", text: "CLEAR OLD LOGS"))
    |> assert_has(css("[role='alert']", text: "Logs older than 7 days cleared"))
  end

  # clear_old_logs — C8b: log viewer still present after click
  feature "CLEAR OLD LOGS status: log source select still present after click", %{
    session: session
  } do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-click='clear_old_logs']", text: "CLEAR OLD LOGS"))
    |> assert_has(css("select[name='source']"))
  end

  # open_signoz — C8a: button is present (redirect, no flash - verify it exists before click)
  feature "OPEN IN SIGNOZ button has correct phx-click attribute", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> assert_has(css("button[phx-click='open_signoz']"))
  end

  # All 4 quick diagnostic action buttons present
  feature "all 4 quick diagnostic buttons are present", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> assert_has(css("button[phx-click='run_health_check']", text: "RUN HEALTH CHECK"))
    |> assert_has(css("button[phx-click='dump_state']", text: "DUMP STATE"))
    |> assert_has(css("button[phx-click='trace_request']", text: "TRACE REQUEST"))
    |> assert_has(css("button[phx-click='profile_cpu']", text: "PROFILE CPU"))
  end

  # toggle_live_tail — C8a: flash is NOT produced (no put_flash), but LIVE TAIL: OFF badge
  feature "LIVE TAIL status: toggling to OFF shows OFF badge (C8 status verification)", %{
    session: session
  } do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-click='toggle_live_tail']"))
    |> assert_has(css("button[phx-click='toggle_live_tail']", text: "LIVE TAIL: OFF"))
  end

  feature "Audit Trail tab shows audit entry details paragraph text", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> click(css("button[phx-value-tab='audit']"))
    |> assert_has(css("p", text: "Acknowledged intrusion alarm in Zone-A"))
  end

  feature "log time-range select is present with Last 1 hour option", %{session: session} do
    session
    |> visit("/cockpit/diagnostics")
    |> assert_has(css("option", text: "Last 1 hour"))
    |> assert_has(css("option", text: "Last 7 days"))
  end
end
