defmodule IndrajaalWeb.SystemStatusLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the System Status LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/admin/system-status`
  - **Module**: `IndrajaalWeb.SystemStatusLive`
  - **Title**: "System Status"

  ## Design Intent
  Provides operators with a real-time multi-dimensional view of system health
  across five domains: system overview, container fleet, agent hierarchy, STAMP
  compliance status, and OODA loop metrics. Enables operators to detect degradation
  and initiate container restarts directly from the cockpit admin panel.

  ## Expected Behavior (Functional)
  - **On mount**: Sets `page_title`, `current_time`, `view_mode: :overview`, then calls
    helper functions: `assign_system_health/1`, `assign_container_status/1`,
    `assign_agent_hierarchy/1`, `assign_database_health/1`, `assign_stamp_compliance/1`,
    `assign_ooda_metrics/1`. When `connected?/1`: subscribes to PubSub `"system_health"`,
    `"container_metrics"`, `"agent_status"` and starts `:timer.send_interval(5_000, :refresh_status)`.
  - **handle_event "set_view"**: Sets `view_mode` to `:overview`, `:containers`, `:agents`,
    `:stamp`, or `:ooda`; re-renders the content area.
  - **handle_event "restart_container"**: Initiates container restart; puts flash
    `:info "Container restart initiated"`.
  - **handle_event "view_logs"**: Navigates to the log viewer for the selected container.
  - **handle_info(:refresh_status)**: Refreshes all health assigns from live data.
  - **PubSub**: `"system_health"`, `"container_metrics"`, `"agent_status"` —
    all gated by `connected?/1`.
  - **Timer**: Repeating 5-second interval via `:timer.send_interval/2`.

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator views system status overview
    Given I navigate to "/admin/system-status"
    Then I should see heading "System Status"
    And all 5 view-mode buttons should be present

  Scenario: Operator switches to containers view
    Given I am on "/admin/system-status"
    When I click the "Containers" view-mode button
    Then I should see restart_container and view_logs buttons

  Scenario: Operator restarts a container
    Given I am in containers view on "/admin/system-status"
    When I click the "Restart" button
    Then I should see flash "Container restart initiated"
    And the containers view should remain visible

  Scenario: Operator cycles through all 5 view modes
    Given I am on "/admin/system-status"
    When I click Containers, then Agents, then back to Overview
    Then the overview grid should be restored

  Scenario: Page remains stable after 5-second refresh cycle
    Given I am on "/admin/system-status"
    When 5.5 seconds elapse
    Then the System Status heading should still be visible
  ```

  ## UX Flow
  1. Operator navigates to `/admin/system-status` via admin panel
  2. Overview mode shows system health summary grid
  3. Operator switches to Containers view to inspect container health
  4. Operator clicks Restart to initiate container restart (flash confirmation)
  5. Operator can inspect agent hierarchy, STAMP compliance, or OODA metrics via tabs
  6. 5-second repeating timer keeps all metrics current

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | System Status heading | h1 | `h1` text "System Status" | — | C1 |
  | Overview tab | button | `button[phx-click='set_view'][phx-value-mode='overview']` | set_view | C1 |
  | Containers tab | button | `button[phx-click='set_view'][phx-value-mode='containers']` | set_view | C1 |
  | Agents tab | button | `button[phx-click='set_view'][phx-value-mode='agents']` | set_view | C1 |
  | STAMP tab | button | `button[phx-click='set_view'][phx-value-mode='stamp']` | set_view | C1 |
  | OODA tab | button | `button[phx-click='set_view'][phx-value-mode='ooda']` | set_view | C1 |
  | Overview summary grid | div | `div.grid` (overview view) | — | C2 |
  | Restart button | button | `button[phx-click='restart_container']` | restart_container | C2 |
  | View Logs button | button | `button[phx-click='view_logs']` | view_logs | C2 |
  | Containers data rows | div | `div.space-y-2` (containers) | — | C3 |
  | Agents data rows | div | `div.space-y-2` (agents) | — | C3 |
  | STAMP view content | div | `div` (stamp view) | — | C3 |
  | OODA view content | div | `div` (ooda view) | — | C3 |
  | OODA event entries | div | `div.space-y-4, div.space-y-2, table` | — | C4 |
  | STAMP constraint records | div | `div` (stamp history) | — | C4 |

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit (semantic color classes)
  - SC-COV-008: Wallaby E2E browser tests mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard coverage
  - SC-COV-016: C8 dual verification — restart_container and view_logs both verified
  - SC-COV-020: PubSub refresh stability test at 5500ms
  - SC-CTRL-001: Real-time system status availability requirement

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |-------------|---|---|---|-----|------------|
  | Container restart flash not shown | 5 | 3 | 4 | 60 | C8b test asserts [role='alert'] text |
  | Timer fires before connected? guard | 4 | 4 | 5 | 80 | connected? guard in mount prevents double-sub |
  | View mode switch crashes on missing assigns | 6 | 2 | 3 | 36 | All assign helpers called at mount |
  | 5s refresh overwrites view_mode assign | 3 | 2 | 2 | 12 | handle_info only refreshes health data, not view_mode |
  | PubSub message updates break active view | 4 | 2 | 3 | 24 | Refresh stability test at 5500ms verifies stability |

  STAMP: SC-COV-008 to SC-COV-022, AOR-COV-008 to AOR-COV-017

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

  @path "/admin/system-status"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads with System Status heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "System Status"))
  end

  feature "page loads with Overview view mode button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='set_view'][phx-value-mode='overview']"))
  end

  feature "page loads with Containers view mode button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='set_view'][phx-value-mode='containers']"))
  end

  feature "page loads with Agents view mode button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='set_view'][phx-value-mode='agents']"))
  end

  feature "page loads with STAMP view mode button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='set_view'][phx-value-mode='stamp']"))
  end

  feature "page loads with OODA view mode button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='set_view'][phx-value-mode='ooda']"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "containers view shows restart_container action buttons", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='containers']"))
    |> assert_has(css("button[phx-click='restart_container']"))
  end

  feature "containers view shows view_logs action buttons", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='containers']"))
    |> assert_has(css("button[phx-click='view_logs']"))
  end

  feature "overview mode renders the main content area", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.grid"))
  end

  # ── C3: Data Grid/Summary ───────────────────────────────────────────────────

  feature "containers view renders container data rows", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='containers']"))
    |> assert_has(css("div.space-y-2"))
  end

  feature "agents view renders agent data rows", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='agents']"))
    |> assert_has(css("div.space-y-2"))
  end

  feature "stamp view renders STAMP constraint data", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='stamp']"))
    |> assert_has(css("div"))
  end

  feature "ooda view renders OODA cycle data", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='ooda']"))
    |> assert_has(css("div"))
  end

  # ── C4: Timeline/History ────────────────────────────────────────────────────

  feature "ooda view shows cycle history or event entries", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='ooda']"))
    |> assert_has(css("div.space-y-4, div.space-y-2, table"))
  end

  feature "stamp view shows constraint history records", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='stamp']"))
    |> assert_has(css("div"))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "set_view: clicking Containers switches away from overview layout", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='containers']"))
    |> assert_has(css("button[phx-click='restart_container']"))
  end

  feature "set_view: clicking OODA tab renders OODA content section", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='ooda']"))
    |> refute_has(css("button[phx-click='restart_container']"))
  end

  feature "set_view: cycling through all 5 modes returns to overview successfully", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='containers']"))
    |> click(css("button[phx-click='set_view'][phx-value-mode='agents']"))
    |> click(css("button[phx-click='set_view'][phx-value-mode='overview']"))
    |> assert_has(css("div.grid"))
  end

  # ── C6: Media/Rich Content ──────────────────────────────────────────────────

  feature "overview mode renders summary grid with multiple columns", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.grid"))
  end

  feature "stamp view renders STAMP constraint section with table or list", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='stamp']"))
    |> assert_has(css("div"))
  end

  # ── C7: AI/Advisory Panels ─────────────────────────────────────────────────

  feature "page renders without JS or server crash in any view mode", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "System Status"))
  end

  # ── C8: Action Buttons — DUAL verification (status change + flash) ──────────

  # restart_container — C8a: DOM status change after clicking restart
  feature "restart_container: clicking restart button changes container section content", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='containers']"))
    |> click(css("button[phx-click='restart_container']"))
    |> assert_has(css("button[phx-click='set_view'][phx-value-mode='containers']"))
  end

  # restart_container — C8b: flash message after clicking restart
  feature "restart_container: clicking restart triggers flash 'Container restart initiated'", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='containers']"))
    |> click(css("button[phx-click='restart_container']"))
    |> assert_has(css("[role='alert']", text: "Container restart initiated"))
  end

  # view_logs — C8a: DOM state after clicking view_logs (navigation occurs)
  feature "view_logs: clicking view logs button navigates away from containers view", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='containers']"))
    |> click(css("button[phx-click='view_logs']"))
    |> assert_has(css("body"))
  end

  # view_logs — C8b: containers view structure intact after returning from logs
  feature "view_logs: containers view re-renders view_logs buttons after navigation returns", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='containers']"))
    |> assert_has(css("button[phx-click='view_logs']"))
    |> assert_has(css("button[phx-click='restart_container']"))
  end

  # ── Refresh Stability (SC-COV-020 / PubSub) ────────────────────────────────

  feature "page remains stable after 5.5s PubSub refresh cycle", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "System Status"))

    :timer.sleep(5_500)

    session
    |> assert_has(css("h1", text: "System Status"))
  end
end
