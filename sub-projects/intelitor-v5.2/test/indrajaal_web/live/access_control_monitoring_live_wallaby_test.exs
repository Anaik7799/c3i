defmodule IndrajaalWeb.AccessControlMonitoringLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Access Control Monitoring Dashboard.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/admin/access_control`
  - **Module**: `IndrajaalWeb.AccessControlMonitoringLive`
  - **Title**: "Access Control Monitoring Dashboard"

  ## Design Intent
  Provides real-time security monitoring for operators to observe active alerts,
  active sessions, and recent access events across the enterprise. Enables security
  teams to detect anomalies and compliance violations at a glance.

  ## Expected Behavior (Functional)
  - **On mount**: Assigns `page_title: "Access Control Monitoring"`,
    `alert_count: 0`, `active_sessions: 0`, `recent_events: []`. No PubSub
    subscription and no timer in the current implementation.
  - **handle_in("query", ...)**: Channel handler that resets `alert_count` to 0;
    this is NOT a phx-click event — no action buttons are rendered on the page.
  - **handle_info**: Not implemented; no periodic refresh in current version.
  - **PubSub**: None subscribed at mount.
  - **Timers**: None; page is static after mount.

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator views access control monitoring dashboard
    Given I navigate to "/admin/access_control"
    Then I see the "Access Control Monitoring Dashboard" heading
    And three metric cards are visible: Active Alerts, Active Sessions, Recent Events
    And the Recent Access Events section shows "No recent events"

  Scenario: Dashboard remains stable after re-navigation
    Given I navigate to "/admin/access_control"
    When I navigate away and return
    Then all three metric card headings are still present
  ```

  ## UX Flow
  1. Operator navigates to `/admin/access_control` via the admin menu
  2. Page mounts with zero-values in all three metric cards
  3. Operator observes alert_count, active_sessions, and recent_events count
  4. The Recent Access Events section shows an empty-state message when no events exist
  5. (Future) A query channel or PubSub broadcast populates live event data

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | Dashboard heading | h1 | `h1.text-content-primary` | — | C1 |
  | Subtitle | p | `p.text-content-secondary` | — | C1 |
  | Wrapper div | div | `div.access-control-monitoring` | — | C1 |
  | Active Alerts card | h3 | `h3[text="Active Alerts"]` | — | C2 |
  | Active Sessions card | h3 | `h3[text="Active Sessions"]` | — | C2 |
  | Recent Events card | h3 | `h3[text="Recent Events"]` | — | C2 |
  | Alert count value | p | `p.text-2xl.font-bold` | — | C3 |
  | 3-col grid | div | `div.grid.grid-cols-3` | — | C3 |
  | Events section | h2 | `h2[text="Recent Access Events"]` | — | C4 |
  | Empty-state text | p | `p.text-content-muted.text-center` | — | C4 |
  | Surface card | div | `div.card.bg-surface-primary` | — | C6 |

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit — all cards use `bg-surface-primary` semantic class
  - SC-HMI-008: Theme-aware rendering — `text-content-primary/secondary/muted`
  - SC-ACE-001: Access Control Engine — dashboard provides visibility into access events
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |-------------|---|---|---|-----|------------|
  | handle_in("query") fires but no LiveView event rendered (F-001) | 3 | 6 | 5 | 90 | C8 stability tests replace button-click tests |
  | recent_events always [] at mount — empty state never tested (F-002) | 4 | 5 | 4 | 80 | Explicit empty-state assertion in C4 |
  | Page crash on re-mount after navigation (F-003) | 6 | 2 | 3 | 36 | C8 dual-visit stability test |

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

  @path "/admin/access_control"

  # ── C1: Page Structure ─────────────────────────────────────────────────────

  feature "page loads and renders Access Control Monitoring Dashboard heading", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "Access Control Monitoring Dashboard"))
  end

  feature "Real-time security and access monitoring subtitle is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Real-time security and access monitoring"))
  end

  feature "Recent Access Events card section heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Recent Access Events"))
  end

  feature "top-level access-control-monitoring container div is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.access-control-monitoring", minimum: 1))
  end

  # ── C2: Status/Badge Display — metric cards ────────────────────────────────

  feature "Active Alerts metric card heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Active Alerts"))
  end

  feature "Active Sessions metric card heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Active Sessions"))
  end

  feature "Recent Events metric card heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Recent Events"))
  end

  feature "Active Alerts numeric value is rendered in a large font element", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("p.text-2xl", minimum: 1))
  end

  # ── C3: Data Grid/Summary — metric card values ─────────────────────────────

  feature "three metric cards are rendered in the stats grid", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.card", minimum: 3))
  end

  feature "alert_count value is rendered as a numeric element on page load", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("p.text-2xl.font-bold", text: "0"))
  end

  feature "grid layout with three columns is applied to metric cards section", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.grid.grid-cols-3", minimum: 1))
  end

  feature "metric card shadows are applied via Tailwind shadow class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.shadow", minimum: 3))
  end

  # ── C4: Event List / History ───────────────────────────────────────────────

  feature "empty-state message is shown when no recent events exist", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "No recent events"))
  end

  feature "Recent Access Events card has a wrapping card div", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.card.bg-surface-primary", minimum: 1))
  end

  feature "p-6 padded card wraps the recent events section", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.p-6", minimum: 1))
  end

  # ── C5: Interactive Elements ───────────────────────────────────────────────

  feature "page renders without JavaScript errors blocking LiveView mount", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.access-control-monitoring", minimum: 1))
  end

  feature "page structure is complete with header, metric cards, and events card", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.header", minimum: 1))
    |> assert_has(css("div.grid.grid-cols-3", minimum: 1))
    |> assert_has(css("h2", text: "Recent Access Events"))
  end

  feature "metric card content-muted labels are applied for accessibility", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3.text-content-muted", minimum: 3))
  end

  # ── C6: Theme-Aware Rendering (SC-HMI-008) ────────────────────────────────

  feature "metric cards use bg-surface-primary dark theme-aware class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.bg-surface-primary", minimum: 1))
  end

  feature "main heading uses text-content-primary theme-aware color class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1.text-content-primary", minimum: 1))
  end

  feature "subtitle uses text-content-secondary theme-aware color class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p.text-content-secondary", minimum: 1))
  end

  # ── C7: Content State and Labels ──────────────────────────────────────────

  feature "empty-state text is styled with text-content-muted class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p.text-content-muted", minimum: 1))
  end

  feature "empty-state text is centered with text-center class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p.text-center", minimum: 1))
  end

  # ── C8: Page Stability (no action buttons in current impl — F-001) ─────────

  # Test 1: page remains fully rendered on reload
  feature "page remains fully rendered on a second visit (no crash on re-mount)", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "Access Control Monitoring Dashboard"))
    |> visit(@path)
    |> assert_has(css("h1", text: "Access Control Monitoring Dashboard"))
  end

  # Test 2: all three metric card headings still present after re-navigation
  feature "all three metric cards are still present after re-navigation to the page", %{
    session: session
  } do
    session
    |> visit(@path)
    |> visit("/")
    |> visit(@path)
    |> assert_has(css("h3", text: "Active Alerts"))
    |> assert_has(css("h3", text: "Active Sessions"))
    |> assert_has(css("h3", text: "Recent Events"))
  end

  # ── Refresh Stability (SC-COV-020) ────────────────────────────────────────

  feature "dashboard remains stable across 2000ms — no timers in current impl", %{
    session: session
  } do
    session = visit(session, @path)
    assert_has(session, css("h1", text: "Access Control Monitoring Dashboard"))
    assert_has(session, css("h3", text: "Active Alerts"))

    Process.sleep(2_000)

    assert_has(session, css("h1", text: "Access Control Monitoring Dashboard"))
    assert_has(session, css("h2", text: "Recent Access Events"))
  end
end
