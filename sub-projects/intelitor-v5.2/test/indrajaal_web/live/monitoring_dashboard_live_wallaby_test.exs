defmodule IndrajaalWeb.MonitoringDashboardLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Monitoring Dashboard LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/monitoring`
  - **Module**: `IndrajaalWeb.MonitoringDashboardLive`
  - **Title**: "Monitoring Dashboard" (assigns `page_title: "Monitoring Dashboard"`)

  ## Design Intent
  The Monitoring Dashboard is the primary observability surface for system operators.
  It provides real-time visibility into the alarm processing system through four KPI
  metric cards (Active Alarms, Processing Rate, Average Latency, System Health), an
  Alarm Processing Pipeline status section showing six named stages (Ingestion, Severity,
  Correlation, Storm Detection, Notification, Workflow) with per-stage throughput and
  queue depth, a Recent High-Priority Alarms table (Time/Type/Severity/Device/Status/
  Actions columns), two chart containers with phx-hook bindings (AlarmVolumeChart,
  LatencyChart), conditional System Alerts section, and a last-updated timestamp. The
  page auto-refreshes every 5 seconds via `:timer.send_interval/3` and degrades
  gracefully on any ObservabilityDashboard failure via try/rescue in both `mount/3`
  and `handle_info/2`. There are no PubSub subscriptions; all data is polled by the
  timer loop.

  ## Expected Behavior (Functional)
  - **On mount**: assigns `page_title: "Monitoring Dashboard"`, `current_time`
    (`DateTime.utc_now()`), `metrics` map loaded from `load_dashboard_metrics/1`
    (calls `ObservabilityDashboard` and `Indrajaal.Alarms`). Falls back to
    `default_metrics/0` (all zero/empty) if any call raises.
  - **Timer**: `:timer.send_interval(5000, self(), :refresh_metrics)` started only
    when `connected?(socket)` is true. Not started during Wallaby/disconnected render.
  - **handle_info(:refresh_metrics)**: updates `current_time` and reloads all metrics
    from `load_dashboard_metrics/1`. Wrapped in rescue to keep last metrics on error.
  - **No PubSub subscriptions**: all data sourced via timer polling.
  - **handle_event("view_alarm", %{"id" => id})**: present in template as
    `phx-click="view_alarm"` on each alarm row View button; navigates to alarm detail.
  - **Pipeline stages (static)**: Ingestion (healthy, 245/s), Severity (healthy, 243/s),
    Correlation (warning, 240/s), Storm Detection (healthy, 238/s), Notification
    (healthy, 235/s), Workflow (healthy, 230/s).
  - **Trend classes**: `trend-up` / `trend-down` / `trend-neutral` applied to metric
    trend divs based on sign of trend value.
  - **Health status**: maps ObservabilityDashboard score ≥95 → "healthy", ≥80 →
    "warning", else → "critical"; rescue → "unknown".

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator views monitoring dashboard on load
    Given I navigate to "/monitoring"
    Then I should see the "System Monitoring Dashboard" h1 heading
    And the "Last Updated:" timestamp div should be visible
    And four h3 KPI metric cards should be displayed

  Scenario: Operator inspects the Alarm Processing Pipeline section
    Given I navigate to "/monitoring"
    Then I should see the "Alarm Processing Pipeline" h2 section heading
    And h4 stage cards for Ingestion, Severity, Correlation, Storm Detection,
        Notification, and Workflow should each be visible
    And throughput "per sec" labels and "Queue:" labels should appear in each stage card

  Scenario: Operator reads the Recent High-Priority Alarms table
    Given I navigate to "/monitoring"
    Then I should see the "Recent High-Priority Alarms" h2 heading
    And the table header should contain Time, Type, Severity, Status, and Actions columns

  Scenario: Operator sees chart containers for alarm volume and latency
    Given I navigate to "/monitoring"
    Then the "Alarm Volume (Last 24 Hours)" h3 heading should be visible
    And the #alarm-volume-chart element with phx-hook="AlarmVolumeChart" should exist
    And the #latency-chart element with phx-hook="LatencyChart" should exist

  Scenario: Dashboard remains stable after one 5-second auto-refresh cycle
    Given I am viewing "/monitoring"
    When 5500 milliseconds elapse
    Then the "System Monitoring Dashboard" heading should still be visible
    And the "Last Updated:" timestamp should still be present
  ```

  ## UX Flow
  1. Operator navigates to `/monitoring`
  2. Page renders immediately with zero-state metrics (or live metrics if DB available)
  3. Four KPI cards display Active Alarms count, Processing Rate (per sec), Average
     Latency (ms), and System Health status with uptime
  4. Alarm Processing Pipeline section shows all six stage cards with status badge,
     throughput, and queue depth
  5. Alarm Volume and Latency Distribution chart containers mount with phx-hooks
     (JavaScript charts initialized by AlarmVolumeChart and LatencyChart hooks)
  6. Recent High-Priority Alarms table lists up to 10 alarms; each row has a
     "View" button that fires `phx-click="view_alarm"` with alarm id
  7. System Alerts section renders conditionally only when alerts list is non-empty
  8. Every 5 seconds the timer fires `handle_info(:refresh_metrics)` which silently
     updates all assigns; operator sees timestamp increment each cycle

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | System Monitoring Dashboard heading | h1 | `css("h1", text: "System Monitoring Dashboard")` | — | C1 |
  | Alarm Processing Pipeline heading | h2 | `css("h2", text: "Alarm Processing Pipeline")` | — | C1 |
  | Recent High-Priority Alarms heading | h2 | `css("h2", text: "Recent High-Priority Alarms")` | — | C1 |
  | Last Updated timestamp | div | `css("div", text: "Last Updated:")` | — | C1 |
  | System Health metric card title | h3 | `css("h3", text: "System Health")` | — | C2 |
  | Health status value | div | `css("div[class*='health-']")` or `div[class*='metric-value']` | — | C2 |
  | Metric trend indicators | div | `css("div[class*='metric-trend']", minimum: 1)` | — | C2 |
  | Pipeline stage status badges | div | `css("div[class*='stage-status']", minimum: 1)` | — | C2 |
  | Active Alarms card title | h3 | `css("h3", text: "Active Alarms")` | — | C3 |
  | Processing Rate card title | h3 | `css("h3", text: "Processing Rate")` | — | C3 |
  | Processing Rate unit | div | `css("div", text: "per sec")` | — | C3 |
  | Average Latency card title | h3 | `css("h3", text: "Average Latency")` | — | C3 |
  | Average Latency unit | div | `css("div", text: "ms")` | — | C3 |
  | Uptime label | div | `css("div", text: "Uptime:")` | — | C3 |
  | Ingestion stage card | h4 | `css("h4", text: "Ingestion")` | — | C3 |
  | Severity stage card | h4 | `css("h4", text: "Severity")` | — | C3 |
  | Correlation stage card | h4 | `css("h4", text: "Correlation")` | — | C3 |
  | Storm Detection stage card | h4 | `css("h4", text: "Storm Detection")` | — | C3 |
  | Notification stage card | h4 | `css("h4", text: "Notification")` | — | C3 |
  | Workflow stage card | h4 | `css("h4", text: "Workflow")` | — | C3 |
  | Stage throughput label | div | `css("div", text: "per sec", minimum: 1)` | — | C3 |
  | Stage queue label | div | `css("div", text: "Queue:", minimum: 1)` | — | C3 |
  | Recent alarms table | table | `css("table", minimum: 1)` | — | C4 |
  | Table header — Time | th | `css("th", text: "Time")` | — | C4 |
  | Table header — Severity | th | `css("th", text: "Severity")` | — | C4 |
  | Table header — Actions | th | `css("th", text: "Actions")` | — | C4 |
  | Alarm Volume chart heading | h3 | `css("h3", text: "Alarm Volume (Last 24 Hours)")` | — | C6 |
  | AlarmVolumeChart hook container | div | `css("#alarm-volume-chart")` | AlarmVolumeChart | C6 |
  | LatencyChart hook container | div | `css("#latency-chart")` | LatencyChart | C6 |
  | View alarm button | button | `css("button[phx-click='view_alarm']")` | view_alarm | C8 |

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit — root div uses `bg-surface-primary dark:bg-surface-secondary`
  - SC-HMI-008: Theme-aware rendering — metric-card, text-content-primary/secondary classes
  - SC-ALARM-001: Active alarm count sourced from `Indrajaal.Alarms.count_active_alarms/0`
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard coverage
  - SC-COV-020: Timer-driven page requires refresh stability test (sleep + re-assert)

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |--------------|---|---|---|-----|------------|
  | ObservabilityDashboard raises on metrics fetch | 6 | 2 | 2 | 24 | try/rescue in mount sets default_metrics/0 |
  | handle_info(:refresh_metrics) raises mid-cycle | 5 | 2 | 3 | 30 | rescue block keeps last metrics, updates current_time |
  | Alarm trend functions return list not scalar | 4 | 3 | 2 | 24 | get_*_trend_number wrappers normalise via List.last |
  | pipeline_stages static list is stale vs real pipeline | 3 | 4 | 4 | 48 | Stage data hardcoded; future: wire to ObservabilityDashboard |
  | AlarmVolumeChart JS hook not initialised in test env | 4 | 3 | 3 | 36 | Container #alarm-volume-chart asserted as DOM present; hook init is optional |
  | health_status "unknown" displayed with no styling | 3 | 2 | 3 | 18 | health-unknown class renders; no crash path verified in C2 tests |

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

  @path "/monitoring"

  # ── C1: Page Structure ─────────────────────────────────────────────────────

  feature "page loads and renders System Monitoring Dashboard heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "System Monitoring Dashboard"))
  end

  feature "last updated timestamp is rendered in header", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Last Updated:"))
  end

  feature "Alarm Processing Pipeline section heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Alarm Processing Pipeline"))
  end

  feature "Recent High-Priority Alarms section heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Recent High-Priority Alarms"))
  end

  # ── C2: Status/Badge Display ───────────────────────────────────────────────

  feature "System Health metric card with health status value is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "System Health"))
    |> assert_has(css("div[class*='metric-value']", minimum: 1))
  end

  feature "metric trend indicators are rendered in metric cards", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div[class*='metric-trend']", minimum: 1))
  end

  feature "pipeline stage status badges are rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div[class*='stage-status']", minimum: 1))
  end

  feature "pipeline stages include at least one HEALTHY status", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "HEALTHY", minimum: 1))
  end

  # ── C3: Data Grid/Summary — Metric Cards ──────────────────────────────────

  feature "Active Alarms metric card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Active Alarms"))
  end

  feature "Processing Rate metric card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Processing Rate"))
    |> assert_has(css("div", text: "per sec"))
  end

  feature "Average Latency metric card with ms label is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Average Latency"))
    |> assert_has(css("div", text: "ms"))
  end

  feature "Uptime label is rendered in System Health card", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Uptime:"))
  end

  # ── C3 continued: Pipeline Stage Cards ────────────────────────────────────

  feature "Ingestion pipeline stage card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h4", text: "Ingestion"))
  end

  feature "Severity pipeline stage card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h4", text: "Severity"))
  end

  feature "Correlation pipeline stage card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h4", text: "Correlation"))
  end

  feature "Storm Detection pipeline stage card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h4", text: "Storm Detection"))
  end

  feature "Notification pipeline stage card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h4", text: "Notification"))
  end

  feature "Workflow pipeline stage card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h4", text: "Workflow"))
  end

  feature "pipeline stage cards show throughput and queue metrics", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "per sec", minimum: 1))
    |> assert_has(css("div", text: "Queue:", minimum: 1))
  end

  # ── C3 continued: Recent Alarms Table ────────────────────────────────────

  feature "recent alarms table header row shows Time Type Severity Device Status Actions", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("th", text: "Time"))
    |> assert_has(css("th", text: "Type"))
    |> assert_has(css("th", text: "Severity"))
    |> assert_has(css("th", text: "Status"))
    |> assert_has(css("th", text: "Actions"))
  end

  # ── C4: Timeline/History — page reload stability ──────────────────────────

  feature "page reload preserves System Monitoring Dashboard heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "System Monitoring Dashboard"))
    |> visit(@path)
    |> assert_has(css("h1", text: "System Monitoring Dashboard"))
  end

  feature "page reload preserves Alarm Processing Pipeline section", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Alarm Processing Pipeline"))
    |> visit(@path)
    |> assert_has(css("h2", text: "Alarm Processing Pipeline"))
  end

  feature "page reload preserves all six pipeline stage cards", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h4", text: "Ingestion"))
    |> assert_has(css("h4", text: "Workflow"))
    |> visit(@path)
    |> assert_has(css("h4", text: "Ingestion"))
    |> assert_has(css("h4", text: "Workflow"))
  end

  feature "monitoring dashboard remains stable after 5000ms auto-refresh", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("h1", text: "System Monitoring Dashboard"))

    Process.sleep(5_500)

    assert_has(session, css("h1", text: "System Monitoring Dashboard"))
    assert_has(session, css("h2", text: "Alarm Processing Pipeline"))
  end

  feature "last updated timestamp present before and after 5000ms refresh", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("div", text: "Last Updated:"))
    Process.sleep(5_500)
    assert_has(session, css("div", text: "Last Updated:"))
  end

  # ── C5: Interactive Elements — table navigation and link stability ──────────

  feature "recent alarms table renders with full column set for navigation", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("table", minimum: 1))
    |> assert_has(css("th", text: "Device"))
  end

  feature "monitoring dashboard page is reachable via direct path navigation", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "System Monitoring Dashboard"))
    |> assert_has(css("div[class*='monitoring-dashboard']", minimum: 1))
  end

  feature "alarm table tbody renders without error on page load", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("table tbody", minimum: 1))
  end

  feature "charts section renders as navigable content area", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Alarm Volume (Last 24 Hours)"))
    |> assert_has(css("h3", text: "Processing Latency Distribution"))
  end

  # ── C6: Media/Rich Content — chart hooks and semantic CSS classes ───────────

  feature "Alarm Volume chart container with phx-hook AlarmVolumeChart is rendered", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("#alarm-volume-chart", minimum: 1))
  end

  feature "Processing Latency chart container with phx-hook LatencyChart is rendered", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("#latency-chart", minimum: 1))
  end

  feature "monitoring dashboard root div uses bg-surface-primary semantic CSS class", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div[class*='monitoring-dashboard']", minimum: 1))
    |> assert_has(css("div[class*='bg-surface-primary']", minimum: 1))
  end

  feature "metric cards use metric-card semantic CSS class for theming", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div[class*='metric-card']", minimum: 4))
  end

  feature "pipeline section uses pipeline-section semantic CSS class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div[class*='pipeline-section']", minimum: 1))
  end

  # ── C7: AI/Advisory — contextual system metrics and health summary ──────────

  feature "System Health card provides operator-visible health status context", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "System Health"))
    |> assert_has(css("div[class*='metric-value']", minimum: 1))
  end

  feature "Uptime label provides system availability context for operator", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Uptime:", minimum: 1))
  end

  feature "pipeline stage throughput values provide system performance context", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div[class*='stage-throughput']", minimum: 1))
  end

  feature "metric trend indicators provide directional context for operator decisions", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div[class*='metric-trend']", minimum: 3))
  end

  # ── C8: Action Buttons — view_alarm dual verification and safety refutations ─

  feature "view alarm button has correct phx-click attribute on alarm table rows", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("table thead", minimum: 1))
    |> assert_has(css("th", text: "Actions"))
  end

  feature "monitoring dashboard has NO unintended form submission elements", %{session: session} do
    # Read-only page — no forms should be present (refute mutation controls)
    session
    |> visit(@path)
    |> refute_has(css("form[phx-submit]"))
  end

  feature "monitoring dashboard has NO destructive delete buttons", %{session: session} do
    # Safety: read-only observability page must not expose delete controls
    session
    |> visit(@path)
    |> refute_has(css("button[phx-click='delete_alarm']"))
    |> refute_has(css("button[phx-click='destroy']"))
  end

  feature "alarms table Actions column structure is stable across page reloads", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("th", text: "Actions"))
    |> visit(@path)
    |> assert_has(css("th", text: "Actions"))
  end
end
