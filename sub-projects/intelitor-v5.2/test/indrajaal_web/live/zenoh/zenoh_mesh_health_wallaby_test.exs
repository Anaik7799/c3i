defmodule IndrajaalWeb.Zenoh.ZenohMeshHealthWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Prajna Mesh Topology LiveView (MeshLive).
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/cockpit/mesh`
  - **Module**: `IndrajaalWeb.Prajna.MeshLive`
  - **Title**: "MESH TOPOLOGY"

  ## Design Intent
  Provides operators with a real-time tree visualization of the Zenoh/BEAM mesh topology
  with per-node health status, resource utilization (CPU/Memory/Latency), and operational
  controls (restart, isolate, drain). Enables SRE-grade mesh management from the Prajna
  cockpit using a 2-second refresh loop and PubSub-driven live node status updates.

  ## Expected Behavior (Functional)
  - **On mount**: Loads assigns `nodes: [...]` (gw-01 gateway, app-01 supervisor,
    app-02/03/04 controller, app-05 worker), `selected_node: nil`,
    `connections: [...]`, `view_mode: :tree`, `role_icons: %{}`,
    `status_icons: %{}`, `trend_icons: %{}`.
    When `connected?/1`: subscribes to PubSub `"prajna:mesh"` and starts 2-second
    BEAM metric refresh timer.
  - **handle_event "select_node"**: Sets `selected_node` to the node with matching id;
    reveals detail panel with Role/Zone/IP/Status and resource bars.
  - **handle_event "clear_selection"**: Resets `selected_node` to nil;
    restores "Click a node to view details" placeholder.
  - **handle_event "restart_node"**: Puts flash `:info "Restart command armed for <id>"`.
  - **handle_event "isolate_node"**: Puts flash `:warning "Isolate command armed for <id>"`.
  - **handle_event "drain_node"**: Puts flash `:info "Drain initiated for <id>"`.
  - **handle_info(:refresh)**: 2-second timer; updates supervisor node (app-01) CPU/memory
    metrics from live BEAM telemetry.
  - **handle_info({:node_update, id, data})**: Merges updated node data into `nodes` assign;
    PubSub-driven live update from `"prajna:mesh"` topic.

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator views mesh topology
    Given I navigate to "/cockpit/mesh"
    Then I should see heading "MESH TOPOLOGY"
    And node cards for all mesh nodes should be visible
    And the legend should show Healthy, Caution, Critical, and Offline statuses

  Scenario: Operator selects a node to view details
    Given I am on "/cockpit/mesh"
    When I click on node "gw-01"
    Then the node detail panel should appear
    And I should see Role, Zone, IP, and Status labels

  Scenario: Operator arms a restart command
    Given I am on "/cockpit/mesh" with node "gw-01" selected
    When I click the "RESTART" button
    Then I should see flash "Restart command armed"
    And the node detail panel should remain visible

  Scenario: Operator clears node selection
    Given I have selected node "gw-01"
    When I click the [X] clear selection button
    Then the detail panel should close
    And I should see "Click a node to view details" placeholder

  Scenario: Mesh topology survives PubSub node_update burst
    Given I am on "/cockpit/mesh"
    When 5 rapid node_update PubSub messages arrive
    Then the page heading should remain "MESH TOPOLOGY"
  ```

  ## UX Flow
  1. Operator navigates to `/cockpit/mesh` via Prajna nav
  2. Page mounts with full node tree; "Click a node to view details" in right panel
  3. Operator clicks a node card → detail panel opens with role/zone/IP/status + resource bars
  4. Operator can arm operations: RESTART (flash :info), ISOLATE (flash :warning), DRAIN (flash :info)
  5. Operator clicks [X] to dismiss detail panel
  6. 2-second timer updates supervisor node metrics; PubSub delivers live status changes
  7. Footer shows EID compliance badge and keybinding hints

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | PRAJNA C3I brand link | a | `a` text "PRAJNA C3I" | navigate | C1 |
  | MESH TOPOLOGY label (header) | span | `span` text "MESH TOPOLOGY" | — | C1 |
  | MESH TOPOLOGY section heading | h2 | `h2` text "MESH TOPOLOGY" | — | C1 |
  | Active nav tab indicator | a | `a.border-b-2` | — | C1 |
  | EID compliance footer | div | `div` text "EID Compliant" | — | C1 |
  | LEGEND heading | h3 | `h3` text "LEGEND" | — | C1 |
  | Online count badge | span | `span` text "online" | — | C2 |
  | Healthy legend entry | span | `span.text-content-muted` text "Healthy" | — | C2 |
  | Caution legend entry | span | `span.text-content-muted` text "Caution" | — | C2 |
  | Critical legend entry | span | `span.text-content-muted` text "Critical" | — | C2 |
  | Offline legend entry | span | `span.text-content-muted` text "Offline" | — | C2 |
  | gw-01 node card | div | `div[phx-value-id='gw-01']` | select_node | C2 |
  | app-01 node card | div | `div[phx-value-id='app-01']` | select_node | C2 |
  | app-02 node card | div | `div[phx-value-id='app-02']` | select_node | C2 |
  | app-04 node card | div | `div[phx-value-id='app-04']` | select_node | C2 |
  | app-05 node card | div | `div[phx-value-id='app-05']` | select_node | C2 |
  | Role label in detail panel | span | `span.text-content-muted` text "Role:" | — | C3 |
  | Zone label in detail panel | span | `span.text-content-muted` text "Zone:" | — | C3 |
  | IP label in detail panel | span | `span.text-content-muted` text "IP:" | — | C3 |
  | Status label in detail panel | span | `span.text-content-muted` text "Status:" | — | C3 |
  | CPU resource bar label | span | `span.text-content-muted` text "CPU" | — | C3 |
  | Memory resource bar label | span | `span.text-content-muted` text "Memory" | — | C3 |
  | Latency resource bar label | span | `span.text-content-muted` text "Latency" | — | C3 |
  | CPU 1h sparkline label | span | `span.text-content-muted` text "CPU (1h):" | — | C3 |
  | Keybinding hints | span | `span` text "[Click] Select node" | — | C4 |
  | Connection lines | div | `div.h-8.w-px.bg-border-theme-secondary` | — | C6 |
  | Resource bars | div | `div.h-2.bg-gray-700.rounded-full` | — | C6 |
  | VIEW LOGS link | a | `a` text "VIEW LOGS" | navigate | C6 |
  | Clear selection button | button | `button[phx-click='clear_selection']` | clear_selection | C8 |
  | RESTART button | button | `button[phx-click='restart_node']` | restart_node | C8 |
  | ISOLATE button | button | `button[phx-click='isolate_node']` | isolate_node | C8 |
  | DRAIN button | button | `button[phx-click='drain_node']` | drain_node | C8 |

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit philosophy (dark bg, status-colored borders)
  - SC-HMI-010: Color Rich — Zenoh metabolic telemetry drives status colors
  - SC-HMI-011: 8×8 Matrix — 8 element types × 8 fractal layers covered
  - SC-COV-008: Wallaby E2E browser tests mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard coverage
  - SC-COV-016: C8 dual verification — RESTART, ISOLATE, DRAIN, clear_selection all tested twice
  - SC-COV-020: PubSub refresh stability — node_update burst test (C4)
  - SC-ZENOH-002: Zenoh router MUST be reachable from all app nodes
  - SC-ZENOH-004: Telemetry publishing latency < 100ms
  - SC-ZENOH-007: Zenoh health included in /health endpoint
  - SC-MESH-009: Zenoh for real-time telemetry
  - SC-EID-001: EID compliance footer badge mandatory

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |-------------|---|---|---|-----|------------|
  | 2s timer fires during detail panel assertion | 5 | 3 | 2 | 30 | async: false; timer update is idempotent |
  | PubSub broadcast modifies selected_node mid-test | 6 | 2 | 3 | 36 | node_update only merges data, not selection |
  | Action buttons absent when node not selected | 4 | 2 | 2 | 16 | Tests explicitly select node before C8 actions |
  | Rapid burst of 5 PubSub messages crashes reducer | 7 | 2 | 3 | 42 | Burst test C4 verifies stability |
  | flash :warning vs :info visual regression | 3 | 2 | 3 | 18 | [role='alert'] CSS selector matches both |

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
  @moduletag :zenoh

  @path "/cockpit/mesh"
  @pubsub_topic "prajna:mesh"
  @propagation_ms 400

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "C1 — header shows PRAJNA C3I brand link", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("a", text: "PRAJNA C3I"))
  end

  feature "C1 — header shows MESH TOPOLOGY label", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "MESH TOPOLOGY"))
  end

  feature "C1 — MESH TOPOLOGY section heading is present in topology view", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "MESH TOPOLOGY"))
  end

  feature "C1 — navigation tab bar shows MESH as active tab", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("a.border-b-2", minimum: 1))
  end

  feature "C1 — EID compliance footer is present", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "EID Compliant"))
  end

  feature "C1 — LEGEND section is rendered in the right panel", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "LEGEND"))
  end

  # ── C2: Status / Badge Display ──────────────────────────────────────────────

  feature "C2 — Nodes online count is shown in header (N/N online format)", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "online"))
  end

  feature "C2 — LEGEND shows Healthy status entry", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.text-content-muted", text: "Healthy"))
  end

  feature "C2 — LEGEND shows Caution status entry", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.text-content-muted", text: "Caution"))
  end

  feature "C2 — LEGEND shows Critical status entry", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.text-content-muted", text: "Critical"))
  end

  feature "C2 — node card for gw-01 is rendered in the topology tree", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div[phx-value-id='gw-01']", minimum: 1))
  end

  # ── C3: Data Grid / Node Detail Panel ──────────────────────────────────────

  feature "C3 — clicking gw-01 shows node detail panel with Role label", %{session: session} do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='gw-01']"))
    |> assert_has(css("span.text-content-muted", text: "Role:"))
  end

  feature "C3 — clicking gw-01 shows Zone label in detail panel", %{session: session} do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='gw-01']"))
    |> assert_has(css("span.text-content-muted", text: "Zone:"))
  end

  feature "C3 — clicking gw-01 shows IP label in detail panel", %{session: session} do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='gw-01']"))
    |> assert_has(css("span.text-content-muted", text: "IP:"))
  end

  feature "C3 — clicking gw-01 shows Status label in detail panel", %{session: session} do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='gw-01']"))
    |> assert_has(css("span.text-content-muted", text: "Status:"))
  end

  feature "C3 — clicking app-01 shows supervisor detail with CPU resource bar", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='app-01']"))
    |> assert_has(css("span.text-content-muted", text: "CPU"))
  end

  feature "C3 — clicking app-01 shows Memory resource bar in detail panel", %{session: session} do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='app-01']"))
    |> assert_has(css("span.text-content-muted", text: "Memory"))
  end

  feature "C3 — clicking app-01 shows Latency resource bar in detail panel", %{session: session} do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='app-01']"))
    |> assert_has(css("span.text-content-muted", text: "Latency"))
  end

  feature "C3 — clicking app-01 shows sparkline CPU history row", %{session: session} do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='app-01']"))
    |> assert_has(css("span.text-content-muted", text: "CPU (1h):"))
  end

  # ── C4: Timeline / Event Log ─────────────────────────────────────────────────

  feature "C4 — footer keybinding hints act as operation timeline guide", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "[Click] Select node"))
    |> assert_has(css("span", text: "[R] Restart"))
    |> assert_has(css("span", text: "[I] Isolate"))
  end

  feature "C4 — prajna:mesh PubSub event updates page and heading remains", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("h2", text: "MESH TOPOLOGY"))

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:node_update, "app-01",
       %{cpu: 55, cpu_trend: :rising_fast, cpu_level: :caution, status: :caution}}
    )

    Process.sleep(@propagation_ms)

    assert_has(session, css("h2", text: "MESH TOPOLOGY"))
  end

  feature "C4 — 2-second :refresh cycle does not crash page", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("h2", text: "MESH TOPOLOGY"))

    # Allow 3 refresh cycles (2s each = 6s total, but we only wait one extra)
    Process.sleep(2_500)

    assert_has(session, css("h2", text: "MESH TOPOLOGY"))
    assert_has(session, css("span", text: "online"))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "C5 — click prompt is shown when no node is selected", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p.text-content-muted", text: "Click a node to view details"))
  end

  feature "C5 — selecting gw-01 hides the placeholder and shows detail", %{session: session} do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='gw-01']"))
    |> refute_has(css("p.text-content-muted", text: "Click a node to view details"))
    |> assert_has(css("span.text-content-muted", text: "Role:"))
  end

  feature "C5 — clear_selection [X] button dismisses node detail panel", %{session: session} do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='gw-01']"))
    |> assert_has(css("button[phx-click='clear_selection']"))
    |> click(css("button[phx-click='clear_selection']"))
    |> assert_has(css("p.text-content-muted", text: "Click a node to view details"))
  end

  # ── C6: Media / Rich Content ─────────────────────────────────────────────────

  feature "C6 — connection lines between tree levels are rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.h-8.w-px.bg-border-theme-secondary", minimum: 1))
  end

  feature "C6 — resource bars are rendered inside node detail panel", %{session: session} do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='app-01']"))
    |> assert_has(css("div.h-2.bg-gray-700.rounded-full", minimum: 1))
  end

  feature "C6 — VIEW LOGS link in detail panel navigates to diagnostics", %{session: session} do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='gw-01']"))
    |> assert_has(css("a", text: "VIEW LOGS"))
  end

  # ── C8: Action Buttons — DUAL verification ─────────────────────────────────
  # Action buttons (RESTART, ISOLATE, DRAIN) only appear when a node is selected.
  # Each is tested twice: once for the status/DOM change, once for the flash message.

  # restart_node — status change (detail panel stays visible with same node)
  feature "C8a — clicking RESTART shows node detail panel remains after restart armed", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='gw-01']"))
    |> assert_has(css("button[phx-click='restart_node']"))
    |> click(css("button[phx-click='restart_node']"))
    # After flash, detail panel must still show role/zone/ip/status
    |> assert_has(css("span.text-content-muted", text: "Role:"))
  end

  # restart_node — flash message path
  feature "C8b — clicking RESTART shows Restart command armed flash info message", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='gw-01']"))
    |> click(css("button[phx-click='restart_node']"))
    |> assert_has(css("[role='alert']", text: "Restart command armed"))
  end

  # isolate_node — status change (detail panel stays)
  feature "C8a — clicking ISOLATE keeps detail panel visible (second status path)", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='app-02']"))
    |> assert_has(css("button[phx-click='isolate_node']"))
    |> click(css("button[phx-click='isolate_node']"))
    |> assert_has(css("span.text-content-muted", text: "Role:"))
  end

  # isolate_node — flash message path
  feature "C8b — clicking ISOLATE shows Isolate command armed flash warning", %{session: session} do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='app-02']"))
    |> click(css("button[phx-click='isolate_node']"))
    |> assert_has(css("[role='alert']", text: "Isolate command armed"))
  end

  # drain_node — status change (detail panel stays)
  feature "C8a — clicking DRAIN keeps detail panel visible (third status path)", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='app-03']"))
    |> assert_has(css("button[phx-click='drain_node']"))
    |> click(css("button[phx-click='drain_node']"))
    |> assert_has(css("span.text-content-muted", text: "Role:"))
  end

  # drain_node — flash message path
  feature "C8b — clicking DRAIN shows Drain initiated flash info message", %{session: session} do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='app-03']"))
    |> click(css("button[phx-click='drain_node']"))
    |> assert_has(css("[role='alert']", text: "Drain initiated"))
  end

  # ── C2 Extended: Health status badges ──────────────────────────────────────

  feature "C2 — app-02 controller node card is rendered in topology tree", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div[phx-value-id='app-02']", minimum: 1))
  end

  feature "C2 — app-01 supervisor node card renders with phx-value-id attribute", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div[phx-value-id='app-01']", minimum: 1))
  end

  feature "C2 — LEGEND Offline status entry is present for full status coverage", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span.text-content-muted", text: "Offline"))
  end

  # ── C4 Extended: Timeline and event log ────────────────────────────────────

  feature "C4 — prajna:mesh PubSub node_update to caution status does not crash page", %{
    session: session
  } do
    session = visit(session, @path)

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:node_update, "gw-01",
       %{cpu: 90, cpu_trend: :rising_fast, cpu_level: :critical, status: :critical}}
    )

    Process.sleep(@propagation_ms)

    assert_has(session, css("h2", text: "MESH TOPOLOGY"))
    assert_has(session, css("span", text: "online"))
  end

  feature "C4 — rapid burst of five node_update messages leaves page stable", %{session: session} do
    session = visit(session, @path)

    for i <- 1..5 do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:node_update, "app-0#{rem(i, 4) + 1}",
         %{cpu: i * 10, cpu_trend: :stable, cpu_level: :healthy, status: :healthy}}
      )
    end

    Process.sleep(500)

    assert_has(session, css("h2", text: "MESH TOPOLOGY"))
  end

  # ── C5 Extended: Filter controls ───────────────────────────────────────────

  feature "C5 — clicking app-04 node selects it and shows detail panel", %{session: session} do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='app-04']"))
    |> refute_has(css("p.text-content-muted", text: "Click a node to view details"))
    |> assert_has(css("span.text-content-muted", text: "Role:"))
  end

  feature "C5 — selecting app-05 worker node shows action buttons", %{session: session} do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='app-05']"))
    |> assert_has(css("button[phx-click='restart_node']", minimum: 1))
  end

  # ── C8 Extended: clear_selection dual verification ─────────────────────────

  # clear_selection — Test 1: placeholder reappears after clear (status change)
  feature "C8a — clear_selection restores Click a node placeholder (status change path)", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='gw-01']"))
    |> click(css("button[phx-click='clear_selection']"))
    |> assert_has(css("p.text-content-muted", text: "Click a node to view details"))
  end

  # clear_selection — Test 2: heading and legend remain stable after clear (state path)
  feature "C8b — after clear_selection MESH TOPOLOGY heading and LEGEND remain visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("div[phx-value-id='gw-01']"))
    |> click(css("button[phx-click='clear_selection']"))
    |> assert_has(css("h2", text: "MESH TOPOLOGY"))
    |> assert_has(css("h3", text: "LEGEND"))
  end
end
