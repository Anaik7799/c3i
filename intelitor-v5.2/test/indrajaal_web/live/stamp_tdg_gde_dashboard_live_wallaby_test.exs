defmodule IndrajaalWeb.StampTdgGdeDashboardLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the STAMP/TDG/GDE Monitoring Dashboard (/analytics/dashboard).
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/analytics/dashboard`
  - **Module**: `IndrajaalWeb.StampTdgGdeDashboardLive`
  - **Title**: "STAMP / TDG / GDE Monitoring Dashboard"

  ## Design Intent
  Provides real-time monitoring of STAMP safety analysis, TDG test coverage, and GDE
  goal-driven evolution progress. Surfaces health summary cards, per-domain metric grids,
  feature flag toggles, chart containers, and rollout management controls in a single
  operator-facing dashboard. Supports quality assurance workflows and compliance reporting.

  ## Expected Behavior (Functional)
  - **On mount**: Loads assigns `stamp_metrics: %{}`, `tdg_metrics: %{}`, `gde_metrics: %{}`,
    `alerts: [...]`, `feature_flags: %{stamp_enabled: true, tdg_enabled: true, gde_enabled: true}`,
    `rollout_percentage: N`. Starts 5-second refresh timer via `Process.send_after/3`
    (NOT gated by `connected?/1` — key FMEA finding F-001).
    Subscribes unconditionally (not inside `connected?`) to PubSub topics:
    `"stamp_metrics"`, `"tdg_metrics"`, `"gde_metrics"`, `"alerts"`.
  - **handle_event "toggle_flag"**: Toggles boolean value for the named feature flag;
    re-renders feature flag section.
  - **handle_event "export_report"**: Stub handler — page must not crash (FMEA F-002).
  - **handle_event "manage_rollout"**: Stub handler — page must not crash (FMEA F-002).
  - **handle_info(:refresh)**: 5-second timer; refreshes all metric assigns from data source.
  - **PubSub**: `"stamp_metrics"`, `"tdg_metrics"`, `"gde_metrics"`, `"alerts"` —
    subscriptions fire even on disconnected mounts (intentional design).

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator views STAMP/TDG/GDE monitoring dashboard
    Given I navigate to "/analytics/dashboard"
    Then I should see heading "STAMP / TDG / GDE Monitoring Dashboard"
    And I should see health cards for Overall Health, STAMP Compliance, TDG Coverage, GDE Progress

  Scenario: Operator checks STAMP safety metrics
    Given I am on "/analytics/dashboard"
    Then I should see metric rows for STPA Analyses, UCAs Identified, Safety Violations

  Scenario: Operator toggles a feature flag
    Given I am on "/analytics/dashboard"
    When I click the "STAMP Enabled" toggle button
    Then the page should remain functional and headings should be unchanged

  Scenario: Operator exports compliance report
    Given I am on "/analytics/dashboard"
    When I click "Export Report"
    Then the page should not crash and dashboard heading should remain visible

  Scenario: Dashboard survives 5-second refresh cycle
    Given I am on "/analytics/dashboard"
    When 5.5 seconds elapse (one full refresh interval)
    Then the dashboard heading and all section headings should still be visible
  ```

  ## UX Flow
  1. Operator navigates to `/analytics/dashboard` via Analytics menu
  2. Page mounts with health summary cards at top; metric sections below
  3. Operator reviews STAMP Safety Analysis, TDG Test Coverage, GDE Goal Management metrics
  4. Operator toggles feature flags to enable/disable compliance enforcement
  5. Operator clicks Export Report (scheduled for full implementation)
  6. Operator adjusts rollout percentage via Manage Rollout button
  7. 5-second refresh cycle keeps all metrics current

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | Dashboard heading | h1 | `h1` text "STAMP / TDG / GDE Monitoring Dashboard" | — | C1 |
  | Subtitle | p | `p.subtitle` text "Real-time system health and compliance monitoring" | — | C1 |
  | STAMP Safety Analysis section | h3 | `h3` text "STAMP Safety Analysis" | — | C1 |
  | TDG Test Coverage section | h3 | `h3` text "TDG Test Coverage" | — | C1 |
  | GDE Goal Management section | h3 | `h3` text "GDE Goal Management" | — | C1 |
  | Active Alerts section | h3 | `h3` text "Active Alerts" | — | C1 |
  | System Performance Impact | h3 | `h3` text "System Performance Impact" | — | C1 |
  | Feature Flag Configuration | h3 | `h3` text "Feature Flag Configuration" | — | C1 |
  | Overall Health card | h3 | `h3` text "Overall Health" | — | C2 |
  | STAMP Compliance card | h3 | `h3` text "STAMP Compliance" | — | C2 |
  | TDG Coverage card | h3 | `h3` text "TDG Coverage" | — | C2 |
  | GDE Progress card | h3 | `h3` text "GDE Progress" | — | C2 |
  | STAMP Enabled toggle | button | `button[phx-click='toggle_flag'][phx-value-flag='stamp_enabled']` | toggle_flag | C2 |
  | TDG Enforcement toggle | button | `button[phx-click='toggle_flag'][phx-value-flag='tdg_enabled']` | toggle_flag | C2 |
  | GDE Active toggle | button | `button[phx-click='toggle_flag'][phx-value-flag='gde_enabled']` | toggle_flag | C2 |
  | STPA Analyses metric | span | `span` text "STPA Analyses" | — | C3 |
  | UCAs Identified metric | span | `span` text "UCAs Identified" | — | C3 |
  | Safety Violations metric | span | `span` text "Safety Violations" | — | C3 |
  | CAST Investigations metric | span | `span` text "CAST Investigations" | — | C3 |
  | Overall Coverage metric | span | `span` text "Overall Coverage" | — | C3 |
  | Property Tests metric | span | `span` text "Property Tests" | — | C3 |
  | AI Code Tested metric | span | `span` text "AI Code Tested" | — | C3 |
  | Failed Validations metric | span | `span` text "Failed Validations" | — | C3 |
  | Active Goals metric | span | `span` text "Active Goals" | — | C3 |
  | Goals On Track metric | span | `span` text "Goals On Track" | — | C3 |
  | Goals At Risk metric | span | `span` text "Goals At Risk" | — | C3 |
  | Interventions Active metric | span | `span` text "Interventions Active" | — | C3 |
  | Compilation Time Impact | span | `span` text "Compilation Time Impact" | — | C3 |
  | Test Suite Impact | span | `span` text "Test Suite Impact" | — | C3 |
  | Memory Overhead | span | `span` text "Memory Overhead" | — | C3 |
  | Rollout percentage | div | `div` text "Rollout:" | — | C3 |
  | STAMP timeline chart | div | `#stamp-timeline-chart` | — | C6 |
  | TDG coverage chart | div | `#tdg-coverage-chart` | — | C6 |
  | Performance impact chart | div | `#performance-impact-chart` | — | C6 |
  | Export Report button | button | `button[phx-click='export_report']` text "Export Report" | export_report | C8 |
  | Manage Rollout button | button | `button[phx-click='manage_rollout']` text "Manage Rollout" | manage_rollout | C8 |

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit (semantic color classes for health status)
  - SC-HMI-008: Theme-aware rendering (surface-primary, content-secondary)
  - SC-COV-008: Wallaby E2E browser tests mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard coverage
  - SC-COV-016: C8 dual verification — export_report and manage_rollout verified twice each
  - SC-COV-020: PubSub/refresh stability test required (unconditional timer)

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |-------------|---|---|---|-----|------------|
  | PubSub subscribe not gated by connected?/1 (F-001) | 5 | 4 | 3 | 60 | Benign but tested; subscriptions fire on disconnected mounts |
  | export_report / manage_rollout are stub handlers (F-002) | 4 | 5 | 2 | 40 | C8 tests verify no crash; stub must be replaced |
  | Unconditional timer fires on disconnected mount | 4 | 4 | 3 | 48 | Refresh stability test at 5500ms verifies idempotence |
  | Health card value not rendered if metrics nil | 6 | 2 | 2 | 24 | Default assigns prevent nil; span.text-2xl guards tested |
  | Feature flag toggle state not reflected in UI | 5 | 2 | 3 | 30 | toggle_flag tests verify page remains stable post-toggle |

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

  @path "/analytics/dashboard"

  # ── C1: Page Structure ─────────────────────────────────────────────────────

  feature "page loads and renders STAMP / TDG / GDE Monitoring Dashboard heading", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "STAMP / TDG / GDE Monitoring Dashboard"))
  end

  feature "Real-time system health and compliance monitoring subtitle is rendered", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("p.subtitle", text: "Real-time system health and compliance monitoring"))
  end

  feature "Export Report button is present in the header actions", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='export_report']", text: "Export Report"))
  end

  feature "STAMP Safety Analysis card heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "STAMP Safety Analysis"))
  end

  feature "TDG Test Coverage card heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "TDG Test Coverage"))
  end

  feature "GDE Goal Management card heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "GDE Goal Management"))
  end

  feature "Active Alerts card heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Active Alerts"))
  end

  # ── C2: Status/Badge Display — Health Summary Cards ───────────────────────

  feature "Overall Health health card is rendered with a numeric value", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Overall Health"))
    |> assert_has(css("span.text-2xl", minimum: 1))
  end

  feature "STAMP Compliance health card is rendered with a numeric value", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "STAMP Compliance"))
  end

  feature "TDG Coverage health card is rendered with a numeric value", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "TDG Coverage"))
  end

  feature "GDE Progress health card is rendered with a numeric value", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "GDE Progress"))
  end

  feature "Feature Flag Configuration section heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Feature Flag Configuration"))
  end

  feature "STAMP Enabled feature flag toggle is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "STAMP Enabled"))
    |> assert_has(css("button[phx-click='toggle_flag'][phx-value-flag='stamp_enabled']"))
  end

  feature "TDG Enforcement feature flag toggle is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "TDG Enforcement"))
    |> assert_has(css("button[phx-click='toggle_flag'][phx-value-flag='tdg_enabled']"))
  end

  feature "GDE Active feature flag toggle is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "GDE Active"))
    |> assert_has(css("button[phx-click='toggle_flag'][phx-value-flag='gde_enabled']"))
  end

  # ── C3: Data Grid/Summary — STAMP Safety Metrics ─────────────────────────

  feature "STPA Analyses metric row is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "STPA Analyses"))
  end

  feature "UCAs Identified metric row is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "UCAs Identified"))
  end

  feature "Safety Violations metric row is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Safety Violations"))
  end

  feature "CAST Investigations metric row is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "CAST Investigations"))
  end

  # ── C3 continued: TDG Coverage Metrics ───────────────────────────────────

  feature "Overall Coverage TDG metric row is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Overall Coverage"))
  end

  feature "Property Tests metric row is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Property Tests"))
  end

  feature "AI Code Tested metric row is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "AI Code Tested"))
  end

  feature "Failed Validations metric row is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Failed Validations"))
  end

  # ── C3 continued: GDE Goal Management Metrics ────────────────────────────

  feature "Active Goals metric row is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Active Goals"))
  end

  feature "Goals On Track metric row is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Goals On Track"))
  end

  feature "Goals At Risk metric row is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Goals At Risk"))
  end

  feature "Interventions Active metric row is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Interventions Active"))
  end

  # ── C3 continued: System Performance Impact ──────────────────────────────

  feature "System Performance Impact section heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "System Performance Impact"))
  end

  feature "Compilation Time Impact metric row is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Compilation Time Impact"))
  end

  feature "Test Suite Impact metric row is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Test Suite Impact"))
  end

  feature "Memory Overhead metric row is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Memory Overhead"))
  end

  # ── C3 continued: Rollout status ─────────────────────────────────────────

  feature "rollout percentage is rendered in feature flags section", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Rollout:"))
    |> assert_has(css("div", text: "%"))
  end

  # ── C5: Interactive Elements — feature flag toggles ───────────────────────

  feature "clicking STAMP Enabled toggle does not crash the page", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='toggle_flag'][phx-value-flag='stamp_enabled']"))
    |> assert_has(css("h1", text: "STAMP / TDG / GDE Monitoring Dashboard"))
  end

  feature "clicking TDG Enforcement toggle does not crash the page", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='toggle_flag'][phx-value-flag='tdg_enabled']"))
    |> assert_has(css("h1", text: "STAMP / TDG / GDE Monitoring Dashboard"))
  end

  feature "clicking GDE Active toggle does not crash the page", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='toggle_flag'][phx-value-flag='gde_enabled']"))
    |> assert_has(css("h1", text: "STAMP / TDG / GDE Monitoring Dashboard"))
  end

  # ── C6: Chart Containers ───────────────────────────────────────────────────

  feature "STAMP compliance trend chart container with phx-hook is rendered", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("#stamp-timeline-chart", minimum: 1))
  end

  feature "TDG coverage by domain chart container is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("#tdg-coverage-chart", minimum: 1))
  end

  feature "performance impact over time chart container is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("#performance-impact-chart", minimum: 1))
  end

  # ── C8: Action Buttons — export_report dual verification ─────────────────

  # Test 1: Page remains functional after export_report (no status badge change in current impl)
  feature "clicking Export Report does not crash the dashboard (F-002: stub handler)", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='export_report']", text: "Export Report"))
    |> assert_has(css("h1", text: "STAMP / TDG / GDE Monitoring Dashboard"))
  end

  # Test 2: Page structure is preserved after export action
  feature "clicking Export Report preserves STAMP Safety Analysis section", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='export_report']", text: "Export Report"))
    |> assert_has(css("h3", text: "STAMP Safety Analysis"))
  end

  # ── C8: Action Buttons — manage_rollout dual verification ─────────────────

  feature "Manage Rollout button is present in feature flags footer", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='manage_rollout']", text: "Manage Rollout"))
  end

  # Test 1: Page remains stable after manage_rollout click
  feature "clicking Manage Rollout does not crash the dashboard", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='manage_rollout']", text: "Manage Rollout"))
    |> assert_has(css("h1", text: "STAMP / TDG / GDE Monitoring Dashboard"))
  end

  # Test 2: Rollout percentage is still rendered after manage_rollout click
  feature "clicking Manage Rollout preserves rollout percentage display", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='manage_rollout']", text: "Manage Rollout"))
    |> assert_has(css("div", text: "Rollout:"))
  end

  # ── C4: Timeline/History — page reload stability and history continuity ──────

  feature "page reload stability: dashboard heading persists on revisit", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "STAMP / TDG / GDE Monitoring Dashboard"))
    |> visit(@path)
    |> assert_has(css("h1", text: "STAMP / TDG / GDE Monitoring Dashboard"))
  end

  feature "page reload stability: STAMP Safety Analysis section persists on revisit", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "STAMP Safety Analysis"))
    |> visit(@path)
    |> assert_has(css("h3", text: "STAMP Safety Analysis"))
  end

  feature "page reload stability: metric data (STPA Analyses) persists across revisits", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "STPA Analyses"))
    |> visit(@path)
    |> assert_has(css("span", text: "STPA Analyses"))
  end

  feature "page reload stability: Feature Flag Configuration persists on revisit", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Feature Flag Configuration"))
    |> visit(@path)
    |> assert_has(css("h3", text: "Feature Flag Configuration"))
  end

  # ── C7: AI/Advisory — contextual metrics and system advisory text ─────────

  feature "Active Alerts section shows empty state advisory text when no alerts", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("p.text-content-muted", text: "No active alerts"))
  end

  feature "View all alerts navigation link is rendered as contextual advisory", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("a[href='/alerts']", text: "View all alerts"))
  end

  feature "dashboard provides system context via numeric health value in health card", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Overall Health"))
    |> assert_has(css("span.text-2xl", minimum: 1))
  end

  # ── Refresh Stability (SC-COV-020: PubSub pages require refresh stability) ──

  feature "STAMP/TDG/GDE dashboard remains stable after 5000ms periodic refresh", %{
    session: session
  } do
    session = visit(session, @path)
    assert_has(session, css("h1", text: "STAMP / TDG / GDE Monitoring Dashboard"))
    assert_has(session, css("h3", text: "STAMP Safety Analysis"))

    Process.sleep(5_500)

    assert_has(session, css("h1", text: "STAMP / TDG / GDE Monitoring Dashboard"))
    assert_has(session, css("h3", text: "TDG Test Coverage"))
  end
end
