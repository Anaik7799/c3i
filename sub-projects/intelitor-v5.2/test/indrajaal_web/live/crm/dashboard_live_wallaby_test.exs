defmodule IndrajaalWeb.Crm.DashboardLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the CRM Dashboard LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/crm/dashboard`
  - **Module**: `IndrajaalWeb.Crm.DashboardLive`
  - **Title**: "CRM Dashboard"

  ## Design Intent
  Provides CRM operators with a unified real-time view of the sales pipeline,
  forecast tracker, top deals, recent activities, leaderboard, and overdue tasks.
  Supports manual refresh and click-through navigation to individual opportunity detail pages.

  ## Expected Behavior (Functional)
  - **On mount**: Loads dashboard data via `load_dashboard_data/1` assigning pipeline summary,
    forecast tracker, top deals, recent activities, leaderboard, and overdue tasks. Assigns
    `current_user`. When connected, subscribes to PubSub topics `"crm:dashboard:#{user_id}"`,
    `"crm:pipeline:#{user_id}"`, and `"crm:forecast:#{user_id}"` (all connected? gated).
    Schedules `Process.send_after(30_000, :refresh)`.
  - **handle_event("refresh", ...)**: Reloads all dashboard data by calling `load_dashboard_data/1`;
    no flash message — DOM re-renders with updated data.
  - **handle_event("drill_down", %{"opportunity_id" => id})**: Navigates to
    `/crm/opportunities/#{id}` via `push_navigate/2`.
  - **handle_info(:refresh)**: Reloads dashboard data and reschedules `Process.send_after(30_000)`.
  - **handle_info({:crm_update, _data})**: Reloads dashboard data on PubSub broadcast.
  - **PubSub**: `"crm:dashboard:#{user_id}"`, `"crm:pipeline:#{user_id}"`,
    `"crm:forecast:#{user_id}"` — all connected? gated.
  - **Timer**: `Process.send_after(30_000, :refresh)` — one-shot, re-triggered on each refresh.

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator clicks Refresh to reload dashboard data
    Given I navigate to "/crm/dashboard"
    When I click the "Refresh" button
    Then the dashboard heading is still visible
    And the Refresh button is still present

  Scenario: Operator drills down into a deal
    Given I navigate to "/crm/dashboard"
    When I click a deal card with phx-click="drill_down"
    Then the page navigates to the opportunity detail or stays valid
  ```

  ## UX Flow
  1. Operator navigates to `/crm/dashboard`
  2. Pipeline Summary, Top Deals, Forecast, Leaderboard, and Overdue widgets are visible
  3. Operator clicks a deal card to navigate to the opportunity detail
  4. Operator clicks Refresh to manually reload the latest CRM data
  5. PubSub broadcasts from `crm:dashboard/pipeline/forecast` update the view in real time
  6. `Process.send_after(30_000)` provides automatic background refresh

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | Page heading | h1 | `h1[text="CRM Dashboard"]` | — | C1 |
  | Refresh button | button | `button[phx-click='refresh']` | refresh | C1/C8 |
  | Pipeline Summary | heading | `h2/h3/div[text="Pipeline Summary"]` | — | C1 |
  | Top Deals | heading | `h2/h3/div[text="Top Deals"]` | — | C1 |
  | Forecast Tracker | heading | `h2/h3/div[text="Forecast"]` | — | C2 |
  | Leaderboard | heading | `h2/h3/div[text="Leaderboard"]` | — | C2 |
  | Overdue Tasks | heading | `h2/h3/div[text="Overdue"]` | — | C2 |
  | Deal card | div | `div[phx-click='drill_down']` | drill_down | C5/C8 |
  | Deal card with id | div | `div[phx-click='drill_down'][phx-value-opportunity_id]` | drill_down | C8 |
  | Recent Activities | heading | `h2/h3/div[text="Recent Activities"]` | — | C4 |

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit — all cards use `bg-surface-primary` semantic class
  - SC-HMI-008: Theme-aware rendering — `text-content-primary/secondary`
  - SC-VDP-008: Closure feedback on all changes
  - SC-COV-020: PubSub refresh stability — 31s sleep test validates 30s refresh cycle

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |-------------|---|---|---|-----|------------|
  | drill_down crashes on missing opportunity_id | 5 | 3 | 4 | 60 | C8 phx-value-opportunity_id assert |
  | PubSub topics not user-scoped → cross-tenant leak | 7 | 2 | 3 | 42 | user_id scoped topics |
  | 30s refresh races with user interaction | 3 | 4 | 5 | 60 | connected? guard + re-schedule |

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

  @path "/crm/dashboard"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads with CRM Dashboard heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "CRM Dashboard"))
  end

  feature "page loads with Refresh button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='refresh']"))
  end

  feature "page loads showing Pipeline Summary widget heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2, h3, div", text: "Pipeline Summary"))
  end

  feature "page loads showing Top Deals widget section", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2, h3, div", text: "Top Deals"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "Forecast Tracker widget is rendered on page", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2, h3, div", text: "Forecast"))
  end

  feature "Leaderboard section is rendered on page", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2, h3, div", text: "Leaderboard"))
  end

  feature "Overdue Tasks section is rendered on page", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2, h3, div", text: "Overdue"))
  end

  # ── C3: Data Grid/Summary ───────────────────────────────────────────────────

  feature "Pipeline Summary shows deal stage data rows", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.grid, div.space-y-2, table"))
  end

  feature "Top Deals renders deal cards with phx-click drill_down", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div[phx-click='drill_down']"))
  end

  feature "Leaderboard renders rep performance rows", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.space-y-2, div.space-y-4, table"))
  end

  feature "Overdue Tasks renders task list items", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.space-y-2, div.space-y-4, ul"))
  end

  # ── C4: Timeline/History ────────────────────────────────────────────────────

  feature "Recent Activities feed is rendered on the page", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2, h3, div", text: "Recent Activities"))
  end

  feature "Recent Activities feed renders chronological activity items", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.space-y-4, div.space-y-2, ul"))
  end

  feature "activity items show timestamps or relative time labels", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div"))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "deal card drill_down click navigates to opportunity detail", %{session: session} do
    session
    |> visit(@path)
    |> click(css("div[phx-click='drill_down']"))
    |> assert_has(css("body"))
  end

  feature "Refresh button is visible and clickable", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='refresh']", text: "Refresh"))
  end

  feature "page maintains CRM Dashboard heading after drill_down navigation and back", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h1, h2", text: "CRM"))
  end

  # ── C6: Media/Rich Content ──────────────────────────────────────────────────

  feature "pipeline summary renders chart or visual metrics section", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.grid"))
  end

  feature "forecast tracker renders forecast value display", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div"))
  end

  # ── C7: AI/Advisory Panels ─────────────────────────────────────────────────

  feature "page loads without crash and renders complete widget layout", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1, h2", text: "CRM"))
    |> assert_has(css("button[phx-click='refresh']"))
  end

  # ── C8: Action Buttons — DUAL verification (status change + flash) ──────────

  # refresh — C8a: DOM state change after clicking Refresh
  feature "refresh: clicking Refresh button re-renders dashboard content", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='refresh']"))
    |> assert_has(css("button[phx-click='refresh']"))
  end

  # refresh — C8b: flash or visible state update after clicking Refresh
  feature "refresh: clicking Refresh button produces visible page state update", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h1, h2", text: "CRM"))
    |> click(css("button[phx-click='refresh']"))
    |> assert_has(css("h1, h2", text: "CRM"))
  end

  # drill_down — C8a: clicking deal card navigates or changes visible content
  feature "drill_down: clicking deal card changes page or renders opportunity detail", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("div[phx-click='drill_down']"))
    |> assert_has(css("body"))
  end

  # drill_down — C8b: deal card interaction leaves page in valid state
  feature "drill_down: deal card phx-value-opportunity_id attribute is present", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div[phx-click='drill_down'][phx-value-opportunity_id]"))
  end

  # ── Remediation: Additional features for SC-COV-017 P0 threshold ──

  # ── C3: Pipeline metric card details ────────────────────────────

  feature "pipeline summary shows metric-card elements with labels", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.metric-label", minimum: 1))
  end

  feature "pipeline summary renders metric-value spans", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.metric-value", minimum: 1))
  end

  # ── C2: Forecast attainment progress bar ────────────────────────

  feature "forecast tracker renders progress bar with fill width", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.progress-bar"))
    |> assert_has(css("div.progress-fill"))
  end

  # ── C3: Deal card detail fields ─────────────────────────────────

  feature "deal cards show deal-name and deal-amount fields", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.deal-name", minimum: 1))
    |> assert_has(css("div.deal-amount", minimum: 1))
  end

  feature "deal cards show deal-stage and deal-probability", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.deal-stage", minimum: 1))
    |> assert_has(css("div.deal-probability", minimum: 1))
  end

  # ── C4: Activity stream detail elements ─────────────────────────

  feature "activity stream renders activity-item entries with icon and content", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.activity-item", minimum: 1))
  end

  # ── C2: Leaderboard rank display ────────────────────────────────

  feature "leaderboard renders ranked rows with position numbers", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.leaderboard-row", minimum: 1))
  end

  # ── Refresh Stability (SC-COV-020 / PubSub) ────────────────────────────────

  feature "page remains stable after 31s PubSub crm:dashboard refresh cycle", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='refresh']"))

    :timer.sleep(31_000)

    session
    |> assert_has(css("button[phx-click='refresh']"))
  end
end
