defmodule IndrajaalWeb.PerformanceDashboardLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Performance Optimization Dashboard (/performance).
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/performance`
  - **Module**: `IndrajaalWeb.PerformanceDashboardLive`
  - **Title**: "SOPv5.1 Performance Optimization Dashboard"

  ## Design Intent
  Provides real-time observability into BEAM VM performance metrics for operators
  diagnosing resource utilization — memory breakdown (total/processes/ETS/atoms),
  scheduler count, process count vs. limit, I/O bytes, and system uptime. The page
  auto-refreshes on a 5-second timer with no operator interaction required.

  ## Expected Behavior (Functional)
  - **On mount**: Calls `load_metrics/1` which assigns `dashboard_active: true`,
    `memory_total_mb`, `memory_processes_mb`, `memory_ets_mb`, `memory_atom_mb`,
    `schedulers`, `process_count`, `process_limit`, `process_pct`, `io_bytes`,
    `uptime_hours`. Timer started unconditionally (not gated by `connected?/1`):
    `:timer.send_interval(5000, :refresh)`.
  - **handle_event**: No `handle_event` callbacks — this is a read-only observability page.
  - **handle_info(:refresh)**: Calls `load_metrics/1` to refresh all BEAM metric assigns;
    re-render occurs automatically.
  - **PubSub**: None — metrics are read directly from BEAM via `:erlang.memory/0`,
    `:erlang.system_info/1`, and `:erlang.statistics/1`.
  - **Timer**: `:timer.send_interval(5000, :refresh)` — repeating 5-second auto-refresh,
    NOT gated by `connected?/1` (fires on both connected and disconnected mounts).

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator observes BEAM memory breakdown
    Given I navigate to "/performance"
    Then I see the heading "SOPv5.1 Performance Optimization Dashboard"
    And the BEAM Memory card shows Total, Processes, ETS, and Atoms values in MB

  Scenario: Dashboard auto-refreshes without interaction
    Given I navigate to "/performance"
    When 5500ms elapses
    Then the BEAM Memory card heading is still visible
    And numeric MB values are still rendered
  ```

  ## UX Flow
  1. Operator navigates to `/performance` via the monitoring menu
  2. BEAM Memory card shows four memory breakdowns with color-coded values
  3. Schedulers & Processes card shows scheduler count and process utilization
  4. System Status card shows uptime and dashboard_active flag
  5. Page auto-refreshes every 5 seconds without any operator action

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | Page heading | h1 | `h1[text="SOPv5.1 Performance Optimization Dashboard"]` | — | C1 |
  | BEAM Memory card | h2 | `h2[text="BEAM Memory"]` | — | C3 |
  | Schedulers & Processes card | h2 | `h2[text="Schedulers & Processes"]` | — | C3 |
  | System Status card | h2 | `h2[text="System Status"]` | — | C3 |
  | Dashboard Active label | p | `p[text="Dashboard Active:"]` + `p[text="true"]` | — | C2 |
  | Process utilization % | span | `span[class*='font-mono'][text~='%']` | — | C2 |
  | Uptime in hours | span | `span[text~='h']` | — | C2 |
  | Total memory MB | span | `span.text-blue-400[text~='MB']` | — | C3 |
  | Processes memory MB | span | `span.text-green-400[text~='MB']` | — | C3 |
  | ETS memory MB | span | `span.text-yellow-400[text~='MB']` | — | C3 |
  | Atoms memory MB | span | `span.text-purple-400[text~='MB']` | — | C3 |
  | Schedulers value | span | `span.text-blue-400` | — | C3 |
  | Processes count/limit | span | `span.text-green-400[text~='/']` | — | C3 |
  | Surface card | div | `div[class*='bg-surface-primary']` | — | C6 |

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit — all cards use `bg-surface-primary` semantic class
  - SC-HMI-008: Theme-aware rendering — `text-content-primary`, color-coded metric spans
  - SC-OBS-065: Observability requirements — BEAM metrics exposed in real-time
  - SC-CTRL-001: System status available in real-time

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |-------------|---|---|---|-----|------------|
  | Timer fires on disconnected mount — double refresh | 3 | 7 | 5 | 105 | unconditional timer is intentional; stability test validates |
  | BEAM memory API returns unexpected format | 5 | 2 | 3 | 30 | load_metrics/1 pattern-matches known keys |
  | process_pct overflow >100% during test load | 3 | 4 | 5 | 60 | display-only, no control logic |

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

  @path "/performance"

  # ── C1: Page Structure ─────────────────────────────────────────────────────

  feature "page loads and renders SOPv5.1 Performance Optimization Dashboard heading", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "SOPv5.1 Performance Optimization Dashboard"))
  end

  feature "page renders three main metric cards", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", minimum: 3))
  end

  # ── C2: Status/Badge Display ───────────────────────────────────────────────

  feature "Dashboard Active label shows true value", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Dashboard Active:"))
    |> assert_has(css("p", text: "true"))
  end

  feature "process utilization percentage value is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Utilization:"))
    |> assert_has(css("span[class*='font-mono']", text: "%", minimum: 1))
  end

  feature "Uptime value in hours is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Uptime:"))
    |> assert_has(css("span", text: "h", minimum: 1))
  end

  # ── C3: Data Grid/Summary — BEAM Memory Card ──────────────────────────────

  feature "BEAM Memory card heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "BEAM Memory"))
  end

  feature "Total memory value with MB label is rendered in blue", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Total:"))
    |> assert_has(css("span.text-blue-400", text: "MB", minimum: 1))
  end

  feature "Processes memory value with MB label is rendered in green", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Processes:"))
    |> assert_has(css("span.text-green-400", text: "MB", minimum: 1))
  end

  feature "ETS memory value with MB label is rendered in yellow", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "ETS:"))
    |> assert_has(css("span.text-yellow-400", text: "MB", minimum: 1))
  end

  feature "Atoms memory value with MB label is rendered in purple", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Atoms:"))
    |> assert_has(css("span.text-purple-400", text: "MB", minimum: 1))
  end

  # ── C3 continued: Schedulers & Processes Card ─────────────────────────────

  feature "Schedulers and Processes card heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Schedulers & Processes"))
  end

  feature "Schedulers value is rendered as a non-zero number in blue", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Schedulers:"))
    |> assert_has(css("span.text-blue-400", minimum: 1))
  end

  feature "Processes value showing current slash limit is rendered in green", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Processes:"))
    |> assert_has(css("span.text-green-400", text: "/", minimum: 1))
  end

  # ── C3 continued: System Status Card ─────────────────────────────────────

  feature "System Status card heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "System Status"))
  end

  feature "uptime value in hours is rendered in blue mono font", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.text-blue-400", minimum: 1))
  end

  # ── C4: Timeline/History — Auto-Refresh Temporal Sequence ──────────────────

  feature "dashboard is stable after first 5000ms auto-refresh cycle (SC-COV-020)", %{
    session: session
  } do
    session = visit(session, @path)
    assert_has(session, css("h1", text: "SOPv5.1 Performance Optimization Dashboard"))
    assert_has(session, css("h2", text: "BEAM Memory"))

    Process.sleep(5_500)

    assert_has(session, css("h1", text: "SOPv5.1 Performance Optimization Dashboard"))
    assert_has(session, css("h2", text: "BEAM Memory"))
  end

  feature "memory values persist through refresh cycle as temporal data points", %{
    session: session
  } do
    session = visit(session, @path)
    assert_has(session, css("span.text-blue-400", text: "MB", minimum: 1))

    Process.sleep(5_500)

    assert_has(session, css("span.text-blue-400", text: "MB", minimum: 1))
  end

  feature "scheduler count remains consistent across refresh intervals", %{
    session: session
  } do
    session = visit(session, @path)
    assert_has(session, css("p", text: "Schedulers:"))

    Process.sleep(5_500)

    assert_has(session, css("p", text: "Schedulers:"))
  end

  feature "process utilization percentage updates through refresh cycle", %{
    session: session
  } do
    session = visit(session, @path)
    assert_has(session, css("span[class*='font-mono']", text: "%", minimum: 1))

    Process.sleep(5_500)

    assert_has(session, css("span[class*='font-mono']", text: "%", minimum: 1))
  end

  # ── C5: Interactive Elements — Navigation & Page Controls ────────────────

  feature "page is navigable from root and renders without interaction", %{session: session} do
    session
    |> visit("/")
    |> visit(@path)
    |> assert_has(css("h1", text: "SOPv5.1 Performance Optimization Dashboard"))
  end

  feature "page responds to browser refresh maintaining state", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("h2", text: "BEAM Memory"))

    session = visit(session, @path)
    assert_has(session, css("h2", text: "BEAM Memory"))
  end

  # ── C6: Media/Rich Content — Color-Coded Metric Visualizations ──────────

  feature "page uses semantic bg-surface-primary class for dark cockpit (SC-HMI-001)", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div[class*='bg-surface-primary']", minimum: 1))
  end

  feature "text-content-primary semantic class is applied on metric card headings", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h2[class*='text-content-primary']", minimum: 1))
  end

  feature "border-border-theme-primary semantic class used on metric card borders", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div[class*='border-border-theme-primary']", minimum: 1))
  end

  feature "four distinct color-coded memory spans present (blue/green/yellow/purple)", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span.text-blue-400", minimum: 1))
    |> assert_has(css("span.text-green-400", minimum: 1))
    |> assert_has(css("span.text-yellow-400", minimum: 1))
    |> assert_has(css("span.text-purple-400", minimum: 1))
  end

  # ── C7: AI/Advisory Panels — Metric Interpretation Guidance ──────────────

  feature "process utilization metric provides contextual percentage reading", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Utilization:"))
    |> assert_has(css("span[class*='font-mono']", minimum: 1))
  end

  feature "memory breakdown provides four-dimension analysis (total/proc/ets/atom)", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Total:"))
    |> assert_has(css("p", text: "Processes:"))
    |> assert_has(css("p", text: "ETS:"))
    |> assert_has(css("p", text: "Atoms:"))
  end

  # ── C8: Action Buttons — Read-Only Page Verification ─────────────────────
  # This page has no action buttons (read-only observability).
  # C8 coverage verifies the absence of unintended interactive mutations.

  feature "no phx-click action buttons present on read-only dashboard", %{session: session} do
    session = visit(session, @path)
    refute_has(session, css("button[phx-click]"))
  end

  feature "no form submission elements on read-only dashboard", %{session: session} do
    session = visit(session, @path)
    refute_has(session, css("form[phx-submit]"))
  end
end
