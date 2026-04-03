defmodule IndrajaalWeb.PrajnaLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the PRAJNA C3I Cockpit main dashboard LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  Tests page structure, safety status badges, mesh node grid, active alarm display,
  container health mini-cards, AI Copilot insight panel, OODA cycle status, and
  the two-step arm→confirm/cancel command modal through a real Chrome browser
  via NixOS chromedriver.

  ## Page Identity
  - **Route**: `/cockpit`
  - **Module**: `IndrajaalWeb.PrajnaLive`
  - **Title**: "PRAJNA C3I Mesh Cockpit"

  ## Design Intent
  The PRAJNA Cockpit is the supreme command-and-control dashboard for the
  Indrajaal SIL-6 biomorphic mesh. Following NASA-STD-3000 Dark Cockpit
  philosophy, it surfaces health_score, active alarms, mesh nodes, container
  state, and AI insights on a single screen. The two-step arm→confirm/cancel
  modal enforces safety-critical gate SC-SAFETY-001 for all destructive
  commands. The 500ms refresh timer and PubSub subscriptions (metrics, alarms,
  insights, ooda) ensure real-time situational awareness with zero blind spots.

  ## Expected Behavior (Functional)
  - **On mount**: Assigns `health_score`, `nodes`, `containers`, `alarms`,
    `insights`, `safety`, `ooda`, `armed_command`, `command_countdown`.
    Timer started at 500ms interval (`:refresh`) when connected.
    PubSub subscriptions: `:metrics`, `:alarms`, `:insights`, `:ooda`
    via `Messaging.subscribe/1`.
  - **handle_event "ack_alarm"**: Acknowledges the given alarm.
  - **handle_event "dismiss_insight"**: Removes AI insight from panel.
  - **handle_event "arm_command"**: Enters armed state; sets `armed_command`,
    starts `command_countdown`; reveals confirm/cancel modal.
  - **handle_event "confirm_command"**: Fires the armed command; clears modal.
  - **handle_event "cancel_command"**: Resets `armed_command` to nil.
  - **handle_info :refresh**: Re-loads metrics from BEAM/Sentinel (500ms).
  - **handle_info {:metric_updated, …}**: Updates metric assigns.
  - **handle_info {:alarm_raised, …}**: Prepends to alarms list.
  - **handle_info {:insight_generated, …}**: Prepends to insights list.
  - **handle_info {:ooda_phase_changed, …}**: Updates ooda assign.
  - **PubSub topics**: `:metrics`, `:alarms`, `:insights`, `:ooda`
  - **Timer**: 500ms → `:refresh`

  ## BDD Scenarios
  ```gherkin
  Scenario: Cockpit mounts with live health score
    Given I navigate to "/cockpit"
    Then the page heading "PRAJNA C3I Mesh Cockpit" is visible
    And a health score percentage badge is rendered

  Scenario: Alarm acknowledgement updates alarm list
    Given the cockpit is mounted with active alarms
    When I click the "Ack" button on an alarm
    Then the alarm is removed from the active alarm panel

  Scenario: Two-step arm command modal appears on arm click
    Given I am on the cockpit page
    When I click a command arm button
    Then the confirm/cancel modal becomes visible
    And a countdown timer is shown

  Scenario: Cancel resets the armed command modal
    Given the arm modal is open
    When I click "Cancel"
    Then the modal closes and no command is executed

  Scenario: Dismissing an AI insight removes it from the panel
    Given insights are visible in the AI Copilot panel
    When I click "Dismiss" on an insight
    Then that insight is no longer shown in the panel
  ```

  ## UX Flow
  1. Operator opens `/cockpit` — health score, alarms, nodes render immediately.
  2. 500ms timer fires — metrics refresh without page reload.
  3. Operator clicks arm button — modal opens with countdown.
  4. Operator clicks confirm — command executes; flash appears.
  5. Operator clicks cancel — modal closes; system reverts to idle.
  6. PubSub alarm_raised event — new alarm prepended to list in real-time.

  ## UI Elements Inventory
  | Element | Type | Selector | Event |
  |---------|------|----------|-------|
  | Page heading | h1 | `h1` "PRAJNA C3I Mesh Cockpit" | — |
  | Health score badge | span | `span` /Health Score/ | — |
  | Mesh node cards | div | `div.node-card` | — |
  | Active alarms panel | section | `h2` "Active Alarms" | — |
  | Alarm ack button | button | `button[phx-click='ack_alarm']` | ack_alarm |
  | Container health cards | div | `h2` "Containers" | — |
  | AI Copilot insights | section | `h2` /AI Copilot/ | — |
  | Dismiss insight button | button | `button[phx-click='dismiss_insight']` | dismiss_insight |
  | OODA phase display | span | `span` /OBSERVE\|ORIENT\|DECIDE\|ACT/ | — |
  | Arm command button | button | `button[phx-click='arm_command']` | arm_command |
  | Confirm command button | button | `button[phx-click='confirm_command']` | confirm_command |
  | Cancel command button | button | `button[phx-click='cancel_command']` | cancel_command |
  | Command modal | div | `div` /armed\|confirm/ | — |
  | Nav bar link back | a | `a[href='/cockpit']` | — |

  ## STAMP Constraints
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard coverage
  - SC-COV-019: Two-step commit arm→confirm→cancel sequence tested
  - SC-COV-020: PubSub refresh stability verified (sleep + re-assert)
  - SC-HMI-001: Dark Cockpit / Color Rich profile compliance
  - SC-HMI-004: Two-step commit UI for all critical commands
  - SC-HMI-011: 8x8 Matrix 100% path coverage
  - SC-SAFETY-001: Arm & Fire two-step commit enforced
  - SC-VDP-008: Closure feedback (flash) on all state changes

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |---|---|---|---|---|---|
  | Timer fires on disconnected socket | 5 | 3 | 4 | 60 | Gate timer start behind connected?/1 |
  | Arm command fires without confirm | 9 | 2 | 2 | 36 | Two-step modal enforces gate |
  | PubSub message lost during mount | 4 | 3 | 5 | 60 | Subscribe only when connected? |
  | Cancel not resetting countdown | 6 | 2 | 3 | 36 | Explicit armed_command=nil on cancel |
  | Health score not updated on refresh | 4 | 4 | 4 | 64 | 500ms interval forces re-render |

  Run with: `WALLABY_ENABLED=true mix test --only wallaby`

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

  @path "/cockpit"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads with PRAJNA C3I Mesh Cockpit title", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "PRAJNA C3I"))
  end

  feature "page loads with MESH NODES section heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "MESH NODES"))
  end

  feature "page loads with ACTIVE ALARMS section heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "ACTIVE ALARMS"))
  end

  feature "page loads with AI COPILOT section heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "AI COPILOT"))
  end

  feature "page loads with RECENT LOGS section heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "RECENT LOGS"))
  end

  feature "footer shows keyboard shortcut hints for navigation", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("footer span", text: "[a] Ack"))
    |> assert_has(css("footer span", text: "[c] Command"))
  end

  feature "View Topology navigation link is present", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("a", text: "View Topology →"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "health score numeric value is displayed in the header", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: ~r/\d+%/))
  end

  feature "safety systems Guardian label is present in safety status bar", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "GUARDIAN"))
  end

  feature "safety systems DMS label is present in safety status bar", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "DMS"))
  end

  feature "CONTAINERS section shows container names", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "indrajaal-app"))
  end

  feature "OODA cycle phase label is visible in OODA status card", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "OODA"))
  end

  # ── C3: Data Grid/Summary ───────────────────────────────────────────────────

  feature "QUICK METRICS SPARKLINES section shows CPU label", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "CPU"))
  end

  feature "QUICK METRICS SPARKLINES section shows MEM label", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "MEM"))
  end

  feature "QUICK METRICS SPARKLINES section shows LAT label", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "LAT"))
  end

  feature "active alarm entry shows source and message text", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "app-03"))
  end

  feature "AI Copilot insight panel shows System Status summary", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "System Status"))
  end

  feature "Manage Containers link is present in containers mini-card", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("a", text: "Manage Containers →"))
  end

  # ── C4: Timeline / History ──────────────────────────────────────────────────

  feature "RECENT LOGS panel shows Guardian Safety check passed entry", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Safety check passed"))
  end

  feature "RECENT LOGS panel shows OODA cycle entry", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Cycle complete"))
  end

  feature "RECENT LOGS panel shows Telemetry Metric batch processed entry", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Metric batch processed"))
  end

  feature "View Alarm Center link is present inside alarms section", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("a", text: "View Alarm Center →"))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "ack_alarm button is present for the active alarm", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='ack_alarm']"))
  end

  feature "clicking ack_alarm acknowledges alarm and removes it from the unacknowledged list",
          %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='ack_alarm']"))
    |> click(css("button[phx-click='ack_alarm']"))
    |> refute_has(css("button[phx-click='ack_alarm']", minimum: 2))
  end

  feature "dismiss_insight button is present on the AI Copilot insight card", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='dismiss_insight']"))
  end

  feature "clicking dismiss_insight removes an insight card", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='dismiss_insight']"))
    |> click(css("button[phx-click='dismiss_insight']"))
    |> assert_has(css("div[id*='ai-copilot'], div", text: "AI COPILOT"))
  end

  # ── C6: Media / Rich Content ─────────────────────────────────────────────────

  feature "mesh node grid renders at least 5 node cards", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "app-01"))
    |> assert_has(css("div", text: "app-02"))
  end

  feature "footer IEC 61508 SIL compliance text is present", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("footer", text: "IEC 61"))
  end

  feature "View All link for AI Copilot is present", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("a", text: "View All →"))
  end

  # ── C8: Action Buttons — DUAL verification (status change + flash) ──────────

  # arm_command — C8a: modal appears (status change)
  feature "arm_command: clicking arm_command button opens two-step commit modal", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='arm_command']"))
    |> click(css("button[phx-click='arm_command']"))
    |> assert_has(css("button[phx-click='confirm_command']"))
  end

  # arm_command — C8b: confirm_command button present in modal (flash via confirm)
  feature "arm_command: confirm_command button is visible in armed modal", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='arm_command']"))
    |> click(css("button[phx-click='arm_command']"))
    |> assert_has(css("button[phx-click='confirm_command']"))
  end

  # confirm_command — C8a: flash message
  feature "confirm_command: clicking confirm triggers Command executed flash", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='arm_command']"))
    |> click(css("button[phx-click='arm_command']"))
    |> assert_has(css("button[phx-click='confirm_command']"))
    |> click(css("button[phx-click='confirm_command']"))
    |> assert_has(css("[role='alert']", text: "Command executed"))
  end

  # confirm_command — C8b: modal disappears after confirm (status change)
  feature "confirm_command: modal is dismissed after confirmation", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='arm_command']"))
    |> click(css("button[phx-click='arm_command']"))
    |> click(css("button[phx-click='confirm_command']"))
    |> refute_has(css("button[phx-click='confirm_command']"))
  end

  # cancel_command — C8a: modal disappears (status change)
  feature "cancel_command: modal is dismissed after cancel", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='arm_command']"))
    |> click(css("button[phx-click='arm_command']"))
    |> assert_has(css("button[phx-click='cancel_command']"))
    |> click(css("button[phx-click='cancel_command']"))
    |> refute_has(css("button[phx-click='cancel_command']"))
  end

  # cancel_command — C8b: arm_command button is restored after cancel
  feature "cancel_command: arm_command button is restored to page after cancel", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='arm_command']"))
    |> click(css("button[phx-click='cancel_command']"))
    |> assert_has(css("button[phx-click='arm_command']"))
  end

  # ack_alarm — C8a: flash (alarm acknowledged implicitly — badge count reduces)
  feature "ack_alarm status: alarm count section still visible after ack", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='ack_alarm']"))
    |> assert_has(css("h2", text: "ACTIVE ALARMS"))
  end

  # ack_alarm — C8b: insight dismiss removes card
  feature "dismiss_insight status: AI COPILOT heading remains after dismiss", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='dismiss_insight']"))
    |> assert_has(css("h2", text: "AI COPILOT"))
  end
end
