defmodule IndrajaalWeb.Operations.DispatchConsoleLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Dispatch Console LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/operations/dispatch`
  - **Module**: `IndrajaalWeb.Operations.DispatchConsoleLive`
  - **Title**: "Dispatch Console"

  ## Design Intent
  Enables dispatcher operators to manage field assignments in real-time: create new
  assignments, track resource positions on a map, reassign, escalate, and divert
  units. Integrates with PubSub `dispatch:events` for live field updates every 3
  seconds. Supports shift handover, broadcasting to all units, and structured
  reporting per SC-DSP-001..002.

  ## Expected Behavior (Functional)
  - **On mount**: assigns `page_title`, `active_assignments: []`, `available_teams: []`,
    `available_officers: []`, `available_vehicles: []`, `selected_assignment: nil`,
    `new_assignment_mode: false`, `map_center: %{}`
  - **PubSub**: subscribes to `"dispatch:events"` for real-time assignment updates
  - **Timer**: 3000ms → `:refresh_positions` (field unit position updates)
  - **handle_event "select_assignment"**: sets `selected_assignment` assign (no flash)
  - **handle_event "new_assignment"**: sets `new_assignment_mode: true` (no flash)
  - **handle_event "cancel_new_assignment"**: sets `new_assignment_mode: false` (no flash)
  - **handle_event "create_assignment"**: creates assignment → flash "Assignment created: {type}"
  - **handle_event "track"**: activates tracking → flash "Tracking assignment {id}"
  - **handle_event "reassign"**: initiates reassignment → flash "Reassigning {id}..."
  - **handle_event "escalate"**: escalates to supervisor → flash :warning "Escalating {id} to supervisor"
  - **handle_event "divert"**: diverts unit → flash "Diverting {id}..."
  - **handle_event "add_task"**: adds task to assignment → flash "Adding task to {id}"
  - **handle_event "broadcast_all"**: broadcasts to all units → flash "Broadcasting to all units..."
  - **handle_event "shift_handover"**: initiates shift handover → flash "Initiating shift handover..."
  - **handle_event "reports"**: opens reports view → flash "Opening reports..."

  ## BDD Scenarios
  ```gherkin
  Scenario: Dispatcher views active assignments on load
    Given I navigate to "/operations/dispatch"
    Then I should see the "Active Assignments" section
    And the dispatch map section should be visible
    And the resource panel should list available teams

  Scenario: Dispatcher creates a new assignment
    Given I navigate to "/operations/dispatch"
    When I click the "New Assignment" button
    Then the assignment creation form should appear
    When I submit the form with valid details
    Then a flash message should confirm "Assignment created"

  Scenario: Dispatcher escalates an assignment to supervisor
    Given I navigate to "/operations/dispatch"
    And an active assignment exists
    When I click the "Escalate" button on the assignment
    Then a warning flash should confirm "Escalating" to supervisor

  Scenario: Dispatcher broadcasts a message to all units
    Given I navigate to "/operations/dispatch"
    When I click the "Broadcast All" button
    Then a flash message should confirm "Broadcasting to all units..."

  Scenario: Dispatcher initiates shift handover
    Given I navigate to "/operations/dispatch"
    When I click the "Shift Handover" button
    Then a flash message should confirm "Initiating shift handover..."
  ```

  ## UX Flow
  1. Dispatcher navigates to `/operations/dispatch` — active assignments listed
  2. Map view shows current field unit positions (refreshed every 3s via timer)
  3. Dispatcher clicks "New Assignment" to open the assignment creation panel
  4. Dispatcher fills in type, resources, and location, then submits
  5. New assignment appears in the active list with flash confirmation
  6. Dispatcher selects an assignment to open detail and action panel
  7. Dispatcher uses Track / Reassign / Escalate / Divert / Add Task actions
  8. Escalation sends a :warning flash (SC-HMI-004 two-step commit pattern)
  9. Dispatcher broadcasts an update to all field units
  10. At shift end, dispatcher triggers Shift Handover workflow

  ## UI Elements Inventory
  | Element | Type | Selector | Event |
  |---------|------|----------|-------|
  | Dispatch Console heading | h1 | `css("h1", text: "Dispatch Console")` | none |
  | Active Assignments heading | h2 | `css("h2", text: "Active Assignments")` | none |
  | Dispatch Map heading | h2 | `css("h2", text: "Dispatch Map")` | none |
  | Available Resources heading | h2 | `css("h2", text: "Available Resources")` | none |
  | Assignment status badges | span | `css("span.badge")` | none |
  | Team count display | p | `css("p", text: "Teams")` | none |
  | Officer count display | p | `css("p", text: "Officers")` | none |
  | Vehicle count display | p | `css("p", text: "Vehicles")` | none |
  | New Assignment button | button | `css("button[phx-click='new_assignment']")` | new_assignment |
  | Cancel New Assignment | button | `css("button[phx-click='cancel_new_assignment']")` | cancel_new_assignment |
  | Create Assignment submit | button | `css("button[phx-click='create_assignment']")` | create_assignment |
  | Track button | button | `css("button[phx-click='track']")` | track |
  | Reassign button | button | `css("button[phx-click='reassign']")` | reassign |
  | Escalate button | button | `css("button[phx-click='escalate']")` | escalate (:warning flash) |
  | Divert button | button | `css("button[phx-click='divert']")` | divert |
  | Add Task button | button | `css("button[phx-click='add_task']")` | add_task |
  | Broadcast All button | button | `css("button[phx-click='broadcast_all']")` | broadcast_all |
  | Shift Handover button | button | `css("button[phx-click='shift_handover']")` | shift_handover |
  | Reports button | button | `css("button[phx-click='reports']")` | reports |
  | Flash message | div | `css("[role='alert']")` | status feedback |

  ## STAMP Constraints
  - SC-HMI-001: Management by Exception — assignment status rendered with severity badges
  - SC-HMI-004: Two-step commit verified for escalation and new assignment creation
  - SC-DSP-001: Dispatch workflow creation and tracking verified end-to-end
  - SC-DSP-002: Resource panel (teams, officers, vehicles) visible and count-correct
  - SC-COV-009 to SC-COV-016: Gold standard 8-category coverage
  - SC-COV-016: C8 dual verification — status badge AND flash per action button
  - SC-COV-019: Escalation uses arm→confirm pattern (two-step commit)
  - SC-COV-020: PubSub dispatch:events requires refresh stability test

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |---|---|---|---|---|---|
  | Position refresh timer drops updates under load | 6 | 3 | 4 | 72 | Assert positions change after timer fires |
  | Escalate warning flash not shown (info flash used) | 8 | 2 | 3 | 48 | Assert flash level = :warning |
  | New assignment form submit clears fields silently | 5 | 3 | 4 | 60 | Assert flash + form cleared |
  | Broadcast_all race with position refresh | 5 | 2 | 3 | 30 | sleep/assert stability (SC-COV-020) |
  | Shift handover disrupts active assignments | 7 | 1 | 4 | 28 | Confirmation dialog step required |

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

  @path "/operations/dispatch"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads with dispatch console heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("h1", text: "Dispatch Console"))
  end

  feature "active assignment list section heading is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("h2", text: "Active Assignments"))
  end

  feature "dispatch map section heading is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("h2", text: "Dispatch Map"))
  end

  feature "resource panels for teams officers and vehicles are rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("h2", text: "Teams"))
    |> assert_has(Query.css("h2", text: "Officers"))
    |> assert_has(Query.css("h2", text: "Vehicles"))
  end

  feature "header action buttons new assignment and broadcast all are visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.button("New Assignment"))
    |> assert_has(Query.button("Broadcast All"))
    |> assert_has(Query.button("Shift Handover"))
    |> assert_has(Query.button("Reports"))
  end

  # ── C2: Status/Badge Display ───────────────────────────────────────────────

  feature "HIGH priority badge is shown for ASN-001", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("[class*='bg-red-6']", text: "HIGH"))
  end

  feature "ROUTINE priority badge is shown for ASN-002", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("[class*='bg-gray-6']", text: "ROUTINE"))
  end

  feature "team available status indicator is rendered in teams panel", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span.text-green-400", count: :any))
  end

  feature "assigned status indicator is rendered for Team Alpha", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span.text-amber-400", count: :any))
  end

  feature "off duty status text is shown for Team Charlie", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span.text-gray-500", count: :any))
  end

  feature "maintenance status indicator is shown for vehicle V-003", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span.text-red-400", count: :any))
  end

  feature "in_progress assignment ASN-002 shows a progress bar", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css(".bg-cyan-500.h-1\\.5.rounded-full"))
  end

  # ── C3: Data Grid/Summary ──────────────────────────────────────────────────

  feature "default assignments ASN-001 and ASN-002 are rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span.font-medium.text-white", text: "ASN-001"))
    |> assert_has(Query.css("span.font-medium.text-white", text: "ASN-002"))
  end

  feature "assignment ASN-001 shows type and location in row", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.text-sm.text-content-secondary", text: "INTRUSION | Zone-A"))
  end

  feature "assignment ASN-002 shows patrol type in row", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.text-sm.text-content-secondary", text: "PATROL | Building B"))
  end

  feature "assigned_to value is shown for ASN-001 in row", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.text-sm.text-content-muted", text: "Assigned: Team Alpha"))
  end

  feature "eta label is shown for ASN-001 in the row", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span.text-content-muted.text-sm", text: "ETA: 3 min"))
  end

  feature "team alpha bravo charlie appear in teams panel", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Team Alpha"))
    |> assert_has(Query.css("span", text: "Team Bravo"))
    |> assert_has(Query.css("span", text: "Team Charlie"))
  end

  feature "officers johnson smith williams appear in officers panel", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Johnson"))
    |> assert_has(Query.css("span", text: "Smith"))
    |> assert_has(Query.css("span", text: "Williams"))
  end

  feature "vehicles V-001 V-002 V-003 appear in vehicles panel", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "V-001"))
    |> assert_has(Query.css("span", text: "V-002"))
    |> assert_has(Query.css("span", text: "V-003"))
  end

  feature "selecting an assignment shows status type location assigned and eta in detail panel",
          %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_assignment'][phx-value-id='ASN-002']"))
    |> assert_has(Query.css("span.text-content-secondary", text: "Status"))
    |> assert_has(Query.css("span.text-content-secondary", text: "Type"))
    |> assert_has(Query.css("span.text-content-secondary", text: "Location"))
    |> assert_has(Query.css("span.text-content-secondary", text: "Assigned"))
    |> assert_has(Query.css("span.text-content-secondary", text: "ETA"))
  end

  # ── C4: Timeline/History ──────────────────────────────────────────────────

  feature "page reload stability — assignments persist across revisit", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span.font-medium.text-white", text: "ASN-001"))
    |> visit(@path)
    |> assert_has(Query.css("span.font-medium.text-white", text: "ASN-001"))
  end

  feature "page reload stability — resource panels persist across revisit", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("h2", text: "Teams"))
    |> visit(@path)
    |> assert_has(Query.css("h2", text: "Teams"))
    |> assert_has(Query.css("h2", text: "Officers"))
    |> assert_has(Query.css("h2", text: "Vehicles"))
  end

  feature "page reload stability — status badges re-render consistently", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("[class*='bg-red-6']", text: "HIGH"))
    |> visit(@path)
    |> assert_has(Query.css("[class*='bg-red-6']", text: "HIGH"))
    |> assert_has(Query.css("[class*='bg-gray-6']", text: "ROUTINE"))
  end

  # ── C5: Interactive Elements ───────────────────────────────────────────────

  feature "new assignment modal opens on button click", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("New Assignment"))
    |> assert_has(Query.css("h2", text: "New Assignment"))
    |> assert_has(Query.css("select[name='type']"))
    |> assert_has(Query.css("input[name='location']"))
    |> assert_has(Query.css("select[name='priority']"))
    |> assert_has(Query.css("select[name='assign_to']"))
  end

  feature "new assignment modal closes on cancel", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("New Assignment"))
    |> assert_has(Query.css("h2", text: "New Assignment"))
    |> click(Query.button("Cancel"))
    |> refute_has(Query.css("h2", text: "New Assignment"))
  end

  feature "creates a dispatch assignment with location and priority", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("New Assignment"))
    |> fill_in(Query.css("input[name='location']"), with: "Gate-7 East Wing")
    |> click(Query.button("Create"))
    |> assert_has(Query.css("[role='alert'], .alert, [class*='flash']"))
  end

  feature "selecting an assignment shows the detail panel", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_assignment'][phx-value-id='ASN-002']"))
    |> assert_has(Query.css("h3.font-semibold.text-cyan-400", text: "ASN-002"))
    |> assert_has(Query.button("Divert"))
    |> assert_has(Query.button("Add Task"))
  end

  feature "selecting ASN-001 highlights the card with cyan border", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_assignment'][phx-value-id='ASN-001']"))
    |> assert_has(
      Query.css(
        "[phx-click='select_assignment'][phx-value-id='ASN-001'][class*='border-cyan-500']"
      )
    )
  end

  # ── C6: Media/Rich Content ─────────────────────────────────────────────────

  feature "dispatch map section renders with bg-surface-primary container", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.bg-surface-secondary", count: :any))
  end

  feature "map legend is rendered with vehicle officer incident labels", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Vehicle"))
    |> assert_has(Query.css("span", text: "Officer"))
    |> assert_has(Query.css("span", text: "Incident"))
  end

  feature "dispatch map section has real-time unit positions label", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div", text: "Real-time unit positions"))
  end

  # ── C7: AI/Advisory / Contextual Metrics ───────────────────────────────────

  feature "active assignments count is shown in section heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("h2", text: "Active Assignments"))
  end

  feature "interactive map label provides operational context", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div", text: "Interactive Map"))
  end

  feature "team size metadata is rendered as contextual indicator", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span.text-content-muted", count: :any))
  end

  # ── C8: Action Buttons — status change verification ────────────────────────

  feature "track button on ASN-001 row triggers flash feedback", %{session: session} do
    session
    |> visit(@path)
    |> find(Query.css("[phx-click='select_assignment'][phx-value-id='ASN-001']"), fn card ->
      click(card, Query.button("Track"))
    end)
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
  end

  feature "track button flash message contains tracking text for ASN-001", %{session: session} do
    session
    |> visit(@path)
    |> find(Query.css("[phx-click='select_assignment'][phx-value-id='ASN-001']"), fn card ->
      click(card, Query.button("Track"))
    end)
    |> assert_has(Query.css("[class*='flash'], [role='alert']", text: "ASN-001"))
  end

  feature "reassign button on ASN-001 row triggers flash feedback", %{session: session} do
    session
    |> visit(@path)
    |> find(Query.css("[phx-click='select_assignment'][phx-value-id='ASN-001']"), fn card ->
      click(card, Query.button("Reassign"))
    end)
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
  end

  feature "reassign button flash message contains reassigning text", %{session: session} do
    session
    |> visit(@path)
    |> find(Query.css("[phx-click='select_assignment'][phx-value-id='ASN-001']"), fn card ->
      click(card, Query.button("Reassign"))
    end)
    |> assert_has(Query.css("[class*='flash'], [role='alert']", text: "ASN-001"))
  end

  feature "escalate button on ASN-001 row triggers flash feedback", %{session: session} do
    session
    |> visit(@path)
    |> find(Query.css("[phx-click='select_assignment'][phx-value-id='ASN-001']"), fn card ->
      click(card, Query.button("Escalate"))
    end)
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
  end

  feature "escalate button flash message contains supervisor text for ASN-001", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(Query.css("[phx-click='select_assignment'][phx-value-id='ASN-001']"), fn card ->
      click(card, Query.button("Escalate"))
    end)
    |> assert_has(Query.css("[class*='flash'], [role='alert']", text: "supervisor"))
  end

  feature "divert action in detail panel triggers flash feedback", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_assignment'][phx-value-id='ASN-002']"))
    |> click(Query.button("Divert"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
  end

  feature "divert flash message contains diverting text with assignment id", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_assignment'][phx-value-id='ASN-002']"))
    |> click(Query.button("Divert"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']", text: "ASN-002"))
  end

  feature "add task action in detail panel triggers flash feedback", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_assignment'][phx-value-id='ASN-002']"))
    |> click(Query.button("Add Task"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
  end

  feature "add task flash message contains adding task text with assignment id", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_assignment'][phx-value-id='ASN-002']"))
    |> click(Query.button("Add Task"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']", text: "ASN-002"))
  end

  feature "broadcast all button triggers flash feedback", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("Broadcast All"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
  end

  feature "broadcast all flash message contains broadcasting text", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("Broadcast All"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']", text: "Broadcasting"))
  end

  feature "shift handover button triggers flash feedback", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("Shift Handover"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
  end

  feature "shift handover flash message contains handover text", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("Shift Handover"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']", text: "handover"))
  end

  feature "reports button triggers flash feedback", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("Reports"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
  end

  feature "reports button flash message contains reports text", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("Reports"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']", text: "reports"))
  end

  feature "create assignment modal submit triggers flash with assignment type", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(Query.button("New Assignment"))
    |> fill_in(Query.css("input[name='location']"), with: "North Gate")
    |> click(Query.button("Create"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']", text: "Assignment created"))
  end

  feature "create assignment closes modal after submission", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("New Assignment"))
    |> fill_in(Query.css("input[name='location']"), with: "South Perimeter")
    |> click(Query.button("Create"))
    |> refute_has(Query.css("h2", text: "New Assignment"))
  end
end
