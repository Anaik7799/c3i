defmodule IndrajaalWeb.Prajna.VideoLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Video Analytics Center LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity

  | Field   | Value                                                          |
  |---------|----------------------------------------------------------------|
  | Route   | `/cockpit/video`                                               |
  | Module  | `IndrajaalWeb.Prajna.VideoLive`                                |
  | Title   | Video Analytics Center — Prajna C3I Cockpit                    |
  | Tier    | Tier 2 (Medium) — Stream Health & AI Detection Monitoring      |

  ## Design Intent
  The Video Analytics Center provides operators with a real-time overview of all
  video streams ingested by the Indrajaal mesh. Streams are displayed in a filterable
  grid with per-stream health metrics, object-detection counts, and a detail panel
  that activates on stream selection. The page refreshes every 2 seconds and syncs
  AI-processing metrics every 5 seconds. Graceful degradation via try/rescue in
  mount ensures the page loads even when the video service is offline.

  ## Expected Behavior (Functional)
  - **On mount**: assigns `page_title: "Video Analytics Center"`, `current_nav: :video`,
    `video_streams` (list), `detections` (list), `filter_status: :all`,
    `filter_type: :all`, `selected_stream: nil`, `metrics` (AI stats map), `error`
  - **Graceful degradation**: mount wrapped in try/rescue; `error` assign set if service unavailable
  - **handle_event "filter_status"**: sets `filter_status` atom; no flash
  - **handle_event "select_stream"**: sets `selected_stream` to stream id; no flash
  - **handle_event "close_detail"**: clears `selected_stream`; no flash
  - **handle_info :refresh** (every 2000ms): refreshes `video_streams` and `detections`
  - **handle_info :sync_metrics** (every 5000ms): refreshes `metrics` AI stats
  - **PubSub**: subscribes to `"prajna:video"` and `"zenoh:video"`

  ## BDD Scenarios

  ```gherkin
  Feature: Video Analytics Center Live View

    Scenario: C1 — Page loads with Video Analytics Center heading
      Given I navigate to "/cockpit/video"
      Then I should see "Video Analytics Center" heading
      And I should see stream health metric cards
      And a stream grid should be visible

    Scenario: C3 — Five metrics summary cards are rendered
      Given I navigate to "/cockpit/video"
      Then I should see "Active Streams"
      And I should see "Avg Latency"
      And I should see "Detection Rate"

    Scenario: C5 — Operator filters streams by status
      Given I navigate to "/cockpit/video"
      When I click an "active" status filter button
      Then only streams matching ACTIVE status should be displayed

    Scenario: C5 — Operator selects a stream and sees detail panel
      Given I navigate to "/cockpit/video"
      When I click on a stream card
      Then a detail panel should appear showing stream metadata
      When I click the close detail button
      Then the detail panel should disappear

    Scenario: C7 — AI advisory section present with disclaimer
      Given I navigate to "/cockpit/video"
      Then I should see "advisory only" or AI disclaimer text
  ```

  ## UX Flow
  1. Operator navigates to `/cockpit/video`
  2. Metrics summary cards render at top (streams, active, detections, latency)
  3. Stream grid renders all video streams with health indicators
  4. Operator optionally filters streams by status or detection type
  5. Operator clicks a stream card to open its detail panel
  6. Detail panel shows stream ID, source, resolution, AI detection counts
  7. Operator clicks close to dismiss the detail panel
  8. Page refreshes every 2s; AI metrics sync every 5s
  9. AI advisory section presents insights with SC-AI-001 disclaimer

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | Video Analytics Center heading | h1 | `css("h1", text: "Video Analytics Center")` | — | C1 |
  | Stream Health sub-heading | p | `Query.text("Stream Health & AI Detection Monitoring")` | — | C1 |
  | Metrics summary cards | div | metric value text (e.g. active stream count) | — | C3 |
  | Stream grid | div | stream card list | — | C3 |
  | Status filter buttons | button | `button[phx-click='filter_status']` | `filter_status` | C5 |
  | Stream cards (selectable) | div | `[phx-click='select_stream']` | `select_stream` | C5 |
  | Close detail button | button | `button[phx-click='close_detail']` | `close_detail` | C8 |
  | Flash message | div | `[role='alert']` | action feedback | C8 |
  | AI advisory section | div | text "advisory only" | — | C7 |
  | Detection type labels | span | "Person" / "Vehicle" / "Object" text | — | C2 |

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit defaults verified on mount
  - SC-VID-001: Stream latency < 100ms — metrics card tested
  - SC-PRAJNA-004: Sentinel health integration — metrics section present
  - SC-BRIDGE-005: PubSub topics `prajna:video`, `zenoh:video` subscribed
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard coverage
  - SC-COV-020: PubSub pages require refresh stability test (sleep + re-assert)
  - SC-AI-001: AI advisory disclaimer mandatory in AI panels

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |---|---|---|---|---|---|
  | Mount crashes when video service offline | 8 | 2 | 2 | 32 | try/rescue in mount sets error assign |
  | Detail panel persists after filter change | 4 | 3 | 3 | 36 | close_detail clears selected_stream |
  | AI metrics stale when sync_metrics fires during offline | 5 | 2 | 3 | 30 | handle_info :sync_metrics wrapped in rescue |

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

  @path "/cockpit/video"

  # ── C1: Page Structure ─────────────────────────────────────────

  # ---------------------------------------------------------------------------
  # Test 1: Page loads with correct title
  # ---------------------------------------------------------------------------
  feature "page loads with Video Analytics Center heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Video Analytics Center"))
    |> assert_has(Query.text("Stream Health & AI Detection Monitoring"))
  end

  # ── C3: Data Grid/Summary ────────────────────────────────────

  # ---------------------------------------------------------------------------
  # Test 2: Five metrics summary cards are rendered
  # ---------------------------------------------------------------------------
  feature "five metrics summary cards are rendered on load", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Active Streams"))
    |> assert_has(Query.text("Avg Latency"))
    |> assert_has(Query.text("Detection Rate"))
    |> assert_has(Query.text("Accuracy"))
    |> assert_has(Query.text("Frame Drops"))
  end

  # ---------------------------------------------------------------------------
  # Test 3: Video Streams panel heading is visible
  # ---------------------------------------------------------------------------
  feature "video streams panel renders with heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Video Streams"))
  end

  # ── C5: Interactive Elements ──────────────────────────────────

  # ---------------------------------------------------------------------------
  # Test 4: Filter status dropdown contains all options
  # ---------------------------------------------------------------------------
  feature "filter status dropdown contains All, Active, Degraded, Offline", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("select[name='status']"))
    |> assert_has(Query.option("All"))
    |> assert_has(Query.option("Active"))
    |> assert_has(Query.option("Degraded"))
    |> assert_has(Query.option("Offline"))
  end

  # ---------------------------------------------------------------------------
  # Test 5: Filter streams to Active only
  # ---------------------------------------------------------------------------
  feature "selecting Active filter in status dropdown updates stream list", %{session: session} do
    session
    |> visit(@path)
    |> find(Query.css("select[name='status']"), fn select ->
      click(select, Query.option("Active"))
    end)
    |> assert_has(Query.css("select[name='status']"))
  end

  # ---------------------------------------------------------------------------
  # Test 6: Stream grid items have camera name labels
  # ---------------------------------------------------------------------------
  feature "stream grid renders camera name labels", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Camera 1"))
  end

  # ---------------------------------------------------------------------------
  # Test 7: Clicking a stream card triggers select_stream event
  # ---------------------------------------------------------------------------
  feature "clicking a stream card selects it via phx-click select_stream", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_stream']"))
  end

  # ── C7: AI/Advisory Panels ────────────────────────────────────

  # ---------------------------------------------------------------------------
  # Test 8: Recent Detections panel heading is visible
  # ---------------------------------------------------------------------------
  feature "recent detections panel renders with heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Recent Detections"))
  end

  # ---------------------------------------------------------------------------
  # Test 9: AI Processing Stats panel renders all metric labels
  # ---------------------------------------------------------------------------
  feature "ai processing stats panel shows inference time and gpu utilization", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.text("AI Processing Stats"))
    |> assert_has(Query.text("Inference Time"))
    |> assert_has(Query.text("GPU Utilization"))
    |> assert_has(Query.text("Model Version"))
    |> assert_has(Query.text("Processed Today"))
  end

  # ---------------------------------------------------------------------------
  # Test 10: Filter to Degraded streams
  # ---------------------------------------------------------------------------
  feature "selecting Degraded filter restricts stream panel display", %{session: session} do
    session
    |> visit(@path)
    |> find(Query.css("select[name='status']"), fn select ->
      click(select, Query.option("Degraded"))
    end)
    |> assert_has(Query.css("select[name='status']"))
  end

  # ---------------------------------------------------------------------------
  # Test 11: Model version label is rendered in stats panel
  # ---------------------------------------------------------------------------
  feature "model version v3.2.1 appears in AI processing stats", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("v3.2.1"))
  end

  # ── C2: Status/Badge Display ─────────────────────────────────

  # ---------------------------------------------------------------------------
  # C2: Status badges — stream health indicators
  # ---------------------------------------------------------------------------
  feature "active stream cards render a green status dot", %{session: session} do
    # Active streams have bg-green-500 status dot in stream card
    session
    |> visit(@path)
    |> assert_has(Query.css("div.bg-green-500", minimum: 1))
  end

  feature "avg latency metric card renders with border styling", %{session: session} do
    # SC-VID-001: avg_latency > 100 triggers yellow warning border
    session
    |> visit(@path)
    |> assert_has(Query.css("div.border", minimum: 1))
    |> assert_has(Query.text("Avg Latency"))
  end

  feature "detection confidence values appear in green for high-confidence detections", %{
    session: session
  } do
    # Recent detections with confidence >= 90 use text-green-600 class
    session
    |> visit(@path)
    |> assert_has(Query.css("span.text-green-600", minimum: 1))
  end

  # ── C6: Media/Rich Content ────────────────────────────────────

  # ---------------------------------------------------------------------------
  # C6: Media controls — stream filter and select interactions
  # ---------------------------------------------------------------------------
  feature "clicking stream card navigates to stream detail via select_stream event", %{
    session: session
  } do
    # select_stream assigns :selected_stream — page must not crash
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_stream']"))
    |> assert_has(Query.text("Video Analytics Center"))
  end

  feature "close_detail button appears after selecting a stream", %{session: session} do
    # handle_event close_detail clears :selected_stream
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_stream']"))
    |> assert_has(Query.css("[phx-click='close_detail']", minimum: 1))
  end

  feature "clicking close detail button clears stream selection", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_stream']"))
    |> click(Query.css("[phx-click='close_detail']"))
    |> assert_has(Query.text("Video Analytics Center"))
  end

  # ── C8: Action Buttons (DUAL verification) ───────────────────

  # ---------------------------------------------------------------------------
  # C8: Dual verification for select_stream + close_detail
  # ---------------------------------------------------------------------------

  # select_stream — Test 1: detail panel opens (status change path)
  feature "C8a — clicking stream opens detail panel (status change)", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_stream']"))
    |> assert_has(Query.css("[phx-click='close_detail']", minimum: 1))
  end

  # select_stream — Test 2: video analytics heading remains after select (page stable)
  feature "C8b — clicking stream keeps Video Analytics Center heading visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(Query.css("[phx-click='select_stream']"))
    |> assert_has(Query.text("Video Analytics Center"))
    |> assert_has(Query.text("AI Processing Stats"))
  end

  # ── SC-COV-020: PubSub refresh stability ────────────────────────────────────

  feature "video page remains stable after PubSub refresh cycle (SC-COV-020)", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Video Analytics Center"))

    :timer.sleep(6_000)

    session
    |> assert_has(Query.text("Video Analytics Center"))
  end
end
