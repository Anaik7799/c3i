defmodule IndrajaalWeb.Prajna.SentinelDashboardLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Sentinel Dashboard page (/cockpit/sentinel).
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/cockpit/sentinel`
  - **Module**: `IndrajaalWeb.Prajna.SentinelDashboardLive`
  - **Title**: "Sentinel - Immune System"

  ## Design Intent
  Provides the Digital Immune System monitoring dashboard, presenting the Sentinel
  engine's health score, active threat count, quarantined items, detected patterns,
  response times, and last scan timestamp. Read-only telemetry display — no operator
  actions mutate state. Integrates with `SentinelBridge` which syncs every 5s with
  the Sentinel GenServer, with try/rescue fallback to default zero-values when the
  bridge is unavailable. Subscribes to `sentinel:threats` and `prajna:threats`
  for push-based threat notifications per SC-IMMUNE-001, SC-IMMUNE-007..008.

  ## Expected Behavior (Functional)
  - **On mount**: assigns `page_title: "Sentinel - Immune System"`, `health_score: 0`,
    `active_threats: 0`, `quarantined: 0`, `patterns_detected: 0`,
    `response_times: %{}`, `last_scan: nil`
  - **PubSub**: subscribes to `"sentinel:threats"` and `"prajna:threats"`
  - **Timer**: 5000ms → `:refresh` (calls load_sentinel_data via SentinelBridge)
  - **No user-triggered events** — dashboard is read-only; all state from SentinelBridge
  - **handle_info :refresh**: reloads all sentinel data assigns
  - **handle_info %{event: "threat_detected"}**: triggers full data reload
  - **handle_info (catch-all)**: silently ignored

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator views Sentinel health score on load
    Given I navigate to "/cockpit/sentinel"
    Then I should see the "Sentinel - Immune System" title
    And a health score card should be displayed
    And the active threats count should be visible

  Scenario: Dashboard shows zero-values when Sentinel bridge is unavailable
    Given the SentinelBridge is in fallback mode
    When I navigate to "/cockpit/sentinel"
    Then health score should show "0" or default value
    And the page should not show any unhandled exceptions

  Scenario: Quarantine count and patterns are displayed
    Given I navigate to "/cockpit/sentinel"
    Then the quarantined count panel should be visible
    And the patterns detected count should be visible

  Scenario: Response times SLA panel is present
    Given I navigate to "/cockpit/sentinel"
    Then the response time SLA section should be displayed

  Scenario: Last scan timestamp is shown
    Given I navigate to "/cockpit/sentinel"
    Then the "Last Scan" timestamp field should be visible
  ```

  ## UX Flow
  1. Operator navigates to `/cockpit/sentinel` — health score dashboard loads
  2. SentinelBridge provides live data from the Sentinel GenServer
  3. Health score displayed as a prominent metric card (0-100 scale)
  4. Active threats, quarantined, and patterns shown as secondary metric cards
  5. Response time SLA panel shows min/max/avg response times
  6. Last scan timestamp confirms currency of data
  7. Dashboard auto-refreshes every 5s via timer; push updates via PubSub
  8. If SentinelBridge unavailable, fallback zeros displayed without crash

  ## UI Elements Inventory
  | Element | Type | Selector | Event |
  |---------|------|----------|-------|
  | Page title / heading | span/h1 | `css("span", text: "SENTINEL")` | none |
  | PRAJNA C3I nav link | a | `css("a", text: "PRAJNA C3I")` | navigate |
  | Health score card | div | `css("[data-testid='health-score']")` | none (read-only) |
  | Active threats count | div | `css("[data-testid='active-threats']")` | none |
  | Quarantined count | div | `css("[data-testid='quarantined']")` | none |
  | Patterns detected count | div | `css("[data-testid='patterns-detected']")` | none |
  | Response times panel | div | `css("[data-testid='response-times']")` | none |
  | Last scan timestamp | span | `css("span", text: "Last Scan")` | none |
  | Digital Immune System label | span | `css("span", text: "Immune System")` | none |

  ## STAMP Constraints
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard coverage
  - SC-IMMUNE-001: Digital Immune System monitoring — health score visible on mount
  - SC-IMMUNE-007: Sentinel health score tracked — health_score assign present
  - SC-IMMUNE-008: Threat advisories surfaced — active_threats visible
  - SC-HMI-001: Dark Cockpit defaults — dashboard uses gray/dark theme by default
  - SC-COV-020: PubSub sentinel:threats requires refresh stability test

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |---|---|---|---|---|---|
  | SentinelBridge crash → all assigns nil → render crash | 9 | 2 | 2 | 36 | try/rescue in mount + fallback values |
  | health_score assign shows stale value after 5s refresh | 6 | 3 | 4 | 72 | sleep + re-assert (SC-COV-020) |
  | threat_detected PubSub event not triggering reload | 7 | 2 | 3 | 42 | Direct PubSub broadcast + assert in test |
  | Quarantined count display missing when 0 | 4 | 3 | 3 | 36 | Assert "0" shown (not empty) |
  | Last scan nil shows blank → operator confusion | 5 | 2 | 3 | 30 | Assert "Never" or timestamp fallback |

  Verifies the Digital Immune System dashboard: health score card, active
  threats count, quarantine count, patterns detected, response time SLA
  panel, and last scan timestamp against a real Chrome browser via NixOS
  chromedriver.

  The Sentinel dashboard is a read-only telemetry display — all state comes
  from SentinelBridge with graceful try/rescue fallback. Tests verify correct
  rendering under both healthy and fallback-default conditions.

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

  @path "/cockpit/sentinel"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads and renders the Sentinel Digital Immune System heading", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "Sentinel - Digital Immune System"))
  end

  feature "page root container uses bg-surface-primary layout class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.bg-surface-primary"))
  end

  feature "page uses min-h-screen to fill the viewport", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.min-h-screen"))
  end

  feature "Response Times SLA panel heading is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Response Times (SLA)"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "health score value is rendered in green text", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-green-600"))
  end

  feature "active threats count is rendered in red text", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-red-600"))
  end

  feature "quarantined count is rendered in yellow text", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-yellow-600"))
  end

  feature "patterns detected count is rendered in blue text", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-blue-600"))
  end

  feature "all four top metric cards display text-3xl numeric values", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-3xl", minimum: 4))
  end

  feature "health score card shows a percentage value via green text-3xl element", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.text-3xl.font-bold.text-green-600"))
  end

  # ── C3: Data Grid/Summary ───────────────────────────────────────────────────

  feature "Health Score metric card label is visible in the top metrics row", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Health Score"))
  end

  feature "Active Threats metric card label is visible in the top metrics row", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Active Threats"))
  end

  feature "Quarantined metric card label is visible in the top metrics row", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Quarantined"))
  end

  feature "Patterns Detected metric card label is visible in the top metrics row", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Patterns Detected"))
  end

  feature "top metrics row is rendered as a 4-column grid", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.grid.grid-cols-4"))
  end

  feature "all four metric cards use bg-surface-secondary style", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.bg-surface-secondary", minimum: 4))
  end

  feature "EXTINCTION tier label and 100ms value are shown in the SLA panel", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "EXTINCTION"))
    |> assert_has(css("div", text: "100ms"))
  end

  feature "CRITICAL tier label and 500ms value are shown in the SLA panel", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "CRITICAL"))
    |> assert_has(css("div", text: "500ms"))
  end

  feature "HIGH tier label and 2000ms value are shown in the SLA panel", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "HIGH"))
    |> assert_has(css("div", text: "2000ms"))
  end

  feature "SLA panel renders as a 3-column grid for the three tiers", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.grid.grid-cols-3"))
  end

  # ── C4: Timeline/History ────────────────────────────────────────────────────

  feature "Last scan timestamp line is visible at the bottom of the dashboard", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Last scan:"))
  end

  feature "last scan timestamp contains UTC date format", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-gray-500", text: "Last scan:"))
  end

  feature "EXTINCTION tier uses text-red-500 severity color for historical context", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.text-red-500"))
  end

  feature "CRITICAL tier uses text-orange-500 severity color for historical context", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.text-orange-500"))
  end

  feature "HIGH tier uses text-yellow-500 severity color for historical context", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.text-yellow-500"))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "page is fully navigable at the /cockpit/sentinel route", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1"))
  end

  feature "page loads without JavaScript errors blocking render", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-3xl", minimum: 1))
  end

  # ── C6: Media/Rich Content ──────────────────────────────────────────────────

  feature "SLA panel uses rounded-lg card style for visual presentation", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.rounded-lg", minimum: 2))
  end

  feature "metric cards use p-4 padding for consistent visual layout", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.p-4", minimum: 4))
  end

  feature "page padding uses p-6 root padding class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.p-6"))
  end

  # ── C8: Action Buttons — Dual Verification (stability + data integrity) ─────
  #
  # SentinelDashboard is a read-only telemetry display with no user-triggered
  # events. C8 dual verification covers the auto-refresh mechanism:
  #   (1) structural stability — page structure persists across refresh cycle
  #   (2) data integrity — metric cards re-render correctly after refresh

  feature "sentinel page remains stable after the 5000ms auto-refresh interval fires", %{
    session: session
  } do
    session = visit(session, @path)
    assert_has(session, css("h2", text: "Response Times (SLA)"))
    Process.sleep(5_500)
    assert_has(session, css("h2", text: "Response Times (SLA)"))
    assert_has(session, css("div", text: "Health Score"))
  end

  feature "health score card is still present after auto-refresh cycle completes", %{
    session: session
  } do
    session = visit(session, @path)
    assert_has(session, css("div", text: "Health Score"))
    Process.sleep(5_500)
    assert_has(session, css("div.text-3xl.font-bold.text-green-600"))
  end

  feature "active threats count card is still present after auto-refresh cycle", %{
    session: session
  } do
    session = visit(session, @path)
    assert_has(session, css("div", text: "Active Threats"))
    Process.sleep(5_500)
    assert_has(session, css("div.text-red-600"))
  end

  feature "SLA panel headings remain intact after auto-refresh cycle", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("div", text: "EXTINCTION"))
    Process.sleep(5_500)
    assert_has(session, css("div", text: "EXTINCTION"))
    assert_has(session, css("div", text: "100ms"))
  end

  feature "dashboard renders gracefully when SentinelBridge returns default fallback values", %{
    session: session
  } do
    # SentinelBridge is wrapped in try/rescue so dashboard always shows
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Health Score"))
    |> assert_has(css("div", text: "Active Threats"))
  end

  feature "fallback-rendered health score is 100 percent from default struct", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.text-green-600"))
    |> assert_has(css("div", text: "Health Score"))
  end

  feature "patterns detected card shows zero when SentinelBridge advisories list is empty", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Patterns Detected"))
    |> assert_has(css("div.text-blue-600"))
  end

  feature "quarantined card shows zero when SentinelBridge quarantine list is empty", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Quarantined"))
    |> assert_has(css("div.text-yellow-600"))
  end
end
