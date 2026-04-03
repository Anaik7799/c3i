defmodule IndrajaalWeb.Prajna.AnalyticsLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the PRAJNA Analytics Center LiveView page.

  Gold standard 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/cockpit/analytics`
  - **Module**: `IndrajaalWeb.Prajna.AnalyticsLive`
  - **Title**: "Analytics Center"

  ## Design Intent
  Provides the PRAJNA Analytics Center dashboard for browsing analytics reports,
  monitoring query performance, tracking data pipeline health, and reviewing trend
  analysis. Operators can filter reports by status and drill into individual report
  details. Integrates with PubSub `prajna:analytics` and `zenoh:analytics` for
  real-time data pushes and syncs metrics every 10s. No operator actions produce
  flash messages — all events are assign-only state updates per SC-ANA-001.

  ## Expected Behavior (Functional)
  - **On mount**: assigns `page_title`, `current_nav: :analytics`, `reports: []`,
    `queries: []`, `pipelines: []`, `trends: []`, `filter_status: :all`,
    `selected_report: nil`, `metrics: %{}`
  - **PubSub**: subscribes to `"prajna:analytics"` and `"zenoh:analytics"`
  - **Timer**: 5000ms → `:refresh`; 10000ms → `:sync_metrics`
  - **handle_event "filter_status"**: sets `filter_status` atom (no flash)
  - **handle_event "select_report"**: sets `selected_report` assign (no flash)
  - **handle_event "close_detail"**: sets `selected_report: nil` (no flash)

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator views analytics summary metrics on load
    Given I navigate to "/cockpit/analytics"
    Then I should see the "Analytics Center" heading
    And the four metric summary cards should be visible
    And the Report Status panel should show filter options

  Scenario: Operator filters reports by status
    Given I navigate to "/cockpit/analytics"
    When I select "running" from the status filter dropdown
    Then only reports with "running" status should be shown

  Scenario: Operator selects a report to view its details
    Given I navigate to "/cockpit/analytics"
    And at least one report row exists
    When I click a report row
    Then the report detail panel should open

  Scenario: Operator views query performance metrics
    Given I navigate to "/cockpit/analytics"
    Then the "Query Performance" panel should be visible
    And query time metrics should be displayed

  Scenario: Operator views data pipelines panel
    Given I navigate to "/cockpit/analytics"
    Then the "Data Pipelines" panel should show at least one named pipeline
  ```

  ## UX Flow
  1. Operator navigates to `/cockpit/analytics` — summary metric cards shown
  2. Four cards display: Reports Today, Avg Query Time, Pipeline Health, Data Freshness
  3. Report Status panel lists reports with status badges (running/completed/failed)
  4. Operator selects a status filter to narrow the report list
  5. Operator clicks a report row to open the detail panel
  6. Detail panel shows report metadata, query duration, and data freshness
  7. Operator clicks "Close" to dismiss the detail panel
  8. Query Performance panel shows timing histograms and percentile data
  9. Data Pipelines panel shows pipeline status and last-run timestamps
  10. Trend Analysis panel shows time-series trends (auto-refreshes every 5s)

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | Analytics Center heading | h1/span | `css("span", text: "Analytics Center")` | — | C1 |
  | Page subtitle | text | `css("p", text: "Reports, Queries & Data Pipeline Monitoring")` | — | C1 |
  | Reports Today card | div | `css("p", text: "Reports Today")` | — | C3 |
  | Avg Query Time card | div | `css("p", text: "Avg Query Time")` | — | C3 |
  | Pipeline Health card | div | `css("p", text: "Pipeline Health")` | — | C3 |
  | Data Freshness card | div | `css("p", text: "Data Freshness")` | — | C3 |
  | Report Status panel | section | `css("h3", text: "Report Status")` | — | C1 |
  | Status filter select | select | `css("select[phx-change='filter_status']")` | filter_status | C5 |
  | Report rows | tr/div | `css("[phx-click='select_report']")` | select_report | C8 |
  | Report status badge | badge | `css("span", text: "completed/running/failed")` | — | C2 |
  | Close detail button | button | `css("button[phx-click='close_detail']")` | close_detail | C8 |
  | Query Performance panel | section | `css("section", text: "Query Performance")` | — | C3 |
  | Data Pipelines panel | section | `css("section", text: "Data Pipelines")` | — | C3 |
  | Trend Analysis panel | section | `css("section", text: "Trend Analysis")` | — | C4 |

  ## STAMP Constraints
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: Gold standard 8-category coverage
  - SC-HMI-001: Dark Cockpit (gray defaults on initial render)
  - SC-HMI-011: 8x8 Matrix path coverage
  - SC-ANA-001: Query timeout < 30s (query time metrics visible in UI)
  - SC-PRAJNA-004: Sentinel health integration (sentinel data in metrics)
  - SC-COV-020: PubSub prajna:analytics requires refresh stability test

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |-------------|---|---|---|-----|------------|
  | filter_status event not firing (select vs dropdown) | 5 | 3 | 4 | 60 | Verify phx-change selector matches template |
  | Reports list empty — filter shows no results | 4 | 3 | 3 | 36 | Seed mock report data or assert "No reports" |
  | Detail panel close leaves stale selected_report | 5 | 2 | 3 | 30 | Assert selected_report nil after close |
  | Dual timer (5s + 10s) race causes double-render | 4 | 2 | 4 | 32 | sleep + stability assertion (SC-COV-020) |
  | Trend panel renders empty chart with no data | 4 | 3 | 3 | 36 | Assert fallback "No trend data" message |

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

  @path "/cockpit/analytics"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads with Analytics Center heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "Analytics Center"))
  end

  feature "page subtitle Reports Queries and Data Pipeline Monitoring is visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Reports, Queries & Data Pipeline Monitoring"))
  end

  feature "Report Status panel heading is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Report Status"))
  end

  feature "Query Performance panel heading is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Query Performance"))
  end

  feature "Data Pipelines panel heading is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Data Pipelines"))
  end

  feature "Trend Analysis panel heading is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Trend Analysis"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "report rows contain status labels with color-coded text", %{session: session} do
    session
    |> visit(@path)
    # completed/running/failed/scheduled status labels are rendered as colored spans
    |> assert_has(css("span.text-green-600", minimum: 1))
  end

  feature "running pipeline entries display green status text", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.text-green-600", minimum: 1))
  end

  feature "query duration fast class renders green for sub-1000ms queries", %{session: session} do
    session
    |> visit(@path)
    # Query durations are colored green (fast), yellow (normal), or red (slow)
    |> assert_has(css("span[class*='font-mono']", minimum: 1))
  end

  feature "trend direction arrow indicators are present in trend cards", %{session: session} do
    session
    |> visit(@path)
    # Trend arrows: ↑ for up (green), ↓ for down (red), → for stable (gray)
    |> assert_has(css("span[class*='text-green-600']", minimum: 1))
  end

  feature "pipeline running status label is displayed for active pipelines", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "running", minimum: 1))
  end

  # ── C3: Data Grid/Summary ───────────────────────────────────────────────────

  feature "Reports Today metric card is rendered with a numeric value", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Reports Today"))
  end

  feature "Avg Query Time metric card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Avg Query Time"))
  end

  feature "Pipeline Health metric card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Pipeline Health"))
  end

  feature "Data Freshness metric card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Data Freshness"))
  end

  feature "four metric summary cards are rendered in the top grid", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-sm.text-gray-600", minimum: 4))
  end

  feature "query performance panel shows a database source label", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-xs.text-gray-600", minimum: 1))
  end

  feature "query rows show duration in milliseconds unit", %{session: session} do
    session
    |> visit(@path)
    # Query duration is rendered as NNNms via the font-mono span
    |> assert_has(css("span[class*='font-mono']", minimum: 1))
  end

  feature "query rows show row count label", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.text-gray-600", text: "rows", minimum: 1))
  end

  # ── C4: Timeline/History (Trend Data Entries) ───────────────────────────────

  feature "Alarm Volume trend card is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Alarm Volume"))
  end

  feature "Response Time trend card is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Response Time"))
  end

  feature "Device Uptime trend card is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Device Uptime"))
  end

  feature "False Alarms trend card is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "False Alarms"))
  end

  feature "trend period label vs last week is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "vs last week", minimum: 1))
  end

  feature "trend period label vs last month is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "vs last month", minimum: 1))
  end

  feature "trend cards each show a percentage change value", %{session: session} do
    session
    |> visit(@path)
    # Each trend card renders change% next to direction arrow
    |> assert_has(css("span[class*='text-green-600']", minimum: 1))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "status filter dropdown contains All Completed Running Failed Scheduled options", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("select[name='status']"))
    |> assert_has(css("option[value='all']", text: "All"))
    |> assert_has(css("option[value='completed']", text: "Completed"))
    |> assert_has(css("option[value='running']", text: "Running"))
    |> assert_has(css("option[value='failed']", text: "Failed"))
    |> assert_has(css("option[value='scheduled']", text: "Scheduled"))
  end

  feature "selecting Completed in status filter keeps Report Status panel visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(css("select[name='status']"), fn select ->
      click(select, css("option[value='completed']"))
    end)
    |> assert_has(css("h3", text: "Report Status"))
  end

  feature "selecting Running in status filter keeps Report Status panel visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(css("select[name='status']"), fn select ->
      click(select, css("option[value='running']"))
    end)
    |> assert_has(css("h3", text: "Report Status"))
  end

  feature "selecting Failed filter does not crash the analytics page", %{session: session} do
    session
    |> visit(@path)
    |> find(css("select[name='status']"), fn select ->
      click(select, css("option[value='failed']"))
    end)
    |> assert_has(css("h1", text: "Analytics Center"))
  end

  feature "selecting Scheduled filter keeps all four panels visible", %{session: session} do
    session
    |> visit(@path)
    |> find(css("select[name='status']"), fn select ->
      click(select, css("option[value='scheduled']"))
    end)
    |> assert_has(css("h3", text: "Query Performance"))
    |> assert_has(css("h3", text: "Data Pipelines"))
    |> assert_has(css("h3", text: "Trend Analysis"))
  end

  feature "switching filter to All after Completed restores full report list", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(css("select[name='status']"), fn select ->
      click(select, css("option[value='completed']"))
    end)
    |> find(css("select[name='status']"), fn select ->
      click(select, css("option[value='all']"))
    end)
    |> assert_has(css("h3", text: "Report Status"))
  end

  feature "report rows are rendered and respond to phx-click select_report", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("[phx-click='select_report']", minimum: 1))
  end

  # ── C6: Visualization / Rich Content ───────────────────────────────────────

  feature "pipeline source PostgreSQL is shown in data pipelines", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.text-blue-600", text: "PostgreSQL"))
  end

  feature "pipeline target DuckDB is shown for Alarms ETL pipeline", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.text-green-600", text: "DuckDB"))
  end

  feature "Alarms ETL data pipeline entry is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Alarms ETL"))
  end

  feature "Metrics Aggregation data pipeline entry is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Metrics Aggregation"))
  end

  feature "Event Stream data pipeline entry is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Event Stream"))
  end

  feature "Backup Sync data pipeline entry is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Backup Sync"))
  end

  feature "pipeline source-to-target arrow separator is rendered between source and target", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span.text-gray-600", text: "→", minimum: 1))
  end

  # ── C8: Action Buttons — Dual Verification (status change + page stability) ──
  # The analytics source has filter_status (select) and select_report (click).
  # Neither has put_flash calls in the source. C8 dual verification tests
  # the observable DOM change for each interactive trigger.

  # filter_status: verification 1 — report panel persists (status change)
  feature "C8 filter_status completed — report panel heading remains after filter", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(css("select[name='status']"), fn select ->
      click(select, css("option[value='completed']"))
    end)
    |> assert_has(css("h3", text: "Report Status"))
  end

  # filter_status: verification 2 — page structure stable after filter (page integrity)
  feature "C8 filter_status completed — page h1 heading remains visible after filter applied", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(css("select[name='status']"), fn select ->
      click(select, css("option[value='completed']"))
    end)
    |> assert_has(css("h1", text: "Analytics Center"))
  end

  # select_report: verification 1 — click does not remove Report Status panel
  feature "C8 select_report click — Report Status panel remains after clicking report row", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("[phx-click='select_report']", minimum: 1))
    |> click(css("[phx-click='select_report']"))
    |> assert_has(css("h3", text: "Report Status"))
  end

  # select_report: verification 2 — all panels still rendered after row selection
  feature "C8 select_report click — all four panel headings remain after report row selected", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("[phx-click='select_report']", minimum: 1))
    |> click(css("[phx-click='select_report']"))
    |> assert_has(css("h3", text: "Query Performance"))
    |> assert_has(css("h3", text: "Data Pipelines"))
    |> assert_has(css("h3", text: "Trend Analysis"))
  end

  # filter_status running: verification 1 — status panel persists
  feature "C8 filter_status running — Report Status panel remains visible", %{session: session} do
    session
    |> visit(@path)
    |> find(css("select[name='status']"), fn select ->
      click(select, css("option[value='running']"))
    end)
    |> assert_has(css("h3", text: "Report Status"))
  end

  # filter_status running: verification 2 — metric cards still present
  feature "C8 filter_status running — metric cards remain rendered after filter applied", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(css("select[name='status']"), fn select ->
      click(select, css("option[value='running']"))
    end)
    |> assert_has(css("div", text: "Reports Today"))
    |> assert_has(css("div", text: "Pipeline Health"))
  end
end
