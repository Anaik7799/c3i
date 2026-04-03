defmodule IndrajaalWeb.SystemStatusLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the System Status LiveView admin page.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/admin/system-status`
  - **Module**: `IndrajaalWeb.SystemStatusLive`
  - **Title**: "System Status"

  ## Design Intent
  Provides operators with a comprehensive real-time view of system health across
  five dimensions: overview, container details, agent hierarchy, STAMP compliance,
  and OODA loop metrics. Supports container restart actions from within the UI.

  ## Expected Behavior (Functional)
  - **On mount**: Assigns `page_title`, `current_time`, `view_mode: :overview`,
    then calls `assign_system_health/1`, `assign_container_status/1`,
    `assign_agent_hierarchy/1`, `assign_database_health/1`,
    `assign_stamp_compliance/1`, `assign_ooda_metrics/1`. When connected,
    subscribes to PubSub `"system_health"`, `"container_metrics"`,
    `"agent_status"` and starts `:timer.send_interval(5_000, :refresh_status)`.
  - **handle_event("set_view", %{"mode" => mode})**: Sets `view_mode` to the
    selected atom (:overview | :containers | :agents | :stamp | :ooda).
  - **handle_event("restart_container", ...)**: Initiates container restart; puts
    flash `"Container restart initiated"`.
  - **handle_event("view_logs", ...)**: Navigates to the log viewer for a container.
  - **handle_info(:refresh_status)**: Refreshes all health assigns.
  - **PubSub**: `"system_health"`, `"container_metrics"`, `"agent_status"`.
  - **Timer**: `:timer.send_interval(5_000)` — repeating 5-second refresh.

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator restarts a container from the containers view
    Given I navigate to "/admin/system-status"
    When I click the "Containers" view-mode button
    And I click the "Restart" button for a container
    Then I see the flash "Container restart initiated"
    And the containers panel is still visible

  Scenario: Operator views OODA loop metrics
    Given I navigate to "/admin/system-status"
    When I click the "OODA" view-mode button
    Then I see the "Cybernetic Feedback Loops" section
    And the Emergency Loop and Fast Loop cards are present
  ```

  ## UX Flow
  1. Operator navigates to `/admin/system-status` via the admin panel
  2. Overview mode shows health summary cards and resource utilization bars
  3. Operator switches to Containers view to inspect individual container health
  4. Operator can restart a container with the Restart button (flash confirmation)
  5. Switching to Agents, STAMP, or OODA view shows domain-specific metrics
  6. Page auto-refreshes every 5 seconds via timer

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | Page heading | h1 | `h1[text="System Status"]` | — | C1 |
  | View-mode buttons | button | `button[phx-click='set_view']` | set_view | C5 |
  | Overall status badge | span | `span[text~=HEALTHY]` | — | C2 |
  | Last Updated label | span | `span[text~="Last Updated"]` | — | C2 |
  | System Health card | h4 | `h4[text="System Health"]` | — | C2 |
  | Containers card | h4 | `h4[text="Containers"]` | — | C2 |
  | Resource Utilization | h3 | `h3[text="Resource Utilization"]` | — | C3 |
  | CPU bar | span | `span[text="CPU"]` | — | C3 |
  | Memory bar | span | `span[text="Memory"]` | — | C3 |
  | Container status badge | span | `span.running` | — | C6 |
  | Restart button | button | `button[phx-click='restart_container']` | restart_container | C8 |
  | View Logs button | button | `button[phx-click='view_logs']` | view_logs | C8 |
  | STAMP Compliance | h3 | `h3[text="STAMP Compliance"]` | — | C4 |
  | OODA Fast Loop | h4 | `h4[text="Fast Loop"]` | — | C4 |

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit — `bg-surface-primary` semantic classes
  - SC-OBS-065: Observability requirements — real-time health monitoring
  - SC-VDP-008: Closure feedback on all changes — flash on restart
  - SC-CTRL-001: System status available in real-time

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |-------------|---|---|---|-----|------------|
  | Container restart flash not shown | 5 | 3 | 4 | 60 | C8 dual verification |
  | Timer fires before LiveView connected — PubSub race | 4 | 4 | 5 | 80 | connected? guard in mount |
  | View mode switch crashes on missing assigns | 6 | 2 | 3 | 36 | All assign helpers called at mount |

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

  feature "page loads with Overview view-mode button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='set_view']", text: "Overview"))
  end

  feature "page loads with Containers view-mode button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='set_view']", text: "Containers"))
  end

  feature "page loads with Agents view-mode button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='set_view']", text: "Agents"))
  end

  feature "page loads with STAMP view-mode button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='set_view']", text: "STAMP"))
  end

  feature "page loads with OODA view-mode button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='set_view']", text: "OODA"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "overall status badge is shown in the header", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: ~r/HEALTHY|WARNING|CRITICAL/i))
  end

  feature "Last Updated timestamp is displayed in the header", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: ~r/Last Updated/))
  end

  feature "overview panel shows System Health status card", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h4", text: "System Health"))
  end

  feature "overview panel shows Containers status card", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h4", text: "Containers"))
  end

  feature "overview panel shows Database status card", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h4", text: "Database"))
  end

  # ── C3: Data Grid/Summary ───────────────────────────────────────────────────

  feature "overview panel shows Resource Utilization section", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Resource Utilization"))
  end

  feature "overview panel shows CPU resource bar label", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "CPU"))
  end

  feature "overview panel shows Memory resource bar label", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Memory"))
  end

  feature "overview panel shows Recent Events section", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Recent Events"))
  end

  feature "switching to containers view shows container names", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='containers']"))
    |> assert_has(css("h4", text: "indrajaal-app"))
  end

  feature "switching to agents view shows Executive section heading", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='agents']"))
    |> assert_has(css("h3", text: ~r/Executive/))
  end

  feature "switching to agents view shows Total Agents stat", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='agents']"))
    |> assert_has(css("span", text: "Total Agents"))
  end

  # ── C4: Timeline / History ──────────────────────────────────────────────────

  feature "switching to STAMP view shows STAMP Compliance heading", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='stamp']"))
    |> assert_has(css("h3", text: "STAMP Compliance"))
  end

  feature "switching to STAMP view shows compliance score percentage", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='stamp']"))
    |> assert_has(css("div", text: ~r/\d+%/))
  end

  feature "switching to OODA view shows Emergency Loop card", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='ooda']"))
    |> assert_has(css("h4", text: "Emergency Loop"))
  end

  feature "switching to OODA view shows Fast Loop card", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='ooda']"))
    |> assert_has(css("h4", text: "Fast Loop"))
  end

  feature "switching to OODA view shows Cybernetic Feedback Loops section", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='ooda']"))
    |> assert_has(css("h3", text: "Cybernetic Feedback Loops"))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "set_view switches to containers panel on click", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='containers']"))
    |> assert_has(css("button[phx-click='restart_container']"))
  end

  feature "restart_container button is present in containers view", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='containers']"))
    |> assert_has(css("button[phx-click='restart_container']"))
  end

  feature "view_logs button is present in containers view", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='containers']"))
    |> assert_has(css("button[phx-click='view_logs']"))
  end

  # ── C6: Media / Rich Content ─────────────────────────────────────────────────

  feature "containers view shows status-badge span for each container", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='containers']"))
    |> assert_has(css("span.running"))
  end

  feature "containers view shows PHICS Latency label", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='containers']"))
    |> assert_has(css("span", text: "PHICS Latency"))
  end

  feature "agents view shows Domain Supervisors section", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='agents']"))
    |> assert_has(css("h3", text: ~r/Domain Supervisors/))
  end

  # ── C8: Action Buttons — DUAL verification (status change + flash) ──────────

  # restart_container — C8a: flash "Container restart initiated"
  feature "restart_container: clicking Restart triggers Container restart initiated flash", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='containers']"))
    |> assert_has(css("button[phx-click='restart_container']"))
    |> click(css("button[phx-click='restart_container']"))
    |> assert_has(css("[role='alert']", text: "Container restart initiated"))
  end

  # restart_container — C8b: containers panel remains visible after restart (status change)
  feature "restart_container: containers panel remains after restart action", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='containers']"))
    |> click(css("button[phx-click='restart_container']"))
    |> assert_has(css("h4", text: "indrajaal-app"))
  end

  # set_view — C8a: view switches to agents (status change)
  feature "set_view: clicking Agents tab switches panel content to Agents view", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='agents']"))
    |> assert_has(css("h3", text: ~r/Executive/))
  end

  # set_view — C8b: clicking OODA switches to OODA content
  feature "set_view: clicking OODA tab shows OODA loop content", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='set_view'][phx-value-mode='ooda']"))
    |> assert_has(css("h4", text: "Standard Loop"))
  end
end
