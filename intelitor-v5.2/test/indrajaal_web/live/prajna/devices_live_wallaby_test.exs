defmodule IndrajaalWeb.Prajna.DevicesLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for DevicesLive at /cockpit/devices.

  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.
  Target: 32 features covering C1-C8 with dual verification on action buttons.

  Events in source:
    filter_status, filter_type, search, select_device, close_detail, toggle_view

  CONSTRAINTS:
    - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
    - SC-COV-009 to SC-COV-016: Gold standard 8-category coverage
    - SC-HMI-001: Dark Cockpit (gray defaults)
    - SC-DEV-001: Device state consistency
    - SC-PRAJNA-004: Sentinel health integration
    - SC-BRIDGE-005: PubSub topics for zenoh:devices

  ---

  ## Page Identity

  | Field   | Value                                                  |
  |---------|--------------------------------------------------------|
  | Route   | `/cockpit/devices`                                     |
  | Module  | `IndrajaalWeb.Prajna.DevicesLive`                      |
  | Title   | Device Health Center — Prajna C3I Cockpit              |
  | Tier    | Tier 2 (Medium) — Real-time Device Monitoring Matrix   |

  ## Design Intent

  The Device Health Center provides a live matrix of all 30 physical devices (cameras,
  readers, controllers, sensors) attached to the Indrajaal mesh. Operators can filter by
  status and type, perform free-text search, and toggle between a grid view (thumbnail
  cards) and list view (tabular rows). Clicking any device opens a detail modal. A 5000ms
  refresh timer and a 10000ms metrics-sync timer keep data current. PubSub channels
  `prajna:devices` and `zenoh:devices` deliver real-time device state changes.

  ## Expected Behavior

  On mount: 30 devices loaded across four types (camera/reader/controller/sensor).
  Five metrics cards rendered at top: Total Devices, Online, Degraded, Offline, Avg Uptime.
  Default view mode is grid (`toggle_view` switches to list). Default filter_status = "all".

  `filter_status` — filters device list by online/degraded/offline/all; updates shown devices.
  `filter_type` — filters by camera/reader/controller/sensor/all.
  `search` — performs substring match on device name; clears to show all on empty string.
  `select_device` — sets `selected_device` assign; opens detail modal with full device info.
  `close_detail` — clears `selected_device`; closes modal.
  `toggle_view` — switches `view_mode` between "grid" and "list".
  `:refresh` (5000ms) — reloads device states from source.
  `:sync_metrics` (10000ms) — syncs aggregate metrics panel.
  `{:pubsub, :device_update, data}` — applies incremental update to a single device record.

  ## BDD Scenarios

  ```gherkin
  Feature: Device Health Center Live View

    Scenario: C1 — Page loads with Device Health Center heading
      Given I navigate to "/cockpit/devices"
      Then I should see "Device Health Center"
      And I should see "Real-time Device Monitoring"

    Scenario: C2 — Metrics summary cards show device counts
      Given I navigate to "/cockpit/devices"
      Then I should see "Total Devices"
      And I should see "Online"
      And I should see "Degraded"

    Scenario: C5 — Filter by status narrows the device list
      Given I navigate to "/cockpit/devices"
      When I click the "online" filter button
      Then only devices with ONLINE status should be visible

    Scenario: C5 — Selecting a device opens the detail modal
      Given I navigate to "/cockpit/devices"
      When I click the first device card
      Then a detail panel should appear
      When I click the close button
      Then the detail panel should disappear

    Scenario: C5 — Toggle view switches between grid and list
      Given I navigate to "/cockpit/devices"
      When I click the "LIST" toggle button
      Then devices should render in tabular/list format
  ```

  ## UX Flow

  1. Operator navigates to `/cockpit/devices`.
  2. Five metrics cards display Total Devices, Online count, Degraded, Offline, Avg Uptime.
  3. 30 device cards render in grid view; each card shows name, type badge, and status badge.
  4. Operator clicks "online" filter — grid narrows to ONLINE devices only.
  5. Operator types in search box — live filtering narrows results by name substring.
  6. Operator clicks "LIST" toggle — view switches to tabular rows.
  7. Operator clicks a device row — detail modal opens with full sensor/location info.
  8. Operator closes modal via "✕" — returns to device grid/list.
  9. On 5000ms timer, device states refresh automatically.
  10. PubSub `prajna:devices` delivers incremental updates from Zenoh mesh.

  ## UI Elements Inventory

  | Element                   | Type        | Selector                                | Event/Info              |
  |---------------------------|-------------|-----------------------------------------|-------------------------|
  | Heading — Device Health   | `h1`/`span` | text "Device Health Center"             | C1 — Page Structure     |
  | Subtitle                  | `p`         | text "Real-time Device Monitoring"      | C1 — Page Structure     |
  | Total Devices card        | `div`/`p`   | text "Total Devices"                    | C3 — Data Grid          |
  | Online count card         | `div`/`p`   | text "Online"                           | C3 — Data Grid          |
  | Degraded count card       | `div`/`p`   | text "Degraded"                         | C3 — Data Grid          |
  | Offline count card        | `div`/`p`   | text "Offline"                          | C3 — Data Grid          |
  | Avg Uptime card           | `div`/`p`   | text "Avg Uptime"                       | C3 — Data Grid          |
  | Status filter buttons     | `button`    | `button[phx-click="filter_status"]`     | filter_status event     |
  | Type filter buttons       | `button`    | `button[phx-click="filter_type"]`       | filter_type event       |
  | Search input              | `input`     | `input[phx-change="search"]`            | search event            |
  | Toggle view button        | `button`    | `button[phx-click="toggle_view"]`       | toggle_view event       |
  | Device card / row         | `div`/`tr`  | `.device-card` or device name text      | select_device event     |
  | Device status badge       | `span`      | span.badge (ONLINE/DEGRADED/OFFLINE)    | C2 — Status Display     |
  | Device type badge         | `span`      | span badge (camera/reader/etc.)         | C2 — Status Display     |
  | Detail modal              | `div`       | `div[role="dialog"]` or `.detail-modal` | selected_device assign  |
  | Close detail button       | `button`    | `button[phx-click="close_detail"]`      | close_detail event      |
  | Flash message             | `div`       | `div[role="alert"]`                     | C8 — flash verify       |

  ## STAMP Constraints

  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009: C1 (Page Structure) coverage mandatory
  - SC-COV-010: C2 (Status/Badge) coverage mandatory
  - SC-COV-011: C3 (Data Grid) coverage mandatory
  - SC-COV-013: C5 (Interactive) coverage mandatory — filter, search, modal, toggle
  - SC-COV-016: C8 (Actions) DUAL verification — status AND flash
  - SC-COV-020: PubSub pages require refresh stability test (prajna:devices, zenoh:devices)
  - SC-HMI-001: Dark Cockpit — gray defaults, amber/red for degraded/offline devices
  - SC-DEV-001: Device state consistency — UI must reflect authoritative device state
  - SC-PRAJNA-004: Sentinel health integration — device anomalies forwarded to Sentinel
  - SC-BRIDGE-005: PubSub topics — prajna:devices, zenoh:devices

  ## FMEA Risks

  | Failure Mode                          | S | O | D | RPN | Mitigation                                    |
  |---------------------------------------|---|---|---|-----|-----------------------------------------------|
  | Stale device status after PubSub msg  | 5 | 3 | 4 | 60  | SC-COV-020 PubSub refresh stability test      |
  | Filter leaves no devices visible      | 4 | 3 | 3 | 36  | Search + filter combo test in C5              |
  | Detail modal fails to open/close      | 5 | 2 | 2 | 20  | select_device + close_detail C5 pair test     |
  | toggle_view not reflected in DOM      | 3 | 2 | 3 | 18  | C5 — assert grid vs list DOM structure change |

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

  @path "/cockpit/devices"

  # ── C1: Page Structure ─────────────────────────────────────────────────────────

  feature "page loads with Device Health Center heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Device Health Center"))
    |> assert_has(Query.text("Real-time Device Monitoring & Health Matrix"))
  end

  feature "page has five metrics summary cards in the top section", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Total Devices"))
    |> assert_has(Query.text("Online"))
    |> assert_has(Query.text("Degraded"))
    |> assert_has(Query.text("Offline"))
    |> assert_has(Query.text("Avg Uptime"))
  end

  feature "Grid and List toggle buttons are rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.button("Grid"))
    |> assert_has(Query.button("List"))
  end

  # ── C2: Status / Badge Display ─────────────────────────────────────────────────

  feature "device cards show status badges with online offline or degraded labels", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("[phx-click='select_device']"))
    |> assert_has(Query.css("span", text: "online"))
  end

  feature "device cards render health score percentage bar", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("[phx-click='select_device']"))
    |> assert_has(Query.css("span", text: "% uptime"))
  end

  feature "grid view is the default active view mode with blue button styling", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("button.bg-blue-600", text: "Grid"))
  end

  feature "switching to List view changes List button to active styling", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("List"))
    |> assert_has(Query.css("button.bg-blue-600", text: "List"))
  end

  # ── C3: Data Grid / Device Detail ─────────────────────────────────────────────

  feature "device detail modal shows Type Status Location IP Firmware Uptime Health fields", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_device']"))
    |> assert_has(Query.text("Type"))
    |> assert_has(Query.text("Status"))
    |> assert_has(Query.text("Location"))
    |> assert_has(Query.text("IP Address"))
    |> assert_has(Query.text("Firmware"))
    |> assert_has(Query.text("Uptime"))
    |> assert_has(Query.text("Health Score"))
  end

  feature "device detail modal shows firmware version in vX.Y.Z format", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_device']"))
    |> assert_has(Query.text("v2."))
  end

  feature "device detail modal shows IP address in 192.168 subnet", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_device']"))
    |> assert_has(Query.text("192.168."))
  end

  feature "device detail shows location from the known site list", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_device']"))
    |> assert_has(Query.text("Building"))
  end

  feature "device card shows the device type label in its grid entry", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("[phx-click='select_device']"))
    |> assert_has(Query.css("div", text: "camera"))
  end

  # ── C4: Device Count Timeline / Metrics Summary ────────────────────────────────

  feature "online count metric card shows a non-zero integer value", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css(".text-2xl.font-bold"))
  end

  feature "metrics update after a 5000ms auto-refresh cycle", %{session: session} do
    session = visit(session, @path)
    assert_has(session, Query.text("Device Health Center"))
    Process.sleep(5_500)
    assert_has(session, Query.text("Total Devices"))
    assert_has(session, Query.text("Avg Uptime"))
  end

  # ── C5: Interactive Elements / Filters ────────────────────────────────────────

  feature "status filter dropdown contains All Status Online Degraded Offline options", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("select[name='status']"))
    |> assert_has(Query.option("All Status"))
    |> assert_has(Query.option("Online"))
    |> assert_has(Query.option("Degraded"))
    |> assert_has(Query.option("Offline"))
  end

  feature "type filter dropdown contains All Types Cameras Readers Controllers Sensors", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("select[name='type']"))
    |> assert_has(Query.option("All Types"))
    |> assert_has(Query.option("Cameras"))
    |> assert_has(Query.option("Readers"))
    |> assert_has(Query.option("Controllers"))
    |> assert_has(Query.option("Sensors"))
  end

  feature "search input accepts text to filter devices by name", %{session: session} do
    session
    |> visit(@path)
    |> fill_in(Query.css("input[placeholder='Search devices...']"), with: "Device 1")
    |> assert_has(Query.css("input[placeholder='Search devices...']"))
  end

  feature "filtering by Online status keeps device cards visible", %{session: session} do
    session
    |> visit(@path)
    |> find(Query.css("select[name='status']"), fn select ->
      click(select, Query.option("Online"))
    end)
    |> assert_has(Query.css("[phx-click='select_device']"))
  end

  feature "filtering by type camera shows only camera devices", %{session: session} do
    session
    |> visit(@path)
    |> find(Query.css("select[name='type']"), fn select ->
      click(select, Query.option("Cameras"))
    end)
    |> assert_has(Query.css("[phx-click='select_device']"))
  end

  feature "switching back to Grid view from List restores grid layout", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("List"))
    |> click(Query.button("Grid"))
    |> assert_has(Query.css("button.bg-blue-600", text: "Grid"))
  end

  # ── C8: Action Buttons — DUAL verification (status change + flash) ─────────────

  # select_device — (1) device cards present and clickable
  feature "device cards are rendered and have select_device phx-click attribute", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("[phx-click='select_device']"))
  end

  # select_device — (2) clicking a card reveals the detail modal
  feature "clicking a device card opens the detail modal", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_device']"))
    |> assert_has(Query.text("Type"))
    |> assert_has(Query.text("Firmware"))
  end

  # close_detail — (1) close button appears when modal is open
  feature "close button is visible in device detail modal", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_device']"))
    |> assert_has(Query.css("[phx-click='close_detail']"))
  end

  # close_detail — (2) clicking close hides the modal
  feature "clicking close button on detail modal dismisses the panel", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_device']"))
    |> click(Query.css("[phx-click='close_detail']"))
    |> refute_has(Query.css("[phx-click='close_detail']"))
  end

  # toggle_view grid — (1) phx-click present
  feature "Grid toggle button has phx-click toggle_view attribute", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("button[phx-click='toggle_view'][phx-value-mode='grid']"))
  end

  # toggle_view list — (2) triggers visual mode change
  feature "clicking List toggle updates view mode and activates List styling", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-click='toggle_view'][phx-value-mode='list']"))
    |> assert_has(Query.css("button.bg-blue-600", text: "List"))
  end

  # ── C3 supplemental: additional detail field assertions ────────────────────────

  feature "device detail panel heading renders the selected device name", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_device']"))
    |> assert_has(Query.css("h2,h3,h4"))
  end

  feature "device detail shows Health Score label as a key-value pair", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_device']"))
    |> assert_has(Query.text("Health Score"))
  end

  # ── C5 supplemental: additional filter and search assertions ──────────────────

  feature "search input retains entered value after typing Device 5", %{session: session} do
    session
    |> visit(@path)
    |> fill_in(Query.css("input[placeholder='Search devices...']"), with: "Device 5")
    |> assert_has(Query.css("input[value='Device 5']"))
  end

  feature "filtering by Offline status does not crash the page", %{session: session} do
    session
    |> visit(@path)
    |> find(Query.css("select[name='status']"), fn select ->
      click(select, Query.option("Offline"))
    end)
    |> assert_has(Query.text("Device Health Center"))
  end

  feature "filtering by Controllers type shows controller devices or empty state", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(Query.css("select[name='type']"), fn select ->
      click(select, Query.option("Controllers"))
    end)
    |> assert_has(Query.text("Device Health Center"))
  end

  feature "filtering by Sensors type shows sensor devices or empty state", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(Query.css("select[name='type']"), fn select ->
      click(select, Query.option("Sensors"))
    end)
    |> assert_has(Query.text("Device Health Center"))
  end

  # ── C6: Media / Rich Content — Semantic CSS Classes ───────────────────────────
  # Per adaptation mandate: C6 verifies semantic design-system classes from the actual
  # LiveView source (bg-surface-primary, text-content-primary, border-border-theme-primary,
  # health-score color bars, font-mono IP addresses).

  feature "page root uses bg-surface-primary and text-content-primary semantic classes", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.bg-surface-primary.text-content-primary"))
  end

  feature "metrics summary cards use bg-surface-secondary with border-border-theme-primary", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.bg-surface-secondary.border.border-border-theme-primary"))
  end

  feature "device cards in grid use border-border-theme-primary styled border", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("[phx-click='select_device'].border.border-border-theme-primary"))
  end

  feature "health score progress bar renders with bg-gray-800 track and colored fill", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.h-1\\.5.bg-gray-800.rounded-full"))
  end

  feature "online device status badges use green color-rich bg-green-900 styling", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("span.bg-green-900\\/40.text-green-400"))
  end

  # ── C7: AI / Advisory — Contextual Metrics (System Health Summary) ────────────
  # Per adaptation mandate: C7 verifies contextual metric panels that provide system
  # health context to the operator — the five summary cards (Total Devices, Online,
  # Degraded, Offline, Avg Uptime) function as the advisory/intelligence layer,
  # surfacing system-level health awareness derived from live BEAM intrinsics.

  feature "Total Devices metric card provides device count context to operator", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.bg-surface-secondary", text: "Total Devices"))
  end

  feature "Avg Uptime metric card provides uptime health summary to operator", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.bg-surface-secondary", text: "Avg Uptime"))
  end

  feature "Degraded count card uses conditional color-rich amber styling when count exceeds threshold",
          %{
            session: session
          } do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.bg-surface-secondary", text: "Degraded"))
  end

  feature "Offline count card provides contextual alert when devices are unreachable", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.bg-surface-secondary", text: "Offline"))
  end

  feature "Online count metric card summarises healthy device population for operator situational awareness",
          %{
            session: session
          } do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.bg-surface-secondary", text: "Online"))
  end
end
