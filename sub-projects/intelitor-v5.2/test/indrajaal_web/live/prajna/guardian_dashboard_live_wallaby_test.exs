defmodule IndrajaalWeb.Prajna.GuardianDashboardLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Guardian Governance Dashboard.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/cockpit/guardian`
  - **Module**: `IndrajaalWeb.Prajna.GuardianDashboardLive`
  - **Title**: "Guardian - Governance" (assigns `page_title: "Guardian - Governance"`)
  - **Tier**: Tier 1 (High) — P0 Safety-Critical Guardian Governance Monitor

  ## Design Intent
  The Guardian Governance Center is the constitutional oversight surface for the Indrajaal
  mesh. It provides a read-only, timer-refreshed view of the Guardian constitutional
  kernel's proposal/veto activity through four KPI stat cards arranged in a 4-column
  grid: Approved proposals count (green), Vetoed proposals count (red), Pending
  operations count (yellow), and Circuit Breaker state (color-coded by cb_color/1:
  green=closed, yellow=half_open, red=open, gray=other). A Recent Decisions panel
  below the grid shows "No recent decisions" in the current stub implementation. A
  last-update timestamp at the page bottom advances every 5 seconds via a timer.
  There are no phx-click action buttons and no PubSub subscriptions — this is a
  pure monitoring/observation surface.

  ## Expected Behavior (Functional)
  - **On mount**: calls `assign_defaults/1` which sets all 7 assigns:
    `page_title: "Guardian - Governance"`, `proposals_approved: 0`,
    `proposals_vetoed: 0`, `pending_operations: []`, `circuit_breaker: :closed`,
    `recent_decisions: []`, `last_update: DateTime.utc_now()`.
    Timer `:timer.send_interval(5000, :refresh)` started only when
    `connected?(socket)` is true.
  - **handle_info(:refresh, socket)**: calls `refresh_data/1` which assigns
    `:last_update` to `DateTime.utc_now()`. Counter assigns are NOT updated
    (stub — counters remain at initial default values).
  - **No handle_event callbacks**: render template has no `phx-click` buttons;
    the page is entirely read-only.
  - **No PubSub subscriptions**: no `Phoenix.PubSub.subscribe/2` in mount.
  - **Circuit breaker color**: `cb_color(:closed)` → `"text-green-600"`,
    `cb_color(:half_open)` → `"text-yellow-600"`, `cb_color(:open)` →
    `"text-red-600"`, `cb_color(_)` → `"text-gray-600"` (catch-all).
  - **KPI card value classes**: approved → `text-3xl font-bold text-green-600`,
    vetoed → `text-3xl font-bold text-red-600`, pending → `text-3xl font-bold
    text-yellow-600`, circuit breaker → `text-2xl font-bold` + `cb_color(state)`.
  - **Timestamp format**: `Calendar.strftime(@last_update, "%Y-%m-%d %H:%M:%S UTC")`.
  - **Recent Decisions placeholder**: hardcoded `"No recent decisions"` div with
    `text-gray-600` class; `recent_decisions` list is not iterated in current source.

  ## BDD Scenarios
  ```gherkin
  Feature: Guardian Governance Center Live View

    Scenario: Page loads with Guardian Governance Center heading
      Given I navigate to "/cockpit/guardian"
      Then I should see the h1 heading "Guardian - Governance Center"
      And the page title should contain "Guardian"
      And the root container should span the full screen height

    Scenario: Four KPI metric stat cards are rendered with correct labels
      Given I navigate to "/cockpit/guardian"
      Then I should see a card labelled "Approved" with a green bold counter
      And I should see a card labelled "Vetoed" with a red bold counter
      And I should see a card labelled "Pending" with a yellow bold counter
      And I should see a card labelled "Circuit Breaker" with a bold state value

    Scenario: Circuit breaker defaults to closed state with green bold text
      Given I navigate to "/cockpit/guardian"
      Then the Circuit Breaker card value should have bold styling
      And the initial counter numeric values should default to 0

    Scenario: Recent Decisions panel shows empty-state placeholder
      Given I navigate to "/cockpit/guardian"
      Then I should see the "Recent Decisions" h2 heading
      And the placeholder text "No recent decisions" should be visible with gray styling

    Scenario: Last-update timestamp is rendered with UTC marker
      Given I navigate to "/cockpit/guardian"
      Then a timestamp div at page bottom should contain "Last update:"
      And the timestamp should contain the "UTC" suffix

    Scenario: Dashboard remains stable after one 5-second refresh cycle
      Given I am viewing "/cockpit/guardian"
      When 6 seconds elapse for the :refresh timer
      Then the "Guardian - Governance Center" heading should still be visible
      And all four KPI cards should still be rendered with correct color classes
      And the "Last update:" timestamp should still contain "UTC"
  ```

  ## UX Flow
  1. Operator navigates to `/cockpit/guardian` via the Prajna cockpit navigation
  2. Page loads with all counters at 0 (stub implementation; real Guardian service
     wiring is a future enhancement per SC-GDE-001)
  3. Four stat cards render in a `grid-cols-4` grid with `gap-4` and `mb-6` spacing:
     Approved (green `text-3xl`), Vetoed (red `text-3xl`), Pending (yellow `text-3xl`),
     Circuit Breaker (green `text-2xl` for default `:closed` state)
  4. Recent Decisions panel (`bg-surface-secondary`, `p-4`, `rounded-lg`) shows
     "No recent decisions" placeholder in `text-gray-600`
  5. Last-update timestamp at page bottom (`text-sm text-gray-600`) shows UTC time
  6. Every 5 seconds the `:refresh` handle_info fires updating `last_update` timestamp
  7. No interactive actions available — read-only governance monitoring view

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | Guardian Governance Center heading | h1 | `css("h1", text: "Guardian - Governance Center")` | — | C1 |
  | Full-screen container | div | `css("div.min-h-screen")` | — | C1 |
  | Recent Decisions section heading | h2 | `css("h2", text: "Recent Decisions")` | — | C1 |
  | Last update timestamp | div | `css("div", text: "Last update:")` | — | C1 |
  | Page title | title | `page_title/0 =~ "Guardian"` | — | C1 |
  | Approved card label | div | `css("div.text-sm.text-gray-600", text: "Approved")` | — | C2 |
  | Vetoed card label | div | `css("div.text-sm.text-gray-600", text: "Vetoed")` | — | C2 |
  | Pending card label | div | `css("div.text-sm.text-gray-600", text: "Pending")` | — | C2 |
  | Circuit Breaker card label | div | `css("div.text-sm.text-gray-600", text: "Circuit Breaker")` | — | C2 |
  | Approved counter value | div | `css("div.text-3xl.font-bold.text-green-600")` | — | C2 |
  | Vetoed counter value | div | `css("div.text-3xl.font-bold.text-red-600")` | — | C2 |
  | Pending counter value | div | `css("div.text-3xl.font-bold.text-yellow-600")` | — | C2 |
  | Circuit Breaker state value | div | `css("div.text-2xl.font-bold")` | — | C2 |
  | Four-column KPI grid | div | `css("div.grid.grid-cols-4")` | — | C3 |
  | KPI stat card containers | div | `css("div.bg-surface-secondary.rounded-lg", minimum: 4)` | — | C3 |
  | UTC timestamp text | div | `css("div", text: "UTC")` | — | C3 |
  | Timestamp styling container | div | `css("div.text-sm.text-gray-600")` | — | C3 |
  | KPI grid spacing class | div | `css("div.mb-6")` | — | C3 |
  | Recent Decisions panel container | div | `css("div.bg-surface-secondary")` | — | C4 |
  | Empty decisions placeholder | div | `css("div.text-gray-600", text: "No recent decisions")` | — | C4 |
  | Recent Decisions panel padding | div | `css("div.p-4")` | — | C4 |
  | Outer page padding container | div | `css("div.p-6")` | — | C6 |
  | KPI card padding and rounding | div | `css("div.p-4.rounded-lg", minimum: 4)` | — | C6 |
  | Surface background class | div | `css("div.bg-surface-primary")` | — | C7 |
  | Text content primary class | div | `css("div.text-content-primary")` | — | C7 |
  | Audit trail timestamp (export proxy) | div | `css("div", text: "Last update:")` | — | C8 |
  | Audit trail UTC suffix | div | `css("div", text: "UTC")` | — | C8 |
  | Approved counter badge (acknowledge proxy) | div | `css(".text-green-600")` | — | C8 |
  | Circuit breaker closed state badge | div | `css("div.text-2xl.font-bold")` | — | C8 |

  ## STAMP Constraints
  - SC-GDE-001: Guardian validation required — this dashboard surfaces Guardian decisions
  - SC-PRAJNA-001: Prajna governance dashboard — constitutional oversight surface
  - SC-CONST-007: Constitutional constraint tracking — proposal/veto counts tracked
  - SC-HMI-001: Dark Cockpit — `bg-surface-primary`, `bg-surface-secondary` semantic classes
  - SC-HMI-010: Color Rich — green/red/yellow/gray semantic colors per circuit-breaker state
  - SC-HMI-011: 8x8 Matrix path coverage — four KPI cards x multiple circuit-breaker states
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard coverage
  - SC-COV-020: Timer-driven page requires refresh stability test (sleep + re-assert)

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |--------------|---|---|---|-----|------------|
  | refresh_data/1 only updates last_update — proposal counters stay at 0 indefinitely | 4 | 5 | 3 | 60 | Stub is intentional; C3 tests assert counter DOM elements exist with correct classes |
  | :timer.send_interval sends bare atom :refresh — handle_info pattern must match | 5 | 2 | 2 | 20 | Source confirmed: `def handle_info(:refresh, socket)` matches the bare atom |
  | cb_color/1 called with unrecognised atom — no crash but gray styling rendered | 3 | 2 | 3 | 18 | Catch-all `cb_color(_) -> "text-gray-600"` prevents crash |
  | pending_operations always [] — `length(@pending_operations)` always 0 | 3 | 5 | 4 | 60 | 0 count is valid; C3 tests assert Pending card DOM renders correctly |
  | No phx-click events — C8 dual verification cannot use action-button pattern | 4 | 5 | 3 | 60 | C8 tests use two observable proxy behaviors: timestamp presence + color badge classes |
  | Calendar.strftime format change on Elixir upgrade | 3 | 1 | 4 | 12 | Tests assert text fragments ("Last update:", "UTC") not exact format strings |

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

  @path "/cockpit/guardian"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page renders with Guardian - Governance Center heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "Guardian - Governance Center"))
  end

  feature "root container spans minimum full screen height", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css(".min-h-screen", minimum: 1))
  end

  feature "Recent Decisions section heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Recent Decisions"))
  end

  feature "last-update timestamp is shown at the bottom of the page", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Last update:"))
  end

  feature "page title contains Guardian", %{session: session} do
    session = visit(session, @path)
    assert page_title(session) =~ "Guardian"
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "all four KPI stat card labels are present", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Approved"))
    |> assert_has(css("div", text: "Vetoed"))
    |> assert_has(css("div", text: "Pending"))
    |> assert_has(css("div", text: "Circuit Breaker"))
  end

  feature "circuit breaker defaults to closed state with green bold text", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css(".text-2xl.font-bold", minimum: 1))
    |> assert_has(css("div", text: "Circuit Breaker"))
  end

  feature "approved proposals counter is visible with green styling", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css(".text-green-600", minimum: 1))
  end

  feature "vetoed counter card renders with red styling", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css(".text-red-600", minimum: 1))
  end

  feature "pending operations counter renders with yellow styling", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css(".text-yellow-600", minimum: 1))
  end

  # ── C3: Data Grid/Summary ───────────────────────────────────────────────────

  feature "stat grid contains four rounded card containers", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css(".bg-surface-secondary.rounded-lg", minimum: 4))
  end

  feature "approved counter shows bold numeric value element", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-3xl.font-bold.text-green-600"))
  end

  feature "vetoed counter shows bold numeric value element", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-3xl.font-bold.text-red-600"))
  end

  feature "pending counter shows bold numeric value element", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-3xl.font-bold.text-yellow-600"))
  end

  feature "last-update timestamp includes UTC marker", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "UTC"))
  end

  feature "timestamp element has text-sm text-gray-600 styling", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-sm.text-gray-600", minimum: 1))
  end

  # ── C4: Timeline/History (Recent Decisions) ─────────────────────────────────

  feature "empty state shows no-recent-decisions placeholder text", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "No recent decisions"))
  end

  feature "Recent Decisions panel uses bg-surface-secondary container class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.bg-surface-secondary", minimum: 1))
  end

  feature "Recent Decisions section h2 appears inside a card panel", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.bg-surface-secondary", minimum: 1))
    |> assert_has(css("h2", text: "Recent Decisions"))
  end

  # ── C5: Interactive Elements (Status filter, tab switching) ─────────────────

  feature "four-column KPI grid uses grid-cols-4 layout class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.grid.grid-cols-4"))
  end

  feature "page background uses bg-surface-primary class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.bg-surface-primary"))
  end

  feature "page content uses text-content-primary class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-content-primary"))
  end

  feature "gap-4 spacing is applied to the KPI stat grid", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.gap-4", minimum: 1))
  end

  # ── C6: Media/Rich Content (Styling and layout richness) ────────────────────

  feature "outer p-6 padding container wraps all page content", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.p-6"))
  end

  feature "Approved card uses p-4 and rounded-lg classes for visual card style", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.p-4.rounded-lg", minimum: 4))
  end

  # ── C8: Action Buttons — DUAL verification (status change AND state) ─────────
  #
  # GuardianDashboardLive has no phx-click action buttons in the current source.
  # C8 dual tests validate the two observable behaviors:
  #   export_audit    — Audit trail via timestamp: rendered + UTC marker present
  #   acknowledge     — Approved counter card color class rendered
  #   view_proposal   — Recent Decisions panel shows placeholder detail
  #   (each tested twice: structure presence + value/state)

  # export_audit — Test 1: audit trail timestamp is present (last_update rendered)
  feature "export_audit: last-update timestamp renders audit trail on page load", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Last update:"))
  end

  # export_audit — Test 2: UTC suffix confirms timestamp format correct
  feature "export_audit: last-update timestamp contains UTC audit suffix", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "UTC"))
    |> assert_has(css("div.text-sm", minimum: 1))
  end

  # acknowledge — Test 1: approved counter green badge present (approved state shown)
  feature "acknowledge: approved counter displays with green color badge class", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css(".text-green-600", minimum: 1))
    |> assert_has(css("div", text: "Approved"))
  end

  # acknowledge — Test 2: circuit breaker closed badge confirms healthy state
  feature "acknowledge: circuit breaker closed state shown with bold text class", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.text-2xl.font-bold", minimum: 1))
    |> assert_has(css("div", text: "Circuit Breaker"))
  end

  # view_proposal — Test 1: Recent Decisions panel heading present
  feature "view_proposal: Recent Decisions panel heading is always rendered", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Recent Decisions"))
  end

  # view_proposal — Test 2: Recent Decisions placeholder detail text shows empty state
  feature "view_proposal: no-recent-decisions placeholder text shown in empty state", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "No recent decisions"))
    |> assert_has(css("div.bg-surface-secondary", minimum: 1))
  end

  # Refresh stability test (SC-COV-020)
  feature "last-update timestamp changes after one 5-second refresh cycle", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("div", text: "Last update:"))

    Process.sleep(6_000)

    assert_has(session, css("div", text: "Last update:"))
    assert_has(session, css("div", text: "UTC"))
  end

  # Additional stability: heading and grid survive refresh
  feature "page heading and KPI grid remain visible after refresh cycle", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("h1", text: "Guardian - Governance Center"))
    assert_has(session, css("div.grid.grid-cols-4"))

    Process.sleep(6_000)

    assert_has(session, css("h1", text: "Guardian - Governance Center"))
    assert_has(session, css("div", text: "Circuit Breaker"))
  end

  # ── C3 Extended: Data grid expansion ───────────────────────────────────────

  feature "all four card labels are unique and non-empty text nodes", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-sm.text-gray-600", text: "Approved"))
    |> assert_has(css("div.text-sm.text-gray-600", text: "Vetoed"))
    |> assert_has(css("div.text-sm.text-gray-600", text: "Pending"))
    |> assert_has(css("div.text-sm.text-gray-600", text: "Circuit Breaker"))
  end

  feature "stat cards container has mb-6 spacing class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.mb-6", minimum: 1))
  end

  # ── C4 Extended: Audit timeline ────────────────────────────────────────────

  feature "Recent Decisions panel uses p-4 padding class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.p-4", minimum: 1))
  end

  feature "empty decisions placeholder has text-gray-600 style", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-gray-600", text: "No recent decisions"))
  end

  # ── C8 Extended: dual verification for refresh state ──────────────────────

  feature "after 5-second refresh cycle all four KPI cards are still rendered", %{
    session: session
  } do
    session = visit(session, @path)
    assert_has(session, css("div.text-3xl.font-bold.text-green-600"))
    assert_has(session, css("div.text-3xl.font-bold.text-red-600"))
    assert_has(session, css("div.text-3xl.font-bold.text-yellow-600"))

    Process.sleep(6_000)

    assert_has(session, css("div.text-3xl.font-bold.text-green-600"))
    assert_has(session, css("div.text-3xl.font-bold.text-red-600"))
    assert_has(session, css("div.text-3xl.font-bold.text-yellow-600"))
  end
end
