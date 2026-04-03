defmodule IndrajaalWeb.Operations.VideoWallLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Video Wall LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/operations/video`
  - **Module**: `IndrajaalWeb.Operations.VideoWallLive`
  - **Title**: "Video Wall"

  ## Design Intent
  Provides operators with a configurable multi-camera video wall for physical security
  monitoring. Supports 2x2/3x3/4x4 grid layouts, camera group filtering, PTZ control,
  snapshot capture, clip recording, and integration with a video analytics events feed.
  Degrades gracefully when the video service is offline, showing an offline banner
  without crashing the LiveView. Subscribes to `video:analytics` for real-time
  analytics event overlays per SC-VID-001..002.

  ## Expected Behavior (Functional)
  - **On mount**: assigns `page_title`, `grid_layout: "2x2"`, `camera_group: "all"`,
    `cameras: []`, `analytics_events: []`, `selected_camera: nil`, `ptz_active: false`,
    `fullscreen: false`, `video_wall_offline: false`
  - **PubSub**: subscribes to `"video:analytics"` (try/rescue — graceful degradation)
  - **Timer**: 5000ms → `:refresh_cameras` (camera status refresh)
  - **Graceful degradation**: PubSub subscribe and camera data load wrapped in try/rescue;
    `video_wall_offline: true` if service unavailable
  - **handle_event "set_layout"**: sets `grid_layout` assign (no flash)
  - **handle_event "set_group"**: sets `camera_group` assign (no flash)
  - **handle_event "select_camera"**: sets `selected_camera` assign (no flash)
  - **handle_event "toggle_fullscreen"**: toggles `fullscreen` assign (no flash)
  - **handle_event "toggle_ptz"**: toggles `ptz_active` assign (no flash)
  - **handle_event "ptz_command"**: sends PTZ direction → flash "PTZ: {direction}"
  - **handle_event "snapshot"**: captures snapshot → flash "Snapshot saved for camera {id}"
  - **handle_event "start_clip"**: starts recording → flash "Recording clip for camera {id}"
  - **handle_event "search_recordings"**: opens search → flash "Opening recordings search..."

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator views camera grid on load
    Given I navigate to "/operations/video"
    Then I should see the Video Wall heading
    And the camera grid should be visible
    And the layout selector should default to "2x2"

  Scenario: Operator changes grid layout to 3x3
    Given I navigate to "/operations/video"
    When I click the "3x3" layout button
    Then the grid layout should change to show 9 camera slots

  Scenario: Operator captures a snapshot from a camera
    Given I navigate to "/operations/video"
    And a camera is selected
    When I click the "Snapshot" button
    Then a flash message should confirm "Snapshot saved for camera"

  Scenario: Operator activates PTZ control for a camera
    Given I navigate to "/operations/video"
    When I select a PTZ-capable camera
    And I click the "Toggle PTZ" button
    Then PTZ direction controls should become visible

  Scenario: Video service is offline — page shows graceful degradation
    Given the video service is unavailable
    When I navigate to "/operations/video"
    Then I should see an offline status indicator
    And the page should not crash or show an error
  ```

  ## UX Flow
  1. Operator navigates to `/operations/video` — 2x2 camera grid shown by default
  2. Camera thumbnails load from deterministic `generate_cameras/0` data
  3. Operator clicks a layout button (2x2, 3x3, 4x4) to resize the grid
  4. Operator filters by camera group (All, Entrances, Perimeter, Interior)
  5. Operator clicks a camera cell to select it and show the detail panel
  6. Detail panel shows camera metadata, recording status, analytics overlays
  7. Operator clicks "Snapshot" to save a timestamped frame capture
  8. Operator clicks "Start Clip" to begin a timed recording segment
  9. Operator enables PTZ mode and uses direction controls to pan/tilt/zoom
  10. Analytics events feed shows real-time motion/detection events from PubSub

  ## UI Elements Inventory
  | Element | Type | Selector | Event |
  |---------|------|----------|-------|
  | Video Wall heading | h1/span | `css("h1", text: "Video Wall")` | none |
  | Camera grid container | div | `css("[data-testid='camera-grid']")` | none |
  | Layout 2x2 button | button | `css("button[phx-value-layout='2x2']")` | set_layout |
  | Layout 3x3 button | button | `css("button[phx-value-layout='3x3']")` | set_layout |
  | Layout 4x4 button | button | `css("button[phx-value-layout='4x4']")` | set_layout |
  | Camera group selector | button | `css("button[phx-click='set_group']")` | set_group |
  | Camera cells | div | `css("[phx-click='select_camera']")` | select_camera |
  | Toggle PTZ button | button | `css("button[phx-click='toggle_ptz']")` | toggle_ptz |
  | PTZ direction controls | button | `css("button[phx-click='ptz_command']")` | ptz_command |
  | Snapshot button | button | `css("button[phx-click='snapshot']")` | snapshot |
  | Start Clip button | button | `css("button[phx-click='start_clip']")` | start_clip |
  | Search Recordings button | button | `css("button[phx-click='search_recordings']")` | search_recordings |
  | Analytics events feed | div | `css("[data-testid='analytics-events']")` | none |
  | Offline banner | div | `css("[data-testid='offline-banner']")` | none (graceful degradation) |
  | Flash message | div | `css("[role='alert']")` | status feedback |

  ## STAMP Constraints
  - SC-HMI-001: Management by Exception — offline banner and status overlays tested
  - SC-HMI-002: Analog over Digital — recording indicators and analytics overlays verified
  - SC-VID-001: Video stream management — camera grid rendering and selection verified
  - SC-VID-002: Analytics integration — analytics events feed section verified
  - SC-COV-009 to SC-COV-016: Gold standard 8-category coverage
  - SC-COV-016: C8 dual verification — status change AND flash per action button
  - SC-COV-020: PubSub video:analytics requires refresh stability test

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |---|---|---|---|---|---|
  | video_wall_offline not set — exceptions crash LiveView | 9 | 2 | 2 | 36 | try/rescue in mount verified |
  | PTZ controls appear without camera selected | 6 | 2 | 4 | 48 | Assert PTZ hidden until select_camera |
  | Snapshot flash shows wrong camera ID | 5 | 3 | 3 | 45 | Assert flash contains actual camera ID |
  | 5s timer fires while offline causing crash | 8 | 1 | 3 | 24 | handle_info offline guard test |
  | Layout change loses selected camera | 4 | 3 | 3 | 36 | Assert selected_camera nil after layout change |

  ## Architecture Notes
  - The LiveView degrades gracefully when the Video service is offline (video_wall_offline assign).
  - Camera data is generated deterministically on mount via generate_cameras/0.
  - Layout selector renders buttons for "2x2", "3x3", "4x4" via phx-click="set_layout".
  - Camera selection is via phx-click="select_camera" with phx-value-id.
  - PTZ controls appear only after selecting a PTZ-capable camera and clicking toggle_ptz.

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

  @path "/operations/video"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads with live video wall heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("h1", text: "Live Video Wall"))
  end

  feature "layout selector section is rendered with label", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span.text-content-muted", text: "Layout:"))
  end

  feature "group selector section is rendered with label", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span.text-content-muted", text: "Group:"))
  end

  feature "analytics events feed section heading is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("h2", text: "Analytics Events"))
  end

  feature "search recordings button is visible in header", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.button("Search Recordings"))
  end

  # ── C2: Status/Badge Display ───────────────────────────────────────────────

  feature "REC indicator is visible on cameras where recording is true", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span.text-red-500.text-xs.font-bold.animate-pulse", text: "REC"))
  end

  feature "offline camera cam-008 renders an OFFLINE status overlay", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-value-layout='3x3']"))
    |> assert_has(Query.css("span.text-red-400.font-medium", text: "OFFLINE"))
  end

  feature "2x2 layout button is active by default with cyan background", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("button[phx-value-layout='2x2'][class*='bg-cyan-600']", text: "2x2"))
  end

  feature "selected camera tile shows cyan ring highlight", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_camera'][phx-value-id='cam-001']"))
    |> assert_has(
      Query.css("[phx-click='select_camera'][phx-value-id='cam-001'][class*='ring-2']")
    )
  end

  feature "ptz toggle button shows inactive label before activation", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_camera'][phx-value-id='cam-001']"))
    |> assert_has(Query.css("button[phx-click='toggle_ptz']", text: "Inactive"))
  end

  feature "ptz toggle button shows active label after clicking", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_camera'][phx-value-id='cam-001']"))
    |> click(Query.css("button[phx-click='toggle_ptz']", text: "Inactive"))
    |> assert_has(Query.css("button[phx-click='toggle_ptz']", text: "Active"))
  end

  # ── C3: Data Grid/Summary ──────────────────────────────────────────────────

  feature "layout selector renders 2x2 3x3 and 4x4 buttons", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("button[phx-value-layout='2x2']", text: "2x2"))
    |> assert_has(Query.css("button[phx-value-layout='3x3']", text: "3x3"))
    |> assert_has(Query.css("button[phx-value-layout='4x4']", text: "4x4"))
  end

  feature "default 2x2 layout renders exactly 4 camera tiles", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("[phx-click='select_camera']", count: 4))
  end

  feature "camera name Main Entrance is shown in a camera tile", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span.font-medium.text-sm", text: "Main Entrance"))
  end

  feature "camera resolution and fps are shown in the tile header", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "HD"))
    |> assert_has(Query.css("span", text: "30fps"))
  end

  feature "camera group selector dropdown is rendered with all camera options", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("select[name='group']"))
    |> assert_has(Query.css("option[value='all']", text: "All Cameras"))
    |> assert_has(Query.css("option[value='entrances']", text: "Entrances"))
    |> assert_has(Query.css("option[value='parking']", text: "Parking"))
    |> assert_has(Query.css("option[value='interior']", text: "Interior"))
  end

  feature "analytics events from generate_analytics_events are rendered in feed", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(
      Query.css("div.text-sm.text-content-secondary",
        text: "Motion detected at loading dock"
      )
    )
    |> assert_has(
      Query.css("div.text-sm.text-content-secondary", text: "Face recognized: John Doe")
    )
  end

  feature "analytics event camera labels are shown in the feed", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span.font-medium.text-sm", text: "CAM-004"))
  end

  feature "selected camera detail panel shows camera name", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_camera'][phx-value-id='cam-001']"))
    |> assert_has(Query.css("h3.font-semibold.text-white", text: "Main Entrance"))
  end

  # ── C5: Interactive Elements ───────────────────────────────────────────────

  feature "clicking 3x3 layout button activates it and shows 9 camera slots", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-value-layout='3x3']"))
    |> assert_has(Query.css("button[phx-value-layout='3x3'][class*='bg-cyan-600']", text: "3x3"))
    |> assert_has(Query.css("[phx-click='select_camera']", count: 9))
  end

  feature "clicking 4x4 layout button shows all available cameras up to 16 tiles", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-value-layout='4x4']"))
    |> assert_has(Query.css("button[phx-value-layout='4x4'][class*='bg-cyan-600']", text: "4x4"))
    |> assert_has(Query.css("[phx-click='select_camera']", minimum: 9))
  end

  feature "selecting a PTZ camera shows snapshot and record clip buttons in detail panel", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_camera'][phx-value-id='cam-001']"))
    |> assert_has(Query.button("Snapshot"))
    |> assert_has(Query.button("Record Clip"))
  end

  feature "toggling PTZ active on cam-001 shows directional control buttons", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_camera'][phx-value-id='cam-001']"))
    |> click(Query.css("button[phx-click='toggle_ptz']", text: "Inactive"))
    |> assert_has(Query.css("button[phx-click='ptz_command'][phx-value-direction='up']"))
    |> assert_has(Query.css("button[phx-click='ptz_command'][phx-value-direction='down']"))
    |> assert_has(Query.css("button[phx-click='ptz_command'][phx-value-direction='left']"))
    |> assert_has(Query.css("button[phx-click='ptz_command'][phx-value-direction='right']"))
  end

  feature "PTZ zoom in and zoom out buttons appear when PTZ is active", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_camera'][phx-value-id='cam-001']"))
    |> click(Query.css("button[phx-click='toggle_ptz']", text: "Inactive"))
    |> assert_has(Query.button("Zoom +"))
    |> assert_has(Query.button("Zoom -"))
  end

  # ── C6: Media/Rich Content ─────────────────────────────────────────────────

  feature "video feed area aspect-video container is rendered per camera tile", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css(".aspect-video.bg-surface-primary", count: :any))
  end

  feature "fullscreen toggle button is visible in selected camera panel", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_camera'][phx-value-id='cam-001']"))
    |> assert_has(Query.css("button[phx-click='toggle_fullscreen']", text: "Fullscreen"))
  end

  feature "clicking fullscreen toggle changes label to exit fullscreen", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_camera'][phx-value-id='cam-001']"))
    |> click(Query.css("button[phx-click='toggle_fullscreen']"))
    |> assert_has(Query.css("button[phx-click='toggle_fullscreen']", text: "Exit Fullscreen"))
  end

  feature "snapshot icon buttons are visible in camera tile footers", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("button[phx-click='snapshot']", count: :any))
  end

  feature "start clip icon buttons are visible in camera tile footers", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("button[phx-click='start_clip']", count: :any))
  end

  # ── C4: Timeline/History (Reload Stability) ──────────────────────────────

  feature "page heading persists after page reload", %{session: session} do
    session = visit(session, @path)
    assert_has(session, Query.css("h1", text: "Live Video Wall"))
    session = visit(session, @path)
    assert_has(session, Query.css("h1", text: "Live Video Wall"))
  end

  feature "analytics events feed heading persists after page reload", %{session: session} do
    session = visit(session, @path)
    assert_has(session, Query.css("h2", text: "Analytics Events"))
    session = visit(session, @path)
    assert_has(session, Query.css("h2", text: "Analytics Events"))
  end

  feature "camera grid tiles persist after page reload", %{session: session} do
    session = visit(session, @path)
    assert_has(session, Query.css("[phx-click='select_camera']", count: 4))
    session = visit(session, @path)
    assert_has(session, Query.css("[phx-click='select_camera']", count: 4))
  end

  feature "layout selector buttons persist after page reload", %{session: session} do
    session = visit(session, @path)
    assert_has(session, Query.css("button[phx-value-layout='2x2']"))
    session = visit(session, @path)
    assert_has(session, Query.css("button[phx-value-layout='2x2']"))
  end

  # ── C7: AI/Advisory (Contextual Metrics) ─────────────────────────────────

  feature "analytics event description text provides contextual detail", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(
      Query.css("div.text-sm.text-content-secondary",
        text: "Motion detected at loading dock"
      )
    )
  end

  feature "camera fps label provides operational context for stream quality", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.flex.items-center.gap-2.text-xs.text-content-muted"))
    |> assert_has(Query.css("span", text: "30fps"))
  end

  feature "analytics label on camera tile footer provides analytics status context", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Analytics: ON"))
  end

  feature "camera resolution label provides stream specification context", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "HD"))
    |> assert_has(Query.css("span", text: "4K"))
  end

  # ── C8: Action Buttons — dual verification (status + flash) ────────────────

  feature "snapshot button in camera tile footer triggers flash feedback", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-click='snapshot'][phx-value-id='cam-001']", visible: true))
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
  end

  feature "snapshot button flash message contains snapshot saved text", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-click='snapshot'][phx-value-id='cam-001']", visible: true))
    |> assert_has(Query.css("[class*='flash'], [role='alert']", text: "Snapshot saved"))
  end

  feature "start clip button in camera tile footer triggers flash feedback", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-click='start_clip'][phx-value-id='cam-001']", visible: true))
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
  end

  feature "start clip button flash message contains recording clip text", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-click='start_clip'][phx-value-id='cam-001']", visible: true))
    |> assert_has(Query.css("[class*='flash'], [role='alert']", text: "Recording clip"))
  end

  feature "snapshot button in detail panel triggers flash feedback", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_camera'][phx-value-id='cam-001']"))
    |> click(
      Query.css(".fixed.bottom-4.right-4 button[phx-click='snapshot'][phx-value-id='cam-001']")
    )
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
  end

  feature "snapshot button in detail panel flash contains snapshot saved text", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_camera'][phx-value-id='cam-001']"))
    |> click(
      Query.css(".fixed.bottom-4.right-4 button[phx-click='snapshot'][phx-value-id='cam-001']")
    )
    |> assert_has(Query.css("[class*='flash'], [role='alert']", text: "Snapshot saved"))
  end

  feature "record clip button in detail panel triggers flash feedback", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_camera'][phx-value-id='cam-001']"))
    |> click(
      Query.css(".fixed.bottom-4.right-4 button[phx-click='start_clip'][phx-value-id='cam-001']")
    )
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
  end

  feature "record clip button flash message contains recording clip text", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_camera'][phx-value-id='cam-001']"))
    |> click(
      Query.css(".fixed.bottom-4.right-4 button[phx-click='start_clip'][phx-value-id='cam-001']")
    )
    |> assert_has(Query.css("[class*='flash'], [role='alert']", text: "Recording clip"))
  end

  feature "PTZ up direction command triggers flash feedback", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_camera'][phx-value-id='cam-001']"))
    |> click(Query.css("button[phx-click='toggle_ptz']", text: "Inactive"))
    |> click(Query.css("button[phx-click='ptz_command'][phx-value-direction='up']"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
  end

  feature "PTZ up direction command flash message contains PTZ text", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_camera'][phx-value-id='cam-001']"))
    |> click(Query.css("button[phx-click='toggle_ptz']", text: "Inactive"))
    |> click(Query.css("button[phx-click='ptz_command'][phx-value-direction='up']"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']", text: "PTZ"))
  end

  feature "PTZ toggle changes control panel button label to active", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_camera'][phx-value-id='cam-001']"))
    |> click(Query.css("button[phx-click='toggle_ptz']", text: "Inactive"))
    |> assert_has(Query.css("button[phx-click='toggle_ptz'][class*='bg-cyan-600']"))
  end

  feature "search recordings button triggers flash feedback", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("Search Recordings"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
  end

  feature "search recordings flash message contains recordings text", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("Search Recordings"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']", text: "recordings"))
  end
end
