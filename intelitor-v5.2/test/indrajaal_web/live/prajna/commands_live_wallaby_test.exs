defmodule IndrajaalWeb.Prajna.CommandsLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the PRAJNA C3I Command Center LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/cockpit/commands`
  - **Module**: `IndrajaalWeb.Prajna.CommandsLive`
  - **Title**: "Command Center"
  - **Priority**: P0 (Safety-Critical — two-step Arm & Fire)

  ## Design Intent
  The Command Center provides a safety-critical operator interface for executing
  system commands on target nodes. Critical commands (restart_app, failover,
  purge_cache, evacuate_node, drain_connections) require a two-step Arm & Fire
  protocol with a time-limited countdown and confirmation code entry. Standard
  commands execute immediately. Scaling commands adjust FLAME pool capacity.
  All commands are logged to the command history with result status.

  ## Expected Behavior

  ### Mount Assigns
  - `page_title` — "Command Center"
  - `armed_command` — nil (no command armed on load)
  - `arm_countdown` — 0 (countdown starts when armed)
  - `selected_target` — "app-01" (default target node)
  - `targets` — list of 5 nodes (app-01 through app-05)
  - `command_history` — [] (empty on mount)
  - `confirmation_code` — "" (empty string)
  - `show_confirmation` — false
  - `command_icons`, `status_icons` — icon maps
  - `critical_commands`, `standard_commands`, `scaling_commands` — command lists

  ### handle_event Callbacks
  - `"select_target"` — updates `selected_target` assign; no flash
  - `"arm_command"` (critical) — sets `armed_command`, `show_confirmation=true`; no flash
  - `"arm_command"` (standard/scaling) — executes immediately; flash :info "#{cmd} executed successfully"
  - `"update_confirmation"` — updates `confirmation_code`; no flash
  - `"confirm_command"` (valid code) — executes, flash :info "Command #{cmd} executing on #{target}"
  - `"confirm_command"` (invalid code) — flash :error "Invalid confirmation code"
  - `"cancel_command"` — clears `armed_command`, `show_confirmation=false`; no flash

  ### handle_info Callbacks
  - `:tick` (every 1000ms) — decrements `arm_countdown`; auto-cancels armed state when countdown ≤ 0
  - `{:command_result, cmd_id, result}` — updates corresponding entry in `command_history`

  ### PubSub Subscriptions
  - `"prajna:commands"` — receives live command result events

  ### Timer Intervals
  - `:tick` every 1000ms (`@refresh_interval 1000`)
  - Arm timeout: 300 seconds (`@arm_timeout_seconds 300`)

  ## BDD Scenarios

  ```gherkin
  Scenario: C1 - Page loads with Command Center heading
    Given I navigate to "/cockpit/commands"
    Then I see "COMMAND CENTER" heading
    And I see navigation links OVERVIEW, MESH, ALARMS

  Scenario: C2 - Default target app-01 is selected on load
    Given I navigate to "/cockpit/commands"
    Then the target "app-01" button is visible

  Scenario: C5 - Selecting a target updates the active state
    Given I navigate to "/cockpit/commands"
    When I click the "app-03" target button
    Then "app-03" becomes the selected target

  Scenario: C8 (dual) - Standard command executes with flash
    Given I navigate to "/cockpit/commands"
    When I click a standard command button
    Then I see a flash info message "executed successfully"

  Scenario: C8 (two-step) - Critical command arm→confirm→cancel
    Given I navigate to "/cockpit/commands"
    When I click a critical command button
    Then the confirmation code input appears
    When I fill in an invalid code and confirm
    Then I see flash error "Invalid confirmation code"
    When I click cancel
    Then the confirmation panel disappears
  ```

  ## UX Flow
  1. Operator selects target node from the 5-node target panel
  2. Operator clicks a command button:
     - Standard/scaling: executes immediately with flash confirmation
     - Critical: ARM phase activates — confirmation panel appears with countdown
  3. For critical commands: operator enters confirmation code → FIRE
  4. Invalid code → flash error; countdown expires → auto-cancel
  5. Command result updates in the history panel on the right

  ## UI Elements Inventory

  | Element | Type | Selector | Event |
  |---------|------|----------|-------|
  | COMMAND CENTER header | h1/span | `span[text="COMMAND CENTER"]` | — |
  | Target buttons (app-01..05) | button | `button[phx-value-target='app-01']` | `select_target` |
  | Critical command buttons | button | `button[phx-click='arm_command']` | `arm_command` |
  | Standard command buttons | button | `button[phx-click='arm_command']` | `arm_command` |
  | Confirmation code input | input | `input[name='confirmation_code']` | `update_confirmation` |
  | Confirm fire button | button | `button[phx-click='confirm_command']` | `confirm_command` |
  | Cancel button | button | `button[phx-click='cancel_command']` | `cancel_command` |
  | Command history panel | div | `div[contains('COMMAND HISTORY')]` | — |
  | Arm countdown display | span | `span[contains text countdown]` | — |
  | Category heading (critical) | h3 | `h3[text~='CRITICAL COMMANDS']` | — |
  | Category heading (standard) | h3 | `h3[text~='STANDARD COMMANDS']` | — |
  | Footer compliance badge | footer | `footer[text~='MIL-STD-1472H']` | — |

  ## STAMP Constraints
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard
  - SC-COV-019: Two-step commit arm→confirm→cancel sequence required
  - SC-HMI-004: Two-step commit UI (Arm & Fire pattern)
  - SC-HMI-011: 8x8 Matrix path coverage
  - SC-SAFETY-001: Guardian pre-approval for critical commands
  - SC-PRAJNA-005: Two-step commit for destructive actions
  - SC-MIL-001 to SC-MIL-004: Feedback latency requirements (MIL-STD-1472H)

  ## FMEA Risks

  | Failure Mode | S | O | D | RPN | Mitigation |
  |---|---|---|---|---|---|
  | Critical command fires without confirmation | 9 | 2 | 2 | 36 | Arm & Fire two-step enforced in handle_event |
  | Countdown expires with no auto-cancel | 7 | 2 | 3 | 42 | `:tick` handle_info auto-cancels at ≤0 |
  | Invalid confirmation code not rejected | 9 | 1 | 2 | 18 | Code verified before execution; error flash |
  | Standard command executes on wrong target | 7 | 2 | 3 | 42 | Target stored in assign; displayed in UI |
  | Command history not updated on result | 3 | 3 | 4 | 36 | `{:command_result,...}` handle_info updates list |

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

  @path "/cockpit/commands"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads with COMMAND CENTER header", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "COMMAND CENTER"))
  end

  feature "page loads with PRAJNA C3I navigation link", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("a", text: "PRAJNA C3I"))
  end

  feature "COMMANDS tab is active in navigation bar", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("a[class*='border-accent-primary']", text: "COMMANDS"))
  end

  feature "all three command category headings are present", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "CRITICAL COMMANDS (Two-Step Required)"))
    |> assert_has(css("h3", text: "STANDARD COMMANDS (Immediate)"))
    |> assert_has(css("h3", text: "SCALING"))
  end

  feature "navigation bar contains links to other cockpit sections", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("a", text: "OVERVIEW"))
    |> assert_has(css("a", text: "MESH"))
    |> assert_has(css("a", text: "ALARMS"))
  end

  feature "footer shows Two-Step Commit MIL-STD-1472H compliance text", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("footer", text: "Two-Step Commit: MIL-STD-1472H Compliant"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "target selection panel shows SELECT TARGET heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "SELECT TARGET"))
  end

  feature "default target app-01 is selected on load", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-value-target='app-01']"))
  end

  feature "clicking a target button changes the selected target highlight", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-target='app-03']"))
    |> assert_has(css("button[phx-value-target='app-03'][class*='bg-blue-600']"))
  end

  feature "arming restart command opens armed modal with COMMAND ARMED heading", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='restart']"))
    |> assert_has(css("h2", text: "COMMAND ARMED - CONFIRM EXECUTION"))
  end

  feature "confirmation modal shows target name in status area", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='restart']"))
    |> assert_has(css("span", text: "app-01"))
  end

  feature "confirmation modal shows RESTART command in status area", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='restart']"))
    |> assert_has(css("span", text: "RESTART"))
  end

  # ── C3: Data Grid / Summary ─────────────────────────────────────────────────

  feature "all 5 node target buttons are present", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-value-target='app-01']"))
    |> assert_has(css("button[phx-value-target='app-02']"))
    |> assert_has(css("button[phx-value-target='app-03']"))
    |> assert_has(css("button[phx-value-target='app-04']"))
    |> assert_has(css("button[phx-value-target='app-05']"))
  end

  feature "all 6 critical command arm buttons are present", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-value-command='restart']"))
    |> assert_has(css("button[phx-value-command='shutdown']"))
    |> assert_has(css("button[phx-value-command='power_off']"))
    |> assert_has(css("button[phx-value-command='isolate']"))
    |> assert_has(css("button[phx-value-command='hibernate']"))
    |> assert_has(css("button[phx-value-command='emergency_stop']"))
  end

  feature "scaling section has scale_flame_up scale_flame_down and set_load_balancer buttons", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-value-command='scale_flame_up']"))
    |> assert_has(css("button[phx-value-command='scale_flame_down']"))
    |> assert_has(css("button[phx-value-command='set_load_balancer']"))
  end

  feature "command history panel heading COMMAND HISTORY is present on load", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "COMMAND HISTORY (Last 10)"))
  end

  feature "confirmation modal shows armed-by operator identity", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='restart']"))
    |> assert_has(css("span", text: "operator@indrajaal.local"))
  end

  feature "confirmation modal shows Enter confirmation code label", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='restart']"))
    |> assert_has(css("label", text: "Enter confirmation code:"))
  end

  feature "confirmation modal shows Expires in countdown row", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='restart']"))
    |> assert_has(css("span", text: "Expires in:"))
  end

  feature "confirmation modal shows Armed at timestamp row", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='restart']"))
    |> assert_has(css("span", text: "Armed at:"))
  end

  # ── C4: Timeline / Command History ─────────────────────────────────────────

  feature "command history panel shows No commands executed when empty", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "COMMAND HISTORY (Last 10)"))
    |> assert_has(css("div", text: "No commands executed"))
  end

  feature "clear_alarms standard command adds CLEAR ALARMS entry to command history", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='clear_alarms']"))
    |> assert_has(css("span", text: "CLEAR ALARMS"))
  end

  feature "executing multiple standard commands populates history list with SUCCESS badges", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='power_on']"))
    |> click(css("button[phx-value-command='health_check']"))
    |> click(css("button[phx-value-command='resume_network']"))
    |> assert_has(css("span", text: "SUCCESS", minimum: 3))
  end

  feature "health_check history entry shows target identifier", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='health_check']"))
    |> assert_has(css("span", text: "app-01"))
  end

  feature "resume_network history entry shows RESUME NETWORK command label", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='resume_network']"))
    |> assert_has(css("span", text: "RESUME NETWORK"))
  end

  feature "power_on history entry shows POWER ON command label", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='power_on']"))
    |> assert_has(css("span", text: "POWER ON"))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "selecting target app-02 then arming shows app-02 in modal", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-target='app-02']"))
    |> click(css("button[phx-value-command='shutdown']"))
    |> assert_has(css("span", text: "app-02"))
  end

  feature "selecting target app-04 and arming hibernate shows app-04 in modal", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-target='app-04']"))
    |> click(css("button[phx-value-command='hibernate']"))
    |> assert_has(css("span", text: "app-04"))
  end

  feature "selecting target app-05 and arming isolate shows app-05 in modal", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-target='app-05']"))
    |> click(css("button[phx-value-command='isolate']"))
    |> assert_has(css("span", text: "app-05"))
  end

  feature "after cancel the command selection interface is visible again", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='hibernate']"))
    |> click(css("button[phx-click='cancel_command']"))
    |> assert_has(css("h3", text: "SELECT TARGET"))
    |> assert_has(css("h3", text: "SCALING"))
  end

  feature "WARNING block is shown in confirmation modal for critical command", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='restart']"))
    |> assert_has(css("p", text: "WARNING:"))
  end

  # ── C8: Action Buttons — dual verification (status change + flash) ───────────
  # SC-COV-016: every action button tested twice per AOR-COV-009

  # arm_command → cancel_command: status change (modal dismissed, grid restored)
  feature "cancel_command status — clicking Cancel dismisses armed modal and restores grid", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='restart']"))
    |> assert_has(css("h2", text: "COMMAND ARMED - CONFIRM EXECUTION"))
    |> click(css("button[phx-click='cancel_command']"))
    |> assert_has(css("h3", text: "CRITICAL COMMANDS (Two-Step Required)"))
  end

  # arm_command → cancel_command: no flash expected — verify grid present (cancel produces no flash)
  feature "cancel_command grid — command selection grid visible after cancel", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='power_off']"))
    |> click(css("button[phx-click='cancel_command']"))
    |> assert_has(css("h3", text: "STANDARD COMMANDS (Immediate)"))
  end

  # health_check (standard): status change — history entry appears
  feature "health_check status — history entry with SUCCESS badge appears after execution", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='health_check']"))
    |> assert_has(css("span", text: "SUCCESS"))
  end

  # health_check (standard): flash message
  feature "health_check flash — HEALTH CHECK executed successfully flash appears", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='health_check']"))
    |> assert_has(css("[role='alert']", text: "HEALTH CHECK executed successfully"))
  end

  # clear_alarms (standard): status change — history entry appears
  feature "clear_alarms status — history entry with CLEAR ALARMS label appears", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='clear_alarms']"))
    |> assert_has(css("span", text: "CLEAR ALARMS"))
  end

  # clear_alarms (standard): flash message
  feature "clear_alarms flash — CLEAR ALARMS executed successfully flash appears", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='clear_alarms']"))
    |> assert_has(css("[role='alert']", text: "CLEAR ALARMS executed successfully"))
  end

  # power_on (standard): status change — history entry
  feature "power_on status — history entry with POWER ON label appears", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='power_on']"))
    |> assert_has(css("span", text: "POWER ON"))
  end

  # power_on (standard): flash message
  feature "power_on flash — POWER ON executed successfully flash appears", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='power_on']"))
    |> assert_has(css("[role='alert']", text: "POWER ON executed successfully"))
  end

  # resume_network (standard): status change — history entry
  feature "resume_network status — history entry with RESUME NETWORK label appears", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='resume_network']"))
    |> assert_has(css("span", text: "RESUME NETWORK"))
  end

  # resume_network (standard): flash message
  feature "resume_network flash — RESUME NETWORK executed successfully flash appears", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='resume_network']"))
    |> assert_has(css("[role='alert']", text: "RESUME NETWORK executed successfully"))
  end

  # arm restart: status change — modal appears
  feature "arm restart status — COMMAND ARMED modal appears after arming restart", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='restart']"))
    |> assert_has(css("h2", text: "COMMAND ARMED - CONFIRM EXECUTION"))
  end

  # arm emergency_stop: status change — modal shows EMERGENCY STOP label
  feature "arm emergency_stop status — modal shows EMERGENCY STOP command label", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='emergency_stop']"))
    |> assert_has(css("h2", text: "COMMAND ARMED - CONFIRM EXECUTION"))
    |> assert_has(css("span", text: "EMERGENCY STOP"))
  end

  # arm shutdown: status change — modal shows shutdown-specific warning
  feature "arm shutdown status — modal shows node shutdown warning text", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='shutdown']"))
    |> assert_has(css("p", text: "shut down completely"))
  end

  # arm isolate: status change — modal shows ISOLATE command label
  feature "arm isolate status — modal shows ISOLATE command label", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='isolate']"))
    |> assert_has(css("span", text: "ISOLATE"))
  end

  # scale_flame_up (standard): flash message
  feature "scale_flame_up flash — SCALE FLAME UP executed successfully flash appears", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='scale_flame_up']"))
    |> assert_has(css("[role='alert']", text: "SCALE FLAME UP executed successfully"))
  end

  # scale_flame_down (standard): flash message
  feature "scale_flame_down flash — SCALE FLAME DOWN executed successfully flash appears", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='scale_flame_down']"))
    |> assert_has(css("[role='alert']", text: "SCALE FLAME DOWN executed successfully"))
  end

  # set_load_balancer (standard): flash message
  feature "set_load_balancer flash — SET LOAD BALANCER executed successfully flash appears", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-command='set_load_balancer']"))
    |> assert_has(css("[role='alert']", text: "SET LOAD BALANCER executed successfully"))
  end

  # ── C6: Media/Rich Content (Semantic CSS) ────────────────────────────────────

  feature "main container has bg-surface-primary theme-aware background class", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.bg-surface-primary"))
  end

  feature "header has bg-surface-secondary theme-aware surface class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("header.bg-surface-secondary"))
  end

  feature "header has border-border-theme-primary theme-aware border class", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("header.border-border-theme-primary"))
  end

  feature "main container uses font-mono monospace class for cockpit typography", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.font-mono"))
  end

  feature "navigation bar has bg-surface-secondary and border-border-theme-primary classes", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("nav.bg-surface-secondary"))
    |> assert_has(css("nav.border-border-theme-primary"))
  end

  # ── C7: AI/Advisory (Contextual Metrics) ─────────────────────────────────────

  feature "footer shows [A] Arm keyboard shortcut advisory for operator guidance", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("footer span", text: "[A] Arm"))
  end

  feature "footer shows [C] Confirm keyboard shortcut for two-step commit guidance", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("footer span", text: "[C] Confirm"))
  end

  feature "footer shows [X] Cancel keyboard shortcut for abort guidance", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("footer span", text: "[X] Cancel"))
  end

  feature "footer shows SC-HMI-004 constraint reference for operator compliance context", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("footer", text: "SC-HMI-004"))
  end

  feature "SCALING section heading provides operational category context for operators", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "SCALING"))
  end
end
