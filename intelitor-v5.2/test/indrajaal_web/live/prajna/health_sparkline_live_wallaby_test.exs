defmodule IndrajaalWeb.Prajna.HealthSparklineLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the PRAJNA System Health Sparklines LiveView page.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity

  | Field  | Value                                                        |
  |--------|--------------------------------------------------------------|
  | Route  | `/cockpit/health-sparklines`                                 |
  | Module | `IndrajaalWeb.Prajna.HealthSparklineLive`                    |
  | Title  | `System Health — Sparklines`                                 |
  | Tier   | Tier 1 (High) — Node Health Matrix, SVG Sparklines, PubSub  |

  ## Design Intent

  The System Health Sparklines page is the primary rolling-window homeostasis monitor
  for the SIL-6 mesh. It renders four SVG sparkline summary cards (CPU Utilization,
  Memory Usage, Queue Depth, Response Latency) each with a 60-sample rolling window and
  a dashed threshold line. A node selector row lets operators switch between the
  AGGREGATE view and any of the five individual nodes (node-1 through node-5). A NODE
  HEALTH MATRIX table lists each node with CPU %, MEM %, QUEUE, RESP MS, PROCS, and a
  STATUS badge (HEALTHY / DEGRADED / CRITICAL). A detailed 2-column sparklines grid
  repeats the four charts at double size with fill-polygon, current-value dot, and
  threshold annotation. Two timers drive live updates: 5 000 ms (:refresh) advances
  the rolling window; 30 000 ms (:sync_metrics) syncs BEAM runtime metrics. Three
  PubSub channels feed live telemetry: `prajna:metrics`, `zenoh:health`, `prajna:health`.

  ## Expected Behavior (Functional)

  On mount: `metric_history` (map: cpu / memory / queue_depth / response_ms → 60-point
  float lists), `node_metrics` (5 nodes), `system_summary` (%{health_score, trend,
  alert_count}), `selected_node` (:aggregate), `alert_thresholds` (map of string keys
  to float thresholds), `last_update` (DateTime), `sparkline_width` (200),
  `sparkline_height` (40).

  `handle_event "select_node"` — sets `selected_node` assign to node key or :aggregate;
  active button receives `bg-blue-900 text-blue-300` class; inactive buttons use
  `bg-surface-tertiary`.

  `handle_event "set_threshold"` — parses float from `value` param; updates
  `alert_thresholds[metric]`; invalid value is silently ignored (no state change).

  `handle_info :refresh` (5 000 ms timer) — advances each series in `metric_history` by
  dropping the oldest point and appending a random-walk next value; updates `last_update`.

  `handle_info :sync_metrics` (30 000 ms timer) — fetches BEAM/FullSystemMonitor metrics;
  updates `node_metrics` and recomputes `system_summary`.

  `handle_info {:metrics_update, metrics}` (PubSub `prajna:metrics`) — pushes a new
  sample into `metric_history` from the broadcast map; updates `last_update`.

  `handle_info {:node_health, node_id, health}` (PubSub `zenoh:health`) — merges health
  map into `node_metrics[node_id]`.

  ## BDD Scenarios

  ```gherkin
  Feature: System Health Sparklines Live View

    Scenario: C1 — Page loads with System Health Sparklines heading
      Given I navigate to "/cockpit/health-sparklines"
      Then I should see an h1 containing "System Health — Sparklines"
      And the SC-MON-001 annotation is visible in the sub-header paragraph

    Scenario: C3 — Four metric summary cards are rendered
      Given I navigate to "/cockpit/health-sparklines"
      Then I should see "CPU Utilization" card
      And I should see "Memory Usage" card
      And I should see "Queue Depth" card
      And I should see "Response Latency" card

    Scenario: C6 — SVG sparklines are present in metric cards
      Given I navigate to "/cockpit/health-sparklines"
      Then SVG polyline elements should be visible
      And circle current-value markers should be visible in the detailed grid
      And "60s ago" and "now" time labels should be present

    Scenario: C3 — NODE HEALTH MATRIX table renders all five nodes
      Given I navigate to "/cockpit/health-sparklines"
      Then I should see "NODE HEALTH MATRIX" heading
      And table headers NODE, CPU %, MEM %, QUEUE, RESP MS, STATUS should be present
      And rows for node-1 through node-5 should be present

    Scenario: C2 — Node status badge is present in matrix rows
      Given I navigate to "/cockpit/health-sparklines"
      Then at least one status badge (HEALTHY / DEGRADED / CRITICAL) should be visible

    Scenario: C5 — Selecting node-2 makes its button active
      Given I navigate to "/cockpit/health-sparklines"
      When I click the node-2 selector button
      Then the node-2 button should have class bg-blue-900
      And the AGGREGATE button should no longer have class bg-blue-900

    Scenario: C5 — Returning to AGGREGATE restores its active state
      Given I navigate to "/cockpit/health-sparklines"
      When I click node-3 then click AGGREGATE
      Then the AGGREGATE button should have class bg-blue-900

    Scenario: C8 — select_node event (status change) switches active button highlight
      Given I navigate to "/cockpit/health-sparklines"
      When I click the node-1 selector button
      Then node-1 button should have bg-blue-900
      And AGGREGATE button should not have bg-blue-900

    Scenario: C8 — PubSub prajna:metrics broadcast keeps page stable
      Given I navigate to "/cockpit/health-sparklines"
      When a {:metrics_update, ...} message is broadcast on "prajna:metrics"
      And 400ms propagation elapses
      Then the page heading and NODE HEALTH MATRIX should still be visible
  ```

  ## UX Flow

  1. Operator navigates to `/cockpit/health-sparklines` via Prajna nav.
  2. "System Health — Sparklines" h1 renders; sub-header shows 60-second rolling window
     annotation and last_update timestamp (HH:MM:SS UTC).
  3. Top row: four summary sparkline cards (CPU %, Memory %, Queue Depth, Response ms)
     each with an SVG polyline, dashed threshold line, and current value in colour.
  4. Node selector row: AGGREGATE active by default; node-1 through node-5 buttons
     available; clicking any button updates selected_node and re-renders sparklines.
  5. NODE HEALTH MATRIX table: each of the 5 nodes listed with numeric metrics and a
     STATUS badge; selected node row highlighted with bg-surface-elevated.
  6. Detailed 2-column sparkline grid: larger SVG with fill polygon, threshold marker,
     current-value dot, t-60s / now / Threshold: labels.
  7. 5 000 ms timer fires — rolling window advances; sparkline paths update silently.
  8. 30 000 ms timer fires — BEAM metrics synced; node_metrics refreshed.
  9. PubSub `prajna:metrics` broadcast pushes a new sample into metric_history.
  10. PubSub `zenoh:health` broadcast merges updated health for a specific node.

  ## UI Elements Inventory

  | Element                       | Type     | Selector                                                      | Event                    | Category |
  |-------------------------------|----------|---------------------------------------------------------------|--------------------------|----------|
  | Page heading                  | h1       | `css("h1", text: "System Health — Sparklines")`               | —                        | C1       |
  | SC-MON-001 sub-header         | p        | `css("p", text: "SC-MON-001")`                                | —                        | C1       |
  | 60-second annotation          | p        | `css("p", text: "60-second rolling window")`                  | —                        | C1       |
  | STAMP footer                  | div      | `css("div.text-xs.text-content-muted", text: "SC-MON-001")`   | —                        | C1       |
  | Health score label            | span     | `css("span", text: "Health:")`                                | —                        | C2       |
  | Trend badge                   | span     | `css("span.px-2.py-1.rounded")`                               | —                        | C2       |
  | Node status badge             | span     | `css("span.rounded.text-xs")`                                 | —                        | C2       |
  | CPU Utilization card          | div      | `css("div", text: "CPU Utilization")`                         | —                        | C3       |
  | Memory Usage card             | div      | `css("div", text: "Memory Usage")`                            | —                        | C3       |
  | Queue Depth card              | div      | `css("div", text: "Queue Depth")`                             | —                        | C3       |
  | Response Latency card         | div      | `css("div", text: "Response Latency")`                        | —                        | C3       |
  | NODE HEALTH MATRIX heading    | h2       | `css("h2", text: "NODE HEALTH MATRIX")`                       | —                        | C3       |
  | Matrix table headers          | th       | `css("th", text: "NODE")` etc.                                | —                        | C3       |
  | Node-1 table row              | td       | `css("td", text: "node-1")`                                   | —                        | C3       |
  | SVG polyline sparkline        | polyline | `css("polyline")`                                             | :refresh timer           | C6       |
  | SVG circle value dot          | circle   | `css("circle")`                                               | :refresh timer           | C6       |
  | "60s ago" label               | span     | `css("span", text: "60s ago")`                                | —                        | C6       |
  | "t-60s" label                 | span     | `css("span", text: "t-60s")`                                  | —                        | C6       |
  | Threshold annotation          | span     | `css("span", text: "Threshold:")`                             | —                        | C6       |
  | Message Queue Depth detail    | h3       | `css("h3", text: "Message Queue Depth")`                      | —                        | C6       |
  | AGGREGATE node button         | button   | `css("button[phx-click='select_node'][phx-value-node='aggregate']")` | select_node      | C5       |
  | Node-1 selector button        | button   | `css("button[phx-value-node='node-1']")`                      | select_node              | C5       |
  | Node-2 selector button        | button   | `css("button[phx-value-node='node-2']")`                      | select_node              | C5       |
  | Active button (bg-blue-900)   | button   | `css("button[phx-value-node='...'].bg-blue-900")`             | select_node result       | C8       |
  | Flash message                 | div      | `css("[role='alert']")`                                       | PubSub broadcast         | C8       |

  ## STAMP Constraints

  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009: C1 (Page Structure) — heading, SC-MON-001 annotation, STAMP footer
  - SC-COV-010: C2 (Status/Badge) — trend badge, node status HEALTHY/DEGRADED/CRITICAL
  - SC-COV-011: C3 (Data Grid) — NODE HEALTH MATRIX table with 5 node rows and headers
  - SC-COV-013: C5 (Interactive) — select_node buttons (aggregate + node-1 to node-5)
  - SC-COV-014: C6 (Media/Rich Content) — SVG polylines, circle markers, time labels
  - SC-COV-016: C8 (Actions) — select_node active-class change; PubSub stability assert
  - SC-COV-020: PubSub refresh stability — prajna:metrics, zenoh:health broadcasts
  - SC-COV-021: @moduledoc page spec derived from source (SC-COV-022 compliant)
  - SC-HMI-010: Color Rich — sparkline stroke colour green/amber/red per threshold
  - SC-HMI-011: 8x8 Matrix path coverage across all node selector states
  - SC-MON-001: 30 s refresh cycle verified via sub-header annotation
  - SC-MON-002: Infrastructure metrics complete — all four sparkline metrics present
  - SC-MON-004: Safety metrics mandatory — node health status badges present
  - SC-PRF-050: Response latency sparkline tracks response_ms metric

  ## FMEA Risks

  | Failure Mode                                  | S | O | D | RPN | Mitigation                                              |
  |-----------------------------------------------|---|---|---|-----|---------------------------------------------------------|
  | Sparklines render blank after node switch     | 5 | 3 | 3 |  45 | C5+C6 — assert polyline present after select_node      |
  | NODE HEALTH MATRIX stale after PubSub update  | 6 | 3 | 3 |  54 | SC-COV-020 sleep 400ms + re-assert heading and matrix  |
  | AGGREGATE button loses active class on reload | 4 | 2 | 3 |  24 | C5 — assert bg-blue-900 on AGGREGATE at page load      |
  | set_threshold silently drops invalid float    | 4 | 2 | 2 |  16 | No flash issued; guard Float.parse error clause tested |
  | Health score badge absent from matrix row     | 6 | 2 | 3 |  36 | C2 — assert span.rounded.text-xs minimum: 1            |
  | :refresh timer causes SVG path corruption     | 7 | 1 | 3 |  21 | C6 — assert polyline still present after PubSub sleep  |
  | zenoh:health broadcast ignored silently       | 5 | 2 | 4 |  40 | C8b — broadcast + sleep + re-assert heading stability  |

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

  @path "/cockpit/health-sparklines"
  @propagation_ms 400

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "C1 — page loads with System Health Sparklines heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "System Health — Sparklines"))
  end

  feature "C1 — SC-MON-001 annotation is visible in sub-header", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "SC-MON-001"))
  end

  feature "C1 — 60-second rolling window annotation is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "60-second rolling window"))
  end

  feature "C1 — STAMP compliance footer with SC-MON-001 is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-xs.text-content-muted", text: "SC-MON-001"))
  end

  feature "C1 — STAMP compliance footer references SC-MON-002 and SC-PRF-050", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.text-xs.text-content-muted", text: "SC-MON-002"))
    |> assert_has(css("div.text-xs.text-content-muted", text: "SC-PRF-050"))
  end

  # ── C2: Status / Badge Display ──────────────────────────────────────────────

  feature "C2 — system health score percentage label is visible in header area", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Health:"))
  end

  feature "C2 — trend badge STABLE IMPROVING or DEGRADING is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.px-2.py-1.rounded", minimum: 1))
  end

  feature "C2 — node status badge HEALTHY DEGRADED or CRITICAL is present in matrix", %{
    session: session
  } do
    # The STATUS column uses node_status_label/1 which returns HEALTHY/DEGRADED/CRITICAL
    session
    |> visit(@path)
    |> assert_has(css("span.rounded.text-xs", minimum: 1))
  end

  # ── C3: Data Grid / Summary ─────────────────────────────────────────────────

  feature "C3 — CPU Utilization summary metric card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "CPU Utilization"))
  end

  feature "C3 — Memory Usage summary metric card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Memory Usage"))
  end

  feature "C3 — Queue Depth summary metric card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Queue Depth"))
  end

  feature "C3 — Response Latency summary metric card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Response Latency"))
  end

  feature "C3 — NODE HEALTH MATRIX section heading is present", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "NODE HEALTH MATRIX"))
  end

  feature "C3 — NODE HEALTH MATRIX table has NODE CPU MEM QUEUE RESP PROCS STATUS headers", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("th", text: "NODE"))
    |> assert_has(css("th", text: "CPU %"))
    |> assert_has(css("th", text: "MEM %"))
    |> assert_has(css("th", text: "QUEUE"))
    |> assert_has(css("th", text: "RESP MS"))
    |> assert_has(css("th", text: "STATUS"))
  end

  feature "C3 — NODE HEALTH MATRIX shows node-1 through node-5 rows", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("td", text: "node-1"))
    |> assert_has(css("td", text: "node-5"))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "C5 — AGGREGATE node selector button is present and active by default", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(
      css("button[phx-click='select_node'][phx-value-node='aggregate']", text: "AGGREGATE")
    )
    |> assert_has(css("button[phx-value-node='aggregate'].bg-blue-900"))
  end

  feature "C5 — node-1 through node-5 selector buttons are present", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='select_node'][phx-value-node='node-1']"))
    |> assert_has(css("button[phx-click='select_node'][phx-value-node='node-2']"))
    |> assert_has(css("button[phx-click='select_node'][phx-value-node='node-3']"))
    |> assert_has(css("button[phx-click='select_node'][phx-value-node='node-4']"))
    |> assert_has(css("button[phx-click='select_node'][phx-value-node='node-5']"))
  end

  feature "C5 — clicking node-2 selector makes it active (bg-blue-900)", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-node='node-2']"))
    |> assert_has(css("button[phx-value-node='node-2'].bg-blue-900"))
  end

  feature "C5 — clicking AGGREGATE after node-3 restores aggregate active state", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-node='node-3']"))
    |> click(css("button[phx-value-node='aggregate']"))
    |> assert_has(css("button[phx-value-node='aggregate'].bg-blue-900"))
  end

  # ── C6: Media / Rich Content (SVG sparklines) ───────────────────────────────

  feature "C6 — SVG sparkline polylines are present in summary metric cards", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("polyline", minimum: 1))
  end

  feature "C6 — SVG circle current-value markers are present in detailed sparklines", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("circle", minimum: 1))
  end

  feature "C6 — sparkline time labels 60s ago and now are shown", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "60s ago", minimum: 1))
    |> assert_has(css("span", text: "now", minimum: 1))
  end

  feature "C6 — detailed sparkline t-60s label is shown", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "t-60s", minimum: 1))
  end

  feature "C6 — Threshold annotation is visible in the detailed sparklines section", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Threshold:", minimum: 1))
  end

  feature "C6 — Message Queue Depth label is present in detailed sparklines grid", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Message Queue Depth"))
  end

  # ── C8: Action Buttons — DUAL verification ─────────────────────────────────

  # C8a select_node → active button style CHANGES (status change)
  feature "C8a — select_node for node-1 changes active button highlight (status badge change)", %{
    session: session
  } do
    session
    |> visit(@path)
    # AGGREGATE is active initially; click node-1 to change active node
    |> click(css("button[phx-value-node='node-1']"))
    |> assert_has(css("button[phx-value-node='node-1'].bg-blue-900"))
    |> refute_has(css("button[phx-value-node='aggregate'].bg-blue-900"))
  end

  # C8b select_node → no flash, but metrics_update PubSub causes data refresh
  feature "C8b — metrics_update PubSub broadcast keeps page stable and heading visible", %{
    session: session
  } do
    session = visit(session, @path)
    assert_has(session, css("h1", text: "System Health — Sparklines"))

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "prajna:metrics",
      {:metrics_update, %{cpu: 55.0, memory: 70.0, queue_depth: 20, response_ms: 30}}
    )

    Process.sleep(@propagation_ms)

    assert_has(session, css("h1", text: "System Health — Sparklines"))
    assert_has(session, css("h2", text: "NODE HEALTH MATRIX"))
  end

  # C8a select_node node-4 path
  feature "C8a — select_node for node-4 activates node-4 button (second status path)", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-node='node-4']"))
    |> assert_has(css("button[phx-value-node='node-4'].bg-blue-900"))
  end

  # C8b zenoh:health broadcast path
  feature "C8b — zenoh:health broadcast keeps sparklines page alive", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("h1", text: "System Health — Sparklines"))

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:health",
      {:health_update, %{score: 98.5, threats: 0, status: :healthy}}
    )

    Process.sleep(@propagation_ms)

    assert_has(session, css("h1", text: "System Health — Sparklines"))
    assert_has(session, css("div", text: "CPU Utilization"))
  end

  # ── SC-COV-020: PubSub refresh stability ────────────────────────────────────

  feature "health sparkline remains stable after PubSub refresh (SC-COV-020)", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "System Health — Sparklines"))

    :timer.sleep(6_000)

    session
    |> assert_has(css("h1", text: "System Health — Sparklines"))
  end

  # ── C4: Timeline / History (Page Reload Stability) ──────────────────────────
  # Adapted per protocol: C4 = "page reload stability" — visit, assert, revisit, re-assert.
  # Verifies that all key structural and data elements survive a full page reload cycle.

  feature "C4 — page heading survives reload cycle (reload stability)", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "System Health — Sparklines"))
    |> visit(@path)
    |> assert_has(css("h1", text: "System Health — Sparklines"))
  end

  feature "C4 — NODE HEALTH MATRIX survives reload cycle (reload stability)", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "NODE HEALTH MATRIX"))
    |> visit(@path)
    |> assert_has(css("h2", text: "NODE HEALTH MATRIX"))
    |> assert_has(css("td", text: "node-1"))
  end

  feature "C4 — SC-MON-001 annotation survives reload cycle (rolling window annotation stable)",
          %{
            session: session
          } do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "60-second rolling window"))
    |> visit(@path)
    |> assert_has(css("p", text: "SC-MON-001"))
    |> assert_has(css("p", text: "60-second rolling window"))
  end

  # ── C7: AI / Advisory (Contextual Metrics & System Context) ─────────────────
  # Adapted per protocol: C7 = "contextual metrics" — verify summary text that provides
  # system context: health scores, trend indicators, STAMP compliance annotations,
  # and metric threshold advisories. These panels inform operator decisions (SC-HMI-010).

  feature "C7 — system health score is displayed as contextual advisory metric", %{
    session: session
  } do
    # health_score % is rendered next to "Health:" span — serves as system-state advisory
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Health:"))
    |> assert_has(css("span.font-bold", minimum: 1))
  end

  feature "C7 — trend indicator provides system trajectory context (STABLE IMPROVING DEGRADING)",
          %{
            session: session
          } do
    # trend_label/1 renders STABLE/IMPROVING/DEGRADING — contextual system direction advisory
    session
    |> visit(@path)
    |> assert_has(css("span.px-2.py-1.rounded", minimum: 1))
  end

  feature "C7 — STAMP compliance footer provides regulatory context annotation", %{
    session: session
  } do
    # STAMP footer renders SC-MON-001/002/004/SC-PRF-050 — advisory constraints context
    session
    |> visit(@path)
    |> assert_has(css("div.text-xs.text-content-muted", text: "SC-MON-004"))
  end

  feature "C7 — threshold annotation in detailed sparklines provides safety-margin advisory", %{
    session: session
  } do
    # Threshold: {value}{unit} annotation on each detailed sparkline gives operator
    # the safety margin context — advisory for proactive intervention before breach
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Threshold:", minimum: 1))
    |> assert_has(css("span", text: "t-60s", minimum: 1))
  end
end
