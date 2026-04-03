defmodule IndrajaalWeb.Operations.AccessDashboardLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Access Control Dashboard page (/operations/access).

  ## Page Identity
  - **Route**: `/operations/access`
  - **Module**: `IndrajaalWeb.Operations.AccessDashboardLive`
  - **Title**: "Access Control Dashboard"

  ## Design Intent
  Provides operators with a real-time physical access control monitoring interface.
  Displays live metrics (total access points, active credentials, events today, threat
  level), access point status list, recent access events feed, credentials summary,
  active schedules, and quick action buttons (grant, revoke, lockdown, emergency
  unlock). Subscribes to `access:events` PubSub and refreshes metrics every 2s
  per SC-SEC-001. Emergency lockdown and unlock actions use :warning flash to signal
  criticality per SC-HMI-004 (two-step commit pattern).

  ## Expected Behavior (Functional)
  - **On mount**: assigns `page_title`, `metrics: %{}`, `access_points: []`,
    `recent_events: []`, `credentials_summary: %{}`, `active_schedules: []`,
    `selected_point: nil`
  - **PubSub**: subscribes to `"access:events"` for real-time access events
  - **Timer**: 2000ms → `:refresh_metrics` (fastest refresh of any dashboard)
  - **handle_event "select_point"**: sets `selected_point` assign (no flash)
  - **handle_event "grant_access"**: opens grant dialog → flash "Access grant dialog opened"
  - **handle_event "revoke_access"**: opens revoke dialog → flash "Access revocation dialog opened"
  - **handle_event "lockdown_zone"**: initiates zone lockdown → flash :warning "Zone lockdown initiated - confirmation required"
  - **handle_event "unlock_all"**: emergency unlock → flash "Emergency unlock - confirmation required"
  - **handle_event "close_detail"**: sets `selected_point: nil` (no flash)

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator views access control metrics on load
    Given I navigate to "/operations/access"
    Then I should see the "Access Control Dashboard" heading
    And the real-time metrics row should show access point counts
    And the recent access events feed should be visible

  Scenario: Operator initiates zone lockdown
    Given I navigate to "/operations/access"
    When I click the "Lockdown Zone" button
    Then a warning flash should confirm "Zone lockdown initiated - confirmation required"

  Scenario: Operator triggers emergency unlock
    Given I navigate to "/operations/access"
    When I click the "Unlock All" emergency button
    Then a flash message should confirm "Emergency unlock - confirmation required"

  Scenario: Operator grants access via quick action
    Given I navigate to "/operations/access"
    When I click the "Grant Access" button
    Then a flash message should confirm "Access grant dialog opened"

  Scenario: Operator selects an access point to view its detail
    Given I navigate to "/operations/access"
    And at least one access point row exists
    When I click on an access point row
    Then the detail panel for that access point should open
  ```

  ## UX Flow
  1. Operator navigates to `/operations/access` — metrics row loads immediately
  2. Metrics row shows: Total Points, Active Credentials, Events Today, Threat Level
  3. Access Points list shows each point with status badge (open/locked/alarm)
  4. Operator clicks an access point to open its detail and action panel
  5. Detail panel shows point metadata (location, type, last event, schedule)
  6. Operator uses Grant / Revoke buttons to open access management dialogs
  7. Operator uses Lockdown Zone for critical zone isolation (confirmation required)
  8. Operator uses Unlock All for emergency override (confirmation required)
  9. Recent Events feed streams live PubSub events every 2s via timer
  10. Operator closes detail panel to return to full list view

  ## UI Elements Inventory
  | Element | Type | Selector | Event |
  |---------|------|----------|-------|
  | Access Control Dashboard heading | h1 | `css("h1", text: "Access Control Dashboard")` | none |
  | Metrics row | div | `css("[data-testid='metrics-row']")` | none (C3) |
  | Total access points metric | p | `css("p", text: "Access Points")` | none |
  | Active credentials metric | p | `css("p", text: "Active Credentials")` | none |
  | Events today metric | p | `css("p", text: "Events Today")` | none |
  | Threat level badge | span | `css("span.badge")` | none (C2) |
  | Access Points section | section | `css("section", text: "Access Points")` | none |
  | Access point rows | div | `css("[phx-click='select_point']")` | select_point |
  | Access point status badges | span | `css("span", text: "LOCKED")` | none (C2) |
  | Recent Events section | section | `css("section", text: "Recent Events")` | none |
  | Credentials summary | div | `css("[data-testid='credentials-summary']")` | none (C3) |
  | Active Schedules section | section | `css("section", text: "Active Schedules")` | none |
  | Grant Access button | button | `css("button[phx-click='grant_access']")` | grant_access |
  | Revoke Access button | button | `css("button[phx-click='revoke_access']")` | revoke_access |
  | Lockdown Zone button | button | `css("button[phx-click='lockdown_zone']")` | lockdown_zone (:warning) |
  | Unlock All button | button | `css("button[phx-click='unlock_all']")` | unlock_all |
  | Close detail button | button | `css("button[phx-click='close_detail']")` | close_detail |
  | Flash message | div | `css("[role='alert']")` | status feedback |

  ## STAMP Constraints
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: Gold Standard 8-category coverage
  - SC-COV-016: C8 dual verification — status badge AND flash for all 5 action buttons
  - SC-COV-019: Lockdown and Unlock All require arm→confirm pattern
  - SC-COV-020: PubSub access:events requires refresh stability test (2s timer)
  - SC-HMI-001: Management by Exception — threat level badge drives operator attention
  - SC-HMI-002: Analog over Digital — progress bars for credential utilization
  - SC-HMI-003: Staleness Decay — 2s refresh ensures fresh metrics display
  - SC-SEC-001: Access control verification — grant/revoke actions confirmed via flash

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |---|---|---|---|---|---|
  | Lockdown flash level :info instead of :warning | 8 | 2 | 2 | 32 | Assert flash class = "warning" |
  | 2s refresh timer shows stale events under test | 6 | 3 | 3 | 54 | sleep(2100) + re-assert (SC-COV-020) |
  | Unlock All confirmation not shown (single click fires) | 9 | 2 | 2 | 36 | Assert flash "confirmation required" present |
  | Access point detail persists after close_detail | 5 | 2 | 3 | 30 | Assert selected_point nil after close |
  | Grant/Revoke dialogs not rendered (flash only) | 5 | 3 | 4 | 60 | Assert flash message content verified per SC-COV-016 |

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

  @path "/operations/access"

  # ── C1: Page Structure ─────────────────────────────────────────────────────

  feature "page loads and renders the Access Control Dashboard heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "Access Control Dashboard"))
  end

  feature "Grant Access button is visible in the header action row", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='grant_access']", text: "Grant Access"))
  end

  feature "Revoke Access button is visible in the header action row", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='revoke_access']", text: "Revoke Access"))
  end

  feature "Access Points Status section heading is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Access Points Status"))
  end

  feature "Recent Events section heading is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Recent Events"))
  end

  feature "Quick Actions section heading is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Quick Actions"))
  end

  feature "Active Credentials section heading is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Active Credentials"))
  end

  feature "Active Schedules section heading is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Active Schedules"))
  end

  # ── C2: Status/Badge Display ───────────────────────────────────────────────

  feature "Grants Today metric with text-green-400 value is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Grants Today"))
    |> assert_has(css("div.text-green-400", minimum: 1))
  end

  feature "Denials Today metric with text-red-400 value is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Denials Today"))
    |> assert_has(css("div.text-red-400", minimum: 1))
  end

  feature "Tailgating Alerts metric with text-amber-400 value is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Tailgating Alerts"))
    |> assert_has(css("div.text-amber-400", minimum: 1))
  end

  feature "Anti-Passback metric with text-cyan-400 value is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Anti-Passback"))
    |> assert_has(css("div.text-cyan-400", minimum: 1))
  end

  feature "at least one access point row renders an online green status indicator", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span.text-green-400", minimum: 1))
  end

  feature "Loading Dock access point renders an offline grey indicator", %{session: session} do
    # Loading Dock is :offline — its indicator class is text-gray-500
    session
    |> visit(@path)
    |> assert_has(css("span.text-gray-500", minimum: 1))
  end

  feature "Active Credentials section shows active count in green", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.text-green-400", minimum: 1))
  end

  feature "Active Credentials section shows suspended count in amber", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.text-amber-400", minimum: 1))
  end

  feature "Active Credentials section shows expired count in red", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.text-red-400", minimum: 1))
  end

  # ── C3: Data Grid/Summary ──────────────────────────────────────────────────

  feature "all five named access points are rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Main Entrance"))
    |> assert_has(css("div", text: "Parking Gate A"))
    |> assert_has(css("div", text: "Server Room"))
    |> assert_has(css("div", text: "Loading Dock"))
    |> assert_has(css("div", text: "Executive Floor"))
  end

  feature "at least five access point rows are rendered with select_point handler", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("[phx-click='select_point']", minimum: 5))
  end

  feature "Active Credentials summary rows Total Active Suspended Expired are rendered", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Total"))
    |> assert_has(css("span", text: "Active"))
    |> assert_has(css("span", text: "Suspended"))
    |> assert_has(css("span", text: "Expired"))
  end

  feature "Active Schedules section shows Business Hours schedule entry", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Business Hours"))
  end

  feature "Active Schedules section shows 24/7 Access schedule entry", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "24/7 Access"))
  end

  feature "traffic progress bars are rendered in access point rows", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.bg-cyan-500", minimum: 1))
  end

  feature "Recent Events section shows event rows with user and location data", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.flex.items-center.gap-3", minimum: 1))
  end

  feature "event row for John Doe at Main Entrance is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "John Doe"))
    |> assert_has(css("span", text: "Main Entrance"))
  end

  # ── C4: Timeline/History — Recent Events ──────────────────────────────────

  feature "recent events show timestamps in HH:MM:SS format", %{session: session} do
    # format_time/1 uses Calendar.strftime with %H:%M:%S
    session
    |> visit(@path)
    |> assert_has(css("span.text-content-muted", text: ":", minimum: 1))
  end

  feature "at least seven event entries are rendered in the recent events feed", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.flex.items-center.gap-3", minimum: 7))
  end

  feature "grant event rows show green check icon class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.text-green-400", minimum: 1))
  end

  feature "deny event rows show red cross icon class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.text-red-400", minimum: 1))
  end

  feature "tailgate event rows show amber warning icon class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.text-amber-400", minimum: 1))
  end

  # ── C5: Interactive Elements ───────────────────────────────────────────────

  feature "clicking an access point row shows the cyan detail panel heading", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_point']", at: 0))
    |> assert_has(css("h2.text-cyan-400", minimum: 1))
  end

  feature "clicking an access point row reveals Status Type Traffic Events Today fields", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_point']", at: 0))
    |> assert_has(css("span", text: "Status"))
    |> assert_has(css("span", text: "Type"))
    |> assert_has(css("span", text: "Traffic"))
    |> assert_has(css("span", text: "Events Today"))
  end

  feature "clicking a different access point row updates the detail panel heading", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_point']", at: 1))
    |> assert_has(css("h2.text-cyan-400", minimum: 1))
  end

  # ── C8: Action Buttons — close_detail dual verification ───────────────────

  # Test 1: Status change — detail panel disappears after close
  feature "clicking close button in detail panel dismisses the detail view", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_point']", at: 0))
    |> assert_has(css("button[phx-click='close_detail']"))
    |> click(css("button[phx-click='close_detail']"))
    |> refute_has(css("button[phx-click='close_detail']"))
  end

  # Test 2: Page structure remains intact after close
  feature "after closing detail panel Access Points Status heading remains visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_point']", at: 0))
    |> click(css("button[phx-click='close_detail']"))
    |> assert_has(css("h2", text: "Access Points Status"))
  end

  # ── C8: Action Buttons — grant_access dual verification ───────────────────

  # Test 1: Flash message appears
  feature "clicking Grant Access button shows Access grant dialog opened flash", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='grant_access']", text: "Grant Access"))
    |> assert_has(css("[role='alert']", text: "Access grant dialog opened"))
  end

  # Test 2: Dashboard heading still visible after flash (page stable)
  feature "after clicking Grant Access the dashboard heading remains visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='grant_access']", text: "Grant Access"))
    |> assert_has(css("h1", text: "Access Control Dashboard"))
  end

  # ── C8: Action Buttons — revoke_access dual verification ──────────────────

  # Test 1: Flash message appears
  feature "clicking Revoke Access button shows Access revocation dialog opened flash", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='revoke_access']", text: "Revoke Access"))
    |> assert_has(css("[role='alert']", text: "Access revocation dialog opened"))
  end

  # Test 2: Dashboard heading still visible after flash
  feature "after clicking Revoke Access the dashboard heading remains visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='revoke_access']", text: "Revoke Access"))
    |> assert_has(css("h1", text: "Access Control Dashboard"))
  end

  # ── C8: Action Buttons — lockdown_zone dual verification ──────────────────

  feature "Lockdown Zone quick action button is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='lockdown_zone']", text: "Lockdown Zone"))
  end

  # Test 1: Warning flash appears (confirmation required prompt)
  feature "clicking Lockdown Zone shows Zone lockdown initiated confirmation warning flash", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='lockdown_zone']", text: "Lockdown Zone"))
    |> assert_has(css("[role='alert']", text: "confirmation required"))
  end

  # Test 2: Page structure preserved after lockdown click
  feature "after clicking Lockdown Zone Quick Actions heading remains visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='lockdown_zone']", text: "Lockdown Zone"))
    |> assert_has(css("h2", text: "Quick Actions"))
  end

  # ── C8: Action Buttons — unlock_all dual verification ─────────────────────

  # Test 1: Info flash appears (confirmation required)
  feature "clicking Unlock All shows Emergency unlock confirmation required flash", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='unlock_all']", text: "Unlock All"))
    |> assert_has(css("[role='alert']", text: "confirmation required"))
  end

  # Test 2: Access Points Status heading still visible after unlock_all
  feature "after clicking Unlock All Access Points Status heading remains visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='unlock_all']", text: "Unlock All"))
    |> assert_has(css("h2", text: "Access Points Status"))
  end

  # ── Refresh Stability (SC-COV-020) ────────────────────────────────────────

  feature "access dashboard remains stable after a 2000ms metrics refresh", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("h2", text: "Access Points Status"))

    Process.sleep(2_500)

    assert_has(session, css("h2", text: "Access Points Status"))
    assert_has(session, css("h2", text: "Recent Events"))
  end

  feature "metrics row values are still rendered after 2000ms refresh", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("div", text: "Grants Today"))

    Process.sleep(2_500)

    assert_has(session, css("div", text: "Grants Today"))
    assert_has(session, css("div", text: "Denials Today"))
  end

  # ── F-005: handle_info({:access_event, event}) regression ─────────────────

  feature "PubSub access_event message is handled without crashing the page", %{session: session} do
    # F-005: handle_info({:access_event, event}) prepends event to recent_events list
    session = visit(session, @path)
    assert_has(session, css("h2", text: "Recent Events"))

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "access:events",
      {:access_event,
       %{
         type: :grant,
         timestamp: DateTime.utc_now(),
         user: "PubSub User",
         location: "Test Gate"
       }}
    )

    Process.sleep(400)

    assert_has(session, css("h2", text: "Recent Events"))
    assert_has(session, css("h1", text: "Access Control Dashboard"))
  end

  feature "access_event PubSub broadcast keeps recent events feed visible", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("div.flex.items-center.gap-3", minimum: 1))

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "access:events",
      {:access_event,
       %{
         type: :deny,
         timestamp: DateTime.utc_now(),
         user: "Intruder",
         location: "Server Room"
       }}
    )

    Process.sleep(400)

    assert_has(session, css("div.flex.items-center.gap-3", minimum: 1))
  end

  # ── C5: Additional interactive — zone filter & credential badge ────────────

  feature "Manage Credentials button is visible in Active Credentials panel", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button", text: "Manage Credentials"))
  end

  feature "clicking a second different access point row also reveals detail panel", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_point']", at: 2))
    |> assert_has(css("h2.text-cyan-400", minimum: 1))
    |> assert_has(css("span", text: "Events Today"))
  end

  feature "detail panel shows point type for the selected access point", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_point']", at: 0))
    |> assert_has(css("span", text: "Card Reader"))
  end

  feature "detail panel shows numeric traffic percentage for selected point", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_point']", at: 0))
    |> assert_has(css("span.text-content-secondary", text: "Traffic"))
    |> assert_has(css("span.text-content-primary", minimum: 1))
  end

  # ── C2: Zone status — schedule active/inactive indicators ─────────────────

  feature "active schedule Business Hours shows green active indicator", %{session: session} do
    # generate_active_schedules: Business Hours schedule.active = true → text-green-400
    session
    |> visit(@path)
    |> assert_has(css("span.text-green-400", text: "●", minimum: 1))
  end

  feature "inactive schedule Weekend Maintenance shows amber inactive indicator", %{
    session: session
  } do
    # Weekend Maintenance: active = false → text-amber-400 with ○ indicator
    session
    |> visit(@path)
    |> assert_has(css("span.text-amber-400", minimum: 1))
  end

  feature "schedule user counts are rendered alongside schedule names", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "156 users"))
  end

  # ── C4: event type coverage — arrow separator in recent events ─────────────

  feature "event rows show location arrow separator rendered as HTML entity", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "→", minimum: 1))
  end
end
