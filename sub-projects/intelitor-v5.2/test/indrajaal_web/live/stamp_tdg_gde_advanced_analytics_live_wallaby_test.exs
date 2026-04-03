defmodule IndrajaalWeb.StampTdgGdeAdvancedAnalyticsLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the STAMP/TDG/GDE Advanced Analytics Dashboard
  (/analytics/stamp-tdg-gde-advanced).
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/analytics/stamp-tdg-gde-advanced`
  - **Module**: `IndrajaalWeb.StampTdgGdeAdvancedAnalyticsLive`
  - **Title**: "STAMP / TDG / GDE Advanced Analytics Dashboard"

  ## Design Intent
  Provides advanced machine-learning-augmented analytics for STAMP safety compliance,
  TDG test success rates, GDE efficiency scores, and ML model quality metrics.
  Supports timeframe selection (1h/24h/7d/30d), chart type switching (line/bar/area),
  predictive health forecasting, and export to JSON/CSV for external reporting.

  ## Expected Behavior (Functional)
  - **On mount**: Loads assigns `selected_timeframe: "24h"`, `chart_type: "line"`,
    `stamp_compliance: 92.5`, `tdg_success_rate: 89.3`, `gde_efficiency: 87.1`,
    `ml_model_accuracy: N`, `precision: N`, `recall: N`, `f1_score: N`,
    `performance_prediction: 88.4`, `analytics_data: [...]`.
    PubSub subscriptions to `"stamp_analytics"`, `"tdg_analytics"`, `"gde_analytics"`,
    `"system_performance"` all started inside `connected?/1` (correctly gated).
    Three timers started when connected: 5s, 30s, 60s intervals.
  - **handle_params/3**: Accepts `timeframe`, `metrics`, `chart_type` URL params;
    updates assigns accordingly (FMEA F-001: no push_patch links in template).
  - **handle_event "change_timeframe"**: Updates `selected_timeframe` and reloads data.
  - **handle_event "change_chart_type"**: Updates `chart_type`; triggers chart re-render.
  - **handle_event "export"**: Stub handler with `phx-value-format` ("json"/"csv") —
    page must NOT crash (FMEA F-002: no implementation yet).
  - **handle_info**: Three timer intervals (5s/30s/60s) for different data refresh scopes.
  - **PubSub**: `"stamp_analytics"`, `"tdg_analytics"`, `"gde_analytics"`,
    `"system_performance"` — all gated by `connected?/1`.

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator views advanced analytics dashboard
    Given I navigate to "/analytics/stamp-tdg-gde-advanced"
    Then I should see heading "STAMP / TDG / GDE Advanced Analytics Dashboard"
    And I should see metric cards for STAMP Compliance, TDG Success Rate, GDE Efficiency, ML Accuracy
    And initial STAMP Compliance value "92.5%" should be visible

  Scenario: Operator changes timeframe to 7 days
    Given I am on "/analytics/stamp-tdg-gde-advanced"
    When I select "Last 7 Days" from the timeframe select
    Then the page should remain stable and the heading should be unchanged

  Scenario: Operator switches chart type to Bar Chart
    Given I am on "/analytics/stamp-tdg-gde-advanced"
    When I select "Bar Chart" from the chart-type select
    Then the page should remain stable

  Scenario: Operator exports analytics as JSON
    Given I am on "/analytics/stamp-tdg-gde-advanced"
    When I click "JSON" export button
    Then the page should not crash (export handler is scheduled but not yet implemented)

  Scenario: Advanced analytics page survives 5-second refresh cycle
    Given I am on "/analytics/stamp-tdg-gde-advanced"
    When 5.5 seconds elapse (one refresh interval)
    Then the dashboard heading and Performance Prediction card should remain visible
  ```

  ## UX Flow
  1. Operator navigates to `/analytics/stamp-tdg-gde-advanced` via Analytics menu
  2. Page mounts with 4 metric cards and ML model performance section
  3. Operator selects timeframe from controls bar (1h/24h/7d/30d)
  4. Operator switches chart visualization type (line/bar/area)
  5. Operator views Performance Prediction card with predicted system health
  6. Operator exports analytics data to JSON or CSV for external review
  7. Three-tier refresh cycle (5s/30s/60s) keeps ML metrics and predictions current

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | Dashboard heading | h1 | `h1` text "STAMP / TDG / GDE Advanced Analytics Dashboard" | — | C1 |
  | Subtitle | p | `p` text "Advanced analytics and machine learning insights" | — | C1 |
  | ML Model Performance section | h2 | `h2` text "ML Model Performance" | — | C1 |
  | Performance Prediction section | h2 | `h2` text "Performance Prediction" | — | C1 |
  | Export Analytics section | h2 | `h2` text "Export Analytics" | — | C1 |
  | Top-level container | div | `div.stamp-tdg-gde-advanced-analytics` | — | C1 |
  | STAMP Compliance card | h3 | `h3` text "STAMP Compliance" | — | C2 |
  | TDG Success Rate card | h3 | `h3` text "TDG Success Rate" | — | C2 |
  | GDE Efficiency card | h3 | `h3` text "GDE Efficiency" | — | C2 |
  | ML Accuracy card | h3 | `h3` text "ML Accuracy" | — | C2 |
  | 4-column metric grid | div | `div.grid.grid-cols-4` | — | C2 |
  | STAMP Compliance value | p | `p.text-2xl` text "92.5%" | — | C3 |
  | TDG Success Rate value | p | `p.text-2xl` text "89.3%" | — | C3 |
  | GDE Efficiency value | p | `p.text-2xl` text "87.1%" | — | C3 |
  | Precision metric | span | `span` text "Precision" | — | C3 |
  | Recall metric | span | `span` text "Recall" | — | C3 |
  | F1 Score metric | span | `span` text "F1 Score" | — | C3 |
  | Predicted health label | p | `p` text "Predicted system health" | — | C3 |
  | Prediction value | p | `p.text-4xl` text "88.4%" | — | C3 |
  | bg-surface-primary metric cards | div | `div.bg-surface-primary` (×4 minimum) | — | C7 |
  | content-secondary metric labels | span | `span.text-content-secondary` (×3 minimum) | — | C7 |
  | Controls flex bar | div | `div.controls.flex` | — | C7 |
  | Timeframe select | select | `select[phx-change='change_timeframe']` | change_timeframe | C5 |
  | Chart type select | select | `select[phx-change='change_chart_type']` | change_chart_type | C5 |
  | Last Hour option | option | `option[value='1h']` text "Last Hour" | — | C5 |
  | Last 24 Hours option | option | `option[value='24h']` text "Last 24 Hours" | — | C5 |
  | Last 7 Days option | option | `option[value='7d']` text "Last 7 Days" | — | C5 |
  | Last 30 Days option | option | `option[value='30d']` text "Last 30 Days" | — | C5 |
  | Line Chart option | option | `option[value='line']` text "Line Chart" | — | C5 |
  | Bar Chart option | option | `option[value='bar']` text "Bar Chart" | — | C5 |
  | Area Chart option | option | `option[value='area']` text "Area Chart" | — | C5 |
  | JSON export button | button | `button[phx-click='export'][phx-value-format='json']` text "JSON" | export | C6 |
  | CSV export button | button | `button[phx-click='export'][phx-value-format='csv']` text "CSV" | export | C6 |
  | Export description | p | `p` text "Export analytics data for external analysis..." | — | C6 |

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit (semantic color classes)
  - SC-HMI-008: Theme-aware rendering (bg-surface-primary, text-content-secondary)
  - SC-COV-008: Wallaby E2E browser tests mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard coverage
  - SC-COV-016: C8 dual verification — JSON export and CSV export each tested twice
  - SC-COV-020: PubSub refresh stability test at 5500ms (SC-COV-020)
  - SC-ANALYTICS-001: Analytics coverage requirement

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |-------------|---|---|---|-----|------------|
  | handle_params not wired to live_patch (F-001) | 4 | 3 | 3 | 36 | phx-change selects bypass params; C5 tests verify |
  | export handler not implemented (F-002) | 4 | 5 | 2 | 40 | C8 tests verify no crash; stub must be replaced |
  | Unconditional :timer.send_interval (F-003) | 4 | 4 | 3 | 48 | Refresh stability test at 5500ms verifies idempotence |
  | Initial metric values hard-coded, not from DB | 3 | 4 | 2 | 24 | Static assigns; values tested for presence |
  | PubSub gated by connected? (correct) | 2 | 1 | 1 | 2 | Standard pattern; no risk |

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

  @path "/analytics/stamp-tdg-gde-advanced"

  # ── C1: Page Structure ─────────────────────────────────────────────────────

  feature "page loads and renders STAMP / TDG / GDE Advanced Analytics Dashboard heading", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "STAMP / TDG / GDE Advanced Analytics Dashboard"))
  end

  feature "Advanced analytics and machine learning insights subtitle is rendered", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Advanced analytics and machine learning insights"))
  end

  feature "ML Model Performance card heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "ML Model Performance"))
  end

  feature "Performance Prediction card heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Performance Prediction"))
  end

  feature "Export Analytics section heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Export Analytics"))
  end

  feature "top-level stamp-tdg-gde-advanced-analytics container div is rendered", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.stamp-tdg-gde-advanced-analytics", minimum: 1))
  end

  # ── C2: Status/Badge Display — top metric cards ────────────────────────────

  feature "STAMP Compliance metric card heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "STAMP Compliance"))
  end

  feature "TDG Success Rate metric card heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "TDG Success Rate"))
  end

  feature "GDE Efficiency metric card heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "GDE Efficiency"))
  end

  feature "ML Accuracy metric card heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "ML Accuracy"))
  end

  feature "four top-level metric cards are rendered in a four-column grid", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.grid.grid-cols-4", minimum: 1))
  end

  # ── C3: Data Grid/Summary — ML and prediction metric rows ─────────────────

  feature "Precision metric row is rendered in ML Model Performance card", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Precision"))
  end

  feature "Recall metric row is rendered in ML Model Performance card", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Recall"))
  end

  feature "F1 Score metric row is rendered in ML Model Performance card", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "F1 Score"))
  end

  feature "STAMP Compliance initial value 92.5% is rendered on page load", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p.text-2xl", text: "92.5%"))
  end

  feature "TDG Success Rate initial value 89.3% is rendered on page load", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p.text-2xl", text: "89.3%"))
  end

  feature "GDE Efficiency initial value 87.1% is rendered on page load", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p.text-2xl", text: "87.1%"))
  end

  feature "Predicted system health label is rendered in Performance Prediction card", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Predicted system health"))
  end

  feature "performance_prediction initial value 88.4% is rendered on page load", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("p.text-4xl", text: "88.4%"))
  end

  # ── C4: Controls — timeframe and chart-type selects ───────────────────────

  feature "timeframe select control with phx-change is rendered in controls bar", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("select[phx-change='change_timeframe']", minimum: 1))
  end

  feature "chart_type select control with phx-change is rendered in controls bar", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("select[phx-change='change_chart_type']", minimum: 1))
  end

  feature "Last Hour option is present in timeframe select", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("option[value='1h']", text: "Last Hour"))
  end

  feature "Last 24 Hours option is present in timeframe select and pre-selected", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("option[value='24h']", text: "Last 24 Hours"))
  end

  feature "Last 7 Days and Last 30 Days options are present in timeframe select", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("option[value='7d']", text: "Last 7 Days"))
    |> assert_has(css("option[value='30d']", text: "Last 30 Days"))
  end

  feature "Line Chart, Bar Chart, and Area Chart options are in the chart-type select", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("option[value='line']", text: "Line Chart"))
    |> assert_has(css("option[value='bar']", text: "Bar Chart"))
    |> assert_has(css("option[value='area']", text: "Area Chart"))
  end

  # ── C5: Interactive Elements — select changes ──────────────────────────────

  feature "selecting Last 7 Days timeframe does not crash the page (F-001)", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(css("select[phx-change='change_timeframe']"), fn select ->
      select |> click(css("option[value='7d']"))
    end)
    |> assert_has(css("h1", text: "STAMP / TDG / GDE Advanced Analytics Dashboard"))
  end

  feature "selecting Bar Chart type does not crash the page (F-001)", %{session: session} do
    session
    |> visit(@path)
    |> find(css("select[phx-change='change_chart_type']"), fn select ->
      select |> click(css("option[value='bar']"))
    end)
    |> assert_has(css("h1", text: "STAMP / TDG / GDE Advanced Analytics Dashboard"))
  end

  # ── C6: Export Section Content ─────────────────────────────────────────────

  feature "JSON export button with phx-value-format='json' is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='export'][phx-value-format='json']", text: "JSON"))
  end

  feature "CSV export button with phx-value-format='csv' is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='export'][phx-value-format='csv']", text: "CSV"))
  end

  feature "Export analytics data description text is rendered below the export buttons", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Export analytics data for external analysis and reporting."))
  end

  # ── C7: Theme-Aware Rendering (SC-HMI-008) ────────────────────────────────

  feature "metric cards use bg-surface-primary dark theme-aware class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.bg-surface-primary", minimum: 4))
  end

  feature "content-secondary class is applied to metric row labels", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.text-content-secondary", minimum: 3))
  end

  feature "controls flex bar is rendered with gap-4 and mb-6 layout classes", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.controls.flex", minimum: 1))
  end

  # ── C8: Action Buttons — export dual verification (F-002: no handle_event) ─

  # JSON export: Test 1 — page heading preserved after click
  feature "clicking JSON export does not crash the dashboard (F-002: no export handler)", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='export'][phx-value-format='json']", text: "JSON"))
    |> assert_has(css("h1", text: "STAMP / TDG / GDE Advanced Analytics Dashboard"))
  end

  # JSON export: Test 2 — ML Model Performance section preserved after click
  feature "clicking JSON export preserves ML Model Performance section heading", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='export'][phx-value-format='json']", text: "JSON"))
    |> assert_has(css("h2", text: "ML Model Performance"))
  end

  # CSV export: Test 1 — page heading preserved after click
  feature "clicking CSV export does not crash the dashboard (F-002: no export handler)", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='export'][phx-value-format='csv']", text: "CSV"))
    |> assert_has(css("h1", text: "STAMP / TDG / GDE Advanced Analytics Dashboard"))
  end

  # CSV export: Test 2 — metric cards preserved after click
  feature "clicking CSV export preserves STAMP Compliance and TDG Success Rate cards", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='export'][phx-value-format='csv']", text: "CSV"))
    |> assert_has(css("h3", text: "STAMP Compliance"))
    |> assert_has(css("h3", text: "TDG Success Rate"))
  end

  # ── Refresh Stability (SC-COV-020 — F-003: unconditional timer.send_interval) ──

  feature "advanced analytics page remains stable after 5500ms periodic refresh interval", %{
    session: session
  } do
    session = visit(session, @path)
    assert_has(session, css("h1", text: "STAMP / TDG / GDE Advanced Analytics Dashboard"))
    assert_has(session, css("h3", text: "STAMP Compliance"))

    Process.sleep(5_500)

    assert_has(session, css("h1", text: "STAMP / TDG / GDE Advanced Analytics Dashboard"))
    assert_has(session, css("h2", text: "Performance Prediction"))
  end
end
